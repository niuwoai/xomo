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
        guard action == "get" else {
            throw XomoAutomationCallError.invalidArgument(
                "Unknown adjustment layer settings action: \(action)"
            )
        }
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
