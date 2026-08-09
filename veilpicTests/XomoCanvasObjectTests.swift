import AppKit
import Testing
@testable import musepic

@MainActor
struct XomoCanvasObjectTests {
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
