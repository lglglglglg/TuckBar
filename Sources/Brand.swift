import AppKit

@MainActor
enum Brand {
    static let name = "TuckBar"

    static func image(size: CGFloat, colored: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            if colored {
                let background = NSBezierPath(
                    roundedRect: rect.insetBy(dx: size * 0.055, dy: size * 0.055),
                    xRadius: size * 0.22,
                    yRadius: size * 0.22
                )
                NSColor(red: 0.055, green: 0.065, blue: 0.105, alpha: 1).setFill()
                background.fill()
            }

            let markFrame = colored
                ? NSRect(x: size * 0.25, y: size * 0.29, width: size * 0.50, height: size * 0.42)
                : NSRect(x: size * 0.08, y: size * 0.17, width: size * 0.84, height: size * 0.66)
            let lineWidth = size * (colored ? 0.052 : 0.105)
            let cornerRadius = size * (colored ? 0.10 : 0.14)
            let foreground = colored
                ? NSColor(calibratedWhite: 0.94, alpha: 1)
                : NSColor.black

            foreground.setStroke()
            let outline = NSBezierPath(
                roundedRect: markFrame.insetBy(dx: lineWidth / 2, dy: lineWidth / 2),
                xRadius: cornerRadius,
                yRadius: cornerRadius
            )
            outline.lineWidth = lineWidth
            outline.lineJoinStyle = .round
            outline.stroke()

            let divider = NSBezierPath()
            divider.move(to: NSPoint(x: markFrame.minX + size * (colored ? 0.055 : 0.11), y: markFrame.midY))
            divider.line(to: NSPoint(x: markFrame.maxX - size * (colored ? 0.055 : 0.11), y: markFrame.midY))
            divider.lineWidth = lineWidth
            divider.lineCapStyle = .round
            divider.stroke()
            return true
        }
        image.isTemplate = !colored
        return image
    }
}
