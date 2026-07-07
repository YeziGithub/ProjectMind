import Core
import Foundation

/// Base behavior shared by parser engine stubs.
public protocol ParserStub: ParserProtocol {
    var kind: ParserKind { get }
}

extension ParserStub {
    public func parse(file: ProjectFile) async throws -> SourceFile {
        throw ProjectMindError.parseNotImplemented(parser: kind)
    }
}
