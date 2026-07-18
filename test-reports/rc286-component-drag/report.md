# rc286 组件拖动命中与光标专项回归

- 版本：`2.12.0-rc286`
- 结果：通过

## 通过项

- `componentSidebarWiresTransparentInteractionOverlay`
- `componentHitQueryDoesNotMutateSelection`
- `movingAnObjectPublishesAndClearsItsDashedPreviewFrame`
- `ImageEditorCanvasCursorTests` 聚焦套件
- 发布契约：3 次运行、7 项断言全部通过
- `xcodebuild` 聚焦测试编译：macOS 13.0 目标通过

## 备注

本报告只覆盖本次透明交互命中层、组件拖动预览和熟悉工具光标相关回归。更大范围的旧测试套件仍有两个与本次改动无关的既有失败：Command 深入选择用例和主题 Token 刷新用例，未将其混入本版本专项通过项。
