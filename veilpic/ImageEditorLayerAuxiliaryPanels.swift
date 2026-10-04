import AppKit
import SwiftUI
import UniformTypeIdentifiers

extension ImageEditorView {
    var channelsPanelContent: some View {
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

    var layerCompsPanelContent: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Button {
                    viewModel.addLayerComp(captureOptions: layerCompCreationOptions)
                } label: {
                    Label(
                        L10n.text("imageEditor.action.layerCompNew"),
                        systemImage: "rectangle.stack.badge.plus"
                    )
                    .font(.system(size: 11, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .help(L10n.text("imageEditor.action.layerCompNew"))

                Menu {
                    Toggle(
                        L10n.text("imageEditor.action.layerCompCaptureVisibility"),
                        isOn: $defaultLayerCompCapturesVisibility
                    )
                    Toggle(
                        L10n.text("imageEditor.action.layerCompCapturePosition"),
                        isOn: $defaultLayerCompCapturesPosition
                    )
                    Toggle(
                        L10n.text("imageEditor.action.layerCompCaptureAppearance"),
                        isOn: $defaultLayerCompCapturesAppearance
                    )
                    Divider()
                    Button(L10n.text("imageEditor.action.layerCompClearAllWarnings")) {
                        _ = viewModel.clearAllLayerCompWarnings()
                    }
                    .disabled(!viewModel.canClearAllLayerCompWarnings)
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .menuStyle(.borderlessButton)
                .help(L10n.text("imageEditor.action.layerCompCreationOptions"))
                .accessibilityIdentifier("image-editor-layer-comp-creation-options")
            }

            Button {
                _ = viewModel.restoreLastDocumentLayerCompState()
            } label: {
                Label(
                    L10n.text("imageEditor.layerComp.lastDocumentState"),
                    systemImage: "clock.arrow.circlepath"
                )
                .font(.system(size: 11, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .disabled(!viewModel.canRestoreLastDocumentLayerCompState)
            .help(L10n.text("imageEditor.action.layerCompRestoreLastDocumentState"))
            .accessibilityIdentifier("image-editor-layer-comp-last-document-state")

            layerCompSearchField

            if hasLayerCompSearchQuery, !viewModel.document.layerComps.isEmpty {
                Text(L10n.format(
                    "imageEditor.layerComp.searchResultsCount",
                    filteredLayerComps.count,
                    viewModel.document.layerComps.count
                ))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("image-editor-layer-comp-search-results-count")
            }

            if viewModel.document.layerComps.isEmpty {
                Text(L10n.text("imageEditor.layerComp.empty"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if filteredLayerComps.isEmpty {
                Text(L10n.text("imageEditor.layerComp.noSearchResults"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 5) {
                            ForEach(filteredLayerComps) { comp in
                                layerCompDraggableRow(comp)
                                    .id(comp.id)
                            }
                        }
                    }
                    .onChange(of: viewModel.document.selectedLayerCompID) { selectedID in
                        guard let selectedID,
                              filteredLayerComps.contains(where: { $0.id == selectedID })
                        else { return }
                        proxy.scrollTo(selectedID, anchor: .center)
                    }
                }
            }

            HStack(spacing: 6) {
                layerCompIconButton(
                    "chevron.left",
                    "imageEditor.action.layerCompPrevious"
                ) {
                    viewModel.applyPreviousLayerComp(
                        matching: layerCompSearchQuery,
                        scope: layerCompSearchScope,
                        favoritesOnly: showsFavoriteLayerCompsOnly
                    )
                }
                .disabled(viewModel.layerCompNavigationTarget(
                    .previous,
                    matching: layerCompSearchQuery,
                    scope: layerCompSearchScope,
                    favoritesOnly: showsFavoriteLayerCompsOnly
                ) == nil)
                .accessibilityIdentifier("image-editor-layer-comp-previous")

                layerCompIconButton(
                    "chevron.right",
                    "imageEditor.action.layerCompNext"
                ) {
                    viewModel.applyNextLayerComp(
                        matching: layerCompSearchQuery,
                        scope: layerCompSearchScope,
                        favoritesOnly: showsFavoriteLayerCompsOnly
                    )
                }
                .disabled(viewModel.layerCompNavigationTarget(
                    .next,
                    matching: layerCompSearchQuery,
                    scope: layerCompSearchScope,
                    favoritesOnly: showsFavoriteLayerCompsOnly
                ) == nil)
                .accessibilityIdentifier("image-editor-layer-comp-next")

                Spacer()
            }

            Text(L10n.text("imageEditor.layerComp.hint"))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var layerCompCreationOptions: ImageEditorLayerCompCaptureOptions {
        ImageEditorLayerCompCaptureOptions(
            capturesVisibility: defaultLayerCompCapturesVisibility,
            capturesPosition: defaultLayerCompCapturesPosition,
            capturesAppearance: defaultLayerCompCapturesAppearance
        )
    }

    private var filteredLayerComps: [ImageEditorLayerComp] {
        ImageEditorLayerCompSearch.filtered(
            viewModel.document.layerComps,
            matching: layerCompSearchQuery,
            scope: layerCompSearchScope,
            favoritesOnly: showsFavoriteLayerCompsOnly
        )
    }

    private var hasLayerCompSearchQuery: Bool {
        ImageEditorLayerCompSearch.hasTerms(layerCompSearchQuery)
            || showsFavoriteLayerCompsOnly
    }

    private var layerCompSearchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))

            ImageEditorLayerSearchField(
                placeholder: L10n.text("imageEditor.layerComp.searchPlaceholder"),
                text: $layerCompSearchQuery,
                identifier: "image-editor-layer-comp-search-field",
                onSubmit: {
                    _ = viewModel.applyPreferredLayerCompSearchResult(
                        matching: layerCompSearchQuery,
                        scope: layerCompSearchScope,
                        favoritesOnly: showsFavoriteLayerCompsOnly
                    )
                },
                onCancel: layerCompSearchQuery.isEmpty ? nil : {
                    layerCompSearchQuery = ""
                },
                onMovePrevious: {
                    _ = viewModel.selectAdjacentLayerCompSearchResult(
                        .previous,
                        matching: layerCompSearchQuery,
                        scope: layerCompSearchScope,
                        favoritesOnly: showsFavoriteLayerCompsOnly
                    )
                },
                onMoveNext: {
                    _ = viewModel.selectAdjacentLayerCompSearchResult(
                        .next,
                        matching: layerCompSearchQuery,
                        scope: layerCompSearchScope,
                        favoritesOnly: showsFavoriteLayerCompsOnly
                    )
                }
            )
            .frame(minHeight: 16)
            .help(L10n.text("imageEditor.layerComp.searchSyntaxHelp"))

            Menu {
                ForEach(ImageEditorLayerCompSearchScope.allCases, id: \.self) { scope in
                    Button {
                        layerCompSearchScope = scope
                    } label: {
                        Label(
                            L10n.text(layerCompSearchScopeLabelKey(scope)),
                            systemImage: layerCompSearchScope == scope ? "checkmark" : "circle"
                        )
                    }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 18, height: 18)
                    .foregroundStyle(layerCompSearchScope == .all
                        ? Color(nsColor: ImageEditorTheme.mutedText)
                        : Color.accentColor)
            }
            .menuStyle(.borderlessButton)
            .help(L10n.text("imageEditor.layerComp.searchScopeHelp"))
            .accessibilityIdentifier("image-editor-layer-comp-search-scope")

            Button {
                showsFavoriteLayerCompsOnly.toggle()
            } label: {
                Image(systemName: showsFavoriteLayerCompsOnly ? "star.fill" : "star")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 18, height: 18)
                    .foregroundStyle(showsFavoriteLayerCompsOnly
                        ? Color.accentColor
                        : Color(nsColor: ImageEditorTheme.mutedText))
            }
            .buttonStyle(.plain)
            .help(L10n.text("imageEditor.action.layerCompFavoritesOnly"))
            .accessibilityIdentifier("image-editor-layer-comp-favorites-only")

            if !layerCompSearchQuery.isEmpty {
                Button {
                    layerCompSearchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .help(L10n.text("imageEditor.action.layerCompSearchClear"))
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
        .accessibilityIdentifier("image-editor-layer-comp-search")
    }

    private func layerCompSearchScopeLabelKey(
        _ scope: ImageEditorLayerCompSearchScope
    ) -> String {
        switch scope {
        case .all:
            return "imageEditor.layerComp.searchScope.all"
        case .name:
            return "imageEditor.layerComp.searchScope.name"
        case .comment:
            return "imageEditor.layerComp.searchScope.comment"
        }
    }

    private func layerCompDraggableRow(_ comp: ImageEditorLayerComp) -> some View {
        VStack(spacing: 2) {
            layerCompDropBand(comp, placement: .above)
            layerCompRow(comp)
                .onDrag {
                    viewModel.selectLayerComp(comp.id)
                    syncLayerCompNameDraft(comp)
                    syncLayerCompCommentDraft(comp)
                    let operation: ImageEditorLayerCompDragOperation = NSEvent.modifierFlags
                        .contains(.option) ? .copy : .move
                    let payload = ImageEditorLayerCompDragPayload(
                        layerCompID: comp.id,
                        operation: operation
                    )
                    return NSItemProvider(object: payload.serialized as NSString)
                }
                .help(L10n.text("imageEditor.action.layerCompDragReorderOrCopy"))
            layerCompDropBand(comp, placement: .below)
        }
    }

    private func layerCompRow(_ comp: ImageEditorLayerComp) -> some View {
        let isSelected = viewModel.document.selectedLayerCompID == comp.id
        let isApplied = viewModel.isLayerCompApplied(comp.id)
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

            Button {
                _ = viewModel.setLayerCompFavorite(comp.id, isFavorite: !comp.isFavorite)
            } label: {
                Image(systemName: comp.isFavorite ? "star.fill" : "star")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 16)
                    .foregroundStyle(comp.isFavorite
                        ? Color.yellow
                        : Color(nsColor: ImageEditorTheme.mutedText))
            }
            .buttonStyle(.plain)
            .help(L10n.text(
                comp.isFavorite
                    ? "imageEditor.action.layerCompRemoveFavorite"
                    : "imageEditor.action.layerCompAddFavorite"
            ))
            .accessibilityIdentifier("image-editor-layer-comp-favorite-\(comp.id.uuidString)")

            if isApplied {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 16)
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.selected))
                    .help(L10n.text("imageEditor.layerComp.currentlyApplied"))
                    .accessibilityIdentifier("image-editor-layer-comp-applied-\(comp.id.uuidString)")
            }

            if viewModel.layerCompHasWarning(comp) {
                Button {
                    viewModel.showLayerCompWarning(comp.id)
                } label: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 18)
                        .foregroundStyle(Color.yellow)
                }
                .buttonStyle(.plain)
                .help(L10n.text("imageEditor.layerComp.missingLayerWarning"))
                .accessibilityIdentifier("image-editor-layer-comp-warning-\(comp.id.uuidString)")
            }

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

                HStack(spacing: 4) {
                    Text(viewModel.layerCompSummary(comp))
                        .lineLimit(1)
                    if !comp.capturesVisibility {
                        Image(systemName: "eye.slash")
                            .help(L10n.text("imageEditor.layerComp.visibilityNotCaptured"))
                    }
                    if !comp.capturesPosition {
                        Image(systemName: "move.3d")
                            .help(L10n.text("imageEditor.layerComp.positionNotCaptured"))
                    }
                    if !comp.capturesAppearance {
                        Image(systemName: "paintbrush.pointed")
                            .help(L10n.text("imageEditor.layerComp.appearanceNotCaptured"))
                    }
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))

                TextField(
                    L10n.text("imageEditor.layerComp.commentPlaceholder"),
                    text: layerCompCommentBinding(comp)
                )
                .textFieldStyle(.plain)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                .lineLimit(1)
                .onSubmit {
                    commitLayerCompCommentDraft(comp)
                }
                .onAppear {
                    syncLayerCompCommentDraft(comp)
                }
                .onChange(of: comp.comment) { _ in
                    syncLayerCompCommentDraft(comp)
                }
                .accessibilityIdentifier("image-editor-layer-comp-comment-\(comp.id.uuidString)")
            }

