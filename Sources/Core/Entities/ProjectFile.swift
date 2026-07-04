import Foundation

/// A file discovered during project scanning.
public struct ProjectFile: Sendable, Equatable, Hashable, Identifiable {
    public var id: String { path }

    public let path: String
    public let filename: String
    public let ext: String
    public let size: Int64
    public let modifiedDate: Date

    public init(
        path: String,
        filename: String,
        ext: String,
        size: Int64,
        modifiedDate: Date
    ) {
        self.path = path
        self.filename = filename
        self.ext = ext
        self.size = size
        self.modifiedDate = modifiedDate
    }
}
