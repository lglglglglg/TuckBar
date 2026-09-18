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

    /// Menu-bar AX elements expose `AXPick` on current macOS. `AXPress` may
    /// report success or do nothing, especially for Control Center-hosted
    /// status items, so keep this as the first activation path after the
    /// target has been revealed on-screen.
    static func pick(_ item: MenuBarItemDescriptor, visibleFrame: CGRect) -> Bool {
        guard AXIsProcessTrusted() else { return false }

        let unidentified = item.identifier.hasPrefix("unidentified.")
        for app in NSWorkspace.shared.runningApplications {
            guard app.isFinishedLaunching,
                  !app.isTerminated,
                  app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
                  unidentified || app.bundleIdentifier == item.identifier
            else { continue }

            let applicationElement = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(applicationElement, 0.5)
            guard let extrasMenuBar = elementAttribute(kAXExtrasMenuBarAttribute, of: applicationElement),
                  let children = elementArrayAttribute(kAXChildrenAttribute, of: extrasMenuBar)
            else { continue }

            let target: AXUIElement?
            if !unidentified, item.occurrence >= 0, item.occurrence < children.count {
                target = children[item.occurrence]
            } else {
                target = children.min { lhs, rhs in
                    distance(from: frame(of: lhs), to: visibleFrame)
                        < distance(from: frame(of: rhs), to: visibleFrame)
                }
            }

            guard let target else { continue }
            AXUIElementSetMessagingTimeout(target, 0.5)
            for action in ["AXPick", kAXPressAction as String, kAXShowMenuAction as String] {
                let result = AXUIElementPerformAction(target, action as CFString)
                if result == .success { return true }
                if result == .actionUnsupported || result == .notImplemented { continue }
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

    private static func distance(from childFrame: CGRect?, to targetFrame: CGRect) -> CGFloat {
        guard let childFrame else { return .greatestFiniteMagnitude }
        return hypot(childFrame.midX - targetFrame.midX, childFrame.midY - targetFrame.midY)
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
