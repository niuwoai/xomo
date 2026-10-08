# rc1761 Finder 冷启动文件打开验证

- 基线：`a92196c8`（rc1760 门槛），开发分支 `codex/rc1761-cold-file-open`。
- 目标：修复文件通过 Launch Services 冷启动 Xomo 时进程已启动但没有编辑窗口；支持原生项目替换保护。

## 实现

- `veilpicApp` 从 SwiftUI 环境捕获 `openWindow(id:)`，绑定到 AppDelegate；收到 macOS 文件打开事件时先交给协调器排队，再确保编辑窗口已请求打开。
- 协调器在工作区注册前保留待处理文件；环境动作若晚于文件事件绑定，绑定时会补发窗口打开请求。一个窗口创建请求在工作区注册前只发送一次。
- 原生 `.xomoproject`、`.qpicproject` 与 JSON 项目进入同一异步外部文件协调器，沿用未保存文档替换确认、成功打开后登记最近文件及窗口激活流程。

## 验证

- `ruby scripts/run_tests_isolated.rb --filter XomoExternalDocumentOpenTests`：27/27 个独立执行组通过。
- 冷启动待注册项目队列：1/1 通过；未保存原生项目替换保护及项目保存目标回归通过。
- SwiftUI/AppDelegate `openWindow` 接线：1/1 通过。
- `ruby scripts/test_release_contract.rb`：10 项、30 断言通过；`ruby scripts/test_xomo_cli_release_build.rb`：7 项、24 断言通过；`ruby scripts/test_product_overview_archive.rb`：3 项、26 断言通过。
- 真实 Launch Services PNG 冷启动：候选 `2.12.0-rc1761` / build `1761` 进程可见，窗口数 1，标题 `xomo-startup-artwork.png`。仅验证 Debug 候选；未覆盖 `/Applications`。
- 真实 Launch Services 原生项目冷启动：用应用自动化接口从空白画布导出临时 `.xomoproject`，冷启动候选后再从应用读回；源文件与读回文件的 `sourceName`、`canvasSize`（1440×900）、图层数（2）及 `formatVersion`（11）完全一致。窗口数 1，标题为项目文件名。

## 边界

- 本轮验证的是 Debug 候选和本机自动化通道，不是独立 Release CLI；未覆盖 `/Applications`、Release archive 或公证。
- 未执行四十版本完整门槛、Release archive、全量项目测试、签名/公证或 GitHub 发布；下一完整门槛为 rc1800。
- 本记录不证明 Figma 导入或其它编辑能力完成，也未扩张 Figma 范围。
