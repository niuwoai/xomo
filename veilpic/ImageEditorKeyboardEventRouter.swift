import AppKit

enum ImageEditorKeyboardEventRouter {
    /// Modifier-only events update cursor state but have no readable characters.
    /// Keep their original event in AppKit's responder chain.
    static func route(
        _ event: NSEvent,
        updateCanvasModifiers: (NSEvent.ModifierFlags) -> Void,
        handleKeyEvent: (NSEvent) -> NSEvent?
    ) -> NSEvent? {
        updateCanvasModifiers(
            event.modifierFlags.intersection([.shift, .option, .capsLock])
        )
        guard event.type == .keyDown || event.type == .keyUp else {
            return event
        }
        return handleKeyEvent(event)
    }
}
