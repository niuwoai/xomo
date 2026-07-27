//
//  XomoAutomationFillSettings.swift
//  veilpic
//

import Foundation

@MainActor
extension XomoAutomationRegistry {
    func solidColorFillSettingsAction(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws -> XomoJSONValue {
        guard let action = arguments["action"]?.stringValue else {
            throw XomoAutomationCallError.invalidArgument("Missing string argument: action")
        }
        switch action {
        case "get":
            return solidColorFillSettingsResult(viewModel)
        case "set":
            let target = ImageEditorSolidColorFillContent(
                red: try finiteNumber("red", in: arguments),
                green: try finiteNumber("green", in: arguments),
                blue: try finiteNumber("blue", in: arguments)
            ).normalized()
            let selectedIDs = viewModel.document.selectedLayerIDs
            let updatedLayerCount = viewModel.document.layers.reduce(into: 0) { count, layer in
                guard
                    selectedIDs.contains(layer.id),
                    !viewModel.document.isEffectivelyPixelsLocked(layer),
                    let content = layer.solidColorFillContent?.normalized(),
                    content != target
                else {
                    return
                }
                count += 1
            }
            guard updatedLayerCount > 0 else {
                throw XomoAutomationCallError.operationFailed(
                    "Solid color fill settings require a changed editable selected solid-color-fill layer"
                )
            }

            viewModel.solidColorFillRed = target.red
            viewModel.solidColorFillGreen = target.green
            viewModel.solidColorFillBlue = target.blue
            viewModel.updateSelectedSolidColorFillLayer()

            return .object([
                "updatedLayerCount": .number(Double(updatedLayerCount)),
                "layers": solidColorFillSettingsResult(viewModel)
            ])
        default:
            throw XomoAutomationCallError.invalidArgument(
                "Unknown solid color fill settings action: \(action)"
            )
        }
    }

    private func solidColorFillSettingsResult(
        _ viewModel: ImageEditorViewModel
    ) -> XomoJSONValue {
        let selectedIDs = viewModel.document.selectedLayerIDs
        return .array(viewModel.document.layers.compactMap { layer in
            guard
                selectedIDs.contains(layer.id),
                let content = layer.solidColorFillContent?.normalized()
            else {
                return nil
            }
            return .object([
                "id": .string(layer.id.uuidString),
                "name": .string(layer.name),
                "locked": .bool(viewModel.document.isEffectivelyPixelsLocked(layer)),
                "red": .number(content.red),
                "green": .number(content.green),
                "blue": .number(content.blue)
            ])
        })
    }

    func gradientFillSettingsAction(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws -> XomoJSONValue {
        guard let action = arguments["action"]?.stringValue else {
            throw XomoAutomationCallError.invalidArgument("Missing string argument: action")
        }
        switch action {
        case "get":
            return gradientFillSettingsResult(viewModel)
        case "set":
            return try setGradientFillSettings(arguments, viewModel: viewModel)
        default:
            throw XomoAutomationCallError.invalidArgument(
                "Unknown gradient fill settings action: \(action)"
            )
        }
    }

    private func setGradientFillSettings(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws -> XomoJSONValue {
        let target = try gradientFillContent(in: arguments)
        let selectedIDs = viewModel.document.selectedLayerIDs
        let indices = viewModel.document.layers.indices.filter { index in
            let layer = viewModel.document.layers[index]
            guard let current = layer.gradientFillContent?.normalized() else { return false }
            return selectedIDs.contains(layer.id)
                && !viewModel.document.isEffectivelyPixelsLocked(layer)
                && current != target
        }
        guard !indices.isEmpty else {
            throw XomoAutomationCallError.operationFailed(
                "Gradient fill settings require a changed editable selected gradient-fill layer"
            )
        }

        viewModel.pushUndo()
        for index in indices {
            viewModel.document.layers[index].kind = .gradientFill(target)
            viewModel.document.layers[index].name = L10n.text("imageEditor.layer.gradientFillName")
        }
        syncGradientFillControls(target, viewModel: viewModel)
        viewModel.appendHistory(
            L10n.text(
                indices.count == 1
                    ? "imageEditor.history.layerGradientFillUpdate"
                    : "imageEditor.history.layerGradientFillUpdateSelected"
            )
        )
        return .object([
            "updatedLayerCount": .number(Double(indices.count)),
            "layers": gradientFillSettingsResult(viewModel)
        ])
    }

    private func syncGradientFillControls(
        _ content: ImageEditorGradientFillContent,
        viewModel: ImageEditorViewModel
    ) {
        viewModel.selectedGradientFillPreset = content.preset
        viewModel.selectedGradientFillStyle = content.style
        viewModel.gradientFillReverse = content.reverse
        viewModel.gradientFillAngle = Double(content.angle)
        viewModel.gradientFillScale = Double(content.scale)
        viewModel.gradientFillStartRed = content.startRed
        viewModel.gradientFillStartGreen = content.startGreen
        viewModel.gradientFillStartBlue = content.startBlue
        viewModel.gradientFillEndRed = content.endRed
        viewModel.gradientFillEndGreen = content.endGreen
        viewModel.gradientFillEndBlue = content.endBlue
    }

    private func gradientFillContent(
        in arguments: [String: XomoJSONValue]
    ) throws -> ImageEditorGradientFillContent {
        guard
            let presetName = arguments["preset"]?.stringValue,
            let preset = ImageEditorGradientFillPreset(rawValue: presetName)
        else {
            throw XomoAutomationCallError.invalidArgument("Missing or invalid string argument: preset")
        }
        guard
            let styleName = arguments["style"]?.stringValue,
            let style = ImageEditorGradientFillStyle(rawValue: styleName)
        else {
            throw XomoAutomationCallError.invalidArgument("Missing or invalid string argument: style")
        }
        guard let reverse = arguments["reverse"]?.boolValue else {
            throw XomoAutomationCallError.invalidArgument("Missing boolean argument: reverse")
        }
        let angle = try finiteNumber("angle", in: arguments)
        guard (-180...180).contains(angle) else {
            throw XomoAutomationCallError.invalidArgument("angle must be between -180 and 180")
        }
        let scale = try finiteNumber("scale", in: arguments)
        guard (0.25...4).contains(scale) else {
            throw XomoAutomationCallError.invalidArgument("scale must be between 0.25 and 4")
        }
        let start = try gradientColor("startColor", in: arguments)
        let end = try gradientColor("endColor", in: arguments)
        let stops = try optionalGradientStops(in: arguments)

        return ImageEditorGradientFillContent(
            preset: preset,
            style: style,
            reverse: reverse,
            angle: CGFloat(angle),
            scale: CGFloat(scale),
            startRed: start.red,
            startGreen: start.green,
            startBlue: start.blue,
            endRed: end.red,
            endGreen: end.green,
            endBlue: end.blue,
            colorStops: stops
        ).normalized()
    }

    private func optionalGradientStops(
        in arguments: [String: XomoJSONValue]
    ) throws -> [ImageEditorGradientColorStop]? {
        guard let value = arguments["stops"] else { return nil }
        guard let values = value.arrayValue else {
            throw XomoAutomationCallError.invalidArgument("stops must be an array")
        }
        guard (2...ImageEditorGradientFillContent.maximumColorStopCount).contains(values.count) else {
            throw XomoAutomationCallError.invalidArgument("stops must contain 2 to 16 items")
        }
        let stops = try values.enumerated().map { index, value in
            guard
                let stop = value.objectValue,
                let position = stop["position"]?.doubleValue,
                position.isFinite,
                (0...1).contains(position)
            else {
                throw XomoAutomationCallError.invalidArgument(
                    "stops[\(index)].position must be between 0 and 1"
                )
            }
            let color = try gradientColor("color", in: stop)
            return ImageEditorGradientColorStop(
                position: position,
                red: color.red,
                green: color.green,
                blue: color.blue
            )
        }
        guard
            abs((stops.first?.position ?? 1)) <= 0.000_1,
            abs((stops.last?.position ?? 0) - 1) <= 0.000_1,
            zip(stops, stops.dropFirst()).allSatisfy({ pair in
                pair.0.position <= pair.1.position
            })
        else {
            throw XomoAutomationCallError.invalidArgument(
                "stops must be ordered and span positions 0 through 1"
            )
        }
        return stops
    }

    private func gradientFillSettingsResult(
        _ viewModel: ImageEditorViewModel
    ) -> XomoJSONValue {
        let selectedIDs = viewModel.document.selectedLayerIDs
        return .array(viewModel.document.layers.compactMap { layer in
            guard
                selectedIDs.contains(layer.id),
                let content = layer.gradientFillContent?.normalized()
            else {
                return nil
            }
            var result: [String: XomoJSONValue] = [
                "id": .string(layer.id.uuidString),
                "name": .string(layer.name),
                "locked": .bool(viewModel.document.isEffectivelyPixelsLocked(layer)),
                "preset": .string(content.preset.rawValue),
                "style": .string(content.style.rawValue),
                "reverse": .bool(content.reverse),
                "angle": .number(Double(content.angle)),
                "scale": .number(Double(content.scale)),
                "startColor": gradientColorJSON(
                    red: content.startRed,
                    green: content.startGreen,
                    blue: content.startBlue
                ),
                "endColor": gradientColorJSON(
                    red: content.endRed,
                    green: content.endGreen,
                    blue: content.endBlue
                )
            ]
            if let stops = content.colorStops {
                result["stops"] = .array(stops.map { stop in
                    .object([
                        "position": .number(stop.position),
                        "color": gradientColorJSON(
                            red: stop.red,
                            green: stop.green,
                            blue: stop.blue
                        )
                    ])
                })
            }
            return .object(result)
        })
    }

    private func gradientColor(
        _ key: String,
        in arguments: [String: XomoJSONValue]
    ) throws -> (red: Double, green: Double, blue: Double) {
        guard let object = arguments[key]?.objectValue else {
            throw XomoAutomationCallError.invalidArgument("\(key) must be an object")
        }
        return (
            try unitNumber("red", in: object, path: key),
            try unitNumber("green", in: object, path: key),
            try unitNumber("blue", in: object, path: key)
        )
    }

    private func gradientColorJSON(
        red: Double,
        green: Double,
        blue: Double
    ) -> XomoJSONValue {
        .object([
            "red": .number(red),
            "green": .number(green),
            "blue": .number(blue)
        ])
    }

    private func unitNumber(
        _ key: String,
        in arguments: [String: XomoJSONValue],
        path: String
    ) throws -> Double {
        let value = try finiteNumber(key, in: arguments)
        guard (0...1).contains(value) else {
            throw XomoAutomationCallError.invalidArgument(
                "\(path).\(key) must be between 0 and 1"
            )
        }
        return value
    }

    private func finiteNumber(
        _ key: String,
        in arguments: [String: XomoJSONValue]
    ) throws -> Double {
        guard let value = arguments[key]?.doubleValue, value.isFinite else {
            throw XomoAutomationCallError.invalidArgument(
                "Missing or invalid number argument: \(key)"
            )
        }
        return value
    }
}
