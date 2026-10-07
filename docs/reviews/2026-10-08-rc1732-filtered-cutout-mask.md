# rc1732 滤镜后选区剪切掩码

## 范围

以 `v2.12.0-rc1731` 为基线，实现活动智能滤镜图层在保留原栅格蒙版设置的情况下剪切选区。掩码属于图层局部像素网格，在滤镜和普通蒙版之后应用。

## 验收状态

- 基线：`main` / `origin/main` 的 `a88f0535`（`v2.12.0-rc1731`）；实现仍待按仓库约定提交并合入 main。
- 定向单测：10 个套件、173 项实际测试全部通过：`ImageEditorSelectionCutSamplingTests` 16、`ImageEditorMaskSamplingTests` 11、`ImageEditorMaskLinkRenderingTests` 5、`ImageEditorProjectDocumentTests` 13、`ImageEditorLayerCompTests` 33、`ImageEditorPSDTests` 59、`ImageEditorGroupResizeTests` 9、`ImageEditorGroupRotationTests` 9、`ImageEditorRasterRotationTests` 9、`ImageEditorRasterizeTargetTests` 9。结果来自独立进程 `.xcresult`；中途抓到并修复类型栅格化回归后，相关套件重跑通过。
- 覆盖范围包括降密度/羽化/未链接蒙版剪切、Undo/Redo 与项目重开、格式 10 缺键兼容、LayerComp、PSD 图层挖空 alpha、缩放/旋转及栅格化；羽化用带黑白边界的低分辨率蒙版确认采样语义不变。PSD 断言核对透明度和源层裁切，不声称跨色彩空间 RGB 字节严格一致。
- 全量构建、界面冒烟、安装及公开发布：本版本不执行；下一四十版本门槛为 rc1760，安装版维持 rc1729。

## 风险

- PSD 以滤镜后栅格化通道和图层蒙版表达源层裁切；内部解码已确认源层挖空 alpha 与整体透明度正确。尚无 Adobe Photoshop/外部 PSD 实际打开验证。
- `visibleImage` 在保留低分辨率源像素时，通过高分辨率渲染副本采样高密度裁切掩码；不同画布缩放和羽化组合仍需更多真实素材验证。
- 新的可选项目数据在缺少字段的格式 11 项目中可解码为 `nil`。
