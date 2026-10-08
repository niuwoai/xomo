# rc1756 选区剪贴板原子写入验证

- 版本：`2.12.0-rc1756`，基于 `main` 的 `c6ca6db1`。
- 目标：选区复制、剪切和合并复制将图像与原位粘贴坐标作为同一个 `NSPasteboardItem` 的表示写入；剪切只有在完整剪贴板写入成功后才修改文档。

## 实现与回归

`ImageEditorSelectionEditCommands.swift` 在调用剪贴板图像写入器之前编码帧元数据，并通过 `additionalData` 与图像一起写入。若坐标无法编码，操作会先失败；若剪切写入失败，Undo、图层像素和历史记录均不提交。移除了图像写入后再单独写坐标的第二阶段。

复制专项新增选区复制、合并复制、同 item 数据、原位粘贴能力及图层帧检查。剪切专项补充同 item PNG 与坐标元数据检查，并保留此前的像素、Undo/Redo、项目重开覆盖。

## 实际验证

- `ImageEditorSelectionCopySamplingTests`：1 个独立执行组，7 项实际测试通过，0 失败。
- `ImageEditorSelectionCutSamplingTests`：1 个独立执行组，19 项实际测试通过，0 失败。
- `scripts/test_release_contract.rb`：10 runs / 30 assertions，通过。
- `scripts/test_xomo_cli_release_build.rb`：7 runs / 24 assertions，通过。
- `scripts/test_product_overview_archive.rb`：3 runs / 26 assertions，通过。
- `scripts/verify_release_contract.rb`：通过；App/CLI 版本 `2.12.0-rc1756`、Build `1756` 一致。
- `git diff --check`：通过。

## 范围边界

这不是 rc1760 四十版本完整门槛：未执行全量构建、全量测试、真实界面冒烟或 `/Applications` 覆盖安装。剪贴板系统级失败注入未覆盖；测试验证了正常写入内容及剪切事务的既有成功/失败边界。
