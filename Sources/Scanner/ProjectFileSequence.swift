import Core
import Foundation

/// Lazily streams `ProjectFile` values from a directory tree without loading all results into memory.
public struct ProjectFileSequence: AsyncSequence, Sendable {
  public typealias Element = ProjectFile
  public typealias AsyncIterator = Iterator

  private let root: URL
  private let configuration: ScannerConfiguration
  private let fileManager: FileManager

  public init(
    root: URL,
    configuration: ScannerConfiguration = .default,
    fileManager: FileManager = .default
  ) {
    self.root = root.standardizedFileURL
    self.configuration = configuration
    self.fileManager = fileManager
  }

  public func makeAsyncIterator() -> Iterator {
    Iterator(
      root: root,
      configuration: configuration,
      fileManager: fileManager
    )
  }

  public struct Iterator: AsyncIteratorProtocol {
    private let state: ScanState
    private var started = false

    init(
      root: URL,
      configuration: ScannerConfiguration,
      fileManager: FileManager
    ) {
      state = ScanState(
        root: root,
        configuration: configuration,
        fileManager: fileManager
      )
    }

    public mutating func next() async throws -> ProjectFile? {
      if !started {
        try state.prepare()
        started = true
      }

      guard let enumerator = state.enumerator else {
        return nil
      }

      let propertyKeys: Set<URLResourceKey> = [
        .isRegularFileKey,
        .isDirectoryKey,
        .isSymbolicLinkKey,
        .fileSizeKey,
        .contentModificationDateKey,
      ]

      while let item = enumerator.nextObject() as? URL {
        let values = try item.resourceValues(forKeys: propertyKeys)

        if values.isSymbolicLink == true, !state.configuration.followSymlinks {
          enumerator.skipDescendants()
          continue
        }

        if values.isDirectory == true {
          let directoryName = item.lastPathComponent
          if state.configuration.excludedDirectoryNames.contains(directoryName) {
            enumerator.skipDescendants()
          }
          continue
        }

        guard values.isRegularFile == true else {
          continue
        }

        let standardized = item.standardizedFileURL
        return ProjectFile(
          path: standardized.path,
          filename: standardized.deletingPathExtension().lastPathComponent,
          ext: standardized.pathExtension,
          size: Int64(values.fileSize ?? 0),
          modifiedDate: values.contentModificationDate ?? .distantPast
        )
      }

      state.enumerator = nil
      return nil
    }
  }
}

// MARK: - Internal State

private final class ScanState: @unchecked Sendable {
  let root: URL
  let configuration: ScannerConfiguration
  let fileManager: FileManager
  var enumerator: FileManager.DirectoryEnumerator?

  init(
    root: URL,
    configuration: ScannerConfiguration,
    fileManager: FileManager
  ) {
    self.root = root
    self.configuration = configuration
    self.fileManager = fileManager
  }

  func prepare() throws {
    var isDirectory: ObjCBool = false
    guard fileManager.fileExists(atPath: root.path, isDirectory: &isDirectory) else {
      throw ProjectMindError.projectNotFound(path: root.path)
    }
    guard isDirectory.boolValue else {
      throw ProjectMindError.invalidProjectPath(path: root.path)
    }

    var options: FileManager.DirectoryEnumerationOptions = []
    if !configuration.followSymlinks {
      options.insert(.skipsHiddenFiles)
      options.insert(.skipsPackageDescendants)
    }

    guard let enumerator = fileManager.enumerator(
      at: root,
      includingPropertiesForKeys: [
        .isRegularFileKey,
        .isDirectoryKey,
        .isSymbolicLinkKey,
        .fileSizeKey,
        .contentModificationDateKey,
      ],
      options: options
    ) else {
      throw ProjectMindError.scanFailed(
        path: root.path,
        underlying: "Failed to create directory enumerator"
      )
    }

    self.enumerator = enumerator
  }
}
