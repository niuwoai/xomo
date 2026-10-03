import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorTransformFinalStateTests {
    enum Content: CaseIterable { case pixel, unlinkedMask, component, paragraph }
    struct RasterPixels: Equatable {
        let width: Int
        let height: Int
        let bytes: [UInt8]
    }

    @Test(arguments: Content.allCases, [false, true])
    func returningToStartPreservesSavedDocumentAndPendingThemeRedo(content: Content, rotation: Bool) throws {
        let model = try fixture(content)
        let pendingTheme: XomoComponentTheme = model.xomoComponentTheme == .native ? .softMobile : .native
        model.selectXomoComponentTheme(pendingTheme)
        let pending = try model.projectData()
        model.undo()
        model.resetProjectSaveBaseline()
        let original = try model.projectData()
        let undoCount = model.undoStack.count
        let history = model.document.history
        let frame = try #require(model.selectedLayerTransformFrame)
        let start = rotation ? CGPoint(x: frame.midX, y: frame.minY - 24)
            : CGPoint(x: frame.maxX, y: frame.midY)
        let end = rotation ? CGPoint(x: frame.maxX + 40, y: frame.minY - 40)
            : CGPoint(x: frame.maxX + 40, y: frame.midY)
        if rotation {
            model.beginRotatingSelectedLayer(from: start)
            model.rotateSelectedLayer(to: end)
        } else {
            model.beginResizingSelectedLayer(handle: .right)
            model.resizeSelectedLayer(to: end, handle: .right)
        }
        #expect(try model.projectData() != original)
        if rotation {
            model.rotateSelectedLayer(to: start)
            model.finishRotatingSelectedLayer()
        } else {
            model.resizeSelectedLayer(to: start, handle: .right)
            model.finishResizingSelectedLayer()
        }
        #expect(try model.projectData() == original)
        #expect(model.document.history == history)
        #expect(model.undoStack.count == undoCount && model.redoStack.count == 1)
        #expect(!model.hasUnsavedProjectChanges && !model.hasActiveSelectedLayerTransformTransaction)
        model.redo()
        #expect(model.xomoComponentTheme == pendingTheme)
        #expect(try model.projectData() == pending)
    }

    @Test(arguments: [0.005, 0.02, 0.05, -0.05, 0.2])
    func rotationCommitMatchesActualPreviewAndRemainsUndoable(degrees: Double) throws {
        let model = try fixture(.pixel)
        model.renameSelectedLayer(to: "Pending redo")
        let pending = try model.projectData()
        model.undo()
        model.resetProjectSaveBaseline()
        let original = try model.projectData()
        let undoCount = model.undoStack.count
        let historyCount = model.document.history.count
        let frame = try #require(model.selectedLayerTransformFrame)
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let radius = frame.height / 2 + 24
        let radians = CGFloat(degrees) * .pi / 180
        let start = CGPoint(x: center.x, y: center.y - radius)
        let end = CGPoint(x: center.x + sin(radians) * radius, y: center.y - cos(radians) * radius)
        model.beginRotatingSelectedLayer(from: start)
        model.rotateSelectedLayer(to: end)
        let preview = try model.projectData()
        let didChange = abs(degrees) > 0.01
        #expect((preview != original) == didChange)
        model.finishRotatingSelectedLayer()
        #expect(!model.hasActiveSelectedLayerTransformTransaction)
        if didChange {
            let committed = try model.projectData()
            #expect(model.undoStack.count == undoCount + 1 && model.redoStack.isEmpty)
            #expect(model.document.history.count == historyCount + 1 && model.hasUnsavedProjectChanges)
            model.undo()
            #expect(try model.projectData() == original && !model.hasUnsavedProjectChanges)
            model.redo()
            #expect(try model.projectData() == committed)
            let restored = try fixture(.pixel)
            try restored.loadProjectData(committed)
            // PNG re-encoding can change the payload bytes, not the saved pixels.
            #expect(try projectMetadata(committed) == projectMetadata(restored.projectData()))
            let savedProject = try JSONDecoder().decode(ImageEditorProjectDocument.self, from: committed)
            let savedPNG = try #require(savedProject.layers[0].imageData)
            let savedBitmap = try #require(NSBitmapImageRep(data: savedPNG))
            let savedImage = try #require(savedBitmap.cgImage)
            let reopenedImage = try #require(restored.document.layers[0].image.cgImage(
                forProposedRect: nil, context: nil, hints: nil
            ))
            #expect(try rasterPixels(savedImage) == rasterPixels(reopenedImage))
            #expect(!restored.hasUnsavedProjectChanges)
        } else {
            #expect(try model.projectData() == original && !model.hasUnsavedProjectChanges)
            #expect(model.undoStack.count == undoCount && model.redoStack.count == 1)
            model.redo()
            #expect(try model.projectData() == pending)
        }
    }

    private func projectMetadata(_ data: Data) throws -> NSDictionary {
        var project = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var layers = try #require(project["layers"] as? [[String: Any]])
        for index in layers.indices { layers[index].removeValue(forKey: "imageData") }
        project["layers"] = layers
        return project as NSDictionary
    }

    @Test(arguments: [false, true])
    func projectLayerAndMaskKeepExactStoredPixelsIncludingFractionalSize(mask: Bool) throws {
        let model = try fixture(.pixel)
        let size = CGSize(width: 37.25, height: 29.75)
        let image = try #require(NSImage.rendered(size: size) { rect in
            NSColor(red: 0.2, green: 0.6, blue: 0.9, alpha: 0.65).setFill()
            rect.fill()
            NSColor.red.setFill()
            CGRect(x: 4, y: 7, width: 9, height: 11).fill()
        })
        if mask { model.document.layers[0].mask = image }
        else { model.document.layers[0].image = image }
        let project = try JSONDecoder().decode(ImageEditorProjectDocument.self, from: model.projectData())
        let layer = try project.layers[0].restoredLayer()
        let storedData = try #require(mask ? project.layers[0].maskData : project.layers[0].imageData)
        let stored = try #require(NSBitmapImageRep(data: storedData)?.cgImage)
        let restored = try #require((mask ? layer.mask : layer.image)?.cgImage(
            forProposedRect: nil, context: nil, hints: nil
        ))
        #expect(try rasterPixels(stored) == rasterPixels(restored))
        #expect(layer.frame == model.document.layers[0].frame)
        #expect(layer.isMaskLinked == model.document.layers[0].isMaskLinked)
    }

    @Test func malformedProjectRasterIsRejected() {
        #expect(ImageEditorProjectRasterData.decodedImage(Data("not a bitmap".utf8)) == nil)
    }

    private func rasterPixels(_ cgImage: CGImage) throws -> RasterPixels {
        let bytesPerPixel = 4
        let bytesPerRow = cgImage.width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: cgImage.height * bytesPerRow)
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        try pixels.withUnsafeMutableBytes { bytes in
            let context = try #require(CGContext(
                data: bytes.baseAddress, width: cgImage.width, height: cgImage.height,
                bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
            ))
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        }
        return RasterPixels(width: cgImage.width, height: cgImage.height, bytes: pixels)
    }

    private func fixture(_ content: Content) throws -> ImageEditorViewModel {
        let model = try ImageEditorPixelMoveWorkflowFixture.model(size: 256)
        model.document.selection = nil
        model.document.isGuideSnappingEnabled = false
        switch content {
        case .pixel: break
        case .unlinkedMask:
            model.document.layers[0].isMaskLinked = false
            model.document.layers[0].mask = try #require(NSImage.rendered(size: CGSize(width: 256, height: 256)) { _ in
                NSColor.white.setFill()
                CGRect(x: 20, y: 20, width: 180, height: 160).fill()
            })
        case .component:
            model.insertXomoComponent(.button, at: CGPoint(x: 40, y: 40))
        case .paragraph:
            model.textValue = "Paragraph resize transaction"
            model.textBoxWidth = 100
            model.textBoxHeight = 60
            model.addText(at: CGPoint(x: 20, y: 20))
            #expect(model.document.selectedLayer?.textContent?.layoutMode == .paragraph)
        }
        model.clearUndoHistory()
        return model
    }
}
