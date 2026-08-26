import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct XomoLayerClipboardTests {
    @Test func multiSelectionPasteKeepsTextAndShapeEditableWithNewIDs() throws {
        let canvasSize = CGSize(width: 240, height: 180)
        let viewModel = ImageEditorViewModel(
            sourceName: "editable-clipboard.xomo",
            image: .transparent(size: canvasSize)
        ) { _ in }
        let text = ImageEditorLayer.text(
            name: "Editable title",
            origin: CGPoint(x: 24, y: 28),
            content: ImageEditorTextContent(
                text: "Keep me editable",
                color: .labelColor,
                fontSize: 19,
                point: CGPoint(x: 2, y: 2),
                isBold: true
            )
        )
        let shape = ImageEditorLayer.shape(
            name: "Editable badge",
            frame: CGRect(x: 80, y: 70, width: 64, height: 36),
            content: ImageEditorShapeContent(
                kind: .rectangle,
                fillColor: .systemIndigo,
                fillOpacity: 0.8,
                strokeColor: .white,
                strokeWidth: 2,
                strokeOpacity: 1,
                cornerRadius: 9
            )
        )
        viewModel.document.layers.append(contentsOf: [text, shape])
        viewModel.document.selectedLayerIDs = [text.id, shape.id]
        viewModel.document.selectedLayerID = shape.id
        let originalIDs: Set<UUID> = [text.id, shape.id]
        let originalLayerCount = viewModel.document.layers.count
        let historyCount = viewModel.document.history.count
        let pasteboard = NSPasteboard(name: .init("im.some.xomo.tests.editable-multi.\(UUID())"))
        pasteboard.clearContents()
        defer { pasteboard.clearContents() }

        #expect(viewModel.copySelectedLayersToClipboard(to: pasteboard))
        #expect(pasteboard.data(forType: XomoLayerClipboardArchive.pasteboardType) != nil)
        #expect(pasteboard.data(forType: .png) != nil)
        #expect(viewModel.pasteClipboardAsLayer(from: pasteboard))

        #expect(viewModel.document.layers.count == originalLayerCount + 2)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs.count == 2)
        #expect(viewModel.document.selectedLayerIDs.isDisjoint(with: originalIDs))
        let pastedText = try #require(viewModel.document.layers.last { $0.name == text.name })
        let pastedShape = try #require(viewModel.document.layers.last { $0.name == shape.name })
        #expect(pastedText.id != text.id)
        #expect(pastedShape.id != shape.id)
        #expect(pastedText.frame == text.frame.offsetBy(dx: 10, dy: 10))
        #expect(pastedShape.frame == shape.frame.offsetBy(dx: 10, dy: 10))
        if case .text(let content) = pastedText.kind {
            #expect(content.text == "Keep me editable")
            #expect(content.isBold)
        } else {
            Issue.record("Pasted text was rasterized")
        }
        if case .shape(let content) = pastedShape.kind {
            #expect(content.kind == .rectangle)
            #expect(content.cornerRadius == 9)
        } else {
            Issue.record("Pasted shape was rasterized")
        }

        viewModel.undo()
        #expect(viewModel.document.layers.count == originalLayerCount)
        #expect(viewModel.document.layers.contains { $0.id == text.id })
        #expect(viewModel.document.layers.contains { $0.id == shape.id })
    }

    @Test func componentCutAndPasteInPlaceRemapsTheWholeEditableHierarchy() throws {
        let canvasSize = CGSize(width: 300, height: 220)
        let viewModel = ImageEditorViewModel(
            sourceName: "component-clipboard.xomo",
            image: .transparent(size: canvasSize)
        ) { _ in }
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 70, y: 80))
        viewModel.setSelectedXomoComponentAsMaster()
        let originalRoot = try #require(viewModel.document.selectedLayer)
        #expect(originalRoot.isGroup)
        #expect(originalRoot.xomoComponentInstance?.masterID == originalRoot.id)
        let originalSubtree = viewModel.document.layers.filter {
            $0.id == originalRoot.id || $0.groupID == originalRoot.id
        }
        let originalIDs = Set(originalSubtree.map(\.id))
        let historyBeforeCut = viewModel.document.history.count
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        defer { pasteboard.clearContents() }

        #expect(viewModel.canCutSelectedLayersToClipboard)
        #expect(viewModel.cutSelectionToClipboard())
        #expect(viewModel.document.layers.allSatisfy { !originalIDs.contains($0.id) })
        #expect(viewModel.document.history.count == historyBeforeCut + 1)
        #expect(pasteboard.data(forType: XomoLayerClipboardArchive.pasteboardType) != nil)

        #expect(viewModel.pasteClipboardInPlaceAsLayer(from: pasteboard))
        let pastedRoot = try #require(viewModel.document.selectedLayer)
        let pastedSubtree = viewModel.document.layers.filter {
            $0.id == pastedRoot.id || $0.groupID == pastedRoot.id
        }
        #expect(pastedRoot.id != originalRoot.id)
        #expect(pastedRoot.isGroup)
        #expect(pastedRoot.xomoComponentInstance?.kind == .button)
        #expect(pastedRoot.xomoComponentInstance?.masterID == pastedRoot.id)
        #expect(pastedSubtree.count == originalSubtree.count)
        #expect(Set(pastedSubtree.map(\.id)).isDisjoint(with: originalIDs))
        for (source, pasted) in zip(originalSubtree, pastedSubtree) {
            #expect(source.name == pasted.name)
            #expect(layerKindName(source.kind) == layerKindName(pasted.kind))
            #expect(source.frame == pasted.frame)
            #expect(
                source.id == originalRoot.id
                    ? pasted.groupID == nil
                    : pasted.groupID == pastedRoot.id
            )
        }

        let pastedIDs = Set(pastedSubtree.map(\.id))
        viewModel.undo()
        #expect(viewModel.document.layers.allSatisfy { !pastedIDs.contains($0.id) })
        viewModel.undo()
        #expect(originalIDs.isSubset(of: Set(viewModel.document.layers.map(\.id))))
        #expect(viewModel.document.selectedLayerID == originalRoot.id)
    }

    @Test func archiveDropsExternalHierarchyLinksMastersAndOrphanClipping() throws {
        var layer = ImageEditorLayer.blank(
            name: "Detached object",
            size: CGSize(width: 32, height: 20)
        )
        layer.frame = CGRect(x: 8, y: 11, width: 32, height: 20)
        layer.groupID = UUID()
        layer.linkedLayerIDs = [UUID()]
        layer.isClippingMask = true
        layer.xomoComponentInstance = XomoComponentInstance(
            kind: .button,
            theme: .native,
            masterID: UUID()
        )
        let data = try #require(XomoLayerClipboardArchive.data(
            layers: [layer],
            selectedIDs: [layer.id],
            primarySelectionID: layer.id
        ))
        let pasteboard = NSPasteboard(name: .init("im.some.xomo.tests.detached.\(UUID())"))
        pasteboard.clearContents()
        defer { pasteboard.clearContents() }
        let item = NSPasteboardItem()
        item.setData(data, forType: XomoLayerClipboardArchive.pasteboardType)
        #expect(pasteboard.writeObjects([item]))

        let restored = try #require(XomoLayerClipboardArchive.restoredCopy(
            from: pasteboard,
            offset: CGPoint(x: 4, y: 6)
        ))
        let restoredLayer = try #require(restored.layers.first)
        #expect(restoredLayer.id != layer.id)
        #expect(restoredLayer.frame == layer.frame.offsetBy(dx: 4, dy: 6))
        #expect(restoredLayer.groupID == nil)
        #expect(restoredLayer.linkedLayerIDs.isEmpty)
        #expect(restoredLayer.xomoComponentInstance?.masterID == nil)
        #expect(!restoredLayer.isClippingMask)
    }

    @Test func malformedNativePayloadFallsBackToThePublicPNG() throws {
        let clipboardImage = solidImage(
            color: .systemOrange,
            size: CGSize(width: 18, height: 12)
        )
        let pngData = try #require(clipboardImage.qingtuPNGData())
        let pasteboard = NSPasteboard(name: .init("im.some.xomo.tests.corrupt.\(UUID())"))
        pasteboard.clearContents()
        defer { pasteboard.clearContents() }
        let item = NSPasteboardItem()
        item.setData(Data("not-an-archive".utf8), forType: XomoLayerClipboardArchive.pasteboardType)
        item.setData(pngData, forType: .png)
        #expect(pasteboard.writeObjects([item]))
        let viewModel = ImageEditorViewModel(
            sourceName: "corrupt-fallback.xomo",
            image: .transparent(size: CGSize(width: 80, height: 60))
        ) { _ in }

        #expect(viewModel.pasteClipboardAsLayer(from: pasteboard))
        let pasted = try #require(viewModel.document.selectedLayer)
        #expect(pasted.kind.isPixel)
        #expect(pasted.image.size == clipboardImage.size)
        #expect(
            viewModel.document.history.last?.title
                == L10n.text("imageEditor.history.clipboardPasteLayer")
        )
    }

    private func solidImage(color: NSColor, size: CGSize) -> NSImage {
        NSImage(size: size, flipped: false) { rect in
            color.setFill()
            rect.fill()
            return true
        }
    }

    private func layerKindName(_ kind: ImageEditorLayerKind) -> String {
        switch kind {
        case .pixel: "pixel"
        case .group: "group"
        case .adjustment: "adjustment"
        case .filter: "filter"
        case .solidColorFill: "solidColorFill"
        case .patternFill: "patternFill"
        case .gradientFill: "gradientFill"
        case .text: "text"
        case .shape: "shape"
        case .smartObject: "smartObject"
        }
    }
}
