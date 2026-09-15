import AppKit
import ScreenCaptureKit

@MainActor
enum MenuBarItemSnapshotService {
    static func enrich(_ items: [MenuBarItemDescriptor]) async -> [MenuBarItemDescriptor] {
        // Do not call ScreenCaptureKit before permission is granted: macOS
        // otherwise presents the authorization prompt on every refresh.
        guard !items.isEmpty, CGPreflightScreenCaptureAccess() else { return items }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                true,
                onScreenWindowsOnly: true
            )
            let windowsByID = Dictionary(
                uniqueKeysWithValues: content.windows.map { ($0.windowID, $0) }
            )

            var enriched = items
            for index in enriched.indices {
                guard let window = windowsByID[enriched[index].id] else { continue }
                if let snapshot = try? await capture(window: window, frame: enriched[index].frame) {
                    enriched[index].snapshot = snapshot
                }
            }
            return enriched
        } catch {
            // Discovery and click forwarding still work without capture access.
            return items
        }
    }

    private static func capture(window: SCWindow, frame: CGRect) async throws -> NSImage {
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let configuration = SCStreamConfiguration()
        let scale = NSScreen.screens
            .first(where: {
                guard let number = $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return false }
                return CGDisplayBounds(number.uint32Value).intersects(frame)
            })?
            .backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        configuration.width = max(1, Int(frame.width * scale))
        configuration.height = max(1, Int(frame.height * scale))
        configuration.showsCursor = false
        configuration.ignoreShadowsSingleWindow = true

        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )
        return NSImage(cgImage: image, size: frame.size)
    }
}
