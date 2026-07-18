# veilpicTests rc280 完整门禁报告

- 生成时间：2026-07-18 09:43:11.270 UTC
- 总测试数：1053
- 通过：1053
- 失败：0
- macOS 13 测试目标：是

## 执行说明

- 1051 个测试由 4 路独立 xcodebuild test-without-building 完成，所有日志均包含 TEST EXECUTE SUCCEEDED。
- 两个尾部 worker 连续约一小时无 CPU、无输出，确认是测试进程卡死而不是断言失败后停止。
- ImageEditorCanvasCommandTests/canvasRotationCommandsTransformLayerFramesAndHistory 已串行 1/1 通过。
- ImageEditorRasterizeStyleAndApplyMaskTests/applyVectorMaskRemovesOnlyVectorMaskAndPreservesRasterMaskAndLayerAppearance 已串行 1/1 通过。

因此 1053/1053 个独立测试均有成功证据；并行卡死情况保留在本报告中，便于后续优化测试编排。
