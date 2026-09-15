import CoreGraphics

enum HidingGeometry {
    static let expandedSeparatorLength: CGFloat = 16
    static let collapsedSectionLength: CGFloat = 10_000

    static func collapsedLength(forDisplayWidths widths: [CGFloat]) -> CGFloat {
        collapsedSectionLength
    }

    static func windowID(from windowNumber: Int) -> CGWindowID? {
        guard let id = UInt32(exactly: windowNumber), id != 0 else { return nil }
        return id
    }
}
