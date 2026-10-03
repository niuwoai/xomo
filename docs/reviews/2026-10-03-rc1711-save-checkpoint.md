# rc1711 项目保存验证检查点

> 2026-10-03（Asia/Shanghai）；版本 2.12.0-rc1711；代码修复、原生专项及解锁后的实际保存重开任务通过。

## 缺陷与修复

main 基线为 `8607dbe63795b856c6f17319cc2c5e258d2b94dd`（rc1709）。功能分支已有 rc1710 旋转命中修复及实际界面记录 `19a189c5`；rc1711 原生通过检查点 `3b2afe05` 先提交推送，待实际任务通过后集成。rc1710 的合成图片真实编辑任务发现：项目保存面板确认后未生成文件，状态未变为保存成功。

`ImageEditorProjectDocument.swift` 的普通保存、另存为、保存副本把写入表达式放在 `completion?(write...)` 参数中。可选调用为 nil 时参数不求值；工具栏和文件菜单使用无回调入口，关闭保护则传入回调，因此底层写入测试及关闭保护测试未覆盖该缺陷。

rc1711 将三个入口的写入结果存入局部变量，再调用可选 completion；保留原子写入、失败时不改变文档身份与脏状态、普通保存成功才更新保存基线，以及副本不改变当前项目身份的现有规则。普通保存入口复用底层写入与最近文档登记的隔离依赖，用于真实入口回归，不写用户文件或污染用户最近文档。

## 原生证据

- 可执行失败基线：`/private/tmp/veilpic-rc1711-save-entry-baseline-tests.xcresult`，12 个方法、14 次运行，2 个失败方法、8 处失败断言。两个失败的参数用例都是 `notify=false`；有回调用例通过。此前两个结果包为测试闭包编译失败，不能作为业务失败证据。
- 修复后：`/private/tmp/veilpic-rc1711-save-green-tests.xcresult`，九组、89 个方法、含参数化 127 次运行，零失败、零跳过。对应日志同名 `.log`。
- 九组范围：ProjectSave、ProjectDocument、ProjectRevert、DocumentCloseGuard、RecentDocuments、ExternalDocumentOpen、PixelMoveCoverage、PixelMovePreviewReuse、RotationHandleGesture。不是全项目测试或完整 Release 门禁。
- 新保存入口测试覆盖成功/抛错、回调有无、写入数据和目的地址、最近文档登记次数、脏状态、项目身份及现有历史与 Undo/Redo 计数不变。另存为及副本的无回调原生面板路径另由下述实际界面复验，未用底层单测替代它。
- 版本契约 10 项、30 断言；README 29 项通过；`git diff --check` 通过。App、CLI 与 Xcode 目标版本均为 rc1711，Debug 产物版本/构建号直接核验为 rc1711/1711。
- 构建持 `/private/tmp/veilpic-build.lock` 串行执行，复用 `.codex/DerivedData` 和 `.codex/SourcePackages`，没有 clean。原生回归结束后重新核对六项源码/版本输入指纹不变；先确认无其他构建/测试/App 进程再请求界面验收。

## 解锁后的实际保存重开验收

先前 Computer Use 返回 Mac 已锁定且自动解锁失败；保存检查点，没有绕过锁屏。后续复查已解锁，在相同源码指纹、精确工作区 Debug App 中完成本轮合成图片任务，没有修改用户项目或替换 `/Applications`。

1. 打开 `/private/tmp/xomo-ui-selection-task-source.png`，选框 `[688,778]→[803,893]`，Move 拖动 `[745,835]→[860,892]`。历史只有一个“移动选中像素”增量：4 个状态、Undo 2、Redo 0，无误触旋转。
2. 工具栏保存实际生成 `/private/tmp/xomo-ui-selection-task-rc1711-moved.xomoproject`，解析版本为 rc1711，历史未增加保存事务。导出 `xomo-ui-selection-task-rc1711-before-reopen.png`。
3. 一次 Undo 后 Cmd-S 更新既有项目文件，保留 1 个 Redo。按 selectedLayerID 定位真实选中层（不能误取第一项透明背景），其 RGBA SHA256 与原始 PNG 完全相同：`064180d38ce813878a9d0c999de23ec47791dc01b9e27933a843378a0b37e764`。Redo 后 Cmd-S，完整项目 SHA256 恢复为首次保存的 `52a86b8dac21f6816368e0c16eeb40fbf437e74eab8731113ff90f406b671a0c`。
4. Cmd-Shift-S 另存为 `xomo-ui-selection-task-rc1711-save-as.xomoproject`，当前窗口身份变为新目的地址；Cmd-Option-S 保存 `xomo-ui-selection-task-rc1711-copy.xomoproject` 后窗口仍保持另存为身份。三个实际文件各 46498099 字节，可解析且完整 SHA256 一致。菜单 AX 项失效后改用已配置的原生快捷键，并取消残留菜单焦点后核验保存面板，不将自动化失效误判为产品缺陷。
5. 原生打开面板实际重开副本，画布保留移动结果及原位绿色参考条；历史标题保留并追加“打开项目”，Undo/Redo 栈按现有设计重置为零，不宣称跨重开保存了撤销快照。导出 `xomo-ui-selection-task-rc1711-after-reopen.png`。
6. 独立 Ruby PNG 解码检查 CRC 和所有 scanline filter，重开前后 2048² 导出 RGBA 逐字节相同，保存选中层的 RGBA 也与导出一致，SHA256 为 `e64ed359e895cf8830d890c63e9625d03829aa3a5b86b24e0e0f057186d3cf36`。绿色范围 x=1400…1431、y=0…2047，共 65536 像素不变。脚本输出 `/private/tmp/veilpic-rc1711-ui-review.json` 与 `.md`，仓库留存 [JSON 摘要](2026-10-03-rc1711-ui-result.json)。验收 App 正常退出，无未保存项目丢弃。

本保存任务已通过实际闭环，准予将相关版本集成 main、打标签并推送；Git 状态仍以实际提交图和远端回读为准。安装版直接核验仍为 rc1680；下一完整 Release 编译、回归、冒烟及可恢复安装门槛仍为 rc1720。旋转 Escape 后续事件的测试与生产路径不一致风险仍另待补齐，不混入本保存修复，也不宣称已消除。项目中稠密栅格选区的 JSON 较大（本 fixture 约 46.5MB），值得下一阶段测量序列化成本；没有本轮 UI 帧延迟或内存改善证据。
