import AppKit
import SwiftUI

/// A square editor color swatch that deliberately stays out of the keyboard
/// focus chain. It uses the system color panel without inheriting NSColorWell's
/// native rounded/pill drawing, which would otherwise overlap our swatch.
@MainActor
final class ImageEditorColorWellControl: NSView {
    static let swatchBorderWidth: CGFloat = 1
    private static weak var activeColorWell: ImageEditorColorWellControl?

    var onColorChange: ((NSColor) -> Void)?
    var onEditingBegan: (() -> Bool)?
    var onEditingEnded: (() -> Void)?
    var colorPanelActivationHandler: (() -> Void)?
    var color: NSColor = .black {
        didSet { needsDisplay = true }
    }
    private(set) var isColorPanelEditing = false

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
        setAccessibilityElement(true)
        setAccessibilityRole(.colorWell)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(colorPanelEditingDidEnd(_:)),
            name: NSWindow.didResignKeyNotification,
            object: NSColorPanel.shared
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(colorPanelEditingDidEnd(_:)),
            name: NSWindow.willCloseNotification,
            object: NSColorPanel.shared
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(colorPanelEditingDidEnd(_:)),
            name: NSMenu.didBeginTrackingNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(colorPanelEditingDidEnd(_:)),
            name: NSApplication.didResignActiveNotification,
            object: NSApplication.shared
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            endColorPanelEditing()
        }
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

    func performClick(_ sender: Any?) {
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
        if let activeColorWell = Self.activeColorWell,
           activeColorWell !== self {
            activeColorWell.endColorPanelEditing()
        }
        guard beginColorPanelEditing() else { return }
        Self.activeColorWell = self
        panel.setTarget(self)
        panel.setAction(#selector(colorPanelDidChange(_:)))
        panel.isContinuous = true
        panel.color = color
        panel.makeKeyAndOrderFront(nil)
    }

    @objc
    private func colorPanelDidChange(_ sender: NSColorPanel) {
        guard beginColorPanelEditing() else { return }
        Self.activeColorWell = self
        color = sender.color
        onColorChange?(color)
    }

    @discardableResult
    func beginColorPanelEditing() -> Bool {
        guard !isColorPanelEditing else { return true }
        guard onEditingBegan?() ?? true else { return false }
        isColorPanelEditing = true
        return true
    }

    func endColorPanelEditing() {
        guard isColorPanelEditing else { return }
        isColorPanelEditing = false
        if Self.activeColorWell === self {
            Self.activeColorWell = nil
        }
        onEditingEnded?()
    }

    @objc
    private func colorPanelEditingDidEnd(_ notification: Notification) {
        endColorPanelEditing()
    }
}

struct ImageEditorColorWell: NSViewRepresentable {
    @Binding var color: NSColor
    var accessibilityIdentifier: String
    var accessibilityLabel: String
    var onEditingBegan: (() -> Bool)? = nil
    var onEditingEnded: (() -> Void)? = nil
    var activationRequestID: Int? = nil

    final class Coordinator {
        private var appliedActivationRequestID: Int?

        func synchronizeActivationRequest(_ requestID: Int?) {
            appliedActivationRequestID = requestID
        }

        func consumeActivationRequest(_ requestID: Int?) -> Bool {
            guard let requestID else { return false }
            defer { appliedActivationRequestID = requestID }
            return appliedActivationRequestID != requestID
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> ImageEditorColorWellControl {
        let colorWell = ImageEditorColorWellControl(
            frame: NSRect(x: 0, y: 0, width: 26, height: 26)
        )
        colorWell.color = color
        colorWell.onColorChange = { selectedColor in
            color = selectedColor
        }
        colorWell.onEditingBegan = onEditingBegan
        colorWell.onEditingEnded = onEditingEnded
        colorWell.toolTip = accessibilityLabel
        colorWell.setAccessibilityIdentifier(accessibilityIdentifier)
        colorWell.setAccessibilityLabel(accessibilityLabel)
        context.coordinator.synchronizeActivationRequest(activationRequestID)
        return colorWell
    }

    func updateNSView(_ colorWell: ImageEditorColorWellControl, context: Context) {
        if colorWell.color != color {
            colorWell.color = color
        }
        colorWell.onColorChange = { selectedColor in
            color = selectedColor
        }
        colorWell.onEditingBegan = onEditingBegan
        colorWell.onEditingEnded = onEditingEnded
        colorWell.toolTip = accessibilityLabel
        colorWell.setAccessibilityIdentifier(accessibilityIdentifier)
        colorWell.setAccessibilityLabel(accessibilityLabel)
        if context.coordinator.consumeActivationRequest(activationRequestID) {
            DispatchQueue.main.async { [weak colorWell] in
                colorWell?.performClick(nil)
            }
        }
    }

    static func dismantleNSView(
        _ colorWell: ImageEditorColorWellControl,
        coordinator: Coordinator
    ) {
        colorWell.endColorPanelEditing()
    }
}
