import AppKit
import SwiftUI
import Testing
@testable import musepic

@MainActor
struct ImageEditorLayerSearchFieldDispatchTests {
    @Test func nativeEditingCommandsDispatchOnlyTheirOwnAvailableCallback() {
        let selectors = [
            #selector(NSResponder.insertNewline(_:)),
            #selector(NSResponder.cancelOperation(_:)),
            #selector(NSResponder.moveUp(_:)),
            #selector(NSResponder.moveDown(_:))
        ]
        for (selectedIndex, selector) in selectors.enumerated() {
            for callbackAvailable in [false, true] {
                var counts = [0, 0, 0, 0]
                let field = ImageEditorLayerSearchField(
                    placeholder: "Search fixture",
                    text: .constant("fixture"),
                    onSubmit: callbackAvailable ? { counts[0] += 1 } : nil,
                    onCancel: callbackAvailable ? { counts[1] += 1 } : nil,
                    onMovePrevious: callbackAvailable ? { counts[2] += 1 } : nil,
                    onMoveNext: callbackAvailable ? { counts[3] += 1 } : nil
                )
                let coordinator = field.makeCoordinator()
                let control = NSTextField()
                let editor = NSTextView()
                let handled = coordinator.control(
                    control, textView: editor, doCommandBy: selector
                )
                var expected = [0, 0, 0, 0]
                if callbackAvailable { expected[selectedIndex] = 1 }
                #expect(handled == callbackAvailable)
                #expect(counts == expected)
                let unsupported = coordinator.control(
                    control, textView: editor,
                    doCommandBy: #selector(NSResponder.moveLeft(_:))
                )
                #expect(!unsupported)
                #expect(counts == expected)
            }
        }
    }
}
