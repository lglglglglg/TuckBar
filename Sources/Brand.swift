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
            let tray = NSRect(x: size * inset, y: size * 0.28, width: size * (1 - inset * 2), height: size * 0.30)
            let upper = NSRect(x: tray.minX, y: size * 0.49, width: tray.width, height: tray.height)
            path.append(NSBezierPath(roundedRect: upper, xRadius: size * 0.09, yRadius: size * 0.09))
            path.append(NSBezierPath(roundedRect: tray, xRadius: size * 0.09, yRadius: size * 0.09))
            path.stroke()
            return true
        }
        image.isTemplate = !colored
        return image
    }
}
