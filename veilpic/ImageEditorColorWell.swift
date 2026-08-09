import AppKit
import SwiftUI

/// A square editor color swatch that deliberately stays out of the keyboard
/// focus chain. It uses the system color panel without inheriting NSColorWell's
/// native rounded/pill drawing, which would otherwise overlap our swatch.
@MainActor
final class ImageEditorColorWellControl: NSControl {
    static let swatchBorderWidth: CGFloat = 1

    var onColorChange: ((NSColor) -> Void)?
    var colorPanelActivationHandler: (() -> Void)?
    var color: NSColor = .black {
        didSet { needsDisplay = true }
    }

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
        isContinuous = true
        focusRingType = .none
        setAccessibilityElement(true)
        setAccessibilityRole(.colorWell)
        target = self
        action = #selector(controlActivated(_:))
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

    override func mouseDown(with event: NSEvent) {
        activateColorPanel()
    }

    override func performClick(_ sender: Any?) {
        activateColorPanel()
    }

    override func accessibilityPerformPress() -> Bool {
        activateColorPanel()
        return true
    }

    private func activateColorPanel() {
        if let colorPanelActivationHandler {
            colorPanelActivationHandler()
            return
        }
        let panel = NSColorPanel.shared
        panel.setTarget(self)
        panel.setAction(#selector(colorPanelDidChange(_:)))
        panel.isContinuous = true
        panel.color = color
        panel.makeKeyAndOrderFront(nil)
    }

    @objc
    private func controlActivated(_ sender: NSControl) {
        activateColorPanel()
    }

    @objc
    private func colorPanelDidChange(_ sender: NSColorPanel) {
        color = sender.color
        onColorChange?(color)
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
