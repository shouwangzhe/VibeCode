import Foundation
import AppKit

/// Exports diagnostic information for troubleshooting
class DiagnosticExporter {

    struct DiagnosticData: Codable {
        let timestamp: String
        let sessionId: String
        let systemInfo: SystemInfo
        let appInfo: AppInfo
        let configuration: Configuration
        let logs: [String]

        struct SystemInfo: Codable {
            let osVersion: String
            let macModel: String
            let architecture: String
            let memory: String
        }

        struct AppInfo: Codable {
            let version: String
            let buildNumber: String
            let bundleId: String
        }

        struct Configuration: Codable {
            let launchAtLogin: Bool
            let soundsEnabled: Bool
            let hooksInstalled: Bool
            let activeSessions: Int
        }
    }

    static func exportDiagnostics() -> URL? {
        let data = collectDiagnosticData()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let jsonData = try? encoder.encode(data) else {
            showError("Failed to encode diagnostic data")
            return nil
        }

        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let filename = "vibecode-diagnostics-\(data.sessionId).json"
        let fileURL = desktopURL.appendingPathComponent(filename)

        do {
            try jsonData.write(to: fileURL)
            showSuccess("Diagnostics exported to Desktop: \(filename)")
            return fileURL
        } catch {
            showError("Failed to write diagnostic file: \(error.localizedDescription)")
            return nil
        }
    }

    private static func collectDiagnosticData() -> DiagnosticData {
        let sessionId = UUID().uuidString.prefix(8).lowercased()
        let timestamp = ISO8601DateFormatter().string(from: Date())

        return DiagnosticData(
            timestamp: timestamp,
            sessionId: String(sessionId),
            systemInfo: collectSystemInfo(),
            appInfo: collectAppInfo(),
            configuration: collectConfiguration(),
            logs: collectLogs()
        )
    }

    private static func collectSystemInfo() -> DiagnosticData.SystemInfo {
        let processInfo = ProcessInfo.processInfo
        let osVersion = processInfo.operatingSystemVersionString
        let architecture = processInfo.machineHardwareName ?? "unknown"

        let memory = ByteCountFormatter.string(
            fromByteCount: Int64(processInfo.physicalMemory),
            countStyle: .memory
        )

        return DiagnosticData.SystemInfo(
            osVersion: osVersion,
            macModel: getMacModel(),
            architecture: architecture,
            memory: memory
        )
    }

    private static func getMacModel() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }

    private static func collectAppInfo() -> DiagnosticData.AppInfo {
        let bundle = Bundle.main
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let buildNumber = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        let bundleId = bundle.bundleIdentifier ?? "unknown"

        return DiagnosticData.AppInfo(
            version: version,
            buildNumber: buildNumber,
            bundleId: bundleId
        )
    }

    private static func collectConfiguration() -> DiagnosticData.Configuration {
        return DiagnosticData.Configuration(
            launchAtLogin: LaunchAtLoginService.shared.isEnabled,
            soundsEnabled: SoundService.shared.isEnabled,
            hooksInstalled: FileManager.default.fileExists(atPath: VibeCodeConstants.claudeSettingsPath),
            activeSessions: 0 // TODO: Get from SessionManager singleton
        )
    }

    private static func collectLogs() -> [String] {
        let logPath = "/tmp/vibecode-ipc.log"
        guard FileManager.default.fileExists(atPath: logPath),
              let logContent = try? String(contentsOfFile: logPath, encoding: .utf8) else {
            return ["No logs available"]
        }

        let lines = logContent.components(separatedBy: .newlines)
        let recentLines = Array(lines.suffix(500))
        return recentLines.filter { !$0.isEmpty }
    }

    private static func showSuccess(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Success"
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private static func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    static func clearLogs() {
        let logPath = "/tmp/vibecode-ipc.log"
        try? FileManager.default.removeItem(atPath: logPath)
        showSuccess("Logs cleared successfully")
    }
}

extension ProcessInfo {
    var machineHardwareName: String? {
        var sysinfo = utsname()
        let result = uname(&sysinfo)
        guard result == EXIT_SUCCESS else { return nil }
        let data = Data(bytes: &sysinfo.machine, count: Int(_SYS_NAMELEN))
        guard let identifier = String(bytes: data, encoding: .ascii) else { return nil }
        return identifier.trimmingCharacters(in: .controlCharacters)
    }
}
