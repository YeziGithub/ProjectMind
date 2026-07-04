import Core
import Foundation
import Scanner
import Testing

@Suite("SwiftProjectScanner")
struct SwiftProjectScannerTests {
    let scanner = SwiftProjectScanner()
    let fixtureRoot: URL

    init() {
        let thisFile = URL(fileURLWithPath: #filePath)
        fixtureRoot = thisFile
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/SampleProject")
            .standardizedFileURL
    }

    @Test("streams swift source files from sample project")
    func streamsSwiftFiles() async throws {
        let files = try await collectFiles(from: scanner.scan(at: fixtureRoot))
        let paths = Set(files.map(\.path))

        #expect(files.count == 3)
        #expect(paths.contains(where: { $0.hasSuffix("Package.swift") }))
        #expect(paths.contains(where: { $0.hasSuffix("Sources/SamplePackage/User.swift") }))
        #expect(paths.contains(where: { $0.hasSuffix("Sources/SamplePackage/Settings.swift") }))
    }

    @Test("excludes build and dependency directories")
    func excludesIgnoredDirectories() async throws {
        let files = try await collectFiles(from: scanner.scan(at: fixtureRoot))
        let paths = files.map(\.path)

        for path in paths {
            #expect(!path.contains("/.build/"))
            #expect(!path.contains("/.git/"))
            #expect(!path.contains("/DerivedData/"))
            #expect(!path.contains("/Pods/"))
            #expect(!path.contains("/Carthage/"))
            #expect(!path.contains("/.swiftpm/"))
        }
    }

    @Test("populates ProjectFile fields")
    func projectFileFields() async throws {
        let files = try await collectFiles(from: scanner.scan(at: fixtureRoot))
        let userFile = try #require(files.first { $0.filename == "User" })

        #expect(userFile.ext == "swift")
        #expect(userFile.path.hasSuffix("User.swift"))
        #expect(userFile.size > 0)
        #expect(userFile.modifiedDate.timeIntervalSince1970 > 0)
    }

    @Test("does not buffer all results before iteration")
    func streamsLazily() async throws {
        let sequence = scanner.scan(at: fixtureRoot)
        var iterator = sequence.makeAsyncIterator()

        let first = try await iterator.next()
        #expect(first != nil)

        let second = try await iterator.next()
        #expect(second != nil)
        #expect(second?.path != first?.path)
    }

    @Test("throws when project path does not exist")
    func missingPath() async {
        let url = URL(fileURLWithPath: "/nonexistent/projectmind/scanner/\(UUID().uuidString)")
        let sequence = scanner.scan(at: url)
        var iterator = sequence.makeAsyncIterator()

        await #expect(throws: ProjectMindError.self) {
            _ = try await iterator.next()
        }
    }

    @Test("throws when path is a file not a directory")
    func fileNotDirectory() async throws {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("projectmind-scanner-\(UUID().uuidString).swift")
        try "struct Temp {}".write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let sequence = scanner.scan(at: tempFile)
        var iterator = sequence.makeAsyncIterator()

        await #expect(throws: ProjectMindError.self) {
            _ = try await iterator.next()
        }
    }

    @Test("handles empty directory")
    func emptyDirectory() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("projectmind-empty-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let files = try await collectFiles(from: scanner.scan(at: tempDir))
        #expect(files.isEmpty)
    }

    @Test("scales with many files without collecting all upfront")
    func manyFiles() async throws {
        let tempDir = try makeManyFileFixture(count: 500)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        var count = 0
        for try await _ in scanner.scan(at: tempDir) {
            count += 1
            if count == 10 { break }
        }
        #expect(count == 10)

        let total = try await countFiles(in: scanner.scan(at: tempDir))
        #expect(total == 500)
    }

    @Test("default configuration excludes standard directories")
    func defaultConfiguration() {
        let config = ScannerConfiguration.default
        #expect(config.excludedDirectoryNames.contains(".build"))
        #expect(config.excludedDirectoryNames.contains(".git"))
        #expect(config.excludedDirectoryNames.contains("DerivedData"))
        #expect(config.excludedDirectoryNames.contains("Pods"))
        #expect(config.excludedDirectoryNames.contains("Carthage"))
        #expect(config.excludedDirectoryNames.contains(".swiftpm"))
    }

    @Test("custom configuration excludes additional directories")
    func customConfiguration() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("projectmind-custom-\(UUID().uuidString)")
        let vendorDir = tempDir.appendingPathComponent("Vendor")
        try FileManager.default.createDirectory(at: vendorDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try "struct Vendor {}".write(
            to: vendorDir.appendingPathComponent("Code.swift"),
            atomically: true,
            encoding: .utf8
        )
        try "struct App {}".write(
            to: tempDir.appendingPathComponent("App.swift"),
            atomically: true,
            encoding: .utf8
        )

        var config = ScannerConfiguration.default
        config = ScannerConfiguration(
            excludedDirectoryNames: config.excludedDirectoryNames.union(["Vendor"]),
            followSymlinks: config.followSymlinks
        )
        let customScanner = SwiftProjectScanner(configuration: config)

        let files = try await collectFiles(from: customScanner.scan(at: tempDir))
        #expect(files.count == 1)
        #expect(files.first?.filename == "App")
    }
}

// MARK: - Helpers

private func collectFiles(from sequence: ProjectFileSequence) async throws -> [ProjectFile] {
    var files: [ProjectFile] = []
    for try await file in sequence {
        files.append(file)
    }
    return files
}

private func countFiles(in sequence: ProjectFileSequence) async throws -> Int {
    var count = 0
    for try await _ in sequence {
        count += 1
    }
    return count
}

private func makeManyFileFixture(count: Int) throws -> URL {
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("projectmind-many-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

    for index in 0..<count {
        let subdirectory = tempDir.appendingPathComponent("Dir\(index % 20)")
        try FileManager.default.createDirectory(at: subdirectory, withIntermediateDirectories: true)
        let fileURL = subdirectory.appendingPathComponent("File\(index).swift")
        try "struct File\(index) {}".write(to: fileURL, atomically: true, encoding: .utf8)
    }

    return tempDir
}
