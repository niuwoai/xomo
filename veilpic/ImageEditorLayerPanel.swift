//
//  ImageEditorLayerPanel.swift
//  veilpic
//
//  Created by Codex on 2026/7/9.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

private let imageEditorLayerRowDragStride: CGFloat = 66

enum ImageEditorLayerThumbnailSelectionSource: Equatable {
    case transparency
    case rasterMask
    case vectorMask
}

enum ImageEditorLayerThumbnailSelectionPolicy {
    static func mode(
        sidebarTab: XomoLeftSidebarTab,
        modifierFlags: NSEvent.ModifierFlags
    ) -> ImageEditorSelectionMode? {
        guard sidebarTab == .tools else { return nil }
        let relevantFlags = modifierFlags.intersection([.command, .shift, .option, .control])
        switch relevantFlags {
        case [.command]:
            return .replace
        case [.command, .shift]:
            return .add
        case [.command, .option]:
            return .subtract
        case [.command, .shift, .option]:
            return .intersect
        default:
            return nil
        }
    }

    static func togglesMaskEnabled(
        sidebarTab: XomoLeftSidebarTab,
        source: ImageEditorLayerThumbnailSelectionSource,
        modifierFlags: NSEvent.ModifierFlags
    ) -> Bool {
        guard sidebarTab == .tools,
              source != .transparency
        else { return false }
        let relevantFlags = modifierFlags.intersection([.command, .shift, .option, .control])
        return relevantFlags == [.shift]
    }

    static func previewsRasterMask(
        sidebarTab: XomoLeftSidebarTab,
        source: ImageEditorLayerThumbnailSelectionSource,
        modifierFlags: NSEvent.ModifierFlags
    ) -> Bool {
        guard sidebarTab == .tools,
              source == .rasterMask
        else { return false }
        let relevantFlags = modifierFlags.intersection([.command, .shift, .option, .control])
        return relevantFlags == [.option]
    }

    static func previewsRasterMaskAsRubylith(
        sidebarTab: XomoLeftSidebarTab,
        source: ImageEditorLayerThumbnailSelectionSource,
        modifierFlags: NSEvent.ModifierFlags
    ) -> Bool {
        guard sidebarTab == .tools,
              source == .rasterMask
        else { return false }
        let relevantFlags = modifierFlags.intersection([.command, .shift, .option, .control])
        return relevantFlags == [.shift, .option]
    }
}

enum ImageEditorLayerPanelTabAppearance {
    static let selectedForegroundColor = NSColor.white
    static let foregroundColor = NSColor(calibratedWhite: 0.88, alpha: 1)

    static func attributedTitle(_ title: String, isSelected: Bool) -> NSAttributedString {
        let color = isSelected ? selectedForegroundColor : foregroundColor
        let font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byClipping
        return NSAttributedString(
            string: title,
            attributes: [
                .foregroundColor: color,
                .font: font,
                .paragraphStyle: paragraphStyle
            ]
        )
    }
}

final class ImageEditorLayerPanelTabNativeLabel: NSView {
    var title = "" {
        didSet {
            invalidateIntrinsicContentSize()
            needsDisplay = true
        }
    }
    var isSelected = false {
        didSet { needsDisplay = true }
    }

    override var acceptsFirstResponder: Bool { false }

    override var intrinsicContentSize: NSSize {
        let size = attributedTitle.size()
        return NSSize(width: ceil(size.width), height: max(16, ceil(size.height)))
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let value = attributedTitle
        let size = value.size()
        value.draw(at: NSPoint(
            x: max(0, (bounds.width - size.width) / 2),
            y: max(0, (bounds.height - size.height) / 2)
        ))
    }

    var attributedTitle: NSAttributedString {
        ImageEditorLayerPanelTabAppearance.attributedTitle(title, isSelected: isSelected)
    }
}

enum ImageEditorLayerSearchAppearance {
    static let textColor = NSColor(calibratedWhite: 0.92, alpha: 1)
    static let placeholderColor = NSColor(calibratedWhite: 0.72, alpha: 1)

    static func configure(_ field: NSTextField, placeholder: String) {
        let font = NSFont.systemFont(ofSize: 11, weight: .medium)
        field.appearance = NSAppearance(named: .darkAqua)
        field.textColor = textColor
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
        field.identifier = NSUserInterfaceItemIdentifier("image-editor-layer-search-field")
    }
}

struct ImageEditorLayerSearchField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(string: text)
        field.delegate = context.coordinator
        ImageEditorLayerSearchAppearance.configure(field, placeholder: placeholder)
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.text = $text
        if field.stringValue != text {
            field.stringValue = text
        }
        ImageEditorLayerSearchAppearance.configure(field, placeholder: placeholder)
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

struct ImageEditorLayerPanelTabLabel: NSViewRepresentable {
    let title: String
    let isSelected: Bool

    func makeNSView(context: Context) -> ImageEditorLayerPanelTabNativeLabel {
        let label = ImageEditorLayerPanelTabNativeLabel()
        configure(label)
        return label
    }

    func updateNSView(_ label: ImageEditorLayerPanelTabNativeLabel, context: Context) {
        configure(label)
    }

    private func configure(_ label: ImageEditorLayerPanelTabNativeLabel) {
        label.appearance = NSAppearance(named: .darkAqua)
        label.identifier = NSUserInterfaceItemIdentifier("image-editor-layer-panel-native-tab-label")
        label.title = title
        label.isSelected = isSelected
    }
}

