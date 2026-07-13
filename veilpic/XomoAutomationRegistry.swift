//
//  XomoAutomationRegistry.swift
//  veilpic
//

import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class XomoAutomationRegistry {
    static let shared = XomoAutomationRegistry()

    private weak var activeViewModel: ImageEditorViewModel?

    private init() {}

    func register(_ viewModel: ImageEditorViewModel) {
        activeViewModel = viewModel
    }

    func unregister(_ viewModel: ImageEditorViewModel) {
        guard activeViewModel === viewModel else { return }
        activeViewModel = nil
    }

    func execute(_ request: XomoAutomationWireRequest) -> XomoAutomationWireResponse {
        switch request.operation {
        case "status":
            return .success(statusResult())
        case "tools":
            return .success(.array(Self.tools.map { definition in
                .object([
                    "name": .string(definition.name),
                    "description": .string(definition.description),
                    "inputSchema": definition.inputSchema
                ])
            }))
        case "call":
            guard let name = request.name else { return .failure("Missing tool name") }
            guard let viewModel = activeViewModel else { return .failure("No active Xomo editor window") }
            do {
                return .success(try call(name, arguments: request.arguments ?? [:], viewModel: viewModel))
            } catch {
                return .failure(error.localizedDescription)
            }
        default:
            return .failure("Unsupported operation: \(request.operation)")
        }
    }

    private func statusResult() -> XomoJSONValue {
        .object([
            "app": .string("Xomo"),
            "version": .string(AppVersion.current),
            "editorActive": .bool(activeViewModel != nil),
            "toolCount": .number(Double(Self.tools.count))
        ])
    }

    private func call(
        _ name: String,
        arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws -> XomoJSONValue {
        switch name {
        case "xomo.app.status":
            return statusResult()
        case "xomo.document.get":
            return documentResult(viewModel)
        case "xomo.document.create":
            try createDocument(arguments, viewModel: viewModel)
        case "xomo.project.export":
            return try projectExportResult(viewModel)
        case "xomo.project.import":
            try importProject(arguments, viewModel: viewModel)
        case "xomo.import.image":
            try importImage(arguments, viewModel: viewModel)
        case "xomo.tool.list":
            return .array(ImageEditorTool.allCases.map { tool in
                .object(["id": .string(tool.rawValue), "title": .string(tool.title)])
            })
        case "xomo.tool.select":
            let rawValue = try requiredString("tool", in: arguments)
            guard let tool = ImageEditorTool(rawValue: rawValue) else {
                throw XomoAutomationCallError.invalidArgument("Unknown tool: \(rawValue)")
            }
            viewModel.selectTool(tool)
        case "xomo.layer.list":
            return layersResult(viewModel)
        case "xomo.layer.select":
            let id = try requiredUUID("id", in: arguments)
            viewModel.selectLayer(id, extendingSelection: arguments["extend"]?.boolValue ?? false)
        case "xomo.layer.create":
            try createLayer(arguments, viewModel: viewModel)
        case "xomo.layer.delete":
            viewModel.deleteSelectedLayer()
        case "xomo.layer.duplicate":
            viewModel.duplicateSelectedLayer()
        case "xomo.layer.rename":
            viewModel.renameSelectedLayer(to: try requiredString("name", in: arguments))
        case "xomo.layer.set_visibility":
            let id = try requiredUUID("id", in: arguments)
            let visible = try requiredBool("visible", in: arguments)
            guard let layer = viewModel.document.layers.first(where: { $0.id == id }) else {
                throw XomoAutomationCallError.notFound("Layer \(id.uuidString)")
            }
            if layer.isVisible != visible { viewModel.toggleLayerVisibility(id) }
        case "xomo.layer.set_lock":
            let id = try requiredUUID("id", in: arguments)
            let locked = try requiredBool("locked", in: arguments)
            guard let layer = viewModel.document.layers.first(where: { $0.id == id }) else {
                throw XomoAutomationCallError.notFound("Layer \(id.uuidString)")
            }
            if layer.isLocked != locked { viewModel.toggleLayerLock(id) }
        case "xomo.layer.set_opacity":
            viewModel.setSelectedLayerOpacity(try requiredNumber("opacity", in: arguments))
            viewModel.commitSelectedLayerOpacityChange()
        case "xomo.layer.set_blend_mode":
            let rawValue = try requiredString("mode", in: arguments)
            guard let mode = ImageEditorBlendMode(rawValue: rawValue) else {
                throw XomoAutomationCallError.invalidArgument("Unknown blend mode: \(rawValue)")
            }
            viewModel.setSelectedLayerBlendMode(mode)
        case "xomo.layer.nudge":
            viewModel.nudgeSelectionOrSelectedLayer(
                by: CGSize(
                    width: try requiredNumber("dx", in: arguments),
                    height: try requiredNumber("dy", in: arguments)
                )
            )
        case "xomo.layer.order":
            try reorderLayer(arguments, viewModel: viewModel)
        case "xomo.layer.group":
            viewModel.groupSelectedLayer()
        case "xomo.layer.ungroup":
            viewModel.ungroupSelectedLayers()
        case "xomo.layer.merge_down":
            viewModel.mergeSelectedLayerDown()
        case "xomo.layer.merge_selected":
            viewModel.mergeSelectedLayers()
        case "xomo.layer.merge_visible":
            viewModel.mergeVisibleLayers()
        case "xomo.layer.stamp_visible":
            viewModel.stampVisibleLayers()
        case "xomo.layer.stamp_selected":
            viewModel.stampSelectedLayers()
        case "xomo.layer.flatten":
            viewModel.flattenImage()
        case "xomo.layer.transform":
            try layerTransform(arguments, viewModel: viewModel)
        case "xomo.layer.align":
            try layerAlignment(arguments, viewModel: viewModel)
        case "xomo.layer.style":
            try layerStyleAction(arguments, viewModel: viewModel)
        case "xomo.layer.style_settings":
            try layerStyleSetting(arguments, viewModel: viewModel)
        case "xomo.layer.selection":
            try layerSelectionAction(arguments, viewModel: viewModel)
        case "xomo.layer.link":
            try layerLinkAction(arguments, viewModel: viewModel)
        case "xomo.layer.smart_object":
            try smartObjectAction(arguments, viewModel: viewModel)
        case "xomo.layer.properties":
            try layerProperties(arguments, viewModel: viewModel)
        case "xomo.layer.action":
            try layerGeneralAction(arguments, viewModel: viewModel)
        case "xomo.layer_comp.list":
            return layerCompsResult(viewModel)
        case "xomo.layer_comp.action":
            try layerCompAction(arguments, viewModel: viewModel)
        case "xomo.selection.get":
            return selectionResult(viewModel)
        case "xomo.selection.all":
            viewModel.selectAll()
        case "xomo.selection.rectangle":
            viewModel.createRectSelection(
                from: CGPoint(
                    x: try requiredNumber("x", in: arguments),
                    y: try requiredNumber("y", in: arguments)
                ),
                to: CGPoint(
                    x: try requiredNumber("x", in: arguments) + requiredNumber("width", in: arguments),
                    y: try requiredNumber("y", in: arguments) + requiredNumber("height", in: arguments)
                )
            )
        case "xomo.selection.ellipse":
            viewModel.selectMarqueeShape(.ellipse)
            viewModel.createMarqueeSelection(
                from: CGPoint(
                    x: try requiredNumber("x", in: arguments),
                    y: try requiredNumber("y", in: arguments)
                ),
                to: CGPoint(
                    x: try requiredNumber("x", in: arguments) + requiredNumber("width", in: arguments),
                    y: try requiredNumber("y", in: arguments) + requiredNumber("height", in: arguments)
                )
            )
        case "xomo.selection.lasso":
            viewModel.createLassoSelection(points: try requiredPoints("points", in: arguments))
        case "xomo.selection.magic":
            viewModel.createMagicSelection(at: try requiredPoint(arguments))
        case "xomo.selection.quick":
            viewModel.createQuickSelection(points: try requiredPoints("points", in: arguments))
        case "xomo.selection.clear":
            viewModel.clearSelection()
        case "xomo.selection.invert":
            viewModel.invertSelection()
        case "xomo.selection.feather":
            if let radius = arguments["radius"]?.doubleValue { viewModel.feather = radius }
            viewModel.featherSelection()
        case "xomo.selection.smooth":
            viewModel.smoothSelection()
        case "xomo.selection.edit":
            try selectionEdit(arguments, viewModel: viewModel)
        case "xomo.selection.modify":
            try selectionModify(arguments, viewModel: viewModel)
        case "xomo.clipboard.action":
            try clipboardAction(arguments, viewModel: viewModel)
        case "xomo.channel.list":
            return channelsResult(viewModel)
        case "xomo.channel.create":
            viewModel.createBlankAlphaChannel()
        case "xomo.channel.select":
            viewModel.selectAlphaChannel(try requiredUUID("id", in: arguments))
        case "xomo.channel.rename":
            viewModel.renameAlphaChannel(
                try requiredUUID("id", in: arguments),
                to: try requiredString("name", in: arguments)
            )
        case "xomo.channel.delete":
            viewModel.deleteAlphaChannel(try requiredUUID("id", in: arguments))
        case "xomo.channel.duplicate":
            viewModel.duplicateAlphaChannel(try requiredUUID("id", in: arguments))
        case "xomo.channel.action":
            try channelAction(arguments, viewModel: viewModel)
        case "xomo.history.list":
            return historyResult(viewModel)
        case "xomo.history.undo":
            viewModel.undo()
        case "xomo.history.redo":
            viewModel.redo()
        case "xomo.history.restore":
            viewModel.restoreHistoryEntry(try requiredUUID("id", in: arguments))
        case "xomo.history.snapshot_list":
            return historySnapshotsResult(viewModel)
        case "xomo.history.action":
            try historyAction(arguments, viewModel: viewModel)
        case "xomo.canvas.resize_image":
            viewModel.resizeImage(
                to: CGSize(
                    width: try requiredNumber("width", in: arguments),
                    height: try requiredNumber("height", in: arguments)
                )
            )
        case "xomo.canvas.resize_canvas":
            let anchorRaw = arguments["anchor"]?.stringValue ?? ImageEditorCanvasAnchor.center.rawValue
            guard let anchor = ImageEditorCanvasAnchor(rawValue: anchorRaw) else {
                throw XomoAutomationCallError.invalidArgument("Unknown canvas anchor: \(anchorRaw)")
            }
            viewModel.resizeCanvas(
                to: CGSize(
                    width: try requiredNumber("width", in: arguments),
                    height: try requiredNumber("height", in: arguments)
                ),
                anchor: anchor
            )
        case "xomo.canvas.crop_to_selection":
            viewModel.cropToSelection()
        case "xomo.canvas.transform":
            try canvasTransform(arguments, viewModel: viewModel)
        case "xomo.component.list":
            return componentsResult()
        case "xomo.component.insert":
            try insertComponent(arguments, viewModel: viewModel)
        case "xomo.color.get":
            return colorResult(viewModel)
        case "xomo.color.set":
            try setColor(arguments, viewModel: viewModel)
        case "xomo.color.swap":
            viewModel.swapForegroundBackgroundColors()
        case "xomo.color.reset":
            viewModel.resetForegroundBackgroundColors()
        case "xomo.brush.preset":
            return try brushPresetAction(arguments, viewModel: viewModel)
        case "xomo.paint.stroke":
            try paintStroke(arguments, viewModel: viewModel)
        case "xomo.paint.gradient":
            let points = try requiredPoints("points", in: arguments)
            guard points.count == 2 else {
                throw XomoAutomationCallError.invalidArgument("Gradient requires exactly two points")
            }
            viewModel.drawGradient(from: points[0], to: points[1])
        case "xomo.paint.special":
            try specialPaint(arguments, viewModel: viewModel)
        case "xomo.shape.create":
            let origin = try requiredPoint(arguments)
            let end = CGPoint(
                x: origin.x + (try requiredNumber("width", in: arguments)),
                y: origin.y + (try requiredNumber("height", in: arguments))
            )
            viewModel.drawShape(
                from: origin,
                to: end,
                ellipse: arguments["kind"]?.stringValue == "ellipse"
            )
        case "xomo.shape.get":
            return shapeResult(viewModel)
        case "xomo.shape.update":
            try updateShape(arguments, viewModel: viewModel)
        case "xomo.text.create":
            viewModel.textValue = try requiredString("text", in: arguments)
            if let fontSize = arguments["fontSize"]?.doubleValue { viewModel.textSize = fontSize }
            viewModel.textBoxWidth = arguments["boxWidth"]?.doubleValue ?? 0
            viewModel.textBoxHeight = arguments["boxHeight"]?.doubleValue ?? 0
            viewModel.addText(at: optionalPoint(arguments))
        case "xomo.text.get":
            return textResult(viewModel)
        case "xomo.text.update":
            try updateText(arguments, viewModel: viewModel)
        case "xomo.text.convert":
            let rawValue = try requiredString("mode", in: arguments)
            guard let layoutMode = ImageEditorTextLayoutMode(rawValue: rawValue) else {
                throw XomoAutomationCallError.invalidArgument("Unknown text layout mode: \(rawValue)")
            }
            viewModel.convertSelectedTextLayers(to: layoutMode)
        case "xomo.text.fitBox":
            let rawValue = try requiredString("mode", in: arguments)
            guard let fitMode = ImageEditorTextBoxFitMode(rawValue: rawValue) else {
                throw XomoAutomationCallError.invalidArgument("Unknown text box fit mode: \(rawValue)")
            }
            viewModel.fitSelectedTextBoxes(fitMode)
        case "xomo.mask.action":
            try maskAction(arguments, viewModel: viewModel)
        case "xomo.path.get":
            return pathResult(viewModel)
        case "xomo.path.action":
            try pathAction(arguments, viewModel: viewModel)
        case "xomo.layer.effect":
            try layerEffect(arguments, viewModel: viewModel)
        case "xomo.guide.list":
            return guidesResult(viewModel)
        case "xomo.guide.add":
            let orientation = try requiredString("orientation", in: arguments)
            guard let guideOrientation = ImageEditorGuideOrientation(rawValue: orientation) else {
                throw XomoAutomationCallError.invalidArgument("Unknown guide orientation")
            }
            viewModel.addGuide(guideOrientation, at: try requiredNumber("position", in: arguments))
        case "xomo.guide.delete":
            viewModel.deleteGuide(try requiredUUID("id", in: arguments))
        case "xomo.guide.clear":
            viewModel.clearGuides()
        case "xomo.guide.settings":
            try guideSettings(arguments, viewModel: viewModel)
        case "xomo.view.zoom":
            try setZoom(arguments, viewModel: viewModel)
        case "xomo.smart_filter.list":
            return smartFiltersResult(viewModel)
        case "xomo.smart_filter.add":
            let rawValue = try requiredString("filter", in: arguments)
            guard let filter = ImageEditorFilter(rawValue: rawValue) else {
                throw XomoAutomationCallError.invalidArgument("Unknown filter: \(rawValue)")
            }
            viewModel.selectedFilter = filter
            if let intensity = arguments["intensity"]?.doubleValue { viewModel.filterIntensity = intensity }
            viewModel.addSmartFilterToSelectedLayer()
        case "xomo.smart_filter.toggle":
            viewModel.toggleSmartFilterOnSelectedLayer(try requiredUUID("id", in: arguments))
        case "xomo.smart_filter.clear":
            viewModel.clearSmartFiltersFromSelectedLayer()
        case "xomo.smart_filter.manage":
            try smartFilterManage(arguments, viewModel: viewModel)
        case "xomo.filter.list":
            return .array(ImageEditorFilter.allCases.map { .string($0.rawValue) })
        case "xomo.filter.apply":
            let rawValue = try requiredString("filter", in: arguments)
            guard let filter = ImageEditorFilter(rawValue: rawValue) else {
                throw XomoAutomationCallError.invalidArgument("Unknown filter: \(rawValue)")
            }
            viewModel.selectedFilter = filter
            if let intensity = arguments["intensity"]?.doubleValue { viewModel.filterIntensity = intensity }
            viewModel.applySelectedFilter()
        case "xomo.filter.configure":
            try configureFilter(arguments, viewModel: viewModel)
        case "xomo.adjustment.list":
            return .array(ImageEditorAdjustment.allCases.map { .string($0.rawValue) })
        case "xomo.adjustment.apply":
            let rawValue = try requiredString("adjustment", in: arguments)
            guard let adjustment = ImageEditorAdjustment(rawValue: rawValue) else {
                throw XomoAutomationCallError.invalidArgument("Unknown adjustment: \(rawValue)")
            }
            viewModel.selectedAdjustment = adjustment
            if let amount = arguments["amount"]?.doubleValue { viewModel.adjustmentValue = amount }
            viewModel.applyAdjustment()
        case "xomo.adjustment.configure":
            try configureAdjustment(arguments, viewModel: viewModel)
        case "xomo.export.render":
            return try exportResult(arguments, viewModel: viewModel)
        default:
            throw XomoAutomationCallError.notFound("Tool \(name)")
        }

        return actionResult(viewModel)
    }

    private func documentResult(_ viewModel: ImageEditorViewModel) -> XomoJSONValue {
        .object([
            "name": .string(viewModel.document.sourceName),
            "width": .number(viewModel.document.canvasSize.width),
            "height": .number(viewModel.document.canvasSize.height),
            "layerCount": .number(Double(viewModel.document.layers.count)),
            "alphaChannelCount": .number(Double(viewModel.document.alphaChannels.count)),
            "selectedLayerId": viewModel.document.selectedLayerID.map { .string($0.uuidString) } ?? .null,
            "tool": .string(viewModel.selectedTool.rawValue),
            "zoom": .number(viewModel.zoom),
            "status": .string(viewModel.statusText)
        ])
    }

    private func createDocument(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws {
        let preset: XomoCanvasPreset
        if let rawValue = arguments["preset"]?.stringValue {
            guard let value = XomoCanvasPreset(rawValue: rawValue) else {
                throw XomoAutomationCallError.invalidArgument("Unknown canvas preset")
            }
            preset = value
        } else {
            preset = .desktopWide
        }
        let backgroundRaw = arguments["background"]?.stringValue ?? XomoCanvasBackground.transparent.rawValue
        guard let background = XomoCanvasBackground(rawValue: backgroundRaw) else {
            throw XomoAutomationCallError.invalidArgument("Unknown canvas background")
        }
        var draft = XomoCanvasDraft(preset: preset, background: background)
        if let width = arguments["width"]?.doubleValue { draft.width = width }
        if let height = arguments["height"]?.doubleValue { draft.height = height }
        if let exportScale = arguments["exportScale"]?.doubleValue { draft.exportScale = Int(exportScale) }
        viewModel.createCanvas(from: draft)
    }

    private func projectExportResult(_ viewModel: ImageEditorViewModel) throws -> XomoJSONValue {
        let data = try viewModel.projectData()
        let base = (viewModel.document.sourceName as NSString).deletingPathExtension
        let filename = "\(base.isEmpty ? "image" : base).\(ImageEditorProjectDocument.fileExtension)"
        return .object([
            "filename": .string(filename),
            "mimeType": .string("application/json"),
            "formatVersion": .number(Double(ImageEditorProjectDocument.formatVersion)),
            "base64": .string(data.base64EncodedString())
        ])
    }

    private func importProject(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws {
        let base64 = try requiredString("base64", in: arguments)
        guard let data = Data(base64Encoded: base64) else {
            throw XomoAutomationCallError.invalidArgument("Project base64 is invalid")
        }
        do {
            try viewModel.loadProjectData(data)
        } catch {
            throw XomoAutomationCallError.operationFailed("Project import failed: \(error.localizedDescription)")
        }
    }

    private func importImage(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws {
        let base64 = try requiredString("base64", in: arguments)
        guard let data = Data(base64Encoded: base64),
              let image = NSImage(data: data)
        else { throw XomoAutomationCallError.invalidArgument("Image base64 is invalid") }
        let name = arguments["name"]?.stringValue ?? "imported-image.png"
        if arguments["intoSelection"]?.boolValue == true {
            viewModel.importImageLayerIntoSelection(image, sourceName: name)
        } else {
            viewModel.importImageLayer(image, sourceName: name)
        }
    }

    private func layersResult(_ viewModel: ImageEditorViewModel) -> XomoJSONValue {
        .array(viewModel.document.layers.reversed().map { layer in
            .object([
                "id": .string(layer.id.uuidString),
                "name": .string(layer.name),
                "kind": .string(layerKindName(layer.kind)),
                "selected": .bool(viewModel.document.selectedLayerIDs.contains(layer.id)),
                "visible": .bool(layer.isVisible),
                "locked": .bool(layer.isLocked),
                "opacity": .number(layer.opacity),
                "blendMode": .string(layer.blendMode.rawValue),
                "groupId": layer.groupID.map { .string($0.uuidString) } ?? .null,
                "x": .number(layer.frame.minX),
                "y": .number(layer.frame.minY),
                "width": .number(layer.frame.width),
                "height": .number(layer.frame.height)
            ])
        })
    }

    private func selectionResult(_ viewModel: ImageEditorViewModel) -> XomoJSONValue {
        guard let selection = viewModel.document.selection else { return .object(["active": .bool(false)]) }
        let bounds = selection.bounds.standardized
        return .object([
            "active": .bool(true),
            "inverted": .bool(selection.isInverted),
            "x": .number(bounds.minX),
            "y": .number(bounds.minY),
            "width": .number(bounds.width),
            "height": .number(bounds.height)
        ])
    }

    private func channelsResult(_ viewModel: ImageEditorViewModel) -> XomoJSONValue {
        .array(viewModel.document.alphaChannels.map { channel in
            .object([
                "id": .string(channel.id.uuidString),
                "name": .string(channel.name),
                "selected": .bool(channel.id == viewModel.selectedAlphaChannelID),
                "width": .number(Double(channel.mask.width)),
                "height": .number(Double(channel.mask.height))
            ])
        })
    }

    private func historyResult(_ viewModel: ImageEditorViewModel) -> XomoJSONValue {
        .array(viewModel.document.history.map { entry in
            .object([
                "id": .string(entry.id.uuidString),
                "title": .string(entry.title),
                "timestamp": .string(ISO8601DateFormatter().string(from: entry.createdAt)),
                "selected": .bool(entry.id == viewModel.selectedHistoryEntryID)
            ])
        })
    }

    private func historySnapshotsResult(_ viewModel: ImageEditorViewModel) -> XomoJSONValue {
        .array(viewModel.namedHistorySnapshots.map { snapshot in
            .object([
                "id": .string(snapshot.id.uuidString),
                "name": .string(snapshot.name),
                "selected": .bool(snapshot.id == viewModel.selectedHistorySnapshotID),
                "createdAt": .string(ISO8601DateFormatter().string(from: snapshot.createdAt))
            ])
        })
    }

    private func componentsResult() -> XomoJSONValue {
        .object([
            "components": .array(XomoComponentKind.allCases.map { .string($0.rawValue) }),
            "themes": .array(XomoComponentTheme.allCases.map { .string($0.rawValue) })
        ])
    }

    private func colorResult(_ viewModel: ImageEditorViewModel) -> XomoJSONValue {
        .object([
            "foreground": colorJSON(viewModel.foregroundColor),
            "background": colorJSON(viewModel.backgroundColor)
        ])
    }

    private func brushPresetAction(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws -> XomoJSONValue {
        let action = arguments["action"]?.stringValue ?? "list"
        switch action {
        case "list":
            break
        case "create":
            guard viewModel.createBrushPresetFromCurrentSettings() != nil else {
                throw XomoAutomationCallError.invalidArgument("Custom brush preset limit reached")
            }
        case "apply":
            let id = try requiredString("id", in: arguments)
            guard let preset = viewModel.brushPresets.first(where: { $0.id == id }) else {
                throw XomoAutomationCallError.notFound("Brush preset \(id)")
            }
            viewModel.applyBrushPreset(preset)
        case "delete":
            let id = try requiredString("id", in: arguments)
            guard let preset = viewModel.customBrushPresets.first(where: { $0.id == id }) else {
                throw XomoAutomationCallError.notFound("Custom brush preset \(id)")
            }
            viewModel.deleteBrushPreset(preset)
        default:
            throw XomoAutomationCallError.invalidArgument("Unknown brush preset action: \(action)")
        }
        return brushPresetsResult(viewModel)
    }

    private func brushPresetsResult(_ viewModel: ImageEditorViewModel) -> XomoJSONValue {
        .array(viewModel.brushPresets.map { preset in
            .object([
                "id": .string(preset.id),
                "title": .string(preset.title),
                "builtIn": .bool(preset.isBuiltIn),
                "active": .bool(viewModel.activeBrushPreset?.id == preset.id),
                "size": .number(Double(preset.size)),
                "hardness": .number(Double(preset.hardness)),
                "flow": .number(Double(preset.flow)),
                "spacing": .number(Double(preset.spacing)),
                "pressureSize": .bool(preset.pressureControlsSize),
                "pressureFlow": .bool(preset.pressureControlsFlow),
                "pressureSensitivity": .number(Double(preset.pressureSensitivity))
            ])
        })
    }

    private func pathResult(_ viewModel: ImageEditorViewModel) -> XomoJSONValue {
        guard let layer = viewModel.document.selectedLayer,
              let content = layer.shapeContent,
              content.kind == .path
        else { return .object(["active": .bool(false)]) }
        let subpaths = content.allEditablePathSubpaths.enumerated().map { subpathIndex, anchors in
            XomoJSONValue.object([
                "index": .number(Double(subpathIndex)),
                "anchors": .array(anchors.enumerated().map { anchorIndex, anchor in
                    .object([
                        "index": .number(Double(anchorIndex)),
                        "point": pointJSON(anchor.point),
                        "inControl": anchor.inControl.map(pointJSON) ?? .null,
                        "outControl": anchor.outControl.map(pointJSON) ?? .null,
                        "selected": .bool(
                            subpathIndex == viewModel.selectedPathSubpathIndex
                                && anchorIndex == viewModel.selectedPathAnchorIndex
                        )
                    ])
                })
            ])
        }
        return .object([
            "active": .bool(true),
            "layerId": .string(layer.id.uuidString),
            "coordinateSpace": .string("layer"),
            "closed": .bool(content.isPathClosed),
            "selectedSubpath": .number(Double(viewModel.selectedPathSubpathIndex)),
            "selectedAnchor": viewModel.selectedPathAnchorIndex.map { .number(Double($0)) } ?? .null,
            "subpaths": .array(subpaths)
        ])
    }

    private func textResult(_ viewModel: ImageEditorViewModel) -> XomoJSONValue {
        guard let layer = viewModel.document.selectedLayer,
              let content = layer.textContent
        else { return .object(["active": .bool(false)]) }
        return .object([
            "active": .bool(true),
            "layerId": .string(layer.id.uuidString),
            "text": .string(content.text),
            "fontSize": .number(content.fontSize),
            "bold": .bool(content.isBold),
            "italic": .bool(content.isItalic),
            "underline": .bool(content.isUnderlined),
            "strikethrough": .bool(content.isStruckThrough),
            "characterSpacing": .number(content.characterSpacing),
            "lineSpacing": .number(content.lineSpacing),
            "boxWidth": .number(content.boxWidth),
            "boxHeight": .number(content.boxHeight),
            "requiredBoxHeight": .number(content.requiredParagraphHeight),
            "hasOverflow": .bool(content.hasOverflow),
            "layoutMode": .string(content.layoutMode.rawValue),
            "alignment": .string(content.alignment.rawValue),
            "leftIndent": .number(content.leftIndent),
            "rightIndent": .number(content.rightIndent),
            "firstLineIndent": .number(content.firstLineIndent),
            "color": colorJSON(content.color)
        ])
    }

    private func updateText(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws {
        guard let content = viewModel.document.selectedLayer?.textContent else {
            throw XomoAutomationCallError.operationFailed("No selected text layer")
        }
        viewModel.textValue = arguments["text"]?.stringValue ?? content.text
        viewModel.textSize = arguments["fontSize"]?.doubleValue ?? content.fontSize
        viewModel.textBold = arguments["bold"]?.boolValue ?? content.isBold
        viewModel.textItalic = arguments["italic"]?.boolValue ?? content.isItalic
        viewModel.textUnderlined = arguments["underline"]?.boolValue ?? content.isUnderlined
        viewModel.textStruckThrough = arguments["strikethrough"]?.boolValue ?? content.isStruckThrough
        viewModel.textCharacterSpacing = arguments["characterSpacing"]?.doubleValue ?? content.characterSpacing
        viewModel.textLineSpacing = arguments["lineSpacing"]?.doubleValue ?? content.lineSpacing
        viewModel.textBoxWidth = arguments["boxWidth"]?.doubleValue ?? content.boxWidth
        viewModel.textBoxHeight = arguments["boxHeight"]?.doubleValue ?? content.boxHeight
        viewModel.textLeftIndent = arguments["leftIndent"]?.doubleValue ?? content.leftIndent
        viewModel.textRightIndent = arguments["rightIndent"]?.doubleValue ?? content.rightIndent
        viewModel.textFirstLineIndent = arguments["firstLineIndent"]?.doubleValue ?? content.firstLineIndent
        if let alignmentRaw = arguments["alignment"]?.stringValue {
            guard let alignment = ImageEditorTextAlignment(rawValue: alignmentRaw) else {
                throw XomoAutomationCallError.invalidArgument("Unknown text alignment")
            }
            viewModel.selectedTextAlignment = alignment
        } else {
            viewModel.selectedTextAlignment = content.alignment
        }
        viewModel.updateSelectedTextLayer()
    }

    private func shapeResult(_ viewModel: ImageEditorViewModel) -> XomoJSONValue {
        guard let layer = viewModel.document.selectedLayer,
              let content = layer.shapeContent
        else { return .object(["active": .bool(false)]) }
        return .object([
            "active": .bool(true),
            "layerId": .string(layer.id.uuidString),
            "kind": .string(content.kind.rawValue),
            "fillColor": colorJSON(content.fillColor),
            "fillOpacity": .number(content.fillOpacity),
            "strokeColor": colorJSON(content.strokeColor),
            "strokeOpacity": .number(content.strokeOpacity),
            "strokeWidth": .number(content.strokeWidth)
        ])
    }

    private func updateShape(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws {
        guard let content = viewModel.document.selectedLayer?.shapeContent else {
            throw XomoAutomationCallError.operationFailed("No selected shape layer")
        }
        viewModel.opacity = arguments["opacity"]?.doubleValue ?? content.fillOpacity
        if let strokeWidth = arguments["strokeWidth"]?.doubleValue {
            viewModel.brushSize = strokeWidth / 0.35
        } else {
            viewModel.brushSize = content.strokeWidth / 0.35
        }
        viewModel.updateSelectedShapeLayer()
    }

    private func pathAction(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws {
        let action = try requiredString("action", in: arguments)
        if action == "create" {
            let points = try requiredPoints("points", in: arguments)
            guard points.count >= 2 else {
                throw XomoAutomationCallError.invalidArgument("A path needs at least two points")
            }
            viewModel.cancelPenPath()
            points.forEach(viewModel.addPenPoint)
            viewModel.finishPenPath(closed: arguments["closed"]?.boolValue ?? false)
            return
        }
        if action == "select" {
            guard let content = viewModel.document.selectedLayer?.shapeContent,
                  content.kind == .path
            else { throw XomoAutomationCallError.operationFailed("No selected path layer") }
            let subpath = Int(arguments["subpath"]?.doubleValue ?? 0)
            let anchor = Int(try requiredNumber("anchor", in: arguments))
            guard content.allEditablePathSubpaths.indices.contains(subpath),
                  content.allEditablePathSubpaths[subpath].indices.contains(anchor)
            else { throw XomoAutomationCallError.invalidArgument("Path anchor index is out of range") }
            viewModel.selectedPathSubpathIndex = subpath
            viewModel.selectedPathAnchorIndex = anchor
            switch arguments["role"]?.stringValue ?? "anchor" {
            case "anchor": viewModel.selectedPathControlRole = .anchor
            case "inHandle": viewModel.selectedPathControlRole = .inHandle
            case "outHandle": viewModel.selectedPathControlRole = .outHandle
            default: throw XomoAutomationCallError.invalidArgument("Unknown path control role")
            }
            return
        }
        switch action {
        case "nextAnchor": viewModel.selectNextPathAnchor()
        case "previousAnchor": viewModel.selectPreviousPathAnchor()
        case "nextSubpath": viewModel.selectNextPathSubpath()
        case "previousSubpath": viewModel.selectPreviousPathSubpath()
        case "setAnchorX": viewModel.setSelectedPathAnchorX(try requiredNumber("value", in: arguments))
        case "setAnchorY": viewModel.setSelectedPathAnchorY(try requiredNumber("value", in: arguments))
        case "smoothAnchor": viewModel.smoothSelectedPathAnchor()
        case "symmetrizeHandles": viewModel.symmetrizeSelectedPathAnchorHandles()
        case "clearHandles": viewModel.clearSelectedPathAnchorHandles()
        case "moveSubpath":
            viewModel.moveSelectedPathSubpath(by: CGSize(
                width: try requiredNumber("dx", in: arguments),
                height: try requiredNumber("dy", in: arguments)
            ))
        case "duplicateSubpath": viewModel.duplicateSelectedPathSubpath()
        case "deleteAnchor": viewModel.deleteSelectedPathAnchor()
        case "deleteSubpath": viewModel.deleteSelectedPathSubpath()
        case "insertAnchorAfter": viewModel.insertPathAnchorAfterSelection()
        case "toggleClosed": viewModel.toggleSelectedPathClosed()
        case "reverse": viewModel.reverseSelectedPathDirection()
        case "strokeToPixelLayer": viewModel.strokeSelectedPathToPixelLayer()
        case "fillToPixelLayer": viewModel.fillSelectedPathToPixelLayer()
        case "fromSelection": viewModel.createPathFromSelection()
        case "loadSelection": viewModel.loadSelectionFromSelectedPath()
        case "applyVectorMask": viewModel.applySelectedPathAsVectorMask()
        case "applyLayerMask": viewModel.applySelectedPathAsLayerMask()
        case "editVectorMask": viewModel.editSelectedVectorMaskAsPath()
        default: throw XomoAutomationCallError.invalidArgument("Unknown path action")
        }
    }

    private func guidesResult(_ viewModel: ImageEditorViewModel) -> XomoJSONValue {
        .object([
            "visible": .bool(viewModel.document.areGuidesVisible),
            "locked": .bool(viewModel.document.areGuidesLocked),
            "snapping": .bool(viewModel.document.isGuideSnappingEnabled),
            "gridVisible": .bool(viewModel.document.isGridVisible),
            "gridSnapping": .bool(viewModel.document.isGridSnappingEnabled),
            "guides": .array(viewModel.document.guides.map { guide in
                .object([
                    "id": .string(guide.id.uuidString),
                    "orientation": .string(guide.orientation.rawValue),
                    "position": .number(guide.position)
                ])
            })
        ])
    }

    private func smartFiltersResult(_ viewModel: ImageEditorViewModel) -> XomoJSONValue {
        .array((viewModel.document.selectedLayer?.smartFilters ?? []).map { filter in
            .object([
                "id": .string(filter.id.uuidString),
                "filter": .string(filter.kind.rawValue),
                "intensity": .number(filter.intensity),
                "enabled": .bool(filter.isEnabled)
            ])
        })
    }

    private func actionResult(_ viewModel: ImageEditorViewModel) -> XomoJSONValue {
        .object([
            "status": .string(viewModel.statusText),
            "selectedLayerId": viewModel.document.selectedLayerID.map { .string($0.uuidString) } ?? .null,
            "historyCount": .number(Double(viewModel.document.history.count))
        ])
    }

    private func createLayer(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws {
        switch arguments["kind"]?.stringValue ?? "pixel" {
        case "pixel": viewModel.addLayer()
        case "group": viewModel.addLayerGroup()
        case "text":
            viewModel.addText(at: optionalPoint(arguments))
        case "adjustment": viewModel.addAdjustmentLayer()
        case "filter": viewModel.addFilterLayer()
        case "solidColorFill": viewModel.addSolidColorFillLayer()
        case "patternFill": viewModel.addPatternFillLayer()
        case "gradientFill": viewModel.addGradientFillLayer()
        default: throw XomoAutomationCallError.invalidArgument("Unknown layer kind")
        }
    }

    private func reorderLayer(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws {
        switch try requiredString("direction", in: arguments) {
        case "top": viewModel.moveSelectedLayerToTop()
        case "up": viewModel.moveSelectedLayerUp()
        case "down": viewModel.moveSelectedLayerDown()
        case "bottom": viewModel.moveSelectedLayerToBottom()
        default: throw XomoAutomationCallError.invalidArgument("Unknown layer order direction")
        }
    }

    private func layerTransform(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws {
        switch try requiredString("action", in: arguments) {
        case "scale": viewModel.scaleSelectedLayer(by: try requiredNumber("value", in: arguments))
        case "rotate": viewModel.rotateSelectedLayer(degrees: try requiredNumber("value", in: arguments))
        case "rotateLeft90": viewModel.rotateSelectedLayerLeft90()
        case "rotateRight90": viewModel.rotateSelectedLayerRight90()
        case "rotate180": viewModel.rotateSelectedLayer180()
        case "flipHorizontal": viewModel.flipSelectedLayerHorizontal()
        case "flipVertical": viewModel.flipSelectedLayerVertical()
        case "fitCanvas": viewModel.fitSelectedLayerToCanvas()
        case "fillCanvas": viewModel.fillSelectedLayerToCanvas()
        case "fitSelection": viewModel.fitSelectedLayerToSelection()
        case "fillSelection": viewModel.fillSelectedLayerToSelection()
        case "trimTransparent": viewModel.trimSelectedLayerTransparentPixels()
        case "rasterize": viewModel.rasterizeSelectedLayer()
        default: throw XomoAutomationCallError.invalidArgument("Unknown layer transform action")
        }
    }

    private func layerAlignment(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws {
        let action = try requiredString("action", in: arguments)
        let mode = try requiredString("mode", in: arguments)
        if action == "distributeSpacing" {
            switch mode {
            case "horizontal": viewModel.distributeSelectedLayerSpacing(.horizontal)
            case "vertical": viewModel.distributeSelectedLayerSpacing(.vertical)
            default: throw XomoAutomationCallError.invalidArgument("Unknown spacing distribution mode")
            }
            return
        }
        let alignment: ImageEditorLayerAlignment
        switch mode {
        case "left": alignment = .left
        case "horizontalCenter": alignment = .horizontalCenter
        case "right": alignment = .right
        case "top": alignment = .top
        case "verticalCenter": alignment = .verticalCenter
        case "bottom": alignment = .bottom
        default: throw XomoAutomationCallError.invalidArgument("Unknown alignment mode")
        }
        switch action {
        case "align":
            switch arguments["target"]?.stringValue ?? "selectionBounds" {
            case "selectionBounds": viewModel.alignSelectedLayers(alignment)
            case "canvas": viewModel.alignSelectedLayersToCanvas(alignment)
            case "pixelSelection": viewModel.alignSelectedLayersToSelection(alignment)
            default: throw XomoAutomationCallError.invalidArgument("Unknown alignment target")
            }
        case "distribute":
            let distribution: ImageEditorLayerDistribution
            switch alignment {
            case .left: distribution = .left
            case .horizontalCenter: distribution = .horizontalCenter
            case .right: distribution = .right
            case .top: distribution = .top
            case .verticalCenter: distribution = .verticalCenter
            case .bottom: distribution = .bottom
            }
            viewModel.distributeSelectedLayers(distribution)
        default: throw XomoAutomationCallError.invalidArgument("Unknown layer alignment action")
        }
    }

    private func layerStyleAction(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws {
        switch try requiredString("action", in: arguments) {
        case "copy": viewModel.copySelectedLayerStyle()
        case "paste": viewModel.pasteLayerStyleToSelectedLayers()
        case "clear": viewModel.clearSelectedLayerStyles()
        default: throw XomoAutomationCallError.invalidArgument("Unknown layer style action")
        }
    }

    private func layerStyleSetting(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws {
        let property = try requiredString("property", in: arguments)
        let value = arguments["value"]?.doubleValue
        func number() throws -> Double {
            guard let value, value.isFinite else {
                throw XomoAutomationCallError.invalidArgument("Style setting requires numeric value")
            }
            return value
        }
        switch property {
        case "strokeWidth": viewModel.setSelectedLayerStrokeWidth(try number())
        case "strokeOpacity": viewModel.setSelectedLayerStrokeOpacity(try number())
        case "strokeColor": viewModel.setSelectedLayerStrokeColor(viewModel.foregroundColor)
        case "shadowOpacity": viewModel.setSelectedLayerShadowOpacity(try number())
        case "shadowColor": viewModel.setSelectedLayerShadowColor(viewModel.foregroundColor)
        case "shadowBlur": viewModel.setSelectedLayerShadowBlur(try number())
        case "shadowSpread": viewModel.setSelectedLayerShadowSpread(try number())
        case "shadowNoise": viewModel.setSelectedLayerShadowNoise(try number())
        case "shadowDistance": viewModel.setSelectedLayerShadowDistance(try number())
        case "shadowAngle": viewModel.setSelectedLayerShadowAngle(try number())
        case "globalLightAngle": viewModel.setGlobalLightAngle(try number())
        case "innerShadowOpacity": viewModel.setSelectedLayerInnerShadowOpacity(try number())
        case "innerShadowBlur": viewModel.setSelectedLayerInnerShadowBlur(try number())
        case "innerShadowChoke": viewModel.setSelectedLayerInnerShadowChoke(try number())
        case "innerShadowNoise": viewModel.setSelectedLayerInnerShadowNoise(try number())
        case "innerShadowDistance": viewModel.setSelectedLayerInnerShadowDistance(try number())
        case "innerShadowAngle": viewModel.setSelectedLayerInnerShadowAngle(try number())
        case "outerGlowOpacity": viewModel.setSelectedLayerOuterGlowOpacity(try number())
        case "outerGlowColor": viewModel.setSelectedLayerOuterGlowColor(viewModel.foregroundColor)
        case "outerGlowBlur": viewModel.setSelectedLayerOuterGlowBlur(try number())
        case "outerGlowSpread": viewModel.setSelectedLayerOuterGlowSpread(try number())
        case "outerGlowNoise": viewModel.setSelectedLayerOuterGlowNoise(try number())
        case "innerGlowOpacity": viewModel.setSelectedLayerInnerGlowOpacity(try number())
        case "innerGlowColor": viewModel.setSelectedLayerInnerGlowColor(viewModel.foregroundColor)
        case "innerGlowBlur": viewModel.setSelectedLayerInnerGlowBlur(try number())
        case "innerGlowChoke": viewModel.setSelectedLayerInnerGlowChoke(try number())
        case "innerGlowNoise": viewModel.setSelectedLayerInnerGlowNoise(try number())
        case "colorOverlayOpacity": viewModel.setSelectedLayerColorOverlayOpacity(try number())
        case "colorOverlayColor": viewModel.setSelectedLayerColorOverlayColor(viewModel.foregroundColor)
        case "gradientOverlayOpacity": viewModel.setSelectedLayerGradientOverlayOpacity(try number())
        case "gradientOverlayScale": viewModel.setSelectedLayerGradientOverlayScale(try number())
        case "gradientOverlayAngle": viewModel.setSelectedLayerGradientOverlayAngle(try number())
        case "patternOverlayOpacity": viewModel.setSelectedLayerPatternOverlayOpacity(try number())
        case "patternOverlayScale": viewModel.setSelectedLayerPatternOverlayScale(try number())
        case "satinOpacity": viewModel.setSelectedLayerSatinOpacity(try number())
        case "satinColor": viewModel.setSelectedLayerSatinColor(viewModel.foregroundColor)
        case "satinDistance": viewModel.setSelectedLayerSatinDistance(try number())
        case "satinSize": viewModel.setSelectedLayerSatinSize(try number())
        case "satinAngle": viewModel.setSelectedLayerSatinAngle(try number())
        case "satinInvert": viewModel.setSelectedLayerSatinInvert(try requiredBool("enabled", in: arguments))
        case "bevelSize": viewModel.setSelectedLayerBevelSize(try number())
        case "bevelOpacity": viewModel.setSelectedLayerBevelOpacity(try number())
        case "bevelHighlightColor": viewModel.setSelectedLayerBevelHighlightColor(viewModel.foregroundColor)
        case "bevelShadowColor": viewModel.setSelectedLayerBevelShadowColor(viewModel.foregroundColor)
        case "bevelSoften": viewModel.setSelectedLayerBevelSoften(try number())
        case "bevelAngle": viewModel.setSelectedLayerBevelAngle(try number())
        default: throw XomoAutomationCallError.invalidArgument("Unknown layer style setting")
        }
    }

    private func layerSelectionAction(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws {
        switch try requiredString("action", in: arguments) {
        case "all": viewModel.selectAllLayers()
        case "clear": viewModel.clearLayerSelection()
        case "invert": viewModel.invertLayerSelection()
        case "visible": viewModel.selectVisibleLayers()
        case "hidden": viewModel.selectHiddenLayers()
        case "locked": viewModel.selectLockedLayers()
        case "unlocked": viewModel.selectUnlockedLayers()
        case "masked": viewModel.selectMaskedLayers()
        case "styled": viewModel.selectStyledLayers()
        case "clippingMasks": viewModel.selectClippingMaskLayers()
        case "smartFiltered": viewModel.selectSmartFilteredLayers()
        case "sameKind": viewModel.selectLayersWithSameKind()
        case "similar": viewModel.selectSimilarLayers()
        case "sameBlendMode": viewModel.selectLayersWithSameBlendMode()
        case "sameLabel": viewModel.selectLayersWithSameLabelColor()
        case "groupMembers": viewModel.selectSelectedGroupMembers()
        case "parentGroup": viewModel.selectParentGroup()
        default: throw XomoAutomationCallError.invalidArgument("Unknown layer selection action")
        }
    }

    private func layerLinkAction(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws {
        switch try requiredString("action", in: arguments) {
        case "link": viewModel.linkSelectedLayers()
        case "unlink": viewModel.unlinkSelectedLayers()
        case "unlinkAll": viewModel.unlinkAllLayers()
        case "selectLinked": viewModel.selectLinkedLayers()
        default: throw XomoAutomationCallError.invalidArgument("Unknown layer link action")
        }
    }

    private func smartObjectAction(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws {
        switch try requiredString("action", in: arguments) {
        case "convert": viewModel.convertSelectedLayerToSmartObject()
        case "resetTransform": viewModel.resetSelectedSmartObjectTransform()
        case "makeUnique": viewModel.makeSelectedSmartObjectUnique()
        default: throw XomoAutomationCallError.invalidArgument("Unknown smart object action")
        }
    }

    private func layerProperties(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws {
        let property = try requiredString("property", in: arguments)
        switch property {
        case "fillOpacity":
            viewModel.setSelectedLayerFillOpacity(try requiredNumber("value", in: arguments))
            viewModel.commitSelectedLayerFillOpacityChange()
        case "blendIfSourceBlack":
            viewModel.setSelectedLayerBlendIfSourceBlack(try requiredNumber("value", in: arguments))
            viewModel.commitSelectedLayerBlendIfChange()
        case "blendIfSourceWhite":
            viewModel.setSelectedLayerBlendIfSourceWhite(try requiredNumber("value", in: arguments))
            viewModel.commitSelectedLayerBlendIfChange()
        case "blendIfUnderlyingBlack":
            viewModel.setSelectedLayerBlendIfUnderlyingBlack(try requiredNumber("value", in: arguments))
            viewModel.commitSelectedLayerBlendIfChange()
        case "blendIfUnderlyingWhite":
            viewModel.setSelectedLayerBlendIfUnderlyingWhite(try requiredNumber("value", in: arguments))
            viewModel.commitSelectedLayerBlendIfChange()
        case "maskDensity":
            viewModel.setSelectedLayerMaskDensity(try requiredNumber("value", in: arguments))
            viewModel.commitSelectedLayerMaskDensityChange()
        case "maskFeather":
            viewModel.setSelectedLayerMaskFeather(try requiredNumber("value", in: arguments))
            viewModel.commitSelectedLayerMaskFeatherChange()
        case "clippingMask": viewModel.toggleSelectedLayerClippingMask()
        case "lock":
            try setLayerLock(arguments, viewModel: viewModel)
        case "label":
            let rawValue = arguments["label"]?.stringValue
            let label = try rawValue.map { value -> ImageEditorLayerLabelColor in
                guard let color = ImageEditorLayerLabelColor(rawValue: value) else {
                    throw XomoAutomationCallError.invalidArgument("Unknown layer label color")
                }
                return color
            }
            viewModel.setSelectedLayersLabelColor(label)
        case "visibility":
            switch try requiredString("action", in: arguments) {
            case "isolate": viewModel.isolateSelectedLayers()
            case "showAll": viewModel.showAllLayers()
            case "showSelected": viewModel.showSelectedLayers()
            case "hideSelected": viewModel.hideSelectedLayers()
            default: throw XomoAutomationCallError.invalidArgument("Unknown visibility action")
            }
        default: throw XomoAutomationCallError.invalidArgument("Unknown layer property")
        }
    }

    private func setLayerLock(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws {
        let enabled = try requiredBool("enabled", in: arguments)
        switch try requiredString("kind", in: arguments) {
        case "all": enabled ? viewModel.lockSelectedLayers() : viewModel.unlockSelectedLayers()
        case "pixels": enabled ? viewModel.lockSelectedLayerPixels() : viewModel.unlockSelectedLayerPixels()
        case "position": enabled ? viewModel.lockSelectedLayerPosition() : viewModel.unlockSelectedLayerPosition()
        case "transparentPixels": enabled ? viewModel.lockSelectedLayerTransparentPixels() : viewModel.unlockSelectedLayerTransparentPixels()
        default: throw XomoAutomationCallError.invalidArgument("Unknown layer lock kind")
        }
    }

    private func layerCompsResult(_ viewModel: ImageEditorViewModel) -> XomoJSONValue {
        .array(viewModel.document.layerComps.map { comp in
            .object([
                "id": .string(comp.id.uuidString),
                "name": .string(comp.name),
                "selected": .bool(comp.id == viewModel.document.selectedLayerCompID),
                "layerStateCount": .number(Double(comp.layerStates.count)),
                "createdAt": .string(ISO8601DateFormatter().string(from: comp.createdAt))
            ])
        })
    }

    private func layerCompAction(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws {
        let action = try requiredString("action", in: arguments)
        switch action {
        case "create": viewModel.addLayerComp(named: arguments["name"]?.stringValue)
        case "select": viewModel.selectLayerComp(try requiredUUID("id", in: arguments))
        case "apply": viewModel.applyLayerComp(try requiredUUID("id", in: arguments))
        case "update": viewModel.updateLayerComp(try requiredUUID("id", in: arguments))
        case "rename":
            viewModel.renameLayerComp(
                try requiredUUID("id", in: arguments),
                to: try requiredString("name", in: arguments)
            )
        case "delete": viewModel.deleteLayerComp(try requiredUUID("id", in: arguments))
        case "duplicate":
            viewModel.selectLayerComp(try requiredUUID("id", in: arguments))
            viewModel.duplicateSelectedLayerComp()
        case "previous": viewModel.selectPreviousLayerComp()
        case "next": viewModel.selectNextLayerComp()
        default: throw XomoAutomationCallError.invalidArgument("Unknown layer comp action")
        }
    }

    private func layerGeneralAction(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws {
        switch try requiredString("action", in: arguments) {
        case "backgroundToLayer": viewModel.convertBackgroundToLayer()
        case "layerToBackground": viewModel.convertSelectedLayerToBackground()
        case "moveIntoGroup": viewModel.moveSelectedLayersIntoGroup()
        case "moveOutOfGroup": viewModel.moveSelectedLayersOutOfGroup()
        case "expandSelectedGroups": viewModel.expandSelectedLayerGroups()
        case "collapseSelectedGroups": viewModel.collapseSelectedLayerGroups()
        case "createClippingMasks": viewModel.createClippingMasksForSelectedLayers()
        case "releaseClippingMasks": viewModel.releaseSelectedClippingMasks()
        case "toggleClippingMask": viewModel.toggleSelectedLayerClippingMask()
        case "stampSelected": viewModel.stampSelectedLayers()
        default: throw XomoAutomationCallError.invalidArgument("Unknown layer action")
        }
    }

    private func selectionEdit(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws {
        switch try requiredString("action", in: arguments) {
        case "fillForeground": viewModel.fillSelection()
        case "fillBackground": viewModel.fillSelectionWithBackgroundColor()
        case "stroke": viewModel.strokeSelection()
        case "contentAwareFill": viewModel.contentAwareFillSelection()
        case "clearPixels": viewModel.clearSelectionPixels()
        case "copyToLayer": viewModel.copySelectionToNewLayer()
        case "cutToLayer": viewModel.cutSelectionToNewLayer()
        case "copyMergedToLayer": viewModel.copyMergedToNewLayer()
        case "duplicate": viewModel.duplicateSelectionOrSelectedLayer()
        default: throw XomoAutomationCallError.invalidArgument("Unknown selection edit action")
        }
    }

    private func selectionModify(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws {
        switch try requiredString("action", in: arguments) {
        case "loadTransparency": viewModel.loadSelectionFromLayerTransparency()
        case "save": viewModel.saveCurrentSelection()
        case "reselect": viewModel.reselectSelection()
        case "restoreSaved": viewModel.restoreSavedSelection()
        case "colorRange": viewModel.selectColorRangeFromForeground()
        case "similarColors": viewModel.selectSimilarColors()
        case "growColor": viewModel.growColorSelection()
        case "expand": viewModel.expandSelection()
        case "contract": viewModel.contractSelection()
        case "border": viewModel.borderSelection()
        case "fillHoles": viewModel.fillSelectionHoles()
        case "removeSpeckles": viewModel.removeSelectionSpeckles()
        case "centerHorizontal": viewModel.centerSelectionHorizontally()
        case "centerVertical": viewModel.centerSelectionVertically()
        case "centerCanvas": viewModel.centerSelectionInCanvas()
        case "flipHorizontal": viewModel.flipSelectionHorizontal()
        case "flipVertical": viewModel.flipSelectionVertical()
        case "rotateClockwise": viewModel.rotateSelectionClockwise()
        case "rotateCounterclockwise": viewModel.rotateSelectionCounterclockwise()
        case "rotate180": viewModel.rotateSelection180()
        case "scaleUp": viewModel.scaleSelectionUp()
        case "scaleDown": viewModel.scaleSelectionDown()
        case "fitCanvas": viewModel.fitSelectionToCanvas()
        case "nudge":
            viewModel.nudgeSelection(by: CGSize(
                width: try requiredNumber("dx", in: arguments),
                height: try requiredNumber("dy", in: arguments)
            ))
        default: throw XomoAutomationCallError.invalidArgument("Unknown selection modify action")
        }
    }

    private func historyAction(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws {
        switch try requiredString("action", in: arguments) {
        case "truncate": viewModel.truncateHistory(from: try requiredUUID("id", in: arguments))
        case "clearStates": viewModel.clearHistoryStates()
        case "createSnapshot": viewModel.createHistorySnapshot()
        case "selectSnapshot": viewModel.selectHistorySnapshot(try requiredUUID("id", in: arguments))
        case "restoreSnapshot": viewModel.restoreHistorySnapshot(try requiredUUID("id", in: arguments))
        case "renameSnapshot":
            viewModel.renameHistorySnapshot(
                try requiredUUID("id", in: arguments),
                to: try requiredString("name", in: arguments)
            )
        case "deleteSnapshot": viewModel.deleteHistorySnapshot(try requiredUUID("id", in: arguments))
        case "duplicateSnapshot":
            viewModel.selectHistorySnapshot(try requiredUUID("id", in: arguments))
            viewModel.duplicateSelectedHistorySnapshot()
        case "previousSnapshot": viewModel.selectPreviousHistorySnapshot()
        case "nextSnapshot": viewModel.selectNextHistorySnapshot()
        default: throw XomoAutomationCallError.invalidArgument("Unknown history action")
        }
    }

    private func canvasTransform(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws {
        switch try requiredString("action", in: arguments) {
        case "rotateClockwise": viewModel.rotateClockwise()
        case "rotateCounterclockwise": viewModel.rotateCounterclockwise()
        case "rotate180": viewModel.rotate180()
        case "flipHorizontal": viewModel.flipHorizontal()
        case "flipVertical": viewModel.flipVertical()
        case "cropCenter": viewModel.cropCenter()
        case "trimTransparent": viewModel.trimTransparentPixels()
        case "revealAll": viewModel.revealAllLayers()
        default: throw XomoAutomationCallError.invalidArgument("Unknown canvas transform action")
        }
    }

    private func clipboardAction(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws {
        switch try requiredString("action", in: arguments) {
        case "pasteAsLayer": viewModel.pasteClipboardAsLayer()
        case "pasteIntoSelection": viewModel.pasteClipboardIntoSelectionAsLayer()
        case "copySelection": viewModel.copySelectionToClipboard()
        case "cutSelection": viewModel.cutSelectionToClipboard()
        case "copyMerged": viewModel.copyMergedToClipboard()
        default: throw XomoAutomationCallError.invalidArgument("Unknown clipboard action")
        }
    }

    private func channelAction(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws {
        let id = try requiredUUID("id", in: arguments)
        switch try requiredString("action", in: arguments) {
        case "loadSelection": viewModel.loadSelectionFromAlphaChannel(id)
        case "addSelection": viewModel.addSelectionToAlphaChannel(id)
        case "subtractSelection": viewModel.subtractSelectionFromAlphaChannel(id)
        case "intersectSelection": viewModel.intersectSelectionWithAlphaChannel(id)
        case "invert": viewModel.invertAlphaChannel(id)
        case "fillWhite": viewModel.fillAlphaChannelWhite(id)
        case "clear": viewModel.clearAlphaChannel(id)
        case "threshold": viewModel.thresholdAlphaChannel(id)
        case "feather": viewModel.featherAlphaChannel(id)
        case "expand": viewModel.expandAlphaChannel(id)
        case "contract": viewModel.contractAlphaChannel(id)
        case "smooth": viewModel.smoothAlphaChannel(id)
        case "fillHoles": viewModel.fillHolesAlphaChannel(id)
        case "removeSpeckles": viewModel.removeSpecklesAlphaChannel(id)
        case "flipHorizontal": viewModel.flipAlphaChannelHorizontal(id)
        case "flipVertical": viewModel.flipAlphaChannelVertical(id)
        case "rotateClockwise": viewModel.rotateAlphaChannelClockwise(id)
        case "rotateCounterclockwise": viewModel.rotateAlphaChannelCounterclockwise(id)
        case "rotate180": viewModel.rotateAlphaChannel180(id)
        case "scaleUp": viewModel.scaleAlphaChannelUp(id)
        case "scaleDown": viewModel.scaleAlphaChannelDown(id)
        case "fitCanvas": viewModel.fitAlphaChannelToCanvas(id)
        case "moveLeft": viewModel.moveAlphaChannelLeft(id)
        case "moveRight": viewModel.moveAlphaChannelRight(id)
        case "moveUp": viewModel.moveAlphaChannelUp(id)
        case "moveDown": viewModel.moveAlphaChannelDown(id)
        case "updateFromSelection": viewModel.updateAlphaChannelFromSelection(id)
        case "applyToLayerMask": viewModel.applyAlphaChannelToSelectedLayerMask(id)
        case "createLayer": viewModel.createLayerFromAlphaChannel(id)
        default: throw XomoAutomationCallError.invalidArgument("Unknown channel action")
        }
    }

    private func insertComponent(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws {
        let componentRaw = try requiredString("component", in: arguments)
        guard let component = XomoComponentKind(rawValue: componentRaw) else {
            throw XomoAutomationCallError.invalidArgument("Unknown component: \(componentRaw)")
        }
        if let themeRaw = arguments["theme"]?.stringValue {
            guard let theme = XomoComponentTheme(rawValue: themeRaw) else {
                throw XomoAutomationCallError.invalidArgument("Unknown theme: \(themeRaw)")
            }
            viewModel.xomoComponentTheme = theme
        }
        viewModel.insertXomoComponent(component, at: optionalPoint(arguments))
    }

    private func setColor(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws {
        let target = arguments["target"]?.stringValue ?? "foreground"
        let color = NSColor(
            calibratedRed: try requiredNumber("red", in: arguments),
            green: try requiredNumber("green", in: arguments),
            blue: try requiredNumber("blue", in: arguments),
            alpha: arguments["alpha"]?.doubleValue ?? 1
        )
        switch target {
        case "foreground": viewModel.foregroundColor = color
        case "background": viewModel.backgroundColor = color
        default: throw XomoAutomationCallError.invalidArgument("Color target must be foreground or background")
        }
    }

    private func paintStroke(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws {
        let tool = arguments["tool"]?.stringValue ?? "brush"
        if let size = arguments["size"]?.doubleValue { viewModel.brushSize = size }
        if let opacity = arguments["opacity"]?.doubleValue { viewModel.opacity = opacity }
        if let hardness = arguments["hardness"]?.doubleValue {
            viewModel.hardness = max(0, min(1, hardness))
        }
        if let flow = arguments["flow"]?.doubleValue {
            viewModel.brushFlow = max(1, min(100, flow))
        }
        if let spacing = arguments["spacing"]?.doubleValue {
            viewModel.brushSpacing = max(1, min(200, spacing))
        }
        if let pressureSize = arguments["pressureSize"]?.boolValue {
            viewModel.setBrushPressureControlsSize(pressureSize)
        }
        if let pressureFlow = arguments["pressureFlow"]?.boolValue {
            viewModel.setBrushPressureControlsFlow(pressureFlow)
        }
        if let pressureSensitivity = arguments["pressureSensitivity"]?.doubleValue {
            viewModel.setBrushPressureSensitivity(CGFloat(pressureSensitivity))
        }
        let samples = try requiredBrushSamples("points", in: arguments)
        switch tool {
        case "brush": viewModel.drawBrush(samples: samples)
        case "eraser": viewModel.drawBrush(samples: samples, erase: true)
        default: throw XomoAutomationCallError.invalidArgument("Stroke tool must be brush or eraser")
        }
    }

    private func specialPaint(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws {
        let action = try requiredString("action", in: arguments)
        if let size = arguments["size"]?.doubleValue { viewModel.brushSize = size }
        if let opacity = arguments["opacity"]?.doubleValue { viewModel.opacity = opacity }
        if let feather = arguments["feather"]?.doubleValue { viewModel.feather = max(0, feather) }
        if action == "setCloneSource" || action == "cloneStamp" {
            if let aligned = arguments["aligned"]?.boolValue {
                viewModel.isCloneStampAligned = aligned
            }
            if let source = arguments["sampleSource"]?.stringValue {
                guard let sampleSource = ImageEditorCloneSampleSource(rawValue: source) else {
                    throw XomoAutomationCallError.invalidArgument(
                        "Clone sampleSource must be currentLayer, currentAndBelow, or allVisible"
                    )
                }
                viewModel.cloneStampSampleSource = sampleSource
            }
        }
        if action == "setHealingSource" || action == "healing" {
            if let aligned = arguments["aligned"]?.boolValue {
                viewModel.isHealingBrushAligned = aligned
            }
            if let source = arguments["sampleSource"]?.stringValue {
                guard let sampleSource = ImageEditorCloneSampleSource(rawValue: source) else {
                    throw XomoAutomationCallError.invalidArgument(
                        "Healing sampleSource must be currentLayer, currentAndBelow, or allVisible"
                    )
                }
                viewModel.healingBrushSampleSource = sampleSource
            }
        }
        if action == "paintBucket" {
            viewModel.paintBucketFill(at: try requiredPoint(arguments))
            return
        }
        if action == "redEye" {
            viewModel.reduceRedEye(at: try requiredPoint(arguments))
            return
        }
        if action == "setCloneSource" {
            viewModel.setCloneSource(at: try requiredPoint(arguments))
            return
        }
        if action == "setHealingSource" {
            viewModel.setHealingSource(at: try requiredPoint(arguments))
            return
        }
        let points = try requiredPoints("points", in: arguments)
        switch action {
        case "cloneStamp": viewModel.cloneStamp(points: points)
        case "dodge": viewModel.toneBrush(points: points, burn: false)
        case "burn": viewModel.toneBrush(points: points, burn: true)
        case "sponge": viewModel.spongeBrush(points: points)
        case "blur": viewModel.blurBrush(points: points)
        case "sharpen": viewModel.sharpenBrush(points: points)
        case "smudge": viewModel.smudgeBrush(points: points)
        case "healing": viewModel.healingBrush(points: points)
        case "patch":
            guard points.count == 2 else {
                throw XomoAutomationCallError.invalidArgument("Patch requires exactly two points")
            }
            if let rawMode = arguments["mode"]?.stringValue {
                guard let mode = ImageEditorPatchMode(rawValue: rawMode) else {
                    throw XomoAutomationCallError.invalidArgument("Patch mode must be source or destination")
                }
                viewModel.patchMode = mode
            }
            viewModel.patchSelection(from: points[0], to: points[1])
        default: throw XomoAutomationCallError.invalidArgument("Unknown special paint action")
        }
    }

    private func maskAction(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws {
        switch try requiredString("action", in: arguments) {
        case "addRevealAll": viewModel.addLayerMask()
        case "addFromSelection": viewModel.addLayerMaskFromSelection()
        case "addHideAll": viewModel.addLayerMaskHidingAll()
        case "addHideSelection": viewModel.addLayerMaskHidingSelection()
        case "delete": viewModel.deleteLayerMask()
        case "apply": viewModel.applyLayerMask()
        case "invert": viewModel.invertLayerMask()
        case "revealSelection": viewModel.revealSelectionOnLayerMask()
        case "hideSelection": viewModel.hideSelectionOnLayerMask()
        case "intersectSelection": viewModel.intersectLayerMaskWithSelection()
        case "loadSelection": viewModel.loadSelectionFromLayerMask()
        case "copyToSelected": viewModel.copyLayerMaskToSelectedLayers()
        case "toggleEnabled": viewModel.toggleLayerMaskEnabled()
        case "toggleLinked": viewModel.toggleLayerMaskLinked()
        case "addVectorFromSelection": viewModel.addVectorMaskFromSelection()
        case "copyVectorToSelected": viewModel.copyVectorMaskToSelectedLayers()
        case "rasterizeVector": viewModel.rasterizeSelectedVectorMask()
        case "loadVectorSelection": viewModel.loadSelectionFromVectorMask()
        case "toggleVectorEnabled": viewModel.toggleVectorMaskEnabled()
        case "deleteVector": viewModel.deleteVectorMask()
        default: throw XomoAutomationCallError.invalidArgument("Unknown mask action")
        }
    }

    private func layerEffect(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws {
        switch try requiredString("effect", in: arguments) {
        case "stroke": viewModel.toggleSelectedLayerStroke()
        case "shadow": viewModel.toggleSelectedLayerShadow()
        case "innerShadow": viewModel.toggleSelectedLayerInnerShadow()
        case "outerGlow": viewModel.toggleSelectedLayerOuterGlow()
        case "innerGlow": viewModel.toggleSelectedLayerInnerGlow()
        case "colorOverlay": viewModel.toggleSelectedLayerColorOverlay()
        case "gradientOverlay": viewModel.toggleSelectedLayerGradientOverlay()
        case "patternOverlay": viewModel.toggleSelectedLayerPatternOverlay()
        case "satin": viewModel.toggleSelectedLayerSatin()
        case "bevel": viewModel.toggleSelectedLayerBevel()
        default: throw XomoAutomationCallError.invalidArgument("Unknown layer effect")
        }
    }

    private func guideSettings(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws {
        if let visible = arguments["visible"]?.boolValue,
           viewModel.document.areGuidesVisible != visible {
            viewModel.toggleGuidesVisible()
        }
        if let locked = arguments["locked"]?.boolValue,
           viewModel.document.areGuidesLocked != locked {
            viewModel.toggleGuidesLocked()
        }
        if let snapping = arguments["snapping"]?.boolValue,
           viewModel.document.isGuideSnappingEnabled != snapping {
            viewModel.toggleGuideSnapping()
        }
        if let gridVisible = arguments["gridVisible"]?.boolValue,
           viewModel.document.isGridVisible != gridVisible {
            viewModel.toggleGridVisible()
        }
        if let gridSnapping = arguments["gridSnapping"]?.boolValue,
           viewModel.document.isGridSnappingEnabled != gridSnapping {
            viewModel.toggleGridSnapping()
        }
    }

    private func smartFilterManage(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws {
        let id = try requiredUUID("id", in: arguments)
        switch try requiredString("action", in: arguments) {
        case "update":
            if let intensity = arguments["intensity"]?.doubleValue { viewModel.filterIntensity = intensity }
            viewModel.updateSmartFilterOnSelectedLayer(id)
        case "remove": viewModel.removeSmartFilterFromSelectedLayer(id)
        case "moveUp": viewModel.moveSmartFilterOnSelectedLayer(id, offset: 1)
        case "moveDown": viewModel.moveSmartFilterOnSelectedLayer(id, offset: -1)
        default: throw XomoAutomationCallError.invalidArgument("Unknown smart filter management action")
        }
    }

    private func configureAdjustment(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws {
        let rawValue = try requiredString("adjustment", in: arguments)
        guard let adjustment = ImageEditorAdjustment(rawValue: rawValue) else {
            throw XomoAutomationCallError.invalidArgument("Unknown adjustment")
        }
        viewModel.selectedAdjustment = adjustment
        let settings = arguments["settings"]?.objectValue ?? [:]
        for (key, value) in settings {
            switch key {
            case "amount": viewModel.adjustmentValue = try numericSetting(value, key: key)
            case "levelsBlackPoint": viewModel.levelsBlackPoint = try numericSetting(value, key: key)
            case "levelsGamma": viewModel.levelsGamma = try numericSetting(value, key: key)
            case "levelsWhitePoint": viewModel.levelsWhitePoint = try numericSetting(value, key: key)
            case "curvesShadows": viewModel.curvesShadows = try numericSetting(value, key: key)
            case "curvesMidtones": viewModel.curvesMidtones = try numericSetting(value, key: key)
            case "curvesHighlights": viewModel.curvesHighlights = try numericSetting(value, key: key)
            case "hue": viewModel.hueSaturationHue = try numericSetting(value, key: key)
            case "saturation": viewModel.hueSaturationSaturation = try numericSetting(value, key: key)
            case "lightness": viewModel.hueSaturationLightness = try numericSetting(value, key: key)
            case "colorize": viewModel.hueSaturationColorize = try booleanSetting(value, key: key)
            case "brightness": viewModel.brightnessContrastBrightness = try numericSetting(value, key: key)
            case "contrast": viewModel.brightnessContrastContrast = try numericSetting(value, key: key)
            case "exposureEV": viewModel.exposureEV = try numericSetting(value, key: key)
            case "exposureOffset": viewModel.exposureOffset = try numericSetting(value, key: key)
            case "exposureGamma": viewModel.exposureGamma = try numericSetting(value, key: key)
            case "shadows": viewModel.shadowsHighlightsShadows = try numericSetting(value, key: key)
            case "highlights": viewModel.shadowsHighlightsHighlights = try numericSetting(value, key: key)
            case "vibrance": viewModel.vibranceAmount = try numericSetting(value, key: key)
            case "vibranceSaturation": viewModel.vibranceSaturation = try numericSetting(value, key: key)
            case "gradientReverse": viewModel.gradientMapReverse = try booleanSetting(value, key: key)
            case "gradientDither": viewModel.gradientMapDither = try booleanSetting(value, key: key)
            case "photoFilterDensity": viewModel.photoFilterDensity = try numericSetting(value, key: key)
            case "preserveLuminosity": viewModel.photoFilterPreserveLuminosity = try booleanSetting(value, key: key)
            default: throw XomoAutomationCallError.invalidArgument("Unknown adjustment setting: \(key)")
            }
        }
        switch arguments["action"]?.stringValue ?? "apply" {
        case "apply": viewModel.applyAdjustment()
        case "addLayer": viewModel.addAdjustmentLayer()
        case "updateLayer": viewModel.updateSelectedAdjustmentLayer()
        default: throw XomoAutomationCallError.invalidArgument("Unknown adjustment configure action")
        }
    }

    private func configureFilter(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws {
        let rawValue = try requiredString("filter", in: arguments)
        guard let filter = ImageEditorFilter(rawValue: rawValue) else {
            throw XomoAutomationCallError.invalidArgument("Unknown filter")
        }
        viewModel.selectedFilter = filter
        let settings = arguments["settings"]?.objectValue ?? [:]
        for (key, value) in settings {
            switch key {
            case "intensity": viewModel.filterIntensity = try numericSetting(value, key: key)
            case "unsharpRadius": viewModel.filterUnsharpRadius = try numericSetting(value, key: key)
            case "unsharpThreshold": viewModel.filterUnsharpThreshold = try numericSetting(value, key: key)
            case "liquifyPushX": viewModel.filterLiquifyPushX = try numericSetting(value, key: key)
            case "liquifyPushY": viewModel.filterLiquifyPushY = try numericSetting(value, key: key)
            case "twirlAngle": viewModel.filterLiquifyTwirlAngle = try numericSetting(value, key: key)
            case "bulgeAmount": viewModel.filterLiquifyBulgeAmount = try numericSetting(value, key: key)
            case "offsetX": viewModel.filterOffsetX = try numericSetting(value, key: key)
            case "offsetY": viewModel.filterOffsetY = try numericSetting(value, key: key)
            case "waveAmplitude": viewModel.filterWaveAmplitude = try numericSetting(value, key: key)
            case "waveFrequency": viewModel.filterWaveFrequency = try numericSetting(value, key: key)
            case "rippleAmount": viewModel.filterRippleAmount = try numericSetting(value, key: key)
            case "rippleFrequency": viewModel.filterRippleFrequency = try numericSetting(value, key: key)
            case "pinchAmount": viewModel.filterPinchAmount = try numericSetting(value, key: key)
            case "spherizeAmount": viewModel.filterSpherizeAmount = try numericSetting(value, key: key)
            default: throw XomoAutomationCallError.invalidArgument("Unknown filter setting: \(key)")
            }
        }
        switch arguments["action"]?.stringValue ?? "apply" {
        case "apply": viewModel.applySelectedFilter()
        case "addLayer": viewModel.addFilterLayer()
        case "updateLayer": viewModel.updateSelectedFilterLayer()
        case "addSmartFilter": viewModel.addSmartFilterToSelectedLayer()
        default: throw XomoAutomationCallError.invalidArgument("Unknown filter configure action")
        }
    }

    private func numericSetting(_ value: XomoJSONValue, key: String) throws -> Double {
        guard let number = value.doubleValue, number.isFinite else {
            throw XomoAutomationCallError.invalidArgument("Setting \(key) must be numeric")
        }
        return number
    }

    private func booleanSetting(_ value: XomoJSONValue, key: String) throws -> Bool {
        guard let boolean = value.boolValue else {
            throw XomoAutomationCallError.invalidArgument("Setting \(key) must be boolean")
        }
        return boolean
    }

    private func setZoom(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws {
        switch arguments["action"]?.stringValue ?? "set" {
        case "in": viewModel.zoomIn()
        case "out": viewModel.zoomOut()
        case "actual": viewModel.zoomActualPixels()
        case "fit": viewModel.fitZoom()
        case "set":
            let value = try requiredNumber("value", in: arguments)
            viewModel.zoom = min(ImageEditorViewModel.maximumZoom, max(ImageEditorViewModel.minimumZoom, value))
        default: throw XomoAutomationCallError.invalidArgument("Unknown zoom action")
        }
    }

    private func exportResult(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws -> XomoJSONValue {
        let formatRaw = arguments["format"]?.stringValue ?? "png"
        let scopeRaw = arguments["scope"]?.stringValue ?? "composited"
        guard let format = ImageEditorExportFormat(rawValue: formatRaw),
              let scope = ImageEditorExportScope(rawValue: scopeRaw)
        else { throw XomoAutomationCallError.invalidArgument("Unsupported export format or scope") }
        var settings = ImageEditorExportSettings()
        settings.format = format
        settings.scope = scope
        settings.scale = arguments["scale"]?.doubleValue ?? 1
        settings.quality = arguments["quality"]?.doubleValue ?? 0.9
        guard let data = viewModel.exportData(settings: settings) else {
            throw XomoAutomationCallError.operationFailed("Export failed")
        }
        return .object([
            "filename": .string(viewModel.exportFilenames(settings: settings).first ?? "xomo.\(format.filenameExtension)"),
            "mimeType": .string(format.contentType.preferredMIMEType ?? "application/octet-stream"),
            "base64": .string(data.base64EncodedString())
        ])
    }

    private func optionalPoint(_ arguments: [String: XomoJSONValue]) -> CGPoint? {
        guard let x = arguments["x"]?.doubleValue,
              let y = arguments["y"]?.doubleValue
        else { return nil }
        return CGPoint(x: x, y: y)
    }

    private func requiredPoint(_ arguments: [String: XomoJSONValue]) throws -> CGPoint {
        CGPoint(
            x: try requiredNumber("x", in: arguments),
            y: try requiredNumber("y", in: arguments)
        )
    }

    private func requiredPoints(
        _ key: String,
        in arguments: [String: XomoJSONValue]
    ) throws -> [CGPoint] {
        guard let values = arguments[key]?.arrayValue else {
            throw XomoAutomationCallError.invalidArgument("Missing point array: \(key)")
        }
        let points = try values.map { value -> CGPoint in
            guard let object = value.objectValue,
                  let x = object["x"]?.doubleValue,
                  let y = object["y"]?.doubleValue
            else { throw XomoAutomationCallError.invalidArgument("Each point needs numeric x and y") }
            return CGPoint(x: x, y: y)
        }
        guard !points.isEmpty else {
            throw XomoAutomationCallError.invalidArgument("Point array cannot be empty")
        }
        return points
    }

    private func requiredBrushSamples(
        _ key: String,
        in arguments: [String: XomoJSONValue]
    ) throws -> [ImageEditorBrushStrokeSample] {
        guard let values = arguments[key]?.arrayValue else {
            throw XomoAutomationCallError.invalidArgument("Missing point array: \(key)")
        }
        let samples = try values.map { value -> ImageEditorBrushStrokeSample in
            guard let object = value.objectValue,
                  let x = object["x"]?.doubleValue,
                  let y = object["y"]?.doubleValue
            else { throw XomoAutomationCallError.invalidArgument("Each point needs numeric x and y") }
            let pressure = object["pressure"]?.doubleValue.map {
                CGFloat(max(0, min(1, $0)))
            }
            return ImageEditorBrushStrokeSample(
                point: CGPoint(x: x, y: y),
                pressure: pressure
            )
        }
        guard !samples.isEmpty else {
            throw XomoAutomationCallError.invalidArgument("Point array cannot be empty")
        }
        return samples
    }

    private func colorJSON(_ color: NSColor) -> XomoJSONValue {
        let rgb = color.usingColorSpace(.deviceRGB) ?? color
        return .object([
            "red": .number(rgb.redComponent),
            "green": .number(rgb.greenComponent),
            "blue": .number(rgb.blueComponent),
            "alpha": .number(rgb.alphaComponent)
        ])
    }

    private func pointJSON(_ point: CGPoint) -> XomoJSONValue {
        .object([
            "x": .number(point.x),
            "y": .number(point.y)
        ])
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

    private func requiredString(
        _ key: String,
        in arguments: [String: XomoJSONValue]
    ) throws -> String {
        guard let value = arguments[key]?.stringValue, !value.isEmpty else {
            throw XomoAutomationCallError.invalidArgument("Missing string argument: \(key)")
        }
        return value
    }

    private func requiredNumber(
        _ key: String,
        in arguments: [String: XomoJSONValue]
    ) throws -> Double {
        guard let value = arguments[key]?.doubleValue, value.isFinite else {
            throw XomoAutomationCallError.invalidArgument("Missing number argument: \(key)")
        }
        return value
    }

    private func requiredBool(
        _ key: String,
        in arguments: [String: XomoJSONValue]
    ) throws -> Bool {
        guard let value = arguments[key]?.boolValue else {
            throw XomoAutomationCallError.invalidArgument("Missing boolean argument: \(key)")
        }
        return value
    }

    private func requiredUUID(
        _ key: String,
        in arguments: [String: XomoJSONValue]
    ) throws -> UUID {
        let rawValue = try requiredString(key, in: arguments)
        guard let value = UUID(uuidString: rawValue) else {
            throw XomoAutomationCallError.invalidArgument("Invalid UUID argument: \(key)")
        }
        return value
    }
}

private enum XomoAutomationCallError: LocalizedError {
    case invalidArgument(String)
    case notFound(String)
    case operationFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidArgument(let message): "Invalid argument: \(message)"
        case .notFound(let message): "Not found: \(message)"
        case .operationFailed(let message): message
        }
    }
}

private extension XomoAutomationRegistry {
    static let tools: [XomoAutomationToolDefinition] = [
        tool("xomo.app.status", "Get Xomo app, version, active editor, and capability status."),
        tool("xomo.document.get", "Inspect the active Xomo document and canvas."),
        tool("xomo.document.create", "Replace the active document with a new preset or custom canvas.", [
            "preset": XomoAutomationSchema.string(description: "Canvas preset", values: XomoCanvasPreset.allCases.map(\.rawValue)),
            "width": XomoAutomationSchema.number(description: "Optional custom width"),
            "height": XomoAutomationSchema.number(description: "Optional custom height"),
            "exportScale": XomoAutomationSchema.number(description: "Export scale from 1 to 3"),
            "background": XomoAutomationSchema.string(description: "Canvas background", values: XomoCanvasBackground.allCases.map(\.rawValue))
        ]),
        tool("xomo.project.export", "Serialize the complete layered project and return base64 qpicproject data."),
        tool("xomo.project.import", "Replace the active document from base64 qpicproject data.", [
            "base64": XomoAutomationSchema.string(description: "Base64 qpicproject data")
        ], required: ["base64"]),
        tool("xomo.import.image", "Import a base64 encoded image as an editable layer.", [
            "base64": XomoAutomationSchema.string(description: "Base64 image data"),
            "name": XomoAutomationSchema.string(description: "Source filename"),
            "intoSelection": XomoAutomationSchema.boolean(description: "Mask the imported layer to the current selection")
        ], required: ["base64"]),
        tool("xomo.tool.list", "List all image editor tools."),
        tool("xomo.tool.select", "Select the active editor tool.", [
            "tool": XomoAutomationSchema.string(description: "Tool identifier", values: ImageEditorTool.allCases.map(\.rawValue))
        ], required: ["tool"]),
        tool("xomo.layer.list", "List layers with hierarchy, bounds, visibility, locks, opacity, and blend mode."),
        tool("xomo.layer.select", "Select a layer by UUID.", [
            "id": XomoAutomationSchema.string(description: "Layer UUID"),
            "extend": XomoAutomationSchema.boolean(description: "Extend the current layer selection")
        ], required: ["id"]),
        tool("xomo.layer.create", "Create a pixel, group, text, adjustment, filter, or fill layer.", [
            "kind": XomoAutomationSchema.string(description: "Layer kind", values: ["pixel", "group", "text", "adjustment", "filter", "solidColorFill", "patternFill", "gradientFill"]),
            "x": XomoAutomationSchema.number(description: "Optional canvas x position"),
            "y": XomoAutomationSchema.number(description: "Optional canvas y position")
        ]),
        tool("xomo.layer.delete", "Delete unlocked selected layer roots as complete subtrees and preserve a visible selection fallback."),
        tool("xomo.layer.duplicate", "Duplicate selected layer roots as hierarchy-safe subtrees within their original parents."),
        tool("xomo.layer.rename", "Rename the primary selected layer.", ["name": XomoAutomationSchema.string(description: "New layer name")], required: ["name"]),
        tool("xomo.layer.set_visibility", "Set layer visibility.", idBoolProperties(key: "visible"), required: ["id", "visible"]),
        tool("xomo.layer.set_lock", "Set the full lock state of a layer.", idBoolProperties(key: "locked"), required: ["id", "locked"]),
        tool("xomo.layer.set_opacity", "Set selected layer opacity from 0 to 1.", ["opacity": XomoAutomationSchema.number(description: "Opacity from 0 to 1")], required: ["opacity"]),
        tool("xomo.layer.set_blend_mode", "Set selected layer blend mode.", [
            "mode": XomoAutomationSchema.string(description: "Blend mode", values: ImageEditorBlendMode.allCases.map(\.rawValue))
        ], required: ["mode"]),
        tool("xomo.layer.nudge", "Move the active selection or selected layers by a canvas delta.", pointDeltaProperties, required: ["dx", "dy"]),
        tool("xomo.layer.order", "Move selected layer subtrees in the current visible hierarchy order.", [
            "direction": XomoAutomationSchema.string(description: "Visible stack direction", values: ["top", "up", "down", "bottom"])
        ], required: ["direction"]),
        tool("xomo.layer.group", "Group selected editable sibling subtrees while leaving locked items in place."),
        tool("xomo.layer.ungroup", "Ungroup selected editable groups while preserving unaffected selection."),
        tool("xomo.layer.merge_down", "Merge the selected visible layer into its adjacent lower pixel sibling, or flatten the selected group subtree."),
        tool("xomo.layer.merge_selected", "Merge editable selected sibling subtrees while preserving locked selections."),
        tool("xomo.layer.merge_visible", "Merge all visible layers."),
        tool("xomo.layer.stamp_visible", "Create a stamped layer from visible content."),
        tool("xomo.layer.stamp_selected", "Create a stamped layer from selected layer subtrees."),
        tool("xomo.layer.flatten", "Flatten visible content onto an opaque locked background and discard hidden layers."),
        tool("xomo.layer.transform", "Scale, rotate, flip, fit, trim, or rasterize selected layers.", [
            "action": XomoAutomationSchema.string(description: "Transform action", values: ["scale", "rotate", "rotateLeft90", "rotateRight90", "rotate180", "flipHorizontal", "flipVertical", "fitCanvas", "fillCanvas", "fitSelection", "fillSelection", "trimTransparent", "rasterize"]),
            "value": XomoAutomationSchema.number(description: "Scale factor or rotation degrees")
        ], required: ["action"]),
        tool("xomo.layer.align", "Align or distribute selected layers against their bounds, canvas, or pixel selection.", [
            "action": XomoAutomationSchema.string(description: "Layout action", values: ["align", "distribute", "distributeSpacing"]),
            "mode": XomoAutomationSchema.string(description: "Alignment or distribution mode", values: ["left", "horizontalCenter", "right", "top", "verticalCenter", "bottom", "horizontal", "vertical"]),
            "target": XomoAutomationSchema.string(description: "Alignment target", values: ["selectionBounds", "canvas", "pixelSelection"])
        ], required: ["action", "mode"]),
        tool("xomo.layer.style", "Copy, paste, or clear the complete selected layer style.", [
            "action": XomoAutomationSchema.string(description: "Layer style action", values: ["copy", "paste", "clear"])
        ], required: ["action"]),
        tool("xomo.layer.style_settings", "Set detailed stroke, shadow, glow, overlay, satin, bevel, and global-light properties.", [
            "property": XomoAutomationSchema.string(description: "Layer style property", values: ["strokeWidth", "strokeOpacity", "strokeColor", "shadowOpacity", "shadowColor", "shadowBlur", "shadowSpread", "shadowNoise", "shadowDistance", "shadowAngle", "globalLightAngle", "innerShadowOpacity", "innerShadowBlur", "innerShadowChoke", "innerShadowNoise", "innerShadowDistance", "innerShadowAngle", "outerGlowOpacity", "outerGlowColor", "outerGlowBlur", "outerGlowSpread", "outerGlowNoise", "innerGlowOpacity", "innerGlowColor", "innerGlowBlur", "innerGlowChoke", "innerGlowNoise", "colorOverlayOpacity", "colorOverlayColor", "gradientOverlayOpacity", "gradientOverlayScale", "gradientOverlayAngle", "patternOverlayOpacity", "patternOverlayScale", "satinOpacity", "satinColor", "satinDistance", "satinSize", "satinAngle", "satinInvert", "bevelSize", "bevelOpacity", "bevelHighlightColor", "bevelShadowColor", "bevelSoften", "bevelAngle"]),
            "value": XomoAutomationSchema.number(description: "Numeric style value"),
            "enabled": XomoAutomationSchema.boolean(description: "Boolean style value; color properties use the current foreground color")
        ], required: ["property"]),
        tool("xomo.layer.selection", "Select layers by state, relationship, kind, blend mode, or label.", [
            "action": XomoAutomationSchema.string(description: "Layer selection action", values: ["all", "clear", "invert", "visible", "hidden", "locked", "unlocked", "masked", "styled", "clippingMasks", "smartFiltered", "sameKind", "similar", "sameBlendMode", "sameLabel", "groupMembers", "parentGroup"])
        ], required: ["action"]),
        tool("xomo.layer.link", "Link, unlink, or select linked layers.", [
            "action": XomoAutomationSchema.string(description: "Layer link action", values: ["link", "unlink", "unlinkAll", "selectLinked"])
        ], required: ["action"]),
        tool("xomo.layer.smart_object", "Convert and manage embedded smart object layers.", [
            "action": XomoAutomationSchema.string(description: "Smart object action", values: ["convert", "resetTransform", "makeUnique"])
        ], required: ["action"]),
        tool("xomo.layer.properties", "Set fill, Blend If, mask, clipping, lock, label, and visibility properties.", [
            "property": XomoAutomationSchema.string(description: "Property group", values: ["fillOpacity", "blendIfSourceBlack", "blendIfSourceWhite", "blendIfUnderlyingBlack", "blendIfUnderlyingWhite", "maskDensity", "maskFeather", "clippingMask", "lock", "label", "visibility"]),
            "value": XomoAutomationSchema.number(description: "Numeric property value"),
            "kind": XomoAutomationSchema.string(description: "Lock kind", values: ["all", "pixels", "position", "transparentPixels"]),
            "enabled": XomoAutomationSchema.boolean(description: "Desired lock state"),
            "label": XomoAutomationSchema.string(description: "Layer label color", values: ImageEditorLayerLabelColor.allCases.map(\.rawValue)),
            "action": XomoAutomationSchema.string(description: "Visibility action", values: ["isolate", "showAll", "showSelected", "hideSelected"])
        ], required: ["property"]),
        tool("xomo.layer.action", "Run background conversion, recursive group expansion, hierarchy-safe group movement, clipping, and selected-layer stamping commands.", [
            "action": XomoAutomationSchema.string(description: "Layer action", values: ["backgroundToLayer", "layerToBackground", "moveIntoGroup", "moveOutOfGroup", "expandSelectedGroups", "collapseSelectedGroups", "createClippingMasks", "releaseClippingMasks", "toggleClippingMask", "stampSelected"])
        ], required: ["action"]),
        tool("xomo.layer_comp.list", "List saved layer composition states."),
        tool("xomo.layer_comp.action", "Create, select, apply, update, rename, duplicate, or delete layer comps.", [
            "action": XomoAutomationSchema.string(description: "Layer comp action", values: ["create", "select", "apply", "update", "rename", "delete", "duplicate", "previous", "next"]),
            "id": XomoAutomationSchema.string(description: "Layer comp UUID"),
            "name": XomoAutomationSchema.string(description: "Layer comp name")
        ], required: ["action"]),
        tool("xomo.selection.get", "Inspect the active pixel selection."),
        tool("xomo.selection.all", "Select the full canvas."),
        tool("xomo.selection.rectangle", "Create a rectangular canvas selection.", rectProperties, required: ["x", "y", "width", "height"]),
        tool("xomo.selection.ellipse", "Create an elliptical canvas selection.", rectProperties, required: ["x", "y", "width", "height"]),
        tool("xomo.selection.lasso", "Create a polygonal lasso selection from canvas points.", ["points": pointsSchema], required: ["points"]),
        tool("xomo.selection.magic", "Create a contiguous magic-wand selection at a canvas point.", pointProperties, required: ["x", "y"]),
        tool("xomo.selection.quick", "Create a quick selection from sampled canvas points.", ["points": pointsSchema], required: ["points"]),
        tool("xomo.selection.clear", "Deselect the current selection."),
        tool("xomo.selection.invert", "Invert the current selection."),
        tool("xomo.selection.feather", "Feather the current selection.", ["radius": XomoAutomationSchema.number(description: "Feather radius in pixels")]),
        tool("xomo.selection.smooth", "Smooth the current selection boundary."),
        tool("xomo.selection.edit", "Fill, stroke, clear, duplicate, or move selected pixels into new layers.", [
            "action": XomoAutomationSchema.string(description: "Selection edit action", values: ["fillForeground", "fillBackground", "stroke", "contentAwareFill", "clearPixels", "copyToLayer", "cutToLayer", "copyMergedToLayer", "duplicate"])
        ], required: ["action"]),
        tool("xomo.selection.modify", "Save, restore, transform, clean, color-match, or nudge the pixel selection.", [
            "action": XomoAutomationSchema.string(description: "Selection modification", values: ["loadTransparency", "save", "reselect", "restoreSaved", "colorRange", "similarColors", "growColor", "expand", "contract", "border", "fillHoles", "removeSpeckles", "centerHorizontal", "centerVertical", "centerCanvas", "flipHorizontal", "flipVertical", "rotateClockwise", "rotateCounterclockwise", "rotate180", "scaleUp", "scaleDown", "fitCanvas", "nudge"]),
            "dx": XomoAutomationSchema.number(description: "Horizontal selection delta"),
            "dy": XomoAutomationSchema.number(description: "Vertical selection delta")
        ], required: ["action"]),
        tool("xomo.clipboard.action", "Copy or cut selected pixels and paste clipboard images as editable layers.", [
            "action": XomoAutomationSchema.string(description: "Clipboard action", values: ["pasteAsLayer", "pasteIntoSelection", "copySelection", "cutSelection", "copyMerged"])
        ], required: ["action"]),
        tool("xomo.channel.list", "List alpha channels."),
        tool("xomo.channel.create", "Create a blank alpha channel."),
        tool("xomo.channel.select", "Select an alpha channel.", idProperties, required: ["id"]),
        tool("xomo.channel.rename", "Rename an alpha channel.", [
            "id": XomoAutomationSchema.string(description: "Channel UUID"),
            "name": XomoAutomationSchema.string(description: "New channel name")
        ], required: ["id", "name"]),
        tool("xomo.channel.delete", "Delete an alpha channel.", idProperties, required: ["id"]),
        tool("xomo.channel.duplicate", "Duplicate an alpha channel.", idProperties, required: ["id"]),
        tool("xomo.channel.action", "Apply a selection or mask operation to an alpha channel.", [
            "id": XomoAutomationSchema.string(description: "Channel UUID"),
            "action": XomoAutomationSchema.string(description: "Channel action", values: ["loadSelection", "addSelection", "subtractSelection", "intersectSelection", "invert", "fillWhite", "clear", "threshold", "feather", "expand", "contract", "smooth"])
        ], required: ["id", "action"]),
        tool("xomo.history.list", "List document history states."),
        tool("xomo.history.undo", "Undo the last document operation."),
        tool("xomo.history.redo", "Redo the last undone operation."),
        tool("xomo.history.restore", "Restore a history state by UUID.", idProperties, required: ["id"]),
        tool("xomo.history.snapshot_list", "List named history snapshots."),
        tool("xomo.history.action", "Truncate history or create and manage named snapshots.", [
            "action": XomoAutomationSchema.string(description: "History action", values: ["truncate", "clearStates", "createSnapshot", "selectSnapshot", "restoreSnapshot", "renameSnapshot", "deleteSnapshot", "duplicateSnapshot", "previousSnapshot", "nextSnapshot"]),
            "id": XomoAutomationSchema.string(description: "History entry or snapshot UUID"),
            "name": XomoAutomationSchema.string(description: "Snapshot name")
        ], required: ["action"]),
        tool("xomo.canvas.resize_image", "Resize the image and all layer content.", sizeProperties, required: ["width", "height"]),
        tool("xomo.canvas.resize_canvas", "Resize the canvas without scaling layer content.", [
            "width": XomoAutomationSchema.number(description: "Canvas width"),
            "height": XomoAutomationSchema.number(description: "Canvas height"),
            "anchor": XomoAutomationSchema.string(description: "Canvas anchor", values: ImageEditorCanvasAnchor.allCases.map(\.rawValue))
        ], required: ["width", "height"]),
        tool("xomo.canvas.crop_to_selection", "Crop the document to the current selection."),
        tool("xomo.canvas.transform", "Rotate, flip, crop, trim, or reveal the complete canvas.", [
            "action": XomoAutomationSchema.string(description: "Canvas action", values: ["rotateClockwise", "rotateCounterclockwise", "rotate180", "flipHorizontal", "flipVertical", "cropCenter", "trimTransparent", "revealAll"])
        ], required: ["action"]),
        tool("xomo.component.list", "List editable Xomo UI components and themes."),
        tool("xomo.component.insert", "Insert an editable UI component as native layers.", [
            "component": XomoAutomationSchema.string(description: "Component identifier", values: XomoComponentKind.allCases.map(\.rawValue)),
            "theme": XomoAutomationSchema.string(description: "Optional theme", values: XomoComponentTheme.allCases.map(\.rawValue)),
            "x": XomoAutomationSchema.number(description: "Optional canvas x position"),
            "y": XomoAutomationSchema.number(description: "Optional canvas y position")
        ], required: ["component"]),
        tool("xomo.color.get", "Read foreground and background RGBA colors."),
        tool("xomo.color.set", "Set the foreground or background RGBA color.", [
            "target": XomoAutomationSchema.string(description: "Color target", values: ["foreground", "background"]),
            "red": XomoAutomationSchema.number(description: "Red from 0 to 1"),
            "green": XomoAutomationSchema.number(description: "Green from 0 to 1"),
            "blue": XomoAutomationSchema.number(description: "Blue from 0 to 1"),
            "alpha": XomoAutomationSchema.number(description: "Alpha from 0 to 1")
        ], required: ["red", "green", "blue"]),
        tool("xomo.color.swap", "Swap foreground and background colors."),
        tool("xomo.color.reset", "Reset foreground to black and background to white."),
        tool("xomo.brush.preset", "List, create, apply, or delete persisted brush presets.", [
            "action": XomoAutomationSchema.string(description: "Brush preset action", values: ["list", "create", "apply", "delete"]),
            "id": XomoAutomationSchema.string(description: "Preset identifier for apply or delete")
        ]),
        tool("xomo.paint.stroke", "Paint a brush or eraser stroke from canvas points.", [
            "tool": XomoAutomationSchema.string(description: "Stroke tool", values: ["brush", "eraser"]),
            "points": pointsSchema,
            "size": XomoAutomationSchema.number(description: "Brush diameter in pixels"),
            "opacity": XomoAutomationSchema.number(description: "Stroke opacity cap from 0 to 1"),
            "hardness": XomoAutomationSchema.number(description: "Edge hardness from 0 to 1"),
            "flow": XomoAutomationSchema.number(description: "Per-stamp flow from 1 to 100 percent"),
            "spacing": XomoAutomationSchema.number(description: "Stamp spacing from 1 to 200 percent of brush diameter"),
            "pressureSize": XomoAutomationSchema.boolean(description: "Use point pressure to control brush diameter"),
            "pressureFlow": XomoAutomationSchema.boolean(description: "Use point pressure to control per-stamp flow"),
            "pressureSensitivity": XomoAutomationSchema.number(description: "Pressure curve sensitivity from 0 to 100")
        ], required: ["points"]),
        tool("xomo.paint.gradient", "Paint a gradient between exactly two canvas points.", ["points": pointsSchema], required: ["points"]),
        tool("xomo.paint.special", "Use clone, tone, sponge, blur, sharpen, smudge, healing, red-eye, or paint-bucket tools.", [
            "action": XomoAutomationSchema.string(description: "Paint action", values: ["setCloneSource", "cloneStamp", "setHealingSource", "healing", "patch", "dodge", "burn", "sponge", "blur", "sharpen", "smudge", "redEye", "paintBucket"]),
            "points": pointsSchema,
            "x": XomoAutomationSchema.number(description: "Canvas x coordinate for point actions"),
            "y": XomoAutomationSchema.number(description: "Canvas y coordinate for point actions"),
            "size": XomoAutomationSchema.number(description: "Brush diameter"),
            "opacity": XomoAutomationSchema.number(description: "Brush opacity"),
            "feather": XomoAutomationSchema.number(description: "Patch selection feather radius"),
            "mode": XomoAutomationSchema.string(description: "Patch mode", values: ["source", "destination"]),
            "aligned": XomoAutomationSchema.boolean(description: "Keep the clone or healing source offset aligned across strokes"),
            "sampleSource": XomoAutomationSchema.string(description: "Clone or healing sampling layer range", values: ["currentLayer", "currentAndBelow", "allVisible"])
        ], required: ["action"]),
        tool("xomo.shape.create", "Create an editable rectangle or ellipse shape layer.", [
            "kind": XomoAutomationSchema.string(description: "Shape kind", values: ["rectangle", "ellipse"]),
            "x": XomoAutomationSchema.number(description: "Left coordinate"),
            "y": XomoAutomationSchema.number(description: "Top coordinate"),
            "width": XomoAutomationSchema.number(description: "Width"),
            "height": XomoAutomationSchema.number(description: "Height")
        ], required: ["kind", "x", "y", "width", "height"]),
        tool("xomo.shape.get", "Inspect the selected editable shape layer."),
        tool("xomo.shape.update", "Update selected shape fill opacity, stroke width, and foreground color.", [
            "opacity": XomoAutomationSchema.number(description: "Fill and stroke opacity"),
            "strokeWidth": XomoAutomationSchema.number(description: "Stroke width in pixels")
        ]),
        tool("xomo.text.create", "Create an editable text layer.", [
            "text": XomoAutomationSchema.string(description: "Text content"),
            "fontSize": XomoAutomationSchema.number(description: "Font size in points"),
            "boxWidth": XomoAutomationSchema.number(description: "Optional paragraph text box width"),
            "boxHeight": XomoAutomationSchema.number(description: "Optional fixed paragraph text box height"),
            "x": XomoAutomationSchema.number(description: "Optional canvas x position"),
            "y": XomoAutomationSchema.number(description: "Optional canvas y position")
        ], required: ["text"]),
        tool("xomo.text.get", "Inspect the selected editable text layer."),
        tool("xomo.text.update", "Update selected text content and typography.", [
            "text": XomoAutomationSchema.string(description: "Text content"),
            "fontSize": XomoAutomationSchema.number(description: "Font size"),
            "bold": XomoAutomationSchema.boolean(description: "Bold style"),
            "italic": XomoAutomationSchema.boolean(description: "Italic style"),
            "underline": XomoAutomationSchema.boolean(description: "Underline style"),
            "strikethrough": XomoAutomationSchema.boolean(description: "Strikethrough style"),
            "characterSpacing": XomoAutomationSchema.number(description: "Character spacing"),
            "lineSpacing": XomoAutomationSchema.number(description: "Line spacing"),
            "boxWidth": XomoAutomationSchema.number(description: "Text box width, zero for auto"),
            "boxHeight": XomoAutomationSchema.number(description: "Fixed text box height, zero for auto"),
            "alignment": XomoAutomationSchema.string(description: "Paragraph alignment", values: ImageEditorTextAlignment.allCases.map(\.rawValue)),
            "leftIndent": XomoAutomationSchema.number(description: "Paragraph left indent"),
            "rightIndent": XomoAutomationSchema.number(description: "Paragraph right indent"),
            "firstLineIndent": XomoAutomationSchema.number(description: "First-line indent relative to the left indent")
        ]),
        tool("xomo.text.convert", "Convert selected editable text layers between point and paragraph text.", [
            "mode": XomoAutomationSchema.string(description: "Target text layout mode", values: ImageEditorTextLayoutMode.allCases.map(\.rawValue))
        ], required: ["mode"]),
        tool("xomo.text.fitBox", "Fit selected paragraph text boxes to content or expand overflowing boxes.", [
            "mode": XomoAutomationSchema.string(description: "Text box fit mode", values: ImageEditorTextBoxFitMode.allCases.map(\.rawValue))
        ], required: ["mode"]),
        tool("xomo.mask.action", "Create, edit, copy, apply, rasterize, or delete raster and vector masks.", [
            "action": XomoAutomationSchema.string(description: "Mask action", values: ["addRevealAll", "addFromSelection", "addHideAll", "addHideSelection", "delete", "apply", "invert", "revealSelection", "hideSelection", "intersectSelection", "loadSelection", "copyToSelected", "toggleEnabled", "toggleLinked", "addVectorFromSelection", "copyVectorToSelected", "rasterizeVector", "loadVectorSelection", "toggleVectorEnabled", "deleteVector"])
        ], required: ["action"]),
        tool("xomo.path.get", "Inspect anchors, control handles, subpaths, closure, and active path selection."),
        tool("xomo.path.action", "Create and edit vector paths, anchors, subpaths, masks, fills, and strokes.", [
            "action": XomoAutomationSchema.string(description: "Path action", values: ["create", "select", "nextAnchor", "previousAnchor", "nextSubpath", "previousSubpath", "setAnchorX", "setAnchorY", "smoothAnchor", "symmetrizeHandles", "clearHandles", "moveSubpath", "duplicateSubpath", "deleteAnchor", "deleteSubpath", "insertAnchorAfter", "toggleClosed", "reverse", "strokeToPixelLayer", "fillToPixelLayer", "fromSelection", "loadSelection", "applyVectorMask", "applyLayerMask", "editVectorMask"]),
            "points": pointsSchema,
            "closed": XomoAutomationSchema.boolean(description: "Close a newly created path"),
            "subpath": XomoAutomationSchema.number(description: "Zero-based subpath index"),
            "anchor": XomoAutomationSchema.number(description: "Zero-based anchor index"),
            "role": XomoAutomationSchema.string(description: "Selected control role", values: ["anchor", "inHandle", "outHandle"]),
            "value": XomoAutomationSchema.number(description: "Anchor coordinate value"),
            "dx": XomoAutomationSchema.number(description: "Horizontal path delta"),
            "dy": XomoAutomationSchema.number(description: "Vertical path delta")
        ], required: ["action"]),
        tool("xomo.layer.effect", "Toggle a layer effect on selected layers.", [
            "effect": XomoAutomationSchema.string(description: "Layer effect", values: ["stroke", "shadow", "innerShadow", "outerGlow", "innerGlow", "colorOverlay", "gradientOverlay", "patternOverlay", "satin", "bevel"])
        ], required: ["effect"]),
        tool("xomo.guide.list", "List guides, grid, visibility, locks, and snapping settings."),
        tool("xomo.guide.add", "Add a horizontal or vertical guide.", [
            "orientation": XomoAutomationSchema.string(description: "Guide orientation", values: ImageEditorGuideOrientation.allCases.map(\.rawValue)),
            "position": XomoAutomationSchema.number(description: "Canvas position")
        ], required: ["orientation", "position"]),
        tool("xomo.guide.delete", "Delete a guide by UUID.", idProperties, required: ["id"]),
        tool("xomo.guide.clear", "Delete all guides."),
        tool("xomo.guide.settings", "Set guide and grid visibility, locks, and snapping.", [
            "visible": XomoAutomationSchema.boolean(description: "Guide visibility"),
            "locked": XomoAutomationSchema.boolean(description: "Guide lock state"),
            "snapping": XomoAutomationSchema.boolean(description: "Guide snapping"),
            "gridVisible": XomoAutomationSchema.boolean(description: "Grid visibility"),
            "gridSnapping": XomoAutomationSchema.boolean(description: "Grid snapping")
        ]),
        tool("xomo.view.zoom", "Set or change canvas zoom.", [
            "action": XomoAutomationSchema.string(description: "Zoom action", values: ["set", "in", "out", "actual", "fit"]),
            "value": XomoAutomationSchema.number(description: "Zoom factor for set action")
        ]),
        tool("xomo.smart_filter.list", "List smart filters on the selected layer."),
        tool("xomo.smart_filter.add", "Add a non-destructive smart filter to the selected layer.", [
            "filter": XomoAutomationSchema.string(description: "Filter identifier", values: ImageEditorFilter.allCases.map(\.rawValue)),
            "intensity": XomoAutomationSchema.number(description: "Filter intensity from 0 to 1")
        ], required: ["filter"]),
        tool("xomo.smart_filter.toggle", "Enable or disable a smart filter by UUID.", idProperties, required: ["id"]),
        tool("xomo.smart_filter.clear", "Remove all smart filters from selected layers."),
        tool("xomo.smart_filter.manage", "Update, remove, or reorder a smart filter.", [
            "id": XomoAutomationSchema.string(description: "Smart filter UUID"),
            "action": XomoAutomationSchema.string(description: "Management action", values: ["update", "remove", "moveUp", "moveDown"]),
            "intensity": XomoAutomationSchema.number(description: "Updated filter intensity")
        ], required: ["id", "action"]),
        tool("xomo.filter.list", "List raster filters."),
        tool("xomo.filter.apply", "Apply a raster filter to selected layers.", [
            "filter": XomoAutomationSchema.string(description: "Filter identifier", values: ImageEditorFilter.allCases.map(\.rawValue)),
            "intensity": XomoAutomationSchema.number(description: "Filter intensity from 0 to 1")
        ], required: ["filter"]),
        tool("xomo.filter.configure", "Configure detailed filter settings and apply, add, update, or create a smart filter.", [
            "filter": XomoAutomationSchema.string(description: "Filter identifier", values: ImageEditorFilter.allCases.map(\.rawValue)),
            "action": XomoAutomationSchema.string(description: "Filter destination", values: ["apply", "addLayer", "updateLayer", "addSmartFilter"]),
            "settings": filterSettingsSchema
        ], required: ["filter"]),
        tool("xomo.adjustment.list", "List image adjustments."),
        tool("xomo.adjustment.apply", "Apply an adjustment to selected layers.", [
            "adjustment": XomoAutomationSchema.string(description: "Adjustment identifier", values: ImageEditorAdjustment.allCases.map(\.rawValue)),
            "amount": XomoAutomationSchema.number(description: "Adjustment amount")
        ], required: ["adjustment"]),
        tool("xomo.adjustment.configure", "Configure detailed adjustment settings and apply, add, or update an adjustment layer.", [
            "adjustment": XomoAutomationSchema.string(description: "Adjustment identifier", values: ImageEditorAdjustment.allCases.map(\.rawValue)),
            "action": XomoAutomationSchema.string(description: "Adjustment destination", values: ["apply", "addLayer", "updateLayer"]),
            "settings": adjustmentSettingsSchema
        ], required: ["adjustment"]),
        tool("xomo.export.render", "Render the active document and return base64 encoded export data.", [
            "format": XomoAutomationSchema.string(description: "Export format", values: ImageEditorExportFormat.allCases.map(\.rawValue)),
            "scope": XomoAutomationSchema.string(description: "Export scope", values: ImageEditorExportScope.allCases.map(\.rawValue)),
            "scale": XomoAutomationSchema.number(description: "Bitmap export scale"),
            "quality": XomoAutomationSchema.number(description: "JPEG or WebP quality from 0 to 1")
        ])
    ]

    static func tool(
        _ name: String,
        _ description: String,
        _ properties: [String: XomoJSONValue] = [:],
        required: [String] = []
    ) -> XomoAutomationToolDefinition {
        XomoAutomationToolDefinition(
            name: name,
            description: description,
            inputSchema: XomoAutomationSchema.object(properties: properties, required: required)
        )
    }

    static let idProperties = ["id": XomoAutomationSchema.string(description: "Object UUID")]
    static let pointDeltaProperties = [
        "dx": XomoAutomationSchema.number(description: "Horizontal canvas delta"),
        "dy": XomoAutomationSchema.number(description: "Vertical canvas delta")
    ]
    static let pointProperties = [
        "x": XomoAutomationSchema.number(description: "Canvas x coordinate"),
        "y": XomoAutomationSchema.number(description: "Canvas y coordinate"),
        "pressure": XomoAutomationSchema.number(description: "Optional normalized pen pressure from 0 to 1")
    ]
    static let pointsSchema: XomoJSONValue = .object([
        "type": .string("array"),
        "items": .object([
            "type": .string("object"),
            "properties": .object(pointProperties),
            "required": .array([.string("x"), .string("y")]),
            "additionalProperties": .bool(false)
        ]),
        "minItems": .number(1)
    ])
    static let rectProperties = [
        "x": XomoAutomationSchema.number(description: "Left coordinate"),
        "y": XomoAutomationSchema.number(description: "Top coordinate"),
        "width": XomoAutomationSchema.number(description: "Width"),
        "height": XomoAutomationSchema.number(description: "Height")
    ]
    static let sizeProperties = [
        "width": XomoAutomationSchema.number(description: "Width"),
        "height": XomoAutomationSchema.number(description: "Height")
    ]
    static let adjustmentSettingsSchema = XomoAutomationSchema.object(properties: [
        "amount": XomoAutomationSchema.number(description: "Generic adjustment amount"),
        "levelsBlackPoint": XomoAutomationSchema.number(description: "Levels black point"),
        "levelsGamma": XomoAutomationSchema.number(description: "Levels gamma"),
        "levelsWhitePoint": XomoAutomationSchema.number(description: "Levels white point"),
        "curvesShadows": XomoAutomationSchema.number(description: "Curves shadows"),
        "curvesMidtones": XomoAutomationSchema.number(description: "Curves midtones"),
        "curvesHighlights": XomoAutomationSchema.number(description: "Curves highlights"),
        "hue": XomoAutomationSchema.number(description: "Hue shift"),
        "saturation": XomoAutomationSchema.number(description: "Saturation"),
        "lightness": XomoAutomationSchema.number(description: "Lightness"),
        "colorize": XomoAutomationSchema.boolean(description: "Colorize mode"),
        "brightness": XomoAutomationSchema.number(description: "Brightness"),
        "contrast": XomoAutomationSchema.number(description: "Contrast"),
        "exposureEV": XomoAutomationSchema.number(description: "Exposure EV"),
        "exposureOffset": XomoAutomationSchema.number(description: "Exposure offset"),
        "exposureGamma": XomoAutomationSchema.number(description: "Exposure gamma"),
        "shadows": XomoAutomationSchema.number(description: "Shadow recovery"),
        "highlights": XomoAutomationSchema.number(description: "Highlight recovery"),
        "vibrance": XomoAutomationSchema.number(description: "Vibrance"),
        "vibranceSaturation": XomoAutomationSchema.number(description: "Vibrance saturation"),
        "gradientReverse": XomoAutomationSchema.boolean(description: "Reverse gradient map"),
        "gradientDither": XomoAutomationSchema.boolean(description: "Dither gradient map"),
        "photoFilterDensity": XomoAutomationSchema.number(description: "Photo filter density"),
        "preserveLuminosity": XomoAutomationSchema.boolean(description: "Preserve luminosity")
    ])
    static let filterSettingsSchema = XomoAutomationSchema.object(properties: [
        "intensity": XomoAutomationSchema.number(description: "Filter intensity"),
        "unsharpRadius": XomoAutomationSchema.number(description: "Unsharp radius"),
        "unsharpThreshold": XomoAutomationSchema.number(description: "Unsharp threshold"),
        "liquifyPushX": XomoAutomationSchema.number(description: "Liquify horizontal push"),
        "liquifyPushY": XomoAutomationSchema.number(description: "Liquify vertical push"),
        "twirlAngle": XomoAutomationSchema.number(description: "Twirl angle"),
        "bulgeAmount": XomoAutomationSchema.number(description: "Bulge amount"),
        "offsetX": XomoAutomationSchema.number(description: "Horizontal offset"),
        "offsetY": XomoAutomationSchema.number(description: "Vertical offset"),
        "waveAmplitude": XomoAutomationSchema.number(description: "Wave amplitude"),
        "waveFrequency": XomoAutomationSchema.number(description: "Wave frequency"),
        "rippleAmount": XomoAutomationSchema.number(description: "Ripple amount"),
        "rippleFrequency": XomoAutomationSchema.number(description: "Ripple frequency"),
        "pinchAmount": XomoAutomationSchema.number(description: "Pinch amount"),
        "spherizeAmount": XomoAutomationSchema.number(description: "Spherize amount")
    ])

    static func idBoolProperties(key: String) -> [String: XomoJSONValue] {
        [
            "id": XomoAutomationSchema.string(description: "Layer UUID"),
            key: XomoAutomationSchema.boolean(description: "Desired \(key) state")
        ]
    }
}
