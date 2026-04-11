import AppKit

/// Detects the notch area and computes panel positioning
struct NotchGeometry {
    struct PanelFrame {
        let collapsed: NSRect
        let expanded: NSRect
        let hasNotch: Bool
    }

    /// Get the actual menu bar height for a screen
    static func menuBarHeight(for screen: NSScreen) -> CGFloat {
        let frame = screen.frame
        let visible = screen.visibleFrame
        return frame.maxY - visible.maxY
    }

    /// Compute panel frames for the given screen
    static func frames(for screen: NSScreen) -> PanelFrame {
        let screenFrame = screen.frame
        let notch = hasNotch(screen: screen)
        let menuH = menuBarHeight(for: screen)

        let collapsedW = VibeCodeConstants.collapsedWidth
        let collapsedH = VibeCodeConstants.collapsedHeight
        let expandedW = VibeCodeConstants.expandedWidth
        let expandedH = VibeCodeConstants.expandedMaxHeight

        let centerX = screenFrame.midX

        if notch {
            // Notch screens: pill sits at the very top, flush with notch
            let collapsed = NSRect(
                x: centerX - collapsedW / 2,
                y: screenFrame.maxY - collapsedH,
                width: collapsedW,
                height: collapsedH
            )
            let expanded = NSRect(
                x: centerX - expandedW / 2,
                y: screenFrame.maxY - expandedH,
                width: expandedW,
                height: expandedH
            )
            return PanelFrame(collapsed: collapsed, expanded: expanded, hasNotch: true)
        } else {
            // Non-notch screens: pill fills the entire menu bar height
            let collapsed = NSRect(
                x: centerX - collapsedW / 2,
                y: screenFrame.maxY - menuH,
                width: collapsedW,
                height: menuH
            )
            // Expanded: top flush with screen top (same as collapsed), grows downward
            let expanded = NSRect(
                x: centerX - expandedW / 2,
                y: screenFrame.maxY - expandedH,
                width: expandedW,
                height: expandedH
            )
            return PanelFrame(collapsed: collapsed, expanded: expanded, hasNotch: false)
        }
    }

    /// Check if the screen has a notch (MacBook Pro 2021+)
    static func hasNotch(screen: NSScreen) -> Bool {
        guard let topLeft = screen.auxiliaryTopLeftArea else { return false }
        return topLeft.width > 0
    }
}
