# Architecture Design

`resetSelectedFigmaComponentProperty` 在取得 current/default 后先比较完整对象，再检查内容锁并 pushUndo。单次 document mutation 写回完整 default；若 current 为 TEXT 且 value 改变，沿用现有后代范围、旧值匹配、锁定过滤和文本尺寸重算。History/status 继续使用既有单项 key。

Automation 保持现有 action/schema，通过 ViewModel 路径自动获得精确恢复语义。
