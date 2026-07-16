# rc168 PSD 命名路径验证

日期：2026-07-17

## 结果

- `ImageEditorPSDTests`：18 个测试中 10 个通过、8 个失败。
- `swift test --package-path xomo-cli`：2/2 通过。
- `psdExportPreservesClosedAndOpenSavedPaths`：通过。
- `externalPathResourcesBecomeEditableSavedPathsAndRoundTrip`：通过。
- Debug 测试执行过程中完成构建并启动测试产品。

## 修复内容

PSD Path Resource 的长度记录固定为 26 字节：选择器 2 字节、结点数 2 字节、保留区 22 字节。此前导出器和独立夹具都只写入 20 字节，导致第一个结点选择器错位，命名路径被安全丢弃。rc168 同时修复 Xomo 导出器、夹具生成器和二进制夹具。

剩余失败集中在既有文字解析、矢量蒙版和复杂蒙版回归，不属于本版本路径改动。
