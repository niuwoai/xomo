import AppKit
import SwiftUI

/// A standard macOS color well that deliberately stays out of the editor's
/// keyboard focus chain. Clicking it opens the system color panel; changing
/// the panel updates the bound editor color continuously.
@MainActor
final class ImageEditorColorWellControl: NSColorWell {
    var onColorChange: ((NSColor) -> Void)?

    override var acceptsFirstResponder: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        isBordered = false
        isContinuous = true
        target = self
        action = #selector(colorDidChange(_:))
    }

    @objc
    private func colorDidChange(_ sender: NSColorWell) {
        onColorChange?(sender.color)
    }
}

struct ImageEditorColorWell: NSViewRepresentable {
    @Binding var color: NSColor
    var accessibilityIdentifier: String
    var accessibilityLabel: String

    func makeNSView(context: Context) -> ImageEditorColorWellControl {
        let colorWell = ImageEditorColorWellControl(
            frame: NSRect(x: 0, y: 0, width: 26, height: 26)
        )
        colorWell.color = color
        colorWell.onColorChange = { selectedColor in
            color = selectedColor
        }
        colorWell.toolTip = accessibilityLabel
        colorWell.setAccessibilityIdentifier(accessibilityIdentifier)
        colorWell.setAccessibilityLabel(accessibilityLabel)
        return colorWell
    }

    func updateNSView(_ colorWell: ImageEditorColorWellControl, context: Context) {
        if colorWell.color != color {
            colorWell.color = color
        }
        colorWell.onColorChange = { selectedColor in
            color = selectedColor
        }
        colorWell.toolTip = accessibilityLabel
        colorWell.setAccessibilityIdentifier(accessibilityIdentifier)
        colorWell.setAccessibilityLabel(accessibilityLabel)
    }
}
