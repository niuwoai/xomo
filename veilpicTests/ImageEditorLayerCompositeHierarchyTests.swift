//
//  ImageEditorLayerCompositeHierarchyTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/13.
//

import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorLayerCompositeHierarchyTests {
    @Test func mergeVisibleRemovesNestedVisibleGroupsWithoutSplittingHiddenRoots() throws {
        let viewModel = makeViewModel()
        var root = layer("Root", color: .systemBlue, in: viewModel)
        root.opacity = 0.65
        var leaf = layer("Leaf", color: .systemRed, in: viewModel)
        var inner = ImageEditorLayer.group(name: "Inner", size: viewModel.document.canvasSize)
        let outer = ImageEditorLayer.group(name: "Outer", size: viewModel.document.canvasSize)
        var hiddenTop = layer("Hidden Top", color: .systemGreen, in: viewModel)
        leaf.groupID = inner.id
        inner.groupID = outer.id
        hiddenTop.isVisible = false
        viewModel.document.layers = [root, leaf, inner, outer, hiddenTop]
        select([leaf.id], primary: leaf.id, in: viewModel)
        let imageBefore = viewModel.document.compositedImage

        viewModel.mergeVisibleLayers()

        let merged = try #require(viewModel.document.selectedLayer)
        #expect(viewModel.document.layers.map(\.id) == [merged.id, hiddenTop.id])
        #expect(merged.groupID == nil)
        #expect(!viewModel.document.layers.contains { $0.id == inner.id || $0.id == outer.id })
        #expect(viewModel.document.layers.last?.id == hiddenTop.id)
        #expect(
            imageEditorMaximumPixelDifference(viewModel.document.compositedImage, imageBefore)
                <= ImageEditorTestPixelTolerance.rasterizedMerge
        )
    }

    @Test func mergeVisiblePreservesEffectivelyHiddenNestedSubtrees() throws {
        let viewModel = makeViewModel()
        let lower = layer("Lower", color: .systemBlue, in: viewModel)
        var hiddenChild = layer("Hidden Child", color: .systemGreen, in: viewModel)
        var hiddenGroup = ImageEditorLayer.group(name: "Hidden Group", size: viewModel.document.canvasSize)
        let upper = layer("Upper", color: .systemRed, in: viewModel)
        hiddenChild.groupID = hiddenGroup.id
        hiddenGroup.isVisible = false
        viewModel.document.layers = [lower, hiddenChild, hiddenGroup, upper]
        select([upper.id], primary: upper.id, in: viewModel)

        viewModel.mergeVisibleLayers()

        let merged = try #require(viewModel.document.selectedLayer)
        #expect(viewModel.document.layers.map(\.id) == [hiddenChild.id, hiddenGroup.id, merged.id])
        #expect(viewModel.document.layers.first { $0.id == hiddenChild.id }?.groupID == hiddenGroup.id)
        #expect(viewModel.document.layers.first { $0.id == hiddenGroup.id }?.isVisible == false)
    }

    @Test func mergeVisibleReplacesLinksAndKeepsAValidHiddenClippingChain() throws {
        let viewModel = makeViewModel()
        var lower = layer("Lower", color: .systemBlue, in: viewModel)
        var base = layer("Base", color: .systemRed, in: viewModel)
        var hiddenClip = layer("Hidden Clip", color: .systemGreen, in: viewModel)
        lower.linkedLayerIDs = [hiddenClip.id]
        base.linkedLayerIDs = [hiddenClip.id]
        hiddenClip.linkedLayerIDs = [lower.id, base.id]
        hiddenClip.isClippingMask = true
        hiddenClip.isVisible = false
        viewModel.document.layers = [lower, base, hiddenClip]
        select([base.id], primary: base.id, in: viewModel)

        viewModel.mergeVisibleLayers()

        let merged = try #require(viewModel.document.selectedLayer)
        let survivingClip = try #require(viewModel.document.layers.first { $0.id == hiddenClip.id })
        let clipIndex = try #require(viewModel.document.layers.firstIndex { $0.id == hiddenClip.id })
        #expect(viewModel.document.layers.map(\.id) == [merged.id, hiddenClip.id])
        #expect(merged.linkedLayerIDs == [hiddenClip.id])
        #expect(survivingClip.linkedLayerIDs == [merged.id])
        #expect(survivingClip.isClippingMask)
        #expect(viewModel.document.clippingBase(forLayerAt: clipIndex)?.id == merged.id)
    }

    @Test func mergeVisibleKeepsHiddenNearestBaseInsideSurvivingGroup() throws {
        let viewModel = makeViewModel()
        var visibleFallback = layer("Visible Fallback", color: .systemBlue, in: viewModel)
        var hiddenBase = layer("Hidden Base", color: .systemRed, in: viewModel)
        var hiddenClip = layer("Hidden Clip", color: .systemGreen, in: viewModel)
        let group = ImageEditorLayer.group(name: "Surviving Group", size: viewModel.document.canvasSize)
        let visibleRoot = layer("Visible Root", color: .systemYellow, in: viewModel)
        visibleFallback.groupID = group.id
        hiddenBase.groupID = group.id
        hiddenBase.isVisible = false
        hiddenClip.groupID = group.id
        hiddenClip.isVisible = false
        hiddenClip.isClippingMask = true
        viewModel.document.layers = [visibleFallback, hiddenBase, hiddenClip, group, visibleRoot]
        select([visibleRoot.id], primary: visibleRoot.id, in: viewModel)

        let clipIndexBefore = try #require(viewModel.document.layers.firstIndex { $0.id == hiddenClip.id })
        #expect(viewModel.document.clippingBase(forLayerAt: clipIndexBefore)?.id == hiddenBase.id)

        viewModel.mergeVisibleLayers()

        let survivingClip = try #require(viewModel.document.layers.first { $0.id == hiddenClip.id })
        let clipIndex = try #require(viewModel.document.layers.firstIndex { $0.id == hiddenClip.id })
        #expect(viewModel.document.layers.contains { $0.id == group.id })
        #expect(viewModel.document.layers.contains { $0.id == hiddenBase.id })
        #expect(!viewModel.document.layers.contains { $0.id == visibleFallback.id })
        #expect(survivingClip.isClippingMask)
        #expect(viewModel.document.clippingBase(forLayerAt: clipIndex)?.id == hiddenBase.id)
    }

    @Test func stampVisibleUsesASafeRootBoundaryAndLeavesSourceRelationsUntouched() throws {
        let viewModel = makeViewModel()
        var root = layer("Root", color: .systemBlue, in: viewModel)
        var child = layer("Child", color: .systemRed, in: viewModel)
        let group = ImageEditorLayer.group(name: "Group", size: viewModel.document.canvasSize)
        var hiddenTop = layer("Hidden Top", color: .systemGreen, in: viewModel)
        child.groupID = group.id
        root.linkedLayerIDs = [child.id]
        child.linkedLayerIDs = [root.id]
        hiddenTop.isVisible = false
        viewModel.document.layers = [root, child, group, hiddenTop]
        select([child.id], primary: child.id, in: viewModel)
        let originalRelations = relationSnapshot(viewModel.document.layers)

        viewModel.stampVisibleLayers()

        let stamp = try #require(viewModel.document.selectedLayer)
        #expect(viewModel.document.layers.map(\.id) == [root.id, child.id, group.id, stamp.id, hiddenTop.id])
        #expect(stamp.groupID == nil)
        #expect(relationSnapshot(viewModel.document.layers.filter { $0.id != stamp.id }) == originalRelations)
    }

    @Test func stampSelectedInsideAGroupUsesParentLocalPixelsAndStaysInsideTheGroup() throws {
        let viewModel = makeViewModel()
        var lower = layer("Lower", color: .systemRed, in: viewModel)
        var upper = layer("Upper", color: .clear, in: viewModel)
        var group = ImageEditorLayer.group(name: "Group", size: viewModel.document.canvasSize)
        lower.groupID = group.id
        upper.groupID = group.id
        group.opacity = 0.5
        viewModel.document.layers = [lower, upper, group]
        select([lower.id, upper.id], primary: upper.id, in: viewModel)

        viewModel.stampSelectedLayers()

        let stamp = try #require(viewModel.document.selectedLayer)
        #expect(viewModel.document.layers.map(\.id) == [lower.id, upper.id, stamp.id, group.id])
        #expect(stamp.groupID == group.id)
        let center = try #require(stamp.image.color(at: CGPoint(x: 20, y: 20))?.usingColorSpace(.deviceRGB))
        #expect(center.alphaComponent > 0.95)
        #expect(center.redComponent > 0.9)
    }

    @Test func stampSelectedAcrossParentsUsesATopLevelBoundaryWithoutSplittingGroups() throws {
        let viewModel = makeViewModel()
        var child = layer("Child", color: .systemBlue, in: viewModel)
        let group = ImageEditorLayer.group(name: "Group", size: viewModel.document.canvasSize)
        let root = layer("Root", color: .systemRed, in: viewModel)
        var hiddenTop = layer("Hidden Top", color: .systemGreen, in: viewModel)
        child.groupID = group.id
        hiddenTop.isVisible = false
        viewModel.document.layers = [child, group, root, hiddenTop]
        select([child.id, root.id], primary: root.id, in: viewModel)

        viewModel.stampSelectedLayers()

        let stamp = try #require(viewModel.document.selectedLayer)
        #expect(viewModel.document.layers.map(\.id) == [child.id, group.id, root.id, stamp.id, hiddenTop.id])
        #expect(stamp.groupID == nil)
        #expect(viewModel.document.layers.first { $0.id == child.id }?.groupID == group.id)
    }

    @Test func flattenCreatesAnOpaqueLockedBackgroundAndUndoRestoresTheHierarchy() throws {
        let viewModel = makeViewModel()
        var visible = ImageEditorLayer.blank(name: "Visible", size: viewModel.document.canvasSize)
        visible.image = solidImage(color: .systemRed, size: NSSize(width: 18, height: 18))
        visible.frame = CGRect(x: 8, y: 8, width: 18, height: 18)
        var hidden = layer("Hidden", color: .systemGreen, in: viewModel)
        let group = ImageEditorLayer.group(name: "Group", size: viewModel.document.canvasSize)
        hidden.groupID = group.id
        hidden.isVisible = false
        visible.linkedLayerIDs = [hidden.id]
        hidden.linkedLayerIDs = [visible.id]
        viewModel.document.layers = [visible, hidden, group]
        select([visible.id], primary: visible.id, in: viewModel)
        let originalIDs = viewModel.document.layers.map(\.id)

        viewModel.flattenImage()

        let background = try #require(viewModel.document.selectedLayer)
        #expect(viewModel.document.layers.count == 1)
        #expect(viewModel.document.layers.first?.id == background.id)
        #expect(background.name == L10n.text("imageEditor.layer.background"))
        #expect(background.isLocked)
        #expect(background.groupID == nil)
        #expect(background.linkedLayerIDs.isEmpty)
        #expect(!background.isClippingMask)
        let whiteCorner = try #require(background.image.color(at: CGPoint(x: 100, y: 70))?.usingColorSpace(.deviceRGB))
        #expect(whiteCorner.alphaComponent > 0.99)
        #expect(whiteCorner.redComponent > 0.98)
        #expect(whiteCorner.greenComponent > 0.98)
        #expect(whiteCorner.blueComponent > 0.98)

        viewModel.undo()
        #expect(viewModel.document.layers.map(\.id) == originalIDs)
        #expect(viewModel.document.layers.first { $0.id == hidden.id }?.groupID == group.id)
    }

    private func makeViewModel() -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "composite-hierarchy.png",
            image: NSImage.transparent(size: NSSize(width: 120, height: 90))
        ) { _ in }
    }

    private func layer(
        _ name: String,
        color: NSColor,
        in viewModel: ImageEditorViewModel
    ) -> ImageEditorLayer {
        var layer = ImageEditorLayer.blank(name: name, size: viewModel.document.canvasSize)
        layer.image = solidImage(color: color, size: viewModel.document.canvasSize)
        return layer
    }

    private func solidImage(color: NSColor, size: NSSize) -> NSImage {
        NSImage.rendered(size: size) { _ in
            color.setFill()
            NSBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
        } ?? NSImage(size: size)
    }

    private func select(
        _ ids: Set<UUID>,
        primary: UUID,
        in viewModel: ImageEditorViewModel
    ) {
        viewModel.document.selectedLayerIDs = ids
        viewModel.document.selectedLayerID = primary
    }

    private func relationSnapshot(_ layers: [ImageEditorLayer]) -> [UUID: LayerRelations] {
        Dictionary(uniqueKeysWithValues: layers.map { layer in
            (
                layer.id,
                LayerRelations(
                    groupID: layer.groupID,
                    linkedLayerIDs: layer.linkedLayerIDs,
                    isClippingMask: layer.isClippingMask
                )
            )
        })
    }

    private struct LayerRelations: Equatable {
        var groupID: UUID?
        var linkedLayerIDs: Set<UUID>
        var isClippingMask: Bool
    }
}