extension ImageEditorView {
    func layersPanel(showsTitle: Bool = true) -> some View {
        EditorPanel(title: L10n.text("imageEditor.panel.layersChannels"), showsTitle: showsTitle) {
            VStack(spacing: 8) {
                layerPanelTabs
                if selectedLayerPanelTab == .layers {
                    layerSearchField
                    layerActionToolbar
                    selectedLayerCountLabel
                    layerRows
                        .frame(minHeight: 150, maxHeight: .infinity)
                        .layoutPriority(1)
                    layerAdvancedControlsDisclosure
                } else {
                    ScrollView {
                        if selectedLayerPanelTab == .channels {
                            channelsPanelContent
                        } else if selectedLayerPanelTab == .paths {
                            savedPathsPanelContent
                        } else {
                            layerCompsPanelContent
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 420)
    }

    private var layerAdvancedControlsDisclosure: some View {
        VStack(spacing: 6) {
            Button {
                isLayerAdvancedControlsExpanded.toggle()
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 11, weight: .semibold))
                    Text(L10n.text("imageEditor.layer.advancedControls"))
                        .font(.system(size: 11, weight: .bold))
                    Spacer(minLength: 0)
                    Image(systemName: isLayerAdvancedControlsExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                .padding(.horizontal, 8)
                .frame(height: 28)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focusable(false)
            .accessibilityIdentifier("image-editor-layer-advanced-controls")
            .accessibilityValue(isLayerAdvancedControlsExpanded ? "expanded" : "collapsed")

            if isLayerAdvancedControlsExpanded {
                ScrollView {
                    VStack(spacing: 8) {
                        layerOpacityControls
                        layerMaskControls
                        layerKindFilterBar
                    }
                }
                .frame(maxHeight: 112)
            }
        }
        .background(Color(nsColor: ImageEditorTheme.panelRaised).opacity(0.38))
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private var layerPanelTabs: some View {
        HStack(spacing: 2) {
            ForEach(ImageEditorLayerPanelTab.allCases) { tab in
                Button {
                    selectedLayerPanelTab = tab
                } label: {
                    ImageEditorLayerPanelTabLabel(
                        title: tab.title,
                        isSelected: selectedLayerPanelTab == tab
                    )
                        .padding(.horizontal, 10)
                        .frame(height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .focusable(false)
                .xomoFocusEffectDisabled()
                .background(
                    selectedLayerPanelTab == tab
                        ? Color.accentColor.opacity(0.82)
                        : Color.white.opacity(0.07)
                )
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .accessibilityIdentifier("image-editor-layer-panel-tab-\(tab.rawValue)")
                .accessibilityAddTraits(selectedLayerPanelTab == tab ? .isSelected : [])
            }
        }
        .padding(2)
        .background(Color.black.opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var channelsPanelContent: some View {
        VStack(spacing: 8) {
            Text(L10n.format("imageEditor.channel.previewing", viewModel.channelPreviewTitle))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                viewModel.createBlankAlphaChannel()
            } label: {
                Label(L10n.text("imageEditor.action.alphaChannelBlank"), systemImage: "plus.square.dashed")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .disabled(!viewModel.canCreateBlankAlphaChannel)
            .help(L10n.text("imageEditor.action.alphaChannelBlank"))

            Button {
                viewModel.saveSelectionAsAlphaChannel()
            } label: {
                Label(L10n.text("imageEditor.action.channelSaveSelection"), systemImage: "plus.rectangle.on.rectangle")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .disabled(!viewModel.canSaveSelectionAsAlphaChannel)
            .help(L10n.text("imageEditor.action.channelSaveSelection"))

            Button {
                viewModel.saveSelectedLayerMaskAsAlphaChannel()
            } label: {
                Label(L10n.text("imageEditor.action.channelSaveLayerMask"), systemImage: "rectangle.badge.plus")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .disabled(!viewModel.canSaveSelectedLayerMaskAsAlphaChannel)
            .help(L10n.text("imageEditor.action.channelSaveLayerMask"))

            Button {
                viewModel.saveSelectedLayerTransparencyAsAlphaChannel()
            } label: {
                Label(L10n.text("imageEditor.action.channelSaveLayerTransparency"), systemImage: "circle.dashed.rectangle")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .disabled(!viewModel.canSaveSelectedLayerTransparencyAsAlphaChannel)
            .help(L10n.text("imageEditor.action.channelSaveLayerTransparency"))

            VStack(spacing: 5) {
                ForEach(ImageEditorChannelPreview.allCases) { channel in
                    channelRow(channel)
                }
            }

            if !viewModel.document.alphaChannels.isEmpty {
                Divider()
                    .overlay(Color.white.opacity(0.12))

                Text(L10n.text("imageEditor.channel.savedAlphaChannels"))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 5) {
                    ForEach(viewModel.document.alphaChannels) { channel in
                        alphaChannelRow(channel)
                    }
                }
            }

            Text(L10n.text("imageEditor.channel.previewHint"))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
    }

    private func channelRow(_ channel: ImageEditorChannelPreview) -> some View {
        let isSelected = viewModel.previewedLayerMask == nil
            && viewModel.previewedAlphaChannel == nil
            && viewModel.selectedChannelPreview == channel
        return HStack(spacing: 6) {
            Button {
                viewModel.selectChannelPreview(channel)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isSelected ? "eye.fill" : "eye")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 18)
                        .foregroundStyle(Color(nsColor: isSelected ? ImageEditorTheme.selected : ImageEditorTheme.mutedText))

                    Image(nsImage: viewModel.channelThumbnailImage(for: channel))
                        .resizable()
                        .scaledToFill()
                        .frame(width: 42, height: 28)
                        .clipped()
                        .background(Color.black.opacity(0.22))
                        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )

                    Label(channel.title, systemImage: channel.symbolName)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)

                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .help(L10n.format("imageEditor.action.channelPreview", channel.title))

            Button {
                viewModel.loadSelectionFromChannel(channel)
            } label: {
                Image(systemName: "circle.dashed")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 28)
            }
            .buttonStyle(EditorIconButtonStyle(isSelected: false))
            .help(L10n.format("imageEditor.action.channelLoadSelection", channel.title))

            Button {
                viewModel.saveChannelAsAlphaChannel(channel)
            } label: {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 28)
            }
            .buttonStyle(EditorIconButtonStyle(isSelected: false))
            .help(L10n.format("imageEditor.action.channelSaveAsAlpha", channel.title))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isSelected ? Color(nsColor: ImageEditorTheme.selected).opacity(0.28) : Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func alphaChannelRow(_ channel: ImageEditorAlphaChannel) -> some View {
        let isSelected = viewModel.selectedAlphaChannelID == channel.id
        return HStack(spacing: 6) {
            Button {
                viewModel.selectAlphaChannel(channel.id)
            } label: {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square.dashed")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 18)
                    .foregroundStyle(Color(nsColor: isSelected ? ImageEditorTheme.selected : ImageEditorTheme.mutedText))
            }
            .buttonStyle(.plain)
            .help(L10n.text("imageEditor.action.alphaChannelSelect"))

            Image(nsImage: viewModel.alphaChannelThumbnailImage(channel))
                .resizable()
                .scaledToFill()
                .frame(width: 42, height: 28)
                .clipped()
                .background(Color.black.opacity(0.22))
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )

            TextField(
                L10n.text("imageEditor.channel.alphaNamePlaceholder"),
                text: alphaChannelNameBinding(channel)
            )
            .textFieldStyle(.plain)
            .font(.system(size: 12, weight: .semibold))
            .lineLimit(1)
            .frame(minWidth: 0, maxWidth: .infinity)
            .onSubmit {
                commitAlphaChannelNameDraft(channel)
            }
            .onAppear {
                syncAlphaChannelNameDraft(channel)
            }
            .onChange(of: channel.name) { _ in
                syncAlphaChannelNameDraft(channel)
            }

            alphaChannelActionsMenu(channel)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isSelected ? Color(nsColor: ImageEditorTheme.selected).opacity(0.28) : Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func alphaChannelActionsMenu(_ channel: ImageEditorAlphaChannel) -> some View {
        Menu {
            alphaChannelMenuAction("imageEditor.action.alphaChannelLoadSelection", systemImage: "circle.dashed", channel: channel) {
                viewModel.loadSelectionFromAlphaChannel(channel.id)
            }
            alphaChannelMenuAction("imageEditor.action.alphaChannelUpdate", systemImage: "arrow.triangle.2.circlepath", channel: channel, isDisabled: !viewModel.canSaveSelectionAsAlphaChannel) {
                viewModel.updateAlphaChannelFromSelection(channel.id)
            }
            alphaChannelMenuAction("imageEditor.action.alphaChannelSelectionAdd", systemImage: "plus.square", channel: channel, isDisabled: !viewModel.canSaveSelectionAsAlphaChannel) {
                viewModel.addSelectionToAlphaChannel(channel.id)
            }
            alphaChannelMenuAction("imageEditor.action.alphaChannelSelectionSubtract", systemImage: "minus.square", channel: channel, isDisabled: !viewModel.canSaveSelectionAsAlphaChannel) {
                viewModel.subtractSelectionFromAlphaChannel(channel.id)
            }
            alphaChannelMenuAction("imageEditor.action.alphaChannelSelectionIntersect", systemImage: "square.grid.2x2", channel: channel, isDisabled: !viewModel.canSaveSelectionAsAlphaChannel) {
                viewModel.intersectSelectionWithAlphaChannel(channel.id)
            }

            Divider()

            alphaChannelMenuAction("imageEditor.action.alphaChannelApplyToMask", systemImage: "rectangle.badge.checkmark", channel: channel, isDisabled: !viewModel.canApplyAlphaChannelToSelectedLayerMask) {
                viewModel.applyAlphaChannelToSelectedLayerMask(channel.id)
            }
            alphaChannelMenuAction("imageEditor.action.alphaChannelLayer", systemImage: "square.stack.3d.up", channel: channel) {
                viewModel.createLayerFromAlphaChannel(channel.id)
            }
            alphaChannelMenuAction("imageEditor.action.alphaChannelDuplicate", systemImage: "doc.on.doc", channel: channel) {
                viewModel.duplicateAlphaChannel(channel.id)
            }
            alphaChannelMenuAction("imageEditor.action.alphaChannelInvert", systemImage: "circle.lefthalf.filled", channel: channel) {
                viewModel.invertAlphaChannel(channel.id)
            }
            alphaChannelMenuAction("imageEditor.action.alphaChannelFillWhite", systemImage: "square.fill", channel: channel) {
                viewModel.fillAlphaChannelWhite(channel.id)
            }
            alphaChannelMenuAction("imageEditor.action.alphaChannelClear", systemImage: "square", channel: channel) {
                viewModel.clearAlphaChannel(channel.id)
            }
            alphaChannelMenuAction("imageEditor.action.alphaChannelThreshold", systemImage: "circle.righthalf.filled", channel: channel) {
                viewModel.thresholdAlphaChannel(channel.id)
            }
            alphaChannelMenuAction("imageEditor.action.alphaChannelFeather", systemImage: "circle.dotted", channel: channel) {
                viewModel.featherAlphaChannel(channel.id)
            }
            alphaChannelMenuAction("imageEditor.action.alphaChannelExpand", systemImage: "arrow.up.left.and.arrow.down.right", channel: channel) {
                viewModel.expandAlphaChannel(channel.id)
            }
            alphaChannelMenuAction("imageEditor.action.alphaChannelContract", systemImage: "arrow.down.right.and.arrow.up.left", channel: channel) {
                viewModel.contractAlphaChannel(channel.id)
            }
            alphaChannelMenuAction("imageEditor.action.alphaChannelSmooth", systemImage: "sparkles", channel: channel) {
                viewModel.smoothAlphaChannel(channel.id)
            }
            alphaChannelMenuAction("imageEditor.action.alphaChannelFillHoles", systemImage: "circle.fill", channel: channel) {
                viewModel.fillHolesAlphaChannel(channel.id)
            }
            alphaChannelMenuAction("imageEditor.action.alphaChannelRemoveSpeckles", systemImage: "eraser", channel: channel) {
                viewModel.removeSpecklesAlphaChannel(channel.id)
            }

            Divider()

            alphaChannelMenuAction("imageEditor.action.alphaChannelFlipHorizontal", systemImage: "arrow.left.and.right", channel: channel) {
                viewModel.flipAlphaChannelHorizontal(channel.id)
            }
            alphaChannelMenuAction("imageEditor.action.alphaChannelFlipVertical", systemImage: "arrow.up.and.down", channel: channel) {
                viewModel.flipAlphaChannelVertical(channel.id)
            }
            alphaChannelMenuAction("imageEditor.action.alphaChannelRotateCounterclockwise", systemImage: "rotate.left", channel: channel) {
                viewModel.rotateAlphaChannelCounterclockwise(channel.id)
            }
            alphaChannelMenuAction("imageEditor.action.alphaChannelRotateClockwise", systemImage: "rotate.right", channel: channel) {
                viewModel.rotateAlphaChannelClockwise(channel.id)
            }
            alphaChannelMenuAction("imageEditor.action.alphaChannelRotate180", systemImage: "arrow.triangle.2.circlepath", channel: channel) {
                viewModel.rotateAlphaChannel180(channel.id)
            }
            alphaChannelMenuAction("imageEditor.action.alphaChannelScaleUp", systemImage: "plus.magnifyingglass", channel: channel) {
                viewModel.scaleAlphaChannelUp(channel.id)
            }
            alphaChannelMenuAction("imageEditor.action.alphaChannelScaleDown", systemImage: "minus.magnifyingglass", channel: channel) {
                viewModel.scaleAlphaChannelDown(channel.id)
            }
            alphaChannelMenuAction("imageEditor.action.alphaChannelFitCanvas", systemImage: "viewfinder", channel: channel) {
                viewModel.fitAlphaChannelToCanvas(channel.id)
            }
            alphaChannelMenuAction("imageEditor.action.alphaChannelMoveLeft", systemImage: "arrow.left", channel: channel) {
                viewModel.moveAlphaChannelLeft(channel.id)
            }
            alphaChannelMenuAction("imageEditor.action.alphaChannelMoveRight", systemImage: "arrow.right", channel: channel) {
                viewModel.moveAlphaChannelRight(channel.id)
            }
            alphaChannelMenuAction("imageEditor.action.alphaChannelMoveUp", systemImage: "arrow.up", channel: channel) {
                viewModel.moveAlphaChannelUp(channel.id)
            }
            alphaChannelMenuAction("imageEditor.action.alphaChannelMoveDown", systemImage: "arrow.down", channel: channel) {
                viewModel.moveAlphaChannelDown(channel.id)
            }

            Divider()

            alphaChannelMenuAction("imageEditor.action.alphaChannelDelete", systemImage: "trash", channel: channel) {
                viewModel.deleteAlphaChannel(channel.id)
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 28, height: 28)
        }
        .menuStyle(.borderlessButton)
        .help(L10n.format("imageEditor.action.alphaChannelMore", channel.name))
        .accessibilityLabel(L10n.format("imageEditor.action.alphaChannelMore", channel.name))
    }

    private func alphaChannelMenuAction(
        _ titleKey: String,
        systemImage: String,
        channel: ImageEditorAlphaChannel,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(L10n.format(titleKey, channel.name), systemImage: systemImage)
        }
        .disabled(isDisabled)
    }

    private func legacyAlphaChannelRow(_ channel: ImageEditorAlphaChannel) -> some View {
        let isSelected = viewModel.selectedAlphaChannelID == channel.id
        return HStack(spacing: 6) {
            Button {
                viewModel.selectAlphaChannel(channel.id)
            } label: {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square.dashed")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 18)
                    .foregroundStyle(Color(nsColor: isSelected ? ImageEditorTheme.selected : ImageEditorTheme.mutedText))
            }
            .buttonStyle(.plain)
            .help(L10n.text("imageEditor.action.alphaChannelSelect"))

            Image(nsImage: viewModel.alphaChannelPreviewImage(channel))
                .resizable()
                .scaledToFill()
                .frame(width: 42, height: 28)
                .clipped()
                .background(Color.black.opacity(0.22))
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )

            TextField(
                L10n.text("imageEditor.channel.alphaNamePlaceholder"),
                text: alphaChannelNameBinding(channel)
            )
            .textFieldStyle(.plain)
            .font(.system(size: 12, weight: .semibold))
            .lineLimit(1)
            .onSubmit {
                commitAlphaChannelNameDraft(channel)
            }
            .onAppear {
                syncAlphaChannelNameDraft(channel)
            }
            .onChange(of: channel.name) { _ in
                syncAlphaChannelNameDraft(channel)
            }

            Spacer()

            Button {
                viewModel.loadSelectionFromAlphaChannel(channel.id)
            } label: {
                Image(systemName: "circle.dashed")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 28)
            }
            .buttonStyle(EditorIconButtonStyle(isSelected: false))
            .help(L10n.format("imageEditor.action.alphaChannelLoadSelection", channel.name))

            Button {
                viewModel.updateAlphaChannelFromSelection(channel.id)
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 28)
            }
            .buttonStyle(EditorIconButtonStyle(isSelected: false))
            .disabled(!viewModel.canSaveSelectionAsAlphaChannel)
            .help(L10n.format("imageEditor.action.alphaChannelUpdate", channel.name))

            Button {
                viewModel.addSelectionToAlphaChannel(channel.id)
            } label: {
                Image(systemName: "plus.square")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 28)
            }
            .buttonStyle(EditorIconButtonStyle(isSelected: false))
            .disabled(!viewModel.canSaveSelectionAsAlphaChannel)
            .help(L10n.format("imageEditor.action.alphaChannelSelectionAdd", channel.name))

            Button {
                viewModel.subtractSelectionFromAlphaChannel(channel.id)
            } label: {
                Image(systemName: "minus.square")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 28)
            }
            .buttonStyle(EditorIconButtonStyle(isSelected: false))
            .disabled(!viewModel.canSaveSelectionAsAlphaChannel)
            .help(L10n.format("imageEditor.action.alphaChannelSelectionSubtract", channel.name))

            Button {
                viewModel.intersectSelectionWithAlphaChannel(channel.id)
            } label: {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 28)
            }
            .buttonStyle(EditorIconButtonStyle(isSelected: false))
            .disabled(!viewModel.canSaveSelectionAsAlphaChannel)
            .help(L10n.format("imageEditor.action.alphaChannelSelectionIntersect", channel.name))

            Button {
                viewModel.applyAlphaChannelToSelectedLayerMask(channel.id)
            } label: {
                Image(systemName: "rectangle.badge.checkmark")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 28)
            }
            .buttonStyle(EditorIconButtonStyle(isSelected: false))
            .disabled(!viewModel.canApplyAlphaChannelToSelectedLayerMask)
            .help(L10n.format("imageEditor.action.alphaChannelApplyToMask", channel.name))

            Button {
                viewModel.createLayerFromAlphaChannel(channel.id)
            } label: {
                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 28)
            }
            .buttonStyle(EditorIconButtonStyle(isSelected: false))
            .help(L10n.format("imageEditor.action.alphaChannelLayer", channel.name))

            Button {
                viewModel.duplicateAlphaChannel(channel.id)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 28)
            }
            .buttonStyle(EditorIconButtonStyle(isSelected: false))
            .help(L10n.format("imageEditor.action.alphaChannelDuplicate", channel.name))

            Button {
                viewModel.invertAlphaChannel(channel.id)
            } label: {
                Image(systemName: "circle.lefthalf.filled")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 28)
            }
            .buttonStyle(EditorIconButtonStyle(isSelected: false))
            .help(L10n.format("imageEditor.action.alphaChannelInvert", channel.name))

            Button {
                viewModel.fillAlphaChannelWhite(channel.id)
            } label: {
                Image(systemName: "square.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 28)
            }
            .buttonStyle(EditorIconButtonStyle(isSelected: false))
            .help(L10n.format("imageEditor.action.alphaChannelFillWhite", channel.name))

            Button {
                viewModel.clearAlphaChannel(channel.id)
            } label: {
                Image(systemName: "square")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 28)
            }
            .buttonStyle(EditorIconButtonStyle(isSelected: false))
            .help(L10n.format("imageEditor.action.alphaChannelClear", channel.name))

            Button {
                viewModel.thresholdAlphaChannel(channel.id)
            } label: {
                Image(systemName: "circle.righthalf.filled")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 28)
            }
            .buttonStyle(EditorIconButtonStyle(isSelected: false))
            .help(L10n.format("imageEditor.action.alphaChannelThreshold", channel.name))

