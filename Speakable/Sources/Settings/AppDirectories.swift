import Foundation

/// Centralized directory management for app storage.
/// All directories are automatically separated by Bundle ID (Debug vs Release).
enum AppDirectories {
  /// Bundle identifier used as directory name
  /// - Debug: sh.lennon.Speakable.debug
  /// - Release: sh.lennon.Speakable
  static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "sh.lennon.Speakable"

  /// Application Support directory
  /// ~/Library/Application Support/{bundleId}/
  static var applicationSupport: URL {
    let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
      .appendingPathComponent(bundleIdentifier, isDirectory: true)
    createDirectoryIfNeeded(url)
    return url
  }

  /// Logs directory
  /// ~/Library/Logs/{bundleId}/
  static var logs: URL {
    let url = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
      .appendingPathComponent("Logs", isDirectory: true)
      .appendingPathComponent(bundleIdentifier, isDirectory: true)
    createDirectoryIfNeeded(url)
    return url
  }

  /// Caches directory
  /// ~/Library/Caches/{bundleId}/
  static var caches: URL {
    let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
      .appendingPathComponent(bundleIdentifier, isDirectory: true)
    createDirectoryIfNeeded(url)
    return url
  }

  /// Temporary directory (already sandboxed by system)
  static var temporary: URL {
    FileManager.default.temporaryDirectory
  }

  // MARK: - Private

  private static func createDirectoryIfNeeded(_ url: URL) {
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
  }
}
