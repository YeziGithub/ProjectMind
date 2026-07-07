import Core
import Database
import Foundation
import Testing

@Suite("SQLiteDatabase")
struct SQLiteDatabaseTests {
    @Test("creates tables via migration")
    func createTables() async throws {
        try await withDatabase { database in
            try await database.createTables()
            let id = try await database.insertFile(sampleFile(name: "App"))
            #expect(id > 0)
        }
    }

    @Test("inserts and queries file")
    func insertAndQuery() async throws {
        try await withDatabase { database in
            try await database.createTables()
            let file = sampleFile(name: "User", ext: "swift", size: 256)
            let id = try await database.insertFile(file)

            let results = try await database.query(FileQuery(path: file.path))
            #expect(results.count == 1)
            #expect(results.first?.id == id)
            #expect(results.first?.filename == "User")
            #expect(results.first?.ext == "swift")
            #expect(results.first?.size == 256)
            #expect(results.first?.asProjectFile == file)
        }
    }

    @Test("updates file")
    func updateFile() async throws {
        try await withDatabase { database in
            try await database.createTables()
            let id = try await database.insertFile(sampleFile(name: "Old"))

            let updated = sampleFile(name: "New", size: 512)
            try await database.updateFile(id: id, file: updated)

            let results = try await database.query(FileQuery(filename: "New"))
            #expect(results.count == 1)
            #expect(results.first?.size == 512)
        }
    }

    @Test("deletes file")
    func deleteFile() async throws {
        try await withDatabase { database in
            try await database.createTables()
            let file = sampleFile(name: "DeleteMe")
            let id = try await database.insertFile(file)

            try await database.deleteFile(id: id)

            let results = try await database.query(FileQuery(path: file.path))
            #expect(results.isEmpty)
        }
    }

    @Test("query filters by extension")
    func queryByExtension() async throws {
        try await withDatabase { database in
            try await database.createTables()
            _ = try await database.insertFile(sampleFile(name: "A", ext: "swift"))
            _ = try await database.insertFile(sampleFile(name: "B", ext: "md"))

            let swiftFiles = try await database.query(FileQuery(ext: "swift"))
            #expect(swiftFiles.count == 1)
            #expect(swiftFiles.first?.filename == "A")
        }
    }

    @Test("query supports limit and offset")
    func queryPagination() async throws {
        try await withDatabase { database in
            try await database.createTables()
            for index in 0..<5 {
                _ = try await database.insertFile(sampleFile(name: "File\(index)"))
            }

            let page = try await database.query(FileQuery(limit: 2, offset: 2))
            #expect(page.count == 2)
            #expect(page.first?.filename == "File2")
        }
    }

    @Test("enforces unique path constraint")
    func uniquePath() async throws {
        try await withDatabase { database in
            try await database.createTables()
            let file = sampleFile(name: "Duplicate")
            _ = try await database.insertFile(file)

            await #expect(throws: ProjectMindError.self) {
                _ = try await database.insertFile(file)
            }
        }
    }

    @Test("update throws when file not found")
    func updateMissingFile() async throws {
        try await withDatabase { database in
            try await database.createTables()

            await #expect(throws: ProjectMindError.self) {
                try await database.updateFile(id: 9_999, file: sampleFile(name: "Missing"))
            }
        }
    }

    @Test("delete throws when file not found")
    func deleteMissingFile() async throws {
        try await withDatabase { database in
            try await database.createTables()

            await #expect(throws: ProjectMindError.self) {
                try await database.deleteFile(id: 9_999)
            }
        }
    }

    @Test("operations throw when database is not open")
    func notOpen() async {
        let database = SQLiteDatabase()

        await #expect(throws: ProjectMindError.self) {
            try await database.createTables()
        }
    }

    @Test("transaction commits on success")
    func transactionCommit() async throws {
        try await withDatabase { database in
            try await database.createTables()

            let id = try await database.transaction {
                try await database.insertFile(sampleFile(name: "Tx"))
            }

            let results = try await database.query(FileQuery(filename: "Tx"))
            #expect(results.first?.id == id)
        }
    }

    @Test("transaction rolls back on failure")
    func transactionRollback() async throws {
        try await withDatabase { database in
            try await database.createTables()

            await #expect(throws: ProjectMindError.self) {
                try await database.transaction {
                    _ = try await database.insertFile(sampleFile(name: "Rollback"))
                    throw ProjectMindError.databaseExecuteFailed(underlying: "forced failure")
                }
            }

            let results = try await database.query(FileQuery(filename: "Rollback"))
            #expect(results.isEmpty)
        }
    }

    @Test("migrations are idempotent")
    func migrationIdempotent() async throws {
        try await withDatabase { database in
            try await database.createTables()
            try await database.createTables()

            let id = try await database.insertFile(sampleFile(name: "AfterSecondMigration"))
            #expect(id > 0)
        }
    }
}

@Suite("DatabaseMigration")
struct DatabaseMigrationTests {
    @Test("initial migration version")
    func initialMigrationVersion() {
        let migration = InitialMigration()
        #expect(migration.version == 1)
        #expect(!migration.statements.isEmpty)
    }

    @Test("custom migration can be injected")
    func customMigration() async throws {
        struct TestMigration: DatabaseMigration {
            let version = 2
            var statements: [String] {
                ["""
                CREATE TABLE IF NOT EXISTS tags (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    name TEXT NOT NULL UNIQUE
                );
                """]
            }
        }

        try await withDatabase(migrations: [InitialMigration(), TestMigration()]) { database in
            try await database.createTables()
            try await database.createTables()
        }

        // Second migration should not fail when re-run.
        #expect(true)
    }
}

// MARK: - Helpers

private func makeTempDatabaseURL() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("projectmind-db-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory.appendingPathComponent("index.sqlite")
}

private func withDatabase<T>(
    migrations: [any DatabaseMigration]? = nil,
    _ body: (SQLiteDatabase) async throws -> T
) async throws -> T {
    let database: SQLiteDatabase
    if let migrations {
        database = SQLiteDatabase(migrations: migrations)
    } else {
        database = SQLiteDatabase()
    }
    let url = try makeTempDatabaseURL()

    do {
        try await database.open(at: url)
        let result = try await body(database)
        try? await database.close()
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
        return result
    } catch {
        try? await database.close()
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
        throw error
    }
}

private func sampleFile(
    name: String,
    ext: String = "swift",
    size: Int64 = 128
) -> ProjectFile {
    let path = "/tmp/projectmind/\(name).\(ext)"
    return ProjectFile(
        path: path,
        filename: name,
        ext: ext,
        size: size,
        modifiedDate: Date(timeIntervalSince1970: 1_700_000_000)
    )
}
