# rc1806 选区像素重采样

## 用户工作流

自定义缩放现在允许选择最近邻或双线性重采样。最近邻用于像素画、像素图标等需要保持硬边的素材；双线性依旧是默认选项，适合照片。自定义操作的 History 和状态同时记录百分比、固定参考点及用户显式选择的重采样方式。快速 50%/200% 命令和旧调用仍使用双线性。

## 验证结果

- `ImageEditorSelectionPixelTransformTests`: 22/25 个隔离执行组通过。新增最近邻硬边像素断言、最近邻 Undo/Redo 与显式双线性 History/状态测试均实际执行并通过。
- 3 个参数化旧用例（`flipMirrorsOnlyMaskedRectangleAndPreservesUnselectedPixels`、`quarterTurnRotatesOnlyMaskedPixels`、`invalidCustomScaleLeavesDocumentUntouched`）由隔离运行器报告“Xcode 返回成功，但 xcresult 确认执行了 0 个测试”。重试时同样结果；对应 xcresult 的 `totalTestCount=0`、`failedTests=0`、`result=unknown`。这是执行/过滤问题，不能记作断言通过；这些用例仍未验证。
- `scripts/test_release_contract.rb`: 10 runs, 30 assertions, passed。
- `scripts/test_xomo_cli_release_build.rb`: 7 runs, 24 assertions, passed。
- `scripts/test_product_overview_archive.rb`: 3 runs, 30 assertions, passed。
- 三种本地化 `.strings` 文件通过 `plutil -lint`；`git diff --check` 通过。

本版本未执行 40 版本 Release/全量测试/桌面安装门槛。下一完整门槛为 rc1840；rc1800 本机签名信任异常仍独立跟踪，不绕过系统校验。
