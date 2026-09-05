# Goal Packet

- 版本：`2.12.0-rc1620`
- 目标：为 Figma 组件属性增加可跨兼容实例使用的“粘贴覆盖值”，补齐 rc1619 的复制工作流。
- 成功标准：完整属性对象可往返；源/目标 imported baseline 严格匹配；任一非法项整单失败；单次 Undo/History；TEXT 后代一致更新；Automation 可调用；定向动态测试通过。
- 禁区：不改项目 schema、不替换组件身份、不引入组件 detach、不改 cursor、不执行 Release/安装。
- 停止条件：必须破坏 rc1619 纯文本剪贴板兼容，或存在无法串行的外部构建。
