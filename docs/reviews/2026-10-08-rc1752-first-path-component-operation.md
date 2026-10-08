# rc1752 首路径组件运算校验

## 问题与影响范围

`continuePrevious` 只有在已有前序组件时才有意义。组件运算 renderer 对第一个子路径会回退为 `.exclude`，但 Picker 原先仍允许选择“延续上一组件”，ViewModel 也会把该无效值写入项目与 Undo 历史，造成界面选择与实际渲染语义不一致。

## 修复

- 第一个路径子项的 Picker 禁用 `continuePrevious`，后续子项仍按原有可用性开放。
- ViewModel 对首项拒绝该设置，并将历史数据中首项的无效值显示为 renderer 实际使用的 `.exclude`。
- 回归检查无效设置和相同有效设置均不改文档内容、历史或 Undo 栈。

## 验证

- `ImageEditorVectorLayerTests`：110/110 实际通过，0 失败；隔离报告：`/tmp/veilpic-rc1752-first-path-operation/report.md`。
- `scripts/test_release_contract.rb`：10 runs / 30 assertions 通过。
- `scripts/test_xomo_cli_release_build.rb`：7 runs / 24 assertions 通过。
- `scripts/verify_release_contract.rb`：通过，App/CLI/Xcode 版本 `2.12.0-rc1752`，build 号 `1752`。
- `scripts/test_product_overview_archive.rb`：3 runs / 26 assertions 通过。
- `git diff --check`：通过。

Xcode 定向套件通过；未运行完整项目门槛、真实 GUI Picker 冒烟或覆盖 `/Applications`。下一完整门槛仍为 rc1760。
