# rc1838：Image Size 保持宽高比

- 基线：`main` / `04bca6b49c5ecb45d9da45216c84848f50262d47`（rc1837）
- 版本：`2.12.0-rc1838`，build `1838`
- 范围：在图像尺寸控制中加入默认开启的宽高比锁；修改任一维度时按原画布比例联动另一维度，取消锁定后两个尺寸独立，重新锁定时依据当前宽度更新高度。

## 验证

- `ImageEditorSliceImageSizeTransformTests`：11/11 实际执行通过。新增测试验证开关默认状态、宽/高两个方向的尺寸联动、解除锁定后的独立值、重新锁定，以及最终缩放的一条 Undo、Undo/Redo 项目数据往返。
- `LocalizationResourceTests`：46/46 实际执行通过；新增三语键与本地化资源一致性检查。
- 隔离测试器的 build-for-testing 成功；结果报告：`/private/tmp/xomo-rc1838-tests-final/report.json`、`report.md`。
- 发布合同：12 runs / 36 assertions；CLI 发布合同：7 / 24；Product Overview 归档合同：3 / 30；隔离测试器合同通过。
- 中文、英文、日文 `.strings` 文件均通过 `plutil -lint`；`git diff --check` 通过。
- 未运行完整 Release、全量 XCTest、桌面冒烟或 `/Applications` 安装；下一次周期门槛仍为 rc1840，rc1800 的签名信任异常仍须在门槛验收中单独复核，不绕过系统安全检查。
