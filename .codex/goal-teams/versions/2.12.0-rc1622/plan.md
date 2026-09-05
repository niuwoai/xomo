# Plan

长期 Goal 已确认持续执行。主线起点为 rc1621；本版不是 rc1640 周期门禁。

1. 冻结 TEXT 与非 TEXT 的输入、传播、命名、锁和 no-op 语义。
2. 最小调整 ViewModel 归一化，补 ViewModel 与 Automation 动态回归。
3. 独立审查最终 diff，关闭全部 P0/P1/P2。
4. 串行运行 Figma、Automation、cursor、CLI/MCP 和发布契约。
5. 提交分支，快进合入 `main`，打 `v2.12.0-rc1622` 并推送。
