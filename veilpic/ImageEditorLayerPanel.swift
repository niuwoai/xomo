//
//  ImageEditorLayerPanel.swift
//  veilpic
//
//  Created by Codex on 2026/7/9.
//

import AppKit
import SwiftUI

extension ImageEditorView {
    var layersPanel: some View {
        EditorPanel(title: L10n.text("imageEditor.panel.layersChannels")) {
            VStack(spacing: 8) {
                layerPanelTabs
                if selectedLayerPanelTab == .layers {
                    layerOpacityControls
                    layerMaskControls
                    layerActionToolbar
                    layerSearchField
                    layerKindFilterBar
                    selectedLayerCountLabel
                    layerRows
                } else if selectedLayerPanelTab == .channels {
                    channelsPanelContent
                } else {
                    layerCompsPanelContent
                }
            }
        }
        .frame(height: 348)
    }

    private var layerPanelTabs: some View {
        Picker("", selection: $selectedLayerPanelTab) {
            ForEach(ImageEditorLayerPanelTab.allCases) { tab in
                Text(tab.title).tag(tab)
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
    }

    private var channelsPanelContent: some View {
        VStack(spacing: 8) {
            Text(L10n.format("imageEditor.channel.previewing", viewModel.channelPreviewTitle))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                .frame(maxWidth: .infinity, alignment: .leading)

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
        let isSelected = viewModel.previewedAlphaChannel == nil && viewModel.selectedChannelPreview == channel
        return HStack(spacing: 6) {
            Button {
                viewModel.selectChannelPreview(channel)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isSelected ? "eye.fill" : "eye")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 18)
                        .foregroundStyle(Color(nsColor: isSelected ? ImageEditorTheme.selected : ImageEditorTheme.mutedText))

                    Image(nsImage: viewModel.channelPreviewImage(for: channel))
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
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isSelected ? Color(nsColor: ImageEditorTheme.selected).opacity(0.28) : Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
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
            .onChange(of: channel.name) { _, _ in
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
                .lineLimit(1)
                .onSubmit {
                    commitLayerCompNameDraft(comp)
                }
                .onAppear {
                    syncLayerCompNameDraft(comp)
                }
                .onChange(of: comp.name) { _, _ in
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
                if !editing {
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
                if !editing {
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
                if !editing {
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
                if !editing {
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
                if !editing {
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
                if !editing {
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
                    if !editing {
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
                    if !editing {
                        viewModel.commitSelectedLayerMaskFeatherChange()
                    }
                }
                .disabled(!viewModel.canEditSelectedLayerMaskProperties)
                .font(.system(size: 10, weight: .medium).monospacedDigit())
            }
        }
    }

    private var layerActionToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                layerActionButton(systemImage: "plus", helpKey: "imageEditor.action.layerNew") { viewModel.addLayer() }
                layerActionButton(systemImage: "photo.badge.plus", helpKey: "imageEditor.action.layerImport") { viewModel.chooseImageLayerFile() }
                layerActionButton(systemImage: "cube", helpKey: "imageEditor.action.layerSmartObject") { viewModel.convertSelectedLayerToSmartObject() }
                    .disabled(!viewModel.canConvertSelectedLayerToSmartObject)
                layerActionButton(systemImage: "arrow.triangle.2.circlepath", helpKey: "imageEditor.action.layerSmartObjectReplace") { viewModel.chooseSmartObjectReplacementFile() }
                    .disabled(!viewModel.canReplaceSelectedSmartObjectContents)
                layerActionButton(systemImage: "link.slash", helpKey: "imageEditor.action.layerSmartObjectMakeUnique") { viewModel.makeSelectedSmartObjectUnique() }
                    .disabled(!viewModel.canMakeSelectedSmartObjectUnique)
                layerActionButton(systemImage: "arrow.counterclockwise", helpKey: "imageEditor.action.layerSmartObjectResetTransform") { viewModel.resetSelectedSmartObjectTransform() }
                    .disabled(!viewModel.canResetSelectedSmartObjectTransform)
                layerActionButton(systemImage: "square.grid.3x3.fill", helpKey: "imageEditor.action.layerRasterize") { viewModel.rasterizeSelectedLayer() }
                    .disabled(!viewModel.canRasterizeSelectedLayer)
                layerActionButton(systemImage: "folder.badge.plus", helpKey: "imageEditor.action.layerGroupNew") { viewModel.addLayerGroup() }
                layerActionButton(systemImage: "rectangle.stack.badge.plus", helpKey: "imageEditor.action.layerGroupSelected") { viewModel.groupSelectedLayer() }
                    .disabled(!viewModel.canGroupSelectedLayer)
                layerActionButton(systemImage: "list.bullet.indent", helpKey: "imageEditor.action.layerSelectGroupMembers") { viewModel.selectSelectedGroupMembers() }
                    .disabled(!viewModel.canSelectSelectedGroupMembers)
                layerLabelColorMenu
                layerActionButton(systemImage: "increase.indent", helpKey: "imageEditor.action.layerMoveIntoGroup") { viewModel.moveSelectedLayersIntoGroup() }
                    .disabled(!viewModel.canMoveSelectedLayersIntoGroup)
                layerActionButton(systemImage: "decrease.indent", helpKey: "imageEditor.action.layerMoveOutOfGroup") { viewModel.moveSelectedLayersOutOfGroup() }
                    .disabled(!viewModel.canMoveSelectedLayersOutOfGroup)
                layerActionButton(systemImage: "folder.badge.minus", helpKey: "imageEditor.action.layerUngroup") { viewModel.ungroupSelectedLayers() }
                    .disabled(!viewModel.canUngroupSelectedLayers)
                layerActionButton(systemImage: "checklist", helpKey: "imageEditor.action.layerSelectAll") { viewModel.selectAllLayers() }
                    .disabled(!viewModel.canSelectAllLayers)
                layerActionButton(systemImage: "arrow.triangle.2.circlepath", helpKey: "imageEditor.action.layerSelectionInvert") { viewModel.invertLayerSelection() }
                    .disabled(!viewModel.canInvertLayerSelection)
                layerActionButton(systemImage: "xmark.square", helpKey: "imageEditor.action.layerSelectionClear") { viewModel.clearLayerSelection() }
                    .disabled(!viewModel.canClearLayerSelection)
                layerActionButton(systemImage: "doc.on.doc", helpKey: "imageEditor.action.layerDuplicate") { viewModel.duplicateSelectedLayer() }
                layerActionButton(systemImage: "eye.circle", helpKey: "imageEditor.action.layerIsolateSelected") { viewModel.isolateSelectedLayers() }
                    .disabled(!viewModel.canIsolateSelectedLayers)
                layerActionButton(systemImage: "eye", helpKey: "imageEditor.action.layerShowAll") { viewModel.showAllLayers() }
                    .disabled(!viewModel.canShowAllLayers)
                layerActionButton(systemImage: "link", helpKey: "imageEditor.action.layerLink") { viewModel.linkSelectedLayers() }
                    .disabled(!viewModel.canLinkSelectedLayers)
                layerActionButton(systemImage: "link.circle", helpKey: "imageEditor.action.layerSelectLinked") { viewModel.selectLinkedLayers() }
                    .disabled(!viewModel.canSelectLinkedLayers)
                layerActionButton(systemImage: "link.slash", helpKey: "imageEditor.action.layerUnlink") { viewModel.unlinkSelectedLayers() }
                    .disabled(!viewModel.canUnlinkSelectedLayers)
                layerActionButton(systemImage: "xmark.circle", helpKey: "imageEditor.action.layerUnlinkAll") { viewModel.unlinkAllLayers() }
                    .disabled(!viewModel.canUnlinkAllLayers)
                layerAlignmentButtons
                layerOrderingButtons
                layerMaskActionButtons
                layerEffectButtons
            }
        }
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
        }
    }

    private var layerOrderingButtons: some View {
        Group {
            layerActionButton(systemImage: "trash", helpKey: "imageEditor.action.layerDelete") { viewModel.deleteSelectedLayer() }
                .disabled(!viewModel.canDeleteLayer)
            layerActionButton(systemImage: "arrow.up.to.line", helpKey: "imageEditor.action.layerTop") { viewModel.moveSelectedLayerToTop() }
                .disabled(!viewModel.canMoveSelectedLayerToTop)
            layerActionButton(systemImage: "arrow.up", helpKey: "imageEditor.action.layerUp") { viewModel.moveSelectedLayerUp() }
                .disabled(!viewModel.canMoveSelectedLayerUp)
            layerActionButton(systemImage: "arrow.down", helpKey: "imageEditor.action.layerDown") { viewModel.moveSelectedLayerDown() }
                .disabled(!viewModel.canMoveSelectedLayerDown)
            layerActionButton(systemImage: "arrow.down.to.line", helpKey: "imageEditor.action.layerBottom") { viewModel.moveSelectedLayerToBottom() }
                .disabled(!viewModel.canMoveSelectedLayerToBottom)
            layerActionButton(systemImage: "square.stack.3d.down.right", helpKey: "imageEditor.action.layerMergeDown") { viewModel.mergeSelectedLayerDown() }
                .disabled(!viewModel.canMergeSelectedLayerDown)
            layerActionButton(systemImage: "square.stack.3d.down.right.fill", helpKey: "imageEditor.action.layerMergeSelected") { viewModel.mergeSelectedLayers() }
                .disabled(!viewModel.canMergeSelectedLayers)
            layerActionButton(systemImage: "square.stack.3d.down.right.fill", helpKey: "imageEditor.action.layerMergeVisible") { viewModel.mergeVisibleLayers() }
                .disabled(!viewModel.canMergeVisibleLayers)
            layerActionButton(systemImage: "square.stack.3d.up.fill", helpKey: "imageEditor.action.layerStampVisible") { viewModel.stampVisibleLayers() }
                .disabled(!viewModel.canStampVisibleLayers)
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
            layerActionButton(systemImage: "square.grid.3x3", helpKey: "imageEditor.action.vectorMaskRasterize") { viewModel.rasterizeSelectedVectorMask() }
                .disabled(!viewModel.canRasterizeSelectedVectorMask)
            layerActionButton(systemImage: "xmark.square.fill", helpKey: "imageEditor.action.vectorMaskDelete") { viewModel.deleteVectorMask() }
                .disabled(!viewModel.canDeleteVectorMask)
        }
    }

    private var layerEffectButtons: some View {
        Group {
            layerActionButton(systemImage: "f.cursive", helpKey: "imageEditor.action.layerStroke", isSelected: viewModel.selectedLayerHasStroke) { viewModel.toggleSelectedLayerStroke() }
            layerActionButton(systemImage: "sparkles", helpKey: "imageEditor.action.layerShadow", isSelected: viewModel.selectedLayerHasShadow) { viewModel.toggleSelectedLayerShadow() }
            layerActionButton(systemImage: "circle.righthalf.filled", helpKey: "imageEditor.action.layerInnerShadow", isSelected: viewModel.selectedLayerHasInnerShadow) { viewModel.toggleSelectedLayerInnerShadow() }
            layerActionButton(systemImage: "sun.max", helpKey: "imageEditor.action.layerOuterGlow", isSelected: viewModel.selectedLayerHasOuterGlow) { viewModel.toggleSelectedLayerOuterGlow() }
            layerActionButton(systemImage: "circle.circle", helpKey: "imageEditor.action.layerInnerGlow", isSelected: viewModel.selectedLayerHasInnerGlow) { viewModel.toggleSelectedLayerInnerGlow() }
            layerActionButton(systemImage: "circle.lefthalf.filled", helpKey: "imageEditor.action.layerColorOverlay", isSelected: viewModel.selectedLayerHasColorOverlay) { viewModel.toggleSelectedLayerColorOverlay() }
            layerActionButton(systemImage: "square.lefthalf.filled", helpKey: "imageEditor.action.layerGradientOverlay", isSelected: viewModel.selectedLayerHasGradientOverlay) { viewModel.toggleSelectedLayerGradientOverlay() }
            layerActionButton(systemImage: "checkerboard.rectangle", helpKey: "imageEditor.action.layerPatternOverlay", isSelected: viewModel.selectedLayerHasPatternOverlay) { viewModel.toggleSelectedLayerPatternOverlay() }
            layerActionButton(systemImage: "circle.dotted", helpKey: "imageEditor.action.layerSatin", isSelected: viewModel.selectedLayerHasSatin) { viewModel.toggleSelectedLayerSatin() }
            layerActionButton(systemImage: "cube.transparent", helpKey: "imageEditor.action.layerBevel", isSelected: viewModel.selectedLayerHasBevel) { viewModel.toggleSelectedLayerBevel() }
            layerActionButton(systemImage: "arrow.down.to.line.compact", helpKey: "imageEditor.action.layerClippingMask", isSelected: viewModel.selectedLayerIsClippingMask) {
                viewModel.toggleSelectedLayerClippingMask()
            }
            .disabled(!viewModel.canToggleSelectedLayerClippingMask)
        }
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

    private var filteredVisibleLayerRows: [ImageEditorLayer] {
        viewModel.visibleLayerRows(
            matching: layerSearchQuery,
            kindFilter: selectedLayerKindFilter,
            labelFilter: selectedLayerLabelFilter,
            stateFilter: selectedLayerStateFilter,
            attributeFilter: selectedLayerAttributeFilter
        )
    }

    private var layerSearchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))

            TextField(L10n.text("imageEditor.layer.searchPlaceholder"), text: $layerSearchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 11, weight: .medium))

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

            HStack(spacing: 8) {
                if indentation > 0 {
                    Spacer().frame(width: indentation)
                }
                layerGroupDisclosure(layer)
                layerVisibilityButton(layer)
                layerContentButton(layer)
                layerLockButton(layer)
            }
            .padding(8)
            .background(layerRowBackground(layer))
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .draggable(layer.id.uuidString)
            .dropDestination(for: String.self) { items, _ in
                guard layer.isGroup else { return false }
                return handleLayerDrop(items, on: layer, placement: .insideGroup)
            } isTargeted: { isTargeted in
                targetedLayerDropTarget = isTargeted && layer.isGroup
                    ? ImageEditorLayerDropTarget(layerID: layer.id, placement: .insideGroup)
                    : nil
            }
            .help(layer.isGroup ? L10n.text("imageEditor.action.layerDropInsideGroup") : L10n.text("imageEditor.action.layerDragReorder"))

            layerDropBand(layer, placement: .below)
        }
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
            .dropDestination(for: String.self) { items, _ in
                handleLayerDrop(items, on: layer, placement: placement)
            } isTargeted: { isTargeted in
                targetedLayerDropTarget = isTargeted ? target : nil
            }
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
                viewModel.toggleLayerGroupExpansion(layer.id)
            } label: {
                Image(systemName: layer.isGroupExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 14, height: 22)
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
            }
            .buttonStyle(.plain)
            .help(L10n.text(layer.isGroupExpanded ? "imageEditor.action.layerGroupCollapse" : "imageEditor.action.layerGroupExpand"))
        } else {
            Spacer().frame(width: 14)
        }
    }

    private func layerVisibilityButton(_ layer: ImageEditorLayer) -> some View {
        Button {
            viewModel.toggleLayerVisibility(layer.id)
        } label: {
            Image(systemName: layer.isVisible ? "eye" : "eye.slash")
                .frame(width: 18, height: 22)
        }
        .buttonStyle(.plain)
        .help(L10n.text("imageEditor.action.layerVisibility"))
    }

    private func layerContentButton(_ layer: ImageEditorLayer) -> some View {
        HStack(spacing: 8) {
            layerLabelColorSwatch(layer)
            layerThumbnail(layer)
            layerRasterMaskThumbnail(layer)
            layerVectorMaskThumbnail(layer)
            TextField(
                L10n.text("imageEditor.properties.layerNamePlaceholder"),
                text: layerNameBinding(layer)
            )
            .textFieldStyle(.plain)
            .font(.system(size: 12, weight: .semibold))
            .lineLimit(1)
            .onSubmit {
                commitLayerNameDraft(layer)
            }
            .onAppear {
                syncLayerNameDraft(layer)
            }
            .onChange(of: layer.name) { _, _ in
                syncLayerNameDraft(layer)
            }
            Spacer()
            layerBadges(layer)
            layerLockToggles(layer)
            Text("\(Int((layer.opacity * 100).rounded()))%")
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
        }
        .contentShape(Rectangle())
        .onTapGesture {
            let flags = NSEvent.modifierFlags
            viewModel.selectLayer(
                layer.id,
                editingMask: false,
                extendingSelection: flags.contains(.command) || flags.contains(.shift)
            )
        }
    }

    private func layerNameBinding(_ layer: ImageEditorLayer) -> Binding<String> {
        Binding {
            layerNameDrafts[layer.id] ?? layer.name
        } set: { value in
            layerNameDrafts[layer.id] = value
        }
    }

    private func syncLayerNameDraft(_ layer: ImageEditorLayer) {
        layerNameDrafts[layer.id] = layer.name
    }

    private func commitLayerNameDraft(_ layer: ImageEditorLayer) {
        guard let proposedName = layerNameDrafts[layer.id] else { return }
        viewModel.selectLayer(layer.id)
        viewModel.renameSelectedLayer(to: proposedName)
        layerNameDrafts[layer.id] = viewModel.document.layers.first { $0.id == layer.id }?.name ?? layer.name
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
        Image(nsImage: layer.thumbnail())
            .resizable()
            .scaledToFill()
            .frame(width: 34, height: 26)
            .clipped()
            .background(Color.white.opacity(0.18))
            .overlay(Rectangle().stroke(contentThumbnailStroke(for: layer), lineWidth: 1.4))
    }

    @ViewBuilder
    private func layerRasterMaskThumbnail(_ layer: ImageEditorLayer) -> some View {
        if let maskThumbnail = layer.maskThumbnail() {
            Image(systemName: layer.isMaskLinked ? "link" : "link.slash")
                .font(.system(size: 9, weight: .bold))
                .frame(width: 12, height: 24)
                .foregroundStyle(layer.isMaskLinked ? Color(nsColor: ImageEditorTheme.mutedText) : Color(nsColor: ImageEditorTheme.selected))
                .help(L10n.text(layer.isMaskLinked ? "imageEditor.action.layerMaskLinked" : "imageEditor.action.layerMaskUnlinked"))
            Button {
                viewModel.selectLayer(layer.id, editingMask: true)
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
            .help(L10n.text("imageEditor.action.layerMaskEdit"))
        }
    }

    @ViewBuilder
    private func layerVectorMaskThumbnail(_ layer: ImageEditorLayer) -> some View {
        if let vectorMaskThumbnail = layer.vectorMaskThumbnail() {
            Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                .font(.system(size: 9, weight: .bold))
                .frame(width: 12, height: 24)
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                .help(L10n.text("imageEditor.layer.vectorMaskBadge"))
            Button {
                viewModel.selectLayer(layer.id, editingMask: false)
                viewModel.editSelectedVectorMaskAsPath()
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
            .help(L10n.text("imageEditor.action.vectorMaskSelect"))
        }
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
                viewModel.toggleLayerPixelsLock(layer.id)
            }
            layerSmallToggle(
                systemImage: layer.locksPosition ? "arrow.up.left.and.arrow.down.right.circle.fill" : "arrow.up.left.and.arrow.down.right.circle",
                helpKey: layer.locksPosition ? "imageEditor.action.layerPositionUnlock" : "imageEditor.action.layerPositionLock",
                isEnabled: canTogglePositionLock(for: layer)
            ) {
                viewModel.toggleLayerPositionLock(layer.id)
            }
            layerSmallToggle(
                systemImage: layer.locksTransparentPixels ? "square.split.2x2.fill" : "square.split.2x2",
                helpKey: layer.locksTransparentPixels ? "imageEditor.action.layerTransparentUnlock" : "imageEditor.action.layerTransparentLock",
                isEnabled: canToggleTransparentPixelsLock(for: layer)
            ) {
                viewModel.toggleLayerTransparentPixelsLock(layer.id)
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
            viewModel.toggleLayerLock(layer.id)
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
