//
//  ImageEditorBlendModeTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/9.
//

import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorBlendModeTests {
    @Test func photoshopBlendModeMenuIncludesExtendedBlendFamilies() async throws {
        #expect(ImageEditorBlendMode.allCases.contains(.darkerColor))
        #expect(ImageEditorBlendMode.allCases.contains(.lighterColor))
        #expect(ImageEditorBlendMode.allCases.contains(.subtract))
        #expect(ImageEditorBlendMode.allCases.contains(.divide))
        #expect(ImageEditorBlendMode.allCases.contains(.hardMix))
        #expect(ImageEditorBlendMode.darkerColor.title != "imageEditor.blend.darkerColor")
        #expect(ImageEditorBlendMode.lighterColor.title != "imageEditor.blend.lighterColor")
        #expect(ImageEditorBlendMode.subtract.title != "imageEditor.blend.subtract")
        #expect(ImageEditorBlendMode.divide.title != "imageEditor.blend.divide")
        #expect(ImageEditorBlendMode.hardMix.title != "imageEditor.blend.hardMix")
    }

    @Test func photoshopExtendedBlendModesUsePixelMath() async throws {
        let darker = ImageEditorBlendMode.darkerColor.blend(
            baseRed: 0.20,
            baseGreen: 0.80,
            baseBlue: 0.20,
            overlayRed: 0.80,
            overlayGreen: 0.10,
            overlayBlue: 0.10
        )
        #expect(abs(darker.red - 0.80) < 0.001)
        #expect(abs(darker.green - 0.10) < 0.001)
        #expect(abs(darker.blue - 0.10) < 0.001)

        let lighter = ImageEditorBlendMode.lighterColor.blend(
            baseRed: 0.20,
            baseGreen: 0.80,
            baseBlue: 0.20,
            overlayRed: 0.80,
            overlayGreen: 0.10,
            overlayBlue: 0.10
        )
        #expect(abs(lighter.red - 0.20) < 0.001)
        #expect(abs(lighter.green - 0.80) < 0.001)
        #expect(abs(lighter.blue - 0.20) < 0.001)

        let subtract = ImageEditorBlendMode.subtract.blend(
            baseRed: 0.72,
            baseGreen: 0.55,
            baseBlue: 0.40,
            overlayRed: 0.22,
            overlayGreen: 0.65,
            overlayBlue: 0.10
        )
        #expect(abs(subtract.red - 0.50) < 0.001)
        #expect(abs(subtract.green - 0.00) < 0.001)
        #expect(abs(subtract.blue - 0.30) < 0.001)

        let divide = ImageEditorBlendMode.divide.blend(
            baseRed: 0.20,
            baseGreen: 0.50,
            baseBlue: 0.90,
            overlayRed: 0.50,
            overlayGreen: 0.25,
            overlayBlue: 0.30
        )
        #expect(abs(divide.red - 0.40) < 0.001)
        #expect(abs(divide.green - 1.00) < 0.001)
        #expect(abs(divide.blue - 1.00) < 0.001)

        let hardMix = ImageEditorBlendMode.hardMix.blend(
            baseRed: 0.65,
            baseGreen: 0.35,
            baseBlue: 0.45,
            overlayRed: 0.75,
            overlayGreen: 0.20,
            overlayBlue: 0.55
        )
        #expect(abs(hardMix.red - 1.00) < 0.001)
        #expect(abs(hardMix.green - 0.00) < 0.001)
        #expect(abs(hardMix.blue - 1.00) < 0.001)
    }

    @Test func extendedBlendModesCompositeThroughLayerRenderer() async throws {
        let size = NSSize(width: 12, height: 12)
        let base = solidImage(
            size: size,
            color: NSColor(calibratedRed: 0.20, green: 0.50, blue: 0.90, alpha: 1)
        )
        let overlay = solidImage(
            size: size,
            color: NSColor(calibratedRed: 0.50, green: 0.25, blue: 0.30, alpha: 1)
        )

        let divideImage = try #require(base.blended(with: overlay, mode: .divide, opacity: 1))
        let divide = try #require(divideImage.color(at: CGPoint(x: 6, y: 6))?.usingColorSpace(.deviceRGB))
        #expect(abs(divide.redComponent - 0.40) < 0.02)
        #expect(abs(divide.greenComponent - 1.00) < 0.02)
        #expect(abs(divide.blueComponent - 1.00) < 0.02)

        let subtractImage = try #require(base.blended(with: overlay, mode: .subtract, opacity: 1))
        let subtract = try #require(subtractImage.color(at: CGPoint(x: 6, y: 6))?.usingColorSpace(.deviceRGB))
        #expect(abs(subtract.redComponent - 0.00) < 0.02)
        #expect(abs(subtract.greenComponent - 0.25) < 0.02)
        #expect(abs(subtract.blueComponent - 0.60) < 0.02)
    }

    private func solidImage(size: NSSize, color: NSColor) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        color.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        return image
    }
}
