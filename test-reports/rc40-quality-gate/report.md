# Xomo v2.12.0-rc40 完整质量门禁

- 生成时间：2026-07-14 06:55:41 +0800
- 结论：**通过**，附 UI Automation 基础设施说明
- App：`2.12.0-rc40`，Bundle ID `im.some.xomo`，最低 macOS 13.0
- App 架构：arm64 + x86_64
- CLI：`2.12.0-rc40`，arm64 + x86_64

## 自动化结果

| 项目 | 结果 |
|---|---:|
| 干净 Debug 测试产品 | 通过 |
| App 全量隔离单元测试 | 744 / 744 |
| SwiftPM CLI 测试 | 2 / 2 |
| 干净通用 Release App | 通过 |
| 通用 Release CLI | 通过 |
| 等价真实界面冒烟 | 2 / 2 |

## 真实界面冒烟

1. 在当前 Debug App 打开图层样式预设管理器，搜索“霓虹”后仅显示“霓虹发光”；切换到“自定义”后显示“没有匹配的样式预设”。
2. 从组件库插入“按钮”后，状态栏显示“已插入组件：按钮”，图层面板生成按钮组、文字子层和背景形状子层，结构保持可编辑。

## UI Automation 说明

新增 XCTest UI 用例已成功编译，并使用 Apple Development 身份签名。测试 runner 在执行任何产品断言前因本机 UI Automation 服务报错 `Timed out while enabling automation mode.`，因此不把该次运行记作产品测试失败，也不伪报为通过；上述两条路径已在同一份 Debug App 上用界面控制完成等价冒烟。

详细的 744 项套件结果见 [rc40-full/report.md](../rc40-full/report.md)。
