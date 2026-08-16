//
//  ImageEditorGradientOverlayCenterHandle.swift
//  veilpic
//
//  Created by Codex on 2026/8/16.
//

import AppKit
import CoreGraphics
import Foundation

enum ImageEditorGradientOverlayCenterGeometry {
    static func canvasPoint(center: CGPoint, layerFrame: CGRect) -> CGPoint? {
        let frame = layerFrame.standardized
        guard frame.width > 0, frame.height > 0 else { return nil }
        let normalized = ImageEditorGradientOverlayCenterPolicy.normalized(center)
        return CGPoint(
            x: frame.minX + normalized.x * frame.width,
            y: frame.minY + normalized.y * frame.height
        )
    }

    static func normalizedCenter(canvasPoint: CGPoint, layerFrame: CGRect) -> CGPoint? {
        let frame = layerFrame.standardized
        guard frame.width > 0,
              frame.height > 0,
              canvasPoint.x.isFinite,
              canvasPoint.y.isFinite
        else { return nil }
        return ImageEditorGradientOverlayCenterPolicy.normalized(
            CGPoint(
                x: (canvasPoint.x - frame.minX) / frame.width,
                y: (canvasPoint.y - frame.minY) / frame.height
            )
        )
    }
}

struct ImageEditorGradientOverlayCanvasGeometry: Equatable {
    var center: CGPoint
    var axisStart: CGPoint
    var axisEndpoint: CGPoint
}

struct ImageEditorGradientOverlayAxisValues: Equatable {
    var angle: CGFloat
    var scale: CGFloat
}

struct ImageEditorGradientOverlayStopHandlePoint: Identifiable, Equatable {
    var index: Int
    var canvasPoint: CGPoint
    var stop: ImageEditorGradientColorStop

    var id: Int { index }
}

struct ImageEditorGradientOverlayMidpointHandlePoint: Identifiable, Equatable {
    var lowerStopIndex: Int
    var canvasPoint: CGPoint
    var midpoint: Double

    var id: Int { lowerStopIndex }
}

struct ImageEditorGradientOverlayStopRemovalResult: Equatable {
    var removedIndex: Int
    var nextSelectedIndex: Int?
}

enum ImageEditorGradientOverlayStopKeyboardAction: Equatable {
    case nudge(Double)
    case consume

    static func resolve(delta: CGSize) -> ImageEditorGradientOverlayStopKeyboardAction {
        guard delta.width.isFinite, delta.height.isFinite else { return .consume }
        guard delta.height == 0, delta.width != 0 else { return .consume }
        return .nudge(Double(delta.width / 100))
    }
}

enum ImageEditorGradientOverlayCanvasHandleSelection: Equatable {
    case stop(Int)
    case midpoint(after: Int)
}

enum ImageEditorGradientOverlayCanvasHandleSelectionPolicy {
    static func next(
        current: ImageEditorGradientOverlayCanvasHandleSelection?,
        stopCount: Int,
        isReversed: Bool,
        movesBackward: Bool
    ) -> ImageEditorGradientOverlayCanvasHandleSelection? {
        guard stopCount >= 2 else { return nil }
        var ordered: [ImageEditorGradientOverlayCanvasHandleSelection] = []
        for lowerStopIndex in 0..<(stopCount - 1) {
            ordered.append(.midpoint(after: lowerStopIndex))
            let upperStopIndex = lowerStopIndex + 1
            if upperStopIndex < stopCount - 1 {
                ordered.append(.stop(upperStopIndex))
            }
        }
        if isReversed {
            ordered.reverse()
        }
        guard !ordered.isEmpty else { return nil }
        guard let current,
              let currentIndex = ordered.firstIndex(of: current)
        else {
            return movesBackward ? ordered.last : ordered.first
        }
        let offset = movesBackward ? -1 : 1
        let nextIndex = (currentIndex + offset + ordered.count) % ordered.count
        return ordered[nextIndex]
    }
}

enum ImageEditorGradientOverlayCanvasTabKeyPolicy {
    static func matches(
        keyCode: UInt16,
        modifierFlags: NSEvent.ModifierFlags,
        isTextInputActive: Bool
    ) -> Bool {
        let relevantFlags = modifierFlags.intersection([.command, .option, .shift, .control])
        return keyCode == 48
            && !isTextInputActive
            && (relevantFlags.isEmpty || relevantFlags == [.shift])
    }
}

enum ImageEditorGradientOverlayCanvasBoundaryKeyPolicy {
    static func displayedDelta(
        keyCode: UInt16,
        modifierFlags: NSEvent.ModifierFlags,
        isTextInputActive: Bool
    ) -> Double? {
        let relevantFlags = modifierFlags.intersection([.command, .option, .shift, .control])
        guard relevantFlags.isEmpty, !isTextInputActive else { return nil }
        return switch keyCode {
        case 115: -1
        case 119: 1
        default: nil
        }
    }
}

enum ImageEditorGradientOverlayAxisGeometry {
    static let angleSnapStep: CGFloat = 15

