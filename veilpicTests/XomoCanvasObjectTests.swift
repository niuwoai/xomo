import AppKit
import Testing
@testable import musepic

@MainActor
struct XomoCanvasObjectTests {
    @Test func objectBoxSelectionRequiresThreeViewPointsAndNormalizesDirection() throws {
        #expect(!ImageEditorObjectBoxSelectionPolicy.isActivated(
            viewTranslation: CGSize(width: 2.9, height: 0)
        ))
        #expect(ImageEditorObjectBoxSelectionPolicy.isActivated(
            viewTranslation: CGSize(width: 0, height: -3)
        ))

        let rect = try #require(ImageEditorObjectBoxSelectionPolicy.selectionRect(
            from: CGPoint(x: 90, y: 70),
            to: CGPoint(x: 20, y: 30)
        ))
        #expect(rect == CGRect(x: 20, y: 30, width: 70, height: 40))
        #expect(ImageEditorObjectBoxSelectionPolicy.selectionRect(
            from: CGPoint(x: 10, y: 10),
            to: CGPoint(x: 10, y: 10)
        ) == nil)
        #expect(ImageEditorObjectBoxSelectionScope.resolve(
            sidebarTab: .tools,
            modifierFlags: [.command]
        ) == .deepLayers)
        #expect(ImageEditorObjectBoxSelectionScope.resolve(
            sidebarTab: .components,
            modifierFlags: [.command]
        ) == .configured)
        let target = CGRect(x: 20, y: 20, width: 40, height: 30)
        let partialSelection = CGRect(x: 10, y: 10, width: 30, height: 30)
        let containingSelection = CGRect(x: 10, y: 10, width: 60, height: 50)
        #expect(ImageEditorObjectBoxSelectionInclusion.touching.includes(
            targetFrame: target,
            in: partialSelection
        ))
        #expect(!ImageEditorObjectBoxSelectionInclusion.contained.includes(
            targetFrame: target,
            in: partialSelection
        ))
        #expect(ImageEditorObjectBoxSelectionInclusion.contained.includes(
            targetFrame: target,
            in: containingSelection
        ))
    }

    @Test func layerScopeBoxSelectionUsesVisibleLeafBoundsWithoutHistory() {
        let viewModel = makeViewModel()
        viewModel.document.layers = []
        viewModel.document.selectedLayerID = nil
        viewModel.document.selectedLayerIDs = []
        var first = ImageEditorLayer.solidColorFill(
            name: "First",
            size: CGSize(width: 40, height: 30),
            content: ImageEditorSolidColorFillContent(red: 1, green: 0, blue: 0)
        )
        first.frame.origin = CGPoint(x: 20, y: 30)
        var second = ImageEditorLayer.solidColorFill(
            name: "Second",
            size: CGSize(width: 50, height: 40),
            content: ImageEditorSolidColorFillContent(red: 0, green: 0, blue: 1)
        )
        second.frame.origin = CGPoint(x: 160, y: 120)
        var hidden = ImageEditorLayer.solidColorFill(
            name: "Hidden",
            size: CGSize(width: 30, height: 30),
            content: ImageEditorSolidColorFillContent(red: 0, green: 1, blue: 0)
        )
        hidden.frame.origin = CGPoint(x: 45, y: 40)
        hidden.isVisible = false
        viewModel.document.layers = [first, second, hidden]
        viewModel.isMoveToolAutoSelectEnabled = true
        viewModel.moveToolAutoSelectTarget = .layer
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        let partialRect = CGRect(x: 10, y: 20, width: 25, height: 25)
        #expect(viewModel.moveToolBoxSelectionTargetIDs(
            in: partialRect,
            inclusion: .touching
        ) == [first.id])
        #expect(viewModel.moveToolBoxSelectionTargetIDs(
            in: partialRect,
            inclusion: .contained
        ).isEmpty)
        #expect(viewModel.moveToolBoxSelectionTargetIDs(
            in: CGRect(x: 10, y: 20, width: 65, height: 55),
            inclusion: .contained
        ) == [first.id])

        #expect(viewModel.applyMoveToolBoxSelection(
            in: CGRect(x: 10, y: 20, width: 65, height: 55),
            mode: .replace
        ))
        #expect(viewModel.document.selectedLayerIDs == [first.id])
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
    }

    @Test func groupScopePromotesIntersectedLeavesAndDeduplicatesTheirContainer() throws {
        let viewModel = makeViewModel()
        viewModel.document.layers = []
        viewModel.document.selectedLayerID = nil
        viewModel.document.selectedLayerIDs = []
        let outer = ImageEditorLayer.group(name: "Outer", size: viewModel.document.canvasSize)
        var inner = ImageEditorLayer.group(name: "Inner", size: viewModel.document.canvasSize)
        inner.groupID = outer.id
        var first = ImageEditorLayer.solidColorFill(
            name: "First",
            size: CGSize(width: 30, height: 30),
            content: ImageEditorSolidColorFillContent(red: 1, green: 0, blue: 0)
        )
        first.groupID = inner.id
        first.frame.origin = CGPoint(x: 30, y: 30)
        var second = ImageEditorLayer.solidColorFill(
            name: "Second",
            size: CGSize(width: 30, height: 30),
            content: ImageEditorSolidColorFillContent(red: 0, green: 0, blue: 1)
        )
        second.groupID = inner.id
        second.frame.origin = CGPoint(x: 80, y: 30)
        viewModel.document.layers = [first, second, inner, outer]
        viewModel.isMoveToolAutoSelectEnabled = true
        viewModel.moveToolAutoSelectTarget = .group

        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count
        let targets = viewModel.moveToolBoxSelectionTargets(
            in: CGRect(x: 20, y: 20, width: 100, height: 50)
        )

        #expect(targets.map(\.id) == [outer.id])
        #expect(targets.first?.frame == first.frame.union(second.frame))
        #expect(viewModel.moveToolBoxSelectionTargetIDs(
            in: CGRect(x: 20, y: 20, width: 100, height: 50),
            inclusion: .contained
        ) == [outer.id])
        #expect(viewModel.moveToolBoxSelectionTargetIDs(
            in: CGRect(x: 20, y: 20, width: 25, height: 25),
            inclusion: .contained
        ).isEmpty)
        #expect(viewModel.document.selectedLayerIDs.isEmpty)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)

        let deepTargets = viewModel.moveToolBoxSelectionTargets(
            in: CGRect(x: 20, y: 20, width: 100, height: 50),
            scope: .deepLayers
        )
        #expect(deepTargets.map(\.id) == [first.id, second.id])
        #expect(viewModel.applyMoveToolBoxSelection(
            in: CGRect(x: 20, y: 20, width: 100, height: 50),
            mode: .replace,
            scope: .deepLayers
        ))
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id])
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
    }

    @Test func componentModeBoxSelectionReturnsWholeInstances() throws {
        let viewModel = makeViewModel()
        viewModel.document.layers = []
        viewModel.document.selectedLayerID = nil
        viewModel.document.selectedLayerIDs = []
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        let firstGroup = try #require(viewModel.document.selectedLayer)
        viewModel.insertXomoComponent(.badge, at: CGPoint(x: 280, y: 190))
        let secondGroup = try #require(viewModel.document.selectedLayer)
        let firstBounds = try #require(viewModel.document.layers
            .filter { $0.groupID == firstGroup.id }
            .map(\.frame)
            .reduce(nil) { bounds, frame in bounds?.union(frame) ?? frame })
        let union = try #require(viewModel.document.layers
            .filter { $0.groupID == firstGroup.id || $0.groupID == secondGroup.id }
            .map(\.frame)
            .reduce(nil) { bounds, frame in bounds?.union(frame) ?? frame })
        let childIDs = Set(viewModel.document.layers
            .filter {
                ($0.groupID == firstGroup.id || $0.groupID == secondGroup.id)
                    && !$0.isGroup
                    && !$0.isAdjustment
                    && !$0.isFilter
                    && viewModel.document.isEffectivelyVisible($0)
            }
            .map(\.id))

        let deepTargets = viewModel.moveToolBoxSelectionTargets(
            in: union.insetBy(dx: -2, dy: -2),
            scope: .deepLayers
        )
        #expect(Set(deepTargets.map(\.id)) == childIDs)
        #expect(!deepTargets.contains { $0.id == firstGroup.id || $0.id == secondGroup.id })

        viewModel.selectLeftSidebarTab(.components)

        let targets = viewModel.moveToolBoxSelectionTargets(
            in: union.insetBy(dx: -2, dy: -2),
            scope: .deepLayers,
            inclusion: .contained
        )
        let ids = Set(targets.map(\.id))

        #expect(ids == [firstGroup.id, secondGroup.id])
        #expect(targets.allSatisfy { target in
            let childBounds = viewModel.document.layers
                .filter { $0.groupID == target.id }
                .map(\.frame)
                .reduce(nil) { bounds, frame in bounds?.union(frame) ?? frame }
            return target.frame == childBounds
        })
        #expect(!ids.contains { id in
            viewModel.document.layers.contains { $0.id == id && $0.groupID != nil }
        })
        #expect(viewModel.moveToolBoxSelectionTargets(
            in: firstBounds.insetBy(
                dx: firstBounds.width * 0.25,
                dy: firstBounds.height * 0.25
            ),
            scope: .deepLayers,
            inclusion: .contained
        ).isEmpty)
    }

    @Test func shiftBoxSelectionAddsTargetsAndEmptyPlainBoxClearsWithoutUndo() {
        let viewModel = makeViewModel()
        viewModel.document.layers = []
        viewModel.document.selectedLayerID = nil
        viewModel.document.selectedLayerIDs = []
        var first = ImageEditorLayer.solidColorFill(
            name: "First",
            size: CGSize(width: 30, height: 30),
            content: ImageEditorSolidColorFillContent(red: 1, green: 0, blue: 0)
        )
        first.frame.origin = CGPoint(x: 20, y: 20)
        var second = ImageEditorLayer.solidColorFill(
            name: "Second",
            size: CGSize(width: 30, height: 30),
            content: ImageEditorSolidColorFillContent(red: 0, green: 0, blue: 1)
        )
        second.frame.origin = CGPoint(x: 120, y: 120)
        viewModel.document.layers = [first, second]
        viewModel.isMoveToolAutoSelectEnabled = true
        viewModel.moveToolAutoSelectTarget = .layer
        viewModel.selectLayer(first.id)
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        #expect(viewModel.applyMoveToolBoxSelection(
            in: CGRect(x: 110, y: 110, width: 50, height: 50),
            mode: .add
        ))
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id])
        #expect(!viewModel.applyMoveToolBoxSelection(
            in: CGRect(x: 400, y: 400, width: 20, height: 20),
            mode: .add
        ))
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id])
        #expect(viewModel.applyMoveToolBoxSelection(
            in: CGRect(x: 400, y: 400, width: 20, height: 20),
            mode: .replace
        ))
        #expect(viewModel.document.selectedLayerIDs.isEmpty)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
    }

    @Test func optionBoxSelectionSubtractsAndShiftOptionIntersectsWithoutHistory() {
        let viewModel = makeViewModel()
        viewModel.document.layers = []
        viewModel.document.selectedLayerID = nil
        viewModel.document.selectedLayerIDs = []
        let xPositions: [CGFloat] = [20, 120, 220]
        let layers = xPositions.enumerated().map { index, x -> ImageEditorLayer in
            var layer = ImageEditorLayer.solidColorFill(
                name: "Layer \(index)",
                size: CGSize(width: 40, height: 40),
                content: ImageEditorSolidColorFillContent(
                    red: index == 0 ? 1 : 0,
                    green: index == 1 ? 1 : 0,
                    blue: index == 2 ? 1 : 0
                )
            )
            layer.frame.origin = CGPoint(x: x, y: 40)
            return layer
        }
        viewModel.document.layers = layers
        viewModel.moveToolAutoSelectTarget = .layer
        viewModel.selectLayer(layers[0].id)
        viewModel.selectLayer(layers[1].id, extendingSelection: true)
        viewModel.selectLayer(layers[2].id, extendingSelection: true)
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        #expect(ImageEditorObjectBoxSelectionMode.resolve(modifierFlags: []) == .replace)
        #expect(ImageEditorObjectBoxSelectionMode.resolve(modifierFlags: [.shift]) == .add)
        #expect(ImageEditorObjectBoxSelectionMode.resolve(modifierFlags: [.option]) == .subtract)
        #expect(ImageEditorObjectBoxSelectionMode.resolve(
            modifierFlags: [.shift, .option]
        ) == .intersect)

        #expect(viewModel.applyMoveToolBoxSelection(
            in: CGRect(x: 110, y: 30, width: 60, height: 60),
            mode: .subtract
        ))
        #expect(viewModel.document.selectedLayerIDs == [layers[0].id, layers[2].id])
        #expect(viewModel.applyMoveToolBoxSelection(
            in: CGRect(x: 110, y: 30, width: 60, height: 60),
            mode: .add
        ))
        #expect(viewModel.document.selectedLayerIDs == Set(layers.map(\.id)))
        #expect(viewModel.applyMoveToolBoxSelection(
            in: CGRect(x: 110, y: 30, width: 160, height: 60),
            mode: .intersect
        ))
        #expect(viewModel.document.selectedLayerIDs == [layers[1].id, layers[2].id])

        let subtractPreview = viewModel.moveToolBoxSelectionPreviewTargets(
            in: CGRect(x: 10, y: 30, width: 160, height: 60),
            mode: .subtract
        )
        let addPreview = viewModel.moveToolBoxSelectionPreviewTargets(
            in: CGRect(x: 10, y: 30, width: 260, height: 60),
            mode: .add
        )
        #expect(subtractPreview.map(\.id) == [layers[1].id])
        #expect(addPreview.map(\.id) == [layers[0].id])
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
    }

    @Test func moveToolBlankCanvasGestureOwnsBoxSelectionInsteadOfPan() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("objectSelectionBoxOverlay(in: geometry.size)"))
        #expect(source.contains("viewModel.moveToolContentHit(at: pressedImagePoint) == .none"))
        #expect(source.contains("objectSelectionBoxDrag = ImageEditorObjectSelectionBoxDrag("))
        #expect(source.contains("viewModel.applyMoveToolBoxSelection("))
        #expect(source.contains("viewModel.moveToolBoxSelectionPreviewTargets("))
        #expect(source.contains("boxSelectionOwnsModifiedBlankDrag"))
        #expect(source.contains("mode: ImageEditorObjectBoxSelectionMode.resolve("))
        #expect(source.contains("scope: ImageEditorObjectBoxSelectionScope.resolve("))
        #expect(source.contains("inclusion: viewModel.moveToolBoxSelectionInclusion"))
        #expect(source.contains("inclusion: selectionBoxDrag.inclusion"))
        #expect(source.contains("selection: $viewModel.moveToolBoxSelectionInclusion"))
        #expect(source.contains("image-editor-move-box-selection-inclusion"))
        #expect(source.contains("moveToolUsesBoxSelection: viewModel.moveToolAutoSelectsCanvasTarget"))
        #expect(source.contains("onCanvasLifecycleInterrupted: { _ in\n                            objectSelectionBoxDrag = nil"))
        #expect(source.contains("if objectSelectionBoxDrag != nil {\n                        objectSelectionBoxDrag = nil"))
        #expect(source.contains("private func beginCanvasPointerSequence() {\n        // A lost mouse-up"))
    }

    @Test func canvasDragTranslationMapsViewPixelsToImagePixels() {
        let imageDelta = ImageEditorCanvasDragGeometry.imageDelta(
            from: CGSize(width: 75, height: 40),
            canvasSize: CGSize(width: 1_440, height: 900),
            imageRect: CGRect(x: 120, y: 80, width: 720, height: 450)
        )

        #expect(imageDelta == CGSize(width: 150, height: 80))
    }

    @Test func deliveryDragClampPreservesRectangleSizeAtCanvasEdges() {
        let viewModel = makeViewModel()
        let original = CGRect(x: 120, y: 90, width: 80, height: 50)

        let clamped = viewModel.clampedDeliveryFrame(
            original,
            offsetBy: CGSize(width: 10_000, height: 10_000)
        )

        #expect(clamped.origin == CGPoint(
            x: viewModel.document.canvasSize.width - original.width,
            y: viewModel.document.canvasSize.height - original.height
        ))
        #expect(clamped.size == original.size)
    }

    @Test func textToolCanSelectEditableTextInsideAComponent() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        let group = try #require(viewModel.document.selectedLayer)
        let textLayer = try #require(viewModel.document.layers.first { $0.groupID == group.id && $0.isText })

        #expect(viewModel.selectEditableTextLayer(at: CGPoint(x: textLayer.frame.midX, y: textLayer.frame.midY)))
        #expect(viewModel.document.selectedLayerID == textLayer.id)
        #expect(viewModel.document.selectedLayer?.textContent != nil)
    }

    @Test func textHitTestingCanExcludeTheJustCommittedLayer() throws {
        let viewModel = makeViewModel()
        viewModel.textValue = "First"
        viewModel.addText(at: CGPoint(x: 80, y: 90))
        let committedLayer = try #require(viewModel.document.selectedLayer)
        let pointInsideCommittedFrame = CGPoint(
            x: committedLayer.frame.midX,
            y: committedLayer.frame.midY
        )

        #expect(viewModel.selectEditableTextLayer(at: pointInsideCommittedFrame))
        #expect(!viewModel.selectEditableTextLayer(at: pointInsideCommittedFrame, excluding: committedLayer.id))
    }

    @Test func clickingAnUncoveredComponentSelectsItsObjectGroup() throws {
        let viewModel = makeViewModel()
        let origin = CGPoint(x: 80, y: 90)
        viewModel.insertXomoComponent(.button, at: origin)
        let group = try #require(viewModel.document.selectedLayer)

        viewModel.selectLayer(viewModel.document.layers.first!.id)
        let didSelect = viewModel.selectXomoObject(at: CGPoint(x: 160, y: 112))

        #expect(didSelect)
        #expect(viewModel.document.selectedLayerID == group.id)
        #expect(viewModel.document.selectedLayerIDs == [group.id])
    }

    @Test func componentsTabRoutesCanvasInputThroughMoveTool() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        let group = try #require(viewModel.document.selectedLayer)
        viewModel.selectLayer(viewModel.document.layers.first!.id)
        viewModel.selectLeftSidebarTab(.components)

        #expect(viewModel.canvasInteractionTool == .move)
        #expect(viewModel.selectXomoObject(at: CGPoint(x: 160, y: 95)))
        #expect(viewModel.document.selectedLayerID == group.id)
    }

    @Test func sharedMoveTargetFallbackSelectsAComponentBeforeItsChildren() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        let group = try #require(viewModel.document.selectedLayer)
        let backgroundID = try #require(viewModel.document.layers.first?.id)
        viewModel.selectLayer(backgroundID)

        #expect(viewModel.selectMovableCanvasTarget(at: CGPoint(x: 160, y: 112)))
        #expect(viewModel.document.selectedLayerID == group.id)
        #expect(viewModel.document.selectedLayerIDs == [group.id])
    }

    @Test func sharedMoveTargetFallbackStillSelectsOrdinaryVisibleLayers() throws {
        let viewModel = makeViewModel()
        var layer = ImageEditorLayer.solidColorFill(
            name: "Ordinary layer",
            size: CGSize(width: 120, height: 80),
            content: ImageEditorSolidColorFillContent(red: 0.2, green: 0.5, blue: 0.8)
        )
        layer.frame.origin = CGPoint(x: 140, y: 120)
        viewModel.document.layers.append(layer)

        #expect(viewModel.selectMovableCanvasTarget(at: CGPoint(x: 180, y: 150)))
        #expect(viewModel.document.selectedLayerID == layer.id)
    }

    @Test func componentObjectNudgeWinsOverStalePixelSelectionInComponentsMode() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        let initialFrame = try #require(viewModel.selectedXomoObjectFrame)

        viewModel.createMarqueeSelection(
            from: CGPoint(x: 12, y: 14),
            to: CGPoint(x: 42, y: 34)
        )
        let selectionBounds = try #require(viewModel.document.selection?.bounds)
        let historyCount = viewModel.document.history.count
        viewModel.selectLeftSidebarTab(.components)

        viewModel.nudgeSelectionOrSelectedLayer(by: CGSize(width: 5, height: 0))

        #expect(viewModel.selectedXomoObjectFrame?.minX == initialFrame.minX + 5)
        #expect(viewModel.selectedXomoObjectFrame?.minY == initialFrame.minY)
        #expect(viewModel.document.selection?.bounds == selectionBounds)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerTranslate"))
    }

    @Test func escapeClearsSelectedComponentObjectWithoutChangingHistory() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        viewModel.selectLeftSidebarTab(.components)
        let historyCount = viewModel.document.history.count

        #expect(viewModel.clearSelectedXomoObjectIfNeeded())
        #expect(viewModel.document.selectedLayerID == nil)
        #expect(viewModel.document.selectedLayerIDs.isEmpty)
        #expect(!viewModel.hasSelectedXomoObject)
        #expect(viewModel.document.history.count == historyCount)
    }

    @Test func escapeReturnsADeepSelectedComponentChildToItsParentGroup() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        let group = try #require(viewModel.document.selectedLayer)
        let child = try #require(viewModel.document.layers.first {
            $0.groupID == group.id && !$0.isGroup
        })
        viewModel.selectLayer(child.id)
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        #expect(viewModel.exitDeepCanvasSelectionIfNeeded())
        #expect(viewModel.document.selectedLayerID == group.id)
        #expect(viewModel.document.selectedLayerIDs == [group.id])
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(!viewModel.exitDeepCanvasSelectionIfNeeded())
        #expect(viewModel.document.selectedLayerID == group.id)
    }

    @Test func escapeClimbsNestedGroupsOneLevelButIgnoresMultiSelectionAndComponentsMode() throws {
        let viewModel = makeViewModel()
        let parentGroup = ImageEditorLayer.group(
            name: "Parent",
            size: viewModel.document.canvasSize
        )
        var childGroup = ImageEditorLayer.group(
            name: "Child",
            size: viewModel.document.canvasSize
        )
        childGroup.groupID = parentGroup.id
        var leaf = ImageEditorLayer.solidColorFill(
            name: "Leaf",
            size: CGSize(width: 80, height: 60),
            content: ImageEditorSolidColorFillContent(red: 0.2, green: 0.4, blue: 0.8)
        )
        leaf.groupID = childGroup.id
        viewModel.document.layers.append(contentsOf: [leaf, childGroup, parentGroup])

        viewModel.selectLayer(leaf.id)
        #expect(viewModel.exitDeepCanvasSelectionIfNeeded())
        #expect(viewModel.document.selectedLayerID == childGroup.id)
        #expect(viewModel.exitDeepCanvasSelectionIfNeeded())
        #expect(viewModel.document.selectedLayerID == parentGroup.id)

        viewModel.selectLayer(leaf.id)
        viewModel.selectLayer(parentGroup.id, extendingSelection: true)
        let multiSelection = viewModel.document.selectedLayerIDs
        #expect(!viewModel.exitDeepCanvasSelectionIfNeeded())
        #expect(viewModel.document.selectedLayerIDs == multiSelection)

        viewModel.selectLayer(leaf.id)
        viewModel.selectLeftSidebarTab(.components)
        #expect(!viewModel.exitDeepCanvasSelectionIfNeeded())
        #expect(viewModel.document.selectedLayerID == leaf.id)
    }

    @Test func escapeWiresParentNavigationAfterEveryActiveCanvasCancellation() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let escapeStart = try #require(source.range(of: "cancelSelectedObject: {"))
        let filterStart = try #require(
            source[escapeStart.upperBound...].range(of: "discardPendingSmartFilterChanges:")
        )
        let escapeSource = source[escapeStart.lowerBound..<filterStart.lowerBound]
        let transformCancel = try #require(
            escapeSource.range(of: "viewModel.cancelTransformingSelectedLayer()")
        )
        let moveCancel = try #require(
            escapeSource.range(of: "viewModel.cancelMovingSelectedLayer()")
        )
        let componentExit = try #require(
            escapeSource.range(of: "viewModel.clearSelectedXomoObjectIfNeeded()")
        )
        let parentExit = try #require(
            escapeSource.range(of: "viewModel.exitDeepCanvasSelectionIfNeeded()")
        )

        #expect(transformCancel.lowerBound < parentExit.lowerBound)
        #expect(moveCancel.lowerBound < parentExit.lowerBound)
        #expect(componentExit.lowerBound < parentExit.lowerBound)
        #expect(escapeSource.contains("return true"))
    }

    @Test func componentHitQueryDoesNotMutateSelection() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        let group = try #require(viewModel.document.selectedLayer)
        let frame = try #require(viewModel.selectedXomoObjectFrame)
        let backgroundID = try #require(viewModel.document.layers.first?.id)
        viewModel.selectLayer(backgroundID)

        #expect(viewModel.hasXomoObject(at: CGPoint(x: frame.midX, y: frame.midY)))
        #expect(viewModel.document.selectedLayerID == backgroundID)
        #expect(!viewModel.hasXomoObject(at: CGPoint(x: 620, y: 460)))
        #expect(viewModel.document.selectedLayerID == backgroundID)
        #expect(group.id != backgroundID)
    }

    @Test func moveToolSelectsTopmostVisibleOrdinaryLayerFromCanvas() throws {
        let viewModel = makeViewModel()
        let lowerImage = NSImage.rendered(size: CGSize(width: 120, height: 80)) { rect in
            NSColor.systemBlue.setFill()
            rect.fill()
        }
        var lower = ImageEditorLayer.blank(name: "Lower", size: CGSize(width: 120, height: 80))
        lower.image = try #require(lowerImage)
        lower.frame = CGRect(x: 100, y: 90, width: 120, height: 80)

        let upperImage = NSImage.rendered(size: CGSize(width: 120, height: 80)) { rect in
            NSColor.systemRed.setFill()
            rect.insetBy(dx: 20, dy: 20).fill()
        }
        var upper = ImageEditorLayer.blank(name: "Upper", size: CGSize(width: 120, height: 80))
        upper.image = try #require(upperImage)
        upper.frame = lower.frame

        viewModel.document.layers.append(lower)
        viewModel.document.layers.append(upper)
        viewModel.selectLayer(viewModel.document.layers.first!.id)
        let historyCount = viewModel.document.history.count

        #expect(viewModel.selectVisibleLayer(at: CGPoint(x: 160, y: 130)))
        #expect(viewModel.document.selectedLayerID == upper.id)
        #expect(viewModel.document.history.count == historyCount)

        #expect(viewModel.selectVisibleLayer(at: CGPoint(x: 105, y: 95)))
        #expect(viewModel.document.selectedLayerID == lower.id)
    }

    @Test func moveToolDoesNotSelectTransparentOrdinaryLayerOrComponentChildren() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        let componentGroup = try #require(viewModel.document.selectedLayer)
        let child = try #require(viewModel.document.layers.first { $0.groupID == componentGroup.id })

        viewModel.selectLayer(viewModel.document.layers.first!.id)
        #expect(!viewModel.selectVisibleLayer(at: CGPoint(x: 160, y: 112)))
        #expect(viewModel.document.selectedLayerID != child.id)

        var transparent = ImageEditorLayer.blank(name: "Transparent", size: CGSize(width: 240, height: 80))
        transparent.frame = CGRect(x: 80, y: 90, width: 240, height: 80)
        viewModel.document.layers.append(transparent)
        viewModel.selectLayer(transparent.id)
        #expect(!viewModel.selectVisibleLayer(at: CGPoint(x: 160, y: 112)))
        #expect(viewModel.document.selectedLayerID == transparent.id)
    }

    @Test func shiftCanvasSelectionAddsAndTogglesVisibleOrdinaryLayers() throws {
        let viewModel = makeViewModel()
        var first = ImageEditorLayer.solidColorFill(
            name: "First",
            size: CGSize(width: 80, height: 60),
            content: ImageEditorSolidColorFillContent(red: 0.1, green: 0.2, blue: 0.8)
        )
        first.frame.origin = CGPoint(x: 40, y: 40)
        var second = ImageEditorLayer.solidColorFill(
            name: "Second",
            size: CGSize(width: 80, height: 60),
            content: ImageEditorSolidColorFillContent(red: 0.8, green: 0.2, blue: 0.1)
        )
        second.frame.origin = CGPoint(x: 220, y: 140)
        viewModel.document.layers.append(first)
        viewModel.document.layers.append(second)
        viewModel.selectLayer(first.id)

        #expect(viewModel.selectVisibleLayer(at: CGPoint(x: 260, y: 160), extendingSelection: true))
        #expect(viewModel.document.selectedLayerIDs == Set([first.id, second.id]))
        #expect(viewModel.document.selectedLayerID == second.id)

        #expect(viewModel.selectVisibleLayer(at: CGPoint(x: 260, y: 160), extendingSelection: true))
        #expect(viewModel.document.selectedLayerIDs == [first.id])
        #expect(viewModel.document.selectedLayerID == first.id)
    }

    @Test func shiftCanvasSelectionAddsComponentObjectGroups() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 60, y: 80))
        let firstGroupID = try #require(viewModel.document.selectedLayerID)
        viewModel.insertXomoComponent(.avatar, at: CGPoint(x: 400, y: 260))
        let secondGroupID = try #require(viewModel.document.selectedLayerID)

        viewModel.selectLayer(firstGroupID)
        #expect(viewModel.selectXomoObject(at: CGPoint(x: 448, y: 308), extendingSelection: true))
        #expect(viewModel.document.selectedLayerIDs == Set([firstGroupID, secondGroupID]))
        #expect(viewModel.document.selectedLayerID == secondGroupID)
    }

    @Test func shiftSelectedComponentsUseACompositeSelectionFrame() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 60, y: 80))
        let firstFrame = try #require(viewModel.selectedXomoObjectFrame)
        let firstGroupID = try #require(viewModel.document.selectedLayerID)
        viewModel.insertXomoComponent(.avatar, at: CGPoint(x: 400, y: 260))
        let secondFrame = try #require(viewModel.selectedXomoObjectFrame)

        viewModel.selectLayer(firstGroupID)
        #expect(viewModel.selectXomoObject(at: CGPoint(x: secondFrame.midX, y: secondFrame.midY), extendingSelection: true))
        #expect(viewModel.selectedXomoObjectFrame == firstFrame.union(secondFrame))
        #expect(viewModel.hasSelectedXomoObject)
    }

    @Test func optionDragDuplicatesAndMovesAComponentAsOneUndoableAction() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        let originalGroupID = try #require(viewModel.document.selectedLayerID)
        let originalFrame = try #require(viewModel.selectedXomoObjectFrame)
        let historyCount = viewModel.document.history.count

        #expect(viewModel.beginDuplicatingSelectedLayerForMove())
        let duplicateGroupID = try #require(viewModel.document.selectedLayerID)
        #expect(duplicateGroupID != originalGroupID)
        viewModel.moveSelectedLayer(by: CGSize(width: 32, height: 18), snapping: false)
        viewModel.finishMovingSelectedLayer()

        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerDuplicate"))
        #expect(viewModel.selectedXomoObjectFrame?.minX == originalFrame.minX + 32)
        #expect(viewModel.selectedXomoObjectFrame?.minY == originalFrame.minY + 18)
        viewModel.undo()
        #expect(viewModel.document.layers.contains { $0.id == originalGroupID })
        #expect(!viewModel.document.layers.contains { $0.id == duplicateGroupID })
    }

    @Test func optionDragDuplicatesSelectedOrdinaryLayer() throws {
        let viewModel = makeViewModel()
        var layer = ImageEditorLayer.solidColorFill(
            name: "Card",
            size: CGSize(width: 96, height: 64),
            content: ImageEditorSolidColorFillContent(red: 0.2, green: 0.6, blue: 0.9)
        )
        layer.frame.origin = CGPoint(x: 120, y: 100)
        viewModel.document.layers.append(layer)
        viewModel.selectLayer(layer.id)
        let originalFrame = layer.frame

        #expect(viewModel.beginDuplicatingSelectedLayerForMove())
        let duplicateID = try #require(viewModel.document.selectedLayerID)
        #expect(duplicateID != layer.id)
        viewModel.moveSelectedLayer(by: CGSize(width: 24, height: 16), snapping: false)
        viewModel.finishMovingSelectedLayer()

        let duplicate = try #require(viewModel.document.layers.first { $0.id == duplicateID })
        #expect(duplicate.frame == originalFrame.offsetBy(dx: 24, dy: 16))
        #expect(viewModel.document.layers.contains { $0.id == layer.id })
    }

    @Test func optionDragDuplicatesOnlyTheDeepSelectedComponentChild() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        let group = try #require(viewModel.document.selectedLayer)
        let point = CGPoint(x: 160, y: 112)
        let target = try #require(
            viewModel.selectMoveToolDoubleClickTarget(at: point, hitTolerance: 0)
        )
        let originalFrames: [UUID: CGRect] = Dictionary(
            uniqueKeysWithValues: viewModel.document.layers.compactMap { layer in
                guard layer.groupID == group.id else { return nil }
                return (layer.id, layer.frame)
            }
        )
        let targetFrame = try #require(originalFrames[target.layerID])
        let historyCount = viewModel.document.history.count

        #expect(viewModel.prepareCanvasCloneMove(at: point))
        #expect(viewModel.document.selectedLayerID == target.layerID)
        #expect(viewModel.beginDuplicatingSelectedLayerForMove())
        let duplicate = try #require(viewModel.document.selectedLayer)
        #expect(duplicate.id != target.layerID)
        #expect(duplicate.groupID == group.id)
        #expect(!duplicate.isGroup)
        viewModel.moveSelectedLayer(by: CGSize(width: 24, height: 12), snapping: false)
        viewModel.finishMovingSelectedLayer()

        #expect(
            viewModel.document.layers.first { $0.id == duplicate.id }?.frame
                == targetFrame.offsetBy(dx: 24, dy: 12)
        )
        for (originalID, originalFrame) in originalFrames {
            #expect(viewModel.document.layers.first { $0.id == originalID }?.frame == originalFrame)
        }
        #expect(viewModel.document.layers.contains { $0.id == group.id })
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerDuplicate"))

        viewModel.undo()
        #expect(!viewModel.document.layers.contains { $0.id == duplicate.id })
        #expect(viewModel.document.layers.contains { $0.id == target.layerID })
        #expect(viewModel.document.layers.contains { $0.id == group.id })
    }

    @Test func componentModeClonePreparationStillSelectsTheWholeObject() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        let group = try #require(viewModel.document.selectedLayer)
        let point = CGPoint(x: 160, y: 112)
        let target = try #require(
            viewModel.selectMoveToolDoubleClickTarget(at: point, hitTolerance: 0)
        )
        #expect(viewModel.document.selectedLayerID == target.layerID)

        viewModel.selectLeftSidebarTab(.components)
        #expect(viewModel.prepareCanvasCloneMove(at: point))
        #expect(viewModel.document.selectedLayerID == group.id)
        #expect(viewModel.document.selectedLayerIDs == [group.id])
    }

    @Test func optionCloneGesturePreparesTheDeepTargetBeforeDuplicating() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let cloneStart = try #require(source.range(
            of: "let cloneDragDecision = ImageEditorObjectDragEventPolicy.cloneDragDecision("
        ))
        let cloneEnd = try #require(
            source[cloneStart.upperBound...].range(
                of: "if let extendsDeepSelection = ImageEditorObjectDragEventPolicy"
            )
        )
        let cloneSource = source[cloneStart.lowerBound..<cloneEnd.lowerBound]
        let activationGate = try #require(
            cloneSource.range(of: "if cloneDragDecision == .activate,")
        )
        let prepareCall = try #require(
            cloneSource.range(of: "viewModel.prepareCanvasCloneMove(")
        )
        let beginCall = try #require(
            cloneSource.range(of: "viewModel.beginDuplicatingSelectedLayerForMove()")
        )

        #expect(activationGate.lowerBound < prepareCall.lowerBound)
        #expect(prepareCall.lowerBound < beginCall.lowerBound)
        #expect(!cloneSource.contains("viewModel.selectMovableCanvasTarget("))
        #expect(cloneSource.contains("isCanvasCloneGestureActive = true"))
        #expect(cloneSource.contains("if cloneDragDecision != .unavailable,"))
        #expect(cloneSource.contains("// Option owns the whole pointer sequence"))
    }

    @Test func commandCanvasSelectionCanEnterAVisibleComponentChild() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        let group = try #require(viewModel.document.selectedLayer)
        let child = try #require(viewModel.document.layers.reversed().first { $0.groupID == group.id && !$0.isGroup })
        let backgroundID = try #require(viewModel.document.layers.first?.id)
        viewModel.selectLayer(backgroundID)

        #expect(viewModel.selectDeepestVisibleLayer(at: CGPoint(x: 160, y: 112)))
        #expect(viewModel.document.selectedLayerID == child.id)
        #expect(viewModel.document.selectedLayer?.groupID == group.id)
        #expect(viewModel.document.selectedLayerID != group.id)
    }

    @Test func moveToolDoubleClickEntersTheForegroundComponentChild() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        let group = try #require(viewModel.document.selectedLayer)
        let textLayer = try #require(viewModel.document.layers.first {
            $0.groupID == group.id && $0.isText
        })
        let textPoint = CGPoint(x: textLayer.frame.midX, y: textLayer.frame.midY)

        #expect(
            viewModel.moveToolDoubleClickTarget(at: textPoint, hitTolerance: 0)
                == .editableText(textLayer.id)
        )
        #expect(viewModel.document.selectedLayerID == group.id)
        #expect(
            viewModel.selectMoveToolDoubleClickTarget(at: textPoint, hitTolerance: 0)
                == .editableText(textLayer.id)
        )
        #expect(viewModel.document.selectedLayerID == textLayer.id)

        let backgroundPoint = CGPoint(x: 88, y: 98)
        let backgroundTarget = try #require(
            viewModel.moveToolDoubleClickTarget(at: backgroundPoint, hitTolerance: 0)
        )
        #expect(backgroundTarget.layerID != group.id)
        #expect(backgroundTarget.layerID != textLayer.id)
        #expect(viewModel.selectMoveToolDoubleClickTarget(at: backgroundPoint) == backgroundTarget)
        #expect(viewModel.document.selectedLayerID == backgroundTarget.layerID)
        #expect(viewModel.document.selectedLayer?.groupID == group.id)
    }

    @Test func foregroundCoverPreventsDoubleClickFromEditingTextUnderneath() throws {
        let viewModel = makeViewModel()
        viewModel.textValue = "Covered text"
        viewModel.addText(at: CGPoint(x: 120, y: 110))
        let textLayer = try #require(viewModel.document.selectedLayer)
        let hitPoint = CGPoint(x: textLayer.frame.midX, y: textLayer.frame.midY)
        var cover = ImageEditorLayer.solidColorFill(
            name: "Cover",
            size: textLayer.frame.size,
            content: ImageEditorSolidColorFillContent(red: 0.1, green: 0.2, blue: 0.3)
        )
        cover.frame = textLayer.frame
        viewModel.document.layers.append(cover)
        viewModel.selectLayer(textLayer.id)

        #expect(
            viewModel.moveToolDoubleClickTarget(at: hitPoint, hitTolerance: 0)
                == .layer(cover.id)
        )
        #expect(viewModel.document.selectedLayerID == textLayer.id)
        #expect(
            viewModel.selectMoveToolDoubleClickTarget(at: hitPoint, hitTolerance: 0)
                == .layer(cover.id)
        )
        #expect(viewModel.document.selectedLayerID == cover.id)
    }

    @Test func transparentForegroundLayerDoesNotStealTextDoubleClick() throws {
        let viewModel = makeViewModel()
        viewModel.textValue = "Visible text"
        viewModel.addText(at: CGPoint(x: 120, y: 110))
        let textLayer = try #require(viewModel.document.selectedLayer)
        let hitPoint = CGPoint(x: textLayer.frame.midX, y: textLayer.frame.midY)
        var transparentLayer = ImageEditorLayer.blank(
            name: "Transparent cover",
            size: textLayer.frame.size
        )
        transparentLayer.frame = textLayer.frame
        viewModel.document.layers.append(transparentLayer)

        #expect(
            viewModel.moveToolDoubleClickTarget(at: hitPoint, hitTolerance: 0)
                == .editableText(textLayer.id)
        )
    }

    @Test func toolsModeDragsADeepSelectedComponentChildInsteadOfItsWholeObject() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        let group = try #require(viewModel.document.selectedLayer)
        let hitPoint = CGPoint(x: 160, y: 112)
        let target = try #require(
            viewModel.selectMoveToolDoubleClickTarget(at: hitPoint, hitTolerance: 0)
        )
        let targetID = target.layerID
        let targetFrame = try #require(
            viewModel.document.layers.first { $0.id == targetID }?.frame
        )
        let siblingFrames: [UUID: CGRect] = Dictionary(
            uniqueKeysWithValues: viewModel.document.layers.compactMap { layer in
                guard layer.groupID == group.id, layer.id != targetID else { return nil }
                return (layer.id, layer.frame)
            }
        )

        #expect(viewModel.hasMovableDeepSelectedCanvasLayer(at: hitPoint))
        #expect(viewModel.prepareCanvasObjectMove(at: hitPoint))
        #expect(viewModel.document.selectedLayerID == targetID)
        #expect(viewModel.beginMovingSelectedLayer())
        viewModel.moveSelectedLayer(by: CGSize(width: 18, height: 9), snapping: false)
        viewModel.finishMovingSelectedLayer()

        #expect(
            viewModel.document.layers.first { $0.id == targetID }?.frame
                == targetFrame.offsetBy(dx: 18, dy: 9)
        )
        for (siblingID, siblingFrame) in siblingFrames {
            #expect(viewModel.document.layers.first { $0.id == siblingID }?.frame == siblingFrame)
        }
        #expect(viewModel.document.layers.contains { $0.id == group.id })
        #expect(viewModel.document.selectedLayerID == targetID)
    }

    @Test func deepSelectedLayerDragRequiresTheFrontmostEditablePixelAndToolsMode() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        let group = try #require(viewModel.document.selectedLayer)
        let hitPoint = CGPoint(x: 160, y: 112)
        let target = try #require(
            viewModel.selectMoveToolDoubleClickTarget(at: hitPoint, hitTolerance: 0)
        )
        let targetID = target.layerID

        var transparentLayer = ImageEditorLayer.blank(
            name: "Transparent",
            size: CGSize(width: 80, height: 40)
        )
        transparentLayer.frame = CGRect(x: 120, y: 92, width: 80, height: 40)
        viewModel.document.layers.append(transparentLayer)
        #expect(viewModel.hasMovableDeepSelectedCanvasLayer(at: hitPoint))

        var cover = ImageEditorLayer.solidColorFill(
            name: "Cover",
            size: CGSize(width: 80, height: 40),
            content: ImageEditorSolidColorFillContent(red: 0.8, green: 0.2, blue: 0.1)
        )
        cover.frame = transparentLayer.frame
        viewModel.document.layers.append(cover)
        #expect(!viewModel.hasMovableDeepSelectedCanvasLayer(at: hitPoint))

        viewModel.document.layers.removeAll { $0.id == cover.id || $0.id == transparentLayer.id }
        let targetIndex = try #require(
            viewModel.document.layers.firstIndex { $0.id == targetID }
        )
        viewModel.document.layers[targetIndex].locksPosition = true
        #expect(!viewModel.hasMovableDeepSelectedCanvasLayer(at: hitPoint))

        viewModel.document.layers[targetIndex].locksPosition = false
        viewModel.selectLeftSidebarTab(.components)
        #expect(!viewModel.hasMovableDeepSelectedCanvasLayer(at: hitPoint))
        #expect(viewModel.prepareCanvasObjectMove(at: hitPoint))
        #expect(viewModel.document.selectedLayerID == group.id)
    }

    @Test func disablingMoveAutoSelectMovesTheCurrentObjectFromBlankCanvas() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 70, y: 80))
        let firstID = try #require(viewModel.document.selectedLayerID)
        let firstFrame = try #require(viewModel.selectedLayerTransformFrame)
        viewModel.insertXomoComponent(.card, at: CGPoint(x: 330, y: 210))
        let secondID = try #require(viewModel.document.selectedLayerID)
        let secondFrame = try #require(viewModel.selectedLayerTransformFrame)
        viewModel.selectLayer(firstID)
        viewModel.isMoveToolAutoSelectEnabled = false
        let blankPoint = CGPoint(x: 620, y: 460)

        #expect(!viewModel.moveToolAutoSelectsCanvasTarget)
        #expect(viewModel.moveToolContentHit(at: blankPoint) == .movable)
        #expect(viewModel.canBeginCanvasObjectMove(at: blankPoint))
        #expect(viewModel.prepareCanvasObjectMove(at: CGPoint(
            x: secondFrame.midX,
            y: secondFrame.midY
        )))
        #expect(viewModel.document.selectedLayerID == firstID)
        #expect(viewModel.beginMovingSelectedLayer())
        viewModel.moveSelectedLayer(by: CGSize(width: 18, height: 9), snapping: false)
        viewModel.finishMovingSelectedLayer()

        #expect(viewModel.selectedLayerTransformFrame == firstFrame.offsetBy(dx: 18, dy: 9))
        viewModel.selectLayer(secondID)
        #expect(viewModel.selectedLayerTransformFrame == secondFrame)
        viewModel.selectLayer(firstID)
        viewModel.toggleLayerPositionLock(firstID)
        #expect(viewModel.moveToolContentHit(at: blankPoint) == .blocked)
        #expect(!viewModel.canBeginCanvasObjectMove(at: blankPoint))
    }

    @Test func disablingMoveAutoSelectOptionCopiesTheCurrentObjectNotTheHoveredOne() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 70, y: 80))
        let firstID = try #require(viewModel.document.selectedLayerID)
        viewModel.insertXomoComponent(.card, at: CGPoint(x: 330, y: 210))
        let secondID = try #require(viewModel.document.selectedLayerID)
        let secondFrame = try #require(viewModel.selectedLayerTransformFrame)
        viewModel.selectLayer(firstID)
        viewModel.isMoveToolAutoSelectEnabled = false
        let initialLayerIDs = viewModel.document.layers.map(\.id)

        #expect(viewModel.prepareCanvasCloneMove(at: CGPoint(
            x: secondFrame.midX,
            y: secondFrame.midY
        )))
        #expect(viewModel.document.selectedLayerID == firstID)
        #expect(viewModel.beginDuplicatingSelectedLayerForMove())
        #expect(viewModel.document.selectedLayerID != firstID)
        #expect(viewModel.document.selectedLayerID != secondID)
        #expect(viewModel.cancelMovingSelectedLayer())
        #expect(viewModel.document.layers.map(\.id) == initialLayerIDs)
        #expect(viewModel.document.selectedLayerID == firstID)
    }

    @Test func componentModeIgnoresTheMoveToolAutoSelectLock() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 70, y: 80))
        let firstID = try #require(viewModel.document.selectedLayerID)
        viewModel.insertXomoComponent(.card, at: CGPoint(x: 330, y: 210))
        let secondID = try #require(viewModel.document.selectedLayerID)
        let secondFrame = try #require(viewModel.selectedLayerTransformFrame)
        viewModel.selectLayer(firstID)
        viewModel.isMoveToolAutoSelectEnabled = false
        viewModel.selectLeftSidebarTab(.components)

        #expect(viewModel.moveToolAutoSelectsCanvasTarget)
        #expect(viewModel.prepareCanvasFallbackMove(at: CGPoint(
            x: secondFrame.midX,
            y: secondFrame.midY
        )))
        #expect(viewModel.document.selectedLayerID == secondID)
        #expect(viewModel.document.selectedLayerIDs == [secondID])
    }

    @Test func moveAutoSelectGroupTargetsTheOutermostContainerAndItsLockClosure() throws {
        let viewModel = makeViewModel()
        var leaf = ImageEditorLayer.solidColorFill(
            name: "Leaf",
            size: CGSize(width: 80, height: 60),
            content: ImageEditorSolidColorFillContent(red: 0.2, green: 0.7, blue: 0.4)
        )
        leaf.frame = CGRect(x: 120, y: 100, width: 80, height: 60)
        var innerGroup = ImageEditorLayer.group(
            name: "Inner",
            size: viewModel.document.canvasSize
        )
        let outerGroup = ImageEditorLayer.group(
            name: "Outer",
            size: viewModel.document.canvasSize
        )
        var lockedSibling = ImageEditorLayer.solidColorFill(
            name: "Locked sibling",
            size: CGSize(width: 40, height: 40),
            content: ImageEditorSolidColorFillContent(red: 0.8, green: 0.2, blue: 0.2)
        )
        lockedSibling.frame = CGRect(x: 260, y: 180, width: 40, height: 40)
        leaf.groupID = innerGroup.id
        innerGroup.groupID = outerGroup.id
        lockedSibling.groupID = outerGroup.id
        lockedSibling.locksPosition = true
        viewModel.document.layers = [leaf, innerGroup, lockedSibling, outerGroup]
        let point = CGPoint(x: leaf.frame.midX, y: leaf.frame.midY)

        #expect(viewModel.moveToolAutoSelectTarget == .group)
        #expect(viewModel.moveToolAutoSelectLayer(at: point)?.id == outerGroup.id)
        #expect(viewModel.moveToolContentHit(at: point) == .blocked)
        #expect(viewModel.selectMovableCanvasTarget(at: point))
        #expect(viewModel.document.selectedLayerID == outerGroup.id)

        viewModel.moveToolAutoSelectTarget = .layer
        #expect(viewModel.moveToolAutoSelectLayer(at: point)?.id == leaf.id)
        #expect(viewModel.moveToolContentHit(at: point) == .movable)
        #expect(viewModel.selectMovableCanvasTarget(at: point))
        #expect(viewModel.document.selectedLayerID == leaf.id)
    }

    @Test func moveAutoSelectScopeDrillsIntoComponentsOnlyInToolsMode() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        let groupID = try #require(viewModel.document.selectedLayerID)
        let point = CGPoint(x: 160, y: 112)
        let backgroundID = try #require(viewModel.document.layers.first?.id)
        viewModel.selectLayer(backgroundID)

        viewModel.moveToolAutoSelectTarget = .group
        #expect(viewModel.selectMovableCanvasTarget(at: point))
        #expect(viewModel.document.selectedLayerID == groupID)

        viewModel.selectLayer(backgroundID)
        viewModel.moveToolAutoSelectTarget = .layer
        #expect(viewModel.selectMovableCanvasTarget(at: point))
        let child = try #require(viewModel.document.selectedLayer)
        #expect(!child.isGroup)
        #expect(child.groupID == groupID)

        viewModel.selectLayer(backgroundID)
        viewModel.selectLeftSidebarTab(.components)
        #expect(viewModel.selectMovableCanvasTarget(at: point))
        #expect(viewModel.document.selectedLayerID == groupID)
        #expect(viewModel.document.selectedLayerIDs == [groupID])
    }

    @Test func nativeObjectDragUsesTheSharedAutoSelectPolicyBeforeMoving() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let candidateStart = try #require(
            source.range(of: "onObjectMoveCandidateBegan: { location, modifierFlags, clickCount in")
        )
        let activationStart = try #require(
            source[candidateStart.upperBound...].range(of: "onObjectMoveActivated:")
        )
        let changedStart = try #require(
            source[activationStart.upperBound...].range(of: "onObjectMoveChanged:")
        )
        let candidateSource = source[candidateStart.lowerBound..<activationStart.lowerBound]
        let activationSource = source[activationStart.lowerBound..<changedStart.lowerBound]

        #expect(candidateSource.contains("viewModel.canBeginCanvasObjectMove("))
        #expect(!candidateSource.contains("viewModel.hasMovableDeepSelectedCanvasLayer("))
        #expect(!candidateSource.contains("viewModel.hasXomoObject("))
        #expect(activationSource.contains("viewModel.prepareCanvasObjectMove("))
        #expect(!activationSource.contains("viewModel.prepareXomoObjectMove("))
        #expect(activationSource.contains("viewModel.beginMovingSelectedLayer()"))
        #expect(source.contains("guard viewModel.moveToolAutoSelectsCanvasTarget else { return }"))
        #expect(source.contains("if viewModel.moveToolAutoSelectsCanvasTarget,"))
        #expect(source.contains("viewModel.prepareCanvasFallbackMove("))
        #expect(source.components(separatedBy: "viewModel.moveToolContentHit(at:").count == 5)
    }

    @Test func commandShiftCanvasSelectionAddsAVisibleComponentChild() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        let group = try #require(viewModel.document.selectedLayer)
        let child = try #require(viewModel.document.layers.reversed().first {
            $0.groupID == group.id && !$0.isGroup
        })
        let backgroundID = try #require(viewModel.document.layers.first?.id)
        viewModel.selectLayer(backgroundID)

        #expect(viewModel.selectDeepestVisibleLayer(
            at: CGPoint(x: 160, y: 112),
            extendingSelection: true
        ))
        #expect(viewModel.document.selectedLayerID == child.id)
        #expect(viewModel.document.selectedLayerIDs.contains(backgroundID))
        #expect(viewModel.document.selectedLayerIDs.contains(child.id))
        #expect(viewModel.document.selectedLayerIDs.count == 2)
    }

    @Test func topmostOverlappingComponentWinsObjectHitTesting() throws {
        let viewModel = makeViewModel()
        let origin = CGPoint(x: 80, y: 90)
        viewModel.insertXomoComponent(.button, at: origin)
        let firstObject = try #require(viewModel.document.selectedLayer)
        viewModel.insertXomoComponent(.secondaryButton, at: origin)
        let secondObject = try #require(viewModel.document.selectedLayer)

        #expect(viewModel.selectXomoObject(at: CGPoint(x: 160, y: 112)))
        #expect(viewModel.document.selectedLayerID == secondObject.id)
        #expect(viewModel.document.selectedLayerID != firstObject.id)
    }

    @Test func componentMovePreparationSwitchesFromSelectedBackObjectToFrontObject() throws {
        let viewModel = makeViewModel()
        let origin = CGPoint(x: 80, y: 90)
        viewModel.insertXomoComponent(.button, at: origin)
        let backObject = try #require(viewModel.document.selectedLayer)
        viewModel.insertXomoComponent(.secondaryButton, at: origin)
        let frontObject = try #require(viewModel.document.selectedLayer)
        viewModel.selectLayer(backObject.id)

        #expect(viewModel.prepareXomoObjectMove(at: CGPoint(x: 160, y: 112)))
        #expect(viewModel.document.selectedLayerID == frontObject.id)
        #expect(viewModel.document.selectedLayerID != backObject.id)
    }

    @Test func componentMovePreparationPreservesAnExistingMultiSelection() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        let firstObject = try #require(viewModel.document.selectedLayer)
        viewModel.insertXomoComponent(.avatar, at: CGPoint(x: 420, y: 260))
        let secondObject = try #require(viewModel.document.selectedLayer)
        #expect(viewModel.selectXomoObject(
            at: CGPoint(x: 160, y: 112),
            extendingSelection: true
        ))
        let selectionBeforeMove = viewModel.document.selectedLayerIDs
        #expect(selectionBeforeMove == [firstObject.id, secondObject.id])

        #expect(viewModel.prepareXomoObjectMove(at: CGPoint(x: 468, y: 308)))
        #expect(viewModel.document.selectedLayerIDs == selectionBeforeMove)
    }

    @Test func shiftClickTogglesAComponentWithoutCollapsingTheExistingSelection() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        let firstObject = try #require(viewModel.document.selectedLayer)
        viewModel.insertXomoComponent(.avatar, at: CGPoint(x: 420, y: 260))
        let secondObject = try #require(viewModel.document.selectedLayer)

        #expect(viewModel.selectXomoObject(
            at: CGPoint(x: 160, y: 112),
            extendingSelection: true
        ))
        #expect(viewModel.document.selectedLayerIDs == [firstObject.id, secondObject.id])

        #expect(viewModel.selectXomoObject(
            at: CGPoint(x: 468, y: 308),
            extendingSelection: true
        ))
        #expect(viewModel.document.selectedLayerIDs == [firstObject.id])
        #expect(viewModel.document.selectedLayerID == firstObject.id)
    }

    @Test func pixelLockedComponentCanMoveWithoutAllowingContentResampling() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        let groupID = try #require(viewModel.document.selectedLayerID)
        viewModel.document.layers = viewModel.document.layers.map { layer in
            guard layer.id == groupID else { return layer }
            var pixelLocked = layer
            pixelLocked.locksPixels = true
            return pixelLocked
        }
        let initialFrame = try #require(viewModel.selectedXomoObjectFrame)

        #expect(viewModel.canMoveSelectedLayer)
        #expect(!viewModel.canResizeSelectedLayer)
        #expect(!viewModel.canRotateSelectedLayer)
        #expect(viewModel.beginMovingSelectedLayer())
        viewModel.moveSelectedLayer(by: CGSize(width: 12, height: 8), snapping: false)
        viewModel.finishMovingSelectedLayer()
        #expect(viewModel.selectedXomoObjectFrame == initialFrame.offsetBy(dx: 12, dy: 8))
    }

    @Test func switchingObjectsUpdatesKindAndBoundsImmediately() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 40, y: 60))
        let buttonID = try #require(viewModel.document.selectedLayerID)
        let buttonFrame = try #require(viewModel.selectedXomoObjectFrame)
        viewModel.insertXomoComponent(.avatar, at: CGPoint(x: 420, y: 260))
        let avatarID = try #require(viewModel.document.selectedLayerID)

        #expect(viewModel.selectXomoObject(at: CGPoint(x: buttonFrame.midX, y: buttonFrame.midY)))
        #expect(viewModel.document.selectedLayerID == buttonID)
        #expect(viewModel.selectedXomoObjectKind == .button)
        #expect(viewModel.selectedXomoObjectFrame == buttonFrame)

        #expect(viewModel.selectXomoObject(at: CGPoint(x: 468, y: 308)))
        #expect(viewModel.document.selectedLayerID == avatarID)
        #expect(viewModel.selectedXomoObjectKind == .avatar)
        #expect(viewModel.selectedXomoObjectFrame == CGRect(x: 420, y: 260, width: 96, height: 96))
    }

    @Test func componentsTabSwitchesToAnotherObjectBeforeDragging() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        let firstObjectID = try #require(viewModel.document.selectedLayerID)
        viewModel.insertXomoComponent(.avatar, at: CGPoint(x: 420, y: 260))
        let secondObjectID = try #require(viewModel.document.selectedLayerID)
        viewModel.selectLayer(firstObjectID)
        viewModel.selectLeftSidebarTab(.components)

        #expect(viewModel.selectXomoObject(at: CGPoint(x: 468, y: 308)))
        #expect(viewModel.document.selectedLayerID == secondObjectID)
        #expect(viewModel.selectedXomoObjectKind == .avatar)
        #expect(viewModel.canvasInteractionTool == .move)
    }

    @Test func selectingComponentGroupUsesFastSelectionPath() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        let group = try #require(viewModel.document.selectedLayer)
        let background = try #require(viewModel.document.layers.first)

        viewModel.selectLayer(background.id)
        #expect(viewModel.selectXomoObject(at: CGPoint(x: 160, y: 112)))
        #expect(viewModel.document.selectedLayerID == group.id)
        #expect(viewModel.document.selectedLayerIDs == [group.id])
        #expect(!viewModel.isEditingLayerMask)
    }

    @Test func coveredComponentDoesNotClaimTheClick() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        let group = try #require(viewModel.document.selectedLayer)
        let coverContent = ImageEditorSolidColorFillContent(red: 0, green: 0, blue: 0)
        var cover = ImageEditorLayer.solidColorFill(
            name: "Cover",
            size: CGSize(width: 240, height: 80),
            content: coverContent
        )
        cover.frame = CGRect(x: 80, y: 90, width: 240, height: 80)
        viewModel.document.layers.append(cover)
        viewModel.selectLayer(cover.id)

        #expect(!viewModel.selectXomoObject(at: CGPoint(x: 160, y: 112)))
        #expect(viewModel.document.selectedLayerID == cover.id)
        #expect(viewModel.document.selectedLayerID != group.id)
    }

    @Test func transparentLayerDoesNotBlockComponentObjectHitTesting() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        let group = try #require(viewModel.document.selectedLayer)
        var transparentLayer = ImageEditorLayer.blank(name: "Empty", size: CGSize(width: 240, height: 80))
        transparentLayer.frame = CGRect(x: 80, y: 90, width: 240, height: 80)
        viewModel.document.layers.append(transparentLayer)
        viewModel.selectLayer(transparentLayer.id)

        #expect(viewModel.selectXomoObject(at: CGPoint(x: 160, y: 112)))
        #expect(viewModel.document.selectedLayerID == group.id)
    }

    @Test func transparentPixelHoleDoesNotBlockComponentObjectHitTesting() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        let group = try #require(viewModel.document.selectedLayer)
        let sparseImage = NSImage.rendered(size: CGSize(width: 240, height: 80)) { rect in
            NSColor.systemRed.setFill()
            rect.insetBy(dx: 0, dy: 20).fill()
        }
        var sparseLayer = ImageEditorLayer.blank(name: "Sparse", size: CGSize(width: 240, height: 80))
        sparseLayer.image = sparseImage ?? NSImage.transparent(size: CGSize(width: 240, height: 80))
        sparseLayer.frame = CGRect(x: 80, y: 90, width: 240, height: 80)
        viewModel.document.layers.append(sparseLayer)
        viewModel.selectLayer(sparseLayer.id)

        #expect(viewModel.selectXomoObject(at: CGPoint(x: 160, y: 95)))
        #expect(viewModel.document.selectedLayerID == group.id)
    }

    @Test func repeatedPixelHitTestingKeepsTransparentHoleSemantics() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        let group = try #require(viewModel.document.selectedLayer)
        let sparseImage = NSImage.rendered(size: CGSize(width: 240, height: 80)) { rect in
            NSColor.systemRed.setFill()
            rect.insetBy(dx: 0, dy: 20).fill()
        }
        var sparseLayer = ImageEditorLayer.blank(name: "Sparse", size: CGSize(width: 240, height: 80))
        sparseLayer.image = sparseImage ?? NSImage.transparent(size: CGSize(width: 240, height: 80))
        sparseLayer.frame = CGRect(x: 80, y: 90, width: 240, height: 80)
        viewModel.document.layers.append(sparseLayer)
        viewModel.selectLayer(sparseLayer.id)

        for _ in 0..<12 {
            #expect(viewModel.selectXomoObject(at: CGPoint(x: 160, y: 95)))
            #expect(viewModel.document.selectedLayerID == group.id)
            viewModel.selectLayer(sparseLayer.id)
        }
    }

    @Test func deletingASelectedObjectRemovesItsGroupAndChildren() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        let group = try #require(viewModel.document.selectedLayer)
        let childIDs = Set(viewModel.document.layers.filter { $0.groupID == group.id }.map(\.id))

        #expect(viewModel.deleteSelectedXomoObjectIfNeeded())
        #expect(!viewModel.document.layers.contains { $0.id == group.id })
        #expect(!viewModel.document.layers.contains { childIDs.contains($0.id) })
    }

    @Test func deleteWaitsForAnActivePointerMoveToFinishOrCancel() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        let group = try #require(viewModel.document.selectedLayer)
        let initialHistoryCount = viewModel.document.history.count
        let initialUndoCount = viewModel.undoStack.count

        #expect(viewModel.beginMovingSelectedLayer())
        viewModel.moveSelectedLayer(by: CGSize(width: 16, height: 8), snapping: false)
        #expect(viewModel.hasActiveLayerMoveTransaction)
        #expect(!viewModel.deleteSelectedXomoObjectIfNeeded())
        #expect(viewModel.document.layers.contains { $0.id == group.id })
        #expect(viewModel.document.history.count == initialHistoryCount)
        #expect(viewModel.undoStack.count == initialUndoCount + 1)

        #expect(viewModel.cancelMovingSelectedLayer())
        #expect(!viewModel.hasActiveLayerMoveTransaction)
        #expect(viewModel.deleteSelectedXomoObjectIfNeeded())
        #expect(!viewModel.document.layers.contains { $0.id == group.id })
    }

    @Test func movingAnObjectPublishesAndClearsItsDashedPreviewFrame() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        let initialFrame = try #require(viewModel.selectedLayerTransformFrame)

        viewModel.beginMovingSelectedLayer()
        viewModel.moveSelectedLayer(by: CGSize(width: 18, height: 12), snapping: false)

        let preview = try #require(viewModel.movingObjectPreviewFrame)
        #expect(preview.minX == initialFrame.minX + 18)
        #expect(preview.minY == initialFrame.minY + 12)
        #expect(viewModel.selectedLayerTransformFrame == initialFrame)

        viewModel.finishMovingSelectedLayer()
        #expect(viewModel.movingObjectPreviewFrame == nil)
        #expect(viewModel.selectedLayerTransformFrame?.minX == initialFrame.minX + 18)
        #expect(viewModel.selectedLayerTransformFrame?.minY == initialFrame.minY + 12)
    }

    @Test func repeatedDragUpdatesAccumulateInThePreviewBeforeCommit() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        let initialFrame = try #require(viewModel.selectedLayerTransformFrame)

        viewModel.beginMovingSelectedLayer()
        viewModel.moveSelectedLayer(by: CGSize(width: 4, height: 3), snapping: false)
        viewModel.moveSelectedLayer(by: CGSize(width: 6, height: 2), snapping: false)

        #expect(viewModel.movingObjectPreviewFrame?.minX == initialFrame.minX + 10)
        #expect(viewModel.movingObjectPreviewFrame?.minY == initialFrame.minY + 5)
        #expect(viewModel.selectedLayerTransformFrame == initialFrame)

        viewModel.finishMovingSelectedLayer()
        #expect(viewModel.selectedLayerTransformFrame?.minX == initialFrame.minX + 10)
        #expect(viewModel.selectedLayerTransformFrame?.minY == initialFrame.minY + 5)
    }

    @Test func cancellingAnObjectDragDiscardsPreviewWithoutHistoryOrPositionChange() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        let initialFrame = try #require(viewModel.selectedLayerTransformFrame)
        let initialHistoryCount = viewModel.document.history.count
        let initialUndoCount = viewModel.undoStack.count

        viewModel.beginMovingSelectedLayer()
        viewModel.moveSelectedLayer(by: CGSize(width: 28, height: 16), snapping: false)
        #expect(viewModel.movingObjectPreviewFrame?.minX == initialFrame.minX + 28)

        #expect(viewModel.cancelMovingSelectedLayer())
        #expect(viewModel.selectedLayerTransformFrame == initialFrame)
        #expect(viewModel.movingObjectPreviewFrame == nil)
        #expect(viewModel.document.history.count == initialHistoryCount)
        #expect(viewModel.undoStack.count == initialUndoCount)
        #expect(viewModel.cancelMovingSelectedLayer() == false)
    }

    @Test func keyboardNudgeDoesNotCommitAnActivePointerMove() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        let initialFrame = try #require(viewModel.selectedLayerTransformFrame)
        let initialHistoryCount = viewModel.document.history.count
        let initialUndoCount = viewModel.undoStack.count

        #expect(viewModel.beginMovingSelectedLayer())
        viewModel.moveSelectedLayer(by: CGSize(width: 24, height: 12), snapping: false)
        let pointerPreview = try #require(viewModel.movingObjectPreviewFrame)

        viewModel.nudgeSelectionOrSelectedLayer(by: CGSize(width: 5, height: 0))

        #expect(viewModel.movingObjectPreviewFrame == pointerPreview)
        #expect(viewModel.selectedLayerTransformFrame == initialFrame)
        #expect(viewModel.document.history.count == initialHistoryCount)
        #expect(viewModel.undoStack.count == initialUndoCount + 1)
        #expect(viewModel.cancelMovingSelectedLayer())
        #expect(viewModel.selectedLayerTransformFrame == initialFrame)
    }

    @Test func undoAndRedoFirstCancelAnActivePointerMove() throws {
        for performHistoryCommand in [
            { (viewModel: ImageEditorViewModel) in viewModel.undo() },
            { (viewModel: ImageEditorViewModel) in viewModel.redo() }
        ] {
            let viewModel = makeViewModel()
            viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
            let initialFrame = try #require(viewModel.selectedLayerTransformFrame)
            let initialHistoryCount = viewModel.document.history.count
            let initialUndoCount = viewModel.undoStack.count

            #expect(viewModel.beginMovingSelectedLayer())
            viewModel.moveSelectedLayer(by: CGSize(width: 20, height: 10), snapping: false)
            #expect(viewModel.hasActiveLayerMoveTransaction)

            performHistoryCommand(viewModel)

            #expect(!viewModel.hasActiveLayerMoveTransaction)
            #expect(viewModel.movingObjectPreviewFrame == nil)
            #expect(viewModel.selectedLayerTransformFrame == initialFrame)
            #expect(viewModel.document.history.count == initialHistoryCount)
            #expect(viewModel.undoStack.count == initialUndoCount)
        }
    }

    @Test func cancellingAnOptionDragRemovesThePendingDuplicate() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        let initialLayerIDs = viewModel.document.layers.map(\.id)
        let initialSelectionID = try #require(viewModel.document.selectedLayerID)
        let initialHistoryCount = viewModel.document.history.count
        let initialUndoCount = viewModel.undoStack.count

        #expect(viewModel.beginDuplicatingSelectedLayerForMove())
        #expect(viewModel.document.layers.map(\.id) != initialLayerIDs)
        viewModel.moveSelectedLayer(by: CGSize(width: 24, height: 12), snapping: false)

        #expect(viewModel.cancelMovingSelectedLayer())
        #expect(viewModel.document.layers.map(\.id) == initialLayerIDs)
        #expect(viewModel.document.selectedLayerID == initialSelectionID)
        #expect(viewModel.document.history.count == initialHistoryCount)
        #expect(viewModel.undoStack.count == initialUndoCount)
        #expect(viewModel.movingObjectPreviewFrame == nil)
    }

    @Test func selectingAnotherObjectKeepsTheCompositeImageCache() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        let objectID = try #require(viewModel.document.selectedLayerID)
        let cachedImage = viewModel.currentImage
        let backgroundID = try #require(viewModel.document.layers.first?.id)

        viewModel.selectLayer(backgroundID)
        viewModel.selectLayer(objectID)

        #expect(viewModel.currentImage === cachedImage)
    }

    @Test func objectPreviewSnapsBeforeTheRealLayersCommit() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        let initialFrame = try #require(viewModel.selectedLayerTransformFrame)
        let initialChildFrames = Dictionary(uniqueKeysWithValues: viewModel.document.layers.compactMap { layer in
            layer.groupID == viewModel.document.selectedLayerID ? (layer.id, layer.frame) : nil
        })
        viewModel.addGuide(.vertical, at: initialFrame.maxX + 20)

        viewModel.beginMovingSelectedLayer()
        viewModel.moveSelectedLayer(by: CGSize(width: 18, height: 0), snapping: true)

        #expect(viewModel.movingObjectPreviewFrame?.maxX == initialFrame.maxX + 20)
        #expect(viewModel.activeAlignmentGuides.contains {
            $0.orientation == .vertical && $0.position == initialFrame.maxX + 20
        })
        for layer in viewModel.document.layers {
            if let initialChildFrame = initialChildFrames[layer.id] {
                #expect(layer.frame == initialChildFrame)
            }
        }

        viewModel.finishMovingSelectedLayer()
        #expect(viewModel.selectedXomoObjectFrame?.maxX == initialFrame.maxX + 20)
    }

    @Test func componentMovementSnapsToCanvasCenterGuides() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 100, y: 100))
        let initialFrame = try #require(viewModel.selectedXomoObjectFrame)
        let deltaToNearCanvasCenter = CGSize(
            width: viewModel.document.canvasSize.width * 0.5 - initialFrame.maxX - 3,
            height: 0
        )

        viewModel.beginMovingSelectedLayer()
        viewModel.moveSelectedLayer(by: deltaToNearCanvasCenter, snapping: true)

        #expect(viewModel.movingObjectPreviewFrame?.maxX == viewModel.document.canvasSize.width * 0.5)
        #expect(viewModel.activeAlignmentGuides.contains {
            $0.orientation == .vertical
                && $0.position == viewModel.document.canvasSize.width * 0.5
        })

        viewModel.finishMovingSelectedLayer()
        #expect(viewModel.selectedXomoObjectFrame?.maxX == viewModel.document.canvasSize.width * 0.5)
    }

    @Test func horizontalDragConstraintIgnoresCrossAxisSnapCorrection() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 100, y: 100))
        let initialFrame = try #require(viewModel.selectedXomoObjectFrame)
        viewModel.addGuide(.vertical, at: initialFrame.maxX + 20)
        viewModel.addGuide(.horizontal, at: initialFrame.minY + 2)

        viewModel.beginMovingSelectedLayer()
        viewModel.moveSelectedLayer(
            by: CGSize(width: 18, height: 0),
            snapping: true,
            constrainingTo: .horizontal
        )

        #expect(viewModel.movingObjectPreviewFrame?.maxX == initialFrame.maxX + 20)
        #expect(viewModel.movingObjectPreviewFrame?.minY == initialFrame.minY)
        #expect(viewModel.activeAlignmentGuides == [
            ImageEditorAlignmentGuide(
                orientation: .vertical,
                position: initialFrame.maxX + 20
            )
        ])
    }

    @Test func transformInspectorMovesSelectedLayerWithUndoHistory() throws {
        let viewModel = makeViewModel()
        var layer = ImageEditorLayer.solidColorFill(
            name: "Card",
            size: CGSize(width: 96, height: 64),
            content: ImageEditorSolidColorFillContent(red: 0.2, green: 0.6, blue: 0.9)
        )
        layer.frame.origin = CGPoint(x: 120, y: 100)
        viewModel.document.layers.append(layer)
        viewModel.selectLayer(layer.id)
        let historyCount = viewModel.document.history.count

        viewModel.setSelectedLayerTransform(x: 240, y: 180)

        #expect(viewModel.selectedLayerTransformFrame?.origin == CGPoint(x: 240, y: 180))
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerTransformInspector"))

        viewModel.undo()
        #expect(viewModel.selectedLayerTransformFrame?.origin == CGPoint(x: 120, y: 100))
    }

    @Test func transformInspectorResizesComponentChildrenAsOneObject() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        let originalObjectFrame = try #require(viewModel.selectedXomoObjectFrame)
        let groupID = try #require(viewModel.document.selectedLayerID)
        let originalChildFrames = Dictionary(uniqueKeysWithValues: viewModel.document.layers.compactMap { layer in
            layer.groupID == groupID ? (layer.id, layer.frame) : nil
        })

        viewModel.setSelectedLayerTransform(
            width: Double(originalObjectFrame.width * 2),
            height: Double(originalObjectFrame.height * 2)
        )

        let resizedObjectFrame = try #require(viewModel.selectedXomoObjectFrame)
        #expect(resizedObjectFrame.width == originalObjectFrame.width * 2)
        #expect(resizedObjectFrame.height == originalObjectFrame.height * 2)
        for layer in viewModel.document.layers {
            guard let originalFrame = originalChildFrames[layer.id] else { continue }
            #expect(layer.frame.width == originalFrame.width * 2)
            #expect(layer.frame.height == originalFrame.height * 2)
        }
    }

    @Test func transformInspectorCanPreserveSelectedLayerAspectRatio() throws {
        let viewModel = makeViewModel()
        var layer = ImageEditorLayer.solidColorFill(
            name: "Card",
            size: CGSize(width: 96, height: 64),
            content: ImageEditorSolidColorFillContent(red: 0.2, green: 0.6, blue: 0.9)
        )
        layer.frame.origin = CGPoint(x: 120, y: 100)
        viewModel.document.layers.append(layer)
        viewModel.selectLayer(layer.id)

        viewModel.setSelectedLayerTransform(width: 192, preservingAspectRatio: true)

        #expect(viewModel.selectedLayerTransformFrame?.width == 192)
        #expect(viewModel.selectedLayerTransformFrame?.height == 128)
    }

    private func makeViewModel() -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "objects",
            image: NSImage.transparent(size: CGSize(width: 640, height: 480))
        ) { _ in }
    }
}
