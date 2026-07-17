# Xomo rc240 Release 门禁报告

- 版本：`2.12.0-rc240`
- Bundle ID：`im.some.xomo`
- 最低系统：macOS `13.0`
- App：arm64 + x86_64 通用二进制
- CLI：arm64 + x86_64 通用二进制，版本输出 `2.12.0-rc240`
- 全量独立进程测试：**1027/1027**
- CLI 测试：**2/2**
- 签名：ad-hoc，`codesign --verify --deep --strict` 通过
- 安装路径：`/Applications/Xomo.app`
- 冒烟：启动进程为 `Xomo`，主窗口数量为 `1`

## 结果

✅ 双架构 Release 构建、版本元数据、签名、安装与启动冒烟全部通过。
