//
//  ImageEditorOptionsBarStyleTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/15.
//

import AppKit
import Foundation
import Testing
@testable import musepic

@Suite
struct ImageEditorOptionsBarStyleTests {
    @Test func optionsBarUsesPureWhiteForeground() throws {
        let color = try #require(
            ImageEditorOptionsBarAppearance.foregroundColor.usingColorSpace(.deviceRGB)
        )

        #expect(color.redComponent > 0.99)
        #expect(color.greenComponent > 0.99)
        #expect(color.blueComponent > 0.99)
    }

    @Test func optionsBarForcesDarkNativeControlsAndExplicitWhiteLabels() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let optionBarStart = try #require(source.range(of: "private var optionBar: some View"))
        let optionBarEnd = try #require(
            source[optionBarStart.upperBound...].range(of: "private var usesBrushOptions: Bool")
        )
        let optionBarSource = source[optionBarStart.lowerBound..<optionBarEnd.lowerBound]

        #expect(optionBarSource.contains(
            ".foregroundStyle(Color(nsColor: ImageEditorOptionsBarAppearance.foregroundColor))"
        ))
        #expect(optionBarSource.contains(".environment(\\.colorScheme, .dark)"))
        #expect(source.contains(
            "Text(mode.compactTitle)\n                    .foregroundStyle(Color(nsColor: ImageEditorOptionsBarAppearance.foregroundColor))"
        ))
        #expect(source.contains(
            "Label(viewModel.marqueeShape.title, systemImage: viewModel.marqueeShape.symbolName)\n                .foregroundStyle(Color(nsColor: ImageEditorOptionsBarAppearance.foregroundColor))"
        ))
        #expect(optionBarSource.contains("titleKey: opacityOptionTitleKey"))
        #expect(source.contains("? \"imageEditor.option.strength\""))
        #expect(source.contains("case .blur, .sharpen, .smudge:"))
        #expect(source.contains("usesStrengthOption ? 0...1 : 0.05...1"))
        #expect(source.contains("displayMultiplier: opacityOptionDisplayMultiplier"))

        let explicitForegroundUses = source.components(
            separatedBy: "ImageEditorOptionsBarAppearance.foregroundColor"
        ).count - 1
        #expect(explicitForegroundUses >= 6)
    }

    private static func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
