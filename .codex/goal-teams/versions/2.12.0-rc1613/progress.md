# 2.12.0-rc1613 Progress

- 2026-09-05：上一轮 rc1612 归类为 progress；main、功能分支与 tag 已远端一致，工作区干净。
- 2026-09-05：需求、架构与测试三名独立成员完成只读分析，确认四类缩画布入口共享私有 `crop` 漏斗；Canvas Trim 与 Layer Trim 明确分离。
- 2026-09-05：冻结复用 rc1612 Slice helper、Undo 前全量预计算、源/目标 preset 双校验、合法删除、scope 协调与元数据保真语义。
- 2026-09-05：开发、动态测试、独立复核和 Git 闭环进行中。
- 2026-09-05：首轮评审发现有效非首项选择假阳性、测试命名过度、初始倍率证据和 Canvas Trim 部分裁切缺口；修正后独立二次复核 PASS，无 P0/P1/P2。
- 2026-09-05：修正版增量构建成功；新增 Direct 测试 9/9、Automation 2/2，合计 11/11 通过，失败/跳过/基础设施重试均为 0。相邻回归进行中。
- 2026-09-05：相邻回归 12/12 组、59/59 通过，所有 filter 均匹配；Canvas Commands 25、Hotspot Crop/Reveal 4、Slice Canvas Size 11、Canvas Automation 1、Image Size 8、Image Automation 1、Figma preset 4、preset boundary 1、selected export 1、project round-trip 1、cursor arrow 1、cursor pan 1。
- 2026-09-05：动态测试总计 70/70，失败 0、跳过 0；CLI/MCP 2/2，发布契约 9/9（27 条断言）、隔离测试器契约与发布结构校验通过。首次 CLI 尝试仅因沙箱禁止写 Swift 缓存失败，在正常权限环境原命令通过。
- 2026-09-05：rc1613 非 40 版本门禁，不执行 Release、全量 UI 冒烟或 `/Applications` 覆盖。提交、tag、main 合入和远端精确指针在 Git 闭环后补记。
