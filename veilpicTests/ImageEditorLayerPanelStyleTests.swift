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
        #expect(ImageEditorLayerPanelTab.allCases.count == 4)
    }

    @Test func nativeTabLabelDrawsExplicitLightTextOutsideSwiftUIButtonTinting() {
        let label = ImageEditorLayerPanelTabNativeLabel()
        label.appearance = NSAppearance(named: .darkAqua)
        label.title = "通道"
        label.isSelected = false
        let attributedUnselectedColor = label.attributedTitle.attribute(
            .foregroundColor,
            at: 0,
            effectiveRange: nil
        ) as? NSColor
        let unselectedColor = attributedUnselectedColor?.usingColorSpace(.deviceRGB)
        #expect(label.title == "通道")
        #expect(!label.acceptsFirstResponder)
        #expect(label.appearance?.name == .darkAqua)
        #expect((unselectedColor?.redComponent ?? 0) > 0.85)
        #expect((unselectedColor?.greenComponent ?? 0) > 0.85)
        #expect((unselectedColor?.blueComponent ?? 0) > 0.85)
        #expect(attributedUnselectedColor == ImageEditorLayerPanelTabAppearance.foregroundColor)

        label.title = "图层"
        label.isSelected = true
        let attributedSelectedColor = label.attributedTitle.attribute(
            .foregroundColor,
            at: 0,
            effectiveRange: nil
        ) as? NSColor
        let selectedColor = attributedSelectedColor?.usingColorSpace(.deviceRGB)
        #expect(label.title == "图层")
        #expect((selectedColor?.redComponent ?? 0) > 0.99)
        #expect((selectedColor?.greenComponent ?? 0) > 0.99)
        #expect((selectedColor?.blueComponent ?? 0) > 0.99)
        #expect(attributedSelectedColor == ImageEditorLayerPanelTabAppearance.selectedForegroundColor)
    }

    @Test func layerDockTitleUsesWhiteText() {
        let color = ImageEditorDockDisclosureAppearance.foregroundColor.usingColorSpace(.deviceRGB)

        #expect(color != nil)
        #expect((color?.redComponent ?? 0) > 0.99)
        #expect((color?.greenComponent ?? 0) > 0.99)
        #expect((color?.blueComponent ?? 0) > 0.99)
    }

    @Test func layerPanelTitleUsesWhiteText() throws {
        let color = EditorPanelTitleAppearance.foregroundColor.usingColorSpace(.deviceRGB)

        #expect(color != nil)
        #expect((color?.redComponent ?? 0) > 0.99)
        #expect((color?.greenComponent ?? 0) > 0.99)
        #expect((color?.blueComponent ?? 0) > 0.99)

        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        #expect(source.contains(
            ".foregroundColor(Color(nsColor: EditorPanelTitleAppearance.foregroundColor))"
        ))
    }

    @Test func layerSearchFieldUsesReadableLightTextAndPlaceholder() {
        let textColor = ImageEditorLayerSearchAppearance.textColor.usingColorSpace(.deviceRGB)
        let placeholderColor = ImageEditorLayerSearchAppearance.placeholderColor.usingColorSpace(.deviceRGB)

        #expect((textColor?.redComponent ?? 0) > 0.9)
        #expect((textColor?.greenComponent ?? 0) > 0.9)
        #expect((textColor?.blueComponent ?? 0) > 0.9)
        #expect((placeholderColor?.redComponent ?? 0) > 0.7)
        #expect((placeholderColor?.greenComponent ?? 0) > 0.7)
        #expect((placeholderColor?.blueComponent ?? 0) > 0.7)
    }

    @Test func nativeLayerSearchFieldKeepsExplicitLightPlaceholderAndInputText() throws {
        let field = NSTextField(string: "按钮")

        ImageEditorLayerSearchAppearance.configure(field, placeholder: "搜索图层")

        let textColor = try #require(field.textColor?.usingColorSpace(.deviceRGB))
        let placeholder = try #require(field.placeholderAttributedString)
        let rawPlaceholderColor = try #require(
            placeholder.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        )
        let placeholderColor = try #require(rawPlaceholderColor.usingColorSpace(.deviceRGB))
        #expect(field.appearance?.name == .darkAqua)
        #expect(field.identifier?.rawValue == "image-editor-layer-search-field")
        #expect(field.stringValue == "按钮")
        #expect(placeholder.string == "搜索图层")
        #expect(textColor.redComponent > 0.9)
        #expect(placeholderColor.redComponent > 0.7)
        #expect(!field.drawsBackground)
        #expect(!field.isBordered)
        #expect(field.focusRingType == .none)
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
