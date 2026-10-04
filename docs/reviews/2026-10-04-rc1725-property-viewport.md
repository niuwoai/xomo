# 高级图层属性视口修复与验收

rc1725 明确保留高级属性滚动区 112pt，修复图层列表优先消耗弹性空间后视口缩至零高度的约束。基线 main `55b6bdbadf2c8063d1f3d68961594ba984759851`，分支 `codex/advanced-property-viewport-rc1725`。这是同一 rc1720 验收周期的可用性修复，不扩张 Figma，不改变图像算法或属性事务。

## 生产组件回归

`ImageEditorLayerAdvancedControlsViewport` 是生产面板实际调用的 SwiftUI 组件，包含原滚动内容，仅将最大高度改为固定高度。测试用 NSHostingView 承载这个真实组件与固定 420pt、列表最小 150pt／优先级 1 的周边夹具，测量背景 NSView 的实际尺寸。宽度 300／360／460 与图层数量 0／2／20／120 形成 12 种场景，分别测展开与收起。不是简化的候选实现，也不是完整生产面板或 GUI 验收。

同一测试文件既纳入原生 Swift Testing，也可在独立进程编译运行，不调用共享 XCTest 服务。命令为 `ruby scripts/test_layer_advanced_controls_layout.rb <新的空输出目录>`；执行器持有 `/private/tmp/veilpic-build.lock`，保留编译／运行日志、JSON 和 Markdown，不覆盖旧结果。

旧生产组件保留 `frame(maxHeight:)` 时，12 项均为零高度，运行退出 1；目录 `/private/tmp/xomo-rc1725-layout-red.gWyKBm`，编译退出 0，4.313 秒。修复为 `frame(height:)` 后，12 项均通过，编译／运行退出 0，3.601 秒；目录 `/private/tmp/xomo-rc1725-layout-green.jmI20b`。测试文件指纹两次相同 `e2a57c5e3e58d2183bec76ad4741def4e377a757803c5bcf9b5a3df1b07d08f0`，未删断言；展开视口 112pt、列表至少 150pt、收起后视口消失且列表空间增加。编译前确认只有共享 testmanagerd，没有其它构建或 App；服务未重启、系统权限未改。

## 相关文件拆分

原 4445 行的 `ImageEditorLayerPanel.swift` 中连续 1672 行通道、图层复合和已保存路径代码搬至 `ImageEditorLayerAuxiliaryPanels.swift`，其专用的私有列表拖放代理也随调用点移动。逐字节对比搬移内容，除三个入口移除 private 外没有内容变化；保留区仅替换视口包装并移除末尾一个空行。原文件 2734 行，辅助文件 1716 行。三项源码接线测试更新读取位置，不减少原断言。未混入遗留巨型 ViewModel 或 Scope 测试的大范围重构，它们仍是架构债务。

首次双架构项目编译退出 65、42.352 秒，准确报告辅助面板无法访问文件私有拖放代理；结果保留在 `/private/tmp/veilpic-rc1725-gate-cycle.RZTkgo`。修正是将代理原样搬到唯一调用它的文件，不开放访问权限、不改拖放语义。随后唯一编译目录 `/private/tmp/veilpic-rc1725-gate-final.aJjnEf` 的 415 输入前后指纹同为 `2474a67b9281b1c467f03a3eec74038552871886064f97757736cdbbde0b63f8`，退出 0、688.353 秒；原生结果 succeeded、零错误、64 警告。原失败结果未删除或改写。

其中新增两条测试参数 actor 隔离警告，修正不可变 widths／rowCounts 的 nonisolated 声明后，独立组件 12 场景重跑通过，3.700 秒，测试指纹 `b42606a7e60789bae4484ddc5cb8ecc9d032b878492e41477c0b57129275a2b6`。此前沙箱禁止 Swift 模块缓存写入的失败日志保留；相同测试在允许缓存写入的环境、新目录运行，没有改断言或清缓存。

最后双架构 build-for-testing 于 08:57:22–08:57:52 +08:00 退出 0、29.903 秒，目录 `/private/tmp/veilpic-rc1725-gate-warning-verified.S0Il05`，415 输入前后 SHA256 `62ae1d1d89e61fde73bf65091480f4481a092a02436a2f5fe3be22a70bc1168a`。原生 succeeded、零错误、5 条本次增量编译警告，新增 widths／rowCounts 警告不存在；这不表示所有遗留警告都已修复。App 版本 rc1725、含 x86_64／arm64，严格 deep 签名验证退出 0；共享 testmanagerd 2101 未动。此前沙箱签名检查失败、相同检查在正常权限下成功，未重签或降低验证要求。

