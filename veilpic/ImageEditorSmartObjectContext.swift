import Foundation

enum ImageEditorSmartObjectContextAction: String, CaseIterable, Identifiable {
    case convert
    case newViaCopy
    case replaceContents
    case exportSourcePNG
    case makeUnique
    case resetTransform

    var id: String { rawValue }

    var actionTitleKey: String {
        switch self {
        case .convert: "imageEditor.action.layerSmartObject"
        case .newViaCopy: "imageEditor.action.layerSmartObjectViaCopy"
        case .replaceContents: "imageEditor.action.layerSmartObjectReplace"
        case .exportSourcePNG: "imageEditor.action.smartObjectSourcePNGExport"
        case .makeUnique: "imageEditor.action.layerSmartObjectMakeUnique"
        case .resetTransform: "imageEditor.action.layerSmartObjectResetTransform"
        }
    }

    var systemImage: String {
        switch self {
        case .convert: "cube.transparent"
        case .newViaCopy: "doc.on.doc"
        case .replaceContents: "arrow.triangle.2.circlepath"
        case .exportSourcePNG: "square.and.arrow.up"
        case .makeUnique: "point.3.connected.trianglepath.dotted"
        case .resetTransform: "arrow.counterclockwise"
        }
    }
}

@MainActor
extension ImageEditorViewModel {
    func canPerformSmartObjectActionFromContext(
        _ clickedLayerID: UUID,
        action: ImageEditorSmartObjectContextAction
    ) -> Bool {
        let selectedIDs = layerContextSelectionIDs(for: clickedLayerID)
        guard !selectedIDs.isEmpty else { return false }
        switch action {
        case .convert:
            return canConvertLayersFromContext(clickedLayerID)
        case .newViaCopy:
            return canCreateSmartObjectViaCopy(selectedIDs: selectedIDs)
        case .replaceContents:
            return !smartObjectReplacementTargetSourceIDs(
                selectedIDs: selectedIDs
            ).isEmpty
        case .exportSourcePNG:
            return canExportSmartObjectSourcePNG(selectedIDs: selectedIDs)
        case .makeUnique:
            return !smartObjectUniqueTargetIndices(selectedIDs: selectedIDs).isEmpty
        case .resetTransform:
            return !smartObjectResetTransformPlans(selectedIDs: selectedIDs).isEmpty
        }
    }

    @discardableResult
    func performSmartObjectActionFromContext(
        _ clickedLayerID: UUID,
        action: ImageEditorSmartObjectContextAction,
        chooseReplacement: ((Set<UUID>) -> Void)? = nil,
        chooseSourcePNGDestination: ((Data, String) -> Void)? = nil
    ) -> Bool {
        guard canPerformSmartObjectActionFromContext(
            clickedLayerID,
            action: action
        ) else { return false }
        if action == .convert {
            return convertLayersFromContext(clickedLayerID)
        }

        prepareLayerContextSelection(for: clickedLayerID)
        switch action {
        case .convert:
            return false
        case .newViaCopy:
            return createSmartObjectViaCopy()
        case .replaceContents:
            let sourceIDs = smartObjectReplacementTargetSourceIDs()
            if let chooseReplacement {
                chooseReplacement(sourceIDs)
            } else {
                chooseSmartObjectReplacementFile(targetSourceIDs: sourceIDs)
            }
            return true
        case .exportSourcePNG:
            guard let data = selectedSmartObjectSourcePNGData(),
                  let filename = selectedSmartObjectSourcePNGFilename()
            else { return false }
            if let chooseSourcePNGDestination {
                chooseSourcePNGDestination(data, filename)
            } else {
                chooseSmartObjectSourcePNGDestination(
                    data: data,
                    filename: filename
                )
            }
            return true
        case .makeUnique:
            makeSelectedSmartObjectUnique()
            return true
        case .resetTransform:
            resetSelectedSmartObjectTransform()
            return true
        }
    }
}
