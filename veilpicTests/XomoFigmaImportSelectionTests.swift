import AppKit
import Testing
@testable import musepic

@MainActor
struct XomoFigmaImportSelectionTests {
    @Test func importedHierarchyOwnsDeleteAndRestoresSelectionThroughHistory() throws {
        let model = makeModel()
        let beforeIDs = model.document.layers.map(\.id)
        let beforeSelection = ImageEditorSelection.rectangle(CGRect(x: 2, y: 3, width: 12, height: 10))
        model.document.selection = beforeSelection
        let historyCount = model.document.history.count

        #expect(model.importFigmaNodePlan(try plan()))
        let rootID = try #require(model.document.selectedLayerID)
        let importedIDs = Set(model.document.layers.map(\.id)).subtracting(beforeIDs)
        #expect(importedIDs.count == 2)
        #expect(model.document.selection == nil)
        #expect(model.reselectableSelection == beforeSelection)
        #expect(model.document.selectedLayerIDs == [rootID])
        #expect(model.document.history.count == historyCount + 1)
        #expect(model.deleteSelectedLayerFromKeyboardIfPossible())
        #expect(model.document.layers.map(\.id) == beforeIDs)

        model.undo()
        #expect(importedIDs.isSubset(of: Set(model.document.layers.map(\.id))))
        #expect(model.document.selectedLayerID == rootID)
        #expect(model.document.selection == nil)
        model.undo()
        #expect(model.document.layers.map(\.id) == beforeIDs)
        #expect(model.document.selection == beforeSelection)
        model.redo()
        #expect(model.document.selectedLayerID == rootID)
        #expect(model.document.selection == nil)
        model.redo()
        #expect(model.document.layers.map(\.id) == beforeIDs)
    }

