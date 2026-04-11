import Foundation
// import Sparkle

/// Manages app updates using Sparkle framework
/// TODO: Re-enable when Sparkle framework is properly integrated
class UpdateService {
    static let shared = UpdateService()

    // private let updaterController: SPUStandardUpdaterController

    private init() {
        // updaterController = SPUStandardUpdaterController(
        //     startingUpdater: true,
        //     updaterDelegate: nil,
        //     userDriverDelegate: nil
        // )
    }

    /// Check for updates manually
    func checkForUpdates() {
        // updaterController.checkForUpdates(nil)
        print("Update checking temporarily disabled - Sparkle framework not integrated")
    }

    // /// Get the updater instance
    // var updater: SPUUpdater {
    //     updaterController.updater
    // }
    //
    // /// Check if automatic update checks are enabled
    // var automaticallyChecksForUpdates: Bool {
    //     get { updater.automaticallyChecksForUpdates }
    //     set { updater.automaticallyChecksForUpdates = newValue }
    // }
}
