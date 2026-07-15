//
//  ImageEditorShapeStyle.swift
//  veilpic
//
//  Created by Codex on 2026/7/15.
//

import AppKit
import Foundation

enum ImageEditorShapeFillKind: String, CaseIterable, Identifiable {
    case solid
    case linearGradient
    case radialGradient

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.properties.shapeFillKind.\(rawValue)")
    }
}

extension ImageEditorGradientFillContent {
    static func shapeLinear(
        startColor: NSColor,
        endColor: NSColor,
        angle: CGFloat = 0,
        scale: CGFloat = 1
    ) -> ImageEditorGradientFillContent {
        let start = rgbComponents(startColor)
        let end = rgbComponents(endColor)
        return ImageEditorGradientFillContent(
            preset: .custom,
            style: .linear,
            angle: angle,
            scale: scale,
            startRed: start.red,
            startGreen: start.green,
            startBlue: start.blue,
            endRed: end.red,
            endGreen: end.green,
            endBlue: end.blue,
            colorStops: [
                ImageEditorGradientColorStop(position: 0, color: startColor),
                ImageEditorGradientColorStop(position: 1, color: endColor)
            ]
        ).normalized()
    }

    static func shapeLinear(
        colorStops: [ImageEditorGradientColorStop],
        angle: CGFloat = 0,
        scale: CGFloat = 1
    ) -> ImageEditorGradientFillContent {
        let stops = colorStops.count >= 2 ? colorStops : [
            ImageEditorGradientColorStop(position: 0, color: .black),
            ImageEditorGradientColorStop(position: 1, color: .white)
        ]
        let first = stops.first?.normalized() ?? ImageEditorGradientColorStop(position: 0, color: .black)
        let last = stops.last?.normalized() ?? ImageEditorGradientColorStop(position: 1, color: .white)
        return ImageEditorGradientFillContent(
            preset: .custom,
            style: .linear,
            angle: angle,
            scale: scale,
            startRed: first.red,
            startGreen: first.green,
            startBlue: first.blue,
            endRed: last.red,
            endGreen: last.green,
            endBlue: last.blue,
            colorStops: stops
        ).normalized()
    }

    var shapeColorStops: [ImageEditorGradientColorStop] {
        let content = normalized()
        if let stops = content.colorStops { return stops }
        let colors = content.colors()
        return [
            ImageEditorGradientColorStop(
                position: 0,
                red: colors.start.x,
                green: colors.start.y,
                blue: colors.start.z
            ),
            ImageEditorGradientColorStop(
                position: 1,
                red: colors.end.x,
                green: colors.end.y,
                blue: colors.end.z
            )
        ]
    }

    func shapeColor(at position: Double) -> NSColor {
        let stops = shapeColorStops
        let value = max(0, min(1, position))
        guard let first = stops.first, let last = stops.last else { return .black }
        if value <= first.position { return first.color }
        if value >= last.position { return last.color }
        for index in 1..<stops.count {
            let upper = stops[index]
            guard value <= upper.position else { continue }
            let lower = stops[index - 1]
            let distance = upper.position - lower.position
            guard distance > 0.000_001 else { return upper.color }
            let amount = (value - lower.position) / distance
            let vector = lower.vector + (upper.vector - lower.vector) * amount
            return NSColor(deviceRed: vector.x, green: vector.y, blue: vector.z, alpha: 1)
        }
        return last.color
    }

    var shapeStartColor: NSColor {
        shapeColorStops.first?.color ?? .black
    }

    var shapeEndColor: NSColor {
        shapeColorStops.last?.color ?? .white
    }

    private static func rgbComponents(_ color: NSColor) -> (red: Double, green: Double, blue: Double) {
        let resolved = color.usingColorSpace(.deviceRGB) ?? color
        return (
            Double(resolved.redComponent),
            Double(resolved.greenComponent),
            Double(resolved.blueComponent)
        )
    }
}

@MainActor
extension ImageEditorViewModel {
    var selectedShapeFillKind: ImageEditorShapeFillKind {
        guard let gradient = document.selectedLayer?.shapeContent?.fillGradient else {
            return .solid
        }
        return gradient.style == .radial ? .radialGradient : .linearGradient
    }

    var selectedShapeFillColor: NSColor {
        document.selectedLayer?.shapeContent?.fillColor ?? .clear
    }

    var selectedShapeGradientStartColor: NSColor {
        selectedShapeGradient.shapeStartColor
    }

    var selectedShapeGradientEndColor: NSColor {
        selectedShapeGradient.shapeEndColor
    }

    var selectedShapeGradientAngle: Double {
        Double(selectedShapeGradient.angle)
    }

    var selectedShapeGradientScale: Double {
        Double(selectedShapeGradient.scale)
    }

    var selectedShapeGradientColorStops: [ImageEditorGradientColorStop] {
        selectedShapeGradient.shapeColorStops
    }

    var selectedShapeFillOpacity: Double {
        Double(document.selectedLayer?.shapeContent?.fillOpacity ?? 0)
    }

