import AppKit
import CoreFoundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import musepic

@MainActor
struct ImageEditorP3PixelEditExportWorkflowTests {
    @Test func p3PNGOpenSelectionMoveUndoRedoProjectReloadAndPNGExportStayConsistent() throws {
        let sourceSpace = try #require(CGColorSpace(name: CGColorSpace.displayP3))
        let sourceData = try p3PNGData(colorSpace: sourceSpace)
        let source = try #require(NSImage(data: sourceData))
        let sourceCGImage = try #require(source.cgImage(forProposedRect: nil, context: nil, hints: nil))
        #expect(sourceCGImage.colorSpace?.name == CGColorSpace.displayP3)

        let model = ImageEditorViewModel(
            sourceName: "p3-selection-workflow.png",
            image: .transparent(size: CGSize(width: 1, height: 1))
        ) { _ in }
        model.loadExternalImageDocument(
            XomoExternalImageDocumentFactory.make(sourceName: "p3-selection-workflow.png", image: source)
        )
        model.selectedTool = .move
        model.document.selection = .rectangle(CGRect(x: 2, y: 2, width: 2, height: 2))

        let originalProject = try model.projectData()
        let originalPixels = try #require(imageEditorRGBABytes(model.document.compositedImage, width: 8, height: 8))
        let expectedSelectedColor = try expectedSRGBBytes(
            colorSpace: sourceSpace,
            components: [200 / 255, 60 / 255, 40 / 255, 1]
        )
        let selectedLayerImage = try #require(model.document.selectedLayer?.image)
        let selectedLayerPixels = try #require(imageEditorRGBABytes(selectedLayerImage, width: 8, height: 8))
        let importedSelectedColor = Array(selectedLayerPixels[(2 * 8 + 2) * 4..<(2 * 8 + 2) * 4 + 4])
        for channel in 0..<3 {
            #expect(abs(Int(importedSelectedColor[channel]) - Int(expectedSelectedColor[channel])) <= 1)
        }
        #expect(Array(originalPixels[(2 * 8 + 2) * 4..<(2 * 8 + 2) * 4 + 4]) == importedSelectedColor)

        #expect(model.beginPixelSelectionMove(at: CGPoint(x: 2.5, y: 2.5)))
        model.updatePixelSelectionMove(by: CGSize(width: 3, height: 2))
        model.finishPixelSelectionMove()
        let movedProject = try model.projectData()
        let movedPixels = try #require(imageEditorRGBABytes(model.document.compositedImage, width: 8, height: 8))
        #expect(movedPixels != originalPixels)
        #expect(Array(movedPixels[(2 * 8 + 2) * 4..<(2 * 8 + 2) * 4 + 4]) == [0, 0, 0, 0])
        #expect(Array(movedPixels[(4 * 8 + 5) * 4..<(4 * 8 + 5) * 4 + 4]) == importedSelectedColor)

        model.undo()
        #expect(try model.projectData() == originalProject)
        model.redo()
        #expect(try model.projectData() == movedProject)

        let reopened = ImageEditorViewModel(
            sourceName: "placeholder.png",
            image: .transparent(size: CGSize(width: 1, height: 1))
        ) { _ in }
        try reopened.loadProjectData(movedProject)
        let reopenedPixels = try #require(imageEditorRGBABytes(reopened.document.compositedImage, width: 8, height: 8))
        #expect(reopenedPixels == movedPixels)

        let pngData = try #require(reopened.exportData(settings: .init(format: .png, scope: .composited)))
        let pngSource = try #require(CGImageSourceCreateWithData(pngData as CFData, nil))
        let exportedImage = try #require(CGImageSourceCreateImageAtIndex(pngSource, 0, nil))
        #expect(exportedImage.colorSpace?.name == CGColorSpace.sRGB)
        #expect(exportedImage.width == 8)
        #expect(exportedImage.height == 8)
        let exportedPixels = try #require(imageEditorRGBABytes(NSImage(cgImage: exportedImage, size: CGSize(width: 8, height: 8)), width: 8, height: 8))
        #expect(exportedPixels == movedPixels)
    }

    private func p3PNGData(colorSpace: CGColorSpace) throws -> Data {
        let width = 8
        let height = 8
        var pixels: [UInt8] = []
        for y in 0..<height {
            for x in 0..<width {
                let selected = (2..<4).contains(x) && (2..<4).contains(y)
                pixels.append(contentsOf: selected ? [200, 60, 40, 255] : [20, 90, 220, 255])
            }
        }
        let provider = try #require(CGDataProvider(data: Data(pixels) as CFData))
        let image = try #require(CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ))
        let output = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(
            output,
            UTType.png.identifier as CFString,
            1,
            nil
        ))
        CGImageDestinationAddImage(destination, image, nil)
        try #require(CGImageDestinationFinalize(destination))
        return output as Data
    }

    private func expectedSRGBBytes(colorSpace: CGColorSpace, components: [CGFloat]) throws -> [UInt8] {
        let sourceColor = try #require(CGColor(colorSpace: colorSpace, components: components))
        let sRGB = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let converted = try #require(sourceColor.converted(to: sRGB, intent: .relativeColorimetric, options: nil))
        return try #require(converted.components).prefix(4).map { UInt8(($0 * 255).rounded()) }
    }
}
