import Sparkle
import SwiftUI

/// Manages Sparkle software update lifecycle.
///
/// Wraps `SPUStandardUpdaterController` for SwiftUI consumption,
/// exposing reactive properties for update availability and preferences.
@MainActor
final class UpdaterController: ObservableObject {
  static let shared = UpdaterController()

  /// Whether the updater is currently able to check for updates.
  @Published var canCheckForUpdates = false

  /// Whether the app automatically checks for updates on launch.
  var automaticallyChecksForUpdates: Bool {
    get { updaterController.updater.automaticallyChecksForUpdates }
    set { updaterController.updater.automaticallyChecksForUpdates = newValue }
  }

  private let updaterController: SPUStandardUpdaterController

  private init() {
    updaterController = SPUStandardUpdaterController(
      startingUpdater: true,
      updaterDelegate: nil,
      userDriverDelegate: nil
    )

    updaterController.updater.publisher(for: \.canCheckForUpdates)
      .assign(to: &$canCheckForUpdates)
  }

  /// Triggers a user-initiated update check.
  func checkForUpdates() {
    updaterController.checkForUpdates(nil)
  }
}