    var selectedShapeStrokeColor: NSColor {
        document.selectedLayer?.shapeContent?.strokeColor ?? .clear
    }

    var selectedShapeStrokeOpacity: Double {
        Double(document.selectedLayer?.shapeContent?.strokeOpacity ?? 0)
    }

    var selectedShapeStrokeWidth: Double {
        Double(document.selectedLayer?.shapeContent?.strokeWidth ?? 1)
    }

    func setSelectedShapeFillColor(_ color: NSColor) {
        updateSelectedShapeProperties(fillColor: color)
    }

    func setSelectedShapeFillKind(_ kind: ImageEditorShapeFillKind) {
        switch kind {
        case .solid:
            updateSelectedShapeProperties(clearsFillGradient: true)
        case .linearGradient:
            var gradient = selectedShapeGradient
            gradient.style = .linear
            updateSelectedShapeProperties(fillGradient: gradient)
        case .radialGradient:
            var gradient = selectedShapeGradient
            gradient.style = .radial
            updateSelectedShapeProperties(fillGradient: gradient)
        }
    }

    func setSelectedShapeGradientStartColor(_ color: NSColor) {
        setSelectedShapeGradientStopColor(at: 0, color: color)
    }

    func setSelectedShapeGradientEndColor(_ color: NSColor) {
        let index = max(0, selectedShapeGradientColorStops.count - 1)
        setSelectedShapeGradientStopColor(at: index, color: color)
    }

    func setSelectedShapeGradientStopColor(at index: Int, color: NSColor) {
        var gradient = selectedShapeGradient
        var stops = gradient.shapeColorStops
        guard stops.indices.contains(index) else { return }
        stops[index] = ImageEditorGradientColorStop(position: stops[index].position, color: color)
        gradient.colorStops = stops
        updateSelectedShapeProperties(fillGradient: gradient)
    }

    func setSelectedShapeGradientStopPosition(at index: Int, position: Double) {
        guard position.isFinite else { return }
        var gradient = selectedShapeGradient
        var stops = gradient.shapeColorStops
        guard stops.indices.contains(index), index > 0, index < stops.count - 1 else { return }
        let lowerBound = stops[index - 1].position + 0.01
        let upperBound = stops[index + 1].position - 0.01
        guard lowerBound <= upperBound else { return }
        stops[index].position = max(lowerBound, min(upperBound, position))
        gradient.colorStops = stops
        updateSelectedShapeProperties(fillGradient: gradient)
    }

    @discardableResult
    func addSelectedShapeGradientStop() -> Int? {
        let stops = selectedShapeGradient.shapeColorStops
        guard stops.count < ImageEditorGradientFillContent.maximumColorStopCount else { return nil }
        let gap = stops.indices.dropLast().max { lhs, rhs in
            (stops[lhs + 1].position - stops[lhs].position)
                < (stops[rhs + 1].position - stops[rhs].position)
        } ?? 0
        let position = (stops[gap].position + stops[gap + 1].position) / 2
        return addSelectedShapeGradientStop(at: position)
    }

    @discardableResult
    func addSelectedShapeGradientStop(at position: Double) -> Int? {
        guard position.isFinite else { return nil }
        var gradient = selectedShapeGradient
        var stops = gradient.shapeColorStops
        guard stops.count < ImageEditorGradientFillContent.maximumColorStopCount else { return nil }
        let requestedPosition = max(0, min(1, position))
        let insertionIndex = stops.firstIndex { requestedPosition < $0.position } ?? stops.count - 1
        guard insertionIndex > 0, insertionIndex < stops.count else { return nil }
        let lowerBound = stops[insertionIndex - 1].position + 0.01
        let upperBound = stops[insertionIndex].position - 0.01
        guard lowerBound <= upperBound else { return nil }
        let resolvedPosition = max(lowerBound, min(upperBound, requestedPosition))
        stops.insert(
            ImageEditorGradientColorStop(
                position: resolvedPosition,
                color: gradient.shapeColor(at: resolvedPosition)
            ),
            at: insertionIndex
        )
        gradient.colorStops = stops
        updateSelectedShapeProperties(fillGradient: gradient)
        return insertionIndex
    }

    @discardableResult
    func removeSelectedShapeGradientStop(at index: Int) -> Int? {
        var gradient = selectedShapeGradient
        var stops = gradient.shapeColorStops
        guard stops.count > 2, index > 0, index < stops.count - 1 else { return nil }
        stops.remove(at: index)
        gradient.colorStops = stops
        updateSelectedShapeProperties(fillGradient: gradient)
        return min(index, stops.count - 1)
    }

    func setSelectedShapeGradientAngle(_ angle: Double) {
        guard angle.isFinite else { return }
        var gradient = selectedShapeGradient
        gradient.angle = CGFloat(max(-180, min(180, angle)))
        updateSelectedShapeProperties(fillGradient: gradient)
    }

    func setSelectedShapeGradientScale(_ scale: Double) {
        guard scale.isFinite else { return }
        var gradient = selectedShapeGradient
        gradient.scale = CGFloat(max(0.25, min(4, scale)))
        updateSelectedShapeProperties(fillGradient: gradient)
    }

