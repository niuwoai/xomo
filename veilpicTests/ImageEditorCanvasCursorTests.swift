import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorCanvasCursorTests {
    @Test func cursorRectOnlyTreatsTheRenderedImageAsDrawableCanvas() {
        let imageRect = CGRect(x: 120, y: 80, width: 720, height: 450)

        #expect(ImageEditorCanvasCursor.isPointerOverDrawableCanvas(nil, imageRect: imageRect) == false)
        #expect(ImageEditorCanvasCursor.isPointerOverDrawableCanvas(CGPoint(x: 120, y: 80), imageRect: imageRect))
        #expect(ImageEditorCanvasCursor.isPointerOverDrawableCanvas(CGPoint(x: 839.99, y: 529.99), imageRect: imageRect))
        #expect(ImageEditorCanvasCursor.isPointerOverDrawableCanvas(CGPoint(x: 100, y: 200), imageRect: imageRect) == false)
        #expect(ImageEditorCanvasCursor.isPointerOverDrawableCanvas(CGPoint(x: 900, y: 600), imageRect: imageRect) == false)
    }

    @Test func interactionModeSeparatesComponentLibraryFromToolsAndPan() {
        #expect(
            ImageEditorCanvasCursor.interactionMode(
                for: .components,
                selectedTool: .brush,
                isSpacebarPanning: false,
                isCanvasPanGestureActive: false
            ) == .componentLibrary
        )
        #expect(
            ImageEditorCanvasCursor.interactionMode(
                for: .tools,
                selectedTool: .brush,
                isSpacebarPanning: false,
                isCanvasPanGestureActive: false
            ) == .tool(.brush)
        )
        #expect(
            ImageEditorCanvasCursor.interactionMode(
                for: .components,
                selectedTool: .brush,
                isSpacebarPanning: true,
                isCanvasPanGestureActive: false
            ) == .pan
        )
    }

    @Test func componentLibraryUsesSystemArrowUntilDragOrCanvasPanBegins() {
        #expect(
            ImageEditorCanvasCursor.tool(
                for: .components,
                selectedTool: .brush,
                isSpacebarPanning: false,
                isCanvasPanGestureActive: false
            ) == .move
        )
        #expect(
            ImageEditorCanvasCursor.cursor(for: .move, brushDiameter: 18) === NSCursor.arrow
        )
        #expect(
            ImageEditorCanvasCursor.tool(
                for: .components,
                selectedTool: .brush,
                isSpacebarPanning: true,
                isCanvasPanGestureActive: false
            ) == .hand
        )

        #expect(
            ImageEditorCanvasCursor.cursor(
                for: .components,
                selectedTool: .brush,
                brushDiameter: 18,
                isPointerOverMovableContent: true
            ) === NSCursor.arrow
        )
        #expect(
            ImageEditorCanvasCursor.cursor(
                for: .components,
                selectedTool: .brush,
                brushDiameter: 18,
                isPointerOverMovableContent: false
            ) === NSCursor.arrow
        )
        #expect(
            ImageEditorCanvasCursor.cursor(
                for: .components,
                selectedTool: .brush,
                brushDiameter: 18,
                isSpacebarPanning: true
            ) === NSCursor.openHand
        )
        #expect(
            ImageEditorCanvasCursor.cursor(
                for: .components,
                selectedTool: .brush,
                brushDiameter: 18,
                handIsDragging: true,
                isCanvasPanGestureActive: true
            ) === NSCursor.closedHand
        )
    }

    @Test func pressureCursorDiameterTracksBrushFamiliesAndKeepsComponentArrow() {
        let baseDiameter: CGFloat = 40
        let pressure: CGFloat = 0.25
        let expectedBrushDiameter = baseDiameter * ImageEditorBrushStrokeKernel.mappedPressure(
            pressure,
            sensitivity: 0.5
        )
        let brushDiameter = ImageEditorCanvasCursor.pressureAdjustedBrushDiameter(
            baseDiameter: baseDiameter,
            tool: .brush,
            pressure: pressure,
            brushPressureControlsSize: true,
            retouchPressureControlsSize: false,
            brushPressureSensitivity: 0.5,
            retouchPressureSensitivity: 0.5
        )
        #expect(abs(brushDiameter - expectedBrushDiameter) < 0.001)

        let minimumDiameter = ImageEditorCanvasCursor.pressureAdjustedBrushDiameter(
            baseDiameter: baseDiameter,
            tool: .brush,
            pressure: 0,
            brushPressureControlsSize: true,
            retouchPressureControlsSize: false,
            brushPressureSensitivity: 0.5,
            brushMinimumDiameter: 0.5,
            retouchPressureSensitivity: 0.5
        )
        #expect(minimumDiameter == baseDiameter * 0.5)

        let retouchTools: [ImageEditorTool] = [
            .cloneStamp, .dodge, .burn, .sponge,
            .blur, .sharpen, .smudge, .healingBrush
        ]
        for tool in retouchTools {
            let diameter = ImageEditorCanvasCursor.pressureAdjustedBrushDiameter(
                baseDiameter: baseDiameter,
                tool: tool,
                pressure: pressure,
                brushPressureControlsSize: false,
                retouchPressureControlsSize: true,
                brushPressureSensitivity: 0.5,
                retouchPressureSensitivity: 0.8
            )
            let expected = baseDiameter * ImageEditorBrushStrokeKernel.mappedPressure(
                pressure,
                sensitivity: 0.8
            )
            #expect(abs(diameter - expected) < 0.001)
        }

        #expect(ImageEditorCanvasCursor.pressureAdjustedBrushDiameter(
            baseDiameter: baseDiameter,
            tool: .brush,
            pressure: pressure,
            brushPressureControlsSize: false,
            retouchPressureControlsSize: true,
            brushPressureSensitivity: 0.5,
            retouchPressureSensitivity: 0.5
        ) == baseDiameter)
        #expect(ImageEditorCanvasCursor.pressureAdjustedBrushDiameter(
            baseDiameter: baseDiameter,
            tool: .brush,
            pressure: nil,
            brushPressureControlsSize: true,
            retouchPressureControlsSize: true,
            brushPressureSensitivity: 0.5,
            retouchPressureSensitivity: 0.5
        ) == baseDiameter)
        #expect(ImageEditorCanvasCursor.pressureAdjustedBrushDiameter(
            baseDiameter: baseDiameter,
            tool: .move,
            pressure: pressure,
            brushPressureControlsSize: true,
            retouchPressureControlsSize: true,
            brushPressureSensitivity: 0.5,
            retouchPressureSensitivity: 0.5
        ) == baseDiameter)

        let tinyDiameter = ImageEditorCanvasCursor.pressureAdjustedBrushDiameter(
            baseDiameter: 2,
            tool: .eraser,
            pressure: 0,
            brushPressureControlsSize: true,
            retouchPressureControlsSize: false,
            brushPressureSensitivity: 0.5,
            retouchPressureSensitivity: 0.5
        )
        #expect(tinyDiameter == 1)
        #expect(ImageEditorCanvasCursor.cursor(
            for: .components,
            selectedTool: .brush,
            brushDiameter: brushDiameter
        ) === NSCursor.arrow)
    }

    @Test func tiltCursorFootprintMatchesTheRenderedBrushTipAndKeepsMouseCircular() {
        let horizontal = ImageEditorBrushCursorFootprint(
            diameter: 80,
            tilt: ImageEditorStylusTilt(x: 1, y: 0),
            tiltControlsShape: true
        )
        #expect(horizontal.majorDiameter == 80)
        #expect(horizontal.minorDiameter == 20)
        #expect(horizontal.aspectRatio == 0.25)
        #expect(horizontal.rotationDegrees == 0)

        let vertical = ImageEditorBrushCursorFootprint(
            diameter: 80,
            tilt: ImageEditorStylusTilt(x: 0, y: 1),
            tiltControlsShape: true
        )
        #expect(vertical.majorDiameter == 80)
        #expect(vertical.minorDiameter == 20)
        #expect(vertical.rotationDegrees == 90)

        let diagonal = ImageEditorBrushCursorFootprint(
            diameter: 80,
            tilt: ImageEditorStylusTilt(x: 0.5, y: 0.5),
            tiltControlsShape: true
        )
        #expect(diagonal.rotationDegrees == 45)
        #expect(diagonal.aspectRatio == 0.47)

        let mouse = ImageEditorBrushCursorFootprint(
            diameter: 80,
            tilt: nil,
            tiltControlsShape: true
        )
        let disabled = ImageEditorBrushCursorFootprint(
            diameter: 80,
            tilt: ImageEditorStylusTilt(x: 1, y: 0),
            tiltControlsShape: false
        )
        let perpendicular = ImageEditorBrushCursorFootprint(
            diameter: 80,
            tilt: ImageEditorStylusTilt(x: 0, y: 0),
            tiltControlsShape: true
        )
        for circular in [mouse, disabled, perpendicular] {
            #expect(circular.majorDiameter == 80)
            #expect(circular.minorDiameter == 80)
            #expect(circular.aspectRatio == 1)
            #expect(circular.rotationDegrees == 0)
        }
    }

    @Test func tiltChangesOnlyBrushAndEraserFootprintCursors() {
        let tilt = ImageEditorStylusTilt(x: 1, y: 0)
        let roundBrush = ImageEditorCanvasCursor.cursor(
            for: .brush,
            brushDiameter: 80
        )
        let disabledBrush = ImageEditorCanvasCursor.cursor(
            for: .brush,
            brushDiameter: 80,
            brushTilt: tilt,
            brushTiltControlsShape: false
        )
        let tiltedBrush = ImageEditorCanvasCursor.cursor(
            for: .brush,
            brushDiameter: 80,
            brushTilt: tilt,
            brushTiltControlsShape: true
        )
        let tiltedEraser = ImageEditorCanvasCursor.cursor(
            for: .eraser,
            brushDiameter: 80,
            brushTilt: tilt,
            brushTiltControlsShape: true
        )
        let roundClone = ImageEditorCanvasCursor.cursor(
            for: .cloneStamp,
            brushDiameter: 80
        )
        let tiltedClone = ImageEditorCanvasCursor.cursor(
            for: .cloneStamp,
            brushDiameter: 80,
            brushTilt: tilt,
            brushTiltControlsShape: true
        )

        #expect(roundBrush === disabledBrush)
        #expect(tiltedBrush !== roundBrush)
        #expect(tiltedEraser === tiltedBrush)
        #expect(tiltedClone === roundClone)
        #expect(tiltedBrush.image.tiffRepresentation != roundBrush.image.tiffRepresentation)
        #expect(ImageEditorCanvasCursor.cursor(
            for: .brush,
            brushDiameter: 80,
            brushTilt: tilt,
            brushTiltControlsShape: true,
            modifierFlags: [.capsLock]
        ) === NSCursor.crosshair)
        #expect(ImageEditorCanvasCursor.cursor(
            for: .components,
            selectedTool: .brush,
            brushDiameter: 80,
            brushTilt: tilt,
            brushTiltControlsShape: true
        ) === NSCursor.arrow)
    }

    @Test func manualRoundnessAndAngleUpdateBrushAndEraserWhileTiltTakesPriority() {
        let flatFootprint = ImageEditorBrushCursorFootprint(
            diameter: 80,
            tilt: nil,
            tiltControlsShape: false,
            tipRoundness: 0.25,
            tipAngleDegrees: 90
        )
        #expect(flatFootprint.majorDiameter == 80)
        #expect(flatFootprint.minorDiameter == 20)
        #expect(flatFootprint.aspectRatio == 0.25)
        #expect(flatFootprint.rotationDegrees == 90)

        let roundBrush = ImageEditorCanvasCursor.cursor(
            for: .brush,
            brushDiameter: 80
        )
        let flatBrush = ImageEditorCanvasCursor.cursor(
            for: .brush,
            brushDiameter: 80,
            brushTipRoundness: 0.25,
            brushTipAngleDegrees: 90
        )
        let flatEraser = ImageEditorCanvasCursor.cursor(
            for: .eraser,
            brushDiameter: 80,
            brushTipRoundness: 0.25,
            brushTipAngleDegrees: 90
        )
        let horizontalFlatBrush = ImageEditorCanvasCursor.cursor(
            for: .brush,
            brushDiameter: 80,
            brushTipRoundness: 0.25
        )
        let tiltOverridesManualAngle = ImageEditorCanvasCursor.cursor(
            for: .brush,
            brushDiameter: 80,
            brushTilt: ImageEditorStylusTilt(x: 1, y: 0),
            brushTiltControlsShape: true,
            brushTipRoundness: 0.25,
            brushTipAngleDegrees: 90
        )
        let cloneStamp = ImageEditorCanvasCursor.cursor(
            for: .cloneStamp,
            brushDiameter: 80,
            brushTipRoundness: 0.25
        )

        #expect(flatBrush !== roundBrush)
        #expect(flatEraser === flatBrush)
        #expect(horizontalFlatBrush !== flatBrush)
        #expect(tiltOverridesManualAngle === horizontalFlatBrush)
        #expect(cloneStamp !== flatBrush)
        #expect(flatBrush.image.tiffRepresentation != roundBrush.image.tiffRepresentation)
        #expect(ImageEditorCanvasCursor.cursor(
            for: .components,
            selectedTool: .brush,
            brushDiameter: 80,
            brushTipRoundness: 0.25
        ) === NSCursor.arrow)
    }

    @Test func draggingAnObjectKeepsMoveCursorAcrossSidebarModes() {
        let componentDrag = ImageEditorCanvasCursor.cursor(
            for: .components,
            selectedTool: .brush,
            brushDiameter: 18,
            isObjectMoveGestureActive: true
        )
        let moveToolDrag = ImageEditorCanvasCursor.cursor(
            for: .tools,
            selectedTool: .move,
            brushDiameter: 18,
            isObjectMoveGestureActive: true
        )

        #expect(componentDrag === ImageEditorCanvasCursor.objectMoveCursor())
        #expect(moveToolDrag === ImageEditorCanvasCursor.objectMoveCursor())
        #expect(componentDrag !== NSCursor.closedHand)
    }

    @Test func componentLibraryUsesArrowExceptForAnActualTransformControl() {
        let ordinary = ImageEditorCanvasCursor.cursor(
            for: .components,
            selectedTool: .brush,
            brushDiameter: 72,
            isPointerOverMovableContent: true
        )
        let resize = ImageEditorCanvasCursor.cursor(
            for: .components,
            selectedTool: .brush,
            brushDiameter: 72,
            isPointerOverMovableContent: true,
            layerTransformTarget: .resize(.right)
        )
        let rotate = ImageEditorCanvasCursor.cursor(
            for: .components,
            selectedTool: .brush,
            brushDiameter: 72,
            layerTransformTarget: .rotate
        )

        #expect(ordinary === NSCursor.arrow)
        #expect(resize === NSCursor.resizeLeftRight)
        #expect(rotate !== NSCursor.arrow)
        #expect(rotate !== NSCursor.crosshair)
    }

    @Test func transformCursorHitTestingMatchesVisibleControlRules() {
        #expect(ImageEditorLayerTransformControlLayout.showsControls(
            areExtrasVisible: true,
            areTransformControlsVisible: true,
            hasSelectedXomoObject: false
        ))
        #expect(!ImageEditorLayerTransformControlLayout.showsControls(
            areExtrasVisible: false,
            areTransformControlsVisible: true,
            hasSelectedXomoObject: false
        ))
        #expect(ImageEditorLayerTransformControlLayout.showsControls(
            areExtrasVisible: false,
            areTransformControlsVisible: true,
            hasSelectedXomoObject: true
        ))
        #expect(!ImageEditorLayerTransformControlLayout.showsControls(
            areExtrasVisible: true,
            areTransformControlsVisible: false,
            hasSelectedXomoObject: true
        ))
    }

    @Test func componentLibraryNeverLeaksAnyPreviousToolOrHoverCursor() {
        let staleModifiers: NSEvent.ModifierFlags = [.command, .option, .shift, .control, .capsLock]

        for tool in ImageEditorTool.allCases {
            #expect(
                ImageEditorCanvasCursor.cursor(
                    for: .components,
                    selectedTool: tool,
                    brushDiameter: 96,
                    isPointerOverMovableContent: true,
                    isPointerOverBlockedContent: true,
                    modifierFlags: staleModifiers
                ) === NSCursor.arrow
            )
        }

        #expect(
            ImageEditorCanvasCursor.cursor(
                for: .components,
                selectedTool: .brush,
                brushDiameter: 96,
                isPointerOverCanvas: false,
                modifierFlags: staleModifiers
            ) === NSCursor.arrow
        )
    }

    @Test func toolCursorFallsBackToSystemArrowOutsideDrawableCanvas() {
        let outside = ImageEditorCanvasCursor.cursor(
            for: .tools,
            selectedTool: .brush,
            brushDiameter: 48,
            isPointerOverCanvas: false
        )
        #expect(outside === NSCursor.arrow)

        let panning = ImageEditorCanvasCursor.cursor(
            for: .tools,
            selectedTool: .brush,
            brushDiameter: 48,
            isPointerOverCanvas: false,
            handIsDragging: true,
            isCanvasPanGestureActive: true
        )
        #expect(panning === NSCursor.closedHand)
    }

    @Test func toolsTabPreservesSelectedToolCursorAndPanOverride() {
        #expect(
            ImageEditorCanvasCursor.tool(
                for: .tools,
                selectedTool: .brush,
                isSpacebarPanning: false,
                isCanvasPanGestureActive: false
            ) == .brush
        )
        #expect(
            ImageEditorCanvasCursor.tool(
                for: .tools,
                selectedTool: .zoom,
                isSpacebarPanning: false,
                isCanvasPanGestureActive: true
            ) == .hand
        )
        let move = ImageEditorCanvasCursor.cursor(
            for: .tools,
            selectedTool: .move,
            brushDiameter: 18
        )
        #expect(move === NSCursor.arrow)
        #expect(ImageEditorCanvasCursor.family(for: .move) == .moveTool)

        let emptyCanvasMove = ImageEditorCanvasCursor.cursor(
            for: .tools,
            selectedTool: .move,
            brushDiameter: 18,
            isPointerOverMovableContent: false
        )
        #expect(emptyCanvasMove === NSCursor.openHand)

        let blockedContentMove = ImageEditorCanvasCursor.cursor(
            for: .tools,
            selectedTool: .move,
            brushDiameter: 18,
            isPointerOverMovableContent: false,
            isPointerOverBlockedContent: true
        )
        #expect(blockedContentMove === NSCursor.operationNotAllowed)
    }

    @Test func moveCursorHitTestUsesComponentGeometryWithoutChangingSelection() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "cursor-hit-test",
            image: NSImage.transparent(size: CGSize(width: 640, height: 480))
        ) { _ in }
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        let frame = try #require(viewModel.selectedXomoObjectFrame)

        #expect(viewModel.hasMovableCanvasContent(at: CGPoint(x: frame.midX, y: frame.midY)))
        #expect(!viewModel.hasMovableCanvasContent(at: CGPoint(x: 620, y: 460)))
        #expect(viewModel.document.selectedLayer?.xomoComponentInstance != nil)
    }

    @Test func moveCursorDoesNotClaimOccludedOrPositionLockedContent() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "cursor-lock-hit-test",
            image: NSImage.transparent(size: CGSize(width: 640, height: 480))
        ) { _ in }
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        let groupID = try #require(viewModel.document.selectedLayerID)
        let frame = try #require(viewModel.selectedXomoObjectFrame)
        let center = CGPoint(x: frame.midX, y: frame.midY)

        viewModel.document.layers = viewModel.document.layers.map { layer in
            guard layer.id == groupID else { return layer }
            var locked = layer
            locked.locksPosition = true
            return locked
        }
        #expect(!viewModel.hasMovableCanvasContent(at: center))
        #expect(viewModel.hasBlockedCanvasContent(at: center))

        viewModel.document.layers = viewModel.document.layers.map { layer in
            guard layer.id == groupID else { return layer }
            var unlocked = layer
            unlocked.locksPosition = false
            return unlocked
        }
        var cover = ImageEditorLayer.solidColorFill(
            name: "Cursor cover",
            size: CGSize(width: 240, height: 80),
            content: ImageEditorSolidColorFillContent(red: 0.2, green: 0.2, blue: 0.2)
        )
        cover.frame = CGRect(x: 80, y: 90, width: 240, height: 80)
        cover.locksPosition = true
        viewModel.document.layers.append(cover)
        #expect(!viewModel.hasMovableCanvasContent(at: center))
        #expect(viewModel.hasBlockedCanvasContent(at: center))
    }

    @Test func moveCursorUsesTheFrontmostLockedLayerOverAnUnlockedLayer() {
        let viewModel = ImageEditorViewModel(
            sourceName: "cursor-frontmost-lock-hit-test",
            image: NSImage.transparent(size: CGSize(width: 640, height: 480))
        ) { _ in }

        var unlockedBottom = ImageEditorLayer.solidColorFill(
            name: "Unlocked bottom",
            size: CGSize(width: 180, height: 90),
            content: ImageEditorSolidColorFillContent(red: 0.2, green: 0.4, blue: 0.8)
        )
        unlockedBottom.frame = CGRect(x: 120, y: 140, width: 180, height: 90)

        var lockedTop = ImageEditorLayer.solidColorFill(
            name: "Locked top",
            size: CGSize(width: 180, height: 90),
            content: ImageEditorSolidColorFillContent(red: 0.8, green: 0.3, blue: 0.2)
        )
        lockedTop.frame = unlockedBottom.frame
        lockedTop.locksPosition = true
        viewModel.document.layers = [unlockedBottom, lockedTop]

        let center = CGPoint(x: lockedTop.frame.midX, y: lockedTop.frame.midY)
        #expect(!viewModel.hasMovableCanvasContent(at: center))
        #expect(viewModel.hasBlockedCanvasContent(at: center))
    }

    @Test func canvasContentHitSharesTheSameSemanticForCursorPaths() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "cursor-shared-hit-test",
            image: NSImage.transparent(size: CGSize(width: 640, height: 480))
        ) { _ in }
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        let frame = try #require(viewModel.selectedXomoObjectFrame)

        #expect(viewModel.canvasContentHit(at: CGPoint(x: frame.midX, y: frame.midY)) == .movable)
        #expect(viewModel.canvasContentHit(at: CGPoint(x: 620, y: 460)) == .none)

        let groupID = try #require(viewModel.document.selectedLayerID)
        viewModel.document.layers = viewModel.document.layers.map { layer in
            guard layer.id == groupID else { return layer }
            var locked = layer
            locked.locksPosition = true
            return locked
        }
        #expect(viewModel.canvasContentHit(at: CGPoint(x: frame.midX, y: frame.midY)) == .blocked)
    }

    @Test func objectDragReleaseKeepsTheLocallyOwnedEventStreamBalanced() {
        let activeMove = ImageEditorObjectDragEventPolicy.releaseDecision(
            eventType: .leftMouseUp,
            hasObjectMoveCandidate: true,
            isObjectMoving: true
        )
        #expect(activeMove.shouldFinishMove)
        #expect(activeMove.shouldConsumeEvent)

        let candidateOnly = ImageEditorObjectDragEventPolicy.releaseDecision(
            eventType: .leftMouseUp,
            hasObjectMoveCandidate: true,
            isObjectMoving: false
        )
        #expect(!candidateOnly.shouldFinishMove)
        #expect(candidateOnly.shouldConsumeEvent)

        let unrelatedDrag = ImageEditorObjectDragEventPolicy.releaseDecision(
            eventType: .leftMouseDragged,
            hasObjectMoveCandidate: true,
            isObjectMoving: true
        )
        #expect(!unrelatedDrag.shouldFinishMove)
        #expect(!unrelatedDrag.shouldConsumeEvent)
    }

    @Test func objectDragStartsOnlyAfterThePointerLeavesClickTolerance() {
        let start = CGPoint(x: 120, y: 90)

        #expect(
            ImageEditorObjectDragEventPolicy.shouldActivate(
                from: start,
                to: CGPoint(x: 122, y: 92)
            ) == false
        )
        #expect(
            ImageEditorObjectDragEventPolicy.shouldActivate(
                from: start,
                to: CGPoint(x: 123, y: 90)
            )
        )
        #expect(
            ImageEditorObjectDragEventPolicy.shouldActivate(
                from: start,
                to: CGPoint(x: 120, y: 86)
            )
        )
    }

    @Test func shiftCanBeginAConstrainedDragWhileReservedModifiersAndHandlesWin() {
        #expect(
            ImageEditorObjectDragEventPolicy.allowsCandidate(
                modifierFlags: [],
                hasTransformTarget: false
            )
        )
        #expect(
            !ImageEditorObjectDragEventPolicy.allowsCandidate(
                modifierFlags: [],
                hasTransformTarget: true
            )
        )
        #expect(
            ImageEditorObjectDragEventPolicy.allowsCandidate(
                modifierFlags: [.shift],
                hasTransformTarget: false
            )
        )
        for modifier: NSEvent.ModifierFlags in [.command, .option, .control] {
            #expect(
                !ImageEditorObjectDragEventPolicy.allowsCandidate(
                    modifierFlags: modifier,
                    hasTransformTarget: false
                )
            )
        }
    }

    @Test func optionCloneDragAcceptsShiftConstraintButRejectsConflictingModifiers() {
        #expect(ImageEditorObjectDragEventPolicy.allowsCloneDrag(modifierFlags: [.option]))
        #expect(ImageEditorObjectDragEventPolicy.allowsCloneDrag(
            modifierFlags: [.option, .shift]
        ))
        #expect(!ImageEditorObjectDragEventPolicy.allowsCloneDrag(modifierFlags: [.shift]))
        #expect(!ImageEditorObjectDragEventPolicy.allowsCloneDrag(
            modifierFlags: [.option, .command]
        ))
        #expect(!ImageEditorObjectDragEventPolicy.allowsCloneDrag(
            modifierFlags: [.option, .control]
        ))
    }

    @Test func primaryDrawingToolsUseBalancedAppKitPointerCaptureOnlyInToolsMode() {
        for tool in [ImageEditorTool.brush, .eraser, .rectangle, .ellipse, .text] {
            #expect(
                ImageEditorPrimaryToolPointerCapture.shouldCapture(
                    sidebarTab: .tools,
                    tool: tool
                )
            )
            #expect(
                !ImageEditorPrimaryToolPointerCapture.shouldCapture(
                    sidebarTab: .components,
                    tool: tool
                )
            )
        }

        for tool in [ImageEditorTool.move, .marquee, .gradient, .hand, .zoom] {
            #expect(
                !ImageEditorPrimaryToolPointerCapture.shouldCapture(
                    sidebarTab: .tools,
                    tool: tool
                )
            )
        }

        for tool in [ImageEditorTool.brush, .eraser, .rectangle, .ellipse, .text, .marquee, .gradient] {
            #expect(
                ImageEditorPrimaryToolPointerCapture.usesDirectCanvasHitTarget(
                    sidebarTab: .tools,
                    tool: tool
                )
            )
            #expect(
                !ImageEditorPrimaryToolPointerCapture.usesDirectCanvasHitTarget(
                    sidebarTab: .components,
                    tool: tool
                )
            )
        }
        for tool in [
            ImageEditorTool.move,
            .hand,
            .zoom,
        ] {
            #expect(
                !ImageEditorPrimaryToolPointerCapture.usesDirectCanvasHitTarget(
                    sidebarTab: .tools,
                    tool: tool
                )
            )
        }
    }

    @Test func brushCommitKeepsAStartAndEndFallbackWhenDragUpdatesAreCoalesced() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let monitorSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorScrollZoom.swift"),
            encoding: .utf8
        )
        let pressureSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorBrushPressure.swift"),
            encoding: .utf8
        )

        #expect(viewSource.contains("let fallbackBrushSamples = ["))
        #expect(viewSource.contains("brushStrokeSamples.count >= 2"))
        #expect(viewSource.contains("viewModel.drawBrush(samples: committedBrushSamples)"))
        #expect(viewSource.contains(".allowsHitTesting("))
        #expect(viewSource.contains("ImageEditorPrimaryToolPointerCapture.usesDirectCanvasHitTarget("))
        #expect(
            monitorSource.contains(
                "var samples: [ImageEditorPrimaryPointerSample]"
            )
        )
        #expect(monitorSource.contains("transaction.onPrimaryEnded?(location, transaction.samples)"))
        #expect(monitorSource.contains("ImageEditorStylusInput.sample(from: event)"))
        #expect(monitorSource.contains("private static var canvasPointerMonitor: Any?"))
        #expect(monitorSource.contains("guard let host = currentPointerHost else { return event }"))
        #expect(viewSource.contains("if event.type == .keyDown,\n               isDelete,"))
        #expect(viewSource.contains("if event.type == .keyDown,\n               let action = ImageEditorKeyboardShortcutAction.resolve("))
        #expect(!pressureSource.contains("event.stage"))
        #expect(monitorSource.contains("onLayerResizeBegan?(location) == true"))
        #expect(monitorSource.contains("pointerCaptureState.isLayerResizing = true"))
        #expect(monitorSource.contains("onLayerResizeChanged?(location)"))
        #expect(monitorSource.contains("onLayerResizeEnded?(location)"))
        #expect(viewSource.contains("onLayerResizeBegan: { location in"))
        #expect(
            viewSource.contains(
                "viewModel.beginResizingSelectedLayer(handle: handle.transformModelHandle)"
            )
        )
        #expect(viewSource.contains("handle: handle.transformModelHandle,"))
        #expect(viewSource.contains("viewModel.finishResizingSelectedLayer()"))
    }

    @Test func pointerDownRefreshesTheSemanticCursorBeforeCaptureArbitration() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorScrollZoom.swift"),
            encoding: .utf8
        )
        let downStart = try #require(source.range(of: "case .down:\n"))
        let primaryCapture = try #require(
            source[downStart.upperBound...].range(
                of: "let primaryAccepted = onPrimaryToolDragBegan?(location) == true"
            )
        )
        let downPrefix = source[downStart.lowerBound..<primaryCapture.lowerBound]

        #expect(downPrefix.contains("guard bounds.contains(location)"))
        #expect(downPrefix.contains(
            "onMouseMoved?(location, ImageEditorStylusInput.sample(from: event))"
        ))
    }

    @Test func canvasMoveGestureYieldsToTransformHandles() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(viewSource.contains("layerTransformCursorTarget("))
        #expect(viewSource.contains("at: value.startLocation"))
        #expect(viewSource.contains("The parent canvas gesture is simultaneous"))
    }

    @Test func commandJUsesOnlyTheWindowShortcutMonitor() throws {
        #expect(
            ImageEditorKeyboardShortcutAction.resolve(
                charactersIgnoringModifiers: "j",
                modifierFlags: [.command]
            ) == .duplicateSelectionOrLayer
        )
        #expect(
            ImageEditorKeyboardShortcutAction.resolve(
                charactersIgnoringModifiers: "j",
                modifierFlags: [.command, .shift]
            ) == .cutSelectionToLayer
        )

        let menuSource = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let layerMenuStart = try #require(menuSource.range(of: "private var layerMenu: some View"))
        let selectMenuStart = try #require(
            menuSource[layerMenuStart.upperBound...].range(of: "private var selectMenu: some View")
        )
        let layerMenuSource = menuSource[layerMenuStart.lowerBound..<selectMenuStart.lowerBound]
        #expect(!layerMenuSource.contains(".keyboardShortcut(\"j\""))
    }

    @Test func componentTilesDoNotCombineNativeButtonTrackingWithDragSources() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("veilpic/XomoLeftSidebar.swift"),
            encoding: .utf8
        )
        let previewStart = try #require(source.range(of: "private func componentPreview("))
        let labelStart = try #require(
            source[previewStart.upperBound...].range(of: "private func componentPreviewLabel(")
        )
        let previewSource = source[previewStart.lowerBound..<labelStart.lowerBound]

        #expect(previewSource.contains("componentPreviewLabel(item, isAvailable: true)"))
        #expect(previewSource.contains(".onTapGesture"))
        #expect(previewSource.contains(".xomoDraggable(component.rawValue)"))
        #expect(previewSource.contains(".accessibilityAction"))
        #expect(!previewSource.contains("Button {"))
    }

    @Test func moveToolShowsCopyBadgeOnlyAfterAnOptionDragStarts() {
        let normal = ImageEditorCanvasCursor.objectMoveCursor()
        let duplicating = ImageEditorCanvasCursor.objectMoveCursor(isDuplicating: true)

        #expect(normal.image.tiffRepresentation != duplicating.image.tiffRepresentation)
        #expect(ImageEditorCanvasCursor.cursor(for: .move, brushDiameter: 18) === NSCursor.arrow)
        #expect(
            ImageEditorCanvasCursor.cursor(
                for: .tools,
                selectedTool: .move,
                brushDiameter: 18,
                modifierFlags: [.option]
            ) === NSCursor.arrow
        )
    }

    @Test func arrowNudgeUsesPhotoshopStyleModifierDistances() {
        #expect(ImageEditorArrowNudge.delta(for: 123, modifierFlags: []) == CGSize(width: -1, height: 0))
        #expect(ImageEditorArrowNudge.delta(for: 124, modifierFlags: [.option]) == CGSize(width: 5, height: 0))
        #expect(ImageEditorArrowNudge.delta(for: 126, modifierFlags: [.shift]) == CGSize(width: 0, height: -10))
        #expect(ImageEditorArrowNudge.delta(for: 125, modifierFlags: [.command]) == nil)
    }

    @Test func selectionCursorModesReflectPhotoshopModifierSemantics() {
        #expect(ImageEditorSelectionCursorMode.from(modifierFlags: []) == .replace)
        #expect(ImageEditorSelectionCursorMode.from(modifierFlags: [.shift]) == .add)
        #expect(ImageEditorSelectionCursorMode.from(modifierFlags: [.option]) == .subtract)
        #expect(ImageEditorSelectionCursorMode.from(modifierFlags: [.shift, .option]) == .intersect)

        let replace = ImageEditorCanvasCursor.cursor(for: .marquee, brushDiameter: 18)
        let add = ImageEditorCanvasCursor.cursor(for: .marquee, brushDiameter: 18, modifierFlags: [.shift])
        let subtract = ImageEditorCanvasCursor.cursor(for: .marquee, brushDiameter: 18, modifierFlags: [.option])
        let intersect = ImageEditorCanvasCursor.cursor(for: .marquee, brushDiameter: 18, modifierFlags: [.shift, .option])
        #expect(replace === NSCursor.crosshair)
        #expect(replace.image.tiffRepresentation != add.image.tiffRepresentation)
        #expect(add.image.tiffRepresentation != subtract.image.tiffRepresentation)
        #expect(subtract.image.tiffRepresentation != intersect.image.tiffRepresentation)
    }

    @Test func marqueeUsesTheConventionalCrosshairForEveryBaseShape() {
        let rectangle = ImageEditorCanvasCursor.cursor(
            for: .marquee,
            brushDiameter: 18,
            marqueeShape: .rectangle
        )
        let ellipse = ImageEditorCanvasCursor.cursor(
            for: .marquee,
            brushDiameter: 18,
            marqueeShape: .ellipse
        )

        #expect(rectangle === NSCursor.crosshair)
        #expect(ellipse === NSCursor.crosshair)
    }

    @Test func capsLockSwitchesEveryBrushLikeToolToPrecisionCursor() {
        let brush = ImageEditorCanvasCursor.cursor(for: .brush, brushDiameter: 18)
        let precision = ImageEditorCanvasCursor.cursor(
            for: .brush,
            brushDiameter: 18,
            modifierFlags: [.capsLock]
        )
        let eraserPrecision = ImageEditorCanvasCursor.cursor(
            for: .eraser,
            brushDiameter: 18,
            modifierFlags: [.capsLock]
        )
        let clonePrecision = ImageEditorCanvasCursor.cursor(
            for: .cloneStamp,
            brushDiameter: 18,
            modifierFlags: [.capsLock]
        )
        let healingPrecision = ImageEditorCanvasCursor.cursor(
            for: .healingBrush,
            brushDiameter: 18,
            modifierFlags: [.capsLock]
        )

        #expect(brush !== NSCursor.crosshair)
        #expect(precision === NSCursor.crosshair)
        #expect(eraserPrecision === NSCursor.crosshair)
        #expect(clonePrecision === NSCursor.crosshair)
        #expect(healingPrecision === NSCursor.crosshair)
        #expect(ImageEditorCanvasCursor.cursor(for: .cloneStamp, brushDiameter: 18) !== NSCursor.crosshair)
        #expect(ImageEditorCanvasCursor.cursor(for: .healingBrush, brushDiameter: 18) !== NSCursor.crosshair)
    }

    @Test func zoomCursorReflectsOptionZoomOutMode() {
        let zoomIn = ImageEditorCanvasCursor.cursor(for: .zoom, brushDiameter: 18)
        let zoomOut = ImageEditorCanvasCursor.cursor(
            for: .zoom,
            brushDiameter: 18,
            modifierFlags: [.option]
        )

        #expect(zoomIn.image.tiffRepresentation != zoomOut.image.tiffRepresentation)
        #expect(
            ImageEditorCanvasCursor.cursor(
                for: .tools,
                selectedTool: .zoom,
                brushDiameter: 18,
                modifierFlags: [.option]
            ).image.tiffRepresentation == zoomOut.image.tiffRepresentation
        )
    }

    @Test func componentLibraryUsesClosedHandOnlyDuringCanvasPan() {
        let arrow = ImageEditorCanvasCursor.cursor(
            for: .components,
            selectedTool: .brush,
            brushDiameter: 18,
            isCanvasPanGestureActive: false
        )
        let closedHand = ImageEditorCanvasCursor.cursor(
            for: .components,
            selectedTool: .brush,
            brushDiameter: 18,
            handIsDragging: true,
            isCanvasPanGestureActive: true
        )

        #expect(arrow === NSCursor.arrow)
        #expect(closedHand === NSCursor.closedHand)
    }

    @Test func zoomDirectionUsesOptionForZoomOut() {
        #expect(ImageEditorZoomDirection.from(modifierFlags: []) == .zoomIn)
        #expect(ImageEditorZoomDirection.from(modifierFlags: [.shift]) == .zoomIn)
        #expect(ImageEditorZoomDirection.from(modifierFlags: [.option]) == .zoomOut)
        #expect(ImageEditorZoomDirection.from(modifierFlags: [.option, .shift]) == .zoomOut)
    }

    @Test func cropHandlesUseContextualResizeCursors() {
        let move = ImageEditorCanvasCursor.cursor(
            for: .tools,
            selectedTool: .crop,
            brushDiameter: 18,
            cropHandle: .move
        )
        let top = ImageEditorCanvasCursor.cursor(
            for: .tools,
            selectedTool: .crop,
            brushDiameter: 18,
            cropHandle: .top
        )
        let left = ImageEditorCanvasCursor.cursor(
            for: .tools,
            selectedTool: .crop,
            brushDiameter: 18,
            cropHandle: .left
        )
        let diagonalForward = ImageEditorCanvasCursor.cursor(
            for: .tools,
            selectedTool: .crop,
            brushDiameter: 18,
            cropHandle: .topLeft
        )
        let diagonalBackward = ImageEditorCanvasCursor.cursor(
            for: .tools,
            selectedTool: .crop,
            brushDiameter: 18,
            cropHandle: .topRight
        )
        let defaultCrop = ImageEditorCanvasCursor.cursor(
            for: .tools,
            selectedTool: .crop,
            brushDiameter: 18
        )

        #expect(move === NSCursor.openHand)
        #expect(top === NSCursor.resizeUpDown)
        #expect(left === NSCursor.resizeLeftRight)
        #expect(diagonalForward !== NSCursor.crosshair)
        #expect(diagonalBackward !== NSCursor.crosshair)
        #expect(diagonalForward.image.tiffRepresentation != diagonalBackward.image.tiffRepresentation)
        #expect(defaultCrop.image.tiffRepresentation != diagonalForward.image.tiffRepresentation)
    }

    @Test func layerTransformGeometryFindsTheNearestVisibleControl() {
        let frame = CGRect(x: 20, y: 30, width: 120, height: 80)

        #expect(
            ImageEditorCanvasCursor.transformTarget(
                at: CGPoint(x: 21, y: 31),
                frame: frame,
                canResize: true,
                canRotate: true
            ) == .resize(.topLeft)
        )
        #expect(
            ImageEditorCanvasCursor.transformTarget(
                at: CGPoint(x: 80, y: 30),
                frame: frame,
                canResize: true,
                canRotate: true
            ) == .resize(.top)
        )
        #expect(
            ImageEditorCanvasCursor.transformTarget(
                at: CGPoint(x: 80, y: 6),
                frame: frame,
                canResize: true,
                canRotate: true
            ) == .rotate
        )
        #expect(
            ImageEditorCanvasCursor.transformTarget(
                at: CGPoint(x: 80, y: 6),
                frame: frame,
                canResize: true,
                canRotate: false
            ) == nil
        )
        #expect(
            ImageEditorCanvasCursor.transformTarget(
                at: CGPoint(x: 80, y: 70),
                frame: frame,
                canResize: true,
                canRotate: true
            ) == nil
        )
        #expect(
            ImageEditorCanvasCursor.transformTarget(
                at: CGPoint(x: 80, y: 70),
                frame: frame,
                canResize: true,
                canRotate: true,
                referencePoint: CGPoint(x: 80, y: 70),
                canMoveReferencePoint: true
            ) == .referencePoint
        )
    }

    @Test func layerTransformControlsUseFamiliarResizeAndRotateCursors() {
        let vertical = ImageEditorCanvasCursor.transformCursor(for: .resize(.top))
        let horizontal = ImageEditorCanvasCursor.transformCursor(for: .resize(.left))
        let forward = ImageEditorCanvasCursor.transformCursor(for: .resize(.topLeft))
        let backward = ImageEditorCanvasCursor.transformCursor(for: .resize(.topRight))
        let rotate = ImageEditorCanvasCursor.transformCursor(for: .rotate)
        let referencePoint = ImageEditorCanvasCursor.transformCursor(for: .referencePoint)

        #expect(vertical === NSCursor.resizeUpDown)
        #expect(horizontal === NSCursor.resizeLeftRight)
        #expect(forward.image.tiffRepresentation != backward.image.tiffRepresentation)
        #expect(rotate !== NSCursor.arrow)
        #expect(rotate !== NSCursor.crosshair)
        #expect(rotate.image.tiffRepresentation != forward.image.tiffRepresentation)
        #expect(referencePoint === NSCursor.crosshair)
    }

    @Test func compactLayerTransformControlsPreserveAnInteriorMoveTarget() {
        let compactFrame = CGRect(x: 40, y: 40, width: 12, height: 12)

        #expect(
            ImageEditorLayerTransformControlLayout.visibleResizeHandles(in: compactFrame)
                == [.topLeft, .topRight, .bottomLeft, .bottomRight]
        )
        #expect(!ImageEditorLayerTransformControlLayout.showsReferencePoint(in: compactFrame))
        #expect(
            ImageEditorCanvasCursor.transformTarget(
                at: CGPoint(x: 46, y: 46),
                frame: compactFrame,
                canResize: true,
                canRotate: true,
                referencePoint: CGPoint(x: 46, y: 46),
                canMoveReferencePoint: true
            ) == nil
        )
        #expect(
            ImageEditorCanvasCursor.transformTarget(
                at: CGPoint(x: 40, y: 40),
                frame: compactFrame,
                canResize: true,
                canRotate: true
            ) == .resize(.topLeft)
        )

        let regularFrame = CGRect(x: 40, y: 40, width: 120, height: 80)
        #expect(
            ImageEditorLayerTransformControlLayout.visibleResizeHandles(in: regularFrame)
                == ImageEditorLayerResizeHandle.allCases
        )
        #expect(ImageEditorLayerTransformControlLayout.showsReferencePoint(in: regularFrame))
    }

    @Test func visualResizeHandlesMapToTheTransformModelsVerticalAxis() {
        #expect(ImageEditorLayerResizeHandle.topLeft.transformModelHandle == .bottomLeft)
        #expect(ImageEditorLayerResizeHandle.top.transformModelHandle == .bottom)
        #expect(ImageEditorLayerResizeHandle.topRight.transformModelHandle == .bottomRight)
        #expect(ImageEditorLayerResizeHandle.left.transformModelHandle == .left)
        #expect(ImageEditorLayerResizeHandle.right.transformModelHandle == .right)
        #expect(ImageEditorLayerResizeHandle.bottomLeft.transformModelHandle == .topLeft)
        #expect(ImageEditorLayerResizeHandle.bottom.transformModelHandle == .top)
        #expect(ImageEditorLayerResizeHandle.bottomRight.transformModelHandle == .topRight)
    }

    @Test func activeLayerTransformKeepsItsCursorAfterPointerLeavesTheHandle() {
        #expect(
            ImageEditorCanvasCursor.resolvedTransformTarget(
                hoveredTarget: nil,
                activeResizeHandle: .bottomRight,
                isRotating: false
            ) == .resize(.bottomRight)
        )
        #expect(
            ImageEditorCanvasCursor.resolvedTransformTarget(
                hoveredTarget: .resize(.left),
                activeResizeHandle: .top,
                isRotating: false
            ) == .resize(.top)
        )
        #expect(
            ImageEditorCanvasCursor.resolvedTransformTarget(
                hoveredTarget: nil,
                activeResizeHandle: nil,
                isRotating: true
            ) == .rotate
        )
        #expect(
            ImageEditorCanvasCursor.resolvedTransformTarget(
                hoveredTarget: .resize(.right),
                activeResizeHandle: nil,
                isRotating: false
            ) == .resize(.right)
        )
        #expect(
            ImageEditorCanvasCursor.resolvedTransformTarget(
                hoveredTarget: nil,
                activeResizeHandle: nil,
                isRotating: false,
                isMovingReferencePoint: true
            ) == .referencePoint
        )
    }

    @Test func transformControlCursorOverridesComponentArrowOutsideDrawableCanvas() {
        let rotate = ImageEditorCanvasCursor.cursor(
            for: .components,
            selectedTool: .brush,
            brushDiameter: 18,
            isPointerOverCanvas: false,
            layerTransformTarget: .rotate
        )
        let dragging = ImageEditorCanvasCursor.cursor(
            for: .components,
            selectedTool: .brush,
            brushDiameter: 18,
            isPointerOverCanvas: false,
            isObjectMoveGestureActive: true,
            layerTransformTarget: .rotate
        )

        #expect(rotate !== NSCursor.arrow)
        #expect(dragging === ImageEditorCanvasCursor.objectMoveCursor())
    }

    @Test func toolCursorsUseFamiliarPrecisionAndBrushConventions() {
        #expect(ImageEditorCanvasCursor.family(for: .paintBucket) == .paintBucket)
        #expect(ImageEditorCanvasCursor.family(for: .eyedropper) == .eyedropper)
        #expect(ImageEditorCanvasCursor.family(for: .redEye) == .redEye)
        #expect(ImageEditorCanvasCursor.family(for: .quickSelection) == .quickSelection)
        #expect(ImageEditorCanvasCursor.family(for: .cloneStamp) == .cloneStamp)
        #expect(ImageEditorCanvasCursor.family(for: .healingBrush) == .healingBrush)
        #expect(ImageEditorCanvasCursor.family(for: .colorSampler) == .samplingScope)
        #expect(ImageEditorCanvasCursor.family(for: .brush) == .brushTool)
        #expect(ImageEditorCanvasCursor.family(for: .eraser) == .eraserTool)
        #expect(ImageEditorCanvasCursor.family(for: .rectangle) == .rectangleOutline)
        #expect(ImageEditorCanvasCursor.family(for: .ellipse) == .ellipseOutline)
        #expect(ImageEditorCanvasCursor.family(for: .dodge) == .toneBrush)
        #expect(ImageEditorCanvasCursor.family(for: .burn) == .toneBrush)
        #expect(ImageEditorCanvasCursor.family(for: .sponge) == .toneBrush)
        #expect(ImageEditorCanvasCursor.family(for: .blur) == .retouchBrush)
        #expect(ImageEditorCanvasCursor.family(for: .sharpen) == .retouchBrush)
        #expect(ImageEditorCanvasCursor.family(for: .smudge) == .retouchBrush)

        let precisionTools: [ImageEditorTool] = [
            .marquee, .crop, .gradient, .rectangle, .ellipse, .redEye, .colorSampler
        ]
        for tool in precisionTools {
            #expect(ImageEditorCanvasCursor.cursor(for: tool, brushDiameter: 18) === NSCursor.crosshair)
        }

        let familiarSpecificTools: [ImageEditorTool] = [
            .lasso, .magicWand, .quickSelection, .patchTool, .pen,
            .paintBucket, .eyedropper, .zoom
        ]
        for tool in familiarSpecificTools {
            #expect(ImageEditorCanvasCursor.cursor(for: tool, brushDiameter: 18) !== NSCursor.crosshair)
        }

        let brushTools: [ImageEditorTool] = [
            .brush, .eraser, .cloneStamp, .healingBrush,
            .dodge, .burn, .sponge, .blur, .sharpen, .smudge
        ]
        let brushRepresentations = brushTools.compactMap {
            ImageEditorCanvasCursor.cursor(for: $0, brushDiameter: 18).image.tiffRepresentation
        }
        #expect(brushRepresentations.count == brushTools.count)
        #expect(Set(brushRepresentations).count == 1)

        #expect(ImageEditorCanvasCursor.cursor(for: .paintBucket, brushDiameter: 18) !== NSCursor.crosshair)
        #expect(ImageEditorCanvasCursor.cursor(for: .eyedropper, brushDiameter: 18) !== NSCursor.crosshair)
        #expect(ImageEditorCanvasCursor.cursor(for: .pen, brushDiameter: 18) !== NSCursor.crosshair)
    }

    @Test func colorSamplerCursorDistinguishesPlacementMoveAndOptionRemoval() {
        let placement = ImageEditorCanvasCursor.cursor(
            for: .tools,
            selectedTool: .colorSampler,
            brushDiameter: 18
        )
        let pointHover = ImageEditorCanvasCursor.cursor(
            for: .tools,
            selectedTool: .colorSampler,
            brushDiameter: 18,
            isPointerOverColorSamplerPoint: true
        )
        let moving = ImageEditorCanvasCursor.cursor(
            for: .tools,
            selectedTool: .colorSampler,
            brushDiameter: 18,
            isColorSamplerMoveGestureActive: true
        )
        let removing = ImageEditorCanvasCursor.cursor(
            for: .tools,
            selectedTool: .colorSampler,
            brushDiameter: 18,
            isPointerOverColorSamplerPoint: true,
            modifierFlags: [.option]
        )
        let componentLibrary = ImageEditorCanvasCursor.cursor(
            for: .components,
            selectedTool: .colorSampler,
            brushDiameter: 18,
            isPointerOverColorSamplerPoint: true,
            modifierFlags: [.option]
        )

        #expect(placement === NSCursor.crosshair)
        #expect(pointHover === ImageEditorCanvasCursor.objectMoveCursor())
        #expect(moving === ImageEditorCanvasCursor.objectMoveCursor())
        #expect(removing !== NSCursor.crosshair)
        #expect(removing !== ImageEditorCanvasCursor.objectMoveCursor())
        #expect(componentLibrary === NSCursor.arrow)
    }

    @Test func pathSelectionUsesTheFamiliarSystemArrowAndPhotoshopShortcut() {
        #expect(ImageEditorCanvasCursor.family(for: .pathSelection) == .systemArrow)
        #expect(ImageEditorCanvasCursor.cursor(for: .pathSelection, brushDiameter: 18) === NSCursor.arrow)
        #expect(ImageEditorTool.classicShortcutGroup(for: "a")?.primaryTool == .pathSelection)
    }

    @Test func directSelectionUsesAWhiteEditingArrowAndSharesTheAGroup() {
        #expect(ImageEditorCanvasCursor.family(for: .directSelection) == .directSelection)
        let directSelection = ImageEditorCanvasCursor.cursor(for: .directSelection, brushDiameter: 18)
        #expect(directSelection !== NSCursor.arrow)
        #expect(directSelection.image.tiffRepresentation != NSCursor.arrow.image.tiffRepresentation)
        #expect(ImageEditorTool.classicShortcutGroup(for: "a")?.tools.contains(.directSelection) == true)
    }

    @Test func selectionToolsUseRecognizablePointersInsteadOfOneGenericShape() {
        let marquee = ImageEditorCanvasCursor.cursor(for: .marquee, brushDiameter: 18)
        let lasso = ImageEditorCanvasCursor.cursor(for: .lasso, brushDiameter: 18)
        let wand = ImageEditorCanvasCursor.cursor(for: .magicWand, brushDiameter: 18)
        let quick = ImageEditorCanvasCursor.cursor(for: .quickSelection, brushDiameter: 18)

        let representations = [marquee, lasso, wand, quick].map { $0.image.tiffRepresentation }
        #expect(Set(representations).count == representations.count)
    }

    @Test func selectionModifierCursorStillCommunicatesAddSubtractModes() {
        let tools: [ImageEditorTool] = [
            .marquee, .lasso, .magicWand, .quickSelection
        ]
        for tool in tools {
            let base = ImageEditorCanvasCursor.cursor(for: tool, brushDiameter: 18)
            let add = ImageEditorCanvasCursor.cursor(for: tool, brushDiameter: 18, modifierFlags: [.shift])
            let subtract = ImageEditorCanvasCursor.cursor(for: tool, brushDiameter: 18, modifierFlags: [.option])
            if tool == .marquee {
                #expect(base === NSCursor.crosshair)
            } else {
                #expect(base !== NSCursor.crosshair)
            }
            #expect(add.image.tiffRepresentation != base.image.tiffRepresentation)
            #expect(subtract.image.tiffRepresentation != base.image.tiffRepresentation)
            #expect(add.image.tiffRepresentation != subtract.image.tiffRepresentation)
        }
    }
}
