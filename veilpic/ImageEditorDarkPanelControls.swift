//
//  ImageEditorDarkPanelControls.swift
//  veilpic
//
//  Created by Codex on 2026/7/20.
//

import AppKit
import SwiftUI

enum ImageEditorDarkPanelTextRole {
    case primary
    case muted

    var color: NSColor {
        switch self {
        case .primary:
            return ImageEditorTheme.text
        case .muted:
            return ImageEditorTheme.mutedText
        }
    }
}

enum ImageEditorDarkPanelControlAppearance {
    static let placeholderColor = NSColor(calibratedWhite: 0.72, alpha: 1)

    static func attributedTitle(
        _ title: String,
        role: ImageEditorDarkPanelTextRole,
        font: NSFont
    ) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byTruncatingTail
        return NSAttributedString(
            string: title,
            attributes: [
                .foregroundColor: role.color,
                .font: font,
                .paragraphStyle: paragraphStyle
            ]
        )
    }

    static func configureSearchField(_ field: NSTextField, placeholder: String) {
        let font = NSFont.systemFont(ofSize: 11, weight: .regular)
        field.appearance = NSAppearance(named: .darkAqua)
        field.textColor = ImageEditorTheme.text
        field.font = font
        field.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: placeholderColor,
                .font: font
            ]
        )
        field.drawsBackground = false
        field.isBordered = false
        field.isBezeled = false
        field.focusRingType = .none
        field.lineBreakMode = .byTruncatingTail
        field.usesSingleLineMode = true
        field.identifier = NSUserInterfaceItemIdentifier("image-editor-history-search-field")
    }

    static func configureFilterPicker(_ picker: ImageEditorFilterPopUpButton) {
        picker.appearance = NSAppearance(named: .darkAqua)
        picker.focusRingType = .none
        picker.controlSize = .small
        picker.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        picker.contentTintColor = ImageEditorTheme.text
        picker.identifier = NSUserInterfaceItemIdentifier("image-editor-filter-picker")
    }
}

final class ImageEditorDarkPanelNativeLabel: NSView {
    var title = "" {
        didSet {
            setAccessibilityLabel(title)
            invalidateIntrinsicContentSize()
            needsDisplay = true
        }
    }
    var role = ImageEditorDarkPanelTextRole.primary {
        didSet { needsDisplay = true }
    }
    var font = NSFont.systemFont(ofSize: 12, weight: .medium) {
        didSet {
            invalidateIntrinsicContentSize()
            needsDisplay = true
        }
    }

    override var acceptsFirstResponder: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
    }

    override var intrinsicContentSize: NSSize {
        let size = attributedTitle.size()
        return NSSize(width: ceil(size.width), height: max(16, ceil(size.height)))
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        attributedTitle.draw(
            in: NSRect(
                x: 0,
                y: max(0, (bounds.height - attributedTitle.size().height) / 2),
                width: bounds.width,
                height: attributedTitle.size().height
            )
        )
    }

    var attributedTitle: NSAttributedString {
        ImageEditorDarkPanelControlAppearance.attributedTitle(title, role: role, font: font)
    }
}

struct ImageEditorDarkPanelLabel: NSViewRepresentable {
    let title: String
    var role = ImageEditorDarkPanelTextRole.primary
    var font = NSFont.systemFont(ofSize: 12, weight: .medium)

    func makeNSView(context: Context) -> ImageEditorDarkPanelNativeLabel {
        let label = ImageEditorDarkPanelNativeLabel()
        configure(label)
        return label
    }

    func updateNSView(_ label: ImageEditorDarkPanelNativeLabel, context: Context) {
        configure(label)
    }

    private func configure(_ label: ImageEditorDarkPanelNativeLabel) {
        label.appearance = NSAppearance(named: .darkAqua)
        label.identifier = NSUserInterfaceItemIdentifier("image-editor-dark-panel-label")
        label.title = title
        label.role = role
        label.font = font
    }
}

struct ImageEditorHistorySearchField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(string: text)
        field.delegate = context.coordinator
        ImageEditorDarkPanelControlAppearance.configureSearchField(field, placeholder: placeholder)
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.text = $text
        if field.stringValue != text {
            field.stringValue = text
        }
        ImageEditorDarkPanelControlAppearance.configureSearchField(field, placeholder: placeholder)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
        }
    }
}

final class ImageEditorFilterPopUpButton: NSPopUpButton {
    override var acceptsFirstResponder: Bool { false }