            Button {
                viewModel.featherAlphaChannel(channel.id)
            } label: {
                Image(systemName: "circle.dotted")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 28)
            }
            .buttonStyle(EditorIconButtonStyle(isSelected: false))
            .help(L10n.format("imageEditor.action.alphaChannelFeather", channel.name))

            Button {
                viewModel.expandAlphaChannel(channel.id)
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 28)
            }
            .buttonStyle(EditorIconButtonStyle(isSelected: false))
            .help(L10n.format("imageEditor.action.alphaChannelExpand", channel.name))

            Button {
                viewModel.contractAlphaChannel(channel.id)
            } label: {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 28)
            }
            .buttonStyle(EditorIconButtonStyle(isSelected: false))
            .help(L10n.format("imageEditor.action.alphaChannelContract", channel.name))

            Button {
                viewModel.smoothAlphaChannel(channel.id)
            } label: {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 28)
            }
            .buttonStyle(EditorIconButtonStyle(isSelected: false))
            .help(L10n.format("imageEditor.action.alphaChannelSmooth", channel.name))

            Button {
                viewModel.fillHolesAlphaChannel(channel.id)
            } label: {
                Image(systemName: "circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 28)
            }
            .buttonStyle(EditorIconButtonStyle(isSelected: false))
            .help(L10n.format("imageEditor.action.alphaChannelFillHoles", channel.name))

            Button {
                viewModel.removeSpecklesAlphaChannel(channel.id)
            } label: {
                Image(systemName: "eraser")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 28)
            }
            .buttonStyle(EditorIconButtonStyle(isSelected: false))
            .help(L10n.format("imageEditor.action.alphaChannelRemoveSpeckles", channel.name))

            Button {
                viewModel.flipAlphaChannelHorizontal(channel.id)
            } label: {
                Image(systemName: "arrow.left.and.right")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 28)
            }
            .buttonStyle(EditorIconButtonStyle(isSelected: false))
            .help(L10n.format("imageEditor.action.alphaChannelFlipHorizontal", channel.name))

            Button {
                viewModel.flipAlphaChannelVertical(channel.id)
            } label: {
                Image(systemName: "arrow.up.and.down")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 28)
            }
            .buttonStyle(EditorIconButtonStyle(isSelected: false))
            .help(L10n.format("imageEditor.action.alphaChannelFlipVertical", channel.name))

            Button {
                viewModel.rotateAlphaChannelCounterclockwise(channel.id)
            } label: {
                Image(systemName: "rotate.left")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 28)
            }
            .buttonStyle(EditorIconButtonStyle(isSelected: false))
            .help(L10n.format("imageEditor.action.alphaChannelRotateCounterclockwise", channel.name))

            Button {
                viewModel.rotateAlphaChannelClockwise(channel.id)
            } label: {
                Image(systemName: "rotate.right")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 28)
            }
            .buttonStyle(EditorIconButtonStyle(isSelected: false))
            .help(L10n.format("imageEditor.action.alphaChannelRotateClockwise", channel.name))

            Button {
                viewModel.rotateAlphaChannel180(channel.id)
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 28)
            }
            .buttonStyle(EditorIconButtonStyle(isSelected: false))
            .help(L10n.format("imageEditor.action.alphaChannelRotate180", channel.name))

            Button {
                viewModel.scaleAlphaChannelUp(channel.id)
            } label: {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 28)
            }
            .buttonStyle(EditorIconButtonStyle(isSelected: false))
            .help(L10n.format("imageEditor.action.alphaChannelScaleUp", channel.name))

            Button {
                viewModel.scaleAlphaChannelDown(channel.id)
            } label: {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 28)
            }
            .buttonStyle(EditorIconButtonStyle(isSelected: false))
            .help(L10n.format("imageEditor.action.alphaChannelScaleDown", channel.name))

            Button {
                viewModel.fitAlphaChannelToCanvas(channel.id)
            } label: {
                Image(systemName: "viewfinder")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 28)
            }
            .buttonStyle(EditorIconButtonStyle(isSelected: false))
            .help(L10n.format("imageEditor.action.alphaChannelFitCanvas", channel.name))

            Button {
                viewModel.moveAlphaChannelLeft(channel.id)
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 28)
            }
            .buttonStyle(EditorIconButtonStyle(isSelected: false))
            .help(L10n.format("imageEditor.action.alphaChannelMoveLeft", channel.name))

            Button {
                viewModel.moveAlphaChannelRight(channel.id)
            } label: {
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 28)
            }
            .buttonStyle(EditorIconButtonStyle(isSelected: false))
            .help(L10n.format("imageEditor.action.alphaChannelMoveRight", channel.name))

            Button {
                viewModel.moveAlphaChannelUp(channel.id)
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 28)
            }
            .buttonStyle(EditorIconButtonStyle(isSelected: false))
            .help(L10n.format("imageEditor.action.alphaChannelMoveUp", channel.name))

            Button {
                viewModel.moveAlphaChannelDown(channel.id)
            } label: {
                Image(systemName: "arrow.down")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 28)
            }
            .buttonStyle(EditorIconButtonStyle(isSelected: false))
            .help(L10n.format("imageEditor.action.alphaChannelMoveDown", channel.name))

            Button {
                viewModel.deleteAlphaChannel(channel.id)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 28)
            }
            .buttonStyle(EditorIconButtonStyle(isSelected: false))
            .help(L10n.format("imageEditor.action.alphaChannelDelete", channel.name))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isSelected ? Color(nsColor: ImageEditorTheme.selected).opacity(0.28) : Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private func alphaChannelNameBinding(_ channel: ImageEditorAlphaChannel) -> Binding<String> {
        Binding {
            alphaChannelNameDrafts[channel.id] ?? channel.name
        } set: { value in
            alphaChannelNameDrafts[channel.id] = value
        }
    }

    private func syncAlphaChannelNameDraft(_ channel: ImageEditorAlphaChannel) {
        alphaChannelNameDrafts[channel.id] = channel.name
    }

    private func commitAlphaChannelNameDraft(_ channel: ImageEditorAlphaChannel) {
        viewModel.renameAlphaChannel(channel.id, to: alphaChannelNameDrafts[channel.id] ?? channel.name)
        if let updatedChannel = viewModel.document.alphaChannels.first(where: { $0.id == channel.id }) {
            syncAlphaChannelNameDraft(updatedChannel)
        }
    }

    private var layerCompsPanelContent: some View {
        VStack(spacing: 8) {
            Button {
                viewModel.addLayerComp()
            } label: {
                Label(L10n.text("imageEditor.action.layerCompNew"), systemImage: "rectangle.stack.badge.plus")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .help(L10n.text("imageEditor.action.layerCompNew"))

            if viewModel.document.layerComps.isEmpty {
                Text(L10n.text("imageEditor.layerComp.empty"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView {
                    VStack(spacing: 5) {
                        ForEach(viewModel.document.layerComps) { comp in
                            layerCompRow(comp)
                        }
                    }
                }
            }

            Text(L10n.text("imageEditor.layerComp.hint"))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func layerCompRow(_ comp: ImageEditorLayerComp) -> some View {
        let isSelected = viewModel.document.selectedLayerCompID == comp.id
        return HStack(spacing: 6) {
            Button {
                viewModel.selectLayerComp(comp.id)
            } label: {
                Image(systemName: isSelected ? "checkmark.rectangle.stack.fill" : "rectangle.stack")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 18)
                    .foregroundStyle(Color(nsColor: isSelected ? ImageEditorTheme.selected : ImageEditorTheme.mutedText))
            }
            .buttonStyle(.plain)
            .help(L10n.text("imageEditor.action.layerCompSelect"))

            VStack(alignment: .leading, spacing: 2) {
                TextField(
                    L10n.text("imageEditor.layerComp.namePlaceholder"),
                    text: layerCompNameBinding(comp)
                )
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                .lineLimit(1)
                .onSubmit {
                    commitLayerCompNameDraft(comp)
                }
                .onAppear {
                    syncLayerCompNameDraft(comp)
                }
                .onChange(of: comp.name) { _ in
                    syncLayerCompNameDraft(comp)
                }

                Text(viewModel.layerCompSummary(comp))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                    .lineLimit(1)
            }

            Spacer()

            layerCompIconButton("play.fill", "imageEditor.action.layerCompApply") {
                viewModel.applyLayerComp(comp.id)
            }
            layerCompIconButton("arrow.triangle.2.circlepath", "imageEditor.action.layerCompUpdate") {
                viewModel.updateLayerComp(comp.id)
            }
            layerCompIconButton("trash", "imageEditor.action.layerCompDelete") {
                viewModel.deleteLayerComp(comp.id)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isSelected ? Color(nsColor: ImageEditorTheme.selected).opacity(0.28) : Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private func layerCompIconButton(_ systemImage: String, _ helpKey: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 24, height: 28)
        }
        .buttonStyle(EditorIconButtonStyle(isSelected: false))
        .help(L10n.text(helpKey))
    }

    private func layerCompNameBinding(_ comp: ImageEditorLayerComp) -> Binding<String> {
        Binding {
            layerCompNameDrafts[comp.id] ?? comp.name
        } set: { value in
            layerCompNameDrafts[comp.id] = value
        }
    }

    private func syncLayerCompNameDraft(_ comp: ImageEditorLayerComp) {
        layerCompNameDrafts[comp.id] = comp.name
    }

    private func commitLayerCompNameDraft(_ comp: ImageEditorLayerComp) {
        viewModel.renameLayerComp(comp.id, to: layerCompNameDrafts[comp.id] ?? comp.name)
        if let updatedComp = viewModel.document.layerComps.first(where: { $0.id == comp.id }) {
            syncLayerCompNameDraft(updatedComp)
        }
    }

    private var savedPathsPanelContent: some View {
        VStack(spacing: 8) {
            Button {
                if let savedPath = viewModel.saveCurrentPath(name: nil) {
                    syncSavedPathNameDraft(savedPath)
                }
            } label: {
                Label(L10n.text("imageEditor.action.savedPathSave"), systemImage: "tray.and.arrow.down")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .focusable(false)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .disabled(!viewModel.canSaveCurrentPath)
            .help(L10n.text("imageEditor.action.savedPathSave"))

            if viewModel.document.savedPaths.isEmpty {
                Text(L10n.text("imageEditor.savedPath.empty"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView {
                    VStack(spacing: 5) {
                        ForEach(viewModel.document.savedPaths) { savedPath in
                            savedPathDraggableRow(savedPath)
                        }
                    }
                }
            }

            Text(L10n.text("imageEditor.savedPath.hint"))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                savedPathIconButton("circle.fill", "imageEditor.action.savedPathFill") {
                    guard let id = viewModel.document.selectedSavedPathID else { return }
                    viewModel.fillSavedPathToSelectedPixelLayer(id)
                }
                .disabled(!viewModel.canFillSelectedSavedPathToPixelLayer)
                savedPathIconButton("circle", "imageEditor.action.savedPathStroke") {
                    guard let id = viewModel.document.selectedSavedPathID else { return }
                    viewModel.strokeSavedPathToSelectedPixelLayer(id)
                }
                .disabled(!viewModel.canStrokeSelectedSavedPathToPixelLayer)
                savedPathIconButton("doc.on.doc", "imageEditor.action.savedPathCopy") {
                    guard let id = viewModel.document.selectedSavedPathID else { return }
                    viewModel.copySavedPath(id)
                }
                .disabled(viewModel.selectedSavedPath == nil)
                savedPathIconButton("plus.square.on.square", "imageEditor.action.savedPathDuplicate") {
                    guard let id = viewModel.document.selectedSavedPathID else { return }
                    if let savedPath = viewModel.duplicateSavedPath(id) {
                        syncSavedPathNameDraft(savedPath)
                    }
                }
                .disabled(!viewModel.canDuplicateSelectedSavedPath)
                savedPathIconButton("clipboard", "imageEditor.action.savedPathPaste") {
                    if let savedPath = viewModel.pasteSavedPath() {
                        syncSavedPathNameDraft(savedPath)
                    }
                }
                savedPathIconButton("arrow.up.to.line", "imageEditor.action.savedPathMoveToTop") {
                    guard let id = viewModel.document.selectedSavedPathID else { return }
                    viewModel.moveSavedPathToTop(id)
                }
                .disabled(!viewModel.canMoveSelectedSavedPathToTop)
                savedPathIconButton("arrow.up", "imageEditor.action.savedPathMoveUp") {
                    guard let id = viewModel.document.selectedSavedPathID else { return }
                    viewModel.moveSavedPathUp(id)
                }
                .disabled(!viewModel.canMoveSelectedSavedPathUp)
                savedPathIconButton("arrow.down", "imageEditor.action.savedPathMoveDown") {
                    guard let id = viewModel.document.selectedSavedPathID else { return }
                    viewModel.moveSavedPathDown(id)
                }
                .disabled(!viewModel.canMoveSelectedSavedPathDown)
                savedPathIconButton("arrow.down.to.line", "imageEditor.action.savedPathMoveToBottom") {
                    guard let id = viewModel.document.selectedSavedPathID else { return }
                    viewModel.moveSavedPathToBottom(id)
                }
                .disabled(!viewModel.canMoveSelectedSavedPathToBottom)
                Spacer(minLength: 0)
            }
        }
    }

    private func savedPathDraggableRow(_ savedPath: ImageEditorSavedPath) -> some View {
        VStack(spacing: 2) {
            savedPathDropBand(savedPath, placement: .above)
            savedPathRow(savedPath)
                .onDrag {
                    viewModel.selectSavedPath(savedPath.id)
                    syncSavedPathNameDraft(savedPath)
                    return NSItemProvider(object: savedPath.id.uuidString as NSString)
                }
                .help(L10n.text("imageEditor.action.savedPathDragReorder"))
            savedPathDropBand(savedPath, placement: .below)
        }
    }

    private func savedPathRow(_ savedPath: ImageEditorSavedPath) -> some View {
        let isSelected = viewModel.document.selectedSavedPathID == savedPath.id
        return HStack(spacing: 6) {
            savedPathIconButton(
                savedPath.isVisible ? "eye.fill" : "eye",
                "imageEditor.action.savedPathVisibility"
            ) {
                viewModel.setSavedPathVisibility(savedPath.id, isVisible: !savedPath.isVisible)
            }

            Button {
                viewModel.selectSavedPath(savedPath.id)
                syncSavedPathNameDraft(savedPath)
            } label: {
                Image(systemName: "vector.square")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 18)
                    .foregroundStyle(Color(nsColor: isSelected ? ImageEditorTheme.selected : ImageEditorTheme.mutedText))
            }
            .buttonStyle(.plain)
            .focusable(false)
            .help(L10n.text("imageEditor.action.savedPathSelect"))

            VStack(alignment: .leading, spacing: 2) {
                TextField(
                    L10n.text("imageEditor.savedPath.namePlaceholder"),
                    text: savedPathNameBinding(savedPath)
                )
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                .lineLimit(1)
                .onSubmit {
                    commitSavedPathNameDraft(savedPath)
                }
                .onAppear {
                    syncSavedPathNameDraft(savedPath)
                }
                .onChange(of: savedPath.name) { _ in
                    syncSavedPathNameDraft(savedPath)
                }

                Text(viewModel.savedPathSummary(savedPath))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                    .lineLimit(1)
            }

            Spacer()

            savedPathIconButton("circle.dashed", "imageEditor.action.savedPathSelection") {
                viewModel.selectSavedPath(savedPath.id)
                viewModel.loadSelectionFromSavedPath(savedPath.id)
            }
            .disabled(!savedPath.isClosed)
            savedPathIconButton("square.and.arrow.up", "imageEditor.action.savedPathLoad") {
                viewModel.loadSavedPath(savedPath.id)
            }
            savedPathIconButton("arrow.triangle.2.circlepath", "imageEditor.action.savedPathUpdate") {
                viewModel.updateSavedPath(savedPath.id)
            }
            .disabled(!viewModel.hasEditableCurrentPath)
            savedPathIconButton("trash", "imageEditor.action.savedPathDelete") {
                viewModel.deleteSavedPath(savedPath.id)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isSelected ? Color(nsColor: ImageEditorTheme.selected).opacity(0.28) : Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private func savedPathDropBand(
        _ savedPath: ImageEditorSavedPath,
        placement: ImageEditorSavedPathDropPlacement
    ) -> some View {
        let target = ImageEditorSavedPathDropTarget(
            savedPathID: savedPath.id,
            placement: placement
        )
        let isTargeted = targetedSavedPathDropTarget == target
        return Rectangle()
            .fill(isTargeted ? Color(nsColor: ImageEditorTheme.selected) : Color.clear)
            .frame(height: 6)
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            .onDrop(
                of: [UTType.plainText],
                delegate: ImageEditorSavedPathDropDelegate(
                    onTargetChange: { isTargeted in
                        targetedSavedPathDropTarget = isTargeted ? target : nil
                    },
                    onDrop: { sourceID in
                        _ = handleSavedPathDrop(sourceID, on: savedPath, placement: placement)
                    }
                )
            )
    }

    private func handleSavedPathDrop(
        _ sourceIDString: String,
        on targetPath: ImageEditorSavedPath,
        placement: ImageEditorSavedPathDropPlacement
    ) -> Bool {
        guard let sourceID = UUID(uuidString: sourceIDString),
              let sourceIndex = viewModel.document.savedPaths.firstIndex(where: { $0.id == sourceID }),
              let targetIndex = viewModel.document.savedPaths.firstIndex(where: { $0.id == targetPath.id }),
              let destinationIndex = ImageEditorSavedPathDropGeometry.destinationIndex(
                  sourceIndex: sourceIndex,
                  targetIndex: targetIndex,
                  placement: placement,
                  count: viewModel.document.savedPaths.count
              )
        else { return false }
        return viewModel.moveSavedPath(sourceID, toIndex: destinationIndex)
    }

    private func savedPathIconButton(
        _ systemImage: String,
        _ helpKey: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 24, height: 28)
        }
        .buttonStyle(EditorIconButtonStyle(isSelected: false))
        .focusable(false)
        .help(L10n.text(helpKey))
    }

    private func savedPathNameBinding(_ savedPath: ImageEditorSavedPath) -> Binding<String> {
        Binding {
            savedPathNameDrafts[savedPath.id] ?? savedPath.name
        } set: { value in
            savedPathNameDrafts[savedPath.id] = value
        }
    }

    private func syncSavedPathNameDraft(_ savedPath: ImageEditorSavedPath) {
        savedPathNameDrafts[savedPath.id] = savedPath.name
    }

    private func commitSavedPathNameDraft(_ savedPath: ImageEditorSavedPath) {
        viewModel.renameSavedPath(
            savedPath.id,
            to: savedPathNameDrafts[savedPath.id] ?? savedPath.name
        )
        if let updatedPath = viewModel.document.savedPaths.first(where: { $0.id == savedPath.id }) {
            syncSavedPathNameDraft(updatedPath)
        }
    }

    private var layerOpacityControls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Picker("", selection: selectedLayerBlendModeBinding) {
                    ForEach(viewModel.selectedLayerBlendModes) { blendMode in
                        Text(blendMode.title).tag(blendMode)
                    }
                }
                .labelsHidden()
                .frame(width: 136)

                Text(L10n.text("imageEditor.option.opacity"))
                Text("\(Int((viewModel.selectedLayerOpacity * 100).rounded()))%")
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
            }
            .font(.system(size: 11, weight: .medium))

            Slider(value: selectedLayerOpacityBinding, in: 0...1, step: 0.05) {
                Text(L10n.text("imageEditor.option.opacity"))
            } minimumValueLabel: {
                Text("0")
            } maximumValueLabel: {
                Text("100")
            } onEditingChanged: { editing in
                if editing {
                    viewModel.beginSelectedLayerOpacityChange()
                } else {
                    viewModel.commitSelectedLayerOpacityChange()
                }
            }
            .font(.system(size: 10, weight: .medium).monospacedDigit())

            HStack(spacing: 8) {
                Text(L10n.text("imageEditor.option.fillOpacity"))
                Text("\(Int((viewModel.selectedLayerFillOpacity * 100).rounded()))%")
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
            }
            .font(.system(size: 11, weight: .medium))
            .frame(maxWidth: .infinity, alignment: .leading)

            Slider(value: selectedLayerFillOpacityBinding, in: 0...1, step: 0.05) {
                Text(L10n.text("imageEditor.option.fillOpacity"))
            } minimumValueLabel: {
                Text("0")
            } maximumValueLabel: {
                Text("100")
            } onEditingChanged: { editing in
                if editing {
                    viewModel.beginSelectedLayerFillOpacityChange()
                } else {
                    viewModel.commitSelectedLayerFillOpacityChange()
                }
            }
            .disabled(!viewModel.canEditSelectedLayerFillOpacity)
            .font(.system(size: 10, weight: .medium).monospacedDigit())

            HStack(spacing: 8) {
                Text(L10n.text("imageEditor.option.blendIfSource"))
                Spacer()
                Text(L10n.format(
                    "imageEditor.option.blendIfSourceRange",
                    Int((viewModel.selectedLayerBlendIfSourceBlack * 255).rounded()),
                    Int((viewModel.selectedLayerBlendIfSourceWhite * 255).rounded())
                ))
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
            }
            .font(.system(size: 11, weight: .medium))

            Slider(value: selectedLayerBlendIfSourceBlackBinding, in: 0...1, step: 1 / 255) {
                Text(L10n.text("imageEditor.option.blendIfBlack"))
            } minimumValueLabel: {
                Text(L10n.text("imageEditor.option.blendIfBlackShort"))
            } maximumValueLabel: {
                Text("")
            } onEditingChanged: { editing in
                if editing {
                    viewModel.beginSelectedLayerBlendIfSourceBlackChange()
                } else {
                    viewModel.commitSelectedLayerBlendIfChange()
                }
            }
            .disabled(!viewModel.canEditSelectedLayerBlendIf)
            .font(.system(size: 10, weight: .medium).monospacedDigit())

            Slider(value: selectedLayerBlendIfSourceWhiteBinding, in: 0...1, step: 1 / 255) {
                Text(L10n.text("imageEditor.option.blendIfWhite"))
            } minimumValueLabel: {
                Text("")
            } maximumValueLabel: {
                Text(L10n.text("imageEditor.option.blendIfWhiteShort"))
            } onEditingChanged: { editing in
                if editing {
                    viewModel.beginSelectedLayerBlendIfSourceWhiteChange()
                } else {
                    viewModel.commitSelectedLayerBlendIfChange()
                }
            }
            .disabled(!viewModel.canEditSelectedLayerBlendIf)
            .font(.system(size: 10, weight: .medium).monospacedDigit())

            HStack(spacing: 8) {
                Text(L10n.text("imageEditor.option.blendIfUnderlying"))
                Spacer()
                Text(L10n.format(
                    "imageEditor.option.blendIfUnderlyingRange",
                    Int((viewModel.selectedLayerBlendIfUnderlyingBlack * 255).rounded()),
                    Int((viewModel.selectedLayerBlendIfUnderlyingWhite * 255).rounded())
                ))
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
            }
            .font(.system(size: 11, weight: .medium))

            Slider(value: selectedLayerBlendIfUnderlyingBlackBinding, in: 0...1, step: 1 / 255) {
                Text(L10n.text("imageEditor.option.blendIfUnderlyingBlack"))
            } minimumValueLabel: {
                Text(L10n.text("imageEditor.option.blendIfBlackShort"))
            } maximumValueLabel: {
                Text("")
            } onEditingChanged: { editing in
                if editing {
                    viewModel.beginSelectedLayerBlendIfUnderlyingBlackChange()
                } else {
                    viewModel.commitSelectedLayerBlendIfChange()
                }
            }
            .disabled(!viewModel.canEditSelectedLayerBlendIf)
            .font(.system(size: 10, weight: .medium).monospacedDigit())

            Slider(value: selectedLayerBlendIfUnderlyingWhiteBinding, in: 0...1, step: 1 / 255) {
                Text(L10n.text("imageEditor.option.blendIfUnderlyingWhite"))
            } minimumValueLabel: {
                Text("")
            } maximumValueLabel: {
                Text(L10n.text("imageEditor.option.blendIfWhiteShort"))
            } onEditingChanged: { editing in
                if editing {
                    viewModel.beginSelectedLayerBlendIfUnderlyingWhiteChange()
                } else {
                    viewModel.commitSelectedLayerBlendIfChange()
                }
            }
            .disabled(!viewModel.canEditSelectedLayerBlendIf)
            .font(.system(size: 10, weight: .medium).monospacedDigit())
        }
    }

    @ViewBuilder
    private var layerMaskControls: some View {
        if viewModel.selectedLayerHasMask {
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Text(L10n.text("imageEditor.option.maskDensity"))
                    Text("\(Int((viewModel.selectedLayerMaskDensity * 100).rounded()))%")
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                }
                .font(.system(size: 11, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading)

                Slider(value: selectedLayerMaskDensityBinding, in: 0...1, step: 0.05) {
                    Text(L10n.text("imageEditor.option.maskDensity"))
                } minimumValueLabel: {
                    Text("0")
                } maximumValueLabel: {
                    Text("100")
                } onEditingChanged: { editing in
                    if editing {
                        viewModel.beginSelectedLayerMaskDensityChange()
                    } else {
                        viewModel.commitSelectedLayerMaskDensityChange()
                    }
                }
                .disabled(!viewModel.canEditSelectedLayerMaskProperties)
                .font(.system(size: 10, weight: .medium).monospacedDigit())

                HStack(spacing: 8) {
                    Text(L10n.text("imageEditor.option.maskFeather"))
                    Text("\(Int(viewModel.selectedLayerMaskFeather.rounded())) px")
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                }
                .font(.system(size: 11, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading)

                Slider(value: selectedLayerMaskFeatherBinding, in: 0...80, step: 1) {
                    Text(L10n.text("imageEditor.option.maskFeather"))
                } minimumValueLabel: {
                    Text("0")
                } maximumValueLabel: {
                    Text("80")
                } onEditingChanged: { editing in
                    if editing {
                        viewModel.beginSelectedLayerMaskFeatherChange()
                    } else {
                        viewModel.commitSelectedLayerMaskFeatherChange()
                    }
                }
                .disabled(!viewModel.canEditSelectedLayerMaskProperties)
                .font(.system(size: 10, weight: .medium).monospacedDigit())
            }
        }
    }

    private var layerActionToolbar: some View {
        HStack(spacing: 6) {
            layerActionButton(systemImage: "plus", helpKey: "imageEditor.action.layerNew") { viewModel.addLayer() }
            layerActionButton(systemImage: "photo.badge.plus", helpKey: "imageEditor.action.layerImport") { viewModel.chooseImageLayerFile() }
            layerActionButton(systemImage: "folder.badge.plus", helpKey: "imageEditor.action.layerGroupNew") { viewModel.addLayerGroup() }
            layerActionButton(systemImage: "doc.on.doc", helpKey: "imageEditor.action.layerDuplicate") { viewModel.duplicateSelectedLayer() }
                .disabled(!viewModel.canDuplicateSelectedLayer)
            layerActionButton(systemImage: "arrow.up", helpKey: "imageEditor.action.layerUp") {
                viewModel.moveSelectedLayerUp(inVisibleOrder: filteredVisibleLayerRowIDs)
            }
            .disabled(!viewModel.canMoveSelectedLayerUp(inVisibleOrder: filteredVisibleLayerRowIDs))
            layerActionButton(systemImage: "arrow.down", helpKey: "imageEditor.action.layerDown") {
                viewModel.moveSelectedLayerDown(inVisibleOrder: filteredVisibleLayerRowIDs)
            }
            .disabled(!viewModel.canMoveSelectedLayerDown(inVisibleOrder: filteredVisibleLayerRowIDs))
            layerActionButton(systemImage: "circle.dashed", helpKey: "imageEditor.action.layerMaskAdd") { viewModel.addLayerMask() }
                .disabled(!viewModel.canAddLayerMask)
            layerActionButton(systemImage: "trash", helpKey: "imageEditor.action.layerDelete") { viewModel.deleteSelectedLayer() }
                .disabled(!viewModel.canDeleteLayer)
            layerMoreActionsMenu
        }
    }

    private var layerMoreActionsMenu: some View {
        Menu {
            Button(L10n.text("imageEditor.action.layerGroupSelected")) { viewModel.groupSelectedLayer() }
                .disabled(!viewModel.canGroupSelectedLayer)
            Button(L10n.text("imageEditor.action.layerUngroup")) { viewModel.ungroupSelectedLayers() }
                .disabled(!viewModel.canUngroupSelectedLayers)
            Button(L10n.text("imageEditor.action.layerGroupsExpandSelected")) {
                viewModel.expandSelectedLayerGroups()
            }
            .disabled(!viewModel.canExpandSelectedLayerGroups)
            Button(L10n.text("imageEditor.action.layerGroupsCollapseSelected")) {
                viewModel.collapseSelectedLayerGroups()
            }
            .disabled(!viewModel.canCollapseSelectedLayerGroups)
            Divider()
            Button(L10n.text("imageEditor.action.layerSmartObject")) { viewModel.convertSelectedLayerToSmartObject() }
                .disabled(!viewModel.canConvertSelectedLayerToSmartObject)
            Button(L10n.text("imageEditor.action.layerSmartObjectViaCopy")) {
                viewModel.createSmartObjectViaCopy()
            }
            .disabled(!viewModel.canCreateSmartObjectViaCopy)
            Button(L10n.text("imageEditor.action.layerSmartObjectReplace")) {
                viewModel.chooseSmartObjectReplacementFile()
            }
            .disabled(!viewModel.canReplaceSelectedSmartObjectContents)
            Button(L10n.text("imageEditor.action.smartObjectSourcePNGExport")) {
                viewModel.chooseSmartObjectSourcePNGDestination()
            }
            .disabled(!viewModel.canExportSelectedSmartObjectSourcePNG)
            Button(L10n.text("imageEditor.action.layerSmartObjectMakeUnique")) {
                viewModel.makeSelectedSmartObjectUnique()
            }
            .disabled(!viewModel.canMakeSelectedSmartObjectUnique)
            Button(L10n.text("imageEditor.action.layerSmartObjectResetTransform")) {
                viewModel.resetSelectedSmartObjectTransform()
            }
            .disabled(!viewModel.canResetSelectedSmartObjectTransform)
            Menu(L10n.text("imageEditor.action.layerRasterize")) {
                ForEach(ImageEditorRasterizeTarget.allCases) { target in
                    Button(L10n.text(target.actionTitleKey)) {
                        viewModel.rasterizeSelectedLayers(target)
                    }
                    .disabled(!viewModel.canRasterizeSelectedLayers(target))
                }
            }
            Button(
                L10n.text(
                    viewModel.selectedLayerEffectsAreVisible
                        ? "imageEditor.action.layerEffectsHideSelected"
                        : "imageEditor.action.layerEffectsShowSelected"
                )
            ) {
                viewModel.toggleSelectedLayerEffects()
            }
            .disabled(!viewModel.canToggleSelectedLayerEffects)
            Button(L10n.text("imageEditor.action.layerEffectsScale")) {
                viewModel.showLayerEffectScaleOptions()
            }
            .disabled(!viewModel.canScaleSelectedLayerEffects)
            Divider()
            Button(L10n.text(viewModel.mergeDownActionTitleKey)) { viewModel.mergeSelectedLayerDown() }
                .disabled(!viewModel.canMergeSelectedLayerDown)
            Button(L10n.text("imageEditor.action.layerMergeSelected")) { viewModel.mergeSelectedLayers() }
                .disabled(!viewModel.canMergeSelectedLayers)
            Button(L10n.text("imageEditor.action.layerFlatten")) { viewModel.flattenImage() }
                .disabled(!viewModel.canFlattenImage)
            Divider()
            layerLabelColorMenu
            Button(L10n.text("imageEditor.action.layerMoreOpenMenu")) {
                viewModel.statusText = L10n.text("imageEditor.status.layerMoreOpenMenu")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .bold))
                .frame(width: 24, height: 24)
        }
        .buttonStyle(EditorIconButtonStyle(isSelected: false))
        .help(L10n.text("imageEditor.action.layerMore"))
        .accessibilityIdentifier("image-editor-layer-more-actions")
    }

    private var layerAlignmentButtons: some View {
        Group {
            layerActionButton(systemImage: "align.horizontal.left", helpKey: "imageEditor.action.layerAlignLeft") { viewModel.alignSelectedLayers(.left) }
                .disabled(!viewModel.canAlignSelectedLayers)
            layerActionButton(systemImage: "align.horizontal.center", helpKey: "imageEditor.action.layerAlignHorizontalCenter") { viewModel.alignSelectedLayers(.horizontalCenter) }
                .disabled(!viewModel.canAlignSelectedLayers)
            layerActionButton(systemImage: "align.horizontal.right", helpKey: "imageEditor.action.layerAlignRight") { viewModel.alignSelectedLayers(.right) }
                .disabled(!viewModel.canAlignSelectedLayers)
            layerActionButton(systemImage: "align.vertical.top", helpKey: "imageEditor.action.layerAlignTop") { viewModel.alignSelectedLayers(.top) }
                .disabled(!viewModel.canAlignSelectedLayers)
            layerActionButton(systemImage: "align.vertical.center", helpKey: "imageEditor.action.layerAlignVerticalCenter") { viewModel.alignSelectedLayers(.verticalCenter) }
                .disabled(!viewModel.canAlignSelectedLayers)
            layerActionButton(systemImage: "align.vertical.bottom", helpKey: "imageEditor.action.layerAlignBottom") { viewModel.alignSelectedLayers(.bottom) }
                .disabled(!viewModel.canAlignSelectedLayers)
            layerActionButton(systemImage: "rectangle.leadinghalf.filled", helpKey: "imageEditor.action.layerAlignCanvasLeft") { viewModel.alignSelectedLayersToCanvas(.left) }
                .disabled(!viewModel.canAlignSelectedLayersToCanvas)
            layerActionButton(systemImage: "rectangle.center.inset.filled", helpKey: "imageEditor.action.layerAlignCanvasHorizontalCenter") { viewModel.alignSelectedLayersToCanvas(.horizontalCenter) }
                .disabled(!viewModel.canAlignSelectedLayersToCanvas)
            layerActionButton(systemImage: "rectangle.trailinghalf.filled", helpKey: "imageEditor.action.layerAlignCanvasRight") { viewModel.alignSelectedLayersToCanvas(.right) }
                .disabled(!viewModel.canAlignSelectedLayersToCanvas)
            layerActionButton(systemImage: "rectangle.tophalf.filled", helpKey: "imageEditor.action.layerAlignCanvasTop") { viewModel.alignSelectedLayersToCanvas(.top) }
                .disabled(!viewModel.canAlignSelectedLayersToCanvas)
            layerActionButton(systemImage: "rectangle.center.inset.filled", helpKey: "imageEditor.action.layerAlignCanvasVerticalCenter") { viewModel.alignSelectedLayersToCanvas(.verticalCenter) }
                .disabled(!viewModel.canAlignSelectedLayersToCanvas)
            layerActionButton(systemImage: "rectangle.bottomhalf.filled", helpKey: "imageEditor.action.layerAlignCanvasBottom") { viewModel.alignSelectedLayersToCanvas(.bottom) }
                .disabled(!viewModel.canAlignSelectedLayersToCanvas)
            layerActionButton(systemImage: "rectangle.dashed", helpKey: "imageEditor.action.layerAlignSelectionLeft") { viewModel.alignSelectedLayersToSelection(.left) }
                .disabled(!viewModel.canAlignSelectedLayersToSelection)
            layerActionButton(systemImage: "rectangle.dashed", helpKey: "imageEditor.action.layerAlignSelectionHorizontalCenter") { viewModel.alignSelectedLayersToSelection(.horizontalCenter) }
                .disabled(!viewModel.canAlignSelectedLayersToSelection)
            layerActionButton(systemImage: "rectangle.dashed", helpKey: "imageEditor.action.layerAlignSelectionRight") { viewModel.alignSelectedLayersToSelection(.right) }
                .disabled(!viewModel.canAlignSelectedLayersToSelection)
            layerActionButton(systemImage: "rectangle.dashed", helpKey: "imageEditor.action.layerAlignSelectionTop") { viewModel.alignSelectedLayersToSelection(.top) }
                .disabled(!viewModel.canAlignSelectedLayersToSelection)
            layerActionButton(systemImage: "rectangle.dashed", helpKey: "imageEditor.action.layerAlignSelectionVerticalCenter") { viewModel.alignSelectedLayersToSelection(.verticalCenter) }
                .disabled(!viewModel.canAlignSelectedLayersToSelection)
            layerActionButton(systemImage: "rectangle.dashed", helpKey: "imageEditor.action.layerAlignSelectionBottom") { viewModel.alignSelectedLayersToSelection(.bottom) }
                .disabled(!viewModel.canAlignSelectedLayersToSelection)
            layerActionButton(systemImage: "distribute.horizontal.left", helpKey: "imageEditor.action.layerDistributeLeft") { viewModel.distributeSelectedLayers(.left) }
                .disabled(!viewModel.canDistributeSelectedLayers)
            layerActionButton(systemImage: "arrow.left.and.right", helpKey: "imageEditor.action.layerDistributeHorizontalCenter") { viewModel.distributeSelectedLayers(.horizontalCenter) }
                .disabled(!viewModel.canDistributeSelectedLayers)
            layerActionButton(systemImage: "distribute.horizontal.right", helpKey: "imageEditor.action.layerDistributeRight") { viewModel.distributeSelectedLayers(.right) }
                .disabled(!viewModel.canDistributeSelectedLayers)
            layerActionButton(systemImage: "distribute.vertical.top", helpKey: "imageEditor.action.layerDistributeTop") { viewModel.distributeSelectedLayers(.top) }
                .disabled(!viewModel.canDistributeSelectedLayers)
            layerActionButton(systemImage: "arrow.up.and.down", helpKey: "imageEditor.action.layerDistributeVerticalCenter") { viewModel.distributeSelectedLayers(.verticalCenter) }
                .disabled(!viewModel.canDistributeSelectedLayers)
            layerActionButton(systemImage: "distribute.vertical.bottom", helpKey: "imageEditor.action.layerDistributeBottom") { viewModel.distributeSelectedLayers(.bottom) }
                .disabled(!viewModel.canDistributeSelectedLayers)
            layerActionButton(systemImage: "rectangle.split.3x1", helpKey: "imageEditor.action.layerDistributeHorizontalSpacing") { viewModel.distributeSelectedLayerSpacing(.horizontal) }
                .disabled(!viewModel.canDistributeSelectedLayers)
            layerActionButton(systemImage: "rectangle.split.1x3", helpKey: "imageEditor.action.layerDistributeVerticalSpacing") { viewModel.distributeSelectedLayerSpacing(.vertical) }
                .disabled(!viewModel.canDistributeSelectedLayers)
        }
    }

    private var layerOrderingButtons: some View {
        Group {
            layerActionButton(systemImage: "trash", helpKey: "imageEditor.action.layerDelete") { viewModel.deleteSelectedLayer() }
                .disabled(!viewModel.canDeleteLayer)
            layerActionButton(systemImage: "eye", helpKey: "imageEditor.action.layerShowSelected") { viewModel.showSelectedLayers() }
                .disabled(!viewModel.canShowSelectedLayers)
            layerActionButton(systemImage: "eye.slash", helpKey: "imageEditor.action.layerHideSelected") { viewModel.hideSelectedLayers() }
                .disabled(!viewModel.canHideSelectedLayers)
            layerActionButton(systemImage: "arrow.up.to.line", helpKey: "imageEditor.action.layerTop") {
                viewModel.moveSelectedLayerToTop(inVisibleOrder: filteredVisibleLayerRowIDs)
            }
            .disabled(!viewModel.canMoveSelectedLayerToTop(inVisibleOrder: filteredVisibleLayerRowIDs))
            layerActionButton(systemImage: "arrow.up", helpKey: "imageEditor.action.layerUp") {
                viewModel.moveSelectedLayerUp(inVisibleOrder: filteredVisibleLayerRowIDs)
            }
            .disabled(!viewModel.canMoveSelectedLayerUp(inVisibleOrder: filteredVisibleLayerRowIDs))
            layerActionButton(systemImage: "arrow.down", helpKey: "imageEditor.action.layerDown") {
                viewModel.moveSelectedLayerDown(inVisibleOrder: filteredVisibleLayerRowIDs)
            }
            .disabled(!viewModel.canMoveSelectedLayerDown(inVisibleOrder: filteredVisibleLayerRowIDs))
            layerActionButton(systemImage: "arrow.down.to.line", helpKey: "imageEditor.action.layerBottom") {
                viewModel.moveSelectedLayerToBottom(inVisibleOrder: filteredVisibleLayerRowIDs)
            }
            .disabled(!viewModel.canMoveSelectedLayerToBottom(inVisibleOrder: filteredVisibleLayerRowIDs))
            layerActionButton(systemImage: "square.stack.3d.down.right", helpKey: viewModel.mergeDownActionTitleKey) { viewModel.mergeSelectedLayerDown() }
                .disabled(!viewModel.canMergeSelectedLayerDown)
            layerActionButton(systemImage: "square.stack.3d.down.right.fill", helpKey: "imageEditor.action.layerMergeSelected") { viewModel.mergeSelectedLayers() }
                .disabled(!viewModel.canMergeSelectedLayers)
            layerActionButton(systemImage: "square.stack.3d.down.right.fill", helpKey: "imageEditor.action.layerMergeVisible") { viewModel.mergeVisibleLayers() }
                .disabled(!viewModel.canMergeVisibleLayers)
            layerActionButton(systemImage: "square.stack.3d.up.fill", helpKey: "imageEditor.action.layerStampVisible") { viewModel.stampVisibleLayers() }
                .disabled(!viewModel.canStampVisibleLayers)
            layerActionButton(systemImage: "square.stack.3d.up", helpKey: "imageEditor.action.layerStampSelected") { viewModel.stampSelectedLayers() }
                .disabled(!viewModel.canStampSelectedLayers)
            layerActionButton(systemImage: "rectangle.fill", helpKey: "imageEditor.action.layerFlatten") { viewModel.flattenImage() }
                .disabled(!viewModel.canFlattenImage)
        }
    }

    private var layerLabelColorMenu: some View {
        Menu {
            Button {
                viewModel.setSelectedLayersLabelColor(nil)
            } label: {
                Label(L10n.text("imageEditor.action.layerLabelNone"), systemImage: "tag.slash")
            }

            Divider()

            ForEach(ImageEditorLayerLabelColor.allCases) { labelColor in
                Button {
                    viewModel.setSelectedLayersLabelColor(labelColor)
                } label: {
                    Label(labelColor.title, systemImage: "tag.fill")
                }
            }
        } label: {
            Image(systemName: "tag")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 24, height: 24)
        }
        .buttonStyle(EditorIconButtonStyle(isSelected: viewModel.document.selectedLayer?.labelColor != nil))
        .disabled(!viewModel.canSetSelectedLayerLabelColor)
        .help(L10n.text("imageEditor.action.layerLabelColor"))
    }

    private var layerMaskActionButtons: some View {
        Group {
            layerActionButton(systemImage: "circle.dashed", helpKey: "imageEditor.action.layerMaskAdd") { viewModel.addLayerMask() }
                .disabled(!viewModel.canAddLayerMask)
            layerActionButton(systemImage: "circle.fill", helpKey: "imageEditor.action.layerMaskHideAll") { viewModel.addLayerMaskHidingAll() }
                .disabled(!viewModel.canAddLayerMask)
            layerActionButton(systemImage: "circle.lefthalf.filled", helpKey: "imageEditor.action.layerMaskFromSelection") { viewModel.addLayerMaskFromSelection() }
                .disabled(!viewModel.canCreateLayerMaskFromSelection)
            layerActionButton(systemImage: "point.topleft.down.curvedto.point.bottomright.up", helpKey: "imageEditor.action.vectorMaskFromSelection") { viewModel.addVectorMaskFromSelection() }
                .disabled(!viewModel.canCreateVectorMaskFromSelection)
            layerActionButton(systemImage: "circle.dashed.inset.filled", helpKey: "imageEditor.action.layerMaskHideSelection") { viewModel.addLayerMaskHidingSelection() }
                .disabled(!viewModel.canCreateLayerMaskFromSelection)
            layerActionButton(systemImage: "paintbrush", helpKey: "imageEditor.action.layerMaskEdit") { viewModel.editLayerMask() }
                .disabled(!viewModel.selectedLayerHasMask)
            layerActionButton(systemImage: "circle.slash", helpKey: "imageEditor.action.layerMaskToggle", isSelected: viewModel.document.selectedLayer?.isMaskEnabled == false) {
                viewModel.toggleLayerMaskEnabled()
            }
            .disabled(!viewModel.canToggleLayerMaskEnabled)
            layerActionButton(
                systemImage: viewModel.document.selectedLayer?.isMaskLinked == false ? "link.slash" : "link",
                helpKey: "imageEditor.action.layerMaskLinkToggle",
                isSelected: viewModel.document.selectedLayer?.isMaskLinked == false
            ) {
                viewModel.toggleLayerMaskLinked()
            }
            .disabled(!viewModel.canToggleLayerMaskLinked)
            layerActionButton(systemImage: "arrow.triangle.2.circlepath", helpKey: "imageEditor.action.layerMaskInvert") { viewModel.invertLayerMask() }
                .disabled(!viewModel.canInvertLayerMask)
            layerActionButton(systemImage: "rectangle.dashed", helpKey: "imageEditor.action.layerMaskLoadSelection") { viewModel.loadSelectionFromLayerMask() }
                .disabled(!viewModel.canLoadSelectionFromLayerMask)
            layerActionButton(systemImage: "square.dashed", helpKey: "imageEditor.action.layerTransparencyLoadSelection") { viewModel.loadSelectionFromLayerTransparency() }
                .disabled(!viewModel.canLoadSelectionFromLayerTransparency)
            layerActionButton(systemImage: "checkmark.square", helpKey: "imageEditor.action.layerMaskApply") { viewModel.applyLayerMask() }
                .disabled(!viewModel.canApplyLayerMask)
            layerActionButton(systemImage: "xmark.square", helpKey: "imageEditor.action.layerMaskDelete") { viewModel.deleteLayerMask() }
                .disabled(!viewModel.canDeleteLayerMask)
            layerActionButton(systemImage: "pencil.and.outline", helpKey: "imageEditor.action.vectorMaskEditPath") { viewModel.editSelectedVectorMaskAsPath() }
                .disabled(!viewModel.canEditSelectedVectorMaskAsPath)
            layerActionButton(systemImage: "rectangle.dashed", helpKey: "imageEditor.action.vectorMaskLoadSelection") { viewModel.loadSelectionFromVectorMask() }
                .disabled(!viewModel.canLoadSelectionFromVectorMask)
            layerActionButton(systemImage: "point.topleft.down.curvedto.point.bottomright.up", helpKey: "imageEditor.action.vectorMaskToggle", isSelected: viewModel.document.selectedLayer?.isVectorMaskEnabled == false) {
                viewModel.toggleVectorMaskEnabled()
            }
            .disabled(!viewModel.canToggleVectorMaskEnabled)
            layerActionButton(systemImage: "checkmark.square.fill", helpKey: "imageEditor.action.vectorMaskApply") { viewModel.applyVectorMask() }
                .disabled(!viewModel.canApplyVectorMask)
            layerActionButton(systemImage: "square.grid.3x3", helpKey: "imageEditor.action.vectorMaskRasterize") { viewModel.rasterizeSelectedVectorMask() }
                .disabled(!viewModel.canRasterizeSelectedVectorMask)
            layerActionButton(systemImage: "xmark.square.fill", helpKey: "imageEditor.action.vectorMaskDelete") { viewModel.deleteVectorMask() }
                .disabled(!viewModel.canDeleteVectorMask)
        }
    }

    private var layerEffectButtons: some View {
        Group {
            layerStyleEffectButton(.stroke, systemImage: "f.cursive", helpKey: "imageEditor.action.layerStroke") { viewModel.toggleSelectedLayerStroke() }
            layerStyleEffectButton(.shadow, systemImage: "sparkles", helpKey: "imageEditor.action.layerShadow") { viewModel.toggleSelectedLayerShadow() }
            layerStyleEffectButton(.innerShadow, systemImage: "circle.righthalf.filled", helpKey: "imageEditor.action.layerInnerShadow") { viewModel.toggleSelectedLayerInnerShadow() }
            layerStyleEffectButton(.outerGlow, systemImage: "sun.max", helpKey: "imageEditor.action.layerOuterGlow") { viewModel.toggleSelectedLayerOuterGlow() }
            layerStyleEffectButton(.innerGlow, systemImage: "circle.circle", helpKey: "imageEditor.action.layerInnerGlow") { viewModel.toggleSelectedLayerInnerGlow() }
            layerStyleEffectButton(.colorOverlay, systemImage: "circle.lefthalf.filled", helpKey: "imageEditor.action.layerColorOverlay") { viewModel.toggleSelectedLayerColorOverlay() }
            layerStyleEffectButton(.gradientOverlay, systemImage: "square.lefthalf.filled", helpKey: "imageEditor.action.layerGradientOverlay") { viewModel.toggleSelectedLayerGradientOverlay() }
            layerStyleEffectButton(.patternOverlay, systemImage: "checkerboard.rectangle", helpKey: "imageEditor.action.layerPatternOverlay") { viewModel.toggleSelectedLayerPatternOverlay() }
            layerStyleEffectButton(.satin, systemImage: "circle.dotted", helpKey: "imageEditor.action.layerSatin") { viewModel.toggleSelectedLayerSatin() }
            layerStyleEffectButton(.bevel, systemImage: "cube.transparent", helpKey: "imageEditor.action.layerBevel") { viewModel.toggleSelectedLayerBevel() }
            layerClippingMaskBatchButton
        }
    }

    private func layerStyleEffectButton(
        _ effect: ImageEditorLayerStyleEffect,
        systemImage: String,
        helpKey: String,
        action: @escaping () -> Void
    ) -> some View {
        let state = viewModel.selectedLayerStyleEffectState(effect)
        return layerActionButton(
            systemImage: systemImage,
            helpKey: helpKey,
            isSelected: state != .off,
            action: action
        )
        .overlay(alignment: .bottomTrailing) {
            if state == .mixed {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                    .offset(x: 2, y: 2)
                    .allowsHitTesting(false)
            }
        }
        .disabled(!viewModel.canEditSelectedLayerStyle)
        .focusable(false)
        .accessibilityValue(L10n.text(state.accessibilityKey))
        .accessibilityIdentifier("image-editor-layer-style-effect-\(effect)")
    }

    private var layerClippingMaskBatchButton: some View {
        let state = viewModel.selectedLayersClippingMaskState
        return layerActionButton(
            systemImage: "arrow.down.to.line.compact",
            helpKey: "imageEditor.action.layerClippingMask",
            isSelected: state != .off
        ) {
            viewModel.toggleClippingMasksForSelectedLayers()
        }
        .overlay(alignment: .bottomTrailing) {
            if state == .mixed {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                    .offset(x: 2, y: 2)
                    .allowsHitTesting(false)
            }
        }
        .disabled(!viewModel.canToggleClippingMasksForSelectedLayers)
        .accessibilityValue(L10n.text(state.accessibilityKey))
        .accessibilityIdentifier("image-editor-layer-clipping-mask-batch")
    }

    @ViewBuilder
    private var selectedLayerCountLabel: some View {
        if viewModel.selectedLayerCount > 1 {
            Text(L10n.format("imageEditor.layer.selectionCount", viewModel.selectedLayerCount))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    var filteredVisibleLayerRows: [ImageEditorLayer] {
        viewModel.visibleLayerRows(
            matching: layerSearchQuery,
            kindFilter: selectedLayerKindFilter,
            labelFilter: selectedLayerLabelFilter,
            stateFilter: selectedLayerStateFilter,
            attributeFilter: selectedLayerAttributeFilter
        )
    }

    var filteredVisibleLayerRowIDs: [UUID] {
        filteredVisibleLayerRows.map(\.id)
    }

    private var layerSearchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))

            ImageEditorLayerSearchField(
                placeholder: L10n.text("imageEditor.layer.searchPlaceholder"),
                text: $layerSearchQuery
            )
            .frame(minHeight: 16)

            if !layerSearchQuery.isEmpty {
                Button {
                    layerSearchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .help(L10n.text("imageEditor.action.layerSearchClear"))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var layerKindFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(ImageEditorLayerKindFilter.allCases) { filter in
                    Button {
                        selectedLayerKindFilter = filter
                    } label: {
                        Image(systemName: filter.symbolName)
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(EditorIconButtonStyle(isSelected: selectedLayerKindFilter == filter))
                    .help(filter.title)
                }
                Divider()
                    .frame(height: 18)
                    .overlay(Color.white.opacity(0.12))
                ForEach(ImageEditorLayerStateFilter.allCases) { filter in
                    Button {
                        selectedLayerStateFilter = filter
                    } label: {
                        Image(systemName: filter.symbolName)
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(EditorIconButtonStyle(isSelected: selectedLayerStateFilter == filter))
                    .help(filter.title)
                }
                Divider()
                    .frame(height: 18)
                    .overlay(Color.white.opacity(0.12))
                ForEach(ImageEditorLayerAttributeFilter.allCases) { filter in
                    Button {
                        selectedLayerAttributeFilter = filter
                    } label: {
                        Image(systemName: filter.symbolName)
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(EditorIconButtonStyle(isSelected: selectedLayerAttributeFilter == filter))
                    .help(filter.title)
                }
                Divider()
                    .frame(height: 18)
                    .overlay(Color.white.opacity(0.12))
                layerLabelFilterMenu
            }
        }
    }

    private var layerLabelFilterMenu: some View {
        Menu {
            Button {
                selectedLayerLabelFilter = nil
            } label: {
                Label(L10n.text("imageEditor.layer.labelFilter.all"), systemImage: "tag")
            }

            Divider()

            ForEach(ImageEditorLayerLabelColor.allCases) { labelColor in
                Button {
                    selectedLayerLabelFilter = labelColor
                } label: {
                    Label(labelColor.title, systemImage: "tag.fill")
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: selectedLayerLabelFilter == nil ? "tag" : "tag.fill")
                    .font(.system(size: 12, weight: .semibold))
                if let selectedLayerLabelFilter {
                    Circle()
                        .fill(layerLabelColor(selectedLayerLabelFilter))
                        .frame(width: 8, height: 8)
                }
            }
            .frame(width: 34, height: 24)
        }
        .buttonStyle(EditorIconButtonStyle(isSelected: selectedLayerLabelFilter != nil))
        .help(selectedLayerLabelFilter.map { L10n.format("imageEditor.layer.labelFilter.active", $0.title) }
            ?? L10n.text("imageEditor.layer.labelFilter.all"))
    }

    private var layerRows: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(filteredVisibleLayerRows) { layer in
                    layerRow(layer)
                }
                if filteredVisibleLayerRows.isEmpty {
                    Text(L10n.text("imageEditor.layer.searchEmpty"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                }
            }
        }
        .accessibilityIdentifier("image-editor-layer-list")
    }

    private func layerActionButton(systemImage: String, helpKey: String, isSelected: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 24, height: 24)
        }
        .buttonStyle(EditorIconButtonStyle(isSelected: isSelected))
        .help(L10n.text(helpKey))
    }

    private func layerRow(_ layer: ImageEditorLayer) -> some View {
        let indentation = CGFloat(viewModel.document.groupDepth(for: layer)) * 14
        return VStack(spacing: 2) {
            layerDropBand(layer, placement: .above)

            HStack(spacing: 6) {
                if indentation > 0 {
                    Spacer().frame(width: indentation)
                }
                layerVisibilityButton(layer)
                layerDragHandle(layer)
                layerGroupDisclosure(layer)
                layerContentButton(layer)
                layerLockButton(layer)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 8)
            .background(layerRowBackground(layer))
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .onDrop(
                of: [UTType.plainText],
                delegate: ImageEditorLayerDropDelegate(
                    onTargetChange: { isTargeted, location in
                        targetedLayerDropTarget = isTargeted
                            ? ImageEditorLayerDropTarget(
                                layerID: layer.id,
                                placement: layerRowDropPlacement(layer, location: location)
                            )
                            : nil
                    },
                    onDrop: { sourceID, location in
                        _ = handleLayerDrop(
                            [sourceID],
                            on: layer,
                            placement: layerRowDropPlacement(layer, location: location)
                        )
                    }
                )
            )
            .help(layer.isGroup ? L10n.text("imageEditor.action.layerDropInsideGroup") : L10n.text("imageEditor.action.layerDragReorder"))
            .accessibilityElement(children: .contain)
            .accessibilityLabel(layer.name)
            .accessibilityIdentifier("image-editor-layer-row-\(layer.id.uuidString)")
            .contextMenu {
                Button {
                    beginLayerInlineRename(layer)
                } label: {
                    Label(
                        L10n.text("imageEditor.action.layerRename"),
                        systemImage: "pencil"
                    )
                }
                .accessibilityIdentifier("image-editor-layer-context-rename-\(layer.id.uuidString)")

                Divider()
                Button {
                    viewModel.prepareLayerContextSelection(for: layer.id)
                    viewModel.cutSelectedLayersToClipboard()
                } label: {
                    Label(
                        L10n.text("imageEditor.action.layerCut"),
                        systemImage: "scissors"
                    )
                }
                .disabled(!viewModel.canCutLayersFromContext(layer.id))
                .accessibilityIdentifier("image-editor-layer-context-cut-\(layer.id.uuidString)")

                Button {
                    viewModel.prepareLayerContextSelection(for: layer.id)
                    viewModel.copySelectedLayersToClipboard()
                } label: {
                    Label(
                        L10n.text("imageEditor.action.layerCopy"),
                        systemImage: "doc.on.clipboard"
                    )
                }
                .disabled(!viewModel.canCopyLayersFromContext(layer.id))
                .accessibilityIdentifier("image-editor-layer-context-copy-\(layer.id.uuidString)")

                Divider()
                Button {
                    viewModel.prepareLayerContextSelection(for: layer.id)
                    viewModel.pasteClipboardAsLayer()
                } label: {
                    Label(
                        L10n.text("imageEditor.action.pasteClipboardLayer"),
                        systemImage: "doc.on.clipboard"
                    )
                }
                .disabled(!viewModel.canPasteClipboardImage)
                .accessibilityIdentifier("image-editor-layer-context-paste-\(layer.id.uuidString)")

                Button {
                    viewModel.prepareLayerContextSelection(for: layer.id)
                    viewModel.pasteClipboardInPlaceAsLayer()
                } label: {
                    Label(
                        L10n.text("imageEditor.action.pasteClipboardInPlaceLayer"),
                        systemImage: "arrow.down.doc"
                    )
                }
                .disabled(!viewModel.canPasteClipboardImageInPlace)
                .accessibilityIdentifier("image-editor-layer-context-paste-in-place-\(layer.id.uuidString)")

                Divider()
                Button {
                    viewModel.prepareLayerContextSelection(for: layer.id)
                    viewModel.duplicateSelectedLayer()
                } label: {
                    Label(
                        L10n.text("imageEditor.action.layerDuplicate"),
                        systemImage: "doc.on.doc"
                    )
                }
                .disabled(!viewModel.canDuplicateLayersFromContext(layer.id))
                .accessibilityIdentifier("image-editor-layer-context-duplicate-\(layer.id.uuidString)")

                Divider()
                Button {
                    viewModel.prepareLayerContextSelection(for: layer.id)
                    viewModel.groupSelectedLayer()
                } label: {
                    Label(
                        L10n.text("imageEditor.action.layerGroupSelected"),
                        systemImage: "folder.badge.plus"
                    )
                }
                .disabled(!viewModel.canGroupLayersFromContext(layer.id))
                .accessibilityIdentifier("image-editor-layer-context-group-\(layer.id.uuidString)")

                Button {
                    viewModel.prepareLayerContextSelection(for: layer.id)
                    viewModel.ungroupSelectedLayers()
                } label: {
                    Label(
                        L10n.text("imageEditor.action.layerUngroup"),
                        systemImage: "folder.badge.minus"
                    )
                }
                .disabled(!viewModel.canUngroupLayersFromContext(layer.id))
                .accessibilityIdentifier("image-editor-layer-context-ungroup-\(layer.id.uuidString)")

                layerContextClippingMaskButton(layer)

                Divider()
                Button(role: .destructive) {
                    viewModel.prepareLayerContextSelection(for: layer.id)
                    viewModel.deleteSelectedLayer()
                } label: {
                    Label(
                        L10n.text("imageEditor.action.layerDelete"),
                        systemImage: "trash"
                    )
                }
                .disabled(!viewModel.canDeleteLayersFromContext(layer.id))
                .accessibilityIdentifier("image-editor-layer-context-delete-\(layer.id.uuidString)")

                Divider()
                Button {
                    if !viewModel.isLayerSelected(layer.id) {
                        viewModel.selectLayer(layer.id)
                    }
                    guard let scope = viewModel.selectedLayersExportScope else { return }
                    viewModel.exportSettings.scope = scope
                    viewModel.openExportPanel()
                } label: {
                    Label(
                        L10n.text("imageEditor.action.exportLayers"),
                        systemImage: "square.and.arrow.up"
                    )
                }
                .disabled(layer.isAdjustment || layer.isFilter)

                if viewModel.openableFigmaSourceURL(for: layer.id) != nil {
                    Divider()
                    Button {
                        viewModel.selectLayer(layer.id)
                        viewModel.openSelectedFigmaSourceURL()
                    } label: {
                        Label(
                            L10n.text("imageEditor.action.openFigmaSourceURL"),
                            systemImage: "arrow.up.right.square"
                        )
                    }
                    .accessibilityIdentifier("image-editor-layer-open-figma-source-\(layer.id.uuidString)")

                    Button {
                        viewModel.selectLayer(layer.id)
                        viewModel.copySelectedFigmaSourceURL()
                    } label: {
                        Label(
                            L10n.text("imageEditor.action.copyFigmaSourceURL"),
                            systemImage: "doc.on.doc"
                        )
                    }
                    .accessibilityIdentifier("image-editor-layer-copy-figma-source-\(layer.id.uuidString)")
                }
            }

            layerDropBand(layer, placement: .below)
        }
    }

    private func layerRowDropPlacement(_ layer: ImageEditorLayer, location: CGPoint) -> ImageEditorLayerDropPlacement {
        if layer.isGroup {
            return .insideGroup
        }
        return location.y < 22 ? .above : .below
    }

    private func layerDragHandle(_ layer: ImageEditorLayer) -> some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
            .frame(width: 12, height: 22)
            .contentShape(Rectangle())
            .gesture(layerReorderGesture(layer))
            .accessibilityLabel(L10n.text("imageEditor.action.layerDragReorder"))
            .accessibilityIdentifier("image-editor-layer-drag-handle-\(layer.id.uuidString)")
    }

    private func layerReorderGesture(_ layer: ImageEditorLayer) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if !viewModel.isLayerSelected(layer.id) {
                    viewModel.selectLayer(layer.id)
                }
                targetedLayerDropTarget = layerDragTarget(
                    for: layer,
                    verticalTranslation: value.translation.height
                )
            }
            .onEnded { value in
                defer { targetedLayerDropTarget = nil }
                guard let target = layerDragTarget(
                    for: layer,
                    verticalTranslation: value.translation.height
                ) else { return }
                let sourceIDs = viewModel.layerDragSourceIDs(for: layer.id)
                _ = viewModel.moveLayerIDs(sourceIDs, toDropTarget: target)
            }
    }

    private func layerDragTarget(
        for layer: ImageEditorLayer,
        verticalTranslation: CGFloat
    ) -> ImageEditorLayerDropTarget? {
        let rows = filteredVisibleLayerRows
        guard let sourceIndex = rows.firstIndex(where: { $0.id == layer.id }) else { return nil }
        let step = Int((verticalTranslation / imageEditorLayerRowDragStride).rounded())
        guard step != 0 else { return nil }
        let targetIndex = min(max(sourceIndex + step, rows.startIndex), rows.index(before: rows.endIndex))
        guard targetIndex != sourceIndex else { return nil }
        let targetLayer = rows[targetIndex]
        let placement: ImageEditorLayerDropPlacement = targetIndex > sourceIndex ? .below : .above
        return ImageEditorLayerDropTarget(layerID: targetLayer.id, placement: placement)
    }

    private func layerRowBackground(_ layer: ImageEditorLayer) -> Color {
        let insideTarget = targetedLayerDropTarget == ImageEditorLayerDropTarget(layerID: layer.id, placement: .insideGroup)
        let opacity = insideTarget ? 0.58 : (viewModel.isLayerSelected(layer.id) ? 0.45 : 0.14)
        return Color(nsColor: ImageEditorTheme.selected).opacity(opacity)
    }

    private func layerDropBand(_ layer: ImageEditorLayer, placement: ImageEditorLayerDropPlacement) -> some View {
        let target = ImageEditorLayerDropTarget(layerID: layer.id, placement: placement)
        let isTargeted = targetedLayerDropTarget == target
        return Rectangle()
            .fill(isTargeted ? Color(nsColor: ImageEditorTheme.selected) : Color.clear)
            .frame(height: 6)
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            .onDrop(
                of: [UTType.plainText],
                delegate: ImageEditorLayerDropDelegate(
                    onTargetChange: { isTargeted, _ in
                        targetedLayerDropTarget = isTargeted ? target : nil
                    },
                    onDrop: { sourceID, _ in
                        _ = handleLayerDrop([sourceID], on: layer, placement: placement)
                    }
                )
            )
            .help(L10n.text(placement == .above ? "imageEditor.action.layerDropAbove" : "imageEditor.action.layerDropBelow"))
    }

    private func handleLayerDrop(
        _ items: [String],
        on layer: ImageEditorLayer,
        placement: ImageEditorLayerDropPlacement
    ) -> Bool {
        guard let sourceID = items.compactMap({ UUID(uuidString: $0) }).first else { return false }
        let sourceIDs = viewModel.layerDragSourceIDs(for: sourceID)
        let target = ImageEditorLayerDropTarget(layerID: layer.id, placement: placement)
        return viewModel.moveLayerIDs(sourceIDs, toDropTarget: target)
    }

    @ViewBuilder
    private func layerGroupDisclosure(_ layer: ImageEditorLayer) -> some View {
        if layer.isGroup {
            Button {
                viewModel.toggleLayerGroupExpansion(
                    layer.id,
                    recursively: NSEvent.modifierFlags.contains(.option)
                )
            } label: {
                Image(systemName: layer.isGroupExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 14, height: 22)
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
            }
            .buttonStyle(.plain)
            .focusable(false)
            .help(L10n.text(
                layer.isGroupExpanded
                    ? "imageEditor.action.layerGroupCollapseBranchHint"
                    : "imageEditor.action.layerGroupExpandBranchHint"
            ))
        } else {
            Spacer().frame(width: 14)
        }
    }

    private func layerVisibilityButton(_ layer: ImageEditorLayer) -> some View {
        Button {
            viewModel.toggleLayerVisibility(layer.id, applyingToSelection: true)
        } label: {
            Image(systemName: layer.isVisible ? "eye" : "eye.slash")
                .frame(width: 18, height: 22)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(L10n.text("imageEditor.action.layerVisibility"))
        .accessibilityLabel(L10n.text("imageEditor.action.layerVisibility"))
        .accessibilityValue(L10n.text(
            layer.isVisible
                ? "imageEditor.accessibility.layerVisible"
                : "imageEditor.accessibility.layerHidden"
        ))
        .accessibilityIdentifier("image-editor-layer-visibility-\(layer.id.uuidString)")
    }

    private func layerContentButton(_ layer: ImageEditorLayer) -> some View {
        Button {
            selectLayerFromPanel(layer)
        } label: {
            HStack(spacing: 8) {
                layerLabelColorSwatch(layer)
                layerThumbnail(layer)
                layerRasterMaskThumbnail(layer)
                layerVectorMaskThumbnail(layer)
                layerNameEditor(layer)
                Spacer()
                layerBadges(layer)
                layerLockToggles(layer)
                Text("\(Int((layer.opacity * 100).rounded()))%")
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(minWidth: 32, alignment: .trailing)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .accessibilityIdentifier("image-editor-layer-content-\(layer.id.uuidString)")
    }

    private func selectLayerFromPanel(_ layer: ImageEditorLayer) {
        let flags = NSEvent.modifierFlags
        if flags.contains(.shift) {
            viewModel.selectLayerRange(
                to: layer.id,
                among: filteredVisibleLayerRows.map(\.id),
                addingToSelection: flags.contains(.command)
            )
        } else {
            viewModel.selectLayer(
                layer.id,
                editingMask: false,
                extendingSelection: flags.contains(.command)
            )
        }
    }

    @ViewBuilder
    private func layerNameEditor(_ layer: ImageEditorLayer) -> some View {
        if renamingLayerID == layer.id {
            TextField(
                L10n.text("imageEditor.properties.layerNamePlaceholder"),
                text: $inlineLayerNameDraft
            )
            .textFieldStyle(.plain)
            .font(.system(size: 12, weight: .semibold))
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .focused($focusedInlineLayerNameID, equals: layer.id)
            .onSubmit {
                commitLayerInlineRename(layer.id)
            }
            .onExitCommand {
                cancelLayerInlineRename(layer.id)
            }
            .onChange(of: focusedInlineLayerNameID) { focusedID in
                if focusedID != layer.id, renamingLayerID == layer.id {
                    commitLayerInlineRename(layer.id)
                }
            }
            .accessibilityIdentifier("image-editor-layer-inline-name-\(layer.id.uuidString)")
        } else {
            Text(layer.name)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    beginLayerInlineRename(layer)
                }
        }
    }

    private func layerContextClippingMaskButton(_ layer: ImageEditorLayer) -> some View {
        let action = viewModel.clippingMaskActionFromContext(layer.id)
        return Button {
            viewModel.applyClippingMaskActionFromContext(layer.id)
        } label: {
            Label(
                L10n.text((action ?? .create).titleKey),
                systemImage: "arrow.down.to.line.compact"
            )
        }
        .disabled(action == nil)
        .accessibilityIdentifier("image-editor-layer-context-clipping-mask-\(layer.id.uuidString)")
    }

    private func beginLayerInlineRename(_ layer: ImageEditorLayer) {
        viewModel.selectLayer(layer.id)
        inlineLayerNameDraft = layer.name
        renamingLayerID = layer.id
        Task { @MainActor in
            await Task.yield()
            guard renamingLayerID == layer.id else { return }
            focusedInlineLayerNameID = layer.id
        }
    }

    private func commitLayerInlineRename(_ layerID: UUID) {
        guard renamingLayerID == layerID else { return }
        let proposedName = inlineLayerNameDraft
        renamingLayerID = nil
        focusedInlineLayerNameID = nil
        guard !proposedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        _ = viewModel.renameLayer(layerID, to: proposedName)
    }

    private func cancelLayerInlineRename(_ layerID: UUID) {
        guard renamingLayerID == layerID else { return }
        renamingLayerID = nil
        focusedInlineLayerNameID = nil
        inlineLayerNameDraft = ""
    }

    @ViewBuilder
    private func layerLabelColorSwatch(_ layer: ImageEditorLayer) -> some View {
        if let labelColor = layer.labelColor {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(layerLabelColor(labelColor))
                .frame(width: 5, height: 28)
                .help(L10n.format("imageEditor.layer.labelBadge", labelColor.title))
        } else {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .frame(width: 5, height: 28)
        }
    }

    private func layerLabelColor(_ labelColor: ImageEditorLayerLabelColor) -> Color {
        switch labelColor {
        case .red:
            return Color(nsColor: NSColor(calibratedRed: 0.93, green: 0.25, blue: 0.25, alpha: 1))
        case .orange:
            return Color(nsColor: NSColor(calibratedRed: 0.95, green: 0.55, blue: 0.18, alpha: 1))
        case .yellow:
            return Color(nsColor: NSColor(calibratedRed: 0.92, green: 0.76, blue: 0.20, alpha: 1))
        case .green:
            return Color(nsColor: NSColor(calibratedRed: 0.25, green: 0.72, blue: 0.39, alpha: 1))
        case .blue:
            return Color(nsColor: NSColor(calibratedRed: 0.25, green: 0.52, blue: 0.95, alpha: 1))
        case .purple:
            return Color(nsColor: NSColor(calibratedRed: 0.64, green: 0.42, blue: 0.92, alpha: 1))
        case .gray:
            return Color(nsColor: NSColor(calibratedWhite: 0.58, alpha: 1))
        }
    }

    private func layerThumbnail(_ layer: ImageEditorLayer) -> some View {
        Button {
            if !loadSelectionFromLayerThumbnail(layer, source: .transparency) {
                selectLayerFromPanel(layer)
            }
        } label: {
            Image(nsImage: layer.thumbnail())
                .resizable()
                .scaledToFill()
                .frame(width: 34, height: 26)
                .clipped()
                .background(Color.white.opacity(0.18))
                .overlay(Rectangle().stroke(contentThumbnailStroke(for: layer), lineWidth: 1.4))
        }
        .buttonStyle(.plain)
        .help(L10n.text("imageEditor.layer.thumbnailSelectionHelp"))
    }

    @ViewBuilder
    private func layerRasterMaskThumbnail(_ layer: ImageEditorLayer) -> some View {
        if let maskThumbnail = layer.maskThumbnail() {
            layerMaskLinkButton(layer)
            Button {
                if !handleLayerThumbnailGesture(layer, source: .rasterMask) {
                    viewModel.selectLayer(layer.id, editingMask: true)
                }
            } label: {
                Image(nsImage: maskThumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 24, height: 24)
                    .clipped()
                    .background(Color.black.opacity(0.24))
                    .overlay(Rectangle().stroke(maskThumbnailStroke(for: layer), lineWidth: 1.4))
                    .overlay {
                        if !layer.isMaskEnabled {
                            DisabledMaskSlash()
                        }
                    }
            }
            .buttonStyle(.plain)
            .help(L10n.text("imageEditor.layer.rasterMaskThumbnailSelectionHelp"))
        }
    }

    @ViewBuilder
    private func layerVectorMaskThumbnail(_ layer: ImageEditorLayer) -> some View {
        if let vectorMaskThumbnail = layer.vectorMaskThumbnail() {
            if layer.mask == nil {
                layerMaskLinkButton(layer)
            } else {
                Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                    .font(.system(size: 9, weight: .bold))
                    .frame(width: 12, height: 24)
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                    .help(L10n.text("imageEditor.layer.vectorMaskBadge"))
            }
            Button {
                if !handleLayerThumbnailGesture(layer, source: .vectorMask) {
                    viewModel.selectLayer(layer.id, editingMask: false)
                    viewModel.editSelectedVectorMaskAsPath()
                }
            } label: {
                Image(nsImage: vectorMaskThumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 24, height: 24)
                    .clipped()
                    .background(Color.black.opacity(0.24))
                    .overlay(Rectangle().stroke(vectorMaskThumbnailStroke(for: layer), lineWidth: 1.4))
                    .overlay {
                        if !layer.isVectorMaskEnabled {
                            DisabledMaskSlash()
                        }
                    }
            }
            .buttonStyle(.plain)
            .help(L10n.text("imageEditor.layer.vectorMaskThumbnailSelectionHelp"))
        }
    }

    private func layerMaskLinkButton(_ layer: ImageEditorLayer) -> some View {
        Button {
            viewModel.toggleLayerMaskLinked(layerID: layer.id)
        } label: {
            Image(systemName: layer.isMaskLinked ? "link" : "link.slash")
                .font(.system(size: 9, weight: .bold))
                .frame(width: 12, height: 24)
                .foregroundStyle(
                    layer.isMaskLinked
                        ? Color(nsColor: ImageEditorTheme.mutedText)
                        : Color(nsColor: ImageEditorTheme.selected)
                )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.document.isEffectivelyLocked(layer))
        .help(L10n.text("imageEditor.action.layerMaskLinkToggle"))
        .accessibilityLabel(L10n.text("imageEditor.action.layerMaskLinkToggle"))
        .accessibilityValue(L10n.text(
            layer.isMaskLinked
                ? "imageEditor.action.layerMaskLinked"
                : "imageEditor.action.layerMaskUnlinked"
        ))
    }

    private func loadSelectionFromLayerThumbnail(
        _ layer: ImageEditorLayer,
        source: ImageEditorLayerThumbnailSelectionSource
    ) -> Bool {
        guard let mode = ImageEditorLayerThumbnailSelectionPolicy.mode(
            sidebarTab: viewModel.selectedLeftSidebarTab,
            modifierFlags: NSEvent.modifierFlags
        ) else { return false }

        switch source {
        case .transparency:
            viewModel.loadSelectionFromLayerTransparency(layerID: layer.id, mode: mode)
        case .rasterMask:
            viewModel.loadSelectionFromLayerMask(layerID: layer.id, mode: mode)
        case .vectorMask:
            viewModel.loadSelectionFromVectorMask(layerID: layer.id, mode: mode)
        }
        return true
    }

    private func handleLayerThumbnailGesture(
        _ layer: ImageEditorLayer,
        source: ImageEditorLayerThumbnailSelectionSource
    ) -> Bool {
        let flags = NSEvent.modifierFlags
        if ImageEditorLayerThumbnailSelectionPolicy.previewsRasterMask(
            sidebarTab: viewModel.selectedLeftSidebarTab,
            source: source,
            modifierFlags: flags
        ) {
            return viewModel.toggleLayerMaskSoloPreview(layerID: layer.id)
        }
        if ImageEditorLayerThumbnailSelectionPolicy.previewsRasterMaskAsRubylith(
            sidebarTab: viewModel.selectedLeftSidebarTab,
            source: source,
            modifierFlags: flags
        ) {
            return viewModel.toggleLayerMaskRubylithPreview(layerID: layer.id)
        }
        if ImageEditorLayerThumbnailSelectionPolicy.togglesMaskEnabled(
            sidebarTab: viewModel.selectedLeftSidebarTab,
            source: source,
            modifierFlags: flags
        ) {
            switch source {
            case .transparency:
                return false
            case .rasterMask:
                viewModel.toggleLayerMaskEnabled(layerID: layer.id)
            case .vectorMask:
                viewModel.toggleVectorMaskEnabled(layerID: layer.id)
            }
            return true
        }
        return loadSelectionFromLayerThumbnail(layer, source: source)
    }

    private func layerBadges(_ layer: ImageEditorLayer) -> some View {
        Group {
            if layer.isGroup {
                layerTextBadge("imageEditor.layer.groupBadge")
            } else if layer.isAdjustment {
                layerTextBadge("imageEditor.layer.adjustmentBadge")
            } else if layer.isFilter {
                layerTextBadge("imageEditor.layer.filterBadge")
            } else if layer.isSolidColorFill {
                layerTextBadge("imageEditor.layer.solidColorFillBadge")
            } else if layer.isPatternFill {
                layerTextBadge("imageEditor.layer.patternFillBadge")
            } else if layer.isGradientFill {
                layerTextBadge("imageEditor.layer.gradientFillBadge")
            } else if layer.isText {
                layerTextBadge("imageEditor.layer.textBadge")
            } else if layer.isShape {
                layerTextBadge("imageEditor.layer.shapeBadge")
            } else if layer.isSmartObject {
                layerTextBadge("imageEditor.layer.smartObjectBadge")
            } else if layer.hasSmartFilters {
                layerTextBadge("imageEditor.layer.smartFilterBadge")
            } else if layer.blendMode != .normal {
                Text(layer.blendMode.title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                    .lineLimit(1)
            }
            if layer.isClippingMask {
                Text(L10n.text("imageEditor.layer.clippingBadge"))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color(nsColor: ImageEditorTheme.selected).opacity(0.52))
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            }
            if viewModel.isLayerLinked(layer.id) {
                Image(systemName: "link")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                    .frame(width: 14, height: 14)
                    .help(L10n.text("imageEditor.layer.linkedBadge"))
            }
            if layer.hasLayerEffects {
                Text("fx")
                    .font(.system(size: 10, weight: .bold, design: .serif))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color(nsColor: ImageEditorTheme.selected).opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                    .opacity(layer.style.effectsEnabled ? 1 : 0.42)
                    .help(
                        L10n.text(
                            layer.style.effectsEnabled
                                ? "imageEditor.action.layerEffectsHideSelected"
                                : "imageEditor.action.layerEffectsShowSelected"
                        )
                    )
            }
        }
    }

    private func layerTextBadge(_ key: String) -> some View {
        Text(L10n.text(key))
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
            .lineLimit(1)
    }

    private func layerLockToggles(_ layer: ImageEditorLayer) -> some View {
        Group {
            layerSmallToggle(
                systemImage: layer.locksPixels ? "photo.fill" : "photo",
                helpKey: layer.locksPixels ? "imageEditor.action.layerPixelsUnlock" : "imageEditor.action.layerPixelsLock",
                isEnabled: canTogglePixelsLock(for: layer)
            ) {
                viewModel.toggleLayerPixelsLock(layer.id, applyingToSelection: true)
            }
            layerSmallToggle(
                systemImage: layer.locksPosition ? "arrow.up.left.and.arrow.down.right.circle.fill" : "arrow.up.left.and.arrow.down.right.circle",
                helpKey: layer.locksPosition ? "imageEditor.action.layerPositionUnlock" : "imageEditor.action.layerPositionLock",
                isEnabled: canTogglePositionLock(for: layer)
            ) {
                viewModel.toggleLayerPositionLock(layer.id, applyingToSelection: true)
            }
            layerSmallToggle(
                systemImage: layer.locksTransparentPixels ? "square.split.2x2.fill" : "square.split.2x2",
                helpKey: layer.locksTransparentPixels ? "imageEditor.action.layerTransparentUnlock" : "imageEditor.action.layerTransparentLock",
                isEnabled: canToggleTransparentPixelsLock(for: layer)
            ) {
                viewModel.toggleLayerTransparentPixelsLock(layer.id, applyingToSelection: true)
            }
        }
    }

    private func layerSmallToggle(systemImage: String, helpKey: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .bold))
                .frame(width: 16, height: 18)
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.35)
        .disabled(!isEnabled)
        .help(L10n.text(helpKey))
    }

    private func layerLockButton(_ layer: ImageEditorLayer) -> some View {
        Button {
            viewModel.toggleLayerLock(layer.id, applyingToSelection: true)
        } label: {
            Image(systemName: layer.isLocked ? "lock.fill" : "lock.open")
                .font(.system(size: 10, weight: .bold))
                .frame(width: 16, height: 22)
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
        }
        .buttonStyle(.plain)
        .help(L10n.text(layer.isLocked ? "imageEditor.action.layerUnlock" : "imageEditor.action.layerLock"))
    }

    private func canToggleTransparentPixelsLock(for layer: ImageEditorLayer) -> Bool {
        !layer.isGroup && !layer.isAdjustment && !layer.isFilter && !layer.isSolidColorFill && !layer.isPatternFill && !layer.isGradientFill && !layer.isText && !layer.isShape
    }

    private func canTogglePixelsLock(for layer: ImageEditorLayer) -> Bool {
        !layer.isAdjustment && !layer.isFilter && !layer.isSolidColorFill && !layer.isPatternFill && !layer.isGradientFill
    }

    private func canTogglePositionLock(for layer: ImageEditorLayer) -> Bool {
        !layer.isAdjustment && !layer.isFilter && !layer.isSolidColorFill && !layer.isPatternFill && !layer.isGradientFill
    }

    private func contentThumbnailStroke(for layer: ImageEditorLayer) -> Color {
        let selected = viewModel.isPrimaryLayer(layer.id) && !viewModel.isEditingLayerMask
        return selected ? Color.white.opacity(0.9) : Color.white.opacity(0.18)
    }

    private func maskThumbnailStroke(for layer: ImageEditorLayer) -> Color {
        let selected = viewModel.isPrimaryLayer(layer.id) && viewModel.isEditingLayerMask
        return selected ? Color(nsColor: ImageEditorTheme.selected) : Color.white.opacity(0.22)
    }

    private func vectorMaskThumbnailStroke(for layer: ImageEditorLayer) -> Color {
        let selected = viewModel.isPrimaryLayer(layer.id) && !viewModel.isEditingLayerMask
        return selected ? Color(nsColor: ImageEditorTheme.selected).opacity(0.9) : Color.white.opacity(0.22)
    }

    private var selectedLayerOpacityBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerOpacity
        } set: { value in
            viewModel.setSelectedLayerOpacity(value)
        }
    }

    private var selectedLayerFillOpacityBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerFillOpacity
        } set: { value in
            viewModel.setSelectedLayerFillOpacity(value)
        }
    }

    private var selectedLayerBlendIfSourceBlackBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerBlendIfSourceBlack
        } set: { value in
            viewModel.setSelectedLayerBlendIfSourceBlack(value)
        }
    }

    private var selectedLayerBlendIfSourceWhiteBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerBlendIfSourceWhite
        } set: { value in
            viewModel.setSelectedLayerBlendIfSourceWhite(value)
        }
    }

    private var selectedLayerBlendIfUnderlyingBlackBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerBlendIfUnderlyingBlack
        } set: { value in
            viewModel.setSelectedLayerBlendIfUnderlyingBlack(value)
        }
    }

    private var selectedLayerBlendIfUnderlyingWhiteBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerBlendIfUnderlyingWhite
        } set: { value in
            viewModel.setSelectedLayerBlendIfUnderlyingWhite(value)
        }
    }

    private var selectedLayerMaskDensityBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerMaskDensity
        } set: { value in
            viewModel.setSelectedLayerMaskDensity(value)
        }
    }

    private var selectedLayerMaskFeatherBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerMaskFeather
        } set: { value in
            viewModel.setSelectedLayerMaskFeather(value)
        }
    }

    private var selectedLayerBlendModeBinding: Binding<ImageEditorBlendMode> {
        Binding {
            viewModel.selectedLayerBlendMode
        } set: { value in
            viewModel.setSelectedLayerBlendMode(value)
        }
    }
}

