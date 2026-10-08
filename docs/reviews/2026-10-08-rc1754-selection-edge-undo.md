# rc1754 选区边缘显示与内容撤销隔离

## 用户场景

选区仍然有效时，用户隐藏“蚂蚁线”以检查图像细节，再填充或绘画并按 Undo。显示辅助状态不应抢先消耗 Undo，也不应在撤销像素编辑时被旧文档快照恢复成可见。

## 实现

- `toggleSelectionEdgesVisible()` 只切换并报告当前显示状态，不新增图像 History/Undo。
- Undo、Redo、历史条目恢复、History 截断和命名快照恢复仍整体恢复内容文档，但会沿用操作前当前的选区边缘显示状态。
- 显示值仍保存在项目文档中；既有项目保存/重开测试继续验证该值持久化。

## 验证

- `ImageEditorGuideTests`：37/37 实际通过。
- `ImageEditorScopeTests`：195/195 实际通过；包含像素选区填充 → 隐藏边缘 → Undo/Redo → 恢复命名历史快照，断言切换瞬间图层 PNG 不变、不增加 History/Undo、像素按内容历史恢复且边缘保持隐藏；原有显隐测试同时核验不改变内容 History/Undo。
- `scripts/test_release_contract.rb`：10 runs / 30 assertions；`scripts/test_xomo_cli_release_build.rb`：7 / 24；`scripts/test_product_overview_archive.rb`：3 / 26，均通过。
- `scripts/verify_release_contract.rb` 验证 App、CLI 与 Xcode 六配置版本 `2.12.0-rc1754` / build 1754 一致；`git diff --check` 通过。
- 初轮测试构建指出新增 Swift Testing 方法缺少 `@MainActor`；补齐后 rc1754 的测试目标编译成功，相关两个套件实际运行全部通过。

## 未覆盖

- 尚未执行真实菜单/画布 GUI 冒烟；没有验证窗口重开时的实际选区边缘显示，也未运行 rc1760 全量门槛或安装覆盖。
- 选区边缘显示仍随项目保存；仅确保内容撤销与历史恢复不回滚此显示状态。
