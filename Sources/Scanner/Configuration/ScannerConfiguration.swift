import Foundation

/// Controls directory traversal and filtering during project scanning.
public struct ScannerConfiguration: Sendable, Equatable {
  public let excludedDirectoryNames: Set<String>
  public let followSymlinks: Bool

  public static let `default` = ScannerConfiguration(
    excludedDirectoryNames: [
      ".build",
      ".git",
      "DerivedData",
      "Pods",
      "Carthage",
      ".swiftpm",
    ],
    followSymlinks: false
  )

  public init(
    excludedDirectoryNames: Set<String>,
    followSymlinks: Bool = false
  ) {
    self.excludedDirectoryNames = excludedDirectoryNames
    self.followSymlinks = followSymlinks
  }
}
