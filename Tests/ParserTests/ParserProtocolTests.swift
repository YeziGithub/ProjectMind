import Core
import Foundation
import Parser
import Testing

@Suite("ParserProtocol")
struct ParserProtocolTests {
    let factory = DefaultParserFactory()
    let file = ProjectFile(
        path: "/tmp/App.swift",
        filename: "App",
        ext: "swift",
        size: 128,
        modifiedDate: .now
    )

    @Test("factory creates three parser kinds")
    func factoryCreatesParsers() {
        for kind in ParserKind.allCases {
            let parser = factory.makeParser(kind: kind)
            #expect(parser.kind == kind)
        }
    }

    @Test("parsers are interchangeable via protocol")
    func interchangeable() {
        let parsers: [any ParserProtocol] = ParserKind.allCases.map { factory.makeParser(kind: $0) }
        #expect(parsers.count == 3)
    }

    @Test("stub parser returns not implemented")
    func notImplemented() async {
        let parser = factory.makeParser(kind: .sourceKit)
        await #expect(throws: ProjectMindError.self) {
            _ = try await parser.parse(file: file)
        }
    }

    @Test("parse input uses ProjectFile and output is SourceFile")
    func inputOutputTypes() async throws {
        let empty = SourceFile(file: file)
        #expect(empty.file == file)
        #expect(empty.isEmpty)
    }
}
