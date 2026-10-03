# rc1711 项目保存验证检查点

> 2026-10-03（Asia/Shanghai）；版本 2.12.0-rc1711；代码修复与原生专项通过，实际保存重开验收被 Mac 锁屏阻断。

## 缺陷与修复

main 基线为 `8607dbe63795b856c6f17319cc2c5e258d2b94dd`（rc1709）。功能分支已有 rc1710 旋转命中修复及实际界面记录 `19a189c5`，尚未合 main。rc1710 的合成图片真实编辑任务发现：项目保存面板确认后未生成文件，状态未变为保存成功。

`ImageEditorProjectDocument.swift` 的普通保存、另存为、保存副本把写入表达式放在 `completion?(write...)` 参数中。可选调用为 nil 时参数不求值；工具栏和文件菜单使用无回调入口，关闭保护则传入回调，因此底层写入测试及关闭保护测试未覆盖该缺陷。

rc1711 将三个入口的写入结果存入局部变量，再调用可选 completion；保留原子写入、失败时不改变文档身份与脏状态、普通保存成功才更新保存基线，以及副本不改变当前项目身份的现有规则。普通保存入口复用底层写入与最近文档登记的隔离依赖，用于真实入口回归，不写用户文件或污染用户最近文档。

## 原生证据

- 可执行失败基线：`/private/tmp/veilpic-rc1711-save-entry-baseline-tests.xcresult`，12 个方法、14 次运行，2 个失败方法、8 处失败断言。两个失败的参数用例都是 `notify=false`；有回调用例通过。此前两个结果包为测试闭包编译失败，不能作为业务失败证据。
- 修复后：`/private/tmp/veilpic-rc1711-save-green-tests.xcresult`，九组、89 个方法、含参数化 127 次运行，零失败、零跳过。对应日志同名 `.log`。
- 九组范围：ProjectSave、ProjectDocument、ProjectRevert、DocumentCloseGuard、RecentDocuments、ExternalDocumentOpen、PixelMoveCoverage、PixelMovePreviewReuse、RotationHandleGesture。不是全项目测试或完整 Release 门禁。
- 新保存入口测试覆盖成功/抛错、回调有无、写入数据和目的地址、最近文档登记次数、脏状态、项目身份及现有历史与 Undo/Redo 计数不变。另存为及副本的原生面板无回调路径仍需实际界面复验；底层写入单测不能替代它。
- 版本契约 10 项、30 断言；README 29 项通过；`git diff --check` 通过。App、CLI 与 Xcode 目标版本均为 rc1711，Debug 产物版本/构建号直接核验为 rc1711/1711。
- 构建持 `/private/tmp/veilpic-build.lock` 串行执行，复用 `.codex/DerivedData` 和 `.codex/SourcePackages`，没有 clean。原生回归结束后重新核对六项源码/版本输入指纹不变；先确认无其他构建/测试/App 进程再请求界面验收。

## 阻断与下一个验收动作

通过原生回归后使用 Computer Use 打开精确工作区 Debug App，工具返回 Mac 已锁定且自动解锁失败，需要用户手动解锁。没有绕过锁屏、访问用户图片、替换 `/Applications` 或把锁屏误判为代码失败。

解锁后继续使用 `/private/tmp/xomo-ui-selection-task-source.png` 这张本轮合成的 2048² 图片：选区移动 → 单步 Undo/Redo → 保存实际项目 → 普通保存更新 → 另存为和副本 → 实际重开 → PNG 导出逐像素对照。每次保存都核验文件真实存在及可解析，不能只看面板关闭。通过后再将 rc1710/rc1711 合 main、打版本标签并推送。

当前检查点不宣称完整任务已交付。安装版直接核验仍为 rc1680；下一完整 Release 编译、回归、冒烟及可恢复安装门槛仍为 rc1720。旋转 Escape 后续事件的测试与生产路径不一致风险仍另待补齐，不混入本保存修复，也不宣称已消除。
