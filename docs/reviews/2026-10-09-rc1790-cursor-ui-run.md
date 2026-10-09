# rc1790 组件库光标 UI 回归尝试

## 基线与范围

- 源码基线：`main` / `2a2e838b` / `v2.12.0-rc1790`；工作区在测试前干净。
- 目标：验证真实工具光标 → 组件库系统箭头（悬停与选择）→ 返回工具光标的 macOS UI 流程。
- 不覆盖 `/Applications`，不发布二进制，也未修改产品代码。

## 当前策略回归

- 命令：`lockf -t 1 /private/tmp/veilpic-build.lock env XOMO_DERIVED_DATA_PATH=/private/tmp/xomo-rc1790-cursor-ui-derived ruby scripts/run_tests_isolated.rb --group-by-suite --filter ImageEditorCanvasCursorTests --skip-build --out /private/tmp/xomo-rc1790-cursor-policy`
- 结果：执行组 1/1 通过，`ImageEditorCanvasCursorTests` 130/130 实际执行，无失败；报告位于 `/private/tmp/xomo-rc1790-cursor-policy/report.{json,md}`。
- 这验证光标策略及生产接线单测，不验证屏幕上的 AppKit 指针形状。

## 原生 UI runner 尝试

- 首次在干净 DerivedData 上执行 `xcodebuild test`，指定 `veilpicUITests/veilpicUITests/testComponentLibraryHoverAndSelectionRestoreSystemArrow`；测试 runner 在建立 XCTest 连接前被 `SIGKILL`，`xcodebuild` 退出 65。
- 使用已生成的 DerivedData 以 `arch=arm64` 重跑同一 UI 方法，并移除 `QPIC_SKIP_ADHOC_SIGN=YES`，结果仍为 runner 建立连接前 `SIGKILL`，退出 65。
- 第二次 `.xcresult` 摘要：`Failed`，`passedTests=0`、`failedTests=1`、`skippedTests=0`；失败项是 `veilpicUITests-Runner ... encountered an error`，不是目标 UI 测试体。活动树也只有 runner 启动失败消息。
- 根因尚未确定；“跳过 ad-hoc 签名”已不是充分解释。当前宿主无法启动 UI runner，不能据此判定应用光标实现失败或通过。

## rc1797 follow-up retry

- Source baseline: `main` / `c0a6ea49` (published `2.12.0-rc1797` code plus release documentation); the worktree was clean.
- Command: `xcodebuild test -project veilpic.xcodeproj -scheme veilpic -destination 'platform=macOS' -derivedDataPath /Users/rocky/Sites/new83d/build/mac-releases/xomo/DerivedData-universal -only-testing:veilpicUITests/veilpicUITests/testComponentLibraryHoverAndSelectionRestoreSystemArrow -parallel-testing-enabled NO -resultBundlePath /private/tmp/xomo-rc1798-cursor-ui.xcresult`.
- The first Debug build of this DerivedData compiled the app and the scheme's complete `veilpicTests` dependency before launching the UI runner; this took about 60 minutes. This exposes a slow path for isolated UI acceptance on a cold Debug cache.
- `xcresulttool` summary: `Failed`, `passedTests=0`, `failedTests=1`, `skippedTests=0`; the only failure was `veilpicUITests-Runner (6686)`: “The test runner hung before establishing connection.” The target test body was not executed, so no product assertion or cursor mismatch was reported. Result: `/private/tmp/xomo-rc1798-cursor-ui.xcresult`.
- The build lock was released and no Xcode/UI-test runner process remained afterward. Existing strategy tests remain 130/130, but they do not substitute for this runtime check.

## 下一步

- Next, obtain a usable macOS XCUITest worker/runner startup channel or perform an equivalent observed desktop smoke test, then verify the actual pointer transitions; do not weaken or count the unexecuted UI test as passing.
- rc1800 完整门槛仍要求 Release 全量构建、真实桌面编辑/光标冒烟与可恢复安装；本记录不作为门槛通过证据。
