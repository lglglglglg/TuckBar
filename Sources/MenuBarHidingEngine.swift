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
        guard let hiddenFrame = boundaryFrame(.hidden, near: item.frame),
              let alwaysHiddenFrame = boundaryFrame(.alwaysHidden, near: item.frame)
        else { return false }

        if item.frame.midX < hiddenFrame.midX, item.frame.midX > alwaysHiddenFrame.midX {
            return true
        }

        let destination = CGPoint(
            x: hiddenFrame.minX - 1,
            y: hiddenFrame.midY
        )
        guard await commandDrag(from: item.frame.center, to: destination),
              let updatedFrame = windowFrame(id: item.id),
              let updatedHiddenFrame = boundaryFrame(.hidden, near: updatedFrame),
              let updatedAlwaysHiddenFrame = boundaryFrame(.alwaysHidden, near: updatedFrame)
        else { return false }
        return updatedFrame.midX < updatedHiddenFrame.midX
            && updatedFrame.midX > updatedAlwaysHiddenFrame.midX
    }

    func moveToAlwaysHiddenSection(_ item: MenuBarItemDescriptor) async -> Bool {
        guard let initialBoundaryFrame = boundaryFrame(.alwaysHidden, near: item.frame) else { return false }
        if item.frame.midX < initialBoundaryFrame.midX { return true }

        let destination = CGPoint(
            x: initialBoundaryFrame.minX - 1,
            y: initialBoundaryFrame.midY
        )
        guard await commandDrag(from: item.frame.center, to: destination),
              let updatedFrame = windowFrame(id: item.id),
              let updatedBoundary = boundaryFrame(.alwaysHidden, near: updatedFrame)
        else { return false }
        return updatedFrame.midX < updatedBoundary.midX
    }

    func moveToVisibleSection(_ item: MenuBarItemDescriptor) async -> Bool {
        guard let initialBoundaryFrame = boundaryFrame(.hidden, near: item.frame) else { return false }
        if item.frame.midX > initialBoundaryFrame.midX { return true }

        let destination = CGPoint(
            x: initialBoundaryFrame.maxX + 1,
            y: initialBoundaryFrame.midY
        )
        guard await commandDrag(from: item.frame.center, to: destination),
              let updatedFrame = windowFrame(id: item.id),
              let updatedBoundary = boundaryFrame(.hidden, near: updatedFrame)
        else { return false }
        return updatedFrame.midX > updatedBoundary.midX
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
        guard let screenFrame = displayFrames.first(where: {
            $0.contains(CGPoint(x: itemFrame.midX, y: itemFrame.midY))
        }) else { return nil }

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

    private func commandDrag(from start: CGPoint, to end: CGPoint) async -> Bool {
        let originalPointer = CGEvent(source: nil)?.location
        // Command-dragging a status item with synthetic events can otherwise
        // leave the user's pointer at the off-screen boundary. Keep the
        // hardware cursor independent during the short automation gesture and
        // restore it without generating a hover event afterwards.
        CGAssociateMouseAndMouseCursorPosition(0)
        defer {
            CGAssociateMouseAndMouseCursorPosition(1)
            if let originalPointer {
                CGWarpMouseCursorPosition(originalPointer)
            }
        }

        guard let source = CGEventSource(stateID: .hidSystemState),
              let mouseDown = CGEvent(
                mouseEventSource: source,
                mouseType: .leftMouseDown,
                mouseCursorPosition: start,
                mouseButton: .left
              )
        else { return false }

        mouseDown.flags = .maskCommand
        mouseDown.post(tap: .cghidEventTap)

        for step in 1...10 {
            let progress = CGFloat(step) / 10
            let point = CGPoint(
                x: start.x + (end.x - start.x) * progress,
                y: start.y + (end.y - start.y) * progress
            )
            guard let dragged = CGEvent(
                mouseEventSource: source,
                mouseType: .leftMouseDragged,
                mouseCursorPosition: point,
                mouseButton: .left
            ) else { continue }
            dragged.flags = .maskCommand
            dragged.post(tap: .cghidEventTap)
            try? await Task.sleep(for: .milliseconds(18))
        }

        guard let mouseUp = CGEvent(
            mouseEventSource: source,
            mouseType: .leftMouseUp,
            mouseCursorPosition: end,
            mouseButton: .left
        ) else { return false }
        mouseUp.flags = .maskCommand
        mouseUp.post(tap: .cghidEventTap)
        try? await Task.sleep(for: .milliseconds(180))
        return true
    }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}
