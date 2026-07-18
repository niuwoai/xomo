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
            ImageEditorCanvasCursor.cursor(for: .move, brushDiameter: 18) !== NSCursor.arrow
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
        #expect(move !== NSCursor.arrow)
        #expect(move.image.tiffRepresentation != NSCursor.arrow.image.tiffRepresentation)
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

    @Test func objectDragReleaseAlwaysClosesEvenWhenPointerLeavesCanvasWindow() {
        #expect(
            ImageEditorObjectDragEventPolicy.shouldFinish(
                eventType: .leftMouseUp,
                isObjectMoving: true
            )
        )
        #expect(
            ImageEditorObjectDragEventPolicy.shouldFinish(
                eventType: .leftMouseDragged,
                isObjectMoving: true
            ) == false
        )
        #expect(
            ImageEditorObjectDragEventPolicy.shouldFinish(
                eventType: .leftMouseUp,
                isObjectMoving: false
            ) == false
        )
    }

    @Test func moveToolShowsCopyBadgeWhileHoldingOption() {
        let normal = ImageEditorCanvasCursor.cursor(
            for: .tools,
            selectedTool: .move,
            brushDiameter: 18
        )
        let duplicating = ImageEditorCanvasCursor.cursor(
            for: .tools,
            selectedTool: .move,
            brushDiameter: 18,
            modifierFlags: [.option]
        )

        #expect(normal.image.tiffRepresentation != duplicating.image.tiffRepresentation)
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
        #expect(replace.image.tiffRepresentation != add.image.tiffRepresentation)
        #expect(add.image.tiffRepresentation != subtract.image.tiffRepresentation)
        #expect(subtract.image.tiffRepresentation != intersect.image.tiffRepresentation)
    }

    @Test func marqueeCursorReflectsTheSelectedSelectionShape() {
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

        #expect(rectangle.image.tiffRepresentation != ellipse.image.tiffRepresentation)
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

        let semanticTools: [ImageEditorTool] = [
            .marquee, .lasso, .magicWand, .quickSelection,
            .crop, .patchTool, .gradient, .rectangle, .ellipse, .pen
        ]
        for tool in semanticTools {
            let cursor = ImageEditorCanvasCursor.cursor(for: tool, brushDiameter: 18)
            #expect(cursor !== NSCursor.crosshair)
            #expect(cursor.image.tiffRepresentation != NSCursor.crosshair.image.tiffRepresentation)
        }

        #expect(
            ImageEditorCanvasCursor.cursor(for: .rectangle, brushDiameter: 18).image.tiffRepresentation
                != ImageEditorCanvasCursor.cursor(for: .ellipse, brushDiameter: 18).image.tiffRepresentation
        )

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
            #expect(base !== NSCursor.crosshair)
            let add = ImageEditorCanvasCursor.cursor(for: tool, brushDiameter: 18, modifierFlags: [.shift])
            let subtract = ImageEditorCanvasCursor.cursor(for: tool, brushDiameter: 18, modifierFlags: [.option])
            #expect(add.image.tiffRepresentation != base.image.tiffRepresentation)
            #expect(subtract.image.tiffRepresentation != base.image.tiffRepresentation)
            #expect(add.image.tiffRepresentation != subtract.image.tiffRepresentation)
        }
    }
}
