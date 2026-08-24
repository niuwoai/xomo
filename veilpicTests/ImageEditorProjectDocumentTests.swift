//
//  ImageEditorProjectDocumentTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/9.
//

import AppKit
import Testing
import UniformTypeIdentifiers
@testable import musepic

@MainActor
struct ImageEditorProjectDocumentTests {
    @Test func projectFormatUsesXomoExtensionAndKeepsLegacyQPicReadable() {
        #expect(ImageEditorProjectDocument.fileExtension == "xomoproject")
        #expect(ImageEditorProjectDocument.legacyFileExtension == "qpicproject")
        #expect(ImageEditorViewModel.projectContentType.identifier == "im.some.xomo.project")
        #expect(ImageEditorViewModel.legacyProjectContentType.identifier != "public.json")
    }

    @Test
    func projectDocumentRoundTripsColorSamplerStateAndRestoresLegacyDefaults() throws {
        let canvasSize = NSSize(width: 32, height: 24)
        let sourceImage = testImage(color: .blue, size: canvasSize)
        let viewModel = ImageEditorViewModel(
            sourceName: "samplers.png",
            image: sourceImage
        ) { _ in }
        viewModel.selectedColorSamplerReadoutMode = .cmyk
        viewModel.selectColorSamplerSampleSize(.fiveByFive)
        #expect(viewModel.selectColorSamplerSource(.currentAndBelow))
        viewModel.setColorSamplerIgnoresAdjustmentLayers(true)
        #expect(viewModel.addColorSampler(at: CGPoint(x: 4, y: 5)))
        #expect(viewModel.addColorSampler(at: CGPoint(x: 20, y: 12)))
        let savedIDs = viewModel.colorSamplerPoints.map(\.id)
        let savedColor = try #require(
            viewModel.colorSamplerPoints.first?.color.usingColorSpace(.deviceRGB)
        )

        let data = try viewModel.projectData()
        let project = try JSONDecoder().decode(
            ImageEditorProjectDocument.self,
            from: data
        )
        #expect(project.formatVersion == ImageEditorProjectDocument.formatVersion)
        #expect(project.colorSamplerPoints?.map(\.id) == savedIDs)
        #expect(project.colorSamplerReadoutMode == .cmyk)
        #expect(project.colorSamplerSampleSize == .fiveByFive)
        #expect(project.colorSamplerSource == .currentAndBelow)
        #expect(project.colorSamplerIgnoresAdjustmentLayers == true)

        let reopened = ImageEditorViewModel(
            sourceName: "empty.png",
            image: testImage(color: .black, size: NSSize(width: 8, height: 8))
        ) { _ in }
        try reopened.loadProjectData(data)

