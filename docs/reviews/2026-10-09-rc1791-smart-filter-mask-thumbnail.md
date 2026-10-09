# rc1791 智能滤镜蒙版缩略图

## 基线与范围

- 基线：`main` / `9c467979`；开发分支：`codex/rc1791-smart-filter-mask-thumbnail`。
- 为每个有蒙版的 Smart Filter 项显示灰度覆盖缩略图；点击它进入或退出对应滤镜的蒙版绘制模式。沿用现有本地化的“绘制蒙版 / 结束绘制蒙版”无障碍名称，不增加文案键，也不改变蒙版内容、密度、羽化或历史事务。

## 验证

- `ImageEditorSmartFilterMaskTests`：9/9 通过。新增 4 像素覆盖值 `[0, 64, 128, 255]` 的灰度缩略图读回，逐通道核对 RGB 与不透明 Alpha。
- `ImageEditorScopeTests/smartFilterRowsExposeNonFocusableResultOpacityAndBlendControls`：1/1 通过，核对缩略图接入筛选行、使用 mask 灰度图、提供稳定辅助功能标识并调用蒙版编辑切换。
- `scripts/test_release_contract.rb`：10 runs / 30 assertions 通过；`scripts/test_xomo_cli_release_build.rb`：7 runs / 24 assertions 通过。
- `scripts/test_product_overview_archive.rb`：3 runs / 30 assertions 通过。
- 定向 `build-for-testing` 成功；一次先行尝试因沙箱不能写用户级 SwiftPM/Clang cache 而在编译前失败，获准访问本机缓存后以相同构建路径重跑成功，没有清理缓存。
- `git diff --check` 通过。未运行完整 Release、桌面 GUI 冒烟、`/Applications` 安装或公开发布；下一完整门槛仍是 rc1800。策略/接线单测不等于真实鼠标操作验收。

## 报告

- 蒙版套件报告：`/private/tmp/xomo-rc1791-smart-filter-mask-tests-final/report.md`
- 属性面板报告：`/private/tmp/xomo-rc1791-smart-filter-inspector-test-final/report.md`
