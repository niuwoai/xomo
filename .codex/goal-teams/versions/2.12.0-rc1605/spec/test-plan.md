# 测试计划：rc1605

## 直接测试

- 自身全锁、像素锁、祖先全锁、祖先像素锁均拒绝 TEXT/BOOLEAN/VARIANT 更新和 reset。
- 位置锁与透明像素锁不误阻断内容属性编辑。
- 拒绝前后 current/default、文本后代、History 与 Undo/Redo 保持一致；UI 状态为既有 layerLocked。
- 解锁后编辑/还原及覆盖筛选正常。
- View 源码包含共享 canEdit 禁用接线。
- Automation list 返回 editable=false；set/reset 明确失败且无文档/撤销副作用。

## 相邻回归

- `ImageEditorFigmaProvenanceTests`。
- Figma component properties Automation set/reset。
- 锁定层/组语义测试。
- rc1604 覆盖筛选与组件库系统箭头合同。
- 发布契约、隔离测试器契约、CLI/MCP 2/2。

rc1605 不执行 Release/安装；rc1640 执行完整门禁。
