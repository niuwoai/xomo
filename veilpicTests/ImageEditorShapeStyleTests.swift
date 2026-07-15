//
//  ImageEditorShapeStyleTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/15.
//

import AppKit
import Foundation
import Testing
@testable import musepic

@Suite
@MainActor
struct ImageEditorShapeStyleTests {
    @Test func linearGradientFillClipsToShapeAndPreservesIndependentStroke() throws {
        let gradient = ImageEditorGradientFillContent.shapeLinear(
            startColor: .systemRed,
            endColor: .systemBlue
        )
        let image = ImageEditorShapeContent(
            kind: .rectangle,
            fillColor: .clear,
            fillGradient: gradient,
            fillOpacity: 0.7,
            strokeColor: .systemGreen,
            strokeWidth: 4,
            strokeOpacity: 0.9,
            cornerRadius: 8
        ).renderedImage(size: CGSize(width: 48, height: 32))

        let left = try #require(image.color(at: CGPoint(x: 8, y: 16)))
        let right = try #require(image.color(at: CGPoint(x: 39, y: 16)))
        let edge = try #require(image.color(at: CGPoint(x: 1, y: 16)))
        let corner = try #require(image.color(at: CGPoint(x: 0, y: 0)))
        #expect(left.redComponent > left.blueComponent + 0.2)
        #expect(right.blueComponent > right.redComponent + 0.2)
        #expect(abs(left.alphaComponent - 0.7) < 0.1)
        #expect(edge.greenComponent > edge.redComponent + 0.35)
        #expect(corner.alphaComponent < 0.05)
    }

    @Test func gradientAppearanceIsUndoablePersistentAndCanReturnToSolid() throws {
        let viewModel = makeViewModel()
        viewModel.drawShape(
            from: CGPoint(x: 10, y: 10),
            to: CGPoint(x: 90, y: 60),
            ellipse: false
        )
        let gradient = ImageEditorGradientFillContent.shapeLinear(
            startColor: .systemOrange,
            endColor: .systemPurple,
            angle: 35,
            scale: 1.4
        )
        let historyCount = viewModel.document.history.count

        viewModel.updateSelectedShapeProperties(fillGradient: gradient, fillOpacity: 0.65)
        let edited = try #require(viewModel.document.selectedLayer?.shapeContent)
        #expect(edited.fillGradient == gradient)
        #expect(edited.fillOpacity == 0.65)
        #expect(viewModel.document.history.count == historyCount + 1)

        viewModel.undo()
        #expect(viewModel.document.selectedLayer?.shapeContent?.fillGradient == nil)
        viewModel.redo()
        #expect(viewModel.document.selectedLayer?.shapeContent?.fillGradient == gradient)

        let projectData = try viewModel.projectData()
        let reopened = makeViewModel()
        try reopened.loadProjectData(projectData)
        #expect(reopened.document.selectedLayer?.shapeContent?.fillGradient == gradient)
        #expect(reopened.document.selectedLayer?.shapeContent?.fillOpacity == 0.65)

        reopened.setSelectedShapeFillKind(.solid)
        #expect(reopened.document.selectedLayer?.shapeContent?.fillGradient == nil)
        reopened.undo()
        #expect(reopened.document.selectedLayer?.shapeContent?.fillGradient == gradient)
    }

    @Test func fillAndStrokeRenderAsIndependentEditableProperties() throws {
        let image = ImageEditorShapeContent(
            kind: .rectangle,
            fillColor: .systemRed,
            fillOpacity: 0.6,
            strokeColor: .systemBlue,
            strokeWidth: 6,
            strokeOpacity: 0.8
        ).renderedImage(size: CGSize(width: 40, height: 30))

        let center = try #require(image.color(at: CGPoint(x: 20, y: 15)))
        let edge = try #require(image.color(at: CGPoint(x: 1, y: 15)))
        #expect(center.redComponent > center.blueComponent + 0.5)
        #expect(abs(center.alphaComponent - 0.6) < 0.08)
        #expect(edge.blueComponent > edge.redComponent + 0.5)
        #expect(abs(edge.alphaComponent - 0.8) < 0.08)
    }

