import AppKit
import SwiftUI
import os.log

private let panelLogger = Logger(subsystem: "com.vibecode.macos", category: "NotchPanel")

private func panelLog(_ msg: String) {
    panelLogger.info("\(msg)")
    let line = "\(Date()) [NotchPanel] \(msg)\n"
    if let data = line.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: "/tmp/vibecode-ipc.log") {
            if let fh = FileHandle(forWritingAtPath: "/tmp/vibecode-ipc.log") {
                fh.seekToEndOfFile()
                fh.write(data)
                fh.closeFile()
            }
        } else {
            FileManager.default.createFile(atPath: "/tmp/vibecode-ipc.log", contents: data)
        }
    }
}

/// A view that clips its children and doesn't push its intrinsic size to the window
class ClippingView: NSView {
    override var wantsLayer: Bool {
        get { true }
        set { super.wantsLayer = newValue }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        self.layer?.masksToBounds = true
        self.autoresizesSubviews = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize {
        return NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }
}

/// Manages the NotchPanel lifecycle, expand/collapse state, and content hosting
class NotchPanelController: NSObject {
    private let panel: NotchPanel
    private let sessionManager: SessionManager
    private let screenSelector = ScreenSelector.shared
    private var hostingView: NSHostingView<NotchContentView>!
    private var isExpanded = false
    private var trackingArea: NSTrackingArea?
    private var collapseTimer: Timer?
    private var outsideCheckTimer: Timer?

    init(sessionManager: SessionManager) {
        self.sessionManager = sessionManager
        self.panel = NotchPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()
        setupContent()
    }

