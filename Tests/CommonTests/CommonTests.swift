import Common
import Testing

@Suite("Common")
struct CommonTests {
    @Test("module name")
    func moduleName() {
        #expect(CommonModule.name == "Common")
    }
}
