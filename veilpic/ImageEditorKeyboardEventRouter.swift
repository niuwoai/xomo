import AppKit

enum ImageEditorKeyboardEventRouter {
    /// A nil handler result consumes the event; only a released owner is a fallback.
    static func monitorHandler<Owner: AnyObject>(
        for owner: Owner,
        handle: @escaping (Owner, NSEvent) -> NSEvent?
    ) -> (NSEvent) -> NSEvent? {
        { [weak owner] event in
            guard let owner else { return event }
            return handle(owner, event)
        }
    }

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
