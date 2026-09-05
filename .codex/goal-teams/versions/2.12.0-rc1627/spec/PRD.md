# PRD

## 功能需求

- 激活条件：`onlyOverrides || onlyDiagnostics || !normalizedSearch.isEmpty`。
- `visibleCount` 是既有三条件 AND 过滤后的最终 key 数；`totalCount` 是完整属性字典数。
- 激活时始终显示摘要与清除入口，包括 `m/m` 和 `0/m`。
- `0/m` 同时保留现有无结果空态。
- 一键清除在同一主线程按钮事件中复位两个布尔状态和原始查询字符串。

## 兼容与非目标

- 保持 key/value 搜索、固定 locale 规范化、原始 key 排序和既有 keys API。
- 不增加协议字段、持久状态、快捷键或新页面。
- 复制、粘贴、还原仍按完整既有语义，不消费可见列表。

## 验收

- 空/纯空白查询与两个关闭 Toggle 为 inactive，完整列表且无新摘要。
- 三种单独筛选与任意组合均准确计数；有效无命中为 `0/m`。
- 清除后恢复 inactive 与完整列表，项目和所有历史状态不变。