    static func canvasGeometry(
        style: ImageEditorGradientFillStyle,
        center: CGPoint,
        angle: CGFloat,
        scale: CGFloat,
        layerFrame: CGRect
    ) -> ImageEditorGradientOverlayCanvasGeometry? {
        let frame = layerFrame.standardized
        guard frame.width > 0, frame.height > 0 else { return nil }
        let normalizedCenter = ImageEditorGradientOverlayCenterPolicy.normalized(center)
        let canvasCenter = CGPoint(
            x: frame.minX + normalizedCenter.x * frame.width,
            y: frame.minY + normalizedCenter.y * frame.height
        )
        let normalizedAngle = normalizedAngle(angle)
        let radians = normalizedAngle * .pi / 180
        let direction = style == .radial
            ? CGSize(width: 1, height: 0)
            : CGSize(width: cos(radians), height: sin(radians))
        let resolvedScale = max(0.25, min(4, scale))
        let length: CGFloat
        switch style {
        case .linear, .reflected:
            length = span(angle: normalizedAngle, size: frame.size) * resolvedScale / 2
        case .radial, .diamond:
            length = referenceRadius(size: frame.size) * resolvedScale
        }
        let endpoint = CGPoint(
            x: canvasCenter.x + direction.width * length,
            y: canvasCenter.y + direction.height * length
        )
        let start = style == .linear
            ? CGPoint(
                x: canvasCenter.x - direction.width * length,
                y: canvasCenter.y - direction.height * length
            )
            : canvasCenter
        return ImageEditorGradientOverlayCanvasGeometry(
            center: canvasCenter,
            axisStart: start,
            axisEndpoint: endpoint
        )
    }

    static func stopHandlePoints(
        style: ImageEditorGradientFillStyle,
        center: CGPoint,
        angle: CGFloat,
        scale: CGFloat,
        reverse: Bool,
        stops: [ImageEditorGradientColorStop],
        layerFrame: CGRect
    ) -> [ImageEditorGradientOverlayStopHandlePoint] {
        guard let geometry = canvasGeometry(
            style: style,
            center: center,
            angle: angle,
            scale: scale,
            layerFrame: layerFrame
        ) else { return [] }
        let normalizedStops = ImageEditorGradientFillContent.shapeLinear(
            colorStops: stops
        ).shapeColorStops
        return normalizedStops.indices.dropFirst().dropLast().map { index in
            let stop = normalizedStops[index]
            let displayedPosition = reverse ? 1 - stop.position : stop.position
            return ImageEditorGradientOverlayStopHandlePoint(
                index: index,
                canvasPoint: point(
                    at: displayedPosition,
                    from: geometry.axisStart,
                    to: geometry.axisEndpoint
                ),
                stop: stop
            )
        }
    }

    static func midpointHandlePoints(
        style: ImageEditorGradientFillStyle,
        center: CGPoint,
        angle: CGFloat,
        scale: CGFloat,
        reverse: Bool,
        stops: [ImageEditorGradientColorStop],
        layerFrame: CGRect
    ) -> [ImageEditorGradientOverlayMidpointHandlePoint] {
        guard let geometry = canvasGeometry(
            style: style,
            center: center,
            angle: angle,
            scale: scale,
            layerFrame: layerFrame
        ) else { return [] }
        let normalizedStops = ImageEditorGradientFillContent.shapeLinear(
            colorStops: stops
        ).shapeColorStops
        return normalizedStops.indices.dropLast().map { index in
            let lower = normalizedStops[index]
            let upper = normalizedStops[index + 1]
            let logicalPosition = lower.position
                + (upper.position - lower.position) * lower.midpoint
            let displayedPosition = reverse ? 1 - logicalPosition : logicalPosition
            return ImageEditorGradientOverlayMidpointHandlePoint(
                lowerStopIndex: index,
                canvasPoint: point(
                    at: displayedPosition,
                    from: geometry.axisStart,
                    to: geometry.axisEndpoint
                ),
                midpoint: lower.midpoint
            )
        }
    }

    static func logicalStopPosition(
        style: ImageEditorGradientFillStyle,
        center: CGPoint,
        angle: CGFloat,
        scale: CGFloat,
        reverse: Bool,
        layerFrame: CGRect,
        canvasPoint: CGPoint
    ) -> Double? {
        guard canvasPoint.x.isFinite,
              canvasPoint.y.isFinite,
              let geometry = canvasGeometry(
                  style: style,
                  center: center,
                  angle: angle,
                  scale: scale,
                  layerFrame: layerFrame
              )
        else { return nil }
        let axis = CGVector(
            dx: geometry.axisEndpoint.x - geometry.axisStart.x,
            dy: geometry.axisEndpoint.y - geometry.axisStart.y
        )
        let lengthSquared = axis.dx * axis.dx + axis.dy * axis.dy
        guard lengthSquared > 0.000_001 else { return nil }
        let pointer = CGVector(
            dx: canvasPoint.x - geometry.axisStart.x,
            dy: canvasPoint.y - geometry.axisStart.y
        )
        let displayedPosition = max(
            0,
            min(1, (pointer.dx * axis.dx + pointer.dy * axis.dy) / lengthSquared)
        )
        return reverse ? 1 - displayedPosition : displayedPosition
    }

