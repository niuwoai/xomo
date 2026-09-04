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
        #expect(source.contains("selectedLayerFigmaComponentPropertyKeys"))
        #expect(source.contains("imageEditor.properties.figmaComponentPropertyOverrideCount"))
        #expect(source.contains("imageEditor.properties.figmaComponentPropertyOverridesOnly"))
        #expect(source.contains("imageEditor.properties.figmaComponentPropertyOverridesEmpty"))
        #expect(source.contains("imageEditor.properties.figmaComponentPropertyResetAll"))
        #expect(source.contains("image-editor-figma-component-override-summary"))
        #expect(source.contains("image-editor-figma-component-overrides-only"))
        #expect(source.contains("image-editor-figma-component-overrides-empty"))
        #expect(source.contains("image-editor-figma-component-reset-all"))

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
        #expect(resetAllSource.contains("imageEditor.properties.figmaComponentPropertyResetAll"))
        #expect(resetAllSource.contains("viewModel.resetAllSelectedFigmaComponentPropertyOverrides()"))
        #expect(resetAllSource.contains("image-editor-figma-component-reset-all"))
        #expect(resetAllSource.contains(".disabled(!viewModel.canEditSelectedFigmaComponentProperties)"))
        #expect(resetAllSource.contains(".focusable(false)"))

        let editorStart = try #require(source.range(of: "private func figmaComponentPropertyEditor("))
        let editorTail = source[editorStart.lowerBound...]
        let editorEnd = try #require(editorTail.range(of: "private func figmaImageFillRow("))
        let editorSource = String(editorTail[..<editorEnd.lowerBound])
        for controlIdentifier in [
            "image-editor-figma-property-reset-\\(key)",
            "image-editor-figma-property-boolean-\\(key)",
            "image-editor-figma-property-picker-\\(key)",
            "image-editor-figma-property-text-\\(key)"
        ] {
            #expect(editorSource.contains(controlIdentifier))
        }
        #expect(
            editorSource.components(
                separatedBy: ".disabled(!viewModel.canEditSelectedFigmaComponentProperties)"
            ).count - 1 == 4
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
            #expect(localization.contains("\"imageEditor.properties.figmaComponentPropertyOverridesEmpty\""))
            #expect(localization.contains("\"imageEditor.properties.figmaComponentPropertyResetAll\""))
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
