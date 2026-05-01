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
    /// Errors when a field's declared type isn't a known primitive and isn't
    /// another `@Castable` struct (Foundation value types like `Date`, `URL`,
    /// `UUID`, `Data`, `Decimal`). Was a warning pre-v1.0; promoted to error
    /// because the synthesized mirror would otherwise produce a cryptic
    /// `<TypeName>.PartiallyGenerated?` compile error downstream — surfacing
    /// the diagnostic at the call site is friendlier.
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
            "'\(typeName)' is not a Cast-supported type. Wrap it in a small @Castable struct, or pre-convert to a primitive at the model boundary (e.g. ISO-8601 String for Date, raw bytes for Data). See the 'Foundation types' section of MIGRATION.md."
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
        .error
    }
}
