import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
@Suite
struct ImageEditorStackLayoutTests {
    @Test func verticalLayoutHonorsPaddingSpacingAndCrossAlignment() {
        let frames = ImageEditorStackLayoutEngine.frames(
            in: CGRect(x: 10, y: 20, width: 200, height: 160),
            itemFrames: [
                CGRect(x: 0, y: 0, width: 30, height: 20),
                CGRect(x: 0, y: 0, width: 50, height: 30)
            ],
            layout: ImageEditorStackLayout(
                axis: .vertical,
                spacing: 10,
                paddingTop: 10,
                paddingRight: 20,
                paddingBottom: 10,
                paddingLeft: 20,
                crossAlignment: .center
            )
        )

        #expect(frames == [
            CGRect(x: 95, y: 30, width: 30, height: 20),
            CGRect(x: 85, y: 60, width: 50, height: 30)
        ])
    }

    @Test func horizontalLayoutSupportsSpaceBetweenAndEndAlignment() {
        let frames = ImageEditorStackLayoutEngine.frames(
            in: CGRect(x: 0, y: 0, width: 200, height: 100),
            itemFrames: [
                CGRect(x: 0, y: 0, width: 20, height: 10),
                CGRect(x: 0, y: 0, width: 40, height: 20),
                CGRect(x: 0, y: 0, width: 30, height: 30)
            ],
            layout: ImageEditorStackLayout(
                axis: .horizontal,
                paddingTop: 10,
                paddingRight: 10,
                paddingBottom: 10,
                paddingLeft: 10,
                primaryAlignment: .spaceBetween,
                crossAlignment: .end
            )
        )

        #expect(frames == [
            CGRect(x: 10, y: 80, width: 20, height: 10),
            CGRect(x: 75, y: 70, width: 40, height: 20),
            CGRect(x: 160, y: 60, width: 30, height: 30)
        ])
    }

    @Test func reflowMovesDirectChildrenAndNestedSubtreeButNotExcludedBackground() throws {
        let fixture = makeFixture()
        let originalChildFrame = fixture.layer(named: "First").frame
        let originalNestedFrame = fixture.layer(named: "Nested").frame
        let originalDescendantFrame = fixture.layer(named: "Nested Child").frame
        let originalBackgroundFrame = fixture.layer(named: "Background").frame

        fixture.viewModel.reflowSelectedStackLayout()

        #expect(fixture.layer(named: "First").frame == CGRect(x: 95, y: 30, width: 30, height: 20))
        #expect(fixture.layer(named: "Nested").frame == CGRect(x: 85, y: 60, width: 50, height: 30))
        #expect(fixture.layer(named: "Nested Child").frame == CGRect(x: 95, y: 70, width: 10, height: 10))
        #expect(fixture.layer(named: "Background").frame == originalBackgroundFrame)
        #expect(fixture.viewModel.document.history.last?.title == L10n.text("imageEditor.history.stackLayout"))

        fixture.viewModel.undo()
        #expect(fixture.layer(named: "First").frame == originalChildFrame)
        #expect(fixture.layer(named: "Nested").frame == originalNestedFrame)
        #expect(fixture.layer(named: "Nested Child").frame == originalDescendantFrame)

        fixture.viewModel.redo()
        #expect(fixture.layer(named: "First").frame == CGRect(x: 95, y: 30, width: 30, height: 20))
    }

    @Test func stackLayoutAndExclusionSurviveProjectRoundTrip() throws {
        let fixture = makeFixture()
        let projectData = try fixture.viewModel.projectData()
        let reopened = ImageEditorViewModel(
            sourceName: "empty.png",
            image: NSImage.transparent(size: CGSize(width: 8, height: 8))
        ) { _ in }

        try reopened.loadProjectData(projectData)

        let root = try #require(reopened.document.layers.first { $0.name == "Root" })
        let background = try #require(reopened.document.layers.first { $0.name == "Background" })
        #expect(root.stackLayout == ImageEditorStackLayout(
            axis: .vertical,
            spacing: 10,
            paddingTop: 10,
            paddingRight: 20,
            paddingBottom: 10,
            paddingLeft: 20,
            crossAlignment: .center
        ))
        #expect(background.isStackLayoutExcluded)
    }

    @Test func propertyPanelAndLayerTabsKeepExplicitInteractionAndLightTextContracts() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let panelSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorLayerPanel.swift"),
            encoding: .utf8
        )

        #expect(viewSource.contains("image-editor-stack-layout-axis"))
        #expect(viewSource.contains("image-editor-stack-layout-reflow"))
        #expect(viewSource.contains("setSelectedStackSpacing"))
        #expect(panelSource.contains("static let foregroundColor = NSColor.white"))
        #expect(panelSource.contains(".foregroundColor: color"))
    }

    private func makeFixture() -> StackLayoutFixture {
        let viewModel = ImageEditorViewModel(
            sourceName: "stack-layout.png",
            image: NSImage.transparent(size: CGSize(width: 240, height: 200))
        ) { _ in }
        var root = ImageEditorLayer.group(name: "Root", size: viewModel.document.canvasSize)
        root.frame = CGRect(x: 10, y: 20, width: 200, height: 160)
        root.stackLayout = ImageEditorStackLayout(
            axis: .vertical,
            spacing: 10,
            paddingTop: 10,
            paddingRight: 20,
            paddingBottom: 10,
            paddingLeft: 20,
            crossAlignment: .center
        )
        var first = ImageEditorLayer.blank(name: "First", size: CGSize(width: 30, height: 20))
        first.frame = CGRect(x: 30, y: 40, width: 30, height: 20)
        first.groupID = root.id
        var nested = ImageEditorLayer.group(name: "Nested", size: CGSize(width: 50, height: 30))
        nested.frame = CGRect(x: 100, y: 100, width: 50, height: 30)
        nested.groupID = root.id
        var descendant = ImageEditorLayer.blank(name: "Nested Child", size: CGSize(width: 10, height: 10))
        descendant.frame = CGRect(x: 110, y: 110, width: 10, height: 10)
        descendant.groupID = nested.id
        var background = ImageEditorLayer.blank(name: "Background", size: CGSize(width: 200, height: 160))
        background.frame = root.frame
        background.groupID = root.id
        background.isStackLayoutExcluded = true
        viewModel.document.layers = [first, descendant, nested, background, root]
        viewModel.document.selectedLayerID = root.id
        viewModel.document.selectedLayerIDs = [root.id]
        return StackLayoutFixture(viewModel: viewModel)
    }
}

@MainActor
private struct StackLayoutFixture {
    let viewModel: ImageEditorViewModel

    func layer(named name: String) -> ImageEditorLayer {
        guard let layer = viewModel.document.layers.first(where: { $0.name == name }) else {
            fatalError("Missing test layer")
        }
        return layer
    }
}
