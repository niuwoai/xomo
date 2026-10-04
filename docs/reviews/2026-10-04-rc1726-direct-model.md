# rc1726 直接模型回归与测试接线缺口

本轮在源码不变的 rc1726 上实际执行完整模型回归。新增 Blend If 交错测试的 24 个内部场景通过；相关八个套件均执行完成，其中七个完整套件、339 个方法、851 次运行通过，LayerComp 套件有四处源码接线断言失败。不能报告八组全部通过或放行 rc1720 完整门槛。本轮只补证据，不增加版本，不修改生产／测试源码，不重写已有标签。

代码基线 main 为 `ac90367ecf528940be144ed2d70b35d4634ec1d1`。419 个真实输入 SHA256 仍为 `1ddea5ad0a8a856d7be59d83bf7f3249695151a94ec560fdc42e0e3f62d8f34d`，与成功的 rc1726 Universal Release 测试编译相同；原 App 和测试 arm64 对象哈希均未变，没有重编项目或改写其缓存对象。

## 实际执行与失败传播

临时执行器使用本机 Xcode 自带 Testing 框架及接口 `Testing.__swiftPMEntryPoint(passing:)`。正向探针退出 0，一个方法开始和结束、零 issue；故意错误断言探针退出 1，一个方法开始和结束、一个 issue，确认失败会传播。探针不是产品回归。

从原编译日志提取 arm64 链接命令，移除 bundle loader 和写回原缓存的元数据，重链接原对象为临时 dylib；不复制候选模型或改断言。首次加载缺少 libXCTestSwiftSupport.dylib 搜索路径，退出 2、目标未执行。增加 Xcode 的 Platforms/MacOSX.platform/Developer/usr/lib rpath 后真实目标执行通过。24 场景位于一个非参数化方法内部，不计为 24 个方法。

逐组用清单核对精确开始／结束标识；参数方法另核对每个方法的 case 开始／结束数量，无缺项、额外方法或跳过。[汇总记录](2026-10-04-rc1726-direct-model-result.json)保留命令、全部结束标识、事件／日志哈希、资源哈希和临时执行器源码。

## 宿主环境修正和原失败

沙箱运行样式套件出现 11 处像素断言失败；正常权限下同一 dylib 和断言的 96 方法全部通过，旧失败保留。对照证明运行权限环境影响此直接执行路径的图像结果，底层原因未定位，不把旧失败判为产品回归。

未携带 App 资源、未初始化 NSApplication 的执行器，Scope 出现六处本地化失败并异常中断。临时 ModelProbe.app 复制原构建资源且逐文件哈希一致，使用独立 bundle identifier；执行前初始化 NSApplication，activation policy 为 prohibited，不启动产品 UI。正常权限下 Scope 的 194 方法全部通过；修改的是临时宿主，不是产品。

所有流程串行持有 /private/tmp/veilpic-build.lock，子进程只继承最小 PATH，不调用会输出环境的 xctest 帮助命令。失败和重跑分别保留在 /private/tmp/xomo-rc1726-direct-model.rQkSQ9、/private/tmp/xomo-rc1726-direct-model-v2.IApZDx、/private/tmp/xomo-rc1726-direct-model-v3.TkUnee。自动生成的 default.profraw 移到最终临时目录保留，不提交该覆盖率二进制。

## 最终相关回归

| 套件 | 方法 | 运行 | 结果 |
| --- | ---: | ---: | --- |
| ImageEditorLayerPropertyOwnershipTests | 6 | 246 | 通过 |
| ImageEditorLayerBatchAppearanceTests | 6 | 6 | 通过 |
| XomoLayerPropertyCommandBoundaryTests | 4 | 196 | 通过 |
| ImageEditorDeferredRedoBoundaryTests | 3 | 83 | 通过 |
| ImageEditorLayerStyleTests | 96 | 96 | 通过 |
| ImageEditorScopeTests | 194 | 194 | 通过 |
| ImageEditorLayerCompTests | 33 | 33 | 4 处断言失败 |
| ImageEditorSavedPathTests | 30 | 30 | 通过 |

八组共执行 372 方法。LayerComp 的 33 方法都有开始和结束，但其中一个方法有四处失败，套件不通过；失败后单独补跑 SavedPath，没有删除失败或将七组通过拼成八组全绿。

## 确认的测试接线问题

ImageEditorLayerCompTests.swift 第 590–593 行在 rc1725 拆分后只读取 ImageEditorLayerAuxiliaryPanels.swift；第 624、625、627、628 行仍在该文本中检查 Return、Escape、Up、Down selector。真实共享搜索框 Coordinator 留在 ImageEditorLayerPanel.swift 第 224–243 行，辅助文件继续传入提交、取消和相邻选择回调。四处失败是读取边界未覆盖原断言，不证明用户键盘处理丢失。

下一小版本应分别读取辅助面板与共享搜索框实现，检查调用接线及处理器，保留全部旧断言；不要拼接整个仓库或删断言求通过。本轮尚未修正，报告仍是失败。

## 完整门槛和下一步

此路径是在普通 arm64 进程加载原 Xcode 对象，不等价于 XCTest 原 App 宿主、原生全量或 Intel 原生运行；共享 testmanagerd 未重启、未确认恢复。完整模型交错回归从未执行推进为直接执行通过，但迟到数值、同属性不同会话、中断手势与真实组件库箭头／语义工具光标仍待验证。

继续同一 rc1720 门槛，不顺延 rc1760，不增加 Figma 范围。正常候选与可恢复安装未通过；测试权限 App 和临时 ModelProbe.app 不安装、不公开发布。构建测试技能用于唯一锁、指纹与失败传播，文档技能用于明确直接执行和完整验收边界。
