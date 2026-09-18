import AppKit

@MainActor
final class StatusBarController: NSObject {
    private let statusBar = NSStatusBar.system
    private let model: AppModel
    private let showSettings: () -> Void
    private let aggregatePanel = AggregatePanelController()
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var hoverOpenTask: Task<Void, Never>?
    private var hoverCloseTask: Task<Void, Never>?
    private var panelPresentationTask: Task<Void, Never>?
    private var panelPresentationID: UUID?
    private var layoutRecoveryTask: Task<Void, Never>?
    private var isApplyingLayout = false
    private var isRecoveringLayout = false

    private lazy var toggleItem = statusBar.statusItem(withLength: NSStatusItem.squareLength)
    private lazy var hidingEngine = MenuBarHidingEngine(statusBar: statusBar)

    init(model: AppModel, showSettings: @escaping () -> Void) {
        self.model = model
        self.showSettings = showSettings
        super.init()

        configureToggleItem()
        // Create the invisible boundary after the visible controller. Items
        // moved to its left can then be displaced without hiding the controller.
        _ = hidingEngine
        observeDisplayChanges()
        observeWorkspaceWakeEvents()
        observePointerForHoverTrigger()
        refreshMenuBarItems()
        restoreSavedLayoutAfterLaunch()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc func handleToggleItemAction() {
        if NSApplication.shared.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else {
            toggle()
        }
    }

    func toggle() {
        if aggregatePanel.isVisible || panelPresentationTask != nil {
            dismissAggregatePanel()
        } else {
            showAggregatePanel()
        }
    }

    func showAggregatePanel() {
        guard panelPresentationTask == nil, !aggregatePanel.isVisible else { return }
        let presentationID = UUID()
        panelPresentationID = presentationID
        panelPresentationTask = Task { [weak self] in
            guard let self else { return }
            await self.showAggregatePanelNow()
            if self.panelPresentationID == presentationID {
                self.panelPresentationTask = nil
                self.panelPresentationID = nil
            }
        }
    }

    func refreshMenuBarItems(replacingKnownItems: Bool = false) {
        model.refreshPermissions()
        model.updateDiscoveredItems(
            MenuBarItemDiscovery.discover(on: currentScreenFrame),
            replacingKnownItems: replacingKnownItems
        )
    }

    func applyHiddenItems() {
        Task { [weak self] in await self?.applyHiddenItemsNow() }
    }

    func revealAllItems() {
        dismissAggregatePanel(restoreCollapsedLayout: false)
        hidingEngine.expand()
        model.updateHidingState(applied: false, message: "已暂时展开全部原始菜单栏项目")
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            self?.refreshMenuBarItems(replacingKnownItems: true)
        }
    }

    func requestScreenRecordingPermission() {
        _ = CGRequestScreenCaptureAccess()
        model.refreshPermissions()
        if !model.hasScreenRecordingPermission {
            model.updateHidingState(applied: false, message: "若系统开关已经打开却仍不可用，请在屏幕录制列表移除旧的 MenuBarOrganizer，再用 + 添加当前 dist/MenuBarOrganizer.app，随后退出并重开。开发测试包更新后旧授权可能失效。")
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        } else {
            applyHiddenItems()
        }
    }

    func requestAccessibilityPermission() {
        MenuBarItemActivator.requestAccessibilityPermission()
        model.refreshPermissions()
    }

    func expandBeforeTermination() {
        dismissAggregatePanel(restoreCollapsedLayout: false)
        hidingEngine.expand()
    }

    private var currentScreenFrame: CGRect? {
        guard let screen = toggleItem.button?.window?.screen ?? NSScreen.main,
              let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        else { return nil }
        return CGDisplayBounds(number.uint32Value)
    }

