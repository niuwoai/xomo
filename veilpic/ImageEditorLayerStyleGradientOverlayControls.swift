//
//  ImageEditorLayerStyleGradientOverlayControls.swift
//  veilpic
//
//  Created by Codex on 2026/8/16.
//

import AppKit
import SwiftUI

struct ImageEditorLayerStyleGradientOverlayStopsEditor: View {
    private static let trackCoordinateSpace =
        "image-editor-layer-style-gradient-overlay-track-space"

    @ObservedObject var viewModel: ImageEditorViewModel
    @State private var draftStops = ImageEditorGradientFillContent.shapeLinear(
        startColor: .black,
        endColor: .white
    ).shapeColorStops
    @State private var selectedStopIndex = 0

    var body: some View {
        let stops = normalizedDraftStops
        let selectedIndex = normalizedSelectedIndex(stops: stops)
        let canRemove = stops.count > 2
            && selectedIndex > 0
            && selectedIndex < stops.count - 1
        let hasChanges = stops != sourceStops

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(L10n.text("imageEditor.properties.gradientOverlayStops"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                if viewModel.selectedLayerGradientOverlayColorStopsState == .mixed {
                    Text(L10n.text("imageEditor.properties.multipleValues"))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                }
                Spacer(minLength: 4)
                Text(L10n.format("imageEditor.properties.shapeGradientStopCount", stops.count))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
            }

            stopTrack(stops: stops, selectedIndex: selectedIndex)

            HStack(spacing: 6) {
                Button {
                    addStop()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .focusable(false)
                .disabled(stops.count >= ImageEditorGradientFillContent.maximumColorStopCount)
                .help(L10n.text("imageEditor.action.shapeGradientStopAdd"))
                .accessibilityIdentifier(
                    "image-editor-layer-style-gradient-overlay-stop-add"
                )

                Button {
                    removeStop(at: selectedIndex)
                } label: {
                    Image(systemName: "minus")
                }
                .buttonStyle(.borderless)
                .focusable(false)
                .disabled(!canRemove)
                .help(L10n.text("imageEditor.action.shapeGradientStopRemove"))
                .accessibilityIdentifier(
                    "image-editor-layer-style-gradient-overlay-stop-remove"
                )

                Spacer(minLength: 4)
                Text(L10n.format(
                    "imageEditor.properties.shapeGradientStopColor",
                    selectedIndex + 1
                ))
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                ColorPicker("", selection: selectedColorBinding, supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 32)
                    .focusable(false)
                    .accessibilityIdentifier(
                        "image-editor-layer-style-gradient-overlay-stop-color"
                    )
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
            .accessibilityIdentifier(
                "image-editor-layer-style-gradient-overlay-stop-opacity"
            )

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
            .accessibilityIdentifier(
                "image-editor-layer-style-gradient-overlay-stop-position"
            )

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
                .accessibilityIdentifier(
                    "image-editor-layer-style-gradient-overlay-stop-midpoint"
                )
            }

            HStack(spacing: 6) {
                Button(L10n.text("imageEditor.action.gradientOverlayStopsApply")) {
                    _ = viewModel.setSelectedLayerGradientOverlayColorStops(stops)
                }
                .buttonStyle(EditorTextButtonStyle())
                .focusable(false)
                .disabled(!hasChanges || !viewModel.canEditSelectedLayerStyle)
                .accessibilityIdentifier(
                    "image-editor-layer-style-gradient-overlay-stops-apply"
                )

                Button(L10n.text("imageEditor.action.cancel")) {
                    reloadDraft(from: sourceStops)
                }
                .buttonStyle(EditorTextButtonStyle())
                .focusable(false)
                .disabled(!hasChanges)
                .accessibilityIdentifier(
                    "image-editor-layer-style-gradient-overlay-stops-cancel"
                )
            }
        }
        .accessibilityIdentifier("image-editor-layer-style-gradient-overlay-stops")
        .onAppear {
            reloadDraft(from: sourceStops)
        }
        .onChange(of: sourceStops) { stops in
            reloadDraft(from: stops)
        }
        .onChange(of: viewModel.document.selectedLayerIDs) { _ in
            reloadDraft(from: sourceStops)
        }
    }

    private var sourceStops: [ImageEditorGradientColorStop] {
        viewModel.selectedLayerGradientOverlayColorStops
    }

    private var normalizedDraftStops: [ImageEditorGradientColorStop] {
        ImageEditorGradientFillContent.shapeLinear(
            colorStops: draftStops
        ).shapeColorStops
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
                            coordinateSpace: .named(Self.trackCoordinateSpace)
                        )
                        .onEnded { value in
                            addStop(at: ImageEditorGradientStopTrackGeometry.logicalPosition(
                                forX: value.location.x,
                                width: geometry.size.width
                            ))
                        }
                    )
                    .allowsHitTesting(
                        stops.count < ImageEditorGradientFillContent.maximumColorStopCount
                    )
                    .help(L10n.text("imageEditor.help.shapeGradientAxis"))
                    .accessibilityIdentifier(
                        "image-editor-layer-style-gradient-overlay-track"
                    )

