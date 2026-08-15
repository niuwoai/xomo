# PSD Compatibility Fixtures

这些夹具由 `scripts/generate_psd_compatibility_fixtures.rb` 按 Adobe Photoshop File Formats Specification 独立生成，不经过象墨的 PSD 编码器，避免往返测试只验证同一份实现。

| 文件 | 覆盖能力 |
|---|---|
| `zip-group-mask.psd` | ZIP Prediction 图层通道、ZIP 合成图、嵌套结构标记、栅格蒙版、Linear Light、Fill、透明/像素/位置锁、ICC 资源提示 |
| `zip-composite.psd` | 无图层 PSD 的 ZIP 合成图解码 |
| `unsupported-features.psd` | 文字、矢量、智能对象、图层效果、填充层和未知混合模式的兼容性报告 |
| `editable-text.psd` | 外部生成的 TySh 文字层，读取纯文本、字体、字号、颜色、基础段落对齐和字符样式 |
| `vector-mask.psd` | 外部生成的 vmsk 简单闭合三点路径，导入为 Xomo 原生矢量蒙版 |
| `vector-mask-multi.psd` | 外部生成的 vmsk 两个闭合子路径，验证 pathSubpaths 与偶奇填充孔洞 |
| `modern-solid-vector-shape.psd` | `vsms + vscg` version 16 的 `SoCo` 内容，恢复为原生实色矢量形状 |
| `modern-gradient-vector-shape.psd` | `vsms + vscg` version 16 的 `GdFl` 内容，恢复为原生线性渐变矢量形状 |
| `modern-radial-vector-shape.psd` | `GdFl` 的 `Rdl ` 类型，恢复为原生径向渐变矢量形状 |
| `modern-reflected-vector-shape.psd` | `GdFl` 的 `Rflc` 类型，恢复为原生对称渐变矢量形状 |
| `modern-diamond-vector-shape.psd` | `GdFl` 的 `Dmnd` 类型，恢复为原生菱形渐变矢量形状 |
| `modern-angle-vector-shape.psd` | Xomo 尚无对应模型的 `Angl` 类型，验证兼容性报告与安全栅格降级 |
| `path-resources.psd` | 外部生成的 Image Resources 路径资源，验证闭合路径和开放路径进入路径面板 |

重新生成：

```sh
ruby scripts/generate_psd_compatibility_fixtures.rb
```
