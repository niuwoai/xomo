# PRD

Figma 组件属性面板已经能识别完整属性覆盖，但旧单项还原只恢复 value，导致候选值或类型漂移时出现“按钮点了、覆盖还在”的 ghost override。rc1617 将 Reset 的动作语义与覆盖判定及 rc1616 Reset All 对齐。

验收：目标完整对象等于导入默认、覆盖计数正确下降、目标外属性保持、一次 Undo/Redo、TEXT 后代恢复、锁定与 no-op 无副作用、Automation 结果不再假报成功。
