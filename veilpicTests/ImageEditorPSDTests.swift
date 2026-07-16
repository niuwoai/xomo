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
