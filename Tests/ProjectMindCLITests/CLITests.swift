import Core
import Database
import Foundation
import Testing
@testable import ProjectMindCLI

@Suite("ProjectMindCLI")
struct CLITests {
    @Test("parses scan path")
    func parsesScanPath() throws {
        let command = try CommandParser().parse(["scan", "/tmp/project"])
        #expect(command == .scan(ScanCommandOptions(projectPath: "/tmp/project", databasePath: nil)))
    }

    @Test("parses scan path with db")
    func parsesScanPathWithDatabase() throws {
        let command = try CommandParser().parse([
            "scan",
            "/tmp/project",
            "--db",
            "/tmp/projectmind.sqlite",
        ])
        #expect(command == .scan(
            ScanCommandOptions(projectPath: "/tmp/project", databasePath: "/tmp/projectmind.sqlite")
        ))
    }

    @Test("scan requires path")
    func scanRequiresPath() {
        #expect(throws: CommandParserError.self) {
            _ = try CommandParser().parse(["scan"])
        }
    }

    @Test("db requires value")
    func databaseOptionRequiresValue() {
        #expect(throws: CommandParserError.self) {
            _ = try CommandParser().parse(["scan", "/tmp/project", "--db"])
        }
    }

    @Test("runner scans fixture into database")
    func runnerScansFixtureIntoDatabase() async throws {
        let fixture = fixtureProjectURL()
        let databaseURL = try makeTempDatabaseURL()
        let result = try await ScanCommandRunner().run(options: ScanCommandOptions(
            projectPath: fixture.path,
            databasePath: databaseURL.path
        ))

        #expect(result.scannedFileCount == 3)
        #expect(result.indexedFileCount == 3)
        #expect(result.databasePath == databaseURL.standardizedFileURL.path)

        let files = try await readFiles(at: databaseURL)
        #expect(files.count == 3)
        #expect(files.contains { $0.path.hasSuffix("Package.swift") })
        #expect(files.contains { $0.path.hasSuffix("Sources/SamplePackage/User.swift") })
        #expect(files.contains { $0.path.hasSuffix("Sources/SamplePackage/Settings.swift") })

        try? FileManager.default.removeItem(at: databaseURL.deletingLastPathComponent())
    }

    @Test("runner rejects invalid path")
    func runnerRejectsInvalidPath() async {
        await #expect(throws: ScanCommandError.self) {
            _ = try await ScanCommandRunner().run(options: ScanCommandOptions(
                projectPath: "/nonexistent/projectmind/\(UUID().uuidString)",
                databasePath: nil
            ))
        }
    }

    @Test("runner uses default database path")
    func runnerUsesDefaultDatabasePath() async throws {
        let projectURL = try makeTempProject()
        let result = try await ScanCommandRunner().run(options: ScanCommandOptions(
            projectPath: projectURL.path,
            databasePath: nil
        ))

        #expect(result.databasePath.hasSuffix(".projectmind/projectmind.sqlite"))
        #expect(result.scannedFileCount == 2)
        #expect(result.indexedFileCount == 2)

        let files = try await readFiles(at: URL(fileURLWithPath: result.databasePath))
        #expect(files.count == 2)
        #expect(!files.contains { $0.path.contains("/.projectmind/") })

        try? FileManager.default.removeItem(at: projectURL)
    }

    @Test("runner supports repeated scan")
    func runnerSupportsRepeatedScan() async throws {
        let fixture = fixtureProjectURL()
        let databaseURL = try makeTempDatabaseURL()
        let options = ScanCommandOptions(projectPath: fixture.path, databasePath: databaseURL.path)

        _ = try await ScanCommandRunner().run(options: options)
        _ = try await ScanCommandRunner().run(options: options)

        let files = try await readFiles(at: databaseURL)
        #expect(files.count == 3)

        try? FileManager.default.removeItem(at: databaseURL.deletingLastPathComponent())
    }
}

private func fixtureProjectURL() -> URL {
    let thisFile = URL(fileURLWithPath: #filePath)
    return thisFile
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("ScannerTests/Fixtures/SampleProject")
        .standardizedFileURL
}

private func makeTempDatabaseURL() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("projectmind-cli-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory.appendingPathComponent("projectmind.sqlite")
}

private func makeTempProject() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("projectmind-project-\(UUID().uuidString)", isDirectory: true)
    let sources = directory.appendingPathComponent("Sources", isDirectory: true)
    try FileManager.default.createDirectory(at: sources, withIntermediateDirectories: true)
    try "struct App {}".write(
        to: directory.appendingPathComponent("Package.swift"),
        atomically: true,
        encoding: .utf8
    )
    try "struct User {}".write(
        to: sources.appendingPathComponent("User.swift"),
        atomically: true,
        encoding: .utf8
    )
    return directory
}

private func readFiles(at url: URL) async throws -> [StoredFile] {
    let database = SQLiteDatabase()
    try await database.open(at: url)
    try await database.createTables()
    let files = try await database.query(FileQuery(limit: 100, offset: 0))
    try await database.close()
    return files
}
