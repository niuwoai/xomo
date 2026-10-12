# rc1841 四十版本完整门槛记录（安装待续）

## 基线与范围

- 目标门槛：rc1840（覆盖 rc1801–rc1839 的四十个小版本）；首轮全量测试发现既有范围守卫误报后，依仓库版本规则修正并在 `2.12.0-rc1841` 重验。
- 本地 `main` 基线：`7fd0506e5b77257cb3ca1be79ad9d1a25ddff7e3`（rc1839）；仓库没有 `develop` 分支。
- 验证期间生产代码仅含 rc1838/1839 Image Size 修改；rc1841 调整的是 `ImageEditorScopeTests` 的重型 3D 场景静态范围守卫和版本/记录文件。
- 验证窗口：2026-10-13 06:53–07:36（Asia/Shanghai）；Xcode/Swift 构建串行运行，使用 `/private/tmp/veilpic-build.lock`。

## 全量回归

- rc1840 首次完整隔离回归：232/233 执行组通过，失败组 `ImageEditorScopeTests`；3796 项中该组的 200 项未计通过。失败检查在 `veilpicTests/ImageEditorScopeTests.swift:2102`，通用 `threeDimensional` / `threeD` 字符串守卫误命中 `ImageEditorModels.swift` 已存在的合法 3D `.cube` Color Lookup LUT 字段，不是重型 3D 场景能力。
- rc1841 将通用字串替换为具体场景框架/类型入口（SceneKit、RealityKit、ModelIO、SCNScene、MDLMesh），重新编译测试宿主并完整复跑：233/233 执行组、3796/3796 项通过，失败 0。JSON/Markdown 报告：`/private/tmp/xomo-rc1841-full-gate/tests/report.json`、`report.md`。

## Release 与 CLI

- Universal Release archive：`xcodebuild archive` 成功；产物 `/private/tmp/xomo-rc1841-full-gate/archive/Xomo.xcarchive/Products/Applications/Xomo.app`。`Info.plist` 读回 `2.12.0-rc1841` / build `1841`，主可执行文件架构 `x86_64 arm64`。
- archive 签名 Authority 为 `Developer ID Application: Beijing Alibaba information Technology Co., Ltd. (ZH2S7D6PL6)`，Team ID `ZH2S7D6PL6`；`codesign --verify --deep --strict` 返回有效，签名带 Apple 时间戳（2026-10-13 07:31）。
- `spctl --assess --type execute` 返回 `rejected`，来源为 `Unnotarized Developer ID`。这是未公证分发包的 Gatekeeper 结果；本轮没有公证，也没有移除隔离标记、重签包或修改 Gatekeeper。故不能记录为 Gatekeeper 接受或公证通过。
- CLI Universal Release 构建成功；实际产物 `dist/xomo-macos-universal` 架构 `x86_64 arm64`，`xomo version` 输出 `2.12.0-rc1841`；CLI XCTest 2/2 通过。SwiftPM 提示 macOS 27.0 部署目标的 x86_64 架构已弃用，未阻断当前构建。
- 发布合同 12 runs/36 assertions，CLI 合同 7/24，概览合同 3/30，隔离运行器合同通过；版本合同报告 `passed: true`，App/CLI/Xcode 版本和 build 一致；zh-Hans/en/ja `.strings` 全部 `plutil -lint` 通过，`git diff --check` 通过。

## `/Applications` 安装与 UI 冒烟（待用户保存/关闭）

- 安装前读回 `/Applications/Xomo.app` 为 `2.12.0-rc1803` / build `1803`；旧包 `codesign --verify --deep --strict` 有效，旧应用进程 PID `85712` 正在运行。
- 使用正常 Cmd+Q 尝试退出时，Xomo 明确提示关闭前需要保存“未命名画布”的更改。已选择“取消”并保留原应用与画布；没有强制退出、丢弃内容、替换 `/Applications` 或启动未公证的新包。
- 因当前应用仍承载未保存文档，本轮没有进行 staged install、启动新版本或 Image Size UI 冒烟。恢复后先由用户保存并关闭旧文档，再复制校验旧版备份、安装 rc1841 并以正常方式启动；若 Gatekeeper 仍拒绝，停止在系统提示处，不绕过安全策略。

## 当前结论与下一步

- 已完成：修正范围守卫误报、全量 XCTest、Universal Release archive 与严格 Developer ID 验签、Universal CLI 与 CLI XCTest、版本/发布合同。
- 未完成：Gatekeeper 接受/公证（本轮不执行公证）、`/Applications` 可恢复替换安装及安装版真实 UI 冒烟。rc1840/1841 周期门槛暂不记为完整通过，当前旧版仍为 rc1803/build1803。
- 旧版文档保存并关闭后继续本机安装验收；届时重读 Gatekeeper 和签名状态。下一四十版本门槛只有在本轮安装验收闭环后才记为 rc1880。
