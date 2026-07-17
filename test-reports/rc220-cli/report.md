# Xomo CLI rc220 回归报告

- 版本：**2.12.0-rc220**
- 测试：`swift test --package-path xomo-cli`
- 结果：**2/2 通过，0 失败**
- MCP 协议：`initialize` 能力声明与 `tools/list` 的 122 个工具目录均通过。
- 发布产物：`dist/xomo-macos-universal`
- 架构：arm64 + x86_64（Mach-O universal）

