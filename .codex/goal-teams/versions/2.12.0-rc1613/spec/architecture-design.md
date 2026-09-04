# rc1613 Architecture Design

## 共用漏斗

四种缩画布入口均进入 `ImageEditorViewModel.crop(to:historyTitle:)`。在该函数的 `pushUndo()` 前，与 Hotspot 同一 `do` 中对全部 Slice 调用：

```swift
try slice.offsetForCanvasResize(
    offset: offset,
    sourceCanvasSize: originalSize,
    targetCanvasSize: targetSize
)
```

用稳定 `compactMap` 保序并移除合法空交集。任一 throw 设置既有 resize invalid 状态并返回；成功提交 `document.slices` 后调用 `syncExportSettingsForCurrentSliceScope()`。

## 原子顺序

裁剪框验证 → Slice/Hotspot 全量预计算 → 图层、参考线和其它画布状态预计算 → `pushUndo()` → 一次性写文档 → Slice scope 与 Hotspot 选择协调 → History。

## 明确不变

- 不调用 `normalized`，避免清洗名称、截断 preset 或破坏 Optional 形态。
- 不修改 Automation registry、payload 或 UI 调用点。
- Canvas Trim 仍只用 composited alpha bounds；Layer Trim 仍只处理图层。
- Reveal All 因“不允许非破坏操作静默删除”的规则不同，单独留给下一版。
