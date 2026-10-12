# rc1804 选区像素缩放固定参考点

## 用户工作流

在「编辑 → 缩放选区像素 → 自定义比例」中选择九宫格锚点后，选区覆盖与选中像素围绕同一个参考点缩放。默认中心锚点维持旧行为；非中心缩放在 History 和状态栏中显示锚点，便于连续贴边修图时保持边缘或角点位置。

## 实现与回归覆盖

- `ImageEditorSelectionBoolean.swift`：选区蒙版缩放根据归一化锚点计算目标边界，并把锚点贯通到选区缩放几何。
- `ImageEditorSelectionPixelTransformCommands.swift`：增加本地化九点选择器；缩放继续由原来的像素预算、蒙版采样和文档事务路径处理。
- `ImageEditorSelectionPixelTransformTests.swift`：覆盖全部九个锚点位置不漂移，以及左上锚点的像素、选区、History 与一次 Undo/Redo 事务。

## 验证结果

- 2026-10-12 16:36（Asia/Shanghai）：`ImageEditorSelectionPixelTransformTests` 22/22 通过，零基础设施重试。
- `ruby scripts/test_release_contract.rb`：10 tests / 30 assertions 通过。
- `ruby scripts/test_xomo_cli_release_build.rb`：7 tests / 24 assertions 通过。
- `ruby scripts/test_product_overview_archive.rb`：3 tests / 30 assertions 通过。
- `plutil -lint` 对 en、ja、zh-Hans 三份 `Localizable.strings` 均通过；`git diff --check` 通过。

## 未做及下一门槛

本轮未做 GUI 手动交互验收、完整 Release 构建或 `/Applications` 替换；没有把单测成功表述为本机安装验收。按每四十个版本的门槛安排，下一次完整构建、冒烟与安装验收为 rc1840。rc1800 质量门槛记录中的系统签名信任异常仍单独跟踪，不绕过验证。
