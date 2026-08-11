import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorTransformLockTests {
    @Test
    func pixelLockBlocksEveryContentResamplingEntryPoint() throws {
        let viewModel = makePixelLockedComponent()
        let framesBefore = Dictionary(uniqueKeysWithValues: viewModel.document.layers.map { ($0.id, $0.frame) })
        let historyCountBefore = viewModel.document.history.count
        let transformFrame = try #require(viewModel.selectedLayerTransformFrame)

        viewModel.scaleSelectedLayer(by: 1.5)
        viewModel.rotateSelectedLayerRight90()
        viewModel.flipSelectedLayerHorizontal()
        viewModel.fitSelectedLayerToCanvas()
        viewModel.setSelectedLayerTransform(width: Double(transformFrame.width + 40))
        viewModel.beginResizingSelectedLayer(handle: .bottomRight)
        viewModel.resizeSelectedLayer(
            to: CGPoint(x: transformFrame.maxX + 40, y: transformFrame.maxY + 30),
            handle: .bottomRight
        )
        viewModel.finishResizingSelectedLayer()
        viewModel.beginRotatingSelectedLayer(from: CGPoint(x: transformFrame.maxX, y: transformFrame.midY))
        viewModel.rotateSelectedLayer(to: CGPoint(x: transformFrame.midX, y: transformFrame.maxY))
        viewModel.finishRotatingSelectedLayer()

        #expect(viewModel.document.history.count == historyCountBefore)
        #expect(viewModel.document.layers.allSatisfy { framesBefore[$0.id] == $0.frame })
    }

    @Test
    func pixelLockStillAllowsInspectorPositionChanges() throws {
        let viewModel = makePixelLockedComponent()
        let frameBefore = try #require(viewModel.selectedLayerTransformFrame)

        viewModel.setSelectedLayerTransform(x: Double(frameBefore.minX + 14))

        let frameAfter = try #require(viewModel.selectedLayerTransformFrame)
        #expect(frameAfter.minX == frameBefore.minX + 14)
        #expect(frameAfter.size == frameBefore.size)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerTransformInspector"))
    }

    @Test
    func linkedGroupExpandsToDescendantsAndHonorsTheirPositionLocks() throws {
        let viewModel = makeLinkedGroupFixture()
        let childID = try #require(viewModel.document.layers.first { $0.name == "Child" }?.id)
        let childIndex = try #require(viewModel.document.layers.firstIndex { $0.id == childID })
        let framesBefore = Dictionary(uniqueKeysWithValues: viewModel.document.layers.map { ($0.id, $0.frame) })
        let historyCount = viewModel.document.history.count
        viewModel.document.layers[childIndex].locksPosition = true

        #expect(!viewModel.beginMovingSelectedLayer())
        #expect(viewModel.document.layers.allSatisfy { framesBefore[$0.id] == $0.frame })
        #expect(viewModel.document.history.count == historyCount)

        viewModel.document.layers[childIndex].locksPosition = false
        #expect(viewModel.beginMovingSelectedLayer())
        viewModel.moveSelectedLayer(by: CGSize(width: 12, height: 7))
        viewModel.finishMovingSelectedLayer()

        let movedPeer = try #require(viewModel.document.layers.first { $0.name == "Peer" })
        let movedChild = try #require(viewModel.document.layers.first { $0.name == "Child" })
        #expect(movedPeer.frame == framesBefore[movedPeer.id]?.offsetBy(dx: 12, dy: 7))
        #expect(movedChild.frame == framesBefore[movedChild.id]?.offsetBy(dx: 12, dy: 7))
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerTranslate"))
    }

    @Test
    func hiddenLinkedGroupDescendantsRemainInTransformAndLockClosure() throws {
        let viewModel = makeLinkedGroupFixture()
        let groupIndex = try #require(viewModel.document.layers.firstIndex { $0.name == "Group" })
        let childIndex = try #require(viewModel.document.layers.firstIndex { $0.name == "Child" })
        let childID = viewModel.document.layers[childIndex].id
        let framesBefore = Dictionary(uniqueKeysWithValues: viewModel.document.layers.map { ($0.id, $0.frame) })
        let historyCount = viewModel.document.history.count
        viewModel.document.layers[groupIndex].isVisible = false
        viewModel.document.layers[childIndex].locksPosition = true

        #expect(!viewModel.document.isEffectivelyVisible(viewModel.document.layers[childIndex]))
        #expect(!viewModel.beginMovingSelectedLayer())
        #expect(viewModel.document.layers.allSatisfy { framesBefore[$0.id] == $0.frame })
        #expect(viewModel.document.history.count == historyCount)

        viewModel.document.layers[childIndex].locksPosition = false
        #expect(viewModel.beginMovingSelectedLayer())
        viewModel.moveSelectedLayer(by: CGSize(width: 9, height: -6))
        viewModel.finishMovingSelectedLayer()

        let movedPeer = try #require(viewModel.document.layers.first { $0.name == "Peer" })
        let movedChild = try #require(viewModel.document.layers.first { $0.id == childID })
        #expect(movedPeer.frame == framesBefore[movedPeer.id]?.offsetBy(dx: 9, dy: -6))
        #expect(movedChild.frame == framesBefore[childID]?.offsetBy(dx: 9, dy: -6))
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerTranslate"))
    }

    private func makePixelLockedComponent() -> ImageEditorViewModel {
        let viewModel = ImageEditorViewModel(
            sourceName: "transform-locks",
            image: NSImage.transparent(size: CGSize(width: 640, height: 480))
        ) { _ in }
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        guard let groupID = viewModel.document.selectedLayerID else { return viewModel }
        viewModel.document.layers = viewModel.document.layers.map { layer in
            guard layer.id == groupID else { return layer }
            var locked = layer
            locked.locksPixels = true
            return locked
        }
        return viewModel
    }

    private func makeLinkedGroupFixture() -> ImageEditorViewModel {
        let canvasSize = CGSize(width: 240, height: 180)
        let viewModel = ImageEditorViewModel(
            sourceName: "linked-group-transform",
            image: NSImage.transparent(size: canvasSize)
        ) { _ in }
        let solid = NSImage.rendered(size: CGSize(width: 20, height: 20)) { rect in
            NSColor.systemBlue.setFill()
            rect.fill()
        } ?? NSImage.transparent(size: CGSize(width: 20, height: 20))
        var group = ImageEditorLayer.group(name: "Group", size: canvasSize)
        group.frame = CGRect(x: 80, y: 60, width: 60, height: 50)
        var child = ImageEditorLayer.blank(name: "Child", size: solid.size)
        child.image = solid
        child.frame = CGRect(x: 90, y: 70, width: 20, height: 20)
        child.groupID = group.id
        var peer = ImageEditorLayer.blank(name: "Peer", size: solid.size)
        peer.image = solid
        peer.frame = CGRect(x: 20, y: 30, width: 20, height: 20)
        peer.linkedLayerIDs = [group.id]
        group.linkedLayerIDs = [peer.id]
        viewModel.document.layers = [peer, child, group]
        viewModel.document.selectedLayerID = peer.id
        viewModel.document.selectedLayerIDs = [peer.id]
        return viewModel
    }
}
