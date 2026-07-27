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
