import Foundation

/// Parses a scanned project file into structured source knowledge.
public protocol ParserProtocol: Sendable {
    /// The parser engine kind backing this implementation.
    var kind: ParserKind { get }

    /// Parses a single file and returns extracted symbols and imports.
    func parse(file: ProjectFile) async throws -> SourceFile
}
