# Blend If 结束回调身份修复

rc1726 让四个 Blend If 滑块的结束回调携带属性身份，避免旧属性的结束提前提交另一个活动属性。基线 main `8f80c445efd3dcd75a3f10507f256271e74d9df0`，分支 `codex/blend-if-completion-identity-rc1726`。修复只覆盖不同属性的结束所有权，不声称同属性不同会话或迟到数值已经安全；继续同一 rc1720 完整门槛，不扩张 Figma。

## 生产调用路径

`ImageEditorLayerPanel.swift` 的 sourceBlack、sourceWhite、underlyingBlack、underlyingWhite 四个结束回调，分别传递对应的 `ImageEditorLayerBlendIfEditKind`。四个自动化属性命令也传递同样的身份。模型 `commitSelectedLayerBlendIfChange(_:)` 先调用真实生产规则 `ImageEditorLayerBlendIfCompletionOwnership.mayFinish`，只有活动属性与结束属性相同才完成；无活动事务或属性不同则不修改文档、History 或 Undo/Redo。无参数的公共结束入口已移除。

普通编辑命令仍通过 `finishActiveLayerPropertyEditForNewCommand()` 调用私有统一结束方法，不被滑块的身份判断拦住。合法自动化命令仍先校验输入再完成先前编辑，未改变无效输入的事务原子性。

## 有限文件拆分

连续 421 行属性 setter、begin/end、目标捕获与 History/Redo 逻辑搬至 `ImageEditorLayerPropertyTransactions.swift`。十二个原私有状态字段由同一模型拥有的状态对象保存，字段保持文件私有；只开放被该扩展调用的六个原模型辅助方法。原主题 Redo 属性的访问改为其原 getter/setter 使用的 `undoTransactionState.redoThemes`，没有另建主题历史。

恢复原字段前缀、主题 Redo 别名及结束入口后，搬移的方法块与基线逐字节一致。自动化属性与锁命令搬至 `XomoLayerPropertyAutomation.swift`，恢复两项访问级别和四个 typed end 后，除扩展收尾空行外与基线一致；三个校验辅助函数仅调整跨文件访问级别。

这是局部搬移，不是大范围重写。新事务文件 469 行、自动化文件 90 行；遗留 ViewModel 仍 12936 行、Registry 仍 8472 行，超过仓库行数限制的架构债务尚未清除，不称整体文件规范已经满足。

## 单元测试与构建证据

独立执行器编译真实生产身份规则与同一测试夹具，不复制候选算法，不使用或重启共享 XCTest 服务。命令为 `ruby scripts/test_blend_if_completion_ownership.rb <新的空输出目录>`，持有 `/private/tmp/veilpic-build.lock`。目录 `/private/tmp/xomo-rc1726-completion-unit.20261004-25110-f4acxr`：编译和运行退出 0、2.791 秒，四属性的 16 种活动/结束组合与 4 种无活动组合全部通过。原始报告原样归档至[单元结果](2026-10-04-rc1726-completion-unit.json)，SHA256 `4b7e75547b75b055e0b664ac9b574b9d63e1c99d5de7a2678899f02b4a985a64`。它只证明身份判断，不证明完整模型事务或 GUI 顺序。

完整模型新增 `delayedBlendIfEndDoesNotFinishAnotherActiveSlider`：12 种不同属性对乘以先前属性有/无变化，共 24 场景。旧结束先于新结束到达时，比较完整项目和 History/Undo/Redo/主题快照，并验证活动状态和后续 Undo/Redo。原有断言均保留，批量外观测试的九项已有 Blend If 调用点补与 begin 对应的类型；其它已有调用点同样只补类型，保持原场景。该模型回归尚未执行，不能记为 24 场景通过；没有以规则测试充当完整模型 RED 或 GREEN。

版本契约首次实际失败：10 项/23 断言、1 失败，测试期待构建号 1725、实际为 1726；修正该遗漏后 10 项/30 断言通过。CLI 构建脚本契约 7 项/24 断言通过，6.096411 秒；新增执行器 Ruby 语法检查通过。产品概览在更新前也实际失败（3 项/17 断言、1 失败），不把中途文档未同步写成最初全绿。

产品概览更新后 3 项/22 断言通过，版本契约再次 10 项/30 断言通过；图层 tab 样式 4 项、README 29 项通过，`git diff --check` 通过。

