# PSD Compatibility Fixtures

这些夹具由 `scripts/generate_psd_compatibility_fixtures.rb` 按 Adobe Photoshop File Formats Specification 独立生成，不经过象墨的 PSD 编码器，避免往返测试只验证同一份实现。

| 文件 | 覆盖能力 |
|---|---|
| `zip-group-mask.psd` | ZIP Prediction 图层通道、ZIP 合成图、嵌套结构标记、栅格蒙版、Linear Light、Fill、透明/像素/位置锁、ICC 资源提示 |
| `zip-composite.psd` | 无图层 PSD 的 ZIP 合成图解码 |
| `unsupported-features.psd` | 文字、矢量、智能对象、图层效果、填充层和未知混合模式的兼容性报告 |

重新生成：

```sh
ruby scripts/generate_psd_compatibility_fixtures.rb
```
