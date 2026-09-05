# Test Plan

- ViewModel：TEXT rc1622 保真；BOOLEAN 小写、空白与大小写；VARIANT 唯一 name/存 name、重复 name 整项拒绝。
- ViewModel：INSTANCE_SWAP 存 key、重名 name 拒绝但明确 key 可选；唯一 key/name 语义 no-op，legacy 重名 name 不误判。
- ViewModel：以 A{key:a,name:b}、B{key:b,name:c} 击穿 VARIANT/INSTANCE_SWAP，显式选择 a 必须 invalid，属性、defaults、Undo/Redo、History 均不变。
- ViewModel：INSTANCE_SWAP Undo/Redo；无候选自由值兼容；未知 type、损坏候选与孤儿值失败零副作用。
- Automation：swap 重名 name 返回 invalidArgument，明确 key 的 snapshot 与 Undo/Redo 均保持 key；其余非法输入零副作用。
- Inspector 合同：getter 只反解唯一 name，重复/无匹配返回 raw value，Picker tag 使用 key，三语 invalid 状态存在。
- 回归：串行运行 Figma provenance、Automation、cursor、CLI/MCP 与发布契约。
