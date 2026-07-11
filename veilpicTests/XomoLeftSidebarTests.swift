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
        #expect(XomoComponentKind.allCases.allSatisfy(\.supportsThemeApplication))
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
}
