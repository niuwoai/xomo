# rc1836：Release 签名与 Gatekeeper 失败关闭

- 基线：`main` / `c4eaa408e39ea466f5cb4851fcdecb941eabaaed`（rc1835）
- 版本：`2.12.0-rc1836`，build `1836`
- 范围：在 Release 导出 `.app` 后、创建 DMG 前执行严格代码签名验证；签名无效时 fail closed。

## 依据与预期

rc1803 的归档 `.app` 与 `/Applications/Xomo.app` 在当前读回中均未通过 `codesign --verify --deep --strict`；两者主可执行文件与 `CodeResources` 的 SHA-256 相同，说明安装复制未改变这两个签名输入。当前 `release.sh` 原流程只验证 DMG 签名，未独立验证其中的 `.app`。此外，stapling 后的 Gatekeeper 评估附带 `|| true`，即使命令失败也会继续输出“完成”。签好 DMG 不能修复或证明其内应用签名有效，忽略 Gatekeeper 失败也会造成错误的成功信号。

现在 Release 流程在确认导出 `.app` 存在后立即执行严格验签，失败则因 `set -e` 停止，避免创建 DMG、提交公证或继续分发无效应用；stapling 后 Gatekeeper 评估失败也会使流程非零退出。改动不改变证书、签名身份或 Gatekeeper 策略。

## 验证

- 发布契约：12 runs / 36 assertions 全通过；正向验证导出应用验签次序及 stapling 后 Gatekeeper 评估，负向夹具覆盖移除验签和添加 `|| true`。
- CLI 发布构建契约：7 runs / 24 assertions 通过；产品概览归档契约：3 runs / 30 assertions 通过；隔离测试器契约 PASS。
- Ruby 语法、`bash -n scripts/release.sh` 与 `git diff --check` 均通过。
- 未运行 Xcode Release archive、全量测试、真实 DMG/公证、桌面冒烟或 `/Applications` 安装。周期门槛仍为 rc1840。
