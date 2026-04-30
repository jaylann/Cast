import SwiftDiagnostics

enum CastableDiagnostic: DiagnosticMessage {
    case requiresStruct
    case rangeOnString
    case lengthOnNumeric
    case countOnNonArray
    case invertedRange
    case conflictingLengths
    case patternOnNonString
    case precisionOnNonFloat
    /// Warns when a field's declared type isn't a known primitive and isn't
    /// recognizably another `@Castable` struct (Foundation value types like
    /// `Date`, `URL`, `UUID`, `Data`, `Decimal`). The macro will still project
    /// it as `<TypeName>.PartiallyGenerated?` in the synthesized mirror; the
    /// consumer must supply that conformance themselves or wrap the field.
    case unknownNonPrimitiveType(typeName: String)

    var message: String {
        switch self {
        case .requiresStruct:
            "@Castable can only be applied to structs"
        case .rangeOnString:
            "@CastRange cannot be applied to String properties"
        case .lengthOnNumeric:
            "@MaxLength/@MinLength can only be applied to String properties"
        case .countOnNonArray:
            "@MaxCount/@MinCount/@Count can only be applied to Array properties"
        case .invertedRange:
            "@CastRange lower bound must be less than or equal to upper bound"
        case .conflictingLengths:
            "@MinLength value must be less than or equal to @MaxLength value"
        case .patternOnNonString:
            "@Pattern can only be applied to String properties"
        case .precisionOnNonFloat:
            "@Precision can only be applied to Double or Float properties"
        case let .unknownNonPrimitiveType(typeName):
            "'\(typeName)' is not a Cast-supported primitive; the synthesized PartiallyGenerated mirror will project this field as '\(typeName).PartiallyGenerated?' and will fail to compile unless '\(typeName)' is itself @Castable. Consider wrapping it in a small @Castable struct or pre-converting to a primitive (e.g. ISO-8601 String for dates)."
        }
    }

    var diagnosticID: MessageID {
        let id = switch self {
        case .requiresStruct: "requiresStruct"
        case .rangeOnString: "rangeOnString"
        case .lengthOnNumeric: "lengthOnNumeric"
        case .countOnNonArray: "countOnNonArray"
        case .invertedRange: "invertedRange"
        case .conflictingLengths: "conflictingLengths"
        case .patternOnNonString: "patternOnNonString"
        case .precisionOnNonFloat: "precisionOnNonFloat"
        case .unknownNonPrimitiveType: "unknownNonPrimitiveType"
        }
        return MessageID(domain: "CastMacro", id: id)
    }

    var severity: DiagnosticSeverity {
        switch self {
        case .unknownNonPrimitiveType:
            .warning
        default:
            .error
        }
    }
}
