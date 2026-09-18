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

        // Never synthesize a click at the status-item window's frame. That
        // path temporarily exposes the item and lets AppKit move the pointer,
        // which is the source of the visible "drawn by the mouse" animation.
        // Pressing the AX menu-bar child activates the original item in place.
        return MenuBarItemSourceResolver.press(item)
    }
}