    @Test func appearanceEditIsOneUndoableProjectPersistentChange() throws {
        let viewModel = makeViewModel()
        viewModel.drawShape(
            from: CGPoint(x: 10, y: 10),
            to: CGPoint(x: 70, y: 50),
            ellipse: false
        )
        let original = try #require(viewModel.document.selectedLayer?.shapeContent)
        let historyCount = viewModel.document.history.count

        viewModel.updateSelectedShapeProperties(
            fillColor: .systemRed,
            fillOpacity: 0.55,
            strokeColor: .systemBlue,
            strokeOpacity: 0.75,
            strokeWidth: 7
        )

        let edited = try #require(viewModel.document.selectedLayer?.shapeContent)
        #expect(edited.fillColor.isEqual(NSColor.systemRed))
        #expect(edited.fillOpacity == 0.55)
        #expect(edited.strokeColor.isEqual(NSColor.systemBlue))
        #expect(edited.strokeOpacity == 0.75)
        #expect(edited.strokeWidth == 7)
        #expect(viewModel.document.history.count == historyCount + 1)

        viewModel.undo()
        let undone = try #require(viewModel.document.selectedLayer?.shapeContent)
        #expect(undone.fillColor.isEqual(original.fillColor))
        #expect(undone.fillOpacity == original.fillOpacity)
        #expect(undone.strokeColor.isEqual(original.strokeColor))
        #expect(undone.strokeOpacity == original.strokeOpacity)
        #expect(undone.strokeWidth == original.strokeWidth)
        viewModel.redo()
        let redone = try #require(viewModel.document.selectedLayer?.shapeContent)
        #expect(redone.fillColor.isEqual(edited.fillColor))
        #expect(redone.fillOpacity == edited.fillOpacity)
        #expect(redone.strokeColor.isEqual(edited.strokeColor))
        #expect(redone.strokeOpacity == edited.strokeOpacity)
        #expect(redone.strokeWidth == edited.strokeWidth)

        let projectData = try viewModel.projectData()
        let reopened = makeViewModel()
        try reopened.loadProjectData(projectData)
        let restored = try #require(reopened.document.selectedLayer?.shapeContent)
        #expect(restored.fillColor.isEqual(edited.fillColor))
        #expect(restored.fillOpacity == edited.fillOpacity)
        #expect(restored.strokeColor.isEqual(edited.strokeColor))
        #expect(restored.strokeOpacity == edited.strokeOpacity)
        #expect(restored.strokeWidth == edited.strokeWidth)
    }

    @Test func lockedShapeRejectsAppearanceChanges() throws {
        let viewModel = makeViewModel()
        viewModel.drawShape(
            from: CGPoint(x: 8, y: 8),
            to: CGPoint(x: 48, y: 38),
            ellipse: false
        )
        let selectedID = try #require(viewModel.document.selectedLayerID)
        let selectedIndex = try #require(viewModel.document.layers.firstIndex { $0.id == selectedID })
        let original = try #require(viewModel.document.layers[selectedIndex].shapeContent)
        let historyCount = viewModel.document.history.count
        viewModel.document.layers[selectedIndex].isLocked = true

        viewModel.updateSelectedShapeProperties(fillColor: .systemGreen, strokeWidth: 20)

        let locked = try #require(viewModel.document.layers[selectedIndex].shapeContent)
        #expect(locked.fillColor.isEqual(original.fillColor))
        #expect(locked.strokeWidth == original.strokeWidth)
        #expect(viewModel.document.history.count == historyCount)
    }

    @Test func propertiesPanelControlsStayKeyboardNeutral() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot()
                .appendingPathComponent("veilpic/ImageEditorShapeStyleControls.swift"),
            encoding: .utf8
        )
        for identifier in [
            "image-editor-shape-fill-kind",
            "image-editor-shape-fill-color",
            "image-editor-shape-gradient-start-color",
            "image-editor-shape-gradient-end-color",
            "image-editor-shape-gradient-angle",
            "image-editor-shape-fill-opacity",
            "image-editor-shape-stroke-color",
            "image-editor-shape-stroke-opacity",
            "image-editor-shape-stroke-width"
        ] {
            #expect(source.contains(identifier))
        }
        #expect(source.components(separatedBy: ".focusable(false)").count - 1 == 8)
    }

    private func makeViewModel() -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "shape-style.png",
            image: NSImage.transparent(size: CGSize(width: 120, height: 80))
        ) { _ in }
    }

    private static func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
