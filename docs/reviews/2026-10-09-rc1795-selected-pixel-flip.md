# rc1795 selected-pixel flip verification

- Implementation version: `2.12.0-rc1795`; verification-contract correction: `2.12.0-rc1796`; feathered-selection regression: `2.12.0-rc1797`.
- Scope: Edit-menu horizontal/vertical flips of selected pixel-layer content, feathered selection coverage, multi-layer atomic history, preserved geometric selections when coverage is unchanged, and project round-trip.
- `ImageEditorSelectionPixelTransformTests`: 6/6 passed, including horizontal/vertical masked raster behavior, feathered partial-alpha coverage, no-op selection preservation, lock availability, multi-layer Undo/Redo, and reopen round-trip.
- Pixel movement and layer-boundary regression suites: 47/47 passed across 8 suites.
- Selection fill/copy/cut suites: 65/65 passed across 4 suites.
- Patch/Healing and retouch workflows: 67/67 passed across 6 suites.
- Content-aware fill: 2/2 passed; Edit-menu wiring regression: 1/1 passed.
- Release contract: 10 runs / 30 assertions passed; CLI release build contract: 7 runs / 24 assertions passed; product-overview archive contract: 3 runs / 30 assertions passed.
- `build-for-testing` completed successfully; `git diff --check` passed; all 4,359 localization keys match across English, Simplified Chinese, and Japanese.
- The first per-method pixel test run reported 13 parameterized cases as zero executed. The runner intentionally rejects zero-test results; rerunning by suite executed all 47 cases and passed. This is a test-runner selector limitation, not a product test failure.
- No full Release archive, complete project suite, desktop smoke test, install, GitHub Release, OSS upload, or Sparkle appcast publication is claimed here. The full release/install gate remains `rc1800`.

## Release follow-up

- The official `xomo` release runner completed the full test target: 3,738 tests passed, then the universal arm64 + x86_64 Release archive/export succeeded.
- Developer ID signature verification, Apple notarization, app and DMG stapling, and Gatekeeper assessment succeeded.
- Published as [GitHub Release v2.12.0-rc1797](https://github.com/niuwoai/xomo/releases/tag/v2.12.0-rc1797), targeting commit `4724fd0cce24c031bd537af5cd4912c4a0a4c9f6`. The uploaded asset reports SHA-256 `9dbfab8aadeefce6e7c48685032995e5e7e85c80db56e97b0d973f890aa59a69`.
- Uploaded the same 21,097,155-byte DMG to [the versioned download](https://img.niuwoai.com/mac-apps/Xomo-2.12.0-rc1797.dmg) and [the latest download](https://img.niuwoai.com/mac-apps/latest/Xomo.dmg); both endpoints returned HTTP 200 with matching content length and ETag.
- Read back the `xomo` stable-channel [Sparkle appcast](https://some.im/api/v1/public/app-updates/appcast.xml?app_id=xomo&platform=macos&channel=stable); it identifies version `2.12.0-rc1797`, build `1797`, the versioned DMG URL, file size, and the runner-reported EdDSA signature.
- This is not the scheduled `rc1800` full desktop smoke/install gate. `/Applications/Xomo.app` was not replaced. The Homebrew tap still lists Xomo as pending and has no cask, so no cask was created or updated.
