import AppKit

struct MenuBarItemDescriptor: Identifiable, Equatable {
    let id: CGWindowID
    let identifier: String
    let occurrence: Int
    let frame: CGRect
    var snapshot: NSImage?

    init(id: CGWindowID, identifier: String, occurrence: Int = 0, frame: CGRect, snapshot: NSImage? = nil) {
        self.id = id
        self.identifier = identifier
        self.occurrence = occurrence
        self.frame = frame
        self.snapshot = snapshot
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.identifier == rhs.identifier && lhs.frame == rhs.frame
    }

    var persistentIdentifier: String { "\(identifier)#\(occurrence)" }

    var displayName: String {
        if identifier.hasPrefix("unidentified.") {
            return "菜单栏项目"
        }
        switch identifier {
        case "com.openai.codex": return "Codex"
        case "cn.better365.iCopy": return "iCopy"
        case "cn.better365.iShotProHelper": return "iShot"
        case "com.liguangming.Shadowrocket.LaunchHelper": return "Shadowrocket"
        case "com.shrek.rightmouse": return "超级右键"
        case "com.sogou.inputmethod.sogou": return "搜狗输入法"
        default:
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) {
                return FileManager.default.displayName(atPath: appURL.path)
                    .replacingOccurrences(of: ".app", with: "")
            }
            return identifier.split(separator: ".").last.map(String.init) ?? identifier
        }
    }

    var icon: NSImage {
        if let snapshot {
            return snapshot
        }
        // A menu-bar item is not the same as its owning app. Never use the
        // application's icon as a misleading substitute for the original.
        return NSImage(systemSymbolName: "questionmark.square.dashed", accessibilityDescription: "原始菜单栏图标暂不可用") ?? NSImage()
    }
}
