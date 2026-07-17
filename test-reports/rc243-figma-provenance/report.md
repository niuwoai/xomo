# rc243 Figma provenance 测试报告

- 版本：`2.12.0-rc243`
- 结果：**3/3 通过，0 失败**
- 覆盖：Figma 图片填充属性面板数据源、完整 JSON 复制、项目保存重开，以及既有组件属性覆盖与 Undo/Redo 回归。
- 执行：沙箱外串行 `xcodebuild test`，macOS 目标下限 13.0。
