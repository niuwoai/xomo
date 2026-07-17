# rc246 Figma 图片填充属性回归

- 日期：2026-07-18
- 结果：通过
- 测试：4/4
- 范围：缩放模式、缩放因子、旋转的属性更新；实时内容图像；三次 Undo；项目 Codable 往返。
- Xcode 结果：`/tmp/xomo-rc246-figma-fill-controls/Logs/Test/Test-veilpic-2026.07.18_06-53-37-+0800.xcresult`

属性面板编辑只对仍保留源图的图片填充启用；旧项目没有源图时控件保持不可编辑，不会伪造可见结果。
