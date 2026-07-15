# Design QA

- Source visual truth: `test-reports/rc85-options-bar/visual/reference-options-bar.png`
- Implementation screenshot: `test-reports/rc85-options-bar/visual/implementation-options-bar.png`
- Combined comparison: `test-reports/rc85-options-bar/visual/reference-vs-implementation.png`
- Viewport: 686 × 52 px options-bar crop from the 1361 × 768 px Debug app window
- State: Chinese localization, rectangle marquee selected, replace selection mode selected, feather 0 px

**Findings**

- No remaining P0/P1/P2 mismatch. The requested labels and values are now white while the selected state, background, dividers, control sizes, and horizontal rhythm remain unchanged.

**Required Fidelity Surfaces**

- Fonts and typography: system font family, size, weight, baseline, truncation, and antialiasing remain unchanged; only the foreground color changed.
- Spacing and layout rhythm: tool title, segmented control, shape menu, feather control, and divider align with the source crop; no frame or padding changes were introduced.
- Colors and visual tokens: selection-mode text, shape-menu text/icon, feather label, and `0px` value now use explicit pure white. The purple selected state and dark panel background remain intact.
- Image quality and asset fidelity: this toolbar contains only system icons and native controls; no raster assets, placeholders, or replacement artwork were introduced.
- Copy and content: `矩形选区 / 新建 / 添加 / 减去 / 相交 / 矩形 / 羽化 / 0px` remain unchanged.

**Full-view Comparison Evidence**

- The source and implementation toolbar crops are combined side by side in `test-reports/rc85-options-bar/visual/reference-vs-implementation.png`.
- The implementation preserves the source layout and changes only the requested foreground colors.

**Focused Region Comparison Evidence**

- A separate focused crop was unnecessary because the complete source artifact is already a 686 × 52 px focused toolbar region and every affected label is legible at original resolution.

**Comparison History**

- Initial P1: unselected selection modes, shape menu, feather label, and numeric value inherited the outer light color scheme and rendered dark on a dark panel.
- Fix: the options bar now uses a local dark control environment and an explicit pure-white foreground token for affected labels and values.
- Post-fix evidence: the Debug app screenshot shows all requested text and icons in white with no layout or interaction-state regression.

**Implementation Checklist**

- [x] Apply a local dark native-control environment to the options bar.
- [x] Apply explicit pure-white foreground color to the affected labels and values.
- [x] Preserve selected state, layout, and interaction behavior.
- [x] Run the focused unit tests and inspect the live Debug app.

**Follow-up Polish**

- None required for this scoped correction.

final result: passed
