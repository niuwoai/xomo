# rc290 组件拖拽与工具光标回归报告

- 生成时间：2026-07-18 20:06:27 +0800
- 版本：`2.12.0-rc290`
- 环境：macOS 26.5.2 / Xcode 17E202 / arm64
- 总数：**21**，通过：**21**，失败：**0**，跳过：**0**

✅ 本次变更相关的窄范围回归全部通过。

## 覆盖范围

- 组件库模式的组件命中、父画布拖拽兜底和移动手势接线。
- 移动过程中的实时虚线预览，以及释放时才提交位置。
- 组件模式、移动、选择、裁切、缩放、画笔精度等工具光标的通用语义。

## 执行命令

```text
xcodebuild test -project veilpic.xcodeproj -scheme veilpic -destination 'platform=macOS' \
  -only-testing:veilpicTests/XomoLeftSidebarTests/componentSidebarWiresMoveSemanticsIntoCanvasCursorAndGestures \
  -only-testing:veilpicTests/XomoCanvasObjectTests/movingAnObjectPublishesAndClearsItsDashedPreviewFrame \
  -only-testing:veilpicTests/XomoCanvasObjectTests/repeatedDragUpdatesAccumulateInThePreviewBeforeCommit \
  -only-testing:veilpicTests/XomoCanvasObjectTests/componentsTabRoutesCanvasInputThroughMoveTool \
  -only-testing:veilpicTests/ImageEditorCanvasCursorTests
```

