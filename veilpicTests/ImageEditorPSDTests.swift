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
}

private func psdSolidImage(color: NSColor, size: CGSize) -> NSImage {
    NSImage.rendered(size: size) { rect in
        color.setFill()
        rect.fill()
    } ?? NSImage.transparent(size: size)
}
