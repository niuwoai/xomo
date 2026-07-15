# rc129 项目主题/Token 往返回归报告

- 日期：2026-07-16
- 版本：v2.12.0-rc129
- XomoLeftSidebarTests：42/42
- ImageEditorProjectDocumentTests：8/8
- ImageEditorSavedPathTests：28/28

## 覆盖内容

- 项目文件保存当前 Xomo 组件主题和本地 `.xomotokens.json` 映射。
- 重新打开项目恢复同一套主题与 Token 快照；旧项目缺少字段时回退到原生主题和空本地映射。
- 既有可编辑图层、智能对象、保存路径和旧格式兼容回归保持通过。
