# Xomo rc260 Release 门禁报告

- 版本：`2.12.0-rc260`
- Bundle ID：`im.some.xomo`
- 最低系统：macOS `13.0`
- App：arm64 + x86_64 universal Release，`codesign --verify --deep --strict` 通过
- CLI：arm64 + x86_64 universal，版本输出 `2.12.0-rc260`
- 全量独立进程测试：**1043/1043**
- 项目专项测试：**11/11**；MCP/CLI 专项：**59/59**
- 安装路径：`/Applications/Xomo.app`
- 冒烟：安装后启动进程存在，主窗口数量为 **1**

## 结果

✅ rc260 热点功能、双架构 Release、版本元数据、安装与启动冒烟全部通过。
