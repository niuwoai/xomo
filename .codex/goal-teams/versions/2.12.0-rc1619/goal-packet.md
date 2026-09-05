# Goal Packet

- 版本：`2.12.0-rc1619`
- 目标：为 Figma 组件属性增加独立的“复制覆盖值”交付入口。
- 成功标准：复制精确覆盖子集；Custom 无基线排除；锁定仍可读；筛选状态无关；Copy All 兼容；Automation 可调用；定向动态测试通过。
- 禁区：不改项目 schema、不增加粘贴协议、不改 cursor、不执行 Release/安装。
- 停止条件：必须破坏既有 Copy All 契约，或存在无法串行的外部构建。
