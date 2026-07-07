import Foundation

/// SQLite persistence port for project knowledge.
public protocol DatabaseProtocol: Sendable {
    func open(at url: URL) async throws
    func close() async throws
    func createTables() async throws
    func insertFile(_ file: ProjectFile) async throws -> Int64
    func upsertFile(_ file: ProjectFile) async throws
    func updateFile(id: Int64, file: ProjectFile) async throws
    func deleteFile(id: Int64) async throws
    func query(_ query: FileQuery) async throws -> [StoredFile]
    func upsertSourceFile(_ sourceFile: SourceFile) async throws
    func querySymbols(_ query: SymbolQuery) async throws -> [SourceSymbol]
    func queryImports(filePath: String?) async throws -> [ImportReference]
    func deleteSourceFile(filePath: String) async throws
    func transaction<T: Sendable>(
        _ operation: @Sendable () async throws -> T
    ) async throws -> T
}
