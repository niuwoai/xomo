# rc1818：羽化选区四边缘剪切验证

## 范围与基线

- 时间：2026-10-13（本机时间，UTC+08:00）
- 基线：`78b567545f22eef47e1c1dd1a66be50a58da273f`（`main`，rc1817）
- 工作分支：`codex/feathered-edge-cut-rc1818`
- 变更范围：只为既有 feathered selection → Cut to Clipboard 路径补边缘集成回归；没有修改生产算法。

## 覆盖内容

在 24×20 画布的完全不透明红色栅格层上，对左、右、上、下边缘各放置一个单像素栅格选区，启用 1 px feather 后执行 Cut to Clipboard。每个边缘均断言：

- 输出剪贴板 frame 等于羽化范围与画布边界的交集，超出画布的羽化像素不会被错误表示为可粘贴画布内容；
- 画布内的剪贴像素仍包含部分透明的羽化覆盖，源层对应 RGBA 与剪贴 alpha 逐像素互补；
- 一次剪切只追加一个 Undo 项，Undo 精确恢复原项目数据，Redo 精确恢复剪切后项目数据。

## 实测结果

- `ImageEditorSelectionCutSamplingTests`：20/20 通过；新增四边缘场景均在该实际 suite 中执行。
- `scripts/test_release_contract.rb`：10 runs / 30 assertions，通过。
- `scripts/test_xomo_cli_release_build.rb`：7 runs / 24 assertions，通过。
- `scripts/test_product_overview_archive.rb`：3 runs / 30 assertions，通过。
- `scripts/test_run_tests_isolated_contract.rb`：通过。
- `git diff --check`：通过。

定向 XCTest 在仓库锁保护下执行；启动前确认没有其它 Xcode/XCTest 构建。此记录不代表 rc1840 完整构建、全量回归、桌面冒烟或 `/Applications` 安装验收已经完成。

## 方向判断与下一步

rc1802 已验证像素选区缩放的四边缘羽化覆盖，因此本版本补的是不同的用户动作：把软选区剪切到剪贴板并让源像素正确扣除。该变化没有扩张 Figma 兼容范围，也没有改变产品算法。下一步仍是 rc1840 完整 Release 构建、全量 XCTest、桌面关键工作流/光标冒烟和可恢复的本机安装验收。
