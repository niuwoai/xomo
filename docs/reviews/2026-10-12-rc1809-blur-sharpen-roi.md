# rc1809 Blur/Sharpen 笔刷 ROI 合成

## 范围

Blur 与 Sharpen 仍基于完整源图生成滤镜结果，确保笔触需要的邻域采样不被裁掉。但之前每次笔划还会生成全画布 alpha-mask 位图、全画布裁切滤镜图并运行两轮 AppKit 画布绘制。rc1809 改为直接读取源图与滤镜图的预乘 RGBA 缓冲，只在紧凑笔触 bounds 内执行 source-over 混合，最后仍构造原尺寸输出图像。透明度、压感尺寸、画布边缘裁切和 Undo/Redo 事务均保持既有入口。

## 回归

- 新增 `blurAndSharpenROIMixesMatchFullFrameAppKitReference`，用不对称双色边缘及不透明/半透明源图、触及左上画布边缘的笔划，对比旧全画布 AppKit destination-in/source-over 合成与 ROI 混合的每像素 RGBA，容差为 4/255。实测最大通道差约 0.01325（3.4/255），来自像素量化/色彩转换。
- 既有 Blur/Sharpen 像素可见效果测试验证笔划区域发生相应变化、远端像素保持不变及 History 标题正确。

## 验证

- `ImageEditorToneAirbrushTests` 7/7 通过；不透明与半透明源图的 Blur/Sharpen ROI 输出均与旧全帧 AppKit 路径逐像素比较，最大 RGBA 通道差 0.01325，低于 4/255 容差。
- Blur 局部软化 1/1、Sharpen 边缘增强 1/1 通过，分别确认远端像素不变并保留工具 History 语义。
- 发布合同 10/30 断言、CLI 发布构建合同 7/24、产品概览归档合同 3/30、隔离测试运行器合同及 `git diff --check` 通过。
- rc1840 仍为下一次完整构建、全量测试、桌面冒烟与安装门槛；本版不覆盖 `/Applications`。