        #expect(reopened.colorSamplerPoints.map(\.id) == savedIDs)
        #expect(
            reopened.colorSamplerPoints.map(\.point)
                == [CGPoint(x: 4, y: 5), CGPoint(x: 20, y: 12)]
        )
        #expect(reopened.selectedColorSamplerReadoutMode == .cmyk)
        #expect(reopened.selectedColorSamplerSampleSize == .fiveByFive)
        #expect(reopened.selectedColorSamplerSource == .currentAndBelow)
        #expect(reopened.colorSamplerIgnoresAdjustmentLayers)
        let reopenedColor = try #require(
            reopened.colorSamplerPoints.first?.color.usingColorSpace(.deviceRGB)
        )
        #expect(abs(reopenedColor.redComponent - savedColor.redComponent) < 0.01)
        #expect(abs(reopenedColor.greenComponent - savedColor.greenComponent) < 0.01)
        #expect(abs(reopenedColor.blueComponent - savedColor.blueComponent) < 0.01)
        #expect(abs(reopenedColor.alphaComponent - savedColor.alphaComponent) < 0.01)

        var normalizedProject = project
        let duplicateID = UUID()
        normalizedProject.colorSamplerSource = .composite
        normalizedProject.colorSamplerPoints = [
            ImageEditorProjectColorSamplerPoint(
                id: UUID(),
                point: CGPoint(x: -1, y: 3)
            ),
            ImageEditorProjectColorSamplerPoint(
                id: duplicateID,
                point: CGPoint(x: 2, y: 3)
            ),
            ImageEditorProjectColorSamplerPoint(
                id: duplicateID,
                point: CGPoint(x: 4, y: 5)
            ),
            ImageEditorProjectColorSamplerPoint(
                id: UUID(),
                point: CGPoint(x: 6, y: 7)
            ),
            ImageEditorProjectColorSamplerPoint(
                id: UUID(),
                point: CGPoint(x: 8, y: 9)
            ),
            ImageEditorProjectColorSamplerPoint(
                id: UUID(),
                point: CGPoint(x: 10, y: 11)
            )
        ]
        let normalizedData = try JSONEncoder().encode(normalizedProject)
        try reopened.loadProjectData(normalizedData)
        #expect(
            reopened.colorSamplerPoints.count
                == ImageEditorColorSamplerPoint.maximumCount
        )
        #expect(Set(reopened.colorSamplerPoints.map(\.id)).count == 4)
        #expect(
            reopened.colorSamplerPoints.map(\.point)
                == [
                    CGPoint(x: 2, y: 3),
                    CGPoint(x: 4, y: 5),
                    CGPoint(x: 6, y: 7),
                    CGPoint(x: 8, y: 9)
                ]
        )

        var legacyObject = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        legacyObject.removeValue(forKey: "colorSamplerPoints")
        legacyObject.removeValue(forKey: "colorSamplerReadoutMode")
        legacyObject.removeValue(forKey: "colorSamplerSampleSize")
        legacyObject.removeValue(forKey: "colorSamplerSource")
        legacyObject.removeValue(forKey: "colorSamplerIgnoresAdjustmentLayers")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
        try reopened.loadProjectData(legacyData)
        #expect(reopened.colorSamplerPoints.isEmpty)
        #expect(reopened.selectedColorSamplerReadoutMode == .rgb)
        #expect(reopened.selectedColorSamplerSampleSize == .threeByThree)
        #expect(reopened.selectedColorSamplerSource == .composite)
        #expect(!reopened.colorSamplerIgnoresAdjustmentLayers)
    }

    @Test func textFontFamilyRoundTripsAndLegacyPayloadUsesSystemFont() throws {
        let content = ImageEditorTextContent(
            text: "Typography",
            color: .white,
            fontSize: 28,
            fontFamilyName: "Helvetica",
            point: CGPoint(x: 4, y: 4)
        )
        let encoded = try JSONEncoder().encode(ImageEditorProjectTextContent(content: content))
        let restored = try JSONDecoder().decode(ImageEditorProjectTextContent.self, from: encoded)
        #expect(restored.textContent.fontFamilyName == "Helvetica")
        #expect(!restored.textContent.truncatesOverflow)
        #expect(restored.textContent.verticalAlignment == .top)

        var legacyObject = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        legacyObject.removeValue(forKey: "fontFamilyName")
        legacyObject.removeValue(forKey: "truncatesOverflow")
        legacyObject.removeValue(forKey: "verticalAlignment")
        let legacy = try JSONSerialization.data(withJSONObject: legacyObject)
        let legacyContent = try JSONDecoder().decode(ImageEditorProjectTextContent.self, from: legacy)
        #expect(legacyContent.textContent.fontFamilyName == ImageEditorTextContent.systemFontFamilyName)
        #expect(legacyContent.textContent.verticalAlignment == .top)
    }

    @Test func shapeMiterLimitRoundTripsAndLegacyPayloadUsesNativeDefault() throws {
        let content = ImageEditorShapeContent(
            kind: .path,
            fillColor: .clear,
            fillOpacity: 0,
            strokeColor: .black,
            strokeWidth: 4,
            strokeOpacity: 1,
            strokeJoin: .miter,
            strokeMiterLimit: 4,
            strokeDashOffset: 5.5,
            pathPoints: [CGPoint(x: 0, y: 10), CGPoint(x: 10, y: 0), CGPoint(x: 20, y: 10)]
        )
        let encoded = try JSONEncoder().encode(ImageEditorProjectShapeContent(content: content))
        let restored = try JSONDecoder().decode(ImageEditorProjectShapeContent.self, from: encoded)
        #expect(restored.content.strokeMiterLimit == 4)
        #expect(restored.content.strokeDashOffset == 5.5)

        var legacyObject = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        legacyObject.removeValue(forKey: "strokeMiterLimit")
        legacyObject.removeValue(forKey: "strokeDashOffset")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
        let legacy = try JSONDecoder().decode(ImageEditorProjectShapeContent.self, from: legacyData)
        #expect(legacy.content.strokeMiterLimit == ImageEditorShapeContent.defaultStrokeMiterLimit)
        #expect(legacy.content.strokeDashOffset == 0)
    }

    @Test
    func adjustmentSettingsDecodeLegacyPayloadWithMissingNewFields() throws {
        let legacyPayload = Data(
            """
            {
              "levelsBlackPoint": 0.12,
              "levelsGamma": 1.4,
              "levelsWhitePoint": 0.92,
              "hueSaturationHue": 24,
              "hueSaturationSaturation": 0.35,
              "photoFilterDensity": 0.7,
              "gradientMapPreset": "sepia"
            }
            """.utf8
        )

        let settings = try JSONDecoder().decode(ImageEditorAdjustmentSettings.self, from: legacyPayload)

        #expect(settings.levelsBlackPoint == 0.12)
        #expect(settings.levelsGamma == 1.4)
        #expect(settings.levelsWhitePoint == 0.92)
        #expect(settings.hueSaturationHue == 24)
        #expect(settings.hueSaturationSaturation == 0.35)
        #expect(settings.exposureEV == 0)
        #expect(settings.exposureOffset == 0)
        #expect(settings.exposureGamma == 1)
        #expect(settings.shadowsHighlightsShadows == 0)
        #expect(settings.shadowsHighlightsHighlights == 0)
        #expect(settings.blackWhiteReds == 0.40)
        #expect(settings.channelMixerRedRed == 1)
        #expect(settings.photoFilterDensity == 0.7)
        #expect(settings.gradientMapPreset == .sepia)
        #expect(!settings.gradientMapReverse)
        #expect(settings.gradientMapHighlightBlue == 1)
    }

    @Test
    func gradientFillLayerRendersAndRoundTripsThroughProjectDocument() throws {
        let canvasSize = NSSize(width: 40, height: 20)
        let sourceImage = testImage(color: .black, size: canvasSize)
        let viewModel = ImageEditorViewModel(sourceName: "gradient.png", image: sourceImage) { _ in }
        viewModel.selectedGradientFillPreset = .custom
        viewModel.gradientFillStartRed = 1
        viewModel.gradientFillStartGreen = 0
        viewModel.gradientFillStartBlue = 0
        viewModel.gradientFillEndRed = 0
        viewModel.gradientFillEndGreen = 0
        viewModel.gradientFillEndBlue = 1
        viewModel.gradientFillAngle = 0
        viewModel.gradientFillScale = 1

        viewModel.addGradientFillLayer()

        let gradientLayer = try #require(viewModel.document.selectedLayer)
        let leftColor = try #require(viewModel.currentImage.color(at: CGPoint(x: 2, y: 10))?.usingColorSpace(.deviceRGB))
        let rightColor = try #require(viewModel.currentImage.color(at: CGPoint(x: 38, y: 10))?.usingColorSpace(.deviceRGB))
        #expect(gradientLayer.isGradientFill)
        #expect(gradientLayer.gradientFillContent?.preset == .custom)
        #expect(leftColor.redComponent > rightColor.redComponent)
        #expect(rightColor.blueComponent > leftColor.blueComponent)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerGradientFillNew"))

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == gradientLayer.id })
        let restoredLeftColor = try #require(restoredDocument.compositedImage.color(at: CGPoint(x: 2, y: 10))?.usingColorSpace(.deviceRGB))
        let restoredRightColor = try #require(restoredDocument.compositedImage.color(at: CGPoint(x: 38, y: 10))?.usingColorSpace(.deviceRGB))
        #expect(restoredLayer.isGradientFill)
        #expect(restoredLayer.gradientFillContent?.preset == .custom)
        #expect(restoredLeftColor.redComponent > restoredRightColor.redComponent)
        #expect(restoredRightColor.blueComponent > restoredLeftColor.blueComponent)
    }

    @Test
    func projectDocumentRoundTripsEditableLayerState() throws {
        let sourceImage = testImage(color: .systemBlue, size: NSSize(width: 96, height: 72))
        let viewModel = ImageEditorViewModel(sourceName: "design.png", image: sourceImage) { _ in }

        var pixelLayer = ImageEditorLayer.blank(name: "Pixel detail", size: NSSize(width: 40, height: 30))
        pixelLayer.image = testImage(color: .systemPink, size: NSSize(width: 40, height: 30))
        pixelLayer.mask = NSImage.opaqueMask(size: NSSize(width: 40, height: 30))
        pixelLayer.frame = CGRect(x: 12, y: 14, width: 40, height: 30)
        pixelLayer.opacity = 0.65
        pixelLayer.fillOpacity = 0.72
        pixelLayer.blendIfSourceBlack = 0.2
        pixelLayer.blendIfSourceWhite = 0.86
        pixelLayer.blendIfUnderlyingBlack = 0.12
        pixelLayer.blendIfUnderlyingWhite = 0.91
        pixelLayer.blendMode = .multiply
        pixelLayer.locksPixels = true
        pixelLayer.style.strokeEnabled = true
        pixelLayer.style.strokeColor = .systemYellow
        pixelLayer.style.strokeWidth = 5
        pixelLayer.style.strokePosition = .inside
        pixelLayer.style.strokeOpacity = 0.44
        pixelLayer.style.shadowEnabled = true
        pixelLayer.style.shadowColor = .systemRed
        pixelLayer.style.shadowDistance = 13
        pixelLayer.style.shadowAngle = 30
        pixelLayer.style.shadowUsesGlobalLight = false
        pixelLayer.style.shadowOffset = ImageEditorLayerStyle.shadowOffset(distance: 13, angle: 30)
        pixelLayer.style.shadowSpread = 9
        pixelLayer.style.innerShadowEnabled = true
        pixelLayer.style.innerShadowDistance = 8
        pixelLayer.style.innerShadowAngle = 45
        pixelLayer.style.innerShadowUsesGlobalLight = true
        pixelLayer.style.bevelEnabled = true
        pixelLayer.style.bevelSize = 6
        pixelLayer.style.bevelAngle = 18
        pixelLayer.style.bevelUsesGlobalLight = false
        pixelLayer.smartFilters = [
            ImageEditorSmartFilter(
                kind: .unsharpMask,
                intensity: 0.8,
                settings: ImageEditorFilterSettings(unsharpRadius: 2.5, unsharpThreshold: 0.2),
                opacity: 0.42,
                blendMode: .softLight
            )
        ]
        pixelLayer.vectorMask = ImageEditorShapeContent(
            kind: .path,
            fillColor: .white,
            fillOpacity: 1,
            strokeColor: .white,
            strokeWidth: 1,
            strokeOpacity: 1,
            pathPoints: [
                CGPoint(x: 4, y: 4),
                CGPoint(x: 30, y: 6),
                CGPoint(x: 20, y: 24)
            ],
            pathAnchors: [
                ImageEditorPathAnchor(point: CGPoint(x: 4, y: 4)),
                ImageEditorPathAnchor(point: CGPoint(x: 30, y: 6)),
                ImageEditorPathAnchor(point: CGPoint(x: 20, y: 24))
            ],
            isPathClosed: true
        )
        pixelLayer.isVectorMaskInverted = true

        let textContent = ImageEditorTextContent(
            text: "Round trip",
            color: .white,
            fontSize: 18,
            point: CGPoint(x: 2, y: 3),
            isBold: true,
            isItalic: true,
            characterSpacing: 1.5,
            lineSpacing: 2,
            boxWidth: 80,
            alignment: .center
        )
        var textLayer = ImageEditorLayer.text(
            name: "Title",
            origin: CGPoint(x: 20, y: 8),
            content: textContent
        )
        textLayer.opacity = 0.9

        let shapeContent = ImageEditorShapeContent(
            kind: .ellipse,
            fillColor: .systemGreen,
            fillOpacity: 0.45,
            strokeColor: .black,
            strokeWidth: 3,
            strokeOpacity: 0.8,
            strokeCap: .square,
            strokeJoin: .bevel,
            strokeMiterLimit: 4,
            strokeDashPattern: [6, 3],
            strokeDashOffset: 2.5
        )
        let shapeLayer = ImageEditorLayer.shape(
            name: "Badge",
            frame: CGRect(x: 50, y: 20, width: 28, height: 28),
            content: shapeContent
        )
        var smartObjectLayer = ImageEditorLayer.smartObject(
            name: "Placed Logo",
            image: testImage(color: .systemOrange, size: NSSize(width: 32, height: 24)),
            sourceName: "logo.png"
        )
        smartObjectLayer.frame = CGRect(x: 10, y: 34, width: 48, height: 36)
        var groupLayer = ImageEditorLayer.group(
            name: "Composite Group",
            size: NSSize(width: 96, height: 72)
        )
        groupLayer.blendMode = .multiply
        groupLayer.opacity = 0.77
        groupLayer.isGroupExpanded = false
        pixelLayer.groupID = groupLayer.id
        pixelLayer.labelColor = .blue
        groupLayer.labelColor = .purple

        viewModel.document.layers.append(pixelLayer)
        viewModel.document.layers.append(textLayer)
        viewModel.document.layers.append(shapeLayer)
        viewModel.document.layers.append(smartObjectLayer)
        viewModel.document.layers.append(groupLayer)
        viewModel.document.selectedLayerID = textLayer.id
        viewModel.document.selectedLayerIDs = [pixelLayer.id, textLayer.id]
        viewModel.document.areExtrasVisible = false
        viewModel.document.areSelectionEdgesVisible = false
        viewModel.document.areTransformControlsVisible = false
        viewModel.document.isGridVisible = true
        viewModel.document.isGridSnappingEnabled = true
        viewModel.document.gridSpacing = 40
        viewModel.document.globalLightAngle = 72

        let selectionMask = ImageEditorSelectionMask(width: 4, height: 3, alpha: [
            255, 0, 255, 0,
            0, 255, 0, 255,
            255, 255, 0, 0
        ])
        viewModel.document.selection = ImageEditorSelection.raster(
            mask: selectionMask,
            bounds: CGRect(x: 0, y: 0, width: 4, height: 3)
        )
        viewModel.document.savedSelection = viewModel.document.selection
        viewModel.document.alphaChannels = [
            ImageEditorAlphaChannel(name: "Soft Mask", mask: selectionMask)
        ]

        let data = try viewModel.projectData()
        let restoredViewModel = ImageEditorViewModel(
            sourceName: "empty.png",
            image: testImage(color: .black, size: NSSize(width: 12, height: 12))
        ) { _ in }
        try restoredViewModel.loadProjectData(data)

        #expect(restoredViewModel.document.sourceName == "design.png")
        #expect(restoredViewModel.document.canvasSize == NSSize(width: 96, height: 72))
        #expect(restoredViewModel.document.layers.count == viewModel.document.layers.count)
        #expect(restoredViewModel.document.selectedLayerID == textLayer.id)
        #expect(restoredViewModel.document.selectedLayerIDs.contains(pixelLayer.id))
        #expect(restoredViewModel.document.selectedLayerIDs.contains(textLayer.id))
        #expect(!restoredViewModel.document.areExtrasVisible)
        #expect(!restoredViewModel.document.areSelectionEdgesVisible)
        #expect(!restoredViewModel.document.areTransformControlsVisible)
        #expect(restoredViewModel.document.isGridVisible)
        #expect(restoredViewModel.document.isGridSnappingEnabled)
        #expect(restoredViewModel.document.gridSpacing == 40)
        #expect(restoredViewModel.document.globalLightAngle == 72)

        let restoredPixel = try #require(restoredViewModel.document.layers.first { $0.id == pixelLayer.id })
        #expect(restoredPixel.name == "Pixel detail")
        #expect(restoredPixel.frame == pixelLayer.frame)
        #expect(restoredPixel.opacity == 0.65)
        #expect(restoredPixel.fillOpacity == 0.72)
        #expect(restoredPixel.blendIfSourceBlack == 0.2)
        #expect(restoredPixel.blendIfSourceWhite == 0.86)
        #expect(restoredPixel.blendIfUnderlyingBlack == 0.12)
        #expect(restoredPixel.blendIfUnderlyingWhite == 0.91)
        #expect(restoredPixel.blendMode == .multiply)
        #expect(restoredPixel.locksPixels)
        #expect(restoredPixel.mask != nil)
        #expect(restoredPixel.vectorMask?.kind == .path)
        #expect(restoredPixel.vectorMask?.editablePathAnchors.count == 3)
        #expect(restoredPixel.isVectorMaskInverted)
        #expect(restoredPixel.style.strokeEnabled)
        #expect(restoredPixel.style.strokeWidth == 5)
        #expect(restoredPixel.style.strokePosition == .inside)
        #expect(restoredPixel.style.strokeOpacity == 0.44)
        let restoredStrokeColor = try #require(restoredPixel.style.strokeColor.usingColorSpace(.deviceRGB))
        #expect(restoredStrokeColor.redComponent > 0.75)
        #expect(restoredStrokeColor.greenComponent > 0.55)
        #expect(restoredPixel.style.shadowEnabled)
        let restoredShadowColor = try #require(restoredPixel.style.shadowColor.usingColorSpace(.deviceRGB))
        #expect(restoredShadowColor.redComponent > 0.75)
        #expect(restoredShadowColor.greenComponent < 0.35)
        #expect(restoredPixel.style.shadowSpread == 9)
        #expect(abs(restoredPixel.style.shadowDistance - 13) < 0.001)
        #expect(abs(restoredPixel.style.shadowAngle - 30) < 0.001)
        #expect(!restoredPixel.style.shadowUsesGlobalLight)
        #expect(restoredPixel.style.innerShadowEnabled)
        #expect(restoredPixel.style.innerShadowUsesGlobalLight)
        #expect(restoredPixel.style.resolvedInnerShadowAngle(globalLightAngle: restoredViewModel.document.globalLightAngle) == 72)
        #expect(restoredPixel.style.bevelEnabled)
        #expect(restoredPixel.style.bevelSize == 6)
        #expect(!restoredPixel.style.bevelUsesGlobalLight)
        #expect(restoredPixel.style.resolvedBevelAngle(globalLightAngle: restoredViewModel.document.globalLightAngle) == 18)
        #expect(restoredPixel.smartFilters.count == 1)
        #expect(restoredPixel.smartFilters.first?.kind == .unsharpMask)
        #expect(restoredPixel.smartFilters.first?.normalizedOpacity == 0.42)
        #expect(restoredPixel.smartFilters.first?.normalizedBlendMode == .softLight)
        #expect(restoredPixel.smartFilters.first?.normalizedSettings.unsharpRadius == 2.5)
        #expect(restoredPixel.smartFilters.first?.normalizedSettings.unsharpThreshold == 0.2)
        #expect(restoredPixel.groupID == groupLayer.id)
        #expect(restoredPixel.labelColor == .blue)

        let restoredText = try #require(restoredViewModel.document.layers.first { $0.id == textLayer.id })
        let restoredTextContent = try #require(restoredText.textContent)
        #expect(restoredTextContent.text == "Round trip")
        #expect(restoredTextContent.isBold)
        #expect(restoredTextContent.isItalic)
        #expect(restoredTextContent.alignment == .center)
        #expect(restoredTextContent.boxWidth == 80)

        let restoredShape = try #require(restoredViewModel.document.layers.first { $0.id == shapeLayer.id })
        let restoredShapeContent = try #require(restoredShape.shapeContent)
        #expect(restoredShapeContent.kind == .ellipse)
        #expect(restoredShapeContent.strokeWidth == 3)
        #expect(restoredShapeContent.fillOpacity == 0.45)
        #expect(restoredShapeContent.strokeCap == .square)
        #expect(restoredShapeContent.strokeJoin == .bevel)
        #expect(restoredShapeContent.strokeMiterLimit == 4)
        #expect(restoredShapeContent.strokeDashPattern == [6, 3])
        #expect(restoredShapeContent.strokeDashOffset == 2.5)

        let restoredSmartObject = try #require(restoredViewModel.document.layers.first { $0.id == smartObjectLayer.id })
        let restoredSmartObjectContent = try #require(restoredSmartObject.smartObjectContent)
        #expect(restoredSmartObject.frame == smartObjectLayer.frame)
        #expect(restoredSmartObject.image.size == NSSize(width: 32, height: 24))
        #expect(restoredSmartObjectContent.sourceName == "logo.png")
        #expect(restoredSmartObjectContent.originalSize == NSSize(width: 32, height: 24))
        #expect(restoredSmartObjectContent.sourceID == smartObjectLayer.smartObjectContent?.sourceID)

        let restoredGroup = try #require(restoredViewModel.document.layers.first { $0.id == groupLayer.id })
        #expect(restoredGroup.isGroup)
        #expect(restoredGroup.blendMode == .multiply)
        #expect(restoredGroup.opacity == 0.77)
        #expect(!restoredGroup.isGroupExpanded)
        #expect(restoredGroup.labelColor == .purple)

        #expect(restoredViewModel.document.selection?.rasterMask == selectionMask)
        #expect(restoredViewModel.document.savedSelection?.rasterMask == selectionMask)
        #expect(restoredViewModel.document.alphaChannels.first?.name == "Soft Mask")
        #expect(restoredViewModel.document.alphaChannels.first?.mask == selectionMask)
    }

    @Test
    func projectDocumentRoundTripsNamedSlicesAndNormalizesThemToCanvas() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "slices.png",
            image: NSImage.transparent(size: CGSize(width: 120, height: 80))
        ) { _ in }
        let sliceID = UUID()
        viewModel.document.slices = [
            ImageEditorSlice(
                id: sliceID,
                name: "Hero",
                frame: CGRect(x: 20, y: 12, width: 60, height: 40)
            )
        ]

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restored = try project.restoredDocument()
        let slice = try #require(restored.slices.first)

        #expect(slice.id == sliceID)
        #expect(slice.name == "Hero")
        #expect(slice.frame == CGRect(x: 20, y: 12, width: 60, height: 40))
    }

    @Test
    func projectDocumentRoundTripsNamedHotspotsAndKeepsDestinationURL() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "hotspots.png",
            image: NSImage.transparent(size: CGSize(width: 120, height: 80))
        ) { _ in }
        let hotspotID = UUID()
        viewModel.document.hotspots = [
            ImageEditorHotspot(
                id: hotspotID,
                name: "Hero link",
                frame: CGRect(x: 20, y: 12, width: 60, height: 40),
                url: "https://example.com/hero"
            )
        ]

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restored = try project.restoredDocument()
        let hotspot = try #require(restored.hotspots.first)

        #expect(hotspot.id == hotspotID)
        #expect(hotspot.name == "Hero link")
        #expect(hotspot.url == "https://example.com/hero")
        #expect(hotspot.frame == CGRect(x: 20, y: 12, width: 60, height: 40))
    }

    @Test
    func projectDocumentStoresSmartObjectSourceOnceForSharedInstances() throws {
        let sourceImage = testImage(color: .systemBlue, size: NSSize(width: 96, height: 72))
        let viewModel = ImageEditorViewModel(sourceName: "design.png", image: sourceImage) { _ in }
        let logoImage = testImage(color: .systemOrange, size: NSSize(width: 32, height: 24))

        var firstInstance = ImageEditorLayer.smartObject(
            name: "Logo",
            image: logoImage,
            sourceName: "logo.png"
        )
        firstInstance.frame = CGRect(x: 8, y: 10, width: 32, height: 24)
        var secondInstance = firstInstance
        secondInstance.id = UUID()
        secondInstance.name = "Logo copy"
        secondInstance.frame = CGRect(x: 48, y: 20, width: 32, height: 24)

        viewModel.document.layers.append(firstInstance)
        viewModel.document.layers.append(secondInstance)

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let sharedSource = try #require(project.smartObjectSources?.first)
        #expect(project.formatVersion == ImageEditorProjectDocument.formatVersion)
        #expect(project.smartObjectSources?.count == 1)
        #expect(sharedSource.sourceID == firstInstance.smartObjectContent?.sourceID)

        let smartObjectProjectLayers = project.layers.filter { layer in
            if case .smartObject = layer.kind { return true }
            return false
        }
        #expect(smartObjectProjectLayers.count == 2)
        #expect(smartObjectProjectLayers.allSatisfy { $0.imageData == nil })

        let restoredDocument = try project.restoredDocument()
        let restoredSmartObjects = restoredDocument.layers.filter(\.isSmartObject)
        #expect(restoredSmartObjects.count == 2)
        #expect(restoredSmartObjects.allSatisfy {
            $0.smartObjectContent?.sourceID == firstInstance.smartObjectContent?.sourceID
        })
        #expect(restoredSmartObjects.allSatisfy { $0.image.size == logoImage.size })
        let restoredFrames = restoredSmartObjects.map(\.frame)
        #expect(restoredFrames.count == 2)
        #expect(restoredFrames.contains(firstInstance.frame))
        #expect(restoredFrames.contains(secondInstance.frame))
    }

    @Test
    func projectDocumentRestoresLegacySmartObjectLayerImageData() throws {
        let sourceImage = testImage(color: .systemBlue, size: NSSize(width: 96, height: 72))
        let viewModel = ImageEditorViewModel(sourceName: "design.png", image: sourceImage) { _ in }
        let logoImage = testImage(color: .systemOrange, size: NSSize(width: 32, height: 24))
        let smartObjectLayer = ImageEditorLayer.smartObject(
            name: "Logo",
            image: logoImage,
            sourceName: "logo.png"
        )
        viewModel.document.layers.append(smartObjectLayer)

        var project = try ImageEditorProjectDocument(document: viewModel.document)
        project.smartObjectSources = nil
        project.layers = try viewModel.document.layers.map(ImageEditorProjectLayer.init(layer:))

        let restoredDocument = try project.restoredDocument()
        let restoredSmartObject = try #require(restoredDocument.layers.first { $0.id == smartObjectLayer.id })
        #expect(restoredSmartObject.image.size == logoImage.size)
        #expect(restoredSmartObject.smartObjectContent?.sourceID == smartObjectLayer.smartObjectContent?.sourceID)
    }

    @Test
    func layerGroupPassThroughKeepsChildBlendingAgainstBackdrop() throws {
        let canvasSize = NSSize(width: 12, height: 12)
        let viewModel = ImageEditorViewModel(
            sourceName: "design.png",
            image: testImage(color: .blue, size: canvasSize)
        ) { _ in }

        let group = ImageEditorLayer.group(name: "Multiply Group", size: canvasSize)
        var child = ImageEditorLayer.blank(name: "Red Multiply", size: canvasSize)
        child.image = testImage(color: .red, size: canvasSize)
        child.blendMode = .multiply
        child.groupID = group.id
        viewModel.document.layers.append(child)
        viewModel.document.layers.append(group)

        #expect(group.blendMode == .passThrough)
        let passThroughColor = try #require(viewModel.currentImage.color(at: CGPoint(x: 4, y: 4))?.usingColorSpace(.deviceRGB))
        #expect(passThroughColor.redComponent < 0.08)
        #expect(passThroughColor.blueComponent < 0.08)

        let groupIndex = try #require(viewModel.document.layers.firstIndex { $0.id == group.id })
        viewModel.document.layers[groupIndex].blendMode = .normal
        let isolatedColor = try #require(viewModel.currentImage.color(at: CGPoint(x: 4, y: 4))?.usingColorSpace(.deviceRGB))
        #expect(isolatedColor.redComponent > 0.9)
        #expect(isolatedColor.blueComponent < 0.08)
    }

    @Test
    func projectDocumentMigratesLegacyNormalGroupsToPassThrough() throws {
        let canvasSize = NSSize(width: 12, height: 12)
        let viewModel = ImageEditorViewModel(
            sourceName: "legacy-group.png",
            image: testImage(color: .blue, size: canvasSize)
        ) { _ in }

        var group = ImageEditorLayer.group(name: "Legacy Group", size: canvasSize)
        group.blendMode = .normal
        var child = ImageEditorLayer.blank(name: "Red Multiply", size: canvasSize)
        child.image = testImage(color: .red, size: canvasSize)
        child.blendMode = .multiply
        child.groupID = group.id
        viewModel.document.layers.append(child)
        viewModel.document.layers.append(group)

        var legacyProject = try ImageEditorProjectDocument(document: viewModel.document)
        legacyProject.formatVersion = 2
        let restoredDocument = try legacyProject.restoredDocument()
        let restoredGroup = try #require(restoredDocument.layers.first { $0.id == group.id })
        #expect(restoredGroup.blendMode == .passThrough)
    }

    private func testImage(color: NSColor, size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        color.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        return image
    }
}
