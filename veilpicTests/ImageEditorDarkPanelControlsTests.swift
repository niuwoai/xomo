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
        let host = ImageEditorFilterPickerHost()
        let picker = host.picker

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
        ImageEditorDarkPanelControlAppearance.synchronizeSelectedTitle(on: picker)
        host.frame = NSRect(x: 0, y: 0, width: 240, height: 24)
        host.layoutSubtreeIfNeeded()

        let titleColor = try #require(
            picker.displayedAttributedTitle.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        )
        let titleRGB = try #require(titleColor.usingColorSpace(.deviceRGB))
        let nativeTitleColor = try #require(
            picker.attributedTitle.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        )
        let nativeTitleRGB = try #require(nativeTitleColor.usingColorSpace(.deviceRGB))
        let cellTitleColor = try #require(
            (picker.cell as? NSPopUpButtonCell)?.attributedTitle.attribute(
                .foregroundColor,
                at: 0,
                effectiveRange: nil
            ) as? NSColor
        )
        let cellTitleRGB = try #require(cellTitleColor.usingColorSpace(.deviceRGB))
        let visibleTitleColor = try #require(
            host.displayedTitleLabel.attributedStringValue.attribute(
                .foregroundColor,
                at: 0,
                effectiveRange: nil
            ) as? NSColor
        )
        let visibleTitleRGB = try #require(visibleTitleColor.usingColorSpace(.deviceRGB))
        #expect(picker.appearance?.name == .darkAqua)
        #expect(picker.identifier?.rawValue == "image-editor-filter-picker")
        #expect(!picker.acceptsFirstResponder)
        #expect(picker.focusRingType == .none)
        #expect(titleRGB.redComponent > 0.9)
        #expect(titleRGB.greenComponent > 0.9)
        #expect(titleRGB.blueComponent > 0.9)
        #expect(nativeTitleRGB.redComponent > 0.9)
        #expect(cellTitleRGB.redComponent > 0.9)
        #expect(visibleTitleRGB.redComponent > 0.9)
        #expect(host.displayedTitleLabel.identifier?.rawValue == "image-editor-filter-visible-title")
        #expect(host.displayedTitleLabel.hitTest(.zero) == nil)
        #expect(host.subviews.last === host.displayedTitleLabel)
        #expect(host.picker.frame == host.bounds)
        #expect(host.displayedTitleLabel.frame.width == 206)
    }

    @Test func filterPickerHostActuallyRendersLightTitlePixels() throws {
        let host = ImageEditorFilterPickerHost(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        let picker = host.picker
        let item = NSMenuItem(title: "高斯模糊", action: nil, keyEquivalent: "")
        item.attributedTitle = ImageEditorDarkPanelControlAppearance.attributedTitle(
            item.title,
            role: .primary,
            font: NSFont.systemFont(ofSize: 12, weight: .medium)
        )
        picker.menu?.addItem(item)
        picker.selectItem(at: 0)
        ImageEditorDarkPanelControlAppearance.synchronizeSelectedTitle(on: picker)
        host.layoutSubtreeIfNeeded()

        let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        var maximumLuminance = 0.0
        for x in 8..<120 {
            for y in 0..<24 {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                maximumLuminance = max(
                    maximumLuminance,
                    0.2126 * color.redComponent + 0.7152 * color.greenComponent + 0.0722 * color.blueComponent
                )
            }
        }

        #expect(maximumLuminance > 0.8)
    }

    @Test func smartFilterBlendPickerUsesTheSameExplicitLightNativeControl() throws {
        let host = ImageEditorFilterPickerHost()
        let picker = host.picker

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
        ImageEditorDarkPanelControlAppearance.synchronizeSelectedTitle(on: picker)

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
        #expect(picker.attributedTitle.string == ImageEditorBlendMode.multiply.title)
        #expect(!blendModes.contains(.passThrough))
    }
}
