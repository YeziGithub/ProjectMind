import Foundation

/// A single schema migration step.
public protocol DatabaseMigration: Sendable {
    var version: Int { get }
    var statements: [String] { get }
}

/// Initial schema migration.
public struct InitialMigration: DatabaseMigration, Sendable {
    public let version = 1

    public init() {}

    public var statements: [String] {
        [
            SQLStatements.createSchemaMigrationsTable,
            SQLStatements.createFilesTable,
            SQLStatements.createFilesPathIndex,
            SQLStatements.createFilesExtIndex,
            SQLStatements.createFilesFilenameIndex,
        ]
    }
}
