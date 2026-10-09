import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorSmartFilterMaskTests {
    @Test func selectionMaskLimitsOneSmartFilterAndUndoRedoRestoresIt() throws {
        let source = patternedImage(width: 32, height: 16)
        let viewModel = ImageEditorViewModel(sourceName: "filter-mask.png", image: source) { _ in }
        let selectedLayerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[selectedLayerIndex].image = source
        viewModel.selectedFilter = .pixelate
        viewModel.filterIntensity = 1
        viewModel.filterPixelateCellSize = 4
        viewModel.addSmartFilterToSelectedLayer()
        let filterID = try #require(viewModel.document.selectedLayer?.smartFilters.first?.id)
        let fullFilterResult = try #require(viewModel.document.selectedLayer?.contentImage)
        let fullPixels = try #require(imageEditorRGBABytes(fullFilterResult, width: 32, height: 16))
        let sourcePixels = try #require(imageEditorRGBABytes(source, width: 32, height: 16))

        viewModel.document.selection = .rectangle(CGRect(x: 0, y: 0, width: 16, height: 16))
        #expect(viewModel.canSetSmartFilterMaskFromSelection(filterID))
        #expect(viewModel.setSmartFilterMaskFromSelection(filterID) == 1)
        let filter = try #require(viewModel.document.selectedLayer?.smartFilters.first)
        let mask = try #require(filter.mask)
        #expect(mask.width == 32)
        #expect(mask.height == 16)
        #expect(mask.alpha[8 * mask.width + 4] == .max)
        #expect(mask.alpha[8 * mask.width + 28] == .min)
        let maskImage = try #require(NSImage.selectionMaskImage(
            mask,
            inverted: false,
            targetSize: source.size
        ))
        let roundTripMask = try #require(maskImage.imageEditorSelectionMask(
            targetSize: source.size,
            flipsY: false
        ))
        #expect(roundTripMask.alpha[8 * mask.width + 28] == .min)

        let maskedResult = try #require(viewModel.document.selectedLayer?.contentImage)
        let maskedPixels = try #require(imageEditorRGBABytes(maskedResult, width: 32, height: 16))
        var selectedRegionChanged = false
        var outsideSelectionMatches = true
        var outsideMismatchSamples: [String] = []
        for y in 0..<16 {
            for x in 16..<32 {
                let offset = (y * 32 + x) * 4
                let maskedPixel = Array(maskedPixels[offset..<(offset + 4)])
                let sourcePixel = Array(sourcePixels[offset..<(offset + 4)])
                if maskedPixel != sourcePixel {
                    outsideSelectionMatches = false
                    if outsideMismatchSamples.count < 3 {
                        let index = y * mask.width + x
                        let fullPixel = Array(fullPixels[offset..<(offset + 4)])
                        outsideMismatchSamples.append(
                            "(\(x),\(y)) mask=\(mask.alpha[index]) roundTrip=\(roundTripMask.alpha[index]) source=\(sourcePixel) full=\(fullPixel) masked=\(maskedPixel)"
                        )
                    }
                }
            }
            for x in 2..<14 {
                let offset = (y * 32 + x) * 4
                if maskedPixels[offset..<(offset + 3)] != sourcePixels[offset..<(offset + 3)] {
                    selectedRegionChanged = true
                }
            }
        }
        #expect(selectedRegionChanged)
        #expect(outsideSelectionMatches, "Outside-mask samples: \(outsideMismatchSamples)")

        viewModel.undo()
        #expect(viewModel.document.selectedLayer?.smartFilters.first?.mask == nil)
        #expect(try #require(viewModel.document.selectedLayer?.contentImage).qingtuPNGData()
            == fullFilterResult.qingtuPNGData())
        viewModel.redo()
        #expect(viewModel.document.selectedLayer?.smartFilters.first?.mask == mask)
        #expect(imageEditorMaximumPixelDifference(
            try #require(viewModel.document.selectedLayer?.contentImage),
            maskedResult
        ) == 0)
        #expect(fullPixels != sourcePixels)
    }

    @Test func filterMaskSurvivesProjectRoundTripAndCanBeCleared() throws {
        let source = patternedImage(width: 24, height: 16)
        let viewModel = ImageEditorViewModel(sourceName: "filter-mask-roundtrip.png", image: source) { _ in }
        viewModel.selectedFilter = .pixelate
        viewModel.filterPixelateCellSize = 4
        viewModel.addSmartFilterToSelectedLayer()
        let filterID = try #require(viewModel.document.selectedLayer?.smartFilters.first?.id)
        viewModel.document.selection = .rectangle(CGRect(x: 4, y: 2, width: 12, height: 10))
        #expect(viewModel.setSmartFilterMaskFromSelection(filterID) == 1)
        let savedMask = try #require(viewModel.document.selectedLayer?.smartFilters.first?.mask)

        let reopened = ImageEditorViewModel(
            sourceName: "empty.png",
            image: NSImage.transparent(size: NSSize(width: 4, height: 4))
        ) { _ in }
        try reopened.loadProjectData(viewModel.projectData())
        let restoredFilter = try #require(reopened.document.selectedLayer?.smartFilters.first)
        #expect(restoredFilter.id == filterID)
        #expect(restoredFilter.mask == savedMask)

        #expect(reopened.clearSmartFilterMask(filterID) == 1)
        #expect(reopened.document.selectedLayer?.smartFilters.first?.mask == nil)
        reopened.undo()
        #expect(reopened.document.selectedLayer?.smartFilters.first?.mask == savedMask)
        reopened.redo()
        #expect(reopened.document.selectedLayer?.smartFilters.first?.mask == nil)
    }

    @Test func legacySmartFilterDecodingDefaultsToNoMask() throws {
        let data = Data(
            #"{"kind":"pixelate","intensity":0.75,"settings":{},"isEnabled":true}"#.utf8
        )
        let filter = try JSONDecoder().decode(ImageEditorSmartFilter.self, from: data)
        #expect(filter.mask == nil)
    }

    private func patternedImage(width: Int, height: Int) -> NSImage {
        let rendered = NSImage.rendered(size: CGSize(width: width, height: height)) { _ in
            for y in 0..<height {
                for x in 0..<width {
                    ((x + y).isMultiple(of: 2) ? NSColor.black : NSColor.white).setFill()
                    NSRect(x: x, y: y, width: 1, height: 1).fill()
                }
            }
        }
        guard let image = rendered else { fatalError("Unable to render smart filter mask test fixture") }
        return image
    }
}
