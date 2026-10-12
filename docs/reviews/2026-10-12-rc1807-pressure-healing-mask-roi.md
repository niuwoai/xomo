# rc1807 压感修复笔 ROI 蒙版

## 范围

压感 Healing Brush 与 Spot Healing 的 `retouchStrokeMask` 原先调用 `retouchStrokeAlpha` 创建画布尺寸的 `[CGFloat]` 覆盖图，经转换为画布尺寸 `[UInt8]` 后，再由 `compactStrokeMask` 复制笔触边界。大画布上的小笔触因此会为未受影响区域付出完整临时缓冲成本。

rc1807 将笔触设置、压感采样和已有 mask bounds 传入 `coverageRegion`，覆盖内核只分配 ROI 尺寸的累积数组，并保留绝对画布坐标用于噪声和笔刷采样。非压感路径不变；湿边仍只由原全画布 coverage API 处理，避免改变湿边的邻域语义。

## 回归

新增 `pressureCoverageRegionMatchesFullCanvasWithoutAllocatingCanvasPixels`：以 1024×768 画布和小型压感笔划比较 ROI 每行与全画布参考，要求逐字节一致，并要求 ROI 像素数小于画布的 1%。既有 Healing/Spot Healing 压感集成用例继续覆盖实际应用路径。

## 验证

- `ImageEditorHealingBrushTests`：27/27 通过，覆盖现有压感、Spot Healing、选区、边缘和 Undo/Redo 路径。
- `pressureCoverageRegionMatchesFullCanvasWithoutAllocatingCanvasPixels`：1/1 通过，中心与左上画布边缘笔划（启用确定性噪声）逐行逐字节等价，ROI 缓冲低于全画布像素数的 1%。
- 发布契约 10/30、CLI Release 契约 7/24、产品概览归档契约 3/30 通过；`git diff --check` 通过。
- 一次受限沙箱内构建在源码编译前因 SwiftPM/Clang 用户缓存写权限失败；随后在获得缓存写权限并持共享构建锁的重跑中，测试与构建成功。
- rc1840 仍是下一次完整构建、全量测试、冒烟与安装门槛；rc1807 不覆盖 `/Applications`。
