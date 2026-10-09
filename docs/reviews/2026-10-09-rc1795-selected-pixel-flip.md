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
