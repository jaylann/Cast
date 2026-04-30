import Foundation
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

public struct CastableMacro {}

// MARK: - MemberMacro

extension CastableMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo _: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            context.diagnose(Diagnostic(node: node, message: CastableDiagnostic.requiresStruct))
            return []
        }

        let properties = collectProperties(from: structDecl)
        let diagnostics = validateProperties(properties)
        for (diagnostic, propNode) in diagnostics {
            context.diagnose(Diagnostic(node: propNode, message: diagnostic))
        }
        // Warnings (e.g. unknown non-primitive field types) inform the user but
        // must not block expansion — the synthesized members are still useful
        // and the warning flags the call-site for follow-up.
        let hasError = diagnostics.contains { $0.0.severity == .error }
        guard !hasError else { return [] }

        let schemaDecl = generateSchemaDecl(properties: properties)
        let initDecl = generateInitDecl(properties: properties)
        let partialDecl = generatePartiallyGeneratedDecl(properties: properties)

        return [schemaDecl, initDecl, partialDecl]
    }
}

// MARK: - ExtensionMacro

extension CastableMacro: ExtensionMacro {
    public static func expansion(
        of _: AttributeSyntax,
        attachedTo _: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo _: [TypeSyntax],
        in _: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let ext: DeclSyntax = "extension \(type.trimmed): Castable, Decodable {}"
        return [ext.cast(ExtensionDeclSyntax.self)]
    }
}

// MARK: - Property Collection

private struct PropertyInfo {
    let name: String
    let typeName: String
    let isOptional: Bool
    let isArray: Bool
    let arrayElementType: String?
    let wrappers: [WrapperInfo]
    let defaultValue: String?
    let node: Syntax
}

private struct WrapperInfo {
    let name: String
    let arguments: [String]
    let node: Syntax
}

private func collectProperties(from structDecl: StructDeclSyntax) -> [PropertyInfo] {
    var properties: [PropertyInfo] = []

    for member in structDecl.memberBlock.members {
        guard let varDecl = member.decl.as(VariableDeclSyntax.self),
              varDecl.bindingSpecifier.tokenKind == .keyword(.var),
              let binding = varDecl.bindings.first,
              let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
              let typeAnnotation = binding.typeAnnotation?.type else { continue }

        let name = pattern.identifier.text
        let (typeName, isOptional, isArray, arrayElement) = parseType(typeAnnotation)
        let wrappers = collectWrappers(from: varDecl)
        let defaultValue = binding.initializer.map { "\($0.value.trimmed)" }

        properties.append(PropertyInfo(
            name: name,
            typeName: typeName,
            isOptional: isOptional,
            isArray: isArray,
            arrayElementType: arrayElement,
            wrappers: wrappers,
            defaultValue: defaultValue,
            node: Syntax(varDecl)
        ))
    }

    return properties
}

private func parseType(_ type: TypeSyntax) -> (name: String, isOptional: Bool, isArray: Bool, arrayElement: String?) {
    if let optional = type.as(OptionalTypeSyntax.self) {
        let (name, _, isArray, element) = parseType(optional.wrappedType)
        return (name, true, isArray, element)
    }

    if let array = type.as(ArrayTypeSyntax.self) {
        let elementName = "\(array.element.trimmed)"
        return ("[\(elementName)]", false, true, elementName)
    }

    if let ident = type.as(IdentifierTypeSyntax.self) {
        let name = ident.name.text
        if name == "Array", let generic = ident.genericArgumentClause?.arguments.first {
            let elementName = "\(generic.argument.trimmed)"
            return ("[\(elementName)]", false, true, elementName)
        }
        if name == "Optional", let generic = ident.genericArgumentClause?.arguments.first {
            let inner = "\(generic.argument.trimmed)"
            return (inner, true, false, nil)
        }
        return (name, false, false, nil)
    }

    return ("\(type.trimmed)", false, false, nil)
}

private func collectWrappers(from varDecl: VariableDeclSyntax) -> [WrapperInfo] {
    varDecl.attributes.compactMap { attr -> WrapperInfo? in
        guard let attrSyntax = attr.as(AttributeSyntax.self),
              let name = attrSyntax.attributeName.as(IdentifierTypeSyntax.self)?.name.text
        else {
            return nil
        }

        let args: [String] = if let argList = attrSyntax.arguments?.as(LabeledExprListSyntax.self) {
            argList.map { "\($0.expression.trimmed)" }
        } else {
            []
        }

        return WrapperInfo(name: name, arguments: args, node: Syntax(attrSyntax))
    }
}