唯一双架构 Release `build-for-testing` 会话 57545、PID 25278 已结束：2026-10-04 09:21:41–09:33:34 +08:00，退出 0、713.148 秒，目录 `/private/tmp/veilpic-rc1726-gate-cycle.0u5PyS`。419 个真实编译输入前后指纹同为 `1ddea5ad0a8a856d7be59d83bf7f3249695151a94ec560fdc42e0e3f62d8f34d`；原生 succeeded、零错误、62 警告，新事务/身份/自动化文件及新增回归文件没有对应警告，不称全部遗留警告已清除。App 实读 rc1726、含 x86_64/arm64，严格 deep 签名验证退出 0。构建使用现有 ReleaseDerivedData/SourcePackages 与唯一锁，测试注入权限产物不得安装；编译成功不是模型回归执行通过。

[执行报告](2026-10-04-rc1726-test-build.json)原样归档，SHA256 `9a7bfb435b29064e3d26a12564f93e5c7a470d1acd3536bae76f1ebf93773c79`；[原生构建结果](2026-10-04-rc1726-native-build.json)仅脱敏设备标识，原始 xcresult 本地保留，未修改签名或原日志。

## 实机 Blend If 工作流

自有 rc1726 测试 App PID 27185 打开 rc1725 独立基线，再另存本轮 baseline，不覆盖旧验收。高级区真实鼠标点按黑场后显示 67–255，另存 black；点按白场后显示 67–194，另存 white。两步分别 Undo 到 black、baseline，再分别 Redo 到 black、white，各自保存独立快照，确认不是显示值变化却缺失事务。正常重开 white-redone、另存 reopened，分别界面导出编辑结果和重开结果的 PNG/合成/1x；另开本轮 baseline 导出未编辑对照，最后重开后画布可见浅色区域变透明、较深图案保留。

`ruby scripts/verify_layer_blend_if_workflow.rb /private/tmp/xomo-rc1726-blend-workflow.Q5Hxiu 2.12.0-rc1726` 的 21 项严格检查通过。两次 Undo/Redo 均完整项目字节相同，非目标图层及目标位图/其它元数据保留，阈值精确为 67/255 与 194/255；重开除新增一条打开 History 外字段一致。编辑与重开 PNG 同为 1586×992、218015 字节，文件和 RGBA 完全相同，SHA256 `4b93cc83549a65df033890284a00fe0038df12b488bca63fb68d3ce96c6609f0`。相对于基线 1503664 像素改变，可见像素从 1573312 降至 69648，证明 Blend If 对实际输出产生透明效果，不只是属性显示改变。

[严格读回报告](2026-10-04-rc1726-blend-if-readback.json)原样归档，验证器记录自身与十一份项目/PNG 的哈希。只覆盖普通当前图层黑场/白场顺序完成，不覆盖迟到值、同属性旧会话、拖动中断、下方图层两个控件或完整 GUI 光标验收。自有 App 正常 Cmd-Q 后独立进程检查确认 PID 27185 消失；未再次读界面使其重启，共享 testmanagerd 2101 未动。

## 四小时审查与下一里程碑

本轮只读审查窗口 2026-10-04 05:26:34–09:26:34 +08:00，基线 `eb96080ee64f4e725cd6b1aede10dc71ce271cec`、main 终点 `8f80c445efd3dcd75a3f10507f256271e74d9df0`。10 个非合并提交全部进入 main，GitHub main 和 rc1725 标签已实读核对；8 个为验收记录、2 个修复实际 CLI 和属性入口问题，没有 Figma 扩张。rc1725 的 25 项验收报告及所有产物哈希重新核对一致，但不替代 rc1726 的模型或实机验证。

P1 待验证风险：Undo/重载取消属性预览后，迟到 Binding 数值仍可经当前选择回退直接修改文档，而 setter 不建立快照；现有重置/重载测试只补迟到结束，缺迟到值。P2 待验证风险：本版仅比较属性种类，旧 sourceBlack 会话的结束仍可能结束新 sourceBlack 会话。下一事务里程碑应验证并收敛界面数值与结束的会话身份，同时保留合法程序调用和自动化命令行为，不能简单禁用全部无活动 setter。

共享 XCTest 服务恢复仍待明确人工许可，本轮没有重启 testmanagerd、修改系统权限或强退 Xedit。当前版完整原生回归、真实组件库箭头/语义工具光标、滑块中断、正常候选与可恢复安装尚未通过；不沿用 rc1723 全量结果，不把门槛顺延为 rc1760。`/Applications/Xomo.app` 实读仍 rc1680，不公开发布。构建技能只用于缓存与唯一锁，文档技能用于区分实际结果与未验证假设。
