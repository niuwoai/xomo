# rc166 PSD 专色通道验证

日期：2026-07-17

## 结果

- `build-for-testing`：通过。
- `swift test --package-path xomo-cli`：2/2 通过。
- `psdExportPreservesSpotChannelDisplayInfoAndProjectRoundTrip`：通过。
- `psdExportPreservesExtraAlphaChannelsAndNames`：隔离复跑通过。
- `psdExportPreservesClosedAndOpenSavedPaths`：隔离复跑通过。
- `ImageEditorPSDTests` 完整套件：18 个测试中 8 个通过、10 个失败。

完整套件的失败集中在已有的外部 fixture、可编辑文字、矢量/路径资源和一个蒙版回归；本次新增的 Spot 通道测试没有失败。后续 rc 会单独处理这些既有回归，避免把它们和 Spot DisplayInfo 支持混在一起。
