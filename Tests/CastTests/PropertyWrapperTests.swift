import Foundation
import Testing

@testable import Cast

struct TestStruct {
    @MaxLength(100) var title: String = ""
    @MinLength(1) var name: String = ""
    @CastRange(1...10) var rating: Int = 0
    @MaxCount(5) var tags: [String] = []
    @MinCount(1) var items: [String] = []
    @OneOf(["USD", "EUR"]) var currency: String = ""
    @Description("A description") var summary: String = ""
    @Examples("Good", "Bad") var review: String = ""
}

@Suite("PropertyWrappers")
struct PropertyWrapperTests {

    let instance = TestStruct()

    // MARK: - Mirror constraint detection

    @Test("MaxLength constraint readable via Mirror")
    func maxLengthMirror() {
        let mirror = Mirror(reflecting: instance)
        let child = mirror.children.first { $0.label == "_title" }!
        let wrapper = child.value as! MaxLength<String>
        #expect(wrapper.maxLength == 100)
    }

    @Test("MinLength constraint readable via Mirror")
    func minLengthMirror() {
        let mirror = Mirror(reflecting: instance)
        let child = mirror.children.first { $0.label == "_name" }!
        let wrapper = child.value as! MinLength<String>
        #expect(wrapper.minLength == 1)
    }

    @Test("CastRange constraint readable via Mirror")
    func castRangeMirror() {
        let mirror = Mirror(reflecting: instance)
        let child = mirror.children.first { $0.label == "_rating" }!
        let wrapper = child.value as! CastRange<Int, Int>
        #expect(wrapper.lowerBound == 1)
        #expect(wrapper.upperBound == 10)
    }

    @Test("MaxCount constraint readable via Mirror")
    func maxCountMirror() {
        let mirror = Mirror(reflecting: instance)
        let child = mirror.children.first { $0.label == "_tags" }!
        let wrapper = child.value as! MaxCount<[String]>
        #expect(wrapper.maxCount == 5)
    }

    @Test("MinCount constraint readable via Mirror")
    func minCountMirror() {
        let mirror = Mirror(reflecting: instance)
        let child = mirror.children.first { $0.label == "_items" }!
        let wrapper = child.value as! MinCount<[String]>
        #expect(wrapper.minCount == 1)
    }

    @Test("OneOf constraint readable via Mirror")
    func oneOfMirror() {
        let mirror = Mirror(reflecting: instance)
        let child = mirror.children.first { $0.label == "_currency" }!
        let wrapper = child.value as! OneOf<String>
        #expect(wrapper.values == ["USD", "EUR"])
    }

    @Test("Description constraint readable via Mirror")
    func descriptionMirror() {
        let mirror = Mirror(reflecting: instance)
        let child = mirror.children.first { $0.label == "_summary" }!
        let wrapper = child.value as! Description<String>
        #expect(wrapper.descriptionText == "A description")
    }

    @Test("Examples constraint readable via Mirror")
    func examplesMirror() {
        let mirror = Mirror(reflecting: instance)
        let child = mirror.children.first { $0.label == "_review" }!
        let wrapper = child.value as! Examples<String>
        #expect(wrapper.examples == ["Good", "Bad"])
    }

    // MARK: - WrappedValue access

    @Test("wrappedValue read and write")
    func wrappedValueAccess() {
        var s = TestStruct()

        s.title = "Hello"
        #expect(s.title == "Hello")

        s.name = "World"
        #expect(s.name == "World")

        s.rating = 5
        #expect(s.rating == 5)

        s.tags = ["a", "b"]
        #expect(s.tags == ["a", "b"])

        s.items = ["x"]
        #expect(s.items == ["x"])

        s.currency = "EUR"
        #expect(s.currency == "EUR")

        s.summary = "Updated"
        #expect(s.summary == "Updated")

        s.review = "Excellent"
        #expect(s.review == "Excellent")
    }
}
