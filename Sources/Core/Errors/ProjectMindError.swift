import Foundation

public enum ProjectMindError: Error, Sendable, Equatable {
    case notImplemented(module: String)
    case projectNotFound(path: String)
    case invalidProjectPath(path: String)
    case scanFailed(path: String, underlying: String)
    case databaseNotOpen
    case databaseOpenFailed(path: String, underlying: String)
    case databaseExecuteFailed(underlying: String)
    case databaseQueryFailed(underlying: String)
    case fileNotFound(id: Int64)
    case migrationFailed(version: Int, underlying: String)
    case parseNotImplemented(parser: ParserKind)
    case parseFailed(path: String, underlying: String)
}
