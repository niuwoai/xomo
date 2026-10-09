# rc1798 选区像素旋转验证记录

日期：2026-10-10（Asia/Shanghai）

## 改动

- 编辑菜单新增选区像素顺时针 90°、逆时针 90° 和 180° 旋转。
- 选区覆盖与所有已选像素图层在一次 Undo/Redo 事务中更新；旋转目标超出原图层 backing 时扩展像素 backing。
- 90° 旋转只对等比缩放的像素图层开放，避免把画布栅格上的旋转错误解释为非等比缩放图层的局部旋转；180° 与原像素翻转遵循既有可用条件。
- 英文、日文、简体中文菜单、状态与历史记录均有本地化资源。

## 已执行验证

- `ImageEditorSelectionPixelTransformTests`：10 项，通过 10 项、失败 0。覆盖选区像素旋转映射、CW/CCW/180°、多层原子变更、Undo/Redo、项目保存/重开、backing 扩展和非等比缩放图层的 90° 防护。
- `ruby scripts/test_release_contract.rb`：10 runs、30 assertions，0 failures/errors。
- `ruby scripts/test_xomo_cli_release_build.rb`：7 runs、24 assertions，0 failures/errors。
- `ruby scripts/test_product_overview_archive.rb`：3 runs、30 assertions，0 failures/errors。
- `git diff --check`：通过。

## 尚未完成的门槛

- 本记录不是全量测试、完整 Release archive、真实桌面编辑冒烟、签名/公证或安装验收。
- 这些完整门槛仍按路线图在 rc1800 执行；本次没有覆盖 `/Applications/Xomo.app`。