// MARK: - Validation

private let stringTypes: Set<String> = ["String"]
private let integerTypes: Set<String> = [
    "Int",
    "Int8",
    "Int16",
    "Int32",
    "Int64",
    "UInt",
    "UInt8",
    "UInt16",
    "UInt32",
    "UInt64"
]
private let floatTypes: Set<String> = ["Double", "Float"]
private let numericTypes: Set<String> = integerTypes.union(floatTypes)
private let boolTypes: Set<String> = ["Bool"]

/// Foundation value types developers commonly reach for that are *not*
/// primitives in Cast's model. They will be projected as
/// `<TypeName>.PartiallyGenerated?` and break compilation unless the
/// consumer adds that conformance manually. Warn loudly at the call site.
private let suspectFoundationTypes: Set<String> = [
    "Date",
    "URL",
    "UUID",
    "Data",
    "Decimal",
    "TimeInterval"
]

private func validateProperties(_ properties: [PropertyInfo]) -> [(CastableDiagnostic, Syntax)] {
    var diagnostics: [(CastableDiagnostic, Syntax)] = []

    for prop in properties {
        var hasMaxLength: (Int, Syntax)?
        var hasMinLength: (Int, Syntax)?

        for wrapper in prop.wrappers {
            switch wrapper.name {
            case "CastRange":
                if stringTypes.contains(prop.typeName) || boolTypes.contains(prop.typeName) {
                    diagnostics.append((.rangeOnString, wrapper.node))
                }
                if let bounds = parseRangeBounds(wrapper.arguments) {
                    if bounds.lower > bounds.upper {
                        diagnostics.append((.invertedRange, wrapper.node))
                    }
                }

            case "MaxLength":
                if numericTypes.contains(prop.typeName) || boolTypes.contains(prop.typeName) {
                    diagnostics.append((.lengthOnNumeric, wrapper.node))
                }
                if let val = wrapper.arguments.first.flatMap({ Int($0) }) {
                    hasMaxLength = (val, wrapper.node)
                }

            case "MinLength":
                if numericTypes.contains(prop.typeName) || boolTypes.contains(prop.typeName) {
                    diagnostics.append((.lengthOnNumeric, wrapper.node))
                }
                if let val = wrapper.arguments.first.flatMap({ Int($0) }) {
                    hasMinLength = (val, wrapper.node)
                }

            case "MaxCount", "MinCount", "Count":
                if !prop.isArray {
                    diagnostics.append((.countOnNonArray, wrapper.node))
                }

            case "Pattern":
                if !stringTypes.contains(prop.typeName) {
                    diagnostics.append((.patternOnNonString, wrapper.node))
                }

            case "Precision":
                if !floatTypes.contains(prop.typeName) {
                    diagnostics.append((.precisionOnNonFloat, wrapper.node))
                }

            default:
                break
            }
        }

        if let (minVal, _) = hasMinLength, let (maxVal, node) = hasMaxLength {
            if minVal > maxVal {
                diagnostics.append((.conflictingLengths, node))
            }
        }

        if let warning = unknownTypeWarning(for: prop) {
            diagnostics.append(warning)
        }
    }

    return diagnostics
}

/// Emit a warning when the field's declared type is a known-suspect Foundation
/// value type (`Date`, `URL`, `UUID`, …) so the consumer is told *at the call
/// site* that the synthesized `PartiallyGenerated` will reference
/// `<TypeName>.PartiallyGenerated`. We deliberately do *not* warn for every
/// non-primitive (which would flood the build for legitimate nested `@Castable`
/// structs we can't see from inside the macro) — only for the Foundation types
/// users most often try first.
private func unknownTypeWarning(for prop: PropertyInfo) -> (CastableDiagnostic, Syntax)? {
    let candidate = prop.isArray ? (prop.arrayElementType ?? "") : prop.typeName
    guard suspectFoundationTypes.contains(candidate) else { return nil }
    return (.unknownNonPrimitiveType(typeName: candidate), prop.node)
}

