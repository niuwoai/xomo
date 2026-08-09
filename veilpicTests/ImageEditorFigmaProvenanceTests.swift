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
        layer.xomoFigmaSizeConstraints = XomoFigmaSizeConstraints(
            minWidth: 120,
            maxWidth: 360,
            minHeight: 44,
            maxHeight: 88
        )
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
        layer.xomoFigmaImageFill = XomoFigmaImageFillMetadata(
            imageReference: "img-ref-hero",
            scaleMode: "CROP",
            imageTransform: XomoFigmaPlanTransform([
                [0.8, 0.1, 0.12],
                [-0.1, 0.9, 0.08]
            ]),
            scalingFactor: 1.5,
            rotation: 90,
            filters: XomoFigmaPlanImageFilters(exposure: 0.25, contrast: -0.2, saturation: 0.1)
        )
        document.layers = [layer]
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]

        let viewModel = ImageEditorViewModel(document: document) { _ in }
        #expect(viewModel.selectedLayerFigmaSourceID == "1:60")
        #expect(viewModel.selectedLayerFigmaNodeType == "BOOLEAN_OPERATION")
        #expect(viewModel.selectedLayerFigmaSizeConstraints == layer.xomoFigmaSizeConstraints)
        #expect(viewModel.selectedLayerFigmaComponentRole == .instance)
        #expect(viewModel.selectedLayerFigmaComponentProperties["Size"]?.value == "Large")
        #expect(viewModel.selectedLayerFigmaImageFill?.imageReference == "img-ref-hero")
        #expect(viewModel.selectedLayerFigmaImageFill?.scaleMode == "CROP")

        viewModel.copySelectedFigmaSourceReference()
        #expect(NSPasteboard.general.string(forType: .string) == "BOOLEAN_OPERATION:1:60")

        viewModel.copySelectedFigmaSourceURL()
        #expect(NSPasteboard.general.string(forType: .string) == "https://www.figma.com/design/abc123/Checkout?node-id=1-60")

        viewModel.copySelectedFigmaComponentProperties()
        let copied = try #require(NSPasteboard.general.string(forType: .string))
        #expect(copied.contains("\"Is Enabled\""))
        #expect(copied.contains("\"VARIANT\""))

        viewModel.copySelectedFigmaImageFill()
        let copiedImageFill = try #require(NSPasteboard.general.string(forType: .string))
        #expect(copiedImageFill.contains("\"img-ref-hero\""))
        #expect(copiedImageFill.contains("\"CROP\""))
        #expect(copiedImageFill.contains("\"exposure\""))

        let project = try ImageEditorProjectDocument(document: document)
        let restored = try project.restoredDocument()
        #expect(restored.layers.first?.xomoFigmaComponentProperties == layer.xomoFigmaComponentProperties)
        #expect(restored.layers.first?.xomoFigmaImageFill == layer.xomoFigmaImageFill)
        #expect(restored.layers.first?.xomoFigmaSizeConstraints == layer.xomoFigmaSizeConstraints)
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

    @Test func editableFigmaImageFillParametersUseUndoAndRemainProjectCodable() throws {
        let image = NSImage.rendered(size: CGSize(width: 40, height: 20)) { rect in
            NSColor.systemBlue.setFill()
            rect.fill()
        }!
        var document = ImageEditorDocument(sourceName: "figma-fill-controls.png", image: image)
        var layer = document.layers[0]
        layer.xomoFigmaImageFill = XomoFigmaImageFillMetadata(
            imageReference: "img-ref-controls",
            scaleMode: "CROP",
            imageTransform: nil,
            scalingFactor: 1,
            rotation: 0,
            filters: XomoFigmaPlanImageFilters(),
            sourcePixelSize: XomoFigmaPlanSize(width: 40, height: 20),
            importScale: 1
        )
        layer.xomoFigmaImageFillSourceImage = image
        document.layers = [layer]
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]

        let viewModel = ImageEditorViewModel(document: document) { _ in }
        #expect(viewModel.canEditSelectedFigmaImageFill)
        viewModel.updateSelectedFigmaImageFillScaleMode("TILE")
        viewModel.updateSelectedFigmaImageFillScalingFactor(2)
        viewModel.updateSelectedFigmaImageFillRotation(45)
        viewModel.updateSelectedFigmaImageFillOffsetX(0.25)
        viewModel.updateSelectedFigmaImageFillOffsetY(-0.15)
        viewModel.updateSelectedFigmaImageFillMatrixM11(0.8)
        viewModel.updateSelectedFigmaImageFillMatrixM12(0.25)
        viewModel.updateSelectedFigmaImageFillMatrixM21(-0.1)
        viewModel.updateSelectedFigmaImageFillMatrixM22(0.9)

        #expect(viewModel.selectedLayerFigmaImageFill?.scaleMode == "TILE")
        #expect(viewModel.selectedLayerFigmaImageFill?.scalingFactor == 2)
        #expect(viewModel.selectedLayerFigmaImageFill?.rotation == 45)
        #expect(viewModel.selectedLayerFigmaImageFill?.imageTransform?.translationX == 0.25)
        #expect(viewModel.selectedLayerFigmaImageFill?.imageTransform?.translationY == -0.15)
        #expect(viewModel.selectedLayerFigmaImageFill?.imageTransform?.m11 == 0.8)
        #expect(viewModel.selectedLayerFigmaImageFill?.imageTransform?.m12 == 0.25)
        #expect(viewModel.selectedLayerFigmaImageFill?.imageTransform?.m21 == -0.1)
        #expect(viewModel.selectedLayerFigmaImageFill?.imageTransform?.m22 == 0.9)
        #expect(viewModel.document.selectedLayer?.contentImage.size == image.size)

        viewModel.undo()
        #expect(viewModel.selectedLayerFigmaImageFill?.imageTransform?.m22 == 1)
        viewModel.undo()
        #expect(viewModel.selectedLayerFigmaImageFill?.imageTransform?.m21 == 0)
        viewModel.undo()
        #expect(viewModel.selectedLayerFigmaImageFill?.imageTransform?.m12 == 0)
        viewModel.undo()
        #expect(viewModel.selectedLayerFigmaImageFill?.imageTransform?.m11 == 1)
        viewModel.undo()
        #expect((viewModel.selectedLayerFigmaImageFill?.imageTransform?.translationY ?? 0) == 0)
        viewModel.undo()
        #expect((viewModel.selectedLayerFigmaImageFill?.imageTransform?.translationX ?? 0) == 0)
        viewModel.undo()
        #expect(viewModel.selectedLayerFigmaImageFill?.rotation == 0)
        viewModel.undo()
        #expect(viewModel.selectedLayerFigmaImageFill?.scalingFactor == 1)
        viewModel.undo()
        #expect(viewModel.selectedLayerFigmaImageFill?.scaleMode == "CROP")

        let project = try ImageEditorProjectDocument(document: document)
        let restored = try project.restoredDocument()
        #expect(restored.layers.first?.xomoFigmaImageFill?.imageReference == "img-ref-controls")
        #expect(restored.layers.first?.xomoFigmaImageFillSourceImage != nil)
    }

    @Test func automationEditsSelectedFigmaImageFillAndUsesUndoableViewModelPath() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].xomoFigmaImageFill = XomoFigmaImageFillMetadata(
            imageReference: "img-ref-controls",
            scaleMode: "CROP",
            imageTransform: nil,
            scalingFactor: 1,
            rotation: 0,
            filters: XomoFigmaPlanImageFilters(),
            sourcePixelSize: XomoFigmaPlanSize(width: 40, height: 20),
            importScale: 1
        )
        viewModel.document.layers[layerIndex].xomoFigmaImageFillSourceImage =
            NSImage.transparent(size: CGSize(width: 40, height: 20))

        let listed = registry.execute(request(
            operation: "call",
            name: "xomo.figma.image_fill",
            arguments: ["action": .string("list")]
        ))
        #expect(listed.ok)
        #expect(listed.result?.objectValue?["editable"] == .bool(true))
        #expect(listed.result?.objectValue?["imageFill"]?.objectValue?["scaleMode"] == .string("CROP"))

        let scaleMode = registry.execute(request(
            operation: "call",
            name: "xomo.figma.image_fill",
            arguments: [
                "action": .string("set"),
                "property": .string("scaleMode"),
                "scaleMode": .string("TILE")
            ]
        ))
        #expect(scaleMode.ok)
        let matrix = registry.execute(request(
            operation: "call",
            name: "xomo.figma.image_fill",
            arguments: [
                "action": .string("set"),
                "property": .string("m11"),
                "value": .number(0.75)
            ]
        ))
        #expect(matrix.ok)
        let filters = registry.execute(request(
            operation: "call",
            name: "xomo.figma.image_fill",
            arguments: [
                "action": .string("set"),
                "property": .string("filtersEnabled"),
                "enabled": .bool(false)
            ]
        ))
        #expect(filters.ok)
        #expect(viewModel.selectedLayerFigmaImageFill?.scaleMode == "TILE")
        #expect(viewModel.selectedLayerFigmaImageFill?.imageTransform?.m11 == 0.75)
        #expect(viewModel.selectedLayerFigmaImageFillFiltersEnabled == false)

        viewModel.undo()
        #expect(viewModel.selectedLayerFigmaImageFillFiltersEnabled)
        viewModel.undo()
        #expect((viewModel.selectedLayerFigmaImageFill?.imageTransform?.m11 ?? 1) == 1)
        viewModel.undo()
        #expect(viewModel.selectedLayerFigmaImageFill?.scaleMode == "CROP")
    }

    @Test func componentTextOverrideUpdatesMatchingEditableDescendantAndUndoRestoresIt() throws {
        let image = NSImage.transparent(size: CGSize(width: 320, height: 180))
        var document = ImageEditorDocument(sourceName: "figma-text-component.png", image: image)
        var component = ImageEditorLayer.group(name: "Button", size: CGSize(width: 140, height: 44))
        component.frame.origin = CGPoint(x: 40, y: 60)
        component.xomoFigmaComponentProperties = [
            "Label": XomoFigmaComponentProperty(type: "TEXT", value: "Continue")
        ]
        component.xomoFigmaComponentPropertyDefaults = component.xomoFigmaComponentProperties
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
        #expect(viewModel.document.selectedLayer?.xomoFigmaComponentPropertyDefaults["Label"]?.value == "Continue")
        #expect(viewModel.document.layers[1].textContent?.text == "Buy now")
        #expect(viewModel.document.layers[1].isText)

        viewModel.resetSelectedFigmaComponentProperty("Label")
        #expect(viewModel.document.selectedLayer?.xomoFigmaComponentProperties["Label"]?.value == "Continue")
        #expect(viewModel.document.layers[1].textContent?.text == "Continue")

        viewModel.undo()
        #expect(viewModel.document.selectedLayer?.xomoFigmaComponentProperties["Label"]?.value == "Buy now")
        #expect(viewModel.document.layers[1].textContent?.text == "Buy now")
        viewModel.redo()
        #expect(viewModel.document.selectedLayer?.xomoFigmaComponentProperties["Label"]?.value == "Continue")
        #expect(viewModel.document.layers[1].textContent?.text == "Continue")

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restored = try project.restoredDocument()
        #expect(restored.layers.first?.xomoFigmaComponentPropertyDefaults["Label"]?.value == "Continue")
    }

    @Test func figmaSizeConstraintInspectorIsVisibleLocalizedAndReadOnly() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("viewModel.selectedLayerFigmaSizeConstraints"))
        #expect(source.contains("image-editor-figma-size-constraints"))
        #expect(source.contains("image-editor-figma-size-constraint-\\(identifier)"))
        #expect(source.contains("identifier: \"min-width\""))
        #expect(source.contains("identifier: \"max-width\""))
        #expect(source.contains("identifier: \"min-height\""))
        #expect(source.contains("identifier: \"max-height\""))
        #expect(source.contains("imageEditor.properties.figmaSizeConstraintsActive"))
        #expect(!source.contains("updateSelectedFigmaSizeConstraint"))
    }

    private func request(
        operation: String,
        name: String? = nil,
        arguments: [String: XomoJSONValue]? = nil
    ) -> XomoAutomationWireRequest {
        XomoAutomationWireRequest(
            token: "test",
            operation: operation,
            name: name,
            arguments: arguments
        )
    }

    private func makeViewModel() -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "figma-automation",
            image: NSImage.transparent(size: CGSize(width: 320, height: 240))
        ) { _ in }
    }
}