    private func setupContent() {
        let screen = screenSelector.selectedScreen
        let contentView = NotchContentView(
            sessionManager: sessionManager,
            isExpanded: isExpanded,
            hasNotch: NotchGeometry.hasNotch(screen: screen),
            onToggle: { [weak self] in self?.toggle() },
            onApprove: { [weak self] id, decision in self?.handlePermission(id: id, decision: decision) },
            onQuestionSubmit: { [weak self] id, answers in self?.handleQuestionSubmit(id: id, answers: answers) },
            onJumpToSession: { [weak self] session in self?.jumpToSession(session) },
            onReplyToSession: { [weak self] session, text in self?.replyToSession(session, text: text) }
        )
        hostingView = NSHostingView(rootView: contentView)
        hostingView.wantsLayer = true
        hostingView.layer?.masksToBounds = true
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        let clipView = ClippingView()
        clipView.addSubview(hostingView)

        // Pin hosting view to fill clip view entirely
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: clipView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: clipView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: clipView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: clipView.bottomAnchor),
        ])

        panel.contentView = clipView
        setupMouseTracking()
    }

    private func setupMouseTracking() {
        guard let contentView = panel.contentView else { return }
        let area = NSTrackingArea(
            rect: contentView.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self, userInfo: nil
        )
        contentView.addTrackingArea(area)
        trackingArea = area
    }

    func showPanel() {
        repositionPanel()
        panel.makeKeyAndOrderFront(nil)

        // Force clip content AFTER showing
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.masksToBounds = true

        // Force position update after showing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.repositionPanel()
            self?.panel.contentView?.layer?.masksToBounds = true
        }
    }

    func repositionPanel() {
        let screen = screenSelector.selectedScreen
        let frames = NotchGeometry.frames(for: screen)
        let targetFrame = isExpanded ? frames.expanded : frames.collapsed

        panelLog("repositionPanel: screen.frame=\(screen.frame)")
        panelLog("repositionPanel: isExpanded=\(isExpanded)")
        panelLog("repositionPanel: targetFrame=\(targetFrame)")
        panelLog("repositionPanel: panel.frame before=\(panel.frame)")

        panel.setFrame(targetFrame, display: true, animate: false)

        // Force the exact frame size - prevent SwiftUI from expanding
        if panel.frame.size != targetFrame.size {
            panel.setFrame(targetFrame, display: true, animate: false)
        }

        panelLog("repositionPanel: panel.frame after=\(panel.frame)")
    }

    func toggle() {
        if isExpanded {
            collapse()
        } else {
            expand()
        }
    }

    func expand() {
        startOutsideCheck()
        guard !isExpanded else { return }
        isExpanded = true
        animateTransition()
    }

    func collapse() {
        guard isExpanded else { return }
        isExpanded = false
        animateTransition()
        stopOutsideCheck()
    }

    private func animateTransition() {
        let screen = screenSelector.selectedScreen
        let frames = NotchGeometry.frames(for: screen)
        let targetFrame = isExpanded ? frames.expanded : frames.collapsed

        updateContent()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(targetFrame, display: true)
        }
    }

    private func updateContent() {
        let screen = screenSelector.selectedScreen
        let contentView = NotchContentView(
            sessionManager: sessionManager,
            isExpanded: isExpanded,
            hasNotch: NotchGeometry.hasNotch(screen: screen),
            onToggle: { [weak self] in self?.toggle() },
            onApprove: { [weak self] id, decision in self?.handlePermission(id: id, decision: decision) },
            onQuestionSubmit: { [weak self] id, answers in self?.handleQuestionSubmit(id: id, answers: answers) },
            onJumpToSession: { [weak self] session in self?.jumpToSession(session) },
            onReplyToSession: { [weak self] session, text in self?.replyToSession(session, text: text) }
        )
        hostingView.rootView = contentView
    }

    private func handlePermission(id: String, decision: String) {
        panelLog("handlePermission called: id=\(id), decision=\(decision)")
        sessionManager.respondToPermission(requestId: id, decision: decision)
        panelLog("respondToPermission completed for id=\(id)")
    }

    private func handleQuestionSubmit(id: String, answers: [String: AnyCodableValue]) {
        panelLog("handleQuestionSubmit called: id=\(id)")
        sessionManager.respondToQuestion(requestId: id, answers: answers)
    }

    private func jumpToSession(_ session: ClaudeSession) {
        TerminalService.jumpToSession(session)
    }

    private func replyToSession(_ session: ClaudeSession, text: String) {
        panelLog("replyToSession: session=\(session.id), text=\(text), isRemote=\(session.isRemote)")
        if session.isRemote, let sourceId = session.remoteSourceId {
            RemoteSourceManager.shared?.sendInput(sourceId: sourceId, sessionId: session.id, text: text)
        } else {
            TerminalService.sendInput(to: session, text: text)
        }
    }

    // MARK: - Click Outside to Collapse

    private func startOutsideCheck() {
        stopOutsideCheck()
        var ticksOutside = 0
        outsideCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            guard let self = self, self.isExpanded else { return }
            let mouse = NSEvent.mouseLocation
            let inside = self.panel.frame.contains(mouse)
            // Don't auto-collapse when there are pending permissions needing user confirmation
            let hasPending = self.sessionManager.sessions.values.contains { !$0.pendingPermissions.isEmpty }

            if inside || hasPending {
                ticksOutside = 0
            } else {
                ticksOutside += 1
                if ticksOutside >= 3 {
                    self.collapse()
                }
            }
        }
    }

    private func stopOutsideCheck() {
        outsideCheckTimer?.invalidate()
        outsideCheckTimer = nil
    }

    // MARK: - Mouse Tracking

    @objc func mouseEntered(with event: NSEvent) {
        collapseTimer?.invalidate()
        collapseTimer = nil
        expand()
    }

    @objc func mouseExited(with event: NSEvent) {
        // Don't auto-collapse when there are pending permissions needing user confirmation
        let hasPending = sessionManager.sessions.values.contains { !$0.pendingPermissions.isEmpty }
        guard !hasPending else { return }

        collapseTimer?.invalidate()
        collapseTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.collapse()
        }
    }
}
