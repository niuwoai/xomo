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

enum ImageEditorSpacingGuideLabelLayout {
    static func clampedCoordinate(
        _ coordinate: CGFloat,
        minimum: CGFloat,
        maximum: CGFloat,
        badgeLength: CGFloat
    ) -> CGFloat {
        guard maximum - minimum >= badgeLength else { return (minimum + maximum) / 2 }
        let halfLength = badgeLength / 2
        return min(max(coordinate, minimum + halfLength), maximum - halfLength)
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

struct ImageEditorEyedropperSamplingRingState {
    let originalColor: NSColor
    let sampledColor: NSColor
    let canvasPoint: CGPoint
    let target: ImageEditorColorSampleTarget

    static func begin(
        at canvasPoint: CGPoint,
        target: ImageEditorColorSampleTarget,
        foregroundColor: NSColor,
        backgroundColor: NSColor,
        sampledColor: NSColor
    ) -> Self {
        Self(
            originalColor: target == .foreground ? foregroundColor : backgroundColor,
            sampledColor: sampledColor,
            canvasPoint: canvasPoint,
            target: target
        )
    }

    func updating(sampledColor: NSColor, at canvasPoint: CGPoint) -> Self {
        Self(
            originalColor: originalColor,
            sampledColor: sampledColor,
            canvasPoint: canvasPoint,
            target: target
        )
    }
}

enum ImageEditorEyedropperSamplingRingGeometry {
    static let diameter: CGFloat = 48
    private static let cursorOffset: CGFloat = 42
    private static let edgePadding: CGFloat = 4

    static func center(pointer: CGPoint, viewportSize: CGSize) -> CGPoint {
        let radius = diameter / 2
        let horizontalInset = min(radius + edgePadding, max(viewportSize.width / 2, 0))
        let verticalInset = min(radius + edgePadding, max(viewportSize.height / 2, 0))
        let maximumX = max(horizontalInset, viewportSize.width - horizontalInset)
        let maximumY = max(verticalInset, viewportSize.height - verticalInset)
        var center = CGPoint(
            x: pointer.x + cursorOffset,
            y: pointer.y - cursorOffset
        )
        if center.x > maximumX {
            center.x = pointer.x - cursorOffset
        }
        if center.y < verticalInset {
            center.y = pointer.y + cursorOffset
        }
        center.x = min(max(center.x, horizontalInset), maximumX)
        center.y = min(max(center.y, verticalInset), maximumY)
        return center
    }
}

private struct ImageEditorObjectSelectionBoxDrag: Equatable {
    let startCanvasPoint: CGPoint
    var endCanvasPoint: CGPoint
    var viewTranslation: CGSize
    let mode: ImageEditorObjectBoxSelectionMode
    let scope: ImageEditorObjectBoxSelectionScope
    let inclusion: ImageEditorObjectBoxSelectionInclusion

    var selectionRect: CGRect? {
        ImageEditorObjectBoxSelectionPolicy.selectionRect(
            from: startCanvasPoint,
            to: endCanvasPoint
        )
    }

    var isActivated: Bool {
        ImageEditorObjectBoxSelectionPolicy.isActivated(
            viewTranslation: viewTranslation
        )
    }
}

struct ImageEditorView: View {
    @Environment(\.locale) private var locale
    @StateObject var viewModel: ImageEditorViewModel
    @StateObject var recentDocumentStore = XomoRecentDocumentStore.shared
    @ObservedObject private var externalOpenCoordinator = XomoExternalDocumentOpenCoordinator.shared
    @State private var dragPoints: [CGPoint] = []
    @State private var brushStrokeSamples: [ImageEditorBrushStrokeSample] = []
    @State private var isTemporaryEyedropperGestureActive = false
    @State private var eyedropperGestureTarget: ImageEditorColorSampleTarget?
    @State private var eyedropperSamplingRing: ImageEditorEyedropperSamplingRingState?
    @State private var isEraserHistoryGestureActive = false
    @State private var paintAirbrushStroke = ImageEditorToneAirbrushStroke()
    @State private var toneAirbrushStroke = ImageEditorToneAirbrushStroke()
    @State private var dragStart: CGPoint?
    @State private var dragEnd: CGPoint?
    @State private var primaryToolViewStart: CGPoint?
    @State private var patchPreviewImage: NSImage?
    @State private var patchRawDragEnd: CGPoint?
    @State private var patchDragConstraintAxis: ImageEditorObjectDragAxis?
    @State private var isDrawingPatchSelection = false
    @State private var isPatchGestureBlocked = false
    @State private var lastPatchPreviewUpdateTime: TimeInterval = 0
    @State private var pendingCropRect: CGRect?
    @State private var cropGuideKind = ImageEditorCropGuideKind.ruleOfThirds
    @State private var showsCroppedArea = true
    @State private var isCropAspectRatioLocked = false
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
    @State private var objectSelectionBoxDrag: ImageEditorObjectSelectionBoxDrag?
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
    @State private var activeShapeGradientMidpointIndex: Int?
    @State private var isGradientOverlayCenterDragActive = false
    @State private var gradientOverlayCenterDragStartLocation: CGPoint?
    @State private var cancelledGradientOverlayCenterDragStartLocation: CGPoint?
    @State private var isGradientOverlayAxisDragActive = false
    @State private var gradientOverlayAxisDragStartLocation: CGPoint?
    @State private var cancelledGradientOverlayAxisDragStartLocation: CGPoint?
    @State private var activeGradientOverlayStopIndex: Int?
    @State private var selectedGradientOverlayStopIndex: Int?
    @State private var gradientOverlayStopColorActivationRequestID = 0
    @State private var selectedGradientOverlayMidpointIndex: Int?
    @State private var gradientOverlayStopDragStartLocation: CGPoint?
    @State private var cancelledGradientOverlayStopDragStartLocation: CGPoint?
    @State private var gradientOverlayStopDragDuplicates = false
    @State private var isGradientOverlayStopDuplicateDragBlocked = false
    @State private var isGradientOverlayStopDragRemovalPreview = false
    @State private var activeGradientOverlayMidpointIndex: Int?
    @State private var gradientOverlayMidpointDragStartLocation: CGPoint?
    @State private var cancelledGradientOverlayMidpointDragStartLocation: CGPoint?
    @State var selectedShapeGradientStopIndex = 0
    @State var activeShapeGradientTrackStopIndex: Int?
    @State var activeShapeGradientTrackMidpointIndex: Int?
    @State private var isRotatingLayer = false
    @State private var isMovingTransformReferencePoint = false
    @State private var isTransformReferencePointDragCancelled = false
    @State private var isMovingPathAnchor = false
    @State private var isPathAnchorDragCancelled = false
    @State private var isDirectPathGestureResolved = false
    @State private var isPathSelectionGestureResolved = false
    @State private var isPenPointerSequenceActive = false
    @State private var pendingPenCreationAction: ImageEditorPendingPenGestureAction?
    @State private var isPenAnchorConversionGestureActive = false
    @State private var penAnchorConversionAction: ImageEditorPenAnchorConversionAction?
    @State private var penAnchorConversionTarget: ImageEditorPenAnchorConversionTarget?
    @State private var isPenAnchorConversionGestureBlocked = false
    @State private var penAnchorDeletionGestureState: ImageEditorPenAnchorDeletionState = .none
    @State private var penPathContinuationGestureState: ImageEditorPenPathContinuationState = .none
    @State private var activeGuideDrag: ImageEditorGuideDrag?
    @State private var layerNameDraft = ""
    @State private var figmaComponentPropertyDrafts: [String: String] = [:]
    @State private var figmaSizeConstraintDrafts: [XomoFigmaSizeConstraintField: String] = [:]
    @State var layerSearchQuery = ""
    @State var selectedLayerKindFilter: ImageEditorLayerKindFilter = .all
    @State var selectedLayerLabelFilter: ImageEditorLayerLabelColor?
    @State var selectedLayerStateFilter: ImageEditorLayerStateFilter = .all
    @State var selectedLayerAttributeFilter: ImageEditorLayerAttributeFilter = .all
    @State var alphaChannelNameDrafts: [UUID: String] = [:]
    @State var layerCompNameDrafts: [UUID: String] = [:]
    @State var layerCompCommentDrafts: [UUID: String] = [:]
    @State var layerCompSearchQuery = ""
    @State var layerCompSearchScope: ImageEditorLayerCompSearchScope = .all
    @State var showsFavoriteLayerCompsOnly = false
    @AppStorage(ImageEditorLayerCompCaptureDefaults.visibilityKey)
    var defaultLayerCompCapturesVisibility = true
    @AppStorage(ImageEditorLayerCompCaptureDefaults.positionKey)
    var defaultLayerCompCapturesPosition = true
    @AppStorage(ImageEditorLayerCompCaptureDefaults.appearanceKey)
    var defaultLayerCompCapturesAppearance = true
    @State var savedPathNameDrafts: [UUID: String] = [:]
    @State var historySnapshotNameDrafts: [UUID: String] = [:]
    @State var inlineLayerNameDraft = ""
    @State var renamingLayerID: UUID?
    @FocusState var focusedInlineLayerNameID: UUID?
    @State var selectedLayerPanelTab: ImageEditorLayerPanelTab = .layers
    @State var targetedLayerDropTarget: ImageEditorLayerDropTarget?
    @State var targetedLayerCompDropTarget: ImageEditorLayerCompDropTarget?
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
    @State var pendingFigmaLinkImportInput: String?
    @State var pendingFigmaLinkImportPlacementCenter: CGPoint?
    @State var isBrushPresetRenamePresented = false
    @State var brushPresetNameDraft = ""
    @State private var canvasTextEditingOrigin: CGPoint?
    @State private var canvasTextEditingLayerID: UUID?
    @State private var canvasTextEditingFrame: CGRect?
    @FocusState private var isCanvasTextEditorFocused: Bool
    @FocusState private var focusedFigmaSizeConstraintField: XomoFigmaSizeConstraintField?
    @State private var isTransformAspectRatioLocked = false

    init(sourceName: String, image: NSImage, onApply: @escaping (NSImage) -> Void) {
        _viewModel = StateObject(wrappedValue: ImageEditorViewModel(sourceName: sourceName, image: image, onApply: onApply))
    }

    init(viewModel: ImageEditorViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            quickActionBar
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
        .onDeleteCommand {
            _ = deleteSelectedObjectFromKeyboard()
        }
        .background(
            ImageEditorKeyboardShortcutMonitor(
                perform: performKeyboardShortcut,
                activeTool: viewModel.canvasInteractionTool,
                hasPendingCrop: pendingCropRect != nil,
                canCycleCropGuide: pendingCropRect != nil,
                canToggleQuickMaskGrayscalePreview: viewModel.isQuickMaskMode,
                canToggleLayerMaskRubylith: viewModel.canToggleSelectedLayerMaskRubylithPreview,
                nudgePendingCrop: { delta in
                    guard let pendingCropRect else { return false }
                    self.pendingCropRect = ImageEditorCropGeometry.adjustedFrame(
                        from: pendingCropRect,
                        handle: .move,
                        delta: delta,
                        canvasSize: viewModel.document.canvasSize
                    )
                    return true
                },
                nudgeSelected: performNudgeCommand,
                selectNextCanvasHandle: { movesBackward in
                    if cancelGradientOverlayCanvasHandleDragForLifecycle() {
                        return true
                    }
                    return selectNextGradientOverlayCanvasHandle(
                        movesBackward: movesBackward
                    )
                },
                moveSelectedCanvasHandleToBoundary: { displayedDelta in
                    if cancelGradientOverlayCanvasHandleDragForLifecycle() {
                        return true
                    }
                    return nudgeSelectedGradientOverlayHandleIfNeeded(
                        by: CGSize(width: displayedDelta * 100, height: 0)
                    )
                },
                deleteSelectedObject: { event in
                    deleteSelectedObjectFromKeyboard(event: event)
                },
                confirmPendingCrop: {
                    guard let pendingCropRect else { return false }
                    viewModel.crop(to: pendingCropRect)
                    self.pendingCropRect = nil
                    endPendingCropInteraction()
                    return true
                },
                cancelPendingCrop: {
                    guard pendingCropRect != nil else { return false }
                    self.pendingCropRect = nil
                    endPendingCropInteraction()
                    return true
                },
                finishPendingPenPath: {
                    let isUncommittedPenPointerSequence = ImageEditorPendingPenPointerPolicy
                        .ownsUncommittedPoint(
                            tool: canvasInteractionTool,
                            isPointerSequenceActive: isPenPointerSequenceActive,
                            isMovingPathAnchor: isMovingPathAnchor
                        )
                    if isUncommittedPenPointerSequence {
                        isPathAnchorDragCancelled = true
                    }
                    return viewModel.finishPendingPenPathFromKeyboard()
                        || isUncommittedPenPointerSequence
                },
                enterSelectedGroup: {
                    guard ImageEditorMoveToolGroupEntryKeyPolicy.shouldEnter(
                        sidebarTab: viewModel.selectedLeftSidebarTab,
                        selectedTool: viewModel.selectedTool,
                        hasActiveInteraction: hasActiveMoveToolVisualInteraction
                    ) else { return false }
                    return viewModel.enterSelectedCanvasGroupIfNeeded()
                },
                cancelSelectedObject: {
                    if objectSelectionBoxDrag != nil {
                        objectSelectionBoxDrag = nil
                        NSCursor.arrow.set()
                        return true
                    }
                    if cancelGradientOverlayCanvasHandleDragForLifecycle() {
                        NSCursor.arrow.set()
                        return true
                    }
                    if cancelPatchGestureForCanvasLifecycle() {
                        return true
                    }
                    if isMovingPathAnchor {
                        isPathAnchorDragCancelled = true
                        if viewModel.cancelMovingPathAnchor() {
                            NSCursor.arrow.set()
                            return true
                        }
                    }
                    let isUncommittedPenPointerSequence = ImageEditorPendingPenPointerPolicy
                        .ownsUncommittedPoint(
                            tool: canvasInteractionTool,
                            isPointerSequenceActive: isPenPointerSequenceActive,
                            isMovingPathAnchor: isMovingPathAnchor
                        )
                    if viewModel.cancelPenPath() || isUncommittedPenPointerSequence {
                        isPathAnchorDragCancelled = true
                        pendingPenCreationAction = nil
                        resetPenAnchorConversionGesture()
                        NSCursor.arrow.set()
                        return true
                    }
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
                    if viewModel.clearSelectedXomoObjectIfNeeded() {
                        return true
                    }
                    return viewModel.exitDeepCanvasSelectionIfNeeded()
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
                    // Keep semantic cursor and idle-hover feedback in sync
                    // with modifier changes; gesture commits still snapshot
                    // the authoritative event flags when their sequence starts.
                    canvasModifierFlags = flags.intersection([
                        .shift,
                        .option,
                        .command,
                        .capsLock
                    ])
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
            syncFigmaSizeConstraintDrafts()
            viewModel.syncSizeControlsFromDocument()
            presentExternalFigmaLinkImportIfNeeded()
            restoreKeyboardFocusAfterExternalOpenIfNeeded()
            guard !isRightDockMounted else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                isRightDockMounted = true
            }
        }
        .onChange(of: externalOpenCoordinator.editorKeyboardFocusRequestID) { _ in
            restoreKeyboardFocusAfterExternalOpenIfNeeded()
        }
        .onChange(of: externalOpenCoordinator.figmaLinkImportRequest?.id) { _ in
            presentExternalFigmaLinkImportIfNeeded()
        }
        .onChange(of: viewModel.document.selectedLayerIDs) { selectedLayerIDs in
            syncLayerNameDraft()
            syncFigmaComponentPropertyDrafts()
            syncFigmaSizeConstraintDrafts()
            viewModel.finishSelectedLayerTransformReferencePointDrag()
            viewModel.clearSelectedLayerTransformReferencePoint()
            isMovingTransformReferencePoint = false
            isTransformReferencePointDragCancelled = false
            selectedGradientOverlayStopIndex = nil
            selectedGradientOverlayMidpointIndex = nil
            reclaimEditorKeyboardFocusAfterLayerSelection(
                hasSelectedLayers: !selectedLayerIDs.isEmpty
            )
        }
        .onChange(of: viewModel.selectedLayerFigmaComponentProperties) { _ in
            syncFigmaComponentPropertyDrafts()
        }
        .onChange(of: viewModel.hasActivePathAnchorMoveTransaction) { isActive in
            if !isActive, isMovingPathAnchor {
                isPathAnchorDragCancelled = true
            }
        }
        .onChange(of: viewModel.selectedLayerFigmaSizeConstraints) { _ in
            syncFigmaSizeConstraintDrafts()
        }
        .onChange(of: viewModel.selectedLayerName) { _ in
            syncLayerNameDraft()
        }
        .onChange(of: viewModel.filterPanelPresentationRequest) { _ in
            isFiltersDockExpanded = true
        }
        .onChange(of: viewModel.selectedTool) { _ in
            _ = cancelPenAnchorConversionGesture()
            penAnchorDeletionGestureState = .none
            if viewModel.selectedTool != .marquee {
                isMarqueeShapeMenuPresented = false
            }
            patchPreviewImage = nil
            patchRawDragEnd = nil
            patchDragConstraintAxis = nil
            isDrawingPatchSelection = false
            isPatchGestureBlocked = false
            lastPatchPreviewUpdateTime = 0
            dragStart = nil
            dragEnd = nil
            primaryToolViewStart = nil
            dragPoints = []
            brushStrokeSamples = []
            isTemporaryEyedropperGestureActive = false
            eyedropperGestureTarget = nil
            eyedropperSamplingRing = nil
            isEraserHistoryGestureActive = false
            activeBrushPressure = nil
            activeBrushTilt = nil
            paintAirbrushStroke.reset()
            toneAirbrushStroke.reset()
            if viewModel.selectedTool != .crop {
                pendingCropRect = nil
                endPendingCropInteraction()
            }
        }
        .alert(
            L10n.text("imageEditor.brushPreset.renameTitle"),
            isPresented: $isBrushPresetRenamePresented
        ) {
            TextField(
                L10n.text("imageEditor.brushPreset.namePlaceholder"),
                text: $brushPresetNameDraft
            )
            Button(L10n.text("imageEditor.action.cancel"), role: .cancel) {}
            Button(L10n.text("imageEditor.action.brushPresetRename")) {
                viewModel.renameSelectedCustomBrushPreset(to: brushPresetNameDraft)
            }
            .disabled(
                ImageEditorBrushPreset.normalizedCustomName(brushPresetNameDraft) == nil
            )
        } message: {
            Text(L10n.text("imageEditor.brushPreset.renameMessage"))
        }
        .sheet(isPresented: $viewModel.isExportSheetPresented) {
            ImageEditorExportPanel(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.isPreviewSheetPresented) {
            ImageEditorPreviewPanel(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.isColorRangeSheetPresented) {
            ImageEditorColorRangePanel(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.isSelectionFillSheetPresented) {
            ImageEditorSelectionFillPanel(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.isNewCanvasSheetPresented) {
            XomoNewCanvasSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.isBrushPresetManagerPresented) {
            ImageEditorBrushPresetManager(viewModel: viewModel)
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
        .sheet(isPresented: $isFigmaLinkImportPresented, onDismiss: {
            pendingFigmaLinkImportInput = nil
            pendingFigmaLinkImportPlacementCenter = nil
            presentExternalFigmaLinkImportIfNeeded()
        }) {
            XomoFigmaLinkImportSheet(
                viewModel: viewModel,
                initialLink: pendingFigmaLinkImportInput,
                placementCenter: pendingFigmaLinkImportPlacementCenter
            )
        }
        .focusedSceneValue(\.xomoFileCommandActions, xomoFileCommandActions)
        .focusedSceneValue(\.xomoEditCommandActions, xomoEditCommandActions)
        .focusedSceneValue(\.xomoImageCommandActions, xomoImageCommandActions)
        .focusedSceneValue(\.xomoLayerCommandContent, xomoLayerCommandContent)
        .focusedSceneValue(\.xomoSelectCommandContent, xomoSelectCommandContent)
        .focusedSceneValue(\.xomoFilterCommandContent, xomoFilterCommandContent)
        .focusedSceneValue(\.xomoViewCommandContent, xomoViewCommandContent)
        .focusedSceneValue(\.xomoWindowCommandContent, xomoWindowCommandContent)
    }

    /// Panel clicks can select an already-selected layer, so the selection set
    /// does not always change and the `onChange` recovery above will not run.
    /// Reusing this entry point lets those clicks release stale search-field
    /// focus without stealing focus from an intentional text editor.
    func reclaimEditorKeyboardFocusAfterLayerSelection(
        hasSelectedLayers: Bool? = nil
    ) {
        ImageEditorLayerSelectionKeyboardFocusRestorer.reclaimIfNeeded(
            in: NSApp.keyWindow ?? NSApp.mainWindow,
            hasSelectedLayers: hasSelectedLayers ?? !viewModel.document.selectedLayerIDs.isEmpty,
            isCanvasTextEditing: isCanvasTextEditorFocused,
            isInlineLayerNameEditing: focusedInlineLayerNameID != nil,
            isFigmaSizeConstraintEditing: focusedFigmaSizeConstraintField != nil
        )
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

            if viewModel.selectedTool == .move {
                Toggle(
                    L10n.text("imageEditor.option.moveAutoSelect"),
                    isOn: $viewModel.isMoveToolAutoSelectEnabled
                )
                .toggleStyle(.checkbox)
                .focusable(false)
                .fixedSize()
                .help(L10n.text("imageEditor.option.moveAutoSelectHelp"))
                .accessibilityIdentifier("image-editor-move-auto-select")

                Picker(
                    L10n.text("imageEditor.option.moveAutoSelectTarget"),
                    selection: $viewModel.moveToolAutoSelectTarget
                ) {
                    ForEach(ImageEditorMoveAutoSelectTarget.allCases) { target in
                        Text(target.title).tag(target)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
                .focusable(false)
                .disabled(!viewModel.isMoveToolAutoSelectEnabled)
                .help(L10n.text("imageEditor.option.moveAutoSelectTargetHelp"))
                .accessibilityIdentifier("image-editor-move-auto-select-target")

                Picker(
                    L10n.text("imageEditor.option.moveBoxSelectionInclusion"),
                    selection: $viewModel.moveToolBoxSelectionInclusion
                ) {
                    ForEach(ImageEditorObjectBoxSelectionInclusion.allCases) { inclusion in
                        Text(inclusion.title).tag(inclusion)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
                .focusable(false)
                .disabled(!viewModel.isMoveToolAutoSelectEnabled)
                .help(L10n.text("imageEditor.option.moveBoxSelectionInclusionHelp"))
                .accessibilityIdentifier("image-editor-move-box-selection-inclusion")

                Toggle(
                    L10n.text("imageEditor.action.transformControlsVisible"),
                    isOn: Binding(
                        get: { viewModel.document.areTransformControlsVisible },
                        set: { _ in viewModel.toggleTransformControlsVisible() }
                    )
                )
                .toggleStyle(.checkbox)
                .focusable(false)
                .fixedSize()
                .help(L10n.text("imageEditor.action.transformControlsVisible"))
                .accessibilityIdentifier("image-editor-move-transform-controls")

                Divider()
                    .frame(height: 20)
                    .overlay(editorBorder)

                Picker(
                    L10n.text("imageEditor.option.moveAlignmentTarget"),
                    selection: $viewModel.moveToolAlignmentTarget
                ) {
                    ForEach(ImageEditorMoveAlignmentTarget.allCases) { target in
                        Text(target.title).tag(target)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
                .focusable(false)
                .help(L10n.text("imageEditor.option.moveAlignmentTargetHelp"))
                .accessibilityIdentifier("image-editor-move-alignment-target")

                HStack(spacing: 2) {
                    ForEach(ImageEditorLayerAlignment.allCases) { alignment in
                        Button {
                            viewModel.applyMoveToolAlignment(alignment)
                        } label: {
                            Image(systemName: alignment.optionBarSystemImage)
                                .font(.system(size: 11, weight: .semibold))
                                .frame(width: 22, height: 22)
                        }
                        .buttonStyle(EditorIconButtonStyle(isSelected: false))
                        .disabled(!viewModel.canApplyMoveToolAlignment)
                        .help(L10n.text(alignment.actionTitleKey(
                            for: viewModel.moveToolAlignmentTarget
                        )))
                        .accessibilityLabel(Text(L10n.text(alignment.actionTitleKey(
                            for: viewModel.moveToolAlignmentTarget
                        ))))
                        .accessibilityIdentifier(alignment.accessibilityIdentifier)
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("image-editor-move-alignment-controls")

                Menu {
                    ForEach(ImageEditorLayerDistribution.allCases) { distribution in
                        Button {
                            viewModel.distributeSelectedLayers(distribution)
                        } label: {
                            Label(
                                L10n.text(distribution.actionTitleKey),
                                systemImage: distribution.optionBarSystemImage
                            )
                        }
                        .accessibilityIdentifier(distribution.accessibilityIdentifier)
                    }
                    Divider()
                    ForEach(ImageEditorLayerSpacingDistribution.allCases) { distribution in
                        Button {
                            viewModel.distributeSelectedLayerSpacing(distribution)
                        } label: {
                            Label(
                                L10n.text(distribution.actionTitleKey),
                                systemImage: distribution.optionBarSystemImage
                            )
                        }
                        .accessibilityIdentifier(distribution.accessibilityIdentifier)
                    }
                } label: {
                    Label(
                        L10n.text("imageEditor.option.moveDistribute"),
                        systemImage: "rectangle.split.3x1"
                    )
                    .font(.system(size: 11, weight: .semibold))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .focusable(false)
                .disabled(!viewModel.canDistributeSelectedLayers)
                .help(L10n.text("imageEditor.option.moveDistributeHelp"))
                .accessibilityIdentifier("image-editor-move-distribute-menu")
            }

            if viewModel.selectedTool.supportsSelectionMode {
                selectionModePicker
            }

            if viewModel.selectedTool == .marquee {
                marqueeShapePicker
            }

            if viewModel.selectedTool == .move,
               let stopIndex = selectedGradientOverlayStopIndex,
               viewModel.document.areExtrasVisible,
               viewModel.canEditSelectedLayerGradientOverlayCanvasCenter,
               let stopHandle = viewModel.selectedLayerGradientOverlayCanvasStopHandlePoints.first(
                   where: { $0.index == stopIndex }
               ) {
                Divider()
                    .frame(height: 20)
                    .overlay(editorBorder)
                Text(L10n.format(
                    "imageEditor.properties.shapeGradientStopColor",
                    stopIndex + 1
                ))
                .font(.system(size: 11, weight: .medium))
                gradientOverlayCanvasStopColorWell(at: stopIndex)
                ImageEditorPercentageField(
                    label: L10n.text("imageEditor.option.gradientOverlayStopOpacity"),
                    normalizedValue: stopHandle.stop.alpha,
                    accessibilityIdentifier:
                        "image-editor-gradient-overlay-canvas-stop-opacity-\(stopIndex)"
                ) { opacity in
                    _ = viewModel.setSelectedLayerGradientOverlayCanvasStopOpacity(
                        at: stopIndex,
                        to: opacity
                    )
                }
                .id("gradient-overlay-stop-opacity-\(stopIndex)")
                if !stopHandle.isEndpoint {
                    ImageEditorPercentageField(
                        label: L10n.text("imageEditor.option.gradientOverlayStopPosition"),
                        normalizedValue: viewModel.selectedLayerGradientOverlayCanvasIsReversed
                            ? 1 - stopHandle.stop.position
                            : stopHandle.stop.position,
                        accessibilityIdentifier:
                            "image-editor-gradient-overlay-canvas-stop-position-\(stopIndex)"
                    ) { displayedPosition in
                        if let movedIndex = viewModel
                            .setSelectedLayerGradientOverlayCanvasStopDisplayedPosition(
                                at: stopIndex,
                                to: displayedPosition
                            ) {
                            selectedGradientOverlayStopIndex = movedIndex
                            selectedGradientOverlayMidpointIndex = nil
                        }
                    }
                    .id("gradient-overlay-stop-position-\(stopIndex)")
                }
            }

            if viewModel.selectedTool == .move,
               let midpointIndex = selectedGradientOverlayMidpointIndex,
               viewModel.document.areExtrasVisible,
               viewModel.canEditSelectedLayerGradientOverlayCanvasCenter,
               let midpointHandle = viewModel
                   .selectedLayerGradientOverlayCanvasMidpointHandlePoints.first(
                       where: { $0.lowerStopIndex == midpointIndex }
                   ) {
                Divider()
                    .frame(height: 20)
                    .overlay(editorBorder)
                ImageEditorPercentageField(
                    label: L10n.text("imageEditor.option.gradientOverlayMidpoint"),
                    normalizedValue: midpointHandle.midpoint,
                    accessibilityIdentifier:
                        "image-editor-gradient-overlay-canvas-midpoint-position-\(midpointIndex)"
                ) { midpoint in
                    _ = viewModel.setSelectedLayerGradientOverlayCanvasMidpoint(
                        after: midpointIndex,
                        to: midpoint
                    )
                }
                .id("gradient-overlay-midpoint-position-\(midpointIndex)")
            }

            if viewModel.selectedTool == .patchTool {
                patchModePicker
                Toggle(
                    L10n.text("imageEditor.option.patchTransparent"),
                    isOn: $viewModel.patchTransparentEnabled
                )
                .toggleStyle(.checkbox)
                .focusable(false)
                .fixedSize()
                .help(L10n.text("imageEditor.option.patchTransparent.help"))
                .accessibilityIdentifier("image-editor-patch-transparent")
                Picker(
                    L10n.text("imageEditor.option.patchSampleSource"),
                    selection: $viewModel.patchSampleSource
                ) {
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
                .help(L10n.text("imageEditor.option.patchSampleSource.help"))
                .accessibilityLabel(L10n.text("imageEditor.option.patchSampleSource"))
                .accessibilityHint(L10n.text("imageEditor.option.patchSampleSource.help"))
                .accessibilityIdentifier("image-editor-patch-sample-source")
                Toggle(
                    L10n.text("imageEditor.option.colorSamplerIgnoreAdjustments"),
                    isOn: $viewModel.patchIgnoresAdjustmentLayers
                )
                .toggleStyle(.checkbox)
                .focusable(false)
                .fixedSize()
                .disabled(viewModel.patchSampleSource == .currentLayer)
                .help(L10n.text("imageEditor.option.patchIgnoreAdjustments.help"))
                .accessibilityHint(L10n.text("imageEditor.option.patchIgnoreAdjustments.help"))
                .accessibilityIdentifier("image-editor-patch-ignore-adjustments")
                Stepper(value: $viewModel.patchDiffusion, in: 1...7) {
                    Text(L10n.format(
                        "imageEditor.option.patchDiffusionValue",
                        viewModel.patchDiffusion
                    ))
                    .foregroundStyle(Color(nsColor: ImageEditorOptionsBarAppearance.foregroundColor))
                }
                .focusable(false)
                .fixedSize()
                .help(L10n.text("imageEditor.option.patchDiffusion.help"))
                .accessibilityIdentifier("image-editor-patch-diffusion")
                Menu {
                    Section {
                        Picker(
                            L10n.text("imageEditor.option.patchPattern"),
                            selection: $viewModel.patchPatternContent.kind
                        ) {
                            ForEach(ImageEditorPatternOverlayKind.allCases) { kind in
                                Text(kind.title).tag(kind)
                            }
                        }
                        HStack {
                            Text(L10n.text("imageEditor.option.patchPatternColor"))
                            Spacer()
                            ColorPicker(
                                "",
                                selection: patchPatternColorBinding,
                                supportsOpacity: false
                            )
                            .labelsHidden()
                            .focusable(false)
                            .accessibilityIdentifier("image-editor-patch-pattern-color")
                        }
                        Stepper(
                            value: $viewModel.patchPatternContent.opacity,
                            in: 0.05...1,
                            step: 0.05
                        ) {
                            Text(L10n.format(
                                "imageEditor.option.patchPatternOpacityValue",
                                Int((viewModel.patchPatternContent.opacity * 100).rounded())
                            ))
                        }
                        .accessibilityIdentifier("image-editor-patch-pattern-opacity")
                        Picker(
                            L10n.text("imageEditor.option.patchPatternBlendMode"),
                            selection: $viewModel.patchPatternBlendMode
                        ) {
                            ForEach(ImageEditorBlendMode.smartFilterCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .accessibilityIdentifier("image-editor-patch-pattern-blend-mode")
                        Picker(
                            L10n.text("imageEditor.option.patchPatternRepeatMode"),
                            selection: $viewModel.patchPatternContent.repeatMode
                        ) {
                            ForEach(ImageEditorPatternRepeatMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .accessibilityIdentifier("image-editor-patch-pattern-repeat-mode")
                    } header: {
                        Text(L10n.text("imageEditor.section.patchPatternAppearance"))
                    }
                    Section {
                        Stepper(
                            value: $viewModel.patchPatternContent.scale,
                            in: 6...64,
                            step: 1
                        ) {
                            Text(L10n.format(
                                "imageEditor.option.patchPatternScaleValue",
                                Int(viewModel.patchPatternContent.scale.rounded())
                            ))
                        }
                        .accessibilityIdentifier("image-editor-patch-pattern-scale")
                        Toggle(
                            L10n.text("imageEditor.option.patchPatternLinkAxisScales"),
                            isOn: patchPatternScaleAxesLinkedBinding
                        )
                        .toggleStyle(.checkbox)
                        .accessibilityIdentifier("image-editor-patch-pattern-link-axis-scales")
                        Stepper(
                            value: patchPatternScaleXBinding,
                            in: 0.25...4,
                            step: 0.05
                        ) {
                            Text(L10n.format(
                                "imageEditor.option.patchPatternScaleXValue",
                                Int((viewModel.patchPatternContent.scaleX * 100).rounded())
                            ))
                        }
                        .accessibilityIdentifier("image-editor-patch-pattern-scale-x")
                        Stepper(
                            value: patchPatternScaleYBinding,
                            in: 0.25...4,
                            step: 0.05
                        ) {
                            Text(L10n.format(
                                "imageEditor.option.patchPatternScaleYValue",
                                Int((viewModel.patchPatternContent.scaleY * 100).rounded())
                            ))
                        }
                        .accessibilityIdentifier("image-editor-patch-pattern-scale-y")
                        Stepper(
                            value: $viewModel.patchPatternContent.angle,
                            in: -180...180,
                            step: 1
                        ) {
                            Text(L10n.format(
                                "imageEditor.patternFill.angleValue",
                                Int(viewModel.patchPatternContent.angle.rounded())
                            ))
                        }
                        .accessibilityIdentifier("image-editor-patch-pattern-angle")
                        Toggle(
                            L10n.text("imageEditor.option.patchPatternFlipHorizontal"),
                            isOn: $viewModel.patchPatternContent.flipsHorizontally
                        )
                        .toggleStyle(.checkbox)
                        .accessibilityIdentifier("image-editor-patch-pattern-flip-horizontal")
                        Toggle(
                            L10n.text("imageEditor.option.patchPatternFlipVertical"),
                            isOn: $viewModel.patchPatternContent.flipsVertically
                        )
                        .toggleStyle(.checkbox)
                        .accessibilityIdentifier("image-editor-patch-pattern-flip-vertical")
                        Stepper(
                            value: $viewModel.patchPatternContent.offsetX,
                            in: -128...128,
                            step: 1
                        ) {
                            Text(L10n.format(
                                "imageEditor.patternFill.offsetXValue",
                                Int(viewModel.patchPatternContent.offsetX.rounded())
                            ))
                        }
                        .accessibilityIdentifier("image-editor-patch-pattern-offset-x")
                        Stepper(
                            value: $viewModel.patchPatternContent.offsetY,
                            in: -128...128,
                            step: 1
                        ) {
                            Text(L10n.format(
                                "imageEditor.patternFill.offsetYValue",
                                Int(viewModel.patchPatternContent.offsetY.rounded())
                            ))
                        }
                        .accessibilityIdentifier("image-editor-patch-pattern-offset-y")
                        Button(L10n.text("imageEditor.action.patchPatternResetOffset")) {
                            viewModel.resetPatchPatternOffset()
                        }
                        .disabled(
                            viewModel.patchPatternContent.offsetX == 0
                                && viewModel.patchPatternContent.offsetY == 0
                        )
                        .accessibilityIdentifier("image-editor-patch-pattern-reset-offset")
                        Button(L10n.text("imageEditor.action.patchPatternResetTransform")) {
                            viewModel.resetPatchPatternTransform()
                        }
                        .disabled(viewModel.patchPatternTransformIsIdentity)
                        .accessibilityIdentifier("image-editor-patch-pattern-reset-transform")
                    } header: {
                        Text(L10n.text("imageEditor.section.patchPatternTransform"))
                    }
                    Section {
                        Toggle(
                            L10n.text("imageEditor.selectionFill.alignPatternWithCanvas"),
                            isOn: $viewModel.patchPatternAlignsWithCanvas
                        )
                        .toggleStyle(.checkbox)
                        .accessibilityIdentifier("image-editor-patch-pattern-align-canvas")
                        Toggle(
                            L10n.text("imageEditor.selectionFill.preserveTransparency"),
                            isOn: $viewModel.patchPatternPreservesTransparency
                        )
                        .toggleStyle(.checkbox)
                        .accessibilityIdentifier("image-editor-patch-pattern-preserve-transparency")
                        Toggle(
                            L10n.text("imageEditor.option.patchPatternInvertCoverage"),
                            isOn: $viewModel.patchPatternInvertsCoverage
                        )
                        .toggleStyle(.checkbox)
                        .accessibilityIdentifier("image-editor-patch-pattern-invert-coverage")
                        Button(L10n.text("imageEditor.action.patchUsePattern")) {
                            viewModel.applyPatchPattern()
                        }
                        .disabled(!viewModel.canEditSelectionPixels)
                        .accessibilityIdentifier("image-editor-patch-use-pattern")
                    } header: {
                        Text(L10n.text("imageEditor.section.patchPatternApplication"))
                    }
                } label: {
                    Label(
                        viewModel.patchPatternSummary,
                        systemImage: "square.grid.2x2"
                    )
                    .font(.system(size: 11, weight: .semibold))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .focusable(false)
                .help(L10n.text("imageEditor.option.patchPattern.help"))
                .accessibilityIdentifier("image-editor-patch-pattern-menu")
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
                    in: Double(ImageEditorTextContent.minimumFontSize)...Double(ImageEditorTextContent.maximumFontSize),
                    step: 1
                )
                .fixedSize()
                .focusable(false)
            } else {
                if usesBrushOptions {
                    optionSlider(titleKey: "imageEditor.option.size", value: $viewModel.brushSize, range: 1...96, step: 1, suffix: "px")
                    if usesBrushHardnessOption {
                        optionSlider(titleKey: "imageEditor.option.hardness", value: $viewModel.hardness, range: 0...1, step: 0.05, suffix: "")
                    }
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
                if viewModel.selectedTool == .gradient {
                    Toggle(
                        L10n.text("imageEditor.gradientFill.reverse"),
                        isOn: $viewModel.isGradientReversed
                    )
                    .toggleStyle(.checkbox)
                    .focusable(false)
                    .fixedSize()
                    .accessibilityIdentifier("image-editor-gradient-reverse")
                }
                if viewModel.selectedTool == .brush || viewModel.selectedTool == .pencil {
                    Picker(
                        L10n.text("imageEditor.option.paintBlendMode"),
                        selection: Binding(
                            get: { viewModel.paintBlendMode },
                            set: { viewModel.setPaintBlendMode($0) }
                        )
                    ) {
                        ForEach(ImageEditorBlendMode.paintCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .focusable(false)
                    .frame(width: 132)
                    .help(L10n.text("imageEditor.option.paintBlendMode.help"))
                    .accessibilityIdentifier("image-editor-paint-blend-mode")
                }
                if viewModel.selectedTool == .brush {
                    Toggle(
                        isOn: Binding(
                            get: { viewModel.paintAirbrushEnabled },
                            set: { viewModel.setPaintAirbrushEnabled($0) }
                        )
                    ) {
                        Image(systemName: "wind")
                    }
                    .toggleStyle(.button)
                    .focusable(false)
                    .help(L10n.text("imageEditor.option.paintAirbrush.help"))
                    .accessibilityLabel(L10n.text("imageEditor.option.paintAirbrush"))
                    .accessibilityIdentifier("image-editor-paint-airbrush")
                }
                if viewModel.selectedTool == .pencil {
                    Toggle(
                        L10n.text("imageEditor.option.pencilAutoErase"),
                        isOn: Binding(
                            get: { viewModel.pencilAutoEraseEnabled },
                            set: { viewModel.setPencilAutoEraseEnabled($0) }
                        )
                    )
                    .toggleStyle(.checkbox)
                    .focusable(false)
                    .fixedSize()
                    .help(L10n.text("imageEditor.option.pencilAutoErase.help"))
                    .accessibilityHint(L10n.text("imageEditor.option.pencilAutoErase.help"))
                    .accessibilityIdentifier("image-editor-pencil-auto-erase")
                }
                if usesBrushDynamicsOptions {
                    brushPresetMenu
                    brushRoundnessMenu
                    brushSizeJitterMenu
                    brushScatteringMenu
                    brushTransferMenu
                    if viewModel.selectedTool != .pencil {
                        brushTipFinishMenu
                    }
                    optionSlider(titleKey: "imageEditor.option.flow", value: $viewModel.brushFlow, range: 1...100, step: 1, suffix: "%")
                    optionSlider(titleKey: "imageEditor.option.spacing", value: $viewModel.brushSpacing, range: 1...200, step: 1, suffix: "%")
                    brushSmoothingMenu
                    brushPressureMenu
                }
                if viewModel.selectedTool == .historyBrush {
                    Picker(
                        L10n.text("imageEditor.option.historyBrushBlendMode"),
                        selection: Binding(
                            get: { viewModel.historyBrushBlendMode },
                            set: { viewModel.setHistoryBrushBlendMode($0) }
                        )
                    ) {
                        ForEach(ImageEditorBlendMode.smartFilterCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .focusable(false)
                    .frame(width: 132)
                    .help(L10n.text("imageEditor.option.historyBrushBlendMode"))
                    .accessibilityIdentifier("image-editor-history-brush-blend-mode")

                    HStack(spacing: 4) {
                        Text(L10n.text("imageEditor.selectionFill.historySource"))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        Text(viewModel.historyFillSourceTitle)
                            .lineLimit(1)
                    }
                    .font(.system(size: 10, weight: .medium))
                    .help(L10n.text("imageEditor.tool.historyBrush.sourceHelp"))
                    .accessibilityIdentifier("image-editor-history-brush-source")
                }
                if viewModel.selectedTool == .eraser {
                    Toggle(
                        L10n.text("imageEditor.option.eraseToHistory"),
                        isOn: $viewModel.eraserErasesToHistory
                    )
                    .toggleStyle(.checkbox)
                    .focusable(false)
                    .fixedSize()
                    .disabled(!viewModel.canEraseToHistory)
                    .help(L10n.text("imageEditor.option.eraseToHistory.help"))
                    .accessibilityIdentifier("image-editor-erase-to-history")
                }
                if viewModel.selectedTool.supportsSelectionMode {
                    optionSlider(titleKey: "imageEditor.option.feather", value: $viewModel.feather, range: 0...40, step: 1, suffix: "px")
                }
            }
            if viewModel.selectedTool.supportsTolerance {
                optionSlider(titleKey: "imageEditor.option.tolerance", value: $viewModel.tolerance, range: 0...1, step: 0.02, suffix: "")
            }
            if viewModel.selectedTool == .paintBucket {
                Toggle(
                    L10n.text("imageEditor.option.contiguous"),
                    isOn: $viewModel.isPaintBucketContiguous
                )
                .toggleStyle(.checkbox)
                .focusable(false)
                .fixedSize()
                .accessibilityIdentifier("image-editor-paint-bucket-contiguous")
            }
            if viewModel.selectedTool == .magicWand {
                Toggle(
                    L10n.text("imageEditor.option.contiguous"),
                    isOn: $viewModel.isMagicWandContiguous
                )
                .toggleStyle(.checkbox)
                .focusable(false)
                .fixedSize()
                .accessibilityIdentifier("image-editor-magic-wand-contiguous")
            }

            if viewModel.selectedTool == .cloneStamp {
                Picker(
                    L10n.text("imageEditor.option.cloneSourceSlot"),
                    selection: Binding(
                        get: { viewModel.activeCloneSourceSlotIndex },
                        set: { viewModel.selectCloneSourceSlot($0) }
                    )
                ) {
                    ForEach(0..<ImageEditorCloneSourceSlotState.maximumCount, id: \.self) { index in
                        let isPopulated = viewModel.cloneSourceSlotIsPopulated(index)
                        HStack(spacing: 3) {
                            Text("\(index + 1)")
                            Image(systemName: isPopulated ? "circle.fill" : "circle")
                                .font(.system(size: 5, weight: .bold))
                                .accessibilityHidden(true)
                        }
                        .accessibilityLabel(L10n.format(
                            isPopulated
                                ? "imageEditor.accessibility.cloneSourceSlotPopulated"
                                : "imageEditor.accessibility.cloneSourceSlotEmpty",
                            index + 1
                        ))
                        .tag(index)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 130)
                .focusable(false)
                .xomoFocusEffectDisabled()
                .accessibilityLabel(L10n.text("imageEditor.option.cloneSourceSlot"))
                .accessibilityIdentifier("image-editor-clone-source-slot")

                optionSlider(
                    titleKey: "imageEditor.option.cloneSourceScaleWidth",
                    value: Binding(
                        get: { viewModel.cloneSourceHorizontalScalePercent },
                        set: { viewModel.setCloneSourceHorizontalScalePercent($0) }
                    ),
                    range: ImageEditorCloneSourceSlotState.minimumScalePercent...ImageEditorCloneSourceSlotState.maximumScalePercent,
                    step: 1,
                    suffix: "%"
                )
                .accessibilityIdentifier("image-editor-clone-source-scale-width")

                Toggle(
                    L10n.text("imageEditor.option.cloneSourceScaleLink"),
                    isOn: Binding(
                        get: { viewModel.cloneSourceScalesLinked },
                        set: { viewModel.setCloneSourceScalesLinked($0) }
                    )
                )
                .toggleStyle(.checkbox)
                .fixedSize()
                .focusable(false)
                .xomoFocusEffectDisabled()
                .accessibilityIdentifier("image-editor-clone-source-scale-link")

                optionSlider(
                    titleKey: "imageEditor.option.cloneSourceScaleHeight",
                    value: Binding(
                        get: { viewModel.cloneSourceVerticalScalePercent },
                        set: { viewModel.setCloneSourceVerticalScalePercent($0) }
                    ),
                    range: ImageEditorCloneSourceSlotState.minimumScalePercent...ImageEditorCloneSourceSlotState.maximumScalePercent,
                    step: 1,
                    suffix: "%"
                )
                .accessibilityIdentifier("image-editor-clone-source-scale-height")

                optionSlider(
                    titleKey: "imageEditor.option.cloneSourceRotation",
                    value: Binding(
                        get: { viewModel.cloneSourceRotationDegrees },
                        set: { viewModel.setCloneSourceRotationDegrees($0) }
                    ),
                    range: ImageEditorCloneSourceSlotState.minimumRotationDegrees...ImageEditorCloneSourceSlotState.maximumRotationDegrees,
                    step: 1,
                    suffix: "°"
                )
                .accessibilityIdentifier("image-editor-clone-source-rotation")

                Toggle(
                    L10n.text("imageEditor.option.cloneSourceShowOverlay"),
                    isOn: $viewModel.cloneStampShowsOverlay
                )
                .toggleStyle(.checkbox)
                .fixedSize()
                .focusable(false)
                .xomoFocusEffectDisabled()
                .accessibilityIdentifier("image-editor-clone-source-show-overlay")

                Toggle(
                    L10n.text("imageEditor.option.cloneSourceOverlayClipped"),
                    isOn: $viewModel.cloneStampOverlayClipsToBrush
                )
                .toggleStyle(.checkbox)
                .fixedSize()
                .disabled(!viewModel.cloneStampShowsOverlay)
                .focusable(false)
                .xomoFocusEffectDisabled()
                .accessibilityIdentifier("image-editor-clone-source-overlay-clipped")

                Toggle(
                    L10n.text("imageEditor.option.cloneSourceOverlayAutoHide"),
                    isOn: $viewModel.cloneStampOverlayAutoHidesWhilePainting
                )
                .toggleStyle(.checkbox)
                .fixedSize()
                .disabled(!viewModel.cloneStampShowsOverlay)
                .focusable(false)
                .xomoFocusEffectDisabled()
                .accessibilityIdentifier("image-editor-clone-source-overlay-auto-hide")

                Toggle(
                    L10n.text("imageEditor.option.cloneSourceOverlayInvert"),
                    isOn: $viewModel.cloneStampOverlayInvertsColors
                )
                .toggleStyle(.checkbox)
                .fixedSize()
                .disabled(!viewModel.cloneStampShowsOverlay)
                .focusable(false)
                .xomoFocusEffectDisabled()
                .accessibilityIdentifier("image-editor-clone-source-overlay-invert")

                Picker(
                    L10n.text("imageEditor.option.cloneSourceOverlayBlendMode"),
                    selection: $viewModel.cloneStampOverlayBlendMode
                ) {
                    ForEach(ImageEditorCloneStampOverlayBlendMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .environment(\.colorScheme, .dark)
                .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                .frame(width: 105)
                .disabled(!viewModel.cloneStampShowsOverlay)
                .focusable(false)
                .xomoFocusEffectDisabled()
                .accessibilityLabel(L10n.text("imageEditor.option.cloneSourceOverlayBlendMode"))
                .accessibilityIdentifier("image-editor-clone-source-overlay-blend-mode")

                optionSlider(
                    titleKey: "imageEditor.option.cloneSourceOverlayOpacity",
                    value: Binding(
                        get: { viewModel.cloneStampOverlayOpacityPercent },
                        set: { viewModel.setCloneStampOverlayOpacityPercent($0) }
                    ),
                    range: 0...100,
                    step: 5,
                    suffix: "%"
                )
                .disabled(!viewModel.cloneStampShowsOverlay)
                .accessibilityIdentifier("image-editor-clone-source-overlay-opacity")

                Toggle(
                    L10n.text("imageEditor.option.cloneSourceFlipHorizontal"),
                    isOn: Binding(
                        get: { viewModel.cloneSourceFlipsHorizontally },
                        set: { viewModel.setCloneSourceFlipsHorizontally($0) }
                    )
                )
                .toggleStyle(.checkbox)
                .fixedSize()
                .focusable(false)
                .xomoFocusEffectDisabled()
                .accessibilityIdentifier("image-editor-clone-source-flip-horizontal")

                Toggle(
                    L10n.text("imageEditor.option.cloneSourceFlipVertical"),
                    isOn: Binding(
                        get: { viewModel.cloneSourceFlipsVertically },
                        set: { viewModel.setCloneSourceFlipsVertically($0) }
                    )
                )
                .toggleStyle(.checkbox)
                .fixedSize()
                .focusable(false)
                .xomoFocusEffectDisabled()
                .accessibilityIdentifier("image-editor-clone-source-flip-vertical")

                Button {
                    viewModel.resetActiveCloneSourceTransform()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(EditorIconButtonStyle(isSelected: false))
                .frame(width: 28, height: 28)
                .disabled(!viewModel.canResetCloneSourceTransform)
                .focusable(false)
                .xomoFocusEffectDisabled()
                .help(L10n.text("imageEditor.action.cloneSourceResetTransform"))
                .accessibilityLabel(L10n.text("imageEditor.action.cloneSourceResetTransform"))
                .accessibilityIdentifier("image-editor-clone-source-reset-transform")

                Button {
                    viewModel.clearActiveCloneSource()
                } label: {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(EditorIconButtonStyle(isSelected: false))
                .frame(width: 28, height: 28)
                .disabled(!viewModel.canClearCloneSource)
                .focusable(false)
                .xomoFocusEffectDisabled()
                .help(L10n.text("imageEditor.action.cloneSourceClear"))
                .accessibilityLabel(L10n.text("imageEditor.action.cloneSourceClear"))
                .accessibilityIdentifier("image-editor-clone-source-clear")

                sampledBrushOptions(
                    isAligned: $viewModel.isCloneStampAligned,
                    sampleSource: $viewModel.cloneStampSampleSource,
                    ignoresAdjustmentLayers:
                        $viewModel.cloneStampIgnoresAdjustmentLayers,
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
                    ignoresAdjustmentLayers:
                        $viewModel.healingBrushIgnoresAdjustmentLayers,
                    sourceActionKey: "imageEditor.action.healingSourcePick",
                    identifierPrefix: "image-editor-healing",
                    showsExplicitSourceControls: viewModel.healingBrushMode == .source
                ) {
                    viewModel.beginSettingHealingSource()
                }
            }

            if viewModel.selectedTool == .eyedropper
                || viewModel.selectedTool == .colorSampler {
                colorSamplingOptionControls
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

    private var patchPatternColorBinding: Binding<Color> {
        Binding {
            Color(nsColor: viewModel.patchPatternContent.color)
        } set: { value in
            guard let color = NSColor(value).usingColorSpace(.deviceRGB) else { return }
            viewModel.patchPatternContent.red = Double(color.redComponent)
            viewModel.patchPatternContent.green = Double(color.greenComponent)
            viewModel.patchPatternContent.blue = Double(color.blueComponent)
        }
    }

    private var patchPatternScaleAxesLinkedBinding: Binding<Bool> {
        Binding {
            viewModel.patchPatternContent.linksAxisScales
        } set: {
            viewModel.setPatchPatternScaleAxesLinked($0)
        }
    }

    private var patchPatternScaleXBinding: Binding<CGFloat> {
        Binding {
            viewModel.patchPatternContent.scaleX
        } set: {
            viewModel.setPatchPatternScaleX($0)
        }
    }

    private var patchPatternScaleYBinding: Binding<CGFloat> {
        Binding {
            viewModel.patchPatternContent.scaleY
        } set: {
            viewModel.setPatchPatternScaleY($0)
        }
    }

    private var colorSamplingOptionControls: some View {
        Group {
            HStack(spacing: 4) {
                Text(L10n.text("imageEditor.info.colorSampler.source"))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                Picker(
                    L10n.text("imageEditor.info.colorSampler.source"),
                    selection: Binding(
                        get: { viewModel.activeColorSamplerSource },
                        set: { _ = viewModel.selectColorSamplerSource($0) }
                    )
                ) {
                    ForEach(ImageEditorColorSamplerSource.allCases) { source in
                        Text(source.shortTitle)
                            .tag(source)
                            .disabled(!viewModel.canSampleColorSamplerSource(source))
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
                .focusable(false)
                .accessibilityIdentifier("image-editor-color-sampling-source")
            }

            HStack(spacing: 4) {
                Text(L10n.text("imageEditor.info.colorSampler.sampleSize"))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                Picker(
                    L10n.text("imageEditor.info.colorSampler.sampleSize"),
                    selection: Binding(
                        get: { viewModel.selectedColorSamplerSampleSize },
                        set: { viewModel.selectColorSamplerSampleSize($0) }
                    )
                ) {
                    ForEach(ImageEditorColorSamplerSampleSize.allCases) { sampleSize in
                        Text(sampleSize.shortTitle).tag(sampleSize)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
                .focusable(false)
                .accessibilityIdentifier("image-editor-color-sampling-size")
            }

            Toggle(
                L10n.text("imageEditor.option.colorSamplerIgnoreAdjustments"),
                isOn: Binding(
                    get: { viewModel.colorSamplerIgnoresAdjustmentLayers },
                    set: { viewModel.setColorSamplerIgnoresAdjustmentLayers($0) }
                )
            )
            .toggleStyle(.checkbox)
            .fixedSize()
            .focusable(false)
            .accessibilityIdentifier(
                "image-editor-color-sampling-ignore-adjustments"
            )

            if viewModel.selectedTool == .eyedropper {
                Toggle(
                    L10n.text("imageEditor.option.eyedropperSamplingRing"),
                    isOn: $viewModel.eyedropperShowsSamplingRing
                )
                .toggleStyle(.checkbox)
                .fixedSize()
                .focusable(false)
                .accessibilityIdentifier("image-editor-eyedropper-sampling-ring")
            }
        }
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
            performUndo()
        } label: {
            Image(systemName: "arrow.uturn.backward")
        }
        .buttonStyle(EditorIconButtonStyle(isSelected: false))
        .focusable(false)
        .disabled(!viewModel.canUndo)
        .help(L10n.text("imageEditor.action.undo"))

        Button {
            performRedo()
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
        case .brush, .pencil, .historyBrush, .eraser, .cloneStamp, .dodge, .burn, .sponge, .blur, .sharpen,
             .smudge, .healingBrush, .quickSelection:
            true
        default:
            false
        }
    }

    private var usesOpacityOption: Bool {
        switch viewModel.selectedTool {
        case .brush, .pencil, .historyBrush, .eraser, .cloneStamp, .dodge, .burn, .sponge, .blur, .sharpen,
             .smudge, .healingBrush, .patchTool, .paintBucket, .gradient, .rectangle, .ellipse:
            true
        default:
            false
        }
    }

    private var usesBrushHardnessOption: Bool {
        usesBrushOptions && viewModel.selectedTool != .pencil
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
        viewModel.selectedTool == .brush
            || viewModel.selectedTool == .pencil
            || viewModel.selectedTool == .historyBrush
            || viewModel.selectedTool == .eraser
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
            if !viewModel.favoriteBrushPresets.isEmpty {
                Section(L10n.text("imageEditor.brushPreset.favoriteSection")) {
                    ForEach(viewModel.favoriteBrushPresets) { preset in
                        brushPresetButton(preset)
                    }
                }
            }
            if !viewModel.recentBrushPresets.isEmpty {
                Section(L10n.text("imageEditor.brushPreset.recentSection")) {
                    ForEach(viewModel.recentBrushPresets) { preset in
                        brushPresetButton(preset)
                    }
                }
            }
            Section(L10n.text("imageEditor.brushPreset.builtInSection")) {
                ForEach(ImageEditorBrushPreset.defaultPresets) { preset in
                    brushPresetButton(preset)
                }
            }
            if !viewModel.customBrushPresets.isEmpty {
                Section(L10n.text("imageEditor.brushPreset.customSection")) {
                    ForEach(viewModel.customBrushPresets) { preset in
                        brushPresetButton(preset)
                    }
                }
            }
            Divider()
            Button {
                viewModel.resetBrushSettings()
            } label: {
                Label(L10n.text("imageEditor.action.brushSettingsReset"), systemImage: "arrow.counterclockwise")
            }
            Button {
                viewModel.createBrushPresetFromCurrentSettings()
            } label: {
                Label(L10n.text("imageEditor.action.brushPresetCreate"), systemImage: "plus")
            }
            Button {
                viewModel.chooseBrushPresetImportFile()
            } label: {
                Label(L10n.text("imageEditor.action.brushPresetImport"), systemImage: "square.and.arrow.down")
            }
            Button {
                viewModel.chooseBrushPresetExportFile()
            } label: {
                Label(L10n.text("imageEditor.action.brushPresetExportAll"), systemImage: "square.and.arrow.up.on.square")
            }
            .disabled(viewModel.customBrushPresets.isEmpty)
            Button {
                viewModel.isBrushPresetManagerPresented = true
            } label: {
                Label(L10n.text("imageEditor.action.brushPresetManage"), systemImage: "square.grid.2x2")
            }
            if let selectedPreset = viewModel.selectedBrushPreset {
                Button {
                    viewModel.setBrushPresetFavorite(
                        id: selectedPreset.id,
                        isFavorite: !viewModel.isFavoriteBrushPreset(id: selectedPreset.id)
                    )
                } label: {
                    Label(
                        L10n.text(
                            viewModel.isFavoriteBrushPreset(id: selectedPreset.id)
                                ? "imageEditor.action.brushPresetUnfavorite"
                                : "imageEditor.action.brushPresetFavorite"
                        ),
                        systemImage: viewModel.isFavoriteBrushPreset(id: selectedPreset.id)
                            ? "star.slash"
                            : "star"
                    )
                }
            }
            if let selectedPreset = viewModel.selectedCustomBrushPreset {
                Button {
                    viewModel.chooseBrushPresetExportFile(presetIDs: [selectedPreset.id])
                } label: {
                    Label(L10n.text("imageEditor.action.brushPresetExport"), systemImage: "square.and.arrow.up")
                }
                Button {
                    beginBrushPresetRename()
                } label: {
                    Label(L10n.text("imageEditor.action.brushPresetRename"), systemImage: "pencil")
                }
                Button {
                    viewModel.updateSelectedCustomBrushPresetFromCurrentSettings()
                } label: {
                    Label(L10n.text("imageEditor.action.brushPresetUpdate"), systemImage: "square.and.arrow.down")
                }
                Button {
                    viewModel.revertSelectedCustomBrushPresetToSavedSettings()
                } label: {
                    Label(L10n.text("imageEditor.action.brushPresetRevert"), systemImage: "arrow.uturn.backward")
                }
                .disabled(!viewModel.canRevertSelectedCustomBrushPreset)
                Button {
                    viewModel.duplicateSelectedCustomBrushPreset()
                } label: {
                    Label(L10n.text("imageEditor.action.brushPresetDuplicate"), systemImage: "square.on.square")
                }
                Button {
                    viewModel.moveSelectedCustomBrushPresetUp()
                } label: {
                    Label(L10n.text("imageEditor.action.brushPresetMoveUp"), systemImage: "arrow.up")
                }
                .disabled(!viewModel.canMoveSelectedCustomBrushPresetUp)
                Button {
                    viewModel.moveSelectedCustomBrushPresetDown()
                } label: {
                    Label(L10n.text("imageEditor.action.brushPresetMoveDown"), systemImage: "arrow.down")
                }
                .disabled(!viewModel.canMoveSelectedCustomBrushPresetDown)
                Button(role: .destructive) {
                    viewModel.deleteBrushPreset(selectedPreset)
                } label: {
                    Label(L10n.text("imageEditor.action.brushPresetDelete"), systemImage: "trash")
                }
            }
        } label: {
            Label(
                viewModel.brushPresetMenuTitle,
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

    private func brushPresetButton(_ preset: ImageEditorBrushPreset) -> some View {
        Button {
            viewModel.applyBrushPreset(preset)
        } label: {
            HStack(spacing: 6) {
                Text(preset.title)
                if viewModel.isFavoriteBrushPreset(id: preset.id) {
                    Image(systemName: "star.fill")
                }
                if viewModel.activeBrushPreset?.id == preset.id {
                    Image(systemName: "checkmark")
                }
            }
        }
    }

    func beginBrushPresetRename() {
        guard let selectedPreset = viewModel.selectedCustomBrushPreset else {
            viewModel.statusText = L10n.text("imageEditor.status.brushPresetRenameUnavailable")
            return
        }
        brushPresetNameDraft = selectedPreset.title
        isBrushPresetRenamePresented = true
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

    private var brushSizeJitterMenu: some View {
        Menu {
            Picker(
                L10n.text("imageEditor.option.sizeJitter"),
                selection: Binding(
                    get: { viewModel.brushSizeJitter },
                    set: { viewModel.setBrushSizeJitter($0) }
                )
            ) {
                ForEach(ImageEditorBrushSizeJitterPresets.values, id: \.self) { jitter in
                    Text(L10n.format("imageEditor.option.percentPreset", Int(jitter)))
                        .tag(jitter)
                }
            }
        } label: {
            Text(
                L10n.format(
                    "imageEditor.option.sizeJitterValue",
                    Int(viewModel.brushSizeJitter.rounded())
                )
            )
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .focusable(false)
        .xomoFocusEffectDisabled()
        .help(L10n.text("imageEditor.help.sizeJitter"))
        .accessibilityIdentifier("image-editor-brush-size-jitter")
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
            Toggle(
                L10n.text("imageEditor.option.angleFollowsStrokeDirection"),
                isOn: Binding(
                    get: { viewModel.brushAngleFollowsStrokeDirection },
                    set: { viewModel.setBrushAngleFollowsStrokeDirection($0) }
                )
            )
            Divider()
            Picker(
                L10n.text("imageEditor.option.angleJitter"),
                selection: Binding(
                    get: { viewModel.brushAngleJitter },
                    set: { viewModel.setBrushAngleJitter($0) }
                )
            ) {
                ForEach(ImageEditorBrushAngleJitterPresets.values, id: \.self) { jitter in
                    Text(L10n.format("imageEditor.option.percentPreset", Int(jitter)))
                        .tag(jitter)
                }
            }
            Divider()
            Picker(
                L10n.text("imageEditor.option.roundnessJitter"),
                selection: Binding(
                    get: { viewModel.brushRoundnessJitter },
                    set: { viewModel.setBrushRoundnessJitter($0) }
                )
            ) {
                ForEach(ImageEditorBrushRoundnessJitterPresets.values, id: \.self) { jitter in
                    Text(L10n.format("imageEditor.option.percentPreset", Int(jitter)))
                        .tag(jitter)
                }
            }
            Picker(
                L10n.text("imageEditor.option.minimumRoundness"),
                selection: Binding(
                    get: { viewModel.brushMinimumRoundness },
                    set: { viewModel.setBrushMinimumRoundness($0) }
                )
            ) {
                ForEach(ImageEditorBrushMinimumRoundnessPresets.values, id: \.self) { roundness in
                    Text(L10n.format("imageEditor.option.percentPreset", Int(roundness)))
                        .tag(roundness)
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

    private var brushScatteringMenu: some View {
        Menu {
            Picker(
                L10n.text("imageEditor.option.scatter"),
                selection: Binding(
                    get: { viewModel.brushScatter },
                    set: { viewModel.setBrushScatter($0) }
                )
            ) {
                ForEach(ImageEditorBrushScatterPresets.values, id: \.self) { scatter in
                    Text(L10n.format("imageEditor.option.percentPreset", Int(scatter)))
                        .tag(scatter)
                }
            }
            Toggle(
                L10n.text("imageEditor.option.scatterBothAxes"),
                isOn: Binding(
                    get: { viewModel.brushScatterBothAxes },
                    set: { viewModel.setBrushScatterBothAxes($0) }
                )
            )
            Divider()
            Picker(
                L10n.text("imageEditor.option.scatterCount"),
                selection: Binding(
                    get: { viewModel.brushScatterCount },
                    set: { viewModel.setBrushScatterCount($0) }
                )
            ) {
                ForEach(ImageEditorBrushScatterCountPresets.values, id: \.self) { count in
                    Text(L10n.format("imageEditor.option.countPreset", count))
                        .tag(count)
                }
            }
            Picker(
                L10n.text("imageEditor.option.scatterCountJitter"),
                selection: Binding(
                    get: { viewModel.brushScatterCountJitter },
                    set: { viewModel.setBrushScatterCountJitter($0) }
                )
            ) {
                ForEach(ImageEditorBrushScatterCountJitterPresets.values, id: \.self) { jitter in
                    Text(L10n.format("imageEditor.option.percentPreset", Int(jitter)))
                        .tag(jitter)
                }
            }
            .disabled(viewModel.brushScatterCount == 1)
        } label: {
            Label(
                L10n.text("imageEditor.option.scattering"),
                systemImage: "circle.grid.cross"
            )
                .font(.system(size: 11, weight: .semibold))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .focusable(false)
        .xomoFocusEffectDisabled()
        .help(L10n.text("imageEditor.help.scattering"))
        .accessibilityIdentifier("image-editor-brush-scattering")
    }

    private var brushTransferMenu: some View {
        Menu {
            Picker(
                L10n.text("imageEditor.option.opacityJitter"),
                selection: Binding(
                    get: { viewModel.brushOpacityJitter },
                    set: { viewModel.setBrushOpacityJitter($0) }
                )
            ) {
                ForEach(ImageEditorBrushSizeJitterPresets.values, id: \.self) { jitter in
                    Text(L10n.format("imageEditor.option.percentPreset", Int(jitter)))
                        .tag(jitter)
                }
            }
            Picker(
                L10n.text("imageEditor.option.flowJitter"),
                selection: Binding(
                    get: { viewModel.brushFlowJitter },
                    set: { viewModel.setBrushFlowJitter($0) }
                )
            ) {
                ForEach(ImageEditorBrushSizeJitterPresets.values, id: \.self) { jitter in
                    Text(L10n.format("imageEditor.option.percentPreset", Int(jitter)))
                        .tag(jitter)
                }
            }
        } label: {
            Label(
                L10n.text("imageEditor.option.transfer"),
                systemImage: "drop.halffull"
            )
                .font(.system(size: 11, weight: .semibold))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .focusable(false)
        .xomoFocusEffectDisabled()
        .help(L10n.text("imageEditor.help.transfer"))
        .accessibilityIdentifier("image-editor-brush-transfer")
    }

    private var brushTipFinishMenu: some View {
        Menu {
            Toggle(
                L10n.text("imageEditor.option.noise"),
                isOn: Binding(
                    get: { viewModel.brushNoiseEnabled },
                    set: { viewModel.setBrushNoiseEnabled($0) }
                )
            )
            Toggle(
                L10n.text("imageEditor.option.wetEdges"),
                isOn: Binding(
                    get: { viewModel.brushWetEdgesEnabled },
                    set: { viewModel.setBrushWetEdgesEnabled($0) }
                )
            )
        } label: {
            Label(
                L10n.text("imageEditor.option.brushTipFinish"),
                systemImage: "circle.dotted"
            )
                .font(.system(size: 11, weight: .semibold))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .focusable(false)
        .xomoFocusEffectDisabled()
        .help(L10n.text("imageEditor.help.brushTipFinish"))
        .accessibilityIdentifier("image-editor-brush-tip-finish")
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
        ignoresAdjustmentLayers: Binding<Bool>,
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

        Toggle(
            L10n.text("imageEditor.option.colorSamplerIgnoreAdjustments"),
            isOn: ignoresAdjustmentLayers
        )
        .toggleStyle(.checkbox)
        .fixedSize()
        .focusable(false)
        .xomoFocusEffectDisabled()
        .disabled(sampleSource.wrappedValue == .currentLayer)
        .accessibilityIdentifier("\(identifierPrefix)-ignore-adjustments")

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
            viewModel.activateQuickMaskControl(modifierFlags: NSEvent.modifierFlags)
        } label: {
            Image(systemName: "circle.inset.filled")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 30, height: 30)
        }
        .buttonStyle(EditorIconButtonStyle(isSelected: viewModel.isQuickMaskMode))
        .focusable(false)
        .xomoFocusEffectDisabled()
        .help(L10n.text("imageEditor.help.quickMask"))
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

            Text(L10n.text("imageEditor.quickMask.previewLabel"))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))

            HStack(spacing: 6) {
                ForEach(ImageEditorQuickMaskPreviewMode.allCases) { mode in
                    Button(mode.title) {
                        viewModel.setQuickMaskPreviewMode(mode)
                    }
                    .buttonStyle(
                        EditorSegmentButtonStyle(
                            isSelected: viewModel.quickMaskPreviewMode == mode
                        )
                    )
                    .focusable(false)
                    .xomoFocusEffectDisabled()
                }
            }
            .disabled(!viewModel.isQuickMaskMode)
            .help(L10n.text("imageEditor.help.quickMaskPreview"))

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
                guard ImageEditorLiveMoveShortcutPolicy.allowsDirectShortcut(
                    hasActiveLayerMoveTransaction: viewModel.hasActiveLayerMoveTransaction,
                    hasActivePathAnchorMoveTransaction: viewModel.hasActivePathAnchorMoveTransaction
                ) else { return }
                viewModel.clearColorSamplers()
            } label: {
                EmptyView()
            }
            .keyboardShortcut("x", modifiers: [.option])
            .accessibilityHidden(true)

            ForEach(ImageEditorTool.classicShortcutGroups) { group in
                Button {
                    guard ImageEditorLiveMoveShortcutPolicy.allowsDirectShortcut(
                        hasActiveLayerMoveTransaction: viewModel.hasActiveLayerMoveTransaction,
                        hasActivePathAnchorMoveTransaction: viewModel.hasActivePathAnchorMoveTransaction
                    ) else { return }
                    viewModel.selectClassicToolShortcut(group.key)
                } label: {
                    EmptyView()
                }
                .keyboardShortcut(KeyEquivalent(group.key), modifiers: [])
                .accessibilityHidden(true)

                if group.tools.count > 1 {
                    Button {
                        guard ImageEditorLiveMoveShortcutPolicy.allowsDirectShortcut(
                            hasActiveLayerMoveTransaction: viewModel.hasActiveLayerMoveTransaction,
                            hasActivePathAnchorMoveTransaction: viewModel.hasActivePathAnchorMoveTransaction
                        ) else { return }
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
                performDirectShortcut { viewModel.adjustBrushSizeShortcut(by: -1) }
            } label: {
                EmptyView()
            }
            .keyboardShortcut("[", modifiers: [])
            .accessibilityHidden(true)

            Button {
                performDirectShortcut { viewModel.adjustBrushSizeShortcut(by: 1) }
            } label: {
                EmptyView()
            }
            .keyboardShortcut("]", modifiers: [])
            .accessibilityHidden(true)

            Button {
                performDirectShortcut { viewModel.adjustBrushHardnessShortcut(by: -0.25) }
            } label: {
                EmptyView()
            }
            .keyboardShortcut("[", modifiers: [.shift])
            .accessibilityHidden(true)

            Button {
                performDirectShortcut { viewModel.adjustBrushHardnessShortcut(by: 0.25) }
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
                    performDirectShortcut { viewModel.applyOpacityShortcutDigit(digit) }
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
                performDirectShortcut { viewModel.resetForegroundBackgroundColors() }
            } label: {
                EmptyView()
            }
            .keyboardShortcut("d", modifiers: [])
            .accessibilityHidden(true)

            Button {
                performDirectShortcut { viewModel.swapForegroundBackgroundColors() }
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
                performDirectShortcut { viewModel.zoomOut() }
            } label: {
                EmptyView()
            }
            .keyboardShortcut("-", modifiers: [.option])
            .accessibilityHidden(true)

            Button {
                performDirectShortcut { viewModel.zoomIn() }
            } label: {
                EmptyView()
            }
            .keyboardShortcut("=", modifiers: [.option, .shift])
            .accessibilityHidden(true)

            Button {
                performDirectShortcut { viewModel.zoomIn() }
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
            performDirectShortcut { performNudgeCommand(delta) }
        } label: {
            EmptyView()
        }
        .keyboardShortcut(key, modifiers: modifiers)
        .accessibilityHidden(true)
    }

    private func performDirectShortcut(_ action: () -> Void) {
        guard ImageEditorLiveMoveShortcutPolicy.allowsDirectShortcut(
            hasActiveLayerMoveTransaction: viewModel.hasActiveLayerMoveTransaction,
            hasActivePathAnchorMoveTransaction: viewModel.hasActivePathAnchorMoveTransaction
        ) else { return }
        action()
    }

    func performNudgeCommand(_ delta: CGSize) {
        guard ImageEditorNudgeCommandDispatchGate.shouldDispatch(
            delta,
            event: .currentKeyEvent
        ) else { return }
        if cancelPathAnchorDragForKeyboardCommand() {
            return
        }
        if cancelGradientOverlayCanvasHandleDragForLifecycle() {
            return
        }
        if nudgeSelectedGradientOverlayHandleIfNeeded(by: delta) {
            return
        }
        if !viewModel.nudgeSelectedDeliveryObject(by: delta) {
            viewModel.nudgeSelectionOrSelectedLayer(by: delta)
        }
    }

    private func restoreKeyboardFocusAfterExternalOpenIfNeeded() {
        guard let requestID = externalOpenCoordinator.editorKeyboardFocusRequestID else {
            return
        }
        ImageEditorFilePanelKeyboardFocusRestorer.restore(
            to: NSApp.keyWindow ?? NSApp.mainWindow
        )
        externalOpenCoordinator.fulfillEditorKeyboardFocusRequest(requestID)
    }

    private func presentExternalFigmaLinkImportIfNeeded() {
        guard !isFigmaLinkImportPresented,
              let request = externalOpenCoordinator.figmaLinkImportRequest
        else { return }
        presentFigmaLinkImport(
            canonicalURL: request.canonicalURL,
            placementCenter: viewModel.visibleCanvasCenter
        )
        externalOpenCoordinator.fulfillFigmaLinkImportRequest(request.id)
    }

    @discardableResult
    func deleteSelectedObjectFromKeyboard(
        event: ImageEditorKeyboardShortcutEventSignature? = .currentKeyEvent
    ) -> Bool {
        guard ImageEditorDeleteCommandDispatchGate.shouldDispatch(
            event: event
        ) else {
            // A second AppKit route for the same physical Delete must remain
            // consumed so it cannot fall through to history or text deletion.
            return true
        }
        func finishDispatch(_ didHandle: Bool) -> Bool {
            if didHandle {
                ImageEditorDeleteCommandDispatchGate.recordDispatch(event: event)
            }
            return didHandle
        }
        if resetPendingCropToCanvas() {
            return finishDispatch(true)
        }
        if cancelPathAnchorDragForKeyboardCommand() {
            return finishDispatch(true)
        }
        if cancelGradientOverlayCanvasHandleDragForLifecycle() {
            return finishDispatch(true)
        }
        if ImageEditorPendingPenPointerPolicy.ownsUncommittedPoint(
            tool: canvasInteractionTool,
            isPointerSequenceActive: isPenPointerSequenceActive,
            isMovingPathAnchor: isMovingPathAnchor
        ) {
            isPathAnchorDragCancelled = true
            return finishDispatch(true)
        }
        if viewModel.deletePendingPenPointIfNeeded() {
            return finishDispatch(true)
        }
        guard !viewModel.hasActiveLayerMoveTransaction else { return false }
        if deleteSelectedGradientOverlayStopIfNeeded() {
            return finishDispatch(true)
        }
        if resetSelectedGradientOverlayMidpointIfNeeded() {
            return finishDispatch(true)
        }
        if deleteSelectedShapeGradientStopIfNeeded() {
            return finishDispatch(true)
        }
        if viewModel.selectedTool == .pen || viewModel.selectedTool == .directSelection,
           viewModel.canDeleteSelectedPathAnchor {
            viewModel.deleteSelectedPathAnchor()
            return finishDispatch(true)
        }
        if viewModel.deleteSelectedDeliveryObjectIfNeeded() {
            return finishDispatch(true)
        }
        if viewModel.deleteSelectedXomoObjectIfNeeded() {
            return finishDispatch(true)
        }

        switch ImageEditorContextualDocumentDeletePolicy.resolve(
            hasSelection: viewModel.hasSelection,
            canRemoveSelectionPixels: viewModel.canRemoveSelectionPixels,
            canDeleteLayer: viewModel.canDeleteLayer
        ) {
        case .clearSelectionPixels:
            viewModel.clearSelectionPixels()
            return finishDispatch(true)
        case .deleteSelectedLayer:
            return finishDispatch(viewModel.deleteSelectedLayerFromKeyboardIfPossible())
        case .none:
            return false
        }
    }

    private func performKeyboardShortcut(_ action: ImageEditorKeyboardShortcutAction) {
        guard ImageEditorLiveMoveShortcutPolicy.disposition(
            for: action,
            hasActiveLayerMoveTransaction: viewModel.hasActiveLayerMoveTransaction,
            hasActivePathAnchorMoveTransaction: viewModel.hasActivePathAnchorMoveTransaction
        ) != .ignore else { return }

        switch action {
        case .newCanvas: performFileCommand(.createCanvas)
        case .openProject: performFileCommand(.openProject)
        case .saveProject: performFileCommand(.saveProject)
        case .export: performFileCommand(.export)
        case .openFigmaLinkImport: performFileCommand(.importFigmaLink)
        case .undo: performUndo()
        case .redo: performRedo()
        case .cutSelectionClipboard: performClipboardCommand(.cutSelection)
        case .copySelectionClipboard: performClipboardCommand(.copySelection)
        case .copyMergedClipboard: performClipboardCommand(.copyMerged)
        case .copySelectedLayersClipboard: performClipboardCommand(.copySelectedLayers)
        case .pasteClipboardLayer: performClipboardCommand(.pasteAsLayer)
        case .pasteClipboardIntoSelection: performClipboardCommand(.pasteIntoSelection)
        case .pasteClipboardInPlaceLayer: performClipboardCommand(.pasteInPlace)
        case .toggleTransformControls: performToggleTransformControls()
        case .openSelectionFill: performSelectionFillCommand(.dialog)
        case .fillSelection: performSelectionFillCommand(.foreground)
        case .fillSelectionPreservingTransparency:
            performSelectionFillCommand(.foregroundPreservingTransparency)
        case .fillSelectionBackground: performSelectionFillCommand(.background)
        case .fillSelectionBackgroundPreservingTransparency:
            performSelectionFillCommand(.backgroundPreservingTransparency)
        case .fillSelectionHistory: performSelectionFillCommand(.history)
        case .fillSelectionHistoryPreservingTransparency:
            performSelectionFillCommand(.historyPreservingTransparency)
        case .clearSelectionPixels: viewModel.clearSelectionPixels()
        case .resizeImage: performImageGeometryCommand(.resizeImage)
        case .resizeCanvas: performImageGeometryCommand(.resizeCanvas)
        case .levels: viewModel.selectAdjustment(.levels)
        case .curves: viewModel.selectAdjustment(.curves)
        case .colorBalance: viewModel.selectAdjustment(.colorBalance)
        case .hueSaturation: viewModel.selectAdjustment(.hueSaturation)
        case .toneRange(let range): viewModel.applyToneRangeShortcut(range)
        case .spongeMode(let mode): viewModel.applySpongeModeShortcut(mode)
        case .desaturate: performPixelCorrectionCommand(.desaturate)
        case .invertPixels: performPixelCorrectionCommand(.invert)
        case .autoLevels: performPixelCorrectionCommand(.autoLevels)
        case .autoContrast: performPixelCorrectionCommand(.autoContrast)
        case .autoColor: performPixelCorrectionCommand(.autoColor)
        case .newLayer: performNewLayer()
        case .duplicateSelectionOrLayer: performDuplicateSelectionOrLayer()
        case .cutSelectionToLayer: performCutSelectionToLayer()
        case .groupSelectedLayer: performGroupSelectedLayer()
        case .ungroupSelectedLayers: performUngroupSelectedLayers()
        case .mergeDown: performMergeDown()
        case .stampVisible: performStampVisible()
        case .mergeVisible: performMergeVisible()
        case .layerTop: performLayerTop()
        case .layerUp: performLayerUp()
        case .layerDown: performLayerDown()
        case .layerBottom: performLayerBottom()
        case .navigateLayerSelection(let navigation): viewModel.navigateLayerSelection(navigation)
        case .selectAllLayers: viewModel.selectAllWorkspaceObjects()
        case .selectAll: performSelectionCommand(.selectAll)
        case .clearSelection: performSelectionCommand(.clear)
        case .reselectSelection: performSelectionCommand(.reselect)
        case .invertSelection: performSelectionCommand(.invert)
        case .featherSelection: performSelectionCommand(.feather)
        case .toggleQuickMask: performToggleQuickMask()
        case .toggleQuickMaskGrayscalePreview: viewModel.toggleQuickMaskGrayscalePreview()
        case .toggleLayerMaskRubylith: viewModel.toggleSelectedLayerMaskRubylithPreview()
        case .applyLastFilter: performLastFilter()
        case .toggleRulers: performCanvasAidCommand(.rulers)
        case .toggleGuides: performCanvasAidCommand(.guides)
        case .toggleGuideSnapping: performCanvasAidCommand(.guideSnapping)
        case .toggleGuidesLocked: performCanvasAidCommand(.guidesLocked)
        case .toggleGrid: performCanvasAidCommand(.grid)
        case .toggleCroppedAreaVisibility: showsCroppedArea.toggle()
        case .swapCropOrientation: swapPendingCropOrientation()
        case .cycleCropGuide:
            guard pendingCropRect != nil else { return }
            cropGuideKind = cropGuideKind.next
            viewModel.statusText = L10n.format(
                "imageEditor.status.cropGuideChanged",
                L10n.text(cropGuideKind.titleKey)
            )
        case .zoomIn: performZoomCommand(.zoomIn)
        case .zoomOut: performZoomCommand(.zoomOut)
        case .actualPixels: performZoomCommand(.actualPixels)
        case .fitOnScreen: performZoomCommand(.fitOnScreen)
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

    func performUndo() {
        guard ImageEditorHistoryCommandDispatchGate.shouldDispatch(
            event: .currentKeyEvent
        ) else { return }
        if ImageEditorPendingPenPointerPolicy.ownsUncommittedPoint(
            tool: canvasInteractionTool,
            isPointerSequenceActive: isPenPointerSequenceActive,
            isMovingPathAnchor: isMovingPathAnchor
        ) {
            isPathAnchorDragCancelled = true
            return
        }
        if viewModel.hasActivePathAnchorMoveTransaction || viewModel.hasPendingPenPathTransaction {
            isPathAnchorDragCancelled = true
        }
        viewModel.undo()
    }

    func performNewLayer() {
        guard ImageEditorNewLayerCommandDispatchGate.shouldDispatch(
            event: .currentKeyEvent
        ) else { return }
        viewModel.addLayer()
    }

    func performClipboardCommand(_ action: ImageEditorClipboardCommandAction) {
        guard ImageEditorClipboardCommandDispatchGate.shouldDispatch(
            action,
            event: .currentKeyEvent
        ) else { return }
        switch action {
        case .cutSelection: viewModel.cutSelectionToClipboard()
        case .copySelection: viewModel.copySelectionToClipboard()
        case .copyMerged: viewModel.copyMergedToClipboard()
        case .copySelectedLayers: viewModel.copySelectedLayersToClipboard()
        case .pasteAsLayer: performContextualPasteAsLayer()
        case .pasteIntoSelection: viewModel.pasteClipboardIntoSelectionAsLayer()
        case .pasteInPlace: viewModel.pasteClipboardInPlaceAsLayer()
        }
    }

    func performContextualPasteAsLayer(
        pasteboard: NSPasteboard = .general
    ) {
        switch XomoFigmaClipboardPastePolicy.resolve(
            hasLayerPayload: viewModel.canPasteClipboardImage(from: pasteboard),
            clipboardText: pasteboard.string(forType: .string),
            clipboardURLString: pasteboard.string(forType: .URL),
            clipboardRichLinkTargets: XomoFigmaRichClipboardLinkExtractor.targets(
                from: pasteboard
            )
        ) {
        case .layerPayload:
            viewModel.pasteClipboardAsLayer(from: pasteboard)
        case let .figmaLink(canonicalURL):
            presentFigmaLinkImport(
                canonicalURL: canonicalURL,
                placementCenter: viewModel.visibleCanvasCenter
            )
        case .unavailable:
            viewModel.pasteClipboardAsLayer(from: pasteboard)
        }
    }

    func performToggleTransformControls() {
        guard ImageEditorTransformControlsCommandDispatchGate.shouldDispatch(
            event: .currentKeyEvent
        ) else { return }
        viewModel.toggleTransformControlsVisible()
    }

    func performDuplicateSelectionOrLayer() {
        guard ImageEditorLayerDuplicateCommandDispatchGate.shouldDispatch(
            event: .currentKeyEvent
        ) else { return }
        viewModel.duplicateSelectionOrSelectedLayer()
    }

    func performCutSelectionToLayer() {
        guard ImageEditorLayerCutCommandDispatchGate.shouldDispatch(
            event: .currentKeyEvent
        ) else { return }
        viewModel.cutSelectionToNewLayer()
    }

    func performGroupSelectedLayer() {
        guard ImageEditorLayerGroupingCommandDispatchGate.shouldDispatch(
            .group,
            event: .currentKeyEvent
        ) else { return }
        viewModel.groupSelectedLayer()
    }

    func performUngroupSelectedLayers() {
        guard ImageEditorLayerGroupingCommandDispatchGate.shouldDispatch(
            .ungroup,
            event: .currentKeyEvent
        ) else { return }
        viewModel.ungroupSelectedLayers()
    }

    func performMergeDown() {
        guard ImageEditorLayerMergeCommandDispatchGate.shouldDispatch(
            .mergeDown,
            event: .currentKeyEvent
        ) else { return }
        viewModel.mergeSelectedLayerDown()
    }

    func performStampVisible() {
        guard ImageEditorLayerMergeCommandDispatchGate.shouldDispatch(
            .stampVisible,
            event: .currentKeyEvent
        ) else { return }
        viewModel.stampVisibleLayers()
    }

    func performMergeVisible() {
        guard ImageEditorLayerMergeCommandDispatchGate.shouldDispatch(
            .mergeVisible,
            event: .currentKeyEvent
        ) else { return }
        viewModel.mergeVisibleLayers()
    }

    func performLayerTop() {
        guard ImageEditorLayerOrderCommandDispatchGate.shouldDispatch(
            .top,
            event: .currentKeyEvent
        ) else { return }
        viewModel.moveSelectedLayerToTop(inVisibleOrder: filteredVisibleLayerRowIDs)
    }

    func performLayerUp() {
        guard ImageEditorLayerOrderCommandDispatchGate.shouldDispatch(
            .up,
            event: .currentKeyEvent
        ) else { return }
        viewModel.moveSelectedLayerUp(inVisibleOrder: filteredVisibleLayerRowIDs)
    }

    func performLayerDown() {
        guard ImageEditorLayerOrderCommandDispatchGate.shouldDispatch(
            .down,
            event: .currentKeyEvent
        ) else { return }
        viewModel.moveSelectedLayerDown(inVisibleOrder: filteredVisibleLayerRowIDs)
    }

    func performLayerBottom() {
        guard ImageEditorLayerOrderCommandDispatchGate.shouldDispatch(
            .bottom,
            event: .currentKeyEvent
        ) else { return }
        viewModel.moveSelectedLayerToBottom(inVisibleOrder: filteredVisibleLayerRowIDs)
    }

    func performToggleQuickMask() {
        guard ImageEditorQuickMaskCommandDispatchGate.shouldDispatch(
            event: .currentKeyEvent
        ) else { return }
        viewModel.toggleQuickMaskMode()
    }

    func performSelectionCommand(_ action: ImageEditorSelectionCommandAction) {
        guard ImageEditorSelectionCommandDispatchGate.shouldDispatch(
            action,
            event: .currentKeyEvent
        ) else { return }
        switch action {
        case .selectAll: viewModel.selectAll()
        case .clear: viewModel.clearSelection()
        case .reselect: viewModel.reselectSelection()
        case .invert: viewModel.invertSelection()
        case .feather: viewModel.featherSelection()
        }
    }

    func performSelectionFillCommand(_ action: ImageEditorSelectionFillCommandAction) {
        guard ImageEditorSelectionFillCommandDispatchGate.shouldDispatch(
            action,
            event: .currentKeyEvent
        ) else { return }
        switch action {
        case .dialog:
            if case .tool = viewModel.workspaceInputMode {
                viewModel.presentSelectionFillPanel()
            }
        case .foreground: viewModel.fillSelection()
        case .foregroundPreservingTransparency:
            viewModel.fillSelectionPreservingTransparency()
        case .background: viewModel.fillSelectionWithBackgroundColor()
        case .backgroundPreservingTransparency:
            viewModel.fillSelectionWithBackgroundColorPreservingTransparency()
        case .history: viewModel.fillSelectionFromHistory()
        case .historyPreservingTransparency:
            viewModel.fillSelectionFromHistoryPreservingTransparency()
        }
    }

    func performImageGeometryCommand(_ action: ImageEditorImageGeometryCommandAction) {
        guard ImageEditorImageGeometryCommandDispatchGate.shouldDispatch(
            action,
            event: .currentKeyEvent
        ) else { return }
        switch action {
        case .resizeImage: viewModel.resizeImageToControlSize()
        case .resizeCanvas: viewModel.resizeCanvasToControlSize()
        }
    }

    func performPixelCorrectionCommand(_ action: ImageEditorPixelCorrectionCommandAction) {
        guard ImageEditorPixelCorrectionCommandDispatchGate.shouldDispatch(
            action,
            event: .currentKeyEvent
        ) else { return }
        switch action {
        case .desaturate: viewModel.desaturateSelectedLayer()
        case .invert: viewModel.invertCurrentEditingTarget()
        case .autoLevels: viewModel.autoLevelsSelectedLayer()
        case .autoContrast: viewModel.autoContrastSelectedLayer()
        case .autoColor: viewModel.autoColorSelectedLayer()
        }
    }

    func performLastFilter() {
        guard ImageEditorLastFilterCommandDispatchGate.shouldDispatch(
            event: .currentKeyEvent
        ) else { return }
        viewModel.applyLastFilter()
    }

    func performCanvasAidCommand(_ action: ImageEditorCanvasAidCommandAction) {
        guard ImageEditorCanvasAidCommandDispatchGate.shouldDispatch(
            action,
            event: .currentKeyEvent
        ) else { return }
        switch action {
        case .rulers: viewModel.toggleRulersVisible()
        case .guides: viewModel.toggleGuidesVisible()
        case .guideSnapping: viewModel.toggleGuideSnapping()
        case .guidesLocked: viewModel.toggleGuidesLocked()
        case .grid: viewModel.toggleGridVisible()
        }
    }

    func performZoomCommand(_ action: ImageEditorZoomCommandAction) {
        guard ImageEditorZoomCommandDispatchGate.shouldDispatch(
            action,
            event: .currentKeyEvent
        ) else { return }
        switch action {
        case .zoomIn: viewModel.zoomIn()
        case .zoomOut: viewModel.zoomOut()
        case .actualPixels: viewModel.zoomActualPixels()
        case .fitOnScreen: viewModel.fitZoom()
        }
    }

    func performRedo() {
        guard ImageEditorHistoryCommandDispatchGate.shouldDispatch(
            event: .currentKeyEvent
        ) else { return }
        if ImageEditorPendingPenPointerPolicy.ownsUncommittedPoint(
            tool: canvasInteractionTool,
            isPointerSequenceActive: isPenPointerSequenceActive,
            isMovingPathAnchor: isMovingPathAnchor
        ) {
            isPathAnchorDragCancelled = true
            return
        }
        if viewModel.hasActivePathAnchorMoveTransaction || viewModel.hasPendingPenPathTransaction {
            isPathAnchorDragCancelled = true
        }
        viewModel.redo()
    }

    private func cancelPathAnchorDragForCanvasLifecycle() {
        if cancelPenAnchorConversionGesture() {
            NSCursor.arrow.set()
        }
        guard ImageEditorPathAnchorDragLifecyclePolicy.shouldCancel(
            isMovingPathAnchor: isMovingPathAnchor,
            hasActiveTransaction: viewModel.hasActivePathAnchorMoveTransaction
        ) else { return }
        isPathAnchorDragCancelled = true
        _ = viewModel.cancelMovingPathAnchor()
        NSCursor.arrow.set()
    }

    private func beginCanvasPointerSequence() {
        // A lost mouse-up must not leave a stale rubber band owning the next
        // pointer sequence. Selection is committed only by the matching end.
        objectSelectionBoxDrag = nil
        isPenPointerSequenceActive = canvasInteractionTool == .pen
        isDirectPathGestureResolved = false
        isPathSelectionGestureResolved = false
        pendingPenCreationAction = nil
        resetPenAnchorConversionGesture()
        penAnchorDeletionGestureState = .none
        penPathContinuationGestureState = .none
        guard ImageEditorPathAnchorDragLifecyclePolicy.shouldReleaseCancellationLatch(
            isCancelled: isPathAnchorDragCancelled,
            hasActiveTransaction: viewModel.hasActivePathAnchorMoveTransaction
        ) else { return }
        isPathAnchorDragCancelled = false
        isMovingPathAnchor = false
    }

    private func resetPenAnchorConversionGesture() {
        isPenAnchorConversionGestureActive = false
        penAnchorConversionAction = nil
        penAnchorConversionTarget = nil
        isPenAnchorConversionGestureBlocked = false
    }

    private func resolvedPenAnchorDeletionState(
        at canvasPoint: CGPoint?
    ) -> ImageEditorPenAnchorDeletionState {
        guard canvasInteractionTool == .pen,
              !canvasModifierFlags.contains(.option)
        else { return .none }
        if isMovingPathAnchor {
            return penAnchorDeletionGestureState
        }
        return viewModel.penAnchorDeletionState(at: canvasPoint)
    }

    private func resolvedPenPathContinuationState(
        at canvasPoint: CGPoint?
    ) -> ImageEditorPenPathContinuationState {
        guard canvasInteractionTool == .pen,
              !canvasModifierFlags.contains(.option)
        else { return .none }
        if penPathContinuationGestureState != .none {
            return penPathContinuationGestureState
        }
        if viewModel.hasPendingPenPathTransaction {
            return viewModel.penPathJoinState(at: canvasPoint)
        }
        if isMovingPathAnchor {
            return .none
        }
        return viewModel.penPathContinuationState(at: canvasPoint)
    }

    @discardableResult
    private func cancelPenAnchorConversionGesture() -> Bool {
        guard isPenAnchorConversionGestureActive else { return false }
        isPathAnchorDragCancelled = true
        resetPenAnchorConversionGesture()
        return true
    }

    @discardableResult
    private func cancelPathAnchorDragForKeyboardCommand() -> Bool {
        guard ImageEditorPathAnchorDragLifecyclePolicy.shouldCancel(
            isMovingPathAnchor: isMovingPathAnchor,
            hasActiveTransaction: viewModel.hasActivePathAnchorMoveTransaction
        ) else { return false }
        isPathAnchorDragCancelled = true
        _ = viewModel.cancelMovingPathAnchor()
        return true
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
                viewModel.resetForegroundBackgroundColors()
            } label: {
                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .fill(Color.white)
                        .overlay(Rectangle().stroke(Color.gray, lineWidth: 1))
                        .frame(width: 8, height: 8)
                        .offset(x: 4, y: 4)
                    Rectangle()
                        .fill(Color.black)
                        .overlay(Rectangle().stroke(Color.white.opacity(0.9), lineWidth: 1))
                        .frame(width: 8, height: 8)
                }
                .frame(width: 14, height: 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(width: 18, height: 18)
            .focusable(false)
            .xomoFocusEffectDisabled()
            .help(L10n.text("imageEditor.action.colorDefaultForegroundBackground"))
            .accessibilityIdentifier("image-editor-color-default")
            .accessibilityLabel(L10n.text("imageEditor.action.colorDefaultForegroundBackground"))
            .offset(x: 0, y: 27)

            Button {
                viewModel.swapForegroundBackgroundColors()
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focusable(false)
            .xomoFocusEffectDisabled()
            .help(L10n.text("imageEditor.action.colorSwapForegroundBackground"))
            .accessibilityIdentifier("image-editor-color-swap")
            .accessibilityLabel(L10n.text("imageEditor.action.colorSwapForegroundBackground"))
            .offset(x: 29, y: -2)
        }
        .frame(width: 50, height: 46)
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
        .focusable(false)
        .xomoFocusEffectDisabled()
        .help(L10n.text(accessibilityLabelKey))
    }

    private func gradientOverlayCanvasStopColorWell(at stopIndex: Int) -> some View {
        let label = L10n.format(
            "imageEditor.properties.shapeGradientStopColor",
            stopIndex + 1
        )
        return ImageEditorColorWell(
            color: Binding(
                get: {
                    let stops = viewModel.selectedLayerGradientOverlayColorStops
                    return stops.indices.contains(stopIndex)
                        ? stops[stopIndex].color
                        : .clear
                },
                set: { color in
                    _ = viewModel.updateSelectedLayerGradientOverlayCanvasStopColor(color)
                }
            ),
            accessibilityIdentifier:
                "image-editor-gradient-overlay-canvas-stop-color-\(stopIndex)",
            accessibilityLabel: label,
            onEditingBegan: {
                guard selectedGradientOverlayStopIndex == stopIndex else { return false }
                return viewModel.beginEditingSelectedLayerGradientOverlayCanvasStopColor(
                    at: stopIndex
                )
            },
            onEditingEnded: {
                viewModel.finishEditingSelectedLayerGradientOverlayCanvasStop()
            },
            activationRequestID: gradientOverlayStopColorActivationRequestID
        )
        .frame(width: 26, height: 26)
        .focusable(false)
        .xomoFocusEffectDisabled()
        .help(label)
    }

    private func requestGradientOverlayCanvasStopColorEditing(at stopIndex: Int) {
        selectedGradientOverlayStopIndex = stopIndex
        selectedGradientOverlayMidpointIndex = nil
        DispatchQueue.main.async {
            guard selectedGradientOverlayStopIndex == stopIndex else { return }
            gradientOverlayStopColorActivationRequestID &+= 1
        }
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
                    maskColorOverlay(in: geometry.size)
                    selectionOverlay(in: geometry.size)
                    patchTransferGuideOverlay(in: geometry.size)
                    moveToolHoverOutlineOverlay(in: geometry.size)
                    objectSelectionBoxOverlay(in: geometry.size)
                    savedPathOverlay(in: geometry.size)
                    sliceOverlay(in: geometry.size)
                    hotspotOverlay(in: geometry.size)
                    deliverySelectionOverlay(in: geometry.size)
                    colorSamplerOverlay(in: geometry.size)
                    eyedropperSamplingRingOverlay(in: geometry.size)
                    cloneStampPixelOverlay(in: geometry.size)
                    sampledBrushSourceOverlay(in: geometry.size)
                    paintAirbrushOverlay(in: geometry.size)
                    toneAirbrushOverlay(in: geometry.size)
                    layerTransformOverlay(in: geometry.size)
                    shapeGradientControlOverlay(in: geometry.size)
                    gradientOverlayCenterControlOverlay(in: geometry.size)
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
                    onDrop: { values, location in
                        switch XomoCanvasStringDropPolicy.resolve(
                            values,
                            knownComponentPayloads: Set(XomoComponentKind.allCases.map(\.rawValue))
                        ) {
                        case let .componentPayload(rawValue):
                            guard let component = XomoComponentKind(rawValue: rawValue),
                                  let canvasPoint = imagePoint(
                                      from: location,
                                      in: geometry.size
                                  )
                            else { return false }
                            viewModel.insertXomoComponent(
                                component,
                                at: viewModel.xomoComponentDropOrigin(
                                    component,
                                    centeredAt: canvasPoint
                                )
                            )
                            XomoComponentLibraryCursorPolicy.restoreArrow(for: .dropCompleted)
                            return true
                        case let .figmaLink(canonicalURL):
                            guard let canvasPoint = imagePoint(
                                from: location,
                                in: geometry.size
                            ) else { return false }
                            presentFigmaLinkImport(
                                canonicalURL: canonicalURL,
                                placementCenter: canvasPoint
                            )
                            return true
                        case .unavailable:
                            return false
                        }
                    },
                    onFileDrop: { urls, location in
                        switch XomoCanvasURLDropPolicy.resolve(urls) {
                        case let .localFiles(urls):
                            guard let canvasPoint = imagePoint(
                                from: location,
                                in: geometry.size
                            ) else { return false }
                            let didImport = viewModel.importLayerFiles(
                                urls,
                                centeredAt: canvasPoint
                            )
                            if didImport {
                                ImageEditorFilePanelKeyboardFocusRestorer.claimEditorResponder(
                                    in: NSApp.keyWindow ?? NSApp.mainWindow
                                )
                            }
                            return didImport
                        case let .figmaLink(canonicalURL):
                            guard let canvasPoint = imagePoint(
                                from: location,
                                in: geometry.size
                            ) else { return false }
                            presentFigmaLinkImport(
                                canonicalURL: canonicalURL,
                                placementCenter: canvasPoint
                            )
                            return true
                        case .unavailable:
                            return false
                        }
                    },
                    onRichLinkDrop: { htmlData, rtfData, location in
                        guard case let .figmaLink(canonicalURL) =
                            XomoCanvasRichLinkDropPolicy.resolve(
                                htmlData: htmlData,
                                rtfData: rtfData
                            ),
                            let canvasPoint = imagePoint(
                                from: location,
                                in: geometry.size
                            )
                        else { return false }
                        presentFigmaLinkImport(
                            canonicalURL: canonicalURL,
                            placementCenter: canvasPoint
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
                            tool: canvasInteractionTool,
                            isCanvasTextEditing: canvasTextEditingOrigin != nil
                        ),
                        capturesPrimaryPointer: ImageEditorPrimaryToolPointerCapture.usesDirectCanvasHitTarget(
                            sidebarTab: viewModel.selectedLeftSidebarTab,
                            tool: canvasInteractionTool,
                            isCanvasTextEditing: canvasTextEditingOrigin != nil
                        ),
                        claimsKeyboardFocusOnPointerDown: canvasTextEditingOrigin == nil,
                        onCanvasPointerSequenceBegan: {
                            beginCanvasPointerSequence()
                        },
                        onCanvasLifecycleInterrupted: { _ in
                            objectSelectionBoxDrag = nil
                            eyedropperSamplingRing = nil
                            cancelPathAnchorDragForCanvasLifecycle()
                        },
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
                            if canvasInteractionTool == .marquee {
                                let imagePoint = imagePoint(from: location, in: geometry.size)
                                viewModel.updatePointer(imagePoint)
                                dragEnd = boundedImagePoint(from: location, in: geometry.size)
                            } else if canvasInteractionTool == .gradient {
                                let rawGradientPoint = unboundedImagePoint(
                                    from: location,
                                    in: geometry.size
                                )
                                dragEnd = rawGradientPoint
                                viewModel.updatePointer(constrainedGradientEndpoint(rawGradientPoint))
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
                                    to: gradientDragPoint(from: location, in: geometry.size)
                                )
                            }
                            dragStart = nil
                            dragEnd = nil
                            refreshCanvasCursor(in: geometry.size)
                        },
                        onRangeToolDragCancelled: {
                            dragStart = nil
                            dragEnd = nil
                            refreshCanvasCursor(in: geometry.size)
                        },
                        onPrimaryToolDragBegan: { location in
                            guard ImageEditorPrimaryToolPointerCapture.shouldCapture(
                                    sidebarTab: viewModel.selectedLeftSidebarTab,
                                    tool: canvasInteractionTool,
                                    isCanvasTextEditing: canvasTextEditingOrigin != nil
                                  ),
                                  let imagePoint = imagePoint(from: location, in: geometry.size)
                            else { return false }
                            viewModel.canvasPointerCaptureState.activeTool = canvasInteractionTool
                            if canvasInteractionTool == .eraser {
                                isEraserHistoryGestureActive = viewModel.shouldEraseToHistory(
                                    modifierFlags: NSEvent.modifierFlags
                                )
                            }
                            if canvasInteractionTool == .brush {
                                // Let the AppKit host finish installing its
                                // static mouse-up transaction before the
                                // Timeline overlay mutates SwiftUI state.
                                DispatchQueue.main.async {
                                    guard viewModel.canvasPointerCaptureState.activeTool == .brush
                                    else { return }
                                    updatePaintAirbrushStroke(at: imagePoint, pressure: nil)
                                }
                            }
                            // Keep the native NSView as first responder for the
                            // whole brush stroke. Mutating several SwiftUI
                            // states on mouse-down can rebuild the overlay
                            // before mouse-up and strand the responder.
                            if canvasInteractionTool != .brush
                                && canvasInteractionTool != .pencil
                                && canvasInteractionTool != .historyBrush
                                && canvasInteractionTool != .eraser {
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
                            if primaryTool == .brush
                                || primaryTool == .pencil
                                || primaryTool == .historyBrush
                                || primaryTool == .eraser {
                                activeBrushPressure = pressure
                                activeBrushTilt = tilt
                                if primaryTool == .brush {
                                    updatePaintAirbrushStroke(
                                        at: imagePoint,
                                        pressure: pressure
                                    )
                                }
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
                               primaryTool == .brush
                                || primaryTool == .pencil
                                || primaryTool == .historyBrush
                                || primaryTool == .eraser {
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
                            let paintAirbrushPulseSamples = primaryTool == .brush
                                ? finishPaintAirbrushStroke(at: endImagePoint)
                                : []
                            switch primaryTool {
                            case .brush:
                                viewModel.drawBrush(
                                    samples: committedBrushSamples,
                                    airbrushPulseSamples: paintAirbrushPulseSamples
                                )
                            case .pencil:
                                viewModel.drawPencil(samples: committedBrushSamples)
                            case .historyBrush:
                                viewModel.historyBrush(samples: committedBrushSamples)
                            case .eraser:
                                viewModel.eraseBrush(
                                    samples: committedBrushSamples,
                                    restoringHistory: isEraserHistoryGestureActive
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
                                    beginCanvasTextEditing(at: endImagePoint, in: geometry.size)
                                }
                            default:
                                break
                            }
                            brushStrokeSamples = []
                            isEraserHistoryGestureActive = false
                            paintAirbrushStroke.reset()
                            activeBrushPressure = nil
                            activeBrushTilt = nil
                            dragStart = nil
                            dragEnd = nil
                            primaryToolViewStart = nil
                            refreshCanvasCursor(in: geometry.size)
                        },
                        onPrimaryToolDragCancelled: {
                            brushStrokeSamples = []
                            isEraserHistoryGestureActive = false
                            paintAirbrushStroke.reset()
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
                        onLayerResizeCancelled: {
                            _ = viewModel.cancelTransformingSelectedLayer()
                            activeResizeHandle = nil
                            refreshCanvasCursor(in: geometry.size)
                        },
                        onObjectMoveCandidateBegan: { location, modifierFlags, clickCount in
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
                            let isDirectEditingDoubleClick = ImageEditorMoveToolDoubleClickPolicy
                                .shouldBeginDirectEditing(
                                    sidebarTab: viewModel.selectedLeftSidebarTab,
                                    selectedTool: viewModel.selectedTool,
                                    clickCount: clickCount,
                                    modifierFlags: modifierFlags
                                )
                                && viewModel.moveToolDoubleClickTarget(
                                    at: imagePoint,
                                    hitTolerance: canvasTextHitTolerance(in: geometry.size)
                                ) != nil
                            if isDirectEditingDoubleClick {
                                return true
                            }
                            return viewModel.canBeginCanvasObjectMove(at: imagePoint)
                        },
                        onObjectMoveActivated: { location, _ in
                            resetObjectMoveTracking()
                            guard let imagePoint = imagePoint(from: location, in: geometry.size),
                                  viewModel.prepareCanvasObjectMove(at: imagePoint),
                                  viewModel.canMoveSelectedLayer
                            else { return false }
                            guard viewModel.beginMovingSelectedLayer() else { return false }
                            isSelectedObjectMoveGestureActive = true
                            ImageEditorCanvasCursor.objectMoveCursor().set()
                            return true
                        },
                        onObjectMoveClicked: { location, modifierFlags, clickCount in
                            guard let imagePoint = imagePoint(from: location, in: geometry.size) else {
                                return
                            }
                            if ImageEditorMoveToolDoubleClickPolicy.shouldBeginDirectEditing(
                                sidebarTab: viewModel.selectedLeftSidebarTab,
                                selectedTool: viewModel.selectedTool,
                                clickCount: clickCount,
                                modifierFlags: modifierFlags
                            ), let target = viewModel.selectMoveToolDoubleClickTarget(
                                at: imagePoint,
                                hitTolerance: canvasTextHitTolerance(in: geometry.size)
                            ) {
                                if case .editableText = target {
                                    _ = beginEditingSelectedCanvasTextLayer()
                                }
                                return
                            }
                            guard viewModel.moveToolAutoSelectsCanvasTarget else { return }
                            _ = viewModel.selectMovableCanvasTarget(
                                at: imagePoint,
                                extendingSelection: modifierFlags.contains(.shift)
                            )
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
                        },
                        onObjectMoveCancelled: {
                            guard isSelectedObjectMoveGestureActive else { return }
                            _ = viewModel.cancelMovingSelectedLayer()
                            isSelectedObjectMoveGestureActive = false
                            resetObjectMoveTracking()
                            NSCursor.arrow.set()
                        },
                        onLayerChooserRequested: { location in
                            guard canvasInteractionTool == .move,
                                  canvasTextEditingOrigin == nil,
                                  let imagePoint = imagePoint(from: location, in: geometry.size)
                            else { return [] }
                            return viewModel.canvasLayerChoices(at: imagePoint)
                        },
                        onLayerChooserSelected: { layerID in
                            _ = viewModel.selectCanvasLayerChoice(layerID)
                            refreshCanvasCursor(in: geometry.size)
                        }
                    )
                    .allowsHitTesting(
                        ImageEditorPrimaryToolPointerCapture.usesDirectCanvasHitTarget(
                            sidebarTab: viewModel.selectedLeftSidebarTab,
                            tool: canvasInteractionTool,
                            isCanvasTextEditing: canvasTextEditingOrigin != nil
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
                        : (canvasPoint.map(viewModel.moveToolContentHit(at:)) ?? .none)
                    let moveToolHoverSelectionIntent = canvasPoint.flatMap {
                        viewModel.moveToolHoverTarget(
                            at: $0,
                            modifierFlags: canvasModifierFlags
                        )?.selectionIntent
                    } ?? .none
                    let cropHandle = cropInteractionHandle(at: hoverViewPoint, in: geometry.size)
                    let layerTransformTarget = layerTransformCursorTarget(
                        at: hoverViewPoint,
                        in: geometry.size
                    )
                    let penSegmentInsertionState = canvasInteractionTool == .pen
                        ? viewModel.penPathSegmentInsertionState(at: canvasPoint)
                        : .none
                    let penAnchorDeletionState = resolvedPenAnchorDeletionState(at: canvasPoint)
                    let penPathContinuationState = resolvedPenPathContinuationState(at: canvasPoint)
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
                            spongeMode: viewModel.spongeMode,
                            brushTilt: activeBrushTilt,
                            brushTiltControlsShape: viewModel.brushTiltControlsShape,
                            brushTipRoundness: viewModel.brushTipRoundness / 100,
                            brushTipAngleDegrees: viewModel.brushTipAngleDegrees,
                            isPointerOverCanvas: isPointerOverDrawableCanvas,
                            isPointerOverMovableContent: contentHit.isMovable,
                            isPointerOverBlockedContent: contentHit.isBlocked,
                            moveToolUsesBoxSelection: viewModel.moveToolAutoSelectsCanvasTarget,
                            moveToolHoverSelectionIntent: moveToolHoverSelectionIntent,
                            isPointerOverEditableText:
                                canvasInteractionTool == .text
                                    && canvasPoint.map {
                                        viewModel.hasEditableTextLayer(
                                            at: $0,
                                            hitTolerance: canvasTextHitTolerance(in: geometry.size)
                                        )
                                    } == true,
                            isPointerOverColorSamplerPoint:
                                canvasInteractionTool == .colorSampler
                                    && hoverViewPoint.map {
                                        colorSamplerPointID(
                                            at: $0,
                                            in: geometry.size
                                        ) != nil
                                    } == true,
                            paintBucketSeedIsBlocked: canvasInteractionTool == .paintBucket
                                && !viewModel.isPaintBucketSeedAvailable(at: canvasPoint),
                            penIsClosing: canvasInteractionTool == .pen
                                && viewModel.isPenCloseCandidate(at: canvasPoint),
                            penIsConverting: isPenAnchorConversionGestureActive
                                || (canvasInteractionTool == .pen
                                    && canvasModifierFlags.contains(.option)
                                    && viewModel.isPenCornerConversionCandidate(at: canvasPoint)),
                            penConversionIsBlocked: isPenAnchorConversionGestureBlocked
                                || (canvasInteractionTool == .pen
                                    && canvasModifierFlags.contains(.option)
                                    && viewModel.isPenCornerConversionBlocked(at: canvasPoint)),
                            penIsAddingAnchor: penSegmentInsertionState != .none,
                            penAdditionIsBlocked: penSegmentInsertionState == .blocked,
                            penIsDeletingAnchor: penAnchorDeletionState == .available,
                            penAnchorDeletionIsBlocked: penAnchorDeletionState == .blocked,
                            penIsContinuingPath: penPathContinuationState == .available,
                            penContinuationIsBlocked: penPathContinuationState == .blocked,
                            directSelectionIsBlocked: canvasInteractionTool == .directSelection
                                && viewModel.directPathAnchorState(at: canvasPoint) == .blocked,
                            pathSelectionIsBlocked: canvasInteractionTool == .pathSelection
                                && viewModel.pathSelectionTarget(at: canvasPoint)?.isBlocked == true,
                            pathHandleIsBreaking: isBreakingSmoothPathHandle(
                                at: canvasPoint,
                                modifierFlags: canvasModifierFlags
                            ),
                            handIsDragging: isCanvasPanGestureActive,
                            isObjectMoveGestureActive: objectMoveIsActive,
                            isColorSamplerMoveGestureActive: colorSamplerDrag != nil,
                            isSpacebarPanning: isSpacebarPanning,
                            isCanvasPanGestureActive: isCanvasPanGestureActive,
                            isPickingSampledBrushSource: isSettingSampledBrushSourceGesture,
                            isTemporaryEyedropperActive: isTemporaryEyedropperCursorActive,
                            eyedropperTarget: eyedropperCursorTarget,
                            isErasingToHistory: isEraserHistoryCursorActive,
                            patchPhase: patchCursorPhase(at: canvasPoint),
                            patchMode: viewModel.patchMode,
                            patchSelectionMode: viewModel.selectionMode,
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
                        commitCanvasTextEditingIfNeeded()
                    }
                    refreshCanvasCursor(in: geometry.size)
                }
                .onChange(of: viewModel.spongeMode) { _ in
                    refreshCanvasCursor(in: geometry.size)
                }
                .onChange(of: viewModel.patchMode) { _ in
                    refreshActivePatchPreview()
                    refreshCanvasCursor(in: geometry.size)
                }
                .onChange(of: viewModel.patchTransparentEnabled) { _ in
                    refreshActivePatchPreview()
                }
                .onChange(of: viewModel.patchSampleSource) { _ in
                    refreshActivePatchPreview()
                }
                .onChange(of: viewModel.patchIgnoresAdjustmentLayers) { _ in
                    refreshActivePatchPreview()
                }
                .onChange(of: viewModel.patchDiffusion) { _ in
                    refreshActivePatchPreview()
                }
                .onChange(of: viewModel.selectionMode) { _ in
                    refreshCanvasCursor(in: geometry.size)
                }
                .onChange(of: viewModel.selectedLeftSidebarTab) { tab in
                    activeBrushPressure = nil
                    activeBrushTilt = nil
                    _ = cancelPenAnchorConversionGesture()
                    if tab == .components {
                        pendingCropRect = nil
                        endPendingCropInteraction()
                        resetColorSamplerGesture()
                        commitCanvasTextEditingIfNeeded()
                        // Changing sidebar mode must immediately clear the
                        // previous tool cursor, even before the next hover
                        // event arrives from the canvas.
                        XomoComponentLibraryCursorPolicy.restoreArrow(for: .modeActivated)
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
                        XomoComponentLibraryCursorPolicy.restoreArrow(for: .componentSelected)
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
                .onChange(of: canvasModifierFlags) { flags in
                    if let patchRawDragEnd,
                       canvasInteractionTool == .patchTool,
                       !isDrawingPatchSelection {
                        updatePatchDrag(
                            to: patchRawDragEnd,
                            modifierFlags: flags,
                            forcesPreview: true
                        )
                    }
                    refreshCanvasCursor(in: geometry.size)
                }
                .onChange(of: viewModel.isSettingCloneSource) { _ in
                    refreshCanvasCursor(in: geometry.size)
                }
                .onChange(of: viewModel.isSettingHealingSource) { _ in
                    refreshCanvasCursor(in: geometry.size)
                }
                .onChange(of: viewModel.eraserErasesToHistory) { _ in
                    refreshCanvasCursor(in: geometry.size)
                }
                .onChange(of: viewModel.healingBrushMode) { _ in
                    refreshCanvasCursor(in: geometry.size)
                }
                .onChange(of: viewModel.zoom) { _ in
                    refreshCanvasCursor(in: geometry.size)
                }
                .onChange(of: viewModel.selectedTool) { _ in
                    _ = cancelGradientOverlayCanvasHandleDragForLifecycle()
                    objectSelectionBoxDrag = nil
                }
                .onChange(of: viewModel.selectedLeftSidebarTab) { _ in
                    _ = cancelGradientOverlayCanvasHandleDragForLifecycle()
                    objectSelectionBoxDrag = nil
                    eyedropperSamplingRing = nil
                }
                .onChange(of: viewModel.eyedropperShowsSamplingRing) { isVisible in
                    if !isVisible {
                        eyedropperSamplingRing = nil
                    }
                }
                .onDisappear {
                    _ = cancelGradientOverlayCanvasHandleDragForLifecycle()
                    cancelPathAnchorDragForCanvasLifecycle()
                    pendingPenCreationAction = nil
                    resetPenAnchorConversionGesture()
                    penAnchorDeletionGestureState = .none
                    isPointerInsideCanvas = false
                    activeBrushPressure = nil
                    activeBrushTilt = nil
                    isTemporaryEyedropperGestureActive = false
                    eyedropperGestureTarget = nil
                    eyedropperSamplingRing = nil
                    isEraserHistoryGestureActive = false
                    paintAirbrushStroke.reset()
                    isPatchGestureBlocked = false
                    endPendingCropInteraction()
                    resetColorSamplerGesture()
                    objectSelectionBoxDrag = nil
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
                    let pixelBounds = ImageEditorCropGeometry.committedPixelBounds(
                        for: pendingCropRect,
                        canvasSize: viewModel.document.canvasSize
                    )
                    HStack(spacing: 2) {
                        Text(L10n.text("imageEditor.cropBounds.x"))
                            .foregroundStyle(.secondary)
                        TextField(
                            "",
                            value: Binding(
                                get: { Double(pixelBounds.minX) },
                                set: { setPendingCropOrigin(x: CGFloat($0)) }
                            ),
                            format: .number.precision(.fractionLength(0))
                        )
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(width: 44)
                        .accessibilityLabel(L10n.text("imageEditor.cropBounds.xHelp"))
                        .accessibilityIdentifier("image-editor-crop-origin-x")

                        Text(L10n.text("imageEditor.cropBounds.y"))
                            .foregroundStyle(.secondary)
                        TextField(
                            "",
                            value: Binding(
                                get: { Double(pixelBounds.minY) },
                                set: { setPendingCropOrigin(y: CGFloat($0)) }
                            ),
                            format: .number.precision(.fractionLength(0))
                        )
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(width: 44)
                        .accessibilityLabel(L10n.text("imageEditor.cropBounds.yHelp"))
                        .accessibilityIdentifier("image-editor-crop-origin-y")
                    }

                    HStack(spacing: 2) {
                        Text(L10n.text("imageEditor.cropBounds.width"))
                            .foregroundStyle(.secondary)
                        TextField(
                            "",
                            value: Binding(
                                get: { Double(pixelBounds.width) },
                                set: { setPendingCropSize(width: CGFloat($0)) }
                            ),
                            format: .number.precision(.fractionLength(0))
                        )
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(width: 44)
                        .accessibilityLabel(L10n.text("imageEditor.cropBounds.widthHelp"))
                        .accessibilityIdentifier("image-editor-crop-width")

                        Button {
                            isCropAspectRatioLocked.toggle()
                        } label: {
                            Image(systemName: isCropAspectRatioLocked ? "link" : "link.slash")
                                .font(.system(size: 10, weight: .semibold))
                                .frame(width: 18, height: 18)
                        }
                        .buttonStyle(EditorIconButtonStyle(isSelected: isCropAspectRatioLocked))
                        .focusable(false)
                        .help(L10n.text(
                            isCropAspectRatioLocked
                                ? "imageEditor.cropBounds.aspectUnlock"
                                : "imageEditor.cropBounds.aspectLock"
                        ))
                        .accessibilityIdentifier("image-editor-crop-aspect-ratio-lock")

                        Text(L10n.text("imageEditor.cropBounds.height"))
                            .foregroundStyle(.secondary)
                        TextField(
                            "",
                            value: Binding(
                                get: { Double(pixelBounds.height) },
                                set: { setPendingCropSize(height: CGFloat($0)) }
                            ),
                            format: .number.precision(.fractionLength(0))
                        )
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(width: 44)
                        .accessibilityLabel(L10n.text("imageEditor.cropBounds.heightHelp"))
                        .accessibilityIdentifier("image-editor-crop-height")

                        Button {
                            swapPendingCropOrientation()
                        } label: {
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.system(size: 10, weight: .semibold))
                                .frame(width: 18, height: 18)
                        }
                        .buttonStyle(EditorIconButtonStyle(isSelected: false))
                        .focusable(false)
                        .disabled(pixelBounds.width == pixelBounds.height)
                        .help(L10n.text("imageEditor.cropBounds.swapHelp"))
                        .accessibilityIdentifier("image-editor-crop-swap-dimensions")
                    }

                    Picker(
                        L10n.text("imageEditor.cropGuide.title"),
                        selection: $cropGuideKind
                    ) {
                        ForEach(ImageEditorCropGuideKind.allCases) { kind in
                            Text(L10n.text(kind.titleKey)).tag(kind)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 126)
                    .focusable(false)
                    .help(L10n.text("imageEditor.cropGuide.help"))
                    .accessibilityIdentifier("image-editor-crop-guide-picker")

                    Menu {
                        ForEach(ImageEditorCropAspectPreset.allCases) { preset in
                            Button {
                                applyCropAspectPreset(preset)
                            } label: {
                                Text(L10n.text(preset.titleKey))
                            }
                            .accessibilityIdentifier(preset.accessibilityIdentifier)
                        }
                    } label: {
                        Image(systemName: "aspectratio")
                            .frame(width: 24, height: 24)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .focusable(false)
                    .help(L10n.text("imageEditor.cropAspect.help"))
                    .accessibilityIdentifier("image-editor-crop-aspect-menu")

                    Button {
                        showsCroppedArea.toggle()
                    } label: {
                        Image(systemName: showsCroppedArea ? "eye" : "eye.slash")
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(EditorIconButtonStyle(isSelected: showsCroppedArea))
                    .focusable(false)
                    .help(L10n.text("imageEditor.cropBounds.croppedAreaHelp"))
                    .accessibilityLabel(L10n.text("imageEditor.cropBounds.croppedAreaHelp"))
                    .accessibilityIdentifier("image-editor-crop-outside-area-toggle")

                    Button {
                        resetPendingCropToCanvas()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(EditorIconButtonStyle(isSelected: false))
                    .focusable(false)
                    .disabled(pixelBounds == ImageEditorCropGeometry.fullCanvasFrame(
                        canvasSize: viewModel.document.canvasSize
                    ))
                    .help(L10n.text("imageEditor.cropBounds.resetHelp"))
                    .accessibilityIdentifier("image-editor-crop-reset")

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

    private func setPendingCropOrigin(x: CGFloat? = nil, y: CGFloat? = nil) {
        guard let pendingCropRect else { return }
        let currentBounds = ImageEditorCropGeometry.committedPixelBounds(
            for: pendingCropRect,
            canvasSize: viewModel.document.canvasSize
        )
        self.pendingCropRect = ImageEditorCropGeometry.frameBySettingCommittedOrigin(
            of: pendingCropRect,
            to: CGPoint(
                x: x ?? currentBounds.minX,
                y: y ?? currentBounds.minY
            ),
            canvasSize: viewModel.document.canvasSize
        )
    }

    private func setPendingCropSize(width: CGFloat? = nil, height: CGFloat? = nil) {
        guard let pendingCropRect,
              let dimension = width.map({ (ImageEditorCropSizeDimension.width, $0) })
                ?? height.map({ (ImageEditorCropSizeDimension.height, $0) })
        else { return }
        self.pendingCropRect = ImageEditorCropGeometry.frameBySettingCommittedDimension(
            of: pendingCropRect,
            dimension: dimension.0,
            value: dimension.1,
            canvasSize: viewModel.document.canvasSize,
            preservesAspectRatio: isCropAspectRatioLocked
        )
    }

    private func applyCropAspectPreset(_ preset: ImageEditorCropAspectPreset) {
        guard let pendingCropRect else { return }
        guard let components = preset.components(canvasSize: viewModel.document.canvasSize) else {
            isCropAspectRatioLocked = false
            return
        }
        self.pendingCropRect = ImageEditorCropGeometry.frameByApplyingAspectRatio(
            of: pendingCropRect,
            components: components,
            canvasSize: viewModel.document.canvasSize
        )
        isCropAspectRatioLocked = true
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
        if !viewModel.pendingPenPathAnchors.isEmpty || pendingPenCreationAction != nil {
            let anchors = viewModel.pendingPenPathAnchors.map { anchor in
                ImageEditorPathAnchor(
                    point: viewPoint(from: anchor.point, in: size),
                    inControl: anchor.inControl.map { viewPoint(from: $0, in: size) },
                    outControl: anchor.outControl.map { viewPoint(from: $0, in: size) }
                )
            }
            let activeAnchor = pendingPenCreationAction.map { action in
                let controls = action.symmetricControlDrag.flatMap {
                    ImageEditorPenPointGeometry.symmetricControls(
                        anchor: action.anchorPoint,
                        drag: $0,
                        canvasSize: viewModel.document.canvasSize
                    )
                }
                return ImageEditorPathAnchor(
                    point: viewPoint(from: action.anchorPoint, in: size),
                    inControl: controls.map { viewPoint(from: $0.inControl, in: size) },
                    outControl: controls.map { viewPoint(from: $0.outControl, in: size) }
                )
            }
            let previewPoint = pendingPenPreviewViewPoint(in: size)
            Canvas { context, _ in
                if let first = anchors.first {
                    var path = Path()
                    path.move(to: first.point)
                    for index in anchors.indices.dropFirst() {
                        let previous = anchors[index - 1]
                        let current = anchors[index]
                        if previous.outControl != nil || current.inControl != nil {
                            path.addCurve(
                                to: current.point,
                                control1: previous.outControl ?? previous.point,
                                control2: current.inControl ?? current.point
                            )
                        } else {
                            path.addLine(to: current.point)
                        }
                    }
                    context.stroke(path, with: .color(Color.white.opacity(0.88)), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    context.stroke(path, with: .color(Color(nsColor: ImageEditorTheme.selected).opacity(0.95)), style: StrokeStyle(lineWidth: 2, dash: [6, 4], dashPhase: 5))
                }

                let displayedAnchors = anchors + [activeAnchor].compactMap { $0 }
                for (index, anchor) in displayedAnchors.enumerated() {
                    for handle in [anchor.inControl, anchor.outControl].compactMap({ $0 }) {
                        var handleLine = Path()
                        handleLine.move(to: anchor.point)
                        handleLine.addLine(to: handle)
                        context.stroke(handleLine, with: .color(Color.white.opacity(0.68)), lineWidth: 1)
                        let handleRect = CGRect(x: handle.x - 3.5, y: handle.y - 3.5, width: 7, height: 7)
                        context.fill(Path(handleRect), with: .color(Color(nsColor: ImageEditorTheme.selected).opacity(0.82)))
                        context.stroke(Path(handleRect), with: .color(Color.white.opacity(0.9)), lineWidth: 1)
                    }
                    let radius: CGFloat = index == 0 ? 5 : 4
                    let rect = CGRect(x: anchor.point.x - radius, y: anchor.point.y - radius, width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(index == 0 ? Color.white : Color(nsColor: ImageEditorTheme.selected)))
                    context.stroke(Path(ellipseIn: rect), with: .color(Color.black.opacity(0.45)), lineWidth: 1)
                }

                if let last = anchors.last, let activeAnchor {
                    var previewPath = Path()
                    previewPath.move(to: last.point)
                    previewPath.addCurve(
                        to: activeAnchor.point,
                        control1: last.outControl ?? last.point,
                        control2: activeAnchor.inControl ?? activeAnchor.point
                    )
                    context.stroke(
                        previewPath,
                        with: .color(Color.white.opacity(0.82)),
                        style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                    )
                } else if let last = anchors.last, let previewPoint {
                    var previewPath = Path()
                    previewPath.move(to: last.point)
                    if let outControl = last.outControl {
                        previewPath.addCurve(
                            to: previewPoint,
                            control1: outControl,
                            control2: previewPoint
                        )
                    } else {
                        previewPath.addLine(to: previewPoint)
                    }
                    context.stroke(
                        previewPath,
                        with: .color(Color.white.opacity(0.82)),
                        style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                    )
                    let radius: CGFloat = 3.5
                    let previewRect = CGRect(
                        x: previewPoint.x - radius,
                        y: previewPoint.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                    context.fill(
                        Path(ellipseIn: previewRect),
                        with: .color(Color(nsColor: ImageEditorTheme.selected).opacity(0.72))
                    )
                    context.stroke(
                        Path(ellipseIn: previewRect),
                        with: .color(Color.white.opacity(0.92)),
                        lineWidth: 1
                    )
                }
            }
            .allowsHitTesting(false)
        }

        if !isPenAnchorConversionGestureBlocked,
           let action = penAnchorConversionAction,
           let drag = action.symmetricControlDrag,
           let controls = ImageEditorPenPointGeometry.symmetricControls(
            anchor: action.anchorPoint,
            drag: drag,
            canvasSize: viewModel.document.canvasSize
           ) {
            let anchor = viewPoint(from: action.anchorPoint, in: size)
            let inControl = viewPoint(from: controls.inControl, in: size)
            let outControl = viewPoint(from: controls.outControl, in: size)
            Canvas { context, _ in
                var handleLine = Path()
                handleLine.move(to: inControl)
                handleLine.addLine(to: outControl)
                context.stroke(handleLine, with: .color(Color.white.opacity(0.9)), lineWidth: 3)
                context.stroke(handleLine, with: .color(Color.orange.opacity(0.95)), lineWidth: 1.25)
                for handle in [inControl, outControl] {
                    let rect = CGRect(x: handle.x - 4, y: handle.y - 4, width: 8, height: 8)
                    context.fill(Path(rect), with: .color(Color.orange.opacity(0.92)))
                    context.stroke(Path(rect), with: .color(Color.white.opacity(0.95)), lineWidth: 1)
                }
                let anchorRect = CGRect(x: anchor.x - 4.5, y: anchor.y - 4.5, width: 9, height: 9)
                context.fill(Path(ellipseIn: anchorRect), with: .color(Color.white.opacity(0.96)))
                context.stroke(Path(ellipseIn: anchorRect), with: .color(Color.orange), lineWidth: 1.5)
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
            let displayedDragEnd = canvasInteractionTool == .gradient
                ? constrainedGradientEndpoint(dragEnd)
                : dragEnd
            let end = viewPoint(from: displayedDragEnd, in: size)
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
            let cropShieldRects = ImageEditorCropGeometry.shieldRects(
                in: fittedImageRect(in: size),
                excluding: rect
            )
            let cropGuideSegments = ImageEditorCropGeometry.compositionGuideSegments(
                for: cropGuideKind,
                in: CGRect(origin: .zero, size: rect.size)
            )
            Path { path in
                for shieldRect in cropShieldRects {
                    path.addRect(shieldRect)
                }
            }
            .fill(
                showsCroppedArea
                    ? Color.black.opacity(0.48)
                    : Color(nsColor: ImageEditorTheme.window)
            )
            .allowsHitTesting(false)
            ZStack {
                Rectangle()
                    .stroke(Color(nsColor: ImageEditorTheme.selected), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .background(Rectangle().fill(Color(nsColor: ImageEditorTheme.selected).opacity(0.10)))
                    .frame(width: rect.width, height: rect.height)
                Path { path in
                    for segment in cropGuideSegments {
                        path.move(to: segment.start)
                        path.addLine(to: segment.end)
                    }
                }
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
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

    private func pendingPenPreviewViewPoint(in size: CGSize) -> CGPoint? {
        guard canvasInteractionTool == .pen,
              isPointerInsideCanvas,
              let hoverViewPoint,
              let pointerImagePoint = imagePoint(from: hoverViewPoint, in: size),
              let previewImagePoint = viewModel.pendingPenPreviewPoint(
                at: pointerImagePoint,
                constrainedToAngleIncrement: canvasModifierFlags.contains(.shift)
              )
        else { return nil }
        return viewPoint(from: previewImagePoint, in: size)
    }

    private var shouldShowDragRect: Bool {
        switch canvasInteractionTool {
        case .crop, .marquee, .rectangle, .ellipse, .text:
            true
        default:
            false
        }
    }

    private func sampleEyedropperColor(
        at canvasPoint: CGPoint,
        target: ImageEditorColorSampleTarget
    ) {
        let foregroundBeforeSampling = viewModel.foregroundColor
        let backgroundBeforeSampling = viewModel.backgroundColor
        let existingRing = eyedropperSamplingRing
        guard let sampledColor = viewModel.sampleColor(
            at: canvasPoint,
            target: target
        ) else {
            eyedropperSamplingRing = nil
            return
        }
        guard viewModel.eyedropperShowsSamplingRing else {
            eyedropperSamplingRing = nil
            return
        }
        if let existingRing, existingRing.target == target {
            eyedropperSamplingRing = existingRing.updating(
                sampledColor: sampledColor,
                at: canvasPoint
            )
        } else {
            eyedropperSamplingRing = ImageEditorEyedropperSamplingRingState.begin(
                at: canvasPoint,
                target: target,
                foregroundColor: foregroundBeforeSampling,
                backgroundColor: backgroundBeforeSampling,
                sampledColor: sampledColor
            )
        }
    }

    @ViewBuilder
    private func eyedropperSamplingRingOverlay(in size: CGSize) -> some View {
        if viewModel.eyedropperShowsSamplingRing,
           let eyedropperSamplingRing {
            let pointer = viewPoint(from: eyedropperSamplingRing.canvasPoint, in: size)
            let center = ImageEditorEyedropperSamplingRingGeometry.center(
                pointer: pointer,
                viewportSize: size
            )
            let diameter = ImageEditorEyedropperSamplingRingGeometry.diameter
            ZStack {
                Circle()
                    .fill(Color(nsColor: ImageEditorTheme.panelRaised))
                HStack(spacing: 0) {
                    Color(nsColor: eyedropperSamplingRing.sampledColor)
                    Color(nsColor: eyedropperSamplingRing.originalColor)
                }
                .frame(width: diameter, height: diameter)
                .clipShape(Circle())
                Rectangle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 1, height: diameter - 8)
                Circle()
                    .stroke(Color.black.opacity(0.86), lineWidth: 4)
                Circle()
                    .stroke(Color.white.opacity(0.96), lineWidth: 1)
                    .padding(1.5)
            }
            .frame(width: diameter, height: diameter)
            .position(center)
            .shadow(color: .black.opacity(0.72), radius: 3, x: 0, y: 2)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
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
    private func cloneStampPixelOverlay(in size: CGSize) -> some View {
        if canvasInteractionTool == .cloneStamp,
           isPointerInsideCanvas,
           !isSettingSampledBrushSourceGesture,
           let hoverViewPoint,
           let hoverCanvasPoint = imagePoint(from: hoverViewPoint, in: size),
           let preview = viewModel.cloneStampOverlayPreview(
               destinationReference: dragPoints.first ?? hoverCanvasPoint,
               isPainting: !dragPoints.isEmpty,
               brushCenter: dragPoints.last ?? hoverCanvasPoint,
               brushDiameter: sampledBrushOverlayGeometry?.destinationDiameter
                   ?? viewModel.brushSize
           ) {
            let imageRect = fittedImageRect(in: size)
            let xScale = imageRect.width / max(1, viewModel.document.canvasSize.width)
            let yScale = imageRect.height / max(1, viewModel.document.canvasSize.height)
            let destinationViewPoint = viewPoint(
                from: preview.geometry.destinationReference,
                in: size
            )
            let sourceFrame = imageRect.offsetBy(
                dx: -preview.geometry.canvasOffset.width * xScale,
                dy: -preview.geometry.canvasOffset.height * yScale
            )
            let targetFrame = viewRect(from: preview.geometry.targetFrame, in: size)
            Canvas { context, _ in
                context.clip(to: Path(targetFrame))
                if let brushClip = preview.brushClip {
                    context.clip(to: Path(
                        ellipseIn: viewRect(from: brushClip.canvasRect, in: size)
                    ))
                }
                context.opacity = Double(preview.opacity)
                if preview.invertsColors {
                    context.addFilter(.colorInvert(1))
                }
                context.translateBy(
                    x: destinationViewPoint.x,
                    y: destinationViewPoint.y
                )
                context.rotate(by: .degrees(Double(preview.geometry.rotationDegrees)))
                context.scaleBy(
                    x: preview.geometry.horizontalScale
                        * (preview.geometry.flipsHorizontally ? -1 : 1),
                    y: preview.geometry.verticalScale
                        * (preview.geometry.flipsVertically ? -1 : 1)
                )
                context.translateBy(
                    x: -destinationViewPoint.x,
                    y: -destinationViewPoint.y
                )
                context.draw(Image(nsImage: preview.sourceCanvas), in: sourceFrame)
            }
            .blendMode(preview.blendMode.canvasBlendMode)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func sampledBrushSourceOverlay(in size: CGSize) -> some View {
        if let geometry = sampledBrushOverlayGeometry {
            let imageRect = fittedImageRect(in: size)
            let viewScale = imageRect.width / max(1, viewModel.document.canvasSize.width)
            let sourcePoint = viewPoint(from: geometry.sourcePoint, in: size)
            let sourceWidth = max(1, geometry.diameter * viewScale)
            let sourceHeight = max(1, (geometry.sourceHeight ?? geometry.diameter) * viewScale)
            ZStack {
                if let connector = geometry.connector {
                    let start = viewPoint(from: connector.start, in: size)
                    let end = viewPoint(from: connector.end, in: size)
                    Path { path in
                        path.move(to: start)
                        path.addLine(to: end)
                    }
                    .stroke(
                        Color.black.opacity(0.72),
                        style: StrokeStyle(lineWidth: 3, dash: [5, 4])
                    )
                    Path { path in
                        path.move(to: start)
                        path.addLine(to: end)
                    }
                    .stroke(
                        Color.white.opacity(0.9),
                        style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                    )
                }
                Ellipse()
                    .stroke(Color.white.opacity(0.92), lineWidth: 1)
                    .frame(width: sourceWidth, height: sourceHeight)
                    .position(sourcePoint)
                Rectangle()
                    .fill(Color.white.opacity(0.92))
                    .frame(width: 1, height: max(5, min(sourceHeight / 2, 12)))
                    .offset(y: -max(3, min(sourceHeight / 4, 6)))
                    .rotationEffect(.degrees(Double(geometry.sourceRotationDegrees)))
                    .position(sourcePoint)
                Rectangle()
                    .fill(Color.white.opacity(0.92))
                    .frame(width: 11, height: 1)
                    .position(sourcePoint)
                Rectangle()
                    .fill(Color.white.opacity(0.92))
                    .frame(width: 1, height: 11)
                    .position(sourcePoint)
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .shadow(color: .black.opacity(0.85), radius: 1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private func updatePaintAirbrushStroke(at point: CGPoint, pressure: CGFloat?) {
        guard viewModel.paintAirbrushEnabled else {
            paintAirbrushStroke.reset()
            return
        }
        let time = Date.timeIntervalSinceReferenceDate
        if paintAirbrushStroke.isActive {
            paintAirbrushStroke.update(to: point, pressure: pressure, time: time)
        } else {
            paintAirbrushStroke.begin(at: point, pressure: pressure, time: time)
        }
    }

    private func finishPaintAirbrushStroke(
        at point: CGPoint?
    ) -> [ImageEditorBrushStrokeSample] {
        guard viewModel.paintAirbrushEnabled,
              paintAirbrushStroke.isActive,
              let finalPoint = point ?? paintAirbrushStroke.currentPoint
        else {
            paintAirbrushStroke.reset()
            return []
        }
        return paintAirbrushStroke.finishSamples(
            at: finalPoint,
            pressure: paintAirbrushStroke.currentPressure,
            time: Date.timeIntervalSinceReferenceDate
        )
    }

    @ViewBuilder
    private func paintAirbrushOverlay(in size: CGSize) -> some View {
        if viewModel.paintAirbrushEnabled,
           canvasInteractionTool == .brush,
           let imagePoint = paintAirbrushStroke.currentPoint,
           let dwellBeganAt = paintAirbrushStroke.currentDwellBeganAt {
            let imageRect = fittedImageRect(in: size)
            let pressureScale = viewModel.brushPressureControlsSize
                ? ImageEditorBrushStrokeKernel.pressureDiameterScale(
                    mappedPressure: ImageEditorBrushStrokeKernel.mappedPressure(
                        paintAirbrushStroke.currentPressure ?? 1,
                        sensitivity: viewModel.brushPressureSensitivity / 100
                    ),
                    minimumDiameter: viewModel.brushMinimumDiameter / 100
                )
                : 1
            ImageEditorPaintAirbrushPreview(
                color: viewModel.foregroundColor,
                point: viewPoint(from: imagePoint, in: size),
                dwellBeganAt: dwellBeganAt,
                opacity: viewModel.opacity,
                flow: viewModel.brushFlow / 100,
                diameter: max(
                    4,
                    viewModel.brushSize * pressureScale * imageRect.width
                        / max(1, viewModel.document.canvasSize.width)
                ),
                roundness: viewModel.brushTipRoundness / 100,
                angleDegrees: viewModel.brushTipAngleDegrees
            )
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

    private var sampledBrushOverlayGeometry: ImageEditorSampledBrushOverlayGeometry? {
        let sourcePoint: CGPoint?
        switch canvasInteractionTool {
        case .cloneStamp:
            sourcePoint = viewModel.cloneSourcePoint
        case .healingBrush:
            guard viewModel.healingBrushMode == .source else { return nil }
            sourcePoint = viewModel.healingSourcePoint
        default:
            return nil
        }

        guard let sourcePoint else { return nil }
        let strokeStart = dragPoints.first
        let currentDestination = dragPoints.last
        let liveSourcePoint: CGPoint?
        if let strokeStart, let currentDestination {
            liveSourcePoint = viewModel.sampledBrushPreviewSourcePoint(
                for: canvasInteractionTool,
                strokeStart: strokeStart,
                currentDestination: currentDestination
            )
        } else {
            liveSourcePoint = nil
        }
        return ImageEditorSampledBrushOverlayGeometry.resolve(
            sourcePoint: sourcePoint,
            liveSourcePoint: liveSourcePoint,
            currentDestination: currentDestination,
            isPickingSource: isSettingSampledBrushSourceGesture,
            brushDiameter: viewModel.brushSize,
            horizontalSourceScale: canvasInteractionTool == .cloneStamp
                ? viewModel.cloneSourceHorizontalScalePercent / 100
                : 1,
            verticalSourceScale: canvasInteractionTool == .cloneStamp
                ? viewModel.cloneSourceVerticalScalePercent / 100
                : 1,
            sourceRotationDegrees: canvasInteractionTool == .cloneStamp
                ? viewModel.cloneSourceRotationDegrees
                : 0,
            pressure: brushStrokeSamples.last?.pressure,
            pressureControlsSize: viewModel.retouchPressureControlsSize,
            pressureSensitivity: viewModel.retouchPressureSensitivity / 100
        )
    }

    private var isSettingSampledBrushSourceGesture: Bool {
        ImageEditorSampledBrushCursorPolicy.isPickingSource(
            tool: canvasInteractionTool,
            healingMode: viewModel.healingBrushMode,
            isSettingCloneSource: viewModel.isSettingCloneSource,
            isSettingHealingSource: viewModel.isSettingHealingSource,
            modifierFlags: canvasModifierFlags
        )
    }

    private var isTemporaryEyedropperCursorActive: Bool {
        isTemporaryEyedropperGestureActive
            || ImageEditorTemporaryEyedropperPolicy.isActive(
                tool: canvasInteractionTool,
                modifierFlags: canvasModifierFlags
            )
    }

    private var eyedropperCursorTarget: ImageEditorColorSampleTarget {
        ImageEditorEyedropperTargetPolicy.target(
            tool: canvasInteractionTool,
            modifierFlags: canvasModifierFlags,
            latchedTarget: eyedropperGestureTarget
        )
    }

    private func patchCursorPhase(at canvasPoint: CGPoint?) -> ImageEditorPatchCursorPhase {
        guard canvasInteractionTool == .patchTool else { return .drawingSelection }
        return ImageEditorPatchCursorPhase.resolve(
            isPointerOverSelection: viewModel.canBeginPatch(at: canvasPoint),
            isDrawingSelection: isDrawingPatchSelection,
            isDraggingSelection: dragStart != nil && !isDrawingPatchSelection,
            canEditSelectionPixels: viewModel.canEditSelectionPixels,
            isBlockedGestureActive: isPatchGestureBlocked
        )
    }

    private func canvasGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if isPathAnchorDragCancelled {
                    return
                }
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

                if ImageEditorTemporaryEyedropperPolicy.ownsPointerSequence(
                    tool: canvasInteractionTool,
                    modifierFlags: NSEvent.modifierFlags,
                    isGestureActive: isTemporaryEyedropperGestureActive,
                    hasPaintSamples: !brushStrokeSamples.isEmpty
                ) {
                    isTemporaryEyedropperGestureActive = true
                    activeBrushPressure = nil
                    activeBrushTilt = nil
                    if let pointerImagePoint {
                        sampleEyedropperColor(
                            at: pointerImagePoint,
                            target: .foreground
                        )
                    }
                    updateCanvasCursor(at: value.location, in: size)
                    return
                }

                if canvasInteractionTool == .eyedropper {
                    if eyedropperGestureTarget == nil {
                        eyedropperGestureTarget = ImageEditorEyedropperTargetPolicy.target(
                            tool: canvasInteractionTool,
                            modifierFlags: NSEvent.modifierFlags
                        )
                        updateCanvasCursor(at: value.location, in: size)
                    }
                    if let pointerImagePoint,
                       let eyedropperGestureTarget {
                        sampleEyedropperColor(
                            at: pointerImagePoint,
                            target: eyedropperGestureTarget
                        )
                    }
                }

                switch canvasInteractionTool {
                case .move:
                    if var selectionBoxDrag = objectSelectionBoxDrag {
                        selectionBoxDrag.endCanvasPoint = boundedImagePoint(
                            from: value.location,
                            in: size
                        )
                        selectionBoxDrag.viewTranslation = value.translation
                        objectSelectionBoxDrag = selectionBoxDrag
                        break
                    }
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
                    if isCanvasCloneGestureActive {
                        if isObjectMoveGestureActive {
                            updateObjectMove(translation: value.translation, in: size)
                        }
                        break
                    }
                    let cloneDragDecision = ImageEditorObjectDragEventPolicy.cloneDragDecision(
                        modifierFlags: NSEvent.modifierFlags,
                        from: value.startLocation,
                        to: value.location
                    )
                    let cloneStartImagePoint = imagePoint(from: value.startLocation, in: size)
                    let boxSelectionOwnsModifiedBlankDrag = viewModel.moveToolAutoSelectsCanvasTarget
                        && cloneStartImagePoint.map(viewModel.moveToolContentHit(at:)) == .some(.none)
                    if cloneDragDecision != .unavailable,
                       !boxSelectionOwnsModifiedBlankDrag,
                       !isCanvasSelectionGestureActive,
                       !isObjectMoveGestureActive {
                        if cloneDragDecision == .activate,
                           let pressedImagePoint = imagePoint(from: value.startLocation, in: size),
                           viewModel.prepareCanvasCloneMove(at: pressedImagePoint) {
                            isCanvasCloneGestureActive = true
                            if viewModel.beginDuplicatingSelectedLayerForMove() {
                                resetObjectMoveTracking()
                                isObjectMoveGestureActive = true
                                updateObjectMove(translation: value.translation, in: size)
                            }
                        }
                        // Option owns the whole pointer sequence while it is
                        // waiting for the drag threshold. Falling through here
                        // would start an ordinary move and prevent cloning.
                        break
                    }
                    if let extendsDeepSelection = ImageEditorObjectDragEventPolicy
                        .deepSelectionExtendsSelection(
                            modifierFlags: NSEvent.modifierFlags
                        ),
                       !isCanvasSelectionGestureActive,
                       !isObjectMoveGestureActive {
                        let pressedImagePoint = imagePoint(from: value.startLocation, in: size)
                        if let pressedImagePoint,
                           viewModel.selectDeepestVisibleLayer(
                            at: pressedImagePoint,
                            extendingSelection: extendsDeepSelection
                           ) {
                            // Command-click is a deep-selection gesture, not
                            // a move. Keep the selected child stable until end.
                            isCanvasSelectionGestureActive = true
                        }
                    }
                    if isCanvasSelectionGestureActive {
                        break
                    }
                    if viewModel.moveToolAutoSelectsCanvasTarget,
                       NSEvent.modifierFlags.contains(.shift),
                       !isCanvasSelectionGestureActive,
                       !isObjectMoveGestureActive {
                        let pressedImagePoint = imagePoint(from: value.startLocation, in: size)
                        if let pressedImagePoint,
                           viewModel.selectMovableCanvasTarget(
                            at: pressedImagePoint,
                            extendingSelection: true
                           ) {
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
                        if let pressedImagePoint,
                           viewModel.moveToolAutoSelectsCanvasTarget,
                           viewModel.moveToolContentHit(at: pressedImagePoint) == .none {
                            objectSelectionBoxDrag = ImageEditorObjectSelectionBoxDrag(
                                startCanvasPoint: pressedImagePoint,
                                endCanvasPoint: boundedImagePoint(from: value.location, in: size),
                                viewTranslation: value.translation,
                                mode: ImageEditorObjectBoxSelectionMode.resolve(
                                    modifierFlags: NSEvent.modifierFlags
                                ),
                                scope: ImageEditorObjectBoxSelectionScope.resolve(
                                    sidebarTab: viewModel.selectedLeftSidebarTab,
                                    modifierFlags: NSEvent.modifierFlags
                                ),
                                inclusion: viewModel.moveToolBoxSelectionInclusion
                            )
                            break
                        }
                        guard let pressedImagePoint else {
                            isCanvasPanGestureActive = true
                            updateCanvasPan(translation: value.translation)
                            NSCursor.closedHand.set()
                            return
                        }
                        guard viewModel.prepareCanvasFallbackMove(at: pressedImagePoint) else {
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
                case .brush, .pencil, .historyBrush, .eraser, .sponge:
                    if let pointerImagePoint {
                        if canvasInteractionTool == .eraser,
                           brushStrokeSamples.isEmpty {
                            isEraserHistoryGestureActive = viewModel.shouldEraseToHistory(
                                modifierFlags: canvasModifierFlags
                            )
                        }
                        activeBrushPressure = eventPressure
                        activeBrushTilt = stylusInput.tilt
                        brushStrokeSamples.append(ImageEditorBrushStrokeSample(
                            point: pointerImagePoint,
                            pressure: eventPressure,
                            tilt: stylusInput.tilt
                        ))
                        if canvasInteractionTool == .brush {
                            updatePaintAirbrushStroke(
                                at: pointerImagePoint,
                                pressure: eventPressure
                            )
                        }
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
                case .crop, .rectangle, .ellipse:
                    if canvasInteractionTool == .crop, dragStart == nil {
                        pendingCropRect = nil
                    }
                    if dragStart == nil {
                        dragStart = pointerImagePoint
                    }
                    dragEnd = pointerImagePoint
                case .gradient:
                    if dragStart == nil {
                        dragStart = imagePoint(from: value.startLocation, in: size)
                    }
                    if dragStart != nil {
                        let rawGradientPoint = unboundedImagePoint(from: value.location, in: size)
                        dragEnd = rawGradientPoint
                        viewModel.updatePointer(constrainedGradientEndpoint(rawGradientPoint))
                    }
                case .text:
                    if dragStart == nil {
                        dragStart = imagePoint(from: value.startLocation, in: size)
                    }
                    if dragStart != nil {
                        dragEnd = boundedImagePoint(from: value.location, in: size)
                    }
                case .patchTool:
                    let boundedPoint = boundedImagePoint(from: value.location, in: size)
                    if dragStart == nil, dragPoints.isEmpty, !isPatchGestureBlocked {
                        let startImagePoint = imagePoint(from: value.startLocation, in: size)
                        switch ImageEditorPatchGestureStartAction.resolve(
                            isPointerOverSelection: viewModel.canBeginPatch(at: startImagePoint),
                            canEditSelectionPixels: viewModel.canEditSelectionPixels,
                            selectionMode: viewModel.selectionMode
                        ) {
                        case .dragSelection:
                            dragStart = startImagePoint
                            patchRawDragEnd = pointerImagePoint
                            patchDragConstraintAxis = nil
                            if let pointerImagePoint {
                                updatePatchDrag(
                                    to: pointerImagePoint,
                                    modifierFlags: NSEvent.modifierFlags,
                                    forcesPreview: true
                                )
                            }
                            isDrawingPatchSelection = false
                        case .drawSelection:
                            patchRawDragEnd = nil
                            patchDragConstraintAxis = nil
                            isDrawingPatchSelection = true
                            dragPoints = [boundedPoint]
                        case .blocked:
                            patchRawDragEnd = nil
                            patchDragConstraintAxis = nil
                            isDrawingPatchSelection = false
                            isPatchGestureBlocked = true
                        }
                    }
                    if isDrawingPatchSelection {
                        dragPoints.append(boundedPoint)
                    } else if dragStart != nil, let pointerImagePoint {
                        updatePatchDrag(
                            to: pointerImagePoint,
                            modifierFlags: NSEvent.modifierFlags
                        )
                    }
                    updateCanvasCursor(at: value.location, in: size)
                case .pen:
                    if isPenAnchorConversionGestureActive {
                        if let anchorPoint = penAnchorConversionAction?.anchorPoint {
                            penAnchorConversionAction = ImageEditorPenAnchorConversionGesturePolicy.resolve(
                                anchorPoint: anchorPoint,
                                pointerEnd: unboundedImagePoint(from: value.location, in: size),
                                viewTranslation: value.translation
                            )
                            updateCanvasCursor(at: value.location, in: size)
                        }
                    } else if pendingPenCreationAction == nil,
                              !isMovingPathAnchor,
                              NSEvent.modifierFlags.contains(.option),
                              let pointerStart = imagePoint(from: value.startLocation, in: size),
                              let target = viewModel.penAnchorConversionTarget(at: pointerStart) {
                        isPenAnchorConversionGestureActive = true
                        penAnchorConversionTarget = target
                        isPenAnchorConversionGestureBlocked = target.isBlocked
                        penAnchorConversionAction = ImageEditorPenAnchorConversionGesturePolicy.resolve(
                            anchorPoint: target.anchorPoint,
                            pointerEnd: unboundedImagePoint(from: value.location, in: size),
                            viewTranslation: value.translation
                        )
                        updateCanvasCursor(at: value.location, in: size)
                    } else if isMovingPathAnchor {
                        if penAnchorDeletionGestureState == .available,
                           !ImageEditorPenAnchorAutoDeletePolicy.shouldDelete(
                            viewTranslation: value.translation
                           ) {
                            penAnchorDeletionGestureState = .selectionOnly
                        }
                        if penAnchorDeletionGestureState != .blocked {
                            viewModel.moveSelectedPathAnchor(
                                to: pointerImagePoint,
                                constrainedToAngleIncrement: ImageEditorPathAnchorDragConstraint
                                    .shouldConstrain(
                                        modifierFlags: NSEvent.modifierFlags,
                                        viewTranslation: value.translation
                                    ),
                                preservingSmoothness: !NSEvent.modifierFlags.contains(.option)
                            )
                        }
                        updateCanvasCursor(at: value.location, in: size)
                    } else if pendingPenCreationAction == nil,
                              viewModel.pendingPenPathPoints.isEmpty,
                              let pointerStart = imagePoint(from: value.startLocation, in: size),
                              viewModel.penPathContinuationState(at: pointerStart) != .none {
                        penPathContinuationGestureState = viewModel.penPathContinuationState(
                            at: pointerStart
                        )
                        if penPathContinuationGestureState == .available,
                           !ImageEditorPenAnchorAutoDeletePolicy.shouldDelete(
                            viewTranslation: value.translation
                           ),
                           viewModel.beginMovingPenPathContinuationAnchor(
                            at: pointerStart,
                            constrainedToAngleIncrement: ImageEditorPathAnchorDragConstraint
                                .shouldConstrain(
                                    modifierFlags: NSEvent.modifierFlags,
                                    viewTranslation: value.translation
                                ),
                            preservingSmoothness: !NSEvent.modifierFlags.contains(.option)
                           ) {
                            isMovingPathAnchor = true
                            penAnchorDeletionGestureState = .selectionOnly
                            penPathContinuationGestureState = .none
                            viewModel.moveSelectedPathAnchor(
                                to: pointerImagePoint,
                                constrainedToAngleIncrement: ImageEditorPathAnchorDragConstraint
                                    .shouldConstrain(
                                        modifierFlags: NSEvent.modifierFlags,
                                        viewTranslation: value.translation
                                    ),
                                preservingSmoothness: !NSEvent.modifierFlags.contains(.option)
                            )
                        }
                        updateCanvasCursor(at: value.location, in: size)
                    } else if pendingPenCreationAction == nil,
                              viewModel.pendingPenPathPoints.isEmpty,
                              let pointerStart = imagePoint(from: value.startLocation, in: size),
                              viewModel.beginMovingPenPathAnchor(
                                at: pointerStart,
                                constrainedToAngleIncrement: ImageEditorPathAnchorDragConstraint
                                    .shouldConstrain(
                                        modifierFlags: NSEvent.modifierFlags,
                                        viewTranslation: value.translation
                                    ),
                                preservingSmoothness: !NSEvent.modifierFlags.contains(.option)
                              ) {
                        isMovingPathAnchor = true
                        penAnchorDeletionGestureState = viewModel.penAnchorDeletionState(
                            at: pointerStart
                        )
                        if penAnchorDeletionGestureState == .available,
                           !ImageEditorPenAnchorAutoDeletePolicy.shouldDelete(
                            viewTranslation: value.translation
                           ) {
                            penAnchorDeletionGestureState = .selectionOnly
                        }
                        if penAnchorDeletionGestureState != .blocked {
                            viewModel.moveSelectedPathAnchor(
                                to: pointerImagePoint,
                                constrainedToAngleIncrement: ImageEditorPathAnchorDragConstraint
                                    .shouldConstrain(
                                        modifierFlags: NSEvent.modifierFlags,
                                        viewTranslation: value.translation
                                    ),
                                preservingSmoothness: !NSEvent.modifierFlags.contains(.option)
                            )
                        }
                        updateCanvasCursor(at: value.location, in: size)
                    } else if !isPathAnchorDragCancelled {
                        pendingPenCreationAction = ImageEditorPendingPenGesturePolicy.resolve(
                            startImagePoint: imagePoint(from: value.startLocation, in: size),
                            endImagePoint: pointerImagePoint,
                            viewTranslation: value.translation
                        )
                    }
                case .pathSelection:
                    if !isPathSelectionGestureResolved {
                        isPathSelectionGestureResolved = true
                        if let pointerStart = imagePoint(from: value.startLocation, in: size),
                           let target = viewModel.pathSelectionTarget(at: pointerStart),
                           !target.isBlocked,
                           viewModel.selectPathLayer(
                            at: pointerStart,
                            extendingSelection: NSEvent.modifierFlags.contains(.shift)
                           ),
                           viewModel.document.selectedLayerIDs.contains(target.layerID) {
                            if viewModel.beginMovingSelectedLayer() {
                                resetObjectMoveTracking()
                                isObjectMoveGestureActive = true
                            }
                        }
                    }
                    if isObjectMoveGestureActive {
                        updateObjectMove(translation: value.translation, in: size)
                    }
                case .directSelection:
                    if !isDirectPathGestureResolved {
                        isDirectPathGestureResolved = true
                        let pointerStart = imagePoint(from: value.startLocation, in: size)
                        if viewModel.directPathAnchorState(at: pointerStart) == .available {
                            isMovingPathAnchor = viewModel.beginDirectPathAnchorMove(
                                at: pointerStart,
                                constrainedToAngleIncrement: ImageEditorPathAnchorDragConstraint
                                    .shouldConstrain(
                                        modifierFlags: NSEvent.modifierFlags,
                                        viewTranslation: value.translation
                                    ),
                                preservingSmoothness: !NSEvent.modifierFlags.contains(.option)
                            )
                        }
                    } else if isMovingPathAnchor {
                        viewModel.moveSelectedPathAnchor(
                            to: pointerImagePoint,
                            constrainedToAngleIncrement: ImageEditorPathAnchorDragConstraint
                                .shouldConstrain(
                                    modifierFlags: NSEvent.modifierFlags,
                                    viewTranslation: value.translation
                                ),
                            preservingSmoothness: !NSEvent.modifierFlags.contains(.option)
                        )
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
                    isTemporaryEyedropperGestureActive = false
                    eyedropperGestureTarget = nil
                    eyedropperSamplingRing = nil
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
                let paintAirbrushPulseSamples = canvasInteractionTool == .brush
                    ? finishPaintAirbrushStroke(at: endImagePoint)
                    : []

                if let activeCropHandle {
                    let currentEvent = NSApp.currentEvent
                    let shouldCommitCrop = ImageEditorCropDoubleClickCommitPolicy.shouldCommit(
                        activeHandle: activeCropHandle,
                        clickCount: currentEvent?.clickCount ?? 0,
                        viewTranslation: value.translation,
                        hasConflictingModifiers: currentEvent?.modifierFlags
                            .intersection([.command, .option, .shift, .control])
                            .isEmpty == false
                    )
                    endPendingCropInteraction()
                    if shouldCommitCrop, let pendingCropRect {
                        viewModel.crop(to: pendingCropRect)
                        self.pendingCropRect = nil
                    }
                    dragStart = nil
                    dragEnd = nil
                    resetObjectMoveTracking()
                    return
                }

                if let selectionBoxDrag = objectSelectionBoxDrag {
                    if selectionBoxDrag.isActivated,
                       let selectionRect = selectionBoxDrag.selectionRect {
                        viewModel.applyMoveToolBoxSelection(
                            in: selectionRect,
                            mode: selectionBoxDrag.mode,
                            scope: selectionBoxDrag.scope,
                            inclusion: selectionBoxDrag.inclusion
                        )
                    } else if selectionBoxDrag.mode == .replace {
                        viewModel.clearLayerSelection()
                    }
                    objectSelectionBoxDrag = nil
                    resetObjectMoveTracking()
                    refreshCanvasCursor(in: size)
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
                    if isTemporaryEyedropperGestureActive, let endImagePoint {
                        viewModel.sampleColor(at: endImagePoint)
                    } else {
                        viewModel.drawBrush(
                            samples: committedBrushSamples,
                            airbrushPulseSamples: paintAirbrushPulseSamples
                        )
                    }
                case .pencil:
                    if isTemporaryEyedropperGestureActive, let endImagePoint {
                        viewModel.sampleColor(at: endImagePoint)
                    } else {
                        viewModel.drawPencil(samples: committedBrushSamples)
                    }
                case .historyBrush:
                    viewModel.historyBrush(samples: committedBrushSamples)
                case .eraser:
                    viewModel.eraseBrush(
                        samples: committedBrushSamples,
                        restoringHistory: isEraserHistoryGestureActive
                    )
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
                    } else if let dragStart,
                              let proposedEnd = endImagePoint ?? patchRawDragEnd ?? dragEnd {
                        let constrainedEnd = ImageEditorPatchDragConstraint.resolve(
                            start: dragStart,
                            proposedEnd: proposedEnd,
                            existingAxis: patchDragConstraintAxis,
                            isConstrained: NSEvent.modifierFlags.contains(.shift)
                        )
                        viewModel.patchSelection(
                            from: dragStart,
                            to: constrainedEnd.endPoint
                        )
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
                    if isPenAnchorConversionGestureActive {
                        if !isPathAnchorDragCancelled,
                           let target = penAnchorConversionTarget,
                           let anchorPoint = penAnchorConversionAction?.anchorPoint {
                            let action = ImageEditorPenAnchorConversionGesturePolicy.resolve(
                                anchorPoint: anchorPoint,
                                pointerEnd: unboundedImagePoint(from: value.location, in: size),
                                viewTranslation: value.translation
                            )
                            viewModel.convertPathAnchor(
                                target: target,
                                symmetricControlDrag: action.symmetricControlDrag
                            )
                        }
                    } else if penPathContinuationGestureState != .none {
                        if penPathContinuationGestureState == .available,
                           ImageEditorPenAnchorAutoDeletePolicy.shouldDelete(
                            viewTranslation: value.translation
                           ) {
                            _ = viewModel.beginPenPathContinuation(
                                at: imagePoint(from: value.startLocation, in: size)
                            )
                        }
                    } else if isMovingPathAnchor, !isPathAnchorDragCancelled {
                        viewModel.finishPenAnchorInteraction(
                            deletionState: penAnchorDeletionGestureState,
                            shouldDelete: ImageEditorPenAnchorAutoDeletePolicy.shouldDelete(
                                viewTranslation: value.translation
                            )
                        )
                    } else if !isPathAnchorDragCancelled,
                              viewModel.insertPathAnchor(
                                at: imagePoint(from: value.startLocation, in: size)
                              ) {
                        break
                    } else if !isPathAnchorDragCancelled,
                              ImageEditorPendingPenPointerFinishPolicy.shouldFinishOpenPath(
                                hasPendingPath: viewModel.hasPendingPenPathTransaction,
                                modifierFlags: NSEvent.modifierFlags
                              ) {
                        viewModel.finishPenPath(closed: false)
                    } else {
                        if !isPathAnchorDragCancelled {
                            let action = pendingPenCreationAction
                                ?? ImageEditorPendingPenGesturePolicy.resolve(
                                    startImagePoint: imagePoint(from: value.startLocation, in: size),
                                    endImagePoint: endImagePoint,
                                    viewTranslation: value.translation
                                )
                            viewModel.addPenPoint(
                                action?.anchorPoint,
                                symmetricControlDrag: action?.symmetricControlDrag,
                                constrainedToAngleIncrement: canvasModifierFlags.contains(.shift)
                            )
                        }
                    }
                case .pathSelection:
                    if isObjectMoveGestureActive {
                        updateObjectMove(translation: value.translation, in: size)
                        viewModel.finishMovingSelectedLayer()
                    }
                case .directSelection:
                    if isMovingPathAnchor, !isPathAnchorDragCancelled {
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
                        beginCanvasTextEditing(at: endImagePoint, in: size)
                    }
                case .eyedropper:
                    if let endImagePoint {
                        viewModel.sampleColor(
                            at: endImagePoint,
                            target: eyedropperGestureTarget
                                ?? ImageEditorEyedropperTargetPolicy.target(
                                    tool: canvasInteractionTool,
                                    modifierFlags: NSEvent.modifierFlags
                                )
                        )
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
                    if let dragStart {
                        viewModel.drawGradient(
                            from: dragStart,
                            to: gradientDragPoint(from: value.location, in: size)
                        )
                    }
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
                isTemporaryEyedropperGestureActive = false
                eyedropperGestureTarget = nil
                eyedropperSamplingRing = nil
                isEraserHistoryGestureActive = false
                activeBrushPressure = nil
                paintAirbrushStroke.reset()
                toneAirbrushStroke.reset()
                dragStart = nil
                dragEnd = nil
                patchPreviewImage = nil
                patchRawDragEnd = nil
                patchDragConstraintAxis = nil
                isDrawingPatchSelection = false
                isPatchGestureBlocked = false
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
                isPathAnchorDragCancelled = false
                isDirectPathGestureResolved = false
                isPathSelectionGestureResolved = false
                isPenPointerSequenceActive = false
                pendingPenCreationAction = nil
                resetPenAnchorConversionGesture()
                penAnchorDeletionGestureState = .none
                penPathContinuationGestureState = .none
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
    private func cancelPatchGestureForCanvasLifecycle() -> Bool {
        guard ImageEditorPatchGestureCancellationPolicy.shouldCancel(
            tool: canvasInteractionTool,
            hasDragStart: dragStart != nil,
            hasDrawnPoints: !dragPoints.isEmpty,
            isDrawingSelection: isDrawingPatchSelection,
            hasPreview: patchPreviewImage != nil
        ) else { return false }

        dragStart = nil
        dragEnd = nil
        dragPoints = []
        patchPreviewImage = nil
        patchRawDragEnd = nil
        patchDragConstraintAxis = nil
        isDrawingPatchSelection = false
        isPatchGestureBlocked = true
        lastPatchPreviewUpdateTime = 0
        NSCursor.arrow.set()
        return true
    }

    private func updatePatchDrag(
        to proposedEnd: CGPoint,
        modifierFlags: NSEvent.ModifierFlags,
        forcesPreview: Bool = false
    ) {
        guard let dragStart else { return }
        let constrainedEnd = ImageEditorPatchDragConstraint.resolve(
            start: dragStart,
            proposedEnd: proposedEnd,
            existingAxis: patchDragConstraintAxis,
            isConstrained: modifierFlags.contains(.shift)
        )
        patchRawDragEnd = proposedEnd
        patchDragConstraintAxis = constrainedEnd.axis
        dragEnd = constrainedEnd.endPoint
        viewModel.updatePointer(constrainedEnd.endPoint)

        let updateTime = ProcessInfo.processInfo.systemUptime
        guard forcesPreview
                || patchPreviewImage == nil
                || updateTime - lastPatchPreviewUpdateTime >= 1.0 / 30.0
        else { return }
        patchPreviewImage = viewModel.patchPreviewImage(
            from: dragStart,
            to: constrainedEnd.endPoint
        )
        lastPatchPreviewUpdateTime = updateTime
    }

    private func refreshActivePatchPreview() {
        guard let proposedEnd = patchRawDragEnd ?? dragEnd else { return }
        updatePatchDrag(
            to: proposedEnd,
            modifierFlags: canvasModifierFlags,
            forcesPreview: true
        )
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
            canvasSize: viewModel.document.canvasSize,
            preservesAspectRatio: isCropAspectRatioLocked
        )
    }

    private func endPendingCropInteraction() {
        activeCropHandle = nil
        cropInteractionStartPoint = nil
        cropInteractionOriginalRect = nil
    }

    private func swapPendingCropOrientation() {
        guard let pendingCropRect else { return }
        self.pendingCropRect = ImageEditorCropGeometry.frameBySwappingCommittedDimensions(
            of: pendingCropRect,
            canvasSize: viewModel.document.canvasSize
        )
        endPendingCropInteraction()
    }

    @discardableResult
    private func resetPendingCropToCanvas() -> Bool {
        guard pendingCropRect != nil else { return false }
        pendingCropRect = ImageEditorCropGeometry.fullCanvasFrame(
            canvasSize: viewModel.document.canvasSize
        )
        endPendingCropInteraction()
        return true
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
                    .onExitCommand {
                        cancelCanvasTextEditing()
                    }
                    .accessibilityIdentifier("image-editor-canvas-text-editor")

                HStack(spacing: 4) {
                    Button { cancelCanvasTextEditing() } label: {
                        Image(systemName: "xmark")
                    }
                    .focusable(false)
                    Button { commitCanvasTextEditing() } label: {
                        Image(systemName: "checkmark")
                    }
                    .keyboardShortcut(.return, modifiers: [.command])
                    .focusable(false)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
            .position(x: position.x + editorWidth / 2, y: position.y + editorHeight / 2)
            .zIndex(20)
        }
    }

    private func beginCanvasTextEditing(at point: CGPoint?, in size: CGSize) {
        guard let point else { return }
        var excludedLayerID: UUID?
        if canvasTextEditingOrigin != nil {
            commitCanvasTextEditing()
            excludedLayerID = viewModel.document.selectedLayerID
        }
        startCanvasTextEditing(
            at: point,
            excluding: excludedLayerID,
            hitTolerance: canvasTextHitTolerance(in: size)
        )
    }

    private func canvasTextHitTolerance(in size: CGSize) -> CGFloat {
        let imageRect = fittedImageRect(in: size)
        let displayScale = imageRect.width / max(viewModel.document.canvasSize.width, 1)
        return ImageEditorTextHitTesting.canvasTolerance(displayScale: displayScale)
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

    private func startCanvasTextEditing(
        at point: CGPoint,
        excluding excludedLayerID: UUID? = nil,
        hitTolerance: CGFloat = ImageEditorTextHitTesting.viewTolerance
    ) {
        if beginExistingCanvasTextEditing(
            at: point,
            excluding: excludedLayerID,
            hitTolerance: hitTolerance
        ) {
            return
        }
        viewModel.textValue = ""
        viewModel.textBoxWidth = 0
        viewModel.textBoxHeight = 0
        canvasTextEditingLayerID = nil
        canvasTextEditingOrigin = point
        canvasTextEditingFrame = nil
        DispatchQueue.main.async { isCanvasTextEditorFocused = true }
    }

    @discardableResult
    private func beginExistingCanvasTextEditing(
        at point: CGPoint,
        excluding excludedLayerID: UUID? = nil,
        hitTolerance: CGFloat = ImageEditorTextHitTesting.viewTolerance
    ) -> Bool {
        guard viewModel.selectEditableTextLayer(
            at: point,
            excluding: excludedLayerID,
            hitTolerance: hitTolerance
        ) else { return false }

        return beginEditingSelectedCanvasTextLayer()
    }

    @discardableResult
    private func beginEditingSelectedCanvasTextLayer() -> Bool {
        guard let layer = viewModel.document.selectedLayer,
              layer.isText,
              !viewModel.document.isEffectivelyPixelsLocked(layer)
        else { return false }

        canvasTextEditingLayerID = layer.id
        canvasTextEditingOrigin = layer.frame.origin
        canvasTextEditingFrame = nil
        DispatchQueue.main.async { isCanvasTextEditorFocused = true }
        return true
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

    private func commitCanvasTextEditingIfNeeded() {
        guard canvasTextEditingOrigin != nil else { return }
        commitCanvasTextEditing()
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
        let penSegmentInsertionState = canvasInteractionTool == .pen
            ? viewModel.penPathSegmentInsertionState(at: canvasPoint)
            : .none
        let penAnchorDeletionState = resolvedPenAnchorDeletionState(at: canvasPoint)
        let penPathContinuationState = resolvedPenPathContinuationState(at: canvasPoint)
        viewModel.updatePointer(canvasPoint)
        let imageRect = fittedImageRect(in: size)
        let displayScale = imageRect.width / max(viewModel.document.canvasSize.width, 1)
        let contentHit = canvasPoint.map(viewModel.moveToolContentHit(at:)) ?? .none
        let moveToolHoverSelectionIntent = canvasPoint.flatMap {
            viewModel.moveToolHoverTarget(
                at: $0,
                modifierFlags: NSEvent.modifierFlags
            )?.selectionIntent
        } ?? .none
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
            spongeMode: viewModel.spongeMode,
            brushTilt: activeBrushTilt,
            brushTiltControlsShape: viewModel.brushTiltControlsShape,
            brushTipRoundness: viewModel.brushTipRoundness / 100,
            brushTipAngleDegrees: viewModel.brushTipAngleDegrees,
            isPointerOverCanvas: canvasPoint != nil,
            isPointerOverMovableContent: contentHit.isMovable,
            isPointerOverBlockedContent: contentHit.isBlocked,
            moveToolUsesBoxSelection: viewModel.moveToolAutoSelectsCanvasTarget,
            moveToolHoverSelectionIntent: moveToolHoverSelectionIntent,
            isPointerOverEditableText:
                canvasInteractionTool == .text
                    && canvasPoint.map {
                        viewModel.hasEditableTextLayer(
                            at: $0,
                            hitTolerance: canvasTextHitTolerance(in: size)
                        )
                    } == true,
            isPointerOverColorSamplerPoint:
                canvasInteractionTool == .colorSampler
                    && colorSamplerPointID(at: viewPoint, in: size) != nil,
            paintBucketSeedIsBlocked: canvasInteractionTool == .paintBucket
                && !viewModel.isPaintBucketSeedAvailable(at: canvasPoint),
            penIsClosing: canvasInteractionTool == .pen && viewModel.isPenCloseCandidate(at: canvasPoint),
            penIsConverting: isPenAnchorConversionGestureActive
                || (canvasInteractionTool == .pen
                    && NSEvent.modifierFlags.contains(.option)
                    && viewModel.isPenCornerConversionCandidate(at: canvasPoint)),
            penConversionIsBlocked: isPenAnchorConversionGestureBlocked
                || (canvasInteractionTool == .pen
                    && NSEvent.modifierFlags.contains(.option)
                    && viewModel.isPenCornerConversionBlocked(at: canvasPoint)),
            penIsAddingAnchor: penSegmentInsertionState != .none,
            penAdditionIsBlocked: penSegmentInsertionState == .blocked,
            penIsDeletingAnchor: penAnchorDeletionState == .available,
            penAnchorDeletionIsBlocked: penAnchorDeletionState == .blocked,
            penIsContinuingPath: penPathContinuationState == .available,
            penContinuationIsBlocked: penPathContinuationState == .blocked,
            directSelectionIsBlocked: canvasInteractionTool == .directSelection
                && viewModel.directPathAnchorState(at: canvasPoint) == .blocked,
            pathSelectionIsBlocked: canvasInteractionTool == .pathSelection
                && viewModel.pathSelectionTarget(at: canvasPoint)?.isBlocked == true,
            pathHandleIsBreaking: isBreakingSmoothPathHandle(
                at: canvasPoint,
                modifierFlags: NSEvent.modifierFlags
            ),
            handIsDragging: isCanvasPanGestureActive,
            isObjectMoveGestureActive: isSelectedObjectMoveGestureActive || isObjectMoveGestureActive,
            isColorSamplerMoveGestureActive: colorSamplerDrag != nil,
            isSpacebarPanning: isSpacebarPanning,
            isCanvasPanGestureActive: isCanvasPanGestureActive,
            isPickingSampledBrushSource: isSettingSampledBrushSourceGesture,
            isTemporaryEyedropperActive: isTemporaryEyedropperCursorActive,
            eyedropperTarget: eyedropperCursorTarget,
            isErasingToHistory: isEraserHistoryCursorActive,
            patchPhase: patchCursorPhase(at: canvasPoint),
            patchMode: viewModel.patchMode,
            patchSelectionMode: viewModel.selectionMode,
            modifierFlags: NSEvent.modifierFlags,
            marqueeShape: viewModel.marqueeShape,
            cropHandle: cropInteractionHandle(at: viewPoint, in: size),
            layerTransformTarget: layerTransformCursorTarget(at: viewPoint, in: size)
        ).set()
    }

    private func isBreakingSmoothPathHandle(
        at canvasPoint: CGPoint?,
        modifierFlags: NSEvent.ModifierFlags
    ) -> Bool {
        guard modifierFlags.contains(.option),
              canvasInteractionTool == .pen || canvasInteractionTool == .directSelection
        else { return false }
        if isMovingPathAnchor {
            return viewModel.isMovingSmoothPathControlHandle
        }
        return viewModel.isSmoothPathControlHandle(
            at: canvasPoint,
            includingUnselectedPaths: canvasInteractionTool == .directSelection
        )
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
            spongeMode: viewModel.spongeMode,
            isPointerOverCanvas: false,
            isPointerOverMovableContent: false,
            moveToolUsesBoxSelection: viewModel.moveToolAutoSelectsCanvasTarget,
            handIsDragging: isCanvasPanGestureActive,
            isObjectMoveGestureActive: isSelectedObjectMoveGestureActive || isObjectMoveGestureActive,
            isColorSamplerMoveGestureActive: colorSamplerDrag != nil,
            isSpacebarPanning: isSpacebarPanning,
            isCanvasPanGestureActive: isCanvasPanGestureActive,
            isPickingSampledBrushSource: isSettingSampledBrushSourceGesture,
            isTemporaryEyedropperActive: isTemporaryEyedropperCursorActive,
            eyedropperTarget: eyedropperCursorTarget,
            isErasingToHistory: isEraserHistoryCursorActive,
            patchPhase: patchCursorPhase(at: nil),
            patchMode: viewModel.patchMode,
            patchSelectionMode: viewModel.selectionMode,
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

    private var isEraserHistoryCursorActive: Bool {
        guard canvasInteractionTool == .eraser else { return false }
        if viewModel.canvasPointerCaptureState.activeTool == .eraser
            || !brushStrokeSamples.isEmpty {
            return isEraserHistoryGestureActive
        }
        return viewModel.shouldEraseToHistory(modifierFlags: canvasModifierFlags)
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

    private func gradientDragPoint(from viewPoint: CGPoint, in size: CGSize) -> CGPoint {
        constrainedGradientEndpoint(unboundedImagePoint(from: viewPoint, in: size))
    }

    private func constrainedGradientEndpoint(_ current: CGPoint) -> CGPoint {
        guard let dragStart else { return current }
        return ImageEditorGradientDragGeometry.endpoint(
            from: dragStart,
            toward: current,
            constrainedToAngleIncrement: canvasModifierFlags.contains(.shift)
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
                Toggle(
                    L10n.text("imageEditor.option.colorSamplerIgnoreAdjustments"),
                    isOn: Binding(
                        get: { viewModel.colorSamplerIgnoresAdjustmentLayers },
                        set: { viewModel.setColorSamplerIgnoresAdjustmentLayers($0) }
                    )
                )
                .toggleStyle(.checkbox)
                .focusable(false)
                .accessibilityIdentifier(
                    "image-editor-info-color-sampling-ignore-adjustments"
                )
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
                                Button {
                                    viewModel.setHistoryFillSource(entryID: entry.id)
                                } label: {
                                    Image(systemName: viewModel.isHistoryFillSource(entryID: entry.id)
                                        ? "paintbrush.fill"
                                        : "circle")
                                        .font(.system(size: 10, weight: .semibold))
                                        .frame(width: 18, height: 22)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(Color(nsColor: viewModel.isHistoryFillSource(entryID: entry.id)
                                    ? ImageEditorTheme.selected
                                    : ImageEditorTheme.mutedText))
                                .focusable(false)
                                .help(L10n.format("imageEditor.action.historyFillSource", entry.title))
                                .accessibilityIdentifier("image-editor-history-fill-source-\(entry.id)")

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
                if viewModel.selectedFilter == .gaussianBlur {
                    Text(L10n.format(
                        "imageEditor.filter.gaussianBlurRadiusValue",
                        String(format: "%.1f", viewModel.filterGaussianBlurEffectiveRadius)
                    ))
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        .frame(width: 64, alignment: .leading)
                    Slider(
                        value: Binding(
                            get: { viewModel.filterGaussianBlurEffectiveRadius },
                            set: { viewModel.filterGaussianBlurEffectiveRadius = $0 }
                        ),
                        in: 0.1...1_000,
                        step: 0.1
                    )
                        .focusable(false)
                        .accessibilityLabel(L10n.text("imageEditor.filter.gaussianBlurRadius"))
                        .accessibilityIdentifier("image-editor-filter-quick-gaussian-blur-radius")
                } else if viewModel.selectedFilter == .sharpen {
                    Text(L10n.format(
                        "imageEditor.filter.unsharpAmountValue",
                        Int(viewModel.filterSharpenEffectiveAmountPercent.rounded())
                    ))
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        .frame(width: 52, alignment: .leading)
                    Slider(
                        value: Binding(
                            get: { viewModel.filterSharpenEffectiveAmountPercent },
                            set: { viewModel.filterSharpenEffectiveAmountPercent = $0 }
                        ),
                        in: 0...200,
                        step: 1
                    )
                        .focusable(false)
                        .accessibilityLabel(L10n.text("imageEditor.filter.unsharpAmount"))
                        .accessibilityIdentifier("image-editor-filter-quick-sharpen-amount")
                } else if viewModel.selectedFilter == .pixelate {
                    Text(L10n.format(
                        "imageEditor.filter.pixelateCellSizeValue",
                        Int(viewModel.filterPixelateCellSize.rounded())
                    ))
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        .frame(width: 52, alignment: .leading)
                    Slider(value: $viewModel.filterPixelateCellSize, in: 2...200, step: 1)
                        .focusable(false)
                        .accessibilityLabel(L10n.text("imageEditor.filter.pixelateCellSize"))
                        .accessibilityIdentifier("image-editor-filter-quick-pixelate-cell-size")
                } else if viewModel.selectedFilter == .addNoise {
                    Text(L10n.format(
                        "imageEditor.filter.addNoiseAmountValue",
                        String(format: "%.1f", viewModel.filterAddNoiseEffectiveAmountPercent)
                    ))
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        .frame(width: 62, alignment: .leading)
                    Slider(
                        value: Binding(
                            get: { viewModel.filterAddNoiseEffectiveAmountPercent },
                            set: { viewModel.filterAddNoiseEffectiveAmountPercent = $0 }
                        ),
                        in: 0.1...400,
                        step: 0.1
                    )
                        .focusable(false)
                        .accessibilityLabel(L10n.text("imageEditor.filter.addNoiseAmount"))
                        .accessibilityIdentifier("image-editor-filter-quick-add-noise-amount")
                } else if viewModel.selectedFilter == .vignette {
                    Text(L10n.format(
                        "imageEditor.filter.vignetteAmountValue",
                        String(format: "%+d", Int(viewModel.filterVignetteEffectiveAmountPercent.rounded()))
                    ))
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        .frame(width: 52, alignment: .leading)
                    Slider(
                        value: Binding(
                            get: { viewModel.filterVignetteEffectiveAmountPercent },
                            set: { viewModel.filterVignetteEffectiveAmountPercent = $0 }
                        ),
                        in: -100...100,
                        step: 1
                    )
                        .focusable(false)
                        .accessibilityLabel(L10n.text("imageEditor.filter.vignetteAmount"))
                        .accessibilityIdentifier("image-editor-filter-quick-vignette-amount")
                } else if viewModel.selectedFilter == .oilPaint {
                    Text(L10n.format(
                        "imageEditor.filter.oilPaintRadiusValue",
                        Int(viewModel.filterOilPaintRadius.rounded())
                    ))
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        .frame(width: 52, alignment: .leading)
                    Slider(value: $viewModel.filterOilPaintRadius, in: 1...10, step: 1)
                        .focusable(false)
                        .accessibilityLabel(L10n.text("imageEditor.filter.oilPaintRadius"))
                        .accessibilityIdentifier("image-editor-filter-quick-oil-paint-radius")
                } else if viewModel.selectedFilter == .highPass {
                    Text(L10n.format(
                        "imageEditor.filter.highPassRadiusValue",
                        Int(viewModel.filterHighPassRadius.rounded())
                    ))
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        .frame(width: 62, alignment: .leading)
                    Slider(value: $viewModel.filterHighPassRadius, in: 1...1_000, step: 1)
                        .focusable(false)
                        .accessibilityLabel(L10n.text("imageEditor.filter.highPassRadius"))
                        .accessibilityIdentifier("image-editor-filter-quick-high-pass-radius")
                } else if viewModel.selectedFilter == .motionBlur {
                    Text(L10n.format(
                        "imageEditor.filter.motionBlurDistanceValue",
                        Int(viewModel.filterMotionBlurDistance.rounded())
                    ))
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        .frame(width: 62, alignment: .leading)
                    Slider(value: $viewModel.filterMotionBlurDistance, in: 1...999, step: 1)
                        .focusable(false)
                        .accessibilityLabel(L10n.text("imageEditor.filter.motionBlurDistance"))
                        .accessibilityIdentifier("image-editor-filter-quick-motion-blur-distance")
                } else if viewModel.selectedFilter == .unsharpMask {
                    Text(L10n.format(
                        "imageEditor.filter.unsharpAmountValue",
                        Int(viewModel.filterUnsharpEffectiveAmountPercent.rounded())
                    ))
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        .frame(width: 52, alignment: .leading)
                    Slider(
                        value: Binding(
                            get: { viewModel.filterUnsharpEffectiveAmountPercent },
                            set: { viewModel.filterUnsharpEffectiveAmountPercent = $0 }
                        ),
                        in: 1...500,
                        step: 1
                    )
                        .focusable(false)
                        .accessibilityLabel(L10n.text("imageEditor.filter.unsharpAmount"))
                        .accessibilityIdentifier("image-editor-filter-quick-unsharp-amount")
                } else if viewModel.selectedFilter == .emboss {
                    Text(L10n.format(
                        "imageEditor.filter.embossHeightValue",
                        Int(viewModel.filterEmbossHeight.rounded())
                    ))
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        .frame(width: 52, alignment: .leading)
                    Slider(value: $viewModel.filterEmbossHeight, in: 1...10, step: 1)
                        .focusable(false)
                        .accessibilityLabel(L10n.text("imageEditor.filter.embossHeight"))
                        .accessibilityIdentifier("image-editor-filter-quick-emboss-height")
                } else if viewModel.selectedFilter == .minimum || viewModel.selectedFilter == .maximum {
                    Text(L10n.format(
                        "imageEditor.filter.morphologyRadiusValue",
                        Int(viewModel.filterMorphologyRadius.rounded())
                    ))
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        .frame(width: 52, alignment: .leading)
                    Slider(value: $viewModel.filterMorphologyRadius, in: 1...256, step: 1)
                        .focusable(false)
                        .accessibilityLabel(L10n.text("imageEditor.filter.morphologyRadius"))
                        .accessibilityIdentifier("image-editor-filter-quick-morphology-radius")
                } else if viewModel.selectedFilter == .liquifyTwirl {
                    Text(L10n.format(
                        "imageEditor.filter.liquifyTwirlValue",
                        String(format: "%+d", Int(viewModel.filterLiquifyTwirlEffectiveAngleDegrees.rounded()))
                    ))
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        .frame(width: 52, alignment: .leading)
                    Slider(
                        value: Binding(
                            get: { viewModel.filterLiquifyTwirlEffectiveAngleDegrees },
                            set: { viewModel.filterLiquifyTwirlEffectiveAngleDegrees = $0 }
                        ),
                        in: -999...999,
                        step: 1
                    )
                        .focusable(false)
                        .accessibilityLabel(L10n.text("imageEditor.filter.liquifyTwirlAngle"))
                        .accessibilityIdentifier("image-editor-filter-quick-liquify-twirl-angle")
                } else if viewModel.selectedFilter == .liquifyPuckerBloat {
                    Text(L10n.format(
                        "imageEditor.filter.liquifyBulgeValue",
                        String(format: "%+d", Int(viewModel.filterLiquifyBulgeEffectiveAmountPercent.rounded()))
                    ))
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        .frame(width: 52, alignment: .leading)
                    Slider(
                        value: Binding(
                            get: { viewModel.filterLiquifyBulgeEffectiveAmountPercent },
                            set: { viewModel.filterLiquifyBulgeEffectiveAmountPercent = $0 }
                        ),
                        in: -100...100,
                        step: 1
                    )
                        .focusable(false)
                        .accessibilityLabel(L10n.text("imageEditor.filter.liquifyBulgeAmount"))
                        .accessibilityIdentifier("image-editor-filter-quick-liquify-bulge-amount")
                } else if viewModel.selectedFilter == .pinch {
                    Text(L10n.format(
                        "imageEditor.filter.pinchAmountValue",
                        String(format: "%+d", Int(viewModel.filterPinchEffectiveAmountPercent.rounded()))
                    ))
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        .frame(width: 52, alignment: .leading)
                    Slider(
                        value: Binding(
                            get: { viewModel.filterPinchEffectiveAmountPercent },
                            set: { viewModel.filterPinchEffectiveAmountPercent = $0 }
                        ),
                        in: -100...100,
                        step: 1
                    )
                        .focusable(false)
                        .accessibilityLabel(L10n.text("imageEditor.filter.pinchAmount"))
                        .accessibilityIdentifier("image-editor-filter-quick-pinch-amount")
                } else if viewModel.selectedFilter == .spherize {
                    Text(L10n.format(
                        "imageEditor.filter.spherizeAmountValue",
                        String(format: "%+d", Int(viewModel.filterSpherizeEffectiveAmountPercent.rounded()))
                    ))
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        .frame(width: 52, alignment: .leading)
                    Slider(
                        value: Binding(
                            get: { viewModel.filterSpherizeEffectiveAmountPercent },
                            set: { viewModel.filterSpherizeEffectiveAmountPercent = $0 }
                        ),
                        in: -100...100,
                        step: 1
                    )
                        .focusable(false)
                        .accessibilityLabel(L10n.text("imageEditor.filter.spherizeAmount"))
                        .accessibilityIdentifier("image-editor-filter-quick-spherize-amount")
                } else if viewModel.selectedFilter == .lensCorrection {
                    Text(L10n.format(
                        "imageEditor.filter.lensDistortionValue",
                        String(format: "%+d", Int(viewModel.filterLensDistortionEffectiveAmountPercent.rounded()))
                    ))
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        .frame(width: 52, alignment: .leading)
                    Slider(
                        value: Binding(
                            get: { viewModel.filterLensDistortionEffectiveAmountPercent },
                            set: { viewModel.filterLensDistortionEffectiveAmountPercent = $0 }
                        ),
                        in: -100...100,
                        step: 1
                    )
                        .focusable(false)
                        .accessibilityLabel(L10n.text("imageEditor.filter.lensDistortion"))
                        .accessibilityIdentifier("image-editor-filter-quick-lens-distortion-amount")
                } else if viewModel.selectedFilter == .ripple {
                    Text(L10n.format(
                        "imageEditor.filter.rippleAmountValue",
                        String(format: "%+d", Int(viewModel.filterRippleEffectiveAmountPercent.rounded()))
                    ))
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        .frame(width: 52, alignment: .leading)
                    Slider(
                        value: Binding(
                            get: { viewModel.filterRippleEffectiveAmountPercent },
                            set: { viewModel.filterRippleEffectiveAmountPercent = $0 }
                        ),
                        in: -100...100,
                        step: 1
                    )
                        .focusable(false)
                        .accessibilityLabel(L10n.text("imageEditor.filter.rippleAmount"))
                        .accessibilityIdentifier("image-editor-filter-quick-ripple-amount")
                } else if viewModel.selectedFilter == .wave {
                    Text(L10n.format(
                        "imageEditor.filter.waveAmplitudeValue",
                        String(format: "%+d", Int(viewModel.filterWaveEffectiveAmplitudePercent.rounded()))
                    ))
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        .frame(width: 52, alignment: .leading)
                    Slider(
                        value: Binding(
                            get: { viewModel.filterWaveEffectiveAmplitudePercent },
                            set: { viewModel.filterWaveEffectiveAmplitudePercent = $0 }
                        ),
                        in: -100...100,
                        step: 1
                    )
                        .focusable(false)
                        .accessibilityLabel(L10n.text("imageEditor.filter.waveAmplitude"))
                        .accessibilityIdentifier("image-editor-filter-quick-wave-amplitude")
                } else if viewModel.selectedFilter == .offset {
                    VStack(spacing: 6) {
                        HStack(spacing: 8) {
                            Text(L10n.text("imageEditor.filter.offsetX"))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                                .frame(width: 58, alignment: .leading)
                            Slider(
                                value: Binding(
                                    get: { viewModel.filterOffsetEffectiveXPixels },
                                    set: { viewModel.filterOffsetEffectiveXPixels = $0 }
                                ),
                                in: -9_999...9_999,
                                step: 1
                            )
                                .focusable(false)
                                .accessibilityLabel(L10n.text("imageEditor.filter.offsetX"))
                                .accessibilityIdentifier("image-editor-filter-quick-offset-x-pixels")
                            Text(L10n.format(
                                "imageEditor.filter.offsetValue",
                                String(format: "%+d", Int(viewModel.filterOffsetEffectiveXPixels.rounded()))
                            ))
                                .font(.system(size: 10, weight: .semibold).monospacedDigit())
                                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                                .frame(width: 62, alignment: .trailing)
                        }
                        HStack(spacing: 8) {
                            Text(L10n.text("imageEditor.filter.offsetY"))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                                .frame(width: 58, alignment: .leading)
                            Slider(
                                value: Binding(
                                    get: { viewModel.filterOffsetEffectiveYPixels },
                                    set: { viewModel.filterOffsetEffectiveYPixels = $0 }
                                ),
                                in: -9_999...9_999,
                                step: 1
                            )
                                .focusable(false)
                                .accessibilityLabel(L10n.text("imageEditor.filter.offsetY"))
                                .accessibilityIdentifier("image-editor-filter-quick-offset-y-pixels")
                            Text(L10n.format(
                                "imageEditor.filter.offsetValue",
                                String(format: "%+d", Int(viewModel.filterOffsetEffectiveYPixels.rounded()))
                            ))
                                .font(.system(size: 10, weight: .semibold).monospacedDigit())
                                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                                .frame(width: 62, alignment: .trailing)
                        }
                    }
                } else if viewModel.selectedFilter == .liquifyPush {
                    VStack(spacing: 6) {
                        HStack(spacing: 8) {
                            Text(L10n.text("imageEditor.filter.liquifyPushX"))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                                .frame(width: 58, alignment: .leading)
                            Slider(
                                value: Binding(
                                    get: { viewModel.filterLiquifyPushEffectiveXPixels },
                                    set: { viewModel.filterLiquifyPushEffectiveXPixels = $0 }
                                ),
                                in: -9_999...9_999,
                                step: 1
                            )
                                .focusable(false)
                                .accessibilityLabel(L10n.text("imageEditor.filter.liquifyPushX"))
                                .accessibilityIdentifier("image-editor-filter-quick-liquify-push-x-pixels")
                            Text(L10n.format(
                                "imageEditor.filter.liquifyPushValue",
                                String(format: "%+d", Int(viewModel.filterLiquifyPushEffectiveXPixels.rounded()))
                            ))
                                .font(.system(size: 10, weight: .semibold).monospacedDigit())
                                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                                .frame(width: 62, alignment: .trailing)
                        }
                        HStack(spacing: 8) {
                            Text(L10n.text("imageEditor.filter.liquifyPushY"))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                                .frame(width: 58, alignment: .leading)
                            Slider(
                                value: Binding(
                                    get: { viewModel.filterLiquifyPushEffectiveYPixels },
                                    set: { viewModel.filterLiquifyPushEffectiveYPixels = $0 }
                                ),
                                in: -9_999...9_999,
                                step: 1
                            )
                                .focusable(false)
                                .accessibilityLabel(L10n.text("imageEditor.filter.liquifyPushY"))
                                .accessibilityIdentifier("image-editor-filter-quick-liquify-push-y-pixels")
                            Text(L10n.format(
                                "imageEditor.filter.liquifyPushValue",
                                String(format: "%+d", Int(viewModel.filterLiquifyPushEffectiveYPixels.rounded()))
                            ))
                                .font(.system(size: 10, weight: .semibold).monospacedDigit())
                                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                                .frame(width: 62, alignment: .trailing)
                        }
                    }
                } else if viewModel.selectedFilter == .median {
                    Text("\(Int((viewModel.filterIntensity * 100).rounded()))%")
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        .frame(width: 36, alignment: .leading)
                    Slider(value: $viewModel.filterIntensity, in: 0...1, step: 0.05)
                        .focusable(false)
                        .accessibilityLabel(L10n.text("imageEditor.option.strength"))
                        .accessibilityIdentifier("image-editor-filter-quick-median-strength")
                } else if viewModel.selectedFilter == .findEdges {
                    Text(L10n.text("imageEditor.filter.noAdjustableParameters"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("image-editor-filter-quick-no-adjustable-parameters")
                }
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
                viewModel.setHistoryFillSource(snapshotID: snapshot.id)
            } label: {
                Image(systemName: viewModel.isHistoryFillSource(snapshotID: snapshot.id)
                    ? "paintbrush.fill"
                    : "circle")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 16)
                    .foregroundStyle(Color(nsColor: viewModel.isHistoryFillSource(snapshotID: snapshot.id)
                        ? ImageEditorTheme.selected
                        : ImageEditorTheme.mutedText))
            }
            .buttonStyle(.plain)
            .focusable(false)
            .help(L10n.format("imageEditor.action.historyFillSource", snapshot.name))
            .accessibilityIdentifier("image-editor-history-snapshot-fill-source-\(snapshot.id)")

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

    private func selectedFigmaSizeConstraintValue(
        _ field: XomoFigmaSizeConstraintField
    ) -> Double? {
        viewModel.selectedLayerFigmaSizeConstraints.flatMap { field.value(in: $0) }
    }

    private func syncFigmaSizeConstraintDrafts() {
        for field in XomoFigmaSizeConstraintField.allCases {
            syncFigmaSizeConstraintDraft(field)
        }
    }

    private func syncFigmaSizeConstraintDraft(_ field: XomoFigmaSizeConstraintField) {
        figmaSizeConstraintDrafts[field] = selectedFigmaSizeConstraintValue(field).map {
            figmaSizeConstraintFormatter.string(from: NSNumber(value: $0)) ?? String($0)
        } ?? ""
    }

    private func figmaSizeConstraintDraftBinding(
        _ field: XomoFigmaSizeConstraintField
    ) -> Binding<String> {
        Binding(
            get: { figmaSizeConstraintDrafts[field] ?? "" },
            set: { figmaSizeConstraintDrafts[field] = $0 }
        )
    }

    private func commitFigmaSizeConstraintDraft(_ field: XomoFigmaSizeConstraintField) {
        let draft = (figmaSizeConstraintDrafts[field] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if draft.isEmpty {
            viewModel.setSelectedFigmaSizeConstraint(field, value: nil)
        } else if let value = figmaSizeConstraintFormatter.number(from: draft)?.doubleValue {
            viewModel.setSelectedFigmaSizeConstraint(field, value: value)
        }
        syncFigmaSizeConstraintDraft(field)
    }

    private var figmaSizeConstraintFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.isLenient = false
        return formatter
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

    private var selectedLayerGradientOverlayCenterXBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerGradientOverlayCenterX
        } set: { value in
            viewModel.setSelectedLayerGradientOverlayCenterX(value)
        }
    }

    private var selectedLayerGradientOverlayCenterYBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerGradientOverlayCenterY
        } set: { value in
            viewModel.setSelectedLayerGradientOverlayCenterY(value)
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
        let inspectedSpacingGuides = objectDistanceInspectionGuides(in: size)
        let displayedSpacingGuides = viewModel.activeSpacingGuides.isEmpty
            ? inspectedSpacingGuides
            : viewModel.activeSpacingGuides
        return Canvas { context, _ in
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

            for guide in displayedSpacingGuides {
                context.stroke(
                    spacingGuidePath(guide, in: size),
                    with: .color(Color(nsColor: ImageEditorTheme.selected).opacity(0.96)),
                    style: StrokeStyle(lineWidth: 1.5, dash: [2, 2])
                )
                drawSpacingGuideLabel(guide, context: context, in: size)
            }
        }
        .allowsHitTesting(false)
    }

    private func objectDistanceInspectionGuides(in size: CGSize) -> [ImageEditorSpacingGuide] {
        guard ImageEditorObjectDistanceInspectionPolicy.shouldShow(
            sidebarTab: viewModel.selectedLeftSidebarTab,
            selectedTool: viewModel.selectedTool,
            modifierFlags: canvasModifierFlags,
            hasActiveInteraction: hasActiveMoveToolVisualInteraction
        ), let hoverViewPoint,
           let canvasPoint = imagePoint(from: hoverViewPoint, in: size)
        else { return [] }
        return viewModel.moveToolDistanceInspectionGuides(at: canvasPoint)
    }

    private var hasActiveMoveToolVisualInteraction: Bool {
        viewModel.hasActiveLayerMoveTransaction
            || isObjectMoveGestureActive
            || isSelectedObjectMoveGestureActive
            || isCanvasCloneGestureActive
            || isCanvasSelectionGestureActive
            || objectSelectionBoxDrag != nil
            || activeResizeHandle != nil
            || isRotatingLayer
            || isMovingTransformReferencePoint
            || isSpacebarPanning
            || isCanvasPanGestureActive
            || isDeliveryObjectMoveGestureActive
            || activeGuideDrag != nil
    }

    @ViewBuilder
    private func moveToolHoverOutlineOverlay(in size: CGSize) -> some View {
        if ImageEditorMoveToolHoverOutlinePolicy.shouldShow(
            sidebarTab: viewModel.selectedLeftSidebarTab,
            selectedTool: viewModel.selectedTool,
            isAutoSelectEnabled: viewModel.isMoveToolAutoSelectEnabled,
            isPointerInsideCanvas: isPointerInsideCanvas,
            modifierFlags: canvasModifierFlags,
            hasActiveInteraction: hasActiveMoveToolVisualInteraction
        ), let hoverViewPoint,
           let canvasPoint = imagePoint(from: hoverViewPoint, in: size),
           let target = viewModel.moveToolHoverTarget(
                at: canvasPoint,
                modifierFlags: canvasModifierFlags
           ), !viewModel.document.selectedLayerIDs.contains(target.id)
                || target.selectionIntent == .remove {
            let rect = viewRect(from: target.frame, in: size)
            let accent = target.isBlocked || target.selectionIntent == .remove
                ? Color(nsColor: .systemRed)
                : Color(nsColor: ImageEditorTheme.selected)
            let labelHalfWidth: CGFloat = 74
            let labelX = size.width >= labelHalfWidth * 2
                ? min(max(rect.midX, labelHalfWidth), size.width - labelHalfWidth)
                : size.width / 2
            let labelY = min(max(rect.minY + 10, 10), max(10, size.height - 10))
            ZStack {
                Rectangle()
                    .stroke(
                        accent.opacity(target.isBlocked ? 0.9 : 0.82),
                        style: StrokeStyle(
                            lineWidth: 1,
                            dash: target.isBlocked ? [4, 3] : []
                        )
                    )
                    .frame(width: max(1, rect.width), height: max(1, rect.height))
                    .position(x: rect.midX, y: rect.midY)

                if !target.name.isEmpty {
                    HStack(spacing: 3) {
                        if target.selectionIntent != .none {
                            Image(systemName: target.selectionIntent == .add ? "plus" : "minus")
                                .font(.system(size: 8, weight: .bold))
                        }
                        Text(verbatim: target.name)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .frame(maxWidth: labelHalfWidth * 2, minHeight: 18)
                    .background(accent.opacity(0.92))
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                    .position(x: labelX, y: labelY)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func objectSelectionBoxOverlay(in size: CGSize) -> some View {
        if let selectionBoxDrag = objectSelectionBoxDrag,
           selectionBoxDrag.isActivated,
           let selectionRect = selectionBoxDrag.selectionRect {
            let previewTargets = viewModel.moveToolBoxSelectionPreviewTargets(
                in: selectionRect,
                mode: selectionBoxDrag.mode,
                scope: selectionBoxDrag.scope,
                inclusion: selectionBoxDrag.inclusion
            )
            let previewColor = switch selectionBoxDrag.mode {
            case .replace, .add:
                Color(nsColor: ImageEditorTheme.selected)
            case .subtract:
                Color(nsColor: .systemRed)
            case .intersect:
                Color(nsColor: .systemPurple)
            }
            let start = viewPoint(from: selectionRect.origin, in: size)
            let end = viewPoint(
                from: CGPoint(x: selectionRect.maxX, y: selectionRect.maxY),
                in: size
            )
            let viewRect = CGRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: abs(end.x - start.x),
                height: abs(end.y - start.y)
            )
            ZStack {
                Rectangle()
                    .fill(Color(nsColor: ImageEditorTheme.selected).opacity(0.12))
                    .overlay {
                        Rectangle()
                            .stroke(
                                Color(nsColor: ImageEditorTheme.selected).opacity(0.96),
                                lineWidth: 1
                            )
                    }
                    .frame(width: viewRect.width, height: viewRect.height)
                    .position(x: viewRect.midX, y: viewRect.midY)

                Canvas { context, _ in
                    for target in previewTargets {
                        let targetStart = viewPoint(from: target.frame.origin, in: size)
                        let targetEnd = viewPoint(
                            from: CGPoint(x: target.frame.maxX, y: target.frame.maxY),
                            in: size
                        )
                        let targetViewRect = CGRect(
                            x: min(targetStart.x, targetEnd.x),
                            y: min(targetStart.y, targetEnd.y),
                            width: abs(targetEnd.x - targetStart.x),
                            height: abs(targetEnd.y - targetStart.y)
                        )
                        context.stroke(
                            Path(targetViewRect),
                            with: .color(previewColor),
                            lineWidth: 1.5
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private func spacingGuidePath(_ guide: ImageEditorSpacingGuide, in size: CGSize) -> Path {
        let start = viewPoint(from: guide.start, in: size)
        let end = viewPoint(from: guide.end, in: size)
        let capLength: CGFloat = 4
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        switch guide.orientation {
        case .horizontal:
            path.move(to: CGPoint(x: start.x, y: start.y - capLength))
            path.addLine(to: CGPoint(x: start.x, y: start.y + capLength))
            path.move(to: CGPoint(x: end.x, y: end.y - capLength))
            path.addLine(to: CGPoint(x: end.x, y: end.y + capLength))
        case .vertical:
            path.move(to: CGPoint(x: start.x - capLength, y: start.y))
            path.addLine(to: CGPoint(x: start.x + capLength, y: start.y))
            path.move(to: CGPoint(x: end.x - capLength, y: end.y))
            path.addLine(to: CGPoint(x: end.x + capLength, y: end.y))
        }
        return path
    }

    private func drawSpacingGuideLabel(
        _ guide: ImageEditorSpacingGuide,
        context: GraphicsContext,
        in size: CGSize
    ) {
        let start = viewPoint(from: guide.start, in: size)
        let end = viewPoint(from: guide.end, in: size)
        let midpoint = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        let preferredLabelPoint: CGPoint
        switch guide.orientation {
        case .horizontal:
            preferredLabelPoint = CGPoint(x: midpoint.x, y: midpoint.y - 10)
        case .vertical:
            preferredLabelPoint = CGPoint(x: midpoint.x + 12, y: midpoint.y)
        }

        let label = guide.distanceText(locale: locale)
        let badgeSize = CGSize(width: max(18, CGFloat(label.count) * 6 + 8), height: 14)
        let canvasRect = fittedImageRect(in: size)
        let labelPoint = CGPoint(
            x: ImageEditorSpacingGuideLabelLayout.clampedCoordinate(
                preferredLabelPoint.x,
                minimum: canvasRect.minX,
                maximum: canvasRect.maxX,
                badgeLength: badgeSize.width
            ),
            y: ImageEditorSpacingGuideLabelLayout.clampedCoordinate(
                preferredLabelPoint.y,
                minimum: canvasRect.minY,
                maximum: canvasRect.maxY,
                badgeLength: badgeSize.height
            )
        )
        let badgeRect = CGRect(
            x: labelPoint.x - badgeSize.width / 2,
            y: labelPoint.y - badgeSize.height / 2,
            width: badgeSize.width,
            height: badgeSize.height
        )
        let badgePath = Path(roundedRect: badgeRect, cornerRadius: 3)
        context.fill(
            badgePath,
            with: .color(Color(nsColor: ImageEditorTheme.window).opacity(0.88))
        )
        context.stroke(
            badgePath,
            with: .color(Color(nsColor: ImageEditorTheme.selected).opacity(0.82)),
            lineWidth: 0.75
        )
        context.draw(
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(nsColor: ImageEditorTheme.text)),
            at: labelPoint
        )
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
    private func maskColorOverlay(in size: CGSize) -> some View {
        if let overlayImage = viewModel.canvasMaskOverlayImage {
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
    private func patchTransferGuideOverlay(in size: CGSize) -> some View {
        if canvasInteractionTool == .patchTool,
           !isDrawingPatchSelection,
           let selection = viewModel.selection,
           let selectionEdges = viewModel.selectionEdgeGeometry,
           let dragStart,
           let dragEnd,
           let guide = ImageEditorPatchTransferGuide.make(
                selectionEdges: selectionEdges,
                selectionBounds: selection.bounds,
                dragStart: dragStart,
                dragEnd: dragEnd,
                mode: viewModel.patchMode
           ) {
            Canvas { context, _ in
                func canvasPath(for geometry: ImageEditorSelectionEdgeGeometry) -> Path {
                    var path = Path()
                    for contour in geometry.contours {
                        guard let first = contour.first else { continue }
                        path.move(to: viewPoint(from: first, in: size))
                        for point in contour.dropFirst() {
                            path.addLine(to: viewPoint(from: point, in: size))
                        }
                    }
                    return path
                }

                let sourcePath = canvasPath(for: guide.sourceEdges)
                context.stroke(
                    sourcePath,
                    with: .color(Color(nsColor: ImageEditorTheme.selected).opacity(0.96)),
                    style: StrokeStyle(lineWidth: 2.4)
                )
                context.stroke(
                    canvasPath(for: guide.targetEdges),
                    with: .color(Color.white.opacity(0.94)),
                    style: StrokeStyle(lineWidth: 2, dash: [5, 4])
                )

                let arrowStart = viewPoint(from: guide.sourceAnchor, in: size)
                let arrowEnd = viewPoint(from: guide.targetAnchor, in: size)
                let deltaX = arrowEnd.x - arrowStart.x
                let deltaY = arrowEnd.y - arrowStart.y
                let length = hypot(deltaX, deltaY)
                if length >= 8 {
                    let unitX = deltaX / length
                    let unitY = deltaY / length
                    let arrowHeadLength = min(CGFloat(10), max(CGFloat(6), length * 0.22))
                    let arrowHeadWidth = arrowHeadLength * 0.62
                    let arrowBase = CGPoint(
                        x: arrowEnd.x - unitX * arrowHeadLength,
                        y: arrowEnd.y - unitY * arrowHeadLength
                    )
                    let perpendicularX = -unitY
                    let perpendicularY = unitX
                    var arrow = Path()
                    arrow.move(to: arrowStart)
                    arrow.addLine(to: arrowEnd)
                    arrow.move(to: arrowEnd)
                    arrow.addLine(to: CGPoint(
                        x: arrowBase.x + perpendicularX * arrowHeadWidth,
                        y: arrowBase.y + perpendicularY * arrowHeadWidth
                    ))
                    arrow.move(to: arrowEnd)
                    arrow.addLine(to: CGPoint(
                        x: arrowBase.x - perpendicularX * arrowHeadWidth,
                        y: arrowBase.y - perpendicularY * arrowHeadWidth
                    ))
                    context.stroke(
                        arrow,
                        with: .color(Color(nsColor: ImageEditorTheme.selected).opacity(0.96)),
                        style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                    )
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)

            let delta = CGSize(
                width: dragEnd.x - dragStart.x,
                height: dragEnd.y - dragStart.y
            )
            let movingBounds = selection.bounds.offsetBy(
                dx: delta.width,
                dy: delta.height
            )
            transformHUDOverlay(
                frame: movingBounds,
                viewRect: viewRect(from: movingBounds, in: size),
                mode: .patchTransfer(
                    delta: delta,
                    constrainedAxis: patchDragConstraintAxis
                ),
                canvasSize: size
            )
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

            ForEach(viewModel.selectedShapeGradientCanvasMidpointHandlePoints) { midpointPoint in
                shapeGradientMidpointHandleView(
                    midpointPoint,
                    position: viewPoint(from: midpointPoint.canvasPoint, in: canvasSize),
                    canvasSize: canvasSize
                )
            }

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

            ForEach(viewModel.selectedShapeGradientCanvasMidpointHandlePoints) { midpointPoint in
                shapeGradientMidpointHandleView(
                    midpointPoint,
                    position: viewPoint(from: midpointPoint.canvasPoint, in: canvasSize),
                    canvasSize: canvasSize
                )
            }

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

    private func shapeGradientMidpointHandleView(
        _ midpointPoint: ImageEditorShapeGradientMidpointHandlePoint,
        position: CGPoint,
        canvasSize: CGSize
    ) -> some View {
        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
            .fill(Color.white.opacity(0.92))
            .overlay {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .stroke(Color.black.opacity(0.72), lineWidth: 1)
            }
            .frame(width: 8, height: 8)
            .rotationEffect(.degrees(45))
            .position(position)
            .contentShape(Rectangle().inset(by: -7))
            .highPriorityGesture(
                DragGesture(
                    minimumDistance: 0,
                    coordinateSpace: .named("image-editor-canvas-space")
                )
                .onChanged { value in
                    selectedShapeGradientStopIndex = midpointPoint.lowerStopIndex
                    if activeShapeGradientMidpointIndex == nil,
                       viewModel.beginEditingSelectedShapeGradientMidpoint(
                           after: midpointPoint.lowerStopIndex
                       ) {
                        activeShapeGradientMidpointIndex = midpointPoint.lowerStopIndex
                    }
                    guard activeShapeGradientMidpointIndex == midpointPoint.lowerStopIndex else {
                        return
                    }
                    viewModel.updateSelectedShapeGradientMidpoint(
                        to: unboundedImagePoint(from: value.location, in: canvasSize)
                    )
                }
                .onEnded { value in
                    guard activeShapeGradientMidpointIndex == midpointPoint.lowerStopIndex else {
                        return
                    }
                    viewModel.updateSelectedShapeGradientMidpoint(
                        to: unboundedImagePoint(from: value.location, in: canvasSize)
                    )
                    viewModel.finishEditingSelectedShapeGradient()
                    activeShapeGradientMidpointIndex = nil
                }
            )
            .opacity(viewModel.canEditSelectedShapeGradientStops ? 1 : 0.55)
            .help(L10n.text("imageEditor.help.shapeGradientMidpointHandle"))
            .accessibilityLabel(
                L10n.format(
                    "imageEditor.properties.shapeGradientMidpointAccessibility",
                    midpointPoint.lowerStopIndex + 1,
                    Int((midpointPoint.midpoint * 100).rounded())
                )
            )
            .accessibilityIdentifier(
                "image-editor-shape-gradient-midpoint-\(midpointPoint.lowerStopIndex)"
            )
    }

    private func deleteSelectedGradientOverlayStopIfNeeded() -> Bool {
        guard viewModel.selectedLeftSidebarTab == .tools,
              canvasInteractionTool == .move,
              viewModel.document.areExtrasVisible,
              viewModel.canEditSelectedLayerGradientOverlayCanvasCenter,
              let selectedGradientOverlayStopIndex,
              let selectedHandle = viewModel.selectedLayerGradientOverlayCanvasStopHandlePoints.first(
                  where: { $0.index == selectedGradientOverlayStopIndex }
              )
        else { return false }
        if selectedHandle.isEndpoint {
            return true
        }
        return removeGradientOverlayCanvasStop(at: selectedGradientOverlayStopIndex)
    }

    private func resetSelectedGradientOverlayMidpointIfNeeded() -> Bool {
        guard viewModel.selectedLeftSidebarTab == .tools,
              canvasInteractionTool == .move,
              viewModel.document.areExtrasVisible,
              viewModel.canEditSelectedLayerGradientOverlayCanvasCenter,
              let index = selectedGradientOverlayMidpointIndex,
              viewModel.selectedLayerGradientOverlayCanvasMidpointHandlePoints.contains(
                  where: { $0.lowerStopIndex == index }
              )
        else { return false }
        viewModel.resetSelectedLayerGradientOverlayCanvasMidpoint(after: index)
        return true
    }

    private func nudgeSelectedGradientOverlayHandleIfNeeded(by delta: CGSize) -> Bool {
        guard viewModel.selectedLeftSidebarTab == .tools,
              canvasInteractionTool == .move,
              viewModel.document.areExtrasVisible,
              viewModel.canEditSelectedLayerGradientOverlayCanvasCenter
        else { return false }
        let action = ImageEditorGradientOverlayStopKeyboardAction.resolve(delta: delta)
        if let index = selectedGradientOverlayStopIndex,
           viewModel.selectedLayerGradientOverlayCanvasStopHandlePoints.contains(
               where: { $0.index == index }
           ) {
            applyGradientOverlayStopKeyboardAction(action, at: index)
            return true
        }
        if let index = selectedGradientOverlayMidpointIndex,
           viewModel.selectedLayerGradientOverlayCanvasMidpointHandlePoints.contains(
               where: { $0.lowerStopIndex == index }
           ) {
            applyGradientOverlayMidpointKeyboardAction(action, after: index)
            return true
        }
        return false
    }

    private func selectNextGradientOverlayCanvasHandle(movesBackward: Bool) -> Bool {
        guard viewModel.selectedLeftSidebarTab == .tools,
              canvasInteractionTool == .move,
              viewModel.document.areExtrasVisible,
              viewModel.canEditSelectedLayerGradientOverlayCanvasCenter
        else { return false }
        let current: ImageEditorGradientOverlayCanvasHandleSelection?
        if let index = selectedGradientOverlayStopIndex {
            current = .stop(index)
        } else if let index = selectedGradientOverlayMidpointIndex {
            current = .midpoint(after: index)
        } else {
            current = nil
        }
        guard let next = ImageEditorGradientOverlayCanvasHandleSelectionPolicy.next(
            current: current,
            stopCount: viewModel.selectedLayerGradientOverlayColorStops.count,
            isReversed: viewModel.selectedLayerGradientOverlayCanvasIsReversed,
            movesBackward: movesBackward
        ) else { return false }
        switch next {
        case .stop(let index):
            selectedGradientOverlayStopIndex = index
            selectedGradientOverlayMidpointIndex = nil
        case .midpoint(after: let index):
            selectedGradientOverlayStopIndex = nil
            selectedGradientOverlayMidpointIndex = index
        }
        return true
    }

    private func applyGradientOverlayStopKeyboardAction(
        _ action: ImageEditorGradientOverlayStopKeyboardAction,
        at index: Int
    ) {
        switch action {
        case .nudge(let displayedDelta):
            _ = viewModel.nudgeSelectedLayerGradientOverlayCanvasStop(
                at: index,
                displayedDelta: displayedDelta
            )
        case .consume:
            break
        }
    }

    private func applyGradientOverlayMidpointKeyboardAction(
        _ action: ImageEditorGradientOverlayStopKeyboardAction,
        after index: Int
    ) {
        switch action {
        case .nudge(let displayedDelta):
            _ = viewModel.nudgeSelectedLayerGradientOverlayCanvasMidpoint(
                after: index,
                displayedDelta: displayedDelta
            )
        case .consume:
            break
        }
    }

    @discardableResult
    private func removeGradientOverlayCanvasStop(at index: Int) -> Bool {
        guard viewModel.selectedLeftSidebarTab == .tools,
              canvasInteractionTool == .move,
              viewModel.document.areExtrasVisible,
              viewModel.canEditSelectedLayerGradientOverlayCanvasCenter,
              viewModel.selectedLayerGradientOverlayCanvasStopHandlePoints.contains(
                  where: { $0.index == index }
              ),
              let result = viewModel.removeSelectedLayerGradientOverlayCanvasStop(at: index)
        else { return false }
        selectedGradientOverlayStopIndex = result.nextSelectedIndex
        selectedGradientOverlayMidpointIndex = nil
        return true
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
    private func gradientOverlayCenterControlOverlay(in size: CGSize) -> some View {
        if viewModel.selectedLeftSidebarTab == .tools,
           canvasInteractionTool == .move,
           viewModel.document.areExtrasVisible,
           let geometry = viewModel.selectedLayerGradientOverlayCanvasGeometry {
            let center = viewPoint(from: geometry.center, in: size)
            let axisStart = viewPoint(from: geometry.axisStart, in: size)
            let axisEndpoint = viewPoint(from: geometry.axisEndpoint, in: size)
            let axisPath = Path { path in
                path.move(to: axisStart)
                path.addLine(to: axisEndpoint)
            }
            ZStack {
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
                            selectedGradientOverlayMidpointIndex = nil
                            selectedGradientOverlayStopIndex =
                                viewModel.addSelectedLayerGradientOverlayCanvasStop(
                                    at: unboundedImagePoint(from: value.location, in: size)
                                )
                        }
                    )
                    .allowsHitTesting(
                        viewModel.canEditSelectedLayerGradientOverlayCanvasCenter
                            && viewModel.selectedLayerGradientOverlayColorStops.count
                                < ImageEditorGradientFillContent.maximumColorStopCount
                    )
                    .help(L10n.text("imageEditor.help.gradientOverlayAxis"))
                    .accessibilityIdentifier("image-editor-gradient-overlay-axis")

                ForEach(viewModel.selectedLayerGradientOverlayCanvasStopHandlePoints) { point in
                    gradientOverlayStopHandleView(
                        point,
                        axisStart: axisStart,
                        axisEndpoint: axisEndpoint,
                        canvasSize: size
                    )
                }

                ForEach(
                    viewModel.selectedLayerGradientOverlayCanvasMidpointHandlePoints
                ) { point in
                    gradientOverlayMidpointHandleView(
                        point,
                        axisStart: axisStart,
                        axisEndpoint: axisEndpoint,
                        canvasSize: size
                    )
                }

                Circle()
                    .fill(Color.accentColor)
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.96), lineWidth: 1.5)
                        Circle()
                            .stroke(Color.black.opacity(0.62), lineWidth: 0.5)
                            .padding(-1)
                    }
                    .frame(width: 13, height: 13)
                    .position(axisEndpoint)
                    .contentShape(Circle().inset(by: -7))
                    .highPriorityGesture(
                        DragGesture(
                            minimumDistance: 0,
                            coordinateSpace: .named("image-editor-canvas-space")
                        )
                        .onChanged { value in
                            if let cancelledStart = cancelledGradientOverlayAxisDragStartLocation {
                                guard cancelledStart != value.startLocation else { return }
                                cancelledGradientOverlayAxisDragStartLocation = nil
                            }
                            if !isGradientOverlayAxisDragActive {
                                gradientOverlayAxisDragStartLocation = value.startLocation
                                guard viewModel.beginEditingSelectedLayerGradientOverlayCanvasAxis() else {
                                    gradientOverlayAxisDragStartLocation = nil
                                    return
                                }
                                isGradientOverlayAxisDragActive = true
                            }
                            viewModel.updateSelectedLayerGradientOverlayCanvasAxis(
                                to: unboundedImagePoint(from: value.location, in: size),
                                snappingAngle: NSEvent.modifierFlags.contains(.shift)
                            )
                        }
                        .onEnded { value in
                            defer {
                                isGradientOverlayAxisDragActive = false
                                gradientOverlayAxisDragStartLocation = nil
                            }
                            if cancelledGradientOverlayAxisDragStartLocation == value.startLocation {
                                cancelledGradientOverlayAxisDragStartLocation = nil
                                return
                            }
                            guard isGradientOverlayAxisDragActive else { return }
                            viewModel.updateSelectedLayerGradientOverlayCanvasAxis(
                                to: unboundedImagePoint(from: value.location, in: size),
                                snappingAngle: NSEvent.modifierFlags.contains(.shift)
                            )
                            viewModel.finishEditingSelectedLayerGradientOverlayCanvasAxis()
                        }
                    )
                    .allowsHitTesting(viewModel.canEditSelectedLayerGradientOverlayCanvasCenter)
                    .opacity(viewModel.canEditSelectedLayerGradientOverlayCanvasCenter ? 1 : 0.55)
                    .help(L10n.text("imageEditor.help.gradientOverlayAxisHandle"))
                    .accessibilityIdentifier("image-editor-gradient-overlay-axis-handle")

                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.62))
                    Circle()
                        .stroke(Color.white.opacity(0.96), lineWidth: 1.5)
                    Rectangle()
                        .fill(Color.white.opacity(0.96))
                        .frame(width: 12, height: 1)
                    Rectangle()
                        .fill(Color.white.opacity(0.96))
                        .frame(width: 1, height: 12)
                }
                .frame(width: 16, height: 16)
                .position(center)
                .contentShape(Circle().inset(by: -7))
                .highPriorityGesture(
                    DragGesture(
                        minimumDistance: 0,
                        coordinateSpace: .named("image-editor-canvas-space")
                    )
                    .onChanged { value in
                        if let cancelledStart = cancelledGradientOverlayCenterDragStartLocation {
                            guard cancelledStart != value.startLocation else { return }
                            cancelledGradientOverlayCenterDragStartLocation = nil
                        }
                        if !isGradientOverlayCenterDragActive {
                            gradientOverlayCenterDragStartLocation = value.startLocation
                            guard viewModel.beginEditingSelectedLayerGradientOverlayCanvasCenter() else {
                                gradientOverlayCenterDragStartLocation = nil
                                return
                            }
                            isGradientOverlayCenterDragActive = true
                        }
                        viewModel.updateSelectedLayerGradientOverlayCanvasCenter(
                            to: unboundedImagePoint(from: value.location, in: size)
                        )
                    }
                    .onEnded { value in
                        defer {
                            isGradientOverlayCenterDragActive = false
                            gradientOverlayCenterDragStartLocation = nil
                        }
                        if cancelledGradientOverlayCenterDragStartLocation == value.startLocation {
                            cancelledGradientOverlayCenterDragStartLocation = nil
                            return
                        }
                        guard isGradientOverlayCenterDragActive else { return }
                        viewModel.updateSelectedLayerGradientOverlayCanvasCenter(
                            to: unboundedImagePoint(from: value.location, in: size)
                        )
                        viewModel.finishEditingSelectedLayerGradientOverlayCanvasCenter()
                    }
                )
                .allowsHitTesting(viewModel.canEditSelectedLayerGradientOverlayCanvasCenter)
                .opacity(viewModel.canEditSelectedLayerGradientOverlayCanvasCenter ? 1 : 0.55)
                .help(L10n.text("imageEditor.help.gradientOverlayCenterHandle"))
                .accessibilityIdentifier("image-editor-gradient-overlay-center-handle")
            }
        }
    }

    private func gradientOverlayStopHandleView(
        _ point: ImageEditorGradientOverlayStopHandlePoint,
        axisStart: CGPoint,
        axisEndpoint: CGPoint,
        canvasSize: CGSize
    ) -> some View {
        let isSelected = selectedGradientOverlayStopIndex == point.index
        let isEndpoint = point.isEndpoint
        let isBeingRemoved = activeGradientOverlayStopIndex == point.index
            && isGradientOverlayStopDragRemovalPreview
        let axis = CGVector(dx: axisEndpoint.x - axisStart.x, dy: axisEndpoint.y - axisStart.y)
        let length = max(0.001, hypot(axis.dx, axis.dy))
        let canvasPosition = viewPoint(from: point.canvasPoint, in: canvasSize)
        let perpendicularOffset: CGFloat = isEndpoint ? 20 : 14
        let position = CGPoint(
            x: canvasPosition.x - axis.dy / length * perpendicularOffset,
            y: canvasPosition.y + axis.dx / length * perpendicularOffset
        )
        return RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(
                isBeingRemoved
                    ? Color.red.opacity(0.82)
                    : Color(nsColor: point.stop.color)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .stroke(
                        isSelected ? Color.accentColor : Color.white.opacity(0.96),
                        lineWidth: isSelected ? 2 : 1.5
                    )
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .stroke(Color.black.opacity(0.62), lineWidth: 0.5)
                    .padding(-1)
            }
            .frame(width: 12, height: 12)
            .rotationEffect(.degrees(45))
            .position(position)
            .contentShape(Rectangle().inset(by: isEndpoint ? -3 : -7))
            .highPriorityGesture(
                DragGesture(
                    minimumDistance: 0,
                    coordinateSpace: .named("image-editor-canvas-space")
                )
                .onChanged { value in
                    if activeGradientOverlayStopIndex == nil,
                       gradientOverlayStopDragStartLocation == nil {
                        selectedGradientOverlayStopIndex = point.index
                        selectedGradientOverlayMidpointIndex = nil
                    }
                    guard !isEndpoint else { return }
                    if let cancelledStart = cancelledGradientOverlayStopDragStartLocation {
                        guard cancelledStart != value.startLocation else { return }
                        cancelledGradientOverlayStopDragStartLocation = nil
                    }
                    if gradientOverlayStopDragStartLocation == nil {
                        gradientOverlayStopDragStartLocation = value.startLocation
                        gradientOverlayStopDragDuplicates = NSEvent.modifierFlags.contains(.option)
                    }
                    if activeGradientOverlayStopIndex == nil {
                        if gradientOverlayStopDragDuplicates {
                            guard ImageEditorGradientOverlayStopDuplicateGesturePolicy
                                .hasStartedDrag(
                                    from: value.startLocation,
                                    to: value.location
                                )
                            else { return }
                            guard let duplicateIndex = viewModel
                                .beginDuplicatingSelectedLayerGradientOverlayCanvasStop(
                                    at: point.index,
                                    toward: unboundedImagePoint(
                                        from: value.location,
                                        in: canvasSize
                                    )
                                )
                            else {
                                activeGradientOverlayStopIndex = point.index
                                isGradientOverlayStopDuplicateDragBlocked = true
                                return
                            }
                            selectedGradientOverlayStopIndex = duplicateIndex
                        } else if !viewModel.beginEditingSelectedLayerGradientOverlayCanvasStop(
                            at: point.index
                        ) {
                            gradientOverlayStopDragStartLocation = nil
                            return
                        }
                        activeGradientOverlayStopIndex = point.index
                    }
                    guard activeGradientOverlayStopIndex == point.index,
                          !isGradientOverlayStopDuplicateDragBlocked
                    else { return }
                    isGradientOverlayStopDragRemovalPreview =
                        ImageEditorGradientOverlayStopRemovalGesturePolicy.shouldRemove(
                            pointer: value.location,
                            axisStart: axisStart,
                            axisEnd: axisEndpoint
                        )
                    guard !isGradientOverlayStopDragRemovalPreview else { return }
                    selectedGradientOverlayStopIndex = viewModel
                        .updateSelectedLayerGradientOverlayCanvasStop(
                            to: unboundedImagePoint(from: value.location, in: canvasSize),
                            snappingToStep: NSEvent.modifierFlags.contains(.shift)
                        )
                }
                .onEnded { value in
                    defer {
                        activeGradientOverlayStopIndex = nil
                        gradientOverlayStopDragStartLocation = nil
                        gradientOverlayStopDragDuplicates = false
                        isGradientOverlayStopDuplicateDragBlocked = false
                        isGradientOverlayStopDragRemovalPreview = false
                    }
                    if cancelledGradientOverlayStopDragStartLocation == value.startLocation {
                        cancelledGradientOverlayStopDragStartLocation = nil
                        return
                    }
                    guard activeGradientOverlayStopIndex == point.index,
                          !isGradientOverlayStopDuplicateDragBlocked
                    else { return }
                    let shouldRemove = ImageEditorGradientOverlayStopRemovalGesturePolicy
                        .shouldRemove(
                            pointer: value.location,
                            axisStart: axisStart,
                            axisEnd: axisEndpoint
                        )
                    if shouldRemove {
                        selectedGradientOverlayStopIndex = viewModel
                            .removeEditingSelectedLayerGradientOverlayCanvasStop()
                    } else {
                        selectedGradientOverlayStopIndex = viewModel
                            .updateSelectedLayerGradientOverlayCanvasStop(
                                to: unboundedImagePoint(from: value.location, in: canvasSize),
                                snappingToStep: NSEvent.modifierFlags.contains(.shift)
                            )
                    }
                    viewModel.finishEditingSelectedLayerGradientOverlayCanvasStop()
                }
            )
            .simultaneousGesture(
                SpatialTapGesture(
                    count: 2,
                    coordinateSpace: .named("image-editor-canvas-space")
                )
                .onEnded { _ in
                    requestGradientOverlayCanvasStopColorEditing(at: point.index)
                }
            )
            .zIndex(isEndpoint ? 2 : 0)
            .allowsHitTesting(viewModel.canEditSelectedLayerGradientOverlayCanvasCenter)
            .opacity(viewModel.canEditSelectedLayerGradientOverlayCanvasCenter ? 1 : 0.55)
            .contextMenu {
                if !isEndpoint {
                    Button(role: .destructive) {
                        _ = removeGradientOverlayCanvasStop(at: point.index)
                    } label: {
                        Label(
                            L10n.text("imageEditor.action.shapeGradientStopRemove"),
                            systemImage: "trash"
                        )
                    }
                }
            }
            .help(L10n.text(
                isEndpoint
                    ? "imageEditor.help.gradientOverlayEndpointHandle"
                    : "imageEditor.help.gradientOverlayStopHandle"
            ))
            .accessibilityLabel(
                L10n.format(
                    "imageEditor.properties.shapeGradientStopAccessibility",
                    point.index + 1,
                    Int(
                        ((viewModel.selectedLayerGradientOverlayCanvasIsReversed
                            ? 1 - point.stop.position
                            : point.stop.position) * 100).rounded()
                    ),
                    Int((point.stop.alpha * 100).rounded())
                )
            )
            .accessibilityIdentifier(
                "image-editor-gradient-overlay-canvas-stop-\(point.index)"
            )
    }

    private func gradientOverlayMidpointHandleView(
        _ point: ImageEditorGradientOverlayMidpointHandlePoint,
        axisStart: CGPoint,
        axisEndpoint: CGPoint,
        canvasSize: CGSize
    ) -> some View {
        let isSelected = selectedGradientOverlayMidpointIndex == point.lowerStopIndex
        let axis = CGVector(dx: axisEndpoint.x - axisStart.x, dy: axisEndpoint.y - axisStart.y)
        let length = max(0.001, hypot(axis.dx, axis.dy))
        let canvasPosition = viewPoint(from: point.canvasPoint, in: canvasSize)
        let position = CGPoint(
            x: canvasPosition.x + axis.dy / length * 14,
            y: canvasPosition.y - axis.dx / length * 14
        )
        return RoundedRectangle(cornerRadius: 1.5, style: .continuous)
            .fill(Color.white.opacity(0.92))
            .overlay {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .stroke(
                        isSelected ? Color.accentColor : Color.black.opacity(0.72),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
            .frame(width: 8, height: 8)
            .rotationEffect(.degrees(45))
            .position(position)
            .contentShape(Rectangle().inset(by: -7))
            .highPriorityGesture(
                DragGesture(
                    minimumDistance: 0,
                    coordinateSpace: .named("image-editor-canvas-space")
                )
                .onChanged { value in
                    selectedGradientOverlayStopIndex = nil
                    selectedGradientOverlayMidpointIndex = point.lowerStopIndex
                    if let cancelledStart = cancelledGradientOverlayMidpointDragStartLocation {
                        guard cancelledStart != value.startLocation else { return }
                        cancelledGradientOverlayMidpointDragStartLocation = nil
                    }
                    if activeGradientOverlayMidpointIndex == nil {
                        gradientOverlayMidpointDragStartLocation = value.startLocation
                        guard viewModel.beginEditingSelectedLayerGradientOverlayCanvasMidpoint(
                            after: point.lowerStopIndex
                        ) else {
                            gradientOverlayMidpointDragStartLocation = nil
                            return
                        }
                        activeGradientOverlayMidpointIndex = point.lowerStopIndex
                    }
                    guard activeGradientOverlayMidpointIndex == point.lowerStopIndex else {
                        return
                    }
                    viewModel.updateSelectedLayerGradientOverlayCanvasMidpoint(
                        to: unboundedImagePoint(from: value.location, in: canvasSize),
                        snappingToStep: NSEvent.modifierFlags.contains(.shift)
                    )
                }
                .onEnded { value in
                    defer {
                        activeGradientOverlayMidpointIndex = nil
                        gradientOverlayMidpointDragStartLocation = nil
                    }
                    if cancelledGradientOverlayMidpointDragStartLocation
                        == value.startLocation {
                        cancelledGradientOverlayMidpointDragStartLocation = nil
                        return
                    }
                    guard activeGradientOverlayMidpointIndex == point.lowerStopIndex else {
                        return
                    }
                    viewModel.updateSelectedLayerGradientOverlayCanvasMidpoint(
                        to: unboundedImagePoint(from: value.location, in: canvasSize),
                        snappingToStep: NSEvent.modifierFlags.contains(.shift)
                    )
                    viewModel.finishEditingSelectedLayerGradientOverlayCanvasMidpoint()
                }
            )
            .simultaneousGesture(
                SpatialTapGesture(
                    count: 2,
                    coordinateSpace: .named("image-editor-canvas-space")
                )
                .onEnded { _ in
                    resetGradientOverlayCanvasMidpoint(after: point.lowerStopIndex)
                }
            )
            .contextMenu {
                Button(L10n.text("imageEditor.action.resetGradientOverlayMidpoint")) {
                    resetGradientOverlayCanvasMidpoint(after: point.lowerStopIndex)
                }
                .disabled(abs(point.midpoint - 0.5) < 0.000_001)
            }
            .allowsHitTesting(viewModel.canEditSelectedLayerGradientOverlayCanvasCenter)
            .opacity(viewModel.canEditSelectedLayerGradientOverlayCanvasCenter ? 1 : 0.55)
            .help(L10n.text("imageEditor.help.gradientOverlayMidpointHandle"))
            .accessibilityLabel(
                L10n.format(
                    "imageEditor.properties.shapeGradientMidpointAccessibility",
                    point.lowerStopIndex + 1,
                    Int((point.midpoint * 100).rounded())
                )
            )
            .accessibilityIdentifier(
                "image-editor-gradient-overlay-canvas-midpoint-\(point.lowerStopIndex)"
            )
    }

    private func resetGradientOverlayCanvasMidpoint(after lowerStopIndex: Int) {
        selectedGradientOverlayStopIndex = nil
        selectedGradientOverlayMidpointIndex = lowerStopIndex
        DispatchQueue.main.async {
            guard selectedGradientOverlayMidpointIndex == lowerStopIndex else { return }
            viewModel.resetSelectedLayerGradientOverlayCanvasMidpoint(after: lowerStopIndex)
        }
    }

    @discardableResult
    private func cancelGradientOverlayCanvasHandleDragForLifecycle() -> Bool {
        let cancelledMidpoint = cancelGradientOverlayMidpointDragForLifecycle()
        let cancelledStop = cancelGradientOverlayStopDragForLifecycle()
        let cancelledAxis = cancelGradientOverlayAxisDragForLifecycle()
        let cancelledCenter = cancelGradientOverlayCenterDragForLifecycle()
        return cancelledMidpoint || cancelledStop || cancelledAxis || cancelledCenter
    }

    @discardableResult
    private func cancelGradientOverlayCenterDragForLifecycle() -> Bool {
        let hadActiveDrag = isGradientOverlayCenterDragActive
            || viewModel.hasActiveGradientOverlayCenterTransaction
        guard hadActiveDrag else { return false }
        cancelledGradientOverlayCenterDragStartLocation = gradientOverlayCenterDragStartLocation
        isGradientOverlayCenterDragActive = false
        gradientOverlayCenterDragStartLocation = nil
        _ = viewModel.cancelEditingSelectedLayerGradientOverlayCanvasCenter()
        return true
    }

    @discardableResult
    private func cancelGradientOverlayAxisDragForLifecycle() -> Bool {
        let hadActiveDrag = isGradientOverlayAxisDragActive
            || viewModel.hasActiveGradientOverlayAxisTransaction
        guard hadActiveDrag else { return false }
        cancelledGradientOverlayAxisDragStartLocation = gradientOverlayAxisDragStartLocation
        isGradientOverlayAxisDragActive = false
        gradientOverlayAxisDragStartLocation = nil
        _ = viewModel.cancelEditingSelectedLayerGradientOverlayCanvasAxis()
        return true
    }

    @discardableResult
    private func cancelGradientOverlayStopDragForLifecycle() -> Bool {
        let hadActiveDrag = activeGradientOverlayStopIndex != nil
            || gradientOverlayStopDragStartLocation != nil
            || viewModel.hasActiveGradientOverlayStopTransaction
        guard hadActiveDrag else { return false }
        cancelledGradientOverlayStopDragStartLocation = gradientOverlayStopDragStartLocation
        activeGradientOverlayStopIndex = nil
        gradientOverlayStopDragStartLocation = nil
        gradientOverlayStopDragDuplicates = false
        isGradientOverlayStopDuplicateDragBlocked = false
        isGradientOverlayStopDragRemovalPreview = false
        _ = viewModel.cancelEditingSelectedLayerGradientOverlayCanvasStop()
        return true
    }

    @discardableResult
    private func cancelGradientOverlayMidpointDragForLifecycle() -> Bool {
        let hadActiveDrag = activeGradientOverlayMidpointIndex != nil
            || viewModel.hasActiveGradientOverlayMidpointTransaction
        guard hadActiveDrag else { return false }
        cancelledGradientOverlayMidpointDragStartLocation =
            gradientOverlayMidpointDragStartLocation
        activeGradientOverlayMidpointIndex = nil
        gradientOverlayMidpointDragStartLocation = nil
        _ = viewModel.cancelEditingSelectedLayerGradientOverlayCanvasMidpoint()
        return true
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

    private func figmaSizeConstraintEditorRow(
        _ field: XomoFigmaSizeConstraintField
    ) -> some View {
        let hasLocalOverride = viewModel.hasSelectedFigmaSizeConstraintOverride(field)
        return HStack(spacing: 7) {
            HStack(spacing: 4) {
                Text(L10n.text(field.localizationKey))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                if hasLocalOverride {
                    Circle()
                        .fill(Color(nsColor: ImageEditorTheme.selected))
                        .frame(width: 5, height: 5)
                        .accessibilityHidden(true)
                }
            }
            .frame(minWidth: 76, alignment: .leading)
            Spacer(minLength: 4)
            TextField(
                L10n.text("imageEditor.properties.figmaSizeConstraintUnset"),
                text: figmaSizeConstraintDraftBinding(field)
            )
            .textFieldStyle(.roundedBorder)
            .font(.system(size: 10, design: .monospaced))
            .frame(width: 88)
            .focused($focusedFigmaSizeConstraintField, equals: field)
            .onSubmit {
                commitFigmaSizeConstraintDraft(field)
                focusedFigmaSizeConstraintField = nil
            }
            .onChange(of: focusedFigmaSizeConstraintField) { focusedField in
                if focusedField != field {
                    commitFigmaSizeConstraintDraft(field)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(
                        hasLocalOverride
                            ? Color(nsColor: ImageEditorTheme.selected).opacity(0.75)
                            : Color.clear,
                        lineWidth: 1
                    )
            )
            .accessibilityIdentifier("image-editor-figma-size-constraint-\(field.rawValue)-field")

            Text(L10n.text("imageEditor.properties.pixelUnit"))
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))

            Button {
                viewModel.setSelectedFigmaSizeConstraint(field, value: nil)
                syncFigmaSizeConstraintDraft(field)
            } label: {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(EditorIconButtonStyle(isSelected: false))
            .focusable(false)
            .disabled(selectedFigmaSizeConstraintValue(field) == nil)
            .help(L10n.text("imageEditor.action.clearFigmaSizeConstraint"))
            .accessibilityLabel(L10n.text("imageEditor.action.clearFigmaSizeConstraint"))
            .accessibilityIdentifier("image-editor-figma-size-constraint-\(field.rawValue)-clear")

            if hasLocalOverride {
                Button {
                    focusedFigmaSizeConstraintField = nil
                    viewModel.resetSelectedFigmaSizeConstraint(field)
                    syncFigmaSizeConstraintDraft(field)
                } label: {
                    Image(systemName: "arrow.uturn.backward.circle")
                }
                .buttonStyle(EditorIconButtonStyle(isSelected: false))
                .focusable(false)
                .help(L10n.text("imageEditor.action.resetFigmaSizeConstraint"))
                .accessibilityLabel(L10n.text("imageEditor.action.resetFigmaSizeConstraint"))
                .accessibilityIdentifier("image-editor-figma-size-constraint-\(field.rawValue)-reset")
            }
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
                            if viewModel.selectedLayerOpenableFigmaSourceURL != nil {
                                Button(L10n.text("imageEditor.action.openFigmaSourceURL")) {
                                    viewModel.openSelectedFigmaSourceURL()
                                }
                                .buttonStyle(EditorTextButtonStyle())
                                .focusable(false)
                                .accessibilityIdentifier("image-editor-open-figma-source-url")
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

                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 6) {
                                Text(L10n.text("imageEditor.properties.figmaSizeConstraints"))
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                                Spacer(minLength: 4)
                                if viewModel.hasSelectedFigmaSizeConstraintOverrides {
                                    Button(L10n.text("imageEditor.action.resetAllFigmaSizeConstraints")) {
                                        focusedFigmaSizeConstraintField = nil
                                        viewModel.resetAllSelectedFigmaSizeConstraints()
                                        syncFigmaSizeConstraintDrafts()
                                    }
                                    .buttonStyle(EditorTextButtonStyle())
                                    .focusable(false)
                                    .accessibilityIdentifier("image-editor-figma-size-constraints-reset-all")
                                }
                            }
                            ForEach(XomoFigmaSizeConstraintField.allCases, id: \.self) { field in
                                figmaSizeConstraintEditorRow(field)
                            }
                            if viewModel.selectedLayerFigmaSizeConstraintConflicts.count > 1 {
                                HStack {
                                    Spacer(minLength: 0)
                                    Button(L10n.text("imageEditor.action.resolveAllFigmaSizeConstraintConflicts")) {
                                        focusedFigmaSizeConstraintField = nil
                                        viewModel.resolveAllSelectedFigmaSizeConstraintConflicts()
                                        syncFigmaSizeConstraintDrafts()
                                    }
                                    .buttonStyle(EditorTextButtonStyle())
                                    .focusable(false)
                                    .accessibilityIdentifier(
                                        "image-editor-figma-size-constraint-conflicts-resolve-all"
                                    )
                                }
                            }
                            ForEach(viewModel.selectedLayerFigmaSizeConstraintConflicts, id: \.self) { conflict in
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Label(
                                        L10n.text(conflict.localizationKey),
                                        systemImage: "exclamationmark.triangle.fill"
                                    )
                                    .font(.system(size: 9))
                                    .foregroundStyle(Color.orange.opacity(0.92))
                                    .fixedSize(horizontal: false, vertical: true)
                                    Spacer(minLength: 4)
                                    Button(L10n.text("imageEditor.action.resolveFigmaSizeConstraintConflict")) {
                                        focusedFigmaSizeConstraintField = nil
                                        viewModel.resolveSelectedFigmaSizeConstraintConflict(conflict)
                                        syncFigmaSizeConstraintDrafts()
                                    }
                                    .buttonStyle(EditorTextButtonStyle())
                                    .focusable(false)
                                    .accessibilityIdentifier(
                                        "image-editor-figma-size-constraint-conflict-\(conflict.rawValue)-resolve"
                                    )
                                }
                                .accessibilityIdentifier(
                                    "image-editor-figma-size-constraint-conflict-\(conflict.rawValue)"
                                )
                            }
                            Text(L10n.text("imageEditor.properties.figmaSizeConstraintsActive"))
                                .font(.system(size: 9))
                                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .accessibilityIdentifier("image-editor-figma-size-constraints")
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
                            .disabled(!viewModel.canFillCurrentEditingTarget)
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
                if viewModel.selectedFilter != .gaussianBlur
                    && viewModel.selectedFilter != .sharpen
                    && viewModel.selectedFilter != .minimum
                    && viewModel.selectedFilter != .maximum
                    && viewModel.selectedFilter != .highPass
                    && viewModel.selectedFilter != .findEdges
                    && viewModel.selectedFilter != .pixelate
                    && viewModel.selectedFilter != .motionBlur
                    && viewModel.selectedFilter != .emboss
                    && viewModel.selectedFilter != .addNoise
                    && viewModel.selectedFilter != .unsharpMask
                    && viewModel.selectedFilter != .oilPaint
                    && viewModel.selectedFilter != .vignette
                    && viewModel.selectedFilter != .lensCorrection
                    && viewModel.selectedFilter != .pinch
                    && viewModel.selectedFilter != .spherize
                    && viewModel.selectedFilter != .liquifyPuckerBloat
                    && viewModel.selectedFilter != .ripple
                    && viewModel.selectedFilter != .wave
                    && viewModel.selectedFilter != .liquifyTwirl
                    && viewModel.selectedFilter != .liquifyPush
                    && viewModel.selectedFilter != .offset {
                    Slider(value: $viewModel.filterIntensity, in: 0...1, step: 0.05)
                }
                if viewModel.selectedFilter == .gaussianBlur {
                    HStack {
                        Text(L10n.text("imageEditor.filter.gaussianBlurRadius"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        Slider(
                            value: Binding(
                                get: { viewModel.filterGaussianBlurEffectiveRadius },
                                set: { viewModel.filterGaussianBlurEffectiveRadius = $0 }
                            ),
                            in: 0.1...1_000,
                            step: 0.1
                        )
                        Text(L10n.format(
                            "imageEditor.filter.gaussianBlurRadiusValue",
                            String(format: "%.1f", viewModel.filterGaussianBlurEffectiveRadius)
                        ))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                            .frame(width: 60, alignment: .trailing)
                    }
                    .accessibilityIdentifier("image-editor-filter-gaussian-blur-radius")
                }
                if viewModel.selectedFilter == .sharpen {
                    HStack {
                        Text(L10n.text("imageEditor.filter.unsharpAmount"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        Slider(
                            value: Binding(
                                get: { viewModel.filterSharpenEffectiveAmountPercent },
                                set: { viewModel.filterSharpenEffectiveAmountPercent = $0 }
                            ),
                            in: 0...200,
                            step: 1
                        )
                        Text(L10n.format(
                            "imageEditor.filter.unsharpAmountValue",
                            Int(viewModel.filterSharpenEffectiveAmountPercent.rounded())
                        ))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                            .frame(width: 54, alignment: .trailing)
                    }
                    .accessibilityIdentifier("image-editor-filter-sharpen-amount")
                }
                if viewModel.selectedFilter == .pixelate {
                    HStack {
                        Text(L10n.text("imageEditor.filter.pixelateCellSize"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        Slider(value: $viewModel.filterPixelateCellSize, in: 2...200, step: 1)
                        Text(L10n.format(
                            "imageEditor.filter.pixelateCellSizeValue",
                            Int(viewModel.filterPixelateCellSize.rounded())
                        ))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                            .frame(width: 54, alignment: .trailing)
                    }
                    .accessibilityIdentifier("image-editor-filter-pixelate-cell-size")
                }
                if viewModel.selectedFilter == .addNoise {
                    HStack {
                        Text(L10n.text("imageEditor.filter.addNoiseAmount"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        Slider(
                            value: Binding(
                                get: { viewModel.filterAddNoiseEffectiveAmountPercent },
                                set: { viewModel.filterAddNoiseEffectiveAmountPercent = $0 }
                            ),
                            in: 0.1...400,
                            step: 0.1
                        )
                        Text(L10n.format(
                            "imageEditor.filter.addNoiseAmountValue",
                            String(format: "%.1f", viewModel.filterAddNoiseEffectiveAmountPercent)
                        ))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                            .frame(width: 62, alignment: .trailing)
                    }
                    .accessibilityIdentifier("image-editor-filter-add-noise-amount")
                    Picker(
                        L10n.text("imageEditor.filter.addNoiseDistribution"),
                        selection: $viewModel.filterAddNoiseDistribution
                    ) {
                        ForEach(ImageEditorAddNoiseDistribution.allCases) { distribution in
                            Text(distribution.title).tag(distribution)
                        }
                    }
                    .pickerStyle(.segmented)
                    .font(.system(size: 10))
                    .accessibilityIdentifier("image-editor-filter-add-noise-distribution")
                    Toggle(
                        L10n.text("imageEditor.filter.addNoiseMonochromatic"),
                        isOn: $viewModel.filterAddNoiseMonochromatic
                    )
                    .toggleStyle(.switch)
                    .font(.system(size: 10))
                    .focusable(false)
                    .accessibilityIdentifier("image-editor-filter-add-noise-monochromatic")
                }
                if viewModel.selectedFilter == .vignette {
                    HStack {
                        Text(L10n.text("imageEditor.filter.vignetteAmount"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        Slider(
                            value: Binding(
                                get: { viewModel.filterVignetteEffectiveAmountPercent },
                                set: { viewModel.filterVignetteEffectiveAmountPercent = $0 }
                            ),
                            in: -100...100,
                            step: 1
                        )
                        Text(L10n.format(
                            "imageEditor.filter.vignetteAmountValue",
                            String(format: "%+d", Int(viewModel.filterVignetteEffectiveAmountPercent.rounded()))
                        ))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                            .frame(width: 52, alignment: .trailing)
                    }
                    .accessibilityIdentifier("image-editor-filter-vignette-amount")
                    HStack {
                        Text(L10n.text("imageEditor.filter.vignetteMidpoint"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        Slider(value: $viewModel.filterVignetteMidpoint, in: 0...0.95, step: 0.01)
                        Text(L10n.format(
                            "imageEditor.filter.vignetteMidpointValue",
                            Int((viewModel.filterVignetteMidpoint * 100).rounded())
                        ))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                            .frame(width: 48, alignment: .trailing)
                    }
                    .accessibilityIdentifier("image-editor-filter-vignette-midpoint")
                }
                if viewModel.selectedFilter == .oilPaint {
                    HStack {
                        Text(L10n.text("imageEditor.filter.oilPaintRadius"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        Slider(value: $viewModel.filterOilPaintRadius, in: 1...10, step: 1)
                        Text(L10n.format(
                            "imageEditor.filter.oilPaintRadiusValue",
                            Int(viewModel.filterOilPaintRadius.rounded())
                        ))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                            .frame(width: 48, alignment: .trailing)
                    }
                    .accessibilityIdentifier("image-editor-filter-oil-paint-radius")
                    HStack {
                        Text(L10n.text("imageEditor.filter.oilPaintTonalLevels"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        Slider(value: $viewModel.filterOilPaintTonalLevels, in: 6...18, step: 1)
                        Text(L10n.format(
                            "imageEditor.filter.oilPaintTonalLevelsValue",
                            Int(viewModel.filterOilPaintTonalLevels.rounded())
                        ))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                            .frame(width: 48, alignment: .trailing)
                    }
                    .accessibilityIdentifier("image-editor-filter-oil-paint-tonal-levels")
                    HStack {
                        Text(L10n.text("imageEditor.filter.oilPaintStylization"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        Slider(value: $viewModel.filterOilPaintStylization, in: 0...10, step: 0.1)
                        Text(L10n.format(
                            "imageEditor.filter.oilPaintStylizationValue",
                            String(format: "%.1f", viewModel.filterOilPaintStylization)
                        ))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                            .frame(width: 48, alignment: .trailing)
                    }
                    .accessibilityIdentifier("image-editor-filter-oil-paint-stylization")
                    HStack {
                        Text(L10n.text("imageEditor.filter.oilPaintCleanliness"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        Slider(value: $viewModel.filterOilPaintCleanliness, in: 0...10, step: 0.1)
                        Text(L10n.format(
                            "imageEditor.filter.oilPaintCleanlinessValue",
                            String(format: "%.1f", viewModel.filterOilPaintCleanliness)
                        ))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                            .frame(width: 48, alignment: .trailing)
                    }
                    .accessibilityIdentifier("image-editor-filter-oil-paint-cleanliness")
                    HStack {
                        Text(L10n.text("imageEditor.filter.oilPaintBristleDetail"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        Slider(value: $viewModel.filterOilPaintBristleDetail, in: 0...10, step: 0.1)
                        Text(L10n.format(
                            "imageEditor.filter.oilPaintBristleDetailValue",
                            String(format: "%.1f", viewModel.filterOilPaintBristleDetail)
                        ))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                            .frame(width: 48, alignment: .trailing)
                    }
                    .accessibilityIdentifier("image-editor-filter-oil-paint-bristle-detail")
                    Toggle(
                        L10n.text("imageEditor.filter.oilPaintLightingEnabled"),
                        isOn: $viewModel.filterOilPaintLightingEnabled
                    )
                    .toggleStyle(.checkbox)
                    .accessibilityIdentifier("image-editor-filter-oil-paint-lighting-enabled")
                    HStack {
                        Text(L10n.text("imageEditor.filter.oilPaintShine"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        Slider(value: $viewModel.filterOilPaintShine, in: 0...10, step: 0.1)
                        Text(L10n.format(
                            "imageEditor.filter.oilPaintShineValue",
                            String(format: "%.1f", viewModel.filterOilPaintShine)
                        ))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                            .frame(width: 48, alignment: .trailing)
                    }
                    .accessibilityIdentifier("image-editor-filter-oil-paint-shine")
                    .disabled(!viewModel.filterOilPaintLightingEnabled)
                    HStack {
                        Text(L10n.text("imageEditor.filter.oilPaintLightingAngle"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        Slider(value: $viewModel.filterOilPaintLightingAngleDegrees, in: -180...180, step: 1)
                        Text(L10n.format(
                            "imageEditor.filter.oilPaintLightingAngleValue",
                            Int(viewModel.filterOilPaintLightingAngleDegrees.rounded())
                        ))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                            .frame(width: 48, alignment: .trailing)
                    }
                    .accessibilityIdentifier("image-editor-filter-oil-paint-lighting-angle")
                    .disabled(!viewModel.filterOilPaintLightingEnabled)
                }
                if viewModel.selectedFilter == .motionBlur {
                    HStack {
                        Text(L10n.text("imageEditor.filter.motionBlurAngle"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        Slider(value: $viewModel.filterMotionBlurAngleDegrees, in: -180...180, step: 1)
                        Text(L10n.format(
                            "imageEditor.filter.motionBlurAngleValue",
                            Int(viewModel.filterMotionBlurAngleDegrees.rounded())
                        ))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                            .frame(width: 54, alignment: .trailing)
                    }
                    .accessibilityIdentifier("image-editor-filter-motion-blur-angle")
                    HStack {
                        Text(L10n.text("imageEditor.filter.motionBlurDistance"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        Slider(value: $viewModel.filterMotionBlurDistance, in: 1...999, step: 1)
                        Text(L10n.format(
                            "imageEditor.filter.motionBlurDistanceValue",
                            Int(viewModel.filterMotionBlurDistance.rounded())
                        ))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                            .frame(width: 54, alignment: .trailing)
                    }
                    .accessibilityIdentifier("image-editor-filter-motion-blur-distance")
                }
                if viewModel.selectedFilter == .unsharpMask {
                    HStack {
                        Text(L10n.text("imageEditor.filter.unsharpAmount"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        Slider(
                            value: Binding(
                                get: { viewModel.filterUnsharpEffectiveAmountPercent },
                                set: { viewModel.filterUnsharpEffectiveAmountPercent = $0 }
                            ),
                            in: 1...500,
                            step: 1
                        )
                        Text(L10n.format(
                            "imageEditor.filter.unsharpAmountValue",
                            Int(viewModel.filterUnsharpEffectiveAmountPercent.rounded())
                        ))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                            .frame(width: 54, alignment: .trailing)
                    }
                    .accessibilityIdentifier("image-editor-filter-unsharp-amount")
                    HStack {
                        Text(L10n.text("imageEditor.filter.unsharpRadius"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        Slider(
                            value: Binding(
                                get: { viewModel.filterUnsharpEffectiveRadiusPixels },
                                set: { viewModel.filterUnsharpEffectiveRadiusPixels = $0 }
                            ),
                            in: 0.1...250,
                            step: 0.1
                        )
                        Text(L10n.format(
                            "imageEditor.filter.unsharpRadiusValue",
                            String(format: "%.1f", viewModel.filterUnsharpEffectiveRadiusPixels)
                        ))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                            .frame(width: 44, alignment: .trailing)
                    }
                    .accessibilityIdentifier("image-editor-filter-unsharp-radius")
                    HStack {
                        Text(L10n.text("imageEditor.filter.unsharpThreshold"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        Slider(
                            value: Binding(
                                get: { viewModel.filterUnsharpEffectiveThresholdLevels },
                                set: { viewModel.filterUnsharpEffectiveThresholdLevels = $0 }
                            ),
                            in: 0...255,
                            step: 1
                        )
                        Text(L10n.format(
                            "imageEditor.filter.unsharpThresholdValue",
                            Int(viewModel.filterUnsharpEffectiveThresholdLevels.rounded())
                        ))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                            .frame(width: 44, alignment: .trailing)
                    }
                    .accessibilityIdentifier("image-editor-filter-unsharp-threshold")
                }
                if viewModel.selectedFilter == .highPass {
                    HStack {
                        Text(L10n.text("imageEditor.filter.highPassRadius"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        Slider(value: $viewModel.filterHighPassRadius, in: 1...1_000, step: 1)
                        Text(L10n.format(
                            "imageEditor.filter.highPassRadiusValue",
                            Int(viewModel.filterHighPassRadius.rounded())
                        ))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                            .frame(width: 54, alignment: .trailing)
                    }
                    .accessibilityIdentifier("image-editor-filter-high-pass-radius")
                }
                if viewModel.selectedFilter == .minimum || viewModel.selectedFilter == .maximum {
                    HStack {
                        Text(L10n.text("imageEditor.filter.morphologyRadius"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        Slider(value: $viewModel.filterMorphologyRadius, in: 1...256, step: 1)
                        Text(L10n.format(
                            "imageEditor.filter.morphologyRadiusValue",
                            Int(viewModel.filterMorphologyRadius.rounded())
                        ))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                            .frame(width: 54, alignment: .trailing)
                    }
                    .accessibilityIdentifier("image-editor-filter-morphology-radius")
                }
                if viewModel.selectedFilter == .emboss {
                    HStack {
                        Text(L10n.text("imageEditor.filter.embossAngle"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        Slider(value: $viewModel.filterEmbossAngleDegrees, in: -180...180, step: 1)
                        Text(L10n.format(
                            "imageEditor.filter.embossAngleValue",
                            Int(viewModel.filterEmbossAngleDegrees.rounded())
                        ))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                            .frame(width: 54, alignment: .trailing)
                    }
                    .accessibilityIdentifier("image-editor-filter-emboss-angle")
                    HStack {
                        Text(L10n.text("imageEditor.filter.embossHeight"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        Slider(value: $viewModel.filterEmbossHeight, in: 1...10, step: 1)
                        Text(L10n.format(
                            "imageEditor.filter.embossHeightValue",
                            Int(viewModel.filterEmbossHeight.rounded())
                        ))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                            .frame(width: 54, alignment: .trailing)
                    }
                    .accessibilityIdentifier("image-editor-filter-emboss-height")
                    HStack {
                        Text(L10n.text("imageEditor.filter.embossAmount"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        Slider(value: $viewModel.filterIntensity, in: 0...1, step: 0.05)
                        Text(L10n.format(
                            "imageEditor.filter.embossAmountValue",
                            Int((viewModel.filterIntensity * 100).rounded())
                        ))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                            .frame(width: 54, alignment: .trailing)
                    }
                    .accessibilityIdentifier("image-editor-filter-emboss-amount")
                }
                if viewModel.selectedFilter == .liquifyPush {
                    HStack {
                        Text(L10n.text("imageEditor.filter.liquifyPushX"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        Slider(
                            value: Binding(
                                get: { viewModel.filterLiquifyPushEffectiveXPixels },
                                set: { viewModel.filterLiquifyPushEffectiveXPixels = $0 }
                            ),
                            in: -9_999...9_999,
                            step: 1
                        )
                        .accessibilityIdentifier("image-editor-filter-liquify-push-x-pixels")
                        Text(L10n.format(
                            "imageEditor.filter.liquifyPushValue",
                            String(format: "%+d", Int(viewModel.filterLiquifyPushEffectiveXPixels.rounded()))
                        ))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                            .frame(width: 44, alignment: .trailing)
                    }
                    HStack {
                        Text(L10n.text("imageEditor.filter.liquifyPushY"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        Slider(
                            value: Binding(
                                get: { viewModel.filterLiquifyPushEffectiveYPixels },
                                set: { viewModel.filterLiquifyPushEffectiveYPixels = $0 }
                            ),
                            in: -9_999...9_999,
                            step: 1
                        )
                        .accessibilityIdentifier("image-editor-filter-liquify-push-y-pixels")
                        Text(L10n.format(
                            "imageEditor.filter.liquifyPushValue",
                            String(format: "%+d", Int(viewModel.filterLiquifyPushEffectiveYPixels.rounded()))
                        ))
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
                        Slider(
                            value: Binding(
                                get: { viewModel.filterLiquifyTwirlEffectiveAngleDegrees },
                                set: { viewModel.filterLiquifyTwirlEffectiveAngleDegrees = $0 }
                            ),
                            in: -999...999,
                            step: 1
                        )
                        .accessibilityIdentifier("image-editor-filter-liquify-twirl-angle")
                        Text(L10n.format(
                            "imageEditor.filter.liquifyTwirlValue",
                            String(format: "%+d", Int(viewModel.filterLiquifyTwirlEffectiveAngleDegrees.rounded()))
                        ))
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
                        Slider(
                            value: Binding(
                                get: { viewModel.filterLiquifyBulgeEffectiveAmountPercent },
                                set: { viewModel.filterLiquifyBulgeEffectiveAmountPercent = $0 }
                            ),
                            in: -100...100,
                            step: 1
                        )
                        .accessibilityIdentifier("image-editor-filter-liquify-bulge-amount")
                        Text(L10n.format(
                            "imageEditor.filter.liquifyBulgeValue",
                            String(format: "%+d", Int(viewModel.filterLiquifyBulgeEffectiveAmountPercent.rounded()))
                        ))
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
                        Slider(
                            value: Binding(
                                get: { viewModel.filterOffsetEffectiveXPixels },
                                set: { viewModel.filterOffsetEffectiveXPixels = $0 }
                            ),
                            in: -9_999...9_999,
                            step: 1
                        )
                        .accessibilityIdentifier("image-editor-filter-offset-x-pixels")
                        Text(L10n.format(
                            "imageEditor.filter.offsetValue",
                            String(format: "%+d", Int(viewModel.filterOffsetEffectiveXPixels.rounded()))
                        ))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                            .frame(width: 44, alignment: .trailing)
                    }
                    HStack {
                        Text(L10n.text("imageEditor.filter.offsetY"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        Slider(
                            value: Binding(
                                get: { viewModel.filterOffsetEffectiveYPixels },
                                set: { viewModel.filterOffsetEffectiveYPixels = $0 }
                            ),
                            in: -9_999...9_999,
                            step: 1
                        )
                        .accessibilityIdentifier("image-editor-filter-offset-y-pixels")
                        Text(L10n.format(
                            "imageEditor.filter.offsetValue",
                            String(format: "%+d", Int(viewModel.filterOffsetEffectiveYPixels.rounded()))
                        ))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                            .frame(width: 44, alignment: .trailing)
                    }
                    HStack {
                        Text(L10n.text("imageEditor.filter.offsetUndefinedAreas"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        Spacer(minLength: 8)
                        Picker("", selection: $viewModel.filterOffsetUndefinedAreaMode) {
                            ForEach(ImageEditorOffsetUndefinedAreaMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .controlSize(.small)
                        .frame(width: 176)
                        .accessibilityIdentifier("image-editor-filter-offset-undefined-area-mode")
                    }
                }

                })

                AnyView(Group {

                if viewModel.selectedFilter == .wave {
                    HStack {
                        Text(L10n.text("imageEditor.filter.waveAmplitude"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        Slider(
                            value: Binding(
                                get: { viewModel.filterWaveEffectiveAmplitudePercent },
                                set: { viewModel.filterWaveEffectiveAmplitudePercent = $0 }
                            ),
                            in: -100...100,
                            step: 1
                        )
                        .accessibilityIdentifier("image-editor-filter-wave-amplitude")
                        Text(L10n.format(
                            "imageEditor.filter.waveAmplitudeValue",
                            String(format: "%+d", Int(viewModel.filterWaveEffectiveAmplitudePercent.rounded()))
                        ))
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
                        Slider(
                            value: Binding(
                                get: { viewModel.filterRippleEffectiveAmountPercent },
                                set: { viewModel.filterRippleEffectiveAmountPercent = $0 }
                            ),
                            in: -100...100,
                            step: 1
                        )
                        .accessibilityIdentifier("image-editor-filter-ripple-amount")
                        Text(L10n.format(
                            "imageEditor.filter.rippleAmountValue",
                            String(format: "%+d", Int(viewModel.filterRippleEffectiveAmountPercent.rounded()))
                        ))
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
                        Slider(
                            value: Binding(
                                get: { viewModel.filterPinchEffectiveAmountPercent },
                                set: { viewModel.filterPinchEffectiveAmountPercent = $0 }
                            ),
                            in: -100...100,
                            step: 1
                        )
                        Text(L10n.format(
                            "imageEditor.filter.pinchAmountValue",
                            String(format: "%+d", Int(viewModel.filterPinchEffectiveAmountPercent.rounded()))
                        ))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                            .frame(width: 52, alignment: .trailing)
                    }
                    .accessibilityIdentifier("image-editor-filter-pinch-amount")
                }
                if viewModel.selectedFilter == .spherize {
                    HStack {
                        Text(L10n.text("imageEditor.filter.spherizeAmount"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        Slider(
                            value: Binding(
                                get: { viewModel.filterSpherizeEffectiveAmountPercent },
                                set: { viewModel.filterSpherizeEffectiveAmountPercent = $0 }
                            ),
                            in: -100...100,
                            step: 1
                        )
                        Text(L10n.format(
                            "imageEditor.filter.spherizeAmountValue",
                            String(format: "%+d", Int(viewModel.filterSpherizeEffectiveAmountPercent.rounded()))
                        ))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                            .frame(width: 52, alignment: .trailing)
                    }
                    .accessibilityIdentifier("image-editor-filter-spherize-amount")
                }
                if viewModel.selectedFilter == .lensCorrection {
                    HStack {
                        Text(L10n.text("imageEditor.filter.lensDistortion"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        Slider(
                            value: Binding(
                                get: { viewModel.filterLensDistortionEffectiveAmountPercent },
                                set: { viewModel.filterLensDistortionEffectiveAmountPercent = $0 }
                            ),
                            in: -100...100,
                            step: 1
                        )
                        Text(L10n.format(
                            "imageEditor.filter.lensDistortionValue",
                            String(format: "%+d", Int(viewModel.filterLensDistortionEffectiveAmountPercent.rounded()))
                        ))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                            .frame(width: 52, alignment: .trailing)
                    }
                    .accessibilityIdentifier("image-editor-filter-lens-distortion-amount")
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
                    in: Double(ImageEditorTextContent.minimumFontSize)...Double(ImageEditorTextContent.maximumFontSize),
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
                Picker(
                    L10n.text("imageEditor.properties.textVerticalAlignment"),
                    selection: Binding(
                        get: { viewModel.selectedTextVerticalAlignment },
                        set: { viewModel.setSelectedTextBoxesVerticalAlignment($0) }
                    )
                ) {
                    ForEach(ImageEditorTextVerticalAlignment.allCases) { alignment in
                        Text(alignment.title).tag(alignment)
                    }
                }
                .pickerStyle(.segmented)
                .focusable(false)
                .disabled(!viewModel.canSetSelectedTextBoxVerticalAlignment)
                .accessibilityIdentifier("image-editor-text-box-vertical-alignment")
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

                if viewModel.selectedTool == .pen || viewModel.hasPendingPenPathTransaction {
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
                        .disabled(!viewModel.hasPendingPenPathTransaction)
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
                layerStyleValuePicker(
                    state: viewModel.selectedLayerGradientOverlayBlendModeState,
                    values: ImageEditorBlendMode.layerEffectCases,
                    labelKey: "imageEditor.properties.gradientOverlayBlendMode",
                    accessibilityIdentifier: "image-editor-layer-style-gradient-overlay-blend-mode",
                    title: \.title
                ) { blendMode in
                    viewModel.setSelectedLayerGradientOverlayBlendMode(blendMode)
                }
                layerStyleTriStateToggle(
                    state: viewModel.selectedLayerGradientOverlayReverseState,
                    labelKey: "imageEditor.gradientFill.reverse",
                    accessibilityIdentifier: "image-editor-layer-style-gradient-overlay-reverse"
                ) {
                    viewModel.toggleSelectedLayerGradientOverlayReverse()
                }
                layerStyleTriStateToggle(
                    state: viewModel.selectedLayerGradientOverlayDitherState,
                    labelKey: "imageEditor.gradientFill.dither",
                    accessibilityIdentifier: "image-editor-layer-style-gradient-overlay-dither"
                ) {
                    viewModel.toggleSelectedLayerGradientOverlayDither()
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
                ImageEditorLayerStyleGradientOverlayStopsEditor(viewModel: viewModel)
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
                HStack {
                    layerStyleNumericStepper(
                        state: viewModel.selectedLayerGradientOverlayCenterXState,
                        value: selectedLayerGradientOverlayCenterXBinding,
                        range: -4...5,
                        step: 0.01,
                        accessibilityIdentifier: "image-editor-layer-style-gradient-overlay-center-x"
                    ) { value in
                        L10n.format(
                            "imageEditor.properties.gradientOverlayCenterXValue",
                            Int((value * 100).rounded())
                        )
                    }
                    layerStyleNumericStepper(
                        state: viewModel.selectedLayerGradientOverlayCenterYState,
                        value: selectedLayerGradientOverlayCenterYBinding,
                        range: -4...5,
                        step: 0.01,
                        accessibilityIdentifier: "image-editor-layer-style-gradient-overlay-center-y"
                    ) { value in
                        L10n.format(
                            "imageEditor.properties.gradientOverlayCenterYValue",
                            Int((value * 100).rounded())
                        )
                    }
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
            .onChange(of: viewModel.selectedGradientFillPreset) { preset in
                viewModel.setGradientFillDraftPreset(preset)
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
            Toggle(L10n.text("imageEditor.gradientFill.dither"), isOn: $viewModel.gradientFillDither)
                .toggleStyle(.checkbox)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                .accessibilityIdentifier("image-editor-gradient-fill-dither")
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
                ImageEditorGradientFillStopsEditor(viewModel: viewModel)
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
        NSApplication.shared.keyWindow?.performClose(nil)
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
    case pathSelection
    case directSelection
    case moveTool
    case grab
    case textInsertion
    case brushTool
    case historicalPixelRestore
    case pencilTool
    case eraserTool
    case selectionMarquee
    case freeformSelectionPath
    case similarColorSelection
    case paintedRegionSelection
    case sampledPixelTransfer
    case sampledRepairBlend
    case localExposureLighten
    case localExposureDarken
    case localSaturationAdjust
    case localDetailSoften
    case localDetailSharpen
    case pixelSmear
    case crop
    case patch
    case gradient
    case rectangleOutline
    case ellipseOutline
    case paintBucket
    case eyedropper
    case redCastNeutralization
    case samplingScope
    case vectorPen
    case zoomViewportScale
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

    static func from(selectionMode: ImageEditorSelectionMode) -> Self {
        switch selectionMode {
        case .replace:
            .replace
        case .add:
            .add
        case .subtract:
            .subtract
        case .intersect:
            .intersect
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

enum ImageEditorSampledBrushCursorPolicy {
    static func isPickingSource(
        tool: ImageEditorTool,
        healingMode: ImageEditorHealingBrushMode,
        isSettingCloneSource: Bool,
        isSettingHealingSource: Bool,
        modifierFlags: NSEvent.ModifierFlags
    ) -> Bool {
        switch tool {
        case .cloneStamp:
            return isSettingCloneSource || modifierFlags.contains(.option)
        case .healingBrush:
            return healingMode == .source
                && (isSettingHealingSource || modifierFlags.contains(.option))
        default:
            return false
        }
    }
}

enum ImageEditorTemporaryEyedropperPolicy {
    static func isAvailable(for tool: ImageEditorTool) -> Bool {
        tool == .brush || tool == .pencil
    }

    static func isActive(
        tool: ImageEditorTool,
        modifierFlags: NSEvent.ModifierFlags
    ) -> Bool {
        isAvailable(for: tool) && modifierFlags.contains(.option)
    }

    static func ownsPointerSequence(
        tool: ImageEditorTool,
        modifierFlags: NSEvent.ModifierFlags,
        isGestureActive: Bool,
        hasPaintSamples: Bool
    ) -> Bool {
        if isGestureActive { return true }
        guard !hasPaintSamples else { return false }
        return isActive(tool: tool, modifierFlags: modifierFlags)
    }
}

enum ImageEditorEyedropperTargetPolicy {
    static func target(
        tool: ImageEditorTool,
        modifierFlags: NSEvent.ModifierFlags,
        latchedTarget: ImageEditorColorSampleTarget? = nil
    ) -> ImageEditorColorSampleTarget {
        if let latchedTarget { return latchedTarget }
        guard tool == .eyedropper, modifierFlags.contains(.option) else {
            return .foreground
        }
        return .background
    }
}

enum ImageEditorPatchCursorPhase: Equatable {
    case drawingSelection
    case readyToDrag
    case draggingSelection
    case blocked

    static func resolve(
        isPointerOverSelection: Bool,
        isDrawingSelection: Bool,
        isDraggingSelection: Bool,
        canEditSelectionPixels: Bool,
        isBlockedGestureActive: Bool = false
    ) -> Self {
        if isBlockedGestureActive {
            return .blocked
        }
        if isDraggingSelection {
            return .draggingSelection
        }
        if isDrawingSelection {
            return .drawingSelection
        }
        guard isPointerOverSelection else { return .drawingSelection }
        return canEditSelectionPixels ? .readyToDrag : .blocked
    }
}

enum ImageEditorPatchGestureStartAction: Equatable {
    case drawSelection
    case dragSelection
    case blocked

    static func resolve(
        isPointerOverSelection: Bool,
        canEditSelectionPixels: Bool,
        selectionMode: ImageEditorSelectionMode = .replace
    ) -> Self {
        guard selectionMode == .replace else { return .drawSelection }
        guard isPointerOverSelection else { return .drawSelection }
        return canEditSelectionPixels ? .dragSelection : .blocked
    }
}

enum ImageEditorPatchGestureCancellationPolicy {
    static func shouldCancel(
        tool: ImageEditorTool,
        hasDragStart: Bool,
        hasDrawnPoints: Bool,
        isDrawingSelection: Bool,
        hasPreview: Bool
    ) -> Bool {
        guard tool == .patchTool else { return false }
        return hasDragStart || hasDrawnPoints || isDrawingSelection || hasPreview
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
        case .brush, .pencil, .historyBrush, .eraser:
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
        spongeMode: ImageEditorSpongeMode = .saturate,
        brushTilt: ImageEditorStylusTilt? = nil,
        brushTiltControlsShape: Bool = false,
        brushTipRoundness: CGFloat = 1,
        brushTipAngleDegrees: CGFloat = 0,
        isPointerOverCanvas: Bool = true,
        isPointerOverMovableContent: Bool = true,
        isPointerOverBlockedContent: Bool = false,
        moveToolUsesBoxSelection: Bool = false,
        moveToolHoverSelectionIntent: ImageEditorMoveToolHoverSelectionIntent = .none,
        isPointerOverEditableText: Bool = false,
        isPointerOverColorSamplerPoint: Bool = false,
        paintBucketSeedIsBlocked: Bool = false,
        penIsClosing: Bool = false,
        penIsConverting: Bool = false,
        penConversionIsBlocked: Bool = false,
        penIsAddingAnchor: Bool = false,
        penAdditionIsBlocked: Bool = false,
        penIsDeletingAnchor: Bool = false,
        penAnchorDeletionIsBlocked: Bool = false,
        penIsContinuingPath: Bool = false,
        penContinuationIsBlocked: Bool = false,
        directSelectionIsBlocked: Bool = false,
        pathSelectionIsBlocked: Bool = false,
        pathHandleIsBreaking: Bool = false,
        handIsDragging: Bool = false,
        isObjectMoveGestureActive: Bool = false,
        isColorSamplerMoveGestureActive: Bool = false,
        isSpacebarPanning: Bool = false,
        isCanvasPanGestureActive: Bool = false,
        isPickingSampledBrushSource: Bool = false,
        isTemporaryEyedropperActive: Bool = false,
        eyedropperTarget: ImageEditorColorSampleTarget = .foreground,
        isErasingToHistory: Bool = false,
        patchPhase: ImageEditorPatchCursorPhase = .drawingSelection,
        patchMode: ImageEditorPatchMode = .source,
        patchSelectionMode: ImageEditorSelectionMode = .replace,
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
            if selectedTool == .paintBucket, paintBucketSeedIsBlocked {
                return .operationNotAllowed
            }
            if selectedTool == .move, isPointerOverBlockedContent {
                return .operationNotAllowed
            }
            if selectedTool == .directSelection, directSelectionIsBlocked {
                return .operationNotAllowed
            }
            if selectedTool == .pathSelection, pathSelectionIsBlocked {
                return .operationNotAllowed
            }
            if selectedTool == .move, !isPointerOverMovableContent {
                return moveToolUsesBoxSelection
                    ? objectBoxSelectionCursor(
                        mode: ImageEditorObjectBoxSelectionMode.resolve(
                            modifierFlags: modifierFlags
                        )
                    )
                    : .openHand
            }
            if selectedTool == .move {
                if let mode = moveToolHoverSelectionIntent.boxSelectionMode {
                    return objectBoxSelectionCursor(mode: mode)
                }
                // Sketch and Figma keep the ordinary pointer while hovering a
                // selectable object. The four-way move cursor appears only
                // after a real drag starts, so hover never impersonates pan.
                return .arrow
            }
            return cursor(
                for: selectedTool,
                brushDiameter: brushDiameter,
                spongeMode: spongeMode,
                brushTilt: brushTilt,
                brushTiltControlsShape: brushTiltControlsShape,
                brushTipRoundness: brushTipRoundness,
                brushTipAngleDegrees: brushTipAngleDegrees,
                isPointerOverEditableText: isPointerOverEditableText,
                penIsClosing: penIsClosing,
                penIsConverting: penIsConverting,
                penConversionIsBlocked: penConversionIsBlocked,
                penIsAddingAnchor: penIsAddingAnchor,
                penAdditionIsBlocked: penAdditionIsBlocked,
                penIsDeletingAnchor: penIsDeletingAnchor,
                penAnchorDeletionIsBlocked: penAnchorDeletionIsBlocked,
                penIsContinuingPath: penIsContinuingPath,
                penContinuationIsBlocked: penContinuationIsBlocked,
                pathHandleIsBreaking: pathHandleIsBreaking,
                handIsDragging: handIsDragging,
                isPickingSampledBrushSource: isPickingSampledBrushSource,
                isTemporaryEyedropperActive: isTemporaryEyedropperActive,
                eyedropperTarget: eyedropperTarget,
                isErasingToHistory: isErasingToHistory,
                patchPhase: patchPhase,
                patchMode: patchMode,
                patchSelectionMode: patchSelectionMode,
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

    /// Object-box selection keeps the precise native arrow and adds only the
    /// compact set-operation badge used by familiar selection tools.
    static func objectBoxSelectionCursor(
        mode: ImageEditorObjectBoxSelectionMode
    ) -> NSCursor {
        guard mode != .replace else { return .arrow }
        let cacheKey = "object-box-selection:\(mode.rawValue)"
        if let cachedCursor = cursorCache[cacheKey] {
            return cachedCursor
        }

        let arrowCursor = NSCursor.arrow
        let arrowImage = arrowCursor.image
        let side = max(34, arrowImage.size.width, arrowImage.size.height)
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()
        arrowImage.draw(
            in: NSRect(origin: .zero, size: arrowImage.size),
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )
        let selectionMode: ImageEditorSelectionCursorMode = switch mode {
        case .replace:
            .replace
        case .add:
            .add
        case .subtract:
            .subtract
        case .intersect:
            .intersect
        }
        drawSelectionModifierBadge(selectionMode, side: side)
        image.unlockFocus()
        return cache(
            NSCursor(image: image, hotSpot: arrowCursor.hotSpot),
            for: cacheKey
        )
    }

    /// Photoshop exposes Option-click as the familiar way to remove an
    /// existing color sampler. Keep the precision crosshair and add a compact
    /// minus badge only while the pointer is over a real sampler point.
    static func colorSamplerRemovalCursor() -> NSCursor {
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

    /// Blank canvas is a creation target for the Text tool: a click creates
    /// point text and a drag creates a paragraph box. Keep the insertion beam
    /// small and precise, then add only a quiet dashed corner to communicate
    /// the optional box gesture. Existing editable text continues to use the
    /// native I-beam.
    private static func textCreationCursor() -> NSCursor {
        let cacheKey = "text-creation"
        if let cachedCursor = cursorCache[cacheKey] {
            return cachedCursor
        }

        let side: CGFloat = 32
        let insertionPoint = NSPoint(x: 9, y: 18)
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()

        let beam = NSBezierPath()
        beam.move(to: NSPoint(x: insertionPoint.x, y: 7))
        beam.line(to: NSPoint(x: insertionPoint.x, y: 29))
        beam.move(to: NSPoint(x: 5, y: 7))
        beam.line(to: NSPoint(x: 13, y: 7))
        beam.move(to: NSPoint(x: 5, y: 29))
        beam.line(to: NSPoint(x: 13, y: 29))
        NSColor.white.withAlphaComponent(0.98).setStroke()
        beam.lineWidth = 3
        beam.stroke()
        NSColor.black.withAlphaComponent(0.96).setStroke()
        beam.lineWidth = 1.2
        beam.stroke()

        let paragraphCorner = NSBezierPath()
        paragraphCorner.move(to: NSPoint(x: 16, y: 25))
        paragraphCorner.line(to: NSPoint(x: 27, y: 25))
        paragraphCorner.line(to: NSPoint(x: 27, y: 14))
        paragraphCorner.setLineDash([2, 2], count: 2, phase: 0)
        NSColor.black.withAlphaComponent(0.94).setStroke()
        paragraphCorner.lineWidth = 3
        paragraphCorner.stroke()
        NSColor.white.withAlphaComponent(0.98).setStroke()
        paragraphCorner.lineWidth = 1
        paragraphCorner.stroke()

        image.unlockFocus()
        return cache(
            NSCursor(
                image: image,
                hotSpot: NSPoint(x: insertionPoint.x, y: side - insertionPoint.y)
            ),
            for: cacheKey
        )
    }

    /// Photoshop's Path Selection tool uses a black arrow. Add a compact
    /// Bézier-node badge so it remains distinct from both the system pointer
    /// used by component-library mode and the white Direct Selection arrow.
    private static func pathSelectionCursor() -> NSCursor {
        let cacheKey = "path-selection"
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
        NSColor.white.withAlphaComponent(0.98).setStroke()
        pointer.lineWidth = 3
        pointer.stroke()
        NSColor.black.withAlphaComponent(0.96).setFill()
        pointer.fill()
        NSColor.black.setStroke()
        pointer.lineWidth = 1
        pointer.stroke()

        let path = NSBezierPath()
        path.move(to: NSPoint(x: 22, y: 7))
        path.curve(
            to: NSPoint(x: 33, y: 10),
            controlPoint1: NSPoint(x: 25, y: 14),
            controlPoint2: NSPoint(x: 30, y: 3)
        )
        NSColor.black.withAlphaComponent(0.95).setStroke()
        path.lineWidth = 3
        path.stroke()
        NSColor.white.setStroke()
        path.lineWidth = 1
        path.stroke()
        for point in [NSPoint(x: 22, y: 7), NSPoint(x: 33, y: 10)] {
            let anchor = NSBezierPath(rect: NSRect(x: point.x - 2, y: point.y - 2, width: 4, height: 4))
            NSColor.black.setFill()
            anchor.fill()
            NSColor.white.setStroke()
            anchor.lineWidth = 1
            anchor.stroke()
        }

        image.unlockFocus()
        return cache(
            NSCursor(image: image, hotSpot: NSPoint(x: 8, y: side - 30)),
            for: cacheKey
        )
    }

    /// Photoshop's Direct Selection tool uses a white node-editing arrow.
    /// Keeping the black/white distinction visible makes the two path tools
    /// understandable at a glance.
    private static func directSelectionCursor(isBreakingSmoothHandle: Bool = false) -> NSCursor {
        let cacheKey = "direct-selection:\(isBreakingSmoothHandle)"
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

        if isBreakingSmoothHandle {
            let badgeRect = NSRect(x: 23, y: 2, width: 11, height: 11)
            let badge = NSBezierPath(ovalIn: badgeRect)
            NSColor.black.withAlphaComponent(0.96).setFill()
            badge.fill()
            NSColor.white.withAlphaComponent(0.98).setStroke()
            badge.lineWidth = 1
            badge.stroke()

            let brokenTangent = NSBezierPath()
            brokenTangent.move(to: NSPoint(x: badgeRect.minX + 2.5, y: badgeRect.midY + 2.5))
            brokenTangent.line(to: NSPoint(x: badgeRect.midX, y: badgeRect.midY))
            brokenTangent.line(to: NSPoint(x: badgeRect.maxX - 2.5, y: badgeRect.midY + 1))
            NSColor.white.setStroke()
            brokenTangent.lineWidth = 1.4
            brokenTangent.stroke()
        }

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
            .freeformSelectionPath
        case .magicWand:
            .similarColorSelection
        case .quickSelection:
            .paintedRegionSelection
        case .cloneStamp:
            .sampledPixelTransfer
        case .healingBrush:
            .sampledRepairBlend
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
        case .historyBrush:
            .historicalPixelRestore
        case .pencil:
            .pencilTool
        case .eraser:
            .eraserTool
        case .dodge:
            .localExposureLighten
        case .burn:
            .localExposureDarken
        case .sponge:
            .localSaturationAdjust
        case .blur:
            .localDetailSoften
        case .sharpen:
            .localDetailSharpen
        case .smudge:
            .pixelSmear
        case .paintBucket:
            .paintBucket
        case .colorSampler:
            .samplingScope
        case .eyedropper:
            .eyedropper
        case .redEye:
            .redCastNeutralization
        case .pen:
            .vectorPen
        case .pathSelection:
            .pathSelection
        case .directSelection:
            .directSelection
        case .zoom:
            .zoomViewportScale
        }
    }

    static func cursor(
        for tool: ImageEditorTool,
        brushDiameter: CGFloat,
        spongeMode: ImageEditorSpongeMode = .saturate,
        brushTilt: ImageEditorStylusTilt? = nil,
        brushTiltControlsShape: Bool = false,
        brushTipRoundness: CGFloat = 1,
        brushTipAngleDegrees: CGFloat = 0,
        isPointerOverEditableText: Bool = false,
        penIsClosing: Bool = false,
        penIsConverting: Bool = false,
        penConversionIsBlocked: Bool = false,
        penIsAddingAnchor: Bool = false,
        penAdditionIsBlocked: Bool = false,
        penIsDeletingAnchor: Bool = false,
        penAnchorDeletionIsBlocked: Bool = false,
        penIsContinuingPath: Bool = false,
        penContinuationIsBlocked: Bool = false,
        pathHandleIsBreaking: Bool = false,
        handIsDragging: Bool = false,
        isPickingSampledBrushSource: Bool = false,
        isTemporaryEyedropperActive: Bool = false,
        eyedropperTarget: ImageEditorColorSampleTarget = .foreground,
        isErasingToHistory: Bool = false,
        patchPhase: ImageEditorPatchCursorPhase = .drawingSelection,
        patchMode: ImageEditorPatchMode = .source,
        patchSelectionMode: ImageEditorSelectionMode = .replace,
        modifierFlags: NSEvent.ModifierFlags = [],
        marqueeShape: ImageEditorMarqueeShape = .rectangle,
        cropHandle: ImageEditorCropHandle? = nil
    ) -> NSCursor {
        if isTemporaryEyedropperActive,
           ImageEditorTemporaryEyedropperPolicy.isAvailable(for: tool) {
            return eyedropperCursor(target: .foreground)
        }
        let selectionMode = ImageEditorSelectionCursorMode.from(modifierFlags: modifierFlags)
        switch family(for: tool) {
        case .systemArrow:
            return .arrow
        case .pathSelection:
            return pathSelectionCursor()
        case .directSelection:
            return directSelectionCursor(isBreakingSmoothHandle: pathHandleIsBreaking)
        case .moveTool:
            return .arrow
        case .grab:
            return handIsDragging ? .closedHand : .openHand
        case .textInsertion:
            return isPointerOverEditableText ? .iBeam : textCreationCursor()
        case .selectionMarquee:
            return selectionMode == .replace
                ? .crosshair
                : familiarSelectionCursor(mode: selectionMode, shape: marqueeShape)
        case .freeformSelectionPath:
            return freeformSelectionPathCursor(mode: selectionMode)
        case .similarColorSelection:
            return similarColorSelectionCursor(mode: selectionMode)
        case .paintedRegionSelection:
            return paintedRegionSelectionCursor(mode: selectionMode)
        case .sampledPixelTransfer:
            return modifierFlags.contains(.capsLock) || isPickingSampledBrushSource
                ? .crosshair
                : cloneTransferCursor(diameter: brushDiameter)
        case .sampledRepairBlend:
            return modifierFlags.contains(.capsLock) || isPickingSampledBrushSource
                ? .crosshair
                : repairBlendCursor(diameter: brushDiameter)
        case .brushTool:
            return modifierFlags.contains(.capsLock)
                ? .crosshair
                : familiarBrushCursor(
                    diameter: brushDiameter,
                    tilt: brushTilt,
                    tiltControlsShape: brushTiltControlsShape,
                    tipRoundness: brushTipRoundness,
                    tipAngleDegrees: brushTipAngleDegrees
                )
        case .historicalPixelRestore:
            return modifierFlags.contains(.capsLock)
                ? .crosshair
                : historicalPixelRestoreCursor(diameter: brushDiameter)
        case .pencilTool:
            return modifierFlags.contains(.capsLock)
                ? .crosshair
                : pencilPixelCursor(diameter: brushDiameter)
        case .eraserTool:
            return modifierFlags.contains(.capsLock)
                ? .crosshair
                : eraserResultCursor(
                    diameter: brushDiameter,
                    restoringHistory: isErasingToHistory
                )
        case .localExposureLighten:
            return modifierFlags.contains(.capsLock)
                ? .crosshair
                : localExposureCursor(diameter: brushDiameter, lightening: true)
        case .localExposureDarken:
            return modifierFlags.contains(.capsLock)
                ? .crosshair
                : localExposureCursor(diameter: brushDiameter, lightening: false)
        case .localSaturationAdjust:
            return modifierFlags.contains(.capsLock)
                ? .crosshair
                : localSaturationCursor(diameter: brushDiameter, mode: spongeMode)
        case .localDetailSoften:
            return modifierFlags.contains(.capsLock)
                ? .crosshair
                : localDetailSoftenCursor(diameter: brushDiameter)
        case .localDetailSharpen:
            return modifierFlags.contains(.capsLock)
                ? .crosshair
                : localDetailSharpenCursor(diameter: brushDiameter)
        case .pixelSmear:
            return modifierFlags.contains(.capsLock)
                ? .crosshair
                : pixelSmearCursor(diameter: brushDiameter)
        case .crop:
            if let cropHandle {
                return cropResizeCursor(for: cropHandle)
            }
            return cropCursor()
        case .patch:
            switch patchPhase {
            case .drawingSelection:
                return freeformSelectionPathCursor(
                    mode: ImageEditorSelectionCursorMode.from(selectionMode: patchSelectionMode)
                )
            case .readyToDrag:
                return patchTransferCursor(mode: patchMode)
            case .draggingSelection:
                return patchTransferCursor(mode: patchMode)
            case .blocked:
                return .operationNotAllowed
            }
        case .gradient:
            return gradientCursor(isConstrained: modifierFlags.contains(.shift))
        case .rectangleOutline, .ellipseOutline:
            return shapeCreationCursor(for: tool)
        case .paintBucket:
            return regionFillCursor()
        case .eyedropper:
            return eyedropperCursor(target: eyedropperTarget)
        case .redCastNeutralization:
            return modifierFlags.contains(.capsLock)
                ? .crosshair
                : redCastNeutralizationCursor(diameter: brushDiameter)
        case .samplingScope:
            // A Color Sampler click creates a persistent canvas marker rather
            // than merely reading one transient pixel. Preview that result
            // with a compact target marker; Caps Lock keeps the familiar
            // precise crosshair available when the marker would obscure a
            // very small feature.
            return modifierFlags.contains(.capsLock)
                ? .crosshair
                : samplingScopeCursor()
        case .vectorPen:
            if penConversionIsBlocked || penAdditionIsBlocked || penAnchorDeletionIsBlocked
                || penContinuationIsBlocked {
                return .operationNotAllowed
            }
            return penCursor(
                isClosing: penIsClosing,
                isConverting: penIsConverting || pathHandleIsBreaking,
                isAddingAnchor: penIsAddingAnchor,
                isDeletingAnchor: penIsDeletingAnchor,
                isContinuingPath: penIsContinuingPath,
                isConstrained: modifierFlags.contains(.shift)
            )
        case .zoomViewportScale:
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
            )
        )
    }

    private static func brushCursor(
        footprint: ImageEditorBrushCursorFootprint
    ) -> NSCursor {
        let diameter = footprint.majorDiameter
        let cacheKey = "brush:\(footprint.cacheKey)"
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

        image.unlockFocus()
        return cache(
            NSCursor(image: image, hotSpot: NSPoint(x: center.x, y: side - center.y)),
            for: cacheKey
        )
    }

    private static func historicalPixelRestoreCursor(
        diameter requestedDiameter: CGFloat
    ) -> NSCursor {
        let diameter = max(3, min(256, requestedDiameter.rounded()))
        let cacheKey = "historical-pixel-restore:\(Int(diameter))"
        if let cachedCursor = cursorCache[cacheKey] {
            return cachedCursor
        }

        let side = max(36, diameter + 18)
        let center = NSPoint(x: side / 2, y: side / 2)
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()

        let footprint = NSBezierPath(ovalIn: NSRect(
            x: center.x - diameter / 2,
            y: center.y - diameter / 2,
            width: diameter,
            height: diameter
        ))
        NSColor.black.withAlphaComponent(0.95).setStroke()
        footprint.lineWidth = 3.5
        footprint.stroke()
        NSColor.white.withAlphaComponent(0.98).setStroke()
        footprint.lineWidth = 1.4
        footprint.stroke()

        // The right swatch is the altered current pixel; the colorful left
        // swatch is the chosen history source. A reverse arrow previews
        // painting snapshot pixels back into the real brush footprint without
        // shrinking a clock or history-brush toolbox icon onto the pointer.
        let sampleSize = max(3.2, min(6, diameter * 0.19))
        let spacing = max(4.8, min(8.5, diameter * 0.28))
        let historyRect = NSRect(
            x: center.x - spacing - sampleSize / 2,
            y: center.y - sampleSize / 2,
            width: sampleSize,
            height: sampleSize
        )
        let currentRect = NSRect(
            x: center.x + spacing - sampleSize / 2,
            y: center.y - sampleSize / 2,
            width: sampleSize,
            height: sampleSize
        )

        NSColor.systemGray.withAlphaComponent(0.85).setFill()
        NSBezierPath(rect: currentRect).fill()
        let fadedDetail = NSBezierPath()
        fadedDetail.move(to: NSPoint(x: currentRect.minX + 1, y: currentRect.minY + 1))
        fadedDetail.line(to: NSPoint(x: currentRect.maxX - 1, y: currentRect.maxY - 1))
        NSColor.white.withAlphaComponent(0.8).setStroke()
        fadedDetail.lineWidth = 1
        fadedDetail.stroke()

        NSColor.systemCyan.setFill()
        NSBezierPath(rect: NSRect(
            x: historyRect.minX,
            y: historyRect.minY,
            width: historyRect.width / 2,
            height: historyRect.height
        )).fill()
        NSColor.systemOrange.setFill()
        NSBezierPath(rect: NSRect(
            x: historyRect.midX,
            y: historyRect.minY,
            width: historyRect.width / 2,
            height: historyRect.height
        )).fill()

        NSColor.black.withAlphaComponent(0.9).setStroke()
        for rect in [historyRect, currentRect] {
            let outline = NSBezierPath(rect: rect)
            outline.lineWidth = 0.8
            outline.stroke()
        }

        let arrowY = center.y - spacing * 0.72
        let endpoint = NSPoint(x: historyRect.maxX, y: arrowY)
        let restore = NSBezierPath()
        restore.move(to: NSPoint(x: currentRect.minX, y: arrowY))
        restore.line(to: endpoint)
        restore.move(to: endpoint)
        restore.line(to: NSPoint(x: endpoint.x + 3.2, y: endpoint.y + 2.6))
        restore.move(to: endpoint)
        restore.line(to: NSPoint(x: endpoint.x + 3.2, y: endpoint.y - 2.6))
        NSColor.black.withAlphaComponent(0.95).setStroke()
        restore.lineWidth = 3.5
        restore.stroke()
        NSColor.systemGreen.setStroke()
        restore.lineWidth = 1.2
        restore.stroke()

        image.unlockFocus()
        return cache(
            NSCursor(image: image, hotSpot: NSPoint(x: center.x, y: side - center.y)),
            for: cacheKey
        )
    }

    private static func pencilPixelCursor(diameter requestedDiameter: CGFloat) -> NSCursor {
        let diameter = max(3, min(256, requestedDiameter.rounded()))
        let cacheKey = "pencil-pixels:\(Int(diameter))"
        if let cachedCursor = cursorCache[cacheKey] {
            return cachedCursor
        }

        let side = max(36, diameter + 18)
        let center = NSPoint(x: side / 2, y: side / 2)
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()

        let footprint = NSBezierPath(ovalIn: NSRect(
            x: center.x - diameter / 2,
            y: center.y - diameter / 2,
            width: diameter,
            height: diameter
        ))
        NSColor.black.withAlphaComponent(0.95).setStroke()
        footprint.lineWidth = 3.5
        footprint.stroke()
        NSColor.white.withAlphaComponent(0.98).setStroke()
        footprint.lineWidth = 1.4
        footprint.stroke()

        // Crisp square samples and a stepped diagonal preview the Pencil's
        // aliased pixel output without shrinking a pencil-shaped toolbox icon.
        let pixelSize = max(2.2, min(4.5, diameter * 0.15))
        let step = pixelSize * 0.9
        let pixelOffsets: [(x: CGFloat, y: CGFloat)] = [
            (-step, -step), (0, 0), (step, step)
        ]
        for (index, offset) in pixelOffsets.enumerated() {
            let rect = NSRect(
                x: center.x + offset.x - pixelSize / 2,
                y: center.y + offset.y - pixelSize / 2,
                width: pixelSize,
                height: pixelSize
            )
            (index == 1 ? NSColor.systemBlue : NSColor.white).setFill()
            NSBezierPath(rect: rect).fill()
            NSColor.black.withAlphaComponent(0.95).setStroke()
            let outline = NSBezierPath(rect: rect)
            outline.lineWidth = 0.9
            outline.stroke()
        }

        image.unlockFocus()
        return cache(
            NSCursor(image: image, hotSpot: NSPoint(x: center.x, y: side - center.y)),
            for: cacheKey
        )
    }

    private static func eraserResultCursor(
        diameter requestedDiameter: CGFloat,
        restoringHistory: Bool
    ) -> NSCursor {
        let diameter = max(3, min(256, requestedDiameter.rounded()))
        let mode = restoringHistory ? "restore" : "transparent"
        let cacheKey = "eraser-result-\(mode):\(Int(diameter))"
        if let cachedCursor = cursorCache[cacheKey] {
            return cachedCursor
        }

        let side = max(36, diameter + 18)
        let center = NSPoint(x: side / 2, y: side / 2)
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()

        let footprint = NSBezierPath(ovalIn: NSRect(
            x: center.x - diameter / 2,
            y: center.y - diameter / 2,
            width: diameter,
            height: diameter
        ))
        NSColor.black.withAlphaComponent(0.95).setStroke()
        footprint.lineWidth = 3.5
        footprint.stroke()
        NSColor.white.withAlphaComponent(0.98).setStroke()
        footprint.lineWidth = 1.4
        footprint.stroke()

        let sampleSize = max(3.2, min(6, diameter * 0.19))
        let spacing = max(4.8, min(8.5, diameter * 0.28))
        let leftRect = NSRect(
            x: center.x - spacing - sampleSize / 2,
            y: center.y - sampleSize / 2,
            width: sampleSize,
            height: sampleSize
        )
        let rightRect = NSRect(
            x: center.x + spacing - sampleSize / 2,
            y: center.y - sampleSize / 2,
            width: sampleSize,
            height: sampleSize
        )
        let transparencyRect = restoringHistory ? leftRect : rightRect
        let pixelRect = restoringHistory ? rightRect : leftRect
        drawTransparencySample(in: transparencyRect)
        NSColor.systemBlue.setFill()
        NSBezierPath(rect: pixelRect).fill()
        NSColor.black.withAlphaComponent(0.9).setStroke()
        for rect in [leftRect, rightRect] {
            let outline = NSBezierPath(rect: rect)
            outline.lineWidth = 0.8
            outline.stroke()
        }

        let endpoint = NSPoint(x: rightRect.minX, y: center.y - spacing * 0.72)
        let change = NSBezierPath()
        change.move(to: NSPoint(x: leftRect.maxX, y: center.y - spacing * 0.72))
        change.line(to: endpoint)
        change.move(to: endpoint)
        change.line(to: NSPoint(x: endpoint.x - 3.2, y: endpoint.y + 2.6))
        change.move(to: endpoint)
        change.line(to: NSPoint(x: endpoint.x - 3.2, y: endpoint.y - 2.6))
        NSColor.black.withAlphaComponent(0.95).setStroke()
        change.lineWidth = 3.5
        change.stroke()
        (restoringHistory ? NSColor.systemGreen : NSColor.systemPink).setStroke()
        change.lineWidth = 1.2
        change.stroke()

        image.unlockFocus()
        return cache(
            NSCursor(image: image, hotSpot: NSPoint(x: center.x, y: side - center.y)),
            for: cacheKey
        )
    }

    private static func redCastNeutralizationCursor(
        diameter requestedDiameter: CGFloat
    ) -> NSCursor {
        let diameter = max(3, min(256, requestedDiameter.rounded()))
        let cacheKey = "red-cast-neutralization:\(Int(diameter))"
        if let cachedCursor = cursorCache[cacheKey] {
            return cachedCursor
        }

        let side = max(36, diameter + 18)
        let center = NSPoint(x: side / 2, y: side / 2)
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()

        let footprint = NSBezierPath(ovalIn: NSRect(
            x: center.x - diameter / 2,
            y: center.y - diameter / 2,
            width: diameter,
            height: diameter
        ))
        NSColor.black.withAlphaComponent(0.95).setStroke()
        footprint.lineWidth = 3.5
        footprint.stroke()
        NSColor.white.withAlphaComponent(0.98).setStroke()
        footprint.lineWidth = 1.4
        footprint.stroke()

        // Red-eye reduction only lowers red-dominant pixels inside the real
        // circular treatment area. Two compact color samples and a forward
        // arrow preview that red-to-neutral result without drawing an eye or
        // reproducing the toolbox icon under the pointer.
        let sampleDiameter = max(3.4, min(6.2, diameter * 0.2))
        let spacing = max(4.8, min(8.8, diameter * 0.29))
        let redRect = NSRect(
            x: center.x - spacing - sampleDiameter / 2,
            y: center.y - sampleDiameter / 2,
            width: sampleDiameter,
            height: sampleDiameter
        )
        let neutralRect = NSRect(
            x: center.x + spacing - sampleDiameter / 2,
            y: center.y - sampleDiameter / 2,
            width: sampleDiameter,
            height: sampleDiameter
        )
        NSColor.systemRed.setFill()
        NSBezierPath(ovalIn: redRect).fill()
        NSColor(deviceWhite: 0.28, alpha: 1).setFill()
        NSBezierPath(ovalIn: neutralRect).fill()
        NSColor.black.withAlphaComponent(0.95).setStroke()
        for rect in [redRect, neutralRect] {
            let outline = NSBezierPath(ovalIn: rect)
            outline.lineWidth = 0.85
            outline.stroke()
        }

        let arrowY = center.y - spacing * 0.72
        let endpoint = NSPoint(x: neutralRect.minX, y: arrowY)
        let neutralize = NSBezierPath()
        neutralize.move(to: NSPoint(x: redRect.maxX, y: arrowY))
        neutralize.line(to: endpoint)
        neutralize.move(to: endpoint)
        neutralize.line(to: NSPoint(x: endpoint.x - 3.2, y: endpoint.y + 2.6))
        neutralize.move(to: endpoint)
        neutralize.line(to: NSPoint(x: endpoint.x - 3.2, y: endpoint.y - 2.6))
        NSColor.black.withAlphaComponent(0.95).setStroke()
        neutralize.lineWidth = 3.5
        neutralize.stroke()
        NSColor.systemBlue.setStroke()
        neutralize.lineWidth = 1.2
        neutralize.stroke()

        image.unlockFocus()
        return cache(
            NSCursor(image: image, hotSpot: NSPoint(x: center.x, y: side - center.y)),
            for: cacheKey
        )
    }

    private static func drawTransparencySample(in rect: NSRect) {
        let halfWidth = rect.width / 2
        let halfHeight = rect.height / 2
        let tiles = [
            NSRect(x: rect.minX, y: rect.minY, width: halfWidth, height: halfHeight),
            NSRect(x: rect.midX, y: rect.midY, width: halfWidth, height: halfHeight)
        ]
        NSColor.white.setFill()
        NSBezierPath(rect: rect).fill()
        NSColor.systemGray.withAlphaComponent(0.72).setFill()
        for tile in tiles {
            NSBezierPath(rect: tile).fill()
        }
    }

    private static func localExposureCursor(
        diameter requestedDiameter: CGFloat,
        lightening: Bool
    ) -> NSCursor {
        let diameter = max(3, min(256, requestedDiameter.rounded()))
        let operation = lightening ? "lighten" : "darken"
        let cacheKey = "local-exposure-\(operation):\(Int(diameter))"
        if let cachedCursor = cursorCache[cacheKey] {
            return cachedCursor
        }

        let side = max(36, diameter + 18)
        let center = NSPoint(x: side / 2, y: side / 2)
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()

        // Show the actual affected footprint and a compact tonal ramp. The
        // arrow follows the exposure change instead of reproducing a sun or
        // flame-shaped toolbox icon.
        let footprint = NSBezierPath(ovalIn: NSRect(
            x: center.x - diameter / 2,
            y: center.y - diameter / 2,
            width: diameter,
            height: diameter
        ))
        NSColor.black.withAlphaComponent(0.95).setStroke()
        footprint.lineWidth = 3.5
        footprint.stroke()
        NSColor.white.withAlphaComponent(0.98).setStroke()
        footprint.lineWidth = 1.4
        footprint.stroke()

        let sampleSide = max(2, min(4, diameter * 0.14))
        let sampleSpacing = max(3, min(7, diameter * 0.24))
        let samples: [(offset: CGFloat, white: CGFloat)] = lightening
            ? [(-sampleSpacing, 0.2), (0, 0.58), (sampleSpacing, 0.94)]
            : [(-sampleSpacing, 0.94), (0, 0.58), (sampleSpacing, 0.2)]
        for sample in samples {
            let rect = NSRect(
                x: center.x + sample.offset - sampleSide / 2,
                y: center.y + sample.offset * 0.45 - sampleSide / 2,
                width: sampleSide,
                height: sampleSide
            )
            NSColor(white: sample.white, alpha: 1).setFill()
            NSBezierPath(rect: rect).fill()
            NSColor.black.withAlphaComponent(0.95).setStroke()
            let outline = NSBezierPath(rect: rect)
            outline.lineWidth = 0.8
            outline.stroke()
        }

        let direction: CGFloat = lightening ? 1 : -1
        let exposureChange = NSBezierPath()
        exposureChange.move(to: NSPoint(
            x: center.x - sampleSpacing * direction,
            y: center.y - sampleSpacing * 0.35 * direction
        ))
        let endpoint = NSPoint(
            x: center.x + sampleSpacing * direction,
            y: center.y + sampleSpacing * 0.85 * direction
        )
        exposureChange.line(to: endpoint)
        exposureChange.move(to: endpoint)
        exposureChange.line(to: NSPoint(
            x: endpoint.x - 4.5 * direction,
            y: endpoint.y - 0.5 * direction
        ))
        exposureChange.move(to: endpoint)
        exposureChange.line(to: NSPoint(
            x: endpoint.x - 0.5 * direction,
            y: endpoint.y - 4.5 * direction
        ))
        NSColor.black.withAlphaComponent(0.95).setStroke()
        exposureChange.lineWidth = 3.5
        exposureChange.stroke()
        (lightening ? NSColor.systemYellow : NSColor.systemIndigo).setStroke()
        exposureChange.lineWidth = 1.2
        exposureChange.stroke()

        image.unlockFocus()
        return cache(
            NSCursor(image: image, hotSpot: NSPoint(x: center.x, y: side - center.y)),
            for: cacheKey
        )
    }

    private static func localSaturationCursor(
        diameter requestedDiameter: CGFloat,
        mode: ImageEditorSpongeMode
    ) -> NSCursor {
        let diameter = max(3, min(256, requestedDiameter.rounded()))
        let cacheKey = "local-saturation-\(mode.rawValue):\(Int(diameter))"
        if let cachedCursor = cursorCache[cacheKey] {
            return cachedCursor
        }

        let side = max(36, diameter + 18)
        let center = NSPoint(x: side / 2, y: side / 2)
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()

        let footprint = NSBezierPath(ovalIn: NSRect(
            x: center.x - diameter / 2,
            y: center.y - diameter / 2,
            width: diameter,
            height: diameter
        ))
        NSColor.black.withAlphaComponent(0.95).setStroke()
        footprint.lineWidth = 3.5
        footprint.stroke()
        NSColor.white.withAlphaComponent(0.98).setStroke()
        footprint.lineWidth = 1.4
        footprint.stroke()

        // A fixed hue moving between gray and vivid color previews the actual
        // saturation result without shrinking a sponge-shaped toolbox icon.
        let sampleDiameter = max(2.5, min(5, diameter * 0.16))
        let sampleSpacing = max(4, min(8, diameter * 0.27))
        let saturations: [CGFloat] = mode == .saturate
            ? [0.08, 0.48, 0.95]
            : [0.95, 0.48, 0.08]
        for (index, saturation) in saturations.enumerated() {
            let offset = CGFloat(index - 1) * sampleSpacing
            let rect = NSRect(
                x: center.x + offset - sampleDiameter / 2,
                y: center.y + sampleSpacing * 0.2 - sampleDiameter / 2,
                width: sampleDiameter,
                height: sampleDiameter
            )
            NSColor(
                calibratedHue: 0.58,
                saturation: saturation,
                brightness: 0.9,
                alpha: 1
            ).setFill()
            NSBezierPath(ovalIn: rect).fill()
            NSColor.black.withAlphaComponent(0.9).setStroke()
            let outline = NSBezierPath(ovalIn: rect)
            outline.lineWidth = 0.8
            outline.stroke()
        }

        let endpoint = NSPoint(
            x: center.x + sampleSpacing,
            y: center.y - sampleSpacing * 0.65
        )
        let change = NSBezierPath()
        change.move(to: NSPoint(
            x: center.x - sampleSpacing,
            y: center.y - sampleSpacing * 0.65
        ))
        change.line(to: endpoint)
        change.move(to: endpoint)
        change.line(to: NSPoint(x: endpoint.x - 3.5, y: endpoint.y + 2.8))
        change.move(to: endpoint)
        change.line(to: NSPoint(x: endpoint.x - 3.5, y: endpoint.y - 2.8))
        NSColor.black.withAlphaComponent(0.95).setStroke()
        change.lineWidth = 3.5
        change.stroke()
        (mode == .saturate ? NSColor.systemBlue : NSColor.systemGray).setStroke()
        change.lineWidth = 1.2
        change.stroke()

        image.unlockFocus()
        return cache(
            NSCursor(image: image, hotSpot: NSPoint(x: center.x, y: side - center.y)),
            for: cacheKey
        )
    }

    private static func localDetailSoftenCursor(diameter requestedDiameter: CGFloat) -> NSCursor {
        let diameter = max(3, min(256, requestedDiameter.rounded()))
        let cacheKey = "local-detail-soften:\(Int(diameter))"
        if let cachedCursor = cursorCache[cacheKey] {
            return cachedCursor
        }

        let side = max(36, diameter + 18)
        let center = NSPoint(x: side / 2, y: side / 2)
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()

        let footprint = NSBezierPath(ovalIn: NSRect(
            x: center.x - diameter / 2,
            y: center.y - diameter / 2,
            width: diameter,
            height: diameter
        ))
        NSColor.black.withAlphaComponent(0.95).setStroke()
        footprint.lineWidth = 3.5
        footprint.stroke()
        NSColor.white.withAlphaComponent(0.98).setStroke()
        footprint.lineWidth = 1.4
        footprint.stroke()

        // A crisp two-tone edge becomes overlapping translucent samples,
        // previewing local detail diffusion instead of repeating a droplet.
        let sampleSize = max(2.5, min(5, diameter * 0.16))
        let sampleSpacing = max(4, min(8, diameter * 0.27))
        let sharpRect = NSRect(
            x: center.x - sampleSpacing - sampleSize / 2,
            y: center.y - sampleSize / 2,
            width: sampleSize,
            height: sampleSize
        )
        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(
            x: sharpRect.minX,
            y: sharpRect.midY,
            width: sharpRect.width,
            height: sharpRect.height / 2
        )).fill()
        NSColor.black.setFill()
        NSBezierPath(rect: NSRect(
            x: sharpRect.minX,
            y: sharpRect.minY,
            width: sharpRect.width,
            height: sharpRect.height / 2
        )).fill()
        NSColor.black.withAlphaComponent(0.95).setStroke()
        let sharpOutline = NSBezierPath(rect: sharpRect)
        sharpOutline.lineWidth = 0.8
        sharpOutline.stroke()

        let diffuseCenter = NSPoint(x: center.x + sampleSpacing, y: center.y)
        let diffuseScales: [(scale: CGFloat, alpha: CGFloat)] = [
            (1.7, 0.1), (1.2, 0.2), (0.7, 0.36)
        ]
        for layer in diffuseScales {
            let layerSize = sampleSize * layer.scale
            NSColor.systemBlue.withAlphaComponent(layer.alpha).setFill()
            NSBezierPath(ovalIn: NSRect(
                x: diffuseCenter.x - layerSize / 2,
                y: diffuseCenter.y - layerSize / 2,
                width: layerSize,
                height: layerSize
            )).fill()
        }

        let endpoint = NSPoint(
            x: center.x + sampleSpacing,
            y: center.y - sampleSpacing * 0.72
        )
        let diffusion = NSBezierPath()
        diffusion.move(to: NSPoint(
            x: center.x - sampleSpacing,
            y: center.y - sampleSpacing * 0.72
        ))
        diffusion.line(to: endpoint)
        diffusion.move(to: endpoint)
        diffusion.line(to: NSPoint(x: endpoint.x - 3.5, y: endpoint.y + 2.8))
        diffusion.move(to: endpoint)
        diffusion.line(to: NSPoint(x: endpoint.x - 3.5, y: endpoint.y - 2.8))
        NSColor.black.withAlphaComponent(0.95).setStroke()
        diffusion.lineWidth = 3.5
        diffusion.stroke()
        NSColor.systemBlue.setStroke()
        diffusion.lineWidth = 1.2
        diffusion.stroke()

        image.unlockFocus()
        return cache(
            NSCursor(image: image, hotSpot: NSPoint(x: center.x, y: side - center.y)),
            for: cacheKey
        )
    }

    private static func localDetailSharpenCursor(diameter requestedDiameter: CGFloat) -> NSCursor {
        let diameter = max(3, min(256, requestedDiameter.rounded()))
        let cacheKey = "local-detail-sharpen:\(Int(diameter))"
        if let cachedCursor = cursorCache[cacheKey] {
            return cachedCursor
        }

        let side = max(36, diameter + 18)
        let center = NSPoint(x: side / 2, y: side / 2)
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()

        let footprint = NSBezierPath(ovalIn: NSRect(
            x: center.x - diameter / 2,
            y: center.y - diameter / 2,
            width: diameter,
            height: diameter
        ))
        NSColor.black.withAlphaComponent(0.95).setStroke()
        footprint.lineWidth = 3.5
        footprint.stroke()
        NSColor.white.withAlphaComponent(0.98).setStroke()
        footprint.lineWidth = 1.4
        footprint.stroke()

        // A low-contrast diffuse sample becomes a crisp two-tone edge,
        // previewing local contrast gain instead of repeating a star icon.
        let sampleSize = max(2.5, min(5, diameter * 0.16))
        let sampleSpacing = max(4, min(8, diameter * 0.27))
        let diffuseCenter = NSPoint(x: center.x - sampleSpacing, y: center.y)
        let diffuseScales: [(scale: CGFloat, alpha: CGFloat)] = [
            (1.7, 0.08), (1.2, 0.16), (0.7, 0.28)
        ]
        for layer in diffuseScales {
            let layerSize = sampleSize * layer.scale
            NSColor.systemOrange.withAlphaComponent(layer.alpha).setFill()
            NSBezierPath(ovalIn: NSRect(
                x: diffuseCenter.x - layerSize / 2,
                y: diffuseCenter.y - layerSize / 2,
                width: layerSize,
                height: layerSize
            )).fill()
        }

        let sharpRect = NSRect(
            x: center.x + sampleSpacing - sampleSize / 2,
            y: center.y - sampleSize / 2,
            width: sampleSize,
            height: sampleSize
        )
        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(
            x: sharpRect.minX,
            y: sharpRect.midY,
            width: sharpRect.width,
            height: sharpRect.height / 2
        )).fill()
        NSColor.black.setFill()
        NSBezierPath(rect: NSRect(
            x: sharpRect.minX,
            y: sharpRect.minY,
            width: sharpRect.width,
            height: sharpRect.height / 2
        )).fill()
        NSColor.systemOrange.setStroke()
        let sharpOutline = NSBezierPath(rect: sharpRect)
        sharpOutline.lineWidth = 1.2
        sharpOutline.stroke()

        let endpoint = NSPoint(
            x: center.x + sampleSpacing,
            y: center.y - sampleSpacing * 0.72
        )
        let contrastGain = NSBezierPath()
        contrastGain.move(to: NSPoint(
            x: center.x - sampleSpacing,
            y: center.y - sampleSpacing * 0.72
        ))
        contrastGain.line(to: endpoint)
        contrastGain.move(to: endpoint)
        contrastGain.line(to: NSPoint(x: endpoint.x - 3.5, y: endpoint.y + 2.8))
        contrastGain.move(to: endpoint)
        contrastGain.line(to: NSPoint(x: endpoint.x - 3.5, y: endpoint.y - 2.8))
        NSColor.black.withAlphaComponent(0.95).setStroke()
        contrastGain.lineWidth = 3.5
        contrastGain.stroke()
        NSColor.systemOrange.setStroke()
        contrastGain.lineWidth = 1.2
        contrastGain.stroke()

        image.unlockFocus()
        return cache(
            NSCursor(image: image, hotSpot: NSPoint(x: center.x, y: side - center.y)),
            for: cacheKey
        )
    }

    private static func pixelSmearCursor(diameter requestedDiameter: CGFloat) -> NSCursor {
        let diameter = max(3, min(256, requestedDiameter.rounded()))
        let cacheKey = "pixel-smear:\(Int(diameter))"
        if let cachedCursor = cursorCache[cacheKey] {
            return cachedCursor
        }

        let side = max(36, diameter + 18)
        let center = NSPoint(x: side / 2, y: side / 2)
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()

        let footprint = NSBezierPath(ovalIn: NSRect(
            x: center.x - diameter / 2,
            y: center.y - diameter / 2,
            width: diameter,
            height: diameter
        ))
        NSColor.black.withAlphaComponent(0.95).setStroke()
        footprint.lineWidth = 3.5
        footprint.stroke()
        NSColor.white.withAlphaComponent(0.98).setStroke()
        footprint.lineWidth = 1.4
        footprint.stroke()

        // Three sampled colors stretch into converging trails, previewing
        // directional pixel transport and mixing rather than a finger icon.
        let sampleDiameter = max(2.4, min(4.6, diameter * 0.15))
        let travel = max(7, min(13, diameter * 0.34))
        let startX = center.x - travel * 0.58
        let endX = center.x + travel * 0.55
        let offsets: [CGFloat] = [-1, 0, 1]
        let colors: [NSColor] = [.systemCyan, .systemPink, .systemOrange]
        for (index, offset) in offsets.enumerated() {
            let start = NSPoint(
                x: startX,
                y: center.y + offset * sampleDiameter * 1.25
            )
            let end = NSPoint(
                x: endX,
                y: center.y + offset * sampleDiameter * 0.35
            )
            let trail = NSBezierPath()
            trail.move(to: start)
            trail.curve(
                to: end,
                controlPoint1: NSPoint(x: center.x - travel * 0.1, y: start.y),
                controlPoint2: NSPoint(x: center.x + travel * 0.15, y: end.y)
            )
            NSColor.black.withAlphaComponent(0.9).setStroke()
            trail.lineWidth = 3.2
            trail.stroke()
            colors[index].withAlphaComponent(0.9).setStroke()
            trail.lineWidth = 1.3
            trail.stroke()

            colors[index].setFill()
            NSBezierPath(ovalIn: NSRect(
                x: start.x - sampleDiameter / 2,
                y: start.y - sampleDiameter / 2,
                width: sampleDiameter,
                height: sampleDiameter
            )).fill()
        }

        let arrowTip = NSPoint(x: endX + 2.2, y: center.y)
        let direction = NSBezierPath()
        direction.move(to: NSPoint(x: endX - 2.5, y: center.y))
        direction.line(to: arrowTip)
        direction.move(to: arrowTip)
        direction.line(to: NSPoint(x: arrowTip.x - 3.6, y: arrowTip.y + 3))
        direction.move(to: arrowTip)
        direction.line(to: NSPoint(x: arrowTip.x - 3.6, y: arrowTip.y - 3))
        NSColor.black.withAlphaComponent(0.95).setStroke()
        direction.lineWidth = 3.5
        direction.stroke()
        NSColor.systemPurple.setStroke()
        direction.lineWidth = 1.2
        direction.stroke()

        image.unlockFocus()
        return cache(
            NSCursor(image: image, hotSpot: NSPoint(x: center.x, y: side - center.y)),
            for: cacheKey
        )
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

    private static func freeformSelectionPathCursor(
        mode: ImageEditorSelectionCursorMode
    ) -> NSCursor {
        let cacheKey = "freeform-selection-path:\(mode.rawValue)"
        if let cachedCursor = cursorCache[cacheKey] {
            return cachedCursor
        }
        let side: CGFloat = 36
        let origin = NSPoint(x: 8, y: 10)
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()

        // Show the path the pointer will draw, plus the closure that happens
        // on release. A rope loop describes the tool name; this describes the
        // actual freehand selection transaction.
        let freeformPath = NSBezierPath()
        freeformPath.move(to: origin)
        freeformPath.curve(
            to: NSPoint(x: 14, y: 4),
            controlPoint1: NSPoint(x: 8, y: 6),
            controlPoint2: NSPoint(x: 10, y: 4)
        )
        freeformPath.curve(
            to: NSPoint(x: 23, y: 7),
            controlPoint1: NSPoint(x: 18, y: 3),
            controlPoint2: NSPoint(x: 22, y: 4)
        )
        freeformPath.curve(
            to: NSPoint(x: 21, y: 16),
            controlPoint1: NSPoint(x: 26, y: 10),
            controlPoint2: NSPoint(x: 24, y: 14)
        )
        freeformPath.curve(
            to: NSPoint(x: 12, y: 21),
            controlPoint1: NSPoint(x: 18, y: 20),
            controlPoint2: NSPoint(x: 15, y: 21)
        )
        freeformPath.curve(
            to: NSPoint(x: 5, y: 15),
            controlPoint1: NSPoint(x: 8, y: 21),
            controlPoint2: NSPoint(x: 5, y: 18)
        )
        freeformPath.setLineDash([2.5, 2], count: 2, phase: 0)
        NSColor.black.withAlphaComponent(0.95).setStroke()
        freeformPath.lineWidth = 3
        freeformPath.stroke()
        NSColor.white.setStroke()
        freeformPath.lineWidth = 1
        freeformPath.stroke()

        let closureGuide = NSBezierPath()
        closureGuide.move(to: NSPoint(x: 5, y: 15))
        closureGuide.line(to: origin)
        closureGuide.move(to: origin)
        closureGuide.line(to: NSPoint(x: 5.5, y: 9))
        closureGuide.move(to: origin)
        closureGuide.line(to: NSPoint(x: 7, y: 12.5))
        NSColor.black.withAlphaComponent(0.95).setStroke()
        closureGuide.lineWidth = 3
        closureGuide.stroke()
        NSColor.systemBlue.setStroke()
        closureGuide.lineWidth = 1
        closureGuide.stroke()

        let startRing = NSBezierPath(ovalIn: NSRect(
            x: origin.x - 3,
            y: origin.y - 3,
            width: 6,
            height: 6
        ))
        NSColor.black.withAlphaComponent(0.95).setFill()
        startRing.fill()
        let startPoint = NSBezierPath(ovalIn: NSRect(
            x: origin.x - 1.5,
            y: origin.y - 1.5,
            width: 3,
            height: 3
        ))
        NSColor.systemBlue.setFill()
        startPoint.fill()
        drawSelectionModifierBadge(mode, side: side)
        image.unlockFocus()
        return cache(
            NSCursor(image: image, hotSpot: NSPoint(x: origin.x, y: side - origin.y)),
            for: cacheKey
        )
    }

    private static func similarColorSelectionCursor(
        mode: ImageEditorSelectionCursorMode
    ) -> NSCursor {
        let cacheKey = "similar-color-selection:\(mode.rawValue)"
        if let cachedCursor = cursorCache[cacheKey] {
            return cachedCursor
        }
        let side: CGFloat = 36
        let seed = NSPoint(x: 10, y: 10)
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()

        // Preview the contiguous result: an irregular marching-ants boundary
        // grows from the exact sampled pixel instead of reproducing a wand.
        let region = NSBezierPath()
        region.move(to: NSPoint(x: 3, y: 9))
        region.curve(
            to: NSPoint(x: 8, y: 3),
            controlPoint1: NSPoint(x: 3, y: 6),
            controlPoint2: NSPoint(x: 5, y: 4)
        )
        region.curve(
            to: NSPoint(x: 16, y: 4),
            controlPoint1: NSPoint(x: 11, y: 2),
            controlPoint2: NSPoint(x: 14, y: 3)
        )
        region.curve(
            to: NSPoint(x: 20, y: 11),
            controlPoint1: NSPoint(x: 19, y: 5),
            controlPoint2: NSPoint(x: 21, y: 8)
        )
        region.curve(
            to: NSPoint(x: 15, y: 18),
            controlPoint1: NSPoint(x: 20, y: 14),
            controlPoint2: NSPoint(x: 18, y: 17)
        )
        region.curve(
            to: NSPoint(x: 7, y: 17),
            controlPoint1: NSPoint(x: 12, y: 19),
            controlPoint2: NSPoint(x: 9, y: 18)
        )
        region.curve(
            to: NSPoint(x: 3, y: 9),
            controlPoint1: NSPoint(x: 4, y: 15),
            controlPoint2: NSPoint(x: 2, y: 12)
        )
        region.close()
        region.setLineDash([2.5, 2], count: 2, phase: 0)
        NSColor.black.withAlphaComponent(0.95).setStroke()
        region.lineWidth = 3
        region.stroke()
        NSColor.white.setStroke()
        region.lineWidth = 1
        region.stroke()

        let expansion = NSBezierPath()
        expansion.move(to: NSPoint(x: 20, y: 11))
        expansion.line(to: NSPoint(x: 26, y: 11))
        expansion.move(to: NSPoint(x: 26, y: 11))
        expansion.line(to: NSPoint(x: 23, y: 8))
        expansion.move(to: NSPoint(x: 26, y: 11))
        expansion.line(to: NSPoint(x: 23, y: 14))
        expansion.move(to: NSPoint(x: 12, y: 19))
        expansion.line(to: NSPoint(x: 12, y: 25))
        expansion.move(to: NSPoint(x: 12, y: 25))
        expansion.line(to: NSPoint(x: 9, y: 22))
        expansion.move(to: NSPoint(x: 12, y: 25))
        expansion.line(to: NSPoint(x: 15, y: 22))
        NSColor.black.withAlphaComponent(0.95).setStroke()
        expansion.lineWidth = 3
        expansion.stroke()
        NSColor.systemBlue.setStroke()
        expansion.lineWidth = 1
        expansion.stroke()

        let seedRing = NSBezierPath(ovalIn: NSRect(
            x: seed.x - 3,
            y: seed.y - 3,
            width: 6,
            height: 6
        ))
        NSColor.black.withAlphaComponent(0.95).setFill()
        seedRing.fill()
        let seedPoint = NSBezierPath(ovalIn: NSRect(
            x: seed.x - 1.5,
            y: seed.y - 1.5,
            width: 3,
            height: 3
        ))
        NSColor.systemBlue.setFill()
        seedPoint.fill()
        drawSelectionModifierBadge(mode, side: side)
        image.unlockFocus()
        return cache(
            NSCursor(image: image, hotSpot: NSPoint(x: seed.x, y: side - seed.y)),
            for: cacheKey
        )
    }

    private static func paintedRegionSelectionCursor(
        mode: ImageEditorSelectionCursorMode
    ) -> NSCursor {
        let cacheKey = "painted-region-selection:\(mode.rawValue)"
        if let cachedCursor = cursorCache[cacheKey] {
            return cachedCursor
        }

        let side: CGFloat = 38
        let origin = NSPoint(x: 7, y: 7)
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()

        // Quick Selection samples several contiguous colour regions along the
        // drag path and merges them. Preview that transaction instead of
        // shrinking the toolbox brush-and-plus icon into the pointer.
        let mergedBoundary = NSBezierPath()
        mergedBoundary.move(to: NSPoint(x: 4, y: 10))
        mergedBoundary.curve(
            to: NSPoint(x: 11, y: 3),
            controlPoint1: NSPoint(x: 4, y: 6),
            controlPoint2: NSPoint(x: 7, y: 3)
        )
        mergedBoundary.curve(
            to: NSPoint(x: 20, y: 7),
            controlPoint1: NSPoint(x: 15, y: 2),
            controlPoint2: NSPoint(x: 18, y: 4)
        )
        mergedBoundary.curve(
            to: NSPoint(x: 29, y: 12),
            controlPoint1: NSPoint(x: 24, y: 5),
            controlPoint2: NSPoint(x: 28, y: 8)
        )
        mergedBoundary.curve(
            to: NSPoint(x: 25, y: 23),
            controlPoint1: NSPoint(x: 31, y: 17),
            controlPoint2: NSPoint(x: 29, y: 21)
        )
        mergedBoundary.curve(
            to: NSPoint(x: 14, y: 27),
            controlPoint1: NSPoint(x: 21, y: 27),
            controlPoint2: NSPoint(x: 17, y: 28)
        )
        mergedBoundary.curve(
            to: NSPoint(x: 5, y: 20),
            controlPoint1: NSPoint(x: 9, y: 27),
            controlPoint2: NSPoint(x: 5, y: 24)
        )
        mergedBoundary.curve(
            to: NSPoint(x: 4, y: 10),
            controlPoint1: NSPoint(x: 3, y: 16),
            controlPoint2: NSPoint(x: 3, y: 13)
        )
        mergedBoundary.close()
        mergedBoundary.setLineDash([3, 2], count: 2, phase: 0)
        NSColor.black.withAlphaComponent(0.95).setStroke()
        mergedBoundary.lineWidth = 3.5
        mergedBoundary.stroke()
        NSColor.white.withAlphaComponent(0.98).setStroke()
        mergedBoundary.lineWidth = 1.2
        mergedBoundary.stroke()

        let samplingTrail = NSBezierPath()
        samplingTrail.move(to: origin)
        samplingTrail.curve(
            to: NSPoint(x: 21, y: 18),
            controlPoint1: NSPoint(x: 11, y: 8),
            controlPoint2: NSPoint(x: 16, y: 14)
        )
        NSColor.black.withAlphaComponent(0.95).setStroke()
        samplingTrail.lineWidth = 3.5
        samplingTrail.stroke()
        NSColor.systemBlue.setStroke()
        samplingTrail.lineWidth = 1.3
        samplingTrail.stroke()

        for point in [origin, NSPoint(x: 13, y: 11), NSPoint(x: 21, y: 18)] {
            let ring = NSBezierPath(ovalIn: NSRect(
                x: point.x - 2.75,
                y: point.y - 2.75,
                width: 5.5,
                height: 5.5
            ))
            NSColor.black.withAlphaComponent(0.95).setFill()
            ring.fill()
            NSColor.systemBlue.setFill()
            NSBezierPath(ovalIn: NSRect(
                x: point.x - 1.25,
                y: point.y - 1.25,
                width: 2.5,
                height: 2.5
            )).fill()
        }

        let growth = NSBezierPath()
        growth.move(to: NSPoint(x: 23, y: 18))
        growth.line(to: NSPoint(x: 28, y: 18))
        growth.move(to: NSPoint(x: 28, y: 18))
        growth.line(to: NSPoint(x: 25.5, y: 15.5))
        growth.move(to: NSPoint(x: 28, y: 18))
        growth.line(to: NSPoint(x: 25.5, y: 20.5))
        NSColor.black.withAlphaComponent(0.95).setStroke()
        growth.lineWidth = 3
        growth.stroke()
        NSColor.systemBlue.setStroke()
        growth.lineWidth = 1
        growth.stroke()
        drawSelectionModifierBadge(mode, side: side)

        image.unlockFocus()
        return cache(
            NSCursor(image: image, hotSpot: NSPoint(x: origin.x, y: side - origin.y)),
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

    private static func cloneTransferCursor(diameter requestedDiameter: CGFloat) -> NSCursor {
        let diameter = max(3, min(256, requestedDiameter.rounded()))
        let cacheKey = "sampled-pixel-transfer:\(Int(diameter))"
        if let cachedCursor = cursorCache[cacheKey] {
            return cachedCursor
        }

        let side = max(36, diameter + 18)
        let center = NSPoint(x: side / 2, y: side / 2)
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()

        // The ring is the exact destination footprint. A small pixel matrix
        // and straight transfer arrow communicate that Clone Stamp copies
        // sampled pixels unchanged, unlike Healing Brush's blended repair.
        let footprint = NSBezierPath(ovalIn: NSRect(
            x: center.x - diameter / 2,
            y: center.y - diameter / 2,
            width: diameter,
            height: diameter
        ))
        NSColor.black.withAlphaComponent(0.95).setStroke()
        footprint.lineWidth = 3.5
        footprint.stroke()
        NSColor.white.withAlphaComponent(0.98).setStroke()
        footprint.lineWidth = 1.4
        footprint.stroke()

        let transferDistance = max(3, min(9, diameter * 0.3))
        let sourceCenter = NSPoint(
            x: center.x - transferDistance,
            y: center.y + transferDistance
        )
        let destinationCenter = NSPoint(
            x: center.x + transferDistance * 0.35,
            y: center.y - transferDistance * 0.35
        )
        let transfer = NSBezierPath()
        transfer.move(to: sourceCenter)
        transfer.line(to: destinationCenter)
        transfer.move(to: destinationCenter)
        transfer.line(to: NSPoint(
            x: destinationCenter.x - 4.5,
            y: destinationCenter.y + 0.5
        ))
        transfer.move(to: destinationCenter)
        transfer.line(to: NSPoint(
            x: destinationCenter.x - 0.5,
            y: destinationCenter.y + 4.5
        ))
        NSColor.black.withAlphaComponent(0.95).setStroke()
        transfer.lineWidth = 3.5
        transfer.stroke()
        NSColor.systemBlue.setStroke()
        transfer.lineWidth = 1.2
        transfer.stroke()

        let cellSide = max(1.5, min(3, diameter * 0.1))
        for row in 0..<2 {
            for column in 0..<2 {
                let isBlue = (row + column).isMultiple(of: 2)
                let rect = NSRect(
                    x: sourceCenter.x - cellSide + CGFloat(column) * cellSide,
                    y: sourceCenter.y - cellSide + CGFloat(row) * cellSide,
                    width: cellSide,
                    height: cellSide
                )
                (isBlue ? NSColor.systemBlue : NSColor.white).setFill()
                NSBezierPath(rect: rect).fill()
                NSColor.black.withAlphaComponent(0.9).setStroke()
                let cell = NSBezierPath(rect: rect)
                cell.lineWidth = 0.75
                cell.stroke()
            }
        }

        image.unlockFocus()
        return cache(
            NSCursor(image: image, hotSpot: NSPoint(x: center.x, y: side - center.y)),
            for: cacheKey
        )
    }

    private static func repairBlendCursor(diameter requestedDiameter: CGFloat) -> NSCursor {
        let diameter = max(3, min(256, requestedDiameter.rounded()))
        let cacheKey = "sampled-repair-blend:\(Int(diameter))"
        if let cachedCursor = cursorCache[cacheKey] {
            return cachedCursor
        }

        let side = max(36, diameter + 18)
        let center = NSPoint(x: side / 2, y: side / 2)
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()

        // The outer ring is the actual repair footprint. The inner dashed
        // boundary and texture samples preview the operation's result:
        // sampled detail is transferred, then blended into the destination.
        let footprint = NSBezierPath(ovalIn: NSRect(
            x: center.x - diameter / 2,
            y: center.y - diameter / 2,
            width: diameter,
            height: diameter
        ))
        NSColor.black.withAlphaComponent(0.95).setStroke()
        footprint.lineWidth = 3.5
        footprint.stroke()
        NSColor.white.withAlphaComponent(0.98).setStroke()
        footprint.lineWidth = 1.4
        footprint.stroke()

        let blendDiameter = max(2, diameter * 0.64)
        let blendBoundary = NSBezierPath(ovalIn: NSRect(
            x: center.x - blendDiameter / 2,
            y: center.y - blendDiameter / 2,
            width: blendDiameter,
            height: blendDiameter
        ))
        blendBoundary.setLineDash([2.5, 2], count: 2, phase: 0)
        NSColor.black.withAlphaComponent(0.9).setStroke()
        blendBoundary.lineWidth = 3
        blendBoundary.stroke()
        NSColor.systemBlue.setStroke()
        blendBoundary.lineWidth = 1
        blendBoundary.stroke()

        let transferDistance = max(2.5, min(8, diameter * 0.28))
        let transfer = NSBezierPath()
        transfer.move(to: NSPoint(
            x: center.x - transferDistance,
            y: center.y + transferDistance
        ))
        transfer.line(to: NSPoint(x: center.x - 1.5, y: center.y + 1.5))
        transfer.move(to: NSPoint(x: center.x - 1.5, y: center.y + 1.5))
        transfer.line(to: NSPoint(x: center.x - 5, y: center.y + 1.5))
        transfer.move(to: NSPoint(x: center.x - 1.5, y: center.y + 1.5))
        transfer.line(to: NSPoint(x: center.x - 1.5, y: center.y + 5))
        NSColor.black.withAlphaComponent(0.95).setStroke()
        transfer.lineWidth = 3
        transfer.stroke()
        NSColor.systemBlue.setStroke()
        transfer.lineWidth = 1
        transfer.stroke()

        let textureOffsets = [
            NSPoint(x: -transferDistance * 0.55, y: transferDistance * 0.45),
            NSPoint(x: transferDistance * 0.5, y: -transferDistance * 0.35),
            NSPoint(x: transferDistance * 0.25, y: transferDistance * 0.6)
        ]
        for offset in textureOffsets {
            let sampleCenter = NSPoint(x: center.x + offset.x, y: center.y + offset.y)
            NSColor.black.withAlphaComponent(0.95).setFill()
            NSBezierPath(ovalIn: NSRect(
                x: sampleCenter.x - 2.25,
                y: sampleCenter.y - 2.25,
                width: 4.5,
                height: 4.5
            )).fill()
            let texturePoint = NSBezierPath(ovalIn: NSRect(
                x: sampleCenter.x - 1,
                y: sampleCenter.y - 1,
                width: 2,
                height: 2
            ))
            NSColor.white.setStroke()
            texturePoint.lineWidth = 0.75
            texturePoint.stroke()
            NSColor.systemBlue.setFill()
            texturePoint.fill()
        }

        image.unlockFocus()
        return cache(
            NSCursor(image: image, hotSpot: NSPoint(x: center.x, y: side - center.y)),
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
        let cacheKey = "crop-creation-boundary"
        if let cachedCursor = cursorCache[cacheKey] {
            return cachedCursor
        }

        let side: CGFloat = 36
        let origin = NSPoint(x: 7, y: 7)
        let destination = NSPoint(x: 29, y: 27)
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()

        // Open corner brackets and a rule-of-thirds grid preview the crop
        // boundary that a drag will create. This intentionally differs from
        // the closed vector-shape outline used by rectangle/ellipse tools.
        let corners = NSBezierPath()
        corners.move(to: NSPoint(x: 7, y: 15))
        corners.line(to: origin)
        corners.line(to: NSPoint(x: 15, y: 7))
        corners.move(to: NSPoint(x: 21, y: 7))
        corners.line(to: NSPoint(x: 29, y: 7))
        corners.line(to: NSPoint(x: 29, y: 15))
        corners.move(to: NSPoint(x: 29, y: 19))
        corners.line(to: destination)
        corners.line(to: NSPoint(x: 21, y: 27))
        corners.move(to: NSPoint(x: 15, y: 27))
        corners.line(to: NSPoint(x: 7, y: 27))
        corners.line(to: NSPoint(x: 7, y: 19))
        NSColor.black.withAlphaComponent(0.95).setStroke()
        corners.lineWidth = 4
        corners.stroke()
        NSColor.white.setStroke()
        corners.lineWidth = 1.4
        corners.stroke()

        let thirds = NSBezierPath()
        thirds.move(to: NSPoint(x: 14.3, y: 9))
        thirds.line(to: NSPoint(x: 14.3, y: 25))
        thirds.move(to: NSPoint(x: 21.7, y: 9))
        thirds.line(to: NSPoint(x: 21.7, y: 25))
        thirds.move(to: NSPoint(x: 9, y: 13.7))
        thirds.line(to: NSPoint(x: 27, y: 13.7))
        thirds.move(to: NSPoint(x: 9, y: 20.3))
        thirds.line(to: NSPoint(x: 27, y: 20.3))
        NSColor.black.withAlphaComponent(0.82).setStroke()
        thirds.lineWidth = 2.5
        thirds.stroke()
        NSColor.systemBlue.withAlphaComponent(0.92).setStroke()
        thirds.lineWidth = 1
        thirds.stroke()

        let dragGuide = NSBezierPath()
        dragGuide.move(to: NSPoint(x: 11, y: 11))
        dragGuide.line(to: NSPoint(x: 26, y: 24))
        dragGuide.setLineDash([2.5, 2], count: 2, phase: 0)
        NSColor.black.withAlphaComponent(0.9).setStroke()
        dragGuide.lineWidth = 3
        dragGuide.stroke()
        NSColor.white.setStroke()
        dragGuide.lineWidth = 1.1
        dragGuide.stroke()

        let originRing = NSBezierPath(ovalIn: NSRect(x: 2, y: 2, width: 10, height: 10))
        NSColor.black.withAlphaComponent(0.95).setFill()
        originRing.fill()
        NSColor.white.setStroke()
        originRing.lineWidth = 1.2
        originRing.stroke()
        NSColor.systemBlue.setFill()
        NSBezierPath(ovalIn: NSRect(x: 5, y: 5, width: 4, height: 4)).fill()

        image.unlockFocus()
        return cache(
            NSCursor(image: image, hotSpot: NSPoint(x: origin.x, y: side - origin.y)),
            for: cacheKey
        )
    }

    /// The Patch tool has two opposite data-flow modes. Source samples the
    /// drag endpoint back into the selected target; Destination copies the
    /// selected source outward to the endpoint. Show that transfer direction
    /// rather than a generic four-way move or a mechanical patch-tool icon.
    static func patchTransferCursor(mode: ImageEditorPatchMode) -> NSCursor {
        let cacheKey = "patch-transfer:\(mode.rawValue)"
        if let cachedCursor = cursorCache[cacheKey] {
            return cachedCursor
        }

        let side: CGFloat = 38
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()

        let selectedTile = NSRect(x: 2, y: 13, width: 12, height: 12)
        let endpointTile = NSRect(x: 24, y: 13, width: 12, height: 12)
        let sourceTile = mode == .source ? endpointTile : selectedTile
        let targetTile = mode == .source ? selectedTile : endpointTile

        let source = NSBezierPath(roundedRect: sourceTile, xRadius: 2.5, yRadius: 2.5)
        NSColor.black.withAlphaComponent(0.96).setFill()
        source.fill()
        NSColor.white.withAlphaComponent(0.98).setStroke()
        source.lineWidth = 1.2
        source.stroke()
        NSColor.systemBlue.withAlphaComponent(0.95).setFill()
        NSBezierPath(
            roundedRect: sourceTile.insetBy(dx: 3.2, dy: 3.2),
            xRadius: 1.2,
            yRadius: 1.2
        ).fill()

        let target = NSBezierPath(roundedRect: targetTile, xRadius: 2.5, yRadius: 2.5)
        target.setLineDash([2.2, 1.6], count: 2, phase: 0)
        NSColor.black.withAlphaComponent(0.96).setStroke()
        target.lineWidth = 3.2
        target.stroke()
        NSColor.white.withAlphaComponent(0.98).setStroke()
        target.lineWidth = 1.1
        target.stroke()

        let arrowStart = mode == .source
            ? NSPoint(x: endpointTile.minX - 1, y: endpointTile.midY)
            : NSPoint(x: selectedTile.maxX + 1, y: selectedTile.midY)
        let arrowEnd = mode == .source
            ? NSPoint(x: selectedTile.maxX + 1, y: selectedTile.midY)
            : NSPoint(x: endpointTile.minX - 1, y: endpointTile.midY)
        let arrow = NSBezierPath()
        arrow.move(to: arrowStart)
        arrow.line(to: arrowEnd)
        let direction: CGFloat = arrowEnd.x >= arrowStart.x ? 1 : -1
        arrow.move(to: arrowEnd)
        arrow.line(to: NSPoint(x: arrowEnd.x - direction * 4.5, y: arrowEnd.y + 3.5))
        arrow.move(to: arrowEnd)
        arrow.line(to: NSPoint(x: arrowEnd.x - direction * 4.5, y: arrowEnd.y - 3.5))
        NSColor.black.withAlphaComponent(0.96).setStroke()
        arrow.lineWidth = 3.4
        arrow.stroke()
        NSColor.white.withAlphaComponent(0.98).setStroke()
        arrow.lineWidth = 1.1
        arrow.stroke()

        image.unlockFocus()
        let hotSpot = NSPoint(x: selectedTile.midX, y: side - selectedTile.midY)
        return cache(NSCursor(image: image, hotSpot: hotSpot), for: cacheKey)
    }

    private static func gradientCursor(isConstrained: Bool) -> NSCursor {
        let cacheKey = "gradient-axis:\(isConstrained)"
        if let cachedCursor = cursorCache[cacheKey] {
            return cachedCursor
        }
        let side: CGFloat = 36
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()

        let origin = NSPoint(x: 8, y: 8)
        let endpoint = NSPoint(x: 28, y: 28)
        let axis = NSBezierPath()
        axis.move(to: NSPoint(x: 11, y: 11))
        axis.line(to: NSPoint(x: 25, y: 25))
        axis.setLineDash([3, 2], count: 2, phase: 0)
        NSColor.black.withAlphaComponent(0.95).setStroke()
        axis.lineWidth = 4
        axis.stroke()
        NSColor.white.setStroke()
        axis.lineWidth = 1.4
        axis.stroke()

        let arrowhead = NSBezierPath()
        arrowhead.move(to: NSPoint(x: 20, y: 27))
        arrowhead.line(to: endpoint)
        arrowhead.line(to: NSPoint(x: 27, y: 20))
        NSColor.black.withAlphaComponent(0.95).setStroke()
        arrowhead.lineWidth = 4
        arrowhead.stroke()
        NSColor.white.setStroke()
        arrowhead.lineWidth = 1.4
        arrowhead.stroke()

        let originRing = NSBezierPath(ovalIn: NSRect(x: 3, y: 3, width: 10, height: 10))
        NSColor.black.withAlphaComponent(0.95).setFill()
        originRing.fill()
        NSColor.white.setStroke()
        originRing.lineWidth = 1.2
        originRing.stroke()
        NSColor.systemBlue.setFill()
        NSBezierPath(ovalIn: NSRect(x: 6, y: 6, width: 4, height: 4)).fill()

        if isConstrained {
            // Shift snaps the real gesture to angle increments. A compact
            // angular guide communicates that constraint without turning the
            // cursor into a miniature gradient-tool icon.
            let baseline = NSBezierPath()
            baseline.move(to: NSPoint(x: 14, y: 8))
            baseline.line(to: NSPoint(x: 22, y: 8))
            NSColor.black.withAlphaComponent(0.95).setStroke()
            baseline.lineWidth = 3
            baseline.stroke()
            NSColor.white.setStroke()
            baseline.lineWidth = 1
            baseline.stroke()

            let angleGuide = NSBezierPath()
            angleGuide.appendArc(
                withCenter: origin,
                radius: 11,
                startAngle: 0,
                endAngle: 45
            )
            NSColor.systemBlue.setStroke()
            angleGuide.lineWidth = 2
            angleGuide.stroke()
        }

        image.unlockFocus()
        return cache(
            NSCursor(image: image, hotSpot: NSPoint(x: origin.x, y: side - origin.y)),
            for: cacheKey
        )
    }

    private static func shapeCreationCursor(for tool: ImageEditorTool) -> NSCursor {
        let cacheKey = "shape-creation:\(tool.rawValue)"
        if let cachedCursor = cursorCache[cacheKey] {
            return cachedCursor
        }

        let side: CGFloat = 36
        let origin = NSPoint(x: 7, y: 7)
        let destination = NSPoint(x: 29, y: 27)
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()

        // The hot spot is the real drag origin. The dashed outline previews
        // the vector result, while the diagonal guide explains that dragging
        // away from the seed controls both dimensions. This communicates the
        // pending action instead of reproducing a miniature toolbox glyph.
        let shapeBounds = NSRect(
            x: origin.x,
            y: origin.y,
            width: destination.x - origin.x,
            height: destination.y - origin.y
        )
        let outline = tool == .ellipse
            ? NSBezierPath(ovalIn: shapeBounds)
            : NSBezierPath(rect: shapeBounds)
        outline.setLineDash([3, 2], count: 2, phase: 0)
        NSColor.black.withAlphaComponent(0.95).setStroke()
        outline.lineWidth = 3.5
        outline.stroke()
        NSColor.white.setStroke()
        outline.lineWidth = 1.2
        outline.stroke()

        let dimensionGuide = NSBezierPath()
        dimensionGuide.move(to: NSPoint(x: 11, y: 11))
        dimensionGuide.line(to: NSPoint(x: 26, y: 24))
        dimensionGuide.setLineDash([2.5, 2], count: 2, phase: 0)
        NSColor.black.withAlphaComponent(0.92).setStroke()
        dimensionGuide.lineWidth = 3
        dimensionGuide.stroke()
        NSColor.systemBlue.setStroke()
        dimensionGuide.lineWidth = 1.2
        dimensionGuide.stroke()

        let arrowhead = NSBezierPath()
        arrowhead.move(to: NSPoint(x: 21, y: 24))
        arrowhead.line(to: destination)
        arrowhead.line(to: NSPoint(x: 27, y: 19))
        NSColor.black.withAlphaComponent(0.92).setStroke()
        arrowhead.lineWidth = 3
        arrowhead.stroke()
        NSColor.systemBlue.setStroke()
        arrowhead.lineWidth = 1.2
        arrowhead.stroke()

        let originRing = NSBezierPath(ovalIn: NSRect(x: 2, y: 2, width: 10, height: 10))
        NSColor.black.withAlphaComponent(0.95).setFill()
        originRing.fill()
        NSColor.white.setStroke()
        originRing.lineWidth = 1.2
        originRing.stroke()
        NSColor.systemBlue.setFill()
        NSBezierPath(ovalIn: NSRect(x: 5, y: 5, width: 4, height: 4)).fill()

        image.unlockFocus()
        return cache(
            NSCursor(image: image, hotSpot: NSPoint(x: origin.x, y: side - origin.y)),
            for: cacheKey
        )
    }

    private static func drawCursorCrosshair(center: NSPoint) {
        let cross = NSBezierPath()
        cross.move(to: NSPoint(x: center.x - 4, y: center.y))
        cross.line(to: NSPoint(x: center.x + 4, y: center.y))
        cross.move(to: NSPoint(x: center.x, y: center.y - 4))
        cross.line(to: NSPoint(x: center.x, y: center.y + 4))
        NSColor.black.withAlphaComponent(0.95).setStroke()
        cross.lineWidth = 2.5
        cross.stroke()
        NSColor.white.setStroke()
        cross.lineWidth = 1
        cross.stroke()
    }

    private static func regionFillCursor() -> NSCursor {
        let cacheKey = "region-fill-seed"
        if let cachedCursor = cursorCache[cacheKey] {
            return cachedCursor
        }

        let side: CGFloat = 36
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()

        let seed = NSPoint(x: 8, y: 8)
        let innerWave = NSBezierPath()
        innerWave.move(to: NSPoint(x: 13, y: 6))
        innerWave.curve(
            to: NSPoint(x: 17, y: 15),
            controlPoint1: NSPoint(x: 18, y: 7),
            controlPoint2: NSPoint(x: 20, y: 12)
        )
        innerWave.curve(
            to: NSPoint(x: 7, y: 18),
            controlPoint1: NSPoint(x: 14, y: 19),
            controlPoint2: NSPoint(x: 10, y: 20)
        )
        NSColor.black.withAlphaComponent(0.95).setStroke()
        innerWave.lineWidth = 4
        innerWave.stroke()
        NSColor.white.setStroke()
        innerWave.lineWidth = 1.3
        innerWave.stroke()

        let outerWave = NSBezierPath()
        outerWave.move(to: NSPoint(x: 17, y: 4))
        outerWave.curve(
            to: NSPoint(x: 29, y: 18),
            controlPoint1: NSPoint(x: 28, y: 4),
            controlPoint2: NSPoint(x: 32, y: 10)
        )
        outerWave.curve(
            to: NSPoint(x: 9, y: 30),
            controlPoint1: NSPoint(x: 27, y: 27),
            controlPoint2: NSPoint(x: 18, y: 32)
        )
        outerWave.setLineDash([3, 2], count: 2, phase: 0)
        NSColor.black.withAlphaComponent(0.95).setStroke()
        outerWave.lineWidth = 4
        outerWave.stroke()
        NSColor.white.setStroke()
        outerWave.lineWidth = 1.3
        outerWave.stroke()

        let seedRing = NSBezierPath(ovalIn: NSRect(x: 3, y: 3, width: 10, height: 10))
        NSColor.black.withAlphaComponent(0.95).setFill()
        seedRing.fill()
        NSColor.white.setStroke()
        seedRing.lineWidth = 1.2
        seedRing.stroke()
        NSColor.systemBlue.setFill()
        NSBezierPath(ovalIn: NSRect(x: 6, y: 6, width: 4, height: 4)).fill()

        image.unlockFocus()
        return cache(
            NSCursor(image: image, hotSpot: NSPoint(x: seed.x, y: side - seed.y)),
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

    private static func eyedropperCursor(
        target: ImageEditorColorSampleTarget
    ) -> NSCursor {
        let cacheKey = "eyedropper:\(target)"
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

        if target == .background {
            let backSwatch = NSBezierPath(rect: NSRect(x: 2, y: 25, width: 7, height: 7))
            NSColor.white.setFill()
            backSwatch.fill()
            NSColor.black.setStroke()
            backSwatch.lineWidth = 2
            backSwatch.stroke()

            let frontSwatch = NSBezierPath(rect: NSRect(x: 6, y: 21, width: 7, height: 7))
            NSColor.black.setFill()
            frontSwatch.fill()
            NSColor.white.setStroke()
            frontSwatch.lineWidth = 1
            frontSwatch.stroke()
        }

        image.unlockFocus()
        return cache(
            NSCursor(image: image, hotSpot: NSPoint(x: 7, y: side - 7)),
            for: cacheKey
        )
    }

    private static func penCursor(
        isClosing: Bool,
        isConverting: Bool,
        isAddingAnchor: Bool,
        isDeletingAnchor: Bool,
        isContinuingPath: Bool,
        isConstrained: Bool
    ) -> NSCursor {
        let cacheKey = "pen:\(isClosing):\(isConverting):\(isAddingAnchor):\(isDeletingAnchor):\(isContinuingPath):\(isConstrained)"
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
        } else if isConverting {
            let corner = NSBezierPath()
            corner.move(to: NSPoint(x: 1.5, y: 32.5))
            corner.line(to: NSPoint(x: 7, y: 25.5))
            corner.line(to: NSPoint(x: 12.5, y: 32.5))
            NSColor.black.withAlphaComponent(0.95).setStroke()
            corner.lineWidth = 3.5
            corner.stroke()
            NSColor.systemOrange.setStroke()
            corner.lineWidth = 1.4
            corner.stroke()
        } else if isAddingAnchor || isDeletingAnchor || isContinuingPath {
            let badge = NSBezierPath(ovalIn: NSRect(x: 0.5, y: 23.5, width: 12, height: 12))
            NSColor.black.withAlphaComponent(0.94).setFill()
            badge.fill()
            NSColor.white.withAlphaComponent(0.96).setStroke()
            badge.lineWidth = 1
            badge.stroke()

            let plus = NSBezierPath()
            plus.move(to: NSPoint(x: 3.5, y: 29.5))
            plus.line(to: NSPoint(x: 9.5, y: 29.5))
            if isAddingAnchor {
                plus.move(to: NSPoint(x: 6.5, y: 26.5))
                plus.line(to: NSPoint(x: 6.5, y: 32.5))
            } else if isContinuingPath {
                plus.move(to: NSPoint(x: 3.5, y: 26.5))
                plus.line(to: NSPoint(x: 9.5, y: 32.5))
            }
            (isDeletingAnchor ? NSColor.systemRed : NSColor.systemGreen).setStroke()
            plus.lineWidth = 1.5
            plus.stroke()
        } else if isConstrained {
            let badgeRect = NSRect(x: 0.5, y: 23.5, width: 12, height: 12)
            let badge = NSBezierPath(ovalIn: badgeRect)
            NSColor.black.withAlphaComponent(0.94).setFill()
            badge.fill()
            NSColor.white.withAlphaComponent(0.96).setStroke()
            badge.lineWidth = 1
            badge.stroke()

            let angleGuide = NSBezierPath()
            angleGuide.move(to: NSPoint(x: 3.5, y: 27))
            angleGuide.line(to: NSPoint(x: 3.5, y: 32.5))
            angleGuide.line(to: NSPoint(x: 9, y: 32.5))
            angleGuide.move(to: NSPoint(x: 3.5, y: 27))
            angleGuide.line(to: NSPoint(x: 9, y: 32.5))
            NSColor.systemBlue.setStroke()
            angleGuide.lineWidth = 1.25
            angleGuide.stroke()
        }

        image.unlockFocus()
        return cache(NSCursor(image: image, hotSpot: NSPoint(x: 6, y: side - 6)), for: cacheKey)
    }

    private static func zoomCursor(isZoomingOut: Bool) -> NSCursor {
        let cacheKey = "zoom:viewport-scale:\(isZoomingOut ? "out" : "in")"
        if let cachedCursor = cursorCache[cacheKey] {
            return cachedCursor
        }

        let side: CGFloat = 36
        let center = NSPoint(x: side / 2, y: side / 2)
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()

        // The click point is the actual zoom focus. Four directional arrows
        // preview whether content will expand away from that focus or contract
        // toward it, instead of reproducing a magnifying-glass toolbox icon.
        let corners = NSBezierPath()
        corners.move(to: NSPoint(x: 4, y: 11))
        corners.line(to: NSPoint(x: 4, y: 4))
        corners.line(to: NSPoint(x: 11, y: 4))
        corners.move(to: NSPoint(x: 25, y: 4))
        corners.line(to: NSPoint(x: 32, y: 4))
        corners.line(to: NSPoint(x: 32, y: 11))
        corners.move(to: NSPoint(x: 32, y: 25))
        corners.line(to: NSPoint(x: 32, y: 32))
        corners.line(to: NSPoint(x: 25, y: 32))
        corners.move(to: NSPoint(x: 11, y: 32))
        corners.line(to: NSPoint(x: 4, y: 32))
        corners.line(to: NSPoint(x: 4, y: 25))
        NSColor.black.withAlphaComponent(0.94).setStroke()
        corners.lineWidth = 4
        corners.stroke()
        NSColor.white.setStroke()
        corners.lineWidth = 1.4
        corners.stroke()

        func drawScaleArrow(inner: NSPoint, outer: NSPoint) {
            let start = isZoomingOut ? outer : inner
            let tip = isZoomingOut ? inner : outer
            let deltaX = tip.x - start.x
            let deltaY = tip.y - start.y
            let length = max(1, hypot(deltaX, deltaY))
            let unitX = deltaX / length
            let unitY = deltaY / length
            let perpendicularX = -unitY
            let perpendicularY = unitX
            let arrowLength: CGFloat = 4.5
            let arrowWidth: CGFloat = 2.2

            let path = NSBezierPath()
            path.move(to: start)
            path.line(to: tip)
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
            NSColor.black.withAlphaComponent(0.94).setStroke()
            path.lineWidth = 3.5
            path.stroke()
            NSColor.systemBlue.setStroke()
            path.lineWidth = 1.2
            path.stroke()
        }

        drawScaleArrow(inner: NSPoint(x: 14, y: 14), outer: NSPoint(x: 8, y: 8))
        drawScaleArrow(inner: NSPoint(x: 22, y: 14), outer: NSPoint(x: 28, y: 8))
        drawScaleArrow(inner: NSPoint(x: 14, y: 22), outer: NSPoint(x: 8, y: 28))
        drawScaleArrow(inner: NSPoint(x: 22, y: 22), outer: NSPoint(x: 28, y: 28))

        let focusRing = NSBezierPath(ovalIn: NSRect(x: 13, y: 13, width: 10, height: 10))
        NSColor.black.withAlphaComponent(0.95).setFill()
        focusRing.fill()
        NSColor.white.setStroke()
        focusRing.lineWidth = 1.2
        focusRing.stroke()
        NSColor.systemBlue.setFill()
        NSBezierPath(ovalIn: NSRect(x: 16, y: 16, width: 4, height: 4)).fill()

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

class CursorRectNSView: NSView {
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
        registerCursorRect(bounds, cursor: cursor)
    }

    func registerCursorRect(_ rect: NSRect, cursor: NSCursor) {
        addCursorRect(rect, cursor: cursor)
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

@MainActor
enum ImageEditorNudgeCommandDispatchGate {
    private struct Dispatch: Equatable {
        let delta: CGSize
        let event: ImageEditorKeyboardShortcutEventSignature
    }

    private static var lastDispatch: Dispatch?

    static func shouldDispatch(
        _ delta: CGSize,
        event: ImageEditorKeyboardShortcutEventSignature?
    ) -> Bool {
        guard let event else { return true }
        let dispatch = Dispatch(delta: delta, event: event)
        guard dispatch != lastDispatch else { return false }
        lastDispatch = dispatch
        return true
    }

    static func reset() {
        lastDispatch = nil
    }
}

enum ImageEditorContextualDocumentDeleteAction: Equatable {
    case clearSelectionPixels
    case deleteSelectedLayer
}

enum ImageEditorContextualDocumentDeletePolicy {
    static func resolve(
        hasSelection: Bool,
        canRemoveSelectionPixels: Bool,
        canDeleteLayer: Bool
    ) -> ImageEditorContextualDocumentDeleteAction? {
        if hasSelection {
            return canRemoveSelectionPixels ? .clearSelectionPixels : nil
        }
        return canDeleteLayer ? .deleteSelectedLayer : nil
    }
}

enum ImageEditorDeleteMenuOwnedContext {
    case absent
    case consumesOnly
    case deletes
}

enum ImageEditorEditMenuDeleteAvailabilityPolicy {
    static func resolve(
        pendingPenOwnership: ImageEditorDeleteMenuOwnedContext,
        overlayHandleOwnership: ImageEditorDeleteMenuOwnedContext,
        canDeleteShapeGradientStop: Bool,
        canDeleteDeliveryObject: Bool,
        canDeleteXomoObject: Bool,
        canDeletePathPoint: Bool,
        documentAction: ImageEditorContextualDocumentDeleteAction?
    ) -> Bool {
        switch pendingPenOwnership {
        case .deletes:
            return true
        case .consumesOnly:
            return false
        case .absent:
            break
        }
        switch overlayHandleOwnership {
        case .deletes:
            return true
        case .consumesOnly:
            return false
        case .absent:
            break
        }
        return canDeleteShapeGradientStop
            || canDeletePathPoint
            || canDeleteDeliveryObject
            || canDeleteXomoObject
            || documentAction != nil
    }
}

enum ImageEditorGradientStopDeleteAvailabilityPolicy {
    static func resolve(
        selectedIndex: Int?,
        stopCount: Int,
        isInteractionAvailable: Bool
    ) -> Bool {
        guard isInteractionAvailable, let selectedIndex else { return false }
        return selectedIndex > 0 && selectedIndex < stopCount - 1
    }
}

extension ImageEditorView {
    var selectedGradientDeleteMenuContext: (
        overlayOwnership: ImageEditorDeleteMenuOwnedContext,
        canDeleteShapeStop: Bool
    ) {
        let overlayInteractionIsAvailable = viewModel.selectedLeftSidebarTab == .tools
            && canvasInteractionTool == .move
            && viewModel.document.areExtrasVisible
            && viewModel.canEditSelectedLayerGradientOverlayCanvasCenter
        let selectedOverlayStop = overlayInteractionIsAvailable
            ? viewModel.selectedLayerGradientOverlayCanvasStopHandlePoints.first(where: {
                $0.index == selectedGradientOverlayStopIndex
            })
            : nil
        let overlayMidpointIsSelected = overlayInteractionIsAvailable
            && selectedGradientOverlayMidpointIndex.map { selectedIndex in
                viewModel.selectedLayerGradientOverlayCanvasMidpointHandlePoints.contains {
                    $0.lowerStopIndex == selectedIndex
                }
            } == true
        let overlayStopCanDelete = ImageEditorGradientStopDeleteAvailabilityPolicy.resolve(
            selectedIndex: selectedOverlayStop?.index,
            stopCount: viewModel.selectedLayerGradientOverlayColorStops.count,
            isInteractionAvailable: selectedOverlayStop != nil
        )
        let shapeStopCanDelete = ImageEditorGradientStopDeleteAvailabilityPolicy.resolve(
            selectedIndex: selectedShapeGradientStopIndex,
            stopCount: viewModel.selectedShapeGradientColorStops.count,
            isInteractionAvailable: canvasInteractionTool == .move
                && viewModel.document.areExtrasVisible
                && viewModel.canEditSelectedShapeGradientStops
                && !viewModel.selectedShapeGradientCanvasStopHandlePoints.isEmpty
        )
        let overlayOwnership: ImageEditorDeleteMenuOwnedContext
        if selectedOverlayStop != nil {
            overlayOwnership = overlayStopCanDelete ? .deletes : .consumesOnly
        } else if overlayMidpointIsSelected {
            overlayOwnership = .consumesOnly
        } else {
            overlayOwnership = .absent
        }
        return (overlayOwnership, shapeStopCanDelete)
    }
}

@MainActor
enum ImageEditorDeleteCommandDispatchGate {
    private static var lastHandledDispatch: ImageEditorKeyboardShortcutEventSignature?

    static func shouldDispatch(
        event: ImageEditorKeyboardShortcutEventSignature?
    ) -> Bool {
        guard let event else { return true }
        return event != lastHandledDispatch
    }

    static func recordDispatch(event: ImageEditorKeyboardShortcutEventSignature?) {
        guard let event else { return }
        lastHandledDispatch = event
    }

    static func reset() {
        lastHandledDispatch = nil
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
    case openSelectionFill
    case fillSelection
    case fillSelectionPreservingTransparency
    case fillSelectionBackground
    case fillSelectionBackgroundPreservingTransparency
    case fillSelectionHistory
    case fillSelectionHistoryPreservingTransparency
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
    case navigateLayerSelection(ImageEditorLayerSelectionNavigation)
    case selectAllLayers
    case selectAll
    case clearSelection
    case reselectSelection
    case invertSelection
    case featherSelection
    case toggleQuickMask
    case toggleQuickMaskGrayscalePreview
    case toggleLayerMaskRubylith
    case applyLastFilter
    case toggleRulers
    case toggleGuides
    case toggleGuideSnapping
    case toggleGuidesLocked
    case toggleGrid
    case toggleCroppedAreaVisibility
    case swapCropOrientation
    case cycleCropGuide
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
        case .cutSelectionClipboard,
             .copySelectionClipboard,
             .pasteClipboardLayer,
             .openSelectionFill,
             .fillSelection,
             .fillSelectionPreservingTransparency,
             .fillSelectionBackground,
             .fillSelectionBackgroundPreservingTransparency,
             .fillSelectionHistory,
             .fillSelectionHistoryPreservingTransparency,
             .clearSelectionPixels,
             .selectAll,
             .undo,
             .redo,
             .colorBalance,
             .invertPixels,
             .hueSaturation,
             .applyLastFilter,
             .toggleTransformControls,
             .curves,
             .levels,
             .groupSelectedLayer,
             .ungroupSelectedLayers,
             .duplicateSelectionOrLayer,
             .cutSelectionToLayer,
             .mergeDown,
             .toggleRulers,
             .layerTop,
             .layerUp,
             .layerDown,
             .layerBottom,
             .navigateLayerSelection,
             .selectAllLayers,
             .toggleQuickMask,
             .toggleQuickMaskGrayscalePreview,
             .toggleLayerMaskRubylith,
             .toggleCroppedAreaVisibility,
             .swapCropOrientation,
             .cycleCropGuide,
             .toneRange,
             .spongeMode:
            true
        default:
            false
        }
    }

    static func resolve(
        charactersIgnoringModifiers: String?,
        modifierFlags: NSEvent.ModifierFlags,
        keyCode: UInt16? = nil,
        activeTool: ImageEditorTool? = nil,
        hasPendingCrop: Bool = false,
        canCycleCropGuide: Bool = false,
        canToggleQuickMaskGrayscalePreview: Bool = false,
        canToggleLayerMaskRubylith: Bool = false
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
            if relevantFlags == [.option, .shift] { return .fillSelectionPreservingTransparency }
            if relevantFlags == [.command] { return .fillSelectionBackground }
            if relevantFlags == [.command, .shift] {
                return .fillSelectionBackgroundPreservingTransparency
            }
            if relevantFlags == [.command, .option] { return .fillSelectionHistory }
            if relevantFlags == [.command, .option, .shift] {
                return .fillSelectionHistoryPreservingTransparency
            }
            return nil
        }

        if keyCode == 96, relevantFlags == [.shift] {
            return .openSelectionFill
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
        if key == "]", relevantFlags == [.option] {
            return .navigateLayerSelection(.above(extendingSelection: false))
        }
        if key == "[", relevantFlags == [.option] {
            return .navigateLayerSelection(.below(extendingSelection: false))
        }
        if key == "]", relevantFlags == [.option, .shift] {
            return .navigateLayerSelection(.above(extendingSelection: true))
        }
        if key == "[", relevantFlags == [.option, .shift] {
            return .navigateLayerSelection(.below(extendingSelection: true))
        }
        if key == ".", relevantFlags == [.option] { return .navigateLayerSelection(.top) }
        if key == ",", relevantFlags == [.option] { return .navigateLayerSelection(.bottom) }
        if key == "]", relevantFlags == [.command, .shift] { return .layerTop }
        if key == "]", relevantFlags == [.command] { return .layerUp }
        if key == "[", relevantFlags == [.command] { return .layerDown }
        if key == "[", relevantFlags == [.command, .shift] { return .layerBottom }
        if key == "a", relevantFlags == [.command, .option] { return .selectAllLayers }
        if key == "a", relevantFlags == [.command] { return .selectAll }
        if key == "d", relevantFlags == [.command] { return .clearSelection }
        if key == "d", relevantFlags == [.command, .shift] { return .reselectSelection }
        if key == "i", relevantFlags == [.command, .shift] { return .invertSelection }
        if key == "d", relevantFlags == [.command, .option] { return .featherSelection }
        if key == "q", relevantFlags.isEmpty { return .toggleQuickMask }
        if (key == "/" || keyCode == 44),
           relevantFlags.isEmpty,
           activeTool == .crop,
           hasPendingCrop {
            return .toggleCroppedAreaVisibility
        }
        if key == "x",
           relevantFlags.isEmpty,
           activeTool == .crop,
           hasPendingCrop {
            return .swapCropOrientation
        }
        if key == "o",
           relevantFlags.isEmpty,
           activeTool == .crop,
           canCycleCropGuide {
            return .cycleCropGuide
        }
        if keyCode == 50,
           relevantFlags == [.shift],
           canToggleQuickMaskGrayscalePreview {
            return .toggleQuickMaskGrayscalePreview
        }
        if (key == "\\" || keyCode == 42),
           relevantFlags.isEmpty,
           canToggleLayerMaskRubylith {
            return .toggleLayerMaskRubylith
        }
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

enum ImageEditorPathAnchorDragLifecyclePolicy {
    static func shouldCancel(
        isMovingPathAnchor: Bool,
        hasActiveTransaction: Bool
    ) -> Bool {
        isMovingPathAnchor || hasActiveTransaction
    }

    static func shouldReleaseCancellationLatch(
        isCancelled: Bool,
        hasActiveTransaction: Bool
    ) -> Bool {
        isCancelled && !hasActiveTransaction
    }
}

enum ImageEditorPendingPenPointerPolicy {
    static func ownsUncommittedPoint(
        tool: ImageEditorTool,
        isPointerSequenceActive: Bool,
        isMovingPathAnchor: Bool
    ) -> Bool {
        tool == .pen && isPointerSequenceActive && !isMovingPathAnchor
    }
}

struct ImageEditorPendingPenGestureAction: Equatable {
    let anchorPoint: CGPoint
    let symmetricControlDrag: CGSize?
}

enum ImageEditorPathAnchorDragConstraint {
    static func shouldConstrain(
        modifierFlags: NSEvent.ModifierFlags,
        viewTranslation: CGSize
    ) -> Bool {
        modifierFlags.contains(.shift)
            && hypot(viewTranslation.width, viewTranslation.height)
                > ImageEditorPendingPenGesturePolicy.minimumSmoothDragDistance
    }
}

enum ImageEditorPenAnchorAutoDeletePolicy {
    static func shouldDelete(viewTranslation: CGSize) -> Bool {
        hypot(viewTranslation.width, viewTranslation.height)
            <= ImageEditorPendingPenGesturePolicy.minimumSmoothDragDistance
    }
}

struct ImageEditorPenAnchorConversionAction: Equatable {
    let anchorPoint: CGPoint
    let symmetricControlDrag: CGSize?
}

enum ImageEditorPenAnchorConversionGesturePolicy {
    static let minimumSmoothDragDistance = ImageEditorPendingPenGesturePolicy
        .minimumSmoothDragDistance

    static func resolve(
        anchorPoint: CGPoint,
        pointerEnd: CGPoint?,
        viewTranslation: CGSize
    ) -> ImageEditorPenAnchorConversionAction {
        guard hypot(viewTranslation.width, viewTranslation.height) > minimumSmoothDragDistance,
              let pointerEnd
        else {
            return ImageEditorPenAnchorConversionAction(
                anchorPoint: anchorPoint,
                symmetricControlDrag: nil
            )
        }
        return ImageEditorPenAnchorConversionAction(
            anchorPoint: anchorPoint,
            symmetricControlDrag: CGSize(
                width: pointerEnd.x - anchorPoint.x,
                height: pointerEnd.y - anchorPoint.y
            )
        )
    }
}

enum ImageEditorPendingPenGesturePolicy {
    static let minimumSmoothDragDistance: CGFloat = 3

    static func resolve(
        startImagePoint: CGPoint?,
        endImagePoint: CGPoint?,
        viewTranslation: CGSize
    ) -> ImageEditorPendingPenGestureAction? {
        guard let endImagePoint else { return nil }
        guard hypot(viewTranslation.width, viewTranslation.height) > minimumSmoothDragDistance,
              let startImagePoint
        else {
            return ImageEditorPendingPenGestureAction(
                anchorPoint: endImagePoint,
                symmetricControlDrag: nil
            )
        }
        return ImageEditorPendingPenGestureAction(
            anchorPoint: startImagePoint,
            symmetricControlDrag: CGSize(
                width: endImagePoint.x - startImagePoint.x,
                height: endImagePoint.y - startImagePoint.y
            )
        )
    }
}

enum ImageEditorLiveMoveShortcutPolicy {
    enum Disposition: Equatable {
        case perform
        case cancelMove
        case ignore
    }

    static func disposition(
        for action: ImageEditorKeyboardShortcutAction,
        hasActiveLayerMoveTransaction: Bool,
        hasActivePathAnchorMoveTransaction: Bool = false
    ) -> Disposition {
        guard hasActiveLayerMoveTransaction || hasActivePathAnchorMoveTransaction else {
            return .perform
        }
        switch action {
        case .undo, .redo:
            return .cancelMove
        default:
            return .ignore
        }
    }

    static func allowsDirectShortcut(
        hasActiveLayerMoveTransaction: Bool,
        hasActivePathAnchorMoveTransaction: Bool = false
    ) -> Bool {
        !hasActiveLayerMoveTransaction && !hasActivePathAnchorMoveTransaction
    }
}

enum ImageEditorSpacebarPanResetPolicy {
    struct Decision: Equatable {
        let shouldStopSpacebarPanning: Bool
        let shouldClearCanvasModifierFlags: Bool
    }

    static func decision(isPanning: Bool) -> Decision {
        Decision(
            shouldStopSpacebarPanning: isPanning,
            shouldClearCanvasModifierFlags: true
        )
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

enum ImageEditorKeyboardShortcutEventWindowPolicy {
    static func belongsToEditorWindow(
        eventWindow: AnyObject?,
        eventWindowNumber: Int,
        editorWindow: AnyObject,
        editorWindowNumber: Int,
        keyWindow: AnyObject?
    ) -> Bool {
        if eventWindow === editorWindow {
            return true
        }
        if eventWindowNumber != 0, eventWindowNumber == editorWindowNumber {
            return true
        }
        return eventWindow == nil
            && eventWindowNumber == 0
            && keyWindow === editorWindow
    }
}

@MainActor
enum ImageEditorKeyboardShortcutWindowRegistry {
    private final class WeakCoordinator {
        weak var value: AnyObject?

        init(_ value: AnyObject) {
            self.value = value
        }
    }

    private static var coordinatorsByWindow: [ObjectIdentifier: [WeakCoordinator]] = [:]

    static func register(coordinator: AnyObject, for window: AnyObject) {
        let windowID = ObjectIdentifier(window)
        var coordinators = coordinatorsByWindow[windowID] ?? []
        coordinators.removeAll { entry in
            entry.value == nil || entry.value === coordinator
        }
        coordinators.append(WeakCoordinator(coordinator))
        coordinatorsByWindow[windowID] = coordinators
    }

    static func unregister(coordinator: AnyObject, from window: AnyObject) {
        let windowID = ObjectIdentifier(window)
        guard var coordinators = coordinatorsByWindow[windowID] else { return }
        coordinators.removeAll { entry in
            entry.value == nil || entry.value === coordinator
        }
        if coordinators.isEmpty {
            coordinatorsByWindow.removeValue(forKey: windowID)
        } else {
            coordinatorsByWindow[windowID] = coordinators
        }
    }

    static func isRegistered(coordinator: AnyObject, for window: AnyObject) -> Bool {
        let windowID = ObjectIdentifier(window)
        guard var coordinators = coordinatorsByWindow[windowID] else { return false }
        coordinators.removeAll { $0.value == nil }
        if coordinators.isEmpty {
            coordinatorsByWindow.removeValue(forKey: windowID)
            return false
        }
        coordinatorsByWindow[windowID] = coordinators
        return coordinators.contains { $0.value === coordinator }
    }

    /// AppKit does not guarantee which per-host local monitor receives a key
    /// first. Contextual Delete therefore uses the newest mounted editor and
    /// only falls back when that editor cannot handle the event.
    static func registeredCoordinatorsNewestFirst(for window: AnyObject) -> [AnyObject] {
        let windowID = ObjectIdentifier(window)
        guard var coordinators = coordinatorsByWindow[windowID] else { return [] }
        coordinators.removeAll { $0.value == nil }
        if coordinators.isEmpty {
            coordinatorsByWindow.removeValue(forKey: windowID)
            return []
        }
        coordinatorsByWindow[windowID] = coordinators
        return coordinators.reversed().compactMap(\.value)
    }

    static func reset() {
        coordinatorsByWindow.removeAll()
    }
}

enum ImageEditorPanelToggleAction: Equatable {
    case workspaceChrome
    case rightDock
}

@MainActor
enum ImageEditorHistoryCommandDispatchGate {
    private static var lastEvent: ImageEditorKeyboardShortcutEventSignature?

    static func shouldDispatch(
        event: ImageEditorKeyboardShortcutEventSignature?
    ) -> Bool {
        guard let event else { return true }
        guard event != lastEvent else { return false }
        lastEvent = event
        return true
    }

    static func reset() {
        lastEvent = nil
    }
}

enum ImageEditorFileCommandAction: Equatable, CaseIterable {
    case createCanvas
    case openProject
    case saveProject
    case export
    case importFigmaLink
}

@MainActor
enum ImageEditorFileCommandDispatchGate {
    private struct Dispatch: Equatable {
        let action: ImageEditorFileCommandAction
        let event: ImageEditorKeyboardShortcutEventSignature
    }

    private static var lastDispatch: Dispatch?

    static func shouldDispatch(
        _ action: ImageEditorFileCommandAction,
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

@MainActor
enum ImageEditorTransformControlsCommandDispatchGate {
    private static var lastEvent: ImageEditorKeyboardShortcutEventSignature?

    static func shouldDispatch(event: ImageEditorKeyboardShortcutEventSignature?) -> Bool {
        guard let event else { return true }
        guard event != lastEvent else { return false }
        lastEvent = event
        return true
    }

    static func reset() {
        lastEvent = nil
    }
}

@MainActor
enum ImageEditorNewLayerCommandDispatchGate {
    private static var lastEvent: ImageEditorKeyboardShortcutEventSignature?

    static func shouldDispatch(
        event: ImageEditorKeyboardShortcutEventSignature?
    ) -> Bool {
        guard let event else { return true }
        guard event != lastEvent else { return false }
        lastEvent = event
        return true
    }

    static func reset() {
        lastEvent = nil
    }
}

enum ImageEditorClipboardCommandAction: Equatable, CaseIterable {
    case cutSelection
    case copySelection
    case copyMerged
    case copySelectedLayers
    case pasteAsLayer
    case pasteIntoSelection
    case pasteInPlace
}

@MainActor
enum ImageEditorClipboardCommandDispatchGate {
    private struct Dispatch: Equatable {
        let action: ImageEditorClipboardCommandAction
        let event: ImageEditorKeyboardShortcutEventSignature
    }

    private static var lastDispatch: Dispatch?

    static func shouldDispatch(
        _ action: ImageEditorClipboardCommandAction,
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

@MainActor
enum ImageEditorLayerDuplicateCommandDispatchGate {
    private static var lastEvent: ImageEditorKeyboardShortcutEventSignature?

    static func shouldDispatch(
        event: ImageEditorKeyboardShortcutEventSignature?
    ) -> Bool {
        guard let event else { return true }
        guard event != lastEvent else { return false }
        lastEvent = event
        return true
    }

    static func reset() {
        lastEvent = nil
    }
}

@MainActor
enum ImageEditorLayerCutCommandDispatchGate {
    private static var lastEvent: ImageEditorKeyboardShortcutEventSignature?

    static func shouldDispatch(
        event: ImageEditorKeyboardShortcutEventSignature?
    ) -> Bool {
        guard let event else { return true }
        guard event != lastEvent else { return false }
        lastEvent = event
        return true
    }

    static func reset() {
        lastEvent = nil
    }
}

enum ImageEditorLayerGroupingCommandAction: Equatable {
    case group
    case ungroup
}

@MainActor
enum ImageEditorLayerGroupingCommandDispatchGate {
    private struct Dispatch: Equatable {
        let action: ImageEditorLayerGroupingCommandAction
        let event: ImageEditorKeyboardShortcutEventSignature
    }

    private static var lastDispatch: Dispatch?

    static func shouldDispatch(
        _ action: ImageEditorLayerGroupingCommandAction,
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

enum ImageEditorLayerMergeCommandAction: Equatable {
    case mergeDown
    case stampVisible
    case mergeVisible
}

@MainActor
enum ImageEditorLayerMergeCommandDispatchGate {
    private struct Dispatch: Equatable {
        let action: ImageEditorLayerMergeCommandAction
        let event: ImageEditorKeyboardShortcutEventSignature
    }

    private static var lastDispatch: Dispatch?

    static func shouldDispatch(
        _ action: ImageEditorLayerMergeCommandAction,
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

enum ImageEditorLayerOrderCommandAction: Equatable {
    case top
    case up
    case down
    case bottom
}

@MainActor
enum ImageEditorLayerOrderCommandDispatchGate {
    private struct Dispatch: Equatable {
        let action: ImageEditorLayerOrderCommandAction
        let event: ImageEditorKeyboardShortcutEventSignature
    }

    private static var lastDispatch: Dispatch?

    static func shouldDispatch(
        _ action: ImageEditorLayerOrderCommandAction,
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

@MainActor
enum ImageEditorQuickMaskCommandDispatchGate {
    private static var lastEvent: ImageEditorKeyboardShortcutEventSignature?

    static func shouldDispatch(
        event: ImageEditorKeyboardShortcutEventSignature?
    ) -> Bool {
        guard let event else { return true }
        guard event != lastEvent else { return false }
        lastEvent = event
        return true
    }

    static func reset() {
        lastEvent = nil
    }
}

enum ImageEditorSelectionCommandAction: Equatable, CaseIterable {
    case selectAll
    case clear
    case reselect
    case invert
    case feather
}

@MainActor
enum ImageEditorSelectionCommandDispatchGate {
    private struct Dispatch: Equatable {
        let action: ImageEditorSelectionCommandAction
        let event: ImageEditorKeyboardShortcutEventSignature
    }

    private static var lastDispatch: Dispatch?

    static func shouldDispatch(
        _ action: ImageEditorSelectionCommandAction,
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

enum ImageEditorSelectionFillCommandAction: Equatable, CaseIterable {
    case dialog
    case foreground
    case foregroundPreservingTransparency
    case background
    case backgroundPreservingTransparency
    case history
    case historyPreservingTransparency
}

@MainActor
enum ImageEditorSelectionFillCommandDispatchGate {
    private struct Dispatch: Equatable {
        let action: ImageEditorSelectionFillCommandAction
        let event: ImageEditorKeyboardShortcutEventSignature
    }

    private static var lastDispatch: Dispatch?

    static func shouldDispatch(
        _ action: ImageEditorSelectionFillCommandAction,
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

enum ImageEditorImageGeometryCommandAction: Equatable, CaseIterable {
    case resizeImage
    case resizeCanvas
}

@MainActor
enum ImageEditorImageGeometryCommandDispatchGate {
    private struct Dispatch: Equatable {
        let action: ImageEditorImageGeometryCommandAction
        let event: ImageEditorKeyboardShortcutEventSignature
    }

    private static var lastDispatch: Dispatch?

    static func shouldDispatch(
        _ action: ImageEditorImageGeometryCommandAction,
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

enum ImageEditorPixelCorrectionCommandAction: Equatable, CaseIterable {
    case desaturate
    case invert
    case autoLevels
    case autoContrast
    case autoColor
}

@MainActor
enum ImageEditorPixelCorrectionCommandDispatchGate {
    private struct Dispatch: Equatable {
        let action: ImageEditorPixelCorrectionCommandAction
        let event: ImageEditorKeyboardShortcutEventSignature
    }

    private static var lastDispatch: Dispatch?

    static func shouldDispatch(
        _ action: ImageEditorPixelCorrectionCommandAction,
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

@MainActor
enum ImageEditorLastFilterCommandDispatchGate {
    private static var lastEvent: ImageEditorKeyboardShortcutEventSignature?

    static func shouldDispatch(
        event: ImageEditorKeyboardShortcutEventSignature?
    ) -> Bool {
        guard let event else { return true }
        guard event != lastEvent else { return false }
        lastEvent = event
        return true
    }

    static func reset() {
        lastEvent = nil
    }
}

enum ImageEditorCanvasAidCommandAction: Equatable {
    case rulers
    case guides
    case guideSnapping
    case guidesLocked
    case grid
}

enum ImageEditorZoomCommandAction: Equatable {
    case zoomIn
    case zoomOut
    case actualPixels
    case fitOnScreen
}

@MainActor
enum ImageEditorZoomCommandDispatchGate {
    private struct Dispatch: Equatable {
        let action: ImageEditorZoomCommandAction
        let event: ImageEditorKeyboardShortcutEventSignature
    }

    private static var lastDispatch: Dispatch?

    static func shouldDispatch(
        _ action: ImageEditorZoomCommandAction,
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

@MainActor
enum ImageEditorCanvasAidCommandDispatchGate {
    private struct Dispatch: Equatable {
        let action: ImageEditorCanvasAidCommandAction
        let event: ImageEditorKeyboardShortcutEventSignature
    }

    private static var lastDispatch: Dispatch?

    static func shouldDispatch(
        _ action: ImageEditorCanvasAidCommandAction,
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

enum ImageEditorPendingCropKeyPolicy {
    static func matchesConfirm(
        keyCode: UInt16,
        modifierFlags: NSEvent.ModifierFlags
    ) -> Bool {
        let relevantFlags = modifierFlags.intersection([.command, .option, .shift, .control])
        return (keyCode == 36 || keyCode == 76) && relevantFlags.isEmpty
    }

    static func matchesCancel(
        keyCode: UInt16,
        modifierFlags: NSEvent.ModifierFlags
    ) -> Bool {
        let relevantFlags = modifierFlags.intersection([.command, .option, .shift, .control])
        return keyCode == 53 && relevantFlags.isEmpty
    }
}

enum ImageEditorPendingCropCancelDispatcher {
    static func handle(
        cancelPendingCrop: () -> Bool,
        cancelFallback: () -> Bool
    ) -> Bool {
        if cancelPendingCrop() {
            return true
        }
        return cancelFallback()
    }
}

enum ImageEditorPendingCropNudgeDispatcher {
    static func perform(
        delta: CGSize,
        nudgePendingCrop: (CGSize) -> Bool,
        nudgeFallback: (CGSize) -> Void
    ) {
        if !nudgePendingCrop(delta) {
            nudgeFallback(delta)
        }
    }
}

enum ImageEditorPendingPenFinishKeyPolicy {
    static func matches(
        keyCode: UInt16,
        modifierFlags: NSEvent.ModifierFlags
    ) -> Bool {
        let relevantFlags = modifierFlags.intersection([.command, .option, .shift, .control])
        return (keyCode == 36 || keyCode == 76) && relevantFlags.isEmpty
    }
}

enum ImageEditorPendingPenPointerFinishPolicy {
    static func shouldFinishOpenPath(
        hasPendingPath: Bool,
        modifierFlags: NSEvent.ModifierFlags
    ) -> Bool {
        let relevantFlags = modifierFlags.intersection([.command, .option, .shift, .control])
        return hasPendingPath && relevantFlags == [.command]
    }
}

struct ImageEditorKeyboardShortcutMonitor: NSViewRepresentable {
    let perform: (ImageEditorKeyboardShortcutAction) -> Void
    let activeTool: ImageEditorTool
    let hasPendingCrop: Bool
    let canCycleCropGuide: Bool
    let canToggleQuickMaskGrayscalePreview: Bool
    let canToggleLayerMaskRubylith: Bool
    let nudgePendingCrop: (CGSize) -> Bool
    let nudgeSelected: (CGSize) -> Void
    let selectNextCanvasHandle: (Bool) -> Bool
    let moveSelectedCanvasHandleToBoundary: (Double) -> Bool
    let deleteSelectedObject: (ImageEditorKeyboardShortcutEventSignature?) -> Bool
    let confirmPendingCrop: () -> Bool
    let cancelPendingCrop: () -> Bool
    let finishPendingPenPath: () -> Bool
    let enterSelectedGroup: () -> Bool
    let cancelSelectedObject: () -> Bool
    let discardPendingSmartFilterChanges: () -> Bool
    let deleteSelectedHistory: () -> Bool
    let setSpacebarPanning: (Bool) -> Void
    let setCanvasModifierFlags: (NSEvent.ModifierFlags) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            perform: perform,
            activeTool: activeTool,
            hasPendingCrop: hasPendingCrop,
            canCycleCropGuide: canCycleCropGuide,
            canToggleQuickMaskGrayscalePreview: canToggleQuickMaskGrayscalePreview,
            canToggleLayerMaskRubylith: canToggleLayerMaskRubylith,
            nudgePendingCrop: nudgePendingCrop,
            nudgeSelected: nudgeSelected,
            selectNextCanvasHandle: selectNextCanvasHandle,
            moveSelectedCanvasHandleToBoundary: moveSelectedCanvasHandleToBoundary,
            deleteSelectedObject: deleteSelectedObject,
            confirmPendingCrop: confirmPendingCrop,
            cancelPendingCrop: cancelPendingCrop,
            finishPendingPenPath: finishPendingPenPath,
            enterSelectedGroup: enterSelectedGroup,
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
        context.coordinator.hasPendingCrop = hasPendingCrop
        context.coordinator.canCycleCropGuide = canCycleCropGuide
        context.coordinator.canToggleQuickMaskGrayscalePreview = canToggleQuickMaskGrayscalePreview
        context.coordinator.canToggleLayerMaskRubylith = canToggleLayerMaskRubylith
        context.coordinator.nudgePendingCrop = nudgePendingCrop
        context.coordinator.nudgeSelected = nudgeSelected
        context.coordinator.selectNextCanvasHandle = selectNextCanvasHandle
        context.coordinator.moveSelectedCanvasHandleToBoundary = moveSelectedCanvasHandleToBoundary
        context.coordinator.deleteSelectedObject = deleteSelectedObject
        context.coordinator.confirmPendingCrop = confirmPendingCrop
        context.coordinator.cancelPendingCrop = cancelPendingCrop
        context.coordinator.finishPendingPenPath = finishPendingPenPath
        context.coordinator.enterSelectedGroup = enterSelectedGroup
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
        var hasPendingCrop: Bool
        var canCycleCropGuide: Bool
        var canToggleQuickMaskGrayscalePreview: Bool
        var canToggleLayerMaskRubylith: Bool
        var nudgePendingCrop: (CGSize) -> Bool
        var nudgeSelected: (CGSize) -> Void
        var selectNextCanvasHandle: (Bool) -> Bool
        var moveSelectedCanvasHandleToBoundary: (Double) -> Bool
        var deleteSelectedObject: (ImageEditorKeyboardShortcutEventSignature?) -> Bool
        var confirmPendingCrop: () -> Bool
        var cancelPendingCrop: () -> Bool
        var finishPendingPenPath: () -> Bool
        var enterSelectedGroup: () -> Bool
        var cancelSelectedObject: () -> Bool
        var discardPendingSmartFilterChanges: () -> Bool
        var deleteSelectedHistory: () -> Bool
        var setSpacebarPanning: (Bool) -> Void
        var setCanvasModifierFlags: (NSEvent.ModifierFlags) -> Void
        private var eventMonitor: Any?
        private var appDeactivateObserver: Any?
        private var windowResignKeyObserver: Any?
        private var isSpacebarPanning = false

        init(
            perform: @escaping (ImageEditorKeyboardShortcutAction) -> Void,
            activeTool: ImageEditorTool,
            hasPendingCrop: Bool,
            canCycleCropGuide: Bool,
            canToggleQuickMaskGrayscalePreview: Bool,
            canToggleLayerMaskRubylith: Bool,
            nudgePendingCrop: @escaping (CGSize) -> Bool,
            nudgeSelected: @escaping (CGSize) -> Void,
            selectNextCanvasHandle: @escaping (Bool) -> Bool,
            moveSelectedCanvasHandleToBoundary: @escaping (Double) -> Bool,
            deleteSelectedObject: @escaping (ImageEditorKeyboardShortcutEventSignature?) -> Bool,
            confirmPendingCrop: @escaping () -> Bool,
            cancelPendingCrop: @escaping () -> Bool,
            finishPendingPenPath: @escaping () -> Bool,
            enterSelectedGroup: @escaping () -> Bool,
            cancelSelectedObject: @escaping () -> Bool,
            discardPendingSmartFilterChanges: @escaping () -> Bool,
            deleteSelectedHistory: @escaping () -> Bool,
            setSpacebarPanning: @escaping (Bool) -> Void,
            setCanvasModifierFlags: @escaping (NSEvent.ModifierFlags) -> Void
        ) {
            self.perform = perform
            self.activeTool = activeTool
            self.hasPendingCrop = hasPendingCrop
            self.canCycleCropGuide = canCycleCropGuide
            self.canToggleQuickMaskGrayscalePreview = canToggleQuickMaskGrayscalePreview
            self.canToggleLayerMaskRubylith = canToggleLayerMaskRubylith
            self.nudgePendingCrop = nudgePendingCrop
            self.nudgeSelected = nudgeSelected
            self.selectNextCanvasHandle = selectNextCanvasHandle
            self.moveSelectedCanvasHandleToBoundary = moveSelectedCanvasHandleToBoundary
            self.deleteSelectedObject = deleteSelectedObject
            self.confirmPendingCrop = confirmPendingCrop
            self.cancelPendingCrop = cancelPendingCrop
            self.finishPendingPenPath = finishPendingPenPath
            self.enterSelectedGroup = enterSelectedGroup
            self.cancelSelectedObject = cancelSelectedObject
            self.discardPendingSmartFilterChanges = discardPendingSmartFilterChanges
            self.deleteSelectedHistory = deleteSelectedHistory
            self.setSpacebarPanning = setSpacebarPanning
            self.setCanvasModifierFlags = setCanvasModifierFlags
            eventMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.keyDown, .keyUp, .flagsChanged]
            ) { [weak self] event in
                self?.handle(event) ?? event
            }
            appDeactivateObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didResignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.resetTransientKeyboardState()
            }
            windowResignKeyObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let self,
                      notification.object as? NSWindow === self.window else { return }
                self.resetTransientKeyboardState()
            }
        }

        deinit {
            if let eventMonitor {
                NSEvent.removeMonitor(eventMonitor)
            }
            if let appDeactivateObserver {
                NotificationCenter.default.removeObserver(appDeactivateObserver)
            }
            if let windowResignKeyObserver {
                NotificationCenter.default.removeObserver(windowResignKeyObserver)
            }
        }

        func attach(to newWindow: NSWindow?) {
            if window !== newWindow {
                resetTransientKeyboardState()
            }
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
                  ImageEditorKeyboardShortcutEventWindowPolicy.belongsToEditorWindow(
                    eventWindow: event.window,
                    eventWindowNumber: event.windowNumber,
                    editorWindow: window,
                    editorWindowNumber: window.windowNumber,
                    keyWindow: NSApp.keyWindow
                  ),
                  ImageEditorKeyboardShortcutWindowRegistry.isRegistered(
                      coordinator: self,
                      for: window
                  )
            else { return event }
            setCanvasModifierFlags(event.modifierFlags.intersection([.shift, .option, .capsLock]))
            let relevantFlags = event.modifierFlags.intersection([.command, .option, .shift, .control])
            if event.keyCode == 49, relevantFlags.isEmpty {
                if event.type == .keyUp, isSpacebarPanning {
                    resetTransientKeyboardState()
                    return nil
                }
                if event.type == .keyDown, !isTextInputActive {
                    isSpacebarPanning = true
                    setSpacebarPanning(true)
                    return nil
                }
            }
            let isDelete = ImageEditorDeleteKeyPolicy.matches(
                keyCode: event.keyCode,
                charactersIgnoringModifiers: event.charactersIgnoringModifiers,
                modifierFlags: event.modifierFlags
            )
            if event.type == .keyDown,
               ImageEditorGradientOverlayCanvasTabKeyPolicy.matches(
                keyCode: event.keyCode,
                modifierFlags: event.modifierFlags,
                isTextInputActive: isTextInputActive
               ),
               selectNextCanvasHandle(relevantFlags.contains(.shift)) {
                return nil
            }
            if event.type == .keyDown,
               let displayedDelta = ImageEditorGradientOverlayCanvasBoundaryKeyPolicy.displayedDelta(
                keyCode: event.keyCode,
                modifierFlags: event.modifierFlags,
                isTextInputActive: isTextInputActive
               ),
               moveSelectedCanvasHandleToBoundary(displayedDelta) {
                return nil
            }
            if event.type == .keyDown,
               ImageEditorPendingCropKeyPolicy.matchesCancel(
                   keyCode: event.keyCode,
                   modifierFlags: event.modifierFlags
               ),
               !isTextInputActive {
                if ImageEditorPendingCropCancelDispatcher.handle(
                    cancelPendingCrop: cancelPendingCrop,
                    cancelFallback: {
                        ImageEditorEscapeCancelDispatcher.handle(
                            cancelSelectedObject: cancelSelectedObject,
                            discardPendingSmartFilterChanges: discardPendingSmartFilterChanges
                        )
                    }
                ) {
                    return nil
                }
            }
            if event.type == .keyDown,
               !isTextInputActive,
               ImageEditorPendingCropKeyPolicy.matchesConfirm(
                   keyCode: event.keyCode,
                   modifierFlags: event.modifierFlags
               ),
               confirmPendingCrop() {
                return nil
            }
            if event.type == .keyDown,
               !isTextInputActive,
               ImageEditorPendingPenFinishKeyPolicy.matches(
                keyCode: event.keyCode,
                modifierFlags: event.modifierFlags
               ),
               finishPendingPenPath() {
                return nil
            }
            if event.type == .keyDown,
               ImageEditorMoveToolGroupEntryKeyPolicy.matches(
                keyCode: event.keyCode,
                modifierFlags: event.modifierFlags,
                isTextInputActive: isTextInputActive
               ),
               enterSelectedGroup() {
                return nil
            }
            if event.type == .keyDown,
               isDelete,
               relevantFlags.isEmpty,
               !isTextInputActive,
               performDeleteCommandFromKeyboardResponder(
                   event: ImageEditorKeyboardShortcutEventSignature(event: event)
               ) {
                return nil
            }

            if event.type == .keyDown,
               !isTextInputActive,
               let delta = ImageEditorArrowNudge.delta(
                   for: event.keyCode,
                   modifierFlags: event.modifierFlags
               ) {
                ImageEditorPendingCropNudgeDispatcher.perform(
                    delta: delta,
                    nudgePendingCrop: nudgePendingCrop,
                    nudgeFallback: nudgeSelected
                )
                return nil
            }

            if event.type == .keyDown,
               let action = ImageEditorKeyboardShortcutAction.resolve(
                charactersIgnoringModifiers: event.charactersIgnoringModifiers,
                modifierFlags: event.modifierFlags,
                keyCode: event.keyCode,
                activeTool: activeTool,
                hasPendingCrop: hasPendingCrop,
                canCycleCropGuide: canCycleCropGuide,
                canToggleQuickMaskGrayscalePreview: canToggleQuickMaskGrayscalePreview,
                canToggleLayerMaskRubylith: canToggleLayerMaskRubylith
            ) {
                if action.isBlockedByTextInput, isTextInputActive {
                    return event
                }
                perform(action)
                return nil
            }
            return event
        }

        @discardableResult
        func performDeleteCommandFromKeyboardResponder(
            event: ImageEditorKeyboardShortcutEventSignature?
        ) -> Bool {
            guard let window else {
                return performOwnDeleteCommandFromKeyboardResponder(event: event)
            }
            let handlers = ImageEditorKeyboardShortcutWindowRegistry
                .registeredCoordinatorsNewestFirst(for: window)
                .compactMap { $0 as? Coordinator }
                .map { candidate in
                    { event in
                        candidate.performOwnDeleteCommandFromKeyboardResponder(event: event)
                    }
                }
            return ImageEditorKeyboardDeleteWindowDispatcher.perform(
                event: event,
                handlersNewestFirst: handlers
            )
        }

        private func performOwnDeleteCommandFromKeyboardResponder(
            event: ImageEditorKeyboardShortcutEventSignature?
        ) -> Bool {
            ImageEditorKeyboardDeleteCommandDispatcher.perform(
                event: event,
                deleteSelectedObject: deleteSelectedObject,
                deleteSelectedHistory: deleteSelectedHistory
            )
        }

        private var isTextInputActive: Bool {
            window?.firstResponder is NSTextView || window?.firstResponder is NSTextField
        }

        private func resetTransientKeyboardState() {
            let decision = ImageEditorSpacebarPanResetPolicy.decision(
                isPanning: isSpacebarPanning
            )
            if decision.shouldStopSpacebarPanning {
                isSpacebarPanning = false
                setSpacebarPanning(false)
            }
            if decision.shouldClearCanvasModifierFlags {
                setCanvasModifierFlags([])
            }
        }
    }
}

enum ImageEditorKeyboardDeleteCommandDispatcher {
    static func perform(
        event: ImageEditorKeyboardShortcutEventSignature?,
        deleteSelectedObject: (ImageEditorKeyboardShortcutEventSignature?) -> Bool,
        deleteSelectedHistory: () -> Bool
    ) -> Bool {
        if deleteSelectedObject(event) {
            return true
        }
        return deleteSelectedHistory()
    }
}

enum ImageEditorKeyboardDeleteWindowDispatcher {
    static func perform(
        event: ImageEditorKeyboardShortcutEventSignature?,
        handlersNewestFirst: [(ImageEditorKeyboardShortcutEventSignature?) -> Bool]
    ) -> Bool {
        for handler in handlersNewestFirst where handler(event) {
            return true
        }
        return false
    }
}

enum ImageEditorKeyboardResponderDeleteDispatcher {
    static func performKeyEquivalent(
        event: NSEvent,
        isTextInputActive: Bool,
        deleteSelectedObject: (ImageEditorKeyboardShortcutEventSignature?) -> Bool
    ) -> Bool {
        performKeyEquivalent(
            keyCode: event.keyCode,
            charactersIgnoringModifiers: event.charactersIgnoringModifiers,
            modifierFlags: event.modifierFlags,
            eventSignature: ImageEditorKeyboardShortcutEventSignature(event: event),
            isTextInputActive: isTextInputActive,
            deleteSelectedObject: deleteSelectedObject
        )
    }

    static func performKeyEquivalent(
        keyCode: UInt16,
        charactersIgnoringModifiers: String?,
        modifierFlags: NSEvent.ModifierFlags,
        eventSignature: ImageEditorKeyboardShortcutEventSignature?,
        isTextInputActive: Bool,
        deleteSelectedObject: (ImageEditorKeyboardShortcutEventSignature?) -> Bool
    ) -> Bool {
        guard !isTextInputActive else { return false }
        return perform(
            keyCode: keyCode,
            charactersIgnoringModifiers: charactersIgnoringModifiers,
            modifierFlags: modifierFlags,
            eventSignature: eventSignature,
            deleteSelectedObject: deleteSelectedObject
        )
    }

    static func perform(
        event: NSEvent,
        deleteSelectedObject: (ImageEditorKeyboardShortcutEventSignature?) -> Bool
    ) -> Bool {
        perform(
            keyCode: event.keyCode,
            charactersIgnoringModifiers: event.charactersIgnoringModifiers,
            modifierFlags: event.modifierFlags,
            eventSignature: ImageEditorKeyboardShortcutEventSignature(event: event),
            deleteSelectedObject: deleteSelectedObject
        )
    }

    static func perform(
        keyCode: UInt16,
        charactersIgnoringModifiers: String?,
        modifierFlags: NSEvent.ModifierFlags,
        eventSignature: ImageEditorKeyboardShortcutEventSignature?,
        deleteSelectedObject: (ImageEditorKeyboardShortcutEventSignature?) -> Bool
    ) -> Bool {
        guard ImageEditorDeleteKeyPolicy.matches(
            keyCode: keyCode,
            charactersIgnoringModifiers: charactersIgnoringModifiers,
            modifierFlags: modifierFlags
        ) else { return false }
        return deleteSelectedObject(eventSignature)
    }
}

enum ImageEditorDeleteKeyPolicy {
    private static let backwardDeleteKeyCode: UInt16 = 51
    private static let forwardDeleteKeyCode: UInt16 = 117
    private static let backwardDeleteCharacters: Set<String> = ["\u{7F}", "\u{8}"]
    private static let forwardDeleteCharacter = "\u{F728}"

    static func matches(
        keyCode: UInt16,
        charactersIgnoringModifiers: String?,
        modifierFlags: NSEvent.ModifierFlags
    ) -> Bool {
        let relevantFlags = modifierFlags.intersection([.command, .option, .shift, .control])
        guard relevantFlags.isEmpty else { return false }
        if keyCode == backwardDeleteKeyCode || keyCode == forwardDeleteKeyCode {
            return true
        }
        guard let charactersIgnoringModifiers else { return false }
        return backwardDeleteCharacters.contains(charactersIgnoringModifiers)
            || charactersIgnoringModifiers == forwardDeleteCharacter
    }
}

class ImageEditorKeyboardShortcutResponderNSView: NSView {
    override var acceptsFirstResponder: Bool { true }
}

final class KeyboardShortcutMonitorNSView: ImageEditorKeyboardShortcutResponderNSView {
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

    override func keyDown(with event: NSEvent) {
        if ImageEditorKeyboardResponderDeleteDispatcher.perform(
            event: event,
            deleteSelectedObject: { event in
                coordinator?.performDeleteCommandFromKeyboardResponder(event: event) == true
            }
        ) {
            return
        }
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let isTextInputActive = window?.firstResponder is NSTextView
            || window?.firstResponder is NSTextField
        if ImageEditorKeyboardResponderDeleteDispatcher.performKeyEquivalent(
            event: event,
            isTextInputActive: isTextInputActive,
            deleteSelectedObject: { event in
                coordinator?.performDeleteCommandFromKeyboardResponder(event: event) == true
            }
        ) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func deleteBackward(_ sender: Any?) {
        guard coordinator?.performDeleteCommandFromKeyboardResponder(
            event: .currentKeyEvent
        ) != true else { return }
        super.deleteBackward(sender)
    }

    override func deleteForward(_ sender: Any?) {
        guard coordinator?.performDeleteCommandFromKeyboardResponder(
            event: .currentKeyEvent
        ) != true else { return }
        super.deleteForward(sender)
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
        nsView.prepareForDismantling()
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

    func prepareForDismantling() {
        activationHandler = nil
        marqueeMenuHandler = nil
        onHoverChanged = nil
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
            self.hoverTrackingArea = nil
        }
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
