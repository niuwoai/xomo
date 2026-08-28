//
//  XomoAutomationFilterSettings.swift
//  veilpic
//

import Foundation

@MainActor
extension XomoAutomationRegistry {
    func filterLayerSettingsAction(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws -> XomoJSONValue {
        guard let action = arguments["action"]?.stringValue else {
            throw XomoAutomationCallError.invalidArgument("Missing string argument: action")
        }
        switch action {
        case "get":
            return try filterLayerSettingsResult(viewModel)
        case "set":
            return try setFilterLayerSettings(arguments, viewModel: viewModel)
        default:
            throw XomoAutomationCallError.invalidArgument(
                "Unknown filter layer settings action: \(action)"
            )
        }
    }

    private func setFilterLayerSettings(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws -> XomoJSONValue {
        let intensity = try arguments["intensity"].map {
            guard let value = $0.doubleValue, value.isFinite else {
                throw XomoAutomationCallError.invalidArgument(
                    "intensity must be a finite number"
                )
            }
            return value
        }
        let settings = try arguments["settings"].map(decodeCompleteFilterSettings)
        guard intensity != nil || settings != nil else {
            throw XomoAutomationCallError.invalidArgument(
                "Filter layer settings set action requires intensity or settings"
            )
        }
        let updatedLayerCount = viewModel.replaceSelectedFilterLayerValues(
            intensity: intensity,
            settings: settings
        )
        guard updatedLayerCount > 0 else {
            throw XomoAutomationCallError.operationFailed(
                "Filter layer settings require a changed editable selected filter layer"
            )
        }
        return .object([
            "updatedLayerCount": .number(Double(updatedLayerCount)),
            "layers": try filterLayerSettingsResult(viewModel)
        ])
    }

    private func filterLayerSettingsResult(
        _ viewModel: ImageEditorViewModel
    ) throws -> XomoJSONValue {
        let selectedIDs = viewModel.document.selectedLayerIDs
        return .array(try viewModel.document.layers.compactMap { layer in
            guard
                selectedIDs.contains(layer.id),
                let filter = layer.filter
            else {
                return nil
            }
            return .object([
                "id": .string(layer.id.uuidString),
                "name": .string(layer.name),
                "locked": .bool(viewModel.document.isEffectivelyPixelsLocked(layer)),
                "filter": .string(filter.kind.rawValue),
                "intensity": .number(filter.intensity),
                "settings": try encodedFilterJSONValue(
                    layer.filterSettings.normalized()
                )
            ])
        })
    }

    private func decodeCompleteFilterSettings(
        _ value: XomoJSONValue
    ) throws -> ImageEditorFilterSettings {
        guard let object = value.objectValue else {
            throw XomoAutomationCallError.invalidArgument(
                "settings must be the complete object returned by get"
            )
        }
        let expectedKeys = try encodedFilterJSONValue(
            ImageEditorFilterSettings()
        ).objectValue.map { Set($0.keys) } ?? []
        let optionalKeys: Set<String> = [
            "gaussianBlurRadius",
            "highPassRadius",
            "morphologyRadius"
        ]
        guard
            Set(object.keys).subtracting(optionalKeys) == expectedKeys,
            Set(object.keys).isSubset(of: expectedKeys.union(optionalKeys))
        else {
            throw XomoAutomationCallError.invalidArgument(
                "settings must contain every field returned by get and no unknown fields"
            )
        }
        do {
            return try JSONDecoder().decode(
                ImageEditorFilterSettings.self,
                from: JSONEncoder().encode(value)
            ).normalized()
        } catch {
            throw XomoAutomationCallError.invalidArgument(
                "Invalid filter layer settings: \(error.localizedDescription)"
            )
        }
    }

    private func encodedFilterJSONValue<Value: Encodable>(
        _ value: Value
    ) throws -> XomoJSONValue {
        do {
            return try JSONDecoder().decode(
                XomoJSONValue.self,
                from: JSONEncoder().encode(value)
            )
        } catch {
            throw XomoAutomationCallError.operationFailed(
                "Could not encode filter layer settings: \(error.localizedDescription)"
            )
        }
    }
}
