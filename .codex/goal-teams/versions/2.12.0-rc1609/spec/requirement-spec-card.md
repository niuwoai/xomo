# Requirement Spec Card

## 用户价值

裁剪或显露画布后，Fireworks 风格热点继续覆盖对应内容，不再停留于旧坐标、漂出画布或被非破坏命令悄悄删除。

## 冻结语义

- 普通 Crop、Crop to Selection 与 Trim Transparent 共用 `frame + (-crop.minX, -crop.minY)`，不缩放热点。
- Crop 家族平移后裁到新画布；部分越界裁切，完全越界或边界相切时合法移除。
- Reveal All 的目标画布只由旧画布和可见可合成图层决定，热点不参与扩大范围。
- Reveal All 按 `frame + (-reveal.minX, -reveal.minY)` 平移热点；合法热点必须全部保留，任何 `nil` 或 throw 都使整次命令原子拒绝。
- 存活热点只改变 frame，`id`、`name`、`url` 与相对顺序精确保持。
- 选择为 nil 时保持 nil；存活则保持；删除或 stale 时回退第一项，无热点则 nil；面板显隐不变。
- Undo/Redo 精确恢复文档，继续沿用 UI 热点选择不进入文档历史的既定边界。
