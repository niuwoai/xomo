//
//  XomoAutomationAdjustmentSettings.swift
//  veilpic
//

import Foundation

@MainActor
extension XomoAutomationRegistry {
    func adjustmentLayerSettingsAction(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws -> XomoJSONValue {
        guard let action = arguments["action"]?.stringValue else {
            throw XomoAutomationCallError.invalidArgument("Missing string argument: action")
        }
        switch action {
        case "get":
            return try adjustmentLayerSettingsResult(viewModel)
        case "set":
            return try setAdjustmentLayerSettings(arguments, viewModel: viewModel)
        default:
            throw XomoAutomationCallError.invalidArgument(
                "Unknown adjustment layer settings action: \(action)"
            )
        }
    }

    private func setAdjustmentLayerSettings(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws -> XomoJSONValue {
        let amount = try arguments["amount"].map {
            guard let value = $0.doubleValue, value.isFinite else {
                throw XomoAutomationCallError.invalidArgument(
                    "amount must be a finite number"
                )
            }
            return value
        }
        let settings = try arguments["settings"].map(decodeCompleteAdjustmentSettings)
        guard amount != nil || settings != nil else {
            throw XomoAutomationCallError.invalidArgument(
                "Adjustment layer settings set action requires amount or settings"
            )
        }
        let updatedLayerCount = viewModel.replaceSelectedAdjustmentLayerValues(
            amount: amount,
            settings: settings
        )
        guard updatedLayerCount > 0 else {
            throw XomoAutomationCallError.operationFailed(
                "Adjustment layer settings require a changed editable selected adjustment layer"
            )
        }
        return .object([
            "updatedLayerCount": .number(Double(updatedLayerCount)),
            "layers": try adjustmentLayerSettingsResult(viewModel)
        ])
    }

    private func adjustmentLayerSettingsResult(
        _ viewModel: ImageEditorViewModel
    ) throws -> XomoJSONValue {
        let selectedIDs = viewModel.document.selectedLayerIDs
        return .array(try viewModel.document.layers.compactMap { layer in
            guard
                selectedIDs.contains(layer.id),
                let adjustment = layer.adjustment
            else {
                return nil
            }
            return .object([
                "id": .string(layer.id.uuidString),
                "name": .string(layer.name),
                "locked": .bool(viewModel.document.isEffectivelyPixelsLocked(layer)),
                "adjustment": .string(adjustment.kind.rawValue),
                "amount": .number(adjustment.amount),
                "settings": try encodedJSONValue(
                    layer.adjustmentSettings.normalized()
                )
            ])
        })
    }

    private func decodeCompleteAdjustmentSettings(
        _ value: XomoJSONValue
    ) throws -> ImageEditorAdjustmentSettings {
        guard let object = value.objectValue else {
            throw XomoAutomationCallError.invalidArgument(
                "settings must be the complete object returned by get"
            )
        }
        let expectedKeys = try encodedJSONValue(
            ImageEditorAdjustmentSettings()
        ).objectValue.map { Set($0.keys) } ?? []
        guard Set(object.keys) == expectedKeys else {
            throw XomoAutomationCallError.invalidArgument(
                "settings must contain every field returned by get and no unknown fields"
            )
        }
        do {
            return try JSONDecoder().decode(
                ImageEditorAdjustmentSettings.self,
                from: JSONEncoder().encode(value)
            ).normalized()
        } catch {
            throw XomoAutomationCallError.invalidArgument(
                "Invalid adjustment layer settings: \(error.localizedDescription)"
            )
        }
    }

    private func encodedJSONValue<Value: Encodable>(
        _ value: Value
    ) throws -> XomoJSONValue {
        do {
            return try JSONDecoder().decode(
                XomoJSONValue.self,
                from: JSONEncoder().encode(value)
            )
        } catch {
            throw XomoAutomationCallError.operationFailed(
                "Could not encode adjustment layer settings: \(error.localizedDescription)"
            )
        }
    }
}
