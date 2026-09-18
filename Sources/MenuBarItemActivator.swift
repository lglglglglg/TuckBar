import AppKit
import ApplicationServices
import CoreGraphics

@MainActor
enum MenuBarItemActivator {
    static var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    static func requestAccessibilityPermission() {
        // The framework global is imported as mutable state and is rejected by
        // Swift 6 strict concurrency. Its documented CFString value is stable.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func activate(_ item: MenuBarItemDescriptor) -> Bool {
        guard hasAccessibilityPermission else {
            requestAccessibilityPermission()
            return false
        }

        let target = CGPoint(x: item.frame.midX, y: item.frame.midY)
        let source = CGEventSource(stateID: .hidSystemState)

        guard
            let mouseDown = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: target, mouseButton: .left),
            let mouseUp = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: target, mouseButton: .left)
        else { return false }

        mouseDown.post(tap: .cghidEventTap)
        mouseUp.post(tap: .cghidEventTap)

        // The event location is enough to activate a status item. Do not post
        // a synthetic mouseMoved event afterwards: it changes the user's
        // pointer position from the hover panel and can reopen/close the
        // panel while the activation transaction is still in flight.
        return true
    }
}
