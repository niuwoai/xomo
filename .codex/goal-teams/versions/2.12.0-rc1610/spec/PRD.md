# rc1610 PRD

## 目标

让五个既有 Canvas Transform 命令在保持图层行为不变的同时，可靠地同步变换热点，并让菜单、直接调用与 `xomo.canvas.transform` Automation 共享同一业务入口。

## 验收标准

1. 非对称画布上的两个热点经五种命令后得到精确预期坐标，90° 正确交换画布尺寸。
2. 热点数量、顺序、UUID、名称和 URL 不变；有效与空选择保持，陈旧选择按既有规则修复。
3. 每次成功操作只产生一个 Undo 事务和一条既有历史记录；Undo/Redo 可完整往返热点文档状态。
4. 任一热点、画布或图层无效时，除 `imageEditor.status.operationFailed` 外所有状态保持原样。
5. 成功后尺寸控件反映新画布尺寸，视口偏移与面板可见性保持。
6. 不更改项目 schema、Automation payload、导出格式或 UI。

## 发布边界

rc1610 是热点专属增量，不宣称 Rotate/Flip 已同步所有 selection、channel、guide、slice 或 path 状态。下一次完整构建、冒烟和 `/Applications` 覆盖门禁仍为 rc1640。
