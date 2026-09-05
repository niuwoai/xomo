# Decisions

- Figma `TEXT` value 是设计内容，首尾空格、Tab、换行、纯空白与空字符串均逐字符保留。
- BOOLEAN、VARIANT、INSTANCE_SWAP 等非 TEXT 继续使用 `whitespacesAndNewlines` trim；结果为空或未变化时 no-op。
- 文本后代按修改前 value 精确匹配，正文原样写入；锁定后代跳过。
- 图层名称继续使用 `textLayerNameFragment` 的去空白摘要与本地化兜底，不反向改变正文。
- 选中组件自身或祖先 full/pixel lock 拒绝；position/transparency lock 允许。
- 实际属性变化维持单次 Undo、mutation、History 与 status；UI 和 Automation 共享 ViewModel 语义。
