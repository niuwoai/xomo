import AppKit
import Testing
@testable import musepic

@MainActor
struct XomoLeftSidebarTests {
    @Test func sidebarHasToolsAndComponentsTabs() {
        #expect(XomoLeftSidebarTab.allCases == [.tools, .components])
        #expect(XomoLeftSidebarTab.tools.symbolName == "wrench.and.screwdriver")
        #expect(XomoLeftSidebarTab.components.symbolName == "square.grid.2x2")
    }

    @Test func componentLibraryExposesEditableStarterComponents() {
        #expect(XomoComponentKind.allCases == [.button, .input, .card, .image])
    }

    @Test func switchingSidebarDoesNotChangeSelectedTool() {
        let image = NSImage.transparent(size: CGSize(width: 20, height: 20))
        let viewModel = ImageEditorViewModel(sourceName: "source", image: image) { _ in }
        viewModel.selectTool(.brush)

        viewModel.selectLeftSidebarTab(.components)

        #expect(viewModel.selectedLeftSidebarTab == .components)
        #expect(viewModel.selectedTool == .brush)

        viewModel.selectLeftSidebarTab(.tools)

        #expect(viewModel.selectedLeftSidebarTab == .tools)
        #expect(viewModel.selectedTool == .brush)
    }

    @Test func insertingButtonCreatesEditableGroupedLayers() throws {
        let image = NSImage.transparent(size: CGSize(width: 640, height: 480))
        let viewModel = ImageEditorViewModel(sourceName: "source", image: image) { _ in }

        viewModel.insertXomoComponent(.button, at: CGPoint(x: 40, y: 60))

        let group = try #require(viewModel.document.selectedLayer)
        #expect(group.isGroup)
        #expect(group.name == XomoComponentKind.button.title)
        let children = viewModel.document.layers.filter { $0.groupID == group.id }
        #expect(children.count == 2)
        #expect(children.contains(where: { $0.isShape }))
        #expect(children.contains(where: { $0.isText && $0.textContent?.text == L10n.text("xomo.component.button.defaultLabel") }))
        #expect(viewModel.canUndo)
    }

    @Test func buttonComponentRoundTripRetainsGroupAndEditableChildren() throws {
        let image = NSImage.transparent(size: CGSize(width: 640, height: 480))
        let viewModel = ImageEditorViewModel(sourceName: "source", image: image) { _ in }
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 40, y: 60))

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restored = try project.restoredDocument()
        let group = try #require(restored.layers.first(where: { $0.isGroup && $0.name == XomoComponentKind.button.title }))
        let children = restored.layers.filter { $0.groupID == group.id }

        #expect(children.count == 2)
        #expect(children.contains(where: { $0.isShape }))
        #expect(children.contains(where: { $0.isText }))
    }

    @Test func insertingInputCreatesEditableGroupedLayers() throws {
        let image = NSImage.transparent(size: CGSize(width: 640, height: 480))
        let viewModel = ImageEditorViewModel(sourceName: "source", image: image) { _ in }

        viewModel.insertXomoComponent(.input, at: CGPoint(x: 40, y: 60))

        let group = try #require(viewModel.document.selectedLayer)
        #expect(group.isGroup)
        #expect(group.name == XomoComponentKind.input.title)
        let children = viewModel.document.layers.filter { $0.groupID == group.id }
        #expect(children.count == 2)
        #expect(children.contains(where: { $0.isShape }))
        #expect(children.contains(where: { $0.isText && $0.textContent?.text == L10n.text("xomo.component.input.defaultPlaceholder") }))
        #expect(viewModel.canUndo)
    }

    @Test func inputComponentRoundTripRetainsGroupAndEditableChildren() throws {
        let image = NSImage.transparent(size: CGSize(width: 640, height: 480))
        let viewModel = ImageEditorViewModel(sourceName: "source", image: image) { _ in }
        viewModel.insertXomoComponent(.input, at: CGPoint(x: 40, y: 60))

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restored = try project.restoredDocument()
        let group = try #require(restored.layers.first(where: { $0.isGroup && $0.name == XomoComponentKind.input.title }))
        let children = restored.layers.filter { $0.groupID == group.id }

        #expect(children.count == 2)
        #expect(children.contains(where: { $0.isShape }))
        #expect(children.contains(where: { $0.isText }))
    }

    @Test func insertingCardCreatesEditableGroupedLayers() throws {
        let image = NSImage.transparent(size: CGSize(width: 640, height: 480))
        let viewModel = ImageEditorViewModel(sourceName: "source", image: image) { _ in }

        viewModel.insertXomoComponent(.card, at: CGPoint(x: 40, y: 60))

        let group = try #require(viewModel.document.selectedLayer)
        #expect(group.isGroup)
        #expect(group.name == XomoComponentKind.card.title)
        let children = viewModel.document.layers.filter { $0.groupID == group.id }
        #expect(children.count == 3)
        #expect(children.contains(where: { $0.isShape }))
        #expect(children.contains(where: { $0.isText && $0.textContent?.text == L10n.text("xomo.component.card.defaultTitle") }))
        #expect(children.contains(where: { $0.isText && $0.textContent?.text == L10n.text("xomo.component.card.defaultBody") }))
        #expect(viewModel.canUndo)
    }

    @Test func cardComponentRoundTripRetainsGroupAndEditableChildren() throws {
        let image = NSImage.transparent(size: CGSize(width: 640, height: 480))
        let viewModel = ImageEditorViewModel(sourceName: "source", image: image) { _ in }
        viewModel.insertXomoComponent(.card, at: CGPoint(x: 40, y: 60))

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restored = try project.restoredDocument()
        let group = try #require(restored.layers.first(where: { $0.isGroup && $0.name == XomoComponentKind.card.title }))
        let children = restored.layers.filter { $0.groupID == group.id }

        #expect(children.count == 3)
        #expect(children.contains(where: { $0.isShape }))
        #expect(children.filter { $0.isText }.count == 2)
    }

    @Test func insertingImageCreatesEditablePixelLayerInGroup() throws {
        let image = NSImage.transparent(size: CGSize(width: 640, height: 480))
        let viewModel = ImageEditorViewModel(sourceName: "source", image: image) { _ in }

        viewModel.insertXomoComponent(.image, at: CGPoint(x: 40, y: 60))

        let group = try #require(viewModel.document.selectedLayer)
        #expect(group.isGroup)
        #expect(group.name == XomoComponentKind.image.title)
        let children = viewModel.document.layers.filter { $0.groupID == group.id }
        #expect(children.count == 1)
        #expect(children[0].kind.isPixel)
        #expect(children[0].name == L10n.text("xomo.component.image.placeholderLayer"))
        #expect(children[0].image.cgImage(forProposedRect: nil, context: nil, hints: nil) != nil)
        #expect(viewModel.canUndo)
    }

    @Test func imageComponentRoundTripRetainsEditablePixelLayer() throws {
        let image = NSImage.transparent(size: CGSize(width: 640, height: 480))
        let viewModel = ImageEditorViewModel(sourceName: "source", image: image) { _ in }
        viewModel.insertXomoComponent(.image, at: CGPoint(x: 40, y: 60))

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restored = try project.restoredDocument()
        let group = try #require(restored.layers.first(where: { $0.isGroup && $0.name == XomoComponentKind.image.title }))
        let children = restored.layers.filter { $0.groupID == group.id }

        #expect(children.count == 1)
        #expect(children[0].kind.isPixel)
        #expect(children[0].image.cgImage(forProposedRect: nil, context: nil, hints: nil) != nil)
    }
}
