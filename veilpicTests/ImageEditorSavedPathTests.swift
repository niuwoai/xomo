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
        #expect(project.formatVersion == 6)

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
        #expect(panel.contains("text: savedPathNameBinding(savedPath)"))
        #expect(panel.contains(".foregroundStyle(Color(nsColor: ImageEditorTheme.text))"))
        #expect(menu.contains("selectedLayerPanelTab = .paths"))
        #expect(menu.contains("viewModel.loadSelectionFromSavedPath"))
        #expect(project.contains("savedPaths"))
        #expect(automation.contains("xomo.path.saved"))
        #expect(automation.contains("case \"selection\""))
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

    private func source(_ root: URL, _ path: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }
}
