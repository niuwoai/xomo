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
        layer.xomoFigmaSizeConstraintDefaults = layer.xomoFigmaSizeConstraints
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
        #expect(viewModel.selectedLayerFigmaSizeConstraintDefaults == layer.xomoFigmaSizeConstraintDefaults)
        #expect(viewModel.selectedLayerFigmaComponentRole == .instance)
        #expect(viewModel.selectedLayerFigmaComponentProperties["Size"]?.value == "Large")
        #expect(viewModel.selectedLayerFigmaImageFill?.imageReference == "img-ref-hero")
        #expect(viewModel.selectedLayerFigmaImageFill?.scaleMode == "CROP")

        viewModel.copySelectedFigmaSourceReference()
        #expect(NSPasteboard.general.string(forType: .string) == "BOOLEAN_OPERATION:1:60")

        viewModel.copySelectedFigmaSourceURL()
        #expect(NSPasteboard.general.string(forType: .string) == "https://www.figma.com/design/abc123/Checkout?node-id=1-60")
        #expect(NSPasteboard.general.string(forType: .URL) == "https://www.figma.com/design/abc123/Checkout?node-id=1-60")

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
        #expect(restored.layers.first?.xomoFigmaSizeConstraintDefaults == layer.xomoFigmaSizeConstraintDefaults)
    }

    @Test func selectedFigmaSourceOpensOnlyItsRevalidatedCanonicalURL() throws {
        let image = NSImage.transparent(size: CGSize(width: 20, height: 20))
        var document = ImageEditorDocument(sourceName: "figma-source.png", image: image)
        document.layers[0].xomoFigmaSourceURL = URL(
            string: "https://figma.com/design/abc123/Checkout?node-id=10-20&version-id=7&utm_source=mail"
        )
        document.layers[0].xomoFigmaSourceID = "I32:9;44:5"
        document.selectedLayerID = document.layers[0].id
        document.selectedLayerIDs = [document.layers[0].id]
        let viewModel = ImageEditorViewModel(document: document) { _ in }
        var openedURLs: [URL] = []

        #expect(viewModel.openSelectedFigmaSourceURL { url in
            openedURLs.append(url)
            return true
        })
        #expect(openedURLs.map(\.absoluteString) == [
            "https://www.figma.com/design/abc123/Checkout?node-id=I32-9%3B44-5&version-id=7"
        ])
        #expect(viewModel.statusText == L10n.text("imageEditor.status.figmaSourceOpened"))

        #expect(viewModel.copySelectedFigmaSourceURL())
        #expect(
            NSPasteboard.general.string(forType: .string) ==
                "https://www.figma.com/design/abc123/Checkout?node-id=I32-9%3B44-5&version-id=7"
        )
        #expect(
            NSPasteboard.general.string(forType: .URL) ==
                "https://www.figma.com/design/abc123/Checkout?node-id=I32-9%3B44-5&version-id=7"
        )

        viewModel.document.layers[0].xomoFigmaSourceID = "../../outside"
        #expect(viewModel.selectedLayerOpenableFigmaSourceURL == nil)
        #expect(!viewModel.openSelectedFigmaSourceURL { _ in
            Issue.record("Untrusted source URL reached the system opener")
            return true
        })
        #expect(viewModel.statusText == L10n.text("imageEditor.status.figmaSourceOpenFailed"))
        #expect(!viewModel.copySelectedFigmaSourceURL())
        #expect(viewModel.statusText == L10n.text("imageEditor.status.figmaSourceURLCopyFailed"))
    }

    @Test func selectedFigmaSourceReportsSystemOpenFailureAndPropertyPanelUsesTheSafeRoute() throws {
        let image = NSImage.transparent(size: CGSize(width: 20, height: 20))
        var document = ImageEditorDocument(sourceName: "figma-source.png", image: image)
        document.layers[0].xomoFigmaSourceURL = URL(
            string: "https://www.figma.com/design/abc123/Checkout?node-id=1-60"
        )
        document.layers[0].xomoFigmaSourceID = "1:60"
        document.selectedLayerID = document.layers[0].id
        document.selectedLayerIDs = [document.layers[0].id]
        let viewModel = ImageEditorViewModel(document: document) { _ in }

        var attemptedURL: URL?
        #expect(!viewModel.openSelectedFigmaSourceURL { url in
            attemptedURL = url
            return false
        })
        #expect(attemptedURL?.absoluteString == "https://www.figma.com/design/abc123/Checkout?node-id=1-60")
        #expect(viewModel.statusText == L10n.text("imageEditor.status.figmaSourceOpenFailed"))

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        #expect(source.contains("if viewModel.selectedLayerOpenableFigmaSourceURL != nil"))
        #expect(source.contains("viewModel.openSelectedFigmaSourceURL()"))
        #expect(source.contains("image-editor-open-figma-source-url"))
    }

    @Test func layerPanelSourceActionsResolveTheClickedLayerWithoutChangingSelectionDuringInspection() throws {
        let image = NSImage.transparent(size: CGSize(width: 20, height: 20))
        var document = ImageEditorDocument(sourceName: "figma-layers.png", image: image)
        let selectedLayerID = document.layers[0].id
        var sourceLayer = ImageEditorLayer.blank(name: "Imported child", size: image.size)
        sourceLayer.frame.origin = CGPoint(x: 30, y: 30)
        sourceLayer.xomoFigmaSourceID = "44:5"
        sourceLayer.xomoFigmaSourceURL = URL(
            string: "https://figma.com/design/abc123/Checkout?node-id=10-20&utm_source=mail"
        )
        document.layers.append(sourceLayer)
        document.selectedLayerID = selectedLayerID
        document.selectedLayerIDs = [selectedLayerID]
        let viewModel = ImageEditorViewModel(document: document) { _ in }

        #expect(
            viewModel.openableFigmaSourceURL(for: sourceLayer.id)?.absoluteString ==
                "https://www.figma.com/design/abc123/Checkout?node-id=44-5"
        )
        #expect(viewModel.document.selectedLayerID == selectedLayerID)
        #expect(viewModel.openableFigmaSourceURL(for: UUID()) == nil)

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let panel = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorLayerPanel.swift"),
            encoding: .utf8
        )
        #expect(panel.contains("if viewModel.openableFigmaSourceURL(for: layer.id) != nil"))
        #expect(panel.contains("viewModel.selectLayer(layer.id)\n                        viewModel.openSelectedFigmaSourceURL()"))
        #expect(panel.contains("viewModel.selectLayer(layer.id)\n                        viewModel.copySelectedFigmaSourceURL()"))
        #expect(panel.contains("image-editor-layer-open-figma-source-\\(layer.id.uuidString)"))
        #expect(panel.contains("image-editor-layer-copy-figma-source-\\(layer.id.uuidString)"))
    }

    @Test func componentPropertyLocalOverrideUsesUndoAndRedo() throws {
        let image = NSImage.transparent(size: CGSize(width: 20, height: 20))
        var document = ImageEditorDocument(sourceName: "figma-component.png", image: image)
        var layer = document.layers[0]
        layer.isLocked = false
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

    @Test func textComponentPropertyPreservesWhitespaceWhileNonTextStillNormalizes() throws {
        let image = NSImage.transparent(size: CGSize(width: 220, height: 100))
        var document = ImageEditorDocument(sourceName: "figma-text-whitespace.png", image: image)
        var component = ImageEditorLayer.group(name: "Button", size: image.size)
        component.xomoFigmaComponentProperties = [
            "Label": XomoFigmaComponentProperty(type: "TEXT", value: "Continue"),
            "Size": XomoFigmaComponentProperty(type: "VARIANT", value: "Large")
        ]
        var label = ImageEditorLayer.text(
            name: "Continue",
            origin: CGPoint(x: 12, y: 12),
            content: ImageEditorTextContent(
                text: "Continue",
                color: .white,
                fontSize: 14,
                point: CGPoint(
                    x: ImageEditorTextContent.drawingPadding,
                    y: ImageEditorTextContent.drawingPadding
                )
            )
        )
        label.groupID = component.id
        document.layers = [component, label]
        document.selectedLayerID = component.id
        document.selectedLayerIDs = [component.id]
        let viewModel = ImageEditorViewModel(document: document) { _ in }
        let undoCountBefore = viewModel.undoStack.count
        let historyCountBefore = viewModel.document.history.count

        viewModel.updateSelectedFigmaComponentProperty("Label", value: "  Buy now  ")
        #expect(viewModel.selectedLayerFigmaComponentProperties["Label"]?.value == "  Buy now  ")
        #expect(viewModel.document.layers[1].textContent?.text == "  Buy now  ")

        let whitespaceOnly = "\t \n"
        viewModel.updateSelectedFigmaComponentProperty("Label", value: whitespaceOnly)
        #expect(viewModel.selectedLayerFigmaComponentProperties["Label"]?.value == whitespaceOnly)
        #expect(viewModel.document.layers[1].textContent?.text == whitespaceOnly)
        #expect(
            viewModel.document.layers[1].name
                == L10n.format(
                    "imageEditor.layer.textName",
                    L10n.text("imageEditor.layer.textFallbackName")
                )
        )

        viewModel.updateSelectedFigmaComponentProperty("Label", value: "")
        #expect(viewModel.selectedLayerFigmaComponentProperties["Label"]?.value == "")
        #expect(viewModel.document.layers[1].textContent?.text == "")
        let textNoOpUndoCount = viewModel.undoStack.count
        let textNoOpRedoCount = viewModel.redoStack.count
        let textNoOpHistory = viewModel.document.history
        viewModel.updateSelectedFigmaComponentProperty("Label", value: "")
        #expect(viewModel.undoStack.count == textNoOpUndoCount)
        #expect(viewModel.redoStack.count == textNoOpRedoCount)
        #expect(viewModel.document.history == textNoOpHistory)

        viewModel.updateSelectedFigmaComponentProperty("Size", value: "  Compact \n")
        #expect(viewModel.selectedLayerFigmaComponentProperties["Size"]?.value == "Compact")
        #expect(viewModel.undoStack.count == undoCountBefore + 4)
        #expect(viewModel.document.history.count == historyCountBefore + 4)
        let variantNoOpUndoCount = viewModel.undoStack.count
        let variantNoOpRedoCount = viewModel.redoStack.count
        let variantNoOpHistory = viewModel.document.history
        let propertiesBeforeRejectedBlank = viewModel.selectedLayerFigmaComponentProperties
        viewModel.updateSelectedFigmaComponentProperty("Size", value: " \t\n ")
        #expect(viewModel.selectedLayerFigmaComponentProperties == propertiesBeforeRejectedBlank)
        #expect(viewModel.undoStack.count == variantNoOpUndoCount)
        #expect(viewModel.redoStack.count == variantNoOpRedoCount)
        #expect(viewModel.document.history == variantNoOpHistory)

        viewModel.undo()
        #expect(viewModel.selectedLayerFigmaComponentProperties["Size"]?.value == "Large")
        #expect(viewModel.selectedLayerFigmaComponentProperties["Label"]?.value == "")
        #expect(viewModel.document.layers[1].textContent?.text == "")
        viewModel.undo()
        #expect(viewModel.selectedLayerFigmaComponentProperties["Label"]?.value == whitespaceOnly)
        #expect(viewModel.document.layers[1].textContent?.text == whitespaceOnly)
        viewModel.redo()
        #expect(viewModel.selectedLayerFigmaComponentProperties["Label"]?.value == "")
        #expect(viewModel.document.layers[1].textContent?.text == "")
        viewModel.redo()
        #expect(viewModel.selectedLayerFigmaComponentProperties["Size"]?.value == "Compact")
    }

    @Test func enumeratedComponentPropertyWritesValidateAndCanonicalizeWithoutMigratingOrphans() throws {
        let image = NSImage.transparent(size: CGSize(width: 80, height: 40))
        var document = ImageEditorDocument(sourceName: "figma-enum-validation.png", image: image)
        var layer = document.layers[0]
        layer.isLocked = false
        let sizeCandidates = [
            XomoFigmaComponentPreferredValue(key: "small-key", name: "Small"),
            XomoFigmaComponentPreferredValue(key: "roomy-key", name: "Roomy")
        ]
        layer.xomoFigmaComponentProperties = [
            "Size": XomoFigmaComponentProperty(
                type: "VARIANT",
                value: "small-key",
                preferredValues: sizeCandidates
            ),
            "Duplicate": XomoFigmaComponentProperty(
                type: "INSTANCE_SWAP",
                value: "Same",
                preferredValues: [
                    XomoFigmaComponentPreferredValue(key: "first-key", name: "Same"),
                    XomoFigmaComponentPreferredValue(key: "second-key", name: "Same")
                ]
            ),
            "Unique Swap": XomoFigmaComponentProperty(
                type: "INSTANCE_SWAP",
                value: "unique-key",
                preferredValues: [
                    XomoFigmaComponentPreferredValue(key: "unique-key", name: "Unique")
                ]
            ),
            "Duplicate Variant": XomoFigmaComponentProperty(
                type: "VARIANT",
                value: "legacy-variant",
                preferredValues: [
                    XomoFigmaComponentPreferredValue(key: "variant-first", name: "Duplicate"),
                    XomoFigmaComponentPreferredValue(key: "variant-second", name: "Duplicate")
                ]
            ),
            "Variant Namespace Collision": XomoFigmaComponentProperty(
                type: "VARIANT",
                value: "b",
                preferredValues: [
                    XomoFigmaComponentPreferredValue(key: "a", name: "b"),
                    XomoFigmaComponentPreferredValue(key: "b", name: "c")
                ]
            ),
            "Swap Namespace Collision": XomoFigmaComponentProperty(
                type: "INSTANCE_SWAP",
                value: "b",
                preferredValues: [
                    XomoFigmaComponentPreferredValue(key: "a", name: "b"),
                    XomoFigmaComponentPreferredValue(key: "b", name: "c")
                ]
            ),
            "Empty Candidate": XomoFigmaComponentProperty(
                type: "VARIANT",
                value: "Legacy",
                preferredValues: [
                    XomoFigmaComponentPreferredValue(key: "", name: "Available")
                ]
            ),
            "Duplicate Key": XomoFigmaComponentProperty(
                type: "VARIANT",
                value: "Legacy",
                preferredValues: [
                    XomoFigmaComponentPreferredValue(key: "same-key", name: "First"),
                    XomoFigmaComponentPreferredValue(key: "same-key", name: "Second")
                ]
            ),
            "Enabled": XomoFigmaComponentProperty(type: "BOOLEAN", value: "true"),
            "Legacy Boolean": XomoFigmaComponentProperty(type: "BOOLEAN", value: "TRUE"),
            "Free Variant": XomoFigmaComponentProperty(type: "VARIANT", value: "Legacy"),
            "Unknown": XomoFigmaComponentProperty(type: "FUTURE", value: "Preserved")
        ]
        layer.xomoFigmaComponentPropertyDefaults = layer.xomoFigmaComponentProperties
        document.layers = [layer]
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]
        let viewModel = ImageEditorViewModel(document: document) { _ in }

        let semanticNoOpProperties = viewModel.selectedLayerFigmaComponentProperties
        let semanticNoOpUndoCount = viewModel.undoStack.count
        let semanticNoOpHistory = viewModel.document.history
        #expect(
            viewModel.updateSelectedFigmaComponentProperty("Size", value: "Small")
                == .unchanged
        )
        #expect(viewModel.selectedLayerFigmaComponentProperties == semanticNoOpProperties)
        #expect(viewModel.undoStack.count == semanticNoOpUndoCount)
        #expect(viewModel.document.history == semanticNoOpHistory)

        #expect(
            viewModel.updateSelectedFigmaComponentProperty("Size", value: " roomy-key ")
                == .changed
        )
        #expect(viewModel.selectedLayerFigmaComponentProperties["Size"]?.value == "Roomy")
        let defaultsAfterChange = viewModel.selectedLayerFigmaComponentPropertyDefaults
        let uniqueNoOpUndoCount = viewModel.undoStack.count
        let uniqueNoOpHistory = viewModel.document.history
        #expect(
            viewModel.updateSelectedFigmaComponentProperty("Size", value: "roomy-key")
                == .unchanged
        )
        #expect(
            viewModel.updateSelectedFigmaComponentProperty("Unique Swap", value: "Unique")
                == .unchanged
        )
        #expect(viewModel.selectedLayerFigmaComponentProperties["Size"]?.value == "Roomy")
        #expect(viewModel.selectedLayerFigmaComponentProperties["Unique Swap"]?.value == "unique-key")
        #expect(viewModel.undoStack.count == uniqueNoOpUndoCount)
        #expect(viewModel.document.history == uniqueNoOpHistory)

        for invalidInput in ["Unknown", "roomy", "   "] {
            let propertiesBefore = viewModel.selectedLayerFigmaComponentProperties
            let undoCountBefore = viewModel.undoStack.count
            let redoCountBefore = viewModel.redoStack.count
            let historyBefore = viewModel.document.history
            #expect(
                viewModel.updateSelectedFigmaComponentProperty("Size", value: invalidInput)
                    == .invalid
            )
            #expect(viewModel.selectedLayerFigmaComponentProperties == propertiesBefore)
            #expect(viewModel.selectedLayerFigmaComponentPropertyDefaults == defaultsAfterChange)
            #expect(viewModel.undoStack.count == undoCountBefore)
            #expect(viewModel.redoStack.count == redoCountBefore)
            #expect(viewModel.document.history == historyBefore)
        }

        let orphanBefore = viewModel.selectedLayerFigmaComponentProperties["Duplicate"]
        #expect(
            viewModel.updateSelectedFigmaComponentProperty("Duplicate", value: "Same")
                == .invalid
        )
        #expect(viewModel.selectedLayerFigmaComponentProperties["Duplicate"] == orphanBefore)
        #expect(
            viewModel.updateSelectedFigmaComponentProperty("Duplicate", value: "second-key")
                == .changed
        )
        #expect(viewModel.selectedLayerFigmaComponentProperties["Duplicate"]?.value == "second-key")
        viewModel.undo()
        #expect(viewModel.selectedLayerFigmaComponentProperties["Duplicate"]?.value == "Same")
        viewModel.redo()
        #expect(viewModel.selectedLayerFigmaComponentProperties["Duplicate"]?.value == "second-key")
        for value in ["Duplicate", "variant-first"] {
            let propertyBefore = viewModel.selectedLayerFigmaComponentProperties["Duplicate Variant"]
            let undoCountBefore = viewModel.undoStack.count
            let historyBefore = viewModel.document.history
            #expect(
                viewModel.updateSelectedFigmaComponentProperty(
                    "Duplicate Variant",
                    value: value
                ) == .invalid
            )
            #expect(viewModel.selectedLayerFigmaComponentProperties["Duplicate Variant"] == propertyBefore)
            #expect(viewModel.undoStack.count == undoCountBefore)
            #expect(viewModel.document.history == historyBefore)
        }
        for key in ["Variant Namespace Collision", "Swap Namespace Collision"] {
            let propertiesBefore = viewModel.selectedLayerFigmaComponentProperties
            let defaultsBefore = viewModel.selectedLayerFigmaComponentPropertyDefaults
            let undoCountBefore = viewModel.undoStack.count
            let redoCountBefore = viewModel.redoStack.count
            let historyBefore = viewModel.document.history
            #expect(
                viewModel.updateSelectedFigmaComponentProperty(key, value: "a") == .invalid
            )
            #expect(viewModel.selectedLayerFigmaComponentProperties == propertiesBefore)
            #expect(viewModel.selectedLayerFigmaComponentPropertyDefaults == defaultsBefore)
            #expect(viewModel.undoStack.count == undoCountBefore)
            #expect(viewModel.redoStack.count == redoCountBefore)
            #expect(viewModel.document.history == historyBefore)
        }
        for (key, value) in [("Empty Candidate", "Available"), ("Duplicate Key", "same-key")] {
            let propertyBefore = viewModel.selectedLayerFigmaComponentProperties[key]
            let undoCountBefore = viewModel.undoStack.count
            let historyBefore = viewModel.document.history
            #expect(
                viewModel.updateSelectedFigmaComponentProperty(key, value: value) == .invalid
            )
            #expect(viewModel.selectedLayerFigmaComponentProperties[key] == propertyBefore)
            #expect(viewModel.undoStack.count == undoCountBefore)
            #expect(viewModel.document.history == historyBefore)
        }

        let invalidBooleanProperties = viewModel.selectedLayerFigmaComponentProperties
        let invalidBooleanUndoCount = viewModel.undoStack.count
        let invalidBooleanHistory = viewModel.document.history
        #expect(
            viewModel.updateSelectedFigmaComponentProperty("Enabled", value: " TRUE ")
                == .invalid
        )
        #expect(viewModel.selectedLayerFigmaComponentProperties == invalidBooleanProperties)
        #expect(viewModel.undoStack.count == invalidBooleanUndoCount)
        #expect(viewModel.document.history == invalidBooleanHistory)
        #expect(
            viewModel.updateSelectedFigmaComponentProperty("Enabled", value: " false ")
                == .changed
        )
        #expect(viewModel.selectedLayerFigmaComponentProperties["Enabled"]?.value == "false")
        #expect(
            viewModel.updateSelectedFigmaComponentProperty("Legacy Boolean", value: "false")
                == .changed
        )
        #expect(
            viewModel.selectedLayerFigmaComponentProperties["Legacy Boolean"]?.value == "false"
        )

        #expect(
            viewModel.updateSelectedFigmaComponentProperty("Free Variant", value: " Open ")
                == .changed
        )
        #expect(viewModel.selectedLayerFigmaComponentProperties["Free Variant"]?.value == "Open")
        let unknownBefore = viewModel.selectedLayerFigmaComponentProperties["Unknown"]
        #expect(
            viewModel.updateSelectedFigmaComponentProperty("Unknown", value: "Changed")
                == .invalid
        )
        #expect(viewModel.selectedLayerFigmaComponentProperties["Unknown"] == unknownBefore)
        #expect(
            viewModel.statusText
                == L10n.text("imageEditor.status.figmaComponentPropertyInvalidValue")
        )
        #expect(
            viewModel.updateSelectedFigmaComponentProperty("Missing", value: "Anything")
                == .notFound
        )
    }

    @Test func componentPropertyDiagnosisKeepsHealthyEditorsAndSurfacesImportedDataDamage() {
        let text = XomoFigmaComponentProperty(type: "TEXT", value: "  Buy now  ")
        #expect(text.diagnosis.editor == .text)
        #expect(text.diagnosis.writable)
        #expect(text.diagnosis.diagnostic == nil)
        #expect(
            text.resolvingWrite("")
                == .accepted(value: "", semanticallyUnchanged: false)
        )

        let boolean = XomoFigmaComponentProperty(type: "BOOLEAN", value: "true")
        #expect(boolean.diagnosis.editor == .boolean)
        #expect(boolean.diagnosis.writable)
        #expect(
            boolean.resolvingWrite(" false ")
                == .accepted(value: "false", semanticallyUnchanged: false)
        )
        let nonCanonicalBoolean = XomoFigmaComponentProperty(type: "BOOLEAN", value: "TRUE")
        #expect(nonCanonicalBoolean.diagnosis.editor == .readOnly)
        #expect(nonCanonicalBoolean.diagnosis.writable)
        #expect(nonCanonicalBoolean.diagnosis.diagnostic == .booleanValueNonCanonical)
        #expect(
            nonCanonicalBoolean.resolvingWrite("false")
                == .accepted(value: "false", semanticallyUnchanged: false)
        )

        let freeVariant = XomoFigmaComponentProperty(type: "VARIANT", value: "Legacy")
        #expect(freeVariant.diagnosis.editor == .text)
        #expect(freeVariant.diagnosis.writable)
        #expect(freeVariant.diagnosis.diagnostic == .preferredValuesMissing)
        #expect(
            freeVariant.resolvingWrite(" Open ")
                == .accepted(value: "Open", semanticallyUnchanged: false)
        )

        let preferredValues = [
            XomoFigmaComponentPreferredValue(key: "small-key", name: "Small"),
            XomoFigmaComponentPreferredValue(key: "large-key", name: "Large")
        ]
        let variantByName = XomoFigmaComponentProperty(
            type: "VARIANT",
            value: "Large",
            preferredValues: preferredValues
        )
        #expect(variantByName.diagnosis.editor == .picker)
        #expect(variantByName.diagnosis.selectionKey == "large-key")
        #expect(variantByName.diagnosis.diagnostic == nil)
        #expect(
            variantByName.resolvingWrite("small-key")
                == .accepted(value: "Small", semanticallyUnchanged: false)
        )
        let sameKeyAndName = XomoFigmaComponentProperty(
            type: "VARIANT",
            value: "same",
            preferredValues: [XomoFigmaComponentPreferredValue(key: "same", name: "same")]
        )
        #expect(sameKeyAndName.diagnosis.selectionKey == "same")
        #expect(sameKeyAndName.diagnosis.diagnostic == nil)

        let orphan = XomoFigmaComponentProperty(
            type: "VARIANT",
            value: "Legacy",
            preferredValues: preferredValues
        )
        #expect(orphan.diagnosis.editor == .picker)
        #expect(orphan.diagnosis.writable)
        #expect(orphan.diagnosis.selectionKey == nil)
        #expect(orphan.diagnosis.diagnostic == .currentValueOrphan)
        #expect(orphan.value == "Legacy")

        let duplicateSwapNames = XomoFigmaComponentProperty(
            type: "INSTANCE_SWAP",
            value: "Shared",
            preferredValues: [
                XomoFigmaComponentPreferredValue(key: "first-key", name: "Shared"),
                XomoFigmaComponentPreferredValue(key: "second-key", name: "Shared")
            ]
        )
        #expect(duplicateSwapNames.diagnosis.editor == .picker)
        #expect(duplicateSwapNames.diagnosis.writable)
        #expect(duplicateSwapNames.diagnosis.selectionKey == nil)
        #expect(duplicateSwapNames.diagnosis.diagnostic == .currentValueAmbiguous)
        #expect(
            duplicateSwapNames.resolvingWrite("second-key")
                == .accepted(value: "second-key", semanticallyUnchanged: false)
        )
        #expect(duplicateSwapNames.resolvingWrite("Shared") == .rejected)
        #expect(duplicateSwapNames.displayName(for: duplicateSwapNames.preferredValues[0]).contains("first-key"))

        let malformedProperties: [(XomoFigmaComponentProperty, XomoFigmaComponentPropertyDiagnosticCode)] = [
            (
                XomoFigmaComponentProperty(
                    type: "VARIANT",
                    value: "Legacy",
                    preferredValues: [XomoFigmaComponentPreferredValue(key: " ", name: "One")]
                ),
                .preferredValueKeyEmpty
            ),
            (
                XomoFigmaComponentProperty(
                    type: "VARIANT",
                    value: "Legacy",
                    preferredValues: [XomoFigmaComponentPreferredValue(key: "one", name: "\n")]
                ),
                .preferredValueNameEmpty
            ),
            (
                XomoFigmaComponentProperty(
                    type: "INSTANCE_SWAP",
                    value: "first",
                    preferredValues: [
                        XomoFigmaComponentPreferredValue(key: "same", name: "One"),
                        XomoFigmaComponentPreferredValue(key: "same", name: "Two")
                    ]
                ),
                .preferredValueKeyDuplicate
            ),
            (
                XomoFigmaComponentProperty(
                    type: "VARIANT",
                    value: "first",
                    preferredValues: [
                        XomoFigmaComponentPreferredValue(key: "one", name: "Same"),
                        XomoFigmaComponentPreferredValue(key: "two", name: "Same")
                    ]
                ),
                .variantNameDuplicate
            ),
            (
                XomoFigmaComponentProperty(
                    type: "INSTANCE_SWAP",
                    value: "b",
                    preferredValues: [
                        XomoFigmaComponentPreferredValue(key: "a", name: "b"),
                        XomoFigmaComponentPreferredValue(key: "b", name: "c")
                    ]
                ),
                .preferredValueNamespaceCollision
            )
        ]
        for (property, issue) in malformedProperties {
            #expect(property.diagnosis.editor == .readOnly)
            #expect(!property.diagnosis.writable)
            #expect(property.diagnosis.diagnostic == issue)
            #expect(property.diagnosis.selectionKey == nil)
            #expect(property.resolvingWrite("one") == .rejected)
        }

        let unknown = XomoFigmaComponentProperty(type: "FUTURE", value: "Preserved")
        #expect(unknown.diagnosis.editor == .readOnly)
        #expect(!unknown.diagnosis.writable)
        #expect(unknown.diagnosis.diagnostic == .unknownType)
        #expect(unknown.value == "Preserved")
    }

    @Test func componentPropertyInspectorConsumesSharedDiagnosisAndPreservesUnselectedRawValues() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("let diagnosis = property.diagnosis"))
        #expect(source.contains("switch diagnosis.editor"))
        #expect(source.contains("Binding<String?>"))
        #expect(source.contains("get: { diagnosis.selectionKey }"))
        #expect(source.contains("Text(property.value).tag(Optional<String>.none)"))
        #expect(source.contains("property.displayName(for: preferredValue)"))
        #expect(source.contains("image-editor-figma-property-read-only-\\(key)"))
        #expect(source.contains("image-editor-figma-property-diagnostic-\\(key)"))
        #expect(source.contains("presentation: property.typePresentation"))
        #expect(source.contains("private func figmaComponentPropertyTypeBadge("))
        #expect(source.contains("private func figmaComponentPropertySourceBadge("))
        #expect(source.contains("image-editor-figma-property-source-\\(key)"))
        #expect(source.contains("presentation: viewModel.selectedLayerFigmaComponentPropertySourcePresentation("))
        #expect(source.contains("image-editor-figma-property-type-\\(key)"))
        #expect(source.contains("imageEditor.properties.figmaComponentPropertyType.rawHelp"))
        #expect(source.contains("presentation.rawType"))
        #expect(!source.contains("Text(property.type)"))
        #expect(!source.contains("} else if !property.preferredValues.isEmpty {"))

        let badgeStart = try #require(
            source.range(of: "private func figmaComponentPropertyTypeBadge(")
        )
        let badgeEnd = try #require(
            source.range(of: "\n    private func figmaImageFillRow", range: badgeStart.upperBound..<source.endIndex)
        )
        let badgeSource = source[badgeStart.lowerBound..<badgeEnd.lowerBound]
        #expect(badgeSource.contains("Capsule()"))
        #expect(badgeSource.contains(".focusable(false)"))
        #expect(!badgeSource.contains("Button"))
        #expect(!badgeSource.contains("onTapGesture"))
        #expect(!badgeSource.contains("Binding"))
        #expect(!badgeSource.contains("viewModel"))
        #expect(!badgeSource.contains("updateSelected"))
        #expect(!badgeSource.contains("resetSelected"))
        #expect(!badgeSource.lowercased().contains("search"))

        let sourceBadgeStart = try #require(
            source.range(of: "private func figmaComponentPropertySourceBadge(")
        )
        let sourceBadgeEnd = try #require(
            source.range(of: "\n    private func figmaImageFillRow", range: sourceBadgeStart.upperBound..<source.endIndex)
        )
        let sourceBadgeSource = source[sourceBadgeStart.lowerBound..<sourceBadgeEnd.lowerBound]
        #expect(sourceBadgeSource.contains("Capsule()"))
        #expect(sourceBadgeSource.contains(".focusable(false)"))
        #expect(!sourceBadgeSource.contains("Button"))
        #expect(!sourceBadgeSource.contains("onTapGesture"))
        #expect(!sourceBadgeSource.contains("Binding"))
        #expect(!sourceBadgeSource.contains("viewModel"))
        #expect(!sourceBadgeSource.contains("updateSelected"))
        #expect(!sourceBadgeSource.contains("resetSelected"))
        #expect(!sourceBadgeSource.lowercased().contains("search"))
    }

    @Test func componentPropertyTypePresentationLocalizesExactKnownTypesAndPreservesRawProtocolData() throws {
        let cases: [(
            property: XomoFigmaComponentProperty,
            presentation: XomoFigmaComponentPropertyTypePresentation,
            diagnosis: XomoFigmaComponentPropertyDiagnosis
        )] = [
            (
                XomoFigmaComponentProperty(type: "TEXT", value: "Neutral"),
                .localized(
                    key: "imageEditor.properties.figmaComponentPropertyType.text",
                    rawType: "TEXT"
                ),
                XomoFigmaComponentPropertyDiagnosis(
                    editor: .text,
                    writable: true,
                    diagnostic: nil,
                    selectionKey: nil
                )
            ),
            (
                XomoFigmaComponentProperty(type: "BOOLEAN", value: "true"),
                .localized(
                    key: "imageEditor.properties.figmaComponentPropertyType.boolean",
                    rawType: "BOOLEAN"
                ),
                XomoFigmaComponentPropertyDiagnosis(
                    editor: .boolean,
                    writable: true,
                    diagnostic: nil,
                    selectionKey: nil
                )
            ),
            (
                XomoFigmaComponentProperty(type: "VARIANT", value: "Neutral"),
                .localized(
                    key: "imageEditor.properties.figmaComponentPropertyType.variant",
                    rawType: "VARIANT"
                ),
                XomoFigmaComponentPropertyDiagnosis(
                    editor: .text,
                    writable: true,
                    diagnostic: .preferredValuesMissing,
                    selectionKey: nil
                )
            ),
            (
                XomoFigmaComponentProperty(type: "INSTANCE_SWAP", value: "Neutral"),
                .localized(
                    key: "imageEditor.properties.figmaComponentPropertyType.instanceSwap",
                    rawType: "INSTANCE_SWAP"
                ),
                XomoFigmaComponentPropertyDiagnosis(
                    editor: .text,
                    writable: true,
                    diagnostic: .preferredValuesMissing,
                    selectionKey: nil
                )
            ),
            (
                XomoFigmaComponentProperty(type: "text", value: "Neutral"),
                .raw("text"),
                XomoFigmaComponentPropertyDiagnosis(
                    editor: .readOnly,
                    writable: false,
                    diagnostic: .unknownType,
                    selectionKey: nil
                )
            ),
            (
                XomoFigmaComponentProperty(type: " Text ", value: "Neutral"),
                .raw(" Text "),
                XomoFigmaComponentPropertyDiagnosis(
                    editor: .readOnly,
                    writable: false,
                    diagnostic: .unknownType,
                    selectionKey: nil
                )
            ),
            (
                XomoFigmaComponentProperty(type: "FUTURE_WIDGET", value: "Neutral"),
                .raw("FUTURE_WIDGET"),
                XomoFigmaComponentPropertyDiagnosis(
                    editor: .readOnly,
                    writable: false,
                    diagnostic: .unknownType,
                    selectionKey: nil
                )
            ),
            (
                XomoFigmaComponentProperty(type: "", value: "Neutral"),
                .localized(
                    key: "imageEditor.properties.figmaComponentPropertyType.unknown",
                    rawType: ""
                ),
                XomoFigmaComponentPropertyDiagnosis(
                    editor: .readOnly,
                    writable: false,
                    diagnostic: .unknownType,
                    selectionKey: nil
                )
            ),
            (
                XomoFigmaComponentProperty(type: " \t\n ", value: "Neutral"),
                .localized(
                    key: "imageEditor.properties.figmaComponentPropertyType.unknown",
                    rawType: " \t\n "
                ),
                XomoFigmaComponentPropertyDiagnosis(
                    editor: .readOnly,
                    writable: false,
                    diagnostic: .unknownType,
                    selectionKey: nil
                )
            )
        ]

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for testCase in cases {
            #expect(testCase.property.typePresentation == testCase.presentation)
            #expect(testCase.property.typePresentation.rawType == testCase.property.type)
            #expect(testCase.property.diagnosis == testCase.diagnosis)
            let restored = try decoder.decode(
                XomoFigmaComponentProperty.self,
                from: encoder.encode(testCase.property)
            )
            #expect(restored == testCase.property)
            #expect(restored.typePresentation == testCase.presentation)
            #expect(restored.diagnosis == testCase.diagnosis)
        }

        let image = NSImage.transparent(size: CGSize(width: 20, height: 20))
        var document = ImageEditorDocument(sourceName: "figma-type-presentation.png", image: image)
        var layer = document.layers[0]
        layer.xomoFigmaComponentProperties = Dictionary(
            uniqueKeysWithValues: cases.enumerated().map { index, testCase in
                ("Property \(index)", testCase.property)
            }
        )
        layer.xomoFigmaComponentPropertyDefaults = layer.xomoFigmaComponentProperties
        document.layers = [layer]
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]
        let viewModel = ImageEditorViewModel(document: document) { _ in }
        let propertiesBefore = viewModel.selectedLayerFigmaComponentProperties
        let historyBefore = viewModel.document.history

        for excludedPresentationQuery in [
            "TEXT",
            "FUTURE_WIDGET",
            "unknown_type",
            "imageEditor.properties.figmaComponentPropertyType.text",
            "Toggle",
            "开关",
            "切り替え"
        ] {
            #expect(
                viewModel.selectedLayerFigmaComponentPropertyKeys(
                    onlyOverrides: false,
                    searchQuery: excludedPresentationQuery
                ).isEmpty
            )
        }
        #expect(viewModel.selectedLayerFigmaComponentProperties == propertiesBefore)
        #expect(viewModel.document.history == historyBefore)
        #expect(viewModel.undoStack.isEmpty)
        #expect(viewModel.redoStack.isEmpty)

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let localizationExpectations: [(
            path: String,
            entries: [(key: String, value: String)]
        )] = [
            (
                "veilpic/en.lproj/Localizable.strings",
                [
                    ("imageEditor.properties.figmaComponentPropertyType.text", "Text"),
                    ("imageEditor.properties.figmaComponentPropertyType.boolean", "Toggle"),
                    ("imageEditor.properties.figmaComponentPropertyType.variant", "Variant"),
                    ("imageEditor.properties.figmaComponentPropertyType.instanceSwap", "Instance swap"),
                    ("imageEditor.properties.figmaComponentPropertyType.unknown", "Unknown type"),
                    ("imageEditor.properties.figmaComponentPropertyType.rawHelp", "Figma raw type: %@")
                ]
            ),
            (
                "veilpic/zh-Hans.lproj/Localizable.strings",
                [
                    ("imageEditor.properties.figmaComponentPropertyType.text", "文本"),
                    ("imageEditor.properties.figmaComponentPropertyType.boolean", "开关"),
                    ("imageEditor.properties.figmaComponentPropertyType.variant", "变体"),
                    ("imageEditor.properties.figmaComponentPropertyType.instanceSwap", "实例交换"),
                    ("imageEditor.properties.figmaComponentPropertyType.unknown", "未知类型"),
                    ("imageEditor.properties.figmaComponentPropertyType.rawHelp", "Figma 原始类型：%@")
                ]
            ),
            (
                "veilpic/ja.lproj/Localizable.strings",
                [
                    ("imageEditor.properties.figmaComponentPropertyType.text", "テキスト"),
                    ("imageEditor.properties.figmaComponentPropertyType.boolean", "切り替え"),
                    ("imageEditor.properties.figmaComponentPropertyType.variant", "バリアント"),
                    ("imageEditor.properties.figmaComponentPropertyType.instanceSwap", "インスタンス入れ替え"),
                    ("imageEditor.properties.figmaComponentPropertyType.unknown", "不明な型"),
                    ("imageEditor.properties.figmaComponentPropertyType.rawHelp", "Figma 元の型：%@")
                ]
            )
        ]
        for expectation in localizationExpectations {
            let localizationSource = try String(
                contentsOf: repositoryRoot.appendingPathComponent(expectation.path),
                encoding: .utf8
            )
            for entry in expectation.entries {
                #expect(localizationSource.contains("\"\(entry.key)\" = \"\(entry.value)\";"))
            }
        }
    }

    @Test func componentPropertySourcePresentationSeparatesDefaultsOverridesAndLocalOnlyWithoutSideEffects() throws {
        let image = NSImage.transparent(size: CGSize(width: 20, height: 20))
        var document = ImageEditorDocument(sourceName: "figma-source-presentation.png", image: image)
        var layer = document.layers[0]
        let equal = XomoFigmaComponentProperty(type: "TEXT", value: "Imported")
        let valueOnly = XomoFigmaComponentProperty(type: "TEXT", value: "Changed")
        let metadataOnly = XomoFigmaComponentProperty(
            type: "VARIANT",
            value: "Same",
            preferredValues: [XomoFigmaComponentPreferredValue(key: "same", name: "Same")]
        )
        let valueAndMetadata = XomoFigmaComponentProperty(
            type: "BOOLEAN",
            value: "false",
            preferredValues: [XomoFigmaComponentPreferredValue(key: "false", name: "False")]
        )
        let equalDefault = XomoFigmaComponentProperty(type: "TEXT", value: "Imported")
        let valueDefault = XomoFigmaComponentProperty(type: "TEXT", value: "Original")
        let metadataDefault = XomoFigmaComponentProperty(type: "TEXT", value: "Same")
        let valueAndMetadataDefault = XomoFigmaComponentProperty(type: "BOOLEAN", value: "true")
        let custom = XomoFigmaComponentProperty(type: "TEXT", value: "Local")

        layer.xomoFigmaComponentProperties = [
            "Equal": equal,
            "Value only": valueOnly,
            "Metadata only": metadataOnly,
            "Value and metadata": valueAndMetadata,
            "Custom": custom
        ]
        layer.xomoFigmaComponentPropertyDefaults = [
            "Equal": equalDefault,
            "Value only": valueDefault,
            "Metadata only": metadataDefault,
            "Value and metadata": valueAndMetadataDefault
        ]
        document.layers = [layer]
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]
        let viewModel = ImageEditorViewModel(document: document) { _ in }

        let expected: [(String, XomoFigmaComponentPropertySourcePresentation)] = [
            ("Equal", .importedDefault),
            ("Value only", .overridden),
            ("Metadata only", .overridden),
            ("Value and metadata", .overridden),
            ("Custom", .localOnly)
        ]
        for (key, presentation) in expected {
            let property = try #require(viewModel.selectedLayerFigmaComponentProperties[key])
            #expect(
                viewModel.selectedLayerFigmaComponentPropertySourcePresentation(key, property: property)
                    == presentation
            )
        }
        #expect(viewModel.selectedLayerFigmaComponentPropertyOverrideKeys == [
            "Metadata only", "Value and metadata", "Value only"
        ])
        #expect(viewModel.selectedLayerFigmaComponentPropertyOverrideCount == 3)

        let propertiesBefore = viewModel.selectedLayerFigmaComponentProperties
        let defaultsBefore = viewModel.selectedLayerFigmaComponentPropertyDefaults
        let historyBefore = viewModel.document.history
        let statusBefore = viewModel.statusText
        let selectionBefore = viewModel.document.selectedLayerIDs
        let diagnosticsBefore = viewModel.selectedLayerFigmaComponentPropertyDiagnosticCount
        let blockedBefore = viewModel.selectedLayerFigmaComponentPropertyBlockedCount
        let undoBefore = viewModel.undoStack
        let redoBefore = viewModel.redoStack
        for query in ["Imported default", "Overridden", "Local only", "导入默认值", "已覆盖", "仅本地", "インポートされたデフォルト", "上書き済み", "ローカルのみ"] {
            #expect(
                viewModel.selectedLayerFigmaComponentPropertyKeys(
                    onlyOverrides: false,
                    searchQuery: query
                ).isEmpty
            )
        }

        let encoded = try JSONEncoder().encode(propertiesBefore)
        let restored = try JSONDecoder().decode(
            [String: XomoFigmaComponentProperty].self,
            from: encoded
        )
        #expect(restored == propertiesBefore)
        #expect(viewModel.selectedLayerFigmaComponentProperties == propertiesBefore)
        #expect(viewModel.selectedLayerFigmaComponentPropertyDefaults == defaultsBefore)
        #expect(viewModel.document.history == historyBefore)
        #expect(viewModel.statusText == statusBefore)
        #expect(viewModel.document.selectedLayerIDs == selectionBefore)
        #expect(viewModel.selectedLayerFigmaComponentPropertyDiagnosticCount == diagnosticsBefore)
        #expect(viewModel.selectedLayerFigmaComponentPropertyBlockedCount == blockedBefore)
        #expect(viewModel.undoStack.count == undoBefore.count)
        #expect(viewModel.redoStack.count == redoBefore.count)

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let localizationExpectations: [(String, [(String, String)])] = [
            (
                "veilpic/en.lproj/Localizable.strings",
                [
                    ("imageEditor.properties.figmaComponentPropertySource.importedDefault", "Imported default"),
                    ("imageEditor.properties.figmaComponentPropertySource.overridden", "Overridden"),
                    ("imageEditor.properties.figmaComponentPropertySource.localOnly", "Local only")
                ]
            ),
            (
                "veilpic/zh-Hans.lproj/Localizable.strings",
                [
                    ("imageEditor.properties.figmaComponentPropertySource.importedDefault", "导入默认值"),
                    ("imageEditor.properties.figmaComponentPropertySource.overridden", "已覆盖"),
                    ("imageEditor.properties.figmaComponentPropertySource.localOnly", "仅本地")
                ]
            ),
            (
                "veilpic/ja.lproj/Localizable.strings",
                [
                    ("imageEditor.properties.figmaComponentPropertySource.importedDefault", "インポートされたデフォルト"),
                    ("imageEditor.properties.figmaComponentPropertySource.overridden", "上書き済み"),
                    ("imageEditor.properties.figmaComponentPropertySource.localOnly", "ローカルのみ")
                ]
            )
        ]
        for (path, entries) in localizationExpectations {
            let source = try String(contentsOf: repositoryRoot.appendingPathComponent(path), encoding: .utf8)
            for (key, value) in entries {
                #expect(source.contains("\"\(key)\" = \"\(value)\";"))
            }
        }
    }

    @Test func resettingSingleComponentPropertyRestoresImportedObjectAtomically() throws {
        let image = NSImage.transparent(size: CGSize(width: 20, height: 20))
        var document = ImageEditorDocument(sourceName: "figma-single-reset-metadata.png", image: image)
        var layer = document.layers[0]
        layer.isLocked = false
        let imported = XomoFigmaComponentProperty(
            type: "VARIANT",
            value: "Compact",
            preferredValues: [
                XomoFigmaComponentPreferredValue(key: "compact", name: "Compact")
            ]
        )
        layer.xomoFigmaComponentProperties = [
            "Size": XomoFigmaComponentProperty(
                type: "TEXT",
                value: "Compact",
                preferredValues: [
                    XomoFigmaComponentPreferredValue(key: "local", name: "Local compact")
                ]
            ),
            "Tone": XomoFigmaComponentProperty(type: "VARIANT", value: "Strong"),
            "Custom": XomoFigmaComponentProperty(type: "TEXT", value: "Local only")
        ]
        layer.xomoFigmaComponentPropertyDefaults = [
            "Size": imported,
            "Tone": XomoFigmaComponentProperty(type: "VARIANT", value: "Quiet")
        ]
        document.layers = [layer]
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]

        let viewModel = ImageEditorViewModel(document: document) { _ in }
        let propertiesBefore = viewModel.selectedLayerFigmaComponentProperties
        let undoCountBefore = viewModel.undoStack.count
        let historyCountBefore = viewModel.document.history.count

        viewModel.resetSelectedFigmaComponentProperty("Size")

        #expect(viewModel.selectedLayerFigmaComponentProperties["Size"] == imported)
        #expect(viewModel.selectedLayerFigmaComponentProperties["Tone"] == propertiesBefore["Tone"])
        #expect(viewModel.selectedLayerFigmaComponentProperties["Custom"] == propertiesBefore["Custom"])
        #expect(viewModel.selectedLayerFigmaComponentPropertyOverrideKeys == ["Tone"])
        #expect(viewModel.undoStack.count == undoCountBefore + 1)
        #expect(viewModel.document.history.count == historyCountBefore + 1)
        #expect(
            viewModel.document.history.last?.title
                == L10n.format("imageEditor.history.figmaComponentPropertyChanged", "Size")
        )

        viewModel.undo()
        #expect(viewModel.selectedLayerFigmaComponentProperties == propertiesBefore)
        viewModel.redo()
        #expect(viewModel.selectedLayerFigmaComponentProperties["Size"] == imported)

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restored = try project.restoredDocument()
        #expect(restored.selectedLayer?.xomoFigmaComponentProperties["Size"] == imported)
        #expect(restored.selectedLayer?.xomoFigmaComponentProperties["Tone"] == propertiesBefore["Tone"])
        #expect(restored.selectedLayer?.xomoFigmaComponentProperties["Custom"] == propertiesBefore["Custom"])

        let statusBeforeNoOp = viewModel.statusText
        let historyBeforeNoOp = viewModel.document.history
        let undoCountBeforeNoOp = viewModel.undoStack.count
        let redoCountBeforeNoOp = viewModel.redoStack.count
        viewModel.resetSelectedFigmaComponentProperty("Size")
        viewModel.resetSelectedFigmaComponentProperty("Missing Default")
        #expect(viewModel.statusText == statusBeforeNoOp)
        #expect(viewModel.document.history == historyBeforeNoOp)
        #expect(viewModel.undoStack.count == undoCountBeforeNoOp)
        #expect(viewModel.redoStack.count == redoCountBeforeNoOp)
    }

    @Test func resettingSingleTextPropertyRestoresMetadataAndOnlyEditableMatchingDescendants() throws {
        let image = NSImage.transparent(size: CGSize(width: 320, height: 180))
        var document = ImageEditorDocument(sourceName: "figma-single-reset-text.png", image: image)
        var component = ImageEditorLayer.group(name: "Button", size: CGSize(width: 140, height: 44))
        let imported = XomoFigmaComponentProperty(
            type: "TEXT",
            value: "Continue",
            preferredValues: [
                XomoFigmaComponentPreferredValue(key: "continue", name: "Continue")
            ]
        )
        component.xomoFigmaComponentProperties = [
            "Label": XomoFigmaComponentProperty(
                type: "TEXT",
                value: "Buy now",
                preferredValues: [
                    XomoFigmaComponentPreferredValue(key: "buy", name: "Buy now")
                ]
            )
        ]
        component.xomoFigmaComponentPropertyDefaults = ["Label": imported]
        var editableLabel = ImageEditorLayer.text(
            name: "Buy now",
            origin: CGPoint(x: 12, y: 12),
            content: ImageEditorTextContent(
                text: "Buy now",
                color: .white,
                fontSize: 14,
                point: CGPoint(
                    x: ImageEditorTextContent.drawingPadding,
                    y: ImageEditorTextContent.drawingPadding
                )
            )
        )
        editableLabel.groupID = component.id
        var pixelsLockedLabel = editableLabel
        pixelsLockedLabel.id = UUID()
        pixelsLockedLabel.name = "Locked Buy now"
        pixelsLockedLabel.groupID = component.id
        pixelsLockedLabel.locksPixels = true
        document.layers = [component, editableLabel, pixelsLockedLabel]
        document.selectedLayerID = component.id
        document.selectedLayerIDs = [component.id]

        let viewModel = ImageEditorViewModel(document: document) { _ in }
        let undoCountBefore = viewModel.undoStack.count
        viewModel.resetSelectedFigmaComponentProperty("Label")

        #expect(viewModel.selectedLayerFigmaComponentProperties["Label"] == imported)
        #expect(viewModel.document.layers[1].textContent?.text == "Continue")
        #expect(viewModel.document.layers[2].textContent?.text == "Buy now")
        #expect(viewModel.undoStack.count == undoCountBefore + 1)

        viewModel.undo()
        #expect(viewModel.selectedLayerFigmaComponentProperties["Label"]?.value == "Buy now")
        #expect(viewModel.document.layers[1].textContent?.text == "Buy now")
        #expect(viewModel.document.layers[2].textContent?.text == "Buy now")
        viewModel.redo()
        #expect(viewModel.selectedLayerFigmaComponentProperties["Label"] == imported)
        #expect(viewModel.document.layers[1].textContent?.text == "Continue")
        #expect(viewModel.document.layers[2].textContent?.text == "Buy now")
    }

    @Test func resettingSingleTextPropertyToVariantLeavesDescendantLayerUntouched() throws {
        let image = NSImage.transparent(size: CGSize(width: 180, height: 80))
        var document = ImageEditorDocument(sourceName: "figma-single-reset-type.png", image: image)
        var component = ImageEditorLayer.group(name: "Button", size: image.size)
        let current = XomoFigmaComponentProperty(
            type: "TEXT",
            value: "Buy now",
            preferredValues: [XomoFigmaComponentPreferredValue(key: "buy", name: "Buy now")]
        )
        let imported = XomoFigmaComponentProperty(
            type: "VARIANT",
            value: "Primary",
            preferredValues: [XomoFigmaComponentPreferredValue(key: "primary", name: "Primary")]
        )
        component.xomoFigmaComponentProperties = ["Label": current]
        component.xomoFigmaComponentPropertyDefaults = ["Label": imported]
        var label = ImageEditorLayer.text(
            name: "Buy now",
            origin: CGPoint(x: 12, y: 12),
            content: ImageEditorTextContent(
                text: "Buy now",
                color: .white,
                fontSize: 14,
                point: CGPoint(
                    x: ImageEditorTextContent.drawingPadding,
                    y: ImageEditorTextContent.drawingPadding
                )
            )
        )
        label.groupID = component.id
        document.layers = [component, label]
        document.selectedLayerID = component.id
        document.selectedLayerIDs = [component.id]
        let viewModel = ImageEditorViewModel(document: document) { _ in }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let labelBefore = try encoder.encode(ImageEditorProjectLayer(layer: label))
        let undoCountBefore = viewModel.undoStack.count
        let historyCountBefore = viewModel.document.history.count

        viewModel.resetSelectedFigmaComponentProperty("Label")

        #expect(viewModel.selectedLayerFigmaComponentProperties["Label"] == imported)
        #expect(try encoder.encode(ImageEditorProjectLayer(layer: viewModel.document.layers[1])) == labelBefore)
        #expect(viewModel.undoStack.count == undoCountBefore + 1)
        #expect(viewModel.document.history.count == historyCountBefore + 1)

        viewModel.undo()
        #expect(viewModel.selectedLayerFigmaComponentProperties["Label"] == current)
        #expect(try encoder.encode(ImageEditorProjectLayer(layer: viewModel.document.layers[1])) == labelBefore)
        viewModel.redo()
        #expect(viewModel.selectedLayerFigmaComponentProperties["Label"] == imported)
        #expect(try encoder.encode(ImageEditorProjectLayer(layer: viewModel.document.layers[1])) == labelBefore)
    }

    @Test func resettingAllComponentPropertiesUsesTypeSafeTextPropagationMatrix() throws {
        let image = NSImage.transparent(size: CGSize(width: 260, height: 160))
        var document = ImageEditorDocument(sourceName: "figma-reset-type-matrix.png", image: image)
        var component = ImageEditorLayer.group(name: "Card", size: image.size)
        let textDefault = XomoFigmaComponentProperty(type: "TEXT", value: "Imported text")
        let variantDefault = XomoFigmaComponentProperty(type: "VARIANT", value: "Primary")
        let fromVariantDefault = XomoFigmaComponentProperty(type: "TEXT", value: "Imported variant label")
        let metadataDefault = XomoFigmaComponentProperty(
            type: "TEXT",
            value: "Same text",
            preferredValues: [XomoFigmaComponentPreferredValue(key: "imported", name: "Imported")]
        )
        let custom = XomoFigmaComponentProperty(type: "TEXT", value: "Custom stays")
        component.xomoFigmaComponentProperties = [
            "A Text to Text": XomoFigmaComponentProperty(type: "TEXT", value: "Local text"),
            "B Text to Variant": XomoFigmaComponentProperty(type: "TEXT", value: "Local variant label"),
            "C Variant to Text": XomoFigmaComponentProperty(type: "VARIANT", value: "Local variant"),
            "D Same Text Metadata": XomoFigmaComponentProperty(
                type: "TEXT",
                value: "Same text",
                preferredValues: [XomoFigmaComponentPreferredValue(key: "local", name: "Local")]
            ),
            "Custom": custom
        ]
        component.xomoFigmaComponentPropertyDefaults = [
            "A Text to Text": textDefault,
            "B Text to Variant": variantDefault,
            "C Variant to Text": fromVariantDefault,
            "D Same Text Metadata": metadataDefault
        ]

        func textLayer(_ text: String, y: CGFloat, locked: Bool = false) -> ImageEditorLayer {
            var layer = ImageEditorLayer.text(
                name: text,
                origin: CGPoint(x: 12, y: y),
                content: ImageEditorTextContent(
                    text: text,
                    color: .white,
                    fontSize: 14,
                    point: CGPoint(
                        x: ImageEditorTextContent.drawingPadding,
                        y: ImageEditorTextContent.drawingPadding
                    )
                )
            )
            layer.groupID = component.id
            layer.locksPixels = locked
            return layer
        }

        let editableText = textLayer("Local text", y: 8)
        let lockedText = textLayer("Local text", y: 36, locked: true)
        let textToVariant = textLayer("Local variant label", y: 64)
        let variantToText = textLayer("Local variant", y: 92)
        let metadataOnlyText = textLayer("Same text", y: 120)
        document.layers = [
            component,
            editableText,
            lockedText,
            textToVariant,
            variantToText,
            metadataOnlyText
        ]
        document.selectedLayerID = component.id
        document.selectedLayerIDs = [component.id]
        let viewModel = ImageEditorViewModel(document: document) { _ in }
        let propertiesBefore = viewModel.selectedLayerFigmaComponentProperties
        let defaultsBefore = viewModel.selectedLayerFigmaComponentPropertyDefaults
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let descendantSignaturesBefore = try viewModel.document.layers.dropFirst().map {
            try encoder.encode(ImageEditorProjectLayer(layer: $0))
        }
        let undoCountBefore = viewModel.undoStack.count
        let historyCountBefore = viewModel.document.history.count

        viewModel.resetAllSelectedFigmaComponentPropertyOverrides()

        #expect(viewModel.selectedLayerFigmaComponentProperties["A Text to Text"] == textDefault)
        #expect(viewModel.selectedLayerFigmaComponentProperties["B Text to Variant"] == variantDefault)
        #expect(viewModel.selectedLayerFigmaComponentProperties["C Variant to Text"] == fromVariantDefault)
        #expect(viewModel.selectedLayerFigmaComponentProperties["D Same Text Metadata"] == metadataDefault)
        #expect(viewModel.selectedLayerFigmaComponentProperties["Custom"] == custom)
        #expect(viewModel.selectedLayerFigmaComponentPropertyDefaults == defaultsBefore)
        #expect(viewModel.document.layers[1].textContent?.text == "Imported text")
        for index in 2..<viewModel.document.layers.count {
            #expect(
                try encoder.encode(ImageEditorProjectLayer(layer: viewModel.document.layers[index]))
                    == descendantSignaturesBefore[index - 1]
            )
        }
        #expect(viewModel.undoStack.count == undoCountBefore + 1)
        #expect(viewModel.document.history.count == historyCountBefore + 1)
        let descendantSignaturesAfter = try viewModel.document.layers.dropFirst().map {
            try encoder.encode(ImageEditorProjectLayer(layer: $0))
        }

        viewModel.undo()
        #expect(viewModel.selectedLayerFigmaComponentProperties == propertiesBefore)
        #expect(viewModel.selectedLayerFigmaComponentPropertyDefaults == defaultsBefore)
        for index in 1..<viewModel.document.layers.count {
            #expect(
                try encoder.encode(ImageEditorProjectLayer(layer: viewModel.document.layers[index]))
                    == descendantSignaturesBefore[index - 1]
            )
        }
        viewModel.redo()
        #expect(viewModel.selectedLayerFigmaComponentProperties["A Text to Text"] == textDefault)
        #expect(viewModel.selectedLayerFigmaComponentProperties["B Text to Variant"] == variantDefault)
        #expect(viewModel.selectedLayerFigmaComponentProperties["C Variant to Text"] == fromVariantDefault)
        #expect(viewModel.selectedLayerFigmaComponentProperties["D Same Text Metadata"] == metadataDefault)
        #expect(viewModel.selectedLayerFigmaComponentProperties["Custom"] == custom)
        for index in 1..<viewModel.document.layers.count {
            #expect(
                try encoder.encode(ImageEditorProjectLayer(layer: viewModel.document.layers[index]))
                    == descendantSignaturesAfter[index - 1]
            )
        }

        let noOpProperties = viewModel.selectedLayerFigmaComponentProperties
        let noOpDefaults = viewModel.selectedLayerFigmaComponentPropertyDefaults
        let noOpDescendantSignatures = try viewModel.document.layers.dropFirst().map {
            try encoder.encode(ImageEditorProjectLayer(layer: $0))
        }
        let noOpUndoCount = viewModel.undoStack.count
        let noOpRedoCount = viewModel.redoStack.count
        let noOpHistory = viewModel.document.history
        viewModel.resetAllSelectedFigmaComponentPropertyOverrides()
        #expect(viewModel.selectedLayerFigmaComponentProperties == noOpProperties)
        #expect(viewModel.selectedLayerFigmaComponentPropertyDefaults == noOpDefaults)
        #expect(try viewModel.document.layers.dropFirst().map {
            try encoder.encode(ImageEditorProjectLayer(layer: $0))
        } == noOpDescendantSignatures)
        #expect(viewModel.undoStack.count == noOpUndoCount)
        #expect(viewModel.redoStack.count == noOpRedoCount)
        #expect(viewModel.document.history == noOpHistory)
    }

    @Test func componentPropertyEditingRejectsOwnAndAncestorContentLocksWithoutSideEffects() throws {
        enum LockCase: CaseIterable {
            case ownFull
            case ownPixels
            case ancestorFull
            case ancestorPixels
        }

        for lockCase in LockCase.allCases {
            let image = NSImage.transparent(size: CGSize(width: 320, height: 180))
            var document = ImageEditorDocument(sourceName: "locked-figma-component.png", image: image)
            var ancestor = ImageEditorLayer.group(name: "Screen", size: image.size)
            var component = ImageEditorLayer.group(name: "Button", size: CGSize(width: 140, height: 44))
            component.groupID = ancestor.id
            component.xomoFigmaComponentProperties = [
                "Label": XomoFigmaComponentProperty(type: "TEXT", value: "Continue"),
                "Enabled": XomoFigmaComponentProperty(type: "BOOLEAN", value: "true"),
                "Size": XomoFigmaComponentProperty(type: "VARIANT", value: "Large")
            ]
            component.xomoFigmaComponentPropertyDefaults = [
                "Label": XomoFigmaComponentProperty(type: "TEXT", value: "Default"),
                "Enabled": XomoFigmaComponentProperty(type: "BOOLEAN", value: "false"),
                "Size": XomoFigmaComponentProperty(type: "VARIANT", value: "Small")
            ]
            var label = ImageEditorLayer.text(
                name: "Continue",
                origin: CGPoint(x: 24, y: 24),
                content: ImageEditorTextContent(
                    text: "Continue",
                    color: .white,
                    fontSize: 14,
                    point: CGPoint(
                        x: ImageEditorTextContent.drawingPadding,
                        y: ImageEditorTextContent.drawingPadding
                    )
                )
            )
            label.groupID = component.id
            switch lockCase {
            case .ownFull:
                component.isLocked = true
            case .ownPixels:
                component.locksPixels = true
            case .ancestorFull:
                ancestor.isLocked = true
            case .ancestorPixels:
                ancestor.locksPixels = true
            }
            document.layers = [ancestor, component, label]
            document.selectedLayerID = component.id
            document.selectedLayerIDs = [component.id]

            let viewModel = ImageEditorViewModel(document: document) { _ in }
            viewModel.pushUndo()
            viewModel.undo()
            let propertiesBefore = viewModel.selectedLayerFigmaComponentProperties
            let defaultsBefore = viewModel.selectedLayerFigmaComponentPropertyDefaults
            let textBefore = viewModel.document.layers[2].textContent?.text
            let historyBefore = viewModel.document.history
            let undoCountBefore = viewModel.undoStack.count
            let redoCountBefore = viewModel.redoStack.count
            let canRedoBefore = viewModel.canRedo
            let projectEncoder = JSONEncoder()
            projectEncoder.outputFormatting = .sortedKeys
            let projectBefore = try projectEncoder.encode(
                ImageEditorProjectDocument(document: viewModel.document)
            )
            let undoSignaturesBefore = try viewModel.undoStack.map {
                try projectEncoder.encode(ImageEditorProjectDocument(document: $0))
            }
            let redoSignaturesBefore = try viewModel.redoStack.map {
                try projectEncoder.encode(ImageEditorProjectDocument(document: $0))
            }

            #expect(!viewModel.canEditSelectedFigmaComponentProperties)
            #expect(viewModel.copySelectedFigmaComponentPropertyOverrides())
            let copiedData = try #require(
                NSPasteboard.general.data(forType: .string)
            )
            let copiedProperties = try JSONDecoder().decode(
                [String: XomoFigmaComponentProperty].self,
                from: copiedData
            )
            #expect(copiedProperties == propertiesBefore)
            viewModel.updateSelectedFigmaComponentProperty("Label", value: "Buy now")
            viewModel.updateSelectedFigmaComponentBooleanProperty("Enabled", isEnabled: false)
            viewModel.updateSelectedFigmaComponentProperty("Size", value: "Small")
            viewModel.resetSelectedFigmaComponentProperty("Label")
            viewModel.resetAllSelectedFigmaComponentPropertyOverrides()

            #expect(viewModel.selectedLayerFigmaComponentProperties == propertiesBefore)
            #expect(viewModel.selectedLayerFigmaComponentPropertyDefaults == defaultsBefore)
            #expect(viewModel.document.layers[2].textContent?.text == textBefore)
            #expect(viewModel.document.history == historyBefore)
            #expect(viewModel.undoStack.count == undoCountBefore)
            #expect(viewModel.redoStack.count == redoCountBefore)
            #expect(viewModel.canRedo == canRedoBefore)
            let undoSignaturesAfter = try viewModel.undoStack.map {
                try projectEncoder.encode(ImageEditorProjectDocument(document: $0))
            }
            let redoSignaturesAfter = try viewModel.redoStack.map {
                try projectEncoder.encode(ImageEditorProjectDocument(document: $0))
            }
            #expect(undoSignaturesAfter == undoSignaturesBefore)
            #expect(redoSignaturesAfter == redoSignaturesBefore)
            let projectAfter = try projectEncoder.encode(
                ImageEditorProjectDocument(document: viewModel.document)
            )
            #expect(projectAfter == projectBefore)
            #expect(viewModel.statusText == L10n.text("imageEditor.status.layerLocked"))
        }
    }

    @Test func componentPropertyEditingIgnoresPositionAndTransparencyLocksAndRecoversAfterUnlock() throws {
        let image = NSImage.transparent(size: CGSize(width: 20, height: 20))
        var document = ImageEditorDocument(sourceName: "figma-component-lock-scope.png", image: image)
        var ancestor = ImageEditorLayer.group(name: "Screen", size: image.size)
        ancestor.locksPosition = true
        ancestor.locksTransparentPixels = true
        var layer = document.layers[0]
        layer.isLocked = false
        layer.xomoFigmaComponentProperties = [
            "Label": XomoFigmaComponentProperty(type: "TEXT", value: "Continue")
        ]
        layer.xomoFigmaComponentPropertyDefaults = layer.xomoFigmaComponentProperties
        layer.groupID = ancestor.id
        layer.locksPosition = true
        layer.locksTransparentPixels = true
        document.layers = [ancestor, layer]
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]

        let viewModel = ImageEditorViewModel(document: document) { _ in }
        #expect(viewModel.canEditSelectedFigmaComponentProperties)
        viewModel.updateSelectedFigmaComponentProperty("Label", value: "Buy now")
        #expect(viewModel.selectedLayerFigmaComponentProperties["Label"]?.value == "Buy now")
        #expect(viewModel.selectedLayerFigmaComponentPropertyOverrideCount == 1)

        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].locksPixels = true
        #expect(!viewModel.canEditSelectedFigmaComponentProperties)
        viewModel.resetSelectedFigmaComponentProperty("Label")
        #expect(viewModel.selectedLayerFigmaComponentProperties["Label"]?.value == "Buy now")

        viewModel.document.layers[layerIndex].locksPixels = false
        #expect(viewModel.canEditSelectedFigmaComponentProperties)
        let undoCountBeforeResetAll = viewModel.undoStack.count
        let historyCountBeforeResetAll = viewModel.document.history.count
        viewModel.resetAllSelectedFigmaComponentPropertyOverrides()
        #expect(viewModel.selectedLayerFigmaComponentProperties["Label"]?.value == "Continue")
        #expect(viewModel.selectedLayerFigmaComponentPropertyOverrideCount == 0)
        #expect(viewModel.undoStack.count == undoCountBeforeResetAll + 1)
        #expect(viewModel.document.history.count == historyCountBeforeResetAll + 1)

        viewModel.undo()
        #expect(viewModel.selectedLayerFigmaComponentProperties["Label"]?.value == "Buy now")
        viewModel.redo()
        #expect(viewModel.selectedLayerFigmaComponentProperties["Label"]?.value == "Continue")
    }

    @Test func componentPropertyOverrideSummaryAndFilteringStayDerivedAndSorted() throws {
        let image = NSImage.transparent(size: CGSize(width: 20, height: 20))
        var document = ImageEditorDocument(sourceName: "figma-component-overrides.png", image: image)
        var layer = document.layers[0]
        layer.isLocked = false
        layer.xomoFigmaComponentProperties = [
            "Size": XomoFigmaComponentProperty(type: "VARIANT", value: "Large"),
            "Label": XomoFigmaComponentProperty(type: "TEXT", value: "Continue"),
            "Is Enabled": XomoFigmaComponentProperty(type: "BOOLEAN", value: "true"),
            "Custom": XomoFigmaComponentProperty(type: "TEXT", value: "No snapshot")
        ]
        layer.xomoFigmaComponentPropertyDefaults = [
            "Size": XomoFigmaComponentProperty(type: "VARIANT", value: "Large"),
            "Label": XomoFigmaComponentProperty(type: "TEXT", value: "Continue"),
            "Is Enabled": XomoFigmaComponentProperty(type: "BOOLEAN", value: "true")
        ]
        document.layers = [layer]
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]

        let viewModel = ImageEditorViewModel(document: document) { _ in }

        #expect(viewModel.selectedLayerFigmaComponentPropertyOverrideKeys.isEmpty)
        #expect(viewModel.selectedLayerFigmaComponentPropertyOverrideCount == 0)
        #expect(
            viewModel.selectedLayerFigmaComponentPropertyKeys(onlyOverrides: false)
                == ["Custom", "Is Enabled", "Label", "Size"]
        )
        #expect(viewModel.selectedLayerFigmaComponentPropertyKeys(onlyOverrides: true).isEmpty)

        viewModel.updateSelectedFigmaComponentProperty("Size", value: "Compact")
        viewModel.updateSelectedFigmaComponentBooleanProperty("Is Enabled", isEnabled: false)
        viewModel.updateSelectedFigmaComponentProperty("Label", value: "Buy now")

        #expect(viewModel.selectedLayerFigmaComponentPropertyOverrideKeys == ["Is Enabled", "Label", "Size"])
        #expect(viewModel.selectedLayerFigmaComponentPropertyOverrideCount == 3)
        #expect(
            viewModel.selectedLayerFigmaComponentPropertyKeys(onlyOverrides: true)
                == ["Is Enabled", "Label", "Size"]
        )

        viewModel.resetSelectedFigmaComponentProperty("Label")
        #expect(viewModel.selectedLayerFigmaComponentPropertyOverrideKeys == ["Is Enabled", "Size"])
        #expect(viewModel.selectedLayerFigmaComponentPropertyOverrideCount == 2)

        viewModel.undo()
        #expect(viewModel.selectedLayerFigmaComponentPropertyOverrideKeys == ["Is Enabled", "Label", "Size"])
        #expect(viewModel.selectedLayerFigmaComponentPropertyOverrideCount == 3)

        viewModel.redo()
        #expect(viewModel.selectedLayerFigmaComponentPropertyOverrideKeys == ["Is Enabled", "Size"])
        #expect(viewModel.selectedLayerFigmaComponentPropertyOverrideCount == 2)

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restored = try project.restoredDocument()
        let restoredViewModel = ImageEditorViewModel(document: restored) { _ in }
        #expect(restoredViewModel.selectedLayerFigmaComponentPropertyOverrideKeys == ["Is Enabled", "Size"])
        #expect(restoredViewModel.selectedLayerFigmaComponentPropertyOverrideCount == 2)
    }

    @Test func componentPropertyHealthSummaryAndCombinedFiltersStayDerivedAndSorted() throws {
        let image = NSImage.transparent(size: CGSize(width: 20, height: 20))
        var document = ImageEditorDocument(sourceName: "figma-component-health.png", image: image)
        var layer = document.layers[0]
        let preferredValues = [
            XomoFigmaComponentPreferredValue(key: "small", name: "Small"),
            XomoFigmaComponentPreferredValue(key: "large", name: "Large")
        ]
        layer.xomoFigmaComponentProperties = [
            "Golf": XomoFigmaComponentProperty(type: "TEXT", value: "Current"),
            "Echo": XomoFigmaComponentProperty(
                type: "VARIANT",
                value: "Legacy",
                preferredValues: [
                    XomoFigmaComponentPreferredValue(key: "same", name: "First"),
                    XomoFigmaComponentPreferredValue(key: "same", name: "Second")
                ]
            ),
            "Charlie": XomoFigmaComponentProperty(type: "BOOLEAN", value: "TRUE"),
            "Alpha": XomoFigmaComponentProperty(type: "TEXT", value: "Healthy"),
            "Foxtrot": XomoFigmaComponentProperty(type: "FUTURE", value: "Preserved"),
            "Delta": XomoFigmaComponentProperty(
                type: "VARIANT",
                value: "Legacy",
                preferredValues: preferredValues
            ),
            "Bravo": XomoFigmaComponentProperty(type: "TEXT", value: "Override")
        ]
        layer.xomoFigmaComponentPropertyDefaults = [
            "Golf": XomoFigmaComponentProperty(type: "TEXT", value: "Current"),
            "Echo": layer.xomoFigmaComponentProperties["Echo"]!,
            "Charlie": XomoFigmaComponentProperty(type: "BOOLEAN", value: "true"),
            "Alpha": XomoFigmaComponentProperty(type: "TEXT", value: "Healthy"),
            "Foxtrot": layer.xomoFigmaComponentProperties["Foxtrot"]!,
            "Delta": XomoFigmaComponentProperty(
                type: "VARIANT",
                value: "Small",
                preferredValues: preferredValues
            ),
            "Bravo": XomoFigmaComponentProperty(type: "TEXT", value: "Imported")
        ]
        document.layers = [layer]
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]

        let viewModel = ImageEditorViewModel(document: document) { _ in }
        #expect(viewModel.selectedLayerFigmaComponentProperties.count == 7)
        #expect(viewModel.selectedLayerFigmaComponentPropertyOverrideCount == 3)
        #expect(
            viewModel.selectedLayerFigmaComponentPropertyHealthSummary
                == XomoFigmaComponentPropertyHealthSummary(
                    properties: layer.xomoFigmaComponentProperties
                )
        )
        #expect(viewModel.selectedLayerFigmaComponentPropertyDiagnosticCount == 4)
        #expect(viewModel.selectedLayerFigmaComponentPropertyBlockedCount == 2)
        #expect(
            viewModel.selectedLayerFigmaComponentPropertyKeys(onlyOverrides: false)
                == ["Alpha", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot", "Golf"]
        )
        #expect(
            viewModel.selectedLayerFigmaComponentPropertyKeys(
                onlyOverrides: true,
                onlyDiagnostics: false
            ) == ["Bravo", "Charlie", "Delta"]
        )
        #expect(
            viewModel.selectedLayerFigmaComponentPropertyKeys(
                onlyOverrides: false,
                onlyDiagnostics: true
            ) == ["Charlie", "Delta", "Echo", "Foxtrot"]
        )
        #expect(
            viewModel.selectedLayerFigmaComponentPropertyKeys(
                onlyOverrides: true,
                onlyDiagnostics: true
            ) == ["Charlie", "Delta"]
        )
    }

    @Test func componentPropertySearchMatchesKeysAndCurrentValuesAcrossCombinedFilters() throws {
        let image = NSImage.transparent(size: CGSize(width: 20, height: 20))
        var document = ImageEditorDocument(sourceName: "figma-component-search.png", image: image)
        var layer = document.layers[0]
        let deltaPreferredValues = [
            XomoFigmaComponentPreferredValue(key: "small", name: "Default Only Phrase")
        ]
        layer.xomoFigmaComponentProperties = [
            "Golf": XomoFigmaComponentProperty(type: "TEXT", value: "Value-only token"),
            "Echo Focus": XomoFigmaComponentProperty(type: "FUTURE", value: "Preserved"),
            "Charlie": XomoFigmaComponentProperty(type: "BOOLEAN", value: "FOCUS"),
            "Alpha": XomoFigmaComponentProperty(type: "TEXT", value: "Neutral"),
            "Foxtrot": XomoFigmaComponentProperty(type: "TEXT", value: "Café value"),
            "Delta": XomoFigmaComponentProperty(
                type: "VARIANT",
                value: "Résumé Focus",
                preferredValues: deltaPreferredValues
            ),
            "Bravo Focus": XomoFigmaComponentProperty(type: "TEXT", value: "Ready")
        ]
        layer.xomoFigmaComponentPropertyDefaults = [
            "Golf": layer.xomoFigmaComponentProperties["Golf"]!,
            "Echo Focus": layer.xomoFigmaComponentProperties["Echo Focus"]!,
            "Charlie": XomoFigmaComponentProperty(type: "BOOLEAN", value: "true"),
            "Alpha": layer.xomoFigmaComponentProperties["Alpha"]!,
            "Foxtrot": layer.xomoFigmaComponentProperties["Foxtrot"]!,
            "Delta": XomoFigmaComponentProperty(
                type: "VARIANT",
                value: "Default Only Phrase",
                preferredValues: deltaPreferredValues
            ),
            "Bravo Focus": XomoFigmaComponentProperty(type: "TEXT", value: "Imported")
        ]
        document.layers = [layer]
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]

        let viewModel = ImageEditorViewModel(document: document) { _ in }
        let propertiesBefore = viewModel.selectedLayerFigmaComponentProperties
        let defaultsBefore = viewModel.selectedLayerFigmaComponentPropertyDefaults
        let historyBefore = viewModel.document.history
        let undoCountBefore = viewModel.undoStack.count
        let redoCountBefore = viewModel.redoStack.count
        let overrideCountBefore = viewModel.selectedLayerFigmaComponentPropertyOverrideCount
        let diagnosticCountBefore = viewModel.selectedLayerFigmaComponentPropertyDiagnosticCount
        let blockedCountBefore = viewModel.selectedLayerFigmaComponentPropertyBlockedCount
        let allKeys = ["Alpha", "Bravo Focus", "Charlie", "Delta", "Echo Focus", "Foxtrot", "Golf"]

        #expect(
            viewModel.selectedLayerFigmaComponentPropertyKeys(
                onlyOverrides: false,
                searchQuery: ""
            ) == allKeys
        )
        #expect(
            viewModel.selectedLayerFigmaComponentPropertyKeys(
                onlyOverrides: false,
                searchQuery: " \t\n "
            ) == allKeys
        )
        #expect(
            viewModel.selectedLayerFigmaComponentPropertyKeys(
                onlyOverrides: false,
                searchQuery: "  bRaVo  "
            ) == ["Bravo Focus"]
        )
        #expect(
            viewModel.selectedLayerFigmaComponentPropertyKeys(
                onlyOverrides: false,
                searchQuery: "resume"
            ) == ["Delta"]
        )
        #expect(
            viewModel.selectedLayerFigmaComponentPropertyKeys(
                onlyOverrides: false,
                searchQuery: "CAFE"
            ) == ["Foxtrot"]
        )
        #expect(
            viewModel.selectedLayerFigmaComponentPropertyKeys(
                onlyOverrides: false,
                searchQuery: "value-only"
            ) == ["Golf"]
        )
        #expect(
            viewModel.selectedLayerFigmaComponentPropertyKeys(
                onlyOverrides: false,
                searchQuery: "Default Only Phrase"
            ).isEmpty
        )
        for excludedMetadataQuery in [
            "FUTURE",
            "unknown_type",
            "boolean_value_non_canonical"
        ] {
            #expect(
                viewModel.selectedLayerFigmaComponentPropertyKeys(
                    onlyOverrides: false,
                    searchQuery: excludedMetadataQuery
                ).isEmpty
            )
        }
        #expect(
            viewModel.selectedLayerFigmaComponentPropertyKeys(
                onlyOverrides: false,
                searchQuery: "not present"
            ).isEmpty
        )
        #expect(
            viewModel.selectedLayerFigmaComponentPropertyKeys(
                onlyOverrides: false,
                onlyDiagnostics: false,
                searchQuery: "focus"
            ) == ["Bravo Focus", "Charlie", "Delta", "Echo Focus"]
        )
        #expect(
            viewModel.selectedLayerFigmaComponentPropertyKeys(
                onlyOverrides: true,
                onlyDiagnostics: false,
                searchQuery: "focus"
            ) == ["Bravo Focus", "Charlie", "Delta"]
        )
        #expect(
            viewModel.selectedLayerFigmaComponentPropertyKeys(
                onlyOverrides: false,
                onlyDiagnostics: true,
                searchQuery: "focus"
            ) == ["Charlie", "Delta", "Echo Focus"]
        )
        #expect(
            viewModel.selectedLayerFigmaComponentPropertyKeys(
                onlyOverrides: true,
                onlyDiagnostics: true,
                searchQuery: "focus"
            ) == ["Charlie", "Delta"]
        )

        #expect(viewModel.selectedLayerFigmaComponentProperties == propertiesBefore)
        #expect(viewModel.selectedLayerFigmaComponentPropertyDefaults == defaultsBefore)
        #expect(viewModel.document.history == historyBefore)
        #expect(viewModel.undoStack.count == undoCountBefore)
        #expect(viewModel.redoStack.count == redoCountBefore)
        #expect(viewModel.selectedLayerFigmaComponentPropertyOverrideCount == overrideCountBefore)
        #expect(viewModel.selectedLayerFigmaComponentPropertyDiagnosticCount == diagnosticCountBefore)
        #expect(viewModel.selectedLayerFigmaComponentPropertyBlockedCount == blockedCountBefore)
        #expect(viewModel.undoStack.isEmpty)
        #expect(viewModel.redoStack.isEmpty)
    }

    @Test func componentPropertyFilterResultReportsSharedCountsAndActivationWithoutSideEffects() throws {
        let image = NSImage.transparent(size: CGSize(width: 20, height: 20))
        var document = ImageEditorDocument(sourceName: "figma-component-filter-result.png", image: image)
        var layer = document.layers[0]
        let preferredValues = [
            XomoFigmaComponentPreferredValue(key: "small", name: "Small"),
            XomoFigmaComponentPreferredValue(key: "large", name: "Large")
        ]
        layer.xomoFigmaComponentProperties = [
            "Shared Golf": XomoFigmaComponentProperty(type: "TEXT", value: "Current"),
            "Shared Echo Focus": XomoFigmaComponentProperty(
                type: "VARIANT",
                value: "Legacy",
                preferredValues: [
                    XomoFigmaComponentPreferredValue(key: "same", name: "First"),
                    XomoFigmaComponentPreferredValue(key: "same", name: "Second")
                ]
            ),
            "Shared Charlie": XomoFigmaComponentProperty(type: "BOOLEAN", value: "FOCUS"),
            "Shared Alpha": XomoFigmaComponentProperty(type: "TEXT", value: "Healthy"),
            "Shared Foxtrot": XomoFigmaComponentProperty(type: "FUTURE", value: "Preserved"),
            "Shared Delta": XomoFigmaComponentProperty(
                type: "VARIANT",
                value: "Focus Legacy",
                preferredValues: preferredValues
            ),
            "Shared Bravo Focus": XomoFigmaComponentProperty(type: "TEXT", value: "Override")
        ]
        layer.xomoFigmaComponentPropertyDefaults = [
            "Shared Golf": layer.xomoFigmaComponentProperties["Shared Golf"]!,
            "Shared Echo Focus": layer.xomoFigmaComponentProperties["Shared Echo Focus"]!,
            "Shared Charlie": XomoFigmaComponentProperty(type: "BOOLEAN", value: "true"),
            "Shared Alpha": layer.xomoFigmaComponentProperties["Shared Alpha"]!,
            "Shared Foxtrot": layer.xomoFigmaComponentProperties["Shared Foxtrot"]!,
            "Shared Delta": XomoFigmaComponentProperty(
                type: "VARIANT",
                value: "Small",
                preferredValues: preferredValues
            ),
            "Shared Bravo Focus": XomoFigmaComponentProperty(type: "TEXT", value: "Imported")
        ]
        document.layers = [layer]
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]

        let viewModel = ImageEditorViewModel(document: document) { _ in }
        let propertiesBefore = viewModel.selectedLayerFigmaComponentProperties
        let defaultsBefore = viewModel.selectedLayerFigmaComponentPropertyDefaults
        let historyBefore = viewModel.document.history
        let statusBefore = viewModel.statusText
        let undoCountBefore = viewModel.undoStack.count
        let redoCountBefore = viewModel.redoStack.count
        let overrideCountBefore = viewModel.selectedLayerFigmaComponentPropertyOverrideCount
        let diagnosticCountBefore = viewModel.selectedLayerFigmaComponentPropertyDiagnosticCount
        let blockedCountBefore = viewModel.selectedLayerFigmaComponentPropertyBlockedCount
        let allKeys = [
            "Shared Alpha",
            "Shared Bravo Focus",
            "Shared Charlie",
            "Shared Delta",
            "Shared Echo Focus",
            "Shared Foxtrot",
            "Shared Golf"
        ]

        let inactiveResult = viewModel.selectedLayerFigmaComponentPropertyFilterResult(
            onlyOverrides: false
        )
        #expect(
            inactiveResult
                == XomoFigmaComponentPropertyFilterResult(
                    visibleKeys: allKeys,
                    totalCount: 7,
                    isActive: false
                )
        )
        #expect(inactiveResult.visibleCount == 7)

        let whitespaceResult = viewModel.selectedLayerFigmaComponentPropertyFilterResult(
            onlyOverrides: false,
            searchQuery: " \t\n "
        )
        #expect(whitespaceResult == inactiveResult)

        let overrideResult = viewModel.selectedLayerFigmaComponentPropertyFilterResult(
            onlyOverrides: true
        )
        #expect(
            overrideResult.visibleKeys
                == ["Shared Bravo Focus", "Shared Charlie", "Shared Delta"]
        )
        #expect(overrideResult.visibleCount == 3)
        #expect(overrideResult.totalCount == 7)
        #expect(overrideResult.isActive)

        let diagnosticResult = viewModel.selectedLayerFigmaComponentPropertyFilterResult(
            onlyOverrides: false,
            onlyDiagnostics: true
        )
        #expect(
            diagnosticResult.visibleKeys
                == ["Shared Charlie", "Shared Delta", "Shared Echo Focus", "Shared Foxtrot"]
        )
        #expect(diagnosticResult.visibleCount == 4)
        #expect(diagnosticResult.totalCount == 7)
        #expect(diagnosticResult.isActive)

        let matchingAllResult = viewModel.selectedLayerFigmaComponentPropertyFilterResult(
            onlyOverrides: false,
            searchQuery: "  SHARED  "
        )
        #expect(matchingAllResult.visibleKeys == allKeys)
        #expect(matchingAllResult.visibleCount == matchingAllResult.totalCount)
        #expect(matchingAllResult.isActive)

        let searchResult = viewModel.selectedLayerFigmaComponentPropertyFilterResult(
            onlyOverrides: false,
            searchQuery: "focus"
        )
        #expect(
            searchResult.visibleKeys
                == ["Shared Bravo Focus", "Shared Charlie", "Shared Delta", "Shared Echo Focus"]
        )
        #expect(searchResult.visibleCount == 4)
        #expect(searchResult.totalCount == 7)
        #expect(searchResult.isActive)

        let combinedResult = viewModel.selectedLayerFigmaComponentPropertyFilterResult(
            onlyOverrides: true,
            onlyDiagnostics: true,
            searchQuery: "focus"
        )
        #expect(combinedResult.visibleKeys == ["Shared Charlie", "Shared Delta"])
        #expect(combinedResult.visibleCount == 2)
        #expect(combinedResult.totalCount == 7)
        #expect(combinedResult.isActive)

        let emptyResult = viewModel.selectedLayerFigmaComponentPropertyFilterResult(
            onlyOverrides: false,
            searchQuery: "not present"
        )
        #expect(emptyResult.visibleKeys.isEmpty)
        #expect(emptyResult.visibleCount == 0)
        #expect(emptyResult.totalCount == 7)
        #expect(emptyResult.isActive)

        for (result, onlyOverrides, onlyDiagnostics, searchQuery) in [
            (inactiveResult, false, false, ""),
            (whitespaceResult, false, false, " \t\n "),
            (overrideResult, true, false, ""),
            (diagnosticResult, false, true, ""),
            (matchingAllResult, false, false, "  SHARED  "),
            (searchResult, false, false, "focus"),
            (combinedResult, true, true, "focus"),
            (emptyResult, false, false, "not present")
        ] {
            #expect(
                viewModel.selectedLayerFigmaComponentPropertyKeys(
                    onlyOverrides: onlyOverrides,
                    onlyDiagnostics: onlyDiagnostics,
                    searchQuery: searchQuery
                ) == result.visibleKeys
            )
        }

        #expect(viewModel.selectedLayerFigmaComponentProperties == propertiesBefore)
        #expect(viewModel.selectedLayerFigmaComponentPropertyDefaults == defaultsBefore)
        #expect(viewModel.document.history == historyBefore)
        #expect(viewModel.statusText == statusBefore)
        #expect(viewModel.undoStack.count == undoCountBefore)
        #expect(viewModel.redoStack.count == redoCountBefore)
        #expect(viewModel.selectedLayerFigmaComponentPropertyOverrideCount == overrideCountBefore)
        #expect(viewModel.selectedLayerFigmaComponentPropertyDiagnosticCount == diagnosticCountBefore)
        #expect(viewModel.selectedLayerFigmaComponentPropertyBlockedCount == blockedCountBefore)
        #expect(viewModel.undoStack.isEmpty)
        #expect(viewModel.redoStack.isEmpty)
    }

    @Test func copyingComponentPropertyOverridesUsesAnExactBaselineDerivedSubsetAndNoOpsWhenEmpty() throws {
        let image = NSImage.transparent(size: CGSize(width: 20, height: 20))
        var document = ImageEditorDocument(sourceName: "figma-copy-overrides.png", image: image)
        var layer = document.layers[0]
        let importedLabel = XomoFigmaComponentProperty(type: "TEXT", value: "Continue")
        let importedEnabled = XomoFigmaComponentProperty(type: "BOOLEAN", value: "true")
        let importedSize = XomoFigmaComponentProperty(
            type: "VARIANT",
            value: "Large",
            preferredValues: [
                XomoFigmaComponentPreferredValue(key: "large", name: "Large"),
                XomoFigmaComponentPreferredValue(key: "small", name: "Small")
            ]
        )
        let metadataOnlySize = XomoFigmaComponentProperty(
            type: "VARIANT",
            value: "Large",
            preferredValues: [
                XomoFigmaComponentPreferredValue(key: "large", name: "Large"),
                XomoFigmaComponentPreferredValue(key: "compact", name: "Compact")
            ]
        )
        layer.xomoFigmaComponentProperties = [
            "Label": XomoFigmaComponentProperty(type: "TEXT", value: "Buy now"),
            "Enabled": XomoFigmaComponentProperty(type: "BOOLEAN", value: "false"),
            "Size": metadataOnlySize,
            "Custom": XomoFigmaComponentProperty(type: "TEXT", value: "Local only")
        ]
        layer.xomoFigmaComponentPropertyDefaults = [
            "Label": importedLabel,
            "Enabled": importedEnabled,
            "Size": importedSize
        ]
        document.layers = [layer]
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]
        let viewModel = ImageEditorViewModel(document: document) { _ in }

        viewModel.copySelectedFigmaComponentProperties()
        let allData = try #require(NSPasteboard.general.data(forType: .string))
        let allProperties = try JSONDecoder().decode(
            [String: XomoFigmaComponentProperty].self,
            from: allData
        )
        #expect(allProperties == layer.xomoFigmaComponentProperties)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.figmaComponentPropertiesCopied"))

        #expect(viewModel.copySelectedFigmaComponentPropertyOverrides())
        let overridesData = try #require(NSPasteboard.general.data(forType: .string))
        let overrides = try JSONDecoder().decode(
            [String: XomoFigmaComponentProperty].self,
            from: overridesData
        )
        let overriddenLabel = try #require(layer.xomoFigmaComponentProperties["Label"])
        let expectedOverrides: [String: XomoFigmaComponentProperty] = [
            "Enabled": XomoFigmaComponentProperty(type: "BOOLEAN", value: "false"),
            "Label": overriddenLabel,
            "Size": metadataOnlySize
        ]
        #expect(overrides == expectedOverrides)
        #expect(overrides["Size"]?.preferredValues == metadataOnlySize.preferredValues)
        #expect(overrides["Enabled"]?.value == "false")
        #expect(overrides["Custom"] == nil)
        let sidecarType = NSPasteboard.PasteboardType(
            XomoFigmaComponentPropertyOverridesPasteboardPayload.pasteboardType
        )
        let sidecarData = try #require(NSPasteboard.general.data(forType: sidecarType))
        let sidecar = try JSONDecoder().decode(
            XomoFigmaComponentPropertyOverridesPasteboardPayload.self,
            from: sidecarData
        )
        #expect(sidecar.version == XomoFigmaComponentPropertyOverridesPasteboardPayload.currentVersion)
        #expect(sidecar.overrides == expectedOverrides)
        #expect(Set(sidecar.importedDefaults.keys) == Set(expectedOverrides.keys))
        #expect(
            viewModel.statusText
                == L10n.text("imageEditor.status.figmaComponentPropertyOverridesCopied")
        )

        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].xomoFigmaComponentProperties = [
            "Label": importedLabel,
            "Enabled": importedEnabled,
            "Size": importedSize,
            "Custom": XomoFigmaComponentProperty(type: "TEXT", value: "Local only")
        ]
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("copy-overrides-sentinel", forType: .string)
        let changeCountBefore = pasteboard.changeCount
        viewModel.statusText = "copy-overrides-status-sentinel"

        #expect(!viewModel.copySelectedFigmaComponentPropertyOverrides())
        #expect(pasteboard.changeCount == changeCountBefore)
        #expect(pasteboard.string(forType: .string) == "copy-overrides-sentinel")
        #expect(viewModel.statusText == "copy-overrides-status-sentinel")
    }

    @Test func pastingComponentPropertyOverridesIsCrossInstanceAtomicAndSchemaSafe() throws {
        let image = NSImage.transparent(size: CGSize(width: 240, height: 100))
        let labelDefault = XomoFigmaComponentProperty(type: "TEXT", value: "Continue")
        let modeDefault = XomoFigmaComponentProperty(
            type: "TEXT",
            value: "Continue",
            preferredValues: [XomoFigmaComponentPreferredValue(key: "base", name: "Base")]
        )
        let metadataOnlyMode = XomoFigmaComponentProperty(
            type: "VARIANT",
            value: "Continue",
            preferredValues: [XomoFigmaComponentPreferredValue(key: "local", name: "Local")]
        )

        var sourceDocument = ImageEditorDocument(sourceName: "figma-source.png", image: image)
        var source = ImageEditorLayer.group(name: "Source", size: image.size)
        source.xomoFigmaComponentProperties = [
            "Label": XomoFigmaComponentProperty(type: "TEXT", value: "Buy now"),
            "Mode": metadataOnlyMode
        ]
        source.xomoFigmaComponentPropertyDefaults = ["Label": labelDefault, "Mode": modeDefault]
        sourceDocument.layers = [source]
        sourceDocument.selectedLayerID = source.id
        sourceDocument.selectedLayerIDs = [source.id]
        let sourceViewModel = ImageEditorViewModel(document: sourceDocument) { _ in }
        #expect(sourceViewModel.copySelectedFigmaComponentPropertyOverrides())

        var targetDocument = ImageEditorDocument(sourceName: "figma-target.png", image: image)
        var target = ImageEditorLayer.group(name: "Target", size: image.size)
        target.xomoFigmaComponentProperties = ["Label": labelDefault, "Mode": modeDefault]
        target.xomoFigmaComponentPropertyDefaults = ["Label": labelDefault, "Mode": modeDefault]
        var label = ImageEditorLayer.text(
            name: "Continue",
            origin: .zero,
            content: ImageEditorTextContent(
                text: "Continue",
                color: .white,
                fontSize: 14,
                point: CGPoint(
                    x: ImageEditorTextContent.drawingPadding,
                    y: ImageEditorTextContent.drawingPadding
                )
            )
        )
        label.groupID = target.id
        targetDocument.layers = [target, label]
        targetDocument.selectedLayerID = target.id
        targetDocument.selectedLayerIDs = [target.id]
        let viewModel = ImageEditorViewModel(document: targetDocument) { _ in }
        let defaultsBefore = viewModel.selectedLayerFigmaComponentPropertyDefaults
        let undoCountBefore = viewModel.undoStack.count
        let historyCountBefore = viewModel.document.history.count

        let pasted = viewModel.pasteSelectedFigmaComponentPropertyOverrides()
        guard case .success(let pastedCount) = pasted else {
            Issue.record("Expected compatible cross-instance overrides to paste")
            return
        }
        #expect(pastedCount == 2)
        #expect(viewModel.selectedLayerFigmaComponentProperties["Label"]?.value == "Buy now")
        #expect(viewModel.selectedLayerFigmaComponentProperties["Mode"] == metadataOnlyMode)
        #expect(viewModel.selectedLayerFigmaComponentPropertyDefaults == defaultsBefore)
        #expect(viewModel.document.layers[1].textContent?.text == "Buy now")
        #expect(viewModel.undoStack.count == undoCountBefore + 1)
        #expect(viewModel.document.history.count == historyCountBefore + 1)

        viewModel.undo()
        #expect(viewModel.selectedLayerFigmaComponentProperties["Label"] == labelDefault)
        #expect(viewModel.selectedLayerFigmaComponentProperties["Mode"] == modeDefault)
        #expect(viewModel.document.layers[1].textContent?.text == "Continue")
        #expect(viewModel.selectedLayerFigmaComponentPropertyDefaults == defaultsBefore)
        viewModel.redo()
        #expect(viewModel.selectedLayerFigmaComponentProperties["Label"]?.value == "Buy now")
        #expect(viewModel.selectedLayerFigmaComponentProperties["Mode"] == metadataOnlyMode)
        #expect(viewModel.document.layers[1].textContent?.text == "Buy now")
        #expect(viewModel.selectedLayerFigmaComponentPropertyDefaults == defaultsBefore)

        let noOpUndoCount = viewModel.undoStack.count
        let noOpHistory = viewModel.document.history
        let noOpPaste = viewModel.pasteSelectedFigmaComponentPropertyOverrides()
        guard case .success(let noOpCount) = noOpPaste else {
            Issue.record("Expected an identical override paste to succeed")
            return
        }
        #expect(noOpCount == 0)
        #expect(viewModel.undoStack.count == noOpUndoCount)
        #expect(viewModel.document.history == noOpHistory)

        let incompatiblePayload = XomoFigmaComponentPropertyOverridesPasteboardPayload(
            overrides: [
                "Label": XomoFigmaComponentProperty(type: "TEXT", value: "Rejected"),
                "Mode": metadataOnlyMode
            ],
            importedDefaults: [
                "Label": XomoFigmaComponentProperty(type: "TEXT", value: "Different baseline"),
                "Mode": modeDefault
            ]
        )
        let encoder = JSONEncoder()
        let pasteboard = NSPasteboard(
            name: NSPasteboard.Name("im.some.xomo.tests.figma-component-overrides.atomic")
        )
        let sidecarType = NSPasteboard.PasteboardType(
            XomoFigmaComponentPropertyOverridesPasteboardPayload.pasteboardType
        )
        pasteboard.clearContents()
        pasteboard.setData(try encoder.encode(incompatiblePayload), forType: sidecarType)
        let propertiesBeforeFailure = viewModel.selectedLayerFigmaComponentProperties
        let failureUndoCount = viewModel.undoStack.count
        let failureRedoCount = viewModel.redoStack.count
        let failureHistory = viewModel.document.history
        let incompatiblePaste = viewModel.pasteSelectedFigmaComponentPropertyOverrides(
            from: pasteboard
        )
        guard case .failure(let incompatibleError) = incompatiblePaste else {
            Issue.record("Expected the incompatible override batch to be rejected")
            return
        }
        #expect(incompatibleError == .incompatiblePayload)
        #expect(viewModel.selectedLayerFigmaComponentProperties == propertiesBeforeFailure)
        #expect(viewModel.undoStack.count == failureUndoCount)
        #expect(viewModel.redoStack.count == failureRedoCount)
        #expect(viewModel.document.history == failureHistory)
        #expect(viewModel.selectedLayerFigmaComponentPropertyDefaults == defaultsBefore)
        #expect(viewModel.document.layers[1].textContent?.text == "Buy now")

        let invalidBooleanPayload = XomoFigmaComponentPropertyOverridesPasteboardPayload(
            overrides: [
                "Label": XomoFigmaComponentProperty(type: "BOOLEAN", value: "yes"),
                "Mode": metadataOnlyMode
            ],
            importedDefaults: ["Label": labelDefault, "Mode": modeDefault]
        )
        pasteboard.clearContents()
        pasteboard.setData(try encoder.encode(invalidBooleanPayload), forType: sidecarType)
        let invalidBooleanPaste = viewModel.pasteSelectedFigmaComponentPropertyOverrides(
            from: pasteboard
        )
        guard case .failure(let invalidBooleanError) = invalidBooleanPaste else {
            Issue.record("Expected an invalid BOOLEAN override batch to be rejected")
            return
        }
        #expect(invalidBooleanError == .incompatiblePayload)
        #expect(viewModel.selectedLayerFigmaComponentProperties == propertiesBeforeFailure)
        #expect(viewModel.undoStack.count == failureUndoCount)
        #expect(viewModel.redoStack.count == failureRedoCount)
        #expect(viewModel.document.history == failureHistory)
        #expect(viewModel.selectedLayerFigmaComponentPropertyDefaults == defaultsBefore)
        #expect(viewModel.document.layers[1].textContent?.text == "Buy now")

        let validPayload = XomoFigmaComponentPropertyOverridesPasteboardPayload(
            overrides: ["Label": XomoFigmaComponentProperty(type: "TEXT", value: "Checkout")],
            importedDefaults: ["Label": labelDefault]
        )
        pasteboard.clearContents()
        pasteboard.setData(try encoder.encode(validPayload), forType: sidecarType)
        viewModel.document.layers[0].locksPixels = true
        let lockedPaste = viewModel.pasteSelectedFigmaComponentPropertyOverrides(from: pasteboard)
        guard case .failure(let lockedError) = lockedPaste else {
            Issue.record("Expected a pixel-locked component to reject paste")
            return
        }
        #expect(lockedError == .locked)
        #expect(viewModel.selectedLayerFigmaComponentProperties == propertiesBeforeFailure)
    }

    @Test func rawComponentPropertyOverridePasteRequiresImportedSchemaMetadata() throws {
        let image = NSImage.transparent(size: CGSize(width: 80, height: 40))
        var document = ImageEditorDocument(sourceName: "figma-raw-paste.png", image: image)
        var layer = ImageEditorLayer.group(name: "Raw target", size: image.size)
        let imported = XomoFigmaComponentProperty(
            type: "VARIANT",
            value: "Compact",
            preferredValues: [XomoFigmaComponentPreferredValue(key: "compact", name: "Compact")]
        )
        layer.xomoFigmaComponentProperties = ["Size": imported]
        layer.xomoFigmaComponentPropertyDefaults = ["Size": imported]
        document.layers = [layer]
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]
        let viewModel = ImageEditorViewModel(document: document) { _ in }
        let pasteboard = NSPasteboard(
            name: NSPasteboard.Name("im.some.xomo.tests.figma-component-overrides.raw")
        )
        pasteboard.clearContents()
        let compatible = [
            "Size": XomoFigmaComponentProperty(
                type: "VARIANT",
                value: "Roomy",
                preferredValues: imported.preferredValues
            )
        ]
        let compatibleJSON = try #require(
            String(data: JSONEncoder().encode(compatible), encoding: .utf8)
        )
        #expect(pasteboard.setString(compatibleJSON, forType: .string))
        let compatiblePaste = viewModel.pasteSelectedFigmaComponentPropertyOverrides(from: pasteboard)
        guard case .success(let compatibleCount) = compatiblePaste else {
            Issue.record("Expected schema-compatible raw overrides to paste, got \(compatiblePaste)")
            return
        }
        #expect(compatibleCount == 1)
        #expect(viewModel.selectedLayerFigmaComponentProperties["Size"]?.value == "Roomy")

        let undoCount = viewModel.undoStack.count
        let incompatible = [
            "Size": XomoFigmaComponentProperty(
                type: "VARIANT",
                value: "Dense",
                preferredValues: [XomoFigmaComponentPreferredValue(key: "dense", name: "Dense")]
            )
        ]
        let incompatibleJSON = try #require(
            String(data: JSONEncoder().encode(incompatible), encoding: .utf8)
        )
        #expect(pasteboard.setString(incompatibleJSON, forType: .string))
        let incompatiblePaste = viewModel.pasteSelectedFigmaComponentPropertyOverrides(from: pasteboard)
        guard case .failure(let incompatibleError) = incompatiblePaste else {
            Issue.record("Expected raw metadata drift to be rejected")
            return
        }
        #expect(incompatibleError == .incompatiblePayload)
        #expect(viewModel.selectedLayerFigmaComponentProperties["Size"]?.value == "Roomy")
        #expect(viewModel.undoStack.count == undoCount)
    }

    @Test func componentOverridePasteHonorsTextTypeLockInheritanceAndAmbiguityBoundaries() throws {
        let image = NSImage.transparent(size: CGSize(width: 200, height: 90))
        let labelDefault = XomoFigmaComponentProperty(type: "TEXT", value: "Continue")
        let swapDefault = XomoFigmaComponentProperty(type: "TEXT", value: "Old swap")
        let pastedLabel = XomoFigmaComponentProperty(type: "TEXT", value: "Buy now")
        let pastedSwap = XomoFigmaComponentProperty(type: "INSTANCE_SWAP", value: "node-2")
        let payload = XomoFigmaComponentPropertyOverridesPasteboardPayload(
            overrides: ["Label": pastedLabel, "Swap": pastedSwap],
            importedDefaults: ["Label": labelDefault, "Swap": swapDefault]
        )
        let pasteboard = NSPasteboard.general
        let sidecarType = NSPasteboard.PasteboardType(
            XomoFigmaComponentPropertyOverridesPasteboardPayload.pasteboardType
        )
        pasteboard.clearContents()
        pasteboard.setData(try JSONEncoder().encode(payload), forType: sidecarType)

        var document = ImageEditorDocument(sourceName: "figma-paste-locks.png", image: image)
        var parent = ImageEditorLayer.group(name: "Parent", size: image.size)
        parent.locksPosition = true
        parent.locksTransparentPixels = true
        var component = ImageEditorLayer.group(name: "Instance", size: image.size)
        component.groupID = parent.id
        component.xomoFigmaComponentProperties = ["Label": labelDefault, "Swap": swapDefault]
        component.xomoFigmaComponentPropertyDefaults = ["Label": labelDefault, "Swap": swapDefault]
        var lockedLabel = ImageEditorLayer.text(
            name: "Continue",
            origin: .zero,
            content: ImageEditorTextContent(
                text: "Continue",
                color: .white,
                fontSize: 14,
                point: CGPoint(
                    x: ImageEditorTextContent.drawingPadding,
                    y: ImageEditorTextContent.drawingPadding
                )
            )
        )
        lockedLabel.groupID = component.id
        lockedLabel.locksPixels = true
        var swapLabel = ImageEditorLayer.text(
            name: "Old swap",
            origin: CGPoint(x: 0, y: 30),
            content: ImageEditorTextContent(
                text: "Old swap",
                color: .white,
                fontSize: 14,
                point: CGPoint(
                    x: ImageEditorTextContent.drawingPadding,
                    y: ImageEditorTextContent.drawingPadding
                )
            )
        )
        swapLabel.groupID = component.id
        document.layers = [parent, component, lockedLabel, swapLabel]
        document.selectedLayerID = component.id
        document.selectedLayerIDs = [component.id]
        let viewModel = ImageEditorViewModel(document: document) { _ in }
        let propertiesBefore = viewModel.selectedLayerFigmaComponentProperties
        let defaultsBefore = viewModel.selectedLayerFigmaComponentPropertyDefaults
        let historyCountBefore = viewModel.document.history.count
        let undoCountBefore = viewModel.undoStack.count

        viewModel.document.layers[0].locksPixels = true
        let pixelLockedPaste = viewModel.pasteSelectedFigmaComponentPropertyOverrides()
        guard case .failure(let pixelLockedError) = pixelLockedPaste else {
            Issue.record("Expected an ancestor pixel lock to reject paste")
            return
        }
        #expect(pixelLockedError == .locked)
        #expect(viewModel.selectedLayerFigmaComponentProperties == propertiesBefore)
        #expect(viewModel.document.history.count == historyCountBefore)
        #expect(viewModel.undoStack.count == undoCountBefore)

        viewModel.document.layers[0].locksPixels = false
        viewModel.document.layers[0].isLocked = true
        let fullyLockedPaste = viewModel.pasteSelectedFigmaComponentPropertyOverrides()
        guard case .failure(let fullyLockedError) = fullyLockedPaste else {
            Issue.record("Expected an ancestor full lock to reject paste")
            return
        }
        #expect(fullyLockedError == .locked)
        #expect(viewModel.selectedLayerFigmaComponentProperties == propertiesBefore)
        #expect(viewModel.document.history.count == historyCountBefore)
        #expect(viewModel.undoStack.count == undoCountBefore)

        viewModel.document.layers[0].isLocked = false
        let allowedPaste = viewModel.pasteSelectedFigmaComponentPropertyOverrides()
        guard case .success(let allowedCount) = allowedPaste else {
            Issue.record("Expected ancestor position and transparency locks to allow paste")
            return
        }
        #expect(allowedCount == 2)
        #expect(viewModel.selectedLayerFigmaComponentProperties["Label"] == pastedLabel)
        #expect(viewModel.selectedLayerFigmaComponentProperties["Swap"] == pastedSwap)
        #expect(viewModel.selectedLayerFigmaComponentPropertyDefaults == defaultsBefore)
        #expect(viewModel.document.layers[2].textContent?.text == "Continue")
        #expect(viewModel.document.layers[3].textContent?.text == "Old swap")
        #expect(viewModel.undoStack.count == undoCountBefore + 1)
        #expect(viewModel.document.history.count == historyCountBefore + 1)

        viewModel.undo()
        #expect(viewModel.selectedLayerFigmaComponentProperties == propertiesBefore)
        #expect(viewModel.document.layers[2].textContent?.text == "Continue")
        #expect(viewModel.document.layers[3].textContent?.text == "Old swap")
        viewModel.redo()
        #expect(viewModel.selectedLayerFigmaComponentProperties["Label"] == pastedLabel)
        #expect(viewModel.selectedLayerFigmaComponentProperties["Swap"] == pastedSwap)
        #expect(viewModel.document.layers[2].textContent?.text == "Continue")
        #expect(viewModel.document.layers[3].textContent?.text == "Old swap")
        #expect(viewModel.selectedLayerFigmaComponentPropertyDefaults == defaultsBefore)

        let alphaDefault = XomoFigmaComponentProperty(type: "TEXT", value: "Alpha")
        let betaDefault = XomoFigmaComponentProperty(type: "TEXT", value: "Beta")
        var ambiguousDocument = ImageEditorDocument(
            sourceName: "figma-paste-ambiguous.png",
            image: image
        )
        var ambiguousComponent = ImageEditorLayer.group(name: "Ambiguous", size: image.size)
        ambiguousComponent.xomoFigmaComponentProperties = [
            "Alpha": XomoFigmaComponentProperty(type: "TEXT", value: "Shared"),
            "Beta": XomoFigmaComponentProperty(type: "TEXT", value: "Shared")
        ]
        ambiguousComponent.xomoFigmaComponentPropertyDefaults = [
            "Alpha": alphaDefault,
            "Beta": betaDefault
        ]
        var ambiguousLabel = ImageEditorLayer.text(
            name: "Shared",
            origin: .zero,
            content: ImageEditorTextContent(
                text: "Shared",
                color: .white,
                fontSize: 14,
                point: CGPoint(
                    x: ImageEditorTextContent.drawingPadding,
                    y: ImageEditorTextContent.drawingPadding
                )
            )
        )
        ambiguousLabel.groupID = ambiguousComponent.id
        ambiguousDocument.layers = [ambiguousComponent, ambiguousLabel]
        ambiguousDocument.selectedLayerID = ambiguousComponent.id
        ambiguousDocument.selectedLayerIDs = [ambiguousComponent.id]
        let ambiguousViewModel = ImageEditorViewModel(document: ambiguousDocument) { _ in }
        let ambiguousPropertiesBefore = ambiguousViewModel.selectedLayerFigmaComponentProperties
        let ambiguousDefaultsBefore = ambiguousViewModel.selectedLayerFigmaComponentPropertyDefaults
        let ambiguousHistoryBefore = ambiguousViewModel.document.history
        let ambiguousPayload = XomoFigmaComponentPropertyOverridesPasteboardPayload(
            overrides: [
                "Alpha": XomoFigmaComponentProperty(type: "TEXT", value: "One"),
                "Beta": XomoFigmaComponentProperty(type: "TEXT", value: "Two")
            ],
            importedDefaults: ["Alpha": alphaDefault, "Beta": betaDefault]
        )
        pasteboard.clearContents()
        pasteboard.setData(try JSONEncoder().encode(ambiguousPayload), forType: sidecarType)
        let ambiguousPaste = ambiguousViewModel.pasteSelectedFigmaComponentPropertyOverrides()
        guard case .failure(let ambiguousError) = ambiguousPaste else {
            Issue.record("Expected conflicting TEXT replacements to reject the whole batch")
            return
        }
        #expect(ambiguousError == .incompatiblePayload)
        #expect(ambiguousViewModel.selectedLayerFigmaComponentProperties == ambiguousPropertiesBefore)
        #expect(ambiguousViewModel.selectedLayerFigmaComponentPropertyDefaults == ambiguousDefaultsBefore)
        #expect(ambiguousViewModel.document.layers[1].textContent?.text == "Shared")
        #expect(ambiguousViewModel.document.history == ambiguousHistoryBefore)
        #expect(ambiguousViewModel.undoStack.isEmpty)
    }

    @Test func resettingAllComponentPropertyOverridesIsAtomicAndRestoresImportedObjectsAndText() throws {
        let image = NSImage.transparent(size: CGSize(width: 320, height: 180))
        var document = ImageEditorDocument(sourceName: "figma-reset-all.png", image: image)
        var component = ImageEditorLayer.group(name: "Card", size: image.size)
        let primaryDefault = XomoFigmaComponentProperty(type: "TEXT", value: "Continue")
        let secondaryDefault = XomoFigmaComponentProperty(type: "TEXT", value: "Cancel")
        let variantDefault = XomoFigmaComponentProperty(
            type: "VARIANT",
            value: "Compact",
            preferredValues: [XomoFigmaComponentPreferredValue(key: "compact", name: "Compact")]
        )
        component.xomoFigmaComponentProperties = [
            "Primary": XomoFigmaComponentProperty(type: "TEXT", value: "Buy now"),
            "Secondary": XomoFigmaComponentProperty(type: "TEXT", value: "Maybe later"),
            "Variant": XomoFigmaComponentProperty(
                type: "VARIANT",
                value: "Roomy",
                preferredValues: [XomoFigmaComponentPreferredValue(key: "roomy", name: "Roomy")]
            ),
            "Custom": XomoFigmaComponentProperty(type: "TEXT", value: "Local only")
        ]
        component.xomoFigmaComponentPropertyDefaults = [
            "Primary": primaryDefault,
            "Secondary": secondaryDefault,
            "Variant": variantDefault
        ]
        var primary = ImageEditorLayer.text(
            name: "Buy now",
            origin: CGPoint(x: 12, y: 12),
            content: ImageEditorTextContent(
                text: "Buy now",
                color: .white,
                fontSize: 14,
                point: CGPoint(
                    x: ImageEditorTextContent.drawingPadding,
                    y: ImageEditorTextContent.drawingPadding
                )
            )
        )
        primary.groupID = component.id
        var secondary = ImageEditorLayer.text(
            name: "Maybe later",
            origin: CGPoint(x: 12, y: 48),
            content: ImageEditorTextContent(
                text: "Maybe later",
                color: .white,
                fontSize: 14,
                point: CGPoint(
                    x: ImageEditorTextContent.drawingPadding,
                    y: ImageEditorTextContent.drawingPadding
                )
            )
        )
        secondary.groupID = component.id
        document.layers = [component, primary, secondary]
        document.selectedLayerID = component.id
        document.selectedLayerIDs = [component.id]

        let viewModel = ImageEditorViewModel(document: document) { _ in }
        let propertiesBefore = viewModel.selectedLayerFigmaComponentProperties
        let undoCountBefore = viewModel.undoStack.count
        let historyCountBefore = viewModel.document.history.count

        viewModel.resetAllSelectedFigmaComponentPropertyOverrides()

        #expect(viewModel.selectedLayerFigmaComponentProperties["Primary"] == primaryDefault)
        #expect(viewModel.selectedLayerFigmaComponentProperties["Secondary"] == secondaryDefault)
        #expect(viewModel.selectedLayerFigmaComponentProperties["Variant"] == variantDefault)
        #expect(viewModel.selectedLayerFigmaComponentProperties["Custom"] == propertiesBefore["Custom"])
        #expect(viewModel.document.layers[1].textContent?.text == "Continue")
        #expect(viewModel.document.layers[2].textContent?.text == "Cancel")
        #expect(viewModel.selectedLayerFigmaComponentPropertyOverrideCount == 0)
        #expect(viewModel.undoStack.count == undoCountBefore + 1)
        #expect(viewModel.document.history.count == historyCountBefore + 1)
        #expect(
            viewModel.document.history.last?.title
                == L10n.text("imageEditor.history.figmaComponentPropertyOverridesResetAll")
        )
        #expect(
            viewModel.statusText
                == L10n.format("imageEditor.status.figmaComponentPropertyOverridesResetAll", 3)
        )

        viewModel.undo()
        #expect(viewModel.selectedLayerFigmaComponentProperties == propertiesBefore)
        #expect(viewModel.document.layers[1].textContent?.text == "Buy now")
        #expect(viewModel.document.layers[2].textContent?.text == "Maybe later")
        viewModel.redo()
        #expect(viewModel.selectedLayerFigmaComponentProperties["Variant"] == variantDefault)
        #expect(viewModel.document.layers[1].textContent?.text == "Continue")
        #expect(viewModel.document.layers[2].textContent?.text == "Cancel")
    }

    @Test func resettingAllComponentPropertyOverridesUsesSortedTextConsumptionAndNoOpsCleanly() throws {
        let image = NSImage.transparent(size: CGSize(width: 120, height: 60))
        var document = ImageEditorDocument(sourceName: "figma-reset-all-order.png", image: image)
        var component = ImageEditorLayer.group(name: "Button", size: image.size)
        component.xomoFigmaComponentProperties = [
            "Z Label": XomoFigmaComponentProperty(type: "TEXT", value: "Shared"),
            "A Label": XomoFigmaComponentProperty(type: "TEXT", value: "Shared"),
            "Custom": XomoFigmaComponentProperty(type: "TEXT", value: "Untouched")
        ]
        component.xomoFigmaComponentPropertyDefaults = [
            "Z Label": XomoFigmaComponentProperty(type: "TEXT", value: "Zulu"),
            "A Label": XomoFigmaComponentProperty(type: "TEXT", value: "Alpha")
        ]
        var label = ImageEditorLayer.text(
            name: "Shared",
            origin: .zero,
            content: ImageEditorTextContent(
                text: "Shared",
                color: .white,
                fontSize: 14,
                point: CGPoint(
                    x: ImageEditorTextContent.drawingPadding,
                    y: ImageEditorTextContent.drawingPadding
                )
            )
        )
        label.groupID = component.id
        document.layers = [component, label]
        document.selectedLayerID = component.id
        document.selectedLayerIDs = [component.id]

        let viewModel = ImageEditorViewModel(document: document) { _ in }
        viewModel.resetAllSelectedFigmaComponentPropertyOverrides()
        #expect(viewModel.document.layers[1].textContent?.text == "Alpha")
        #expect(viewModel.selectedLayerFigmaComponentProperties["Custom"]?.value == "Untouched")

        let statusBefore = viewModel.statusText
        let historyBefore = viewModel.document.history
        let undoCountBefore = viewModel.undoStack.count
        let redoCountBefore = viewModel.redoStack.count
        viewModel.resetAllSelectedFigmaComponentPropertyOverrides()
        #expect(viewModel.statusText == statusBefore)
        #expect(viewModel.document.history == historyBefore)
        #expect(viewModel.undoStack.count == undoCountBefore)
        #expect(viewModel.redoStack.count == redoCountBefore)
    }

    @Test func componentPropertyOverrideInspectorExposesLocalizedFilterAndEmptyState() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("selectedLayerFigmaComponentPropertyOverrideCount"))
        #expect(source.contains("selectedLayerFigmaComponentPropertyFilterResult"))
        #expect(source.contains("imageEditor.properties.figmaComponentPropertyOverrideCount"))
        #expect(source.contains("imageEditor.properties.figmaComponentPropertyOverridesOnly"))
        #expect(source.contains("imageEditor.properties.figmaComponentPropertyHealthSummary"))
        #expect(source.contains("imageEditor.properties.figmaComponentPropertyDiagnosticsOnly"))
        #expect(source.contains("imageEditor.properties.figmaComponentPropertySearchPlaceholder"))
        #expect(source.contains("imageEditor.properties.figmaComponentPropertySearchClear"))
        #expect(source.contains("imageEditor.properties.figmaComponentPropertyFilterSummary"))
        #expect(source.contains("imageEditor.properties.figmaComponentPropertyFiltersClear"))
        #expect(source.contains("imageEditor.properties.figmaComponentPropertyFiltersEmpty"))
        #expect(source.contains("imageEditor.properties.figmaComponentPropertyResetAll"))
        #expect(source.contains("image-editor-figma-component-override-summary"))
        #expect(source.contains("image-editor-figma-component-overrides-only"))
        #expect(source.contains("image-editor-figma-component-property-health-summary"))
        #expect(source.contains("image-editor-figma-component-diagnostics-only"))
        #expect(source.contains("image-editor-figma-component-property-search"))
        #expect(source.contains("image-editor-figma-component-property-search-clear"))
        #expect(source.contains("image-editor-figma-component-property-filter-summary"))
        #expect(source.contains("image-editor-figma-component-property-filters-clear"))
        #expect(source.contains("image-editor-figma-component-property-filters-empty"))
        #expect(source.contains("image-editor-figma-component-reset-all"))
        #expect(source.contains("image-editor-copy-figma-component-property-overrides"))
        #expect(source.contains("image-editor-paste-figma-component-property-overrides"))
        #expect(source.contains("imageEditor.action.pasteFigmaComponentPropertyOverrides"))
        #expect(source.contains("viewModel.pasteSelectedFigmaComponentPropertyOverrides()"))
        #expect(source.contains("@State private var figmaComponentPropertySearchQuery = \"\""))
        #expect(source.contains("onlyDiagnostics: showsOnlyFigmaComponentPropertyDiagnostics"))
        #expect(source.contains("searchQuery: figmaComponentPropertySearchQuery"))
        #expect(source.contains("figmaComponentPropertySearchQuery = \"\""))
        #expect(source.contains("if figmaComponentPropertyFilterResult.isActive {"))

        let searchFieldStart = try #require(
            source.range(
                of: "TextField(\n                                L10n.text(\"imageEditor.properties.figmaComponentPropertySearchPlaceholder\")"
            )
        )
        let searchFieldTail = source[searchFieldStart.lowerBound...]
        let searchFieldEnd = try #require(
            searchFieldTail.range(of: "if !figmaComponentPropertySearchQuery.isEmpty {")
        )
        let searchFieldSource = String(searchFieldTail[..<searchFieldEnd.lowerBound])
        #expect(searchFieldSource.contains("text: $figmaComponentPropertySearchQuery"))
        #expect(searchFieldSource.contains("image-editor-figma-component-property-search"))
        #expect(!searchFieldSource.contains(".focusable(false)"))

        let clearSearchTail = searchFieldTail[searchFieldEnd.lowerBound...]
        let clearSearchEnd = try #require(
            clearSearchTail.range(of: ".padding(.horizontal, 7)")
        )
        let clearSearchSource = String(clearSearchTail[..<clearSearchEnd.lowerBound])
        #expect(clearSearchSource.contains("figmaComponentPropertySearchQuery = \"\""))
        #expect(clearSearchSource.contains("imageEditor.properties.figmaComponentPropertySearchClear"))
        #expect(clearSearchSource.contains("image-editor-figma-component-property-search-clear"))
        #expect(clearSearchSource.contains(".focusable(false)"))

        let filterSummaryStart = try #require(
            source.range(of: "if figmaComponentPropertyFilterResult.isActive {")
        )
        let filterSummaryTail = source[filterSummaryStart.lowerBound...]
        let filterSummaryEnd = try #require(
            filterSummaryTail.range(
                of: "if figmaComponentPropertyFilterResult.visibleKeys.isEmpty,"
            )
        )
        let filterSummarySource = String(filterSummaryTail[..<filterSummaryEnd.lowerBound])
        #expect(filterSummarySource.contains("imageEditor.properties.figmaComponentPropertyFilterSummary"))
        #expect(filterSummarySource.contains("figmaComponentPropertyFilterResult.visibleCount"))
        #expect(filterSummarySource.contains("figmaComponentPropertyFilterResult.totalCount"))
        #expect(filterSummarySource.contains("image-editor-figma-component-property-filter-summary"))

        let clearFiltersStart = try #require(
            filterSummarySource.range(
                of: "Button(\n                                    L10n.text(\n                                        \"imageEditor.properties.figmaComponentPropertyFiltersClear\""
            )
        )
        let clearFiltersTail = filterSummarySource[clearFiltersStart.lowerBound...]
        let clearFiltersEnd = try #require(clearFiltersTail.range(of: ".buttonStyle("))
        let clearFiltersSource = String(clearFiltersTail[..<clearFiltersEnd.lowerBound])
        #expect(clearFiltersSource.contains("showsOnlyFigmaComponentPropertyOverrides = false"))
        #expect(clearFiltersSource.contains("showsOnlyFigmaComponentPropertyDiagnostics = false"))
        #expect(clearFiltersSource.contains("figmaComponentPropertySearchQuery = \"\""))
        #expect(!clearFiltersSource.contains("viewModel."))
        #expect(filterSummarySource.contains("image-editor-figma-component-property-filters-clear"))
        #expect(filterSummarySource.contains(".focusable(false)"))

        let filteredEmptyStateStart = try #require(
            source.range(
                of: "if figmaComponentPropertyFilterResult.visibleKeys.isEmpty,\n                           figmaComponentPropertyFilterResult.isActive {"
            )
        )
        let filteredEmptyStateTail = source[filteredEmptyStateStart.lowerBound...]
        let filteredEmptyStateEnd = try #require(
            filteredEmptyStateTail.range(
                of: "ForEach(figmaComponentPropertyFilterResult.visibleKeys, id: \\.self)"
            )
        )
        let filteredEmptyStateSource = String(
            filteredEmptyStateTail[..<filteredEmptyStateEnd.lowerBound]
        )
        #expect(filteredEmptyStateSource.contains("figmaComponentPropertyFilterResult.visibleKeys.isEmpty"))
        #expect(filteredEmptyStateSource.contains("figmaComponentPropertyFilterResult.isActive"))
        #expect(filteredEmptyStateSource.contains("imageEditor.properties.figmaComponentPropertyFiltersEmpty"))
        #expect(filteredEmptyStateSource.contains("image-editor-figma-component-property-filters-empty"))
        #expect(
            source.contains("ForEach(figmaComponentPropertyFilterResult.visibleKeys, id: \\.self)")
        )

        let pasteOverridesStart = try #require(
            source.range(
                of: "Button(L10n.text(\"imageEditor.action.pasteFigmaComponentPropertyOverrides\"))"
            )
        )
        let pasteOverridesTail = source[pasteOverridesStart.lowerBound...]
        let pasteOverridesEnd = try #require(
            pasteOverridesTail.range(
                of: "Button(L10n.text(\"imageEditor.action.copyFigmaComponentProperties\"))"
            )
        )
        let pasteOverridesSource = String(pasteOverridesTail[..<pasteOverridesEnd.lowerBound])
        #expect(pasteOverridesSource.contains(".disabled(!viewModel.canEditSelectedFigmaComponentProperties)"))
        #expect(pasteOverridesSource.contains(".focusable(false)"))
        #expect(!pasteOverridesSource.contains("figmaComponentPropertySearchQuery"))

        let resetAllStart = try #require(
            source.range(
                of: "if viewModel.selectedLayerFigmaComponentPropertyOverrideCount > 0 {"
            )
        )
        let resetAllTail = source[resetAllStart.lowerBound...]
        let resetAllEnd = try #require(
            resetAllTail.range(
                of: "Toggle(\n                                L10n.text(\"imageEditor.properties.figmaComponentPropertyOverridesOnly\")"
            )
        )
        let resetAllSource = String(resetAllTail[..<resetAllEnd.lowerBound])
        #expect(resetAllSource.contains("imageEditor.action.copyFigmaComponentPropertyOverrides"))
        #expect(resetAllSource.contains("viewModel.copySelectedFigmaComponentPropertyOverrides()"))
        #expect(resetAllSource.contains("image-editor-copy-figma-component-property-overrides"))
        #expect(resetAllSource.contains("imageEditor.properties.figmaComponentPropertyResetAll"))
        #expect(resetAllSource.contains("viewModel.resetAllSelectedFigmaComponentPropertyOverrides()"))
        #expect(resetAllSource.contains("image-editor-figma-component-reset-all"))
        #expect(resetAllSource.contains(".disabled(!viewModel.canEditSelectedFigmaComponentProperties)"))
        #expect(resetAllSource.contains(".focusable(false)"))
        let copyOverridesStart = try #require(
            resetAllSource.range(
                of: "Button(L10n.text(\"imageEditor.action.copyFigmaComponentPropertyOverrides\"))"
            )
        )
        let copyOverridesTail = resetAllSource[copyOverridesStart.lowerBound...]
        let copyOverridesEnd = try #require(
            copyOverridesTail.range(
                of: "Button(L10n.text(\"imageEditor.properties.figmaComponentPropertyResetAll\"))"
            )
        )
        let copyOverridesSource = String(copyOverridesTail[..<copyOverridesEnd.lowerBound])
        #expect(!copyOverridesSource.contains("showsOnlyFigmaComponentPropertyOverrides"))
        #expect(!copyOverridesSource.contains("figmaComponentPropertySearchQuery"))
        #expect(!copyOverridesSource.contains("canEditSelectedFigmaComponentProperties"))
        #expect(!copyOverridesSource.contains(".disabled("))

        let editorStart = try #require(source.range(of: "private func figmaComponentPropertyEditor("))
        let editorTail = source[editorStart.lowerBound...]
        let editorEnd = try #require(editorTail.range(of: "private func figmaImageFillRow("))
        let editorSource = String(editorTail[..<editorEnd.lowerBound])
        for controlIdentifier in [
            "image-editor-figma-property-reset-\\(key)",
            "image-editor-figma-property-boolean-\\(key)",
            "image-editor-figma-property-picker-\\(key)",
            "image-editor-figma-property-text-\\(key)",
            "image-editor-figma-property-read-only-\\(key)",
            "image-editor-figma-property-diagnostic-\\(key)"
        ] {
            #expect(editorSource.contains(controlIdentifier))
        }
        #expect(
            editorSource.components(
                separatedBy: ".disabled(!viewModel.canEditSelectedFigmaComponentProperties)"
            ).count - 1 == 3
        )
        #expect(editorSource.contains("let diagnosis = property.diagnosis"))
        #expect(editorSource.contains("switch diagnosis.editor"))
        #expect(editorSource.contains("Binding<String?>"))
        #expect(editorSource.contains("get: { diagnosis.selectionKey }"))
        #expect(editorSource.contains("Text(property.value).tag(Optional<String>.none)"))
        #expect(editorSource.contains("property.displayName(for: preferredValue)"))
        #expect(
            editorSource.contains(
                "!viewModel.canEditSelectedFigmaComponentProperties || !diagnosis.writable"
            )
        )
        for localizationDirectory in ["en.lproj", "zh-Hans.lproj", "ja.lproj"] {
            let localization = try String(
                contentsOf: repositoryRoot
                    .appendingPathComponent("veilpic")
                    .appendingPathComponent(localizationDirectory)
                    .appendingPathComponent("Localizable.strings"),
                encoding: .utf8
            )
            #expect(localization.contains("\"imageEditor.properties.figmaComponentPropertyOverrideCount\""))
            #expect(localization.contains("\"imageEditor.properties.figmaComponentPropertyOverridesOnly\""))
            #expect(localization.contains("\"imageEditor.properties.figmaComponentPropertyHealthSummary\""))
            #expect(localization.contains("\"imageEditor.properties.figmaComponentPropertyDiagnosticsOnly\""))
            #expect(localization.contains("\"imageEditor.properties.figmaComponentPropertySearchPlaceholder\""))
            #expect(localization.contains("\"imageEditor.properties.figmaComponentPropertySearchClear\""))
            #expect(localization.contains("\"imageEditor.properties.figmaComponentPropertyFilterSummary\""))
            #expect(localization.contains("\"imageEditor.properties.figmaComponentPropertyFiltersClear\""))
            #expect(localization.contains("\"imageEditor.properties.figmaComponentPropertyFiltersEmpty\""))
            #expect(localization.contains("\"imageEditor.properties.figmaComponentPropertyResetAll\""))
            #expect(localization.contains("\"imageEditor.action.copyFigmaComponentPropertyOverrides\""))
            #expect(localization.contains("\"imageEditor.action.pasteFigmaComponentPropertyOverrides\""))
            #expect(localization.contains("\"imageEditor.status.figmaComponentPropertyOverridesCopied\""))
            #expect(localization.contains("\"imageEditor.history.figmaComponentPropertyOverridesPasted\""))
            #expect(localization.contains("\"imageEditor.status.figmaComponentPropertyOverridesPasted\""))
            #expect(localization.contains("\"imageEditor.status.figmaComponentPropertyOverridesPasteNoChanges\""))
            #expect(localization.contains("\"imageEditor.status.figmaComponentPropertyOverridesPasteInvalid\""))
            #expect(localization.contains("\"imageEditor.status.figmaComponentPropertyOverridesPasteIncompatible\""))
            #expect(localization.contains("\"imageEditor.status.figmaComponentPropertyInvalidValue\""))
            #expect(localization.contains("\"imageEditor.history.figmaComponentPropertyOverridesResetAll\""))
            #expect(localization.contains("\"imageEditor.status.figmaComponentPropertyOverridesResetAll\""))
        }
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
        layer.isLocked = false
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

    @Test func pixelAndAncestorLocksBlockEveryEditableFigmaImageFillControl() throws {
        let image = NSImage.transparent(size: CGSize(width: 40, height: 20))
        var document = ImageEditorDocument(sourceName: "locked-figma-fill.png", image: image)
        var group = ImageEditorLayer.group(name: "Locked Group", size: image.size)
        group.locksPixels = true
        var layer = document.layers[0]
        layer.groupID = group.id
        layer.xomoFigmaImageFill = XomoFigmaImageFillMetadata(
            imageReference: "img-ref-locked",
            scaleMode: "CROP",
            imageTransform: nil,
            scalingFactor: 1,
            rotation: 0,
            filters: XomoFigmaPlanImageFilters(),
            sourcePixelSize: XomoFigmaPlanSize(width: 40, height: 20),
            importScale: 1
        )
        layer.xomoFigmaImageFillSourceImage = image
        document.layers = [layer, group]
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]

        let viewModel = ImageEditorViewModel(document: document) { _ in }
        let historyCount = viewModel.document.history.count
        #expect(!viewModel.canEditSelectedFigmaImageFill)

        viewModel.updateSelectedFigmaImageFillScaleMode("TILE")
        viewModel.updateSelectedFigmaImageFillScalingFactor(2)
        viewModel.updateSelectedFigmaImageFillRotation(45)
        viewModel.updateSelectedFigmaImageFillOffsetX(0.25)
        viewModel.updateSelectedFigmaImageFillOffsetY(-0.15)
        viewModel.updateSelectedFigmaImageFillMatrixM11(0.8)
        viewModel.updateSelectedFigmaImageFillMatrixM12(0.25)
        viewModel.updateSelectedFigmaImageFillMatrixM21(-0.1)
        viewModel.updateSelectedFigmaImageFillMatrixM22(0.9)
        viewModel.setSelectedFigmaImageFillFiltersEnabled(false)

        let lockedFill = try #require(viewModel.selectedLayerFigmaImageFill)
        #expect(lockedFill.scaleMode == "CROP")
        #expect(lockedFill.scalingFactor == 1)
        #expect(lockedFill.rotation == 0)
        #expect(lockedFill.imageTransform == nil)
        #expect(viewModel.selectedLayerFigmaImageFillFiltersEnabled)
        #expect(viewModel.document.history.count == historyCount)

        let groupIndex = try #require(viewModel.document.layers.firstIndex { $0.id == group.id })
        let layerIndex = try #require(viewModel.document.layers.firstIndex { $0.id == layer.id })
        viewModel.document.layers[groupIndex].locksPixels = false
        viewModel.document.layers[layerIndex].isLocked = true
        #expect(!viewModel.canEditSelectedFigmaImageFill)
        viewModel.updateSelectedFigmaImageFillScaleMode("FIT")
        #expect(viewModel.selectedLayerFigmaImageFill?.scaleMode == "CROP")
        #expect(viewModel.document.history.count == historyCount)
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
        viewModel.document.layers[layerIndex].isLocked = false

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

        viewModel.document.layers[layerIndex].locksPixels = true
        let historyCount = viewModel.document.history.count
        let lockedList = registry.execute(request(
            operation: "call",
            name: "xomo.figma.image_fill",
            arguments: ["action": .string("list")]
        ))
        #expect(lockedList.ok)
        #expect(lockedList.result?.objectValue?["editable"] == .bool(false))
        let lockedUpdate = registry.execute(request(
            operation: "call",
            name: "xomo.figma.image_fill",
            arguments: [
                "action": .string("set"),
                "property": .string("scaleMode"),
                "scaleMode": .string("FIT")
            ]
        ))
        #expect(!lockedUpdate.ok)
        #expect(lockedUpdate.error?.contains("locked") == true)
        #expect(viewModel.selectedLayerFigmaImageFill?.scaleMode == "CROP")
        #expect(viewModel.document.history.count == historyCount)
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

    @Test func figmaSizeConstraintSourcePresentationDistinguishesUnsetLocalAndImportedValues() throws {
        let image = NSImage.transparent(size: CGSize(width: 20, height: 20))
        var document = ImageEditorDocument(sourceName: "figma-size-source-presentation.png", image: image)
        var layer = document.layers[0]
        layer.xomoFigmaSizeConstraints = XomoFigmaSizeConstraints(
            minWidth: 120,
            maxWidth: 240,
            minHeight: 80,
            maxHeight: nil
        )
        layer.xomoFigmaSizeConstraintDefaults = XomoFigmaSizeConstraints(
            minWidth: 120,
            maxWidth: 200,
            minHeight: 80,
            maxHeight: nil
        )
        document.layers = [layer]
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]
        let viewModel = ImageEditorViewModel(document: document) { _ in }

        #expect(
            viewModel.selectedLayerFigmaSizeConstraintSourcePresentation(.minWidth)
                == .importedDefault
        )
        #expect(
            viewModel.selectedLayerFigmaSizeConstraintSourcePresentation(.maxWidth)
                == .overridden
        )
        #expect(
            viewModel.selectedLayerFigmaSizeConstraintSourcePresentation(.minHeight)
                == .importedDefault
        )
        #expect(
            viewModel.selectedLayerFigmaSizeConstraintSourcePresentation(.maxHeight)
                == .importedDefault
        )
        #expect(viewModel.hasSelectedFigmaSizeConstraintOverrides)

        let propertiesBefore = viewModel.selectedLayerFigmaSizeConstraints
        let defaultsBefore = viewModel.selectedLayerFigmaSizeConstraintDefaults
        let historyBefore = viewModel.document.history
        let statusBefore = viewModel.statusText
        let undoBefore = viewModel.undoStack
        let redoBefore = viewModel.redoStack
        for field in XomoFigmaSizeConstraintField.allCases {
            _ = viewModel.selectedLayerFigmaSizeConstraintSourcePresentation(field)
        }
        #expect(viewModel.selectedLayerFigmaSizeConstraints == propertiesBefore)
        #expect(viewModel.selectedLayerFigmaSizeConstraintDefaults == defaultsBefore)
        #expect(viewModel.document.history == historyBefore)
        #expect(viewModel.statusText == statusBefore)
        #expect(viewModel.undoStack.count == undoBefore.count)
        #expect(viewModel.redoStack.count == redoBefore.count)

        var localOnlyDocument = ImageEditorDocument(
            sourceName: "figma-size-local-only.png",
            image: image
        )
        var localOnlyLayer = localOnlyDocument.layers[0]
        localOnlyLayer.xomoFigmaSizeConstraints = XomoFigmaSizeConstraints(
            minWidth: 64,
            maxWidth: nil,
            minHeight: nil,
            maxHeight: nil
        )
        localOnlyLayer.xomoFigmaSizeConstraintDefaults = nil
        localOnlyDocument.layers = [localOnlyLayer]
        localOnlyDocument.selectedLayerID = localOnlyLayer.id
        localOnlyDocument.selectedLayerIDs = [localOnlyLayer.id]
        let localOnlyViewModel = ImageEditorViewModel(document: localOnlyDocument) { _ in }
        #expect(
            localOnlyViewModel.selectedLayerFigmaSizeConstraintSourcePresentation(.minWidth)
                == .localOnly
        )
        #expect(
            localOnlyViewModel.selectedLayerFigmaSizeConstraintSourcePresentation(.maxWidth)
                == .unset
        )
        #expect(!localOnlyViewModel.hasSelectedFigmaSizeConstraintOverrides)

        var emptyDocument = ImageEditorDocument(sourceName: "figma-size-unset.png", image: image)
        var emptyLayer = emptyDocument.layers[0]
        emptyLayer.xomoFigmaSizeConstraints = nil
        emptyLayer.xomoFigmaSizeConstraintDefaults = nil
        emptyDocument.layers = [emptyLayer]
        emptyDocument.selectedLayerID = emptyLayer.id
        emptyDocument.selectedLayerIDs = [emptyLayer.id]
        let emptyViewModel = ImageEditorViewModel(document: emptyDocument) { _ in }
        for field in XomoFigmaSizeConstraintField.allCases {
            #expect(
                emptyViewModel.selectedLayerFigmaSizeConstraintSourcePresentation(field)
                    == .unset
            )
        }

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        #expect(source.contains("figmaSizeConstraintSourceBadge("))
        #expect(source.contains("viewModel.selectedLayerFigmaSizeConstraintSourcePresentation(field)"))
        #expect(source.contains("image-editor-figma-size-constraint-\\(field.rawValue)-source"))
        let badgeStart = try #require(source.range(of: "private func figmaSizeConstraintSourceBadge("))
        let badgeEnd = try #require(
            source.range(of: "\n    private var adjustmentValueControls", range: badgeStart.upperBound..<source.endIndex)
        )
        let badgeSource = source[badgeStart.lowerBound..<badgeEnd.lowerBound]
        #expect(badgeSource.contains("Capsule()"))
        #expect(badgeSource.contains(".focusable(false)"))
        #expect(!badgeSource.contains("Button"))
        #expect(!badgeSource.contains("Binding"))
        #expect(!badgeSource.contains("viewModel"))
        #expect(!badgeSource.contains("setSelected"))
        #expect(!badgeSource.contains("resetSelected"))

        let localizationExpectations: [(String, [(String, String)])] = [
            (
                "veilpic/en.lproj/Localizable.strings",
                [
                    ("imageEditor.properties.figmaSizeConstraintSource.importedDefault", "Imported default"),
                    ("imageEditor.properties.figmaSizeConstraintSource.overridden", "Overridden"),
                    ("imageEditor.properties.figmaSizeConstraintSource.localOnly", "Local only"),
                    ("imageEditor.properties.figmaSizeConstraintSource.unset", "Unset")
                ]
            ),
            (
                "veilpic/zh-Hans.lproj/Localizable.strings",
                [
                    ("imageEditor.properties.figmaSizeConstraintSource.importedDefault", "导入默认值"),
                    ("imageEditor.properties.figmaSizeConstraintSource.overridden", "已覆盖"),
                    ("imageEditor.properties.figmaSizeConstraintSource.localOnly", "仅本地"),
                    ("imageEditor.properties.figmaSizeConstraintSource.unset", "未设置")
                ]
            ),
            (
                "veilpic/ja.lproj/Localizable.strings",
                [
                    ("imageEditor.properties.figmaSizeConstraintSource.importedDefault", "インポートされたデフォルト"),
                    ("imageEditor.properties.figmaSizeConstraintSource.overridden", "上書き済み"),
                    ("imageEditor.properties.figmaSizeConstraintSource.localOnly", "ローカルのみ"),
                    ("imageEditor.properties.figmaSizeConstraintSource.unset", "未設定")
                ]
            )
        ]
        for (path, entries) in localizationExpectations {
            let localization = try String(
                contentsOf: repositoryRoot.appendingPathComponent(path),
                encoding: .utf8
            )
            for (key, value) in entries {
                #expect(localization.contains("\"\(key)\" = \"\(value)\";"))
            }
        }
    }

    @Test func figmaSizeConstraintInspectorUsesDraftedLocalizedEditors() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("viewModel.selectedLayerFigmaSizeConstraints"))
        #expect(source.contains("image-editor-figma-size-constraints"))
        #expect(source.contains("ForEach(XomoFigmaSizeConstraintField.allCases"))
        #expect(source.contains("figmaSizeConstraintEditorRow(field)"))
        #expect(source.contains("figmaSizeConstraintDraftBinding(field)"))
        #expect(source.contains("commitFigmaSizeConstraintDraft(field)"))
        #expect(source.contains("viewModel.setSelectedFigmaSizeConstraint(field, value: nil)"))
        #expect(source.contains("viewModel.hasSelectedFigmaSizeConstraintOverride(field)"))
        #expect(source.contains("viewModel.selectedLayerFigmaSizeConstraintSourcePresentation(field)"))
        #expect(source.contains("image-editor-figma-size-constraint-\\(field.rawValue)-source"))
        #expect(source.contains("viewModel.resetSelectedFigmaSizeConstraint(field)"))
        #expect(source.contains("image-editor-figma-size-constraint-\\(field.rawValue)-field"))
        #expect(source.contains("image-editor-figma-size-constraint-\\(field.rawValue)-clear"))
        #expect(source.contains("image-editor-figma-size-constraint-\\(field.rawValue)-reset"))
        #expect(source.contains("imageEditor.action.resetFigmaSizeConstraint"))
        #expect(source.contains("viewModel.hasSelectedFigmaSizeConstraintOverrides"))
        #expect(source.contains("viewModel.resetAllSelectedFigmaSizeConstraints()"))
        #expect(source.contains("image-editor-figma-size-constraints-reset-all"))
        #expect(source.contains("imageEditor.action.resetAllFigmaSizeConstraints"))
        #expect(source.contains("viewModel.selectedLayerFigmaSizeConstraintConflicts"))
        #expect(source.contains("image-editor-figma-size-constraint-conflict-\\(conflict.rawValue)"))
        #expect(source.contains("L10n.text(conflict.localizationKey)"))
        #expect(source.contains("viewModel.resolveSelectedFigmaSizeConstraintConflict(conflict)"))
        #expect(source.contains("image-editor-figma-size-constraint-conflict-\\(conflict.rawValue)-resolve"))
        #expect(source.contains("imageEditor.action.resolveFigmaSizeConstraintConflict"))
        #expect(source.contains("viewModel.resolveAllSelectedFigmaSizeConstraintConflicts()"))
        #expect(source.contains("image-editor-figma-size-constraint-conflicts-resolve-all"))
        #expect(source.contains("imageEditor.action.resolveAllFigmaSizeConstraintConflicts"))
        #expect(source.contains("focusedFigmaSizeConstraintField"))
        #expect(source.contains("imageEditor.properties.figmaSizeConstraintsActive"))
        #expect(source.contains(".focusable(false)"))
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