    @Test(arguments: [false, true])
    func staleDeliverySelectionDoesNotConsumeImportedLayerDelete(hotspot: Bool) throws {
        let model = makeModel()
        let oldSlice = ImageEditorSlice(name: "Old slice", frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        let oldHotspot = ImageEditorHotspot(name: "Old hotspot", frame: oldSlice.frame, url: "https://example.com")
        model.document.slices = [oldSlice]
        model.document.hotspots = [oldHotspot]
        if hotspot {
            model.selectedHotspotID = oldHotspot.id
        } else {
            model.exportSettings.scope = .slice
            model.exportSettings.sliceID = oldSlice.id
        }

        #expect(model.importFigmaNodePlan(try plan()))
        let importedID = try #require(model.document.selectedLayerID)
        #expect(model.selectedHotspotID == nil)
        #expect(model.exportSettings.scope != .slice)
        #expect(!model.deleteSelectedDeliveryObjectIfNeeded())
        #expect(model.document.slices.map(\.id) == [oldSlice.id])
        #expect(model.document.hotspots.map(\.id) == [oldHotspot.id])
        #expect(model.deleteSelectedLayerFromKeyboardIfPossible())
        #expect(!model.document.layers.contains { $0.id == importedID })
    }

    @Test func importingAnObjectLeavesQuickMaskAndPreservesReselect() throws {
        let model = makeModel()
        let selection = ImageEditorSelection.rectangle(CGRect(x: 3, y: 4, width: 9, height: 8))
        model.document.selection = selection
        model.foregroundColor = .systemRed
        model.toggleQuickMaskMode()
        #expect(model.isQuickMaskMode)

        #expect(model.importFigmaNodePlan(try plan()))
        #expect(!model.isQuickMaskMode)
        #expect(model.document.selection == nil)
        #expect(model.reselectableSelection == selection)
        #expect(model.foregroundColor == NSColor.systemRed)
    }

    @Test func importedTextSynchronizesInspectorAndLeavesOldMaskPreview() throws {
        let model = makeModel()
        let oldID = try #require(model.document.selectedLayerID)
        let index = try #require(model.document.layers.firstIndex { $0.id == oldID })
        model.document.layers[index].mask = .transparent(size: model.document.canvasSize)
        #expect(model.toggleLayerMaskSoloPreview(layerID: oldID))
        model.textValue = "Old text"
        model.textSize = 99

        #expect(model.importFigmaNodePlan(try plan(type: "TEXT")))
        let content = try #require(model.document.selectedLayer?.textContent)
        #expect(model.textValue == content.text)
        #expect(model.textSize == Double(content.fontSize))
        #expect(!model.isEditingLayerMask)
        #expect(model.previewedLayerMaskID == nil)
    }

    @Test func importedRootBecomesTheRangeSelectionAnchor() throws {
        let model = makeModel()
        let oldID = try #require(model.document.selectedLayerID)
        let other = ImageEditorLayer.blank(name: "Other", size: model.document.canvasSize)
        model.document.layers.append(other)
        model.selectLayer(other.id)
        model.selectLayer(oldID)

        #expect(model.importFigmaNodePlan(try plan()))
        let rootID = try #require(model.document.selectedLayerID)
        model.selectLayerRange(to: rootID, among: model.document.layers.reversed().map(\.id))
        #expect(model.document.selectedLayerIDs == [rootID])
    }

    @Test func sliceOnlyImportPreservesPixelAndLayerSelection() throws {
        let model = makeModel()
        let selection = ImageEditorSelection.rectangle(CGRect(x: 2, y: 3, width: 12, height: 10))
        model.document.selection = selection
        let selectedID = model.document.selectedLayerID
        let layerIDs = model.document.layers.map(\.id)

        #expect(model.importFigmaNodePlan(try plan(type: "SLICE")))
        #expect(model.document.layers.map(\.id) == layerIDs)
        #expect(model.document.selectedLayerID == selectedID)
        #expect(model.document.selection == selection)
        #expect(model.exportSettings.scope == .slice)
        #expect(model.document.slices.count == 1)
    }

    @Test func newExportPresetStillOwnsItsImportedSlice() throws {
        let model = makeModel()
        let hotspot = ImageEditorHotspot(name: "Old", frame: CGRect(x: 0, y: 0, width: 8, height: 8), url: "https://example.com")
        model.document.hotspots = [hotspot]
        model.selectedHotspotID = hotspot.id
        #expect(model.importFigmaNodePlan(try plan(exportPreset: true)))
        #expect(model.selectedHotspotID == nil)
        #expect(model.exportSettings.scope == .slice)
        #expect(model.exportSettings.scale == 2)
        #expect(model.document.slices.contains { $0.id == model.exportSettings.sliceID })
        #expect(model.deleteSelectedDeliveryObjectIfNeeded())
        #expect(model.document.slices.isEmpty)
        #expect(model.document.hotspots.map(\.id) == [hotspot.id])
    }

    @Test func emptyImportDoesNotChangeSelectionOrHistory() throws {
        let model = makeModel()
        var empty = try plan()
        empty.items = []
        let selection = ImageEditorSelection.rectangle(CGRect(x: 2, y: 3, width: 12, height: 10))
        model.document.selection = selection
        model.toggleQuickMaskMode()
        let selectedID = model.document.selectedLayerID
        let historyCount = model.document.history.count

        #expect(!model.importFigmaNodePlan(empty))
        #expect(model.document.selection == selection)
        #expect(model.isQuickMaskMode)
        #expect(model.document.selectedLayerID == selectedID)
        #expect(model.document.history.count == historyCount)
    }

    private func makeModel() -> ImageEditorViewModel {
        ImageEditorViewModel(sourceName: "fixture.png", image: .transparent(size: CGSize(width: 200, height: 160))) { _ in }
    }

    private func plan(type: String = "FRAME", exportPreset: Bool = false) throws -> XomoFigmaNodeImportPlan {
        let children = type == "FRAME" ? #"""
        ,"children":[{"id":"2:1","name":"Child","type":"RECTANGLE",
          "absoluteBoundingBox":{"x":1,"y":1,"width":20,"height":10}}]
        """# : ""
        let presets = exportPreset ? #"""
        ,"exportSettings":[{"suffix":"@2x","format":"PNG","constraint":{"type":"SCALE","value":2}}]
        """# : ""
        let data = Data("""
        {"name":"Fixture","nodes":{"1:3":{"document":{
          "id":"1:3","name":"Imported","type":"\(type)",
          "absoluteBoundingBox":{"x":0,"y":0,"width":100,"height":50},
          "characters":"New text","style":{"fontFamily":"Helvetica","fontSize":18}
          \(children)\(presets)
        }}}}
        """.utf8)
        return try XomoFigmaNodeImportMapper.makePlan(
            response: JSONDecoder().decode(XomoFigmaNodeResponse.self, from: data),
            requestedNodeID: "1:3"
        )
    }
}
