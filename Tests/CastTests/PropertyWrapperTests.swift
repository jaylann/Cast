@testable import Cast
import Foundation
import Testing

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
    func maxLengthMirror() throws {
        let mirror = Mirror(reflecting: instance)
        let child = try #require(mirror.children.first { $0.label == "_title" })
        let wrapper = try #require(child.value as? MaxLength<String>)
        #expect(wrapper.maxLength == 100)
    }

    @Test("MinLength constraint readable via Mirror")
    func minLengthMirror() throws {
        let mirror = Mirror(reflecting: instance)
        let child = try #require(mirror.children.first { $0.label == "_name" })
        let wrapper = try #require(child.value as? MinLength<String>)
        #expect(wrapper.minLength == 1)
    }

    @Test("CastRange constraint readable via Mirror")
    func castRangeMirror() throws {
        let mirror = Mirror(reflecting: instance)
        let child = try #require(mirror.children.first { $0.label == "_rating" })
        let wrapper = try #require(child.value as? CastRange<Int, Int>)
        #expect(wrapper.lowerBound == 1)
        #expect(wrapper.upperBound == 10)
    }

    @Test("MaxCount constraint readable via Mirror")
    func maxCountMirror() throws {
        let mirror = Mirror(reflecting: instance)
        let child = try #require(mirror.children.first { $0.label == "_tags" })
        let wrapper = try #require(child.value as? MaxCount<[String]>)
        #expect(wrapper.maxCount == 5)
    }

    @Test("MinCount constraint readable via Mirror")
    func minCountMirror() throws {
        let mirror = Mirror(reflecting: instance)
        let child = try #require(mirror.children.first { $0.label == "_items" })
        let wrapper = try #require(child.value as? MinCount<[String]>)
        #expect(wrapper.minCount == 1)
    }

    @Test("OneOf constraint readable via Mirror")
    func oneOfMirror() throws {
        let mirror = Mirror(reflecting: instance)
        let child = try #require(mirror.children.first { $0.label == "_currency" })
        let wrapper = try #require(child.value as? OneOf<String>)
        #expect(wrapper.values == ["USD", "EUR"])
    }

    @Test("Description constraint readable via Mirror")
    func descriptionMirror() throws {
        let mirror = Mirror(reflecting: instance)
        let child = try #require(mirror.children.first { $0.label == "_summary" })
        let wrapper = try #require(child.value as? Description<String>)
        #expect(wrapper.descriptionText == "A description")
    }

    @Test("Examples constraint readable via Mirror")
    func examplesMirror() throws {
        let mirror = Mirror(reflecting: instance)
        let child = try #require(mirror.children.first { $0.label == "_review" })
        let wrapper = try #require(child.value as? Examples<String>)
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
