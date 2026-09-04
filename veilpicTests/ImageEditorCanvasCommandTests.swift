//
//  ImageEditorCanvasCommandTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/9.
//

import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorCanvasCommandTests {
    @Test
    func imageResizeScalesLayersSelectionsAndChannels() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemBlue, size: NSSize(width: 100, height: 80))
        ) { _ in }
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 10, y: 12, width: 20, height: 16)
        viewModel.document.layers[layerIndex].image = NSImage.transparent(size: CGSize(width: 20, height: 16))
        viewModel.document.layers[layerIndex].mask = NSImage.opaqueMask(size: CGSize(width: 20, height: 16))
        viewModel.document.layers[layerIndex].style.strokePatternOffset = CGSize(width: 3, height: -4)
        viewModel.document.layers[layerIndex].style.patternOverlayOffset = CGSize(width: -5, height: 7)
        viewModel.document.layers[layerIndex].vectorMask = ImageEditorShapeContent(
            kind: .path,
            fillColor: .white,
            fillOpacity: 1,
            strokeColor: .black,
            strokeWidth: 2,
            strokeOpacity: 1,
            pathPoints: [CGPoint(x: 4, y: 5), CGPoint(x: 12, y: 10)]
        )
        viewModel.document.selection = .rectangle(CGRect(x: 5, y: 8, width: 30, height: 20))
        viewModel.document.alphaChannels = [
            ImageEditorAlphaChannel(
                name: "Alpha 1",
                mask: ImageEditorSelectionMask(width: 100, height: 80, alpha: [UInt8](repeating: 255, count: 8_000))
            )
        ]

        viewModel.resizeImage(to: CGSize(width: 200, height: 160))

        let resizedLayer = viewModel.document.layers[layerIndex]
        #expect(viewModel.document.canvasSize == CGSize(width: 200, height: 160))
        #expect(resizedLayer.frame == CGRect(x: 20, y: 24, width: 40, height: 32))
        #expect(resizedLayer.image.size == CGSize(width: 40, height: 32))
        #expect(resizedLayer.mask?.size == CGSize(width: 40, height: 32))
        #expect(resizedLayer.style.strokePatternOffset == CGSize(width: 6, height: -8))
        #expect(resizedLayer.style.patternOverlayOffset == CGSize(width: -10, height: 14))
        #expect(resizedLayer.vectorMask?.pathPoints.first == CGPoint(x: 8, y: 10))
        #expect(viewModel.document.selection?.points.first == CGPoint(x: 10, y: 16))
        #expect(viewModel.document.alphaChannels.first?.mask.width == 200)
        #expect(viewModel.document.alphaChannels.first?.mask.height == 160)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.imageResize"))
        #expect(viewModel.canUndo)
    }

    @Test
    func imageResizeScalesHotspotsAtomicallyAndPreservesIdentitySelectionAndPanelState() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "hotspots.png",
            image: testImage(color: .systemBlue, size: NSSize(width: 100, height: 80))
        ) { _ in }
        let firstID = UUID()
        let edgeID = UUID()
        let originalHotspots = [
            ImageEditorHotspot(
                id: firstID,
                name: "Primary CTA",
                frame: CGRect(x: 30.4, y: 27.6, width: -20.2, height: -15.2),
                url: "https://example.com/primary"
            ),
            ImageEditorHotspot(
                id: edgeID,
                name: "Edge CTA",
                frame: CGRect(x: 89.6, y: 69.2, width: 10.4, height: 10.8),
                url: "https://example.com/edge"
            )
        ]
        viewModel.document.hotspots = originalHotspots
        viewModel.selectedHotspotID = edgeID
        viewModel.isHotspotsPanelVisible = true

        // Seed both history directions so a successful resize must replace Redo
        // with exactly one new document transaction.
        viewModel.pushUndo()
        viewModel.document.areGuidesVisible.toggle()
        viewModel.pushUndo()
        viewModel.document.areRulersVisible.toggle()
        viewModel.undo()
        let beforeResize = try projectData(viewModel.document)
        let undoCountBefore = viewModel.undoStack.count
        let historyCountBefore = viewModel.document.history.count
        #expect(!viewModel.redoStack.isEmpty)

        viewModel.resizeImage(to: CGSize(width: 150, height: 40))

        let resizedHotspots = viewModel.document.hotspots
        #expect(resizedHotspots.map(\.id) == [firstID, edgeID])
        #expect(resizedHotspots.map(\.name) == originalHotspots.map(\.name))
        #expect(resizedHotspots.map(\.url) == originalHotspots.map(\.url))
        #expect(resizedHotspots[0].frame == CGRect(x: 15, y: 6, width: 31, height: 8))
        #expect(resizedHotspots[1].frame == CGRect(x: 134, y: 34, width: 16, height: 6))
        #expect(viewModel.undoStack.count == undoCountBefore + 1)
        #expect(viewModel.redoStack.isEmpty)
        #expect(viewModel.document.history.count == historyCountBefore + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.imageResize"))
        #expect(viewModel.selectedHotspotID == edgeID)
        #expect(viewModel.isHotspotsPanelVisible)

        let afterResize = try projectData(viewModel.document)
        viewModel.undo()
        #expect(try projectData(viewModel.document) == beforeResize)
        #expect(viewModel.selectedHotspotID == edgeID)
        #expect(viewModel.isHotspotsPanelVisible)

        viewModel.redo()
        #expect(try projectData(viewModel.document) == afterResize)
        #expect(viewModel.selectedHotspotID == edgeID)
        #expect(viewModel.isHotspotsPanelVisible)
    }

    @Test
    func imageResizeRejectsUnchangedInvalidTargetsAndInvalidHotspotsWithoutPartialMutation() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "atomic-hotspots.png",
            image: testImage(color: .systemGreen, size: NSSize(width: 100, height: 80))
        ) { _ in }
        let hotspotID = UUID()
        viewModel.document.hotspots = [
            ImageEditorHotspot(
                id: hotspotID,
                name: "Atomic CTA",
                frame: CGRect(x: 12, y: 10, width: 30, height: 20),
                url: "https://example.com/atomic"
            )
        ]
        viewModel.selectedHotspotID = hotspotID
        viewModel.isHotspotsPanelVisible = true
        viewModel.pushUndo()
        viewModel.document.areGuidesVisible.toggle()
        viewModel.pushUndo()
        viewModel.document.areRulersVisible.toggle()
        viewModel.undo()

        let validBaseline = try projectTransactionSnapshot(viewModel)
        for targetSize in [
            CGSize(width: 100, height: 80),
            CGSize(width: 7, height: 80),
            CGSize(width: CGFloat.nan, height: 80)
        ] {
            viewModel.resizeImage(to: targetSize)
            #expect(try projectTransactionSnapshot(viewModel) == validBaseline)
            #expect(viewModel.statusText == L10n.text("imageEditor.status.resizeInvalid"))
            #expect(viewModel.selectedHotspotID == hotspotID)
            #expect(viewModel.isHotspotsPanelVisible)
        }

        let validHotspot = viewModel.document.hotspots[0]
        let invalidHotspotCases: [(hotspot: ImageEditorHotspot, targetSize: CGSize)] = [
            (
                ImageEditorHotspot(
                    name: "Invalid zero-area hotspot",
                    frame: CGRect(x: 60, y: 20, width: 0, height: 12),
                    url: "https://example.com/invalid-zero"
                ),
                CGSize(width: 200, height: 160)
            ),
            (
                ImageEditorHotspot(
                    name: "Invalid NaN hotspot",
                    frame: CGRect(x: CGFloat.nan, y: 20, width: 12, height: 12),
                    url: "https://example.com/invalid-nan"
                ),
                CGSize(width: 200, height: 160)
            ),
            (
                ImageEditorHotspot(
                    name: "Invalid infinity hotspot",
                    frame: CGRect(x: 60, y: CGFloat.infinity, width: 12, height: 12),
                    url: "https://example.com/invalid-infinity"
                ),
                CGSize(width: 200, height: 160)
            ),
            (
                ImageEditorHotspot(
                    name: "Finite hotspot that overflows while scaling",
                    frame: CGRect(
                        x: CGFloat.greatestFiniteMagnitude / 2,
                        y: CGFloat.greatestFiniteMagnitude / 2,
                        width: CGFloat.greatestFiniteMagnitude / 4,
                        height: CGFloat.greatestFiniteMagnitude / 4
                    ),
                    url: "https://example.com/invalid-overflow"
                ),
                CGSize(width: 12_000, height: 12_000)
            )
        ]

        for invalidCase in invalidHotspotCases {
            // Replace the invalid item on every pass so an earlier failure
            // cannot conceal validation of a later numeric domain.
            viewModel.document.hotspots = [validHotspot, invalidCase.hotspot]
            let invalidHotspotBaseline = try projectTransactionSnapshot(viewModel)

            viewModel.resizeImage(to: invalidCase.targetSize)

            #expect(try projectTransactionSnapshot(viewModel) == invalidHotspotBaseline)
            #expect(viewModel.statusText == L10n.text("imageEditor.status.resizeInvalid"))
            #expect(viewModel.selectedHotspotID == hotspotID)
            #expect(viewModel.isHotspotsPanelVisible)
        }
    }

    @Test
    func canvasResizeOffsetsLayersSelectionsAndChannelsWithoutResamplingLayerPixels() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemRed, size: NSSize(width: 100, height: 80))
        ) { _ in }
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 10, y: 12, width: 20, height: 16)
        viewModel.document.layers[layerIndex].image = NSImage.transparent(size: CGSize(width: 20, height: 16))
        viewModel.document.selection = .rectangle(CGRect(x: 5, y: 8, width: 30, height: 20))
        viewModel.document.alphaChannels = [
            ImageEditorAlphaChannel(
                name: "Alpha 1",
                mask: ImageEditorSelectionMask(width: 100, height: 80, alpha: [UInt8](repeating: 255, count: 8_000))
            )
        ]

        viewModel.resizeCanvas(to: CGSize(width: 140, height: 100), anchor: .center)

        let resizedLayer = viewModel.document.layers[layerIndex]
        #expect(viewModel.document.canvasSize == CGSize(width: 140, height: 100))
        #expect(resizedLayer.frame == CGRect(x: 30, y: 22, width: 20, height: 16))
        #expect(resizedLayer.image.size == CGSize(width: 20, height: 16))
        #expect(viewModel.document.selection?.points.first == CGPoint(x: 25, y: 18))
        #expect(viewModel.document.alphaChannels.first?.mask.width == 140)
        #expect(viewModel.document.alphaChannels.first?.mask.height == 100)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.canvasResize"))
        #expect(viewModel.canUndo)
    }

    @Test
    func canvasResizeOffsetsHotspotsForAllNineAnchorsWithoutScalingMetadata() {
        let hotspotID = UUID()
        let originalHotspot = ImageEditorHotspot(
            id: hotspotID,
            name: "Anchor CTA",
            frame: CGRect(x: 12, y: 14, width: 18, height: 10),
            url: "https://example.com/anchor"
        )
        let cases: [(anchor: ImageEditorCanvasAnchor, offset: CGSize)] = [
            (.topLeft, CGSize(width: 0, height: 40)),
            (.top, CGSize(width: 20, height: 40)),
            (.topRight, CGSize(width: 40, height: 40)),
            (.left, CGSize(width: 0, height: 20)),
            (.center, CGSize(width: 20, height: 20)),
            (.right, CGSize(width: 40, height: 20)),
            (.bottomLeft, .zero),
            (.bottom, CGSize(width: 20, height: 0)),
            (.bottomRight, CGSize(width: 40, height: 0))
        ]

        for resizeCase in cases {
            let viewModel = ImageEditorViewModel(
                sourceName: "anchor-\(resizeCase.anchor.rawValue).png",
                image: testImage(color: .systemBlue, size: NSSize(width: 100, height: 80))
            ) { _ in }
            viewModel.document.hotspots = [originalHotspot]
            viewModel.selectedHotspotID = hotspotID

            viewModel.resizeCanvas(
                to: CGSize(width: 140, height: 120),
                anchor: resizeCase.anchor
            )

            let hotspot = viewModel.document.hotspots.first
            #expect(hotspot?.id == hotspotID)
            #expect(hotspot?.name == originalHotspot.name)
            #expect(hotspot?.url == originalHotspot.url)
            #expect(hotspot?.frame == CGRect(
                x: originalHotspot.frame.minX + resizeCase.offset.width,
                y: originalHotspot.frame.minY + resizeCase.offset.height,
                width: originalHotspot.frame.width,
                height: originalHotspot.frame.height
            ))
            #expect(viewModel.selectedHotspotID == hotspotID)
        }
    }

    @Test
    func canvasResizeHotspotGeometryHelperDistinguishesRemovalFromInvalidGeometry() throws {
        let hotspotID = UUID()
        let hotspot = ImageEditorHotspot(
            id: hotspotID,
            name: "  Geometry CTA  ",
            frame: CGRect(x: 30, y: 24, width: -10, height: -8),
            url: "  https://example.com/geometry  "
        )

        let translated = try hotspot.offsetForCanvasResize(
            offset: CGSize(width: 5, height: 4),
            targetCanvasSize: CGSize(width: 100, height: 80)
        )
        #expect(translated?.id == hotspotID)
        #expect(translated?.name == hotspot.name)
        #expect(translated?.url == hotspot.url)
        #expect(translated?.frame == CGRect(x: 25, y: 20, width: 10, height: 8))

        let removed = try hotspot.offsetForCanvasResize(
            offset: CGSize(width: 80, height: 0),
            targetCanvasSize: CGSize(width: 100, height: 80)
        )
        #expect(removed == nil)

        do {
            _ = try ImageEditorHotspot(
                name: "Invalid Geometry",
                frame: CGRect(x: CGFloat.nan, y: 0, width: 10, height: 10)
            ).offsetForCanvasResize(offset: .zero, targetCanvasSize: CGSize(width: 100, height: 80))
            Issue.record("Invalid hotspot geometry should throw")
        } catch {
            // Invalid geometry is intentionally distinct from a valid hotspot
            // that lands fully outside the resized canvas.
        }
    }

    @Test
    func canvasResizeClipsAndRemovesHotspotsAsOneUndoableTransaction() throws {
        let keptID = UUID()
        let clippedID = UUID()
        let removedID = UUID()
        let trailingID = UUID()
        let originalHotspots = [
            ImageEditorHotspot(
                id: keptID,
                name: "Kept CTA",
                frame: CGRect(x: 25, y: 25, width: 20, height: 10),
                url: "https://example.com/kept"
            ),
            ImageEditorHotspot(
                id: clippedID,
                name: "Clipped CTA",
                frame: CGRect(x: 10, y: 10, width: 15, height: 15),
                url: "https://example.com/clipped"
            ),
            ImageEditorHotspot(
                id: removedID,
                name: "Removed CTA",
                frame: CGRect(x: 80, y: 20, width: 10, height: 10),
                url: "https://example.com/removed"
            ),
            ImageEditorHotspot(
                id: trailingID,
                name: "Trailing CTA",
                frame: CGRect(x: 65, y: 45, width: 15, height: 15),
                url: "https://example.com/trailing"
            )
        ]
        let viewModel = ImageEditorViewModel(
            sourceName: "canvas-hotspot-transaction.png",
            image: testImage(color: .systemGreen, size: NSSize(width: 100, height: 80))
        ) { _ in }
        viewModel.document.hotspots = originalHotspots
        viewModel.selectedHotspotID = removedID
        viewModel.isHotspotsPanelVisible = true

        viewModel.pushUndo()
        viewModel.document.areGuidesVisible.toggle()
        viewModel.pushUndo()
        viewModel.document.areRulersVisible.toggle()
        viewModel.undo()
        let beforeResize = try projectData(viewModel.document)
        let undoCountBefore = viewModel.undoStack.count
        let historyCountBefore = viewModel.document.history.count
        #expect(!viewModel.redoStack.isEmpty)

        viewModel.resizeCanvas(to: CGSize(width: 60, height: 40), anchor: .center)

        let resizedHotspots = viewModel.document.hotspots
        #expect(resizedHotspots.map(\.id) == [keptID, clippedID, trailingID])
        #expect(resizedHotspots.map(\.name) == ["Kept CTA", "Clipped CTA", "Trailing CTA"])
        #expect(resizedHotspots.map(\.url) == [
            "https://example.com/kept",
            "https://example.com/clipped",
            "https://example.com/trailing"
        ])
        #expect(resizedHotspots.map(\.frame) == [
            CGRect(x: 5, y: 5, width: 20, height: 10),
            CGRect(x: 0, y: 0, width: 5, height: 5),
            CGRect(x: 45, y: 25, width: 15, height: 15)
        ])
        #expect(viewModel.selectedHotspotID == keptID)
        #expect(viewModel.isHotspotsPanelVisible)
        #expect(viewModel.undoStack.count == undoCountBefore + 1)
        #expect(viewModel.redoStack.isEmpty)
        #expect(viewModel.document.history.count == historyCountBefore + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.canvasResize"))

        let afterResize = try projectData(viewModel.document)
        viewModel.undo()
        #expect(try projectData(viewModel.document) == beforeResize)
        #expect(viewModel.selectedHotspotID == keptID)
        #expect(viewModel.isHotspotsPanelVisible)

        viewModel.redo()
        #expect(try projectData(viewModel.document) == afterResize)
        #expect(viewModel.selectedHotspotID == keptID)
        #expect(viewModel.isHotspotsPanelVisible)
    }

    @Test
    func canvasResizeRejectsInvalidTargetsAndHotspotGeometryWithoutPartialMutation() throws {
        let hotspotID = UUID()
        let validHotspot = ImageEditorHotspot(
            id: hotspotID,
            name: "Atomic Canvas CTA",
            frame: CGRect(x: 12, y: 10, width: 30, height: 20),
            url: "https://example.com/atomic-canvas"
        )
        let viewModel = ImageEditorViewModel(
            sourceName: "atomic-canvas-hotspots.png",
            image: testImage(color: .systemOrange, size: NSSize(width: 100, height: 80))
        ) { _ in }
        viewModel.document.hotspots = [validHotspot]
        viewModel.selectedHotspotID = hotspotID
        viewModel.isHotspotsPanelVisible = true
        viewModel.pushUndo()
        viewModel.document.areGuidesVisible.toggle()
        viewModel.pushUndo()
        viewModel.document.areRulersVisible.toggle()
        viewModel.undo()

        let validBaseline = try projectTransactionSnapshot(viewModel)
        for targetSize in [
            CGSize(width: 100, height: 80),
            CGSize(width: 7, height: 80),
            CGSize(width: CGFloat.nan, height: 80)
        ] {
            viewModel.resizeCanvas(to: targetSize, anchor: .center)
            #expect(try projectTransactionSnapshot(viewModel) == validBaseline)
            #expect(viewModel.statusText == L10n.text("imageEditor.status.resizeInvalid"))
            #expect(viewModel.selectedHotspotID == hotspotID)
            #expect(viewModel.isHotspotsPanelVisible)
        }

        let invalidHotspots = [
            ImageEditorHotspot(
                name: "Invalid zero-area hotspot",
                frame: CGRect(x: 60, y: 20, width: 0, height: 12)
            ),
            ImageEditorHotspot(
                name: "Invalid NaN hotspot",
                frame: CGRect(x: CGFloat.nan, y: 20, width: 12, height: 12)
            ),
            ImageEditorHotspot(
                name: "Invalid infinity hotspot",
                frame: CGRect(x: 60, y: CGFloat.infinity, width: 12, height: 12)
            ),
            ImageEditorHotspot(
                name: "Finite hotspot with overflowing bounds",
                frame: CGRect(
                    x: CGFloat.greatestFiniteMagnitude,
                    y: CGFloat.greatestFiniteMagnitude,
                    width: CGFloat.greatestFiniteMagnitude,
                    height: CGFloat.greatestFiniteMagnitude
                )
            )
        ]

        for invalidHotspot in invalidHotspots {
            viewModel.document.hotspots = [validHotspot, invalidHotspot]
            let invalidBaseline = try projectTransactionSnapshot(viewModel)

            viewModel.resizeCanvas(to: CGSize(width: 140, height: 120), anchor: .topRight)

            #expect(try projectTransactionSnapshot(viewModel) == invalidBaseline)
            #expect(viewModel.statusText == L10n.text("imageEditor.status.resizeInvalid"))
            #expect(viewModel.selectedHotspotID == hotspotID)
            #expect(viewModel.isHotspotsPanelVisible)
        }
    }

    @Test
    func canvasResizeRejectsInvalidOriginalCanvasGeometryWithoutPartialMutation() throws {
        let hotspotID = UUID()
        let invalidOriginalSizesWithHotspot = [
            CGSize(width: 0, height: 80),
            CGSize(width: -100, height: 80)
        ]
        for originalSize in invalidOriginalSizesWithHotspot {
            let viewModel = ImageEditorViewModel(
                sourceName: "invalid-original-canvas-hotspot.png",
                image: testImage(color: .systemRed, size: NSSize(width: 100, height: 80))
            ) { _ in }
            viewModel.document.canvasSize = originalSize
            viewModel.document.hotspots = [
                ImageEditorHotspot(
                    id: hotspotID,
                    name: "Atomic CTA",
                    frame: CGRect(x: 10, y: 10, width: 20, height: 12)
                )
            ]
            viewModel.selectedHotspotID = hotspotID
            viewModel.isHotspotsPanelVisible = true
            viewModel.pushUndo()
            viewModel.document.areGuidesVisible.toggle()
            viewModel.pushUndo()
            viewModel.document.areRulersVisible.toggle()
            viewModel.undo()
            let baseline = try projectTransactionSnapshot(viewModel)

            viewModel.resizeCanvas(to: CGSize(width: 140, height: 120), anchor: .topRight)

            #expect(try projectTransactionSnapshot(viewModel) == baseline)
            #expect(viewModel.statusText == L10n.text("imageEditor.status.resizeInvalid"))
            #expect(viewModel.selectedHotspotID == hotspotID)
            #expect(viewModel.isHotspotsPanelVisible)
        }

        let invalidOriginalSizesWithoutHotspots = [
            CGSize(width: CGFloat.nan, height: 80),
            CGSize(width: 100, height: CGFloat.infinity)
        ]
        for originalSize in invalidOriginalSizesWithoutHotspots {
            let viewModel = ImageEditorViewModel(
                sourceName: "invalid-original-canvas-empty.png",
                image: testImage(color: .systemBlue, size: NSSize(width: 100, height: 80))
            ) { _ in }
            viewModel.document.canvasSize = originalSize
            viewModel.document.hotspots = []
            let baseline = try projectTransactionSnapshot(viewModel)

            viewModel.resizeCanvas(to: CGSize(width: 140, height: 120), anchor: .center)

            #expect(try projectTransactionSnapshot(viewModel) == baseline)
            #expect(viewModel.statusText == L10n.text("imageEditor.status.resizeInvalid"))
        }
    }

    @Test
    func canvasResizePreservesNilHotspotSelectionAndRepairsStaleSelection() {
        let hotspotID = UUID()
        let staleHotspotID = UUID()
        let cases: [(selection: UUID?, expected: UUID?)] = [
            (nil, nil),
            (staleHotspotID, hotspotID)
        ]

        for selectionCase in cases {
            let viewModel = ImageEditorViewModel(
                sourceName: "canvas-hotspot-selection.png",
                image: testImage(color: .systemTeal, size: NSSize(width: 100, height: 80))
            ) { _ in }
            viewModel.document.hotspots = [
                ImageEditorHotspot(
                    id: hotspotID,
                    name: "Surviving CTA",
                    frame: CGRect(x: 10, y: 10, width: 20, height: 12)
                )
            ]
            viewModel.selectedHotspotID = selectionCase.selection
            viewModel.isHotspotsPanelVisible = true

            viewModel.resizeCanvas(to: CGSize(width: 140, height: 120), anchor: .center)

            #expect(viewModel.selectedHotspotID == selectionCase.expected)
            #expect(viewModel.isHotspotsPanelVisible)
        }
    }

    @Test
    func canvasResizeClearsHotspotSelectionWhenNoHotspotSurvives() {
        let removedID = UUID()
        let viewModel = ImageEditorViewModel(
            sourceName: "canvas-hotspot-empty.png",
            image: testImage(color: .systemPurple, size: NSSize(width: 100, height: 80))
        ) { _ in }
        viewModel.document.hotspots = [
            ImageEditorHotspot(
                id: removedID,
                name: "Removed CTA",
                frame: CGRect(x: 80, y: 60, width: 10, height: 10)
            )
        ]
        viewModel.selectedHotspotID = removedID
        viewModel.isHotspotsPanelVisible = true

        viewModel.resizeCanvas(to: CGSize(width: 60, height: 40), anchor: .bottomLeft)

        #expect(viewModel.document.hotspots.isEmpty)
        #expect(viewModel.selectedHotspotID == nil)
        #expect(viewModel.isHotspotsPanelVisible)
    }

    @Test
    func cropClipsAndRemovesHotspotsAsOneUndoableTransaction() throws {
        let keptID = UUID()
        let clippedID = UUID()
        let removedID = UUID()
        let trailingID = UUID()
        let viewModel = ImageEditorViewModel(
            sourceName: "crop-hotspot-transaction.png",
            image: testImage(color: .systemGreen, size: CGSize(width: 100, height: 80))
        ) { _ in }
        viewModel.document.hotspots = [
            ImageEditorHotspot(
                id: keptID,
                name: "  Kept CTA  ",
                frame: CGRect(x: 25, y: 15, width: 10, height: 10),
                url: "  https://example.com/kept  "
            ),
            ImageEditorHotspot(
                id: clippedID,
                name: "Clipped CTA",
                frame: CGRect(x: 15, y: 15, width: 10, height: 10),
                url: "https://example.com/clipped"
            ),
            ImageEditorHotspot(
                id: removedID,
                name: "Removed CTA",
                frame: CGRect(x: 10, y: 10, width: 10, height: 10),
                url: "https://example.com/removed"
            ),
            ImageEditorHotspot(
                id: trailingID,
                name: "Trailing CTA",
                frame: CGRect(x: 60, y: 40, width: 10, height: 10),
                url: "https://example.com/trailing"
            )
        ]
        viewModel.selectedHotspotID = removedID
        viewModel.isHotspotsPanelVisible = true
        viewModel.pushUndo()
        viewModel.document.areGuidesVisible.toggle()
        viewModel.pushUndo()
        viewModel.document.areRulersVisible.toggle()
        viewModel.undo()
        let beforeCrop = try projectData(viewModel.document)
        let undoCountBefore = viewModel.undoStack.count
        let historyCountBefore = viewModel.document.history.count
        #expect(!viewModel.redoStack.isEmpty)

        viewModel.crop(to: CGRect(x: 20, y: 10, width: 50, height: 40))

        #expect(viewModel.document.hotspots.map(\.id) == [keptID, clippedID, trailingID])
        #expect(viewModel.document.hotspots.map(\.name) == ["  Kept CTA  ", "Clipped CTA", "Trailing CTA"])
        #expect(viewModel.document.hotspots.map(\.url) == [
            "  https://example.com/kept  ",
            "https://example.com/clipped",
            "https://example.com/trailing"
        ])
        #expect(viewModel.document.hotspots.map(\.frame) == [
            CGRect(x: 5, y: 5, width: 10, height: 10),
            CGRect(x: 0, y: 5, width: 5, height: 10),
            CGRect(x: 40, y: 30, width: 10, height: 10)
        ])
        #expect(viewModel.selectedHotspotID == keptID)
        #expect(viewModel.isHotspotsPanelVisible)
        #expect(viewModel.undoStack.count == undoCountBefore + 1)
        #expect(viewModel.redoStack.isEmpty)
        #expect(viewModel.document.history.count == historyCountBefore + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.crop"))

        let afterCrop = try projectData(viewModel.document)
        viewModel.undo()
        #expect(try projectData(viewModel.document) == beforeCrop)
        #expect(viewModel.selectedHotspotID == keptID)
        #expect(viewModel.isHotspotsPanelVisible)

        viewModel.redo()
        #expect(try projectData(viewModel.document) == afterCrop)
        #expect(viewModel.selectedHotspotID == keptID)
        #expect(viewModel.isHotspotsPanelVisible)
    }

    @Test
    func cropPreservesNilHotspotSelectionAndRepairsStaleSelection() {
        let hotspotID = UUID()
        let staleID = UUID()
        for selection in [nil, staleID] as [UUID?] {
            let viewModel = ImageEditorViewModel(
                sourceName: "crop-hotspot-selection.png",
                image: testImage(color: .systemTeal, size: CGSize(width: 100, height: 80))
            ) { _ in }
            viewModel.document.hotspots = [
                ImageEditorHotspot(
                    id: hotspotID,
                    name: "Surviving CTA",
                    frame: CGRect(x: 25, y: 15, width: 10, height: 10)
                )
            ]
            viewModel.selectedHotspotID = selection
            viewModel.isHotspotsPanelVisible = true

            viewModel.crop(to: CGRect(x: 20, y: 10, width: 50, height: 40))

            #expect(viewModel.selectedHotspotID == (selection == nil ? nil : hotspotID))
            #expect(viewModel.isHotspotsPanelVisible)
        }
    }

    @Test
    func cropClearsHotspotSelectionWhenEveryHotspotIsRemoved() {
        let hotspotID = UUID()
        let viewModel = ImageEditorViewModel(
            sourceName: "crop-removes-all-hotspots.png",
            image: testImage(color: .systemPurple, size: CGSize(width: 100, height: 80))
        ) { _ in }
        viewModel.document.hotspots = [
            ImageEditorHotspot(
                id: hotspotID,
                name: "Removed CTA",
                frame: CGRect(x: 10, y: 10, width: 10, height: 10)
            )
        ]
        viewModel.selectedHotspotID = hotspotID
        viewModel.isHotspotsPanelVisible = true

        viewModel.crop(to: CGRect(x: 20, y: 10, width: 50, height: 40))

        #expect(viewModel.document.hotspots.isEmpty)
        #expect(viewModel.selectedHotspotID == nil)
        #expect(viewModel.isHotspotsPanelVisible)
    }

    @Test
    func cropAndRevealRejectInvalidOrUnexpectedlyRemovedHotspotsAtomically() throws {
        let invalidFrames = [
            CGRect(x: CGFloat.nan, y: 10, width: 10, height: 10),
            CGRect(x: 10, y: CGFloat.infinity, width: 10, height: 10),
            CGRect(x: 10, y: 10, width: 0, height: 10)
        ]
        for invalidFrame in invalidFrames {
            let viewModel = ImageEditorViewModel(
                sourceName: "invalid-crop-hotspot.png",
                image: testImage(color: .systemOrange, size: CGSize(width: 100, height: 80))
            ) { _ in }
            let selectedID = UUID()
            viewModel.document.hotspots = [
                ImageEditorHotspot(
                    id: selectedID,
                    name: "Valid CTA",
                    frame: CGRect(x: 25, y: 15, width: 10, height: 10)
                ),
                ImageEditorHotspot(name: "Invalid CTA", frame: invalidFrame)
            ]
            viewModel.selectedHotspotID = selectedID
            viewModel.isHotspotsPanelVisible = true
            viewModel.canvasOffset = CGSize(width: 7, height: -9)
            viewModel.targetCanvasWidth = 321
            viewModel.targetCanvasHeight = 654
            let baseline = try projectTransactionSnapshot(viewModel)

            viewModel.crop(to: CGRect(x: 20, y: 10, width: 50, height: 40))

            #expect(try projectTransactionSnapshot(viewModel) == baseline)
            #expect(viewModel.selectedHotspotID == selectedID)
            #expect(viewModel.isHotspotsPanelVisible)
            #expect(viewModel.canvasOffset == CGSize(width: 7, height: -9))
            #expect(viewModel.targetCanvasWidth == 321)
            #expect(viewModel.targetCanvasHeight == 654)
            #expect(viewModel.statusText == L10n.text("imageEditor.status.resizeInvalid"))
        }

        for rejectedHotspot in [
            ImageEditorHotspot(
                name: "Outside CTA",
                frame: CGRect(x: 300, y: 10, width: 10, height: 10)
            ),
            ImageEditorHotspot(
                name: "Invalid CTA",
                frame: CGRect(x: CGFloat.nan, y: 10, width: 10, height: 10)
            )
        ] {
            let viewModel = revealViewModel()
            let selectedID = UUID()
            viewModel.document.hotspots = [
                ImageEditorHotspot(
                    id: selectedID,
                    name: "Valid CTA",
                    frame: CGRect(x: 10, y: 10, width: 10, height: 10)
                ),
                rejectedHotspot
            ]
            viewModel.selectedHotspotID = selectedID
            viewModel.isHotspotsPanelVisible = true
            viewModel.canvasOffset = CGSize(width: -3, height: 4)
            let baseline = try projectTransactionSnapshot(viewModel)

            viewModel.revealAllLayers()

            #expect(try projectTransactionSnapshot(viewModel) == baseline)
            #expect(viewModel.selectedHotspotID == selectedID)
            #expect(viewModel.isHotspotsPanelVisible)
            #expect(viewModel.canvasOffset == CGSize(width: -3, height: 4))
            #expect(viewModel.statusText == L10n.text("imageEditor.status.resizeInvalid"))
        }
    }

    @Test
    func revealAvailabilityIgnoresHotspotsOutsideCanvas() {
        let viewModel = ImageEditorViewModel(
            sourceName: "hotspot-only-reveal.png",
            image: testImage(color: .systemBlue, size: CGSize(width: 100, height: 80))
        ) { _ in }
        viewModel.document.hotspots = [
            ImageEditorHotspot(
                name: "Outside CTA",
                frame: CGRect(x: -30, y: 10, width: 10, height: 10)
            )
        ]

        #expect(!viewModel.canRevealAllLayers)
        let canvasSize = viewModel.document.canvasSize
        viewModel.revealAllLayers()
        #expect(viewModel.document.canvasSize == canvasSize)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.revealAllNoHiddenPixels"))
    }

    @Test
    func revealRejectsOversizedTargetAtomically() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "oversized-reveal.png",
            image: NSImage.transparent(size: CGSize(width: 100, height: 80))
        ) { _ in }
        var farLayer = ImageEditorLayer.blank(
            name: "Far Visible Layer",
            size: CGSize(width: 10, height: 10)
        )
        farLayer.image = NSImage.opaqueMask(size: CGSize(width: 10, height: 10))
        farLayer.frame = CGRect(x: 12_000, y: 10, width: 10, height: 10)
        viewModel.document.layers.append(farLayer)
        let hotspotID = UUID()
        viewModel.document.hotspots = [
            ImageEditorHotspot(
                id: hotspotID,
                name: "Stable CTA",
                frame: CGRect(x: 10, y: 10, width: 10, height: 10)
            )
        ]
        viewModel.selectedHotspotID = hotspotID
        viewModel.isHotspotsPanelVisible = true
        viewModel.canvasOffset = CGSize(width: 13, height: -17)
        viewModel.targetImageWidth = 222
        viewModel.targetImageHeight = 333
        viewModel.targetCanvasWidth = 444
        viewModel.targetCanvasHeight = 555
        viewModel.pushUndo()
        viewModel.document.areGuidesVisible.toggle()
        viewModel.pushUndo()
        viewModel.document.areRulersVisible.toggle()
        viewModel.undo()
        let baseline = try projectTransactionSnapshot(viewModel)

        #expect(viewModel.canRevealAllLayers)
        viewModel.revealAllLayers()

        #expect(try projectTransactionSnapshot(viewModel) == baseline)
        #expect(viewModel.selectedHotspotID == hotspotID)
        #expect(viewModel.isHotspotsPanelVisible)
        #expect(viewModel.canvasOffset == CGSize(width: 13, height: -17))
        #expect(viewModel.targetImageWidth == 222)
        #expect(viewModel.targetImageHeight == 333)
        #expect(viewModel.targetCanvasWidth == 444)
        #expect(viewModel.targetCanvasHeight == 555)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.resizeInvalid"))
    }

    @Test
    func revealPreservesNilHotspotSelectionAndRepairsStaleSelection() {
        let hotspotID = UUID()
        let staleID = UUID()
        for selection in [nil, staleID] as [UUID?] {
            let viewModel = revealViewModel()
            viewModel.document.hotspots = [
                ImageEditorHotspot(
                    id: hotspotID,
                    name: "Reveal CTA",
                    frame: CGRect(x: 10, y: 10, width: 10, height: 10)
                )
            ]
            viewModel.selectedHotspotID = selection
            viewModel.isHotspotsPanelVisible = true

            viewModel.revealAllLayers()

            #expect(viewModel.selectedHotspotID == (selection == nil ? nil : hotspotID))
            #expect(viewModel.isHotspotsPanelVisible)
        }
    }

    @Test
    func revealAllOffsetsHotspotsForNegativeHorizontalAndVerticalBounds() {
        let viewModel = ImageEditorViewModel(
            sourceName: "reveal-hotspot-negative-origin.png",
            image: NSImage.transparent(size: CGSize(width: 100, height: 80))
        ) { _ in }
        var outsideLayer = ImageEditorLayer.blank(
            name: "Visible Outside",
            size: CGSize(width: 20, height: 16)
        )
        outsideLayer.image = NSImage.opaqueMask(size: CGSize(width: 20, height: 16))
        outsideLayer.frame = CGRect(x: -10, y: -6, width: 20, height: 16)
        viewModel.document.layers.append(outsideLayer)
        let hotspotID = UUID()
        viewModel.document.hotspots = [
            ImageEditorHotspot(
                id: hotspotID,
                name: "Offset CTA",
                frame: CGRect(x: 12, y: 14, width: 10, height: 8),
                url: "https://example.com/offset"
            )
        ]

        viewModel.revealAllLayers()

        #expect(viewModel.document.canvasSize == CGSize(width: 110, height: 86))
        #expect(viewModel.document.hotspots.first?.id == hotspotID)
        #expect(viewModel.document.hotspots.first?.frame == CGRect(x: 22, y: 20, width: 10, height: 8))
    }

    @Test
    func cropOffsetsLayersSelectionsChannelsAndGuidesIntoNewCanvasSpace() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemBlue, size: NSSize(width: 100, height: 80))
        ) { _ in }
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 30, y: 22, width: 20, height: 16)
        viewModel.document.layers[layerIndex].image = NSImage.transparent(size: CGSize(width: 20, height: 16))
        viewModel.document.layers[layerIndex].mask = NSImage.opaqueMask(size: CGSize(width: 100, height: 80))

        let selectionMask = sparseMask(width: 100, height: 80, points: [CGPoint(x: 26, y: 16)])
        viewModel.document.selection = .raster(
            mask: selectionMask,
            bounds: CGRect(x: 25, y: 15, width: 18, height: 12)
        )
        viewModel.document.savedSelection = .rectangle(CGRect(x: 42, y: 28, width: 10, height: 8))
        viewModel.document.alphaChannels = [
            ImageEditorAlphaChannel(
                name: "Crop Alpha",
                mask: sparseMask(width: 100, height: 80, points: [CGPoint(x: 26, y: 16), CGPoint(x: 90, y: 70)])
            )
        ]
        viewModel.document.guides = [
            ImageEditorGuide(orientation: .vertical, position: 25),
            ImageEditorGuide(orientation: .horizontal, position: 15),
            ImageEditorGuide(orientation: .vertical, position: 90)
        ]

        viewModel.crop(to: CGRect(x: 20, y: 10, width: 50, height: 40))

        let croppedLayer = viewModel.document.layers[layerIndex]
        let croppedAlpha = try #require(viewModel.document.alphaChannels.first?.mask)
        #expect(viewModel.document.canvasSize == CGSize(width: 50, height: 40))
        #expect(croppedLayer.frame == CGRect(x: 10, y: 12, width: 20, height: 16))
        #expect(croppedLayer.mask?.size == CGSize(width: 50, height: 40))
        #expect(viewModel.document.selection == .fullCanvas(size: CGSize(width: 50, height: 40)))
        #expect(viewModel.document.savedSelection?.points.first == CGPoint(x: 22, y: 18))
        #expect(croppedAlpha.width == 50)
        #expect(croppedAlpha.height == 40)
        #expect(croppedAlpha.alpha[6 * 50 + 6] == 255)
        #expect(croppedAlpha.alpha.filter { $0 == 255 }.count == 1)
        #expect(viewModel.document.guides.count == 2)
        #expect(viewModel.document.guides.contains { $0.orientation == .vertical && $0.position == 5 })
        #expect(viewModel.document.guides.contains { $0.orientation == .horizontal && $0.position == 5 })
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.crop"))
        #expect(viewModel.canUndo)
    }

    @Test
    func cropToSelectionUsesSelectionBoundsAndPreservesCanvasState() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemGreen, size: NSSize(width: 100, height: 80))
        ) { _ in }
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 30, y: 22, width: 20, height: 16)
        viewModel.document.layers[layerIndex].image = NSImage.transparent(size: CGSize(width: 20, height: 16))
        viewModel.document.layers[layerIndex].mask = NSImage.opaqueMask(size: CGSize(width: 100, height: 80))
        viewModel.document.selection = .rectangle(CGRect(x: 20, y: 10, width: 50, height: 40))
        viewModel.document.savedSelection = .rectangle(CGRect(x: 42, y: 28, width: 10, height: 8))
        viewModel.document.alphaChannels = [
            ImageEditorAlphaChannel(
                name: "Selection Crop Alpha",
                mask: sparseMask(width: 100, height: 80, points: [CGPoint(x: 26, y: 16), CGPoint(x: 90, y: 70)])
            )
        ]
        viewModel.document.guides = [
            ImageEditorGuide(orientation: .vertical, position: 25),
            ImageEditorGuide(orientation: .horizontal, position: 15),
            ImageEditorGuide(orientation: .vertical, position: 90)
        ]
        let hotspotID = UUID()
        viewModel.document.hotspots = [
            ImageEditorHotspot(
                id: hotspotID,
                name: "Selection CTA",
                frame: CGRect(x: 25, y: 15, width: 12, height: 10),
                url: "https://example.com/selection"
            )
        ]
        viewModel.selectedHotspotID = hotspotID

        #expect(viewModel.canCropToSelection)
        viewModel.cropToSelection()

        let croppedAlpha = try #require(viewModel.document.alphaChannels.first?.mask)
        #expect(viewModel.document.canvasSize == CGSize(width: 50, height: 40))
        #expect(viewModel.document.layers[layerIndex].frame == CGRect(x: 10, y: 12, width: 20, height: 16))
        #expect(viewModel.document.layers[layerIndex].mask?.size == CGSize(width: 50, height: 40))
        #expect(viewModel.document.selection == .fullCanvas(size: CGSize(width: 50, height: 40)))
        #expect(viewModel.document.savedSelection?.points.first == CGPoint(x: 22, y: 18))
        #expect(croppedAlpha.width == 50)
        #expect(croppedAlpha.height == 40)
        #expect(croppedAlpha.alpha[6 * 50 + 6] == 255)
        #expect(croppedAlpha.alpha.filter { $0 == 255 }.count == 1)
        #expect(viewModel.document.guides.count == 2)
        #expect(viewModel.document.guides.contains { $0.orientation == .vertical && $0.position == 5 })
        #expect(viewModel.document.guides.contains { $0.orientation == .horizontal && $0.position == 5 })
        #expect(viewModel.document.hotspots.first?.id == hotspotID)
        #expect(viewModel.document.hotspots.first?.frame == CGRect(x: 5, y: 5, width: 12, height: 10))
        #expect(viewModel.selectedHotspotID == hotspotID)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.cropSelection"))
        #expect(!viewModel.canCropToSelection)
        #expect(viewModel.canUndo)
    }

    @Test
    func cropToSelectionUsesRasterPixelsAndRejectsInvertedCanvasBounds() throws {
        let canvasSize = CGSize(width: 100, height: 80)
        let viewModel = ImageEditorViewModel(
            sourceName: "raster-selection.png",
            image: testImage(color: .systemGreen, size: canvasSize)
        ) { _ in }
        viewModel.document.selection = .raster(
            mask: rectangularMask(
                width: Int(canvasSize.width),
                height: Int(canvasSize.height),
                rect: CGRect(x: 24, y: 16, width: 40, height: 32)
            ),
            bounds: CGRect(origin: .zero, size: canvasSize)
        )

        #expect(viewModel.canCropToSelection)
        viewModel.cropToSelection()

        #expect(viewModel.document.canvasSize == CGSize(width: 40, height: 32))
        #expect(viewModel.document.selection == .fullCanvas(size: CGSize(width: 40, height: 32)))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.cropSelection"))
        #expect(viewModel.canUndo)

        viewModel.undo()
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count
        var invertedSelection = ImageEditorSelection.rectangle(
            CGRect(x: 20, y: 10, width: 50, height: 40)
        )
        invertedSelection.isInverted = true
        viewModel.document.selection = invertedSelection

        #expect(!viewModel.canCropToSelection)
        viewModel.cropToSelection()

        #expect(viewModel.document.canvasSize == canvasSize)
        #expect(viewModel.document.selection == invertedSelection)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.cropSelectionInvalid"))
    }

    @Test
    func canvasRotationCommandsTransformLayerFramesAndHistory() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemPurple, size: NSSize(width: 100, height: 80))
        ) { _ in }
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 10, y: 12, width: 20, height: 16)
        viewModel.document.layers[layerIndex].image = NSImage.transparent(size: CGSize(width: 20, height: 16))
        viewModel.document.layers[layerIndex].mask = NSImage.opaqueMask(size: CGSize(width: 20, height: 16))

        viewModel.rotateCounterclockwise()

        #expect(viewModel.document.canvasSize == CGSize(width: 80, height: 100))
        #expect(viewModel.document.layers[layerIndex].frame == CGRect(x: 12, y: 70, width: 16, height: 20))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.rotateCounterclockwise"))

        viewModel.undo()
        viewModel.rotate180()

        #expect(viewModel.document.canvasSize == CGSize(width: 100, height: 80))
        #expect(viewModel.document.layers[layerIndex].frame == CGRect(x: 70, y: 52, width: 20, height: 16))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.rotate180"))
    }

    @Test
    func trimTransparentPixelsCropsToVisibleAlphaBounds() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: NSImage.transparent(size: NSSize(width: 100, height: 80))
        ) { _ in }
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 30, y: 22, width: 20, height: 16)
        viewModel.document.layers[layerIndex].image = NSImage.opaqueMask(size: CGSize(width: 20, height: 16))
        viewModel.document.selection = .rectangle(CGRect(x: 34, y: 26, width: 8, height: 6))
        viewModel.document.savedSelection = .rectangle(CGRect(x: 38, y: 30, width: 6, height: 4))
        viewModel.document.alphaChannels = [
            ImageEditorAlphaChannel(
                name: "Trim Alpha",
                mask: sparseMask(width: 100, height: 80, points: [CGPoint(x: 35, y: 27), CGPoint(x: 90, y: 70)])
            )
        ]
        viewModel.document.guides = [
            ImageEditorGuide(orientation: .vertical, position: 30),
            ImageEditorGuide(orientation: .horizontal, position: 22),
            ImageEditorGuide(orientation: .vertical, position: 90)
        ]
        let hotspotID = UUID()
        let outsideHotspotID = UUID()
        viewModel.document.hotspots = [
            ImageEditorHotspot(
                id: hotspotID,
                name: "Trim CTA",
                frame: CGRect(x: 35, y: 27, width: 10, height: 8),
                url: "https://example.com/trim"
            ),
            ImageEditorHotspot(
                id: outsideHotspotID,
                name: "Does Not Expand Trim Bounds",
                frame: CGRect(x: 80, y: 60, width: 10, height: 8),
                url: "https://example.com/trim-outside"
            )
        ]
        viewModel.selectedHotspotID = hotspotID

        viewModel.trimTransparentPixels()

        let trimmedAlpha = try #require(viewModel.document.alphaChannels.first?.mask)
        #expect(viewModel.document.canvasSize == CGSize(width: 20, height: 16))
        #expect(viewModel.document.layers[layerIndex].frame == CGRect(x: 0, y: 0, width: 20, height: 16))
        #expect(viewModel.document.selection == .fullCanvas(size: CGSize(width: 20, height: 16)))
        #expect(viewModel.document.savedSelection?.points.first == CGPoint(x: 8, y: 8))
        #expect(trimmedAlpha.width == 20)
        #expect(trimmedAlpha.height == 16)
        #expect(trimmedAlpha.alpha[5 * 20 + 5] == 255)
        #expect(trimmedAlpha.alpha.filter { $0 == 255 }.count == 1)
        #expect(viewModel.document.guides.count == 2)
        #expect(viewModel.document.guides.contains { $0.orientation == .vertical && $0.position == 0 })
        #expect(viewModel.document.guides.contains { $0.orientation == .horizontal && $0.position == 0 })
        #expect(viewModel.document.hotspots.map(\.id) == [hotspotID])
        #expect(viewModel.document.hotspots.first?.frame == CGRect(x: 5, y: 5, width: 10, height: 8))
        #expect(viewModel.selectedHotspotID == hotspotID)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.trim"))
    }

    @Test
    func revealAllExpandsCanvasToVisibleLayerBounds() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemBlue, size: NSSize(width: 100, height: 80))
        ) { _ in }
        let initialLayerIDs = viewModel.document.layers.map(\.id)
        var leftLayer = ImageEditorLayer.blank(name: "Left", size: CGSize(width: 20, height: 16))
        leftLayer.image = NSImage.opaqueMask(size: CGSize(width: 20, height: 16))
        leftLayer.frame = CGRect(x: -10, y: 12, width: 20, height: 16)
        var rightLayer = ImageEditorLayer.blank(name: "Right", size: CGSize(width: 30, height: 20))
        rightLayer.image = NSImage.opaqueMask(size: CGSize(width: 30, height: 20))
        rightLayer.frame = CGRect(x: 90, y: 70, width: 30, height: 20)
        var hiddenLayer = ImageEditorLayer.blank(name: "Hidden", size: CGSize(width: 30, height: 20))
        hiddenLayer.frame = CGRect(x: -40, y: 10, width: 30, height: 20)
        hiddenLayer.isVisible = false
        viewModel.document.layers.append(contentsOf: [leftLayer, rightLayer, hiddenLayer])
        viewModel.document.selection = .rectangle(CGRect(x: 6, y: 14, width: 10, height: 8))
        viewModel.document.savedSelection = .rectangle(CGRect(x: 12, y: 18, width: 8, height: 6))
        viewModel.document.alphaChannels = [
            ImageEditorAlphaChannel(
                name: "Reveal Alpha",
                mask: sparseMask(width: 100, height: 80, points: [CGPoint(x: 6, y: 16), CGPoint(x: 99, y: 79)])
            )
        ]
        viewModel.document.guides = [
            ImageEditorGuide(orientation: .vertical, position: 4),
            ImageEditorGuide(orientation: .horizontal, position: 20)
        ]
        let firstHotspotID = UUID()
        let selectedHotspotID = UUID()
        viewModel.document.hotspots = [
            ImageEditorHotspot(
                id: firstHotspotID,
                name: "  Reveal Primary  ",
                frame: CGRect(x: 6, y: 14, width: 10, height: 8),
                url: "  https://example.com/reveal-primary  "
            ),
            ImageEditorHotspot(
                id: selectedHotspotID,
                name: "Reveal Secondary",
                frame: CGRect(x: 70, y: 50, width: 12, height: 10),
                url: "https://example.com/reveal-secondary"
            )
        ]
        viewModel.selectedHotspotID = selectedHotspotID
        viewModel.isHotspotsPanelVisible = true
        let beforeReveal = try projectData(viewModel.document)
        let undoCountBefore = viewModel.undoStack.count
        let historyCountBefore = viewModel.document.history.count

        #expect(viewModel.canRevealAllLayers)
        viewModel.revealAllLayers()

        let revealedAlpha = try #require(viewModel.document.alphaChannels.first?.mask)
        let revealedLeft = try #require(viewModel.document.layers.first { $0.id == leftLayer.id })
        let revealedRight = try #require(viewModel.document.layers.first { $0.id == rightLayer.id })
        let revealedHidden = try #require(viewModel.document.layers.first { $0.id == hiddenLayer.id })
        #expect(viewModel.document.canvasSize == CGSize(width: 130, height: 90))
        for initialLayerID in initialLayerIDs {
            #expect(
                viewModel.document.layers.first { $0.id == initialLayerID }?.frame
                    == CGRect(x: 10, y: 0, width: 100, height: 80)
            )
        }
        #expect(revealedLeft.frame == CGRect(x: 0, y: 12, width: 20, height: 16))
        #expect(revealedRight.frame == CGRect(x: 100, y: 70, width: 30, height: 20))
        #expect(revealedHidden.frame == CGRect(x: -30, y: 10, width: 30, height: 20))
        #expect(viewModel.document.selection?.points.first == CGPoint(x: 16, y: 14))
        #expect(viewModel.document.savedSelection?.points.first == CGPoint(x: 22, y: 18))
        #expect(revealedAlpha.width == 130)
        #expect(revealedAlpha.height == 90)
        #expect(revealedAlpha.alpha[16 * 130 + 16] == 255)
        #expect(revealedAlpha.alpha[79 * 130 + 109] == 255)
        #expect(viewModel.document.guides.contains { $0.orientation == .vertical && $0.position == 14 })
        #expect(viewModel.document.guides.contains { $0.orientation == .horizontal && $0.position == 20 })
        #expect(viewModel.document.hotspots.map(\.id) == [firstHotspotID, selectedHotspotID])
        #expect(viewModel.document.hotspots.map(\.name) == ["  Reveal Primary  ", "Reveal Secondary"])
        #expect(viewModel.document.hotspots.map(\.url) == [
            "  https://example.com/reveal-primary  ",
            "https://example.com/reveal-secondary"
        ])
        #expect(viewModel.document.hotspots.map(\.frame) == [
            CGRect(x: 16, y: 14, width: 10, height: 8),
            CGRect(x: 80, y: 50, width: 12, height: 10)
        ])
        #expect(viewModel.selectedHotspotID == selectedHotspotID)
        #expect(viewModel.isHotspotsPanelVisible)
        #expect(viewModel.undoStack.count == undoCountBefore + 1)
        #expect(viewModel.document.history.count == historyCountBefore + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.revealAll"))
        #expect(!viewModel.canRevealAllLayers)
        #expect(viewModel.canUndo)

        let afterReveal = try projectData(viewModel.document)
        viewModel.undo()
        #expect(try projectData(viewModel.document) == beforeReveal)
        #expect(viewModel.selectedHotspotID == selectedHotspotID)
        #expect(viewModel.isHotspotsPanelVisible)
        viewModel.redo()
        #expect(try projectData(viewModel.document) == afterReveal)
        #expect(viewModel.selectedHotspotID == selectedHotspotID)
        #expect(viewModel.isHotspotsPanelVisible)
    }

    private func revealViewModel() -> ImageEditorViewModel {
        let viewModel = ImageEditorViewModel(
            sourceName: "reveal-hotspot-atomic.png",
            image: NSImage.transparent(size: CGSize(width: 100, height: 80))
        ) { _ in }
        var leftLayer = ImageEditorLayer.blank(
            name: "Visible Left",
            size: CGSize(width: 20, height: 16)
        )
        leftLayer.image = NSImage.opaqueMask(size: CGSize(width: 20, height: 16))
        leftLayer.frame = CGRect(x: -10, y: 12, width: 20, height: 16)
        viewModel.document.layers.append(leftLayer)
        return viewModel
    }

    private func testImage(color: NSColor, size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        color.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        return image
    }

    private func sparseMask(width: Int, height: Int, points: [CGPoint]) -> ImageEditorSelectionMask {
        var alpha = [UInt8](repeating: 0, count: width * height)
        for point in points {
            let x = min(width - 1, max(0, Int(point.x.rounded())))
            let y = min(height - 1, max(0, Int(point.y.rounded())))
            alpha[y * width + x] = 255
        }
        return ImageEditorSelectionMask(width: width, height: height, alpha: alpha)
    }

    private func rectangularMask(
        width: Int,
        height: Int,
        rect: CGRect
    ) -> ImageEditorSelectionMask {
        var alpha = [UInt8](repeating: 0, count: width * height)
        let bounds = rect.standardized.integral.intersection(
            CGRect(x: 0, y: 0, width: width, height: height)
        )
        guard !bounds.isNull, !bounds.isEmpty else {
            return ImageEditorSelectionMask(width: width, height: height, alpha: alpha)
        }
        for y in Int(bounds.minY)..<Int(bounds.maxY) {
            for x in Int(bounds.minX)..<Int(bounds.maxX) {
                alpha[y * width + x] = UInt8.max
            }
        }
        return ImageEditorSelectionMask(width: width, height: height, alpha: alpha)
    }

    private func projectData(_ document: ImageEditorDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "Infinity",
            negativeInfinity: "-Infinity",
            nan: "NaN"
        )
        return try encoder.encode(ImageEditorProjectDocument(document: document))
    }

    private func projectTransactionSnapshot(
        _ viewModel: ImageEditorViewModel
    ) throws -> ProjectTransactionSnapshot {
        ProjectTransactionSnapshot(
            document: try projectData(viewModel.document),
            undo: try viewModel.undoStack.map { try projectData($0) },
            redo: try viewModel.redoStack.map { try projectData($0) }
        )
    }

    private struct ProjectTransactionSnapshot: Equatable {
        let document: Data
        let undo: [Data]
        let redo: [Data]
    }
}