private func parseRangeBounds(_ args: [String]) -> (lower: Double, upper: Double)? {
    guard let rangeExpr = args.first else { return nil }
    let parts = rangeExpr.split(separator: ".", maxSplits: .max, omittingEmptySubsequences: true)
    guard parts.count >= 2 else { return nil }
    // Parse "L...U" — after splitting on ".", we get [L, "", "", U] for "L...U"
    // or components like ["1", "", "", "10"] for "1...10"
    let cleaned = rangeExpr.replacingOccurrences(of: "...", with: "\t")
    let components = cleaned.split(separator: "\t")
    guard components.count == 2,
          let lower = Double(components[0].trimmingCharacters(in: .whitespaces)),
          let upper = Double(components[1].trimmingCharacters(in: .whitespaces))
    else {
        return nil
    }
    return (lower, upper)
}

// MARK: - Schema Generation

private func generateSchemaDecl(properties: [PropertyInfo]) -> DeclSyntax {
    var propertyEntries: [String] = []
    var requiredFields: [String] = []

    for prop in properties {
        let schemaExpr = schemaExpression(for: prop)
        propertyEntries.append("(\"\(prop.name)\", \(schemaExpr))")

        let isNullable = prop.wrappers.contains { $0.name == "Nullable" }
        if !prop.isOptional, !isNullable {
            requiredFields.append("\"\(prop.name)\"")
        }
    }

    let propertiesStr = propertyEntries.joined(separator: ",\n            ")
    let requiredStr = requiredFields.isEmpty ? "nil" : "[\(requiredFields.joined(separator: ", "))]"

    return """
    static let castSchema: JSONSchema = .object(
        properties: OrderedDictionary(dictionaryLiteral:
            \(raw: propertiesStr)
        ),
        required: \(raw: requiredStr),
        additionalProperties: .boolean(false)
    )
    """
}

private func generateInitDecl(properties _: [PropertyInfo]) -> DeclSyntax {
    """
    init() {
    }
    """
}

// MARK: - PartiallyGenerated Synthesis

/// Project a property's type onto its `PartiallyGenerated` form: known
/// primitives keep their own type, everything else is treated as a nested
/// `Castable` and routed through `.PartiallyGenerated`. Arrays carry the
/// projection through to their element type. The whole field is then made
/// Optional regardless of whether it was Optional originally — partial
/// snapshots have no notion of "required".
private func partialFieldType(for prop: PropertyInfo) -> String {
    if prop.isArray {
        let element = prop.arrayElementType ?? "String"
        return "[\(partialElementType(element))]?"
    }
    return "\(partialBaseType(prop.typeName))?"
}

private func partialBaseType(_ typeName: String) -> String {
    if stringTypes.contains(typeName) || numericTypes.contains(typeName) || boolTypes.contains(typeName) {
        return typeName
    }
    return "\(typeName).PartiallyGenerated"
}

private func partialElementType(_ typeName: String) -> String {
    if stringTypes.contains(typeName) || numericTypes.contains(typeName) || boolTypes.contains(typeName) {
        return typeName
    }
    return "\(typeName).PartiallyGenerated"
}

private func generatePartiallyGeneratedDecl(properties: [PropertyInfo]) -> DeclSyntax {
    let fields = properties
        .map { "var \($0.name): \(partialFieldType(for: $0))" }
        .joined(separator: "\n        ")

    if properties.isEmpty {
        return """
        struct PartiallyGenerated: Sendable, Decodable {
        }
        """
    }

    return """
    struct PartiallyGenerated: Sendable, Decodable {
        \(raw: fields)
    }
    """
}

