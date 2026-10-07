import AppKit
import CoreFoundation
import ImageIO
import Testing
@testable import musepic

@MainActor
struct ImageEditorJPEGExportColorTests {
    @Test func displayP3JPEGExportEmbedsSRGBAndPreservesFlattenedColor() throws {
        let sourceSpace = try #require(CGColorSpace(name: CGColorSpace.displayP3))
        let importedDocument = try p3Document(alpha: 255)
        let viewModel = makeViewModel(document: importedDocument)
        let settings = ImageEditorExportSettings(
            format: .jpeg,
            scope: .composited,
            scale: 0.5,
            quality: 1
        )
        let jpegData = try #require(viewModel.exportData(settings: settings))
        let decoded = try decodedJPEG(jpegData)
        #expect(decoded.width == 8)
        #expect(decoded.height == 8)
        #expect(decoded.colorSpace?.name == CGColorSpace.sRGB)
        let referencePNGData = try #require(viewModel.quickExportPNGData())
        let referencePNG = try decodedJPEG(referencePNGData)

        let expectedComponents = try expectedSRGBComponents(sourceSpace: sourceSpace)
        let jpegColor = try pixelColor(decoded, x: 4, y: 4)
        let pngColor = try pixelColor(referencePNG, x: 4, y: 4)
        try expectColor(jpegColor, matches: expectedComponents)
        for channel in 0..<3 {
            #expect(abs(jpegColor[channel] - pngColor[channel]) < 0.04)
        }

        viewModel.addLayerComp(named: "P3 JPEG")
        let artifacts = try #require(viewModel.layerCompExportArtifacts(format: .jpeg, quality: 1))
        let layerCompImage = try decodedJPEG(artifacts[0].data)
        #expect(layerCompImage.colorSpace?.name == CGColorSpace.sRGB)
        try expectColor(pixelColor(layerCompImage, x: 8, y: 8), matches: expectedComponents)

        let transparentViewModel = makeViewModel(document: try p3Document(alpha: 128))
        let transparentData = try #require(transparentViewModel.exportData(settings: ImageEditorExportSettings(
            format: .jpeg,
            scope: .composited,
            quality: 1
        )))
        let flattenedImage = try decodedJPEG(transparentData)
        let flattenedColor = try pixelColor(flattenedImage, x: 8, y: 8)
        let alpha = 128.0 / 255
        expectColor(
            flattenedColor,
            matches: expectedComponents.map { $0 * alpha + (1 - alpha) }
        )
    }

    private func p3Document(alpha: UInt8) throws -> ImageEditorDocument {
        let sourceSpace = try #require(CGColorSpace(name: CGColorSpace.displayP3))
        let width = 16
        let height = 16
        let sourceBytes: [UInt8] = Array(
            repeating: [UInt8(200), UInt8(120), UInt8(40), alpha],
            count: width * height
        ).flatMap { $0 }
        let provider = try #require(CGDataProvider(data: Data(sourceBytes) as CFData))
        let source = try #require(CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: sourceSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ))
        return XomoExternalImageDocumentFactory.make(
            sourceName: "p3-jpeg.png",
            image: NSImage(cgImage: source, size: CGSize(width: width, height: height))
        )
    }

    private func makeViewModel(document: ImageEditorDocument) -> ImageEditorViewModel {
        let viewModel = ImageEditorViewModel(
            sourceName: "initial.png",
            image: NSImage.transparent(size: CGSize(width: 1, height: 1))
        ) { _ in }
        viewModel.document = document
        return viewModel
    }

    private func expectedSRGBComponents(sourceSpace: CGColorSpace) throws -> [CGFloat] {
        let sourceColor = try #require(CGColor(
            colorSpace: sourceSpace,
            components: [200 / 255, 120 / 255, 40 / 255, 1]
        ))
        let sRGB = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let converted = try #require(sourceColor.converted(
            to: sRGB,
            intent: .relativeColorimetric,
            options: nil
        ))
        return Array(try #require(converted.components).prefix(3))
    }

    private func expectColor(_ actual: [CGFloat], matches expected: [CGFloat]) {
        for channel in 0..<3 {
            #expect(
                abs(actual[channel] - expected[channel]) < 0.04,
                "channel=\(channel), actual=\(actual[channel]), expected=\(expected[channel])"
            )
        }
    }

    private func decodedJPEG(_ data: Data) throws -> CGImage {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        return try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    }

    private func pixelColor(_ image: CGImage, x: Int, y: Int) throws -> [CGFloat] {
        let pixelCount = image.width * image.height
        var pixels = [UInt8](repeating: 0, count: pixelCount * 4)
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: &pixels,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: image.width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let offset = (y * image.width + x) * 4
        return (0..<3).map { CGFloat(pixels[offset + $0]) / 255 }
    }
}
