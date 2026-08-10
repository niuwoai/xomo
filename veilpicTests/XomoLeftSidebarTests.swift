import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
struct XomoLeftSidebarTests {
    @Test func componentDragPreviewUsesTheExactCanvasDisplaySize() {
        let canvasSize = CGSize(width: 1_000, height: 800)
        let viewModel = ImageEditorViewModel(
            sourceName: "component-drag-preview",
            image: NSImage.transparent(size: canvasSize)
        ) { _ in }
        viewModel.canvasViewportSize = canvasSize
        viewModel.zoom = 1

        let expectedScale: CGFloat = 0.74
        for component in XomoComponentKind.allCases {
            let componentSize = viewModel.xomoComponentSize(component)
            let previewSize = viewModel.xomoComponentDragPreviewSize(component)

            #expect(abs(previewSize.width - componentSize.width * expectedScale) < 0.01)
            #expect(abs(previewSize.height - componentSize.height * expectedScale) < 0.01)
        }
    }

    @Test func componentDropCentersThePreviewAtThePointerAndClampsToCanvasEdges() {
        let canvasSize = CGSize(width: 1_000, height: 800)
        let viewModel = ImageEditorViewModel(
            sourceName: "component-drop-origin",
            image: NSImage.transparent(size: canvasSize)
        ) { _ in }

        for component in XomoComponentKind.allCases {
            let size = viewModel.xomoComponentSize(component)
            let centered = viewModel.xomoComponentDropOrigin(
                component,
                centeredAt: CGPoint(x: 500, y: 400)
            )
            #expect(abs(centered.x + size.width * 0.5 - 500) < 0.01)
            #expect(abs(centered.y + size.height * 0.5 - 400) < 0.01)

            let topLeft = viewModel.xomoComponentDropOrigin(component, centeredAt: .zero)
            #expect(topLeft == .zero)

            let bottomRight = viewModel.xomoComponentDropOrigin(
                component,
                centeredAt: CGPoint(x: canvasSize.width, y: canvasSize.height)
            )
            #expect(abs(bottomRight.x - (canvasSize.width - size.width)) < 0.01)
            #expect(abs(bottomRight.y - (canvasSize.height - size.height)) < 0.01)
        }
    }

    @Test func sidebarHasToolsAndComponentsTabs() {
        #expect(XomoLeftSidebarTab.allCases == [.tools, .components])
        #expect(XomoLeftSidebarTab.tools.symbolName == "wrench.and.screwdriver")
        #expect(XomoLeftSidebarTab.components.symbolName == "square.grid.2x2")
    }

