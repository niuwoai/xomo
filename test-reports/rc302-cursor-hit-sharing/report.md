# Xomo 2.12.0-rc302 测试报告

## 范围

本轮把画布命中判断统一为一次语义查询：直接鼠标路径和 `CursorRect` 覆盖层都使用同一个结果，因此空白、可移动对象、锁定/受阻对象不会出现鼠标样式互相覆盖的问题。

## 定向测试

- 命令：`xcodebuild test -project veilpic.xcodeproj -scheme veilpic -destination 'platform=macOS' ...`
- 环境：arm64 MacBook Pro、macOS 26.5.2、Xcode 26.4.1
- 结果：3 通过，0 失败，0 跳过
- 测试：
  - `canvasContentHitSharesTheSameSemanticForCursorPaths`
  - `moveCursorUsesTheFrontmostLockedLayerOverAnUnlockedLayer`
  - `moveCursorDoesNotClaimOccludedOrPositionLockedContent`

## 发布契约

`ruby scripts/test_release_contract.rb`：3 个测试、7 个断言，全部通过。

结果包：`/private/tmp/xomo-rc302-escalated.xcresult`
