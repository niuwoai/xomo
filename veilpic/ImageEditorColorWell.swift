import AppKit
import SwiftUI

/// A standard macOS color well that deliberately stays out of the editor's
/// keyboard focus chain. Clicking it opens the system color panel; changing
/// the panel updates the bound editor color continuously.
@MainActor
final class ImageEditorColorWellControl: NSColorWell {
    static let swatchBorderWidth: CGFloat = 1

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
        focusRingType = .none
        target = self
        action = #selector(colorDidChange(_:))
    }

    override func draw(_ dirtyRect: NSRect) {
        let borderWidth = Self.swatchBorderWidth
        let swatchRect = bounds.insetBy(dx: borderWidth / 2, dy: borderWidth / 2)
        let path = NSBezierPath(rect: swatchRect)
        (color.usingColorSpace(.deviceRGB) ?? color).setFill()
        path.fill()
        NSColor.white.withAlphaComponent(0.92).setStroke()
        path.lineWidth = borderWidth
        path.stroke()
    }

    @objc
    private func colorDidChange(_ sender: NSColorWell) {
        needsDisplay = true
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
