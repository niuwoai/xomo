# rc1803 自定义选区像素缩放验证记录

- 日期：2026-10-12
- 基线：`v2.12.0-rc1802`，提交 `5f9fe81e`
- 目标：为现有选区像素缩放增加可输入比例的菜单入口，验证输入、缩放事务、撤销与重做。

## 实现

- 「编辑 → 缩放选区像素 → 自定义缩放…」打开本地化输入对话框，接受 1%–1,000% 和系统 locale 的小数分隔符；不接受分组符、指数形式、非有限值或越界值。
- 有效输入调用既有画布空间缩放路径，保留统一像素预算校验；变换通过既有单事务 Undo/Redo 提交。无效输入不更改项目数据或撤销栈。
- 英文、简体中文、日文资源同步添加菜单、对话框、状态及历史记录文案。

## 验证

- `ImageEditorSelectionPixelTransformTests`：20/20 通过，包含自定义百分比解析、本地化小数、无效输入不改文档、150% 缩放及完整 Undo/Redo 往返。
- `ruby scripts/test_release_contract.rb`：10 tests / 30 assertions，通过。
- `ruby scripts/test_xomo_cli_release_build.rb`：7 tests / 24 assertions，通过。
- `ruby scripts/test_product_overview_archive.rb`：3 tests / 30 assertions，通过。
- `git diff --check`：通过。

## 未完成的独立门槛

本记录不代表 rc1800 Release 或完整项目冒烟完成，也不代表 `/Applications/Xomo.app` 安装验收通过。此前 Release 日志中的签名/公证记录与当前 strict codesign 读回不一致，且当前机器无法枚举有效 Developer ID 身份；因此没有覆盖本机安装，也没有绕过系统签名验证。该安装门槛仍需修复签名身份/信任读回后另行验收。
