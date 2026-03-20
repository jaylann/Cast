import Foundation

@propertyWrapper
public struct MaxLength<Value: Sendable>: Sendable {
    public var wrappedValue: Value
    public let maxLength: Int

    public init(wrappedValue: Value, _ maxLength: Int) {
        self.wrappedValue = wrappedValue
        self.maxLength = maxLength
    }
}

@propertyWrapper
public struct MinLength<Value: Sendable>: Sendable {
    public var wrappedValue: Value
    public let minLength: Int

    public init(wrappedValue: Value, _ minLength: Int) {
        self.wrappedValue = wrappedValue
        self.minLength = minLength
    }
}

@propertyWrapper
public struct CastRange<Value: Sendable, Bound: Comparable & Sendable>: Sendable {
    public var wrappedValue: Value
    public let lowerBound: Bound
    public let upperBound: Bound

    public init(wrappedValue: Value, _ range: ClosedRange<Bound>) {
        self.wrappedValue = wrappedValue
        self.lowerBound = range.lowerBound
        self.upperBound = range.upperBound
    }
}

@propertyWrapper
public struct MaxCount<Value: Sendable>: Sendable {
    public var wrappedValue: Value
    public let maxCount: Int

    public init(wrappedValue: Value, _ maxCount: Int) {
        self.wrappedValue = wrappedValue
        self.maxCount = maxCount
    }
}

@propertyWrapper
public struct MinCount<Value: Sendable>: Sendable {
    public var wrappedValue: Value
    public let minCount: Int

    public init(wrappedValue: Value, _ minCount: Int) {
        self.wrappedValue = wrappedValue
        self.minCount = minCount
    }
}

@propertyWrapper
public struct OneOf<Value: Sendable>: Sendable {
    public var wrappedValue: Value
    public let values: [String]

    public init(wrappedValue: Value, _ values: [String]) {
        self.wrappedValue = wrappedValue
        self.values = values
    }
}

@propertyWrapper
public struct Description<Value: Sendable>: Sendable {
    public var wrappedValue: Value
    public let descriptionText: String

    public init(wrappedValue: Value, _ descriptionText: String) {
        self.wrappedValue = wrappedValue
        self.descriptionText = descriptionText
    }
}

@propertyWrapper
public struct Examples<Value: Sendable>: Sendable {
    public var wrappedValue: Value
    public let examples: [String]

    public init(wrappedValue: Value, _ examples: String...) {
        self.wrappedValue = wrappedValue
        self.examples = examples
    }
}
