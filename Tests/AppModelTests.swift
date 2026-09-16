import XCTest
@testable import TuckBar

@MainActor
final class AppModelTests: XCTestCase {
    func testAuthoritativeDiscoveryRemovesStaleMenuBarItems() {
        let defaults = UserDefaults.standard
        let keys = [
            "HiddenMenuBarItemIdentifiers",
            "AlwaysHiddenMenuBarItemIdentifiers",
            "ExplicitVisibleMenuBarItems"
        ]
        let savedValues = Dictionary(uniqueKeysWithValues: keys.map { ($0, defaults.object(forKey: $0)) })
        defer {
            for (key, value) in savedValues {
                if let value {
                    defaults.set(value, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
        }
        keys.forEach(defaults.removeObject(forKey:))

        let model = AppModel()
        let stale = MenuBarItemDescriptor(
            id: 101,
            identifier: "com.example.stale-item",
            frame: CGRect(x: 100, y: 0, width: 24, height: 24)
        )
        let current = MenuBarItemDescriptor(
            id: 102,
            identifier: "com.example.current-item",
            frame: CGRect(x: 130, y: 0, width: 24, height: 24)
        )

        model.updateDiscoveredItems([stale], replacingKnownItems: true)
        XCTAssertTrue(model.hiddenItems.contains { $0.persistentIdentifier == stale.persistentIdentifier })

        model.updateDiscoveredItems([current], replacingKnownItems: true)
        XCTAssertFalse(model.hiddenItems.contains { $0.persistentIdentifier == stale.persistentIdentifier })
        XCTAssertTrue(model.hiddenItems.contains { $0.persistentIdentifier == current.persistentIdentifier })
    }
}