    private func configureToggleItem() {
        toggleItem.autosaveName = "com.hanshijiu.MenuBarOrganizer.toggle"
        toggleItem.isVisible = true
        guard let button = toggleItem.button else { return }
        button.image = Brand.image(size: 21, colored: false)
        button.imageScaling = .scaleProportionallyDown
        button.imagePosition = .imageOnly
        button.toolTip = "TuckBar：打开收纳条"
        button.target = self
        button.action = #selector(handleToggleItemAction)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func applyHiddenItemsNow() async {
        guard !isApplyingLayout else { return }
        dismissAggregatePanel(restoreCollapsedLayout: false)
        isApplyingLayout = true
        defer { isApplyingLayout = false }

        model.refreshPermissions()
        guard model.hasScreenRecordingPermission else {
            hidingEngine.expand()
            model.updateHidingState(applied: false, message: "当前版本尚未获得屏幕录制权限，无法读取原始图标和收纳边界。请在系统设置中授权此应用，再退出并重新打开。")
            return
        }
        guard model.hasAccessibilityPermission else {
            model.updateHidingState(applied: false, message: "需要先授权辅助功能，才能移动原始菜单栏项目")
            requestAccessibilityPermission()
            return
        }

        hidingEngine.expand()
        model.updateHidingState(applied: false, message: "正在整理原始菜单栏项目…")
        try? await Task.sleep(for: .milliseconds(300))
        refreshMenuBarItems(replacingKnownItems: true)

        // Capture original status-item artwork while every selected item is
        // still visible. The aggregate bar can then open without placeholders
        // or a visible expand/collapse flash.
        await aggregatePanel.preloadSnapshots(for: model.hiddenItems)

        let hiddenIdentifiers = Set(model.hiddenItems.map(\.persistentIdentifier))
        let alwaysHiddenIdentifiers = Set(model.alwaysHiddenItems.map(\.persistentIdentifier))
        var currentItems = MenuBarItemDiscovery.discover(on: currentScreenFrame)
        // Re-discover before every drag because moving one status item shifts
        // the geometry of its neighbours.
        let restoreIdentifiers = currentItems
            .filter { model.placement(for: $0) == .visible }
            .map(\.persistentIdentifier)
        for identifier in restoreIdentifiers {
            currentItems = MenuBarItemDiscovery.discover(on: currentScreenFrame)
            guard let item = currentItems.first(where: { $0.persistentIdentifier == identifier }) else { continue }
            _ = await hidingEngine.moveToVisibleSection(item)
        }

        var moved = 0
        for identifier in hiddenIdentifiers {
            currentItems = MenuBarItemDiscovery.discover(on: currentScreenFrame)
            model.updateDiscoveredItems(currentItems)
            guard let item = currentItems.first(where: { $0.persistentIdentifier == identifier }) else { continue }
            if await hidingEngine.moveToHiddenSection(item) { moved += 1 }
        }

        var movedAlwaysHidden = 0
        for identifier in alwaysHiddenIdentifiers {
            currentItems = MenuBarItemDiscovery.discover(on: currentScreenFrame)
            model.updateDiscoveredItems(currentItems)
            guard let item = currentItems.first(where: { $0.persistentIdentifier == identifier }) else { continue }
            if await hidingEngine.moveToAlwaysHiddenSection(item) { movedAlwaysHidden += 1 }
        }

        let managedCount = hiddenIdentifiers.count + alwaysHiddenIdentifiers.count
        guard managedCount > 0 else {
            model.updateHidingState(applied: false, message: "收纳区为空，当前保持全部展开")
            return
        }

        hidingEngine.collapse()
        let didApplyAll = moved + movedAlwaysHidden == managedCount
        model.updateHidingState(
            applied: didApplyAll,
            message: didApplyAll
                ? "已收起 \(moved) 项，始终隐藏 \(movedAlwaysHidden) 项"
                : "已移动 \(moved + movedAlwaysHidden)/\(managedCount) 项；其余项目可能不支持 Command 拖动"
        )
    }

