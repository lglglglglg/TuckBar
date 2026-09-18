import AppKit
import ApplicationServices

@MainActor
enum MenuBarItemSourceResolver {
    struct Candidate {
        let id: CGWindowID
        let frame: CGRect
    }

    struct SourceIdentity {
        let pid: pid_t
        let occurrence: Int
    }

    /// Invoke a real status-item action without moving the status item.
    ///
    /// iBar/Ice keep the item in their hidden section and use the
    /// accessibility representation of the menu-bar extra for activation.
    /// This is deliberately separate from the CGWindow discovery path: a
    /// window click would make macOS reveal the item, move the pointer and
    /// produce the drag-like animation that the aggregate bar is meant to
    /// avoid.
    static func press(_ item: MenuBarItemDescriptor) -> Bool {
        guard AXIsProcessTrusted() else { return false }

        let unidentified = item.identifier.hasPrefix("unidentified.")
        for app in NSWorkspace.shared.runningApplications {
            guard app.isFinishedLaunching,
                  !app.isTerminated,
                  app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
                  unidentified || app.bundleIdentifier == item.identifier
            else { continue }

            let applicationElement = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(applicationElement, 0.12)
            guard let extrasMenuBar = elementAttribute(kAXExtrasMenuBarAttribute, of: applicationElement),
                  let children = elementArrayAttribute(kAXChildrenAttribute, of: extrasMenuBar)
            else { continue }

            let target: AXUIElement?
            if unidentified {
                // Unresolved source identities can still be activated when
                // the accessibility child exposes the same screen frame.
                target = children.first { child in
                    guard let childFrame = frame(of: child) else { return false }
                    return hypot(childFrame.midX - item.frame.midX,
                                 childFrame.midY - item.frame.midY) <= 3
                }
            } else if item.occurrence >= 0, item.occurrence < children.count {
                // `occurrence` is recorded from this exact children array in
                // sourceIdentities(for:), so it remains stable across layout
                // changes while the owning app is running.
                target = children[item.occurrence]
            } else {
                target = nil
            }

            if let target, performMenuAction(on: target) {
                return true
            }

            // A helper can reorder its AX children after a wake or a menu
            // refresh. If the recorded occurrence no longer points at the
            // original element, use the closest current child as a bounded
            // fallback instead of clicking an unrelated screen coordinate.
            if !unidentified {
                let nearest = children.sorted {
                    distance(from: frame(of: $0), to: item.frame)
                        < distance(from: frame(of: $1), to: item.frame)
                }
                if let candidate = nearest.first,
                   distance(from: frame(of: candidate), to: item.frame)
                        <= max(40, item.frame.width * 2),
                   performMenuAction(on: candidate) {
                    return true
                }
            }
        }
        return false
    }

    private static func distance(from childFrame: CGRect?, to itemFrame: CGRect) -> CGFloat {
        guard let childFrame else { return .greatestFiniteMagnitude }
        return hypot(childFrame.midX - itemFrame.midX, childFrame.midY - itemFrame.midY)
    }

    private static func performMenuAction(on element: AXUIElement) -> Bool {
        // Some menu-bar helpers answer the first request with
        // kAXErrorCannotComplete while they are rebuilding their menu. Apple
        // documents that this result is retryable. The second action is the
        // native menu-opening action used by status items that do not expose a
        // normal button press.
        AXUIElementSetMessagingTimeout(element, 0.5)
        for action in [kAXPressAction as CFString, kAXShowMenuAction as CFString] {
            for _ in 0..<2 {
                let result = AXUIElementPerformAction(element, action)
                if result == .success { return true }
                if result == .actionUnsupported || result == .notImplemented { break }
            }
        }
        return false
    }

    static func sourceIdentities(for candidates: [Candidate]) -> [CGWindowID: SourceIdentity] {
        guard AXIsProcessTrusted(), !candidates.isEmpty else { return [:] }

        var unresolved = Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, $0.frame) })
        var result: [CGWindowID: SourceIdentity] = [:]

        for app in NSWorkspace.shared.runningApplications {
            guard !unresolved.isEmpty,
                  app.isFinishedLaunching,
                  !app.isTerminated,
                  app.processIdentifier != ProcessInfo.processInfo.processIdentifier
            else { continue }

            let applicationElement = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(applicationElement, 0.12)
            guard let extrasMenuBar = elementAttribute(kAXExtrasMenuBarAttribute, of: applicationElement),
                  let children = elementArrayAttribute(kAXChildrenAttribute, of: extrasMenuBar)
            else { continue }

            for (index, child) in children.enumerated() {
                guard let childFrame = frame(of: child) else { continue }
                let center = CGPoint(x: childFrame.midX, y: childFrame.midY)
                guard let match = unresolved.first(where: {
                    hypot($0.value.midX - center.x, $0.value.midY - center.y) <= 1.5
                }) else { continue }

                result[match.key] = SourceIdentity(pid: app.processIdentifier, occurrence: index)
                unresolved.removeValue(forKey: match.key)
            }
        }

        return result
    }

    private static func elementAttribute(_ name: String, of element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }
        return unsafeDowncast(value, to: AXUIElement.self)
    }

    private static func elementArrayAttribute(_ name: String, of element: AXUIElement) -> [AXUIElement]? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success,
              let values = value as? [AXUIElement]
        else { return nil }
        return values
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionValue,
              let sizeValue,
              CFGetTypeID(positionValue) == AXValueGetTypeID(),
              CFGetTypeID(sizeValue) == AXValueGetTypeID()
        else { return nil }

        let positionAXValue = unsafeDowncast(positionValue, to: AXValue.self)
        let sizeAXValue = unsafeDowncast(sizeValue, to: AXValue.self)
        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionAXValue, .cgPoint, &position),
              AXValueGetValue(sizeAXValue, .cgSize, &size)
        else { return nil }
        return CGRect(origin: position, size: size)
    }
}
