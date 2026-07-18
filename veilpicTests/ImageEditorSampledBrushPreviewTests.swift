//
//  ImageEditorSampledBrushPreviewTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/19.
//

import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorSampledBrushPreviewTests {
    @Test func clonePreviewKeepsAlignedOffsetAndResetsNonAlignedOffset() {
        let viewModel = sampledBrushViewModel()
        viewModel.setCloneSource(at: CGPoint(x: 10, y: 15))

        let firstPreview = viewModel.sampledBrushPreviewSourcePoint(
            for: .cloneStamp,
            strokeStart: CGPoint(x: 50, y: 15),
            currentDestination: CGPoint(x: 55, y: 15)
        )
        #expect(firstPreview == CGPoint(x: 15, y: 15))

        viewModel.cloneStamp(points: [CGPoint(x: 50, y: 15), CGPoint(x: 55, y: 15)])
        let nextAlignedPreview = viewModel.sampledBrushPreviewSourcePoint(
            for: .cloneStamp,
            strokeStart: CGPoint(x: 70, y: 15),
            currentDestination: CGPoint(x: 75, y: 15)
        )
        #expect(nextAlignedPreview == CGPoint(x: 35, y: 15))

        viewModel.isCloneStampAligned = false
        let nonAlignedPreview = viewModel.sampledBrushPreviewSourcePoint(
            for: .cloneStamp,
            strokeStart: CGPoint(x: 70, y: 15),
            currentDestination: CGPoint(x: 75, y: 15)
        )
        #expect(nonAlignedPreview == CGPoint(x: 15, y: 15))
    }

    @Test func healingPreviewUsesItsOwnSourceAndRejectsOtherTools() {
        let viewModel = sampledBrushViewModel()
        viewModel.isHealingBrushAligned = false
        viewModel.setHealingSource(at: CGPoint(x: 12, y: 14))

        let preview = viewModel.sampledBrushPreviewSourcePoint(
            for: .healingBrush,
            strokeStart: CGPoint(x: 60, y: 20),
            currentDestination: CGPoint(x: 66, y: 24)
        )

        #expect(preview == CGPoint(x: 18, y: 18))
        #expect(viewModel.sampledBrushPreviewSourcePoint(
            for: .brush,
            strokeStart: .zero,
            currentDestination: CGPoint(x: 10, y: 10)
        ) == nil)
    }

    @Test func canvasOverlayUsesLiveStrokeEndpointsButNotSourceSetting() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let propertyStart = try #require(source.range(of: "private var sampledBrushSourcePoint: CGPoint?"))
        let propertyEnd = try #require(
            source[propertyStart.upperBound...].range(of: "private func canvasGesture")
        )
        let propertySource = source[propertyStart.lowerBound..<propertyEnd.lowerBound]

        #expect(propertySource.contains("let strokeStart = dragPoints.first"))
        #expect(propertySource.contains("let currentDestination = dragPoints.last"))
        #expect(propertySource.contains("sampledBrushPreviewSourcePoint("))
        #expect(propertySource.contains("canvasModifierFlags.contains(.option)"))
        #expect(propertySource.contains("viewModel.isSettingCloneSource"))
        #expect(propertySource.contains("viewModel.isSettingHealingSource"))
    }

    private func sampledBrushViewModel() -> ImageEditorViewModel {
        let size = CGSize(width: 100, height: 30)
        let image = NSImage.rendered(size: size) { rect in
            NSColor.systemBlue.setFill()
            rect.fill()
            NSColor.systemRed.setFill()
            CGRect(x: 6, y: 10, width: 18, height: 10).fill()
        } ?? NSImage.transparent(size: size)
        return ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
    }

    private static func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