                ForEach(stops.indices.dropLast(), id: \.self) { index in
                    if let midpointPosition = ImageEditorGradientStopTrackGeometry.midpointPosition(
                        after: index,
                        stops: stops
                    ) {
                        Button {
                            selectedStopIndex = index
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
                                coordinateSpace: .named(Self.trackCoordinateSpace)
                            )
                            .onChanged { value in
                                selectedStopIndex = index
                                let currentStops = normalizedDraftStops
                                guard let midpoint = ImageEditorGradientStopTrackGeometry.midpoint(
                                    forX: value.location.x,
                                    width: geometry.size.width,
                                    after: index,
                                    stops: currentStops
                                ) else { return }
                                draftStops = ImageEditorGradientOverlayStopDraftEditing
                                    .movingMidpoint(
                                        currentStops,
                                        after: index,
                                        to: midpoint
                                    )
                            }
                        )
                        .help(L10n.text("imageEditor.help.shapeGradientMidpointHandle"))
                        .accessibilityIdentifier(
                            "image-editor-layer-style-gradient-overlay-midpoint-\(index)"
                        )
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
                        x: ImageEditorGradientStopTrackGeometry.xPosition(
                            for: stops[index].position,
                            width: geometry.size.width
                        ),
                        y: 30
                    )
                    .highPriorityGesture(
                        DragGesture(
                            minimumDistance: 1,
                            coordinateSpace: .named(Self.trackCoordinateSpace)
                        )
                        .onChanged { value in
                            selectedStopIndex = index
                            draftStops = ImageEditorGradientOverlayStopDraftEditing.movingStop(
                                normalizedDraftStops,
                                at: index,
                                to: ImageEditorGradientStopTrackGeometry.logicalPosition(
                                    forX: value.location.x,
                                    width: geometry.size.width
                                )
                            )
                        }
                    )
                    .help(L10n.text("imageEditor.help.shapeGradientStopHandle"))
                    .accessibilityIdentifier(
                        "image-editor-layer-style-gradient-overlay-stop-\(index)"
                    )
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
            .coordinateSpace(name: Self.trackCoordinateSpace)
        }
        .frame(height: 46)
    }

    private var selectedColorBinding: Binding<Color> {
        Binding {
            let stops = normalizedDraftStops
            return Color(nsColor: stops[normalizedSelectedIndex(stops: stops)].color)
        } set: { color in
            var stops = normalizedDraftStops
            let index = normalizedSelectedIndex(stops: stops)
            let resolved = NSColor(color).usingColorSpace(.deviceRGB) ?? .black
            stops[index].red = Double(resolved.redComponent)
            stops[index].green = Double(resolved.greenComponent)
            stops[index].blue = Double(resolved.blueComponent)
            draftStops = normalized(stops)
        }
    }

    private var selectedOpacityBinding: Binding<Double> {
        Binding {
            let stops = normalizedDraftStops
            return stops[normalizedSelectedIndex(stops: stops)].alpha
        } set: { opacity in
            guard opacity.isFinite else { return }
            var stops = normalizedDraftStops
            stops[normalizedSelectedIndex(stops: stops)].alpha = max(0, min(1, opacity))
            draftStops = normalized(stops)
        }
    }

    private var selectedPositionBinding: Binding<Double> {
        Binding {
            let stops = normalizedDraftStops
            return stops[normalizedSelectedIndex(stops: stops)].position
        } set: { position in
            guard position.isFinite else { return }
            let stops = normalizedDraftStops
            let index = normalizedSelectedIndex(stops: stops)
            guard index > 0, index < stops.count - 1 else { return }
            draftStops = ImageEditorGradientOverlayStopDraftEditing.movingStop(
                stops,
                at: index,
                to: position
            )
        }
    }

    private var selectedMidpointBinding: Binding<Double> {
        Binding {
            let stops = normalizedDraftStops
            return stops[normalizedSelectedIndex(stops: stops)].midpoint
        } set: { midpoint in
            guard midpoint.isFinite else { return }
            let stops = normalizedDraftStops
            let index = normalizedSelectedIndex(stops: stops)
            guard index < stops.count - 1 else { return }
            draftStops = ImageEditorGradientOverlayStopDraftEditing.movingMidpoint(
                stops,
                after: index,
                to: midpoint
            )
        }
    }

    private func addStop() {
        let stops = normalizedDraftStops
        guard let gap = stops.indices.dropLast().max(by: { lhs, rhs in
            (stops[lhs + 1].position - stops[lhs].position)
                < (stops[rhs + 1].position - stops[rhs].position)
        }) else { return }
        addStop(at: (stops[gap].position + stops[gap + 1].position) / 2)
    }

    private func addStop(at position: Double) {
        guard position.isFinite else { return }
        var stops = normalizedDraftStops
        guard stops.count < ImageEditorGradientFillContent.maximumColorStopCount else {
            return
        }
        let requestedPosition = max(0, min(1, position))
        let insertionIndex = stops.firstIndex {
            requestedPosition < $0.position
        } ?? stops.count
        guard insertionIndex > 0, insertionIndex < stops.count else { return }
        let lowerBound = stops[insertionIndex - 1].position
            + ImageEditorGradientOverlayStopDraftEditing.minimumStopSpacing
        let upperBound = stops[insertionIndex].position
            - ImageEditorGradientOverlayStopDraftEditing.minimumStopSpacing
        guard lowerBound <= upperBound else { return }
        let resolvedPosition = max(lowerBound, min(upperBound, requestedPosition))
        let color = ImageEditorGradientFillContent.shapeLinear(
            colorStops: stops
        ).shapeColor(at: resolvedPosition)
        stops.insert(
            ImageEditorGradientColorStop(position: resolvedPosition, color: color),
            at: insertionIndex
        )
        draftStops = normalized(stops)
        selectedStopIndex = insertionIndex
    }

    private func removeStop(at index: Int) {
        var stops = normalizedDraftStops
        guard stops.count > 2, index > 0, index < stops.count - 1 else { return }
        stops.remove(at: index)
        draftStops = normalized(stops)
        selectedStopIndex = min(index, stops.count - 1)
    }

    private func normalized(
        _ stops: [ImageEditorGradientColorStop]
    ) -> [ImageEditorGradientColorStop] {
        ImageEditorGradientFillContent.shapeLinear(
            colorStops: stops
        ).shapeColorStops
    }

    private func normalizedSelectedIndex(
        stops: [ImageEditorGradientColorStop]
    ) -> Int {
        max(0, min(selectedStopIndex, stops.count - 1))
    }

    private func reloadDraft(from stops: [ImageEditorGradientColorStop]) {
        draftStops = normalized(stops)
        selectedStopIndex = min(selectedStopIndex, draftStops.count - 1)
    }
}
