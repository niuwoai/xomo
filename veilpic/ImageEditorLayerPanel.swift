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
    var identifier = "image-editor-layer-search-field"
    var onSubmit: (() -> Void)?
    var onCancel: (() -> Void)?
    var onMovePrevious: (() -> Void)?
    var onMoveNext: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            onSubmit: onSubmit,
            onCancel: onCancel,
            onMovePrevious: onMovePrevious,
            onMoveNext: onMoveNext
        )
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(string: text)
        field.delegate = context.coordinator
        ImageEditorLayerSearchAppearance.configure(field, placeholder: placeholder)
        field.identifier = NSUserInterfaceItemIdentifier(identifier)
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.text = $text
        context.coordinator.onSubmit = onSubmit
        context.coordinator.onCancel = onCancel
        context.coordinator.onMovePrevious = onMovePrevious
        context.coordinator.onMoveNext = onMoveNext
        if field.stringValue != text {
            field.stringValue = text
        }
        ImageEditorLayerSearchAppearance.configure(field, placeholder: placeholder)
        field.identifier = NSUserInterfaceItemIdentifier(identifier)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>
        var onSubmit: (() -> Void)?
        var onCancel: (() -> Void)?
        var onMovePrevious: (() -> Void)?
        var onMoveNext: (() -> Void)?

        init(
            text: Binding<String>,
            onSubmit: (() -> Void)?,
            onCancel: (() -> Void)?,
            onMovePrevious: (() -> Void)? = nil,
            onMoveNext: (() -> Void)? = nil
        ) {
            self.text = text
            self.onSubmit = onSubmit
            self.onCancel = onCancel
            self.onMovePrevious = onMovePrevious
            self.onMoveNext = onMoveNext
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)), let onSubmit {
                onSubmit()
                return true
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)), let onCancel {
                onCancel()
                return true
            }
            if commandSelector == #selector(NSResponder.moveUp(_:)), let onMovePrevious {
                onMovePrevious()
                return true
            }
            if commandSelector == #selector(NSResponder.moveDown(_:)), let onMoveNext {
                onMoveNext()
                return true
            }
            return false
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
                ImageEditorLayerAdvancedControlsViewport {
                    VStack(spacing: 8) {
                        layerOpacityControls
                        layerMaskControls
                        layerKindFilterBar
                    }
                }
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

            ImageEditorLayerPropertySlider(value: viewModel.selectedLayerOpacity, viewModel: viewModel,
                                          property: .opacity, in: 0...1, step: 0.05) {
                Text(L10n.text("imageEditor.option.opacity"))
            } minimumValueLabel: {
                Text("0")
            } maximumValueLabel: {
                Text("100")
            }
            .font(.system(size: 10, weight: .medium).monospacedDigit())

            HStack(spacing: 8) {
                Text(L10n.text("imageEditor.option.fillOpacity"))
                Text("\(Int((viewModel.selectedLayerFillOpacity * 100).rounded()))%")
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
            }
            .font(.system(size: 11, weight: .medium))
            .frame(maxWidth: .infinity, alignment: .leading)

            ImageEditorLayerPropertySlider(value: viewModel.selectedLayerFillOpacity, viewModel: viewModel,
                                          property: .fillOpacity, in: 0...1, step: 0.05) {
                Text(L10n.text("imageEditor.option.fillOpacity"))
            } minimumValueLabel: {
                Text("0")
            } maximumValueLabel: {
                Text("100")
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

            ImageEditorLayerPropertySlider(value: viewModel.selectedLayerBlendIfSourceBlack, viewModel: viewModel,
                                          property: .sourceBlack, in: 0...1, step: 1 / 255) {
                Text(L10n.text("imageEditor.option.blendIfBlack"))
            } minimumValueLabel: {
                Text(L10n.text("imageEditor.option.blendIfBlackShort"))
            } maximumValueLabel: {
                Text("")
            }
            .disabled(!viewModel.canEditSelectedLayerBlendIf)
            .font(.system(size: 10, weight: .medium).monospacedDigit())

            ImageEditorLayerPropertySlider(value: viewModel.selectedLayerBlendIfSourceWhite, viewModel: viewModel,
                                          property: .sourceWhite, in: 0...1, step: 1 / 255) {
                Text(L10n.text("imageEditor.option.blendIfWhite"))
            } minimumValueLabel: {
                Text("")
            } maximumValueLabel: {
                Text(L10n.text("imageEditor.option.blendIfWhiteShort"))
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

            ImageEditorLayerPropertySlider(value: viewModel.selectedLayerBlendIfUnderlyingBlack, viewModel: viewModel,
                                          property: .underlyingBlack, in: 0...1, step: 1 / 255) {
                Text(L10n.text("imageEditor.option.blendIfUnderlyingBlack"))
            } minimumValueLabel: {
                Text(L10n.text("imageEditor.option.blendIfBlackShort"))
            } maximumValueLabel: {
                Text("")
            }
            .disabled(!viewModel.canEditSelectedLayerBlendIf)
            .font(.system(size: 10, weight: .medium).monospacedDigit())

            ImageEditorLayerPropertySlider(value: viewModel.selectedLayerBlendIfUnderlyingWhite, viewModel: viewModel,
                                          property: .underlyingWhite, in: 0...1, step: 1 / 255) {
                Text(L10n.text("imageEditor.option.blendIfUnderlyingWhite"))
            } minimumValueLabel: {
                Text("")
            } maximumValueLabel: {
                Text(L10n.text("imageEditor.option.blendIfWhiteShort"))
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

                ImageEditorLayerPropertySlider(value: viewModel.selectedLayerMaskDensity, viewModel: viewModel,
                                              property: .maskDensity, in: 0...1, step: 0.05) {
                    Text(L10n.text("imageEditor.option.maskDensity"))
                } minimumValueLabel: {
                    Text("0")
                } maximumValueLabel: {
                    Text("100")
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

                ImageEditorLayerPropertySlider(value: viewModel.selectedLayerMaskFeather, viewModel: viewModel,
                                              property: .maskFeather, in: 0...80, step: 1) {
                    Text(L10n.text("imageEditor.option.maskFeather"))
                } minimumValueLabel: {
                    Text("0")
                } maximumValueLabel: {
                    Text("80")
                }
                .disabled(!viewModel.canEditSelectedLayerMaskProperties)
                .font(.system(size: 10, weight: .medium).monospacedDigit())
            }
        }
    }

    private var layerActionToolbar: some View {
        HStack(spacing: 6) {
            layerActionButton(systemImage: "plus", helpKey: "imageEditor.action.layerNew") { viewModel.addLayer() }
            layerActionButton(systemImage: "photo.badge.plus", helpKey: "imageEditor.action.layerImport") {
                viewModel.chooseImageLayerFile { canonicalURL in
                    presentFigmaLinkImport(
                        canonicalURL: canonicalURL,
                        placementCenter: viewModel.visibleCanvasCenter
                    )
                }
            }
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
            layerActionButton(
                systemImage: viewModel.document.selectedLayer?.isMaskLinked == false ? "link.slash" : "link",
                helpKey: "imageEditor.action.vectorMaskLinkToggle",
                isSelected: viewModel.document.selectedLayer?.isMaskLinked == false
            ) {
                viewModel.toggleVectorMaskLinked()
            }
            .disabled(!viewModel.canToggleVectorMaskLinked)
            layerActionButton(systemImage: "arrow.triangle.2.circlepath", helpKey: "imageEditor.action.vectorMaskInvert") {
                viewModel.invertVectorMask()
            }
            .disabled(!viewModel.canInvertVectorMask)
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

                layerContextMatchingSelectionMenu(layer)

                layerContextLinksMenu(layer)

                layerContextLockMenu(layer)

                layerContextVisibilityMenu(layer)

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

                layerContextOrderingMenu(layer)

                layerContextTransformMenu(layer)

                layerContextAlignmentMenu(layer)

                layerContextDistributionMenu(layer)

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

                layerContextGroupExpansionButtons(layer)

                layerContextClippingMaskButton(layer)

                layerContextLayerMaskMenu(layer)

                layerContextVectorMaskMenu(layer)

                layerContextSmartObjectMenu(layer)

                Menu(L10n.text("imageEditor.action.layerRasterize")) {
                    ForEach(ImageEditorRasterizeTarget.allCases) { target in
                        Button(L10n.text(target.actionTitleKey)) {
                            viewModel.rasterizeLayersFromContext(layer.id, target: target)
                        }
                        .disabled(!viewModel.canRasterizeLayersFromContext(layer.id, target: target))
                        .accessibilityIdentifier(
                            "image-editor-layer-context-rasterize-\(target.rawValue)-\(layer.id.uuidString)"
                        )
                    }
                }
                .accessibilityIdentifier("image-editor-layer-context-rasterize-\(layer.id.uuidString)")

                layerContextMergeButton(layer)

                layerContextStyleMenu(layer)

                layerContextLabelColorMenu(layer)

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
            if NSEvent.modifierFlags.contains(.option) {
                viewModel.toggleLayerIsolationFromVisibilityEye(layer.id)
            } else {
                viewModel.toggleLayerVisibility(layer.id, applyingToSelection: true)
            }
        } label: {
            Image(systemName: layer.isVisible ? "eye" : "eye.slash")
                .frame(width: 18, height: 22)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(L10n.text("imageEditor.action.layerVisibilityOptionHint"))
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
        reclaimEditorKeyboardFocusAfterLayerSelection()
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

    private func layerContextSmartObjectMenu(_ layer: ImageEditorLayer) -> some View {
        Menu(L10n.text("imageEditor.menu.layer.smartObject")) {
            ForEach(ImageEditorSmartObjectContextAction.allCases) { action in
                Button {
                    viewModel.performSmartObjectActionFromContext(
                        layer.id,
                        action: action
                    )
                } label: {
                    Label(
                        L10n.text(action.actionTitleKey),
                        systemImage: action.systemImage
                    )
                }
                .disabled(!viewModel.canPerformSmartObjectActionFromContext(
                    layer.id,
                    action: action
                ))
                .accessibilityIdentifier(
                    "image-editor-layer-context-smart-object-\(action.rawValue)-\(layer.id.uuidString)"
                )
            }
        }
        .accessibilityIdentifier(
            "image-editor-layer-context-smart-object-\(layer.id.uuidString)"
        )
    }

    private func layerContextLayerMaskMenu(_ layer: ImageEditorLayer) -> some View {
        Menu(L10n.text("imageEditor.menu.layer.mask")) {
            layerContextLayerMaskButtons(
                layer,
                actions: ImageEditorLayerMaskContextAction.creationActions
            )
            Divider()
            layerContextLayerMaskButtons(
                layer,
                actions: ImageEditorLayerMaskContextAction.selectionActions
            )
            Divider()
            layerContextLayerMaskButtons(
                layer,
                actions: ImageEditorLayerMaskContextAction.managementActions
            )
        }
        .accessibilityIdentifier(
            "image-editor-layer-context-mask-\(layer.id.uuidString)"
        )
    }

    @ViewBuilder
    private func layerContextLayerMaskButtons(
        _ layer: ImageEditorLayer,
        actions: [ImageEditorLayerMaskContextAction]
    ) -> some View {
        ForEach(actions) { action in
            Button {
                viewModel.performLayerMaskActionFromContext(
                    layer.id,
                    action: action
                )
            } label: {
                Label(
                    L10n.text(action.actionTitleKey),
                    systemImage: action.systemImage
                )
            }
            .disabled(!viewModel.canPerformLayerMaskActionFromContext(
                layer.id,
                action: action
            ))
            .accessibilityIdentifier(
                "image-editor-layer-context-mask-\(action.rawValue)-\(layer.id.uuidString)"
            )
        }
    }

    private func layerContextVectorMaskMenu(_ layer: ImageEditorLayer) -> some View {
        Menu(L10n.text("imageEditor.menu.layer.vectorMask")) {
            ForEach(ImageEditorVectorMaskContextAction.allCases) { action in
                Button {
                    viewModel.performVectorMaskActionFromContext(
                        layer.id,
                        action: action
                    )
                } label: {
                    Label(
                        L10n.text(action.actionTitleKey),
                        systemImage: action.systemImage
                    )
                }
                .disabled(!viewModel.canPerformVectorMaskActionFromContext(
                    layer.id,
                    action: action
                ))
                .accessibilityIdentifier(
                    "image-editor-layer-context-vector-mask-\(action.rawValue)-\(layer.id.uuidString)"
                )
            }
        }
        .accessibilityIdentifier(
            "image-editor-layer-context-vector-mask-\(layer.id.uuidString)"
        )
    }

    private func layerContextOrderingMenu(_ layer: ImageEditorLayer) -> some View {
        Menu(L10n.text("imageEditor.menu.layer.order")) {
            ForEach(ImageEditorLayerStackContextAction.allCases, id: \.self) { action in
                Button {
                    viewModel.moveLayersFromContext(
                        layer.id,
                        action: action,
                        visibleRowIDs: filteredVisibleLayerRowIDs
                    )
                } label: {
                    Label(
                        L10n.text(action.actionTitleKey),
                        systemImage: action.systemImage
                    )
                }
                .disabled(!viewModel.canMoveLayersFromContext(
                    layer.id,
                    action: action,
                    visibleRowIDs: filteredVisibleLayerRowIDs
                ))
                .accessibilityIdentifier(
                    "image-editor-layer-context-order-\(action.rawValue)-\(layer.id.uuidString)"
                )
            }
        }
        .accessibilityIdentifier(
            "image-editor-layer-context-order-\(layer.id.uuidString)"
        )
    }

    private func layerContextTransformMenu(_ layer: ImageEditorLayer) -> some View {
        Menu(L10n.text("imageEditor.menu.layer.transform")) {
            ForEach(ImageEditorLayerTransformContextAction.directionalActions) { action in
                layerContextTransformButton(layer, action: action)
            }

            Divider()

            ForEach(ImageEditorLayerTransformContextAction.canvasSizingActions) { action in
                layerContextTransformButton(layer, action: action)
            }

            Divider()

            ForEach(ImageEditorLayerTransformContextAction.selectionSizingActions) { action in
                layerContextTransformButton(layer, action: action)
            }

            Divider()

            ForEach(ImageEditorLayerTransformContextAction.pixelContentActions) { action in
                layerContextTransformButton(layer, action: action)
            }
        }
        .accessibilityIdentifier(
            "image-editor-layer-context-transform-\(layer.id.uuidString)"
        )
    }

    private func layerContextTransformButton(
        _ layer: ImageEditorLayer,
        action: ImageEditorLayerTransformContextAction
    ) -> some View {
        Button {
            viewModel.transformLayersFromContext(layer.id, action: action)
        } label: {
            Label(
                L10n.text(action.actionTitleKey),
                systemImage: action.systemImage
            )
        }
        .disabled(!viewModel.canTransformLayersFromContext(
            layer.id,
            action: action
        ))
        .accessibilityIdentifier(
            "image-editor-layer-context-transform-\(action.rawValue)-\(layer.id.uuidString)"
        )
    }

    private func layerContextAlignmentMenu(_ layer: ImageEditorLayer) -> some View {
        Menu(L10n.text("imageEditor.menu.layer.align")) {
            layerContextAlignmentTargetMenu(layer, target: .selectedLayers)
            layerContextAlignmentTargetMenu(layer, target: .canvas)
            layerContextAlignmentTargetMenu(layer, target: .pixelSelection)
        }
        .accessibilityIdentifier(
            "image-editor-layer-context-align-\(layer.id.uuidString)"
        )
    }

    private func layerContextAlignmentTargetMenu(
        _ layer: ImageEditorLayer,
        target: ImageEditorMoveAlignmentTarget
    ) -> some View {
        Menu(target.title) {
            ForEach(ImageEditorLayerAlignment.allCases) { alignment in
                Button {
                    switch target {
                    case .selectedLayers:
                        viewModel.alignLayersFromContextToSelectedLayers(
                            layer.id,
                            alignment: alignment
                        )
                    case .canvas:
                        viewModel.alignLayersFromContextToCanvas(
                            layer.id,
                            alignment: alignment
                        )
                    case .pixelSelection:
                        viewModel.alignLayersFromContextToSelection(
                            layer.id,
                            alignment: alignment
                        )
                    }
                } label: {
                    Label(
                        L10n.text(alignment.actionTitleKey(for: target)),
                        systemImage: alignment.optionBarSystemImage
                    )
                }
                .disabled(!canAlignLayersFromContext(
                    layer.id,
                    alignment: alignment,
                    target: target
                ))
                .accessibilityIdentifier(
                    "image-editor-layer-context-align-\(target.rawValue)-\(alignment.contextIdentifier)-\(layer.id.uuidString)"
                )
            }
        }
        .accessibilityIdentifier(
            "image-editor-layer-context-align-\(target.rawValue)-\(layer.id.uuidString)"
        )
    }

    private func canAlignLayersFromContext(
        _ layerID: UUID,
        alignment: ImageEditorLayerAlignment,
        target: ImageEditorMoveAlignmentTarget
    ) -> Bool {
        switch target {
        case .selectedLayers:
            viewModel.canAlignLayersFromContextToSelectedLayers(
                layerID,
                alignment: alignment
            )
        case .canvas:
            viewModel.canAlignLayersFromContextToCanvas(
                layerID,
                alignment: alignment
            )
        case .pixelSelection:
            viewModel.canAlignLayersFromContextToSelection(
                layerID,
                alignment: alignment
            )
        }
    }

    private func layerContextDistributionMenu(_ layer: ImageEditorLayer) -> some View {
        Menu(L10n.text("imageEditor.menu.layer.distribute")) {
            ForEach(ImageEditorLayerDistribution.allCases) { distribution in
                Button {
                    viewModel.distributeLayersFromContext(
                        layer.id,
                        distribution: distribution
                    )
                } label: {
                    Label(
                        L10n.text(distribution.actionTitleKey),
                        systemImage: distribution.optionBarSystemImage
                    )
                }
                .disabled(!viewModel.canDistributeLayersFromContext(
                    layer.id,
                    distribution: distribution
                ))
                .accessibilityIdentifier(
                    "image-editor-layer-context-distribute-\(distribution.rawValue)-\(layer.id.uuidString)"
                )
            }

            Divider()

            ForEach(ImageEditorLayerSpacingDistribution.allCases) { distribution in
                Button {
                    viewModel.distributeLayerSpacingFromContext(
                        layer.id,
                        distribution: distribution
                    )
                } label: {
                    Label(
                        L10n.text(distribution.actionTitleKey),
                        systemImage: distribution.optionBarSystemImage
                    )
                }
                .disabled(!viewModel.canDistributeLayerSpacingFromContext(
                    layer.id,
                    distribution: distribution
                ))
                .accessibilityIdentifier(
                    "image-editor-layer-context-distribute-spacing-\(distribution.rawValue)-\(layer.id.uuidString)"
                )
            }
        }
        .accessibilityIdentifier(
            "image-editor-layer-context-distribute-\(layer.id.uuidString)"
        )
    }

    @ViewBuilder
    private func layerContextGroupExpansionButtons(_ layer: ImageEditorLayer) -> some View {
        if layer.isGroup {
            Button {
                viewModel.setLayerGroupsExpansionFromContext(
                    layer.id,
                    expanded: true
                )
            } label: {
                Label(
                    L10n.text("imageEditor.action.layerGroupsExpandSelected"),
                    systemImage: "chevron.down.square"
                )
            }
            .disabled(!viewModel.canSetLayerGroupsExpansionFromContext(
                layer.id,
                expanded: true
            ))
            .accessibilityIdentifier(
                "image-editor-layer-context-groups-expand-\(layer.id.uuidString)"
            )

            Button {
                viewModel.setLayerGroupsExpansionFromContext(
                    layer.id,
                    expanded: false
                )
            } label: {
                Label(
                    L10n.text("imageEditor.action.layerGroupsCollapseSelected"),
                    systemImage: "chevron.right.square"
                )
            }
            .disabled(!viewModel.canSetLayerGroupsExpansionFromContext(
                layer.id,
                expanded: false
            ))
            .accessibilityIdentifier(
                "image-editor-layer-context-groups-collapse-\(layer.id.uuidString)"
            )
        }
    }

    private func layerContextMergeButton(_ layer: ImageEditorLayer) -> some View {
        let action = viewModel.layerMergeActionFromContext(layer.id)
        return Button {
            viewModel.applyLayerMergeActionFromContext(layer.id)
        } label: {
            Label(
                L10n.text(viewModel.layerMergeTitleKeyFromContext(layer.id)),
                systemImage: "square.stack.3d.down.right"
            )
        }
        .disabled(action == nil)
        .accessibilityIdentifier("image-editor-layer-context-merge-\(layer.id.uuidString)")
    }

    private func layerContextMatchingSelectionMenu(_ layer: ImageEditorLayer) -> some View {
        Menu(L10n.text("imageEditor.menu.layer.selectAttribute")) {
            Button(L10n.text("imageEditor.action.layerSelectSimilar")) {
                viewModel.selectSimilarLayersFromContext(layer.id)
            }
            .disabled(!viewModel.canSelectSimilarLayersFromContext(layer.id))
            .accessibilityIdentifier("image-editor-layer-context-select-similar-\(layer.id.uuidString)")

            Button(L10n.text("imageEditor.action.layerSelectSameKind")) {
                viewModel.selectLayersWithSameKindFromContext(layer.id)
            }
            .disabled(!viewModel.canSelectLayersWithSameKindFromContext(layer.id))
            .accessibilityIdentifier("image-editor-layer-context-select-same-kind-\(layer.id.uuidString)")

            Button(L10n.text("imageEditor.action.layerSelectSameBlendMode")) {
                viewModel.selectLayersWithSameBlendModeFromContext(layer.id)
            }
            .disabled(!viewModel.canSelectLayersWithSameBlendModeFromContext(layer.id))
            .accessibilityIdentifier("image-editor-layer-context-select-same-blend-\(layer.id.uuidString)")

            Button(L10n.text("imageEditor.action.layerSelectSameLabelColor")) {
                viewModel.selectLayersWithSameLabelColorFromContext(layer.id)
            }
            .disabled(!viewModel.canSelectLayersWithSameLabelColorFromContext(layer.id))
            .accessibilityIdentifier("image-editor-layer-context-select-same-label-\(layer.id.uuidString)")
        }
        .accessibilityIdentifier("image-editor-layer-context-select-attribute-\(layer.id.uuidString)")
    }

    private func layerContextLinksMenu(_ layer: ImageEditorLayer) -> some View {
        Menu(L10n.text("imageEditor.menu.layer.links")) {
            Button(L10n.text("imageEditor.action.layerLink")) {
                viewModel.linkLayersFromContext(layer.id)
            }
            .disabled(!viewModel.canLinkLayersFromContext(layer.id))
            .accessibilityIdentifier("image-editor-layer-context-link-\(layer.id.uuidString)")

            Button(L10n.text("imageEditor.action.layerSelectLinked")) {
                viewModel.selectLinkedLayersFromContext(layer.id)
            }
            .disabled(!viewModel.canSelectLinkedLayersFromContext(layer.id))
            .accessibilityIdentifier("image-editor-layer-context-select-linked-\(layer.id.uuidString)")

            Button(L10n.text("imageEditor.action.layerUnlink")) {
                viewModel.unlinkLayersFromContext(layer.id)
            }
            .disabled(!viewModel.canUnlinkLayersFromContext(layer.id))
            .accessibilityIdentifier("image-editor-layer-context-unlink-\(layer.id.uuidString)")
        }
        .accessibilityIdentifier("image-editor-layer-context-links-\(layer.id.uuidString)")
    }

    private func layerContextLockMenu(_ layer: ImageEditorLayer) -> some View {
        Menu(L10n.text("imageEditor.menu.layer.lock")) {
            layerContextLockButton(
                layer,
                kind: .full,
                isLocked: true,
                titleKey: "imageEditor.action.layerLockSelected",
                systemImage: "lock.fill"
            )
            layerContextLockButton(
                layer,
                kind: .full,
                isLocked: false,
                titleKey: "imageEditor.action.layerUnlockSelected",
                systemImage: "lock.open"
            )
            Divider()
            layerContextLockButton(
                layer,
                kind: .pixels,
                isLocked: true,
                titleKey: "imageEditor.action.layerPixelsLockSelected",
                systemImage: "photo.fill"
            )
            layerContextLockButton(
                layer,
                kind: .pixels,
                isLocked: false,
                titleKey: "imageEditor.action.layerPixelsUnlockSelected",
                systemImage: "photo"
            )
            Divider()
            layerContextLockButton(
                layer,
                kind: .position,
                isLocked: true,
                titleKey: "imageEditor.action.layerPositionLockSelected",
                systemImage: "arrow.up.left.and.arrow.down.right.circle.fill"
            )
            layerContextLockButton(
                layer,
                kind: .position,
                isLocked: false,
                titleKey: "imageEditor.action.layerPositionUnlockSelected",
                systemImage: "arrow.up.left.and.arrow.down.right.circle"
            )
            Divider()
            layerContextLockButton(
                layer,
                kind: .transparentPixels,
                isLocked: true,
                titleKey: "imageEditor.action.layerTransparentPixelsLockSelected",
                systemImage: "square.split.2x2.fill"
            )
            layerContextLockButton(
                layer,
                kind: .transparentPixels,
                isLocked: false,
                titleKey: "imageEditor.action.layerTransparentPixelsUnlockSelected",
                systemImage: "square.split.2x2"
            )
        }
        .accessibilityIdentifier("image-editor-layer-context-locks-\(layer.id.uuidString)")
    }

    private func layerContextLockButton(
        _ layer: ImageEditorLayer,
        kind: ImageEditorLayerLockKind,
        isLocked: Bool,
        titleKey: String,
        systemImage: String
    ) -> some View {
        Button {
            viewModel.setLayersLockFromContext(
                layer.id,
                kind: kind,
                isLocked: isLocked
            )
        } label: {
            Label(L10n.text(titleKey), systemImage: systemImage)
        }
        .disabled(!viewModel.canSetLayersLockFromContext(
            layer.id,
            kind: kind,
            isLocked: isLocked
        ))
        .accessibilityIdentifier(
            "image-editor-layer-context-lock-\(kind.rawValue)-\(isLocked ? "on" : "off")-\(layer.id.uuidString)"
        )
    }

    private func layerContextVisibilityMenu(_ layer: ImageEditorLayer) -> some View {
        Menu(L10n.text("imageEditor.action.layerVisibility")) {
            Button {
                viewModel.setLayersVisibilityFromContext(layer.id, isVisible: true)
            } label: {
                Label(
                    L10n.text("imageEditor.action.layerShowSelected"),
                    systemImage: "eye"
                )
            }
            .disabled(!viewModel.canSetLayersVisibilityFromContext(
                layer.id,
                isVisible: true
            ))
            .accessibilityIdentifier(
                "image-editor-layer-context-visibility-show-\(layer.id.uuidString)"
            )

            Button {
                viewModel.setLayersVisibilityFromContext(layer.id, isVisible: false)
            } label: {
                Label(
                    L10n.text("imageEditor.action.layerHideSelected"),
                    systemImage: "eye.slash"
                )
            }
            .disabled(!viewModel.canSetLayersVisibilityFromContext(
                layer.id,
                isVisible: false
            ))
            .accessibilityIdentifier(
                "image-editor-layer-context-visibility-hide-\(layer.id.uuidString)"
            )

            Divider()

            Button {
                viewModel.isolateLayersFromContext(layer.id)
            } label: {
                Label(
                    L10n.text("imageEditor.action.layerIsolateSelected"),
                    systemImage: "eye.trianglebadge.exclamationmark"
                )
            }
            .disabled(!viewModel.canIsolateLayersFromContext(layer.id))
            .accessibilityIdentifier(
                "image-editor-layer-context-visibility-isolate-\(layer.id.uuidString)"
            )

            Button {
                viewModel.showAllLayersFromContext(layer.id)
            } label: {
                Label(
                    L10n.text("imageEditor.action.layerShowAll"),
                    systemImage: "eye.fill"
                )
            }
            .disabled(!viewModel.canShowAllLayersFromContext(layer.id))
            .accessibilityIdentifier(
                "image-editor-layer-context-visibility-show-all-\(layer.id.uuidString)"
            )
        }
        .accessibilityIdentifier(
            "image-editor-layer-context-visibility-\(layer.id.uuidString)"
        )
    }

    private func layerContextStyleMenu(_ layer: ImageEditorLayer) -> some View {
        Menu(L10n.text("imageEditor.menu.layer.style")) {
            Button(L10n.text("imageEditor.action.layerStyleCopy")) {
                viewModel.copyLayerStyleFromContext(layer.id)
            }
            .disabled(!viewModel.canCopyLayerStyleFromContext(layer.id))
            .accessibilityIdentifier("image-editor-layer-context-style-copy-\(layer.id.uuidString)")

            Button(L10n.text("imageEditor.action.layerStylePaste")) {
                viewModel.pasteLayerStyleFromContext(layer.id)
            }
            .disabled(!viewModel.canPasteLayerStyleFromContext(layer.id))
            .accessibilityIdentifier("image-editor-layer-context-style-paste-\(layer.id.uuidString)")

            Divider()

            Button(L10n.text("imageEditor.action.layerStyleClear")) {
                viewModel.clearLayerStylesFromContext(layer.id)
            }
            .disabled(!viewModel.canClearLayerStylesFromContext(layer.id))
            .accessibilityIdentifier("image-editor-layer-context-style-clear-\(layer.id.uuidString)")
        }
        .accessibilityIdentifier("image-editor-layer-context-style-\(layer.id.uuidString)")
    }

    private func layerContextLabelColorMenu(_ layer: ImageEditorLayer) -> some View {
        Menu(L10n.text("imageEditor.action.layerLabelColor")) {
            Button {
                viewModel.setLayersLabelColorFromContext(layer.id, labelColor: nil)
            } label: {
                Label(
                    L10n.text("imageEditor.action.layerLabelNone"),
                    systemImage: viewModel.layersFromContextHaveLabelColor(
                        layer.id,
                        labelColor: nil
                    ) ? "checkmark" : "tag.slash"
                )
            }
            .disabled(!viewModel.canSetLayersLabelColorFromContext(layer.id, labelColor: nil))
            .accessibilityIdentifier(
                "image-editor-layer-context-label-none-\(layer.id.uuidString)"
            )

            Divider()

            ForEach(ImageEditorLayerLabelColor.allCases) { labelColor in
                Button {
                    viewModel.setLayersLabelColorFromContext(layer.id, labelColor: labelColor)
                } label: {
                    Label(
                        labelColor.title,
                        systemImage: viewModel.layersFromContextHaveLabelColor(
                            layer.id,
                            labelColor: labelColor
                        ) ? "checkmark" : "tag.fill"
                    )
                }
                .disabled(
                    !viewModel.canSetLayersLabelColorFromContext(
                        layer.id,
                        labelColor: labelColor
                    )
                )
                .accessibilityIdentifier(
                    "image-editor-layer-context-label-\(labelColor.rawValue)-\(layer.id.uuidString)"
                )
            }
        }
        .accessibilityIdentifier("image-editor-layer-context-label-\(layer.id.uuidString)")
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
