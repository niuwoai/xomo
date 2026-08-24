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
| `vector-mask-inverted.psd` | 外部生成的 vmsk 反相矢量蒙版，验证原生反相渲染、项目持久化与 PSD 往返 |
| `vector-mask-empty-reveal.psd` | 外部生成的空路径 vmsk，selector 8 初始填充为 1，验证“显示全部”仍保留为可编辑矢量蒙版 |
| `vector-mask-empty-hide.psd` | 外部生成的空路径 vmsk，selector 8 初始填充为 0，验证“隐藏全部”仍保留为可编辑矢量蒙版 |
| `vector-mask-combine.psd` | 两个重叠矩形子路径使用 Combine，验证重叠区域保持可见 |
| `vector-mask-subtract.psd` | 第二个重叠矩形使用 Subtract，验证从第一组件中扣除重叠区域 |
| `vector-mask-intersect.psd` | 第二个重叠矩形使用 Intersect，验证只保留共同区域 |
| `vector-mask-exclude.psd` | 第二个重叠矩形使用 Exclude，验证重叠区域被排除、两侧保留 |
| `vector-mask-continue.psd` | 内层矩形以 `-1` 延续前一组件，验证同一复合组件内的偶奇孔洞与运算身份往返 |
| `modern-solid-vector-shape.psd` | `vsms + vscg` version 16 的 `SoCo` 内容，恢复为原生实色矢量形状 |
| `modern-gradient-vector-shape.psd` | `vsms + vscg` version 16 的 `GdFl` 内容，恢复为原生线性渐变矢量形状 |
| `gradient-vector-shape.psd` | 外部生成的渐变矢量形状，包含 `[6, 3]` 虚线与 `5.5 pt` 非零虚线偏移 |
| `stroked-vector-shape.psd` | 外部生成的实色矢量形状，包含 `[6, 3]` 虚线与 `5.5 pt` 非零虚线偏移 |
| `modern-radial-vector-shape.psd` | `GdFl` 的 `Rdl ` 类型，恢复为原生径向渐变矢量形状 |
| `modern-reflected-vector-shape.psd` | `GdFl` 的 `Rflc` 类型，恢复为原生对称渐变矢量形状 |
| `modern-diamond-vector-shape.psd` | `GdFl` 的 `Dmnd` 类型，恢复为原生菱形渐变矢量形状 |
| `modern-angle-vector-shape.psd` | `GdFl` 的 `Angl` 类型，恢复为原生角度渐变矢量形状并验证现代描述符往返 |
| `path-resources.psd` | 外部生成的 Image Resources 路径资源，验证闭合路径和开放路径进入路径面板 |

重新生成：

```sh
ruby scripts/generate_psd_compatibility_fixtures.rb
```
