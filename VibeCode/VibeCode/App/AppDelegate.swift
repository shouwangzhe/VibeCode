import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panelController: NotchPanelController!
    private var ipcServer: IPCServer!
    private let sessionManager = SessionManager()
    private var remoteSourceManager: RemoteSourceManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ignore SIGPIPE to prevent crash when writing to closed sockets
        signal(SIGPIPE, SIG_IGN)

        SessionManager.shared = sessionManager
        CrashReporter.shared.initialize()

        setupStatusItem()
        panelController = NotchPanelController(sessionManager: sessionManager)
        panelController.showPanel()

        ipcServer = IPCServer(sessionManager: sessionManager, panelController: panelController)
        ipcServer.start()

        remoteSourceManager = RemoteSourceManager(sessionManager: sessionManager, panelController: panelController)
        remoteSourceManager.startAll()

        // Start discovering existing Claude Code sessions
        sessionManager.startDiscovery()

        // Initialize transcript watcher for hookless sessions (e.g. ducc v2.1.71)
        sessionManager.setupTranscriptWatcher()

        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )

        // Initialize update service (checks for updates on launch)
        // TODO: Re-enable when Sparkle framework is properly integrated
        // _ = UpdateService.shared
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "waveform.circle.fill", accessibilityDescription: "VibeCode")
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        updateStatusItemBadge()

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Panel", action: #selector(showPanel), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Hide Panel", action: #selector(hidePanel), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Open Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Install Hooks", action: #selector(installHooks), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Export Diagnostics", action: #selector(exportDiagnostics), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit VibeCode", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            statusItem.menu?.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        } else {
            togglePanel()
        }
    }

    private func updateStatusItemBadge() {
        let activeCount = sessionManager.sessions.values.filter { $0.status.isActive }.count
        if let button = statusItem.button, activeCount > 0 {
            button.title = " \(activeCount)"
        } else {
            statusItem.button?.title = ""
        }
    }

    @objc private func showPanel() {
        panelController.showPanel()
    }

    @objc private func hidePanel() {
        panelController.collapse()
    }

    @objc private func openSettings() {
        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "VibeCode Settings"
        window.styleMask = [.titled, .closable, .resizable]
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func exportDiagnostics() {
        _ = DiagnosticExporter.exportDiagnostics()
    }

    @objc private func togglePanel() {
        panelController.toggle()
    }

    @objc private func installHooks() {
        HookInstaller.install()
    }

    // TODO: Re-enable when Sparkle framework is properly integrated
    // @objc private func checkForUpdates() {
    //     UpdateService.shared.checkForUpdates()
    // }

    @objc private func quitApp() {
        sessionManager.stopDiscovery()
        remoteSourceManager.stopAll()
        ipcServer.stop()
        NSApplication.shared.terminate(nil)
    }

    @objc private func screenParametersChanged() {
        panelController.repositionPanel()
    }
}
