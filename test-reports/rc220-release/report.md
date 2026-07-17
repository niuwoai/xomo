# Xomo rc220 Release 门禁报告

- 版本：`2.12.0-rc220`
- 执行时间：2026-07-18（Asia/Shanghai）
- 全量独立进程测试：**1007/1007**
- CLI 测试：**2/2**
- Release App：**arm64 + x86_64 通用构建通过**
- Release CLI：**arm64 + x86_64 通用构建通过**
- Bundle ID：`im.some.xomo`
- 最低系统：macOS `13.0`
- App 签名：ad-hoc，`codesign --verify --deep --strict` 通过
- 安装路径：`/Applications/Xomo.app`

## 冒烟

安装后真实启动 Xomo 窗口成功。检查到：工具/组件库双 Tab 可见，组件库当前选中时画布与图层面板正常显示；画布透明棋盘格、缩放工具条、图层/通道/复合/路径标签和组件对象选中状态均可见，窗口状态栏显示 `1440 x 900 px · 100% · 就绪`。
