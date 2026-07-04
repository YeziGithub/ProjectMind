import Core
import Testing

@Suite("Core")
struct CoreTests {
    @Test("error cases")
    func errorCases() {
        let notFound = ProjectMindError.projectNotFound(path: "/tmp")
        let invalid = ProjectMindError.invalidProjectPath(path: "/tmp")
        #expect(notFound == .projectNotFound(path: "/tmp"))
        #expect(invalid == .invalidProjectPath(path: "/tmp"))
    }
}
