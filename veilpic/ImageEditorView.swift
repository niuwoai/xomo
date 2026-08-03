//
//  ImageEditorView.swift
//  veilpic
//
//  Created by Codex on 2026/7/8.
//

import AppKit
import SwiftUI

private let imageEditorRightDockWidth: CGFloat = 384
private let imageEditorCanvasToolbarHeight: CGFloat = 42
private let imageEditorToolRailWidth: CGFloat = 84
private let imageEditorToolButtonHitSize: CGFloat = 36
private let imageEditorToolGridColumnCount = 2
private let imageEditorToolGridSpacing: CGFloat = 2
private let imageEditorComponentLibraryWidth: CGFloat = 220

enum ImageEditorOptionsBarAppearance {
    static let foregroundColor = NSColor.white
}

/// Provides the low-cost dash movement used by Photoshop-style active
/// selections. Keeping the phase calculation pure makes the visual feedback
/// deterministic in tests without coupling selection data to animation state.
enum ImageEditorSelectionMarchingAnts {
    static let patternLength: CGFloat = 9
    private static let period: TimeInterval = 0.72

    static func dashPhase(at elapsed: TimeInterval) -> CGFloat {
        guard elapsed.isFinite else { return 0 }
        let remainder = elapsed.truncatingRemainder(dividingBy: period)
        let normalized = remainder >= 0 ? remainder : remainder + period
        return CGFloat(normalized / period) * patternLength
    }
}

enum ImageEditorCanvasDragGeometry {
    static func imageDelta(
        from viewDelta: CGSize,
        canvasSize: CGSize,
        imageRect: CGRect
    ) -> CGSize {
        guard imageRect.width > 0, imageRect.height > 0 else { return .zero }
        return CGSize(
            width: viewDelta.width * canvasSize.width / imageRect.width,
            height: viewDelta.height * canvasSize.height / imageRect.height
        )
    }
}

private enum ImageEditorDeliveryObjectReference: Equatable {
    case slice(UUID)
    case hotspot(UUID)
}

private struct ImageEditorDeliveryDrag: Equatable {
    let reference: ImageEditorDeliveryObjectReference
    let originalFrame: CGRect
    var previewFrame: CGRect
}

private struct ImageEditorColorSamplerDrag: Equatable {
    let id: UUID
    var previewPoint: CGPoint
}

struct ImageEditorView: View {
    @StateObject var viewModel: ImageEditorViewModel
    @State private var dragPoints: [CGPoint] = []
    @State private var brushStrokeSamples: [ImageEditorBrushStrokeSample] = []
    @State private var toneAirbrushStroke = ImageEditorToneAirbrushStroke()
    @State private var dragStart: CGPoint?
    @State private var dragEnd: CGPoint?
    @State private var primaryToolViewStart: CGPoint?
    @State private var patchPreviewImage: NSImage?
    @State private var isDrawingPatchSelection = false
    @State private var lastPatchPreviewUpdateTime: TimeInterval = 0
    @State private var pendingCropRect: CGRect?
    @State private var activeCropHandle: ImageEditorCropHandle?
    @State private var cropInteractionStartPoint: CGPoint?
    @State private var cropInteractionOriginalRect: CGRect?
    @State private var lastPanTranslation: CGSize = .zero
    @State private var isSpacebarPanning = false
    @State private var isCanvasPanGestureActive = false
    @State private var lastMoveTranslation: CGSize = .zero
    @State private var objectMoveAxisLock: ImageEditorObjectDragAxis?
    @State private var isObjectMoveGestureActive = false
    @State private var isCanvasSelectionGestureActive = false
    @State private var isCanvasCloneGestureActive = false
    @State private var isSelectedObjectMoveGestureActive = false
    @State private var isDeliveryObjectMoveGestureActive = false
    @State private var deliveryDrag: ImageEditorDeliveryDrag?
    @State private var colorSamplerDrag: ImageEditorColorSamplerDrag?
    @State private var pendingColorSamplerRemovalID: UUID?
    @State private var isColorSamplerRemovalGestureActive = false
    @State private var activeResizeHandle: ImageEditorLayerResizeHandle?
    @State private var activeShapeGradientHandle: ImageEditorShapeGradientHandle?
    @State private var activeShapeRadialGradientHandle: ImageEditorShapeRadialGradientHandle?
    @State private var activeShapeGradientStopIndex: Int?
    @State var selectedShapeGradientStopIndex = 0
    @State private var isRotatingLayer = false
    @State private var isMovingTransformReferencePoint = false
    @State private var isTransformReferencePointDragCancelled = false
    @State private var isMovingPathAnchor = false
    @State private var activeGuideDrag: ImageEditorGuideDrag?
    @State private var layerNameDraft = ""
    @State private var figmaComponentPropertyDrafts: [String: String] = [:]
    @State var layerSearchQuery = ""
    @State var selectedLayerKindFilter: ImageEditorLayerKindFilter = .all
    @State var selectedLayerLabelFilter: ImageEditorLayerLabelColor?
    @State var selectedLayerStateFilter: ImageEditorLayerStateFilter = .all
    @State var selectedLayerAttributeFilter: ImageEditorLayerAttributeFilter = .all
    @State var alphaChannelNameDrafts: [UUID: String] = [:]
    @State var layerCompNameDrafts: [UUID: String] = [:]
    @State var savedPathNameDrafts: [UUID: String] = [:]
    @State var historySnapshotNameDrafts: [UUID: String] = [:]
    @State var selectedLayerPanelTab: ImageEditorLayerPanelTab = .layers
    @State var targetedLayerDropTarget: ImageEditorLayerDropTarget?
    @State var targetedSavedPathDropTarget: ImageEditorSavedPathDropTarget?
    @State var isLayerAdvancedControlsExpanded = false
    @State private var isLayersDockExpanded = true
    @State private var isNavigatorDockExpanded = false
    @State private var isHistoryDockExpanded = false
    @State private var isFiltersDockExpanded = false
    @State private var isPropertiesDockExpanded = false
    @State private var isHotspotsDockExpanded = true
    @State private var isSlicesDockExpanded = true
    @State private var isRightDockMounted = false
    @State private var isPointerInsideCanvas = false
    @State private var hoverViewPoint: CGPoint?
    @State private var canvasModifierFlags: NSEvent.ModifierFlags = []
    @State private var activeBrushPressure: CGFloat?
    @State private var activeBrushTilt: ImageEditorStylusTilt?
    @State private var stylusProximity: ImageEditorStylusProximity = .none
    @State private var histogramProbeBinIndex: Int?
    @State private var histogramRangeAnchorBinIndex: Int?
    @State private var histogramRangeEndBinIndex: Int?
    @State private var isHistogramRangeDragging = false
    @State private var isMarqueeShapeMenuPresented = false
    @State private var hoveredTool: ImageEditorTool?
    @State private var isQuickMaskOptionsPresented = false
    @State var isFigmaLinkImportPresented = false
    @State private var canvasTextEditingOrigin: CGPoint?
    @State private var canvasTextEditingLayerID: UUID?
    @State private var canvasTextEditingFrame: CGRect?
    @FocusState private var isCanvasTextEditorFocused: Bool
    @State private var isTransformAspectRatioLocked = false

    init(sourceName: String, image: NSImage, onApply: @escaping (NSImage) -> Void) {
        _viewModel = StateObject(wrappedValue: ImageEditorViewModel(sourceName: sourceName, image: image, onApply: onApply))
    }

    init(viewModel: ImageEditorViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            menuBar
            if viewModel.isOptionsBarVisible {
                optionBar
                Divider().overlay(editorBorder)
            }

            HStack(spacing: 0) {
                if viewModel.areToolsPanelVisible {
                    leftSidebar
                        .fixedSize(horizontal: true, vertical: false)
                        .layoutPriority(2)
                    Divider().overlay(editorBorder)
                }
                canvasWorkspace
                    .frame(minWidth: 0)
                    .clipped()
                    .layoutPriority(0)
                if viewModel.isRightDockVisible && isRightDockMounted {
                    Divider().overlay(editorBorder)
                    rightDock
                        .fixedSize(horizontal: true, vertical: false)
                        .layoutPriority(2)
                }
            }
            .overlay(alignment: .topLeading) {
                if isMarqueeShapeMenuPresented,
                   viewModel.areToolsPanelVisible,
                   viewModel.selectedLeftSidebarTab == .tools {
                    marqueeShapeFloatingMenu
                        .offset(x: imageEditorToolRailWidth + 4, y: 50)
                        .zIndex(1_000)
                }
            }

            if viewModel.isStatusBarVisible {
                statusBar
            }
        }
        .frame(minWidth: 1160, minHeight: 720)
        .accessibilityHidden(ImageEditorComputerUseQA.usesScreenshotOnlyAccessibilityTree)
        .background(Color(nsColor: ImageEditorTheme.window))
        .background(toolShortcutButtons)
        .background(brushShortcutButtons)
        .background(opacityShortcutButtons)
        .background(colorShortcutButtons)
        .background(alternateZoomShortcutButtons)
        .background(nudgeShortcutButtons)
        .background(
            ImageEditorKeyboardShortcutMonitor(
                perform: performKeyboardShortcut,
                activeTool: viewModel.canvasInteractionTool,
                nudgeSelected: { delta in
                    if !viewModel.nudgeSelectedDeliveryObject(by: delta) {
                        viewModel.nudgeSelectionOrSelectedLayer(by: delta)
                    }
                },
                deleteSelectedObject: {
                    if deleteSelectedShapeGradientStopIfNeeded() {
                        return true
                    }
                    if viewModel.selectedTool == .pen || viewModel.selectedTool == .directSelection,
                       viewModel.canDeleteSelectedPathAnchor {
                        viewModel.deleteSelectedPathAnchor()
                        return true
                    }
                    if viewModel.deleteSelectedDeliveryObjectIfNeeded() {
                        return true
                    }
                    return viewModel.deleteSelectedXomoObjectIfNeeded()
                },
                cancelSelectedObject: {
                    if isMovingTransformReferencePoint {
                        isTransformReferencePointDragCancelled = true
                        _ = viewModel.cancelSelectedLayerTransformReferencePointDrag()
                        NSCursor.crosshair.set()
                        return true
                    }
                    if viewModel.cancelTransformingSelectedLayer() {
                        // Keep the local active handle until mouse-up so any
                        // remaining drag events cannot begin a new transform
                        // after Escape restored the original document.
                        if let activeResizeHandle {
                            ImageEditorCanvasCursor.transformCursor(for: .resize(activeResizeHandle)).set()
                        } else if isRotatingLayer {
                            ImageEditorCanvasCursor.transformCursor(for: .rotate).set()
                        } else {
                            NSCursor.arrow.set()
                        }
                        return true
                    }
                    if viewModel.cancelMovingSelectedLayer() {
                        isSelectedObjectMoveGestureActive = false
                        isObjectMoveGestureActive = false
                        resetObjectMoveTracking()
                        NSCursor.arrow.set()
                        return true
                    }
                    return viewModel.clearSelectedXomoObjectIfNeeded()
                },
                discardPendingSmartFilterChanges: {
                    viewModel.discardLoadedSmartFilterControlChanges()
                },
                deleteSelectedHistory: {
                    guard viewModel.isHistoryPanelVisible,
                          isHistoryDockExpanded,
                          viewModel.canTruncateSelectedHistory
                    else { return false }
                    viewModel.truncateSelectedHistory()
                    return true
                },
                setSpacebarPanning: { isPressed in
                    isSpacebarPanning = isPressed
                },
                setCanvasModifierFlags: { flags in
                    // Photoshop uses Caps Lock as a precision toggle for
                    // brush-like tools. Keep it in the cursor-only state;
                    // selection and zoom modifiers retain their current rules.
                    canvasModifierFlags = flags.intersection([.shift, .option, .capsLock])
                }
            )
            .allowsHitTesting(false)
        )
        .overlay(alignment: .bottom) {
            workspaceInputModeHint
                .padding(.bottom, viewModel.isStatusBarVisible ? 4 : 8)
        }
        .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
        .onAppear {
            syncLayerNameDraft()
            syncFigmaComponentPropertyDrafts()
            viewModel.syncSizeControlsFromDocument()
            guard !isRightDockMounted else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                isRightDockMounted = true
            }
        }
        .onChange(of: viewModel.document.selectedLayerIDs) { _ in
            syncLayerNameDraft()
            syncFigmaComponentPropertyDrafts()
            viewModel.finishSelectedLayerTransformReferencePointDrag()
            viewModel.clearSelectedLayerTransformReferencePoint()
            isMovingTransformReferencePoint = false
            isTransformReferencePointDragCancelled = false
        }
        .onChange(of: viewModel.selectedLayerFigmaComponentProperties) { _ in
            syncFigmaComponentPropertyDrafts()
        }
        .onChange(of: viewModel.selectedLayerName) { _ in
            syncLayerNameDraft()
        }
        .onChange(of: viewModel.filterPanelPresentationRequest) { _ in
            isFiltersDockExpanded = true
        }
        .onChange(of: viewModel.selectedTool) { _ in
            if viewModel.selectedTool != .marquee {
                isMarqueeShapeMenuPresented = false
            }
            patchPreviewImage = nil
            isDrawingPatchSelection = false
            lastPatchPreviewUpdateTime = 0
            dragStart = nil
            dragEnd = nil
            primaryToolViewStart = nil
            dragPoints = []
            brushStrokeSamples = []
            activeBrushPressure = nil
            activeBrushTilt = nil
            toneAirbrushStroke.reset()
            if viewModel.selectedTool != .crop {
                pendingCropRect = nil
                endPendingCropInteraction()
            }
        }
        .sheet(isPresented: $viewModel.isExportSheetPresented) {
            ImageEditorExportPanel(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.isColorRangeSheetPresented) {
            ImageEditorColorRangePanel(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.isNewCanvasSheetPresented) {
            XomoNewCanvasSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.isLayerStylePresetManagerPresented) {
            ImageEditorLayerStylePresetManager(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.isPSDCompatibilityReportPresented) {
            if let report = viewModel.psdCompatibilityReport {
                ImageEditorPSDCompatibilityReportView(
                    report: report,
                    fileName: viewModel.psdCompatibilityFileName
                )
            }
        }
        .sheet(isPresented: $isFigmaLinkImportPresented) {
            XomoFigmaLinkImportSheet(viewModel: viewModel)
        }
    }

    @ViewBuilder
    private var optionBar: some View {
        switch viewModel.workspaceInputMode {
        case .tool:
            toolOptionBar
        case .componentLibrary(let selectedComponent):
            componentLibraryOptionBar(selectedComponent: selectedComponent)
        }
    }

    private var toolOptionBar: some View {
        HStack(spacing: 12) {
            Label {
                Text(viewModel.selectedTool.title)
            } icon: {
                selectedToolIcon
            }
                .font(.system(size: 12, weight: .semibold))
                .frame(
                    width: usesPressureInputIndicator ? 72 : 132,
                    alignment: .leading
                )
                .accessibilityIdentifier("image-editor-selected-tool")
                .accessibilityValue(viewModel.selectedTool.rawValue)

            if viewModel.selectedTool.supportsSelectionMode {
                selectionModePicker
            }

            if viewModel.selectedTool == .marquee {
                marqueeShapePicker
            }

            if viewModel.selectedTool == .patchTool {
                patchModePicker
            }

            if viewModel.selectedTool == .sponge {
                Picker(
                    L10n.text("imageEditor.option.spongeMode"),
                    selection: $viewModel.spongeMode
                ) {
                    ForEach(ImageEditorSpongeMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .focusable(false)
                .frame(width: 132)
                .help(ImageEditorSpongeModeShortcut.helpText)
                .accessibilityHint(ImageEditorSpongeModeShortcut.helpText)
                .accessibilityIdentifier("image-editor-sponge-mode")

                Toggle(
                    L10n.text("imageEditor.option.spongeVibrance"),
                    isOn: $viewModel.spongeVibranceEnabled
                )
                .toggleStyle(.checkbox)
                .focusable(false)
                .fixedSize()
                .help(L10n.text("imageEditor.option.spongeVibrance.help"))
                .accessibilityHint(L10n.text("imageEditor.option.spongeVibrance.help"))
                .accessibilityIdentifier("image-editor-sponge-vibrance")

                Toggle(
                    L10n.text("imageEditor.option.pressureSize"),
                    isOn: Binding(
                        get: { viewModel.retouchPressureControlsSize },
                        set: { viewModel.setRetouchPressureControlsSize($0) }
                    )
                )
                .toggleStyle(.checkbox)
                .focusable(false)
                .fixedSize()
                .help(L10n.text("imageEditor.option.spongePressureSize.help"))
                .accessibilityHint(L10n.text("imageEditor.option.spongePressureSize.help"))
                .accessibilityIdentifier("image-editor-sponge-pressure-size")
            }

            if viewModel.selectedTool == .dodge || viewModel.selectedTool == .burn {
                Picker(
                    L10n.text("imageEditor.option.toneRange"),
                    selection: $viewModel.toneRange
                ) {
                    ForEach(ImageEditorToneRange.allCases) { range in
                        Text(range.title).tag(range)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .focusable(false)
                .frame(width: 116)
                .help(ImageEditorToneRangeShortcut.helpText)
                .accessibilityHint(ImageEditorToneRangeShortcut.helpText)
                .accessibilityIdentifier("image-editor-tone-range")

                Toggle(
                    L10n.text("imageEditor.option.protectTones"),
                    isOn: $viewModel.protectToneBrushTones
                )
                .toggleStyle(.checkbox)
                .focusable(false)
                .fixedSize()
                .help(L10n.text("imageEditor.option.protectTones.help"))
                .accessibilityIdentifier("image-editor-protect-tones")

                Toggle(
                    L10n.text("imageEditor.option.airbrush"),
                    isOn: $viewModel.toneBrushAirbrushEnabled
                )
                .toggleStyle(.checkbox)
                .focusable(false)
                .fixedSize()
                .help(L10n.text("imageEditor.option.airbrush.help"))
                .accessibilityIdentifier("image-editor-tone-airbrush")

                Toggle(
                    L10n.text("imageEditor.option.pressureSize"),
                    isOn: Binding(
                        get: { viewModel.retouchPressureControlsSize },
                        set: { viewModel.setRetouchPressureControlsSize($0) }
                    )
                )
                .toggleStyle(.checkbox)
                .focusable(false)
                .fixedSize()
                .help(L10n.text("imageEditor.option.tonePressureSize.help"))
                .accessibilityHint(L10n.text("imageEditor.option.tonePressureSize.help"))
                .accessibilityIdentifier("image-editor-tone-pressure-size")
            }

            if viewModel.selectedTool == .blur || viewModel.selectedTool == .sharpen {
                Toggle(
                    L10n.text("imageEditor.option.pressureSize"),
                    isOn: Binding(
                        get: { viewModel.retouchPressureControlsSize },
                        set: { viewModel.setRetouchPressureControlsSize($0) }
                    )
                )
                .toggleStyle(.checkbox)
                .focusable(false)
                .fixedSize()
                .help(L10n.text("imageEditor.option.blurSharpenPressureSize.help"))
                .accessibilityHint(L10n.text("imageEditor.option.blurSharpenPressureSize.help"))
                .accessibilityIdentifier("image-editor-blur-sharpen-pressure-size")
            }

            if viewModel.selectedTool == .smudge {
                Toggle(
                    L10n.text("imageEditor.option.sampleAllLayers"),
                    isOn: $viewModel.smudgeSampleAllLayersEnabled
                )
                .toggleStyle(.checkbox)
                .focusable(false)
                .fixedSize()
                .help(L10n.text("imageEditor.option.sampleAllLayers.help"))
                .accessibilityHint(L10n.text("imageEditor.option.sampleAllLayers.help"))
                .accessibilityIdentifier("image-editor-smudge-sample-all-layers")

                Toggle(
                    L10n.text("imageEditor.option.fingerPainting"),
                    isOn: $viewModel.smudgeFingerPaintingEnabled
                )
                .toggleStyle(.checkbox)
                .focusable(false)
                .fixedSize()
                .help(L10n.text("imageEditor.option.fingerPainting.help"))
                .accessibilityHint(L10n.text("imageEditor.option.fingerPainting.help"))
                .accessibilityIdentifier("image-editor-smudge-finger-painting")

                Toggle(
                    L10n.text("imageEditor.option.pressureSize"),
                    isOn: Binding(
                        get: { viewModel.retouchPressureControlsSize },
                        set: { viewModel.setRetouchPressureControlsSize($0) }
                    )
                )
                .toggleStyle(.checkbox)
                .focusable(false)
                .fixedSize()
                .help(L10n.text("imageEditor.option.smudgePressureSize.help"))
                .accessibilityHint(L10n.text("imageEditor.option.smudgePressureSize.help"))
                .accessibilityIdentifier("image-editor-smudge-pressure-size")
            }

            if viewModel.selectedTool == .cloneStamp || viewModel.selectedTool == .healingBrush {
                Toggle(
                    L10n.text("imageEditor.option.pressureSize"),
                    isOn: Binding(
                        get: { viewModel.retouchPressureControlsSize },
                        set: { viewModel.setRetouchPressureControlsSize($0) }
                    )
                )
                .toggleStyle(.checkbox)
                .focusable(false)
                .fixedSize()
                .help(L10n.text("imageEditor.option.sampledBrushPressureSize.help"))
                .accessibilityHint(L10n.text("imageEditor.option.sampledBrushPressureSize.help"))
                .accessibilityIdentifier("image-editor-sampled-brush-pressure-size")
            }

            if usesRetouchPressureOptions {
                retouchPressureSensitivityMenu
            }

            if usesPressureInputIndicator {
                brushPressureIndicator
            }

            if viewModel.selectedTool == .text {
                fontFamilyPicker(width: 190)
                Stepper(
                    L10n.format("imageEditor.properties.textSizeValue", Int(viewModel.textSize.rounded())),
                    value: $viewModel.textSize,
                    in: 6...240,
                    step: 1
                )
                .fixedSize()
                .focusable(false)
            } else {
                if usesBrushOptions {
                    optionSlider(titleKey: "imageEditor.option.size", value: $viewModel.brushSize, range: 1...96, step: 1, suffix: "px")
                    optionSlider(titleKey: "imageEditor.option.hardness", value: $viewModel.hardness, range: 0...1, step: 0.05, suffix: "")
                }
                if usesOpacityOption {
                    optionSlider(
                        titleKey: amountOptionTitleKey,
                        value: $viewModel.opacity,
                        range: amountOptionRange,
                        step: 0.05,
                        suffix: amountOptionSuffix,
                        displayMultiplier: amountOptionDisplayMultiplier
                    )
                }
                if usesBrushDynamicsOptions {
                    brushPresetMenu
                    brushRoundnessMenu
                    optionSlider(titleKey: "imageEditor.option.flow", value: $viewModel.brushFlow, range: 1...100, step: 1, suffix: "%")
                    optionSlider(titleKey: "imageEditor.option.spacing", value: $viewModel.brushSpacing, range: 1...200, step: 1, suffix: "%")
                    brushSmoothingMenu
                    brushPressureMenu
                }
                if viewModel.selectedTool.supportsSelectionMode {
                    optionSlider(titleKey: "imageEditor.option.feather", value: $viewModel.feather, range: 0...40, step: 1, suffix: "px")
                }
                if viewModel.selectedTool == .patchTool {
                    optionSlider(titleKey: "imageEditor.option.feather", value: $viewModel.feather, range: 0...40, step: 1, suffix: "px")
                }
            }
            if viewModel.selectedTool.supportsTolerance {
                optionSlider(titleKey: "imageEditor.option.tolerance", value: $viewModel.tolerance, range: 0...1, step: 0.02, suffix: "")
            }

            if viewModel.selectedTool == .cloneStamp {
                sampledBrushOptions(
                    isAligned: $viewModel.isCloneStampAligned,
                    sampleSource: $viewModel.cloneStampSampleSource,
                    sourceActionKey: "imageEditor.action.cloneSourcePick",
                    identifierPrefix: "image-editor-clone"
                ) {
                    viewModel.beginSettingCloneSource()
                }
            }

            if viewModel.selectedTool == .healingBrush {
                Picker(
                    L10n.text("imageEditor.option.healingMode"),
                    selection: $viewModel.healingBrushMode
                ) {
                    ForEach(ImageEditorHealingBrushMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .focusable(false)
                .frame(width: 116)
                .help(L10n.text("imageEditor.option.healingMode"))
                .accessibilityIdentifier("image-editor-healing-mode")

                sampledBrushOptions(
                    isAligned: $viewModel.isHealingBrushAligned,
                    sampleSource: $viewModel.healingBrushSampleSource,
                    sourceActionKey: "imageEditor.action.healingSourcePick",
                    identifierPrefix: "image-editor-healing",
                    showsExplicitSourceControls: viewModel.healingBrushMode == .source
                ) {
                    viewModel.beginSettingHealingSource()
                }
            }

            if viewModel.selectedTool == .colorSampler {
                Button(L10n.text("imageEditor.action.colorSamplerClear")) {
                    viewModel.clearColorSamplers()
                }
                .buttonStyle(EditorTextButtonStyle())
                .focusable(false)
                .disabled(viewModel.colorSamplerPoints.isEmpty)
            }

            optionHistoryButtons
        }
        .frame(height: 48)
        .padding(.horizontal, 12)
        .foregroundStyle(Color(nsColor: ImageEditorOptionsBarAppearance.foregroundColor))
        .environment(\.colorScheme, .dark)
        .background(Color(nsColor: ImageEditorTheme.panel))
    }

    private func componentLibraryOptionBar(
        selectedComponent: XomoComponentKind?
    ) -> some View {
        HStack(spacing: 12) {
            Label(
                XomoLeftSidebarTab.components.title,
                systemImage: XomoLeftSidebarTab.components.symbolName
            )
            .font(.system(size: 12, weight: .semibold))
            .frame(width: 132, alignment: .leading)
            .accessibilityIdentifier("image-editor-component-library-mode")
            .accessibilityValue(selectedComponent?.rawValue ?? XomoLeftSidebarTab.components.rawValue)

            if let selectedComponent {
                Divider()
                    .frame(height: 20)
                    .overlay(editorBorder)
                Text(selectedComponent.title)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .accessibilityIdentifier("image-editor-selected-component")
                    .accessibilityValue(selectedComponent.rawValue)
            } else {
                Text(L10n.text("xomo.componentLibrary.subtitle"))
                    .font(.system(size: 11))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                    .lineLimit(1)
            }

            optionHistoryButtons
        }
        .frame(height: 48)
        .padding(.horizontal, 12)
        .foregroundStyle(Color(nsColor: ImageEditorOptionsBarAppearance.foregroundColor))
        .environment(\.colorScheme, .dark)
        .background(Color(nsColor: ImageEditorTheme.panel))
    }

    @ViewBuilder
    private var optionHistoryButtons: some View {
        Spacer()

        Button {
            viewModel.undo()
        } label: {
            Image(systemName: "arrow.uturn.backward")
        }
        .buttonStyle(EditorIconButtonStyle(isSelected: false))
        .focusable(false)
        .disabled(!viewModel.canUndo)
        .help(L10n.text("imageEditor.action.undo"))

        Button {
            viewModel.redo()
        } label: {
            Image(systemName: "arrow.uturn.forward")
        }
        .buttonStyle(EditorIconButtonStyle(isSelected: false))
        .focusable(false)
        .disabled(!viewModel.canRedo)
        .help(L10n.text("imageEditor.action.redo"))
    }

    private var usesBrushOptions: Bool {
        switch viewModel.selectedTool {
        case .brush, .eraser, .cloneStamp, .dodge, .burn, .sponge, .blur, .sharpen,
             .smudge, .healingBrush, .quickSelection:
            true
        default:
            false
        }
    }

    private var usesOpacityOption: Bool {
        switch viewModel.selectedTool {
        case .brush, .eraser, .cloneStamp, .dodge, .burn, .sponge, .blur, .sharpen,
             .smudge, .healingBrush, .patchTool, .paintBucket, .gradient, .rectangle, .ellipse:
            true
        default:
            false
        }
    }

    private var amountOptionTitleKey: String {
        if usesExposureOption { return "imageEditor.option.exposure" }
        if usesStrengthOption { return "imageEditor.option.strength" }
        if usesFlowOption { return "imageEditor.option.flow" }
        return "imageEditor.option.opacity"
    }

    private var amountOptionRange: ClosedRange<CGFloat> {
        usesPercentageAmountOption ? 0...1 : 0.05...1
    }

    private var amountOptionSuffix: String {
        usesPercentageAmountOption ? "%" : ""
    }

    private var amountOptionDisplayMultiplier: CGFloat {
        usesPercentageAmountOption ? 100 : 1
    }

    private var usesPercentageAmountOption: Bool {
        usesExposureOption || usesStrengthOption || usesFlowOption
    }

    private var usesExposureOption: Bool {
        switch viewModel.selectedTool {
        case .dodge, .burn:
            true
        default:
            false
        }
    }

    private var usesStrengthOption: Bool {
        switch viewModel.selectedTool {
        case .blur, .sharpen, .smudge:
            true
        default:
            false
        }
    }

    private var usesFlowOption: Bool {
        viewModel.selectedTool == .sponge
    }

    private var usesBrushDynamicsOptions: Bool {
        viewModel.selectedTool == .brush || viewModel.selectedTool == .eraser
    }

    private var usesRetouchPressureOptions: Bool {
        switch viewModel.selectedTool {
        case .cloneStamp, .dodge, .burn, .sponge,
             .blur, .sharpen, .smudge, .healingBrush:
            true
        default:
            false
        }
    }

    private var usesPressureInputIndicator: Bool {
        usesBrushDynamicsOptions || usesRetouchPressureOptions
    }

    private var brushPressureIndicator: some View {
        let pressureDisplay = ImageEditorBrushPressureDisplay(pressure: activeBrushPressure)
        let tiltDisplay = ImageEditorStylusTiltDisplay(tilt: activeBrushTilt)
        let deviceStatus = switch stylusProximity {
        case .none:
            L10n.text("imageEditor.option.stylusDeviceNotDetected")
        case .pen:
            L10n.text("imageEditor.option.stylusPenDetected")
        case .eraser:
            L10n.text("imageEditor.option.stylusEraserDetected")
        }
        let valueText = pressureDisplay.percent.map {
            L10n.format("imageEditor.option.percentPreset", $0)
        } ?? "—"
        let pressureAccessibilityText = pressureDisplay.percent.map {
            L10n.format("imageEditor.option.percentPreset", $0)
        } ?? L10n.text("imageEditor.option.pressureNotDetected")
        let tiltAccessibilityText: String
        if let magnitudePercent = tiltDisplay.magnitudePercent {
            if let azimuthDegrees = tiltDisplay.azimuthDegrees {
                tiltAccessibilityText = L10n.format(
                    "imageEditor.option.tiltValue",
                    magnitudePercent,
                    "\(azimuthDegrees)°"
                )
            } else {
                tiltAccessibilityText = L10n.text("imageEditor.option.tiltPerpendicular")
            }
        } else {
            tiltAccessibilityText = L10n.text("imageEditor.option.tiltNotDetected")
        }

        return HStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(
                        stylusProximity == .none
                            ? Color.white.opacity(0.28)
                            : Color.accentColor.opacity(0.9),
                        lineWidth: 1
                    )
                if let azimuthDegrees = tiltDisplay.azimuthDegrees {
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .scaleEffect(0.55 + tiltDisplay.magnitudeFraction * 0.45)
                        .rotationEffect(.degrees(Double(azimuthDegrees) + 90))
                } else if stylusProximity == .eraser {
                    Image(systemName: "eraser.fill")
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                } else if stylusProximity == .pen {
                    Image(systemName: "pencil.tip")
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                } else {
                    Circle()
                        .fill(Color.white.opacity(tiltDisplay.magnitudePercent == nil ? 0.22 : 0.72))
                        .frame(width: 3, height: 3)
                }
            }
            .frame(width: 14, height: 14)

            VStack(alignment: .trailing, spacing: 2) {
                Text(valueText)
                    .monospacedDigit()
                    .font(.system(size: 9, weight: .medium))

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.14))
                        Capsule()
                            .fill(Color.accentColor.opacity(pressureDisplay.percent == nil ? 0 : 0.9))
                            .frame(width: proxy.size.width * pressureDisplay.fraction)
                    }
                }
                .frame(width: 30, height: 3)
            }
        }
        .frame(width: 48)
        .focusable(false)
        .help(L10n.format(
            "imageEditor.option.stylusLiveDeviceHelp",
            deviceStatus
        ))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.text("imageEditor.option.stylusInput"))
        .accessibilityValue(L10n.format(
            "imageEditor.option.stylusLiveValue",
            deviceStatus,
            pressureAccessibilityText,
            tiltAccessibilityText
        ))
        .accessibilityHint(
            L10n.text("imageEditor.option.stylusLiveHelp")
        )
        .accessibilityIdentifier("image-editor-live-pressure")
    }

    private var brushPresetMenu: some View {
        Menu {
            ForEach(viewModel.brushPresets) { preset in
                Button {
                    viewModel.applyBrushPreset(preset)
                } label: {
                    if viewModel.activeBrushPreset?.id == preset.id {
                        Label(preset.title, systemImage: "checkmark")
                    } else {
                        Text(preset.title)
                    }
                }
            }
            Divider()
            Button {
                viewModel.createBrushPresetFromCurrentSettings()
            } label: {
                Label(L10n.text("imageEditor.action.brushPresetCreate"), systemImage: "plus")
            }
            if let activePreset = viewModel.activeBrushPreset, !activePreset.isBuiltIn {
                Button(role: .destructive) {
                    viewModel.deleteBrushPreset(activePreset)
                } label: {
                    Label(L10n.text("imageEditor.action.brushPresetDelete"), systemImage: "trash")
                }
            }
        } label: {
            Label(
                viewModel.activeBrushPreset?.title ?? L10n.text("imageEditor.option.brushPreset"),
                systemImage: "paintbrush.pointed"
            )
            .font(.system(size: 11, weight: .semibold))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .focusable(false)
        .help(L10n.text("imageEditor.help.brushPreset"))
        .accessibilityIdentifier("image-editor-brush-preset-menu")
    }

    private var brushPressureMenu: some View {
        Menu {
            Toggle(
                L10n.text("imageEditor.option.pressureSize"),
                isOn: Binding(
                    get: { viewModel.brushPressureControlsSize },
                    set: { viewModel.setBrushPressureControlsSize($0) }
                )
            )
            Picker(
                L10n.text("imageEditor.option.minimumDiameter"),
                selection: Binding(
                    get: { viewModel.brushMinimumDiameter },
                    set: { viewModel.setBrushMinimumDiameter($0) }
                )
            ) {
                ForEach(ImageEditorBrushMinimumDiameterPresets.values, id: \.self) { diameter in
                    Text(L10n.format("imageEditor.option.percentPreset", Int(diameter)))
                        .tag(diameter)
                }
            }
            .disabled(!viewModel.brushPressureControlsSize)
            Toggle(
                L10n.text("imageEditor.option.pressureOpacity"),
                isOn: Binding(
                    get: { viewModel.brushPressureControlsOpacity },
                    set: { viewModel.setBrushPressureControlsOpacity($0) }
                )
            )
            Picker(
                L10n.text("imageEditor.option.minimumOpacity"),
                selection: Binding(
                    get: { viewModel.brushMinimumOpacity },
                    set: { viewModel.setBrushMinimumOpacity($0) }
                )
            ) {
                ForEach(ImageEditorBrushMinimumOpacityPresets.values, id: \.self) { opacity in
                    Text(L10n.format("imageEditor.option.percentPreset", Int(opacity)))
                        .tag(opacity)
                }
            }
            .disabled(!viewModel.brushPressureControlsOpacity)
            Toggle(
                L10n.text("imageEditor.option.pressureFlow"),
                isOn: Binding(
                    get: { viewModel.brushPressureControlsFlow },
                    set: { viewModel.setBrushPressureControlsFlow($0) }
                )
            )
            Picker(
                L10n.text("imageEditor.option.minimumFlow"),
                selection: Binding(
                    get: { viewModel.brushMinimumFlow },
                    set: { viewModel.setBrushMinimumFlow($0) }
                )
            ) {
                ForEach(ImageEditorBrushMinimumFlowPresets.values, id: \.self) { flow in
                    Text(L10n.format("imageEditor.option.percentPreset", Int(flow)))
                        .tag(flow)
                }
            }
            .disabled(!viewModel.brushPressureControlsFlow)
            Toggle(
                L10n.text("imageEditor.option.tiltShape"),
                isOn: Binding(
                    get: { viewModel.brushTiltControlsShape },
                    set: { viewModel.setBrushTiltControlsShape($0) }
                )
            )
            Picker(
                L10n.text("imageEditor.option.pressureSensitivity"),
                selection: Binding(
                    get: { viewModel.brushPressureSensitivity },
                    set: { viewModel.setBrushPressureSensitivity($0) }
                )
            ) {
                ForEach(ImageEditorPressureSensitivityPresets.values, id: \.self) { sensitivity in
                    Text("\(Int(sensitivity))%")
                        .tag(sensitivity)
                }
            }
        } label: {
            Label(
                L10n.text("imageEditor.option.stylusDynamics"),
                systemImage: "scribble.variable"
            )
                .font(.system(size: 11, weight: .semibold))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .focusable(false)
        .xomoFocusEffectDisabled()
        .help(L10n.text("imageEditor.option.stylusDynamicsHelp"))
        .accessibilityIdentifier("image-editor-brush-pressure-menu")
    }

    private var brushSmoothingMenu: some View {
        Menu {
            Picker(
                L10n.text("imageEditor.option.smoothing"),
                selection: Binding(
                    get: { viewModel.brushSmoothing },
                    set: { viewModel.setBrushSmoothing($0) }
                )
            ) {
                ForEach(ImageEditorBrushSmoothingPresets.values, id: \.self) { smoothing in
                    Text(L10n.format("imageEditor.option.percentPreset", Int(smoothing)))
                        .tag(smoothing)
                }
            }
        } label: {
            Text(
                L10n.format(
                    "imageEditor.option.smoothingValue",
                    Int(viewModel.brushSmoothing.rounded())
                )
            )
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .focusable(false)
        .xomoFocusEffectDisabled()
        .help(L10n.text("imageEditor.help.brushSmoothing"))
        .accessibilityIdentifier("image-editor-brush-smoothing")
    }

    private var brushRoundnessMenu: some View {
        Menu {
            Picker(
                L10n.text("imageEditor.option.brushRoundness"),
                selection: Binding(
                    get: { viewModel.brushTipRoundness },
                    set: { viewModel.setBrushTipRoundness($0) }
                )
            ) {
                ForEach(ImageEditorBrushRoundnessPresets.values, id: \.self) { roundness in
                    Text(L10n.format("imageEditor.option.percentPreset", Int(roundness)))
                        .tag(roundness)
                }
            }
            Divider()
            Picker(
                L10n.text("imageEditor.option.brushAngle"),
                selection: Binding(
                    get: { viewModel.brushTipAngleDegrees },
                    set: { viewModel.setBrushTipAngleDegrees($0) }
                )
            ) {
                ForEach(ImageEditorBrushAnglePresets.values, id: \.self) { angle in
                    Text(L10n.format("imageEditor.option.degreePreset", Int(angle)))
                        .tag(angle)
                }
            }
        } label: {
            Text(
                L10n.format(
                    "imageEditor.option.brushTipShapeValue",
                    Int(viewModel.brushTipRoundness.rounded()),
                    Int(viewModel.brushTipAngleDegrees.rounded())
                )
            )
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .focusable(false)
        .xomoFocusEffectDisabled()
        .help(L10n.text("imageEditor.help.brushTipShape"))
        .accessibilityIdentifier("image-editor-brush-roundness")
    }

    private var retouchPressureSensitivityMenu: some View {
        Menu {
            Picker(
                L10n.text("imageEditor.option.pressureSensitivity"),
                selection: Binding(
                    get: { viewModel.retouchPressureSensitivity },
                    set: { viewModel.setRetouchPressureSensitivity($0) }
                )
            ) {
                ForEach(ImageEditorPressureSensitivityPresets.values, id: \.self) { sensitivity in
                    Text(L10n.format("imageEditor.option.percentPreset", Int(sensitivity)))
                        .tag(sensitivity)
                }
            }
            .focusable(false)
        } label: {
            Label {
                Text(L10n.format(
                    "imageEditor.option.percentPreset",
                    Int(viewModel.retouchPressureSensitivity.rounded())
                ))
            } icon: {
                Image(systemName: "slider.horizontal.3")
            }
            .font(.system(size: 11, weight: .semibold))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .focusable(false)
        .xomoFocusEffectDisabled()
        .help(L10n.text("imageEditor.option.retouchPressureSensitivity.help"))
        .accessibilityLabel(L10n.text("imageEditor.option.pressureSensitivity"))
        .accessibilityValue(L10n.format(
            "imageEditor.option.percentPreset",
            Int(viewModel.retouchPressureSensitivity.rounded())
        ))
        .accessibilityIdentifier("image-editor-retouch-pressure-sensitivity")
    }

    private var selectionModePicker: some View {
        Picker(L10n.text("imageEditor.option.selectionMode"), selection: $viewModel.selectionMode) {
            ForEach(ImageEditorSelectionMode.allCases) { mode in
                Text(mode.compactTitle)
                    .foregroundStyle(Color(nsColor: ImageEditorOptionsBarAppearance.foregroundColor))
                    .tag(mode)
                    .help(mode.title)
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .focusable(false)
        .frame(width: 226)
        .help(L10n.text("imageEditor.option.selectionMode"))
    }

    private var patchModePicker: some View {
        Picker(L10n.text("imageEditor.option.patchMode"), selection: $viewModel.patchMode) {
            ForEach(ImageEditorPatchMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .focusable(false)
        .frame(width: 150)
        .help(L10n.text("imageEditor.option.patchMode"))
        .accessibilityIdentifier("image-editor-patch-mode")
    }

    @ViewBuilder
    private func sampledBrushOptions(
        isAligned: Binding<Bool>,
        sampleSource: Binding<ImageEditorCloneSampleSource>,
        sourceActionKey: String,
        identifierPrefix: String,
        showsExplicitSourceControls: Bool = true,
        beginSettingSource: @escaping () -> Void
    ) -> some View {
        if showsExplicitSourceControls {
            Toggle(L10n.text("imageEditor.option.cloneAligned"), isOn: isAligned)
                .toggleStyle(.checkbox)
                .focusable(false)
                .xomoFocusEffectDisabled()
                .accessibilityIdentifier("\(identifierPrefix)-aligned")
        }

        Picker(L10n.text("imageEditor.option.cloneSampleSource"), selection: sampleSource) {
            ForEach(ImageEditorCloneSampleSource.allCases) { source in
                Text(source.title).tag(source)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .environment(\.colorScheme, .dark)
        .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
        .frame(width: 150)
        .focusable(false)
        .xomoFocusEffectDisabled()
        .accessibilityLabel(L10n.text("imageEditor.option.cloneSampleSource"))
        .accessibilityIdentifier("\(identifierPrefix)-sample-source")

        if showsExplicitSourceControls {
            Button(L10n.text(sourceActionKey), action: beginSettingSource)
                .buttonStyle(EditorTextButtonStyle())
                .focusable(false)
                .xomoFocusEffectDisabled()
                .help(L10n.text(sourceActionKey))
        }
    }

    private var marqueeShapePicker: some View {
        Menu {
            ForEach(ImageEditorMarqueeShape.allCases) { shape in
                Button {
                    viewModel.selectMarqueeShape(shape)
                } label: {
                    Label(shape.title, systemImage: shape.symbolName)
                }
            }
        } label: {
            Label(viewModel.marqueeShape.title, systemImage: viewModel.marqueeShape.symbolName)
                .foregroundStyle(Color(nsColor: ImageEditorOptionsBarAppearance.foregroundColor))
                .frame(minWidth: 88, alignment: .leading)
        }
        .menuStyle(.borderlessButton)
        .focusable(false)
        .fixedSize()
        .help(L10n.text("imageEditor.option.marqueeShape"))
        .accessibilityIdentifier("image-editor-marquee-shape")
        .accessibilityValue(viewModel.marqueeShape.rawValue)
    }

    private func optionSlider(
        titleKey: String,
        value: Binding<CGFloat>,
        range: ClosedRange<CGFloat>,
        step: CGFloat,
        suffix: String,
        displayMultiplier: CGFloat = 1
    ) -> some View {
        HStack(spacing: 6) {
            Text(L10n.text(titleKey))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(nsColor: ImageEditorOptionsBarAppearance.foregroundColor))
                .lineLimit(1)
                .fixedSize()
            Slider(value: value, in: range, step: step)
                .frame(width: usesBrushDynamicsOptions ? 76 : 92)
                .focusable(false)
                .xomoFocusEffectDisabled()
            Text(sliderText(value.wrappedValue * displayMultiplier, suffix: suffix))
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(Color(nsColor: ImageEditorOptionsBarAppearance.foregroundColor))
                .frame(width: suffix.isEmpty ? 28 : 42, alignment: .leading)
        }
    }

    private func sliderText(_ value: CGFloat, suffix: String) -> String {
        if suffix.isEmpty {
            return String(format: "%.2f", value)
        }
        return "\(Int(value.rounded()))\(suffix)"
    }

    private var leftSidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                ForEach(XomoLeftSidebarTab.allCases) { tab in
                    Button {
                        isMarqueeShapeMenuPresented = false
                        hoveredTool = nil
                        viewModel.selectLeftSidebarTab(tab)
                    } label: {
                        Image(systemName: tab.symbolName)
                            .symbolRenderingMode(.monochrome)
                            .foregroundColor(
                                viewModel.selectedLeftSidebarTab == tab
                                    ? .white
                                    : Color(nsColor: ImageEditorTheme.text)
                            )
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(EditorIconButtonStyle(isSelected: viewModel.selectedLeftSidebarTab == tab))
                    .focusable(false)
                    .help(tab.title)
                    .accessibilityLabel(tab.title)
                    .accessibilityIdentifier("xomo-left-sidebar-tab-\(tab.rawValue)")
                    .accessibilityValue(viewModel.selectedLeftSidebarTab == tab ? "selected" : "available")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(6)

            Divider().overlay(editorBorder)

            Group {
                switch viewModel.selectedLeftSidebarTab {
                case .tools:
                    toolRail
                case .components:
                    XomoComponentLibraryPanel(viewModel: viewModel)
                }
            }
            // Component previews install native drag sources. Give each tab a
            // distinct subtree identity so switching back tears those sources
            // down instead of reusing their hit-test view for the tool rail.
            .id(viewModel.selectedLeftSidebarTab)
            .frame(maxHeight: .infinity)
        }
        .frame(width: viewModel.selectedLeftSidebarTab == .tools ? imageEditorToolRailWidth : imageEditorComponentLibraryWidth)
        .background(Color(nsColor: ImageEditorTheme.chrome))
        .accessibilityIdentifier("xomo-left-sidebar")
    }

    private var toolRail: some View {
        VStack(spacing: 8) {
            ScrollView(.vertical, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    LazyVGrid(
                        columns: Array(
                            repeating: GridItem(
                                .fixed(imageEditorToolButtonHitSize),
                                spacing: imageEditorToolGridSpacing
                            ),
                            count: imageEditorToolGridColumnCount
                        ),
                        spacing: imageEditorToolGridSpacing
                    ) {
                        ForEach(ImageEditorTool.allCases) { tool in
                            toolRailItem(tool)
                        }
                    }
                    .frame(
                        width: imageEditorToolGridWidth,
                        height: imageEditorToolGridHeight,
                        alignment: .top
                    )

                    EditorToolRailGridClickSurface(
                        toolCount: ImageEditorTool.allCases.count,
                        marqueeToolIndex: ImageEditorTool.allCases.firstIndex(of: .marquee),
                        onActivate: selectToolFromRail(at:),
                        onToggleMarqueeMenu: {
                            isMarqueeShapeMenuPresented.toggle()
                        },
                        onHoverChanged: updateHoveredTool(at:)
                    )
                    .frame(
                        width: imageEditorToolGridWidth,
                        height: imageEditorToolGridHeight
                    )
                    .accessibilityHidden(true)
                }
                .frame(
                    width: imageEditorToolGridWidth,
                    height: imageEditorToolGridHeight
                )
            }

            Divider().overlay(editorBorder)
            colorChips
            quickMaskControls
        }
        .frame(width: imageEditorToolRailWidth)
        .padding(.vertical, 8)
    }

    private var quickMaskControls: some View {
        HStack(spacing: 4) {
            quickMaskButton
            Button {
                isQuickMaskOptionsPresented.toggle()
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(EditorIconButtonStyle(isSelected: isQuickMaskOptionsPresented))
            .focusable(false)
            .xomoFocusEffectDisabled()
            .help(L10n.text("imageEditor.action.quickMaskOptions"))
            .accessibilityIdentifier("image-editor-quick-mask-options")
            .popover(isPresented: $isQuickMaskOptionsPresented, arrowEdge: .trailing) {
                quickMaskOptionsPopover
            }
        }
    }

    private var quickMaskButton: some View {
        Button {
            viewModel.toggleQuickMaskMode()
        } label: {
            Image(systemName: "circle.inset.filled")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 30, height: 30)
        }
        .buttonStyle(EditorIconButtonStyle(isSelected: viewModel.isQuickMaskMode))
        .focusable(false)
        .xomoFocusEffectDisabled()
        .help(L10n.text("imageEditor.action.quickMask"))
        .accessibilityIdentifier("image-editor-quick-mask")
        .accessibilityValue(viewModel.isQuickMaskMode ? "selected" : "available")
    }

    private var quickMaskOptionsPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.text("imageEditor.quickMask.optionsTitle"))
                .font(.system(size: 13, weight: .semibold))

            Text(L10n.text("imageEditor.quickMask.targetLabel"))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))

            HStack(spacing: 6) {
                ForEach(ImageEditorQuickMaskOverlayTarget.allCases) { target in
                    Button(target.title) {
                        viewModel.setQuickMaskOverlayTarget(target)
                    }
                    .buttonStyle(EditorSegmentButtonStyle(isSelected: viewModel.quickMaskOverlayTarget == target))
                    .focusable(false)
                    .xomoFocusEffectDisabled()
                }
            }

            HStack {
                Text(L10n.text("imageEditor.quickMask.color"))
                Spacer()
                ColorPicker("", selection: quickMaskOverlayColorBinding, supportsOpacity: false)
                    .labelsHidden()
                    .focusable(false)
                    .xomoFocusEffectDisabled()
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(L10n.text("imageEditor.quickMask.opacity"))
                    Spacer()
                    Text("\(Int((viewModel.quickMaskOverlayOpacity * 100).rounded()))%")
                        .monospacedDigit()
                }
                Slider(
                    value: quickMaskOverlayOpacityBinding,
                    in: CGFloat(ImageEditorQuickMaskPreferences.minimumOpacity)...CGFloat(ImageEditorQuickMaskPreferences.maximumOpacity),
                    step: 0.05
                )
                .focusable(false)
                .xomoFocusEffectDisabled()
            }
        }
        .font(.system(size: 12))
        .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
        .padding(12)
        .frame(width: 260)
        .background(Color(nsColor: ImageEditorTheme.panelRaised))
        .focusable(false)
        .xomoFocusEffectDisabled()
    }

    private var quickMaskOverlayColorBinding: Binding<Color> {
        Binding {
            Color(nsColor: viewModel.quickMaskOverlayColor)
        } set: { value in
            viewModel.setQuickMaskOverlayColor(NSColor(value))
        }
    }

    private var quickMaskOverlayOpacityBinding: Binding<CGFloat> {
        Binding {
            viewModel.quickMaskOverlayOpacity
        } set: { value in
            viewModel.setQuickMaskOverlayOpacity(value)
        }
    }

    @ViewBuilder
    private func toolRailItem(_ tool: ImageEditorTool) -> some View {
        if tool == .marquee {
            ZStack(alignment: .bottomTrailing) {
                EditorToolRailTile(
                    isSelected: viewModel.selectedTool == tool,
                    isHovered: hoveredTool == tool,
                    action: { selectToolFromRail(tool) }
                ) {
                    ZStack {
                        ImageEditorMarqueeToolSymbol(shape: viewModel.marqueeShape)
                            .frame(width: 30, height: 30)
                    }
                    .frame(width: imageEditorToolButtonHitSize, height: imageEditorToolButtonHitSize)
                    .contentShape(Rectangle())
                }
                .focusable(false)
                .xomoFocusEffectDisabled()
                .accessibilityLabel(tool.title)

                Color.clear
                    .frame(width: 11, height: 11)
                    .allowsHitTesting(false)
                    .focusable(false)
                    .xomoFocusEffectDisabled()
                    .padding(1)
                    .accessibilityLabel(L10n.text("imageEditor.option.marqueeShape"))
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction {
                        isMarqueeShapeMenuPresented.toggle()
                    }
            }
            .frame(width: imageEditorToolButtonHitSize, height: imageEditorToolButtonHitSize)
            .help(L10n.text("imageEditor.option.marqueeShape"))
            .accessibilityIdentifier("image-editor-tool-marquee")
            .accessibilityValue(viewModel.marqueeShape.rawValue)
        } else {
            EditorToolRailTile(
                isSelected: viewModel.selectedTool == tool,
                isHovered: hoveredTool == tool,
                action: { selectToolFromRail(tool) }
            ) {
                ZStack {
                    if tool == .paintBucket {
                        ImageEditorPaintBucketSymbol()
                            .frame(width: 30, height: 30)
                    } else {
                        Image(systemName: tool.symbolName)
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 30, height: 30)
                    }
                }
                .frame(width: imageEditorToolButtonHitSize, height: imageEditorToolButtonHitSize)
                .contentShape(Rectangle())
            }
            .focusable(false)
            .xomoFocusEffectDisabled()
            .accessibilityLabel(tool.title)
            .help(tool.helpText)
            .accessibilityIdentifier("image-editor-tool-\(tool.rawValue)")
            .accessibilityValue(viewModel.selectedTool == tool ? "selected" : "available")
        }
    }

    private var marqueeShapeFloatingMenu: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(ImageEditorMarqueeShape.allCases) { shape in
                EditorMarqueeShapeActionRow(
                    shape: shape,
                    isSelected: viewModel.marqueeShape == shape
                ) {
                    viewModel.selectMarqueeShape(shape)
                    isMarqueeShapeMenuPresented = false
                }
            }
        }
        .padding(8)
        .frame(width: 150)
        .background(Color(nsColor: ImageEditorTheme.panelRaised))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: ImageEditorTheme.border), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
        .focusable(false)
        .xomoFocusEffectDisabled()
        .accessibilityIdentifier("image-editor-marquee-shape-menu")
    }

    private func selectToolFromRail(_ tool: ImageEditorTool) {
        isMarqueeShapeMenuPresented = false
        viewModel.selectTool(tool)
    }

    private func selectToolFromRail(at index: Int) {
        guard ImageEditorTool.allCases.indices.contains(index) else { return }
        selectToolFromRail(ImageEditorTool.allCases[index])
    }

    private func updateHoveredTool(at index: Int?) {
        guard let index, ImageEditorTool.allCases.indices.contains(index) else {
            hoveredTool = nil
            return
        }
        hoveredTool = ImageEditorTool.allCases[index]
    }

    private var imageEditorToolGridWidth: CGFloat {
        imageEditorToolButtonHitSize * CGFloat(imageEditorToolGridColumnCount)
            + imageEditorToolGridSpacing * CGFloat(imageEditorToolGridColumnCount - 1)
    }

    private var imageEditorToolGridHeight: CGFloat {
        let rowCount = (ImageEditorTool.allCases.count + imageEditorToolGridColumnCount - 1)
            / imageEditorToolGridColumnCount
        return imageEditorToolButtonHitSize * CGFloat(rowCount)
            + imageEditorToolGridSpacing * CGFloat(max(0, rowCount - 1))
    }

    @ViewBuilder
    private var workspaceInputModeHint: some View {
        switch viewModel.workspaceInputMode {
        case .tool:
            selectedToolHint
        case .componentLibrary(let selectedComponent):
            componentLibraryHint(selectedComponent: selectedComponent)
        }
    }

    private var selectedToolHint: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label {
                Text(viewModel.selectedTool.title)
            } icon: {
                selectedToolIcon
            }
                .font(.system(size: 11, weight: .semibold))
            Text(viewModel.selectedTool.helpText)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                .lineLimit(1)
        }
        .frame(minWidth: 230, maxWidth: 440, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color(nsColor: ImageEditorTheme.panelRaised).opacity(0.96), in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(editorBorder, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.28), radius: 6, x: 0, y: 2)
        .allowsHitTesting(false)
        .accessibilityIdentifier("image-editor-selected-tool-hint")
        .accessibilityValue(viewModel.selectedTool.rawValue)
    }

    private func componentLibraryHint(
        selectedComponent: XomoComponentKind?
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(
                selectedComponent?.title ?? XomoLeftSidebarTab.components.title,
                systemImage: XomoLeftSidebarTab.components.symbolName
            )
            .font(.system(size: 11, weight: .semibold))
            Text(L10n.text("xomo.componentLibrary.subtitle"))
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                .lineLimit(1)
        }
        .frame(minWidth: 230, maxWidth: 440, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Color(nsColor: ImageEditorTheme.panelRaised).opacity(0.96),
            in: RoundedRectangle(cornerRadius: 6)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(editorBorder, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.28), radius: 6, x: 0, y: 2)
        .allowsHitTesting(false)
        .accessibilityIdentifier("image-editor-component-library-hint")
        .accessibilityValue(
            selectedComponent?.rawValue ?? XomoLeftSidebarTab.components.rawValue
        )
    }

    @ViewBuilder
    private var selectedToolIcon: some View {
        if viewModel.selectedTool == .paintBucket {
            ImageEditorPaintBucketSymbol()
        } else {
            Image(systemName: viewModel.selectedTool.symbolName)
        }
    }

    private var toolShortcutButtons: some View {
        Group {
            Button {
                viewModel.clearColorSamplers()
            } label: {
                EmptyView()
            }
            .keyboardShortcut("x", modifiers: [.option])
            .accessibilityHidden(true)

            ForEach(ImageEditorTool.classicShortcutGroups) { group in
                Button {
                    viewModel.selectClassicToolShortcut(group.key)
                } label: {
                    EmptyView()
                }
                .keyboardShortcut(KeyEquivalent(group.key), modifiers: [])
                .accessibilityHidden(true)

                if group.tools.count > 1 {
                    Button {
                        viewModel.cycleClassicToolShortcut(group.key)
                    } label: {
                        EmptyView()
                    }
                    .keyboardShortcut(KeyEquivalent(group.key), modifiers: [.shift])
                    .accessibilityHidden(true)
                }
            }
        }
        .frame(width: 0, height: 0)
        .opacity(0)
    }

    private var brushShortcutButtons: some View {
        Group {
            Button {
                viewModel.adjustBrushSizeShortcut(by: -1)
            } label: {
                EmptyView()
            }
            .keyboardShortcut("[", modifiers: [])
            .accessibilityHidden(true)

            Button {
                viewModel.adjustBrushSizeShortcut(by: 1)
            } label: {
                EmptyView()
            }
            .keyboardShortcut("]", modifiers: [])
            .accessibilityHidden(true)

            Button {
                viewModel.adjustBrushHardnessShortcut(by: -0.25)
            } label: {
                EmptyView()
            }
            .keyboardShortcut("[", modifiers: [.shift])
            .accessibilityHidden(true)

            Button {
                viewModel.adjustBrushHardnessShortcut(by: 0.25)
            } label: {
                EmptyView()
            }
            .keyboardShortcut("]", modifiers: [.shift])
            .accessibilityHidden(true)
        }
        .frame(width: 0, height: 0)
        .opacity(0)
    }

    private var opacityShortcutButtons: some View {
        Group {
            ForEach([1, 2, 3, 4, 5, 6, 7, 8, 9, 0], id: \.self) { digit in
                Button {
                    viewModel.applyOpacityShortcutDigit(digit)
                } label: {
                    EmptyView()
                }
                .keyboardShortcut(KeyEquivalent(Character(String(digit))), modifiers: [])
                .accessibilityHidden(true)
            }
        }
        .frame(width: 0, height: 0)
        .opacity(0)
    }

    private var colorShortcutButtons: some View {
        Group {
            Button {
                viewModel.resetForegroundBackgroundColors()
            } label: {
                EmptyView()
            }
            .keyboardShortcut("d", modifiers: [])
            .accessibilityHidden(true)

            Button {
                viewModel.swapForegroundBackgroundColors()
            } label: {
                EmptyView()
            }
            .keyboardShortcut("x", modifiers: [])
            .accessibilityHidden(true)
        }
        .frame(width: 0, height: 0)
        .opacity(0)
    }

    private var alternateZoomShortcutButtons: some View {
        Group {
            Button {
                viewModel.zoomOut()
            } label: {
                EmptyView()
            }
            .keyboardShortcut("-", modifiers: [.option])
            .accessibilityHidden(true)

            Button {
                viewModel.zoomIn()
            } label: {
                EmptyView()
            }
            .keyboardShortcut("=", modifiers: [.option, .shift])
            .accessibilityHidden(true)

            Button {
                viewModel.zoomIn()
            } label: {
                EmptyView()
            }
            .keyboardShortcut("=", modifiers: [.option])
            .accessibilityHidden(true)
        }
        .frame(width: 0, height: 0)
        .opacity(0)
    }

    private var nudgeShortcutButtons: some View {
        Group {
            nudgeShortcutButton(.leftArrow, delta: CGSize(width: -1, height: 0), modifiers: [])
            nudgeShortcutButton(.rightArrow, delta: CGSize(width: 1, height: 0), modifiers: [])
            nudgeShortcutButton(.upArrow, delta: CGSize(width: 0, height: -1), modifiers: [])
            nudgeShortcutButton(.downArrow, delta: CGSize(width: 0, height: 1), modifiers: [])
            nudgeShortcutButton(.leftArrow, delta: CGSize(width: -5, height: 0), modifiers: [.option])
            nudgeShortcutButton(.rightArrow, delta: CGSize(width: 5, height: 0), modifiers: [.option])
            nudgeShortcutButton(.upArrow, delta: CGSize(width: 0, height: -5), modifiers: [.option])
            nudgeShortcutButton(.downArrow, delta: CGSize(width: 0, height: 5), modifiers: [.option])
            nudgeShortcutButton(.leftArrow, delta: CGSize(width: -10, height: 0), modifiers: [.shift])
            nudgeShortcutButton(.rightArrow, delta: CGSize(width: 10, height: 0), modifiers: [.shift])
            nudgeShortcutButton(.upArrow, delta: CGSize(width: 0, height: -10), modifiers: [.shift])
            nudgeShortcutButton(.downArrow, delta: CGSize(width: 0, height: 10), modifiers: [.shift])
        }
        .frame(width: 0, height: 0)
        .opacity(0)
    }

    private func nudgeShortcutButton(_ key: KeyEquivalent, delta: CGSize, modifiers: EventModifiers) -> some View {
        Button {
            viewModel.nudgeSelectionOrSelectedLayer(by: delta)
        } label: {
            EmptyView()
        }
        .keyboardShortcut(key, modifiers: modifiers)
        .accessibilityHidden(true)
    }

    private func performKeyboardShortcut(_ action: ImageEditorKeyboardShortcutAction) {
        switch action {
        case .newCanvas: viewModel.isNewCanvasSheetPresented = true
        case .openProject: viewModel.openProjectDocument()
        case .saveProject: viewModel.saveProjectDocument()
        case .export: viewModel.openExportPanel()
        case .openFigmaLinkImport: isFigmaLinkImportPresented = true
        case .undo: viewModel.undo()
        case .redo: viewModel.redo()
        case .cutSelectionClipboard: viewModel.cutSelectionToClipboard()
        case .copySelectionClipboard: viewModel.copySelectionToClipboard()
        case .copyMergedClipboard: viewModel.copyMergedToClipboard()
        case .copySelectedLayersClipboard: viewModel.copySelectedLayersToClipboard()
        case .pasteClipboardLayer: viewModel.pasteClipboardAsLayer()
        case .pasteClipboardIntoSelection: viewModel.pasteClipboardIntoSelectionAsLayer()
        case .pasteClipboardInPlaceLayer: viewModel.pasteClipboardInPlaceAsLayer()
        case .toggleTransformControls: viewModel.toggleTransformControlsVisible()
        case .fillSelection: viewModel.fillSelection()
        case .fillSelectionBackground: viewModel.fillSelectionWithBackgroundColor()
        case .clearSelectionPixels: viewModel.clearSelectionPixels()
        case .resizeImage: viewModel.resizeImageToControlSize()
        case .resizeCanvas: viewModel.resizeCanvasToControlSize()
        case .levels: viewModel.selectAdjustment(.levels)
        case .curves: viewModel.selectAdjustment(.curves)
        case .colorBalance: viewModel.selectAdjustment(.colorBalance)
        case .hueSaturation: viewModel.selectAdjustment(.hueSaturation)
        case .toneRange(let range): viewModel.applyToneRangeShortcut(range)
        case .spongeMode(let mode): viewModel.applySpongeModeShortcut(mode)
        case .desaturate: viewModel.desaturateSelectedLayer()
        case .invertPixels: viewModel.invertSelectedLayer()
        case .autoLevels: viewModel.autoLevelsSelectedLayer()
        case .autoContrast: viewModel.autoContrastSelectedLayer()
        case .autoColor: viewModel.autoColorSelectedLayer()
        case .newLayer: viewModel.addLayer()
        case .duplicateSelectionOrLayer: viewModel.duplicateSelectionOrSelectedLayer()
        case .cutSelectionToLayer: viewModel.cutSelectionToNewLayer()
        case .groupSelectedLayer: viewModel.groupSelectedLayer()
        case .ungroupSelectedLayers: viewModel.ungroupSelectedLayers()
        case .mergeDown: viewModel.mergeSelectedLayerDown()
        case .stampVisible: viewModel.stampVisibleLayers()
        case .mergeVisible: viewModel.mergeVisibleLayers()
        case .layerTop: viewModel.moveSelectedLayerToTop(inVisibleOrder: filteredVisibleLayerRowIDs)
        case .layerUp: viewModel.moveSelectedLayerUp(inVisibleOrder: filteredVisibleLayerRowIDs)
        case .layerDown: viewModel.moveSelectedLayerDown(inVisibleOrder: filteredVisibleLayerRowIDs)
        case .layerBottom: viewModel.moveSelectedLayerToBottom(inVisibleOrder: filteredVisibleLayerRowIDs)
        case .selectAll: viewModel.selectAll()
        case .clearSelection: viewModel.clearSelection()
        case .reselectSelection: viewModel.reselectSelection()
        case .invertSelection: viewModel.invertSelection()
        case .featherSelection: viewModel.featherSelection()
        case .toggleQuickMask: viewModel.toggleQuickMaskMode()
        case .applyLastFilter: viewModel.applyLastFilter()
        case .toggleRulers: viewModel.toggleRulersVisible()
        case .toggleGuides: viewModel.toggleGuidesVisible()
        case .toggleGuideSnapping: viewModel.toggleGuideSnapping()
        case .toggleGuidesLocked: viewModel.toggleGuidesLocked()
        case .toggleGrid: viewModel.toggleGridVisible()
        case .zoomIn: viewModel.zoomIn()
        case .zoomOut: viewModel.zoomOut()
        case .actualPixels: viewModel.zoomActualPixels()
        case .fitOnScreen: viewModel.fitZoom()
        case .toggleWorkspaceChrome: viewModel.toggleWorkspaceChromeVisibility()
        case .toggleRightDock: viewModel.toggleRightDockVisibility()
        case .showInfoSummary:
            viewModel.statusText = "\(viewModel.pointerColorInfoText) | \(viewModel.sizeText)"
        case .showColorSummary: viewModel.statusText = viewModel.colorPanelSummaryText
        case .showBrushSummary: viewModel.statusText = viewModel.brushesPanelSummaryText
        case .showLayersPanel:
            viewModel.isLayersPanelVisible = true
            selectedLayerPanelTab = .layers
        }
    }

    private var colorChips: some View {
        ZStack(alignment: .topLeading) {
            colorChip(
                color: $viewModel.backgroundColor,
                accessibilityIdentifier: "image-editor-background-color-well",
                accessibilityLabelKey: "imageEditor.action.colorEditBackground"
            )
                .offset(x: 11, y: 11)

            colorChip(
                color: $viewModel.foregroundColor,
                accessibilityIdentifier: "image-editor-foreground-color-well",
                accessibilityLabelKey: "imageEditor.action.colorEditForeground"
            )

            Button {
                viewModel.swapForegroundBackgroundColors()
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(EditorIconButtonStyle(isSelected: false))
            .focusable(false)
            .help(L10n.text("imageEditor.action.colorSwapForegroundBackground"))
            .accessibilityIdentifier("image-editor-color-swap")
            .accessibilityLabel(L10n.text("imageEditor.action.colorSwapForegroundBackground"))
            .offset(x: 29, y: -2)
        }
        .frame(width: 50, height: 42)
        .padding(.bottom, 2)
    }

    private func colorChip(
        color: Binding<NSColor>,
        accessibilityIdentifier: String,
        accessibilityLabelKey: String
    ) -> some View {
        ImageEditorColorWell(
            color: color,
            accessibilityIdentifier: accessibilityIdentifier,
            accessibilityLabel: L10n.text(accessibilityLabelKey)
        )
        .frame(width: 26, height: 26)
        .overlay {
            Rectangle()
                .strokeBorder(Color.white.opacity(0.92), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .help(L10n.text(accessibilityLabelKey))
    }

    private var canvasWorkspace: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: imageEditorCanvasToolbarHeight)
            canvasSurface
        }
        .overlay(alignment: .top) {
            documentTab
                .zIndex(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var canvasSurface: some View {
        GeometryReader { geometry in
                ZStack {
                    Color(nsColor: ImageEditorTheme.window)
                    checkerboard
                        .frame(width: fittedImageRect(in: geometry.size).width, height: fittedImageRect(in: geometry.size).height)
                        .position(x: fittedImageRect(in: geometry.size).midX, y: fittedImageRect(in: geometry.size).midY)

                    Image(nsImage: viewModel.previewImage)
                        .resizable()
                        .frame(width: fittedImageRect(in: geometry.size).width, height: fittedImageRect(in: geometry.size).height)
                        .position(x: fittedImageRect(in: geometry.size).midX, y: fittedImageRect(in: geometry.size).midY)
                        .shadow(color: .black.opacity(0.46), radius: 12, x: 0, y: 8)

                    if canvasInteractionTool == .patchTool, let patchPreviewImage {
                        Image(nsImage: patchPreviewImage)
                            .resizable()
                            .frame(width: fittedImageRect(in: geometry.size).width, height: fittedImageRect(in: geometry.size).height)
                            .position(x: fittedImageRect(in: geometry.size).midX, y: fittedImageRect(in: geometry.size).midY)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }

                    gridOverlay(in: geometry.size)
                    guideOverlay(in: geometry.size)
                    guideInteractionOverlay(in: geometry.size)
                    quickMaskOverlay(in: geometry.size)
                    selectionOverlay(in: geometry.size)
                    savedPathOverlay(in: geometry.size)
                    sliceOverlay(in: geometry.size)
                    hotspotOverlay(in: geometry.size)
                    deliverySelectionOverlay(in: geometry.size)
                    colorSamplerOverlay(in: geometry.size)
                    sampledBrushSourceOverlay(in: geometry.size)
                    toneAirbrushOverlay(in: geometry.size)
                    layerTransformOverlay(in: geometry.size)
                    shapeGradientControlOverlay(in: geometry.size)
                    textBoxOverflowOverlay(in: geometry.size)
                    dragOverlay(in: geometry.size)
                    rulerOverlay(in: geometry.size)
                    canvasTextEditingOverlay(in: geometry.size)
                }
                .contentShape(Rectangle())
                .coordinateSpace(name: "image-editor-canvas-space")
                .accessibilityElement(children: .contain)
                .accessibilityLabel(L10n.text("imageEditor.accessibility.canvas"))
                .accessibilityValue(L10n.format(
                    "imageEditor.accessibility.canvasValue",
                    Int(viewModel.document.canvasSize.width.rounded()),
                    Int(viewModel.document.canvasSize.height.rounded()),
                    Int((viewModel.zoom * 100).rounded()),
                    canvasInteractionTool.title
                ))
                .accessibilityIdentifier("image-editor-canvas")
                .xomoCanvasPlatformInteractions(
                    onDrop: { components, location in
                        guard let rawValue = components.first,
                              let component = XomoComponentKind(rawValue: rawValue),
                              let canvasPoint = imagePoint(from: location, in: geometry.size)
                        else { return false }
                        viewModel.insertXomoComponent(
                            component,
                            at: viewModel.xomoComponentDropOrigin(component, centeredAt: canvasPoint)
                        )
                        return true
                    },
                    onMagnifyChanged: { magnification, location in
                        viewModel.magnifyCanvas(
                            magnification,
                            at: location ?? CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2),
                            viewportSize: geometry.size
                        )
                    },
                    onMagnifyEnded: {
                        viewModel.endCanvasMagnify()
                    },
                    onHoverChanged: { isInside, location in
                        isPointerInsideCanvas = isInside
                        hoverViewPoint = location
                        if let location {
                            updateCanvasCursor(at: location, in: geometry.size)
                        } else if isInside {
                            // macOS 13's onHover callback has no pointer
                            // coordinates. Still refresh the semantic tool
                            // cursor on entry instead of leaving the previous
                            // tool's pointer behind until the next event.
                            refreshCanvasCursor(in: geometry.size)
                        } else if !isInside {
                            viewModel.updatePointer(nil)
                            activeBrushPressure = nil
                            activeBrushTilt = nil
                            NSCursor.arrow.set()
                        }
                    }
                )
                // Keep the editor gesture simultaneous with the drop host so
                // external component drops still work on macOS 13. The AppKit
                // canvas monitor below is the single authoritative component
                // drag path; the parent canvas owns ordinary layers/tools.
                .simultaneousGesture(canvasGesture(in: geometry.size))
                .overlay(
                    ScrollWheelZoomView(
                        pointerCaptureState: viewModel.canvasPointerCaptureState,
                        pointerCaptureKind: ImageEditorPrimaryToolPointerCapture.captureKind(
                            sidebarTab: viewModel.selectedLeftSidebarTab,
                            tool: canvasInteractionTool
                        ),
                        capturesPrimaryPointer: ImageEditorPrimaryToolPointerCapture.usesDirectCanvasHitTarget(
                            sidebarTab: viewModel.selectedLeftSidebarTab,
                            tool: canvasInteractionTool
                        ),
                        onZoom: { factor, location, viewportSize in
                            // 每个离散滚轮 tick 独立锚定当前状态：复用捏合缩放的锚定数学，
                            // 立即结束一次缩放会话，避免下一次滚动沿用上一次的基准而叠加错位。
                            viewModel.magnifyCanvas(factor, at: location, viewportSize: viewportSize)
                            viewModel.endCanvasMagnify()
                        },
                        onMouseMoved: { location, stylusInput in
                            isPointerInsideCanvas = true
                            hoverViewPoint = location
                            if usesPressureInputIndicator {
                                activeBrushPressure = stylusInput.pressure
                                activeBrushTilt = stylusInput.tilt
                            } else {
                                activeBrushPressure = nil
                                activeBrushTilt = nil
                            }
                            updateCanvasCursor(at: location, in: geometry.size)
                        },
                        onStylusProximityChanged: { proximity in
                            stylusProximity = proximity
                            activeBrushPressure = nil
                            activeBrushTilt = nil
                            refreshCanvasCursor(in: geometry.size)
                        },
                        onMiddleMousePanBegan: {
                            isCanvasPanGestureActive = true
                            NSCursor.closedHand.set()
                        },
                        onMiddleMousePanChanged: { delta in
                            viewModel.nudgeCanvas(by: delta)
                        },
                        onMiddleMousePanEnded: {
                            isCanvasPanGestureActive = false
                            refreshCanvasCursor(in: geometry.size)
                        },
                        onRangeToolDragBegan: { location in
                            guard canvasInteractionTool == .marquee
                                    || canvasInteractionTool == .gradient,
                                  let imagePoint = imagePoint(from: location, in: geometry.size)
                            else { return false }
                            dragStart = imagePoint
                            dragEnd = imagePoint
                            viewModel.updatePointer(imagePoint)
                            return true
                        },
                        onRangeToolDragChanged: { location in
                            let imagePoint = imagePoint(from: location, in: geometry.size)
                            viewModel.updatePointer(imagePoint)
                            if canvasInteractionTool == .marquee {
                                dragEnd = boundedImagePoint(from: location, in: geometry.size)
                            } else {
                                dragEnd = imagePoint
                            }
                        },
                        onRangeToolDragEnded: { location in
                            if canvasInteractionTool == .marquee, let dragStart {
                                viewModel.createMarqueeSelection(
                                    from: dragStart,
                                    to: boundedImagePoint(from: location, in: geometry.size)
                                )
                            } else if canvasInteractionTool == .gradient {
                                viewModel.drawGradient(
                                    from: dragStart,
                                    to: imagePoint(from: location, in: geometry.size)
                                )
                            }
                            dragStart = nil
                            dragEnd = nil
                            refreshCanvasCursor(in: geometry.size)
                        },
                        onPrimaryToolDragBegan: { location in
                            guard ImageEditorPrimaryToolPointerCapture.shouldCapture(
                                    sidebarTab: viewModel.selectedLeftSidebarTab,
                                    tool: canvasInteractionTool
                                  ),
                                  let imagePoint = imagePoint(from: location, in: geometry.size)
                            else { return false }
                            viewModel.canvasPointerCaptureState.activeTool = canvasInteractionTool
                            // Keep the native NSView as first responder for the
                            // whole brush stroke. Mutating several SwiftUI
                            // states on mouse-down can rebuild the overlay
                            // before mouse-up and strand the responder.
                            if canvasInteractionTool != .brush && canvasInteractionTool != .eraser {
                                primaryToolViewStart = location
                                dragStart = imagePoint
                                dragEnd = imagePoint
                                viewModel.updatePointer(imagePoint)
                            }
                            return true
                        },
                        onPrimaryToolDragChanged: { location, pressure, tilt in
                            guard let imagePoint = imagePoint(from: location, in: geometry.size) else { return }
                            let primaryTool = viewModel.canvasPointerCaptureState.activeTool
                                ?? canvasInteractionTool
                            if primaryTool == .brush || primaryTool == .eraser {
                                activeBrushPressure = pressure
                                activeBrushTilt = tilt
                                updateCanvasCursor(at: location, in: geometry.size)
                                return
                            }
                            dragEnd = imagePoint
                            viewModel.updatePointer(imagePoint)
                        },
                        onPrimaryToolDragEnded: { location, samples in
                            let primaryTool = viewModel.canvasPointerCaptureState.activeTool
                                ?? canvasInteractionTool
                            let endImagePoint = imagePoint(from: location, in: geometry.size) ?? dragEnd
                            let fallbackBrushSamples = samples.compactMap { sample in
                                imagePoint(from: sample.location, in: geometry.size).map {
                                    ImageEditorBrushStrokeSample(
                                        point: $0,
                                        pressure: sample.pressure,
                                        tilt: sample.tilt
                                    )
                                }
                            }
                            if let endImagePoint,
                               primaryTool == .brush || primaryTool == .eraser {
                                let endStylusInput = ImageEditorStylusInput.sample(
                                    from: NSApp.currentEvent
                                )
                                brushStrokeSamples.append(
                                    ImageEditorBrushStrokeSample(
                                        point: endImagePoint,
                                        pressure: endStylusInput.pressure,
                                        tilt: endStylusInput.tilt
                                    )
                                )
                            }
                            let committedBrushSamples = brushStrokeSamples.count >= 2
                                ? brushStrokeSamples
                                : fallbackBrushSamples
                            switch primaryTool {
                            case .brush:
                                viewModel.drawBrush(samples: committedBrushSamples)
                            case .eraser:
                                viewModel.drawBrush(
                                    samples: committedBrushSamples,
                                    erase: true
                                )
                            case .rectangle:
                                if let dragStart, let endImagePoint {
                                    viewModel.drawShape(from: dragStart, to: endImagePoint, ellipse: false)
                                }
                            case .ellipse:
                                if let dragStart, let endImagePoint {
                                    viewModel.drawShape(from: dragStart, to: endImagePoint, ellipse: true)
                                }
                            case .text:
                                let viewTranslation = CGSize(
                                    width: location.x - (primaryToolViewStart?.x ?? location.x),
                                    height: location.y - (primaryToolViewStart?.y ?? location.y)
                                )
                                if let paragraphRect = ImageEditorTextBoxGeometry.paragraphRect(
                                    from: dragStart,
                                    to: endImagePoint,
                                    viewTranslation: viewTranslation
                                ) {
                                    beginCanvasParagraphTextEditing(in: paragraphRect)
                                } else {
                                    beginCanvasTextEditing(at: endImagePoint)
                                }
                            default:
                                break
                            }
                            brushStrokeSamples = []
                            activeBrushPressure = nil
                            activeBrushTilt = nil
                            dragStart = nil
                            dragEnd = nil
                            primaryToolViewStart = nil
                            refreshCanvasCursor(in: geometry.size)
                        },
                        onLayerResizeBegan: { location in
                            guard case let .resize(handle) = layerTransformCursorTarget(
                                at: location,
                                in: geometry.size
                            ) else { return false }
                            activeResizeHandle = handle
                            viewModel.beginResizingSelectedLayer(handle: handle.transformModelHandle)
                            ImageEditorCanvasCursor.transformCursor(for: .resize(handle)).set()
                            return true
                        },
                        onLayerResizeChanged: { location in
                            guard let handle = activeResizeHandle else { return }
                            viewModel.resizeSelectedLayer(
                                to: unboundedImagePoint(from: location, in: geometry.size),
                                handle: handle.transformModelHandle,
                                preservingAspectRatio: NSEvent.modifierFlags.contains(.shift),
                                resizingFromCenter: NSEvent.modifierFlags.contains(.option)
                            )
                        },
                        onLayerResizeEnded: { location in
                            if let handle = activeResizeHandle {
                                viewModel.resizeSelectedLayer(
                                    to: unboundedImagePoint(from: location, in: geometry.size),
                                    handle: handle.transformModelHandle,
                                    preservingAspectRatio: NSEvent.modifierFlags.contains(.shift),
                                    resizingFromCenter: NSEvent.modifierFlags.contains(.option)
                                )
                                viewModel.finishResizingSelectedLayer()
                            }
                            activeResizeHandle = nil
                            refreshCanvasCursor(in: geometry.size)
                        },
                        onObjectMoveCandidateBegan: { location, modifierFlags in
                            guard canvasInteractionTool == .move,
                                  ImageEditorObjectDragEventPolicy.allowsCandidate(
                                    modifierFlags: modifierFlags,
                                    hasTransformTarget: layerTransformCursorTarget(
                                        at: location,
                                        in: geometry.size
                                    ) != nil
                                  ),
                                  let imagePoint = imagePoint(from: location, in: geometry.size)
                            else { return false }
                            let selectedFrame = viewModel.selectedXomoObjectFrame
                            let isInsideSelectedObject = selectedFrame?.contains(imagePoint) == true
                            let didSelectObject = isInsideSelectedObject
                                || viewModel.selectXomoObject(at: imagePoint)
                            guard didSelectObject, viewModel.canResizeSelectedLayer else { return false }
                            return true
                        },
                        onObjectMoveActivated: {
                            resetObjectMoveTracking()
                            guard viewModel.beginMovingSelectedLayer() else { return false }
                            isSelectedObjectMoveGestureActive = true
                            ImageEditorCanvasCursor.objectMoveCursor().set()
                            return true
                        },
                        onObjectMoveChanged: { translation in
                            guard isSelectedObjectMoveGestureActive else { return }
                            updateObjectMove(translation: translation, in: geometry.size)
                            ImageEditorCanvasCursor.objectMoveCursor().set()
                        },
                        onObjectMoveEnded: {
                            guard isSelectedObjectMoveGestureActive else { return }
                            viewModel.finishMovingSelectedLayer()
                            isSelectedObjectMoveGestureActive = false
                            resetObjectMoveTracking()
                            refreshCanvasCursor(in: geometry.size)
                        }
                    )
                    .allowsHitTesting(
                        ImageEditorPrimaryToolPointerCapture.usesDirectCanvasHitTarget(
                            sidebarTab: viewModel.selectedLeftSidebarTab,
                            tool: canvasInteractionTool
                        )
                    )
                )
                .overlay {
                    let imageRect = fittedImageRect(in: geometry.size)
                    let displayScale = imageRect.width / max(viewModel.document.canvasSize.width, 1)
                    let isPointerOverDrawableCanvas = ImageEditorCanvasCursor.isPointerOverDrawableCanvas(
                        hoverViewPoint,
                        imageRect: imageRect
                    )
                    let canvasPoint = hoverViewPoint.flatMap { imagePoint(from: $0, in: geometry.size) }
                    let objectMoveIsActive = isSelectedObjectMoveGestureActive || isObjectMoveGestureActive
                    // The move cursor wins for the entire active transaction.
                    // Avoid rescanning visible pixels and the layer stack for
                    // every lightweight preview-frame update while dragging.
                    let contentHit: XomoCanvasContentHit = objectMoveIsActive
                        ? .movable
                        : (canvasPoint.map(viewModel.canvasContentHit(at:)) ?? .none)
                    let cropHandle = cropInteractionHandle(at: hoverViewPoint, in: geometry.size)
                    let layerTransformTarget = layerTransformCursorTarget(
                        at: hoverViewPoint,
                        in: geometry.size
                    )
                    let displayedBrushDiameter = ImageEditorCanvasCursor.pressureAdjustedBrushDiameter(
                        baseDiameter: viewModel.brushSize * displayScale,
                        tool: canvasInteractionTool,
                        pressure: activeBrushPressure,
                        brushPressureControlsSize: viewModel.brushPressureControlsSize,
                        retouchPressureControlsSize: viewModel.retouchPressureControlsSize,
                        brushPressureSensitivity: viewModel.brushPressureSensitivity / 100,
                        brushMinimumDiameter: viewModel.brushMinimumDiameter / 100,
                        retouchPressureSensitivity: viewModel.retouchPressureSensitivity / 100
                    )
                    ImageEditorCursorRectView(
                        cursor: ImageEditorCanvasCursor.cursor(
                            for: viewModel.selectedLeftSidebarTab,
                            selectedTool: viewModel.selectedTool,
                            brushDiameter: displayedBrushDiameter,
                            brushTilt: activeBrushTilt,
                            brushTiltControlsShape: viewModel.brushTiltControlsShape,
                            brushTipRoundness: viewModel.brushTipRoundness / 100,
                            brushTipAngleDegrees: viewModel.brushTipAngleDegrees,
                            isPointerOverCanvas: isPointerOverDrawableCanvas,
                            isPointerOverMovableContent: contentHit.isMovable,
                            isPointerOverBlockedContent: contentHit.isBlocked,
                            isPointerOverColorSamplerPoint:
                                canvasInteractionTool == .colorSampler
                                    && hoverViewPoint.map {
                                        colorSamplerPointID(
                                            at: $0,
                                            in: geometry.size
                                        ) != nil
                                    } == true,
                            handIsDragging: isCanvasPanGestureActive,
                            isObjectMoveGestureActive: objectMoveIsActive,
                            isColorSamplerMoveGestureActive: colorSamplerDrag != nil,
                            isSpacebarPanning: isSpacebarPanning,
                            isCanvasPanGestureActive: isCanvasPanGestureActive,
                            modifierFlags: canvasModifierFlags,
                            marqueeShape: viewModel.marqueeShape,
                            cropHandle: cropHandle,
                            layerTransformTarget: layerTransformTarget
                        )
                    )
                    .allowsHitTesting(false)
                }
                .onChange(of: viewModel.selectedTool) { tool in
                    if tool != .crop {
                        pendingCropRect = nil
                        endPendingCropInteraction()
                    }
                    if tool != .colorSampler {
                        resetColorSamplerGesture()
                    }
                    if tool != .text {
                        cancelCanvasTextEditing()
                    }
                    refreshCanvasCursor(in: geometry.size)
                }
                .onChange(of: viewModel.selectedLeftSidebarTab) { tab in
                    activeBrushPressure = nil
                    activeBrushTilt = nil
                    if tab == .components {
                        pendingCropRect = nil
                        endPendingCropInteraction()
                        resetColorSamplerGesture()
                        cancelCanvasTextEditing()
                        // Changing sidebar mode must immediately clear the
                        // previous tool cursor, even before the next hover
                        // event arrives from the canvas.
                        NSCursor.arrow.set()
                    }
                    if isPointerInsideCanvas {
                        refreshCanvasCursor(in: geometry.size)
                    }
                }
                .onChange(of: viewModel.document.selectedLayerIDs) { _ in
                    // The full selection set is the authoritative change
                    // signal. Shift-adding or removing a peer can change the
                    // transform bounds while the primary selection stays put.
                    if viewModel.selectedLeftSidebarTab == .components {
                        NSCursor.arrow.set()
                    }
                    refreshCanvasCursor(in: geometry.size)
                }
                .onChange(of: viewModel.document.areTransformControlsVisible) { _ in
                    refreshCanvasCursor(in: geometry.size)
                }
                .onChange(of: viewModel.document.areExtrasVisible) { _ in
                    refreshCanvasCursor(in: geometry.size)
                }
                .onChange(of: viewModel.canResizeSelectedLayer) { _ in
                    refreshCanvasCursor(in: geometry.size)
                }
                .onChange(of: viewModel.canRotateSelectedLayer) { _ in
                    refreshCanvasCursor(in: geometry.size)
                }
                .onChange(of: viewModel.brushSize) { _ in
                    refreshCanvasCursor(in: geometry.size)
                }
                .onChange(of: viewModel.brushTiltControlsShape) { _ in
                    refreshCanvasCursor(in: geometry.size)
                }
                .onChange(of: isSpacebarPanning) { _ in
                    refreshCanvasCursor(in: geometry.size)
                }
                .onChange(of: canvasModifierFlags) { _ in
                    refreshCanvasCursor(in: geometry.size)
                }
                .onChange(of: viewModel.zoom) { _ in
                    refreshCanvasCursor(in: geometry.size)
                }
                .onDisappear {
                    isPointerInsideCanvas = false
                    activeBrushPressure = nil
                    activeBrushTilt = nil
                    endPendingCropInteraction()
                    resetColorSamplerGesture()
                    NSCursor.arrow.set()
                }
                .onAppear {
                    viewModel.updateCanvasViewportSize(geometry.size)
                }
                .onChange(of: geometry.size) { newSize in
                    viewModel.updateCanvasViewportSize(newSize)
                }
        }
    }

    private var documentTab: some View {
        HStack(spacing: 8) {
            Label(viewModel.document.sourceName, systemImage: "photo")
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 10)
                .frame(height: 32)
                .background(Color(nsColor: ImageEditorTheme.panelRaised))
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            if let pendingCropRect {
                HStack(spacing: 4) {
                    Button {
                        viewModel.crop(to: pendingCropRect)
                        self.pendingCropRect = nil
                    } label: {
                        Image(systemName: "checkmark")
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(EditorIconButtonStyle(isSelected: true))
                    .help(L10n.text("imageEditor.action.cropConfirm"))
                    .accessibilityIdentifier("image-editor-crop-confirm")

                    Button {
                        self.pendingCropRect = nil
                    } label: {
                        Image(systemName: "xmark")
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(EditorIconButtonStyle(isSelected: false))
                    .help(L10n.text("imageEditor.action.cropCancel"))
                    .accessibilityIdentifier("image-editor-crop-cancel")
                }
                .padding(.horizontal, 4)
                .frame(height: 32)
                .background(Color(nsColor: ImageEditorTheme.panelRaised))
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
            Spacer()
            Button {
                viewModel.zoomOut()
            } label: {
                Image(systemName: "minus.magnifyingglass")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(EditorIconButtonStyle(isSelected: false))
            .focusable(false)
            .help(L10n.text("imageEditor.menu.view.zoomOut"))
            .accessibilityIdentifier("image-editor-zoom-out")

            Slider(value: zoomSliderBinding, in: 0...1)
                .frame(width: 120)
                .focusable(false)
                .help(L10n.text("imageEditor.tool.zoom.help"))
                .accessibilityIdentifier("image-editor-zoom-slider")

            Text(viewModel.zoomText)
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                .frame(width: 42, alignment: .trailing)

            Button {
                viewModel.zoomIn()
            } label: {
                Image(systemName: "plus.magnifyingglass")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(EditorIconButtonStyle(isSelected: false))
            .focusable(false)
            .help(L10n.text("imageEditor.menu.view.zoomIn"))
            .accessibilityIdentifier("image-editor-zoom-in")

            Button {
                viewModel.fitZoom()
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(EditorIconButtonStyle(isSelected: false))
            .focusable(false)
            .help(L10n.text("imageEditor.menu.view.fit"))
            .accessibilityIdentifier("image-editor-zoom-fit")
        }
        .frame(height: imageEditorCanvasToolbarHeight)
        .padding(.horizontal, 12)
        .background(Color(nsColor: ImageEditorTheme.window))
    }

    private var zoomSliderBinding: Binding<Double> {
        let minimumZoom = Double(ImageEditorViewModel.minimumZoom)
        let zoomRangeRatio = Double(ImageEditorViewModel.maximumZoom / ImageEditorViewModel.minimumZoom)
        return Binding {
            log(max(minimumZoom, Double(viewModel.zoom)) / minimumZoom) / log(zoomRangeRatio)
        } set: { sliderValue in
            let clampedValue = min(max(sliderValue, 0), 1)
            viewModel.setZoom(CGFloat(minimumZoom * pow(zoomRangeRatio, clampedValue)))
        }
    }

    private var checkerboard: some View {
        Canvas { context, size in
            let square: CGFloat = 12
            let light = Color(nsColor: NSColor(calibratedWhite: 0.94, alpha: 1))
            let dark = Color(nsColor: NSColor(calibratedWhite: 0.72, alpha: 1))
            var y: CGFloat = 0
            var row = 0
            while y < size.height {
                var x: CGFloat = 0
                var col = 0
                while x < size.width {
                    let rect = CGRect(x: x, y: y, width: square, height: square)
                    context.fill(Path(rect), with: .color((row + col).isMultiple(of: 2) ? light : dark))
                    x += square
                    col += 1
                }
                y += square
                row += 1
            }
        }
    }

    @ViewBuilder
    private func dragOverlay(in size: CGSize) -> some View {
        if !viewModel.pendingPenPathPoints.isEmpty {
            let points = viewModel.pendingPenPathPoints.map { viewPoint(from: $0, in: size) }
            Canvas { context, _ in
                guard let first = points.first else { return }
                var path = Path()
                path.move(to: first)
                for point in points.dropFirst() {
                    path.addLine(to: point)
                }
                context.stroke(path, with: .color(Color.white.opacity(0.88)), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                context.stroke(path, with: .color(Color(nsColor: ImageEditorTheme.selected).opacity(0.95)), style: StrokeStyle(lineWidth: 2, dash: [6, 4], dashPhase: 5))
                for (index, point) in points.enumerated() {
                    let radius: CGFloat = index == 0 ? 5 : 4
                    let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(index == 0 ? Color.white : Color(nsColor: ImageEditorTheme.selected)))
                    context.stroke(Path(ellipseIn: rect), with: .color(Color.black.opacity(0.45)), lineWidth: 1)
                }
            }
            .allowsHitTesting(false)
        }

        if let anchorPoints = selectedPathAnchorOverlayPoints(in: size), !anchorPoints.isEmpty {
            Canvas { context, _ in
                for item in anchorPoints {
                    for handle in [item.inHandle, item.outHandle].compactMap({ $0 }) {
                        var handleLine = Path()
                        handleLine.move(to: item.anchor)
                        handleLine.addLine(to: handle)
                        context.stroke(
                            handleLine,
                            with: .color(Color.white.opacity(0.62)),
                            style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                        )
                    }
                    for handle in [
                        (role: ImageEditorPathControlRole.inHandle, point: item.inHandle),
                        (role: ImageEditorPathControlRole.outHandle, point: item.outHandle)
                    ] {
                        guard let point = handle.point else { continue }
                        let isHandleSelected = item.subpathIndex == viewModel.selectedPathSubpathIndex
                            && item.index == viewModel.selectedPathAnchorIndex
                            && viewModel.selectedPathControlRole == handle.role
                        let rect = CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)
                        context.fill(
                            Path(rect),
                            with: .color(isHandleSelected ? Color.white : Color(nsColor: ImageEditorTheme.selected).opacity(0.78))
                        )
                        context.stroke(Path(rect), with: .color(Color.black.opacity(0.55)), lineWidth: 1)
                    }
                    let isAnchorSelected = item.subpathIndex == viewModel.selectedPathSubpathIndex
                        && item.index == viewModel.selectedPathAnchorIndex
                        && viewModel.selectedPathControlRole == .anchor
                    let radius: CGFloat = isAnchorSelected ? 5.5 : 4
                    let anchorRect = CGRect(
                        x: item.anchor.x - radius,
                        y: item.anchor.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                    context.fill(
                        Path(ellipseIn: anchorRect),
                        with: .color(isAnchorSelected ? Color.white : Color(nsColor: ImageEditorTheme.selected))
                    )
                    context.stroke(Path(ellipseIn: anchorRect), with: .color(Color.black.opacity(0.55)), lineWidth: 1)
                }
            }
            .allowsHitTesting(false)
        }

        if let dragStart, let dragEnd, canvasInteractionTool == .gradient || canvasInteractionTool == .patchTool {
            let start = viewPoint(from: dragStart, in: size)
            let end = viewPoint(from: dragEnd, in: size)
            Canvas { context, _ in
                var path = Path()
                path.move(to: start)
                path.addLine(to: end)
                context.stroke(path, with: .color(Color.white.opacity(0.86)), style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
                context.stroke(path, with: .color(Color(nsColor: ImageEditorTheme.selected).opacity(0.9)), style: StrokeStyle(lineWidth: 2, dash: [7, 5], dashPhase: 6))
                context.fill(Path(ellipseIn: CGRect(x: start.x - 4, y: start.y - 4, width: 8, height: 8)), with: .color(Color.white.opacity(0.92)))
                context.fill(Path(ellipseIn: CGRect(x: end.x - 4, y: end.y - 4, width: 8, height: 8)), with: .color(Color(nsColor: ImageEditorTheme.selected).opacity(0.92)))

                if canvasInteractionTool == .patchTool,
                   let edgeGeometry = viewModel.selectionEdgeGeometry {
                    let delta = CGSize(width: dragEnd.x - dragStart.x, height: dragEnd.y - dragStart.y)
                    var translatedPath = Path()
                    for contour in edgeGeometry.contours {
                        guard let first = contour.first else { continue }
                        translatedPath.move(to: viewPoint(
                            from: CGPoint(x: first.x + delta.width, y: first.y + delta.height),
                            in: size
                        ))
                        for point in contour.dropFirst() {
                            translatedPath.addLine(to: viewPoint(
                                from: CGPoint(x: point.x + delta.width, y: point.y + delta.height),
                                in: size
                            ))
                        }
                    }
                    context.stroke(
                        translatedPath,
                        with: .color(Color.gray.opacity(0.9)),
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                    )
                }
            }
            .allowsHitTesting(false)
        }

        if let dragStart, let dragEnd, shouldShowDragRect {
            let imageRect = canvasInteractionTool == .marquee
                ? viewModel.marqueeSelectionRect(from: dragStart, to: dragEnd)
                : CGRect(
                    x: min(dragStart.x, dragEnd.x),
                    y: min(dragStart.y, dragEnd.y),
                    width: abs(dragEnd.x - dragStart.x),
                    height: abs(dragEnd.y - dragStart.y)
                )
            let rect = viewRect(from: imageRect, in: size)
            Group {
                if canvasInteractionTool == .marquee && viewModel.marqueeShape.isEllipse {
                    Ellipse()
                        .stroke(Color(nsColor: ImageEditorTheme.selected), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                        .background(Ellipse().fill(Color(nsColor: ImageEditorTheme.selected).opacity(0.12)))
                } else {
                    Rectangle()
                        .stroke(Color(nsColor: ImageEditorTheme.selected), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                        .background(Rectangle().fill(Color(nsColor: ImageEditorTheme.selected).opacity(0.12)))
                }
            }
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
        }

        if let pendingCropRect {
            let rect = viewRect(from: pendingCropRect, in: size)
            ZStack {
                Rectangle()
                    .stroke(Color(nsColor: ImageEditorTheme.selected), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .background(Rectangle().fill(Color(nsColor: ImageEditorTheme.selected).opacity(0.10)))
                    .frame(width: rect.width, height: rect.height)
                ForEach(ImageEditorCropHandle.resizeHandles) { handle in
                    let point = viewPoint(from: handle.point(in: pendingCropRect), in: size)
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(Color.white.opacity(0.96))
                        .overlay(
                            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                                .stroke(Color(nsColor: ImageEditorTheme.selected), lineWidth: 1)
                        )
                        .frame(width: 8, height: 8)
                        .position(x: point.x - rect.minX, y: point.y - rect.minY)
                }
            }
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .allowsHitTesting(false)
        }
    }

    private var shouldShowDragRect: Bool {
        switch canvasInteractionTool {
        case .crop, .marquee, .rectangle, .ellipse, .text:
            true
        default:
            false
        }
    }

    @ViewBuilder
    private func colorSamplerOverlay(in size: CGSize) -> some View {
        ForEach(Array(viewModel.colorSamplerPoints.enumerated()), id: \.element.id) { index, sample in
            let samplePoint = colorSamplerDrag?.id == sample.id
                ? colorSamplerDrag?.previewPoint ?? sample.point
                : sample.point
            let point = viewPoint(from: samplePoint, in: size)
            let isRemovalTarget = pendingColorSamplerRemovalID == sample.id
            Text("\(index + 1)")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Color(nsColor: sample.color).opacity(isRemovalTarget ? 0.52 : 0.92))
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(
                            Color.white.opacity(isRemovalTarget ? 0.76 : 0),
                            style: StrokeStyle(lineWidth: 1, dash: [3, 2])
                        )
                        .padding(-3)
                    Circle().stroke(Color.black.opacity(0.7), lineWidth: 1)
                }
                .position(point)
                .allowsHitTesting(false)

            Text(colorSamplerLabel(index: index + 1, color: sample.color))
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.68))
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                .position(x: point.x + 54, y: point.y - 14)
                .opacity(isRemovalTarget ? 0.56 : 1)
                .allowsHitTesting(false)
        }
    }

    private func colorSamplerPointID(
        at viewPoint: CGPoint,
        in size: CGSize,
        hitRadius: CGFloat = 12
    ) -> UUID? {
        let maximumDistanceSquared = hitRadius * hitRadius
        return viewModel.colorSamplerPoints
            .map { sample -> (id: UUID, distanceSquared: CGFloat) in
                let sampleViewPoint = self.viewPoint(from: sample.point, in: size)
                let deltaX = sampleViewPoint.x - viewPoint.x
                let deltaY = sampleViewPoint.y - viewPoint.y
                return (sample.id, deltaX * deltaX + deltaY * deltaY)
            }
            .filter { $0.distanceSquared <= maximumDistanceSquared }
            .min { $0.distanceSquared < $1.distanceSquared }?
            .id
    }

    private func resetColorSamplerGesture() {
        colorSamplerDrag = nil
        pendingColorSamplerRemovalID = nil
        isColorSamplerRemovalGestureActive = false
    }

    private func colorSamplerLabel(index: Int, color: NSColor) -> String {
        let rgb = color.usingColorSpace(.deviceRGB) ?? color
        return "\(index)  R\(Int((rgb.redComponent * 255).rounded())) G\(Int((rgb.greenComponent * 255).rounded())) B\(Int((rgb.blueComponent * 255).rounded())) A\(Int((rgb.alphaComponent * 255).rounded()))"
    }

    private func deliveryObjectReference(at point: CGPoint) -> ImageEditorDeliveryObjectReference? {
        if let hotspot = viewModel.availableHotspots.reversed().first(where: {
            $0.frame.standardized.contains(point)
        }) {
            return .hotspot(hotspot.id)
        }
        if let slice = viewModel.availableSlices.reversed().first(where: {
            $0.frame.standardized.contains(point)
        }) {
            return .slice(slice.id)
        }
        return nil
    }

    private func deliveryFrame(
        for reference: ImageEditorDeliveryObjectReference
    ) -> CGRect? {
        switch reference {
        case .slice(let id):
            return viewModel.slice(with: id)?.frame
        case .hotspot(let id):
            return viewModel.hotspot(with: id)?.frame
        }
    }

    private func selectDeliveryObject(_ reference: ImageEditorDeliveryObjectReference) {
        switch reference {
        case .slice(let id):
            _ = viewModel.selectSlice(id: id)
        case .hotspot(let id):
            _ = viewModel.selectHotspot(id: id)
        }
    }

    private func beginDeliveryObjectMove(at point: CGPoint) -> Bool {
        guard let reference = deliveryObjectReference(at: point),
              let frame = deliveryFrame(for: reference)
        else { return false }
        selectDeliveryObject(reference)
        deliveryDrag = ImageEditorDeliveryDrag(
            reference: reference,
            originalFrame: frame.standardized,
            previewFrame: frame.standardized
        )
        return true
    }

    private func updateDeliveryObjectMove(translation: CGSize, in size: CGSize) {
        guard let deliveryDrag else { return }
        let imageRect = fittedImageRect(in: size)
        let delta = ImageEditorCanvasDragGeometry.imageDelta(
            from: translation,
            canvasSize: viewModel.document.canvasSize,
            imageRect: imageRect
        )
        let previewFrame = viewModel.clampedDeliveryFrame(
            deliveryDrag.originalFrame,
            offsetBy: delta
        )
        self.deliveryDrag = ImageEditorDeliveryDrag(
            reference: deliveryDrag.reference,
            originalFrame: deliveryDrag.originalFrame,
            previewFrame: previewFrame
        )
    }

    private func finishDeliveryObjectMove() {
        guard let deliveryDrag else { return }
        guard deliveryDrag.previewFrame != deliveryDrag.originalFrame else {
            self.deliveryDrag = nil
            return
        }
        switch deliveryDrag.reference {
        case .slice(let id):
            _ = viewModel.updateSlice(id: id, frame: deliveryDrag.previewFrame)
        case .hotspot(let id):
            _ = viewModel.updateHotspot(id: id, frame: deliveryDrag.previewFrame)
        }
        self.deliveryDrag = nil
    }

    @ViewBuilder
    private func sampledBrushSourceOverlay(in size: CGSize) -> some View {
        if let sourcePoint = sampledBrushSourcePoint {
            let point = viewPoint(from: sourcePoint, in: size)
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.92), lineWidth: 1)
                    .frame(width: 15, height: 15)
                Rectangle()
                    .fill(Color.white.opacity(0.92))
                    .frame(width: 21, height: 1)
                Rectangle()
                    .fill(Color.white.opacity(0.92))
                    .frame(width: 1, height: 21)
            }
            .shadow(color: .black.opacity(0.85), radius: 1)
            .position(point)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private func updateToneAirbrushStroke(at point: CGPoint, pressure: CGFloat?) {
        guard viewModel.toneBrushAirbrushEnabled else {
            toneAirbrushStroke.reset()
            return
        }
        let time = Date.timeIntervalSinceReferenceDate
        if toneAirbrushStroke.isActive {
            toneAirbrushStroke.update(to: point, pressure: pressure, time: time)
        } else {
            toneAirbrushStroke.begin(at: point, pressure: pressure, time: time)
        }
    }

    private func finishToneAirbrushStroke(at point: CGPoint?) -> [ImageEditorBrushStrokeSample] {
        guard viewModel.toneBrushAirbrushEnabled,
              toneAirbrushStroke.isActive,
              let finalPoint = point ?? toneAirbrushStroke.currentPoint
        else {
            toneAirbrushStroke.reset()
            return []
        }
        return toneAirbrushStroke.finishSamples(
            at: finalPoint,
            pressure: toneAirbrushStroke.currentPressure,
            time: Date.timeIntervalSinceReferenceDate
        )
    }

    @ViewBuilder
    private func toneAirbrushOverlay(in size: CGSize) -> some View {
        if viewModel.toneBrushAirbrushEnabled,
           canvasInteractionTool == .dodge || canvasInteractionTool == .burn,
           let imagePoint = toneAirbrushStroke.currentPoint,
           let dwellBeganAt = toneAirbrushStroke.currentDwellBeganAt {
            let imageRect = fittedImageRect(in: size)
            let pressureScale = viewModel.retouchPressureControlsSize
                ? ImageEditorBrushStrokeKernel.mappedPressure(
                    toneAirbrushStroke.currentPressure ?? 1,
                    sensitivity: viewModel.retouchPressureSensitivity / 100
                )
                : 1
            ImageEditorToneAirbrushPreview(
                isBurn: canvasInteractionTool == .burn,
                point: viewPoint(from: imagePoint, in: size),
                dwellBeganAt: dwellBeganAt,
                exposure: viewModel.opacity,
                diameter: max(
                    4,
                    viewModel.brushSize * pressureScale * imageRect.width
                        / max(1, viewModel.document.canvasSize.width)
                )
            )
        }
    }

    private var sampledBrushSourcePoint: CGPoint? {
        let originalSourcePoint: CGPoint?
        let isSettingSource: Bool
        switch canvasInteractionTool {
        case .cloneStamp:
            originalSourcePoint = viewModel.cloneSourcePoint
            isSettingSource = viewModel.isSettingCloneSource
        case .healingBrush:
            guard viewModel.healingBrushMode == .source else { return nil }
            originalSourcePoint = viewModel.healingSourcePoint
            isSettingSource = viewModel.isSettingHealingSource
        default:
            return nil
        }

        guard !isSettingSource,
              !canvasModifierFlags.contains(.option),
              let strokeStart = dragPoints.first,
              let currentDestination = dragPoints.last
        else { return originalSourcePoint }

        return viewModel.sampledBrushPreviewSourcePoint(
            for: canvasInteractionTool,
            strokeStart: strokeStart,
            currentDestination: currentDestination
        ) ?? originalSourcePoint
    }

    private var isSettingSampledBrushSourceGesture: Bool {
        switch canvasInteractionTool {
        case .cloneStamp:
            return viewModel.isSettingCloneSource || canvasModifierFlags.contains(.option)
        case .healingBrush:
            return viewModel.healingBrushMode == .source
                && (viewModel.isSettingHealingSource || canvasModifierFlags.contains(.option))
        default:
            return false
        }
    }

    private func canvasGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // The selected-object gesture is the fast path, but macOS 13
                // can still route a drag through the drop host instead of the
                // transparent object hit target. Keep the normal canvas move
                // branch as a fallback; when the fast path wins it sets this
                // flag and the branch exits above, so the translation is never
                // applied twice.
                if isSelectedObjectMoveGestureActive {
                    return
                }
                if isCanvasPanGestureActive || canvasInteractionTool == .hand || isSpacebarPanning {
                    isCanvasPanGestureActive = true
                    updateCanvasPan(translation: value.translation)
                    NSCursor.closedHand.set()
                    return
                }

                let pointerImagePoint = imagePoint(from: value.location, in: size)
                let stylusInput = ImageEditorStylusInput.sample(from: NSApp.currentEvent)
                let eventPressure = stylusInput.pressure
                viewModel.updatePointer(pointerImagePoint)

                if canvasInteractionTool == .crop {
                    if activeCropHandle == nil,
                       let startPoint = imagePoint(from: value.startLocation, in: size),
                       beginPendingCropInteraction(at: startPoint, in: size) {
                        updatePendingCropInteraction(at: boundedImagePoint(from: value.location, in: size))
                        return
                    }
                    if activeCropHandle != nil {
                        updatePendingCropInteraction(at: boundedImagePoint(from: value.location, in: size))
                        return
                    }
                }

                switch canvasInteractionTool {
                case .move:
                    if !isObjectMoveGestureActive,
                       !isSelectedObjectMoveGestureActive,
                       layerTransformCursorTarget(
                        at: value.startLocation,
                        in: size
                       ) != nil {
                        // Resize/rotate/reference-point handles own this
                        // sequence. The parent canvas gesture is simultaneous
                        // with them for component drops, so it must explicitly
                        // stand down instead of starting a competing move.
                        return
                    }
                    if !isDeliveryObjectMoveGestureActive,
                       !isCanvasSelectionGestureActive,
                       !isObjectMoveGestureActive,
                       let pressedImagePoint = imagePoint(from: value.startLocation, in: size),
                       beginDeliveryObjectMove(at: pressedImagePoint) {
                        isDeliveryObjectMoveGestureActive = true
                    }
                    if isDeliveryObjectMoveGestureActive {
                        updateDeliveryObjectMove(translation: value.translation, in: size)
                        break
                    }
                    let cloneModifiers = NSEvent.modifierFlags.intersection([.command, .control, .option, .shift])
                    if cloneModifiers == [.option],
                       !isCanvasCloneGestureActive,
                       !isCanvasSelectionGestureActive,
                       !isObjectMoveGestureActive {
                        let pressedImagePoint = imagePoint(from: value.startLocation, in: size)
                        if let pressedImagePoint,
                           viewModel.selectXomoObject(at: pressedImagePoint)
                                || viewModel.selectVisibleLayer(at: pressedImagePoint) {
                            isCanvasCloneGestureActive = true
                            if viewModel.beginDuplicatingSelectedLayerForMove() {
                                resetObjectMoveTracking()
                                isObjectMoveGestureActive = true
                            }
                        }
                    }
                    if isCanvasCloneGestureActive {
                        if isObjectMoveGestureActive {
                            updateObjectMove(translation: value.translation, in: size)
                        }
                        break
                    }
                    let deepSelectionModifiers = NSEvent.modifierFlags.intersection([.command, .control, .option, .shift])
                    if deepSelectionModifiers == [.command],
                       !isCanvasSelectionGestureActive,
                       !isObjectMoveGestureActive {
                        let pressedImagePoint = imagePoint(from: value.startLocation, in: size)
                        if let pressedImagePoint,
                           viewModel.selectDeepestVisibleLayer(at: pressedImagePoint) {
                            // Command-click is a deep-selection gesture, not
                            // a move. Keep the selected child stable until end.
                            isCanvasSelectionGestureActive = true
                        }
                    }
                    if isCanvasSelectionGestureActive {
                        break
                    }
                    if NSEvent.modifierFlags.contains(.shift),
                       !isCanvasSelectionGestureActive,
                       !isObjectMoveGestureActive {
                        let pressedImagePoint = imagePoint(from: value.startLocation, in: size)
                        if let pressedImagePoint,
                           viewModel.selectXomoObject(at: pressedImagePoint, extendingSelection: true)
                                || viewModel.selectVisibleLayer(at: pressedImagePoint, extendingSelection: true) {
                            // Shift-click is a selection gesture, not a move.
                            // Keep it stable while DragGesture emits repeated updates.
                            isCanvasSelectionGestureActive = true
                        }
                    }
                    if isCanvasSelectionGestureActive {
                        break
                    }
                    if !isObjectMoveGestureActive {
                        let pressedImagePoint = imagePoint(from: value.startLocation, in: size)
                        guard let pressedImagePoint,
                              viewModel.selectVisibleLayer(at: pressedImagePoint)
                        else {
                            isCanvasPanGestureActive = true
                            updateCanvasPan(translation: value.translation)
                            NSCursor.closedHand.set()
                            return
                        }
                        guard viewModel.beginMovingSelectedLayer() else { return }
                        resetObjectMoveTracking()
                        isObjectMoveGestureActive = true
                    }
                    updateObjectMove(translation: value.translation, in: size)
                    if isObjectMoveGestureActive {
                        ImageEditorCanvasCursor.objectMoveCursor(
                            isDuplicating: isCanvasCloneGestureActive
                        ).set()
                    }
                case .brush, .eraser, .sponge:
                    if let pointerImagePoint {
                        activeBrushPressure = eventPressure
                        activeBrushTilt = stylusInput.tilt
                        brushStrokeSamples.append(ImageEditorBrushStrokeSample(
                            point: pointerImagePoint,
                            pressure: eventPressure,
                            tilt: stylusInput.tilt
                        ))
                        updateCanvasCursor(at: value.location, in: size)
                    }
                case .dodge, .burn:
                    if let pointerImagePoint {
                        activeBrushPressure = eventPressure
                        activeBrushTilt = stylusInput.tilt
                        dragPoints.append(pointerImagePoint)
                        brushStrokeSamples.append(ImageEditorBrushStrokeSample(
                            point: pointerImagePoint,
                            pressure: eventPressure,
                            tilt: stylusInput.tilt
                        ))
                        updateToneAirbrushStroke(at: pointerImagePoint, pressure: eventPressure)
                        updateCanvasCursor(at: value.location, in: size)
                    }
                case .cloneStamp, .blur, .sharpen, .smudge, .healingBrush:
                    if let pointerImagePoint {
                        activeBrushPressure = isSettingSampledBrushSourceGesture ? nil : eventPressure
                        activeBrushTilt = isSettingSampledBrushSourceGesture ? nil : stylusInput.tilt
                        dragPoints.append(pointerImagePoint)
                        brushStrokeSamples.append(ImageEditorBrushStrokeSample(
                            point: pointerImagePoint,
                            pressure: eventPressure,
                            tilt: stylusInput.tilt
                        ))
                        updateCanvasCursor(at: value.location, in: size)
                    }
                case .marquee:
                    if dragStart == nil {
                        dragStart = pointerImagePoint
                    }
                    if dragStart != nil {
                        dragEnd = boundedImagePoint(from: value.location, in: size)
                    }
                case .crop, .rectangle, .ellipse, .gradient:
                    if canvasInteractionTool == .crop, dragStart == nil {
                        pendingCropRect = nil
                    }
                    if dragStart == nil {
                        dragStart = pointerImagePoint
                    }
                    dragEnd = pointerImagePoint
                case .text:
                    if dragStart == nil {
                        dragStart = imagePoint(from: value.startLocation, in: size)
                    }
                    if dragStart != nil {
                        dragEnd = boundedImagePoint(from: value.location, in: size)
                    }
                case .patchTool:
                    let boundedPoint = boundedImagePoint(from: value.location, in: size)
                    if dragStart == nil, dragPoints.isEmpty {
                        if viewModel.canBeginPatch(at: pointerImagePoint) {
                            dragStart = pointerImagePoint
                            dragEnd = pointerImagePoint
                            isDrawingPatchSelection = false
                        } else {
                            isDrawingPatchSelection = true
                            dragPoints = [boundedPoint]
                        }
                    }
                    if isDrawingPatchSelection {
                        dragPoints.append(boundedPoint)
                    } else if dragStart != nil {
                        dragEnd = pointerImagePoint
                        let updateTime = ProcessInfo.processInfo.systemUptime
                        if patchPreviewImage == nil || updateTime - lastPatchPreviewUpdateTime >= 1.0 / 30.0 {
                            patchPreviewImage = viewModel.patchPreviewImage(
                                from: dragStart,
                                to: pointerImagePoint
                            )
                            lastPatchPreviewUpdateTime = updateTime
                        }
                    }
                case .pen:
                    guard viewModel.pendingPenPathPoints.isEmpty,
                          viewModel.canEditSelectedPathAnchors
                    else { break }
                    if isMovingPathAnchor {
                        viewModel.moveSelectedPathAnchor(to: pointerImagePoint)
                    } else {
                        isMovingPathAnchor = viewModel.beginMovingPathAnchor(at: pointerImagePoint)
                    }
                case .pathSelection:
                    if !isObjectMoveGestureActive,
                       let pressedImagePoint = imagePoint(from: value.startLocation, in: size),
                       viewModel.selectPathLayer(at: pressedImagePoint) {
                        if viewModel.beginMovingSelectedLayer() {
                            resetObjectMoveTracking()
                            isObjectMoveGestureActive = true
                        }
                    }
                    if isObjectMoveGestureActive {
                        updateObjectMove(translation: value.translation, in: size)
                    }
                case .directSelection:
                    if !isMovingPathAnchor {
                        isMovingPathAnchor = viewModel.beginDirectPathAnchorMove(at: pointerImagePoint)
                    } else {
                        viewModel.moveSelectedPathAnchor(to: pointerImagePoint)
                    }
                case .lasso:
                    if dragPoints.isEmpty {
                        if let pointerImagePoint {
                            dragPoints.append(pointerImagePoint)
                        }
                    } else {
                        dragPoints.append(boundedImagePoint(from: value.location, in: size))
                    }
                case .quickSelection:
                    if let pointerImagePoint {
                        dragPoints.append(pointerImagePoint)
                    }
                case .colorSampler:
                    if colorSamplerDrag == nil, !isColorSamplerRemovalGestureActive {
                        let hitID = colorSamplerPointID(
                            at: value.startLocation,
                            in: size
                        )
                        if NSEvent.modifierFlags.contains(.option) {
                            isColorSamplerRemovalGestureActive = true
                            pendingColorSamplerRemovalID = hitID
                        } else if let hitID,
                                  let sample = viewModel.colorSamplerPoints.first(where: {
                                      $0.id == hitID
                                  }) {
                            colorSamplerDrag = ImageEditorColorSamplerDrag(
                                id: hitID,
                                previewPoint: sample.point
                            )
                        }
                    }
                    if var colorSamplerDrag,
                       let previewPoint = imagePoint(from: value.location, in: size) {
                        colorSamplerDrag.previewPoint = previewPoint
                        self.colorSamplerDrag = colorSamplerDrag
                        ImageEditorCanvasCursor.objectMoveCursor().set()
                    }
                default:
                    break
                }
            }
            .onEnded { value in
                if isSelectedObjectMoveGestureActive {
                    // The component gesture commits the move. Keeping this
                    // recognizer out of the end phase prevents it from
                    // clearing the shared state before the commit runs.
                    return
                }
                if isCanvasPanGestureActive {
                    updateCanvasPan(translation: value.translation)
                    isCanvasPanGestureActive = false
                    lastPanTranslation = .zero
                    if isPointerInsideCanvas {
                        updateCanvasCursor(at: value.location, in: size)
                    }
                    return
                }

                let endImagePoint = imagePoint(from: value.location, in: size)
                activeBrushPressure = nil
                activeBrushTilt = nil
                let endStylusInput = ImageEditorStylusInput.sample(from: NSApp.currentEvent)
                let fallbackBrushSamples = [
                    imagePoint(from: value.startLocation, in: size),
                    endImagePoint
                ].compactMap { $0 }.map {
                    ImageEditorBrushStrokeSample(
                        point: $0,
                        pressure: endStylusInput.pressure,
                        tilt: endStylusInput.tilt
                    )
                }
                let committedBrushSamples = brushStrokeSamples.count >= 2
                    ? brushStrokeSamples
                    : fallbackBrushSamples

                if activeCropHandle != nil {
                    endPendingCropInteraction()
                    dragStart = nil
                    dragEnd = nil
                    resetObjectMoveTracking()
                    return
                }

                if isCanvasSelectionGestureActive {
                    isCanvasSelectionGestureActive = false
                    dragPoints = []
                    brushStrokeSamples = []
                    dragStart = nil
                    dragEnd = nil
                    lastPanTranslation = .zero
                    resetObjectMoveTracking()
                    isObjectMoveGestureActive = false
                    isCanvasCloneGestureActive = false
                    isSelectedObjectMoveGestureActive = false
                    return
                }

                switch canvasInteractionTool {
                case .move:
                    if isDeliveryObjectMoveGestureActive {
                        updateDeliveryObjectMove(translation: value.translation, in: size)
                        finishDeliveryObjectMove()
                        isDeliveryObjectMoveGestureActive = false
                        break
                    }
                    if isObjectMoveGestureActive {
                        updateObjectMove(translation: value.translation, in: size)
                        viewModel.finishMovingSelectedLayer()
                    }
                case .marquee:
                    if let dragStart {
                        viewModel.createMarqueeSelection(
                            from: dragStart,
                            to: boundedImagePoint(from: value.location, in: size)
                        )
                    }
                case .lasso:
                    if !dragPoints.isEmpty {
                        dragPoints.append(boundedImagePoint(from: value.location, in: size))
                    }
                    viewModel.createLassoSelection(points: dragPoints)
                case .magicWand:
                    viewModel.createMagicSelection(at: endImagePoint)
                case .quickSelection:
                    viewModel.createQuickSelection(points: dragPoints)
                case .brush:
                    viewModel.drawBrush(samples: committedBrushSamples)
                case .eraser:
                    viewModel.drawBrush(samples: committedBrushSamples, erase: true)
                case .cloneStamp:
                    if viewModel.isSettingCloneSource || NSEvent.modifierFlags.contains(.option), let endImagePoint {
                        viewModel.setCloneSource(at: endImagePoint)
                    } else {
                        viewModel.cloneStamp(samples: brushStrokeSamples)
                    }
                case .dodge:
                    viewModel.toneBrush(
                        samples: brushStrokeSamples,
                        burn: false,
                        airbrushPulseSamples: finishToneAirbrushStroke(at: endImagePoint)
                    )
                case .burn:
                    viewModel.toneBrush(
                        samples: brushStrokeSamples,
                        burn: true,
                        airbrushPulseSamples: finishToneAirbrushStroke(at: endImagePoint)
                    )
                case .sponge:
                    viewModel.spongeBrush(samples: brushStrokeSamples)
                case .blur:
                    viewModel.blurBrush(samples: brushStrokeSamples)
                case .sharpen:
                    viewModel.sharpenBrush(samples: brushStrokeSamples)
                case .smudge:
                    viewModel.smudgeBrush(samples: brushStrokeSamples)
                case .healingBrush:
                    if viewModel.healingBrushMode == .source,
                       (viewModel.isSettingHealingSource || NSEvent.modifierFlags.contains(.option)),
                       let endImagePoint {
                        viewModel.setHealingSource(at: endImagePoint)
                    } else {
                        viewModel.healingBrush(samples: brushStrokeSamples)
                    }
                case .patchTool:
                    if isDrawingPatchSelection {
                        dragPoints.append(boundedImagePoint(from: value.location, in: size))
                        viewModel.createPatchSelection(points: dragPoints)
                    } else {
                        viewModel.patchSelection(from: dragStart, to: endImagePoint)
                    }
                case .redEye:
                    viewModel.reduceRedEye(at: endImagePoint)
                case .paintBucket:
                    viewModel.paintBucketFill(at: endImagePoint)
                case .rectangle:
                    if let dragStart, let endImagePoint {
                        viewModel.drawShape(from: dragStart, to: endImagePoint, ellipse: false)
                    }
                case .ellipse:
                    if let dragStart, let endImagePoint {
                        viewModel.drawShape(from: dragStart, to: endImagePoint, ellipse: true)
                    }
                case .pen:
                    if isMovingPathAnchor {
                        viewModel.finishMovingPathAnchor()
                    } else {
                        viewModel.addPenPoint(endImagePoint)
                    }
                case .pathSelection:
                    if isObjectMoveGestureActive {
                        updateObjectMove(translation: value.translation, in: size)
                        viewModel.finishMovingSelectedLayer()
                    }
                case .directSelection:
                    if isMovingPathAnchor {
                        viewModel.finishMovingPathAnchor()
                    }
                case .crop:
                    if let dragStart, let endImagePoint {
                        let rect = CGRect(
                            x: min(dragStart.x, endImagePoint.x),
                            y: min(dragStart.y, endImagePoint.y),
                            width: abs(endImagePoint.x - dragStart.x),
                            height: abs(endImagePoint.y - dragStart.y)
                        )
                        if rect.width > 3, rect.height > 3 {
                            pendingCropRect = rect
                        }
                    }
                case .text:
                    if let paragraphRect = ImageEditorTextBoxGeometry.paragraphRect(
                        from: dragStart,
                        to: dragEnd,
                        viewTranslation: value.translation
                    ) {
                        beginCanvasParagraphTextEditing(in: paragraphRect)
                    } else {
                        beginCanvasTextEditing(at: endImagePoint)
                    }
                case .eyedropper:
                    if let endImagePoint {
                        viewModel.sampleColor(at: endImagePoint)
                    }
                case .colorSampler:
                    if isColorSamplerRemovalGestureActive {
                        if let pendingColorSamplerRemovalID,
                           colorSamplerPointID(
                               at: value.location,
                               in: size
                           ) == pendingColorSamplerRemovalID {
                            viewModel.removeColorSampler(id: pendingColorSamplerRemovalID)
                        }
                    } else if let colorSamplerDrag {
                        viewModel.moveColorSampler(
                            id: colorSamplerDrag.id,
                            to: colorSamplerDrag.previewPoint
                        )
                    } else if let endImagePoint {
                        viewModel.addColorSampler(at: endImagePoint)
                    }
                case .gradient:
                    viewModel.drawGradient(from: dragStart, to: endImagePoint)
                case .zoom:
                    switch ImageEditorZoomDirection.from(modifierFlags: canvasModifierFlags) {
                    case .zoomIn:
                        viewModel.zoomIn()
                    case .zoomOut:
                        viewModel.zoomOut()
                    }
                default:
                    break
                }

                dragPoints = []
                brushStrokeSamples = []
                activeBrushPressure = nil
                toneAirbrushStroke.reset()
                dragStart = nil
                dragEnd = nil
                patchPreviewImage = nil
                isDrawingPatchSelection = false
                lastPatchPreviewUpdateTime = 0
                lastPanTranslation = .zero
                resetObjectMoveTracking()
                isObjectMoveGestureActive = false
                isCanvasCloneGestureActive = false
                isSelectedObjectMoveGestureActive = false
                isDeliveryObjectMoveGestureActive = false
                deliveryDrag = nil
                resetColorSamplerGesture()
                isMovingPathAnchor = false
                activeResizeHandle = nil
                refreshCanvasCursor(in: size)
            }
    }

    private func updateCanvasPan(translation: CGSize) {
        let delta = CGSize(
            width: translation.width - lastPanTranslation.width,
            height: translation.height - lastPanTranslation.height
        )
        viewModel.nudgeCanvas(by: delta)
        lastPanTranslation = translation
    }

    @discardableResult
    private func beginPendingCropInteraction(at point: CGPoint, in size: CGSize) -> Bool {
        guard let pendingCropRect,
              let handle = ImageEditorCropGeometry.hitHandle(
                  at: point,
                  in: pendingCropRect,
                  tolerance: cropHitTolerance(in: size)
              )
        else { return false }
        activeCropHandle = handle
        cropInteractionStartPoint = point
        cropInteractionOriginalRect = pendingCropRect
        return true
    }

    private func updatePendingCropInteraction(at point: CGPoint) {
        guard let activeCropHandle,
              let startPoint = cropInteractionStartPoint,
              let originalRect = cropInteractionOriginalRect
        else { return }
        pendingCropRect = ImageEditorCropGeometry.adjustedFrame(
            from: originalRect,
            handle: activeCropHandle,
            delta: CGSize(width: point.x - startPoint.x, height: point.y - startPoint.y),
            canvasSize: viewModel.document.canvasSize
        )
    }

    private func endPendingCropInteraction() {
        activeCropHandle = nil
        cropInteractionStartPoint = nil
        cropInteractionOriginalRect = nil
    }

    private func cropHitTolerance(in size: CGSize) -> CGFloat {
        let imageRect = fittedImageRect(in: size)
        let displayScale = imageRect.width / max(viewModel.document.canvasSize.width, 1)
        return max(6, 10 / max(displayScale, 0.01))
    }

    private func updateObjectMove(translation: CGSize, in size: CGSize) {
        let imageRect = fittedImageRect(in: size)
        guard imageRect.width > 0, imageRect.height > 0 else { return }
        let resolvedAxis = ImageEditorObjectDragConstraint.resolvedAxis(
            for: translation,
            existingAxis: objectMoveAxisLock,
            isConstrained: NSEvent.modifierFlags.contains(.shift)
        )
        let viewDelta = ImageEditorObjectDragConstraint.incrementalDelta(
            currentTranslation: translation,
            previousTranslation: lastMoveTranslation,
            axis: resolvedAxis
        )
        objectMoveAxisLock = resolvedAxis
        viewModel.moveSelectedLayer(
            by: ImageEditorCanvasDragGeometry.imageDelta(
                from: viewDelta,
                canvasSize: viewModel.document.canvasSize,
                imageRect: imageRect
            ),
            snapping: true,
            constrainingTo: resolvedAxis
        )
        lastMoveTranslation = translation
    }

    private func resetObjectMoveTracking() {
        lastMoveTranslation = .zero
        objectMoveAxisLock = nil
    }

    private func fontFamilyPicker(width: CGFloat? = nil) -> some View {
        Picker(L10n.text("imageEditor.properties.fontFamily"), selection: $viewModel.selectedFontFamilyName) {
            ForEach(viewModel.availableFontFamilyNames, id: \.self) { family in
                Text(viewModel.fontFamilyDisplayName(family)).tag(family)
            }
        }
        .labelsHidden()
        .environment(\.colorScheme, .dark)
        .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
        .frame(width: width)
        .focusable(false)
        .accessibilityLabel(L10n.text("imageEditor.properties.fontFamily"))
        .accessibilityIdentifier("image-editor-font-family")
    }

    @ViewBuilder
    private func canvasTextEditingOverlay(in size: CGSize) -> some View {
        if let origin = canvasTextEditingOrigin {
            let imageRect = fittedImageRect(in: size)
            let displayScale = imageRect.width / max(viewModel.document.canvasSize.width, 1)
            let selectedFrame = canvasTextEditingLayerID.flatMap { id in
                viewModel.document.layers.first(where: { $0.id == id })?.frame
            }
            let editorWidth = canvasTextEditingFrame.map { max(24, $0.width * displayScale) }
                ?? max(160, (selectedFrame?.width ?? max(240, CGFloat(viewModel.textBoxWidth))) * displayScale)
            let editorHeight = canvasTextEditingFrame.map { max(24, $0.height * displayScale) }
                ?? max(64, (selectedFrame?.height ?? 72) * displayScale)
            let position = viewPoint(from: origin, in: size)

            VStack(alignment: .trailing, spacing: 4) {
                TextEditor(text: $viewModel.textValue)
                    .font(.custom(viewModel.selectedFontFamilyName, size: max(6, viewModel.textSize * displayScale)))
                    .foregroundStyle(Color(nsColor: viewModel.foregroundColor))
                    .xomoScrollContentBackgroundHidden()
                    .padding(2)
                    .frame(width: editorWidth, height: editorHeight)
                    .background(Color(nsColor: ImageEditorTheme.panelRaised).opacity(0.16))
                    .overlay {
                        Rectangle()
                            .stroke(Color.gray.opacity(0.78), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    }
                    .focused($isCanvasTextEditorFocused)
                    .accessibilityIdentifier("image-editor-canvas-text-editor")

                HStack(spacing: 4) {
                    Button { cancelCanvasTextEditing() } label: {
                        Image(systemName: "xmark")
                    }
                    Button { commitCanvasTextEditing() } label: {
                        Image(systemName: "checkmark")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
            .position(x: position.x + editorWidth / 2, y: position.y + editorHeight / 2)
            .zIndex(20)
        }
    }

    private func beginCanvasTextEditing(at point: CGPoint?) {
        guard let point else { return }
        var excludedLayerID: UUID?
        if canvasTextEditingOrigin != nil {
            commitCanvasTextEditing()
            excludedLayerID = viewModel.document.selectedLayerID
        }
        startCanvasTextEditing(at: point, excluding: excludedLayerID)
    }

    private func beginCanvasParagraphTextEditing(in frame: CGRect) {
        if canvasTextEditingOrigin != nil {
            commitCanvasTextEditing()
        }
        let contentSize = ImageEditorTextBoxGeometry.contentSize(for: frame)
        viewModel.textValue = ""
        viewModel.textBoxWidth = Double(contentSize.width)
        viewModel.textBoxHeight = Double(contentSize.height)
        canvasTextEditingLayerID = nil
        canvasTextEditingOrigin = frame.origin
        canvasTextEditingFrame = frame
        DispatchQueue.main.async { isCanvasTextEditorFocused = true }
    }

    private func startCanvasTextEditing(at point: CGPoint, excluding excludedLayerID: UUID? = nil) {
        if viewModel.selectEditableTextLayer(at: point, excluding: excludedLayerID),
           let layer = viewModel.document.selectedLayer {
            canvasTextEditingLayerID = layer.id
            canvasTextEditingOrigin = layer.frame.origin
            canvasTextEditingFrame = nil
        } else {
            viewModel.textValue = ""
            viewModel.textBoxWidth = 0
            viewModel.textBoxHeight = 0
            canvasTextEditingLayerID = nil
            canvasTextEditingOrigin = point
            canvasTextEditingFrame = nil
        }
        DispatchQueue.main.async { isCanvasTextEditorFocused = true }
    }

    private func commitCanvasTextEditing() {
        if canvasTextEditingLayerID != nil {
            viewModel.updateSelectedTextLayer()
        } else {
            viewModel.addText(at: canvasTextEditingOrigin)
        }
        canvasTextEditingOrigin = nil
        canvasTextEditingLayerID = nil
        canvasTextEditingFrame = nil
        isCanvasTextEditorFocused = false
    }

    private func cancelCanvasTextEditing() {
        canvasTextEditingOrigin = nil
        canvasTextEditingLayerID = nil
        canvasTextEditingFrame = nil
        isCanvasTextEditorFocused = false
    }

    private func fittedImageRect(in size: CGSize) -> CGRect {
        ImageEditorCanvasGeometry.fittedImageRect(
            canvasSize: viewModel.document.canvasSize,
            viewportSize: size,
            zoom: viewModel.zoom,
            canvasOffset: viewModel.canvasOffset
        )
    }

    private func updateCanvasCursor(at viewPoint: CGPoint, in size: CGSize) {
        let canvasPoint = imagePoint(from: viewPoint, in: size)
        viewModel.updatePointer(canvasPoint)
        let imageRect = fittedImageRect(in: size)
        let displayScale = imageRect.width / max(viewModel.document.canvasSize.width, 1)
        let contentHit = canvasPoint.map(viewModel.canvasContentHit(at:)) ?? .none
        let displayedBrushDiameter = ImageEditorCanvasCursor.pressureAdjustedBrushDiameter(
            baseDiameter: viewModel.brushSize * displayScale,
            tool: canvasInteractionTool,
            pressure: activeBrushPressure,
            brushPressureControlsSize: viewModel.brushPressureControlsSize,
            retouchPressureControlsSize: viewModel.retouchPressureControlsSize,
            brushPressureSensitivity: viewModel.brushPressureSensitivity / 100,
            brushMinimumDiameter: viewModel.brushMinimumDiameter / 100,
            retouchPressureSensitivity: viewModel.retouchPressureSensitivity / 100
        )
        ImageEditorCanvasCursor.cursor(
            for: viewModel.selectedLeftSidebarTab,
            selectedTool: viewModel.selectedTool,
            brushDiameter: displayedBrushDiameter,
            brushTilt: activeBrushTilt,
            brushTiltControlsShape: viewModel.brushTiltControlsShape,
            brushTipRoundness: viewModel.brushTipRoundness / 100,
            brushTipAngleDegrees: viewModel.brushTipAngleDegrees,
            isPointerOverCanvas: canvasPoint != nil,
            isPointerOverMovableContent: contentHit.isMovable,
            isPointerOverBlockedContent: contentHit.isBlocked,
            isPointerOverColorSamplerPoint:
                canvasInteractionTool == .colorSampler
                    && colorSamplerPointID(at: viewPoint, in: size) != nil,
            penIsClosing: canvasInteractionTool == .pen && viewModel.isPenCloseCandidate(at: canvasPoint),
            handIsDragging: isCanvasPanGestureActive,
            isObjectMoveGestureActive: isSelectedObjectMoveGestureActive || isObjectMoveGestureActive,
            isColorSamplerMoveGestureActive: colorSamplerDrag != nil,
            isSpacebarPanning: isSpacebarPanning,
            isCanvasPanGestureActive: isCanvasPanGestureActive,
            modifierFlags: NSEvent.modifierFlags,
            marqueeShape: viewModel.marqueeShape,
            cropHandle: cropInteractionHandle(at: viewPoint, in: size),
            layerTransformTarget: layerTransformCursorTarget(at: viewPoint, in: size)
        ).set()
    }

    private func refreshCanvasCursor(in size: CGSize) {
        guard isPointerInsideCanvas else { return }
        if let hoverViewPoint {
            updateCanvasCursor(at: hoverViewPoint, in: size)
            return
        }

        // macOS 13's SwiftUI hover callback may report entry before the
        // AppKit bridge has delivered the first pointer coordinate.  Do not
        // guess that the pointer is over an editable object: a stale brush or
        // move cursor is more misleading than a brief native arrow.
        ImageEditorCanvasCursor.cursor(
            for: viewModel.selectedLeftSidebarTab,
            selectedTool: viewModel.selectedTool,
            brushDiameter: viewModel.brushSize,
            isPointerOverCanvas: false,
            isPointerOverMovableContent: false,
            handIsDragging: isCanvasPanGestureActive,
            isObjectMoveGestureActive: isSelectedObjectMoveGestureActive || isObjectMoveGestureActive,
            isColorSamplerMoveGestureActive: colorSamplerDrag != nil,
            isSpacebarPanning: isSpacebarPanning,
            isCanvasPanGestureActive: isCanvasPanGestureActive,
            modifierFlags: canvasModifierFlags,
            marqueeShape: viewModel.marqueeShape,
            cropHandle: nil,
            layerTransformTarget: layerTransformCursorTarget(at: nil, in: size)
        ).set()
    }

    private func layerTransformCursorTarget(
        at viewPoint: CGPoint?,
        in size: CGSize
    ) -> ImageEditorLayerTransformCursorTarget? {
        var hoveredTarget: ImageEditorLayerTransformCursorTarget?
        if canvasInteractionTool == .move,
           ImageEditorLayerTransformControlLayout.showsControls(
               areExtrasVisible: viewModel.document.areExtrasVisible,
               areTransformControlsVisible: viewModel.document.areTransformControlsVisible,
               hasSelectedXomoObject: viewModel.hasSelectedXomoObject
           ),
           let layerFrame = viewModel.selectedLayerTransformFrame {
            hoveredTarget = ImageEditorCanvasCursor.transformTarget(
                at: viewPoint,
                frame: viewRect(from: layerFrame, in: size),
                canResize: viewModel.canResizeSelectedLayer,
                canRotate: viewModel.canRotateSelectedLayer,
                referencePoint: viewModel.selectedLayerTransformReferencePoint.map {
                    self.viewPoint(from: $0, in: size)
                },
                canMoveReferencePoint: viewModel.canRotateSelectedLayer
            )
        }
        return ImageEditorCanvasCursor.resolvedTransformTarget(
            hoveredTarget: hoveredTarget,
            activeResizeHandle: activeResizeHandle,
            isRotating: isRotatingLayer,
            isMovingReferencePoint: isMovingTransformReferencePoint
        )
    }

    private func cropInteractionHandle(at viewPoint: CGPoint?, in size: CGSize) -> ImageEditorCropHandle? {
        guard canvasInteractionTool == .crop,
              let pendingCropRect,
              let viewPoint,
              let imagePoint = imagePoint(from: viewPoint, in: size)
        else { return nil }
        return ImageEditorCropGeometry.hitHandle(
            at: imagePoint,
            in: pendingCropRect,
            tolerance: cropHitTolerance(in: size)
        )
    }

    private var canvasInteractionTool: ImageEditorTool {
        ImageEditorStylusToolOverride.effectiveTool(
            baseTool: viewModel.canvasInteractionTool,
            sidebarTab: viewModel.selectedLeftSidebarTab,
            isEraserInProximity: stylusProximity.isEraser
        )
    }

    private func imagePoint(from viewPoint: CGPoint, in size: CGSize) -> CGPoint? {
        let rect = fittedImageRect(in: size)
        return ImageEditorCanvasGeometry.imagePoint(
            from: viewPoint,
            imageRect: rect,
            canvasSize: viewModel.document.canvasSize
        )
    }

    private func unboundedImagePoint(from viewPoint: CGPoint, in size: CGSize) -> CGPoint {
        let rect = fittedImageRect(in: size)
        return ImageEditorCanvasGeometry.unboundedImagePoint(
            from: viewPoint,
            imageRect: rect,
            canvasSize: viewModel.document.canvasSize
        )
    }

    private func boundedImagePoint(from viewPoint: CGPoint, in size: CGSize) -> CGPoint {
        let rect = fittedImageRect(in: size)
        return ImageEditorCanvasGeometry.boundedImagePoint(
            from: viewPoint,
            imageRect: rect,
            canvasSize: viewModel.document.canvasSize
        )
    }

    private func viewPoint(from imagePoint: CGPoint, in size: CGSize) -> CGPoint {
        let rect = fittedImageRect(in: size)
        return ImageEditorCanvasGeometry.viewPoint(
            from: imagePoint,
            imageRect: rect,
            canvasSize: viewModel.document.canvasSize
        )
    }

    private func selectedPathAnchorOverlayPoints(
        in size: CGSize
    ) -> [(subpathIndex: Int, index: Int, anchor: CGPoint, inHandle: CGPoint?, outHandle: CGPoint?)]? {
        guard let layer = viewModel.document.selectedLayer,
              let content = layer.shapeContent,
              content.kind == .path
        else { return nil }
        return content.allEditablePathSubpaths.enumerated().flatMap { subpathIndex, anchors in
            anchors.enumerated().map { index, anchor in
                (
                    subpathIndex: subpathIndex,
                    index: index,
                    anchor: viewPoint(from: canvasPoint(anchor.point, layer: layer), in: size),
                    inHandle: anchor.inControl.map { viewPoint(from: canvasPoint($0, layer: layer), in: size) },
                    outHandle: anchor.outControl.map { viewPoint(from: canvasPoint($0, layer: layer), in: size) }
                )
            }
        }
    }

    private func canvasPoint(_ localPoint: CGPoint, layer: ImageEditorLayer) -> CGPoint {
        CGPoint(x: layer.frame.minX + localPoint.x, y: layer.frame.minY + localPoint.y)
    }

    private var rightDock: some View {
        ScrollView {
            VStack(spacing: 8) {
                if viewModel.isLayersPanelVisible {
                    EditorDockDisclosure(
                        title: L10n.text("imageEditor.panel.layersChannels"),
                        systemImage: "square.3.layers.3d",
                        isExpanded: $isLayersDockExpanded
                    ) {
                        layersPanel(showsTitle: false)
                    }
                }

                if viewModel.isNavigatorPanelVisible {
                    EditorDockDisclosure(
                        title: L10n.text("imageEditor.panel.navigator"),
                        systemImage: "scope",
                        isExpanded: $isNavigatorDockExpanded
                    ) {
                        navigatorPanel(showsTitle: false)
                    }
                }

                if viewModel.isHistoryPanelVisible {
                    EditorDockDisclosure(
                        title: L10n.text("imageEditor.panel.history"),
                        systemImage: "clock",
                        isExpanded: $isHistoryDockExpanded
                    ) {
                        historyPanel(showsTitle: false)
                    }
                }

                if viewModel.isPropertiesPanelVisible {
                    EditorDockDisclosure(
                        title: L10n.text("imageEditor.properties.filter"),
                        systemImage: "camera.filters",
                        isExpanded: $isFiltersDockExpanded
                    ) {
                        filtersQuickPanel
                    }
                }

                if viewModel.isPropertiesPanelVisible {
                    EditorDockDisclosure(
                        title: L10n.text("imageEditor.panel.properties"),
                        systemImage: "slider.horizontal.3",
                        isExpanded: $isPropertiesDockExpanded
                    ) {
                        propertiesPanel(showsTitle: false)
                    }
                }

                if viewModel.isHotspotsPanelVisible {
                    EditorDockDisclosure(
                        title: L10n.text("imageEditor.panel.hotspots"),
                        systemImage: "scope",
                        isExpanded: $isHotspotsDockExpanded
                    ) {
                        ImageEditorHotspotPanel(viewModel: viewModel, showsTitle: false)
                    }
                }

                if viewModel.isSlicesPanelVisible {
                    EditorDockDisclosure(
                        title: L10n.text("imageEditor.panel.slices"),
                        systemImage: "rectangle.dashed",
                        isExpanded: $isSlicesDockExpanded
                    ) {
                        ImageEditorSlicePanel(viewModel: viewModel, showsTitle: false)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(8)
        }
        .frame(width: imageEditorRightDockWidth)
        .clipped()
        .background(Color(nsColor: ImageEditorTheme.panel))
        .accessibilityIdentifier("image-editor-right-dock")
    }

    private func navigatorPanel(showsTitle: Bool = true) -> some View {
        let histogramSummary = viewModel.histogramSummary
        return EditorPanel(title: L10n.text("imageEditor.panel.navigator"), showsTitle: showsTitle) {
            VStack(alignment: .leading, spacing: 8) {
                navigatorPreview
                histogramView(summary: histogramSummary)
                Text(viewModel.sizeText)
                Text(viewModel.selectionBoundsInfoText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .accessibilityIdentifier("image-editor-info-selection-bounds")
                Text(viewModel.selectedObjectBoundsInfoText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .accessibilityIdentifier("image-editor-info-object-bounds")
                Text(viewModel.pointerColorInfoText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .accessibilityIdentifier("image-editor-info-pointer-color")
                Text(viewModel.selectedHistogramChannelAverageText(for: histogramSummary))
                Text(viewModel.selectedHistogramStatisticsText(for: histogramSummary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(viewModel.histogramPixelCountText(for: histogramSummary))
                    .lineLimit(1)
                Text(viewModel.histogramClippingText(for: histogramSummary))
                Divider()
                    .overlay(Color.white.opacity(0.12))
                HStack(spacing: 6) {
                    Text(L10n.text("imageEditor.info.colorSamplers"))
                        .fontWeight(.semibold)
                    Spacer()
                    ForEach(ImageEditorColorSamplerReadoutMode.allCases) { mode in
                        Button(mode.shortTitle) {
                            viewModel.selectedColorSamplerReadoutMode = mode
                        }
                        .buttonStyle(EditorSegmentButtonStyle(
                            isSelected: viewModel.selectedColorSamplerReadoutMode == mode
                        ))
                        .focusable(false)
                        .xomoFocusEffectDisabled()
                        .help(mode.title)
                        .accessibilityLabel(mode.title)
                        .accessibilityIdentifier(
                            "image-editor-info-color-sampler-mode-\(mode.rawValue)"
                        )
                    }
                    Button {
                        viewModel.clearColorSamplers()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .buttonStyle(EditorIconButtonStyle(isSelected: false))
                    .focusable(false)
                    .xomoFocusEffectDisabled()
                    .disabled(viewModel.colorSamplerPoints.isEmpty)
                    .help(L10n.text("imageEditor.action.colorSamplerClear"))
                    .accessibilityLabel(L10n.text("imageEditor.action.colorSamplerClear"))
                    .accessibilityIdentifier("image-editor-info-clear-color-samplers")
                }
                HStack(spacing: 6) {
                    Text(L10n.text("imageEditor.info.colorSampler.source"))
                    Spacer()
                    ForEach(ImageEditorColorSamplerSource.allCases) { source in
                        Button(source.shortTitle) {
                            viewModel.selectColorSamplerSource(source)
                        }
                        .buttonStyle(EditorSegmentButtonStyle(
                            isSelected: viewModel.activeColorSamplerSource == source
                        ))
                        .disabled(!viewModel.canSampleColorSamplerSource(source))
                        .focusable(false)
                        .xomoFocusEffectDisabled()
                        .help(source.title)
                        .accessibilityLabel(source.title)
                        .accessibilityIdentifier(
                            "image-editor-info-color-sampler-source-\(source.rawValue)"
                        )
                    }
                }
                HStack(spacing: 6) {
                    Text(L10n.text("imageEditor.info.colorSampler.sampleSize"))
                    Spacer()
                    ForEach(ImageEditorColorSamplerSampleSize.allCases) { sampleSize in
                        Button(sampleSize.shortTitle) {
                            viewModel.selectColorSamplerSampleSize(sampleSize)
                        }
                        .buttonStyle(EditorSegmentButtonStyle(
                            isSelected: viewModel.selectedColorSamplerSampleSize == sampleSize
                        ))
                        .focusable(false)
                        .xomoFocusEffectDisabled()
                        .help(sampleSize.title)
                        .accessibilityLabel(sampleSize.title)
                        .accessibilityIdentifier(
                            "image-editor-info-color-sampler-size-\(sampleSize.rawValue)"
                        )
                    }
                }
                if viewModel.colorSamplerPoints.isEmpty {
                    Text(L10n.text("imageEditor.info.colorSamplers.empty"))
                        .foregroundStyle(Color(nsColor: ImageEditorTheme.menuMutedText))
                } else {
                    ForEach(
                        Array(viewModel.colorSamplerPoints.enumerated()),
                        id: \.element.id
                    ) { index, sample in
                        HStack(spacing: 5) {
                            Circle()
                                .fill(Color(nsColor: sample.color))
                                .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 1))
                                .frame(width: 9, height: 9)
                            Text(viewModel.colorSamplerInfoText(index: index, sample: sample))
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                        .accessibilityIdentifier("image-editor-info-color-sampler-\(index + 1)")
                    }
                }
            }
            .font(.system(size: 11, weight: .medium).monospacedDigit())
            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
        }
        .frame(
            height: (showsTitle ? 474 : 438)
                + CGFloat(viewModel.colorSamplerPoints.count * 16)
        )
        .accessibilityIdentifier("image-editor-navigator-panel")
    }

    private var navigatorPreview: some View {
        GeometryReader { geometry in
            let previewBounds = CGRect(origin: .zero, size: geometry.size)
            let thumbnailRect = ImageEditorCanvasGeometry.aspectFitRect(
                contentSize: viewModel.document.canvasSize,
                in: previewBounds
            )
            let viewportRect = ImageEditorCanvasGeometry.navigatorViewportRect(
                canvasSize: viewModel.document.canvasSize,
                canvasViewportSize: viewModel.canvasViewportSize,
                zoom: viewModel.zoom,
                canvasOffset: viewModel.canvasOffset,
                previewBounds: previewBounds
            )

            ZStack {
                Image(nsImage: viewModel.previewImage)
                    .resizable()
                    .scaledToFit()
                if let viewportRect {
                    Rectangle()
                        .fill(Color(nsColor: ImageEditorTheme.selected).opacity(0.14))
                        .overlay {
                            Rectangle()
                                .stroke(
                                    Color(nsColor: ImageEditorTheme.selected),
                                    style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                                )
                        }
                        .frame(width: viewportRect.width, height: viewportRect.height)
                        .position(x: viewportRect.midX, y: viewportRect.midY)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.22))
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard let imagePoint = navigatorImagePoint(
                            at: value.location,
                            in: thumbnailRect
                        ) else { return }
                        viewModel.centerCanvas(on: imagePoint)
                    }
            )
            .accessibilityIdentifier("image-editor-navigator-preview")
            .accessibilityLabel(L10n.text("imageEditor.navigator.preview"))
        }
        .frame(height: 92)
    }

    private func navigatorImagePoint(at point: CGPoint, in thumbnailRect: CGRect) -> CGPoint? {
        guard thumbnailRect.width > 0,
              thumbnailRect.height > 0,
              thumbnailRect.contains(point)
        else { return nil }
        return CGPoint(
            x: (point.x - thumbnailRect.minX) / thumbnailRect.width * viewModel.document.canvasSize.width,
            y: (point.y - thumbnailRect.minY) / thumbnailRect.height * viewModel.document.canvasSize.height
        )
    }

    private func histogramView(summary: ImageEditorHistogramSummary) -> some View {
        let selectedRange = histogramSelectedBinRange
        return VStack(alignment: .leading, spacing: 4) {
            Text(L10n.text("imageEditor.histogram.title"))
                .font(.system(size: 10, weight: .semibold))
            HStack(spacing: 4) {
                ForEach(ImageEditorHistogramSource.allCases) { source in
                    Button(source.shortTitle) {
                        viewModel.selectedHistogramSource = source
                    }
                    .buttonStyle(EditorSegmentButtonStyle(
                        isSelected: viewModel.activeHistogramSource == source
                    ))
                    .focusable(false)
                    .xomoFocusEffectDisabled()
                    .disabled(!viewModel.canInspectHistogramSource(source))
                    .help(source.title)
                    .accessibilityLabel(source.title)
                    .accessibilityIdentifier("image-editor-histogram-source-\(source.rawValue)")
                }
            }
            HStack(spacing: 4) {
                ForEach(ImageEditorHistogramChannel.allCases) { channel in
                    Button(channel.shortTitle) {
                        viewModel.selectedHistogramChannel = channel
                    }
                    .buttonStyle(EditorSegmentButtonStyle(
                        isSelected: viewModel.selectedHistogramChannel == channel
                    ))
                    .focusable(false)
                    .xomoFocusEffectDisabled()
                    .help(channel.title)
                    .accessibilityLabel(channel.title)
                    .accessibilityIdentifier("image-editor-histogram-channel-\(channel.rawValue)")
                }
            }
            GeometryReader { geometry in
                HStack(alignment: .bottom, spacing: 1) {
                    ForEach(summary.bins) { bin in
                        ZStack(alignment: .bottom) {
                            histogramBars(for: bin)
                        }
                        .frame(maxWidth: .infinity, minHeight: 38, maxHeight: 38, alignment: .bottom)
                        .background(
                            selectedRange?.contains(bin.index) == true
                                ? Color(nsColor: ImageEditorTheme.selected).opacity(0.24)
                                : histogramProbeBinIndex == bin.index
                                    ? Color(nsColor: ImageEditorTheme.selected).opacity(0.16)
                                    : Color.clear
                        )
                        .contentShape(Rectangle())
                        .onHover { isHovering in
                            if isHovering {
                                histogramProbeBinIndex = bin.index
                            } else if histogramProbeBinIndex == bin.index {
                                histogramProbeBinIndex = nil
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
                .gesture(histogramRangeGesture(
                    summary: summary,
                    plotWidth: geometry.size.width
                ))
            }
            .frame(height: 40)
            .background(Color.black.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .accessibilityLabel(L10n.text("imageEditor.histogram.title"))
            Text(viewModel.histogramProbeText(
                for: summary,
                binIndex: histogramProbeBinIndex,
                selectedRange: selectedRange
            ))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .accessibilityIdentifier("image-editor-histogram-probe")
        }
    }

    private var histogramSelectedBinRange: ClosedRange<Int>? {
        guard let anchor = histogramRangeAnchorBinIndex,
              let end = histogramRangeEndBinIndex
        else { return nil }
        return min(anchor, end)...max(anchor, end)
    }

    private func histogramRangeGesture(
        summary: ImageEditorHistogramSummary,
        plotWidth: CGFloat
    ) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard let binIndex = summary.binIndex(
                    atX: value.location.x,
                    plotWidth: plotWidth
                ) else { return }
                if !isHistogramRangeDragging {
                    histogramRangeAnchorBinIndex = binIndex
                    isHistogramRangeDragging = true
                }
                histogramRangeEndBinIndex = binIndex
                histogramProbeBinIndex = binIndex
            }
            .onEnded { value in
                guard let binIndex = summary.binIndex(
                    atX: value.location.x,
                    plotWidth: plotWidth
                ) else { return }
                histogramRangeEndBinIndex = binIndex
                histogramProbeBinIndex = binIndex
                isHistogramRangeDragging = false
            }
    }

    @ViewBuilder
    private func histogramBars(for bin: ImageEditorHistogramBin) -> some View {
        switch viewModel.selectedHistogramChannel {
        case .rgb:
            Rectangle()
                .fill(Color.red.opacity(0.55))
                .frame(height: max(1, 38 * bin.red))
            Rectangle()
                .fill(Color.green.opacity(0.45))
                .frame(height: max(1, 38 * bin.green))
            Rectangle()
                .fill(Color.blue.opacity(0.55))
                .frame(height: max(1, 38 * bin.blue))
        case .luminance:
            Rectangle()
                .fill(Color.white.opacity(0.62))
                .frame(height: max(1, 38 * bin.luminance))
        case .red:
            Rectangle()
                .fill(Color.red.opacity(0.72))
                .frame(height: max(1, 38 * bin.red))
        case .green:
            Rectangle()
                .fill(Color.green.opacity(0.62))
                .frame(height: max(1, 38 * bin.green))
        case .blue:
            Rectangle()
                .fill(Color.blue.opacity(0.72))
                .frame(height: max(1, 38 * bin.blue))
        }
    }

    private func historyPanel(showsTitle: Bool = true) -> some View {
        EditorPanel(title: L10n.text("imageEditor.panel.history"), showsTitle: showsTitle) {
            VStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 5) {
                        Image(systemName: "clock")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        ImageEditorDarkPanelLabel(
                            title: viewModel.historyStateSummary,
                            role: .muted,
                            font: NSFont.systemFont(ofSize: 10, weight: .semibold)
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Spacer()
                    Button {
                        viewModel.createHistorySnapshot()
                    } label: {
                        Image(systemName: "camera.badge.clock")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(EditorIconButtonStyle(isSelected: false))
                    .help(L10n.text("imageEditor.action.historySnapshotCreate"))
                    Button {
                        viewModel.clearHistoryStates()
                    } label: {
                        Image(systemName: "clock.badge.xmark")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(EditorIconButtonStyle(isSelected: false))
                    .disabled(viewModel.document.history.count <= 1 && !viewModel.canUndo && !viewModel.canRedo)
                    .help(L10n.text("imageEditor.action.historyClear"))
                }

                HStack(spacing: 5) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                    ImageEditorHistorySearchField(
                        placeholder: L10n.text("imageEditor.history.searchPlaceholder"),
                        text: $viewModel.historyQuery
                    )
                    .accessibilityIdentifier("image-editor-history-search-field")
                    if !viewModel.historyQuery.isEmpty {
                        Button {
                            viewModel.historyQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        .help(L10n.text("imageEditor.history.searchClear"))
                        .accessibilityIdentifier("image-editor-history-search-clear")
                    }
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .background(Color.black.opacity(0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(editorBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        if !viewModel.filteredHistorySnapshots.isEmpty {
                            Text(L10n.text("imageEditor.history.snapshots"))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                                .padding(.horizontal, 4)

                            ForEach(viewModel.filteredHistorySnapshots) { snapshot in
                                historySnapshotRow(snapshot)
                            }

                            Divider().overlay(editorBorder)
                                .padding(.vertical, 2)
                        }

                        ForEach(viewModel.filteredHistoryEntries) { entry in
                            HStack(spacing: 4) {
                                HStack(spacing: 6) {
                                    Image(systemName: historyIconName(for: entry))
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                                    ImageEditorDarkPanelLabel(
                                        title: entry.title,
                                        font: NSFont.systemFont(ofSize: 12, weight: .medium)
                                    )
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.selectHistoryEntry(entry.id)
                                }
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(entry.title)
                                .accessibilityAddTraits(.isButton)
                                .accessibilityAction {
                                    viewModel.selectHistoryEntry(entry.id)
                                }
                                .help(L10n.text("imageEditor.action.historySelect"))
                                .accessibilityIdentifier("image-editor-history-entry-\(entry.id)")

                                Button {
                                    viewModel.restoreHistoryEntry(entry.id)
                                } label: {
                                    Image(systemName: "arrow.uturn.backward.circle")
                                        .font(.system(size: 11, weight: .semibold))
                                        .frame(width: 22, height: 22)
                                }
                                .buttonStyle(EditorIconButtonStyle(isSelected: false))
                                .focusable(false)
                                .disabled(viewModel.document.history.last?.id == entry.id)
                                .help(L10n.text("imageEditor.action.historyRestore"))
                                .accessibilityIdentifier("image-editor-history-restore-\(entry.id)")
                            }
                            .background(historyRowBackground(for: entry))
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        }
                    }
                }
                .onDeleteCommand {
                    viewModel.truncateSelectedHistory()
                }
            }
        }
        .frame(height: showsTitle ? 190 : 168)
    }

    private var filtersQuickPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            ImageEditorDarkFilterPicker(selection: $viewModel.selectedFilter)
            .frame(maxWidth: .infinity, minHeight: 24)
            .focusable(false)
            .accessibilityIdentifier("image-editor-filter-picker")

            HStack(spacing: 8) {
                Text("\(Int((viewModel.filterIntensity * 100).rounded()))%")
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                    .frame(width: 36, alignment: .leading)
                Slider(value: $viewModel.filterIntensity, in: 0...1, step: 0.05)
                    .focusable(false)
                    .accessibilityLabel(L10n.text("imageEditor.option.strength"))
                    .accessibilityIdentifier("image-editor-filter-intensity")
            }

            VStack(spacing: 8) {
                Button {
                    viewModel.applySelectedFilter()
                } label: {
                    Text(L10n.text("imageEditor.action.applyFilter"))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(EditorPrimaryButtonStyle())
                .focusable(false)
                .accessibilityIdentifier("image-editor-filter-apply")

                HStack(spacing: 8) {
                    Button {
                        viewModel.addFilterLayer()
                    } label: {
                        Text(L10n.text("imageEditor.action.layerFilterNew"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(EditorTextButtonStyle())
                    .focusable(false)
                    .accessibilityIdentifier("image-editor-filter-layer-new")

                    Button {
                        viewModel.addSmartFilterToSelectedLayer()
                    } label: {
                        Text(L10n.text("imageEditor.action.layerSmartFilterAdd"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(EditorTextButtonStyle())
                    .focusable(false)
                    .accessibilityIdentifier("image-editor-filter-smart-add")
                    .disabled(!viewModel.canAddSmartFilterToSelectedLayer)
                }
            }
        }
        .padding(10)
    }

    private func historySnapshotRow(_ snapshot: ImageEditorHistorySnapshot) -> some View {
        let isSelected = viewModel.selectedHistorySnapshotID == snapshot.id
        return HStack(spacing: 6) {
            Button {
                viewModel.selectHistorySnapshot(snapshot.id)
            } label: {
                Image(systemName: isSelected ? "checkmark.camera.fill" : "camera.filters")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 16)
                    .foregroundStyle(Color(nsColor: isSelected ? ImageEditorTheme.selected : ImageEditorTheme.mutedText))
            }
            .buttonStyle(.plain)
            .help(L10n.text("imageEditor.action.historySnapshotSelect"))

            TextField(
                L10n.text("imageEditor.history.snapshotNamePlaceholder"),
                text: historySnapshotNameBinding(snapshot)
            )
            .textFieldStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
            .onSubmit {
                commitHistorySnapshotNameDraft(snapshot)
            }
            .onAppear {
                syncHistorySnapshotNameDraft(snapshot)
            }
            .onChange(of: snapshot.name) { _ in
                syncHistorySnapshotNameDraft(snapshot)
            }

            Button {
                viewModel.restoreHistorySnapshot(snapshot.id)
            } label: {
                Image(systemName: "arrow.uturn.backward.circle")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(EditorIconButtonStyle(isSelected: false))
            .help(L10n.format("imageEditor.action.historySnapshotRestore", snapshot.name))

            Button {
                viewModel.deleteHistorySnapshot(snapshot.id)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(EditorIconButtonStyle(isSelected: false))
            .help(L10n.format("imageEditor.action.historySnapshotDelete", snapshot.name))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(isSelected ? Color(nsColor: ImageEditorTheme.selected).opacity(0.22) : Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private func historyIconName(for entry: ImageEditorHistoryEntry) -> String {
        viewModel.document.history.last?.id == entry.id ? "checkmark.circle.fill" : "clock.arrow.circlepath"
    }

    private func historyRowBackground(for entry: ImageEditorHistoryEntry) -> Color {
        viewModel.selectedHistoryEntryID == entry.id
            ? Color(nsColor: ImageEditorTheme.selected).opacity(0.32)
            : Color.white.opacity(0.04)
    }

    private func historySnapshotNameBinding(_ snapshot: ImageEditorHistorySnapshot) -> Binding<String> {
        Binding {
            historySnapshotNameDrafts[snapshot.id] ?? snapshot.name
        } set: { value in
            historySnapshotNameDrafts[snapshot.id] = value
        }
    }

    private func syncHistorySnapshotNameDraft(_ snapshot: ImageEditorHistorySnapshot) {
        historySnapshotNameDrafts[snapshot.id] = snapshot.name
    }

    private func commitHistorySnapshotNameDraft(_ snapshot: ImageEditorHistorySnapshot) {
        viewModel.renameHistorySnapshot(snapshot.id, to: historySnapshotNameDrafts[snapshot.id] ?? snapshot.name)
        if let updatedSnapshot = viewModel.namedHistorySnapshots.first(where: { $0.id == snapshot.id }) {
            syncHistorySnapshotNameDraft(updatedSnapshot)
        }
    }

    private func syncLayerNameDraft() {
        layerNameDraft = viewModel.selectedLayerName
    }

    private func syncFigmaComponentPropertyDrafts() {
        figmaComponentPropertyDrafts = viewModel.selectedLayerFigmaComponentProperties
            .filter { $0.value.type == "TEXT" }
            .mapValues(\.value)
    }

    private func figmaComponentPropertyDraftBinding(_ key: String) -> Binding<String> {
        Binding(
            get: {
                figmaComponentPropertyDrafts[key]
                    ?? viewModel.selectedLayerFigmaComponentProperties[key]?.value
                    ?? ""
            },
            set: { value in
                figmaComponentPropertyDrafts[key] = value
            }
        )
    }

    private var documentSizeControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.text("imageEditor.properties.documentSize"))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))

            Stepper(
                L10n.format("imageEditor.properties.imageWidthValue", Int(viewModel.targetImageWidth.rounded())),
                value: $viewModel.targetImageWidth,
                in: 8...12_000,
                step: 1
            )
            Stepper(
                L10n.format("imageEditor.properties.imageHeightValue", Int(viewModel.targetImageHeight.rounded())),
                value: $viewModel.targetImageHeight,
                in: 8...12_000,
                step: 1
            )
            Button(L10n.text("imageEditor.action.imageResize")) {
                viewModel.resizeImageToControlSize()
            }
            .buttonStyle(EditorTextButtonStyle())

            Picker(L10n.text("imageEditor.properties.canvasAnchor"), selection: $viewModel.selectedCanvasAnchor) {
                ForEach(ImageEditorCanvasAnchor.allCases) { anchor in
                    Text(anchor.title).tag(anchor)
                }
            }
            .pickerStyle(.menu)

            Stepper(
                L10n.format("imageEditor.properties.canvasWidthValue", Int(viewModel.targetCanvasWidth.rounded())),
                value: $viewModel.targetCanvasWidth,
                in: 8...12_000,
                step: 1
            )
            Stepper(
                L10n.format("imageEditor.properties.canvasHeightValue", Int(viewModel.targetCanvasHeight.rounded())),
                value: $viewModel.targetCanvasHeight,
                in: 8...12_000,
                step: 1
            )
            Button(L10n.text("imageEditor.action.canvasResize")) {
                viewModel.resizeCanvasToControlSize()
            }
            .buttonStyle(EditorTextButtonStyle())

            Divider()
                .overlay(Color.white.opacity(0.12))

            guideControls
        }
    }

    private func setSelectedLayerTransformWidth(_ value: Double) {
        viewModel.setSelectedLayerTransform(
            width: value,
            preservingAspectRatio: isTransformAspectRatioLocked
        )
    }

    private func setSelectedLayerTransformHeight(_ value: Double) {
        viewModel.setSelectedLayerTransform(
            height: value,
            preservingAspectRatio: isTransformAspectRatioLocked
        )
    }

    private var selectedLayerTransformControls: some View {
        Group {
            if viewModel.selectedLayerTransformFrame != nil {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 7) {
                        Text(L10n.text("imageEditor.properties.transform"))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        Spacer(minLength: 0)
                        Button {
                            isTransformAspectRatioLocked.toggle()
                        } label: {
                            Image(systemName: isTransformAspectRatioLocked ? "link" : "link.slash")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .buttonStyle(EditorIconButtonStyle(isSelected: isTransformAspectRatioLocked))
                        .focusable(false)
                        .help(
                            L10n.text(
                                isTransformAspectRatioLocked
                                    ? "imageEditor.properties.aspectRatioUnlock"
                                    : "imageEditor.properties.aspectRatioLock"
                            )
                        )
                        .accessibilityLabel(
                            L10n.text(
                                isTransformAspectRatioLocked
                                    ? "imageEditor.properties.aspectRatioUnlock"
                                    : "imageEditor.properties.aspectRatioLock"
                            )
                        )
                        .accessibilityIdentifier("image-editor-transform-aspect-ratio-lock")
                    }

                    HStack(spacing: 7) {
                        Stepper(
                            L10n.format(
                                "imageEditor.properties.transformXValue",
                                viewModel.selectedLayerTransformX
                            ),
                            value: Binding(
                                get: { viewModel.selectedLayerTransformX },
                                set: { viewModel.setSelectedLayerTransform(x: $0) }
                            ),
                            in: -12_000...12_000,
                            step: 1
                        )
                        .focusable(false)
                        .disabled(!viewModel.canResizeSelectedLayer)
                        .accessibilityIdentifier("image-editor-transform-x")

                        Stepper(
                            L10n.format(
                                "imageEditor.properties.transformYValue",
                                viewModel.selectedLayerTransformY
                            ),
                            value: Binding(
                                get: { viewModel.selectedLayerTransformY },
                                set: { viewModel.setSelectedLayerTransform(y: $0) }
                            ),
                            in: -12_000...12_000,
                            step: 1
                        )
                        .focusable(false)
                        .disabled(!viewModel.canResizeSelectedLayer)
                        .accessibilityIdentifier("image-editor-transform-y")
                    }

                    HStack(spacing: 7) {
                        Stepper(
                            L10n.format(
                                "imageEditor.properties.transformWidthValue",
                                viewModel.selectedLayerTransformWidth
                            ),
                            value: Binding(
                                get: { viewModel.selectedLayerTransformWidth },
                                set: { setSelectedLayerTransformWidth($0) }
                            ),
                            in: 1...12_000,
                            step: 1
                        )
                        .focusable(false)
                        .disabled(!viewModel.canResizeSelectedLayer)
                        .accessibilityIdentifier("image-editor-transform-width")

                        Stepper(
                            L10n.format(
                                "imageEditor.properties.transformHeightValue",
                                viewModel.selectedLayerTransformHeight
                            ),
                            value: Binding(
                                get: { viewModel.selectedLayerTransformHeight },
                                set: { setSelectedLayerTransformHeight($0) }
                            ),
                            in: 1...12_000,
                            step: 1
                        )
                        .focusable(false)
                        .disabled(!viewModel.canResizeSelectedLayer)
                        .accessibilityIdentifier("image-editor-transform-height")
                    }
                }
            }
        }
    }

    private var guideControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.text("imageEditor.properties.guides"))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))

            Toggle(
                L10n.text("imageEditor.action.extrasVisible"),
                isOn: Binding(
                    get: { viewModel.document.areExtrasVisible },
                    set: { _ in viewModel.toggleExtrasVisible() }
                )
            )
            .toggleStyle(.checkbox)

            Toggle(
                L10n.text("imageEditor.action.rulersVisible"),
                isOn: Binding(
                    get: { viewModel.document.areRulersVisible },
                    set: { _ in viewModel.toggleRulersVisible() }
                )
            )
            .toggleStyle(.checkbox)

            Toggle(
                L10n.text("imageEditor.action.guidesVisible"),
                isOn: Binding(
                    get: { viewModel.document.areGuidesVisible },
                    set: { _ in viewModel.toggleGuidesVisible() }
                )
            )
            .toggleStyle(.checkbox)

            Toggle(
                L10n.text("imageEditor.action.guidesSnap"),
                isOn: Binding(
                    get: { viewModel.document.isGuideSnappingEnabled },
                    set: { _ in viewModel.toggleGuideSnapping() }
                )
            )
            .toggleStyle(.checkbox)

            Toggle(
                L10n.text("imageEditor.action.guidesLocked"),
                isOn: Binding(
                    get: { viewModel.document.areGuidesLocked },
                    set: { _ in viewModel.toggleGuidesLocked() }
                )
            )
            .toggleStyle(.checkbox)

            Toggle(
                L10n.text("imageEditor.action.selectionEdgesVisible"),
                isOn: Binding(
                    get: { viewModel.document.areSelectionEdgesVisible },
                    set: { _ in viewModel.toggleSelectionEdgesVisible() }
                )
            )
            .toggleStyle(.checkbox)

            Toggle(
                L10n.text("imageEditor.action.transformControlsVisible"),
                isOn: Binding(
                    get: { viewModel.document.areTransformControlsVisible },
                    set: { _ in viewModel.toggleTransformControlsVisible() }
                )
            )
            .toggleStyle(.checkbox)

            HStack(spacing: 6) {
                Button(L10n.text("imageEditor.action.guideVerticalCenter")) {
                    viewModel.addVerticalGuideAtCanvasCenter()
                }
                .buttonStyle(EditorTextButtonStyle())

                Button(L10n.text("imageEditor.action.guideHorizontalCenter")) {
                    viewModel.addHorizontalGuideAtCanvasCenter()
                }
                .buttonStyle(EditorTextButtonStyle())
            }

            HStack(spacing: 6) {
                Text(viewModel.guideSummary)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))

                Spacer()

                Button(L10n.text("imageEditor.action.guidesClear")) {
                    viewModel.clearGuides()
                }
                .buttonStyle(EditorTextButtonStyle())
                .disabled(viewModel.document.guides.isEmpty)
            }
        }
    }

    private func commitLayerNameDraft() {
        viewModel.renameSelectedLayer(to: layerNameDraft)
        syncLayerNameDraft()
    }

    private var selectedLayerEffectScaleBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerEffectScale
        } set: { value in
            viewModel.setSelectedLayerEffectScale(value)
        }
    }

    private var selectedLayerStrokeWidthBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerStrokeWidth
        } set: { value in
            viewModel.setSelectedLayerStrokeWidth(value)
        }
    }

    private var selectedLayerStrokeColorBinding: Binding<Color> {
        Binding {
            Color(nsColor: viewModel.selectedLayerStrokeColor)
        } set: { value in
            viewModel.setSelectedLayerStrokeColor(NSColor(value))
        }
    }

    private var selectedLayerStrokeGradientStartColorBinding: Binding<Color> {
        Binding {
            Color(nsColor: viewModel.selectedLayerStrokeGradientStartColor)
        } set: { value in
            viewModel.setSelectedLayerStrokeGradientStartColor(NSColor(value))
        }
    }

    private var selectedLayerStrokeGradientEndColorBinding: Binding<Color> {
        Binding {
            Color(nsColor: viewModel.selectedLayerStrokeGradientEndColor)
        } set: { value in
            viewModel.setSelectedLayerStrokeGradientEndColor(NSColor(value))
        }
    }

    private var selectedLayerStrokePatternColorBinding: Binding<Color> {
        Binding {
            Color(nsColor: viewModel.selectedLayerStrokePatternColor)
        } set: { value in
            viewModel.setSelectedLayerStrokePatternColor(NSColor(value))
        }
    }

    private var selectedLayerShadowColorBinding: Binding<Color> {
        Binding {
            Color(nsColor: viewModel.selectedLayerShadowColor)
        } set: { value in
            viewModel.setSelectedLayerShadowColor(NSColor(value))
        }
    }

    private var selectedLayerOuterGlowColorBinding: Binding<Color> {
        Binding {
            Color(nsColor: viewModel.selectedLayerOuterGlowColor)
        } set: { value in
            viewModel.setSelectedLayerOuterGlowColor(NSColor(value))
        }
    }

    private var selectedLayerInnerGlowColorBinding: Binding<Color> {
        Binding {
            Color(nsColor: viewModel.selectedLayerInnerGlowColor)
        } set: { value in
            viewModel.setSelectedLayerInnerGlowColor(NSColor(value))
        }
    }

    private var selectedLayerColorOverlayColorBinding: Binding<Color> {
        Binding {
            Color(nsColor: viewModel.selectedLayerColorOverlayColor)
        } set: { value in
            viewModel.setSelectedLayerColorOverlayColor(NSColor(value))
        }
    }

    private var selectedLayerGradientOverlayStartColorBinding: Binding<Color> {
        Binding {
            Color(nsColor: viewModel.selectedLayerGradientOverlayStartColor)
        } set: { value in
            viewModel.setSelectedLayerGradientOverlayStartColor(NSColor(value))
        }
    }

    private var selectedLayerGradientOverlayEndColorBinding: Binding<Color> {
        Binding {
            Color(nsColor: viewModel.selectedLayerGradientOverlayEndColor)
        } set: { value in
            viewModel.setSelectedLayerGradientOverlayEndColor(NSColor(value))
        }
    }

    private var selectedLayerPatternOverlayColorBinding: Binding<Color> {
        Binding {
            Color(nsColor: viewModel.selectedLayerPatternOverlayColor)
        } set: { value in
            viewModel.setSelectedLayerPatternOverlayColor(NSColor(value))
        }
    }

    private var selectedLayerSatinColorBinding: Binding<Color> {
        Binding {
            Color(nsColor: viewModel.selectedLayerSatinColor)
        } set: { value in
            viewModel.setSelectedLayerSatinColor(NSColor(value))
        }
    }

    private var selectedLayerBevelHighlightColorBinding: Binding<Color> {
        Binding {
            Color(nsColor: viewModel.selectedLayerBevelHighlightColor)
        } set: { value in
            viewModel.setSelectedLayerBevelHighlightColor(NSColor(value))
        }
    }

    private var selectedLayerBevelShadowColorBinding: Binding<Color> {
        Binding {
            Color(nsColor: viewModel.selectedLayerBevelShadowColor)
        } set: { value in
            viewModel.setSelectedLayerBevelShadowColor(NSColor(value))
        }
    }

    private var selectedLayerStrokeOpacityBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerStrokeOpacity
        } set: { value in
            viewModel.setSelectedLayerStrokeOpacity(value)
        }
    }

    private var selectedLayerStrokeGradientAngleBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerStrokeGradientAngle
        } set: { value in
            viewModel.setSelectedLayerStrokeGradientAngle(value)
        }
    }

    private var selectedLayerStrokePatternScaleBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerStrokePatternScale
        } set: { value in
            viewModel.setSelectedLayerStrokePatternScale(value)
        }
    }

    private var selectedLayerStrokePatternOffsetXBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerStrokePatternOffsetX
        } set: { value in
            viewModel.setSelectedLayerStrokePatternOffsetX(value)
        }
    }

    private var selectedLayerStrokePatternOffsetYBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerStrokePatternOffsetY
        } set: { value in
            viewModel.setSelectedLayerStrokePatternOffsetY(value)
        }
    }

    private var selectedLayerShadowOpacityBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerShadowOpacity
        } set: { value in
            viewModel.setSelectedLayerShadowOpacity(value)
        }
    }

    private var selectedLayerShadowBlurBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerShadowBlur
        } set: { value in
            viewModel.setSelectedLayerShadowBlur(value)
        }
    }

    private var selectedLayerShadowSpreadBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerShadowSpread
        } set: { value in
            viewModel.setSelectedLayerShadowSpread(value)
        }
    }

    private var selectedLayerShadowNoiseBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerShadowNoise
        } set: { value in
            viewModel.setSelectedLayerShadowNoise(value)
        }
    }

    private var globalLightAngleBinding: Binding<Double> {
        Binding {
            viewModel.globalLightAngle
        } set: { value in
            viewModel.setGlobalLightAngle(value)
        }
    }

    private var selectedLayerShadowDistanceBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerShadowDistance
        } set: { value in
            viewModel.setSelectedLayerShadowDistance(value)
        }
    }

    private var selectedLayerShadowAngleBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerShadowAngle
        } set: { value in
            viewModel.setSelectedLayerShadowAngle(value)
        }
    }

    private var selectedLayerShadowOffsetXBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerShadowOffsetX
        } set: { value in
            viewModel.setSelectedLayerShadowOffsetX(value)
        }
    }

    private var selectedLayerShadowOffsetYBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerShadowOffsetY
        } set: { value in
            viewModel.setSelectedLayerShadowOffsetY(value)
        }
    }

    private var selectedLayerInnerShadowOpacityBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerInnerShadowOpacity
        } set: { value in
            viewModel.setSelectedLayerInnerShadowOpacity(value)
        }
    }

    private var selectedLayerInnerShadowBlurBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerInnerShadowBlur
        } set: { value in
            viewModel.setSelectedLayerInnerShadowBlur(value)
        }
    }

    private var selectedLayerInnerShadowChokeBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerInnerShadowChoke
        } set: { value in
            viewModel.setSelectedLayerInnerShadowChoke(value)
        }
    }

    private var selectedLayerInnerShadowNoiseBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerInnerShadowNoise
        } set: { value in
            viewModel.setSelectedLayerInnerShadowNoise(value)
        }
    }

    private var selectedLayerInnerShadowDistanceBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerInnerShadowDistance
        } set: { value in
            viewModel.setSelectedLayerInnerShadowDistance(value)
        }
    }

    private var selectedLayerInnerShadowAngleBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerInnerShadowAngle
        } set: { value in
            viewModel.setSelectedLayerInnerShadowAngle(value)
        }
    }

    private var selectedLayerOuterGlowOpacityBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerOuterGlowOpacity
        } set: { value in
            viewModel.setSelectedLayerOuterGlowOpacity(value)
        }
    }

    private var selectedLayerOuterGlowBlurBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerOuterGlowBlur
        } set: { value in
            viewModel.setSelectedLayerOuterGlowBlur(value)
        }
    }

    private var selectedLayerOuterGlowSpreadBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerOuterGlowSpread
        } set: { value in
            viewModel.setSelectedLayerOuterGlowSpread(value)
        }
    }

    private var selectedLayerOuterGlowNoiseBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerOuterGlowNoise
        } set: { value in
            viewModel.setSelectedLayerOuterGlowNoise(value)
        }
    }

    private var selectedLayerOuterGlowRangeBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerOuterGlowRange
        } set: { value in
            viewModel.setSelectedLayerOuterGlowRange(value)
        }
    }

    private var selectedLayerOuterGlowJitterBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerOuterGlowJitter
        } set: { value in
            viewModel.setSelectedLayerOuterGlowJitter(value)
        }
    }

    private var selectedLayerInnerGlowOpacityBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerInnerGlowOpacity
        } set: { value in
            viewModel.setSelectedLayerInnerGlowOpacity(value)
        }
    }

    private var selectedLayerInnerGlowBlurBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerInnerGlowBlur
        } set: { value in
            viewModel.setSelectedLayerInnerGlowBlur(value)
        }
    }

    private var selectedLayerInnerGlowChokeBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerInnerGlowChoke
        } set: { value in
            viewModel.setSelectedLayerInnerGlowChoke(value)
        }
    }

    private var selectedLayerInnerGlowNoiseBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerInnerGlowNoise
        } set: { value in
            viewModel.setSelectedLayerInnerGlowNoise(value)
        }
    }

    private var selectedLayerInnerGlowRangeBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerInnerGlowRange
        } set: { value in
            viewModel.setSelectedLayerInnerGlowRange(value)
        }
    }

    private var selectedLayerInnerGlowJitterBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerInnerGlowJitter
        } set: { value in
            viewModel.setSelectedLayerInnerGlowJitter(value)
        }
    }

    private var selectedLayerColorOverlayOpacityBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerColorOverlayOpacity
        } set: { value in
            viewModel.setSelectedLayerColorOverlayOpacity(value)
        }
    }

    private var selectedLayerGradientOverlayOpacityBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerGradientOverlayOpacity
        } set: { value in
            viewModel.setSelectedLayerGradientOverlayOpacity(value)
        }
    }

    private var selectedLayerGradientOverlayScaleBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerGradientOverlayScale
        } set: { value in
            viewModel.setSelectedLayerGradientOverlayScale(value)
        }
    }

    private var selectedLayerGradientOverlayAngleBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerGradientOverlayAngle
        } set: { value in
            viewModel.setSelectedLayerGradientOverlayAngle(value)
        }
    }

    private var selectedLayerPatternOverlayOpacityBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerPatternOverlayOpacity
        } set: { value in
            viewModel.setSelectedLayerPatternOverlayOpacity(value)
        }
    }

    private var selectedLayerPatternOverlayScaleBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerPatternOverlayScale
        } set: { value in
            viewModel.setSelectedLayerPatternOverlayScale(value)
        }
    }

    private var selectedLayerPatternOverlayOffsetXBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerPatternOverlayOffsetX
        } set: { value in
            viewModel.setSelectedLayerPatternOverlayOffsetX(value)
        }
    }

    private var selectedLayerPatternOverlayOffsetYBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerPatternOverlayOffsetY
        } set: { value in
            viewModel.setSelectedLayerPatternOverlayOffsetY(value)
        }
    }

    private var selectedLayerSatinOpacityBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerSatinOpacity
        } set: { value in
            viewModel.setSelectedLayerSatinOpacity(value)
        }
    }

    private var selectedLayerSatinDistanceBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerSatinDistance
        } set: { value in
            viewModel.setSelectedLayerSatinDistance(value)
        }
    }

    private var selectedLayerSatinSizeBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerSatinSize
        } set: { value in
            viewModel.setSelectedLayerSatinSize(value)
        }
    }

    private var selectedLayerSatinAngleBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerSatinAngle
        } set: { value in
            viewModel.setSelectedLayerSatinAngle(value)
        }
    }

    private var selectedLayerBevelSizeBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerBevelSize
        } set: { value in
            viewModel.setSelectedLayerBevelSize(value)
        }
    }

    private var selectedLayerBevelOpacityBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerBevelOpacity
        } set: { value in
            viewModel.setSelectedLayerBevelOpacity(value)
        }
    }

    private var selectedLayerBevelSoftenBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerBevelSoften
        } set: { value in
            viewModel.setSelectedLayerBevelSoften(value)
        }
    }

    private var selectedLayerBevelAngleBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerBevelAngle
        } set: { value in
            viewModel.setSelectedLayerBevelAngle(value)
        }
    }

    private func layerStyleGlobalLightToggle(
        _ effect: ImageEditorLayerLightEffect,
        labelKey: String,
        accessibilityIdentifier: String
    ) -> some View {
        let state = viewModel.selectedLayerGlobalLightState(effect)
        return layerStyleTriStateToggle(
            state: state,
            labelKey: labelKey,
            accessibilityIdentifier: accessibilityIdentifier
        ) {
            viewModel.toggleSelectedLayerUsesGlobalLight(effect)
        }
    }

    private func layerStyleTriStateToggle(
        state: ImageEditorLayerStyleSelectionState,
        labelKey: String,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: layerStyleTriStateSymbol(state))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(layerStyleTriStateColor(state))
                Text(L10n.text(labelKey))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.canEditSelectedLayerStyle)
        .focusable(false)
        .accessibilityLabel(L10n.text(labelKey))
        .accessibilityValue(L10n.text(state.accessibilityKey))
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func layerStyleTriStateSymbol(_ state: ImageEditorLayerStyleSelectionState) -> String {
        switch state {
        case .off: "square"
        case .on: "checkmark.square.fill"
        case .mixed: "minus.square.fill"
        }
    }

    private func layerStyleTriStateColor(_ state: ImageEditorLayerStyleSelectionState) -> Color {
        Color(nsColor: state == .off ? ImageEditorTheme.mutedText : ImageEditorTheme.selected)
    }

    private func layerStyleColorPickerRow(
        labelKey: String,
        state: ImageEditorLayerStyleValueState<ImageEditorProjectColor>,
        selection: Binding<Color>,
        accessibilityIdentifier: String
    ) -> AnyView {
        AnyView(HStack(spacing: 8) {
            Text(L10n.text(labelKey))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
            ColorPicker("", selection: selection, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 32)
                .focusable(false)
                .accessibilityValue(
                    state.isMixed
                        ? L10n.text("imageEditor.properties.multipleValues")
                        : ""
                )
                .accessibilityIdentifier(accessibilityIdentifier)
            if state.isMixed {
                Text(L10n.text("imageEditor.properties.multipleValues"))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
        })
    }

    private func layerStyleValuePicker<Value: Hashable>(
        state: ImageEditorLayerStyleValueState<Value>,
        values: [Value],
        labelKey: String,
        accessibilityIdentifier: String,
        title: @escaping (Value) -> String,
        onSelect: @escaping (Value) -> Void
    ) -> some View {
        let selection = Binding<Value?> {
            state.value
        } set: { value in
            if let value { onSelect(value) }
        }
        let accessibilityValue = state.value.map(title)
            ?? (state.isMixed ? L10n.text("imageEditor.properties.multipleValues") : "")
        return Picker(L10n.text(labelKey), selection: selection) {
            if state.isMixed {
                Text(L10n.text("imageEditor.properties.multipleValues"))
                    .tag(Optional<Value>.none)
            }
            ForEach(values, id: \.self) { value in
                Text(title(value)).tag(Optional(value))
            }
        }
        .pickerStyle(.menu)
        .disabled(!viewModel.canEditSelectedLayerStyle)
        .focusable(false)
        .accessibilityValue(accessibilityValue)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func layerStyleNumericStepper(
        state: ImageEditorLayerStyleValueState<CGFloat>,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        accessibilityIdentifier: String,
        title: @escaping (Double) -> String
    ) -> some View {
        let displayedTitle = state.value.map { title(Double($0)) }
            ?? (state.isMixed ? L10n.text("imageEditor.properties.multipleValues") : "")
        return Stepper(value: value, in: range, step: step) {
            Text(displayedTitle)
        }
        .disabled(!viewModel.canEditSelectedLayerStyle || state == .unavailable)
        .focusable(false)
        .accessibilityValue(displayedTitle)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func guidePath(orientation: ImageEditorGuideOrientation, position: CGFloat, in size: CGSize) -> Path {
        var path = Path()
        switch orientation {
        case .vertical:
            let start = viewPoint(from: CGPoint(x: position, y: 0), in: size)
            let end = viewPoint(from: CGPoint(x: position, y: viewModel.document.canvasSize.height), in: size)
            path.move(to: start)
            path.addLine(to: end)
        case .horizontal:
            let start = viewPoint(from: CGPoint(x: 0, y: position), in: size)
            let end = viewPoint(from: CGPoint(x: viewModel.document.canvasSize.width, y: position), in: size)
            path.move(to: start)
            path.addLine(to: end)
        }
        return path
    }

    @ViewBuilder
    private func gridOverlay(in size: CGSize) -> some View {
        if viewModel.document.areExtrasVisible && viewModel.document.isGridVisible {
            Canvas { context, _ in
                let canvasSize = viewModel.document.canvasSize
                let spacing = max(4, min(512, viewModel.document.gridSpacing))
                let verticalCount = Int((canvasSize.width / spacing).rounded(.up))
                let horizontalCount = Int((canvasSize.height / spacing).rounded(.up))

                for index in 0...verticalCount {
                    let position = min(canvasSize.width, CGFloat(index) * spacing)
                    let opacity = index.isMultiple(of: 4) ? 0.34 : 0.18
                    context.stroke(
                        guidePath(orientation: .vertical, position: position, in: size),
                        with: .color(.white.opacity(opacity)),
                        lineWidth: index.isMultiple(of: 4) ? 0.85 : 0.55
                    )
                }

                for index in 0...horizontalCount {
                    let position = min(canvasSize.height, CGFloat(index) * spacing)
                    let opacity = index.isMultiple(of: 4) ? 0.34 : 0.18
                    context.stroke(
                        guidePath(orientation: .horizontal, position: position, in: size),
                        with: .color(.white.opacity(opacity)),
                        lineWidth: index.isMultiple(of: 4) ? 0.85 : 0.55
                    )
                }
            }
            .allowsHitTesting(false)
        }
    }

    private func guideOverlay(in size: CGSize) -> some View {
        Canvas { context, _ in
            if viewModel.document.areExtrasVisible && viewModel.document.areGuidesVisible {
                for guide in viewModel.document.guides {
                    context.stroke(
                        guidePath(orientation: guide.orientation, position: guide.position, in: size),
                        with: .color(.cyan.opacity(0.82)),
                        style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                    )
                }
            }

            if let activeGuideDrag {
                context.stroke(
                    guidePath(
                        orientation: activeGuideDrag.orientation,
                        position: activeGuideDrag.position,
                        in: size
                    ),
                    with: .color(.yellow.opacity(0.9)),
                    style: StrokeStyle(lineWidth: 1.4, dash: [3, 3])
                )
            }

            for guide in viewModel.activeAlignmentGuides {
                context.stroke(
                    guidePath(orientation: guide.orientation, position: guide.position, in: size),
                    with: .color(Color(nsColor: ImageEditorTheme.selected).opacity(0.96)),
                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                )
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func guideInteractionOverlay(in size: CGSize) -> some View {
        if viewModel.document.areExtrasVisible && viewModel.document.areGuidesVisible && !viewModel.document.areGuidesLocked {
            let rect = fittedImageRect(in: size)
            ZStack {
                ForEach(viewModel.document.guides) { guide in
                    let anchor = guideAnchorPoint(guide, in: size)
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .frame(
                            width: guide.orientation == .vertical ? 12 : max(rect.width, 1),
                            height: guide.orientation == .vertical ? max(rect.height, 1) : 12
                        )
                        .position(anchor)
                        .highPriorityGesture(existingGuideGesture(guide, in: size))
                }
            }
        }
    }

    @ViewBuilder
    private func rulerOverlay(in size: CGSize) -> some View {
        if viewModel.document.areRulersVisible {
            let rect = fittedImageRect(in: size)
            let thickness: CGFloat = 22
            ZStack {
                Canvas { context, _ in
                    drawRulers(context: context, imageRect: rect, thickness: thickness, canvasSize: size)
                }
                .allowsHitTesting(false)

                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .frame(width: max(rect.width, 1), height: thickness)
                    .position(x: rect.midX, y: rect.minY - thickness / 2)
                    .highPriorityGesture(rulerGuideGesture(.vertical, in: size))

                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .frame(width: thickness, height: max(rect.height, 1))
                    .position(x: rect.minX - thickness / 2, y: rect.midY)
                    .highPriorityGesture(rulerGuideGesture(.horizontal, in: size))
            }
        }
    }

    private func guideAnchorPoint(_ guide: ImageEditorGuide, in size: CGSize) -> CGPoint {
        switch guide.orientation {
        case .vertical:
            return viewPoint(from: CGPoint(x: guide.position, y: viewModel.document.canvasSize.height / 2), in: size)
        case .horizontal:
            return viewPoint(from: CGPoint(x: viewModel.document.canvasSize.width / 2, y: guide.position), in: size)
        }
    }

    private func guidePosition(from location: CGPoint, orientation: ImageEditorGuideOrientation, in size: CGSize) -> CGFloat {
        let point = unboundedImagePoint(from: location, in: size)
        let upperBound: CGFloat
        let rawPosition: CGFloat
        switch orientation {
        case .vertical:
            upperBound = viewModel.document.canvasSize.width
            rawPosition = point.x
        case .horizontal:
            upperBound = viewModel.document.canvasSize.height
            rawPosition = point.y
        }
        return min(max(0, rawPosition.rounded()), max(0, upperBound.rounded()))
    }

    private func existingGuideGesture(_ guide: ImageEditorGuide, in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let position = guidePosition(from: value.location, orientation: guide.orientation, in: size)
                if activeGuideDrag == nil {
                    viewModel.beginMovingGuide(guide.id)
                }
                activeGuideDrag = ImageEditorGuideDrag(orientation: guide.orientation, position: position)
                viewModel.moveGuide(guide.id, to: position)
            }
            .onEnded { _ in
                viewModel.finishMovingGuide()
                activeGuideDrag = nil
            }
    }

    private func rulerGuideGesture(_ orientation: ImageEditorGuideOrientation, in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                activeGuideDrag = ImageEditorGuideDrag(
                    orientation: orientation,
                    position: guidePosition(from: value.location, orientation: orientation, in: size)
                )
            }
            .onEnded { value in
                if fittedImageRect(in: size).contains(value.location) {
                    viewModel.addGuide(
                        orientation,
                        at: guidePosition(from: value.location, orientation: orientation, in: size)
                    )
                }
                activeGuideDrag = nil
            }
    }

    private func drawRulers(context: GraphicsContext, imageRect: CGRect, thickness: CGFloat, canvasSize: CGSize) {
        guard imageRect.width > 0, imageRect.height > 0 else { return }
        let topRect = CGRect(x: imageRect.minX, y: imageRect.minY - thickness, width: imageRect.width, height: thickness)
        let leftRect = CGRect(x: imageRect.minX - thickness, y: imageRect.minY, width: thickness, height: imageRect.height)
        let cornerRect = CGRect(x: imageRect.minX - thickness, y: imageRect.minY - thickness, width: thickness, height: thickness)
        let background = Color(nsColor: ImageEditorTheme.panelRaised).opacity(0.94)
        let strokeColor = Color.white.opacity(0.24)
        let tickColor = Color.white.opacity(0.58)
        let labelColor = Color(nsColor: ImageEditorTheme.mutedText)

        context.fill(Path(topRect), with: .color(background))
        context.fill(Path(leftRect), with: .color(background))
        context.fill(Path(cornerRect), with: .color(background.opacity(0.9)))
        context.stroke(Path(topRect), with: .color(strokeColor), lineWidth: 1)
        context.stroke(Path(leftRect), with: .color(strokeColor), lineWidth: 1)

        let xScale = imageRect.width / max(viewModel.document.canvasSize.width, 1)
        let yScale = imageRect.height / max(viewModel.document.canvasSize.height, 1)
        let xStep = rulerStep(pixelScale: xScale)
        let yStep = rulerStep(pixelScale: yScale)

        var xPosition: CGFloat = 0
        while xPosition <= viewModel.document.canvasSize.width + 0.5 {
            let viewX = viewPoint(from: CGPoint(x: xPosition, y: 0), in: canvasSize).x
            var tick = Path()
            tick.move(to: CGPoint(x: viewX, y: topRect.maxY))
            tick.addLine(to: CGPoint(x: viewX, y: topRect.maxY - 8))
            context.stroke(tick, with: .color(tickColor), lineWidth: 1)
            context.draw(
                Text("\(Int(xPosition.rounded()))")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(labelColor),
                at: CGPoint(x: viewX + 3, y: topRect.midY - 2),
                anchor: .leading
            )
            xPosition += xStep
        }

        var yPosition: CGFloat = 0
        while yPosition <= viewModel.document.canvasSize.height + 0.5 {
            let viewY = viewPoint(from: CGPoint(x: 0, y: yPosition), in: canvasSize).y
            var tick = Path()
            tick.move(to: CGPoint(x: leftRect.maxX, y: viewY))
            tick.addLine(to: CGPoint(x: leftRect.maxX - 8, y: viewY))
            context.stroke(tick, with: .color(tickColor), lineWidth: 1)
            context.draw(
                Text("\(Int(yPosition.rounded()))")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(labelColor),
                at: CGPoint(x: leftRect.minX + 3, y: viewY - 2),
                anchor: .leading
            )
            yPosition += yStep
        }
    }

    private func rulerStep(pixelScale: CGFloat) -> CGFloat {
        for step in [10, 25, 50, 100, 250, 500, 1_000, 2_000] where CGFloat(step) * pixelScale >= 48 {
            return CGFloat(step)
        }
        return 5_000
    }

    @ViewBuilder
    private func quickMaskOverlay(in size: CGSize) -> some View {
        if let overlayImage = viewModel.quickMaskOverlayImage {
            let imageRect = fittedImageRect(in: size)
            Image(nsImage: overlayImage)
                .resizable()
                .interpolation(.none)
                .frame(width: imageRect.width, height: imageRect.height)
                .position(x: imageRect.midX, y: imageRect.midY)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func selectionOverlay(in size: CGSize) -> some View {
        if !viewModel.isQuickMaskMode {
            let activeLasso = (
                canvasInteractionTool == .lasso
                    || (canvasInteractionTool == .patchTool && isDrawingPatchSelection)
            ) && dragPoints.count > 1
            let activeSelection = viewModel.document.areExtrasVisible && viewModel.document.areSelectionEdgesVisible
                ? viewModel.selection
                : nil
            let edgeGeometry = activeSelection != nil
                ? viewModel.selectionEdgeGeometry
                : (activeLasso ? ImageEditorSelection.polygon(dragPoints).map {
                    ImageEditorSelectionEdgeGeometry.make(
                        selection: $0,
                        canvasSize: viewModel.document.canvasSize
                    )
                } : nil)
            if let edgeGeometry {
                TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
                    Canvas { context, _ in
                        var path = Path()
                        for contour in edgeGeometry.contours {
                            guard let first = contour.first else { continue }
                            path.move(to: viewPoint(from: first, in: size))
                            for point in contour.dropFirst() {
                                path.addLine(to: viewPoint(from: point, in: size))
                            }
                        }
                        let phase = ImageEditorSelectionMarchingAnts.dashPhase(
                            at: timeline.date.timeIntervalSinceReferenceDate
                        )
                        let stroke = StrokeStyle(lineWidth: 1.4, dash: [5, 4], dashPhase: phase)
                        context.stroke(path, with: .color(Color.white.opacity(0.92)), style: stroke)
                        context.stroke(
                            path,
                            with: .color(Color(nsColor: ImageEditorTheme.selected).opacity(0.9)),
                            style: StrokeStyle(lineWidth: 1.4, dash: [5, 4], dashPhase: phase + 4.5)
                        )
                    }
                }
                .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    private func savedPathOverlay(in size: CGSize) -> some View {
        let savedPaths = viewModel.savedPathCanvasOverlays
        if !savedPaths.isEmpty {
            Canvas { context, _ in
                for savedPath in savedPaths {
                    let path = savedPathCanvasPath(savedPath, in: size)
                    let isSelected = savedPath.id == viewModel.document.selectedSavedPathID
                    context.stroke(
                        path,
                        with: .color(Color.black.opacity(isSelected ? 0.62 : 0.48)),
                        style: StrokeStyle(lineWidth: 2.4)
                    )
                    context.stroke(
                        path,
                        with: .color(Color.gray.opacity(isSelected ? 0.9 : 0.72)),
                        style: StrokeStyle(lineWidth: 1)
                    )
                }
                for item in viewModel.selectedSavedPathAnchorOverlayItems {
                    let anchor = viewPoint(from: item.point, in: size)
                    let controls = [item.inControl, item.outControl].compactMap { $0 }
                    for control in controls {
                        let handle = viewPoint(from: control, in: size)
                        var handleLine = Path()
                        handleLine.move(to: anchor)
                        handleLine.addLine(to: handle)
                        context.stroke(
                            handleLine,
                            with: .color(Color.gray.opacity(0.58)),
                            style: StrokeStyle(lineWidth: 1, dash: [3, 2])
                        )
                        let handleRect = CGRect(
                            x: handle.x - 3,
                            y: handle.y - 3,
                            width: 6,
                            height: 6
                        )
                        context.fill(Path(handleRect), with: .color(Color.black.opacity(0.72)))
                        context.stroke(Path(handleRect), with: .color(Color.gray.opacity(0.9)), lineWidth: 1)
                    }
                    let anchorRect = CGRect(
                        x: anchor.x - 3.5,
                        y: anchor.y - 3.5,
                        width: 7,
                        height: 7
                    )
                    context.fill(Path(anchorRect), with: .color(Color.gray.opacity(0.92)))
                    context.stroke(Path(anchorRect), with: .color(Color.black.opacity(0.7)), lineWidth: 1)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private func savedPathCanvasPath(_ savedPath: ImageEditorSavedPath, in size: CGSize) -> Path {
        var path = Path()
        for anchors in savedPath.subpaths {
            guard let first = anchors.first else { continue }
            path.move(to: viewPoint(from: first.point, in: size))
            for index in anchors.indices.dropFirst() {
                let previous = anchors[index - 1]
                let current = anchors[index]
                let destination = viewPoint(from: current.point, in: size)
                if previous.outControl != nil || current.inControl != nil {
                    path.addCurve(
                        to: destination,
                        control1: viewPoint(from: previous.outControl ?? previous.point, in: size),
                        control2: viewPoint(from: current.inControl ?? current.point, in: size)
                    )
                } else {
                    path.addLine(to: destination)
                }
            }
            if savedPath.isClosed, anchors.count > 2, let last = anchors.last {
                if last.outControl != nil || first.inControl != nil {
                    path.addCurve(
                        to: viewPoint(from: first.point, in: size),
                        control1: viewPoint(from: last.outControl ?? last.point, in: size),
                        control2: viewPoint(from: first.inControl ?? first.point, in: size)
                    )
                }
                path.closeSubpath()
            }
        }
        return path
    }

    @ViewBuilder
    private func hotspotOverlay(in size: CGSize) -> some View {
        let hotspots = viewModel.availableHotspots
        if !hotspots.isEmpty {
            Canvas { context, _ in
                for hotspot in hotspots {
                    let frame = deliveryDrag?.reference == .hotspot(hotspot.id)
                        ? deliveryDrag?.previewFrame ?? hotspot.frame
                        : hotspot.frame
                    let rect = viewRect(from: frame, in: size)
                    let isSelected = viewModel.selectedHotspotID == hotspot.id
                    context.fill(
                        Path(rect),
                        with: .color(Color.orange.opacity(isSelected ? 0.16 : 0.08))
                    )
                    context.stroke(
                        Path(rect),
                        with: .color(Color.orange.opacity(isSelected ? 1 : 0.9)),
                        style: StrokeStyle(lineWidth: isSelected ? 2 : 1.4, dash: [6, 4])
                    )
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func sliceOverlay(in size: CGSize) -> some View {
        let slices = viewModel.availableSlices
        if !slices.isEmpty {
            Canvas { context, _ in
                for slice in slices {
                    let frame = deliveryDrag?.reference == .slice(slice.id)
                        ? deliveryDrag?.previewFrame ?? slice.frame
                        : slice.frame
                    let rect = viewRect(from: frame, in: size)
                    let isSelected = viewModel.selectedHotspotID == nil
                        && viewModel.exportSettings.sliceID == slice.id
                    context.fill(
                        Path(rect),
                        with: .color(Color.cyan.opacity(isSelected ? 0.12 : 0.04))
                    )
                    context.stroke(
                        Path(rect),
                        with: .color(Color.cyan.opacity(isSelected ? 0.95 : 0.62)),
                        style: StrokeStyle(lineWidth: isSelected ? 1.8 : 1, dash: [4, 4])
                    )
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func deliverySelectionOverlay(in size: CGSize) -> some View {
        if canvasInteractionTool == .move {
            ZStack {
                ForEach(viewModel.availableSlices) { slice in
                    let rect = viewRect(from: slice.frame, in: size)
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            _ = viewModel.selectSlice(id: slice.id)
                        }
                        .zIndex(Double(slice.id.hashValue))
                }
                ForEach(viewModel.availableHotspots) { hotspot in
                    let rect = viewRect(from: hotspot.frame, in: size)
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            _ = viewModel.selectHotspot(id: hotspot.id)
                        }
                        .zIndex(Double(hotspot.id.hashValue) + 0.5)
                }
            }
        }
    }

    @ViewBuilder
    private func layerTransformOverlay(in size: CGSize) -> some View {
        if (canvasInteractionTool == .move || viewModel.hasSelectedXomoObject),
           (viewModel.document.areExtrasVisible || viewModel.hasSelectedXomoObject),
           (viewModel.document.areTransformControlsVisible || viewModel.hasSelectedXomoObject),
           let layerFrame = viewModel.movingObjectPreviewFrame ?? viewModel.selectedLayerTransformFrame {
            let rect = viewRect(from: layerFrame, in: size)
            if let componentKind = viewModel.selectedXomoObjectKind {
                xomoObjectSelectionOutline(
                    kind: componentKind,
                    rect: rect,
                    isMoving: viewModel.movingObjectPreviewFrame != nil
                )
            } else {
                Rectangle()
                    .stroke(
                        Color(nsColor: ImageEditorTheme.selected),
                        style: StrokeStyle(lineWidth: 1.25, dash: [6, 4])
                    )
                    .frame(width: max(1, rect.width), height: max(1, rect.height))
                    .position(x: rect.midX, y: rect.midY)
                    .allowsHitTesting(false)
            }

            if let mode = transformHUDMode {
                transformHUDOverlay(
                    frame: layerFrame,
                    viewRect: rect,
                    mode: mode,
                    canvasSize: size
                )
            }

            if canvasInteractionTool == .move,
               ImageEditorLayerTransformControlLayout.showsControls(
                   areExtrasVisible: viewModel.document.areExtrasVisible,
                   areTransformControlsVisible: viewModel.document.areTransformControlsVisible,
                   hasSelectedXomoObject: viewModel.hasSelectedXomoObject
               ),
               viewModel.canResizeSelectedLayer {
                ForEach(ImageEditorLayerTransformControlLayout.visibleResizeHandles(in: rect)) { handle in
                    resizeHandleView(handle: handle, in: rect, canvasSize: size)
                }
            }

            if canvasInteractionTool == .move,
               ImageEditorLayerTransformControlLayout.showsControls(
                   areExtrasVisible: viewModel.document.areExtrasVisible,
                   areTransformControlsVisible: viewModel.document.areTransformControlsVisible,
                   hasSelectedXomoObject: viewModel.hasSelectedXomoObject
               ),
               viewModel.canRotateSelectedLayer {
                if ImageEditorLayerTransformControlLayout.showsReferencePoint(in: rect) {
                    transformReferencePointView(in: size)
                }
                rotateHandleView(in: rect, canvasSize: size)
            }
        }
    }

    private var transformHUDMode: ImageEditorTransformHUDMode? {
        if viewModel.isResizingSelectedLayer {
            return .resize(scalePercent: viewModel.resizingObjectPreviewScalePercent)
        }
        if let degrees = viewModel.rotatingPreviewDegrees {
            return .rotate(degrees: degrees)
        }
        if viewModel.movingObjectPreviewFrame != nil {
            return .move(delta: viewModel.movingObjectPreviewDelta)
        }
        return nil
    }

    private func transformHUDOverlay(
        frame: CGRect,
        viewRect: CGRect,
        mode: ImageEditorTransformHUDMode,
        canvasSize: CGSize
    ) -> some View {
        let text = ImageEditorTransformHUD.displayText(frame: frame, mode: mode)
        let badgeSize = ImageEditorTransformHUD.badgeSize(for: text)
        let center = ImageEditorTransformHUD.badgeCenter(
            selectionRect: viewRect,
            viewportSize: canvasSize,
            badgeSize: badgeSize
        )
        return Text(text)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(Color.white.opacity(0.94))
            .lineLimit(1)
            .frame(width: badgeSize.width, height: badgeSize.height)
            .background(Color.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 5))
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.white.opacity(0.16), lineWidth: 0.5)
            }
            .position(center)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func shapeGradientControlOverlay(in size: CGSize) -> some View {
        if canvasInteractionTool == .move,
           viewModel.document.areExtrasVisible {
            if let points = viewModel.selectedShapeGradientCanvasHandlePoints {
                linearShapeGradientControlOverlay(points: points, canvasSize: size)
            }
            if let geometry = viewModel.selectedShapeRadialGradientCanvasGeometry {
                radialShapeGradientControlOverlay(geometry: geometry, canvasSize: size)
            }
        }
    }

    private func linearShapeGradientControlOverlay(
        points: ImageEditorShapeGradientHandlePoints,
        canvasSize: CGSize
    ) -> some View {
        let start = viewPoint(from: points.start, in: canvasSize)
        let end = viewPoint(from: points.end, in: canvasSize)
        let axisPath = Path { path in
            path.move(to: start)
            path.addLine(to: end)
        }
        return ZStack {
            axisPath
                .stroke(
                    Color.gray.opacity(0.76),
                    style: StrokeStyle(lineWidth: 1.25, dash: [5, 4])
                )
                .allowsHitTesting(false)

            axisPath
                .stroke(Color.white.opacity(0.001), lineWidth: 18)
                .contentShape(axisPath.strokedPath(StrokeStyle(lineWidth: 18)))
                .gesture(
                    SpatialTapGesture(
                        count: 2,
                        coordinateSpace: .named("image-editor-canvas-space")
                    )
                    .onEnded { value in
                        guard let index = viewModel.addSelectedShapeGradientStop(
                            atCanvasPoint: unboundedImagePoint(from: value.location, in: canvasSize)
                        ) else { return }
                        selectedShapeGradientStopIndex = index
                    }
                )
                .allowsHitTesting(
                    viewModel.canEditSelectedShapeGradient
                        && viewModel.selectedShapeGradientColorStops.count
                            < ImageEditorGradientFillContent.maximumColorStopCount
                )
                .help(L10n.text("imageEditor.help.shapeGradientAxis"))
                .accessibilityIdentifier("image-editor-shape-gradient-axis")

            ForEach(viewModel.selectedShapeGradientCanvasStopHandlePoints) { stopPoint in
                shapeGradientStopHandleView(
                    stopPoint,
                    position: viewPoint(from: stopPoint.canvasPoint, in: canvasSize),
                    canvasSize: canvasSize
                )
            }

            ForEach(ImageEditorShapeGradientHandle.allCases) { handle in
                shapeGradientHandleView(
                    handle: handle,
                    position: handle == .start ? start : end,
                    canvasSize: canvasSize
                )
            }
        }
    }

    private func radialShapeGradientControlOverlay(
        geometry: ImageEditorShapeRadialGradientCanvasGeometry,
        canvasSize: CGSize
    ) -> some View {
        let center = viewPoint(from: geometry.center, in: canvasSize)
        let radius = viewPoint(from: geometry.radius, in: canvasSize)
        let boundary = viewRect(from: geometry.boundaryRect, in: canvasSize)
        let radiusPath = Path { path in
            path.move(to: center)
            path.addLine(to: radius)
        }
        return ZStack {
            Ellipse()
                .stroke(
                    Color.gray.opacity(0.58),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                )
                .frame(width: max(1, boundary.width), height: max(1, boundary.height))
                .position(x: boundary.midX, y: boundary.midY)
                .allowsHitTesting(false)
                .accessibilityIdentifier("image-editor-shape-radial-gradient-boundary")

            radiusPath
                .stroke(
                    Color.gray.opacity(0.76),
                    style: StrokeStyle(lineWidth: 1.25, dash: [5, 4])
                )
                .allowsHitTesting(false)

            radiusPath
                .stroke(Color.white.opacity(0.001), lineWidth: 18)
                .contentShape(radiusPath.strokedPath(StrokeStyle(lineWidth: 18)))
                .gesture(
                    SpatialTapGesture(
                        count: 2,
                        coordinateSpace: .named("image-editor-canvas-space")
                    )
                    .onEnded { value in
                        guard let index = viewModel.addSelectedShapeGradientStop(
                            atCanvasPoint: unboundedImagePoint(from: value.location, in: canvasSize)
                        ) else { return }
                        selectedShapeGradientStopIndex = index
                    }
                )
                .allowsHitTesting(
                    viewModel.canEditSelectedShapeGradientStops
                        && viewModel.selectedShapeGradientColorStops.count
                            < ImageEditorGradientFillContent.maximumColorStopCount
                )
                .help(L10n.text("imageEditor.help.shapeGradientAxis"))
                .accessibilityIdentifier("image-editor-shape-radial-gradient-axis")

            ForEach(viewModel.selectedShapeGradientCanvasStopHandlePoints) { stopPoint in
                shapeGradientStopHandleView(
                    stopPoint,
                    position: viewPoint(from: stopPoint.canvasPoint, in: canvasSize),
                    canvasSize: canvasSize
                )
            }

            ForEach(ImageEditorShapeRadialGradientHandle.allCases) { handle in
                shapeRadialGradientHandleView(
                    handle: handle,
                    position: handle == .center ? center : radius,
                    canvasSize: canvasSize
                )
            }
        }
    }

    private func shapeGradientStopHandleView(
        _ stopPoint: ImageEditorShapeGradientStopHandlePoint,
        position: CGPoint,
        canvasSize: CGSize
    ) -> some View {
        let isSelected = selectedShapeGradientStopIndex == stopPoint.index
        return RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(Color(nsColor: stopPoint.stop.color))
            .overlay {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .stroke(
                        isSelected ? Color.accentColor : Color.white.opacity(0.94),
                        lineWidth: isSelected ? 2 : 1.25
                    )
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .stroke(Color.black.opacity(0.58), lineWidth: 0.5)
                    .padding(-1)
            }
            .frame(width: 11, height: 11)
            .rotationEffect(.degrees(45))
            .position(position)
            .contentShape(Rectangle().inset(by: -7))
            .highPriorityGesture(
                DragGesture(
                    minimumDistance: 0,
                    coordinateSpace: .named("image-editor-canvas-space")
                )
                .onChanged { value in
                    selectedShapeGradientStopIndex = stopPoint.index
                    if activeShapeGradientStopIndex == nil,
                       viewModel.beginEditingSelectedShapeGradientStop(at: stopPoint.index) {
                        activeShapeGradientStopIndex = stopPoint.index
                    }
                    guard activeShapeGradientStopIndex == stopPoint.index else { return }
                    viewModel.updateSelectedShapeGradientStop(
                        to: unboundedImagePoint(from: value.location, in: canvasSize)
                    )
                }
                .onEnded { value in
                    guard activeShapeGradientStopIndex == stopPoint.index else { return }
                    viewModel.updateSelectedShapeGradientStop(
                        to: unboundedImagePoint(from: value.location, in: canvasSize)
                    )
                    viewModel.finishEditingSelectedShapeGradient()
                    activeShapeGradientStopIndex = nil
                }
            )
            .opacity(viewModel.canEditSelectedShapeGradientStops ? 1 : 0.55)
            .help(L10n.text("imageEditor.help.shapeGradientStopHandle"))
            .accessibilityIdentifier("image-editor-shape-gradient-canvas-stop-\(stopPoint.index)")
    }

    private func deleteSelectedShapeGradientStopIfNeeded() -> Bool {
        let stops = viewModel.selectedShapeGradientColorStops
        let index = selectedShapeGradientStopIndex
        guard canvasInteractionTool == .move,
              viewModel.document.areExtrasVisible,
              viewModel.canEditSelectedShapeGradientStops,
              !viewModel.selectedShapeGradientCanvasStopHandlePoints.isEmpty,
              index > 0,
              index < stops.count - 1,
              let nextIndex = viewModel.removeSelectedShapeGradientCanvasStop(at: index)
        else { return false }
        selectedShapeGradientStopIndex = nextIndex
        return true
    }

    private func shapeGradientHandleView(
        handle: ImageEditorShapeGradientHandle,
        position: CGPoint,
        canvasSize: CGSize
    ) -> some View {
        Circle()
            .fill(shapeGradientHandleColor(handle))
            .overlay {
                Circle()
                    .stroke(Color.white.opacity(0.96), lineWidth: 1.5)
                Circle()
                    .stroke(Color.black.opacity(0.62), lineWidth: 0.5)
                    .padding(-1)
            }
            .frame(width: 12, height: 12)
            .position(position)
            .contentShape(Circle().inset(by: -6))
            .highPriorityGesture(
                DragGesture(
                    minimumDistance: 0,
                    coordinateSpace: .named("image-editor-canvas-space")
                )
                .onChanged { value in
                    if activeShapeGradientHandle == nil,
                       viewModel.beginEditingSelectedShapeGradient(handle: handle) {
                        activeShapeGradientHandle = handle
                    }
                    guard activeShapeGradientHandle == handle else { return }
                    viewModel.updateSelectedShapeGradient(
                        handle: handle,
                        to: unboundedImagePoint(from: value.location, in: canvasSize),
                        snappingAngle: NSEvent.modifierFlags.contains(.shift)
                    )
                }
                .onEnded { value in
                    guard activeShapeGradientHandle == handle else { return }
                    viewModel.updateSelectedShapeGradient(
                        handle: handle,
                        to: unboundedImagePoint(from: value.location, in: canvasSize),
                        snappingAngle: NSEvent.modifierFlags.contains(.shift)
                    )
                    viewModel.finishEditingSelectedShapeGradient()
                    activeShapeGradientHandle = nil
                }
            )
            .opacity(viewModel.canEditSelectedShapeGradient ? 1 : 0.55)
            .help(L10n.text("imageEditor.help.shapeGradientHandle.\(handle.rawValue)"))
            .accessibilityIdentifier("image-editor-shape-gradient-handle-\(handle.rawValue)")
    }

    private func shapeRadialGradientHandleView(
        handle: ImageEditorShapeRadialGradientHandle,
        position: CGPoint,
        canvasSize: CGSize
    ) -> some View {
        Circle()
            .fill(shapeGradientHandleColor(handle == .center ? .start : .end))
            .overlay {
                Circle()
                    .stroke(Color.white.opacity(0.9), lineWidth: 1.25)
                Circle()
                    .stroke(Color.black.opacity(0.62), lineWidth: 0.5)
                    .padding(-1)
                if handle == .center {
                    Circle()
                        .fill(Color.black.opacity(0.72))
                        .overlay {
                            Circle()
                                .stroke(Color.white.opacity(0.88), lineWidth: 0.5)
                        }
                        .frame(width: 4, height: 4)
                }
            }
            .frame(width: 12, height: 12)
            .position(position)
            .contentShape(Circle().inset(by: -6))
            .highPriorityGesture(
                DragGesture(
                    minimumDistance: 0,
                    coordinateSpace: .named("image-editor-canvas-space")
                )
                .onChanged { value in
                    if activeShapeRadialGradientHandle == nil,
                       viewModel.beginEditingSelectedShapeRadialGradient(handle: handle) {
                        activeShapeRadialGradientHandle = handle
                    }
                    guard activeShapeRadialGradientHandle == handle else { return }
                    viewModel.updateSelectedShapeRadialGradient(
                        handle: handle,
                        to: unboundedImagePoint(from: value.location, in: canvasSize)
                    )
                }
                .onEnded { value in
                    guard activeShapeRadialGradientHandle == handle else { return }
                    viewModel.updateSelectedShapeRadialGradient(
                        handle: handle,
                        to: unboundedImagePoint(from: value.location, in: canvasSize)
                    )
                    viewModel.finishEditingSelectedShapeGradient()
                    activeShapeRadialGradientHandle = nil
                }
            )
            .opacity(viewModel.canEditSelectedShapeRadialGradient ? 1 : 0.55)
            .help(L10n.text("imageEditor.help.shapeRadialGradientHandle.\(handle.rawValue)"))
            .accessibilityIdentifier(
                "image-editor-shape-radial-gradient-handle-\(handle.rawValue)"
            )
    }

    private func shapeGradientHandleColor(_ handle: ImageEditorShapeGradientHandle) -> Color {
        guard let gradient = viewModel.document.selectedLayer?.shapeContent?.fillGradient else {
            return Color.gray
        }
        return Color(
            nsColor: ImageEditorShapeGradientGeometry.displayedEndpointColor(
                gradient: gradient,
                handle: handle
            )
        )
    }

    @ViewBuilder
    private func textBoxOverflowOverlay(in size: CGSize) -> some View {
        if canvasInteractionTool == .move,
           viewModel.document.areExtrasVisible,
           viewModel.document.areTransformControlsVisible,
           viewModel.selectedTextBoxHasOverflow,
           let layerFrame = viewModel.selectedLayerTransformFrame {
            let rect = viewRect(from: layerFrame, in: size)
            ZStack {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(Color(nsColor: ImageEditorTheme.panel).opacity(0.96))
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .stroke(Color.orange.opacity(0.92), lineWidth: 1.2)
                Image(systemName: "plus")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(Color.orange.opacity(0.96))
            }
            .frame(width: 11, height: 11)
            .position(x: rect.maxX - 8, y: rect.maxY - 8)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func xomoObjectSelectionOutline(
        kind: XomoComponentKind,
        rect: CGRect,
        isMoving: Bool
    ) -> some View {
        if isMoving {
            TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
                xomoObjectSelectionOutlineContent(
                    kind: kind,
                    rect: rect,
                    isMoving: true,
                    dashPhase: ImageEditorSelectionMarchingAnts.dashPhase(
                        at: timeline.date.timeIntervalSinceReferenceDate
                    )
                )
            }
        } else {
            xomoObjectSelectionOutlineContent(
                kind: kind,
                rect: rect,
                isMoving: false,
                dashPhase: 0
            )
        }
    }

    private func xomoObjectSelectionOutlineContent(
        kind: XomoComponentKind,
        rect: CGRect,
        isMoving: Bool,
        dashPhase: CGFloat
    ) -> some View {
        let shape: AnyShape
        switch kind {
        case .avatar, .badge:
            shape = AnyShape(Circle())
        case .toggle, .tag:
            shape = AnyShape(Capsule())
        default:
            shape = AnyShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        let accent = Color(nsColor: ImageEditorTheme.selected)
        return shape
            .fill(accent.opacity(isMoving ? 0.08 : 0.055))
            .overlay {
                shape.stroke(
                    Color.gray.opacity(isMoving ? 0.82 : 0.72),
                    style: StrokeStyle(
                        lineWidth: isMoving ? 1.5 : 1.25,
                        dash: [6, 4],
                        dashPhase: dashPhase
                    )
                )
            }
            .shadow(color: accent.opacity(isMoving ? 0.10 : 0.24), radius: isMoving ? 2 : 5)
            .frame(width: max(1, rect.width), height: max(1, rect.height))
            .position(x: rect.midX, y: rect.midY)
            .allowsHitTesting(false)
    }

    private func resizeHandleView(
        handle: ImageEditorLayerResizeHandle,
        in rect: CGRect,
        canvasSize: CGSize
    ) -> some View {
        let point = resizeHandleViewPoint(handle, in: rect)
        return RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(Color.white.opacity(0.95))
            .overlay(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .stroke(Color(nsColor: ImageEditorTheme.selected), lineWidth: 1.5)
            )
            .frame(width: 10, height: 10)
            .position(point)
            .contentShape(Rectangle().inset(by: -4))
            .highPriorityGesture(
                DragGesture(
                    minimumDistance: 0,
                    coordinateSpace: .named("image-editor-canvas-space")
                )
                    .onChanged { value in
                        if activeResizeHandle == nil {
                            activeResizeHandle = handle
                            viewModel.beginResizingSelectedLayer(handle: handle.transformModelHandle)
                            ImageEditorCanvasCursor.transformCursor(for: .resize(handle)).set()
                        }
                        viewModel.resizeSelectedLayer(
                            to: unboundedImagePoint(from: value.location, in: canvasSize),
                            handle: handle.transformModelHandle,
                            preservingAspectRatio: NSEvent.modifierFlags.contains(.shift),
                            resizingFromCenter: NSEvent.modifierFlags.contains(.option)
                        )
                    }
                    .onEnded { _ in
                        viewModel.finishResizingSelectedLayer()
                        activeResizeHandle = nil
                        refreshCanvasCursor(in: canvasSize)
                    }
            )
            .help(L10n.text("imageEditor.action.layerResizeHandle"))
    }

    private func rotateHandleView(
        in rect: CGRect,
        canvasSize: CGSize
    ) -> some View {
        let topPoint = CGPoint(x: rect.midX, y: rect.minY)
        let handlePoint = rotateHandleViewPoint(in: rect)
        return ZStack {
            Path { path in
                path.move(to: topPoint)
                path.addLine(to: handlePoint)
            }
            .stroke(Color(nsColor: ImageEditorTheme.selected).opacity(0.75), lineWidth: 1.4)
            .allowsHitTesting(false)

            Circle()
                .fill(Color.white.opacity(0.96))
                .overlay(
                    Circle()
                        .stroke(Color(nsColor: ImageEditorTheme.selected), lineWidth: 1.6)
                )
                .overlay {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color(nsColor: ImageEditorTheme.selected))
                }
                .frame(width: 16, height: 16)
                .position(handlePoint)
                .contentShape(Rectangle().inset(by: -1))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isRotatingLayer {
                                isRotatingLayer = true
                                viewModel.beginRotatingSelectedLayer(
                                    from: unboundedImagePoint(from: value.startLocation, in: canvasSize)
                                )
                                ImageEditorCanvasCursor.transformCursor(for: .rotate).set()
                            }
                            viewModel.rotateSelectedLayer(
                                to: unboundedImagePoint(from: value.location, in: canvasSize),
                                snappingToStep: NSEvent.modifierFlags.contains(.shift)
                            )
                        }
                        .onEnded { _ in
                            viewModel.finishRotatingSelectedLayer()
                            isRotatingLayer = false
                            refreshCanvasCursor(in: canvasSize)
                        }
                )
                .help(L10n.text("imageEditor.action.layerRotateHandle"))
        }
    }

    private func transformReferencePointView(in canvasSize: CGSize) -> some View {
        let imagePoint = viewModel.selectedLayerTransformReferencePoint ?? .zero
        let point = viewPoint(from: imagePoint, in: canvasSize)
        return ZStack {
            Circle()
                .fill(Color(nsColor: ImageEditorTheme.panel).opacity(0.88))
            Circle()
                .stroke(Color.white.opacity(0.92), lineWidth: 1)
            Path { path in
                path.move(to: CGPoint(x: 2, y: 7))
                path.addLine(to: CGPoint(x: 12, y: 7))
                path.move(to: CGPoint(x: 7, y: 2))
                path.addLine(to: CGPoint(x: 7, y: 12))
            }
            .stroke(Color(nsColor: ImageEditorTheme.selected), lineWidth: 1.25)
        }
        .frame(width: 14, height: 14)
        .position(point)
        .contentShape(Circle().inset(by: -5))
        .highPriorityGesture(
            DragGesture(
                minimumDistance: 0,
                coordinateSpace: .named("image-editor-canvas-space")
            )
            .onChanged { value in
                guard !isTransformReferencePointDragCancelled else { return }
                viewModel.beginSelectedLayerTransformReferencePointDrag()
                isMovingTransformReferencePoint = true
                viewModel.setSelectedLayerTransformReferencePoint(
                    unboundedImagePoint(from: value.location, in: canvasSize)
                )
                NSCursor.crosshair.set()
            }
            .onEnded { value in
                if !isTransformReferencePointDragCancelled {
                    viewModel.setSelectedLayerTransformReferencePoint(
                        unboundedImagePoint(from: value.location, in: canvasSize)
                    )
                }
                viewModel.finishSelectedLayerTransformReferencePointDrag()
                isMovingTransformReferencePoint = false
                isTransformReferencePointDragCancelled = false
                refreshCanvasCursor(in: canvasSize)
            }
        )
        .simultaneousGesture(
            TapGesture(count: 2)
                .onEnded {
                    DispatchQueue.main.async {
                        _ = viewModel.resetSelectedLayerTransformReferencePoint()
                        refreshCanvasCursor(in: canvasSize)
                    }
                }
        )
        .help(L10n.text("imageEditor.action.layerTransformReferencePoint"))
        .accessibilityIdentifier("image-editor-transform-reference-point")
    }

    private func viewRect(from imageRect: CGRect, in size: CGSize) -> CGRect {
        ImageEditorCanvasGeometry.viewRect(
            from: imageRect,
            imageRect: fittedImageRect(in: size),
            canvasSize: viewModel.document.canvasSize
        )
    }

    private func resizeHandleViewPoint(_ handle: ImageEditorLayerResizeHandle, in rect: CGRect) -> CGPoint {
        ImageEditorCanvasCursor.transformHandlePoint(handle, in: rect)
    }

    private func rotateHandleViewPoint(in rect: CGRect) -> CGPoint {
        ImageEditorCanvasCursor.transformRotateHandlePoint(in: rect)
    }

    @ViewBuilder
    private func figmaComponentPropertyEditor(
        key: String,
        property: XomoFigmaComponentProperty
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 7) {
                Text(key)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                Spacer(minLength: 0)
                Text(property.type)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                if viewModel.hasSelectedFigmaComponentPropertyOverride(key, property: property) {
                    Button(L10n.text("imageEditor.properties.figmaComponentPropertyReset")) {
                        viewModel.resetSelectedFigmaComponentProperty(key)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .font(.system(size: 9))
                    .focusable(false)
                    .xomoFocusEffectDisabled()
                    .accessibilityIdentifier("image-editor-figma-property-reset-\(key)")
                }
            }

            if property.type == "BOOLEAN" {
                Toggle(
                    L10n.text("imageEditor.properties.figmaComponentPropertyEnabled"),
                    isOn: Binding(
                        get: { property.value.lowercased() == "true" },
                        set: { viewModel.updateSelectedFigmaComponentBooleanProperty(key, isEnabled: $0) }
                    )
                )
                .toggleStyle(.switch)
                .font(.system(size: 10))
                .focusable(false)
                .accessibilityIdentifier("image-editor-figma-property-boolean-\(key)")
            } else if !property.preferredValues.isEmpty {
                Picker(
                    L10n.text("imageEditor.properties.figmaComponentPropertyValue"),
                    selection: Binding(
                        get: {
                            property.preferredValues.first {
                                $0.name == property.value || $0.key == property.value
                            }?.name ?? property.value
                        },
                        set: { viewModel.updateSelectedFigmaComponentProperty(key, value: $0) }
                    )
                ) {
                    ForEach(property.preferredValues, id: \.key) { preferredValue in
                        Text(preferredValue.name).tag(preferredValue.name)
                    }
                }
                .pickerStyle(.menu)
                .focusable(false)
                .accessibilityIdentifier("image-editor-figma-property-picker-\(key)")
            } else {
                TextField(
                    L10n.text("imageEditor.properties.figmaComponentPropertyValue"),
                    text: figmaComponentPropertyDraftBinding(key)
                )
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 10))
                .onSubmit {
                    let value = figmaComponentPropertyDrafts[key] ?? property.value
                    viewModel.updateSelectedFigmaComponentProperty(key, value: value)
                }
                .accessibilityIdentifier("image-editor-figma-property-text-\(key)")
            }
        }
    }

    private func figmaImageFillRow(
        titleKey: String,
        value: String,
        monospaced: Bool = false
    ) -> some View {
        HStack(spacing: 7) {
            Text(L10n.text(titleKey))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
            Text(value)
                .font(.system(size: 10, design: monospaced ? .monospaced : .default))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
    }

    private var adjustmentValueControls: AnyView {
        switch viewModel.selectedAdjustment {
        case .levels:
            return AnyView(levelsControls)
        case .curves:
            return AnyView(curvesControls)
        case .colorBalance:
            return AnyView(colorBalanceControls)
        case .hueSaturation:
            return AnyView(hueSaturationControls)
        case .brightnessContrast:
            return AnyView(brightnessContrastControls)
        case .exposure:
            return AnyView(exposureControls)
        case .shadowsHighlights:
            return AnyView(shadowsHighlightsControls)
        case .vibrance:
            return AnyView(vibranceControls)
        case .posterize:
            return AnyView(posterizeControls)
        case .blackWhite:
            return AnyView(blackWhiteControls)
        case .channelMixer:
            return AnyView(channelMixerControls)
        case .photoFilter:
            return AnyView(photoFilterControls)
        case .colorLookup:
            return AnyView(colorLookupControls)
        case .selectiveColor:
            return AnyView(selectiveColorControls)
        case .gradientMap:
            return AnyView(gradientMapControls)
        default:
            return AnyView(
                Slider(value: $viewModel.adjustmentValue, in: -1...1, step: 0.05)
            )
        }
    }

    private func propertiesPanel(showsTitle: Bool = true) -> some View {
        EditorPanel(title: L10n.text("imageEditor.panel.properties"), showsTitle: showsTitle) {
            VStack(alignment: .leading, spacing: 10) {
                AnyView(Group {
                Text(L10n.text("imageEditor.properties.layerName"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))

                HStack(spacing: 8) {
                    TextField(L10n.text("imageEditor.properties.layerNamePlaceholder"), text: $layerNameDraft)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            commitLayerNameDraft()
                        }

                    Button(L10n.text("imageEditor.action.layerRename")) {
                        commitLayerNameDraft()
                    }
                    .buttonStyle(EditorTextButtonStyle())
                    .disabled(layerNameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if !viewModel.selectedLayersFigmaVariableBindings.isEmpty {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 8) {
                            Text(L10n.text("imageEditor.properties.figmaVariables"))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                            Spacer(minLength: 4)
                            Button(L10n.text("imageEditor.action.copyFigmaVariables")) {
                                viewModel.copySelectedFigmaVariableBindings()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                            .focusable(false)
                            .accessibilityIdentifier("image-editor-copy-figma-variables")
                        }

                        ForEach(viewModel.selectedLayersFigmaVariableBindings) { binding in
                            HStack(spacing: 7) {
                                Text(binding.field)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                                    .frame(minWidth: 58, alignment: .leading)
                                Text(binding.variableID)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer(minLength: 0)
                                Button {
                                    viewModel.copyFigmaVariableBinding(binding)
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                }
                                .buttonStyle(EditorIconButtonStyle(isSelected: false))
                                .focusable(false)
                                .help(L10n.text("imageEditor.action.copyFigmaVariable"))
                                .accessibilityLabel(L10n.text("imageEditor.action.copyFigmaVariable"))
                                .accessibilityIdentifier("image-editor-copy-figma-variable-\(binding.id)")
                            }
                        }
                    }

                    Divider().overlay(editorBorder)
                }

                if let sourceID = viewModel.selectedLayerFigmaSourceID {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 8) {
                            Text(L10n.text("imageEditor.properties.figmaSource"))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                            Spacer(minLength: 4)
                            Button(L10n.text("imageEditor.action.copyFigmaSource")) {
                                viewModel.copySelectedFigmaSourceReference()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                            .focusable(false)
                            .accessibilityIdentifier("image-editor-copy-figma-source")
                            if viewModel.selectedLayerFigmaSourceURL != nil {
                                Button(L10n.text("imageEditor.action.copyFigmaSourceURL")) {
                                    viewModel.copySelectedFigmaSourceURL()
                                }
                                .buttonStyle(EditorTextButtonStyle())
                                .focusable(false)
                                .accessibilityIdentifier("image-editor-copy-figma-source-url")
                            }
                        }

                        HStack(spacing: 7) {
                            Text(L10n.text("imageEditor.properties.figmaSourceType"))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                            Text(viewModel.selectedLayerFigmaNodeType ?? "—")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                            Spacer(minLength: 0)
                        }

                        if let role = viewModel.selectedLayerFigmaComponentRole {
                            HStack(spacing: 7) {
                                Text(L10n.text("imageEditor.properties.figmaComponentRole"))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                                Text(role.rawValue)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                                Spacer(minLength: 0)
                            }
                        }

                        Text(sourceID)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    Divider().overlay(editorBorder)
                }

                })

                AnyView(Group {

                if let imageFill = viewModel.selectedLayerFigmaImageFill {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 8) {
                            Text(L10n.text("imageEditor.properties.figmaImageFill"))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                            Spacer(minLength: 4)
                            Button(L10n.text("imageEditor.action.copyFigmaImageFill")) {
                                viewModel.copySelectedFigmaImageFill()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                            .focusable(false)
                            .accessibilityIdentifier("image-editor-copy-figma-image-fill")
                        }

                        figmaImageFillRow(
                            titleKey: "imageEditor.properties.figmaImageReference",
                            value: imageFill.imageReference,
                            monospaced: true
                        )
                        Picker(
                            L10n.text("imageEditor.properties.figmaImageScaleMode"),
                            selection: Binding(
                                get: { viewModel.selectedLayerFigmaImageFillScaleMode },
                                set: { viewModel.updateSelectedFigmaImageFillScaleMode($0) }
                            )
                        ) {
                            ForEach(ImageEditorViewModel.figmaImageFillScaleModes, id: \.self) { mode in
                                Text(mode).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)
                        .focusable(false)
                        .disabled(!viewModel.canEditSelectedFigmaImageFill)
                        .accessibilityIdentifier("image-editor-figma-image-fill-scale-mode")

                        Stepper(
                            L10n.format(
                                "imageEditor.properties.figmaImageScalingFactorValue",
                                viewModel.selectedLayerFigmaImageFillScalingFactor
                            ),
                            value: Binding(
                                get: { viewModel.selectedLayerFigmaImageFillScalingFactor },
                                set: { viewModel.updateSelectedFigmaImageFillScalingFactor($0) }
                            ),
                            in: 0.01...100,
                            step: 0.1
                        )
                        .focusable(false)
                        .disabled(!viewModel.canEditSelectedFigmaImageFill)
                        .accessibilityIdentifier("image-editor-figma-image-fill-scaling-factor")

                        Stepper(
                            L10n.format(
                                "imageEditor.properties.figmaImageRotationValue",
                                viewModel.selectedLayerFigmaImageFillRotation
                            ),
                            value: Binding(
                                get: { viewModel.selectedLayerFigmaImageFillRotation },
                                set: { viewModel.updateSelectedFigmaImageFillRotation($0) }
                            ),
                            in: -720...720,
                            step: 1
                        )
                        .focusable(false)
                        .disabled(!viewModel.canEditSelectedFigmaImageFill)
                        .accessibilityIdentifier("image-editor-figma-image-fill-rotation")

                        Stepper(
                            L10n.format(
                                "imageEditor.properties.figmaImageOffsetXValue",
                                viewModel.selectedLayerFigmaImageFillOffsetX
                            ),
                            value: Binding(
                                get: { viewModel.selectedLayerFigmaImageFillOffsetX },
                                set: { viewModel.updateSelectedFigmaImageFillOffsetX($0) }
                            ),
                            in: -10...10,
                            step: 0.01
                        )
                        .focusable(false)
                        .disabled(!viewModel.canEditSelectedFigmaImageFill)
                        .accessibilityIdentifier("image-editor-figma-image-fill-offset-x")

                        Stepper(
                            L10n.format(
                                "imageEditor.properties.figmaImageOffsetYValue",
                                viewModel.selectedLayerFigmaImageFillOffsetY
                            ),
                            value: Binding(
                                get: { viewModel.selectedLayerFigmaImageFillOffsetY },
                                set: { viewModel.updateSelectedFigmaImageFillOffsetY($0) }
                            ),
                            in: -10...10,
                            step: 0.01
                        )
                        .focusable(false)
                        .disabled(!viewModel.canEditSelectedFigmaImageFill)
                        .accessibilityIdentifier("image-editor-figma-image-fill-offset-y")

                        HStack(spacing: 7) {
                            Stepper(
                                L10n.format(
                                    "imageEditor.properties.figmaImageMatrixM11Value",
                                    viewModel.selectedLayerFigmaImageFillMatrixM11
                                ),
                                value: Binding(
                                    get: { viewModel.selectedLayerFigmaImageFillMatrixM11 },
                                    set: { viewModel.updateSelectedFigmaImageFillMatrixM11($0) }
                                ),
                                in: -10...10,
                                step: 0.01
                            )
                            Stepper(
                                L10n.format(
                                    "imageEditor.properties.figmaImageMatrixM12Value",
                                    viewModel.selectedLayerFigmaImageFillMatrixM12
                                ),
                                value: Binding(
                                    get: { viewModel.selectedLayerFigmaImageFillMatrixM12 },
                                    set: { viewModel.updateSelectedFigmaImageFillMatrixM12($0) }
                                ),
                                in: -10...10,
                                step: 0.01
                            )
                        }
                        .focusable(false)
                        .disabled(!viewModel.canEditSelectedFigmaImageFill)
                        .accessibilityIdentifier("image-editor-figma-image-fill-matrix-row-1")

                        HStack(spacing: 7) {
                            Stepper(
                                L10n.format(
                                    "imageEditor.properties.figmaImageMatrixM21Value",
                                    viewModel.selectedLayerFigmaImageFillMatrixM21
                                ),
                                value: Binding(
                                    get: { viewModel.selectedLayerFigmaImageFillMatrixM21 },
                                    set: { viewModel.updateSelectedFigmaImageFillMatrixM21($0) }
                                ),
                                in: -10...10,
                                step: 0.01
                            )
                            Stepper(
                                L10n.format(
                                    "imageEditor.properties.figmaImageMatrixM22Value",
                                    viewModel.selectedLayerFigmaImageFillMatrixM22
                                ),
                                value: Binding(
                                    get: { viewModel.selectedLayerFigmaImageFillMatrixM22 },
                                    set: { viewModel.updateSelectedFigmaImageFillMatrixM22($0) }
                                ),
                                in: -10...10,
                                step: 0.01
                            )
                        }
                        .focusable(false)
                        .disabled(!viewModel.canEditSelectedFigmaImageFill)
                        .accessibilityIdentifier("image-editor-figma-image-fill-matrix-row-2")

                        Toggle(
                            L10n.text("imageEditor.properties.figmaImageFillFiltersEnabled"),
                            isOn: Binding(
                                get: { viewModel.selectedLayerFigmaImageFillFiltersEnabled },
                                set: { viewModel.setSelectedFigmaImageFillFiltersEnabled($0) }
                            )
                        )
                        .toggleStyle(.switch)
                        .font(.system(size: 10))
                        .focusable(false)
                        .accessibilityIdentifier("image-editor-figma-image-fill-filters-enabled")
                    }

                    Divider().overlay(editorBorder)
                }

                })

                AnyView(Group {

                if viewModel.hasSelectedLayerFigmaComponentProperties {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 8) {
                            Text(L10n.text("imageEditor.properties.figmaComponentProperties"))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                            Spacer(minLength: 4)
                            Button(L10n.text("imageEditor.action.copyFigmaComponentProperties")) {
                                viewModel.copySelectedFigmaComponentProperties()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                            .focusable(false)
                            .accessibilityIdentifier("image-editor-copy-figma-component-properties")
                        }

                        ForEach(viewModel.selectedLayerFigmaComponentProperties.keys.sorted(), id: \.self) { key in
                            if let property = viewModel.selectedLayerFigmaComponentProperties[key] {
                                figmaComponentPropertyEditor(key: key, property: property)
                            }
                        }
                    }

                    Divider().overlay(editorBorder)
                }

                })

                AnyView(Group {

                Divider().overlay(editorBorder)

                if viewModel.selectedLayerIsShape {
                    shapeStyleControls
                    Divider().overlay(editorBorder)
                }

                if viewModel.selectedRectangleCornerRadius != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(
                            L10n.text("imageEditor.properties.shapeCornerRadiiIndependent"),
                            isOn: Binding(
                                get: {
                                    viewModel.selectedRectangleUsesIndependentCornerRadii ?? false
                                },
                                set: {
                                    viewModel.setSelectedRectangleUsesIndependentCornerRadii($0)
                                }
                            )
                        )
                        .toggleStyle(.switch)
                        .focusable(false)
                        .accessibilityIdentifier("image-editor-shape-independent-corners")

                        Stepper(
                            L10n.format(
                                "imageEditor.properties.shapeCornerSmoothingValue",
                                Int(
                                    (viewModel.selectedRectangleCornerSmoothingPercent ?? 0)
                                        .rounded()
                                )
                            ),
                            value: Binding(
                                get: {
                                    viewModel.selectedRectangleCornerSmoothingPercent ?? 0
                                },
                                set: {
                                    viewModel.setSelectedRectangleCornerSmoothingPercent($0)
                                }
                            ),
                            in: 0...100,
                            step: 1
                        )
                        .focusable(false)
                        .accessibilityIdentifier("image-editor-shape-corner-smoothing")

                        if viewModel.selectedRectangleUsesIndependentCornerRadii == true {
                            ForEach(ImageEditorRectangleCorner.allCases) { corner in
                                Stepper(
                                    L10n.format(
                                        "imageEditor.properties.shapeCornerValue",
                                        corner.title,
                                        Int(viewModel.selectedRectangleCornerRadius(at: corner).rounded())
                                    ),
                                    value: Binding(
                                        get: {
                                            viewModel.selectedRectangleCornerRadius(at: corner)
                                        },
                                        set: {
                                            viewModel.setSelectedRectangleCornerRadius($0, at: corner)
                                        }
                                    ),
                                    in: 0...max(
                                        1,
                                        viewModel.selectedRectangleMaximumCornerRadius
                                    ),
                                    step: 1
                                )
                                .focusable(false)
                                .accessibilityIdentifier(
                                    "image-editor-shape-corner-\(corner.rawValue)"
                                )
                            }
                        } else {
                            Stepper(
                                L10n.format(
                                    "imageEditor.properties.shapeCornerRadiusValue",
                                    Int((viewModel.selectedRectangleCornerRadius ?? 0).rounded())
                                ),
                                value: Binding(
                                    get: { viewModel.selectedRectangleCornerRadius ?? 0 },
                                    set: { viewModel.setSelectedRectangleCornerRadius($0) }
                                ),
                                in: 0...max(
                                    1,
                                    viewModel.selectedRectangleMaximumCornerRadius
                                ),
                                step: 1
                            )
                            .focusable(false)
                            .accessibilityIdentifier("image-editor-shape-corner-radius")
                        }
                    }

                    Divider().overlay(editorBorder)
                }

                if viewModel.selectedStackLayout != nil {
                    ImageEditorStackLayoutControls(viewModel: viewModel)
                    Divider().overlay(editorBorder)
                }

                if viewModel.selectedStackChildLayout != nil {
                    ImageEditorStackChildLayoutControls(viewModel: viewModel)
                    Divider().overlay(editorBorder)
                }
                })

                AnyView(Group {
                selectedLayerTransformControls

                Divider().overlay(editorBorder)

                documentSizeControls

                Divider().overlay(editorBorder)

                Picker(L10n.text("imageEditor.properties.adjustment"), selection: $viewModel.selectedAdjustment) {
                    ForEach(ImageEditorAdjustment.allCases) { adjustment in
                        Text(adjustment.title).tag(adjustment)
                    }
                }
                adjustmentValueControls

                })

                AnyView(Group {

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Button(L10n.text("imageEditor.action.applyAdjustment")) {
                            viewModel.applyAdjustment()
                        }
                        .buttonStyle(EditorPrimaryButtonStyle())
                        Button(L10n.text("imageEditor.action.layerAdjustmentNew")) {
                            viewModel.addAdjustmentLayer()
                        }
                        .buttonStyle(EditorTextButtonStyle())
                        if viewModel.selectedLayerIsAdjustment {
                            Button(L10n.text("imageEditor.action.layerAdjustmentUpdate")) {
                                viewModel.updateSelectedAdjustmentLayer()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                        }
                    }
                    HStack {
                        Button(L10n.text("imageEditor.action.selectAll")) {
                            viewModel.selectAll()
                        }
                        .buttonStyle(EditorTextButtonStyle())
                        Button(L10n.text("imageEditor.action.selectionFromLayer")) {
                            viewModel.loadSelectionFromLayerTransparency()
                        }
                        .buttonStyle(EditorTextButtonStyle())
                        .disabled(!viewModel.canLoadSelectionFromLayerTransparency)
                        Button(L10n.text("imageEditor.action.cropCenter")) {
                            viewModel.cropCenter()
                        }
                        .buttonStyle(EditorTextButtonStyle())
                    }
                    if viewModel.hasSelection {
                        HStack(spacing: 8) {
                            Text(L10n.text("imageEditor.option.selectionModifyAmount"))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                            Slider(value: $viewModel.selectionModifyAmount, in: 1...64, step: 1)
                            Text("\(Int(viewModel.selectionModifyAmount.rounded()))px")
                                .font(.system(size: 10, weight: .medium).monospacedDigit())
                                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                                .frame(width: 36, alignment: .trailing)
                        }
                        HStack {
                            Button(L10n.text("imageEditor.action.expandSelection")) {
                                viewModel.expandSelection()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                            Button(L10n.text("imageEditor.action.contractSelection")) {
                                viewModel.contractSelection()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                            Button(L10n.text("imageEditor.action.featherSelection")) {
                                viewModel.featherSelection()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                            Button(L10n.text("imageEditor.action.borderSelection")) {
                                viewModel.borderSelection()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                            Button(L10n.text("imageEditor.action.smoothSelection")) {
                                viewModel.smoothSelection()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                        }
                        HStack {
                            Button(L10n.text("imageEditor.action.selectionCenterHorizontal")) {
                                viewModel.centerSelectionHorizontally()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                            Button(L10n.text("imageEditor.action.selectionCenterVertical")) {
                                viewModel.centerSelectionVertically()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                            Button(L10n.text("imageEditor.action.selectionCenterCanvas")) {
                                viewModel.centerSelectionInCanvas()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                        }
                    }
                    HStack {
                        if viewModel.hasSelection {
                            Button(L10n.text("imageEditor.action.fillSelection")) {
                                viewModel.fillSelection()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                            .disabled(!viewModel.canEditSelectionPixels)
                            Button(L10n.text("imageEditor.action.contentAwareFillSelection")) {
                                viewModel.contentAwareFillSelection()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                            .disabled(!viewModel.canEditSelectionPixels)
                            Button(L10n.text("imageEditor.action.strokeSelection")) {
                                viewModel.strokeSelection()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                            .disabled(!viewModel.canEditSelectionPixels)
                            Button(L10n.text("imageEditor.action.selectionCopyLayer")) {
                                viewModel.copySelectionToNewLayer()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                            .disabled(!viewModel.canCopySelectionToNewLayer)
                            Button(L10n.text("imageEditor.action.selectionCutLayer")) {
                                viewModel.cutSelectionToNewLayer()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                            .disabled(!viewModel.canCutSelectionToNewLayer)
                        }
                    }
                    HStack {
                        if viewModel.hasSelection {
                            Button(L10n.text("imageEditor.action.clearSelectionPixels")) {
                                viewModel.clearSelectionPixels()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                            .disabled(!viewModel.canRemoveSelectionPixels)
                        }
                    }
                    HStack {
                        if viewModel.hasSelection {
                            Button(L10n.text("imageEditor.action.invertSelection")) {
                                viewModel.invertSelection()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                            Button(L10n.text("imageEditor.action.saveSelection")) {
                                viewModel.saveCurrentSelection()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                            Button(L10n.text("imageEditor.action.clearSelection")) {
                                viewModel.clearSelection()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                        }
                        Button(L10n.text("imageEditor.action.reselectSelection")) {
                            viewModel.reselectSelection()
                        }
                        .buttonStyle(EditorTextButtonStyle())
                        .disabled(!viewModel.canReselectSelection)
                        Button(L10n.text("imageEditor.action.restoreSelection")) {
                            viewModel.restoreSavedSelection()
                        }
                        .buttonStyle(EditorTextButtonStyle())
                        .disabled(!viewModel.hasSavedSelection)
                    }
                }

                Divider().overlay(editorBorder)

                solidColorFillControls

                Divider().overlay(editorBorder)

                patternFillControls

                Divider().overlay(editorBorder)

                gradientFillControls
                })

                AnyView(Group {
                Divider().overlay(editorBorder)

                Picker(L10n.text("imageEditor.properties.filter"), selection: $viewModel.selectedFilter) {
                    ForEach(ImageEditorFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                Slider(value: $viewModel.filterIntensity, in: 0...1, step: 0.05)
                if viewModel.selectedFilter == .unsharpMask {
                    HStack {
                        Text(L10n.text("imageEditor.filter.unsharpRadius"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        Slider(value: $viewModel.filterUnsharpRadius, in: 0.5...5, step: 0.5)
                        Text(L10n.format("imageEditor.filter.unsharpRadiusValue", String(format: "%.1f", viewModel.filterUnsharpRadius)))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                            .frame(width: 44, alignment: .trailing)
                    }
                    HStack {
                        Text(L10n.text("imageEditor.filter.unsharpThreshold"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        Slider(value: $viewModel.filterUnsharpThreshold, in: 0...1, step: 0.05)
                        Text(L10n.format("imageEditor.filter.unsharpThresholdValue", Int((viewModel.filterUnsharpThreshold * 255).rounded())))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                            .frame(width: 44, alignment: .trailing)
                    }
                }
                if viewModel.selectedFilter == .liquifyPush {
                    HStack {
                        Text(L10n.text("imageEditor.filter.liquifyPushX"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        Slider(value: $viewModel.filterLiquifyPushX, in: -1...1, step: 0.05)
                        Text(L10n.format("imageEditor.filter.liquifyPushValue", Int((viewModel.filterLiquifyPushX * 100).rounded())))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                            .frame(width: 44, alignment: .trailing)
                    }
                    HStack {
                        Text(L10n.text("imageEditor.filter.liquifyPushY"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        Slider(value: $viewModel.filterLiquifyPushY, in: -1...1, step: 0.05)
                        Text(L10n.format("imageEditor.filter.liquifyPushValue", Int((viewModel.filterLiquifyPushY * 100).rounded())))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                            .frame(width: 44, alignment: .trailing)
                    }
                }
                if viewModel.selectedFilter == .liquifyTwirl {
                    HStack {
                        Text(L10n.text("imageEditor.filter.liquifyTwirlAngle"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        Slider(value: $viewModel.filterLiquifyTwirlAngle, in: -1...1, step: 0.05)
                        Text(L10n.format("imageEditor.filter.liquifyTwirlValue", Int((viewModel.filterLiquifyTwirlAngle * 100).rounded())))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                            .frame(width: 44, alignment: .trailing)
                    }
                }
                if viewModel.selectedFilter == .liquifyPuckerBloat {
                    HStack {
                        Text(L10n.text("imageEditor.filter.liquifyBulgeAmount"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        Slider(value: $viewModel.filterLiquifyBulgeAmount, in: -1...1, step: 0.05)
                        Text(L10n.format("imageEditor.filter.liquifyBulgeValue", Int((viewModel.filterLiquifyBulgeAmount * 100).rounded())))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                            .frame(width: 44, alignment: .trailing)
                    }
                }
                if viewModel.selectedFilter == .offset {
                    HStack {
                        Text(L10n.text("imageEditor.filter.offsetX"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        Slider(value: $viewModel.filterOffsetX, in: -1...1, step: 0.05)
                        Text(L10n.format("imageEditor.filter.offsetValue", Int((viewModel.filterOffsetX * 100).rounded())))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                            .frame(width: 44, alignment: .trailing)
                    }
                    HStack {
                        Text(L10n.text("imageEditor.filter.offsetY"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        Slider(value: $viewModel.filterOffsetY, in: -1...1, step: 0.05)
                        Text(L10n.format("imageEditor.filter.offsetValue", Int((viewModel.filterOffsetY * 100).rounded())))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                            .frame(width: 44, alignment: .trailing)
                    }
                }

                })

                AnyView(Group {

                if viewModel.selectedFilter == .wave {
                    HStack {
                        Text(L10n.text("imageEditor.filter.waveAmplitude"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        Slider(value: $viewModel.filterWaveAmplitude, in: -1...1, step: 0.05)
                        Text(L10n.format("imageEditor.filter.waveAmplitudeValue", Int((viewModel.filterWaveAmplitude * 100).rounded())))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                            .frame(width: 44, alignment: .trailing)
                    }
                    HStack {
                        Text(L10n.text("imageEditor.filter.waveFrequency"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        Slider(value: $viewModel.filterWaveFrequency, in: 0...1, step: 0.05)
                        Text(L10n.format("imageEditor.filter.waveFrequencyValue", Int((viewModel.filterWaveFrequency * 100).rounded())))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                            .frame(width: 44, alignment: .trailing)
                    }
                }
                if viewModel.selectedFilter == .ripple {
                    HStack {
                        Text(L10n.text("imageEditor.filter.rippleAmount"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        Slider(value: $viewModel.filterRippleAmount, in: -1...1, step: 0.05)
                        Text(L10n.format("imageEditor.filter.rippleAmountValue", Int((viewModel.filterRippleAmount * 100).rounded())))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                            .frame(width: 44, alignment: .trailing)
                    }
                    HStack {
                        Text(L10n.text("imageEditor.filter.rippleFrequency"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        Slider(value: $viewModel.filterRippleFrequency, in: 0...1, step: 0.05)
                        Text(L10n.format("imageEditor.filter.rippleFrequencyValue", Int((viewModel.filterRippleFrequency * 100).rounded())))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                            .frame(width: 44, alignment: .trailing)
                    }
                }
                if viewModel.selectedFilter == .pinch {
                    HStack {
                        Text(L10n.text("imageEditor.filter.pinchAmount"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        Slider(value: $viewModel.filterPinchAmount, in: -1...1, step: 0.05)
                        Text(L10n.format("imageEditor.filter.pinchAmountValue", Int((viewModel.filterPinchAmount * 100).rounded())))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                            .frame(width: 44, alignment: .trailing)
                    }
                }
                if viewModel.selectedFilter == .spherize {
                    HStack {
                        Text(L10n.text("imageEditor.filter.spherizeAmount"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        Slider(value: $viewModel.filterSpherizeAmount, in: -1...1, step: 0.05)
                        Text(L10n.format("imageEditor.filter.spherizeAmountValue", Int((viewModel.filterSpherizeAmount * 100).rounded())))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                            .frame(width: 44, alignment: .trailing)
                    }
                }
                if viewModel.selectedFilter == .lensCorrection {
                    HStack {
                        Text(L10n.text("imageEditor.filter.lensDistortion"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        Slider(value: $viewModel.filterLensDistortion, in: -1...1, step: 0.05)
                        Text(L10n.format("imageEditor.filter.lensDistortionValue", Int((viewModel.filterLensDistortion * 100).rounded())))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                            .frame(width: 44, alignment: .trailing)
                    }
                }

                })

                AnyView(Group {

                Text(viewModel.selectedLayerSmartFilterText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                    .lineLimit(2)
                if viewModel.selectedLayerHasSmartFilters {
                    VStack(spacing: 6) {
                        ForEach(viewModel.selectedLayerSmartFilters) { filter in
                            smartFilterRow(filter)
                        }
                    }
                }
                HStack {
                    Button(L10n.text("imageEditor.action.layerFilterNew")) {
                        viewModel.addFilterLayer()
                    }
                    .buttonStyle(EditorTextButtonStyle())
                    if viewModel.selectedLayerIsFilter {
                        Button(L10n.text("imageEditor.action.layerFilterUpdate")) {
                            viewModel.updateSelectedFilterLayer()
                        }
                        .buttonStyle(EditorTextButtonStyle())
                    }
                }
                HStack {
                    Button(L10n.text("imageEditor.action.layerSmartFilterAdd")) {
                        viewModel.addSmartFilterToSelectedLayer()
                    }
                    .buttonStyle(EditorTextButtonStyle())
                    .disabled(!viewModel.canAddSmartFilterToSelectedLayer)
                    if viewModel.canUpdateLoadedSmartFilterOnSelectedLayer {
                        Button(L10n.text("imageEditor.action.layerSmartFilterUpdate")) {
                            viewModel.updateLoadedSmartFilterOnSelectedLayer()
                        }
                        .buttonStyle(EditorTextButtonStyle())
                    }
                    if viewModel.canClearSmartFiltersFromSelectedLayer {
                        Button(L10n.text("imageEditor.action.layerSmartFilterClear")) {
                            viewModel.clearSmartFiltersFromSelectedLayer()
                        }
                        .buttonStyle(EditorTextButtonStyle())
                    }
                }
                })

                AnyView(Group {
                Divider().overlay(editorBorder)

                TextField(L10n.text("imageEditor.properties.textPlaceholder"), text: $viewModel.textValue)
                    .textFieldStyle(.roundedBorder)
                fontFamilyPicker()
                Stepper(
                    L10n.format("imageEditor.properties.textSizeValue", Int(viewModel.textSize.rounded())),
                    value: $viewModel.textSize,
                    in: 6...240,
                    step: 1
                )
                Picker(L10n.text("imageEditor.properties.textAlignment"), selection: $viewModel.selectedTextAlignment) {
                    ForEach(ImageEditorTextAlignment.allCases) { alignment in
                        Text(alignment.title).tag(alignment)
                    }
                }
                .pickerStyle(.segmented)
                Picker(L10n.text("imageEditor.properties.textCase"), selection: $viewModel.selectedTextCase) {
                    ForEach(ImageEditorTextCase.allCases) { textCase in
                        Text(textCase.title).tag(textCase)
                    }
                }
                .pickerStyle(.menu)
                .focusable(false)
                .accessibilityIdentifier("image-editor-text-case")
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Toggle(L10n.text("imageEditor.properties.textBold"), isOn: $viewModel.textBold)
                            .toggleStyle(.checkbox)
                            .focusable(false)
                        Toggle(L10n.text("imageEditor.properties.textItalic"), isOn: $viewModel.textItalic)
                            .toggleStyle(.checkbox)
                            .focusable(false)
                    }
                    HStack {
                        Toggle(L10n.text("imageEditor.properties.textUnderline"), isOn: $viewModel.textUnderlined)
                            .toggleStyle(.checkbox)
                            .focusable(false)
                        Toggle(L10n.text("imageEditor.properties.textStrikethrough"), isOn: $viewModel.textStruckThrough)
                            .toggleStyle(.checkbox)
                            .focusable(false)
                    }
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                HStack {
                    Stepper(
                        L10n.format("imageEditor.properties.textCharacterSpacingValue", Int(viewModel.textCharacterSpacing.rounded())),
                        value: $viewModel.textCharacterSpacing,
                        in: -8...48,
                        step: 1
                    )
                    Stepper(
                        L10n.format("imageEditor.properties.textLineSpacingValue", Int(viewModel.textLineSpacing.rounded())),
                        value: $viewModel.textLineSpacing,
                        in: 0...96,
                        step: 1
                    )
                }
                Stepper(
                    L10n.format(
                        "imageEditor.properties.textParagraphSpacingValue",
                        Int(viewModel.textParagraphSpacing.rounded())
                    ),
                    value: $viewModel.textParagraphSpacing,
                    in: 0...400,
                    step: 1
                )
                .focusable(false)
                Stepper(
                    L10n.format("imageEditor.properties.textBoxWidthValue", Int(viewModel.textBoxWidth.rounded())),
                    value: $viewModel.textBoxWidth,
                    in: 0...Double(ImageEditorTextContent.maximumBoxDimension),
                    step: 8
                )
                Stepper(
                    L10n.format("imageEditor.properties.textBoxHeightValue", Int(viewModel.textBoxHeight.rounded())),
                    value: $viewModel.textBoxHeight,
                    in: 0...Double(ImageEditorTextContent.maximumBoxDimension),
                    step: 8
                )
                Toggle(
                    L10n.text("imageEditor.properties.textBoxAutoHeight"),
                    isOn: Binding(
                        get: { viewModel.selectedTextBoxUsesAutoHeight },
                        set: { viewModel.setSelectedTextBoxesAutoHeight($0) }
                    )
                )
                .toggleStyle(.checkbox)
                .focusable(false)
                .disabled(!viewModel.canSetSelectedTextBoxAutoHeight)
                .accessibilityIdentifier("image-editor-text-box-auto-height")
                Toggle(
                    L10n.text("imageEditor.properties.textBoxTruncateOverflow"),
                    isOn: Binding(
                        get: { viewModel.selectedTextBoxTruncatesOverflow },
                        set: { viewModel.setSelectedTextBoxesTruncateOverflow($0) }
                    )
                )
                .toggleStyle(.checkbox)
                .focusable(false)
                .disabled(!viewModel.canSetSelectedTextBoxTruncation)
                .accessibilityIdentifier("image-editor-text-box-truncate-overflow")
                if viewModel.selectedTextBoxHasOverflow {
                    Label(
                        L10n.text("imageEditor.properties.textBoxOverflow"),
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.orange.opacity(0.94))
                    .accessibilityIdentifier("image-editor-text-box-overflow")
                }
                HStack {
                    Button(L10n.text("imageEditor.action.textBoxFitContent")) {
                        viewModel.fitSelectedTextBoxes(.fitContent)
                    }
                    .buttonStyle(EditorTextButtonStyle())
                    .focusable(false)
                    .disabled(!viewModel.canFitSelectedTextBoxesToContent)

                    Button(L10n.text("imageEditor.action.textBoxExpandHeight")) {
                        viewModel.fitSelectedTextBoxes(.expandHeight)
                    }
                    .buttonStyle(EditorTextButtonStyle())
                    .focusable(false)
                    .disabled(!viewModel.canExpandSelectedTextBoxes)
                }
                HStack {
                    Button(L10n.text("imageEditor.action.textConvertToPoint")) {
                        viewModel.convertSelectedTextLayers(to: .point)
                    }
                    .buttonStyle(EditorTextButtonStyle())
                    .focusable(false)
                    .disabled(!viewModel.canConvertSelectedTextToPoint)

                    Button(L10n.text("imageEditor.action.textConvertToParagraph")) {
                        viewModel.convertSelectedTextLayers(to: .paragraph)
                    }
                    .buttonStyle(EditorTextButtonStyle())
                    .focusable(false)
                    .disabled(!viewModel.canConvertSelectedTextToParagraph)
                }
                HStack {
                    Stepper(
                        L10n.format("imageEditor.properties.textLeftIndentValue", Int(viewModel.textLeftIndent.rounded())),
                        value: $viewModel.textLeftIndent,
                        in: 0...800,
                        step: 4
                    )
                    Stepper(
                        L10n.format("imageEditor.properties.textRightIndentValue", Int(viewModel.textRightIndent.rounded())),
                        value: $viewModel.textRightIndent,
                        in: 0...800,
                        step: 4
                    )
                }
                Stepper(
                    L10n.format("imageEditor.properties.textFirstLineIndentValue", Int(viewModel.textFirstLineIndent.rounded())),
                    value: $viewModel.textFirstLineIndent,
                    in: -800...800,
                    step: 4
                )
                })

                AnyView(Group {

                if viewModel.canEditSelectedPathAnchors {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.text("imageEditor.properties.pathAnchors"))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        HStack {
                            Button(L10n.text("imageEditor.action.pathAnchorPrevious")) {
                                viewModel.selectPreviousPathAnchor()
                            }
                            .buttonStyle(EditorTextButtonStyle())

                            Button(L10n.text("imageEditor.action.pathAnchorNext")) {
                                viewModel.selectNextPathAnchor()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                        }
                        HStack {
                            Button(L10n.text("imageEditor.action.pathAnchorSmooth")) {
                                viewModel.smoothSelectedPathAnchor()
                            }
                            .buttonStyle(EditorTextButtonStyle())

                            Button(L10n.text("imageEditor.action.pathAnchorClearHandles")) {
                                viewModel.clearSelectedPathAnchorHandles()
                            }
                            .buttonStyle(EditorTextButtonStyle())

                            Button(L10n.text("imageEditor.action.pathAnchorSymmetric")) {
                                viewModel.symmetrizeSelectedPathAnchorHandles()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                            .disabled(!viewModel.canSymmetrizeSelectedPathAnchorHandles)
                        }
                        HStack {
                            Button(L10n.text("imageEditor.action.pathAnchorInsert")) {
                                viewModel.insertPathAnchorAfterSelection()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                            .disabled(!viewModel.canInsertPathAnchorAfterSelection)

                            Button(L10n.text("imageEditor.action.pathAnchorDelete")) {
                                viewModel.deleteSelectedPathAnchor()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                            .disabled(!viewModel.canDeleteSelectedPathAnchor)

                            Button(L10n.text(viewModel.selectedPathIsClosed ? "imageEditor.action.pathOpen" : "imageEditor.action.pathClose")) {
                                viewModel.toggleSelectedPathClosed()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                            .disabled(!viewModel.canToggleSelectedPathClosed)
                        }
                        HStack {
                            Button(L10n.text("imageEditor.action.pathSubpathPrevious")) {
                                viewModel.selectPreviousPathSubpath()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                            .disabled(!viewModel.canSelectAdjacentPathSubpath)

                            Button(L10n.text("imageEditor.action.pathSubpathNext")) {
                                viewModel.selectNextPathSubpath()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                            .disabled(!viewModel.canSelectAdjacentPathSubpath)
                        }
                        HStack {
                            Button(L10n.text("imageEditor.action.pathSubpathDuplicate")) {
                                viewModel.duplicateSelectedPathSubpath()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                            .disabled(!viewModel.canDuplicateSelectedPathSubpath)

                            Button(L10n.text("imageEditor.action.pathReverse")) {
                                viewModel.reverseSelectedPathDirection()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                            .disabled(!viewModel.canReverseSelectedPathDirection)

                            Button(L10n.text("imageEditor.action.pathSubpathDelete")) {
                                viewModel.deleteSelectedPathSubpath()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                            .disabled(!viewModel.canDeleteSelectedPathSubpath)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.text("imageEditor.properties.pathSubpathNudge"))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                            HStack {
                                Button(L10n.text("imageEditor.action.pathSubpathNudgeLeft")) {
                                    viewModel.nudgeSelectedPathSubpath(dx: -1, dy: 0)
                                }
                                .buttonStyle(EditorTextButtonStyle())
                                .disabled(!viewModel.canMoveSelectedPathSubpath)

                                Button(L10n.text("imageEditor.action.pathSubpathNudgeRight")) {
                                    viewModel.nudgeSelectedPathSubpath(dx: 1, dy: 0)
                                }
                                .buttonStyle(EditorTextButtonStyle())
                                .disabled(!viewModel.canMoveSelectedPathSubpath)
                            }
                            HStack {
                                Button(L10n.text("imageEditor.action.pathSubpathNudgeUp")) {
                                    viewModel.nudgeSelectedPathSubpath(dx: 0, dy: -1)
                                }
                                .buttonStyle(EditorTextButtonStyle())
                                .disabled(!viewModel.canMoveSelectedPathSubpath)

                                Button(L10n.text("imageEditor.action.pathSubpathNudgeDown")) {
                                    viewModel.nudgeSelectedPathSubpath(dx: 0, dy: 1)
                                }
                                .buttonStyle(EditorTextButtonStyle())
                                .disabled(!viewModel.canMoveSelectedPathSubpath)
                            }
                        }
                        Button(L10n.text("imageEditor.action.pathStroke")) {
                            viewModel.strokeSelectedPathToPixelLayer()
                        }
                        .buttonStyle(EditorTextButtonStyle())
                        .disabled(!viewModel.canStrokeSelectedPathToPixelLayer)
                        Button(L10n.text("imageEditor.action.pathFill")) {
                            viewModel.fillSelectedPathToPixelLayer()
                        }
                        .buttonStyle(EditorTextButtonStyle())
                        .disabled(!viewModel.canFillSelectedPathToPixelLayer)
                        Button(L10n.text("imageEditor.action.pathSelection")) {
                            viewModel.loadSelectionFromSelectedPath()
                        }
                        .buttonStyle(EditorTextButtonStyle())
                        .disabled(!viewModel.canLoadSelectionFromSelectedPath)
                        Button(L10n.text("imageEditor.action.pathVectorMask")) {
                            viewModel.applySelectedPathAsVectorMask()
                        }
                        .buttonStyle(EditorTextButtonStyle())
                        .disabled(!viewModel.canApplySelectedPathAsVectorMask)
                        Button(L10n.text("imageEditor.action.pathLayerMask")) {
                            viewModel.applySelectedPathAsLayerMask()
                        }
                        .buttonStyle(EditorTextButtonStyle())
                        .disabled(!viewModel.canApplySelectedPathAsLayerMask)
                        if let point = viewModel.selectedPathAnchorCanvasPoint {
                            HStack {
                                Stepper(
                                    L10n.format("imageEditor.properties.pathAnchorXValue", Int(point.x.rounded())),
                                    value: Binding(
                                        get: { viewModel.selectedPathAnchorCanvasPoint?.x ?? 0 },
                                        set: { viewModel.setSelectedPathAnchorX($0) }
                                    ),
                                    in: 0...viewModel.document.canvasSize.width,
                                    step: 1
                                )
                                Stepper(
                                    L10n.format("imageEditor.properties.pathAnchorYValue", Int(point.y.rounded())),
                                    value: Binding(
                                        get: { viewModel.selectedPathAnchorCanvasPoint?.y ?? 0 },
                                        set: { viewModel.setSelectedPathAnchorY($0) }
                                    ),
                                    in: 0...viewModel.document.canvasSize.height,
                                    step: 1
                                )
                            }
                        }
                    }
                }
                })

                AnyView(Group {

                if viewModel.selectedTool == .pen || !viewModel.pendingPenPathPoints.isEmpty {
                    HStack {
                        Button(L10n.text("imageEditor.action.penFinishOpen")) {
                            viewModel.finishPenPath(closed: false)
                        }
                        .buttonStyle(EditorTextButtonStyle())
                        .disabled(!viewModel.canFinishPenPath)

                        Button(L10n.text("imageEditor.action.penFinishClosed")) {
                            viewModel.finishPenPath(closed: true)
                        }
                        .buttonStyle(EditorTextButtonStyle())
                        .disabled(viewModel.pendingPenPathPoints.count < 3)

                        Button(L10n.text("imageEditor.action.penCancel")) {
                            viewModel.cancelPenPath()
                        }
                        .buttonStyle(EditorTextButtonStyle())
                        .disabled(viewModel.pendingPenPathPoints.isEmpty)
                    }
                }
                HStack {
                    Button(L10n.text("imageEditor.action.layerTextNew")) {
                        viewModel.addText()
                    }
                    .buttonStyle(EditorTextButtonStyle())
                    if viewModel.selectedLayerIsText {
                        Button(L10n.text("imageEditor.action.layerTextUpdate")) {
                            viewModel.updateSelectedTextLayer()
                        }
                        .buttonStyle(EditorTextButtonStyle())
                    }
                    if viewModel.selectedLayerIsShape {
                        Button(L10n.text("imageEditor.action.layerShapeUpdate")) {
                            viewModel.updateSelectedShapeLayer()
                        }
                        .buttonStyle(EditorTextButtonStyle())
                    }
                    Button(L10n.text("imageEditor.action.gradient")) {
                        viewModel.addGradient()
                    }
                    .buttonStyle(EditorTextButtonStyle())
                }

                })

                AnyView(Group {

                Divider().overlay(editorBorder)

                HStack {
                    Button {
                        viewModel.scaleSelectedLayer(by: 0.9)
                    } label: {
                        Label(L10n.text("imageEditor.action.layerScaleDown"), systemImage: "minus.magnifyingglass")
                    }
                    .buttonStyle(EditorTextButtonStyle())

                    Button {
                        viewModel.scaleSelectedLayer(by: 1.1)
                    } label: {
                        Label(L10n.text("imageEditor.action.layerScaleUp"), systemImage: "plus.magnifyingglass")
                    }
                    .buttonStyle(EditorTextButtonStyle())
                }

                HStack {
                    Button {
                        viewModel.rotateSelectedLayer(degrees: -15)
                    } label: {
                        Label(L10n.text("imageEditor.action.layerRotateLeft"), systemImage: "rotate.left")
                    }
                    .buttonStyle(EditorTextButtonStyle())

                    Button {
                        viewModel.rotateSelectedLayer(degrees: 15)
                    } label: {
                        Label(L10n.text("imageEditor.action.layerRotateRight"), systemImage: "rotate.right")
                    }
                    .buttonStyle(EditorTextButtonStyle())
                }

                Text(viewModel.selectedLayerGeometryText)
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))

                Divider().overlay(editorBorder)
                })

                AnyView(Group {
                Text(L10n.text("imageEditor.properties.layerStyle"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))

                ImageEditorLayerStylePresetMenu(viewModel: viewModel)

                HStack(spacing: 8) {
                    Button {
                        viewModel.toggleSelectedLayerEffects()
                    } label: {
                        Label(
                            L10n.text(
                                viewModel.selectedLayerEffectsAreVisible
                                    ? "imageEditor.action.layerEffectsHideSelected"
                                    : "imageEditor.action.layerEffectsShowSelected"
                            ),
                            systemImage: viewModel.selectedLayerEffectsAreVisible ? "eye" : "eye.slash"
                        )
                    }
                    .buttonStyle(EditorTextButtonStyle())
                    .disabled(!viewModel.canToggleSelectedLayerEffects)

                    Stepper(
                        L10n.format(
                            "imageEditor.properties.layerEffectScaleValue",
                            Int(viewModel.selectedLayerEffectScale.rounded())
                        ),
                        value: selectedLayerEffectScaleBinding,
                        in: 1...1_000,
                        step: 5
                    )
                    .disabled(!viewModel.canScaleSelectedLayerEffects)
                }

                layerStyleNumericStepper(
                    state: viewModel.selectedLayerStrokeWidthState,
                    value: selectedLayerStrokeWidthBinding,
                    range: 1...24,
                    step: 1,
                    accessibilityIdentifier: "image-editor-layer-style-stroke-width"
                ) { value in
                    L10n.format("imageEditor.properties.strokeWidthValue", Int(value.rounded()))
                }
                layerStyleValuePicker(
                    state: viewModel.selectedLayerStrokePositionState,
                    values: ImageEditorStrokePosition.allCases,
                    labelKey: "imageEditor.properties.strokePosition",
                    accessibilityIdentifier: "image-editor-layer-style-stroke-position",
                    title: \.title
                ) { position in
                    viewModel.setSelectedLayerStrokePosition(position)
                }
                layerStyleNumericStepper(
                    state: viewModel.selectedLayerStrokeOpacityState,
                    value: selectedLayerStrokeOpacityBinding,
                    range: 0.05...1,
                    step: 0.05,
                    accessibilityIdentifier: "image-editor-layer-style-stroke-opacity"
                ) { value in
                    L10n.format("imageEditor.properties.strokeOpacityValue", Int((value * 100).rounded()))
                }
                layerStyleValuePicker(
                    state: viewModel.selectedLayerStrokeFillTypeState,
                    values: ImageEditorStrokeFillType.allCases,
                    labelKey: "imageEditor.properties.strokeFillType",
                    accessibilityIdentifier: "image-editor-layer-style-stroke-fill-type",
                    title: \.title
                ) { fillType in
                    viewModel.setSelectedLayerStrokeFillType(fillType)
                }
                if viewModel.selectedLayerStrokeFillTypeState.value == .color {
                    HStack(spacing: 8) {
                        Text(L10n.text("imageEditor.properties.strokeColor"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        ColorPicker("", selection: selectedLayerStrokeColorBinding, supportsOpacity: false)
                            .labelsHidden()
                            .frame(width: 32)
                            .focusable(false)
                            .accessibilityValue(
                                viewModel.selectedLayerStrokeColorState.isMixed
                                    ? L10n.text("imageEditor.properties.multipleValues")
                                    : ""
                            )
                        if viewModel.selectedLayerStrokeColorState.isMixed {
                            Text(L10n.text("imageEditor.properties.multipleValues"))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                                .lineLimit(1)
                        }
                        Spacer(minLength: 4)
                        Button(L10n.text("imageEditor.action.strokeColorFromForeground")) {
                            viewModel.setSelectedLayerStrokeColorFromForeground()
                        }
                        .buttonStyle(EditorTextButtonStyle())
                    }
                } else if viewModel.selectedLayerStrokeFillTypeState.value == .gradient {
                    layerStyleColorPickerRow(
                        labelKey: "imageEditor.properties.strokeGradientStartColor",
                        state: viewModel.selectedLayerStrokeGradientStartColorState,
                        selection: selectedLayerStrokeGradientStartColorBinding,
                        accessibilityIdentifier: "image-editor-layer-style-stroke-gradient-start-color"
                    )
                    layerStyleColorPickerRow(
                        labelKey: "imageEditor.properties.strokeGradientEndColor",
                        state: viewModel.selectedLayerStrokeGradientEndColorState,
                        selection: selectedLayerStrokeGradientEndColorBinding,
                        accessibilityIdentifier: "image-editor-layer-style-stroke-gradient-end-color"
                    )
                    layerStyleValuePicker(
                        state: viewModel.selectedLayerStrokeGradientStyleState,
                        values: ImageEditorGradientFillStyle.allCases,
                        labelKey: "imageEditor.properties.strokeGradientStyle",
                        accessibilityIdentifier: "image-editor-layer-style-stroke-gradient-style",
                        title: \.title
                    ) { style in
                        viewModel.setSelectedLayerStrokeGradientStyle(style)
                    }
                    layerStyleNumericStepper(
                        state: viewModel.selectedLayerStrokeGradientAngleState,
                        value: selectedLayerStrokeGradientAngleBinding,
                        range: -180...180,
                        step: 15,
                        accessibilityIdentifier: "image-editor-layer-style-stroke-gradient-angle"
                    ) { value in
                        L10n.format("imageEditor.properties.strokeGradientAngleValue", Int(value.rounded()))
                    }
                } else if viewModel.selectedLayerStrokeFillTypeState.value == .pattern {
                    layerStyleColorPickerRow(
                        labelKey: "imageEditor.properties.strokePatternColor",
                        state: viewModel.selectedLayerStrokePatternColorState,
                        selection: selectedLayerStrokePatternColorBinding,
                        accessibilityIdentifier: "image-editor-layer-style-stroke-pattern-color"
                    )
                    layerStyleValuePicker(
                        state: viewModel.selectedLayerStrokePatternKindState,
                        values: ImageEditorPatternOverlayKind.allCases,
                        labelKey: "imageEditor.properties.strokePatternKind",
                        accessibilityIdentifier: "image-editor-layer-style-stroke-pattern-kind",
                        title: \.title
                    ) { kind in
                        viewModel.setSelectedLayerStrokePatternKind(kind)
                    }
                    layerStyleNumericStepper(
                        state: viewModel.selectedLayerStrokePatternScaleState,
                        value: selectedLayerStrokePatternScaleBinding,
                        range: 6...64,
                        step: 2,
                        accessibilityIdentifier: "image-editor-layer-style-stroke-pattern-scale"
                    ) { value in
                        L10n.format("imageEditor.properties.strokePatternScaleValue", Int(value.rounded()))
                    }
                    layerStyleNumericStepper(
                        state: viewModel.selectedLayerStrokePatternOffsetXState,
                        value: selectedLayerStrokePatternOffsetXBinding,
                        range: -128...128,
                        step: 1,
                        accessibilityIdentifier: "image-editor-layer-style-stroke-pattern-offset-x"
                    ) { value in
                        L10n.format("imageEditor.properties.strokePatternOffsetXValue", Int(value.rounded()))
                    }
                    layerStyleNumericStepper(
                        state: viewModel.selectedLayerStrokePatternOffsetYState,
                        value: selectedLayerStrokePatternOffsetYBinding,
                        range: -128...128,
                        step: 1,
                        accessibilityIdentifier: "image-editor-layer-style-stroke-pattern-offset-y"
                    ) { value in
                        L10n.format("imageEditor.properties.strokePatternOffsetYValue", Int(value.rounded()))
                    }
                }
                layerStyleNumericStepper(
                    state: viewModel.selectedLayerShadowOpacityState,
                    value: selectedLayerShadowOpacityBinding,
                    range: 0.05...1,
                    step: 0.05,
                    accessibilityIdentifier: "image-editor-layer-style-shadow-opacity"
                ) { value in
                    L10n.format("imageEditor.properties.shadowOpacityValue", Int((value * 100).rounded()))
                }
                })

                AnyView(Group {

                HStack(spacing: 8) {
                    Text(L10n.text("imageEditor.properties.shadowColor"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                    ColorPicker("", selection: selectedLayerShadowColorBinding, supportsOpacity: false)
                        .labelsHidden()
                        .frame(width: 32)
                        .focusable(false)
                        .accessibilityValue(
                            viewModel.selectedLayerShadowColorState.isMixed
                                ? L10n.text("imageEditor.properties.multipleValues")
                                : ""
                        )
                    if viewModel.selectedLayerShadowColorState.isMixed {
                        Text(L10n.text("imageEditor.properties.multipleValues"))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    Button(L10n.text("imageEditor.action.shadowColorFromForeground")) {
                        viewModel.setSelectedLayerShadowColorFromForeground()
                    }
                    .buttonStyle(EditorTextButtonStyle())
                }
                layerStyleNumericStepper(
                    state: viewModel.selectedLayerShadowBlurState,
                    value: selectedLayerShadowBlurBinding,
                    range: 0...30,
                    step: 1,
                    accessibilityIdentifier: "image-editor-layer-style-shadow-blur"
                ) { value in
                    L10n.format("imageEditor.properties.shadowBlurValue", Int(value.rounded()))
                }
                layerStyleNumericStepper(
                    state: viewModel.selectedLayerShadowSpreadState,
                    value: selectedLayerShadowSpreadBinding,
                    range: 0...24,
                    step: 1,
                    accessibilityIdentifier: "image-editor-layer-style-shadow-spread"
                ) { value in
                    L10n.format("imageEditor.properties.shadowSpreadValue", Int(value.rounded()))
                }
                layerStyleNumericStepper(
                    state: viewModel.selectedLayerShadowNoiseState,
                    value: selectedLayerShadowNoiseBinding,
                    range: 0...1,
                    step: 0.05,
                    accessibilityIdentifier: "image-editor-layer-style-shadow-noise"
                ) { value in
                    L10n.format("imageEditor.properties.shadowNoiseValue", Int((value * 100).rounded()))
                }
                layerStyleValuePicker(
                    state: viewModel.selectedLayerShadowContourState,
                    values: ImageEditorLayerEffectContour.allCases,
                    labelKey: "imageEditor.properties.shadowContour",
                    accessibilityIdentifier: "image-editor-layer-style-shadow-contour",
                    title: \.title
                ) { contour in
                    viewModel.setSelectedLayerShadowContour(contour)
                }
                layerStyleGlobalLightToggle(
                    .shadow,
                    labelKey: "imageEditor.properties.shadowUseGlobalLight",
                    accessibilityIdentifier: "image-editor-shadow-global-light"
                )
                Stepper(
                    L10n.format("imageEditor.properties.globalLightAngleValue", Int(viewModel.globalLightAngle.rounded())),
                    value: globalLightAngleBinding,
                    in: -180...180,
                    step: 15
                )
                .focusable(false)
                .accessibilityIdentifier("image-editor-layer-style-global-light-angle")
                })

                AnyView(Group {
                HStack {
                    layerStyleNumericStepper(
                        state: viewModel.selectedLayerShadowDistanceState,
                        value: selectedLayerShadowDistanceBinding,
                        range: 0...80,
                        step: 1,
                        accessibilityIdentifier: "image-editor-layer-style-shadow-distance"
                    ) { value in
                        L10n.format("imageEditor.properties.shadowDistanceValue", Int(value.rounded()))
                    }
                    layerStyleNumericStepper(
                        state: viewModel.selectedLayerShadowAngleState,
                        value: selectedLayerShadowAngleBinding,
                        range: -180...180,
                        step: 15,
                        accessibilityIdentifier: "image-editor-layer-style-shadow-angle"
                    ) { value in
                        L10n.format("imageEditor.properties.shadowAngleValue", Int(value.rounded()))
                    }
                }
                HStack {
                    Stepper(
                        L10n.format("imageEditor.properties.shadowOffsetXValue", Int(viewModel.selectedLayerShadowOffsetX.rounded())),
                        value: selectedLayerShadowOffsetXBinding,
                        in: -40...40,
                        step: 1
                    )
                    Stepper(
                        L10n.format("imageEditor.properties.shadowOffsetYValue", Int(viewModel.selectedLayerShadowOffsetY.rounded())),
                        value: selectedLayerShadowOffsetYBinding,
                        in: -40...40,
                        step: 1
                    )
                }
                layerStyleNumericStepper(
                    state: viewModel.selectedLayerInnerShadowOpacityState,
                    value: selectedLayerInnerShadowOpacityBinding,
                    range: 0.05...1,
                    step: 0.05,
                    accessibilityIdentifier: "image-editor-layer-style-inner-shadow-opacity"
                ) { value in
                    L10n.format("imageEditor.properties.innerShadowOpacityValue", Int((value * 100).rounded()))
                }
                HStack {
                    layerStyleNumericStepper(
                        state: viewModel.selectedLayerInnerShadowBlurState,
                        value: selectedLayerInnerShadowBlurBinding,
                        range: 0...40,
                        step: 1,
                        accessibilityIdentifier: "image-editor-layer-style-inner-shadow-blur"
                    ) { value in
                        L10n.format("imageEditor.properties.innerShadowBlurValue", Int(value.rounded()))
                    }
                    layerStyleNumericStepper(
                        state: viewModel.selectedLayerInnerShadowChokeState,
                        value: selectedLayerInnerShadowChokeBinding,
                        range: 0...24,
                        step: 1,
                        accessibilityIdentifier: "image-editor-layer-style-inner-shadow-choke"
                    ) { value in
                        L10n.format("imageEditor.properties.innerShadowChokeValue", Int(value.rounded()))
                    }
                }
                HStack {
                    layerStyleNumericStepper(
                        state: viewModel.selectedLayerInnerShadowDistanceState,
                        value: selectedLayerInnerShadowDistanceBinding,
                        range: 0...48,
                        step: 1,
                        accessibilityIdentifier: "image-editor-layer-style-inner-shadow-distance"
                    ) { value in
                        L10n.format("imageEditor.properties.innerShadowDistanceValue", Int(value.rounded()))
                    }
                    layerStyleNumericStepper(
                        state: viewModel.selectedLayerInnerShadowNoiseState,
                        value: selectedLayerInnerShadowNoiseBinding,
                        range: 0...1,
                        step: 0.05,
                        accessibilityIdentifier: "image-editor-layer-style-inner-shadow-noise"
                    ) { value in
                        L10n.format("imageEditor.properties.innerShadowNoiseValue", Int((value * 100).rounded()))
                    }
                }
                layerStyleValuePicker(
                    state: viewModel.selectedLayerInnerShadowContourState,
                    values: ImageEditorLayerEffectContour.allCases,
                    labelKey: "imageEditor.properties.innerShadowContour",
                    accessibilityIdentifier: "image-editor-layer-style-inner-shadow-contour",
                    title: \.title
                ) { contour in
                    viewModel.setSelectedLayerInnerShadowContour(contour)
                }
                layerStyleNumericStepper(
                    state: viewModel.selectedLayerInnerShadowAngleState,
                    value: selectedLayerInnerShadowAngleBinding,
                    range: -180...180,
                    step: 15,
                    accessibilityIdentifier: "image-editor-layer-style-inner-shadow-angle"
                ) { value in
                    L10n.format("imageEditor.properties.innerShadowAngleValue", Int(value.rounded()))
                }
                layerStyleGlobalLightToggle(
                    .innerShadow,
                    labelKey: "imageEditor.properties.innerShadowUseGlobalLight",
                    accessibilityIdentifier: "image-editor-inner-shadow-global-light"
                )
                })

                AnyView(Group {
                layerStyleNumericStepper(
                    state: viewModel.selectedLayerOuterGlowOpacityState,
                    value: selectedLayerOuterGlowOpacityBinding,
                    range: 0.05...1,
                    step: 0.05,
                    accessibilityIdentifier: "image-editor-layer-style-outer-glow-opacity"
                ) { value in
                    L10n.format("imageEditor.properties.outerGlowOpacityValue", Int((value * 100).rounded()))
                }
                layerStyleColorPickerRow(
                    labelKey: "imageEditor.properties.outerGlowColor",
                    state: viewModel.selectedLayerOuterGlowColorState,
                    selection: selectedLayerOuterGlowColorBinding,
                    accessibilityIdentifier: "image-editor-layer-style-outer-glow-color"
                )
                HStack {
                    layerStyleNumericStepper(
                        state: viewModel.selectedLayerOuterGlowBlurState,
                        value: selectedLayerOuterGlowBlurBinding,
                        range: 0...40,
                        step: 1,
                        accessibilityIdentifier: "image-editor-layer-style-outer-glow-blur"
                    ) { value in
                        L10n.format("imageEditor.properties.outerGlowBlurValue", Int(value.rounded()))
                    }
                    layerStyleNumericStepper(
                        state: viewModel.selectedLayerOuterGlowSpreadState,
                        value: selectedLayerOuterGlowSpreadBinding,
                        range: 0...24,
                        step: 1,
                        accessibilityIdentifier: "image-editor-layer-style-outer-glow-spread"
                    ) { value in
                        L10n.format("imageEditor.properties.outerGlowSpreadValue", Int(value.rounded()))
                    }
                }
                layerStyleValuePicker(
                    state: viewModel.selectedLayerOuterGlowTechniqueState,
                    values: ImageEditorGlowTechnique.allCases,
                    labelKey: "imageEditor.properties.outerGlowTechnique",
                    accessibilityIdentifier: "image-editor-layer-style-outer-glow-technique",
                    title: \.title
                ) { technique in
                    viewModel.setSelectedLayerOuterGlowTechnique(technique)
                }
                layerStyleNumericStepper(
                    state: viewModel.selectedLayerOuterGlowNoiseState,
                    value: selectedLayerOuterGlowNoiseBinding,
                    range: 0...1,
                    step: 0.05,
                    accessibilityIdentifier: "image-editor-layer-style-outer-glow-noise"
                ) { value in
                    L10n.format("imageEditor.properties.outerGlowNoiseValue", Int((value * 100).rounded()))
                }
                layerStyleValuePicker(
                    state: viewModel.selectedLayerOuterGlowContourState,
                    values: ImageEditorLayerEffectContour.allCases,
                    labelKey: "imageEditor.properties.outerGlowContour",
                    accessibilityIdentifier: "image-editor-layer-style-outer-glow-contour",
                    title: \.title
                ) { contour in
                    viewModel.setSelectedLayerOuterGlowContour(contour)
                }
                layerStyleNumericStepper(
                    state: viewModel.selectedLayerOuterGlowRangeState,
                    value: selectedLayerOuterGlowRangeBinding,
                    range: 0.01...1,
                    step: 0.05,
                    accessibilityIdentifier: "image-editor-layer-style-outer-glow-range"
                ) { value in
                    L10n.format("imageEditor.properties.outerGlowRangeValue", Int((value * 100).rounded()))
                }
                layerStyleNumericStepper(
                    state: viewModel.selectedLayerOuterGlowJitterState,
                    value: selectedLayerOuterGlowJitterBinding,
                    range: 0...1,
                    step: 0.05,
                    accessibilityIdentifier: "image-editor-layer-style-outer-glow-jitter"
                ) { value in
                    L10n.format("imageEditor.properties.outerGlowJitterValue", Int((value * 100).rounded()))
                }
                layerStyleNumericStepper(
                    state: viewModel.selectedLayerInnerGlowOpacityState,
                    value: selectedLayerInnerGlowOpacityBinding,
                    range: 0.05...1,
                    step: 0.05,
                    accessibilityIdentifier: "image-editor-layer-style-inner-glow-opacity"
                ) { value in
                    L10n.format("imageEditor.properties.innerGlowOpacityValue", Int((value * 100).rounded()))
                }
                layerStyleColorPickerRow(
                    labelKey: "imageEditor.properties.innerGlowColor",
                    state: viewModel.selectedLayerInnerGlowColorState,
                    selection: selectedLayerInnerGlowColorBinding,
                    accessibilityIdentifier: "image-editor-layer-style-inner-glow-color"
                )
                HStack {
                    layerStyleNumericStepper(
                        state: viewModel.selectedLayerInnerGlowBlurState,
                        value: selectedLayerInnerGlowBlurBinding,
                        range: 0...40,
                        step: 1,
                        accessibilityIdentifier: "image-editor-layer-style-inner-glow-blur"
                    ) { value in
                        L10n.format("imageEditor.properties.innerGlowBlurValue", Int(value.rounded()))
                    }
                    layerStyleNumericStepper(
                        state: viewModel.selectedLayerInnerGlowChokeState,
                        value: selectedLayerInnerGlowChokeBinding,
                        range: 0...24,
                        step: 1,
                        accessibilityIdentifier: "image-editor-layer-style-inner-glow-choke"
                    ) { value in
                        L10n.format("imageEditor.properties.innerGlowChokeValue", Int(value.rounded()))
                    }
                }
                layerStyleValuePicker(
                    state: viewModel.selectedLayerInnerGlowTechniqueState,
                    values: ImageEditorGlowTechnique.allCases,
                    labelKey: "imageEditor.properties.innerGlowTechnique",
                    accessibilityIdentifier: "image-editor-layer-style-inner-glow-technique",
                    title: \.title
                ) { technique in
                    viewModel.setSelectedLayerInnerGlowTechnique(technique)
                }
                layerStyleNumericStepper(
                    state: viewModel.selectedLayerInnerGlowNoiseState,
                    value: selectedLayerInnerGlowNoiseBinding,
                    range: 0...1,
                    step: 0.05,
                    accessibilityIdentifier: "image-editor-layer-style-inner-glow-noise"
                ) { value in
                    L10n.format("imageEditor.properties.innerGlowNoiseValue", Int((value * 100).rounded()))
                }
                layerStyleValuePicker(
                    state: viewModel.selectedLayerInnerGlowSourceState,
                    values: ImageEditorInnerGlowSource.allCases,
                    labelKey: "imageEditor.properties.innerGlowSource",
                    accessibilityIdentifier: "image-editor-layer-style-inner-glow-source",
                    title: \.title
                ) { source in
                    viewModel.setSelectedLayerInnerGlowSource(source)
                }
                layerStyleValuePicker(
                    state: viewModel.selectedLayerInnerGlowContourState,
                    values: ImageEditorLayerEffectContour.allCases,
                    labelKey: "imageEditor.properties.innerGlowContour",
                    accessibilityIdentifier: "image-editor-layer-style-inner-glow-contour",
                    title: \.title
                ) { contour in
                    viewModel.setSelectedLayerInnerGlowContour(contour)
                }
                layerStyleNumericStepper(
                    state: viewModel.selectedLayerInnerGlowRangeState,
                    value: selectedLayerInnerGlowRangeBinding,
                    range: 0.01...1,
                    step: 0.05,
                    accessibilityIdentifier: "image-editor-layer-style-inner-glow-range"
                ) { value in
                    L10n.format("imageEditor.properties.innerGlowRangeValue", Int((value * 100).rounded()))
                }
                layerStyleNumericStepper(
                    state: viewModel.selectedLayerInnerGlowJitterState,
                    value: selectedLayerInnerGlowJitterBinding,
                    range: 0...1,
                    step: 0.05,
                    accessibilityIdentifier: "image-editor-layer-style-inner-glow-jitter"
                ) { value in
                    L10n.format("imageEditor.properties.innerGlowJitterValue", Int((value * 100).rounded()))
                }
                })

                AnyView(Group {
                layerStyleNumericStepper(
                    state: viewModel.selectedLayerColorOverlayOpacityState,
                    value: selectedLayerColorOverlayOpacityBinding,
                    range: 0.05...1,
                    step: 0.05,
                    accessibilityIdentifier: "image-editor-layer-style-color-overlay-opacity"
                ) { value in
                    L10n.format("imageEditor.properties.colorOverlayOpacityValue", Int((value * 100).rounded()))
                }
                HStack(spacing: 8) {
                    Text(L10n.text("imageEditor.properties.colorOverlayColor"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                    ColorPicker("", selection: selectedLayerColorOverlayColorBinding, supportsOpacity: false)
                        .labelsHidden()
                        .frame(width: 32)
                    Spacer(minLength: 4)
                }
                layerStyleValuePicker(
                    state: viewModel.selectedLayerGradientOverlayStyleState,
                    values: ImageEditorGradientFillStyle.allCases,
                    labelKey: "imageEditor.properties.gradientOverlayStyle",
                    accessibilityIdentifier: "image-editor-layer-style-gradient-overlay-style",
                    title: \.title
                ) { style in
                    viewModel.setSelectedLayerGradientOverlayStyle(style)
                }
                HStack(spacing: 8) {
                    Text(L10n.text("imageEditor.properties.gradientOverlayStartColor"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                    ColorPicker("", selection: selectedLayerGradientOverlayStartColorBinding, supportsOpacity: false)
                        .labelsHidden()
                        .frame(width: 32)
                    Spacer(minLength: 4)
                }
                HStack(spacing: 8) {
                    Text(L10n.text("imageEditor.properties.gradientOverlayEndColor"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                    ColorPicker("", selection: selectedLayerGradientOverlayEndColorBinding, supportsOpacity: false)
                        .labelsHidden()
                        .frame(width: 32)
                    Spacer(minLength: 4)
                }
                HStack {
                    layerStyleNumericStepper(
                        state: viewModel.selectedLayerGradientOverlayOpacityState,
                        value: selectedLayerGradientOverlayOpacityBinding,
                        range: 0.05...1,
                        step: 0.05,
                        accessibilityIdentifier: "image-editor-layer-style-gradient-overlay-opacity"
                    ) { value in
                        L10n.format("imageEditor.properties.gradientOverlayOpacityValue", Int((value * 100).rounded()))
                    }
                    layerStyleNumericStepper(
                        state: viewModel.selectedLayerGradientOverlayAngleState,
                        value: selectedLayerGradientOverlayAngleBinding,
                        range: -180...180,
                        step: 15,
                        accessibilityIdentifier: "image-editor-layer-style-gradient-overlay-angle"
                    ) { value in
                        L10n.format("imageEditor.properties.gradientOverlayAngleValue", Int(value.rounded()))
                    }
                }
                layerStyleNumericStepper(
                    state: viewModel.selectedLayerGradientOverlayScaleState,
                    value: selectedLayerGradientOverlayScaleBinding,
                    range: 0.25...4,
                    step: 0.05,
                    accessibilityIdentifier: "image-editor-layer-style-gradient-overlay-scale"
                ) { value in
                    L10n.format("imageEditor.properties.gradientOverlayScaleValue", Int((value * 100).rounded()))
                }
                layerStyleValuePicker(
                    state: viewModel.selectedLayerPatternOverlayKindState,
                    values: ImageEditorPatternOverlayKind.allCases,
                    labelKey: "imageEditor.properties.patternOverlayKind",
                    accessibilityIdentifier: "image-editor-layer-style-pattern-overlay-kind",
                    title: \.title
                ) { kind in
                    viewModel.setSelectedLayerPatternOverlayKind(kind)
                }
                layerStyleColorPickerRow(
                    labelKey: "imageEditor.properties.patternOverlayColor",
                    state: viewModel.selectedLayerPatternOverlayColorState,
                    selection: selectedLayerPatternOverlayColorBinding,
                    accessibilityIdentifier: "image-editor-layer-style-pattern-overlay-color"
                )
                HStack {
                    layerStyleNumericStepper(
                        state: viewModel.selectedLayerPatternOverlayOpacityState,
                        value: selectedLayerPatternOverlayOpacityBinding,
                        range: 0.05...1,
                        step: 0.05,
                        accessibilityIdentifier: "image-editor-layer-style-pattern-overlay-opacity"
                    ) { value in
                        L10n.format("imageEditor.properties.patternOverlayOpacityValue", Int((value * 100).rounded()))
                    }
                    layerStyleNumericStepper(
                        state: viewModel.selectedLayerPatternOverlayScaleState,
                        value: selectedLayerPatternOverlayScaleBinding,
                        range: 6...64,
                        step: 2,
                        accessibilityIdentifier: "image-editor-layer-style-pattern-overlay-scale"
                    ) { value in
                        L10n.format("imageEditor.properties.patternOverlayScaleValue", Int(value.rounded()))
                    }
                }
                layerStyleNumericStepper(
                    state: viewModel.selectedLayerPatternOverlayOffsetXState,
                    value: selectedLayerPatternOverlayOffsetXBinding,
                    range: -128...128,
                    step: 1,
                    accessibilityIdentifier: "image-editor-layer-style-pattern-overlay-offset-x"
                ) { value in
                    L10n.format("imageEditor.properties.patternOverlayOffsetXValue", Int(value.rounded()))
                }
                layerStyleNumericStepper(
                    state: viewModel.selectedLayerPatternOverlayOffsetYState,
                    value: selectedLayerPatternOverlayOffsetYBinding,
                    range: -128...128,
                    step: 1,
                    accessibilityIdentifier: "image-editor-layer-style-pattern-overlay-offset-y"
                ) { value in
                    L10n.format("imageEditor.properties.patternOverlayOffsetYValue", Int(value.rounded()))
                }
                HStack {
                    Stepper(
                        L10n.format("imageEditor.properties.satinOpacityValue", Int((viewModel.selectedLayerSatinOpacity * 100).rounded())),
                        value: selectedLayerSatinOpacityBinding,
                        in: 0.05...1,
                        step: 0.05
                    )
                    Stepper(
                        L10n.format("imageEditor.properties.satinDistanceValue", Int(viewModel.selectedLayerSatinDistance.rounded())),
                        value: selectedLayerSatinDistanceBinding,
                        in: 1...48,
                        step: 1
                    )
                }
                })

                AnyView(Group {

                HStack(spacing: 8) {
                    Text(L10n.text("imageEditor.properties.satinColor"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                    ColorPicker("", selection: selectedLayerSatinColorBinding, supportsOpacity: false)
                        .labelsHidden()
                        .frame(width: 24, height: 18)
                    Spacer(minLength: 4)
                    Button(L10n.text("imageEditor.action.satinColorFromForeground")) {
                        viewModel.setSelectedLayerSatinColorFromForeground()
                    }
                    .buttonStyle(EditorTextButtonStyle())
                }
                layerStyleTriStateToggle(
                    state: viewModel.selectedLayerSatinInvertState,
                    labelKey: "imageEditor.properties.satinInvert",
                    accessibilityIdentifier: "image-editor-satin-invert"
                ) {
                    viewModel.toggleSelectedLayerSatinInvert()
                }
                layerStyleValuePicker(
                    state: viewModel.selectedLayerSatinContourState,
                    values: ImageEditorLayerEffectContour.allCases,
                    labelKey: "imageEditor.properties.satinContour",
                    accessibilityIdentifier: "image-editor-layer-style-satin-contour",
                    title: \.title
                ) { contour in
                    viewModel.setSelectedLayerSatinContour(contour)
                }
                HStack {
                    Stepper(
                        L10n.format("imageEditor.properties.satinSizeValue", Int(viewModel.selectedLayerSatinSize.rounded())),
                        value: selectedLayerSatinSizeBinding,
                        in: 0...40,
                        step: 1
                    )
                    Stepper(
                        L10n.format("imageEditor.properties.satinAngleValue", Int(viewModel.selectedLayerSatinAngle.rounded())),
                        value: selectedLayerSatinAngleBinding,
                        in: -180...180,
                        step: 15
                    )
                }
                HStack {
                    layerStyleNumericStepper(
                        state: viewModel.selectedLayerBevelSizeState,
                        value: selectedLayerBevelSizeBinding,
                        range: 1...24,
                        step: 1,
                        accessibilityIdentifier: "image-editor-layer-style-bevel-size"
                    ) { value in
                        L10n.format("imageEditor.properties.bevelSizeValue", Int(value.rounded()))
                    }
                    layerStyleNumericStepper(
                        state: viewModel.selectedLayerBevelOpacityState,
                        value: selectedLayerBevelOpacityBinding,
                        range: 0.05...1,
                        step: 0.05,
                        accessibilityIdentifier: "image-editor-layer-style-bevel-opacity"
                    ) { value in
                        L10n.format("imageEditor.properties.bevelOpacityValue", Int((value * 100).rounded()))
                    }
                }
                })

                AnyView(Group {

                layerStyleColorPickerRow(
                    labelKey: "imageEditor.properties.bevelHighlightColor",
                    state: viewModel.selectedLayerBevelHighlightColorState,
                    selection: selectedLayerBevelHighlightColorBinding,
                    accessibilityIdentifier: "image-editor-layer-style-bevel-highlight-color"
                )
                layerStyleColorPickerRow(
                    labelKey: "imageEditor.properties.bevelShadowColor",
                    state: viewModel.selectedLayerBevelShadowColorState,
                    selection: selectedLayerBevelShadowColorBinding,
                    accessibilityIdentifier: "image-editor-layer-style-bevel-shadow-color"
                )
                layerStyleNumericStepper(
                    state: viewModel.selectedLayerBevelSoftenState,
                    value: selectedLayerBevelSoftenBinding,
                    range: 0...24,
                    step: 1,
                    accessibilityIdentifier: "image-editor-layer-style-bevel-soften"
                ) { value in
                    L10n.format("imageEditor.properties.bevelSoftenValue", Int(value.rounded()))
                }
                layerStyleGlobalLightToggle(
                    .bevel,
                    labelKey: "imageEditor.properties.bevelUseGlobalLight",
                    accessibilityIdentifier: "image-editor-bevel-global-light"
                )
                layerStyleValuePicker(
                    state: viewModel.selectedLayerBevelDirectionState,
                    values: ImageEditorBevelDirection.allCases,
                    labelKey: "imageEditor.properties.bevelDirection",
                    accessibilityIdentifier: "image-editor-layer-style-bevel-direction",
                    title: \.title
                ) { direction in
                    viewModel.setSelectedLayerBevelDirection(direction)
                }
                layerStyleNumericStepper(
                    state: viewModel.selectedLayerBevelAngleState,
                    value: selectedLayerBevelAngleBinding,
                    range: -180...180,
                    step: 15,
                    accessibilityIdentifier: "image-editor-layer-style-bevel-angle"
                ) { value in
                    L10n.format("imageEditor.properties.bevelAngleValue", Int(value.rounded()))
                }
                })

                AnyView(Group {
                Divider().overlay(editorBorder)

                HStack {
                    Button {
                        viewModel.rotateClockwise()
                    } label: {
                        Label(L10n.text("imageEditor.action.rotateClockwise"), systemImage: "rotate.right")
                    }
                    .buttonStyle(EditorTextButtonStyle())

                    Button {
                        viewModel.flipHorizontal()
                    } label: {
                        Label(L10n.text("imageEditor.action.flipH"), systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                    }
                    .buttonStyle(EditorTextButtonStyle())

                    Button {
                        viewModel.flipVertical()
                    } label: {
                        Label(L10n.text("imageEditor.action.flipV"), systemImage: "arrow.up.and.down.righttriangle.up.righttriangle.down")
                    }
                    .buttonStyle(EditorTextButtonStyle())
                }
                })
            }
        }
        .accessibilityIdentifier("image-editor-properties-panel")
    }

    private func smartFilterRow(_ filter: ImageEditorSmartFilter) -> AnyView {
        let opacityState = viewModel.smartFilterOpacityState(filter.id)
        let opacityTitle = opacityState.value.map {
            L10n.format("imageEditor.option.percentPreset", Int(($0 * 100).rounded()))
        } ?? (opacityState.isMixed ? L10n.text("imageEditor.properties.multipleValues") : "")
        let blendMode = viewModel.smartFilterBlendMode(filter.id) ?? filter.normalizedBlendMode
        let blendModeState = viewModel.smartFilterBlendModeState(filter.id)
        let blendModeTitle = blendModeState.value?.title
            ?? (blendModeState.isMixed ? L10n.text("imageEditor.properties.multipleValues") : blendMode.title)
        let isLoadedForEditing = viewModel.isSmartFilterLoadedForEditing(filter.id)
        let hasPendingControlChanges = viewModel.smartFilterHasPendingControlChanges(filter.id)
        let canDiscardControlChanges = viewModel.canDiscardSmartFilterControlChanges(filter.id)
        let canMoveUp = viewModel.canMoveSmartFilterOnSelectedLayer(filter.id, offset: -1)
        let canMoveDown = viewModel.canMoveSmartFilterOnSelectedLayer(filter.id, offset: 1)
        let editingAccessibilityValue = isLoadedForEditing
            ? L10n.text(
                hasPendingControlChanges
                    ? "imageEditor.state.editingModified"
                    : "imageEditor.state.editing"
            )
            : ""

        return AnyView(VStack(spacing: 4) {
            HStack(spacing: 6) {
                Text(viewModel.smartFilterLabel(filter))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(filter.isEnabled ? Color(nsColor: ImageEditorTheme.text) : Color(nsColor: ImageEditorTheme.mutedText))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.loadSmartFilterIntoControls(filter.id)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(viewModel.smartFilterLabel(filter))
                    .accessibilityValue(editingAccessibilityValue)
                    .accessibilityHint(L10n.text("imageEditor.action.layerSmartFilterLoadSettings"))
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction {
                        viewModel.loadSmartFilterIntoControls(filter.id)
                    }
                    .accessibilityIdentifier("image-editor-smart-filter-load-\(filter.id)")
                    .help(L10n.text("imageEditor.action.layerSmartFilterLoadSettings"))
                Circle()
                    .fill(Color.orange.opacity(0.78))
                    .frame(width: 5, height: 5)
                    .opacity(hasPendingControlChanges ? 1 : 0)
                    .accessibilityHidden(true)
                    .help(L10n.text("imageEditor.state.unsavedChanges"))
                Button(L10n.text(filter.isEnabled ? "imageEditor.action.layerSmartFilterDisable" : "imageEditor.action.layerSmartFilterEnable")) {
                    viewModel.toggleSmartFilterOnSelectedLayer(filter.id)
                }
                .buttonStyle(EditorTextButtonStyle())
                Button(L10n.text("imageEditor.action.layerSmartFilterUpdateShort")) {
                    viewModel.updateSmartFilterOnSelectedLayer(filter.id)
                }
                .buttonStyle(EditorTextButtonStyle())
                .disabled(!isLoadedForEditing || !hasPendingControlChanges)
                Button {
                    _ = viewModel.discardSmartFilterControlChanges(filter.id)
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(EditorTextButtonStyle())
                .focusable(false)
                .disabled(!canDiscardControlChanges)
                .accessibilityLabel(L10n.text("imageEditor.action.layerSmartFilterDiscardChanges"))
                .accessibilityIdentifier("image-editor-smart-filter-discard-\(filter.id)")
                .help(L10n.text("imageEditor.action.layerSmartFilterDiscardChanges"))
                Button {
                    viewModel.duplicateSmartFilterOnSelectedLayer(filter.id)
                } label: {
                    Image(systemName: "square.on.square")
                        .font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(EditorTextButtonStyle())
                .focusable(false)
                .accessibilityLabel(L10n.text("imageEditor.action.layerSmartFilterDuplicate"))
                .accessibilityIdentifier("image-editor-smart-filter-duplicate-\(filter.id)")
                Button {
                    _ = viewModel.moveSmartFilterOnSelectedLayer(filter.id, offset: -1)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(EditorTextButtonStyle())
                .focusable(false)
                .disabled(!canMoveUp)
                .accessibilityLabel(L10n.text("imageEditor.action.layerSmartFilterMoveUp"))
                .accessibilityIdentifier("image-editor-smart-filter-move-up-\(filter.id)")
                .help(L10n.text("imageEditor.action.layerSmartFilterMoveUp"))
                Button {
                    _ = viewModel.moveSmartFilterOnSelectedLayer(filter.id, offset: 1)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(EditorTextButtonStyle())
                .focusable(false)
                .disabled(!canMoveDown)
                .accessibilityLabel(L10n.text("imageEditor.action.layerSmartFilterMoveDown"))
                .accessibilityIdentifier("image-editor-smart-filter-move-down-\(filter.id)")
                .help(L10n.text("imageEditor.action.layerSmartFilterMoveDown"))
                Button(L10n.text("imageEditor.action.layerSmartFilterRemove")) {
                    viewModel.removeSmartFilterFromSelectedLayer(filter.id)
                }
                .buttonStyle(EditorTextButtonStyle())
            }
            Stepper(
                value: Binding(
                    get: { viewModel.smartFilterOpacity(filter.id) ?? filter.normalizedOpacity },
                    set: { viewModel.setSmartFilterOpacityOnSelectedLayer(filter.id, opacity: $0) }
                ),
                in: 0...1,
                step: 0.05
            ) {
                HStack(spacing: 6) {
                    Text(L10n.text("imageEditor.option.opacity"))
                    Spacer(minLength: 4)
                    Text(opacityTitle)
                        .monospacedDigit()
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
            }
            .disabled(opacityState == .unavailable)
            .focusable(false)
            .accessibilityValue(opacityTitle)
            .accessibilityIdentifier("image-editor-smart-filter-opacity-\(filter.id)")
            HStack(spacing: 6) {
                Text(L10n.text("imageEditor.properties.smartFilterBlendMode"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                Spacer(minLength: 4)
                ImageEditorDarkSmartFilterBlendPicker(
                    selection: Binding(
                        get: { viewModel.smartFilterBlendMode(filter.id) ?? filter.normalizedBlendMode },
                        set: { viewModel.setSmartFilterBlendModeOnSelectedLayer(filter.id, blendMode: $0) }
                    ),
                    isMixed: blendModeState.isMixed
                )
                .frame(width: 132, height: 24)
                .disabled(blendModeState == .unavailable)
                .focusable(false)
                .accessibilityValue(blendModeTitle)
                .accessibilityIdentifier("image-editor-smart-filter-blend-mode-\(filter.id)")
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(
                    isLoadedForEditing
                        ? Color(nsColor: ImageEditorTheme.selected).opacity(0.20)
                        : Color.clear
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(
                    isLoadedForEditing
                        ? Color(nsColor: ImageEditorTheme.selected).opacity(0.72)
                        : Color.clear,
                    lineWidth: 1
                )
        }
        )
    }

    private var levelsControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            levelsSlider(
                labelKey: "imageEditor.levels.blackPoint",
                value: $viewModel.levelsBlackPoint,
                range: 0...0.98,
                step: 0.01,
                displayText: "\(Int((viewModel.levelsBlackPoint * 255).rounded()))"
            )
            levelsSlider(
                labelKey: "imageEditor.levels.gamma",
                value: $viewModel.levelsGamma,
                range: 0.1...4,
                step: 0.05,
                displayText: String(format: "%.2f", viewModel.levelsGamma)
            )
            levelsSlider(
                labelKey: "imageEditor.levels.whitePoint",
                value: $viewModel.levelsWhitePoint,
                range: 0.02...1,
                step: 0.01,
                displayText: "\(Int((viewModel.levelsWhitePoint * 255).rounded()))"
            )
        }
    }

    private var curvesControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            adjustmentSlider(
                labelKey: "imageEditor.curves.shadows",
                value: $viewModel.curvesShadows,
                range: -1...1,
                step: 0.05,
                displayText: "\(Int((viewModel.curvesShadows * 100).rounded()))%"
            )
            adjustmentSlider(
                labelKey: "imageEditor.curves.midtones",
                value: $viewModel.curvesMidtones,
                range: -1...1,
                step: 0.05,
                displayText: "\(Int((viewModel.curvesMidtones * 100).rounded()))%"
            )
            adjustmentSlider(
                labelKey: "imageEditor.curves.highlights",
                value: $viewModel.curvesHighlights,
                range: -1...1,
                step: 0.05,
                displayText: "\(Int((viewModel.curvesHighlights * 100).rounded()))%"
            )
        }
    }

    private var colorBalanceControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            colorBalanceSection(
                titleKey: "imageEditor.colorBalance.shadows",
                cyanRed: $viewModel.colorBalanceShadowsCyanRed,
                magentaGreen: $viewModel.colorBalanceShadowsMagentaGreen,
                yellowBlue: $viewModel.colorBalanceShadowsYellowBlue
            )
            colorBalanceSection(
                titleKey: "imageEditor.colorBalance.midtones",
                cyanRed: $viewModel.colorBalanceMidtonesCyanRed,
                magentaGreen: $viewModel.colorBalanceMidtonesMagentaGreen,
                yellowBlue: $viewModel.colorBalanceMidtonesYellowBlue
            )
            colorBalanceSection(
                titleKey: "imageEditor.colorBalance.highlights",
                cyanRed: $viewModel.colorBalanceHighlightsCyanRed,
                magentaGreen: $viewModel.colorBalanceHighlightsMagentaGreen,
                yellowBlue: $viewModel.colorBalanceHighlightsYellowBlue
            )
        }
    }

    private var blackWhiteControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            adjustmentSlider(
                labelKey: "imageEditor.blackWhite.reds",
                value: $viewModel.blackWhiteReds,
                range: 0...2,
                step: 0.05,
                displayText: "\(Int((viewModel.blackWhiteReds * 100).rounded()))%"
            )
            adjustmentSlider(
                labelKey: "imageEditor.blackWhite.yellows",
                value: $viewModel.blackWhiteYellows,
                range: 0...2,
                step: 0.05,
                displayText: "\(Int((viewModel.blackWhiteYellows * 100).rounded()))%"
            )
            adjustmentSlider(
                labelKey: "imageEditor.blackWhite.greens",
                value: $viewModel.blackWhiteGreens,
                range: 0...2,
                step: 0.05,
                displayText: "\(Int((viewModel.blackWhiteGreens * 100).rounded()))%"
            )
            adjustmentSlider(
                labelKey: "imageEditor.blackWhite.cyans",
                value: $viewModel.blackWhiteCyans,
                range: 0...2,
                step: 0.05,
                displayText: "\(Int((viewModel.blackWhiteCyans * 100).rounded()))%"
            )
            adjustmentSlider(
                labelKey: "imageEditor.blackWhite.blues",
                value: $viewModel.blackWhiteBlues,
                range: 0...2,
                step: 0.05,
                displayText: "\(Int((viewModel.blackWhiteBlues * 100).rounded()))%"
            )
            adjustmentSlider(
                labelKey: "imageEditor.blackWhite.magentas",
                value: $viewModel.blackWhiteMagentas,
                range: 0...2,
                step: 0.05,
                displayText: "\(Int((viewModel.blackWhiteMagentas * 100).rounded()))%"
            )
        }
    }

    private var hueSaturationControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(L10n.text("imageEditor.hueSaturation.colorize"), isOn: $viewModel.hueSaturationColorize)
                .toggleStyle(.checkbox)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
            adjustmentSlider(
                labelKey: "imageEditor.hueSaturation.hue",
                value: $viewModel.hueSaturationHue,
                range: -180...180,
                step: 1,
                displayText: "\(Int(viewModel.hueSaturationHue.rounded()))°"
            )
            adjustmentSlider(
                labelKey: "imageEditor.hueSaturation.saturation",
                value: $viewModel.hueSaturationSaturation,
                range: -1...1,
                step: 0.05,
                displayText: "\(Int((viewModel.hueSaturationSaturation * 100).rounded()))%"
            )
            adjustmentSlider(
                labelKey: "imageEditor.hueSaturation.lightness",
                value: $viewModel.hueSaturationLightness,
                range: -1...1,
                step: 0.05,
                displayText: "\(Int((viewModel.hueSaturationLightness * 100).rounded()))%"
            )
        }
    }

    private var channelMixerControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(L10n.text("imageEditor.channelMixer.monochrome"), isOn: $viewModel.channelMixerMonochrome)
                .toggleStyle(.checkbox)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                .onChange(of: viewModel.channelMixerMonochrome) { isMonochrome in
                    viewModel.selectedChannelMixerOutput = isMonochrome ? .monochrome : .red
                }
            if viewModel.channelMixerMonochrome {
                channelMixerSliderGroup(
                    red: $viewModel.channelMixerMonoRed,
                    green: $viewModel.channelMixerMonoGreen,
                    blue: $viewModel.channelMixerMonoBlue,
                    constant: $viewModel.channelMixerMonoConstant
                )
            } else {
                Picker(L10n.text("imageEditor.channelMixer.output"), selection: $viewModel.selectedChannelMixerOutput) {
                    ForEach(ImageEditorChannelMixerOutput.allCases.filter { $0 != .monochrome }) { output in
                        Text(output.title).tag(output)
                    }
                }
                if viewModel.selectedChannelMixerOutput == .red {
                    channelMixerSliderGroup(
                        red: $viewModel.channelMixerRedRed,
                        green: $viewModel.channelMixerRedGreen,
                        blue: $viewModel.channelMixerRedBlue,
                        constant: $viewModel.channelMixerRedConstant
                    )
                } else if viewModel.selectedChannelMixerOutput == .green {
                    channelMixerSliderGroup(
                        red: $viewModel.channelMixerGreenRed,
                        green: $viewModel.channelMixerGreenGreen,
                        blue: $viewModel.channelMixerGreenBlue,
                        constant: $viewModel.channelMixerGreenConstant
                    )
                } else {
                    channelMixerSliderGroup(
                        red: $viewModel.channelMixerBlueRed,
                        green: $viewModel.channelMixerBlueGreen,
                        blue: $viewModel.channelMixerBlueBlue,
                        constant: $viewModel.channelMixerBlueConstant
                    )
                }
            }
        }
    }

    private var photoFilterControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker(L10n.text("imageEditor.photoFilter.preset"), selection: $viewModel.selectedPhotoFilterPreset) {
                ForEach(ImageEditorPhotoFilterPreset.allCases) { preset in
                    Text(preset.title).tag(preset)
                }
            }
            adjustmentSlider(
                labelKey: "imageEditor.photoFilter.density",
                value: $viewModel.photoFilterDensity,
                range: 0...1,
                step: 0.05,
                displayText: "\(Int((viewModel.photoFilterDensity * 100).rounded()))%"
            )
            Toggle(L10n.text("imageEditor.photoFilter.preserveLuminosity"), isOn: $viewModel.photoFilterPreserveLuminosity)
                .toggleStyle(.checkbox)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
            if viewModel.selectedPhotoFilterPreset == .custom {
                adjustmentSlider(
                    labelKey: "imageEditor.photoFilter.customRed",
                    value: $viewModel.photoFilterCustomRed,
                    range: 0...1,
                    step: 0.05,
                    displayText: "\(Int((viewModel.photoFilterCustomRed * 100).rounded()))%"
                )
                adjustmentSlider(
                    labelKey: "imageEditor.photoFilter.customGreen",
                    value: $viewModel.photoFilterCustomGreen,
                    range: 0...1,
                    step: 0.05,
                    displayText: "\(Int((viewModel.photoFilterCustomGreen * 100).rounded()))%"
                )
                adjustmentSlider(
                    labelKey: "imageEditor.photoFilter.customBlue",
                    value: $viewModel.photoFilterCustomBlue,
                    range: 0...1,
                    step: 0.05,
                    displayText: "\(Int((viewModel.photoFilterCustomBlue * 100).rounded()))%"
                )
            }
        }
    }

    private var colorLookupControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker(L10n.text("imageEditor.colorLookup.preset"), selection: $viewModel.selectedColorLookupPreset) {
                ForEach(ImageEditorColorLookupPreset.allCases) { preset in
                    Text(preset.title).tag(preset)
                }
            }
            HStack(spacing: 8) {
                Button(L10n.text("imageEditor.action.colorLookupImportCube")) {
                    viewModel.chooseColorLookupCubeFile()
                }
                .buttonStyle(EditorTextButtonStyle())
                Text(colorLookupCubeStatusText)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                    .lineLimit(1)
            }
        }
    }

    private var colorLookupCubeStatusText: String {
        guard viewModel.selectedColorLookupCube.isValid else {
            return L10n.text("imageEditor.colorLookup.cubeMissing")
        }
        return L10n.format(
            "imageEditor.colorLookup.cubeLoaded",
            viewModel.selectedColorLookupCube.name,
            viewModel.selectedColorLookupCube.dimension
        )
    }

    private var posterizeControls: some View {
        adjustmentSlider(
            labelKey: "imageEditor.option.posterizeLevels",
            value: posterizeLevelBinding,
            range: 2...32,
            step: 1,
            displayText: "\(Int(posterizeLevelBinding.wrappedValue.rounded()))"
        )
    }

    private var shadowsHighlightsControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            adjustmentSlider(
                labelKey: "imageEditor.shadowsHighlights.shadows",
                value: $viewModel.shadowsHighlightsShadows,
                range: 0...1,
                step: 0.05,
                displayText: "\(Int((viewModel.shadowsHighlightsShadows * 100).rounded()))%"
            )
            adjustmentSlider(
                labelKey: "imageEditor.shadowsHighlights.highlights",
                value: $viewModel.shadowsHighlightsHighlights,
                range: 0...1,
                step: 0.05,
                displayText: "\(Int((viewModel.shadowsHighlightsHighlights * 100).rounded()))%"
            )
        }
    }

    private var vibranceControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            adjustmentSlider(
                labelKey: "imageEditor.vibrance.vibrance",
                value: $viewModel.vibranceAmount,
                range: -1...1,
                step: 0.05,
                displayText: "\(Int((viewModel.vibranceAmount * 100).rounded()))"
            )
            adjustmentSlider(
                labelKey: "imageEditor.vibrance.saturation",
                value: $viewModel.vibranceSaturation,
                range: -1...1,
                step: 0.05,
                displayText: "\(Int((viewModel.vibranceSaturation * 100).rounded()))"
            )
        }
    }

    private var exposureControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            adjustmentSlider(
                labelKey: "imageEditor.exposure.exposure",
                value: $viewModel.exposureEV,
                range: -5...5,
                step: 0.05,
                displayText: String(format: "%+.2f", viewModel.exposureEV)
            )
            adjustmentSlider(
                labelKey: "imageEditor.exposure.offset",
                value: $viewModel.exposureOffset,
                range: -0.5...0.5,
                step: 0.01,
                displayText: String(format: "%+.2f", viewModel.exposureOffset)
            )
            adjustmentSlider(
                labelKey: "imageEditor.exposure.gamma",
                value: $viewModel.exposureGamma,
                range: 0.1...9.99,
                step: 0.01,
                displayText: String(format: "%.2f", viewModel.exposureGamma)
            )
        }
    }

    private var brightnessContrastControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            adjustmentSlider(
                labelKey: "imageEditor.brightnessContrast.brightness",
                value: $viewModel.brightnessContrastBrightness,
                range: -1...1,
                step: 0.05,
                displayText: "\(Int((viewModel.brightnessContrastBrightness * 100).rounded()))"
            )
            adjustmentSlider(
                labelKey: "imageEditor.brightnessContrast.contrast",
                value: $viewModel.brightnessContrastContrast,
                range: -1...1,
                step: 0.05,
                displayText: "\(Int((viewModel.brightnessContrastContrast * 100).rounded()))"
            )
        }
    }

    private var selectiveColorControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker(L10n.text("imageEditor.selectiveColor.range"), selection: $viewModel.selectedSelectiveColorRange) {
                ForEach(ImageEditorSelectiveColorRange.allCases) { range in
                    Text(range.title).tag(range)
                }
            }
            Picker(L10n.text("imageEditor.selectiveColor.method"), selection: $viewModel.selectiveColorMethod) {
                ForEach(ImageEditorSelectiveColorMethod.allCases) { method in
                    Text(method.title).tag(method)
                }
            }
            ForEach(ImageEditorSelectiveColorComponent.allCases) { component in
                let binding = selectiveColorBinding(component)
                adjustmentSlider(
                    labelKey: "imageEditor.selectiveColor.component.\(component.rawValue)",
                    value: binding,
                    range: -1...1,
                    step: 0.05,
                    displayText: "\(Int((binding.wrappedValue * 100).rounded()))%"
                )
            }
        }
    }

    private var gradientMapControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker(L10n.text("imageEditor.gradientMap.preset"), selection: $viewModel.selectedGradientMapPreset) {
                ForEach(ImageEditorGradientMapPreset.allCases) { preset in
                    Text(preset.title).tag(preset)
                }
            }
            Toggle(L10n.text("imageEditor.gradientMap.reverse"), isOn: $viewModel.gradientMapReverse)
                .toggleStyle(.checkbox)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
            Toggle(L10n.text("imageEditor.gradientMap.dither"), isOn: $viewModel.gradientMapDither)
                .toggleStyle(.checkbox)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
            if viewModel.selectedGradientMapPreset == .custom {
                Text(L10n.text("imageEditor.gradientMap.shadows"))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                gradientMapColorSliders(
                    red: $viewModel.gradientMapShadowRed,
                    green: $viewModel.gradientMapShadowGreen,
                    blue: $viewModel.gradientMapShadowBlue
                )
                Text(L10n.text("imageEditor.gradientMap.highlights"))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                gradientMapColorSliders(
                    red: $viewModel.gradientMapHighlightRed,
                    green: $viewModel.gradientMapHighlightGreen,
                    blue: $viewModel.gradientMapHighlightBlue
                )
            }
        }
    }

    private var solidColorFillControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.text("imageEditor.solidColorFill.title"))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
            gradientFillColorSliders(
                red: $viewModel.solidColorFillRed,
                green: $viewModel.solidColorFillGreen,
                blue: $viewModel.solidColorFillBlue,
                labelPrefix: "imageEditor.solidColorFill"
            )
            HStack {
                Button(L10n.text("imageEditor.action.layerSolidColorFillNew")) {
                    viewModel.addSolidColorFillLayer()
                }
                .buttonStyle(EditorTextButtonStyle())
                if viewModel.selectedLayerIsSolidColorFill {
                    Button(L10n.text("imageEditor.action.layerSolidColorFillUpdate")) {
                        viewModel.updateSelectedSolidColorFillLayer()
                    }
                    .buttonStyle(EditorTextButtonStyle())
                }
            }
        }
    }

    private var patternFillControls: AnyView {
        AnyView(VStack(alignment: .leading, spacing: 6) {
            Text(L10n.text("imageEditor.patternFill.title"))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
            Picker(L10n.text("imageEditor.patternFill.kind"), selection: $viewModel.selectedPatternFillKind) {
                ForEach(ImageEditorPatternOverlayKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            gradientFillColorSliders(
                red: $viewModel.patternFillRed,
                green: $viewModel.patternFillGreen,
                blue: $viewModel.patternFillBlue,
                labelPrefix: "imageEditor.patternFill"
            )
            adjustmentSlider(
                labelKey: "imageEditor.patternFill.opacity",
                value: $viewModel.patternFillOpacity,
                range: 0.05...1,
                step: 0.05,
                displayText: L10n.format("imageEditor.patternFill.opacityValue", Int((viewModel.patternFillOpacity * 100).rounded()))
            )
            adjustmentSlider(
                labelKey: "imageEditor.patternFill.scale",
                value: $viewModel.patternFillScale,
                range: 6...64,
                step: 1,
                displayText: L10n.format("imageEditor.patternFill.scaleValue", Int(viewModel.patternFillScale.rounded()))
            )
            adjustmentSlider(
                labelKey: "imageEditor.patternFill.offsetX",
                value: $viewModel.patternFillOffsetX,
                range: -128...128,
                step: 1,
                displayText: L10n.format(
                    "imageEditor.patternFill.offsetXValue",
                    Int(viewModel.patternFillOffsetX.rounded())
                )
            )
            .accessibilityIdentifier("image-editor-pattern-fill-offset-x")
            adjustmentSlider(
                labelKey: "imageEditor.patternFill.offsetY",
                value: $viewModel.patternFillOffsetY,
                range: -128...128,
                step: 1,
                displayText: L10n.format(
                    "imageEditor.patternFill.offsetYValue",
                    Int(viewModel.patternFillOffsetY.rounded())
                )
            )
            .accessibilityIdentifier("image-editor-pattern-fill-offset-y")
            HStack {
                Button(L10n.text("imageEditor.action.layerPatternFillNew")) {
                    viewModel.addPatternFillLayer()
                }
                .buttonStyle(EditorTextButtonStyle())
                if viewModel.selectedLayerIsPatternFill {
                    Button(L10n.text("imageEditor.action.layerPatternFillUpdate")) {
                        viewModel.updateSelectedPatternFillLayer()
                    }
                    .buttonStyle(EditorTextButtonStyle())
                }
            }
        })
    }

    private var gradientFillControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker(L10n.text("imageEditor.gradientFill.preset"), selection: $viewModel.selectedGradientFillPreset) {
                ForEach(ImageEditorGradientFillPreset.allCases) { preset in
                    Text(preset.title).tag(preset)
                }
            }
            Picker(L10n.text("imageEditor.gradientFill.style"), selection: $viewModel.selectedGradientFillStyle) {
                ForEach(ImageEditorGradientFillStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }
            Toggle(L10n.text("imageEditor.gradientFill.reverse"), isOn: $viewModel.gradientFillReverse)
                .toggleStyle(.checkbox)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
            adjustmentSlider(
                labelKey: "imageEditor.gradientFill.angle",
                value: $viewModel.gradientFillAngle,
                range: -180...180,
                step: 5,
                displayText: L10n.format("imageEditor.gradientFill.angleValue", Int(viewModel.gradientFillAngle.rounded()))
            )
            adjustmentSlider(
                labelKey: "imageEditor.gradientFill.scale",
                value: $viewModel.gradientFillScale,
                range: 0.25...4,
                step: 0.05,
                displayText: L10n.format("imageEditor.gradientFill.scaleValue", Int((viewModel.gradientFillScale * 100).rounded()))
            )
            if viewModel.selectedGradientFillPreset == .custom {
                Text(L10n.text("imageEditor.gradientFill.start"))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                gradientFillColorSliders(
                    red: $viewModel.gradientFillStartRed,
                    green: $viewModel.gradientFillStartGreen,
                    blue: $viewModel.gradientFillStartBlue,
                    labelPrefix: "imageEditor.gradientFill"
                )
                Text(L10n.text("imageEditor.gradientFill.end"))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                gradientFillColorSliders(
                    red: $viewModel.gradientFillEndRed,
                    green: $viewModel.gradientFillEndGreen,
                    blue: $viewModel.gradientFillEndBlue,
                    labelPrefix: "imageEditor.gradientFill"
                )
            }
            HStack {
                Button(L10n.text("imageEditor.action.layerGradientFillNew")) {
                    viewModel.addGradientFillLayer()
                }
                .buttonStyle(EditorTextButtonStyle())
                if viewModel.selectedLayerIsGradientFill {
                    Button(L10n.text("imageEditor.action.layerGradientFillUpdate")) {
                        viewModel.updateSelectedGradientFillLayer()
                    }
                    .buttonStyle(EditorTextButtonStyle())
                }
            }
        }
    }

    private func selectiveColorBinding(_ component: ImageEditorSelectiveColorComponent) -> Binding<Double> {
        Binding {
            let values = viewModel.selectiveColorSettings.values(for: viewModel.selectedSelectiveColorRange)
            switch component {
            case .cyan:
                return values.cyan
            case .magenta:
                return values.magenta
            case .yellow:
                return values.yellow
            case .black:
                return values.black
            }
        } set: { newValue in
            var settings = viewModel.selectiveColorSettings
            var values = settings.values(for: viewModel.selectedSelectiveColorRange)
            let clamped = max(-1, min(1, newValue))
            switch component {
            case .cyan:
                values.cyan = clamped
            case .magenta:
                values.magenta = clamped
            case .yellow:
                values.yellow = clamped
            case .black:
                values.black = clamped
            }
            settings.setValues(values, for: viewModel.selectedSelectiveColorRange)
            viewModel.selectiveColorSettings = settings
        }
    }

    private func gradientFillColorSliders(
        red: Binding<Double>,
        green: Binding<Double>,
        blue: Binding<Double>,
        labelPrefix: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            adjustmentSlider(
                labelKey: "\(labelPrefix).red",
                value: red,
                range: 0...1,
                step: 0.05,
                displayText: "\(Int((red.wrappedValue * 100).rounded()))%"
            )
            adjustmentSlider(
                labelKey: "\(labelPrefix).green",
                value: green,
                range: 0...1,
                step: 0.05,
                displayText: "\(Int((green.wrappedValue * 100).rounded()))%"
            )
            adjustmentSlider(
                labelKey: "\(labelPrefix).blue",
                value: blue,
                range: 0...1,
                step: 0.05,
                displayText: "\(Int((blue.wrappedValue * 100).rounded()))%"
            )
        }
    }

    private func gradientMapColorSliders(
        red: Binding<Double>,
        green: Binding<Double>,
        blue: Binding<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            adjustmentSlider(
                labelKey: "imageEditor.gradientMap.red",
                value: red,
                range: 0...1,
                step: 0.05,
                displayText: "\(Int((red.wrappedValue * 100).rounded()))%"
            )
            adjustmentSlider(
                labelKey: "imageEditor.gradientMap.green",
                value: green,
                range: 0...1,
                step: 0.05,
                displayText: "\(Int((green.wrappedValue * 100).rounded()))%"
            )
            adjustmentSlider(
                labelKey: "imageEditor.gradientMap.blue",
                value: blue,
                range: 0...1,
                step: 0.05,
                displayText: "\(Int((blue.wrappedValue * 100).rounded()))%"
            )
        }
    }

    private func colorBalanceSection(
        titleKey: String,
        cyanRed: Binding<Double>,
        magentaGreen: Binding<Double>,
        yellowBlue: Binding<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(L10n.text(titleKey))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
            adjustmentSlider(
                labelKey: "imageEditor.colorBalance.cyanRed",
                value: cyanRed,
                range: -1...1,
                step: 0.05,
                displayText: "\(Int((cyanRed.wrappedValue * 100).rounded()))%"
            )
            adjustmentSlider(
                labelKey: "imageEditor.colorBalance.magentaGreen",
                value: magentaGreen,
                range: -1...1,
                step: 0.05,
                displayText: "\(Int((magentaGreen.wrappedValue * 100).rounded()))%"
            )
            adjustmentSlider(
                labelKey: "imageEditor.colorBalance.yellowBlue",
                value: yellowBlue,
                range: -1...1,
                step: 0.05,
                displayText: "\(Int((yellowBlue.wrappedValue * 100).rounded()))%"
            )
        }
    }

    private func channelMixerSliderGroup(
        red: Binding<Double>,
        green: Binding<Double>,
        blue: Binding<Double>,
        constant: Binding<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            adjustmentSlider(
                labelKey: "imageEditor.channelMixer.red",
                value: red,
                range: -2...2,
                step: 0.05,
                displayText: "\(Int((red.wrappedValue * 100).rounded()))%"
            )
            adjustmentSlider(
                labelKey: "imageEditor.channelMixer.green",
                value: green,
                range: -2...2,
                step: 0.05,
                displayText: "\(Int((green.wrappedValue * 100).rounded()))%"
            )
            adjustmentSlider(
                labelKey: "imageEditor.channelMixer.blue",
                value: blue,
                range: -2...2,
                step: 0.05,
                displayText: "\(Int((blue.wrappedValue * 100).rounded()))%"
            )
            adjustmentSlider(
                labelKey: "imageEditor.channelMixer.constant",
                value: constant,
                range: -1...1,
                step: 0.05,
                displayText: "\(Int((constant.wrappedValue * 100).rounded()))%"
            )
        }
    }

    private func levelsSlider(
        labelKey: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        displayText: String
    ) -> some View {
        adjustmentSlider(labelKey: labelKey, value: value, range: range, step: step, displayText: displayText)
    }

    private func adjustmentSlider(
        labelKey: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        displayText: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(L10n.text(labelKey))
                Spacer()
                Text(verbatim: displayText)
                    .monospacedDigit()
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
            Slider(value: value, in: range, step: step)
        }
    }

    private var posterizeLevelBinding: Binding<Double> {
        Binding {
            Double(NSImage.posterizeLevelCount(from: viewModel.adjustmentValue))
        } set: { newValue in
            viewModel.adjustmentValue = Double(max(2, min(32, Int(newValue.rounded()))))
        }
    }

    private var statusBar: some View {
        HStack {
            Text(viewModel.statusText)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
            Text(viewModel.pointerText)
            Text(viewModel.sizeText)
            Text(viewModel.zoomText)
        }
        .font(.system(size: 11, weight: .medium).monospacedDigit())
        .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
        .frame(height: 28)
        .padding(.horizontal, 10)
        .background(Color(nsColor: ImageEditorTheme.chrome))
    }

    private var editorBorder: Color {
        Color(nsColor: ImageEditorTheme.border).opacity(0.65)
    }

    func closeWindow() {
        NSApplication.shared.keyWindow?.close()
    }
}

private struct EditorMarqueeShapeActionRow: View {
    let shape: ImageEditorMarqueeShape
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: shape.symbolName)
                .frame(width: 16)
            Text(shape.title)
            Spacer(minLength: 4)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .semibold))
            }
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
        .background(
            isHovered
                ? Color(nsColor: ImageEditorTheme.selected).opacity(0.20)
                : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture(perform: action)
        .focusable(false)
        .xomoFocusEffectDisabled()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(shape.title)
        .accessibilityValue(isSelected ? "selected" : "available")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            action()
        }
    }
}

enum ImageEditorCanvasCursorFamily: Equatable {
    case systemArrow
    case directSelection
    case moveTool
    case grab
    case textInsertion
    case brushTool
    case eraserTool
    case toneBrush
    case retouchBrush
    case selectionMarquee
    case lasso
    case magicWand
    case quickSelection
    case cloneStamp
    case healingBrush
    case crop
    case patch
    case gradient
    case rectangleOutline
    case ellipseOutline
    case paintBucket
    case eyedropper
    case redEye
    case samplingScope
    case vectorPen
    case zoomMagnifier
}

enum ImageEditorCanvasInteractionMode: Equatable {
    case componentLibrary
    case tool(ImageEditorTool)
    case pan
}

enum ImageEditorLayerTransformCursorTarget: Equatable {
    case resize(ImageEditorLayerResizeHandle)
    case rotate
    case referencePoint
}

enum ImageEditorLayerTransformControlLayout {
    /// Eight resize handles plus a draggable transform origin are useful on a
    /// large object, but they consume the entire hit area of a compact icon or
    /// control.  Keep a body-sized move target by reducing compact selections
    /// to their four familiar corner handles.
    static let compactDimensionThreshold: CGFloat = 44

    static func showsControls(
        areExtrasVisible: Bool,
        areTransformControlsVisible: Bool,
        hasSelectedXomoObject: Bool
    ) -> Bool {
        areTransformControlsVisible && (areExtrasVisible || hasSelectedXomoObject)
    }

    static func visibleResizeHandles(in frame: CGRect) -> [ImageEditorLayerResizeHandle] {
        guard frame.width >= compactDimensionThreshold,
              frame.height >= compactDimensionThreshold
        else {
            return [.topLeft, .topRight, .bottomLeft, .bottomRight]
        }
        return ImageEditorLayerResizeHandle.allCases
    }

    static func showsReferencePoint(in frame: CGRect) -> Bool {
        frame.width >= compactDimensionThreshold
            && frame.height >= compactDimensionThreshold
    }

    static func resizeHitRadius(in frame: CGRect, preferredRadius: CGFloat) -> CGFloat {
        guard !showsReferencePoint(in: frame) else { return preferredRadius }
        let compactDimension = min(frame.width, frame.height)
        return min(preferredRadius, max(2, compactDimension * 0.22))
    }
}

extension ImageEditorLayerResizeHandle {
    /// The canvas view uses the conventional top-left UI origin, while the
    /// transform model keeps its historical bottom-left handle semantics.
    /// Convert only at the UI boundary so dragging a visible top handle grows
    /// the object upward instead of collapsing it toward the opposite edge.
    var transformModelHandle: ImageEditorLayerResizeHandle {
        switch self {
        case .topLeft:
            .bottomLeft
        case .top:
            .bottom
        case .topRight:
            .bottomRight
        case .left:
            .left
        case .right:
            .right
        case .bottomLeft:
            .topLeft
        case .bottom:
            .top
        case .bottomRight:
            .topRight
        }
    }
}

enum ImageEditorSelectionCursorMode: String, Equatable, CaseIterable {
    case replace
    case add
    case subtract
    case intersect

    static func from(modifierFlags: NSEvent.ModifierFlags) -> Self {
        let flags = modifierFlags.intersection([.shift, .option])
        switch flags {
        case [.shift, .option]:
            return .intersect
        case [.shift]:
            return .add
        case [.option]:
            return .subtract
        default:
            return .replace
        }
    }
}

enum ImageEditorZoomDirection: Equatable {
    case zoomIn
    case zoomOut

    static func from(modifierFlags: NSEvent.ModifierFlags) -> Self {
        modifierFlags.contains(.option) ? .zoomOut : .zoomIn
    }
}

enum ImageEditorCanvasCursor {
    private static var cursorCache: [String: NSCursor] = [:]

    static func isPointerOverDrawableCanvas(_ point: CGPoint?, imageRect: CGRect) -> Bool {
        guard let point else { return false }
        return imageRect.contains(point)
    }

    static func pressureAdjustedBrushDiameter(
        baseDiameter: CGFloat,
        tool: ImageEditorTool,
        pressure: CGFloat?,
        brushPressureControlsSize: Bool,
        retouchPressureControlsSize: Bool,
        brushPressureSensitivity: CGFloat,
        brushMinimumDiameter: CGFloat = 0,
        retouchPressureSensitivity: CGFloat
    ) -> CGFloat {
        guard let pressure else { return baseDiameter }
        let settings: (isEnabled: Bool, sensitivity: CGFloat, minimumDiameter: CGFloat)
        switch tool {
        case .brush, .eraser:
            settings = (
                brushPressureControlsSize,
                brushPressureSensitivity,
                brushMinimumDiameter
            )
        case .cloneStamp, .dodge, .burn, .sponge, .blur, .sharpen, .smudge, .healingBrush:
            settings = (retouchPressureControlsSize, retouchPressureSensitivity, 0)
        default:
            return baseDiameter
        }
        guard settings.isEnabled else { return baseDiameter }
        return max(
            1,
            baseDiameter * ImageEditorBrushStrokeKernel.pressureDiameterScale(
                mappedPressure: ImageEditorBrushStrokeKernel.mappedPressure(
                    pressure,
                    sensitivity: settings.sensitivity
                ),
                minimumDiameter: settings.minimumDiameter
            )
        )
    }

    /// Resolves the canvas cursor from the active sidebar mode in one place.
    /// The component library is a canvas object mode, not a drawing tool: it
    /// must always restore the native arrow unless the user is explicitly
    /// panning with Space or the hand tool.
    static func cursor(
        for sidebarTab: XomoLeftSidebarTab,
        selectedTool: ImageEditorTool,
        brushDiameter: CGFloat,
        brushTilt: ImageEditorStylusTilt? = nil,
        brushTiltControlsShape: Bool = false,
        brushTipRoundness: CGFloat = 1,
        brushTipAngleDegrees: CGFloat = 0,
        isPointerOverCanvas: Bool = true,
        isPointerOverMovableContent: Bool = true,
        isPointerOverBlockedContent: Bool = false,
        isPointerOverColorSamplerPoint: Bool = false,
        penIsClosing: Bool = false,
        handIsDragging: Bool = false,
        isObjectMoveGestureActive: Bool = false,
        isColorSamplerMoveGestureActive: Bool = false,
        isSpacebarPanning: Bool = false,
        isCanvasPanGestureActive: Bool = false,
        modifierFlags: NSEvent.ModifierFlags = [],
        marqueeShape: ImageEditorMarqueeShape = .rectangle,
        cropHandle: ImageEditorCropHandle? = nil,
        layerTransformTarget: ImageEditorLayerTransformCursorTarget? = nil
    ) -> NSCursor {
        // The dark workspace surrounding the document is not drawable. Keep
        // the native arrow there so a brush/selection cursor never suggests
        // that a click outside the image will edit pixels.
        if isObjectMoveGestureActive {
            return objectMoveCursor(isDuplicating: modifierFlags.contains(.option))
        }
        // Transform controls sit above the canvas and may extend outside the
        // drawable document (the rotation handle intentionally does). Their
        // familiar resize/rotate cursor must therefore win before canvas
        // bounds and component-library arrow fallbacks are considered.
        if let layerTransformTarget {
            return transformCursor(for: layerTransformTarget)
        }
        if !isPointerOverCanvas && !isCanvasPanGestureActive {
            return .arrow
        }
        switch interactionMode(
            for: sidebarTab,
            selectedTool: selectedTool,
            isSpacebarPanning: isSpacebarPanning,
            isCanvasPanGestureActive: isCanvasPanGestureActive
        ) {
        case .componentLibrary:
            // The component library is a selection/placement mode, not the
            // Move tool. Keep the native arrow regardless of the previous
            // toolbox cursor or hovered component. Active object dragging and
            // explicit canvas panning are resolved before this branch.
            return .arrow
        case .pan:
            return cursor(
                for: .hand,
                brushDiameter: brushDiameter,
                handIsDragging: handIsDragging,
                modifierFlags: modifierFlags
            )
        case .tool(let selectedTool):
            if selectedTool == .colorSampler, isColorSamplerMoveGestureActive {
                return objectMoveCursor()
            }
            if selectedTool == .colorSampler, isPointerOverColorSamplerPoint {
                return modifierFlags.contains(.option)
                    ? colorSamplerRemovalCursor()
                    : objectMoveCursor()
            }
            if selectedTool == .move, isPointerOverBlockedContent {
                return .operationNotAllowed
            }
            if selectedTool == .move, !isPointerOverMovableContent {
                return .openHand
            }
            if selectedTool == .move {
                // Sketch and Figma keep the ordinary pointer while hovering a
                // selectable object. The four-way move cursor appears only
                // after a real drag starts, so hover never impersonates pan.
                return .arrow
            }
            return cursor(
                for: selectedTool,
                brushDiameter: brushDiameter,
                brushTilt: brushTilt,
                brushTiltControlsShape: brushTiltControlsShape,
                brushTipRoundness: brushTipRoundness,
                brushTipAngleDegrees: brushTipAngleDegrees,
                penIsClosing: penIsClosing,
                handIsDragging: handIsDragging,
                modifierFlags: modifierFlags,
                marqueeShape: marqueeShape,
                cropHandle: cropHandle
            )
        }
    }

    static func interactionMode(
        for sidebarTab: XomoLeftSidebarTab,
        selectedTool: ImageEditorTool,
        isSpacebarPanning: Bool,
        isCanvasPanGestureActive: Bool
    ) -> ImageEditorCanvasInteractionMode {
        if isSpacebarPanning || isCanvasPanGestureActive {
            return .pan
        }
        return sidebarTab == .components ? .componentLibrary : .tool(selectedTool)
    }

    static func transformTarget(
        at point: CGPoint?,
        frame: CGRect?,
        canResize: Bool,
        canRotate: Bool,
        referencePoint: CGPoint? = nil,
        canMoveReferencePoint: Bool = false,
        hitRadius: CGFloat = 9
    ) -> ImageEditorLayerTransformCursorTarget? {
        guard let point, let frame else { return nil }
        var candidates: [(ImageEditorLayerTransformCursorTarget, CGPoint, CGFloat)] = []
        if canResize {
            let resizeHitRadius = ImageEditorLayerTransformControlLayout.resizeHitRadius(
                in: frame,
                preferredRadius: hitRadius
            )
            candidates.append(contentsOf: ImageEditorLayerTransformControlLayout
                .visibleResizeHandles(in: frame)
                .map {
                (.resize($0), transformHandlePoint($0, in: frame), resizeHitRadius)
            })
        }
        if canRotate {
            candidates.append((.rotate, transformRotateHandlePoint(in: frame), hitRadius))
        }
        if canMoveReferencePoint,
           ImageEditorLayerTransformControlLayout.showsReferencePoint(in: frame),
           let referencePoint {
            candidates.append((.referencePoint, referencePoint, hitRadius))
        }

        return candidates
            .map { candidate in
                let deltaX = candidate.1.x - point.x
                let deltaY = candidate.1.y - point.y
                return (
                    candidate.0,
                    deltaX * deltaX + deltaY * deltaY,
                    candidate.2 * candidate.2
                )
            }
            .filter { $0.1 <= $0.2 }
            .min { $0.1 < $1.1 }?
            .0
    }

    static func resolvedTransformTarget(
        hoveredTarget: ImageEditorLayerTransformCursorTarget?,
        activeResizeHandle: ImageEditorLayerResizeHandle?,
        isRotating: Bool,
        isMovingReferencePoint: Bool = false
    ) -> ImageEditorLayerTransformCursorTarget? {
        if let activeResizeHandle {
            return .resize(activeResizeHandle)
        }
        if isRotating {
            return .rotate
        }
        if isMovingReferencePoint {
            return .referencePoint
        }
        return hoveredTarget
    }

    static func transformHandlePoint(
        _ handle: ImageEditorLayerResizeHandle,
        in frame: CGRect
    ) -> CGPoint {
        switch handle {
        case .topLeft:
            CGPoint(x: frame.minX, y: frame.minY)
        case .top:
            CGPoint(x: frame.midX, y: frame.minY)
        case .topRight:
            CGPoint(x: frame.maxX, y: frame.minY)
        case .left:
            CGPoint(x: frame.minX, y: frame.midY)
        case .right:
            CGPoint(x: frame.maxX, y: frame.midY)
        case .bottomLeft:
            CGPoint(x: frame.minX, y: frame.maxY)
        case .bottom:
            CGPoint(x: frame.midX, y: frame.maxY)
        case .bottomRight:
            CGPoint(x: frame.maxX, y: frame.maxY)
        }
    }

    static func transformRotateHandlePoint(in frame: CGRect) -> CGPoint {
        CGPoint(x: frame.midX, y: frame.minY - 24)
    }

    static func transformCursor(for target: ImageEditorLayerTransformCursorTarget) -> NSCursor {
        switch target {
        case .resize(.top), .resize(.bottom):
            return .resizeUpDown
        case .resize(.left), .resize(.right):
            return .resizeLeftRight
        case .resize(.topLeft), .resize(.bottomRight):
            return diagonalResizeCursor(isForward: true)
        case .resize(.topRight), .resize(.bottomLeft):
            return diagonalResizeCursor(isForward: false)
        case .rotate:
            return rotateTransformCursor()
        case .referencePoint:
            return .crosshair
        }
    }

    private static func moveToolCursor(isDuplicating: Bool = false) -> NSCursor {
        let cacheKey = isDuplicating ? "move-tool:duplicate" : "move-tool"
        if let cachedCursor = cursorCache[cacheKey] {
            return cachedCursor
        }

        let side: CGFloat = 36
        let center = NSPoint(x: side / 2, y: side / 2)
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()

        func drawArrow(from start: NSPoint, to end: NSPoint) {
            let shaft = NSBezierPath()
            shaft.move(to: start)
            shaft.line(to: end)
            NSColor.black.withAlphaComponent(0.94).setStroke()
            shaft.lineWidth = 4
            shaft.stroke()
            NSColor.white.withAlphaComponent(0.98).setStroke()
            shaft.lineWidth = 1.35
            shaft.stroke()

            let angle = atan2(end.y - start.y, end.x - start.x)
            let headLength: CGFloat = 7
            let headWidth: CGFloat = 3.5
            let left = NSPoint(
                x: end.x - cos(angle) * headLength + sin(angle) * headWidth,
                y: end.y - sin(angle) * headLength - cos(angle) * headWidth
            )
            let right = NSPoint(
                x: end.x - cos(angle) * headLength - sin(angle) * headWidth,
                y: end.y - sin(angle) * headLength + cos(angle) * headWidth
            )
            let head = NSBezierPath()
            head.move(to: end)
            head.line(to: left)
            head.line(to: right)
            head.close()
            NSColor.black.withAlphaComponent(0.94).setFill()
            head.fill()
            NSColor.white.withAlphaComponent(0.98).setStroke()
            head.lineWidth = 1.2
            head.stroke()
        }

        drawArrow(
            from: NSPoint(x: center.x, y: center.y - 2),
            to: NSPoint(x: center.x, y: 32)
        )
        drawArrow(
            from: NSPoint(x: center.x, y: center.y + 2),
            to: NSPoint(x: center.x, y: 4)
        )
        drawArrow(
            from: NSPoint(x: center.x - 2, y: center.y),
            to: NSPoint(x: 4, y: center.y)
        )
        drawArrow(
            from: NSPoint(x: center.x + 2, y: center.y),
            to: NSPoint(x: 32, y: center.y)
        )

        if isDuplicating {
            let badgeRect = NSRect(x: 23, y: 23, width: 11, height: 11)
            let badge = NSBezierPath(ovalIn: badgeRect)
            NSColor.black.withAlphaComponent(0.96).setFill()
            badge.fill()
            NSColor.white.withAlphaComponent(0.98).setStroke()
            badge.lineWidth = 1.2
            badge.stroke()

            let badgeCenter = NSPoint(x: badgeRect.midX, y: badgeRect.midY)
            let plus = NSBezierPath()
            plus.move(to: NSPoint(x: badgeCenter.x - 3, y: badgeCenter.y))
            plus.line(to: NSPoint(x: badgeCenter.x + 3, y: badgeCenter.y))
            plus.move(to: NSPoint(x: badgeCenter.x, y: badgeCenter.y - 3))
            plus.line(to: NSPoint(x: badgeCenter.x, y: badgeCenter.y + 3))
            NSColor.black.withAlphaComponent(0.95).setStroke()
            plus.lineWidth = 3
            plus.stroke()
            NSColor.white.setStroke()
            plus.lineWidth = 1.2
            plus.stroke()
        }

        image.unlockFocus()
        return cache(
            NSCursor(image: image, hotSpot: NSPoint(x: center.x, y: side - center.y)),
            for: cacheKey
        )
    }

    /// Photoshop/Sketch/Figma all distinguish object translation from canvas
    /// panning. Keep the four-way move pointer for objects; reserve open/closed
    /// hands exclusively for the document viewport.
    static func objectMoveCursor(isDuplicating: Bool = false) -> NSCursor {
        moveToolCursor(isDuplicating: isDuplicating)
    }

    /// Photoshop exposes Option-click as the familiar way to remove an
    /// existing color sampler. Keep the precision crosshair and add a compact
    /// minus badge only while the pointer is over a real sampler point.
    private static func colorSamplerRemovalCursor() -> NSCursor {
        let cacheKey = "color-sampler:remove"
        if let cachedCursor = cursorCache[cacheKey] {
            return cachedCursor
        }

        let side: CGFloat = 30
        let center = NSPoint(x: 12, y: 18)
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()

        let crosshair = NSBezierPath()
        crosshair.move(to: NSPoint(x: center.x - 8, y: center.y))
        crosshair.line(to: NSPoint(x: center.x + 8, y: center.y))
        crosshair.move(to: NSPoint(x: center.x, y: center.y - 8))
        crosshair.line(to: NSPoint(x: center.x, y: center.y + 8))
        NSColor.black.withAlphaComponent(0.92).setStroke()
        crosshair.lineWidth = 3
        crosshair.stroke()
        NSColor.white.withAlphaComponent(0.98).setStroke()
        crosshair.lineWidth = 1
        crosshair.stroke()

        let target = NSBezierPath(ovalIn: NSRect(
            x: center.x - 3.5,
            y: center.y - 3.5,
            width: 7,
            height: 7
        ))
        NSColor.black.withAlphaComponent(0.92).setStroke()
        target.lineWidth = 3
        target.stroke()
        NSColor.white.withAlphaComponent(0.98).setStroke()
        target.lineWidth = 1
        target.stroke()

        let badgeRect = NSRect(x: 17, y: 3, width: 11, height: 11)
        let badge = NSBezierPath(ovalIn: badgeRect)
        NSColor.black.withAlphaComponent(0.96).setFill()
        badge.fill()
        NSColor.white.withAlphaComponent(0.98).setStroke()
        badge.lineWidth = 1
        badge.stroke()

        let minus = NSBezierPath()
        minus.move(to: NSPoint(x: badgeRect.minX + 3, y: badgeRect.midY))
        minus.line(to: NSPoint(x: badgeRect.maxX - 3, y: badgeRect.midY))
        NSColor.white.setStroke()
        minus.lineWidth = 1.5
        minus.stroke()

        image.unlockFocus()
        return cache(
            NSCursor(
                image: image,
                hotSpot: NSPoint(x: center.x, y: side - center.y)
            ),
            for: cacheKey
        )
    }

    /// Photoshop's Direct Selection tool uses a white node-editing arrow,
    /// while Path Selection keeps the native black pointer. Keeping that
    /// distinction visible makes the two tools understandable at a glance.
    private static func directSelectionCursor() -> NSCursor {
        let cacheKey = "direct-selection"
        if let cachedCursor = cursorCache[cacheKey] {
            return cachedCursor
        }

        let side: CGFloat = 36
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()

        let pointer = NSBezierPath()
        pointer.move(to: NSPoint(x: 8, y: 30))
        pointer.line(to: NSPoint(x: 8, y: 5))
        pointer.line(to: NSPoint(x: 28, y: 19))
        pointer.line(to: NSPoint(x: 19, y: 20))
        pointer.line(to: NSPoint(x: 24, y: 29))
        pointer.line(to: NSPoint(x: 18, y: 32))
        pointer.line(to: NSPoint(x: 13, y: 22))
        pointer.close()

        NSColor.black.withAlphaComponent(0.95).setStroke()
        pointer.lineWidth = 3
        pointer.stroke()
        NSColor.white.withAlphaComponent(0.98).setFill()
        pointer.fill()
        NSColor.black.withAlphaComponent(0.95).setStroke()
        pointer.lineWidth = 1
        pointer.stroke()

        image.unlockFocus()
        return cache(
            NSCursor(image: image, hotSpot: NSPoint(x: 8, y: side - 30)),
            for: cacheKey
        )
    }

    static func tool(
        for sidebarTab: XomoLeftSidebarTab,
        selectedTool: ImageEditorTool,
        isSpacebarPanning: Bool,
        isCanvasPanGestureActive: Bool
    ) -> ImageEditorTool {
        switch interactionMode(
            for: sidebarTab,
            selectedTool: selectedTool,
            isSpacebarPanning: isSpacebarPanning,
            isCanvasPanGestureActive: isCanvasPanGestureActive
        ) {
        case .componentLibrary:
            return .move
        case .tool(let tool):
            return tool
        case .pan:
            return .hand
        }
    }

    static func family(for tool: ImageEditorTool) -> ImageEditorCanvasCursorFamily {
        switch tool {
        case .move:
            .moveTool
        case .hand:
            .grab
        case .text:
            .textInsertion
        case .marquee:
            .selectionMarquee
        case .lasso:
            .lasso
        case .magicWand:
            .magicWand
        case .quickSelection:
            .quickSelection
        case .cloneStamp:
            .cloneStamp
        case .healingBrush:
            .healingBrush
        case .crop:
            .crop
        case .patchTool:
            .patch
        case .gradient:
            .gradient
        case .rectangle:
            .rectangleOutline
        case .ellipse:
            .ellipseOutline
        case .brush:
            .brushTool
        case .eraser:
            .eraserTool
        case .dodge, .burn, .sponge:
            .toneBrush
        case .blur, .sharpen, .smudge:
            .retouchBrush
        case .paintBucket:
            .paintBucket
        case .colorSampler:
            .samplingScope
        case .eyedropper:
            .eyedropper
        case .redEye:
            .redEye
        case .pen:
            .vectorPen
        case .pathSelection:
            .systemArrow
        case .directSelection:
            .directSelection
        case .zoom:
            .zoomMagnifier
        }
    }

    static func cursor(
        for tool: ImageEditorTool,
        brushDiameter: CGFloat,
        brushTilt: ImageEditorStylusTilt? = nil,
        brushTiltControlsShape: Bool = false,
        brushTipRoundness: CGFloat = 1,
        brushTipAngleDegrees: CGFloat = 0,
        penIsClosing: Bool = false,
        handIsDragging: Bool = false,
        modifierFlags: NSEvent.ModifierFlags = [],
        marqueeShape: ImageEditorMarqueeShape = .rectangle,
        cropHandle: ImageEditorCropHandle? = nil
    ) -> NSCursor {
        let selectionMode = ImageEditorSelectionCursorMode.from(modifierFlags: modifierFlags)
        switch family(for: tool) {
        case .systemArrow:
            return .arrow
        case .directSelection:
            return directSelectionCursor()
        case .moveTool:
            return .arrow
        case .grab:
            return handIsDragging ? .closedHand : .openHand
        case .textInsertion:
            return .iBeam
        case .selectionMarquee:
            return selectionMode == .replace
                ? .crosshair
                : familiarSelectionCursor(mode: selectionMode, shape: marqueeShape)
        case .lasso:
            return lassoCursor(mode: selectionMode)
        case .magicWand:
            return magicWandCursor(mode: selectionMode)
        case .quickSelection:
            return quickSelectionCursor(mode: selectionMode)
        case .cloneStamp:
            return modifierFlags.contains(.capsLock)
                ? .crosshair
                : familiarBrushCursor(diameter: brushDiameter)
        case .healingBrush:
            return modifierFlags.contains(.capsLock)
                ? .crosshair
                : familiarBrushCursor(diameter: brushDiameter)
        case .brushTool, .eraserTool:
            return modifierFlags.contains(.capsLock)
                ? .crosshair
                : familiarBrushCursor(
                    diameter: brushDiameter,
                    tilt: brushTilt,
                    tiltControlsShape: brushTiltControlsShape,
                    tipRoundness: brushTipRoundness,
                    tipAngleDegrees: brushTipAngleDegrees
                )
        case .toneBrush, .retouchBrush:
            return modifierFlags.contains(.capsLock)
                ? .crosshair
                : familiarBrushCursor(diameter: brushDiameter)
        case .crop:
            if let cropHandle {
                return cropResizeCursor(for: cropHandle)
            }
            return .crosshair
        case .patch:
            return patchCursor()
        case .gradient:
            return .crosshair
        case .rectangleOutline, .ellipseOutline:
            return .crosshair
        case .paintBucket:
            return paintBucketCursor()
        case .eyedropper:
            return eyedropperCursor()
        case .redEye:
            return .crosshair
        case .samplingScope:
            return .crosshair
        case .vectorPen:
            return penCursor(isClosing: penIsClosing)
        case .zoomMagnifier:
            return zoomCursor(isZoomingOut: modifierFlags.contains(.option))
        }
    }

    /// Keep the cursor vocabulary close to Photoshop/Sketch: selection tools
    /// show a small dashed selection frame, while modifier modes retain the
    /// familiar add/subtract badge so the operation is still obvious.
    private static func familiarSelectionCursor(
        mode: ImageEditorSelectionCursorMode,
        shape: ImageEditorMarqueeShape
    ) -> NSCursor {
        selectionMarqueeCursor(mode: mode, shape: shape)
    }

    /// Brush-like tools share one predictable footprint cursor. The active
    /// tool is already visible in the toolbar, so a large invented symbol on
    /// the pointer only adds noise while painting.
    private static func familiarBrushCursor(
        diameter: CGFloat,
        tilt: ImageEditorStylusTilt? = nil,
        tiltControlsShape: Bool = false,
        tipRoundness: CGFloat = 1,
        tipAngleDegrees: CGFloat = 0
    ) -> NSCursor {
        brushCursor(
            footprint: ImageEditorBrushCursorFootprint(
                diameter: diameter,
                tilt: tilt,
                tiltControlsShape: tiltControlsShape,
                tipRoundness: tipRoundness,
                tipAngleDegrees: tipAngleDegrees
            ),
            symbolName: ""
        )
    }

    private static func brushCursor(
        footprint: ImageEditorBrushCursorFootprint,
        symbolName: String
    ) -> NSCursor {
        let diameter = footprint.majorDiameter
        let cacheKey = "brush:\(symbolName):\(footprint.cacheKey)"
        if let cachedCursor = cursorCache[cacheKey] {
            return cachedCursor
        }
        let side = max(30, diameter + 16)
        let cursorSize = NSSize(width: side, height: side)
        let image = NSImage(size: cursorSize)
        image.lockFocus()
        let center = NSPoint(x: side / 2, y: side / 2)
        let ringRect = NSRect(
            x: -diameter / 2,
            y: -footprint.minorDiameter / 2,
            width: diameter,
            height: footprint.minorDiameter
        )
        let graphicsContext = NSGraphicsContext.current?.cgContext
        graphicsContext?.saveGState()
        graphicsContext?.translateBy(x: center.x, y: center.y)
        graphicsContext?.rotate(
            by: -CGFloat(footprint.rotationDegrees) * .pi / 180
        )
        let ring = NSBezierPath(ovalIn: ringRect)
        NSColor.black.withAlphaComponent(0.88).setStroke()
        ring.lineWidth = 3.5
        ring.stroke()
        NSColor.white.withAlphaComponent(0.96).setStroke()
        ring.lineWidth = 1.75
        ring.stroke()
        graphicsContext?.restoreGState()

        let crossSize: CGFloat = diameter >= 10 ? 3.5 : 2.5
        let cross = NSBezierPath()
        cross.move(to: NSPoint(x: center.x - crossSize, y: center.y))
        cross.line(to: NSPoint(x: center.x + crossSize, y: center.y))
        cross.move(to: NSPoint(x: center.x, y: center.y - crossSize))
        cross.line(to: NSPoint(x: center.x, y: center.y + crossSize))
        NSColor.black.withAlphaComponent(0.9).setStroke()
        cross.lineWidth = 2.5
        cross.stroke()
        NSColor.white.setStroke()
        cross.lineWidth = 1
        cross.stroke()

        if !symbolName.isEmpty {
            drawSymbolBadge(
                named: symbolName,
                origin: NSPoint(
                    x: min(max(center.x + diameter / 2 - 4, 1), side - 18),
                    y: min(max(center.y - diameter / 2 - 8, 1), side - 18)
                )
            )
        }
        image.unlockFocus()
        return cache(
            NSCursor(image: image, hotSpot: NSPoint(x: center.x, y: side - center.y)),
            for: cacheKey
        )
    }

    private static func paintToolCursor(for tool: ImageEditorTool, diameter requestedDiameter: CGFloat) -> NSCursor {
        let diameter = max(3, min(256, requestedDiameter.rounded()))
        let cacheKey = "paint-tool:\(tool.rawValue):\(Int(diameter))"
        if let cachedCursor = cursorCache[cacheKey] {
            return cachedCursor
        }

        let side = max(36, diameter + 20)
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()

        let center = NSPoint(x: side / 2, y: side / 2)
        let ringRect = NSRect(
            x: center.x - diameter / 2,
            y: center.y - diameter / 2,
            width: diameter,
            height: diameter
        )
        let ring = NSBezierPath(ovalIn: ringRect)
        NSColor.black.withAlphaComponent(0.9).setStroke()
        ring.lineWidth = 3.5
        ring.stroke()
        NSColor.white.withAlphaComponent(0.98).setStroke()
        ring.lineWidth = 1.4
        ring.stroke()
        drawCursorCrosshair(center: center)

        let markOrigin = NSPoint(x: min(side - 28, center.x + diameter / 2 - 3), y: min(side - 28, center.y - diameter / 2 - 3))
        switch tool {
        case .brush:
            let handle = NSBezierPath()
            handle.move(to: NSPoint(x: markOrigin.x + 5, y: markOrigin.y + 4))
            handle.line(to: NSPoint(x: markOrigin.x + 19, y: markOrigin.y + 18))
            NSColor.black.withAlphaComponent(0.95).setStroke()
            handle.lineWidth = 5
            handle.stroke()
            NSColor.systemBlue.setStroke()
            handle.lineWidth = 2
            handle.stroke()

            let ferrule = NSBezierPath(rect: NSRect(x: markOrigin.x + 2, y: markOrigin.y + 2, width: 8, height: 7))
            NSColor.black.withAlphaComponent(0.95).setStroke()
            ferrule.lineWidth = 3
            ferrule.stroke()
            NSColor.white.setStroke()
            ferrule.lineWidth = 1
            ferrule.stroke()
        case .eraser:
            let eraser = NSBezierPath()
            eraser.move(to: NSPoint(x: markOrigin.x + 3, y: markOrigin.y + 8))
            eraser.line(to: NSPoint(x: markOrigin.x + 12, y: markOrigin.y + 1))
            eraser.line(to: NSPoint(x: markOrigin.x + 23, y: markOrigin.y + 13))
            eraser.line(to: NSPoint(x: markOrigin.x + 14, y: markOrigin.y + 21))
            eraser.close()
            NSColor.black.withAlphaComponent(0.95).setStroke()
            eraser.lineWidth = 3.5
            eraser.stroke()
            NSColor.systemPink.withAlphaComponent(0.9).setFill()
            eraser.fill()

            let seam = NSBezierPath()
            seam.move(to: NSPoint(x: markOrigin.x + 8, y: markOrigin.y + 5))
            seam.line(to: NSPoint(x: markOrigin.x + 18, y: markOrigin.y + 16))
            NSColor.white.withAlphaComponent(0.9).setStroke()
            seam.lineWidth = 1.2
            seam.stroke()
        default:
            break
        }

        image.unlockFocus()
        return cache(
            NSCursor(image: image, hotSpot: NSPoint(x: center.x, y: side - center.y)),
            for: cacheKey
        )
    }

    private static func toneBrushCursor(for tool: ImageEditorTool) -> NSCursor {
        let cacheKey = "tone-brush:\(tool.rawValue)"
        if let cachedCursor = cursorCache[cacheKey] {
            return cachedCursor
        }

        let side: CGFloat = 38
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()

        let center = NSPoint(x: 13, y: 13)
        let footprint = NSBezierPath(ovalIn: NSRect(x: 3, y: 3, width: 20, height: 20))
        NSColor.black.withAlphaComponent(0.95).setStroke()
        footprint.lineWidth = 4
        footprint.stroke()
        NSColor.white.withAlphaComponent(0.98).setStroke()
        footprint.lineWidth = 1.4
        footprint.stroke()

        switch tool {
        case .dodge:
            let rays = NSBezierPath()
            for angle in stride(from: 0.0, to: Double.pi * 2, by: Double.pi / 4) {
                let startRadius: CGFloat = 12
                let endRadius: CGFloat = 16
                let start = NSPoint(
                    x: center.x + CGFloat(cos(angle)) * startRadius,
                    y: center.y + CGFloat(sin(angle)) * startRadius
                )
                let end = NSPoint(
                    x: center.x + CGFloat(cos(angle)) * endRadius,
                    y: center.y + CGFloat(sin(angle)) * endRadius
                )
                rays.move(to: start)
                rays.line(to: end)
            }
            NSColor.black.withAlphaComponent(0.95).setStroke()
            rays.lineWidth = 3
            rays.stroke()
            NSColor.systemYellow.setStroke()
            rays.lineWidth = 1.3
            rays.stroke()
            NSColor.systemYellow.setFill()
            NSBezierPath(ovalIn: NSRect(x: 8, y: 8, width: 10, height: 10)).fill()
        case .burn:
            let flame = NSBezierPath()
            flame.move(to: NSPoint(x: 13, y: 5))
            flame.curve(to: NSPoint(x: 19, y: 13), controlPoint1: NSPoint(x: 14, y: 9), controlPoint2: NSPoint(x: 20, y: 10))
            flame.curve(to: NSPoint(x: 13, y: 21), controlPoint1: NSPoint(x: 19, y: 20), controlPoint2: NSPoint(x: 17, y: 22))
            flame.curve(to: NSPoint(x: 7, y: 13), controlPoint1: NSPoint(x: 9, y: 21), controlPoint2: NSPoint(x: 6, y: 18))
            flame.curve(to: NSPoint(x: 13, y: 5), controlPoint1: NSPoint(x: 8, y: 9), controlPoint2: NSPoint(x: 12, y: 8))
            flame.close()
            NSColor.systemOrange.setFill()
            flame.fill()
            NSColor.black.withAlphaComponent(0.95).setStroke()
            flame.lineWidth = 3.5
            flame.stroke()
            NSColor.white.withAlphaComponent(0.98).setStroke()
            flame.lineWidth = 1
            flame.stroke()
        case .sponge:
            NSColor.systemGray.setFill()
            footprint.fill()
            let pores = [
                NSPoint(x: 8, y: 9), NSPoint(x: 14, y: 8), NSPoint(x: 18, y: 12),
                NSPoint(x: 10, y: 15), NSPoint(x: 16, y: 18)
            ]
            for pore in pores {
                NSColor.black.withAlphaComponent(0.42).setFill()
                NSBezierPath(ovalIn: NSRect(x: pore.x - 1.2, y: pore.y - 1.2, width: 2.4, height: 2.4)).fill()
            }
            NSColor.white.withAlphaComponent(0.65).setStroke()
            footprint.lineWidth = 1
            footprint.stroke()
        default:
            break
        }

        drawCursorCrosshair(center: center)
        image.unlockFocus()
        return cache(
            NSCursor(image: image, hotSpot: NSPoint(x: center.x, y: side - center.y)),
            for: cacheKey
        )
    }

    private static func retouchBrushCursor(for tool: ImageEditorTool) -> NSCursor {
        let cacheKey = "retouch-brush:\(tool.rawValue)"
        if let cachedCursor = cursorCache[cacheKey] {
            return cachedCursor
        }

        let side: CGFloat = 38
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()

        let center = NSPoint(x: 13, y: 13)
        let footprint = NSBezierPath(ovalIn: NSRect(x: 3, y: 3, width: 20, height: 20))
        NSColor.black.withAlphaComponent(0.95).setStroke()
        footprint.lineWidth = 4
        footprint.stroke()
        NSColor.white.withAlphaComponent(0.98).setStroke()
        footprint.lineWidth = 1.4
        footprint.stroke()

        switch tool {
        case .blur:
            let drop = NSBezierPath()
            drop.move(to: NSPoint(x: 13, y: 7))
            drop.curve(to: NSPoint(x: 18, y: 14), controlPoint1: NSPoint(x: 16, y: 10), controlPoint2: NSPoint(x: 18, y: 12))
            drop.curve(to: NSPoint(x: 13, y: 20), controlPoint1: NSPoint(x: 18, y: 19), controlPoint2: NSPoint(x: 16, y: 20))
            drop.curve(to: NSPoint(x: 8, y: 14), controlPoint1: NSPoint(x: 10, y: 20), controlPoint2: NSPoint(x: 8, y: 18))
            drop.curve(to: NSPoint(x: 13, y: 7), controlPoint1: NSPoint(x: 8, y: 11), controlPoint2: NSPoint(x: 11, y: 9))
            drop.close()
            NSColor.systemBlue.withAlphaComponent(0.88).setFill()
            drop.fill()
            NSColor.black.withAlphaComponent(0.95).setStroke()
            drop.lineWidth = 3
            drop.stroke()
            NSColor.white.withAlphaComponent(0.98).setStroke()
            drop.lineWidth = 1
            drop.stroke()
            drawRetouchMotionLines(color: .systemBlue)
        case .sharpen:
            let star = NSBezierPath()
            star.move(to: NSPoint(x: 13, y: 6))
            star.line(to: NSPoint(x: 15, y: 11))
            star.line(to: NSPoint(x: 20, y: 13))
            star.line(to: NSPoint(x: 15, y: 15))
            star.line(to: NSPoint(x: 13, y: 20))
            star.line(to: NSPoint(x: 11, y: 15))
            star.line(to: NSPoint(x: 6, y: 13))
            star.line(to: NSPoint(x: 11, y: 11))
            star.close()
            NSColor.systemYellow.setFill()
            star.fill()
            NSColor.black.withAlphaComponent(0.95).setStroke()
            star.lineWidth = 3
            star.stroke()
            NSColor.white.withAlphaComponent(0.98).setStroke()
            star.lineWidth = 1
            star.stroke()
            drawRetouchMotionLines(color: .systemYellow)
        case .smudge:
            let swirl = NSBezierPath()
            swirl.move(to: NSPoint(x: 7, y: 17))
            swirl.curve(to: NSPoint(x: 19, y: 17), controlPoint1: NSPoint(x: 9, y: 22), controlPoint2: NSPoint(x: 18, y: 22))
            swirl.curve(to: NSPoint(x: 18, y: 9), controlPoint1: NSPoint(x: 20, y: 14), controlPoint2: NSPoint(x: 15, y: 9))
            swirl.curve(to: NSPoint(x: 10, y: 10), controlPoint1: NSPoint(x: 13, y: 7), controlPoint2: NSPoint(x: 8, y: 9))
            swirl.curve(to: NSPoint(x: 10, y: 15), controlPoint1: NSPoint(x: 8, y: 12), controlPoint2: NSPoint(x: 10, y: 14))
            NSColor.black.withAlphaComponent(0.95).setStroke()
            swirl.lineWidth = 4
            swirl.stroke()
            NSColor.systemPurple.setStroke()
            swirl.lineWidth = 1.5
            swirl.stroke()
            drawRetouchMotionLines(color: .systemPurple)
        default:
            break
        }

        image.unlockFocus()
        return cache(
            NSCursor(image: image, hotSpot: NSPoint(x: center.x, y: side - center.y)),
            for: cacheKey
        )
    }

    private static func drawRetouchMotionLines(color: NSColor) {
        let lines = NSBezierPath()
        lines.move(to: NSPoint(x: 25, y: 20)); lines.line(to: NSPoint(x: 32, y: 20))
        lines.move(to: NSPoint(x: 25, y: 15)); lines.line(to: NSPoint(x: 35, y: 15))
        lines.move(to: NSPoint(x: 25, y: 10)); lines.line(to: NSPoint(x: 31, y: 10))
        NSColor.black.withAlphaComponent(0.95).setStroke()
        lines.lineWidth = 3
        lines.stroke()
        color.setStroke()
        lines.lineWidth = 1
        lines.stroke()
    }

    private static func selectionMarqueeCursor(
        mode: ImageEditorSelectionCursorMode,
        shape: ImageEditorMarqueeShape
    ) -> NSCursor {
        let cacheKey = "selection-marquee:\(shape.rawValue):\(mode.rawValue)"
        if let cachedCursor = cursorCache[cacheKey] {
            return cachedCursor
        }
        let side: CGFloat = 32
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()
        let bounds = NSRect(x: 3, y: 3, width: 16, height: 14)
        let outline = shape.isEllipse
            ? NSBezierPath(ovalIn: bounds)
            : NSBezierPath(rect: bounds)
        outline.setLineDash([3, 2], count: 2, phase: 0)
        NSColor.black.withAlphaComponent(0.95).setStroke()
        outline.lineWidth = 3
        outline.stroke()
        NSColor.white.setStroke()
        outline.lineWidth = 1
        outline.stroke()
        drawCursorCrosshair(center: NSPoint(x: 10, y: 10))
        drawSelectionModifierBadge(mode, side: side)
        image.unlockFocus()
        return cache(
            NSCursor(image: image, hotSpot: NSPoint(x: 10, y: side - 10)),
            for: cacheKey
        )
    }

    private static func lassoCursor(mode: ImageEditorSelectionCursorMode) -> NSCursor {
        let cacheKey = "lasso:\(mode.rawValue)"
        if let cachedCursor = cursorCache[cacheKey] {
            return cachedCursor
        }
        let side: CGFloat = 34
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()
        let loop = NSBezierPath(ovalIn: NSRect(x: 3, y: 8, width: 17, height: 14))
        loop.move(to: NSPoint(x: 16, y: 10))
        loop.curve(
            to: NSPoint(x: 28, y: 3),
            controlPoint1: NSPoint(x: 21, y: 10),
            controlPoint2: NSPoint(x: 25, y: 4)
        )
        NSColor.black.withAlphaComponent(0.95).setStroke()
        loop.lineWidth = 3.5
        loop.stroke()
        NSColor.white.setStroke()
        loop.lineWidth = 1.3
        loop.stroke()
        drawSelectionModifierBadge(mode, side: side)
        image.unlockFocus()
        return cache(
            NSCursor(image: image, hotSpot: NSPoint(x: 9, y: side - 15)),
            for: cacheKey
        )
    }

    private static func magicWandCursor(mode: ImageEditorSelectionCursorMode) -> NSCursor {
        let cacheKey = "magic-wand:\(mode.rawValue)"
        if let cachedCursor = cursorCache[cacheKey] {
            return cachedCursor
        }
        let side: CGFloat = 34
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()
        let wand = NSBezierPath()
        wand.move(to: NSPoint(x: 4, y: 6))
        wand.line(to: NSPoint(x: 23, y: 25))
        NSColor.black.withAlphaComponent(0.95).setStroke()
        wand.lineWidth = 5
        wand.stroke()
        NSColor.white.setStroke()
        wand.lineWidth = 2
        wand.stroke()
        let star = NSBezierPath()
        star.move(to: NSPoint(x: 25, y: 28))
        star.line(to: NSPoint(x: 25, y: 20))
        star.move(to: NSPoint(x: 21, y: 24))
        star.line(to: NSPoint(x: 29, y: 24))
        star.move(to: NSPoint(x: 29, y: 29))
        star.line(to: NSPoint(x: 29, y: 23))
        star.move(to: NSPoint(x: 26, y: 26))
        star.line(to: NSPoint(x: 32, y: 26))
        NSColor.black.withAlphaComponent(0.95).setStroke()
        star.lineWidth = 3
        star.stroke()
        NSColor.white.setStroke()
        star.lineWidth = 1
        star.stroke()
        drawSelectionModifierBadge(mode, side: side)
        image.unlockFocus()
        return cache(
            NSCursor(image: image, hotSpot: NSPoint(x: 5, y: side - 6)),
            for: cacheKey
        )
    }

    private static func quickSelectionCursor(mode: ImageEditorSelectionCursorMode) -> NSCursor {
        let cacheKey = "quick-selection:\(mode.rawValue)"
        if let cachedCursor = cursorCache[cacheKey] {
            return cachedCursor
        }

        let side: CGFloat = 34
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()

        let selectionRing = NSBezierPath(ovalIn: NSRect(x: 3, y: 5, width: 18, height: 18))
        selectionRing.setLineDash([3, 2], count: 2, phase: 0)
        NSColor.black.withAlphaComponent(0.95).setStroke()
        selectionRing.lineWidth = 3.5
        selectionRing.stroke()
        NSColor.white.withAlphaComponent(0.98).setStroke()
        selectionRing.lineWidth = 1.2
        selectionRing.stroke()

        let brush = NSBezierPath()
        brush.move(to: NSPoint(x: 20, y: 26))
        brush.line(to: NSPoint(x: 29, y: 17))
        NSColor.black.withAlphaComponent(0.95).setStroke()
        brush.lineWidth = 4
        brush.stroke()
        NSColor.white.setStroke()
        brush.lineWidth = 1.4
        brush.stroke()

        let plus = NSBezierPath()
        plus.move(to: NSPoint(x: 25, y: 29)); plus.line(to: NSPoint(x: 25, y: 23))
        plus.move(to: NSPoint(x: 22, y: 26)); plus.line(to: NSPoint(x: 28, y: 26))
        NSColor.systemBlue.setStroke()
        plus.lineWidth = 1.5
        plus.stroke()
        drawSelectionModifierBadge(mode, side: side)

        image.unlockFocus()
        return cache(
            NSCursor(image: image, hotSpot: NSPoint(x: 10, y: side - 10)),
            for: cacheKey
        )
    }

    private static func drawSelectionModifierBadge(
        _ mode: ImageEditorSelectionCursorMode,
        side: CGFloat
    ) {
        guard mode != .replace else { return }
        let center = NSPoint(x: side - 7, y: side - 7)
        let badge = NSBezierPath(ovalIn: NSRect(x: center.x - 6, y: center.y - 6, width: 12, height: 12))
        NSColor.black.withAlphaComponent(0.95).setFill()
        badge.fill()
        NSColor.white.withAlphaComponent(0.98).setStroke()
        badge.lineWidth = 1
        badge.stroke()

        let glyph = NSBezierPath()
        switch mode {
        case .add:
            glyph.move(to: NSPoint(x: center.x - 3, y: center.y))
            glyph.line(to: NSPoint(x: center.x + 3, y: center.y))
            glyph.move(to: NSPoint(x: center.x, y: center.y - 3))
            glyph.line(to: NSPoint(x: center.x, y: center.y + 3))
        case .subtract:
            glyph.move(to: NSPoint(x: center.x - 3, y: center.y))
            glyph.line(to: NSPoint(x: center.x + 3, y: center.y))
        case .intersect:
            glyph.move(to: NSPoint(x: center.x - 3, y: center.y - 3))
            glyph.line(to: NSPoint(x: center.x + 3, y: center.y + 3))
            glyph.move(to: NSPoint(x: center.x + 3, y: center.y - 3))
            glyph.line(to: NSPoint(x: center.x - 3, y: center.y + 3))
        case .replace:
            return
        }
        NSColor.systemBlue.setStroke()
        glyph.lineWidth = 1.4
        glyph.stroke()
    }

    private static func cloneStampCursor() -> NSCursor {
        let cacheKey = "clone-stamp"
        if let cachedCursor = cursorCache[cacheKey] {
            return cachedCursor
        }

        let side: CGFloat = 36
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()

        let stamp = NSBezierPath(ovalIn: NSRect(x: 3, y: 5, width: 18, height: 18))
        NSColor.black.withAlphaComponent(0.95).setStroke()
        stamp.lineWidth = 4
        stamp.stroke()
        NSColor.white.withAlphaComponent(0.98).setStroke()
        stamp.lineWidth = 1.4
        stamp.stroke()

        let handle = NSBezierPath()
        handle.move(to: NSPoint(x: 8, y: 8))
        handle.line(to: NSPoint(x: 17, y: 17))
        NSColor.systemBlue.setStroke()
        handle.lineWidth = 2
        handle.stroke()

        let source = NSBezierPath()
        source.move(to: NSPoint(x: 26, y: 8)); source.line(to: NSPoint(x: 26, y: 18))
        source.move(to: NSPoint(x: 21, y: 13)); source.line(to: NSPoint(x: 31, y: 13))
        NSColor.black.withAlphaComponent(0.95).setStroke()
        source.lineWidth = 3
        source.stroke()
        NSColor.white.setStroke()
        source.lineWidth = 1
        source.stroke()

        let arrow = NSBezierPath()
        arrow.move(to: NSPoint(x: 22, y: 28))
        arrow.line(to: NSPoint(x: 31, y: 28))
        arrow.line(to: NSPoint(x: 27, y: 24))
        NSColor.black.withAlphaComponent(0.95).setStroke()
        arrow.lineWidth = 3
        arrow.stroke()
        NSColor.white.setStroke()
        arrow.lineWidth = 1
        arrow.stroke()

        image.unlockFocus()
        return cache(
            NSCursor(image: image, hotSpot: NSPoint(x: 26, y: side - 13)),
            for: cacheKey
        )
    }

    private static func healingBrushCursor() -> NSCursor {
        let cacheKey = "healing-brush"
        if let cachedCursor = cursorCache[cacheKey] {
            return cachedCursor
        }

        let side: CGFloat = 36
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()

        let bandage = NSBezierPath()
        bandage.move(to: NSPoint(x: 6, y: 14))
        bandage.curve(
            to: NSPoint(x: 17, y: 4),
            controlPoint1: NSPoint(x: 8, y: 10),
            controlPoint2: NSPoint(x: 13, y: 5)
        )
        bandage.curve(
            to: NSPoint(x: 28, y: 15),
            controlPoint1: NSPoint(x: 21, y: 4),
            controlPoint2: NSPoint(x: 25, y: 9)
        )
        bandage.curve(
            to: NSPoint(x: 17, y: 26),
            controlPoint1: NSPoint(x: 26, y: 20),
            controlPoint2: NSPoint(x: 21, y: 25)
        )
        bandage.curve(
            to: NSPoint(x: 6, y: 14),
            controlPoint1: NSPoint(x: 13, y: 25),
            controlPoint2: NSPoint(x: 9, y: 20)
        )
        bandage.close()
        NSColor.black.withAlphaComponent(0.95).setStroke()
        bandage.lineWidth = 4
        bandage.stroke()
        NSColor.white.withAlphaComponent(0.98).setFill()
        bandage.fill()

        let seam = NSBezierPath()
        seam.move(to: NSPoint(x: 10, y: 12)); seam.line(to: NSPoint(x: 18, y: 20))
        NSColor.systemBlue.setStroke()
        seam.lineWidth = 1.4
        seam.stroke()

        let source = NSBezierPath()
        source.move(to: NSPoint(x: 27, y: 7)); source.line(to: NSPoint(x: 27, y: 17))
        source.move(to: NSPoint(x: 22, y: 12)); source.line(to: NSPoint(x: 32, y: 12))
        NSColor.black.withAlphaComponent(0.95).setStroke()
        source.lineWidth = 3
        source.stroke()
        NSColor.white.setStroke()
        source.lineWidth = 1
        source.stroke()

        image.unlockFocus()
        return cache(
            NSCursor(image: image, hotSpot: NSPoint(x: 27, y: side - 12)),
            for: cacheKey
        )
    }

    private static func cropResizeCursor(for handle: ImageEditorCropHandle) -> NSCursor {
        switch handle {
        case .move:
            return .openHand
        case .top, .bottom:
            return .resizeUpDown
        case .left, .right:
            return .resizeLeftRight
        case .topLeft, .bottomRight:
            return diagonalResizeCursor(isForward: true)
        case .topRight, .bottomLeft:
            return diagonalResizeCursor(isForward: false)
        }
    }

    private static func diagonalResizeCursor(isForward: Bool) -> NSCursor {
        let cacheKey = "resize-diagonal:\(isForward ? "forward" : "backward")"
        if let cachedCursor = cursorCache[cacheKey] {
            return cachedCursor
        }

        let side: CGFloat = 34
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()

        let start = isForward ? NSPoint(x: 6, y: 6) : NSPoint(x: 6, y: 28)
        let end = isForward ? NSPoint(x: 28, y: 28) : NSPoint(x: 28, y: 6)

        func drawArrow(at tip: NSPoint, toward point: NSPoint, lineWidth: CGFloat) {
            let dx = tip.x - point.x
            let dy = tip.y - point.y
            let length = max(1, hypot(dx, dy))
            let unitX = dx / length
            let unitY = dy / length
            let perpendicularX = -unitY
            let perpendicularY = unitX
            let arrowLength: CGFloat = 7
            let arrowWidth: CGFloat = 3
            let path = NSBezierPath()
            path.move(to: tip)
            path.line(to: NSPoint(
                x: tip.x - unitX * arrowLength + perpendicularX * arrowWidth,
                y: tip.y - unitY * arrowLength + perpendicularY * arrowWidth
            ))
            path.move(to: tip)
            path.line(to: NSPoint(
                x: tip.x - unitX * arrowLength - perpendicularX * arrowWidth,
                y: tip.y - unitY * arrowLength - perpendicularY * arrowWidth
            ))
            path.lineWidth = lineWidth
            path.stroke()
        }

        let shaft = NSBezierPath()
        shaft.move(to: start)
        shaft.line(to: end)
        NSColor.black.withAlphaComponent(0.95).setStroke()
        shaft.lineWidth = 4.5
        shaft.stroke()
        drawArrow(at: start, toward: end, lineWidth: 4.5)
        drawArrow(at: end, toward: start, lineWidth: 4.5)

        NSColor.white.withAlphaComponent(0.98).setStroke()
        shaft.lineWidth = 1.4
        shaft.stroke()
        drawArrow(at: start, toward: end, lineWidth: 1.4)
        drawArrow(at: end, toward: start, lineWidth: 1.4)

        image.unlockFocus()
        return cache(
            NSCursor(image: image, hotSpot: NSPoint(x: side / 2, y: side / 2)),
            for: cacheKey
        )
    }

    /// A compact circular arrow is the established transform convention in
    /// Photoshop, Sketch and Figma. The pointer hotspot remains at the center
    /// of the rotation handle instead of at an arbitrary corner of the icon.
    private static func rotateTransformCursor() -> NSCursor {
        let cacheKey = "transform-rotate"
        if let cachedCursor = cursorCache[cacheKey] {
            return cachedCursor
        }

        let side: CGFloat = 34
        let center = NSPoint(x: side / 2, y: side / 2)
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()

        let arc = NSBezierPath()
        arc.appendArc(
            withCenter: center,
            radius: 9,
            startAngle: 35,
            endAngle: 315,
            clockwise: false
        )
        NSColor.black.withAlphaComponent(0.95).setStroke()
        arc.lineWidth = 4
        arc.stroke()
        NSColor.white.withAlphaComponent(0.98).setStroke()
        arc.lineWidth = 1.5
        arc.stroke()

        let arrow = NSBezierPath()
        arrow.move(to: NSPoint(x: 25.5, y: 12.5))
        arrow.line(to: NSPoint(x: 27.5, y: 20))
        arrow.line(to: NSPoint(x: 20, y: 17.5))
        arrow.close()
        NSColor.black.withAlphaComponent(0.95).setFill()
        arrow.fill()
        NSColor.white.withAlphaComponent(0.98).setStroke()
        arrow.lineWidth = 1
        arrow.stroke()

        let pivot = NSBezierPath(ovalIn: NSRect(x: center.x - 1.5, y: center.y - 1.5, width: 3, height: 3))
        NSColor.black.withAlphaComponent(0.9).setFill()
        pivot.fill()
        NSColor.white.withAlphaComponent(0.92).setStroke()
        pivot.lineWidth = 0.75
        pivot.stroke()

        image.unlockFocus()
        return cache(
            NSCursor(image: image, hotSpot: NSPoint(x: center.x, y: side - center.y)),
            for: cacheKey
        )
    }

    private static func cropCursor() -> NSCursor {
        let cacheKey = "crop"
        if let cachedCursor = cursorCache[cacheKey] {
            return cachedCursor
        }
        let side: CGFloat = 34
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()
        let corners = NSBezierPath()
        corners.move(to: NSPoint(x: 5, y: 13)); corners.line(to: NSPoint(x: 5, y: 5)); corners.line(to: NSPoint(x: 13, y: 5))
        corners.move(to: NSPoint(x: 21, y: 5)); corners.line(to: NSPoint(x: 29, y: 5)); corners.line(to: NSPoint(x: 29, y: 13))
        corners.move(to: NSPoint(x: 29, y: 21)); corners.line(to: NSPoint(x: 29, y: 29)); corners.line(to: NSPoint(x: 21, y: 29))
        corners.move(to: NSPoint(x: 13, y: 29)); corners.line(to: NSPoint(x: 5, y: 29)); corners.line(to: NSPoint(x: 5, y: 21))
        NSColor.black.withAlphaComponent(0.95).setStroke(); corners.lineWidth = 4; corners.stroke()
        NSColor.white.setStroke(); corners.lineWidth = 1.5; corners.stroke()
        image.unlockFocus()
        return cache(NSCursor(image: image, hotSpot: NSPoint(x: 5, y: side - 5)), for: cacheKey)
    }

    private static func patchCursor() -> NSCursor {
        let cacheKey = "patch"
        if let cachedCursor = cursorCache[cacheKey] {
            return cachedCursor
        }
        let side: CGFloat = 34
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()
        let patch = NSBezierPath(roundedRect: NSRect(x: 4, y: 5, width: 18, height: 16), xRadius: 3, yRadius: 3)
        patch.setLineDash([3, 2], count: 2, phase: 0)
        NSColor.black.withAlphaComponent(0.95).setStroke(); patch.lineWidth = 3.5; patch.stroke()
        NSColor.white.setStroke(); patch.lineWidth = 1.2; patch.stroke()
        let arrow = NSBezierPath()
        arrow.move(to: NSPoint(x: 22, y: 24)); arrow.line(to: NSPoint(x: 30, y: 24)); arrow.line(to: NSPoint(x: 26, y: 28))
        NSColor.black.withAlphaComponent(0.95).setStroke(); arrow.lineWidth = 3; arrow.stroke()
        NSColor.white.setStroke(); arrow.lineWidth = 1; arrow.stroke()
        image.unlockFocus()
        return cache(NSCursor(image: image, hotSpot: NSPoint(x: 8, y: side - 8)), for: cacheKey)
    }

    private static func gradientCursor() -> NSCursor {
        let cacheKey = "gradient"
        if let cachedCursor = cursorCache[cacheKey] {
            return cachedCursor
        }
        let side: CGFloat = 34
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()
        let bar = NSRect(x: 3, y: 6, width: 22, height: 8)
        NSGradient(colors: [.white, .systemBlue, .black])?.draw(in: bar, angle: 0)
        let barOutline = NSBezierPath(rect: bar)
        NSColor.black.withAlphaComponent(0.95).setStroke(); barOutline.lineWidth = 3; barOutline.stroke()
        let arrow = NSBezierPath(); arrow.move(to: NSPoint(x: 8, y: 19)); arrow.line(to: NSPoint(x: 8, y: 29)); arrow.move(to: NSPoint(x: 4, y: 25)); arrow.line(to: NSPoint(x: 8, y: 29)); arrow.line(to: NSPoint(x: 12, y: 25))
        NSColor.black.withAlphaComponent(0.95).setStroke(); arrow.lineWidth = 3.5; arrow.stroke()
        NSColor.white.setStroke(); arrow.lineWidth = 1.2; arrow.stroke()
        image.unlockFocus()
        return cache(NSCursor(image: image, hotSpot: NSPoint(x: 8, y: side - 8)), for: cacheKey)
    }

    private static func shapeCursor(for tool: ImageEditorTool) -> NSCursor {
        let cacheKey = "shape:\(tool.rawValue)"
        if let cachedCursor = cursorCache[cacheKey] {
            return cachedCursor
        }
        let side: CGFloat = 34
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()
        let shapeRect = NSRect(x: 4, y: 4, width: 17, height: 17)
        let shape = tool == .ellipse ? NSBezierPath(ovalIn: shapeRect) : NSBezierPath(rect: shapeRect)
        NSColor.black.withAlphaComponent(0.95).setStroke(); shape.lineWidth = 3.5; shape.stroke()
        NSColor.white.setStroke(); shape.lineWidth = 1.2; shape.stroke()
        drawCursorCrosshair(center: NSPoint(x: 12, y: 12))
        image.unlockFocus()
        return cache(NSCursor(image: image, hotSpot: NSPoint(x: 12, y: side - 12)), for: cacheKey)
    }

    private static func drawCursorCrosshair(center: NSPoint) {
        let cross = NSBezierPath()
        cross.move(to: NSPoint(x: center.x - 4, y: center.y)); cross.line(to: NSPoint(x: center.x + 4, y: center.y))
        cross.move(to: NSPoint(x: center.x, y: center.y - 4)); cross.line(to: NSPoint(x: center.x, y: center.y + 4))
        NSColor.black.withAlphaComponent(0.95).setStroke(); cross.lineWidth = 2.5; cross.stroke()
        NSColor.white.setStroke(); cross.lineWidth = 1; cross.stroke()
    }

    private static func paintBucketCursor() -> NSCursor {
        let cacheKey = "paint-bucket"
        if let cachedCursor = cursorCache[cacheKey] {
            return cachedCursor
        }

        let side: CGFloat = 36
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()

        let bucket = NSBezierPath()
        bucket.move(to: NSPoint(x: 8, y: 8))
        bucket.line(to: NSPoint(x: 27, y: 8))
        bucket.line(to: NSPoint(x: 23, y: 24))
        bucket.curve(
            to: NSPoint(x: 12, y: 24),
            controlPoint1: NSPoint(x: 21, y: 27),
            controlPoint2: NSPoint(x: 14, y: 27)
        )
        bucket.close()
        NSColor.black.withAlphaComponent(0.92).setStroke()
        bucket.lineWidth = 3.5
        bucket.stroke()
        NSColor.white.withAlphaComponent(0.96).setFill()
        bucket.fill()

        let handle = NSBezierPath()
        handle.move(to: NSPoint(x: 11, y: 23))
        handle.curve(
            to: NSPoint(x: 27, y: 27),
            controlPoint1: NSPoint(x: 13, y: 31),
            controlPoint2: NSPoint(x: 24, y: 32)
        )
        NSColor.black.withAlphaComponent(0.92).setStroke()
        handle.lineWidth = 3
        handle.stroke()
        NSColor.white.withAlphaComponent(0.92).setStroke()
        handle.lineWidth = 1
        handle.stroke()

        let drop = NSBezierPath(ovalIn: NSRect(x: 24, y: 3, width: 7, height: 9))
        NSColor.systemBlue.setFill()
        drop.fill()
        NSColor.white.setStroke()
        drop.lineWidth = 1
        drop.stroke()

        image.unlockFocus()
        return cache(
            NSCursor(image: image, hotSpot: NSPoint(x: 6, y: side - 6)),
            for: cacheKey
        )
    }

    private static func samplingScopeCursor() -> NSCursor {
        let cacheKey = "sampling-scope"
        if let cachedCursor = cursorCache[cacheKey] {
            return cachedCursor
        }

        let side: CGFloat = 32
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()
        let center = NSPoint(x: 10, y: 10)
        let ring = NSBezierPath(ovalIn: NSRect(x: 3, y: 3, width: 14, height: 14))
        NSColor.black.withAlphaComponent(0.92).setStroke()
        ring.lineWidth = 4
        ring.stroke()
        NSColor.white.withAlphaComponent(0.96).setStroke()
        ring.lineWidth = 1.5
        ring.stroke()
        NSColor.systemBlue.setFill()
        NSBezierPath(ovalIn: NSRect(x: 8, y: 8, width: 4, height: 4)).fill()

        let ticks = NSBezierPath()
        ticks.move(to: NSPoint(x: 10, y: 19))
        ticks.line(to: NSPoint(x: 10, y: 25))
        ticks.move(to: NSPoint(x: 19, y: 10))
        ticks.line(to: NSPoint(x: 25, y: 10))
        NSColor.black.withAlphaComponent(0.92).setStroke()
        ticks.lineWidth = 3
        ticks.stroke()
        NSColor.white.setStroke()
        ticks.lineWidth = 1
        ticks.stroke()

        image.unlockFocus()
        return cache(
            NSCursor(image: image, hotSpot: NSPoint(x: center.x, y: side - center.y)),
            for: cacheKey
        )
    }

    private static func eyedropperCursor() -> NSCursor {
        let cacheKey = "eyedropper"
        if let cachedCursor = cursorCache[cacheKey] {
            return cachedCursor
        }

        let side: CGFloat = 36
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()

        // The tip is the hot spot: the user can see the actual sample point
        // instead of mistaking the tool for a generic crosshair.
        let barrel = NSBezierPath()
        barrel.move(to: NSPoint(x: 7, y: 7))
        barrel.line(to: NSPoint(x: 14, y: 4))
        barrel.line(to: NSPoint(x: 30, y: 20))
        barrel.line(to: NSPoint(x: 27, y: 27))
        barrel.line(to: NSPoint(x: 20, y: 30))
        barrel.line(to: NSPoint(x: 7, y: 17))
        barrel.close()
        NSColor.black.withAlphaComponent(0.95).setStroke()
        barrel.lineWidth = 4
        barrel.stroke()
        NSColor.white.withAlphaComponent(0.98).setFill()
        barrel.fill()

        let seam = NSBezierPath()
        seam.move(to: NSPoint(x: 12, y: 12))
        seam.line(to: NSPoint(x: 25, y: 25))
        NSColor.black.withAlphaComponent(0.88).setStroke()
        seam.lineWidth = 2
        seam.stroke()

        let drop = NSBezierPath()
        drop.move(to: NSPoint(x: 29, y: 4))
        drop.curve(
            to: NSPoint(x: 29, y: 15),
            controlPoint1: NSPoint(x: 24, y: 9),
            controlPoint2: NSPoint(x: 25, y: 13)
        )
        drop.curve(
            to: NSPoint(x: 29, y: 4),
            controlPoint1: NSPoint(x: 33, y: 13),
            controlPoint2: NSPoint(x: 33, y: 9)
        )
        NSColor.systemBlue.setFill()
        drop.fill()
        NSColor.white.setStroke()
        drop.lineWidth = 1
        drop.stroke()

        image.unlockFocus()
        return cache(
            NSCursor(image: image, hotSpot: NSPoint(x: 7, y: side - 7)),
            for: cacheKey
        )
    }

    private static func redEyeCursor() -> NSCursor {
        let cacheKey = "red-eye"
        if let cachedCursor = cursorCache[cacheKey] {
            return cachedCursor
        }

        let side: CGFloat = 34
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()

        let eye = NSBezierPath()
        eye.move(to: NSPoint(x: 3, y: 12))
        eye.curve(
            to: NSPoint(x: 20, y: 12),
            controlPoint1: NSPoint(x: 7, y: 23),
            controlPoint2: NSPoint(x: 16, y: 23)
        )
        eye.curve(
            to: NSPoint(x: 3, y: 12),
            controlPoint1: NSPoint(x: 16, y: 1),
            controlPoint2: NSPoint(x: 7, y: 1)
        )
        NSColor.black.withAlphaComponent(0.95).setStroke()
        eye.lineWidth = 4
        eye.stroke()
        NSColor.white.withAlphaComponent(0.98).setStroke()
        eye.lineWidth = 1.4
        eye.stroke()

        let iris = NSBezierPath(ovalIn: NSRect(x: 8, y: 7, width: 8, height: 10))
        NSColor.systemRed.setFill()
        iris.fill()
        NSColor.black.setStroke()
        iris.lineWidth = 1
        iris.stroke()
        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(x: 11, y: 10, width: 2, height: 4)).fill()

        let cross = NSBezierPath()
        cross.move(to: NSPoint(x: 24, y: 7)); cross.line(to: NSPoint(x: 24, y: 17))
        cross.move(to: NSPoint(x: 19, y: 12)); cross.line(to: NSPoint(x: 29, y: 12))
        NSColor.black.withAlphaComponent(0.95).setStroke()
        cross.lineWidth = 3
        cross.stroke()
        NSColor.white.setStroke()
        cross.lineWidth = 1
        cross.stroke()

        image.unlockFocus()
        return cache(
            NSCursor(image: image, hotSpot: NSPoint(x: 24, y: side - 12)),
            for: cacheKey
        )
    }

    private static func penCursor(isClosing: Bool) -> NSCursor {
        let cacheKey = "pen:\(isClosing)"
        if let cachedCursor = cursorCache[cacheKey] {
            return cachedCursor
        }
        let side: CGFloat = 36
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()

        let nib = NSBezierPath()
        nib.move(to: NSPoint(x: 6, y: 6))
        nib.line(to: NSPoint(x: 11, y: 17))
        nib.line(to: NSPoint(x: 25, y: 31))
        nib.line(to: NSPoint(x: 31, y: 25))
        nib.line(to: NSPoint(x: 17, y: 11))
        nib.close()
        NSColor.black.withAlphaComponent(0.94).setStroke()
        NSColor.white.withAlphaComponent(0.98).setFill()
        nib.lineWidth = 3.5
        nib.stroke()
        nib.fill()

        let slit = NSBezierPath()
        slit.move(to: NSPoint(x: 7, y: 7))
        slit.line(to: NSPoint(x: 18, y: 18))
        slit.lineWidth = 1.7
        NSColor.black.setStroke()
        slit.stroke()
        NSColor.black.setFill()
        NSBezierPath(ovalIn: NSRect(x: 16, y: 16, width: 4, height: 4)).fill()

        if isClosing {
            let closeRing = NSBezierPath(ovalIn: NSRect(x: 0.5, y: 0.5, width: 11, height: 11))
            NSColor.black.withAlphaComponent(0.95).setStroke()
            closeRing.lineWidth = 3.5
            closeRing.stroke()
            NSColor.white.setStroke()
            closeRing.lineWidth = 1.75
            closeRing.stroke()
        }

        image.unlockFocus()
        return cache(NSCursor(image: image, hotSpot: NSPoint(x: 6, y: side - 6)), for: cacheKey)
    }

    private static func zoomCursor(isZoomingOut: Bool) -> NSCursor {
        let cacheKey = "zoom:magnifier:\(isZoomingOut ? "out" : "in")"
        if let cachedCursor = cursorCache[cacheKey] {
            return cachedCursor
        }
        let side: CGFloat = 32
        let center = NSPoint(x: 10, y: 10)
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()

        let lens = NSBezierPath(ovalIn: NSRect(x: 3, y: 3, width: 14, height: 14))
        let handle = NSBezierPath()
        handle.move(to: NSPoint(x: 15, y: 15))
        handle.line(to: NSPoint(x: 25, y: 25))
        let modeMark = NSBezierPath()
        modeMark.move(to: NSPoint(x: 7, y: 10))
        modeMark.line(to: NSPoint(x: 13, y: 10))
        if !isZoomingOut {
            modeMark.move(to: NSPoint(x: 10, y: 7))
            modeMark.line(to: NSPoint(x: 10, y: 13))
        }

        NSColor.black.withAlphaComponent(0.94).setStroke()
        lens.lineWidth = 4
        handle.lineWidth = 5
        modeMark.lineWidth = 3
        lens.stroke()
        handle.stroke()
        modeMark.stroke()
        NSColor.white.setStroke()
        lens.lineWidth = 1.8
        handle.lineWidth = 2
        modeMark.lineWidth = 1.2
        lens.stroke()
        handle.stroke()
        modeMark.stroke()

        image.unlockFocus()
        return cache(
            NSCursor(image: image, hotSpot: NSPoint(x: center.x, y: side - center.y)),
            for: cacheKey
        )
    }

    private static func cache(_ cursor: NSCursor, for key: String) -> NSCursor {
        if cursorCache.count >= 256 {
            cursorCache.removeAll(keepingCapacity: true)
        }
        cursorCache[key] = cursor
        return cursor
    }

    private static func drawSymbolBadge(named symbolName: String, origin: NSPoint) {
        let badgeRect = NSRect(origin: origin, size: NSSize(width: 17, height: 17))
        NSColor.white.withAlphaComponent(0.96).setFill()
        NSBezierPath(roundedRect: badgeRect, xRadius: 3, yRadius: 3).fill()
        NSColor.black.withAlphaComponent(0.90).setStroke()
        let border = NSBezierPath(roundedRect: badgeRect, xRadius: 3, yRadius: 3)
        border.lineWidth = 1.25
        border.stroke()
        let configuration = NSImage.SymbolConfiguration(pointSize: 10, weight: .semibold)
        guard let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
        else { return }
        symbol.draw(in: badgeRect.insetBy(dx: 3, dy: 3), from: .zero, operation: .sourceOver, fraction: 1)
    }
}

struct ImageEditorCursorRectView: NSViewRepresentable {
    let cursor: NSCursor

    func makeNSView(context: Context) -> CursorRectNSView {
        CursorRectNSView(cursor: cursor)
    }

    func updateNSView(_ nsView: CursorRectNSView, context: Context) {
        nsView.cursor = cursor
    }
}

final class CursorRectNSView: NSView {
    var cursor: NSCursor {
        didSet {
            guard cursor !== oldValue else { return }
            window?.invalidateCursorRects(for: self)
        }
    }

    init(cursor: NSCursor) {
        self.cursor = cursor
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.invalidateCursorRects(for: self)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: cursor)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

enum ImageEditorArrowNudge {
    static func delta(
        for keyCode: UInt16,
        modifierFlags: NSEvent.ModifierFlags
    ) -> CGSize? {
        let relevantFlags = modifierFlags.intersection([.option, .shift, .command, .control])
        let amount: CGFloat
        switch relevantFlags {
        case []:
            amount = 1
        case [.option]:
            amount = 5
        case [.shift]:
            amount = 10
        default:
            return nil
        }

        switch keyCode {
        case 123:
            return CGSize(width: -amount, height: 0)
        case 124:
            return CGSize(width: amount, height: 0)
        case 125:
            return CGSize(width: 0, height: amount)
        case 126:
            return CGSize(width: 0, height: -amount)
        default:
            return nil
        }
    }
}

enum ImageEditorKeyboardShortcutAction: Equatable {
    case newCanvas
    case openProject
    case saveProject
    case export
    case openFigmaLinkImport
    case cutSelectionClipboard
    case copySelectionClipboard
    case copyMergedClipboard
    case copySelectedLayersClipboard
    case pasteClipboardLayer
    case pasteClipboardIntoSelection
    case pasteClipboardInPlaceLayer
    case toggleTransformControls
    case fillSelection
    case fillSelectionBackground
    case clearSelectionPixels
    case resizeImage
    case resizeCanvas
    case levels
    case curves
    case colorBalance
    case hueSaturation
    case toneRange(ImageEditorToneRange)
    case spongeMode(ImageEditorSpongeMode)
    case desaturate
    case invertPixels
    case autoLevels
    case autoContrast
    case autoColor
    case newLayer
    case duplicateSelectionOrLayer
    case cutSelectionToLayer
    case groupSelectedLayer
    case ungroupSelectedLayers
    case mergeDown
    case stampVisible
    case mergeVisible
    case layerTop
    case layerUp
    case layerDown
    case layerBottom
    case selectAll
    case clearSelection
    case reselectSelection
    case invertSelection
    case featherSelection
    case toggleQuickMask
    case applyLastFilter
    case toggleRulers
    case toggleGuides
    case toggleGuideSnapping
    case toggleGuidesLocked
    case toggleGrid
    case zoomIn
    case zoomOut
    case actualPixels
    case fitOnScreen
    case toggleWorkspaceChrome
    case toggleRightDock
    case showInfoSummary
    case showColorSummary
    case showBrushSummary
    case showLayersPanel
    case undo
    case redo

    var isBlockedByTextInput: Bool {
        switch self {
        case .toggleQuickMask, .toneRange, .spongeMode:
            true
        default:
            false
        }
    }

    static func resolve(
        charactersIgnoringModifiers: String?,
        modifierFlags: NSEvent.ModifierFlags,
        keyCode: UInt16? = nil,
        activeTool: ImageEditorTool? = nil
    ) -> ImageEditorKeyboardShortcutAction? {
        let key = charactersIgnoringModifiers?.lowercased() ?? ""
        let relevantFlags = modifierFlags.intersection([.command, .option, .shift, .control])

        if let range = ImageEditorToneRangeShortcut.resolve(
            charactersIgnoringModifiers: charactersIgnoringModifiers,
            modifierFlags: modifierFlags,
            activeTool: activeTool
        ) {
            return .toneRange(range)
        }

        if let mode = ImageEditorSpongeModeShortcut.resolve(
            charactersIgnoringModifiers: charactersIgnoringModifiers,
            modifierFlags: modifierFlags,
            activeTool: activeTool
        ) {
            return .spongeMode(mode)
        }

        if keyCode == 51 || keyCode == 117 {
            if relevantFlags.isEmpty { return .clearSelectionPixels }
            if relevantFlags == [.option] { return .fillSelection }
            if relevantFlags == [.command] { return .fillSelectionBackground }
            return nil
        }

        if keyCode == 48 {
            if relevantFlags.isEmpty { return .toggleWorkspaceChrome }
            if relevantFlags == [.shift] { return .toggleRightDock }
            return nil
        }

        if relevantFlags.isEmpty {
            switch keyCode {
            case 96: return .showBrushSummary
            case 97: return .showColorSummary
            case 98: return .showLayersPanel
            case 100: return .showInfoSummary
            default: break
            }
        }

        if key == "n", relevantFlags == [.command] { return .newCanvas }
        if key == "z", relevantFlags == [.option] { return .undo }
        if key == "o", relevantFlags == [.command] { return .openProject }
        if key == "s", relevantFlags == [.command] { return .saveProject }
        if key == "s", relevantFlags == [.command, .option, .shift] { return .export }
        if key == "f", relevantFlags == [.command, .option] { return .openFigmaLinkImport }
        if key == "z", relevantFlags == [.command, .option] { return .undo }
        if key == "z", relevantFlags == [.command] { return .undo }
        if key == "z", relevantFlags == [.command, .shift] { return .redo }
        if key == "x", relevantFlags == [.command] { return .cutSelectionClipboard }
        if key == "c", relevantFlags == [.command] { return .copySelectionClipboard }
        if key == "c", relevantFlags == [.command, .shift] { return .copyMergedClipboard }
        if key == "c", relevantFlags == [.command, .option, .shift] { return .copySelectedLayersClipboard }
        if key == "v", relevantFlags == [.command] { return .pasteClipboardLayer }
        if key == "v", relevantFlags == [.command, .shift] { return .pasteClipboardIntoSelection }
        if key == "v", relevantFlags == [.command, .option, .shift] { return .pasteClipboardInPlaceLayer }
        if key == "t", relevantFlags == [.command] { return .toggleTransformControls }
        if key == "i", relevantFlags == [.command, .option] { return .resizeImage }
        if key == "c", relevantFlags == [.command, .option] { return .resizeCanvas }
        if key == "l", relevantFlags == [.command] { return .levels }
        if key == "m", relevantFlags == [.command] { return .curves }
        if key == "b", relevantFlags == [.command] { return .colorBalance }
        if key == "u", relevantFlags == [.command] { return .hueSaturation }
        if key == "u", relevantFlags == [.command, .shift] { return .desaturate }
        if key == "i", relevantFlags == [.command] { return .invertPixels }
        if key == "l", relevantFlags == [.command, .shift] { return .autoLevels }
        if key == "l", relevantFlags == [.command, .option, .shift] { return .autoContrast }
        if key == "b", relevantFlags == [.command, .shift] { return .autoColor }
        if key == "n", relevantFlags == [.command, .shift] { return .newLayer }
        if key == "j", relevantFlags == [.command] { return .duplicateSelectionOrLayer }
        if key == "j", relevantFlags == [.command, .shift] { return .cutSelectionToLayer }
        if key == "g", relevantFlags == [.command] { return .groupSelectedLayer }
        if key == "g", relevantFlags == [.command, .shift] { return .ungroupSelectedLayers }
        if key == "e", relevantFlags == [.command] { return .mergeDown }
        if key == "e", relevantFlags == [.command, .option, .shift] { return .stampVisible }
        if key == "e", relevantFlags == [.command, .shift] { return .mergeVisible }
        if key == "]", relevantFlags == [.command, .shift] { return .layerTop }
        if key == "]", relevantFlags == [.command] { return .layerUp }
        if key == "[", relevantFlags == [.command] { return .layerDown }
        if key == "[", relevantFlags == [.command, .shift] { return .layerBottom }
        if key == "a", relevantFlags == [.command] { return .selectAll }
        if key == "d", relevantFlags == [.command] { return .clearSelection }
        if key == "d", relevantFlags == [.command, .shift] { return .reselectSelection }
        if key == "i", relevantFlags == [.command, .shift] { return .invertSelection }
        if key == "d", relevantFlags == [.command, .option] { return .featherSelection }
        if key == "q", relevantFlags.isEmpty { return .toggleQuickMask }
        if key == "f", relevantFlags == [.command] { return .applyLastFilter }
        if key == "r", relevantFlags == [.command] { return .toggleRulers }
        if key == ";", relevantFlags == [.command] { return .toggleGuides }
        if key == ";", relevantFlags == [.command, .shift] { return .toggleGuideSnapping }
        if key == ";", relevantFlags == [.command, .option] { return .toggleGuidesLocked }
        if key == "'", relevantFlags == [.command] { return .toggleGrid }
        if (key == "+" || key == "="), relevantFlags == [.command] || relevantFlags == [.command, .shift] { return .zoomIn }
        if key == "-", relevantFlags == [.command] { return .zoomOut }
        if (key == "+" || key == "="),
           relevantFlags == [.option] || relevantFlags == [.option, .shift] {
            return .zoomIn
        }
        if key == "-", relevantFlags == [.option] { return .zoomOut }
        if key == "1", relevantFlags == [.command] { return .actualPixels }
        if key == "0", relevantFlags == [.command] { return .fitOnScreen }
        return nil
    }
}

struct ImageEditorKeyboardShortcutEventSignature: Equatable {
    let windowNumber: Int
    let eventNumber: Int
    let timestamp: TimeInterval
    let typeRawValue: UInt
    let keyCode: UInt16

    init(
        windowNumber: Int,
        eventNumber: Int,
        timestamp: TimeInterval,
        typeRawValue: UInt,
        keyCode: UInt16
    ) {
        self.windowNumber = windowNumber
        self.eventNumber = eventNumber
        self.timestamp = timestamp
        self.typeRawValue = typeRawValue
        self.keyCode = keyCode
    }

    init(event: NSEvent) {
        self.init(
            windowNumber: event.windowNumber,
            eventNumber: event.eventNumber,
            timestamp: event.timestamp,
            typeRawValue: event.type.rawValue,
            keyCode: event.keyCode
        )
    }

    static var currentKeyEvent: ImageEditorKeyboardShortcutEventSignature? {
        guard let event = NSApp.currentEvent,
              event.type == .keyDown || event.type == .keyUp
        else { return nil }
        return ImageEditorKeyboardShortcutEventSignature(event: event)
    }
}

@MainActor
enum ImageEditorKeyboardShortcutWindowRegistry {
    private static var activeCoordinatorByWindow: [ObjectIdentifier: ObjectIdentifier] = [:]

    static func register(coordinator: AnyObject, for window: AnyObject) {
        activeCoordinatorByWindow[ObjectIdentifier(window)] = ObjectIdentifier(coordinator)
    }

    static func unregister(coordinator: AnyObject, from window: AnyObject) {
        let windowID = ObjectIdentifier(window)
        guard activeCoordinatorByWindow[windowID] == ObjectIdentifier(coordinator) else { return }
        activeCoordinatorByWindow.removeValue(forKey: windowID)
    }

    static func isActive(coordinator: AnyObject, for window: AnyObject) -> Bool {
        activeCoordinatorByWindow[ObjectIdentifier(window)] == ObjectIdentifier(coordinator)
    }

    static func reset() {
        activeCoordinatorByWindow.removeAll()
    }
}

enum ImageEditorPanelToggleAction: Equatable {
    case workspaceChrome
    case rightDock
}

@MainActor
enum ImageEditorPanelToggleDispatchGate {
    private struct Dispatch: Equatable {
        let action: ImageEditorPanelToggleAction
        let event: ImageEditorKeyboardShortcutEventSignature
    }

    private static var lastDispatch: Dispatch?

    static func shouldDispatch(
        _ action: ImageEditorPanelToggleAction,
        event: ImageEditorKeyboardShortcutEventSignature?
    ) -> Bool {
        guard let event else { return true }
        let dispatch = Dispatch(action: action, event: event)
        guard dispatch != lastDispatch else { return false }
        lastDispatch = dispatch
        return true
    }

    static func reset() {
        lastDispatch = nil
    }
}

enum ImageEditorEscapeCancelDispatcher {
    static func handle(
        cancelSelectedObject: () -> Bool,
        discardPendingSmartFilterChanges: () -> Bool
    ) -> Bool {
        if cancelSelectedObject() {
            return true
        }
        return discardPendingSmartFilterChanges()
    }
}

struct ImageEditorKeyboardShortcutMonitor: NSViewRepresentable {
    let perform: (ImageEditorKeyboardShortcutAction) -> Void
    let activeTool: ImageEditorTool
    let nudgeSelected: (CGSize) -> Void
    let deleteSelectedObject: () -> Bool
    let cancelSelectedObject: () -> Bool
    let discardPendingSmartFilterChanges: () -> Bool
    let deleteSelectedHistory: () -> Bool
    let setSpacebarPanning: (Bool) -> Void
    let setCanvasModifierFlags: (NSEvent.ModifierFlags) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            perform: perform,
            activeTool: activeTool,
            nudgeSelected: nudgeSelected,
            deleteSelectedObject: deleteSelectedObject,
            cancelSelectedObject: cancelSelectedObject,
            discardPendingSmartFilterChanges: discardPendingSmartFilterChanges,
            deleteSelectedHistory: deleteSelectedHistory,
            setSpacebarPanning: setSpacebarPanning,
            setCanvasModifierFlags: setCanvasModifierFlags
        )
    }

    func makeNSView(context: Context) -> KeyboardShortcutMonitorNSView {
        KeyboardShortcutMonitorNSView(coordinator: context.coordinator)
    }

    func updateNSView(_ nsView: KeyboardShortcutMonitorNSView, context: Context) {
        context.coordinator.perform = perform
        context.coordinator.activeTool = activeTool
        context.coordinator.nudgeSelected = nudgeSelected
        context.coordinator.deleteSelectedObject = deleteSelectedObject
        context.coordinator.cancelSelectedObject = cancelSelectedObject
        context.coordinator.discardPendingSmartFilterChanges = discardPendingSmartFilterChanges
        context.coordinator.deleteSelectedHistory = deleteSelectedHistory
        context.coordinator.setSpacebarPanning = setSpacebarPanning
        context.coordinator.setCanvasModifierFlags = setCanvasModifierFlags
    }

    final class Coordinator {
        private(set) weak var window: NSWindow?
        var perform: (ImageEditorKeyboardShortcutAction) -> Void
        var activeTool: ImageEditorTool
        var nudgeSelected: (CGSize) -> Void
        var deleteSelectedObject: () -> Bool
        var cancelSelectedObject: () -> Bool
        var discardPendingSmartFilterChanges: () -> Bool
        var deleteSelectedHistory: () -> Bool
        var setSpacebarPanning: (Bool) -> Void
        var setCanvasModifierFlags: (NSEvent.ModifierFlags) -> Void
        private var eventMonitor: Any?
        private var appDeactivateObserver: Any?
        private var isSpacebarPanning = false

        init(
            perform: @escaping (ImageEditorKeyboardShortcutAction) -> Void,
            activeTool: ImageEditorTool,
            nudgeSelected: @escaping (CGSize) -> Void,
            deleteSelectedObject: @escaping () -> Bool,
            cancelSelectedObject: @escaping () -> Bool,
            discardPendingSmartFilterChanges: @escaping () -> Bool,
            deleteSelectedHistory: @escaping () -> Bool,
            setSpacebarPanning: @escaping (Bool) -> Void,
            setCanvasModifierFlags: @escaping (NSEvent.ModifierFlags) -> Void
        ) {
            self.perform = perform
            self.activeTool = activeTool
            self.nudgeSelected = nudgeSelected
            self.deleteSelectedObject = deleteSelectedObject
            self.cancelSelectedObject = cancelSelectedObject
            self.discardPendingSmartFilterChanges = discardPendingSmartFilterChanges
            self.deleteSelectedHistory = deleteSelectedHistory
            self.setSpacebarPanning = setSpacebarPanning
            self.setCanvasModifierFlags = setCanvasModifierFlags
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
                self?.handle(event) ?? event
            }
            appDeactivateObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didResignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.stopSpacebarPanning()
            }
        }

        deinit {
            if let eventMonitor {
                NSEvent.removeMonitor(eventMonitor)
            }
            if let appDeactivateObserver {
                NotificationCenter.default.removeObserver(appDeactivateObserver)
            }
        }

        func attach(to newWindow: NSWindow?) {
            if let window {
                ImageEditorKeyboardShortcutWindowRegistry.unregister(coordinator: self, from: window)
            }
            window = newWindow
            if let newWindow {
                ImageEditorKeyboardShortcutWindowRegistry.register(coordinator: self, for: newWindow)
            }
        }

        private func handle(_ event: NSEvent) -> NSEvent? {
            guard let window,
                  event.window === window,
                  ImageEditorKeyboardShortcutWindowRegistry.isActive(coordinator: self, for: window)
            else { return event }
            setCanvasModifierFlags(event.modifierFlags.intersection([.shift, .option, .capsLock]))
            let relevantFlags = event.modifierFlags.intersection([.command, .option, .shift, .control])
            if event.keyCode == 49, relevantFlags.isEmpty {
                if event.type == .keyUp, isSpacebarPanning {
                    stopSpacebarPanning()
                    return nil
                }
                if event.type == .keyDown, !isTextInputActive {
                    isSpacebarPanning = true
                    setSpacebarPanning(true)
                    return nil
                }
            }
            let isDelete = event.keyCode == 51 || event.keyCode == 117
            if event.type == .keyDown,
               event.keyCode == 53,
               relevantFlags.isEmpty,
               !isTextInputActive {
                if ImageEditorEscapeCancelDispatcher.handle(
                    cancelSelectedObject: cancelSelectedObject,
                    discardPendingSmartFilterChanges: discardPendingSmartFilterChanges
                ) {
                    return nil
                }
            }
            if event.type == .keyDown,
               isDelete,
               relevantFlags.isEmpty,
               !isTextInputActive,
               deleteSelectedObject() {
                return nil
            }
            if event.type == .keyDown,
               isDelete,
               relevantFlags.isEmpty,
               !isTextInputActive,
               deleteSelectedHistory() {
                return nil
            }

            if event.type == .keyDown,
               !isTextInputActive,
               let delta = ImageEditorArrowNudge.delta(
                   for: event.keyCode,
                   modifierFlags: event.modifierFlags
               ) {
                nudgeSelected(delta)
                return nil
            }

            if event.type == .keyDown,
               let action = ImageEditorKeyboardShortcutAction.resolve(
                charactersIgnoringModifiers: event.charactersIgnoringModifiers,
                modifierFlags: event.modifierFlags,
                keyCode: event.keyCode,
                activeTool: activeTool
            ) {
                if action.isBlockedByTextInput, isTextInputActive {
                    return event
                }
                perform(action)
                return nil
            }
            return event
        }

        private var isTextInputActive: Bool {
            window?.firstResponder is NSTextView || window?.firstResponder is NSTextField
        }

        private func stopSpacebarPanning() {
            guard isSpacebarPanning else { return }
            isSpacebarPanning = false
            setSpacebarPanning(false)
            setCanvasModifierFlags([])
        }
    }
}

final class KeyboardShortcutMonitorNSView: NSView {
    private weak var coordinator: ImageEditorKeyboardShortcutMonitor.Coordinator?

    init(coordinator: ImageEditorKeyboardShortcutMonitor.Coordinator) {
        self.coordinator = coordinator
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        coordinator?.attach(to: window)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

enum ImageEditorComputerUseQA {
    static var usesScreenshotOnlyAccessibilityTree: Bool {
#if COMPUTER_USE_QA
        true
#else
        false
#endif
    }
}

struct DisabledMaskSlash: View {
    var body: some View {
        Rectangle()
            .fill(Color.red.opacity(0.85))
            .frame(width: 30, height: 3)
            .rotationEffect(.degrees(-38))
            .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 0)
    }
}

enum EditorPanelTitleAppearance {
    static let foregroundColor = NSColor.white
}

struct EditorPanel<Content: View>: View {
    let title: String
    let showsTitle: Bool
    @ViewBuilder let content: Content

    init(title: String, showsTitle: Bool = true, @ViewBuilder content: () -> Content) {
        self.title = title
        self.showsTitle = showsTitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsTitle {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(nsColor: EditorPanelTitleAppearance.foregroundColor))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color(nsColor: ImageEditorTheme.chrome))
            }

            content
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

enum ImageEditorDockDisclosureAppearance {
    static let foregroundColor = NSColor.white

    static func attributedTitle(_ title: String) -> NSAttributedString {
        NSAttributedString(
            string: title,
            attributes: [
                .foregroundColor: foregroundColor,
                .font: NSFont.systemFont(ofSize: 12, weight: .bold)
            ]
        )
    }
}

final class ImageEditorDockDisclosureNativeLabel: NSView {
    var title = "" {
        didSet {
            invalidateIntrinsicContentSize()
            needsDisplay = true
        }
    }

    override var acceptsFirstResponder: Bool { false }

    override var intrinsicContentSize: NSSize {
        let size = attributedTitle.size()
        return NSSize(width: ceil(size.width), height: max(16, ceil(size.height)))
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let value = attributedTitle
        let size = value.size()
        value.draw(at: NSPoint(
            x: 0,
            y: max(0, (bounds.height - size.height) / 2)
        ))
    }

    var attributedTitle: NSAttributedString {
        ImageEditorDockDisclosureAppearance.attributedTitle(title)
    }
}

struct ImageEditorDockDisclosureLabel: NSViewRepresentable {
    let title: String

    func makeNSView(context: Context) -> ImageEditorDockDisclosureNativeLabel {
        let label = ImageEditorDockDisclosureNativeLabel()
        configure(label)
        return label
    }

    func updateNSView(_ label: ImageEditorDockDisclosureNativeLabel, context: Context) {
        configure(label)
    }

    private func configure(_ label: ImageEditorDockDisclosureNativeLabel) {
        label.appearance = NSAppearance(named: .darkAqua)
        label.identifier = NSUserInterfaceItemIdentifier("image-editor-dock-section-title")
        label.title = title
    }
}

struct EditorDockDisclosure<Content: View>: View {
    let title: String
    let systemImage: String
    @Binding var isExpanded: Bool
    @ViewBuilder let content: Content

    init(
        title: String,
        systemImage: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        _isExpanded = isExpanded
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                isExpanded.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 18)
                        .foregroundStyle(Color(nsColor: ImageEditorDockDisclosureAppearance.foregroundColor))
                    ImageEditorDockDisclosureLabel(title: title)
                        .fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 0)
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(nsColor: ImageEditorDockDisclosureAppearance.foregroundColor))
                }
                .padding(.horizontal, 10)
                .frame(height: 34)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("image-editor-dock-section-\(title)")
            .accessibilityValue(isExpanded ? "expanded" : "collapsed")

            if isExpanded {
                Divider().overlay(Color(nsColor: ImageEditorTheme.border))
                content
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .clipped()
            }
        }
        .background(Color(nsColor: ImageEditorTheme.panelRaised).opacity(0.48))
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(Color(nsColor: ImageEditorTheme.border).opacity(0.75), lineWidth: 1)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct ImageEditorMarqueeToolSymbol: View {
    let shape: ImageEditorMarqueeShape

    var body: some View {
        Canvas { context, _ in
            let iconColor = Color.white.opacity(0.94)
            let iconRect = CGRect(x: 6.5, y: 7.5, width: 16, height: 12)
            let outline = shape.isEllipse
                ? Path(ellipseIn: iconRect)
                : Path(roundedRect: iconRect, cornerRadius: 1)
            context.stroke(
                outline,
                with: .color(iconColor),
                style: StrokeStyle(lineWidth: 1.5, dash: [2.5, 2])
            )

            var indicator = Path()
            indicator.move(to: CGPoint(x: 23, y: 22))
            indicator.addLine(to: CGPoint(x: 27, y: 22))
            indicator.addLine(to: CGPoint(x: 25, y: 25))
            indicator.closeSubpath()
            context.fill(indicator, with: .color(iconColor))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Tool visuals stay in SwiftUI while a single AppKit grid surface owns mouse
/// hit testing. Keeping one stable native surface avoids `LazyVGrid` recycling
/// dozens of transparent representables into stale or zero-sized hit areas.
private struct EditorToolRailTile<Label: View>: View {
    let isSelected: Bool
    let isHovered: Bool
    let action: () -> Void
    @ViewBuilder let label: Label

    init(
        isSelected: Bool,
        isHovered: Bool,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.isSelected = isSelected
        self.isHovered = isHovered
        self.action = action
        self.label = label()
    }

    private var background: Color {
        if isSelected {
            return Color(nsColor: ImageEditorTheme.selected)
        }
        return isHovered
            ? Color(nsColor: ImageEditorTheme.selected).opacity(0.20)
            : .clear
    }

    var body: some View {
        label
            .foregroundStyle(isSelected ? .white : Color(nsColor: ImageEditorTheme.text))
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(isSelected ? Color.white.opacity(0.16) : .clear, lineWidth: 1)
            }
            .allowsHitTesting(false)
            .focusable(false)
            .xomoFocusEffectDisabled()
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                action()
            }
    }
}

private struct EditorToolRailGridClickSurface: NSViewRepresentable {
    let toolCount: Int
    let marqueeToolIndex: Int?
    let onActivate: (Int) -> Void
    let onToggleMarqueeMenu: () -> Void
    let onHoverChanged: (Int?) -> Void

    func makeNSView(context: Context) -> EditorToolRailGridClickNSView {
        let view = EditorToolRailGridClickNSView()
        configure(view)
        return view
    }

    func updateNSView(_ nsView: EditorToolRailGridClickNSView, context: Context) {
        configure(nsView)
    }

    static func dismantleNSView(_ nsView: EditorToolRailGridClickNSView, coordinator: ()) {
        nsView.onHoverChanged?(nil)
        nsView.activationHandler = nil
        nsView.marqueeMenuHandler = nil
        nsView.onHoverChanged = nil
    }

    private func configure(_ view: EditorToolRailGridClickNSView) {
        view.toolCount = toolCount
        view.marqueeToolIndex = marqueeToolIndex
        view.activationHandler = onActivate
        view.marqueeMenuHandler = onToggleMarqueeMenu
        view.onHoverChanged = onHoverChanged
    }
}

final class EditorToolRailGridClickNSView: NSView {
    var toolCount = 0
    var marqueeToolIndex: Int?
    var activationHandler: ((Int) -> Void)?
    var marqueeMenuHandler: (() -> Void)?
    var onHoverChanged: ((Int?) -> Void)?
    private var hoverTrackingArea: NSTrackingArea?

    override var acceptsFirstResponder: Bool { false }
    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        guard event.buttonNumber == 0 else {
            super.mouseDown(with: event)
            return
        }
        let point = convert(event.locationInWindow, from: nil)
        guard let hit = toolHit(at: point) else { return }
        if hit.index == marqueeToolIndex,
           hit.localPoint.x >= imageEditorToolButtonHitSize - 11,
           hit.localPoint.y >= imageEditorToolButtonHitSize - 11 {
            marqueeMenuHandler?()
            return
        }
        activationHandler?(hit.index)
    }

    override func updateTrackingAreas() {
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .inVisibleRect, .mouseEnteredAndExited, .mouseMoved],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        hoverTrackingArea = trackingArea
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) {
        updateHover(with: event)
    }

    override func mouseMoved(with event: NSEvent) {
        updateHover(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChanged?(nil)
    }

    func toolHit(at point: NSPoint) -> (index: Int, localPoint: NSPoint)? {
        guard bounds.contains(point) else { return nil }
        let pitch = imageEditorToolButtonHitSize + imageEditorToolGridSpacing
        let column = Int(point.x / pitch)
        let row = Int(point.y / pitch)
        guard column >= 0, column < imageEditorToolGridColumnCount, row >= 0 else {
            return nil
        }
        let localPoint = NSPoint(
            x: point.x - CGFloat(column) * pitch,
            y: point.y - CGFloat(row) * pitch
        )
        guard localPoint.x >= 0,
              localPoint.y >= 0,
              localPoint.x < imageEditorToolButtonHitSize,
              localPoint.y < imageEditorToolButtonHitSize else {
            return nil
        }
        let index = row * imageEditorToolGridColumnCount + column
        guard index >= 0, index < toolCount else { return nil }
        return (index, localPoint)
    }

    private func updateHover(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        onHoverChanged?(toolHit(at: point)?.index)
    }
}

struct EditorIconButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        EditorButtonSurface(
            label: configuration.label,
            isPressed: configuration.isPressed,
            foreground: isSelected ? .white : Color(nsColor: ImageEditorTheme.text),
            normalBackground: isSelected ? Color(nsColor: ImageEditorTheme.selected) : .clear,
            hoverBackground: isSelected
                ? Color(nsColor: ImageEditorTheme.selected).opacity(0.84)
                : Color(nsColor: ImageEditorTheme.selected).opacity(0.20),
            pressedBackground: Color(nsColor: ImageEditorTheme.selected).opacity(isSelected ? 0.68 : 0.38),
            border: isSelected ? Color.white.opacity(0.16) : Color.clear
        )
    }
}

struct EditorTextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        EditorButtonSurface(
            label: configuration.label
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 10)
                .frame(height: 28),
            isPressed: configuration.isPressed,
            foreground: Color(nsColor: ImageEditorTheme.text),
            normalBackground: Color(nsColor: ImageEditorTheme.panelRaised),
            hoverBackground: Color(nsColor: ImageEditorTheme.selected).opacity(0.26),
            pressedBackground: Color(nsColor: ImageEditorTheme.selected).opacity(0.42),
            border: Color(nsColor: ImageEditorTheme.border).opacity(0.8)
        )
    }
}

struct EditorSegmentButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        EditorButtonSurface(
            label: configuration.label
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 8)
                .frame(height: 26),
            isPressed: configuration.isPressed,
            foreground: isSelected ? .white : Color(nsColor: ImageEditorTheme.text),
            normalBackground: isSelected
                ? Color(nsColor: ImageEditorTheme.selected)
                : Color(nsColor: ImageEditorTheme.chrome),
            hoverBackground: Color(nsColor: ImageEditorTheme.selected).opacity(isSelected ? 0.82 : 0.26),
            pressedBackground: Color(nsColor: ImageEditorTheme.selected).opacity(0.58),
            border: Color(nsColor: ImageEditorTheme.border).opacity(0.8)
        )
    }
}

struct EditorPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        EditorButtonSurface(
            label: configuration.label
                .font(.system(size: 12, weight: .bold))
                .padding(.horizontal, 12)
                .frame(height: 30),
            isPressed: configuration.isPressed,
            foreground: .white,
            normalBackground: Color(nsColor: ImageEditorTheme.selected),
            hoverBackground: Color(nsColor: ImageEditorTheme.selected).opacity(0.84),
            pressedBackground: Color(nsColor: ImageEditorTheme.selected).opacity(0.66),
            border: Color.white.opacity(0.18)
        )
    }
}

private struct EditorButtonSurface<Label: View>: View {
    let label: Label
    let isPressed: Bool
    let foreground: Color
    let normalBackground: Color
    let hoverBackground: Color
    let pressedBackground: Color
    let border: Color
    @State private var isHovered = false

    private var background: Color {
        if isPressed {
            return pressedBackground
        }
        return isHovered ? hoverBackground : normalBackground
    }

    var body: some View {
        label
            .foregroundStyle(foreground)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(border, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .onHover { isHovered = $0 }
            .focusable(false)
    }
}

private struct ImageEditorGuideDrag {
    var orientation: ImageEditorGuideOrientation
    var position: CGFloat
}
