import SwiftDiagnostics

enum CastableDiagnostic: String, DiagnosticMessage {
    case requiresStruct = "@Castable can only be applied to structs"
    case rangeOnString = "@CastRange cannot be applied to String properties"
    case lengthOnNumeric = "@MaxLength/@MinLength can only be applied to String properties"
    case countOnNonArray = "@MaxCount/@MinCount/@Count can only be applied to Array properties"
    case invertedRange = "@CastRange lower bound must be less than or equal to upper bound"
    case conflictingLengths = "@MinLength value must be less than or equal to @MaxLength value"
    case patternOnNonString = "@Pattern can only be applied to String properties"
    case precisionOnNonFloat = "@Precision can only be applied to Double or Float properties"

    var message: String { rawValue }
    var diagnosticID: MessageID { MessageID(domain: "CastMacro", id: String(describing: self)) }
    var severity: DiagnosticSeverity { .error }
}
