import AppKit
import ApplicationServices
import CoreGraphics

@MainActor
enum MenuBarItemActivator {
    private static let windowIDField = CGEventField(rawValue: 0x33)!

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

        // 1. First try AX invocation which is the cleanest, native action (AXPick/AXPress/AXShowMenu)
        // Check if there is an existing popup before trying
        let resolvedWindow = MenuBarItemDiscovery.resolveCurrentWindow(for: item)
        let ownerPID = resolvedWindow?.ownerPID ?? windowInfo(for: item.id)?.ownerPID ?? 0
        let popupBefore = ownerPID > 0 ? popupWindowIDs(ownerPID: ownerPID) : []

        let targetFrame = resolvedWindow?.frame ?? item.frame
        if MenuBarItemSourceResolver.pick(item, visibleFrame: targetFrame) {
            if ownerPID > 0 && waitForPopup(ownerPID: ownerPID, excluding: popupBefore) {
                return true
            }
        }

        // 2. Fallback to direct CGEvent mouse click
        // Resolve latest window ID and geometry
        guard let currentTarget = resolvedWindow ?? windowInfo(for: item.id).flatMap({ info in
            CGRect(dictionaryRepresentation: info.bounds as CFDictionary).map { (id: item.id, frame: $0, ownerPID: info.ownerPID ?? 0) }
        }), currentTarget.ownerPID > 0 else {
            return false
        }

        let location = currentTarget.frame.center
        let restore = MouseCursor.location
        let permit: CGEventFilterMask = [
            .permitLocalMouseEvents,
            .permitLocalKeyboardEvents,
            .permitSystemDefinedEvents
        ]
        guard let source = CGEventSource(stateID: .hidSystemState) else { return false }
        source.setLocalEventsFilterDuringSuppressionState(permit, state: .eventSuppressionStateRemoteMouseDrag)
        source.setLocalEventsFilterDuringSuppressionState(permit, state: .eventSuppressionStateSuppressionInterval)
        source.localEventsSuppressionInterval = 0

        guard let down = event(.leftMouseDown, at: location, windowID: currentTarget.id, ownerPID: currentTarget.ownerPID, source: source),
              let up = event(.leftMouseUp, at: location, windowID: currentTarget.id, ownerPID: currentTarget.ownerPID, source: source)
        else { return false }

        postClick(down: down, up: up)
        if currentTarget.ownerPID > 0 && popupWindowIDs(ownerPID: currentTarget.ownerPID).subtracting(popupBefore).isEmpty {
            usleep(80_000)
            postClick(down: down, up: up)
        }
        if let restore { MouseCursor.warp(to: restore) }
        MouseCursor.show()
        return true
    }

    /// Wait until the host application's native menu or popup has closed, or until user clicks outside / app deactivates.
    static func waitForMenuDismissal(_ item: MenuBarItemDescriptor) async -> Bool {
        let resolved = MenuBarItemDiscovery.resolveCurrentWindow(for: item)
        let ownerPID = resolved?.ownerPID ?? windowInfo(for: item.id)?.ownerPID ?? 0
        guard ownerPID > 0 else { return true }

        // We listen for global mouse clicks and application deactivation to detect dismissal
        var userClickedOutside = false
        let clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { _ in
            userClickedOutside = true
        }
        defer {
            if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        }

        var popupWasSeen = false
        // Loop up to 10 seconds (200 * 50ms)
        for tick in 0..<200 {
            if Task.isCancelled || userClickedOutside {
                try? await Task.sleep(for: .milliseconds(120))
                return true
            }

            let popups = popupWindowIDs(ownerPID: ownerPID)
            if !popups.isEmpty {
                popupWasSeen = true
            } else if popupWasSeen {
                // Was seen and now gone
                try? await Task.sleep(for: .milliseconds(150))
                return true
            } else if tick >= 16 {
                // If after 800ms no native popup menu was ever opened, it's likely an app window or toggle action
                return true
            }

            try? await Task.sleep(for: .milliseconds(50))
        }
        return true
    }

    private struct WindowInfo {
        let bounds: NSDictionary
        let ownerPID: pid_t?
    }

    private static func windowInfo(for id: CGWindowID) -> WindowInfo? {
        guard let rows = CGWindowListCopyWindowInfo([.optionIncludingWindow], id) as? [[String: Any]],
              let row = rows.first,
              let bounds = row[kCGWindowBounds as String] as? NSDictionary
        else { return nil }
        let ownerPID = (row[kCGWindowOwnerPID as String] as? NSNumber).map { pid_t($0.int32Value) }
        return WindowInfo(bounds: bounds, ownerPID: ownerPID)
    }

    private static func event(
        _ type: CGEventType,
        at location: CGPoint,
        windowID: CGWindowID,
        ownerPID: pid_t,
        source: CGEventSource
    ) -> CGEvent? {
        guard let event = CGEvent(
            mouseEventSource: source,
            mouseType: type,
            mouseCursorPosition: location,
            mouseButton: .left
        ) else { return nil }
        event.flags = []
        event.setIntegerValueField(.eventTargetUnixProcessID, value: Int64(ownerPID))
        event.setIntegerValueField(.mouseEventWindowUnderMousePointer, value: Int64(windowID))
        event.setIntegerValueField(
            .mouseEventWindowUnderMousePointerThatCanHandleThisEvent,
            value: Int64(windowID)
        )
        event.setIntegerValueField(windowIDField, value: Int64(windowID))
        event.setIntegerValueField(.mouseEventClickState, value: 1)
        return event
    }

    private static func postClick(down: CGEvent, up: CGEvent) {
        MouseCursor.prepareBackgroundControl()
        MouseCursor.hide()
        down.post(tap: .cgSessionEventTap)
        usleep(40_000)
        up.post(tap: .cgSessionEventTap)
        usleep(80_000)
    }

    private static func isWindowOnScreen(_ id: CGWindowID) -> Bool {
        guard let rows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else { return false }
        return rows.contains { row in
            guard let number = row[kCGWindowNumber as String] as? NSNumber else { return false }
            return CGWindowID(number.uint32Value) == id
        }
    }

    private static func popupWindowIDs(ownerPID: pid_t) -> Set<CGWindowID> {
        let popupLevel = Int(CGWindowLevelForKey(.popUpMenuWindow))
        guard let rows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else { return [] }
        return Set(rows.compactMap { row in
            guard row[kCGWindowLayer as String] as? Int == popupLevel,
                  let pidNumber = row[kCGWindowOwnerPID as String] as? NSNumber,
                  pid_t(pidNumber.int32Value) == ownerPID,
                  let number = row[kCGWindowNumber as String] as? NSNumber
            else { return nil }
            return CGWindowID(number.uint32Value)
        })
    }

    private static func waitForPopup(ownerPID: pid_t, excluding existing: Set<CGWindowID>) -> Bool {
        for _ in 0..<8 {
            if !popupWindowIDs(ownerPID: ownerPID).subtracting(existing).isEmpty {
                return true
            }
            usleep(25_000)
        }
        return false
    }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}
