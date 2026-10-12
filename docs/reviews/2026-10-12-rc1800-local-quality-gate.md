# rc1800 本机完整质量门槛记录

- 执行日期：2026-10-12
- 验收版本：`2.12.0-rc1803` / build `1803`（rc1800 周期门槛在该当前版本执行）
- 基线：`v2.12.0-rc1802`，`5f9fe81e`；结束源码：`17fe1942e9372ca46aeec8b94736b3c8f059d630`
- 目标：完整测试、GUI 与 CLI Release 构建、实际启动/交互冒烟，以及可恢复地覆盖本机 `/Applications/Xomo.app`。

## 完成并读回的项目

- 完整 GUI suite：233/233 执行组通过，3,753/3,753 测试通过，失败 0；机器报告位于 `/private/tmp/xomo-rc1803-full-gate/tests/report.json`。
- GUI Release archive：`/private/tmp/xomo-rc1803-full-gate/Xomo.xcarchive` 构建成功；应用版本/build 读回为 `2.12.0-rc1803` / `1803`，主可执行文件包含 `arm64` 与 `x86_64`。
- CLI Release universal build：在 `/private/tmp/xomo-rc1803-full-gate/CLI/.build` 构建成功；`xomo version` 返回 `2.12.0-rc1803`，`lipo -archs` 返回 `x86_64 arm64`。CLI 测试 2/2 通过。
- 可恢复安装：安装前将原 `/Applications/Xomo.app`（rc1760/build1760）复制到 `/private/tmp/xomo-rc1803-full-gate/Backup/` 并保留原件副本；随后将 rc1803 安装至 `/Applications/Xomo.app`。当前版本/build 读回为 `2.12.0-rc1803` / `1803`。rc1760 两份备份均保留，未删除。
- GUI smoke：通过正常 `open -a /Applications/Xomo.app` 启动；实际辅助功能树显示 1440×900 画布、编辑菜单及本地化“自定义比例…”对话框。对测试空白文档的全画布选区执行 150% 缩放后，状态显示“已将选区像素缩放到 150%”；撤销和重做状态转移均已实际操作。临时填充/缩放操作随后撤销，选区清除；未打开或覆盖用户图稿。
- rc1803 定向像素变换测试 20/20；发布合同 10/30、CLI release-build 合同 7/24、概览归档合同 3/30 均通过。

## 签名与分发边界（未通过）

- GUI archive 及 `/Applications/Xomo.app` 的文件树通过 `rsync --dry-run --checksum` 比对一致；因此没有发现归档到安装过程的文件差异。
- 早期安装后验签曾返回成功，但本轮结束前重复读取时，Xomo archive、安装版及 rc1760 备份的 `codesign --verify --deep --strict` 均失败。本机对 `/System/Applications/Calculator.app` 与 `/Applications/Xcode.app` 的同类验证也返回 `CSSMERR_TP_NOT_TRUSTED`；Xomo Gatekeeper 评估返回系统代码签名子系统内部错误。签名信任服务原因尚未确定，不能把这解释为应用签名通过，也不能把它直接归因于 Xomo 包损坏。
- 没有关闭 Gatekeeper、移除 quarantine、重签系统/应用或绕过任何验证；没有执行公证或新的 GitHub、OSS、Sparkle 发布。此前 rc1797 的远端发布状态不属于本次 rc1803 交付。
- 结论：全量测试、GUI/CLI Release 构建、安装版启动与交互冒烟已完成；本机覆盖安装及原版本备份已读回。安全信任 / Gatekeeper 与公证分发验收未通过/未执行，须先调查系统范围签名信任读回，再决定是否重验。

## 后续重点

1. 诊断本机 `CSSMERR_TP_NOT_TRUSTED` 的系统范围原因，优先用系统日志与签名服务状态取证；在恢复正常读回前，不发布新的签名制品。
2. 下一轮以 rc1840 为完整构建、冒烟与可恢复安装门槛；继续优先真实用户编辑工作流和事务边界，不为版本号拆分空泛小改动。