    private func showAggregatePanelNow() async {
        guard !isApplyingLayout else { return }
        model.refreshPermissions()
        guard model.hasScreenRecordingPermission else {
            aggregatePanel.hide()
            model.updateHidingState(applied: false, message: "需要屏幕录制权限才能显示原始菜单栏图标。请授权当前应用，再退出并重新打开。")
            showSettings()
            return
        }
        var selectedItems = model.hiddenItems

        // Capturing is only needed until every selected item has a cached
        // original image. Subsequent opens stay collapsed and appear instantly.
        let needsCapture = model.hasScreenRecordingPermission
            && !aggregatePanel.hasCachedSnapshots(for: selectedItems)
        if needsCapture {
            hidingEngine.expandHiddenSection()
            guard await waitUnlessCancelled(.milliseconds(280)) else {
                restoreCollapsedLayoutIfNeeded()
                return
            }
            refreshMenuBarItems()
            selectedItems = model.hiddenItems
            await aggregatePanel.preloadSnapshots(for: selectedItems)
        }

        // The source items must be hidden before the aggregate panel appears.
        // Showing both at once creates a duplicate row and exposes internal
        // capture work to the user.
        restoreCollapsedLayoutIfNeeded()
        guard await waitUnlessCancelled(.milliseconds(80)) else { return }

        let cachedCount = aggregatePanel.cachedSnapshotCount(for: selectedItems)
        guard selectedItems.isEmpty || cachedCount > 0 else {
            model.updateHidingState(
                applied: true,
                message: "暂时无法读取菜单栏图标，请稍后重新扫描"
            )
            return
        }

        aggregatePanel.refreshAndShow(
            items: selectedItems,
            anchorWindow: toggleItem.button?.window,
            activate: { [weak self] item in
                Task { await self?.activateHiddenItem(item) }
            }
        )
        if cachedCount < selectedItems.count {
            model.updateHidingState(
                applied: true,
                message: "已显示 \(cachedCount)/\(selectedItems.count) 项；暂时无法读取的项目已忽略"
            )
        }
    }

    private func dismissAggregatePanel(restoreCollapsedLayout: Bool = true) {
        panelPresentationTask?.cancel()
        panelPresentationTask = nil
        panelPresentationID = nil
        hoverOpenTask?.cancel()
        hoverOpenTask = nil
        aggregatePanel.hide()
        if restoreCollapsedLayout {
            restoreCollapsedLayoutIfNeeded()
        }
    }

    private func restoreCollapsedLayoutIfNeeded() {
        if !model.managedItems.isEmpty {
            hidingEngine.collapse()
        }
    }

    private func waitUnlessCancelled(_ duration: Duration) async -> Bool {
        do {
            try await Task.sleep(for: duration)
            return !Task.isCancelled
        } catch {
            return false
        }
    }

    private func activateHiddenItem(_ item: MenuBarItemDescriptor) async {
        // Reveal the regular hidden section only long enough to move this one
        // real status item across the visible boundary. Always-hidden items
        // remain displaced throughout the operation.
        hidingEngine.expandHiddenSection()
        try? await Task.sleep(for: .milliseconds(240))
        var currentItems = MenuBarItemDiscovery.discover(on: currentScreenFrame)
        model.updateDiscoveredItems(currentItems)
        guard let current = currentItems.first(where: {
            $0.persistentIdentifier == item.persistentIdentifier
        }) else {
            hidingEngine.collapse()
            return
        }

        let isolated = await hidingEngine.moveToVisibleSection(current)
        hidingEngine.collapse()
        try? await Task.sleep(for: .milliseconds(140))

        currentItems = MenuBarItemDiscovery.discover(on: currentScreenFrame)
        model.updateDiscoveredItems(currentItems)
        if let exposed = currentItems.first(where: {
            $0.persistentIdentifier == item.persistentIdentifier
        }) {
            _ = MenuBarItemActivator.activate(exposed)
        } else if !isolated {
            model.updateHidingState(applied: true, message: "该项目无法单独临时显示")
            return
        }

        // The menu-open detector comes next; for now this delay preserves the
        // native item's interaction window before it is returned to its section.
        try? await Task.sleep(for: .milliseconds(1_100))
        hidingEngine.expandHiddenSection()
        try? await Task.sleep(for: .milliseconds(220))
        currentItems = MenuBarItemDiscovery.discover(on: currentScreenFrame)
        if let exposed = currentItems.first(where: {
            $0.persistentIdentifier == item.persistentIdentifier
        }) {
            _ = await hidingEngine.moveToHiddenSection(exposed)
        }
        hidingEngine.collapse()
    }

