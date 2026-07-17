# rc242 MCP 图层元数据测试报告

- 版本：`2.12.0-rc242`
- 结果：**1/1 通过，0 失败**
- 测试：`registryLayerListExposesFigmaVariableBindings`
- 覆盖：`xomo.layer.list` 输出 Figma 图片填充源引用、缩放模式、旋转和滤镜元数据。
- 执行：沙箱外串行 `xcodebuild test`，macOS 目标下限 13.0。
