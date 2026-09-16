import Combine
import CoreGraphics
import Foundation

enum MenuBarItemPlacement: String, CaseIterable, Identifiable {
    case visible
    case hidden
    case alwaysHidden

    var id: Self { self }

    var title: String {
        switch self {
        case .visible: "常显"
        case .hidden: "隐藏"
        case .alwaysHidden: "始终隐藏"
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var discoveredItems: [MenuBarItemDescriptor] = []
    @Published private(set) var hiddenItemIdentifiers: Set<String>
    @Published private(set) var alwaysHiddenItemIdentifiers: Set<String>
    @Published private(set) var isHidingApplied = false
    @Published private(set) var operationMessage = "尚未应用隐藏设置"
    @Published private(set) var hasScreenRecordingPermission = false
    @Published private(set) var hasAccessibilityPermission = false
    @Published var openOnHover: Bool {
        didSet { UserDefaults.standard.set(openOnHover, forKey: Self.openOnHoverDefaultsKey) }
    }

    private static let hiddenItemsDefaultsKey = "HiddenMenuBarItemIdentifiers"
    private static let alwaysHiddenItemsDefaultsKey = "AlwaysHiddenMenuBarItemIdentifiers"
    private static let openOnHoverDefaultsKey = "OpenAggregateBarOnHover"
    private var knownItems: [String: MenuBarItemDescriptor] = [:]
    private var explicitVisibleIdentifiers = Set(UserDefaults.standard.stringArray(forKey: "ExplicitVisibleMenuBarItems") ?? [])

    init() {
        hiddenItemIdentifiers = Set(
            UserDefaults.standard.stringArray(forKey: Self.hiddenItemsDefaultsKey) ?? []
        )
        alwaysHiddenItemIdentifiers = Set(
            UserDefaults.standard.stringArray(forKey: Self.alwaysHiddenItemsDefaultsKey) ?? []
        )
        openOnHover = UserDefaults.standard.object(forKey: Self.openOnHoverDefaultsKey) as? Bool ?? true
        refreshPermissions()
    }

    var hiddenItems: [MenuBarItemDescriptor] {
        knownItems.values
            .filter { isHidden($0) }
            .sorted { $0.frame.minX < $1.frame.minX }
    }

    var alwaysHiddenItems: [MenuBarItemDescriptor] {
        knownItems.values
            .filter { placement(for: $0) == .alwaysHidden }
            .sorted { $0.frame.minX < $1.frame.minX }
    }

    var managedItems: [MenuBarItemDescriptor] {
        hiddenItems + alwaysHiddenItems
    }

    func updateDiscoveredItems(
        _ items: [MenuBarItemDescriptor],
        replacingKnownItems: Bool = false
    ) {
        discoveredItems = items
        if replacingKnownItems {
            let currentIdentifiers = Set(items.map(\.persistentIdentifier))
            knownItems = knownItems.filter { currentIdentifiers.contains($0.key) }
        }
        for item in items {
            knownItems[item.persistentIdentifier] = item
            // Newly discovered third-party status items are collected on launch.
            // Keep system controls and any explicit user exception visible.
            if !item.identifier.hasPrefix("com.apple."),
               !item.identifier.hasPrefix("unidentified."),
               !explicitVisibleIdentifiers.contains(item.persistentIdentifier),
               !contains(item, in: alwaysHiddenItemIdentifiers) {
                hiddenItemIdentifiers.insert(item.persistentIdentifier)
            }
        }
        persistPlacements()
    }

    func isHidden(_ item: MenuBarItemDescriptor) -> Bool {
        placement(for: item) == .hidden
    }

    func setHidden(_ hidden: Bool, for item: MenuBarItemDescriptor) {
        setPlacement(hidden ? .hidden : .visible, for: item)
    }

    func placement(for item: MenuBarItemDescriptor) -> MenuBarItemPlacement {
        if contains(item, in: alwaysHiddenItemIdentifiers) { return .alwaysHidden }
        if contains(item, in: hiddenItemIdentifiers) { return .hidden }
        return .visible
    }

    func setPlacement(_ placement: MenuBarItemPlacement, for item: MenuBarItemDescriptor) {
        remove(item, from: &hiddenItemIdentifiers)
        remove(item, from: &alwaysHiddenItemIdentifiers)

        switch placement {
        case .visible:
            explicitVisibleIdentifiers.insert(item.persistentIdentifier)
        case .hidden:
            explicitVisibleIdentifiers.remove(item.persistentIdentifier)
            hiddenItemIdentifiers.insert(item.persistentIdentifier)
        case .alwaysHidden:
            explicitVisibleIdentifiers.remove(item.persistentIdentifier)
            alwaysHiddenItemIdentifiers.insert(item.persistentIdentifier)
        }
        persistPlacements()
    }

    func updateHidingState(applied: Bool, message: String) {
        isHidingApplied = applied
        operationMessage = message
    }

    func refreshPermissions() {
        hasScreenRecordingPermission = CGPreflightScreenCaptureAccess()
        hasAccessibilityPermission = MenuBarItemActivator.hasAccessibilityPermission
    }

    private func contains(_ item: MenuBarItemDescriptor, in identifiers: Set<String>) -> Bool {
        identifiers.contains(item.persistentIdentifier) || identifiers.contains(item.identifier)
    }

    private func remove(_ item: MenuBarItemDescriptor, from identifiers: inout Set<String>) {
        identifiers.remove(item.persistentIdentifier)
        identifiers.remove(item.identifier)
    }

    private func persistPlacements() {
        UserDefaults.standard.set(Array(explicitVisibleIdentifiers).sorted(), forKey: "ExplicitVisibleMenuBarItems")
        UserDefaults.standard.set(Array(hiddenItemIdentifiers).sorted(), forKey: Self.hiddenItemsDefaultsKey)
        UserDefaults.standard.set(Array(alwaysHiddenItemIdentifiers).sorted(), forKey: Self.alwaysHiddenItemsDefaultsKey)
    }
}
