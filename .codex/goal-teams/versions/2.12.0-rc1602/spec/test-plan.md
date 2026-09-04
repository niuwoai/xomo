# 2.12.0-rc1602 测试计划

## 定向测试

1. 先用 `--list --filter` 确认新增测试可枚举，不启动构建。
2. 使用 `scripts/run_tests_isolated.rb --jobs 1` 运行新增回归。
3. 串行运行 `ImageEditorCanvasCursorTests`。
4. 按实际接线追加 Spacebar、MiddleMouse、ObjectMove、PointerSequence 与 Transform 测试。
5. 运行发布契约、隔离运行器契约和 `xomo-cli` 测试。

## 证据要求

- 新测试在旧行为上失败或有明确的新增能力理由。
- 最终报告零失败、零跳过、零已知失败。
- 不以 `veilpicTests` 结果替代 `veilpicUITests` 或安装版真实冒烟。
- 所有 `xcodebuild` 串行；开始前检查系统进程。

## 周期门禁

rc1602 不做完整门禁。rc1640 按冻结 SHA 串行执行完整单元目标、xcresult 审计、UI 目标、CLI/MCP、发布契约、Universal Release、签名/双架构核验、真实冒烟和可恢复覆盖安装。
