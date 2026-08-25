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
    @Test func penEndpointDragUsesTheCrossLayerContinuationTarget() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let branchStart = try #require(
            source.range(of: "viewModel.penPathContinuationState(at: pointerStart) != .none")
        )
        let branchEnd = try #require(
            source[branchStart.upperBound...].range(
                of: "viewModel.beginMovingPenPathAnchor("
            )
        )
        let branch = source[branchStart.lowerBound..<branchEnd.lowerBound]

        #expect(branch.contains("viewModel.beginMovingPenPathContinuationAnchor("))
        #expect(!branch.contains("viewModel.beginMovingPathAnchor("))

        let anchorBranchStart = try #require(
            source[..<branchEnd.lowerBound].range(
                of: "} else if pendingPenCreationAction == nil,",
                options: .backwards
            )
        )
        let anchorBranchEnd = try #require(
            source[branchEnd.upperBound...].range(of: "pendingPenCreationAction =")
        )
        let anchorBranch = source[anchorBranchStart.lowerBound..<anchorBranchEnd.lowerBound]
        #expect(anchorBranch.contains("viewModel.pendingPenPathPoints.isEmpty"))
        #expect(anchorBranch.contains("viewModel.beginMovingPenPathAnchor("))
        #expect(!anchorBranch.contains("viewModel.canEditSelectedPathAnchors"))
    }

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
                "pencil",
                "historyBrush",
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
                "lensCorrection",
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
        #expect(shortcuts["pencil"] == "b")
        #expect(shortcuts["historyBrush"] == "y")
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
        #expect(ImageEditorTool.classicShortcutGroup(for: "b")?.tools == [.brush, .pencil])
        #expect(ImageEditorTool.classicShortcutGroup(for: "o")?.tools == [.dodge, .burn, .sponge])
        #expect(ImageEditorTool.classicShortcutGroup(for: "r")?.tools == [.blur, .sharpen, .smudge])
        #expect(ImageEditorTool.classicShortcutGroup(for: "u")?.tools == [.rectangle, .ellipse])
        #expect(ImageEditorTool.classicShortcutGroup(for: "j")?.tools == [.healingBrush, .patchTool, .redEye])
        #expect(ImageEditorTool.classicShortcutGroup(for: "y")?.tools == [.historyBrush])
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
            source[toolRailStart.upperBound...].range(of: "private var quickMaskControls: some View")
        )
        let toolRailSource = source[toolRailStart.lowerBound..<nextSectionStart.lowerBound]

        #expect(toolRailSource.contains("ForEach(ImageEditorTool.allCases)"))
        #expect(toolRailSource.contains("toolRailItem(tool)"))
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
        #expect(shortcutButtonsSource.contains("ImageEditorLiveMoveShortcutPolicy.allowsDirectShortcut"))
        #expect(shortcutButtonsSource.contains("viewModel.hasActiveLayerMoveTransaction"))

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
        #expect(brushShortcutSource.contains("performDirectShortcut"))

        let opacityShortcutStart = try #require(source.range(of: "private var opacityShortcutButtons: some View"))
        let opacityShortcutEnd = try #require(
            source[opacityShortcutStart.upperBound...].range(of: "private var colorChips: some View")
        )
        let opacityShortcutSource = source[opacityShortcutStart.lowerBound..<opacityShortcutEnd.lowerBound]

        #expect(opacityShortcutSource.contains("ForEach([1, 2, 3, 4, 5, 6, 7, 8, 9, 0], id: \\.self)"))
        #expect(opacityShortcutSource.contains("viewModel.applyOpacityShortcutDigit(digit)"))
        #expect(opacityShortcutSource.contains(".keyboardShortcut(KeyEquivalent(Character(String(digit))), modifiers: [])"))
        #expect(opacityShortcutSource.contains("performDirectShortcut"))

        let colorShortcutStart = try #require(source.range(of: "private var colorShortcutButtons: some View"))
        let colorShortcutEnd = try #require(
            source[colorShortcutStart.upperBound...].range(of: "private var colorChips: some View")
        )
        let colorShortcutSource = source[colorShortcutStart.lowerBound..<colorShortcutEnd.lowerBound]

        #expect(colorShortcutSource.contains("viewModel.resetForegroundBackgroundColors()"))
        #expect(colorShortcutSource.contains(".keyboardShortcut(\"d\", modifiers: [])"))
        #expect(colorShortcutSource.contains("viewModel.swapForegroundBackgroundColors()"))
        #expect(colorShortcutSource.contains(".keyboardShortcut(\"x\", modifiers: [])"))
        #expect(colorShortcutSource.contains("performDirectShortcut"))

        let alternateZoomStart = try #require(source.range(of: "private var alternateZoomShortcutButtons: some View"))
        let alternateZoomEnd = try #require(
            source[alternateZoomStart.upperBound...].range(of: "private var colorChips: some View")
        )
        let alternateZoomSource = source[alternateZoomStart.lowerBound..<alternateZoomEnd.lowerBound]
        #expect(alternateZoomSource.contains("performDirectShortcut { viewModel.zoomOut() }"))
        #expect(alternateZoomSource.components(separatedBy: "performDirectShortcut { viewModel.zoomIn() }").count - 1 == 2)

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
        #expect(nudgeShortcutSource.contains("performNudgeCommand(delta)"))
        #expect(nudgeShortcutSource.contains("performDirectShortcut"))
        #expect(nudgeShortcutSource.contains("ImageEditorLiveMoveShortcutPolicy.allowsDirectShortcut"))
        #expect(source.contains("nudgeSelected: performNudgeCommand"))
        let nudgeHelperStart = try #require(source.range(of: "func performNudgeCommand("))
        let nudgeHelperEnd = try #require(
            source[nudgeHelperStart.upperBound...].range(of: "\n    }")
        )
        let nudgeHelperSource = source[nudgeHelperStart.lowerBound..<nudgeHelperEnd.upperBound]
        let nudgeDispatchGate = try #require(
            nudgeHelperSource.range(of: "ImageEditorNudgeCommandDispatchGate.shouldDispatch")
        )
        let nudgeModelCommand = try #require(
            nudgeHelperSource.range(of: "viewModel.nudgeSelectionOrSelectedLayer(by: delta)")
        )
        #expect(nudgeDispatchGate.lowerBound < nudgeModelCommand.lowerBound)

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

    @Test func quickMaskControlSupportsClassicOptionClickAndEmptySelectionMenuEntry() throws {
        let viewSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let buttonStart = try #require(viewSource.range(of: "private var quickMaskButton: some View"))
        let buttonEnd = try #require(
            viewSource[buttonStart.upperBound...].range(of: "private var quickMaskOptionsPopover: some View")
        )
        let buttonSource = viewSource[buttonStart.lowerBound..<buttonEnd.lowerBound]
        #expect(
            buttonSource.contains(
                "viewModel.activateQuickMaskControl(modifierFlags: NSEvent.modifierFlags)"
            )
        )
        #expect(buttonSource.contains("imageEditor.help.quickMask"))

        let menuSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let quickMaskStart = try #require(
            menuSource.range(of: "Button(L10n.text(\"imageEditor.action.quickMask\"))")
        )
        let quickMaskEnd = try #require(
            menuSource[quickMaskStart.upperBound...].range(of: "Divider()")
        )
        let quickMaskMenuSource = menuSource[quickMaskStart.lowerBound..<quickMaskEnd.lowerBound]
        #expect(quickMaskMenuSource.contains("performToggleQuickMask()"))
        #expect(quickMaskMenuSource.contains(".keyboardShortcut(\"q\", modifiers: [])"))
        #expect(!quickMaskMenuSource.contains(".disabled"))

        let helperStart = try #require(viewSource.range(of: "func performToggleQuickMask()"))
        let helperEnd = try #require(
            viewSource[helperStart.upperBound...].range(of: "\n    }")
        )
        let helperSource = viewSource[helperStart.lowerBound..<helperEnd.upperBound]
        let dispatchGate = try #require(
            helperSource.range(of: "ImageEditorQuickMaskCommandDispatchGate.shouldDispatch")
        )
        let mutation = try #require(helperSource.range(of: "viewModel.toggleQuickMaskMode()"))
        #expect(dispatchGate.lowerBound < mutation.lowerBound)
        #expect(viewSource.contains("case .toggleQuickMask: performToggleQuickMask()"))
    }

    @Test func quickMaskGrayscalePreviewSharesOptionsAndKeyboardEntryPoints() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let optionsStart = try #require(
            source.range(of: "private var quickMaskOptionsPopover: some View")
        )
        let optionsEnd = try #require(
            source[optionsStart.upperBound...].range(of: "private var quickMaskOverlayColorBinding")
        )
        let optionsSource = source[optionsStart.lowerBound..<optionsEnd.lowerBound]
        #expect(optionsSource.contains("ImageEditorQuickMaskPreviewMode.allCases"))
        #expect(optionsSource.contains("viewModel.setQuickMaskPreviewMode(mode)"))
        #expect(optionsSource.contains("viewModel.quickMaskPreviewMode == mode"))
        #expect(optionsSource.contains(".disabled(!viewModel.isQuickMaskMode)"))
        #expect(optionsSource.contains("imageEditor.help.quickMaskPreview"))

        #expect(
            source.contains(
                "canToggleQuickMaskGrayscalePreview: viewModel.isQuickMaskMode"
            )
        )
        #expect(
            source.contains(
                "case .toggleQuickMaskGrayscalePreview: viewModel.toggleQuickMaskGrayscalePreview()"
            )
        )
        #expect(
            source.contains(
                "canToggleQuickMaskGrayscalePreview: canToggleQuickMaskGrayscalePreview"
            )
        )
    }

    @Test func toolRailProvidesExplicitLocalizedAccessibleNamesWithoutKeyboardFocus() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let railItemStart = try #require(source.range(of: "private func toolRailItem(_ tool: ImageEditorTool) -> some View"))
        let railItemEnd = try #require(
            source[railItemStart.upperBound...].range(of: "private var selectedToolHint: some View")
        )
        let railItemSource = source[railItemStart.lowerBound..<railItemEnd.lowerBound]
        let clickSurfaceStart = try #require(
            source.range(of: "private struct EditorToolRailTile<Label: View>: View")
        )
        let clickSurfaceEnd = try #require(
            source[clickSurfaceStart.upperBound...].range(of: "struct EditorIconButtonStyle: ButtonStyle")
        )
        let clickSurfaceSource = source[clickSurfaceStart.lowerBound..<clickSurfaceEnd.lowerBound]

        #expect(railItemSource.components(separatedBy: ".accessibilityLabel(tool.title)").count - 1 == 2)
        #expect(railItemSource.components(separatedBy: ".focusable(false)").count - 1 >= 3)
        #expect(railItemSource.components(separatedBy: "EditorToolRailTile(").count - 1 == 2)
        #expect(!railItemSource.contains("Button {\n                    selectToolFromRail(tool)"))
        #expect(railItemSource.contains("ImageEditorPaintBucketSymbol()"))
        #expect(railItemSource.contains(".accessibilityIdentifier(\"image-editor-tool-\\(tool.rawValue)\")"))
        #expect(source.contains("private let imageEditorToolButtonHitSize: CGFloat = 36"))
        #expect(source.contains("private struct EditorToolRailTile<Label: View>: View"))
        #expect(source.contains("private struct EditorToolRailGridClickSurface: NSViewRepresentable"))
        #expect(source.contains("final class EditorToolRailGridClickNSView: NSView"))
        #expect(source.contains("override func acceptsFirstMouse(for event: NSEvent?) -> Bool"))
        #expect(source.contains("override func mouseDown(with event: NSEvent)"))
        #expect(source.contains("toolCount: ImageEditorTool.allCases.count"))
        #expect(source.contains("onActivate: selectToolFromRail(at:)"))
        #expect(source.contains("onHoverChanged: updateHoveredTool(at:)"))
        #expect(clickSurfaceSource.contains("nsView.prepareForDismantling()"))
        #expect(!clickSurfaceSource.contains("nsView.onHoverChanged?(nil)"))
        #expect(source.contains(".allowsHitTesting(false)"))
        #expect(!clickSurfaceSource.contains(".onTapGesture(perform: action)"))
        #expect(source.contains(".accessibilityAction {\n                action()\n            }"))
        #expect(
            railItemSource.components(
                separatedBy: ".frame(width: imageEditorToolButtonHitSize, height: imageEditorToolButtonHitSize)"
            ).count - 1 >= 3
        )
    }

    @MainActor
    @Test func toolRailGridClickSurfaceMapsEveryFixedCellWithoutTakingFocus() throws {
        let toolCount = ImageEditorTool.allCases.count
        let rowCount = (toolCount + 1) / 2
        let surface = EditorToolRailGridClickNSView(
            frame: NSRect(x: 0, y: 0, width: 74, height: CGFloat(rowCount * 38 - 2))
        )
        surface.toolCount = toolCount

        for index in 0..<toolCount {
            let column = index % 2
            let row = index / 2
            let point = NSPoint(
                x: CGFloat(column * 38 + 18),
                y: CGFloat(row * 38 + 18)
            )
            let hit = try #require(surface.toolHit(at: point))
            #expect(hit.index == index)
            #expect(hit.localPoint == NSPoint(x: 18, y: 18))
        }

        #expect(surface.toolHit(at: NSPoint(x: 37, y: 18)) == nil)
        #expect(surface.toolHit(at: NSPoint(x: 18, y: 37)) == nil)
        #expect(surface.toolHit(at: NSPoint(x: -1, y: 18)) == nil)
        #expect(!surface.acceptsFirstResponder)
        #expect(surface.isFlipped)
    }

    @MainActor
    @Test func toolRailGridClickSurfaceDismantlesWithoutWritingSwiftUIHoverState() {
        let surface = EditorToolRailGridClickNSView(
            frame: NSRect(x: 0, y: 0, width: 74, height: 74)
        )
        var hoverCallbacks: [Int?] = []
        surface.activationHandler = { _ in }
        surface.marqueeMenuHandler = {}
        surface.onHoverChanged = { hoverCallbacks.append($0) }
        surface.updateTrackingAreas()

        surface.prepareForDismantling()

        #expect(hoverCallbacks.isEmpty)
        #expect(surface.activationHandler == nil)
        #expect(surface.marqueeMenuHandler == nil)
        #expect(surface.onHoverChanged == nil)
    }

    @Test func marqueeShapeMenuDoesNotConsumeTheNextToolClick() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let railItemStart = try #require(source.range(of: "private func toolRailItem(_ tool: ImageEditorTool) -> some View"))
        let railItemEnd = try #require(
            source[railItemStart.upperBound...].range(of: "private var selectedToolHint: some View")
        )
        let railItemSource = source[railItemStart.lowerBound..<railItemEnd.lowerBound]

        #expect(railItemSource.contains("private var marqueeShapeFloatingMenu: some View"))
        #expect(railItemSource.contains("private func selectToolFromRail(_ tool: ImageEditorTool)"))
        #expect(railItemSource.contains("isMarqueeShapeMenuPresented = false\n        viewModel.selectTool(tool)"))
        #expect(!railItemSource.contains(".popover(isPresented:"))
        #expect(source.contains("marqueeShapeFloatingMenu\n                        .offset(x: imageEditorToolRailWidth + 4, y: 50)"))
        #expect(source.contains(".accessibilityIdentifier(\"image-editor-marquee-shape-menu\")"))
    }

    @Test func leftSidebarRebuildsToolContentAfterLeavingComponentDragSources() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let sidebarStart = try #require(source.range(of: "private var leftSidebar: some View"))
        let sidebarEnd = try #require(
            source[sidebarStart.upperBound...].range(of: "private var toolRail: some View")
        )
        let sidebarSource = source[sidebarStart.lowerBound..<sidebarEnd.lowerBound]

        #expect(sidebarSource.contains("case .tools:"))
        #expect(sidebarSource.contains("case .components:"))
        #expect(sidebarSource.contains(".id(viewModel.selectedLeftSidebarTab)"))
    }

    @Test func componentDragSourceDoesNotUseTransferableTrackingSession() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/Theme.swift"),
            encoding: .utf8
        )
        let dragStart = try #require(source.range(of: "func xomoDraggable<Preview: View>"))
        let dragEnd = try #require(
            source[dragStart.upperBound...].range(of: "func xomoCanvasPlatformInteractions")
        )
        let dragSource = source[dragStart.lowerBound..<dragEnd.lowerBound]

        #expect(dragSource.contains("onDrag"))
        #expect(dragSource.contains("NSItemProvider(object: payload as NSString)"))
        #expect(!dragSource.contains("draggable(payload"))
    }

    @Test func canvasAcceptsFinderImageURLBatchesThroughTheAtomicLayerImporter() throws {
        let repositoryRoot = Self.repositoryRoot()
        let editorSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let themeSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/Theme.swift"),
            encoding: .utf8
        )
        let importSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorImport.swift"),
            encoding: .utf8
        )
        let interactionStart = try #require(
            editorSource.range(of: ".xomoCanvasPlatformInteractions(")
        )
        let interactionEnd = try #require(
            editorSource[interactionStart.upperBound...].range(of: "onMagnifyChanged:")
        )
        let interaction = editorSource[interactionStart.lowerBound..<interactionEnd.lowerBound]

        #expect(themeSource.contains("onFileDrop: @escaping ([URL], CGPoint) -> Bool"))
        let fileDropRegistrationCount = themeSource.components(
            separatedBy: "dropDestination(for: URL.self, action: onFileDrop)"
        ).count - 1
        #expect(fileDropRegistrationCount == 2)
        #expect(interaction.contains("onFileDrop: { urls, location in"))
        #expect(interaction.contains("ImageEditorLayerFileImportPolicy.supportedURLs(from: urls)"))
        #expect(interaction.contains("viewModel.importLayerFiles(urls, centeredAt: canvasPoint)"))
        #expect(importSource.contains("self.importLayerFiles(panel.urls)"))
        let batchStart = try #require(importSource.range(of: "func importLayerFiles("))
        let batchEnd = try #require(
            importSource[batchStart.upperBound...].range(of: "private func prepareLayerFileImport")
        )
        let batchSource = importSource[batchStart.lowerBound..<batchEnd.lowerBound]
        let preparation = try #require(batchSource.range(of: "for url in urls"))
        let transaction = try #require(batchSource.range(of: "pushUndo()"))
        #expect(preparation.lowerBound < transaction.lowerBound)
        #expect(batchSource.contains("document.layers.append(contentsOf: layers)"))
        #expect(batchSource.contains(
            "selectImportedLayers(layers.map(\\.id), primaryLayerID: layers.last?.id)"
        ))

        let selectionStart = try #require(
            importSource.range(of: "private func selectImportedLayers(")
        )
        let selectionEnd = try #require(
            importSource[selectionStart.upperBound...].range(of: "@discardableResult")
        )
        let selectionSource = importSource[
            selectionStart.lowerBound..<selectionEnd.lowerBound
        ]
        #expect(selectionSource.contains("document.selectedLayerID = primaryLayerID"))
        #expect(selectionSource.contains("document.selectedLayerIDs = Set(layerIDs)"))
        #expect(selectionSource.contains("selectedHotspotID = nil"))
        #expect(selectionSource.contains("if exportSettings.scope == .slice"))
    }

    @Test func propertiesPanelPartitionsLargeViewBuilderForReleaseRuntime() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let panelStart = try #require(
            source.range(of: "private func propertiesPanel(showsTitle: Bool = true) -> some View")
        )
        let panelEnd = try #require(
            source[panelStart.upperBound...].range(of: "private func smartFilterRow")
        )
        let panelSource = source[panelStart.lowerBound..<panelEnd.lowerBound]
        let partitionCount = panelSource.components(
            separatedBy: "\n                AnyView(Group {\n"
        ).count - 1

        // Keep each opaque SwiftUI metadata subtree comfortably below the
        // runtime recursion limit. Layer-style controls continue to grow, so
        // this is deliberately a lower bound rather than a frozen count.
        #expect(partitionCount >= 9)
        #expect(panelSource.contains("AnyView(Group {"))
        #expect(source.contains("private var adjustmentValueControls: AnyView"))
        #expect(panelSource.contains("selectedLayerTransformControls"))
        #expect(panelSource.contains("image-editor-layer-style-global-light-angle"))
        #expect(panelSource.contains("image-editor-layer-style-inner-glow-range"))
        #expect(panelSource.contains("image-editor-layer-style-bevel-angle"))
        #expect(panelSource.contains("imageEditor.action.flipV"))
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
        let viewSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let compatibilitySource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/Theme.swift"),
            encoding: .utf8
        )
        #expect(viewSource.contains(".xomoCanvasPlatformInteractions("))
        #expect(viewSource.contains("onMagnifyChanged: { magnification, location in"))
        #expect(viewSource.contains("viewModel.magnifyCanvas("))
        #expect(viewSource.contains("at: location ?? CGPoint("))
        #expect(viewSource.contains("viewportSize: geometry.size"))
        #expect(viewSource.contains("viewModel.endCanvasMagnify()"))
        #expect(compatibilitySource.contains("if #available(macOS 14.0, *)"))
        #expect(compatibilitySource.contains("MagnifyGesture()"))
        #expect(compatibilitySource.contains("onMagnifyChanged(value.magnification, value.startLocation)"))
        #expect(compatibilitySource.contains("} else if #available(macOS 13.0, *)"))
        #expect(compatibilitySource.contains("MagnificationGesture()"))
        #expect(compatibilitySource.contains("onMagnifyChanged(value, nil)"))
        #expect(compatibilitySource.contains("onMagnifyEnded()"))
    }

    @Test func canvasPublishesItsAutomationIdentifierAsAnAccessibilityContainer() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let canvasStart = try #require(
            source.range(of: ".coordinateSpace(name: \"image-editor-canvas-space\")")
        )
        let canvasEnd = try #require(
            source[canvasStart.upperBound...].range(of: ".xomoCanvasPlatformInteractions(")
        )
        let canvasSemantics = source[canvasStart.lowerBound..<canvasEnd.lowerBound]

        let container = try #require(canvasSemantics.range(of: ".accessibilityElement(children: .contain)"))
        let label = try #require(canvasSemantics.range(of: ".accessibilityLabel(L10n.text(\"imageEditor.accessibility.canvas\"))"))
        let value = try #require(canvasSemantics.range(of: ".accessibilityValue(L10n.format("))
        let identifier = try #require(canvasSemantics.range(of: ".accessibilityIdentifier(\"image-editor-canvas\")"))
        #expect(container.lowerBound < label.lowerBound)
        #expect(label.lowerBound < value.lowerBound)
        #expect(value.lowerBound < identifier.lowerBound)
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
        let nativeRangeStart = try #require(source.range(of: "onRangeToolDragBegan:"))
        let objectMoveStart = try #require(
            source[nativeRangeStart.upperBound...].range(of: "onObjectMoveCandidateBegan:")
        )
        let nativeRangeSource = source[nativeRangeStart.lowerBound..<objectMoveStart.lowerBound]
        #expect(nativeRangeSource.contains("onRangeToolDragChanged:"))
        #expect(nativeRangeSource.contains("onRangeToolDragEnded:"))
        #expect(nativeRangeSource.contains("viewModel.createMarqueeSelection("))
        #expect(nativeRangeSource.contains("viewModel.drawGradient("))
        #expect(nativeRangeSource.contains("canvasInteractionTool == .gradient"))
        #expect(nativeRangeSource.contains("to: gradientDragPoint(from: location, in: geometry.size)"))
        #expect(nativeRangeSource.contains("dragEnd = rawGradientPoint"))
        #expect(source.contains("dragEnd = rawGradientPoint"))
        #expect(source.contains("let displayedDragEnd = canvasInteractionTool == .gradient"))
        #expect(source.contains("? constrainedGradientEndpoint(dragEnd)"))
        #expect(source.contains("if let dragStart {\n                        viewModel.drawGradient("))
        #expect(source.contains("constrainedToAngleIncrement: canvasModifierFlags.contains(.shift)"))
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
        #expect(source.contains("state: viewModel.selectedLayerOuterGlowColorState"))
        #expect(source.contains("selection: selectedLayerOuterGlowColorBinding"))
        #expect(source.contains("state: viewModel.selectedLayerInnerGlowColorState"))
        #expect(source.contains("selection: selectedLayerInnerGlowColorBinding"))
        #expect(source.contains("ColorPicker(\"\", selection: selectedLayerColorOverlayColorBinding, supportsOpacity: false)"))
        #expect(source.contains("ColorPicker(\"\", selection: selectedLayerSatinColorBinding, supportsOpacity: false)"))
        #expect(source.contains("state: viewModel.selectedLayerStrokeGradientStartColorState"))
        #expect(source.contains("selection: selectedLayerStrokeGradientStartColorBinding"))
        #expect(source.contains("image-editor-layer-style-stroke-gradient-start-color"))
        #expect(source.contains("state: viewModel.selectedLayerStrokeGradientEndColorState"))
        #expect(source.contains("selection: selectedLayerStrokeGradientEndColorBinding"))
        #expect(source.contains("image-editor-layer-style-stroke-gradient-end-color"))
        #expect(source.contains("state: viewModel.selectedLayerStrokePatternColorState"))
        #expect(source.contains("selection: selectedLayerStrokePatternColorBinding"))
        #expect(source.contains("image-editor-layer-style-stroke-pattern-color"))
        #expect(source.contains("ColorPicker(\"\", selection: selectedLayerGradientOverlayStartColorBinding, supportsOpacity: false)"))
        #expect(source.contains("ColorPicker(\"\", selection: selectedLayerGradientOverlayEndColorBinding, supportsOpacity: false)"))
        #expect(source.contains("state: viewModel.selectedLayerPatternOverlayColorState"))
        #expect(source.contains("selection: selectedLayerPatternOverlayColorBinding"))
        #expect(source.contains("state: viewModel.selectedLayerBevelHighlightColorState"))
        #expect(source.contains("selection: selectedLayerBevelHighlightColorBinding"))
        #expect(source.contains("image-editor-layer-style-bevel-highlight-color"))
        #expect(source.contains("state: viewModel.selectedLayerBevelShadowColorState"))
        #expect(source.contains("selection: selectedLayerBevelShadowColorBinding"))
        #expect(source.contains("image-editor-layer-style-bevel-shadow-color"))
        #expect(source.contains("viewModel.setSelectedLayerStrokeColor(NSColor(value))"))
        #expect(source.contains("viewModel.setSelectedLayerShadowColor(NSColor(value))"))
        #expect(source.contains("viewModel.setSelectedLayerOuterGlowColor(NSColor(value))"))
        #expect(source.contains("viewModel.setSelectedLayerInnerGlowColor(NSColor(value))"))
        #expect(source.contains("viewModel.setSelectedLayerColorOverlayColor(NSColor(value))"))
        #expect(source.contains("viewModel.setSelectedLayerSatinColor(NSColor(value))"))
        #expect(source.contains("viewModel.setSelectedLayerStrokeGradientStartColor(NSColor(value))"))
        #expect(source.contains("viewModel.setSelectedLayerStrokeGradientEndColor(NSColor(value))"))
        #expect(source.contains("viewModel.setSelectedLayerStrokePatternColor(NSColor(value))"))
        #expect(source.contains("viewModel.setSelectedLayerGradientOverlayStartColor(NSColor(value))"))
        #expect(source.contains("viewModel.setSelectedLayerGradientOverlayEndColor(NSColor(value))"))
        #expect(source.contains("viewModel.setSelectedLayerPatternOverlayColor(NSColor(value))"))
        #expect(source.contains("viewModel.setSelectedLayerBevelHighlightColor(NSColor(value))"))
        #expect(source.contains("viewModel.setSelectedLayerBevelShadowColor(NSColor(value))"))
    }

    @MainActor
    @Test func classicFilterMenuSelectionsPreparePropertiesPanel() {
        let image = NSImage(size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.isPropertiesPanelVisible = false
        let initialPresentationRequest = viewModel.filterPanelPresentationRequest
        viewModel.selectFilter(.unsharpMask)

        #expect(viewModel.selectedFilter == .unsharpMask)
        #expect(viewModel.filterPanelPresentationRequest == initialPresentationRequest + 1)
        #expect(viewModel.isPropertiesPanelVisible)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.filterReady", ImageEditorFilter.unsharpMask.title))

        viewModel.selectFilter(.unsharpMask)
        #expect(viewModel.selectedFilter == .unsharpMask)
        #expect(viewModel.filterPanelPresentationRequest == initialPresentationRequest + 2)
    }

    @Test func filterPresentationRequestAlwaysExpandsQuickControls() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(source.contains(".onChange(of: viewModel.filterPanelPresentationRequest)"))
        #expect(source.contains("isFiltersDockExpanded = true"))
    }

    @Test func filterQuickControlsExposeStableAccessibilityWithoutKeyboardFocus() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let controlSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorDarkPanelControls.swift"),
            encoding: .utf8
        )
        let filterStart = try #require(source.range(of: "private var filtersQuickPanel: some View"))
        let filterEnd = try #require(source[filterStart.upperBound...].range(of: "private func historySnapshotRow"))
        let filterSource = source[filterStart.lowerBound..<filterEnd.lowerBound]

        #expect(filterSource.contains("image-editor-filter-picker"))
        #expect(filterSource.contains("image-editor-filter-intensity"))
        #expect(filterSource.contains("accessibilityLabel(L10n.text(\"imageEditor.option.strength\"))"))
        #expect(filterSource.contains("image-editor-filter-apply"))
        #expect(filterSource.contains("image-editor-filter-layer-new"))
        #expect(filterSource.contains("image-editor-filter-smart-add"))
        #expect(filterSource.components(separatedBy: ".focusable(false)").count - 1 == 5)
        #expect(controlSource.contains("final class ImageEditorFilterPopUpButton: NSPopUpButton"))
        #expect(controlSource.contains("final class ImageEditorFilterPickerHost: NSView"))
        #expect(controlSource.components(separatedBy: "override var acceptsFirstResponder: Bool { false }").count - 1 >= 3)
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

    @Test func compactToolRailExposesPreviewAndVisibleColorControls() throws {
        let viewSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let menuSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )

        #expect(viewSource.contains(".fixed(imageEditorToolButtonHitSize)"))
        #expect(viewSource.contains("count: imageEditorToolGridColumnCount"))
        #expect(viewSource.contains(".frame(width: imageEditorToolRailWidth)"))
        #expect(viewSource.contains("ImageEditorColorWell("))
        #expect(viewSource.contains("image-editor-foreground-color-well"))
        #expect(viewSource.contains("image-editor-background-color-well"))
        #expect(viewSource.contains("image-editor-color-swap"))
        #expect(!viewSource.contains("viewModel.sampleScreenColorForForeground"))
        #expect(!viewSource.contains("viewModel.sampleScreenColorForBackground"))
        #expect(viewSource.contains(".onHover { isHovered = $0 }"))
        #expect(viewSource.contains(".focusable(false)"))
        #expect(menuSource.contains("Button(L10n.text(\"imageEditor.action.preview\"))"))
        #expect(menuSource.contains("viewModel.openPreviewPanel()"))
        #expect(menuSource.contains(".accessibilityIdentifier(\"image-editor-action-preview\")"))
        #expect(menuSource.contains(".accessibilityLabel(L10n.text(\"imageEditor.action.preview\"))"))
        #expect(!menuSource.contains("Button(L10n.text(\"imageEditor.action.preview\")) {\n                viewModel.applyAndClose"))
    }

    @Test func previewPanelWiresThreeNonDestructiveBackdropModes() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent(
                "veilpic/ImageEditorExportPanel.swift"
            ),
            encoding: .utf8
        )
        let viewModelSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent(
                "veilpic/ImageEditorViewModel.swift"
            ),
            encoding: .utf8
        )

        let previewStart = try #require(source.range(of: "struct ImageEditorPreviewPanel: View"))
        let previewEnd = try #require(
            source[previewStart.upperBound...].range(of: "struct ImageEditorExportPanel: View")
        )
        let previewSource = source[previewStart.lowerBound..<previewEnd.lowerBound]
        #expect(source.contains("case checkerboard\n    case white\n    case black"))
        #expect(source.contains("ImageEditorPreviewBackdropView(backdrop: viewModel.previewBackdrop)"))
        #expect(previewSource.contains("selection: $viewModel.previewBackdrop"))
        #expect(previewSource.contains("ForEach(ImageEditorPreviewBackdrop.allCases)"))
        #expect(previewSource.contains(".accessibilityIdentifier(\"image-editor-preview-background\")"))
        #expect(previewSource.contains("ZStack"))
        #expect(viewModelSource.contains(
            "@Published var previewBackdrop: ImageEditorPreviewBackdrop = .checkerboard"
        ))

        for locale in ["en", "ja", "zh-Hans"] {
            let localization = try String(
                contentsOf: Self.repositoryRoot().appendingPathComponent(
                    "veilpic/\(locale).lproj/Localizable.strings"
                ),
                encoding: .utf8
            )
            #expect(localization.contains("\"imageEditor.preview.background\""))
            #expect(localization.contains("\"imageEditor.preview.background.checkerboard\""))
            #expect(localization.contains("\"imageEditor.preview.background.white\""))
            #expect(localization.contains("\"imageEditor.preview.background.black\""))
        }
    }

    @Test func previewPanelWiresFitAndPixelInspectionZoomModes() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent(
                "veilpic/ImageEditorExportPanel.swift"
            ),
            encoding: .utf8
        )
        let viewModelSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent(
                "veilpic/ImageEditorViewModel.swift"
            ),
            encoding: .utf8
        )

        let previewStart = try #require(source.range(of: "struct ImageEditorPreviewPanel: View"))
        let previewEnd = try #require(
            source[previewStart.upperBound...].range(of: "struct ImageEditorExportPanel: View")
        )
        let previewSource = source[previewStart.lowerBound..<previewEnd.lowerBound]
        #expect(source.contains("case fit\n    case actualPixels\n    case doublePixels"))
        #expect(previewSource.contains("selection: $viewModel.previewZoomMode"))
        #expect(previewSource.contains("ForEach(ImageEditorPreviewZoomMode.allCases)"))
        #expect(previewSource.contains(".accessibilityIdentifier(\"image-editor-preview-zoom\")"))
        #expect(previewSource.contains("ScrollView([.horizontal, .vertical])"))
        #expect(previewSource.contains("viewModel.previewZoomMode.usesScrollablePixelCanvas"))
        #expect(previewSource.contains("viewModel.previewZoomMode.interpolation"))
        #expect(source.contains("usesScrollablePixelCanvas ? .none : .high"))
        #expect(previewSource.contains("viewModel.document.canvasSize"))
        #expect(viewModelSource.contains(
            "@Published var previewZoomMode: ImageEditorPreviewZoomMode = .fit"
        ))

        for locale in ["en", "ja", "zh-Hans"] {
            let localization = try String(
                contentsOf: Self.repositoryRoot().appendingPathComponent(
                    "veilpic/\(locale).lproj/Localizable.strings"
                ),
                encoding: .utf8
            )
            #expect(localization.contains("\"imageEditor.preview.zoom\""))
            #expect(localization.contains("\"imageEditor.preview.zoom.fit\""))
            #expect(localization.contains("\"imageEditor.preview.zoom.actualPixels\""))
            #expect(localization.contains("\"imageEditor.preview.zoom.doublePixels\""))
        }
    }

    @Test func previewPanelWiresNonDestructivePixelInspection() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent(
                "veilpic/ImageEditorExportPanel.swift"
            ),
            encoding: .utf8
        )
        let previewStart = try #require(source.range(of: "struct ImageEditorPreviewPanel: View"))
        let previewEnd = try #require(
            source[previewStart.upperBound...].range(of: "struct ImageEditorExportPanel: View")
        )
        let previewSource = source[previewStart.lowerBound..<previewEnd.lowerBound]

        #expect(source.contains("struct ImageEditorPreviewPixelSample"))
        #expect(source.contains("enum ImageEditorPreviewPixelSampleSize"))
        #expect(source.contains("enum ImageEditorPreviewPixelReadoutMode"))
        #expect(source.contains("enum ImageEditorPreviewClipboard"))
        #expect(source.contains("struct ImageEditorPreviewPinnedSamples"))
        #expect(source.contains("struct ImageEditorPreviewMarkerDragTarget"))
        #expect(source.contains("enum ImageEditorPreviewMarkerDragConstraint"))
        #expect(source.contains("enum ImageEditorPreviewMarkerTapAction: Equatable"))
        #expect(source.contains("enum ImageEditorPreviewMarkerCursor"))
        #expect(source.contains("enum ImageEditorPreviewMarkerModifierFlags"))
        #expect(source.contains("private struct ImageEditorPreviewModifierFlagsMonitor"))
        #expect(source.contains("struct ImageEditorPreviewSampleMeasurement"))
        #expect(source.contains("struct ImageEditorPreviewSampleMeasurementSelection"))
        #expect(source.contains("struct ImageEditorPreviewSampleMeasurementGuide"))
        #expect(source.contains("static let maximumCount = 4"))
        #expect(source.contains("func markerNumber("))
        #expect(source.contains("mutating func move("))
        #expect(source.contains("mutating func selectDestination("))
        #expect(source.contains("var latestMeasurement: ImageEditorPreviewSampleMeasurement?"))
        #expect(source.contains("mutating func setReadoutMode("))
        #expect(source.contains("mutating func resample("))
        #expect(source.contains("pasteboard.setString(value, forType: .string)"))
        #expect(source.contains("static func canvasPoint("))
        #expect(source.contains("func displayedCenter("))
        #expect(source.contains("static func resolved(live:"))
        #expect(source.contains("private static func sampledColor("))
        #expect(source.contains("let bitmap = NSBitmapImageRep(cgImage: cgImage)"))
        #expect(source.contains("image.color("))
        #expect(previewSource.contains("@State private var pixelSample"))
        #expect(previewSource.contains("@State private var pinnedPixelSamples"))
        #expect(previewSource.contains("@State private var markerDragTarget"))
        #expect(previewSource.contains("@State private var hoveredPinnedSampleNumber"))
        #expect(previewSource.contains("@State private var previewModifierFlags"))
        #expect(previewSource.contains("@State private var measurementSelection"))
        #expect(previewSource.contains("@State private var pixelSampleSize"))
        #expect(previewSource.contains("@State private var pixelReadoutMode"))
        #expect(previewSource.contains("@State private var copiedPreviewText"))
        #expect(previewSource.contains("selection: $pixelSampleSize"))
        #expect(previewSource.contains("ForEach(ImageEditorPreviewPixelSampleSize.allCases)"))
        #expect(previewSource.contains(
            ".accessibilityIdentifier(\"image-editor-preview-sample-size\")"
        ))
        #expect(previewSource.contains("selection: $pixelReadoutMode"))
        #expect(previewSource.contains("ForEach(ImageEditorPreviewPixelReadoutMode.allCases)"))
        #expect(previewSource.contains(
            ".accessibilityIdentifier(\"image-editor-preview-readout-mode\")"
        ))
        #expect(previewSource.contains("displayedPixelSample.text(mode: pixelReadoutMode)"))
        #expect(previewSource.contains("SpatialTapGesture().onEnded"))
        #expect(previewSource.contains("minimumDistance: Self.markerDragMinimumDistance"))
        #expect(previewSource.contains("markerDragTarget.resolve("))
        #expect(previewSource.contains("startingAt: value.startLocation"))
        #expect(previewSource.contains("ImageEditorPreviewMarkerDragConstraint.location("))
        #expect(previewSource.contains("proposedLocation: value.location"))
        #expect(previewSource.contains("modifierFlags: NSEvent.modifierFlags"))
        #expect(previewSource.contains("ImageEditorCursorRectView(cursor: previewMarkerCursor)"))
        #expect(previewSource.contains("hoveredPinnedSampleNumber = pinnedPixelSamples.markerNumber("))
        #expect(previewSource.contains("ImageEditorPreviewMarkerModifierFlags.tracked("))
        #expect(previewSource.contains("draggedMarkerNumber: markerDragTarget.number"))
        #expect(previewSource.contains("ImageEditorPreviewModifierFlagsMonitor { modifierFlags in"))
        #expect(source.contains("NSEvent.addLocalMonitorForEvents(matching: .flagsChanged)"))
        #expect(source.contains("guard let window, event.window === window else { return }"))
        #expect(source.contains("forName: NSApplication.didResignActiveNotification"))
        #expect(source.contains("forName: NSWindow.didResignKeyNotification"))
        #expect(previewSource.contains("location: location"))
        #expect(previewSource.contains("movePinnedSample(number: markerNumber, to: sample)"))
        #expect(previewSource.contains(".onEnded { value in\n                markerDragTarget.reset()"))
        #expect(previewSource.contains("let markerNumber = pinnedPixelSamples.markerNumber("))
        #expect(previewSource.contains("switch ImageEditorPreviewMarkerTapAction.resolve("))
        #expect(previewSource.contains("modifierFlags: NSEvent.modifierFlags"))
        #expect(previewSource.contains("case let .remove(markerNumber):"))
        #expect(previewSource.contains("measurementSelection.selectDestination("))
        #expect(previewSource.contains("removePinnedSample(number: markerNumber)"))
        #expect(
            previewSource.components(separatedBy: "removePinnedSample(number:").count == 4
        )
        #expect(previewSource.contains("isMeasurementDestination(pinnedSample.number)"))
        #expect(previewSource.contains(
            "pinnedPixelSamples.pin(sample, readoutMode: pixelReadoutMode)"
        ))
        #expect(previewSource.contains("ForEach(pinnedPixelSamples.entries)"))
        #expect(previewSource.contains("pinnedSample.sample.displayedCenter("))
        #expect(previewSource.contains("pinnedSample.number"))
        #expect(previewSource.contains("pinnedPixelSamples.remove(number:"))
        #expect(previewSource.contains(
            ".accessibilityIdentifier(\"image-editor-preview-pinned-samples\")"
        ))
        #expect(previewSource.contains("image-editor-preview-remove-pinned-sample-"))
        #expect(previewSource.contains(
            ".accessibilityIdentifier(\"image-editor-preview-clear-pinned-sample\")"
        ))
        #expect(previewSource.contains("ImageEditorPreviewClipboard.copy(value)"))
        #expect(previewSource.contains(
            "pinnedSample.sample.text(mode: pinnedSample.readoutMode)"
        ))
        #expect(previewSource.contains(
            "pinnedSample.sample.valueText(mode: readoutMode)"
        ))
        #expect(previewSource.contains("mode ?? pinnedSample.readoutMode"))
        #expect(previewSource.contains(
            "copyReadout(for: pinnedSample, mode: pixelReadoutMode)"
        ))
        #expect(previewSource.contains("selection: readoutModeBinding(for: pinnedSample.number)"))
        #expect(previewSource.contains("pinnedPixelSamples.setReadoutMode(readoutMode, for: number)"))
        #expect(previewSource.contains("image-editor-preview-pinned-sample-mode-"))
        #expect(previewSource.contains("measurementSelection.measurement(in: pinnedPixelSamples)"))
        #expect(previewSource.contains("selection: measurementFromBinding"))
        #expect(previewSource.contains("selection: measurementToBinding"))
        #expect(previewSource.contains("measurementSelection.setFrom(number, in: pinnedPixelSamples)"))
        #expect(previewSource.contains("measurementSelection.setTo(number, in: pinnedPixelSamples)"))
        #expect(previewSource.contains("measurementSelection.selectLatest(in: pinnedPixelSamples)"))
        #expect(previewSource.contains("measurementSelection.reconcile(in: pinnedPixelSamples)"))
        #expect(previewSource.contains("Text(measurement.valuesText)"))
        #expect(previewSource.contains("copyMeasurement(measurement)"))
        #expect(previewSource.contains("isCopied(measurement)"))
        #expect(previewSource.contains(
            ".accessibilityIdentifier(\"image-editor-preview-copy-measurement\")"
        ))
        #expect(previewSource.contains("if measurementSelection.setFrom("))
        #expect(previewSource.contains("if measurementSelection.setTo("))
        #expect(previewSource.contains("ImageEditorPreviewSampleMeasurementGuide("))
        #expect(previewSource.contains("path.move(to: guide.fromCenter)"))
        #expect(previewSource.contains("path.addLine(to: guide.toCenter)"))
        #expect(previewSource.contains("path.addLine(to: guide.orthogonalCorner)"))
        #expect(previewSource.contains("if guide.showsOrthogonalComponents"))
        #expect(previewSource.contains("guide.distanceLabelCenter"))
        #expect(previewSource.contains("guide.horizontalLabelCenter"))
        #expect(previewSource.contains("guide.verticalLabelCenter"))
        #expect(previewSource.contains("measurementBadge(guide.distanceText"))
        #expect(previewSource.contains("measurementBadge(guide.deltaXText"))
        #expect(previewSource.contains("measurementBadge(guide.deltaYText"))
        #expect(previewSource.contains("image-editor-preview-measurement-guide"))
        #expect(previewSource.contains(".allowsHitTesting(false)"))
        #expect(previewSource.contains("isMeasurementEndpoint(pinnedSample.number)"))
        #expect(previewSource.contains("image-editor-preview-measurement-from"))
        #expect(previewSource.contains("image-editor-preview-measurement-to"))
        #expect(previewSource.contains(
            ".accessibilityIdentifier(\"image-editor-preview-pinned-sample-measurement\")"
        ))
        #expect(previewSource.contains(
            ".accessibilityIdentifier(\"image-editor-preview-copy-pinned-sample\")"
        ))
        #expect(previewSource.contains(".onContinuousHover"))
        #expect(previewSource.contains("ImageEditorPreviewPixelSample.sample("))
        #expect(previewSource.contains("sampleSize: pixelSampleSize"))
        #expect(previewSource.contains("case .ended:\n                pixelSample = nil"))
        #expect(previewSource.contains(".accessibilityIdentifier(\"image-editor-preview-inspector\")"))
        #expect(previewSource.contains(".accessibilityIdentifier(\"image-editor-preview-pixel-sample\")"))

        let sampleSizeChangeStart = try #require(
            previewSource.range(of: ".onChange(of: pixelSampleSize) { sampleSize in")
        )
        let sampleSizeChangeEnd = try #require(
            previewSource[sampleSizeChangeStart.upperBound...].range(of: ".onDisappear {")
        )
        let sampleSizeChangeSource = previewSource[
            sampleSizeChangeStart.lowerBound..<sampleSizeChangeEnd.lowerBound
        ]
        #expect(sampleSizeChangeSource.contains("canvasPoint: currentPoint"))
        #expect(sampleSizeChangeSource.contains("pinnedPixelSamples.resample("))
        #expect(!sampleSizeChangeSource.contains("pinnedPixelSamples.removeAll()"))
        #expect(!sampleSizeChangeSource.contains("measurementSelection.reset()"))

        let markerTap = try #require(
            previewSource.range(of: "let markerNumber = pinnedPixelSamples.markerNumber(")
        )
        let sampleAfterMarkerTap = try #require(
            previewSource[markerTap.upperBound...].range(
                of: "let sample = ImageEditorPreviewPixelSample.sample("
            )
        )
        #expect(markerTap.lowerBound < sampleAfterMarkerTap.lowerBound)

        for locale in ["en", "ja", "zh-Hans"] {
            let localization = try String(
                contentsOf: Self.repositoryRoot().appendingPathComponent(
                    "veilpic/\(locale).lproj/Localizable.strings"
                ),
                encoding: .utf8
            )
            #expect(localization.contains("\"imageEditor.preview.dimensions\""))
            #expect(localization.contains("\"imageEditor.preview.sample\""))
            #expect(localization.contains("\"imageEditor.preview.sample.empty\""))
            #expect(localization.contains("\"imageEditor.preview.sample.pinHelp\""))
            #expect(localization.contains("\"imageEditor.preview.sample.pinned\""))
            #expect(localization.contains("\"imageEditor.preview.sample.number\""))
            #expect(localization.contains("\"imageEditor.preview.sample.measurement\""))
            #expect(localization.contains("\"imageEditor.preview.sample.measurementValues\""))
            #expect(localization.contains("\"imageEditor.preview.sample.measurementDistance\""))
            #expect(localization.contains("\"imageEditor.preview.sample.measurementDeltaX\""))
            #expect(localization.contains("\"imageEditor.preview.sample.measurementDeltaY\""))
            #expect(localization.contains("\"imageEditor.preview.sample.measurementFrom\""))
            #expect(localization.contains("\"imageEditor.preview.sample.measurementTo\""))
            #expect(localization.contains("\"imageEditor.preview.sample.copyMeasurement\""))
            #expect(localization.contains("\"imageEditor.preview.sample.measurementCopied\""))
            #expect(localization.contains("\"imageEditor.preview.sample.copy\""))
            #expect(localization.contains("\"imageEditor.preview.sample.copied\""))
            #expect(localization.contains("\"imageEditor.preview.sample.clearPinned\""))
            #expect(localization.contains("\"imageEditor.preview.sample.clearAllPinned\""))
            #expect(localization.contains("\"imageEditor.preview.sample.removePinned\""))
            #expect(localization.contains("\"imageEditor.preview.sampleSize\""))
            #expect(localization.contains("\"imageEditor.preview.sampleSize.point\""))
            #expect(localization.contains("\"imageEditor.preview.sampleSize.average3\""))
            #expect(localization.contains("\"imageEditor.preview.sampleSize.average5\""))
            #expect(localization.contains("\"imageEditor.preview.readoutMode\""))
            #expect(localization.contains("\"imageEditor.preview.readoutMode.hexadecimalRGBA\""))
            #expect(localization.contains("\"imageEditor.preview.readoutMode.rgb\""))
            #expect(localization.contains("\"imageEditor.preview.readoutMode.hsb\""))
            #expect(localization.contains("\"imageEditor.preview.readoutMode.cmyk\""))
            #expect(localization.contains("\"imageEditor.preview.readout.rgb\""))
            #expect(localization.contains("\"imageEditor.preview.readout.hsb\""))
            #expect(localization.contains("\"imageEditor.preview.readout.cmyk\""))
        }
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
    @Test func classicArrowNudgeShortcutsMoveSelectedLayerWithoutSelection() throws {
        let image = try #require(NSImage.rendered(size: NSSize(width: 80, height: 60)) { rect in
            NSColor.systemBlue.setFill()
            rect.fill()
        })
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let backgroundID = try #require(viewModel.document.layers.first?.id)
        viewModel.selectLayer(backgroundID)
        viewModel.convertBackgroundToLayer()

        let selectedLayerID = viewModel.document.selectedLayerID
        let originalFrame = try #require(viewModel.document.layers.first { $0.id == selectedLayerID }?.frame)

        viewModel.nudgeSelectionOrSelectedLayer(by: CGSize(width: -10, height: 0))
        let movedFrame = viewModel.document.layers.first { $0.id == selectedLayerID }?.frame

        #expect(movedFrame?.origin.x == originalFrame.origin.x - 10)
        #expect(movedFrame?.origin.y == originalFrame.origin.y)
        #expect(viewModel.document.selection == nil)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerTranslate"))
    }

    @MainActor
    @Test func classicDeleteShortcutClearsSelectionPixelsThroughExistingCommand() throws {
        let image = try #require(NSImage.rendered(size: NSSize(width: 80, height: 60)) { rect in
            NSColor.systemRed.setFill()
            rect.fill()
        })
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let backgroundID = try #require(viewModel.document.layers.first?.id)
        viewModel.selectLayer(backgroundID)
        viewModel.convertBackgroundToLayer()
        viewModel.document.selection = ImageEditorSelection.rectangle(CGRect(x: 10, y: 10, width: 20, height: 20))

        #expect(viewModel.canRemoveSelectionPixels)
        viewModel.clearSelectionPixels()

        let clearedColor = viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 15, y: 15))
        let retainedColor = viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 2, y: 2))
        #expect((clearedColor?.alphaComponent ?? 1) < 0.05)
        #expect((retainedColor?.alphaComponent ?? 0) > 0.95)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionClearPixels"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionPixelsCleared"))
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

        #expect(source.contains("leftSidebar\n                        .fixedSize(horizontal: true, vertical: false)\n                        .layoutPriority(2)"))
        #expect(source.contains("canvasWorkspace\n                    .frame(minWidth: 0)"))
        #expect(source.contains("canvasWorkspace\n                    .frame(minWidth: 0)\n                    .clipped()\n                    .layoutPriority(0)"))
        #expect(source.contains("rightDock\n                        .fixedSize(horizontal: true, vertical: false)\n                        .layoutPriority(2)"))

        let dockStart = try #require(source.range(of: "private var rightDock: some View"))
        let dockEnd = try #require(source[dockStart.upperBound...].range(of: "private func navigatorPanel"))
        let dockSource = source[dockStart.lowerBound..<dockEnd.lowerBound]
        #expect(dockSource.contains("VStack(spacing: 8)"))
        #expect(!dockSource.contains("LazyVStack"))
        #expect(dockSource.contains(".frame(width: imageEditorRightDockWidth)"))
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
        #expect(shortcutSource.contains(".keyboardShortcut(\"=\", modifiers: [.option, .shift])"))
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
        let image = try #require(NSImage.rendered(size: NSSize(width: 80, height: 60)) { rect in
            NSColor.systemGreen.setFill()
            rect.fill()
        })
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let selectedLayerID = try #require(viewModel.document.layers.first?.id)
        viewModel.selectLayer(selectedLayerID)
        let persistedFrame = try #require(
            viewModel.document.layers.first { $0.id == selectedLayerID }?.frame
        )
        let selectedFrame = try #require(viewModel.selectedLayerTransformFrame)

        viewModel.toggleTransformControlsVisible()

        #expect(!viewModel.document.areTransformControlsVisible)
        #expect(viewModel.selectedLayerTransformFrame == selectedFrame)
        #expect(viewModel.document.layers.first { $0.id == selectedLayerID }?.frame == persistedFrame)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.transformControlsVisibility"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.transformControlsHidden"))

        viewModel.toggleTransformControlsVisible()
        #expect(viewModel.document.areTransformControlsVisible)
        #expect(viewModel.selectedLayerTransformFrame == selectedFrame)
        #expect(viewModel.document.layers.first { $0.id == selectedLayerID }?.frame == persistedFrame)

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
        let menuBarSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let commandsSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/XomoApplicationCommands.swift"),
            encoding: .utf8
        )

        #expect(menuBarSource.contains("openProjectDocumentSafely()"))
        #expect(commandsSource.contains(".keyboardShortcut(\"o\", modifiers: [.command])"))
        #expect(menuBarSource.contains("viewModel.saveProjectDocument()"))
        #expect(commandsSource.contains(".keyboardShortcut(\"s\", modifiers: [.command])"))
        #expect(menuBarSource.contains("viewModel.openExportPanel()"))
        #expect(commandsSource.contains(".keyboardShortcut(\"s\", modifiers: [.command, .shift, .option])"))
        #expect(commandsSource.contains("imageEditor.action.fileImport"))
        #expect(menuBarSource.contains("viewModel.chooseImageLayerFile()"))
    }

    @Test func layerMenuExposesSelectionLayerCommandsInPhotoshopStyleLocation() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let viewSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let layerMenuStart = try #require(source.range(of: "private var layerMenuItems: some View"))
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
        #expect(viewSource.contains("if key == \"j\", relevantFlags == [.command, .shift] { return .cutSelectionToLayer }"))
        #expect(viewSource.contains("case .cutSelectionToLayer: viewModel.cutSelectionToNewLayer()"))
    }

    @Test func clearSelectionControlsUseRemovalPermissionInsteadOfGeneralPixelEditing() throws {
        let menuSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let viewSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let commandSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent(
                "veilpic/XomoApplicationCommands.swift"
            ),
            encoding: .utf8
        )

        #expect(viewSource.contains("viewModel.clearSelectionPixels()"))
        #expect(viewSource.contains(".disabled(!viewModel.canRemoveSelectionPixels)"))
        #expect(menuSource.contains("canRemoveSelectionPixels: viewModel.canRemoveSelectionPixels"))
        #expect(menuSource.contains("canDeleteSelectedObject: ImageEditorContextualDocumentDeletePolicy.resolve("))
        #expect(commandSource.contains("actions?.deleteSelectedObject()"))
        #expect(commandSource.contains(".disabled(actions?.canDeleteSelectedObject != true)"))
    }

    @Test func layerMenuExposesClassicLayerShortcuts() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let viewSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let layerMenuStart = try #require(source.range(of: "private var layerMenuItems: some View"))
        let nextMenuStart = try #require(
            source[layerMenuStart.upperBound...].range(of: "private var layerSelectAttributeMenu: some View")
        )
        let layerMenuSource = source[layerMenuStart.lowerBound..<nextMenuStart.lowerBound]

        #expect(layerMenuSource.contains("performNewLayer()"))
        #expect(layerMenuSource.contains(".keyboardShortcut(\"n\", modifiers: [.command, .shift])"))
        #expect(layerMenuSource.contains("viewModel.duplicateSelectionOrSelectedLayer()"))
        #expect(layerMenuSource.contains("viewModel.canDuplicateSelectionOrSelectedLayer"))
        #expect(viewSource.contains("if key == \"j\", relevantFlags == [.command] { return .duplicateSelectionOrLayer }"))
        #expect(viewSource.contains("case .duplicateSelectionOrLayer: viewModel.duplicateSelectionOrSelectedLayer()"))
        #expect(layerMenuSource.contains("performGroupSelectedLayer()"))
        #expect(layerMenuSource.contains(".keyboardShortcut(\"g\", modifiers: [.command])"))
        #expect(layerMenuSource.contains("performUngroupSelectedLayers()"))
        #expect(layerMenuSource.contains(".keyboardShortcut(\"g\", modifiers: [.command, .shift])"))
        #expect(layerMenuSource.contains("performMergeDown()"))
        #expect(layerMenuSource.contains(".keyboardShortcut(\"e\", modifiers: [.command])"))
        #expect(layerMenuSource.contains("performMergeVisible()"))
        #expect(layerMenuSource.contains(".keyboardShortcut(\"e\", modifiers: [.command, .shift])"))
        #expect(layerMenuSource.contains("performStampVisible()"))
        #expect(layerMenuSource.contains(".keyboardShortcut(\"e\", modifiers: [.command, .shift, .option])"))

        let helperStart = try #require(viewSource.range(of: "func performNewLayer()"))
        let helperEnd = try #require(
            viewSource[helperStart.upperBound...].range(of: "\n    }")
        )
        let helperSource = viewSource[helperStart.lowerBound..<helperEnd.upperBound]
        let dispatchGate = try #require(
            helperSource.range(of: "ImageEditorNewLayerCommandDispatchGate.shouldDispatch")
        )
        let addLayer = try #require(helperSource.range(of: "viewModel.addLayer()"))
        #expect(dispatchGate.lowerBound < addLayer.lowerBound)
        #expect(viewSource.contains("case .newLayer: performNewLayer()"))

        for (helperName, action, modelCall) in [
            ("performGroupSelectedLayer", ".group", "viewModel.groupSelectedLayer()"),
            ("performUngroupSelectedLayers", ".ungroup", "viewModel.ungroupSelectedLayers()")
        ] {
            let start = try #require(viewSource.range(of: "func \(helperName)()"))
            let end = try #require(viewSource[start.upperBound...].range(of: "\n    }"))
            let source = viewSource[start.lowerBound..<end.upperBound]
            let dispatchGate = try #require(
                source.range(of: "ImageEditorLayerGroupingCommandDispatchGate.shouldDispatch")
            )
            let actionArgument = try #require(source.range(of: action))
            let mutation = try #require(source.range(of: modelCall))
            #expect(dispatchGate.lowerBound < actionArgument.lowerBound)
            #expect(actionArgument.lowerBound < mutation.lowerBound)
        }
        #expect(viewSource.contains("case .groupSelectedLayer: performGroupSelectedLayer()"))
        #expect(viewSource.contains("case .ungroupSelectedLayers: performUngroupSelectedLayers()"))

        for (helperName, action, modelCall) in [
            ("performMergeDown", ".mergeDown", "viewModel.mergeSelectedLayerDown()"),
            ("performStampVisible", ".stampVisible", "viewModel.stampVisibleLayers()"),
            ("performMergeVisible", ".mergeVisible", "viewModel.mergeVisibleLayers()")
        ] {
            let start = try #require(viewSource.range(of: "func \(helperName)()"))
            let end = try #require(viewSource[start.upperBound...].range(of: "\n    }"))
            let source = viewSource[start.lowerBound..<end.upperBound]
            let dispatchGate = try #require(
                source.range(of: "ImageEditorLayerMergeCommandDispatchGate.shouldDispatch")
            )
            let actionArgument = try #require(source.range(of: action))
            let mutation = try #require(source.range(of: modelCall))
            #expect(dispatchGate.lowerBound < actionArgument.lowerBound)
            #expect(actionArgument.lowerBound < mutation.lowerBound)
        }
        #expect(viewSource.contains("case .mergeDown: performMergeDown()"))
        #expect(viewSource.contains("case .stampVisible: performStampVisible()"))
        #expect(viewSource.contains("case .mergeVisible: performMergeVisible()"))

        for (helperName, action, modelCall) in [
            ("performLayerTop", ".top", "viewModel.moveSelectedLayerToTop(inVisibleOrder: filteredVisibleLayerRowIDs)"),
            ("performLayerUp", ".up", "viewModel.moveSelectedLayerUp(inVisibleOrder: filteredVisibleLayerRowIDs)"),
            ("performLayerDown", ".down", "viewModel.moveSelectedLayerDown(inVisibleOrder: filteredVisibleLayerRowIDs)"),
            ("performLayerBottom", ".bottom", "viewModel.moveSelectedLayerToBottom(inVisibleOrder: filteredVisibleLayerRowIDs)")
        ] {
            let start = try #require(viewSource.range(of: "func \(helperName)()"))
            let end = try #require(viewSource[start.upperBound...].range(of: "\n    }"))
            let source = viewSource[start.lowerBound..<end.upperBound]
            let dispatchGate = try #require(
                source.range(of: "ImageEditorLayerOrderCommandDispatchGate.shouldDispatch")
            )
            let actionArgument = try #require(source.range(of: action))
            let mutation = try #require(source.range(of: modelCall))
            #expect(dispatchGate.lowerBound < actionArgument.lowerBound)
            #expect(actionArgument.lowerBound < mutation.lowerBound)
        }
        #expect(viewSource.contains("case .layerTop: performLayerTop()"))
        #expect(viewSource.contains("case .layerUp: performLayerUp()"))
        #expect(viewSource.contains("case .layerDown: performLayerDown()"))
        #expect(viewSource.contains("case .layerBottom: performLayerBottom()"))
    }

    @Test func systemAndEditorLayerMenusShareOneFocusedCommandTree() throws {
        let menuBarSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let commandsSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/XomoApplicationCommands.swift"),
            encoding: .utf8
        )
        let appSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/veilpicApp.swift"),
            encoding: .utf8
        )
        let viewSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(commandsSource.contains("CommandMenu(L10n.text(\"imageEditor.menu.layer\"))"))
        #expect(commandsSource.contains("XomoFocusedMenuItems("))
        #expect(commandsSource.contains("content: content,"))
        #expect(menuBarSource.contains("var xomoLayerCommandContent: XomoFocusedMenuContent"))
        #expect(menuBarSource.contains("XomoFocusedMenuContent(menuItems: AnyView(layerMenuItems))"))
        #expect(menuBarSource.contains("private var layerMenuItems: some View"))
        #expect(appSource.contains("XomoLayerCommands()"))
        #expect(viewSource.contains(".focusedSceneValue(\\.xomoLayerCommandContent, xomoLayerCommandContent)"))
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

        #expect(orderMenuSource.contains("performLayerTop()"))
        #expect(orderMenuSource.contains(".keyboardShortcut(\"]\", modifiers: [.command, .shift])"))
        #expect(orderMenuSource.contains("performLayerUp()"))
        #expect(orderMenuSource.contains(".keyboardShortcut(\"]\", modifiers: [.command])"))
        #expect(orderMenuSource.contains("performLayerDown()"))
        #expect(orderMenuSource.contains(".keyboardShortcut(\"[\", modifiers: [.command])"))
        #expect(orderMenuSource.contains("performLayerBottom()"))
        #expect(orderMenuSource.contains(".keyboardShortcut(\"[\", modifiers: [.command, .shift])"))
    }

    @Test func imageMenuExposesClassicSizeShortcuts() throws {
        let menuBarSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let commandsSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/XomoApplicationCommands.swift"),
            encoding: .utf8
        )
        let appSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/veilpicApp.swift"),
            encoding: .utf8
        )
        let viewSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let sharedMenuStart = try #require(
            commandsSource.range(of: "struct XomoImageMenuItems: View")
        )
        let sharedMenuEnd = try #require(
            commandsSource[sharedMenuStart.upperBound...].range(of: "struct XomoFileMenuItems: View")
        )
        let imageMenuSource = commandsSource[sharedMenuStart.lowerBound..<sharedMenuEnd.lowerBound]

        #expect(imageMenuSource.contains(".keyboardShortcut(\"i\", modifiers: [.command, .option])"))
        #expect(imageMenuSource.contains(".keyboardShortcut(\"c\", modifiers: [.command, .option])"))
        #expect(imageMenuSource.contains("adjustmentButton(.levels, shortcut: \"l\", modifiers: [.command])"))
        #expect(imageMenuSource.contains("adjustmentButton(.curves, shortcut: \"m\", modifiers: [.command])"))
        #expect(imageMenuSource.contains("adjustmentButton(.colorBalance, shortcut: \"b\", modifiers: [.command])"))
        #expect(imageMenuSource.contains("adjustmentButton(.hueSaturation, shortcut: \"u\", modifiers: [.command])"))
        #expect(imageMenuSource.contains(".keyboardShortcut(\"u\", modifiers: [.command, .shift])"))
        #expect(imageMenuSource.contains(".keyboardShortcut(\"i\", modifiers: [.command])"))
        #expect(imageMenuSource.contains(".keyboardShortcut(\"l\", modifiers: [.command, .shift])"))
        #expect(imageMenuSource.contains(".keyboardShortcut(\"l\", modifiers: [.command, .shift, .option])"))
        #expect(imageMenuSource.contains(".keyboardShortcut(\"b\", modifiers: [.command, .shift])"))
        #expect(imageMenuSource.contains("imageEditor.menu.image.adjustments"))
        for adjustment in [
            "brightnessContrast", "channelMixer", "selectiveColor", "gradientMap",
            "posterize", "threshold", "exposure", "vibrance", "shadowsHighlights",
            "blackWhite", "photoFilter", "colorLookup",
        ] {
            #expect(imageMenuSource.contains("adjustmentButton(.\(adjustment))"))
        }
        #expect(commandsSource.contains("CommandMenu(L10n.text(\"imageEditor.menu.image\"))"))
        #expect(commandsSource.contains("XomoImageMenuItems(actions: actions)"))
        #expect(menuBarSource.contains("var xomoImageCommandActions: XomoImageCommandActions"))
        #expect(menuBarSource.contains("selectAdjustment: { viewModel.selectAdjustment($0) }"))
        #expect(appSource.contains("XomoImageCommands()"))
        #expect(viewSource.contains(".focusedSceneValue(\\.xomoImageCommandActions, xomoImageCommandActions)"))
    }

    @Test func systemAndEditorFilterMenusShareOneFocusedCommandTree() throws {
        let menuBarSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let commandsSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/XomoApplicationCommands.swift"),
            encoding: .utf8
        )
        let appSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/veilpicApp.swift"),
            encoding: .utf8
        )
        let viewSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(commandsSource.contains("CommandMenu(L10n.text(\"imageEditor.menu.filter\"))"))
        #expect(commandsSource.contains("@FocusedValue(\\.xomoFilterCommandContent)"))
        #expect(menuBarSource.contains("var xomoFilterCommandContent: XomoFocusedMenuContent"))
        #expect(menuBarSource.contains("XomoFocusedMenuContent(menuItems: AnyView(filterMenuItems))"))
        #expect(menuBarSource.contains("private var filterMenuItems: some View"))
        #expect(appSource.contains("XomoFilterCommands()"))
        #expect(viewSource.contains(".focusedSceneValue(\\.xomoFilterCommandContent, xomoFilterCommandContent)"))
    }

    @Test func filterMenuExposesClassicLastFilterShortcut() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let filterMenuStart = try #require(source.range(of: "private var filterMenuItems: some View"))
        let nextMenuStart = try #require(
            source[filterMenuStart.upperBound...].range(of: "private var viewMenuItems: some View")
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
        let filterMenuStart = try #require(source.range(of: "private var filterMenuItems: some View"))
        let nextMenuStart = try #require(
            source[filterMenuStart.upperBound...].range(of: "private var viewMenuItems: some View")
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
        let menuBarSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let commandsSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/XomoApplicationCommands.swift"),
            encoding: .utf8
        )
        let appSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/veilpicApp.swift"),
            encoding: .utf8
        )
        let viewSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let sharedMenuStart = try #require(
            commandsSource.range(of: "struct XomoEditMenuItems: View")
        )
        let sharedMenuEnd = try #require(
            commandsSource[sharedMenuStart.upperBound...].range(of: "struct XomoFileMenuItems: View")
        )
        let editMenuSource = commandsSource[sharedMenuStart.lowerBound..<sharedMenuEnd.lowerBound]

        #expect(editMenuSource.contains(".keyboardShortcut(\"z\", modifiers: [.command])"))
        #expect(editMenuSource.contains(".keyboardShortcut(\"z\", modifiers: [.command, .shift])"))
        #expect(editMenuSource.contains(".keyboardShortcut(\"c\", modifiers: [.command])"))
        #expect(editMenuSource.contains(".keyboardShortcut(\"c\", modifiers: [.command, .shift])"))
        #expect(editMenuSource.contains(".keyboardShortcut(\"c\", modifiers: [.command, .option, .shift])"))
        #expect(editMenuSource.contains(".keyboardShortcut(\"v\", modifiers: [.command])"))
        #expect(editMenuSource.contains(".keyboardShortcut(\"v\", modifiers: [.command, .shift])"))
        #expect(editMenuSource.contains("imageEditor.action.freeTransform"))
        #expect(editMenuSource.contains(".keyboardShortcut(\"t\", modifiers: [.command])"))
        #expect(editMenuSource.contains(".keyboardShortcut(\"x\", modifiers: [.command])"))
        #expect(editMenuSource.contains("imageEditor.action.fillDialog"))
        #expect(editMenuSource.contains("KeyEquivalent(\"\\u{F708}\")"))
        #expect(editMenuSource.contains(".keyboardShortcut(.delete, modifiers: [.option])"))
        #expect(editMenuSource.contains(".keyboardShortcut(.delete, modifiers: [.command])"))
        #expect(editMenuSource.contains("imageEditor.action.deleteSelectedObject"))
        #expect(editMenuSource.contains(".keyboardShortcut(.delete, modifiers: [])"))
        #expect(commandsSource.contains("CommandGroup(replacing: .undoRedo)"))
        #expect(commandsSource.contains("CommandGroup(replacing: .pasteboard)"))
        #expect(commandsSource.contains("CommandGroup(replacing: .textEditing)"))
        #expect(commandsSource.contains("CommandGroup(replacing: .textFormatting)"))
        #expect(commandsSource.contains("XomoEditMenuItems(actions: actions)"))
        #expect(menuBarSource.contains("var xomoEditCommandActions: XomoEditCommandActions"))
        #expect(menuBarSource.contains("deleteSelectedObject: { deleteSelectedObjectFromKeyboard() }"))
        #expect(menuBarSource.contains("ImageEditorContextualDocumentDeletePolicy.resolve("))
        #expect(appSource.contains("XomoEditCommands()"))
        #expect(viewSource.contains(".focusedSceneValue(\\.xomoEditCommandActions, xomoEditCommandActions)"))
    }

    @Test func fillDialogWiresNativePatternContentAndCanvasAlignment() throws {
        let panelSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent(
                "veilpic/ImageEditorSelectionFillPanel.swift"
            ),
            encoding: .utf8
        )
        let commandSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent(
                "veilpic/ImageEditorSelectionEditCommands.swift"
            ),
            encoding: .utf8
        )

        #expect(panelSource.contains("ImageEditorPatternOverlayKind.allCases"))
        #expect(panelSource.contains("selectionFillPatternContent"))
        #expect(panelSource.contains("selectionFillPatternAlignsWithCanvas"))
        #expect(panelSource.contains("image-editor-fill-pattern-controls"))
        #expect(commandSource.contains("case pattern"))
        #expect(commandSource.contains("ImageEditorSelectionPatternAlignment.localizedContent"))
        #expect(commandSource.contains("fillQuickMask(\n                with: pattern"))
    }

    @Test func fillDialogWiresContentAwareOptionsAndQuickMaskAvailability() throws {
        let panelSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent(
                "veilpic/ImageEditorSelectionFillPanel.swift"
            ),
            encoding: .utf8
        )
        let commandSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent(
                "veilpic/ImageEditorSelectionEditCommands.swift"
            ),
            encoding: .utf8
        )

        #expect(panelSource.contains("availableCases(\n                        isQuickMaskMode: viewModel.isQuickMaskMode"))
        #expect(panelSource.contains("selectionFillContentAwareColorAdaptation"))
        #expect(panelSource.contains("imageEditor.selectionFill.colorAdaptationHelp"))
        #expect(commandSource.contains("case contentAware"))
        #expect(commandSource.contains("guard !isQuickMaskMode else"))
        #expect(commandSource.contains("colorAdaptation: options.adaptsContentAwareColor"))
        #expect(commandSource.contains("blendMode: blendMode"))
    }

    @Test func historyFillWiresPanelSourceDialogAndClassicShortcut() throws {
        let editorSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let menuSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let panelSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent(
                "veilpic/ImageEditorSelectionFillPanel.swift"
            ),
            encoding: .utf8
        )
        let commandSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent(
                "veilpic/ImageEditorSelectionEditCommands.swift"
            ),
            encoding: .utf8
        )
        let applicationCommandSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent(
                "veilpic/XomoApplicationCommands.swift"
            ),
            encoding: .utf8
        )

        #expect(editorSource.contains("viewModel.setHistoryFillSource(entryID: entry.id)"))
        #expect(editorSource.contains("viewModel.setHistoryFillSource(snapshotID: snapshot.id)"))
        #expect(editorSource.contains("case .fillSelectionHistory: viewModel.fillSelectionFromHistory()"))
        #expect(editorSource.contains("relevantFlags == [.command, .option]"))
        #expect(panelSource.contains("selectionFillContents == .history"))
        #expect(panelSource.contains("viewModel.historyFillSourceTitle"))
        #expect(commandSource.contains("sourceDocument.layers.first(where: { $0.id == layer.id"))
        #expect(commandSource.contains("func historyFilled("))
        #expect(menuSource.contains("fillSelectionFromHistory: { viewModel.fillSelectionFromHistory() }"))
        #expect(menuSource.contains("canFillSelectionFromHistory: viewModel.canFillSelectionFromHistory"))
        #expect(applicationCommandSource.contains(
            ".keyboardShortcut(.delete, modifiers: [.command, .option])"
        ))
        #expect(applicationCommandSource.contains(
            ".disabled(actions?.canFillSelectionFromHistory != true)"
        ))
    }

    @Test func historyBrushWiresTheSharedSourceIntoNativePaintingAndOptions() throws {
        let editorSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let captureSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent(
                "veilpic/ImageEditorScrollZoom.swift"
            ),
            encoding: .utf8
        )
        let commandSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent(
                "veilpic/ImageEditorSelectionEditCommands.swift"
            ),
            encoding: .utf8
        )

        #expect(captureSource.contains("case .brush, .pencil, .historyBrush, .eraser, .rectangle"))
        #expect(editorSource.contains("case .historyBrush:\n                                viewModel.historyBrush(samples: committedBrushSamples)"))
        #expect(editorSource.contains("viewModel.selectedTool == .historyBrush"))
        #expect(editorSource.contains("viewModel.historyFillSourceTitle"))
        #expect(editorSource.contains("image-editor-history-brush-source"))
        #expect(commandSource.contains("func historyBrush(samples: [ImageEditorBrushStrokeSample]) -> Bool"))
        #expect(commandSource.contains("let sourceDocument = historyFillDocument(for: source)"))
        #expect(commandSource.contains("func historyBrushed("))
        #expect(commandSource.contains("skipIfUnchanged: true"))
    }

    @Test func pencilWiresAliasedPaintingThroughNativeCaptureOptionsMasksAndHistory() throws {
        let editorSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let viewModelSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent(
                "veilpic/ImageEditorViewModel.swift"
            ),
            encoding: .utf8
        )
        let brushSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent(
                "veilpic/ImageEditorBrushStroke.swift"
            ),
            encoding: .utf8
        )
        let preferencesSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent(
                "veilpic/ImageEditorBrushDynamicsPreferences.swift"
            ),
            encoding: .utf8
        )

        #expect(editorSource.components(separatedBy: "viewModel.drawPencil(samples: committedBrushSamples)").count == 3)
        #expect(editorSource.contains("usesBrushOptions && viewModel.selectedTool != .pencil"))
        #expect(editorSource.contains("case .brush, .pencil, .historyBrush, .eraser"))
        #expect(viewModelSource.contains("usesBackgroundColorForMasks: usesBackgroundColor,\n            edgeStyle: .aliased"))
        #expect(viewModelSource.contains("edgeStyle == .aliased ? 1 : hardness"))
        #expect(viewModelSource.contains("? \"imageEditor.history.pencil\""))
        #expect(viewModelSource.contains("pencilUsesBackgroundColor(at: samples.first?.point)"))
        #expect(viewModelSource.contains("usesBackgroundColor ? backgroundColor : foregroundColor"))
        #expect(brushSource.contains("return distance <= outerRadius ? 1 : 0"))
        #expect(brushSource.contains("enum ImageEditorPencilAutoErasePolicy"))
        #expect(preferencesSource.contains("case pencilAutoEraseEnabled"))
        #expect(editorSource.contains("viewModel.setPencilAutoEraseEnabled($0)"))
        #expect(editorSource.contains("image-editor-pencil-auto-erase"))

        for locale in ["en", "ja", "zh-Hans"] {
            let localization = try String(
                contentsOf: Self.repositoryRoot().appendingPathComponent(
                    "veilpic/\(locale).lproj/Localizable.strings"
                ),
                encoding: .utf8
            )
            #expect(localization.contains("\"imageEditor.tool.pencil\""))
            #expect(localization.contains("\"imageEditor.tool.pencil.help\""))
            #expect(localization.contains("\"imageEditor.history.pencil\""))
            #expect(localization.contains("\"imageEditor.option.pencilAutoErase\""))
            #expect(localization.contains("\"imageEditor.option.pencilAutoErase.help\""))
        }
    }

    @Test func eraserHistoryModeLatchesAtPointerDownAndWiresBothPaintingPaths() throws {
        let editorSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let commandSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent(
                "veilpic/ImageEditorSelectionEditCommands.swift"
            ),
            encoding: .utf8
        )

        #expect(editorSource.contains("image-editor-erase-to-history"))
        #expect(editorSource.contains("isOn: $viewModel.eraserErasesToHistory"))
        #expect(editorSource.contains(".disabled(!viewModel.canEraseToHistory)"))
        #expect(editorSource.contains("if canvasInteractionTool == .eraser {\n                                isEraserHistoryGestureActive = viewModel.shouldEraseToHistory"))
        #expect(editorSource.contains("if canvasInteractionTool == .eraser,\n                           brushStrokeSamples.isEmpty {\n                            isEraserHistoryGestureActive = viewModel.shouldEraseToHistory"))
        #expect(editorSource.components(separatedBy: "viewModel.eraseBrush(").count == 3)
        #expect(editorSource.components(separatedBy: "isEraserHistoryGestureActive = false").count >= 5)
        #expect(editorSource.components(separatedBy: "isErasingToHistory: isEraserHistoryCursorActive").count == 4)
        #expect(commandSource.contains("var canEraseToHistory: Bool"))
        #expect(commandSource.contains("func shouldEraseToHistory(modifierFlags: NSEvent.ModifierFlags) -> Bool"))
        #expect(commandSource.contains("func eraseBrush("))
        #expect(commandSource.contains("_ = historyBrush(samples: samples, blendMode: .normal)"))

        for locale in ["en", "ja", "zh-Hans"] {
            let localization = try String(
                contentsOf: Self.repositoryRoot().appendingPathComponent(
                    "veilpic/\(locale).lproj/Localizable.strings"
                ),
                encoding: .utf8
            )
            #expect(localization.contains("\"imageEditor.option.eraseToHistory\""))
            #expect(localization.contains("\"imageEditor.option.eraseToHistory.help\""))
        }
    }

    @Test func historyBrushBlendModeWiresPersistencePixelsAndOptionsWithoutAffectingEraser() throws {
        let editorSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let commandSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent(
                "veilpic/ImageEditorSelectionEditCommands.swift"
            ),
            encoding: .utf8
        )
        let preferencesSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent(
                "veilpic/ImageEditorBrushDynamicsPreferences.swift"
            ),
            encoding: .utf8
        )

        #expect(editorSource.contains("image-editor-history-brush-blend-mode"))
        #expect(editorSource.contains("ForEach(ImageEditorBlendMode.smartFilterCases)"))
        #expect(editorSource.contains("set: { viewModel.setHistoryBrushBlendMode($0) }"))
        #expect(commandSource.contains("historyBrush(samples: samples, blendMode: historyBrushBlendMode)"))
        #expect(commandSource.contains("historyBrush(samples: samples, blendMode: .normal)"))
        #expect(commandSource.contains("blendMode: blendMode == .passThrough ? .normal : blendMode"))
        #expect(preferencesSource.contains("case historyBrushBlendMode"))
        #expect(preferencesSource.contains("?? .normal"))

        for locale in ["en", "ja", "zh-Hans"] {
            let localization = try String(
                contentsOf: Self.repositoryRoot().appendingPathComponent(
                    "veilpic/\(locale).lproj/Localizable.strings"
                ),
                encoding: .utf8
            )
            #expect(localization.contains("\"imageEditor.option.historyBrushBlendMode\""))
        }
    }

    @Test func brushAndPencilBlendModeWiresOptionsPixelsAndBothMaskTargets() throws {
        let editorSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let modelSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorViewModel.swift"),
            encoding: .utf8
        )
        let strokeSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorBrushStroke.swift"),
            encoding: .utf8
        )
        let preferencesSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent(
                "veilpic/ImageEditorBrushDynamicsPreferences.swift"
            ),
            encoding: .utf8
        )

        #expect(editorSource.contains("viewModel.selectedTool == .brush || viewModel.selectedTool == .pencil"))
        #expect(editorSource.contains("ForEach(ImageEditorBlendMode.paintCases)"))
        #expect(editorSource.contains("set: { viewModel.setPaintBlendMode($0) }"))
        #expect(editorSource.contains("image-editor-paint-blend-mode"))
        #expect(modelSource.contains("blendMode: erase ? .normal : paintBlendMode"))
        #expect(modelSource.contains("paintQuickMask("))
        #expect(modelSource.contains("paintSelectedLayerMask("))
        #expect(modelSource.contains("targetAlpha: reveal ? UInt8.max : UInt8.min"))
        #expect(strokeSource.contains("targetAlpha * CGFloat(blendedColors[channel])"))
        #expect(preferencesSource.contains("case paintBlendMode"))

        for locale in ["en", "ja", "zh-Hans"] {
            let localization = try String(
                contentsOf: Self.repositoryRoot().appendingPathComponent(
                    "veilpic/\(locale).lproj/Localizable.strings"
                ),
                encoding: .utf8
            )
            #expect(localization.contains("\"imageEditor.option.paintBlendMode\""))
            #expect(localization.contains("\"imageEditor.option.paintBlendMode.help\""))
        }
    }

    @Test func brushAirbrushWiresTimePulsesAcrossNativeFallbackAndMaskPaths() throws {
        let root = Self.repositoryRoot()
        let editorSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let modelSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorViewModel.swift"),
            encoding: .utf8
        )
        let strokeSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorBrushStroke.swift"),
            encoding: .utf8
        )
        let maskSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorSelectionBoolean.swift"),
            encoding: .utf8
        )

        #expect(editorSource.contains("viewModel.selectedTool == .brush"))
        #expect(editorSource.contains("set: { viewModel.setPaintAirbrushEnabled($0) }"))
        #expect(editorSource.contains("image-editor-paint-airbrush"))
        #expect(editorSource.contains("updatePaintAirbrushStroke(at: imagePoint, pressure: nil)"))
        #expect(editorSource.components(separatedBy: "updatePaintAirbrushStroke(").count >= 4)
        #expect(editorSource.components(separatedBy: "finishPaintAirbrushStroke(at:").count >= 3)
        #expect(editorSource.components(separatedBy: "paintAirbrushStroke.reset()").count >= 5)
        #expect(modelSource.contains("airbrushPulseSamples: erase ? [] : airbrushPulseSamples"))
        #expect(modelSource.contains("localPaintAirbrushPulseSamples = rasterLocalSamples"))
        #expect(strokeSource.contains("stamps: pathStamps + airbrushPulseSamples"))
        #expect(maskSource.contains(") + scaledAirbrushPulseSamples"))

        for locale in ["en", "ja", "zh-Hans"] {
            let localization = try String(
                contentsOf: root.appendingPathComponent(
                    "veilpic/\(locale).lproj/Localizable.strings"
                ),
                encoding: .utf8
            )
            #expect(localization.contains("\"imageEditor.option.paintAirbrush\""))
            #expect(localization.contains("\"imageEditor.option.paintAirbrush.help\""))
        }
    }

    @Test func fileMenuExposesClipboardCanvasCreation() throws {
        let menuBarSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let commandsSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/XomoApplicationCommands.swift"),
            encoding: .utf8
        )

        #expect(commandsSource.contains("imageEditor.action.canvasNewFromClipboard"))
        #expect(menuBarSource.contains("viewModel.createCanvasFromClipboard()"))
        #expect(commandsSource.contains(".keyboardShortcut(\"n\", modifiers: [.command, .option])"))
        #expect(commandsSource.contains(".disabled(actions?.canCreateCanvasFromClipboard != true)"))
    }

    @Test func commandNOpensCanvasSheetInsteadOfWindowGroupWindow() throws {
        let root = Self.repositoryRoot()
        let appSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/veilpicApp.swift"),
            encoding: .utf8
        )
        let editorSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let commandsSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/XomoApplicationCommands.swift"),
            encoding: .utf8
        )

        #expect(appSource.contains("XomoFileCommands()"))
        #expect(commandsSource.contains("CommandGroup(replacing: .newItem)"))
        #expect(commandsSource.contains("actions?.createCanvas()"))
        #expect(editorSource.contains("case .newCanvas:"))
        #expect(editorSource.contains("requestDocumentReplacement"))
        #expect(editorSource.contains("viewModel.isNewCanvasSheetPresented = true"))
        #expect(editorSource.contains("if key == \"n\", relevantFlags == [.command] { return .newCanvas }"))
    }

    @Test func fileMenuExposesDirectSelectionSliceExport() throws {
        let menuBarSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let commandsSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/XomoApplicationCommands.swift"),
            encoding: .utf8
        )

        #expect(commandsSource.contains("imageEditor.action.exportSelection"))
        #expect(menuBarSource.contains("viewModel.exportSettings.scope = .selection"))
        #expect(commandsSource.contains(".keyboardShortcut(\"e\", modifiers: [.command, .option])"))
        #expect(commandsSource.contains(".disabled(actions?.canExportSelection != true)"))
    }

    @Test func fileMenuExposesDirectSelectedLayerExport() throws {
        let menuBarSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let commandsSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/XomoApplicationCommands.swift"),
            encoding: .utf8
        )

        #expect(commandsSource.contains("imageEditor.action.exportLayers"))
        #expect(menuBarSource.contains("viewModel.selectedLayersExportScope"))
        #expect(commandsSource.contains(".keyboardShortcut(\"l\", modifiers: [.command, .option])"))
        #expect(commandsSource.contains(".disabled(actions?.canExportSelectedLayers != true)"))
    }

    @Test func exportPanelUsesDarkReadableTextAndLocalizedSliceScope() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorExportPanel.swift"),
            encoding: .utf8
        )

        #expect(source.contains(".foregroundStyle(Color(nsColor: ImageEditorTheme.text))"))
        #expect(source.contains(".environment(\\.colorScheme, .dark)"))
        #expect(source.contains("ImageEditorExportScaleFormatter.string"))
        #expect(L10n.text("imageEditor.export.scope.slice") != "imageEditor.export.scope.slice")
    }

    @Test func exportPanelWiresCollisionSafeAllSlicesDelivery() throws {
        let panelSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent(
                "veilpic/ImageEditorExportPanel.swift"
            ),
            encoding: .utf8
        )
        let exportSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent(
                "veilpic/ImageEditorExport.swift"
            ),
            encoding: .utf8
        )

        #expect(panelSource.contains("imageEditor.export.saveAllSlices"))
        #expect(panelSource.contains("viewModel.runExportAllSlices()"))
        #expect(panelSource.contains(
            ".accessibilityIdentifier(\"image-editor-export-all-slices\")"
        ))
        #expect(exportSource.contains("func sliceExportPlan("))
        #expect(exportSource.contains("slice.exportPresets ?? []"))
        #expect(exportSource.contains("func sliceExportArtifacts("))
        #expect(exportSource.contains("func runExportAllSlices()"))
        #expect(exportSource.contains("let panel = NSOpenPanel()"))
        #expect(exportSource.contains("panel.canChooseDirectories = true"))
        #expect(panelSource.contains("imageEditor.export.sliceConflictPolicy"))
        #expect(panelSource.contains("ImageEditorSliceExportConflictPolicy.allCases"))
        #expect(panelSource.contains("sliceConflictPolicyBinding"))
        #expect(exportSource.contains("ImageEditorSliceExportConflictPolicy.resolve("))
        #expect(exportSource.contains("settings.sliceConflictPolicy == .abort"))
        #expect(exportSource.contains("resolution.deliverablePlan"))
        #expect(exportSource.contains("options: .withoutOverwriting"))

        let conflictCheck = try #require(exportSource.range(of: "settings.sliceConflictPolicy == .abort"))
        let artifactCreation = try #require(
            exportSource[conflictCheck.upperBound...].range(
                of: "sliceExportArtifacts(plan: resolution.deliverablePlan)"
            )
        )
        #expect(conflictCheck.lowerBound < artifactCreation.lowerBound)

        for locale in ["en", "ja", "zh-Hans"] {
            let localization = try String(
                contentsOf: Self.repositoryRoot().appendingPathComponent(
                    "veilpic/\(locale).lproj/Localizable.strings"
                ),
                encoding: .utf8
            )
            #expect(localization.contains("\"imageEditor.export.saveAllSlices\""))
            #expect(localization.contains("\"imageEditor.export.chooseFolder\""))
            #expect(localization.contains("\"imageEditor.status.exportedAllSlices\""))
            #expect(localization.contains("\"imageEditor.status.exportSliceConflicts\""))
            #expect(localization.contains("\"imageEditor.export.sliceConflictPolicy.skipExisting\""))
            #expect(localization.contains("\"imageEditor.status.exportedSlicesSkippingExisting\""))
            #expect(localization.contains("\"imageEditor.status.exportSlicesAllSkipped\""))
        }
    }

    @Test func slicesMenuOffersDirectAllSlicesDelivery() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent(
                "veilpic/ImageEditorMenuBar.swift"
            ),
            encoding: .utf8
        )
        let menuStart = try #require(source.range(of: "private var slicesActionsMenu"))
        let menuEnd = try #require(
            source[menuStart.upperBound...].range(of: "private var toolsActionsMenu")
        )
        let menuSource = source[menuStart.lowerBound..<menuEnd.lowerBound]

        #expect(menuSource.contains("imageEditor.action.exportAllSlices"))
        #expect(menuSource.contains("viewModel.runExportAllSlices()"))
        #expect(menuSource.contains(".disabled(!viewModel.canExportNamedSlice)"))

        for locale in ["en", "ja", "zh-Hans"] {
            let localization = try String(
                contentsOf: Self.repositoryRoot().appendingPathComponent(
                    "veilpic/\(locale).lproj/Localizable.strings"
                ),
                encoding: .utf8
            )
            #expect(localization.contains("\"imageEditor.action.exportAllSlices\""))
        }
    }

    @Test func slicePanelEditsNativeExportPresetsThroughSharedCommands() throws {
        let panelSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent(
                "veilpic/ImageEditorHotspotPanel.swift"
            ),
            encoding: .utf8
        )
        let commandSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent(
                "veilpic/ImageEditorSlices.swift"
            ),
            encoding: .utf8
        )

        #expect(panelSource.contains("imageEditor.slices.exportPreset.addCurrent"))
        #expect(panelSource.contains("viewModel.addCurrentExportPreset(toSlice: slice.id)"))
        #expect(panelSource.contains("viewModel.removeSliceExportPreset(fromSlice: slice.id, at: index)"))
        #expect(panelSource.contains("imageEditor.slices.exportPreset.remove"))
        #expect(commandSource.contains("func addCurrentExportPreset(toSlice id: UUID)"))
        #expect(commandSource.contains("func removeSliceExportPreset(fromSlice id: UUID"))
        #expect(commandSource.contains("guard !existing.contains(preset)"))
        #expect(commandSource.contains("pushUndo()"))

        for locale in ["en", "ja", "zh-Hans"] {
            let localization = try String(
                contentsOf: Self.repositoryRoot().appendingPathComponent(
                    "veilpic/\(locale).lproj/Localizable.strings"
                ),
                encoding: .utf8
            )
            #expect(localization.contains("\"imageEditor.slices.exportPreset.addCurrent\""))
            #expect(localization.contains("\"imageEditor.slices.exportPreset.remove\""))
            #expect(localization.contains("\"imageEditor.history.sliceExportPresetAdded\""))
            #expect(localization.contains("\"imageEditor.history.sliceExportPresetRemoved\""))
        }
    }

    @Test func slicePanelReordersPresetsAndHistoryResynchronizesThePrimarySetting() throws {
        let panelSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent(
                "veilpic/ImageEditorHotspotPanel.swift"
            ),
            encoding: .utf8
        )
        let sliceSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent(
                "veilpic/ImageEditorSlices.swift"
            ),
            encoding: .utf8
        )
        let viewModelSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent(
                "veilpic/ImageEditorViewModel.swift"
            ),
            encoding: .utf8
        )

        #expect(panelSource.contains("onMoveExportPreset(index, .up)"))
        #expect(panelSource.contains("onMoveExportPreset(index, .down)"))
        #expect(panelSource.contains(".disabled(index == presets.startIndex)"))
        #expect(panelSource.contains(".disabled(index == presets.index(before: presets.endIndex))"))
        #expect(sliceSource.contains("func moveSliceExportPreset("))
        #expect(sliceSource.contains("presets.swapAt(presetIndex, destination)"))
        #expect(sliceSource.contains("syncExportSettingsAfterSliceHistoryChange"))
        #expect(viewModelSource.components(
            separatedBy: "syncExportSettingsAfterSliceHistoryChange(from: slicesBeforeRestore)"
        ).count == 4)

        for locale in ["en", "ja", "zh-Hans"] {
            let localization = try String(
                contentsOf: Self.repositoryRoot().appendingPathComponent(
                    "veilpic/\(locale).lproj/Localizable.strings"
                ),
                encoding: .utf8
            )
            #expect(localization.contains("\"imageEditor.slices.exportPreset.moveUp\""))
            #expect(localization.contains("\"imageEditor.slices.exportPreset.moveDown\""))
            #expect(localization.contains("\"imageEditor.history.sliceExportPresetMoved\""))
        }
    }

    @Test func slicePanelCommitsSanitizedPresetSuffixDraftsThroughTheModel() throws {
        let panelSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent(
                "veilpic/ImageEditorHotspotPanel.swift"
            ),
            encoding: .utf8
        )
        let sliceSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent(
                "veilpic/ImageEditorSlices.swift"
            ),
            encoding: .utf8
        )

        #expect(panelSource.contains("var exportPresetSuffixes: [String]"))
        #expect(panelSource.contains("existing.exportPresetSuffixes = (slice.exportPresets ?? []).map(\\.suffix)"))
        #expect(panelSource.contains("imageEditor.slices.exportPreset.suffix"))
        #expect(panelSource.contains("onUpdateExportPresetSuffix("))
        #expect(panelSource.contains("viewModel.updateSliceExportPresetSuffix("))
        #expect(sliceSource.contains("func updateSliceExportPresetSuffix("))
        #expect(sliceSource.contains("suffix: suffix"))
        #expect(sliceSource.contains("index != presetIndex && preset == updated"))
        #expect(sliceSource.contains("presetIndex == presets.startIndex"))

        for locale in ["en", "ja", "zh-Hans"] {
            let localization = try String(
                contentsOf: Self.repositoryRoot().appendingPathComponent(
                    "veilpic/\(locale).lproj/Localizable.strings"
                ),
                encoding: .utf8
            )
            #expect(localization.contains("\"imageEditor.slices.exportPreset.suffix\""))
            #expect(localization.contains("\"imageEditor.slices.exportPreset.applySuffix\""))
            #expect(localization.contains("\"imageEditor.status.sliceExportPresetDuplicate\""))
            #expect(localization.contains("\"imageEditor.history.sliceExportPresetSuffixUpdated\""))
        }
    }

    @Test func slicePanelCommitsSupportedPresetFormatsThroughTheModel() throws {
        let panelSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent(
                "veilpic/ImageEditorHotspotPanel.swift"
            ),
            encoding: .utf8
        )
        let sliceSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent(
                "veilpic/ImageEditorSlices.swift"
            ),
            encoding: .utf8
        )
        let exportSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent(
                "veilpic/ImageEditorExport.swift"
            ),
            encoding: .utf8
        )

        #expect(panelSource.contains("imageEditor.slices.exportPreset.format"))
        #expect(panelSource.contains("ImageEditorExportFormat.sliceExportPresetFormats"))
        #expect(panelSource.contains("onUpdateExportPresetFormat(index, $0)"))
        #expect(panelSource.contains("viewModel.updateSliceExportPresetFormat("))
        #expect(sliceSource.contains("func updateSliceExportPresetFormat("))
        #expect(sliceSource.contains("constraint: format == .pdf ? .scale : current.constraint"))
        #expect(sliceSource.contains("value: format == .pdf ? 1 : current.value"))
        #expect(sliceSource.contains("index != presetIndex && preset == updated"))
        #expect(exportSource.contains("static let sliceExportPresetFormats: [Self] = [.png, .jpeg, .pdf]"))

        for locale in ["en", "ja", "zh-Hans"] {
            let localization = try String(
                contentsOf: Self.repositoryRoot().appendingPathComponent(
                    "veilpic/\(locale).lproj/Localizable.strings"
                ),
                encoding: .utf8
            )
            #expect(localization.contains("\"imageEditor.slices.exportPreset.format\""))
            #expect(localization.contains("\"imageEditor.status.sliceExportPresetFormatUpdated\""))
            #expect(localization.contains("\"imageEditor.history.sliceExportPresetFormatUpdated\""))
        }
    }

    @Test func slicePanelEditsPresetConstraintsAndValuesThroughValidatedModelCommands() throws {
        let panelSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent(
                "veilpic/ImageEditorHotspotPanel.swift"
            ),
            encoding: .utf8
        )
        let sliceSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent(
                "veilpic/ImageEditorSlices.swift"
            ),
            encoding: .utf8
        )

        #expect(panelSource.contains("var exportPresetValues: [String]"))
        #expect(panelSource.contains("existing.exportPresetValues = (slice.exportPresets ?? []).map"))
        #expect(panelSource.contains("ImageEditorSliceExportConstraint.allCases"))
        #expect(panelSource.contains("onChangeExportPresetConstraint(index, $0)"))
        #expect(panelSource.contains("onUpdateExportPresetValue("))
        #expect(panelSource.contains("viewModel.changeSliceExportPresetConstraint("))
        #expect(panelSource.contains("viewModel.updateSliceExportPresetValue("))
        #expect(panelSource.contains(".disabled(presets[index].format == .pdf)"))
        #expect(sliceSource.contains("func changeSliceExportPresetConstraint("))
        #expect(sliceSource.contains("value = scale * Double(slice.frame.width)"))
        #expect(sliceSource.contains("value = scale * Double(slice.frame.height)"))
        #expect(sliceSource.contains("func updateSliceExportPresetValue("))
        #expect(sliceSource.contains("current.format == .pdf ? .scale : constraint"))
        #expect(sliceSource.contains("current.format == .pdf ? 1 : value"))

        for locale in ["en", "ja", "zh-Hans"] {
            let localization = try String(
                contentsOf: Self.repositoryRoot().appendingPathComponent(
                    "veilpic/\(locale).lproj/Localizable.strings"
                ),
                encoding: .utf8
            )
            #expect(localization.contains("\"imageEditor.slices.exportPreset.constraint\""))
            #expect(localization.contains("\"imageEditor.slices.exportPreset.value\""))
            #expect(localization.contains("\"imageEditor.slices.exportPreset.applyValue\""))
            #expect(localization.contains("\"imageEditor.status.sliceExportPresetDeliveryUpdated\""))
            #expect(localization.contains("\"imageEditor.history.sliceExportPresetDeliveryUpdated\""))
        }
    }

    @Test func exportPanelUsesSharedLabelGridAndSingleLineScopeSegments() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorExportPanel.swift"),
            encoding: .utf8
        )

        #expect(source.contains("static let panelWidth: CGFloat = 532"))
        #expect(source.contains("static let labelWidth: CGFloat = 72"))
        #expect(source.contains("static let rowHeight: CGFloat = 26"))
        #expect(source.contains("static let scopePickerMinimumWidth: CGFloat = 392"))
        #expect(source.contains("private func exportFormRow<Content: View>"))
        #expect(source.contains(".frame(width: Layout.labelWidth, alignment: .leading)"))
        #expect(source.contains(".frame(minWidth: Layout.scopePickerMinimumWidth, alignment: .leading)"))
        #expect(source.contains(".frame(minHeight: Layout.rowHeight)"))
        #expect(source.contains(".lineLimit(1)"))
        #expect(source.contains(".minimumScaleFactor(0.75)"))
        #expect(source.contains(".minimumScaleFactor(0.8)"))
        #expect(source.contains(".layoutPriority(2)"))
        #expect(source.components(separatedBy: "exportFormRow(").count - 1 >= 7)
    }

    @Test func historyAndNativeFilterControlsForceDarkReadableAppearance() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let historyStart = try #require(source.range(of: "private func historyPanel"))
        let filterStart = try #require(source.range(of: "private var filtersQuickPanel: some View"))
        let historySource = source[historyStart.lowerBound..<filterStart.lowerBound]
        let snapshotStart = try #require(
            source[filterStart.upperBound...].range(of: "private func historySnapshotRow")
        )
        let filterSource = source[filterStart.lowerBound..<snapshotStart.lowerBound]

        #expect(historySource.contains("ImageEditorDarkPanelLabel("))
        #expect(historySource.contains("title: entry.title"))
        #expect(historySource.contains(".onTapGesture"))
        #expect(historySource.contains(".accessibilityAction"))
        #expect(historySource.contains("ImageEditorHistorySearchField("))
        #expect(historySource.contains(".foregroundStyle(Color(nsColor: ImageEditorTheme.text))"))
        #expect(filterSource.contains("ImageEditorDarkFilterPicker(selection: $viewModel.selectedFilter)"))
        #expect(!filterSource.contains("Picker(L10n.text(\"imageEditor.properties.filter\")"))
        let controlsSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorDarkPanelControls.swift"),
            encoding: .utf8
        )
        #expect(controlsSource.contains("override func hitTest(_ point: NSPoint) -> NSView?"))
    }

    @Test func smartFilterRowsExposeNonFocusableResultOpacityAndBlendControls() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let propertiesStart = try #require(source.range(of: "private func propertiesPanel"))
        let propertiesEnd = try #require(
            source[propertiesStart.upperBound...].range(of: "private var levelsControls")
        )
        let propertiesSource = source[propertiesStart.lowerBound..<propertiesEnd.lowerBound]

        #expect(propertiesSource.contains("viewModel.smartFilterOpacity(filter.id)"))
        #expect(propertiesSource.contains("viewModel.smartFilterOpacityState(filter.id)"))
        #expect(propertiesSource.contains("opacityState.isMixed ? L10n.text(\"imageEditor.properties.multipleValues\")"))
        #expect(propertiesSource.contains("viewModel.setSmartFilterOpacityOnSelectedLayer(filter.id, opacity: $0)"))
        #expect(propertiesSource.contains("image-editor-smart-filter-opacity-\\(filter.id)"))
        #expect(propertiesSource.contains(".accessibilityValue(opacityTitle)"))
        #expect(propertiesSource.contains("viewModel.smartFilterBlendMode(filter.id)"))
        #expect(propertiesSource.contains("viewModel.smartFilterBlendModeState(filter.id)"))
        #expect(propertiesSource.contains("isMixed: blendModeState.isMixed"))
        #expect(propertiesSource.contains("viewModel.setSmartFilterBlendModeOnSelectedLayer(filter.id, blendMode: $0)"))
        #expect(propertiesSource.contains("ImageEditorDarkSmartFilterBlendPicker("))
        #expect(propertiesSource.contains("image-editor-smart-filter-blend-mode-\\(filter.id)"))
        #expect(propertiesSource.contains(".accessibilityValue(blendModeTitle)"))
        #expect(propertiesSource.contains("viewModel.duplicateSmartFilterOnSelectedLayer(filter.id)"))
        #expect(propertiesSource.contains("image-editor-smart-filter-duplicate-\\(filter.id)"))
        #expect(propertiesSource.contains("imageEditor.action.layerSmartFilterDuplicate"))
        #expect(propertiesSource.contains("viewModel.loadSmartFilterIntoControls(filter.id)"))
        #expect(propertiesSource.contains("image-editor-smart-filter-load-\\(filter.id)"))
        #expect(propertiesSource.contains("imageEditor.action.layerSmartFilterLoadSettings"))
        #expect(propertiesSource.contains("viewModel.isSmartFilterLoadedForEditing(filter.id)"))
        #expect(propertiesSource.contains("viewModel.smartFilterHasPendingControlChanges(filter.id)"))
        #expect(propertiesSource.contains("ImageEditorTheme.selected).opacity(0.20)"))
        #expect(propertiesSource.contains("imageEditor.state.editing"))
        #expect(propertiesSource.contains("imageEditor.state.editingModified"))
        #expect(propertiesSource.contains("imageEditor.state.unsavedChanges"))
        #expect(propertiesSource.contains(".disabled(!isLoadedForEditing || !hasPendingControlChanges)"))
        #expect(propertiesSource.contains("viewModel.discardSmartFilterControlChanges(filter.id)"))
        #expect(propertiesSource.contains("viewModel.canDiscardSmartFilterControlChanges(filter.id)"))
        #expect(propertiesSource.contains("image-editor-smart-filter-discard-\\(filter.id)"))
        #expect(propertiesSource.contains("imageEditor.action.layerSmartFilterDiscardChanges"))
        #expect(propertiesSource.contains("viewModel.updateLoadedSmartFilterOnSelectedLayer()"))
        #expect(propertiesSource.contains("viewModel.canUpdateLoadedSmartFilterOnSelectedLayer"))
        #expect(propertiesSource.contains("viewModel.moveSmartFilterOnSelectedLayer(filter.id, offset: -1)"))
        #expect(propertiesSource.contains("viewModel.moveSmartFilterOnSelectedLayer(filter.id, offset: 1)"))
        #expect(propertiesSource.contains("viewModel.canMoveSmartFilterOnSelectedLayer(filter.id, offset: -1)"))
        #expect(propertiesSource.contains("viewModel.canMoveSmartFilterOnSelectedLayer(filter.id, offset: 1)"))
        #expect(propertiesSource.contains("Image(systemName: \"chevron.up\")"))
        #expect(propertiesSource.contains("Image(systemName: \"chevron.down\")"))
        #expect(propertiesSource.contains(".disabled(!canMoveUp)"))
        #expect(propertiesSource.contains(".disabled(!canMoveDown)"))
        #expect(propertiesSource.contains("image-editor-smart-filter-move-up-\\(filter.id)"))
        #expect(propertiesSource.contains("image-editor-smart-filter-move-down-\\(filter.id)"))
        #expect(propertiesSource.contains("imageEditor.option.opacity"))
        #expect(propertiesSource.contains(".focusable(false)"))
    }

    @Test func escapeDiscardsPendingSmartFilterControlsAfterObjectCancellation() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("viewModel.discardLoadedSmartFilterControlChanges()"))
        #expect(source.contains("discardPendingSmartFilterChanges: discardPendingSmartFilterChanges"))
        #expect(source.contains("context.coordinator.discardPendingSmartFilterChanges = discardPendingSmartFilterChanges"))
        let escapeStart = try #require(
            source.range(of: "if event.type == .keyDown,\n               event.keyCode == 53")
        )
        let escapeSource = source[escapeStart.lowerBound...]
        #expect(escapeSource.contains("ImageEditorEscapeCancelDispatcher.handle("))

        var calls: [String] = []
        #expect(
            ImageEditorEscapeCancelDispatcher.handle(
                cancelSelectedObject: {
                    calls.append("object")
                    return true
                },
                discardPendingSmartFilterChanges: {
                    calls.append("filter")
                    return true
                }
            )
        )
        #expect(calls == ["object"])

        calls.removeAll()
        #expect(
            ImageEditorEscapeCancelDispatcher.handle(
                cancelSelectedObject: {
                    calls.append("object")
                    return false
                },
                discardPendingSmartFilterChanges: {
                    calls.append("filter")
                    return true
                }
            )
        )
        #expect(calls == ["object", "filter"])
    }

    @Test func escapeCancelsPathAnchorDragAndLatchesRemainingGestureEvents() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        let cancelStart = try #require(source.range(of: "cancelSelectedObject: {"))
        let cancelEnd = try #require(
            source[cancelStart.upperBound...].range(of: "if isMovingTransformReferencePoint")
        )
        let cancelSource = source[cancelStart.lowerBound..<cancelEnd.lowerBound]
        #expect(cancelSource.contains("if isMovingPathAnchor"))
        #expect(cancelSource.contains("isPathAnchorDragCancelled = true"))
        #expect(cancelSource.contains("viewModel.cancelMovingPathAnchor()"))

        #expect(source.contains("if isPathAnchorDragCancelled {\n                    return\n                }"))
        #expect(source.contains("if isMovingPathAnchor, !isPathAnchorDragCancelled"))
        #expect(source.contains("isPathAnchorDragCancelled = false"))
    }

    @Test func historyCommandsCancelPathAnchorDragAndLatchRemainingGestureEvents() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        for helperName in ["performUndo", "performRedo"] {
            let helperStart = try #require(source.range(of: "func \(helperName)()"))
            let helperEnd = try #require(
                source[helperStart.upperBound...].range(of: "\n    }")
            )
            let helperSource = source[helperStart.lowerBound..<helperEnd.upperBound]
            let dispatchGate = try #require(
                helperSource.range(of: "ImageEditorHistoryCommandDispatchGate.shouldDispatch")
            )
            let activeCheck = try #require(helperSource.range(of: "viewModel.hasActivePathAnchorMoveTransaction"))
            let latch = try #require(
                helperSource[activeCheck.upperBound...].range(of: "isPathAnchorDragCancelled = true")
            )
            let modelCall = try #require(
                helperSource.range(of: helperName == "performUndo" ? "viewModel.undo()" : "viewModel.redo()")
            )
            #expect(dispatchGate.lowerBound < activeCheck.lowerBound)
            #expect(activeCheck.lowerBound < latch.lowerBound)
            #expect(latch.lowerBound < modelCall.lowerBound)
        }

        let historyButtonsStart = try #require(source.range(of: "private var optionHistoryButtons"))
        let historyButtonsEnd = try #require(
            source[historyButtonsStart.upperBound...].range(of: "private var usesBrushOptions")
        )
        let historyButtonsSource = source[historyButtonsStart.lowerBound..<historyButtonsEnd.lowerBound]
        #expect(historyButtonsSource.contains("performUndo()"))
        #expect(historyButtonsSource.contains("performRedo()"))

        let activeChangeStart = try #require(
            source.range(of: ".onChange(of: viewModel.hasActivePathAnchorMoveTransaction)")
        )
        let activeChangeEnd = try #require(
            source[activeChangeStart.upperBound...].range(of: ".onChange(of: viewModel.selectedLayerFigmaSizeConstraints)")
        )
        let activeChangeSource = source[activeChangeStart.lowerBound..<activeChangeEnd.lowerBound]
        #expect(activeChangeSource.contains("if !isActive, isMovingPathAnchor"))
        #expect(activeChangeSource.contains("isPathAnchorDragCancelled = true"))

        #expect(source.contains("hasActivePathAnchorMoveTransaction: viewModel.hasActivePathAnchorMoveTransaction"))
        #expect(source.contains("case .undo: performUndo()"))
        #expect(source.contains("case .redo: performRedo()"))
        #expect(source.contains("if isPathAnchorDragCancelled {\n                    return\n                }"))
    }

    @Test func pendingPenHistoryAndEscapeOwnTheTransientPointerSequence() throws {
        let viewSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let modelSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorViewModel.swift"),
            encoding: .utf8
        )
        let menuSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let applicationCommandSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent(
                "veilpic/XomoApplicationCommands.swift"
            ),
            encoding: .utf8
        )

        let cancelStart = try #require(viewSource.range(of: "cancelSelectedObject: {"))
        let cancelEnd = try #require(
            viewSource[cancelStart.upperBound...].range(of: "if isMovingTransformReferencePoint")
        )
        let cancelSource = viewSource[cancelStart.lowerBound..<cancelEnd.lowerBound]
        let pendingCancel = try #require(cancelSource.range(of: "viewModel.cancelPenPath()"))
        let pendingLatch = try #require(
            cancelSource[pendingCancel.upperBound...].range(of: "isPathAnchorDragCancelled = true")
        )
        #expect(pendingCancel.lowerBound < pendingLatch.lowerBound)

        for helperName in ["performUndo", "performRedo"] {
            let start = try #require(viewSource.range(of: "func \(helperName)()"))
            let end = try #require(viewSource[start.upperBound...].range(of: "\n    }"))
            let source = viewSource[start.lowerBound..<end.upperBound]
            let pointerGuard = try #require(source.range(of: "isPenPointerSequenceActive"))
            let pendingCheck = try #require(source.range(of: "viewModel.hasPendingPenPathTransaction"))
            let pointerLatch = try #require(
                source[pointerGuard.upperBound...].range(of: "isPathAnchorDragCancelled = true")
            )
            let pendingLatch = try #require(
                source[pendingCheck.upperBound...].range(of: "isPathAnchorDragCancelled = true")
            )
            let modelCall = try #require(
                source.range(of: helperName == "performUndo" ? "viewModel.undo()" : "viewModel.redo()")
            )
            #expect(pointerGuard.lowerBound < pointerLatch.lowerBound)
            #expect(pointerLatch.lowerBound < pendingCheck.lowerBound)
            #expect(pendingCheck.lowerBound < pendingLatch.lowerBound)
            #expect(pendingLatch.lowerBound < modelCall.lowerBound)
        }

        for commandName in ["undo", "redo"] {
            let start = try #require(modelSource.range(of: "func \(commandName)()"))
            let sourceAfterStart = modelSource[start.lowerBound...]
            let end = try #require(sourceAfterStart.dropFirst().range(of: "\n    func "))
            let source = sourceAfterStart[..<end.lowerBound]
            let pendingCheck = try #require(source.range(of: "hasPendingPenPathTransaction"))
            let transientCommand = try #require(
                source.range(of: commandName == "undo" ? "undoPendingPenPoint()" : "redoPendingPenPoint()")
            )
            let documentStack = try #require(
                source.range(of: commandName == "undo" ? "undoStack.popLast()" : "redoStack.popLast()")
            )
            #expect(pendingCheck.lowerBound < transientCommand.lowerBound)
            #expect(transientCommand.lowerBound < documentStack.lowerBound)
        }

        #expect(viewSource.contains("if !isPathAnchorDragCancelled {\n                            let action = pendingPenCreationAction"))
        #expect(viewSource.contains("viewModel.addPenPoint(\n                                action?.anchorPoint,"))
        #expect(viewSource.contains("isPenPointerSequenceActive = canvasInteractionTool == .pen"))
        #expect(viewSource.contains("isPenPointerSequenceActive = false"))
        #expect(viewSource.contains("beginCanvasPointerSequence()"))
        #expect(viewSource.contains("viewModel.selectedTool == .pen || viewModel.hasPendingPenPathTransaction"))
        #expect(viewSource.contains(".disabled(!viewModel.hasPendingPenPathTransaction)"))
        #expect(menuSource.contains("undo: performUndo"))
        #expect(menuSource.contains("redo: performRedo"))
        #expect(applicationCommandSource.contains(
            "Button(L10n.text(\"imageEditor.action.undo\")) {\n            actions?.undo()"
        ))
        #expect(applicationCommandSource.contains(
            "Button(L10n.text(\"imageEditor.action.redo\")) {\n            actions?.redo()"
        ))
    }

    @Test func canvasLifecycleInterruptionsCancelPathDragAndFreshMouseDownReleasesLatch() throws {
        let viewSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let bridgeSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorScrollZoom.swift"),
            encoding: .utf8
        )

        let cancelStart = try #require(
            viewSource.range(of: "private func cancelPathAnchorDragForCanvasLifecycle()")
        )
        let beginStart = try #require(
            viewSource[cancelStart.upperBound...].range(of: "private func beginCanvasPointerSequence()")
        )
        let cancelSource = viewSource[cancelStart.lowerBound..<beginStart.lowerBound]
        #expect(cancelSource.contains("ImageEditorPathAnchorDragLifecyclePolicy.shouldCancel"))
        let latch = try #require(cancelSource.range(of: "isPathAnchorDragCancelled = true"))
        let modelCancel = try #require(cancelSource.range(of: "viewModel.cancelMovingPathAnchor()"))
        #expect(latch.lowerBound < modelCancel.lowerBound)

        let beginEnd = try #require(
            viewSource[beginStart.upperBound...].range(of: "private var colorChips")
        )
        let beginSource = viewSource[beginStart.lowerBound..<beginEnd.lowerBound]
        #expect(beginSource.contains("shouldReleaseCancellationLatch"))
        #expect(beginSource.contains("isPathAnchorDragCancelled = false"))
        #expect(beginSource.contains("isMovingPathAnchor = false"))

        #expect(viewSource.contains("onCanvasPointerSequenceBegan: {\n                            beginCanvasPointerSequence()"))
        let lifecycleStart = try #require(
            viewSource.range(of: "onCanvasLifecycleInterrupted: { _ in")
        )
        let lifecycleEnd = try #require(
            viewSource[lifecycleStart.upperBound...].range(of: "onZoom:")
        )
        let lifecycleSource = viewSource[lifecycleStart.lowerBound..<lifecycleEnd.lowerBound]
        #expect(lifecycleSource.contains("objectSelectionBoxDrag = nil"))
        #expect(lifecycleSource.contains("eyedropperSamplingRing = nil"))
        #expect(lifecycleSource.contains("cancelPathAnchorDragForCanvasLifecycle()"))
        let disappearStart = try #require(viewSource.range(of: ".onDisappear {"))
        let disappearEnd = try #require(
            viewSource[disappearStart.upperBound...].range(of: ".onAppear {")
        )
        let disappearSource = viewSource[disappearStart.lowerBound..<disappearEnd.lowerBound]
        #expect(disappearSource.contains("cancelGradientOverlayCanvasHandleDragForLifecycle()"))
        #expect(disappearSource.contains("cancelPathAnchorDragForCanvasLifecycle()"))

        #expect(bridgeSource.contains("interruptCanvasLifecycle(.applicationDeactivated)"))
        #expect(bridgeSource.contains("notification.object as? NSWindow === self.window"))
        #expect(bridgeSource.contains("interruptCanvasLifecycle(.windowDeactivated)"))
        #expect(bridgeSource.contains("onCanvasLifecycleInterrupted?(.bridgeDetached)"))
        #expect(bridgeSource.contains("onCanvasPointerSequenceBegan?()"))
        #expect(bridgeSource.contains("let shouldNotifyBridgeDetached = ownsCanvasLifecycle"))
    }

    @Test func toolSidebarAndLayerContextSwitchesCancelPathDragBeforeMutation() throws {
        let viewModelSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorViewModel.swift"),
            encoding: .utf8
        )
        let pathSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorPathCommands.swift"),
            encoding: .utf8
        )

        let toolStart = try #require(viewModelSource.range(of: "func selectTool(_ tool: ImageEditorTool)"))
        let toolEnd = try #require(viewModelSource[toolStart.upperBound...].range(of: "var canvasInteractionTool"))
        let toolSource = viewModelSource[toolStart.lowerBound..<toolEnd.lowerBound]
        let toolCancel = try #require(toolSource.range(of: "cancelMovingPathAnchor()"))
        let toolMutation = try #require(toolSource.range(of: "selectedTool = tool"))
        #expect(toolSource.contains("if selectedTool != tool"))
        #expect(toolCancel.lowerBound < toolMutation.lowerBound)

        let sidebarStart = try #require(
            viewModelSource.range(of: "func selectLeftSidebarTab(_ tab: XomoLeftSidebarTab)")
        )
        let sidebarEnd = try #require(
            viewModelSource[sidebarStart.upperBound...].range(of: "func selectClassicToolShortcut")
        )
        let sidebarSource = viewModelSource[sidebarStart.lowerBound..<sidebarEnd.lowerBound]
        let sidebarCancel = try #require(sidebarSource.range(of: "cancelMovingPathAnchor()"))
        let sidebarMutation = try #require(sidebarSource.range(of: "selectedLeftSidebarTab = tab"))
        #expect(sidebarSource.contains("if selectedLeftSidebarTab != tab"))
        #expect(sidebarCancel.lowerBound < sidebarMutation.lowerBound)

        let layerStart = try #require(
            viewModelSource.range(of: "func selectLayer(_ id: UUID, editingMask: Bool = false, extendingSelection: Bool = false)")
        )
        let layerEnd = try #require(
            viewModelSource[layerStart.upperBound...].range(of: "func syncLayerSelectionAnchorToPrimarySelection")
        )
        let layerSource = viewModelSource[layerStart.lowerBound..<layerEnd.lowerBound]
        let layerCancel = try #require(layerSource.range(of: "cancelMovingPathAnchor()"))
        let layerMutation = try #require(layerSource.range(of: "document.selectedLayerID = id"))
        #expect(layerCancel.lowerBound < layerMutation.lowerBound)

        let beginStart = try #require(
            pathSource.range(of: "func beginMovingPathAnchor(\n        at point: CGPoint?,")
        )
        let beginEnd = try #require(pathSource[beginStart.upperBound...].range(of: "func moveSelectedPathAnchor"))
        let beginSource = pathSource[beginStart.lowerBound..<beginEnd.lowerBound]
        let staleCheck = try #require(beginSource.range(of: "hasActivePathAnchorMoveTransaction"))
        let staleCancel = try #require(beginSource.range(of: "cancelMovingPathAnchor()"))
        let selection = try #require(beginSource.range(of: "selectNearestPathAnchor(at: point)"))
        #expect(staleCheck.lowerBound < staleCancel.lowerBound)
        #expect(staleCancel.lowerBound < selection.lowerBound)
    }

    @Test func nudgeAndDeleteKeysLatchPathDragCancellationBeforeDiscreteCommands() throws {
        let viewSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let pathSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorPathCommands.swift"),
            encoding: .utf8
        )
        let transformSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorTransform.swift"),
            encoding: .utf8
        )

        #expect(viewSource.contains("nudgeSelected: performNudgeCommand"))
        let nudgeStart = try #require(viewSource.range(of: "func performNudgeCommand("))
        let nudgeEnd = try #require(
            viewSource[nudgeStart.upperBound...].range(of: "\n    }")
        )
        let nudgeSource = viewSource[nudgeStart.lowerBound..<nudgeEnd.upperBound]
        let nudgeGate = try #require(
            nudgeSource.range(of: "ImageEditorNudgeCommandDispatchGate.shouldDispatch")
        )
        let nudgeCancel = try #require(
            nudgeSource.range(of: "cancelPathAnchorDragForKeyboardCommand()")
        )
        let nudgeCommand = try #require(
            nudgeSource.range(of: "viewModel.nudgeSelectionOrSelectedLayer(by: delta)")
        )
        #expect(nudgeGate.lowerBound < nudgeCancel.lowerBound)
        #expect(nudgeCancel.lowerBound < nudgeCommand.lowerBound)

        let deleteStart = try #require(
            viewSource.range(of: "func deleteSelectedObjectFromKeyboard() -> Bool")
        )
        let deleteEnd = try #require(
            viewSource[deleteStart.upperBound...].range(of: "private func performKeyboardShortcut(")
        )
        let deleteSource = viewSource[deleteStart.lowerBound..<deleteEnd.lowerBound]
        let deleteCancel = try #require(
            deleteSource.range(of: "cancelPathAnchorDragForKeyboardCommand()")
        )
        let deleteCommand = try #require(
            deleteSource.range(of: "viewModel.deleteSelectedPathAnchor()")
        )
        #expect(deleteCancel.lowerBound < deleteCommand.lowerBound)

        let helperStart = try #require(
            viewSource.range(of: "private func cancelPathAnchorDragForKeyboardCommand() -> Bool")
        )
        let helperEnd = try #require(viewSource[helperStart.upperBound...].range(of: "private var colorChips"))
        let helperSource = viewSource[helperStart.lowerBound..<helperEnd.lowerBound]
        let latch = try #require(helperSource.range(of: "isPathAnchorDragCancelled = true"))
        let cancel = try #require(helperSource.range(of: "viewModel.cancelMovingPathAnchor()"))
        #expect(helperSource.contains("ImageEditorPathAnchorDragLifecyclePolicy.shouldCancel"))
        #expect(latch.lowerBound < cancel.lowerBound)

        for commandName in ["nudgeSelectedPathAnchor", "deleteSelectedPathAnchor"] {
            let commandStart = try #require(pathSource.range(of: "func \(commandName)"))
            let sourceAfterStart = pathSource[commandStart.lowerBound...]
            let commandEnd = sourceAfterStart.dropFirst().range(of: "\n    func ")
                ?? sourceAfterStart.dropFirst().range(of: "\n    var ")
            let commandSource = commandEnd.map { sourceAfterStart[..<$0.lowerBound] } ?? sourceAfterStart
            #expect(commandSource.contains(
                "guard !cancelPathAnchorDragBeforeDiscreteCommand() else { return }"
            ))
        }
        let sharedBoundaryStart = try #require(
            pathSource.range(of: "func cancelPathAnchorDragBeforeDiscreteCommand() -> Bool")
        )
        let sharedBoundarySource = pathSource[sharedBoundaryStart.lowerBound...]
        #expect(sharedBoundarySource.contains("cancelMovingPathAnchor()"))
        let generalNudgeStart = try #require(
            transformSource.range(of: "func nudgeSelectionOrSelectedLayer(by delta: CGSize)")
        )
        let generalNudgeSource = transformSource[generalNudgeStart.lowerBound...]
        let activeCheck = try #require(generalNudgeSource.range(of: "hasActivePathAnchorMoveTransaction"))
        let modelCancel = try #require(generalNudgeSource.range(of: "cancelMovingPathAnchor()"))
        #expect(activeCheck.lowerBound < modelCancel.lowerBound)
    }

    @Test func discretePathGeometryCommandsShareActiveDragCancellationBoundary() throws {
        let pathSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorPathCommands.swift"),
            encoding: .utf8
        )
        let automationSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/XomoAutomationRegistry.swift"),
            encoding: .utf8
        )
        let guardedCommands = [
            "setSelectedPathAnchorX", "setSelectedPathAnchorY", "nudgeSelectedPathAnchor",
            "selectNextPathAnchor", "selectPreviousPathAnchor", "selectNextPathSubpath",
            "selectPreviousPathSubpath", "smoothSelectedPathAnchor",
            "symmetrizeSelectedPathAnchorHandles", "moveSelectedPathSubpath",
            "duplicateSelectedPathSubpath", "clearSelectedPathAnchorHandles",
            "deleteSelectedPathAnchor", "deleteSelectedPathSubpath",
            "insertPathAnchorAfterSelection", "toggleSelectedPathClosed",
            "reverseSelectedPathDirection"
        ]
        for command in guardedCommands {
            let start = try #require(pathSource.range(of: "func \(command)"))
            let sourceAfterStart = pathSource[start.lowerBound...]
            let end = sourceAfterStart.dropFirst().range(of: "\n    func ")
                ?? sourceAfterStart.dropFirst().range(of: "\n    var ")
            let commandSource = end.map { sourceAfterStart[..<$0.lowerBound] } ?? sourceAfterStart
            #expect(commandSource.contains(
                "guard !cancelPathAnchorDragBeforeDiscreteCommand() else { return }"
            ))
        }

        let actionStart = try #require(automationSource.range(of: "private func pathAction("))
        let actionEnd = try #require(
            automationSource[actionStart.upperBound...].range(of: "private func savedPathAction(")
        )
        let actionSource = automationSource[actionStart.lowerBound..<actionEnd.lowerBound]
        let actionRead = try #require(actionSource.range(of: "let action = try requiredString"))
        let createBranch = try #require(actionSource.range(of: "if action == \"create\""))
        let selectBranch = try #require(actionSource.range(of: "if action == \"select\""))
        let createSource = actionSource[createBranch.lowerBound..<selectBranch.lowerBound]
        let createValidation = try #require(createSource.range(of: "guard points.count >= 2"))
        let createCancel = try #require(
            createSource.range(of: "viewModel.cancelPathAnchorDragBeforeDiscreteCommand()")
        )
        let selectSource = actionSource[selectBranch.lowerBound...]
        let roleValidation = try #require(selectSource.range(of: "let role: ImageEditorPathControlRole"))
        let selectCancel = try #require(
            selectSource.range(of: "viewModel.cancelPathAnchorDragBeforeDiscreteCommand()")
        )
        let selectMutation = try #require(selectSource.range(of: "viewModel.selectedPathSubpathIndex = subpath"))
        #expect(actionRead.lowerBound < createBranch.lowerBound)
        #expect(createValidation.lowerBound < createCancel.lowerBound)
        #expect(roleValidation.lowerBound < selectCancel.lowerBound)
        #expect(selectCancel.lowerBound < selectMutation.lowerBound)
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

    @Test func systemAndEditorSelectMenusShareOneFocusedCommandTree() throws {
        let menuBarSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let commandsSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/XomoApplicationCommands.swift"),
            encoding: .utf8
        )
        let appSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/veilpicApp.swift"),
            encoding: .utf8
        )
        let viewSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(commandsSource.contains("CommandMenu(L10n.text(\"imageEditor.menu.select\"))"))
        #expect(commandsSource.contains("@FocusedValue(\\.xomoSelectCommandContent)"))
        #expect(menuBarSource.contains("var xomoSelectCommandContent: XomoFocusedMenuContent"))
        #expect(menuBarSource.contains("XomoFocusedMenuContent(menuItems: AnyView(selectMenuItems))"))
        #expect(menuBarSource.contains("private var selectMenuItems: some View"))
        #expect(appSource.contains("XomoSelectCommands()"))
        #expect(viewSource.contains(".focusedSceneValue(\\.xomoSelectCommandContent, xomoSelectCommandContent)"))
    }

    @Test func selectMenuExposesSavedSelectionCommandsInPhotoshopStyleLocation() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let selectMenuStart = try #require(source.range(of: "private var selectMenuItems: some View"))
        let nextMenuStart = try #require(
            source[selectMenuStart.upperBound...].range(of: "private var alphaChannelMenu: some View")
        )
        let selectMenuSource = source[selectMenuStart.lowerBound..<nextMenuStart.lowerBound]
        let selectMenuText = String(selectMenuSource)

        #expect(selectMenuSource.contains("imageEditor.action.saveSelection"))
        #expect(selectMenuSource.contains("viewModel.saveCurrentSelection()"))
        #expect(selectMenuSource.contains("viewModel.hasEffectiveSelectionPixels"))
        #expect(selectMenuSource.contains("imageEditor.action.restoreSelection"))
        #expect(selectMenuSource.contains("viewModel.restoreSavedSelection()"))
        #expect(selectMenuSource.contains("viewModel.hasSavedSelection"))
        #expect(selectMenuText.components(separatedBy: "imageEditor.action.saveSelection").count == 2)
        #expect(selectMenuText.components(separatedBy: "imageEditor.action.restoreSelection").count == 2)
    }

    @Test func selectMenuExposesClassicSelectionShortcuts() throws {
        let menuSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let viewSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let selectMenuStart = try #require(menuSource.range(of: "private var selectMenuItems: some View"))
        let nextMenuStart = try #require(
            menuSource[selectMenuStart.upperBound...].range(of: "private var alphaChannelMenu: some View")
        )
        let selectMenuSource = menuSource[selectMenuStart.lowerBound..<nextMenuStart.lowerBound]

        #expect(selectMenuSource.contains("performSelectionCommand(.selectAll)"))
        #expect(selectMenuSource.contains(".keyboardShortcut(\"a\", modifiers: [.command])"))
        #expect(selectMenuSource.contains("performSelectionCommand(.clear)"))
        #expect(selectMenuSource.contains(".keyboardShortcut(\"d\", modifiers: [.command])"))
        #expect(selectMenuSource.contains("performSelectionCommand(.reselect)"))
        #expect(selectMenuSource.contains(".keyboardShortcut(\"d\", modifiers: [.command, .shift])"))
        #expect(selectMenuSource.contains("performSelectionCommand(.invert)"))
        #expect(selectMenuSource.contains(".keyboardShortcut(\"i\", modifiers: [.command, .shift])"))
        #expect(selectMenuSource.contains("viewModel.featherSelection()"))
        #expect(selectMenuSource.contains(".keyboardShortcut(\"d\", modifiers: [.command, .option])"))

        let helperStart = try #require(viewSource.range(of: "func performSelectionCommand("))
        let helperEnd = try #require(
            viewSource[helperStart.upperBound...].range(of: "\n    }")
        )
        let helperSource = viewSource[helperStart.lowerBound..<helperEnd.upperBound]
        let gate = try #require(
            helperSource.range(of: "ImageEditorSelectionCommandDispatchGate.shouldDispatch")
        )
        let inversion = try #require(helperSource.range(of: "viewModel.invertSelection()"))
        #expect(gate.lowerBound < inversion.lowerBound)
        #expect(viewSource.contains("case .selectAll: performSelectionCommand(.selectAll)"))
        #expect(viewSource.contains("case .clearSelection: performSelectionCommand(.clear)"))
        #expect(viewSource.contains("case .reselectSelection: performSelectionCommand(.reselect)"))
        #expect(viewSource.contains("case .invertSelection: performSelectionCommand(.invert)"))
    }

    @Test func selectMenuSeparatesStructuralSelectionActionsFromPixelGeometry() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let selectMenuStart = try #require(source.range(of: "private var selectMenuItems: some View"))
        let nextMenuStart = try #require(
            source[selectMenuStart.upperBound...].range(of: "private var alphaChannelMenu: some View")
        )
        let selectMenuSource = String(source[selectMenuStart.lowerBound..<nextMenuStart.lowerBound])

        #expect(
            selectMenuSource.components(
                separatedBy: ".disabled(!canModifySelectionGeometry)"
            ).count - 1 == 8
        )
        #expect(
            selectMenuSource.components(
                separatedBy: "let canModifySelectionGeometry = viewModel.canModifySelectionGeometry"
            ).count - 1 == 1
        )
        #expect(
            selectMenuSource.components(
                separatedBy: ".disabled(!viewModel.hasSelection)"
            ).count - 1 == 2
        )
        #expect(selectMenuSource.contains("performSelectionCommand(.clear)"))
        #expect(selectMenuSource.contains("performSelectionCommand(.invert)"))
        #expect(selectMenuSource.contains("performToggleQuickMask()"))
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
        let windowMenuStart = try #require(source.range(of: "private var windowMenuItems: some View"))
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
        #expect(windowMenuSource.contains("ImageEditorPanelToggleDispatchGate"))
        #expect(windowMenuSource.contains("imageEditor.action.statusBarHide"))
        #expect(windowMenuSource.contains("imageEditor.action.statusBarShow"))
        #expect(windowMenuSource.contains("viewModel.toggleStatusBarVisibility()"))
    }

    @Test func systemWindowMenuExtendsNativeCommandsWithTheSharedEditorTree() throws {
        let menuBarSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let commandsSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/XomoApplicationCommands.swift"),
            encoding: .utf8
        )
        let appSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/veilpicApp.swift"),
            encoding: .utf8
        )
        let viewSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(commandsSource.contains("@FocusedValue(\\.xomoWindowCommandContent)"))
        #expect(commandsSource.contains("CommandGroup(after: .windowArrangement)"))
        #expect(!commandsSource.contains("CommandMenu(L10n.text(\"imageEditor.menu.window\"))"))
        #expect(menuBarSource.contains("var xomoWindowCommandContent: XomoFocusedMenuContent"))
        #expect(menuBarSource.contains("XomoFocusedMenuContent(menuItems: AnyView(windowMenuItems))"))
        #expect(appSource.contains("XomoWindowCommands()"))
        #expect(viewSource.contains(".focusedSceneValue(\\.xomoWindowCommandContent, xomoWindowCommandContent)"))
    }

    @Test func macOSUsesNativeMenusAndWindowChromeKeepsOnlyQuickActions() throws {
        let menuBarSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let viewSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let actionBarStart = try #require(menuBarSource.range(of: "var quickActionBar: some View"))
        let actionBarEnd = try #require(
            menuBarSource[actionBarStart.upperBound...].range(of: "var xomoFileCommandActions: XomoFileCommandActions")
        )
        let actionBarSource = menuBarSource[actionBarStart.lowerBound..<actionBarEnd.lowerBound]

        #expect(!actionBarSource.contains("Menu {"))
        #expect(!actionBarSource.contains("image-editor-menu-"))
        #expect(viewSource.contains("quickActionBar"))
        #expect(!viewSource.contains("\n            menuBar\n"))
        for action in ["project-open", "project-save", "cancel", "preview", "export"] {
            #expect(actionBarSource.contains("image-editor-action-\(action)"))
        }
        #expect(actionBarSource.components(separatedBy: ".focusable(false)").count - 1 == 5)
    }

    @Test func deleteKeysPrioritizePendingPenPathBeforeDocumentObjects() throws {
        let viewSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let pathSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorPathCommands.swift"),
            encoding: .utf8
        )

        #expect(viewSource.contains("deleteSelectedObject: deleteSelectedObjectFromKeyboard"))
        let deleteStart = try #require(
            viewSource.range(of: "func deleteSelectedObjectFromKeyboard() -> Bool")
        )
        let deleteEnd = try #require(
            viewSource[deleteStart.upperBound...].range(of: "private func performKeyboardShortcut(")
        )
        let deleteSource = viewSource[deleteStart.lowerBound..<deleteEnd.lowerBound]
        let dragCancel = try #require(deleteSource.range(of: "cancelPathAnchorDragForKeyboardCommand()"))
        let pointerPolicy = try #require(deleteSource.range(of: "ImageEditorPendingPenPointerPolicy"))
        let pointerLatch = try #require(
            deleteSource[pointerPolicy.upperBound...].range(of: "isPathAnchorDragCancelled = true")
        )
        let pendingDelete = try #require(deleteSource.range(of: "viewModel.deletePendingPenPointIfNeeded()"))
        let documentDelete = try #require(deleteSource.range(of: "viewModel.deleteSelectedPathAnchor()"))
        let componentDelete = try #require(
            deleteSource.range(of: "viewModel.deleteSelectedXomoObjectIfNeeded()")
        )
        let layerDelete = try #require(
            deleteSource.range(of: "viewModel.deleteSelectedLayerFromKeyboardIfPossible()")
        )
        let documentPolicy = try #require(
            deleteSource.range(of: "ImageEditorContextualDocumentDeletePolicy.resolve(")
        )
        #expect(dragCancel.lowerBound < pointerPolicy.lowerBound)
        #expect(pointerPolicy.lowerBound < pointerLatch.lowerBound)
        #expect(pointerLatch.lowerBound < pendingDelete.lowerBound)
        #expect(pendingDelete.lowerBound < documentDelete.lowerBound)
        #expect(documentDelete.lowerBound < componentDelete.lowerBound)
        #expect(componentDelete.lowerBound < documentPolicy.lowerBound)
        #expect(documentPolicy.lowerBound < layerDelete.lowerBound)

        let commandStart = try #require(pathSource.range(of: "func deletePendingPenPointIfNeeded()"))
        let commandEnd = try #require(
            pathSource[commandStart.upperBound...].range(of: "func beginMovingPathAnchor")
        )
        let commandSource = pathSource[commandStart.lowerBound..<commandEnd.lowerBound]
        let ownership = try #require(commandSource.range(of: "hasPendingPenPathTransaction"))
        let transientDelete = try #require(commandSource.range(of: "undoPendingPenPoint()"))
        #expect(ownership.lowerBound < transientDelete.lowerBound)
        #expect(commandSource.contains("return true"))

        #expect(viewSource.contains("let isDelete = event.keyCode == 51 || event.keyCode == 117"))
        #expect(viewSource.contains("deleteSelectedObject()"))
    }

    @Test func returnAndKeypadEnterFinishPendingPenPathBeforeWindowDefaults() throws {
        let viewSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let pathSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorPathCommands.swift"),
            encoding: .utf8
        )

        let monitorStart = try #require(viewSource.range(of: "ImageEditorKeyboardShortcutMonitor("))
        let monitorEnd = try #require(viewSource[monitorStart.upperBound...].range(of: ".allowsHitTesting(false)"))
        let monitorSource = viewSource[monitorStart.lowerBound..<monitorEnd.lowerBound]
        let finishCallback = try #require(monitorSource.range(of: "finishPendingPenPath: {"))
        let pointerPolicy = try #require(
            monitorSource[finishCallback.upperBound...].range(of: "ImageEditorPendingPenPointerPolicy")
        )
        let pointerLatch = try #require(
            monitorSource[pointerPolicy.upperBound...].range(of: "isPathAnchorDragCancelled = true")
        )
        let finishCommand = try #require(
            monitorSource[pointerLatch.upperBound...].range(of: "viewModel.finishPendingPenPathFromKeyboard()")
        )
        #expect(finishCallback.lowerBound < pointerPolicy.lowerBound)
        #expect(pointerPolicy.lowerBound < pointerLatch.lowerBound)
        #expect(pointerLatch.lowerBound < finishCommand.lowerBound)

        let modelStart = try #require(pathSource.range(of: "func finishPendingPenPathFromKeyboard()"))
        let modelEnd = try #require(pathSource[modelStart.upperBound...].range(of: "func beginMovingPathAnchor"))
        let modelSource = pathSource[modelStart.lowerBound..<modelEnd.lowerBound]
        let ownership = try #require(modelSource.range(of: "hasPendingPenPathTransaction"))
        let openFinish = try #require(modelSource.range(of: "finishPenPath(closed: false)"))
        #expect(ownership.lowerBound < openFinish.lowerBound)
        #expect(modelSource.contains("return true"))

        #expect(viewSource.contains("let finishPendingPenPath: () -> Bool"))
        #expect(viewSource.contains("context.coordinator.finishPendingPenPath = finishPendingPenPath"))
        #expect(viewSource.contains("self.finishPendingPenPath = finishPendingPenPath"))
        #expect(viewSource.contains("ImageEditorPendingPenFinishKeyPolicy.matches("))
        #expect(viewSource.contains("finishPendingPenPath()"))
        #expect(viewSource.contains("!isTextInputActive"))
    }

    @Test func commandClickFinishesPendingPenPathWithoutAddingAnotherAnchor() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        let penEndStart = try #require(
            source.range(
                of: "case .pen:\n                    if isPenAnchorConversionGestureActive {\n                        if !isPathAnchorDragCancelled"
            )
        )
        let penEnd = try #require(
            source[penEndStart.upperBound...].range(of: "case .pathSelection:")
        )
        let penEndSource = source[penEndStart.lowerBound..<penEnd.lowerBound]
        let policy = try #require(
            penEndSource.range(of: "ImageEditorPendingPenPointerFinishPolicy.shouldFinishOpenPath(")
        )
        let finish = try #require(
            penEndSource[policy.upperBound...].range(of: "viewModel.finishPenPath(closed: false)")
        )
        let addPoint = try #require(
            penEndSource[finish.upperBound...].range(of: "viewModel.addPenPoint(")
        )
        #expect(policy.lowerBound < finish.lowerBound)
        #expect(finish.lowerBound < addPoint.lowerBound)
        #expect(penEndSource.contains("let action = pendingPenCreationAction"))
        #expect(penEndSource.contains("endImagePoint: endImagePoint"))
        #expect(penEndSource[addPoint.lowerBound...].contains("action?.anchorPoint,"))
        #expect(penEndSource[addPoint.lowerBound...].contains("constrainedToAngleIncrement:"))
        #expect(penEndSource.contains("hasPendingPath: viewModel.hasPendingPenPathTransaction"))
        #expect(penEndSource.contains("modifierFlags: NSEvent.modifierFlags"))

        let policyStart = try #require(
            source.range(of: "enum ImageEditorPendingPenPointerFinishPolicy")
        )
        let policyEnd = try #require(
            source[policyStart.upperBound...].range(of: "struct ImageEditorKeyboardShortcutMonitor")
        )
        let policySource = source[policyStart.lowerBound..<policyEnd.lowerBound]
        #expect(policySource.contains("hasPendingPath && relevantFlags == [.command]"))
    }

    @Test func penShiftClickConstrainsNewAnchorBeforeAddingIt() throws {
        let viewSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let pathSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorPathCommands.swift"),
            encoding: .utf8
        )

        let penEndStart = try #require(
            viewSource.range(
                of: "case .pen:\n                    if isPenAnchorConversionGestureActive {\n                        if !isPathAnchorDragCancelled"
            )
        )
        let penEnd = try #require(
            viewSource[penEndStart.upperBound...].range(of: "case .pathSelection:")
        )
        let penEndSource = viewSource[penEndStart.lowerBound..<penEnd.lowerBound]
        #expect(penEndSource.contains("viewModel.addPenPoint("))
        #expect(penEndSource.contains("constrainedToAngleIncrement: canvasModifierFlags.contains(.shift)"))

        let addStart = try #require(pathSource.range(of: "func addPenPoint(\n        _ point: CGPoint?,"))
        let addEnd = try #require(pathSource[addStart.upperBound...].range(of: "func undoPendingPenPoint"))
        let addSource = pathSource[addStart.lowerBound..<addEnd.lowerBound]
        let closeCheck = try #require(addSource.range(of: "isPenCloseCandidate(at: point)"))
        let constraint = try #require(
            addSource.range(of: "ImageEditorPenPointGeometry.constrainedPoint(")
        )
        let append = try #require(addSource.range(of: "pendingPenPathAnchors.append(ImageEditorPathAnchor("))
        #expect(closeCheck.lowerBound < constraint.lowerBound)
        #expect(constraint.lowerBound < append.lowerBound)
        #expect(addSource.contains("let previousPoint = pendingPenPathPoints.last"))
        #expect(pathSource.contains(
            "func addPenPoint(_ point: CGPoint?) {\n        addPenPoint(\n            point,\n            symmetricControlDrag: nil,"
        ))
    }

    @Test func pendingPenOverlayUsesTheSameConstrainedPointAsCommit() throws {
        let viewSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let pathSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorPathCommands.swift"),
            encoding: .utf8
        )

        let overlayStart = try #require(viewSource.range(of: "private func dragOverlay(in size: CGSize)"))
        let overlayEnd = try #require(
            viewSource[overlayStart.upperBound...].range(of: "private var shouldShowDragRect")
        )
        let overlaySource = viewSource[overlayStart.lowerBound..<overlayEnd.lowerBound]
        #expect(overlaySource.contains("let previewPoint = pendingPenPreviewViewPoint(in: size)"))
        #expect(overlaySource.contains("previewPath.move(to: last.point)"))
        #expect(overlaySource.contains("previewPath.addLine(to: previewPoint)"))
        #expect(overlaySource.contains("viewModel.pendingPenPathAnchors.map"))
        #expect(overlaySource.contains("previewPath.addCurve("))
        #expect(overlaySource.contains("pendingPenCreationAction.map"))
        #expect(overlaySource.contains("isPointerInsideCanvas"))
        #expect(overlaySource.contains("canvasInteractionTool == .pen"))
        #expect(overlaySource.contains("viewModel.pendingPenPreviewPoint("))
        #expect(overlaySource.contains("constrainedToAngleIncrement: canvasModifierFlags.contains(.shift)"))

        let previewStart = try #require(pathSource.range(of: "func pendingPenPreviewPoint("))
        let previewEnd = try #require(
            pathSource[previewStart.upperBound...].range(of: "func undoPendingPenPoint")
        )
        let previewSource = pathSource[previewStart.lowerBound..<previewEnd.lowerBound]
        let closeCheck = try #require(previewSource.range(of: "isPenCloseCandidate(at: point)"))
        let firstPoint = try #require(previewSource.range(of: "return pendingPenPathPoints.first"))
        let constraint = try #require(
            previewSource.range(of: "ImageEditorPenPointGeometry.constrainedPoint(")
        )
        #expect(closeCheck.lowerBound < firstPoint.lowerBound)
        #expect(firstPoint.lowerBound < constraint.lowerBound)
    }

    @Test func penClickDragWiresLiveSmoothActionThroughCommitAndCleanup() throws {
        let viewSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let changedStart = try #require(
            viewSource.range(of: "case .pen:\n                    if isPenAnchorConversionGestureActive {")
        )
        let changedEnd = try #require(
            viewSource[changedStart.upperBound...].range(of: "case .pathSelection:")
        )
        let changedSource = viewSource[changedStart.lowerBound..<changedEnd.lowerBound]
        #expect(changedSource.contains("pendingPenCreationAction = ImageEditorPendingPenGesturePolicy.resolve("))
        #expect(changedSource.contains("startImagePoint: imagePoint(from: value.startLocation, in: size)"))
        #expect(changedSource.contains("viewTranslation: value.translation"))

        let endedStart = try #require(
            viewSource.range(of: "case .pen:\n                    if isPenAnchorConversionGestureActive {\n                        if !isPathAnchorDragCancelled")
        )
        let endedEnd = try #require(
            viewSource[endedStart.upperBound...].range(of: "case .pathSelection:")
        )
        let endedSource = viewSource[endedStart.lowerBound..<endedEnd.lowerBound]
        #expect(endedSource.contains("let action = pendingPenCreationAction"))
        #expect(endedSource.contains("symmetricControlDrag: action?.symmetricControlDrag"))
        #expect(viewSource.contains("pendingPenCreationAction = nil\n                resetPenAnchorConversionGesture()"))
        let disappearStart = try #require(viewSource.range(of: ".onDisappear {"))
        let disappearEnd = try #require(
            viewSource[disappearStart.upperBound...].range(of: ".onAppear {")
        )
        let disappearSource = viewSource[disappearStart.lowerBound..<disappearEnd.lowerBound]
        let lifecycleCancel = try #require(
            disappearSource.range(of: "cancelPathAnchorDragForCanvasLifecycle()")
        )
        let pendingCleanup = try #require(
            disappearSource.range(of: "pendingPenCreationAction = nil")
        )
        #expect(lifecycleCancel.lowerBound < pendingCleanup.lowerBound)
    }

    @Test func optionClickAndDragConversionCommitOnlyAtPenMouseUp() throws {
        let viewSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let pathSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorPathCommands.swift"),
            encoding: .utf8
        )
        let changedStart = try #require(
            viewSource.range(of: "case .pen:\n                    if isPenAnchorConversionGestureActive {")
        )
        let changedEnd = try #require(
            viewSource[changedStart.upperBound...].range(of: "case .pathSelection:")
        )
        let changedSource = viewSource[changedStart.lowerBound..<changedEnd.lowerBound]
        let modifier = try #require(changedSource.range(of: "NSEvent.modifierFlags.contains(.option)"))
        let anchorHit = try #require(changedSource.range(of: "viewModel.penAnchorConversionTarget("))
        let latch = try #require(changedSource.range(of: "isPenAnchorConversionGestureActive = true"))
        let targetLatch = try #require(changedSource.range(of: "penAnchorConversionTarget = target"))
        let preview = try #require(
            changedSource[latch.upperBound...].range(
                of: "penAnchorConversionAction = ImageEditorPenAnchorConversionGesturePolicy.resolve("
            )
        )
        let creation = try #require(
            changedSource.range(of: "pendingPenCreationAction = ImageEditorPendingPenGesturePolicy.resolve(")
        )
        #expect(modifier.lowerBound < anchorHit.lowerBound)
        #expect(anchorHit.lowerBound < latch.lowerBound)
        #expect(latch.lowerBound < targetLatch.lowerBound)
        #expect(targetLatch.lowerBound < preview.lowerBound)
        #expect(preview.lowerBound < creation.lowerBound)
        #expect(!changedSource.contains("viewModel.convertPathAnchor("))

        let endedStart = try #require(
            viewSource.range(of: "case .pen:\n                    if isPenAnchorConversionGestureActive {\n                        if !isPathAnchorDragCancelled")
        )
        let endedEnd = try #require(
            viewSource[endedStart.upperBound...].range(of: "case .pathSelection:")
        )
        let endedSource = viewSource[endedStart.lowerBound..<endedEnd.lowerBound]
        #expect(endedSource.contains("ImageEditorPenAnchorConversionGesturePolicy.resolve("))
        #expect(endedSource.contains("viewModel.convertPathAnchor("))
        #expect(endedSource.contains("target: target"))
        #expect(endedSource.contains("symmetricControlDrag: action.symmetricControlDrag"))
        #expect(viewSource.contains(
            "resetPenAnchorConversionGesture()\n"
                + "                penAnchorDeletionGestureState = .none\n"
                + "                penPathContinuationGestureState = .none\n"
                + "                activeResizeHandle = nil"
        ))
        #expect(viewSource.contains("private func cancelPenAnchorConversionGesture() -> Bool"))
        #expect(viewSource.contains("guard isPenAnchorConversionGestureActive else { return false }\n        isPathAnchorDragCancelled = true\n        resetPenAnchorConversionGesture()"))
        #expect(viewSource.contains("private func cancelPathAnchorDragForCanvasLifecycle() {\n        if cancelPenAnchorConversionGesture()"))
        #expect(viewSource.contains(".onChange(of: viewModel.selectedTool) { _ in\n            _ = cancelPenAnchorConversionGesture()"))
        #expect(viewSource.contains(".onChange(of: viewModel.selectedLeftSidebarTab) { tab in\n                    activeBrushPressure = nil\n                    activeBrushTilt = nil\n                    _ = cancelPenAnchorConversionGesture()"))
        #expect(pathSource.contains("Returning true means the existing anchor consumed the pointer"))
        #expect(pathSource.contains("let targetControls = symmetricControlDrag.flatMap"))
        #expect(pathSource.contains("canvasAnchors[target.anchorIndex].inControl = targetInControl"))
        #expect(pathSource.contains("canvasAnchors[target.anchorIndex].outControl = targetOutControl"))
        #expect(viewSource.contains("penAnchorConversionTarget = nil"))
        let overlayStart = try #require(
            viewSource.range(of: "if !isPenAnchorConversionGestureBlocked,\n           let action = penAnchorConversionAction")
        )
        let overlayEnd = try #require(
            viewSource[overlayStart.upperBound...].range(of: "if let anchorPoints = selectedPathAnchorOverlayPoints")
        )
        let overlaySource = viewSource[overlayStart.lowerBound..<overlayEnd.lowerBound]
        #expect(overlaySource.contains("ImageEditorPenPointGeometry.symmetricControls("))
        #expect(overlaySource.contains("Color.orange"))
    }

    @Test func pendingPenContinuationWiresJoinHitPreviewAndCommit() throws {
        let viewSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let pathSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent(
                "veilpic/ImageEditorPathCommands.swift"
            ),
            encoding: .utf8
        )
        let resolverStart = try #require(
            viewSource.range(of: "private func resolvedPenPathContinuationState(")
        )
        let resolverEnd = try #require(
            viewSource[resolverStart.upperBound...].range(of: "@discardableResult")
        )
        let resolver = viewSource[resolverStart.lowerBound..<resolverEnd.lowerBound]
        #expect(resolver.contains("if viewModel.hasPendingPenPathTransaction"))
        #expect(resolver.contains("return viewModel.penPathJoinState(at: canvasPoint)"))

        let addStart = try #require(pathSource.range(of: "func addPenPoint(\n        _ point: CGPoint?,\n        symmetricControlDrag:"))
        let addEnd = try #require(pathSource[addStart.upperBound...].range(of: "func pendingPenPreviewPoint("))
        let addSource = pathSource[addStart.lowerBound..<addEnd.lowerBound]
        #expect(addSource.contains("if joinPendingPenPath(at: point"))
        #expect(addSource.contains("symmetricControlDrag: symmetricControlDrag"))

        let previewStart = try #require(pathSource.range(of: "func pendingPenPreviewPoint("))
        let previewEnd = try #require(pathSource[previewStart.upperBound...].range(of: "func undoPendingPenPoint("))
        let previewSource = pathSource[previewStart.lowerBound..<previewEnd.lowerBound]
        #expect(previewSource.contains("if let joinTarget = penPathJoinTarget(at: point)"))
        #expect(previewSource.contains("return joinTarget.anchorPoint"))

        let targetStart = try #require(pathSource.range(of: "func penPathJoinTarget(at point: CGPoint?)"))
        let targetEnd = try #require(
            pathSource[targetStart.upperBound...].range(of: "@discardableResult\n    func beginPenPathContinuation")
        )
        let targetSource = pathSource[targetStart.lowerBound..<targetEnd.lowerBound]
        #expect(targetSource.contains("guard !pendingPenPathAnchors.isEmpty"))
        #expect(!targetSource.contains("pendingPenContinuationLayerID != nil"))

        let joinStart = try #require(pathSource.range(of: "private func joinPendingPenPath("))
        let joinEnd = try #require(pathSource[joinStart.upperBound...].range(of: "private func clearPendingPenPath()"))
        let joinSource = pathSource[joinStart.lowerBound..<joinEnd.lowerBound]
        let newBranchStart = try #require(
            joinSource.range(of: "guard let sourceLayerID = pendingPenContinuationLayerID else {")
        )
        let existingSourceStart = try #require(
            joinSource[newBranchStart.upperBound...].range(of: "guard sourceLayerID != target.layerID")
        )
        let newBranchSource = joinSource[newBranchStart.lowerBound..<existingSourceStart.lowerBound]
        #expect(newBranchSource.contains("updatePathLayer(\n                at: targetIndex"))
        #expect(newBranchSource.contains("document.selectedLayerID = target.layerID"))
        #expect(newBranchSource.contains("document.selectedLayerIDs = [target.layerID]"))
        #expect(!newBranchSource.contains("document.layers.remove"))
        #expect(newBranchSource.contains("clearPendingPenPath()"))
        #expect(pathSource.contains("appendHistory(L10n.text(\"imageEditor.history.pathJoin\"))"))
        #expect(pathSource.contains("statusText = L10n.text(\"imageEditor.status.pathJoined\")"))
    }

    @Test func directSelectionLocksTopmostHitAndPointerSequenceToMouseDown() throws {
        let viewSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let pathSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent(
                "veilpic/ImageEditorPathCommands.swift"
            ),
            encoding: .utf8
        )

        let directStart = try #require(viewSource.range(of: "case .directSelection:\n                    if !isDirectPathGestureResolved"))
        let directEnd = try #require(viewSource[directStart.upperBound...].range(of: "case .lasso:"))
        let directGesture = viewSource[directStart.lowerBound..<directEnd.lowerBound]
        #expect(directGesture.contains("isDirectPathGestureResolved = true"))
        #expect(directGesture.contains("imagePoint(from: value.startLocation, in: size)"))
        #expect(directGesture.contains("directPathAnchorState(at: pointerStart) == .available"))
        #expect(directGesture.contains("beginDirectPathAnchorMove(\n                                at: pointerStart"))
        #expect(directGesture.contains("} else if isMovingPathAnchor {"))
        #expect(viewSource.components(
            separatedBy: "directSelectionIsBlocked: canvasInteractionTool == .directSelection"
        ).count == 3)
        #expect(viewSource.components(separatedBy: "isDirectPathGestureResolved = false").count >= 3)

        let stateStart = try #require(pathSource.range(of: "func directPathAnchorState(at point: CGPoint?)"))
        let stateEnd = try #require(pathSource[stateStart.upperBound...].range(of: "@discardableResult\n    func beginDirectPathAnchorMove"))
        let stateSource = pathSource[stateStart.lowerBound..<stateEnd.lowerBound]
        #expect(stateSource.contains("let hit = penPathInsertionHit(at: point)"))
        #expect(stateSource.contains("case .control(let control):"))
        #expect(stateSource.contains("case .segment(let segment):"))
        #expect(stateSource.contains("? .blocked\n                : .occluded"))

        let beginStart = try #require(pathSource.range(of: "func beginDirectPathAnchorMove("))
        let beginEnd = try #require(pathSource[beginStart.upperBound...].range(of: "private func pathLayerContains("))
        let beginSource = pathSource[beginStart.lowerBound..<beginEnd.lowerBound]
        #expect(beginSource.contains("case .control(let hit) = penPathInsertionHit(at: point)"))
        #expect(beginSource.contains("!document.isEffectivelyPixelsLocked(layer)"))
        #expect(beginSource.contains("!document.isEffectivelyPositionLocked(layer)"))
    }

    @Test func pathSelectionLocksTopmostHitAndWiresShiftSetDragging() throws {
        let viewSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let pathSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent(
                "veilpic/ImageEditorPathCommands.swift"
            ),
            encoding: .utf8
        )

        let changedStart = try #require(
            viewSource.range(of: "case .pathSelection:\n                    if !isPathSelectionGestureResolved")
        )
        let changedEnd = try #require(viewSource[changedStart.upperBound...].range(of: "case .directSelection:"))
        let changedSource = viewSource[changedStart.lowerBound..<changedEnd.lowerBound]
        #expect(changedSource.contains("isPathSelectionGestureResolved = true"))
        #expect(changedSource.contains("imagePoint(from: value.startLocation, in: size)"))
        #expect(changedSource.contains("let target = viewModel.pathSelectionTarget(at: pointerStart)"))
        #expect(changedSource.contains("extendingSelection: NSEvent.modifierFlags.contains(.shift)"))
        #expect(changedSource.contains("viewModel.document.selectedLayerIDs.contains(target.layerID)"))
        #expect(changedSource.contains("viewModel.beginMovingSelectedLayer()"))
        #expect(viewSource.components(
            separatedBy: "pathSelectionIsBlocked: canvasInteractionTool == .pathSelection"
        ).count == 3)
        #expect(viewSource.components(separatedBy: "isPathSelectionGestureResolved = false").count >= 3)

        let targetStart = try #require(pathSource.range(of: "func pathSelectionTarget(at point: CGPoint?)"))
        let targetEnd = try #require(pathSource[targetStart.upperBound...].range(of: "@discardableResult\n    func selectPathLayer"))
        let targetSource = pathSource[targetStart.lowerBound..<targetEnd.lowerBound]
        #expect(targetSource.contains("for layer in document.layers.reversed()"))
        #expect(targetSource.contains("document.isEffectivelyVisible(layer)"))
        #expect(targetSource.contains("pathLayerContains(point: point, content: content, layer: layer)"))
        #expect(targetSource.contains("isBlocked: document.isEffectivelyPositionLocked(layer)"))

        let selectStart = try #require(pathSource.range(of: "func selectPathLayer(at point: CGPoint"))
        let selectEnd = try #require(pathSource[selectStart.upperBound...].range(of: "func directPathAnchorState("))
        let selectSource = pathSource[selectStart.lowerBound..<selectEnd.lowerBound]
        #expect(selectSource.contains("let target = pathSelectionTarget(at: point), !target.isBlocked"))
        #expect(selectSource.contains("selectLayer(target.layerID, extendingSelection: extendingSelection)"))
    }

    @Test func shiftConstraintIsWiredToExistingPenAndDirectSelectionDrags() throws {
        let viewSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let pathSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorPathCommands.swift"),
            encoding: .utf8
        )

        #expect(viewSource.components(
            separatedBy: "constrainedToAngleIncrement: ImageEditorPathAnchorDragConstraint"
        ).count == 8)
        #expect(viewSource.contains("modifierFlags.contains(.shift)\n            && hypot(viewTranslation.width, viewTranslation.height)"))
        #expect(pathSource.contains("movingPathAnchorOriginalCanvasSubpaths[selectedPathSubpathIndex][index].point"))
        #expect(pathSource.contains("case .inHandle, .outHandle:\n                return canvasAnchors[index].point"))
        #expect(pathSource.contains("ImageEditorPenPointGeometry.constrainedPoint("))
    }

    @Test func optionBreaksOnlySmoothHandleCouplingAcrossBothPathTools() throws {
        let viewSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let pathSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorPathCommands.swift"),
            encoding: .utf8
        )

        #expect(viewSource.components(
            separatedBy: "preservingSmoothness: !NSEvent.modifierFlags.contains(.option)"
        ).count == 8)
        #expect(pathSource.contains("originalAnchor.map(ImageEditorPenPointGeometry.isSmoothAnchor) == true"))
        #expect(pathSource.contains("preferredLength: hypot("))
        #expect(pathSource.contains("updatedAnchor.outControl = ImageEditorPenPointGeometry.oppositeControl("))
        #expect(pathSource.contains("updatedAnchor.inControl = ImageEditorPenPointGeometry.oppositeControl("))
    }

    @Test func smoothHandleBreakCursorUsesExactHoverAndActiveTransactionState() throws {
        let viewSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let pathSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorPathCommands.swift"),
            encoding: .utf8
        )

        #expect(viewSource.components(
            separatedBy: "pathHandleIsBreaking: isBreakingSmoothPathHandle("
        ).count == 3)
        #expect(viewSource.contains("if isMovingPathAnchor {\n            return viewModel.isMovingSmoothPathControlHandle"))
        #expect(viewSource.contains("includingUnselectedPaths: canvasInteractionTool == .directSelection"))
        #expect(pathSource.contains("guard nearest.candidate.role != .anchor"))
        #expect(pathSource.contains("nearest.distance <= pathAnchorHitDistance"))
        #expect(viewSource.contains("directSelectionCursor(isBreakingSmoothHandle: pathHandleIsBreaking)"))
        #expect(viewSource.contains("isConverting: penIsConverting || pathHandleIsBreaking"))
    }

    @Test func systemViewMenuReusesEditorCommandsWithoutCreatingADuplicateMenu() throws {
        let menuBarSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let commandsSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/XomoApplicationCommands.swift"),
            encoding: .utf8
        )
        let appSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/veilpicApp.swift"),
            encoding: .utf8
        )
        let viewSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(commandsSource.contains("@FocusedValue(\\.xomoViewCommandContent)"))
        #expect(commandsSource.contains("CommandGroup(replacing: .toolbar)"))
        #expect(commandsSource.contains("CommandGroup(replacing: .sidebar)"))
        #expect(!commandsSource.contains("CommandMenu(L10n.text(\"imageEditor.menu.view\"))"))
        #expect(menuBarSource.contains("var xomoViewCommandContent: XomoFocusedMenuContent"))
        #expect(menuBarSource.contains("XomoFocusedMenuContent(menuItems: AnyView(viewMenuItems))"))
        #expect(appSource.contains("XomoViewCommands()"))
        #expect(viewSource.contains(".focusedSceneValue(\\.xomoViewCommandContent, xomoViewCommandContent)"))
    }

    @Test func viewMenuExposesClassicZoomShortcuts() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let viewSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let viewMenuStart = try #require(source.range(of: "private var viewMenuItems: some View"))
        let nextMenuStart = try #require(
            source[viewMenuStart.upperBound...].range(of: "private var windowMenuItems: some View")
        )
        let viewMenuSource = source[viewMenuStart.lowerBound..<nextMenuStart.lowerBound]

        #expect(viewMenuSource.contains("performCanvasAidCommand(.rulers)"))
        #expect(viewMenuSource.contains(".keyboardShortcut(\"r\", modifiers: [.command])"))
        #expect(viewMenuSource.contains("performCanvasAidCommand(.guides)"))
        #expect(viewMenuSource.contains(".keyboardShortcut(\";\", modifiers: [.command])"))
        #expect(viewMenuSource.contains("performCanvasAidCommand(.guideSnapping)"))
        #expect(viewMenuSource.contains(".keyboardShortcut(\";\", modifiers: [.command, .shift])"))
        #expect(viewMenuSource.contains("performCanvasAidCommand(.guidesLocked)"))
        #expect(viewMenuSource.contains(".keyboardShortcut(\";\", modifiers: [.command, .option])"))
        #expect(viewMenuSource.contains("performCanvasAidCommand(.grid)"))
        #expect(viewMenuSource.contains(".keyboardShortcut(\"'\", modifiers: [.command])"))
        let helperStart = try #require(viewSource.range(of: "func performCanvasAidCommand("))
        let helperEnd = try #require(
            viewSource[helperStart.upperBound...].range(of: "\n    }")
        )
        let helperSource = viewSource[helperStart.lowerBound..<helperEnd.upperBound]
        let dispatchGate = try #require(
            helperSource.range(of: "ImageEditorCanvasAidCommandDispatchGate.shouldDispatch")
        )
        let actionSwitch = try #require(helperSource.range(of: "switch action"))
        #expect(dispatchGate.lowerBound < actionSwitch.lowerBound)
        #expect(viewSource.contains("case .toggleRulers: performCanvasAidCommand(.rulers)"))
        #expect(viewSource.contains("case .toggleGuides: performCanvasAidCommand(.guides)"))
        #expect(viewSource.contains("case .toggleGuideSnapping: performCanvasAidCommand(.guideSnapping)"))
        #expect(viewSource.contains("case .toggleGuidesLocked: performCanvasAidCommand(.guidesLocked)"))
        #expect(viewSource.contains("case .toggleGrid: performCanvasAidCommand(.grid)"))
        #expect(viewMenuSource.contains("performZoomCommand(.zoomIn)"))
        #expect(viewMenuSource.contains(".keyboardShortcut(\"+\", modifiers: [.command])"))
        #expect(viewMenuSource.contains("performZoomCommand(.zoomOut)"))
        #expect(viewMenuSource.contains(".keyboardShortcut(\"-\", modifiers: [.command])"))
        #expect(viewMenuSource.contains("performZoomCommand(.actualPixels)"))
        #expect(viewMenuSource.contains(".keyboardShortcut(\"1\", modifiers: [.command])"))
        #expect(viewMenuSource.contains("performZoomCommand(.fitOnScreen)"))
        #expect(viewMenuSource.contains(".keyboardShortcut(\"0\", modifiers: [.command])"))
        let zoomHelperStart = try #require(viewSource.range(of: "func performZoomCommand("))
        let zoomHelperEnd = try #require(
            viewSource[zoomHelperStart.upperBound...].range(of: "\n    }")
        )
        let zoomHelperSource = viewSource[zoomHelperStart.lowerBound..<zoomHelperEnd.upperBound]
        let zoomDispatchGate = try #require(
            zoomHelperSource.range(of: "ImageEditorZoomCommandDispatchGate.shouldDispatch")
        )
        let zoomActionSwitch = try #require(zoomHelperSource.range(of: "switch action"))
        #expect(zoomDispatchGate.lowerBound < zoomActionSwitch.lowerBound)
        #expect(viewSource.contains("case .zoomIn: performZoomCommand(.zoomIn)"))
        #expect(viewSource.contains("case .zoomOut: performZoomCommand(.zoomOut)"))
        #expect(viewSource.contains("case .actualPixels: performZoomCommand(.actualPixels)"))
        #expect(viewSource.contains("case .fitOnScreen: performZoomCommand(.fitOnScreen)"))
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
        #expect(infoMenuSource.contains("viewModel.pointerColorInfoText"))
        #expect(infoMenuSource.contains("viewModel.sizeText"))
        #expect(infoMenuSource.contains("viewModel.selectionBoundsInfoText"))
        #expect(infoMenuSource.contains("viewModel.selectedObjectBoundsInfoText"))
        #expect(!infoMenuSource.contains("viewModel.colorText"))
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
        #expect(source.contains("@State private var isNavigatorDockExpanded = false"))
        #expect(dockSource.contains("ScrollView"))
        #expect(dockSource.contains("EditorDockDisclosure("))
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
        #expect(source.contains("DragGesture(minimumDistance: 4)"))
        #expect(source.contains("targetedLayerDropTarget = layerDragTarget("))
        #expect(source.contains("viewModel.moveLayerIDs(sourceIDs, toDropTarget: target)"))
        #expect(source.contains("ImageEditorLayerDropDelegate"))
        #expect(source.contains("UTType.plainText"))
        #expect(source.contains("viewModel.toggleLayerVisibility(layer.id, applyingToSelection: true)"))
        #expect(source.contains("layerContentButton(layer)"))
        #expect(source.contains("selectLayerFromPanel(layer)"))
        #expect(source.contains("viewModel.selectLayer("))
        #expect(source.contains("layerNameEditor(layer)"))
        #expect(source.contains("Text(layer.name)"))
        #expect(source.contains("image-editor-layer-row-\\(layer.id.uuidString)"))
        #expect(source.contains("image-editor-layer-visibility-\\(layer.id.uuidString)"))
        #expect(source.contains(".accessibilityValue"))
        #expect(source.contains("imageEditor.accessibility.layerVisible"))
        #expect(source.contains("imageEditor.accessibility.layerHidden"))
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

    @Test func canvasExposesStableAccessibilityIdentityAndLiveContext() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let canvasStart = try #require(source.range(of: "private var canvasSurface: some View"))
        let canvasEnd = try #require(
            source[canvasStart.upperBound...].range(of: "private var documentTab: some View")
        )
        let canvasSource = source[canvasStart.lowerBound..<canvasEnd.lowerBound]

        #expect(canvasSource.contains(".accessibilityIdentifier(\"image-editor-canvas\")"))
        #expect(canvasSource.contains("imageEditor.accessibility.canvas"))
        #expect(canvasSource.contains("imageEditor.accessibility.canvasValue"))
        #expect(canvasSource.contains("viewModel.document.canvasSize"))
        #expect(canvasSource.contains("viewModel.zoom"))
        #expect(canvasSource.contains("canvasInteractionTool.title"))
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
    @Test func rightDockKeyboardToggleCoalescesDuplicateDispatchPaths() {
        ImageEditorPanelToggleDispatchGate.reset()
        defer { ImageEditorPanelToggleDispatchGate.reset() }
        let image = NSImage(size: NSSize(width: 16, height: 16))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let firstEvent = ImageEditorKeyboardShortcutEventSignature(
            windowNumber: 5,
            eventNumber: 90,
            timestamp: 20,
            typeRawValue: NSEvent.EventType.keyDown.rawValue,
            keyCode: 48
        )
        let secondEvent = ImageEditorKeyboardShortcutEventSignature(
            windowNumber: 5,
            eventNumber: 91,
            timestamp: 20.2,
            typeRawValue: NSEvent.EventType.keyDown.rawValue,
            keyCode: 48
        )

        viewModel.toggleRightDockVisibility(eventSignature: firstEvent)
        #expect(!viewModel.isRightDockVisible)
        viewModel.toggleRightDockVisibility(eventSignature: firstEvent)
        #expect(!viewModel.isRightDockVisible)
        viewModel.toggleRightDockVisibility(eventSignature: secondEvent)
        #expect(viewModel.isRightDockVisible)
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
        #expect(brushesMenuSource.contains("viewModel.isBrushPresetManagerPresented = true"))
        #expect(brushesMenuSource.contains("imageEditor.menu.window.brushes.tools"))
        #expect(brushesMenuSource.contains("viewModel.selectBrushPanelTool(tool)"))
        #expect(brushesMenuSource.contains("imageEditor.menu.window.brushes.presets"))
        #expect(brushesMenuSource.contains("ForEach(viewModel.favoriteBrushPresets)"))
        #expect(brushesMenuSource.contains("ForEach(viewModel.recentBrushPresets)"))
        #expect(brushesMenuSource.contains("ForEach(ImageEditorBrushPreset.defaultPresets)"))
        #expect(brushesMenuSource.contains("ForEach(viewModel.customBrushPresets)"))
        #expect(brushesMenuSource.contains("brushPresetMenuButton(preset)"))
        #expect(source.contains("private func brushPresetMenuButton(_ preset: ImageEditorBrushPreset)"))
        #expect(source.contains("viewModel.applyBrushPreset(preset)"))
        #expect(brushesMenuSource.contains("imageEditor.action.brushSettingsReset"))
        #expect(brushesMenuSource.contains("viewModel.resetBrushSettings()"))
        #expect(brushesMenuSource.contains("viewModel.createBrushPresetFromCurrentSettings()"))
        #expect(brushesMenuSource.contains("viewModel.chooseBrushPresetImportFile()"))
        #expect(brushesMenuSource.contains("viewModel.chooseBrushPresetExportFile()"))
        #expect(brushesMenuSource.contains("viewModel.customBrushPresets.isEmpty"))
        #expect(brushesMenuSource.contains("viewModel.chooseBrushPresetExportFile(presetIDs: [selectedPreset.id])"))
        #expect(brushesMenuSource.contains("viewModel.selectedCustomBrushPreset"))
        #expect(brushesMenuSource.contains("imageEditor.action.brushPresetRename"))
        #expect(brushesMenuSource.contains("beginBrushPresetRename()"))
        #expect(brushesMenuSource.contains("imageEditor.action.brushPresetUpdate"))
        #expect(brushesMenuSource.contains("viewModel.updateSelectedCustomBrushPresetFromCurrentSettings()"))
        #expect(brushesMenuSource.contains("imageEditor.action.brushPresetRevert"))
        #expect(brushesMenuSource.contains("viewModel.revertSelectedCustomBrushPresetToSavedSettings()"))
        #expect(brushesMenuSource.contains("!viewModel.canRevertSelectedCustomBrushPreset"))
        #expect(brushesMenuSource.contains("imageEditor.action.brushPresetDuplicate"))
        #expect(brushesMenuSource.contains("viewModel.duplicateSelectedCustomBrushPreset()"))
        #expect(brushesMenuSource.contains("viewModel.moveSelectedCustomBrushPresetUp()"))
        #expect(brushesMenuSource.contains("!viewModel.canMoveSelectedCustomBrushPresetUp"))
        #expect(brushesMenuSource.contains("viewModel.moveSelectedCustomBrushPresetDown()"))
        #expect(brushesMenuSource.contains("!viewModel.canMoveSelectedCustomBrushPresetDown"))
        #expect(brushesMenuSource.contains("viewModel.deleteBrushPreset(selectedPreset)"))
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
        #expect(menuSource.contains("ForEach(viewModel.favoriteBrushPresets)"))
        #expect(menuSource.contains("ForEach(viewModel.recentBrushPresets)"))
        #expect(menuSource.contains("ForEach(ImageEditorBrushPreset.defaultPresets)"))
        #expect(menuSource.contains("ForEach(viewModel.customBrushPresets)"))
        #expect(menuSource.contains("viewModel.activeBrushPreset?.id == preset.id"))
        #expect(menuSource.contains("imageEditor.action.brushSettingsReset"))
        #expect(menuSource.contains("viewModel.resetBrushSettings()"))
        #expect(menuSource.contains("viewModel.createBrushPresetFromCurrentSettings()"))
        #expect(menuSource.contains("viewModel.chooseBrushPresetImportFile()"))
        #expect(menuSource.contains("viewModel.chooseBrushPresetExportFile()"))
        #expect(menuSource.contains("viewModel.customBrushPresets.isEmpty"))
        #expect(menuSource.contains("viewModel.isBrushPresetManagerPresented = true"))
        #expect(menuSource.contains("viewModel.chooseBrushPresetExportFile(presetIDs: [selectedPreset.id])"))
        #expect(menuSource.contains("viewModel.selectedCustomBrushPreset"))
        #expect(menuSource.contains("imageEditor.action.brushPresetRename"))
        #expect(menuSource.contains("beginBrushPresetRename()"))
        #expect(menuSource.contains("imageEditor.action.brushPresetUpdate"))
        #expect(menuSource.contains("viewModel.updateSelectedCustomBrushPresetFromCurrentSettings()"))
        #expect(menuSource.contains("imageEditor.action.brushPresetRevert"))
        #expect(menuSource.contains("viewModel.revertSelectedCustomBrushPresetToSavedSettings()"))
        #expect(menuSource.contains("!viewModel.canRevertSelectedCustomBrushPreset"))
        #expect(menuSource.contains("imageEditor.action.brushPresetDuplicate"))
        #expect(menuSource.contains("viewModel.duplicateSelectedCustomBrushPreset()"))
        #expect(menuSource.contains("viewModel.moveSelectedCustomBrushPresetUp()"))
        #expect(menuSource.contains("!viewModel.canMoveSelectedCustomBrushPresetUp"))
        #expect(menuSource.contains("viewModel.moveSelectedCustomBrushPresetDown()"))
        #expect(menuSource.contains("!viewModel.canMoveSelectedCustomBrushPresetDown"))
        #expect(menuSource.contains("viewModel.deleteBrushPreset(selectedPreset)"))
        #expect(menuSource.contains("viewModel.brushPresetMenuTitle"))
        #expect(menuSource.contains(".focusable(false)"))
        #expect(menuSource.contains("image-editor-brush-preset-menu"))
        #expect(source.contains("isPresented: $isBrushPresetRenamePresented"))
        #expect(source.contains("viewModel.renameSelectedCustomBrushPreset(to: brushPresetNameDraft)"))
        #expect(source.contains("ImageEditorBrushPreset.normalizedCustomName(brushPresetNameDraft) == nil"))
    }

    @Test func brushAndEraserExposeCompactNonFocusableSmoothingPresets() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let menuStart = try #require(
            source.range(of: "private var brushSmoothingMenu: some View")
        )
        let menuEnd = try #require(
            source[menuStart.upperBound...].range(
                of: "private var retouchPressureSensitivityMenu: some View"
            )
        )
        let menuSource = source[menuStart.lowerBound..<menuEnd.lowerBound]

        #expect(source.contains("brushSmoothingMenu\n                    brushPressureMenu"))
        #expect(menuSource.contains("ImageEditorBrushSmoothingPresets.values"))
        #expect(menuSource.contains("viewModel.setBrushSmoothing($0)"))
        #expect(menuSource.contains(".focusable(false)"))
        #expect(menuSource.contains("image-editor-brush-smoothing"))
    }

    @Test func brushPressureMenuExposesMinimumDynamicsWithoutAddingToolbarWidth() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let menuStart = try #require(
            source.range(of: "private var brushPressureMenu: some View")
        )
        let menuEnd = try #require(
            source[menuStart.upperBound...].range(of: "private var brushSmoothingMenu: some View")
        )
        let menuSource = source[menuStart.lowerBound..<menuEnd.lowerBound]

        #expect(menuSource.contains("ImageEditorBrushMinimumDiameterPresets.values"))
        #expect(menuSource.contains("viewModel.setBrushMinimumDiameter($0)"))
        #expect(menuSource.contains(".disabled(!viewModel.brushPressureControlsSize)"))
        #expect(menuSource.contains("imageEditor.option.pressureOpacity"))
        #expect(menuSource.contains("viewModel.setBrushPressureControlsOpacity($0)"))
        #expect(menuSource.contains("ImageEditorBrushMinimumOpacityPresets.values"))
        #expect(menuSource.contains("viewModel.setBrushMinimumOpacity($0)"))
        #expect(menuSource.contains(".disabled(!viewModel.brushPressureControlsOpacity)"))
        #expect(menuSource.contains("ImageEditorBrushMinimumFlowPresets.values"))
        #expect(menuSource.contains("viewModel.setBrushMinimumFlow($0)"))
        #expect(menuSource.contains(".disabled(!viewModel.brushPressureControlsFlow)"))
        #expect(menuSource.contains(".focusable(false)"))
        #expect(menuSource.contains("image-editor-brush-pressure-menu"))
    }

    @Test func brushAndEraserExposeCompactNonFocusableTipShapePresets() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let viewModelSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent(
                "veilpic/ImageEditorViewModel.swift"
            ),
            encoding: .utf8
        )
        let menuStart = try #require(
            source.range(of: "private var brushRoundnessMenu: some View")
        )
        let menuEnd = try #require(
            source[menuStart.upperBound...].range(
                of: "private var retouchPressureSensitivityMenu: some View"
            )
        )
        let menuSource = source[menuStart.lowerBound..<menuEnd.lowerBound]

        #expect(source.contains("brushPresetMenu\n                    brushRoundnessMenu"))
        #expect(source.contains("brushRoundnessMenu\n                    brushSizeJitterMenu"))
        #expect(source.contains("brushSizeJitterMenu\n                    brushScatteringMenu"))
        #expect(source.contains("brushScatteringMenu\n                    brushTransferMenu"))
        #expect(source.contains("brushTransferMenu\n                    if viewModel.selectedTool != .pencil {\n                        brushTipFinishMenu"))
        #expect(source.contains("ImageEditorBrushSizeJitterPresets.values"))
        #expect(source.contains("viewModel.setBrushSizeJitter($0)"))
        #expect(source.contains("image-editor-brush-size-jitter"))
        #expect(menuSource.contains("ImageEditorBrushRoundnessPresets.values"))
        #expect(menuSource.contains("ImageEditorBrushAnglePresets.values"))
        #expect(menuSource.contains("ImageEditorBrushAngleJitterPresets.values"))
        #expect(menuSource.contains("ImageEditorBrushRoundnessJitterPresets.values"))
        #expect(menuSource.contains("ImageEditorBrushMinimumRoundnessPresets.values"))
        #expect(menuSource.contains("ImageEditorBrushScatterPresets.values"))
        #expect(menuSource.contains("ImageEditorBrushScatterCountPresets.values"))
        #expect(menuSource.contains("ImageEditorBrushScatterCountJitterPresets.values"))
        #expect(menuSource.contains("viewModel.setBrushTipRoundness($0)"))
        #expect(menuSource.contains("viewModel.setBrushTipAngleDegrees($0)"))
        #expect(menuSource.contains("viewModel.setBrushAngleFollowsStrokeDirection($0)"))
        #expect(menuSource.contains("viewModel.setBrushAngleJitter($0)"))
        #expect(menuSource.contains("viewModel.setBrushRoundnessJitter($0)"))
        #expect(menuSource.contains("viewModel.setBrushMinimumRoundness($0)"))
        #expect(menuSource.contains("viewModel.setBrushScatter($0)"))
        #expect(menuSource.contains("viewModel.setBrushScatterBothAxes($0)"))
        #expect(menuSource.contains("viewModel.setBrushScatterCount($0)"))
        #expect(menuSource.contains("viewModel.setBrushScatterCountJitter($0)"))
        #expect(menuSource.contains("imageEditor.option.angleJitter"))
        #expect(menuSource.contains("imageEditor.option.angleFollowsStrokeDirection"))
        #expect(menuSource.contains("imageEditor.option.roundnessJitter"))
        #expect(menuSource.contains("imageEditor.option.minimumRoundness"))
        #expect(menuSource.contains("imageEditor.option.scatterBothAxes"))
        #expect(menuSource.contains("image-editor-brush-scattering"))
        #expect(menuSource.contains("private var brushTransferMenu: some View"))
        #expect(menuSource.contains("viewModel.setBrushOpacityJitter($0)"))
        #expect(menuSource.contains("viewModel.setBrushFlowJitter($0)"))
        #expect(menuSource.contains("imageEditor.option.opacityJitter"))
        #expect(menuSource.contains("imageEditor.option.flowJitter"))
        #expect(menuSource.contains("image-editor-brush-transfer"))
        #expect(menuSource.contains("private var brushTipFinishMenu: some View"))
        #expect(menuSource.contains("viewModel.setBrushNoiseEnabled($0)"))
        #expect(menuSource.contains("viewModel.setBrushWetEdgesEnabled($0)"))
        #expect(menuSource.contains("imageEditor.option.brushTipFinish"))
        #expect(menuSource.contains("imageEditor.option.noise"))
        #expect(menuSource.contains("imageEditor.option.wetEdges"))
        #expect(menuSource.contains("image-editor-brush-tip-finish"))
        #expect(
            viewModelSource.components(
                separatedBy: "angleJitter: brushAngleJitter / 100"
            ).count == 4
        )
        #expect(
            viewModelSource.components(
                separatedBy: "angleFollowsStrokeDirection: brushAngleFollowsStrokeDirection"
            ).count == 7
        )
        #expect(
            viewModelSource.components(
                separatedBy: "roundnessJitter: brushRoundnessJitter / 100"
            ).count == 4
        )
        #expect(
            viewModelSource.components(
                separatedBy: "opacityJitter: brushOpacityJitter / 100"
            ).count == 4
        )
        #expect(
            viewModelSource.components(
                separatedBy: "flowJitter: brushFlowJitter / 100"
            ).count == 4
        )
        #expect(
            viewModelSource.components(
                separatedBy: "minimumRoundness: brushMinimumRoundness / 100"
            ).count == 4
        )
        #expect(
            viewModelSource.components(
                separatedBy: "scatter: brushScatter / 100"
            ).count == 4
        )
        #expect(
            viewModelSource.components(
                separatedBy: "scatterBothAxes: brushScatterBothAxes"
            ).count == 7
        )
        #expect(
            viewModelSource.components(
                separatedBy: "scatterCount: brushScatterCount"
            ).count == 7
        )
        #expect(
            viewModelSource.components(
                separatedBy: "scatterCountJitter: brushScatterCountJitter / 100"
            ).count == 4
        )
        #expect(
            viewModelSource.components(
                separatedBy: "noiseEnabled: edgeStyle != .aliased && brushNoiseEnabled"
            ).count == 4
        )
        #expect(
            viewModelSource.components(
                separatedBy: "wetEdgesEnabled: edgeStyle != .aliased && brushWetEdgesEnabled"
            ).count == 4
        )
        #expect(menuSource.contains("imageEditor.option.brushTipShapeValue"))
        #expect(menuSource.contains(".focusable(false)"))
        #expect(menuSource.contains("image-editor-brush-roundness"))
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
        #expect(source.contains("viewModel.canBeginPatch(at: startImagePoint)"))
        #expect(source.contains("viewModel.createPatchSelection(points: dragPoints)"))
        #expect(source.contains("patchPreviewImage = viewModel.patchPreviewImage("))
        #expect(source.contains("if canvasInteractionTool == .patchTool, let patchPreviewImage"))
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

    @Test func sampledBrushPressureSizeOptionUsesSamplesWithoutTakingFocus() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let pressureStart = try #require(
            source.range(of: "if viewModel.selectedTool == .cloneStamp || viewModel.selectedTool == .healingBrush {")
        )
        let textStart = try #require(
            source[pressureStart.upperBound...].range(of: "if viewModel.selectedTool == .text")
        )
        let pressureSource = source[pressureStart.lowerBound..<textStart.lowerBound]

        #expect(pressureSource.contains("viewModel.retouchPressureControlsSize"))
        #expect(pressureSource.contains("viewModel.setRetouchPressureControlsSize"))
        #expect(pressureSource.contains("imageEditor.option.sampledBrushPressureSize.help"))
        #expect(pressureSource.contains("image-editor-sampled-brush-pressure-size"))
        #expect(pressureSource.contains(".focusable(false)"))
        #expect(source.contains("case .cloneStamp, .blur, .sharpen, .smudge, .healingBrush:"))
        #expect(source.contains("viewModel.cloneStamp(samples: brushStrokeSamples)"))
        #expect(source.contains("viewModel.healingBrush(samples: brushStrokeSamples)"))
    }

    @Test func sampledBrushOptionsExposeAdjustmentExclusionForCloneAndHealing() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let optionsStart = try #require(source.range(of: "private func sampledBrushOptions("))
        let optionsEnd = try #require(
            source[optionsStart.upperBound...].range(of: "private var marqueeShapePicker")
        )
        let optionsSource = source[optionsStart.lowerBound..<optionsEnd.lowerBound]

        #expect(source.contains("$viewModel.cloneStampIgnoresAdjustmentLayers"))
        #expect(source.contains("$viewModel.healingBrushIgnoresAdjustmentLayers"))
        #expect(optionsSource.contains("imageEditor.option.colorSamplerIgnoreAdjustments"))
        #expect(optionsSource.contains("isOn: ignoresAdjustmentLayers"))
        #expect(optionsSource.contains(".disabled(sampleSource.wrappedValue == .currentLayer)"))
        #expect(optionsSource.contains(#"\(identifierPrefix)-ignore-adjustments"#))
        #expect(optionsSource.contains(".focusable(false)"))
    }

    @Test func cloneStampExposesFiveNonFocusableSourceSlots() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let cloneStart = try #require(source.range(of: "if viewModel.selectedTool == .cloneStamp {"))
        let healingStart = try #require(
            source[cloneStart.upperBound...].range(of: "if viewModel.selectedTool == .healingBrush {")
        )
        let cloneSource = source[cloneStart.lowerBound..<healingStart.lowerBound]

        #expect(cloneSource.contains("imageEditor.option.cloneSourceSlot"))
        #expect(cloneSource.contains("ImageEditorCloneSourceSlotState.maximumCount"))
        #expect(cloneSource.contains("viewModel.activeCloneSourceSlotIndex"))
        #expect(cloneSource.contains("viewModel.selectCloneSourceSlot($0)"))
        #expect(cloneSource.contains("viewModel.cloneSourceSlotIsPopulated(index)"))
        #expect(cloneSource.contains("isPopulated ? \"circle.fill\" : \"circle\""))
        #expect(cloneSource.contains("imageEditor.accessibility.cloneSourceSlotPopulated"))
        #expect(cloneSource.contains("imageEditor.accessibility.cloneSourceSlotEmpty"))
        #expect(cloneSource.contains(".accessibilityHidden(true)"))
        #expect(cloneSource.contains(".pickerStyle(.segmented)"))
        #expect(cloneSource.contains("imageEditor.option.cloneSourceScaleWidth"))
        #expect(cloneSource.contains("imageEditor.option.cloneSourceScaleHeight"))
        #expect(cloneSource.contains("imageEditor.option.cloneSourceScaleLink"))
        #expect(cloneSource.contains("ImageEditorCloneSourceSlotState.minimumScalePercent"))
        #expect(cloneSource.contains("ImageEditorCloneSourceSlotState.maximumScalePercent"))
        #expect(cloneSource.contains("viewModel.cloneSourceHorizontalScalePercent"))
        #expect(cloneSource.contains("viewModel.setCloneSourceHorizontalScalePercent($0)"))
        #expect(cloneSource.contains("viewModel.cloneSourceVerticalScalePercent"))
        #expect(cloneSource.contains("viewModel.setCloneSourceVerticalScalePercent($0)"))
        #expect(cloneSource.contains("viewModel.cloneSourceScalesLinked"))
        #expect(cloneSource.contains("viewModel.setCloneSourceScalesLinked($0)"))
        #expect(cloneSource.contains("imageEditor.option.cloneSourceRotation"))
        #expect(cloneSource.contains("ImageEditorCloneSourceSlotState.minimumRotationDegrees"))
        #expect(cloneSource.contains("ImageEditorCloneSourceSlotState.maximumRotationDegrees"))
        #expect(cloneSource.contains("viewModel.cloneSourceRotationDegrees"))
        #expect(cloneSource.contains("viewModel.setCloneSourceRotationDegrees($0)"))
        #expect(cloneSource.contains("imageEditor.option.cloneSourceShowOverlay"))
        #expect(cloneSource.contains("$viewModel.cloneStampShowsOverlay"))
        #expect(cloneSource.contains("imageEditor.option.cloneSourceOverlayClipped"))
        #expect(cloneSource.contains("$viewModel.cloneStampOverlayClipsToBrush"))
        #expect(cloneSource.contains("imageEditor.option.cloneSourceOverlayAutoHide"))
        #expect(cloneSource.contains("$viewModel.cloneStampOverlayAutoHidesWhilePainting"))
        #expect(cloneSource.contains("imageEditor.option.cloneSourceOverlayInvert"))
        #expect(cloneSource.contains("$viewModel.cloneStampOverlayInvertsColors"))
        #expect(cloneSource.contains("imageEditor.option.cloneSourceOverlayBlendMode"))
        #expect(cloneSource.contains("$viewModel.cloneStampOverlayBlendMode"))
        #expect(cloneSource.contains("ImageEditorCloneStampOverlayBlendMode.allCases"))
        #expect(cloneSource.contains("imageEditor.option.cloneSourceOverlayOpacity"))
        #expect(cloneSource.contains("viewModel.cloneStampOverlayOpacityPercent"))
        #expect(cloneSource.contains("viewModel.setCloneStampOverlayOpacityPercent($0)"))
        #expect(cloneSource.contains("imageEditor.option.cloneSourceFlipHorizontal"))
        #expect(cloneSource.contains("viewModel.cloneSourceFlipsHorizontally"))
        #expect(cloneSource.contains("viewModel.setCloneSourceFlipsHorizontally($0)"))
        #expect(cloneSource.contains("imageEditor.option.cloneSourceFlipVertical"))
        #expect(cloneSource.contains("viewModel.cloneSourceFlipsVertically"))
        #expect(cloneSource.contains("viewModel.setCloneSourceFlipsVertically($0)"))
        #expect(cloneSource.contains("viewModel.resetActiveCloneSourceTransform()"))
        #expect(cloneSource.contains("!viewModel.canResetCloneSourceTransform"))
        #expect(cloneSource.contains("imageEditor.action.cloneSourceResetTransform"))
        #expect(cloneSource.contains("viewModel.clearActiveCloneSource()"))
        #expect(cloneSource.contains("!viewModel.canClearCloneSource"))
        #expect(cloneSource.contains("imageEditor.action.cloneSourceClear"))
        #expect(cloneSource.contains(".focusable(false)"))
        #expect(cloneSource.contains("image-editor-clone-source-slot"))
        #expect(cloneSource.contains("image-editor-clone-source-scale-width"))
        #expect(cloneSource.contains("image-editor-clone-source-scale-height"))
        #expect(cloneSource.contains("image-editor-clone-source-scale-link"))
        #expect(cloneSource.contains("image-editor-clone-source-rotation"))
        #expect(cloneSource.contains("image-editor-clone-source-show-overlay"))
        #expect(cloneSource.contains("image-editor-clone-source-overlay-clipped"))
        #expect(cloneSource.contains("image-editor-clone-source-overlay-auto-hide"))
        #expect(cloneSource.contains("image-editor-clone-source-overlay-invert"))
        #expect(cloneSource.contains("image-editor-clone-source-overlay-blend-mode"))
        #expect(cloneSource.contains("image-editor-clone-source-overlay-opacity"))
        #expect(cloneSource.contains("image-editor-clone-source-flip-horizontal"))
        #expect(cloneSource.contains("image-editor-clone-source-flip-vertical"))
        #expect(cloneSource.contains("image-editor-clone-source-reset-transform"))
        #expect(cloneSource.contains("image-editor-clone-source-clear"))
    }

    @Test func pressureCursorGestureUsesTabletPressureAndResetsAfterRelease() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let pointerSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent(
                "veilpic/ImageEditorScrollZoom.swift"
            ),
            encoding: .utf8
        )

        #expect(source.contains("@State private var activeBrushPressure: CGFloat?"))
        #expect(source.contains(
            "let stylusInput = ImageEditorStylusInput.sample(from: NSApp.currentEvent)"
        ))
        #expect(source.contains("let eventPressure = stylusInput.pressure"))
        #expect(source.contains("activeBrushPressure = eventPressure"))
        #expect(source.contains(
            "activeBrushPressure = isSettingSampledBrushSourceGesture ? nil : eventPressure"
        ))
        #expect(source.contains("pressure: activeBrushPressure"))
        #expect(source.contains("ImageEditorCanvasCursor.pressureAdjustedBrushDiameter("))
        #expect(source.contains("brushPressureControlsSize: viewModel.brushPressureControlsSize"))
        #expect(source.contains("retouchPressureControlsSize: viewModel.retouchPressureControlsSize"))
        #expect(source.contains("activeBrushPressure = nil"))
        #expect(source.contains("updateCanvasCursor(at: value.location, in: size)"))
        #expect(source.contains("onPrimaryToolDragChanged: { location, pressure, tilt in"))
        #expect(source.contains("activeBrushPressure = pressure"))
        #expect(source.contains("updateCanvasCursor(at: location, in: geometry.size)"))
        #expect(pointerSource.contains(
            "let onPrimaryChanged: ((CGPoint, CGFloat?, ImageEditorStylusTilt?) -> Void)?"
        ))
        #expect(pointerSource.contains("transaction.onPrimaryChanged?("))
        #expect(pointerSource.contains("onPrimaryToolDragChanged?("))
    }

    @Test func livePressureIndicatorIsVisibleNonFocusableAndUsesSharedInput() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let indicatorStart = try #require(
            source.range(of: "private var brushPressureIndicator: some View {")
        )
        let presetStart = try #require(
            source[indicatorStart.upperBound...].range(of: "private var brushPresetMenu: some View {")
        )
        let indicatorSource = source[indicatorStart.lowerBound..<presetStart.lowerBound]

        #expect(source.contains("if usesPressureInputIndicator {"))
        #expect(source.contains("usesBrushDynamicsOptions || usesRetouchPressureOptions"))
        #expect(indicatorSource.contains(
            "ImageEditorBrushPressureDisplay(pressure: activeBrushPressure)"
        ))
        #expect(indicatorSource.contains(
            "ImageEditorStylusTiltDisplay(tilt: activeBrushTilt)"
        ))
        #expect(indicatorSource.contains("imageEditor.option.stylusLiveDeviceHelp"))
        #expect(indicatorSource.contains("imageEditor.option.stylusLiveValue"))
        #expect(indicatorSource.contains("imageEditor.option.stylusDeviceNotDetected"))
        #expect(indicatorSource.contains("imageEditor.option.stylusPenDetected"))
        #expect(indicatorSource.contains("imageEditor.option.stylusEraserDetected"))
        #expect(indicatorSource.contains("imageEditor.option.tiltNotDetected"))
        #expect(indicatorSource.contains("imageEditor.option.pressureNotDetected"))
        #expect(indicatorSource.contains("stylusProximity == .eraser"))
        #expect(indicatorSource.contains("stylusProximity == .pen"))
        #expect(indicatorSource.contains(".focusable(false)"))
        #expect(indicatorSource.contains(
            ".accessibilityIdentifier(\"image-editor-live-pressure\")"
        ))
    }

    @Test func nativeStylusTiltFlowsThroughPointerTransactionsAndBrushSamples() throws {
        let repositoryRoot = Self.repositoryRoot()
        let pointerSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "veilpic/ImageEditorScrollZoom.swift"
            ),
            encoding: .utf8
        )
        let viewSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(pointerSource.contains("let tilt: ImageEditorStylusTilt?"))
        #expect(pointerSource.contains("ImageEditorStylusInput.sample(from: event)"))
        #expect(pointerSource.contains("tilt: stylusInput.tilt"))
        #expect(pointerSource.contains(
            "transaction.onPrimaryChanged?("
        ))
        #expect(viewSource.contains(
            "onPrimaryToolDragChanged: { location, pressure, tilt in"
        ))
        #expect(viewSource.contains(
            "onMouseMoved: { location, stylusInput in"
        ))
        #expect(pointerSource.contains(
            "onMouseMoved?(location, ImageEditorStylusInput.sample(from: event))"
        ))
        #expect(viewSource.contains("activeBrushTilt = tilt"))
        #expect(viewSource.contains("activeBrushTilt = stylusInput.tilt"))
        #expect(viewSource.contains("tilt: sample.tilt"))
        #expect(viewSource.contains("tilt: stylusInput.tilt"))
        #expect(viewSource.contains("brushTilt: activeBrushTilt"))
        #expect(viewSource.contains(
            "brushTiltControlsShape: viewModel.brushTiltControlsShape"
        ))
        #expect(viewSource.contains("activeBrushTilt = nil"))
    }

    @Test func stylusProximityUsesNativeAppKitWithoutOverridingComponents() throws {
        let repositoryRoot = Self.repositoryRoot()
        let pointerSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "veilpic/ImageEditorScrollZoom.swift"
            ),
            encoding: .utf8
        )
        let viewSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(pointerSource.contains("matching: .tabletProximity"))
        #expect(pointerSource.contains("ImageEditorStylusProximity.device("))
        #expect(pointerSource.contains("enteringProximity: event.isEnteringProximity"))
        #expect(pointerSource.contains("currentPointerHost?.reportStylusProximity(nextState)"))
        #expect(pointerSource.contains(
            "guard lastReportedStylusProximity != proximity"
        ))
        #expect(viewSource.contains(
            "@State private var stylusProximity: ImageEditorStylusProximity = .none"
        ))
        #expect(viewSource.contains("onStylusProximityChanged: { proximity in"))
        #expect(viewSource.contains("stylusProximity = proximity"))
        #expect(viewSource.contains("ImageEditorStylusToolOverride.effectiveTool("))
        #expect(viewSource.contains(
            "viewModel.canvasPointerCaptureState.activeTool = canvasInteractionTool"
        ))
        #expect(viewSource.contains(
            "let primaryTool = viewModel.canvasPointerCaptureState.activeTool"
        ))
        #expect(viewSource.contains("switch primaryTool"))
        #expect(ImageEditorStylusToolOverride.effectiveTool(
            baseTool: .move,
            sidebarTab: .components,
            isEraserInProximity: true
        ) == .move)
    }

    @Test func retouchPressureSensitivityMenuIsCompactSharedAndNonFocusable() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let menuStart = try #require(
            source.range(of: "private var retouchPressureSensitivityMenu: some View {")
        )
        let selectionStart = try #require(
            source[menuStart.upperBound...].range(of: "private var selectionModePicker: some View {")
        )
        let menuSource = source[menuStart.lowerBound..<selectionStart.lowerBound]

        #expect(source.contains("if usesRetouchPressureOptions {"))
        #expect(source.contains("case .cloneStamp, .dodge, .burn, .sponge,"))
        #expect(source.contains(".blur, .sharpen, .smudge, .healingBrush:"))
        #expect(menuSource.contains("viewModel.retouchPressureSensitivity"))
        #expect(menuSource.contains("viewModel.setRetouchPressureSensitivity"))
        #expect(menuSource.contains("ImageEditorPressureSensitivityPresets.values"))
        #expect(menuSource.contains("slider.horizontal.3"))
        #expect(menuSource.contains(".fixedSize()"))
        #expect(menuSource.contains(".focusable(false)"))
        #expect(menuSource.contains(".xomoFocusEffectDisabled()"))
        #expect(menuSource.contains("imageEditor.option.retouchPressureSensitivity.help"))
        #expect(menuSource.contains("image-editor-retouch-pressure-sensitivity"))
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

    @Test func spongeVibranceOptionIsNonFocusableAndAccessible() throws {
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

        #expect(spongeSource.contains("isOn: $viewModel.spongeVibranceEnabled"))
        #expect(spongeSource.contains(".toggleStyle(.checkbox)"))
        #expect(spongeSource.contains(".focusable(false)"))
        #expect(spongeSource.contains("imageEditor.option.spongeVibrance.help"))
        #expect(spongeSource.contains("image-editor-sponge-vibrance"))
    }

    @Test func spongePressureSizeOptionIsNonFocusableAndAccessible() throws {
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

        #expect(spongeSource.contains("viewModel.retouchPressureControlsSize"))
        #expect(spongeSource.contains("viewModel.setRetouchPressureControlsSize"))
        #expect(spongeSource.contains(".toggleStyle(.checkbox)"))
        #expect(spongeSource.contains(".focusable(false)"))
        #expect(spongeSource.contains("imageEditor.option.spongePressureSize.help"))
        #expect(spongeSource.contains("image-editor-sponge-pressure-size"))
    }

    @MainActor
    @Test func spongeFlowUsesPercentageOptionAndStatus() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        #expect(source.contains("if usesFlowOption { return \"imageEditor.option.flow\" }"))
        #expect(source.contains("usesExposureOption || usesStrengthOption || usesFlowOption"))
        #expect(source.contains("viewModel.selectedTool == .sponge"))

        let viewModel = ImageEditorViewModel(
            sourceName: "Sponge Flow",
            image: NSImage.transparent(size: CGSize(width: 32, height: 24)),
            onApply: { _ in }
        )
        viewModel.selectTool(.sponge)
        viewModel.applyOpacityShortcutDigit(4)

        #expect(viewModel.optionsPanelSummaryText.contains(L10n.text("imageEditor.option.flow")))
        #expect(viewModel.opacity == 0.4)
        #expect(viewModel.optionsPanelSummaryText.contains("40%"))
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

    @Test func fingerPaintingOptionIsSmudgeOnlyNonFocusableAndAccessible() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let smudgeStart = try #require(
            source.range(of: "if viewModel.selectedTool == .smudge {")
        )
        let textStart = try #require(
            source[smudgeStart.upperBound...].range(of: "if viewModel.selectedTool == .text")
        )
        let smudgeSource = source[smudgeStart.lowerBound..<textStart.lowerBound]

        #expect(smudgeSource.contains("isOn: $viewModel.smudgeFingerPaintingEnabled"))
        #expect(smudgeSource.contains("imageEditor.option.fingerPainting"))
        #expect(smudgeSource.contains("imageEditor.option.fingerPainting.help"))
        #expect(smudgeSource.contains("image-editor-smudge-finger-painting"))
        #expect(smudgeSource.contains(".toggleStyle(.checkbox)"))
        #expect(smudgeSource.contains(".focusable(false)"))
    }

    @Test func sampleAllLayersOptionIsSmudgeOnlyNonFocusableAndAccessible() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let smudgeStart = try #require(
            source.range(of: "if viewModel.selectedTool == .smudge {")
        )
        let textStart = try #require(
            source[smudgeStart.upperBound...].range(of: "if viewModel.selectedTool == .text")
        )
        let smudgeSource = source[smudgeStart.lowerBound..<textStart.lowerBound]

        #expect(smudgeSource.contains("isOn: $viewModel.smudgeSampleAllLayersEnabled"))
        #expect(smudgeSource.contains("imageEditor.option.sampleAllLayers"))
        #expect(smudgeSource.contains("imageEditor.option.sampleAllLayers.help"))
        #expect(smudgeSource.contains("image-editor-smudge-sample-all-layers"))
        #expect(smudgeSource.contains(".toggleStyle(.checkbox)"))
        #expect(smudgeSource.contains(".focusable(false)"))
    }

    @Test func smudgePressureSizeOptionSharesRetouchControlWithoutFocus() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let toneStart = try #require(
            source.range(of: "if viewModel.selectedTool == .dodge || viewModel.selectedTool == .burn {")
        )
        let textStart = try #require(
            source[toneStart.upperBound...].range(of: "if viewModel.selectedTool == .text")
        )
        let toneSource = source[toneStart.lowerBound..<textStart.lowerBound]

        #expect(toneSource.contains("viewModel.retouchPressureControlsSize"))
        #expect(toneSource.contains("viewModel.setRetouchPressureControlsSize"))
        #expect(toneSource.contains("imageEditor.option.tonePressureSize.help"))
        #expect(toneSource.contains("image-editor-tone-pressure-size"))
        #expect(toneSource.contains("imageEditor.option.smudgePressureSize.help"))
        #expect(toneSource.contains("image-editor-smudge-pressure-size"))
        #expect(toneSource.contains(".focusable(false)"))
        #expect(source.contains("brushStrokeSamples.append(ImageEditorBrushStrokeSample("))
        #expect(source.contains("samples: brushStrokeSamples"))
    }

    @Test func blurSharpenPressureSizeOptionSharesRetouchControlWithoutFocus() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let pressureStart = try #require(
            source.range(of: "if viewModel.selectedTool == .blur || viewModel.selectedTool == .sharpen {")
        )
        let smudgeStart = try #require(
            source[pressureStart.upperBound...].range(of: "if viewModel.selectedTool == .smudge {")
        )
        let pressureSource = source[pressureStart.lowerBound..<smudgeStart.lowerBound]

        #expect(pressureSource.contains("viewModel.retouchPressureControlsSize"))
        #expect(pressureSource.contains("viewModel.setRetouchPressureControlsSize"))
        #expect(pressureSource.contains("imageEditor.option.blurSharpenPressureSize.help"))
        #expect(pressureSource.contains("image-editor-blur-sharpen-pressure-size"))
        #expect(pressureSource.contains(".focusable(false)"))
        #expect(source.contains("case .blur, .sharpen, .smudge:"))
        #expect(source.contains("viewModel.blurBrush(samples: brushStrokeSamples)"))
        #expect(source.contains("viewModel.sharpenBrush(samples: brushStrokeSamples)"))
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

    @Test func dodgeBurnToneRangeShortcutsUseTheActiveCanvasToolAndTextFocusGuard() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let shortcutSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorToneRangeShortcut.swift"),
            encoding: .utf8
        )

        #expect(source.contains("activeTool: viewModel.canvasInteractionTool"))
        #expect(source.contains("if action.isBlockedByTextInput, isTextInputActive"))
        #expect(source.contains(".accessibilityHint(ImageEditorToneRangeShortcut.helpText)"))
        #expect(shortcutSource.contains("guard activeTool == .dodge || activeTool == .burn"))
        #expect(shortcutSource.contains("static let modifierFlags: NSEvent.ModifierFlags = [.shift, .option]"))
    }

    @Test func spongeModeShortcutsUseTheActiveCanvasToolAndAccessibleHint() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let shortcutSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorSpongeModeShortcut.swift"),
            encoding: .utf8
        )

        #expect(source.contains("case .spongeMode(let mode): viewModel.applySpongeModeShortcut(mode)"))
        #expect(source.contains(".accessibilityHint(ImageEditorSpongeModeShortcut.helpText)"))
        #expect(source.contains(".toggleQuickMask,"))
        #expect(source.contains(".toneRange,"))
        #expect(source.contains(".spongeMode:"))
        #expect(shortcutSource.contains("guard activeTool == .sponge"))
        #expect(shortcutSource.contains("static let modifierFlags: NSEvent.ModifierFlags = [.shift, .option]"))
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
        #expect(source.contains(".disabled(!viewModel.canHideSelectedLayerEffects)"))
        #expect(source.contains(".disabled(!viewModel.canShowSelectedLayerEffects)"))
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
        #expect(layerMenuSource.contains("performGroupSelectedLayer()"))
        #expect(layerMenuSource.contains("viewModel.canGroupSelectedLayer"))
        #expect(layerMenuSource.contains("viewModel.mergeDownActionTitleKey"))
        #expect(layerMenuSource.contains("performMergeDown()"))
        #expect(layerMenuSource.contains("viewModel.canMergeSelectedLayerDown"))
        #expect(layerMenuSource.contains("imageEditor.action.layerFlatten"))
        #expect(layerMenuSource.contains("viewModel.flattenImage()"))
        #expect(layerMenuSource.contains("viewModel.canFlattenImage"))
        #expect(!layerMenuSource.contains("imageEditor.action.layerSmartObjectReplace"))
        #expect(!layerMenuSource.contains("imageEditor.action.layerSmartObjectMakeUnique"))
        #expect(!layerMenuSource.contains("imageEditor.action.layerSmartObjectResetTransform"))
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
        #expect(propertiesMenuSource.contains("viewModel.updateLoadedSmartFilterOnSelectedLayer()"))
        #expect(propertiesMenuSource.contains("viewModel.canUpdateLoadedSmartFilterOnSelectedLayer"))
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

    @Test func gradientFillPanelWiresTheFullColorStopEditor() throws {
        let repositoryRoot = Self.repositoryRoot()
        let viewSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let editorSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "veilpic/ImageEditorGradientFillControls.swift"
            ),
            encoding: .utf8
        )

        #expect(viewSource.contains("ImageEditorGradientFillStopsEditor(viewModel: viewModel)"))
        #expect(viewSource.contains("viewModel.setGradientFillDraftPreset(preset)"))
        #expect(viewSource.contains("image-editor-gradient-fill-dither"))
        #expect(viewSource.contains("$viewModel.gradientFillDither"))
        for identifier in [
            "image-editor-gradient-fill-stops",
            "image-editor-gradient-fill-track",
            "image-editor-gradient-fill-stop-add",
            "image-editor-gradient-fill-stop-remove",
            "image-editor-gradient-fill-stop-color",
            "image-editor-gradient-fill-stop-opacity",
            "image-editor-gradient-fill-stop-position",
            "image-editor-gradient-fill-stop-midpoint"
        ] {
            #expect(editorSource.contains(identifier))
        }
        #expect(editorSource.contains("image-editor-gradient-fill-midpoint-\\(index)"))
        for method in [
            "addGradientFillColorStop()",
            "removeGradientFillColorStop(at:",
            "setGradientFillColorStopColor(",
            "setGradientFillColorStopOpacity(",
            "setGradientFillColorStopPosition(",
            "setGradientFillColorStopMidpoint("
        ] {
            #expect(editorSource.contains(method))
        }
        #expect(editorSource.contains("supportsOpacity: false"))
        #expect(editorSource.contains("ImageEditorTransparencyCheckerboard"))
        #expect(editorSource.contains("SpatialTapGesture("))
        #expect(editorSource.contains("count: 2"))
        #expect(editorSource.contains("addGradientFillColorStop(at: position)"))
        #expect(editorSource.components(separatedBy: "DragGesture(").count - 1 >= 2)
        #expect(editorSource.contains("coordinateSpace: .named(Self.trackCoordinateSpace)"))
        #expect(editorSource.contains("ImageEditorGradientStopTrackGeometry.midpoint("))
        #expect(editorSource.components(separatedBy: ".focusable(false)").count - 1 >= 7)
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
