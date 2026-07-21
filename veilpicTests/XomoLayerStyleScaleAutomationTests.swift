//
//  XomoLayerStyleScaleAutomationTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/22.
//

import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct XomoLayerStyleScaleAutomationTests {
    @Test func registryReportsActualEffectScaleUpdatesAndRejectsRepeatedValue() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "automation",
            image: NSImage.transparent(size: CGSize(width: 320, height: 240))
        ) { _ in }
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }

        let firstID = try #require(viewModel.document.selectedLayerID)
        let firstIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[firstIndex].style.strokeEnabled = true

        viewModel.addLayer()
        let matchingID = try #require(viewModel.document.selectedLayerID)
        let matchingIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[matchingIndex].style.shadowEnabled = true
        viewModel.document.layers[matchingIndex].style.effectScale = 2

        viewModel.addLayer()
        let lockedID = try #require(viewModel.document.selectedLayerID)
        let lockedIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[lockedIndex].style.outerGlowEnabled = true
        viewModel.document.layers[lockedIndex].isLocked = true
        viewModel.document.selectedLayerID = firstID
        viewModel.document.selectedLayerIDs = [firstID, matchingID, lockedID]
        let historyBeforeScale = viewModel.document.history.count

        let scale = registry.execute(request(value: 200))
        #expect(scale.ok)
        #expect(scale.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[firstIndex].style.effectScale == 2)
        #expect(viewModel.document.layers[matchingIndex].style.effectScale == 2)
        #expect(viewModel.document.layers[lockedIndex].style.effectScale == 1)
        #expect(viewModel.document.history.count == historyBeforeScale + 1)

        let historyAfterScale = viewModel.document.history.count
        let repeatedScale = registry.execute(request(value: 200))
        #expect(!repeatedScale.ok)
        #expect(viewModel.document.history.count == historyAfterScale)

        let clampedScale = registry.execute(request(value: 2_000))
        #expect(clampedScale.ok)
        #expect(clampedScale.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[firstIndex].style.effectScale == 10)
        #expect(viewModel.document.layers[matchingIndex].style.effectScale == 10)
        #expect(viewModel.document.layers[lockedIndex].style.effectScale == 1)
    }

    private func request(value: Double) -> XomoAutomationWireRequest {
        XomoAutomationWireRequest(
            token: "test",
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("effectScale"),
                "value": .number(value)
            ]
        )
    }
}
