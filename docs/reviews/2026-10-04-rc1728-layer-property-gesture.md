# 图层属性手势所有权修复

rc1728 针对 Undo／重载后旧数值继续写入、旧同属性结束接管新手势两个缺陷，将八个属性滑块的数值和结束共同绑定不可变身份。基线 main `1204ab9b539665183af434029c92a615b0b6cfaf`，分支 `codex/layer-property-gesture-ownership-rc1728`。本版测试与实机验收尚待完成，不能放行 rc1720 完整门槛。

## 实际失败基线

加载已核验的 rc1727 生产 dylib，并用实际 ImageEditorViewModel 执行原 Binding 调用顺序：不透明度预览后 Undo，再调用旧 setter，文档与不透明度两处断言失败，但没有新增撤销快照；取消旧预览后建立新的不透明度手势，旧 commit 将新手势结束，一处断言失败。两方法实际执行、退出 1，共三处 issue，不是静态推测；模拟的是现有 UI 回调顺序，尚不证明该顺序已用物理输入触发。

诊断在唯一锁内运行，原模型未重编，原始事件位于 /private/tmp/xomo-rc1728-stale-value-red.xFtpfn/events.jsonl，摘要原样归档为 [失败记录](2026-10-04-rc1728-stale-value-red.json)。第一次编译缺少 Sparkle 头文件搜索路径，未运行测试；增加实际 Build Products 的 framework 搜索路径后成功，首轮 compile.log 保留，不改断言。

## 生产调用路径

ImageEditorLayerPropertyGesture 使用新的 UUID 和属性组合。每个新手势先结束旧属性事务，再独立建快照；数值与结束均严格核对身份。取消、重载、普通命令及合法程序化 begin／finish 使旧身份失效。只约束带身份的 UI 回调，没有将所有无活动事务的 setter 禁用，因此自动化和已有合法调用保持原入口。

ImageEditorLayerPropertyNativeSlider 在 mouse-down 局部捕获一对不可变回调，连续 action 使用该对回调，defer 使用同一结束；SwiftUI updateNSView 可以更换下一手势的工厂，但不能覆盖正在追踪的回调或拇指位置。键盘方向键按原 step 离散执行，独立建撤销事务。八个生产滑块都接入，移除八个无身份 Binding；标签沿用现有本地化资源，native accessibility label 同样来自字典。

新增完整模型测试覆盖八属性和七类中断、64种新旧属性组合（包括同属性）、跨模型身份／非法数值，及真实 NSSlider 对象的重配置、Undo 后 action／release、键盘 step／Undo。原生控件单测直接执行生产追踪与 action 路径，不是物理鼠标或实际键盘焦点验收。

## 实际验证状态

- 版本合同：App、CLI 与 Xcode 六配置为 rc1728／1728；`test_release_contract.rb` 10 项／30 断言、产品概览 3 项／22 断言通过。README、CLI mock 和面板样式合同也在实现过程中通过。
- 原完整双架构 Release `build-for-testing`（2026-10-04 11:31–11:58 +08）：423 个 Swift 输入指纹 `26e5a14715d64150352e08a0c6ee9de2900b2adfb7e0ab120f4bcabeff0ea1db` 未漂移；App 与测试目标编译、链接完成，最终在 App `CodeSign` 失败：`The timestamp service is not available.` xcresult 为 failed、1 error、64 warnings，故不能称完整构建通过，也没有运行测试或可安装产物。
- 定向 Release `build-for-testing`（2026-10-07）：第一次重用时未带 `ENABLE_TESTABILITY=YES`，测试模块无法导入 `musepic`；按原项目测试设置补齐后，arm64 定向构建成功，0 errors、75 warnings，并生成原生 `.xctestrun`。这次明确设 `CODE_SIGNING_ALLOWED=NO`，仅用于运行单测，不可安装、签名或代替完整门槛。
- 原生 `xcodebuild test-without-building`：`ImageEditorLayerPropertyGestureTests` 全部通过，6 个测试函数、124 个用例（56 种中断、64 种旧／新属性配对及 4 个控件／边界用例），执行 1.275 秒。Xcode 输出 `TEST EXECUTE SUCCEEDED`。直接 Swift Testing 执行器曾在初始化 `NSApplication` 时因 Launch Services abort，未进入测试；因此舍弃该执行器结果，采用 Xcode 原生宿主。

本次证据只关闭 rc1728 的目标单测，不关闭完整门槛。组件库系统箭头和工具语义光标、全量测试、签名 Release、冒烟、可恢复安装仍待完成；`/Applications/Xomo.app` 仍是 rc1680。下一步应补做真实鼠标拖动/中断、系统键盘与辅助功能输入验收，并完成逾期的 rc1720 完整构建门槛；不扩张 Figma。
