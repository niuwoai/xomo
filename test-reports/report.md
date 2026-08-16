# veilpicTests 独立进程测试报告

- 汇总时间：2026-08-16 23:42:39 +0800
- 执行组：**2252**，通过：**2252**，失败：**0**
- 覆盖测试：**2252**，通过组内测试：**2252**，失败组内测试：**0**
- 并行度（jobs）：1

✅ 全部通过。

## 重验说明

- 首轮完整隔离执行为 2250/2252；两条失败均为生产接线演进后的过时源码契约。
- 修正契约后逐条重跑通过，并完整重跑 ImageEditorScopeTests 173/173 与 XomoLeftSidebarTests 54/54。

## 按套件汇总

| 套件 | 通过/总数 |
|---|---|
| ClipboardImageWriterTests | 9/9 |
| ImageEditorAdjustmentTests | 28/28 |
| ImageEditorBackgroundLayerConversionTests | 7/7 |
| ImageEditorBevelAngleTransactionTests | 3/3 |
| ImageEditorBevelDirectionTransactionTests | 3/3 |
| ImageEditorBevelHighlightColorTransactionTests | 3/3 |
| ImageEditorBevelOpacityTransactionTests | 3/3 |
| ImageEditorBevelShadowColorTransactionTests | 3/3 |
| ImageEditorBevelSizeTransactionTests | 3/3 |
| ImageEditorBevelSoftenTransactionTests | 3/3 |
| ImageEditorBlendModeTests | 5/5 |
| ImageEditorBrushDynamicsPreferencesTests | 9/9 |
| ImageEditorBrushStrokeTests | 27/27 |
| ImageEditorCanvasCommandTests | 8/8 |
| ImageEditorCanvasCursorTests | 84/84 |
| ImageEditorCanvasGeometryTests | 4/4 |
| ImageEditorCenteredResizeTests | 6/6 |
| ImageEditorChannelTests | 50/50 |
| ImageEditorCloneStampSamplingTests | 8/8 |
| ImageEditorColorWellTests | 6/6 |
| ImageEditorDarkPanelControlsTests | 6/6 |
| ImageEditorEffectiveSelectionAutomationTests | 1/1 |
| ImageEditorEmptySelectionGeometryTests | 3/3 |
| ImageEditorEmptySelectionNudgeTests | 1/1 |
| ImageEditorExportFormatTests | 40/40 |
| ImageEditorFigmaProvenanceTests | 7/7 |
| ImageEditorFilterTests | 51/51 |
| ImageEditorGlobalLightLinkAutomationTests | 2/2 |
| ImageEditorGradientSelectionTests | 10/10 |
| ImageEditorGuideTests | 37/37 |
| ImageEditorHealingBrushTests | 11/11 |
| ImageEditorHistoryTests | 14/14 |
| ImageEditorLayerBatchAppearanceTests | 6/6 |
| ImageEditorLayerCompTests | 6/6 |
| ImageEditorLayerCompositeHierarchyTests | 8/8 |
| ImageEditorLayerDeletionTests | 6/6 |
| ImageEditorLayerDuplicateTests | 8/8 |
| ImageEditorLayerGroupExpansionTests | 4/4 |
| ImageEditorLayerGroupMovementConsistencyTests | 6/6 |
| ImageEditorLayerGroupingConsistencyTests | 7/7 |
| ImageEditorLayerMergeHierarchyTests | 10/10 |
| ImageEditorLayerPanelStyleTests | 8/8 |
| ImageEditorLayerRangeSelectionTests | 6/6 |
| ImageEditorLayerRowBatchPropertyTests | 139/139 |
| ImageEditorLayerStyleBuiltInPresetTests | 6/6 |
| ImageEditorLayerStylePresetManagerTests | 7/7 |
| ImageEditorLayerStylePresetQueryTests | 4/4 |
| ImageEditorLayerStylePresetTests | 5/5 |
| ImageEditorLayerStylePresetUsageTests | 5/5 |
| ImageEditorLayerStyleTests | 94/94 |
| ImageEditorLayerStyleVisibilityScaleTests | 8/8 |
| ImageEditorObjectDragConstraintTests | 5/5 |
| ImageEditorOptionsBarStyleTests | 2/2 |
| ImageEditorPSDTests | 54/54 |
| ImageEditorPaintBucketTests | 7/7 |
| ImageEditorParagraphLayoutTests | 7/7 |
| ImageEditorPatchToolTests | 5/5 |
| ImageEditorProjectDocumentTests | 13/13 |
| ImageEditorQuickMaskPreferencesTests | 3/3 |
| ImageEditorRasterizeStyleAndApplyMaskTests | 6/6 |
| ImageEditorRasterizeTargetTests | 7/7 |
| ImageEditorSampledBrushPreviewTests | 3/3 |
| ImageEditorSatinAutomationTransactionTests | 1/1 |
| ImageEditorSavedPathTests | 30/30 |
| ImageEditorScopeTests | 173/173 |
| ImageEditorSelectionCenteringTests | 2/2 |
| ImageEditorSelectionDeliveryBoundsTests | 2/2 |
| ImageEditorSelectionEdgeTests | 9/9 |
| ImageEditorSelectionExportBoundsTests | 2/2 |
| ImageEditorSelectionFillCoverageTests | 33/33 |
| ImageEditorSelectionInfoBoundsTests | 2/2 |
| ImageEditorSelectionOperationTests | 44/44 |
| ImageEditorSelectionPixelAvailabilityTests | 2/2 |
| ImageEditorSelectionResourceAvailabilityTests | 4/4 |
| ImageEditorSelectionSnapshotAvailabilityTests | 4/4 |
| ImageEditorSelectionTargetBoundsTests | 4/4 |
| ImageEditorShapeCornerRadiusTests | 6/6 |
| ImageEditorShapeStyleTests | 35/35 |
| ImageEditorSpongeModeShortcutTests | 5/5 |
| ImageEditorStackLayoutTests | 35/35 |
| ImageEditorTextBoxCreationTests | 12/12 |
| ImageEditorTextDecorationTests | 7/7 |
| ImageEditorTextEditingLifecycleTests | 4/4 |
| ImageEditorTextHitTestingTests | 4/4 |
| ImageEditorTextInputShortcutTests | 5/5 |
| ImageEditorTextLayoutModeTests | 13/13 |
| ImageEditorToneAirbrushTests | 4/4 |
| ImageEditorToneRangeShortcutTests | 5/5 |
| ImageEditorToolCoordinateTests | 11/11 |
| ImageEditorToolSmokeTests | 35/35 |
| ImageEditorTransformCancellationTests | 2/2 |
| ImageEditorTransformHUDTests | 8/8 |
| ImageEditorTransformLockTests | 4/4 |
| ImageEditorTransformReferencePointTests | 7/7 |
| ImageEditorTransparentPixelLockTests | 2/2 |
| ImageEditorVectorLayerTests | 106/106 |
| ImageEditorVisibleLayerOrderingTests | 6/6 |
| LocalizationResourceTests | 33/33 |
| SomeIMUpdateConfigurationTests | 1/1 |
| XomoAutomationTests | 253/253 |
| XomoCanvasObjectTests | 72/72 |
| XomoCanvasPresetTests | 5/5 |
| XomoExternalDocumentOpenTests | 4/4 |
| XomoFigmaAuthorizedMetadataTests | 8/8 |
| XomoFigmaExportPresetTests | 4/4 |
| XomoFigmaImageAssetTests | 8/8 |
| XomoFigmaImageFilterTests | 4/4 |
| XomoFigmaLinkImportTests | 8/8 |
| XomoFigmaLinkParserTests | 8/8 |
| XomoFigmaNodeImportPlanTests | 94/94 |
| XomoLayerStyleScaleAutomationTests | 1/1 |
| XomoLeftSidebarTests | 54/54 |
| XomoSelectionGetAutomationTests | 1/1 |
| veilpicTests | 156/156 |
