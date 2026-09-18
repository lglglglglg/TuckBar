import CoreGraphics
import Darwin

/// Keeps synthetic menu-bar gestures invisible while TuckBar remains a
/// background accessory application. This follows Lloyd/Ice's proven approach:
/// opt the WindowServer connection into background cursor control, hide the
/// hardware cursor during the gesture, then restore the original position.
@MainActor
enum MouseCursor {
    private static var prepared = false

    static var location: CGPoint? {
        CGEvent(source: nil)?.location
    }

    static func prepareBackgroundControl() {
        guard !prepared else { return }
        prepared = true

        guard let skyLight = dlopen(
            "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight",
            RTLD_LAZY
        ),
        let mainSymbol = dlsym(skyLight, "CGSMainConnectionID"),
        let propertySymbol = dlsym(skyLight, "CGSSetConnectionProperty")
        else { return }

        typealias MainConnection = @convention(c) () -> UInt32
        typealias SetProperty = @convention(c) (UInt32, UInt32, CFString, CFTypeRef) -> Int32
        let mainConnection = unsafeBitCast(mainSymbol, to: MainConnection.self)
        let setProperty = unsafeBitCast(propertySymbol, to: SetProperty.self)
        let connection = mainConnection()
        _ = setProperty(connection, connection, "SetsCursorInBackground" as CFString, kCFBooleanTrue)
    }

    static func hide() {
        CGDisplayHideCursor(CGMainDisplayID())
    }

    static func show() {
        CGDisplayShowCursor(CGMainDisplayID())
    }

    static func warp(to point: CGPoint) {
        CGWarpMouseCursorPosition(point)
    }
}