    private func observePointerForHoverTrigger() {
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            Task { @MainActor in self?.pointerMoved(to: NSEvent.mouseLocation) }
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            Task { @MainActor in self?.pointerMoved(to: NSEvent.mouseLocation) }
            return event
        }
    }

    private func pointerMoved(to point: CGPoint) {
        guard !isRecoveringLayout else { return }
        let triggerFrame = toggleItem.button?.window?.frame.insetBy(dx: -5, dy: -4)
        let isOverTrigger = triggerFrame?.contains(point) == true
        let isOverPanel = aggregatePanel.contains(point)

        if isOverTrigger, model.openOnHover {
            hoverCloseTask?.cancel()
            guard !aggregatePanel.isVisible, hoverOpenTask == nil else { return }
            hoverOpenTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(180))
                guard !Task.isCancelled else { return }
                self?.showAggregatePanel()
                self?.hoverOpenTask = nil
            }
        } else {
            hoverOpenTask?.cancel()
            hoverOpenTask = nil
        }

        if aggregatePanel.isVisible, !isOverTrigger, !isOverPanel {
            guard hoverCloseTask == nil else { return }
            hoverCloseTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(420))
                guard !Task.isCancelled else { return }
                self?.dismissAggregatePanel()
                self?.hoverCloseTask = nil
            }
        } else {
            hoverCloseTask?.cancel()
            hoverCloseTask = nil
        }
    }

    private func restoreSavedLayoutAfterLaunch() {
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(450))
            self?.refreshMenuBarItems()
            await self?.applyHiddenItemsNow()
        }
    }

    private func observeDisplayChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(displayConfigurationDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func displayConfigurationDidChange() {
        scheduleLayoutRecovery(after: .milliseconds(700))
    }

    private func observeWorkspaceWakeEvents() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(
            self,
            selector: #selector(workspaceDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(workspaceDidWake),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
    }

    @objc private func workspaceDidWake() {
        // The status-item server can restore items and discard our boundary
        // lengths while the Mac is locked. Re-apply only after it settles.
        scheduleLayoutRecovery(after: .milliseconds(900))
    }

    private func scheduleLayoutRecovery(after delay: Duration) {
        layoutRecoveryTask?.cancel()
        hoverOpenTask?.cancel()
        hoverOpenTask = nil
        hoverCloseTask?.cancel()
        hoverCloseTask = nil
        panelPresentationTask?.cancel()
        panelPresentationTask = nil
        panelPresentationID = nil
        aggregatePanel.hide()
        isRecoveringLayout = true
        hidingEngine.expand()

        layoutRecoveryTask = Task { [weak self] in
            guard let self else { return }
            guard await self.waitUnlessCancelled(delay) else { return }
            await self.applyHiddenItemsNow()
            guard !Task.isCancelled else { return }
            self.isRecoveringLayout = false
            self.layoutRecoveryTask = nil
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        addMenuItem("打开隐藏项目面板", action: #selector(openAggregatePanel), to: menu)
        addMenuItem("暂时展开全部", action: #selector(revealFromMenu), to: menu)
        addMenuItem("设置…", action: #selector(openSettings), keyEquivalent: ",", to: menu)
        menu.addItem(.separator())
        addMenuItem("退出 TuckBar", action: #selector(quitApplication), keyEquivalent: "q", to: menu)

        toggleItem.menu = menu
        toggleItem.button?.performClick(nil)
        toggleItem.menu = nil
    }

    private func addMenuItem(
        _ title: String,
        action: Selector,
        keyEquivalent: String = "",
        to menu: NSMenu
    ) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        menu.addItem(item)
    }

    @objc private func openSettings() { showSettings() }
    @objc private func openAggregatePanel() { showAggregatePanel() }
    @objc private func applyFromMenu() { applyHiddenItems() }
    @objc private func revealFromMenu() { revealAllItems() }
    @objc private func quitApplication() { NSApplication.shared.terminate(nil) }
}
