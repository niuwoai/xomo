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
        let edgePoint = CGPoint(x: 19, y: 18)
        let blurOriginal = try #require(
            hardEdge.color(at: edgePoint)?.usingColorSpace(.deviceRGB)
        )
        let sharpenOriginal = try #require(
            softenedEdge.color(at: edgePoint)?.usingColorSpace(.deviceRGB)
        )

        softBlur.blurBrush(points: points)
        hardBlur.blurBrush(points: points)
        softSharpen.sharpenBrush(points: points)
        hardSharpen.sharpenBrush(points: points)

        let softBlurEdge = try #require(
            softBlur.document.selectedLayer?.image.color(at: edgePoint)?.usingColorSpace(.deviceRGB)
        )
        let hardBlurEdge = try #require(
            hardBlur.document.selectedLayer?.image.color(at: edgePoint)?.usingColorSpace(.deviceRGB)
        )
        let softSharpenEdge = try #require(
            softSharpen.document.selectedLayer?.image.color(at: edgePoint)?.usingColorSpace(.deviceRGB)
        )
        let hardSharpenEdge = try #require(
            hardSharpen.document.selectedLayer?.image.color(at: edgePoint)?.usingColorSpace(.deviceRGB)
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

        viewModel.addColorSampler(at: CGPoint(x: 20, y: 14))
        let sample = try #require(viewModel.colorSamplerPoints.last)
        let sampledColor = try #require(sample.color.usingColorSpace(NSColorSpace.deviceRGB))
        #expect(sampledColor.redComponent > 0.8)
        #expect(sampledColor.blueComponent > 0.8)
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
