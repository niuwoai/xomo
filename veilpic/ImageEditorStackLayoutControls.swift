import SwiftUI

struct ImageEditorStackLayoutControls: View {
    @ObservedObject var viewModel: ImageEditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("imageEditor.properties.stackLayout")
            axisPicker
            wrapPicker
            alignmentPickers
            sizingPickers
            spacingStepper
            if viewModel.selectedStackLayout?.wrapMode == .wrap {
                counterSpacingStepper
            }
            paddingSteppers
            reflowButton
        }
    }

    private var axisPicker: some View {
        Picker(
            L10n.text("imageEditor.properties.stackLayoutAxis"),
            selection: Binding(
                get: { viewModel.selectedStackLayout?.axis ?? .horizontal },
                set: { viewModel.setSelectedStackAxis($0) }
            )
        ) {
            ForEach(ImageEditorStackAxis.allCases) { axis in
                Text(L10n.text(axis.localizationKey)).tag(axis)
            }
        }
        .pickerStyle(.segmented)
        .focusable(false)
        .accessibilityIdentifier("image-editor-stack-layout-axis")
    }

    private var wrapPicker: some View {
        Picker(
            L10n.text("imageEditor.properties.stackLayoutWrap"),
            selection: Binding(
                get: { viewModel.selectedStackLayout?.wrapMode ?? .noWrap },
                set: { viewModel.setSelectedStackWrapMode($0) }
            )
        ) {
            ForEach(ImageEditorStackWrapMode.allCases) { mode in
                Text(L10n.text(mode.localizationKey)).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .focusable(false)
        .disabled(viewModel.selectedStackLayout?.axis != .horizontal)
        .accessibilityIdentifier("image-editor-stack-layout-wrap")
    }

    private var alignmentPickers: some View {
        Group {
            Picker(
                L10n.text("imageEditor.properties.stackLayoutPrimaryAlignment"),
                selection: Binding(
                    get: { viewModel.selectedStackLayout?.primaryAlignment ?? .start },
                    set: { viewModel.setSelectedStackPrimaryAlignment($0) }
                )
            ) {
                ForEach(ImageEditorStackPrimaryAlignment.allCases) { alignment in
                    Text(L10n.text(alignment.localizationKey)).tag(alignment)
                }
            }
            .focusable(false)

            Picker(
                L10n.text("imageEditor.properties.stackLayoutCrossAlignment"),
                selection: Binding(
                    get: { viewModel.selectedStackLayout?.crossAlignment ?? .start },
                    set: { viewModel.setSelectedStackCrossAlignment($0) }
                )
            ) {
                ForEach(ImageEditorStackCrossAlignment.availableCases(
                    for: viewModel.selectedStackLayout?.axis ?? .horizontal
                )) { alignment in
                    Text(L10n.text(alignment.localizationKey)).tag(alignment)
                }
            }
            .focusable(false)
            .accessibilityIdentifier("image-editor-stack-layout-cross-alignment")
        }
    }

    private var sizingPickers: some View {
        HStack(spacing: 8) {
            Picker(
                L10n.text("imageEditor.properties.stackLayoutPrimarySizing"),
                selection: Binding(
                    get: { viewModel.selectedStackLayout?.primarySizingMode ?? .fixed },
                    set: { viewModel.setSelectedStackPrimarySizingMode($0) }
                )
            ) {
                ForEach(ImageEditorStackSizingMode.allCases) { mode in
                    Text(L10n.text(mode.localizationKey)).tag(mode)
                }
            }
            .focusable(false)
            .accessibilityIdentifier("image-editor-stack-layout-primary-sizing")

            Picker(
                L10n.text("imageEditor.properties.stackLayoutCrossSizing"),
                selection: Binding(
                    get: { viewModel.selectedStackLayout?.crossSizingMode ?? .fixed },
                    set: { viewModel.setSelectedStackCrossSizingMode($0) }
                )
            ) {
                ForEach(ImageEditorStackSizingMode.allCases) { mode in
                    Text(L10n.text(mode.localizationKey)).tag(mode)
                }
            }
            .focusable(false)
            .accessibilityIdentifier("image-editor-stack-layout-cross-sizing")
        }
    }

    private var spacingStepper: some View {
        Stepper(
            L10n.format(
                "imageEditor.properties.stackLayoutSpacingValue",
                Int((viewModel.selectedStackLayout?.spacing ?? 0).rounded())
            ),
            value: Binding(
                get: { viewModel.selectedStackLayout?.spacing ?? 0 },
                set: { viewModel.setSelectedStackSpacing($0) }
            ),
            in: -256...512,
            step: 1
        )
        .focusable(false)
    }

    private var counterSpacingStepper: some View {
        Stepper(
            L10n.format(
                "imageEditor.properties.stackLayoutCounterSpacingValue",
                Int((viewModel.selectedStackLayout?.counterSpacing ?? 0).rounded())
            ),
            value: Binding(
                get: { viewModel.selectedStackLayout?.counterSpacing ?? 0 },
                set: { viewModel.setSelectedStackCounterSpacing($0) }
            ),
            in: 0...512,
            step: 1
        )
        .focusable(false)
        .accessibilityIdentifier("image-editor-stack-layout-counter-spacing")
    }

    private var paddingSteppers: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                paddingStepper(
                    key: "imageEditor.properties.stackLayoutPaddingTopValue",
                    value: \ImageEditorStackLayout.paddingTop,
                    setter: viewModel.setSelectedStackPaddingTop
                )
                paddingStepper(
                    key: "imageEditor.properties.stackLayoutPaddingRightValue",
                    value: \ImageEditorStackLayout.paddingRight,
                    setter: viewModel.setSelectedStackPaddingRight
                )
            }
            HStack(spacing: 8) {
                paddingStepper(
                    key: "imageEditor.properties.stackLayoutPaddingBottomValue",
                    value: \ImageEditorStackLayout.paddingBottom,
                    setter: viewModel.setSelectedStackPaddingBottom
                )
                paddingStepper(
                    key: "imageEditor.properties.stackLayoutPaddingLeftValue",
                    value: \ImageEditorStackLayout.paddingLeft,
                    setter: viewModel.setSelectedStackPaddingLeft
                )
            }
        }
    }

    private var reflowButton: some View {
        Button(L10n.text("imageEditor.action.stackLayoutReflow")) {
            viewModel.reflowSelectedStackLayout()
        }
        .buttonStyle(EditorTextButtonStyle())
        .focusable(false)
        .disabled(!viewModel.canReflowSelectedStackLayout)
        .accessibilityIdentifier("image-editor-stack-layout-reflow")
    }

    private func paddingStepper(
        key: String,
        value: KeyPath<ImageEditorStackLayout, CGFloat>,
        setter: @escaping (CGFloat) -> Void
    ) -> some View {
        let current = viewModel.selectedStackLayout?[keyPath: value] ?? 0
        return Stepper(
            L10n.format(key, Int(current.rounded())),
            value: Binding(get: { current }, set: setter),
            in: 0...512,
            step: 1
        )
        .focusable(false)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionTitle(_ key: String) -> some View {
        Text(L10n.text(key))
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
    }
}

