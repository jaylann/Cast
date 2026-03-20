import Testing
@testable import Cast

@Test func testNewModelIsNotLoaded() {
    let model = CastModel()
    #expect(model.isLoaded == false)
    #expect(model.container == nil)
}

@Test func testUnloadSetsContainerToNil() {
    let model = CastModel()
    model.unload()
    #expect(model.isLoaded == false)
    #expect(model.container == nil)
}
