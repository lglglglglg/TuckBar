import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private var statusBarController: StatusBarController?
    private var settingsWindowController: NSWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // iBar-style menu bar utility: stay out of the Dock during normal use.
        // The settings window remains reachable from the status-item menu.
        NSApplication.shared.setActivationPolicy(.accessory)
        statusBarController = StatusBarController(model: model) { [weak self] in
            self?.showSettings()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        model.refreshPermissions()
        showSettings()
        return true
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        model.refreshPermissions()
        if model.hasAccessibilityPermission,
           !model.managedItems.isEmpty,
           !model.isHidingApplied {
            statusBarController?.applyHiddenItems()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusBarController?.expandBeforeTermination()
    }

    private func showSettings() {
        NSApplication.shared.setActivationPolicy(.regular)
        if settingsWindowController == nil {
            let rootView = SettingsView(
                model: model,
                refreshItems: { [weak self] in self?.statusBarController?.refreshMenuBarItems() },
                applyHiddenItems: { [weak self] in self?.statusBarController?.applyHiddenItems() },
                revealAllItems: { [weak self] in self?.statusBarController?.revealAllItems() },
                showAggregatePanel: { [weak self] in self?.statusBarController?.showAggregatePanel() },
                requestScreenRecordingPermission: { [weak self] in
                    self?.statusBarController?.requestScreenRecordingPermission()
                },
                requestAccessibilityPermission: { [weak self] in
                    self?.statusBarController?.requestAccessibilityPermission()
                },
                quit: { NSApplication.shared.terminate(nil) }
            )

            let window = NSWindow(contentViewController: NSHostingController(rootView: rootView))
            window.title = Brand.name
            window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isOpaque = false
            window.backgroundColor = .clear
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            settingsWindowController = NSWindowController(window: window)
        }

        NSApplication.shared.activate(ignoringOtherApps: true)
        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
    }
}
