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
        #expect((color?.redComponent ?? 0) > 0.85)
        #expect((color?.greenComponent ?? 0) > 0.85)
        #expect((color?.blueComponent ?? 0) > 0.85)
        #expect(ImageEditorLayerPanelTab.allCases.count == 3)
    }

    @Test func layerDockTitleUsesReadableLightText() {
        let color = ImageEditorDockDisclosureAppearance.foregroundColor.usingColorSpace(.deviceRGB)

        #expect(color != nil)
        #expect((color?.redComponent ?? 0) > 0.85)
        #expect((color?.greenComponent ?? 0) > 0.85)
        #expect((color?.blueComponent ?? 0) > 0.85)
    }

    @Test func layerPanelTitleUsesReadableLightText() {
        let color = EditorPanelTitleAppearance.foregroundColor.usingColorSpace(.deviceRGB)

        #expect(color != nil)
        #expect((color?.redComponent ?? 0) > 0.85)
        #expect((color?.greenComponent ?? 0) > 0.85)
        #expect((color?.blueComponent ?? 0) > 0.85)
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
