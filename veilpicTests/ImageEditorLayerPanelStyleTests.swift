//
//  ImageEditorLayerPanelStyleTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/12.
//

import AppKit
import Foundation
import Testing
@testable import musepic

@Suite
struct ImageEditorLayerPanelStyleTests {
    @Test func everyLayerPanelTabUsesReadableLightText() {
        let color = ImageEditorLayerPanelTabAppearance.foregroundColor.usingColorSpace(.deviceRGB)

        #expect(color != nil)
        #expect((color?.redComponent ?? 0) > 0.8)
        #expect((color?.greenComponent ?? 0) > 0.8)
        #expect((color?.blueComponent ?? 0) > 0.8)
        #expect(ImageEditorLayerPanelTab.allCases.count == 3)
    }

    @Test func nativeTabLabelKeepsExplicitLightTextOutsideSwiftUIButtonTinting() {
        let label = NSTextField(labelWithString: "")

        ImageEditorLayerPanelTabAppearance.configure(label, title: "通道", isSelected: false)
        let unselectedColor = label.textColor?.usingColorSpace(.deviceRGB)
        #expect(label.stringValue == "通道")
        #expect(label.refusesFirstResponder)
        #expect((unselectedColor?.redComponent ?? 0) > 0.8)

        ImageEditorLayerPanelTabAppearance.configure(label, title: "图层", isSelected: true)
        let selectedColor = label.textColor?.usingColorSpace(.deviceRGB)
        #expect(label.stringValue == "图层")
        #expect((selectedColor?.redComponent ?? 0) > 0.99)
        #expect((selectedColor?.greenComponent ?? 0) > 0.99)
        #expect((selectedColor?.blueComponent ?? 0) > 0.99)
    }

    @Test func layerDockTitleUsesWhiteText() {
        let color = ImageEditorDockDisclosureAppearance.foregroundColor.usingColorSpace(.deviceRGB)

        #expect(color != nil)
        #expect((color?.redComponent ?? 0) > 0.99)
        #expect((color?.greenComponent ?? 0) > 0.99)
        #expect((color?.blueComponent ?? 0) > 0.99)
    }

    @Test func layerPanelTitleUsesWhiteText() {
        let color = EditorPanelTitleAppearance.foregroundColor.usingColorSpace(.deviceRGB)

        #expect(color != nil)
        #expect((color?.redComponent ?? 0) > 0.99)
        #expect((color?.greenComponent ?? 0) > 0.99)
        #expect((color?.blueComponent ?? 0) > 0.99)
    }

    @Test func dockDisclosureAppliesLightTextToEveryVisibleLabel() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let declaration = try #require(source.range(of: "struct EditorDockDisclosure<Content: View>: View"))
        let nextDeclaration = try #require(
            source[declaration.upperBound...].range(of: "private struct ImageEditorMarqueeToolSymbol")
        )
        let disclosureSource = source[declaration.lowerBound..<nextDeclaration.lowerBound]
        let explicitForegroundUses = disclosureSource.components(
            separatedBy: "ImageEditorDockDisclosureAppearance.foregroundColor"
        ).count - 1

        #expect(explicitForegroundUses == 3)
    }

    private static func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
