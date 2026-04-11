import Foundation

// Stub CrashReporter — Sentry integration is compiled conditionally.
// To enable: add Sentry SPM dependency in project.yml and replace this file.

class CrashReporter {
    static let shared = CrashReporter()

    @UserDefaultsBacked(key: "crashReportingEnabled", defaultValue: true)
    var isEnabled: Bool

    private init() {}

    func initialize() {
        // TODO: Initialize SentrySDK when Sentry dependency is added
        // SentrySDK.start { options in
        //     options.dsn = VibeCodeConstants.sentryDSN
        // }
    }

    func addBreadcrumb(category: String, message: String) {
        // Stub: no-op without Sentry
    }

    func captureError(_ error: Error) {
        // Stub: no-op without Sentry
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }
}
