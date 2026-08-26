import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorSmartObjectContextTests {
    @Test func unselectedContextCreatesIndependentSmartObjectCopy() throws {
        let viewModel = makeViewModel()
        let ordinaryID = try #require(viewModel.document.selectedLayerID)
        let smartObject = makeSmartObject(
            name: "Shared Logo",
            originalSize: CGSize(width: 24, height: 16),
            frame: CGRect(x: 42, y: 30, width: 48, height: 32)
        )
        viewModel.document.layers.append(smartObject)
        viewModel.selectLayer(ordinaryID)
        let originalLayerIDs = viewModel.document.layers.map(\.id)
        let sourceID = try #require(smartObject.smartObjectContent?.sourceID)
        let historyCount = viewModel.document.history.count

        #expect(viewModel.canPerformSmartObjectActionFromContext(
            smartObject.id,
            action: .newViaCopy
        ))
        #expect(viewModel.performSmartObjectActionFromContext(
            smartObject.id,
            action: .newViaCopy
        ))
        let copy = try #require(viewModel.document.selectedLayer)
        #expect(copy.id != smartObject.id)
        #expect(copy.smartObjectContent?.sourceID != sourceID)
        #expect(copy.frame == smartObject.frame)
        #expect(viewModel.document.layers.contains { $0.id == ordinaryID })
        #expect(viewModel.document.layers.contains { $0.id == smartObject.id })
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text(
            "imageEditor.history.layerSmartObjectViaCopy"
        ))

        viewModel.undo()
        #expect(viewModel.document.layers.map(\.id) == originalLayerIDs)
        #expect(viewModel.document.selectedLayerIDs == [smartObject.id])
    }

    @Test func selectedContextMakesSharedInstancesUniqueInOneUndoStep() throws {
        let viewModel = makeViewModel()
        let sharedSourceID = UUID()
        let first = makeSmartObject(
            name: "First",
            originalSize: CGSize(width: 20, height: 14),
            frame: CGRect(x: 20, y: 18, width: 20, height: 14),
            sourceID: sharedSourceID
        )
        let second = makeSmartObject(
            name: "Second",
            originalSize: CGSize(width: 20, height: 14),
            frame: CGRect(x: 52, y: 18, width: 20, height: 14),
            sourceID: sharedSourceID
        )
        let peer = makeSmartObject(
            name: "Peer",
            originalSize: CGSize(width: 20, height: 14),
            frame: CGRect(x: 84, y: 18, width: 20, height: 14),
            sourceID: sharedSourceID
        )
        viewModel.document.layers = [first, second, peer]
        viewModel.selectLayer(first.id)
        viewModel.selectLayer(second.id, extendingSelection: true)
        let historyCount = viewModel.document.history.count

        #expect(viewModel.canPerformSmartObjectActionFromContext(
            first.id,
            action: .makeUnique
        ))
        #expect(viewModel.performSmartObjectActionFromContext(
            first.id,
            action: .makeUnique
        ))
        let firstSourceID = try #require(sourceID(of: first.id, in: viewModel))
        let secondSourceID = try #require(sourceID(of: second.id, in: viewModel))
        #expect(firstSourceID != sharedSourceID)
        #expect(secondSourceID != sharedSourceID)
        #expect(firstSourceID != secondSourceID)
        #expect(sourceID(of: peer.id, in: viewModel) == sharedSourceID)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id])
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text(
            "imageEditor.history.layerSmartObjectMakeUniqueSelected"
        ))

        viewModel.undo()
        #expect(sourceID(of: first.id, in: viewModel) == sharedSourceID)
        #expect(sourceID(of: second.id, in: viewModel) == sharedSourceID)
        #expect(sourceID(of: peer.id, in: viewModel) == sharedSourceID)
    }

    @Test func resetTransformTargetsClickedObjectAndNoOpPreservesRedo() throws {
        let viewModel = makeViewModel()
        let ordinaryID = try #require(viewModel.document.selectedLayerID)
        let smartObject = makeSmartObject(
            name: "Scaled Symbol",
            originalSize: CGSize(width: 20, height: 10),
            frame: CGRect(x: 50, y: 30, width: 40, height: 20)
        )
        viewModel.document.layers.append(smartObject)
        viewModel.selectLayer(ordinaryID)
        let historyCount = viewModel.document.history.count

        #expect(viewModel.performSmartObjectActionFromContext(
            smartObject.id,
            action: .resetTransform
        ))
        #expect(frame(of: smartObject.id, in: viewModel) == CGRect(
            x: 60,
            y: 35,
            width: 20,
            height: 10
        ))
        #expect(viewModel.document.selectedLayerIDs == [smartObject.id])
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(!viewModel.canPerformSmartObjectActionFromContext(
            smartObject.id,
            action: .resetTransform
        ))

        viewModel.setSelectedLayersLabelColor(.purple)
        viewModel.undo()
        let historyBefore = viewModel.document.history
        #expect(viewModel.canRedo)
        #expect(!viewModel.performSmartObjectActionFromContext(
            smartObject.id,
            action: .resetTransform
        ))
        #expect(viewModel.document.history == historyBefore)
        #expect(viewModel.canRedo)
    }

    @Test func fileActionsPrepareClickedTargetBeforePresentingPanels() throws {
        let viewModel = makeViewModel()
        let ordinaryID = try #require(viewModel.document.selectedLayerID)
        let smartObject = makeSmartObject(
            name: "File Target",
            originalSize: CGSize(width: 26, height: 18),
            frame: CGRect(x: 36, y: 24, width: 26, height: 18)
        )
        viewModel.document.layers.append(smartObject)
        viewModel.selectLayer(ordinaryID)
        let smartSourceID = try #require(smartObject.smartObjectContent?.sourceID)
        var replacementSelection: Set<UUID> = []
        var replacementSourceIDs: Set<UUID> = []
        var exportSelection: Set<UUID> = []
        var exportedData: Data?
        var exportedFilename: String?
        let historyBefore = viewModel.document.history

        #expect(viewModel.canPerformSmartObjectActionFromContext(
            smartObject.id,
            action: .replaceContents
        ))
        #expect(viewModel.performSmartObjectActionFromContext(
            smartObject.id,
            action: .replaceContents,
            chooseReplacement: { sourceIDs in
                replacementSelection = viewModel.document.selectedLayerIDs
                replacementSourceIDs = sourceIDs
                viewModel.selectLayer(ordinaryID)
            }
        ))
        #expect(replacementSelection == [smartObject.id])
        #expect(replacementSourceIDs == [smartSourceID])

        #expect(viewModel.document.selectedLayerIDs == [ordinaryID])
        #expect(viewModel.canPerformSmartObjectActionFromContext(
            smartObject.id,
            action: .exportSourcePNG
        ))
        #expect(viewModel.performSmartObjectActionFromContext(
            smartObject.id,
            action: .exportSourcePNG,
            chooseSourcePNGDestination: { data, filename in
                exportSelection = viewModel.document.selectedLayerIDs
                exportedData = data
                exportedFilename = filename
                viewModel.selectLayer(ordinaryID)
            }
        ))
        #expect(exportSelection == [smartObject.id])
        #expect(exportedFilename == "File Target.png")
        #expect(exportedData == smartObject.image.qingtuPNGData())
        #expect(viewModel.document.selectedLayerIDs == [ordinaryID])
        #expect(viewModel.document.history == historyBefore)

        var writtenData: Data?
        let destination = URL(fileURLWithPath: "/tmp/context-source.png")
        #expect(viewModel.writeSmartObjectSourcePNG(
            try #require(exportedData),
            to: destination,
            dataWriter: { data, _ in writtenData = data }
        ))
        #expect(writtenData == exportedData)
        #expect(viewModel.document.selectedLayerIDs == [ordinaryID])

        let replacement = image(
            color: .systemPurple,
            size: CGSize(width: 14, height: 10)
        )
        #expect(viewModel.replaceSmartObjectContents(
            replacement,
            sourceName: "replacement.png",
            targetSourceIDs: replacementSourceIDs
        ) == .changed)
        #expect(viewModel.document.layers.first { $0.id == smartObject.id }?
            .image.qingtuPNGData() == replacement.qingtuPNGData())
        #expect(viewModel.document.selectedLayerIDs == [ordinaryID])
        viewModel.undo()

        let secondSmartObject = makeSmartObject(
            name: "Second File Target",
            originalSize: CGSize(width: 18, height: 12),
            frame: CGRect(x: 72, y: 24, width: 18, height: 12)
        )
        viewModel.document.layers.append(secondSmartObject)
        viewModel.selectLayer(smartObject.id)
        viewModel.selectLayer(secondSmartObject.id, extendingSelection: true)
        #expect(viewModel.canPerformSmartObjectActionFromContext(
            smartObject.id,
            action: .replaceContents
        ))
        #expect(!viewModel.canPerformSmartObjectActionFromContext(
            smartObject.id,
            action: .exportSourcePNG
        ))
    }

    private func makeViewModel() -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "smart-object-context.png",
            image: image(color: .systemGray, size: CGSize(width: 140, height: 90))
        ) { _ in }
    }

    private func makeSmartObject(
        name: String,
        originalSize: CGSize,
        frame: CGRect,
        sourceID: UUID = UUID()
    ) -> ImageEditorLayer {
        let sourceImage = image(color: .systemOrange, size: originalSize)
        var layer = ImageEditorLayer.smartObject(
            name: name,
            image: sourceImage,
            sourceName: "\(name).png"
        )
        layer.kind = .smartObject(ImageEditorSmartObjectContent(
            sourceName: "\(name).png",
            originalSize: originalSize,
            sourceID: sourceID
        ))
        layer.frame = frame
        return layer
    }

    private func sourceID(
        of layerID: UUID,
        in viewModel: ImageEditorViewModel
    ) -> UUID? {
        viewModel.document.layers.first { $0.id == layerID }?
            .smartObjectContent?.sourceID
    }

    private func frame(
        of layerID: UUID,
        in viewModel: ImageEditorViewModel
    ) -> CGRect? {
        viewModel.document.layers.first { $0.id == layerID }?.frame.standardized
    }

    private func image(color: NSColor, size: CGSize) -> NSImage {
        NSImage.rendered(size: size) { rect in
            color.setFill()
            rect.fill()
        } ?? NSImage.transparent(size: size)
    }
}
