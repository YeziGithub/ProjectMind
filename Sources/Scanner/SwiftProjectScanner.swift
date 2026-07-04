import Core
import Foundation

/// Streams files from a Swift project directory tree.
public struct SwiftProjectScanner: ScannerProtocol, Sendable {
  private let configuration: ScannerConfiguration
  private let fileManager: FileManager

  public init(
    configuration: ScannerConfiguration = .default,
    fileManager: FileManager = .default
  ) {
    self.configuration = configuration
    self.fileManager = fileManager
  }

  public func scan(at url: URL) -> ProjectFileSequence {
    ProjectFileSequence(
      root: url,
      configuration: configuration,
      fileManager: fileManager
    )
  }
}
