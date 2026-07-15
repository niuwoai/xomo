//
//  ImageEditorShapeStyleControls.swift
//  veilpic
//
//  Created by Codex on 2026/7/15.
//

import AppKit
import SwiftUI

extension ImageEditorView {
    var shapeStyleControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.text("imageEditor.properties.shapeStyle"))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))

            HStack(spacing: 2) {
                ForEach(ImageEditorShapeFillKind.allCases) { kind in
                    Button {
                        viewModel.setSelectedShapeFillKind(kind)
                    } label: {
                        Text(kind.title)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(
                                viewModel.selectedShapeFillKind == kind ? 1 : 0.82
                            ))
                            .frame(maxWidth: .infinity, minHeight: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .background(
                        viewModel.selectedShapeFillKind == kind
                            ? Color.accentColor.opacity(0.82)
                            : Color.white.opacity(0.07)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .accessibilityIdentifier("image-editor-shape-fill-kind-\(kind.rawValue)")
                }
            }
            .padding(2)
            .background(Color.black.opacity(0.16))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .accessibilityIdentifier("image-editor-shape-fill-kind")

            if viewModel.selectedShapeFillKind == .linearGradient {
                shapeGradientColorControl(
                    title: L10n.text("imageEditor.properties.shapeGradientStartColor"),
                    selection: selectedShapeGradientStartColorBinding,
                    identifier: "image-editor-shape-gradient-start-color"
                )
                shapeGradientColorControl(
                    title: L10n.text("imageEditor.properties.shapeGradientEndColor"),
                    selection: selectedShapeGradientEndColorBinding,
                    identifier: "image-editor-shape-gradient-end-color"
                )
                Stepper(
                    L10n.format(
                        "imageEditor.properties.shapeGradientAngleValue",
                        Int(viewModel.selectedShapeGradientAngle.rounded())
                    ),
                    value: selectedShapeGradientAngleBinding,
                    in: -180...180,
                    step: 5
                )
                .focusable(false)
                .accessibilityIdentifier("image-editor-shape-gradient-angle")
            } else {
                HStack(spacing: 8) {
                    Text(L10n.text("imageEditor.properties.shapeFillColor"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                    Spacer(minLength: 4)
                    ColorPicker(
                        "",
                        selection: selectedShapeFillColorBinding,
                        supportsOpacity: false
                    )
                    .labelsHidden()
                    .frame(width: 32)
                    .focusable(false)
                    .accessibilityIdentifier("image-editor-shape-fill-color")
                }
            }

            Stepper(
                L10n.format(
                    "imageEditor.properties.shapeFillOpacityValue",
                    Int((viewModel.selectedShapeFillOpacity * 100).rounded())
                ),
                value: selectedShapeFillOpacityBinding,
                in: 0...1,
                step: 0.05
            )
            .focusable(false)
            .accessibilityIdentifier("image-editor-shape-fill-opacity")

            HStack(spacing: 8) {
                Text(L10n.text("imageEditor.properties.shapeStrokeColor"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                Spacer(minLength: 4)
                ColorPicker(
                    "",
                    selection: selectedShapeStrokeColorBinding,
                    supportsOpacity: false
                )
                .labelsHidden()
                .frame(width: 32)
                .focusable(false)
                .accessibilityIdentifier("image-editor-shape-stroke-color")
            }

            Stepper(
                L10n.format(
                    "imageEditor.properties.shapeStrokeOpacityValue",
                    Int((viewModel.selectedShapeStrokeOpacity * 100).rounded())
                ),
                value: selectedShapeStrokeOpacityBinding,
                in: 0...1,
                step: 0.05
            )
            .focusable(false)
            .accessibilityIdentifier("image-editor-shape-stroke-opacity")

            Stepper(
                L10n.format(
                    "imageEditor.properties.shapeStrokeWidthValue",
                    Int(viewModel.selectedShapeStrokeWidth.rounded())
                ),
                value: selectedShapeStrokeWidthBinding,
                in: 1...96,
                step: 1
            )
            .focusable(false)
            .accessibilityIdentifier("image-editor-shape-stroke-width")
        }
    }

    private func shapeGradientColorControl(
        title: String,
        selection: Binding<Color>,
        identifier: String
    ) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
            Spacer(minLength: 4)
            ColorPicker("", selection: selection, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 32)
                .focusable(false)
                .accessibilityIdentifier(identifier)
        }
    }

    private var selectedShapeFillColorBinding: Binding<Color> {
        Binding {
            Color(nsColor: viewModel.selectedShapeFillColor)
        } set: { color in
            viewModel.setSelectedShapeFillColor(NSColor(color))
        }
    }

    private var selectedShapeFillOpacityBinding: Binding<Double> {
        Binding {
            viewModel.selectedShapeFillOpacity
        } set: { opacity in
            viewModel.setSelectedShapeFillOpacity(opacity)
        }
    }

    private var selectedShapeGradientStartColorBinding: Binding<Color> {
        Binding {
            Color(nsColor: viewModel.selectedShapeGradientStartColor)
        } set: { color in
            viewModel.setSelectedShapeGradientStartColor(NSColor(color))
        }
    }

    private var selectedShapeGradientEndColorBinding: Binding<Color> {
        Binding {
            Color(nsColor: viewModel.selectedShapeGradientEndColor)
        } set: { color in
            viewModel.setSelectedShapeGradientEndColor(NSColor(color))
        }
    }

    private var selectedShapeGradientAngleBinding: Binding<Double> {
        Binding {
            viewModel.selectedShapeGradientAngle
        } set: { angle in
            viewModel.setSelectedShapeGradientAngle(angle)
        }
    }

    private var selectedShapeStrokeColorBinding: Binding<Color> {
        Binding {
            Color(nsColor: viewModel.selectedShapeStrokeColor)
        } set: { color in
            viewModel.setSelectedShapeStrokeColor(NSColor(color))
        }
    }

    private var selectedShapeStrokeOpacityBinding: Binding<Double> {
        Binding {
            viewModel.selectedShapeStrokeOpacity
        } set: { opacity in
            viewModel.setSelectedShapeStrokeOpacity(opacity)
        }
    }

    private var selectedShapeStrokeWidthBinding: Binding<Double> {
        Binding {
            viewModel.selectedShapeStrokeWidth
        } set: { width in
            viewModel.setSelectedShapeStrokeWidth(width)
        }
    }
}
