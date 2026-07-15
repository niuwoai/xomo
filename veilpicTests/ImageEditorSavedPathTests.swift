//
//  ImageEditorSavedPathTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/14.
//

import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorSavedPathTests {
    @Test func savingPathCreatesIndependentUndoableSnapshotAndLoadsEditableCopy() throws {
        let viewModel = makeViewModel()
        let points = [
            CGPoint(x: 12, y: 10),
            CGPoint(x: 70, y: 14),
            CGPoint(x: 48, y: 52)
        ]
        createPath(points: points, closed: true, viewModel: viewModel)
        let sourceLayerID = try #require(viewModel.document.selectedLayerID)
        let historyCount = viewModel.document.history.count

        let saved = try #require(viewModel.saveCurrentPath(name: "  Logo Outline  "))

        #expect(saved.name == "Logo Outline")
        #expect(saved.isClosed)
        #expect(saved.subpaths.count == 1)
        #expect(saved.subpaths[0].map(\.point) == points)
        #expect(viewModel.document.selectedSavedPathID == saved.id)
        #expect(viewModel.document.history.count == historyCount + 1)

        viewModel.undo()
        #expect(viewModel.document.savedPaths.isEmpty)
        viewModel.redo()
        #expect(viewModel.document.savedPaths.map(\.id) == [saved.id])

        viewModel.document.layers.removeAll { $0.id == sourceLayerID }
        viewModel.document.selectedLayerID = viewModel.document.layers.last?.id
        viewModel.document.selectedLayerIDs = Set([viewModel.document.selectedLayerID].compactMap { $0 })
        let loadedLayer = try #require(viewModel.loadSavedPath(saved.id))
        #expect(loadedLayer.id != sourceLayerID)
        #expect(loadedLayer.name == "Logo Outline")
        #expect(loadedLayer.shapeContent?.kind == .path)
        #expect(loadedLayer.shapeContent?.isPathClosed == true)

        let loadedSnapshot = try #require(viewModel.saveCurrentPath(name: "Loaded Copy"))
        #expect(loadedSnapshot.subpaths == saved.subpaths)
    }

    @Test func savedPathCanBeRenamedUpdatedAndDeletedWithoutChangingItsIdentity() throws {
        let viewModel = makeViewModel()
        createPath(
            points: [CGPoint(x: 10, y: 8), CGPoint(x: 60, y: 12), CGPoint(x: 42, y: 48)],
            closed: true,
            viewModel: viewModel
        )
        let saved = try #require(viewModel.saveCurrentPath(name: nil))
        let originalPoint = try #require(saved.subpaths.first?.first?.point)

        #expect(viewModel.renameSavedPath(saved.id, to: "  Primary Path  "))
        #expect(!viewModel.renameSavedPath(saved.id, to: "  \n"))
        #expect(viewModel.document.savedPaths.first?.name == "Primary Path")
        #expect(viewModel.document.savedPaths.first?.id == saved.id)

        viewModel.selectedPathSubpathIndex = 0
        viewModel.selectedPathAnchorIndex = 0
        viewModel.setSelectedPathAnchorX(originalPoint.x + 9)
        #expect(viewModel.updateSavedPath(saved.id))
        #expect(viewModel.document.savedPaths.first?.subpaths.first?.first?.point.x == originalPoint.x + 9)

        #expect(viewModel.deleteSavedPath(saved.id))
        #expect(viewModel.document.savedPaths.isEmpty)
        #expect(viewModel.document.selectedSavedPathID == nil)
    }

    @Test func updatingExistingPathRemainsAvailableAtSavedPathCapacity() throws {
        let viewModel = makeViewModel()
        createPath(
            points: [CGPoint(x: 9, y: 9), CGPoint(x: 62, y: 13), CGPoint(x: 40, y: 51)],
            closed: true,
            viewModel: viewModel
        )
        let saved = try #require(viewModel.saveCurrentPath(name: "Primary"))
        viewModel.document.savedPaths.append(contentsOf: (1..<ImageEditorSavedPath.maximumCount).map { index in
            ImageEditorSavedPath(
                id: UUID(),
                name: "Stored \(index)",
                subpaths: saved.subpaths,
                isClosed: saved.isClosed
            )
        })
        viewModel.selectedPathAnchorIndex = 0
        viewModel.setSelectedPathAnchorX(18)

        #expect(viewModel.document.savedPaths.count == ImageEditorSavedPath.maximumCount)
        #expect(viewModel.hasEditableCurrentPath)
        #expect(!viewModel.canSaveCurrentPath)
        #expect(viewModel.updateSavedPath(saved.id))
        #expect(viewModel.document.savedPaths.first?.subpaths.first?.first?.point.x == 18)
    }

    @Test func closedSavedPathLoadsSelectionWithoutCreatingOrSelectingALayer() throws {
        let viewModel = makeViewModel()
        createPath(
            points: [CGPoint(x: 12, y: 10), CGPoint(x: 70, y: 14), CGPoint(x: 48, y: 52)],
            closed: true,
            viewModel: viewModel
        )
        let sourceLayerID = try #require(viewModel.document.selectedLayerID)
        let saved = try #require(viewModel.saveCurrentPath(name: "Logo Outline"))
        viewModel.document.layers.removeAll { $0.id == sourceLayerID }
        viewModel.document.selectedLayerID = viewModel.document.layers.last?.id
        viewModel.document.selectedLayerIDs = Set([viewModel.document.selectedLayerID].compactMap { $0 })
        let selectedLayerID = viewModel.document.selectedLayerID
        let layerCount = viewModel.document.layers.count
        let historyCount = viewModel.document.history.count

        #expect(viewModel.canLoadSelectionFromSelectedSavedPath)
        #expect(viewModel.loadSelectionFromSavedPath(saved.id))

        let selection = try #require(viewModel.document.selection)
        let mask = try #require(selection.rasterMask)
        #expect(viewModel.document.layers.count == layerCount)
        #expect(viewModel.document.selectedLayerID == selectedLayerID)
        #expect(viewModel.document.savedPaths == [saved])
        #expect(mask.alpha[26 * mask.width + 46] == UInt8.max)
        #expect(mask.alpha[66 * mask.width + 90] == 0)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionFromSavedPath"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.selectionFromSavedPath", saved.name))

        viewModel.undo()
        #expect(viewModel.document.selection == nil)
        #expect(viewModel.document.layers.count == layerCount)
        #expect(viewModel.document.savedPaths == [saved])
    }

    @Test func openSavedPathCannotLoadSelectionOrCreateHistory() throws {
        let viewModel = makeViewModel()
        createPath(
            points: [CGPoint(x: 10, y: 10), CGPoint(x: 64, y: 16), CGPoint(x: 38, y: 50)],
            closed: false,
            viewModel: viewModel
        )
        let saved = try #require(viewModel.saveCurrentPath(name: "Open Curve"))
        let historyCount = viewModel.document.history.count

        #expect(!viewModel.canLoadSelectionFromSelectedSavedPath)
        #expect(!viewModel.loadSelectionFromSavedPath(saved.id))
        #expect(viewModel.document.selection == nil)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.savedPathSelectionRequiresClosed"))
    }

    @Test func savedPathSelectionRespectsAddMode() throws {
        let viewModel = makeViewModel()
        createPath(
            points: [CGPoint(x: 12, y: 10), CGPoint(x: 70, y: 14), CGPoint(x: 48, y: 52)],
            closed: true,
            viewModel: viewModel
        )
        let saved = try #require(viewModel.saveCurrentPath(name: "Triangle"))
        viewModel.document.selection = .rectangle(CGRect(x: 80, y: 60, width: 10, height: 8))
        viewModel.selectionMode = .add

        #expect(viewModel.loadSelectionFromSavedPath(saved.id))

        let mask = try #require(viewModel.document.selection?.rasterMask)
        #expect(mask.alpha[26 * mask.width + 46] == UInt8.max)
        #expect(mask.alpha[64 * mask.width + 85] == UInt8.max)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionAdd"))
    }

    @Test func compoundSavedPathLoadsEverySubpathIntoSelection() throws {
        let viewModel = makeViewModel()
        let saved = ImageEditorSavedPath(
            name: "Two Islands",
            subpaths: [
                rectangleAnchors(CGRect(x: 8, y: 8, width: 18, height: 14)),
                rectangleAnchors(CGRect(x: 58, y: 42, width: 22, height: 16))
            ],
            isClosed: true
        )
        viewModel.document.savedPaths = [saved]
        viewModel.document.selectedSavedPathID = saved.id

        #expect(viewModel.loadSelectionFromSavedPath(saved.id))

        let mask = try #require(viewModel.document.selection?.rasterMask)
        #expect(mask.alpha[14 * mask.width + 16] == UInt8.max)
        #expect(mask.alpha[50 * mask.width + 68] == UInt8.max)
        #expect(mask.alpha[34 * mask.width + 44] == 0)
    }

    @Test func closedSavedPathFillsSelectedPixelLayerWithoutCreatingALayer() throws {
        let viewModel = makeViewModel()
        viewModel.foregroundColor = .white
        viewModel.opacity = 1
        createPath(
            points: [CGPoint(x: 12, y: 10), CGPoint(x: 70, y: 14), CGPoint(x: 48, y: 52)],
            closed: true,
            viewModel: viewModel
        )
        let sourceLayerID = try #require(viewModel.document.selectedLayerID)
        let saved = try #require(viewModel.saveCurrentPath(name: "Fill Shape"))
        viewModel.document.layers.removeAll { $0.id == sourceLayerID }
        viewModel.document.selectedLayerID = viewModel.document.layers.last?.id
        viewModel.document.selectedLayerIDs = Set([viewModel.document.selectedLayerID].compactMap { $0 })
        let targetLayerID = try #require(viewModel.document.selectedLayerID)
        let targetBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let layerCount = viewModel.document.layers.count

        #expect(viewModel.canFillSelectedSavedPathToPixelLayer)
        #expect(viewModel.fillSavedPathToSelectedPixelLayer(saved.id))

        let target = try #require(viewModel.document.layers.first { $0.id == targetLayerID })
        let inside = try #require(target.image.color(at: CGPoint(x: 46, y: 26))?.usingColorSpace(.deviceRGB))
        let outside = try #require(target.image.color(at: CGPoint(x: 90, y: 66))?.usingColorSpace(.deviceRGB))
        #expect(viewModel.document.layers.count == layerCount)
        #expect(viewModel.document.selectedLayerID == targetLayerID)
        #expect(try #require(target.image.qingtuPNGData()) != targetBefore)
        #expect(inside.alphaComponent > 0.9)
        #expect(inside.redComponent > 0.9)
        #expect(outside.alphaComponent < 0.01)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.savedPathFill"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.savedPathFilled", saved.name))

        viewModel.undo()
        #expect(try #require(viewModel.document.selectedLayer?.image.qingtuPNGData()) == targetBefore)
    }

    @Test func openSavedPathStrokesSelectedPixelLayer() throws {
        let viewModel = makeViewModel()
        viewModel.foregroundColor = .white
        viewModel.opacity = 1
        viewModel.brushSize = 8
        createPath(
            points: [CGPoint(x: 10, y: 20), CGPoint(x: 70, y: 20), CGPoint(x: 70, y: 54)],
            closed: false,
            viewModel: viewModel
        )
        let sourceLayerID = try #require(viewModel.document.selectedLayerID)
        let saved = try #require(viewModel.saveCurrentPath(name: "Open Stroke"))
        viewModel.document.layers.removeAll { $0.id == sourceLayerID }
        viewModel.document.selectedLayerID = viewModel.document.layers.last?.id
        viewModel.document.selectedLayerIDs = Set([viewModel.document.selectedLayerID].compactMap { $0 })
        let targetLayerID = try #require(viewModel.document.selectedLayerID)

        #expect(viewModel.canStrokeSelectedSavedPathToPixelLayer)
        #expect(!viewModel.canFillSelectedSavedPathToPixelLayer)
        #expect(viewModel.strokeSavedPathToSelectedPixelLayer(saved.id))

        let target = try #require(viewModel.document.layers.first { $0.id == targetLayerID })
        let stroked = try #require(target.image.color(at: CGPoint(x: 40, y: 20))?.usingColorSpace(.deviceRGB))
        let untouched = try #require(target.image.color(at: CGPoint(x: 20, y: 60))?.usingColorSpace(.deviceRGB))
        #expect(stroked.alphaComponent > 0.9)
        #expect(stroked.redComponent > 0.9)
        #expect(untouched.alphaComponent < 0.01)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.savedPathStroke"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.savedPathStroked", saved.name))
    }

    @Test func savedPathRenderRejectsLockedTargetWithoutHistory() throws {
        let viewModel = makeViewModel()
        createPath(
            points: [CGPoint(x: 12, y: 10), CGPoint(x: 70, y: 14), CGPoint(x: 48, y: 52)],
            closed: true,
            viewModel: viewModel
        )
        let sourceLayerID = try #require(viewModel.document.selectedLayerID)
        let saved = try #require(viewModel.saveCurrentPath(name: "Locked Target"))
        viewModel.document.layers.removeAll { $0.id == sourceLayerID }
        let targetIndex = try #require(viewModel.document.layers.indices.last)
        viewModel.document.selectedLayerID = viewModel.document.layers[targetIndex].id
        viewModel.document.selectedLayerIDs = [viewModel.document.layers[targetIndex].id]
        viewModel.document.layers[targetIndex].isLocked = true
        let historyCount = viewModel.document.history.count
        let targetBefore = try #require(viewModel.document.layers[targetIndex].image.qingtuPNGData())

        #expect(!viewModel.canFillSelectedSavedPathToPixelLayer)
        #expect(!viewModel.canStrokeSelectedSavedPathToPixelLayer)
        #expect(!viewModel.fillSavedPathToSelectedPixelLayer(saved.id))
        #expect(viewModel.document.history.count == historyCount)
        #expect(try #require(viewModel.document.layers[targetIndex].image.qingtuPNGData()) == targetBefore)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.savedPathRenderRequiresPixelLayer"))
    }

    @Test func savedPathFillPreservesTransparentPixelsWhenLocked() throws {
        let viewModel = makeViewModel()
        viewModel.foregroundColor = .white
        viewModel.opacity = 1
        createPath(
            points: [CGPoint(x: 12, y: 10), CGPoint(x: 70, y: 14), CGPoint(x: 48, y: 52)],
            closed: true,
            viewModel: viewModel
        )
        let sourceLayerID = try #require(viewModel.document.selectedLayerID)
        let saved = try #require(viewModel.saveCurrentPath(name: "Alpha Locked"))
        viewModel.document.layers.removeAll { $0.id == sourceLayerID }
        let targetIndex = try #require(viewModel.document.layers.indices.last)
        viewModel.document.layers[targetIndex].image = alphaSplitImage(size: viewModel.document.canvasSize)
        viewModel.document.layers[targetIndex].locksTransparentPixels = true
        viewModel.document.selectedLayerID = viewModel.document.layers[targetIndex].id
        viewModel.document.selectedLayerIDs = [viewModel.document.layers[targetIndex].id]

        #expect(viewModel.fillSavedPathToSelectedPixelLayer(saved.id))

        let target = viewModel.document.layers[targetIndex]
        let transparentInside = try #require(target.image.color(at: CGPoint(x: 30, y: 26))?.usingColorSpace(.deviceRGB))
        let opaqueInside = try #require(target.image.color(at: CGPoint(x: 55, y: 26))?.usingColorSpace(.deviceRGB))
        #expect(transparentInside.alphaComponent < 0.01)
        #expect(opaqueInside.alphaComponent > 0.9)
        #expect(opaqueInside.redComponent > 0.9)
        #expect(opaqueInside.greenComponent > 0.9)
        #expect(opaqueInside.blueComponent > 0.9)
    }

    @Test func savedPathRenderMapsCanvasCoordinatesIntoOffsetScaledPixelLayer() throws {
        let viewModel = makeViewModel()
        let saved = ImageEditorSavedPath(
            name: "Offset Fill",
            subpaths: [rectangleAnchors(CGRect(x: 30, y: 20, width: 20, height: 20))],
            isClosed: true
        )
        var target = ImageEditorLayer.blank(name: "Scaled Target", size: NSSize(width: 20, height: 20))
        target.frame = CGRect(x: 20, y: 10, width: 40, height: 40)
        viewModel.document.layers = [target]
        viewModel.document.selectedLayerID = target.id
        viewModel.document.selectedLayerIDs = [target.id]
        viewModel.document.savedPaths = [saved]
        viewModel.document.selectedSavedPathID = saved.id
        viewModel.foregroundColor = .white
        viewModel.opacity = 1

        #expect(viewModel.fillSavedPathToSelectedPixelLayer(saved.id))

        let rendered = try #require(viewModel.document.selectedLayer?.image)
        let mappedInside = try #require(rendered.color(at: CGPoint(x: 10, y: 10))?.usingColorSpace(.deviceRGB))
        let mappedOutside = try #require(rendered.color(at: CGPoint(x: 2, y: 2))?.usingColorSpace(.deviceRGB))
        #expect(mappedInside.alphaComponent > 0.9)
        #expect(mappedInside.redComponent > 0.9)
        #expect(mappedOutside.alphaComponent < 0.01)
    }

    @Test func selectedSavedPathProvidesNonDestructiveCanvasOverlay() throws {
        let viewModel = makeViewModel()
        let saved = ImageEditorSavedPath(
            name: "Overlay Path",
            subpaths: [rectangleAnchors(CGRect(x: 18, y: 12, width: 42, height: 30))],
            isClosed: true
        )
        viewModel.document.savedPaths = [saved]
        viewModel.document.selectedSavedPathID = saved.id
        let historyCount = viewModel.document.history.count
        let layerCount = viewModel.document.layers.count

        #expect(viewModel.savedPathCanvasOverlays == [saved])
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.document.layers.count == layerCount)
    }

    @Test func savedPathCanvasOverlayHonorsExtrasVisibilityAndSelection() {
        let viewModel = makeViewModel()
        let saved = ImageEditorSavedPath(
            name: "Hidden Overlay",
            subpaths: [rectangleAnchors(CGRect(x: 10, y: 10, width: 30, height: 20))],
            isClosed: true
        )
        viewModel.document.savedPaths = [saved]

        #expect(viewModel.savedPathCanvasOverlays.isEmpty)
        viewModel.document.selectedSavedPathID = saved.id
        #expect(viewModel.savedPathCanvasOverlays == [saved])
        viewModel.document.areExtrasVisible = false
        #expect(viewModel.savedPathCanvasOverlays.isEmpty)
    }

    @Test func savedPathVisibilityKeepsUnselectedPathsOverlaidWithoutHistory() throws {
        let viewModel = makeViewModel()
        let first = ImageEditorSavedPath(
            name: "Pinned",
            subpaths: [rectangleAnchors(CGRect(x: 8, y: 8, width: 24, height: 18))],
            isClosed: true
        )
        let second = ImageEditorSavedPath(
            name: "Selected",
            subpaths: [rectangleAnchors(CGRect(x: 48, y: 34, width: 26, height: 20))],
            isClosed: true
        )
        viewModel.document.savedPaths = [first, second]
        viewModel.document.selectedSavedPathID = second.id
        let historyCount = viewModel.document.history.count

        #expect(viewModel.setSavedPathVisibility(first.id, isVisible: true))
        #expect(viewModel.document.savedPaths[0].isVisible)
        #expect(viewModel.savedPathCanvasOverlays.map(\.id) == [first.id, second.id])
        #expect(viewModel.document.history.count == historyCount)

        viewModel.document.selectedSavedPathID = nil
        #expect(viewModel.savedPathCanvasOverlays.map(\.id) == [first.id])
        #expect(viewModel.setSavedPathVisibility(first.id, isVisible: false))
        #expect(viewModel.savedPathCanvasOverlays.isEmpty)
    }

    @Test func savedPathVisibilityRoundTripsAndOlderPayloadsDefaultToHidden() throws {
        let viewModel = makeViewModel()
        createPath(
            points: [CGPoint(x: 12, y: 10), CGPoint(x: 70, y: 14), CGPoint(x: 48, y: 52)],
            closed: true,
            viewModel: viewModel
        )
        let saved = try #require(viewModel.saveCurrentPath(name: "Persistent"))
        #expect(viewModel.setSavedPathVisibility(saved.id, isVisible: true))
        #expect(viewModel.updateSavedPath(saved.id))
        #expect(viewModel.document.savedPaths.first?.isVisible == true)

        let data = try viewModel.projectData()
        let restored = makeViewModel()
        try restored.loadProjectData(data)
        #expect(restored.document.savedPaths.first?.isVisible == true)

        var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var savedPaths = try #require(json["savedPaths"] as? [[String: Any]])
        savedPaths[0].removeValue(forKey: "isVisible")
        json["savedPaths"] = savedPaths
        let legacyData = try JSONSerialization.data(withJSONObject: json)
        let legacy = makeViewModel()
        try legacy.loadProjectData(legacyData)
        #expect(legacy.document.savedPaths.first?.isVisible == false)
    }

    @Test func selectedSavedPathExposesReadOnlyAnchorAndControlGeometry() throws {
        let viewModel = makeViewModel()
        let first = ImageEditorPathAnchor(
            point: CGPoint(x: 14, y: 18),
            outControl: CGPoint(x: 24, y: 10)
        )
        let second = ImageEditorPathAnchor(
            point: CGPoint(x: 58, y: 42),
            inControl: CGPoint(x: 46, y: 50)
        )
        let saved = ImageEditorSavedPath(
            name: "Curve Structure",
            subpaths: [[first, second]],
            isClosed: false
        )
        viewModel.document.savedPaths = [saved]
        viewModel.document.selectedSavedPathID = saved.id
        let historyCount = viewModel.document.history.count
        let layerCount = viewModel.document.layers.count

        let items = viewModel.selectedSavedPathAnchorOverlayItems
        #expect(items.count == 2)
        #expect(items[0].subpathIndex == 0)
        #expect(items[0].anchorIndex == 0)
        #expect(items[0].point == first.point)
        #expect(items[0].outControl == first.outControl)
        #expect(items[1].inControl == second.inControl)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.document.layers.count == layerCount)

        viewModel.document.areExtrasVisible = false
        #expect(viewModel.selectedSavedPathAnchorOverlayItems.isEmpty)
    }

    @Test func savedPathCopiesAndPastesAsIndependentGeometryWithoutChangingCopyHistory() throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("xomo-tests.saved-path-copy"))
        defer { pasteboard.clearContents() }
        let viewModel = makeViewModel()
        let saved = ImageEditorSavedPath(
            name: "Curve",
            subpaths: [[
                ImageEditorPathAnchor(
                    point: CGPoint(x: 12, y: 18),
                    outControl: CGPoint(x: 24, y: 8)
                ),
                ImageEditorPathAnchor(
                    point: CGPoint(x: 62, y: 44),
                    inControl: CGPoint(x: 48, y: 54)
                )
            ]],
            isClosed: false,
            isVisible: true
        )
        viewModel.document.savedPaths = [saved]
        viewModel.document.selectedSavedPathID = saved.id
        let historyCount = viewModel.document.history.count

        #expect(viewModel.copySavedPath(saved.id, to: pasteboard))
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.document.savedPaths == [saved])
        #expect(viewModel.canPasteSavedPath(from: pasteboard))

        let pasted = try #require(viewModel.pasteSavedPath(from: pasteboard))
        #expect(pasted.id != saved.id)
        #expect(pasted.name == saved.name + L10n.text("imageEditor.savedPath.copySuffix"))
        #expect(pasted.subpaths == saved.subpaths)
        #expect(pasted.isClosed == saved.isClosed)
        #expect(!pasted.isVisible)
        #expect(viewModel.document.selectedSavedPathID == pasted.id)
        #expect(viewModel.document.history.count == historyCount + 1)

        viewModel.undo()
        #expect(viewModel.document.savedPaths == [saved])
        viewModel.redo()
        #expect(viewModel.document.savedPaths.last?.id == pasted.id)
    }

    @Test func savedPathPasteRejectsInvalidClipboardAndCapacityWithoutMutation() throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("xomo-tests.saved-path-invalid"))
        defer { pasteboard.clearContents() }
        let viewModel = makeViewModel()
        let initialHistoryCount = viewModel.document.history.count

        pasteboard.clearContents()
        pasteboard.setData(Data("not-json".utf8), forType: .xomoSavedPath)
        #expect(!viewModel.canPasteSavedPath(from: pasteboard))
        #expect(viewModel.pasteSavedPath(from: pasteboard) == nil)
        #expect(viewModel.document.savedPaths.isEmpty)
        #expect(viewModel.document.history.count == initialHistoryCount)

        let source = makeViewModel()
        createPath(
            points: [CGPoint(x: 8, y: 8), CGPoint(x: 64, y: 12), CGPoint(x: 36, y: 52)],
            closed: true,
            viewModel: source
        )
        let saved = try #require(source.saveCurrentPath(name: "Capacity Path"))
        #expect(source.copySavedPath(saved.id, to: pasteboard))
        viewModel.document.savedPaths = (0..<ImageEditorSavedPath.maximumCount).map { index in
            ImageEditorSavedPath(
                name: "Stored \(index)",
                subpaths: saved.subpaths,
                isClosed: true
            )
        }
        let fullPaths = viewModel.document.savedPaths

        #expect(viewModel.pasteSavedPath(from: pasteboard) == nil)
        #expect(viewModel.document.savedPaths == fullPaths)
        #expect(viewModel.document.history.count == initialHistoryCount)
    }

    @Test func savedPathDuplicatesAdjacentIndependentCopyWithUndo() throws {
        let viewModel = makeViewModel()
        let saved = ImageEditorSavedPath(
            name: "Curve",
            subpaths: [[
                ImageEditorPathAnchor(
                    point: CGPoint(x: 12, y: 18),
                    outControl: CGPoint(x: 24, y: 8)
                ),
                ImageEditorPathAnchor(
                    point: CGPoint(x: 62, y: 44),
                    inControl: CGPoint(x: 48, y: 54)
                )
            ]],
            isClosed: false,
            isVisible: true
        )
        let trailing = ImageEditorSavedPath(
            name: "Trailing",
            subpaths: saved.subpaths,
            isClosed: false
        )
        viewModel.document.savedPaths = [saved, trailing]
        viewModel.document.selectedSavedPathID = saved.id
        let historyCount = viewModel.document.history.count

        #expect(viewModel.canDuplicateSelectedSavedPath)
        let duplicate = try #require(viewModel.duplicateSavedPath(saved.id))
        #expect(duplicate.id != saved.id)
        #expect(duplicate.name == saved.name + L10n.text("imageEditor.savedPath.copySuffix"))
        #expect(duplicate.subpaths == saved.subpaths)
        #expect(duplicate.isClosed == saved.isClosed)
        #expect(!duplicate.isVisible)
        #expect(viewModel.document.savedPaths.map(\.id) == [saved.id, duplicate.id, trailing.id])
        #expect(viewModel.document.selectedSavedPathID == duplicate.id)
        #expect(viewModel.document.history.count == historyCount + 1)

        viewModel.undo()
        #expect(viewModel.document.savedPaths.map(\.id) == [saved.id, trailing.id])
        viewModel.redo()
        #expect(viewModel.document.savedPaths.map(\.id) == [saved.id, duplicate.id, trailing.id])
    }

    @Test func savedPathDuplicateRejectsCapacityWithoutMutation() {
        let viewModel = makeViewModel()
        let anchors = [[
            ImageEditorPathAnchor(point: CGPoint(x: 8, y: 8)),
            ImageEditorPathAnchor(point: CGPoint(x: 64, y: 12))
        ]]
        viewModel.document.savedPaths = (0..<ImageEditorSavedPath.maximumCount).map { index in
            ImageEditorSavedPath(name: "Stored \(index)", subpaths: anchors, isClosed: false)
        }
        let selectedID = viewModel.document.savedPaths[4].id
        viewModel.document.selectedSavedPathID = selectedID
        let originalPaths = viewModel.document.savedPaths
        let historyCount = viewModel.document.history.count

        #expect(!viewModel.canDuplicateSelectedSavedPath)
        #expect(viewModel.duplicateSavedPath(selectedID) == nil)
        #expect(viewModel.document.savedPaths == originalPaths)
        #expect(viewModel.document.selectedSavedPathID == selectedID)
        #expect(viewModel.document.history.count == historyCount)
    }

    @Test func savedPathOrderMovesWithUndoAndControlsOverlayStacking() throws {
        let viewModel = makeViewModel()
        let anchors = [[
            ImageEditorPathAnchor(point: CGPoint(x: 8, y: 8)),
            ImageEditorPathAnchor(point: CGPoint(x: 64, y: 12)),
            ImageEditorPathAnchor(point: CGPoint(x: 36, y: 52))
        ]]
        let first = ImageEditorSavedPath(name: "First", subpaths: anchors, isClosed: true, isVisible: true)
        let second = ImageEditorSavedPath(name: "Second", subpaths: anchors, isClosed: true, isVisible: true)
        let third = ImageEditorSavedPath(name: "Third", subpaths: anchors, isClosed: true, isVisible: true)
        viewModel.document.savedPaths = [first, second, third]
        viewModel.document.selectedSavedPathID = second.id
        let historyCount = viewModel.document.history.count

        #expect(viewModel.canMoveSelectedSavedPathUp)
        #expect(viewModel.canMoveSelectedSavedPathDown)
        #expect(viewModel.moveSavedPathUp(second.id))
        #expect(viewModel.document.savedPaths.map(\.id) == [second.id, first.id, third.id])
        #expect(viewModel.savedPathCanvasOverlays.map(\.id) == [second.id, first.id, third.id])
        #expect(viewModel.document.selectedSavedPathID == second.id)
        #expect(viewModel.document.history.count == historyCount + 1)

        viewModel.undo()
        #expect(viewModel.document.savedPaths.map(\.id) == [first.id, second.id, third.id])
        viewModel.redo()
        #expect(viewModel.document.savedPaths.map(\.id) == [second.id, first.id, third.id])
        #expect(viewModel.moveSavedPathDown(second.id))
        #expect(viewModel.document.savedPaths.map(\.id) == [first.id, second.id, third.id])
    }

    @Test func savedPathOrderRejectsEdgesWithoutHistory() {
        let viewModel = makeViewModel()
        let anchors = [[
            ImageEditorPathAnchor(point: CGPoint(x: 8, y: 8)),
            ImageEditorPathAnchor(point: CGPoint(x: 64, y: 12)),
            ImageEditorPathAnchor(point: CGPoint(x: 36, y: 52))
        ]]
        let first = ImageEditorSavedPath(name: "First", subpaths: anchors, isClosed: true)
        let second = ImageEditorSavedPath(name: "Second", subpaths: anchors, isClosed: true)
        viewModel.document.savedPaths = [first, second]
        let historyCount = viewModel.document.history.count

        viewModel.document.selectedSavedPathID = first.id
        #expect(!viewModel.canMoveSelectedSavedPathUp)
        #expect(!viewModel.canMoveSelectedSavedPathToTop)
        #expect(!viewModel.moveSavedPathUp(first.id))
        #expect(!viewModel.moveSavedPathToTop(first.id))
        viewModel.document.selectedSavedPathID = second.id
        #expect(!viewModel.canMoveSelectedSavedPathDown)
        #expect(!viewModel.canMoveSelectedSavedPathToBottom)
        #expect(!viewModel.moveSavedPathDown(second.id))
        #expect(!viewModel.moveSavedPathToBottom(second.id))
        #expect(viewModel.document.savedPaths.map(\.id) == [first.id, second.id])
        #expect(viewModel.document.history.count == historyCount)
    }

    @Test func savedPathOrderJumpsToTopAndBottomWithSingleUndoSteps() {
        let viewModel = makeViewModel()
        let anchors = [[
            ImageEditorPathAnchor(point: CGPoint(x: 8, y: 8)),
            ImageEditorPathAnchor(point: CGPoint(x: 64, y: 12)),
            ImageEditorPathAnchor(point: CGPoint(x: 36, y: 52))
        ]]
        let first = ImageEditorSavedPath(name: "First", subpaths: anchors, isClosed: true, isVisible: true)
        let second = ImageEditorSavedPath(name: "Second", subpaths: anchors, isClosed: true, isVisible: true)
        let third = ImageEditorSavedPath(name: "Third", subpaths: anchors, isClosed: true, isVisible: true)
        let fourth = ImageEditorSavedPath(name: "Fourth", subpaths: anchors, isClosed: true, isVisible: true)
        viewModel.document.savedPaths = [first, second, third, fourth]
        viewModel.document.selectedSavedPathID = third.id
        let historyCount = viewModel.document.history.count

        #expect(viewModel.canMoveSelectedSavedPathToTop)
        #expect(viewModel.canMoveSelectedSavedPathToBottom)
        #expect(viewModel.moveSavedPathToTop(third.id))
        #expect(viewModel.document.savedPaths.map(\.id) == [third.id, first.id, second.id, fourth.id])
        #expect(viewModel.savedPathCanvasOverlays.map(\.id) == [third.id, first.id, second.id, fourth.id])
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(!viewModel.canMoveSelectedSavedPathToTop)

        viewModel.undo()
        #expect(viewModel.document.savedPaths.map(\.id) == [first.id, second.id, third.id, fourth.id])
        viewModel.redo()
        #expect(viewModel.document.savedPaths.map(\.id) == [third.id, first.id, second.id, fourth.id])
        #expect(viewModel.moveSavedPathToBottom(third.id))
        #expect(viewModel.document.savedPaths.map(\.id) == [first.id, second.id, fourth.id, third.id])
        #expect(!viewModel.canMoveSelectedSavedPathToBottom)
    }

    @Test func savedPathMovesToExactIndexWithSingleUndoAndRejectsInvalidDestinations() {
        let viewModel = makeViewModel()
        let anchors = [[
            ImageEditorPathAnchor(point: CGPoint(x: 8, y: 8)),
            ImageEditorPathAnchor(point: CGPoint(x: 64, y: 12)),
            ImageEditorPathAnchor(point: CGPoint(x: 36, y: 52))
        ]]
        let first = ImageEditorSavedPath(name: "First", subpaths: anchors, isClosed: true)
        let second = ImageEditorSavedPath(name: "Second", subpaths: anchors, isClosed: true)
        let third = ImageEditorSavedPath(name: "Third", subpaths: anchors, isClosed: true)
        let fourth = ImageEditorSavedPath(name: "Fourth", subpaths: anchors, isClosed: true)
        viewModel.document.savedPaths = [first, second, third, fourth]
        let historyCount = viewModel.document.history.count

        #expect(viewModel.moveSavedPath(first.id, toIndex: 2))
        #expect(viewModel.document.savedPaths.map(\.id) == [second.id, third.id, first.id, fourth.id])
        #expect(viewModel.document.selectedSavedPathID == first.id)
        #expect(viewModel.document.history.count == historyCount + 1)

        viewModel.undo()
        #expect(viewModel.document.savedPaths.map(\.id) == [first.id, second.id, third.id, fourth.id])
        viewModel.redo()
        #expect(viewModel.document.savedPaths.map(\.id) == [second.id, third.id, first.id, fourth.id])

        let movedPaths = viewModel.document.savedPaths
        #expect(!viewModel.moveSavedPath(first.id, toIndex: 2))
        #expect(!viewModel.moveSavedPath(first.id, toIndex: -1))
        #expect(!viewModel.moveSavedPath(first.id, toIndex: movedPaths.count))
        #expect(viewModel.document.savedPaths == movedPaths)
        #expect(viewModel.document.history.count == historyCount + 1)
    }

    @Test func savedPathDropGeometryAccountsForRemovalBeforeInsertion() {
        #expect(ImageEditorSavedPathDropGeometry.destinationIndex(
            sourceIndex: 0,
            targetIndex: 2,
            placement: .above,
            count: 4
        ) == 1)
        #expect(ImageEditorSavedPathDropGeometry.destinationIndex(
            sourceIndex: 0,
            targetIndex: 2,
            placement: .below,
            count: 4
        ) == 2)
        #expect(ImageEditorSavedPathDropGeometry.destinationIndex(
            sourceIndex: 3,
            targetIndex: 1,
            placement: .above,
            count: 4
        ) == 1)
        #expect(ImageEditorSavedPathDropGeometry.destinationIndex(
            sourceIndex: 3,
            targetIndex: 1,
            placement: .below,
            count: 4
        ) == 2)
        #expect(ImageEditorSavedPathDropGeometry.destinationIndex(
            sourceIndex: 2,
            targetIndex: 2,
            placement: .above,
            count: 4
        ) == nil)
        #expect(ImageEditorSavedPathDropGeometry.destinationIndex(
            sourceIndex: -1,
            targetIndex: 2,
            placement: .above,
            count: 4
        ) == nil)
        #expect(ImageEditorSavedPathDropGeometry.destinationIndex(
            sourceIndex: 0,
            targetIndex: 4,
            placement: .below,
            count: 4
        ) == nil)
    }

    @Test func savedPathsRoundTripProjectsAndOlderProjectsDefaultToEmpty() throws {
        let viewModel = makeViewModel()
        createPath(
            points: [CGPoint(x: 8, y: 9), CGPoint(x: 64, y: 11), CGPoint(x: 38, y: 50)],
            closed: false,
            viewModel: viewModel
        )
        let saved = try #require(viewModel.saveCurrentPath(name: "Open Curve"))
        let data = try viewModel.projectData()
        let project = try JSONDecoder().decode(ImageEditorProjectDocument.self, from: data)
        #expect(project.formatVersion == ImageEditorProjectDocument.formatVersion)

        let restored = makeViewModel()
        try restored.loadProjectData(data)
        #expect(restored.document.savedPaths == [saved])
        #expect(restored.document.selectedSavedPathID == saved.id)

        var legacyJSON = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        legacyJSON.removeValue(forKey: "savedPaths")
        legacyJSON.removeValue(forKey: "selectedSavedPathID")
        legacyJSON["formatVersion"] = 5
        let legacyData = try JSONSerialization.data(withJSONObject: legacyJSON)
        let legacy = makeViewModel()
        try legacy.loadProjectData(legacyData)
        #expect(legacy.document.savedPaths.isEmpty)
        #expect(legacy.document.selectedSavedPathID == nil)
    }

    @Test func pathsPanelMenuProjectAndAutomationUseSavedPathCommands() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let panel = try source(root, "veilpic/ImageEditorLayerPanel.swift")
        let channels = try source(root, "veilpic/ImageEditorChannels.swift")
        let menu = try source(root, "veilpic/ImageEditorMenuBar.swift")
        let project = try source(root, "veilpic/ImageEditorProjectDocument.swift")
        let automation = try source(root, "veilpic/XomoAutomationRegistry.swift")

        #expect(channels.contains("case paths"))
        #expect(panel.contains("savedPathsPanelContent"))
        #expect(panel.contains("viewModel.saveCurrentPath"))
        #expect(panel.contains("viewModel.loadSavedPath"))
        #expect(panel.contains("viewModel.loadSelectionFromSavedPath"))
        #expect(panel.contains("viewModel.fillSavedPathToSelectedPixelLayer"))
        #expect(panel.contains("viewModel.strokeSavedPathToSelectedPixelLayer"))
        #expect(panel.contains("viewModel.copySavedPath"))
        #expect(panel.contains("viewModel.pasteSavedPath"))
        #expect(panel.contains("viewModel.duplicateSavedPath"))
        #expect(panel.contains("viewModel.moveSavedPathUp"))
        #expect(panel.contains("viewModel.moveSavedPathDown"))
        #expect(panel.contains("viewModel.moveSavedPathToTop"))
        #expect(panel.contains("viewModel.moveSavedPathToBottom"))
        #expect(panel.contains("ImageEditorSavedPathDropDelegate"))
        #expect(panel.contains("savedPathDropBand"))
        #expect(panel.contains("viewModel.moveSavedPath(sourceID, toIndex: destinationIndex)"))
        #expect(panel.contains("text: savedPathNameBinding(savedPath)"))
        #expect(panel.contains(".foregroundStyle(Color(nsColor: ImageEditorTheme.text))"))
        #expect(menu.contains("selectedLayerPanelTab = .paths"))
        #expect(menu.contains("viewModel.loadSelectionFromSavedPath"))
        #expect(menu.contains("viewModel.fillSavedPathToSelectedPixelLayer"))
        #expect(menu.contains("viewModel.strokeSavedPathToSelectedPixelLayer"))
        #expect(menu.contains("viewModel.copySavedPath"))
        #expect(menu.contains("viewModel.pasteSavedPath"))
        #expect(menu.contains("viewModel.duplicateSavedPath"))
        #expect(menu.contains("viewModel.moveSavedPathUp"))
        #expect(menu.contains("viewModel.moveSavedPathDown"))
        #expect(menu.contains("viewModel.moveSavedPathToTop"))
        #expect(menu.contains("viewModel.moveSavedPathToBottom"))
        let canvas = try source(root, "veilpic/ImageEditorView.swift")
        #expect(canvas.contains("savedPathOverlay(in: geometry.size)"))
        #expect(canvas.contains("viewModel.savedPathCanvasOverlays"))
        #expect(canvas.contains("viewModel.selectedSavedPathAnchorOverlayItems"))
        #expect(canvas.contains("path.addCurve"))
        #expect(canvas.contains("handleLine"))
        #expect(canvas.contains(".allowsHitTesting(false)"))
        #expect(project.contains("savedPaths"))
        #expect(automation.contains("xomo.path.saved"))
        #expect(automation.contains("case \"selection\""))
        #expect(automation.contains("case \"fill\""))
        #expect(automation.contains("case \"stroke\""))
        #expect(automation.contains("case \"visibility\""))
        #expect(automation.contains("case \"duplicate\""))
    }

    private func createPath(
        points: [CGPoint],
        closed: Bool,
        viewModel: ImageEditorViewModel
    ) {
        points.forEach(viewModel.addPenPoint)
        viewModel.finishPenPath(closed: closed)
    }

    private func makeViewModel() -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "saved-paths.png",
            image: NSImage.transparent(size: NSSize(width: 96, height: 72))
        ) { _ in }
    }

    private func rectangleAnchors(_ rect: CGRect) -> [ImageEditorPathAnchor] {
        [
            ImageEditorPathAnchor(point: CGPoint(x: rect.minX, y: rect.minY)),
            ImageEditorPathAnchor(point: CGPoint(x: rect.maxX, y: rect.minY)),
            ImageEditorPathAnchor(point: CGPoint(x: rect.maxX, y: rect.maxY)),
            ImageEditorPathAnchor(point: CGPoint(x: rect.minX, y: rect.maxY))
        ]
    }

    private func alphaSplitImage(size: NSSize) -> NSImage {
        NSImage.rendered(size: size) { rect in
            NSColor.clear.setFill()
            rect.fill()
            NSColor.systemRed.setFill()
            CGRect(x: rect.midX, y: rect.minY, width: rect.width / 2, height: rect.height).fill()
        } ?? NSImage.transparent(size: size)
    }

    private func source(_ root: URL, _ path: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }
}
