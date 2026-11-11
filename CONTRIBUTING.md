# Contributing to Xomo

Thanks for wanting to help. Xomo is MIT-licensed, maintained by a very small team, and
ships extremely often — which has one practical consequence: **a small, well-scoped PR
gets reviewed and merged much faster than a large one.** If your idea is big, open an
issue first and we will agree on the shape before you write code.

English or 中文 both fine, in issues, PRs and commit messages.

---

## The contributions that help most

In rough order of impact per hour of your time:

| | What | Why it is valuable |
|---|---|---|
| 1 | **Translate the reference docs into English** | The README is English, but the deep docs — the six-chapter illustrated tutorial, `XOMO_MCP.md`, `docs/PSD_SUPPORT.md` — are 中文 only. This is the single biggest barrier for the English-speaking audience, and it needs no Swift at all. |
| 2 | **Add an automation tool** | Every tool you add is a capability an AI agent gains. The registry is deliberately one file, so this is a genuinely small, self-contained change. See the worked example below. |
| 3 | **Close a PSD fidelity gap** | `docs/PSD_SUPPORT.md` lists exactly what round-trips and what degrades to pixels. Pick a "degrades to pixels" row and make it round-trip as editable data. |
| 4 | **Take an item off a roadmap** | `PHOTOSHOP_CLASSIC_ROADMAP.md` and `XOMO_UI_DESIGN_ROADMAP.md` list the known gaps in priority order. Anything with a `[ ]` is fair game. |
| 5 | **A bug report with a reproduction** | A report we can reproduce is worth more than a patch we have to guess the intent of. |

---

## Getting set up

**Requirements:** macOS 13 Ventura or newer, Xcode 16 or newer. Nothing else — no
package manager, no runtime, no cloud account.

```bash
git clone https://github.com/niuwoai/xomo.git
cd xomo

# Build the app (Debug, no signing)
xcodebuild -project veilpic.xcodeproj -scheme veilpic -configuration Debug build \
  CODE_SIGNING_ALLOWED=NO

# Build and install the standalone xomo CLI
scripts/build_xomo_cli_release.sh     # -> dist/xomo-macos-universal
dist/xomo-macos-universal install     # -> ~/.local/bin/xomo
```

The `veilpic` scheme is shared, so the command line build works on a fresh clone without
opening Xcode first. To develop in Xcode, just `open veilpic.xcodeproj` — the scheme is
already there.

`CODE_SIGNING_ALLOWED=NO` is what CI uses. If you have a Developer ID team and want a
runnable, signed build, drop that flag and set your own team; the project's own team ID
will not work for you.

---

## Test gates

CI runs these on every pull request. Please run them locally before opening one — it is
much faster than watching a runner.

**The app test suite.** It is unusually large and includes pixel-accurate rendering
assertions. Pixel and colour-space tests need process isolation (a documented
AppKit/Swift Testing interaction), so a plain parallel `xcodebuild test` will show
*false* failures. Use the repo's own runner:

```bash
ruby scripts/run_tests_isolated.rb --jobs 3            # JSON + Markdown report in test-reports/
ruby scripts/run_tests_isolated.rb --filter Filter     # narrower run while iterating
```

**The README guard.** If you touch `README.md`, its numbers, or anything the README
makes claims about:

```bash
ruby scripts/verify_readme.rb
```

It re-checks every relative link and in-page anchor, and re-derives the headline numbers
(automation tool count, component families, theme packs, source/test scale, macOS
deployment target, `swift-tools-version`, changelog size, recent commit count) from the
repository. It is a drift detector: if the number changed, either update the README or
change the claim deliberately — do not let the two silently diverge.

**The scripted contracts.** These check the release pipeline and layout invariants and
finish in seconds:

```bash
for t in scripts/test_release_contract.rb scripts/test_product_overview_archive.rb \
         scripts/test_layer_panel_tab_style.rb scripts/test_run_tests_isolated_contract.rb \
         scripts/test_xomo_cli_release_build.rb scripts/test_benchmark_*.rb; do
  ruby "$t"
done
```

**The CLI.** `swift build && swift test --package-path xomo-cli`.

Note that `scripts/test_blend_if_completion_ownership.rb` and
`scripts/test_layer_advanced_controls_layout.rb` expect arguments and are not part of the
standalone contract sweep.

---

## House rules

These exist because breaking them causes bugs that are expensive to find later:

- **Behaviour changes need a test.** The test should fail without your change.
- **Batch operations commit as a single History/Undo step**, and fail *atomically* on
  invalid input instead of half-applying.
- **Pixel work must go through explicit `sRGB` or `deviceRGB` colour spaces.** Do not let
  a colour space be inferred.
