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

        // On macOS 26 the AX Extras tree can identify an item but often cannot
        // actually open a Control Center-hosted status item. Mature managers
        // such as Lloyd forward a real click to the revealed window instead.
        // The window-id fields are essential: a bare CGEvent is accepted but
        // is delivered to no menu, which was the failure in v0.9.4/0.9.5.
        guard isWindowOnScreen(item.id),
              let info = windowInfo(for: item.id),
              let frame = CGRect(dictionaryRepresentation: info.bounds as CFDictionary),
              let ownerPID = info.ownerPID,
              ownerPID > 0,
              let source = CGEventSource(stateID: .hidSystemState)
        else { return false }

        let location = frame.center
        let restore = MouseCursor.location
        let permit: CGEventFilterMask = [
            .permitLocalMouseEvents,
            .permitLocalKeyboardEvents,
            .permitSystemDefinedEvents
        ]
        source.setLocalEventsFilterDuringSuppressionState(
            permit,
            state: .eventSuppressionStateRemoteMouseDrag
        )
        source.setLocalEventsFilterDuringSuppressionState(
            permit,
            state: .eventSuppressionStateSuppressionInterval
        )
        source.localEventsSuppressionInterval = 0

        guard let down = event(.leftMouseDown, at: location, windowID: item.id, ownerPID: ownerPID, source: source),
              let up = event(.leftMouseUp, at: location, windowID: item.id, ownerPID: ownerPID, source: source)
        else { return false }

        let popupBefore = popupWindowIDs(ownerPID: ownerPID)
        // AXMenuBarItem's native action is AXPick, not AXPress. It is the
        // least disruptive path because it asks the owning status item to
        // open its own menu without another cursor gesture. Do not treat an
        // AX "success" as enough: some hosts acknowledge the action without
        // creating a popup, so keep the window-targeted click as a fallback.
        if MenuBarItemSourceResolver.pick(item, visibleFrame: frame),
           waitForPopup(ownerPID: ownerPID, excluding: popupBefore) {
            return true
        }

        postClick(down: down, up: up)
        if popupWindowIDs(ownerPID: ownerPID).subtracting(popupBefore).isEmpty {
            usleep(120_000)
            postClick(down: down, up: up)
        }
        if let restore { MouseCursor.warp(to: restore) }
        MouseCursor.show()
        return true
    }

    /// Wait until the host application's native menu has closed before the
    /// caller moves the status item back to the hidden section. Some menu-bar
    /// apps do not create a popup at all; in that case return after a short
    /// grace period so launching those apps is not delayed.
    static func waitForMenuDismissal(_ item: MenuBarItemDescriptor) async -> Bool {
        guard let info = windowInfo(for: item.id),
              let ownerPID = info.ownerPID,
              ownerPID > 0 else {
            return true
        }

        var popupWasSeen = false
        for tick in 0..<600 { // 30 seconds at 50 ms per tick
            if Task.isCancelled { return false }
            let popups = popupWindowIDs(ownerPID: ownerPID)
            if !popups.isEmpty {
                popupWasSeen = true
            } else if popupWasSeen {
                return true
            } else if tick >= 8 { // no native menu: app-style item
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