private func schemaExpression(for prop: PropertyInfo) -> String {
    let baseType = prop.typeName
    var descriptionArg: String?
    var constraints = SchemaConstraints()

    for wrapper in prop.wrappers {
        switch wrapper.name {
        case "MaxLength":
            constraints.maxLength = wrapper.arguments.first
        case "MinLength":
            constraints.minLength = wrapper.arguments.first
        case "CastRange":
            if let bounds = wrapper.arguments.first {
                let cleaned = bounds.replacingOccurrences(of: "...", with: "\t")
                let parts = cleaned.split(separator: "\t")
                if parts.count == 2 {
                    constraints.rangeLower = String(parts[0]).trimmingCharacters(in: .whitespaces)
                    constraints.rangeUpper = String(parts[1]).trimmingCharacters(in: .whitespaces)
                }
            }
        case "MaxCount":
            constraints.maxItems = wrapper.arguments.first
        case "MinCount":
            constraints.minItems = wrapper.arguments.first
        case "Count":
            if let n = wrapper.arguments.first {
                constraints.minItems = n
                constraints.maxItems = n
            }
        case "OneOf":
            constraints.oneOfValues = wrapper.arguments.first
        case "Pattern":
            constraints.pattern = wrapper.arguments.first
        case "Precision":
            if let n = wrapper.arguments.first, let intVal = Int(n) {
                let multipleOf = pow(10.0, -Double(intVal))
                constraints.multipleOf = "\(multipleOf)"
            }
        case "Description":
            descriptionArg = wrapper.arguments.first
        case "Examples", "Nullable", "DefaultValue":
            break
        default:
            break
        }
    }

    if let oneOf = constraints.oneOfValues {
        let descPart = descriptionArg.map { "description: \($0), " } ?? ""
        return ".enum(\(descPart)values: \(oneOf).map { .string($0) })"
    }

    if prop.isArray {
        let elementSchema = elementSchemaExpression(prop.arrayElementType ?? "String")
        let descPart = descriptionArg.map { "description: \($0), " } ?? ""
        let itemsPart = "items: \(elementSchema)"
        var extras: [String] = []
        if let v = constraints.minItems { extras.append("minItems: \(v)") }
        if let v = constraints.maxItems { extras.append("maxItems: \(v)") }
        let extraStr = extras.isEmpty ? "" : ", \(extras.joined(separator: ", "))"
        return ".array(\(descPart)\(itemsPart)\(extraStr))"
    }

    if stringTypes.contains(baseType) {
        return stringSchema(desc: descriptionArg, constraints: constraints)
    }
    if integerTypes.contains(baseType) {
        return integerSchema(desc: descriptionArg, constraints: constraints)
    }
    if floatTypes.contains(baseType) {
        return numberSchema(desc: descriptionArg, constraints: constraints)
    }
    if boolTypes.contains(baseType) {
        let descPart = descriptionArg.map { "description: \($0)" } ?? ""
        return ".boolean(\(descPart))"
    }

    // Nested @Castable type — reference its castSchema
    return "\(baseType).castSchema"
}

private struct SchemaConstraints {
    var maxLength: String?
    var minLength: String?
    var rangeLower: String?
    var rangeUpper: String?
    var maxItems: String?
    var minItems: String?
    var oneOfValues: String?
    var pattern: String?
    var multipleOf: String?
}

private func stringSchema(desc: String?, constraints: SchemaConstraints) -> String {
    var args: [String] = []
    if let d = desc { args.append("description: \(d)") }
    if let v = constraints.minLength { args.append("minLength: \(v)") }
    if let v = constraints.maxLength { args.append("maxLength: \(v)") }
    if let v = constraints.pattern { args.append("pattern: \(v)") }
    return ".string(\(args.joined(separator: ", ")))"
}

private func integerSchema(desc: String?, constraints: SchemaConstraints) -> String {
    var args: [String] = []
    if let d = desc { args.append("description: \(d)") }
    if let v = constraints.rangeLower { args.append("minimum: \(v)") }
    if let v = constraints.rangeUpper { args.append("maximum: \(v)") }
    return ".integer(\(args.joined(separator: ", ")))"
}

private func numberSchema(desc: String?, constraints: SchemaConstraints) -> String {
    var args: [String] = []
    if let d = desc { args.append("description: \(d)") }
    if let v = constraints.multipleOf { args.append("multipleOf: \(v)") }
    if let v = constraints.rangeLower { args.append("minimum: \(v)") }
    if let v = constraints.rangeUpper { args.append("maximum: \(v)") }
    return ".number(\(args.joined(separator: ", ")))"
}

private func elementSchemaExpression(_ typeName: String) -> String {
    if stringTypes.contains(typeName) { return ".string()" }
    if integerTypes.contains(typeName) { return ".integer()" }
    if floatTypes.contains(typeName) { return ".number()" }
    if boolTypes.contains(typeName) { return ".boolean()" }
    return "\(typeName).castSchema"
}
