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
        let original = CGEvent(source: nil)?.location
        let source = CGEventSource(stateID: .hidSystemState)

        guard
            let mouseDown = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: target, mouseButton: .left),
            let mouseUp = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: target, mouseButton: .left)
        else { return false }

        mouseDown.post(tap: .cghidEventTap)
        mouseUp.post(tap: .cghidEventTap)

        if let original,
           let restore = CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: original, mouseButton: .left) {
            restore.post(tap: .cghidEventTap)
        }
        return true
    }
}
