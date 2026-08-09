import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorColorWellTests {
    @Test
    func colorWellIsKeyboardNeutralAndPublishesContinuousColorChanges() {
        let colorWell = ImageEditorColorWellControl(
            frame: NSRect(x: 0, y: 0, width: 26, height: 26)
        )
        var selectedColor: NSColor?
        colorWell.onColorChange = { selectedColor = $0 }
        colorWell.color = .systemOrange

        #expect(!colorWell.acceptsFirstResponder)
        #expect(colorWell.isContinuous)
        #expect(!colorWell.isBordered)
        #expect(colorWell.focusRingType == .none)
        #expect(ImageEditorColorWellControl.swatchBorderWidth == 1)
        #expect(colorWell.target === colorWell)
        #expect(colorWell.action != nil)

        _ = colorWell.sendAction(colorWell.action, to: colorWell.target)

        #expect(selectedColor == .systemOrange)
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
        #expect(colorChipSource.contains(".focusable(false)"))
        #expect(colorChipSource.contains(".xomoFocusEffectDisabled()"))
        #expect(!colorChipSource.contains(".strokeBorder("))
        #expect(!colorChipSource.contains("sampleScreenColorForForeground"))
        #expect(!colorChipSource.contains("sampleScreenColorForBackground"))
    }
}