    @Test func componentLibraryExposesEditableStarterComponents() {
        #expect(XomoComponentKind.allCases == [
            .button,
            .secondaryButton,
            .ghostButton,
            .iconButton,
            .input,
            .searchInput,
            .textArea,
            .selectInput,
            .toggle,
            .checkbox,
            .tag,
            .badge,
            .listRow,
            .topNavigation,
            .sideNavigation,
            .tabBar,
            .carouselCard,
            .emptyState,
            .card,
            .image,
            .avatar,
            .icon
        ])
    }

    @Test func componentThemesExposeOriginalAndAttributedReferenceTokenSets() {
        #expect(XomoComponentTheme.allCases == [
            .native, .softMobile, .socialContent, .glassmorphism, .denseAdmin, .chakraUI, .radixThemes
        ])
        #expect(XomoComponentTheme.allCases.filter { $0.librarySource == .xomoOriginal }.count == 5)
        #expect(XomoComponentTheme.chakraUI.librarySource == .chakraUI)
        #expect(XomoComponentTheme.radixThemes.librarySource == .radixThemes)
        #expect(!XomoComponentTheme.native.tokens.accent.isEqual(XomoComponentTheme.softMobile.tokens.accent))
        #expect(!XomoComponentTheme.softMobile.tokens.accent.isEqual(XomoComponentTheme.denseAdmin.tokens.accent))
        #expect(XomoComponentTheme.softMobile.tokens.cornerRadius > XomoComponentTheme.native.tokens.cornerRadius)
        #expect(XomoComponentTheme.denseAdmin.tokens.cornerRadius < XomoComponentTheme.native.tokens.cornerRadius)
        #expect(XomoComponentTheme.glassmorphism.tokens.surface.alphaComponent < 1)
        let everyComponentSupportsThemes = XomoComponentKind.allCases.allSatisfy(\.supportsThemeApplication)
        #expect(everyComponentSupportsThemes)
    }

    @Test func localTokenSnapshotValidatesColorsMetricsAndSchema() throws {
        let snapshot = XomoComponentThemeTokenSnapshot(
            schemaVersion: 1,
            theme: "local-brand",
            librarySource: "local",
            colors: [
                "accent": "#112233FF",
                "accentBorder": "#0A1B2CFF",
                "surface": "#FFFFFFFF",
                "subtleSurface": "#EEF2F6FF",
                "border": "#CBD5E1FF",
                "primaryText": "#0F172AFF",
                "secondaryText": "#475569FF",
                "onAccent": "#FFFFFFFF"
            ],
            metrics: ["cornerRadius": 10, "spacing": 12]
        )
        let tokens = try snapshot.makeTokens()
        #expect(tokens.accent.isEqual(NSColor(deviceRed: 0x11 / 255, green: 0x22 / 255, blue: 0x33 / 255, alpha: 1)))

        let invalid = XomoComponentThemeTokenSnapshot(
            schemaVersion: 2,
            theme: "local-brand",
            librarySource: "local",
            colors: snapshot.colors,
            metrics: snapshot.metrics
        )
        #expect(throws: XomoComponentThemeTokenError.unsupportedSchema(2)) {
            _ = try invalid.makeTokens()
        }
    }

    @Test func importingLocalTokensStylesNewComponentsAndRoundTripsMetadata() throws {
        let snapshot = XomoComponentThemeTokenSnapshot(
            schemaVersion: 1,
            theme: "local-brand",
            librarySource: "local",
            colors: [
                "accent": "#112233FF",
                "accentBorder": "#0A1B2CFF",
                "surface": "#FFFFFFFF",
                "subtleSurface": "#EEF2F6FF",
                "border": "#CBD5E1FF",
                "primaryText": "#0F172AFF",
                "secondaryText": "#475569FF",
                "onAccent": "#FFFFFFFF"
            ],
            metrics: ["cornerRadius": 10, "spacing": 12]
        )
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("xomo-local-token-\(UUID().uuidString).xomotokens.json")
        defer { try? FileManager.default.removeItem(at: path) }
        try Data(snapshot.encodedJSON().utf8).write(to: path)

        let viewModel = ImageEditorViewModel(
            sourceName: "local-token-import",
            image: NSImage.transparent(size: CGSize(width: 640, height: 480))
        ) { _ in }
        try viewModel.importXomoThemeTokens(from: path)
        #expect(viewModel.hasLocalXomoThemeTokens)
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 40, y: 60))

        let group = try #require(viewModel.document.selectedLayer)
        let background = try #require(viewModel.document.layers.first { $0.groupID == group.id && $0.isShape })
        #expect(background.shapeContent?.fillColor.isEqual(NSColor(deviceRed: 0x11 / 255, green: 0x22 / 255, blue: 0x33 / 255, alpha: 1)) == true)
        #expect(group.xomoComponentInstance?.tokenSnapshot == snapshot)

        let restored = try ImageEditorProjectDocument(document: viewModel.document).restoredDocument()
        #expect(restored.layers.first { $0.id == group.id }?.xomoComponentInstance?.tokenSnapshot == snapshot)

        viewModel.clearImportedXomoThemeTokens()
        #expect(!viewModel.hasLocalXomoThemeTokens)
    }

    @Test func applyingImportedTokensIsUndoableAndClearsWithBuiltInThemeSelection() throws {
        let base = XomoComponentTheme.native.tokenSnapshot
        var colors = base.colors
        colors["accent"] = "#801F4FFF"
        let snapshot = XomoComponentThemeTokenSnapshot(
            schemaVersion: 1,
            theme: "local-brand",
            librarySource: "local",
            colors: colors,
            metrics: base.metrics
        )
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("xomo-local-token-undo-\(UUID().uuidString).xomotokens.json")
        defer { try? FileManager.default.removeItem(at: path) }
        try Data(snapshot.encodedJSON().utf8).write(to: path)
        let viewModel = ImageEditorViewModel(
            sourceName: "local-token-undo",
            image: NSImage.transparent(size: CGSize(width: 640, height: 480))
        ) { _ in }
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 40, y: 60))
        let group = try #require(viewModel.document.selectedLayer)
        try viewModel.importXomoThemeTokens(from: path)
        viewModel.applyXomoThemeToSelectedComponent()
        let customBackground = try #require(viewModel.document.layers.first { $0.groupID == group.id && $0.isShape })
        #expect(customBackground.shapeContent?.fillColor.isEqual(NSColor(deviceRed: 0x80 / 255, green: 0x1F / 255, blue: 0x4F / 255, alpha: 1)) == true)
        #expect(viewModel.document.selectedLayer?.xomoComponentInstance?.tokenSnapshot == snapshot)

        viewModel.undo()
        let restoredBackground = try #require(viewModel.document.layers.first { $0.groupID == group.id && $0.isShape })
        #expect(restoredBackground.shapeContent?.fillColor.isEqual(XomoComponentTheme.native.tokens.accent) == true)

        try viewModel.importXomoThemeTokens(from: path)
        viewModel.selectXomoComponentTheme(.denseAdmin)
        #expect(!viewModel.hasLocalXomoThemeTokens)
    }

    @Test func refreshingMappedComponentsUpdatesLocalTokensAsOneUndoableOperation() throws {
        let base = XomoComponentTheme.native.tokenSnapshot
        var firstColors = base.colors
        firstColors["surface"] = "#801F4FFF"
        let firstSnapshot = XomoComponentThemeTokenSnapshot(
            schemaVersion: 1,
            theme: "local-brand",
            librarySource: "local",
            colors: firstColors,
            metrics: base.metrics
        )
        var secondColors = firstColors
        secondColors["surface"] = "#1D4ED8FF"
        let secondSnapshot = XomoComponentThemeTokenSnapshot(
            schemaVersion: 1,
            theme: "local-brand-v2",
            librarySource: "local",
            colors: secondColors,
            metrics: base.metrics
        )
        let firstPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("xomo-local-token-refresh-a-\(UUID().uuidString).xomotokens.json")
        let secondPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("xomo-local-token-refresh-b-\(UUID().uuidString).xomotokens.json")
        defer {
            try? FileManager.default.removeItem(at: firstPath)
            try? FileManager.default.removeItem(at: secondPath)
        }
        try Data(firstSnapshot.encodedJSON().utf8).write(to: firstPath)
        try Data(secondSnapshot.encodedJSON().utf8).write(to: secondPath)

        let viewModel = ImageEditorViewModel(
            sourceName: "local-token-refresh",
            image: NSImage.transparent(size: CGSize(width: 640, height: 480))
        ) { _ in }
        try viewModel.importXomoThemeTokens(from: firstPath)
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 40, y: 60))
        let firstGroup = try #require(viewModel.document.selectedLayer)
        viewModel.insertXomoComponent(.input, at: CGPoint(x: 40, y: 140))
        let secondGroup = try #require(viewModel.document.selectedLayer)
        #expect(viewModel.mappedXomoComponentGroupCount == 2)

        let overriddenIndex = try #require(viewModel.document.layers.firstIndex {
            $0.groupID == firstGroup.id && $0.isShape
        })
        var overriddenLayer = viewModel.document.layers[overriddenIndex]
        var overriddenContent = try #require(overriddenLayer.shapeContent)
        overriddenContent.fillColor = NSColor.systemOrange
        overriddenLayer.kind = .shape(overriddenContent)
        overriddenLayer.isXomoThemeOverride = true
        viewModel.document.layers[overriddenIndex] = overriddenLayer

        try viewModel.importXomoThemeTokens(from: secondPath)
        viewModel.refreshXomoThemeTokensInDocument()
        #expect(viewModel.document.layers.first { $0.id == firstGroup.id }?.xomoComponentInstance?.tokenSnapshot == secondSnapshot)
        #expect(viewModel.document.layers.first { $0.id == secondGroup.id }?.xomoComponentInstance?.tokenSnapshot == secondSnapshot)
        #expect(viewModel.document.layers[overriddenIndex].shapeContent?.fillColor.isEqual(NSColor.systemOrange) == true)
        let refreshedBackground = try #require(viewModel.document.layers.first {
            $0.groupID == secondGroup.id && $0.isShape
        })
        #expect(refreshedBackground.shapeContent?.fillColor.isEqual(NSColor(deviceRed: 0x1D / 255, green: 0x4E / 255, blue: 0xD8 / 255, alpha: 1)) == true)
        #expect(viewModel.document.history.last?.title == L10n.format("xomo.theme.history.tokensRefreshed", 2))

        viewModel.undo()
        #expect(viewModel.document.layers.first { $0.id == firstGroup.id }?.xomoComponentInstance?.tokenSnapshot == firstSnapshot)
        #expect(viewModel.document.layers.first { $0.id == secondGroup.id }?.xomoComponentInstance?.tokenSnapshot == firstSnapshot)
        #expect(viewModel.document.layers[overriddenIndex].isXomoThemeOverride == true)
    }

    @Test func localTokenImportAndClearParticipateInUndoRedo() throws {
        let snapshot = XomoComponentTheme.native.tokenSnapshot
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("xomo-local-token-history-\(UUID().uuidString).xomotokens.json")
        defer { try? FileManager.default.removeItem(at: path) }
        try Data(snapshot.encodedJSON().utf8).write(to: path)

        let viewModel = ImageEditorViewModel(
            sourceName: "local-token-history",
            image: NSImage.transparent(size: CGSize(width: 640, height: 480))
        ) { _ in }

        try viewModel.importXomoThemeTokens(from: path)
        #expect(viewModel.hasLocalXomoThemeTokens)
        viewModel.undo()
        #expect(!viewModel.hasLocalXomoThemeTokens)
        viewModel.redo()
        #expect(viewModel.xomoLocalThemeTokenSnapshot == snapshot)

        viewModel.clearImportedXomoThemeTokens()
        #expect(!viewModel.hasLocalXomoThemeTokens)
        viewModel.undo()
        #expect(viewModel.xomoLocalThemeTokenSnapshot == snapshot)
        viewModel.redo()
        #expect(!viewModel.hasLocalXomoThemeTokens)
    }

    @Test func projectRoundTripRetainsActiveThemeAndLocalTokenMapping() throws {
        let snapshot = XomoComponentTheme.native.tokenSnapshot
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("xomo-local-token-project-\(UUID().uuidString).xomotokens.json")
        defer { try? FileManager.default.removeItem(at: path) }
        try Data(snapshot.encodedJSON().utf8).write(to: path)

        let viewModel = ImageEditorViewModel(
            sourceName: "local-token-project",
            image: NSImage.transparent(size: CGSize(width: 640, height: 480))
        ) { _ in }
        viewModel.selectXomoComponentTheme(.glassmorphism)
        try viewModel.importXomoThemeTokens(from: path)

        let projectData = try viewModel.projectData()
        let reopened = ImageEditorViewModel(
            sourceName: "empty",
            image: NSImage.transparent(size: CGSize(width: 1, height: 1))
        ) { _ in }
        try reopened.loadProjectData(projectData)

        #expect(reopened.xomoComponentTheme == .glassmorphism)
        #expect(reopened.xomoLocalThemeTokenSnapshot == snapshot)
        #expect(reopened.activeXomoComponentTokenSnapshot == snapshot)
    }

    @Test func primaryButtonUsesSelectedComponentThemeTokens() throws {
        for theme in XomoComponentTheme.allCases {
            let image = NSImage.transparent(size: CGSize(width: 640, height: 480))
            let viewModel = ImageEditorViewModel(sourceName: "source", image: image) { _ in }
            viewModel.xomoComponentTheme = theme

            viewModel.insertXomoComponent(.button, at: CGPoint(x: 40, y: 60))

            let group = try #require(viewModel.document.selectedLayer)
            let background = try #require(viewModel.document.layers.first { $0.groupID == group.id && $0.isShape })
            #expect(background.shapeContent?.fillColor.isEqual(theme.tokens.accent) == true)
            #expect(background.shapeContent?.strokeColor.isEqual(theme.tokens.accentBorder) == true)
        }
    }

    @Test func inputsAndCardsUseSelectedComponentThemeTokens() throws {
        for theme in XomoComponentTheme.allCases {
            let image = NSImage.transparent(size: CGSize(width: 640, height: 480))
            let viewModel = ImageEditorViewModel(sourceName: "source", image: image) { _ in }
            viewModel.xomoComponentTheme = theme

            for component in [XomoComponentKind.input, .card] {
                viewModel.insertXomoComponent(component, at: CGPoint(x: 40, y: 60))
                let group = try #require(viewModel.document.selectedLayer)
                let background = try #require(viewModel.document.layers.first { $0.groupID == group.id && $0.isShape })
                let texts = viewModel.document.layers.filter { $0.groupID == group.id && $0.isText }
                #expect(background.shapeContent?.fillColor.isEqual(theme.tokens.surface) == true)
                #expect(background.shapeContent?.strokeColor.isEqual(theme.tokens.border) == true)
                #expect(texts.contains { $0.textContent?.color.isEqual(theme.tokens.secondaryText) == true })
            }
        }
    }

    @Test func applyingThemeToExistingButtonPreservesMarkedLocalOverrideAndRoundTrips() throws {
        let image = NSImage.transparent(size: CGSize(width: 640, height: 480))
        let viewModel = ImageEditorViewModel(sourceName: "source", image: image) { _ in }
        viewModel.xomoComponentTheme = .native
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 40, y: 60))

        let group = try #require(viewModel.document.selectedLayer)
        let background = try #require(viewModel.document.layers.first { $0.groupID == group.id && $0.isShape })
        viewModel.selectLayer(background.id)
        viewModel.toggleXomoThemeOverrideForSelectedLayers()
        #expect(viewModel.document.layers.first { $0.id == background.id }?.isXomoThemeOverride == true)

        viewModel.selectLayer(group.id)
        viewModel.xomoComponentTheme = .softMobile
        viewModel.applyXomoThemeToSelectedComponent()

        let retainedBackground = try #require(viewModel.document.layers.first { $0.id == background.id })
        let updatedGroup = try #require(viewModel.document.layers.first { $0.id == group.id })
        #expect(retainedBackground.shapeContent?.fillColor.isEqual(XomoComponentTheme.native.tokens.accent) == true)
        #expect(updatedGroup.xomoComponentInstance?.theme == .softMobile)

        let restored = try ImageEditorProjectDocument(document: viewModel.document).restoredDocument()
        let restoredGroup = try #require(restored.layers.first { $0.id == group.id })
        let restoredBackground = try #require(restored.layers.first { $0.id == background.id })
        #expect(restoredGroup.xomoComponentInstance == XomoComponentInstance(kind: .button, theme: .softMobile))
        #expect(restoredBackground.isXomoThemeOverride)
        #expect(
            restoredBackground.shapeContent.map { ImageEditorProjectColor(color: $0.fillColor) }
                == ImageEditorProjectColor(color: XomoComponentTheme.native.tokens.accent)
        )
    }

    @Test func applyingThemeToExistingInputAndCardUpdatesTokens() throws {
        let image = NSImage.transparent(size: CGSize(width: 640, height: 480))
        let viewModel = ImageEditorViewModel(sourceName: "source", image: image) { _ in }

        for component in [XomoComponentKind.input, .card] {
            viewModel.xomoComponentTheme = .native
            viewModel.insertXomoComponent(component, at: CGPoint(x: 40, y: 60))
            let group = try #require(viewModel.document.selectedLayer)
            viewModel.xomoComponentTheme = .denseAdmin
            viewModel.applyXomoThemeToSelectedComponent()

            let children = viewModel.document.layers.filter { $0.groupID == group.id }
            let background = try #require(children.first { $0.isShape })
            #expect(background.shapeContent?.fillColor.isEqual(XomoComponentTheme.denseAdmin.tokens.surface) == true)
            #expect(background.shapeContent?.strokeColor.isEqual(XomoComponentTheme.denseAdmin.tokens.border) == true)
            #expect(viewModel.document.layers.first { $0.id == group.id }?.xomoComponentInstance?.theme == .denseAdmin)
        }
    }

    @Test func applyingThemeMigratesPreviouslyInsertedComponentWithoutThemeMetadata() throws {
        let image = NSImage.transparent(size: CGSize(width: 640, height: 480))
        let viewModel = ImageEditorViewModel(sourceName: "source", image: image) { _ in }
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 40, y: 60))

        let group = try #require(viewModel.document.selectedLayer)
        let groupIndex = try #require(viewModel.document.layers.firstIndex { $0.id == group.id })
        viewModel.document.layers[groupIndex].xomoComponentInstance = nil
        viewModel.xomoComponentTheme = .denseAdmin
        viewModel.applyXomoThemeToSelectedComponent()

        let migratedGroup = try #require(viewModel.document.layers.first { $0.id == group.id })
        let background = try #require(viewModel.document.layers.first { $0.groupID == group.id && $0.isShape })
        #expect(migratedGroup.xomoComponentInstance == XomoComponentInstance(kind: .button, theme: .denseAdmin))
        #expect(background.shapeContent?.fillColor.isEqual(XomoComponentTheme.denseAdmin.tokens.accent) == true)
    }

    @Test func eachThemeCanInsertAnEditablePageSample() throws {
        let image = NSImage.transparent(size: CGSize(width: 1440, height: 900))
        let expectedComponents: [XomoThemeSample: Set<XomoComponentKind>] = [
            .nativeWorkspace: [.topNavigation, .sideNavigation, .card, .input, .selectInput, .button],
            .softMobileProfile: [.avatar, .card, .input, .searchInput, .button, .secondaryButton],
            .socialContentFeed: [.topNavigation, .avatar, .carouselCard, .tabBar, .tag, .button],
            .glassmorphismDashboard: [.topNavigation, .card, .searchInput, .toggle, .button],
            .denseAdminSettings: [.topNavigation, .sideNavigation, .card, .searchInput, .selectInput, .button],
            .chakraForm: [.card, .input, .selectInput, .checkbox, .tag, .button],
            .radixSettings: [.topNavigation, .card, .listRow, .selectInput, .toggle, .secondaryButton]
        ]

        for sample in XomoThemeSample.allCases {
            let viewModel = ImageEditorViewModel(sourceName: sample.rawValue, image: image) { _ in }
            viewModel.xomoComponentTheme = sample.theme
            viewModel.insertXomoThemeSample()

            let groups = viewModel.document.layers.filter { $0.isGroup }
            #expect(groups.count == 6)
            #expect(Set(groups.compactMap(\.xomoComponentInstance?.kind)) == expectedComponents[sample])
            #expect(groups.allSatisfy { $0.xomoComponentInstance?.theme == sample.theme })
            #expect(groups.allSatisfy { group in
                viewModel.document.layers.contains { $0.groupID == group.id }
            })
        }
    }

    @Test func componentMasterSyncsLinkedInstancesAndKeepsDetachedInstanceIndependent() throws {
        let image = NSImage.transparent(size: CGSize(width: 640, height: 480))
        let viewModel = ImageEditorViewModel(sourceName: "instances", image: image) { _ in }

        viewModel.xomoComponentTheme = .native
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 40, y: 60))
        let master = try #require(viewModel.document.selectedLayer)
        viewModel.setSelectedXomoComponentAsMaster()

        viewModel.xomoComponentTheme = .denseAdmin
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 40, y: 150))
        let linked = try #require(viewModel.document.selectedLayer)
        viewModel.linkSelectedXomoComponentsToMaster()

        viewModel.xomoComponentTheme = .denseAdmin
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 40, y: 240))
        let detached = try #require(viewModel.document.selectedLayer)
        viewModel.linkSelectedXomoComponentsToMaster()
        viewModel.detachSelectedXomoComponentInstances()

        viewModel.selectLayer(master.id)
        viewModel.xomoComponentTheme = .softMobile
        viewModel.applyXomoThemeToSelectedComponent()
        viewModel.syncSelectedXomoComponentMaster()

        let masterLayer = try #require(viewModel.document.layers.first { $0.id == master.id })
        let linkedLayer = try #require(viewModel.document.layers.first { $0.id == linked.id })
        let detachedLayer = try #require(viewModel.document.layers.first { $0.id == detached.id })
        #expect(masterLayer.xomoComponentInstance?.masterID == master.id)
        #expect(linkedLayer.xomoComponentInstance?.masterID == master.id)
        #expect(linkedLayer.xomoComponentInstance?.theme == .softMobile)
        #expect(detachedLayer.xomoComponentInstance?.masterID == nil)
        #expect(detachedLayer.xomoComponentInstance?.theme == .native)

        let restored = try ImageEditorProjectDocument(document: viewModel.document).restoredDocument()
        #expect(restored.layers.first { $0.id == linked.id }?.xomoComponentInstance?.masterID == master.id)
        #expect(restored.layers.first { $0.id == detached.id }?.xomoComponentInstance?.masterID == nil)
    }

    @Test func switchingSidebarDoesNotChangeSelectedTool() {
        let image = NSImage.transparent(size: CGSize(width: 20, height: 20))
        let viewModel = ImageEditorViewModel(sourceName: "source", image: image) { _ in }
        viewModel.selectTool(.brush)
        #expect(viewModel.canvasInteractionTool == .brush)
        #expect(viewModel.workspaceInputMode == .tool(.brush))

        viewModel.selectLeftSidebarTab(.components)

        #expect(viewModel.selectedLeftSidebarTab == .components)
        #expect(viewModel.selectedTool == .brush)
        #expect(viewModel.canvasInteractionTool == .move)
        #expect(viewModel.workspaceInputMode == .componentLibrary(nil))

        viewModel.selectLeftSidebarTab(.tools)

        #expect(viewModel.selectedLeftSidebarTab == .tools)
        #expect(viewModel.selectedTool == .brush)
        #expect(viewModel.canvasInteractionTool == .brush)
        #expect(viewModel.workspaceInputMode == .tool(.brush))
    }

    @Test func componentWorkspacePresentationTracksTheSelectedComponentNotTheStoredTool() {
        let image = NSImage.transparent(size: CGSize(width: 640, height: 480))
        let viewModel = ImageEditorViewModel(sourceName: "source", image: image) { _ in }
        viewModel.selectTool(.brush)
        viewModel.insertXomoComponent(.iconButton, at: CGPoint(x: 80, y: 90))
        viewModel.selectLeftSidebarTab(.components)

        #expect(viewModel.selectedTool == .brush)
        #expect(viewModel.canvasInteractionTool == .move)
        #expect(viewModel.workspaceInputMode == .componentLibrary(.iconButton))
    }

    @Test func sameKindComponentInsertionChangesSelectionIdentity() throws {
        let image = NSImage.transparent(size: CGSize(width: 640, height: 480))
        let viewModel = ImageEditorViewModel(sourceName: "source", image: image) { _ in }
        viewModel.selectLeftSidebarTab(.components)

        viewModel.insertXomoComponent(.button, at: CGPoint(x: 60, y: 70))
        let firstID = try #require(viewModel.document.selectedLayerID)
        #expect(viewModel.selectedXomoObjectKind == .button)

        viewModel.insertXomoComponent(.button, at: CGPoint(x: 220, y: 70))
        let secondID = try #require(viewModel.document.selectedLayerID)

        #expect(secondID != firstID)
        #expect(viewModel.selectedXomoObjectKind == .button)
        #expect(viewModel.workspaceInputMode == .componentLibrary(.button))
    }

    @Test func removingASecondaryComponentChangesSelectionSetWithoutChangingPrimary() throws {
        let image = NSImage.transparent(size: CGSize(width: 640, height: 480))
        let viewModel = ImageEditorViewModel(sourceName: "source", image: image) { _ in }
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 60, y: 70))
        let firstID = try #require(viewModel.document.selectedLayerID)
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 220, y: 70))
        let secondID = try #require(viewModel.document.selectedLayerID)

        viewModel.selectLayer(firstID, extendingSelection: true)
        #expect(viewModel.document.selectedLayerID == firstID)
        #expect(viewModel.document.selectedLayerIDs == [firstID, secondID])

        let primaryBeforeRemoval = viewModel.document.selectedLayerID
        viewModel.selectLayer(secondID, extendingSelection: true)

        #expect(viewModel.document.selectedLayerID == primaryBeforeRemoval)
        #expect(viewModel.document.selectedLayerIDs == [firstID])
    }

    @Test func lockingSelectedComponentRemovesTransformCapabilities() throws {
        let image = NSImage.transparent(size: CGSize(width: 640, height: 480))
        let viewModel = ImageEditorViewModel(sourceName: "source", image: image) { _ in }
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 60, y: 70))
        let componentID = try #require(viewModel.document.selectedLayerID)

        #expect(viewModel.canResizeSelectedLayer)
        #expect(viewModel.canRotateSelectedLayer)

        viewModel.toggleLayerLock(componentID)

        #expect(!viewModel.canResizeSelectedLayer)
        #expect(!viewModel.canRotateSelectedLayer)
        #expect(viewModel.document.selectedLayerID == componentID)
    }

    @Test func hidingSelectedComponentRemovesAndRestoresTransformPresentation() throws {
        let image = NSImage.transparent(size: CGSize(width: 640, height: 480))
        let viewModel = ImageEditorViewModel(sourceName: "source", image: image) { _ in }
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 60, y: 70))
        let componentID = try #require(viewModel.document.selectedLayerID)
        let visibleFrame = try #require(viewModel.selectedLayerTransformFrame)

        viewModel.toggleLayerVisibility(componentID)

        #expect(viewModel.document.selectedLayerID == componentID)
        #expect(viewModel.selectedLayerTransformFrame == nil)
        #expect(!viewModel.hasSelectedXomoObject)
        #expect(!viewModel.canResizeSelectedLayer)
        #expect(!viewModel.canRotateSelectedLayer)

        viewModel.toggleLayerVisibility(componentID)

        #expect(viewModel.document.selectedLayerID == componentID)
        #expect(viewModel.selectedLayerTransformFrame == visibleFrame)
        #expect(viewModel.hasSelectedXomoObject)
        #expect(viewModel.canResizeSelectedLayer)
        #expect(viewModel.canRotateSelectedLayer)
    }

    @Test func componentWorkspaceOwnsItsOptionBarAndHintPresentation() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let optionStart = try #require(
            source.range(of: "private func componentLibraryOptionBar(")
        )
        let optionEnd = try #require(
            source[optionStart.upperBound...].range(of: "private var optionHistoryButtons:")
        )
        let optionSource = source[optionStart.lowerBound..<optionEnd.lowerBound]
        let hintStart = try #require(
            source.range(of: "private func componentLibraryHint(")
        )
        let hintEnd = try #require(
            source[hintStart.upperBound...].range(of: "@ViewBuilder\n    private var selectedToolIcon")
        )
        let hintSource = source[hintStart.lowerBound..<hintEnd.lowerBound]

        #expect(source.contains("switch viewModel.workspaceInputMode"))
        #expect(optionSource.contains("XomoLeftSidebarTab.components.title"))
        #expect(optionSource.contains("selectedComponent.title"))
        #expect(optionSource.contains("xomo.componentLibrary.subtitle"))
        #expect(optionSource.contains("image-editor-component-library-mode"))
        #expect(!optionSource.contains("viewModel.selectedTool"))
        #expect(hintSource.contains("image-editor-component-library-hint"))
        #expect(hintSource.contains("selectedComponent?.title"))
        #expect(!hintSource.contains("viewModel.selectedTool"))
    }

    @Test func componentSidebarWiresMoveSemanticsIntoCanvasCursorAndGestures() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(source.contains(".onChange(of: viewModel.selectedLeftSidebarTab)"))
        #expect(source.contains(".onChange(of: viewModel.document.selectedLayerIDs)"))
        #expect(!source.contains(".onChange(of: viewModel.document.selectedLayerID)"))
        #expect(source.contains(".onChange(of: viewModel.document.areTransformControlsVisible)"))
        #expect(source.contains(".onChange(of: viewModel.document.areExtrasVisible)"))
        #expect(source.contains(".onChange(of: viewModel.canResizeSelectedLayer)"))
        #expect(source.contains(".onChange(of: viewModel.canRotateSelectedLayer)"))
        #expect(!source.contains(".onChange(of: viewModel.selectedXomoObjectKind)"))
        #expect(source.contains("switch canvasInteractionTool"))
        #expect(source.contains(".simultaneousGesture(canvasGesture(in: geometry.size))"))
        #expect(source.contains("NSEvent.modifierFlags.contains(.shift)"))
        #expect(source.contains("extendingSelection: true"))
        #expect(source.contains("isCanvasSelectionGestureActive"))
        #expect(source.contains("isCanvasCloneGestureActive"))
        #expect(source.contains("beginDuplicatingSelectedLayerForMove()"))
        #expect(source.contains("ImageEditorObjectDragEventPolicy.allowsCloneDrag("))
        #expect(source.contains("ImageEditorObjectDragEventPolicy"))
        #expect(source.contains(".deepSelectionExtendsSelection("))
        #expect(source.contains("viewModel.selectDeepestVisibleLayer("))
        #expect(source.contains("viewModel.selectMovableCanvasTarget(at: pressedImagePoint)"))
        #expect(source.contains("viewModel.beginMovingSelectedLayer()"))
        #expect(source.contains("onObjectMoveClicked:"))
        #expect(source.contains("onObjectMoveCancelled:"))
        #expect(source.contains("viewModel.cancelMovingSelectedLayer()"))
        #expect(source.contains("extendingSelection: modifierFlags.contains(.shift)"))
        #expect(source.contains("viewModel.cancelMovingSelectedLayer()"))
        #expect(source.contains("viewModel.cancelTransformingSelectedLayer()"))
        #expect(source.contains("transformHUDOverlay("))
        #expect(source.contains("viewModel.isResizingSelectedLayer"))
        #expect(source.contains("resizingFromCenter: NSEvent.modifierFlags.contains(.option)"))
        #expect(source.contains("transformReferencePointView(in: size)"))
        #expect(source.contains("viewModel.setSelectedLayerTransformReferencePoint("))
        #expect(source.contains("guard !isTransformReferencePointDragCancelled else { return }"))
        #expect(source.contains("viewModel.rotatingPreviewDegrees"))
        #expect(source.contains("ImageEditorTransformHUD.displayText"))
        #expect(source.contains("layerTransformCursorTarget(at: viewPoint, in: size)"))
        #expect(source.contains("layerTransformTarget: layerTransformTarget"))
        #expect(source.contains(".contentShape(Rectangle().inset(by: -4))"))
        #expect(source.contains("activeResizeHandle: activeResizeHandle"))
        #expect(source.contains("isRotating: isRotatingLayer"))
        #expect(source.contains("refreshCanvasCursor(in: canvasSize)"))
        #expect(source.contains("case .pathSelection:"))
        #expect(source.contains("viewModel.selectPathLayer(at: pressedImagePoint)"))
        #expect(source.contains("case .directSelection:"))
        #expect(source.contains("viewModel.beginDirectPathAnchorMove(at: pointerImagePoint)"))
        #expect(source.contains("single authoritative component"))
        #expect(!source.contains("func selectedXomoObjectCanvasMoveGesture"))
        #expect(!source.contains("func selectedXomoObjectInteractionOverlay"))
        #expect(source.contains("NSCursor.closedHand.set()"))
        #expect(source.contains("coordinateSpace: .named(\"image-editor-canvas-space\")"))
        #expect(source.contains("viewModel.movingObjectPreviewFrame ?? viewModel.selectedLayerTransformFrame"))
        #expect(source.contains("ImageEditorCanvasCursor.objectMoveCursor().set()"))
        #expect(source.contains("ImageEditorObjectDragConstraint.resolvedAxis"))
        #expect(source.contains("NSEvent.modifierFlags.contains(.shift)"))
        #expect(source.contains("constrainingTo: resolvedAxis"))
        #expect(source.contains("resetObjectMoveTracking()"))
        #expect(source.contains("isCanvasPanGestureActive: isCanvasPanGestureActive"))
        #expect(source.contains("private func refreshCanvasCursor(in size: CGSize)"))
        #expect(source.contains("refreshCanvasCursor(in: geometry.size)"))
        #expect(source.contains("NSCursor.arrow.set()"))
        #expect(source.contains("a stale brush or"))
        #expect(source.contains("isPointerOverCanvas: false"))
        #expect(source.components(separatedBy: "switch canvasInteractionTool").count - 1 >= 3)
    }

    @Test func transformReferencePointGestureWiresTransactionalCancellation() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("viewModel.beginSelectedLayerTransformReferencePointDrag()"))
        #expect(source.contains("viewModel.cancelSelectedLayerTransformReferencePointDrag()"))
        #expect(source.contains("viewModel.finishSelectedLayerTransformReferencePointDrag()"))
        #expect(source.contains("guard !isTransformReferencePointDragCancelled else { return }"))
    }

    @Test func transformReferencePointGestureWiresDeferredDoubleClickReset() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("TapGesture(count: 2)"))
        #expect(source.contains("DispatchQueue.main.async"))
        #expect(source.contains("viewModel.resetSelectedLayerTransformReferencePoint()"))
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

    @Test func buttonVariantsCreateEditableGroupedLayers() throws {
        for component in [XomoComponentKind.secondaryButton, .ghostButton, .iconButton] {
            let image = NSImage.transparent(size: CGSize(width: 640, height: 480))
            let viewModel = ImageEditorViewModel(sourceName: "source", image: image) { _ in }

            viewModel.insertXomoComponent(component, at: CGPoint(x: 40, y: 60))

            let group = try #require(viewModel.document.selectedLayer)
            let children = viewModel.document.layers.filter { $0.groupID == group.id }
            #expect(group.isGroup)
            #expect(group.name == component.title)
            #expect(children.count == 2)
            #expect(children.contains(where: { $0.isShape }))
            #expect(children.contains(where: { $0.isText }))
        }
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

    @Test func formInputVariantsCreateEditableGroupedLayers() throws {
        let variants: [(component: XomoComponentKind, childCount: Int)] = [
            (.searchInput, 3),
            (.textArea, 2),
            (.selectInput, 3)
        ]

        for variant in variants {
            let image = NSImage.transparent(size: CGSize(width: 640, height: 480))
            let viewModel = ImageEditorViewModel(sourceName: "source", image: image) { _ in }

            viewModel.insertXomoComponent(variant.component, at: CGPoint(x: 40, y: 60))

            let group = try #require(viewModel.document.selectedLayer)
            let children = viewModel.document.layers.filter { $0.groupID == group.id }
            #expect(group.isGroup)
            #expect(group.name == variant.component.title)
            #expect(children.count == variant.childCount)
            #expect(children.contains(where: { $0.isShape }))
            #expect(children.contains(where: { $0.isText }))
        }
    }

    @Test func selectionComponentsCreateEditableGroupedLayers() throws {
        let components: [(component: XomoComponentKind, childCount: Int)] = [
            (.toggle, 2),
            (.checkbox, 2),
            (.tag, 2),
            (.badge, 2)
        ]

        for item in components {
            let image = NSImage.transparent(size: CGSize(width: 640, height: 480))
            let viewModel = ImageEditorViewModel(sourceName: "source", image: image) { _ in }

            viewModel.insertXomoComponent(item.component, at: CGPoint(x: 40, y: 60))

            let group = try #require(viewModel.document.selectedLayer)
            let children = viewModel.document.layers.filter { $0.groupID == group.id }
            #expect(group.isGroup)
            #expect(group.name == item.component.title)
            #expect(children.count == item.childCount)
            #expect(children.contains(where: { $0.isShape }))
        }
    }

    @Test func navigationComponentsCreateEditableGroupedLayers() throws {
        let components: [(component: XomoComponentKind, minimumChildCount: Int)] = [
            (.listRow, 3),
            (.topNavigation, 4),
            (.sideNavigation, 5),
            (.tabBar, 4)
        ]

        for item in components {
            let image = NSImage.transparent(size: CGSize(width: 640, height: 480))
            let viewModel = ImageEditorViewModel(sourceName: "source", image: image) { _ in }

            viewModel.insertXomoComponent(item.component, at: CGPoint(x: 40, y: 60))

            let group = try #require(viewModel.document.selectedLayer)
            let children = viewModel.document.layers.filter { $0.groupID == group.id }
            #expect(group.isGroup)
            #expect(group.name == item.component.title)
            #expect(children.count >= item.minimumChildCount)
            #expect(children.contains(where: { $0.isShape }))
            #expect(children.contains(where: { $0.isText }))
        }
    }

    @Test func contentComponentsCreateEditableGroupedLayers() throws {
        let components: [(component: XomoComponentKind, minimumChildCount: Int)] = [
            (.carouselCard, 6),
            (.emptyState, 4)
        ]

        for item in components {
            let image = NSImage.transparent(size: CGSize(width: 640, height: 480))
            let viewModel = ImageEditorViewModel(sourceName: "source", image: image) { _ in }

            viewModel.insertXomoComponent(item.component, at: CGPoint(x: 40, y: 60))

            let group = try #require(viewModel.document.selectedLayer)
            let children = viewModel.document.layers.filter { $0.groupID == group.id }
            #expect(group.isGroup)
            #expect(group.name == item.component.title)
            #expect(children.count >= item.minimumChildCount)
            #expect(children.contains(where: { $0.isShape }))
            #expect(children.contains(where: { $0.isText }))
        }
    }

    @Test func mobileLoginCompositionRoundTripsSixEditableComponents() throws {
        let image = NSImage.transparent(size: CGSize(width: 390, height: 844))
        let viewModel = ImageEditorViewModel(sourceName: "mobile-login", image: image) { _ in }
        let components: [(XomoComponentKind, CGPoint)] = [
            (.avatar, CGPoint(x: 165, y: 72)),
            (.input, CGPoint(x: 32, y: 188)),
            (.checkbox, CGPoint(x: 32, y: 254)),
            (.button, CGPoint(x: 32, y: 302)),
            (.secondaryButton, CGPoint(x: 32, y: 366)),
            (.tag, CGPoint(x: 152, y: 438))
        ]

        components.forEach { component, origin in
            viewModel.insertXomoComponent(component, at: origin)
        }

        let insertedGroups = viewModel.document.layers.filter { $0.isGroup }
        #expect(insertedGroups.count == components.count)
        #expect(viewModel.canUndo)
        viewModel.undo()
        #expect(viewModel.document.layers.filter { $0.isGroup }.count == components.count - 1)
        viewModel.redo()
        #expect(viewModel.document.layers.filter { $0.isGroup }.count == components.count)

        let restored = try ImageEditorProjectDocument(document: viewModel.document).restoredDocument()
        let restoredNames = Set(restored.layers.filter { $0.isGroup }.map(\.name))
        #expect(restored.layers.filter { $0.isGroup }.count == components.count)
        for component in components.map(\.0) {
            #expect(restoredNames.contains(component.title))
        }
    }

    @Test func webSettingsCompositionRoundTripsSixEditableComponents() throws {
        let image = NSImage.transparent(size: CGSize(width: 1440, height: 900))
        let viewModel = ImageEditorViewModel(sourceName: "web-settings", image: image) { _ in }
        let components: [(XomoComponentKind, CGPoint)] = [
            (.topNavigation, CGPoint(x: 0, y: 0)),
            (.sideNavigation, CGPoint(x: 0, y: 64)),
            (.card, CGPoint(x: 288, y: 132)),
            (.selectInput, CGPoint(x: 336, y: 246)),
            (.toggle, CGPoint(x: 336, y: 328)),
            (.button, CGPoint(x: 336, y: 404))
        ]

        components.forEach { component, origin in
            viewModel.insertXomoComponent(component, at: origin)
        }

        let insertedGroups = viewModel.document.layers.filter { $0.isGroup }
        #expect(insertedGroups.count == components.count)
        #expect(insertedGroups.allSatisfy { group in
            viewModel.document.layers.contains { $0.groupID == group.id }
        })

        let restored = try ImageEditorProjectDocument(document: viewModel.document).restoredDocument()
        let restoredGroups = restored.layers.filter { $0.isGroup }
        #expect(restoredGroups.count == components.count)
        for component in components.map(\.0) {
            #expect(restoredGroups.contains { $0.name == component.title })
        }
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

    @Test func insertingAvatarCreatesEditableShapeAndInitialsLayers() throws {
        let image = NSImage.transparent(size: CGSize(width: 640, height: 480))
        let viewModel = ImageEditorViewModel(sourceName: "source", image: image) { _ in }

        viewModel.insertXomoComponent(.avatar, at: CGPoint(x: 40, y: 60))

        let group = try #require(viewModel.document.selectedLayer)
        #expect(group.isGroup)
        #expect(group.name == XomoComponentKind.avatar.title)
        let children = viewModel.document.layers.filter { $0.groupID == group.id }
        #expect(children.count == 2)
        #expect(children.contains(where: { $0.isShape && $0.shapeContent?.kind == .ellipse }))
        #expect(children.contains(where: { $0.isText && $0.textContent?.text == L10n.text("xomo.component.avatar.defaultInitials") }))
        #expect(viewModel.canUndo)
    }

    @Test func avatarComponentRoundTripRetainsEditableChildren() throws {
        let image = NSImage.transparent(size: CGSize(width: 640, height: 480))
        let viewModel = ImageEditorViewModel(sourceName: "source", image: image) { _ in }
        viewModel.insertXomoComponent(.avatar, at: CGPoint(x: 40, y: 60))

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restored = try project.restoredDocument()
        let group = try #require(restored.layers.first(where: { $0.isGroup && $0.name == XomoComponentKind.avatar.title }))
        let children = restored.layers.filter { $0.groupID == group.id }

        #expect(children.count == 2)
        #expect(children.contains(where: { $0.isShape && $0.shapeContent?.kind == .ellipse }))
        #expect(children.contains(where: { $0.isText }))
    }

    @Test func insertingIconCreatesEditableStarPathLayer() throws {
        let image = NSImage.transparent(size: CGSize(width: 640, height: 480))
        let viewModel = ImageEditorViewModel(sourceName: "source", image: image) { _ in }

        viewModel.insertXomoComponent(.icon, at: CGPoint(x: 40, y: 60))

        let group = try #require(viewModel.document.selectedLayer)
        #expect(group.isGroup)
        #expect(group.name == XomoComponentKind.icon.title)
        let children = viewModel.document.layers.filter { $0.groupID == group.id }
        let star = try #require(children.first)
        #expect(children.count == 1)
        #expect(star.isShape)
        #expect(star.shapeContent?.kind == .path)
        #expect(star.shapeContent?.editablePathAnchors.count == 10)
        #expect(viewModel.canUndo)
    }

    @Test func iconComponentRoundTripRetainsEditablePathLayer() throws {
        let image = NSImage.transparent(size: CGSize(width: 640, height: 480))
        let viewModel = ImageEditorViewModel(sourceName: "source", image: image) { _ in }
        viewModel.insertXomoComponent(.icon, at: CGPoint(x: 40, y: 60))

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restored = try project.restoredDocument()
        let group = try #require(restored.layers.first(where: { $0.isGroup && $0.name == XomoComponentKind.icon.title }))
        let children = restored.layers.filter { $0.groupID == group.id }
        let star = try #require(children.first)

        #expect(children.count == 1)
        #expect(star.isShape)
        #expect(star.shapeContent?.kind == .path)
        #expect(star.shapeContent?.editablePathAnchors.count == 10)
    }

    @Test func everyThemeExportsStableDesignTokenJSON() throws {
        for theme in XomoComponentTheme.allCases {
            let snapshot = theme.tokenSnapshot
            #expect(snapshot.schemaVersion == 1)
            #expect(snapshot.theme == theme.rawValue)
            #expect(snapshot.librarySource == theme.librarySource.rawValue)
            #expect(snapshot.colors.count == 8)
            #expect(Set(snapshot.metrics.keys) == Set(["cornerRadius", "spacing"]))

            let json = try snapshot.encodedJSON()
            let decoded = try JSONDecoder().decode(
                XomoComponentThemeTokenSnapshot.self,
                from: Data(json.utf8)
            )
            #expect(decoded == snapshot)
        }
    }

    @Test func componentLibraryCopiesCurrentThemeTokensToClipboard() {
        let image = NSImage.transparent(size: CGSize(width: 640, height: 480))
        let viewModel = ImageEditorViewModel(sourceName: "source", image: image) { _ in }
        viewModel.xomoComponentTheme = .chakraUI

        viewModel.copyCurrentXomoThemeTokens()

        let copied = NSPasteboard.general.string(forType: .string) ?? ""
        #expect(copied.contains("\"theme\" : \"chakraUI\""))
        #expect(copied.contains("\"accent\""))
        #expect(viewModel.statusText.contains(L10n.text("xomo.theme.chakraUI")))
    }

    @Test func componentLibraryExportsCurrentThemeTokensToAFile() throws {
        let image = NSImage.transparent(size: CGSize(width: 640, height: 480))
        let viewModel = ImageEditorViewModel(sourceName: "source", image: image) { _ in }
        viewModel.xomoComponentTheme = .radixThemes
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("xomo-theme-(UUID().uuidString).xomotokens.json")
        defer { try? FileManager.default.removeItem(at: url) }

        try viewModel.exportCurrentXomoThemeTokens(to: url)

        let data = try Data(contentsOf: url)
        let snapshot = try JSONDecoder().decode(
            XomoComponentThemeTokenSnapshot.self,
            from: data
        )
        #expect(snapshot.theme == XomoComponentTheme.radixThemes.rawValue)
        #expect(viewModel.statusText.contains(url.lastPathComponent))
    }

    @Test func componentLibraryExposesKeyboardNeutralTokenCopyAction() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appendingPathComponent("veilpic/XomoLeftSidebar.swift"),
            encoding: .utf8
        )

        #expect(source.contains("xomo.theme.copyTokens"))
        #expect(source.contains("copyCurrentXomoThemeTokens()"))
        #expect(source.contains("xomo-component-theme-copy-tokens"))
        #expect(source.contains("xomo.theme.exportTokens"))
        #expect(source.contains("chooseXomoThemeTokenExportFile()"))
        #expect(source.contains("xomo-component-theme-export-tokens"))
        #expect(source.contains(".focusable(false)"))
    }
}
