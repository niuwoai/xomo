# rc406 智能滤镜路由测试报告

- 版本：`2.12.0-rc406`
- 日期：2026-07-20
- 结果：**2/2 通过**

## 覆盖范围

- `updatingFigmaBackdropBlurToContentSmartFilterReentersPixelPipeline()`：将 Figma 背景高斯模糊改为像素化后，滤镜清除背景路由并重新进入普通图层像素链。
- `batchSmartFilterUpdatePreservesBackdropRoutingOnlyForGaussianBlur()`：批量更新时，只有原本的背景滤镜且目标仍为高斯模糊才保留背景路由。
- 验证原始图层像素保持不变、预览像素发生预期变化、历史标题正确，并可通过撤销恢复原背景模糊语义。

## 命令结果

- Xcode 专项测试：2 项通过，0 项失败。
- 结果包：`/tmp/rc406-smart-filter-routing-final.xcresult`。
