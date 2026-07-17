# rc247 Figma 图片填充裁切偏移回归

- 日期：2026-07-18
- 结果：通过
- 测试：4/4
- 范围：裁切偏移 X/Y 编辑、保留原有仿射矩阵、单位矩阵归一化、Undo/Redo、实时内容图像与项目 Codable 往返。
- Xcode 结果：`/tmp/xomo-rc247-figma-fill/Logs/Test/Test-veilpic-2026.07.18_07-03-39-+0800.xcresult`

偏移控件只对保留源图的图片填充启用；零偏移会归一化为无额外变换，避免项目数据膨胀。
