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
        #expect(colorWell.target === colorWell)
        #expect(colorWell.action != nil)

        _ = colorWell.sendAction(colorWell.action, to: colorWell.target)

        #expect(selectedColor == .systemOrange)
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
        #expect(!colorChipSource.contains("sampleScreenColorForForeground"))
        #expect(!colorChipSource.contains("sampleScreenColorForBackground"))
    }
}
