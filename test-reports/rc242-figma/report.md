# rc242 Figma 图片填充测试报告

- 版本：`2.12.0-rc242`
- 结果：**1/1 通过，0 失败**
- 测试：`imageFillSourceMetadataSurvivesMaterializationAndProjectRoundTrip`
- 覆盖：Figma IMAGE 填充源引用、缩放模式、变换、缩放因子、旋转、滤镜在材质化与项目保存重开中的保留。
- 执行：沙箱外串行 `xcodebuild test`，macOS 目标下限 13.0。