    var displayedAttributedTitle: NSAttributedString {
        ImageEditorDarkPanelControlAppearance.attributedTitle(
            titleOfSelectedItem ?? "",
            role: .primary,
            font: NSFont.systemFont(ofSize: 12, weight: .medium)
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        let controlRect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let background = NSColor(calibratedWhite: cell?.isHighlighted == true ? 0.25 : 0.30, alpha: 1)
        let surface = NSBezierPath(roundedRect: controlRect, xRadius: 5, yRadius: 5)
        background.setFill()
        surface.fill()
        ImageEditorTheme.border.setStroke()
        surface.lineWidth = 1
        surface.stroke()

        let title = displayedAttributedTitle
        let titleHeight = ceil(title.size().height)
        title.draw(
            in: NSRect(
                x: 9,
                y: max(0, (bounds.height - titleHeight) / 2),
                width: max(0, bounds.width - 34),
                height: titleHeight
            )
        )

        let arrowCenter = NSPoint(x: bounds.maxX - 13, y: bounds.midY)
        let chevron = NSBezierPath()
        chevron.move(to: NSPoint(x: arrowCenter.x - 3, y: arrowCenter.y + 1.5))
        chevron.line(to: NSPoint(x: arrowCenter.x, y: arrowCenter.y - 1.5))
        chevron.line(to: NSPoint(x: arrowCenter.x + 3, y: arrowCenter.y + 1.5))
        chevron.lineWidth = 1.25
        chevron.lineCapStyle = .round
        chevron.lineJoinStyle = .round
        ImageEditorTheme.mutedText.setStroke()
        chevron.stroke()
    }
}

struct ImageEditorDarkFilterPicker: NSViewRepresentable {
    @Binding var selection: ImageEditorFilter

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    func makeNSView(context: Context) -> ImageEditorFilterPopUpButton {
        let picker = ImageEditorFilterPopUpButton(frame: .zero, pullsDown: false)
        picker.target = context.coordinator
        picker.action = #selector(Coordinator.selectionChanged(_:))
        configure(picker, coordinator: context.coordinator)
        return picker
    }

    func updateNSView(_ picker: ImageEditorFilterPopUpButton, context: Context) {
        context.coordinator.selection = $selection
        configure(picker, coordinator: context.coordinator)
    }

    private func configure(_ picker: ImageEditorFilterPopUpButton, coordinator: Coordinator) {
        ImageEditorDarkPanelControlAppearance.configureFilterPicker(picker)
        picker.menu?.appearance = NSAppearance(named: .darkAqua)
        let filters = ImageEditorFilter.allCases
        if picker.numberOfItems != filters.count {
            picker.removeAllItems()
            filters.forEach { filter in
                let item = NSMenuItem(title: filter.title, action: nil, keyEquivalent: "")
                item.attributedTitle = ImageEditorDarkPanelControlAppearance.attributedTitle(
                    filter.title,
                    role: .primary,
                    font: NSFont.systemFont(ofSize: 12, weight: .medium)
                )
                picker.menu?.addItem(item)
            }
        }
        guard let index = filters.firstIndex(of: selection) else { return }
        picker.selectItem(at: index)
        picker.needsDisplay = true
        coordinator.filters = filters
    }

    final class Coordinator: NSObject {
        var selection: Binding<ImageEditorFilter>
        var filters = ImageEditorFilter.allCases

        init(selection: Binding<ImageEditorFilter>) {
            self.selection = selection
        }

        @objc func selectionChanged(_ sender: NSPopUpButton) {
            guard filters.indices.contains(sender.indexOfSelectedItem) else { return }
            selection.wrappedValue = filters[sender.indexOfSelectedItem]
            sender.needsDisplay = true
        }
    }
}

struct ImageEditorDarkSmartFilterBlendPicker: NSViewRepresentable {
    @Binding var selection: ImageEditorBlendMode

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    func makeNSView(context: Context) -> ImageEditorFilterPopUpButton {
        let picker = ImageEditorFilterPopUpButton(frame: .zero, pullsDown: false)
        picker.target = context.coordinator
        picker.action = #selector(Coordinator.selectionChanged(_:))
        configure(picker, coordinator: context.coordinator)
        return picker
    }

    func updateNSView(_ picker: ImageEditorFilterPopUpButton, context: Context) {
        context.coordinator.selection = $selection
        configure(picker, coordinator: context.coordinator)
    }

    private func configure(_ picker: ImageEditorFilterPopUpButton, coordinator: Coordinator) {
        ImageEditorDarkPanelControlAppearance.configureFilterPicker(picker)
        picker.identifier = NSUserInterfaceItemIdentifier("image-editor-smart-filter-blend-mode-picker")
        picker.setAccessibilityLabel(L10n.text("imageEditor.properties.smartFilterBlendMode"))
        picker.menu?.appearance = NSAppearance(named: .darkAqua)
        let blendModes = ImageEditorBlendMode.smartFilterCases
        if picker.numberOfItems != blendModes.count {
            picker.removeAllItems()
            blendModes.forEach { blendMode in
                let item = NSMenuItem(title: blendMode.title, action: nil, keyEquivalent: "")
                item.attributedTitle = ImageEditorDarkPanelControlAppearance.attributedTitle(
                    blendMode.title,
                    role: .primary,
                    font: NSFont.systemFont(ofSize: 12, weight: .medium)
                )
                picker.menu?.addItem(item)
            }
        }
        guard let index = blendModes.firstIndex(of: selection) else { return }
        picker.selectItem(at: index)
        picker.needsDisplay = true
        coordinator.blendModes = blendModes
    }

    final class Coordinator: NSObject {
        var selection: Binding<ImageEditorBlendMode>
        var blendModes = ImageEditorBlendMode.smartFilterCases

        init(selection: Binding<ImageEditorBlendMode>) {
            self.selection = selection
        }

        @objc func selectionChanged(_ sender: NSPopUpButton) {
            guard blendModes.indices.contains(sender.indexOfSelectedItem) else { return }
            selection.wrappedValue = blendModes[sender.indexOfSelectedItem]
            sender.needsDisplay = true
        }
    }
}
