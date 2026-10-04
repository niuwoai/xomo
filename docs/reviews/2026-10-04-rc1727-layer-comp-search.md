# LayerComp 搜索框回归读取边界修复

rc1727 修正回归测试的源码读取边界，不改变生产键盘交互。基线 main 为 `38d48fe8e02eaf741701f5a8ec0c888e0b331ed4`，分支 `codex/layer-comp-search-regression-rc1727`。实际双架构测试编译、严格签名、九个相关套件 373 方法／885 次运行通过，旧四处断言失败消除；继续同一 rc1720 完整门槛，不增加 Figma 范围。

## 已确认的失败基线

rc1726 使用实际 Xcode 编译对象直接执行 LayerComp 套件，33 个方法均执行，搜索框源码接线方法的第 624、625、627、628 行有四处断言失败。面板拆分后该方法只读取 ImageEditorLayerAuxiliaryPanels.swift，但共享 ImageEditorLayerSearchField 的原生 Coordinator 仍在 ImageEditorLayerPanel.swift；失败不证明键盘处理丢失。原始事件、精确方法清单和失败保留在[上一版记录](2026-10-04-rc1726-direct-model-result.json)，不重写它。

## 本版范围

保留辅助文件的原上下文／动作／拖放检查；另读取共享面板文件，仅取 ImageEditorLayerSearchField 到下一个 ImageEditorLayerPanelTabLabel 类型之前的明确范围。四项原 selector 断言只改检查对象，不删除或弱化期望；新增五项界面调用接线检查，确认实际使用共享搜索框及四种回调。没有拼接全仓库文本来制造匹配。

新增 ImageEditorLayerSearchFieldDispatchTests 的一个方法调用真实 makeCoordinator 和 NSTextFieldDelegate.control 生产路径。Return、Escape、Up、Down 分别在回调存在／不存在时形成八个内部场景，检查事件是否处理、仅对应回调调用一次；每个场景另检查 Left 不被拦截、计数不变。不是候选处理器、源码字符串替代或真实 GUI 键盘验收。新文件独立于已有 2239 行 LayerComp 测试，避免继续堆大文件，本轮未混入大规模测试拆分。

## 版本和验证状态

App、CLI、Xcode 六配置同步 2.12.0-rc1727／1727。版本契约实际 10 项／30 断言通过。新增真实分派单测的八个内部场景已执行通过；它是一个测试方法，不计成八个方法。原文件含 #expect 的 714 行，按四项来源替换后全部保留，当前 719 行，未删除旧断言。

唯一 Universal Release build-for-testing 已结束：10:34:23–10:56:12 +08:00，退出 0、1308.529 秒，目录 /private/tmp/veilpic-rc1727-gate-cycle.b1VFbp，会话 31255、PID 32297 已终态，不是活跃构建。420 个真实输入 SHA256 为 `e6fd02db8bcd6b9ed96cb521b63e230ced4e3a2d5380b10ef0bffb4240b8fd6d`，复用原 DerivedData／SourcePackages，持有 /private/tmp/veilpic-build.lock。进程使用最小 PATH，日志只落到本轮目录，不打印环境凭据，产物标记为 test-only injection、不可安装。输入前后指纹一致；原生 succeeded、零错误、56 警告，新增 Dispatch 和修改的 LayerComp 测试没有对应警告，不称遗留警告已清除。App 实读 rc1727、含 x86_64／arm64，严格 deep 签名核验退出 0；[构建记录](2026-10-04-rc1727-test-build.json)原样归档，[原生摘要](2026-10-04-rc1727-native-build.json)脱敏设备信息。工具摘要首次因警告混入 JSON 未解析，分离诊断后成功，没有再次编译。

## 实际扩大回归和 CLI

临时执行器加载本版真实 Xcode App／测试 arm64 对象，原对象哈希和 420 输入执行前后不变；复制实际构建资源并逐文件核对，初始化 NSApplication，串行执行九个相关套件。LayerComp 33 方法通过，新增 Dispatch 一个方法通过，其余属性所有权、批量外观、自动化命令边界、延迟 Redo、样式、Scope、SavedPath 同样完整通过，总计 373 方法／885 次运行。每组精确清单、case 开始／结束逐方法数量一致，没有缺项、额外方法、issue 或跳过。正向探针退出 0，故意错误断言退出 1，失败传播有效；不会把零测试或前置探针当产品通过。机器证据见[直接模型回归](2026-10-04-rc1727-direct-model-result.json)，目录 /private/tmp/xomo-rc1727-direct-model.SCCj7o。本版同源码完整模型 Blend If 24 内部场景也随 Ownership 套件再次执行通过，不解决迟到值／同属性会话。

同一锁内串行真实 Universal CLI 构建退出 0、13.783 秒，实读版本 rc1727 且 arm64／x86_64 验证通过；Release CLI 编译及两方法运行退出 0、28.409 秒，实际通过 initializeReturnsToolCapability 和 toolsListWorksWithoutRunningApp。日志内旧 XCTest 的零测试行不是这两项 Swift Testing 的数量。交付 SHA256 为 df2ca2f3adf27a7926488466a0b5724789eb98d6938929e5a2979e91985b6a94，[CLI 记录](2026-10-04-rc1727-cli-result.json)原样归档，目录 /private/tmp/xomo-rc1727-cli-verified.PlE8YK；不证明 Intel 原生运行或实时 App MCP。

产品概览 3 项／22 断言、CLI 构建脚本模拟契约 7 项／24 断言（6.564589 秒）、图层 tab 样式四项、README 29 项、格式检查通过。模拟契约不替代上述真实 CLI 构建。此轮比上一轮构建耗时更长，负载／输入不同，不以缓存复用宣称全链路提速。

## 当前验收边界

共享 testmanagerd 未重启，未获得恢复许可；直接模型执行不等价于原生全量或完整门槛。当前版全量、滑块中断／会话安全、真实组件库系统箭头与工具语义光标、正常候选与可恢复安装尚未通过，/Applications 实读仍 rc1680。构建技能用于唯一锁与真实输入核对，文档技能用于保持失败、待执行和通过的明确边界。