    static func logicalMidpoint(
        after lowerStopIndex: Int,
        style: ImageEditorGradientFillStyle,
        center: CGPoint,
        angle: CGFloat,
        scale: CGFloat,
        reverse: Bool,
        stops: [ImageEditorGradientColorStop],
        layerFrame: CGRect,
        canvasPoint: CGPoint
    ) -> Double? {
        let normalizedStops = ImageEditorGradientFillContent.shapeLinear(
            colorStops: stops
        ).shapeColorStops
        guard normalizedStops.indices.contains(lowerStopIndex),
              lowerStopIndex < normalizedStops.count - 1,
              let position = logicalStopPosition(
                  style: style,
                  center: center,
                  angle: angle,
                  scale: scale,
                  reverse: reverse,
                  layerFrame: layerFrame,
                  canvasPoint: canvasPoint
              )
        else { return nil }
        let lowerPosition = normalizedStops[lowerStopIndex].position
        let upperPosition = normalizedStops[lowerStopIndex + 1].position
        let distance = upperPosition - lowerPosition
        guard distance > 0.000_001 else { return nil }
        return max(0, min(1, (position - lowerPosition) / distance))
    }

    private static func point(at position: Double, from start: CGPoint, to end: CGPoint) -> CGPoint {
        CGPoint(
            x: start.x + (end.x - start.x) * CGFloat(position),
            y: start.y + (end.y - start.y) * CGFloat(position)
        )
    }

    static func updatedAxis(
        style: ImageEditorGradientFillStyle,
        center: CGPoint,
        currentAngle: CGFloat,
        layerFrame: CGRect,
        canvasPoint: CGPoint,
        snappingAngle: Bool
    ) -> ImageEditorGradientOverlayAxisValues? {
        let frame = layerFrame.standardized
        guard frame.width > 0,
              frame.height > 0,
              canvasPoint.x.isFinite,
              canvasPoint.y.isFinite,
              let canvasCenter = ImageEditorGradientOverlayCenterGeometry.canvasPoint(
                  center: center,
                  layerFrame: frame
              )
        else { return nil }
        let delta = CGSize(
            width: canvasPoint.x - canvasCenter.x,
            height: canvasPoint.y - canvasCenter.y
        )
        let distance = hypot(delta.width, delta.height)
        guard distance > 0.001 else { return nil }

        if style == .radial {
            return ImageEditorGradientOverlayAxisValues(
                angle: normalizedAngle(currentAngle),
                scale: max(0.25, min(4, distance / referenceRadius(size: frame.size)))
            )
        }

        var angle = atan2(delta.height, delta.width) * 180 / .pi
        if snappingAngle {
            angle = (angle / angleSnapStep).rounded() * angleSnapStep
        }
        angle = normalizedAngle(angle)
        let referenceLength: CGFloat
        switch style {
        case .linear, .reflected:
            referenceLength = span(angle: angle, size: frame.size) / 2
        case .diamond:
            referenceLength = referenceRadius(size: frame.size)
        case .radial:
            return nil
        }
        return ImageEditorGradientOverlayAxisValues(
            angle: angle,
            scale: max(0.25, min(4, distance / referenceLength))
        )
    }

    static func normalizedAngle(_ angle: CGFloat) -> CGFloat {
        var value = angle.truncatingRemainder(dividingBy: 360)
        if value > 180 { value -= 360 }
        if value < -180 { value += 360 }
        return value
    }

    private static func span(angle: CGFloat, size: CGSize) -> CGFloat {
        let radians = angle * .pi / 180
        return max(1, abs(cos(radians)) * size.width + abs(sin(radians)) * size.height)
    }

    private static func referenceRadius(size: CGSize) -> CGFloat {
        max(1, hypot(size.width / 2, size.height / 2))
    }
}

@MainActor
extension ImageEditorViewModel {
    var selectedLayerGradientOverlayCanvasIsReversed: Bool {
        singleSelectedGradientOverlayCanvasLayer?.style.gradientOverlayReverse ?? false
    }

    var selectedLayerGradientOverlayCanvasGeometry: ImageEditorGradientOverlayCanvasGeometry? {
        guard !isEditingLayerMask,
              let layer = singleSelectedGradientOverlayCanvasLayer
        else { return nil }
        return ImageEditorGradientOverlayAxisGeometry.canvasGeometry(
            style: layer.style.gradientOverlayStyle,
            center: layer.style.gradientOverlayCenter,
            angle: layer.style.gradientOverlayAngle,
            scale: layer.style.gradientOverlayScale,
            layerFrame: layer.frame
        )
    }

    var selectedLayerGradientOverlayCanvasStopHandlePoints:
        [ImageEditorGradientOverlayStopHandlePoint] {
        guard !isEditingLayerMask,
              let layer = singleSelectedGradientOverlayCanvasLayer
        else { return [] }
        return ImageEditorGradientOverlayAxisGeometry.stopHandlePoints(
            style: layer.style.gradientOverlayStyle,
            center: layer.style.gradientOverlayCenter,
            angle: layer.style.gradientOverlayAngle,
            scale: layer.style.gradientOverlayScale,
            reverse: layer.style.gradientOverlayReverse,
            stops: layer.style.resolvedGradientOverlayColorStops,
            layerFrame: layer.frame
        )
    }

