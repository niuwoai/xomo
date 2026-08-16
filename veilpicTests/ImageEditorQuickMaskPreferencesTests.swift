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
        #expect((quickMaskColor(maskedOverlay, x: 0, y: 0)?.alphaComponent ?? 0) < 0.05)
        #expect((quickMaskColor(maskedOverlay, x: 1, y: 0)?.alphaComponent ?? 0) > 0.2)

        let selectedOverlay = try #require(
            selection.quickMaskOverlayImage(
                canvasSize: CGSize(width: 2, height: 1),
                color: .systemBlue,
                opacity: 0.75,
                target: .selectedAreas
            )
        )
        let selectedColor = try #require(
            quickMaskColor(selectedOverlay, x: 0, y: 0)?.usingColorSpace(.deviceRGB)
        )
        #expect(selectedColor.blueComponent > 0.9)
        #expect(selectedColor.alphaComponent > 0.7)
        #expect((quickMaskColor(selectedOverlay, x: 1, y: 0)?.alphaComponent ?? 0) < 0.05)
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
        let image = NSImage.transparent(size: CGSize(width: 8, height: 6))
        let firstViewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: image,
            preferencesDefaults: defaults
        ) { _ in }

        firstViewModel.createRectSelection(from: CGPoint(x: 1, y: 1), to: CGPoint(x: 5, y: 4))
        firstViewModel.toggleQuickMaskMode()
        firstViewModel.setQuickMaskOverlayTarget(.selectedAreas)
        firstViewModel.setQuickMaskOverlayColor(.systemBlue)
        firstViewModel.setQuickMaskOverlayOpacity(0.25)

        let overlay = try #require(firstViewModel.quickMaskOverlayImage)
        let selectedColor = try #require(
            quickMaskColor(overlay, x: 2, y: 2)?.usingColorSpace(.deviceRGB)
        )
        #expect(selectedColor.blueComponent > 0.9)
        #expect(selectedColor.alphaComponent > 0.2)
        #expect((quickMaskColor(overlay, x: 7, y: 2)?.alphaComponent ?? 0) < 0.05)

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

    @Test func optionClickSwitchesOverlayTargetWithoutTogglingQuickMaskMode() throws {
        let (defaults, suiteName) = temporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let viewModel = ImageEditorViewModel(
            sourceName: "quick-mask-control.png",
            image: NSImage.transparent(size: CGSize(width: 8, height: 6)),
            preferencesDefaults: defaults
        ) { _ in }
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        #expect(
            ImageEditorQuickMaskControlAction.resolve(modifierFlags: [.option])
                == .toggleOverlayTarget
        )
        #expect(
            ImageEditorQuickMaskControlAction.resolve(modifierFlags: [.option, .capsLock])
                == .toggleOverlayTarget
        )
        #expect(
            ImageEditorQuickMaskControlAction.resolve(modifierFlags: [.option, .shift])
                == .toggleMode
        )
        #expect(ImageEditorQuickMaskControlAction.resolve(modifierFlags: []) == .toggleMode)

        viewModel.activateQuickMaskControl(modifierFlags: [.option])
        #expect(viewModel.quickMaskOverlayTarget == .selectedAreas)
        #expect(!viewModel.isQuickMaskMode)
        #expect(viewModel.document.selection == nil)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)

        viewModel.activateQuickMaskControl(modifierFlags: [])
        #expect(viewModel.isQuickMaskMode)
        let selection = viewModel.document.selection

        viewModel.activateQuickMaskControl(modifierFlags: [.option])
        #expect(viewModel.quickMaskOverlayTarget == .maskedAreas)
        #expect(viewModel.isQuickMaskMode)
        #expect(viewModel.document.selection == selection)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
    }

    private func temporaryDefaults() -> (UserDefaults, String) {
        let suiteName = "ImageEditorQuickMaskPreferencesTests.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suiteName) ?? .standard, suiteName)
    }

    private func quickMaskColor(_ image: NSImage, x: Int, y: Int) -> NSColor? {
        guard let bitmap = image.representations.compactMap({ $0 as? NSBitmapImageRep }).first,
              x >= 0,
              y >= 0,
              x < bitmap.pixelsWide,
              y < bitmap.pixelsHigh
        else { return nil }
        return bitmap.colorAt(x: x, y: bitmap.pixelsHigh - y - 1)
    }
}
