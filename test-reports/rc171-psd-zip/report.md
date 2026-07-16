# v2.12.0-rc171 PSD ZIP 兼容性报告

- 生成时间：2026-07-17 05:44（Asia/Shanghai）
- 变更范围：PSD ZIP zlib 头处理与扁平合成导入层模型

## 验证结果

| 套件 | 通过/总数 | 结果 |
|---|---:|---|
| `ImageEditorPSDTests` | 17/18 | ✅ ZIP、文字、矢量蒙版、路径资源与基础图层通过 |
| `XomoMCPServerTests` | 2/2 | ✅ |

ZIP 相关通过项：

- ZIP 组蒙版：保留组层级、蒙版、混合模式、Fill 不透明度和锁定状态
- ZIP 合成：无图层 PSD 解码为单个可编辑背景层

剩余 1 项是复杂蒙版 alpha 往返问题，留给下一版专门处理。
