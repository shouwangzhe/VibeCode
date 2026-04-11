import SwiftUI

struct SettingsView: View {

    @State private var launchAtLogin = LaunchAtLoginService.shared.isEnabled
    @State private var soundsEnabled = SoundService.shared.isEnabled
    @State private var soundVolume = SoundService.shared.volume
    @State private var sessionStartSound = SoundService.shared.preferences.sessionStart
    @State private var sessionEndSound = SoundService.shared.preferences.sessionEnd
    @State private var responseCompleteSound = SoundService.shared.preferences.responseComplete
    @State private var permissionRequestSound = SoundService.shared.preferences.permissionRequest
    @State private var toolExecutionSound = SoundService.shared.preferences.toolExecution
    @State private var selectedPackId = SoundPackStore.shared.selectedPackId
    @State private var panelHeight: Double = 420
    @State private var autoCollapseDelay: Double = 0.5
    @State private var fontSize: Double = 13
    @State private var screenPreference = ScreenSelector.shared.preference
    @State private var crashReportingEnabled = CrashReporter.shared.isEnabled

    // Remote sources
    @State private var newRemoteName = ""
    @State private var newRemoteURL = ""
    @State private var newRemoteToken = ""
    @State private var newRemoteSSH = ""
    @State private var showAddRemote = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("VibeCode Settings")
                    .font(.title2)

