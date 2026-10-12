# rc1839：Image Size 尺寸直接录入

- 基线：`main` / rc1838
- 版本：`2.12.0-rc1839`，build `1839`
- 范围：把宽高数值从纯步进器标签改为可直接录入的整数像素字段，同时保留每像素步进器、8–12,000 px 范围和 rc1838 的宽高比锁定绑定。

## 验证

- `ImageEditorSliceImageSizeTransformTests`：12/12 实际执行通过。包含比例联动、解锁/重锁、字段到同一 ViewModel 绑定的源码接线合同、整数格式约束、最终图像尺寸变更及 Undo/Redo 往返。
- build-for-testing 成功，报告：`/private/tmp/xomo-rc1839-tests-final/report.json`、`report.md`。首轮编译发现计算型 SwiftUI View 在加入局部绑定后需显式 `return`；修复后复用同一 DerivedData 重新编译并通过。
- 发布合同：12 runs / 36 assertions；CLI 版本合同：7 / 24；Product Overview 归档合同：3 / 30；隔离测试器合同通过。中文、英文、日文 `.strings` 均通过 `plutil -lint`。
- 未执行全量 Release、完整回归、桌面冒烟或 `/Applications` 安装；下一完整门槛为 rc1840。系统签名信任验收仍遵循失败即停止，不做绕过。
