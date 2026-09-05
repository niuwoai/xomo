# Test Plan

- 新增 1 个 Figma 动态测试：七属性乱序夹具验证 7/3/4/2 统计与四种筛选交集、排序。
- 新增 1 个 Automation 动态测试：list/set/reset/resetAll 后计数更新与旧字段兼容。
- 扩写既有 Inspector 源码合同：三语摘要、问题开关、组合空态、accessibility、双参数接线。
- 扩写既有锁定 Automation 回归：锁定不改变数据健康计数。
- 精确目标：Figma 29、Automation 323、Localization 46、cursor 128、CLI/MCP 2、Release contract 9。
- 构建前检查全局 `xcodebuild|swift-frontend|release_mac_apps`，全程 jobs=1，复用同一 DerivedData。
