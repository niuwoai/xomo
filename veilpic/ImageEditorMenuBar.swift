//
//  ImageEditorMenuBar.swift
//  veilpic
//
//  Created by Codex on 2026/7/9.
//

import SwiftUI
import AppKit

extension ImageEditorView {
    var menuBar: some View {
        HStack(spacing: 14) {
            Menu { fileMenu } label: { editorMenuLabel("imageEditor.menu.file") }
                .buttonStyle(.plain)
                .focusable(false)
                .accessibilityIdentifier("image-editor-menu-file")
            Menu { editMenu } label: { editorMenuLabel("imageEditor.menu.edit") }
                .buttonStyle(.plain)
                .focusable(false)
                .accessibilityIdentifier("image-editor-menu-edit")
            Menu { imageMenu } label: { editorMenuLabel("imageEditor.menu.image") }
                .buttonStyle(.plain)
                .focusable(false)
                .accessibilityIdentifier("image-editor-menu-image")
            Menu { layerMenu } label: { editorMenuLabel("imageEditor.menu.layer") }
                .buttonStyle(.plain)
                .focusable(false)
                .accessibilityIdentifier("image-editor-menu-layer")
            Menu { selectMenu } label: { editorMenuLabel("imageEditor.menu.select") }
                .buttonStyle(.plain)
                .focusable(false)
                .accessibilityIdentifier("image-editor-menu-select")
            Menu { filterMenu } label: { editorMenuLabel("imageEditor.menu.filter") }
                .buttonStyle(.plain)
                .focusable(false)
                .accessibilityIdentifier("image-editor-menu-filter")
            Menu { viewMenu } label: { editorMenuLabel("imageEditor.menu.view") }
                .buttonStyle(.plain)
                .focusable(false)
                .accessibilityIdentifier("image-editor-menu-view")
            Menu { windowMenu } label: { editorMenuLabel("imageEditor.menu.window") }
                .buttonStyle(.plain)
                .focusable(false)
                .accessibilityIdentifier("image-editor-menu-window")

            Spacer()

            Button(L10n.text("imageEditor.action.projectOpen")) {
                viewModel.openProjectDocument()
            }
            .buttonStyle(EditorMenuActionButtonStyle())
            .focusable(false)
            .accessibilityIdentifier("image-editor-action-project-open")

            Button(L10n.text("imageEditor.action.projectSave")) {
                viewModel.saveProjectDocument()
            }
            .buttonStyle(EditorMenuActionButtonStyle())
            .focusable(false)
            .accessibilityIdentifier("image-editor-action-project-save")

            Button(L10n.text("imageEditor.action.cancel")) {
                closeWindow()
            }
            .buttonStyle(EditorMenuSecondaryButtonStyle())
            .focusable(false)
            .accessibilityIdentifier("image-editor-action-cancel")

            Button(L10n.text("imageEditor.action.preview")) {
                viewModel.applyAndClose {
                    closeWindow()
                }
            }
            .buttonStyle(EditorMenuPreviewButtonStyle())
            .focusable(false)
            .accessibilityIdentifier("image-editor-action-apply")
            .accessibilityLabel(L10n.text("imageEditor.action.apply"))

            Button(L10n.text("imageEditor.action.export")) {
                viewModel.openExportPanel()
            }
            .buttonStyle(EditorExportButtonStyle())
            .focusable(false)
            .accessibilityIdentifier("image-editor-action-export")
        }
        .frame(height: 42)
        .padding(.horizontal, 14)
        .background(Color(nsColor: ImageEditorTheme.chrome))
    }

