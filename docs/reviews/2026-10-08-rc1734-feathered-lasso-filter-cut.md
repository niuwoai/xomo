# rc1734 滤镜图层套索羽化剪切

## 工作流与验收

为 rc1733 修复补上真实套索路径：活动 Gaussian Blur 图层使用羽化三角形选区剪切到剪贴板，验证选区外合成不变，选区内部近透明，边缘保留半透明过渡；滤镜设置保持，Undo/Redo 和项目保存重开保持相同像素结果。

- `ImageEditorSelectionCutSamplingTests`：`.xcresult` 实际执行 18 项，0 失败。
- `scripts/test_release_contract.rb`：10 runs / 30 assertions，0 失败。
- `scripts/test_xomo_cli_release_build.rb`：7 runs / 24 assertions，0 失败。
- `scripts/test_product_overview_archive.rb`：3 runs / 26 assertions，0 失败。
- `git diff --check` 通过。
- 未执行全量构建/回归、真实 GUI 冒烟或 `/Applications` 安装；当前安装仍为 rc1729，下一完整门槛 rc1760。

## 集成

- 基于本地 `main` 的 rc1733 集成状态；`origin/main` 仍为 rc1731。
- 功能分支：`codex/feathered-lasso-filter-cut-rc1734`。待提交并合入本地 `main`；本轮不推送、不创建 tag。
- 无生产代码变化：本版本收敛像素级验收规格，不扩张 Figma。
