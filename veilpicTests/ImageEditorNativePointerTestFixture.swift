import AppKit
import Testing
@testable import musepic

@MainActor
enum ImageEditorNativePointerTestFixture {
    static func withHost(_ body: (ScrollWheelZoomNSView, NSWindow) throws -> Void) rethrows {
        let window = makeWindow()
        let host = ScrollWheelZoomNSView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        host.claimsKeyboardFocusOnPointerDown = false
        window.contentView?.addSubview(host)
        defer {
            host.teardownMonitor()
            host.removeFromSuperview()
            window.close()
        }
        try body(host, window)
    }

    static func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 320, height: 240),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        return window
    }

    static func event(
        _ type: NSEvent.EventType, window: NSWindow?,
        point: CGPoint = CGPoint(x: 50, y: 50)
    ) throws -> NSEvent {
        var result = try bridgedMouseEvent(type, window: window, point: point)
        if let window {
            // Normalize the synthetic bridge's origin, never the production geometry.
            let actual = result.locationInWindow
            result = try bridgedMouseEvent(type, window: window, point: CGPoint(
                x: point.x + (point.x - actual.x), y: point.y + (point.y - actual.y)
            ))
            try #require(result.window === window)
            try #require(result.locationInWindow == point)
        }
        try #require(result.type == type)
        try #require(result.buttonNumber == buttonNumber(for: type))
        return result
    }

    private static func buttonNumber(for type: NSEvent.EventType) -> Int {
        switch type {
        case .leftMouseDown, .leftMouseDragged, .leftMouseUp: return 0
        case .rightMouseDown, .rightMouseDragged, .rightMouseUp: return 1
        default: return 2
        }
    }

    private static func bridgedMouseEvent(
        _ type: NSEvent.EventType, window: NSWindow?, point: CGPoint
    ) throws -> NSEvent {
        let base = try #require(NSEvent.mouseEvent(
            with: type, location: point, modifierFlags: [], timestamp: 20,
            windowNumber: window?.windowNumber ?? 0, context: nil,
            eventNumber: 1, clickCount: 1, pressure: 0
        ))
        let raw = try #require(base.cgEvent)
        raw.setIntegerValueField(.mouseEventButtonNumber, value: Int64(buttonNumber(for: type)))
        return try #require(NSEvent(cgEvent: raw))
    }
}
