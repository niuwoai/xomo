# 2.12.0-rc1617 Decisions

- 覆盖以完整 `XomoFigmaComponentProperty` 比较，单项 Reset 必须完整写回 imported default。
- metadata-only 覆盖也应创建一次可撤销的真实恢复；已等于默认则严格 no-op。
- TEXT 后代继续按旧 value 匹配并跳过有效像素锁定层，不在本版引入 property-to-layer 绑定 schema。
- Generic Xomo component instance 不冒充 Figma instance；真实 swap/detach 后置。