                GroupBox("General") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Launch at Login", isOn: $launchAtLogin)
                            .onChange(of: launchAtLogin) { _, newValue in
                                do {
                                    if newValue {
                                        try LaunchAtLoginService.shared.enable()
                                    } else {
                                        try LaunchAtLoginService.shared.disable()
                                    }
                                } catch {
                                    print("Failed to toggle launch at login: \(error)")
                                    launchAtLogin = !newValue
                                }
                            }
                    }
                    .padding(8)
                }

                GroupBox("Sounds") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Enable Sounds", isOn: $soundsEnabled)
                            .onChange(of: soundsEnabled) { _, newValue in
                                SoundService.shared.isEnabled = newValue
                            }

                        if soundsEnabled {
                            VStack(alignment: .leading, spacing: 8) {
                                // Sound pack picker
                                Picker("Sound Pack", selection: $selectedPackId) {
                                    ForEach(SoundPackStore.shared.availablePacks) { pack in
                                        Text(pack.name).tag(pack.id)
                                    }
                                }
                                .onChange(of: selectedPackId) { _, newValue in
                                    SoundPackStore.shared.selectedPackId = newValue
                                    SoundService.shared.reloadSounds()
                                }

                                if let pack = SoundPackStore.shared.availablePacks.first(where: { $0.id == selectedPackId }) {
                                    Text("\(pack.description) — by \(pack.author)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Divider()

                                Text("Volume")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Slider(value: $soundVolume, in: 0...1)
                                    .onChange(of: soundVolume) { _, newValue in
                                        SoundService.shared.volume = newValue
                                    }

                                Divider()

                                soundToggleRow("Session Start", isOn: $sessionStartSound, eventKey: "sessionStart") { newValue in
                                    SoundService.shared.preferences.sessionStart = newValue
                                }

                                soundToggleRow("Session End", isOn: $sessionEndSound, eventKey: "sessionEnd") { newValue in
                                    SoundService.shared.preferences.sessionEnd = newValue
                                }

                                soundToggleRow("Response Complete", isOn: $responseCompleteSound, eventKey: "responseComplete") { newValue in
                                    SoundService.shared.preferences.responseComplete = newValue
                                }

                                soundToggleRow("Permission Request", isOn: $permissionRequestSound, eventKey: "permissionRequest") { newValue in
                                    SoundService.shared.preferences.permissionRequest = newValue
                                }

                                soundToggleRow("Tool Execution", isOn: $toolExecutionSound, eventKey: "toolExecution") { newValue in
                                    SoundService.shared.preferences.toolExecution = newValue
                                }
                            }
                        }
                    }
                    .padding(8)
                }

                GroupBox("Display") {
                    VStack(alignment: .leading, spacing: 12) {
                        // Screen selector
                        Picker("Target Display", selection: $screenPreference) {
                            Text("Auto (prefer notch)").tag(ScreenPreference.auto)
                            ForEach(ScreenSelector.shared.availableScreens, id: \.displayID) { screen in
                                Text(screen.localizedName).tag(ScreenPreference.specific(displayID: screen.displayID))
                            }
                        }
                        .onChange(of: screenPreference) { _, newValue in
                            ScreenSelector.shared.preference = newValue
                            NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Panel Height: \(Int(panelHeight))px")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Slider(value: $panelHeight, in: 300...600, step: 20)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Auto-collapse Delay: \(String(format: "%.1f", autoCollapseDelay))s")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Slider(value: $autoCollapseDelay, in: 0.1...3.0, step: 0.1)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Font Size: \(Int(fontSize))pt")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Slider(value: $fontSize, in: 10...16, step: 1)
                        }
                    }
                    .padding(8)
                }

                GroupBox("Hooks") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Claude Code hooks status")
                            .font(.subheadline)
                        Button("Install Hooks") {
                            HookInstaller.install()
                        }
                    }
                    .padding(8)
                }

                GroupBox("Remote Sources") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Connect to Claude Code running in remote containers")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if let manager = RemoteSourceManager.shared {
                            ForEach(manager.sources) { source in
                                remoteSourceRow(source, manager: manager)
                            }

                            Divider()

                            if showAddRemote {
                                VStack(alignment: .leading, spacing: 6) {
                                    TextField("Name", text: $newRemoteName)
                                        .textFieldStyle(.roundedBorder)
                                    TextField("URL (e.g. http://host:8876)", text: $newRemoteURL)
                                        .textFieldStyle(.roundedBorder)
                                    TextField("Token (optional)", text: $newRemoteToken)
                                        .textFieldStyle(.roundedBorder)
                                    TextField("SSH command (e.g. ssh -t host tmux attach -t claude)", text: $newRemoteSSH)
                                        .textFieldStyle(.roundedBorder)
                                    HStack {
                                        Button("Add") {
                                            guard !newRemoteName.isEmpty, !newRemoteURL.isEmpty else { return }
                                            manager.addSource(
                                                name: newRemoteName,
                                                url: newRemoteURL,
                                                token: newRemoteToken.isEmpty ? nil : newRemoteToken,
                                                sshCommand: newRemoteSSH.isEmpty ? nil : newRemoteSSH
                                            )
                                            newRemoteName = ""
                                            newRemoteURL = ""
                                            newRemoteToken = ""
                                            newRemoteSSH = ""
                                            showAddRemote = false
                                        }
                                        Button("Cancel") {
                                            showAddRemote = false
                                        }
                                    }
                                }
                            } else {
                                Button("Add Remote Source") {
                                    showAddRemote = true
                                }
                            }
                        } else {
                            Text("RemoteSourceManager not initialized")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(8)
                }

                GroupBox("Privacy") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Send Crash Reports", isOn: $crashReportingEnabled)
                            .onChange(of: crashReportingEnabled) { _, newValue in
                                CrashReporter.shared.setEnabled(newValue)
                            }
                        Text("Help improve VibeCode by automatically sending crash reports. No personal data is collected.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                }

                GroupBox("Advanced") {
                    VStack(alignment: .leading, spacing: 8) {
                        Button("Export Diagnostics") {
                            _ = DiagnosticExporter.exportDiagnostics()
                        }

                        Button("Clear Logs") {
                            DiagnosticExporter.clearLogs()
                        }

                        Button("Reset to Defaults") {
                            resetToDefaults()
                        }
                        .foregroundColor(.red)
                    }
                    .padding(8)
                }

                GroupBox("About") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("VibeCode v0.1.0")
                        Text("A Dynamic Island for your AI coding tools")
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                }
            }
            .padding(20)
        }
        .frame(width: 420, height: 800)
    }

    @ViewBuilder
    private func soundToggleRow(_ label: String, isOn: Binding<Bool>, eventKey: String, onChange: @escaping (Bool) -> Void) -> some View {
        HStack {
            Toggle(label, isOn: isOn)
                .onChange(of: isOn.wrappedValue) { _, newValue in
                    onChange(newValue)
                }
            Button(action: {
                SoundService.shared.previewSound(eventKey: eventKey)
            }) {
                Image(systemName: "play.circle")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private func resetToDefaults() {
        launchAtLogin = false
        soundsEnabled = true
        soundVolume = 0.5
        selectedPackId = "default"
        panelHeight = 420
        autoCollapseDelay = 0.5
        fontSize = 13
        screenPreference = .auto
        crashReportingEnabled = true

        try? LaunchAtLoginService.shared.disable()
        SoundService.shared.isEnabled = true
        SoundService.shared.volume = 0.5
        SoundPackStore.shared.selectedPackId = "default"
        SoundService.shared.reloadSounds()
        ScreenSelector.shared.preference = .auto
        CrashReporter.shared.setEnabled(true)
    }

    @ViewBuilder
    private func remoteSourceRow(_ source: RemoteSource, manager: RemoteSourceManager) -> some View {
        HStack {
            // Status indicator
            Circle()
                .fill(remoteStatusColor(for: source.id, manager: manager))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(source.name)
                    .font(.system(size: 12, weight: .medium))
                Text(source.url)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Toggle enable/disable
            Toggle("", isOn: Binding(
                get: { source.isEnabled },
                set: { newValue in
                    var updated = source
                    updated.isEnabled = newValue
                    manager.updateSource(updated)
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()

            Button(action: {
                manager.removeSource(id: source.id)
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }

    private func remoteStatusColor(for id: UUID, manager: RemoteSourceManager) -> Color {
        switch manager.sourceStatus[id] {
        case .connected: return .green
        case .connecting: return .yellow
        case .error: return .red
        case .disconnected, .none: return .gray
        }
    }
}
