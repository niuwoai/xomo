# rc1802 四边缘与羽化缩放回归记录

日期：2026-10-12（Asia/Shanghai）

## 改动

- 对选区像素 200% 缩放增加画布左、右、上、下四边缘覆盖，验证缩放后图层 backing 越出画布且画布外仍有可见像素。
- 对四边缘羽化选区增加 partial-alpha 回归，验证缩放后越出画布的像素仍保留半透明覆盖。
- 本版仅加测试，不改变生产缩放算法。

## 验证

- 隔离 `build-for-testing` 成功；原生 `ImageEditorSelectionPixelTransformTests` 实际执行 17/17，通过 0 失败、0 跳过、0 基础设施重试（结果报告：`/private/tmp/xomo-rc1802-selection-tests/report.json`）。
- `ruby scripts/test_release_contract.rb`：10 runs、30 assertions，通过 0 失败。
- `ruby scripts/test_xomo_cli_release_build.rb`：7 runs、24 assertions，通过 0 失败。
- `ruby scripts/test_product_overview_archive.rb`：3 runs、30 assertions，通过 0 失败。
- `git diff --check`：通过。

## rc1800 本机安装门槛调查

- `build/mac-releases/xomo/release.log` 在打包时记录 staged app 的 `codesign --verify --deep --strict` 成功、app 与 DMG 的 stapler validate 成功，以及最终 DMG `spctl` accepted；这是当时日志中的结果，不等于当前制品读回。
- 2026-10-12 当前重读：`Xomo.xcarchive/Products/Applications/Xomo.app`、`dmg-src/Xomo.app` 与 DMG 内容中的 app 均被 `codesign --verify --deep --strict` 报告 `invalid signature (code or signature have been modified)`；单独校验主可执行文件和 Sparkle framework 也失败。
- 同一主机对 `/System/Library/CoreServices/Finder.app` 的 strict 验签返回 `CSSMERR_TP_NOT_TRUSTED`，`spctl` 对 Finder 与 Xomo 均返回 `internal error in Code Signing subsystem`。这显示本机信任服务也异常，但不能据此忽略 Xomo 制品的签名失败。
- 未替换 `/Applications/Xomo.app`，未关闭现有画布窗口，未尝试跳过或绕过 Gatekeeper/签名检查。安装门槛保持未关闭，需先查明历史通过与当前失败的差异。
