//
//  ImageEditorLayerPanelStyleTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/12.
//

import AppKit
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
}
