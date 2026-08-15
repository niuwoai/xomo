//
//  ImageEditorGradientFillControls.swift
//  veilpic
//
//  Created by Codex on 2026/8/15.
//

import AppKit
import SwiftUI

struct ImageEditorGradientFillStopsEditor: View {
    @ObservedObject var viewModel: ImageEditorViewModel
    @State private var selectedStopIndex = 0

    var body: some View {
        let stops = viewModel.gradientFillColorStops
        let selectedIndex = normalizedSelectedIndex(stops: stops)
        let canRemove = stops.count > 2
            && selectedIndex > 0
            && selectedIndex < stops.count - 1

        VStack(alignment: .leading, spacing: 6) {
            stopTrack(stops: stops, selectedIndex: selectedIndex)

            HStack(spacing: 6) {
                Text(L10n.format("imageEditor.properties.shapeGradientStopCount", stops.count))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                Spacer(minLength: 4)
                Button {
                    if let index = viewModel.addGradientFillColorStop() {
                        selectedStopIndex = index
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .focusable(false)
                .disabled(stops.count >= ImageEditorGradientFillContent.maximumColorStopCount)
                .help(L10n.text("imageEditor.action.shapeGradientStopAdd"))
                .accessibilityIdentifier("image-editor-gradient-fill-stop-add")

                Button {
                    if let index = viewModel.removeGradientFillColorStop(at: selectedIndex) {
                        selectedStopIndex = index
                    }
                } label: {
                    Image(systemName: "minus")
                }
                .buttonStyle(.borderless)
                .focusable(false)
                .disabled(!canRemove)
                .help(L10n.text("imageEditor.action.shapeGradientStopRemove"))
                .accessibilityIdentifier("image-editor-gradient-fill-stop-remove")
            }

            HStack(spacing: 8) {
                Text(L10n.format("imageEditor.properties.shapeGradientStopColor", selectedIndex + 1))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                Spacer(minLength: 4)
                ColorPicker("", selection: selectedColorBinding, supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 32)
                    .focusable(false)
                    .accessibilityIdentifier("image-editor-gradient-fill-stop-color")
            }

            Stepper(
                L10n.format(
                    "imageEditor.properties.shapeGradientStopOpacity",
                    Int((stops[selectedIndex].alpha * 100).rounded())
                ),
                value: selectedOpacityBinding,
                in: 0...1,
                step: 0.01
            )
            .focusable(false)
            .accessibilityIdentifier("image-editor-gradient-fill-stop-opacity")

            Stepper(
                L10n.format(
                    "imageEditor.properties.shapeGradientStopPosition",
                    Int((stops[selectedIndex].position * 100).rounded())
                ),
                value: selectedPositionBinding,
                in: 0...1,
                step: 0.01
            )
            .focusable(false)
            .disabled(selectedIndex == 0 || selectedIndex == stops.count - 1)
            .accessibilityIdentifier("image-editor-gradient-fill-stop-position")

            if selectedIndex < stops.count - 1 {
                Stepper(
                    L10n.format(
                        "imageEditor.properties.shapeGradientStopMidpoint",
                        Int((stops[selectedIndex].midpoint * 100).rounded())
                    ),
                    value: selectedMidpointBinding,
                    in: 0...1,
                    step: 0.01
                )
                .focusable(false)
                .accessibilityIdentifier("image-editor-gradient-fill-stop-midpoint")
            }
        }
        .accessibilityIdentifier("image-editor-gradient-fill-stops")
    }

    private func stopTrack(
        stops: [ImageEditorGradientColorStop],
        selectedIndex: Int
    ) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                ImageEditorTransparencyCheckerboard()
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                    .frame(height: 14)

                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(stops: stops.map { stop in
                                Gradient.Stop(
                                    color: Color(nsColor: stop.color),
                                    location: CGFloat(stop.position)
                                )
                            }),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .stroke(Color.white.opacity(0.45), lineWidth: 1)
                    }
                    .frame(height: 14)

                ForEach(stops.indices, id: \.self) { index in
                    Button {
                        selectedStopIndex = index
                    } label: {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(Color(nsColor: stops[index].color))
                            .overlay {
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .stroke(
                                        index == selectedIndex
                                            ? Color.accentColor
                                            : Color.white.opacity(0.86),
                                        lineWidth: index == selectedIndex ? 2 : 1
                                    )
                            }
                            .frame(width: 12, height: 16)
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .position(
                        x: max(
                            6,
                            min(
                                geometry.size.width - 6,
                                CGFloat(stops[index].position) * geometry.size.width
                            )
                        ),
                        y: 26
                    )
                    .accessibilityIdentifier("image-editor-gradient-fill-stop-\(index)")
                    .accessibilityLabel(
                        L10n.format(
                            "imageEditor.properties.shapeGradientStopAccessibility",
                            index + 1,
                            Int((stops[index].position * 100).rounded()),
                            Int((stops[index].alpha * 100).rounded())
                        )
                    )
                }
            }
        }
        .frame(height: 36)
    }

    private var selectedColorBinding: Binding<Color> {
        Binding {
            let stops = viewModel.gradientFillColorStops
            return Color(nsColor: stops[normalizedSelectedIndex(stops: stops)].color)
        } set: { color in
            let stops = viewModel.gradientFillColorStops
            viewModel.setGradientFillColorStopColor(
                at: normalizedSelectedIndex(stops: stops),
                color: NSColor(color)
            )
        }
    }

    private var selectedOpacityBinding: Binding<Double> {
        Binding {
            let stops = viewModel.gradientFillColorStops
            return stops[normalizedSelectedIndex(stops: stops)].alpha
        } set: { opacity in
            let stops = viewModel.gradientFillColorStops
            viewModel.setGradientFillColorStopOpacity(
                at: normalizedSelectedIndex(stops: stops),
                opacity: opacity
            )
        }
    }

    private var selectedPositionBinding: Binding<Double> {
        Binding {
            let stops = viewModel.gradientFillColorStops
            return stops[normalizedSelectedIndex(stops: stops)].position
        } set: { position in
            let stops = viewModel.gradientFillColorStops
            viewModel.setGradientFillColorStopPosition(
                at: normalizedSelectedIndex(stops: stops),
                position: position
            )
        }
    }

    private var selectedMidpointBinding: Binding<Double> {
        Binding {
            let stops = viewModel.gradientFillColorStops
            return stops[normalizedSelectedIndex(stops: stops)].midpoint
        } set: { midpoint in
            let stops = viewModel.gradientFillColorStops
            viewModel.setGradientFillColorStopMidpoint(
                after: normalizedSelectedIndex(stops: stops),
                midpoint: midpoint
            )
        }
    }

    private func normalizedSelectedIndex(
        stops: [ImageEditorGradientColorStop]
    ) -> Int {
        max(0, min(selectedStopIndex, stops.count - 1))
    }
}

struct ImageEditorTransparencyCheckerboard: View {
    var square: CGFloat = 4

    var body: some View {
        Canvas { context, size in
            let light = Color(nsColor: NSColor(calibratedWhite: 0.72, alpha: 1))
            let dark = Color(nsColor: NSColor(calibratedWhite: 0.46, alpha: 1))
            var row = 0
            var y: CGFloat = 0
            while y < size.height {
                var column = 0
                var x: CGFloat = 0
                while x < size.width {
                    let rect = CGRect(x: x, y: y, width: square, height: square)
                    let color = (row + column).isMultiple(of: 2) ? light : dark
                    context.fill(Path(rect), with: .color(color))
                    column += 1
                    x += square
                }
                row += 1
                y += square
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
