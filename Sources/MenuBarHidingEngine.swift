import AppKit
import CoreGraphics

@MainActor
final class MenuBarHidingEngine {
    private enum Boundary {
        case hidden
        case alwaysHidden
    }

    private let statusBar: NSStatusBar
    private let toggleAutosaveName = "com.hanshijiu.MenuBarOrganizer.toggle"
    private let hiddenAutosaveName = "com.hanshijiu.MenuBarOrganizer.hiddenBoundary"
    private let alwaysHiddenAutosaveName = "com.hanshijiu.MenuBarOrganizer.alwaysHiddenBoundary"
    private lazy var hiddenBoundaryItem = statusBar.statusItem(withLength: 1)
    private lazy var alwaysHiddenBoundaryItem = statusBar.statusItem(withLength: 1)

    private(set) var isCollapsed = false
    var isExpanded: Bool { !isCollapsed }

    init(statusBar: NSStatusBar = .system) {
        self.statusBar = statusBar
        configureBoundary(
            hiddenBoundaryItem,
            autosaveName: hiddenAutosaveName
        )
        configureBoundary(
            alwaysHiddenBoundaryItem,
            autosaveName: alwaysHiddenAutosaveName
        )
    }

    func expand() {
        hiddenBoundaryItem.length = 1
        alwaysHiddenBoundaryItem.length = 1
        isCollapsed = false
    }

    func expandHiddenSection() {
        hiddenBoundaryItem.length = 1
        alwaysHiddenBoundaryItem.length = HidingGeometry.collapsedSectionLength
        isCollapsed = false
    }

    func collapse() {
        alwaysHiddenBoundaryItem.length = 1
        hiddenBoundaryItem.length = HidingGeometry.collapsedSectionLength
        isCollapsed = true
    }

    func moveToHiddenSection(_ item: MenuBarItemDescriptor) async -> Bool {
        let current = currentItem(item)
        guard let hiddenFrame = boundaryFrame(.hidden, near: current.frame),
              let alwaysHiddenFrame = boundaryFrame(.alwaysHidden, near: current.frame)
        else { return false }

        if isWindowOnScreen(current.id),
           current.frame.midX < hiddenFrame.midX,
           current.frame.midX > alwaysHiddenFrame.midX {
            return true
        }

        let destination = CGPoint(
            x: hiddenFrame.minX - 1,
            y: hiddenFrame.midY
        )
        guard await commandDrag(from: current.frame.center, to: destination, windowID: current.id),
              let updatedFrame = windowFrame(id: item.id),
              let updatedHiddenFrame = boundaryFrame(.hidden, near: updatedFrame),
              let updatedAlwaysHiddenFrame = boundaryFrame(.alwaysHidden, near: updatedFrame)
        else { return false }
        return updatedFrame.midX < updatedHiddenFrame.midX
            && updatedFrame.midX > updatedAlwaysHiddenFrame.midX
    }

    func moveToAlwaysHiddenSection(_ item: MenuBarItemDescriptor) async -> Bool {
        let current = currentItem(item)
        guard let initialBoundaryFrame = boundaryFrame(.alwaysHidden, near: current.frame) else { return false }
        if isWindowOnScreen(current.id), current.frame.midX < initialBoundaryFrame.midX { return true }

        let destination = CGPoint(
            x: initialBoundaryFrame.minX - 1,
            y: initialBoundaryFrame.midY
        )
        guard await commandDrag(from: current.frame.center, to: destination, windowID: current.id),
              let updatedFrame = windowFrame(id: item.id),
              let updatedBoundary = boundaryFrame(.alwaysHidden, near: updatedFrame)
        else { return false }
        return updatedFrame.midX < updatedBoundary.midX
    }

