# rc1724：Universal CLI 实际交付路径

> 基线 main `eb96080ee64f4e725cd6b1aede10dc71ce271cec`；分支 `codex/cli-release-artifact-path-rc1724`。继续同一 rc1720 四十版本门槛，不扩张 Figma，不改变编辑算法或光标。

## 实际失败与修复

rc1723 全量 Release 原生回归于 05:10:19 +08:00 退出 0，225 套件/3637 方法/4584 次运行全部通过，412 输入未变；[独立机器报告](2026-10-04-rc1723-release-full-result.json) 保存逐组覆盖和原始报告 SHA256。之后唯一锁串行 CLI 构建退出 0、10.13 秒，交付 `dist/xomo-macos-universal` 却实际输出 `2.12.0-rc1200`；文件是双架构历史产物，来自固定 `.build/apple/Products/Release`。当前 SwiftPM `--show-bin-path` 实读 `.build/out/Products/Release`，该目录当前源码产物实际输出 rc1723。随后原生 CLI 测试 2 项通过，但不能修复交付路径错误。

脚本现在用同一组 Release/arm64/x86_64 参数先构建、再查询输出目录；拒绝缺失可执行文件、版本与 CLI 源码不一致或缺少任一架构的产物。全部校验后在 dist 内暂存，原子替换交付文件；失败保持已有文件，不回退至旧目录、不清缓存。App/CLI/Xcode 六配置及版本契约同步 rc1724/1724。

## 有效验证

新增 Ruby 隔离夹具同时放置当前目录和旧 rc1200 二进制，覆盖带空格路径、相同构建/查询参数、旧产物拒绝、缺失不回退、仅 arm64 拒绝、构建失败保留交付。修复前 5 项/8 断言中 4 项失败、1 项通过；补充失败路径查询与失败 version 命令不得用部分输出交付两项回归后，最终旧脚本 RED 为 7 项/11 断言中 6 项失败、1 项通过；最终修复 7 项/24 断言全部通过，零错误/跳过。这是脚本契约，不冒充真实编译。

原生交付校验初两轮因当前 lipo 多架构参数解析失败退出 1；原日志保留，未覆盖旧交付。改为原生已核实的两次单架构验证，并在夹具严格检查参数和两次验证顺序。最终脚本明确保留命令替换的失败退出码（不被 readonly 声明吞掉），原生构建退出 0、5.07 秒，交付版本 rc1724，含 x86_64、arm64，SHA256 `ee210cba2a2a5ea08e55a6a2efc30aee30899cad9e2c2e4f30b7456d6d3ce02b`。原生 Release CLI 测试 2 项全部通过，退出 0、6.88 秒；不是 Intel 运行验证。

最终交付二进制实际处理离线 MCP initialize、通知、tools/list：2 个有 ID 响应，serverInfo 版本 rc1724，工具 127 项，包含 `xomo.layer.properties`；目录哈希 `a0facd19d6798f1bdd7823836b10a95e4361360900d73454d547e24cc6bae6fc`。离线回退目录不证明与运行中 App 的调用、导出或项目往返。

原始日志位于 `/private/tmp/veilpic-rc1723-gate-cycle.pdbG1A/cli-release-{build,tests}.log`、`/private/tmp/veilpic-rc1724-cli-release-{build,final-build,verified-build,tests}.log`，最终构建日志为 `/private/tmp/veilpic-rc1724-cli-release-final-verified-build.log`，最终契约 RED/绿灯为 `/private/tmp/veilpic-rc1724-cli-contract-final-{red,green}.log`。[机器记录](2026-10-04-rc1724-cli-artifact-path-result.json) 区分失败、通过与未完成。

## 审查与下一里程碑

rc1724 修复提交 `1fbacf119c23e7d27f07149a7bbda4a206352edf` 已合入 main `eeea375ca9959f11c859e7c470a8550706f61b54`，GitHub 修复分支/main/标签 `v2.12.0-rc1724` 均实读匹配。随后于 05:28 +08:00 启动唯一 Universal Release 测试编译会话 95279，尚未完成，不称通过；412 编译输入启动前指纹 `68659c8c9392c7e017645c42e09d476dbee448596475534214d1e70df26403a1`，输入契约和新日志位于 `/private/tmp/veilpic-rc1724-gate-cycle.5dtTIx`。只复用固定 Release 缓存与唯一锁，不清理、不启动第二份构建；编译输入继续冻结，文档更新不改变该指纹。测试注入权限产物不得安装。

四小时只读窗口 2026-10-04 01:06:38–05:06:38 +08:00，基线 `98e9f56d9f00b9959fb4214fc275a466785ac5ae`，终点 `eb96080ee64f4e725cd6b1aede10dc71ce271cec`；main 已集成所有窗口内版本，GitHub 标签核验一致，工作区当时干净，没有新增 Figma 能力。遗留 Blend If 四个滑块共享无身份完成入口，旧回调在新事务活动时可提前完成新事务；现测试只覆盖新事务先结束的顺序。取消预览后的旧 Binding 值写入也未验证。代码路径缺口与物理事件复现分开，不声称已复现 GUI 故障。

构建提速技能用于固定缓存、唯一锁和真实退出/产物检查；发布技能用于测试产物与正常候选隔离，没有改发布引擎或签名流程。当前 rc1724 App 编译输入已改变，必须复验同版本 App，再串行 UI、真实图像编辑/Undo/Redo/保存重开/导出及组件库系统箭头/语义光标，包含上述事件顺序。最后验证正常候选及可恢复安装。不能用 rc1723 的全量绿灯代替当前版本；安装仍 rc1680，无公开发布。
