import Foundation

nonisolated enum ImageEditorLayerGestureProperty: CaseIterable, Sendable {
    case opacity, fillOpacity, sourceBlack, sourceWhite, underlyingBlack, underlyingWhite
    case maskDensity, maskFeather
}

nonisolated struct ImageEditorLayerPropertyGesture: Equatable, Sendable {
    fileprivate let id = UUID()
    let property: ImageEditorLayerGestureProperty
}

@MainActor
extension ImageEditorViewModel {
    /// A fresh gesture never shares the preceding gesture's snapshot, even for the same property.
    func beginLayerPropertyGesture(_ property: ImageEditorLayerGestureProperty) -> ImageEditorLayerPropertyGesture? {
        finishActiveLayerPropertyEditForNewCommand()
        switch property {
        case .opacity: beginSelectedLayerOpacityChange()
        case .fillOpacity: beginSelectedLayerFillOpacityChange()
        case .sourceBlack: beginSelectedLayerBlendIfSourceBlackChange()
        case .sourceWhite: beginSelectedLayerBlendIfSourceWhiteChange()
        case .underlyingBlack: beginSelectedLayerBlendIfUnderlyingBlackChange()
        case .underlyingWhite: beginSelectedLayerBlendIfUnderlyingWhiteChange()
        case .maskDensity: beginSelectedLayerMaskDensityChange()
        case .maskFeather: beginSelectedLayerMaskFeatherChange()
        }
        guard hasActiveLayerPropertyEdit else { return nil }
        let gesture = ImageEditorLayerPropertyGesture(property: property)
        layerPropertyTransactionState.activeGesture = gesture
        return gesture
    }

    @discardableResult
    func updateLayerPropertyGesture(_ gesture: ImageEditorLayerPropertyGesture, value: Double) -> Bool {
        guard value.isFinite, layerPropertyTransactionState.activeGesture == gesture else { return false }
        switch gesture.property {
        case .opacity: setSelectedLayerOpacity(value)
        case .fillOpacity: setSelectedLayerFillOpacity(value)
        case .sourceBlack: setSelectedLayerBlendIfSourceBlack(value)
        case .sourceWhite: setSelectedLayerBlendIfSourceWhite(value)
        case .underlyingBlack: setSelectedLayerBlendIfUnderlyingBlack(value)
        case .underlyingWhite: setSelectedLayerBlendIfUnderlyingWhite(value)
        case .maskDensity: setSelectedLayerMaskDensity(value)
        case .maskFeather: setSelectedLayerMaskFeather(value)
        }
        return true
    }

    @discardableResult
    func finishLayerPropertyGesture(_ gesture: ImageEditorLayerPropertyGesture) -> Bool {
        guard layerPropertyTransactionState.activeGesture == gesture else { return false }
        finishActiveLayerPropertyEditForNewCommand()
        return true
    }
}
