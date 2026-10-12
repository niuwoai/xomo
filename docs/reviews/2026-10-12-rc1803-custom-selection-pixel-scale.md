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

rc1800 完整项目与本机安装门槛的实际执行结果见[rc1800 门槛记录](2026-10-12-rc1800-local-quality-gate.md)。本版本的 150% 自定义缩放也已在安装后的 GUI 中实际执行，并验证撤销/重做状态；但本机代码签名信任读回最终出现系统范围异常，因此不能将 Gatekeeper/分发签名验收记为通过，也没有进行公证或公开发布。
