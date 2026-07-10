//
//  ImageEditorScopeTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/10.
//

import Testing
import AppKit
import Foundation
@testable import musepic

struct ImageEditorScopeTests {
    @Test func imageEditorKeepsCurrentLightweightCapabilitySurfaceStable() {
        #expect(
            Set(ImageEditorTool.allCases.map(\.rawValue)) == [
                "move",
                "marquee",
                "lasso",
                "magicWand",
                "crop",
                "brush",
                "eraser",
                "cloneStamp",
                "dodge",
                "burn",
                "blur",
                "sharpen",
                "smudge",
                "healingBrush",
                "patchTool",
                "paintBucket",
                "gradient",
                "eyedropper",
                "text",
                "rectangle",
                "ellipse",
                "pen",
                "hand",
                "zoom"
            ]
        )

        #expect(
            Set(ImageEditorAdjustment.allCases.map(\.rawValue)) == [
                "brightness",
                "contrast",
                "brightnessContrast",
                "saturation",
                "vibrance",
                "exposure",
                "hue",
                "hueSaturation",
                "shadowsHighlights",
                "invert",
                "threshold",
                "posterize",
                "levels",
                "curves",
                "colorBalance",
                "blackWhite",
                "channelMixer",
                "photoFilter",
                "colorLookup",
                "selectiveColor",
                "gradientMap",
                "blur",
                "sharpen"
            ]
        )

        #expect(
            Set(ImageEditorFilter.allCases.map(\.rawValue)) == [
                "gaussianBlur",
                "sharpen",
                "pixelate",
                "motionBlur",
                "addNoise",
                "median",
                "unsharpMask",
                "highPass",
                "emboss",
                "findEdges",
                "minimum",
                "maximum",
                "oilPaint",
                "vignette",
                "offset",
                "wave",
                "ripple",
                "pinch",
                "spherize",
                "liquifyPush",
                "liquifyTwirl",
                "liquifyPuckerBloat"
            ]
        )
    }

    @MainActor
    @Test func imageEditorActualPixelsZoomUsesLastCanvasViewport() {
        let image = NSImage(size: NSSize(width: 100, height: 50))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let viewportSize = CGSize(width: 400, height: 200)
        let expectedZoom = 1 / (min(viewportSize.width / image.size.width, viewportSize.height / image.size.height) * 0.74)

        viewModel.updateCanvasViewportSize(viewportSize)
        viewModel.zoom = 2
        viewModel.canvasOffset = CGSize(width: 24, height: -12)
        viewModel.zoomActualPixels()

        #expect(abs(viewModel.zoom - expectedZoom) < 0.0001)
        #expect(viewModel.canvasOffset == .zero)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.zoomActualPixels"))

        viewModel.fitZoom()

        #expect(viewModel.zoom == 1)
        #expect(viewModel.canvasOffset == .zero)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.zoomFitOnScreen"))
    }

    @MainActor
    @Test func imageEditorFitOnScreenRequiresAUsableCanvasViewport() {
        let image = NSImage(size: NSSize(width: 100, height: 50))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        viewModel.zoom = 2
        viewModel.canvasOffset = CGSize(width: 12, height: 8)

        viewModel.fitZoom()

        #expect(viewModel.zoom == 2)
        #expect(viewModel.canvasOffset == CGSize(width: 12, height: 8))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.operationFailed"))
    }

    @MainActor
    @Test func imageEditorCanHideSelectionEdgesWithoutClearingSelection() {
        let image = NSImage(size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.createRectSelection(from: CGPoint(x: 10, y: 12), to: CGPoint(x: 42, y: 36))
        let selection = viewModel.document.selection

        viewModel.toggleSelectionEdgesVisible()

        #expect(viewModel.document.selection == selection)
        #expect(!viewModel.document.areSelectionEdgesVisible)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionEdgesVisibility"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionEdgesHidden"))

        viewModel.toggleSelectionEdgesVisible()

        #expect(viewModel.document.selection == selection)
        #expect(viewModel.document.areSelectionEdgesVisible)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionEdgesVisible"))
    }

    @MainActor
    @Test func imageEditorCanHideExtrasWithoutChangingUnderlyingGuidesGridOrSelection() {
        let image = NSImage(size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.addVerticalGuideAtCanvasCenter()
        viewModel.document.isGridVisible = true
        viewModel.createRectSelection(from: CGPoint(x: 10, y: 12), to: CGPoint(x: 42, y: 36))
        let selection = viewModel.document.selection

        viewModel.toggleExtrasVisible()

        #expect(!viewModel.document.areExtrasVisible)
        #expect(viewModel.document.areGuidesVisible)
        #expect(viewModel.document.isGridVisible)
        #expect(viewModel.document.areSelectionEdgesVisible)
        #expect(viewModel.document.selection == selection)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.extrasVisibility"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.extrasHidden"))

        viewModel.toggleGridSnapping()

        #expect(viewModel.document.areExtrasVisible)
        #expect(viewModel.document.isGridSnappingEnabled)
        #expect(viewModel.document.isGridVisible)
        #expect(viewModel.document.selection == selection)
    }

    @MainActor
    @Test func imageEditorCanHideTransformControlsWithoutChangingSelectedLayerFrame() throws {
        let image = NSImage(size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let selectedFrame = try #require(viewModel.selectedLayerTransformFrame)

        viewModel.toggleTransformControlsVisible()

        #expect(!viewModel.document.areTransformControlsVisible)
        #expect(viewModel.selectedLayerTransformFrame == selectedFrame)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.transformControlsVisibility"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.transformControlsHidden"))

        viewModel.toggleTransformControlsVisible()

        #expect(viewModel.document.areTransformControlsVisible)
        #expect(viewModel.selectedLayerTransformFrame == selectedFrame)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.transformControlsVisible"))
    }

    @Test func imageEditorDoesNotGrowIntoHeavyExpansionCategories() {
        let blockedFragments = [
            "3d",
            "plugin",
            "generative",
            "neural",
            "cutout",
            "backgroundRemoval",
            "backgroundMatting",
            "cameraRaw"
        ]

        let capabilityNames = ImageEditorTool.allCases.map(\.rawValue)
            + ImageEditorAdjustment.allCases.map(\.rawValue)
            + ImageEditorFilter.allCases.map(\.rawValue)

        for name in capabilityNames {
            for fragment in blockedFragments {
                #expect(!name.localizedCaseInsensitiveContains(fragment))
            }
        }
    }

    @Test func editorSourceDoesNotIntroduceHeavyExpansionEntryPoints() throws {
        let blockedFragments = [
            "plugin",
            "generative",
            "neural",
            "cameraRaw",
            "backgroundRemoval",
            "backgroundMatting",
            "aiCutout",
            "smartCutout",
            "segmentationModel",
            "threeDimensional",
            "threeD"
        ]
        let editorFiles = try FileManager.default.contentsOfDirectory(
            at: Self.repositoryRoot().appendingPathComponent("veilpic"),
            includingPropertiesForKeys: nil
        )
        .filter { url in
            url.pathExtension == "swift" && url.lastPathComponent.hasPrefix("ImageEditor")
        }

        for file in editorFiles {
            let source = try String(contentsOf: file, encoding: .utf8)
            for fragment in blockedFragments {
                #expect(source.range(of: fragment, options: [.caseInsensitive]) == nil)
            }
        }
    }

    @Test func productOverviewDocumentsPreserveAndDoNotExpandEditorScope() throws {
        let overview = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("product-overview.md"),
            encoding: .utf8
        )

        #expect(overview.contains("编辑器目标收敛为轻量 Photoshop 7.0 风格"))
        #expect(overview.contains("现有能力和 UI 组件不做删减"))
        #expect(overview.contains("不再追求完整 Photopea 级别能力"))
        #expect(overview.contains("暂不扩展精细化 AI 抠图、3D、插件系统、复杂云端 PSD 协作等重型功能"))
        #expect(overview.contains("后续工作重点约束在整理、稳定和易用性上"))
    }

    @Test func editorNoLongerCarriesComingSoonToolPlaceholders() throws {
        let blockedKeys = [
            "imageEditor.tool.soon",
            "imageEditor.status.toolSoon",
            "imageEditor.status.menuSoon",
            "imageEditor.status.exportSoon"
        ]
        let sourceFiles = [
            "veilpic/ImageEditorModels.swift",
            "veilpic/ImageEditorView.swift",
            "veilpic/ImageEditorViewModel.swift",
            "veilpic/zh-Hans.lproj/Localizable.strings",
            "veilpic/en.lproj/Localizable.strings",
            "veilpic/ja.lproj/Localizable.strings"
        ]

        for relativePath in sourceFiles {
            let source = try String(
                contentsOf: Self.repositoryRoot().appendingPathComponent(relativePath),
                encoding: .utf8
            )
            for key in blockedKeys {
                #expect(!source.contains(key))
            }
        }
    }

    @Test func layerMenuExposesSelectionLayerCommandsInPhotoshopStyleLocation() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let layerMenuStart = try #require(source.range(of: "private var layerMenu: some View"))
        let nextMenuStart = try #require(
            source[layerMenuStart.upperBound...].range(of: "private var layerSelectAttributeMenu: some View")
        )
        let layerMenuSource = source[layerMenuStart.lowerBound..<nextMenuStart.lowerBound]

        #expect(layerMenuSource.contains("imageEditor.action.selectionCopyLayer"))
        #expect(layerMenuSource.contains("viewModel.copySelectionToNewLayer()"))
        #expect(layerMenuSource.contains("viewModel.canCopySelectionToNewLayer"))
        #expect(layerMenuSource.contains("imageEditor.action.selectionCutLayer"))
        #expect(layerMenuSource.contains("viewModel.cutSelectionToNewLayer()"))
        #expect(layerMenuSource.contains("viewModel.canCutSelectionToNewLayer"))
    }

    @Test func selectMenuExposesSavedSelectionCommandsInPhotoshopStyleLocation() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let selectMenuStart = try #require(source.range(of: "private var selectMenu: some View"))
        let nextMenuStart = try #require(
            source[selectMenuStart.upperBound...].range(of: "private var alphaChannelMenu: some View")
        )
        let selectMenuSource = source[selectMenuStart.lowerBound..<nextMenuStart.lowerBound]
        let selectMenuText = String(selectMenuSource)

        #expect(selectMenuSource.contains("imageEditor.action.saveSelection"))
        #expect(selectMenuSource.contains("viewModel.saveCurrentSelection()"))
        #expect(selectMenuSource.contains("viewModel.hasSelection"))
        #expect(selectMenuSource.contains("imageEditor.action.restoreSelection"))
        #expect(selectMenuSource.contains("viewModel.restoreSavedSelection()"))
        #expect(selectMenuSource.contains("viewModel.hasSavedSelection"))
        #expect(selectMenuText.components(separatedBy: "imageEditor.action.saveSelection").count == 2)
        #expect(selectMenuText.components(separatedBy: "imageEditor.action.restoreSelection").count == 2)
    }

    @Test func windowMenuExposesChannelPanelActionsInPhotoshopStyleLocation() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let channelMenuStart = try #require(source.range(of: "private var channelActionsMenu: some View"))
        let nextMenuStart = try #require(
            source[channelMenuStart.upperBound...].range(of: "private var pathActionsMenu: some View")
        )
        let channelMenuSource = source[channelMenuStart.lowerBound..<nextMenuStart.lowerBound]

        #expect(channelMenuSource.contains("imageEditor.menu.window.channels"))
        #expect(channelMenuSource.contains("imageEditor.action.channelsShowPanel"))
        #expect(channelMenuSource.contains("selectedLayerPanelTab = .channels"))
        #expect(channelMenuSource.contains("imageEditor.menu.window.channels.preview"))
        #expect(channelMenuSource.contains("ImageEditorChannelPreview.allCases"))
        #expect(channelMenuSource.contains("viewModel.selectChannelPreview(channel)"))
        #expect(channelMenuSource.contains("imageEditor.menu.window.channels.selection"))
        #expect(channelMenuSource.contains("viewModel.loadSelectionFromChannel(channel)"))
        #expect(channelMenuSource.contains("imageEditor.menu.window.channels.alpha"))
        #expect(channelMenuSource.contains("imageEditor.action.alphaChannelBlank"))
        #expect(channelMenuSource.contains("viewModel.createBlankAlphaChannel()"))
        #expect(channelMenuSource.contains("viewModel.canCreateBlankAlphaChannel"))
        #expect(channelMenuSource.contains("imageEditor.action.channelSaveSelection"))
        #expect(channelMenuSource.contains("viewModel.saveSelectionAsAlphaChannel()"))
        #expect(channelMenuSource.contains("viewModel.canSaveSelectionAsAlphaChannel"))
        #expect(channelMenuSource.contains("imageEditor.action.channelSaveLayerMask"))
        #expect(channelMenuSource.contains("viewModel.saveSelectedLayerMaskAsAlphaChannel()"))
        #expect(channelMenuSource.contains("viewModel.canSaveSelectedLayerMaskAsAlphaChannel"))
        #expect(channelMenuSource.contains("imageEditor.action.channelSaveLayerTransparency"))
        #expect(channelMenuSource.contains("viewModel.saveSelectedLayerTransparencyAsAlphaChannel()"))
        #expect(channelMenuSource.contains("viewModel.canSaveSelectedLayerTransparencyAsAlphaChannel"))
        #expect(channelMenuSource.contains("imageEditor.action.channelSaveCurrentAsAlpha"))
        #expect(channelMenuSource.contains("viewModel.saveSelectedChannelAsAlphaChannel()"))
        #expect(channelMenuSource.contains("viewModel.canSaveSelectedChannelAsAlphaChannel"))
        #expect(channelMenuSource.contains("imageEditor.action.alphaChannelLoadSelectedSelection"))
        #expect(channelMenuSource.contains("viewModel.loadSelectionFromSelectedAlphaChannel()"))
        #expect(channelMenuSource.contains("viewModel.canLoadSelectedAlphaChannelSelection"))
        #expect(channelMenuSource.contains("imageEditor.action.alphaChannelApplySelectedToMask"))
        #expect(channelMenuSource.contains("viewModel.applySelectedAlphaChannelToSelectedLayerMask()"))
        #expect(channelMenuSource.contains("viewModel.canApplySelectedAlphaChannelToLayerMask"))
        #expect(channelMenuSource.contains("imageEditor.action.alphaChannelDeleteSelected"))
        #expect(channelMenuSource.contains("viewModel.deleteSelectedAlphaChannel()"))
        #expect(channelMenuSource.contains("viewModel.canDeleteSelectedAlphaChannel"))
    }

    @Test func windowMenuExposesNavigatorPanelActionsInPhotoshopStyleLocation() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let navigatorMenuStart = try #require(source.range(of: "private var navigatorActionsMenu: some View"))
        let nextMenuStart = try #require(
            source[navigatorMenuStart.upperBound...].range(of: "private var infoActionsMenu: some View")
        )
        let navigatorMenuSource = source[navigatorMenuStart.lowerBound..<nextMenuStart.lowerBound]

        #expect(navigatorMenuSource.contains("imageEditor.menu.window.navigator"))
        #expect(navigatorMenuSource.contains("imageEditor.action.navigatorShowPanel"))
        #expect(navigatorMenuSource.contains("viewModel.sizeText"))
        #expect(navigatorMenuSource.contains("imageEditor.menu.view.zoomIn"))
        #expect(navigatorMenuSource.contains("viewModel.zoomIn()"))
        #expect(navigatorMenuSource.contains("imageEditor.menu.view.zoomOut"))
        #expect(navigatorMenuSource.contains("viewModel.zoomOut()"))
        #expect(navigatorMenuSource.contains("imageEditor.menu.view.actualPixels"))
        #expect(navigatorMenuSource.contains("viewModel.zoomActualPixels()"))
        #expect(navigatorMenuSource.contains("imageEditor.menu.view.fit"))
        #expect(navigatorMenuSource.contains("viewModel.fitZoom()"))
    }

    @Test func windowMenuExposesInfoPanelActionsInPhotoshopStyleLocation() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let infoMenuStart = try #require(source.range(of: "private var infoActionsMenu: some View"))
        let nextMenuStart = try #require(
            source[infoMenuStart.upperBound...].range(of: "private var histogramActionsMenu: some View")
        )
        let infoMenuSource = source[infoMenuStart.lowerBound..<nextMenuStart.lowerBound]

        #expect(infoMenuSource.contains("imageEditor.menu.window.info"))
        #expect(infoMenuSource.contains("imageEditor.action.infoShowPanel"))
        #expect(infoMenuSource.contains("viewModel.pointerText"))
        #expect(infoMenuSource.contains("viewModel.sizeText"))
        #expect(infoMenuSource.contains("viewModel.colorText"))
    }

    @Test func windowMenuExposesHistogramPanelActionsInPhotoshopStyleLocation() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let histogramMenuStart = try #require(source.range(of: "private var histogramActionsMenu: some View"))
        let nextMenuStart = try #require(
            source[histogramMenuStart.upperBound...].range(of: "private var layerActionsMenu: some View")
        )
        let histogramMenuSource = source[histogramMenuStart.lowerBound..<nextMenuStart.lowerBound]

        #expect(histogramMenuSource.contains("imageEditor.menu.window.histogram"))
        #expect(histogramMenuSource.contains("imageEditor.action.histogramShowPanel"))
        #expect(histogramMenuSource.contains("viewModel.histogramSummary"))
        #expect(histogramMenuSource.contains("viewModel.histogramAverageText(for: summary)"))
        #expect(histogramMenuSource.contains("viewModel.histogramLuminanceText(for: summary)"))
        #expect(histogramMenuSource.contains("viewModel.histogramClippingText(for: summary)"))
    }

    @Test func windowMenuExposesColorPanelActionsInPhotoshopStyleLocation() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let colorMenuStart = try #require(source.range(of: "private var colorActionsMenu: some View"))
        let nextMenuStart = try #require(
            source[colorMenuStart.upperBound...].range(of: "private var layerActionsMenu: some View")
        )
        let colorMenuSource = source[colorMenuStart.lowerBound..<nextMenuStart.lowerBound]

        #expect(colorMenuSource.contains("imageEditor.menu.window.color"))
        #expect(colorMenuSource.contains("imageEditor.action.colorShowPanel"))
        #expect(colorMenuSource.contains("viewModel.colorPanelSummaryText"))
        #expect(colorMenuSource.contains("imageEditor.action.colorDefaultForegroundBackground"))
        #expect(colorMenuSource.contains("viewModel.resetForegroundBackgroundColors()"))
        #expect(colorMenuSource.contains("imageEditor.action.colorSwapForegroundBackground"))
        #expect(colorMenuSource.contains("viewModel.swapForegroundBackgroundColors()"))
        #expect(colorMenuSource.contains("imageEditor.action.colorUseEyedropper"))
        #expect(colorMenuSource.contains("viewModel.selectEyedropperForColorSampling()"))
    }

    @MainActor
    @Test func colorPanelActionsReuseExistingForegroundBackgroundState() throws {
        let image = NSImage(size: NSSize(width: 16, height: 16))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.foregroundColor = .systemBlue
        viewModel.backgroundColor = .systemYellow
        viewModel.swapForegroundBackgroundColors()

        #expect(Self.deviceRGBComponents(viewModel.foregroundColor) == Self.deviceRGBComponents(.systemYellow))
        #expect(Self.deviceRGBComponents(viewModel.backgroundColor) == Self.deviceRGBComponents(.systemBlue))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.colorSwapForegroundBackground"))

        viewModel.resetForegroundBackgroundColors()

        #expect(Self.deviceRGBComponents(viewModel.foregroundColor) == Self.deviceRGBComponents(.black))
        #expect(Self.deviceRGBComponents(viewModel.backgroundColor) == Self.deviceRGBComponents(.white))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.colorDefaultForegroundBackground"))

        viewModel.selectTool(.brush)
        viewModel.selectEyedropperForColorSampling()

        #expect(viewModel.selectedTool == .eyedropper)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.colorEyedropperReady"))
    }

    @Test func windowMenuExposesSwatchesPanelActionsInPhotoshopStyleLocation() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let swatchesMenuStart = try #require(source.range(of: "private var swatchesActionsMenu: some View"))
        let nextMenuStart = try #require(
            source[swatchesMenuStart.upperBound...].range(of: "private var layerActionsMenu: some View")
        )
        let swatchesMenuSource = source[swatchesMenuStart.lowerBound..<nextMenuStart.lowerBound]

        #expect(swatchesMenuSource.contains("imageEditor.menu.window.swatches"))
        #expect(swatchesMenuSource.contains("imageEditor.action.swatchesShowPanel"))
        #expect(swatchesMenuSource.contains("viewModel.swatchesPanelSummaryText"))
        #expect(swatchesMenuSource.contains("imageEditor.menu.window.swatches.foreground"))
        #expect(swatchesMenuSource.contains("viewModel.applySwatchToForeground(swatch)"))
        #expect(swatchesMenuSource.contains("imageEditor.menu.window.swatches.background"))
        #expect(swatchesMenuSource.contains("viewModel.applySwatchToBackground(swatch)"))
    }

    @MainActor
    @Test func swatchesPanelActionsApplyDefaultPaletteToForegroundAndBackground() throws {
        let image = NSImage(size: NSSize(width: 16, height: 16))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let red = try #require(ImageEditorColorSwatch.defaultPalette.first { $0.id == "red" })
        let blue = try #require(ImageEditorColorSwatch.defaultPalette.first { $0.id == "blue" })

        viewModel.applySwatchToForeground(red)

        #expect(Self.deviceRGBComponents(viewModel.foregroundColor) == Self.deviceRGBComponents(red.color))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.swatchForegroundApplied", red.title, viewModel.colorText))

        viewModel.applySwatchToBackground(blue)

        #expect(Self.deviceRGBComponents(viewModel.backgroundColor) == Self.deviceRGBComponents(blue.color))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.swatchBackgroundApplied", blue.title, viewModel.backgroundColorText))
        #expect(viewModel.swatchesPanelSummaryText.contains(red.title))
        #expect(viewModel.swatchesPanelSummaryText.contains(blue.title))
    }

    @Test func windowMenuExposesBrushesPanelActionsInPhotoshopStyleLocation() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let brushesMenuStart = try #require(source.range(of: "private var brushesActionsMenu: some View"))
        let nextMenuStart = try #require(
            source[brushesMenuStart.upperBound...].range(of: "private var layerActionsMenu: some View")
        )
        let brushesMenuSource = source[brushesMenuStart.lowerBound..<nextMenuStart.lowerBound]

        #expect(brushesMenuSource.contains("imageEditor.menu.window.brushes"))
        #expect(brushesMenuSource.contains("imageEditor.action.brushesShowPanel"))
        #expect(brushesMenuSource.contains("viewModel.brushesPanelSummaryText"))
        #expect(brushesMenuSource.contains("imageEditor.menu.window.brushes.tools"))
        #expect(brushesMenuSource.contains("viewModel.selectBrushPanelTool(tool)"))
        #expect(brushesMenuSource.contains("imageEditor.menu.window.brushes.presets"))
        #expect(brushesMenuSource.contains("viewModel.applyBrushPreset(preset)"))
    }

    @MainActor
    @Test func brushesPanelActionsReuseExistingBrushSettings() throws {
        let image = NSImage(size: NSSize(width: 16, height: 16))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let preset = try #require(ImageEditorBrushPreset.defaultPresets.first { $0.size == 36 })

        viewModel.opacity = 0.55
        viewModel.hardness = 0.35
        viewModel.selectBrushPanelTool(.smudge)

        #expect(viewModel.selectedTool == .smudge)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.brushToolSelected", ImageEditorTool.smudge.title, viewModel.brushesPanelSummaryText))
        #expect(viewModel.brushesPanelSummaryText.contains(ImageEditorTool.smudge.title))
        #expect(viewModel.brushesPanelSummaryText.contains("55"))
        #expect(viewModel.brushesPanelSummaryText.contains("35"))

        viewModel.applyBrushPreset(preset)

        #expect(Int(viewModel.brushSize.rounded()) == 36)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.brushPresetApplied", preset.title, viewModel.brushesPanelSummaryText))
    }

    @Test func windowMenuExposesCharacterParagraphPanelActionsInPhotoshopStyleLocation() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let characterMenuStart = try #require(source.range(of: "private var characterActionsMenu: some View"))
        let paragraphMenuStart = try #require(
            source[characterMenuStart.upperBound...].range(of: "private var paragraphActionsMenu: some View")
        )
        let nextMenuStart = try #require(
            source[paragraphMenuStart.upperBound...].range(of: "private var layerActionsMenu: some View")
        )
        let textPanelSource = source[characterMenuStart.lowerBound..<nextMenuStart.lowerBound]

        #expect(textPanelSource.contains("imageEditor.menu.window.character"))
        #expect(textPanelSource.contains("imageEditor.action.characterShowPanel"))
        #expect(textPanelSource.contains("viewModel.characterPanelSummaryText"))
        #expect(textPanelSource.contains("viewModel.selectCharacterPanelTool()"))
        #expect(textPanelSource.contains("viewModel.toggleCharacterBold()"))
        #expect(textPanelSource.contains("viewModel.toggleCharacterItalic()"))
        #expect(textPanelSource.contains("imageEditor.menu.window.paragraph"))
        #expect(textPanelSource.contains("imageEditor.action.paragraphShowPanel"))
        #expect(textPanelSource.contains("viewModel.paragraphPanelSummaryText"))
        #expect(textPanelSource.contains("ImageEditorTextAlignment.allCases"))
        #expect(textPanelSource.contains("viewModel.selectParagraphAlignment(alignment)"))
    }

    @MainActor
    @Test func characterAndParagraphPanelActionsReuseExistingTextSettings() throws {
        let image = NSImage(size: NSSize(width: 16, height: 16))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.textValue = "Caption"
        viewModel.textSize = 48
        viewModel.textCharacterSpacing = 4
        viewModel.textLineSpacing = 12
        viewModel.textBoxWidth = 320
        viewModel.selectCharacterPanelTool()

        #expect(viewModel.selectedTool == .text)
        #expect(viewModel.statusText == viewModel.characterPanelSummaryText)
        #expect(viewModel.characterPanelSummaryText.contains("Caption"))
        #expect(viewModel.characterPanelSummaryText.contains("48"))
        #expect(viewModel.characterPanelSummaryText.contains("4"))
        #expect(viewModel.characterPanelSummaryText.contains("12"))

        viewModel.toggleCharacterBold()
        viewModel.toggleCharacterItalic()

        #expect(viewModel.textBold)
        #expect(viewModel.textItalic)
        #expect(viewModel.statusText == viewModel.characterPanelSummaryText)
        #expect(viewModel.characterPanelSummaryText.contains(L10n.text("imageEditor.characterPanel.enabled")))

        viewModel.selectParagraphAlignment(.center)

        #expect(viewModel.selectedTextAlignment == .center)
        #expect(viewModel.statusText == viewModel.paragraphPanelSummaryText)
        #expect(viewModel.paragraphPanelSummaryText.contains(ImageEditorTextAlignment.center.title))
        #expect(viewModel.paragraphPanelSummaryText.contains("320"))
    }

    @Test func windowMenuExposesStylesPanelActionsInPhotoshopStyleLocation() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let stylesMenuStart = try #require(source.range(of: "private var stylesActionsMenu: some View"))
        let nextMenuStart = try #require(
            source[stylesMenuStart.upperBound...].range(of: "private var layerActionsMenu: some View")
        )
        let stylesMenuSource = source[stylesMenuStart.lowerBound..<nextMenuStart.lowerBound]

        #expect(stylesMenuSource.contains("imageEditor.menu.window.styles"))
        #expect(stylesMenuSource.contains("imageEditor.action.stylesShowPanel"))
        #expect(stylesMenuSource.contains("viewModel.stylesPanelSummaryText"))
        #expect(stylesMenuSource.contains("layerStyleActionItems"))
        #expect(source.contains("viewModel.copySelectedLayerStyle()"))
        #expect(source.contains("viewModel.pasteLayerStyleToSelectedLayers()"))
        #expect(source.contains("viewModel.clearSelectedLayerStyles()"))
        #expect(source.contains("viewModel.toggleSelectedLayerStroke()"))
        #expect(source.contains("viewModel.toggleSelectedLayerShadow()"))
        #expect(source.contains("viewModel.toggleSelectedLayerInnerShadow()"))
        #expect(source.contains("viewModel.toggleSelectedLayerOuterGlow()"))
        #expect(source.contains("viewModel.toggleSelectedLayerInnerGlow()"))
        #expect(source.contains("viewModel.toggleSelectedLayerColorOverlay()"))
        #expect(source.contains("viewModel.toggleSelectedLayerGradientOverlay()"))
        #expect(source.contains("viewModel.toggleSelectedLayerPatternOverlay()"))
        #expect(source.contains("viewModel.toggleSelectedLayerSatin()"))
        #expect(source.contains("viewModel.toggleSelectedLayerBevel()"))
    }

    @MainActor
    @Test func stylesPanelSummaryReusesExistingLayerStyleState() throws {
        let image = NSImage(size: NSSize(width: 16, height: 16))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.addLayer()
        viewModel.renameSelectedLayer(to: "Badge")

        #expect(viewModel.stylesPanelSummaryText.contains("Badge"))
        #expect(viewModel.stylesPanelSummaryText.contains(L10n.text("imageEditor.stylesPanel.noEffects")))

        viewModel.toggleSelectedLayerStroke()
        viewModel.toggleSelectedLayerShadow()

        #expect(viewModel.stylesPanelSummaryText.contains("Badge"))
        #expect(viewModel.stylesPanelSummaryText.contains(L10n.text("imageEditor.action.layerStroke")))
        #expect(viewModel.stylesPanelSummaryText.contains(L10n.text("imageEditor.action.layerShadow")))
    }

    @Test func windowMenuExposesLayerPanelActionsInPhotoshopStyleLocation() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let layerMenuStart = try #require(source.range(of: "private var layerActionsMenu: some View"))
        let nextMenuStart = try #require(
            source[layerMenuStart.upperBound...].range(of: "private var layerCompActionsMenu: some View")
        )
        let layerMenuSource = source[layerMenuStart.lowerBound..<nextMenuStart.lowerBound]

        #expect(layerMenuSource.contains("imageEditor.menu.window.layers"))
        #expect(layerMenuSource.contains("imageEditor.action.layersShowPanel"))
        #expect(layerMenuSource.contains("selectedLayerPanelTab = .layers"))
        #expect(layerMenuSource.contains("imageEditor.action.layerNew"))
        #expect(layerMenuSource.contains("viewModel.addLayer()"))
        #expect(layerMenuSource.contains("imageEditor.action.layerDuplicate"))
        #expect(layerMenuSource.contains("viewModel.duplicateSelectedLayer()"))
        #expect(layerMenuSource.contains("viewModel.canDuplicateSelectedLayer"))
        #expect(layerMenuSource.contains("imageEditor.action.layerDelete"))
        #expect(layerMenuSource.contains("viewModel.deleteSelectedLayer()"))
        #expect(layerMenuSource.contains("viewModel.canDeleteLayer"))
        #expect(layerMenuSource.contains("imageEditor.action.layerGroupNew"))
        #expect(layerMenuSource.contains("viewModel.addLayerGroup()"))
        #expect(layerMenuSource.contains("imageEditor.action.layerGroupSelected"))
        #expect(layerMenuSource.contains("viewModel.groupSelectedLayer()"))
        #expect(layerMenuSource.contains("viewModel.canGroupSelectedLayer"))
        #expect(layerMenuSource.contains("imageEditor.action.layerMergeDown"))
        #expect(layerMenuSource.contains("viewModel.mergeSelectedLayerDown()"))
        #expect(layerMenuSource.contains("viewModel.canMergeSelectedLayerDown"))
        #expect(layerMenuSource.contains("imageEditor.action.layerFlatten"))
        #expect(layerMenuSource.contains("viewModel.flattenImage()"))
        #expect(layerMenuSource.contains("viewModel.canFlattenImage"))
    }

    @Test func windowMenuExposesHistoryPanelActionsInPhotoshopStyleLocation() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let historyMenuStart = try #require(source.range(of: "private var historyActionsMenu: some View"))
        let nextMenuStart = try #require(
            source[historyMenuStart.upperBound...].range(of: "private var channelActionsMenu: some View")
        )
        let historyMenuSource = source[historyMenuStart.lowerBound..<nextMenuStart.lowerBound]

        #expect(historyMenuSource.contains("imageEditor.menu.window.history"))
        #expect(historyMenuSource.contains("imageEditor.action.historyShowPanel"))
        #expect(historyMenuSource.contains("viewModel.historyStateSummary"))
        #expect(historyMenuSource.contains("imageEditor.action.historySnapshotCreate"))
        #expect(historyMenuSource.contains("viewModel.createHistorySnapshot()"))
        #expect(historyMenuSource.contains("imageEditor.action.historySnapshotRestoreSelected"))
        #expect(historyMenuSource.contains("viewModel.restoreSelectedHistorySnapshot()"))
        #expect(historyMenuSource.contains("viewModel.canRestoreSelectedHistorySnapshot"))
        #expect(historyMenuSource.contains("imageEditor.action.historySnapshotDuplicate"))
        #expect(historyMenuSource.contains("viewModel.duplicateSelectedHistorySnapshot()"))
        #expect(historyMenuSource.contains("viewModel.canDuplicateSelectedHistorySnapshot"))
        #expect(historyMenuSource.contains("imageEditor.action.historySnapshotDeleteSelected"))
        #expect(historyMenuSource.contains("viewModel.deleteSelectedHistorySnapshot()"))
        #expect(historyMenuSource.contains("viewModel.canDeleteSelectedHistorySnapshot"))
        #expect(historyMenuSource.contains("imageEditor.action.historySnapshotPrevious"))
        #expect(historyMenuSource.contains("viewModel.selectPreviousHistorySnapshot()"))
        #expect(historyMenuSource.contains("viewModel.canSelectPreviousHistorySnapshot"))
        #expect(historyMenuSource.contains("imageEditor.action.historySnapshotNext"))
        #expect(historyMenuSource.contains("viewModel.selectNextHistorySnapshot()"))
        #expect(historyMenuSource.contains("viewModel.canSelectNextHistorySnapshot"))
        #expect(historyMenuSource.contains("imageEditor.action.historyClear"))
        #expect(historyMenuSource.contains("viewModel.clearHistoryStates()"))
    }

    @Test func windowMenuExposesPropertiesPanelActionsInPhotoshopStyleLocation() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let propertiesMenuStart = try #require(source.range(of: "private var propertiesActionsMenu: some View"))
        let nextMenuStart = try #require(
            source[propertiesMenuStart.upperBound...].range(of: "private var channelActionsMenu: some View")
        )
        let propertiesMenuSource = source[propertiesMenuStart.lowerBound..<nextMenuStart.lowerBound]

        #expect(propertiesMenuSource.contains("imageEditor.menu.window.properties"))
        #expect(propertiesMenuSource.contains("imageEditor.action.propertiesShowPanel"))
        #expect(propertiesMenuSource.contains("imageEditor.status.propertiesVisible"))
        #expect(propertiesMenuSource.contains("imageEditor.action.applyAdjustment"))
        #expect(propertiesMenuSource.contains("viewModel.applyAdjustment()"))
        #expect(propertiesMenuSource.contains("imageEditor.action.layerAdjustmentNew"))
        #expect(propertiesMenuSource.contains("viewModel.addAdjustmentLayer()"))
        #expect(propertiesMenuSource.contains("imageEditor.action.layerAdjustmentUpdate"))
        #expect(propertiesMenuSource.contains("viewModel.updateSelectedAdjustmentLayer()"))
        #expect(propertiesMenuSource.contains("viewModel.selectedLayerIsAdjustment"))
        #expect(propertiesMenuSource.contains("imageEditor.action.layerFilterNew"))
        #expect(propertiesMenuSource.contains("viewModel.addFilterLayer()"))
        #expect(propertiesMenuSource.contains("imageEditor.action.layerFilterUpdate"))
        #expect(propertiesMenuSource.contains("viewModel.updateSelectedFilterLayer()"))
        #expect(propertiesMenuSource.contains("viewModel.selectedLayerIsFilter"))
        #expect(propertiesMenuSource.contains("imageEditor.action.layerSmartFilterAdd"))
        #expect(propertiesMenuSource.contains("viewModel.addSmartFilterToSelectedLayer()"))
        #expect(propertiesMenuSource.contains("viewModel.canAddSmartFilterToSelectedLayer"))
        #expect(propertiesMenuSource.contains("imageEditor.action.layerSmartFilterUpdate"))
        #expect(propertiesMenuSource.contains("viewModel.updateLastSmartFilterOnSelectedLayer()"))
        #expect(propertiesMenuSource.contains("viewModel.canUpdateLastSmartFilterOnSelectedLayer"))
        #expect(propertiesMenuSource.contains("imageEditor.action.addText"))
        #expect(propertiesMenuSource.contains("viewModel.addText()"))
    }

    @Test func windowMenuExposesLayerCompPanelActionsInPhotoshopStyleLocation() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let layerCompMenuStart = try #require(source.range(of: "private var layerCompActionsMenu: some View"))
        let nextMenuStart = try #require(
            source[layerCompMenuStart.upperBound...].range(of: "private var historyActionsMenu: some View")
        )
        let layerCompMenuSource = source[layerCompMenuStart.lowerBound..<nextMenuStart.lowerBound]

        #expect(layerCompMenuSource.contains("imageEditor.menu.window.layerComps"))
        #expect(layerCompMenuSource.contains("imageEditor.action.layerCompsShowPanel"))
        #expect(layerCompMenuSource.contains("selectedLayerPanelTab = .comps"))
        #expect(layerCompMenuSource.contains("imageEditor.action.layerCompNew"))
        #expect(layerCompMenuSource.contains("viewModel.addLayerComp()"))
        #expect(layerCompMenuSource.contains("imageEditor.action.layerCompApply"))
        #expect(layerCompMenuSource.contains("viewModel.applySelectedLayerComp()"))
        #expect(layerCompMenuSource.contains("viewModel.canApplySelectedLayerComp"))
        #expect(layerCompMenuSource.contains("imageEditor.action.layerCompUpdate"))
        #expect(layerCompMenuSource.contains("viewModel.updateSelectedLayerComp()"))
        #expect(layerCompMenuSource.contains("viewModel.canUpdateSelectedLayerComp"))
        #expect(layerCompMenuSource.contains("imageEditor.action.layerCompDuplicate"))
        #expect(layerCompMenuSource.contains("viewModel.duplicateSelectedLayerComp()"))
        #expect(layerCompMenuSource.contains("viewModel.canDuplicateSelectedLayerComp"))
        #expect(layerCompMenuSource.contains("imageEditor.action.layerCompDelete"))
        #expect(layerCompMenuSource.contains("viewModel.deleteSelectedLayerComp()"))
        #expect(layerCompMenuSource.contains("viewModel.canDeleteSelectedLayerComp"))
        #expect(layerCompMenuSource.contains("imageEditor.action.layerCompPrevious"))
        #expect(layerCompMenuSource.contains("viewModel.selectPreviousLayerComp()"))
        #expect(layerCompMenuSource.contains("viewModel.canSelectPreviousLayerComp"))
        #expect(layerCompMenuSource.contains("imageEditor.action.layerCompNext"))
        #expect(layerCompMenuSource.contains("viewModel.selectNextLayerComp()"))
        #expect(layerCompMenuSource.contains("viewModel.canSelectNextLayerComp"))
    }

    @Test func windowMenuExposesPathPanelActionsInPhotoshopStyleLocation() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let pathMenuStart = try #require(source.range(of: "private var pathActionsMenu: some View"))
        let nextBrace = try #require(
            source[pathMenuStart.upperBound...].range(of: "\n    }\n}")
        )
        let pathMenuSource = source[pathMenuStart.lowerBound..<nextBrace.upperBound]

        #expect(pathMenuSource.contains("imageEditor.menu.window.paths"))
        #expect(pathMenuSource.contains("imageEditor.action.pathStroke"))
        #expect(pathMenuSource.contains("viewModel.strokeSelectedPathToPixelLayer()"))
        #expect(pathMenuSource.contains("viewModel.canStrokeSelectedPathToPixelLayer"))
        #expect(pathMenuSource.contains("imageEditor.action.pathFill"))
        #expect(pathMenuSource.contains("viewModel.fillSelectedPathToPixelLayer()"))
        #expect(pathMenuSource.contains("viewModel.canFillSelectedPathToPixelLayer"))
        #expect(pathMenuSource.contains("imageEditor.action.pathSelection"))
        #expect(pathMenuSource.contains("viewModel.loadSelectionFromSelectedPath()"))
        #expect(pathMenuSource.contains("viewModel.canLoadSelectionFromSelectedPath"))
        #expect(pathMenuSource.contains("imageEditor.action.pathVectorMask"))
        #expect(pathMenuSource.contains("viewModel.applySelectedPathAsVectorMask()"))
        #expect(pathMenuSource.contains("viewModel.canApplySelectedPathAsVectorMask"))
        #expect(pathMenuSource.contains("imageEditor.action.pathLayerMask"))
        #expect(pathMenuSource.contains("viewModel.applySelectedPathAsLayerMask()"))
        #expect(pathMenuSource.contains("viewModel.canApplySelectedPathAsLayerMask"))
    }

    private static func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private static func deviceRGBComponents(_ color: NSColor) -> [Int] {
        let deviceColor = color.usingColorSpace(.deviceRGB) ?? color
        return [
            Int((deviceColor.redComponent * 255).rounded()),
            Int((deviceColor.greenComponent * 255).rounded()),
            Int((deviceColor.blueComponent * 255).rounded()),
            Int((deviceColor.alphaComponent * 255).rounded())
        ]
    }
}
