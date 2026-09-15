import AppKit

@MainActor
enum Brand {
    static let name = "TuckBar"

    static func image(size: CGFloat, colored: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            if colored {
                let background = NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.04, dy: size * 0.04), xRadius: size * 0.22, yRadius: size * 0.22)
                NSGradient(starting: NSColor(red: 0.32, green: 0.29, blue: 0.88, alpha: 1), ending: NSColor(red: 0.10, green: 0.68, blue: 0.70, alpha: 1))!.draw(in: background, angle: -45)
            }
            (colored ? NSColor.white : NSColor.black).setStroke()
            let path = NSBezierPath()
            path.lineWidth = size * (colored ? 0.055 : 0.08)
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            let inset: CGFloat = colored ? 0.25 : 0.13
            let left = size * inset
            let right = size * (1 - inset)
            path.move(to: NSPoint(x: left, y: size * 0.73))
            path.line(to: NSPoint(x: right, y: size * 0.73))
            path.move(to: NSPoint(x: left, y: size * 0.51))
            path.line(to: NSPoint(x: left, y: size * 0.27))
            path.line(to: NSPoint(x: right, y: size * 0.27))
            path.line(to: NSPoint(x: right, y: size * 0.51))
            path.move(to: NSPoint(x: size * 0.40, y: size * 0.52))
            path.line(to: NSPoint(x: size * 0.50, y: size * 0.42))
            path.line(to: NSPoint(x: size * 0.60, y: size * 0.52))
            path.stroke()
            return true
        }
        image.isTemplate = !colored
        return image
    }
}