Universal CLI 在同一锁中独立串行构建退出 0、8.541 秒，Release CLI 测试退出 0、4.186 秒。交付 SHA256 `ddb5ab2c943666963e40ae6807dee93a7f0e9045d084c762d9d55d35e6b93bdd`；脚本实际核对版本和两种架构，不再交付历史路径缓存。日志与报告在 `/private/tmp/xomo-rc1725-cli-verified.78MKlr`；不是 Intel 原生运行或 App 实时 MCP 验收。

## 实机属性工作流

自有测试 App PID 21215 原生打开仓库 1586×992 插画，保存独立基线。展开后不透明度和填充控件实际可见；鼠标点按轨道分别改为 50%，各自 Undo／Redo 并另存。高级区滚动后可见下方 Blend If 与过滤内容，收起后列表空间增加，再展开控件仍可见。没有验证全部 Blend If 或蒙版属性编辑。

原生重开 fill-redone 项目，另存 reopened，再分别从编辑和重开窗口导出 PNG／合成／1x。`ruby scripts/verify_layer_property_workflow.rb /private/tmp/xomo-rc1725-property-workflow.gOw30C 2.12.0-rc1725` 的 25 项严格读回通过：非目标图层及目标位图／元数据不变，各属性独立 Undo／Redo 完整字节一致，重开除新增一条打开 History 外全部字段一致，两份 1586×992、1263317 字节 PNG 与解码 RGBA 完全一致，SHA256 `0f95dadaae2ccec9d5c2897dfa07011dfe7578f9f2fff8e3fae707cd5721246d`。原报告 SHA256 `7af2cbf34b7c426d932e37f26306ea78ea61fe4b80be7123b82cd6a14f9b8d1b`，原样归档到[严格读回记录](2026-10-04-rc1725-property-readback.json)。

一次 drag 调用没有观察到属性变化，不记作拖动验收。轨道点按后 Right 实际将图层移动一像素，属性值不变；独立项目保存了该观察，随后 Undo 完整恢复 mouse 项目。未证明滑块持有键盘焦点，因此不把它认定为生产键盘缺陷，也不算属性键盘通过。最初计划的 keyboard 属性验证脚本保留原样、没有执行或弱化；本轮使用不同命名的鼠标验证器，机器报告明确 keyboard_property_acceptance=false、drag_property_acceptance=false。重开窗口无未保存状态，正常 Cmd-Q 后独立进程检查确认 PID 21215 消失，不再次读取界面造成重启。

## 四小时方向审查

只读审查窗口 2026-10-04 04:49:57–08:49:57 +08:00，提交基线 `95bf420fbab64a07c3ce2033093090908fe58427`、终点 `55b6bdbadf2c8063d1f3d68961594ba984759851`。10 个非合并提交均进入 main，GitHub main 实读一致；9 个为验收证据、1 个修复真实 CLI 错误，不因补证据另涨版本。本轮生产属性入口修复也直接改善编辑流程，没有新增 Figma 功能，但不能长期以证据整理替代门槛闭环。

P1 待验证：Undo／重载后迟到 Binding 数值会走 ViewModel 第 7737 行当前选择回退，setter 第 7437 行没有建立新快照；Ownership 测试第 146–158 行只覆盖迟到 end，不覆盖值。P2 确认接口缺口、GUI 顺序未复现：第 7618 行无身份 Blend If 结束入口可提前结束其它活动滑块；面板第 453／469／497／513 行共用入口，测试第 106–113 行只覆盖新事务先结束。下一事务里程碑先验证旧结束先于新结束、迟到数值及文档重载／新会话身份，不混入本版视口修复。

## 当前验收边界

上述专项与鼠标工作流通过不代替键盘属性、拖动中断、全部属性或完整原生回归。本组件测试不覆盖生产面板所有宽度、多选标题和外层停靠区，也不证明迟到 Binding 数值或 Blend If 完成回调风险已修复。

当前版本全量 XCTest 恢复仍待明确人工许可，不沿用 rc1723 全量通过代替 rc1725。真实光标、正常候选和可恢复安装也未通过；`/Applications/Xomo.app` 保持 rc1680，测试注入权限构建不安装，不公开发布。构建技能用于唯一锁与保留缓存，文档技能用于区分实现、专项和完整门槛证据，没有宣称全项目提速。
