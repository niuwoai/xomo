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
                "quickSelection",
                "crop",
                "brush",
                "eraser",
                "cloneStamp",
                "dodge",
                "burn",
                "sponge",
                "blur",
                "sharpen",
                "smudge",
                "healingBrush",
                "patchTool",
                "redEye",
                "paintBucket",
                "gradient",
                "eyedropper",
                "colorSampler",
                "text",
                "rectangle",
                "ellipse",
                "pen",
                "pathSelection",
                "directSelection",
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

    @Test func imageEditorToolsExposeClassicPhotoshopShortcuts() {
        let shortcuts = Dictionary(
            uniqueKeysWithValues: ImageEditorTool.allCases.compactMap { tool in
                tool.classicShortcutKey.map { (tool.rawValue, String($0)) }
            }
        )

        #expect(shortcuts["move"] == "v")
        #expect(shortcuts["marquee"] == "m")
        #expect(shortcuts["lasso"] == "l")
        #expect(shortcuts["magicWand"] == "w")
        #expect(shortcuts["crop"] == "c")
        #expect(shortcuts["brush"] == "b")
        #expect(shortcuts["eraser"] == "e")
        #expect(shortcuts["cloneStamp"] == "s")
        #expect(shortcuts["dodge"] == "o")
        #expect(shortcuts["burn"] == "o")
        #expect(shortcuts["paintBucket"] == "g")
        #expect(shortcuts["gradient"] == "g")
        #expect(shortcuts["eyedropper"] == "i")
        #expect(shortcuts["text"] == "t")
        #expect(shortcuts["rectangle"] == "u")
        #expect(shortcuts["ellipse"] == "u")
        #expect(shortcuts["pen"] == "p")
        #expect(shortcuts["pathSelection"] == "a")
        #expect(shortcuts["directSelection"] == "a")
        #expect(shortcuts["hand"] == "h")
        #expect(shortcuts["zoom"] == "z")
        #expect(shortcuts["blur"] == "r")
        #expect(shortcuts["sharpen"] == "r")
        #expect(shortcuts["smudge"] == "r")
        #expect(shortcuts["healingBrush"] == "j")
        #expect(shortcuts["patchTool"] == "j")
        #expect(ImageEditorTool.classicShortcutGroup(for: "g")?.tools == [.paintBucket, .gradient])
        #expect(ImageEditorTool.classicShortcutGroup(for: "o")?.tools == [.dodge, .burn, .sponge])
        #expect(ImageEditorTool.classicShortcutGroup(for: "r")?.tools == [.blur, .sharpen, .smudge])
        #expect(ImageEditorTool.classicShortcutGroup(for: "u")?.tools == [.rectangle, .ellipse])
        #expect(ImageEditorTool.classicShortcutGroup(for: "j")?.tools == [.healingBrush, .patchTool, .redEye])
        #expect(ImageEditorTool.classicShortcutGroup(for: "a")?.tools == [.pathSelection, .directSelection])
        #expect(ImageEditorTool.paintBucket.isClassicShortcutPrimary)
        #expect(!ImageEditorTool.gradient.isClassicShortcutPrimary)
    }

    @Test func editorRegistersClassicToolShortcutButtonsWithoutDuplicatingToolRailShortcuts() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("private var selectedToolIcon: some View"))
        #expect(source.contains("if viewModel.selectedTool == .paintBucket"))
        #expect(source.contains("ImageEditorPaintBucketSymbol()"))

        let toolRailStart = try #require(source.range(of: "private var toolRail: some View"))
        let nextSectionStart = try #require(
            source[toolRailStart.upperBound...].range(of: "private var colorChips: some View")
        )
        let toolRailSource = source[toolRailStart.lowerBound..<nextSectionStart.lowerBound]

        #expect(toolRailSource.contains("ForEach(ImageEditorTool.allCases)"))
        #expect(toolRailSource.contains("viewModel.selectTool(tool)"))
        #expect(!toolRailSource.contains("keyboardShortcut"))
        #expect(!toolRailSource.contains("ImageEditorToolShortcutModifier"))

        let shortcutButtonsStart = try #require(source.range(of: "private var toolShortcutButtons: some View"))
        let shortcutButtonsEnd = try #require(
            source[shortcutButtonsStart.upperBound...].range(of: "private var colorChips: some View")
        )
        let shortcutButtonsSource = source[shortcutButtonsStart.lowerBound..<shortcutButtonsEnd.lowerBound]

        #expect(shortcutButtonsSource.contains("ForEach(ImageEditorTool.classicShortcutGroups)"))
        #expect(shortcutButtonsSource.contains("viewModel.selectClassicToolShortcut(group.key)"))
        #expect(shortcutButtonsSource.contains(".keyboardShortcut(KeyEquivalent(group.key), modifiers: [])"))
        #expect(shortcutButtonsSource.contains("viewModel.cycleClassicToolShortcut(group.key)"))
        #expect(shortcutButtonsSource.contains(".keyboardShortcut(KeyEquivalent(group.key), modifiers: [.shift])"))

        let brushShortcutStart = try #require(source.range(of: "private var brushShortcutButtons: some View"))
        let brushShortcutEnd = try #require(
            source[brushShortcutStart.upperBound...].range(of: "private var colorChips: some View")
        )
        let brushShortcutSource = source[brushShortcutStart.lowerBound..<brushShortcutEnd.lowerBound]

        #expect(brushShortcutSource.contains("viewModel.adjustBrushSizeShortcut(by: -1)"))
        #expect(brushShortcutSource.contains(".keyboardShortcut(\"[\", modifiers: [])"))
        #expect(brushShortcutSource.contains("viewModel.adjustBrushSizeShortcut(by: 1)"))
        #expect(brushShortcutSource.contains(".keyboardShortcut(\"]\", modifiers: [])"))
        #expect(brushShortcutSource.contains("viewModel.adjustBrushHardnessShortcut(by: -0.25)"))
        #expect(brushShortcutSource.contains(".keyboardShortcut(\"[\", modifiers: [.shift])"))
        #expect(brushShortcutSource.contains("viewModel.adjustBrushHardnessShortcut(by: 0.25)"))
        #expect(brushShortcutSource.contains(".keyboardShortcut(\"]\", modifiers: [.shift])"))

        let opacityShortcutStart = try #require(source.range(of: "private var opacityShortcutButtons: some View"))
        let opacityShortcutEnd = try #require(
            source[opacityShortcutStart.upperBound...].range(of: "private var colorChips: some View")
        )
        let opacityShortcutSource = source[opacityShortcutStart.lowerBound..<opacityShortcutEnd.lowerBound]

        #expect(opacityShortcutSource.contains("ForEach([1, 2, 3, 4, 5, 6, 7, 8, 9, 0], id: \\.self)"))
        #expect(opacityShortcutSource.contains("viewModel.applyOpacityShortcutDigit(digit)"))
        #expect(opacityShortcutSource.contains(".keyboardShortcut(KeyEquivalent(Character(String(digit))), modifiers: [])"))

        let colorShortcutStart = try #require(source.range(of: "private var colorShortcutButtons: some View"))
        let colorShortcutEnd = try #require(
            source[colorShortcutStart.upperBound...].range(of: "private var colorChips: some View")
        )
        let colorShortcutSource = source[colorShortcutStart.lowerBound..<colorShortcutEnd.lowerBound]

        #expect(colorShortcutSource.contains("viewModel.resetForegroundBackgroundColors()"))
        #expect(colorShortcutSource.contains(".keyboardShortcut(\"d\", modifiers: [])"))
        #expect(colorShortcutSource.contains("viewModel.swapForegroundBackgroundColors()"))
        #expect(colorShortcutSource.contains(".keyboardShortcut(\"x\", modifiers: [])"))

        let nudgeShortcutStart = try #require(source.range(of: "private var nudgeShortcutButtons: some View"))
        let nudgeShortcutEnd = try #require(
            source[nudgeShortcutStart.upperBound...].range(of: "private var colorChips: some View")
        )
        let nudgeShortcutSource = source[nudgeShortcutStart.lowerBound..<nudgeShortcutEnd.lowerBound]

        #expect(nudgeShortcutSource.contains("nudgeShortcutButton(.leftArrow, delta: CGSize(width: -1, height: 0), modifiers: [])"))
        #expect(nudgeShortcutSource.contains("nudgeShortcutButton(.rightArrow, delta: CGSize(width: 1, height: 0), modifiers: [])"))
        #expect(nudgeShortcutSource.contains("nudgeShortcutButton(.upArrow, delta: CGSize(width: 0, height: -1), modifiers: [])"))
        #expect(nudgeShortcutSource.contains("nudgeShortcutButton(.downArrow, delta: CGSize(width: 0, height: 1), modifiers: [])"))
        #expect(nudgeShortcutSource.contains("nudgeShortcutButton(.leftArrow, delta: CGSize(width: -5, height: 0), modifiers: [.option])"))
        #expect(nudgeShortcutSource.contains("nudgeShortcutButton(.rightArrow, delta: CGSize(width: 5, height: 0), modifiers: [.option])"))
        #expect(nudgeShortcutSource.contains("nudgeShortcutButton(.upArrow, delta: CGSize(width: 0, height: -5), modifiers: [.option])"))
        #expect(nudgeShortcutSource.contains("nudgeShortcutButton(.downArrow, delta: CGSize(width: 0, height: 5), modifiers: [.option])"))
        #expect(nudgeShortcutSource.contains("nudgeShortcutButton(.leftArrow, delta: CGSize(width: -10, height: 0), modifiers: [.shift])"))
        #expect(nudgeShortcutSource.contains("viewModel.nudgeSelectionOrSelectedLayer(by: delta)"))

        let transformSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorTransform.swift"),
            encoding: .utf8
        )
        #expect(transformSource.contains("if selectedTool == .pen || selectedTool == .directSelection"))
        #expect(transformSource.contains("nudgeSelectedPathAnchor(by: delta)"))

        #expect(source.contains("viewModel.canDeleteSelectedPathAnchor"))
        #expect(source.contains("viewModel.selectedTool == .pen || viewModel.selectedTool == .directSelection"))
        #expect(source.contains("viewModel.deleteSelectedPathAnchor()"))

        #expect(!source.contains("private var selectionEditShortcutButtons: some View"))
        #expect(!source.contains(".background(selectionEditShortcutButtons)"))
    }

    @MainActor
    @Test func classicToolShortcutsSelectPrimaryToolAndCycleGroupedTools() {
        let image = NSImage(size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.selectClassicToolShortcut("g")
        #expect(viewModel.selectedTool == .paintBucket)

        viewModel.cycleClassicToolShortcut("g")
        #expect(viewModel.selectedTool == .gradient)

        viewModel.cycleClassicToolShortcut("g")
        #expect(viewModel.selectedTool == .paintBucket)

        viewModel.selectClassicToolShortcut("o")
        #expect(viewModel.selectedTool == .dodge)

        viewModel.cycleClassicToolShortcut("o")
        #expect(viewModel.selectedTool == .burn)

        viewModel.selectClassicToolShortcut("r")
        #expect(viewModel.selectedTool == .blur)

        viewModel.cycleClassicToolShortcut("r")
        #expect(viewModel.selectedTool == .sharpen)

        viewModel.cycleClassicToolShortcut("r")
        #expect(viewModel.selectedTool == .smudge)

        viewModel.selectTool(.brush)
        viewModel.cycleClassicToolShortcut("u")
        #expect(viewModel.selectedTool == .rectangle)

        viewModel.selectClassicToolShortcut("a")
        #expect(viewModel.selectedTool == .pathSelection)
        viewModel.cycleClassicToolShortcut("a")
        #expect(viewModel.selectedTool == .directSelection)
    }

    @Test func xomoApplicationOpensEditorWorkspaceWithoutMenuBarOrScreenshotStartup() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/veilpicApp.swift"),
            encoding: .utf8
        )
        #expect(source.contains("WindowGroup"))
        #expect(source.contains("XomoEditorWorkspaceView()"))
        #expect(!source.contains("MenuBarExtra"))
        #expect(!source.contains("GlobalScreenshotShortcutManager"))
        #expect(!source.contains("StorageSettingsView"))
    }

    @Test func xomoSourceTreeDoesNotRetainTrayCaptureOrUploadModules() {
        let sourceDirectory = Self.repositoryRoot().appendingPathComponent("veilpic")
        let retiredModules = [
            "MenuBarUploadViewModel.swift",
            "ScreenshotShortcuts.swift",
            "ScreenshotCaptureCoordinator.swift",
            "RegionScreenshotCapture.swift",
            "ObjectStorageUploader.swift",
            "StorageProfileStore.swift",
            "UploadHistoryStore.swift"
        ]

        for module in retiredModules {
            #expect(!FileManager.default.fileExists(atPath: sourceDirectory.appendingPathComponent(module).path))
        }
    }

    @MainActor
    @Test func imageEditorCanStartFromPreparedDocumentForDevelopmentSamples() throws {
        let sourceName = "development.png"
        let image = NSImage.transparent(size: NSSize(width: 80, height: 60))
        var document = ImageEditorDocument(sourceName: sourceName, image: image)
        let selectedLayerID = try #require(document.selectedLayerID)
        let selectedLayerIndex = try #require(document.selectedLayerIndex)
        document.layers[selectedLayerIndex].name = "Prepared sample"

        let viewModel = ImageEditorViewModel(document: document) { _ in }

        #expect(viewModel.document.sourceName == sourceName)
        #expect(viewModel.document.selectedLayerID == selectedLayerID)
        #expect(viewModel.selectedLayerName == "Prepared sample")
    }

    @MainActor
    @Test func classicAdjustmentShortcutsPreparePropertiesPanel() {
        let image = NSImage(size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.isPropertiesPanelVisible = false
        viewModel.selectAdjustment(.levels)

        #expect(viewModel.selectedAdjustment == .levels)
        #expect(viewModel.isPropertiesPanelVisible)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.adjustmentReady", ImageEditorAdjustment.levels.title))

        viewModel.selectAdjustment(.hueSaturation)
        #expect(viewModel.selectedAdjustment == .hueSaturation)
    }

    @MainActor
    @Test func canvasMagnifyGestureZoomsAndClampsWithinBounds() {
        let image = NSImage(size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        let viewport = CGSize(width: 800, height: 600)
        let center = CGPoint(x: 400, y: 300)
        viewModel.zoom = 1
        viewModel.canvasOffset = .zero

        // Zoom anchored at the viewport center leaves the pan offset unchanged.
        viewModel.magnifyCanvas(2, at: center, viewportSize: viewport)
        #expect(abs(viewModel.zoom - 2) < 0.0001)
        #expect(abs(viewModel.canvasOffset.width) < 0.0001)
        #expect(abs(viewModel.canvasOffset.height) < 0.0001)

        // Subsequent updates in the same gesture stay anchored to the gesture-start state.
        viewModel.magnifyCanvas(3, at: center, viewportSize: viewport)
        #expect(abs(viewModel.zoom - 3) < 0.0001)

        // Clamped to the shared upper bound.
        viewModel.magnifyCanvas(100, at: center, viewportSize: viewport)
        #expect(abs(viewModel.zoom - 8) < 0.0001)
        viewModel.endCanvasMagnify()

        // A new gesture re-anchors to the current zoom, and clamps to the lower bound.
        viewModel.magnifyCanvas(0.0001, at: center, viewportSize: viewport)
        #expect(abs(viewModel.zoom - 0.08) < 0.0001)
        viewModel.endCanvasMagnify()

        // Zooming anchored off-center shifts the pan offset so the anchor point stays put.
        viewModel.zoom = 1
        viewModel.canvasOffset = .zero
        viewModel.magnifyCanvas(2, at: CGPoint(x: 600, y: 300), viewportSize: viewport)
        #expect(abs(viewModel.zoom - 2) < 0.0001)
        // deltaOffset.x = (1 - 2) * (600 - 400) = -200
        #expect(abs(viewModel.canvasOffset.width + 200) < 0.0001)
        #expect(abs(viewModel.canvasOffset.height) < 0.0001)
        viewModel.endCanvasMagnify()
    }

    @Test func canvasWorkspaceWiresMagnifyGestureToViewModel() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        #expect(source.contains("MagnifyGesture()"))
        #expect(source.contains("viewModel.magnifyCanvas("))
        #expect(source.contains("at: value.startLocation"))
        #expect(source.contains("viewportSize: geometry.size"))
        #expect(source.contains("viewModel.endCanvasMagnify()"))
    }

    @Test func canvasPublishesItsAutomationIdentifierAsAnAccessibilityContainer() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let identifier = try #require(
            source.range(of: ".accessibilityIdentifier(\"image-editor-canvas\")")
        )
        let prefix = source[..<identifier.lowerBound].suffix(240)

        #expect(prefix.contains(".accessibilityElement(children: .contain)"))
    }

    @Test func workspaceDoesNotOverrideChildAutomationIdentifiers() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/XomoEditorWorkspaceView.swift"),
            encoding: .utf8
        )

        #expect(!source.contains(".accessibilityIdentifier(\"xomo-editor-workspace\")"))
    }

    @MainActor
    @Test func canvasScrollWheelZoomComposesDiscreteTicksAnchoredAtCursor() {
        // 鼠标滚轮的离散语义：每个 tick 调 magnifyCanvas 后立即 endCanvasMagnify，
        // 让下一次 tick 基于当前状态叠加，而不是沿用上一次的手势基准。
        let image = NSImage(size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let viewport = CGSize(width: 800, height: 600)
        // 偏离视口中心，且 y 偏上，用于检测坐标系是否被上下翻转。
        let anchor = CGPoint(x: 600, y: 200)
        viewModel.zoom = 1
        viewModel.canvasOffset = .zero

        func contentCenter() -> CGPoint {
            CGPoint(
                x: viewport.width / 2 + viewModel.canvasOffset.width,
                y: viewport.height / 2 + viewModel.canvasOffset.height
            )
        }

        // 第一个 tick：放大 1.5，锚点内容保持不动（x、y 不变量同时成立即证明不翻转）。
        let centerBefore1 = contentCenter()
        viewModel.magnifyCanvas(1.5, at: anchor, viewportSize: viewport)
        viewModel.endCanvasMagnify()
        #expect(abs(viewModel.zoom - 1.5) < 0.0001)
        let centerAfter1 = contentCenter()
        #expect(abs((anchor.x - centerAfter1.x) - 1.5 * (anchor.x - centerBefore1.x)) < 0.0001)
        #expect(abs((anchor.y - centerAfter1.y) - 1.5 * (anchor.y - centerBefore1.y)) < 0.0001)

        // 第二个 tick：基于当前状态相乘叠加到 3，而非沿用上一次基准。
        let centerBefore2 = contentCenter()
        viewModel.magnifyCanvas(2, at: anchor, viewportSize: viewport)
        viewModel.endCanvasMagnify()
        #expect(abs(viewModel.zoom - 3) < 0.0001)
        let centerAfter2 = contentCenter()
        #expect(abs((anchor.x - centerAfter2.x) - 2 * (anchor.x - centerBefore2.x)) < 0.0001)
        #expect(abs((anchor.y - centerAfter2.y) - 2 * (anchor.y - centerBefore2.y)) < 0.0001)
    }

    @Test func canvasWorkspaceWiresScrollWheelZoomToViewModel() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        #expect(source.contains("ScrollWheelZoomView"))
        #expect(source.contains("onMiddleMousePanBegan"))
        #expect(source.contains("onMiddleMousePanChanged"))
        #expect(source.contains("onMiddleMousePanEnded"))
        #expect(source.contains("onMouseMoved"))
        #expect(source.contains("updateCanvasCursor(at: location, in: geometry.size)"))
        #expect(source.contains("viewModel.magnifyCanvas(factor, at: location, viewportSize: viewportSize)"))
        #expect(source.contains("viewModel.endCanvasMagnify()"))
    }

    @MainActor
    @Test func middleMousePanUsesFlippedCanvasDeltaWithoutTouchingHistory() {
        let previous = CGPoint(x: 120, y: 80)
        let current = CGPoint(x: 155, y: 104)
        #expect(
            ImageEditorCanvasMiddleMousePanGeometry.delta(from: previous, to: current)
                == CGSize(width: 35, height: 24)
        )

        let viewModel = ImageEditorViewModel(
            sourceName: "middle-pan.png",
            image: NSImage(size: NSSize(width: 80, height: 60))
        ) { _ in }
        let historyCount = viewModel.document.history.count
        viewModel.nudgeCanvas(by: ImageEditorCanvasMiddleMousePanGeometry.delta(from: previous, to: current))
        #expect(viewModel.canvasOffset == CGSize(width: 35, height: 24))
        #expect(viewModel.document.history.count == historyCount)
    }

    @MainActor
    @Test func navigatorRecentersCanvasWithoutAddingHistory() {
        let image = NSImage(size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        viewModel.canvasViewportSize = CGSize(width: 800, height: 600)
        viewModel.zoom = 3
        viewModel.canvasOffset = CGSize(width: 40, height: -24)
        let historyCount = viewModel.document.history.count

        viewModel.centerCanvas(on: CGPoint(x: 70, y: 50))

        #expect(viewModel.document.history.count == historyCount)
        let baseScale = min(800 / 80, 600 / 60) * 0.74
        let scale = baseScale * viewModel.zoom
        let origin = CGPoint(
            x: (800 - 80 * scale) / 2 + viewModel.canvasOffset.width,
            y: (600 - 60 * scale) / 2 + viewModel.canvasOffset.height
        )
        #expect(abs(origin.x + 70 * scale - 400) < 0.001)
        #expect(abs(origin.y + 50 * scale - 300) < 0.001)
    }

    @Test func navigatorPreviewWiresViewportOverlayAndPanGesture() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        #expect(source.contains("private var navigatorPreview: some View"))
        #expect(source.contains("navigatorViewportRect"))
        #expect(source.contains("imageEditor.navigator.preview"))
        #expect(source.contains("DragGesture(minimumDistance: 0)"))
        #expect(source.contains("viewModel.centerCanvas(on: imagePoint)"))
    }

    @MainActor
    @Test func layerStyleColorSettersUpdateEveryEditableEffectColor() {
        let image = NSImage(size: NSSize(width: 40, height: 30))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.setSelectedLayerStrokeColor(NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        let stroke = viewModel.selectedLayerStrokeColor.usingColorSpace(.sRGB)
        #expect((stroke?.redComponent ?? 0) > 0.9)
        #expect((stroke?.greenComponent ?? 1) < 0.1)
        #expect((stroke?.blueComponent ?? 1) < 0.1)

        viewModel.setSelectedLayerShadowColor(NSColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))
        let shadow = viewModel.selectedLayerShadowColor.usingColorSpace(.sRGB)
        #expect((shadow?.blueComponent ?? 0) > 0.9)
        #expect((shadow?.redComponent ?? 1) < 0.1)

        viewModel.setSelectedLayerOuterGlowColor(NSColor(srgbRed: 0, green: 1, blue: 0, alpha: 1))
        let outerGlow = viewModel.selectedLayerOuterGlowColor.usingColorSpace(.sRGB)
        #expect((outerGlow?.greenComponent ?? 0) > 0.9)
        #expect((outerGlow?.redComponent ?? 1) < 0.1)

        viewModel.setSelectedLayerInnerGlowColor(NSColor(srgbRed: 1, green: 0, blue: 1, alpha: 1))
        let innerGlow = viewModel.selectedLayerInnerGlowColor.usingColorSpace(.sRGB)
        #expect((innerGlow?.redComponent ?? 0) > 0.9)
        #expect((innerGlow?.blueComponent ?? 0) > 0.9)
        #expect((innerGlow?.greenComponent ?? 1) < 0.1)

        viewModel.setSelectedLayerColorOverlayColor(NSColor(srgbRed: 1, green: 1, blue: 0, alpha: 1))
        let overlay = viewModel.selectedLayerColorOverlayColor.usingColorSpace(.sRGB)
        #expect((overlay?.redComponent ?? 0) > 0.9)
        #expect((overlay?.greenComponent ?? 0) > 0.9)
        #expect((overlay?.blueComponent ?? 1) < 0.1)

        viewModel.setSelectedLayerSatinColor(NSColor(srgbRed: 0, green: 1, blue: 1, alpha: 1))
        let satin = viewModel.selectedLayerSatinColor.usingColorSpace(.sRGB)
        #expect((satin?.greenComponent ?? 0) > 0.9)
        #expect((satin?.blueComponent ?? 0) > 0.9)
        #expect((satin?.redComponent ?? 1) < 0.1)

        viewModel.setSelectedLayerGradientOverlayStartColor(NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        viewModel.setSelectedLayerGradientOverlayEndColor(NSColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))
        let gradientStart = viewModel.selectedLayerGradientOverlayStartColor.usingColorSpace(.sRGB)
        let gradientEnd = viewModel.selectedLayerGradientOverlayEndColor.usingColorSpace(.sRGB)
        #expect((gradientStart?.redComponent ?? 0) > 0.9)
        #expect((gradientStart?.blueComponent ?? 1) < 0.1)
        #expect((gradientEnd?.blueComponent ?? 0) > 0.9)
        #expect((gradientEnd?.redComponent ?? 1) < 0.1)

        viewModel.setSelectedLayerBevelHighlightColor(NSColor(srgbRed: 1, green: 0, blue: 1, alpha: 1))
        viewModel.setSelectedLayerBevelShadowColor(NSColor(srgbRed: 0, green: 1, blue: 0, alpha: 1))
        let bevelHighlight = viewModel.selectedLayerBevelHighlightColor.usingColorSpace(.sRGB)
        let bevelShadow = viewModel.selectedLayerBevelShadowColor.usingColorSpace(.sRGB)
        #expect((bevelHighlight?.redComponent ?? 0) > 0.9)
        #expect((bevelHighlight?.blueComponent ?? 0) > 0.9)
        #expect((bevelHighlight?.greenComponent ?? 1) < 0.1)
        #expect((bevelShadow?.greenComponent ?? 0) > 0.9)
        #expect((bevelShadow?.redComponent ?? 1) < 0.1)
    }

    @Test func layerStylePanelUsesColorPickersForEveryEditableEffectColor() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        #expect(source.contains("ColorPicker(\"\", selection: selectedLayerStrokeColorBinding, supportsOpacity: false)"))
        #expect(source.contains("ColorPicker(\"\", selection: selectedLayerShadowColorBinding, supportsOpacity: false)"))
        #expect(source.contains("ColorPicker(\"\", selection: selectedLayerOuterGlowColorBinding, supportsOpacity: false)"))
        #expect(source.contains("ColorPicker(\"\", selection: selectedLayerInnerGlowColorBinding, supportsOpacity: false)"))
        #expect(source.contains("ColorPicker(\"\", selection: selectedLayerColorOverlayColorBinding, supportsOpacity: false)"))
        #expect(source.contains("ColorPicker(\"\", selection: selectedLayerSatinColorBinding, supportsOpacity: false)"))
        #expect(source.contains("ColorPicker(\"\", selection: selectedLayerGradientOverlayStartColorBinding, supportsOpacity: false)"))
        #expect(source.contains("ColorPicker(\"\", selection: selectedLayerGradientOverlayEndColorBinding, supportsOpacity: false)"))
        #expect(source.contains("ColorPicker(\"\", selection: selectedLayerBevelHighlightColorBinding, supportsOpacity: false)"))
        #expect(source.contains("ColorPicker(\"\", selection: selectedLayerBevelShadowColorBinding, supportsOpacity: false)"))
        #expect(source.contains("viewModel.setSelectedLayerStrokeColor(NSColor(value))"))
        #expect(source.contains("viewModel.setSelectedLayerShadowColor(NSColor(value))"))
        #expect(source.contains("viewModel.setSelectedLayerOuterGlowColor(NSColor(value))"))
        #expect(source.contains("viewModel.setSelectedLayerInnerGlowColor(NSColor(value))"))
        #expect(source.contains("viewModel.setSelectedLayerColorOverlayColor(NSColor(value))"))
        #expect(source.contains("viewModel.setSelectedLayerSatinColor(NSColor(value))"))
        #expect(source.contains("viewModel.setSelectedLayerGradientOverlayStartColor(NSColor(value))"))
        #expect(source.contains("viewModel.setSelectedLayerGradientOverlayEndColor(NSColor(value))"))
        #expect(source.contains("viewModel.setSelectedLayerBevelHighlightColor(NSColor(value))"))
        #expect(source.contains("viewModel.setSelectedLayerBevelShadowColor(NSColor(value))"))
    }

    @MainActor
    @Test func classicFilterMenuSelectionsPreparePropertiesPanel() {
        let image = NSImage(size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.isPropertiesPanelVisible = false
        viewModel.selectFilter(.unsharpMask)

        #expect(viewModel.selectedFilter == .unsharpMask)
        #expect(viewModel.isPropertiesPanelVisible)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.filterReady", ImageEditorFilter.unsharpMask.title))

        viewModel.selectFilter(.gaussianBlur)
        #expect(viewModel.selectedFilter == .gaussianBlur)
    }

    @MainActor
    @Test func classicBrushSizeShortcutsClampAndUpdateOptionsStatus() {
        let image = NSImage(size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.brushSize = 18
        viewModel.adjustBrushSizeShortcut(by: 1)
        #expect(viewModel.brushSize == 19)
        #expect(viewModel.statusText == viewModel.optionsPanelSummaryText)

        viewModel.adjustBrushSizeShortcut(by: -2)
        #expect(viewModel.brushSize == 17)

        viewModel.brushSize = 1
        viewModel.adjustBrushSizeShortcut(by: -1)
        #expect(viewModel.brushSize == 1)

        viewModel.brushSize = 96
        viewModel.adjustBrushSizeShortcut(by: 1)
        #expect(viewModel.brushSize == 96)
    }

    @MainActor
    @Test func classicBrushHardnessShortcutsClampAndUpdateOptionsStatus() {
        let image = NSImage(size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.hardness = 0.5
        viewModel.adjustBrushHardnessShortcut(by: 0.25)
        #expect(viewModel.hardness == 0.75)
        #expect(viewModel.statusText == viewModel.optionsPanelSummaryText)

        viewModel.adjustBrushHardnessShortcut(by: -0.5)
        #expect(viewModel.hardness == 0.25)

        viewModel.hardness = 0
        viewModel.adjustBrushHardnessShortcut(by: -0.25)
        #expect(viewModel.hardness == 0)

        viewModel.hardness = 1
        viewModel.adjustBrushHardnessShortcut(by: 0.25)
        #expect(viewModel.hardness == 1)
    }

    @MainActor
    @Test func classicOpacityDigitShortcutsApplyPhotoshopStylePresets() {
        let image = NSImage(size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.applyOpacityShortcutDigit(1)
        #expect(viewModel.opacity == 0.1)
        #expect(viewModel.statusText == viewModel.optionsPanelSummaryText)

        viewModel.applyOpacityShortcutDigit(5)
        #expect(viewModel.opacity == 0.5)

        viewModel.applyOpacityShortcutDigit(9)
        #expect(viewModel.opacity == 0.9)

        viewModel.applyOpacityShortcutDigit(0)
        #expect(viewModel.opacity == 1)
    }

    @MainActor
    @Test func classicForegroundBackgroundShortcutsReuseExistingColorActions() {
        let image = NSImage(size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.foregroundColor = .systemRed
        viewModel.backgroundColor = .systemBlue
        viewModel.resetForegroundBackgroundColors()
        #expect(viewModel.foregroundColor == .black)
        #expect(viewModel.backgroundColor == .white)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.colorDefaultForegroundBackground"))

        viewModel.swapForegroundBackgroundColors()
        #expect(viewModel.foregroundColor == .white)
        #expect(viewModel.backgroundColor == .black)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.colorSwapForegroundBackground"))
    }

    @MainActor
    @Test func creatingReplacementSelectionPreservesRenderedPreviewCache() {
        let image = NSImage(size: NSSize(width: 320, height: 200))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let previewBeforeSelection = viewModel.previewImage

        viewModel.selectionMode = .replace
        viewModel.createRectSelection(
            from: CGPoint(x: 20, y: 30),
            to: CGPoint(x: 180, y: 140)
        )

        #expect(viewModel.document.selection?.bounds == CGRect(x: 20, y: 30, width: 160, height: 110))
        #expect(viewModel.canSaveSelectionAsAlphaChannel)
        #expect(viewModel.previewImage === previewBeforeSelection)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionCreated"))
    }

    @Test func transparentCanvasUsesLightGrayAndWhiteCheckerboard() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let checkerboardStart = try #require(source.range(of: "private var checkerboard: some View"))
        let checkerboardEnd = try #require(
            source[checkerboardStart.upperBound...].range(of: "private func dragOverlay")
        )
        let checkerboardSource = source[checkerboardStart.lowerBound..<checkerboardEnd.lowerBound]

        #expect(checkerboardSource.contains("let square: CGFloat = 12"))
        #expect(checkerboardSource.contains("calibratedWhite: 0.94"))
        #expect(checkerboardSource.contains("calibratedWhite: 0.72"))
        #expect(checkerboardSource.contains("(row + col).isMultiple(of: 2) ? light : dark"))
    }

    @MainActor
    @Test func screenColorSamplerResultsUpdateTheirRequestedColorTarget() {
        let image = NSImage(size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        let foreground = NSColor(calibratedRed: 0.18, green: 0.42, blue: 0.76, alpha: 1)
        viewModel.applyScreenSampledForegroundColor(foreground)
        #expect(Self.deviceRGBComponents(viewModel.foregroundColor) == Self.deviceRGBComponents(foreground))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.colorScreenSampledForeground"))

        let background = NSColor(calibratedRed: 0.86, green: 0.34, blue: 0.12, alpha: 1)
        viewModel.applyScreenSampledBackgroundColor(background)
        #expect(Self.deviceRGBComponents(viewModel.backgroundColor) == Self.deviceRGBComponents(background))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.colorScreenSampledBackground"))
    }

    @Test func compactToolRailExposesPreviewAndScreenColorControls() throws {
        let viewSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let menuSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )

        #expect(viewSource.contains("GridItem(.fixed(30), spacing: 2)"))
        #expect(viewSource.contains(".frame(width: 80)"))
        #expect(viewSource.contains("viewModel.sampleScreenColorForForeground"))
        #expect(viewSource.contains("viewModel.sampleScreenColorForBackground"))
        #expect(viewSource.contains("image-editor-color-swap"))
        #expect(viewSource.contains(".onHover { isHovered = $0 }"))
        #expect(viewSource.contains(".focusable(false)"))
        #expect(menuSource.contains("Button(L10n.text(\"imageEditor.action.preview\"))"))
        #expect(menuSource.contains(".accessibilityLabel(L10n.text(\"imageEditor.action.apply\"))"))
    }

    @MainActor
    @Test func classicArrowNudgeShortcutsMoveSelectionBeforeLayer() {
        let image = NSImage(size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.document.selection = .rectangle(CGRect(x: 10, y: 12, width: 20, height: 18))
        viewModel.nudgeSelectionOrSelectedLayer(by: CGSize(width: 1, height: 0))
        #expect(viewModel.document.selection?.bounds == CGRect(x: 11, y: 12, width: 20, height: 18))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionMove"))

        viewModel.nudgeSelectionOrSelectedLayer(by: CGSize(width: 0, height: 10))
        #expect(viewModel.document.selection?.bounds == CGRect(x: 11, y: 22, width: 20, height: 18))
    }

    @MainActor
    @Test func classicArrowNudgeShortcutsMoveSelectedLayerWithoutSelection() {
        let image = NSImage(size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        viewModel.addLayer()

        let selectedLayerID = viewModel.document.selectedLayerID
        let originalFrame = try? #require(viewModel.document.layers.first { $0.id == selectedLayerID }?.frame)

        viewModel.nudgeSelectionOrSelectedLayer(by: CGSize(width: -10, height: 0))
        let movedFrame = viewModel.document.layers.first { $0.id == selectedLayerID }?.frame

        #expect(movedFrame?.origin.x == (originalFrame?.origin.x ?? 0) - 10)
        #expect(movedFrame?.origin.y == originalFrame?.origin.y)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerTranslate"))
    }

    @MainActor
    @Test func classicDeleteShortcutClearsSelectionPixelsThroughExistingCommand() throws {
        let image = try #require(NSImage.rendered(size: NSSize(width: 80, height: 60)) { rect in
            NSColor.systemRed.setFill()
            rect.fill()
        })
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        viewModel.convertBackgroundToLayer()
        viewModel.document.selection = ImageEditorSelection.rectangle(CGRect(x: 10, y: 10, width: 20, height: 20))

        viewModel.clearSelectionPixels()

        let clearedColor = viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 15, y: 15))
        let retainedColor = viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 2, y: 2))
        #expect((clearedColor?.alphaComponent ?? 1) < 0.05)
        #expect((retainedColor?.alphaComponent ?? 0) > 0.95)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionClearPixelsSelected"))
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
    @Test func persistentZoomControlClampsAndReportsDirectZoomChanges() {
        let image = NSImage(size: NSSize(width: 100, height: 50))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.setZoom(2.5)
        #expect(viewModel.zoom == 2.5)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.zoom", "250%"))

        viewModel.setZoom(20)
        #expect(viewModel.zoom == 8)

        viewModel.setZoom(0.001)
        #expect(viewModel.zoom == 0.08)
    }

    @MainActor
    @Test func everyZoomEntryPointRestoresTheLeftToolRail() {
        let image = NSImage(size: NSSize(width: 100, height: 50))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        viewModel.updateCanvasViewportSize(CGSize(width: 600, height: 400))

        viewModel.areToolsPanelVisible = false
        viewModel.setZoom(2)
        #expect(viewModel.areToolsPanelVisible)

        viewModel.areToolsPanelVisible = false
        viewModel.magnifyCanvas(1.2, at: CGPoint(x: 300, y: 200), viewportSize: CGSize(width: 600, height: 400))
        viewModel.endCanvasMagnify()
        #expect(viewModel.areToolsPanelVisible)

        viewModel.areToolsPanelVisible = false
        viewModel.fitZoom()
        #expect(viewModel.areToolsPanelVisible)

        viewModel.areToolsPanelVisible = false
        viewModel.zoomActualPixels()
        #expect(viewModel.areToolsPanelVisible)
    }

    @Test func editorSidebarsStayFixedWhileCanvasOwnsFlexibleWidth() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("toolRail\n                        .fixedSize(horizontal: true, vertical: false)"))
        #expect(source.contains("canvasWorkspace\n                    .frame(minWidth: 0)"))
        #expect(source.contains("rightDock\n                        .fixedSize(horizontal: true, vertical: false)"))

        let dockStart = try #require(source.range(of: "private var rightDock: some View"))
        let dockEnd = try #require(source[dockStart.upperBound...].range(of: "private func navigatorPanel"))
        let dockSource = source[dockStart.lowerBound..<dockEnd.lowerBound]
        #expect(dockSource.contains("VStack(spacing: 8)"))
        #expect(!dockSource.contains("LazyVStack"))
        #expect(dockSource.contains(".frame(width: 348)"))
        #expect(dockSource.contains(".clipped()"))

        let filterStart = try #require(source.range(of: "private var filtersQuickPanel: some View"))
        let filterEnd = try #require(source[filterStart.upperBound...].range(of: "private func historySnapshotRow"))
        let filterSource = source[filterStart.lowerBound..<filterEnd.lowerBound]
        #expect(filterSource.contains("Text(L10n.text(\"imageEditor.action.applyFilter\"))"))
        #expect(filterSource.contains(".lineLimit(1)"))
        #expect(filterSource.contains("VStack(spacing: 8)"))
        #expect(filterSource.contains("HStack(spacing: 8)"))
    }

    @Test func documentTabExposesPersistentZoomControls() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let tabStart = try #require(source.range(of: "private var documentTab: some View"))
        let tabEnd = try #require(
            source[tabStart.upperBound...].range(of: "private var checkerboard: some View")
        )
        let tabSource = source[tabStart.lowerBound..<tabEnd.lowerBound]

        #expect(tabSource.contains("image-editor-zoom-out"))
        #expect(tabSource.contains("image-editor-zoom-slider"))
        #expect(tabSource.contains("image-editor-zoom-in"))
        #expect(tabSource.contains("image-editor-zoom-fit"))
        #expect(tabSource.contains("private var zoomSliderBinding: Binding<Double>"))
        #expect(tabSource.contains("ImageEditorViewModel.maximumZoom / ImageEditorViewModel.minimumZoom"))
    }

    @Test func alternateZoomShortcutsSupportOptionPlusAndMinus() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let shortcutStart = try #require(source.range(of: "private var alternateZoomShortcutButtons: some View"))
        let shortcutEnd = try #require(
            source[shortcutStart.upperBound...].range(of: "private var nudgeShortcutButtons: some View")
        )
        let shortcutSource = source[shortcutStart.lowerBound..<shortcutEnd.lowerBound]

        #expect(source.contains(".background(alternateZoomShortcutButtons)"))
        #expect(shortcutSource.contains("viewModel.zoomOut()"))
        #expect(shortcutSource.contains(".keyboardShortcut(\"-\", modifiers: [.option])"))
        #expect(shortcutSource.contains("viewModel.zoomIn()"))
        #expect(shortcutSource.contains(".keyboardShortcut(\"+\", modifiers: [.option])"))
        #expect(shortcutSource.contains(".keyboardShortcut(\"=\", modifiers: [.option])"))
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

    @Test func fileMenuExposesClassicProjectAndExportShortcuts() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let fileMenuStart = try #require(source.range(of: "private var fileMenu: some View"))
        let nextMenuStart = try #require(
            source[fileMenuStart.upperBound...].range(of: "private var editMenu: some View")
        )
        let fileMenuSource = source[fileMenuStart.lowerBound..<nextMenuStart.lowerBound]

        #expect(fileMenuSource.contains("viewModel.openProjectDocument()"))
        #expect(fileMenuSource.contains(".keyboardShortcut(\"o\", modifiers: [.command])"))
        #expect(fileMenuSource.contains("viewModel.saveProjectDocument()"))
        #expect(fileMenuSource.contains(".keyboardShortcut(\"s\", modifiers: [.command])"))
        #expect(fileMenuSource.contains("viewModel.openExportPanel()"))
        #expect(fileMenuSource.contains(".keyboardShortcut(\"s\", modifiers: [.command, .shift, .option])"))
        #expect(fileMenuSource.contains("imageEditor.action.fileImport"))
        #expect(fileMenuSource.contains("viewModel.chooseImageLayerFile()"))
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
        #expect(layerMenuSource.contains(".keyboardShortcut(\"j\", modifiers: [.command, .shift])"))
        #expect(layerMenuSource.contains("viewModel.canCutSelectionToNewLayer"))
    }

    @Test func layerMenuExposesClassicLayerShortcuts() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let layerMenuStart = try #require(source.range(of: "private var layerMenu: some View"))
        let nextMenuStart = try #require(
            source[layerMenuStart.upperBound...].range(of: "private var layerSelectAttributeMenu: some View")
        )
        let layerMenuSource = source[layerMenuStart.lowerBound..<nextMenuStart.lowerBound]

        #expect(layerMenuSource.contains("viewModel.addLayer()"))
        #expect(layerMenuSource.contains(".keyboardShortcut(\"n\", modifiers: [.command, .shift])"))
        #expect(layerMenuSource.contains("viewModel.duplicateSelectionOrSelectedLayer()"))
        #expect(layerMenuSource.contains(".keyboardShortcut(\"j\", modifiers: [.command])"))
        #expect(layerMenuSource.contains("viewModel.canDuplicateSelectionOrSelectedLayer"))
        #expect(layerMenuSource.contains("viewModel.groupSelectedLayer()"))
        #expect(layerMenuSource.contains(".keyboardShortcut(\"g\", modifiers: [.command])"))
        #expect(layerMenuSource.contains("viewModel.ungroupSelectedLayers()"))
        #expect(layerMenuSource.contains(".keyboardShortcut(\"g\", modifiers: [.command, .shift])"))
        #expect(layerMenuSource.contains("viewModel.mergeSelectedLayerDown()"))
        #expect(layerMenuSource.contains(".keyboardShortcut(\"e\", modifiers: [.command])"))
        #expect(layerMenuSource.contains("viewModel.mergeVisibleLayers()"))
        #expect(layerMenuSource.contains(".keyboardShortcut(\"e\", modifiers: [.command, .shift])"))
        #expect(layerMenuSource.contains("viewModel.stampVisibleLayers()"))
        #expect(layerMenuSource.contains(".keyboardShortcut(\"e\", modifiers: [.command, .shift, .option])"))
    }

    @Test func layerOrderMenuExposesClassicLayerOrderShortcuts() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let orderMenuStart = try #require(source.range(of: "private var layerOrderMenu: some View"))
        let nextMenuStart = try #require(
            source[orderMenuStart.upperBound...].range(of: "private var layerTransformMenu: some View")
        )
        let orderMenuSource = source[orderMenuStart.lowerBound..<nextMenuStart.lowerBound]

        #expect(orderMenuSource.contains("viewModel.moveSelectedLayerToTop(inVisibleOrder: filteredVisibleLayerRowIDs)"))
        #expect(orderMenuSource.contains(".keyboardShortcut(\"]\", modifiers: [.command, .shift])"))
        #expect(orderMenuSource.contains("viewModel.moveSelectedLayerUp(inVisibleOrder: filteredVisibleLayerRowIDs)"))
        #expect(orderMenuSource.contains(".keyboardShortcut(\"]\", modifiers: [.command])"))
        #expect(orderMenuSource.contains("viewModel.moveSelectedLayerDown(inVisibleOrder: filteredVisibleLayerRowIDs)"))
        #expect(orderMenuSource.contains(".keyboardShortcut(\"[\", modifiers: [.command])"))
        #expect(orderMenuSource.contains("viewModel.moveSelectedLayerToBottom(inVisibleOrder: filteredVisibleLayerRowIDs)"))
        #expect(orderMenuSource.contains(".keyboardShortcut(\"[\", modifiers: [.command, .shift])"))
    }

    @Test func imageMenuExposesClassicSizeShortcuts() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let imageMenuStart = try #require(source.range(of: "private var imageMenu: some View"))
        let nextMenuStart = try #require(
            source[imageMenuStart.upperBound...].range(of: "private var layerMenu: some View")
        )
        let imageMenuSource = source[imageMenuStart.lowerBound..<nextMenuStart.lowerBound]

        #expect(imageMenuSource.contains("viewModel.resizeImageToControlSize()"))
        #expect(imageMenuSource.contains(".keyboardShortcut(\"i\", modifiers: [.command, .option])"))
        #expect(imageMenuSource.contains("viewModel.resizeCanvasToControlSize()"))
        #expect(imageMenuSource.contains(".keyboardShortcut(\"c\", modifiers: [.command, .option])"))
        #expect(imageMenuSource.contains("viewModel.selectAdjustment(.levels)"))
        #expect(imageMenuSource.contains(".keyboardShortcut(\"l\", modifiers: [.command])"))
        #expect(imageMenuSource.contains("viewModel.selectAdjustment(.curves)"))
        #expect(imageMenuSource.contains(".keyboardShortcut(\"m\", modifiers: [.command])"))
        #expect(imageMenuSource.contains("viewModel.selectAdjustment(.colorBalance)"))
        #expect(imageMenuSource.contains(".keyboardShortcut(\"b\", modifiers: [.command])"))
        #expect(imageMenuSource.contains("viewModel.selectAdjustment(.hueSaturation)"))
        #expect(imageMenuSource.contains(".keyboardShortcut(\"u\", modifiers: [.command])"))
        #expect(imageMenuSource.contains("viewModel.desaturateSelectedLayer()"))
        #expect(imageMenuSource.contains(".keyboardShortcut(\"u\", modifiers: [.command, .shift])"))
        #expect(imageMenuSource.contains("viewModel.canDesaturateSelectedLayer"))
        #expect(imageMenuSource.contains("viewModel.invertSelectedLayer()"))
        #expect(imageMenuSource.contains(".keyboardShortcut(\"i\", modifiers: [.command])"))
        #expect(imageMenuSource.contains("viewModel.canInvertSelectedLayer"))
        #expect(imageMenuSource.contains("viewModel.autoLevelsSelectedLayer()"))
        #expect(imageMenuSource.contains(".keyboardShortcut(\"l\", modifiers: [.command, .shift])"))
        #expect(imageMenuSource.contains("viewModel.autoContrastSelectedLayer()"))
        #expect(imageMenuSource.contains(".keyboardShortcut(\"l\", modifiers: [.command, .shift, .option])"))
        #expect(imageMenuSource.contains("viewModel.autoColorSelectedLayer()"))
        #expect(imageMenuSource.contains(".keyboardShortcut(\"b\", modifiers: [.command, .shift])"))
        #expect(imageMenuSource.contains("imageEditor.menu.image.adjustments"))
        #expect(imageMenuSource.contains("viewModel.selectAdjustment(.brightnessContrast)"))
        #expect(imageMenuSource.contains("viewModel.selectAdjustment(.channelMixer)"))
        #expect(imageMenuSource.contains("viewModel.selectAdjustment(.selectiveColor)"))
        #expect(imageMenuSource.contains("viewModel.selectAdjustment(.gradientMap)"))
        #expect(imageMenuSource.contains("viewModel.selectAdjustment(.posterize)"))
        #expect(imageMenuSource.contains("viewModel.selectAdjustment(.threshold)"))
        #expect(imageMenuSource.contains("viewModel.selectAdjustment(.exposure)"))
        #expect(imageMenuSource.contains("viewModel.selectAdjustment(.vibrance)"))
        #expect(imageMenuSource.contains("viewModel.selectAdjustment(.shadowsHighlights)"))
        #expect(imageMenuSource.contains("viewModel.selectAdjustment(.blackWhite)"))
        #expect(imageMenuSource.contains("viewModel.selectAdjustment(.photoFilter)"))
        #expect(imageMenuSource.contains("viewModel.selectAdjustment(.colorLookup)"))
    }

    @Test func filterMenuExposesClassicLastFilterShortcut() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let filterMenuStart = try #require(source.range(of: "private var filterMenu: some View"))
        let nextMenuStart = try #require(
            source[filterMenuStart.upperBound...].range(of: "private var viewMenu: some View")
        )
        let filterMenuSource = source[filterMenuStart.lowerBound..<nextMenuStart.lowerBound]

        #expect(filterMenuSource.contains("imageEditor.action.lastFilter"))
        #expect(filterMenuSource.contains("viewModel.applyLastFilter()"))
        #expect(filterMenuSource.contains(".keyboardShortcut(\"f\", modifiers: [.command])"))
        #expect(filterMenuSource.contains("viewModel.canApplyLastFilter"))
        #expect(filterMenuSource.contains("imageEditor.menu.filter.blur"))
        #expect(filterMenuSource.contains("viewModel.selectFilter(.gaussianBlur)"))
        #expect(filterMenuSource.contains("viewModel.selectFilter(.motionBlur)"))
        #expect(filterMenuSource.contains("imageEditor.menu.filter.sharpen"))
        #expect(filterMenuSource.contains("viewModel.selectFilter(.sharpen)"))
        #expect(filterMenuSource.contains("viewModel.selectFilter(.unsharpMask)"))
        #expect(filterMenuSource.contains("imageEditor.menu.filter.noise"))
        #expect(filterMenuSource.contains("viewModel.selectFilter(.addNoise)"))
        #expect(filterMenuSource.contains("viewModel.selectFilter(.median)"))
        #expect(filterMenuSource.contains("imageEditor.menu.filter.pixelate"))
        #expect(filterMenuSource.contains("viewModel.selectFilter(.pixelate)"))
        #expect(filterMenuSource.contains("imageEditor.menu.filter.stylize"))
        #expect(filterMenuSource.contains("viewModel.selectFilter(.emboss)"))
        #expect(filterMenuSource.contains("viewModel.selectFilter(.findEdges)"))
        #expect(filterMenuSource.contains("imageEditor.menu.filter.distort"))
        #expect(filterMenuSource.contains("viewModel.selectFilter(.offset)"))
        #expect(filterMenuSource.contains("viewModel.selectFilter(.wave)"))
        #expect(filterMenuSource.contains("viewModel.selectFilter(.ripple)"))
        #expect(filterMenuSource.contains("viewModel.selectFilter(.pinch)"))
        #expect(filterMenuSource.contains("viewModel.selectFilter(.spherize)"))
        #expect(filterMenuSource.contains("viewModel.selectFilter(.vignette)"))
        #expect(filterMenuSource.contains("imageEditor.menu.filter.artistic"))
        #expect(filterMenuSource.contains("viewModel.selectFilter(.oilPaint)"))
        #expect(filterMenuSource.contains("imageEditor.menu.filter.liquify"))
        #expect(filterMenuSource.contains("viewModel.selectFilter(.liquifyPush)"))
        #expect(filterMenuSource.contains("viewModel.selectFilter(.liquifyTwirl)"))
        #expect(filterMenuSource.contains("viewModel.selectFilter(.liquifyPuckerBloat)"))
        #expect(filterMenuSource.contains("imageEditor.menu.filter.other"))
        #expect(filterMenuSource.contains("viewModel.selectFilter(.highPass)"))
    }

    @Test func filterMenuExposesEveryFilterCase() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let filterMenuStart = try #require(source.range(of: "private var filterMenu: some View"))
        let nextMenuStart = try #require(
            source[filterMenuStart.upperBound...].range(of: "private var viewMenu: some View")
        )
        let filterMenuSource = source[filterMenuStart.lowerBound..<nextMenuStart.lowerBound]

        for filter in ImageEditorFilter.allCases {
            #expect(
                filterMenuSource.contains("viewModel.selectFilter(.\(filter.rawValue))"),
                "Filter \(filter.rawValue) is missing a menu entry"
            )
        }
    }

    @Test func editMenuExposesClassicEditingShortcuts() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let editMenuStart = try #require(source.range(of: "private var editMenu: some View"))
        let nextMenuStart = try #require(
            source[editMenuStart.upperBound...].range(of: "private var historySnapshotMenu: some View")
        )
        let editMenuSource = source[editMenuStart.lowerBound..<nextMenuStart.lowerBound]

        #expect(editMenuSource.contains("viewModel.undo()"))
        #expect(editMenuSource.contains(".keyboardShortcut(\"z\", modifiers: [.command])"))
        #expect(editMenuSource.contains("viewModel.redo()"))
        #expect(editMenuSource.contains(".keyboardShortcut(\"z\", modifiers: [.command, .shift])"))
        #expect(editMenuSource.contains("viewModel.copySelectionToClipboard()"))
        #expect(editMenuSource.contains(".keyboardShortcut(\"c\", modifiers: [.command])"))
        #expect(editMenuSource.contains("viewModel.copyMergedToClipboard()"))
        #expect(editMenuSource.contains(".keyboardShortcut(\"c\", modifiers: [.command, .shift])"))
        #expect(editMenuSource.contains("viewModel.copySelectedLayersToClipboard()"))
        #expect(editMenuSource.contains(".keyboardShortcut(\"c\", modifiers: [.command, .option, .shift])"))
        #expect(editMenuSource.contains("viewModel.canCopySelectedLayersToClipboard"))
        #expect(editMenuSource.contains("viewModel.pasteClipboardAsLayer()"))
        #expect(editMenuSource.contains(".keyboardShortcut(\"v\", modifiers: [.command])"))
        #expect(editMenuSource.contains("viewModel.pasteClipboardIntoSelectionAsLayer()"))
        #expect(editMenuSource.contains(".keyboardShortcut(\"v\", modifiers: [.command, .shift])"))
        #expect(editMenuSource.contains("imageEditor.action.freeTransform"))
        #expect(editMenuSource.contains("viewModel.toggleTransformControlsVisible()"))
        #expect(editMenuSource.contains(".keyboardShortcut(\"t\", modifiers: [.command])"))
        #expect(editMenuSource.contains("viewModel.cutSelectionToClipboard()"))
        #expect(editMenuSource.contains(".keyboardShortcut(\"x\", modifiers: [.command])"))
        #expect(editMenuSource.contains("viewModel.canCutSelectionToClipboard"))
        #expect(editMenuSource.contains("viewModel.fillSelection()"))
        #expect(editMenuSource.contains(".keyboardShortcut(.delete, modifiers: [.option])"))
        #expect(editMenuSource.contains("viewModel.fillSelectionWithBackgroundColor()"))
        #expect(editMenuSource.contains(".keyboardShortcut(.delete, modifiers: [.command])"))
        #expect(editMenuSource.contains("viewModel.clearSelectionPixels()"))
        #expect(editMenuSource.contains(".keyboardShortcut(.delete, modifiers: [])"))
    }

    @Test func fileMenuExposesClipboardCanvasCreation() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let fileMenuStart = try #require(source.range(of: "private var fileMenu: some View"))
        let nextMenuStart = try #require(
            source[fileMenuStart.upperBound...].range(of: "private var editMenu: some View")
        )
        let fileMenuSource = source[fileMenuStart.lowerBound..<nextMenuStart.lowerBound]

        #expect(fileMenuSource.contains("imageEditor.action.canvasNewFromClipboard"))
        #expect(fileMenuSource.contains("viewModel.createCanvasFromClipboard()"))
        #expect(fileMenuSource.contains(".keyboardShortcut(\"n\", modifiers: [.command, .option])"))
        #expect(fileMenuSource.contains(".disabled(!viewModel.canCreateCanvasFromClipboard)"))
    }

    @Test func fileMenuExposesDirectSelectionSliceExport() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let fileMenuStart = try #require(source.range(of: "private var fileMenu: some View"))
        let nextMenuStart = try #require(
            source[fileMenuStart.upperBound...].range(of: "private var editMenu: some View")
        )
        let fileMenuSource = source[fileMenuStart.lowerBound..<nextMenuStart.lowerBound]

        #expect(fileMenuSource.contains("imageEditor.action.exportSelection"))
        #expect(fileMenuSource.contains("viewModel.exportSettings.scope = .selection"))
        #expect(fileMenuSource.contains(".keyboardShortcut(\"e\", modifiers: [.command, .option])"))
        #expect(fileMenuSource.contains(".disabled(!viewModel.canExportSelection)"))
    }

    @Test func fileMenuExposesDirectSelectedLayerExport() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let fileMenuStart = try #require(source.range(of: "private var fileMenu: some View"))
        let nextMenuStart = try #require(
            source[fileMenuStart.upperBound...].range(of: "private var editMenu: some View")
        )
        let fileMenuSource = source[fileMenuStart.lowerBound..<nextMenuStart.lowerBound]

        #expect(fileMenuSource.contains("imageEditor.action.exportLayers"))
        #expect(fileMenuSource.contains("viewModel.selectedLayersExportScope"))
        #expect(fileMenuSource.contains(".keyboardShortcut(\"l\", modifiers: [.command, .option])"))
        #expect(fileMenuSource.contains(".disabled(viewModel.selectedLayersExportScope == nil)"))
    }

    @Test func layerRowsExposeTheSameSelectedLayerExportAction() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorLayerPanel.swift"),
            encoding: .utf8
        )
        let layerRowStart = try #require(source.range(of: "private func layerRow(_ layer: ImageEditorLayer)"))
        let nextFunctionStart = try #require(
            source[layerRowStart.upperBound...].range(of: "private func layerRowDropPlacement")
        )
        let layerRowSource = source[layerRowStart.lowerBound..<nextFunctionStart.lowerBound]

        #expect(layerRowSource.contains(".contextMenu"))
        #expect(layerRowSource.contains("imageEditor.action.exportLayers"))
        #expect(layerRowSource.contains("viewModel.selectedLayersExportScope"))
        #expect(layerRowSource.contains("viewModel.openExportPanel()"))
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

    @Test func selectMenuExposesClassicSelectionShortcuts() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let selectMenuStart = try #require(source.range(of: "private var selectMenu: some View"))
        let nextMenuStart = try #require(
            source[selectMenuStart.upperBound...].range(of: "private var alphaChannelMenu: some View")
        )
        let selectMenuSource = source[selectMenuStart.lowerBound..<nextMenuStart.lowerBound]

        #expect(selectMenuSource.contains("viewModel.selectAll()"))
        #expect(selectMenuSource.contains(".keyboardShortcut(\"a\", modifiers: [.command])"))
        #expect(selectMenuSource.contains("viewModel.clearSelection()"))
        #expect(selectMenuSource.contains(".keyboardShortcut(\"d\", modifiers: [.command])"))
        #expect(selectMenuSource.contains("viewModel.reselectSelection()"))
        #expect(selectMenuSource.contains(".keyboardShortcut(\"d\", modifiers: [.command, .shift])"))
        #expect(selectMenuSource.contains("viewModel.invertSelection()"))
        #expect(selectMenuSource.contains(".keyboardShortcut(\"i\", modifiers: [.command, .shift])"))
        #expect(selectMenuSource.contains("viewModel.featherSelection()"))
        #expect(selectMenuSource.contains(".keyboardShortcut(\"d\", modifiers: [.command, .option])"))
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
        #expect(channelMenuSource.contains("viewModel.isLayersPanelVisible = true"))
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

    @Test func windowMenuExposesDefaultWorkspaceResetInPhotoshopStyleLocation() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let windowMenuStart = try #require(source.range(of: "private var windowMenu: some View"))
        let nextMenuStart = try #require(
            source[windowMenuStart.upperBound...].range(of: "private var toolsActionsMenu: some View")
        )
        let windowMenuSource = source[windowMenuStart.lowerBound..<nextMenuStart.lowerBound]

        #expect(windowMenuSource.contains("imageEditor.action.workspaceResetDefault"))
        #expect(windowMenuSource.contains("viewModel.resetDefaultWorkspace()"))
        #expect(windowMenuSource.contains("selectedLayerPanelTab = .layers"))
        #expect(windowMenuSource.contains("imageEditor.action.workspaceHidePanels"))
        #expect(windowMenuSource.contains("imageEditor.action.workspaceShowPanels"))
        #expect(windowMenuSource.contains("viewModel.toggleWorkspaceChromeVisibility()"))
        #expect(windowMenuSource.contains(".keyboardShortcut(.tab, modifiers: [])"))
        #expect(windowMenuSource.contains("imageEditor.action.rightDockHidePanels"))
        #expect(windowMenuSource.contains("imageEditor.action.rightDockShowPanels"))
        #expect(windowMenuSource.contains("viewModel.toggleRightDockVisibility()"))
        #expect(windowMenuSource.contains(".keyboardShortcut(.tab, modifiers: [.shift])"))
        #expect(windowMenuSource.contains("imageEditor.action.statusBarHide"))
        #expect(windowMenuSource.contains("imageEditor.action.statusBarShow"))
        #expect(windowMenuSource.contains("viewModel.toggleStatusBarVisibility()"))
    }

    @Test func viewMenuExposesClassicZoomShortcuts() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let viewMenuStart = try #require(source.range(of: "private var viewMenu: some View"))
        let nextMenuStart = try #require(
            source[viewMenuStart.upperBound...].range(of: "private var windowMenu: some View")
        )
        let viewMenuSource = source[viewMenuStart.lowerBound..<nextMenuStart.lowerBound]

        #expect(viewMenuSource.contains("viewModel.toggleRulersVisible()"))
        #expect(viewMenuSource.contains(".keyboardShortcut(\"r\", modifiers: [.command])"))
        #expect(viewMenuSource.contains("viewModel.toggleGuidesVisible()"))
        #expect(viewMenuSource.contains(".keyboardShortcut(\";\", modifiers: [.command])"))
        #expect(viewMenuSource.contains("viewModel.toggleGuideSnapping()"))
        #expect(viewMenuSource.contains(".keyboardShortcut(\";\", modifiers: [.command, .shift])"))
        #expect(viewMenuSource.contains("viewModel.toggleGuidesLocked()"))
        #expect(viewMenuSource.contains(".keyboardShortcut(\";\", modifiers: [.command, .option])"))
        #expect(viewMenuSource.contains("viewModel.toggleGridVisible()"))
        #expect(viewMenuSource.contains(".keyboardShortcut(\"'\", modifiers: [.command])"))
        #expect(viewMenuSource.contains("viewModel.zoomIn()"))
        #expect(viewMenuSource.contains(".keyboardShortcut(\"+\", modifiers: [.command])"))
        #expect(viewMenuSource.contains("viewModel.zoomOut()"))
        #expect(viewMenuSource.contains(".keyboardShortcut(\"-\", modifiers: [.command])"))
        #expect(viewMenuSource.contains("viewModel.zoomActualPixels()"))
        #expect(viewMenuSource.contains(".keyboardShortcut(\"1\", modifiers: [.command])"))
        #expect(viewMenuSource.contains("viewModel.fitZoom()"))
        #expect(viewMenuSource.contains(".keyboardShortcut(\"0\", modifiers: [.command])"))
        #expect(viewMenuSource.contains("viewModel.toggleTransformControlsVisible()"))
        #expect(!viewMenuSource.contains(".keyboardShortcut(\"t\", modifiers: [.command])"))
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
        #expect(navigatorMenuSource.contains("viewModel.isNavigatorPanelVisible = true"))
        #expect(navigatorMenuSource.contains("imageEditor.action.navigatorHidePanel"))
        #expect(navigatorMenuSource.contains("imageEditor.action.navigatorShowPanelVisibility"))
        #expect(navigatorMenuSource.contains("viewModel.toggleNavigatorPanelVisibility()"))
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
        #expect(infoMenuSource.contains("KeyEquivalent(Character(UnicodeScalar(NSF8FunctionKey)!))"))
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
        #expect(colorMenuSource.contains("KeyEquivalent(Character(UnicodeScalar(NSF6FunctionKey)!))"))
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

    @Test func windowMenuExposesToolsAndOptionsPanelActionsInPhotoshopStyleLocation() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let toolsMenuStart = try #require(source.range(of: "private var toolsActionsMenu: some View"))
        let optionsMenuStart = try #require(
            source[toolsMenuStart.upperBound...].range(of: "private var optionsActionsMenu: some View")
        )
        let nextMenuStart = try #require(
            source[optionsMenuStart.upperBound...].range(of: "private var navigatorActionsMenu: some View")
        )
        let toolOptionsSource = source[toolsMenuStart.lowerBound..<nextMenuStart.lowerBound]

        #expect(toolOptionsSource.contains("imageEditor.menu.window.tools"))
        #expect(toolOptionsSource.contains("imageEditor.action.toolsShowPanel"))
        #expect(toolOptionsSource.contains("imageEditor.action.toolsHidePanel"))
        #expect(toolOptionsSource.contains("imageEditor.action.toolsShowPanelVisibility"))
        #expect(toolOptionsSource.contains("viewModel.toolsPanelSummaryText"))
        #expect(toolOptionsSource.contains("viewModel.toggleToolsPanelVisibility()"))
        #expect(toolOptionsSource.contains("viewModel.toolsPanelTools"))
        #expect(toolOptionsSource.contains("viewModel.selectToolsPanelTool(tool)"))
        #expect(toolOptionsSource.contains("imageEditor.menu.window.options"))
        #expect(toolOptionsSource.contains("imageEditor.action.optionsShowPanel"))
        #expect(toolOptionsSource.contains("imageEditor.action.optionsHideBar"))
        #expect(toolOptionsSource.contains("imageEditor.action.optionsShowBar"))
        #expect(toolOptionsSource.contains("viewModel.optionsPanelSummaryText"))
        #expect(toolOptionsSource.contains("viewModel.toggleOptionsBarVisibility()"))
        #expect(toolOptionsSource.contains("ImageEditorSelectionMode.allCases"))
        #expect(toolOptionsSource.contains("viewModel.applyOptionsSelectionMode(mode)"))
        #expect(toolOptionsSource.contains("viewModel.applyOptionsBrushSizePreset(size)"))
        #expect(toolOptionsSource.contains("viewModel.applyOptionsOpacityPreset(percent)"))
        #expect(toolOptionsSource.contains("viewModel.applyOptionsHardnessPreset(percent)"))
    }

    @Test func editorChromeConditionallyRendersToolsAndOptionsPanels() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("if viewModel.isOptionsBarVisible"))
        #expect(source.contains("if viewModel.areToolsPanelVisible"))
    }

    @Test func editorChromeConditionallyRendersRightDockPanels() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("if viewModel.isRightDockVisible"))
        #expect(source.contains("if viewModel.isNavigatorPanelVisible"))
        #expect(source.contains("if viewModel.isHistoryPanelVisible"))
        #expect(source.contains("if viewModel.isLayersPanelVisible"))
        #expect(source.contains("if viewModel.isPropertiesPanelVisible"))
    }

    @Test func layersDockUsesTheSharedDisclosureLayout() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let dockStart = try #require(source.range(of: "private var rightDock: some View"))
        let nextSectionStart = try #require(
            source[dockStart.upperBound...].range(of: "private func navigatorPanel")
        )
        let dockSource = source[dockStart.lowerBound..<nextSectionStart.lowerBound]

        #expect(source.contains("@State private var isLayersDockExpanded = true"))
        #expect(source.contains("@State private var isNavigatorDockExpanded = true"))
        #expect(dockSource.contains("ScrollView"))
        #expect(dockSource.contains("title: L10n.text(\"imageEditor.panel.layersChannels\")"))
        #expect(dockSource.contains("isExpanded: $isLayersDockExpanded"))
        #expect(dockSource.contains("layersPanel(showsTitle: false)"))
    }

    @Test func layerListExposesDirectSelectionVisibilityAndDragReordering() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorLayerPanel.swift"),
            encoding: .utf8
        )

        #expect(source.contains(".accessibilityIdentifier(\"image-editor-layer-list\")"))
        #expect(source.contains("layerDragHandle(layer)"))
        #expect(source.contains(".gesture(layerReorderGesture(layer))"))
        #expect(source.contains("viewModel.moveLayerIDs(sourceIDs, toDropTarget: target)"))
        #expect(source.contains("NSItemProvider(object: layer.id.uuidString as NSString)"))
        #expect(source.contains("ImageEditorLayerDropDelegate"))
        #expect(source.contains("UTType.plainText"))
        #expect(source.contains("viewModel.toggleLayerVisibility(layer.id)"))
        #expect(source.contains("viewModel.selectLayer("))
        #expect(source.contains("layerNameEditor(layer)"))
        #expect(source.contains("Text(layer.name)"))
        #expect(source.contains("image-editor-layer-row-\\(layer.id.uuidString)"))
        #expect(source.contains("image-editor-layer-visibility-\\(layer.id.uuidString)"))
        #expect(source.contains(".frame(minHeight: 150, maxHeight: .infinity)"))
        #expect(source.contains("layerAdvancedControlsDisclosure"))
        #expect(source.contains("image-editor-layer-advanced-controls"))

        let rowsPosition = try #require(source.range(of: "layerRows"))
        let advancedPosition = try #require(source.range(of: "layerAdvancedControlsDisclosure"))
        #expect(rowsPosition.lowerBound < advancedPosition.lowerBound)
    }

    @Test func channelsPanelKeepsRowsBoundedAndUsesCachedThumbnails() throws {
        let panelSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorLayerPanel.swift"),
            encoding: .utf8
        )
        let viewModelSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorViewModel.swift"),
            encoding: .utf8
        )

        #expect(panelSource.contains("viewModel.channelThumbnailImage(for: channel)"))
        #expect(panelSource.contains("viewModel.alphaChannelThumbnailImage(channel)"))
        #expect(panelSource.contains("alphaChannelActionsMenu(channel)"))
        #expect(panelSource.contains(".frame(maxWidth: .infinity, alignment: .leading)"))
        #expect(viewModelSource.contains("private var cachedChannelThumbnailImages"))
        #expect(viewModelSource.contains("private var cachedAlphaChannelThumbnailImages"))
        #expect(viewModelSource.contains("Self.channelThumbnailSize"))
    }

    @Test func editorChromeConditionallyRendersStatusBar() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("if viewModel.isStatusBarVisible"))
        #expect(source.contains("statusBar"))
    }

    @MainActor
    @Test func toolsAndOptionsPanelActionsReuseExistingToolSettings() throws {
        let image = NSImage(size: NSSize(width: 16, height: 16))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.selectToolsPanelTool(.magicWand)

        #expect(viewModel.selectedTool == .magicWand)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.toolsPanelToolSelected", ImageEditorTool.magicWand.title, viewModel.optionsPanelSummaryText))
        #expect(viewModel.toolsPanelSummaryText.contains(ImageEditorTool.magicWand.title))
        #expect(viewModel.toolsPanelTools.count == ImageEditorTool.allCases.count)

        viewModel.applyOptionsSelectionMode(.add)
        viewModel.applyOptionsBrushSizePreset(48)
        viewModel.applyOptionsOpacityPreset(75)
        viewModel.applyOptionsHardnessPreset(25)

        #expect(viewModel.selectionMode == .add)
        #expect(Int(viewModel.brushSize.rounded()) == 48)
        #expect(Int((viewModel.opacity * 100).rounded()) == 75)
        #expect(Int((viewModel.hardness * 100).rounded()) == 25)
        #expect(viewModel.statusText == viewModel.optionsPanelSummaryText)
        #expect(viewModel.optionsPanelSummaryText.contains(ImageEditorTool.magicWand.title))
        #expect(viewModel.optionsPanelSummaryText.contains("48"))
        #expect(viewModel.optionsPanelSummaryText.contains("75"))
        #expect(viewModel.optionsPanelSummaryText.contains("25"))
    }

    @MainActor
    @Test func toolsAndOptionsPanelVisibilityDefaultsOnAndCanToggle() throws {
        let image = NSImage(size: NSSize(width: 16, height: 16))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        #expect(viewModel.areToolsPanelVisible)
        #expect(viewModel.isOptionsBarVisible)

        viewModel.toggleToolsPanelVisibility()

        #expect(!viewModel.areToolsPanelVisible)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.toolsPanelHidden"))

        viewModel.toggleToolsPanelVisibility()

        #expect(viewModel.areToolsPanelVisible)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.toolsPanelShown"))

        viewModel.toggleOptionsBarVisibility()

        #expect(!viewModel.isOptionsBarVisible)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.optionsBarHidden"))

        viewModel.toggleOptionsBarVisibility()

        #expect(viewModel.isOptionsBarVisible)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.optionsBarShown"))
    }

    @MainActor
    @Test func rightDockPanelVisibilityDefaultsOnAndCanToggle() throws {
        let image = NSImage(size: NSSize(width: 16, height: 16))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        #expect(viewModel.isNavigatorPanelVisible)
        #expect(viewModel.isHistoryPanelVisible)
        #expect(viewModel.isLayersPanelVisible)
        #expect(viewModel.isPropertiesPanelVisible)
        #expect(viewModel.isRightDockVisible)

        viewModel.toggleNavigatorPanelVisibility()
        viewModel.toggleHistoryPanelVisibility()
        viewModel.toggleLayersPanelVisibility()
        viewModel.togglePropertiesPanelVisibility()

        #expect(!viewModel.isNavigatorPanelVisible)
        #expect(!viewModel.isHistoryPanelVisible)
        #expect(!viewModel.isLayersPanelVisible)
        #expect(!viewModel.isPropertiesPanelVisible)
        #expect(!viewModel.isRightDockVisible)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.propertiesPanelHidden"))

        viewModel.togglePropertiesPanelVisibility()

        #expect(viewModel.isRightDockVisible)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.propertiesPanelShown"))
    }

    @MainActor
    @Test func rightDockTogglePreservesToolsAndOptionsPanels() throws {
        let image = NSImage(size: NSSize(width: 16, height: 16))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        #expect(viewModel.areToolsPanelVisible)
        #expect(viewModel.isOptionsBarVisible)
        #expect(viewModel.isRightDockVisible)

        viewModel.toggleRightDockVisibility()

        #expect(viewModel.areToolsPanelVisible)
        #expect(viewModel.isOptionsBarVisible)
        #expect(!viewModel.isNavigatorPanelVisible)
        #expect(!viewModel.isHistoryPanelVisible)
        #expect(!viewModel.isLayersPanelVisible)
        #expect(!viewModel.isPropertiesPanelVisible)
        #expect(!viewModel.isRightDockVisible)
        #expect(viewModel.isWorkspaceChromeVisible)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.rightDockPanelsHidden"))

        viewModel.toggleRightDockVisibility()

        #expect(viewModel.areToolsPanelVisible)
        #expect(viewModel.isOptionsBarVisible)
        #expect(viewModel.isNavigatorPanelVisible)
        #expect(viewModel.isHistoryPanelVisible)
        #expect(viewModel.isLayersPanelVisible)
        #expect(viewModel.isPropertiesPanelVisible)
        #expect(viewModel.isRightDockVisible)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.rightDockPanelsShown"))
    }

    @MainActor
    @Test func defaultWorkspaceResetRestoresAllEditorChromePanels() throws {
        let image = NSImage(size: NSSize(width: 16, height: 16))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.toggleToolsPanelVisibility()
        viewModel.toggleOptionsBarVisibility()
        viewModel.toggleNavigatorPanelVisibility()
        viewModel.toggleHistoryPanelVisibility()
        viewModel.toggleLayersPanelVisibility()
        viewModel.togglePropertiesPanelVisibility()
        viewModel.toggleStatusBarVisibility()

        #expect(!viewModel.areToolsPanelVisible)
        #expect(!viewModel.isOptionsBarVisible)
        #expect(!viewModel.isRightDockVisible)
        #expect(!viewModel.isStatusBarVisible)

        viewModel.resetDefaultWorkspace()

        #expect(viewModel.areToolsPanelVisible)
        #expect(viewModel.isOptionsBarVisible)
        #expect(viewModel.isNavigatorPanelVisible)
        #expect(viewModel.isHistoryPanelVisible)
        #expect(viewModel.isLayersPanelVisible)
        #expect(viewModel.isPropertiesPanelVisible)
        #expect(viewModel.isRightDockVisible)
        #expect(viewModel.isStatusBarVisible)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.workspaceDefaultRestored"))
    }

    @MainActor
    @Test func statusBarVisibilityDefaultsOnAndCanToggle() throws {
        let image = NSImage(size: NSSize(width: 16, height: 16))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        #expect(viewModel.isStatusBarVisible)

        viewModel.toggleStatusBarVisibility()

        #expect(!viewModel.isStatusBarVisible)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.statusBarHidden"))

        viewModel.toggleStatusBarVisibility()

        #expect(viewModel.isStatusBarVisible)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.statusBarShown"))
    }

    @MainActor
    @Test func workspaceChromeToggleHidesAndShowsAllEditorPanels() throws {
        let image = NSImage(size: NSSize(width: 16, height: 16))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        #expect(viewModel.isWorkspaceChromeVisible)

        viewModel.toggleWorkspaceChromeVisibility()

        #expect(!viewModel.areToolsPanelVisible)
        #expect(!viewModel.isOptionsBarVisible)
        #expect(!viewModel.isNavigatorPanelVisible)
        #expect(!viewModel.isHistoryPanelVisible)
        #expect(!viewModel.isLayersPanelVisible)
        #expect(!viewModel.isPropertiesPanelVisible)
        #expect(!viewModel.isRightDockVisible)
        #expect(!viewModel.isWorkspaceChromeVisible)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.workspacePanelsHidden"))

        viewModel.toggleWorkspaceChromeVisibility()

        #expect(viewModel.areToolsPanelVisible)
        #expect(viewModel.isOptionsBarVisible)
        #expect(viewModel.isNavigatorPanelVisible)
        #expect(viewModel.isHistoryPanelVisible)
        #expect(viewModel.isLayersPanelVisible)
        #expect(viewModel.isPropertiesPanelVisible)
        #expect(viewModel.isRightDockVisible)
        #expect(viewModel.isWorkspaceChromeVisible)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.workspacePanelsShown"))
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
        #expect(brushesMenuSource.contains("KeyEquivalent(Character(UnicodeScalar(NSF5FunctionKey)!))"))
        #expect(brushesMenuSource.contains("viewModel.brushesPanelSummaryText"))
        #expect(brushesMenuSource.contains("imageEditor.menu.window.brushes.tools"))
        #expect(brushesMenuSource.contains("viewModel.selectBrushPanelTool(tool)"))
        #expect(brushesMenuSource.contains("imageEditor.menu.window.brushes.presets"))
        #expect(brushesMenuSource.contains("ForEach(viewModel.brushPresets)"))
        #expect(brushesMenuSource.contains("viewModel.applyBrushPreset(preset)"))
        #expect(brushesMenuSource.contains("viewModel.createBrushPresetFromCurrentSettings()"))
        #expect(brushesMenuSource.contains("viewModel.deleteBrushPreset(activePreset)"))
    }

    @Test func brushAndEraserOptionsExposeNonFocusablePresetManagement() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let menuStart = try #require(source.range(of: "private var brushPresetMenu: some View"))
        let pressureStart = try #require(
            source[menuStart.upperBound...].range(of: "private var brushPressureMenu: some View")
        )
        let menuSource = source[menuStart.lowerBound..<pressureStart.lowerBound]

        #expect(source.contains("if usesBrushDynamicsOptions {\n                    brushPresetMenu"))
        #expect(menuSource.contains("ForEach(viewModel.brushPresets)"))
        #expect(menuSource.contains("viewModel.activeBrushPreset?.id == preset.id"))
        #expect(menuSource.contains("viewModel.createBrushPresetFromCurrentSettings()"))
        #expect(menuSource.contains("viewModel.deleteBrushPreset(activePreset)"))
        #expect(menuSource.contains(".focusable(false)"))
        #expect(menuSource.contains("image-editor-brush-preset-menu"))
    }

    @Test func patchToolExposesModesAndWiresTwoPhaseLivePreviewInteraction() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let pickerStart = try #require(source.range(of: "private var patchModePicker: some View"))
        let pickerEnd = try #require(
            source[pickerStart.upperBound...].range(of: "private func sampledBrushOptions")
        )
        let pickerSource = source[pickerStart.lowerBound..<pickerEnd.lowerBound]

        #expect(pickerSource.contains("ForEach(ImageEditorPatchMode.allCases)"))
        #expect(pickerSource.contains(".focusable(false)"))
        #expect(pickerSource.contains("image-editor-patch-mode"))
        #expect(source.contains("viewModel.canBeginPatch(at: pointerImagePoint)"))
        #expect(source.contains("viewModel.createPatchSelection(points: dragPoints)"))
        #expect(source.contains("patchPreviewImage = viewModel.patchPreviewImage("))
        #expect(source.contains("if viewModel.selectedTool == .patchTool, let patchPreviewImage"))
        #expect(source.contains("viewModel.patchSelection(from: dragStart, to: endImagePoint)"))
    }

    @Test func healingBrushExposesNonFocusableSourceAndSpotModes() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let healingStart = try #require(
            source.range(of: "if viewModel.selectedTool == .healingBrush {")
        )
        let colorSamplerStart = try #require(
            source[healingStart.upperBound...].range(of: "if viewModel.selectedTool == .colorSampler")
        )
        let healingSource = source[healingStart.lowerBound..<colorSamplerStart.lowerBound]

        #expect(healingSource.contains("ForEach(ImageEditorHealingBrushMode.allCases)"))
        #expect(healingSource.contains(".focusable(false)"))
        #expect(healingSource.contains("image-editor-healing-mode"))
        #expect(healingSource.contains(
            "showsExplicitSourceControls: viewModel.healingBrushMode == .source"
        ))
        #expect(source.contains("guard viewModel.healingBrushMode == .source else { return nil }"))
    }

    @Test func spongeToolExposesANonFocusableSaturationModePicker() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let spongeStart = try #require(
            source.range(of: "if viewModel.selectedTool == .sponge {")
        )
        let textStart = try #require(
            source[spongeStart.upperBound...].range(of: "if viewModel.selectedTool == .text")
        )
        let spongeSource = source[spongeStart.lowerBound..<textStart.lowerBound]

        #expect(spongeSource.contains("ForEach(ImageEditorSpongeMode.allCases)"))
        #expect(spongeSource.contains("selection: $viewModel.spongeMode"))
        #expect(spongeSource.contains(".focusable(false)"))
        #expect(spongeSource.contains("image-editor-sponge-mode"))
    }

    @Test func dodgeAndBurnExposeANonFocusableToneRangeMenu() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let rangeStart = try #require(
            source.range(of: "if viewModel.selectedTool == .dodge || viewModel.selectedTool == .burn {")
        )
        let textStart = try #require(
            source[rangeStart.upperBound...].range(of: "if viewModel.selectedTool == .text")
        )
        let rangeSource = source[rangeStart.lowerBound..<textStart.lowerBound]

        #expect(rangeSource.contains("ForEach(ImageEditorToneRange.allCases)"))
        #expect(rangeSource.contains("selection: $viewModel.toneRange"))
        #expect(rangeSource.contains(".pickerStyle(.menu)"))
        #expect(rangeSource.contains(".focusable(false)"))
        #expect(rangeSource.contains("image-editor-tone-range"))
    }

    @Test func dodgeAndBurnExposeANonFocusableProtectTonesToggle() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let rangeStart = try #require(
            source.range(of: "if viewModel.selectedTool == .dodge || viewModel.selectedTool == .burn {")
        )
        let textStart = try #require(
            source[rangeStart.upperBound...].range(of: "if viewModel.selectedTool == .text")
        )
        let rangeSource = source[rangeStart.lowerBound..<textStart.lowerBound]

        #expect(rangeSource.contains("isOn: $viewModel.protectToneBrushTones"))
        #expect(rangeSource.contains(".toggleStyle(.checkbox)"))
        #expect(rangeSource.contains(".focusable(false)"))
        #expect(rangeSource.contains("image-editor-protect-tones"))
    }

    @Test func dodgeAndBurnExposeANonFocusableAirbrushToggleAndLightweightPreview() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let airbrushSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorToneAirbrush.swift"),
            encoding: .utf8
        )
        let rangeStart = try #require(
            source.range(of: "if viewModel.selectedTool == .dodge || viewModel.selectedTool == .burn {")
        )
        let textStart = try #require(
            source[rangeStart.upperBound...].range(of: "if viewModel.selectedTool == .text")
        )
        let rangeSource = source[rangeStart.lowerBound..<textStart.lowerBound]

        #expect(rangeSource.contains("isOn: $viewModel.toneBrushAirbrushEnabled"))
        #expect(rangeSource.contains(".toggleStyle(.checkbox)"))
        #expect(rangeSource.contains(".focusable(false)"))
        #expect(rangeSource.contains("image-editor-tone-airbrush"))
        #expect(airbrushSource.contains("TimelineView(.periodic"))
        #expect(airbrushSource.contains("ImageEditorToneAirbrushPreview"))
        #expect(source.contains("toneAirbrushOverlay(in: geometry.size)"))
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
        #expect(textPanelSource.contains("viewModel.toggleCharacterUnderline()"))
        #expect(textPanelSource.contains("viewModel.toggleCharacterStrikethrough()"))
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
        viewModel.textLeftIndent = 24
        viewModel.textRightIndent = 16
        viewModel.textFirstLineIndent = 12
        viewModel.selectCharacterPanelTool()

        #expect(viewModel.selectedTool == .text)
        #expect(viewModel.statusText == viewModel.characterPanelSummaryText)
        #expect(viewModel.characterPanelSummaryText.contains("Caption"))
        #expect(viewModel.characterPanelSummaryText.contains("48"))
        #expect(viewModel.characterPanelSummaryText.contains("4"))
        #expect(viewModel.characterPanelSummaryText.contains("12"))

        viewModel.toggleCharacterBold()
        viewModel.toggleCharacterItalic()
        viewModel.toggleCharacterUnderline()
        viewModel.toggleCharacterStrikethrough()

        #expect(viewModel.textBold)
        #expect(viewModel.textItalic)
        #expect(viewModel.textUnderlined)
        #expect(viewModel.textStruckThrough)
        #expect(viewModel.statusText == viewModel.characterPanelSummaryText)
        #expect(viewModel.characterPanelSummaryText.contains(L10n.text("imageEditor.characterPanel.enabled")))

        viewModel.selectParagraphAlignment(.center)

        #expect(viewModel.selectedTextAlignment == .center)
        #expect(viewModel.statusText == viewModel.paragraphPanelSummaryText)
        #expect(viewModel.paragraphPanelSummaryText.contains(ImageEditorTextAlignment.center.title))
        #expect(viewModel.paragraphPanelSummaryText.contains("320"))
        #expect(viewModel.paragraphPanelSummaryText.contains("24"))
        #expect(viewModel.paragraphPanelSummaryText.contains("16"))
        #expect(viewModel.paragraphPanelSummaryText.contains("12"))
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
        #expect(source.contains("imageEditor.action.layerStyleBlendingOptions"))
        #expect(source.contains("viewModel.showLayerStyleBlendingOptions()"))
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
    @Test func layerStyleBlendingOptionsPreparePropertiesPanel() {
        let image = NSImage(size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.isPropertiesPanelVisible = false
        viewModel.showLayerStyleBlendingOptions()

        #expect(viewModel.isPropertiesPanelVisible)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.layerStyleReady"))
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
        #expect(layerMenuSource.contains("viewModel.isLayersPanelVisible = true"))
        #expect(layerMenuSource.contains("KeyEquivalent(Character(UnicodeScalar(NSF7FunctionKey)!))"))
        #expect(layerMenuSource.contains("imageEditor.action.layersHidePanel"))
        #expect(layerMenuSource.contains("imageEditor.action.layersShowPanelVisibility"))
        #expect(layerMenuSource.contains("viewModel.toggleLayersPanelVisibility()"))
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
        #expect(layerMenuSource.contains("viewModel.mergeDownActionTitleKey"))
        #expect(layerMenuSource.contains("viewModel.mergeSelectedLayerDown()"))
        #expect(layerMenuSource.contains("viewModel.canMergeSelectedLayerDown"))
        #expect(layerMenuSource.contains("imageEditor.action.layerFlatten"))
        #expect(layerMenuSource.contains("viewModel.flattenImage()"))
        #expect(layerMenuSource.contains("viewModel.canFlattenImage"))
        #expect(layerMenuSource.contains("imageEditor.action.layerSmartObjectReplace"))
        #expect(layerMenuSource.contains("viewModel.chooseSmartObjectReplacementFile()"))
        #expect(layerMenuSource.contains("viewModel.canReplaceSelectedSmartObjectContents"))
        #expect(layerMenuSource.contains("imageEditor.action.layerSmartObjectMakeUnique"))
        #expect(layerMenuSource.contains("viewModel.makeSelectedSmartObjectUnique()"))
        #expect(layerMenuSource.contains("viewModel.canMakeSelectedSmartObjectUnique"))
        #expect(layerMenuSource.contains("imageEditor.action.layerSmartObjectResetTransform"))
        #expect(layerMenuSource.contains("viewModel.resetSelectedSmartObjectTransform()"))
        #expect(layerMenuSource.contains("viewModel.canResetSelectedSmartObjectTransform"))
    }

    @Test func layerPanelExposesSmartObjectContentActions() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorLayerPanel.swift"),
            encoding: .utf8
        )
        let menuStart = try #require(source.range(of: "private var layerMoreActionsMenu: some View"))
        let menuEnd = try #require(source[menuStart.upperBound...].range(of: "private var layerAlignmentButtons"))
        let menuSource = source[menuStart.lowerBound..<menuEnd.lowerBound]

        #expect(menuSource.contains("imageEditor.action.layerSmartObjectReplace"))
        #expect(menuSource.contains("viewModel.chooseSmartObjectReplacementFile()"))
        #expect(menuSource.contains("imageEditor.action.layerSmartObjectMakeUnique"))
        #expect(menuSource.contains("viewModel.makeSelectedSmartObjectUnique()"))
        #expect(menuSource.contains("imageEditor.action.layerSmartObjectResetTransform"))
        #expect(menuSource.contains("viewModel.resetSelectedSmartObjectTransform()"))
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
        #expect(historyMenuSource.contains("viewModel.isHistoryPanelVisible = true"))
        #expect(historyMenuSource.contains("imageEditor.action.historyHidePanel"))
        #expect(historyMenuSource.contains("imageEditor.action.historyShowPanelVisibility"))
        #expect(historyMenuSource.contains("viewModel.toggleHistoryPanelVisibility()"))
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
        #expect(propertiesMenuSource.contains("viewModel.isPropertiesPanelVisible = true"))
        #expect(propertiesMenuSource.contains("imageEditor.action.propertiesHidePanel"))
        #expect(propertiesMenuSource.contains("imageEditor.action.propertiesShowPanelVisibility"))
        #expect(propertiesMenuSource.contains("viewModel.togglePropertiesPanelVisibility()"))
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
        #expect(layerCompMenuSource.contains("viewModel.isLayersPanelVisible = true"))
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

    @Test func deploymentTargetsRemainCompatibleWithMacOS13() throws {
        let repositoryRoot = Self.repositoryRoot()
        let project = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic.xcodeproj/project.pbxproj"),
            encoding: .utf8
        )
        let package = try String(
            contentsOf: repositoryRoot.appendingPathComponent("xomo-cli/Package.swift"),
            encoding: .utf8
        )
        let theme = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/Theme.swift"),
            encoding: .utf8
        )

        #expect(project.contains("MACOSX_DEPLOYMENT_TARGET = 13.0;"))
        #expect(!project.contains("MACOSX_DEPLOYMENT_TARGET = 12"))
        #expect(!project.contains("MACOSX_DEPLOYMENT_TARGET = 26"))
        #expect(package.contains("platforms: [.macOS(.v13)]"))
        #expect(theme.contains("if #available(macOS 13.0, *)"))
        #expect(theme.contains("if #available(macOS 14.0, *)"))
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