struct ImageEditorStackChildLayoutControls: View {
    @ObservedObject var viewModel: ImageEditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.text("imageEditor.properties.stackChildLayout"))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.text))

            childSizingPicker(
                key: "imageEditor.properties.stackChildPrimarySizing",
                identifier: "image-editor-stack-child-primary-sizing",
                selection: Binding(
                    get: { viewModel.selectedStackChildLayout?.primarySizingMode ?? .fixed },
                    set: { viewModel.setSelectedStackChildPrimarySizingMode($0) }
                )
            )
            childSizingPicker(
                key: "imageEditor.properties.stackChildCrossSizing",
                identifier: "image-editor-stack-child-cross-sizing",
                selection: Binding(
                    get: { viewModel.selectedStackChildLayout?.crossSizingMode ?? .fixed },
                    set: { viewModel.setSelectedStackChildCrossSizingMode($0) }
                )
            )
        }
    }

    private func childSizingPicker(
        key: String,
        identifier: String,
        selection: Binding<ImageEditorStackChildSizingMode>
    ) -> some View {
        Picker(L10n.text(key), selection: selection) {
            ForEach(ImageEditorStackChildSizingMode.allCases) { mode in
                Text(L10n.text(mode.localizationKey)).tag(mode)
            }
        }
        .focusable(false)
        .accessibilityIdentifier(identifier)
    }
}
