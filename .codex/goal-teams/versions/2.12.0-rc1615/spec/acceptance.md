# rc1615 Acceptance

状态：代码、测试与动态门禁 PASS；Git 闭环待完成。

- 五种 Slice 正交几何与图层、Hotspot 同构，90° 正确交换画布宽高。
- 历史部分越界 Slice 可用；完整源外、触边、损坏几何或源/目标 preset 失效在 Undo 前原子拒绝。
- 数量、顺序、身份、名称、preset 全字段及 nil/显式空数组保持；Slice scope 与主 preset 按最终 frame 协调。
- Direct、Automation、Undo/Redo、Hotspot 交叉失败、size controls 与 cursor 均有动态证据。
- 独立评审最终 PASS；唯一冷构建与相关动态回归去重 203/203 通过，另有 CLI/MCP 2/2 和发布契约 9/9（27 条断言）。
- rc1615 不是 rc1640 周期门禁，不执行 Release、全量 UI 冒烟或 `/Applications` 覆盖。
