//
//  ImageEditorBrushPresetUsageTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/8/22.
//

import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorBrushPresetUsageTests {
    @Test func usagePreferencesNormalizeAndRoundTripFavoriteAndRecentIDs() {
        let context = makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }
        let preferences = ImageEditorBrushPresetUsagePreferences(
            favoriteIDs: ["built-in-18-px", "", "built-in-18-px", "custom-one"],
            recentIDs: ["custom-9", "custom-8", "custom-9", "", "custom-7", "custom-6", "custom-5", "custom-4", "custom-3", "custom-2", "custom-1"]
        )

        preferences.save(to: context.defaults)
        let restored = ImageEditorBrushPresetUsagePreferences.load(from: context.defaults)

        #expect(restored.favoriteIDs == ["built-in-18-px", "custom-one"])
        #expect(restored.recentIDs == ["custom-9", "custom-8", "custom-7", "custom-6", "custom-5", "custom-4", "custom-3", "custom-2"])
    }

    @Test func favoritesAndRecentUsesPersistWithoutDocumentTransactionsAndPruneOnDelete() throws {
        let context = makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }
        let viewModel = makeViewModel(defaults: context.defaults)
        viewModel.brushSize = 37
        let customPreset = try #require(viewModel.createBrushPresetFromCurrentSettings())
        let builtInPreset = try #require(ImageEditorBrushPreset.defaultPresets.first)
        let documentBeforeUsage = transactionSignature(viewModel.document)
        let undoBeforeUsage = viewModel.undoStack.map(transactionSignature)
        let redoBeforeUsage = viewModel.redoStack.map(transactionSignature)

        #expect(viewModel.setBrushPresetFavorite(id: builtInPreset.id, isFavorite: true))
        #expect(viewModel.setBrushPresetFavorite(id: customPreset.id, isFavorite: true))
        viewModel.applyBrushPreset(builtInPreset)
        viewModel.applyBrushPreset(customPreset)

        #expect(viewModel.favoriteBrushPresetIDs == [builtInPreset.id, customPreset.id])
        #expect(viewModel.favoriteBrushPresets.map(\.id) == [builtInPreset.id, customPreset.id])
        #expect(viewModel.recentBrushPresetIDs == [customPreset.id, builtInPreset.id])
        #expect(viewModel.recentBrushPresets.map(\.id) == [customPreset.id, builtInPreset.id])
        #expect(transactionSignature(viewModel.document) == documentBeforeUsage)
        #expect(viewModel.undoStack.map(transactionSignature) == undoBeforeUsage)
        #expect(viewModel.redoStack.map(transactionSignature) == redoBeforeUsage)

        let reopened = makeViewModel(defaults: context.defaults)
        #expect(reopened.favoriteBrushPresetIDs == [builtInPreset.id, customPreset.id])
        #expect(reopened.recentBrushPresetIDs == [customPreset.id, builtInPreset.id])
        let restoredCustomPreset = try #require(
            reopened.customBrushPresets.first(where: { $0.id == customPreset.id })
        )
        reopened.deleteBrushPreset(restoredCustomPreset)
        #expect(reopened.favoriteBrushPresetIDs == [builtInPreset.id])
        #expect(reopened.recentBrushPresetIDs == [builtInPreset.id])

        let afterDeletion = makeViewModel(defaults: context.defaults)
        #expect(afterDeletion.favoriteBrushPresetIDs == [builtInPreset.id])
        #expect(afterDeletion.recentBrushPresetIDs == [builtInPreset.id])
    }

    @Test func recentUsageIsDeduplicatedCappedAndMostRecentFirst() throws {
        let context = makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }
        let viewModel = makeViewModel(defaults: context.defaults)
        for index in 0..<5 {
            viewModel.brushSize = CGFloat(20 + index)
            _ = try #require(viewModel.createBrushPresetFromCurrentSettings())
        }
        let ids = viewModel.brushPresets.map(\.id)
        #expect(ids.count == 10)

        for id in ids {
            let preset = try #require(viewModel.brushPresets.first(where: { $0.id == id }))
            viewModel.applyBrushPreset(preset)
        }
        #expect(viewModel.recentBrushPresetIDs == Array(ids.reversed().prefix(8)))

        let reusedID = ids[3]
        let reusedPreset = try #require(
            viewModel.brushPresets.first(where: { $0.id == reusedID })
        )
        viewModel.applyBrushPreset(reusedPreset)
        #expect(viewModel.recentBrushPresetIDs.first == reusedID)
        #expect(viewModel.recentBrushPresetIDs.filter { $0 == reusedID }.count == 1)

        let reopened = makeViewModel(defaults: context.defaults)
        #expect(reopened.recentBrushPresetIDs == viewModel.recentBrushPresetIDs)
    }

    @Test func optionsAndWindowMenusExposeFavoriteAndRecentBrushPresets() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let options = try source(root, "veilpic/ImageEditorView.swift")
        let windowMenu = try source(root, "veilpic/ImageEditorMenuBar.swift")

        for source in [options, windowMenu] {
            #expect(source.contains("favoriteBrushPresets"))
            #expect(source.contains("recentBrushPresets"))
            #expect(source.contains("setBrushPresetFavorite"))
            #expect(source.contains("imageEditor.brushPreset.favoriteSection"))
            #expect(source.contains("imageEditor.brushPreset.recentSection"))
        }
    }

    private func source(_ root: URL, _ path: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    private func transactionSignature(
        _ document: ImageEditorDocument
    ) -> DocumentTransactionSignature {
        DocumentTransactionSignature(
            canvasSize: document.canvasSize,
            layerIDs: document.layers.map(\.id),
            layerFrames: document.layers.map(\.frame),
            layerImageData: document.layers.map { $0.image.tiffRepresentation },
            layerMaskData: document.layers.map { $0.mask?.tiffRepresentation },
            selectedLayerID: document.selectedLayerID,
            selectedLayerIDs: document.selectedLayerIDs,
            historyIDs: document.history.map(\.id),
            historyTitles: document.history.map(\.title),
            historyDates: document.history.map(\.createdAt)
        )
    }

    private func makeContext() -> (suiteName: String, defaults: UserDefaults) {
        let suiteName = "ImageEditorBrushPresetUsageTests.\(UUID().uuidString)"
        return (suiteName, UserDefaults(suiteName: suiteName) ?? .standard)
    }

    private func makeViewModel(defaults: UserDefaults) -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "brush-preset-usage.png",
            image: NSImage.transparent(size: NSSize(width: 48, height: 36)),
            preferencesDefaults: defaults
        ) { _ in }
    }

    private struct DocumentTransactionSignature: Equatable {
        let canvasSize: CGSize
        let layerIDs: [UUID]
        let layerFrames: [CGRect]
        let layerImageData: [Data?]
        let layerMaskData: [Data?]
        let selectedLayerID: UUID?
        let selectedLayerIDs: Set<UUID>
        let historyIDs: [UUID]
        let historyTitles: [String]
        let historyDates: [Date]
    }
}