    func moveToVisibleSection(_ item: MenuBarItemDescriptor, force: Bool = false) async -> Bool {
        let current = currentItem(item)
        guard let toggleFrame = toggleProxyFrame(near: current.frame) else { return false }
        // A window can still have a screen-intersecting frame while macOS has
        // placed it behind the notch. Ask WindowServer whether this exact
        // window is currently on-screen instead of inferring visibility from
        // geometry alone.
        // When `force` is true, skip this check — the item may be on-screen
        // (e.g. after expandHiddenSection) but still positioned in the hidden
        // zone (left of boundary). We must Command-drag it regardless.
        if !force, isWindowOnScreen(current.id) { return true }

        let destination = CGPoint(
            x: toggleFrame.minX - max(current.frame.width, 24) / 2 - 2,
            y: toggleFrame.midY
        )
        guard await commandDrag(from: current.frame.center, to: destination, windowID: current.id),
              let updatedFrame = windowFrame(id: item.id)
        else { return false }
        return isWindowOnScreen(item.id) && updatedFrame.midX < toggleFrame.minX
    }

    private func configureBoundary(_ item: NSStatusItem, autosaveName: String) {
        item.autosaveName = autosaveName
        item.isVisible = true
        item.length = 1
        guard let button = item.button else { return }
        button.image = nil
        button.title = ""
        button.toolTip = nil
        button.isEnabled = false
    }

    private func boundaryFrame(_ boundary: Boundary, near itemFrame: CGRect) -> CGRect? {
        let displayFrames = NSScreen.screens.compactMap { screen -> CGRect? in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
            return CGDisplayBounds(number.uint32Value)
        }
        let screenFrame = displayFrames.first(where: {
            $0.contains(CGPoint(x: itemFrame.midX, y: itemFrame.midY))
        }) ?? displayFrames.first(where: {
            abs($0.minY - itemFrame.minY) <= 50
        })
        guard let screenFrame else { return nil }

        let frames = ownStatusProxyFrames().filter {
            abs($0.midY - itemFrame.midY) < 8
        }
        // The visible trigger is the only one of our three status items with a
        // normal icon width. macOS 26 strips autosave-name suffixes from the
        // mirrored copies on secondary displays, but preserves adjacency.
        guard let toggleFrame = frames
            .filter({
                $0.width >= 24 && $0.width <= 80
                    && $0.minX >= screenFrame.minX
                    && $0.minX < screenFrame.maxX
            })
            .min(by: { abs($0.minX - itemFrame.midX) < abs($1.minX - itemFrame.midX) })
        else { return nil }

        guard let hiddenFrame = frames
            .filter({ $0 != toggleFrame })
            .min(by: { abs($0.maxX - toggleFrame.minX) < abs($1.maxX - toggleFrame.minX) })
        else { return nil }

        if boundary == .hidden { return hiddenFrame }
        return frames
            .filter({ $0 != toggleFrame && $0 != hiddenFrame })
            .min(by: { abs($0.maxX - hiddenFrame.minX) < abs($1.maxX - hiddenFrame.minX) })
    }

    private func toggleProxyFrame(near itemFrame: CGRect) -> CGRect? {
        let displayFrames = NSScreen.screens.compactMap { screen -> CGRect? in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
            return CGDisplayBounds(number.uint32Value)
        }
        let screenFrame = displayFrames.first(where: {
            abs($0.minY - itemFrame.minY) <= 50
        })
        return ownStatusProxyFrames()
            .filter { frame in
                frame.width >= 24 && frame.width <= 80
                    && (screenFrame == nil || screenFrame!.contains(CGPoint(x: frame.midX, y: frame.midY)))
                    && abs(frame.midY - itemFrame.midY) < 8
            }
            .min(by: { abs($0.midX - itemFrame.midX) < abs($1.midX - itemFrame.midX) })
    }

    /// On macOS 26, Control Center hosts the visible proxy windows for third-
    /// party status items. `button.window` points at an internal offscreen
    /// window, so geometry must be resolved through the autosaved proxy name.
    private func ownStatusProxyFrames() -> [CGRect] {
        guard let rows = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        let statusLayer = Int(CGWindowLevelForKey(.statusWindow))
        return rows.compactMap { row in
            guard row[kCGWindowLayer as String] as? Int == statusLayer,
                  let name = row[kCGWindowName as String] as? String,
                  name.hasPrefix("com.hanshijiu.MenuBarOrganizer"),
                  let boundsValue = row[kCGWindowBounds as String]
            else { return nil }
            return CGRect(dictionaryRepresentation: boundsValue as! CFDictionary)
        }
    }

