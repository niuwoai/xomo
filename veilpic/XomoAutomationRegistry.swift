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
    private static let maximumPSDInspectionBytes = 512 * 1024 * 1024
    private static let actionsRequiringActiveSelection: Set<String> = [
        "save",
        "similarColors",
        "growColor",
        "expand",
        "contract",
        "border",
        "smooth",
        "fillHoles",
        "removeSpeckles",
        "centerHorizontal",
        "centerVertical",
        "centerCanvas",
        "flipHorizontal",
        "flipVertical",
        "rotateClockwise",
        "rotateCounterclockwise",
        "rotate180",
        "scaleUp",
        "scaleDown",
        "fitCanvas",
        "nudge"
    ]
    private static let selectionEditActionsRequiringActiveSelection: Set<String> = [
        "fillForeground",
        "fillBackground",
        "stroke",
        "contentAwareFill",
        "clearPixels",
        "copyToLayer",
        "cutToLayer"
    ]

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
        return .object([
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
            return try documentResult(arguments, viewModel: viewModel)
        case "xomo.document.create":
            try createDocument(arguments, viewModel: viewModel)
        case "xomo.project.export":
            return try projectExportResult(viewModel)
        case "xomo.project.import":
            try importProject(arguments, viewModel: viewModel)
        case "xomo.import.image":
            try importImage(arguments, viewModel: viewModel)
        case "xomo.psd.inspect":
            return try psdInspectionResult(arguments)
        case "xomo.psd.open":
            return try psdOpenResult(arguments)
        case "xomo.psd.save":
            return try psdSaveResult(arguments, viewModel: viewModel)
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
            return try layersResult(arguments, viewModel: viewModel)
        case "xomo.layer.selection_bounds":
            return selectedLayerBoundsResult(viewModel)
        case "xomo.layer.transform_reference":
            return try transformReferenceAction(arguments, viewModel: viewModel)
        case "xomo.object.select_at":
            return try selectObjectAtPoint(arguments, viewModel: viewModel)
        case "xomo.figma.bindings":
            return try figmaBindingsAction(arguments, viewModel: viewModel)
        case "xomo.figma.link":
            return try figmaLinkResult(arguments)
        case "xomo.figma.component_properties":
            return try figmaComponentPropertiesAction(arguments, viewModel: viewModel)
        case "xomo.figma.size_constraints":
            return try figmaSizeConstraintsAction(arguments, viewModel: viewModel)
        case "xomo.figma.image_fill":
            return try figmaImageFillAction(arguments, viewModel: viewModel)
        case "xomo.layer.select":
            let id = try requiredUUID("id", in: arguments)
            viewModel.selectLayer(id, extendingSelection: arguments["extend"]?.boolValue ?? false)
        case "xomo.layer.create":
            try createLayer(arguments, viewModel: viewModel)
        case "xomo.layer.solid_color_fill_settings":
            return try solidColorFillSettingsAction(arguments, viewModel: viewModel)
        case "xomo.layer.adjustment_settings":
            return try adjustmentLayerSettingsAction(arguments, viewModel: viewModel)
        case "xomo.layer.filter_settings":
            return try filterLayerSettingsAction(arguments, viewModel: viewModel)
        case "xomo.layer.gradient_fill_settings":
            return try gradientFillSettingsAction(arguments, viewModel: viewModel)
        case "xomo.layer.pattern_fill_settings":
            return try patternFillSettingsAction(arguments, viewModel: viewModel)
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
            viewModel.beginSelectedLayerOpacityChange()
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
        case "xomo.layer.rasterize":
            try rasterizeLayerContent(arguments, viewModel: viewModel)
        case "xomo.layer.align":
            try layerAlignment(arguments, viewModel: viewModel)
        case "xomo.layer.style":
            if (arguments["action"]?.stringValue ?? "").hasPrefix("preset") {
                return try layerStylePresetAction(arguments, viewModel: viewModel)
            }
            return try layerStyleAction(arguments, viewModel: viewModel)
        case "xomo.layer.style_settings":
            return try layerStyleSetting(arguments, viewModel: viewModel)
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
        case "xomo.slice.create":
            return try sliceCreateResult(arguments, viewModel: viewModel)
        case "xomo.slice.list":
            return sliceListResult(viewModel)
        case "xomo.slice.delete":
            return try sliceDeleteResult(arguments, viewModel: viewModel)
        case "xomo.slice.update":
            return try sliceUpdateResult(arguments, viewModel: viewModel)
        case "xomo.hotspot.create":
            return try hotspotCreateResult(arguments, viewModel: viewModel)
        case "xomo.hotspot.list":
            return hotspotListResult(viewModel)
        case "xomo.hotspot.delete":
            return try hotspotDeleteResult(arguments, viewModel: viewModel)
        case "xomo.hotspot.update":
            return try hotspotUpdateResult(arguments, viewModel: viewModel)
        case "xomo.hotspot.export_html":
            return try hotspotHTMLExportResult(viewModel)
        case "xomo.selection.all":
            viewModel.selectAll()
        case "xomo.selection.rectangle":
            let rect = try requiredSelectionRect(arguments, canvasSize: viewModel.document.canvasSize)
            guard viewModel.createRectSelection(from: rect.origin, to: CGPoint(x: rect.maxX, y: rect.maxY)) else {
                throw XomoAutomationCallError.operationFailed("Rectangle selection failed")
            }
        case "xomo.selection.ellipse":
            let rect = try requiredSelectionRect(arguments, canvasSize: viewModel.document.canvasSize)
            viewModel.selectMarqueeShape(.ellipse)
            guard viewModel.createMarqueeSelection(from: rect.origin, to: CGPoint(x: rect.maxX, y: rect.maxY)) else {
                throw XomoAutomationCallError.operationFailed("Ellipse selection failed")
            }
        case "xomo.selection.lasso":
            let points = try requiredLassoPoints(arguments, canvasSize: viewModel.document.canvasSize)
            guard viewModel.createLassoSelection(points: points) else {
                throw XomoAutomationCallError.operationFailed("Lasso selection failed")
            }
        case "xomo.selection.magic":
            let point = try requiredPoint(arguments)
            let canvasBounds = CGRect(origin: .zero, size: viewModel.document.canvasSize)
            guard point.x.isFinite,
                  point.y.isFinite,
                  canvasBounds.contains(point)
            else {
                throw XomoAutomationCallError.invalidArgument("Magic-wand point is outside the canvas")
            }
            let tolerance = try selectionTolerance(arguments["tolerance"])
            if let contiguous = arguments["contiguous"]?.boolValue {
                viewModel.isMagicWandContiguous = contiguous
            }
            guard viewModel.createMagicSelection(
                at: point,
                tolerance: tolerance,
                contiguous: arguments["contiguous"]?.boolValue
            ) else {
                throw XomoAutomationCallError.operationFailed("Magic-wand sampling failed")
            }
        case "xomo.selection.quick":
            let points = try requiredPoints("points", in: arguments)
            let canvasBounds = CGRect(origin: .zero, size: viewModel.document.canvasSize)
            guard points.allSatisfy({ point in
                point.x.isFinite && point.y.isFinite && canvasBounds.contains(point)
            }) else {
                throw XomoAutomationCallError.invalidArgument("Quick-selection points must all be inside the canvas")
            }
            guard viewModel.createQuickSelection(
                points: points,
                tolerance: try selectionTolerance(arguments["tolerance"])
            ) else {
                throw XomoAutomationCallError.operationFailed("Quick-selection sampling failed")
            }
        case "xomo.selection.clear":
            viewModel.clearSelection()
        case "xomo.selection.invert":
            try requireActiveSelection(for: "invert", viewModel: viewModel)
            viewModel.invertSelection()
        case "xomo.selection.feather":
            try requireActiveSelection(for: "feather", viewModel: viewModel)
            viewModel.featherSelection(
                radius: try selectionRadius(arguments["radius"], maximum: 64)
            )
        case "xomo.selection.smooth":
            try requireActiveSelection(for: "smooth", viewModel: viewModel)
            viewModel.smoothSelection(
                radius: try selectionRadius(arguments["radius"], maximum: 16)
            )
        case "xomo.selection.edit":
            try selectionEdit(arguments, viewModel: viewModel)
        case "xomo.selection.modify":
            try selectionModify(arguments, viewModel: viewModel)
        case "xomo.selection.quick_mask":
            return try quickMaskAction(arguments, viewModel: viewModel)
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
        case "xomo.component.tokens":
            return try componentTokensResult(arguments, viewModel: viewModel)
        case "xomo.component.insert":
            try insertComponent(arguments, viewModel: viewModel)
        case "xomo.component.instance":
            return try componentInstanceAction(arguments, viewModel: viewModel)
        case "xomo.color.get":
            return colorResult(viewModel)
        case "xomo.color.set":
            try setColor(arguments, viewModel: viewModel)
        case "xomo.color.swap":
            viewModel.swapForegroundBackgroundColors()
        case "xomo.color.reset":
            viewModel.resetForegroundBackgroundColors()
        case "xomo.color_sampler.list":
            return colorSamplersResult(viewModel)
        case "xomo.color_sampler.add":
            let point = try requiredPoint(arguments)
            let sampleSize: ImageEditorColorSamplerSampleSize?
            if let rawSampleSize = arguments["sampleSize"]?.stringValue {
                guard let parsedSampleSize = ImageEditorColorSamplerSampleSize(
                    rawValue: rawSampleSize
                ) else {
                    throw XomoAutomationCallError.invalidArgument(
                        "Unsupported color sampler sample size: \(rawSampleSize)"
                    )
                }
                sampleSize = parsedSampleSize
            } else {
                sampleSize = nil
            }
            let sampleSource: ImageEditorColorSamplerSource?
            if let rawSampleSource = arguments["sampleSource"]?.stringValue {
                guard let parsedSampleSource = ImageEditorColorSamplerSource(
                    rawValue: rawSampleSource
                ) else {
                    throw XomoAutomationCallError.invalidArgument(
                        "Unsupported color sampler source: \(rawSampleSource)"
                    )
                }
                guard viewModel.canSampleColorSamplerSource(parsedSampleSource) else {
                    throw XomoAutomationCallError.invalidArgument(
                        "The selected layer cannot be sampled"
                    )
                }
                sampleSource = parsedSampleSource
            } else {
                sampleSource = nil
            }
            let ignoresAdjustmentLayers: Bool?
            if let value = arguments["ignoresAdjustmentLayers"] {
                guard let parsedValue = value.boolValue else {
                    throw XomoAutomationCallError.invalidArgument(
                        "ignoresAdjustmentLayers must be a boolean"
                    )
                }
                ignoresAdjustmentLayers = parsedValue
            } else {
                ignoresAdjustmentLayers = nil
            }
            guard viewModel.addColorSampler(
                at: point,
                sampleSize: sampleSize,
                source: sampleSource,
                ignoringAdjustmentLayers: ignoresAdjustmentLayers
            ),
                  let sample = viewModel.colorSamplerPoints.last
            else {
                throw XomoAutomationCallError.invalidArgument(
                    "Color sampler point must be inside the canvas"
                )
            }
            return colorSamplerJSON(
                sample,
                index: viewModel.colorSamplerPoints.count - 1,
                sampleSize: viewModel.selectedColorSamplerSampleSize,
                sampleSource: viewModel.activeColorSamplerSource,
                ignoresAdjustmentLayers:
                    viewModel.colorSamplerIgnoresAdjustmentLayers
            )
        case "xomo.color_sampler.move":
            let rawID = try requiredString("id", in: arguments)
            guard let id = UUID(uuidString: rawID),
                  viewModel.colorSamplerPoints.contains(where: { $0.id == id })
            else {
                throw XomoAutomationCallError.invalidArgument(
                    "Unknown color sampler id: \(rawID)"
                )
            }
            let point = try requiredPoint(arguments)
            guard viewModel.moveColorSampler(id: id, to: point),
                  let index = viewModel.colorSamplerPoints.firstIndex(where: {
                      $0.id == id
                  })
            else {
                throw XomoAutomationCallError.invalidArgument(
                    "Color sampler point must be inside the canvas"
                )
            }
            return colorSamplerJSON(
                viewModel.colorSamplerPoints[index],
                index: index,
                sampleSize: viewModel.selectedColorSamplerSampleSize,
                sampleSource: viewModel.activeColorSamplerSource,
                ignoresAdjustmentLayers:
                    viewModel.colorSamplerIgnoresAdjustmentLayers
            )
        case "xomo.color_sampler.remove":
            let rawID = try requiredString("id", in: arguments)
            guard let id = UUID(uuidString: rawID),
                  let index = viewModel.colorSamplerPoints.firstIndex(where: {
                      $0.id == id
                  }),
                  let removedSample = viewModel.removeColorSampler(id: id)
            else {
                throw XomoAutomationCallError.invalidArgument(
                    "Unknown color sampler id: \(rawID)"
                )
            }
            return .object([
                "removed": colorSamplerJSON(
                    removedSample,
                    index: index,
                    sampleSize: viewModel.selectedColorSamplerSampleSize,
                    sampleSource: viewModel.activeColorSamplerSource,
                    ignoresAdjustmentLayers:
                        viewModel.colorSamplerIgnoresAdjustmentLayers
                ),
                "remainingCount": .number(Double(viewModel.colorSamplerPoints.count))
            ])
        case "xomo.color_sampler.clear":
            let clearedCount = viewModel.clearColorSamplers()
            guard clearedCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No color samplers to clear"
                )
            }
            return .object([
                "clearedCount": .number(Double(clearedCount))
            ])
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
            let shapeKindRawValue = try requiredString("kind", in: arguments)
            guard let shapeKind = ImageEditorShapeKind(rawValue: shapeKindRawValue),
                  shapeKind == .rectangle || shapeKind == .ellipse
            else {
                throw XomoAutomationCallError.invalidArgument(
                    "Shape kind must be rectangle or ellipse"
                )
            }
            try validateShapeCreationCornerArguments(arguments, kind: shapeKind)
            let origin = try requiredPoint(arguments)
            let cornerRadius = try optionalNonnegativeNumber("cornerRadius", in: arguments)
            let cornerRadii = try optionalCornerRadii(arguments)
            let cornerSmoothing = try optionalUnitInterval("cornerSmoothing", in: arguments)
            try validateExclusiveCornerArguments(arguments)
            var fillGradient = try optionalShapeGradient(arguments)
            let fillGradientCenter = try optionalShapeGradientCenter(arguments)
            try validateShapeFillArguments(arguments, fillGradient: fillGradient)
            let fillKind = arguments["fillKind"]?.stringValue
            let gradientStyle = shapeGradientStyle(for: fillKind)
            if gradientStyle != nil, fillGradient == nil {
                throw XomoAutomationCallError.invalidArgument(
                    "fillGradient is required when creating a gradient fill"
                )
            }
            if let gradientStyle { fillGradient?.style = gradientStyle }
            let fillColor = try optionalColor("fillColor", in: arguments)
            let fillOpacity = try optionalUnitInterval("fillOpacity", in: arguments)
            let strokeColor = try optionalColor("strokeColor", in: arguments)
            let strokeOpacity = try optionalUnitInterval("strokeOpacity", in: arguments)
            let strokePosition = try optionalShapeStrokePosition(arguments["strokePosition"]?.stringValue)
            let strokeCap = try optionalShapeStrokeCap(arguments["strokeCap"]?.stringValue)
            let strokeJoin = try optionalShapeStrokeJoin(arguments["strokeJoin"]?.stringValue)
            let strokeWidth = try optionalShapeStrokeWidth(arguments["strokeWidth"])
            let strokeMiterLimit = try optionalShapeStrokeMiterLimit(arguments["strokeMiterLimit"])
            let strokeDashPattern = try optionalShapeStrokeDashPattern(arguments["strokeDashPattern"])
            let strokeDashOffset = try optionalShapeStrokeDashOffset(arguments["strokeDashOffset"])
            let width = try requiredNumber("width", in: arguments)
            let height = try requiredNumber("height", in: arguments)
            guard width > 3, height > 3 else {
                throw XomoAutomationCallError.invalidArgument(
                    "Shape width and height must both be greater than 3"
                )
            }
            let end = CGPoint(
                x: origin.x + width,
                y: origin.y + height
            )
            let layerCountBeforeCreate = viewModel.document.layers.count
            viewModel.drawShape(
                from: origin,
                to: end,
                ellipse: shapeKind == .ellipse,
                cornerRadius: cornerRadius,
                cornerRadii: cornerRadii,
                cornerSmoothing: cornerSmoothing,
                fillColor: fillColor,
                fillGradient: fillGradient,
                fillGradientCenter: fillGradientCenter,
                fillOpacity: fillOpacity,
                strokeColor: strokeColor,
                strokeOpacity: strokeOpacity,
                strokeWidth: strokeWidth,
                strokePosition: strokePosition,
                strokeCap: strokeCap,
                strokeJoin: strokeJoin,
                strokeMiterLimit: strokeMiterLimit,
                strokeDashPattern: strokeDashPattern,
                strokeDashOffset: strokeDashOffset
            )
            guard viewModel.document.layers.count == layerCountBeforeCreate + 1,
                  viewModel.document.selectedLayer?.shapeContent != nil
            else {
                throw XomoAutomationCallError.operationFailed("Shape creation failed")
            }
            return shapeCreationResult(viewModel)
        case "xomo.shape.get":
            return shapeResult(viewModel)
        case "xomo.shape.update":
            let updatedLayerCount = try updateShape(arguments, viewModel: viewModel)
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "xomo.text.create":
            let boxWidth = arguments["boxWidth"]?.doubleValue ?? 0
            let requestedBoxHeight = arguments["boxHeight"]?.doubleValue
            let textCase = try resolvedTextCase(
                arguments["textCase"]?.stringValue,
                fallback: .original
            )
            let boxHeight = try resolvedCreatedTextBoxHeight(
                autoHeight: arguments["autoHeight"]?.boolValue,
                boxWidth: boxWidth,
                requestedBoxHeight: requestedBoxHeight
            )
            let truncateOverflow = try resolvedTextOverflowTruncation(
                arguments["truncateOverflow"]?.boolValue ?? false,
                boxWidth: boxWidth,
                boxHeight: boxHeight
            )
            let verticalAlignment = try resolvedTextVerticalAlignment(
                arguments["verticalAlignment"]?.stringValue,
                fallback: .top,
                boxWidth: boxWidth,
                boxHeight: boxHeight
            )
            viewModel.textValue = try requiredString("text", in: arguments)
            if let fontSize = arguments["fontSize"]?.doubleValue { viewModel.textSize = fontSize }
            viewModel.textParagraphSpacing = arguments["paragraphSpacing"]?.doubleValue ?? 0
            viewModel.selectedTextCase = textCase
            viewModel.textBoxWidth = boxWidth
            viewModel.textBoxHeight = boxHeight
            viewModel.textTruncatesOverflow = truncateOverflow
            viewModel.selectedTextVerticalAlignment = verticalAlignment
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
        case "xomo.path.saved":
            return try savedPathAction(arguments, viewModel: viewModel)
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
        case "xomo.view.pan":
            return try panCanvas(arguments, viewModel: viewModel)
        case "xomo.smart_filter.list":
            return smartFiltersResult(viewModel)
        case "xomo.smart_filter.add":
            let rawValue = try requiredString("filter", in: arguments)
            guard let filter = ImageEditorFilter(rawValue: rawValue) else {
                throw XomoAutomationCallError.invalidArgument("Unknown filter: \(rawValue)")
            }
            viewModel.selectedFilter = filter
            if let intensity = arguments["intensity"]?.doubleValue { viewModel.filterIntensity = intensity }
            let blendMode = try smartFilterBlendMode(arguments["blendMode"]?.stringValue)
            let addedLayerCount = viewModel.addSmartFilterToSelectedLayer(
                opacity: arguments["opacity"]?.doubleValue ?? 1,
                blendMode: blendMode
            )
            guard addedLayerCount > 0 else {
                throw XomoAutomationCallError.invalidArgument("No selected layers can accept a smart filter")
            }
            return .object([
                "addedLayerCount": .number(Double(addedLayerCount))
            ])
        case "xomo.smart_filter.toggle":
            let toggledLayerCount = viewModel.toggleSmartFilterOnSelectedLayer(
                try requiredUUID("id", in: arguments)
            )
            guard toggledLayerCount > 0 else {
                throw XomoAutomationCallError.invalidArgument("Smart filter cannot be toggled")
            }
            return .object([
                "toggledLayerCount": .number(Double(toggledLayerCount))
            ])
        case "xomo.smart_filter.clear":
            let clearedLayerCount = viewModel.clearSmartFiltersFromSelectedLayer()
            guard clearedLayerCount > 0 else {
                throw XomoAutomationCallError.invalidArgument("No smart filters can be cleared")
            }
            return .object([
                "clearedLayerCount": .number(Double(clearedLayerCount))
            ])
        case "xomo.smart_filter.manage":
            if let result = try smartFilterManage(arguments, viewModel: viewModel) {
                return result
            }
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
            if let result = try configureFilter(arguments, viewModel: viewModel) {
                return result
            }
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

    private func histogramRangeLevel(
        named name: String,
        in arguments: [String: XomoJSONValue]
    ) throws -> Int? {
        guard let value = arguments[name] else { return nil }
        guard let number = value.doubleValue,
              number.isFinite,
              number.rounded() == number,
              number >= 0,
              number <= 255
        else {
            throw XomoAutomationCallError.invalidArgument(
                "\(name) must be an integer from 0 through 255"
            )
        }
        return Int(number)
    }

    private func documentResult(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws -> XomoJSONValue {
        let histogramChannel: ImageEditorHistogramChannel
        if let value = arguments["histogramChannel"] {
            guard let rawValue = value.stringValue else {
                throw XomoAutomationCallError.invalidArgument("histogramChannel must be a string")
            }
            guard let channel = ImageEditorHistogramChannel(rawValue: rawValue) else {
                throw XomoAutomationCallError.invalidArgument("Unknown histogram channel: \(rawValue)")
            }
            histogramChannel = channel
        } else {
            histogramChannel = viewModel.selectedHistogramChannel
        }

        let histogramSource: ImageEditorHistogramSource
        if let value = arguments["histogramSource"] {
            guard let rawValue = value.stringValue else {
                throw XomoAutomationCallError.invalidArgument("histogramSource must be a string")
            }
            guard let source = ImageEditorHistogramSource(rawValue: rawValue) else {
                throw XomoAutomationCallError.invalidArgument("Unknown histogram source: \(rawValue)")
            }
            guard viewModel.canInspectHistogramSource(source) else {
                throw XomoAutomationCallError.operationFailed(
                    "Histogram source is unavailable: \(rawValue)"
                )
            }
            histogramSource = source
        } else {
            histogramSource = viewModel.activeHistogramSource
        }
        let histogram = viewModel.histogramSummary(for: histogramSource)
        let lowerRangeLevel = try histogramRangeLevel(
            named: "histogramRangeLowerLevel",
            in: arguments
        )
        let upperRangeLevel = try histogramRangeLevel(
            named: "histogramRangeUpperLevel",
            in: arguments
        )
        let histogramRangeJSON: XomoJSONValue
        switch (lowerRangeLevel, upperRangeLevel) {
        case (nil, nil):
            histogramRangeJSON = .null
        case (.some(let lowerLevel), .some(let upperLevel)):
            guard lowerLevel <= upperLevel else {
                throw XomoAutomationCallError.invalidArgument(
                    "histogramRangeLowerLevel must not exceed histogramRangeUpperLevel"
                )
            }
            guard let lowerBinIndex = histogram.binIndex(forLevel: lowerLevel),
                  let upperBinIndex = histogram.binIndex(forLevel: upperLevel),
                  let range = histogram.rangeProbe(
                    channel: histogramChannel,
                    lowerBinIndex: lowerBinIndex,
                    upperBinIndex: upperBinIndex
                  )
            else {
                throw XomoAutomationCallError.operationFailed(
                    "Histogram range is unavailable"
                )
            }
            histogramRangeJSON = .object([
                "lowerLevel": .number(Double(range.lowerLevel)),
                "upperLevel": .number(Double(range.upperLevel)),
                "count": .number(Double(range.count)),
                "percentage": .number(range.percentage)
            ])
        default:
            throw XomoAutomationCallError.invalidArgument(
                "histogramRangeLowerLevel and histogramRangeUpperLevel must be provided together"
            )
        }

        return .object([
            "name": .string(viewModel.document.sourceName),
            "width": .number(viewModel.document.canvasSize.width),
            "height": .number(viewModel.document.canvasSize.height),
            "layerCount": .number(Double(viewModel.document.layers.count)),
            "alphaChannelCount": .number(Double(viewModel.document.alphaChannels.count)),
            "selectedLayerId": viewModel.document.selectedLayerID.map { .string($0.uuidString) } ?? .null,
            "tool": .string(viewModel.selectedTool.rawValue),
            "canvasOffset": pointJSON(CGPoint(
                x: viewModel.canvasOffset.width,
                y: viewModel.canvasOffset.height
            )),
            "zoom": .number(viewModel.zoom),
            "histogram": .object([
                "source": .string(histogramSource.rawValue),
                "channel": .string(histogramChannel.rawValue),
                "sampledPixelCount": .number(Double(histogram.sampledPixelCount)),
                "pixelCount": .number(Double(histogram.pixelCount)),
                "transparentPixelCount": .number(Double(histogram.transparentPixelCount)),
                "average": .number(histogramChannel.average(in: histogram)),
                "median": .number(histogramChannel.median(in: histogram)),
                "standardDeviation": .number(histogramChannel.standardDeviation(in: histogram)),
                "averageRed": .number(histogram.averageRed),
                "averageGreen": .number(histogram.averageGreen),
                "averageBlue": .number(histogram.averageBlue),
                "averageLuminance": .number(histogram.averageLuminance),
                "medianRed": .number(histogram.medianRed),
                "medianGreen": .number(histogram.medianGreen),
                "medianBlue": .number(histogram.medianBlue),
                "medianLuminance": .number(histogram.medianLuminance),
                "standardDeviationRed": .number(histogram.standardDeviationRed),
                "standardDeviationGreen": .number(histogram.standardDeviationGreen),
                "standardDeviationBlue": .number(histogram.standardDeviationBlue),
                "standardDeviationLuminance": .number(histogram.standardDeviationLuminance),
                "clippedShadowRatio": .number(histogram.clippedShadowRatio),
                "clippedHighlightRatio": .number(histogram.clippedHighlightRatio),
                "range": histogramRangeJSON,
                "bins": .array(histogram.bins.map {
                    .number(histogramChannel.value(in: $0))
                }),
                "binCounts": .array(histogram.bins.map {
                    .number(Double(histogramChannel.count(in: $0)))
                }),
                "binPercentiles": .array(histogram.bins.compactMap { bin in
                    histogram.probe(channel: histogramChannel, binIndex: bin.index).map {
                        .number($0.percentile)
                    }
                }),
                "binLevelRanges": .array(histogram.bins.compactMap { bin in
                    histogram.probe(channel: histogramChannel, binIndex: bin.index).map {
                        .object([
                            "lowerLevel": .number(Double($0.lowerLevel)),
                            "upperLevel": .number(Double($0.upperLevel))
                        ])
                    }
                })
            ]),
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
        let importsIntoSelection = arguments["intoSelection"]?.boolValue == true
        if importsIntoSelection, viewModel.document.selection == nil {
            throw XomoAutomationCallError.operationFailed(
                "Image import into selection requires an active selection"
            )
        }
        if importsIntoSelection, !viewModel.canImportImageIntoSelection {
            throw XomoAutomationCallError.operationFailed(
                "Image import into selection requires selected pixels inside the canvas"
            )
        }
        let didImportLayer: Bool
        if importsIntoSelection {
            didImportLayer = viewModel.importImageLayerIntoSelection(image, sourceName: name)
        } else {
            didImportLayer = viewModel.importImageLayer(image, sourceName: name)
        }
        guard didImportLayer else {
            throw XomoAutomationCallError.operationFailed("Image import did not create a layer")
        }
    }

    private func layersResult(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws -> XomoJSONValue {
        let bindingFilter = arguments["figmaBindings"]?.stringValue ?? "all"
        guard ["all", "bound", "unbound"].contains(bindingFilter) else {
            throw XomoAutomationCallError.invalidArgument(
                "Unknown Figma variable binding filter: \(bindingFilter)"
            )
        }
        let constraintFilter = arguments["figmaConstraints"]?.stringValue ?? "all"
        guard ["all", "constrained", "overridden", "conflicted"].contains(constraintFilter) else {
            throw XomoAutomationCallError.invalidArgument(
                "Unknown Figma size constraint filter: \(constraintFilter)"
            )
        }
        let sourceFilter = arguments["figmaSource"]?.stringValue ?? "all"
        guard ["all", "imported", "local"].contains(sourceFilter) else {
            throw XomoAutomationCallError.invalidArgument(
                "Unknown Figma source filter: \(sourceFilter)"
            )
        }
        let nodeTypeFilter = arguments["figmaNodeType"]?.stringValue.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        }
        if arguments["figmaNodeType"] != nil, nodeTypeFilter?.isEmpty != false {
            throw XomoAutomationCallError.invalidArgument("Figma node type filter must not be empty")
        }
        let nodeIDFilter = arguments["figmaNodeId"]?.stringValue.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "-", with: ":")
        }
        if arguments["figmaNodeId"] != nil, nodeIDFilter?.isEmpty != false {
            throw XomoAutomationCallError.invalidArgument("Figma node ID filter must be a non-empty string")
        }
        let fileKeyFilter = arguments["figmaFileKey"]?.stringValue.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if arguments["figmaFileKey"] != nil, fileKeyFilter?.isEmpty != false {
            throw XomoAutomationCallError.invalidArgument("Figma file key filter must be a non-empty string")
        }
        let resourceTypeFilter = arguments["figmaResourceType"]?.stringValue
        if arguments["figmaResourceType"] != nil,
           resourceTypeFilter.flatMap(XomoFigmaResourceType.init(rawValue:)) == nil {
            throw XomoAutomationCallError.invalidArgument(
                "Unknown Figma resource type filter: \(resourceTypeFilter ?? "non-string")"
            )
        }
        let importScopeFilter = arguments["figmaImportScope"]?.stringValue
        if arguments["figmaImportScope"] != nil,
           importScopeFilter.flatMap(XomoFigmaPlannedImportScope.init(rawValue:)) == nil {
            throw XomoAutomationCallError.invalidArgument(
                "Unknown Figma import scope filter: \(importScopeFilter ?? "non-string")"
            )
        }
        let componentRoleFilter: String
        if let componentRoleArgument = arguments["figmaComponentRole"] {
            guard let value = componentRoleArgument.stringValue else {
                throw XomoAutomationCallError.invalidArgument(
                    "Figma component role filter must be a string"
                )
            }
            componentRoleFilter = value
        } else {
            componentRoleFilter = "all"
        }
        let componentRoleValues = ["all", "none"] + XomoFigmaComponentRole.allCases.map(\.rawValue)
        guard componentRoleValues.contains(componentRoleFilter) else {
            throw XomoAutomationCallError.invalidArgument(
                "Unknown Figma component role filter: \(componentRoleFilter)"
            )
        }
        let layers = viewModel.document.layers.reversed().filter { layer in
            let matchesBindings: Bool
            switch bindingFilter {
            case "bound": matchesBindings = !layer.xomoFigmaVariableBindings.isEmpty
            case "unbound": matchesBindings = layer.xomoFigmaVariableBindings.isEmpty
            default: matchesBindings = true
            }
            guard matchesBindings else { return false }

            let matchesSource: Bool
            switch sourceFilter {
            case "imported": matchesSource = layer.xomoFigmaSourceID != nil
            case "local": matchesSource = layer.xomoFigmaSourceID == nil
            default: matchesSource = true
            }
            guard matchesSource else { return false }

            if let nodeTypeFilter,
               layer.xomoFigmaNodeType?.uppercased() != nodeTypeFilter {
                return false
            }

            if let nodeIDFilter,
               layer.xomoFigmaSourceID != nodeIDFilter {
                return false
            }

            let sourcePreview = fileKeyFilter != nil || resourceTypeFilter != nil || importScopeFilter != nil
                ? figmaSourcePreview(for: layer)
                : nil
            if let fileKeyFilter,
               sourcePreview?.fileKey != fileKeyFilter {
                return false
            }

            if let resourceTypeFilter,
               sourcePreview?.resourceType.rawValue != resourceTypeFilter {
                return false
            }

            if let importScopeFilter,
               sourcePreview?.plannedImportScope.rawValue != importScopeFilter {
                return false
            }

            let matchesComponentRole: Bool
            switch componentRoleFilter {
            case "none": matchesComponentRole = layer.xomoFigmaComponentRole == nil
            case "all": matchesComponentRole = true
            default: matchesComponentRole = layer.xomoFigmaComponentRole?.rawValue == componentRoleFilter
            }
            guard matchesComponentRole else { return false }

            let current = layer.xomoFigmaSizeConstraints ?? .empty
            switch constraintFilter {
            case "constrained": return !current.isEmpty
            case "overridden":
                return layer.xomoFigmaSizeConstraintDefaults.map { current != $0 } ?? false
            case "conflicted": return !current.conflicts.isEmpty
            default: return true
            }
        }
        return .array(layers.map { layer in
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
                "height": .number(layer.frame.height),
                "figmaVariableBindingCount": .number(Double(layer.xomoFigmaVariableBindings.count)),
                "figmaVariableBindings": .array(layer.xomoFigmaVariableBindings.map { binding in
                    .object([
                        "id": .string(binding.id),
                        "field": .string(binding.field),
                        "variableId": .string(binding.variableID)
                    ])
                }),
                "figmaImageFill": figmaImageFillJSON(layer.xomoFigmaImageFill),
                "figmaSizeConstraints": figmaSizeConstraintSummaryJSON(layer),
                "figmaSource": figmaSourceSummaryJSON(layer)
            ])
        })
    }

    private func figmaSourceSummaryJSON(_ layer: ImageEditorLayer) -> XomoJSONValue {
        guard let sourceID = layer.xomoFigmaSourceID else { return .null }
        let sourcePreview = figmaSourcePreview(for: layer)
        return .object([
            "id": .string(sourceID),
            "fileKey": sourcePreview.map { .string($0.fileKey) } ?? .null,
            "resourceType": sourcePreview.map { .string($0.resourceType.rawValue) } ?? .null,
            "importScope": sourcePreview.map { .string($0.plannedImportScope.rawValue) } ?? .null,
            "url": sourcePreview.map { .string($0.canonicalURL.absoluteString) } ?? .null,
            "nodeType": layer.xomoFigmaNodeType.map(XomoJSONValue.string) ?? .null,
            "componentRole": layer.xomoFigmaComponentRole.map {
                .string($0.rawValue)
            } ?? .null
        ])
    }

    private func figmaSourcePreview(for layer: ImageEditorLayer) -> XomoFigmaLinkPreview? {
        guard let sourceURL = XomoFigmaSourceOpenPolicy.canonicalURL(
            from: layer.xomoFigmaSourceURL,
            selectingNodeID: layer.xomoFigmaSourceID
        ),
              let preview = try? XomoFigmaLinkParser.parse(sourceURL.absoluteString)
        else { return nil }
        return preview
    }

    private func figmaSizeConstraintSummaryJSON(_ layer: ImageEditorLayer) -> XomoJSONValue {
        let current = layer.xomoFigmaSizeConstraints ?? .empty
        guard !current.isEmpty || layer.xomoFigmaSizeConstraintDefaults != nil else { return .null }

        func values(_ constraints: XomoFigmaSizeConstraints) -> XomoJSONValue {
            .object(Dictionary(uniqueKeysWithValues:
                XomoFigmaSizeConstraintField.allCases.map { field in
                    (field.rawValue, field.value(in: constraints).map(XomoJSONValue.number) ?? .null)
                }
            ))
        }

        let conflicts = current.conflicts
        return .object([
            "current": values(current),
            "importedDefaults": layer.xomoFigmaSizeConstraintDefaults.map(values) ?? .null,
            "hasImportedDefaults": .bool(layer.xomoFigmaSizeConstraintDefaults != nil),
            "hasOverrides": .bool(
                layer.xomoFigmaSizeConstraintDefaults.map { current != $0 } ?? false
            ),
            "hasConflicts": .bool(!conflicts.isEmpty),
            "conflicts": .array(conflicts.map { .string($0.rawValue) })
        ])
    }

    private func selectObjectAtPoint(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws -> XomoJSONValue {
        let point = try requiredPoint(arguments)
        let mode = arguments["mode"]?.stringValue ?? "auto"
        let extend = arguments["extend"]?.boolValue ?? false
        let selected: Bool

        switch mode {
        case "auto":
            selected = viewModel.selectXomoObject(at: point, extendingSelection: extend)
                || viewModel.selectVisibleLayer(at: point, extendingSelection: extend)
        case "component":
            selected = viewModel.selectXomoObject(at: point, extendingSelection: extend)
        case "deep":
            selected = viewModel.selectDeepestVisibleLayer(at: point, extendingSelection: extend)
        default:
            throw XomoAutomationCallError.invalidArgument("Unknown object selection mode: \(mode)")
        }

        if !selected, arguments["clearOnMiss"]?.boolValue == true {
            viewModel.clearLayerSelection()
        }

        guard selected, let layer = viewModel.document.selectedLayer else {
            return .object([
                "hit": .bool(false),
                "mode": .string(mode),
                "selectedLayerId": viewModel.document.selectedLayerID.map {
                    .string($0.uuidString)
                } ?? .null,
                "selectedLayerIds": .array(viewModel.document.selectedLayerIDs.map {
                    .string($0.uuidString)
                })
            ])
        }

        let bounds = viewModel.selectedXomoObjectFrame ?? layer.frame.standardized
        return .object([
            "hit": .bool(true),
            "mode": .string(mode),
            "selectedLayerId": .string(layer.id.uuidString),
            "selectedLayerIds": .array(viewModel.document.selectedLayerIDs.map {
                .string($0.uuidString)
            }),
            "name": .string(layer.name),
            "kind": .string(layerKindName(layer.kind)),
            "component": viewModel.selectedXomoObjectKind.map {
                .string($0.rawValue)
            } ?? .null,
            "bounds": .object([
                "x": .number(bounds.minX),
                "y": .number(bounds.minY),
                "width": .number(bounds.width),
                "height": .number(bounds.height)
            ])
        ])
    }

    private func selectedLayerBoundsResult(
        _ viewModel: ImageEditorViewModel
    ) -> XomoJSONValue {
        let selectedLayerIDs = viewModel.document.selectedLayerIDs
            .map(\.uuidString)
            .sorted()
        guard let bounds = (
            viewModel.movingObjectPreviewFrame
                ?? viewModel.selectedLayerTransformFrame
        )?.standardized,
              !bounds.isNull,
              !bounds.isEmpty
        else {
            return .object([
                "active": .bool(false),
                "preview": .bool(false),
                "selectedCount": .number(Double(selectedLayerIDs.count)),
                "selectedLayerIds": .array(selectedLayerIDs.map(XomoJSONValue.string))
            ])
        }
        let previewOperation: String?
        if viewModel.movingObjectPreviewFrame != nil {
            previewOperation = "move"
        } else if viewModel.isResizingSelectedLayer {
            previewOperation = "resize"
        } else if viewModel.rotatingPreviewDegrees != nil {
            previewOperation = "rotate"
        } else {
            previewOperation = nil
        }
        var result: [String: XomoJSONValue] = [
            "active": .bool(true),
            "preview": .bool(previewOperation != nil),
            "selectedCount": .number(Double(selectedLayerIDs.count)),
            "selectedLayerIds": .array(selectedLayerIDs.map(XomoJSONValue.string)),
            "bounds": .object([
                "x": .number(bounds.minX),
                "y": .number(bounds.minY),
                "width": .number(bounds.width),
                "height": .number(bounds.height)
            ])
        ]
        if let referencePoint = viewModel.selectedLayerTransformReferencePoint {
            result["referencePoint"] = .object([
                "x": .number(referencePoint.x),
                "y": .number(referencePoint.y),
                "custom": .bool(viewModel.hasCustomTransformReferencePoint)
            ])
        }
        if let previewOperation {
            result["operation"] = .string(previewOperation)
        }
        if let originalFrame = viewModel.activeTransformOriginalFrame {
            result["originalBounds"] = .object([
                "x": .number(originalFrame.minX),
                "y": .number(originalFrame.minY),
                "width": .number(originalFrame.width),
                "height": .number(originalFrame.height)
            ])
        }
        if let delta = viewModel.movingObjectPreviewDelta {
            result["delta"] = .object([
                "x": .number(delta.width),
                "y": .number(delta.height)
            ])
        }
        if let delta = viewModel.resizingObjectPreviewDelta {
            result["sizeDelta"] = .object([
                "width": .number(delta.width),
                "height": .number(delta.height)
            ])
        }
        if let scale = viewModel.resizingObjectPreviewScalePercent {
            result["scalePercent"] = .object([
                "width": .number(scale.width),
                "height": .number(scale.height)
            ])
        }
        if let degrees = viewModel.rotatingPreviewDegrees {
            result["rotationDeltaDegrees"] = .number(degrees)
        }
        return .object(result)
    }

    private func transformReferenceAction(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws -> XomoJSONValue {
        guard let originalPoint = viewModel.selectedLayerTransformReferencePoint else {
            throw XomoAutomationCallError.operationFailed("No transformable layer selection")
        }
        let action = try requiredString("action", in: arguments)
        let wasCustom = viewModel.hasCustomTransformReferencePoint
        let changed: Bool

        switch action {
        case "set":
            let point = try requiredPoint(arguments)
            viewModel.setSelectedLayerTransformReferencePoint(point)
            changed = !wasCustom || point != originalPoint
        case "reset":
            changed = viewModel.resetSelectedLayerTransformReferencePoint()
        default:
            throw XomoAutomationCallError.invalidArgument(
                "Unknown transform reference action: \(action)"
            )
        }

        guard let point = viewModel.selectedLayerTransformReferencePoint else {
            throw XomoAutomationCallError.operationFailed("Transform reference point became unavailable")
        }
        return .object([
            "action": .string(action),
            "changed": .bool(changed),
            "referencePoint": .object([
                "x": .number(point.x),
                "y": .number(point.y),
                "custom": .bool(viewModel.hasCustomTransformReferencePoint)
            ]),
            "selectedLayerIds": .array(
                viewModel.document.selectedLayerIDs
                    .map(\.uuidString)
                    .sorted()
                    .map(XomoJSONValue.string)
            )
        ])
    }

    private func figmaImageFillJSON(_ metadata: XomoFigmaImageFillMetadata?) -> XomoJSONValue {
        guard let metadata else { return .null }
        let transform: XomoJSONValue
        if let value = metadata.imageTransform {
            transform = .object([
                "m11": .number(value.m11),
                "m12": .number(value.m12),
                "translationX": .number(value.translationX),
                "m21": .number(value.m21),
                "m22": .number(value.m22),
                "translationY": .number(value.translationY)
            ])
        } else {
            transform = .null
        }
        return .object([
            "imageReference": .string(metadata.imageReference),
            "scaleMode": metadata.scaleMode.map { .string($0) } ?? .null,
            "imageTransform": transform,
            "scalingFactor": metadata.scalingFactor.map { .number($0) } ?? .null,
            "rotation": metadata.rotation.map { .number($0) } ?? .null,
            "filters": .object([
                "exposure": .number(metadata.filters.exposure),
                "contrast": .number(metadata.filters.contrast),
                "saturation": .number(metadata.filters.saturation),
                "temperature": .number(metadata.filters.temperature),
                "tint": .number(metadata.filters.tint),
                "highlights": .number(metadata.filters.highlights),
                "shadows": .number(metadata.filters.shadows)
            ])
        ])
    }

    private func figmaBindingsAction(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws -> XomoJSONValue {
        let action = try requiredString("action", in: arguments)
        let bindings = viewModel.selectedLayersFigmaVariableBindings
        let result: XomoJSONValue = .object([
            "count": .number(Double(bindings.count)),
            "variableIds": .array(bindings.map { .string($0.variableID) }),
            "bindings": .array(bindings.map { binding in
                .object([
                    "id": .string(binding.id),
                    "field": .string(binding.field),
                    "variableId": .string(binding.variableID)
                ])
            })
        ])
        switch action {
        case "list":
            return result
        case "copy":
            guard !bindings.isEmpty else {
                throw XomoAutomationCallError.invalidArgument(
                    "No selected Figma variable bindings"
                )
            }
            viewModel.copySelectedFigmaVariableBindings()
            return result
        default:
            throw XomoAutomationCallError.invalidArgument("Unknown Figma binding action")
        }
    }

    private func figmaImageFillAction(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws -> XomoJSONValue {
        let action = try requiredString("action", in: arguments)
        guard viewModel.document.selectedLayer?.xomoFigmaImageFill != nil else {
            throw XomoAutomationCallError.invalidArgument(
                "No selected Figma image fill"
            )
        }

        func result() -> XomoJSONValue {
            guard let layer = viewModel.document.selectedLayer,
                  let metadata = layer.xomoFigmaImageFill
            else {
                return .object(["imageFill": .null])
            }
            return .object([
                "layerId": .string(layer.id.uuidString),
                "editable": .bool(viewModel.canEditSelectedFigmaImageFill),
                "imageFill": figmaImageFillJSON(metadata)
            ])
        }

        switch action {
        case "list":
            return result()
        case "set":
            guard viewModel.canEditSelectedFigmaImageFill else {
                throw XomoAutomationCallError.operationFailed(
                    "Selected Figma image fill is locked or has no retained source image"
                )
            }
            switch try requiredString("property", in: arguments) {
            case "scaleMode":
                viewModel.updateSelectedFigmaImageFillScaleMode(
                    try requiredString("scaleMode", in: arguments)
                )
            case "scalingFactor":
                viewModel.updateSelectedFigmaImageFillScalingFactor(
                    try requiredNumber("value", in: arguments)
                )
            case "rotation":
                viewModel.updateSelectedFigmaImageFillRotation(
                    try requiredNumber("value", in: arguments)
                )
            case "offsetX":
                viewModel.updateSelectedFigmaImageFillOffsetX(
                    try requiredNumber("value", in: arguments)
                )
            case "offsetY":
                viewModel.updateSelectedFigmaImageFillOffsetY(
                    try requiredNumber("value", in: arguments)
                )
            case "m11":
                viewModel.updateSelectedFigmaImageFillMatrixM11(
                    try requiredNumber("value", in: arguments)
                )
            case "m12":
                viewModel.updateSelectedFigmaImageFillMatrixM12(
                    try requiredNumber("value", in: arguments)
                )
            case "m21":
                viewModel.updateSelectedFigmaImageFillMatrixM21(
                    try requiredNumber("value", in: arguments)
                )
            case "m22":
                viewModel.updateSelectedFigmaImageFillMatrixM22(
                    try requiredNumber("value", in: arguments)
                )
            case "filtersEnabled":
                viewModel.setSelectedFigmaImageFillFiltersEnabled(
                    try requiredBool("enabled", in: arguments)
                )
            default:
                throw XomoAutomationCallError.invalidArgument(
                    "Unknown Figma image fill property"
                )
            }
            return result()
        default:
            throw XomoAutomationCallError.invalidArgument(
                "Unknown Figma image fill action"
            )
        }
    }

    private func figmaLinkResult(
        _ arguments: [String: XomoJSONValue]
    ) throws -> XomoJSONValue {
        let input = try requiredString("url", in: arguments)
        let preview: XomoFigmaLinkPreview
        do {
            preview = try XomoFigmaLinkParser.parse(input)
        } catch let error as XomoFigmaLinkParserError {
            throw XomoAutomationCallError.invalidArgument(
                "Figma link rejected: \(error.localizationKey)"
            )
        }
        return .object([
            "resourceType": .string(preview.resourceType.rawValue),
            "fileKey": .string(preview.fileKey),
            "fileSlug": .string(preview.fileSlug),
            "displayName": .string(preview.displayName),
            "nodeId": preview.nodeID.map(XomoJSONValue.string) ?? .null,
            "startingPointNodeId": preview.startingPointNodeID.map(XomoJSONValue.string) ?? .null,
            "versionId": preview.versionID.map(XomoJSONValue.string) ?? .null,
            "canonicalUrl": .string(preview.canonicalURL.absoluteString),
            "discardedQueryItemCount": .number(Double(preview.discardedQueryItemCount)),
            "plannedImportScope": .string(preview.plannedImportScope.rawValue),
            "authorizationState": .string(preview.authorizationState.rawValue)
        ])
    }

    private func figmaComponentPropertiesAction(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws -> XomoJSONValue {
        let action = try requiredString("action", in: arguments)
        guard let layer = viewModel.document.selectedLayer,
              !layer.xomoFigmaComponentProperties.isEmpty
        else {
            throw XomoAutomationCallError.invalidArgument(
                "No selected Figma component properties"
            )
        }

        func result() -> XomoJSONValue {
            guard let currentLayer = viewModel.document.selectedLayer else {
                return .object(["properties": .object([:])])
            }
            var properties: [String: XomoJSONValue] = [:]
            for (key, property) in currentLayer.xomoFigmaComponentProperties {
                let preferredValues: [XomoJSONValue] = property.preferredValues.map { preferredValue in
                    .object([
                        "key": .string(preferredValue.key),
                        "name": .string(preferredValue.name)
                    ])
                }
                properties[key] = .object([
                    "type": .string(property.type),
                    "value": .string(property.value),
                    "preferredValues": .array(preferredValues),
                    "defaultValue": currentLayer.xomoFigmaComponentPropertyDefaults[key].map {
                        .string($0.value)
                    } ?? .null,
                    "overridden": .bool(viewModel.hasSelectedFigmaComponentPropertyOverride(key, property: property))
                ])
            }
            return .object([
                "layerId": .string(currentLayer.id.uuidString),
                "properties": .object(properties)
            ])
        }

        switch action {
        case "list":
            return result()
        case "set":
            let key = try requiredString("key", in: arguments)
            guard layer.xomoFigmaComponentProperties[key] != nil else {
                throw XomoAutomationCallError.notFound("Figma component property \(key)")
            }
            guard let value = arguments["value"]?.stringValue else {
                throw XomoAutomationCallError.invalidArgument("Missing string argument: value")
            }
            viewModel.updateSelectedFigmaComponentProperty(key, value: value)
            return result()
        case "reset":
            let key = try requiredString("key", in: arguments)
            guard layer.xomoFigmaComponentProperties[key] != nil else {
                throw XomoAutomationCallError.notFound("Figma component property \(key)")
            }
            guard layer.xomoFigmaComponentPropertyDefaults[key] != nil else {
                throw XomoAutomationCallError.operationFailed(
                    "Figma component property \(key) has no imported default"
                )
            }
            viewModel.resetSelectedFigmaComponentProperty(key)
            return result()
        default:
            throw XomoAutomationCallError.invalidArgument(
                "Unknown Figma component property action"
            )
        }
    }

    private func figmaSizeConstraintsAction(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws -> XomoJSONValue {
        let action = try requiredString("action", in: arguments)
        guard let layer = viewModel.document.selectedLayer,
              layer.xomoFigmaSourceID != nil
        else {
            throw XomoAutomationCallError.invalidArgument(
                "No selected Figma source layer"
            )
        }

        func field(from arguments: [String: XomoJSONValue]) throws -> XomoFigmaSizeConstraintField {
            let rawValue = try requiredString("field", in: arguments)
            guard let field = XomoFigmaSizeConstraintField(rawValue: rawValue) else {
                throw XomoAutomationCallError.invalidArgument(
                    "Unknown Figma size constraint field: \(rawValue)"
                )
            }
            return field
        }

        func conflict(from arguments: [String: XomoJSONValue]) throws -> XomoFigmaSizeConstraintConflict {
            let rawValue = try requiredString("axis", in: arguments)
            guard let conflict = XomoFigmaSizeConstraintConflict(rawValue: rawValue) else {
                throw XomoAutomationCallError.invalidArgument(
                    "Unknown Figma size constraint axis: \(rawValue)"
                )
            }
            return conflict
        }

        func constraintsJSON(_ constraints: XomoFigmaSizeConstraints?) -> XomoJSONValue {
            let resolved = constraints ?? .empty
            return .object(Dictionary(uniqueKeysWithValues:
                XomoFigmaSizeConstraintField.allCases.map { field in
                    (field.rawValue, field.value(in: resolved).map(XomoJSONValue.number) ?? .null)
                }
            ))
        }

        func result() -> XomoJSONValue {
            guard let currentLayer = viewModel.document.selectedLayer else {
                return .object([:])
            }
            let overrides = Dictionary(uniqueKeysWithValues:
                XomoFigmaSizeConstraintField.allCases.map { field in
                    (field.rawValue, XomoJSONValue.bool(
                        viewModel.hasSelectedFigmaSizeConstraintOverride(field)
                    ))
                }
            )
            let conflicts = (currentLayer.xomoFigmaSizeConstraints ?? .empty).conflicts
            return .object([
                "layerId": .string(currentLayer.id.uuidString),
                "current": constraintsJSON(currentLayer.xomoFigmaSizeConstraints),
                "importedDefaults": constraintsJSON(currentLayer.xomoFigmaSizeConstraintDefaults),
                "hasImportedDefaults": .bool(currentLayer.xomoFigmaSizeConstraintDefaults != nil),
                "hasOverrides": .bool(viewModel.hasSelectedFigmaSizeConstraintOverrides),
                "overrides": .object(overrides),
                "hasConflicts": .bool(!conflicts.isEmpty),
                "conflicts": .array(conflicts.map { .string($0.rawValue) })
            ])
        }

        switch action {
        case "list":
            return result()
        case "set":
            viewModel.setSelectedFigmaSizeConstraint(
                try field(from: arguments),
                value: try requiredNumber("value", in: arguments)
            )
            return result()
        case "clear":
            viewModel.setSelectedFigmaSizeConstraint(try field(from: arguments), value: nil)
            return result()
        case "reset":
            guard layer.xomoFigmaSizeConstraintDefaults != nil else {
                throw XomoAutomationCallError.operationFailed(
                    "Selected Figma layer has no imported size constraint defaults"
                )
            }
            viewModel.resetSelectedFigmaSizeConstraint(try field(from: arguments))
            return result()
        case "resetAll":
            guard layer.xomoFigmaSizeConstraintDefaults != nil else {
                throw XomoAutomationCallError.operationFailed(
                    "Selected Figma layer has no imported size constraint defaults"
                )
            }
            viewModel.resetAllSelectedFigmaSizeConstraints()
            return result()
        case "resolve":
            viewModel.resolveSelectedFigmaSizeConstraintConflict(try conflict(from: arguments))
            return result()
        case "resolveAll":
            viewModel.resolveAllSelectedFigmaSizeConstraintConflicts()
            return result()
        default:
            throw XomoAutomationCallError.invalidArgument(
                "Unknown Figma size constraint action"
            )
        }
    }

    private func componentInstanceAction(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws -> XomoJSONValue {
        let action = try requiredString("action", in: arguments)
        switch action {
        case "makeMaster":
            guard viewModel.canSetSelectedXomoComponentAsMaster else {
                throw XomoAutomationCallError.operationFailed("No applicable UI component is selected")
            }
            viewModel.setSelectedXomoComponentAsMaster()
        case "link":
            guard viewModel.canLinkSelectedXomoComponentsToMaster else {
                throw XomoAutomationCallError.operationFailed("No matching component master or link target is selected")
            }
            viewModel.linkSelectedXomoComponentsToMaster()
        case "sync":
            guard viewModel.canSyncSelectedXomoComponentMaster else {
                throw XomoAutomationCallError.operationFailed("No linked component instances are available to synchronize")
            }
            viewModel.syncSelectedXomoComponentMaster()
        case "detach":
            guard viewModel.canDetachSelectedXomoComponentInstances else {
                throw XomoAutomationCallError.operationFailed("No linked component instances are selected")
            }
            viewModel.detachSelectedXomoComponentInstances()
        default:
            throw XomoAutomationCallError.invalidArgument(
                "Unknown component instance action"
            )
        }
        return componentInstanceResult(action: action, viewModel: viewModel)
    }

    private func componentInstanceResult(
        action: String,
        viewModel: ImageEditorViewModel
    ) -> XomoJSONValue {
        let components = viewModel.document.layers.compactMap { layer -> XomoJSONValue? in
            guard layer.isGroup, let instance = layer.xomoComponentInstance else { return nil }
            return .object([
                "id": .string(layer.id.uuidString),
                "kind": .string(instance.kind.rawValue),
                "masterId": instance.masterID.map { .string($0.uuidString) } ?? .null,
                "isMaster": .bool(instance.masterID == layer.id)
            ])
        }
        return .object([
            "action": .string(action),
            "activeMasterId": viewModel.xomoActiveMasterID.map { .string($0.uuidString) } ?? .null,
            "components": .array(components)
        ])
    }

    private func selectionResult(_ viewModel: ImageEditorViewModel) -> XomoJSONValue {
        guard let selection = viewModel.document.selection,
              let selectedBounds = selection.effectiveSelectedBounds(
                in: viewModel.document.canvasSize
              )
        else { return .object(["active": .bool(false)]) }

        let canvasBounds = CGRect(origin: .zero, size: viewModel.document.canvasSize)
        let bounds = selectedBounds.standardized.integral.intersection(canvasBounds)
        guard !bounds.isNull, !bounds.isEmpty else {
            return .object(["active": .bool(false)])
        }
        return .object([
            "active": .bool(true),
            "inverted": .bool(selection.isInverted),
            "x": .number(bounds.minX),
            "y": .number(bounds.minY),
            "width": .number(bounds.width),
            "height": .number(bounds.height)
        ])
    }

    private func quickMaskResult(_ viewModel: ImageEditorViewModel) -> XomoJSONValue {
        .object([
            "active": .bool(viewModel.isQuickMaskMode),
            "hasSelection": .bool(viewModel.hasSelection),
            "target": .string(viewModel.quickMaskOverlayTarget.rawValue),
            "opacity": .number(viewModel.quickMaskOverlayOpacity),
            "color": colorJSON(viewModel.quickMaskOverlayColor),
            "overlayAvailable": .bool(viewModel.quickMaskOverlayImage != nil)
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

    private func componentTokensResult(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws -> XomoJSONValue {
        let action = arguments["action"]?.stringValue ?? "get"
        guard action == "get" || action == "export" || action == "import" || action == "apply" || action == "clear" || action == "refresh" else {
            throw XomoAutomationCallError.invalidArgument("Unknown component token action")
        }
        if action == "import" {
            let path = try requiredString("path", in: arguments)
            do {
                try viewModel.importXomoThemeTokens(from: URL(fileURLWithPath: path))
            } catch {
                throw XomoAutomationCallError.operationFailed(
                    "Theme token import failed: \(error.localizedDescription)"
                )
            }
            let data = try Data(viewModel.activeXomoComponentTokenSnapshot.encodedJSON().utf8)
            return .object([
                "path": .string(path),
                "filename": .string((path as NSString).lastPathComponent),
                "snapshot": try decodeJSONValue(data)
            ])
        }
        if action == "apply" {
            guard viewModel.canApplyXomoThemeToSelectedComponent else {
                throw XomoAutomationCallError.operationFailed(
                    "No applicable UI component is selected"
                )
            }
            viewModel.applyXomoThemeToSelectedComponent()
            let data = try Data(viewModel.activeXomoComponentTokenSnapshot.encodedJSON().utf8)
            return .object([
                "action": .string("apply"),
                "theme": .string(viewModel.xomoComponentTheme.rawValue),
                "snapshot": try decodeJSONValue(data)
            ])
        }
        if action == "clear" {
            guard viewModel.hasLocalXomoThemeTokens else {
                throw XomoAutomationCallError.operationFailed(
                    "No local component token mapping is active"
                )
            }
            viewModel.clearImportedXomoThemeTokens()
            let data = try Data(viewModel.activeXomoComponentTokenSnapshot.encodedJSON().utf8)
            return .object([
                "action": .string("clear"),
                "theme": .string(viewModel.xomoComponentTheme.rawValue),
                "snapshot": try decodeJSONValue(data)
            ])
        }
        if action == "refresh" {
            guard viewModel.canRefreshXomoThemeTokens else {
                throw XomoAutomationCallError.operationFailed(
                    "No mapped component uses local component tokens"
                )
            }
            viewModel.refreshXomoThemeTokensInDocument()
            let data = try Data(viewModel.activeXomoComponentTokenSnapshot.encodedJSON().utf8)
            return .object([
                "action": .string("refresh"),
                "count": .number(Double(viewModel.mappedXomoComponentGroupCount)),
                "theme": .string(viewModel.xomoComponentTheme.rawValue),
                "snapshot": try decodeJSONValue(data)
            ])
        }
        let theme: XomoComponentTheme
        if let rawTheme = arguments["theme"]?.stringValue {
            guard let requestedTheme = XomoComponentTheme(rawValue: rawTheme) else {
                throw XomoAutomationCallError.invalidArgument("Unknown theme: \(rawTheme)")
            }
            theme = requestedTheme
        } else {
            theme = viewModel.xomoComponentTheme
        }
        let snapshot = arguments["theme"] == nil
            ? viewModel.activeXomoComponentTokenSnapshot
            : theme.tokenSnapshot
        let json = try snapshot.encodedJSON()
        guard let data = json.data(using: .utf8) else {
            throw XomoAutomationCallError.operationFailed("Theme token JSON is not UTF-8")
        }
        if action == "get" {
            return try decodeJSONValue(data)
        }
        let path = try requiredString("path", in: arguments)
        do {
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        } catch {
            throw XomoAutomationCallError.operationFailed(
                "Theme token export failed: \(error.localizedDescription)"
            )
        }
        return .object([
            "path": .string(path),
            "filename": .string((path as NSString).lastPathComponent),
            "snapshot": try decodeJSONValue(data)
        ])
    }

    private func decodeJSONValue(_ data: Data) throws -> XomoJSONValue {
        do {
            return try JSONDecoder().decode(XomoJSONValue.self, from: data)
        } catch {
            throw XomoAutomationCallError.operationFailed(
                "Theme token JSON decode failed: (error.localizedDescription)"
            )
        }
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
        var resultPresets: [ImageEditorBrushPreset]?
        switch action {
        case "list", "favorites", "recent":
            let scopeRaw = arguments["scope"]?.stringValue
                ?? ImageEditorBrushPresetScope.all.rawValue
            guard let scope = ImageEditorBrushPresetScope(rawValue: scopeRaw) else {
                throw XomoAutomationCallError.invalidArgument(
                    "Brush preset scope must be all, builtIn, or custom"
                )
            }
            let sortOrderRaw = arguments["sortOrder"]?.stringValue
                ?? ImageEditorBrushPresetSortOrder.catalog.rawValue
            guard let sortOrder = ImageEditorBrushPresetSortOrder(rawValue: sortOrderRaw) else {
                throw XomoAutomationCallError.invalidArgument(
                    "Brush preset sortOrder must be catalog, nameAscending, or nameDescending"
                )
            }
            let collection: ImageEditorBrushPresetCollection
            switch action {
            case "favorites": collection = .favorites
            case "recent": collection = .recent
            default: collection = .all
            }
            resultPresets = ImageEditorBrushPresetQuery(
                searchText: arguments["query"]?.stringValue ?? "",
                scope: scope,
                collection: collection,
                sortOrder: sortOrder,
                favoriteIDs: Set(viewModel.favoriteBrushPresetIDs),
                recentIDs: viewModel.recentBrushPresetIDs
            ).filter(viewModel.brushPresets)
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
        case "favorite":
            let id = try requiredString("id", in: arguments)
            let isFavorite = try requiredBool("favorite", in: arguments)
            guard viewModel.setBrushPresetFavorite(id: id, isFavorite: isFavorite) else {
                throw XomoAutomationCallError.notFound("Brush preset \(id)")
            }
            resultPresets = viewModel.favoriteBrushPresets
        case "update":
            let id = try requiredString("id", in: arguments)
            guard viewModel.customBrushPresets.contains(where: { $0.id == id }) else {
                throw XomoAutomationCallError.notFound("Custom brush preset \(id)")
            }
            viewModel.updateCustomBrushPresetFromCurrentSettings(id: id)
        case "duplicate":
            let id = try requiredString("id", in: arguments)
            guard viewModel.customBrushPresets.contains(where: { $0.id == id }) else {
                throw XomoAutomationCallError.notFound("Custom brush preset \(id)")
            }
            guard viewModel.customBrushPresets.count < ImageEditorBrushPresetPreferences.maximumPresetCount else {
                throw XomoAutomationCallError.invalidArgument("Custom brush preset limit reached")
            }
            viewModel.duplicateCustomBrushPreset(id: id)
        case "moveToIndex":
            let id = try requiredString("id", in: arguments)
            guard viewModel.customBrushPresets.contains(where: { $0.id == id }) else {
                throw XomoAutomationCallError.notFound("Custom brush preset \(id)")
            }
            let rawIndex = try requiredNumber("index", in: arguments)
            guard rawIndex >= 0,
                  rawIndex < Double(viewModel.customBrushPresets.count),
                  rawIndex.rounded(.towardZero) == rawIndex
            else {
                throw XomoAutomationCallError.invalidArgument(
                    "Brush preset index must be a zero-based integer within the custom preset list"
                )
            }
            viewModel.moveCustomBrushPreset(id: id, toIndex: Int(rawIndex))
        case "inspectLibrary":
            let path = try requiredString("path", in: arguments)
            let url = URL(fileURLWithPath: path)
            let selectedIndexes = try optionalBrushPresetIndexes(arguments)
            let rawMode = arguments["inspectionMode"]?.stringValue
                ?? ImageEditorBrushPresetLibraryInspectionMode.replace.rawValue
            guard let mode = ImageEditorBrushPresetLibraryInspectionMode(rawValue: rawMode) else {
                throw XomoAutomationCallError.invalidArgument(
                    "Brush preset inspectionMode must be append or replace"
                )
            }
            let inspection: ImageEditorBrushPresetLibraryInspection
            let installationPlan: [ImageEditorBrushPresetLibraryInstallationPlanItem]
            do {
                inspection = try viewModel.inspectBrushPresetLibrary(
                    from: url,
                    mode: mode
                )
                installationPlan = try viewModel.brushPresetLibraryInstallationPlan(
                    inspection,
                    selectedIndexes: selectedIndexes
                )
            } catch {
                if let message = brushPresetLibraryArgumentMessage(error) {
                    throw XomoAutomationCallError.invalidArgument(message)
                }
                throw XomoAutomationCallError.operationFailed(
                    "Brush preset inspection failed: \(error.localizedDescription)"
                )
            }
            return .object([
                "path": .string(path),
                "filename": .string(url.lastPathComponent),
                "inspectionMode": .string(inspection.mode.rawValue),
                "presetCount": .number(Double(inspection.presetCount)),
                "installableCount": .number(Double(inspection.installableCount)),
                "skippedCount": .number(Double(inspection.skippedCount)),
                "titles": .array(inspection.presetTitles.map(XomoJSONValue.string)),
                "previews": .array(inspection.presetPreviews.map { preview in
                    .object([
                        "sourceIndex": .number(Double(preview.sourceIndex)),
                        "title": .string(preview.title),
                        "size": .number(Double(preview.size)),
                        "hardness": .number(Double(preview.hardness)),
                        "flow": .number(Double(preview.flow)),
                        "spacing": .number(Double(preview.spacing)),
                        "roundness": .number(Double(preview.tipRoundness)),
                        "angle": .number(Double(preview.tipAngleDegrees)),
                        "smoothing": .number(Double(preview.smoothing))
                    ])
                }),
                "plannedCount": .number(Double(installationPlan.count)),
                "renamedCount": .number(Double(
                    installationPlan.filter(\.isRenamed).count
                )),
                "plannedPresets": .array(installationPlan.map { item in
                    .object([
                        "sourceIndex": .number(Double(item.sourceIndex)),
                        "sourceTitle": .string(item.sourceTitle),
                        "installedTitle": .string(item.installedTitle),
                        "renamed": .bool(item.isRenamed)
                    ])
                })
            ])
        case "import":
            let path = try requiredString("path", in: arguments)
            let url = URL(fileURLWithPath: path)
            let selectedIndexes = try optionalBrushPresetIndexes(arguments)
            let existingIDs = Set(viewModel.customBrushPresets.map(\.id))
            let result: ImageEditorBrushPresetImportResult
            do {
                result = try viewModel.importBrushPresetLibrary(
                    from: url,
                    selectedIndexes: selectedIndexes
                )
            } catch {
                if let message = brushPresetLibraryArgumentMessage(error) {
                    throw XomoAutomationCallError.invalidArgument(message)
                }
                throw XomoAutomationCallError.operationFailed(
                    "Brush preset import failed: \(error.localizedDescription)"
                )
            }
            let importedPresets = viewModel.customBrushPresets.filter {
                !existingIDs.contains($0.id)
            }
            return .object([
                "path": .string(path),
                "filename": .string(url.lastPathComponent),
                "importedCount": .number(Double(result.importedCount)),
                "skippedCount": .number(Double(result.skippedCount)),
                "unselectedCount": .number(Double(result.unselectedCount)),
                "capacitySkippedCount": .number(Double(result.capacitySkippedCount)),
                "presets": brushPresetsResult(viewModel, presets: importedPresets)
            ])
        case "replace":
            let path = try requiredString("path", in: arguments)
            let url = URL(fileURLWithPath: path)
            let selectedIndexes = try optionalBrushPresetIndexes(arguments)
            let result: ImageEditorBrushPresetImportResult
            do {
                result = try viewModel.replaceBrushPresetLibrary(
                    from: url,
                    selectedIndexes: selectedIndexes
                )
            } catch {
                if let message = brushPresetLibraryArgumentMessage(error) {
                    throw XomoAutomationCallError.invalidArgument(message)
                }
                throw XomoAutomationCallError.operationFailed(
                    "Brush preset replacement failed: \(error.localizedDescription)"
                )
            }
            return .object([
                "path": .string(path),
                "filename": .string(url.lastPathComponent),
                "importedCount": .number(Double(result.importedCount)),
                "skippedCount": .number(Double(result.skippedCount)),
                "unselectedCount": .number(Double(result.unselectedCount)),
                "capacitySkippedCount": .number(Double(result.capacitySkippedCount)),
                "presets": brushPresetsResult(
                    viewModel,
                    presets: viewModel.customBrushPresets
                )
            ])
        case "resetLibrary":
            let removedCount = viewModel.resetCustomBrushPresetLibrary()
            return .object([
                "removedCount": .number(Double(removedCount)),
                "presets": brushPresetsResult(
                    viewModel,
                    presets: viewModel.brushPresets
                )
            ])
        case "export":
            let path = try requiredString("path", in: arguments)
            let presetIDs: [String]?
            if let id = arguments["id"]?.stringValue {
                guard viewModel.customBrushPresets.contains(where: { $0.id == id }) else {
                    throw XomoAutomationCallError.notFound("Custom brush preset \(id)")
                }
                presetIDs = [id]
            } else {
                guard !viewModel.customBrushPresets.isEmpty else {
                    throw XomoAutomationCallError.invalidArgument(
                        "No custom brush presets are available to export"
                    )
                }
                presetIDs = nil
            }
            let url = URL(fileURLWithPath: path)
            do {
                try viewModel.exportBrushPresetLibrary(to: url, presetIDs: presetIDs)
            } catch {
                throw XomoAutomationCallError.operationFailed(
                    "Brush preset export failed: \(error.localizedDescription)"
                )
            }
            return .object([
                "path": .string(path),
                "filename": .string(url.lastPathComponent),
                "presetCount": .number(Double(presetIDs?.count ?? viewModel.customBrushPresets.count))
            ])
        case "delete":
            let id = try requiredString("id", in: arguments)
            guard let preset = viewModel.customBrushPresets.first(where: { $0.id == id }) else {
                throw XomoAutomationCallError.notFound("Custom brush preset \(id)")
            }
            viewModel.deleteBrushPreset(preset)
        case "rename":
            let id = try requiredString("id", in: arguments)
            let name = try requiredString("name", in: arguments)
            guard viewModel.customBrushPresets.contains(where: { $0.id == id }) else {
                throw XomoAutomationCallError.notFound("Custom brush preset \(id)")
            }
            guard ImageEditorBrushPreset.normalizedCustomName(name) != nil else {
                throw XomoAutomationCallError.invalidArgument("Brush preset name cannot be empty")
            }
            viewModel.renameCustomBrushPreset(id: id, to: name)
        default:
            throw XomoAutomationCallError.invalidArgument("Unknown brush preset action: \(action)")
        }
        return brushPresetsResult(viewModel, presets: resultPresets)
    }

    private func brushPresetsResult(
        _ viewModel: ImageEditorViewModel,
        presets: [ImageEditorBrushPreset]? = nil
    ) -> XomoJSONValue {
        .array((presets ?? viewModel.brushPresets).map { preset in
            .object([
                "id": .string(preset.id),
                "title": .string(preset.title),
                "builtIn": .bool(preset.isBuiltIn),
                "active": .bool(viewModel.activeBrushPreset?.id == preset.id),
                "favorite": .bool(viewModel.isFavoriteBrushPreset(id: preset.id)),
                "recent": .bool(viewModel.recentBrushPresetIDs.contains(preset.id)),
                "size": .number(Double(preset.size)),
                "hardness": .number(Double(preset.hardness)),
                "flow": .number(Double(preset.flow)),
                "spacing": .number(Double(preset.spacing)),
                "pressureSize": .bool(preset.pressureControlsSize),
                "pressureOpacity": .bool(preset.pressureControlsOpacity),
                "pressureFlow": .bool(preset.pressureControlsFlow),
                "pressureSensitivity": .number(Double(preset.pressureSensitivity)),
                "minimumDiameter": .number(Double(preset.minimumDiameter)),
                "minimumOpacity": .number(Double(preset.minimumOpacity)),
                "minimumFlow": .number(Double(preset.minimumFlow)),
                "tiltShape": .bool(preset.tiltControlsShape),
                "roundness": .number(Double(preset.tipRoundness)),
                "angle": .number(Double(preset.tipAngleDegrees)),
                "smoothing": .number(Double(preset.smoothing))
            ])
        })
    }

    private func brushPresetLibraryArgumentMessage(_ error: Error) -> String? {
        switch error as? ImageEditorBrushPresetLibraryError {
        case .fileTooLarge:
            "Brush preset library exceeds the 5 MB limit"
        case .invalidFile:
            "File is not a valid .xomobrushes archive"
        case .unsupportedFormatVersion:
            "Brush preset library format version is not supported"
        case .emptyLibrary:
            "Brush preset library contains no presets"
        case .noMatchingPresets:
            "Brush preset library contains no matching presets"
        case .invalidPresetSelection:
            "Brush preset indexes must select existing entries from the source library"
        case .none:
            nil
        }
    }

    private func optionalBrushPresetIndexes(
        _ arguments: [String: XomoJSONValue]
    ) throws -> IndexSet? {
        guard let value = arguments["presetIndexes"] else { return nil }
        guard let values = value.arrayValue, !values.isEmpty else {
            throw XomoAutomationCallError.invalidArgument(
                "Brush preset indexes must be a nonempty array"
            )
        }
        var indexes = IndexSet()
        for value in values {
            guard let number = value.doubleValue,
                  number >= 0,
                  number.rounded(.towardZero) == number,
                  number <= Double(Int.max)
            else {
                throw XomoAutomationCallError.invalidArgument(
                    "Brush preset indexes must contain zero-based integers"
                )
            }
            let index = Int(number)
            guard !indexes.contains(index) else {
                throw XomoAutomationCallError.invalidArgument(
                    "Brush preset indexes must not contain duplicates"
                )
            }
            indexes.insert(index)
        }
        return indexes
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
            "textCase": .string(content.textCase.rawValue),
            "displayText": .string(content.displayText),
            "fontSize": .number(content.fontSize),
            "bold": .bool(content.isBold),
            "italic": .bool(content.isItalic),
            "underline": .bool(content.isUnderlined),
            "strikethrough": .bool(content.isStruckThrough),
            "characterSpacing": .number(content.characterSpacing),
            "lineSpacing": .number(content.lineSpacing),
            "paragraphSpacing": .number(content.paragraphSpacing),
            "boxWidth": .number(content.boxWidth),
            "boxHeight": .number(content.boxHeight),
            "autoHeight": .bool(content.layoutMode == .paragraph && content.boxHeight == 0),
            "requiredBoxHeight": .number(content.requiredParagraphHeight),
            "hasOverflow": .bool(content.hasOverflow),
            "truncateOverflow": .bool(content.truncatesOverflow),
            "verticalAlignment": .string(content.verticalAlignment.rawValue),
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
        let boxWidth = arguments["boxWidth"]?.doubleValue ?? content.boxWidth
        let boxHeight = try resolvedUpdatedTextBoxHeight(
            autoHeight: arguments["autoHeight"]?.boolValue,
            boxWidth: boxWidth,
            requestedBoxHeight: arguments["boxHeight"]?.doubleValue,
            content: content
        )
        let textCase = try resolvedTextCase(
            arguments["textCase"]?.stringValue,
            fallback: content.textCase
        )
        let truncateOverflow = try resolvedTextOverflowTruncation(
            arguments["truncateOverflow"]?.boolValue
                ?? (boxWidth > 0 && boxHeight > 0 ? content.truncatesOverflow : false),
            boxWidth: boxWidth,
            boxHeight: boxHeight
        )
        let verticalAlignment = try resolvedTextVerticalAlignment(
            arguments["verticalAlignment"]?.stringValue,
            fallback: content.verticalAlignment,
            boxWidth: boxWidth,
            boxHeight: boxHeight
        )
        viewModel.textValue = arguments["text"]?.stringValue ?? content.text
        viewModel.textSize = arguments["fontSize"]?.doubleValue ?? content.fontSize
        viewModel.textBold = arguments["bold"]?.boolValue ?? content.isBold
        viewModel.textItalic = arguments["italic"]?.boolValue ?? content.isItalic
        viewModel.textUnderlined = arguments["underline"]?.boolValue ?? content.isUnderlined
        viewModel.textStruckThrough = arguments["strikethrough"]?.boolValue ?? content.isStruckThrough
        viewModel.textCharacterSpacing = arguments["characterSpacing"]?.doubleValue ?? content.characterSpacing
        viewModel.textLineSpacing = arguments["lineSpacing"]?.doubleValue ?? content.lineSpacing
        viewModel.textParagraphSpacing = arguments["paragraphSpacing"]?.doubleValue ?? content.paragraphSpacing
        viewModel.selectedTextCase = textCase
        viewModel.textBoxWidth = boxWidth
        viewModel.textBoxHeight = boxHeight
        viewModel.textTruncatesOverflow = truncateOverflow
        viewModel.selectedTextVerticalAlignment = verticalAlignment
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

    private func resolvedTextCase(
        _ rawValue: String?,
        fallback: ImageEditorTextCase
    ) throws -> ImageEditorTextCase {
        guard let rawValue else { return fallback }
        guard let textCase = ImageEditorTextCase(rawValue: rawValue) else {
            throw XomoAutomationCallError.invalidArgument("Unknown text case: \(rawValue)")
        }
        return textCase
    }

    private func resolvedTextOverflowTruncation(
        _ enabled: Bool,
        boxWidth: Double,
        boxHeight: Double
    ) throws -> Bool {
        guard enabled else { return false }
        guard boxWidth > 0, boxHeight > 0 else {
            throw XomoAutomationCallError.invalidArgument(
                "truncateOverflow requires a fixed-height paragraph text box"
            )
        }
        return true
    }

    private func resolvedTextVerticalAlignment(
        _ rawValue: String?,
        fallback: ImageEditorTextVerticalAlignment,
        boxWidth: Double,
        boxHeight: Double
    ) throws -> ImageEditorTextVerticalAlignment {
        guard let rawValue else {
            return boxWidth > 0 && boxHeight > 0 ? fallback : .top
        }
        guard let alignment = ImageEditorTextVerticalAlignment(rawValue: rawValue) else {
            throw XomoAutomationCallError.invalidArgument(
                "Unknown text vertical alignment: \(rawValue)"
            )
        }
        guard boxWidth > 0, boxHeight > 0 else {
            throw XomoAutomationCallError.invalidArgument(
                "verticalAlignment requires a fixed-height paragraph text box"
            )
        }
        return alignment
    }

    private func resolvedCreatedTextBoxHeight(
        autoHeight: Bool?,
        boxWidth: Double,
        requestedBoxHeight: Double?
    ) throws -> Double {
        guard let autoHeight else { return requestedBoxHeight ?? 0 }
        guard boxWidth > 0 else {
            throw XomoAutomationCallError.invalidArgument("autoHeight requires a paragraph text box width")
        }
        if autoHeight {
            guard requestedBoxHeight == nil else {
                throw XomoAutomationCallError.invalidArgument("autoHeight cannot be combined with boxHeight")
            }
            return 0
        }
        guard let requestedBoxHeight, requestedBoxHeight > 0 else {
            throw XomoAutomationCallError.invalidArgument("Fixed-height text requires a positive boxHeight")
        }
        return requestedBoxHeight
    }

    private func resolvedUpdatedTextBoxHeight(
        autoHeight: Bool?,
        boxWidth: Double,
        requestedBoxHeight: Double?,
        content: ImageEditorTextContent
    ) throws -> Double {
        guard let autoHeight else { return requestedBoxHeight ?? content.boxHeight }
        guard boxWidth > 0 else {
            throw XomoAutomationCallError.invalidArgument("autoHeight requires a paragraph text box width")
        }
        if autoHeight {
            guard requestedBoxHeight == nil else {
                throw XomoAutomationCallError.invalidArgument("autoHeight cannot be combined with boxHeight")
            }
            return 0
        }
        if let requestedBoxHeight {
            guard requestedBoxHeight > 0 else {
                throw XomoAutomationCallError.invalidArgument("Fixed-height text requires a positive boxHeight")
            }
            return requestedBoxHeight
        }
        return Double(content.boxHeight > 0
            ? content.boxHeight
            : min(ImageEditorTextContent.maximumBoxDimension, max(1, content.requiredParagraphHeight)))
    }

    private func shapeResult(_ viewModel: ImageEditorViewModel) -> XomoJSONValue {
        guard let layer = viewModel.document.selectedLayer,
              let content = layer.shapeContent
        else { return .object(["active": .bool(false)]) }
        return .object([
            "active": .bool(true),
            "layerId": .string(layer.id.uuidString),
            "name": .string(layer.name),
            "x": .number(layer.frame.minX),
            "y": .number(layer.frame.minY),
            "width": .number(layer.frame.width),
            "height": .number(layer.frame.height),
            "kind": .string(content.kind.rawValue),
            "fillKind": .string(shapeFillKind(content.fillGradient)),
            "fillColor": colorJSON(content.fillColor),
            "fillGradient": content.fillGradient.map {
                shapeGradientJSON($0, center: content.fillGradientCenter)
            } ?? .null,
            "fillOpacity": .number(content.fillOpacity),
            "strokeColor": colorJSON(content.strokeColor),
            "strokeOpacity": .number(content.strokeOpacity),
            "strokeWidth": .number(content.strokeWidth),
            "strokePosition": .string(content.strokePosition.rawValue),
            "strokeCap": .string(content.strokeCap.rawValue),
            "strokeStartDecoration": .string(content.strokeStartDecoration.rawValue),
            "strokeEndDecoration": .string(content.strokeEndDecoration.rawValue),
            "supportsStrokeDecorations": .bool(content.kind == .path && !content.isPathClosed),
            "strokeJoin": .string(content.strokeJoin.rawValue),
            "strokeMiterLimit": .number(content.strokeMiterLimit),
            "strokeDashPattern": .array(content.strokeDashPattern.map {
                .number(Double($0))
            }),
            "strokeDashOffset": .number(Double(content.strokeDashOffset)),
            "cornerRadius": .number(content.cornerRadius),
            "cornerRadii": cornerRadiiJSON(content.effectiveCornerRadii),
            "cornerSmoothing": .number(content.cornerSmoothing),
            "usesIndependentCornerRadii": .bool(content.cornerRadii != nil)
        ])
    }

    private func shapeCreationResult(_ viewModel: ImageEditorViewModel) -> XomoJSONValue {
        guard var result = shapeResult(viewModel).objectValue,
              let layerID = viewModel.document.selectedLayerID
        else { return actionResult(viewModel) }
        result["created"] = .bool(true)
        result["selectedLayerId"] = .string(layerID.uuidString)
        result["historyCount"] = .number(Double(viewModel.document.history.count))
        result["status"] = .string(viewModel.statusText)
        return .object(result)
    }

    private func updateShape(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws -> Int {
        guard viewModel.document.selectedLayer?.shapeContent != nil else {
            throw XomoAutomationCallError.operationFailed("No selected shape layer")
        }
        try validateExclusiveCornerArguments(arguments)
        let cornerRadius = try optionalNonnegativeNumber("cornerRadius", in: arguments)
        let cornerRadii = try optionalCornerRadii(arguments)
        let cornerSmoothing = try optionalUnitInterval("cornerSmoothing", in: arguments)
        let fillGradient = try optionalShapeGradient(arguments)
        let fillGradientCenter = try optionalShapeGradientCenter(arguments)
        try validateShapeFillArguments(arguments, fillGradient: fillGradient)
        let fillKind = arguments["fillKind"]?.stringValue
        let strokePosition = try optionalShapeStrokePosition(arguments["strokePosition"]?.stringValue)
        let strokeCap = try optionalShapeStrokeCap(arguments["strokeCap"]?.stringValue)
        let strokeStartDecoration = try optionalShapeStrokeDecoration(
            arguments["strokeStartDecoration"]?.stringValue,
            argumentName: "strokeStartDecoration"
        )
        let strokeEndDecoration = try optionalShapeStrokeDecoration(
            arguments["strokeEndDecoration"]?.stringValue,
            argumentName: "strokeEndDecoration"
        )
        try validateShapeStrokeDecorationTargets(
            viewModel,
            isRequested: strokeStartDecoration != nil || strokeEndDecoration != nil
        )
        let strokeJoin = try optionalShapeStrokeJoin(arguments["strokeJoin"]?.stringValue)
        let strokeWidth = try optionalShapeStrokeWidth(arguments["strokeWidth"])
        let strokeMiterLimit = try optionalShapeStrokeMiterLimit(arguments["strokeMiterLimit"])
        let strokeDashPattern = try optionalShapeStrokeDashPattern(arguments["strokeDashPattern"])
        let strokeDashOffset = try optionalShapeStrokeDashOffset(arguments["strokeDashOffset"])
        let legacyOpacity = try optionalUnitInterval("opacity", in: arguments)
        let fillOpacity = try optionalUnitInterval("fillOpacity", in: arguments) ?? legacyOpacity
        let strokeOpacity = try optionalUnitInterval("strokeOpacity", in: arguments) ?? legacyOpacity
        let selectedContent = viewModel.document.selectedLayer?.shapeContent
        var resolvedGradient: ImageEditorGradientFillContent?
        let requestedGradientStyle = shapeGradientStyle(for: fillKind)
        if requestedGradientStyle != nil,
           fillGradient == nil,
           let selectedContent {
            resolvedGradient = selectedContent.fillGradient ?? .shapeLinear(
                startColor: selectedContent.fillColor,
                endColor: viewModel.backgroundColor
            )
        } else {
            resolvedGradient = fillGradient
        }
        if let requestedGradientStyle {
            resolvedGradient?.style = requestedGradientStyle
        } else if fillKind == nil, let existingStyle = selectedContent?.fillGradient?.style {
            resolvedGradient?.style = existingStyle
        }
        let updatedLayerCount = viewModel.updateSelectedShapeProperties(
            fillColor: try optionalColor("fillColor", in: arguments),
            fillGradient: resolvedGradient,
            fillGradientCenter: fillGradientCenter,
            clearsFillGradient: fillKind == "solid",
            fillOpacity: fillOpacity,
            strokeColor: try optionalColor("strokeColor", in: arguments),
            strokeOpacity: strokeOpacity,
            strokeWidth: strokeWidth,
            strokePosition: strokePosition,
            strokeCap: strokeCap,
            strokeStartDecoration: strokeStartDecoration,
            strokeEndDecoration: strokeEndDecoration,
            strokeJoin: strokeJoin,
            strokeMiterLimit: strokeMiterLimit,
            strokeDashPattern: strokeDashPattern,
            strokeDashOffset: strokeDashOffset,
            cornerRadius: cornerRadius,
            cornerRadii: cornerRadii,
            cornerSmoothing: cornerSmoothing
        )
        guard updatedLayerCount > 0 else {
            throw XomoAutomationCallError.operationFailed("Shape update made no changes")
        }
        return updatedLayerCount
    }

    private func optionalShapeStrokePosition(
        _ value: String?
    ) throws -> ImageEditorStrokePosition? {
        guard let value else { return nil }
        guard let position = ImageEditorStrokePosition(rawValue: value) else {
            throw XomoAutomationCallError.invalidArgument(
                "strokePosition must be outside, center, or inside"
            )
        }
        return position
    }

    private func optionalShapeStrokeCap(_ value: String?) throws -> ImageEditorStrokeCap? {
        guard let value else { return nil }
        guard let cap = ImageEditorStrokeCap(rawValue: value) else {
            throw XomoAutomationCallError.invalidArgument(
                "strokeCap must be butt, round, or square"
            )
        }
        return cap
    }

    private func optionalShapeStrokeDecoration(
        _ value: String?,
        argumentName: String
    ) throws -> ImageEditorStrokeDecoration? {
        guard let value else { return nil }
        guard let decoration = ImageEditorStrokeDecoration(rawValue: value) else {
            throw XomoAutomationCallError.invalidArgument(
                "\(argumentName) must be none, openArrow, filledArrow, filledTriangle, filledDiamond, or filledCircle"
            )
        }
        return decoration
    }

    private func validateShapeStrokeDecorationTargets(
        _ viewModel: ImageEditorViewModel,
        isRequested: Bool
    ) throws {
        guard isRequested else { return }
        let selectedIDs: Set<UUID>
        if viewModel.document.selectedLayerIDs.isEmpty,
           let selectedLayerID = viewModel.document.selectedLayerID {
            selectedIDs = [selectedLayerID]
        } else {
            selectedIDs = viewModel.document.selectedLayerIDs
        }
        let targets = viewModel.document.layers.filter { layer in
            selectedIDs.contains(layer.id)
                && layer.shapeContent != nil
                && !viewModel.document.isEffectivelyPixelsLocked(layer)
        }
        guard !targets.isEmpty,
              targets.allSatisfy({ layer in
                  guard let content = layer.shapeContent else { return false }
                  return content.kind == .path && !content.isPathClosed
              })
        else {
            throw XomoAutomationCallError.invalidArgument(
                "Stroke endpoint decorations require every editable shape target to be an open path"
            )
        }
    }

    private func optionalShapeStrokeJoin(_ value: String?) throws -> ImageEditorStrokeJoin? {
        guard let value else { return nil }
        guard let join = ImageEditorStrokeJoin(rawValue: value) else {
            throw XomoAutomationCallError.invalidArgument(
                "strokeJoin must be miter, round, or bevel"
            )
        }
        return join
    }

    private func optionalShapeStrokeMiterLimit(
        _ value: XomoJSONValue?
    ) throws -> Double? {
        guard let value else { return nil }
        guard let limit = value.doubleValue,
              limit.isFinite,
              limit >= Double(ImageEditorShapeContent.minimumStrokeMiterLimit),
              limit <= Double(ImageEditorShapeContent.maximumStrokeMiterLimit)
        else {
            throw XomoAutomationCallError.invalidArgument(
                "strokeMiterLimit must be a number from 1 through 1000"
            )
        }
        return limit
    }

    private func optionalShapeStrokeWidth(_ value: XomoJSONValue?) throws -> Double? {
        guard let value else { return nil }
        guard let width = value.doubleValue,
              width.isFinite,
              width >= Double(ImageEditorShapeContent.minimumStrokeWidth),
              width <= Double(ImageEditorShapeContent.maximumStrokeWidth)
        else {
            throw XomoAutomationCallError.invalidArgument(
                "strokeWidth must be a number from 0.1 through 96"
            )
        }
        return width
    }

    private func optionalUnitInterval(
        _ key: String,
        in arguments: [String: XomoJSONValue]
    ) throws -> Double? {
        guard let value = arguments[key] else { return nil }
        guard let number = value.doubleValue,
              number.isFinite,
              (0...1).contains(number)
        else {
            throw XomoAutomationCallError.invalidArgument(
                "\(key) must be a number from 0 through 1"
            )
        }
        return number
    }

    private func optionalNonnegativeNumber(
        _ key: String,
        in arguments: [String: XomoJSONValue]
    ) throws -> Double? {
        guard arguments[key] != nil else { return nil }
        let number = try requiredNumber(key, in: arguments)
        guard number >= 0 else {
            throw XomoAutomationCallError.invalidArgument(
                "\(key) must be a nonnegative number"
            )
        }
        return number
    }

    private func requiredNonnegativeNumber(
        _ key: String,
        in arguments: [String: XomoJSONValue]
    ) throws -> Double {
        guard let number = try optionalNonnegativeNumber(key, in: arguments) else {
            throw XomoAutomationCallError.invalidArgument("Missing number argument: \(key)")
        }
        return number
    }

    private func optionalShapeStrokeDashPattern(
        _ value: XomoJSONValue?
    ) throws -> [CGFloat]? {
        guard let value else { return nil }
        guard let items = value.arrayValue else {
            throw XomoAutomationCallError.invalidArgument(
                "strokeDashPattern must be an array"
            )
        }
        guard items.isEmpty || (2...16).contains(items.count) else {
            throw XomoAutomationCallError.invalidArgument(
                "strokeDashPattern must be empty or contain 2 to 16 lengths"
            )
        }
        return try items.enumerated().map { index, item in
            guard let length = item.doubleValue,
                  length.isFinite,
                  length > 0,
                  length <= 2_048
            else {
                throw XomoAutomationCallError.invalidArgument(
                    "strokeDashPattern[\(index)] must be greater than 0 and at most 2048"
                )
            }
            return CGFloat(length)
        }
    }

    private func optionalShapeStrokeDashOffset(
        _ value: XomoJSONValue?
    ) throws -> Double? {
        guard let value else { return nil }
        guard let offset = value.doubleValue,
              offset.isFinite,
              offset >= Double(ImageEditorShapeContent.minimumStrokeDashOffset),
              offset <= Double(ImageEditorShapeContent.maximumStrokeDashOffset)
        else {
            throw XomoAutomationCallError.invalidArgument(
                "strokeDashOffset must be a number from -2048 through 2048"
            )
        }
        return offset
    }

    private func optionalShapeGradient(
        _ arguments: [String: XomoJSONValue]
    ) throws -> ImageEditorGradientFillContent? {
        guard let value = arguments["fillGradient"] else { return nil }
        guard let object = value.objectValue else {
            throw XomoAutomationCallError.invalidArgument("fillGradient must be an object")
        }
        let angle = try optionalShapeGradientNumber(
            "angle",
            in: object,
            range: -180...180
        ) ?? 0
        let scale = try optionalShapeGradientNumber(
            "scale",
            in: object,
            range: 0.25...4
        ) ?? 1
        let dither: Bool
        if let value = object["dither"] {
            guard let parsed = value.boolValue else {
                throw XomoAutomationCallError.invalidArgument(
                    "fillGradient.dither must be a boolean"
                )
            }
            dither = parsed
        } else {
            dither = false
        }
        if let stopsValue = object["stops"] {
            guard object["startColor"] == nil, object["endColor"] == nil else {
                throw XomoAutomationCallError.invalidArgument(
                    "fillGradient.stops cannot be combined with startColor or endColor"
                )
            }
            let stops = try requiredGradientStops(
                stopsValue,
                path: "fillGradient.stops"
            )
            var gradient = ImageEditorGradientFillContent.shapeLinear(
                colorStops: stops,
                angle: CGFloat(angle),
                scale: CGFloat(scale)
            )
            gradient.dither = dither
            return gradient
        }
        let start = try requiredOpaqueColor("startColor", in: object)
        let end = try requiredOpaqueColor("endColor", in: object)
        var gradient = ImageEditorGradientFillContent.shapeLinear(
            startColor: start,
            endColor: end,
            angle: CGFloat(angle),
            scale: CGFloat(scale)
        )
        gradient.dither = dither
        return gradient
    }

    private func shapeFillKind(_ gradient: ImageEditorGradientFillContent?) -> String {
        guard let gradient else { return "solid" }
        switch gradient.style {
        case .linear: return "linearGradient"
        case .radial: return "radialGradient"
        case .angle: return "angleGradient"
        case .reflected: return "reflectedGradient"
        case .diamond: return "diamondGradient"
        }
    }

    private func shapeGradientStyle(for fillKind: String?) -> ImageEditorGradientFillStyle? {
        switch fillKind {
        case "linearGradient": return .linear
        case "radialGradient": return .radial
        case "angleGradient": return .angle
        case "reflectedGradient": return .reflected
        case "diamondGradient": return .diamond
        default: return nil
        }
    }

    private func optionalShapeGradientCenter(
        _ arguments: [String: XomoJSONValue]
    ) throws -> CGPoint? {
        guard let object = arguments["fillGradient"]?.objectValue else { return nil }
        let centerX = try optionalShapeGradientNumber(
            "centerX",
            in: object,
            range: -4...5
        )
        let centerY = try optionalShapeGradientNumber(
            "centerY",
            in: object,
            range: -4...5
        )
        guard centerX != nil || centerY != nil else { return nil }
        let x = centerX ?? 0.5
        let y = centerY ?? 0.5
        return CGPoint(x: x, y: y)
    }

    private func optionalShapeGradientNumber(
        _ key: String,
        in object: [String: XomoJSONValue],
        range: ClosedRange<Double>
    ) throws -> Double? {
        guard object[key] != nil else { return nil }
        let number = try requiredNumber(key, in: object)
        guard range.contains(number) else {
            throw XomoAutomationCallError.invalidArgument(
                "fillGradient.\(key) must be between \(range.lowerBound) and \(range.upperBound)"
            )
        }
        return number
    }

    private func validateShapeFillArguments(
        _ arguments: [String: XomoJSONValue],
        fillGradient: ImageEditorGradientFillContent?
    ) throws {
        guard let fillKindValue = arguments["fillKind"] else { return }
        guard let fillKind = fillKindValue.stringValue,
              [
                  "solid",
                  "linearGradient",
                  "radialGradient",
                  "angleGradient",
                  "reflectedGradient",
                  "diamondGradient"
              ].contains(fillKind)
        else {
            throw XomoAutomationCallError.invalidArgument(
                "fillKind must be solid, linearGradient, radialGradient, angleGradient, reflectedGradient, or diamondGradient"
            )
        }
        if fillKind == "solid", fillGradient != nil {
            throw XomoAutomationCallError.invalidArgument(
                "fillGradient cannot be combined with fillKind=solid"
            )
        }
    }

    private func requiredColor(
        _ key: String,
        in arguments: [String: XomoJSONValue]
    ) throws -> NSColor {
        guard let color = try optionalColor(key, in: arguments) else {
            throw XomoAutomationCallError.invalidArgument("Missing \(key)")
        }
        return color
    }

    private func requiredOpaqueColor(
        _ key: String,
        in arguments: [String: XomoJSONValue]
    ) throws -> NSColor {
        let color = try requiredColor(key, in: arguments)
        guard abs(color.alphaComponent - 1) <= 0.000_1 else {
            throw XomoAutomationCallError.invalidArgument(
                "\(key).alpha must be 1; use fillOpacity for the shared gradient opacity"
            )
        }
        return color
    }

    private func requiredGradientStops(
        _ value: XomoJSONValue,
        path: String
    ) throws -> [ImageEditorGradientColorStop] {
        guard let values = value.arrayValue else {
            throw XomoAutomationCallError.invalidArgument("\(path) must be an array")
        }
        guard (2...ImageEditorGradientFillContent.maximumColorStopCount).contains(values.count) else {
            throw XomoAutomationCallError.invalidArgument(
                "\(path) must contain 2 to 16 items"
            )
        }
        let stops = try values.enumerated().map { index, value in
            guard let stop = value.objectValue else {
                throw XomoAutomationCallError.invalidArgument(
                    "\(path)[\(index)] must be an object"
                )
            }
            guard let positionValue = stop["position"] else {
                throw XomoAutomationCallError.invalidArgument(
                    "\(path)[\(index)].position is required"
                )
            }
            guard let position = positionValue.doubleValue else {
                throw XomoAutomationCallError.invalidArgument(
                    "\(path)[\(index)].position must be a number"
                )
            }
            guard position.isFinite, (0...1).contains(position) else {
                throw XomoAutomationCallError.invalidArgument(
                    "\(path)[\(index)].position must be between 0 and 1"
                )
            }
            let midpoint: Double
            if let midpointValue = stop["midpoint"] {
                guard let parsedMidpoint = midpointValue.doubleValue,
                      parsedMidpoint.isFinite
                else {
                    throw XomoAutomationCallError.invalidArgument(
                        "\(path)[\(index)].midpoint must be a number"
                    )
                }
                guard (0...1).contains(parsedMidpoint) else {
                    throw XomoAutomationCallError.invalidArgument(
                        "\(path)[\(index)].midpoint must be between 0 and 1"
                    )
                }
                midpoint = parsedMidpoint
            } else {
                midpoint = ImageEditorGradientColorStop.defaultMidpoint
            }
            guard let colorValue = stop["color"] else {
                throw XomoAutomationCallError.invalidArgument(
                    "\(path)[\(index)].color is required"
                )
            }
            guard let colorObject = colorValue.objectValue else {
                throw XomoAutomationCallError.invalidArgument(
                    "\(path)[\(index)].color must be an object"
                )
            }
            return ImageEditorGradientColorStop(
                position: position,
                color: try requiredGradientStopColor(
                    colorObject,
                    stopIndex: index,
                    path: path
                ),
                midpoint: midpoint
            )
        }
        guard abs((stops.first?.position ?? 1)) <= 0.000_1,
              abs((stops.last?.position ?? 0) - 1) <= 0.000_1,
              zip(stops, stops.dropFirst()).allSatisfy({ pair in
                  pair.0.position <= pair.1.position
              })
        else {
            throw XomoAutomationCallError.invalidArgument(
                "\(path) must be ordered and span positions 0 through 1"
            )
        }
        return stops
    }

    private func requiredGradientStopColor(
        _ object: [String: XomoJSONValue],
        stopIndex: Int,
        path: String
    ) throws -> NSColor {
        let red = try requiredGradientStopColorComponent(
            "red", in: object, stopIndex: stopIndex, path: path
        )
        let green = try requiredGradientStopColorComponent(
            "green", in: object, stopIndex: stopIndex, path: path
        )
        let blue = try requiredGradientStopColorComponent(
            "blue", in: object, stopIndex: stopIndex, path: path
        )
        let alpha = try object["alpha"] == nil
            ? 1
            : requiredGradientStopColorComponent(
                "alpha", in: object, stopIndex: stopIndex, path: path
            )
        return NSColor(
            deviceRed: CGFloat(red),
            green: CGFloat(green),
            blue: CGFloat(blue),
            alpha: CGFloat(alpha)
        )
    }

    private func requiredGradientStopColorComponent(
        _ component: String,
        in object: [String: XomoJSONValue],
        stopIndex: Int,
        path: String
    ) throws -> Double {
        let componentPath = "\(path)[\(stopIndex)].color.\(component)"
        guard let value = object[component] else {
            throw XomoAutomationCallError.invalidArgument("\(componentPath) is required")
        }
        guard let number = value.doubleValue, number.isFinite else {
            throw XomoAutomationCallError.invalidArgument("\(componentPath) must be a number")
        }
        guard (0...1).contains(number) else {
            throw XomoAutomationCallError.invalidArgument(
                "\(componentPath) must be between 0 and 1"
            )
        }
        return number
    }

    private func shapeGradientJSON(
        _ content: ImageEditorGradientFillContent,
        center: CGPoint
    ) -> XomoJSONValue {
        let normalized = content.normalized()
        return .object([
            "startColor": colorJSON(normalized.shapeStartColor),
            "endColor": colorJSON(normalized.shapeEndColor),
            "stops": .array(normalized.shapeColorStops.map { stop in
                .object([
                    "position": .number(stop.position),
                    "midpoint": .number(stop.midpoint),
                    "color": colorJSON(stop.color)
                ])
            }),
            "angle": .number(normalized.angle),
            "scale": .number(normalized.scale),
            "dither": .bool(normalized.dither),
            "centerX": .number(center.x),
            "centerY": .number(center.y)
        ])
    }

    private func optionalColor(
        _ key: String,
        in arguments: [String: XomoJSONValue]
    ) throws -> NSColor? {
        guard let value = arguments[key] else { return nil }
        guard let object = value.objectValue else {
            throw XomoAutomationCallError.invalidArgument("\(key) must be an object")
        }
        let red = try requiredUnitNumber("red", in: object)
        let green = try requiredUnitNumber("green", in: object)
        let blue = try requiredUnitNumber("blue", in: object)
        let alpha: Double
        if object["alpha"] == nil {
            alpha = 1
        } else {
            alpha = try requiredUnitNumber("alpha", in: object)
        }
        return NSColor(
            deviceRed: CGFloat(red),
            green: CGFloat(green),
            blue: CGFloat(blue),
            alpha: CGFloat(alpha)
        )
    }

    private func requiredUnitNumber(
        _ key: String,
        in arguments: [String: XomoJSONValue]
    ) throws -> Double {
        let value = try requiredNumber(key, in: arguments)
        guard (0...1).contains(value) else {
            throw XomoAutomationCallError.invalidArgument("\(key) must be between 0 and 1")
        }
        return value
    }

    private func optionalCornerRadii(
        _ arguments: [String: XomoJSONValue]
    ) throws -> ImageEditorRectangleCornerRadii? {
        guard let value = arguments["cornerRadii"] else { return nil }
        guard let object = value.objectValue else {
            throw XomoAutomationCallError.invalidArgument("cornerRadii must be an object")
        }
        return ImageEditorRectangleCornerRadii(
            topLeft: CGFloat(try requiredNonnegativeNumber("topLeft", in: object)),
            topRight: CGFloat(try requiredNonnegativeNumber("topRight", in: object)),
            bottomRight: CGFloat(try requiredNonnegativeNumber("bottomRight", in: object)),
            bottomLeft: CGFloat(try requiredNonnegativeNumber("bottomLeft", in: object))
        )
    }

    private func validateExclusiveCornerArguments(
        _ arguments: [String: XomoJSONValue]
    ) throws {
        guard arguments["cornerRadius"] != nil,
              arguments["cornerRadii"] != nil
        else { return }
        throw XomoAutomationCallError.invalidArgument(
            "Use either cornerRadius or cornerRadii, not both"
        )
    }

    private func validateShapeCreationCornerArguments(
        _ arguments: [String: XomoJSONValue],
        kind: ImageEditorShapeKind
    ) throws {
        guard kind == .ellipse else { return }
        let rectangleOnlyKeys = ["cornerRadius", "cornerRadii", "cornerSmoothing"]
        guard let key = rectangleOnlyKeys.first(where: { arguments[$0] != nil }) else { return }
        throw XomoAutomationCallError.invalidArgument(
            "\(key) is only supported when kind is rectangle"
        )
    }

    private func cornerRadiiJSON(
        _ radii: ImageEditorRectangleCornerRadii
    ) -> XomoJSONValue {
        .object([
            "topLeft": .number(radii.topLeft),
            "topRight": .number(radii.topRight),
            "bottomRight": .number(radii.bottomRight),
            "bottomLeft": .number(radii.bottomLeft)
        ])
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
            if viewModel.cancelPathAnchorDragBeforeDiscreteCommand() {
                return
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
            let role: ImageEditorPathControlRole
            switch arguments["role"]?.stringValue ?? "anchor" {
            case "anchor": role = .anchor
            case "inHandle": role = .inHandle
            case "outHandle": role = .outHandle
            default: throw XomoAutomationCallError.invalidArgument("Unknown path control role")
            }
            if viewModel.cancelPathAnchorDragBeforeDiscreteCommand() {
                return
            }
            viewModel.selectedPathSubpathIndex = subpath
            viewModel.selectedPathAnchorIndex = anchor
            viewModel.selectedPathControlRole = role
            return
        }
        switch action {
        case "nextAnchor": viewModel.selectNextPathAnchor()
        case "previousAnchor": viewModel.selectPreviousPathAnchor()
        case "nextSubpath": viewModel.selectNextPathSubpath()
        case "previousSubpath": viewModel.selectPreviousPathSubpath()
        case "setAnchorX": viewModel.setSelectedPathAnchorX(try requiredNumber("value", in: arguments))
        case "setAnchorY": viewModel.setSelectedPathAnchorY(try requiredNumber("value", in: arguments))
        case "nudgeAnchor":
            viewModel.nudgeSelectedPathAnchor(by: CGSize(
                width: try requiredNumber("dx", in: arguments),
                height: try requiredNumber("dy", in: arguments)
            ))
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

    private func savedPathAction(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws -> XomoJSONValue {
        let action = arguments["action"]?.stringValue ?? "list"
        switch action {
        case "list":
            break
        case "save":
            guard viewModel.saveCurrentPath(name: arguments["name"]?.stringValue) != nil else {
                throw XomoAutomationCallError.operationFailed("No editable path is selected or the saved path limit was reached")
            }
        case "select":
            let id = try requiredUUID("id", in: arguments)
            guard viewModel.selectSavedPath(id) else {
                throw XomoAutomationCallError.notFound("Saved path \(id.uuidString)")
            }
        case "rename":
            let id = try requiredUUID("id", in: arguments)
            guard viewModel.renameSavedPath(id, to: try requiredString("name", in: arguments)) else {
                throw XomoAutomationCallError.invalidArgument("Saved path name must not be blank and the path must exist")
            }
        case "duplicate":
            let id = try requiredUUID("id", in: arguments)
            guard viewModel.duplicateSavedPath(id) != nil else {
                throw XomoAutomationCallError.operationFailed("The saved path does not exist or the saved path limit was reached")
            }
        case "moveUp", "moveDown", "moveToTop", "moveToBottom":
            let id = try requiredUUID("id", in: arguments)
            guard viewModel.document.savedPaths.contains(where: { $0.id == id }) else {
                throw XomoAutomationCallError.notFound("Saved path \(id.uuidString)")
            }
            let moved: Bool
            switch action {
            case "moveUp": moved = viewModel.moveSavedPathUp(id)
            case "moveDown": moved = viewModel.moveSavedPathDown(id)
            case "moveToTop": moved = viewModel.moveSavedPathToTop(id)
            case "moveToBottom": moved = viewModel.moveSavedPathToBottom(id)
            default: moved = false
            }
            guard moved else {
                throw XomoAutomationCallError.operationFailed("Saved path is already at the requested boundary")
            }
        case "moveToIndex":
            let id = try requiredUUID("id", in: arguments)
            guard viewModel.document.savedPaths.contains(where: { $0.id == id }) else {
                throw XomoAutomationCallError.notFound("Saved path \(id.uuidString)")
            }
            let rawIndex = try requiredNumber("index", in: arguments)
            guard rawIndex >= 0,
                  rawIndex < Double(viewModel.document.savedPaths.count),
                  rawIndex.rounded(.towardZero) == rawIndex
            else {
                throw XomoAutomationCallError.invalidArgument(
                    "Saved path index must be a zero-based integer within the current list"
                )
            }
            guard viewModel.moveSavedPath(id, toIndex: Int(rawIndex)) else {
                throw XomoAutomationCallError.operationFailed("Saved path is already at the requested index")
            }
        case "update":
            let id = try requiredUUID("id", in: arguments)
            guard viewModel.updateSavedPath(id) else {
                throw XomoAutomationCallError.operationFailed("No editable path is selected or the saved path does not exist")
            }
        case "load":
            let id = try requiredUUID("id", in: arguments)
            guard viewModel.loadSavedPath(id) != nil else {
                throw XomoAutomationCallError.notFound("Saved path \(id.uuidString)")
            }
        case "selection":
            let id = try requiredUUID("id", in: arguments)
            guard let savedPath = viewModel.document.savedPaths.first(where: { $0.id == id }) else {
                throw XomoAutomationCallError.notFound("Saved path \(id.uuidString)")
            }
            guard savedPath.isClosed else {
                throw XomoAutomationCallError.operationFailed("Selection requires a closed saved path")
            }
            _ = viewModel.loadSelectionFromSavedPath(id)
        case "fill":
            let id = try requiredUUID("id", in: arguments)
            guard viewModel.fillSavedPathToSelectedPixelLayer(id) else {
                throw XomoAutomationCallError.operationFailed("Fill requires a closed saved path and an editable selected pixel layer")
            }
        case "stroke":
            let id = try requiredUUID("id", in: arguments)
            guard viewModel.strokeSavedPathToSelectedPixelLayer(id) else {
                throw XomoAutomationCallError.operationFailed("Stroke requires a saved path and an editable selected pixel layer")
            }
        case "visibility":
            let id = try requiredUUID("id", in: arguments)
            guard viewModel.setSavedPathVisibility(
                id,
                isVisible: try requiredBool("visible", in: arguments)
            ) else {
                throw XomoAutomationCallError.notFound("Saved path \(id.uuidString)")
            }
        case "delete":
            let id = try requiredUUID("id", in: arguments)
            guard viewModel.deleteSavedPath(id) else {
                throw XomoAutomationCallError.notFound("Saved path \(id.uuidString)")
            }
        default:
            throw XomoAutomationCallError.invalidArgument("Unknown saved path action: \(action)")
        }
        return savedPathsResult(viewModel)
    }

    private func savedPathsResult(_ viewModel: ImageEditorViewModel) -> XomoJSONValue {
        let overlayIDs = Set(viewModel.savedPathCanvasOverlays.map(\.id))
        return .array(viewModel.document.savedPaths.enumerated().map { index, savedPath in
            .object([
                "index": .number(Double(index)),
                "id": .string(savedPath.id.uuidString),
                "title": .string(savedPath.name),
                "selected": .bool(viewModel.document.selectedSavedPathID == savedPath.id),
                "visible": .bool(savedPath.isVisible),
                "overlayVisible": .bool(overlayIDs.contains(savedPath.id)),
                "closed": .bool(savedPath.isClosed),
                "anchorCount": .number(Double(savedPath.anchorCount)),
                "subpaths": .array(savedPath.subpaths.enumerated().map { subpathIndex, anchors in
                    .object([
                        "index": .number(Double(subpathIndex)),
                        "anchors": .array(anchors.enumerated().map { anchorIndex, anchor in
                            .object([
                                "index": .number(Double(anchorIndex)),
                                "point": pointJSON(anchor.point),
                                "inControl": anchor.inControl.map(pointJSON) ?? .null,
                                "outControl": anchor.outControl.map(pointJSON) ?? .null
                            ])
                        })
                    ])
                })
            ])
        })
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
                "opacity": .number(filter.normalizedOpacity),
                "blendMode": .string(filter.normalizedBlendMode.rawValue),
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

    private func patternFillSettingsAction(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws -> XomoJSONValue {
        switch try requiredString("action", in: arguments) {
        case "get":
            return patternFillSettingsResult(viewModel)
        case "set":
            let rawKind = try requiredString("patternKind", in: arguments)
            guard let kind = ImageEditorPatternOverlayKind(rawValue: rawKind) else {
                throw XomoAutomationCallError.invalidArgument("Unknown pattern fill kind: \(rawKind)")
            }
            let target = ImageEditorPatternFillContent(
                kind: kind,
                red: try requiredNumber("red", in: arguments),
                green: try requiredNumber("green", in: arguments),
                blue: try requiredNumber("blue", in: arguments),
                opacity: try requiredNumber("opacity", in: arguments),
                scale: CGFloat(try requiredNumber("scale", in: arguments)),
                offsetX: CGFloat(try requiredNumber("offsetX", in: arguments)),
                offsetY: CGFloat(try requiredNumber("offsetY", in: arguments))
            ).normalized()
            let selectedIDs = viewModel.document.selectedLayerIDs
            let updatedLayerCount = viewModel.document.layers.reduce(into: 0) { count, layer in
                guard
                    selectedIDs.contains(layer.id),
                    !viewModel.document.isEffectivelyPixelsLocked(layer),
                    let content = layer.patternFillContent?.normalized(),
                    content != target
                else {
                    return
                }
                count += 1
            }
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "Pattern fill settings require a changed editable selected pattern-fill layer"
                )
            }

            viewModel.selectedPatternFillKind = target.kind
            viewModel.patternFillRed = target.red
            viewModel.patternFillGreen = target.green
            viewModel.patternFillBlue = target.blue
            viewModel.patternFillOpacity = target.opacity
            viewModel.patternFillScale = Double(target.scale)
            viewModel.patternFillOffsetX = Double(target.offsetX)
            viewModel.patternFillOffsetY = Double(target.offsetY)
            viewModel.updateSelectedPatternFillLayer()

            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount)),
                "layers": patternFillSettingsResult(viewModel)
            ])
        default:
            throw XomoAutomationCallError.invalidArgument("Unknown pattern fill settings action")
        }
    }

    private func patternFillSettingsResult(_ viewModel: ImageEditorViewModel) -> XomoJSONValue {
        let selectedIDs = viewModel.document.selectedLayerIDs
        return .array(viewModel.document.layers.compactMap { layer in
            guard
                selectedIDs.contains(layer.id),
                let content = layer.patternFillContent?.normalized()
            else {
                return nil
            }
            return .object([
                "id": .string(layer.id.uuidString),
                "name": .string(layer.name),
                "locked": .bool(viewModel.document.isEffectivelyPixelsLocked(layer)),
                "patternKind": .string(content.kind.rawValue),
                "red": .number(content.red),
                "green": .number(content.green),
                "blue": .number(content.blue),
                "opacity": .number(content.opacity),
                "scale": .number(Double(content.scale)),
                "offsetX": .number(Double(content.offsetX)),
                "offsetY": .number(Double(content.offsetY))
            ])
        })
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
        case "solidColorFill":
            try createSolidColorFillLayer(arguments, viewModel: viewModel)
        case "patternFill":
            let requestedKind: ImageEditorPatternOverlayKind?
            if arguments["patternKind"] != nil {
                let rawKind = try requiredString("patternKind", in: arguments)
                guard let kind = ImageEditorPatternOverlayKind(rawValue: rawKind) else {
                    throw XomoAutomationCallError.invalidArgument("Unknown pattern fill kind: \(rawKind)")
                }
                requestedKind = kind
            } else {
                requestedKind = nil
            }
            let requestedRed = try arguments["patternRed"].map { _ in
                try requiredNumber("patternRed", in: arguments)
            }
            let requestedGreen = try arguments["patternGreen"].map { _ in
                try requiredNumber("patternGreen", in: arguments)
            }
            let requestedBlue = try arguments["patternBlue"].map { _ in
                try requiredNumber("patternBlue", in: arguments)
            }
            let requestedOpacity = try arguments["patternOpacity"].map { _ in
                try requiredNumber("patternOpacity", in: arguments)
            }
            let requestedScale = try arguments["patternScale"].map { _ in
                try requiredNumber("patternScale", in: arguments)
            }
            let requestedOffsetX = try arguments["offsetX"].map { _ in
                try requiredNumber("offsetX", in: arguments)
            }
            let requestedOffsetY = try arguments["offsetY"].map { _ in
                try requiredNumber("offsetY", in: arguments)
            }

            if let requestedKind {
                viewModel.selectedPatternFillKind = requestedKind
            }
            if let requestedRed {
                viewModel.patternFillRed = requestedRed
            }
            if let requestedGreen {
                viewModel.patternFillGreen = requestedGreen
            }
            if let requestedBlue {
                viewModel.patternFillBlue = requestedBlue
            }
            if let requestedOpacity {
                viewModel.patternFillOpacity = requestedOpacity
            }
            if let requestedScale {
                viewModel.patternFillScale = requestedScale
            }
            if let requestedOffsetX {
                viewModel.patternFillOffsetX = requestedOffsetX
            }
            if let requestedOffsetY {
                viewModel.patternFillOffsetY = requestedOffsetY
            }
            viewModel.addPatternFillLayer()
        case "gradientFill":
            try createGradientFillLayer(arguments, viewModel: viewModel)
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

    private func rasterizeLayerContent(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws {
        let rawValue = try requiredString("target", in: arguments)
        guard let target = ImageEditorRasterizeTarget(rawValue: rawValue) else {
            throw XomoAutomationCallError.invalidArgument("Unknown rasterize target: \(rawValue)")
        }
        viewModel.rasterizeSelectedLayers(target)
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
    ) throws -> XomoJSONValue {
        switch try requiredString("action", in: arguments) {
        case "copy":
            guard viewModel.copySelectedLayerStyle(),
                  let sourceLayerID = viewModel.copiedLayerStyleSourceID
            else {
                throw XomoAutomationCallError.operationFailed("No copyable layer is selected")
            }
            return .object([
                "copied": .bool(true),
                "sourceLayerId": .string(sourceLayerID.uuidString)
            ])
        case "paste":
            let pastedLayerCount = viewModel.pasteLayerStyleToSelectedLayers()
            guard pastedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No selected editable layer needs the copied style"
                )
            }
            return .object([
                "pastedLayerCount": .number(Double(pastedLayerCount))
            ])
        case "clear":
            let clearedLayerCount = viewModel.clearSelectedLayerStyles()
            guard clearedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No selected editable layer has a configured style"
                )
            }
            return .object([
                "clearedLayerCount": .number(Double(clearedLayerCount))
            ])
        case "hideSelected":
            return try layerEffectVisibilityResult(
                viewModel.hideSelectedLayerEffects(),
                resultKey: "hiddenLayerCount"
            )
        case "showSelected":
            return try layerEffectVisibilityResult(
                viewModel.showSelectedLayerEffects(),
                resultKey: "shownLayerCount"
            )
        case "hideAll":
            return try layerEffectVisibilityResult(
                viewModel.hideAllLayerEffects(),
                resultKey: "hiddenLayerCount"
            )
        case "showAll":
            return try layerEffectVisibilityResult(
                viewModel.showAllLayerEffects(),
                resultKey: "shownLayerCount"
            )
        default: throw XomoAutomationCallError.invalidArgument("Unknown layer style action")
        }
    }

    private func layerEffectVisibilityResult(
        _ changedLayerCount: Int,
        resultKey: String
    ) throws -> XomoJSONValue {
        guard changedLayerCount > 0 else {
            throw XomoAutomationCallError.operationFailed(
                "No layer effect visibility state needs to change"
            )
        }
        return .object([
            resultKey: .number(Double(changedLayerCount))
        ])
    }

    private func layerStylePresetAction(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws -> XomoJSONValue {
        var resultPresets: [ImageEditorLayerStylePreset]?
        switch try requiredString("action", in: arguments) {
        case "presetList":
            break
        case "presetCatalog":
            resultPresets = viewModel.builtInLayerStylePresets
        case "presetFavorites":
            resultPresets = viewModel.favoriteLayerStylePresets
        case "presetRecent":
            resultPresets = viewModel.recentLayerStylePresets
        case "presetCreate":
            let preset = viewModel.createLayerStylePresetFromSelectedLayer(
                name: arguments["name"]?.stringValue
            )
            guard preset != nil else {
                throw XomoAutomationCallError.invalidArgument(
                    "A configured layer style is required and the custom preset limit must not be reached"
                )
            }
        case "presetApply":
            let id = try requiredString("id", in: arguments)
            guard let preset = viewModel.layerStylePreset(id: id) else {
                throw XomoAutomationCallError.notFound("Layer style preset \(id)")
            }
            viewModel.applyLayerStylePreset(preset)
        case "presetDuplicate":
            let id = try requiredString("id", in: arguments)
            guard let preset = viewModel.layerStylePreset(id: id) else {
                throw XomoAutomationCallError.notFound("Layer style preset \(id)")
            }
            guard viewModel.duplicateLayerStylePresetToCustom(preset) != nil else {
                throw XomoAutomationCallError.invalidArgument("The custom layer style preset limit was reached")
            }
        case "presetFavorite":
            let id = try requiredString("id", in: arguments)
            let isFavorite = try requiredBool("favorite", in: arguments)
            guard viewModel.setLayerStylePresetFavorite(id: id, isFavorite: isFavorite) else {
                throw XomoAutomationCallError.notFound("Layer style preset \(id)")
            }
            resultPresets = viewModel.favoriteLayerStylePresets
        case "presetDelete":
            let id = try requiredString("id", in: arguments)
            guard let preset = viewModel.customLayerStylePresets.first(where: { $0.id == id }) else {
                throw XomoAutomationCallError.notFound("Layer style preset \(id)")
            }
            viewModel.deleteLayerStylePreset(preset)
        case "presetRename":
            let id = try requiredString("id", in: arguments)
            let name = try requiredString("name", in: arguments)
            guard viewModel.renameLayerStylePreset(id: id, name: name) else {
                throw XomoAutomationCallError.invalidArgument("Preset name must not be blank and the preset must exist")
            }
        case "presetMove":
            let id = try requiredString("id", in: arguments)
            let rawDirection = try requiredString("direction", in: arguments)
            guard let direction = ImageEditorLayerStylePresetMoveDirection(rawValue: rawDirection),
                  viewModel.moveLayerStylePreset(id: id, direction: direction)
            else {
                throw XomoAutomationCallError.invalidArgument("Unknown preset or move direction")
            }
        case "presetImportPreview":
            let path = try requiredString("path", in: arguments)
            do {
                let preview = try viewModel.previewLayerStylePresetLibrary(
                    from: URL(fileURLWithPath: path)
                )
                return layerStylePresetImportPreviewResult(preview)
            } catch {
                throw XomoAutomationCallError.invalidArgument("Layer style preset preview failed: \(error.localizedDescription)")
            }
        case "presetImport":
            let path = try requiredString("path", in: arguments)
            do {
                try viewModel.importLayerStylePresetLibrary(from: URL(fileURLWithPath: path))
            } catch {
                throw XomoAutomationCallError.invalidArgument("Layer style preset import failed: \(error.localizedDescription)")
            }
        case "presetExport":
            let path = try requiredString("path", in: arguments)
            let ids = arguments["id"]?.stringValue.map { [$0] }
            do {
                try viewModel.exportLayerStylePresetLibrary(
                    to: URL(fileURLWithPath: path),
                    presetIDs: ids
                )
            } catch {
                throw XomoAutomationCallError.invalidArgument("Layer style preset export failed: \(error.localizedDescription)")
            }
        default:
            throw XomoAutomationCallError.invalidArgument("Unknown layer style preset action")
        }
        return layerStylePresetsResult(
            viewModel,
            presets: resultPresets ?? viewModel.customLayerStylePresets
        )
    }

    private func layerStylePresetsResult(
        _ viewModel: ImageEditorViewModel,
        presets: [ImageEditorLayerStylePreset]
    ) -> XomoJSONValue {
        .array(presets.map { preset in
            let style = preset.layerStyle
            return .object([
                "id": .string(preset.id),
                "title": .string(preset.title),
                "builtIn": .bool(preset.isBuiltIn),
                "active": .bool(viewModel.activeLayerStylePreset?.id == preset.id),
                "favorite": .bool(viewModel.isFavoriteLayerStylePreset(id: preset.id)),
                "recent": .bool(viewModel.recentLayerStylePresetIDs.contains(preset.id)),
                "effectsEnabled": .bool(style.effectsEnabled),
                "effectScale": .number(Double(style.effectScale * 100)),
                "effects": .array(layerStyleEffectNames(style).map(XomoJSONValue.string))
            ])
        })
    }

    private func layerStylePresetImportPreviewResult(
        _ preview: ImageEditorLayerStylePresetImportPreview
    ) -> XomoJSONValue {
        .object([
            "total": .number(Double(preview.totalCount)),
            "importable": .number(Double(preview.importableCount)),
            "duplicates": .number(Double(preview.duplicateCount)),
            "capacitySkipped": .number(Double(preview.capacitySkippedCount)),
            "skipped": .number(Double(preview.skippedCount)),
            "items": .array(preview.items.map { item in
                .object([
                    "index": .number(Double(item.id)),
                    "title": .string(item.title),
                    "outcome": .string(item.outcome.rawValue)
                ])
            })
        ])
    }

    private func layerStyleEffectNames(_ style: ImageEditorLayerStyle) -> [String] {
        [
            style.strokeEnabled ? "stroke" : nil,
            style.shadowEnabled ? "shadow" : nil,
            style.innerShadowEnabled ? "innerShadow" : nil,
            style.outerGlowEnabled ? "outerGlow" : nil,
            style.innerGlowEnabled ? "innerGlow" : nil,
            style.colorOverlayEnabled ? "colorOverlay" : nil,
            style.gradientOverlayEnabled ? "gradientOverlay" : nil,
            style.patternOverlayEnabled ? "patternOverlay" : nil,
            style.satinEnabled ? "satin" : nil,
            style.bevelEnabled ? "bevel" : nil
        ].compactMap { $0 }
    }

    private func layerStyleSetting(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws -> XomoJSONValue {
        let property = try requiredString("property", in: arguments)
        let value = arguments["value"]?.doubleValue
        func number() throws -> Double {
            guard let value, value.isFinite else {
                throw XomoAutomationCallError.invalidArgument("Style setting requires numeric value")
            }
            return value
        }
        switch property {
        case "effectScale":
            let updatedLayerCount = viewModel.setSelectedLayerEffectScale(try number())
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable styled layer needs the requested effect scale"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "strokeWidth":
            let updatedLayerCount = viewModel.setSelectedLayerStrokeWidth(try number())
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested stroke width"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "strokePosition":
            let rawValue = try requiredString("position", in: arguments)
            guard let position = ImageEditorStrokePosition(rawValue: rawValue) else {
                throw XomoAutomationCallError.invalidArgument("Unknown stroke position")
            }
            let updatedLayerCount = viewModel.setSelectedLayerStrokePosition(position)
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested stroke position"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "strokeFillType":
            let rawValue = try requiredString("fillType", in: arguments)
            guard let fillType = ImageEditorStrokeFillType(rawValue: rawValue) else {
                throw XomoAutomationCallError.invalidArgument("Unknown stroke fill type")
            }
            let updatedLayerCount = viewModel.setSelectedLayerStrokeFillType(fillType)
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested stroke fill type"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "strokeGradientStyle":
            let rawValue = try requiredString("gradientStyle", in: arguments)
            guard let gradientStyle = ImageEditorGradientFillStyle(rawValue: rawValue) else {
                throw XomoAutomationCallError.invalidArgument("Unknown stroke gradient style")
            }
            let updatedLayerCount = viewModel.setSelectedLayerStrokeGradientStyle(gradientStyle)
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested stroke gradient style"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "strokeGradientAngle":
            let updatedLayerCount = viewModel.setSelectedLayerStrokeGradientAngle(try number())
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested stroke gradient angle"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "strokePatternKind":
            let rawValue = try requiredString("patternKind", in: arguments)
            guard let patternKind = ImageEditorPatternOverlayKind(rawValue: rawValue) else {
                throw XomoAutomationCallError.invalidArgument("Unknown stroke pattern kind")
            }
            let updatedLayerCount = viewModel.setSelectedLayerStrokePatternKind(patternKind)
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested stroke pattern kind"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "strokePatternColor":
            let updatedLayerCount = viewModel.setSelectedLayerStrokePatternColor(
                viewModel.foregroundColor
            )
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested stroke pattern color"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "strokePatternScale":
            let updatedLayerCount = viewModel.setSelectedLayerStrokePatternScale(try number())
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested stroke pattern scale"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "strokePatternOffsetX":
            let updatedLayerCount = viewModel.setSelectedLayerStrokePatternOffsetX(try number())
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested stroke pattern X offset"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "strokePatternOffsetY":
            let updatedLayerCount = viewModel.setSelectedLayerStrokePatternOffsetY(try number())
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested stroke pattern Y offset"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "strokeOpacity":
            let updatedLayerCount = viewModel.setSelectedLayerStrokeOpacity(try number())
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested stroke opacity"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "strokeColor":
            let updatedLayerCount = viewModel.setSelectedLayerStrokeColor(viewModel.foregroundColor)
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested stroke color"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "strokeGradientStartColor":
            let updatedLayerCount = viewModel.setSelectedLayerStrokeGradientStartColor(
                viewModel.foregroundColor
            )
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested stroke gradient start color"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "strokeGradientEndColor":
            let updatedLayerCount = viewModel.setSelectedLayerStrokeGradientEndColor(
                viewModel.backgroundColor
            )
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested stroke gradient end color"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "shadowOpacity":
            let updatedLayerCount = viewModel.setSelectedLayerShadowOpacity(try number())
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested shadow opacity"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "shadowColor":
            let updatedLayerCount = viewModel.setSelectedLayerShadowColor(viewModel.foregroundColor)
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested shadow color"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "shadowBlur":
            let updatedLayerCount = viewModel.setSelectedLayerShadowBlur(try number())
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested shadow blur"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "shadowSpread":
            let updatedLayerCount = viewModel.setSelectedLayerShadowSpread(try number())
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested shadow spread"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "shadowNoise":
            let updatedLayerCount = viewModel.setSelectedLayerShadowNoise(try number())
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested shadow noise"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "shadowContour":
            let rawValue = try requiredString("shadowContour", in: arguments)
            guard let contour = ImageEditorLayerEffectContour(rawValue: rawValue) else {
                throw XomoAutomationCallError.invalidArgument("Unknown shadow contour")
            }
            let updatedLayerCount = viewModel.setSelectedLayerShadowContour(contour)
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested shadow contour"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "shadowDistance":
            let updatedLayerCount = viewModel.setSelectedLayerShadowDistance(try number())
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested shadow distance"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "shadowAngle":
            let previousGlobalLightAngle = viewModel.document.globalLightAngle
            let updatedLayerCount = viewModel.setSelectedLayerShadowAngle(try number())
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested shadow angle"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount)),
                "globalLightUpdated": .bool(
                    abs(viewModel.document.globalLightAngle - previousGlobalLightAngle) > 0.001
                )
            ])
        case "globalLightAngle":
            let result = viewModel.setGlobalLightAngle(try number())
            guard result.didUpdate else {
                throw XomoAutomationCallError.operationFailed(
                    "The document already uses the requested global light angle"
                )
            }
            return .object([
                "globalLightUpdated": .bool(true),
                "updatedLayerCount": .number(Double(result.affectedLayerCount)),
                "affectedEffectCount": .number(Double(result.affectedEffectCount)),
                "shadowLayerCount": .number(Double(result.shadowLayerCount)),
                "innerShadowLayerCount": .number(Double(result.innerShadowLayerCount)),
                "bevelLayerCount": .number(Double(result.bevelLayerCount))
            ])
        case "innerShadowOpacity":
            let updatedLayerCount = viewModel.setSelectedLayerInnerShadowOpacity(try number())
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested inner shadow opacity"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "innerShadowBlur":
            let updatedLayerCount = viewModel.setSelectedLayerInnerShadowBlur(try number())
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested inner shadow blur"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "innerShadowChoke":
            let updatedLayerCount = viewModel.setSelectedLayerInnerShadowChoke(try number())
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested inner shadow choke"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "innerShadowNoise":
            let updatedLayerCount = viewModel.setSelectedLayerInnerShadowNoise(try number())
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested inner shadow noise"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "innerShadowContour":
            let rawValue = try requiredString("innerShadowContour", in: arguments)
            guard let contour = ImageEditorLayerEffectContour(rawValue: rawValue) else {
                throw XomoAutomationCallError.invalidArgument("Unknown inner shadow contour")
            }
            let updatedLayerCount = viewModel.setSelectedLayerInnerShadowContour(contour)
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested inner shadow contour"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "innerShadowDistance":
            let updatedLayerCount = viewModel.setSelectedLayerInnerShadowDistance(try number())
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested inner shadow distance"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "innerShadowAngle":
            let previousGlobalLightAngle = viewModel.document.globalLightAngle
            let updatedLayerCount = viewModel.setSelectedLayerInnerShadowAngle(try number())
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested inner shadow angle"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount)),
                "globalLightUpdated": .bool(
                    abs(viewModel.document.globalLightAngle - previousGlobalLightAngle) > 0.001
                )
            ])
        case "outerGlowOpacity":
            let updatedLayerCount = viewModel.setSelectedLayerOuterGlowOpacity(try number())
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested outer glow opacity"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "outerGlowColor":
            let updatedLayerCount = viewModel.setSelectedLayerOuterGlowColor(viewModel.foregroundColor)
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested outer glow color"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "outerGlowBlur":
            let updatedLayerCount = viewModel.setSelectedLayerOuterGlowBlur(try number())
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested outer glow blur"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "outerGlowSpread":
            let updatedLayerCount = viewModel.setSelectedLayerOuterGlowSpread(try number())
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested outer glow spread"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "outerGlowTechnique":
            let rawValue = try requiredString("outerGlowTechnique", in: arguments)
            guard let technique = ImageEditorGlowTechnique(rawValue: rawValue) else {
                throw XomoAutomationCallError.invalidArgument("Unknown outer glow technique")
            }
            let updatedLayerCount = viewModel.setSelectedLayerOuterGlowTechnique(technique)
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested outer glow technique"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "outerGlowNoise":
            let updatedLayerCount = viewModel.setSelectedLayerOuterGlowNoise(try number())
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested outer glow noise"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "outerGlowContour":
            let rawValue = try requiredString("outerGlowContour", in: arguments)
            guard let contour = ImageEditorLayerEffectContour(rawValue: rawValue) else {
                throw XomoAutomationCallError.invalidArgument("Unknown outer glow contour")
            }
            let updatedLayerCount = viewModel.setSelectedLayerOuterGlowContour(contour)
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested outer glow contour"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "outerGlowRange":
            let updatedLayerCount = viewModel.setSelectedLayerOuterGlowRange(try number())
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested outer glow range"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "outerGlowJitter":
            let updatedLayerCount = viewModel.setSelectedLayerOuterGlowJitter(try number())
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested outer glow jitter"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "innerGlowOpacity":
            let updatedLayerCount = viewModel.setSelectedLayerInnerGlowOpacity(try number())
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested inner glow opacity"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "innerGlowColor":
            let updatedLayerCount = viewModel.setSelectedLayerInnerGlowColor(viewModel.foregroundColor)
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested inner glow color"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "innerGlowBlur":
            let updatedLayerCount = viewModel.setSelectedLayerInnerGlowBlur(try number())
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested inner glow blur"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "innerGlowChoke":
            let updatedLayerCount = viewModel.setSelectedLayerInnerGlowChoke(try number())
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested inner glow choke"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "innerGlowTechnique":
            let rawValue = try requiredString("innerGlowTechnique", in: arguments)
            guard let technique = ImageEditorGlowTechnique(rawValue: rawValue) else {
                throw XomoAutomationCallError.invalidArgument("Unknown inner glow technique")
            }
            let updatedLayerCount = viewModel.setSelectedLayerInnerGlowTechnique(technique)
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested inner glow technique"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "innerGlowNoise":
            let updatedLayerCount = viewModel.setSelectedLayerInnerGlowNoise(try number())
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested inner glow noise"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "innerGlowSource":
            let rawValue = try requiredString("source", in: arguments)
            guard let source = ImageEditorInnerGlowSource(rawValue: rawValue) else {
                throw XomoAutomationCallError.invalidArgument("Unknown inner glow source")
            }
            let updatedLayerCount = viewModel.setSelectedLayerInnerGlowSource(source)
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested inner glow source"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "innerGlowContour":
            let rawValue = try requiredString("innerGlowContour", in: arguments)
            guard let contour = ImageEditorLayerEffectContour(rawValue: rawValue) else {
                throw XomoAutomationCallError.invalidArgument("Unknown inner glow contour")
            }
            let updatedLayerCount = viewModel.setSelectedLayerInnerGlowContour(contour)
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested inner glow contour"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "innerGlowRange":
            let updatedLayerCount = viewModel.setSelectedLayerInnerGlowRange(try number())
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested inner glow range"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "innerGlowJitter":
            let updatedLayerCount = viewModel.setSelectedLayerInnerGlowJitter(try number())
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested inner glow jitter"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "colorOverlayOpacity":
            let updatedLayerCount = viewModel.setSelectedLayerColorOverlayOpacity(try number())
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested color overlay opacity"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "colorOverlayColor":
            let updatedLayerCount = viewModel.setSelectedLayerColorOverlayColor(viewModel.foregroundColor)
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested color overlay color"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "gradientOverlayOpacity":
            let updatedLayerCount = viewModel.setSelectedLayerGradientOverlayOpacity(try number())
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested gradient overlay opacity"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "gradientOverlayBlendMode":
            let rawValue = try requiredString("blendMode", in: arguments)
            guard let blendMode = ImageEditorBlendMode(rawValue: rawValue),
                  ImageEditorBlendMode.layerEffectCases.contains(blendMode)
            else {
                throw XomoAutomationCallError.invalidArgument(
                    "Unknown gradient overlay blend mode"
                )
            }
            let updatedLayerCount = viewModel.setSelectedLayerGradientOverlayBlendMode(blendMode)
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested gradient overlay blend mode"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "gradientOverlayStartColor":
            let updatedLayerCount = viewModel.setSelectedLayerGradientOverlayStartColor(
                viewModel.foregroundColor
            )
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested gradient overlay start color"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "gradientOverlayEndColor":
            let updatedLayerCount = viewModel.setSelectedLayerGradientOverlayEndColor(
                viewModel.backgroundColor
            )
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested gradient overlay end color"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "gradientOverlayStops":
            guard let value = arguments["stops"] else {
                throw XomoAutomationCallError.invalidArgument("stops is required")
            }
            let stops = try requiredGradientStops(value, path: "stops")
            let updatedLayerCount = viewModel.setSelectedLayerGradientOverlayColorStops(stops)
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested gradient overlay stops"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "gradientOverlayScale":
            let updatedLayerCount = viewModel.setSelectedLayerGradientOverlayScale(try number())
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested gradient overlay scale"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "gradientOverlayAngle":
            let updatedLayerCount = viewModel.setSelectedLayerGradientOverlayAngle(try number())
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested gradient overlay angle"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "gradientOverlayCenterX":
            let updatedLayerCount = viewModel.setSelectedLayerGradientOverlayCenterX(try number())
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested gradient overlay center X"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "gradientOverlayCenterY":
            let updatedLayerCount = viewModel.setSelectedLayerGradientOverlayCenterY(try number())
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested gradient overlay center Y"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "gradientOverlayStyle":
            let rawValue = try requiredString("gradientOverlayStyle", in: arguments)
            guard let style = ImageEditorGradientFillStyle(rawValue: rawValue) else {
                throw XomoAutomationCallError.invalidArgument("Unknown gradient overlay style")
            }
            let updatedLayerCount = viewModel.setSelectedLayerGradientOverlayStyle(style)
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested gradient overlay style"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "gradientOverlayDither":
            let updatedLayerCount = viewModel.setSelectedLayerGradientOverlayDither(
                try requiredBool("enabled", in: arguments)
            )
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested gradient overlay dither setting"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "gradientOverlayReverse":
            let updatedLayerCount = viewModel.setSelectedLayerGradientOverlayReverse(
                try requiredBool("enabled", in: arguments)
            )
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested gradient overlay reverse setting"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "patternOverlayKind":
            let rawValue = try requiredString("patternOverlayKind", in: arguments)
            guard let kind = ImageEditorPatternOverlayKind(rawValue: rawValue) else {
                throw XomoAutomationCallError.invalidArgument("Unknown pattern overlay kind")
            }
            let updatedLayerCount = viewModel.setSelectedLayerPatternOverlayKind(kind)
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested pattern overlay kind"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "patternOverlayColor":
            let updatedLayerCount = viewModel.setSelectedLayerPatternOverlayColor(
                viewModel.foregroundColor
            )
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested pattern overlay color"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "patternOverlayOpacity":
            let updatedLayerCount = viewModel.setSelectedLayerPatternOverlayOpacity(try number())
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested pattern overlay opacity"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "patternOverlayScale":
            let updatedLayerCount = viewModel.setSelectedLayerPatternOverlayScale(try number())
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested pattern overlay scale"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "patternOverlayOffsetX":
            let updatedLayerCount = viewModel.setSelectedLayerPatternOverlayOffsetX(try number())
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested pattern overlay X offset"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "patternOverlayOffsetY":
            let updatedLayerCount = viewModel.setSelectedLayerPatternOverlayOffsetY(try number())
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested pattern overlay Y offset"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "satinOpacity":
            return try satinUpdateResult(
                viewModel.setSelectedLayerSatinOpacity(try number()),
                property: "opacity"
            )
        case "satinColor":
            return try satinUpdateResult(
                viewModel.setSelectedLayerSatinColor(viewModel.foregroundColor),
                property: "color"
            )
        case "satinDistance":
            return try satinUpdateResult(
                viewModel.setSelectedLayerSatinDistance(try number()),
                property: "distance"
            )
        case "satinSize":
            return try satinUpdateResult(
                viewModel.setSelectedLayerSatinSize(try number()),
                property: "size"
            )
        case "satinAngle":
            return try satinUpdateResult(
                viewModel.setSelectedLayerSatinAngle(try number()),
                property: "angle"
            )
        case "satinInvert":
            return try satinUpdateResult(
                viewModel.setSelectedLayerSatinInvert(
                    try requiredBool("enabled", in: arguments)
                ),
                property: "invert"
            )
        case "satinContour":
            let rawValue = try requiredString("satinContour", in: arguments)
            guard let contour = ImageEditorLayerEffectContour(rawValue: rawValue) else {
                throw XomoAutomationCallError.invalidArgument("Unknown satin contour")
            }
            return try satinUpdateResult(
                viewModel.setSelectedLayerSatinContour(contour),
                property: "contour"
            )
        case "bevelSize":
            let updatedLayerCount = viewModel.setSelectedLayerBevelSize(try number())
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested bevel size"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "bevelOpacity":
            let updatedLayerCount = viewModel.setSelectedLayerBevelOpacity(try number())
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested bevel opacity"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "bevelHighlightColor":
            let updatedLayerCount = viewModel.setSelectedLayerBevelHighlightColor(
                viewModel.foregroundColor
            )
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested bevel highlight color"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "bevelShadowColor":
            let updatedLayerCount = viewModel.setSelectedLayerBevelShadowColor(
                viewModel.foregroundColor
            )
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested bevel shadow color"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "bevelSoften":
            let updatedLayerCount = viewModel.setSelectedLayerBevelSoften(try number())
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested bevel soften value"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "bevelAngle":
            let previousGlobalLightAngle = viewModel.document.globalLightAngle
            let updatedLayerCount = viewModel.setSelectedLayerBevelAngle(try number())
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested bevel angle"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount)),
                "globalLightUpdated": .bool(
                    abs(viewModel.document.globalLightAngle - previousGlobalLightAngle) > 0.001
                )
            ])
        case "shadowUsesGlobalLight":
            return try globalLightLinkageResult(
                viewModel.setSelectedLayerShadowUsesGlobalLight(
                    try requiredBool("enabled", in: arguments)
                ),
                property: "shadow"
            )
        case "innerShadowUsesGlobalLight":
            return try globalLightLinkageResult(
                viewModel.setSelectedLayerInnerShadowUsesGlobalLight(
                    try requiredBool("enabled", in: arguments)
                ),
                property: "inner shadow"
            )
        case "bevelUsesGlobalLight":
            return try globalLightLinkageResult(
                viewModel.setSelectedLayerBevelUsesGlobalLight(
                    try requiredBool("enabled", in: arguments)
                ),
                property: "bevel"
            )
        case "bevelDirection":
            let rawValue = try requiredString("bevelDirection", in: arguments)
            guard let direction = ImageEditorBevelDirection(rawValue: rawValue) else {
                throw XomoAutomationCallError.invalidArgument("Unknown bevel direction")
            }
            let updatedLayerCount = viewModel.setSelectedLayerBevelDirection(direction)
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "No editable layer needs the requested bevel direction"
                )
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        default: throw XomoAutomationCallError.invalidArgument("Unknown layer style setting")
        }
    }

    private func globalLightLinkageResult(
        _ updatedLayerCount: Int,
        property: String
    ) throws -> XomoJSONValue {
        guard updatedLayerCount > 0 else {
            throw XomoAutomationCallError.operationFailed(
                "No editable layer needs the requested \(property) global-light linkage"
            )
        }
        return .object([
            "updatedLayerCount": .number(Double(updatedLayerCount))
        ])
    }

    private func satinUpdateResult(
        _ updatedLayerCount: Int,
        property: String
    ) throws -> XomoJSONValue {
        guard updatedLayerCount > 0 else {
            throw XomoAutomationCallError.operationFailed(
                "No editable layer needs the requested satin \(property)"
            )
        }
        return .object([
            "updatedLayerCount": .number(Double(updatedLayerCount))
        ])
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
        case "placeEmbedded":
            let rawPath = try requiredString("path", in: arguments)
            let url = URL(fileURLWithPath: NSString(string: rawPath).expandingTildeInPath)
            guard viewModel.placeEmbeddedSmartObjectFile(url) else {
                throw XomoAutomationCallError.operationFailed("Embedded Smart Object placement failed")
            }
        case "replaceContents":
            let rawPath = try requiredString("path", in: arguments)
            let url = URL(fileURLWithPath: NSString(string: rawPath).expandingTildeInPath)
            guard viewModel.replaceSelectedSmartObjectContentsFile(url).succeeded else {
                throw XomoAutomationCallError.operationFailed(
                    "Smart Object content replacement failed"
                )
            }
        case "resetTransform": viewModel.resetSelectedSmartObjectTransform()
        case "makeUnique": viewModel.makeSelectedSmartObjectUnique()
        case "newViaCopy":
            guard viewModel.createSmartObjectViaCopy() else {
                throw XomoAutomationCallError.operationFailed(
                    "New Smart Object via Copy requires one selected Smart Object"
                )
            }
        case "exportSourcePNG":
            let rawPath = try requiredString("path", in: arguments)
            let url = URL(fileURLWithPath: NSString(string: rawPath).expandingTildeInPath)
            guard viewModel.writeSelectedSmartObjectSourcePNG(to: url) else {
                throw XomoAutomationCallError.operationFailed(
                    "Smart Object source PNG export failed"
                )
            }
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
            viewModel.beginSelectedLayerFillOpacityChange()
            viewModel.setSelectedLayerFillOpacity(try requiredNumber("value", in: arguments))
            viewModel.commitSelectedLayerFillOpacityChange()
        case "blendIfSourceBlack":
            viewModel.beginSelectedLayerBlendIfSourceBlackChange()
            viewModel.setSelectedLayerBlendIfSourceBlack(try requiredNumber("value", in: arguments))
            viewModel.commitSelectedLayerBlendIfChange()
        case "blendIfSourceWhite":
            viewModel.beginSelectedLayerBlendIfSourceWhiteChange()
            viewModel.setSelectedLayerBlendIfSourceWhite(try requiredNumber("value", in: arguments))
            viewModel.commitSelectedLayerBlendIfChange()
        case "blendIfUnderlyingBlack":
            viewModel.beginSelectedLayerBlendIfUnderlyingBlackChange()
            viewModel.setSelectedLayerBlendIfUnderlyingBlack(try requiredNumber("value", in: arguments))
            viewModel.commitSelectedLayerBlendIfChange()
        case "blendIfUnderlyingWhite":
            viewModel.beginSelectedLayerBlendIfUnderlyingWhiteChange()
            viewModel.setSelectedLayerBlendIfUnderlyingWhite(try requiredNumber("value", in: arguments))
            viewModel.commitSelectedLayerBlendIfChange()
        case "maskDensity":
            viewModel.beginSelectedLayerMaskDensityChange()
            viewModel.setSelectedLayerMaskDensity(try requiredNumber("value", in: arguments))
            viewModel.commitSelectedLayerMaskDensityChange()
        case "maskFeather":
            viewModel.beginSelectedLayerMaskFeatherChange()
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
        case "previous": viewModel.applyPreviousLayerComp()
        case "next": viewModel.applyNextLayerComp()
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
        let action = try requiredString("action", in: arguments)
        if Self.selectionEditActionsRequiringActiveSelection.contains(action) {
            let fillsQuickMask = viewModel.isQuickMaskMode
                && (action == "fillForeground" || action == "fillBackground")
            if !fillsQuickMask {
                try requireActiveSelection(for: action, viewModel: viewModel)
            }
            try requireSelectionEditAvailability(for: action, viewModel: viewModel)
        }
        switch action {
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
        let action = try requiredString("action", in: arguments)
        if Self.actionsRequiringActiveSelection.contains(action) {
            try requireActiveSelection(for: action, viewModel: viewModel)
        }
        if action == "reselect", !viewModel.canReselectSelection {
            throw XomoAutomationCallError.operationFailed(
                "Reselect requires no active selection and an available cleared-selection snapshot"
            )
        }
        if action == "restoreSaved", !viewModel.hasSavedSelection {
            throw XomoAutomationCallError.operationFailed(
                "Restore saved selection requires an available saved selection"
            )
        }
        switch action {
        case "loadTransparency":
            let threshold = try selectionAlphaThreshold(arguments["threshold"])
            guard viewModel.canLoadSelectionFromLayerTransparency else {
                throw XomoAutomationCallError.operationFailed(
                    "Loading a selection from transparency requires a selected pixel layer"
                )
            }
            viewModel.loadSelectionFromLayerTransparency(
                threshold: threshold
            )
        case "save": viewModel.saveCurrentSelection()
        case "reselect": viewModel.reselectSelection()
        case "restoreSaved": viewModel.restoreSavedSelection()
        case "colorRange": viewModel.selectColorRangeFromForeground(tolerance: try selectionTolerance(arguments["tolerance"]))
        case "similarColors": viewModel.selectSimilarColors(tolerance: try selectionTolerance(arguments["tolerance"]))
        case "growColor": viewModel.growColorSelection(tolerance: try selectionTolerance(arguments["tolerance"]))
        case "expand": viewModel.expandSelection(radius: try selectionRadius(arguments["amount"], maximum: 64))
        case "contract": viewModel.contractSelection(radius: try selectionRadius(arguments["amount"], maximum: 64))
        case "border": viewModel.borderSelection(radius: try selectionRadius(arguments["amount"], maximum: 64))
        case "smooth": viewModel.smoothSelection(radius: try selectionRadius(arguments["amount"], maximum: 16))
        case "fillHoles": viewModel.fillSelectionHoles()
        case "removeSpeckles": viewModel.removeSelectionSpeckles(
            maximumArea: try selectionRadius(arguments["amount"], maximum: 64)
        )
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

    private func requireActiveSelection(
        for action: String,
        viewModel: ImageEditorViewModel
    ) throws {
        guard viewModel.hasEffectiveSelectionPixels else {
            throw XomoAutomationCallError.operationFailed(
                "Selection action \(action) requires an active selection"
            )
        }
    }

    private func requireSelectionEditAvailability(
        for action: String,
        viewModel: ImageEditorViewModel
    ) throws {
        let requirement: (isAvailable: Bool, description: String)
        switch action {
        case "fillForeground", "fillBackground":
            requirement = (viewModel.canFillCurrentEditingTarget, "a fillable editing target")
        case "stroke", "contentAwareFill":
            requirement = (viewModel.canEditSelectionPixels, "an editable selected pixel layer")
        case "clearPixels":
            requirement = (viewModel.canRemoveSelectionPixels, "a removable selected pixel layer")
        case "copyToLayer":
            requirement = (viewModel.canCopySelectionToNewLayer, "a copyable selected pixel layer")
        case "cutToLayer":
            requirement = (viewModel.canCutSelectionToNewLayer, "a removable single selected pixel layer")
        default:
            return
        }
        guard requirement.isAvailable else {
            throw XomoAutomationCallError.operationFailed(
                "Selection edit action \(action) requires \(requirement.description)"
            )
        }
    }

    private func selectionRadius(_ value: XomoJSONValue?, maximum: Int) throws -> Int? {
        guard let value else { return nil }
        guard let number = value.doubleValue,
              number.isFinite,
              number.rounded() == number,
              (1...Double(maximum)).contains(number)
        else {
            throw XomoAutomationCallError.invalidArgument(
                "Selection radius must be an integer from 1 through \(maximum)"
            )
        }
        return Int(number)
    }

    private func selectionTolerance(_ value: XomoJSONValue?) throws -> CGFloat? {
        guard let value else { return nil }
        guard let number = value.doubleValue,
              number.isFinite,
              (0...1).contains(number)
        else {
            throw XomoAutomationCallError.invalidArgument("Selection tolerance must be a number from 0 through 1")
        }
        return CGFloat(number)
    }

    private func selectionAlphaThreshold(_ value: XomoJSONValue?) throws -> Int? {
        guard let value else { return nil }
        guard let number = value.doubleValue,
              number.isFinite,
              number.rounded() == number,
              (0...255).contains(number)
        else {
            throw XomoAutomationCallError.invalidArgument(
                "Layer transparency threshold must be an integer from 0 through 255"
            )
        }
        return Int(number)
    }

    private func quickMaskAction(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws -> XomoJSONValue {
        let action = try requiredString("action", in: arguments)
        switch action {
        case "get":
            return quickMaskResult(viewModel)
        case "toggle":
            viewModel.toggleQuickMaskMode()
        case "setTarget":
            let rawTarget = try requiredString("target", in: arguments)
            guard let target = ImageEditorQuickMaskOverlayTarget(rawValue: rawTarget) else {
                throw XomoAutomationCallError.invalidArgument("Unknown quick mask target: \(rawTarget)")
            }
            viewModel.setQuickMaskOverlayTarget(target)
        case "setColor":
            viewModel.setQuickMaskOverlayColor(try requiredColor("color", in: arguments))
        case "setOpacity":
            viewModel.setQuickMaskOverlayOpacity(CGFloat(try requiredNumber("opacity", in: arguments)))
        case "paint":
            guard viewModel.isQuickMaskMode else {
                throw XomoAutomationCallError.operationFailed("Quick Mask is not active")
            }
            viewModel.paintQuickMaskSelection(
                samples: try requiredBrushSamples("points", in: arguments),
                reveal: arguments["reveal"]?.boolValue ?? false
            )
        default:
            throw XomoAutomationCallError.invalidArgument("Unknown quick mask action: \(action)")
        }
        return quickMaskResult(viewModel)
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
        let action = try requiredString("action", in: arguments)
        try requireClipboardActionAvailability(for: action, viewModel: viewModel)
        switch action {
        case "pasteAsLayer":
            try requireClipboardImport(viewModel.pasteClipboardAsLayer(), action: action)
        case "pasteIntoSelection":
            try requireClipboardImport(viewModel.pasteClipboardIntoSelectionAsLayer(), action: action)
        case "pasteInPlace":
            try requireClipboardImport(viewModel.pasteClipboardInPlaceAsLayer(), action: action)
        case "copySelection":
            try requireClipboardOutput(viewModel.copySelectionToClipboard(), action: action)
        case "cutSelection":
            try requireClipboardOutput(viewModel.cutSelectionToClipboard(), action: action)
        case "cutSelectedLayers":
            try requireClipboardOutput(viewModel.cutSelectedLayersToClipboard(), action: action)
        case "copyMerged":
            try requireClipboardOutput(viewModel.copyMergedToClipboard(), action: action)
        case "copySelectedLayers":
            try requireClipboardOutput(viewModel.copySelectedLayersToClipboard(), action: action)
        default: throw XomoAutomationCallError.invalidArgument("Unknown clipboard action")
        }
    }

    private func requireClipboardActionAvailability(
        for action: String,
        viewModel: ImageEditorViewModel
    ) throws {
        let requirement: (isAvailable: Bool, description: String)
        switch action {
        case "pasteAsLayer":
            requirement = (viewModel.canPasteClipboardImage, "an image on the clipboard")
        case "pasteIntoSelection":
            requirement = (
                viewModel.canPasteClipboardImageIntoSelection,
                "an image on the clipboard and an active selection"
            )
        case "pasteInPlace":
            requirement = (
                viewModel.canPasteClipboardImageInPlace,
                "an image with Xomo position metadata on the clipboard"
            )
        case "copySelection":
            requirement = (
                viewModel.canCopySelectionToClipboard,
                "an active copyable selection or selected layers"
            )
        case "cutSelection":
            requirement = (
                viewModel.canCutSelectionToClipboard,
                "a removable pixel selection or removable selected objects"
            )
        case "cutSelectedLayers":
            requirement = (
                viewModel.canCutSelectedLayersToClipboard,
                "removable selected objects"
            )
        case "copyMerged":
            requirement = (viewModel.canCopyMergedToClipboard, "a non-empty canvas")
        case "copySelectedLayers":
            requirement = (viewModel.canCopySelectedLayersToClipboard, "copyable selected layers")
        default:
            return
        }
        guard requirement.isAvailable else {
            throw XomoAutomationCallError.operationFailed(
                "Clipboard action \(action) requires \(requirement.description)"
            )
        }
    }

    private func requireClipboardOutput(_ didProduceOutput: Bool, action: String) throws {
        guard didProduceOutput else {
            throw XomoAutomationCallError.operationFailed(
                "Clipboard action \(action) did not produce clipboard content"
            )
        }
    }

    private func requireClipboardImport(_ didImportLayer: Bool, action: String) throws {
        guard didImportLayer else {
            throw XomoAutomationCallError.operationFailed(
                "Clipboard action \(action) did not import a layer"
            )
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
            viewModel.selectXomoComponentTheme(theme)
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
        guard tool == "brush" || tool == "eraser" else {
            throw XomoAutomationCallError.invalidArgument("Stroke tool must be brush or eraser")
        }
        let samples = try requiredBrushSamples("points", in: arguments)
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
        if let pressureOpacity = arguments["pressureOpacity"]?.boolValue {
            viewModel.setBrushPressureControlsOpacity(pressureOpacity)
        }
        if let pressureFlow = arguments["pressureFlow"]?.boolValue {
            viewModel.setBrushPressureControlsFlow(pressureFlow)
        }
        if let pressureSensitivity = arguments["pressureSensitivity"]?.doubleValue {
            viewModel.setBrushPressureSensitivity(CGFloat(pressureSensitivity))
        }
        if let minimumDiameter = arguments["minimumDiameter"]?.doubleValue {
            viewModel.setBrushMinimumDiameter(CGFloat(minimumDiameter))
        }
        if let minimumOpacity = arguments["minimumOpacity"]?.doubleValue {
            viewModel.setBrushMinimumOpacity(CGFloat(minimumOpacity))
        }
        if let minimumFlow = arguments["minimumFlow"]?.doubleValue {
            viewModel.setBrushMinimumFlow(CGFloat(minimumFlow))
        }
        if let tiltShape = arguments["tiltShape"]?.boolValue {
            viewModel.setBrushTiltControlsShape(tiltShape)
        }
        if let roundness = arguments["roundness"]?.doubleValue {
            viewModel.setBrushTipRoundness(CGFloat(roundness))
        }
        if let angle = arguments["angle"]?.doubleValue {
            viewModel.setBrushTipAngleDegrees(CGFloat(angle))
        }
        if let smoothing = arguments["smoothing"]?.doubleValue {
            viewModel.setBrushSmoothing(CGFloat(smoothing))
        }
        switch tool {
        case "brush": viewModel.drawBrush(samples: samples)
        case "eraser": viewModel.drawBrush(samples: samples, erase: true)
        default: break
        }
    }

    private func specialPaint(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws {
        let action = try requiredString("action", in: arguments)
        func validatedCloneSourceSlotIndex() throws -> Int? {
            guard let rawSlot = arguments["sourceSlot"]?.doubleValue else { return nil }
            guard rawSlot.isFinite,
                  rawSlot.rounded() == rawSlot,
                  (1...Double(ImageEditorCloneSourceSlotState.maximumCount)).contains(rawSlot)
            else {
                throw XomoAutomationCallError.invalidArgument(
                    "Clone sourceSlot must be an integer from 1 through \(ImageEditorCloneSourceSlotState.maximumCount)"
                )
            }
            return Int(rawSlot) - 1
        }
        if action == "resetCloneSourceTransform" {
            if let sourceSlotIndex = try validatedCloneSourceSlotIndex() {
                _ = viewModel.selectCloneSourceSlot(sourceSlotIndex)
            }
            viewModel.resetActiveCloneSourceTransform()
            return
        }
        if action == "clearCloneSource" {
            if let sourceSlotIndex = try validatedCloneSourceSlotIndex() {
                _ = viewModel.selectCloneSourceSlot(sourceSlotIndex)
            }
            viewModel.clearActiveCloneSource()
            return
        }
        let resolvedPatchPatternKind: ImageEditorPatternOverlayKind?
        if action == "patchPattern", let rawKind = arguments["patternKind"]?.stringValue {
            guard let kind = ImageEditorPatternOverlayKind(rawValue: rawKind) else {
                throw XomoAutomationCallError.invalidArgument(
                    "Patch patternKind must be checkerboard, diagonalStripes, or dots"
                )
            }
            resolvedPatchPatternKind = kind
        } else {
            resolvedPatchPatternKind = nil
        }
        if let size = arguments["size"]?.doubleValue { viewModel.brushSize = size }
        let usesStrength = ["blur", "sharpen", "smudge"].contains(action)
        let usesExposure = ["dodge", "burn"].contains(action)
        let usesFlow = action == "sponge"
        let usesSampledBrush = action == "cloneStamp" || action == "healing"
        let usesRetouchPressure = usesStrength || usesExposure || usesFlow || usesSampledBrush
        if usesExposure, let exposure = arguments["exposure"]?.doubleValue {
            viewModel.opacity = max(0, min(1, exposure))
        } else if usesStrength, let strength = arguments["strength"]?.doubleValue {
            viewModel.opacity = max(0, min(1, strength))
        } else if usesFlow, let flow = arguments["flow"]?.doubleValue {
            viewModel.opacity = max(0, min(1, flow))
        } else if let opacity = arguments["opacity"]?.doubleValue {
            viewModel.opacity = opacity
        }
        if let hardness = arguments["hardness"]?.doubleValue {
            viewModel.hardness = max(0, min(1, hardness))
        }
        if usesExposure, let rawRange = arguments["toneRange"]?.stringValue {
            guard let range = ImageEditorToneRange(rawValue: rawRange) else {
                throw XomoAutomationCallError.invalidArgument(
                    "Dodge or burn toneRange must be shadows, midtones, or highlights"
                )
            }
            viewModel.toneRange = range
        }
        if usesExposure, let protectTones = arguments["protectTones"]?.boolValue {
            viewModel.protectToneBrushTones = protectTones
        }
        if usesExposure, let airbrush = arguments["airbrush"]?.boolValue {
            viewModel.toneBrushAirbrushEnabled = airbrush
        }
        var airbrushPulseCount = 0
        if usesExposure, let rawPulseCount = arguments["airbrushPulses"]?.doubleValue {
            guard rawPulseCount.isFinite,
                  rawPulseCount.rounded() == rawPulseCount,
                  (0...Double(ImageEditorToneAirbrushStroke.maximumPulseCount)).contains(rawPulseCount)
            else {
                throw XomoAutomationCallError.invalidArgument(
                    "Dodge or burn airbrushPulses must be an integer from 0 to \(ImageEditorToneAirbrushStroke.maximumPulseCount)"
                )
            }
            airbrushPulseCount = Int(rawPulseCount)
            if arguments["airbrush"] == nil {
                viewModel.toneBrushAirbrushEnabled = true
            }
        }
        if let feather = arguments["feather"]?.doubleValue { viewModel.feather = max(0, feather) }
        if action == "patchPattern" {
            if let resolvedPatchPatternKind {
                viewModel.patchPatternContent.kind = resolvedPatchPatternKind
            }
            guard viewModel.applyPatchPattern() else {
                throw XomoAutomationCallError.operationFailed(
                    "Patch pattern requires an editable pixel selection that changes the active layer"
                )
            }
            return
        }
        if action == "patch" {
            let resolvedDiffusion: Int?
            if let rawDiffusion = arguments["diffusion"]?.doubleValue {
                guard rawDiffusion.isFinite,
                      rawDiffusion.rounded() == rawDiffusion,
                      (1.0...7.0).contains(rawDiffusion)
                else {
                    throw XomoAutomationCallError.invalidArgument(
                        "Patch diffusion must be an integer from 1 through 7"
                    )
                }
                resolvedDiffusion = Int(rawDiffusion)
            } else {
                resolvedDiffusion = nil
            }
            let resolvedSampleSource: ImageEditorCloneSampleSource?
            if let rawSource = arguments["sampleSource"]?.stringValue {
                guard let sampleSource = ImageEditorCloneSampleSource(rawValue: rawSource) else {
                    throw XomoAutomationCallError.invalidArgument(
                        "Patch sampleSource must be currentLayer, currentAndBelow, or allVisible"
                    )
                }
                resolvedSampleSource = sampleSource
            } else {
                resolvedSampleSource = nil
            }
            guard resolvedSampleSource == nil || arguments["sampleAllLayers"] == nil else {
                throw XomoAutomationCallError.invalidArgument(
                    "Patch sampleSource cannot be combined with legacy sampleAllLayers"
                )
            }
            if let transparent = arguments["transparent"]?.boolValue {
                viewModel.patchTransparentEnabled = transparent
            }
            if let resolvedSampleSource {
                viewModel.patchSampleSource = resolvedSampleSource
            } else if let sampleAllLayers = arguments["sampleAllLayers"]?.boolValue {
                viewModel.patchSampleAllLayersEnabled = sampleAllLayers
            }
            if let ignoresAdjustmentLayers = arguments["ignoresAdjustmentLayers"]?.boolValue {
                viewModel.patchIgnoresAdjustmentLayers = ignoresAdjustmentLayers
            }
            if let resolvedDiffusion {
                viewModel.patchDiffusion = resolvedDiffusion
            }
        }
        if action == "setCloneSource" || action == "cloneStamp" {
            func validatedCloneScale(_ argumentName: String) throws -> CGFloat? {
                guard let rawPercent = arguments[argumentName]?.doubleValue else { return nil }
                guard rawPercent.isFinite,
                      (Double(ImageEditorCloneSourceSlotState.minimumScalePercent)...Double(ImageEditorCloneSourceSlotState.maximumScalePercent))
                        .contains(rawPercent)
                else {
                    throw XomoAutomationCallError.invalidArgument(
                        "Clone \(argumentName) must be from \(Int(ImageEditorCloneSourceSlotState.minimumScalePercent)) through \(Int(ImageEditorCloneSourceSlotState.maximumScalePercent))"
                    )
                }
                return CGFloat(rawPercent)
            }

            let resolvedSourceSlotIndex = try validatedCloneSourceSlotIndex()
            let resolvedUniformScale = try validatedCloneScale("scalePercent")
            let resolvedHorizontalScale = try validatedCloneScale("scaleXPercent")
            let resolvedVerticalScale = try validatedCloneScale("scaleYPercent")
            let resolvedRotationDegrees: CGFloat?
            if let rawDegrees = arguments["rotationDegrees"]?.doubleValue {
                guard rawDegrees.isFinite,
                      (Double(ImageEditorCloneSourceSlotState.minimumRotationDegrees)...Double(ImageEditorCloneSourceSlotState.maximumRotationDegrees))
                        .contains(rawDegrees)
                else {
                    throw XomoAutomationCallError.invalidArgument(
                        "Clone rotationDegrees must be from \(Int(ImageEditorCloneSourceSlotState.minimumRotationDegrees)) through \(Int(ImageEditorCloneSourceSlotState.maximumRotationDegrees))"
                    )
                }
                resolvedRotationDegrees = CGFloat(rawDegrees)
            } else {
                resolvedRotationDegrees = nil
            }
            let resolvedOverlayOpacityPercent: CGFloat?
            if let rawPercent = arguments["overlayOpacityPercent"]?.doubleValue {
                guard rawPercent.isFinite, (0...100).contains(rawPercent) else {
                    throw XomoAutomationCallError.invalidArgument(
                        "Clone overlayOpacityPercent must be from 0 through 100"
                    )
                }
                resolvedOverlayOpacityPercent = CGFloat(rawPercent)
            } else {
                resolvedOverlayOpacityPercent = nil
            }
            let resolvedOverlayBlendMode: ImageEditorCloneStampOverlayBlendMode?
            if let rawMode = arguments["overlayBlendMode"]?.stringValue {
                guard let mode = ImageEditorCloneStampOverlayBlendMode(rawValue: rawMode) else {
                    throw XomoAutomationCallError.invalidArgument(
                        "Clone overlayBlendMode must be normal, darken, lighten, or difference"
                    )
                }
                resolvedOverlayBlendMode = mode
            } else {
                resolvedOverlayBlendMode = nil
            }
            guard resolvedUniformScale == nil
                    || (resolvedHorizontalScale == nil && resolvedVerticalScale == nil)
            else {
                throw XomoAutomationCallError.invalidArgument(
                    "Clone scalePercent cannot be combined with scaleXPercent or scaleYPercent"
                )
            }
            if let resolvedSourceSlotIndex {
                _ = viewModel.selectCloneSourceSlot(resolvedSourceSlotIndex)
            }
            if let resolvedUniformScale {
                viewModel.setCloneSourceScalePercent(resolvedUniformScale)
                if let linked = arguments["scaleLinked"]?.boolValue {
                    viewModel.setCloneSourceScalesLinked(linked)
                }
            } else {
                viewModel.configureCloneSourceScale(
                    horizontalPercent: resolvedHorizontalScale,
                    verticalPercent: resolvedVerticalScale,
                    linked: arguments["scaleLinked"]?.boolValue
                )
            }
            if let flipHorizontal = arguments["flipHorizontal"]?.boolValue {
                viewModel.setCloneSourceFlipsHorizontally(flipHorizontal)
            }
            if let flipVertical = arguments["flipVertical"]?.boolValue {
                viewModel.setCloneSourceFlipsVertically(flipVertical)
            }
            if let resolvedRotationDegrees {
                viewModel.setCloneSourceRotationDegrees(resolvedRotationDegrees)
            }
            if let showOverlay = arguments["showOverlay"]?.boolValue {
                viewModel.cloneStampShowsOverlay = showOverlay
            }
            if let clipOverlayToBrush = arguments["clipOverlayToBrush"]?.boolValue {
                viewModel.cloneStampOverlayClipsToBrush = clipOverlayToBrush
            }
            if let autoHideOverlay = arguments["autoHideOverlay"]?.boolValue {
                viewModel.cloneStampOverlayAutoHidesWhilePainting = autoHideOverlay
            }
            if let invertOverlay = arguments["invertOverlay"]?.boolValue {
                viewModel.cloneStampOverlayInvertsColors = invertOverlay
            }
            if let resolvedOverlayBlendMode {
                viewModel.cloneStampOverlayBlendMode = resolvedOverlayBlendMode
            }
            if let resolvedOverlayOpacityPercent {
                viewModel.setCloneStampOverlayOpacityPercent(resolvedOverlayOpacityPercent)
            }
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
            if let ignoresAdjustmentLayers =
                arguments["ignoresAdjustmentLayers"]?.boolValue {
                viewModel.cloneStampIgnoresAdjustmentLayers =
                    ignoresAdjustmentLayers
            }
        }
        if action == "setHealingSource" || action == "healing" {
            if let rawMode = arguments["healingMode"]?.stringValue {
                guard let mode = ImageEditorHealingBrushMode(rawValue: rawMode) else {
                    throw XomoAutomationCallError.invalidArgument(
                        "Healing mode must be source or spot"
                    )
                }
                viewModel.healingBrushMode = mode
            }
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
            if let ignoresAdjustmentLayers =
                arguments["ignoresAdjustmentLayers"]?.boolValue {
                viewModel.healingBrushIgnoresAdjustmentLayers =
                    ignoresAdjustmentLayers
            }
        }
        if action == "sponge", let rawMode = arguments["spongeMode"]?.stringValue {
            guard let mode = ImageEditorSpongeMode(rawValue: rawMode) else {
                throw XomoAutomationCallError.invalidArgument(
                    "Sponge mode must be saturate or desaturate"
                )
            }
            viewModel.spongeMode = mode
        }
        if action == "sponge", let vibrance = arguments["spongeVibrance"]?.boolValue {
            viewModel.spongeVibranceEnabled = vibrance
        }
        if action == "smudge", let fingerPainting = arguments["fingerPainting"]?.boolValue {
            viewModel.smudgeFingerPaintingEnabled = fingerPainting
        }
        if action == "smudge", let sampleAllLayers = arguments["sampleAllLayers"]?.boolValue {
            viewModel.smudgeSampleAllLayersEnabled = sampleAllLayers
        }
        if usesRetouchPressure, let pressureSize = arguments["pressureSize"]?.boolValue {
            viewModel.setRetouchPressureControlsSize(pressureSize)
        }
        if usesRetouchPressure,
           let pressureSensitivity = arguments["pressureSensitivity"]?.doubleValue {
            viewModel.setRetouchPressureSensitivity(CGFloat(pressureSensitivity))
        }
        if action == "paintBucket" {
            if let tolerance = arguments["tolerance"]?.doubleValue {
                viewModel.tolerance = max(0, min(1, tolerance))
            }
            if let contiguous = arguments["contiguous"]?.boolValue {
                viewModel.isPaintBucketContiguous = contiguous
            }
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
        let samples = usesRetouchPressure
            ? try requiredBrushSamples("points", in: arguments)
            : try requiredPoints("points", in: arguments).map { ImageEditorBrushStrokeSample(point: $0) }
        let points = samples.map(\.point)
        let airbrushPulseSamples: [ImageEditorBrushStrokeSample]
        if viewModel.toneBrushAirbrushEnabled, let lastSample = samples.last {
            airbrushPulseSamples = Array(repeating: lastSample, count: airbrushPulseCount)
        } else {
            airbrushPulseSamples = []
        }
        switch action {
        case "cloneStamp": viewModel.cloneStamp(samples: samples)
        case "dodge":
            viewModel.toneBrush(
                samples: samples,
                burn: false,
                airbrushPulseSamples: airbrushPulseSamples
            )
        case "burn":
            viewModel.toneBrush(
                samples: samples,
                burn: true,
                airbrushPulseSamples: airbrushPulseSamples
            )
        case "sponge": viewModel.spongeBrush(samples: samples)
        case "blur": viewModel.blurBrush(samples: samples)
        case "sharpen": viewModel.sharpenBrush(samples: samples)
        case "smudge": viewModel.smudgeBrush(samples: samples)
        case "healing": viewModel.healingBrush(samples: samples)
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
        case "applyVector": viewModel.applyVectorMask()
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
    ) throws -> XomoJSONValue? {
        let id = try requiredUUID("id", in: arguments)
        switch try requiredString("action", in: arguments) {
        case "load":
            guard viewModel.loadSmartFilterIntoControls(id) else {
                throw XomoAutomationCallError.invalidArgument("Smart filter cannot be loaded")
            }
        case "update":
            if let intensity = arguments["intensity"]?.doubleValue { viewModel.filterIntensity = intensity }
            let updatedLayerCount = viewModel.updateSmartFilterOnSelectedLayer(id)
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.invalidArgument("Smart filter cannot be updated")
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "setOpacity":
            let updatedLayerCount = viewModel.setSmartFilterOpacityOnSelectedLayer(
                id,
                opacity: try requiredNumber("opacity", in: arguments)
            )
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.invalidArgument("Smart filter opacity cannot be updated")
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "setBlendMode":
            let updatedLayerCount = viewModel.setSmartFilterBlendModeOnSelectedLayer(
                id,
                blendMode: try smartFilterBlendMode(try requiredString("blendMode", in: arguments))
            )
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.invalidArgument("Smart filter blend mode cannot be updated")
            }
            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount))
            ])
        case "duplicate":
            guard let duplication = viewModel.duplicateSmartFilterOnSelectedLayer(id) else {
                throw XomoAutomationCallError.invalidArgument("Smart filter cannot be duplicated")
            }
            return .object([
                "duplicatedLayerCount": .number(Double(duplication.duplicatedLayerCount))
            ])
        case "remove":
            let removedLayerCount = viewModel.removeSmartFilterFromSelectedLayer(id)
            guard removedLayerCount > 0 else {
                throw XomoAutomationCallError.invalidArgument("Smart filter cannot be removed")
            }
            return .object([
                "removedLayerCount": .number(Double(removedLayerCount))
            ])
        case "moveUp":
            let movedLayerCount = viewModel.moveSmartFilterOnSelectedLayer(id, offset: -1)
            guard movedLayerCount > 0 else {
                throw XomoAutomationCallError.invalidArgument("Smart filter cannot be moved up")
            }
            return .object([
                "movedLayerCount": .number(Double(movedLayerCount))
            ])
        case "moveDown":
            let movedLayerCount = viewModel.moveSmartFilterOnSelectedLayer(id, offset: 1)
            guard movedLayerCount > 0 else {
                throw XomoAutomationCallError.invalidArgument("Smart filter cannot be moved down")
            }
            return .object([
                "movedLayerCount": .number(Double(movedLayerCount))
            ])
        default: throw XomoAutomationCallError.invalidArgument("Unknown smart filter management action")
        }
        return nil
    }

    private func smartFilterBlendMode(_ rawValue: String?) throws -> ImageEditorBlendMode {
        guard let rawValue else { return .normal }
        guard let blendMode = ImageEditorBlendMode(rawValue: rawValue),
              ImageEditorBlendMode.smartFilterCases.contains(blendMode)
        else {
            throw XomoAutomationCallError.invalidArgument("Unknown smart filter blend mode: \(rawValue)")
        }
        return blendMode
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
    ) throws -> XomoJSONValue? {
        let rawValue = try requiredString("filter", in: arguments)
        guard let filter = ImageEditorFilter(rawValue: rawValue) else {
            throw XomoAutomationCallError.invalidArgument("Unknown filter")
        }
        viewModel.selectedFilter = filter
        let settings = arguments["settings"]?.objectValue ?? [:]
        for (key, value) in settings {
            switch key {
            case "intensity": viewModel.filterIntensity = try numericSetting(value, key: key)
            case "gaussianBlurRadius": viewModel.filterGaussianBlurRadius = try numericSetting(value, key: key)
            case "sharpenAmountPercent": viewModel.filterSharpenAmountPercent = try numericSetting(value, key: key)
            case "highPassRadius": viewModel.filterHighPassRadius = try numericSetting(value, key: key)
            case "highPassGainPercent": viewModel.filterHighPassGainPercent = try numericSetting(value, key: key)
            case "morphologyRadius": viewModel.filterMorphologyRadius = try numericSetting(value, key: key)
            case "pixelateCellSize": viewModel.filterPixelateCellSize = try numericSetting(value, key: key)
            case "addNoiseAmountPercent": viewModel.filterAddNoiseAmountPercent = try numericSetting(value, key: key)
            case "addNoiseMonochromatic": viewModel.filterAddNoiseMonochromatic = try booleanSetting(value, key: key)
            case "addNoiseDistribution":
                guard
                    let rawValue = value.stringValue,
                    let distribution = ImageEditorAddNoiseDistribution(rawValue: rawValue)
                else {
                    throw XomoAutomationCallError.invalidArgument(
                        "addNoiseDistribution must be a supported string"
                    )
                }
                viewModel.filterAddNoiseDistribution = distribution
            case "motionBlurAngleDegrees": viewModel.filterMotionBlurAngleDegrees = try numericSetting(value, key: key)
            case "motionBlurDistance": viewModel.filterMotionBlurDistance = try numericSetting(value, key: key)
            case "embossAngleDegrees": viewModel.filterEmbossAngleDegrees = try numericSetting(value, key: key)
            case "embossHeight": viewModel.filterEmbossHeight = try numericSetting(value, key: key)
            case "vignetteAmountPercent": viewModel.filterVignetteAmountPercent = try numericSetting(value, key: key)
            case "vignetteMidpoint": viewModel.filterVignetteMidpoint = try numericSetting(value, key: key)
            case "oilPaintRadius": viewModel.filterOilPaintRadius = try numericSetting(value, key: key)
            case "oilPaintTonalLevels": viewModel.filterOilPaintTonalLevels = try numericSetting(value, key: key)
            case "oilPaintStylization": viewModel.filterOilPaintStylization = try numericSetting(value, key: key)
            case "oilPaintCleanliness": viewModel.filterOilPaintCleanliness = try numericSetting(value, key: key)
            case "oilPaintBristleDetail": viewModel.filterOilPaintBristleDetail = try numericSetting(value, key: key)
            case "oilPaintShine": viewModel.filterOilPaintShine = try numericSetting(value, key: key)
            case "oilPaintLightingAngleDegrees": viewModel.filterOilPaintLightingAngleDegrees = try numericSetting(value, key: key)
            case "oilPaintLightingEnabled": viewModel.filterOilPaintLightingEnabled = try booleanSetting(value, key: key)
            case "unsharpAmountPercent": viewModel.filterUnsharpAmountPercent = try numericSetting(value, key: key)
            case "unsharpRadiusPixels": viewModel.filterUnsharpRadiusPixels = try numericSetting(value, key: key)
            case "unsharpThresholdLevels": viewModel.filterUnsharpThresholdLevels = try numericSetting(value, key: key)
            case "unsharpRadius": viewModel.filterUnsharpRadius = try numericSetting(value, key: key)
            case "unsharpThreshold": viewModel.filterUnsharpThreshold = try numericSetting(value, key: key)
            case "liquifyPushXPixels": viewModel.filterLiquifyPushXPixels = try numericSetting(value, key: key)
            case "liquifyPushYPixels": viewModel.filterLiquifyPushYPixels = try numericSetting(value, key: key)
            case "liquifyPushX": viewModel.filterLiquifyPushX = try numericSetting(value, key: key)
            case "liquifyPushY": viewModel.filterLiquifyPushY = try numericSetting(value, key: key)
            case "liquifyTwirlAngleDegrees": viewModel.filterLiquifyTwirlAngleDegrees = try numericSetting(value, key: key)
            case "twirlAngle": viewModel.filterLiquifyTwirlAngle = try numericSetting(value, key: key)
            case "liquifyBulgeAmountPercent": viewModel.filterLiquifyBulgeAmountPercent = try numericSetting(value, key: key)
            case "bulgeAmount": viewModel.filterLiquifyBulgeAmount = try numericSetting(value, key: key)
            case "offsetXPixels": viewModel.filterOffsetXPixels = try numericSetting(value, key: key)
            case "offsetYPixels": viewModel.filterOffsetYPixels = try numericSetting(value, key: key)
            case "offsetX": viewModel.filterOffsetX = try numericSetting(value, key: key)
            case "offsetY": viewModel.filterOffsetY = try numericSetting(value, key: key)
            case "offsetUndefinedAreaMode":
                guard
                    let rawValue = value.stringValue,
                    let mode = ImageEditorOffsetUndefinedAreaMode(rawValue: rawValue)
                else {
                    throw XomoAutomationCallError.invalidArgument(
                        "offsetUndefinedAreaMode must be a supported string"
                    )
                }
                viewModel.filterOffsetUndefinedAreaMode = mode
            case "waveAmplitudePercent": viewModel.filterWaveAmplitudePercent = try numericSetting(value, key: key)
            case "waveAmplitude": viewModel.filterWaveAmplitude = try numericSetting(value, key: key)
            case "waveFrequency": viewModel.filterWaveFrequency = try numericSetting(value, key: key)
            case "rippleAmountPercent": viewModel.filterRippleAmountPercent = try numericSetting(value, key: key)
            case "rippleAmount": viewModel.filterRippleAmount = try numericSetting(value, key: key)
            case "rippleFrequency": viewModel.filterRippleFrequency = try numericSetting(value, key: key)
            case "pinchAmountPercent": viewModel.filterPinchAmountPercent = try numericSetting(value, key: key)
            case "pinchAmount": viewModel.filterPinchAmount = try numericSetting(value, key: key)
            case "spherizeAmountPercent": viewModel.filterSpherizeAmountPercent = try numericSetting(value, key: key)
            case "spherizeAmount": viewModel.filterSpherizeAmount = try numericSetting(value, key: key)
            case "lensDistortionAmountPercent": viewModel.filterLensDistortionAmountPercent = try numericSetting(value, key: key)
            case "lensDistortion": viewModel.filterLensDistortion = try numericSetting(value, key: key)
            default: throw XomoAutomationCallError.invalidArgument("Unknown filter setting: \(key)")
            }
        }
        switch arguments["action"]?.stringValue ?? "apply" {
        case "apply": viewModel.applySelectedFilter()
        case "addLayer": viewModel.addFilterLayer()
        case "updateLayer": viewModel.updateSelectedFilterLayer()
        case "addSmartFilter":
            let addedLayerCount = viewModel.addSmartFilterToSelectedLayer()
            guard addedLayerCount > 0 else {
                throw XomoAutomationCallError.invalidArgument("No selected layers can accept a smart filter")
            }
            return .object([
                "addedLayerCount": .number(Double(addedLayerCount))
            ])
        default: throw XomoAutomationCallError.invalidArgument("Unknown filter configure action")
        }
        return nil
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

    private func panCanvas(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws -> XomoJSONValue {
        let action = arguments["action"]?.stringValue ?? "nudge"
        switch action {
        case "nudge":
            viewModel.nudgeCanvas(by: CGSize(
                width: try requiredNumber("dx", in: arguments),
                height: try requiredNumber("dy", in: arguments)
            ))
        case "center":
            viewModel.centerCanvas(on: CGPoint(
                x: try requiredNumber("x", in: arguments),
                y: try requiredNumber("y", in: arguments)
            ))
        case "reset":
            viewModel.canvasOffset = .zero
        default:
            throw XomoAutomationCallError.invalidArgument("Unknown pan action: \(action)")
        }

        return .object([
            "action": .string(action),
            "offset": pointJSON(CGPoint(
                x: viewModel.canvasOffset.width,
                y: viewModel.canvasOffset.height
            )),
            "zoom": .number(viewModel.zoom)
        ])
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
        if scope == .slice, let rawSliceID = arguments["sliceID"]?.stringValue {
            guard let sliceID = UUID(uuidString: rawSliceID) else {
                throw XomoAutomationCallError.invalidArgument("Invalid UUID argument: sliceID")
            }
            settings.sliceID = sliceID
        }
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

    private func sliceCreateResult(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws -> XomoJSONValue {
        let name = arguments["name"]?.stringValue
        guard let slice = viewModel.createSliceFromCurrentSelection(name: name) else {
            throw XomoAutomationCallError.operationFailed(
                "Create slice requires a non-empty pixel selection or an inverted selection"
            )
        }
        return sliceJSON(slice)
    }

    private func sliceListResult(_ viewModel: ImageEditorViewModel) -> XomoJSONValue {
        .array(viewModel.availableSlices.map(sliceJSON))
    }

    private func sliceDeleteResult(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws -> XomoJSONValue {
        let id = try requiredUUID("id", in: arguments)
        guard let slice = viewModel.deleteSlice(id: id) else {
            throw XomoAutomationCallError.notFound("Slice \(id.uuidString)")
        }
        return sliceJSON(slice)
    }

    private func sliceUpdateResult(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws -> XomoJSONValue {
        let id = try requiredUUID("id", in: arguments)
        let frame: CGRect?
        if arguments["x"] != nil || arguments["y"] != nil || arguments["width"] != nil || arguments["height"] != nil {
            guard let slice = viewModel.slice(with: id) else {
                throw XomoAutomationCallError.notFound("Slice \(id.uuidString)")
            }
            frame = CGRect(
                x: arguments["x"]?.doubleValue ?? slice.frame.origin.x,
                y: arguments["y"]?.doubleValue ?? slice.frame.origin.y,
                width: arguments["width"]?.doubleValue ?? slice.frame.width,
                height: arguments["height"]?.doubleValue ?? slice.frame.height
            )
        } else {
            frame = nil
        }
        guard let slice = viewModel.updateSlice(
            id: id,
            name: arguments["name"]?.stringValue,
            frame: frame
        ) else {
            throw XomoAutomationCallError.operationFailed("Slice update is invalid")
        }
        return sliceJSON(slice)
    }

    private func sliceJSON(_ slice: ImageEditorSlice) -> XomoJSONValue {
        .object([
            "id": .string(slice.id.uuidString),
            "name": .string(slice.name),
            "x": .number(slice.frame.origin.x),
            "y": .number(slice.frame.origin.y),
            "width": .number(slice.frame.width),
            "height": .number(slice.frame.height)
        ])
    }

    private func hotspotCreateResult(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws -> XomoJSONValue {
        let name = arguments["name"]?.stringValue
        let url = arguments["url"]?.stringValue
        guard let hotspot = viewModel.createHotspotFromCurrentSelection(name: name, url: url) else {
            throw XomoAutomationCallError.operationFailed(
                "Create hotspot requires a non-empty pixel selection or an inverted selection"
            )
        }
        return hotspotJSON(hotspot)
    }

    private func hotspotListResult(_ viewModel: ImageEditorViewModel) -> XomoJSONValue {
        .array(viewModel.availableHotspots.map(hotspotJSON))
    }

    private func hotspotDeleteResult(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws -> XomoJSONValue {
        let id = try requiredUUID("id", in: arguments)
        guard let hotspot = viewModel.deleteHotspot(id: id) else {
            throw XomoAutomationCallError.notFound("Hotspot \(id.uuidString)")
        }
        return hotspotJSON(hotspot)
    }

    private func hotspotUpdateResult(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws -> XomoJSONValue {
        let id = try requiredUUID("id", in: arguments)
        let frame: CGRect?
        if arguments["x"] != nil || arguments["y"] != nil || arguments["width"] != nil || arguments["height"] != nil {
            guard let hotspot = viewModel.hotspot(with: id) else {
                throw XomoAutomationCallError.notFound("Hotspot \(id.uuidString)")
            }
            frame = CGRect(
                x: arguments["x"]?.doubleValue ?? hotspot.frame.origin.x,
                y: arguments["y"]?.doubleValue ?? hotspot.frame.origin.y,
                width: arguments["width"]?.doubleValue ?? hotspot.frame.width,
                height: arguments["height"]?.doubleValue ?? hotspot.frame.height
            )
        } else {
            frame = nil
        }
        guard let hotspot = viewModel.updateHotspot(
            id: id,
            name: arguments["name"]?.stringValue,
            url: arguments["url"]?.stringValue,
            frame: frame
        ) else {
            throw XomoAutomationCallError.operationFailed("Hotspot update is invalid")
        }
        return hotspotJSON(hotspot)
    }

    private func hotspotHTMLExportResult(_ viewModel: ImageEditorViewModel) throws -> XomoJSONValue {
        guard let data = viewModel.hotspotHTMLData() else {
            throw XomoAutomationCallError.operationFailed("HTML export requires at least one hotspot")
        }
        return .object([
            "filename": .string("\(viewModel.document.sourceName).hotspots.html"),
            "mimeType": .string("text/html"),
            "base64": .string(data.base64EncodedString())
        ])
    }

    private func hotspotJSON(_ hotspot: ImageEditorHotspot) -> XomoJSONValue {
        .object([
            "id": .string(hotspot.id.uuidString),
            "name": .string(hotspot.name),
            "url": .string(hotspot.url),
            "x": .number(hotspot.frame.origin.x),
            "y": .number(hotspot.frame.origin.y),
            "width": .number(hotspot.frame.width),
            "height": .number(hotspot.frame.height)
        ])
    }

    private func psdInspectionResult(
        _ arguments: [String: XomoJSONValue]
    ) throws -> XomoJSONValue {
        let rawPath = try requiredString("path", in: arguments)
        let (url, data, byteCount) = try psdInspectionFile(rawPath)
        let report: ImageEditorPSDCompatibilityReport
        do {
            report = try ImageEditorPSDCodec.compatibilityReport(data)
        } catch {
            throw XomoAutomationCallError.operationFailed(
                "PSD inspection failed: \(error.localizedDescription)"
            )
        }
        return psdInspectionJSON(report: report, url: url, byteCount: byteCount)
    }

    private func psdOpenResult(
        _ arguments: [String: XomoJSONValue]
    ) throws -> XomoJSONValue {
        let rawPath = try requiredString("path", in: arguments)
        let url = URL(fileURLWithPath: NSString(string: rawPath).expandingTildeInPath)
        guard XomoExternalDocumentOpenPolicy.kind(for: url) == .photoshop else {
            throw XomoAutomationCallError.invalidArgument("PSD open requires a .psd file")
        }
        let attributes: [FileAttributeKey: Any]
        do {
            attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        } catch {
            throw XomoAutomationCallError.operationFailed(
                "PSD open could not read file metadata: \(error.localizedDescription)"
            )
        }
        guard (attributes[.type] as? FileAttributeType) == .typeRegular else {
            throw XomoAutomationCallError.invalidArgument("PSD open requires a regular file")
        }
        let byteCount = (attributes[.size] as? NSNumber)?.intValue ?? 0
        guard byteCount <= Self.maximumPSDInspectionBytes else {
            throw XomoAutomationCallError.invalidArgument("PSD file exceeds the 512 MB open limit")
        }
        XomoExternalDocumentOpenCoordinator.shared.open(url)
        return .object([
            "path": .string(url.path),
            "fileName": .string(url.lastPathComponent),
            "bytes": .number(Double(byteCount)),
            "status": .string("queued")
        ])
    }

    private func psdSaveResult(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws -> XomoJSONValue {
        let rawPath = try requiredString("path", in: arguments)
        let url = URL(fileURLWithPath: NSString(string: rawPath).expandingTildeInPath)
        guard XomoExternalDocumentOpenPolicy.kind(for: url) == .photoshop else {
            throw XomoAutomationCallError.invalidArgument("PSD save requires a .psd file")
        }
        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
           (attributes[.type] as? FileAttributeType) != .typeRegular {
            throw XomoAutomationCallError.invalidArgument("PSD save destination must be a regular file")
        }

        var settings = ImageEditorExportSettings()
        settings.format = .psd
        guard let data = viewModel.exportData(settings: settings) else {
            throw XomoAutomationCallError.operationFailed("PSD export failed")
        }
        guard data.count <= Self.maximumPSDInspectionBytes else {
            throw XomoAutomationCallError.invalidArgument("PSD export exceeds the 512 MB automation limit")
        }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw XomoAutomationCallError.operationFailed(
                "PSD save failed: \(error.localizedDescription)"
            )
        }
        let report: ImageEditorPSDCompatibilityReport
        do {
            report = try ImageEditorPSDCodec.compatibilityReport(data)
        } catch {
            throw XomoAutomationCallError.operationFailed(
                "PSD save verification failed: \(error.localizedDescription)"
            )
        }
        return .object([
            "path": .string(url.path),
            "fileName": .string(url.lastPathComponent),
            "bytes": .number(Double(data.count)),
            "status": .string("saved"),
            "width": .number(Double(report.width)),
            "height": .number(Double(report.height)),
            "layerCount": .number(Double(report.layerCount)),
            "requiresAttention": .bool(report.requiresAttention)
        ])
    }

    private func psdInspectionFile(_ rawPath: String) throws -> (URL, Data, Int) {
        let url = URL(fileURLWithPath: NSString(string: rawPath).expandingTildeInPath)
        guard url.pathExtension.lowercased() == "psd" else {
            throw XomoAutomationCallError.invalidArgument("PSD inspection requires a .psd file")
        }
        let attributes: [FileAttributeKey: Any]
        do {
            attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        } catch {
            throw XomoAutomationCallError.operationFailed(
                "PSD inspection could not read file metadata: \(error.localizedDescription)"
            )
        }
        let byteCount = (attributes[.size] as? NSNumber)?.intValue ?? 0
        guard byteCount <= Self.maximumPSDInspectionBytes else {
            throw XomoAutomationCallError.invalidArgument("PSD file exceeds the 512 MB inspection limit")
        }
        do {
            return (url, try Data(contentsOf: url, options: .mappedIfSafe), byteCount)
        } catch {
            throw XomoAutomationCallError.operationFailed(
                "PSD inspection could not read file data: \(error.localizedDescription)"
            )
        }
    }

    private func psdInspectionJSON(
        report: ImageEditorPSDCompatibilityReport,
        url: URL,
        byteCount: Int
    ) -> XomoJSONValue {
        return .object([
            "path": .string(url.path),
            "fileName": .string(url.lastPathComponent),
            "bytes": .number(Double(byteCount)),
            "width": .number(Double(report.width)),
            "height": .number(Double(report.height)),
            "bitDepth": .number(Double(report.bitDepth)),
            "colorMode": .number(Double(report.colorMode)),
            "layerCount": .number(Double(report.layerCount)),
            "groupCount": .number(Double(report.groupCount)),
            "maskCount": .number(Double(report.maskCount)),
            "compressions": .array(report.compressions.sorted { $0.rawValue < $1.rawValue }.map { .string($0.identifier) }),
            "requiresAttention": .bool(report.requiresAttention),
            "issues": .array(report.issues.map { issue in
                .object([
                    "kind": .string(issue.kind.rawValue),
                    "count": .number(Double(issue.count))
                ])
            })
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

    private func requiredSelectionRect(
        _ arguments: [String: XomoJSONValue],
        canvasSize: CGSize
    ) throws -> CGRect {
        let rect = CGRect(
            x: try requiredNumber("x", in: arguments),
            y: try requiredNumber("y", in: arguments),
            width: try requiredNumber("width", in: arguments),
            height: try requiredNumber("height", in: arguments)
        )
        guard rect.width > 2,
              rect.height > 2,
              rect.minX >= 0,
              rect.minY >= 0,
              rect.maxX <= canvasSize.width,
              rect.maxY <= canvasSize.height
        else {
            throw XomoAutomationCallError.invalidArgument(
                "Selection rectangle must have positive dimensions above 2 pixels and remain inside the canvas"
            )
        }
        return rect
    }

    private func requiredLassoPoints(
        _ arguments: [String: XomoJSONValue],
        canvasSize: CGSize
    ) throws -> [CGPoint] {
        let points = try requiredPoints("points", in: arguments)
        guard points.count >= 3 else {
            throw XomoAutomationCallError.invalidArgument("Lasso selection needs at least three points")
        }
        guard points.allSatisfy({ point in
            point.x.isFinite && point.y.isFinite &&
                point.x >= 0 && point.y >= 0 &&
                point.x <= canvasSize.width && point.y <= canvasSize.height
        }) else {
            throw XomoAutomationCallError.invalidArgument("Lasso points must all be inside the canvas")
        }
        guard ImageEditorSelection.polygon(points) != nil else {
            throw XomoAutomationCallError.invalidArgument("Lasso selection must enclose a nonzero area")
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
            let tiltX = object["tiltX"]?.doubleValue
            let tiltY = object["tiltY"]?.doubleValue
            let tilt: ImageEditorStylusTilt?
            switch (tiltX, tiltY) {
            case (nil, nil):
                tilt = nil
            case (.some(let x), .some(let y)):
                tilt = ImageEditorStylusInput.normalizedTilt(
                    rawX: CGFloat(x),
                    rawY: CGFloat(y),
                    supportsTilt: true
                )
            default:
                throw XomoAutomationCallError.invalidArgument(
                    "Each stylus point needs both tiltX and tiltY"
                )
            }
            return ImageEditorBrushStrokeSample(
                point: CGPoint(x: x, y: y),
                pressure: pressure,
                tilt: tilt
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

    private func colorSamplersResult(
        _ viewModel: ImageEditorViewModel
    ) -> XomoJSONValue {
        viewModel.refreshColorSamplers()
        return .array(viewModel.colorSamplerPoints.enumerated().map { index, sample in
            colorSamplerJSON(
                sample,
                index: index,
                sampleSize: viewModel.selectedColorSamplerSampleSize,
                sampleSource: viewModel.activeColorSamplerSource,
                ignoresAdjustmentLayers:
                    viewModel.colorSamplerIgnoresAdjustmentLayers
            )
        })
    }

    private func colorSamplerJSON(
        _ sample: ImageEditorColorSamplerPoint,
        index: Int,
        sampleSize: ImageEditorColorSamplerSampleSize,
        sampleSource: ImageEditorColorSamplerSource,
        ignoresAdjustmentLayers: Bool
    ) -> XomoJSONValue {
        let reading = ImageEditorColorSamplerReading(color: sample.color)
        return .object([
            "id": .string(sample.id.uuidString),
            "index": .number(Double(index + 1)),
            "sampleSize": .string(sampleSize.rawValue),
            "sampleSource": .string(sampleSource.rawValue),
            "ignoresAdjustmentLayers": .bool(ignoresAdjustmentLayers),
            "point": pointJSON(sample.point),
            "color": colorJSON(sample.color),
            "rgb8": .object([
                "red": .number(Double(reading.red8)),
                "green": .number(Double(reading.green8)),
                "blue": .number(Double(reading.blue8)),
                "alpha": .number(Double(reading.alpha8))
            ]),
            "hsb": .object([
                "hueDegrees": .number(Double(reading.hueDegrees)),
                "saturation": .number(Double(reading.saturation)),
                "brightness": .number(Double(reading.brightness)),
                "alpha": .number(Double(reading.alpha))
            ]),
            "cmyk": .object([
                "cyan": .number(Double(reading.cyan)),
                "magenta": .number(Double(reading.magenta)),
                "yellow": .number(Double(reading.yellow)),
                "key": .number(Double(reading.key)),
                "alpha": .number(Double(reading.alpha)),
                "conversion": .string("deviceRGB")
            ]),
            "hexRGBA": .string(reading.hexadecimalRGBA)
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

enum XomoAutomationCallError: LocalizedError {
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
        tool("xomo.document.get", "Inspect the active Xomo document, canvas, and histogram.", [
            "histogramSource": XomoAutomationSchema.string(
                description: "Histogram analysis source",
                values: ImageEditorHistogramSource.allCases.map(\.rawValue)
            ),
            "histogramChannel": XomoAutomationSchema.string(
                description: "Histogram channel to inspect",
                values: ImageEditorHistogramChannel.allCases.map(\.rawValue)
            ),
            "histogramRangeLowerLevel": XomoAutomationSchema.integer(
                description: "Optional inclusive histogram range start from 0 through 255"
            ),
            "histogramRangeUpperLevel": XomoAutomationSchema.integer(
                description: "Optional inclusive histogram range end from 0 through 255"
            )
        ]),
        tool("xomo.document.create", "Replace the active document with a new preset or custom canvas.", [
            "preset": XomoAutomationSchema.string(description: "Canvas preset", values: XomoCanvasPreset.allCases.map(\.rawValue)),
            "width": XomoAutomationSchema.number(description: "Optional custom width"),
            "height": XomoAutomationSchema.number(description: "Optional custom height"),
            "exportScale": XomoAutomationSchema.number(description: "Export scale from 1 to 3"),
            "background": XomoAutomationSchema.string(description: "Canvas background", values: XomoCanvasBackground.allCases.map(\.rawValue))
        ]),
        tool("xomo.project.export", "Serialize the complete layered project and return base64 xomoproject data."),
        tool("xomo.project.import", "Replace the active document from base64 xomoproject data (legacy qpicproject payloads remain accepted).", [
            "base64": XomoAutomationSchema.string(description: "Base64 xomoproject data")
        ], required: ["base64"]),
        tool("xomo.import.image", "Import a base64 encoded image as an editable layer.", [
            "base64": XomoAutomationSchema.string(description: "Base64 image data"),
            "name": XomoAutomationSchema.string(description: "Source filename"),
            "intoSelection": XomoAutomationSchema.boolean(description: "Mask the imported layer to the current selection")
        ], required: ["base64"]),
        tool("xomo.psd.inspect", "Inspect a local PSD compatibility report without importing or changing the active document.", [
            "path": XomoAutomationSchema.string(description: "Local PSD file path")
        ], required: ["path"]),
        tool("xomo.psd.open", "Open a local PSD asynchronously in the active Xomo editor using the same loading and fallback path as the UI.", [
            "path": XomoAutomationSchema.string(description: "Local PSD file path")
        ], required: ["path"]),
        tool("xomo.psd.save", "Save the current layered Xomo document as a PSD file and verify its compatibility report.", [
            "path": XomoAutomationSchema.string(description: "Destination PSD file path")
        ], required: ["path"]),
        tool("xomo.tool.list", "List all image editor tools."),
        tool("xomo.tool.select", "Select the active editor tool.", [
            "tool": XomoAutomationSchema.string(description: "Tool identifier", values: ImageEditorTool.allCases.map(\.rawValue))
        ], required: ["tool"]),
        tool("xomo.layer.list", "List layers with hierarchy, bounds, visibility, locks, opacity, blend mode, and preserved Figma source, including each layer's validated canonical node URL, bindings, and size constraints, with optional filters.", [
            "figmaBindings": XomoAutomationSchema.string(description: "Filter by preserved Figma variable bindings", values: ["all", "bound", "unbound"]),
            "figmaConstraints": XomoAutomationSchema.string(description: "Filter by effective Figma size constraints", values: ["all", "constrained", "overridden", "conflicted"]),
            "figmaSource": XomoAutomationSchema.string(description: "Filter by retained Figma source identity", values: ["all", "imported", "local"]),
            "figmaFileKey": XomoAutomationSchema.string(description: "Filter by exact Figma file key parsed from the retained canonical source URL"),
            "figmaResourceType": XomoAutomationSchema.string(description: "Filter by Figma resource path type parsed from the retained canonical source URL", values: XomoFigmaResourceType.allCases.map(\.rawValue)),
            "figmaImportScope": XomoAutomationSchema.string(description: "Filter by Xomo's planned import scope for the retained Figma resource", values: XomoFigmaPlannedImportScope.allCases.map(\.rawValue)),
            "figmaNodeId": XomoAutomationSchema.string(description: "Filter by exact retained Figma node ID; canonical colon and URL hyphen separators are accepted"),
            "figmaNodeType": XomoAutomationSchema.string(description: "Filter by exact retained Figma node type, case-insensitive"),
            "figmaComponentRole": XomoAutomationSchema.string(description: "Filter by retained Figma component role", values: ["all", "none"] + XomoFigmaComponentRole.allCases.map(\.rawValue))
        ]),
        tool("xomo.layer.selection_bounds", "Inspect selected object bounds, transform reference point, and live move, resize, or rotate preview context, including original bounds, movement, size, scale, and rotation deltas."),
        tool("xomo.layer.transform_reference", "Set or reset the transform reference point for the current transformable layer selection without changing document history.", [
            "action": XomoAutomationSchema.string(description: "Transform reference action", values: ["set", "reset"]),
            "x": XomoAutomationSchema.number(description: "Canvas x coordinate required by set"),
            "y": XomoAutomationSchema.number(description: "Canvas y coordinate required by set")
        ], required: ["action"]),
        tool("xomo.object.select_at", "Select the frontmost visible canvas object at a point using the editor's alpha-aware component and layer hit testing.", [
            "x": XomoAutomationSchema.number(description: "Canvas x coordinate"),
            "y": XomoAutomationSchema.number(description: "Canvas y coordinate"),
            "mode": XomoAutomationSchema.string(description: "Selection depth", values: ["auto", "component", "deep"]),
            "extend": XomoAutomationSchema.boolean(description: "Extend the current layer selection"),
            "clearOnMiss": XomoAutomationSchema.boolean(description: "Clear layer selection when the point hits no visible object")
        ], required: ["x", "y"]),
        tool("xomo.figma.bindings", "List or copy the deduplicated Figma variable bindings from the current layer selection.", [
            "action": XomoAutomationSchema.string(description: "Binding action", values: ["list", "copy"])
        ], required: ["action"]),
        tool("xomo.figma.link", "Validate and canonicalize a Figma link without network access or credential storage.", [
            "url": XomoAutomationSchema.string(description: "Figma design, file, prototype, board, or other supported resource URL")
        ], required: ["url"]),
        tool("xomo.figma.component_properties", "List, locally override, or reset preserved Figma component properties on the selected layer.", [
            "action": XomoAutomationSchema.string(description: "Component property action", values: ["list", "set", "reset"]),
            "key": XomoAutomationSchema.string(description: "Figma component property name"),
            "value": XomoAutomationSchema.string(description: "New local property value")
        ], required: ["action"]),
        tool("xomo.figma.size_constraints", "List current and imported Figma min/max size constraints, locally set, clear or reset fields, or explicitly resolve a conflicting axis by using its minimum.", [
            "action": XomoAutomationSchema.string(description: "Size constraint action", values: ["list", "set", "clear", "reset", "resetAll", "resolve", "resolveAll"]),
            "field": XomoAutomationSchema.string(description: "Figma size constraint field", values: XomoFigmaSizeConstraintField.allCases.map(\.rawValue)),
            "axis": XomoAutomationSchema.string(description: "Conflicting axis required by resolve", values: XomoFigmaSizeConstraintConflict.allCases.map(\.rawValue)),
            "value": XomoAutomationSchema.number(description: "New local constraint value in pixels")
        ], required: ["action"]),
        tool("xomo.figma.image_fill", "List or edit the retained source, transform, and filter controls of the selected Figma image fill.", [
            "action": XomoAutomationSchema.string(description: "Image fill action", values: ["list", "set"]),
            "property": XomoAutomationSchema.string(description: "Editable image fill property", values: ["scaleMode", "scalingFactor", "rotation", "offsetX", "offsetY", "m11", "m12", "m21", "m22", "filtersEnabled"]),
            "scaleMode": XomoAutomationSchema.string(description: "Figma image fill scale mode", values: ImageEditorViewModel.figmaImageFillScaleModes),
            "value": XomoAutomationSchema.number(description: "Numeric image fill value"),
            "enabled": XomoAutomationSchema.boolean(description: "Whether image fill filters are enabled")
        ], required: ["action"]),
        tool("xomo.layer.select", "Select a layer by UUID.", [
            "id": XomoAutomationSchema.string(description: "Layer UUID"),
            "extend": XomoAutomationSchema.boolean(description: "Extend the current layer selection")
        ], required: ["id"]),
        tool("xomo.layer.create", "Create a pixel, group, text, adjustment, filter, or fill layer.", [
            "kind": XomoAutomationSchema.string(description: "Layer kind", values: ["pixel", "group", "text", "adjustment", "filter", "solidColorFill", "patternFill", "gradientFill"]),
            "x": XomoAutomationSchema.number(description: "Optional canvas x position"),
            "y": XomoAutomationSchema.number(description: "Optional canvas y position"),
            "solidRed": XomoAutomationSchema.number(description: "Optional solid-color-fill red channel from 0 to 1"),
            "solidGreen": XomoAutomationSchema.number(description: "Optional solid-color-fill green channel from 0 to 1"),
            "solidBlue": XomoAutomationSchema.number(description: "Optional solid-color-fill blue channel from 0 to 1"),
            "patternKind": XomoAutomationSchema.string(description: "Optional pattern-fill kind", values: ImageEditorPatternOverlayKind.allCases.map(\.rawValue)),
            "patternRed": XomoAutomationSchema.number(description: "Optional pattern-fill red channel from 0 to 1"),
            "patternGreen": XomoAutomationSchema.number(description: "Optional pattern-fill green channel from 0 to 1"),
            "patternBlue": XomoAutomationSchema.number(description: "Optional pattern-fill blue channel from 0 to 1"),
            "patternOpacity": XomoAutomationSchema.number(description: "Optional pattern-fill opacity from 0.05 to 1"),
            "patternScale": XomoAutomationSchema.number(description: "Optional pattern-fill tile size from 6 to 64 pixels"),
            "offsetX": XomoAutomationSchema.number(description: "Optional pattern-fill horizontal phase in pixels"),
            "offsetY": XomoAutomationSchema.number(description: "Optional pattern-fill vertical phase in pixels"),
            "preset": XomoAutomationSchema.string(description: "Optional gradient-fill preset", values: ImageEditorGradientFillPreset.allCases.map(\.rawValue)),
            "style": XomoAutomationSchema.string(description: "Optional gradient-fill style", values: ImageEditorGradientFillStyle.allCases.map(\.rawValue)),
            "reverse": XomoAutomationSchema.boolean(description: "Optional gradient-fill reverse direction"),
            "dither": XomoAutomationSchema.boolean(description: "Optional deterministic gradient dithering"),
            "angle": shapeBoundedNumberSchema(
                description: "Optional gradient-fill angle in degrees",
                minimum: -180,
                maximum: 180
            ),
            "scale": shapeBoundedNumberSchema(
                description: "Optional gradient-fill span scale",
                minimum: 0.25,
                maximum: 4
            ),
            "startColor": gradientFillColorSchema,
            "endColor": gradientFillColorSchema,
            "stops": gradientFillStopsSchema
        ]),
        tool("xomo.layer.solid_color_fill_settings", "Read or replace the RGB color of selected solid-color-fill layers, skipping locked and ineligible layers and reporting the actual updated count.", [
            "action": XomoAutomationSchema.string(description: "Solid-color-fill settings action", values: ["get", "set"]),
            "red": XomoAutomationSchema.number(description: "Red channel from 0 to 1"),
            "green": XomoAutomationSchema.number(description: "Green channel from 0 to 1"),
            "blue": XomoAutomationSchema.number(description: "Blue channel from 0 to 1")
        ], required: ["action"]),
        tool("xomo.layer.adjustment_settings", "Read or replace the complete normalized settings of selected non-destructive adjustment layers while skipping locked and ineligible layers.", [
            "action": XomoAutomationSchema.string(description: "Adjustment-layer settings action", values: ["get", "set"]),
            "amount": XomoAutomationSchema.number(description: "Optional main adjustment amount; posterize uses 2 to 32 and other adjustments use -1 to 1"),
            "settings": .object([
                "type": .string("object"),
                "description": .string("Optional complete settings object returned by the get action"),
                "additionalProperties": .bool(true)
            ])
        ], required: ["action"]),
        tool("xomo.layer.filter_settings", "Read or replace the intensity and complete normalized settings of selected non-destructive filter layers while skipping locked and ineligible layers.", [
            "action": XomoAutomationSchema.string(description: "Filter-layer settings action", values: ["get", "set"]),
            "intensity": XomoAutomationSchema.number(description: "Optional filter intensity from 0 to 1"),
            "settings": .object([
                "type": .string("object"),
                "description": .string("Optional complete settings object returned by the get action"),
                "additionalProperties": .bool(true)
            ])
        ], required: ["action"]),
        tool("xomo.layer.gradient_fill_settings", "Read or replace the complete settings of selected gradient-fill layers, including optional ordered multi-color stops, while skipping locked and ineligible layers.", [
            "action": XomoAutomationSchema.string(description: "Gradient-fill settings action", values: ["get", "set"]),
            "preset": XomoAutomationSchema.string(description: "Gradient preset", values: ImageEditorGradientFillPreset.allCases.map(\.rawValue)),
            "style": XomoAutomationSchema.string(description: "Gradient style", values: ImageEditorGradientFillStyle.allCases.map(\.rawValue)),
            "reverse": XomoAutomationSchema.boolean(description: "Reverse the gradient direction"),
            "dither": XomoAutomationSchema.boolean(description: "Apply deterministic gradient dithering"),
            "angle": shapeBoundedNumberSchema(
                description: "Gradient angle in degrees",
                minimum: -180,
                maximum: 180
            ),
            "scale": shapeBoundedNumberSchema(
                description: "Gradient span scale",
                minimum: 0.25,
                maximum: 4
            ),
            "startColor": gradientFillColorSchema,
            "endColor": gradientFillColorSchema,
            "stops": gradientFillStopsSchema
        ], required: ["action"]),
        tool("xomo.layer.pattern_fill_settings", "Read or replace the complete settings of selected pattern-fill layers, skipping locked and ineligible layers and reporting the actual updated count.", [
            "action": XomoAutomationSchema.string(description: "Pattern-fill settings action", values: ["get", "set"]),
            "patternKind": XomoAutomationSchema.string(description: "Pattern kind", values: ImageEditorPatternOverlayKind.allCases.map(\.rawValue)),
            "red": XomoAutomationSchema.number(description: "Red channel from 0 to 1"),
            "green": XomoAutomationSchema.number(description: "Green channel from 0 to 1"),
            "blue": XomoAutomationSchema.number(description: "Blue channel from 0 to 1"),
            "opacity": XomoAutomationSchema.number(description: "Pattern opacity from 0.05 to 1"),
            "scale": XomoAutomationSchema.number(description: "Pattern tile size from 6 to 64 pixels"),
            "offsetX": XomoAutomationSchema.number(description: "Horizontal phase from -128 to 128 pixels"),
            "offsetY": XomoAutomationSchema.number(description: "Vertical phase from -128 to 128 pixels")
        ], required: ["action"]),
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
        tool("xomo.layer.rasterize", "Rasterize type, shape, fill content, vector masks, Smart Objects, layer styles, or all vector data on selected layers.", [
            "target": XomoAutomationSchema.string(
                description: "Rasterize target",
                values: ImageEditorRasterizeTarget.allCases.map(\.rawValue)
            )
        ], required: ["target"]),
        tool("xomo.layer.align", "Align or distribute selected layers against their bounds, canvas, or pixel selection.", [
            "action": XomoAutomationSchema.string(description: "Layout action", values: ["align", "distribute", "distributeSpacing"]),
            "mode": XomoAutomationSchema.string(description: "Alignment or distribution mode", values: ["left", "horizontalCenter", "right", "top", "verticalCenter", "bottom", "horizontal", "vertical"]),
            "target": XomoAutomationSchema.string(description: "Alignment target", values: ["selectionBounds", "canvas", "pixelSelection"])
        ], required: ["action", "mode"]),
        tool("xomo.layer.style", "Copy layer styles; paste, clear, hide, or show layers with actual affected counts; browse built-in styles, or preview, import, and manage portable persisted complete layer style presets.", [
            "action": XomoAutomationSchema.string(description: "Layer style action", values: ["copy", "paste", "clear", "hideSelected", "showSelected", "hideAll", "showAll", "presetList", "presetCatalog", "presetFavorites", "presetRecent", "presetCreate", "presetApply", "presetDuplicate", "presetFavorite", "presetDelete", "presetRename", "presetMove", "presetImportPreview", "presetImport", "presetExport"]),
            "id": XomoAutomationSchema.string(description: "Layer style preset ID for apply, duplicate, favorite, delete, rename, move, or selected export"),
            "favorite": XomoAutomationSchema.boolean(description: "Whether presetFavorite should add or remove the preset from favorites"),
            "name": XomoAutomationSchema.string(description: "Custom preset name when creating or renaming"),
            "direction": XomoAutomationSchema.string(description: "Preset ordering direction", values: ImageEditorLayerStylePresetMoveDirection.allCases.map(\.rawValue)),
            "path": XomoAutomationSchema.string(description: "Local .xomostyles path for preset import preview, import, or export")
        ], required: ["action"]),
        tool("xomo.layer.style_settings", "Set effect scale; complete stroke gradient endpoints, stroke pattern color/offset, and other stroke settings; shadow; inner-shadow; outer/inner-glow settings; color-overlay color/opacity; complete gradient-overlay stops, blend mode, and pattern-overlay settings including pattern phase offsets; bevel settings; and per-effect global-light linkage with actual updated-layer counts. Stroke/overlay gradient start, stroke/overlay pattern, and bevel colors use the current foreground color; stroke/overlay gradient end colors use the current background color. Shadow, inner-shadow, and bevel angle updates report whether global light changed; direct global-light updates report affected layer/effect counts across all linked shadows, inner shadows, and bevels.", [
            "property": XomoAutomationSchema.string(description: "Layer style property", values: ["effectScale", "strokeWidth", "strokePosition", "strokeFillType", "strokeGradientStartColor", "strokeGradientEndColor", "strokeGradientStyle", "strokeGradientAngle", "strokePatternKind", "strokePatternColor", "strokePatternScale", "strokePatternOffsetX", "strokePatternOffsetY", "strokeOpacity", "strokeColor", "shadowOpacity", "shadowColor", "shadowBlur", "shadowSpread", "shadowNoise", "shadowContour", "shadowDistance", "shadowAngle", "shadowUsesGlobalLight", "globalLightAngle", "innerShadowOpacity", "innerShadowBlur", "innerShadowChoke", "innerShadowNoise", "innerShadowContour", "innerShadowDistance", "innerShadowAngle", "innerShadowUsesGlobalLight", "outerGlowOpacity", "outerGlowColor", "outerGlowBlur", "outerGlowSpread", "outerGlowTechnique", "outerGlowNoise", "outerGlowContour", "outerGlowRange", "outerGlowJitter", "innerGlowOpacity", "innerGlowColor", "innerGlowBlur", "innerGlowChoke", "innerGlowTechnique", "innerGlowNoise", "innerGlowSource", "innerGlowContour", "innerGlowRange", "innerGlowJitter", "colorOverlayOpacity", "colorOverlayColor", "gradientOverlayOpacity", "gradientOverlayBlendMode", "gradientOverlayStartColor", "gradientOverlayEndColor", "gradientOverlayStops", "gradientOverlayScale", "gradientOverlayAngle", "gradientOverlayCenterX", "gradientOverlayCenterY", "gradientOverlayStyle", "gradientOverlayReverse", "gradientOverlayDither", "patternOverlayKind", "patternOverlayColor", "patternOverlayOpacity", "patternOverlayScale", "patternOverlayOffsetX", "patternOverlayOffsetY", "satinOpacity", "satinColor", "satinDistance", "satinSize", "satinAngle", "satinInvert", "satinContour", "bevelSize", "bevelOpacity", "bevelHighlightColor", "bevelShadowColor", "bevelSoften", "bevelAngle", "bevelUsesGlobalLight", "bevelDirection"]),
            "value": XomoAutomationSchema.number(description: "Numeric style value"),
            "position": XomoAutomationSchema.string(description: "Stroke position", values: ImageEditorStrokePosition.allCases.map(\.rawValue)),
            "fillType": XomoAutomationSchema.string(description: "Stroke fill type", values: ImageEditorStrokeFillType.allCases.map(\.rawValue)),
            "gradientStyle": XomoAutomationSchema.string(description: "Stroke gradient style", values: ImageEditorGradientFillStyle.allCases.map(\.rawValue)),
            "patternKind": XomoAutomationSchema.string(description: "Stroke pattern kind", values: ImageEditorPatternOverlayKind.allCases.map(\.rawValue)),
            "source": XomoAutomationSchema.string(description: "Inner glow source", values: ImageEditorInnerGlowSource.allCases.map(\.rawValue)),
            "gradientOverlayStyle": XomoAutomationSchema.string(description: "Gradient overlay style", values: ImageEditorGradientFillStyle.allCases.map(\.rawValue)),
            "blendMode": XomoAutomationSchema.string(description: "Gradient overlay blend mode", values: ImageEditorBlendMode.layerEffectCases.map(\.rawValue)),
            "stops": gradientFillStopsSchema,
            "patternOverlayKind": XomoAutomationSchema.string(description: "Pattern overlay kind", values: ImageEditorPatternOverlayKind.allCases.map(\.rawValue)),
            "shadowContour": XomoAutomationSchema.string(description: "Drop shadow contour", values: ImageEditorLayerEffectContour.allCases.map(\.rawValue)),
            "innerShadowContour": XomoAutomationSchema.string(description: "Inner shadow contour", values: ImageEditorLayerEffectContour.allCases.map(\.rawValue)),
            "outerGlowContour": XomoAutomationSchema.string(description: "Outer glow contour", values: ImageEditorLayerEffectContour.allCases.map(\.rawValue)),
            "outerGlowTechnique": XomoAutomationSchema.string(description: "Outer glow technique", values: ImageEditorGlowTechnique.allCases.map(\.rawValue)),
            "innerGlowTechnique": XomoAutomationSchema.string(description: "Inner glow technique", values: ImageEditorGlowTechnique.allCases.map(\.rawValue)),
            "innerGlowContour": XomoAutomationSchema.string(description: "Inner glow contour", values: ImageEditorLayerEffectContour.allCases.map(\.rawValue)),
            "satinContour": XomoAutomationSchema.string(description: "Satin contour", values: ImageEditorLayerEffectContour.allCases.map(\.rawValue)),
            "bevelDirection": XomoAutomationSchema.string(description: "Bevel direction", values: ImageEditorBevelDirection.allCases.map(\.rawValue)),
            "enabled": XomoAutomationSchema.boolean(description: "Boolean style value; color properties use the current foreground color except gradientOverlayEndColor, which uses the current background color")
        ], required: ["property"]),
        tool("xomo.layer.selection", "Select layers by state, relationship, kind, blend mode, or label.", [
            "action": XomoAutomationSchema.string(description: "Layer selection action", values: ["all", "clear", "invert", "visible", "hidden", "locked", "unlocked", "masked", "styled", "clippingMasks", "smartFiltered", "sameKind", "similar", "sameBlendMode", "sameLabel", "groupMembers", "parentGroup"])
        ], required: ["action"]),
        tool("xomo.layer.link", "Link, unlink, or select linked layers.", [
            "action": XomoAutomationSchema.string(description: "Layer link action", values: ["link", "unlink", "unlinkAll", "selectLinked"])
        ], required: ["action"]),
        tool("xomo.layer.smart_object", "Place, convert, and manage embedded smart object layers.", [
            "action": XomoAutomationSchema.string(description: "Smart object action", values: ["convert", "placeEmbedded", "replaceContents", "resetTransform", "makeUnique", "newViaCopy", "exportSourcePNG"]),
            "path": XomoAutomationSchema.string(description: "Local path used by placeEmbedded, replaceContents, and exportSourcePNG; exportSourcePNG requires a .png destination")
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
        tool("xomo.layer_comp.action", "Create, select, apply, update, rename, duplicate, delete, or cycle through layer comps.", [
            "action": XomoAutomationSchema.string(description: "Layer comp action", values: ["create", "select", "apply", "update", "rename", "delete", "duplicate", "previous", "next"]),
            "id": XomoAutomationSchema.string(description: "Layer comp UUID"),
            "name": XomoAutomationSchema.string(description: "Layer comp name")
        ], required: ["action"]),
        tool("xomo.selection.get", "Inspect the active pixel selection."),
        tool("xomo.selection.all", "Select the full canvas."),
        tool("xomo.slice.create", "Create a named rectangular Fireworks-style slice from the current pixel selection.", [
            "name": XomoAutomationSchema.string(description: "Optional slice name; defaults to Slice N")
        ]),
        tool("xomo.slice.list", "List named rectangular slices in the active document."),
        tool("xomo.slice.delete", "Delete a named slice by UUID.", idProperties, required: ["id"]),
        tool("xomo.slice.update", "Update a slice name or rectangle.", [
            "id": XomoAutomationSchema.string(description: "Slice UUID"),
            "name": XomoAutomationSchema.string(description: "Updated slice name"),
            "x": XomoAutomationSchema.number(description: "Updated canvas X coordinate"),
            "y": XomoAutomationSchema.number(description: "Updated canvas Y coordinate"),
            "width": XomoAutomationSchema.number(description: "Updated slice width"),
            "height": XomoAutomationSchema.number(description: "Updated slice height")
        ], required: ["id"]),
        tool("xomo.hotspot.create", "Create a named Fireworks-style hotspot from the current pixel selection.", [
            "name": XomoAutomationSchema.string(description: "Optional hotspot name; defaults to Hotspot N"),
            "url": XomoAutomationSchema.string(description: "Optional destination URL for the hotspot")
        ]),
        tool("xomo.hotspot.list", "List named rectangular hotspots in the active document."),
        tool("xomo.hotspot.delete", "Delete a named hotspot by UUID.", idProperties, required: ["id"]),
        tool("xomo.hotspot.update", "Update a hotspot name, destination URL, or rectangle.", [
            "id": XomoAutomationSchema.string(description: "Hotspot UUID"),
            "name": XomoAutomationSchema.string(description: "Updated hotspot name"),
            "url": XomoAutomationSchema.string(description: "Updated destination URL"),
            "x": XomoAutomationSchema.number(description: "Updated canvas X coordinate"),
            "y": XomoAutomationSchema.number(description: "Updated canvas Y coordinate"),
            "width": XomoAutomationSchema.number(description: "Updated hotspot width"),
            "height": XomoAutomationSchema.number(description: "Updated hotspot height")
        ], required: ["id"]),
        tool("xomo.hotspot.export_html", "Export the composited canvas and hotspots as a self-contained HTML image map."),
        tool("xomo.selection.rectangle", "Create a rectangular canvas selection.", rectProperties, required: ["x", "y", "width", "height"]),
        tool("xomo.selection.ellipse", "Create an elliptical canvas selection.", rectProperties, required: ["x", "y", "width", "height"]),
        tool("xomo.selection.lasso", "Create a polygonal lasso selection from canvas points.", ["points": pointsSchema], required: ["points"]),
        tool("xomo.selection.magic", "Create a magic-wand selection at a canvas point.", magicPointProperties, required: ["x", "y"]),
        tool("xomo.selection.quick", "Create a quick selection from sampled canvas points.", [
            "points": pointsSchema,
            "tolerance": XomoAutomationSchema.number(
                description: "Color-distance tolerance from 0 to 1",
                minimum: 0,
                maximum: 1
            )
        ], required: ["points"]),
        tool("xomo.selection.clear", "Deselect the current selection."),
        tool("xomo.selection.invert", "Invert the current selection."),
        tool("xomo.selection.feather", "Feather the current selection.", [
            "radius": XomoAutomationSchema.integer(
                description: "Feather radius in pixels",
                minimum: 1,
                maximum: 64
            )
        ]),
        tool("xomo.selection.smooth", "Smooth the current selection boundary.", [
            "radius": XomoAutomationSchema.integer(
                description: "Smoothing radius in pixels",
                minimum: 1,
                maximum: 16
            )
        ]),
        tool("xomo.selection.edit", "Edit selected pixels; copy merged and duplicate can also operate without a selection.", [
            "action": XomoAutomationSchema.string(description: "Selection edit action", values: ["fillForeground", "fillBackground", "stroke", "contentAwareFill", "clearPixels", "copyToLayer", "cutToLayer", "copyMergedToLayer", "duplicate"])
        ], required: ["action"]),
        tool("xomo.selection.modify", "Save, restore, transform, clean, color-match, or nudge the pixel selection.", [
            "action": XomoAutomationSchema.string(description: "Selection modification", values: ["loadTransparency", "save", "reselect", "restoreSaved", "colorRange", "similarColors", "growColor", "expand", "contract", "border", "smooth", "fillHoles", "removeSpeckles", "centerHorizontal", "centerVertical", "centerCanvas", "flipHorizontal", "flipVertical", "rotateClockwise", "rotateCounterclockwise", "rotate180", "scaleUp", "scaleDown", "fitCanvas", "nudge"]),
            "amount": XomoAutomationSchema.integer(
                description: "Selection modification amount from 1 to 64 pixels; smooth accepts at most 16",
                minimum: 1,
                maximum: 64
            ),
            "tolerance": XomoAutomationSchema.number(
                description: "Color-distance tolerance from 0 to 1",
                minimum: 0,
                maximum: 1
            ),
            "threshold": XomoAutomationSchema.integer(
                description: "Layer alpha threshold from 0 to 255 for loadTransparency",
                minimum: 0,
                maximum: 255
            ),
            "dx": XomoAutomationSchema.number(description: "Horizontal selection delta"),
            "dy": XomoAutomationSchema.number(description: "Vertical selection delta")
        ], required: ["action"]),
        tool("xomo.selection.quick_mask", "Inspect and edit the current selection through Photoshop-style Quick Mask mode.", [
            "action": XomoAutomationSchema.string(description: "Quick Mask action", values: ["get", "toggle", "setTarget", "setColor", "setOpacity", "paint"]),
            "target": XomoAutomationSchema.string(description: "Overlay target", values: ImageEditorQuickMaskOverlayTarget.allCases.map(\.rawValue)),
            "color": XomoAutomationSchema.object(
                properties: [
                    "red": XomoAutomationSchema.number(description: "Red channel from 0 to 1"),
                    "green": XomoAutomationSchema.number(description: "Green channel from 0 to 1"),
                    "blue": XomoAutomationSchema.number(description: "Blue channel from 0 to 1"),
                    "alpha": XomoAutomationSchema.number(description: "Optional alpha channel from 0 to 1")
                ],
                required: ["red", "green", "blue"]
            ),
            "opacity": XomoAutomationSchema.number(description: "Overlay opacity from 0 to 1"),
            "points": pointsSchema,
            "reveal": XomoAutomationSchema.boolean(description: "Reveal selected areas instead of masking them while painting")
        ], required: ["action"]),
        tool("xomo.clipboard.action", "Copy or cut pixel selections and native editable objects, then paste clipboard images or Xomo object archives as editable layers, including in-place paste.", [
            "action": XomoAutomationSchema.string(description: "Clipboard action", values: ["pasteAsLayer", "pasteIntoSelection", "pasteInPlace", "copySelection", "cutSelection", "cutSelectedLayers", "copyMerged", "copySelectedLayers"])
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
        tool("xomo.component.tokens", "Read, import, export, apply, clear, or refresh local component design tokens as a .xomotokens.json file.", [
            "action": XomoAutomationSchema.string(description: "Token action", values: ["get", "import", "export", "apply", "clear", "refresh"]),
            "theme": XomoAutomationSchema.string(description: "Optional theme; defaults to the active component theme", values: XomoComponentTheme.allCases.map(\.rawValue)),
            "path": XomoAutomationSchema.string(description: "Destination file path for export")
        ]),
        tool("xomo.component.insert", "Insert an editable UI component as native layers.", [
            "component": XomoAutomationSchema.string(description: "Component identifier", values: XomoComponentKind.allCases.map(\.rawValue)),
            "theme": XomoAutomationSchema.string(description: "Optional theme", values: XomoComponentTheme.allCases.map(\.rawValue)),
            "x": XomoAutomationSchema.number(description: "Optional canvas x position"),
            "y": XomoAutomationSchema.number(description: "Optional canvas y position")
        ], required: ["component"]),
        tool("xomo.component.instance", "Create a component master, link selected components, synchronize linked instances, or detach instances.", [
            "action": XomoAutomationSchema.string(description: "Component instance action", values: ["makeMaster", "link", "sync", "detach"])
        ], required: ["action"]),
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
        tool("xomo.color_sampler.list", "List up to four canvas color samplers with coordinates and RGBA colors."),
        tool("xomo.color_sampler.add", "Add a color sampler at a canvas coordinate, retaining the newest four samples.", [
            "x": XomoAutomationSchema.number(description: "Canvas x coordinate"),
            "y": XomoAutomationSchema.number(description: "Canvas y coordinate"),
            "sampleSize": XomoAutomationSchema.string(
                description: "Optional square pixel sampling area",
                values: ImageEditorColorSamplerSampleSize.allCases.map(\.rawValue)
            ),
            "sampleSource": XomoAutomationSchema.string(
                description: "Optional rendered source to sample",
                values: ImageEditorColorSamplerSource.allCases.map(\.rawValue)
            ),
            "ignoresAdjustmentLayers": XomoAutomationSchema.boolean(
                description: "Ignore adjustment layers while sampling"
            )
        ], required: ["x", "y"]),
        tool("xomo.color_sampler.move", "Move one color sampler by stable id without writing document history.", [
            "id": XomoAutomationSchema.string(description: "Stable color sampler UUID"),
            "x": XomoAutomationSchema.number(description: "New canvas x coordinate"),
            "y": XomoAutomationSchema.number(description: "New canvas y coordinate")
        ], required: ["id", "x", "y"]),
        tool("xomo.color_sampler.remove", "Remove one color sampler by stable id without clearing the other points.", [
            "id": XomoAutomationSchema.string(description: "Stable color sampler UUID")
        ], required: ["id"]),
        tool("xomo.color_sampler.clear", "Clear all canvas color samplers and report the actual cleared count."),
        tool("xomo.brush.preset", "Search, list, favorite, apply, create, update, duplicate, reorder, inspect, import, replace, reset, export, rename, or delete persisted brush presets.", [
            "action": XomoAutomationSchema.string(description: "Brush preset action", values: ["list", "favorites", "recent", "create", "apply", "favorite", "update", "duplicate", "moveToIndex", "inspectLibrary", "import", "replace", "resetLibrary", "export", "rename", "delete"]),
            "query": XomoAutomationSchema.string(description: "Optional name terms and numeric filters for list, favorites, or recent, such as size:>=24px hardness:80%"),
            "scope": XomoAutomationSchema.string(description: "Optional preset source scope for list, favorites, or recent", values: ImageEditorBrushPresetScope.allCases.map(\.rawValue)),
            "sortOrder": XomoAutomationSchema.string(description: "Optional result order for list, favorites, or recent", values: ImageEditorBrushPresetSortOrder.allCases.map(\.rawValue)),
            "id": XomoAutomationSchema.string(description: "Preset identifier for apply, favorite, update, duplicate, moveToIndex, single-preset export, rename, or delete"),
            "favorite": XomoAutomationSchema.boolean(description: "Whether favorite should add or remove the preset from favorites"),
            "index": XomoAutomationSchema.integer(description: "Zero-based destination index within custom presets for moveToIndex", minimum: 0),
            "path": XomoAutomationSchema.string(description: "Source path for inspect/import/replace or destination path for export of a .xomobrushes file"),
            "inspectionMode": XomoAutomationSchema.string(description: "Capacity policy for inspectLibrary; append preserves current custom presets, while replace starts from an empty custom library", values: ImageEditorBrushPresetLibraryInspectionMode.allCases.map(\.rawValue)),
            "presetIndexes": .object([
                "type": .string("array"),
                "description": .string("Optional zero-based source library indexes to preview, import, or replace in source order; inspectLibrary omits it to preview the default capacity-limited selection"),
                "items": XomoAutomationSchema.integer(
                    description: "Zero-based index from inspectLibrary titles",
                    minimum: 0
                ),
                "minItems": .number(1),
                "maxItems": .number(Double(ImageEditorBrushPresetPreferences.maximumPresetCount)),
                "uniqueItems": .bool(true)
            ]),
            "name": XomoAutomationSchema.string(description: "New custom preset name for rename")
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
            "pressureOpacity": XomoAutomationSchema.boolean(description: "Use point pressure to control the per-position opacity ceiling"),
            "pressureFlow": XomoAutomationSchema.boolean(description: "Use point pressure to control per-stamp flow"),
            "pressureSensitivity": XomoAutomationSchema.number(description: "Pressure curve sensitivity from 0 to 100"),
            "minimumDiameter": XomoAutomationSchema.number(description: "Minimum pressure-controlled brush diameter from 0 to 100 percent"),
            "minimumOpacity": XomoAutomationSchema.number(description: "Minimum pressure-controlled opacity from 0 to 100 percent"),
            "minimumFlow": XomoAutomationSchema.number(description: "Minimum pressure-controlled per-stamp flow from 0 to 100 percent"),
            "tiltShape": XomoAutomationSchema.boolean(description: "Use point tilt to flatten and orient the brush tip"),
            "roundness": XomoAutomationSchema.number(description: "Static brush-tip roundness from 10 to 100 percent"),
            "angle": XomoAutomationSchema.number(description: "Static brush-tip angle from -180 to 180 degrees; live tilt takes priority"),
            "smoothing": XomoAutomationSchema.number(description: "Endpoint-preserving pointer-path smoothing from 0 to 100")
        ], required: ["points"]),
        tool("xomo.paint.gradient", "Paint a gradient between exactly two canvas points.", ["points": pointsSchema], required: ["points"]),
        tool("xomo.paint.special", "Use clone, tone, sponge, blur, sharpen, smudge, healing, red-eye, or paint-bucket tools.", [
            "action": XomoAutomationSchema.string(description: "Paint action", values: ["setCloneSource", "clearCloneSource", "resetCloneSourceTransform", "cloneStamp", "setHealingSource", "healing", "patch", "patchPattern", "dodge", "burn", "sponge", "blur", "sharpen", "smudge", "redEye", "paintBucket"]),
            "points": pointsSchema,
            "x": XomoAutomationSchema.number(description: "Canvas x coordinate for point actions"),
            "y": XomoAutomationSchema.number(description: "Canvas y coordinate for point actions"),
            "size": XomoAutomationSchema.number(description: "Brush diameter"),
            "opacity": XomoAutomationSchema.number(description: "Brush opacity"),
            "flow": XomoAutomationSchema.number(description: "Sponge flow from 0 to 1; preferred over legacy opacity"),
            "strength": XomoAutomationSchema.number(description: "Blur, sharpen, or smudge strength from 0 to 1; preferred over legacy opacity"),
            "exposure": XomoAutomationSchema.number(description: "Dodge or burn exposure from 0 to 1; preferred over legacy opacity"),
            "toneRange": XomoAutomationSchema.string(description: "Dodge or burn tonal range", values: ["shadows", "midtones", "highlights"]),
            "protectTones": XomoAutomationSchema.boolean(description: "Preserve dodge or burn chroma and reduce highlight or shadow clipping"),
            "airbrush": XomoAutomationSchema.boolean(description: "Enable gradual dodge or burn airbrush buildup"),
            "airbrushPulses": XomoAutomationSchema.integer(description: "Deterministic dodge or burn dwell pulses from 0 to 80; implies airbrush when airbrush is omitted"),
            "hardness": XomoAutomationSchema.number(description: "Brush edge hardness from 0 to 1"),
            "tolerance": XomoAutomationSchema.number(description: "Paint-bucket color-distance tolerance from 0 to 1"),
            "contiguous": XomoAutomationSchema.boolean(description: "Restrict paint-bucket fill to the connected region containing the seed"),
            "feather": XomoAutomationSchema.number(description: "Patch selection feather radius"),
            "mode": XomoAutomationSchema.string(description: "Patch mode", values: ["source", "destination"]),
            "transparent": XomoAutomationSchema.boolean(description: "Transfer sampled texture while preserving patch target color and alpha"),
            "diffusion": XomoAutomationSchema.integer(description: "Patch texture diffusion from 1 for sharp detail through 7 for smooth regions", minimum: 1, maximum: 7),
            "patternKind": XomoAutomationSchema.string(description: "Built-in pattern used by patchPattern", values: ["checkerboard", "diagonalStripes", "dots"]),
            "healingMode": XomoAutomationSchema.string(description: "Healing mode", values: ["source", "spot"]),
            "spongeMode": XomoAutomationSchema.string(description: "Sponge mode", values: ["saturate", "desaturate"]),
            "spongeVibrance": XomoAutomationSchema.boolean(description: "Reduce clipping near fully saturated or desaturated colors"),
            "fingerPainting": XomoAutomationSchema.boolean(description: "Start each Smudge stroke with the current foreground color"),
            "sampleAllLayers": XomoAutomationSchema.boolean(description: "Smudge or patch from the composite of all visible layers into the active layer"),
            "pressureSize": XomoAutomationSchema.boolean(description: "Use point pressure to control retouch brush diameter"),
            "pressureSensitivity": XomoAutomationSchema.number(description: "Retouch brush pressure curve sensitivity from 0 to 100"),
            "aligned": XomoAutomationSchema.boolean(description: "Keep the clone or healing source offset aligned across strokes"),
            "sourceSlot": XomoAutomationSchema.integer(description: "One-based clone source slot from 1 through 5", minimum: 1, maximum: 5),
            "scalePercent": XomoAutomationSchema.number(description: "Uniform scale for the active clone source from 25 through 400 percent", minimum: 25, maximum: 400),
            "scaleXPercent": XomoAutomationSchema.number(description: "Horizontal scale for the active clone source from 25 through 400 percent", minimum: 25, maximum: 400),
            "scaleYPercent": XomoAutomationSchema.number(description: "Vertical scale for the active clone source from 25 through 400 percent", minimum: 25, maximum: 400),
            "scaleLinked": XomoAutomationSchema.boolean(description: "Link clone source width and height changes proportionally"),
            "rotationDegrees": XomoAutomationSchema.number(description: "Clockwise clone source rotation from -180 through 180 degrees", minimum: -180, maximum: 180),
            "showOverlay": XomoAutomationSchema.boolean(description: "Show transformed clone source pixels under the pointer before painting"),
            "clipOverlayToBrush": XomoAutomationSchema.boolean(description: "Clip the clone source overlay to the pressure-adjusted brush footprint"),
            "autoHideOverlay": XomoAutomationSchema.boolean(description: "Hide the clone source overlay while a paint stroke is active"),
            "invertOverlay": XomoAutomationSchema.boolean(description: "Invert clone source overlay colors without changing sampled pixels"),
            "overlayBlendMode": XomoAutomationSchema.string(description: "Blend the clone source overlay with the canvas", values: ["normal", "darken", "lighten", "difference"]),
            "overlayOpacityPercent": XomoAutomationSchema.number(description: "Clone source overlay opacity from 0 through 100 percent", minimum: 0, maximum: 100),
            "flipHorizontal": XomoAutomationSchema.boolean(description: "Mirror the active clone source horizontally around its sampling origin"),
            "flipVertical": XomoAutomationSchema.boolean(description: "Mirror the active clone source vertically around its sampling origin"),
            "sampleSource": XomoAutomationSchema.string(description: "Clone, healing, or patch sampling layer range", values: ["currentLayer", "currentAndBelow", "allVisible"]),
            "ignoresAdjustmentLayers": XomoAutomationSchema.boolean(description: "Exclude adjustment layers from clone, healing, or patch composite sampling")
        ], required: ["action"]),
        tool("xomo.shape.create", "Create an editable rectangle or ellipse and return its final layer ID, geometry, and normalized style.", [
            "kind": XomoAutomationSchema.string(description: "Shape kind", values: ["rectangle", "ellipse"]),
            "x": XomoAutomationSchema.number(description: "Left coordinate"),
            "y": XomoAutomationSchema.number(description: "Top coordinate"),
            "width": XomoAutomationSchema.number(description: "Width"),
            "height": XomoAutomationSchema.number(description: "Height"),
            "fillKind": XomoAutomationSchema.string(
                description: "Shape fill type",
                values: ["solid", "linearGradient", "radialGradient", "angleGradient", "reflectedGradient", "diamondGradient"]
            ),
            "fillColor": shapeColorSchema,
            "fillGradient": shapeGradientSchema,
            "fillOpacity": shapeUnitIntervalSchema(description: "Independent fill opacity"),
            "strokeColor": shapeColorSchema,
            "strokeOpacity": shapeUnitIntervalSchema(description: "Independent stroke opacity"),
            "strokeWidth": shapeStrokeWidthSchema,
            "strokePosition": XomoAutomationSchema.string(
                description: "Stroke alignment relative to the shape boundary",
                values: ImageEditorStrokePosition.allCases.map(\.rawValue)
            ),
            "strokeCap": XomoAutomationSchema.string(
                description: "Stroke endpoint cap",
                values: ImageEditorStrokeCap.allCases.map(\.rawValue)
            ),
            "strokeJoin": XomoAutomationSchema.string(
                description: "Stroke corner join",
                values: ImageEditorStrokeJoin.allCases.map(\.rawValue)
            ),
            "strokeMiterLimit": XomoAutomationSchema.number(description: "Miter join limit from 1 to 1000"),
            "strokeDashPattern": .object([
                "type": .string("array"),
                "description": .string("Empty for a solid stroke, or 2 to 16 alternating dash and gap lengths from greater than 0 through 2048 pixels"),
                "items": XomoAutomationSchema.number(description: "Dash or gap length in pixels"),
                "maxItems": .number(16)
            ]),
            "strokeDashOffset": XomoAutomationSchema.number(description: "Dash phase offset from -2048 through 2048 pixels"),
            "cornerRadius": shapeNonnegativeNumberSchema(description: "Rectangle-only uniform corner radius in pixels"),
            "cornerRadii": rectangleCornerRadiiSchema,
            "cornerSmoothing": shapeUnitIntervalSchema(description: "Rectangle-only editable superellipse smoothing")
        ], required: ["kind", "x", "y", "width", "height"]),
        tool("xomo.shape.get", "Inspect the selected editable shape layer, including open-path endpoint decorations."),
        tool("xomo.shape.update", "Update only the specified fill, stroke, open-path endpoint decoration, and rectangle corner properties of selected editable shapes.", [
            "opacity": shapeUnitIntervalSchema(description: "Legacy shared fill and stroke opacity"),
            "fillKind": XomoAutomationSchema.string(
                description: "Shape fill type",
                values: ["solid", "linearGradient", "radialGradient", "angleGradient", "reflectedGradient", "diamondGradient"]
            ),
            "fillColor": shapeColorSchema,
            "fillGradient": shapeGradientSchema,
            "fillOpacity": shapeUnitIntervalSchema(description: "Independent fill opacity"),
            "strokeColor": shapeColorSchema,
            "strokeOpacity": shapeUnitIntervalSchema(description: "Independent stroke opacity"),
            "strokeWidth": shapeStrokeWidthSchema,
            "strokePosition": XomoAutomationSchema.string(
                description: "Stroke alignment relative to the shape boundary",
                values: ImageEditorStrokePosition.allCases.map(\.rawValue)
            ),
            "strokeCap": XomoAutomationSchema.string(
                description: "Stroke endpoint cap",
                values: ImageEditorStrokeCap.allCases.map(\.rawValue)
            ),
            "strokeStartDecoration": XomoAutomationSchema.string(
                description: "Open-path start marker",
                values: ImageEditorStrokeDecoration.allCases.map(\.rawValue)
            ),
            "strokeEndDecoration": XomoAutomationSchema.string(
                description: "Open-path end marker",
                values: ImageEditorStrokeDecoration.allCases.map(\.rawValue)
            ),
            "strokeJoin": XomoAutomationSchema.string(
                description: "Stroke corner join",
                values: ImageEditorStrokeJoin.allCases.map(\.rawValue)
            ),
            "strokeMiterLimit": XomoAutomationSchema.number(description: "Miter join limit from 1 to 1000"),
            "strokeDashPattern": .object([
                "type": .string("array"),
                "description": .string("Empty for a solid stroke, or 2 to 16 alternating dash and gap lengths from greater than 0 through 2048 pixels"),
                "items": XomoAutomationSchema.number(description: "Dash or gap length in pixels"),
                "maxItems": .number(16)
            ]),
            "strokeDashOffset": XomoAutomationSchema.number(description: "Dash phase offset from -2048 through 2048 pixels"),
            "cornerRadius": shapeNonnegativeNumberSchema(description: "Uniform rectangle corner radius in pixels"),
            "cornerRadii": rectangleCornerRadiiSchema,
            "cornerSmoothing": shapeUnitIntervalSchema(description: "Editable superellipse smoothing")
        ]),
        tool("xomo.text.create", "Create an editable text layer.", [
            "text": XomoAutomationSchema.string(description: "Text content"),
            "fontSize": XomoAutomationSchema.number(description: "Font size in points"),
            "textCase": XomoAutomationSchema.string(description: "Editable letter-case style", values: ImageEditorTextCase.allCases.map(\.rawValue)),
            "paragraphSpacing": XomoAutomationSchema.number(description: "Paragraph spacing from 0 to 400 pixels"),
            "boxWidth": XomoAutomationSchema.number(description: "Optional paragraph text box width"),
            "boxHeight": XomoAutomationSchema.number(description: "Optional fixed paragraph text box height"),
            "autoHeight": XomoAutomationSchema.boolean(description: "Use content-driven height for a paragraph text box; do not combine true with boxHeight"),
            "truncateOverflow": XomoAutomationSchema.boolean(description: "Show an ellipsis on the last visible line of a fixed-height paragraph text box"),
            "verticalAlignment": XomoAutomationSchema.string(description: "Vertical alignment inside a fixed-height paragraph text box", values: ImageEditorTextVerticalAlignment.allCases.map(\.rawValue)),
            "x": XomoAutomationSchema.number(description: "Optional canvas x position"),
            "y": XomoAutomationSchema.number(description: "Optional canvas y position")
        ], required: ["text"]),
        tool("xomo.text.get", "Inspect the selected editable text layer."),
        tool("xomo.text.update", "Update selected text content and typography.", [
            "text": XomoAutomationSchema.string(description: "Text content"),
            "fontSize": XomoAutomationSchema.number(description: "Font size"),
            "textCase": XomoAutomationSchema.string(description: "Editable letter-case style", values: ImageEditorTextCase.allCases.map(\.rawValue)),
            "bold": XomoAutomationSchema.boolean(description: "Bold style"),
            "italic": XomoAutomationSchema.boolean(description: "Italic style"),
            "underline": XomoAutomationSchema.boolean(description: "Underline style"),
            "strikethrough": XomoAutomationSchema.boolean(description: "Strikethrough style"),
            "characterSpacing": XomoAutomationSchema.number(description: "Character spacing"),
            "lineSpacing": XomoAutomationSchema.number(description: "Line spacing"),
            "paragraphSpacing": XomoAutomationSchema.number(description: "Paragraph spacing from 0 to 400 pixels"),
            "boxWidth": XomoAutomationSchema.number(description: "Text box width, zero for auto"),
            "boxHeight": XomoAutomationSchema.number(description: "Fixed text box height, zero for auto"),
            "autoHeight": XomoAutomationSchema.boolean(description: "Enable content-driven paragraph height; false fixes the current required height unless boxHeight is supplied"),
            "truncateOverflow": XomoAutomationSchema.boolean(description: "Show an ellipsis on overflow; requires a fixed-height paragraph text box"),
            "verticalAlignment": XomoAutomationSchema.string(description: "Vertical alignment inside a fixed-height paragraph text box", values: ImageEditorTextVerticalAlignment.allCases.map(\.rawValue)),
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
            "action": XomoAutomationSchema.string(description: "Mask action", values: ["addRevealAll", "addFromSelection", "addHideAll", "addHideSelection", "delete", "apply", "invert", "revealSelection", "hideSelection", "intersectSelection", "loadSelection", "copyToSelected", "toggleEnabled", "toggleLinked", "addVectorFromSelection", "copyVectorToSelected", "applyVector", "rasterizeVector", "loadVectorSelection", "toggleVectorEnabled", "deleteVector"])
        ], required: ["action"]),
        tool("xomo.path.get", "Inspect anchors, control handles, subpaths, closure, and active path selection."),
        tool("xomo.path.action", "Create and edit vector paths, anchors, subpaths, masks, fills, and strokes.", [
            "action": XomoAutomationSchema.string(description: "Path action", values: ["create", "select", "nextAnchor", "previousAnchor", "nextSubpath", "previousSubpath", "setAnchorX", "setAnchorY", "nudgeAnchor", "smoothAnchor", "symmetrizeHandles", "clearHandles", "moveSubpath", "duplicateSubpath", "deleteAnchor", "deleteSubpath", "insertAnchorAfter", "toggleClosed", "reverse", "strokeToPixelLayer", "fillToPixelLayer", "fromSelection", "loadSelection", "applyVectorMask", "applyLayerMask", "editVectorMask"]),
            "points": pointsSchema,
            "closed": XomoAutomationSchema.boolean(description: "Close a newly created path"),
            "subpath": XomoAutomationSchema.number(description: "Zero-based subpath index"),
            "anchor": XomoAutomationSchema.number(description: "Zero-based anchor index"),
            "role": XomoAutomationSchema.string(description: "Selected control role", values: ["anchor", "inHandle", "outHandle"]),
            "value": XomoAutomationSchema.number(description: "Anchor coordinate value"),
            "dx": XomoAutomationSchema.number(description: "Horizontal path delta"),
            "dy": XomoAutomationSchema.number(description: "Vertical path delta")
        ], required: ["action"]),
        tool("xomo.path.saved", "List, save, select, rename, duplicate, reorder, update, load, render, show, make a selection from, or delete independent named paths.", [
            "action": XomoAutomationSchema.string(description: "Saved path action", values: ["list", "save", "select", "rename", "duplicate", "moveUp", "moveDown", "moveToTop", "moveToBottom", "moveToIndex", "update", "load", "selection", "fill", "stroke", "visibility", "delete"]),
            "id": XomoAutomationSchema.string(description: "Saved path UUID for select, rename, duplicate, reorder, update, load, selection, fill, stroke, visibility, or delete"),
            "index": XomoAutomationSchema.integer(description: "Zero-based destination index for moveToIndex"),
            "name": XomoAutomationSchema.string(description: "Optional name when saving or required name when renaming"),
            "visible": XomoAutomationSchema.boolean(description: "Persistent canvas overlay state for visibility")
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
        tool("xomo.view.pan", "Nudge, center, or reset the canvas viewport without changing document History.", [
            "action": XomoAutomationSchema.string(description: "Viewport action", values: ["nudge", "center", "reset"]),
            "dx": XomoAutomationSchema.number(description: "Horizontal viewport delta for nudge"),
            "dy": XomoAutomationSchema.number(description: "Vertical viewport delta for nudge"),
            "x": XomoAutomationSchema.number(description: "Canvas x coordinate for center"),
            "y": XomoAutomationSchema.number(description: "Canvas y coordinate for center")
        ]),
        tool("xomo.smart_filter.list", "List smart filters on the selected layer."),
        tool("xomo.smart_filter.add", "Add a non-destructive smart filter to selected editable layers and return the added layer count.", [
            "filter": XomoAutomationSchema.string(description: "Filter identifier", values: ImageEditorFilter.allCases.map(\.rawValue)),
            "intensity": XomoAutomationSchema.number(description: "Filter intensity from 0 to 1"),
            "opacity": XomoAutomationSchema.number(description: "Result opacity from 0 to 1"),
            "blendMode": XomoAutomationSchema.string(description: "Result blend mode", values: ImageEditorBlendMode.smartFilterCases.map(\.rawValue))
        ], required: ["filter"]),
        tool("xomo.smart_filter.toggle", "Enable or disable a smart filter by UUID and return the toggled layer count.", idProperties, required: ["id"]),
        tool("xomo.smart_filter.clear", "Remove all smart filters from selected layers and return the cleared layer count."),
        tool("xomo.smart_filter.manage", "Load, update, duplicate, reorder, or remove a smart filter; mutations return their affected layer count.", [
            "id": XomoAutomationSchema.string(description: "Smart filter UUID"),
            "action": XomoAutomationSchema.string(description: "Management action", values: ["load", "update", "setOpacity", "setBlendMode", "duplicate", "remove", "moveUp", "moveDown"]),
            "intensity": XomoAutomationSchema.number(description: "Updated filter intensity"),
            "opacity": XomoAutomationSchema.number(description: "Result opacity from 0 to 1"),
            "blendMode": XomoAutomationSchema.string(description: "Result blend mode", values: ImageEditorBlendMode.smartFilterCases.map(\.rawValue))
        ], required: ["id", "action"]),
        tool("xomo.filter.list", "List raster filters."),
        tool("xomo.filter.apply", "Apply a raster filter to selected layers.", [
            "filter": XomoAutomationSchema.string(description: "Filter identifier", values: ImageEditorFilter.allCases.map(\.rawValue)),
            "intensity": XomoAutomationSchema.number(description: "Filter intensity from 0 to 1")
        ], required: ["filter"]),
        tool("xomo.filter.configure", "Configure detailed filter settings and apply, add, update, or create a smart filter; addSmartFilter returns the added layer count.", [
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
            "sliceID": XomoAutomationSchema.string(description: "Named slice UUID when scope is slice"),
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
        "pressure": XomoAutomationSchema.number(description: "Optional normalized pen pressure from 0 to 1"),
        "tiltX": XomoAutomationSchema.number(description: "Optional horizontal stylus tilt from -1 to 1; requires tiltY"),
        "tiltY": XomoAutomationSchema.number(description: "Optional vertical stylus tilt from -1 to 1; requires tiltX")
    ]
    static let magicPointProperties = pointProperties.merging([
        "tolerance": XomoAutomationSchema.number(
            description: "Color-distance tolerance from 0 to 1",
            minimum: 0,
            maximum: 1
        ),
        "contiguous": XomoAutomationSchema.boolean(description: "Restrict selection to the connected region containing the seed")
    ]) { current, _ in current }
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
    static let rectangleCornerRadiiSchema = XomoAutomationSchema.object(
        properties: [
            "topLeft": shapeNonnegativeNumberSchema(description: "Top-left radius in pixels"),
            "topRight": shapeNonnegativeNumberSchema(description: "Top-right radius in pixels"),
            "bottomRight": shapeNonnegativeNumberSchema(description: "Bottom-right radius in pixels"),
            "bottomLeft": shapeNonnegativeNumberSchema(description: "Bottom-left radius in pixels")
        ],
        required: ["topLeft", "topRight", "bottomRight", "bottomLeft"]
    )

    static let shapeStrokeWidthSchema: XomoJSONValue = .object([
        "type": .string("number"),
        "description": .string("Stroke width from 0.1 through 96 pixels"),
        "minimum": .number(Double(ImageEditorShapeContent.minimumStrokeWidth)),
        "maximum": .number(Double(ImageEditorShapeContent.maximumStrokeWidth))
    ])

    static func shapeUnitIntervalSchema(description: String) -> XomoJSONValue {
        .object([
            "type": .string("number"),
            "description": .string("\(description) from 0 through 1"),
            "minimum": .number(0),
            "maximum": .number(1)
        ])
    }

    static func shapeNonnegativeNumberSchema(description: String) -> XomoJSONValue {
        .object([
            "type": .string("number"),
            "description": .string(description),
            "minimum": .number(0)
        ])
    }

    static func shapeBoundedNumberSchema(
        description: String,
        minimum: Double,
        maximum: Double
    ) -> XomoJSONValue {
        .object([
            "type": .string("number"),
            "description": .string("\(description) from \(minimum) through \(maximum)"),
            "minimum": .number(minimum),
            "maximum": .number(maximum)
        ])
    }

    static let shapeColorSchema = XomoAutomationSchema.object(
        properties: [
            "red": shapeUnitIntervalSchema(description: "Red component"),
            "green": shapeUnitIntervalSchema(description: "Green component"),
            "blue": shapeUnitIntervalSchema(description: "Blue component"),
            "alpha": shapeUnitIntervalSchema(description: "Optional alpha component")
        ],
        required: ["red", "green", "blue"]
    )
    static let shapeOpaqueColorSchema = XomoAutomationSchema.object(
        properties: [
            "red": shapeUnitIntervalSchema(description: "Red component"),
            "green": shapeUnitIntervalSchema(description: "Green component"),
            "blue": shapeUnitIntervalSchema(description: "Blue component"),
            "alpha": shapeBoundedNumberSchema(
                description: "Optional alpha component fixed at 1; use fillOpacity for transparency",
                minimum: 1,
                maximum: 1
            )
        ],
        required: ["red", "green", "blue"]
    )
    static let gradientFillColorSchema = XomoAutomationSchema.object(
        properties: [
            "red": shapeUnitIntervalSchema(description: "Red component"),
            "green": shapeUnitIntervalSchema(description: "Green component"),
            "blue": shapeUnitIntervalSchema(description: "Blue component")
        ],
        required: ["red", "green", "blue"]
    )
    static let gradientFillStopColorSchema = XomoAutomationSchema.object(
        properties: [
            "red": shapeUnitIntervalSchema(description: "Red component"),
            "green": shapeUnitIntervalSchema(description: "Green component"),
            "blue": shapeUnitIntervalSchema(description: "Blue component"),
            "alpha": shapeUnitIntervalSchema(
                description: "Optional per-stop alpha; defaults to 1"
            )
        ],
        required: ["red", "green", "blue"]
    )
    static let gradientFillStopsSchema: XomoJSONValue = .object([
        "type": .string("array"),
        "description": .string("Optional ordered 2 to 16 color stops spanning positions 0 through 1"),
        "items": XomoAutomationSchema.object(
            properties: [
                "position": shapeUnitIntervalSchema(description: "Normalized position"),
                "midpoint": shapeUnitIntervalSchema(
                    description: "Optional interpolation midpoint after this stop; defaults to 0.5"
                ),
                "color": gradientFillStopColorSchema
            ],
            required: ["position", "color"]
        ),
        "minItems": .number(2),
        "maxItems": .number(16)
    ])
    static let shapeGradientSchema = XomoAutomationSchema.object(
        properties: [
            "startColor": shapeOpaqueColorSchema,
            "endColor": shapeOpaqueColorSchema,
            "stops": .object([
                "type": .string("array"),
                "description": .string(
                    "Ordered 2 to 16 color stops spanning positions 0 through 1; "
                        + "do not combine with startColor or endColor"
                ),
                "items": XomoAutomationSchema.object(
                    properties: [
                        "position": shapeUnitIntervalSchema(description: "Normalized position"),
                        "midpoint": shapeUnitIntervalSchema(
                            description: "Optional interpolation midpoint after this stop; defaults to 0.5"
                        ),
                        "color": shapeColorSchema
                    ],
                    required: ["position", "color"]
                ),
                "minItems": .number(2),
                "maxItems": .number(16)
            ]),
            "angle": shapeBoundedNumberSchema(
                description: "Linear gradient angle in degrees",
                minimum: -180,
                maximum: 180
            ),
            "scale": shapeBoundedNumberSchema(
                description: "Linear gradient span scale",
                minimum: 0.25,
                maximum: 4
            ),
            "dither": XomoAutomationSchema.boolean(
                description: "Apply deterministic gradient dithering"
            ),
            "centerX": shapeBoundedNumberSchema(
                description: "Normalized horizontal gradient center",
                minimum: -4,
                maximum: 5
            ),
            "centerY": shapeBoundedNumberSchema(
                description: "Normalized vertical gradient center",
                minimum: -4,
                maximum: 5
            )
        ],
        required: []
    )
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
        "gaussianBlurRadius": XomoAutomationSchema.number(description: "Gaussian Blur radius from 0 to 1000 pixels; the UI uses 0.1 to 1000"),
        "sharpenAmountPercent": XomoAutomationSchema.number(description: "Sharpen amount from 0 to 200 percent"),
        "highPassRadius": XomoAutomationSchema.number(description: "High Pass radius from 1 to 1000 pixels"),
        "highPassGainPercent": XomoAutomationSchema.number(description: "High Pass detail gain from 0 to 400 percent; new UI filters use 100 percent"),
        "morphologyRadius": XomoAutomationSchema.number(description: "Minimum or Maximum radius in pixels"),
        "pixelateCellSize": XomoAutomationSchema.number(description: "Pixelate or Mosaic cell size in pixels"),
        "addNoiseAmountPercent": XomoAutomationSchema.number(description: "Add Noise amount from 0.1 to 400 percent"),
        "addNoiseMonochromatic": XomoAutomationSchema.boolean(description: "Use one shared Add Noise value for RGB channels"),
        "addNoiseDistribution": XomoAutomationSchema.string(
            description: "Add Noise distribution",
            values: ImageEditorAddNoiseDistribution.allCases.map(\.rawValue)
        ),
        "motionBlurAngleDegrees": XomoAutomationSchema.number(description: "Motion Blur angle in degrees"),
        "motionBlurDistance": XomoAutomationSchema.number(description: "Motion Blur distance in pixels"),
        "embossAngleDegrees": XomoAutomationSchema.number(description: "Emboss light angle in degrees"),
        "embossHeight": XomoAutomationSchema.number(description: "Emboss relief height in pixels"),
        "vignetteAmountPercent": XomoAutomationSchema.number(description: "Vignette amount from -100 to 100 percent"),
        "vignetteMidpoint": XomoAutomationSchema.number(description: "Vignette midpoint from 0 to 0.95"),
        "oilPaintRadius": XomoAutomationSchema.number(description: "Oil Paint brush radius in pixels"),
        "oilPaintTonalLevels": XomoAutomationSchema.number(description: "Oil Paint tonal aggregation levels"),
        "oilPaintStylization": XomoAutomationSchema.number(description: "Oil Paint stylization from 0 to 10"),
        "oilPaintCleanliness": XomoAutomationSchema.number(description: "Oil Paint cleanliness from 0 to 10"),
        "oilPaintBristleDetail": XomoAutomationSchema.number(description: "Oil Paint bristle detail from 0 to 10"),
        "oilPaintShine": XomoAutomationSchema.number(description: "Oil Paint directional shine from 0 to 10"),
        "oilPaintLightingAngleDegrees": XomoAutomationSchema.number(description: "Oil Paint lighting angle in degrees"),
        "oilPaintLightingEnabled": XomoAutomationSchema.boolean(description: "Whether Oil Paint lighting is enabled"),
        "unsharpAmountPercent": XomoAutomationSchema.number(description: "Unsharp Mask amount from 1 to 500 percent"),
        "unsharpRadiusPixels": XomoAutomationSchema.number(description: "Precise Unsharp Mask radius from 0.1 to 250 pixels"),
        "unsharpThresholdLevels": XomoAutomationSchema.number(description: "Precise Unsharp Mask threshold from 0 to 255 levels"),
        "unsharpRadius": XomoAutomationSchema.number(description: "Unsharp radius"),
        "unsharpThreshold": XomoAutomationSchema.number(description: "Unsharp threshold"),
        "liquifyPushXPixels": XomoAutomationSchema.number(description: "Horizontal Liquify Push displacement from -9999 to 9999 pixels"),
        "liquifyPushYPixels": XomoAutomationSchema.number(description: "Vertical Liquify Push displacement from -9999 to 9999 pixels"),
        "liquifyPushX": XomoAutomationSchema.number(description: "Liquify horizontal push"),
        "liquifyPushY": XomoAutomationSchema.number(description: "Liquify vertical push"),
        "liquifyTwirlAngleDegrees": XomoAutomationSchema.number(description: "Twirl angle from -999 to 999 degrees"),
        "twirlAngle": XomoAutomationSchema.number(description: "Twirl angle"),
        "liquifyBulgeAmountPercent": XomoAutomationSchema.number(description: "Pucker/Bloat amount from -100 to 100 percent"),
        "bulgeAmount": XomoAutomationSchema.number(description: "Bulge amount"),
        "offsetXPixels": XomoAutomationSchema.number(description: "Horizontal Offset from -9999 to 9999 pixels"),
        "offsetYPixels": XomoAutomationSchema.number(description: "Vertical Offset from -9999 to 9999 pixels"),
        "offsetX": XomoAutomationSchema.number(description: "Horizontal offset"),
        "offsetY": XomoAutomationSchema.number(description: "Vertical offset"),
        "offsetUndefinedAreaMode": XomoAutomationSchema.string(
            description: "How Offset fills pixels shifted beyond the canvas",
            values: ImageEditorOffsetUndefinedAreaMode.allCases.map(\.rawValue)
        ),
        "waveAmplitudePercent": XomoAutomationSchema.number(description: "Wave amplitude from -100 to 100 percent"),
        "waveAmplitude": XomoAutomationSchema.number(description: "Wave amplitude"),
        "waveFrequency": XomoAutomationSchema.number(description: "Wave frequency"),
        "rippleAmountPercent": XomoAutomationSchema.number(description: "Ripple amount from -100 to 100 percent"),
        "rippleAmount": XomoAutomationSchema.number(description: "Ripple amount"),
        "rippleFrequency": XomoAutomationSchema.number(description: "Ripple frequency"),
        "pinchAmountPercent": XomoAutomationSchema.number(description: "Pinch amount from -100 to 100 percent"),
        "pinchAmount": XomoAutomationSchema.number(description: "Pinch amount"),
        "spherizeAmountPercent": XomoAutomationSchema.number(description: "Spherize amount from -100 to 100 percent"),
        "spherizeAmount": XomoAutomationSchema.number(description: "Spherize amount"),
        "lensDistortionAmountPercent": XomoAutomationSchema.number(description: "Lens distortion amount from -100 to 100 percent"),
        "lensDistortion": XomoAutomationSchema.number(description: "Lens distortion correction")
    ])

    static func idBoolProperties(key: String) -> [String: XomoJSONValue] {
        [
            "id": XomoAutomationSchema.string(description: "Layer UUID"),
            key: XomoAutomationSchema.boolean(description: "Desired \(key) state")
        ]
    }
}
