//
//  ImageEditorPSDTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/11.
//

import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorPSDTests {
    @Test func psdRoundTripPreservesLayerBasicsAndCompositeCompatibility() throws {
        let canvasSize = CGSize(width: 32, height: 24)
        var document = ImageEditorDocument(sourceName: "poster.png", image: psdSolidImage(color: .white, size: canvasSize))
        document.layers.removeAll()

        var bottom = ImageEditorLayer.blank(name: "背景", size: CGSize(width: 32, height: 24))
        bottom.image = psdSolidImage(color: .systemBlue, size: bottom.image.size)
        bottom.frame = CGRect(origin: .zero, size: bottom.image.size)

        var top = ImageEditorLayer.blank(name: "橙色圆点", size: CGSize(width: 10, height: 8))
        top.image = psdSolidImage(color: .systemOrange, size: top.image.size)
        top.frame = CGRect(x: 7, y: 9, width: 10, height: 8)
        top.opacity = 0.6
        top.blendMode = .multiply
        top.isVisible = false

        document.layers = [bottom, top]
        document.selectedLayerID = top.id
        document.selectedLayerIDs = [top.id]

        let data = try ImageEditorPSDCodec.encode(document: document)

        #expect(String(data: data.prefix(4), encoding: .ascii) == "8BPS")
        #expect(NSImage(data: data) != nil)

        let restored = try ImageEditorPSDCodec.decode(data, sourceName: "poster.psd")
        #expect(restored.canvasSize == canvasSize)
        #expect(restored.layers.map { $0.name } == ["背景", "橙色圆点"])
        let restoredTop = try #require(restored.layers.last)
        #expect(restoredTop.frame == top.frame)
        #expect(abs(restoredTop.opacity - top.opacity) < 0.01)
        #expect(restoredTop.blendMode == .multiply)
        #expect(!restoredTop.isVisible)
    }

    @Test func psdExportPreservesClosedAndOpenSavedPaths() throws {
        let canvasSize = CGSize(width: 32, height: 24)
        var document = ImageEditorDocument(
            sourceName: "paths.png",
            image: psdSolidImage(color: .white, size: canvasSize)
        )
        let triangle = ImageEditorSavedPath(
            name: "Exported Triangle",
            subpaths: [[
                ImageEditorPathAnchor(point: CGPoint(x: 4, y: 5)),
                ImageEditorPathAnchor(point: CGPoint(x: 28, y: 5)),
                ImageEditorPathAnchor(point: CGPoint(x: 16, y: 19))
            ], [
                ImageEditorPathAnchor(point: CGPoint(x: 12, y: 8)),
                ImageEditorPathAnchor(point: CGPoint(x: 20, y: 8)),
                ImageEditorPathAnchor(point: CGPoint(x: 16, y: 14))
            ]],
            isClosed: true
        )
        let guide = ImageEditorSavedPath(
            name: "Exported Guide",
            subpaths: [[
                ImageEditorPathAnchor(point: CGPoint(x: 6, y: 8)),
                ImageEditorPathAnchor(point: CGPoint(x: 26, y: 17))
            ]],
            isClosed: false
        )
        document.savedPaths = [triangle, guide]

        let data = try ImageEditorPSDCodec.encode(document: document)
        let restored = try ImageEditorPSDCodec.decode(data, sourceName: "paths.psd")

        #expect(restored.savedPaths.count == 2)
        let restoredTriangle = try #require(restored.savedPaths.first { $0.name == "Exported Triangle" })
        let restoredGuide = try #require(restored.savedPaths.first { $0.name == "Exported Guide" })
        #expect(restoredTriangle.isClosed)
        #expect(restoredTriangle.subpaths.count == 2)
        #expect(restoredTriangle.subpaths.first?.count == 3)
        #expect(!restoredGuide.isClosed)
        #expect(restoredGuide.subpaths.first?.count == 2)
        #expect(abs(restoredTriangle.subpaths[0][1].point.x - 28) < 0.01)
        #expect(abs(restoredGuide.subpaths[0][1].point.y - 17) < 0.01)
    }

    @Test func psdExportPreservesNativeVectorMaskAndEnabledState() throws {
        let canvasSize = CGSize(width: 32, height: 24)
        var document = ImageEditorDocument(
            sourceName: "vector-mask.png",
            image: psdSolidImage(color: .white, size: canvasSize)
        )
        var layer = ImageEditorLayer.blank(name: "Vector Mask Layer", size: canvasSize)
        layer.frame = CGRect(origin: .zero, size: canvasSize)
        layer.vectorMask = ImageEditorShapeContent(
            kind: .path,
            fillColor: .white,
            fillOpacity: 1,
            strokeColor: .clear,
            strokeWidth: 1,
            strokeOpacity: 0,
            pathPoints: [
                CGPoint(x: 4, y: 4),
                CGPoint(x: 28, y: 4),
                CGPoint(x: 16, y: 20)
            ],
            pathAnchors: [
                ImageEditorPathAnchor(point: CGPoint(x: 4, y: 4)),
                ImageEditorPathAnchor(point: CGPoint(x: 28, y: 4)),
                ImageEditorPathAnchor(point: CGPoint(x: 16, y: 20))
            ],
            pathSubpaths: [[
                ImageEditorPathAnchor(point: CGPoint(x: 12, y: 8)),
                ImageEditorPathAnchor(point: CGPoint(x: 20, y: 8)),
                ImageEditorPathAnchor(point: CGPoint(x: 16, y: 14))
            ]],
            isPathClosed: true
        )
        layer.isVectorMaskEnabled = false
        document.layers = [layer]

        let data = try ImageEditorPSDCodec.encode(document: document)
        let restored = try ImageEditorPSDCodec.decode(data, sourceName: "vector-mask.psd")
        let restoredMask = try #require(restored.layers.first?.vectorMask)

        #expect(restoredMask.kind == .path)
        #expect(restoredMask.isPathClosed)
        #expect(restoredMask.editablePathAnchors.count == 3)
        #expect(restoredMask.editablePathSubpaths.count == 1)
        #expect(!restored.layers[0].isVectorMaskEnabled)
        #expect(abs(restoredMask.editablePathAnchors[1].point.x - 28) < 0.01)
        let report = try ImageEditorPSDCodec.compatibilityReport(data)
        #expect(!report.issues.contains { $0.kind == .vectorRasterized })
    }

    @Test func psdExportPreservesExtraAlphaChannelsAndNames() throws {
        let canvasSize = CGSize(width: 4, height: 4)
        var document = ImageEditorDocument(
            sourceName: "alpha-channel.png",
            image: psdSolidImage(color: .white, size: canvasSize)
        )
        document.alphaChannels = [
            ImageEditorAlphaChannel(
                name: "Exported Selection",
                mask: ImageEditorSelectionMask(
                    width: 4,
                    height: 4,
                    alpha: [
                        0, 64, 128, 255,
                        255, 128, 64, 0,
                        0, 64, 128, 255,
                        255, 128, 64, 0
                    ]
                )
            )
        ]

        let data = try ImageEditorPSDCodec.encode(document: document)
        let restored = try ImageEditorPSDCodec.decode(data, sourceName: "alpha-channel.psd")
        let channel = try #require(restored.alphaChannels.first)

        #expect(restored.alphaChannels.count == 1)
        #expect(channel.name == "Exported Selection")
        #expect(channel.mask.alpha == document.alphaChannels[0].mask.alpha)
    }

    @Test func psdExportPreservesSpotChannelDisplayInfoAndProjectRoundTrip() throws {
        let canvasSize = CGSize(width: 4, height: 4)
        var document = ImageEditorDocument(
            sourceName: "spot-channel.png",
            image: psdSolidImage(color: .white, size: canvasSize)
        )
        let spotColor = ImageEditorPSDSpotColor(
            colorSpace: 0,
            components: [65535, 0, 65535, 0],
            opacity: 49152
        )
        document.alphaChannels = [
            ImageEditorAlphaChannel(
                name: "专色洋红",
                mask: ImageEditorSelectionMask(
                    width: 4,
                    height: 4,
                    alpha: [
                        0, 32, 128, 255,
                        255, 128, 32, 0,
                        0, 32, 128, 255,
                        255, 128, 32, 0
                    ]
                ),
                kind: .spot,
                spotColor: spotColor
            )
        ]

        let data = try ImageEditorPSDCodec.encode(document: document)
        let restored = try ImageEditorPSDCodec.decode(data, sourceName: "spot-channel.psd")
        let channel = try #require(restored.alphaChannels.first)

        #expect(channel.kind == .spot)
        #expect(channel.spotColor == spotColor)
        #expect(channel.mask.alpha == document.alphaChannels[0].mask.alpha)

        let project = try ImageEditorProjectDocument(document: restored)
        let projectRestored = try project.restoredDocument()
        #expect(projectRestored.alphaChannels == restored.alphaChannels)
    }

    @Test func psdExportPreservesBasicEditableTextLayer() throws {
        let canvasSize = CGSize(width: 320, height: 180)
        var document = ImageEditorDocument(
            sourceName: "text-export.png",
            image: psdSolidImage(color: .white, size: canvasSize)
        )
        var content = ImageEditorTextContent(
            text: "Hello Xomo",
            color: .systemBlue,
            fontSize: 24,
            fontFamilyName: "Helvetica",
            point: .zero
        )
        content.isBold = true
        content.isItalic = true
        content.isUnderlined = true
        content.characterSpacing = 1.5
        content.lineSpacing = 4
        content.boxWidth = 180
        content.boxHeight = 48
        content.alignment = .center
        content.leftIndent = 3
        content.rightIndent = 4
        content.firstLineIndent = 2
        let layer = ImageEditorLayer.text(name: "Greeting", origin: CGPoint(x: 24, y: 32), content: content)
        document.layers = [layer]

        let data = try ImageEditorPSDCodec.encode(document: document)
        let restored = try ImageEditorPSDCodec.decode(data, sourceName: "text-export.psd")
        let restoredContent = try #require(restored.layers.first?.textContent)

        #expect(restoredContent.text == content.text)
        #expect(restoredContent.fontFamilyName == content.fontFamilyName)
        #expect(abs(restoredContent.fontSize - content.fontSize) < 0.01)
        #expect(restoredContent.isBold)
        #expect(restoredContent.isItalic)
        #expect(restoredContent.isUnderlined)
        #expect(abs(restoredContent.characterSpacing - content.characterSpacing) < 0.01)
        #expect(abs(restoredContent.lineSpacing - content.lineSpacing) < 0.01)
        #expect(restoredContent.alignment == content.alignment)
        #expect(abs(restoredContent.boxWidth - content.boxWidth) < 0.01)
        #expect(abs(restoredContent.boxHeight - content.boxHeight) < 0.01)
        let report = try ImageEditorPSDCodec.compatibilityReport(data)
        #expect(!report.issues.contains { $0.kind == .textRasterized })
    }

    @Test func psdRejectsUnsupportedBitDepth() throws {
        let document = ImageEditorDocument(
            sourceName: "tiny.png",
            image: psdSolidImage(color: .systemRed, size: CGSize(width: 4, height: 4))
        )
        var data = try ImageEditorPSDCodec.encode(document: document)
        data[22] = 0
        data[23] = 16

        #expect(throws: ImageEditorPSDCodecError.self) {
            try ImageEditorPSDCodec.decode(data, sourceName: "invalid.psd")
        }
    }

    @Test func psdAsyncDecodeKeepsLayerMaterializationEquivalent() async throws {
        let canvasSize = CGSize(width: 24, height: 18)
        var document = ImageEditorDocument(
            sourceName: "async-source.png",
            image: psdSolidImage(color: .white, size: canvasSize)
        )
        document.layers = [
            .background(image: psdSolidImage(color: .systemIndigo, size: canvasSize))
        ]

        let data = try ImageEditorPSDCodec.encode(document: document)
        var didBeginMaterializing = false
        let restored = try await ImageEditorPSDCodec.decodeAsync(
            data,
            sourceName: "async.psd",
            onWillMaterialize: {
                didBeginMaterializing = true
            }
        )

        #expect(didBeginMaterializing)
        #expect(restored.sourceName == "async.psd")
        #expect(restored.canvasSize == canvasSize)
        #expect(restored.layers.count == 1)
    }

    @Test func externalZIPGroupMaskFixturePreservesSupportedStructure() throws {
        let data = try psdFixtureData("zip-group-mask.psd")
        let document = try ImageEditorPSDCodec.decode(data, sourceName: "zip-group-mask.psd")

        #expect(document.canvasSize == CGSize(width: 4, height: 4))
        #expect(document.layers.count == 2)
        let group = try #require(document.layers.first { $0.isGroup })
        let child = try #require(document.layers.first { !$0.isGroup })
        #expect(child.groupID == group.id)
        #expect(group.name == "UI Group")
        #expect(child.name == "Masked Card")
        #expect(child.blendMode == .linearLight)
        #expect(abs(child.opacity - Double(200) / 255) < 0.01)
        #expect(abs(child.fillOpacity - Double(128) / 255) < 0.01)
        #expect(child.locksTransparentPixels)
        #expect(child.locksPixels)
        #expect(child.locksPosition)
        let importedMask = try #require(child.mask)
        #expect(psdMaskAlpha(importedMask, width: 4, height: 4) == [
            255, 255, 0, 0,
            255, 255, 0, 0,
            0, 0, 255, 255,
            0, 0, 255, 255
        ])

        let report = try ImageEditorPSDCodec.compatibilityReport(data)
        #expect(report.layerCount == 2)
        #expect(report.groupCount == 1)
        #expect(report.maskCount == 1)
        #expect(report.compressions.contains(.zip))
        #expect(report.compressions.contains(.zipPrediction))
        #expect(report.issues.map(\.kind) == [.colorProfileIgnored])
    }

    @Test func externalZIPCompositeFixtureDecodesWithoutLayers() throws {
        let data = try psdFixtureData("zip-composite.psd")
        let document = try ImageEditorPSDCodec.decode(data, sourceName: "zip-composite.psd")
        #expect(document.canvasSize == CGSize(width: 4, height: 4))
        #expect(document.layers.count == 1)
        let report = try ImageEditorPSDCodec.compatibilityReport(data)
        #expect(report.compressions == [.zip])
        #expect(report.issues.isEmpty)
    }

    @Test func externalExtraAlphaChannelBecomesEditableChannel() throws {
        let data = try psdFixtureData("extra-alpha.psd")
        let document = try ImageEditorPSDCodec.decode(data, sourceName: "extra-alpha.psd")

        let channel = try #require(document.alphaChannels.first)
        #expect(document.alphaChannels.count == 1)
        #expect(channel.name == "Selection Alpha")
        #expect(channel.mask.width == 4)
        #expect(channel.mask.height == 4)
        #expect(channel.mask.alpha == [
            0, 64, 128, 255,
            0, 64, 128, 255,
            0, 64, 128, 255,
            0, 64, 128, 255
        ])

        let project = try ImageEditorProjectDocument(document: document)
        let restored = try project.restoredDocument()
        #expect(restored.alphaChannels == document.alphaChannels)

        let report = try ImageEditorPSDCodec.compatibilityReport(data)
        #expect(!report.issues.contains { $0.kind == .additionalChannels })
    }

    @Test func compatibilityReportNamesUnsupportedSemanticFeatures() throws {
        let data = try psdFixtureData("unsupported-features.psd")
        let report = try ImageEditorPSDCodec.compatibilityReport(data)
        let kinds = Set(report.issues.map(\.kind))
        #expect(kinds.contains(.textRasterized))
        #expect(kinds.contains(.vectorRasterized))
        #expect(kinds.contains(.smartObjectRasterized))
        #expect(kinds.contains(.layerEffectsRasterized))
        #expect(kinds.contains(.fillLayerRasterized))
        #expect(kinds.contains(.unknownBlendMode))
    }

    @Test func externalEditableTextFixtureBecomesNativeTextLayer() throws {
        let data = try psdFixtureData("editable-text.psd")
        let document = try ImageEditorPSDCodec.decode(data, sourceName: "editable-text.psd")
        let textLayer = try #require(document.layers.first)
        let content = try #require(textLayer.textContent)

        #expect(textLayer.isText)
        #expect(content.text == "Hello Xomo")
        #expect(content.fontFamilyName == "Helvetica")
        #expect(content.fontSize == 24)
        #expect(content.alignment == .center)
        #expect(content.boxWidth == 3)
        #expect(content.boxHeight == 2)
        #expect(content.hasOverflow)
        #expect(content.isBold)
        #expect(content.isItalic)
        #expect(content.isUnderlined)
        #expect(content.isStruckThrough)
        #expect(abs(content.characterSpacing - 2.4) < 0.01)
        #expect(abs(content.lineSpacing - 6) < 0.01)
        #expect(abs(content.leftIndent - 1.5) < 0.01)
        #expect(abs(content.rightIndent - 2.5) < 0.01)
        #expect(abs(content.firstLineIndent + 3) < 0.01)
        #expect(abs(content.color.redComponent - 0.2) < 0.01)
        #expect(abs(content.color.greenComponent - 0.4) < 0.01)
        #expect(abs(content.color.blueComponent - 0.8) < 0.01)

        let report = try ImageEditorPSDCodec.compatibilityReport(data)
        #expect(!report.issues.contains { $0.kind == .textRasterized })

        let project = try ImageEditorProjectDocument(document: document)
        let restoredProject = try project.restoredDocument()
        let restoredContent = try #require(restoredProject.layers.first?.textContent)
        #expect(restoredContent.text == content.text)
        #expect(restoredContent.fontFamilyName == content.fontFamilyName)
        #expect(restoredContent.fontSize == content.fontSize)
        #expect(restoredContent.boxWidth == content.boxWidth)
        #expect(restoredContent.boxHeight == content.boxHeight)
        #expect(restoredContent.hasOverflow == content.hasOverflow)
        #expect(restoredContent.isBold == content.isBold)
        #expect(restoredContent.isItalic == content.isItalic)
        #expect(restoredContent.isUnderlined == content.isUnderlined)
        #expect(restoredContent.isStruckThrough == content.isStruckThrough)
        #expect(abs(restoredContent.characterSpacing - content.characterSpacing) < 0.01)
        #expect(abs(restoredContent.lineSpacing - content.lineSpacing) < 0.01)
        #expect(abs(restoredContent.leftIndent - content.leftIndent) < 0.01)
        #expect(abs(restoredContent.rightIndent - content.rightIndent) < 0.01)
        #expect(abs(restoredContent.firstLineIndent - content.firstLineIndent) < 0.01)
    }

    @Test func externalVectorMaskFixtureBecomesNativeEditablePath() throws {
        let data = try psdFixtureData("vector-mask.psd")
        let document = try ImageEditorPSDCodec.decode(data, sourceName: "vector-mask.psd")
        let layer = try #require(document.layers.first)
        let vectorMask = try #require(layer.vectorMask)

        #expect(!layer.isText)
        #expect(vectorMask.kind == .path)
        #expect(vectorMask.isPathClosed)
        #expect(vectorMask.editablePathAnchors.count == 3)
        #expect(abs(vectorMask.editablePathAnchors[0].point.x - 0.4) < 0.01)
        #expect(abs(vectorMask.editablePathAnchors[0].point.y - 0.4) < 0.01)
        #expect(abs(vectorMask.editablePathAnchors[2].point.x - 2.0) < 0.01)
        #expect(abs(vectorMask.editablePathAnchors[2].point.y - 3.6) < 0.01)

        let report = try ImageEditorPSDCodec.compatibilityReport(data)
        #expect(!report.issues.contains { $0.kind == .vectorRasterized })

        let project = try ImageEditorProjectDocument(document: document)
        let restoredProject = try project.restoredDocument()
        let restoredMask = try #require(restoredProject.layers.first?.vectorMask)
        #expect(restoredMask.editablePathAnchors == vectorMask.editablePathAnchors)
    }

    @Test func externalMultiSubpathVectorMaskPreservesHoleAndProjectRoundTrip() throws {
        let data = try psdFixtureData("vector-mask-multi.psd")
        let document = try ImageEditorPSDCodec.decode(data, sourceName: "vector-mask-multi.psd")
        let layer = try #require(document.layers.first)
        let vectorMask = try #require(layer.vectorMask)

        #expect(vectorMask.kind == .path)
        #expect(vectorMask.isPathClosed)
        #expect(vectorMask.editablePathAnchors.count == 3)
        #expect(vectorMask.editablePathSubpaths.count == 1)
        #expect(vectorMask.editablePathSubpaths.first?.count == 3)

        let report = try ImageEditorPSDCodec.compatibilityReport(data)
        #expect(!report.issues.contains { $0.kind == .vectorRasterized })

        let project = try ImageEditorProjectDocument(document: document)
        let restoredProject = try project.restoredDocument()
        let restoredMask = try #require(restoredProject.layers.first?.vectorMask)
        #expect(restoredMask.editablePathSubpaths == vectorMask.editablePathSubpaths)
    }

    @Test func externalPathResourcesBecomeEditableSavedPathsAndRoundTrip() throws {
        let data = try psdFixtureData("path-resources.psd")
        let document = try ImageEditorPSDCodec.decode(data, sourceName: "path-resources.psd")

        #expect(document.savedPaths.count == 2)
        let closedPath = try #require(document.savedPaths.first { $0.name == "Triangle Path" })
        let openPath = try #require(document.savedPaths.first { $0.name == "Open Guide" })
        #expect(closedPath.isClosed)
        #expect(closedPath.subpaths.count == 1)
        #expect(closedPath.subpaths.first?.count == 3)
        #expect(!openPath.isClosed)
        #expect(openPath.subpaths.first?.count == 2)
        #expect(abs(closedPath.subpaths[0][0].point.x - 0.4) < 0.01)
        #expect(abs(openPath.subpaths[0][1].point.y - 3.2) < 0.01)

        let project = try ImageEditorProjectDocument(document: document)
        let restoredProject = try project.restoredDocument()
        #expect(restoredProject.savedPaths == document.savedPaths)
    }

    @Test func openingPSDPublishesCompatibilityReportForTheCurrentDocument() throws {
        let data = try psdFixtureData("unsupported-features.psd")
        let report = try ImageEditorPSDCodec.compatibilityReport(data)
        let document = try ImageEditorPSDCodec.decode(data, sourceName: "unsupported-features.psd")
        let viewModel = ImageEditorViewModel(
            sourceName: "blank.png",
            image: psdSolidImage(color: .clear, size: CGSize(width: 4, height: 4)),
            onApply: { _ in }
        )

        viewModel.loadExternalPSDDocument(
            document,
            openedFlattened: false,
            compatibilityReport: report
        )

        #expect(viewModel.psdCompatibilityReport == report)
        #expect(viewModel.psdCompatibilityFileName == "unsupported-features.psd")
        #expect(viewModel.isPSDCompatibilityReportPresented)
    }

    @Test func psdRoundTripPreservesGroupsMasksFillLocksAndEveryBlendMode() throws {
        let canvasSize = CGSize(width: 8, height: 8)
        var document = ImageEditorDocument(
            sourceName: "compatibility.psd",
            image: psdSolidImage(color: .white, size: canvasSize)
        )
        var outerGroup = ImageEditorLayer.group(name: "Controls", size: canvasSize)
        outerGroup.blendMode = .passThrough
        outerGroup.isLocked = true
        var innerGroup = ImageEditorLayer.group(name: "Components", size: canvasSize)
        innerGroup.groupID = outerGroup.id
        innerGroup.isGroupExpanded = false

        let blendModes: [ImageEditorBlendMode] = [
            .normal, .dissolve, .multiply, .screen, .overlay, .darken, .lighten,
            .darkerColor, .lighterColor, .colorDodge, .colorBurn, .linearDodge,
            .linearBurn, .subtract, .divide, .softLight, .hardLight, .vividLight,
            .linearLight, .pinLight, .hardMix, .difference, .exclusion, .hue,
            .saturation, .color, .luminosity
        ]
        var layers: [ImageEditorLayer] = []
        for (index, mode) in blendModes.enumerated() {
            var layer = ImageEditorLayer.blank(name: mode.rawValue, size: canvasSize)
            layer.image = psdSolidImage(color: .systemTeal, size: canvasSize)
            layer.frame = CGRect(origin: .zero, size: canvasSize)
            layer.groupID = innerGroup.id
            layer.blendMode = mode
            layer.fillOpacity = Double(index + 1) / Double(blendModes.count + 1)
            layer.locksTransparentPixels = index == 0
            layer.locksPixels = index == 1
            layer.locksPosition = index == 2
            if index == 3 {
                layer.mask = NSImage.alphaMaskImage(
                    width: 8,
                    height: 8,
                    alpha: (0..<64).map { $0.isMultiple(of: 2) ? 255 : 0 }
                )
                layer.isMaskLinked = false
                layer.isMaskEnabled = false
            }
            layers.append(layer)
        }
        document.layers = layers + [innerGroup, outerGroup]

        let restored = try ImageEditorPSDCodec.decode(
            ImageEditorPSDCodec.encode(document: document),
            sourceName: "compatibility-roundtrip.psd"
        )
        let restoredOuterGroup = try #require(restored.layers.first { $0.name == "Controls" })
        let restoredInnerGroup = try #require(restored.layers.first { $0.name == "Components" })
        #expect(restoredOuterGroup.isGroup)
        #expect(restoredOuterGroup.isLocked)
        #expect(restoredInnerGroup.isGroup)
        #expect(!restoredInnerGroup.isGroupExpanded)
        #expect(restoredInnerGroup.groupID == restoredOuterGroup.id)
        let restoredChildren = restored.layers.filter { !$0.isGroup }
        #expect(restoredChildren.map(\.blendMode) == blendModes)
        #expect(restoredChildren.allSatisfy { $0.groupID == restoredInnerGroup.id })
        #expect(restoredChildren[0].locksTransparentPixels)
        #expect(restoredChildren[1].locksPixels)
        #expect(restoredChildren[2].locksPosition)
        #expect(restoredChildren[3].mask != nil)
        #expect(!restoredChildren[3].isMaskLinked)
        #expect(!restoredChildren[3].isMaskEnabled)
        #expect(psdMaskAlpha(try #require(restoredChildren[3].mask), width: 8, height: 8) ==
            (0..<64).map { $0.isMultiple(of: 2) ? 255 : 0 }
        )
        for (index, layer) in restoredChildren.enumerated() {
            let expected = Double(index + 1) / Double(blendModes.count + 1)
            #expect(abs(layer.fillOpacity - expected) < 0.01)
        }
    }

    @Test func psdRoundTripPreservesClippingMaskChainAndProjectState() throws {
        let canvasSize = CGSize(width: 16, height: 12)
        var document = ImageEditorDocument(
            sourceName: "clipping-chain.psd",
            image: psdSolidImage(color: .white, size: canvasSize)
        )
        var base = ImageEditorLayer.blank(name: "Card Shape", size: canvasSize)
        base.image = psdSolidImage(color: .systemBlue, size: canvasSize)
        base.frame = CGRect(origin: .zero, size: canvasSize)

        var firstClip = ImageEditorLayer.blank(name: "Card Highlight", size: canvasSize)
        firstClip.image = psdSolidImage(color: .white, size: canvasSize)
        firstClip.frame = CGRect(origin: .zero, size: canvasSize)
        firstClip.opacity = 0.6
        firstClip.isClippingMask = true

        var secondClip = ImageEditorLayer.blank(name: "Card Texture", size: canvasSize)
        secondClip.image = psdSolidImage(color: .systemOrange, size: canvasSize)
        secondClip.frame = CGRect(origin: .zero, size: canvasSize)
        secondClip.isClippingMask = true

        document.layers = [base, firstClip, secondClip]
        document.selectedLayerID = secondClip.id
        document.selectedLayerIDs = [secondClip.id]

        let restored = try ImageEditorPSDCodec.decode(
            ImageEditorPSDCodec.encode(document: document),
            sourceName: "clipping-chain.psd"
        )
        #expect(restored.layers.map(\.name) == ["Card Shape", "Card Highlight", "Card Texture"])
        #expect(!restored.layers[0].isClippingMask)
        #expect(restored.layers[1].isClippingMask)
        #expect(restored.layers[2].isClippingMask)
        #expect(restored.clippingBaseIndex(forLayerAt: 1) == 0)
        #expect(restored.clippingBaseIndex(forLayerAt: 2) == 0)
        #expect(abs(restored.layers[1].opacity - 0.6) < 0.01)

        let project = try ImageEditorProjectDocument(document: restored)
        let projectRestored = try project.restoredDocument()
        #expect(projectRestored.layers.map(\.isClippingMask) == [false, true, true])
        #expect(projectRestored.selectedLayerID == restored.selectedLayerID)
        #expect(projectRestored.selectedLayerIDs == restored.selectedLayerIDs)
        #expect(projectRestored.clippingBaseIndex(forLayerAt: 2) == 0)
    }
}

private func psdFixtureData(_ name: String) throws -> Data {
    let directory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/PSD", isDirectory: true)
    return try Data(contentsOf: directory.appendingPathComponent(name))
}

private func psdMaskAlpha(_ image: NSImage, width: Int, height: Int) -> [UInt8] {
    guard let representation = NSBitmapImageRep(data: image.tiffRepresentation ?? Data()) else { return [] }
    return (0..<height).flatMap { row in
        (0..<width).map { column in
            let imageY = height - row - 1
            return UInt8(((representation.colorAt(x: column, y: imageY)?.alphaComponent ?? 0) * 255).rounded())
        }
    }
}

private func psdSolidImage(color: NSColor, size: CGSize) -> NSImage {
    NSImage.rendered(size: size) { rect in
        color.setFill()
        rect.fill()
    } ?? NSImage.transparent(size: size)
}
