# rc1611 Acceptance

## 独立评审

- 首轮发现 source integral 边界测试值 16.25 恰好解析为允许下界 0.25，无法触发预期失败；改为 16.2 后旧错误实现与正确实现可区分。
- 评审确认 `.webp` 确属不支持的 Slice preset 格式，全部可能失败的变换与 preset 校验均发生在 `pushUndo()` 前，后续 scope 协调不抛错，原子性成立。
- 补强“部分越界 + width preset”夹具，分别锁死源整数可见交集和目标最终可见交集；非法源画布扩为宽高各自 0、负数、NaN、Infinity 八项矩阵。
- 最终结论：PASS，无剩余阻断项。

## 动态 QA

| 报告 | 结果 |
| --- | --- |
| `test-reports/rc1611-slice-resize-final/report.json` | 8/8 |
| `test-reports/rc1611-automation-final/report.json` | 1/1 |
| `test-reports/rc1611-canvas-regression-final/report.json` | 25/25 |
| `test-reports/rc1611-hotspot-automation-regression/report.json` | 1/1 |
| `test-reports/rc1611-guide-regression/report.json` | 1/1 |
| `test-reports/rc1611-textbox-regression/report.json` | 1/1 |
| `test-reports/rc1611-slice-preset-regression/report.json` | 7/7 |
| `test-reports/rc1611-slice-preset-boundary-regression/report.json` | 1/1 |
| `test-reports/rc1611-selected-slice-export-regression/report.json` | 1/1 |
| `test-reports/rc1611-slice-project-regression/report.json` | 1/1 |
| `test-reports/rc1611-cursor-arrow-regression/report.json` | 1/1 |
| `test-reports/rc1611-cursor-lifecycle-regression/report.json` | 1/1 |

- 总计：49/49，失败 0、跳过 0、基础设施重试 0。
- CLI/MCP：2/2。
- 发布契约：9/9，27 条断言；隔离运行器契约与发布结构校验 PASS。
- rc1611 不是 40 版本门禁，未执行 Release 构建、全量回归或 `/Applications` 覆盖。
