<!-- English or 中文 both fine. -->

## What this changes

<!-- One or two sentences. Link the issue if there is one: Fixes #123 -->

## Why

<!-- The problem it solves. Behaviour changes without a stated reason are hard to review. -->

## How it was verified

<!-- Paste the real command and its real result. "Ran the tests" is not evidence. -->

```
ruby scripts/run_tests_isolated.rb --filter <Filter>
```

## Checklist

- [ ] Behaviour changes come with a test, and the test fails without the change.
- [ ] Batch operations commit as a **single** History/Undo step and fail atomically on invalid input.
- [ ] Pixel work goes through explicit `sRGB` / `deviceRGB` colour spaces.
- [ ] Any new UI string exists in **all three** locales (`en`, `ja`, `zh-Hans`).
- [ ] Public docs and numbers updated if this changes them (and `ruby scripts/verify_readme.rb` passes).
- [ ] No credentials, tokens, personal data or `.env` contents are included.
- [ ] If this touches PSD I/O: the compatibility report still reports every degradation instead of silently flattening.

## Screenshots / recordings

<!-- For anything visual. Before and after if the change is a refinement. -->
