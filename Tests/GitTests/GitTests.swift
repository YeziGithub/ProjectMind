import Core
import Git
import Testing

@Suite("GitProtocol")
struct GitProtocolTests {
    @Test("module conforms to GitProtocol")
    func conforms() {
        let git: any GitProtocol = GitModule()
        _ = git
    }

    @Test("stub throws not implemented")
    func notImplemented() async {
        let git = GitModule()
        let url = URL(fileURLWithPath: "/tmp")
        await #expect(throws: ProjectMindError.self) {
            _ = try await git.inspect(at: url)
        }
    }
}
