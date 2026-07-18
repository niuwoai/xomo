# rc297 组件拖拽与光标专项报告

## 结果

- 版本：`2.12.0-rc297`
- 结论：通过
- 定向 Swift Testing：2/2 通过，0 失败，0 跳过
- 发布契约：3 个测试、7 个断言全部通过
- 环境：macOS 26.5.2，arm64

## 覆盖内容

1. 组件库和工具栏两种模式下，组件拖动期间都使用闭合抓手光标。
2. 组件透明命中层使用高优先级拖拽手势，并保留画布手势兜底，避免 macOS 拖放宿主抢占。
3. 释放后恢复上下文移动光标，实时灰色虚线预览和释放时一次性提交逻辑保持不变。

## 执行命令

```text
ruby scripts/test_release_contract.rb
xcodebuild test -project veilpic.xcodeproj -scheme veilpic -destination 'platform=macOS' -derivedDataPath /private/tmp/xomo-rc297-derived -resultBundlePath /private/tmp/xomo-rc297.xcresult -only-testing:veilpicTests/ImageEditorCanvasCursorTests/draggingAComponentUsesTheClosedHandCursorAcrossSidebarModes() -only-testing:veilpicTests/XomoLeftSidebarTests/componentSidebarWiresMoveSemanticsIntoCanvasCursorAndGestures()
```
