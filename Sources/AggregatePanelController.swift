import AppKit
import SwiftUI

@MainActor
final class AggregatePanelController {
    private var panel: NSPanel?
    private var activateItem: ((MenuBarItemDescriptor) -> Void)?
    private var snapshotCache: [String: NSImage] = [:]
    private(set) var items: [MenuBarItemDescriptor] = []
    var isVisible: Bool { panel?.isVisible == true }
    var frame: CGRect? { panel?.frame }

    func hasCachedSnapshots(for items: [MenuBarItemDescriptor]) -> Bool {
        !items.isEmpty && items.allSatisfy { snapshotCache[$0.persistentIdentifier] != nil }
    }

    func cachedSnapshotCount(for items: [MenuBarItemDescriptor]) -> Int {
        items.reduce(into: 0) { count, item in
            if snapshotCache[item.persistentIdentifier] != nil { count += 1 }
        }
    }

    func preloadSnapshots(for sourceItems: [MenuBarItemDescriptor]) async {
        let missingItems = sourceItems.filter { snapshotCache[$0.persistentIdentifier] == nil }
        guard !missingItems.isEmpty else { return }
        let enrichedItems = await MenuBarItemSnapshotService.enrich(missingItems)
        for item in enrichedItems {
            if let snapshot = item.snapshot {
                snapshotCache[item.persistentIdentifier] = snapshot
            }
        }
    }

    private var onOpenSettings: (() -> Void)?
    private var onSetPlacement: ((MenuBarItemDescriptor, MenuBarItemPlacement) -> Void)?

    func refreshAndShow(
        items selectedItems: [MenuBarItemDescriptor],
        anchorWindow: NSWindow?,
        onOpenSettings: (() -> Void)? = nil,
        onSetPlacement: ((MenuBarItemDescriptor, MenuBarItemPlacement) -> Void)? = nil,
        activate: @escaping (MenuBarItemDescriptor) -> Void
    ) {
        self.activateItem = activate
        self.onOpenSettings = onOpenSettings
        self.onSetPlacement = onSetPlacement
        items = selectedItems.compactMap { item in
            guard let snapshot = snapshotCache[item.persistentIdentifier] else { return nil }
            var cachedItem = item
            cachedItem.snapshot = snapshot
            return cachedItem
        }
        rebuildPanel()
        positionPanel(anchorWindow: anchorWindow)
        panel?.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func contains(_ screenPoint: CGPoint) -> Bool {
        panel?.frame.insetBy(dx: -8, dy: -8).contains(screenPoint) == true
    }

    private func rebuildPanel() {
        let rootView = AggregatePanelView(
            items: items,
            activate: { [weak self] item in
                self?.activate(item)
            },
            onSetPlacement: { [weak self] item, placement in
                self?.onSetPlacement?(item, placement)
            },
            onOpenSettings: { [weak self] in
                self?.hide()
                self?.onOpenSettings?()
            }
        )
        let hostingController = NSHostingController(rootView: rootView)

        if panel == nil {
            let newPanel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 240, height: 42),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            newPanel.level = .statusBar
            newPanel.isOpaque = false
            newPanel.backgroundColor = .clear
            newPanel.hasShadow = true
            newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            newPanel.hidesOnDeactivate = false
            newPanel.becomesKeyOnlyIfNeeded = true
            panel = newPanel
        }

        panel?.contentViewController = hostingController
        panel?.setContentSize(hostingController.view.fittingSize)
    }

    private func positionPanel(anchorWindow: NSWindow?) {
        guard let panel else { return }
        let screen = anchorWindow?.screen ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }

        let size = panel.frame.size
        // Match iBar's visual relationship: the second-row bar ends beneath
        // the trigger instead of floating around the centre of the screen.
        let anchorRight = anchorWindow?.frame.maxX ?? screen.visibleFrame.maxX
        let proposedX = anchorRight - size.width
        let minimumX = screen.visibleFrame.minX + 10
        let maximumX = screen.visibleFrame.maxX - size.width - 10
        let x = min(max(proposedX, minimumX), maximumX)
        let y = screen.frame.maxY - NSStatusBar.system.thickness - size.height - 5
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func activate(_ item: MenuBarItemDescriptor) {
        hide()
        activateItem?(item)
    }
}
