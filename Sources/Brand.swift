import AppKit

@MainActor
enum Brand {
    static let name = "TuckBar"

    static func image(size: CGFloat, colored: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            if colored {
                let background = NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.04, dy: size * 0.04), xRadius: size * 0.22, yRadius: size * 0.22)
                NSColor(red: 0.055, green: 0.075, blue: 0.12, alpha: 1).setFill()
                background.fill()
            }
            let foreground = colored ? NSColor.white : NSColor.black
            foreground.setFill()
            let left = size * 0.22
            let right = size * 0.78
            let bottom = size * 0.25
            let top = size * 0.63
            let radius = size * 0.13
            let tray = NSBezierPath(roundedRect: NSRect(x: left, y: bottom, width: right - left, height: top - bottom), xRadius: radius, yRadius: radius)
            tray.windingRule = .evenOdd
            let opening = NSBezierPath(roundedRect: NSRect(x: size * 0.30, y: size * 0.52, width: size * 0.40, height: size * 0.14), xRadius: size * 0.07, yRadius: size * 0.07)
            tray.append(opening)
            tray.fill()

            if colored {
                let fold = NSBezierPath()
                fold.move(to: NSPoint(x: size * 0.63, y: size * 0.63))
                fold.line(to: NSPoint(x: size * 0.73, y: size * 0.63))
                fold.line(to: NSPoint(x: size * 0.63, y: size * 0.53))
                fold.close()
                NSColor(red: 0.20, green: 0.48, blue: 1.0, alpha: 1).setFill()
                fold.fill()
            }
            return true
        }
        image.isTemplate = !colored
        return image
    }
}
