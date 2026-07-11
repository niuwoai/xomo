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
}
