# Test Plan

## 新增动态测试

新增恰好 1 个 Figma provenance 测试，目标 31/31。复用七属性夹具并验证：

| 条件 | Active | 可见/总数 |
| --- | --- | --- |
| 空查询、全关闭 | false | 7/7 |
| 纯空白查询、全关闭 | false | 7/7 |
| 仅覆盖 | true | 3/7 |
| 仅诊断 | true | 4/7 |
| 搜索 focus | true | 4/7 |
| 两 Toggle + focus | true | 2/7 |
| 搜索无命中 | true | 0/7 |

同时比较旧 keys API，并证明属性、defaults、status、History、Undo/Redo、覆盖/诊断/阻塞计数不变。

## 静态 Inspector 合同

- 摘要、空态、列表复用单一 filter result。
- 局部截取清除按钮闭包，确认两个 `false` 和空字符串，且没有 ViewModel/Document 写操作。
- 两个新 i18n key、辅助功能标识及 `.focusable(false)` 完整。

## 回归目标

- Figma provenance 31/31
- Automation 323/323
- Localization 46/46
- Cursor 128/128
- CLI/MCP 2/2
- Release contract 9/9（27 条断言）