private struct ImageEditorLayerDropDelegate: DropDelegate {
    let onTargetChange: (Bool, CGPoint) -> Void
    let onDrop: (String, CGPoint) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.plainText])
    }

    func dropEntered(info: DropInfo) {
        onTargetChange(true, info.location)
    }

    func dropExited(info: DropInfo) {
        onTargetChange(false, info.location)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        onTargetChange(true, info.location)
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let provider = info.itemProviders(for: [UTType.plainText]).first
        else {
            onTargetChange(false, info.location)
            return false
        }

        let location = info.location
        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let sourceID = object as? NSString else { return }
            DispatchQueue.main.async {
                onTargetChange(false, location)
                onDrop(sourceID as String, location)
            }
        }
        return true
    }
}

private struct ImageEditorSavedPathDropDelegate: DropDelegate {
    let onTargetChange: (Bool) -> Void
    let onDrop: (String) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.plainText])
    }

    func dropEntered(info: DropInfo) {
        onTargetChange(true)
    }

    func dropExited(info: DropInfo) {
        onTargetChange(false)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        onTargetChange(true)
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let provider = info.itemProviders(for: [UTType.plainText]).first else {
            onTargetChange(false)
            return false
        }

        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let sourceID = object as? NSString else { return }
            DispatchQueue.main.async {
                onTargetChange(false)
                onDrop(sourceID as String)
            }
        }
        return true
    }
}