    private func editorMenuLabel(_ key: String) -> some View {
        HStack(spacing: 5) {
            Text(L10n.text(key))
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .bold))
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor(Color(nsColor: ImageEditorTheme.menuText))
        .padding(.horizontal, 6)
        .frame(height: 28)
        .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }

    @ViewBuilder
    private var fileMenu: some View {
        Button(L10n.text("imageEditor.action.canvasNew")) {
            viewModel.isNewCanvasSheetPresented = true
        }
        .keyboardShortcut("n", modifiers: [.command])
        Button(L10n.text("imageEditor.action.projectOpen")) {
            viewModel.openProjectDocument()
        }
        .keyboardShortcut("o", modifiers: [.command])
        Button(L10n.text("imageEditor.action.projectSave")) {
            viewModel.saveProjectDocument()
        }
        .keyboardShortcut("s", modifiers: [.command])
        Divider()
        Button(L10n.text("imageEditor.action.fileImport")) {
            viewModel.chooseImageLayerFile()
        }
        Button(L10n.text("imageEditor.action.export")) {
            viewModel.openExportPanel()
        }
        .keyboardShortcut("s", modifiers: [.command, .shift, .option])
        Divider()
        Button(L10n.text("imageEditor.action.apply")) {
            viewModel.applyAndClose {
                closeWindow()
            }
        }
        Button(L10n.text("imageEditor.action.cancel")) {
            closeWindow()
        }
    }

    @ViewBuilder
    private var editMenu: some View {
        Button(L10n.text("imageEditor.action.undo")) {
            viewModel.undo()
        }
        .keyboardShortcut("z", modifiers: [.command])
        .disabled(!viewModel.canUndo)
        Button(L10n.text("imageEditor.action.redo")) {
            viewModel.redo()
        }
        .keyboardShortcut("z", modifiers: [.command, .shift])
        .disabled(!viewModel.canRedo)
        Divider()
        historySnapshotMenu
        Button(L10n.text("imageEditor.action.historyClear")) {
            viewModel.clearHistoryStates()
        }
        Divider()
        Button(L10n.text("imageEditor.action.cutSelectionClipboard")) {
            viewModel.cutSelectionToClipboard()
        }
        .keyboardShortcut("x", modifiers: [.command])
        .disabled(!viewModel.canCutSelectionToClipboard)
        Button(L10n.text("imageEditor.action.copySelectionClipboard")) {
            viewModel.copySelectionToClipboard()
        }
        .keyboardShortcut("c", modifiers: [.command])
        .disabled(!viewModel.canCopySelectionToClipboard)
        Button(L10n.text("imageEditor.action.copyMergedClipboard")) {
            viewModel.copyMergedToClipboard()
        }
        .keyboardShortcut("c", modifiers: [.command, .shift])
        .disabled(!viewModel.canCopyMergedToClipboard)
        Button(L10n.text("imageEditor.action.pasteClipboardLayer")) {
            viewModel.pasteClipboardAsLayer()
        }
        .keyboardShortcut("v", modifiers: [.command])
        .disabled(!viewModel.canPasteClipboardImage)
        Button(L10n.text("imageEditor.action.pasteClipboardIntoSelection")) {
            viewModel.pasteClipboardIntoSelectionAsLayer()
        }
        .keyboardShortcut("v", modifiers: [.command, .shift])
        .disabled(!viewModel.canPasteClipboardImageIntoSelection)
        Button(L10n.text("imageEditor.action.freeTransform")) {
            viewModel.toggleTransformControlsVisible()
        }
        .keyboardShortcut("t", modifiers: [.command])
        Divider()
        Button(L10n.text("imageEditor.action.fillSelection")) {
            viewModel.fillSelection()
        }
        .keyboardShortcut(.delete, modifiers: [.option])
        .disabled(!viewModel.canEditSelectionPixels)
        Button(L10n.text("imageEditor.action.fillSelectionBackground")) {
            viewModel.fillSelectionWithBackgroundColor()
        }
        .keyboardShortcut(.delete, modifiers: [.command])
        .disabled(!viewModel.canEditSelectionPixels)
        Button(L10n.text("imageEditor.action.contentAwareFillSelection")) {
            viewModel.contentAwareFillSelection()
        }
        .disabled(!viewModel.canEditSelectionPixels)
        Button(L10n.text("imageEditor.action.strokeSelection")) {
            viewModel.strokeSelection()
        }
        .disabled(!viewModel.canEditSelectionPixels)
        Button(L10n.text("imageEditor.action.selectionCopyLayer")) {
            viewModel.copySelectionToNewLayer()
        }
        .disabled(!viewModel.canCopySelectionToNewLayer)
        Button(L10n.text("imageEditor.action.selectionCopyMergedLayer")) {
            viewModel.copyMergedToNewLayer()
        }
        .disabled(!viewModel.canCopyMergedToNewLayer)
        Button(L10n.text("imageEditor.action.selectionCutLayer")) {
            viewModel.cutSelectionToNewLayer()
        }
        .disabled(!viewModel.canCutSelectionToNewLayer)
        Button(L10n.text("imageEditor.action.clearSelectionPixels")) {
            viewModel.clearSelectionPixels()
        }
        .keyboardShortcut(.delete, modifiers: [])
        .disabled(!viewModel.canEditSelectionPixels)
    }

    @ViewBuilder
    private var historySnapshotMenu: some View {
        Menu(L10n.text("imageEditor.menu.edit.historySnapshots")) {
            Button(L10n.text("imageEditor.action.historySnapshotCreate")) {
                viewModel.createHistorySnapshot()
            }
            Divider()
            Button(L10n.text("imageEditor.action.historySnapshotRestoreSelected")) {
                viewModel.restoreSelectedHistorySnapshot()
            }
            .disabled(!viewModel.canRestoreSelectedHistorySnapshot)
            Button(L10n.text("imageEditor.action.historySnapshotDuplicate")) {
                viewModel.duplicateSelectedHistorySnapshot()
            }
            .disabled(!viewModel.canDuplicateSelectedHistorySnapshot)
            Button(L10n.text("imageEditor.action.historySnapshotDeleteSelected")) {
                viewModel.deleteSelectedHistorySnapshot()
            }
            .disabled(!viewModel.canDeleteSelectedHistorySnapshot)
            Divider()
            Button(L10n.text("imageEditor.action.historySnapshotPrevious")) {
                viewModel.selectPreviousHistorySnapshot()
            }
            .disabled(!viewModel.canSelectPreviousHistorySnapshot)
            Button(L10n.text("imageEditor.action.historySnapshotNext")) {
                viewModel.selectNextHistorySnapshot()
            }
            .disabled(!viewModel.canSelectNextHistorySnapshot)
        }
    }

    @ViewBuilder
    private var imageMenu: some View {
        Button(L10n.text("imageEditor.action.imageResize")) {
            viewModel.resizeImageToControlSize()
        }
        .keyboardShortcut("i", modifiers: [.command, .option])
        Button(L10n.text("imageEditor.action.canvasResize")) {
            viewModel.resizeCanvasToControlSize()
        }
        .keyboardShortcut("c", modifiers: [.command, .option])
        Divider()
        Button(ImageEditorAdjustment.levels.title) {
            viewModel.selectAdjustment(.levels)
        }
        .keyboardShortcut("l", modifiers: [.command])
        Button(ImageEditorAdjustment.curves.title) {
            viewModel.selectAdjustment(.curves)
        }
        .keyboardShortcut("m", modifiers: [.command])
        Button(ImageEditorAdjustment.colorBalance.title) {
            viewModel.selectAdjustment(.colorBalance)
        }
        .keyboardShortcut("b", modifiers: [.command])
        Button(ImageEditorAdjustment.hueSaturation.title) {
            viewModel.selectAdjustment(.hueSaturation)
        }
        .keyboardShortcut("u", modifiers: [.command])
        Button(L10n.text("imageEditor.action.desaturate")) {
            viewModel.desaturateSelectedLayer()
        }
        .keyboardShortcut("u", modifiers: [.command, .shift])
        .disabled(!viewModel.canDesaturateSelectedLayer)
        Button(ImageEditorAdjustment.invert.title) {
            viewModel.invertSelectedLayer()
        }
        .keyboardShortcut("i", modifiers: [.command])
        .disabled(!viewModel.canInvertSelectedLayer)
        Menu(L10n.text("imageEditor.menu.image.adjustments")) {
            Button(ImageEditorAdjustment.brightnessContrast.title) {
                viewModel.selectAdjustment(.brightnessContrast)
            }
            Button(ImageEditorAdjustment.channelMixer.title) {
                viewModel.selectAdjustment(.channelMixer)
            }
            Button(ImageEditorAdjustment.selectiveColor.title) {
                viewModel.selectAdjustment(.selectiveColor)
            }
            Button(ImageEditorAdjustment.gradientMap.title) {
                viewModel.selectAdjustment(.gradientMap)
            }
            Button(ImageEditorAdjustment.posterize.title) {
                viewModel.selectAdjustment(.posterize)
            }
            Button(ImageEditorAdjustment.threshold.title) {
                viewModel.selectAdjustment(.threshold)
            }
            Divider()
            Button(ImageEditorAdjustment.exposure.title) {
                viewModel.selectAdjustment(.exposure)
            }
            Button(ImageEditorAdjustment.vibrance.title) {
                viewModel.selectAdjustment(.vibrance)
            }
            Button(ImageEditorAdjustment.shadowsHighlights.title) {
                viewModel.selectAdjustment(.shadowsHighlights)
            }
            Button(ImageEditorAdjustment.blackWhite.title) {
                viewModel.selectAdjustment(.blackWhite)
            }
            Button(ImageEditorAdjustment.photoFilter.title) {
                viewModel.selectAdjustment(.photoFilter)
            }
            Button(ImageEditorAdjustment.colorLookup.title) {
                viewModel.selectAdjustment(.colorLookup)
            }
        }
        Divider()
        Button(L10n.text("imageEditor.action.autoLevels")) {
            viewModel.autoLevelsSelectedLayer()
        }
        .keyboardShortcut("l", modifiers: [.command, .shift])
        .disabled(!viewModel.canAutoLevelsSelectedLayer)
        Button(L10n.text("imageEditor.action.autoContrast")) {
            viewModel.autoContrastSelectedLayer()
        }
        .keyboardShortcut("l", modifiers: [.command, .shift, .option])
        .disabled(!viewModel.canAutoContrastSelectedLayer)
        Button(L10n.text("imageEditor.action.autoColor")) {
            viewModel.autoColorSelectedLayer()
        }
        .keyboardShortcut("b", modifiers: [.command, .shift])
        .disabled(!viewModel.canAutoColorSelectedLayer)
        Divider()
        Button(L10n.text("imageEditor.action.cropCenter")) {
            viewModel.cropCenter()
        }
        Button(L10n.text("imageEditor.action.cropSelection")) {
            viewModel.cropToSelection()
        }
        .disabled(!viewModel.canCropToSelection)
        Button(L10n.text("imageEditor.action.trimTransparentPixels")) {
            viewModel.trimTransparentPixels()
        }
        Button(L10n.text("imageEditor.action.revealAll")) {
            viewModel.revealAllLayers()
        }
        .disabled(!viewModel.canRevealAllLayers)
        Button(L10n.text("imageEditor.action.rotateClockwise")) {
            viewModel.rotateClockwise()
        }
        Button(L10n.text("imageEditor.action.rotateCounterclockwise")) {
            viewModel.rotateCounterclockwise()
        }
        Button(L10n.text("imageEditor.action.rotate180")) {
            viewModel.rotate180()
        }
        Button(L10n.text("imageEditor.action.flipH")) {
            viewModel.flipHorizontal()
        }
        Button(L10n.text("imageEditor.action.flipV")) {
            viewModel.flipVertical()
        }
    }

    @ViewBuilder
    private var layerMenu: some View {
        Button(L10n.text("imageEditor.action.layerNew")) {
            viewModel.addLayer()
        }
        .keyboardShortcut("n", modifiers: [.command, .shift])
        Button(L10n.text("imageEditor.action.layerDuplicate")) {
            viewModel.duplicateSelectionOrSelectedLayer()
        }
        .keyboardShortcut("j", modifiers: [.command])
        .disabled(!viewModel.canDuplicateSelectionOrSelectedLayer)
        Button(L10n.text("imageEditor.action.selectionCopyLayer")) {
            viewModel.copySelectionToNewLayer()
        }
        .disabled(!viewModel.canCopySelectionToNewLayer)
        Button(L10n.text("imageEditor.action.selectionCutLayer")) {
            viewModel.cutSelectionToNewLayer()
        }
        .keyboardShortcut("j", modifiers: [.command, .shift])
        .disabled(!viewModel.canCutSelectionToNewLayer)
        Button(L10n.text("imageEditor.action.layerDelete")) {
            viewModel.deleteSelectedLayer()
        }
        .disabled(!viewModel.canDeleteLayer)
        Divider()
        Button(L10n.text("imageEditor.action.layerFromBackground")) {
            viewModel.convertBackgroundToLayer()
        }
        .disabled(!viewModel.canConvertBackgroundToLayer)
        Button(L10n.text("imageEditor.action.backgroundFromLayer")) {
            viewModel.convertSelectedLayerToBackground()
        }
        .disabled(!viewModel.canConvertSelectedLayerToBackground)
        Divider()
        layerLockMenu
        Divider()
        Button(L10n.text("imageEditor.action.layerSelectAll")) {
            viewModel.selectAllLayers()
        }
        .disabled(!viewModel.canSelectAllLayers)
        Button(L10n.text("imageEditor.action.layerSelectVisible")) {
            viewModel.selectVisibleLayers()
        }
        .disabled(!viewModel.canSelectVisibleLayers)
        Button(L10n.text("imageEditor.action.layerSelectHidden")) {
            viewModel.selectHiddenLayers()
        }
        .disabled(!viewModel.canSelectHiddenLayers)
        Button(L10n.text("imageEditor.action.layerSelectLocked")) {
            viewModel.selectLockedLayers()
        }
        .disabled(!viewModel.canSelectLockedLayers)
        Button(L10n.text("imageEditor.action.layerSelectUnlocked")) {
            viewModel.selectUnlockedLayers()
        }
        .disabled(!viewModel.canSelectUnlockedLayers)
        layerSelectAttributeMenu
        Button(L10n.text("imageEditor.action.layerSelectSameKind")) {
            viewModel.selectLayersWithSameKind()
        }
        .disabled(!viewModel.canSelectLayersWithSameKind)
        Button(L10n.text("imageEditor.action.layerSelectSimilar")) {
            viewModel.selectSimilarLayers()
        }
        .disabled(!viewModel.canSelectSimilarLayers)
        Button(L10n.text("imageEditor.action.layerSelectSameBlendMode")) {
            viewModel.selectLayersWithSameBlendMode()
        }
        .disabled(!viewModel.canSelectLayersWithSameBlendMode)
        Button(L10n.text("imageEditor.action.layerSelectSameLabelColor")) {
            viewModel.selectLayersWithSameLabelColor()
        }
        .disabled(!viewModel.canSelectLayersWithSameLabelColor)
        Button(L10n.text("imageEditor.action.layerSelectionInvert")) {
            viewModel.invertLayerSelection()
        }
        .disabled(!viewModel.canInvertLayerSelection)
        Button(L10n.text("imageEditor.action.layerSelectionClear")) {
            viewModel.clearLayerSelection()
        }
        .disabled(!viewModel.canClearLayerSelection)
        Divider()
        Button(L10n.text("imageEditor.action.layerLink")) {
            viewModel.linkSelectedLayers()
        }
        .disabled(!viewModel.canLinkSelectedLayers)
        Button(L10n.text("imageEditor.action.layerSelectLinked")) {
            viewModel.selectLinkedLayers()
        }
        .disabled(!viewModel.canSelectLinkedLayers)
        Button(L10n.text("imageEditor.action.layerUnlink")) {
            viewModel.unlinkSelectedLayers()
        }
        .disabled(!viewModel.canUnlinkSelectedLayers)
        Button(L10n.text("imageEditor.action.layerUnlinkAll")) {
            viewModel.unlinkAllLayers()
        }
        .disabled(!viewModel.canUnlinkAllLayers)
        Divider()
        Button(L10n.text("imageEditor.action.layerGroupNew")) {
            viewModel.addLayerGroup()
        }
        Button(L10n.text("imageEditor.action.layerGroupSelected")) {
            viewModel.groupSelectedLayer()
        }
        .keyboardShortcut("g", modifiers: [.command])
        .disabled(!viewModel.canGroupSelectedLayer)
        Button(L10n.text("imageEditor.action.layerGroupsExpandSelected")) {
            viewModel.expandSelectedLayerGroups()
        }
        .disabled(!viewModel.canExpandSelectedLayerGroups)
        Button(L10n.text("imageEditor.action.layerGroupsCollapseSelected")) {
            viewModel.collapseSelectedLayerGroups()
        }
        .disabled(!viewModel.canCollapseSelectedLayerGroups)
        Button(L10n.text("imageEditor.action.layerSelectGroupMembers")) {
            viewModel.selectSelectedGroupMembers()
        }
        .disabled(!viewModel.canSelectSelectedGroupMembers)
        Button(L10n.text("imageEditor.action.layerSelectParentGroup")) {
            viewModel.selectParentGroup()
        }
        .disabled(!viewModel.canSelectParentGroup)
        Button(L10n.text("imageEditor.action.layerMoveIntoGroup")) {
            viewModel.moveSelectedLayersIntoGroup()
        }
        .disabled(!viewModel.canMoveSelectedLayersIntoGroup)
        Button(L10n.text("imageEditor.action.layerMoveOutOfGroup")) {
            viewModel.moveSelectedLayersOutOfGroup()
        }
        .disabled(!viewModel.canMoveSelectedLayersOutOfGroup)
        Button(L10n.text("imageEditor.action.layerUngroup")) {
            viewModel.ungroupSelectedLayers()
        }
        .keyboardShortcut("g", modifiers: [.command, .shift])
        .disabled(!viewModel.canUngroupSelectedLayers)
        Divider()
        layerOrderMenu
        layerTransformMenu
        layerAlignmentMenu
        layerMaskMenu
        layerStyleMenu
        layerCompMenu
        Divider()
        Button(L10n.text("imageEditor.action.layerAdjustmentNew")) {
            viewModel.addAdjustmentLayer()
        }
        Button(L10n.text("imageEditor.action.layerFilterNew")) {
            viewModel.addFilterLayer()
        }
        Button(L10n.text("imageEditor.action.layerSolidColorFillNew")) {
            viewModel.addSolidColorFillLayer()
        }
        Button(L10n.text("imageEditor.action.layerPatternFillNew")) {
            viewModel.addPatternFillLayer()
        }
        Button(L10n.text("imageEditor.action.layerGradientFillNew")) {
            viewModel.addGradientFillLayer()
        }
        Button(L10n.text("imageEditor.action.layerSmartFilterAdd")) {
            viewModel.addSmartFilterToSelectedLayer()
        }
        .disabled(!viewModel.canAddSmartFilterToSelectedLayer)
        Button(L10n.text("imageEditor.action.layerSmartFilterClear")) {
            viewModel.clearSmartFiltersFromSelectedLayer()
        }
        .disabled(!viewModel.canClearSmartFiltersFromSelectedLayer)
        Divider()
        Menu(L10n.text("imageEditor.action.layerRasterize")) {
            ForEach(ImageEditorRasterizeTarget.allCases) { target in
                Button(L10n.text(target.actionTitleKey)) {
                    viewModel.rasterizeSelectedLayers(target)
                }
                .disabled(!viewModel.canRasterizeSelectedLayers(target))
            }
        }
        Button(L10n.text("imageEditor.action.layerClippingMask")) {
            viewModel.toggleSelectedLayerClippingMask()
        }
        .disabled(!viewModel.canToggleSelectedLayerClippingMask)
        Button(L10n.text("imageEditor.action.layerClippingMaskCreateSelected")) {
            viewModel.createClippingMasksForSelectedLayers()
        }
        .disabled(!viewModel.canCreateClippingMasksForSelectedLayers)
        Button(L10n.text("imageEditor.action.layerClippingMaskReleaseSelected")) {
            viewModel.releaseSelectedClippingMasks()
        }
        .disabled(!viewModel.canReleaseSelectedClippingMasks)
        Divider()
        Button(L10n.text("imageEditor.action.layerIsolateSelected")) {
            viewModel.isolateSelectedLayers()
        }
        .disabled(!viewModel.canIsolateSelectedLayers)
        Button(L10n.text("imageEditor.action.layerShowSelected")) {
            viewModel.showSelectedLayers()
        }
        .disabled(!viewModel.canShowSelectedLayers)
        Button(L10n.text("imageEditor.action.layerHideSelected")) {
            viewModel.hideSelectedLayers()
        }
        .disabled(!viewModel.canHideSelectedLayers)
        Button(L10n.text("imageEditor.action.layerShowAll")) {
            viewModel.showAllLayers()
        }
        .disabled(!viewModel.canShowAllLayers)
        Divider()
        Button(L10n.text(viewModel.mergeDownActionTitleKey)) {
            viewModel.mergeSelectedLayerDown()
        }
        .keyboardShortcut("e", modifiers: [.command])
        .disabled(!viewModel.canMergeSelectedLayerDown)
        Button(L10n.text("imageEditor.action.layerMergeSelected")) {
            viewModel.mergeSelectedLayers()
        }
        .disabled(!viewModel.canMergeSelectedLayers)
        Button(L10n.text("imageEditor.action.layerStampVisible")) {
            viewModel.stampVisibleLayers()
        }
        .keyboardShortcut("e", modifiers: [.command, .shift, .option])
        .disabled(!viewModel.canStampVisibleLayers)
        Button(L10n.text("imageEditor.action.layerStampSelected")) {
            viewModel.stampSelectedLayers()
        }
        .disabled(!viewModel.canStampSelectedLayers)
        Button(L10n.text("imageEditor.action.layerMergeVisible")) {
            viewModel.mergeVisibleLayers()
        }
        .keyboardShortcut("e", modifiers: [.command, .shift])
        .disabled(!viewModel.canMergeVisibleLayers)
        Button(L10n.text("imageEditor.action.layerFlatten")) {
            viewModel.flattenImage()
        }
        .disabled(!viewModel.canFlattenImage)
    }

    @ViewBuilder
    private var layerSelectAttributeMenu: some View {
        Menu(L10n.text("imageEditor.menu.layer.selectAttribute")) {
            Button(L10n.text("imageEditor.action.layerSelectMasked")) {
                viewModel.selectMaskedLayers()
            }
            .disabled(!viewModel.canSelectMaskedLayers)
            Button(L10n.text("imageEditor.action.layerSelectStyled")) {
                viewModel.selectStyledLayers()
            }
            .disabled(!viewModel.canSelectStyledLayers)
            Button(L10n.text("imageEditor.action.layerSelectClipping")) {
                viewModel.selectClippingMaskLayers()
            }
            .disabled(!viewModel.canSelectClippingMaskLayers)
            Button(L10n.text("imageEditor.action.layerSelectSmartFiltered")) {
                viewModel.selectSmartFilteredLayers()
            }
            .disabled(!viewModel.canSelectSmartFilteredLayers)
        }
    }

    @ViewBuilder
    private var layerLockMenu: some View {
        Menu(L10n.text("imageEditor.menu.layer.lock")) {
            Button(L10n.text("imageEditor.action.layerLockSelected")) {
                viewModel.lockSelectedLayers()
            }
            .disabled(!viewModel.canLockSelectedLayers)
            Button(L10n.text("imageEditor.action.layerUnlockSelected")) {
                viewModel.unlockSelectedLayers()
            }
            .disabled(!viewModel.canUnlockSelectedLayers)
            Divider()
            Button(L10n.text("imageEditor.action.layerPixelsLockSelected")) {
                viewModel.lockSelectedLayerPixels()
            }
            .disabled(!viewModel.canLockSelectedLayerPixels)
            Button(L10n.text("imageEditor.action.layerPixelsUnlockSelected")) {
                viewModel.unlockSelectedLayerPixels()
            }
            .disabled(!viewModel.canUnlockSelectedLayerPixels)
            Divider()
            Button(L10n.text("imageEditor.action.layerPositionLockSelected")) {
                viewModel.lockSelectedLayerPosition()
            }
            .disabled(!viewModel.canLockSelectedLayerPosition)
            Button(L10n.text("imageEditor.action.layerPositionUnlockSelected")) {
                viewModel.unlockSelectedLayerPosition()
            }
            .disabled(!viewModel.canUnlockSelectedLayerPosition)
            Divider()
            Button(L10n.text("imageEditor.action.layerTransparentPixelsLockSelected")) {
                viewModel.lockSelectedLayerTransparentPixels()
            }
            .disabled(!viewModel.canLockSelectedLayerTransparentPixels)
            Button(L10n.text("imageEditor.action.layerTransparentPixelsUnlockSelected")) {
                viewModel.unlockSelectedLayerTransparentPixels()
            }
            .disabled(!viewModel.canUnlockSelectedLayerTransparentPixels)
        }
    }

    @ViewBuilder
    private var layerOrderMenu: some View {
        Menu(L10n.text("imageEditor.menu.layer.order")) {
            Button(L10n.text("imageEditor.action.layerTop")) {
                viewModel.moveSelectedLayerToTop(inVisibleOrder: filteredVisibleLayerRowIDs)
            }
            .keyboardShortcut("]", modifiers: [.command, .shift])
            .disabled(!viewModel.canMoveSelectedLayerToTop(inVisibleOrder: filteredVisibleLayerRowIDs))
            Button(L10n.text("imageEditor.action.layerUp")) {
                viewModel.moveSelectedLayerUp(inVisibleOrder: filteredVisibleLayerRowIDs)
            }
            .keyboardShortcut("]", modifiers: [.command])
            .disabled(!viewModel.canMoveSelectedLayerUp(inVisibleOrder: filteredVisibleLayerRowIDs))
            Button(L10n.text("imageEditor.action.layerDown")) {
                viewModel.moveSelectedLayerDown(inVisibleOrder: filteredVisibleLayerRowIDs)
            }
            .keyboardShortcut("[", modifiers: [.command])
            .disabled(!viewModel.canMoveSelectedLayerDown(inVisibleOrder: filteredVisibleLayerRowIDs))
            Button(L10n.text("imageEditor.action.layerBottom")) {
                viewModel.moveSelectedLayerToBottom(inVisibleOrder: filteredVisibleLayerRowIDs)
            }
            .keyboardShortcut("[", modifiers: [.command, .shift])
            .disabled(!viewModel.canMoveSelectedLayerToBottom(inVisibleOrder: filteredVisibleLayerRowIDs))
        }
    }

    @ViewBuilder
    private var layerTransformMenu: some View {
        Menu(L10n.text("imageEditor.menu.layer.transform")) {
            Button(L10n.text("imageEditor.action.layerRotate90Left")) {
                viewModel.rotateSelectedLayerLeft90()
            }
            .disabled(!viewModel.canRotateSelectedLayer)
            Button(L10n.text("imageEditor.action.layerRotate90Right")) {
                viewModel.rotateSelectedLayerRight90()
            }
            .disabled(!viewModel.canRotateSelectedLayer)
            Button(L10n.text("imageEditor.action.layerRotate180")) {
                viewModel.rotateSelectedLayer180()
            }
            .disabled(!viewModel.canRotateSelectedLayer)
            Divider()
            Button(L10n.text("imageEditor.action.layerFlipHorizontal")) {
                viewModel.flipSelectedLayerHorizontal()
            }
            .disabled(!viewModel.canFlipSelectedLayer)
            Button(L10n.text("imageEditor.action.layerFlipVertical")) {
                viewModel.flipSelectedLayerVertical()
            }
            .disabled(!viewModel.canFlipSelectedLayer)
            Divider()
            Button(L10n.text("imageEditor.action.layerFitCanvas")) {
                viewModel.fitSelectedLayerToCanvas()
            }
            .disabled(!viewModel.canFitSelectedLayerToCanvas)
            Button(L10n.text("imageEditor.action.layerFillCanvas")) {
                viewModel.fillSelectedLayerToCanvas()
            }
            .disabled(!viewModel.canFitSelectedLayerToCanvas)
            Divider()
            Button(L10n.text("imageEditor.action.layerFitSelection")) {
                viewModel.fitSelectedLayerToSelection()
            }
            .disabled(!viewModel.canFitSelectedLayerToSelection)
            Button(L10n.text("imageEditor.action.layerFillSelection")) {
                viewModel.fillSelectedLayerToSelection()
            }
            .disabled(!viewModel.canFitSelectedLayerToSelection)
            Divider()
            Button(L10n.text("imageEditor.action.layerTrimTransparentPixels")) {
                viewModel.trimSelectedLayerTransparentPixels()
            }
            .disabled(!viewModel.canTrimSelectedLayerTransparentPixels)
        }
    }

    @ViewBuilder
    private var layerAlignmentMenu: some View {
        Menu(L10n.text("imageEditor.menu.layer.align")) {
            Button(L10n.text("imageEditor.action.layerAlignLeft")) {
                viewModel.alignSelectedLayers(.left)
            }
            Button(L10n.text("imageEditor.action.layerAlignHorizontalCenter")) {
                viewModel.alignSelectedLayers(.horizontalCenter)
            }
            Button(L10n.text("imageEditor.action.layerAlignRight")) {
                viewModel.alignSelectedLayers(.right)
            }
            Button(L10n.text("imageEditor.action.layerAlignTop")) {
                viewModel.alignSelectedLayers(.top)
            }
            Button(L10n.text("imageEditor.action.layerAlignVerticalCenter")) {
                viewModel.alignSelectedLayers(.verticalCenter)
            }
            Button(L10n.text("imageEditor.action.layerAlignBottom")) {
                viewModel.alignSelectedLayers(.bottom)
            }
            Divider()
            Button(L10n.text("imageEditor.action.layerAlignCanvasLeft")) {
                viewModel.alignSelectedLayersToCanvas(.left)
            }
            .disabled(!viewModel.canAlignSelectedLayersToCanvas)
            Button(L10n.text("imageEditor.action.layerAlignCanvasHorizontalCenter")) {
                viewModel.alignSelectedLayersToCanvas(.horizontalCenter)
            }
            .disabled(!viewModel.canAlignSelectedLayersToCanvas)
            Button(L10n.text("imageEditor.action.layerAlignCanvasRight")) {
                viewModel.alignSelectedLayersToCanvas(.right)
            }
            .disabled(!viewModel.canAlignSelectedLayersToCanvas)
            Button(L10n.text("imageEditor.action.layerAlignCanvasTop")) {
                viewModel.alignSelectedLayersToCanvas(.top)
            }
            .disabled(!viewModel.canAlignSelectedLayersToCanvas)
            Button(L10n.text("imageEditor.action.layerAlignCanvasVerticalCenter")) {
                viewModel.alignSelectedLayersToCanvas(.verticalCenter)
            }
            .disabled(!viewModel.canAlignSelectedLayersToCanvas)
            Button(L10n.text("imageEditor.action.layerAlignCanvasBottom")) {
                viewModel.alignSelectedLayersToCanvas(.bottom)
            }
            .disabled(!viewModel.canAlignSelectedLayersToCanvas)
            Divider()
            Button(L10n.text("imageEditor.action.layerAlignSelectionLeft")) {
                viewModel.alignSelectedLayersToSelection(.left)
            }
            .disabled(!viewModel.canAlignSelectedLayersToSelection)
            Button(L10n.text("imageEditor.action.layerAlignSelectionHorizontalCenter")) {
                viewModel.alignSelectedLayersToSelection(.horizontalCenter)
            }
            .disabled(!viewModel.canAlignSelectedLayersToSelection)
            Button(L10n.text("imageEditor.action.layerAlignSelectionRight")) {
                viewModel.alignSelectedLayersToSelection(.right)
            }
            .disabled(!viewModel.canAlignSelectedLayersToSelection)
            Button(L10n.text("imageEditor.action.layerAlignSelectionTop")) {
                viewModel.alignSelectedLayersToSelection(.top)
            }
            .disabled(!viewModel.canAlignSelectedLayersToSelection)
            Button(L10n.text("imageEditor.action.layerAlignSelectionVerticalCenter")) {
                viewModel.alignSelectedLayersToSelection(.verticalCenter)
            }
            .disabled(!viewModel.canAlignSelectedLayersToSelection)
            Button(L10n.text("imageEditor.action.layerAlignSelectionBottom")) {
                viewModel.alignSelectedLayersToSelection(.bottom)
            }
            .disabled(!viewModel.canAlignSelectedLayersToSelection)
            Divider()
            Button(L10n.text("imageEditor.action.layerDistributeLeft")) {
                viewModel.distributeSelectedLayers(.left)
            }
            .disabled(!viewModel.canDistributeSelectedLayers)
            Button(L10n.text("imageEditor.action.layerDistributeHorizontalCenter")) {
                viewModel.distributeSelectedLayers(.horizontalCenter)
            }
            .disabled(!viewModel.canDistributeSelectedLayers)
            Button(L10n.text("imageEditor.action.layerDistributeRight")) {
                viewModel.distributeSelectedLayers(.right)
            }
            .disabled(!viewModel.canDistributeSelectedLayers)
            Button(L10n.text("imageEditor.action.layerDistributeTop")) {
                viewModel.distributeSelectedLayers(.top)
            }
            .disabled(!viewModel.canDistributeSelectedLayers)
            Button(L10n.text("imageEditor.action.layerDistributeVerticalCenter")) {
                viewModel.distributeSelectedLayers(.verticalCenter)
            }
            .disabled(!viewModel.canDistributeSelectedLayers)
            Button(L10n.text("imageEditor.action.layerDistributeBottom")) {
                viewModel.distributeSelectedLayers(.bottom)
            }
            .disabled(!viewModel.canDistributeSelectedLayers)
            Divider()
            Button(L10n.text("imageEditor.action.layerDistributeHorizontalSpacing")) {
                viewModel.distributeSelectedLayerSpacing(.horizontal)
            }
            .disabled(!viewModel.canDistributeSelectedLayers)
            Button(L10n.text("imageEditor.action.layerDistributeVerticalSpacing")) {
                viewModel.distributeSelectedLayerSpacing(.vertical)
            }
            .disabled(!viewModel.canDistributeSelectedLayers)
        }
        .disabled(!viewModel.canAlignSelectedLayers && !viewModel.canAlignSelectedLayersToCanvas && !viewModel.canAlignSelectedLayersToSelection && !viewModel.canDistributeSelectedLayers)
    }

    @ViewBuilder
    private var layerStyleMenu: some View {
        Menu(L10n.text("imageEditor.menu.layer.style")) {
            layerStyleActionItems
        }
    }

    @ViewBuilder
    private var layerStyleActionItems: some View {
        Button(L10n.text("imageEditor.action.layerStyleBlendingOptions")) {
            viewModel.showLayerStyleBlendingOptions()
        }
        .disabled(!viewModel.canEditSelectedLayerStyle)
        Menu(L10n.text("imageEditor.menu.layer.stylePresets")) {
            layerStylePresetItems
        }
        Divider()
        Button(L10n.text("imageEditor.action.layerStyleCopy")) {
            viewModel.copySelectedLayerStyle()
        }
        .disabled(!viewModel.canCopySelectedLayerStyle)
        Button(L10n.text("imageEditor.action.layerStylePaste")) {
            viewModel.pasteLayerStyleToSelectedLayers()
        }
        .disabled(!viewModel.canPasteLayerStyleToSelectedLayers)
        Button(L10n.text("imageEditor.action.layerStyleClear")) {
            viewModel.clearSelectedLayerStyles()
        }
        .disabled(!viewModel.canClearSelectedLayerStyles)
        Divider()
        Button(L10n.text("imageEditor.action.layerEffectsHideSelected")) {
            viewModel.hideSelectedLayerEffects()
        }
        .disabled(!viewModel.canToggleSelectedLayerEffects || !viewModel.selectedLayerEffectsAreVisible)
        Button(L10n.text("imageEditor.action.layerEffectsShowSelected")) {
            viewModel.showSelectedLayerEffects()
        }
        .disabled(!viewModel.canToggleSelectedLayerEffects || viewModel.selectedLayerEffectsAreVisible)
        Button(L10n.text("imageEditor.action.layerEffectsHideAll")) {
            viewModel.hideAllLayerEffects()
        }
        .disabled(!viewModel.canHideAllLayerEffects)
        Button(L10n.text("imageEditor.action.layerEffectsShowAll")) {
            viewModel.showAllLayerEffects()
        }
        .disabled(!viewModel.canShowAllLayerEffects)
        Button(L10n.text("imageEditor.action.layerEffectsScale")) {
            viewModel.showLayerEffectScaleOptions()
        }
        .disabled(!viewModel.canScaleSelectedLayerEffects)
        Divider()
        Button(L10n.text("imageEditor.action.layerStroke")) {
            viewModel.toggleSelectedLayerStroke()
        }
        .disabled(!viewModel.canEditSelectedLayerStyle)
        Button(L10n.text("imageEditor.action.layerShadow")) {
            viewModel.toggleSelectedLayerShadow()
        }
        .disabled(!viewModel.canEditSelectedLayerStyle)
        Button(L10n.text("imageEditor.action.layerInnerShadow")) {
            viewModel.toggleSelectedLayerInnerShadow()
        }
        .disabled(!viewModel.canEditSelectedLayerStyle)
        Button(L10n.text("imageEditor.action.layerOuterGlow")) {
            viewModel.toggleSelectedLayerOuterGlow()
        }
        .disabled(!viewModel.canEditSelectedLayerStyle)
        Button(L10n.text("imageEditor.action.layerInnerGlow")) {
            viewModel.toggleSelectedLayerInnerGlow()
        }
        .disabled(!viewModel.canEditSelectedLayerStyle)
        Button(L10n.text("imageEditor.action.layerColorOverlay")) {
            viewModel.toggleSelectedLayerColorOverlay()
        }
        .disabled(!viewModel.canEditSelectedLayerStyle)
        Button(L10n.text("imageEditor.action.layerGradientOverlay")) {
            viewModel.toggleSelectedLayerGradientOverlay()
        }
        .disabled(!viewModel.canEditSelectedLayerStyle)
        Button(L10n.text("imageEditor.action.layerPatternOverlay")) {
            viewModel.toggleSelectedLayerPatternOverlay()
        }
        .disabled(!viewModel.canEditSelectedLayerStyle)
        Button(L10n.text("imageEditor.action.layerSatin")) {
            viewModel.toggleSelectedLayerSatin()
        }
        .disabled(!viewModel.canEditSelectedLayerStyle)
        Button(L10n.text("imageEditor.action.layerBevel")) {
            viewModel.toggleSelectedLayerBevel()
        }
        .disabled(!viewModel.canEditSelectedLayerStyle)
    }

    @ViewBuilder
    private var layerStylePresetItems: some View {
        Section(L10n.text("imageEditor.layerStylePreset.builtInSection")) {
            ForEach(viewModel.builtInLayerStylePresets) { preset in
                layerStylePresetButton(preset)
            }
        }

        Section(L10n.text("imageEditor.layerStylePreset.customSection")) {
            if viewModel.customLayerStylePresets.isEmpty {
                Text(L10n.text("imageEditor.layerStylePreset.empty"))
            }
            ForEach(viewModel.customLayerStylePresets) { preset in
                layerStylePresetButton(preset)
            }
        }

        Divider()
        Button(L10n.text("imageEditor.action.layerStylePresetCreate")) {
            viewModel.createLayerStylePresetFromSelectedLayer()
        }
        .disabled(!viewModel.canCreateLayerStylePreset)

        if let activePreset = viewModel.activeLayerStylePreset, !activePreset.isBuiltIn {
            Button(L10n.text("imageEditor.action.layerStylePresetDelete"), role: .destructive) {
                viewModel.deleteLayerStylePreset(activePreset)
            }
        }

        Divider()
        Button(L10n.text("imageEditor.action.layerStylePresetManage")) {
            viewModel.isLayerStylePresetManagerPresented = true
        }
    }

    private func layerStylePresetButton(_ preset: ImageEditorLayerStylePreset) -> some View {
        Button {
            viewModel.applyLayerStylePreset(preset)
        } label: {
            if viewModel.activeLayerStylePreset?.id == preset.id {
                Label(preset.title, systemImage: "checkmark")
            } else {
                Text(preset.title)
            }
        }
        .disabled(!viewModel.canApplyLayerStylePreset)
    }

    @ViewBuilder
    private var layerCompMenu: some View {
        Menu(L10n.text("imageEditor.menu.layer.comps")) {
            Button(L10n.text("imageEditor.action.layerCompNew")) {
                viewModel.addLayerComp()
            }
            Divider()
            Button(L10n.text("imageEditor.action.layerCompApply")) {
                viewModel.applySelectedLayerComp()
            }
            .disabled(!viewModel.canApplySelectedLayerComp)
            Button(L10n.text("imageEditor.action.layerCompUpdate")) {
                viewModel.updateSelectedLayerComp()
            }
            .disabled(!viewModel.canUpdateSelectedLayerComp)
            Button(L10n.text("imageEditor.action.layerCompDuplicate")) {
                viewModel.duplicateSelectedLayerComp()
            }
            .disabled(!viewModel.canDuplicateSelectedLayerComp)
            Button(L10n.text("imageEditor.action.layerCompDelete")) {
                viewModel.deleteSelectedLayerComp()
            }
            .disabled(!viewModel.canDeleteSelectedLayerComp)
            Divider()
            Button(L10n.text("imageEditor.action.layerCompPrevious")) {
                viewModel.selectPreviousLayerComp()
            }
            .disabled(!viewModel.canSelectPreviousLayerComp)
            Button(L10n.text("imageEditor.action.layerCompNext")) {
                viewModel.selectNextLayerComp()
            }
            .disabled(!viewModel.canSelectNextLayerComp)
        }
    }

    @ViewBuilder
    private var layerMaskMenu: some View {
        Menu(L10n.text("imageEditor.menu.layer.mask")) {
            Button(L10n.text("imageEditor.action.layerMaskAdd")) {
                viewModel.addLayerMask()
            }
            .disabled(!viewModel.canAddLayerMask)
            Button(L10n.text("imageEditor.action.layerMaskHideAll")) {
                viewModel.addLayerMaskHidingAll()
            }
            .disabled(!viewModel.canAddLayerMask)
            Button(L10n.text("imageEditor.action.layerMaskFromSelection")) {
                viewModel.addLayerMaskFromSelection()
            }
            .disabled(!viewModel.canCreateLayerMaskFromSelection)
            Button(L10n.text("imageEditor.action.vectorMaskFromSelection")) {
                viewModel.addVectorMaskFromSelection()
            }
            .disabled(!viewModel.canCreateVectorMaskFromSelection)
            Button(L10n.text("imageEditor.action.layerMaskHideSelection")) {
                viewModel.addLayerMaskHidingSelection()
            }
            .disabled(!viewModel.canCreateLayerMaskFromSelection)
            Divider()
            Button(L10n.text("imageEditor.action.layerMaskEdit")) {
                viewModel.editLayerMask()
            }
            .disabled(!viewModel.selectedLayerHasMask)
            Button(L10n.text("imageEditor.action.layerMaskToggle")) {
                viewModel.toggleLayerMaskEnabled()
            }
            .disabled(!viewModel.canToggleLayerMaskEnabled)
            Button(L10n.text("imageEditor.action.layerMaskLinkToggle")) {
                viewModel.toggleLayerMaskLinked()
            }
            .disabled(!viewModel.canToggleLayerMaskLinked)
            Button(L10n.text("imageEditor.action.layerMaskInvert")) {
                viewModel.invertLayerMask()
            }
            .disabled(!viewModel.canInvertLayerMask)
            Button(L10n.text("imageEditor.action.layerMaskRevealSelection")) {
                viewModel.revealSelectionOnLayerMask()
            }
            .disabled(!viewModel.canCombineLayerMaskWithSelection)
            Button(L10n.text("imageEditor.action.layerMaskHideSelectionFromMask")) {
                viewModel.hideSelectionOnLayerMask()
            }
            .disabled(!viewModel.canCombineLayerMaskWithSelection)
            Button(L10n.text("imageEditor.action.layerMaskIntersectSelection")) {
                viewModel.intersectLayerMaskWithSelection()
            }
            .disabled(!viewModel.canCombineLayerMaskWithSelection)
            Button(L10n.text("imageEditor.action.layerMaskLoadSelection")) {
                viewModel.loadSelectionFromLayerMask()
            }
            .disabled(!viewModel.canLoadSelectionFromLayerMask)
            Button(L10n.text("imageEditor.action.layerTransparencyLoadSelection")) {
                viewModel.loadSelectionFromLayerTransparency()
            }
            .disabled(!viewModel.canLoadSelectionFromLayerTransparency)
            Button(L10n.text("imageEditor.action.layerMaskCopyToSelected")) {
                viewModel.copyLayerMaskToSelectedLayers()
            }
            .disabled(!viewModel.canCopyLayerMaskToSelectedLayers)
            Button(L10n.text("imageEditor.action.layerMaskApply")) {
                viewModel.applyLayerMask()
            }
            .disabled(!viewModel.canApplyLayerMask)
            Button(L10n.text("imageEditor.action.layerMaskDelete")) {
                viewModel.deleteLayerMask()
            }
            .disabled(!viewModel.canDeleteLayerMask)
            Divider()
            Button(L10n.text("imageEditor.action.vectorMaskToggle")) {
                viewModel.toggleVectorMaskEnabled()
            }
            .disabled(!viewModel.canToggleVectorMaskEnabled)
            Button(L10n.text("imageEditor.action.vectorMaskEditPath")) {
                viewModel.editSelectedVectorMaskAsPath()
            }
            .disabled(!viewModel.canEditSelectedVectorMaskAsPath)
            Button(L10n.text("imageEditor.action.vectorMaskLoadSelection")) {
                viewModel.loadSelectionFromVectorMask()
            }
            .disabled(!viewModel.canLoadSelectionFromVectorMask)
            Button(L10n.text("imageEditor.action.vectorMaskCopyToSelected")) {
                viewModel.copyVectorMaskToSelectedLayers()
            }
            .disabled(!viewModel.canCopyVectorMaskToSelectedLayers)
            Button(L10n.text("imageEditor.action.vectorMaskApply")) {
                viewModel.applyVectorMask()
            }
            .disabled(!viewModel.canApplyVectorMask)
            Button(L10n.text("imageEditor.action.vectorMaskRasterize")) {
                viewModel.rasterizeSelectedVectorMask()
            }
            .disabled(!viewModel.canRasterizeSelectedVectorMask)
            Button(L10n.text("imageEditor.action.vectorMaskDelete")) {
                viewModel.deleteVectorMask()
            }
            .disabled(!viewModel.canDeleteVectorMask)
        }
    }

    @ViewBuilder
    private var selectMenu: some View {
        Button(L10n.text("imageEditor.action.selectAll")) {
            viewModel.selectAll()
        }
        .keyboardShortcut("a", modifiers: [.command])
        Button(L10n.text("imageEditor.action.clearSelection")) {
            viewModel.clearSelection()
        }
        .keyboardShortcut("d", modifiers: [.command])
        .disabled(!viewModel.hasSelection)
        Button(L10n.text("imageEditor.action.reselectSelection")) {
            viewModel.reselectSelection()
        }
        .keyboardShortcut("d", modifiers: [.command, .shift])
        .disabled(!viewModel.canReselectSelection)
        Button(L10n.text("imageEditor.action.invertSelection")) {
            viewModel.invertSelection()
        }
        .keyboardShortcut("i", modifiers: [.command, .shift])
        .disabled(!viewModel.hasSelection)
        Button(L10n.text("imageEditor.action.quickMask")) {
            viewModel.toggleQuickMaskMode()
        }
        .keyboardShortcut("q", modifiers: [])
        .disabled(!viewModel.hasSelection)
        Divider()
        Button(L10n.text("imageEditor.action.selectionFromLayer")) {
            viewModel.loadSelectionFromLayerTransparency()
        }
        .disabled(!viewModel.canLoadSelectionFromLayerTransparency)
        Button(L10n.text("imageEditor.action.pathSelection")) {
            viewModel.loadSelectionFromSelectedPath()
        }
        .disabled(!viewModel.canLoadSelectionFromSelectedPath)
        Button(L10n.text("imageEditor.action.pathFromSelection")) {
            viewModel.createPathFromSelection()
        }
        .disabled(!viewModel.canCreatePathFromSelection)
        Button(L10n.text("imageEditor.action.selectColorRange")) {
            viewModel.presentColorRangePanel()
        }
        Button(L10n.text("imageEditor.action.selectSimilar")) {
            viewModel.selectSimilarColors()
        }
        .disabled(!viewModel.canSelectSimilarColors)
        Button(L10n.text("imageEditor.action.selectGrow")) {
            viewModel.growColorSelection()
        }
        .disabled(!viewModel.canGrowColorSelection)
        Divider()
        Menu(L10n.text("imageEditor.menu.select.alphaChannels")) {
            alphaChannelMenu
        }
        Divider()
        Button(L10n.text("imageEditor.action.saveSelection")) {
            viewModel.saveCurrentSelection()
        }
        .disabled(!viewModel.hasSelection)
        Button(L10n.text("imageEditor.action.restoreSelection")) {
            viewModel.restoreSavedSelection()
        }
        .disabled(!viewModel.hasSavedSelection)
        Divider()
        Button(L10n.text("imageEditor.action.expandSelection")) {
            viewModel.expandSelection()
        }
        .disabled(!viewModel.hasSelection)
        Button(L10n.text("imageEditor.action.contractSelection")) {
            viewModel.contractSelection()
        }
        .disabled(!viewModel.hasSelection)
        Button(L10n.text("imageEditor.action.featherSelection")) {
            viewModel.featherSelection()
        }
        .keyboardShortcut("d", modifiers: [.command, .option])
        .disabled(!viewModel.hasSelection)
        Button(L10n.text("imageEditor.action.borderSelection")) {
            viewModel.borderSelection()
        }
        .disabled(!viewModel.hasSelection)
        Button(L10n.text("imageEditor.action.smoothSelection")) {
            viewModel.smoothSelection()
        }
        .disabled(!viewModel.hasSelection)
        Button(L10n.text("imageEditor.action.fillSelectionHoles")) {
            viewModel.fillSelectionHoles()
        }
        .disabled(!viewModel.hasSelection)
        Button(L10n.text("imageEditor.action.removeSelectionSpeckles")) {
            viewModel.removeSelectionSpeckles()
        }
        .disabled(!viewModel.hasSelection)
        Menu(L10n.text("imageEditor.menu.select.transform")) {
            Button(L10n.text("imageEditor.action.selectionMoveLeft")) {
                viewModel.moveSelectionLeft()
            }
            Button(L10n.text("imageEditor.action.selectionMoveRight")) {
                viewModel.moveSelectionRight()
            }
            Button(L10n.text("imageEditor.action.selectionMoveUp")) {
                viewModel.moveSelectionUp()
            }
            Button(L10n.text("imageEditor.action.selectionMoveDown")) {
                viewModel.moveSelectionDown()
            }
            Divider()
            Button(L10n.text("imageEditor.action.selectionCenterHorizontal")) {
                viewModel.centerSelectionHorizontally()
            }
            Button(L10n.text("imageEditor.action.selectionCenterVertical")) {
                viewModel.centerSelectionVertically()
            }
            Button(L10n.text("imageEditor.action.selectionCenterCanvas")) {
                viewModel.centerSelectionInCanvas()
            }
            Divider()
            Button(L10n.text("imageEditor.action.selectionFlipHorizontal")) {
                viewModel.flipSelectionHorizontal()
            }
            Button(L10n.text("imageEditor.action.selectionFlipVertical")) {
                viewModel.flipSelectionVertical()
            }
            Divider()
            Button(L10n.text("imageEditor.action.selectionRotateClockwise")) {
                viewModel.rotateSelectionClockwise()
            }
            Button(L10n.text("imageEditor.action.selectionRotateCounterclockwise")) {
                viewModel.rotateSelectionCounterclockwise()
            }
            Button(L10n.text("imageEditor.action.selectionRotate180")) {
                viewModel.rotateSelection180()
            }
            Divider()
            Button(L10n.text("imageEditor.action.selectionScaleUp")) {
                viewModel.scaleSelectionUp()
            }
            Button(L10n.text("imageEditor.action.selectionScaleDown")) {
                viewModel.scaleSelectionDown()
            }
            Button(L10n.text("imageEditor.action.selectionFitCanvas")) {
                viewModel.fitSelectionToCanvas()
            }
        }
        .disabled(!viewModel.hasSelection)
    }

    @ViewBuilder
    private var alphaChannelMenu: some View {
        Button(L10n.text("imageEditor.action.alphaChannelBlank")) {
            viewModel.createBlankAlphaChannel()
        }
        .disabled(!viewModel.canCreateBlankAlphaChannel)
        Button(L10n.text("imageEditor.action.channelSaveSelection")) {
            viewModel.saveSelectionAsAlphaChannel()
        }
        .disabled(!viewModel.canSaveSelectionAsAlphaChannel)
        Button(L10n.text("imageEditor.action.channelSaveLayerMask")) {
            viewModel.saveSelectedLayerMaskAsAlphaChannel()
        }
        .disabled(!viewModel.canSaveSelectedLayerMaskAsAlphaChannel)
        Button(L10n.text("imageEditor.action.channelSaveLayerTransparency")) {
            viewModel.saveSelectedLayerTransparencyAsAlphaChannel()
        }
        .disabled(!viewModel.canSaveSelectedLayerTransparencyAsAlphaChannel)
        Button(L10n.text("imageEditor.action.channelSaveCurrentAsAlpha")) {
            viewModel.saveSelectedChannelAsAlphaChannel()
        }
        .disabled(!viewModel.canSaveSelectedChannelAsAlphaChannel)
        Divider()
        Button(L10n.text("imageEditor.action.alphaChannelLoadSelectedSelection")) {
            viewModel.loadSelectionFromSelectedAlphaChannel()
        }
        .disabled(!viewModel.canLoadSelectedAlphaChannelSelection)
        Button(L10n.text("imageEditor.action.alphaChannelUpdateSelected")) {
            viewModel.updateSelectedAlphaChannelFromSelection()
        }
        .disabled(!viewModel.canUpdateSelectedAlphaChannelFromSelection)
        Button(L10n.text("imageEditor.action.alphaChannelSelectionAddSelected")) {
            viewModel.addSelectionToSelectedAlphaChannel()
        }
        .disabled(!viewModel.canAddSelectionToSelectedAlphaChannel)
        Button(L10n.text("imageEditor.action.alphaChannelSelectionSubtractSelected")) {
            viewModel.subtractSelectionFromSelectedAlphaChannel()
        }
        .disabled(!viewModel.canSubtractSelectionFromSelectedAlphaChannel)
        Button(L10n.text("imageEditor.action.alphaChannelSelectionIntersectSelected")) {
            viewModel.intersectSelectionWithSelectedAlphaChannel()
        }
        .disabled(!viewModel.canIntersectSelectionWithSelectedAlphaChannel)
        Button(L10n.text("imageEditor.action.alphaChannelApplySelectedToMask")) {
            viewModel.applySelectedAlphaChannelToSelectedLayerMask()
        }
        .disabled(!viewModel.canApplySelectedAlphaChannelToLayerMask)
        Divider()
        Button(L10n.text("imageEditor.action.alphaChannelLayerSelected")) {
            viewModel.createLayerFromSelectedAlphaChannel()
        }
        .disabled(!viewModel.canCreateLayerFromSelectedAlphaChannel)
        Button(L10n.text("imageEditor.action.alphaChannelDuplicateSelected")) {
            viewModel.duplicateSelectedAlphaChannel()
        }
        .disabled(!viewModel.canDuplicateSelectedAlphaChannel)
        Button(L10n.text("imageEditor.action.alphaChannelInvertSelected")) {
            viewModel.invertSelectedAlphaChannel()
        }
        .disabled(!viewModel.canInvertSelectedAlphaChannel)
        Button(L10n.text("imageEditor.action.alphaChannelFillWhiteSelected")) {
            viewModel.fillSelectedAlphaChannelWhite()
        }
        .disabled(!viewModel.canFillSelectedAlphaChannelWhite)
        Button(L10n.text("imageEditor.action.alphaChannelClearSelected")) {
            viewModel.clearSelectedAlphaChannel()
        }
        .disabled(!viewModel.canClearSelectedAlphaChannel)
        Button(L10n.text("imageEditor.action.alphaChannelThresholdSelected")) {
            viewModel.thresholdSelectedAlphaChannel()
        }
        .disabled(!viewModel.canThresholdSelectedAlphaChannel)
        Button(L10n.text("imageEditor.action.alphaChannelFeatherSelected")) {
            viewModel.featherSelectedAlphaChannel()
        }
        .disabled(!viewModel.canFeatherSelectedAlphaChannel)
        Button(L10n.text("imageEditor.action.alphaChannelExpandSelected")) {
            viewModel.expandSelectedAlphaChannel()
        }
        .disabled(!viewModel.canExpandSelectedAlphaChannel)
        Button(L10n.text("imageEditor.action.alphaChannelContractSelected")) {
            viewModel.contractSelectedAlphaChannel()
        }
        .disabled(!viewModel.canContractSelectedAlphaChannel)
        Button(L10n.text("imageEditor.action.alphaChannelSmoothSelected")) {
            viewModel.smoothSelectedAlphaChannel()
        }
        .disabled(!viewModel.canSmoothSelectedAlphaChannel)
        Button(L10n.text("imageEditor.action.alphaChannelFillHolesSelected")) {
            viewModel.fillHolesSelectedAlphaChannel()
        }
        .disabled(!viewModel.canFillHolesSelectedAlphaChannel)
        Button(L10n.text("imageEditor.action.alphaChannelRemoveSpecklesSelected")) {
            viewModel.removeSpecklesSelectedAlphaChannel()
        }
        .disabled(!viewModel.canRemoveSpecklesSelectedAlphaChannel)
        Button(L10n.text("imageEditor.action.alphaChannelFlipHorizontalSelected")) {
            viewModel.flipSelectedAlphaChannelHorizontal()
        }
        .disabled(!viewModel.canFlipSelectedAlphaChannelHorizontal)
        Button(L10n.text("imageEditor.action.alphaChannelFlipVerticalSelected")) {
            viewModel.flipSelectedAlphaChannelVertical()
        }
        .disabled(!viewModel.canFlipSelectedAlphaChannelVertical)
        Button(L10n.text("imageEditor.action.alphaChannelRotateCounterclockwiseSelected")) {
            viewModel.rotateSelectedAlphaChannelCounterclockwise()
        }
        .disabled(!viewModel.canRotateSelectedAlphaChannelCounterclockwise)
        Button(L10n.text("imageEditor.action.alphaChannelRotateClockwiseSelected")) {
            viewModel.rotateSelectedAlphaChannelClockwise()
        }
        .disabled(!viewModel.canRotateSelectedAlphaChannelClockwise)
        Button(L10n.text("imageEditor.action.alphaChannelRotate180Selected")) {
            viewModel.rotateSelectedAlphaChannel180()
        }
        .disabled(!viewModel.canRotateSelectedAlphaChannel180)
        Button(L10n.text("imageEditor.action.alphaChannelScaleUpSelected")) {
            viewModel.scaleSelectedAlphaChannelUp()
        }
        .disabled(!viewModel.canScaleSelectedAlphaChannelUp)
        Button(L10n.text("imageEditor.action.alphaChannelScaleDownSelected")) {
            viewModel.scaleSelectedAlphaChannelDown()
        }
        .disabled(!viewModel.canScaleSelectedAlphaChannelDown)
        Button(L10n.text("imageEditor.action.alphaChannelFitCanvasSelected")) {
            viewModel.fitSelectedAlphaChannelToCanvas()
        }
        .disabled(!viewModel.canFitSelectedAlphaChannelToCanvas)
        Divider()
        Button(L10n.text("imageEditor.action.alphaChannelMoveLeftSelected")) {
            viewModel.moveSelectedAlphaChannelLeft()
        }
        .disabled(!viewModel.canMoveSelectedAlphaChannelLeft)
        Button(L10n.text("imageEditor.action.alphaChannelMoveRightSelected")) {
            viewModel.moveSelectedAlphaChannelRight()
        }
        .disabled(!viewModel.canMoveSelectedAlphaChannelRight)
        Button(L10n.text("imageEditor.action.alphaChannelMoveUpSelected")) {
            viewModel.moveSelectedAlphaChannelUp()
        }
        .disabled(!viewModel.canMoveSelectedAlphaChannelUp)
        Button(L10n.text("imageEditor.action.alphaChannelMoveDownSelected")) {
            viewModel.moveSelectedAlphaChannelDown()
        }
        .disabled(!viewModel.canMoveSelectedAlphaChannelDown)
        Button(L10n.text("imageEditor.action.alphaChannelDeleteSelected")) {
            viewModel.deleteSelectedAlphaChannel()
        }
        .disabled(!viewModel.canDeleteSelectedAlphaChannel)
        Divider()
        Button(L10n.text("imageEditor.action.alphaChannelPrevious")) {
            viewModel.selectPreviousAlphaChannel()
        }
        .disabled(!viewModel.canSelectPreviousAlphaChannel)
        Button(L10n.text("imageEditor.action.alphaChannelNext")) {
            viewModel.selectNextAlphaChannel()
        }
        .disabled(!viewModel.canSelectNextAlphaChannel)
    }

    @ViewBuilder
    private var filterMenu: some View {
        Button(L10n.text("imageEditor.action.lastFilter")) {
            viewModel.applySelectedFilter()
        }
        .keyboardShortcut("f", modifiers: [.command])
        .disabled(!viewModel.canApplySelectedFilter)
        Divider()
        Menu(L10n.text("imageEditor.menu.filter.blur")) {
            Button(ImageEditorFilter.gaussianBlur.title) {
                viewModel.selectFilter(.gaussianBlur)
            }
            Button(ImageEditorFilter.motionBlur.title) {
                viewModel.selectFilter(.motionBlur)
            }
        }
        Menu(L10n.text("imageEditor.menu.filter.sharpen")) {
            Button(ImageEditorFilter.sharpen.title) {
                viewModel.selectFilter(.sharpen)
            }
            Button(ImageEditorFilter.unsharpMask.title) {
                viewModel.selectFilter(.unsharpMask)
            }
        }
        Menu(L10n.text("imageEditor.menu.filter.noise")) {
            Button(ImageEditorFilter.addNoise.title) {
                viewModel.selectFilter(.addNoise)
            }
            Button(ImageEditorFilter.median.title) {
                viewModel.selectFilter(.median)
            }
        }
        Menu(L10n.text("imageEditor.menu.filter.pixelate")) {
            Button(ImageEditorFilter.pixelate.title) {
                viewModel.selectFilter(.pixelate)
            }
        }
        Menu(L10n.text("imageEditor.menu.filter.stylize")) {
            Button(ImageEditorFilter.emboss.title) {
                viewModel.selectFilter(.emboss)
            }
            Button(ImageEditorFilter.findEdges.title) {
                viewModel.selectFilter(.findEdges)
            }
        }
        Menu(L10n.text("imageEditor.menu.filter.distort")) {
            Button(ImageEditorFilter.offset.title) {
                viewModel.selectFilter(.offset)
            }
            Button(ImageEditorFilter.wave.title) {
                viewModel.selectFilter(.wave)
            }
            Button(ImageEditorFilter.ripple.title) {
                viewModel.selectFilter(.ripple)
            }
            Button(ImageEditorFilter.pinch.title) {
                viewModel.selectFilter(.pinch)
            }
            Button(ImageEditorFilter.spherize.title) {
                viewModel.selectFilter(.spherize)
            }
            Button(ImageEditorFilter.vignette.title) {
                viewModel.selectFilter(.vignette)
            }
        }
        Menu(L10n.text("imageEditor.menu.filter.artistic")) {
            Button(ImageEditorFilter.oilPaint.title) {
                viewModel.selectFilter(.oilPaint)
            }
        }
        Menu(L10n.text("imageEditor.menu.filter.liquify")) {
            Button(ImageEditorFilter.liquifyPush.title) {
                viewModel.selectFilter(.liquifyPush)
            }
            Button(ImageEditorFilter.liquifyTwirl.title) {
                viewModel.selectFilter(.liquifyTwirl)
            }
            Button(ImageEditorFilter.liquifyPuckerBloat.title) {
                viewModel.selectFilter(.liquifyPuckerBloat)
            }
        }
        Menu(L10n.text("imageEditor.menu.filter.other")) {
            Button(ImageEditorFilter.highPass.title) {
                viewModel.selectFilter(.highPass)
            }
            Button(ImageEditorFilter.minimum.title) {
                viewModel.selectFilter(.minimum)
            }
            Button(ImageEditorFilter.maximum.title) {
                viewModel.selectFilter(.maximum)
            }
        }
        Divider()
        Button(L10n.text("imageEditor.action.autoLevels")) {
            viewModel.autoLevelsSelectedLayer()
        }
        .disabled(!viewModel.canAutoLevelsSelectedLayer)
        Button(L10n.text("imageEditor.action.autoContrast")) {
            viewModel.autoContrastSelectedLayer()
        }
        .disabled(!viewModel.canAutoContrastSelectedLayer)
        Button(L10n.text("imageEditor.action.autoColor")) {
            viewModel.autoColorSelectedLayer()
        }
        .disabled(!viewModel.canAutoColorSelectedLayer)
        Divider()
        Button(L10n.text("imageEditor.action.applyAdjustment")) {
            viewModel.applyAdjustment()
        }
        Button(L10n.text("imageEditor.action.layerAdjustmentNew")) {
            viewModel.addAdjustmentLayer()
        }
        Button(L10n.text("imageEditor.action.layerAdjustmentUpdate")) {
            viewModel.updateSelectedAdjustmentLayer()
        }
        .disabled(!viewModel.selectedLayerIsAdjustment)
        Divider()
        Button(L10n.text("imageEditor.action.layerFilterNew")) {
            viewModel.addFilterLayer()
        }
        Button(L10n.text("imageEditor.action.layerFilterUpdate")) {
            viewModel.updateSelectedFilterLayer()
        }
        .disabled(!viewModel.selectedLayerIsFilter)
        Button(L10n.text("imageEditor.action.layerSmartFilterAdd")) {
            viewModel.addSmartFilterToSelectedLayer()
        }
        .disabled(!viewModel.canAddSmartFilterToSelectedLayer)
        Button(L10n.text("imageEditor.action.layerSmartFilterUpdate")) {
            viewModel.updateLastSmartFilterOnSelectedLayer()
        }
        .disabled(!viewModel.canUpdateLastSmartFilterOnSelectedLayer)
    }

    @ViewBuilder
    private var viewMenu: some View {
        Button(L10n.text("imageEditor.action.extrasVisible")) {
            viewModel.toggleExtrasVisible()
        }
        Divider()
        Button(L10n.text("imageEditor.action.rulersVisible")) {
            viewModel.toggleRulersVisible()
        }
        .keyboardShortcut("r", modifiers: [.command])
        Button(L10n.text("imageEditor.action.guidesVisible")) {
            viewModel.toggleGuidesVisible()
        }
        .keyboardShortcut(";", modifiers: [.command])
        Button(L10n.text("imageEditor.action.guidesSnap")) {
            viewModel.toggleGuideSnapping()
        }
        .keyboardShortcut(";", modifiers: [.command, .shift])
        Button(L10n.text("imageEditor.action.guidesLocked")) {
            viewModel.toggleGuidesLocked()
        }
        .keyboardShortcut(";", modifiers: [.command, .option])
        Button(L10n.text("imageEditor.action.selectionEdgesVisible")) {
            viewModel.toggleSelectionEdgesVisible()
        }
        Button(L10n.text("imageEditor.action.transformControlsVisible")) {
            viewModel.toggleTransformControlsVisible()
        }
        Button(L10n.text("imageEditor.action.gridVisible")) {
            viewModel.toggleGridVisible()
        }
        .keyboardShortcut("'", modifiers: [.command])
        Button(L10n.text("imageEditor.action.gridSnap")) {
            viewModel.toggleGridSnapping()
        }
        Divider()
        Button(L10n.text("imageEditor.action.guideVerticalCenter")) {
            viewModel.addVerticalGuideAtCanvasCenter()
        }
        Button(L10n.text("imageEditor.action.guideHorizontalCenter")) {
            viewModel.addHorizontalGuideAtCanvasCenter()
        }
        Button(L10n.text("imageEditor.action.guidesClear")) {
            viewModel.clearGuides()
        }
        .disabled(viewModel.document.guides.isEmpty)
        Divider()
        Button(L10n.text("imageEditor.menu.view.zoomIn")) {
            viewModel.zoomIn()
        }
        .keyboardShortcut("+", modifiers: [.command])
        Button(L10n.text("imageEditor.menu.view.zoomOut")) {
            viewModel.zoomOut()
        }
        .keyboardShortcut("-", modifiers: [.command])
        Button(L10n.text("imageEditor.menu.view.actualPixels")) {
            viewModel.zoomActualPixels()
        }
        .keyboardShortcut("1", modifiers: [.command])
        Button(L10n.text("imageEditor.menu.view.fit")) {
            viewModel.fitZoom()
        }
        .keyboardShortcut("0", modifiers: [.command])
    }

    @ViewBuilder
    private var windowMenu: some View {
        Button(L10n.text("imageEditor.action.workspaceResetDefault")) {
            viewModel.resetDefaultWorkspace()
            selectedLayerPanelTab = .layers
        }
        Button(L10n.text(viewModel.isWorkspaceChromeVisible ? "imageEditor.action.workspaceHidePanels" : "imageEditor.action.workspaceShowPanels")) {
            viewModel.toggleWorkspaceChromeVisibility()
        }
        .keyboardShortcut(.tab, modifiers: [])
        Button(L10n.text(viewModel.isRightDockVisible ? "imageEditor.action.rightDockHidePanels" : "imageEditor.action.rightDockShowPanels")) {
            viewModel.toggleRightDockVisibility()
        }
        .keyboardShortcut(.tab, modifiers: [.shift])
        Button(L10n.text(viewModel.isStatusBarVisible ? "imageEditor.action.statusBarHide" : "imageEditor.action.statusBarShow")) {
            viewModel.toggleStatusBarVisibility()
        }
        Divider()
        toolsActionsMenu
        optionsActionsMenu
        Divider()
        navigatorActionsMenu
        infoActionsMenu
        histogramActionsMenu
        colorActionsMenu
        swatchesActionsMenu
        brushesActionsMenu
        characterActionsMenu
        paragraphActionsMenu
        stylesActionsMenu
        Divider()
        layerActionsMenu
        channelActionsMenu
        layerCompActionsMenu
        Divider()
        historyActionsMenu
        Divider()
        pathActionsMenu
        Divider()
        propertiesActionsMenu
    }

    @ViewBuilder
    private var toolsActionsMenu: some View {
        Menu(L10n.text("imageEditor.menu.window.tools")) {
            Button(L10n.text("imageEditor.action.toolsShowPanel")) {
                viewModel.statusText = viewModel.toolsPanelSummaryText
            }
            Button(L10n.text(viewModel.areToolsPanelVisible ? "imageEditor.action.toolsHidePanel" : "imageEditor.action.toolsShowPanelVisibility")) {
                viewModel.toggleToolsPanelVisibility()
            }
            Divider()
            ForEach(viewModel.toolsPanelTools) { tool in
                Button(tool.title) {
                    viewModel.selectToolsPanelTool(tool)
                }
            }
        }
    }

    @ViewBuilder
    private var optionsActionsMenu: some View {
        Menu(L10n.text("imageEditor.menu.window.options")) {
            Button(L10n.text("imageEditor.action.optionsShowPanel")) {
                viewModel.statusText = viewModel.optionsPanelSummaryText
            }
            Button(L10n.text(viewModel.isOptionsBarVisible ? "imageEditor.action.optionsHideBar" : "imageEditor.action.optionsShowBar")) {
                viewModel.toggleOptionsBarVisibility()
            }
            Divider()
            Menu(L10n.text("imageEditor.menu.window.options.selectionMode")) {
                ForEach(ImageEditorSelectionMode.allCases) { mode in
                    Button(mode.title) {
                        viewModel.applyOptionsSelectionMode(mode)
                    }
                }
            }
            Menu(L10n.text("imageEditor.menu.window.options.size")) {
                ForEach([1, 4, 12, 24, 48, 96], id: \.self) { size in
                    Button(L10n.format("imageEditor.option.sizePreset", size)) {
                        viewModel.applyOptionsBrushSizePreset(size)
                    }
                }
            }
            Menu(L10n.text("imageEditor.menu.window.options.opacity")) {
                ForEach([25, 50, 75, 100], id: \.self) { percent in
                    Button(L10n.format("imageEditor.option.percentPreset", percent)) {
                        viewModel.applyOptionsOpacityPreset(percent)
                    }
                }
            }
            Menu(L10n.text("imageEditor.menu.window.options.hardness")) {
                ForEach([0, 25, 50, 75, 100], id: \.self) { percent in
                    Button(L10n.format("imageEditor.option.percentPreset", percent)) {
                        viewModel.applyOptionsHardnessPreset(percent)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var navigatorActionsMenu: some View {
        Menu(L10n.text("imageEditor.menu.window.navigator")) {
            Button(L10n.text("imageEditor.action.navigatorShowPanel")) {
                viewModel.isNavigatorPanelVisible = true
                viewModel.statusText = viewModel.sizeText
            }
            Button(L10n.text(viewModel.isNavigatorPanelVisible ? "imageEditor.action.navigatorHidePanel" : "imageEditor.action.navigatorShowPanelVisibility")) {
                viewModel.toggleNavigatorPanelVisibility()
            }
            Divider()
            Button(L10n.text("imageEditor.menu.view.zoomIn")) {
                viewModel.zoomIn()
            }
            Button(L10n.text("imageEditor.menu.view.zoomOut")) {
                viewModel.zoomOut()
            }
            Button(L10n.text("imageEditor.menu.view.actualPixels")) {
                viewModel.zoomActualPixels()
            }
            Button(L10n.text("imageEditor.menu.view.fit")) {
                viewModel.fitZoom()
            }
        }
    }

    @ViewBuilder
    private var infoActionsMenu: some View {
        Menu(L10n.text("imageEditor.menu.window.info")) {
            Button(L10n.text("imageEditor.action.infoShowPanel")) {
                viewModel.statusText = "\(viewModel.pointerText) | \(viewModel.sizeText) | \(viewModel.colorText)"
            }
            .keyboardShortcut(KeyEquivalent(Character(UnicodeScalar(NSF8FunctionKey)!)), modifiers: [])
        }
    }

    @ViewBuilder
    private var histogramActionsMenu: some View {
        Menu(L10n.text("imageEditor.menu.window.histogram")) {
            Button(L10n.text("imageEditor.action.histogramShowPanel")) {
                let summary = viewModel.histogramSummary
                viewModel.statusText = [
                    viewModel.histogramAverageText(for: summary),
                    viewModel.histogramLuminanceText(for: summary),
                    viewModel.histogramClippingText(for: summary)
                ].joined(separator: " | ")
            }
        }
    }

    @ViewBuilder
    private var colorActionsMenu: some View {
        Menu(L10n.text("imageEditor.menu.window.color")) {
            Button(L10n.text("imageEditor.action.colorShowPanel")) {
                viewModel.statusText = viewModel.colorPanelSummaryText
            }
            .keyboardShortcut(KeyEquivalent(Character(UnicodeScalar(NSF6FunctionKey)!)), modifiers: [])
            Divider()
            Button(L10n.text("imageEditor.action.colorDefaultForegroundBackground")) {
                viewModel.resetForegroundBackgroundColors()
            }
            Button(L10n.text("imageEditor.action.colorSwapForegroundBackground")) {
                viewModel.swapForegroundBackgroundColors()
            }
            Divider()
            Button(L10n.text("imageEditor.action.colorUseEyedropper")) {
                viewModel.selectEyedropperForColorSampling()
            }
        }
    }

    @ViewBuilder
    private var swatchesActionsMenu: some View {
        Menu(L10n.text("imageEditor.menu.window.swatches")) {
            Button(L10n.text("imageEditor.action.swatchesShowPanel")) {
                viewModel.statusText = viewModel.swatchesPanelSummaryText
            }
            Divider()
            Menu(L10n.text("imageEditor.menu.window.swatches.foreground")) {
                ForEach(ImageEditorColorSwatch.defaultPalette) { swatch in
                    Button(swatch.title) {
                        viewModel.applySwatchToForeground(swatch)
                    }
                }
            }
            Menu(L10n.text("imageEditor.menu.window.swatches.background")) {
                ForEach(ImageEditorColorSwatch.defaultPalette) { swatch in
                    Button(swatch.title) {
                        viewModel.applySwatchToBackground(swatch)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var brushesActionsMenu: some View {
        Menu(L10n.text("imageEditor.menu.window.brushes")) {
            Button(L10n.text("imageEditor.action.brushesShowPanel")) {
                viewModel.statusText = viewModel.brushesPanelSummaryText
            }
            .keyboardShortcut(KeyEquivalent(Character(UnicodeScalar(NSF5FunctionKey)!)), modifiers: [])
            Divider()
            Menu(L10n.text("imageEditor.menu.window.brushes.tools")) {
                ForEach(viewModel.brushPanelTools) { tool in
                    Button(tool.title) {
                        viewModel.selectBrushPanelTool(tool)
                    }
                }
            }
            Menu(L10n.text("imageEditor.menu.window.brushes.presets")) {
                ForEach(viewModel.brushPresets) { preset in
                    Button {
                        viewModel.applyBrushPreset(preset)
                    } label: {
                        if viewModel.activeBrushPreset?.id == preset.id {
                            Label(preset.title, systemImage: "checkmark")
                        } else {
                            Text(preset.title)
                        }
                    }
                }
                Divider()
                Button(L10n.text("imageEditor.action.brushPresetCreate")) {
                    viewModel.createBrushPresetFromCurrentSettings()
                }
                if let activePreset = viewModel.activeBrushPreset, !activePreset.isBuiltIn {
                    Button(L10n.text("imageEditor.action.brushPresetDelete"), role: .destructive) {
                        viewModel.deleteBrushPreset(activePreset)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var characterActionsMenu: some View {
        Menu(L10n.text("imageEditor.menu.window.character")) {
            Button(L10n.text("imageEditor.action.characterShowPanel")) {
                viewModel.statusText = viewModel.characterPanelSummaryText
            }
            Divider()
            Button(L10n.text("imageEditor.action.characterSelectTextTool")) {
                viewModel.selectCharacterPanelTool()
            }
            Button(L10n.text("imageEditor.action.characterToggleBold")) {
                viewModel.toggleCharacterBold()
            }
            Button(L10n.text("imageEditor.action.characterToggleItalic")) {
                viewModel.toggleCharacterItalic()
            }
            Button(L10n.text("imageEditor.action.characterToggleUnderline")) {
                viewModel.toggleCharacterUnderline()
            }
            Button(L10n.text("imageEditor.action.characterToggleStrikethrough")) {
                viewModel.toggleCharacterStrikethrough()
            }
            Divider()
            Button(L10n.text("imageEditor.action.layerTextNew")) {
                viewModel.addText()
            }
            Button(L10n.text("imageEditor.action.layerTextUpdate")) {
                viewModel.updateSelectedTextLayer()
            }
            .disabled(!viewModel.selectedLayerIsText)
        }
    }

    @ViewBuilder
    private var paragraphActionsMenu: some View {
        Menu(L10n.text("imageEditor.menu.window.paragraph")) {
            Button(L10n.text("imageEditor.action.paragraphShowPanel")) {
                viewModel.statusText = viewModel.paragraphPanelSummaryText
            }
            Divider()
            ForEach(ImageEditorTextAlignment.allCases) { alignment in
                Button(alignment.title) {
                    viewModel.selectParagraphAlignment(alignment)
                }
            }
            Divider()
            Button(L10n.text("imageEditor.action.textConvertToPoint")) {
                viewModel.convertSelectedTextLayers(to: .point)
            }
            .disabled(!viewModel.canConvertSelectedTextToPoint)
            Button(L10n.text("imageEditor.action.textConvertToParagraph")) {
                viewModel.convertSelectedTextLayers(to: .paragraph)
            }
            .disabled(!viewModel.canConvertSelectedTextToParagraph)
            Divider()
            Button(L10n.text("imageEditor.action.textBoxFitContent")) {
                viewModel.fitSelectedTextBoxes(.fitContent)
            }
            .disabled(!viewModel.canFitSelectedTextBoxesToContent)
            Button(L10n.text("imageEditor.action.textBoxExpandHeight")) {
                viewModel.fitSelectedTextBoxes(.expandHeight)
            }
            .disabled(!viewModel.canExpandSelectedTextBoxes)
            Divider()
            Button(L10n.text("imageEditor.action.layerTextUpdate")) {
                viewModel.updateSelectedTextLayer()
            }
            .disabled(!viewModel.selectedLayerIsText)
        }
    }

    @ViewBuilder
    private var stylesActionsMenu: some View {
        Menu(L10n.text("imageEditor.menu.window.styles")) {
            Button(L10n.text("imageEditor.action.stylesShowPanel")) {
                viewModel.statusText = viewModel.stylesPanelSummaryText
            }
            Divider()
            layerStyleActionItems
        }
    }

    @ViewBuilder
    private var layerActionsMenu: some View {
        Menu(L10n.text("imageEditor.menu.window.layers")) {
            Button(L10n.text("imageEditor.action.layersShowPanel")) {
                viewModel.isLayersPanelVisible = true
                selectedLayerPanelTab = .layers
            }
            .keyboardShortcut(KeyEquivalent(Character(UnicodeScalar(NSF7FunctionKey)!)), modifiers: [])
            Button(L10n.text(viewModel.isLayersPanelVisible ? "imageEditor.action.layersHidePanel" : "imageEditor.action.layersShowPanelVisibility")) {
                viewModel.toggleLayersPanelVisibility()
            }
            Divider()
            Button(L10n.text("imageEditor.action.layerNew")) {
                selectedLayerPanelTab = .layers
                viewModel.addLayer()
            }
            Button(L10n.text("imageEditor.action.layerDuplicate")) {
                selectedLayerPanelTab = .layers
                viewModel.duplicateSelectedLayer()
            }
            .disabled(!viewModel.canDuplicateSelectedLayer)
            Button(L10n.text("imageEditor.action.layerDelete")) {
                selectedLayerPanelTab = .layers
                viewModel.deleteSelectedLayer()
            }
            .disabled(!viewModel.canDeleteLayer)
            Divider()
            Button(L10n.text("imageEditor.action.layerGroupNew")) {
                selectedLayerPanelTab = .layers
                viewModel.addLayerGroup()
            }
            Button(L10n.text("imageEditor.action.layerGroupSelected")) {
                selectedLayerPanelTab = .layers
                viewModel.groupSelectedLayer()
            }
            .disabled(!viewModel.canGroupSelectedLayer)
            Divider()
            Button(L10n.text(viewModel.mergeDownActionTitleKey)) {
                selectedLayerPanelTab = .layers
                viewModel.mergeSelectedLayerDown()
            }
            .disabled(!viewModel.canMergeSelectedLayerDown)
            Button(L10n.text("imageEditor.action.layerFlatten")) {
                selectedLayerPanelTab = .layers
                viewModel.flattenImage()
            }
            .disabled(!viewModel.canFlattenImage)
        }
    }

    @ViewBuilder
    private var layerCompActionsMenu: some View {
        Menu(L10n.text("imageEditor.menu.window.layerComps")) {
            Button(L10n.text("imageEditor.action.layerCompsShowPanel")) {
                viewModel.isLayersPanelVisible = true
                selectedLayerPanelTab = .comps
            }
            Divider()
            Button(L10n.text("imageEditor.action.layerCompNew")) {
                selectedLayerPanelTab = .comps
                viewModel.addLayerComp()
            }
            Button(L10n.text("imageEditor.action.layerCompApply")) {
                selectedLayerPanelTab = .comps
                viewModel.applySelectedLayerComp()
            }
            .disabled(!viewModel.canApplySelectedLayerComp)
            Button(L10n.text("imageEditor.action.layerCompUpdate")) {
                selectedLayerPanelTab = .comps
                viewModel.updateSelectedLayerComp()
            }
            .disabled(!viewModel.canUpdateSelectedLayerComp)
            Button(L10n.text("imageEditor.action.layerCompDuplicate")) {
                selectedLayerPanelTab = .comps
                viewModel.duplicateSelectedLayerComp()
            }
            .disabled(!viewModel.canDuplicateSelectedLayerComp)
            Button(L10n.text("imageEditor.action.layerCompDelete")) {
                selectedLayerPanelTab = .comps
                viewModel.deleteSelectedLayerComp()
            }
            .disabled(!viewModel.canDeleteSelectedLayerComp)
            Divider()
            Button(L10n.text("imageEditor.action.layerCompPrevious")) {
                selectedLayerPanelTab = .comps
                viewModel.selectPreviousLayerComp()
            }
            .disabled(!viewModel.canSelectPreviousLayerComp)
            Button(L10n.text("imageEditor.action.layerCompNext")) {
                selectedLayerPanelTab = .comps
                viewModel.selectNextLayerComp()
            }
            .disabled(!viewModel.canSelectNextLayerComp)
        }
    }

    @ViewBuilder
    private var historyActionsMenu: some View {
        Menu(L10n.text("imageEditor.menu.window.history")) {
            Button(L10n.text("imageEditor.action.historyShowPanel")) {
                viewModel.isHistoryPanelVisible = true
                viewModel.statusText = viewModel.historyStateSummary
            }
            Button(L10n.text(viewModel.isHistoryPanelVisible ? "imageEditor.action.historyHidePanel" : "imageEditor.action.historyShowPanelVisibility")) {
                viewModel.toggleHistoryPanelVisibility()
            }
            Divider()
            Button(L10n.text("imageEditor.action.historySnapshotCreate")) {
                viewModel.createHistorySnapshot()
            }
            Button(L10n.text("imageEditor.action.historySnapshotRestoreSelected")) {
                viewModel.restoreSelectedHistorySnapshot()
            }
            .disabled(!viewModel.canRestoreSelectedHistorySnapshot)
            Button(L10n.text("imageEditor.action.historySnapshotDuplicate")) {
                viewModel.duplicateSelectedHistorySnapshot()
            }
            .disabled(!viewModel.canDuplicateSelectedHistorySnapshot)
            Button(L10n.text("imageEditor.action.historySnapshotDeleteSelected")) {
                viewModel.deleteSelectedHistorySnapshot()
            }
            .disabled(!viewModel.canDeleteSelectedHistorySnapshot)
            Divider()
            Button(L10n.text("imageEditor.action.historySnapshotPrevious")) {
                viewModel.selectPreviousHistorySnapshot()
            }
            .disabled(!viewModel.canSelectPreviousHistorySnapshot)
            Button(L10n.text("imageEditor.action.historySnapshotNext")) {
                viewModel.selectNextHistorySnapshot()
            }
            .disabled(!viewModel.canSelectNextHistorySnapshot)
            Divider()
            Button(L10n.text("imageEditor.action.historyClear")) {
                viewModel.clearHistoryStates()
            }
        }
    }

    @ViewBuilder
    private var propertiesActionsMenu: some View {
        Menu(L10n.text("imageEditor.menu.window.properties")) {
            Button(L10n.text("imageEditor.action.propertiesShowPanel")) {
                viewModel.isPropertiesPanelVisible = true
                viewModel.statusText = L10n.text("imageEditor.status.propertiesVisible")
            }
            Button(L10n.text(viewModel.isPropertiesPanelVisible ? "imageEditor.action.propertiesHidePanel" : "imageEditor.action.propertiesShowPanelVisibility")) {
                viewModel.togglePropertiesPanelVisibility()
            }
            Divider()
            Button(L10n.text("imageEditor.action.applyAdjustment")) {
                viewModel.applyAdjustment()
            }
            Button(L10n.text("imageEditor.action.layerAdjustmentNew")) {
                viewModel.addAdjustmentLayer()
            }
            Button(L10n.text("imageEditor.action.layerAdjustmentUpdate")) {
                viewModel.updateSelectedAdjustmentLayer()
            }
            .disabled(!viewModel.selectedLayerIsAdjustment)
            Divider()
            Button(L10n.text("imageEditor.action.layerFilterNew")) {
                viewModel.addFilterLayer()
            }
            Button(L10n.text("imageEditor.action.layerFilterUpdate")) {
                viewModel.updateSelectedFilterLayer()
            }
            .disabled(!viewModel.selectedLayerIsFilter)
            Button(L10n.text("imageEditor.action.layerSmartFilterAdd")) {
                viewModel.addSmartFilterToSelectedLayer()
            }
            .disabled(!viewModel.canAddSmartFilterToSelectedLayer)
            Button(L10n.text("imageEditor.action.layerSmartFilterUpdate")) {
                viewModel.updateLastSmartFilterOnSelectedLayer()
            }
            .disabled(!viewModel.canUpdateLastSmartFilterOnSelectedLayer)
            Divider()
            Button(L10n.text("imageEditor.action.addText")) {
                viewModel.addText()
            }
        }
    }

    @ViewBuilder
    private var channelActionsMenu: some View {
        Menu(L10n.text("imageEditor.menu.window.channels")) {
            Button(L10n.text("imageEditor.action.channelsShowPanel")) {
                viewModel.isLayersPanelVisible = true
                selectedLayerPanelTab = .channels
            }
            Divider()
            Menu(L10n.text("imageEditor.menu.window.channels.preview")) {
                ForEach(ImageEditorChannelPreview.allCases) { channel in
                    Button(channel.title) {
                        selectedLayerPanelTab = .channels
                        viewModel.selectChannelPreview(channel)
                    }
                }
            }
            Menu(L10n.text("imageEditor.menu.window.channels.selection")) {
                ForEach(ImageEditorChannelPreview.allCases) { channel in
                    Button(L10n.format("imageEditor.action.channelLoadSelection", channel.title)) {
                        selectedLayerPanelTab = .channels
                        viewModel.selectChannelPreview(channel)
                        viewModel.loadSelectionFromChannel(channel)
                    }
                }
            }
            Menu(L10n.text("imageEditor.menu.window.channels.alpha")) {
                Button(L10n.text("imageEditor.action.alphaChannelBlank")) {
                    selectedLayerPanelTab = .channels
                    viewModel.createBlankAlphaChannel()
                }
                .disabled(!viewModel.canCreateBlankAlphaChannel)
                Button(L10n.text("imageEditor.action.channelSaveSelection")) {
                    selectedLayerPanelTab = .channels
                    viewModel.saveSelectionAsAlphaChannel()
                }
                .disabled(!viewModel.canSaveSelectionAsAlphaChannel)
                Button(L10n.text("imageEditor.action.channelSaveLayerMask")) {
                    selectedLayerPanelTab = .channels
                    viewModel.saveSelectedLayerMaskAsAlphaChannel()
                }
                .disabled(!viewModel.canSaveSelectedLayerMaskAsAlphaChannel)
                Button(L10n.text("imageEditor.action.channelSaveLayerTransparency")) {
                    selectedLayerPanelTab = .channels
                    viewModel.saveSelectedLayerTransparencyAsAlphaChannel()
                }
                .disabled(!viewModel.canSaveSelectedLayerTransparencyAsAlphaChannel)
                Divider()
                Button(L10n.text("imageEditor.action.channelSaveCurrentAsAlpha")) {
                    selectedLayerPanelTab = .channels
                    viewModel.saveSelectedChannelAsAlphaChannel()
                }
                .disabled(!viewModel.canSaveSelectedChannelAsAlphaChannel)
            }
            Divider()
            Button(L10n.text("imageEditor.action.alphaChannelLoadSelectedSelection")) {
                selectedLayerPanelTab = .channels
                viewModel.loadSelectionFromSelectedAlphaChannel()
            }
            .disabled(!viewModel.canLoadSelectedAlphaChannelSelection)
            Button(L10n.text("imageEditor.action.alphaChannelUpdateSelected")) {
                selectedLayerPanelTab = .channels
                viewModel.updateSelectedAlphaChannelFromSelection()
            }
            .disabled(!viewModel.canUpdateSelectedAlphaChannelFromSelection)
            Button(L10n.text("imageEditor.action.alphaChannelApplySelectedToMask")) {
                selectedLayerPanelTab = .channels
                viewModel.applySelectedAlphaChannelToSelectedLayerMask()
            }
            .disabled(!viewModel.canApplySelectedAlphaChannelToLayerMask)
            Button(L10n.text("imageEditor.action.alphaChannelLayerSelected")) {
                selectedLayerPanelTab = .channels
                viewModel.createLayerFromSelectedAlphaChannel()
            }
            .disabled(!viewModel.canCreateLayerFromSelectedAlphaChannel)
            Button(L10n.text("imageEditor.action.alphaChannelDuplicateSelected")) {
                selectedLayerPanelTab = .channels
                viewModel.duplicateSelectedAlphaChannel()
            }
            .disabled(!viewModel.canDuplicateSelectedAlphaChannel)
            Button(L10n.text("imageEditor.action.alphaChannelInvertSelected")) {
                selectedLayerPanelTab = .channels
                viewModel.invertSelectedAlphaChannel()
            }
            .disabled(!viewModel.canInvertSelectedAlphaChannel)
            Button(L10n.text("imageEditor.action.alphaChannelDeleteSelected")) {
                selectedLayerPanelTab = .channels
                viewModel.deleteSelectedAlphaChannel()
            }
            .disabled(!viewModel.canDeleteSelectedAlphaChannel)
        }
    }

    @ViewBuilder
    private var pathActionsMenu: some View {
        Menu(L10n.text("imageEditor.menu.window.paths")) {
            Button(L10n.text("imageEditor.action.savedPathSave")) {
                if let savedPath = viewModel.saveCurrentPath(name: nil) {
                    selectedLayerPanelTab = .paths
                    savedPathNameDrafts[savedPath.id] = savedPath.name
                }
            }
            .disabled(!viewModel.canSaveCurrentPath)
            Button(L10n.text("imageEditor.action.savedPathCopy")) {
                guard let id = viewModel.document.selectedSavedPathID else { return }
                selectedLayerPanelTab = .paths
                viewModel.copySavedPath(id)
            }
            .disabled(viewModel.selectedSavedPath == nil)
            Button(L10n.text("imageEditor.action.savedPathPaste")) {
                selectedLayerPanelTab = .paths
                if let savedPath = viewModel.pasteSavedPath() {
                    savedPathNameDrafts[savedPath.id] = savedPath.name
                }
            }
            Button(L10n.text("imageEditor.action.savedPathMoveUp")) {
                guard let id = viewModel.document.selectedSavedPathID else { return }
                selectedLayerPanelTab = .paths
                viewModel.moveSavedPathUp(id)
            }
            .disabled(!viewModel.canMoveSelectedSavedPathUp)
            Button(L10n.text("imageEditor.action.savedPathMoveDown")) {
                guard let id = viewModel.document.selectedSavedPathID else { return }
                selectedLayerPanelTab = .paths
                viewModel.moveSavedPathDown(id)
            }
            .disabled(!viewModel.canMoveSelectedSavedPathDown)
            Button(L10n.text("imageEditor.action.savedPathLoad")) {
                guard let id = viewModel.document.selectedSavedPathID else { return }
                selectedLayerPanelTab = .paths
                viewModel.loadSavedPath(id)
            }
            .disabled(viewModel.selectedSavedPath == nil)
            Button(L10n.text("imageEditor.action.savedPathSelection")) {
                guard let id = viewModel.document.selectedSavedPathID else { return }
                selectedLayerPanelTab = .paths
                viewModel.loadSelectionFromSavedPath(id)
            }
            .disabled(!viewModel.canLoadSelectionFromSelectedSavedPath)
            Button(L10n.text("imageEditor.action.savedPathFill")) {
                guard let id = viewModel.document.selectedSavedPathID else { return }
                selectedLayerPanelTab = .paths
                viewModel.fillSavedPathToSelectedPixelLayer(id)
            }
            .disabled(!viewModel.canFillSelectedSavedPathToPixelLayer)
            Button(L10n.text("imageEditor.action.savedPathStroke")) {
                guard let id = viewModel.document.selectedSavedPathID else { return }
                selectedLayerPanelTab = .paths
                viewModel.strokeSavedPathToSelectedPixelLayer(id)
            }
            .disabled(!viewModel.canStrokeSelectedSavedPathToPixelLayer)
            Button(L10n.text("imageEditor.action.savedPathUpdate")) {
                guard let id = viewModel.document.selectedSavedPathID else { return }
                selectedLayerPanelTab = .paths
                viewModel.updateSavedPath(id)
            }
            .disabled(viewModel.selectedSavedPath == nil || !viewModel.hasEditableCurrentPath)
            Button(L10n.text("imageEditor.action.savedPathDelete")) {
                guard let id = viewModel.document.selectedSavedPathID else { return }
                selectedLayerPanelTab = .paths
                viewModel.deleteSavedPath(id)
            }
            .disabled(viewModel.selectedSavedPath == nil)
            Divider()
            Button(L10n.text("imageEditor.action.pathStroke")) {
                viewModel.strokeSelectedPathToPixelLayer()
            }
            .disabled(!viewModel.canStrokeSelectedPathToPixelLayer)
            Button(L10n.text("imageEditor.action.pathFill")) {
                viewModel.fillSelectedPathToPixelLayer()
            }
            .disabled(!viewModel.canFillSelectedPathToPixelLayer)
            Button(L10n.text("imageEditor.action.pathSelection")) {
                viewModel.loadSelectionFromSelectedPath()
            }
            .disabled(!viewModel.canLoadSelectionFromSelectedPath)
            Button(L10n.text("imageEditor.action.pathVectorMask")) {
                viewModel.applySelectedPathAsVectorMask()
            }
            .disabled(!viewModel.canApplySelectedPathAsVectorMask)
            Button(L10n.text("imageEditor.action.pathLayerMask")) {
                viewModel.applySelectedPathAsLayerMask()
            }
            .disabled(!viewModel.canApplySelectedPathAsLayerMask)
        }
    }
}

private struct EditorMenuActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        EditorMenuButtonSurface(
            label: configuration.label,
            isPressed: configuration.isPressed,
            foreground: Color(nsColor: ImageEditorTheme.menuText),
            normalBackground: Color.white.opacity(0.075),
            hoverBackground: Color.white.opacity(0.14),
            pressedBackground: Color(nsColor: ImageEditorTheme.selected).opacity(0.56),
            border: Color.white.opacity(0.11)
        )
    }
}

private struct EditorMenuSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        EditorMenuButtonSurface(
            label: configuration.label,
            isPressed: configuration.isPressed,
            foreground: Color(nsColor: ImageEditorTheme.menuMutedText),
            normalBackground: Color.white.opacity(0.035),
            hoverBackground: Color.white.opacity(0.095),
            pressedBackground: Color.white.opacity(0.15),
            border: Color.white.opacity(0.08)
        )
    }
}

private struct EditorMenuPreviewButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        EditorMenuButtonSurface(
            label: configuration.label,
            isPressed: configuration.isPressed,
            foreground: Color(nsColor: ImageEditorTheme.menuText),
            normalBackground: Color(nsColor: ImageEditorTheme.selected).opacity(0.70),
            hoverBackground: Color(nsColor: ImageEditorTheme.selected).opacity(0.88),
            pressedBackground: Color(nsColor: ImageEditorTheme.selected).opacity(0.54),
            border: Color.white.opacity(0.18)
        )
    }
}

private struct EditorExportButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        EditorMenuButtonSurface(
            label: configuration.label,
            isPressed: configuration.isPressed,
            foreground: .white,
            normalBackground: Color(nsColor: ImageEditorTheme.exportAccent),
            hoverBackground: Color(nsColor: ImageEditorTheme.exportAccent).opacity(0.86),
            pressedBackground: Color(nsColor: ImageEditorTheme.exportAccentPressed),
            border: Color.white.opacity(0.22)
        )
    }
}

private struct EditorMenuButtonSurface<Label: View>: View {
    let label: Label
    let isPressed: Bool
    let foreground: Color
    let normalBackground: Color
    let hoverBackground: Color
    let pressedBackground: Color
    let border: Color
    @State private var isHovered = false

    var body: some View {
        label
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 11)
            .frame(height: 28)
            .foregroundStyle(foreground)
            .background(isPressed ? pressedBackground : (isHovered ? hoverBackground : normalBackground))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(border, lineWidth: 1)
            }
            .onHover { isHovered = $0 }
            .focusable(false)
    }
}
