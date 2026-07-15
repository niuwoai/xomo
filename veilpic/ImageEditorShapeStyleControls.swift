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
