import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorColorWellTests {
    @Test
    func colorWellIsKeyboardNeutralAndPublishesContinuousColorChanges() throws {
        let colorWell = ImageEditorColorWellControl(
            frame: NSRect(x: 0, y: 0, width: 26, height: 26)
        )
        var selectedColor: NSColor?
        colorWell.onColorChange = { selectedColor = $0 }
        colorWell.color = .systemOrange

        #expect(!colorWell.acceptsFirstResponder)
        #expect(colorWell.isAccessibilityElement())
        #expect(colorWell.accessibilityRole() == .colorWell)
        #expect(ImageEditorColorWellControl.swatchBorderWidth == 1)
        colorWell.onColorChange?(.systemOrange)
        #expect(selectedColor == .systemOrange)

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let controlSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorColorWell.swift"),
            encoding: .utf8
        )
        #expect(controlSource.contains("final class ImageEditorColorWellControl: NSView"))
        #expect(!controlSource.contains("final class ImageEditorColorWellControl: NSControl"))
        let targetBinding = try #require(controlSource.range(of: "panel.setTarget(self)"))
        let colorAssignment = try #require(controlSource.range(of: "panel.color = color"))
        #expect(targetBinding.lowerBound < colorAssignment.lowerBound)
        let previousSessionEnd = try #require(
            controlSource.range(of: "activeColorWell.endColorPanelEditing()")
        )
        let sessionBegin = try #require(controlSource.range(of: "beginColorPanelEditing()"))
        #expect(previousSessionEnd.lowerBound < sessionBegin.lowerBound)
        #expect(sessionBegin.lowerBound < targetBinding.lowerBound)
        #expect(controlSource.contains("NSWindow.didResignKeyNotification"))
        #expect(controlSource.contains("NSWindow.willCloseNotification"))
        #expect(controlSource.contains("NSMenu.didBeginTrackingNotification"))
        #expect(controlSource.contains("NSApplication.didResignActiveNotification"))
    }

    @Test
    func colorWellRendersAFullSquareSwatchWithoutNativePillCorners() throws {
        let colorWell = ImageEditorColorWellControl(
            frame: NSRect(x: 0, y: 0, width: 26, height: 26)
        )
        colorWell.color = .systemOrange
        let bitmap = try #require(colorWell.bitmapImageRepForCachingDisplay(in: colorWell.bounds))
        colorWell.cacheDisplay(in: colorWell.bounds, to: bitmap)

        let nearCorner = try #require(bitmap.colorAt(x: 2, y: 2)?.usingColorSpace(.deviceRGB))
        let center = try #require(bitmap.colorAt(x: 13, y: 13)?.usingColorSpace(.deviceRGB))
        #expect(nearCorner.redComponent > 0.8)
        #expect(nearCorner.greenComponent > 0.25)
        #expect(center.redComponent > 0.8)
        #expect(center.greenComponent > 0.25)
    }

    @Test
    func mouseEquivalentAndAccessibilityActivationShareTheColorPanelAction() {
        let colorWell = ImageEditorColorWellControl(
            frame: NSRect(x: 0, y: 0, width: 26, height: 26)
        )
        var activationCount = 0
        colorWell.colorPanelActivationHandler = { activationCount += 1 }

        colorWell.performClick(nil)
        #expect(activationCount == 1)
        #expect(colorWell.accessibilityPerformPress())
        #expect(activationCount == 2)
    }

    @Test
    func colorPanelEditingLifecycleBeginsAndEndsExactlyOnce() {
        let colorWell = ImageEditorColorWellControl(
            frame: NSRect(x: 0, y: 0, width: 26, height: 26)
        )
        var beginCount = 0
        var endCount = 0
        colorWell.onEditingBegan = {
            beginCount += 1
            return true
        }
        colorWell.onEditingEnded = { endCount += 1 }

        colorWell.beginColorPanelEditing()
        colorWell.beginColorPanelEditing()
        #expect(colorWell.isColorPanelEditing)
        #expect(beginCount == 1)

        colorWell.endColorPanelEditing()
        colorWell.endColorPanelEditing()
        #expect(!colorWell.isColorPanelEditing)
        #expect(endCount == 1)

        colorWell.beginColorPanelEditing()
        ImageEditorColorWell.dismantleNSView(colorWell, coordinator: ())
        #expect(!colorWell.isColorPanelEditing)
        #expect(beginCount == 2)
        #expect(endCount == 2)

        let rejectedColorWell = ImageEditorColorWellControl(frame: .zero)
        rejectedColorWell.onEditingBegan = { false }
        #expect(!rejectedColorWell.beginColorPanelEditing())
        #expect(!rejectedColorWell.isColorPanelEditing)
    }

    @Test
    func editorUsesColorWellsInsteadOfInvisibleScreenSamplerButtons() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let start = try #require(source.range(of: "private var colorChips:"))
        let end = try #require(
            source[start.upperBound...].range(of: "private var canvasWorkspace:")
        )
        let colorChipSource = source[start.lowerBound..<end.lowerBound]

        #expect(colorChipSource.contains("ImageEditorColorWell("))
        #expect(colorChipSource.contains("image-editor-foreground-color-well"))
        #expect(colorChipSource.contains("image-editor-background-color-well"))
        #expect(colorChipSource.contains("viewModel.resetForegroundBackgroundColors()"))
        #expect(colorChipSource.contains("image-editor-color-default"))
        #expect(colorChipSource.contains("imageEditor.action.colorDefaultForegroundBackground"))
        #expect(colorChipSource.contains(".buttonStyle(.plain)"))
        #expect(colorChipSource.contains(".focusable(false)"))
        #expect(colorChipSource.contains(".xomoFocusEffectDisabled()"))
        #expect(!colorChipSource.contains("EditorIconButtonStyle"))
        #expect(!colorChipSource.contains(".strokeBorder("))
        #expect(!colorChipSource.contains("NSColorWell"))
        #expect(!colorChipSource.contains("sampleScreenColorForForeground"))
        #expect(!colorChipSource.contains("sampleScreenColorForBackground"))
    }
}
