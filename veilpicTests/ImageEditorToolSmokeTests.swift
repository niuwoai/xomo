//
//  ImageEditorToolSmokeTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/11.
//

import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorToolSmokeTests {
    @Test func sampledRetouchZeroOpacitySkipsHistoryForEverySampledTool() throws {
        let operations: [(String, (ImageEditorViewModel) -> Void)] = [
            ("clone", { viewModel in
                viewModel.setCloneSource(at: CGPoint(x: 8, y: 14))
                viewModel.cloneStamp(points: [CGPoint(x: 22, y: 14), CGPoint(x: 28, y: 14)])
            }),
            ("burn", { viewModel in
                viewModel.toneBrush(
                    points: [CGPoint(x: 10, y: 14), CGPoint(x: 30, y: 14)],
                    burn: true
                )
            }),
            ("sponge", { viewModel in
                viewModel.spongeBrush(points: [CGPoint(x: 10, y: 14), CGPoint(x: 30, y: 14)])
            }),
            ("blur", { viewModel in
                viewModel.blurBrush(points: [CGPoint(x: 10, y: 14), CGPoint(x: 30, y: 14)])
            }),
            ("sharpen", { viewModel in
                viewModel.sharpenBrush(points: [CGPoint(x: 10, y: 14), CGPoint(x: 30, y: 14)])
            }),
            ("smudge", { viewModel in
                viewModel.smudgeBrush(points: [CGPoint(x: 10, y: 14), CGPoint(x: 30, y: 14)])
            }),
            ("spot healing", { viewModel in
                viewModel.healingBrushMode = .spot
                viewModel.healingBrush(points: [CGPoint(x: 20, y: 14)])
            }),
            ("source healing", { viewModel in
                viewModel.setHealingSource(at: CGPoint(x: 8, y: 14))
                viewModel.healingBrush(points: [CGPoint(x: 20, y: 14)])
            })
        ]

        for (_, operation) in operations {
            let viewModel = makeEditableViewModel(image: verticalEdgeImage())
            viewModel.brushSize = 12
            viewModel.opacity = 0
            let beforePixels = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
            let beforeHistory = viewModel.document.history.count
            let beforeUndo = viewModel.undoStack.count

            operation(viewModel)

            #expect(
                viewModel.document.selectedLayer?.image.qingtuPNGData() == beforePixels,
                "(name) changed pixels at zero opacity"
            )
            #expect(viewModel.document.history.count == beforeHistory, "(name) added history")
            #expect(viewModel.undoStack.count == beforeUndo, "(name) added undo")
            #expect(
                viewModel.statusText == L10n.text("imageEditor.status.retouchUnchanged"),
                "(name) overwrote the no-change status"
            )
        }
    }

    @Test func lassoCreatesAUsablePolygonSelection() throws {
        let viewModel = makeViewModel(image: solidImage(color: .systemBlue))

        viewModel.createLassoSelection(points: [
            CGPoint(x: 4, y: 4),
            CGPoint(x: 30, y: 5),
            CGPoint(x: 24, y: 22),
            CGPoint(x: 6, y: 20),
        ])

        let selection = try #require(viewModel.document.selection)
        #expect(selection.isPolygon)
        #expect(selection.contains(CGPoint(x: 15, y: 12)))
        #expect(!selection.contains(CGPoint(x: 36, y: 25)))
    }

    @Test func quickSelectionCombinesSampledColorRegions() throws {
        let image = NSImage.rendered(size: canvasSize) { rect in
            NSColor.systemRed.setFill()
            CGRect(x: rect.minX, y: rect.minY, width: rect.width / 2, height: rect.height).fill()
            NSColor.systemBlue.setFill()
            CGRect(x: rect.midX, y: rect.minY, width: rect.width / 2, height: rect.height).fill()
        } ?? NSImage.transparent(size: canvasSize)
        let viewModel = makeViewModel(image: image)
        viewModel.tolerance = 0.05
        viewModel.brushSize = 4

        viewModel.createQuickSelection(points: [CGPoint(x: 5, y: 14), CGPoint(x: 35, y: 14)])

        let selection = try #require(viewModel.document.selection)
        #expect(selection.contains(CGPoint(x: 5, y: 14)))
        #expect(selection.contains(CGPoint(x: 35, y: 14)))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.quickSelection"))
    }

    @Test func quickSelectionSamplesTheEntireLongStrokeWithinItsAnalysisBudget() throws {
        let canvasSize = CGSize(width: 480, height: 28)
        let samplePoints = (0..<24).map { index in
            CGPoint(x: CGFloat(index * 20 + 5), y: 14)
        }
        let image = NSImage.rendered(size: canvasSize) { rect in
            NSColor.systemBlue.setFill()
            rect.fill()
            NSColor.systemRed.setFill()
            for index in 0..<24 {
                CGRect(x: CGFloat(index * 20), y: 0, width: 10, height: rect.height).fill()
            }
        } ?? NSImage.transparent(size: canvasSize)
        let viewModel = ImageEditorViewModel(sourceName: "long-quick-selection.png", image: image) { _ in }
        viewModel.brushSize = 4
        viewModel.tolerance = 0.05

        #expect(viewModel.createQuickSelection(points: samplePoints))

        let selection = try #require(viewModel.document.selection)
        let firstSample = try #require(samplePoints.first)
        let lastSample = try #require(samplePoints.last)
        #expect(selection.contains(firstSample))
        #expect(selection.contains(lastSample))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.quickSelection"))
    }

    @Test func quickSelectionSamplingUsesStrokeDistanceInsteadOfEventDensity() throws {
        let unevenlySpacedPoints = stride(from: 0, through: 100, by: 5).map { value in
            CGPoint(x: CGFloat(value), y: 10)
        } + [CGPoint(x: 200, y: 10), CGPoint(x: 300, y: 10), CGPoint(x: 400, y: 10)]

        let samples = ImageEditorQuickSelectionSampling.points(
            from: unevenlySpacedPoints,
            within: CGRect(x: 0, y: 0, width: 480, height: 28),
            minimumDistance: 1,
            maximumCount: 4
        )

        #expect(samples.count == 4)
        let first = try #require(samples.first)
        let second = try #require(samples.dropFirst().first)
        let third = try #require(samples.dropFirst(2).first)
        let last = try #require(samples.last)
        #expect(first.x == 0)
        #expect(abs(second.x - (400.0 / 3.0)) < 0.01)
        #expect(abs(third.x - (800.0 / 3.0)) < 0.01)
        #expect(last.x == 400)
    }

    @Test func spongeIncreasesLocalColorSaturation() throws {
        let muted = NSColor(deviceRed: 0.58, green: 0.50, blue: 0.42, alpha: 1)
        let viewModel = makeEditableViewModel(image: solidImage(color: muted))
        viewModel.brushSize = 12
        viewModel.opacity = 1
        let before = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 20, y: 14))?.usingColorSpace(.deviceRGB))

        viewModel.spongeBrush(points: [CGPoint(x: 10, y: 14), CGPoint(x: 30, y: 14)])

        let after = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 20, y: 14))?.usingColorSpace(.deviceRGB))
        #expect((after.redComponent - after.blueComponent) > (before.redComponent - before.blueComponent))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.sponge"))
    }

    @Test func spongeDesaturateModePullsLocalColorTowardGray() throws {
        let color = NSColor(deviceRed: 0.72, green: 0.43, blue: 0.18, alpha: 1)
        let viewModel = makeEditableViewModel(image: solidImage(color: color))
        viewModel.spongeMode = .desaturate
        viewModel.brushSize = 12
        viewModel.opacity = 1
        let point = CGPoint(x: 20, y: 14)
        let before = try #require(
            viewModel.document.selectedLayer?.image.color(at: point)?.usingColorSpace(.deviceRGB)
        )

        viewModel.spongeBrush(points: [CGPoint(x: 10, y: 14), CGPoint(x: 30, y: 14)])

        let after = try #require(
            viewModel.document.selectedLayer?.image.color(at: point)?.usingColorSpace(.deviceRGB)
        )
        let beforeRange = before.redComponent - before.blueComponent
        let afterRange = after.redComponent - after.blueComponent
        #expect(afterRange < beforeRange * 0.35)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.sponge"))
    }

    @Test func spongeHardnessControlsTheVisibleStrokeEdge() throws {
        let color = NSColor(deviceRed: 0.64, green: 0.46, blue: 0.24, alpha: 1)
        let soft = makeEditableViewModel(image: solidImage(color: color))
        let hard = makeEditableViewModel(image: solidImage(color: color))
        for viewModel in [soft, hard] {
            viewModel.spongeMode = .saturate
            viewModel.brushSize = 12
            viewModel.opacity = 1
        }
        soft.hardness = 0
        hard.hardness = 1
        let points = [CGPoint(x: 10, y: 14), CGPoint(x: 30, y: 14)]

        soft.spongeBrush(points: points)
        hard.spongeBrush(points: points)

        let edgePoint = CGPoint(x: 20, y: 18)
        let softEdge = try #require(
            soft.document.selectedLayer?.image.color(at: edgePoint)?.usingColorSpace(.deviceRGB)
        )
        let hardEdge = try #require(
            hard.document.selectedLayer?.image.color(at: edgePoint)?.usingColorSpace(.deviceRGB)
        )
        let softRange = softEdge.redComponent - softEdge.blueComponent
        let hardRange = hardEdge.redComponent - hardEdge.blueComponent
        #expect(hardRange > softRange + 0.06)
        #expect(soft.document.history.last?.title == L10n.text("imageEditor.history.sponge"))
        #expect(hard.document.history.last?.title == L10n.text("imageEditor.history.sponge"))
    }

    @Test func spongeSingleClickAppliesBothSaturationModes() throws {
        let color = NSColor(deviceRed: 0.68, green: 0.45, blue: 0.22, alpha: 1)
        let saturate = makeEditableViewModel(image: solidImage(color: color))
        let desaturate = makeEditableViewModel(image: solidImage(color: color))
        saturate.spongeMode = .saturate
        desaturate.spongeMode = .desaturate
        for viewModel in [saturate, desaturate] {
            viewModel.brushSize = 12
            viewModel.hardness = 1
            viewModel.opacity = 1
        }
        let point = CGPoint(x: 20, y: 14)
        let before = try #require(
            saturate.document.selectedLayer?.image.color(at: point)?.usingColorSpace(.deviceRGB)
        )

        saturate.spongeBrush(points: [point])
        desaturate.spongeBrush(points: [point])

        let saturated = try #require(
            saturate.document.selectedLayer?.image.color(at: point)?.usingColorSpace(.deviceRGB)
        )
        let desaturated = try #require(
            desaturate.document.selectedLayer?.image.color(at: point)?.usingColorSpace(.deviceRGB)
        )
        let beforeRange = before.redComponent - before.blueComponent
        #expect(saturated.redComponent - saturated.blueComponent > beforeRange)
        #expect(desaturated.redComponent - desaturated.blueComponent < beforeRange * 0.35)
        #expect(saturate.document.history.last?.title == L10n.text("imageEditor.history.sponge"))
        #expect(desaturate.document.history.last?.title == L10n.text("imageEditor.history.sponge"))
    }

    @Test func spongeVibranceReducesSaturationEndpointClipping() throws {
        let color = NSColor(deviceRed: 0.95, green: 0.45, blue: 0.05, alpha: 1)
        let protected = makeEditableViewModel(image: solidImage(color: color))
        let unprotected = makeEditableViewModel(image: solidImage(color: color))
        for viewModel in [protected, unprotected] {
            viewModel.spongeMode = .saturate
            viewModel.brushSize = 12
            viewModel.hardness = 1
            viewModel.opacity = 1
        }
        unprotected.spongeVibranceEnabled = false
        let point = CGPoint(x: 20, y: 14)

        protected.spongeBrush(points: [point])
        unprotected.spongeBrush(points: [point])

        let protectedColor = try #require(
            protected.document.selectedLayer?.image.color(at: point)?.usingColorSpace(.deviceRGB)
        )
        let unprotectedColor = try #require(
            unprotected.document.selectedLayer?.image.color(at: point)?.usingColorSpace(.deviceRGB)
        )
        #expect(protected.spongeVibranceEnabled)
        #expect(protectedColor.redComponent < unprotectedColor.redComponent - 0.005)
        #expect(protectedColor.blueComponent > unprotectedColor.blueComponent + 0.003)
        #expect(protected.document.history.last?.title == L10n.text("imageEditor.history.sponge"))
    }

    @Test func spongeVibranceKeepsNearGrayChromaFromFlattening() throws {
        let color = NSColor(deviceRed: 0.53, green: 0.50, blue: 0.47, alpha: 1)
        let protected = makeEditableViewModel(image: solidImage(color: color))
        let unprotected = makeEditableViewModel(image: solidImage(color: color))
        for viewModel in [protected, unprotected] {
            viewModel.spongeMode = .desaturate
            viewModel.brushSize = 12
            viewModel.hardness = 1
            viewModel.opacity = 1
        }
        unprotected.spongeVibranceEnabled = false
        let point = CGPoint(x: 20, y: 14)

        protected.spongeBrush(points: [point])
        unprotected.spongeBrush(points: [point])

        let protectedColor = try #require(
            protected.document.selectedLayer?.image.color(at: point)?.usingColorSpace(.deviceRGB)
        )
        let unprotectedColor = try #require(
            unprotected.document.selectedLayer?.image.color(at: point)?.usingColorSpace(.deviceRGB)
        )
        let protectedChroma = protectedColor.redComponent - protectedColor.blueComponent
        let unprotectedChroma = unprotectedColor.redComponent - unprotectedColor.blueComponent
        #expect(protectedChroma > unprotectedChroma + 0.03)
        #expect(unprotected.document.history.last?.title == L10n.text("imageEditor.history.sponge"))
    }

    @Test func spongeFlowControlsPixelEffect() throws {
        let color = NSColor(deviceRed: 0.62, green: 0.48, blue: 0.32, alpha: 1)
        let low = makeEditableViewModel(image: solidImage(color: color))
        let high = makeEditableViewModel(image: solidImage(color: color))
        for viewModel in [low, high] {
            viewModel.spongeMode = .saturate
            viewModel.spongeVibranceEnabled = false
            viewModel.brushSize = 12
            viewModel.hardness = 1
        }
        low.opacity = 0.20
        high.opacity = 1
        let point = CGPoint(x: 20, y: 14)

        low.spongeBrush(points: [point])
        high.spongeBrush(points: [point])

        let lowColor = try #require(
            low.document.selectedLayer?.image.color(at: point)?.usingColorSpace(.deviceRGB)
        )
        let highColor = try #require(
            high.document.selectedLayer?.image.color(at: point)?.usingColorSpace(.deviceRGB)
        )
        let lowChroma = lowColor.redComponent - lowColor.blueComponent
        let highChroma = highColor.redComponent - highColor.blueComponent
        #expect(highChroma > lowChroma + 0.15)
        #expect(low.document.history.last?.title == L10n.text("imageEditor.history.sponge"))
        #expect(high.document.history.last?.title == L10n.text("imageEditor.history.sponge"))
    }

    @Test func spongePressureControlsBrushDiameterWithoutChangingMouseStrokes() throws {
        let color = NSColor(deviceRed: 0.62, green: 0.48, blue: 0.32, alpha: 1)
        let lightPressure = makeEditableViewModel(image: solidImage(color: color))
        let fullPressure = makeEditableViewModel(image: solidImage(color: color))
        for viewModel in [lightPressure, fullPressure] {
            viewModel.spongeMode = .saturate
            viewModel.spongeVibranceEnabled = false
            viewModel.brushSize = 20
            viewModel.hardness = 1
            viewModel.opacity = 1
            viewModel.setBrushPressureControlsSize(true)
            viewModel.setBrushPressureSensitivity(50)
        }
        let center = CGPoint(x: 20, y: 14)
        let edge = CGPoint(x: 27, y: 14)

        lightPressure.spongeBrush(samples: [
            ImageEditorBrushStrokeSample(point: center, pressure: 0.1)
        ])
        fullPressure.spongeBrush(samples: [
            ImageEditorBrushStrokeSample(point: center, pressure: 1)
        ])

        let lightEdge = try #require(
            lightPressure.document.selectedLayer?.image.color(at: edge)?.usingColorSpace(.deviceRGB)
        )
        let fullEdge = try #require(
            fullPressure.document.selectedLayer?.image.color(at: edge)?.usingColorSpace(.deviceRGB)
        )
        let lightChroma = lightEdge.redComponent - lightEdge.blueComponent
        let fullChroma = fullEdge.redComponent - fullEdge.blueComponent
        #expect(fullChroma > lightChroma + 0.12)
        #expect(lightPressure.document.history.last?.title == L10n.text("imageEditor.history.sponge"))
        #expect(fullPressure.document.history.last?.title == L10n.text("imageEditor.history.sponge"))
    }

    @Test func toneBrushHardnessControlsDodgeAndBurnEdges() throws {
        let image = solidImage(color: NSColor(deviceWhite: 0.45, alpha: 1))
        let softDodge = makeEditableViewModel(image: image)
        let hardDodge = makeEditableViewModel(image: image)
        let softBurn = makeEditableViewModel(image: image)
        let hardBurn = makeEditableViewModel(image: image)
        for viewModel in [softDodge, hardDodge, softBurn, hardBurn] {
            viewModel.brushSize = 12
            viewModel.opacity = 1
        }
        softDodge.hardness = 0
        softBurn.hardness = 0
        hardDodge.hardness = 1
        hardBurn.hardness = 1
        let points = [CGPoint(x: 10, y: 14), CGPoint(x: 30, y: 14)]

        softDodge.toneBrush(points: points, burn: false)
        hardDodge.toneBrush(points: points, burn: false)
        softBurn.toneBrush(points: points, burn: true)
        hardBurn.toneBrush(points: points, burn: true)

        let edgePoint = CGPoint(x: 20, y: 18)
        let softDodgeEdge = try #require(
            softDodge.document.selectedLayer?.image.color(at: edgePoint)?.usingColorSpace(.deviceRGB)
        )
        let hardDodgeEdge = try #require(
            hardDodge.document.selectedLayer?.image.color(at: edgePoint)?.usingColorSpace(.deviceRGB)
        )
        let softBurnEdge = try #require(
            softBurn.document.selectedLayer?.image.color(at: edgePoint)?.usingColorSpace(.deviceRGB)
        )
        let hardBurnEdge = try #require(
            hardBurn.document.selectedLayer?.image.color(at: edgePoint)?.usingColorSpace(.deviceRGB)
        )
        #expect(hardDodgeEdge.redComponent > softDodgeEdge.redComponent + 0.15)
        #expect(hardBurnEdge.redComponent < softBurnEdge.redComponent - 0.12)
        #expect(hardDodge.document.history.last?.title == L10n.text("imageEditor.history.dodge"))
        #expect(hardBurn.document.history.last?.title == L10n.text("imageEditor.history.burn"))
    }

    @Test func retouchPressureControlsDodgeAndBurnDiameterWithoutChangingExposure() throws {
        let image = solidImage(color: NSColor(deviceWhite: 0.45, alpha: 1))
        let lightDodge = makeEditableViewModel(image: image)
        let fullDodge = makeEditableViewModel(image: image)
        let lightBurn = makeEditableViewModel(image: image)
        let fullBurn = makeEditableViewModel(image: image)
        for viewModel in [lightDodge, fullDodge, lightBurn, fullBurn] {
            viewModel.brushSize = 20
            viewModel.hardness = 1
            viewModel.opacity = 1
            viewModel.setRetouchPressureControlsSize(true)
            viewModel.setRetouchPressureSensitivity(50)
        }
        let center = CGPoint(x: 20, y: 14)
        let edge = CGPoint(x: 27, y: 14)
        let lightSample = [ImageEditorBrushStrokeSample(point: center, pressure: 0.1)]
        let fullSample = [ImageEditorBrushStrokeSample(point: center, pressure: 1)]

        lightDodge.toneBrush(samples: lightSample, burn: false)
        fullDodge.toneBrush(samples: fullSample, burn: false)
        lightBurn.toneBrush(samples: lightSample, burn: true)
        fullBurn.toneBrush(samples: fullSample, burn: true)

        #expect(try redComponent(in: fullDodge, at: edge) > redComponent(in: lightDodge, at: edge) + 0.15)
        #expect(try redComponent(in: fullBurn, at: edge) < redComponent(in: lightBurn, at: edge) - 0.12)
        #expect(try redComponent(in: lightDodge, at: center) > 0.65)
        #expect(try redComponent(in: lightBurn, at: center) < 0.30)
        #expect(fullDodge.document.history.last?.title == L10n.text("imageEditor.history.dodge"))
        #expect(fullBurn.document.history.last?.title == L10n.text("imageEditor.history.burn"))
    }

    @Test func toneBrushSingleClickAppliesDodgeAndBurnDabs() throws {
        let image = solidImage(color: NSColor(deviceWhite: 0.45, alpha: 1))
        let dodge = makeEditableViewModel(image: image)
        let burn = makeEditableViewModel(image: image)
        for viewModel in [dodge, burn] {
            viewModel.brushSize = 12
            viewModel.hardness = 1
            viewModel.opacity = 1
        }
        let point = CGPoint(x: 20, y: 14)
        let before = try #require(
            dodge.document.selectedLayer?.image.color(at: point)?.usingColorSpace(.deviceRGB)
        )

        dodge.toneBrush(points: [point], burn: false)
        burn.toneBrush(points: [point], burn: true)

        let dodged = try #require(
            dodge.document.selectedLayer?.image.color(at: point)?.usingColorSpace(.deviceRGB)
        )
        let burned = try #require(
            burn.document.selectedLayer?.image.color(at: point)?.usingColorSpace(.deviceRGB)
        )
        #expect(dodged.redComponent > before.redComponent + 0.25)
        #expect(burned.redComponent < before.redComponent - 0.20)
        #expect(dodge.document.history.last?.title == L10n.text("imageEditor.history.dodge"))
        #expect(burn.document.history.last?.title == L10n.text("imageEditor.history.burn"))
    }

    @Test func dodgeExposureControlsPixelEffect() throws {
        let image = solidImage(color: NSColor(deviceWhite: 0.45, alpha: 1))
        let low = makeConfiguredRetouchViewModel(image: image)
        let high = makeConfiguredRetouchViewModel(image: image)
        low.opacity = 0.20
        high.opacity = 1
        let point = CGPoint(x: 20, y: 14)

        low.toneBrush(points: [point], burn: false)
        high.toneBrush(points: [point], burn: false)

        let lowExposure = try redComponent(in: low, at: point)
        let highExposure = try redComponent(in: high, at: point)
        #expect(highExposure > lowExposure + 0.25)
        #expect(low.document.history.last?.title == L10n.text("imageEditor.history.dodge"))
        #expect(high.document.history.last?.title == L10n.text("imageEditor.history.dodge"))
    }

    @Test func burnExposureControlsPixelEffect() throws {
        let image = solidImage(color: NSColor(deviceWhite: 0.45, alpha: 1))
        let low = makeConfiguredRetouchViewModel(image: image)
        let high = makeConfiguredRetouchViewModel(image: image)
        low.opacity = 0.20
        high.opacity = 1
        let point = CGPoint(x: 20, y: 14)

        low.toneBrush(points: [point], burn: true)
        high.toneBrush(points: [point], burn: true)

        let lowExposure = try redComponent(in: low, at: point)
        let highExposure = try redComponent(in: high, at: point)
        #expect(highExposure < lowExposure - 0.20)
        #expect(low.document.history.last?.title == L10n.text("imageEditor.history.burn"))
        #expect(high.document.history.last?.title == L10n.text("imageEditor.history.burn"))
    }

    @Test func toneRangeSelectivelyTargetsShadowsMidtonesAndHighlights() throws {
        let image = tonalBandImage()
        let shadows = makeConfiguredRetouchViewModel(image: image)
        let midtones = makeConfiguredRetouchViewModel(image: image)
        let highlights = makeConfiguredRetouchViewModel(image: image)
        shadows.toneRange = .shadows
        midtones.toneRange = .midtones
        highlights.toneRange = .highlights
        for viewModel in [shadows, midtones, highlights] {
            viewModel.brushSize = 96
        }
        let point = CGPoint(x: 20, y: 14)
        let darkPoint = CGPoint(x: 6, y: 14)
        let middlePoint = CGPoint(x: 20, y: 14)
        let lightPoint = CGPoint(x: 34, y: 14)

        shadows.toneBrush(points: [point], burn: false)
        midtones.toneBrush(points: [point], burn: false)
        highlights.toneBrush(points: [point], burn: true)

        let shadowDarkDelta = try redComponent(in: shadows, at: darkPoint) - 0.15
        let shadowMiddleDelta = try redComponent(in: shadows, at: middlePoint) - 0.50
        let shadowLightDelta = try redComponent(in: shadows, at: lightPoint) - 0.85
        #expect(shadowDarkDelta > shadowMiddleDelta + 0.20)
        #expect(shadowMiddleDelta > shadowLightDelta + 0.05)

        let midtoneDarkDelta = try redComponent(in: midtones, at: darkPoint) - 0.15
        let midtoneMiddleDelta = try redComponent(in: midtones, at: middlePoint) - 0.50
        let midtoneLightDelta = try redComponent(in: midtones, at: lightPoint) - 0.85
        #expect(midtoneMiddleDelta > midtoneDarkDelta + 0.20)
        #expect(midtoneMiddleDelta > midtoneLightDelta + 0.25)

        let highlightDarkDelta = 0.15 - (try redComponent(in: highlights, at: darkPoint))
        let highlightMiddleDelta = 0.50 - (try redComponent(in: highlights, at: middlePoint))
        let highlightLightDelta = 0.85 - (try redComponent(in: highlights, at: lightPoint))
        #expect(highlightLightDelta > highlightMiddleDelta + 0.20)
        #expect(highlightMiddleDelta > highlightDarkDelta + 0.05)
        #expect(shadows.document.history.last?.title == L10n.text("imageEditor.history.dodge"))
        #expect(midtones.document.history.last?.title == L10n.text("imageEditor.history.dodge"))
        #expect(highlights.document.history.last?.title == L10n.text("imageEditor.history.burn"))
    }

    @Test func protectTonesPreservesChromaAndAvoidsEndpointClipping() throws {
        let saturated = solidImage(
            color: NSColor(deviceRed: 0.78, green: 0.32, blue: 0.12, alpha: 1)
        )
        let protectedColor = try applyingToneBrush(
            to: saturated,
            burn: false,
            range: .midtones,
            protectTones: true
        )
        let unprotectedColor = try applyingToneBrush(
            to: saturated,
            burn: false,
            range: .midtones,
            protectTones: false
        )
        let point = CGPoint(x: 20, y: 14)
        let protectedSample = try #require(
            protectedColor.color(at: point)?.usingColorSpace(.deviceRGB)
        )
        let unprotectedSample = try #require(
            unprotectedColor.color(at: point)?.usingColorSpace(.deviceRGB)
        )
        let protectedChroma = protectedSample.redComponent - protectedSample.blueComponent
        let unprotectedChroma = unprotectedSample.redComponent - unprotectedSample.blueComponent
        #expect(protectedChroma > unprotectedChroma + 0.12)

        let light = solidImage(color: NSColor(deviceWhite: 0.92, alpha: 1))
        let protectedLight = try applyingToneBrush(
            to: light,
            burn: false,
            range: .highlights,
            protectTones: true,
            repetitions: 10
        )
        let unprotectedLight = try applyingToneBrush(
            to: light,
            burn: false,
            range: .highlights,
            protectTones: false,
            repetitions: 10
        )
        #expect(try redComponent(in: protectedLight, at: point) < 0.999)
        #expect(try redComponent(in: unprotectedLight, at: point) > 0.999)

        let dark = solidImage(color: NSColor(deviceWhite: 0.08, alpha: 1))
        let protectedDark = try applyingToneBrush(
            to: dark,
            burn: true,
            range: .shadows,
            protectTones: true,
            repetitions: 10
        )
        let unprotectedDark = try applyingToneBrush(
            to: dark,
            burn: true,
            range: .shadows,
            protectTones: false,
            repetitions: 10
        )
        #expect(try redComponent(in: protectedDark, at: point) > 0.001)
        #expect(try redComponent(in: unprotectedDark, at: point) < 0.001)
        #expect(makeConfiguredRetouchViewModel(image: saturated).protectToneBrushTones)
    }

    @Test func blurAndSharpenHardnessControlTheVisibleStrokeEdge() throws {
        let hardEdge = NSImage.rendered(size: canvasSize) { rect in
            NSColor(deviceWhite: 0.35, alpha: 1).setFill()
            rect.fill()
            NSColor(deviceWhite: 0.65, alpha: 1).setFill()
            CGRect(x: rect.midX, y: rect.minY, width: rect.width / 2, height: rect.height).fill()
        } ?? NSImage.transparent(size: canvasSize)
        let softenedEdge = try #require(hardEdge.blurred(radius: 3))
        let softBlur = makeEditableViewModel(image: hardEdge)
        let hardBlur = makeEditableViewModel(image: hardEdge)
        let softSharpen = makeEditableViewModel(image: softenedEdge)
        let hardSharpen = makeEditableViewModel(image: softenedEdge)
        for viewModel in [softBlur, hardBlur, softSharpen, hardSharpen] {
            viewModel.brushSize = 12
            viewModel.opacity = 1
        }
        softBlur.hardness = 0
        softSharpen.hardness = 0
        hardBlur.hardness = 1
        hardSharpen.hardness = 1
        let points = [CGPoint(x: 10, y: 14), CGPoint(x: 30, y: 14)]
        let blurEdgePoint = CGPoint(x: 19, y: 18)
        let sharpenEdgePoint = CGPoint(x: 18, y: 18)
        let blurOriginal = try #require(
            hardEdge.color(at: blurEdgePoint)?.usingColorSpace(.deviceRGB)
        )
        let sharpenOriginal = try #require(
            softenedEdge.color(at: sharpenEdgePoint)?.usingColorSpace(.deviceRGB)
        )

        softBlur.blurBrush(points: points)
        hardBlur.blurBrush(points: points)
        softSharpen.sharpenBrush(points: points)
        hardSharpen.sharpenBrush(points: points)

        let softBlurEdge = try #require(
            softBlur.document.selectedLayer?.image.color(at: blurEdgePoint)?.usingColorSpace(.deviceRGB)
        )
        let hardBlurEdge = try #require(
            hardBlur.document.selectedLayer?.image.color(at: blurEdgePoint)?.usingColorSpace(.deviceRGB)
        )
        let softSharpenEdge = try #require(
            softSharpen.document.selectedLayer?.image.color(at: sharpenEdgePoint)?.usingColorSpace(.deviceRGB)
        )
        let hardSharpenEdge = try #require(
            hardSharpen.document.selectedLayer?.image.color(at: sharpenEdgePoint)?.usingColorSpace(.deviceRGB)
        )
        let softBlurDelta = abs(softBlurEdge.redComponent - blurOriginal.redComponent)
        let hardBlurDelta = abs(hardBlurEdge.redComponent - blurOriginal.redComponent)
        let softSharpenDelta = abs(softSharpenEdge.redComponent - sharpenOriginal.redComponent)
        let hardSharpenDelta = abs(hardSharpenEdge.redComponent - sharpenOriginal.redComponent)
        #expect(hardBlurDelta > softBlurDelta + 0.03)
        #expect(hardSharpenDelta > softSharpenDelta + 0.01)
        #expect(hardBlur.document.history.last?.title == L10n.text("imageEditor.history.blur"))
        #expect(hardSharpen.document.history.last?.title == L10n.text("imageEditor.history.sharpen"))
    }

    @Test func blurSingleClickAppliesACircularDab() throws {
        let hardEdge = verticalEdgeImage()
        let blur = makeConfiguredRetouchViewModel(image: hardEdge)
        let dabPoint = CGPoint(x: 20, y: 14)
        let darkPoint = CGPoint(x: 18, y: 14)
        let lightPoint = CGPoint(x: 22, y: 14)
        let farPoint = CGPoint(x: 4, y: 14)
        let beforeContrast = try colorContrast(in: hardEdge, darkPoint: darkPoint, lightPoint: lightPoint)
        let farBefore = try redComponent(in: hardEdge, at: farPoint)

        blur.blurBrush(points: [dabPoint])

        let afterContrast = try colorContrast(in: blur, darkPoint: darkPoint, lightPoint: lightPoint)
        let farAfter = try redComponent(in: blur, at: farPoint)
        #expect(afterContrast < beforeContrast - 0.15)
        #expect(abs(farAfter - farBefore) < 0.02)
        #expect(blur.document.history.last?.title == L10n.text("imageEditor.history.blur"))
    }

    @Test func sharpenSingleClickAppliesACircularDab() throws {
        let softenedEdge = try #require(verticalEdgeImage().blurred(radius: 4))
        let sharpen = makeConfiguredRetouchViewModel(image: softenedEdge)
        let dabPoint = CGPoint(x: 20, y: 14)
        let darkPoint = CGPoint(x: 18, y: 14)
        let lightPoint = CGPoint(x: 22, y: 14)
        let farPoint = CGPoint(x: 4, y: 14)
        let beforeContrast = try colorContrast(in: softenedEdge, darkPoint: darkPoint, lightPoint: lightPoint)
        let farBefore = try redComponent(in: softenedEdge, at: farPoint)

        sharpen.sharpenBrush(points: [dabPoint])

        let afterContrast = try colorContrast(in: sharpen, darkPoint: darkPoint, lightPoint: lightPoint)
        let farAfter = try redComponent(in: sharpen, at: farPoint)
        #expect(afterContrast > beforeContrast + 0.03)
        #expect(abs(farAfter - farBefore) < 0.02)
        #expect(sharpen.document.history.last?.title == L10n.text("imageEditor.history.sharpen"))
    }

    @Test func blurStrengthControlsPixelEffect() throws {
        let image = verticalEdgeImage()
        let low = makeConfiguredRetouchViewModel(image: image)
        let high = makeConfiguredRetouchViewModel(image: image)
        low.opacity = 0.20
        high.opacity = 1
        let darkPoint = CGPoint(x: 18, y: 14)
        let lightPoint = CGPoint(x: 22, y: 14)

        low.blurBrush(points: [CGPoint(x: 20, y: 14)])
        high.blurBrush(points: [CGPoint(x: 20, y: 14)])

        let lowContrast = try colorContrast(in: low, darkPoint: darkPoint, lightPoint: lightPoint)
        let highContrast = try colorContrast(in: high, darkPoint: darkPoint, lightPoint: lightPoint)
        #expect(highContrast < lowContrast - 0.15)
        #expect(low.document.history.last?.title == L10n.text("imageEditor.history.blur"))
        #expect(high.document.history.last?.title == L10n.text("imageEditor.history.blur"))
    }

    @Test func sharpenStrengthControlsPixelEffect() throws {
        let image = try #require(verticalEdgeImage().blurred(radius: 4))
        let low = makeConfiguredRetouchViewModel(image: image)
        let high = makeConfiguredRetouchViewModel(image: image)
        low.opacity = 0.20
        high.opacity = 1
        let darkPoint = CGPoint(x: 18, y: 14)
        let lightPoint = CGPoint(x: 22, y: 14)

        low.sharpenBrush(points: [CGPoint(x: 20, y: 14)])
        high.sharpenBrush(points: [CGPoint(x: 20, y: 14)])

        let lowContrast = try colorContrast(in: low, darkPoint: darkPoint, lightPoint: lightPoint)
        let highContrast = try colorContrast(in: high, darkPoint: darkPoint, lightPoint: lightPoint)
        #expect(highContrast > lowContrast + 0.03)
        #expect(low.document.history.last?.title == L10n.text("imageEditor.history.sharpen"))
        #expect(high.document.history.last?.title == L10n.text("imageEditor.history.sharpen"))
    }

    @Test func blurSharpenPressureControlsDiameterWithoutChangingMouseStrokes() throws {
        let edge = verticalEdgeImage()
        let softenedEdge = try #require(edge.blurred(radius: 4))
        let blurLight = makeConfiguredRetouchViewModel(image: edge)
        let blurFull = makeConfiguredRetouchViewModel(image: edge)
        let blurMouseBaseline = makeConfiguredRetouchViewModel(image: edge)
        let blurMousePressureEnabled = makeConfiguredRetouchViewModel(image: edge)
        let sharpenLight = makeConfiguredRetouchViewModel(image: softenedEdge)
        let sharpenFull = makeConfiguredRetouchViewModel(image: softenedEdge)
        for viewModel in [
            blurLight,
            blurFull,
            blurMouseBaseline,
            blurMousePressureEnabled,
            sharpenLight,
            sharpenFull
        ] {
            viewModel.brushSize = 16
            viewModel.hardness = 1
            viewModel.opacity = 1
        }
        blurLight.retouchPressureControlsSize = true
        blurFull.retouchPressureControlsSize = true
        blurMouseBaseline.retouchPressureControlsSize = false
        blurMousePressureEnabled.retouchPressureControlsSize = true
        sharpenLight.retouchPressureControlsSize = true
        sharpenFull.retouchPressureControlsSize = true
        let point = CGPoint(x: 20, y: 14)
        let lightSample = [ImageEditorBrushStrokeSample(point: point, pressure: 0.05)]
        let fullSample = [ImageEditorBrushStrokeSample(point: point, pressure: 1)]
        let mouseSample = [ImageEditorBrushStrokeSample(point: point)]

        blurLight.blurBrush(samples: lightSample)
        blurFull.blurBrush(samples: fullSample)
        blurMouseBaseline.blurBrush(samples: mouseSample)
        blurMousePressureEnabled.blurBrush(samples: mouseSample)
        sharpenLight.sharpenBrush(samples: lightSample)
        sharpenFull.sharpenBrush(samples: fullSample)

        let blurEdgePoint = CGPoint(x: 18, y: 19)
        let lightBlur = try redComponent(in: blurLight, at: blurEdgePoint)
        let fullBlur = try redComponent(in: blurFull, at: blurEdgePoint)
        #expect(fullBlur > lightBlur + 0.10)

        let baselineMouseBlur = try redComponent(in: blurMouseBaseline, at: blurEdgePoint)
        let pressureEnabledMouseBlur = try redComponent(
            in: blurMousePressureEnabled,
            at: blurEdgePoint
        )
        #expect(abs(baselineMouseBlur - pressureEnabledMouseBlur) < 0.001)

        let sharpenDarkPoint = CGPoint(x: 18, y: 19)
        let sharpenLightPoint = CGPoint(x: 22, y: 19)
        let initialSharpenContrast = try colorContrast(
            in: softenedEdge,
            darkPoint: sharpenDarkPoint,
            lightPoint: sharpenLightPoint
        )
        let lightSharpenContrast = try colorContrast(
            in: sharpenLight,
            darkPoint: sharpenDarkPoint,
            lightPoint: sharpenLightPoint
        )
        let fullSharpenContrast = try colorContrast(
            in: sharpenFull,
            darkPoint: sharpenDarkPoint,
            lightPoint: sharpenLightPoint
        )
        #expect(fullSharpenContrast > lightSharpenContrast + 0.02)
        #expect(blurFull.document.history.last?.title == L10n.text("imageEditor.history.blur"))
        #expect(sharpenFull.document.history.last?.title == L10n.text("imageEditor.history.sharpen"))
        sharpenFull.undo()
        let undoneContrast = try colorContrast(
            in: sharpenFull,
            darkPoint: sharpenDarkPoint,
            lightPoint: sharpenLightPoint
        )
        #expect(abs(undoneContrast - initialSharpenContrast) < 0.001)
    }

    @Test func smudgeHardnessControlsTheVisibleStrokeEdge() throws {
        let image = verticalEdgeImage()
        let soft = makeConfiguredRetouchViewModel(image: image)
        let hard = makeConfiguredRetouchViewModel(image: image)
        soft.brushSize = 12
        hard.brushSize = 12
        soft.hardness = 0
        hard.hardness = 1
        let points = [
            CGPoint(x: 12, y: 14),
            CGPoint(x: 20, y: 14),
            CGPoint(x: 28, y: 14)
        ]

        soft.smudgeBrush(points: points)
        hard.smudgeBrush(points: points)

        let edgePoint = CGPoint(x: 24, y: 18)
        let softEdge = try redComponent(in: soft, at: edgePoint)
        let hardEdge = try redComponent(in: hard, at: edgePoint)
        #expect(hardEdge < softEdge - 0.20)
        #expect(soft.document.history.last?.title == L10n.text("imageEditor.history.smudge"))
        #expect(hard.document.history.last?.title == L10n.text("imageEditor.history.smudge"))
    }

    @Test func smudgeStrengthControlsPixelDisplacement() throws {
        let image = verticalEdgeImage()
        let low = makeConfiguredRetouchViewModel(image: image)
        let high = makeConfiguredRetouchViewModel(image: image)
        low.brushSize = 12
        high.brushSize = 12
        low.opacity = 0.20
        high.opacity = 1
        let points = [
            CGPoint(x: 12, y: 14),
            CGPoint(x: 20, y: 14),
            CGPoint(x: 28, y: 14)
        ]

        low.smudgeBrush(points: points)
        high.smudgeBrush(points: points)

        let samplePoint = CGPoint(x: 24, y: 14)
        let lowStrength = try redComponent(in: low, at: samplePoint)
        let highStrength = try redComponent(in: high, at: samplePoint)
        #expect(highStrength < lowStrength - 0.35)
        #expect(low.document.history.last?.title == L10n.text("imageEditor.history.smudge"))
        #expect(high.document.history.last?.title == L10n.text("imageEditor.history.smudge"))
    }

    @Test func smudgePressureControlsDiameterWithoutChangingMouseStrokes() throws {
        let image = solidImage(color: NSColor(deviceWhite: 0.45, alpha: 1))
        let lightPressure = makeConfiguredRetouchViewModel(image: image)
        let fullPressure = makeConfiguredRetouchViewModel(image: image)
        let mouseBaseline = makeConfiguredRetouchViewModel(image: image)
        let mouseWithPressureEnabled = makeConfiguredRetouchViewModel(image: image)
        for viewModel in [lightPressure, fullPressure, mouseBaseline, mouseWithPressureEnabled] {
            viewModel.brushSize = 16
            viewModel.hardness = 1
            viewModel.opacity = 1
            viewModel.foregroundColor = NSColor(deviceRed: 1, green: 0.05, blue: 0.05, alpha: 1)
            viewModel.smudgeFingerPaintingEnabled = true
        }
        lightPressure.retouchPressureControlsSize = true
        fullPressure.retouchPressureControlsSize = true
        mouseBaseline.retouchPressureControlsSize = false
        mouseWithPressureEnabled.retouchPressureControlsSize = true
        let points = [CGPoint(x: 8, y: 14), CGPoint(x: 16, y: 14), CGPoint(x: 24, y: 14)]
        let lightSamples = points.map {
            ImageEditorBrushStrokeSample(point: $0, pressure: 0.05)
        }
        let fullSamples = points.map {
            ImageEditorBrushStrokeSample(point: $0, pressure: 1)
        }
        let mouseSamples = points.map { ImageEditorBrushStrokeSample(point: $0) }

        lightPressure.smudgeBrush(samples: lightSamples)
        fullPressure.smudgeBrush(samples: fullSamples)
        mouseBaseline.smudgeBrush(samples: mouseSamples)
        mouseWithPressureEnabled.smudgeBrush(samples: mouseSamples)

        let outsideLightDiameter = try #require(
            lightPressure.document.selectedLayer?.image.color(at: CGPoint(x: 22, y: 19))?
                .usingColorSpace(.deviceRGB)
        )
        let insideFullDiameter = try #require(
            fullPressure.document.selectedLayer?.image.color(at: CGPoint(x: 22, y: 19))?
                .usingColorSpace(.deviceRGB)
        )
        #expect(insideFullDiameter.redComponent > outsideLightDiameter.redComponent + 0.25)
        #expect(insideFullDiameter.redComponent > insideFullDiameter.greenComponent + 0.25)

        let baselineMouseColor = try #require(
            mouseBaseline.document.selectedLayer?.image.color(at: CGPoint(x: 22, y: 19))?
                .usingColorSpace(.deviceRGB)
        )
        let pressureEnabledMouseColor = try #require(
            mouseWithPressureEnabled.document.selectedLayer?.image.color(at: CGPoint(x: 22, y: 19))?
                .usingColorSpace(.deviceRGB)
        )
        #expect(abs(baselineMouseColor.redComponent - pressureEnabledMouseColor.redComponent) < 0.001)
        #expect(abs(baselineMouseColor.greenComponent - pressureEnabledMouseColor.greenComponent) < 0.001)
        #expect(fullPressure.document.history.last?.title == L10n.text("imageEditor.history.smudge"))
        fullPressure.undo()
        let undone = try #require(
            fullPressure.document.selectedLayer?.image.color(at: CGPoint(x: 22, y: 19))?
                .usingColorSpace(.deviceRGB)
        )
        #expect(abs(undone.redComponent - undone.greenComponent) < 0.02)
    }

    @Test func fingerPaintingCarriesForegroundColorAlongTheSmudgeStroke() throws {
        let image = solidImage(color: NSColor(deviceWhite: 0.45, alpha: 1))
        let ordinary = makeConfiguredRetouchViewModel(image: image)
        let fingerPainting = makeConfiguredRetouchViewModel(image: image)
        for viewModel in [ordinary, fingerPainting] {
            viewModel.brushSize = 12
            viewModel.hardness = 1
            viewModel.opacity = 1
            viewModel.foregroundColor = NSColor(deviceRed: 1, green: 0.05, blue: 0.05, alpha: 1)
        }
        fingerPainting.smudgeFingerPaintingEnabled = true
        let points = [
            CGPoint(x: 8, y: 14),
            CGPoint(x: 16, y: 14),
            CGPoint(x: 24, y: 14)
        ]

        ordinary.smudgeBrush(points: points)
        fingerPainting.smudgeBrush(points: points)

        let ordinaryColor = try #require(
            ordinary.document.selectedLayer?.image.color(at: CGPoint(x: 23, y: 14))?
                .usingColorSpace(.deviceRGB)
        )
        let paintedColor = try #require(
            fingerPainting.document.selectedLayer?.image.color(at: CGPoint(x: 23, y: 14))?
                .usingColorSpace(.deviceRGB)
        )
        #expect(abs(ordinaryColor.redComponent - ordinaryColor.greenComponent) < 0.02)
        #expect(paintedColor.redComponent > paintedColor.greenComponent + 0.25)
        #expect(paintedColor.redComponent > ordinaryColor.redComponent + 0.20)
        #expect(fingerPainting.document.history.last?.title == L10n.text("imageEditor.history.smudge"))
    }

    @Test func sampleAllLayersSmudgesVisiblePixelsOnlyIntoTheActiveLayer() throws {
        func makeLayeredViewModel() -> ImageEditorViewModel {
            let bottomImage = NSImage.rendered(size: canvasSize) { rect in
                NSColor.systemBlue.setFill()
                rect.fill()
                NSColor.systemRed.setFill()
                CGRect(x: 7, y: 10, width: 7, height: 8).fill()
            } ?? NSImage.transparent(size: canvasSize)
            var document = ImageEditorDocument(sourceName: "Smudge Layers", image: bottomImage)
            let editLayer = ImageEditorLayer.blank(name: "Smudge", size: canvasSize)
            document.layers = [document.layers[0], editLayer]
            document.selectedLayerID = editLayer.id
            document.selectedLayerIDs = [editLayer.id]
            return ImageEditorViewModel(document: document, onApply: { _ in })
        }

        let currentLayerOnly = makeLayeredViewModel()
        let allLayers = makeLayeredViewModel()
        for viewModel in [currentLayerOnly, allLayers] {
            viewModel.brushSize = 8
            viewModel.hardness = 1
            viewModel.opacity = 1
        }
        allLayers.smudgeSampleAllLayersEnabled = true
        let points = [CGPoint(x: 10, y: 14), CGPoint(x: 20, y: 14)]

        currentLayerOnly.smudgeBrush(points: points)
        allLayers.smudgeBrush(points: points)

        let currentOnlyPixel = try #require(
            currentLayerOnly.document.selectedLayer?.image.color(at: CGPoint(x: 19, y: 14))?
                .usingColorSpace(.deviceRGB)
        )
        let sampledPixel = try #require(
            allLayers.document.selectedLayer?.image.color(at: CGPoint(x: 19, y: 14))?
                .usingColorSpace(.deviceRGB)
        )
        let untouchedPixel = try #require(
            allLayers.document.selectedLayer?.image.color(at: CGPoint(x: 34, y: 4))?
                .usingColorSpace(.deviceRGB)
        )
        let unchangedBottom = try #require(
            allLayers.document.layers[0].image.color(at: CGPoint(x: 10, y: 14))?
                .usingColorSpace(.deviceRGB)
        )
        #expect(currentOnlyPixel.alphaComponent < 0.05)
        #expect(sampledPixel.redComponent > sampledPixel.blueComponent + 0.25)
        #expect(untouchedPixel.alphaComponent < 0.05)
        #expect(unchangedBottom.redComponent > unchangedBottom.blueComponent + 0.25)
        #expect(allLayers.document.history.last?.title == L10n.text("imageEditor.history.smudge"))

        allLayers.undo()
        let undonePixel = try #require(
            allLayers.document.selectedLayer?.image.color(at: CGPoint(x: 19, y: 14))?
                .usingColorSpace(.deviceRGB)
        )
        #expect(undonePixel.alphaComponent < 0.05)
        allLayers.redo()
        let redonePixel = try #require(
            allLayers.document.selectedLayer?.image.color(at: CGPoint(x: 19, y: 14))?
                .usingColorSpace(.deviceRGB)
        )
        #expect(redonePixel.redComponent > redonePixel.blueComponent + 0.25)
    }

    @Test func redEyeToolReducesExcessRedAtTheClickedPupil() throws {
        let image = NSImage.rendered(size: canvasSize) { rect in
            NSColor(deviceWhite: 0.35, alpha: 1).setFill()
            rect.fill()
            NSColor(deviceRed: 1, green: 0.05, blue: 0.05, alpha: 1).setFill()
            CGRect(x: 16, y: 10, width: 8, height: 8).fill()
        } ?? NSImage.transparent(size: canvasSize)
        let viewModel = makeEditableViewModel(image: image)
        viewModel.brushSize = 10
        viewModel.opacity = 1
        let before = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 20, y: 14))?.usingColorSpace(.deviceRGB))

        viewModel.reduceRedEye(at: CGPoint(x: 20, y: 14))

        let after = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 20, y: 14))?.usingColorSpace(.deviceRGB))
        #expect(after.redComponent < before.redComponent)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.redEye"))
    }

    @Test func redEyeToolSkipsHistoryWhenNoRedPixelsChange() throws {
        let image = NSImage.rendered(size: canvasSize) { rect in
            NSColor(deviceWhite: 0.35, alpha: 1).setFill()
            rect.fill()
        } ?? NSImage.transparent(size: canvasSize)
        let viewModel = makeEditableViewModel(image: image)
        viewModel.brushSize = 10
        viewModel.opacity = 1
        let historyBefore = viewModel.document.history
        let undoCountBefore = viewModel.undoStack.count

        viewModel.reduceRedEye(at: CGPoint(x: 20, y: 14))

        #expect(viewModel.document.history == historyBefore)
        #expect(viewModel.undoStack.count == undoCountBefore)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.retouchUnchanged"))
    }

    @Test func shapeToolUsesTheCanvasTopLeftCoordinateSystem() throws {
        let viewModel = makeViewModel(image: NSImage.transparent(size: canvasSize))
        viewModel.foregroundColor = .systemRed

        viewModel.drawShape(from: CGPoint(x: 4, y: 3), to: CGPoint(x: 18, y: 11), ellipse: false)

        let topShapeColor = try #require(viewModel.currentImage.color(at: CGPoint(x: 11, y: 7))?.usingColorSpace(NSColorSpace.deviceRGB))
        let mirroredLocationColor = try #require(viewModel.currentImage.color(at: CGPoint(x: 11, y: 21))?.usingColorSpace(NSColorSpace.deviceRGB))
        #expect(topShapeColor.redComponent > 0.8)
        #expect(mirroredLocationColor.alphaComponent < 0.1)
    }

    @Test func eyedropperAndColorSamplerReadCanvasPixels() throws {
        let image = solidImage(color: .magenta)
        let viewModel = makeViewModel(image: image)

        viewModel.sampleColor(at: CGPoint(x: 20, y: 14))
        let foreground = try #require(viewModel.foregroundColor.usingColorSpace(NSColorSpace.deviceRGB))
        #expect(foreground.redComponent > 0.8)
        #expect(foreground.blueComponent > 0.8)

        #expect(viewModel.addColorSampler(at: CGPoint(x: 20, y: 14)))
        let sample = try #require(viewModel.colorSamplerPoints.last)
        let sampledColor = try #require(sample.color.usingColorSpace(NSColorSpace.deviceRGB))
        #expect(sampledColor.redComponent > 0.8)
        #expect(sampledColor.blueComponent > 0.8)
        let infoText = viewModel.colorSamplerInfoText(index: 0, sample: sample)
        #expect(infoText.contains("X 20"))
        #expect(infoText.contains("Y 14"))
        #expect(infoText.contains("R 255"))
        #expect(infoText.contains("B 255"))
        #expect(infoText.contains("A 255"))
        let readoutSample = ImageEditorColorSamplerPoint(
            point: sample.point,
            color: NSColor(deviceRed: 1, green: 0, blue: 1, alpha: 1)
        )
        let hsbInfoText = viewModel.colorSamplerInfoText(
            index: 0,
            sample: readoutSample,
            mode: .hsb
        )
        #expect(hsbInfoText.contains("H 300°"))
        #expect(hsbInfoText.contains("S 100%"))
        #expect(hsbInfoText.contains("B 100%"))
        let cmykInfoText = viewModel.colorSamplerInfoText(
            index: 0,
            sample: readoutSample,
            mode: .cmyk
        )
        #expect(cmykInfoText.contains("C 0%"))
        #expect(cmykInfoText.contains("M 100%"))
        #expect(cmykInfoText.contains("Y 0%"))
        #expect(cmykInfoText.contains("K 0%"))
        let blackCMYK = ImageEditorColorSamplerReading(color: .black)
        #expect(blackCMYK.cyanPercent == 0)
        #expect(blackCMYK.magentaPercent == 0)
        #expect(blackCMYK.yellowPercent == 0)
        #expect(blackCMYK.keyPercent == 100)
        let wrappedHueReading = ImageEditorColorSamplerReading(
            color: NSColor(
                deviceHue: 0.999,
                saturation: 1,
                brightness: 1,
                alpha: 1
            )
        )
        #expect(wrappedHueReading.hueDegrees == 0)
        viewModel.selectedColorSamplerReadoutMode = .hexadecimal
        let hexadecimalInfoText = viewModel.colorSamplerInfoText(
            index: 0,
            sample: readoutSample
        )
        #expect(hexadecimalInfoText.contains("#FF00FFFF"))
        let sampleID = sample.id

        viewModel.replaceSelectedLayerImageForTesting(
            solidImage(color: .green),
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        var refreshedSample = try #require(viewModel.colorSamplerPoints.last)
        var refreshedColor = try #require(
            refreshedSample.color.usingColorSpace(NSColorSpace.deviceRGB)
        )
        #expect(refreshedSample.id == sampleID)
        #expect(refreshedColor.greenComponent > 0.8)
        #expect(refreshedColor.greenComponent > refreshedColor.redComponent + 0.5)

        viewModel.undo()
        refreshedSample = try #require(viewModel.colorSamplerPoints.last)
        refreshedColor = try #require(
            refreshedSample.color.usingColorSpace(NSColorSpace.deviceRGB)
        )
        #expect(refreshedSample.id == sampleID)
        #expect(refreshedColor.redComponent > 0.8)
        #expect(refreshedColor.blueComponent > 0.8)

        viewModel.redo()
        refreshedSample = try #require(viewModel.colorSamplerPoints.last)
        refreshedColor = try #require(
            refreshedSample.color.usingColorSpace(NSColorSpace.deviceRGB)
        )
        #expect(refreshedSample.id == sampleID)
        #expect(refreshedColor.greenComponent > 0.8)
        #expect(refreshedColor.greenComponent > refreshedColor.redComponent + 0.5)
        #expect(viewModel.clearColorSamplers() == 1)
        #expect(viewModel.colorSamplerPoints.isEmpty)
        #expect(viewModel.clearColorSamplers() == 0)
    }

    @Test func eyedropperCanSampleBackgroundWithoutChangingForegroundOrHistory() throws {
        let viewModel = makeViewModel(image: solidImage(color: .magenta))
        viewModel.foregroundColor = .cyan
        viewModel.backgroundColor = .yellow
        let originalForeground = try #require(
            viewModel.foregroundColor.usingColorSpace(.deviceRGB)
        )
        let originalHistory = viewModel.document.history
        let originalCanUndo = viewModel.canUndo

        viewModel.sampleColor(
            at: CGPoint(x: 20, y: 14),
            target: .background
        )

        let foreground = try #require(
            viewModel.foregroundColor.usingColorSpace(.deviceRGB)
        )
        let background = try #require(
            viewModel.backgroundColor.usingColorSpace(.deviceRGB)
        )
        #expect(abs(foreground.redComponent - originalForeground.redComponent) < 0.001)
        #expect(abs(foreground.greenComponent - originalForeground.greenComponent) < 0.001)
        #expect(abs(foreground.blueComponent - originalForeground.blueComponent) < 0.001)
        #expect(background.redComponent > 0.8)
        #expect(background.blueComponent > 0.8)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.colorSampledBackground"))
        #expect(viewModel.document.history == originalHistory)
        #expect(viewModel.canUndo == originalCanUndo)
    }

    @Test func colorSamplerMoveAndRemoveAreAtomicAndHistoryFree() throws {
        let image = try #require(NSImage.rendered(size: canvasSize) { rect in
            NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1).setFill()
            CGRect(
                x: rect.minX,
                y: rect.minY,
                width: rect.width / 2,
                height: rect.height
            ).fill()
            NSColor(deviceRed: 0, green: 0, blue: 1, alpha: 1).setFill()
            CGRect(
                x: rect.midX,
                y: rect.minY,
                width: rect.width / 2,
                height: rect.height
            ).fill()
        })
        let viewModel = makeViewModel(image: image)
        let historyCount = viewModel.document.history.count
        viewModel.selectColorSamplerSampleSize(.oneByOne)
        #expect(viewModel.addColorSampler(at: CGPoint(x: 8, y: 12)))
        let originalSample = try #require(viewModel.colorSamplerPoints.first)
        let originalColor = try #require(
            originalSample.color.usingColorSpace(.deviceRGB)
        )
        #expect(originalColor.redComponent > 0.8)
        #expect(originalColor.blueComponent < 0.2)

        #expect(viewModel.moveColorSampler(
            id: originalSample.id,
            to: CGPoint(x: 38, y: 12)
        ))
        let movedSample = try #require(viewModel.colorSamplerPoints.first)
        let movedColor = try #require(
            movedSample.color.usingColorSpace(.deviceRGB)
        )
        #expect(movedSample.id == originalSample.id)
        #expect(movedSample.point == CGPoint(x: 38, y: 12))
        #expect(movedColor.blueComponent > 0.8)
        #expect(movedColor.redComponent < 0.2)
        #expect(viewModel.document.history.count == historyCount)

        #expect(!viewModel.moveColorSampler(
            id: originalSample.id,
            to: CGPoint(x: -1, y: 12)
        ))
        #expect(viewModel.colorSamplerPoints.first?.point == CGPoint(x: 38, y: 12))
        #expect(viewModel.document.history.count == historyCount)

        let removedSample = try #require(
            viewModel.removeColorSampler(id: originalSample.id)
        )
        #expect(removedSample.id == originalSample.id)
        #expect(viewModel.colorSamplerPoints.isEmpty)
        #expect(viewModel.removeColorSampler(id: originalSample.id) == nil)
        #expect(viewModel.document.history.count == historyCount)
    }

    @Test func pointerReadoutTracksCurrentCanvasPixelAndClearsOutside() throws {
        let red = NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1)
        let viewModel = makeViewModel(image: solidImage(color: red))
        let initialHistoryCount = viewModel.document.history.count

        #expect(viewModel.pointerCanvasPoint == nil)
        #expect(viewModel.pointerText.contains("—"))
        #expect(viewModel.pointerColorInfoText.contains("—"))

        viewModel.updatePointer(CGPoint(x: 20.8, y: 14.9))

        #expect(viewModel.pointerCanvasPoint == CGPoint(x: 20, y: 14))
        #expect(viewModel.pointerText.contains("X: 20"))
        #expect(viewModel.pointerText.contains("Y: 14"))
        #expect(viewModel.pointerColorInfoText.contains("R 255"))
        #expect(viewModel.pointerColorInfoText.contains("G 0"))
        #expect(viewModel.pointerColorInfoText.contains("A 255"))
        #expect(viewModel.document.history.count == initialHistoryCount)

        viewModel.selectedColorSamplerReadoutMode = .hsb
        #expect(viewModel.pointerColorInfoText.contains("H 0°"))
        #expect(viewModel.pointerColorInfoText.contains("S 100%"))
        #expect(viewModel.pointerColorInfoText.contains("B 100%"))

        viewModel.selectedColorSamplerReadoutMode = .cmyk
        #expect(viewModel.pointerColorInfoText.contains("C 0%"))
        #expect(viewModel.pointerColorInfoText.contains("M 100%"))
        #expect(viewModel.pointerColorInfoText.contains("Y 100%"))
        #expect(viewModel.pointerColorInfoText.contains("K 0%"))

        viewModel.selectedColorSamplerReadoutMode = .hexadecimal
        #expect(viewModel.pointerColorInfoText.contains("#FF0000FF"))

        let blue = NSColor(deviceRed: 0, green: 0, blue: 1, alpha: 1)
        viewModel.replaceSelectedLayerImageForTesting(
            solidImage(color: blue),
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        #expect(viewModel.pointerColorInfoText.contains("#0000FFFF"))
        let historyCountAfterReplacement = viewModel.document.history.count

        viewModel.updatePointer(CGPoint(x: canvasSize.width, y: 14))

        #expect(viewModel.pointerCanvasPoint == nil)
        #expect(viewModel.pointerText.contains("—"))
        #expect(!viewModel.pointerColorInfoText.contains("#0000FFFF"))
        #expect(viewModel.document.history.count == historyCountAfterReplacement)
    }

    @Test func colorSamplerSampleSizeControlsPointerAndPlacedSamples() throws {
        let width = Int(canvasSize.width)
        let height = Int(canvasSize.height)
        let bytesPerPixel = 4
        var pixels = [UInt8](
            repeating: 0,
            count: width * height * bytesPerPixel
        )
        for pixelOffset in stride(
            from: 0,
            to: pixels.count,
            by: bytesPerPixel
        ) {
            pixels[pixelOffset + 3] = 255
        }
        let whitePixelOffset = (14 * width + 20) * bytesPerPixel
        for componentOffset in 0..<bytesPerPixel {
            pixels[whitePixelOffset + componentOffset] = 255
        }
        let provider = try #require(
            CGDataProvider(data: Data(pixels) as CFData)
        )
        let cgImage = try #require(CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: bytesPerPixel * 8,
            bytesPerRow: width * bytesPerPixel,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(
                rawValue: CGImageAlphaInfo.premultipliedLast.rawValue
            ),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ))
        let image = NSImage(cgImage: cgImage, size: canvasSize)
        let viewModel = makeViewModel(image: image)
        let historyCount = viewModel.document.history.count
        let point = CGPoint(x: 20, y: 14)

        viewModel.selectColorSamplerSampleSize(.oneByOne)
        viewModel.updatePointer(point)
        #expect(viewModel.addColorSampler(at: point))
        var sampledColor = try #require(
            viewModel.colorSamplerPoints.last?.color.usingColorSpace(.deviceRGB)
        )
        let oneByOneRed = sampledColor.redComponent
        #expect(oneByOneRed > 0.7)
        #expect(viewModel.pointerColorInfoText.contains(
            "R \(Int((oneByOneRed * 255).rounded()))"
        ))

        viewModel.selectColorSamplerSampleSize(.threeByThree)
        sampledColor = try #require(
            viewModel.colorSamplerPoints.last?.color.usingColorSpace(.deviceRGB)
        )
        #expect(sampledColor.redComponent < oneByOneRed)
        #expect(sampledColor.redComponent > 0.08)
        #expect(sampledColor.redComponent < 0.14)
        #expect(viewModel.pointerColorInfoText.contains("R 28"))

        viewModel.selectColorSamplerSampleSize(.fiveByFive)
        sampledColor = try #require(
            viewModel.colorSamplerPoints.last?.color.usingColorSpace(.deviceRGB)
        )
        #expect(sampledColor.redComponent > 0.02)
        #expect(sampledColor.redComponent < 0.06)
        #expect(viewModel.pointerColorInfoText.contains("R 10"))
        #expect(viewModel.document.history.count == historyCount)
    }

    @Test func colorSamplerSourceSwitchesBetweenCompositeAndSelectedLayer() throws {
        let viewModel = makeViewModel(image: solidImage(color: .red))
        let sourceLayerID = try #require(viewModel.document.layers.first?.id)
        var blueLayer = ImageEditorLayer.blank(
            name: "Blue Overlay",
            size: canvasSize
        )
        blueLayer.image = solidImage(color: .blue)
        viewModel.document.layers.append(blueLayer)
        viewModel.selectLayer(sourceLayerID)
        let historyCount = viewModel.document.history.count
        let point = CGPoint(x: 12, y: 10)

        viewModel.updatePointer(point)
        #expect(viewModel.activeColorSamplerSource == .composite)
        #expect(viewModel.pointerColorInfoText.contains("B 255"))

        #expect(viewModel.selectColorSamplerSource(.selectedLayer))
        #expect(viewModel.activeColorSamplerSource == .selectedLayer)
        #expect(viewModel.pointerColorInfoText.contains("R 255"))
        #expect(viewModel.addColorSampler(at: point))
        var sampledColor = try #require(
            viewModel.colorSamplerPoints.last?.color.usingColorSpace(.deviceRGB)
        )
        #expect(sampledColor.redComponent > 0.95)
        #expect(sampledColor.blueComponent < 0.05)

        #expect(viewModel.selectColorSamplerSource(.composite))
        sampledColor = try #require(
            viewModel.colorSamplerPoints.last?.color.usingColorSpace(.deviceRGB)
        )
        #expect(sampledColor.blueComponent > 0.95)
        #expect(sampledColor.redComponent < 0.05)
        #expect(viewModel.pointerColorInfoText.contains("B 255"))
        #expect(viewModel.document.history.count == historyCount)
    }

    @Test
    func colorSamplerCurrentAndBelowExcludesUpperLayersAndTracksSelection() throws {
        let viewModel = makeViewModel(image: solidImage(color: .red))
        let bottomLayer = try #require(viewModel.document.layers.first)
        var currentLayer = ImageEditorLayer.blank(
            name: "Green Left Half",
            size: canvasSize
        )
        currentLayer.image = NSImage.rendered(size: canvasSize) { rect in
            NSColor.green.setFill()
            CGRect(
                x: rect.minX,
                y: rect.minY,
                width: rect.width / 2,
                height: rect.height
            ).fill()
        } ?? currentLayer.image
        var upperLayer = ImageEditorLayer.blank(
            name: "Blue Upper Layer",
            size: canvasSize
        )
        upperLayer.image = solidImage(color: .blue)
        viewModel.document.layers = [bottomLayer, currentLayer, upperLayer]
        viewModel.selectLayer(currentLayer.id)
        let historyCount = viewModel.document.history.count
        let leftPoint = CGPoint(x: 8, y: 12)
        let rightPoint = CGPoint(x: 32, y: 12)

        #expect(viewModel.selectColorSamplerSource(.currentAndBelow))
        #expect(viewModel.activeColorSamplerSource == .currentAndBelow)
        viewModel.updatePointer(leftPoint)
        #expect(viewModel.pointerColorInfoText.contains("G 255"))
        viewModel.updatePointer(rightPoint)
        #expect(viewModel.pointerColorInfoText.contains("R 255"))
        #expect(viewModel.addColorSampler(at: rightPoint))
        var sampledColor = try #require(
            viewModel.colorSamplerPoints.last?.color.usingColorSpace(.deviceRGB)
        )
        #expect(sampledColor.redComponent > 0.95)
        #expect(sampledColor.blueComponent < 0.05)

        viewModel.selectLayer(upperLayer.id)
        #expect(viewModel.activeColorSamplerSource == .currentAndBelow)
        sampledColor = try #require(
            viewModel.colorSamplerPoints.last?.color.usingColorSpace(.deviceRGB)
        )
        #expect(sampledColor.blueComponent > 0.95)
        #expect(sampledColor.redComponent < 0.05)

        #expect(viewModel.selectColorSamplerSource(.selectedLayer))
        viewModel.selectLayer(currentLayer.id)
        viewModel.updatePointer(rightPoint)
        #expect(viewModel.pointerColorInfoText.contains("A 0"))
        #expect(viewModel.document.history.count == historyCount)
    }

    @Test
    func colorSamplerCurrentAndBelowIncludesSelectedAdjustmentLayer() throws {
        let viewModel = makeViewModel(image: solidImage(color: .black))
        let bottomLayer = try #require(viewModel.document.layers.first)
        let adjustmentLayer = ImageEditorLayer.adjustment(
            name: "Invert Current",
            size: canvasSize,
            kind: .invert,
            amount: 1
        )
        var upperLayer = ImageEditorLayer.blank(
            name: "Blue Upper Layer",
            size: canvasSize
        )
        upperLayer.image = solidImage(color: .blue)
        viewModel.document.layers = [bottomLayer, adjustmentLayer, upperLayer]
        viewModel.selectLayer(adjustmentLayer.id)
        let historyCount = viewModel.document.history.count
        let point = CGPoint(x: 12, y: 10)

        #expect(
            viewModel.document.layerIDsThroughSelectedLayer()
                == Set([bottomLayer.id, adjustmentLayer.id])
        )
        #expect(
            viewModel.document.colorSamplingLayerIDs(
                for: .currentAndBelow,
                ignoringAdjustmentLayers: true
            ) == Set([bottomLayer.id])
        )
        #expect(!viewModel.canSampleColorSamplerSource(.selectedLayer))
        #expect(viewModel.canSampleColorSamplerSource(.currentAndBelow))
        #expect(viewModel.selectColorSamplerSource(.currentAndBelow))
        viewModel.updatePointer(point)
        #expect(viewModel.pointerColorInfoText.contains("R 255"))
        #expect(viewModel.pointerColorInfoText.contains("G 255"))
        #expect(viewModel.pointerColorInfoText.contains("B 255"))
        #expect(viewModel.addColorSampler(at: point))
        var sampledColor = try #require(
            viewModel.colorSamplerPoints.last?.color.usingColorSpace(.deviceRGB)
        )
        #expect(sampledColor.redComponent > 0.95)

        viewModel.setColorSamplerIgnoresAdjustmentLayers(true)
        #expect(viewModel.pointerColorInfoText.contains("R 0"))
        sampledColor = try #require(
            viewModel.colorSamplerPoints.last?.color.usingColorSpace(.deviceRGB)
        )
        #expect(sampledColor.redComponent < 0.05)
        #expect(sampledColor.greenComponent < 0.05)
        #expect(sampledColor.blueComponent < 0.05)

        viewModel.setColorSamplerIgnoresAdjustmentLayers(false)
        sampledColor = try #require(
            viewModel.colorSamplerPoints.last?.color.usingColorSpace(.deviceRGB)
        )
        #expect(sampledColor.redComponent > 0.95)

        #expect(viewModel.selectColorSamplerSource(.composite))
        #expect(viewModel.pointerColorInfoText.contains("B 255"))
        #expect(!viewModel.pointerColorInfoText.contains("R 255"))
        #expect(viewModel.document.history.count == historyCount)
    }

    @Test
    func colorSamplerIgnoresAdjustmentDescendantsWithoutReincludingTheirGroup() throws {
        let viewModel = makeViewModel(image: solidImage(color: .black))
        var bottomLayer = try #require(viewModel.document.layers.first)
        let adjustmentLayer = ImageEditorLayer.adjustment(
            name: "Invert Child",
            size: canvasSize,
            kind: .invert,
            amount: 1
        )
        let groupLayer = ImageEditorLayer.group(
            name: "Sample Group",
            size: canvasSize
        )
        var filterLayer = ImageEditorLayer.filter(
            name: "Blur Child",
            size: canvasSize,
            kind: .gaussianBlur,
            intensity: 0.5
        )
        bottomLayer.groupID = groupLayer.id
        var groupedAdjustment = adjustmentLayer
        groupedAdjustment.groupID = groupLayer.id
        filterLayer.groupID = groupLayer.id
        viewModel.document.layers = [
            bottomLayer,
            groupedAdjustment,
            filterLayer,
            groupLayer
        ]
        viewModel.selectLayer(groupLayer.id)
        let historyCount = viewModel.document.history.count
        let point = CGPoint(x: 12, y: 10)

        #expect(viewModel.selectColorSamplerSource(.selectedLayer))
        #expect(viewModel.addColorSampler(at: point))
        var sampledColor = try #require(
            viewModel.colorSamplerPoints.last?.color.usingColorSpace(.deviceRGB)
        )
        #expect(sampledColor.redComponent > 0.95)

        viewModel.setColorSamplerIgnoresAdjustmentLayers(true)
        #expect(
            viewModel.document.colorSamplingLayerIDs(
                for: .selectedLayer,
                ignoringAdjustmentLayers: true
            ) == Set([bottomLayer.id, filterLayer.id])
        )
        sampledColor = try #require(
            viewModel.colorSamplerPoints.last?.color.usingColorSpace(.deviceRGB)
        )
        #expect(sampledColor.redComponent < 0.05)
        #expect(sampledColor.greenComponent < 0.05)
        #expect(sampledColor.blueComponent < 0.05)
        #expect(viewModel.document.history.count == historyCount)
    }

    @Test
    func colorSamplerCompositeIgnoreAdjustmentSwitchInvalidatesItsCachedImage() throws {
        let viewModel = makeViewModel(image: solidImage(color: .black))
        let bottomLayer = try #require(viewModel.document.layers.first)
        let adjustmentLayer = ImageEditorLayer.adjustment(
            name: "Invert Composite",
            size: canvasSize,
            kind: .invert,
            amount: 1
        )
        viewModel.document.layers = [bottomLayer, adjustmentLayer]
        let historyCount = viewModel.document.history.count
        let point = CGPoint(x: 12, y: 10)

        #expect(viewModel.addColorSampler(at: point))
        var sampledColor = try #require(
            viewModel.colorSamplerPoints.last?.color.usingColorSpace(.deviceRGB)
        )
        #expect(sampledColor.redComponent > 0.95)

        viewModel.setColorSamplerIgnoresAdjustmentLayers(true)
        sampledColor = try #require(
            viewModel.colorSamplerPoints.last?.color.usingColorSpace(.deviceRGB)
        )
        #expect(sampledColor.redComponent < 0.05)

        viewModel.setColorSamplerIgnoresAdjustmentLayers(false)
        sampledColor = try #require(
            viewModel.colorSamplerPoints.last?.color.usingColorSpace(.deviceRGB)
        )
        #expect(sampledColor.redComponent > 0.95)
        #expect(viewModel.document.history.count == historyCount)
    }

    @Test func eyedropperSharesSampleSizeAndSourceWithoutWritingHistory() throws {
        let width = Int(canvasSize.width)
        let height = Int(canvasSize.height)
        let bytesPerPixel = 4
        var pixels = [UInt8](
            repeating: 0,
            count: width * height * bytesPerPixel
        )
        for pixelOffset in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
            pixels[pixelOffset + 3] = 255
        }
        let point = CGPoint(x: 20, y: 14)
        let whitePixelOffset = (Int(point.y) * width + Int(point.x)) * bytesPerPixel
        for componentOffset in 0..<bytesPerPixel {
            pixels[whitePixelOffset + componentOffset] = 255
        }
        let provider = try #require(CGDataProvider(data: Data(pixels) as CFData))
        let cgImage = try #require(CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: bytesPerPixel * 8,
            bytesPerRow: width * bytesPerPixel,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(
                rawValue: CGImageAlphaInfo.premultipliedLast.rawValue
            ),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ))
        let selectedLayerImage = NSImage(cgImage: cgImage, size: canvasSize)
        let viewModel = makeViewModel(image: selectedLayerImage)
        viewModel.foregroundColor = .cyan
        viewModel.backgroundColor = .yellow
        let history = viewModel.document.history
        let canUndo = viewModel.canUndo

        viewModel.selectColorSamplerSampleSize(.threeByThree)
        let returnedCompositeAverage = try #require(
            viewModel.sampleColor(at: point, target: .background)?
                .usingColorSpace(.deviceRGB)
        )
        let compositeAverage = try #require(
            viewModel.backgroundColor.usingColorSpace(.deviceRGB)
        )
        #expect(abs(returnedCompositeAverage.redComponent - compositeAverage.redComponent) < 0.01)
        #expect(compositeAverage.redComponent > 0.08)
        #expect(compositeAverage.redComponent < 0.14)
        #expect(abs(compositeAverage.redComponent - compositeAverage.greenComponent) < 0.01)
        #expect(abs(compositeAverage.redComponent - compositeAverage.blueComponent) < 0.01)
        let unchangedForeground = try #require(
            viewModel.foregroundColor.usingColorSpace(.deviceRGB)
        )
        #expect(unchangedForeground.greenComponent > 0.8)
        #expect(unchangedForeground.blueComponent > 0.8)
        #expect(viewModel.document.history == history)
        #expect(viewModel.canUndo == canUndo)

        let sourceViewModel = makeViewModel(image: solidImage(color: .red))
        let selectedLayerID = try #require(sourceViewModel.document.layers.first?.id)
        var blueLayer = ImageEditorLayer.blank(name: "Blue Overlay", size: canvasSize)
        blueLayer.image = solidImage(color: .blue)
        sourceViewModel.document.layers.append(blueLayer)
        sourceViewModel.selectLayer(selectedLayerID)
        let sourceHistory = sourceViewModel.document.history
        let sourceCanUndo = sourceViewModel.canUndo

        #expect(sourceViewModel.selectColorSamplerSource(.selectedLayer))
        #expect(sourceViewModel.activeColorSamplerSource == .selectedLayer)
        sourceViewModel.sampleColor(at: point, target: .background)
        let selectedLayer = try #require(
            sourceViewModel.backgroundColor.usingColorSpace(.deviceRGB)
        )
        #expect(selectedLayer.redComponent > 0.95)
        #expect(selectedLayer.blueComponent < 0.05)

        #expect(sourceViewModel.selectColorSamplerSource(.composite))
        sourceViewModel.sampleColor(at: point)
        let composite = try #require(
            sourceViewModel.foregroundColor.usingColorSpace(.deviceRGB)
        )
        #expect(composite.blueComponent > 0.95)
        #expect(composite.redComponent < 0.05)
        #expect(sourceViewModel.document.history == sourceHistory)
        #expect(sourceViewModel.canUndo == sourceCanUndo)
    }

    private let canvasSize = NSSize(width: 40, height: 28)

    private func makeViewModel(image: NSImage) -> ImageEditorViewModel {
        ImageEditorViewModel(sourceName: "tool-smoke.png", image: image) { _ in }
    }

    private func makeEditableViewModel(image: NSImage) -> ImageEditorViewModel {
        let viewModel = makeViewModel(image: image)
        viewModel.replaceSelectedLayerImageForTesting(image, historyTitle: L10n.text("imageEditor.history.brush"))
        return viewModel
    }

    private func makeConfiguredRetouchViewModel(image: NSImage) -> ImageEditorViewModel {
        let viewModel = makeEditableViewModel(image: image)
        viewModel.brushSize = 14
        viewModel.hardness = 1
        viewModel.opacity = 1
        return viewModel
    }

    private func solidImage(color: NSColor) -> NSImage {
        NSImage.rendered(size: canvasSize) { rect in
            color.setFill()
            rect.fill()
        } ?? NSImage.transparent(size: canvasSize)
    }

    private func verticalEdgeImage() -> NSImage {
        NSImage.rendered(size: canvasSize) { rect in
            NSColor.black.setFill()
            rect.fill()
            NSColor.white.setFill()
            CGRect(x: rect.midX, y: rect.minY, width: rect.width / 2, height: rect.height).fill()
        } ?? NSImage.transparent(size: canvasSize)
    }

    private func tonalBandImage() -> NSImage {
        NSImage.rendered(size: canvasSize) { rect in
            let bandWidth = rect.width / 3
            NSColor(deviceWhite: 0.15, alpha: 1).setFill()
            CGRect(x: rect.minX, y: rect.minY, width: bandWidth, height: rect.height).fill()
            NSColor(deviceWhite: 0.50, alpha: 1).setFill()
            CGRect(x: rect.minX + bandWidth, y: rect.minY, width: bandWidth, height: rect.height).fill()
            NSColor(deviceWhite: 0.85, alpha: 1).setFill()
            CGRect(x: rect.minX + bandWidth * 2, y: rect.minY, width: rect.width - bandWidth * 2, height: rect.height).fill()
        } ?? NSImage.transparent(size: canvasSize)
    }

    private func applyingToneBrush(
        to image: NSImage,
        burn: Bool,
        range: ImageEditorToneRange,
        protectTones: Bool,
        repetitions: Int = 1
    ) throws -> NSImage {
        var output = image
        for _ in 0..<repetitions {
            output = try #require(output.withToneBrush(
                points: [CGPoint(x: 20, y: 14)],
                width: 96,
                opacity: 1,
                hardness: 1,
                burn: burn,
                range: range,
                protectTones: protectTones
            ))
        }
        return output
    }

    private func colorContrast(
        in viewModel: ImageEditorViewModel,
        darkPoint: CGPoint,
        lightPoint: CGPoint
    ) throws -> CGFloat {
        let dark = try #require(
            viewModel.document.selectedLayer?.image.color(at: darkPoint)?.usingColorSpace(.deviceRGB)
        )
        let light = try #require(
            viewModel.document.selectedLayer?.image.color(at: lightPoint)?.usingColorSpace(.deviceRGB)
        )
        return light.redComponent - dark.redComponent
    }

    private func colorContrast(
        in image: NSImage,
        darkPoint: CGPoint,
        lightPoint: CGPoint
    ) throws -> CGFloat {
        try redComponent(in: image, at: lightPoint) - redComponent(in: image, at: darkPoint)
    }

    private func redComponent(in image: NSImage, at point: CGPoint) throws -> CGFloat {
        try #require(image.color(at: point)?.usingColorSpace(.deviceRGB)).redComponent
    }

    private func redComponent(
        in viewModel: ImageEditorViewModel,
        at point: CGPoint
    ) throws -> CGFloat {
        let image = try #require(viewModel.document.selectedLayer?.image)
        return try redComponent(in: image, at: point)
    }
}