            Spacer()

            layerCompIconButton("play.fill", "imageEditor.action.layerCompApply") {
                viewModel.applyLayerComp(comp.id)
            }
            .disabled(isApplied)
            .help(viewModel.layerCompApplyHelp(for: comp.id))
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
        .contextMenu {
            layerCompContextMenu(comp)
        }
    }

    @ViewBuilder
    private func layerCompContextMenu(_ comp: ImageEditorLayerComp) -> some View {
        let isApplied = viewModel.isLayerCompApplied(comp.id)
        Button {
            viewModel.applyLayerComp(comp.id)
        } label: {
            Label(L10n.text("imageEditor.action.layerCompApply"), systemImage: "play.fill")
        }
        .disabled(isApplied)
        .help(viewModel.layerCompApplyHelp(for: comp.id))
        Button {
            viewModel.updateLayerComp(comp.id)
        } label: {
            Label(
                L10n.text("imageEditor.action.layerCompUpdate"),
                systemImage: "arrow.triangle.2.circlepath"
            )
        }
        if viewModel.layerCompHasWarning(comp) {
            Button {
                _ = viewModel.clearLayerCompWarning(comp.id)
            } label: {
                Label(
                    L10n.text("imageEditor.action.layerCompClearWarning"),
                    systemImage: "exclamationmark.triangle"
                )
            }
            Button {
                _ = viewModel.clearAllLayerCompWarnings()
            } label: {
                Label(
                    L10n.text("imageEditor.action.layerCompClearAllWarnings"),
                    systemImage: "checkmark.circle"
                )
            }
            .disabled(!viewModel.canClearAllLayerCompWarnings)
        }
        Button {
            _ = viewModel.duplicateLayerComp(comp.id)
        } label: {
            Label(L10n.text("imageEditor.action.layerCompDuplicate"), systemImage: "doc.on.doc")
        }
        Button {
            _ = viewModel.setLayerCompFavorite(comp.id, isFavorite: !comp.isFavorite)
        } label: {
            Label(
                L10n.text(
                    comp.isFavorite
                        ? "imageEditor.action.layerCompRemoveFavorite"
                        : "imageEditor.action.layerCompAddFavorite"
                ),
                systemImage: comp.isFavorite ? "star.slash" : "star"
            )
        }
        Button {
            _ = viewModel.setLayerCompCapturesVisibility(
                comp.id,
                enabled: !comp.capturesVisibility
            )
        } label: {
            Label(
                L10n.text("imageEditor.action.layerCompCaptureVisibility"),
                systemImage: comp.capturesVisibility ? "checkmark.square.fill" : "square"
            )
        }
        Button {
            _ = viewModel.setLayerCompCapturesPosition(
                comp.id,
                enabled: !comp.capturesPosition
            )
        } label: {
            Label(
                L10n.text("imageEditor.action.layerCompCapturePosition"),
                systemImage: comp.capturesPosition ? "checkmark.square.fill" : "square"
            )
        }
        Button {
            _ = viewModel.setLayerCompCapturesAppearance(
                comp.id,
                enabled: !comp.capturesAppearance
            )
        } label: {
            Label(
                L10n.text("imageEditor.action.layerCompCaptureAppearance"),
                systemImage: comp.capturesAppearance ? "checkmark.square.fill" : "square"
            )
        }
        Divider()
        Button {
            viewModel.moveLayerCompToTop(comp.id)
        } label: {
            Label(L10n.text("imageEditor.action.layerCompMoveToTop"), systemImage: "arrow.up.to.line")
        }
        .disabled(!viewModel.canMoveLayerCompToTop(comp.id))
        Button {
            viewModel.moveLayerCompUp(comp.id)
        } label: {
            Label(L10n.text("imageEditor.action.layerCompMoveUp"), systemImage: "arrow.up")
        }
        .disabled(!viewModel.canMoveLayerCompUp(comp.id))
        Button {
            viewModel.moveLayerCompDown(comp.id)
        } label: {
            Label(L10n.text("imageEditor.action.layerCompMoveDown"), systemImage: "arrow.down")
        }
        .disabled(!viewModel.canMoveLayerCompDown(comp.id))
        Button {
            viewModel.moveLayerCompToBottom(comp.id)
        } label: {
            Label(
                L10n.text("imageEditor.action.layerCompMoveToBottom"),
                systemImage: "arrow.down.to.line"
            )
        }
        .disabled(!viewModel.canMoveLayerCompToBottom(comp.id))
        Divider()
        Button(role: .destructive) {
            viewModel.deleteLayerComp(comp.id)
        } label: {
            Label(L10n.text("imageEditor.action.layerCompDelete"), systemImage: "trash")
        }
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

    private func layerCompDropBand(
        _ comp: ImageEditorLayerComp,
        placement: ImageEditorLayerCompDropPlacement
    ) -> some View {
        let target = ImageEditorLayerCompDropTarget(
            layerCompID: comp.id,
            placement: placement
        )
        let isTargeted = targetedLayerCompDropTarget == target
        return Rectangle()
            .fill(isTargeted ? Color(nsColor: ImageEditorTheme.selected) : Color.clear)
            .frame(height: 6)
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            .onDrop(
                of: [UTType.plainText],
                delegate: ImageEditorPanelListDropDelegate(
                    onTargetChange: { isTargeted in
                        targetedLayerCompDropTarget = isTargeted ? target : nil
                    },
                    onDrop: { payload in
                        _ = handleLayerCompDrop(payload, on: comp, placement: placement)
                    }
                )
            )
    }

    private func handleLayerCompDrop(
        _ serializedPayload: String,
        on targetComp: ImageEditorLayerComp,
        placement: ImageEditorLayerCompDropPlacement
    ) -> Bool {
        guard let payload = ImageEditorLayerCompDragPayload.parse(serializedPayload),
              let sourceIndex = viewModel.document.layerComps.firstIndex(where: {
                  $0.id == payload.layerCompID
              }),
              let targetIndex = viewModel.document.layerComps.firstIndex(where: { $0.id == targetComp.id }),
              sourceIndex != targetIndex || placement == .below || payload.operation == .copy
        else { return false }

        switch payload.operation {
        case .move:
            guard let destinationIndex = ImageEditorLayerCompDropGeometry.destinationIndex(
                sourceIndex: sourceIndex,
                targetIndex: targetIndex,
                placement: placement,
                count: viewModel.document.layerComps.count
            ) else { return false }
            return viewModel.moveLayerComp(payload.layerCompID, toIndex: destinationIndex)
        case .copy:
            guard let destinationIndex = ImageEditorLayerCompDropGeometry.copyInsertionIndex(
                targetIndex: targetIndex,
                placement: placement,
                count: viewModel.document.layerComps.count
            ) else { return false }
            return viewModel.duplicateLayerComp(
                payload.layerCompID,
                toIndex: destinationIndex
            ) != nil
        }
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

    private func layerCompCommentBinding(_ comp: ImageEditorLayerComp) -> Binding<String> {
        Binding {
            layerCompCommentDrafts[comp.id] ?? comp.comment
        } set: { value in
            layerCompCommentDrafts[comp.id] = value
        }
    }

    private func syncLayerCompCommentDraft(_ comp: ImageEditorLayerComp) {
        layerCompCommentDrafts[comp.id] = comp.comment
    }

    private func commitLayerCompCommentDraft(_ comp: ImageEditorLayerComp) {
        _ = viewModel.updateLayerCompComment(
            comp.id,
            to: layerCompCommentDrafts[comp.id] ?? comp.comment
        )
        if let updatedComp = viewModel.document.layerComps.first(where: { $0.id == comp.id }) {
            syncLayerCompCommentDraft(updatedComp)
        }
    }

    var savedPathsPanelContent: some View {
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
                delegate: ImageEditorPanelListDropDelegate(
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

}

private struct ImageEditorPanelListDropDelegate: DropDelegate {
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
