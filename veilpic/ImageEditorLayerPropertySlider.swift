import AppKit
import SwiftUI

/// Captured once at native mouse-down, never replaced by a SwiftUI body update.
@MainActor
struct ImageEditorLayerPropertyGestureCallbacks {
    let update: (Double) -> Void
    let finish: () -> Void
}

@MainActor
extension ImageEditorViewModel {
    func makeLayerPropertyGestureCallbacks(_ property: ImageEditorLayerGestureProperty) -> ImageEditorLayerPropertyGestureCallbacks? {
        guard let gesture = beginLayerPropertyGesture(property) else { return nil }
        return ImageEditorLayerPropertyGestureCallbacks(
            update: { [weak self] in self?.updateLayerPropertyGesture(gesture, value: $0) },
            finish: { [weak self] in self?.finishLayerPropertyGesture(gesture) }
        )
    }
}

@MainActor
final class ImageEditorLayerPropertyNativeSlider: NSSlider {
    var beginGesture: (() -> ImageEditorLayerPropertyGestureCallbacks?)?
    private(set) var trackingCallbacks: ImageEditorLayerPropertyGestureCallbacks?
    var step = 1.0

    override func mouseDown(with event: NSEvent) {
        trackGesture { super.mouseDown(with: event) }
    }

    func trackGesture(_ track: () -> Void) {
        guard isEnabled, let callbacks = beginGesture?() else { return }
        // The local immutable callbacks also own the release if the view is reconfigured while tracking.
        trackingCallbacks = callbacks
        defer {
            trackingCallbacks = nil
            callbacks.finish()
        }
        track()
    }

    override func keyDown(with event: NSEvent) {
        guard isEnabled else { return }
        let direction: Double
        switch event.keyCode {
        case 123, 125: direction = -1
        case 124, 126: direction = 1
        default:
            super.keyDown(with: event)
            return
        }
        doubleValue = min(maxValue, max(minValue, doubleValue + direction * step))
        applyNativeValue()
    }

    @objc func applyNativeValue() {
        guard isEnabled, doubleValue.isFinite, step.isFinite, step > 0 else { return }
        let value = min(maxValue, max(minValue, minValue + ((doubleValue - minValue) / step).rounded() * step))
        doubleValue = value
        if let trackingCallbacks {
            trackingCallbacks.update(value)
        } else if let callbacks = beginGesture?() {
            // Keyboard and accessibility actions are discrete, independently undoable edits.
            callbacks.update(value)
            callbacks.finish()
        }
    }
}

@MainActor
struct ImageEditorLayerPropertyNativeControl: NSViewRepresentable {
    let value: Double
    let range: ClosedRange<Double>
    let step: Double
    let accessibilityTitle: String
    let beginGesture: () -> ImageEditorLayerPropertyGestureCallbacks?
    @Environment(\.isEnabled) private var isEnabled

    func makeNSView(context: Context) -> ImageEditorLayerPropertyNativeSlider {
        let slider = ImageEditorLayerPropertyNativeSlider()
        slider.controlSize = .small
        slider.isContinuous = true
        slider.target = slider
        slider.action = #selector(ImageEditorLayerPropertyNativeSlider.applyNativeValue)
        configure(slider)
        return slider
    }

    func updateNSView(_ slider: ImageEditorLayerPropertyNativeSlider, context: Context) {
        configure(slider)
    }

    func configure(_ slider: ImageEditorLayerPropertyNativeSlider) {
        slider.minValue = range.lowerBound
        slider.maxValue = range.upperBound
        slider.step = step
        slider.isEnabled = isEnabled
        slider.beginGesture = beginGesture
        slider.setAccessibilityLabel(accessibilityTitle)
        // Do not overwrite the tracking thumb from a body update or an interrupted model preview.
        if slider.trackingCallbacks == nil { slider.doubleValue = value }
    }
}

@MainActor
struct ImageEditorLayerPropertySlider<Label: View, Minimum: View, Maximum: View>: View {
    let value: Double
    let viewModel: ImageEditorViewModel
    let property: ImageEditorLayerGestureProperty
    let range: ClosedRange<Double>
    let step: Double
    let label: Label
    let minimum: Minimum
    let maximum: Maximum

    init(value: Double, viewModel: ImageEditorViewModel, property: ImageEditorLayerGestureProperty,
         in range: ClosedRange<Double>, step: Double,
         @ViewBuilder label: () -> Label,
         @ViewBuilder minimumValueLabel: () -> Minimum,
         @ViewBuilder maximumValueLabel: () -> Maximum) {
        self.value = value
        self.viewModel = viewModel
        self.property = property
        self.range = range
        self.step = step
        self.label = label()
        self.minimum = minimumValueLabel()
        self.maximum = maximumValueLabel()
    }

    var body: some View {
        HStack(spacing: 4) {
            label
            minimum
            ImageEditorLayerPropertyNativeControl(value: value, range: range, step: step,
                                                 accessibilityTitle: accessibilityTitle) {
                viewModel.makeLayerPropertyGestureCallbacks(property)
            }
            .frame(minWidth: 40, maxWidth: .infinity, minHeight: 20, maxHeight: 20)
            maximum
        }
    }

    private var accessibilityTitle: String {
        switch property {
        case .opacity: L10n.text("imageEditor.option.opacity")
        case .fillOpacity: L10n.text("imageEditor.option.fillOpacity")
        case .sourceBlack: L10n.text("imageEditor.option.blendIfBlack")
        case .sourceWhite: L10n.text("imageEditor.option.blendIfWhite")
        case .underlyingBlack: L10n.text("imageEditor.option.blendIfUnderlyingBlack")
        case .underlyingWhite: L10n.text("imageEditor.option.blendIfUnderlyingWhite")
        case .maskDensity: L10n.text("imageEditor.option.maskDensity")
        case .maskFeather: L10n.text("imageEditor.option.maskFeather")
        }
    }
}
