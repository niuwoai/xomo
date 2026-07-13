//
//  ImageEditorLayerStylePresetQueryTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/14.
//

import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorLayerStylePresetQueryTests {
    @Test func queryMatchesCaseAndDiacriticsWithoutChangingSourceOrder() {
        let presets = [
            preset(id: "builtin.shadow", name: "Soft Shadow"),
            preset(id: "custom-one", name: "Néon Card"),
            preset(id: "custom-two", name: "Neon Text")
        ]

        let result = ImageEditorLayerStylePresetQuery(
            searchText: "  NEON ",
            scope: .all
        ).filter(presets)

        #expect(result.map(\.id) == ["custom-one", "custom-two"])
    }

    @Test func sourceScopeSeparatesBuiltInAndCustomPresets() {
        let presets = ImageEditorLayerStyleBuiltInPresetCatalog.presets + [
            preset(id: "custom-one", name: "My Shadow"),
            preset(id: "custom-two", name: "My Glow")
        ]

        let builtIns = ImageEditorLayerStylePresetQuery(searchText: "", scope: .builtIn)
            .filter(presets)
        let customs = ImageEditorLayerStylePresetQuery(searchText: "", scope: .custom)
            .filter(presets)

        #expect(builtIns.count == ImageEditorLayerStyleBuiltInPresetCatalog.presets.count)
        #expect(builtIns.allSatisfy { $0.isBuiltIn })
        #expect(customs.map(\.id) == ["custom-one", "custom-two"])
        #expect(customs.allSatisfy { !$0.isBuiltIn })
    }

    @Test func queryRepairsSelectionOnlyWhenCurrentPresetIsHidden() {
        let presets = [
            preset(id: "custom-shadow", name: "Shadow"),
            preset(id: "custom-glow", name: "Glow")
        ]
        let all = ImageEditorLayerStylePresetQuery(searchText: "", scope: .all)
        let glow = ImageEditorLayerStylePresetQuery(searchText: "glow", scope: .all)
        let missing = ImageEditorLayerStylePresetQuery(searchText: "bevel", scope: .all)

        #expect(all.repairedSelectionID("custom-shadow", in: presets) == "custom-shadow")
        #expect(glow.repairedSelectionID("custom-shadow", in: presets) == "custom-glow")
        #expect(missing.repairedSelectionID("custom-shadow", in: presets) == nil)
    }

    @Test func presetManagerConnectsSearchScopeAndStableAccessibilityIdentifiers() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorLayerStylePresetManager.swift"),
            encoding: .utf8
        )

        #expect(source.contains("ImageEditorLayerStylePresetQuery("))
        #expect(source.contains("image-editor-layer-style-preset-search"))
        #expect(source.contains("image-editor-layer-style-preset-scope"))
        #expect(source.contains("query.repairedSelectionID"))
    }

    private func preset(id: String, name: String) -> ImageEditorLayerStylePreset {
        var style = ImageEditorLayerStyle()
        style.strokeEnabled = true
        return ImageEditorLayerStylePreset(
            id: id,
            name: name,
            style: ImageEditorProjectLayerStyle(style: style)
        )
    }
}
