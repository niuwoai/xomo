# rc1811 Sample All Layers 涂抹蒙版复用

## 范围

Sample All Layers 涂抹在每个拖动段先从独立采样源生成平移图，再将相同笔触几何分别合成到活动层输出与后续采样源。此前两次 `mixingBrushSource` 调用各自重新栅格化完全相同的 ROI 蒙版。rc1811 改为每段只生成一次蒙版，并将同一不可变蒙版用于两路合成；两路目的像素缓冲、alpha 和连续采样顺序仍彼此独立。

本版仅消除重复 ROI 蒙版生成，不声称减少全尺寸源平移、每路整图 RGBA 解码/编码，也未量化整体延迟或内存提升。

## 回归

- `ImageEditorToneAirbrushTests` 覆盖涂抹笔刷的逐段像素行为与撤销历史。
- `sampleAllLayersSmudgesVisiblePixelsOnlyIntoTheActiveLayer` 覆盖可见合成取样、仅写当前层、范围外像素、History 与 Undo/Redo。
- 曾尝试用全帧 AppKit source-over 输出作为透明活动层的参考，但该合成语义与涂抹实现的 straight-RGBA 混合不同；此对照不具备有效的像素等价性，已移除，不作为产品缺陷证据。

## 验证

- 首轮编译成功，但新增参考测试失败；已删除不等价的参考用例。重新编译后 `ImageEditorToneAirbrushTests` 8/8 通过，Sample All Layers 工作流回归 1/1 通过；发布合同 10/30、CLI 发布构建合同 7/24、概览归档合同 3/30、隔离测试器合同及 `git diff --check` 均通过。
- 共享机器上的 Xedit 构建已结束；VeilPic 定向构建/测试在仓库共享构建锁下串行完成。
- rc1840 仍为完整构建、全量测试、桌面冒烟和可恢复安装门槛；本版不覆盖 `/Applications`。
