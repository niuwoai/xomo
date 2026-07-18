# rc285 组件拖动与光标专项回归

- 版本：`2.12.0-rc285`
- 结果：通过

## 通过项

- `componentHitQueryDoesNotMutateSelection`
- `movingAnObjectPublishesAndClearsItsDashedPreviewFrame`
- `repeatedDragUpdatesAccumulateInThePreviewBeforeCommit`
- `componentSidebarWiresMoveSemanticsIntoCanvasCursorAndGestures`
- 发布契约：3 次运行、7 项断言全部通过
- `xcodebuild build-for-testing`：macOS 13.0 目标编译通过

## 备注

本报告只覆盖本次组件画布拖动、虚线预览和工具光标改动。更大范围的旧测试套件仍有两个与本次改动无关的既有失败：Command 深入选择用例和主题 Token 刷新用例，未将其混入本版本的专项通过项。
