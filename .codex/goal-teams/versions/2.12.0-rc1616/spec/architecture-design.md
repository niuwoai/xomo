# Architecture Design

ViewModel 先按稳定 key 顺序筛出可恢复覆盖，再在 pushUndo 后的单次 document mutation 中写回完整默认对象。TEXT 属性复用现有后代选择、锁定过滤与尺寸更新语义。完成后仅追加一条批量历史和状态。

Inspector 仅在覆盖数大于零时显示入口。Automation 在现有 component_properties action 中增加 resetAll，并维持现有 result schema。
