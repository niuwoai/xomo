import Foundation

@MainActor
extension XomoAutomationRegistry {
    func layerProperties(
        _ arguments: [String: XomoJSONValue],
        viewModel: ImageEditorViewModel
    ) throws {
        let property = try requiredString("property", in: arguments)
        switch property {
        case "fillOpacity":
            let value = try requiredNumber("value", in: arguments)
            viewModel.finishActiveCanvasEditForNewCommand()
            viewModel.beginSelectedLayerFillOpacityChange()
            viewModel.setSelectedLayerFillOpacity(value)
            viewModel.commitSelectedLayerFillOpacityChange()
        case "blendIfSourceBlack":
            let value = try requiredNumber("value", in: arguments)
            viewModel.finishActiveCanvasEditForNewCommand()
            viewModel.beginSelectedLayerBlendIfSourceBlackChange()
            viewModel.setSelectedLayerBlendIfSourceBlack(value)
            viewModel.commitSelectedLayerBlendIfChange(.sourceBlack)
        case "blendIfSourceWhite":
            let value = try requiredNumber("value", in: arguments)
            viewModel.finishActiveCanvasEditForNewCommand()
            viewModel.beginSelectedLayerBlendIfSourceWhiteChange()
            viewModel.setSelectedLayerBlendIfSourceWhite(value)
            viewModel.commitSelectedLayerBlendIfChange(.sourceWhite)
        case "blendIfUnderlyingBlack":
            let value = try requiredNumber("value", in: arguments)
            viewModel.finishActiveCanvasEditForNewCommand()
            viewModel.beginSelectedLayerBlendIfUnderlyingBlackChange()
            viewModel.setSelectedLayerBlendIfUnderlyingBlack(value)
            viewModel.commitSelectedLayerBlendIfChange(.underlyingBlack)
        case "blendIfUnderlyingWhite":
            let value = try requiredNumber("value", in: arguments)
            viewModel.finishActiveCanvasEditForNewCommand()
            viewModel.beginSelectedLayerBlendIfUnderlyingWhiteChange()
            viewModel.setSelectedLayerBlendIfUnderlyingWhite(value)
            viewModel.commitSelectedLayerBlendIfChange(.underlyingWhite)
        case "maskDensity":
            let value = try requiredNumber("value", in: arguments)
            viewModel.finishActiveCanvasEditForNewCommand()
            viewModel.beginSelectedLayerMaskDensityChange()
            viewModel.setSelectedLayerMaskDensity(value)
            viewModel.commitSelectedLayerMaskDensityChange()
        case "maskFeather":
            let value = try requiredNumber("value", in: arguments)
            viewModel.finishActiveCanvasEditForNewCommand()
            viewModel.beginSelectedLayerMaskFeatherChange()
            viewModel.setSelectedLayerMaskFeather(value)
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

    func setLayerLock(
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
}
