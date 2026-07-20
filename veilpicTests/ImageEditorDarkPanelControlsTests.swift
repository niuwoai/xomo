//
//  ImageEditorDarkPanelControlsTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/20.
//

import AppKit
import Testing
@testable import musepic

@Suite
struct ImageEditorDarkPanelControlsTests {
    @Test func nativePanelLabelsKeepExplicitReadableColorsOutsideButtonTinting() throws {
        let primary = ImageEditorDarkPanelNativeLabel()
        primary.appearance = NSAppearance(named: .darkAqua)
        primary.title = "高斯模糊"
        primary.role = .primary

        let primaryColor = try #require(
            primary.attributedTitle.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        )
        let primaryRGB = try #require(primaryColor.usingColorSpace(.deviceRGB))
        #expect(primary.title == "高斯模糊")
        #expect(!primary.acceptsFirstResponder)
        #expect(primary.appearance?.name == .darkAqua)
        #expect(primaryRGB.redComponent > 0.9)
        #expect(primaryRGB.greenComponent > 0.9)
        #expect(primaryRGB.blueComponent > 0.9)

        primary.role = .muted
        let mutedColor = try #require(
            primary.attributedTitle.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        )
        let mutedRGB = try #require(mutedColor.usingColorSpace(.deviceRGB))
        #expect(mutedRGB.redComponent > 0.65)
        #expect(mutedRGB.greenComponent > 0.65)
        #expect(mutedRGB.blueComponent > 0.65)
    }

    @Test func historySearchUsesLightTextPlaceholderAndNoFocusRing() throws {
        let field = NSTextField(string: "打开")

        ImageEditorDarkPanelControlAppearance.configureSearchField(field, placeholder: "搜索历史")

        let textColor = try #require(field.textColor?.usingColorSpace(.deviceRGB))
        let placeholder = try #require(field.placeholderAttributedString)
        let placeholderColor = try #require(
            (placeholder.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor)?
                .usingColorSpace(.deviceRGB)
        )
        #expect(field.appearance?.name == .darkAqua)
        #expect(field.identifier?.rawValue == "image-editor-history-search-field")
        #expect(field.stringValue == "打开")
        #expect(textColor.redComponent > 0.9)
        #expect(placeholderColor.redComponent > 0.7)
        #expect(field.focusRingType == .none)
        #expect(!field.drawsBackground)
        #expect(!field.isBordered)
    }

    @Test func filterPickerUsesDarkAppearanceAndCannotTakeKeyboardFocus() throws {
        let picker = ImageEditorFilterPopUpButton(frame: .zero, pullsDown: false)

        ImageEditorDarkPanelControlAppearance.configureFilterPicker(picker)
        let attributedTitle = ImageEditorDarkPanelControlAppearance.attributedTitle(
            "高斯模糊",
            role: .primary,
            font: NSFont.systemFont(ofSize: 12, weight: .medium)
        )
        let item = NSMenuItem(title: "高斯模糊", action: nil, keyEquivalent: "")
        item.attributedTitle = attributedTitle
        picker.menu?.addItem(item)
        picker.selectItem(at: 0)
        picker.needsDisplay = true

        let titleColor = try #require(
            picker.displayedAttributedTitle.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        )
        let titleRGB = try #require(titleColor.usingColorSpace(.deviceRGB))
        #expect(picker.appearance?.name == .darkAqua)
        #expect(picker.identifier?.rawValue == "image-editor-filter-picker")
        #expect(!picker.acceptsFirstResponder)
        #expect(picker.focusRingType == .none)
        #expect(titleRGB.redComponent > 0.9)
        #expect(titleRGB.greenComponent > 0.9)
        #expect(titleRGB.blueComponent > 0.9)
    }

    @Test func smartFilterBlendPickerUsesTheSameExplicitLightNativeControl() throws {
        let picker = ImageEditorFilterPopUpButton(frame: .zero, pullsDown: false)

        ImageEditorDarkPanelControlAppearance.configureFilterPicker(picker)
        picker.identifier = NSUserInterfaceItemIdentifier("image-editor-smart-filter-blend-mode-picker")
        let blendModes = ImageEditorBlendMode.smartFilterCases
        blendModes.forEach { blendMode in
            let item = NSMenuItem(title: blendMode.title, action: nil, keyEquivalent: "")
            item.attributedTitle = ImageEditorDarkPanelControlAppearance.attributedTitle(
                blendMode.title,
                role: .primary,
                font: NSFont.systemFont(ofSize: 12, weight: .medium)
            )
            picker.menu?.addItem(item)
        }
        let multiplyIndex = try #require(blendModes.firstIndex(of: .multiply))
        picker.selectItem(at: multiplyIndex)

        let titleColor = try #require(
            picker.displayedAttributedTitle.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        )
        let titleRGB = try #require(titleColor.usingColorSpace(.deviceRGB))
        #expect(picker.titleOfSelectedItem == ImageEditorBlendMode.multiply.title)
        #expect(picker.identifier?.rawValue == "image-editor-smart-filter-blend-mode-picker")
        #expect(!picker.acceptsFirstResponder)
        #expect(titleRGB.redComponent > 0.9)
        #expect(titleRGB.greenComponent > 0.9)
        #expect(titleRGB.blueComponent > 0.9)
        #expect(!blendModes.contains(.passThrough))
    }
}