    var selectedLayerGradientOverlayCanvasMidpointHandlePoints:
        [ImageEditorGradientOverlayMidpointHandlePoint] {
        guard !isEditingLayerMask,
              let layer = singleSelectedGradientOverlayCanvasLayer
        else { return [] }
        return ImageEditorGradientOverlayAxisGeometry.midpointHandlePoints(
            style: layer.style.gradientOverlayStyle,
            center: layer.style.gradientOverlayCenter,
            angle: layer.style.gradientOverlayAngle,
            scale: layer.style.gradientOverlayScale,
            reverse: layer.style.gradientOverlayReverse,
            stops: layer.style.resolvedGradientOverlayColorStops,
            layerFrame: layer.frame
        )
    }

    var selectedLayerGradientOverlayCanvasCenterPoint: CGPoint? {
        selectedLayerGradientOverlayCanvasGeometry?.center
    }

    var canEditSelectedLayerGradientOverlayCanvasCenter: Bool {
        guard let layer = singleSelectedGradientOverlayCanvasLayer else { return false }
        return !document.isEffectivelyLocked(layer)
    }

    var hasActiveGradientOverlayCenterTransaction: Bool {
        editingGradientOverlayCenterLayerID != nil
    }

    @discardableResult
    func beginEditingSelectedLayerGradientOverlayCanvasCenter() -> Bool {
        guard editingGradientOverlayCenterLayerID == nil,
              editingGradientOverlayAxisLayerID == nil,
              editingGradientOverlayStopLayerID == nil,
              editingGradientOverlayMidpointLayerID == nil,
              canEditSelectedLayerGradientOverlayCanvasCenter,
              let layer = singleSelectedGradientOverlayCanvasLayer
        else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return false
        }
        beginGradientOverlayCenterUndoTransaction()
        editingGradientOverlayCenterLayerID = layer.id
        editingGradientOverlayCenterOriginalPoint = ImageEditorGradientOverlayCenterPolicy
            .normalized(layer.style.gradientOverlayCenter)
        return true
    }

    func updateSelectedLayerGradientOverlayCanvasCenter(to canvasPoint: CGPoint) {
        guard let layerID = editingGradientOverlayCenterLayerID,
              let index = document.layers.firstIndex(where: { $0.id == layerID }),
              let center = ImageEditorGradientOverlayCenterGeometry.normalizedCenter(
                canvasPoint: canvasPoint,
                layerFrame: document.layers[index].frame
              ),
              document.layers[index].style.gradientOverlayCenter != center
        else { return }
        document.layers[index].style.gradientOverlayCenter = center
        statusText = L10n.text("imageEditor.status.gradientOverlayCenterMoved")
    }

    func finishEditingSelectedLayerGradientOverlayCanvasCenter() {
        guard let layerID = editingGradientOverlayCenterLayerID else { return }
        let currentCenter = document.layers.first(where: { $0.id == layerID }).map {
            ImageEditorGradientOverlayCenterPolicy.normalized($0.style.gradientOverlayCenter)
        }
        let didChange = currentCenter != editingGradientOverlayCenterOriginalPoint
        if didChange {
            appendHistory(L10n.text("imageEditor.history.gradientOverlayCenter"))
        } else {
            updateStatus()
        }
        finishGradientOverlayCenterUndoTransaction(didChange: didChange)
        clearGradientOverlayCenterEditingState()
    }

    @discardableResult
    func cancelEditingSelectedLayerGradientOverlayCanvasCenter() -> Bool {
        guard editingGradientOverlayCenterLayerID != nil else { return false }
        let cancelled = cancelGradientOverlayCenterUndoTransaction()
        clearGradientOverlayCenterEditingState()
        if cancelled { updateStatus() }
        return cancelled
    }

    var hasActiveGradientOverlayAxisTransaction: Bool {
        editingGradientOverlayAxisLayerID != nil
    }

    @discardableResult
    func beginEditingSelectedLayerGradientOverlayCanvasAxis() -> Bool {
        guard editingGradientOverlayAxisLayerID == nil,
              editingGradientOverlayCenterLayerID == nil,
              editingGradientOverlayStopLayerID == nil,
              editingGradientOverlayMidpointLayerID == nil,
              canEditSelectedLayerGradientOverlayCanvasCenter,
              let layer = singleSelectedGradientOverlayCanvasLayer
        else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return false
        }
        beginGradientOverlayAxisUndoTransaction()
        editingGradientOverlayAxisLayerID = layer.id
        editingGradientOverlayAxisOriginalAngle = ImageEditorGradientOverlayAxisGeometry
            .normalizedAngle(layer.style.gradientOverlayAngle)
        editingGradientOverlayAxisOriginalScale = layer.style.gradientOverlayScale
        return true
    }

    func updateSelectedLayerGradientOverlayCanvasAxis(
        to canvasPoint: CGPoint,
        snappingAngle: Bool
    ) {
        guard let layerID = editingGradientOverlayAxisLayerID,
              let index = document.layers.firstIndex(where: { $0.id == layerID }),
              let values = ImageEditorGradientOverlayAxisGeometry.updatedAxis(
                  style: document.layers[index].style.gradientOverlayStyle,
                  center: document.layers[index].style.gradientOverlayCenter,
                  currentAngle: document.layers[index].style.gradientOverlayAngle,
                  layerFrame: document.layers[index].frame,
                  canvasPoint: canvasPoint,
                  snappingAngle: snappingAngle
              )
        else { return }
        let currentAngle = ImageEditorGradientOverlayAxisGeometry.normalizedAngle(
            document.layers[index].style.gradientOverlayAngle
        )
        guard currentAngle != values.angle
                || document.layers[index].style.gradientOverlayScale != values.scale
        else { return }
        document.layers[index].style.gradientOverlayAngle = values.angle
        document.layers[index].style.gradientOverlayScale = values.scale
        statusText = L10n.text("imageEditor.status.gradientOverlayAxisMoved")
    }

    func finishEditingSelectedLayerGradientOverlayCanvasAxis() {
        guard let layerID = editingGradientOverlayAxisLayerID else { return }
        let style = document.layers.first(where: { $0.id == layerID })?.style
        let angle = style.map {
            ImageEditorGradientOverlayAxisGeometry.normalizedAngle($0.gradientOverlayAngle)
        }
        let angleDelta = angle.map {
            abs(ImageEditorGradientOverlayAxisGeometry.normalizedAngle(
                $0 - (editingGradientOverlayAxisOriginalAngle ?? $0)
            ))
        } ?? 0
        let scaleDelta = style.map {
            abs($0.gradientOverlayScale - (editingGradientOverlayAxisOriginalScale ?? $0.gradientOverlayScale))
        } ?? 0
        let didChange = angleDelta > 0.000_001 || scaleDelta > 0.000_001
        if didChange {
            appendHistory(L10n.text("imageEditor.history.gradientOverlayAxis"))
        }
        finishGradientOverlayAxisUndoTransaction(didChange: didChange)
        clearGradientOverlayAxisEditingState()
        if !didChange { updateStatus() }
    }

    @discardableResult
    func cancelEditingSelectedLayerGradientOverlayCanvasAxis() -> Bool {
        guard editingGradientOverlayAxisLayerID != nil else { return false }
        let cancelled = cancelGradientOverlayAxisUndoTransaction()
        clearGradientOverlayAxisEditingState()
        if cancelled { updateStatus() }
        return cancelled
    }

    var hasActiveGradientOverlayStopTransaction: Bool {
        editingGradientOverlayStopLayerID != nil
    }

    @discardableResult
    func beginEditingSelectedLayerGradientOverlayCanvasStop(at stopIndex: Int) -> Bool {
        guard editingGradientOverlayStopLayerID == nil,
              editingGradientOverlayCenterLayerID == nil,
              editingGradientOverlayAxisLayerID == nil,
              editingGradientOverlayMidpointLayerID == nil,
              canEditSelectedLayerGradientOverlayCanvasCenter,
              let layer = singleSelectedGradientOverlayCanvasLayer
        else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return false
        }
        let stops = layer.style.resolvedGradientOverlayColorStops
        guard stopIndex > 0, stopIndex < stops.count - 1 else { return false }
        beginGradientOverlayStopUndoTransaction()
        editingGradientOverlayStopLayerID = layer.id
        editingGradientOverlayStopIndex = stopIndex
        editingGradientOverlayOriginalStops = stops
        return true
    }

    func updateSelectedLayerGradientOverlayCanvasStop(to canvasPoint: CGPoint) {
        guard let layerID = editingGradientOverlayStopLayerID,
              let stopIndex = editingGradientOverlayStopIndex,
              let originalStops = editingGradientOverlayOriginalStops,
              let index = document.layers.firstIndex(where: { $0.id == layerID }),
              let position = logicalGradientOverlayStopPosition(
                  layer: document.layers[index],
                  canvasPoint: canvasPoint
              )
        else { return }
        let stops = ImageEditorGradientOverlayStopDraftEditing.movingStop(
            originalStops,
            at: stopIndex,
            to: position
        )
        guard stops != document.layers[index].style.resolvedGradientOverlayColorStops else {
            return
        }
        document.layers[index].style.setGradientOverlayColorStops(stops)
        statusText = L10n.text("imageEditor.status.gradientOverlayStopMoved")
    }

    func finishEditingSelectedLayerGradientOverlayCanvasStop() {
        guard let layerID = editingGradientOverlayStopLayerID else { return }
        let currentStops = document.layers.first(where: { $0.id == layerID })?
            .style.resolvedGradientOverlayColorStops
        let didChange = !gradientOverlayStopsMatch(
            currentStops,
            editingGradientOverlayOriginalStops
        )
        if didChange {
            appendHistory(L10n.text("imageEditor.history.gradientOverlayStop"))
        }
        finishGradientOverlayStopUndoTransaction(didChange: didChange)
        clearGradientOverlayStopEditingState()
        if !didChange { updateStatus() }
    }

    @discardableResult
    func cancelEditingSelectedLayerGradientOverlayCanvasStop() -> Bool {
        guard editingGradientOverlayStopLayerID != nil else { return false }
        let cancelled = cancelGradientOverlayStopUndoTransaction()
        clearGradientOverlayStopEditingState()
        if cancelled { updateStatus() }
        return cancelled
    }

    var hasActiveGradientOverlayMidpointTransaction: Bool {
        editingGradientOverlayMidpointLayerID != nil
    }

    @discardableResult
    func beginEditingSelectedLayerGradientOverlayCanvasMidpoint(
        after lowerStopIndex: Int
    ) -> Bool {
        guard editingGradientOverlayMidpointLayerID == nil,
              editingGradientOverlayCenterLayerID == nil,
              editingGradientOverlayAxisLayerID == nil,
              editingGradientOverlayStopLayerID == nil,
              canEditSelectedLayerGradientOverlayCanvasCenter,
              let layer = singleSelectedGradientOverlayCanvasLayer
        else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return false
        }
        let stops = layer.style.resolvedGradientOverlayColorStops
        guard lowerStopIndex >= 0, lowerStopIndex < stops.count - 1 else { return false }
        beginGradientOverlayMidpointUndoTransaction()
        editingGradientOverlayMidpointLayerID = layer.id
        editingGradientOverlayMidpointLowerStopIndex = lowerStopIndex
        editingGradientOverlayMidpointOriginalStops = stops
        return true
    }

    func updateSelectedLayerGradientOverlayCanvasMidpoint(to canvasPoint: CGPoint) {
        guard let layerID = editingGradientOverlayMidpointLayerID,
              let lowerStopIndex = editingGradientOverlayMidpointLowerStopIndex,
              let originalStops = editingGradientOverlayMidpointOriginalStops,
              let index = document.layers.firstIndex(where: { $0.id == layerID }),
              let midpoint = logicalGradientOverlayMidpoint(
                  after: lowerStopIndex,
                  layer: document.layers[index],
                  stops: originalStops,
                  canvasPoint: canvasPoint
              )
        else { return }
        let stops = ImageEditorGradientOverlayStopDraftEditing.movingMidpoint(
            originalStops,
            after: lowerStopIndex,
            to: midpoint
        )
        guard stops != document.layers[index].style.resolvedGradientOverlayColorStops else {
            return
        }
        document.layers[index].style.setGradientOverlayColorStops(stops)
        statusText = L10n.text("imageEditor.status.gradientOverlayMidpointMoved")
    }

    func finishEditingSelectedLayerGradientOverlayCanvasMidpoint() {
        guard let layerID = editingGradientOverlayMidpointLayerID else { return }
        let currentStops = document.layers.first(where: { $0.id == layerID })?
            .style.resolvedGradientOverlayColorStops
        let didChange = !gradientOverlayStopsMatch(
            currentStops,
            editingGradientOverlayMidpointOriginalStops
        )
        if didChange {
            appendHistory(L10n.text("imageEditor.history.gradientOverlayMidpoint"))
        }
        finishGradientOverlayMidpointUndoTransaction(didChange: didChange)
        clearGradientOverlayMidpointEditingState()
        if !didChange { updateStatus() }
    }

    @discardableResult
    func cancelEditingSelectedLayerGradientOverlayCanvasMidpoint() -> Bool {
        guard editingGradientOverlayMidpointLayerID != nil else { return false }
        let cancelled = cancelGradientOverlayMidpointUndoTransaction()
        clearGradientOverlayMidpointEditingState()
        if cancelled { updateStatus() }
        return cancelled
    }

    @discardableResult
    func addSelectedLayerGradientOverlayCanvasStop(at canvasPoint: CGPoint) -> Int? {
        guard editingGradientOverlayCenterLayerID == nil,
              editingGradientOverlayAxisLayerID == nil,
              editingGradientOverlayStopLayerID == nil,
              editingGradientOverlayMidpointLayerID == nil,
              canEditSelectedLayerGradientOverlayCanvasCenter,
              let layer = singleSelectedGradientOverlayCanvasLayer,
              let layerIndex = document.layers.firstIndex(where: { $0.id == layer.id }),
              let position = logicalGradientOverlayStopPosition(
                  layer: layer,
                  canvasPoint: canvasPoint
              )
        else { return nil }
        var stops = layer.style.resolvedGradientOverlayColorStops
        guard stops.count < ImageEditorGradientFillContent.maximumColorStopCount else {
            return nil
        }
        let insertionIndex = stops.firstIndex { position < $0.position } ?? stops.count - 1
        guard insertionIndex > 0, insertionIndex < stops.count else { return nil }
        let lowerBound = stops[insertionIndex - 1].position
            + ImageEditorGradientOverlayStopDraftEditing.minimumStopSpacing
        let upperBound = stops[insertionIndex].position
            - ImageEditorGradientOverlayStopDraftEditing.minimumStopSpacing
        guard lowerBound <= upperBound else { return nil }
        let resolvedPosition = max(lowerBound, min(upperBound, position))
        let gradient = ImageEditorGradientFillContent.shapeLinear(colorStops: stops)
        stops.insert(
            ImageEditorGradientColorStop(
                position: resolvedPosition,
                color: gradient.shapeColor(at: resolvedPosition)
            ),
            at: insertionIndex
        )
        beginGradientOverlayStopUndoTransaction()
        document.layers[layerIndex].style.setGradientOverlayColorStops(stops)
        appendHistory(L10n.text("imageEditor.history.gradientOverlayStopAdded"))
        finishGradientOverlayStopUndoTransaction(didChange: true)
        return insertionIndex
    }

    @discardableResult
    func removeSelectedLayerGradientOverlayCanvasStop(
        at stopIndex: Int
    ) -> ImageEditorGradientOverlayStopRemovalResult? {
        guard editingGradientOverlayCenterLayerID == nil,
              editingGradientOverlayAxisLayerID == nil,
              editingGradientOverlayStopLayerID == nil,
              editingGradientOverlayMidpointLayerID == nil,
              canEditSelectedLayerGradientOverlayCanvasCenter,
              let layer = singleSelectedGradientOverlayCanvasLayer,
              let layerIndex = document.layers.firstIndex(where: { $0.id == layer.id })
        else { return nil }
        var stops = layer.style.resolvedGradientOverlayColorStops
        guard stops.count > 2,
              stopIndex > 0,
              stopIndex < stops.count - 1
        else { return nil }
        stops.remove(at: stopIndex)
        beginGradientOverlayStopUndoTransaction()
        document.layers[layerIndex].style.setGradientOverlayColorStops(stops)
        appendHistory(L10n.text("imageEditor.history.gradientOverlayStopRemoved"))
        finishGradientOverlayStopUndoTransaction(didChange: true)
        let nextSelectedIndex = stops.count > 2
            ? min(stopIndex, stops.count - 2)
            : nil
        return ImageEditorGradientOverlayStopRemovalResult(
            removedIndex: stopIndex,
            nextSelectedIndex: nextSelectedIndex
        )
    }

    @discardableResult
    func nudgeSelectedLayerGradientOverlayCanvasStop(
        at stopIndex: Int,
        displayedDelta: Double
    ) -> Bool {
        guard displayedDelta.isFinite,
              displayedDelta != 0,
              editingGradientOverlayCenterLayerID == nil,
              editingGradientOverlayAxisLayerID == nil,
              editingGradientOverlayStopLayerID == nil,
              editingGradientOverlayMidpointLayerID == nil,
              canEditSelectedLayerGradientOverlayCanvasCenter,
              let layer = singleSelectedGradientOverlayCanvasLayer,
              let layerIndex = document.layers.firstIndex(where: { $0.id == layer.id })
        else { return false }
        let stops = layer.style.resolvedGradientOverlayColorStops
        guard stopIndex > 0, stopIndex < stops.count - 1 else { return false }
        let logicalDelta = layer.style.gradientOverlayReverse
            ? -displayedDelta
            : displayedDelta
        let movedStops = ImageEditorGradientOverlayStopDraftEditing.movingStop(
            stops,
            at: stopIndex,
            to: stops[stopIndex].position + logicalDelta
        )
        guard !gradientOverlayStopsMatch(movedStops, stops) else { return false }
        beginGradientOverlayStopUndoTransaction()
        document.layers[layerIndex].style.setGradientOverlayColorStops(movedStops)
        appendHistory(L10n.text("imageEditor.history.gradientOverlayStopNudged"))
        finishGradientOverlayStopUndoTransaction(didChange: true)
        return true
    }

    @discardableResult
    func nudgeSelectedLayerGradientOverlayCanvasMidpoint(
        after lowerStopIndex: Int,
        displayedDelta: Double
    ) -> Bool {
        guard displayedDelta.isFinite,
              displayedDelta != 0,
              editingGradientOverlayCenterLayerID == nil,
              editingGradientOverlayAxisLayerID == nil,
              editingGradientOverlayStopLayerID == nil,
              editingGradientOverlayMidpointLayerID == nil,
              canEditSelectedLayerGradientOverlayCanvasCenter,
              let layer = singleSelectedGradientOverlayCanvasLayer,
              let layerIndex = document.layers.firstIndex(where: { $0.id == layer.id })
        else { return false }
        let stops = layer.style.resolvedGradientOverlayColorStops
        guard lowerStopIndex >= 0, lowerStopIndex < stops.count - 1 else { return false }
        let lower = stops[lowerStopIndex]
        let upper = stops[lowerStopIndex + 1]
        let span = upper.position - lower.position
        guard span > 0 else { return false }
        let logicalDelta = layer.style.gradientOverlayReverse
            ? -displayedDelta
            : displayedDelta
        let movedStops = ImageEditorGradientOverlayStopDraftEditing.movingMidpoint(
            stops,
            after: lowerStopIndex,
            to: lower.midpoint + logicalDelta / span
        )
        guard !gradientOverlayStopsMatch(movedStops, stops) else { return false }
        beginGradientOverlayMidpointUndoTransaction()
        document.layers[layerIndex].style.setGradientOverlayColorStops(movedStops)
        appendHistory(L10n.text("imageEditor.history.gradientOverlayMidpointNudged"))
        finishGradientOverlayMidpointUndoTransaction(didChange: true)
        return true
    }

    @discardableResult
    func resetSelectedLayerGradientOverlayCanvasMidpoint(
        after lowerStopIndex: Int
    ) -> Bool {
        guard editingGradientOverlayCenterLayerID == nil,
              editingGradientOverlayAxisLayerID == nil,
              editingGradientOverlayStopLayerID == nil,
              editingGradientOverlayMidpointLayerID == nil,
              canEditSelectedLayerGradientOverlayCanvasCenter,
              let layer = singleSelectedGradientOverlayCanvasLayer,
              let layerIndex = document.layers.firstIndex(where: { $0.id == layer.id })
        else { return false }
        let stops = layer.style.resolvedGradientOverlayColorStops
        guard lowerStopIndex >= 0, lowerStopIndex < stops.count - 1 else { return false }
        let resetStops = ImageEditorGradientOverlayStopDraftEditing.movingMidpoint(
            stops,
            after: lowerStopIndex,
            to: 0.5
        )
        guard !gradientOverlayStopsMatch(resetStops, stops) else { return false }
        beginGradientOverlayMidpointUndoTransaction()
        document.layers[layerIndex].style.setGradientOverlayColorStops(resetStops)
        appendHistory(L10n.text("imageEditor.history.gradientOverlayMidpointReset"))
        finishGradientOverlayMidpointUndoTransaction(didChange: true)
        return true
    }

    private var singleSelectedGradientOverlayCanvasLayer: ImageEditorLayer? {
        let selectedIDs = document.selectedLayerIDs.isEmpty
            ? Set(document.selectedLayerID.map { [$0] } ?? [])
            : document.selectedLayerIDs
        guard selectedIDs.count == 1,
              let selectedID = selectedIDs.first,
              let layer = document.layers.first(where: { $0.id == selectedID }),
              !layer.isGroup,
              !layer.isAdjustment,
              !layer.isFilter,
              layer.style.effectsEnabled,
              layer.style.gradientOverlayEnabled,
              layer.shapeContent?.fillGradient == nil
        else { return nil }
        return layer
    }

    private func clearGradientOverlayCenterEditingState() {
        editingGradientOverlayCenterLayerID = nil
        editingGradientOverlayCenterOriginalPoint = nil
    }

    private func clearGradientOverlayAxisEditingState() {
        editingGradientOverlayAxisLayerID = nil
        editingGradientOverlayAxisOriginalAngle = nil
        editingGradientOverlayAxisOriginalScale = nil
    }

    private func clearGradientOverlayStopEditingState() {
        editingGradientOverlayStopLayerID = nil
        editingGradientOverlayStopIndex = nil
        editingGradientOverlayOriginalStops = nil
    }

    private func clearGradientOverlayMidpointEditingState() {
        editingGradientOverlayMidpointLayerID = nil
        editingGradientOverlayMidpointLowerStopIndex = nil
        editingGradientOverlayMidpointOriginalStops = nil
    }

    private func logicalGradientOverlayStopPosition(
        layer: ImageEditorLayer,
        canvasPoint: CGPoint
    ) -> Double? {
        ImageEditorGradientOverlayAxisGeometry.logicalStopPosition(
            style: layer.style.gradientOverlayStyle,
            center: layer.style.gradientOverlayCenter,
            angle: layer.style.gradientOverlayAngle,
            scale: layer.style.gradientOverlayScale,
            reverse: layer.style.gradientOverlayReverse,
            layerFrame: layer.frame,
            canvasPoint: canvasPoint
        )
    }

    private func logicalGradientOverlayMidpoint(
        after lowerStopIndex: Int,
        layer: ImageEditorLayer,
        stops: [ImageEditorGradientColorStop],
        canvasPoint: CGPoint
    ) -> Double? {
        ImageEditorGradientOverlayAxisGeometry.logicalMidpoint(
            after: lowerStopIndex,
            style: layer.style.gradientOverlayStyle,
            center: layer.style.gradientOverlayCenter,
            angle: layer.style.gradientOverlayAngle,
            scale: layer.style.gradientOverlayScale,
            reverse: layer.style.gradientOverlayReverse,
            stops: stops,
            layerFrame: layer.frame,
            canvasPoint: canvasPoint
        )
    }

    private func gradientOverlayStopsMatch(
        _ lhs: [ImageEditorGradientColorStop]?,
        _ rhs: [ImageEditorGradientColorStop]?,
        tolerance: Double = 0.000_001
    ) -> Bool {
        guard let lhs, let rhs else { return lhs == nil && rhs == nil }
        guard lhs.count == rhs.count else { return false }
        return zip(lhs, rhs).allSatisfy { left, right in
            abs(left.position - right.position) <= tolerance
                && abs(left.red - right.red) <= tolerance
                && abs(left.green - right.green) <= tolerance
                && abs(left.blue - right.blue) <= tolerance
                && abs(left.alpha - right.alpha) <= tolerance
                && abs(left.midpoint - right.midpoint) <= tolerance
        }
    }
}
