import Core
import Foundation

public struct QueryModule: QueryProtocol, Sendable {
    public init() {}

    public func project() async throws -> Project? {
        throw ProjectMindError.notImplemented(module: "Query")
    }

    public func symbols(matching query: SymbolQuery) async throws -> [SourceSymbol] {
        throw ProjectMindError.notImplemented(module: "Query")
    }

    public func imports(forFilePath path: String) async throws -> [ImportReference] {
        throw ProjectMindError.notImplemented(module: "Query")
    }
}
