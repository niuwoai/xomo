# rc411 调整图层结果不透明度测试

- 日期：2026-07-20
- 结果：2/2 通过
- 结果包：`/tmp/rc411-adjustment-layer-opacity-final-pair.xcresult`
- 构建说明：定向测试设置 `QPIC_SKIP_ADHOC_SIGN=YES`，绕开 Debug 自定义签名脚本与 Info.plist 生成阶段的已知竞态；不影响被测业务代码。

## 覆盖范围

- 调整图层以完整参数生成效果，再按图层不透明度混合最终结果。
- 调整层向下合并与实时预览逐像素一致。
- 半透明源图像经过局部滤镜蒙版时，RGBA 插值不抬高源 Alpha。

## 结果

- `ImageEditorAdjustmentTests/adjustmentLayerOpacityBlendsTheCompletedEffectWithoutChangingItsParameters()`：通过。
- `ImageEditorFilterTests/maskedFilterInterpolatesPixelsWithoutIncreasingSourceAlpha()`：通过。
