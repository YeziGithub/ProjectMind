import Foundation

/// Reads indexed project knowledge.
public protocol QueryProtocol: Sendable {
    /// Returns metadata for the indexed project, if available.
    func project() async throws -> Project?

    /// Searches symbols matching the given criteria.
    func symbols(matching query: SymbolQuery) async throws -> [SourceSymbol]

    /// Returns import references for a given file path.
    func imports(forFilePath path: String) async throws -> [ImportReference]
}
