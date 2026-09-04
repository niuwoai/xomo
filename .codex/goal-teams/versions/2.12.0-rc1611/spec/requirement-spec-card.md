# rc1611 Requirement Specification Card

## 用户价值

执行 Image Size 后，Fireworks 风格 Slice 继续覆盖同一视觉内容；非等比缩放不滞留旧坐标，同时保持多规格导出意图。

## 几何契约

设旧画布 `OW × OH`、目标画布 `TW × TH`，`sx = TW / OW`、`sy = TH / OH`。源 frame 先标准化，再分别缩放四条边，最后对完整目标矩形执行一次 `.integral` 并与目标画布求交。

- 负宽高允许，先标准化；小数不可逐坐标提前取整。
- 部分越界历史数据保留可见交集；完全越界、空交集、非有限、零面积或算术溢出使整次命令失败。
- Slice 数量、顺序、UUID、名称、`exportPresets` 的 nil/空数组形态及每个 preset 全字段逐值保持。
- 不调用会修剪名称或过滤 preset 的 `ImageEditorSlice.normalized`。

示例：旧画布 `100 × 80`，frame `(30.4, 27.6, -20.2, -15.2)`，目标 `150 × 40`，最终 frame 为 `(15, 6, 31, 8)`。

## 导出预设与选择

- `.scale` 保持倍率值；`.width/.height` 保持固定交付像素值，并用目标最终 frame 重新解析倍率。
- preset 数量不得超限、format 必须受支持、value 必须有限且大于零；在源画布有效 frame 与目标最终 frame 上均须解析到现有倍率范围，否则 Image Size 原子拒绝，不删除或重写 preset。
- Slice scope 下有效 `sliceID` 保持；nil/stale 回退首个 Slice，无 Slice 时回退 composited。非 Slice scope 的全部导出设置保持。
- 选中 Slice 成功后应用第一个合法主 preset；无 preset 时沿用现有语义，仅清空 filename suffix。

## 范围边界

本版不处理 Canvas Size、Crop/Trim/Reveal、Rotate/Flip、schema、UI、Automation payload 或新的导出格式。