    private func windowFrame(id: CGWindowID) -> CGRect? {
        guard let rows = CGWindowListCopyWindowInfo([.optionIncludingWindow], id) as? [[String: Any]],
              let row = rows.first,
              let boundsValue = row[kCGWindowBounds as String]
        else { return nil }
        return CGRect(dictionaryRepresentation: boundsValue as! CFDictionary)
    }

    private func currentItem(_ item: MenuBarItemDescriptor) -> MenuBarItemDescriptor {
        if let resolved = MenuBarItemDiscovery.resolveCurrentWindow(for: item) {
            return MenuBarItemDescriptor(
                id: resolved.id,
                identifier: item.identifier,
                occurrence: item.occurrence,
                frame: resolved.frame,
                snapshot: item.snapshot
            )
        }
        guard let frame = windowFrame(id: item.id) else { return item }
        return MenuBarItemDescriptor(
            id: item.id,
            identifier: item.identifier,
            occurrence: item.occurrence,
            frame: frame,
            snapshot: item.snapshot
        )
    }

    private func isWindowOnScreen(_ id: CGWindowID) -> Bool {
        guard let rows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]
        ] else { return false }
        return rows.contains { row in
            guard let number = row[kCGWindowNumber as String] as? NSNumber else { return false }
            return CGWindowID(number.uint32Value) == id
        }
    }

    private func commandDrag(from start: CGPoint, to end: CGPoint, windowID: CGWindowID) async -> Bool {
        let originalPointer = MouseCursor.location
        guard let ownerPID = windowOwnerPID(windowID),
              let source = CGEventSource(stateID: .hidSystemState)
        else { return false }

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

        let midpoint = CGPoint(x: (start.x + end.x) / 2, y: start.y)
        guard let down = dragEvent(.leftMouseDown, at: start, windowID: windowID, ownerPID: ownerPID, source: source),
              let drag1 = dragEvent(.leftMouseDragged, at: midpoint, windowID: windowID, ownerPID: ownerPID, source: source),
              let drag2 = dragEvent(.leftMouseDragged, at: end, windowID: windowID, ownerPID: ownerPID, source: source),
              let up = dragEvent(.leftMouseUp, at: end, windowID: windowID, ownerPID: ownerPID, source: source)
        else { return false }

        // The window server follows the live cursor during a Command-drag.
        // Hide it for the ~160ms gesture and only warp it back after the item
        // frame has settled. Warping immediately cancels the move.
        MouseCursor.prepareBackgroundControl()
        MouseCursor.hide()
        down.post(tap: .cgSessionEventTap)
        usleep(50_000)
        drag1.post(tap: .cgSessionEventTap)
        usleep(50_000)
        drag2.post(tap: .cgSessionEventTap)
        usleep(60_000)
        up.post(tap: .cgSessionEventTap)

        var lastMidX: CGFloat?
        var movedAndStable = false
        for _ in 0..<16 {
            try? await Task.sleep(for: .milliseconds(50))
            guard let current = windowFrame(id: windowID) else { continue }
            let moved = abs(current.midX - start.x) > 20
            let stable = lastMidX.map { abs(current.midX - $0) < 1 } ?? false
            lastMidX = current.midX
            if moved && stable {
                movedAndStable = true
                break
            }
        }

        if let originalPointer { MouseCursor.warp(to: originalPointer) }
        MouseCursor.show()
        return movedAndStable
    }

    private func windowOwnerPID(_ id: CGWindowID) -> pid_t? {
        guard let rows = CGWindowListCopyWindowInfo([.optionIncludingWindow], id) as? [[String: Any]],
              let row = rows.first,
              let number = row[kCGWindowOwnerPID as String] as? NSNumber
        else { return nil }
        return pid_t(number.int32Value)
    }

    private func dragEvent(
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
        event.flags = .maskCommand
        event.setIntegerValueField(.eventTargetUnixProcessID, value: Int64(ownerPID))
        event.setIntegerValueField(.mouseEventWindowUnderMousePointer, value: Int64(windowID))
        event.setIntegerValueField(
            .mouseEventWindowUnderMousePointerThatCanHandleThisEvent,
            value: Int64(windowID)
        )
        event.setIntegerValueField(CGEventField(rawValue: 0x33)!, value: Int64(windowID))
        return event
    }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}
