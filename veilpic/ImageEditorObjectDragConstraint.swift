//
//  ImageEditorObjectDragConstraint.swift
//  veilpic
//

import CoreGraphics

enum ImageEditorObjectDragAxis: Equatable {
    case horizontal
    case vertical
}

enum ImageEditorObjectDragConstraint {
    private static let activationDistance: CGFloat = 0.5

    /// Locks to the first clearly dominant axis and keeps that decision until
    /// Shift is released. This avoids a diagonal drag flickering between axes.
    static func resolvedAxis(
        for totalTranslation: CGSize,
        existingAxis: ImageEditorObjectDragAxis?,
        isConstrained: Bool
    ) -> ImageEditorObjectDragAxis? {
        guard isConstrained else { return nil }
        if let existingAxis { return existingAxis }

        let horizontalDistance = abs(totalTranslation.width)
        let verticalDistance = abs(totalTranslation.height)
        guard max(horizontalDistance, verticalDistance) >= activationDistance else { return nil }
        return horizontalDistance >= verticalDistance ? .horizontal : .vertical
    }

    static func incrementalDelta(
        currentTranslation: CGSize,
        previousTranslation: CGSize,
        axis: ImageEditorObjectDragAxis?
    ) -> CGSize {
        constrainedDelta(
            CGSize(
                width: currentTranslation.width - previousTranslation.width,
                height: currentTranslation.height - previousTranslation.height
            ),
            to: axis
        )
    }

    static func constrainedDelta(
        _ delta: CGSize,
        to axis: ImageEditorObjectDragAxis?
    ) -> CGSize {
        switch axis {
        case .horizontal:
            return CGSize(width: delta.width, height: 0)
        case .vertical:
            return CGSize(width: 0, height: delta.height)
        case nil:
            return delta
        }
    }
}
