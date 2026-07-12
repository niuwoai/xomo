//
//  ImageEditorQuickMaskPreferencesTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/12.
//

import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorQuickMaskPreferencesTests {
    @Test func overlayCanIndicateMaskedOrSelectedAreas() throws {
        let mask = ImageEditorSelectionMask(width: 2, height: 1, alpha: [255, 0])
        let selection = ImageEditorSelection.raster(
            mask: mask,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1)
        )

        let maskedOverlay = try #require(
            selection.quickMaskOverlayImage(
                canvasSize: CGSize(width: 2, height: 1),
                color: .systemGreen,
                opacity: 0.25,
                target: .maskedAreas
            )
        )
        #expect((maskedOverlay.color(at: CGPoint(x: 0, y: 0))?.alphaComponent ?? 0) < 0.05)
        #expect((maskedOverlay.color(at: CGPoint(x: 1, y: 0))?.alphaComponent ?? 0) > 0.2)

        let selectedOverlay = try #require(
            selection.quickMaskOverlayImage(
                canvasSize: CGSize(width: 2, height: 1),
                color: .systemBlue,
                opacity: 0.75,
                target: .selectedAreas
            )
        )
        let selectedColor = try #require(
            selectedOverlay.color(at: CGPoint(x: 0, y: 0))?.usingColorSpace(.deviceRGB)
        )
        #expect(selectedColor.blueComponent > 0.9)
        #expect(selectedColor.alphaComponent > 0.7)
        #expect((selectedOverlay.color(at: CGPoint(x: 1, y: 0))?.alphaComponent ?? 0) < 0.05)
    }

    @Test func preferencesRoundTripAndClampOpacity() throws {
        let (defaults, suiteName) = temporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = ImageEditorQuickMaskPreferences(
            target: .selectedAreas,
            color: ImageEditorProjectColor(color: .systemPurple),
            opacity: 2
        )

        preferences.save(to: defaults)
        let loaded = ImageEditorQuickMaskPreferences.load(from: defaults)

        #expect(loaded.target == .selectedAreas)
        #expect(loaded.opacity == ImageEditorQuickMaskPreferences.maximumOpacity)
        #expect(loaded.color == ImageEditorProjectColor(color: .systemPurple))

        defaults.set(Data("invalid".utf8), forKey: ImageEditorQuickMaskPreferences.storageKey)
        #expect(ImageEditorQuickMaskPreferences.load(from: defaults) == .defaultValue)
    }

    @Test func viewModelPersistsOptionsAndRefreshesActiveOverlay() throws {
        let (defaults, suiteName) = temporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let image = NSImage.transparent(size: CGSize(width: 4, height: 2))
        let firstViewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: image,
            preferencesDefaults: defaults
        ) { _ in }

        firstViewModel.createRectSelection(from: .zero, to: CGPoint(x: 2, y: 2))
        firstViewModel.toggleQuickMaskMode()
        firstViewModel.setQuickMaskOverlayTarget(.selectedAreas)
        firstViewModel.setQuickMaskOverlayColor(.systemBlue)
        firstViewModel.setQuickMaskOverlayOpacity(0.25)

        let overlay = try #require(firstViewModel.quickMaskOverlayImage)
        let selectedColor = try #require(
            overlay.color(at: CGPoint(x: 1, y: 1))?.usingColorSpace(.deviceRGB)
        )
        #expect(selectedColor.blueComponent > 0.9)
        #expect(selectedColor.alphaComponent > 0.2)
        #expect((overlay.color(at: CGPoint(x: 3, y: 1))?.alphaComponent ?? 0) < 0.05)

        let restoredViewModel = ImageEditorViewModel(
            sourceName: "restored.png",
            image: image,
            preferencesDefaults: defaults
        ) { _ in }
        #expect(restoredViewModel.quickMaskOverlayTarget == .selectedAreas)
        #expect(restoredViewModel.quickMaskOverlayOpacity == 0.25)
        #expect(ImageEditorProjectColor(color: restoredViewModel.quickMaskOverlayColor) == ImageEditorProjectColor(color: .systemBlue))

        restoredViewModel.setQuickMaskOverlayOpacity(0)
        #expect(restoredViewModel.quickMaskOverlayOpacity == CGFloat(ImageEditorQuickMaskPreferences.minimumOpacity))
    }

    private func temporaryDefaults() -> (UserDefaults, String) {
        let suiteName = "ImageEditorQuickMaskPreferencesTests.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suiteName) ?? .standard, suiteName)
    }
}
