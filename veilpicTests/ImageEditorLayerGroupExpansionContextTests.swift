import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorLayerGroupExpansionContextTests {
    @Test func unselectedGroupContextRecursivelyCollapsesOnlyClickedBranch() {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        viewModel.selectLayer(fixture.outsideID)
        let historyBefore = viewModel.document.history
        let canUndoBefore = viewModel.canUndo
        let canRedoBefore = viewModel.canRedo

        #expect(viewModel.canSetLayerGroupsExpansionFromContext(
            fixture.parentID,
            expanded: false
        ))
        #expect(viewModel.setLayerGroupsExpansionFromContext(
            fixture.parentID,
            expanded: false
        ))
        #expect(groupExpansion(fixture.parentID, in: viewModel) == false)
        #expect(groupExpansion(fixture.childID, in: viewModel) == false)
        #expect(viewModel.document.selectedLayerIDs == [fixture.parentID])
        #expect(viewModel.document.selectedLayerID == fixture.parentID)
        #expect(viewModel.document.history == historyBefore)
        #expect(viewModel.canUndo == canUndoBefore)
        #expect(viewModel.canRedo == canRedoBefore)
    }

    @Test func selectedGroupContextPreservesVisiblePeerAndExpandsWholeBranch() throws {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        let parentIndex = try #require(
            viewModel.document.layers.firstIndex { $0.id == fixture.parentID }
        )
        let childIndex = try #require(
            viewModel.document.layers.firstIndex { $0.id == fixture.childID }
        )
        viewModel.document.layers[parentIndex].isGroupExpanded = false
        viewModel.document.layers[childIndex].isGroupExpanded = false
        viewModel.document.selectedLayerIDs = [fixture.parentID, fixture.outsideID]
        viewModel.document.selectedLayerID = fixture.outsideID

        #expect(viewModel.setLayerGroupsExpansionFromContext(
            fixture.parentID,
            expanded: true
        ))
        #expect(groupExpansion(fixture.parentID, in: viewModel) == true)
        #expect(groupExpansion(fixture.childID, in: viewModel) == true)
        #expect(viewModel.document.selectedLayerIDs == [
            fixture.parentID,
            fixture.outsideID
        ])
        #expect(viewModel.document.selectedLayerID == fixture.outsideID)
    }

    @Test func ordinaryInvalidAndRepeatedContextExpansionAreAtomicNoOps() {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        let layerIDsBefore = viewModel.document.layers.map(\.id)
        let selectedIDsBefore = viewModel.document.selectedLayerIDs
        let primaryIDBefore = viewModel.document.selectedLayerID
        let historyBefore = viewModel.document.history
        let unknownID = UUID()

        #expect(!viewModel.canSetLayerGroupsExpansionFromContext(
            fixture.parentID,
            expanded: true
        ))
        #expect(!viewModel.setLayerGroupsExpansionFromContext(
            fixture.parentID,
            expanded: true
        ))
        #expect(!viewModel.canSetLayerGroupsExpansionFromContext(
            fixture.outsideID,
            expanded: false
        ))
        #expect(!viewModel.setLayerGroupsExpansionFromContext(
            fixture.outsideID,
            expanded: false
        ))
        #expect(!viewModel.canSetLayerGroupsExpansionFromContext(
            unknownID,
            expanded: false
        ))
        #expect(!viewModel.setLayerGroupsExpansionFromContext(
            unknownID,
            expanded: false
        ))
        #expect(viewModel.document.layers.map(\.id) == layerIDsBefore)
        #expect(viewModel.document.selectedLayerIDs == selectedIDsBefore)
        #expect(viewModel.document.selectedLayerID == primaryIDBefore)
        #expect(viewModel.document.history == historyBefore)
    }

    private struct Fixture {
        let viewModel: ImageEditorViewModel
        let parentID: UUID
        let childID: UUID
        let leafID: UUID
        let outsideID: UUID
    }

    private func makeFixture() -> Fixture {
        let canvasSize = CGSize(width: 160, height: 100)
        let viewModel = ImageEditorViewModel(
            sourceName: "group-context.png",
            image: NSImage.transparent(size: canvasSize)
        ) { _ in }
        var parent = ImageEditorLayer.group(name: "Parent", size: canvasSize)
        var child = ImageEditorLayer.group(name: "Child", size: canvasSize)
        var leaf = ImageEditorLayer.blank(name: "Leaf", size: canvasSize)
        let outside = ImageEditorLayer.blank(name: "Outside", size: canvasSize)
        child.groupID = parent.id
        leaf.groupID = child.id
        parent.isGroupExpanded = true
        child.isGroupExpanded = true
        viewModel.document.layers = [leaf, child, parent, outside]
        viewModel.document.selectedLayerID = parent.id
        viewModel.document.selectedLayerIDs = [parent.id]
        return Fixture(
            viewModel: viewModel,
            parentID: parent.id,
            childID: child.id,
            leafID: leaf.id,
            outsideID: outside.id
        )
    }

    private func groupExpansion(
        _ id: UUID,
        in viewModel: ImageEditorViewModel
    ) -> Bool? {
        viewModel.document.layers.first { $0.id == id }?.isGroupExpanded
    }
}
