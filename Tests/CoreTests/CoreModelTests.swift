import Foundation
import Testing

@Suite("Core Models")
struct CoreModelTests {
    @Test("Project identity")
    func project() {
        let project = Project(
            id: "p1",
            rootPath: "/tmp/MyApp",
            name: "MyApp",
            kind: .swiftPackage
        )
        #expect(project.id == "p1")
        #expect(project.name == "MyApp")
    }

    @Test("ProjectFile identity")
    func projectFile() {
        let file = ProjectFile(
            path: "/tmp/App.swift",
            filename: "App",
            ext: "swift",
            size: 100,
            modifiedDate: .now
        )
        #expect(file.id == file.path)
    }

    @Test("SourceFile groups symbols and imports")
    func sourceFile() {
        let file = ProjectFile(
            path: "/tmp/App.swift",
            filename: "App",
            ext: "swift",
            size: 100,
            modifiedDate: .now
        )
        let source = SourceFile(
            file: file,
            symbols: [
                SourceSymbol(id: "s1", name: "App", kind: .class, filePath: file.path),
                SourceSymbol(id: "s2", name: "run", kind: .function, filePath: file.path),
            ],
            imports: [
                ImportReference(id: "i1", moduleName: "Foundation", filePath: file.path),
            ]
        )
        #expect(source.declarationCount == 3)
        #expect(source.symbols(ofKind: .class).count == 1)
    }

    @Test("SourceSymbol kinds")
    func symbolKinds() {
        #expect(SymbolKind.class.rawValue == "class")
        #expect(SymbolKind.function.rawValue == "function")
        #expect(SymbolKind.protocol.rawValue == "protocol")
    }

    @Test("ImportReference")
    func importReference() {
        let ref = ImportReference(
            id: "i1",
            moduleName: "Foundation",
            filePath: "/tmp/App.swift"
        )
        #expect(ref.moduleName == "Foundation")
    }

    @Test("StoredFile converts to ProjectFile")
    func storedFileConversion() {
        let stored = StoredFile(
            id: 1,
            path: "/tmp/Foo.swift",
            filename: "Foo",
            ext: "swift",
            size: 100,
            modifiedDate: Date(timeIntervalSince1970: 1_000)
        )
        #expect(stored.asProjectFile.path == stored.path)
    }

    @Test("SymbolQuery defaults")
    func symbolQueryDefaults() {
        let query = SymbolQuery()
        #expect(query.limit == 100)
        #expect(query.name == nil)
    }

    @Test("GitMetadata")
    func gitMetadata() {
        let meta = GitMetadata(rootPath: "/repo", branch: "main", isDirty: false)
        #expect(meta.branch == "main")
    }
}

@Suite("Core Protocols Compile")
struct CoreProtocolTests {
    @Test("protocols are available")
    func protocolsExist() {
        // Compile-time check that all five port protocols are part of Core.
        let _: any ScannerProtocol.Type = SwiftProjectScannerPlaceholder.self
        let _: any ParserProtocol.Type = ParserProtocolPlaceholder.self
        let _: any DatabaseProtocol.Type = DatabaseProtocolPlaceholder.self
        let _: any QueryProtocol.Type = QueryProtocolPlaceholder.self
        let _: any GitProtocol.Type = GitProtocolPlaceholder.self
    }
}

// MARK: - Compile-time placeholders

private struct SwiftProjectScannerPlaceholder: ScannerProtocol {
    struct Files: AsyncSequence, Sendable {
        typealias Element = ProjectFile
        struct Iterator: AsyncIteratorProtocol {
            mutating func next() async throws -> ProjectFile? { nil }
        }
        func makeAsyncIterator() -> Iterator { Iterator() }
    }
    func scan(at url: URL) -> Files { Files() }
}

private struct ParserProtocolPlaceholder: ParserProtocol {
    let kind: ParserKind = .swiftSyntax
    func parse(file: ProjectFile) async throws -> SourceFile { SourceFile(file: file) }
}

private actor DatabaseProtocolPlaceholder: DatabaseProtocol {
    func open(at url: URL) async throws {}
    func close() async throws {}
    func createTables() async throws {}
    func insertFile(_ file: ProjectFile) async throws -> Int64 { 0 }
    func updateFile(id: Int64, file: ProjectFile) async throws {}
    func deleteFile(id: Int64) async throws {}
    func query(_ query: FileQuery) async throws -> [StoredFile] { [] }
    func transaction<T: Sendable>(_ operation: @Sendable () async throws -> T) async throws -> T {
        try await operation()
    }
}

private struct QueryProtocolPlaceholder: QueryProtocol {
    func project() async throws -> Project? { nil }
    func symbols(matching query: SymbolQuery) async throws -> [SourceSymbol] { [] }
    func imports(forFilePath path: String) async throws -> [ImportReference] { [] }
}

private struct GitProtocolPlaceholder: GitProtocol {
    func inspect(at url: URL) async throws -> GitMetadata {
        GitMetadata(rootPath: url.path)
    }
}
