//
//  ImageEditorAdjustmentTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/9.
//

import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorAdjustmentTests {
    @Test func curvesGraphMappingMatchesEditableAnchorValuesAndKeepsIdentityBaseline() {
        let identity = ImageEditorCurvesMapping.points(shadows: 0, midtones: 0, highlights: 0)
        for sample in stride(from: 0.0, through: 1.0, by: 0.1) {
            #expect(abs(ImageEditorCurvesMapping.map(sample, points: identity) - sample) < 0.000001)
        }

        let adjusted = ImageEditorCurvesMapping.points(shadows: 0.4, midtones: -0.5, highlights: 0.2)
        #expect(abs(adjusted[1].1 - 0.35) < 0.000001)
        #expect(abs(adjusted[2].1 - 0.325) < 0.000001)
        #expect(abs(adjusted[3].1 - 0.8) < 0.000001)
        for anchor in ImageEditorCurvesAnchor.allCases {
            let output = ImageEditorCurvesMapping.output(
                for: anchor, shadows: 0.4, midtones: -0.5, highlights: 0.2
            )
            #expect(abs(ImageEditorCurvesMapping.adjustmentValue(for: anchor, output: output)
                - (anchor == .shadows ? 0.4 : anchor == .midtones ? -0.5 : 0.2)) < 0.000001)
        }

        #expect(ImageEditorCurvesMapping.adjustmentValue(for: .shadows, output: -1) == -1)
        #expect(ImageEditorCurvesMapping.adjustmentValue(for: .highlights, output: 2) == 1)

        let monotonic = ImageEditorCurvesMapping.points(shadows: -1, midtones: 0.1, highlights: 1)
        for sample in stride(from: 0.0, to: 1.0, by: 0.01) {
            #expect(ImageEditorCurvesMapping.map(sample, points: monotonic)
                <= ImageEditorCurvesMapping.map(sample + 0.01, points: monotonic) + 0.000001)
        }
    }

    @Test func histogramEqualizationRedistributesVisibleLuminanceAndPreservesAlpha() throws {
        let source = bitmapImage(
            size: NSSize(width: 4, height: 1),
            background: NSColor(calibratedWhite: 0.25, alpha: 0.25),
            fills: [
                (CGRect(x: 2, y: 0, width: 1, height: 1), NSColor(calibratedWhite: 0.50, alpha: 0.50)),
                (CGRect(x: 3, y: 0, width: 1, height: 1), NSColor(calibratedWhite: 0.75, alpha: 1))
            ]
        )

        let equalized = try #require(source.histogramEqualized())
        let dark = try #require(equalized.color(at: CGPoint(x: 0, y: 0))?.usingColorSpace(.deviceRGB))
        let middle = try #require(equalized.color(at: CGPoint(x: 2, y: 0))?.usingColorSpace(.deviceRGB))
        let light = try #require(equalized.color(at: CGPoint(x: 3, y: 0))?.usingColorSpace(.deviceRGB))

        #expect(dark.redComponent < 0.03)
        #expect(abs(middle.redComponent - 0.5) < 0.04)
        #expect(light.redComponent > 0.97)
        #expect(abs(dark.alphaComponent - 0.25) < 0.03)
        #expect(abs(middle.alphaComponent - 0.50) < 0.03)
        #expect(abs(light.alphaComponent - 1) < 0.01)
    }

    @Test func histogramEqualizationIsNoOpForUniformVisibleTones() throws {
        let source = bitmapImage(
            size: NSSize(width: 8, height: 4),
            background: NSColor(calibratedRed: 0.35, green: 0.22, blue: 0.12, alpha: 0.6)
        )

        let equalized = try #require(source.histogramEqualized())
        #expect(equalized.qingtuPNGData() == source.qingtuPNGData())
    }

    @Test func histogramEqualizationRespectsSelectionAndUsesOneUndoRedoStep() throws {
        let image = bitmapImage(
            size: NSSize(width: 4, height: 1),
            background: NSColor(calibratedWhite: 0.25, alpha: 1),
            fills: [
                (CGRect(x: 2, y: 0, width: 1, height: 1), NSColor(calibratedWhite: 0.50, alpha: 1)),
                (CGRect(x: 3, y: 0, width: 1, height: 1), NSColor(calibratedWhite: 0.75, alpha: 1))
            ]
        )
        let viewModel = editableRasterViewModel(image: image)
        viewModel.document.selection = .rectangle(CGRect(x: 2, y: 0, width: 2, height: 1))
        let before = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())

        #expect(viewModel.canEqualizeSelectedLayer)
        viewModel.equalizeSelectedLayer()

        let after = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        #expect(after != before)
        let untouched = try #require(
            viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 0, y: 0))?.usingColorSpace(.deviceRGB)
        )
        #expect(abs(untouched.redComponent - 0.25) < 0.02)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.equalize"))

        viewModel.undo()
        #expect(viewModel.document.selectedLayer?.image.qingtuPNGData() == before)

        viewModel.redo()
        #expect(viewModel.document.selectedLayer?.image.qingtuPNGData() == after)
    }

    @Test func automaticCorrectionsUseStraightRGBAndPreservePremultipliedAlpha() throws {
        let size = NSSize(width: 20, height: 10)
        let dark = NSColor(calibratedRed: 0.20, green: 0.30, blue: 0.40, alpha: 0.25)
        let light = NSColor(calibratedRed: 0.60, green: 0.70, blue: 0.80, alpha: 0.75)
        let translucent = bitmapImage(
            size: size,
            background: dark,
            fills: [(CGRect(x: 10, y: 0, width: 10, height: 10), light)]
        )
        let opaque = bitmapImage(
            size: size,
            background: NSColor(calibratedRed: 0.20, green: 0.30, blue: 0.40, alpha: 1),
            fills: [(
                CGRect(x: 10, y: 0, width: 10, height: 10),
                NSColor(calibratedRed: 0.60, green: 0.70, blue: 0.80, alpha: 1)
            )]
        )
        let corrections: [(String, (NSImage) -> NSImage?)] = [
            ("Auto Levels", { $0.autoLeveled() }),
            ("Auto Contrast", { $0.autoContrasted() }),
            ("Auto Color", { $0.autoColored() })
        ]

        for (name, correction) in corrections {
            let edited = try #require(correction(translucent), "\(name) should produce an image")
            let reference = try #require(correction(opaque), "\(name) should produce an opaque reference")
            for (point, expectedAlpha) in [(CGPoint(x: 5, y: 5), 0.25), (CGPoint(x: 15, y: 5), 0.75)] {
                let actual = try #require(edited.color(at: point)?.usingColorSpace(.deviceRGB))
                let expected = try #require(reference.color(at: point)?.usingColorSpace(.deviceRGB))
                #expect(abs(actual.redComponent - expected.redComponent) < 0.025, "\(name) red at \(point)")
                #expect(abs(actual.greenComponent - expected.greenComponent) < 0.025, "\(name) green at \(point)")
                #expect(abs(actual.blueComponent - expected.blueComponent) < 0.025, "\(name) blue at \(point)")
                #expect(abs(actual.alphaComponent - expectedAlpha) < 0.025, "\(name) alpha at \(point)")
            }
        }
    }

    @Test func automaticToneCorrectionsIgnoreIsolatedHistogramOutliers() throws {
        let size = NSSize(width: 100, height: 100)
        let image = bitmapImage(
            size: size,
            background: NSColor(calibratedWhite: 0.40, alpha: 1),
            fills: [
                (CGRect(x: 50, y: 0, width: 50, height: 100), NSColor(calibratedWhite: 0.60, alpha: 1)),
                (CGRect(x: 0, y: 0, width: 1, height: 1), NSColor.black),
                (CGRect(x: 99, y: 99, width: 1, height: 1), NSColor.white)
            ]
        )
        let corrections: [(String, (NSImage) -> NSImage?)] = [
            ("Auto Levels", { $0.autoLeveled() }),
            ("Auto Contrast", { $0.autoContrasted() })
        ]

        for (name, correction) in corrections {
            let adjusted = try #require(correction(image), "\(name) should produce an image")
            let dark = try #require(adjusted.color(at: CGPoint(x: 25, y: 50))?.usingColorSpace(.deviceRGB))
            let light = try #require(adjusted.color(at: CGPoint(x: 75, y: 50))?.usingColorSpace(.deviceRGB))
            #expect(dark.redComponent < 0.04, "\(name) should stretch the common dark tone")
            #expect(light.redComponent > 0.95, "\(name) should stretch the common light tone")
        }
    }

    @Test func automaticCorrectionsIgnoreLowAlphaColorOutliers() throws {
        let size = NSSize(width: 20, height: 10)
        let gray = NSColor(calibratedWhite: 0.40, alpha: 1)
        let imageWithFaintColorFringe = bitmapImage(
            size: size,
            background: gray,
            fills: [(
                CGRect(x: 9, y: 9, width: 1, height: 1),
                NSColor(calibratedRed: 1, green: 0, blue: 0, alpha: 0.004)
            )]
        )
        let neutralReference = bitmapImage(size: size, background: gray, fills: [])
        let corrections: [(String, (NSImage) -> NSImage?)] = [
            ("Auto Levels", { $0.autoLeveled() }),
            ("Auto Contrast", { $0.autoContrasted() }),
            ("Auto Color", { $0.autoColored() })
        ]

        for (name, correction) in corrections {
            let actualImage = try #require(correction(imageWithFaintColorFringe), "\(name) should produce an image")
            let referenceImage = try #require(correction(neutralReference), "\(name) should produce a reference")
            let actual = try #require(actualImage.color(at: CGPoint(x: 5, y: 5))?.usingColorSpace(.deviceRGB))
            let reference = try #require(referenceImage.color(at: CGPoint(x: 5, y: 5))?.usingColorSpace(.deviceRGB))
            #expect(abs(actual.redComponent - reference.redComponent) < 0.004, "\(name) red should ignore an isolated color fringe")
            #expect(abs(actual.greenComponent - reference.greenComponent) < 0.004, "\(name) green should ignore an isolated color fringe")
            #expect(abs(actual.blueComponent - reference.blueComponent) < 0.004, "\(name) blue should ignore an isolated color fringe")
        }
    }

    @Test func levelsNumericInputsClampToSupportedRangesWithoutCrossingChannels() {
        let viewModel = ImageEditorViewModel(
            sourceName: "levels-input-range.png",
            image: NSImage(size: NSSize(width: 4, height: 4))
        ) { _ in }

        viewModel.levelsChannel = .red
        viewModel.selectedLevelsBlackPoint = -1
        viewModel.selectedLevelsGamma = 8
        viewModel.selectedLevelsWhitePoint = 0
        viewModel.selectedLevelsOutputBlackPoint = 2
        viewModel.selectedLevelsOutputWhitePoint = -1
        #expect(viewModel.levelsRedBlackPoint == 0)
        #expect(viewModel.levelsRedGamma == 4)
        #expect(viewModel.levelsRedWhitePoint == 0.02)
        #expect(viewModel.levelsRedOutputBlackPoint == 1)
        #expect(viewModel.levelsRedOutputWhitePoint == 1)

        viewModel.levelsChannel = .green
        viewModel.selectedLevelsBlackPoint = 0.37
        viewModel.selectedLevelsGamma = 1.65
        viewModel.selectedLevelsWhitePoint = 0.82
        viewModel.selectedLevelsOutputBlackPoint = 0.37
        viewModel.selectedLevelsOutputWhitePoint = 0.82
        #expect(viewModel.levelsGreenBlackPoint == 0.37)
        #expect(viewModel.levelsGreenGamma == 1.65)
        #expect(viewModel.levelsGreenWhitePoint == 0.82)
        #expect(viewModel.levelsGreenOutputBlackPoint == 0.37)
        #expect(viewModel.levelsGreenOutputWhitePoint == 0.82)

        viewModel.levelsChannel = .blue
        viewModel.selectedLevelsBlackPoint = 2
        viewModel.selectedLevelsGamma = 0
        viewModel.selectedLevelsWhitePoint = 2
        viewModel.selectedLevelsOutputBlackPoint = 2
        viewModel.selectedLevelsOutputWhitePoint = -1
        #expect(viewModel.levelsBlueBlackPoint == 0.98)
        #expect(viewModel.levelsBlueGamma == 0.1)
        #expect(viewModel.levelsBlueWhitePoint == 1)
        #expect(viewModel.levelsBlueOutputBlackPoint == 1)
        #expect(viewModel.levelsBlueOutputWhitePoint == 1)

        viewModel.levelsChannel = .rgb
        #expect(viewModel.levelsBlackPoint == 0)
        #expect(viewModel.levelsGamma == 1)
        #expect(viewModel.levelsWhitePoint == 1)
        #expect(viewModel.levelsOutputBlackPoint == 0)
        #expect(viewModel.levelsOutputWhitePoint == 1)
    }

    @Test func levelsAdjustmentEditsRGBChannelsIndependentlyAndSurvivesUndoRedo() throws {
        let canvasSize = NSSize(width: 20, height: 20)
        let sourceImage = bitmapImage(
            size: canvasSize,
            background: NSColor(calibratedRed: 0.60, green: 0.25, blue: 0.60, alpha: 0.45)
        )
        let viewModel = ImageEditorViewModel(sourceName: "levels-channels.png", image: sourceImage) { _ in }
        viewModel.selectedAdjustment = .levels
        viewModel.levelsOutputBlackPoint = 0.05
        viewModel.levelsOutputWhitePoint = 0.95

        viewModel.levelsChannel = .red
        viewModel.selectedLevelsBlackPoint = 0.20
        viewModel.selectedLevelsOutputBlackPoint = 0.20
        viewModel.selectedLevelsOutputWhitePoint = 0.70
        viewModel.levelsChannel = .green
        viewModel.selectedLevelsGamma = 2
        viewModel.selectedLevelsOutputBlackPoint = 0.10
        viewModel.selectedLevelsOutputWhitePoint = 0.70
        viewModel.levelsChannel = .blue
        viewModel.selectedLevelsWhitePoint = 0.80
        viewModel.selectedLevelsOutputBlackPoint = 0.05
        viewModel.selectedLevelsOutputWhitePoint = 0.95
        viewModel.addAdjustmentLayer()

        let adjustmentLayer = try #require(viewModel.document.selectedLayer)
        let adjustedColor = try #require(
            viewModel.currentImage.color(at: CGPoint(x: 10, y: 10))?.usingColorSpace(.deviceRGB)
        )
        #expect(adjustmentLayer.adjustmentSettings.levelsRedBlackPoint == 0.20)
        #expect(adjustmentLayer.adjustmentSettings.levelsGreenGamma == 2)
        #expect(adjustmentLayer.adjustmentSettings.levelsBlueWhitePoint == 0.80)
        #expect(adjustmentLayer.adjustmentSettings.levelsRedOutputBlackPoint == 0.20)
        #expect(adjustmentLayer.adjustmentSettings.levelsGreenOutputWhitePoint == 0.70)
        #expect(adjustmentLayer.adjustmentSettings.levelsBlueOutputWhitePoint == 0.95)
        #expect(abs(adjustedColor.redComponent - 0.444) < 0.025)
        #expect(abs(adjustedColor.greenComponent - 0.415) < 0.025)
        #expect(abs(adjustedColor.blueComponent - 0.714) < 0.025)
        #expect(abs(adjustedColor.alphaComponent - 0.45) < 0.025)
        #expect(
            viewModel.selectedLayerGeometryText.contains(
                L10n.format("imageEditor.properties.levelsLayerOutputValue", 13, 242)
            )
        )
        #expect(
            viewModel.selectedLayerGeometryText.contains(
                L10n.format(
                    "imageEditor.properties.levelsLayerChannelValue",
                    L10n.text("imageEditor.levels.channel.red"),
                    51,
                    "1.00",
                    255
                )
            )
        )
        #expect(viewModel.selectedLayerGeometryText.contains(
            L10n.format(
                "imageEditor.properties.levelsLayerChannelOutputValue",
                L10n.text("imageEditor.levels.channel.red"),
                51,
                179
            )
        ))

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == adjustmentLayer.id })
        #expect(restoredLayer.adjustmentSettings.levelsRedBlackPoint == 0.20)
        #expect(restoredLayer.adjustmentSettings.levelsGreenGamma == 2)
        #expect(restoredLayer.adjustmentSettings.levelsBlueWhitePoint == 0.80)
        #expect(restoredLayer.adjustmentSettings.levelsRedOutputBlackPoint == 0.20)
        #expect(restoredLayer.adjustmentSettings.levelsGreenOutputWhitePoint == 0.70)
        #expect(restoredLayer.adjustmentSettings.levelsBlueOutputWhitePoint == 0.95)
        #expect(restoredLayer.adjustmentSettings.levelsOutputBlackPoint == 0.05)
        #expect(restoredLayer.adjustmentSettings.levelsOutputWhitePoint == 0.95)

        let adjustedPixels = try #require(viewModel.currentImage.qingtuPNGData())
        viewModel.undo()
        let restoredBaseColor = try #require(
            viewModel.currentImage.color(at: CGPoint(x: 10, y: 10))?.usingColorSpace(.deviceRGB)
        )
        #expect(abs(restoredBaseColor.redComponent - 0.60) < 0.025)
        #expect(abs(restoredBaseColor.greenComponent - 0.25) < 0.025)
        #expect(abs(restoredBaseColor.blueComponent - 0.60) < 0.025)

        viewModel.redo()
        #expect(viewModel.currentImage.qingtuPNGData() == adjustedPixels)
    }

    @Test func curvesAdjustmentAppliesRGBThenPerChannelAndSurvivesProjectRoundTrip() throws {
        let sourceImage = bitmapImage(
            size: NSSize(width: 20, height: 20),
            background: NSColor(calibratedRed: 0.60, green: 0.25, blue: 0.60, alpha: 0.45)
        )
        let viewModel = ImageEditorViewModel(sourceName: "curves-channels.png", image: sourceImage) { _ in }
        viewModel.selectedAdjustment = .curves
        viewModel.curvesChannel = .rgb
        viewModel.selectedCurvesMidtones = 0.20
        viewModel.curvesChannel = .red
        viewModel.selectedCurvesMidtones = 0.60
        viewModel.curvesChannel = .green
        viewModel.selectedCurvesShadows = 0.25
        viewModel.curvesChannel = .blue
        viewModel.selectedCurvesHighlights = 0.40
        viewModel.addAdjustmentLayer()

        let layer = try #require(viewModel.document.selectedLayer)
        let adjustedColor = try #require(
            viewModel.currentImage.color(at: CGPoint(x: 10, y: 10))?.usingColorSpace(.deviceRGB)
        )
        #expect(layer.adjustmentSettings.curvesRedMidtones == 0.60)
        #expect(layer.adjustmentSettings.curvesMidtones == 0.20)
        #expect(layer.adjustmentSettings.curvesGreenShadows == 0.25)
        #expect(layer.adjustmentSettings.curvesBlueHighlights == 0.40)
        #expect(abs(adjustedColor.redComponent - 0.732) < 0.03)
        #expect(abs(adjustedColor.greenComponent - 0.3125) < 0.03)
        #expect(abs(adjustedColor.blueComponent - 0.693) < 0.03)
        #expect(abs(adjustedColor.alphaComponent - 0.45) < 0.025)
        #expect(viewModel.selectedLayerGeometryText.contains(
            L10n.format(
                "imageEditor.properties.curvesLayerChannelValue",
                L10n.text("imageEditor.curves.channel.red"),
                0,
                60,
                0
            )
        ))

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restored = try project.restoredDocument()
        let restoredLayer = try #require(restored.layers.first { $0.id == layer.id })
        #expect(restoredLayer.adjustmentSettings.curvesMidtones == 0.20)
        #expect(restoredLayer.adjustmentSettings.curvesRedMidtones == 0.60)
        #expect(restoredLayer.adjustmentSettings.curvesGreenShadows == 0.25)
        #expect(restoredLayer.adjustmentSettings.curvesBlueHighlights == 0.40)
    }

    @Test func adjustmentLayerOpacityBlendsTheCompletedEffectWithoutChangingItsParameters() throws {
        let canvasSize = NSSize(width: 48, height: 32)
        let sourceImage = bitmapImage(
            size: canvasSize,
            background: NSColor(deviceRed: 0.9, green: 0.1, blue: 0.1, alpha: 1)
        )
        let viewModel = ImageEditorViewModel(sourceName: "adjustment-layer-opacity.png", image: sourceImage) { _ in }
        viewModel.selectedAdjustment = .invert
        viewModel.adjustmentValue = 1
        viewModel.addAdjustmentLayer()

        let adjustmentIndex = try #require(
            viewModel.document.layers.firstIndex { $0.id == viewModel.document.selectedLayerID }
        )
        let baseIndex = try #require(
            viewModel.document.layers.indices.first { !viewModel.document.layers[$0].isAdjustment }
        )
        viewModel.setSelectedLayerOpacity(0.5)

        let expectedImage = try #require(
            sourceImage.applyingAdjustment(
                kind: .invert,
                amount: 1,
                mask: nil,
                opacity: 0.5
            )
        )
        let parameterScaledImage = try #require(
            sourceImage.applyingAdjustment(
                kind: .invert,
                amount: 0.5,
                mask: nil
            )
        )
        let adjustmentLayer = viewModel.document.layers[adjustmentIndex]
        let merged = try #require(
            viewModel.mergedAdjustmentLayer(lowerIndex: baseIndex, adjustmentIndex: adjustmentIndex)
        )

        #expect(adjustmentLayer.adjustment?.amount == 1)
        #expect(imageEditorMaximumPixelDifference(viewModel.currentImage, expectedImage) == 0)
        #expect(imageEditorMaximumPixelDifference(viewModel.currentImage, parameterScaledImage) > 0)
        #expect(imageEditorMaximumPixelDifference(merged.image, viewModel.currentImage) == 0)
    }

    @Test func imageEditorDesaturatesSelectedLayerWithClassicCommand() throws {
        let canvasSize = NSSize(width: 20, height: 20)
        let sourceImage = bitmapImage(
            size: canvasSize,
            background: NSColor(calibratedRed: 0.95, green: 0.10, blue: 0.05, alpha: 1)
        )
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        let selectedLayerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[selectedLayerIndex].image = sourceImage

        let before = try #require(viewModel.currentImage.color(at: CGPoint(x: 10, y: 10)))
        viewModel.desaturateSelectedLayer()
        let after = try #require(viewModel.currentImage.color(at: CGPoint(x: 10, y: 10)))

        #expect(saturation(of: before) > 0.75)
        #expect(saturation(of: after) < 0.05)
        #expect(abs(after.redComponent - after.greenComponent) < 0.04)
        #expect(abs(after.greenComponent - after.blueComponent) < 0.04)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.desaturate"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.desaturate"))
    }

    @Test func imageEditorInvertsSelectedLayerWithClassicCommand() throws {
        let canvasSize = NSSize(width: 20, height: 20)
        let sourceImage = bitmapImage(
            size: canvasSize,
            background: NSColor(calibratedRed: 0.20, green: 0.65, blue: 0.90, alpha: 1)
        )
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        let selectedLayerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[selectedLayerIndex].image = sourceImage

        let before = try #require(viewModel.currentImage.color(at: CGPoint(x: 10, y: 10)))
        viewModel.invertSelectedLayer()
        let after = try #require(viewModel.currentImage.color(at: CGPoint(x: 10, y: 10)))

        #expect(abs(after.redComponent - (1 - before.redComponent)) < 0.04)
        #expect(abs(after.greenComponent - (1 - before.greenComponent)) < 0.04)
        #expect(abs(after.blueComponent - (1 - before.blueComponent)) < 0.04)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.invert"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.invert"))
    }

    @Test func imageEditorPatternFillLayerRendersSmartFiltersAndRoundTripsProjectState() async throws {
        let canvasSize = NSSize(width: 60, height: 40)
        let sourceImage = bitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())

        viewModel.selectedPatternFillKind = .checkerboard
        viewModel.patternFillRed = 0.90
        viewModel.patternFillGreen = 0.20
        viewModel.patternFillBlue = 0.10
        viewModel.patternFillOpacity = 1
        viewModel.patternFillScale = 10
        viewModel.patternFillOffsetX = 5
        viewModel.patternFillOffsetY = -3
        viewModel.addPatternFillLayer()

        let patternLayer = try #require(viewModel.document.selectedLayer)
        let patternContent = try #require(patternLayer.patternFillContent?.normalized())
        let firstSquare = try #require(viewModel.currentImage.color(at: CGPoint(x: 2, y: 2)))
        let secondSquare = try #require(viewModel.currentImage.color(at: CGPoint(x: 7, y: 2)))
        let (coloredSquare, transparentSquare) = firstSquare.redComponent >= secondSquare.redComponent
            ? (firstSquare, secondSquare)
            : (secondSquare, firstSquare)

        #expect(patternLayer.isPatternFill)
        #expect(patternContent.kind == .checkerboard)
        #expect(abs(patternContent.red - 0.90) < 0.001)
        #expect(abs(patternContent.green - 0.20) < 0.001)
        #expect(abs(patternContent.blue - 0.10) < 0.001)
        #expect(abs(patternContent.opacity - 1) < 0.001)
        #expect(abs(patternContent.scale - 10) < 0.001)
        #expect(abs(patternContent.offsetX - 5) < 0.001)
        #expect(abs(patternContent.offsetY + 3) < 0.001)
        var zeroPhaseContent = patternContent
        zeroPhaseContent.offsetX = 0
        zeroPhaseContent.offsetY = 0
        #expect(
            patternContent.renderedImage(size: canvasSize).qingtuPNGData()
                != zeroPhaseContent.renderedImage(size: canvasSize).qingtuPNGData()
        )
        #expect(coloredSquare.redComponent > transparentSquare.redComponent + 0.45)
        #expect(coloredSquare.greenComponent > transparentSquare.greenComponent + 0.08)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(
            viewModel.selectedLayerGeometryText == L10n.format(
                "imageEditor.properties.patternFillLayerValue",
                patternContent.kind.title,
                100,
                10,
                5,
                -3
            )
        )
        #expect(viewModel.visibleLayerRows(matching: "", kindFilter: .patternFill).contains { $0.id == patternLayer.id })
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerPatternFillNew"))

        viewModel.selectedPatternFillKind = .dots
        viewModel.patternFillOpacity = 0.50
        viewModel.patternFillScale = 18
        viewModel.patternFillOffsetX = -11
        viewModel.patternFillOffsetY = 9
        viewModel.updateSelectedPatternFillLayer()

        let updatedContent = try #require(viewModel.document.selectedLayer?.patternFillContent?.normalized())
        #expect(updatedContent.kind == .dots)
        #expect(abs(updatedContent.opacity - 0.50) < 0.001)
        #expect(abs(updatedContent.scale - 18) < 0.001)
        #expect(abs(updatedContent.offsetX + 11) < 0.001)
        #expect(abs(updatedContent.offsetY - 9) < 0.001)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerPatternFillUpdate"))

        viewModel.selectedFilter = .vignette
        viewModel.filterIntensity = 1
        viewModel.addSmartFilterToSelectedLayer()

        let smartFilteredLayer = try #require(viewModel.document.selectedLayer)
        let filteredCorner = try #require(viewModel.currentImage.color(at: CGPoint(x: 0, y: 0))?.usingColorSpace(.deviceRGB))
        #expect(smartFilteredLayer.smartFilters.first?.kind == .vignette)
        #expect(filteredCorner.redComponent < coloredSquare.redComponent * 0.35)

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == patternLayer.id })
        let restoredContent = try #require(restoredLayer.patternFillContent?.normalized())
        #expect(restoredLayer.isPatternFill)
        #expect(restoredContent.kind == .dots)
        #expect(abs(restoredContent.opacity - 0.50) < 0.001)
        #expect(abs(restoredContent.scale - 18) < 0.001)
        #expect(abs(restoredContent.offsetX + 11) < 0.001)
        #expect(abs(restoredContent.offsetY - 9) < 0.001)
        #expect(restoredLayer.smartFilters.first?.kind == .vignette)

        let legacyJSON = """
        {
          "kind": "checkerboard",
          "red": 0.1,
          "green": 0.2,
          "blue": 0.3,
          "opacity": 0.5,
          "scale": 12
        }
        """
        let legacyContent = try JSONDecoder().decode(
            ImageEditorPatternFillContent.self,
            from: try #require(legacyJSON.data(using: .utf8))
        )
        #expect(legacyContent.offsetX == 0)
        #expect(legacyContent.offsetY == 0)
    }

    @Test func imageEditorSolidColorFillLayerRendersSmartFiltersAndRoundTripsProjectState() async throws {
        let canvasSize = NSSize(width: 60, height: 40)
        let sourceImage = bitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())

        viewModel.solidColorFillRed = 0.10
        viewModel.solidColorFillGreen = 0.45
        viewModel.solidColorFillBlue = 0.95
        viewModel.addSolidColorFillLayer()

        let fillLayer = try #require(viewModel.document.selectedLayer)
        let fillContent = try #require(fillLayer.solidColorFillContent?.normalized())
        let centerColor = try #require(viewModel.currentImage.color(at: CGPoint(x: 30, y: 20)))

        #expect(fillLayer.isSolidColorFill)
        #expect(abs(fillContent.red - 0.10) < 0.001)
        #expect(abs(fillContent.green - 0.45) < 0.001)
        #expect(abs(fillContent.blue - 0.95) < 0.001)
        #expect(centerColor.blueComponent > centerColor.greenComponent + 0.25)
        #expect(centerColor.greenComponent > centerColor.redComponent + 0.15)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(viewModel.selectedLayerGeometryText == L10n.format("imageEditor.properties.solidColorFillLayerValue", 26, 115, 242))
        #expect(viewModel.visibleLayerRows(matching: "", kindFilter: .solidColorFill).contains { $0.id == fillLayer.id })
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSolidColorFillNew"))

        viewModel.solidColorFillRed = 0.80
        viewModel.solidColorFillGreen = 0.10
        viewModel.solidColorFillBlue = 0.20
        viewModel.updateSelectedSolidColorFillLayer()

        let updatedContent = try #require(viewModel.document.selectedLayer?.solidColorFillContent?.normalized())
        let updatedColor = try #require(viewModel.currentImage.color(at: CGPoint(x: 30, y: 20)))
        #expect(abs(updatedContent.red - 0.80) < 0.001)
        #expect(updatedColor.redComponent > updatedColor.blueComponent + 0.30)
        #expect(updatedColor.blueComponent > updatedColor.greenComponent + 0.04)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSolidColorFillUpdate"))

        viewModel.selectedFilter = .vignette
        viewModel.filterIntensity = 1
        viewModel.addSmartFilterToSelectedLayer()

        let smartFilteredLayer = try #require(viewModel.document.selectedLayer)
        let cornerColor = try #require(viewModel.currentImage.color(at: CGPoint(x: 0, y: 0)))
        #expect(smartFilteredLayer.smartFilters.first?.kind == .vignette)
        #expect(cornerColor.redComponent < updatedColor.redComponent * 0.35)

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == fillLayer.id })
        let restoredContent = try #require(restoredLayer.solidColorFillContent?.normalized())
        #expect(restoredLayer.isSolidColorFill)
        #expect(abs(restoredContent.red - 0.80) < 0.001)
        #expect(abs(restoredContent.green - 0.10) < 0.001)
        #expect(restoredLayer.smartFilters.first?.kind == .vignette)
    }

    @Test func imageEditorGradientFillLayerRendersUpdatesAndRoundTripsProjectState() async throws {
        let canvasSize = NSSize(width: 80, height: 30)
        let sourceImage = bitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())

        viewModel.selectedGradientFillPreset = .custom
        viewModel.gradientFillStartRed = 1
        viewModel.gradientFillStartGreen = 0
        viewModel.gradientFillStartBlue = 0
        viewModel.gradientFillEndRed = 0
        viewModel.gradientFillEndGreen = 1
        viewModel.gradientFillEndBlue = 0
        viewModel.selectedGradientFillStyle = .linear
        viewModel.gradientFillDither = true
        viewModel.gradientFillAngle = 0
        viewModel.gradientFillScale = 1
        viewModel.addGradientFillLayer()

        let gradientLayer = try #require(viewModel.document.selectedLayer)
        let content = try #require(gradientLayer.gradientFillContent?.normalized())
        let leftColor = try #require(viewModel.currentImage.color(at: CGPoint(x: 4, y: 15))?.usingColorSpace(.deviceRGB))
        let rightColor = try #require(viewModel.currentImage.color(at: CGPoint(x: 76, y: 15))?.usingColorSpace(.deviceRGB))

        #expect(content.preset == .custom)
        #expect(content.style == .linear)
        #expect(content.dither)
        #expect(content.angle == 0)
        #expect(content.scale == 1)
        #expect(leftColor.redComponent > rightColor.redComponent + 0.55)
        #expect(rightColor.greenComponent > leftColor.greenComponent + 0.55)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(viewModel.selectedLayerGeometryText == L10n.format("imageEditor.properties.gradientFillLayerValue", content.preset.title, content.style.title, 0, 100))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerGradientFillNew"))

        viewModel.gradientFillReverse = true
        viewModel.gradientFillScale = 2
        viewModel.updateSelectedGradientFillLayer()

        let updatedContent = try #require(viewModel.document.selectedLayer?.gradientFillContent?.normalized())
        let reversedLeft = try #require(viewModel.currentImage.color(at: CGPoint(x: 4, y: 15))?.usingColorSpace(.deviceRGB))
        let reversedRight = try #require(viewModel.currentImage.color(at: CGPoint(x: 76, y: 15))?.usingColorSpace(.deviceRGB))
        #expect(updatedContent.reverse)
        #expect(updatedContent.scale == 2)
        #expect(reversedLeft.greenComponent > reversedRight.greenComponent + 0.25)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerGradientFillUpdate"))

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == gradientLayer.id })
        let restoredContent = try #require(restoredLayer.gradientFillContent?.normalized())
        #expect(restoredContent.preset == .custom)
        #expect(restoredContent.style == .linear)
        #expect(restoredContent.reverse)
        #expect(restoredContent.dither)
        #expect(restoredContent.scale == 2)
        #expect(restoredContent.startRed == 1)
        #expect(restoredContent.endGreen == 1)
    }

    @Test func gradientFillDraftEditsEveryStopAndCommitsOneRealTransaction() throws {
        let canvasSize = NSSize(width: 90, height: 40)
        let viewModel = ImageEditorViewModel(
            sourceName: "gradient-stops.png",
            image: bitmapImage(size: canvasSize, background: .clear)
        ) { _ in }
        let original = ImageEditorGradientFillContent(
            preset: .custom,
            style: .linear,
            colorStops: [
                ImageEditorGradientColorStop(
                    position: 0,
                    red: 1,
                    green: 0,
                    blue: 0,
                    alpha: 0.2,
                    midpoint: 0.3
                ),
                ImageEditorGradientColorStop(
                    position: 0.4,
                    red: 0,
                    green: 1,
                    blue: 0,
                    alpha: 0.5,
                    midpoint: 0.7
                ),
                ImageEditorGradientColorStop(
                    position: 1,
                    red: 0,
                    green: 0,
                    blue: 1,
                    alpha: 1
                )
            ]
        ).normalized()
        viewModel.setGradientFillDraft(original)
        #expect(viewModel.gradientFillColorStops == original.shapeColorStops)

        viewModel.setGradientFillColorStopOpacity(at: 1, opacity: 0.65)
        viewModel.setGradientFillColorStopColor(at: 1, color: .systemYellow)
        viewModel.setGradientFillColorStopPosition(at: 1, position: 0.45)
        viewModel.setGradientFillColorStopMidpoint(after: 1, midpoint: 0.25)
        let editedMiddle = viewModel.gradientFillColorStops[1]
        #expect(abs(editedMiddle.alpha - 0.65) < 0.000_001)
        #expect(abs(editedMiddle.position - 0.45) < 0.000_001)
        #expect(abs(editedMiddle.midpoint - 0.25) < 0.000_001)

        let insertedIndex = try #require(viewModel.addGradientFillColorStop())
        #expect(viewModel.gradientFillColorStops.count == 4)
        #expect(insertedIndex == 2)
        let inserted = viewModel.gradientFillColorStops[insertedIndex]
        #expect(abs(inserted.position - 0.725) < 0.000_001)
        #expect(inserted.alpha > 0.65 && inserted.alpha < 1)
        #expect(viewModel.removeGradientFillColorStop(at: insertedIndex) == 2)
        #expect(viewModel.gradientFillColorStops.count == 3)

        viewModel.addGradientFillLayer()
        let layerID = try #require(viewModel.document.selectedLayerID)
        let created = try #require(
            viewModel.document.selectedLayer?.gradientFillContent?.normalized().colorStops
        )
        #expect(created == viewModel.gradientFillColorStops)

        let historyCount = viewModel.document.history.count
        viewModel.setGradientFillColorStopOpacity(at: 1, opacity: 0.8)
        viewModel.updateSelectedGradientFillLayer()
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(
            viewModel.document.selectedLayer?.gradientFillContent?
                .normalized().colorStops?[1].alpha == 0.8
        )

        viewModel.updateSelectedGradientFillLayer()
        #expect(viewModel.document.history.count == historyCount + 1)
        viewModel.undo()
        #expect(
            viewModel.document.layers.first { $0.id == layerID }?
                .gradientFillContent?.normalized().colorStops == created
        )
        viewModel.redo()
        #expect(
            viewModel.document.layers.first { $0.id == layerID }?
                .gradientFillContent?.normalized().colorStops?[1].alpha == 0.8
        )

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restored = try project.restoredDocument()
        #expect(
            restored.layers.first { $0.id == layerID }?
                .gradientFillContent?.normalized().colorStops?[1].alpha == 0.8
        )
    }

    @Test func gradientFillDraftProtectsEndpointsAndSixteenStopLimit() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "gradient-stop-limits.png",
            image: bitmapImage(size: NSSize(width: 60, height: 30), background: .clear)
        ) { _ in }
        viewModel.setGradientFillDraft(
            .shapeLinear(startColor: .systemRed, endColor: .systemBlue)
        )
        let original = viewModel.gradientFillColorStops

        #expect(viewModel.removeGradientFillColorStop(at: 0) == nil)
        #expect(viewModel.removeGradientFillColorStop(at: 1) == nil)
        viewModel.setGradientFillColorStopPosition(at: 0, position: 0.5)
        viewModel.setGradientFillColorStopPosition(at: 1, position: 0.5)
        viewModel.setGradientFillColorStopOpacity(at: 0, opacity: .nan)
        #expect(viewModel.gradientFillColorStops == original)

        while viewModel.gradientFillColorStops.count
            < ImageEditorGradientFillContent.maximumColorStopCount {
            #expect(viewModel.addGradientFillColorStop() != nil)
        }
        #expect(viewModel.gradientFillColorStops.count == 16)
        #expect(viewModel.addGradientFillColorStop() == nil)
        #expect(viewModel.gradientFillColorStops.first?.position == 0)
        #expect(viewModel.gradientFillColorStops.last?.position == 1)
        #expect(
            zip(
                viewModel.gradientFillColorStops,
                viewModel.gradientFillColorStops.dropFirst()
            ).allSatisfy { lower, upper in
                lower.position < upper.position
            }
        )
    }

    @Test func gradientFillTrackGeometryMapsStopsAndMidpoints() throws {
        let width: CGFloat = 112
        let stops = [
            ImageEditorGradientColorStop(
                position: 0,
                color: .systemRed,
                midpoint: 0.25
            ),
            ImageEditorGradientColorStop(
                position: 0.4,
                color: .systemGreen,
                midpoint: 0.75
            ),
            ImageEditorGradientColorStop(position: 1, color: .systemBlue)
        ]

        #expect(
            abs(ImageEditorGradientStopTrackGeometry.xPosition(for: 0.25, width: width) - 31)
                < 0.000_001
        )
        #expect(
            abs(ImageEditorGradientStopTrackGeometry.logicalPosition(forX: 81, width: width) - 0.75)
                < 0.000_001
        )
        #expect(
            abs(
                try #require(
                    ImageEditorGradientStopTrackGeometry.midpointPosition(
                        after: 0,
                        stops: stops
                    )
                ) - 0.1
            ) < 0.000_001
        )
        #expect(
            abs(
                try #require(
                    ImageEditorGradientStopTrackGeometry.midpointPosition(
                        after: 1,
                        stops: stops
                    )
                ) - 0.85
            ) < 0.000_001
        )
        let midpointX = ImageEditorGradientStopTrackGeometry.xPosition(for: 0.7, width: width)
        #expect(
            abs(
                try #require(
                    ImageEditorGradientStopTrackGeometry.midpoint(
                        forX: midpointX,
                        width: width,
                        after: 1,
                        stops: stops
                    )
                ) - 0.5
            ) < 0.000_001
        )
        #expect(
            ImageEditorGradientStopTrackGeometry.midpoint(
                forX: midpointX,
                width: width,
                after: 2,
                stops: stops
            ) == nil
        )
        #expect(ImageEditorGradientStopTrackGeometry.logicalPosition(forX: -20, width: width) == 0)
        #expect(ImageEditorGradientStopTrackGeometry.logicalPosition(forX: 200, width: width) == 1)
        #expect(ImageEditorGradientStopTrackGeometry.logicalPosition(forX: 5, width: 10) == 0.5)
        #expect(ImageEditorGradientStopTrackGeometry.xPosition(for: .nan, width: width) == 6)
        #expect(ImageEditorGradientStopTrackGeometry.xPosition(for: 0.5, width: .nan) == 0)
    }

    @Test func gradientFillTrackAddsAStopAtTheRequestedCurvePosition() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "gradient-track-insertion.png",
            image: bitmapImage(size: NSSize(width: 60, height: 30), background: .clear)
        ) { _ in }
        let original = ImageEditorGradientFillContent(
            preset: .custom,
            colorStops: [
                ImageEditorGradientColorStop(
                    position: 0,
                    red: 1,
                    green: 0,
                    blue: 0,
                    alpha: 0.2,
                    midpoint: 0.25
                ),
                ImageEditorGradientColorStop(
                    position: 1,
                    red: 0,
                    green: 0,
                    blue: 1,
                    alpha: 0.8
                )
            ]
        ).normalized()
        viewModel.setGradientFillDraft(original)
        let historyCount = viewModel.document.history.count
        let expectedColor = try #require(
            original.shapeColor(at: 0.25).usingColorSpace(.deviceRGB)
        )

        let insertedIndex = try #require(viewModel.addGradientFillColorStop(at: 0.25))
        let inserted = viewModel.gradientFillColorStops[insertedIndex]
        let insertedColor = try #require(inserted.color.usingColorSpace(.deviceRGB))
        #expect(insertedIndex == 1)
        #expect(abs(inserted.position - 0.25) < 0.000_001)
        #expect(abs(insertedColor.redComponent - expectedColor.redComponent) < 0.000_001)
        #expect(abs(insertedColor.blueComponent - expectedColor.blueComponent) < 0.000_001)
        #expect(abs(insertedColor.alphaComponent - expectedColor.alphaComponent) < 0.000_001)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.addGradientFillColorStop(at: .nan) == nil)

        viewModel.setGradientFillDraft(
            ImageEditorGradientFillContent(
                preset: .custom,
                colorStops: [
                    ImageEditorGradientColorStop(position: 0, color: .black),
                    ImageEditorGradientColorStop(position: 0.01, color: .gray),
                    ImageEditorGradientColorStop(position: 1, color: .white)
                ]
            )
        )
        let unchanged = viewModel.gradientFillColorStops
        #expect(viewModel.addGradientFillColorStop(at: 0.005) == nil)
        #expect(viewModel.gradientFillColorStops == unchanged)
    }

    @Test func imageEditorGradientFillStylesRenderAndRoundTripProjectState() async throws {
        let canvasSize = NSSize(width: 61, height: 61)
        let sourceImage = bitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }

        viewModel.selectedGradientFillPreset = .custom
        viewModel.selectedGradientFillStyle = .radial
        viewModel.gradientFillStartRed = 1
        viewModel.gradientFillStartGreen = 0
        viewModel.gradientFillStartBlue = 0
        viewModel.gradientFillEndRed = 0
        viewModel.gradientFillEndGreen = 0
        viewModel.gradientFillEndBlue = 1
        viewModel.gradientFillScale = 1
        viewModel.addGradientFillLayer()

        let gradientLayer = try #require(viewModel.document.selectedLayer)
        let radialContent = try #require(gradientLayer.gradientFillContent?.normalized())
        let radialCenter = try #require(viewModel.currentImage.color(at: CGPoint(x: 30, y: 30))?.usingColorSpace(.deviceRGB))
        let radialCorner = try #require(viewModel.currentImage.color(at: CGPoint(x: 0, y: 0))?.usingColorSpace(.deviceRGB))
        #expect(radialContent.style == .radial)
        #expect(radialCenter.redComponent > radialCorner.redComponent + 0.45)
        #expect(radialCorner.blueComponent > radialCenter.blueComponent + 0.45)

        viewModel.selectedGradientFillStyle = .reflected
        viewModel.gradientFillAngle = 0
        viewModel.updateSelectedGradientFillLayer()

        let reflectedContent = try #require(viewModel.document.selectedLayer?.gradientFillContent?.normalized())
        let reflectedCenter = try #require(viewModel.currentImage.color(at: CGPoint(x: 30, y: 30))?.usingColorSpace(.deviceRGB))
        let reflectedEdge = try #require(viewModel.currentImage.color(at: CGPoint(x: 0, y: 30))?.usingColorSpace(.deviceRGB))
        #expect(reflectedContent.style == .reflected)
        #expect(reflectedCenter.redComponent > reflectedEdge.redComponent + 0.35)
        #expect(reflectedEdge.blueComponent > reflectedCenter.blueComponent + 0.35)

        viewModel.selectedGradientFillStyle = .diamond
        viewModel.updateSelectedGradientFillLayer()

        let diamondContent = try #require(viewModel.document.selectedLayer?.gradientFillContent?.normalized())
        let diamondCenter = try #require(viewModel.currentImage.color(at: CGPoint(x: 30, y: 30))?.usingColorSpace(.deviceRGB))
        let diamondCorner = try #require(viewModel.currentImage.color(at: CGPoint(x: 0, y: 0))?.usingColorSpace(.deviceRGB))
        #expect(diamondContent.style == .diamond)
        #expect(diamondCenter.redComponent > diamondCorner.redComponent + 0.45)
        #expect(diamondCorner.blueComponent > diamondCenter.blueComponent + 0.45)

        viewModel.selectedGradientFillStyle = .angle
        viewModel.gradientFillAngle = 90
        viewModel.updateSelectedGradientFillLayer()

        let angleContent = try #require(viewModel.document.selectedLayer?.gradientFillContent?.normalized())
        let angleRight = try #require(viewModel.currentImage.color(at: CGPoint(x: 55, y: 30))?.usingColorSpace(.deviceRGB))
        let angleLeft = try #require(viewModel.currentImage.color(at: CGPoint(x: 5, y: 30))?.usingColorSpace(.deviceRGB))
        #expect(angleContent.style == .angle)
        #expect(abs(angleRight.redComponent - angleLeft.redComponent) > 0.2)
        #expect(viewModel.selectedLayerGeometryText == L10n.format("imageEditor.properties.gradientFillLayerValue", angleContent.preset.title, angleContent.style.title, 90, 100))

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == gradientLayer.id })
        let restoredContent = try #require(restoredLayer.gradientFillContent?.normalized())
        #expect(restoredContent.style == .angle)
        #expect(restoredContent.preset == .custom)
        #expect(restoredContent.startRed == 1)
        #expect(restoredContent.endBlue == 1)
    }

    @Test func imageEditorVibranceAdjustmentPrioritizesMutedColorsAndSupportsLayerState() async throws {
        let canvasSize = NSSize(width: 80, height: 40)
        let sourceImage = bitmapImage(size: canvasSize, background: .black)
        let mutedRed = NSColor(calibratedRed: 0.55, green: 0.35, blue: 0.35, alpha: 1)
        let vividRed = NSColor(calibratedRed: 0.95, green: 0.05, blue: 0.05, alpha: 1)
        let layerImage = bitmapImage(
            size: canvasSize,
            background: .clear,
            fills: [
                (CGRect(x: 0, y: 0, width: 40, height: 40), mutedRed),
                (CGRect(x: 40, y: 0, width: 40, height: 40), vividRed)
            ]
        )
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))

        let mutedBefore = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 20, y: 20))?.usingColorSpace(.deviceRGB))
        let vividBefore = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 60, y: 20))?.usingColorSpace(.deviceRGB))
        let mutedBeforeSaturation = saturation(of: mutedBefore)
        let vividBeforeSaturation = saturation(of: vividBefore)

        viewModel.selectedAdjustment = .vibrance
        viewModel.adjustmentValue = 1
        viewModel.applyAdjustment()

        let mutedAfter = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 20, y: 20))?.usingColorSpace(.deviceRGB))
        let vividAfter = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 60, y: 20))?.usingColorSpace(.deviceRGB))
        let mutedGain = saturation(of: mutedAfter) - mutedBeforeSaturation
        let vividGain = saturation(of: vividAfter) - vividBeforeSaturation

        #expect(mutedGain > 0.45)
        #expect(mutedGain > vividGain + 0.35)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.adjustment.vibrance"))

        viewModel.undo()
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        viewModel.selectedAdjustment = .vibrance
        viewModel.adjustmentValue = 0
        viewModel.vibranceAmount = 0.55
        viewModel.vibranceSaturation = 0.25
        viewModel.addAdjustmentLayer()

        let adjustmentLayer = try #require(viewModel.document.selectedLayer)
        let previewMuted = try #require(viewModel.currentImage.color(at: CGPoint(x: 20, y: 20))?.usingColorSpace(.deviceRGB))

        #expect(adjustmentLayer.adjustment?.kind == .vibrance)
        #expect(adjustmentLayer.adjustment?.amount == 0)
        #expect(adjustmentLayer.adjustmentSettings.vibranceAmount == 0.55)
        #expect(adjustmentLayer.adjustmentSettings.vibranceSaturation == 0.25)
        #expect(viewModel.vibranceAmount == 0.55)
        #expect(viewModel.vibranceSaturation == 0.25)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(saturation(of: previewMuted) > mutedBeforeSaturation + 0.30)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerAdjustmentNew"))

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == adjustmentLayer.id })
        #expect(restoredLayer.adjustmentSettings.vibranceAmount == 0.55)
        #expect(restoredLayer.adjustmentSettings.vibranceSaturation == 0.25)

        let encodedSettingsData = try JSONEncoder().encode(adjustmentLayer.adjustmentSettings)
        let encodedSettings = try #require(String(data: encodedSettingsData, encoding: .utf8))
        let decodedSettings = try JSONDecoder().decode(ImageEditorAdjustmentSettings.self, from: encodedSettingsData)
        #expect(encodedSettings.contains("\"vibranceAmount\""))
        #expect(encodedSettings.contains("\"vibranceSaturation\""))
        #expect(decodedSettings.vibranceAmount == 0.55)
        #expect(decodedSettings.vibranceSaturation == 0.25)
    }

    @Test func imageEditorPosterizeAdjustmentQuantizesChannelsAndSupportsLayerState() async throws {
        let canvasSize = NSSize(width: 90, height: 40)
        let sourceImage = bitmapImage(size: canvasSize, background: .black)
        let layerImage = bitmapImage(
            size: canvasSize,
            background: .clear,
            fills: [
                (CGRect(x: 0, y: 0, width: 30, height: 40), NSColor(calibratedRed: 0.22, green: 0.47, blue: 0.84, alpha: 1)),
                (CGRect(x: 30, y: 0, width: 30, height: 40), NSColor(calibratedRed: 0.49, green: 0.51, blue: 0.49, alpha: 1)),
                (CGRect(x: 60, y: 0, width: 30, height: 40), NSColor(calibratedRed: 0.82, green: 0.18, blue: 0.18, alpha: 1))
            ]
        )
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))

        viewModel.selectedAdjustment = .posterize
        viewModel.adjustmentValue = 3
        viewModel.applyAdjustment()

        let darkQuantized = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 15, y: 20)))
        let midQuantized = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 45, y: 20)))
        let lightQuantized = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 75, y: 20)))

        #expect(darkQuantized.redComponent < 0.05)
        #expect(abs(darkQuantized.greenComponent - 0.5) < 0.03)
        #expect(darkQuantized.blueComponent > 0.95)
        #expect(abs(midQuantized.redComponent - 0.5) < 0.03)
        #expect(abs(midQuantized.greenComponent - 0.5) < 0.03)
        #expect(lightQuantized.redComponent > 0.95)
        #expect(lightQuantized.greenComponent < 0.05)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.adjustment.posterize"))

        viewModel.undo()
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        viewModel.selectedAdjustment = .posterize
        viewModel.adjustmentValue = 4
        viewModel.addAdjustmentLayer()

        let adjustmentLayer = try #require(viewModel.document.selectedLayer)
        let preview = try #require(viewModel.currentImage.color(at: CGPoint(x: 15, y: 20)))

        #expect(adjustmentLayer.adjustment?.kind == .posterize)
        #expect(adjustmentLayer.adjustment?.amount == 4)
        #expect(viewModel.selectedLayerGeometryText == L10n.format("imageEditor.properties.posterizeLayerValue", 4))
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(abs(preview.greenComponent - (1.0 / 3.0)) < 0.04)
        #expect(preview.blueComponent > 0.95)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerAdjustmentNew"))
    }

    @Test func imageEditorShadowsHighlightsAdjustmentRecoversToneRangeAndSupportsLayerState() async throws {
        let canvasSize = NSSize(width: 90, height: 40)
        let sourceImage = bitmapImage(size: canvasSize, background: .black)
        let layerImage = bitmapImage(
            size: canvasSize,
            background: .clear,
            fills: [
                (CGRect(x: 0, y: 0, width: 30, height: 40), NSColor(calibratedRed: 0.16, green: 0.14, blue: 0.12, alpha: 1)),
                (CGRect(x: 30, y: 0, width: 30, height: 40), NSColor(calibratedRed: 0.50, green: 0.48, blue: 0.46, alpha: 1)),
                (CGRect(x: 60, y: 0, width: 30, height: 40), NSColor(calibratedRed: 0.92, green: 0.88, blue: 0.84, alpha: 1))
            ]
        )
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))

        let shadowBefore = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 15, y: 20))?.usingColorSpace(.deviceRGB))
        let midtoneBefore = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 45, y: 20))?.usingColorSpace(.deviceRGB))
        let highlightBefore = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 75, y: 20))?.usingColorSpace(.deviceRGB))

        viewModel.selectedAdjustment = .shadowsHighlights
        viewModel.shadowsHighlightsShadows = 0.70
        viewModel.shadowsHighlightsHighlights = 0.60
        viewModel.applyAdjustment()

        let shadowAfter = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 15, y: 20))?.usingColorSpace(.deviceRGB))
        let midtoneAfter = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 45, y: 20))?.usingColorSpace(.deviceRGB))
        let highlightAfter = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 75, y: 20))?.usingColorSpace(.deviceRGB))

        #expect(shadowAfter.redComponent > shadowBefore.redComponent + 0.35)
        #expect(highlightAfter.redComponent < highlightBefore.redComponent - 0.25)
        #expect(abs(midtoneAfter.redComponent - midtoneBefore.redComponent) < 0.08)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.adjustment.shadowsHighlights"))

        viewModel.undo()
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        viewModel.selectedAdjustment = .shadowsHighlights
        viewModel.shadowsHighlightsShadows = 0.70
        viewModel.shadowsHighlightsHighlights = 0.60
        viewModel.addAdjustmentLayer()

        let adjustmentLayer = try #require(viewModel.document.selectedLayer)
        let settings = adjustmentLayer.adjustmentSettings.normalized()
        let previewShadow = try #require(viewModel.currentImage.color(at: CGPoint(x: 15, y: 20))?.usingColorSpace(.deviceRGB))
        let previewHighlight = try #require(viewModel.currentImage.color(at: CGPoint(x: 75, y: 20))?.usingColorSpace(.deviceRGB))

        #expect(adjustmentLayer.adjustment?.kind == .shadowsHighlights)
        #expect(abs(settings.shadowsHighlightsShadows - 0.70) < 0.001)
        #expect(abs(settings.shadowsHighlightsHighlights - 0.60) < 0.001)
        #expect(viewModel.selectedLayerGeometryText == L10n.format("imageEditor.properties.shadowsHighlightsLayerValue", 70, 60))
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(previewShadow.redComponent > shadowBefore.redComponent + 0.35)
        #expect(previewHighlight.redComponent < highlightBefore.redComponent - 0.25)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerAdjustmentNew"))
    }

    @Test func imageEditorExposureAdjustmentUsesEvOffsetGammaAndSupportsLayerState() async throws {
        let canvasSize = NSSize(width: 80, height: 40)
        let sourceImage = bitmapImage(size: canvasSize, background: .black)
        let layerImage = bitmapImage(
            size: canvasSize,
            background: .clear,
            fills: [
                (CGRect(x: 0, y: 0, width: 40, height: 40), NSColor(calibratedRed: 0.25, green: 0.23, blue: 0.21, alpha: 1)),
                (CGRect(x: 40, y: 0, width: 40, height: 40), NSColor(calibratedRed: 0.65, green: 0.62, blue: 0.59, alpha: 1))
            ]
        )
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))

        let shadowBefore = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 20, y: 20))?.usingColorSpace(.deviceRGB))
        let highlightBefore = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 60, y: 20))?.usingColorSpace(.deviceRGB))

        viewModel.selectedAdjustment = .exposure
        viewModel.exposureEV = 1
        viewModel.exposureOffset = 0.05
        viewModel.exposureGamma = 2
        viewModel.applyAdjustment()

        let shadowAfter = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 20, y: 20))?.usingColorSpace(.deviceRGB))
        let highlightAfter = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 60, y: 20))?.usingColorSpace(.deviceRGB))

        #expect(shadowAfter.redComponent > shadowBefore.redComponent + 0.45)
        #expect(highlightAfter.redComponent > 0.95)
        #expect(highlightAfter.redComponent > highlightBefore.redComponent + 0.25)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.adjustment.exposure"))

        viewModel.undo()
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        viewModel.selectedAdjustment = .exposure
        viewModel.exposureEV = -1
        viewModel.exposureOffset = -0.05
        viewModel.exposureGamma = 1.2
        viewModel.addAdjustmentLayer()

        let adjustmentLayer = try #require(viewModel.document.selectedLayer)
        let settings = adjustmentLayer.adjustmentSettings.normalized()
        let previewShadow = try #require(viewModel.currentImage.color(at: CGPoint(x: 20, y: 20))?.usingColorSpace(.deviceRGB))
        let previewHighlight = try #require(viewModel.currentImage.color(at: CGPoint(x: 60, y: 20))?.usingColorSpace(.deviceRGB))

        #expect(adjustmentLayer.adjustment?.kind == .exposure)
        #expect(abs(settings.exposureEV + 1) < 0.001)
        #expect(abs(settings.exposureOffset + 0.05) < 0.001)
        #expect(abs(settings.exposureGamma - 1.2) < 0.001)
        #expect(viewModel.selectedLayerGeometryText == L10n.format("imageEditor.properties.exposureLayerValue", -1.0, -0.05, 1.2))
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(previewShadow.redComponent < shadowBefore.redComponent - 0.08)
        #expect(previewHighlight.redComponent < highlightBefore.redComponent - 0.25)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerAdjustmentNew"))
    }

    @Test func imageEditorBrightnessContrastAdjustmentCombinesToneControlsAndSupportsLayerState() async throws {
        let canvasSize = NSSize(width: 90, height: 40)
        let sourceImage = bitmapImage(size: canvasSize, background: .black)
        let layerImage = bitmapImage(
            size: canvasSize,
            background: .clear,
            fills: [
                (CGRect(x: 0, y: 0, width: 30, height: 40), NSColor(calibratedRed: 0.30, green: 0.28, blue: 0.26, alpha: 1)),
                (CGRect(x: 30, y: 0, width: 30, height: 40), NSColor(calibratedRed: 0.50, green: 0.48, blue: 0.46, alpha: 1)),
                (CGRect(x: 60, y: 0, width: 30, height: 40), NSColor(calibratedRed: 0.70, green: 0.67, blue: 0.64, alpha: 1))
            ]
        )
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))

        let darkBefore = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 15, y: 20))?.usingColorSpace(.deviceRGB))
        let midBefore = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 45, y: 20))?.usingColorSpace(.deviceRGB))
        let brightBefore = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 75, y: 20))?.usingColorSpace(.deviceRGB))

        viewModel.selectedAdjustment = .brightnessContrast
        viewModel.brightnessContrastBrightness = 0.10
        viewModel.brightnessContrastContrast = 1.00
        viewModel.applyAdjustment()

        let darkAfter = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 15, y: 20))?.usingColorSpace(.deviceRGB))
        let midAfter = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 45, y: 20))?.usingColorSpace(.deviceRGB))
        let brightAfter = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 75, y: 20))?.usingColorSpace(.deviceRGB))

        #expect(darkAfter.redComponent < darkBefore.redComponent - 0.08)
        #expect(midAfter.redComponent > midBefore.redComponent + 0.08)
        #expect(brightAfter.redComponent > brightBefore.redComponent + 0.22)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.adjustment.brightnessContrast"))

        viewModel.undo()
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        viewModel.selectedAdjustment = .brightnessContrast
        viewModel.brightnessContrastBrightness = -0.10
        viewModel.brightnessContrastContrast = -0.40
        viewModel.addAdjustmentLayer()

        let adjustmentLayer = try #require(viewModel.document.selectedLayer)
        let settings = adjustmentLayer.adjustmentSettings.normalized()
        let previewDark = try #require(viewModel.currentImage.color(at: CGPoint(x: 15, y: 20))?.usingColorSpace(.deviceRGB))
        let previewBright = try #require(viewModel.currentImage.color(at: CGPoint(x: 75, y: 20))?.usingColorSpace(.deviceRGB))

        #expect(adjustmentLayer.adjustment?.kind == .brightnessContrast)
        #expect(abs(settings.brightnessContrastBrightness + 0.10) < 0.001)
        #expect(abs(settings.brightnessContrastContrast + 0.40) < 0.001)
        #expect(viewModel.selectedLayerGeometryText == L10n.format("imageEditor.properties.brightnessContrastLayerValue", -10, -40))
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(previewDark.redComponent > darkBefore.redComponent - 0.04)
        #expect(previewBright.redComponent < brightBefore.redComponent - 0.15)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerAdjustmentNew"))
    }

    @Test func imageEditorGradientMapAdjustmentSupportsPresetsAndLayerState() async throws {
        let canvasSize = NSSize(width: 90, height: 60)
        let sourceImage = bitmapImage(size: canvasSize, background: .black)
        let layerImage = bitmapImage(
            size: canvasSize,
            background: .clear,
            fills: [
                (CGRect(x: 0, y: 0, width: 30, height: 60), NSColor(calibratedRed: 0, green: 0, blue: 0, alpha: 1)),
                (CGRect(x: 30, y: 0, width: 30, height: 60), NSColor(calibratedRed: 0.50, green: 0.48, blue: 0.46, alpha: 1)),
                (CGRect(x: 60, y: 0, width: 30, height: 60), NSColor(calibratedRed: 1, green: 1, blue: 1, alpha: 1))
            ]
        )
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))

        viewModel.selectedAdjustment = .gradientMap
        viewModel.selectedGradientMapPreset = .custom
        viewModel.gradientMapShadowRed = 1
        viewModel.gradientMapShadowGreen = 0
        viewModel.gradientMapShadowBlue = 0
        viewModel.gradientMapHighlightRed = 0
        viewModel.gradientMapHighlightGreen = 0
        viewModel.gradientMapHighlightBlue = 1
        viewModel.applyAdjustment()

        let mappedBlack = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 15, y: 30))?.usingColorSpace(.deviceRGB))
        let mappedGray = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 45, y: 30))?.usingColorSpace(.deviceRGB))
        let mappedWhite = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 75, y: 30))?.usingColorSpace(.deviceRGB))

        #expect(mappedBlack.redComponent > 0.95)
        #expect(mappedBlack.blueComponent < 0.05)
        #expect(mappedGray.redComponent > 0.35)
        #expect(mappedGray.blueComponent > 0.35)
        #expect(mappedWhite.blueComponent > 0.95)
        #expect(mappedWhite.redComponent < 0.05)

        viewModel.undo()
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        viewModel.selectedAdjustment = .gradientMap
        viewModel.selectedGradientMapPreset = .custom
        viewModel.gradientMapReverse = true
        viewModel.gradientMapDither = true
        viewModel.gradientMapShadowRed = 1
        viewModel.gradientMapShadowGreen = 0
        viewModel.gradientMapShadowBlue = 0
        viewModel.gradientMapHighlightRed = 0
        viewModel.gradientMapHighlightGreen = 0
        viewModel.gradientMapHighlightBlue = 1
        viewModel.addAdjustmentLayer()

        let adjustmentLayer = try #require(viewModel.document.selectedLayer)
        let settings = adjustmentLayer.adjustmentSettings.normalized()
        let previewBlack = try #require(viewModel.currentImage.color(at: CGPoint(x: 15, y: 30))?.usingColorSpace(.deviceRGB))
        let previewGrayA = try #require(viewModel.currentImage.color(at: CGPoint(x: 44, y: 28))?.usingColorSpace(.deviceRGB))
        let previewGrayB = try #require(viewModel.currentImage.color(at: CGPoint(x: 45, y: 28))?.usingColorSpace(.deviceRGB))
        let previewWhite = try #require(viewModel.currentImage.color(at: CGPoint(x: 75, y: 30))?.usingColorSpace(.deviceRGB))

        #expect(adjustmentLayer.adjustment?.kind == .gradientMap)
        #expect(settings.gradientMapPreset == .custom)
        #expect(settings.gradientMapReverse)
        #expect(settings.gradientMapDither)
        #expect(settings.gradientMapShadowRed == 1)
        #expect(settings.gradientMapHighlightBlue == 1)
        #expect(viewModel.selectedLayerGeometryText == L10n.format("imageEditor.properties.gradientMapDitherLayerValue", settings.gradientMapPreset.title))
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(previewBlack.blueComponent > 0.95)
        #expect(previewBlack.redComponent < 0.05)
        #expect(abs(previewGrayA.redComponent - previewGrayB.redComponent) > 0.002)
        #expect(previewWhite.redComponent > 0.95)
        #expect(previewWhite.blueComponent < 0.05)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerAdjustmentNew"))

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == adjustmentLayer.id })
        #expect(restoredLayer.adjustmentSettings.gradientMapDither)
    }

    @Test func imageEditorSelectiveColorAdjustmentSupportsRangesAndLayerState() async throws {
        let canvasSize = NSSize(width: 90, height: 60)
        let sourceImage = bitmapImage(size: canvasSize, background: .black)
        let layerImage = bitmapImage(
            size: canvasSize,
            background: .clear,
            fills: [
                (CGRect(x: 0, y: 0, width: 30, height: 60), NSColor(calibratedRed: 1, green: 0, blue: 0, alpha: 1)),
                (CGRect(x: 30, y: 0, width: 30, height: 60), NSColor(calibratedRed: 0, green: 1, blue: 0, alpha: 1)),
                (CGRect(x: 60, y: 0, width: 30, height: 60), NSColor(calibratedRed: 0, green: 0, blue: 1, alpha: 1))
            ]
        )
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))

        viewModel.selectedAdjustment = .selectiveColor
        var directSettings = ImageEditorSelectiveColorSettings()
        directSettings.setValues(ImageEditorSelectiveColorValues(cyan: 0.70), for: .reds)
        viewModel.selectiveColorSettings = directSettings
        viewModel.selectiveColorMethod = .absolute
        viewModel.applyAdjustment()

        let adjustedRed = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 15, y: 30))?.usingColorSpace(.deviceRGB))
        let adjustedGreen = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 45, y: 30))?.usingColorSpace(.deviceRGB))

        #expect(adjustedRed.redComponent < 0.45)
        #expect(adjustedRed.greenComponent < 0.05)
        #expect(adjustedRed.blueComponent < 0.05)
        #expect(adjustedGreen.greenComponent > 0.90)
        #expect(adjustedGreen.redComponent < 0.08)

        viewModel.undo()
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        viewModel.selectedAdjustment = .selectiveColor
        viewModel.selectedSelectiveColorRange = .reds
        var layerSettings = ImageEditorSelectiveColorSettings()
        layerSettings.setValues(ImageEditorSelectiveColorValues(cyan: 0.50, black: 0.20), for: .reds)
        layerSettings.setValues(ImageEditorSelectiveColorValues(yellow: 0.60), for: .blues)
        viewModel.selectiveColorSettings = layerSettings
        viewModel.selectiveColorMethod = .relative
        viewModel.addAdjustmentLayer()

        let adjustmentLayer = try #require(viewModel.document.selectedLayer)
        let settings = adjustmentLayer.adjustmentSettings.normalized()
        let previewRed = try #require(viewModel.currentImage.color(at: CGPoint(x: 15, y: 30))?.usingColorSpace(.deviceRGB))
        let previewBlue = try #require(viewModel.currentImage.color(at: CGPoint(x: 75, y: 30))?.usingColorSpace(.deviceRGB))

        #expect(adjustmentLayer.adjustment?.kind == .selectiveColor)
        #expect(settings.selectiveColorMethod == .relative)
        #expect(settings.selectiveColorSettings.values(for: .reds).cyan == 0.50)
        #expect(settings.selectiveColorSettings.values(for: .reds).black == 0.20)
        #expect(settings.selectiveColorSettings.values(for: .blues).yellow == 0.60)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(previewRed.redComponent < 0.55)
        #expect(previewBlue.blueComponent > previewBlue.redComponent + 0.30)
        #expect(previewBlue.greenComponent < 0.08)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerAdjustmentNew"))
    }

    @Test func imageEditorPhotoFilterAdjustmentSupportsPresetsAndCustomLayerState() async throws {
        let canvasSize = NSSize(width: 80, height: 40)
        let sourceImage = bitmapImage(size: canvasSize, background: .black)
        let layerImage = bitmapImage(
            size: canvasSize,
            background: NSColor(calibratedRed: 0.50, green: 0.48, blue: 0.46, alpha: 1)
        )
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))

        viewModel.selectedAdjustment = .photoFilter
        viewModel.selectedPhotoFilterPreset = .warming85
        viewModel.photoFilterDensity = 0.50
        viewModel.photoFilterPreserveLuminosity = true
        viewModel.applyAdjustment()

        let warmed = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 20, y: 20))?.usingColorSpace(.deviceRGB))
        #expect(warmed.redComponent > warmed.blueComponent + 0.20)
        #expect(warmed.greenComponent > warmed.blueComponent + 0.08)

        viewModel.undo()
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        viewModel.selectedAdjustment = .photoFilter
        viewModel.selectedPhotoFilterPreset = .custom
        viewModel.photoFilterDensity = 0.60
        viewModel.photoFilterPreserveLuminosity = false
        viewModel.photoFilterCustomRed = 0.10
        viewModel.photoFilterCustomGreen = 0.30
        viewModel.photoFilterCustomBlue = 1.0
        viewModel.addAdjustmentLayer()

        let adjustmentLayer = try #require(viewModel.document.selectedLayer)
        let settings = adjustmentLayer.adjustmentSettings.normalized()
        let preview = try #require(viewModel.currentImage.color(at: CGPoint(x: 20, y: 20))?.usingColorSpace(.deviceRGB))

        #expect(adjustmentLayer.adjustment?.kind == .photoFilter)
        #expect(settings.photoFilterPreset == .custom)
        #expect(settings.photoFilterDensity == 0.60)
        #expect(!settings.photoFilterPreserveLuminosity)
        #expect(settings.photoFilterCustomRed == 0.10)
        #expect(settings.photoFilterCustomGreen == 0.30)
        #expect(settings.photoFilterCustomBlue == 1.0)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(preview.blueComponent > preview.redComponent + 0.30)
        #expect(preview.blueComponent > preview.greenComponent + 0.20)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerAdjustmentNew"))
    }

    @Test func imageEditorColorLookupAdjustmentSupportsPresetsAndLayerState() async throws {
        let canvasSize = NSSize(width: 80, height: 40)
        let sourceImage = bitmapImage(size: canvasSize, background: .black)
        let layerImage = bitmapImage(
            size: canvasSize,
            background: NSColor(calibratedRed: 0.45, green: 0.43, blue: 0.41, alpha: 1)
        )
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))

        viewModel.selectedAdjustment = .colorLookup
        viewModel.selectedColorLookupPreset = .crispWarm
        viewModel.applyAdjustment()

        let warmed = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 20, y: 20))?.usingColorSpace(.deviceRGB))
        #expect(warmed.redComponent > warmed.blueComponent + 0.09)
        #expect(warmed.greenComponent > warmed.blueComponent + 0.04)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.adjustment.colorLookup"))

        viewModel.undo()
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        viewModel.selectedAdjustment = .colorLookup
        viewModel.selectedColorLookupPreset = .moonlight
        viewModel.addAdjustmentLayer()

        let adjustmentLayer = try #require(viewModel.document.selectedLayer)
        let settings = adjustmentLayer.adjustmentSettings.normalized()
        let preview = try #require(viewModel.currentImage.color(at: CGPoint(x: 20, y: 20))?.usingColorSpace(.deviceRGB))

        #expect(adjustmentLayer.adjustment?.kind == .colorLookup)
        #expect(settings.colorLookupPreset == .moonlight)
        #expect(viewModel.selectedLayerGeometryText == L10n.format("imageEditor.properties.colorLookupLayerValue", ImageEditorColorLookupPreset.moonlight.title))
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(preview.blueComponent > preview.redComponent + 0.13)
        #expect(preview.greenComponent > preview.redComponent + 0.02)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerAdjustmentNew"))
    }

    @Test func imageEditorColorLookupAdjustmentImportsCubeLUTAndPersistsLayerState() async throws {
        let cubeText = """
        TITLE "Swap RB"
        LUT_3D_SIZE 2
        0 0 0
        1 0 0
        0 1 0
        1 1 0
        0 0 1
        1 0 1
        0 1 1
        1 1 1
        """
        let canvasSize = NSSize(width: 80, height: 40)
        let sourceImage = bitmapImage(size: canvasSize, background: .black)
        let layerImage = bitmapImage(size: canvasSize, background: NSColor(calibratedRed: 0.20, green: 0.40, blue: 0.80, alpha: 1))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))

        #expect(viewModel.importColorLookupCube(name: "Swap RB", contents: cubeText))
        #expect(viewModel.selectedAdjustment == .colorLookup)
        #expect(viewModel.selectedColorLookupPreset == .customCube)
        #expect(viewModel.selectedColorLookupCube.name == "Swap RB")
        #expect(viewModel.selectedColorLookupCube.dimension == 2)
        let original = try #require(
            viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 20, y: 20))?
                .usingColorSpace(.deviceRGB)
        )
        viewModel.applyAdjustment()

        let swapped = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 20, y: 20))?.usingColorSpace(.deviceRGB))
        #expect(swapped.redComponent > 0.74)
        #expect(swapped.blueComponent < 0.26)
        #expect(abs(swapped.greenComponent - original.greenComponent) < 0.04)

        viewModel.undo()
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        #expect(viewModel.importColorLookupCube(name: "Swap RB", contents: cubeText))
        viewModel.addAdjustmentLayer()

        let adjustmentLayer = try #require(viewModel.document.selectedLayer)
        let settings = adjustmentLayer.adjustmentSettings.normalized()
        let preview = try #require(viewModel.currentImage.color(at: CGPoint(x: 20, y: 20))?.usingColorSpace(.deviceRGB))

        #expect(adjustmentLayer.adjustment?.kind == .colorLookup)
        #expect(settings.colorLookupPreset == .customCube)
        #expect(settings.colorLookupCube.name == "Swap RB")
        #expect(settings.colorLookupCube.dimension == 2)
        #expect(settings.colorLookupCube.values.count == 24)
        #expect(viewModel.selectedLayerGeometryText == L10n.format("imageEditor.properties.colorLookupLayerValue", "Swap RB"))
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(preview.redComponent > 0.74)
        #expect(preview.blueComponent < 0.26)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerAdjustmentNew"))
    }

    @Test func imageEditorChannelMixerAdjustmentSupportsRGBMatrixAndMonochromeLayerState() async throws {
        let canvasSize = NSSize(width: 90, height: 60)
        let sourceImage = bitmapImage(size: canvasSize, background: .black)
        let layerImage = bitmapImage(
            size: canvasSize,
            background: .clear,
            fills: [
                (CGRect(x: 0, y: 0, width: 30, height: 60), NSColor(calibratedRed: 1, green: 0, blue: 0, alpha: 1)),
                (CGRect(x: 30, y: 0, width: 30, height: 60), NSColor(calibratedRed: 0, green: 1, blue: 0, alpha: 1)),
                (CGRect(x: 60, y: 0, width: 30, height: 60), NSColor(calibratedRed: 0, green: 0, blue: 1, alpha: 1))
            ]
        )
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))

        viewModel.selectedAdjustment = .channelMixer
        viewModel.channelMixerRedRed = 0
        viewModel.channelMixerRedGreen = 1
        viewModel.applyAdjustment()

        let shiftedRed = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 15, y: 30))?.usingColorSpace(.deviceRGB))
        let shiftedGreen = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 45, y: 30))?.usingColorSpace(.deviceRGB))

        #expect(shiftedRed.redComponent < 0.05)
        #expect(shiftedRed.greenComponent < 0.05)
        #expect(shiftedGreen.redComponent > 0.90)
        #expect(shiftedGreen.greenComponent > 0.90)
        #expect(shiftedGreen.blueComponent < 0.05)

        viewModel.undo()
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        viewModel.selectedAdjustment = .channelMixer
        viewModel.channelMixerMonochrome = true
        viewModel.channelMixerMonoRed = 1.20
        viewModel.channelMixerMonoGreen = 0.45
        viewModel.channelMixerMonoBlue = 0.10
        viewModel.channelMixerMonoConstant = 0
        viewModel.addAdjustmentLayer()

        let adjustmentLayer = try #require(viewModel.document.selectedLayer)
        let settings = adjustmentLayer.adjustmentSettings.normalized()
        let previewRed = try #require(viewModel.currentImage.color(at: CGPoint(x: 15, y: 30))?.usingColorSpace(.deviceRGB))
        let previewGreen = try #require(viewModel.currentImage.color(at: CGPoint(x: 45, y: 30))?.usingColorSpace(.deviceRGB))
        let previewBlue = try #require(viewModel.currentImage.color(at: CGPoint(x: 75, y: 30))?.usingColorSpace(.deviceRGB))

        #expect(adjustmentLayer.adjustment?.kind == .channelMixer)
        #expect(settings.channelMixerMonochrome)
        #expect(settings.channelMixerMonoRed == 1.20)
        #expect(settings.channelMixerMonoGreen == 0.45)
        #expect(settings.channelMixerMonoBlue == 0.10)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(abs(previewRed.redComponent - previewRed.greenComponent) < 0.02)
        #expect(previewRed.redComponent > previewGreen.redComponent + 0.30)
        #expect(previewGreen.redComponent > previewBlue.redComponent + 0.25)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerAdjustmentNew"))
    }

    @Test func imageEditorHueSaturationAdjustmentSupportsColorizeAndLayerState() async throws {
        let canvasSize = NSSize(width: 80, height: 40)
        let sourceImage = bitmapImage(size: canvasSize, background: .black)
        let layerImage = bitmapImage(
            size: canvasSize,
            background: .clear,
            fills: [
                (CGRect(x: 0, y: 0, width: 40, height: 40), NSColor(calibratedRed: 1, green: 0, blue: 0, alpha: 1)),
                (CGRect(x: 40, y: 0, width: 40, height: 40), NSColor(calibratedRed: 0, green: 1, blue: 0, alpha: 1))
            ]
        )
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))

        viewModel.selectedAdjustment = .hueSaturation
        viewModel.hueSaturationHue = 120
        viewModel.applyAdjustment()

        let shiftedRed = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 20, y: 20))?.usingColorSpace(.deviceRGB))
        #expect(shiftedRed.greenComponent > shiftedRed.redComponent + 0.45)
        #expect(shiftedRed.greenComponent > shiftedRed.blueComponent + 0.45)

        viewModel.undo()
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        viewModel.selectedAdjustment = .hueSaturation
        viewModel.hueSaturationHue = -120
        viewModel.hueSaturationSaturation = 0.60
        viewModel.hueSaturationLightness = 0.10
        viewModel.hueSaturationColorize = true
        viewModel.addAdjustmentLayer()

        let adjustmentLayer = try #require(viewModel.document.selectedLayer)
        let settings = adjustmentLayer.adjustmentSettings.normalized()
        let previewLeft = try #require(viewModel.currentImage.color(at: CGPoint(x: 20, y: 20))?.usingColorSpace(.deviceRGB))
        let previewRight = try #require(viewModel.currentImage.color(at: CGPoint(x: 60, y: 20))?.usingColorSpace(.deviceRGB))

        #expect(adjustmentLayer.adjustment?.kind == .hueSaturation)
        #expect(settings.hueSaturationHue == -120)
        #expect(settings.hueSaturationSaturation == 0.60)
        #expect(settings.hueSaturationLightness == 0.10)
        #expect(settings.hueSaturationColorize)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(previewLeft.blueComponent > previewLeft.redComponent + 0.30)
        #expect(previewRight.blueComponent > previewRight.greenComponent + 0.30)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerAdjustmentNew"))
    }

    @Test func imageEditorBlackWhiteAdjustmentSupportsSixChannelMixAndLayerState() async throws {
        let canvasSize = NSSize(width: 90, height: 60)
        let sourceImage = bitmapImage(size: canvasSize, background: .black)
        let layerImage = bitmapImage(
            size: canvasSize,
            background: .clear,
            fills: [
                (CGRect(x: 0, y: 0, width: 30, height: 60), NSColor(calibratedRed: 1, green: 0, blue: 0, alpha: 1)),
                (CGRect(x: 30, y: 0, width: 30, height: 60), NSColor(calibratedRed: 0, green: 1, blue: 0, alpha: 1)),
                (CGRect(x: 60, y: 0, width: 30, height: 60), NSColor(calibratedRed: 0, green: 0, blue: 1, alpha: 1))
            ]
        )
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))

        viewModel.selectedAdjustment = .blackWhite
        viewModel.blackWhiteReds = 1.20
        viewModel.blackWhiteGreens = 0.50
        viewModel.blackWhiteBlues = 0.15
        viewModel.applyAdjustment()

        let redGray = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 15, y: 30))?.usingColorSpace(.deviceRGB))
        let greenGray = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 45, y: 30))?.usingColorSpace(.deviceRGB))
        let blueGray = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 75, y: 30))?.usingColorSpace(.deviceRGB))

        #expect(abs(redGray.redComponent - redGray.greenComponent) < 0.02)
        #expect(abs(greenGray.greenComponent - greenGray.blueComponent) < 0.02)
        #expect(redGray.redComponent > greenGray.redComponent + 0.25)
        #expect(greenGray.redComponent > blueGray.redComponent + 0.18)

        viewModel.undo()
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        viewModel.selectedAdjustment = .blackWhite
        viewModel.blackWhiteReds = 1.10
        viewModel.blackWhiteYellows = 0.70
        viewModel.blackWhiteGreens = 0.45
        viewModel.blackWhiteCyans = 0.65
        viewModel.blackWhiteBlues = 0.20
        viewModel.blackWhiteMagentas = 0.90
        viewModel.addAdjustmentLayer()

        let adjustmentLayer = try #require(viewModel.document.selectedLayer)
        let settings = adjustmentLayer.adjustmentSettings.normalized()
        let previewRed = try #require(viewModel.currentImage.color(at: CGPoint(x: 15, y: 30))?.usingColorSpace(.deviceRGB))
        let previewBlue = try #require(viewModel.currentImage.color(at: CGPoint(x: 75, y: 30))?.usingColorSpace(.deviceRGB))

        #expect(adjustmentLayer.adjustment?.kind == .blackWhite)
        #expect(settings.blackWhiteReds == 1.10)
        #expect(settings.blackWhiteYellows == 0.70)
        #expect(settings.blackWhiteGreens == 0.45)
        #expect(settings.blackWhiteCyans == 0.65)
        #expect(settings.blackWhiteBlues == 0.20)
        #expect(settings.blackWhiteMagentas == 0.90)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(abs(previewRed.redComponent - previewRed.blueComponent) < 0.03)
        #expect(previewRed.redComponent > previewBlue.redComponent + 0.25)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerAdjustmentNew"))
    }

    @Test func imageEditorBatchUpdatesSelectedAdjustmentLayersAndSkipsLockedOrIneligibleLayers() async throws {
        let canvasSize = NSSize(width: 48, height: 32)
        let sourceImage = bitmapImage(
            size: canvasSize,
            background: NSColor(calibratedRed: 0, green: 0, blue: 1, alpha: 1)
        )
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        let baseLayerID = try #require(viewModel.document.selectedLayerID)

        viewModel.selectedAdjustment = .brightnessContrast
        viewModel.adjustmentValue = 0.20
        viewModel.addAdjustmentLayer()
        let firstID = try #require(viewModel.document.selectedLayerID)

        viewModel.selectedAdjustment = .brightnessContrast
        viewModel.adjustmentValue = 0.30
        viewModel.addAdjustmentLayer()
        let secondID = try #require(viewModel.document.selectedLayerID)

        viewModel.selectedAdjustment = .brightnessContrast
        viewModel.adjustmentValue = 0.40
        viewModel.addAdjustmentLayer()
        let lockedID = try #require(viewModel.document.selectedLayerID)
        viewModel.toggleLayerLock(lockedID)

        viewModel.selectLayer(firstID)
        viewModel.selectLayer(secondID, extendingSelection: true)
        viewModel.selectLayer(lockedID, extendingSelection: true)
        viewModel.selectLayer(baseLayerID, extendingSelection: true)

        viewModel.selectedAdjustment = .hueSaturation
        viewModel.adjustmentValue = 0.65
        viewModel.hueSaturationHue = 45
        viewModel.hueSaturationSaturation = 0.25
        viewModel.hueSaturationLightness = -0.10
        viewModel.updateSelectedAdjustmentLayer()

        let first = try #require(layer(firstID, in: viewModel))
        let second = try #require(layer(secondID, in: viewModel))
        let locked = try #require(layer(lockedID, in: viewModel))
        let base = try #require(layer(baseLayerID, in: viewModel))

        #expect(first.adjustment?.kind == .hueSaturation)
        #expect(first.adjustment?.amount == 0.65)
        #expect(first.adjustmentSettings.normalized().hueSaturationHue == 45)
        #expect(first.adjustmentSettings.normalized().hueSaturationSaturation == 0.25)
        #expect(second.adjustment?.kind == .hueSaturation)
        #expect(second.adjustmentSettings.normalized().hueSaturationLightness == -0.10)
        #expect(locked.adjustment?.kind == .brightnessContrast)
        #expect(locked.adjustment?.amount == 0.40)
        #expect(!base.isAdjustment)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerAdjustmentUpdateSelected"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerAdjustmentUpdatedSelected", 2))

        viewModel.undo()

        #expect(try #require(layer(firstID, in: viewModel)).adjustment?.kind == .brightnessContrast)
        #expect(try #require(layer(firstID, in: viewModel)).adjustment?.amount == 0.20)
        #expect(try #require(layer(secondID, in: viewModel)).adjustment?.kind == .brightnessContrast)
        #expect(try #require(layer(secondID, in: viewModel)).adjustment?.amount == 0.30)
        #expect(try #require(layer(lockedID, in: viewModel)).adjustment?.amount == 0.40)
    }

    @Test func imageEditorBatchUpdatesSelectedSolidColorFillLayersAndSkipsLockedOrIneligibleLayers() async throws {
        let canvasSize = NSSize(width: 48, height: 32)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: bitmapImage(size: canvasSize, background: .black)) { _ in }
        let baseLayerID = try #require(viewModel.document.selectedLayerID)

        viewModel.solidColorFillRed = 0.10
        viewModel.solidColorFillGreen = 0.20
        viewModel.solidColorFillBlue = 0.30
        viewModel.addSolidColorFillLayer()
        let firstID = try #require(viewModel.document.selectedLayerID)

        viewModel.solidColorFillRed = 0.20
        viewModel.solidColorFillGreen = 0.30
        viewModel.solidColorFillBlue = 0.40
        viewModel.addSolidColorFillLayer()
        let secondID = try #require(viewModel.document.selectedLayerID)

        viewModel.solidColorFillRed = 0.30
        viewModel.solidColorFillGreen = 0.40
        viewModel.solidColorFillBlue = 0.50
        viewModel.addSolidColorFillLayer()
        let lockedID = try #require(viewModel.document.selectedLayerID)
        viewModel.toggleLayerLock(lockedID)

        viewModel.selectLayer(firstID)
        viewModel.selectLayer(secondID, extendingSelection: true)
        viewModel.selectLayer(lockedID, extendingSelection: true)
        viewModel.selectLayer(baseLayerID, extendingSelection: true)

        viewModel.solidColorFillRed = 0.80
        viewModel.solidColorFillGreen = 0.15
        viewModel.solidColorFillBlue = 0.05
        viewModel.updateSelectedSolidColorFillLayer()

        let first = try #require(layer(firstID, in: viewModel)?.solidColorFillContent?.normalized())
        let second = try #require(layer(secondID, in: viewModel)?.solidColorFillContent?.normalized())
        let locked = try #require(layer(lockedID, in: viewModel)?.solidColorFillContent?.normalized())
        #expect(first.red == 0.80)
        #expect(first.green == 0.15)
        #expect(first.blue == 0.05)
        #expect(second.red == 0.80)
        #expect(second.green == 0.15)
        #expect(second.blue == 0.05)
        #expect(locked.red == 0.30)
        #expect(locked.green == 0.40)
        #expect(locked.blue == 0.50)
        #expect(try #require(layer(baseLayerID, in: viewModel)).isSolidColorFill == false)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSolidColorFillUpdateSelected"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerSolidColorFillUpdatedSelected", 2))

        viewModel.undo()

        #expect(try #require(layer(firstID, in: viewModel)?.solidColorFillContent?.normalized()).red == 0.10)
        #expect(try #require(layer(secondID, in: viewModel)?.solidColorFillContent?.normalized()).red == 0.20)
        #expect(try #require(layer(lockedID, in: viewModel)?.solidColorFillContent?.normalized()).red == 0.30)
    }

    @Test func imageEditorBatchUpdatesSelectedPatternFillLayersAndSkipsLockedOrIneligibleLayers() async throws {
        let canvasSize = NSSize(width: 48, height: 32)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: bitmapImage(size: canvasSize, background: .black)) { _ in }
        let baseLayerID = try #require(viewModel.document.selectedLayerID)

        viewModel.selectedPatternFillKind = .checkerboard
        viewModel.patternFillOpacity = 0.20
        viewModel.patternFillScale = 10
        viewModel.addPatternFillLayer()
        let firstID = try #require(viewModel.document.selectedLayerID)

        viewModel.selectedPatternFillKind = .dots
        viewModel.patternFillOpacity = 0.30
        viewModel.patternFillScale = 12
        viewModel.addPatternFillLayer()
        let secondID = try #require(viewModel.document.selectedLayerID)

        viewModel.selectedPatternFillKind = .diagonalStripes
        viewModel.patternFillOpacity = 0.40
        viewModel.patternFillScale = 14
        viewModel.addPatternFillLayer()
        let lockedID = try #require(viewModel.document.selectedLayerID)
        viewModel.toggleLayerLock(lockedID)

        viewModel.selectLayer(firstID)
        viewModel.selectLayer(secondID, extendingSelection: true)
        viewModel.selectLayer(lockedID, extendingSelection: true)
        viewModel.selectLayer(baseLayerID, extendingSelection: true)

        viewModel.selectedPatternFillKind = .diagonalStripes
        viewModel.patternFillRed = 0.70
        viewModel.patternFillGreen = 0.10
        viewModel.patternFillBlue = 0.80
        viewModel.patternFillOpacity = 0.65
        viewModel.patternFillScale = 22
        viewModel.patternFillOffsetX = -17
        viewModel.patternFillOffsetY = 23
        viewModel.updateSelectedPatternFillLayer()

        let first = try #require(layer(firstID, in: viewModel)?.patternFillContent?.normalized())
        let second = try #require(layer(secondID, in: viewModel)?.patternFillContent?.normalized())
        let locked = try #require(layer(lockedID, in: viewModel)?.patternFillContent?.normalized())
        #expect(first.kind == .diagonalStripes)
        #expect(first.red == 0.70)
        #expect(first.opacity == 0.65)
        #expect(first.scale == 22)
        #expect(first.offsetX == -17)
        #expect(first.offsetY == 23)
        #expect(second.kind == .diagonalStripes)
        #expect(second.blue == 0.80)
        #expect(second.scale == 22)
        #expect(second.offsetX == -17)
        #expect(second.offsetY == 23)
        #expect(locked.kind == .diagonalStripes)
        #expect(locked.opacity == 0.40)
        #expect(locked.scale == 14)
        #expect(locked.offsetX == 0)
        #expect(locked.offsetY == 0)
        #expect(try #require(layer(baseLayerID, in: viewModel)).isPatternFill == false)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerPatternFillUpdateSelected"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerPatternFillUpdatedSelected", 2))

        viewModel.undo()

        #expect(try #require(layer(firstID, in: viewModel)?.patternFillContent?.normalized()).kind == .checkerboard)
        #expect(try #require(layer(secondID, in: viewModel)?.patternFillContent?.normalized()).kind == .dots)
        #expect(try #require(layer(lockedID, in: viewModel)?.patternFillContent?.normalized()).opacity == 0.40)
    }

    @Test func imageEditorBatchUpdatesSelectedGradientFillLayersAndSkipsLockedOrIneligibleLayers() async throws {
        let canvasSize = NSSize(width: 48, height: 32)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: bitmapImage(size: canvasSize, background: .black)) { _ in }
        let baseLayerID = try #require(viewModel.document.selectedLayerID)

        viewModel.selectedGradientFillPreset = .blackWhite
        viewModel.selectedGradientFillStyle = .linear
        viewModel.gradientFillScale = 1
        viewModel.addGradientFillLayer()
        let firstID = try #require(viewModel.document.selectedLayerID)

        viewModel.selectedGradientFillPreset = .sunset
        viewModel.selectedGradientFillStyle = .radial
        viewModel.gradientFillScale = 1.25
        viewModel.addGradientFillLayer()
        let secondID = try #require(viewModel.document.selectedLayerID)

        viewModel.selectedGradientFillPreset = .purpleTeal
        viewModel.selectedGradientFillStyle = .diamond
        viewModel.gradientFillScale = 1.5
        viewModel.addGradientFillLayer()
        let lockedID = try #require(viewModel.document.selectedLayerID)
        viewModel.toggleLayerLock(lockedID)

        viewModel.selectLayer(firstID)
        viewModel.selectLayer(secondID, extendingSelection: true)
        viewModel.selectLayer(lockedID, extendingSelection: true)
        viewModel.selectLayer(baseLayerID, extendingSelection: true)

        viewModel.selectedGradientFillPreset = .custom
        viewModel.selectedGradientFillStyle = .reflected
        viewModel.gradientFillReverse = true
        viewModel.gradientFillAngle = 35
        viewModel.gradientFillScale = 2
        viewModel.gradientFillStartRed = 0.90
        viewModel.gradientFillStartGreen = 0.10
        viewModel.gradientFillStartBlue = 0.20
        viewModel.gradientFillEndRed = 0.05
        viewModel.gradientFillEndGreen = 0.65
        viewModel.gradientFillEndBlue = 0.95
        viewModel.updateSelectedGradientFillLayer()

        let first = try #require(layer(firstID, in: viewModel)?.gradientFillContent?.normalized())
        let second = try #require(layer(secondID, in: viewModel)?.gradientFillContent?.normalized())
        let locked = try #require(layer(lockedID, in: viewModel)?.gradientFillContent?.normalized())
        #expect(first.preset == .custom)
        #expect(first.style == .reflected)
        #expect(first.reverse)
        #expect(first.angle == 35)
        #expect(first.scale == 2)
        #expect(first.startRed == 0.90)
        #expect(second.preset == .custom)
        #expect(second.style == .reflected)
        #expect(second.endBlue == 0.95)
        #expect(locked.preset == .purpleTeal)
        #expect(locked.style == .diamond)
        #expect(locked.scale == 1.5)
        #expect(try #require(layer(baseLayerID, in: viewModel)).isGradientFill == false)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerGradientFillUpdateSelected"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerGradientFillUpdatedSelected", 2))

        viewModel.undo()

        #expect(try #require(layer(firstID, in: viewModel)?.gradientFillContent?.normalized()).preset == .blackWhite)
        #expect(try #require(layer(secondID, in: viewModel)?.gradientFillContent?.normalized()).preset == .sunset)
        #expect(try #require(layer(lockedID, in: viewModel)?.gradientFillContent?.normalized()).preset == .purpleTeal)
    }

    private func bitmapImage(
        size: NSSize,
        background: NSColor,
        fills: [(rect: CGRect, color: NSColor)] = []
    ) -> NSImage {
        let width = Int(size.width.rounded())
        let height = Int(size.height.rounded())
        let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        guard let representation,
              let bitmapData = representation.bitmapData
        else { return NSImage(size: size) }

        for y in 0..<height {
            for x in 0..<width {
                let point = CGPoint(x: CGFloat(x) + 0.5, y: CGFloat(y) + 0.5)
                let fill = fills.last { item in
                    item.rect.contains(point)
                }
                let color = ((fill?.color ?? background).usingColorSpace(.genericRGB) ?? .clear)
                let alpha = max(0, min(1, color.alphaComponent))
                let offset = y * representation.bytesPerRow + x * 4
                bitmapData[offset] = UInt8((max(0, min(1, color.redComponent)) * alpha * 255).rounded())
                bitmapData[offset + 1] = UInt8((max(0, min(1, color.greenComponent)) * alpha * 255).rounded())
                bitmapData[offset + 2] = UInt8((max(0, min(1, color.blueComponent)) * alpha * 255).rounded())
                bitmapData[offset + 3] = UInt8((alpha * 255).rounded())
            }
        }

        representation.size = size
        let image = NSImage(size: size)
        image.addRepresentation(representation)
        return image
    }

    private func editableRasterViewModel(image: NSImage) -> ImageEditorViewModel {
        let normalized = image.normalizedBitmapImage()
        var document = ImageEditorDocument(sourceName: "equalize.png", image: normalized)
        if let index = document.selectedLayerIndex {
            document.layers[index].image = normalized
            document.layers[index].frame = CGRect(origin: .zero, size: normalized.size)
            document.layers[index].isLocked = false
            document.layers[index].locksPixels = false
            document.layers[index].locksPosition = false
            document.layers[index].locksTransparentPixels = false
        }
        for index in document.layers.indices where document.layers[index].id != document.selectedLayerID {
            document.layers[index].isVisible = false
        }
        return ImageEditorViewModel(document: document, initialCompositeImage: normalized) { _ in }
    }

    @Test func zeroAmountAdjustmentPreservesHistoryAndPixels() throws {
        let canvasSize = NSSize(width: 24, height: 24)
        let sourceImage = bitmapImage(
            size: canvasSize,
            background: NSColor(calibratedRed: 0.4, green: 0.5, blue: 0.6, alpha: 1)
        )
        let viewModel = ImageEditorViewModel(sourceName: "adjustment-noop.png", image: sourceImage) { _ in }
        viewModel.selectedAdjustment = .brightness
        viewModel.adjustmentValue = 0
        let beforePixels = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let beforeHistory = viewModel.document.history
        let beforeUndoCount = viewModel.undoStack.count

        viewModel.applyAdjustment()

        #expect(viewModel.document.selectedLayer?.image.qingtuPNGData() == beforePixels)
        #expect(viewModel.document.history == beforeHistory)
        #expect(viewModel.undoStack.count == beforeUndoCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.adjustmentUnchanged"))
    }

    private func saturation(of color: NSColor) -> CGFloat {
        let red = color.redComponent
        let green = color.greenComponent
        let blue = color.blueComponent
        let maximum = max(red, green, blue)
        let minimum = min(red, green, blue)
        let lightness = (maximum + minimum) / 2
        guard maximum > minimum else { return 0 }
        if lightness > 0.5 {
            return (maximum - minimum) / max(0.0001, 2 - maximum - minimum)
        }
        return (maximum - minimum) / max(0.0001, maximum + minimum)
    }

    private func layer(_ id: UUID, in viewModel: ImageEditorViewModel) -> ImageEditorLayer? {
        viewModel.document.layers.first { $0.id == id }
    }
}
