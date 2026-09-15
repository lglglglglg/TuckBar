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
            let inset: CGFloat = colored ? 0.23 : 0.10
            let tray = NSRect(x: size * inset, y: size * 0.29, width: size * (1 - inset * 2), height: size * 0.42)
            path.append(NSBezierPath(roundedRect: tray, xRadius: size * 0.10, yRadius: size * 0.10))
            path.move(to: NSPoint(x: tray.minX + size * 0.06, y: size * 0.52))
            path.line(to: NSPoint(x: tray.maxX - size * 0.06, y: size * 0.52))
            path.move(to: NSPoint(x: size * 0.43, y: tray.minY))
            path.line(to: NSPoint(x: size * 0.50, y: size * 0.22))
            path.line(to: NSPoint(x: size * 0.57, y: tray.minY))
            path.stroke()
            return true
        }
        image.isTemplate = !colored
        return image
    }
}
