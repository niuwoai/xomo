# 2.12.0-rc1606 Goal Teams 计划

## 目标

让 Fireworks 风格热点导出的自包含 HTML 在图片随视口缩放时同步重算 image-map 坐标，避免窄窗口中可见图片与点击区域错位。

## 成员

| 成员 | 任务 | 锁定范围 | 交付 | 验收 |
| --- | --- | --- | --- | --- |
| 需求审计 | 现有热点/项目/几何语义 | 只读 | 最小边界 | Goal Lead |
| 架构审计 | normalized、constraint 与导出层方案比较 | 只读 | 架构建议 | Goal Lead |
| 测试设计 | 导出与相邻合同矩阵 | 只读 | 测试计划 | Goal Lead |
| 开发 | 响应式 HTML 导出与单测 | Exporter、相关测试 | 最小实现 | QA + 评审 |

## 边界

- 保留现有像素 `frame`、项目格式、UI 和 Automation JSON。
- 原 `<area coords>` 继续作为禁用脚本时的像素回退。
- 导出 HTML 仅从可信整数坐标和画布尺寸派生响应式数据；用户名称、URL、标题不进入脚本，链接另经协议白名单过滤后再做 HTML 转义。
- 页面初始、图片 load、窗口 resize 及可用时 ResizeObserver 都会同步坐标。
- 不改变编辑器画布 resize/crop/reveal/rotate/flip 对热点的现有语义，不新增持久化约束模式，不改 cursor。
- rc1606 不执行 Release/安装；rc1640 执行下一次完整门禁。

## 停止条件

- 需要修改项目 schema、热点画布命中或 Automation 协议。
- 需要引入外部脚本、网络依赖或浏览器框架。
- 外部构建占用唯一构建槽时暂停动态测试。
