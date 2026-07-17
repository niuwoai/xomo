import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorFigmaProvenanceTests {
    @Test func selectedLayerExposesAndCopiesFigmaSourceReference() throws {
        let image = NSImage.transparent(size: CGSize(width: 20, height: 20))
        var document = ImageEditorDocument(sourceName: "figma.png", image: image)
        var layer = document.layers[0]
        layer.xomoFigmaSourceID = "1:60"
        layer.xomoFigmaNodeType = "BOOLEAN_OPERATION"
        layer.xomoFigmaComponentRole = .instance
        layer.xomoFigmaComponentProperties = [
            "Size": XomoFigmaComponentProperty(
                type: "VARIANT",
                value: "Large",
                preferredValues: [XomoFigmaComponentPreferredValue(key: "Large", name: "Large")]
            ),
            "Is Enabled": XomoFigmaComponentProperty(type: "BOOLEAN", value: "true")
        ]
        layer.xomoFigmaSourceURL = URL(string: "https://www.figma.com/design/abc123/Checkout?node-id=1-60")
        document.layers = [layer]
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]

        let viewModel = ImageEditorViewModel(document: document) { _ in }
        #expect(viewModel.selectedLayerFigmaSourceID == "1:60")
        #expect(viewModel.selectedLayerFigmaNodeType == "BOOLEAN_OPERATION")
        #expect(viewModel.selectedLayerFigmaComponentRole == .instance)
        #expect(viewModel.selectedLayerFigmaComponentProperties["Size"]?.value == "Large")

        viewModel.copySelectedFigmaSourceReference()
        #expect(NSPasteboard.general.string(forType: .string) == "BOOLEAN_OPERATION:1:60")

        viewModel.copySelectedFigmaSourceURL()
        #expect(NSPasteboard.general.string(forType: .string) == "https://www.figma.com/design/abc123/Checkout?node-id=1-60")

        viewModel.copySelectedFigmaComponentProperties()
        let copied = try #require(NSPasteboard.general.string(forType: .string))
        #expect(copied.contains("\"Is Enabled\""))
        #expect(copied.contains("\"VARIANT\""))

        let project = try ImageEditorProjectDocument(document: document)
        let restored = try project.restoredDocument()
        #expect(restored.layers.first?.xomoFigmaComponentProperties == layer.xomoFigmaComponentProperties)
    }

    @Test func componentPropertyLocalOverrideUsesUndoAndRedo() throws {
        let image = NSImage.transparent(size: CGSize(width: 20, height: 20))
        var document = ImageEditorDocument(sourceName: "figma-component.png", image: image)
        var layer = document.layers[0]
        layer.xomoFigmaComponentProperties = [
            "Size": XomoFigmaComponentProperty(
                type: "VARIANT",
                value: "Large",
                preferredValues: [
                    XomoFigmaComponentPreferredValue(key: "small", name: "Small"),
                    XomoFigmaComponentPreferredValue(key: "large", name: "Large")
                ]
            ),
            "Is Enabled": XomoFigmaComponentProperty(type: "BOOLEAN", value: "true"),
            "Label": XomoFigmaComponentProperty(type: "TEXT", value: "Continue")
        ]
        document.layers = [layer]
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]

        let viewModel = ImageEditorViewModel(document: document) { _ in }
        viewModel.updateSelectedFigmaComponentProperty("Size", value: "Small")
        viewModel.updateSelectedFigmaComponentBooleanProperty("Is Enabled", isEnabled: false)
        viewModel.updateSelectedFigmaComponentProperty("Label", value: "")

        #expect(viewModel.document.layers[0].xomoFigmaComponentProperties["Size"]?.value == "Small")
        #expect(viewModel.document.layers[0].xomoFigmaComponentProperties["Is Enabled"]?.value == "false")
        #expect(viewModel.document.layers[0].xomoFigmaComponentProperties["Label"]?.value == "")

        viewModel.undo()
        #expect(viewModel.document.layers[0].xomoFigmaComponentProperties["Is Enabled"]?.value == "false")
        viewModel.undo()
        #expect(viewModel.document.layers[0].xomoFigmaComponentProperties["Is Enabled"]?.value == "true")
        #expect(viewModel.document.layers[0].xomoFigmaComponentProperties["Size"]?.value == "Small")

        viewModel.redo()
        #expect(viewModel.document.layers[0].xomoFigmaComponentProperties["Is Enabled"]?.value == "false")
        viewModel.redo()
        #expect(viewModel.document.layers[0].xomoFigmaComponentProperties["Label"]?.value == "")
    }

    @Test func componentTextOverrideUpdatesMatchingEditableDescendantAndUndoRestoresIt() throws {
        let image = NSImage.transparent(size: CGSize(width: 320, height: 180))
        var document = ImageEditorDocument(sourceName: "figma-text-component.png", image: image)
        var component = ImageEditorLayer.group(name: "Button", size: CGSize(width: 140, height: 44))
        component.frame.origin = CGPoint(x: 40, y: 60)
        component.xomoFigmaComponentProperties = [
            "Label": XomoFigmaComponentProperty(type: "TEXT", value: "Continue")
        ]
        var label = ImageEditorLayer.text(
            name: "Continue",
            origin: CGPoint(x: 56, y: 72),
            content: ImageEditorTextContent(
                text: "Continue",
                color: .white,
                fontSize: 14,
                point: CGPoint(x: ImageEditorTextContent.drawingPadding, y: ImageEditorTextContent.drawingPadding)
            )
        )
        label.groupID = component.id
        document.layers = [component, label]
        document.selectedLayerID = component.id
        document.selectedLayerIDs = [component.id]

        let viewModel = ImageEditorViewModel(document: document) { _ in }
        viewModel.updateSelectedFigmaComponentProperty("Label", value: "Buy now")

        #expect(viewModel.document.selectedLayer?.xomoFigmaComponentProperties["Label"]?.value == "Buy now")
        #expect(viewModel.document.layers[1].textContent?.text == "Buy now")
        #expect(viewModel.document.layers[1].isText)

        viewModel.undo()
        #expect(viewModel.document.selectedLayer?.xomoFigmaComponentProperties["Label"]?.value == "Continue")
        #expect(viewModel.document.layers[1].textContent?.text == "Continue")
    }
}
