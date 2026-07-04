import Core
import Foundation

/// Base behavior shared by parser engine stubs.
protocol ParserStub: ParserProtocol {
    var kind: ParserKind { get }
}

extension ParserStub {
    func parse(file: ProjectFile) async throws -> SourceFile {
        throw ProjectMindError.parseNotImplemented(parser: kind)
    }
}
