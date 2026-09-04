import AppKit

enum ImageEditorSpacebarPanEventRouter {
    private static let spaceKeyCode: UInt16 = 49
    private static let shortcutModifiers: NSEvent.ModifierFlags = [.command, .option, .shift, .control]

    /// An active temporary hand ends on space-up, even if focus or modifiers changed.
    /// Cursor modifier state belongs to the enclosing event router, not this gesture.
    static func handle(
        _ event: NSEvent,
        isPanning: inout Bool,
        isTextInputActive: Bool,
        canBeginPanning: () -> Bool = { true },
        setPanning: (Bool) -> Void
    ) -> Bool {
        guard event.type == .keyDown || event.type == .keyUp,
              event.keyCode == spaceKeyCode else { return false }
        if event.type == .keyUp {
            guard isPanning else { return false }
            isPanning = false
            setPanning(false)
            return true
        }
        guard event.modifierFlags.intersection(shortcutModifiers).isEmpty,
              !isTextInputActive,
              canBeginPanning() else { return false }
        if !isPanning {
            isPanning = true
            setPanning(true)
        }
        return true
    }
}
