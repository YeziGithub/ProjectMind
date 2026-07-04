import Core
import Query
import Testing

@Suite("QueryProtocol")
struct QueryProtocolTests {
    @Test("module conforms to QueryProtocol")
    func conforms() {
        let query: any QueryProtocol = QueryModule()
        _ = query
    }

    @Test("stub throws not implemented")
    func notImplemented() async {
        let query = QueryModule()
        await #expect(throws: ProjectMindError.self) {
            _ = try await query.symbols(matching: SymbolQuery())
        }
    }
}
