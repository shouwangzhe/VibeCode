import Carbon
import AppKit

/// Registers global keyboard shortcuts using Carbon Event Tap
class HotkeyService {
    static let shared = HotkeyService()
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    var onTogglePanel: (() -> Void)?
    var onApprove: (() -> Void)?
    var onDeny: (() -> Void)?

    private init() {}

    func register() {
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { _, _, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let service = Unmanaged<HotkeyService>.fromOpaque(refcon).takeUnretainedValue()
                return service.handleKeyEvent(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let eventTap = eventTap else {
            print("Failed to create event tap. Accessibility permission required.")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    private func handleKeyEvent(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let flags = event.flags
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        // Ctrl+Shift+V: Toggle panel
        if flags.contains([.maskControl, .maskShift]) && keyCode == 9 { // V key
            DispatchQueue.main.async { self.onTogglePanel?() }
            return nil
        }

        // Ctrl+Shift+A: Approve (when panel is showing permission)
        if flags.contains([.maskControl, .maskShift]) && keyCode == 0 { // A key
            DispatchQueue.main.async { self.onApprove?() }
            return nil
        }

        // Ctrl+Shift+D: Deny
        if flags.contains([.maskControl, .maskShift]) && keyCode == 2 { // D key
            DispatchQueue.main.async { self.onDeny?() }
            return nil
        }

        return Unmanaged.passRetained(event)
    }

    func unregister() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }
}
