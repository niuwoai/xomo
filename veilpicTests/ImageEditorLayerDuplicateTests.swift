//
//  ImageEditorLayerDuplicateTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/10.
//

import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorLayerDuplicateTests {
    @Test func imageEditorDuplicatesSelectedLinkedLayersWithInternalDuplicateLinks() async throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: solidImage(color: .black, size: NSSize(width: 28, height: 20))
        ) { _ in }

        viewModel.addLayer()
        let firstID = try #require(viewModel.document.selectedLayerID)
        viewModel.addLayer()
        let secondID = try #require(viewModel.document.selectedLayerID)

        viewModel.selectLayer(firstID)
        viewModel.selectLayer(secondID, extendingSelection: true)
        viewModel.linkSelectedLayers()

        #expect(layer(firstID, in: viewModel)?.linkedLayerIDs == Set([secondID]))
        #expect(layer(secondID, in: viewModel)?.linkedLayerIDs == Set([firstID]))

        viewModel.duplicateSelectedLayer()

        let duplicatedIDs = viewModel.document.selectedLayerIDs
        #expect(duplicatedIDs.count == 2)
        #expect(!duplicatedIDs.contains(firstID))
        #expect(!duplicatedIDs.contains(secondID))

        let duplicatedLayers = viewModel.document.layers.filter { duplicatedIDs.contains($0.id) }
        #expect(duplicatedLayers.count == 2)
        for duplicatedLayer in duplicatedLayers {
            #expect(duplicatedLayer.linkedLayerIDs.count == 1)
            #expect(duplicatedLayer.linkedLayerIDs.isSubset(of: duplicatedIDs))
            #expect(!duplicatedLayer.linkedLayerIDs.contains(firstID))
            #expect(!duplicatedLayer.linkedLayerIDs.contains(secondID))
        }

        #expect(layer(firstID, in: viewModel)?.linkedLayerIDs == Set([secondID]))
        #expect(layer(secondID, in: viewModel)?.linkedLayerIDs == Set([firstID]))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerDuplicate"))
    }

    @Test func imageEditorDropsLinksToUnselectedOriginalsWhenDuplicatingSingleLinkedLayer() async throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: solidImage(color: .black, size: NSSize(width: 28, height: 20))
        ) { _ in }

        viewModel.addLayer()
        let firstID = try #require(viewModel.document.selectedLayerID)
        viewModel.addLayer()
        let secondID = try #require(viewModel.document.selectedLayerID)

        viewModel.selectLayer(firstID)
        viewModel.selectLayer(secondID, extendingSelection: true)
        viewModel.linkSelectedLayers()

        viewModel.selectLayer(firstID)
        viewModel.duplicateSelectedLayer()

        let duplicatedID = try #require(viewModel.document.selectedLayerID)
        let duplicatedLayer = try #require(layer(duplicatedID, in: viewModel))
        #expect(duplicatedLayer.linkedLayerIDs.isEmpty)
        #expect(layer(firstID, in: viewModel)?.linkedLayerIDs == Set([secondID]))
        #expect(layer(secondID, in: viewModel)?.linkedLayerIDs == Set([firstID]))
    }

    @Test func duplicatesNoncontiguousSelectionsInsideEachParentBoundary() throws {
        let viewModel = makeViewModel()
        var lowerA = namedLayer("Lower A", in: viewModel)
        var gapA = namedLayer("Gap A", in: viewModel)
        var upperA = namedLayer("Upper A", in: viewModel)
        let groupA = ImageEditorLayer.group(name: "Group A", size: viewModel.document.canvasSize)
        var selectedB = namedLayer("Selected B", in: viewModel)
        var gapB = namedLayer("Gap B", in: viewModel)
        let groupB = ImageEditorLayer.group(name: "Group B", size: viewModel.document.canvasSize)
        let ceiling = namedLayer("Ceiling", in: viewModel)
        lowerA.groupID = groupA.id
        gapA.groupID = groupA.id
        upperA.groupID = groupA.id
        selectedB.groupID = groupB.id
        gapB.groupID = groupB.id
        viewModel.document.layers = [
            lowerA,
            gapA,
            upperA,
            groupA,
            selectedB,
            gapB,
            groupB,
            ceiling
        ]
        select([lowerA.id, upperA.id, selectedB.id], primary: selectedB.id, in: viewModel)
        let originalLayers = viewModel.document.layers
        let historyCount = viewModel.document.history.count

        viewModel.duplicateSelectedLayer()

        let lowerACopy = try #require(copy(of: lowerA, in: viewModel))
        let upperACopy = try #require(copy(of: upperA, in: viewModel))
        let selectedBCopy = try #require(copy(of: selectedB, in: viewModel))
        #expect(viewModel.document.layers.map(\.id) == [
            lowerA.id,
            gapA.id,
            upperA.id,
            lowerACopy.id,
            upperACopy.id,
            groupA.id,
            selectedB.id,
            selectedBCopy.id,
            gapB.id,
            groupB.id,
            ceiling.id
        ])
        #expect(lowerACopy.groupID == groupA.id)
        #expect(upperACopy.groupID == groupA.id)
        #expect(selectedBCopy.groupID == groupB.id)
        #expect(viewModel.document.selectedLayerIDs == Set([lowerACopy.id, upperACopy.id, selectedBCopy.id]))
        #expect(viewModel.document.selectedLayerID == selectedBCopy.id)
        #expect(viewModel.document.history.count == historyCount + 1)

        viewModel.undo()
        #expect(viewModel.document.layers.map(\.id) == originalLayers.map(\.id))
        #expect(viewModel.document.selectedLayerIDs == Set([lowerA.id, upperA.id, selectedB.id]))
    }

    @Test func duplicatingSelectedGroupMapsExplicitSelectionWithoutRenamingImplicitDescendants() throws {
        let viewModel = makeViewModel()
        var leaf = namedLayer("Leaf", in: viewModel)
        var innerGroup = ImageEditorLayer.group(name: "Inner", size: viewModel.document.canvasSize)
        var loose = namedLayer("Loose", in: viewModel)
        let outerGroup = ImageEditorLayer.group(name: "Outer", size: viewModel.document.canvasSize)
        let ceiling = namedLayer("Ceiling", in: viewModel)
        leaf.groupID = innerGroup.id
        innerGroup.groupID = outerGroup.id
        loose.groupID = outerGroup.id
        viewModel.document.layers = [leaf, innerGroup, loose, outerGroup, ceiling]
        select([outerGroup.id, leaf.id], primary: outerGroup.id, in: viewModel)

        viewModel.duplicateSelectedLayer()

        let outerCopy = try #require(viewModel.document.layers.first {
            $0.id != outerGroup.id
                && $0.isGroup
                && $0.name == L10n.format("imageEditor.layer.copyName", outerGroup.name)
        })
        let innerCopy = try #require(viewModel.document.layers.first {
            $0.id != innerGroup.id && $0.groupID == outerCopy.id && $0.isGroup
        })
        let leafCopy = try #require(viewModel.document.layers.first {
            $0.id != leaf.id && $0.groupID == innerCopy.id && !$0.isGroup
        })
        let looseCopy = try #require(viewModel.document.layers.first {
            $0.id != loose.id && $0.groupID == outerCopy.id && !$0.isGroup
        })
        #expect(innerCopy.name == innerGroup.name)
        #expect(leafCopy.name == leaf.name)
        #expect(looseCopy.name == loose.name)
        #expect(viewModel.document.layers.map(\.id) == [
            leaf.id,
            innerGroup.id,
            loose.id,
            outerGroup.id,
            leafCopy.id,
            innerCopy.id,
            looseCopy.id,
            outerCopy.id,
            ceiling.id
        ])
        #expect(viewModel.document.selectedLayerIDs == Set([outerCopy.id, leafCopy.id]))
        #expect(viewModel.document.selectedLayerID == outerCopy.id)
    }

    @Test func duplicatingLinkedLayersAcrossImplicitSubtreeRemapsOnlyDuplicateLinks() throws {
        let viewModel = makeViewModel()
        var linkedChild = namedLayer("Linked Child", in: viewModel)
        let selectedGroup = ImageEditorLayer.group(name: "Selected Group", size: viewModel.document.canvasSize)
        var linkedPeer = namedLayer("Linked Peer", in: viewModel)
        let peerGroup = ImageEditorLayer.group(name: "Peer Group", size: viewModel.document.canvasSize)
        linkedChild.groupID = selectedGroup.id
        linkedPeer.groupID = peerGroup.id
        linkedChild.linkedLayerIDs = [linkedPeer.id]
        linkedPeer.linkedLayerIDs = [linkedChild.id]
        viewModel.document.layers = [linkedChild, selectedGroup, linkedPeer, peerGroup]
        select([selectedGroup.id, linkedPeer.id], primary: linkedPeer.id, in: viewModel)

        viewModel.duplicateSelectedLayer()

        let groupCopy = try #require(copy(of: selectedGroup, in: viewModel))
        let childCopy = try #require(viewModel.document.layers.first {
            $0.id != linkedChild.id && $0.groupID == groupCopy.id
        })
        let peerCopy = try #require(copy(of: linkedPeer, in: viewModel))
        #expect(childCopy.linkedLayerIDs == Set([peerCopy.id]))
        #expect(peerCopy.linkedLayerIDs == Set([childCopy.id]))
        #expect(layer(linkedChild.id, in: viewModel)?.linkedLayerIDs == Set([linkedPeer.id]))
        #expect(layer(linkedPeer.id, in: viewModel)?.linkedLayerIDs == Set([linkedChild.id]))
        #expect(viewModel.document.layers.firstIndex { $0.id == groupCopy.id }
            == (viewModel.document.layers.firstIndex { $0.id == selectedGroup.id } ?? -2) + 2)
        #expect(viewModel.document.layers.firstIndex { $0.id == peerCopy.id }
            == (viewModel.document.layers.firstIndex { $0.id == linkedPeer.id } ?? -2) + 1)
    }

    @Test func duplicatingClippingBasePreservesOriginalChainBoundary() throws {
        let viewModel = makeViewModel()
        let base = namedLayer("Base", in: viewModel)
        var firstClip = namedLayer("First Clip", in: viewModel)
        var secondClip = namedLayer("Second Clip", in: viewModel)
        let ceiling = namedLayer("Ceiling", in: viewModel)
        firstClip.isClippingMask = true
        secondClip.isClippingMask = true
        viewModel.document.layers = [base, firstClip, secondClip, ceiling]
        select([base.id], primary: base.id, in: viewModel)

        viewModel.duplicateSelectedLayer()

        let baseCopy = try #require(copy(of: base, in: viewModel))
        #expect(viewModel.document.layers.map(\.id) == [
            base.id,
            firstClip.id,
            secondClip.id,
            baseCopy.id,
            ceiling.id
        ])
        let firstClipIndex = try #require(viewModel.document.layers.firstIndex { $0.id == firstClip.id })
        let secondClipIndex = try #require(viewModel.document.layers.firstIndex { $0.id == secondClip.id })
        #expect(viewModel.document.clippingBase(forLayerAt: firstClipIndex)?.id == base.id)
        #expect(viewModel.document.clippingBase(forLayerAt: secondClipIndex)?.id == base.id)
    }

    @Test func duplicatingClippingChainMapsDuplicateBaseAndClearsOrphanCopy() throws {
        let viewModel = makeViewModel()
        var base = namedLayer("Base", in: viewModel)
        var clip = namedLayer("Clip", in: viewModel)
        let group = ImageEditorLayer.group(name: "Chain", size: viewModel.document.canvasSize)
        var orphan = namedLayer("Orphan", in: viewModel)
        base.groupID = group.id
        clip.groupID = group.id
        clip.isClippingMask = true
        orphan.isClippingMask = true
        viewModel.document.layers = [base, clip, group, orphan]
        select([group.id, orphan.id], primary: orphan.id, in: viewModel)

        viewModel.duplicateSelectedLayer()

        let groupCopy = try #require(copy(of: group, in: viewModel))
        let baseCopy = try #require(viewModel.document.layers.first {
            $0.id != base.id && $0.groupID == groupCopy.id && !$0.isClippingMask
        })
        let clipCopy = try #require(viewModel.document.layers.first {
            $0.id != clip.id && $0.groupID == groupCopy.id && $0.isClippingMask
        })
        let orphanCopy = try #require(copy(of: orphan, in: viewModel))
        let clipCopyIndex = try #require(viewModel.document.layers.firstIndex { $0.id == clipCopy.id })
        #expect(viewModel.document.clippingBase(forLayerAt: clipCopyIndex)?.id == baseCopy.id)
        #expect(!orphanCopy.isClippingMask)
        #expect(orphan.isClippingMask)
    }

    private func layer(_ id: UUID, in viewModel: ImageEditorViewModel) -> ImageEditorLayer? {
        viewModel.document.layers.first { $0.id == id }
    }

    private func makeViewModel() -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "source.png",
            image: solidImage(color: .black, size: NSSize(width: 80, height: 60))
        ) { _ in }
    }

    private func namedLayer(_ name: String, in viewModel: ImageEditorViewModel) -> ImageEditorLayer {
        ImageEditorLayer.blank(name: name, size: viewModel.document.canvasSize)
    }

    private func select(
        _ ids: Set<UUID>,
        primary: UUID,
        in viewModel: ImageEditorViewModel
    ) {
        viewModel.document.selectedLayerIDs = ids
        viewModel.document.selectedLayerID = primary
    }

    private func copy(
        of source: ImageEditorLayer,
        in viewModel: ImageEditorViewModel
    ) -> ImageEditorLayer? {
        let copyName = L10n.format("imageEditor.layer.copyName", source.name)
        return viewModel.document.layers.first { layer in
            layer.id != source.id && layer.name == copyName
        }
    }

    private func solidImage(color: NSColor, size: NSSize) -> NSImage {
        NSImage.rendered(size: size) { rect in
            color.setFill()
            rect.fill()
        } ?? NSImage.transparent(size: size)
    }
}
