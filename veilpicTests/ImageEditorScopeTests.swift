//
//  ImageEditorScopeTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/10.
//

import Foundation
import Testing
@testable import musepic

struct ImageEditorScopeTests {
    @Test func imageEditorKeepsCurrentLightweightCapabilitySurfaceStable() {
        #expect(
            Set(ImageEditorTool.allCases.map(\.rawValue)) == [
                "move",
                "marquee",
                "lasso",
                "magicWand",
                "crop",
                "brush",
                "eraser",
                "cloneStamp",
                "dodge",
                "burn",
                "blur",
                "sharpen",
                "smudge",
                "healingBrush",
                "patchTool",
                "paintBucket",
                "gradient",
                "eyedropper",
                "text",
                "rectangle",
                "ellipse",
                "pen",
                "hand",
                "zoom"
            ]
        )

        #expect(
            Set(ImageEditorAdjustment.allCases.map(\.rawValue)) == [
                "brightness",
                "contrast",
                "brightnessContrast",
                "saturation",
                "vibrance",
                "exposure",
                "hue",
                "hueSaturation",
                "shadowsHighlights",
                "invert",
                "threshold",
                "posterize",
                "levels",
                "curves",
                "colorBalance",
                "blackWhite",
                "channelMixer",
                "photoFilter",
                "colorLookup",
                "selectiveColor",
                "gradientMap",
                "blur",
                "sharpen"
            ]
        )

        #expect(
            Set(ImageEditorFilter.allCases.map(\.rawValue)) == [
                "gaussianBlur",
                "sharpen",
                "pixelate",
                "motionBlur",
                "addNoise",
                "median",
                "unsharpMask",
                "highPass",
                "emboss",
                "findEdges",
                "minimum",
                "maximum",
                "oilPaint",
                "vignette",
                "offset",
                "wave",
                "ripple",
                "pinch",
                "spherize",
                "liquifyPush",
                "liquifyTwirl",
                "liquifyPuckerBloat"
            ]
        )
    }

    @Test func imageEditorDoesNotGrowIntoHeavyExpansionCategories() {
        let blockedFragments = [
            "3d",
            "plugin",
            "generative",
            "neural",
            "cutout",
            "backgroundRemoval",
            "backgroundMatting",
            "cameraRaw"
        ]

        let capabilityNames = ImageEditorTool.allCases.map(\.rawValue)
            + ImageEditorAdjustment.allCases.map(\.rawValue)
            + ImageEditorFilter.allCases.map(\.rawValue)

        for name in capabilityNames {
            for fragment in blockedFragments {
                #expect(!name.localizedCaseInsensitiveContains(fragment))
            }
        }
    }
}
