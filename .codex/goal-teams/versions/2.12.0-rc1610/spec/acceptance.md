# rc1610 Acceptance

## 独立评审

- 首轮：发现 90° 变换 Undo/Redo 恢复文档后未同步四个尺寸控件（P2）。
- 二轮：无条件同步虽关闭首个问题，但会在普通图层 Undo/Redo 时清除用户未提交的尺寸输入（P2）。
- 最终修复：仅当 Undo/Redo 恢复前后画布尺寸确实变化时同步；新增画布往返和真实图层可见性事务测试。
- 最终结论：PASS，无剩余 P0-P3。

## 动态 QA

| 报告 | 结果 |
| --- | --- |
| `test-reports/rc1610-orthogonal-final/report.json` | 5/5 |
| `test-reports/rc1610-canvas-final/report.json` | 25/25 |
| `test-reports/rc1610-automation-final/report.json` | 7/7 |
| `test-reports/rc1610-html-final/report.json` | 3/3 |
| `test-reports/rc1610-project-final/report.json` | 1/1 |
| `test-reports/rc1610-cursor-library-final/report.json` | 7/7 |
| `test-reports/rc1610-cursor-mode-final/report.json` | 1/1 |

- 总计：49/49，失败 0、跳过 0、基础设施重试 0。
- 首次构建仅因测试 `CGFloat.nan/infinity` 歧义失败；显式标注后最终测试构建通过。
- CLI/MCP：2/2。
- 发布契约：9/9，27 条断言；隔离运行器契约与发布结构校验 PASS。
- rc1610 不是 40 版本门禁，未执行 Release 构建、全量回归或 `/Applications` 覆盖。
