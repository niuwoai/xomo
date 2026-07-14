//
//  ImageEditorShapeCornerRadiusTests.swift
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
struct ImageEditorShapeCornerRadiusTests {
    @Test func roundedRectangleRendersTransparentCornersWithoutRasterizingTheShape() throws {
        let size = CGSize(width: 40, height: 30)
        let rounded = ImageEditorShapeContent(
            kind: .rectangle,
            fillColor: .systemRed,
            fillOpacity: 1,
            strokeColor: .clear,
            strokeWidth: 1,
            strokeOpacity: 0,
            cornerRadius: 12
        ).renderedImage(size: size)
        let square = ImageEditorShapeContent(
            kind: .rectangle,
            fillColor: .systemRed,
            fillOpacity: 1,
            strokeColor: .clear,
            strokeWidth: 1,
            strokeOpacity: 0
        ).renderedImage(size: size)

        let roundedCorner = try #require(rounded.color(at: CGPoint(x: 1, y: 1)))
        let roundedCenter = try #require(rounded.color(at: CGPoint(x: 20, y: 15)))
        let squareCorner = try #require(square.color(at: CGPoint(x: 1, y: 1)))
        #expect(roundedCorner.alphaComponent < 0.1)
        #expect(roundedCenter.alphaComponent > 0.9)
        #expect(squareCorner.alphaComponent > 0.9)
    }

    @Test func independentCornerRadiiRenderPersistUndoAndScale() throws {
        let size = CGSize(width: 60, height: 40)
        let independent = ImageEditorShapeContent(
            kind: .rectangle,
            fillColor: .systemBlue,
            fillOpacity: 1,
            strokeColor: .clear,
            strokeWidth: 1,
            strokeOpacity: 0,
            cornerRadii: ImageEditorRectangleCornerRadii(
                topLeft: 16,
                topRight: 0,
                bottomRight: 0,
                bottomLeft: 0
            )
        ).renderedImage(size: size)
        let topLeft = try #require(independent.color(at: CGPoint(x: 1, y: 1)))
        let topRight = try #require(independent.color(at: CGPoint(x: 58, y: 1)))
        #expect(topLeft.alphaComponent < 0.1)
        #expect(topRight.alphaComponent > 0.9)

        let viewModel = ImageEditorViewModel(
            sourceName: "independent-corners.png",
            image: NSImage.transparent(size: CGSize(width: 120, height: 80))
        ) { _ in }
        viewModel.drawShape(
            from: CGPoint(x: 10, y: 10),
            to: CGPoint(x: 70, y: 50),
            ellipse: false
        )
        viewModel.setSelectedRectangleCornerRadius(8)
        viewModel.setSelectedRectangleUsesIndependentCornerRadii(true)
        viewModel.setSelectedRectangleCornerRadius(4, at: .topLeft)
        viewModel.setSelectedRectangleCornerRadius(12, at: .bottomRight)

        let edited = try #require(viewModel.document.selectedLayer?.shapeContent)
        #expect(edited.cornerRadii == ImageEditorRectangleCornerRadii(
            topLeft: 4,
            topRight: 8,
            bottomRight: 12,
            bottomLeft: 8
        ))
        viewModel.undo()
        #expect(viewModel.document.selectedLayer?.shapeContent?.cornerRadii?.bottomRight == 8)
        viewModel.redo()
        #expect(viewModel.document.selectedLayer?.shapeContent?.cornerRadii?.bottomRight == 12)

        let projectData = try viewModel.projectData()
        let reopened = ImageEditorViewModel(
            sourceName: "empty.png",
            image: NSImage.transparent(size: CGSize(width: 8, height: 8))
        ) { _ in }
        try reopened.loadProjectData(projectData)
        #expect(reopened.document.selectedLayer?.shapeContent?.cornerRadii == edited.cornerRadii)

        reopened.resizeImage(to: CGSize(width: 240, height: 160))
        #expect(reopened.document.selectedLayer?.shapeContent?.cornerRadii == ImageEditorRectangleCornerRadii(
            topLeft: 8,
            topRight: 16,
            bottomRight: 24,
            bottomLeft: 16
        ))
    }

    @Test func cornerRadiusEditsUndoPersistsAndScalesWithTheImage() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "corner-radius.png",
            image: NSImage.transparent(size: CGSize(width: 120, height: 80))
        ) { _ in }
        viewModel.drawShape(
            from: CGPoint(x: 10, y: 10),
            to: CGPoint(x: 70, y: 50),
            ellipse: false
        )

        viewModel.setSelectedRectangleCornerRadius(12)
        #expect(viewModel.selectedRectangleCornerRadius == 12)
        #expect(viewModel.document.selectedLayer?.shapeContent?.cornerRadius == 12)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.shapeCornerRadius"))

        viewModel.undo()
        #expect(viewModel.document.selectedLayer?.shapeContent?.cornerRadius == 0)
        viewModel.redo()
        #expect(viewModel.document.selectedLayer?.shapeContent?.cornerRadius == 12)

        let projectData = try viewModel.projectData()
        let reopened = ImageEditorViewModel(
            sourceName: "empty.png",
            image: NSImage.transparent(size: CGSize(width: 8, height: 8))
        ) { _ in }
        try reopened.loadProjectData(projectData)
        #expect(reopened.document.selectedLayer?.shapeContent?.cornerRadius == 12)

        reopened.resizeImage(to: CGSize(width: 240, height: 160))
        #expect(reopened.document.selectedLayer?.shapeContent?.cornerRadius == 24)
    }

    @Test func cornerRadiusClampsToHalfTheShortSideAndLockedShapesStayUnchanged() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "corner-radius-clamp.png",
            image: NSImage.transparent(size: CGSize(width: 100, height: 70))
        ) { _ in }
        viewModel.drawShape(
            from: CGPoint(x: 10, y: 10),
            to: CGPoint(x: 70, y: 40),
            ellipse: false
        )

        viewModel.setSelectedRectangleCornerRadius(999)
        #expect(viewModel.selectedRectangleCornerRadius == 15)

        let selectedID = try #require(viewModel.document.selectedLayerID)
        let selectedIndex = try #require(viewModel.document.layers.firstIndex { $0.id == selectedID })
        viewModel.document.layers[selectedIndex].isLocked = true
        viewModel.setSelectedRectangleCornerRadius(4)
        #expect(viewModel.selectedRectangleCornerRadius == 15)
    }

    @Test func propertiesPanelExposesAKeyboardNeutralCornerRadiusStepper() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        #expect(source.contains("image-editor-shape-corner-radius"))
        #expect(source.contains("image-editor-shape-independent-corners"))
        #expect(source.contains("imageEditor.properties.shapeCornerRadiusValue"))
        #expect(source.contains("imageEditor.properties.shapeCornerValue"))
        #expect(source.contains("viewModel.setSelectedRectangleCornerRadius"))
    }

    private static func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