    func setSelectedShapeFillOpacity(_ opacity: Double) {
        updateSelectedShapeProperties(fillOpacity: opacity)
    }

    func setSelectedShapeStrokeColor(_ color: NSColor) {
        updateSelectedShapeProperties(strokeColor: color)
    }

    func setSelectedShapeStrokeOpacity(_ opacity: Double) {
        updateSelectedShapeProperties(strokeOpacity: opacity)
    }

    func setSelectedShapeStrokeWidth(_ width: Double) {
        updateSelectedShapeProperties(strokeWidth: width)
    }

    func updateSelectedShapeProperties(
        fillColor: NSColor? = nil,
        fillGradient: ImageEditorGradientFillContent? = nil,
        fillGradientCenter: CGPoint? = nil,
        clearsFillGradient: Bool = false,
        fillOpacity: Double? = nil,
        strokeColor: NSColor? = nil,
        strokeOpacity: Double? = nil,
        strokeWidth: Double? = nil,
        cornerRadius: Double? = nil,
        cornerRadii: ImageEditorRectangleCornerRadii? = nil,
        cornerSmoothing: Double? = nil
    ) {
        let selectedIDs: Set<UUID>
        if document.selectedLayerIDs.isEmpty,
           let selectedLayerID = document.selectedLayerID {
            selectedIDs = [selectedLayerID]
        } else {
            selectedIDs = document.selectedLayerIDs
        }
        let indices = document.layers.indices.filter { index in
            let layer = document.layers[index]
            return selectedIDs.contains(layer.id)
                && layer.isShape
                && !document.isEffectivelyPixelsLocked(layer)
        }
        guard !indices.isEmpty else { return }

        var updates: [(index: Int, content: ImageEditorShapeContent)] = []
        for index in indices {
            guard var content = document.layers[index].shapeContent else { continue }
            let previous = content
            if let fillColor { content.fillColor = fillColor }
            if clearsFillGradient {
                content.fillGradient = nil
            } else if var fillGradient {
                if fillGradient.style != .radial {
                    fillGradient.style = .linear
                }
                content.fillGradient = fillGradient.normalized()
            }
            if let fillGradientCenter {
                content.fillGradientCenter = fillGradientCenter
            }
            if let fillOpacity, fillOpacity.isFinite {
                content.fillOpacity = CGFloat(max(0, min(1, fillOpacity)))
            }
            if let strokeColor { content.strokeColor = strokeColor }
            if let strokeOpacity, strokeOpacity.isFinite {
                content.strokeOpacity = CGFloat(max(0, min(1, strokeOpacity)))
            }
            if let strokeWidth, strokeWidth.isFinite {
                content.strokeWidth = CGFloat(max(1, min(96, strokeWidth)))
            }
            if content.kind == .rectangle,
               let cornerRadius,
               cornerRadius.isFinite {
                content.cornerRadius = CGFloat(max(0, cornerRadius))
                content.cornerRadii = nil
            } else if content.kind == .rectangle,
                      let cornerRadii {
                content.cornerRadii = cornerRadii
            }
            if content.kind == .rectangle,
               let cornerSmoothing,
               cornerSmoothing.isFinite {
                content.cornerSmoothing = CGFloat(max(0, min(1, cornerSmoothing)))
            }
            content = content.normalized(size: document.layers[index].image.size)
            guard !shapeAppearanceEqual(previous, content) else { continue }
            updates.append((index, content))
        }
        guard !updates.isEmpty else { return }

        pushUndo()
        for update in updates {
            document.layers[update.index].kind = .shape(update.content)
        }
        appendHistory(L10n.text("imageEditor.history.shapeStyle"))
        statusText = L10n.format("imageEditor.status.shapeStyle", updates.count)
    }

    private func shapeAppearanceEqual(
        _ lhs: ImageEditorShapeContent,
        _ rhs: ImageEditorShapeContent
    ) -> Bool {
        lhs.fillColor.isEqual(rhs.fillColor)
            && lhs.fillGradient == rhs.fillGradient
            && lhs.fillGradientCenter == rhs.fillGradientCenter
            && abs(lhs.fillOpacity - rhs.fillOpacity) <= 0.000_1
            && lhs.strokeColor.isEqual(rhs.strokeColor)
            && abs(lhs.strokeOpacity - rhs.strokeOpacity) <= 0.000_1
            && abs(lhs.strokeWidth - rhs.strokeWidth) <= 0.000_1
            && abs(lhs.cornerRadius - rhs.cornerRadius) <= 0.000_1
            && lhs.cornerRadii == rhs.cornerRadii
            && abs(lhs.cornerSmoothing - rhs.cornerSmoothing) <= 0.000_1
    }

    private var selectedShapeGradient: ImageEditorGradientFillContent {
        if let gradient = document.selectedLayer?.shapeContent?.fillGradient {
            return gradient.normalized()
        }
        return .shapeLinear(
            startColor: selectedShapeFillColor,
            endColor: backgroundColor
        )
    }
}
