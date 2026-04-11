import AppKit

/// Custom NSPanel that sits at the notch area without stealing focus
class NotchPanel: NSPanel {
    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        configure()
    }

    private func configure() {
        // Above menu bar so expanded panel isn't clipped
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = false
        isMovableByWindowBackground = false
        acceptsMouseMovedEvents = true
        animationBehavior = .utilityWindow
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        contentMinSize = NSSize(width: 10, height: 10)

        // Force clip content to window bounds
        contentView?.wantsLayer = true
        contentView?.layer?.masksToBounds = true
    }

    // Allow the panel to become key for button clicks
    override var canBecomeKey: Bool { true }

    // But never become main window
    override var canBecomeMain: Bool { false }
}
