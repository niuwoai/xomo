# rc413 发布契约测试

- 日期：2026-07-20
- 命令：`ruby scripts/test_release_contract.rb`
- 结果：3 runs，7 assertions，全部通过

## 覆盖范围

- App、Xcode 工程和 CLI 版本统一为 `2.12.0-rc413`。
- 版本漂移会被契约测试拒绝。
- 发布配置与最低系统版本约束保持一致。