- **Every UI string must exist in all three locales.** The app ships English, 简体中文 and
 日本語; a missing key is a build/test failure, not a cosmetic issue.
- **If you touch PSD I/O, never silently flatten.** Anything that cannot survive a
  round-trip must appear in the compatibility report. This is the contract that makes the
  format support trustworthy.
- **No secrets in the repository.** No tokens, credentials, personal data, or `.env`
  contents — in code, tests, fixtures, screenshots or commit messages.

### Localisation

Strings live in four `.strings` files per locale:

```
veilpic/en.lproj/       veilpic/ja.lproj/       veilpic/zh-Hans.lproj/
  Localizable.strings     Localizable.strings     Localizable.strings
  InfoPlist.strings       InfoPlist.strings       InfoPlist.strings
  FigmaImport.strings     FigmaImport.strings     FigmaImport.strings
  WindowCommands.strings  WindowCommands.strings  WindowCommands.strings
```

Add to all three locales in the same PR, even if your translation is rough — a wrong word
is easy to fix, an absent key is a hole.

---

## Worked example: adding an automation tool

All automation tools live in one file — `veilpic/XomoAutomationRegistry.swift` — so you do
not have to learn the whole app to extend it.

1. **Declare the tool's JSON schema.** Add one `tool("xomo.something.action")` entry to the
   registry: name, description, and the argument schema.
2. **Handle it.** Add the matching `case "xomo.something.action"` to the executor switch in
   the same file. A declaration without a handler (or vice versa) fails
   `scripts/verify_readme.rb` — the two sides are asserted to be identical sets.
3. **Reject bad input atomically.** Unknown enum values must be rejected before anything is
   written to History, not part-way through.
4. **Make it one Undo step.** Whatever it does to the canvas must be undoable as a single
   action, exactly as if the user had done it in the UI.
5. **Test it.** Add a test that drives the tool and asserts the document state afterwards.
6. **Keep the count honest.** If the tool total changes, the README states it in four
   places (badge, hero line, comparison table, "Extend it"). `ruby scripts/verify_readme.rb`
   tells you if you missed one.

Tools must run through the *same* code path as the UI. A tool that shortcuts the UI into a
separate implementation will be sent back.

## Worked example: adding a UI component family

1. Add the family to `XomoComponentKind` in `veilpic/XomoComponentInsertion.swift`.
2. If it belongs to a new theme pack, add that pack to `XomoComponentTheme` in
   `veilpic/XomoComponentTheme.swift`.
3. The generator must emit **native editable layers** — shapes, text, paths and layer
   effects the user can still edit afterwards. Flattened bitmaps are not acceptable here.
4. Record provenance and licensing in `XOMO_COMPONENT_LIBRARY_MANIFEST.md`. Referenced
   third-party packs (Chakra UI, Radix Themes) are *re-implemented* as editable layers, not
   bundled assets — keep it that way.
5. Update the family/theme counts in `README.md` and re-run `ruby scripts/verify_readme.rb`.

---

## Commit and pull request conventions

Match the existing history: a Conventional-Commits style subject with a scope.

```
fix(editor): guard Blend If completion ownership
docs(gate): record rc1726 direct model regression
feat(cli): expose slice export through xomo call
```

Maintainers append an `rcNNNN` release-cycle marker to their own commits for traceability.
Outside contributors do not need it.

Other expectations:

- One logical change per PR. Unrelated refactors or reformatting make a change hard to
  review and will be asked to split.
- PRs should be based on `main` and up to date with it.
- Fill in the pull request template, especially the **How it was verified** section. Paste
  the command and its real output. "Ran the tests" is not evidence.
- Keep generated artifacts out of the diff (`build/`, `dist/`, `test-reports/`, DerivedData).

## Review

What gets checked, in order: does CI pass; is the change atomic and undoable; is there a
test that fails without it; do all three locales have the string; are the README and the
affected reference docs still true.

This is a small team, so review latency varies. If a PR has had no response for a week, a
polite comment on it is welcome — that is a reminder, not a nuisance.

## Security

The app's only network surface is a loopback-only automation endpoint: it writes an
endpoint file with `0600` permissions, mints a fresh token on every launch, and the CLI
reads that token from the file and sends it in the request body — never on the command
line. Figma support executes locally and never asks for your access token.

If you find a security problem, please do not post exploit details in a public issue. Use
the **Security** tab's private vulnerability reporting if it is available, or open a
minimal issue asking for a private channel — without the details.

## License

Xomo is MIT-licensed. By contributing you agree that your contribution is licensed under
the same terms ([`LICENSE`](LICENSE)). Bundled and referenced third-party components are
attributed in [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) — if you add one, add it
there too.
