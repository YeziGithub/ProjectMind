import Foundation

/// A project file persisted in the database.
public struct StoredFile: Sendable, Equatable, Identifiable {
    public let id: Int64
    public let path: String
    public let filename: String
    public let ext: String
    public let size: Int64
    public let modifiedDate: Date

    public init(
        id: Int64,
        path: String,
        filename: String,
        ext: String,
        size: Int64,
        modifiedDate: Date
    ) {
        self.id = id
        self.path = path
        self.filename = filename
        self.ext = ext
        self.size = size
        self.modifiedDate = modifiedDate
    }

    public var asProjectFile: ProjectFile {
        ProjectFile(
            path: path,
            filename: filename,
            ext: ext,
            size: size,
            modifiedDate: modifiedDate
        )
    }
}
