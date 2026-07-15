# Xomo rc121 质量门禁报告

- 执行日期：2026-07-16
- 版本：`2.12.0-rc121`
- 里程碑：本地 `.xomotokens.json` 设计 Token 映射

## 结果

✅ 全部通过。

| 检查项 | 结果 | 证据 |
|---|---:|---|
| 组件库与本地 Token | 40/40 | `test-reports/rc121-component-token/report.json` |
| MCP/自动化回归 | 36/36 | `test-reports/rc121-automation/report.json` |
| Figma 节点导入与项目往返 | 25/25 | `test-reports/rc121-figma/report.json` |
| 三语本地化资源 | 4/4 | `test-reports/rc121-localization/report.json` |
| CLI 测试 | 2/2 | `XomoMCPServerTests` |
| CLI 通用构建 | 通过 | `dist/xomo-macos-universal`，`arm64 + x86_64` |
| Xomo Debug 通用构建 | 通过 | `/tmp/xomo-debug-rc121/Build/Products/Debug/Xomo.app` |
| 应用元数据 | 通过 | Bundle ID `im.some.xomo`；最低 macOS `13.0`；版本 `2.12.0-rc121` |

## 功能边界

- `.xomotokens.json` 会严格校验 schema、8 个颜色 Token 和尺寸指标，拒绝未知版本、缺失字段、非法颜色和非有限数值。
- 导入映射作用于后续插入组件，以及“应用到所选组件”命令；组件实例保存 Token 快照，项目保存/重开继续保留。
- 切换内置主题会清除当前会话的本地映射；对文档的应用仍通过现有 History/Undo 入口完成。
- UI 和 `xomo.component.tokens` MCP/CLI 使用同一导入逻辑；本地 Token 不会联网或写回 Figma/Sketch。
