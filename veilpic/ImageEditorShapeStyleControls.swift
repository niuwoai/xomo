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
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
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

            if viewModel.selectedShapeFillKind != .solid {
                shapeGradientStopsEditor
                Toggle(
                    L10n.text("imageEditor.gradientFill.dither"),
                    isOn: selectedShapeGradientDitherBinding
                )
                .toggleStyle(.checkbox)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                .focusable(false)
                .accessibilityIdentifier("image-editor-shape-gradient-dither")
                if viewModel.selectedShapeFillKind != .radialGradient {
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
                }
                if viewModel.selectedShapeFillKind != .linearGradient {
                    Stepper(
                        L10n.format(
                            viewModel.selectedShapeFillKind == .radialGradient
                                ? "imageEditor.properties.shapeGradientRadiusValue"
                                : "imageEditor.properties.shapeGradientScaleValue",
                            Int((viewModel.selectedShapeGradientScale * 100).rounded())
                        ),
                        value: selectedShapeGradientScaleBinding,
                        in: 0.25...4,
                        step: 0.05
                    )
                    .focusable(false)
                    .accessibilityIdentifier(
                        viewModel.selectedShapeFillKind == .radialGradient
                            ? "image-editor-shape-gradient-radius"
                            : "image-editor-shape-gradient-scale"
                    )
                }
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
                    viewModel.selectedShapeStrokeWidth
                ),
                value: selectedShapeStrokeWidthBinding,
                in: Double(ImageEditorShapeContent.minimumStrokeWidth)...Double(ImageEditorShapeContent.maximumStrokeWidth),
                step: 0.1
            )
            .focusable(false)
            .accessibilityIdentifier("image-editor-shape-stroke-width")

            HStack(spacing: 8) {
                Text(L10n.text("imageEditor.properties.strokePosition"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                Spacer(minLength: 4)
                Picker("", selection: selectedShapeStrokePositionBinding) {
                    ForEach(ImageEditorStrokePosition.allCases) { position in
                        Text(position.title).tag(position)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .focusable(false)
                .accessibilityIdentifier("image-editor-shape-stroke-position")
            }

            HStack(spacing: 8) {
                Text(L10n.text("imageEditor.properties.shapeStrokeCap"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                Spacer(minLength: 4)
                Picker("", selection: selectedShapeStrokeCapBinding) {
                    ForEach(ImageEditorStrokeCap.allCases, id: \.self) { cap in
                        Text(cap.title).tag(cap)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .focusable(false)
                .accessibilityIdentifier("image-editor-shape-stroke-cap")
            }

            HStack(spacing: 8) {
                Text(L10n.text("imageEditor.properties.shapeStrokeJoin"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                Spacer(minLength: 4)
                Picker("", selection: selectedShapeStrokeJoinBinding) {
                    ForEach(ImageEditorStrokeJoin.allCases, id: \.self) { join in
                        Text(join.title).tag(join)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .focusable(false)
                .accessibilityIdentifier("image-editor-shape-stroke-join")
            }

            if viewModel.selectedShapeStrokeJoin == .miter {
                Stepper(
                    L10n.format(
                        "imageEditor.properties.shapeStrokeMiterLimitValue",
                        viewModel.selectedShapeStrokeMiterLimit
                    ),
                    value: selectedShapeStrokeMiterLimitBinding,
                    in: Double(ImageEditorShapeContent.minimumStrokeMiterLimit)...Double(ImageEditorShapeContent.maximumStrokeMiterLimit),
                    step: 0.5
                )
                .focusable(false)
                .accessibilityIdentifier("image-editor-shape-stroke-miter-limit")
            }

            HStack(spacing: 8) {
                Text(L10n.text("imageEditor.properties.shapeStrokeDash"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                Spacer(minLength: 4)
                Picker("", selection: selectedShapeStrokeDashPresetBinding) {
                    ForEach(ImageEditorStrokeDashPreset.allCases) { preset in
                        Text(preset.title)
                            .tag(preset)
                            .disabled(preset == .custom)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .focusable(false)
                .accessibilityIdentifier("image-editor-shape-stroke-dash")
            }

            if viewModel.selectedShapeStrokeDashPreset != .solid {
                Stepper(
                    L10n.format(
                        "imageEditor.properties.shapeStrokeDashOffsetValue",
                        viewModel.selectedShapeStrokeDashOffset
                    ),
                    value: selectedShapeStrokeDashOffsetBinding,
                    in: Double(ImageEditorShapeContent.minimumStrokeDashOffset)...Double(ImageEditorShapeContent.maximumStrokeDashOffset),
                    step: 1
                )
                .focusable(false)
                .accessibilityIdentifier("image-editor-shape-stroke-dash-offset")
            }
        }
    }

    private var shapeGradientStopsEditor: some View {
        let stops = viewModel.selectedShapeGradientColorStops
        let selectedIndex = normalizedShapeGradientStopIndex(stops: stops)
        let canRemove = stops.count > 2 && selectedIndex > 0 && selectedIndex < stops.count - 1
        return VStack(alignment: .leading, spacing: 6) {
            shapeGradientStopTrack(stops: stops, selectedIndex: selectedIndex)
            .accessibilityIdentifier("image-editor-shape-gradient-stops")

            HStack(spacing: 6) {
                Text(L10n.format("imageEditor.properties.shapeGradientStopCount", stops.count))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                Spacer(minLength: 4)
                Button {
                    if let index = viewModel.addSelectedShapeGradientStop() {
                        selectedShapeGradientStopIndex = index
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .focusable(false)
                .disabled(stops.count >= ImageEditorGradientFillContent.maximumColorStopCount)
                .help(L10n.text("imageEditor.action.shapeGradientStopAdd"))
                .accessibilityIdentifier("image-editor-shape-gradient-stop-add")

                Button {
                    if let index = viewModel.removeSelectedShapeGradientStop(at: selectedIndex) {
                        selectedShapeGradientStopIndex = index
                    }
                } label: {
                    Image(systemName: "minus")
                }
                .buttonStyle(.borderless)
                .focusable(false)
                .disabled(!canRemove)
                .help(L10n.text("imageEditor.action.shapeGradientStopRemove"))
                .accessibilityIdentifier("image-editor-shape-gradient-stop-remove")
            }

            HStack(spacing: 8) {
                Text(L10n.format("imageEditor.properties.shapeGradientStopColor", selectedIndex + 1))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                Spacer(minLength: 4)
                ColorPicker("", selection: selectedShapeGradientStopColorBinding, supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 32)
                    .focusable(false)
                    .accessibilityIdentifier("image-editor-shape-gradient-stop-color")
            }

            Stepper(
                L10n.format(
                    "imageEditor.properties.shapeGradientStopOpacity",
                    Int((stops[selectedIndex].alpha * 100).rounded())
                ),
                value: selectedShapeGradientStopOpacityBinding,
                in: 0...1,
                step: 0.01
            )
            .focusable(false)
            .accessibilityIdentifier("image-editor-shape-gradient-stop-opacity")

            Stepper(
                L10n.format(
                    "imageEditor.properties.shapeGradientStopPosition",
                    Int((stops[selectedIndex].position * 100).rounded())
                ),
                value: selectedShapeGradientStopPositionBinding,
                in: 0...1,
                step: 0.01
            )
            .focusable(false)
            .disabled(selectedIndex == 0 || selectedIndex == stops.count - 1)
            .accessibilityIdentifier("image-editor-shape-gradient-stop-position")

            if selectedIndex < stops.count - 1 {
                Stepper(
                    L10n.format(
                        "imageEditor.properties.shapeGradientStopMidpoint",
                        Int((stops[selectedIndex].midpoint * 100).rounded())
                    ),
                    value: selectedShapeGradientStopMidpointBinding,
                    in: 0...1,
                    step: 0.01
                )
                .focusable(false)
                .accessibilityIdentifier("image-editor-shape-gradient-stop-midpoint")
            }
        }
    }

    private func shapeGradientStopTrack(
        stops: [ImageEditorGradientColorStop],
        selectedIndex: Int
    ) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                ImageEditorTransparencyCheckerboard()
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                    .frame(height: 14)
                    .padding(.horizontal, ImageEditorGradientStopTrackGeometry.horizontalInset)

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
                    .padding(.horizontal, ImageEditorGradientStopTrackGeometry.horizontalInset)

                Rectangle()
                    .fill(Color.white.opacity(0.001))
                    .frame(height: 14)
                    .padding(.horizontal, ImageEditorGradientStopTrackGeometry.horizontalInset)
                    .contentShape(Rectangle())
                    .gesture(
                        SpatialTapGesture(
                            count: 2,
                            coordinateSpace: .named("image-editor-shape-gradient-track-space")
                        )
                        .onEnded { value in
                            let position = ImageEditorGradientStopTrackGeometry.logicalPosition(
                                forX: value.location.x,
                                width: geometry.size.width
                            )
                            if let index = viewModel.addSelectedShapeGradientStop(at: position) {
                                selectedShapeGradientStopIndex = index
                            }
                        }
                    )
                    .allowsHitTesting(
                        stops.count < ImageEditorGradientFillContent.maximumColorStopCount
                    )
                    .help(L10n.text("imageEditor.help.shapeGradientAxis"))
                    .accessibilityIdentifier("image-editor-shape-gradient-track")
                    .accessibilityLabel(L10n.text("imageEditor.action.shapeGradientStopAdd"))

                ForEach(stops.indices.dropLast(), id: \.self) { index in
                    if let midpointPosition = ImageEditorGradientStopTrackGeometry.midpointPosition(
                        after: index,
                        stops: stops
                    ) {
                        Button {
                            selectedShapeGradientStopIndex = index
                        } label: {
                            Rectangle()
                                .fill(
                                    index == selectedIndex
                                        ? Color.accentColor
                                        : Color.white.opacity(0.88)
                                )
                                .overlay {
                                    Rectangle()
                                        .stroke(Color.black.opacity(0.62), lineWidth: 0.75)
                                }
                                .frame(width: 8, height: 8)
                                .rotationEffect(.degrees(45))
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                        .position(
                            x: ImageEditorGradientStopTrackGeometry.xPosition(
                                for: midpointPosition,
                                width: geometry.size.width
                            ),
                            y: 23
                        )
                        .highPriorityGesture(
                            DragGesture(
                                minimumDistance: 1,
                                coordinateSpace: .named(
                                    "image-editor-shape-gradient-track-space"
                                )
                            )
                            .onChanged { value in
                                selectedShapeGradientStopIndex = index
                                if activeShapeGradientTrackMidpointIndex == nil,
                                   viewModel.beginEditingSelectedShapeGradientMidpoint(
                                       after: index
                                   ) {
                                    activeShapeGradientTrackMidpointIndex = index
                                }
                                guard activeShapeGradientTrackMidpointIndex == index,
                                      let midpoint = ImageEditorGradientStopTrackGeometry.midpoint(
                                          forX: value.location.x,
                                          width: geometry.size.width,
                                          after: index,
                                          stops: stops
                                      )
                                else { return }
                                viewModel.updateSelectedShapeGradientMidpoint(
                                    toLogicalMidpoint: midpoint
                                )
                            }
                            .onEnded { value in
                                guard activeShapeGradientTrackMidpointIndex == index else { return }
                                if let midpoint = ImageEditorGradientStopTrackGeometry.midpoint(
                                    forX: value.location.x,
                                    width: geometry.size.width,
                                    after: index,
                                    stops: stops
                                ) {
                                    viewModel.updateSelectedShapeGradientMidpoint(
                                        toLogicalMidpoint: midpoint
                                    )
                                }
                                viewModel.finishEditingSelectedShapeGradient()
                                activeShapeGradientTrackMidpointIndex = nil
                            }
                        )
                        .help(L10n.text("imageEditor.help.shapeGradientMidpointHandle"))
                        .accessibilityIdentifier("image-editor-shape-gradient-track-midpoint-\(index)")
                        .accessibilityLabel(
                            L10n.format(
                                "imageEditor.properties.shapeGradientMidpointAccessibility",
                                index + 1,
                                Int((stops[index].midpoint * 100).rounded())
                            )
                        )
                    }
                }

                ForEach(stops.indices, id: \.self) { index in
                    Button {
                        selectedShapeGradientStopIndex = index
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
                        x: ImageEditorGradientStopTrackGeometry.xPosition(
                            for: stops[index].position,
                            width: geometry.size.width
                        ),
                        y: 36
                    )
                    .highPriorityGesture(
                        DragGesture(
                            minimumDistance: 1,
                            coordinateSpace: .named("image-editor-shape-gradient-track-space")
                        )
                        .onChanged { value in
                            selectedShapeGradientStopIndex = index
                            guard index > 0, index < stops.count - 1 else { return }
                            if activeShapeGradientTrackStopIndex == nil,
                               viewModel.beginEditingSelectedShapeGradientStop(at: index) {
                                activeShapeGradientTrackStopIndex = index
                            }
                            guard activeShapeGradientTrackStopIndex == index else { return }
                            viewModel.updateSelectedShapeGradientStop(toLogicalPosition:
                                ImageEditorGradientStopTrackGeometry.logicalPosition(
                                    forX: value.location.x,
                                    width: geometry.size.width
                                )
                            )
                        }
                        .onEnded { value in
                            guard activeShapeGradientTrackStopIndex == index else { return }
                            viewModel.updateSelectedShapeGradientStop(toLogicalPosition:
                                ImageEditorGradientStopTrackGeometry.logicalPosition(
                                    forX: value.location.x,
                                    width: geometry.size.width
                                )
                            )
                            viewModel.finishEditingSelectedShapeGradient()
                            activeShapeGradientTrackStopIndex = nil
                        }
                    )
                    .help(L10n.text("imageEditor.help.shapeGradientStopHandle"))
                    .accessibilityIdentifier("image-editor-shape-gradient-stop-\(index)")
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
            .coordinateSpace(name: "image-editor-shape-gradient-track-space")
        }
        .frame(height: 46)
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

    private var selectedShapeGradientStopColorBinding: Binding<Color> {
        Binding {
            let stops = viewModel.selectedShapeGradientColorStops
            let index = normalizedShapeGradientStopIndex(stops: stops)
            return Color(nsColor: stops[index].color)
        } set: { color in
            let stops = viewModel.selectedShapeGradientColorStops
            let index = normalizedShapeGradientStopIndex(stops: stops)
            viewModel.setSelectedShapeGradientStopColor(at: index, color: NSColor(color))
        }
    }

    private var selectedShapeGradientStopPositionBinding: Binding<Double> {
        Binding {
            let stops = viewModel.selectedShapeGradientColorStops
            let index = normalizedShapeGradientStopIndex(stops: stops)
            return stops[index].position
        } set: { position in
            let stops = viewModel.selectedShapeGradientColorStops
            let index = normalizedShapeGradientStopIndex(stops: stops)
            viewModel.setSelectedShapeGradientStopPosition(at: index, position: position)
        }
    }

    private var selectedShapeGradientStopOpacityBinding: Binding<Double> {
        Binding {
            let stops = viewModel.selectedShapeGradientColorStops
            let index = normalizedShapeGradientStopIndex(stops: stops)
            return stops[index].alpha
        } set: { opacity in
            let stops = viewModel.selectedShapeGradientColorStops
            let index = normalizedShapeGradientStopIndex(stops: stops)
            viewModel.setSelectedShapeGradientStopOpacity(at: index, opacity: opacity)
        }
    }

    private var selectedShapeGradientStopMidpointBinding: Binding<Double> {
        Binding {
            let stops = viewModel.selectedShapeGradientColorStops
            let index = normalizedShapeGradientStopIndex(stops: stops)
            return stops[index].midpoint
        } set: { midpoint in
            let stops = viewModel.selectedShapeGradientColorStops
            let index = normalizedShapeGradientStopIndex(stops: stops)
            viewModel.setSelectedShapeGradientStopMidpoint(after: index, midpoint: midpoint)
        }
    }

    private func normalizedShapeGradientStopIndex(
        stops: [ImageEditorGradientColorStop]
    ) -> Int {
        max(0, min(selectedShapeGradientStopIndex, stops.count - 1))
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

    private var selectedShapeGradientScaleBinding: Binding<Double> {
        Binding {
            viewModel.selectedShapeGradientScale
        } set: { scale in
            viewModel.setSelectedShapeGradientScale(scale)
        }
    }

    private var selectedShapeGradientDitherBinding: Binding<Bool> {
        Binding {
            viewModel.selectedShapeGradientDither
        } set: { dither in
            viewModel.setSelectedShapeGradientDither(dither)
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

    private var selectedShapeStrokeCapBinding: Binding<ImageEditorStrokeCap> {
        Binding {
            viewModel.selectedShapeStrokeCap
        } set: { cap in
            viewModel.setSelectedShapeStrokeCap(cap)
        }
    }

    private var selectedShapeStrokePositionBinding: Binding<ImageEditorStrokePosition> {
        Binding {
            viewModel.selectedShapeStrokePosition
        } set: { position in
            viewModel.setSelectedShapeStrokePosition(position)
        }
    }

    private var selectedShapeStrokeJoinBinding: Binding<ImageEditorStrokeJoin> {
        Binding {
            viewModel.selectedShapeStrokeJoin
        } set: { join in
            viewModel.setSelectedShapeStrokeJoin(join)
        }
    }

    private var selectedShapeStrokeMiterLimitBinding: Binding<Double> {
        Binding {
            viewModel.selectedShapeStrokeMiterLimit
        } set: { limit in
            viewModel.setSelectedShapeStrokeMiterLimit(limit)
        }
    }

    private var selectedShapeStrokeDashPresetBinding: Binding<ImageEditorStrokeDashPreset> {
        Binding {
            viewModel.selectedShapeStrokeDashPreset
        } set: { preset in
            viewModel.setSelectedShapeStrokeDashPreset(preset)
        }
    }

    private var selectedShapeStrokeDashOffsetBinding: Binding<Double> {
        Binding {
            viewModel.selectedShapeStrokeDashOffset
        } set: { offset in
            viewModel.setSelectedShapeStrokeDashOffset(offset)
        }
    }
}
