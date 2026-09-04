# rc1612 Acceptance

## 独立评审

- 首轮发现目标 preset 测试使用 height 1000，源倍率已超限，未覆盖目标二次校验；改为 240 后源倍率 3 合法、目标倍率 6 非法。
- 首轮发现 Undo/Redo 与 Automation 的 Slice 宽度未变化，主 preset 倍率始终为 2；改为目标裁切宽度 10 后，真实验证 `2→4→2→4`。
- 补强历史越界源可见交集、合法删除 width 40 与损坏 width 41、13 类无效目标、无 preset scope 及完整原子快照。
- 最终结论：PASS，无剩余阻断项。

## 动态 QA

| 报告 | 结果 |
| --- | --- |
| `test-reports/rc1612-slice-canvas-final/report.json` | 11/11 |
| `test-reports/rc1612-automation-final/report.json` | 1/1 |
| `test-reports/rc1612-canvas-regression-final/report.json` | 25/25 |
| `test-reports/rc1612-slice-image-regression/report.json` | 8/8 |
| `test-reports/rc1612-slice-image-automation-regression/report.json` | 1/1 |
| `test-reports/rc1612-hotspot-canvas-automation-regression/report.json` | 1/1 |
| `test-reports/rc1612-slice-preset-regression/report.json` | 7/7 |
| `test-reports/rc1612-slice-preset-boundary-regression/report.json` | 1/1 |
| `test-reports/rc1612-selected-slice-export-regression/report.json` | 1/1 |
| `test-reports/rc1612-slice-project-regression/report.json` | 1/1 |
| `test-reports/rc1612-cursor-arrow-regression/report.json` | 1/1 |
| `test-reports/rc1612-cursor-pan-regression/report.json` | 1/1 |

- 总计：59/59，失败 0、跳过 0、基础设施重试 0。
- CLI/MCP：2/2。
- 发布契约：9/9，27 条断言；隔离运行器契约与发布结构校验 PASS。
- rc1612 不是 40 版本门禁，未执行 Release 构建、全量回归或 `/Applications` 覆盖。
