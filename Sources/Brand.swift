import AppKit

@MainActor
enum Brand {
    static let name = "TuckBar"

    static func image(size: CGFloat, colored: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            if colored {
                let background = NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.04, dy: size * 0.04), xRadius: size * 0.22, yRadius: size * 0.22)
                NSColor(red: 0.11, green: 0.13, blue: 0.18, alpha: 1).setFill()
                background.fill()
            }
            (colored ? NSColor.white : NSColor.black).setStroke()
            let path = NSBezierPath()
            path.lineWidth = size * (colored ? 0.055 : 0.08)
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            let inset: CGFloat = colored ? 0.22 : 0.08
            let left = size * inset
            let right = size * (1 - inset)
            for (y, width) in [(0.68, 0.72), (0.50, 0.56), (0.32, 0.40)] {
                let rowLeft = size * (0.5 - width / 2)
                let rowRight = size * (0.5 + width / 2)
                path.move(to: NSPoint(x: rowLeft, y: size * y))
                path.line(to: NSPoint(x: rowRight, y: size * y))
            }
            path.move(to: NSPoint(x: size * 0.76, y: size * 0.32))
            path.line(to: NSPoint(x: size * 0.82, y: size * 0.32))
            path.stroke()
            return true
        }
        image.isTemplate = !colored
        return image
    }
}
