import AppKit
import CoreGraphics

@MainActor
enum MenuBarItemDiscovery {
    private struct Candidate {
        let id: CGWindowID
        let frame: CGRect
        let ownerBundleIdentifier: String?
        let windowName: String?
    }

    private static let genericWindowNames: Set<String> = [
        "", "Item-0", "BentoBox-0", "Battery", "Clock", "KeyboardBrightness",
        "AudioVideoModule"
    ]
    private static let ownBundleIdentifier = "com.hanshijiu.MenuBarOrganizer"

    static func discover(on screenFrame: CGRect? = nil) -> [MenuBarItemDescriptor] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let rows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        let statusLayer = Int(CGWindowLevelForKey(.statusWindow))
        var candidates: [Candidate] = []

        for row in rows {
            guard let boundsValue = row[kCGWindowBounds as String] else { continue }
            let boundsDictionary = boundsValue as! CFDictionary

            guard
                let layer = row[kCGWindowLayer as String] as? Int,
                layer == statusLayer,
                let windowNumber = row[kCGWindowNumber as String] as? NSNumber,
                let ownerPIDNumber = row[kCGWindowOwnerPID as String] as? NSNumber,
                let frame = CGRect(dictionaryRepresentation: boundsDictionary),
                frame.height <= 60,
                frame.width <= 240
            else { continue }

            // Window coordinates use a top-left origin. Each display can have
            // a different top edge, so do not assume every menu bar is at y=0.
            let isAtMenuBar = NSScreen.screens.contains { screen in
                guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return false }
                let display = CGDisplayBounds(number.uint32Value)
                return frame.midX >= display.minX && frame.midX < display.maxX
                    && abs(frame.minY - display.minY) <= 50
            }
            guard isAtMenuBar else { continue }

            let ownerPID = pid_t(ownerPIDNumber.int32Value)
            let ownerBundleIdentifier = NSRunningApplication(processIdentifier: ownerPID)?.bundleIdentifier
            guard ownerBundleIdentifier != ownBundleIdentifier else { continue }

            let windowID = CGWindowID(windowNumber.uint32Value)
            if let screenFrame,
               !screenFrame.contains(CGPoint(x: frame.midX, y: frame.midY)) {
                continue
            }
            candidates.append(Candidate(
                id: windowID,
                frame: frame,
                ownerBundleIdentifier: ownerBundleIdentifier,
                windowName: row[kCGWindowName as String] as? String
            ))
        }

        let sourceIdentities = MenuBarItemSourceResolver.sourceIdentities(for: candidates.map {
            .init(id: $0.id, frame: $0.frame)
        })
        let controlCenterBundleIdentifier = "com.apple.controlcenter"
        var occupiedFrames = Set<String>()

        var occurrences: [String: Int] = [:]
        return candidates.sorted { $0.frame.minX < $1.frame.minX }.compactMap { candidate in
            let sourceIdentity = sourceIdentities[candidate.id]
            let sourceBundleIdentifier = sourceIdentity
                .flatMap { NSRunningApplication(processIdentifier: $0.pid)?.bundleIdentifier }
            let meaningfulName = candidate.windowName.flatMap(meaningfulWindowName)

            // macOS 26 publishes a second, bundle-ID-named marker window for
            // many status items. It is not the clickable on-screen icon.
            if candidate.ownerBundleIdentifier == controlCenterBundleIdentifier,
               sourceBundleIdentifier == nil,
               meaningfulName != nil {
                return nil
            }

            let identifier = sourceBundleIdentifier
                ?? meaningfulName
                ?? "unidentified.\(candidate.id)"
            guard identifier != ownBundleIdentifier,
                  sourceBundleIdentifier != controlCenterBundleIdentifier
            else { return nil }

            let geometryKey = [candidate.frame.minX, candidate.frame.minY, candidate.frame.width, candidate.frame.height]
                .map { String(Int($0.rounded())) }
                .joined(separator: ":")
            guard occupiedFrames.insert(geometryKey).inserted else { return nil }
            let fallbackOccurrence = occurrences[identifier, default: 0]
            occurrences[identifier] = fallbackOccurrence + 1
            let occurrence = sourceIdentity?.occurrence ?? fallbackOccurrence
            return MenuBarItemDescriptor(
                id: candidate.id,
                identifier: identifier,
                occurrence: occurrence,
                frame: candidate.frame
            )
        }
    }

    private static func meaningfulWindowName(_ name: String) -> String? {
        guard !genericWindowNames.contains(name), name.contains(".") else { return nil }
        return name
    }

    /// Finds the current on-screen or off-screen window for a descriptor in case its WindowID changed
    static func resolveCurrentWindow(for item: MenuBarItemDescriptor) -> (id: CGWindowID, frame: CGRect, ownerPID: pid_t)? {
        // First try the known item.id directly
        if let rows = CGWindowListCopyWindowInfo([.optionIncludingWindow], item.id) as? [[String: Any]],
           let row = rows.first,
           let boundsValue = row[kCGWindowBounds as String],
           let boundsDict = boundsValue as? NSDictionary,
           let frame = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
           let pidNum = row[kCGWindowOwnerPID as String] as? NSNumber {
            return (id: item.id, frame: frame, ownerPID: pid_t(pidNum.int32Value))
        }

        // If direct lookup fails, discover all candidate windows and match by identifier & occurrence
        let allItems = discover()
        if let match = allItems.first(where: { $0.persistentIdentifier == item.persistentIdentifier }) {
            if let rows = CGWindowListCopyWindowInfo([.optionIncludingWindow], match.id) as? [[String: Any]],
               let row = rows.first,
               let pidNum = row[kCGWindowOwnerPID as String] as? NSNumber {
                return (id: match.id, frame: match.frame, ownerPID: pid_t(pidNum.int32Value))
            }
        }
        return nil
    }
}
