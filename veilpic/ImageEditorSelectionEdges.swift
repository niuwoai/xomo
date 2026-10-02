//
//  ImageEditorSelectionEdges.swift
//  veilpic
//
//  Created by Codex on 2026/7/12.
//

import AppKit
import CoreGraphics
import Foundation

struct ImageEditorSelectionEdgeSegment: Equatable {
    var start: CGPoint
    var end: CGPoint
}

enum ImageEditorMarqueeDragIntent: Equatable {
    case createSelection
    case moveExistingSelection

    static func resolve(
        selectionContainsPointer: Bool,
        selectionMode: ImageEditorSelectionMode,
        modifierFlags: NSEvent.ModifierFlags
    ) -> Self {
        let selectionModifiers = modifierFlags.intersection([.shift, .option])
        guard selectionContainsPointer,
              selectionMode == .replace,
              selectionModifiers.isEmpty
        else { return .createSelection }
        return .moveExistingSelection
    }
}

enum ImageEditorMarqueeMoveConstraint {
    static func delta(
        from start: CGPoint,
        to end: CGPoint,
        modifierFlags: NSEvent.ModifierFlags
    ) -> CGSize {
        let proposed = CGSize(width: end.x - start.x, height: end.y - start.y)
        guard modifierFlags.contains(.shift) else { return proposed }
        if abs(proposed.width) >= abs(proposed.height) {
            return CGSize(width: proposed.width, height: 0)
        }
        return CGSize(width: 0, height: proposed.height)
    }
}

struct ImageEditorSelectionEdgeGeometry: Equatable {
    var contours: [[CGPoint]]

    func offsetBy(dx: CGFloat, dy: CGFloat) -> ImageEditorSelectionEdgeGeometry {
        ImageEditorSelectionEdgeGeometry(
            contours: contours.map { contour in
                contour.map { CGPoint(x: $0.x + dx, y: $0.y + dy) }
            }
        )
    }

    var segments: [ImageEditorSelectionEdgeSegment] {
        contours.flatMap { contour in
            zip(contour, contour.dropFirst()).map {
                ImageEditorSelectionEdgeSegment(start: $0.0, end: $0.1)
            }
        }
    }

    static func make(selection: ImageEditorSelection, canvasSize: CGSize) -> ImageEditorSelectionEdgeGeometry {
        guard let mask = selection.rasterMask,
              mask.width > 0,
              mask.height > 0,
              mask.alpha.count == mask.width * mask.height
        else {
            return vectorGeometry(selection: selection, canvasSize: canvasSize)
        }

        return rasterGeometry(
            mask: mask,
            isInverted: selection.isInverted,
            canvasSize: canvasSize
        )
    }

    private static func vectorGeometry(
        selection: ImageEditorSelection,
        canvasSize: CGSize
    ) -> ImageEditorSelectionEdgeGeometry {
        guard selection.points.count > 1 else { return ImageEditorSelectionEdgeGeometry(contours: []) }
        var contour = selection.points
        if selection.isPolygon || selection.points.count == 4,
           let first = selection.points.first,
           selection.points.last != first {
            contour.append(first)
        }
        var contours = [contour]
        if selection.isInverted {
            contours.insert([
                .zero,
                CGPoint(x: canvasSize.width, y: 0),
                CGPoint(x: canvasSize.width, y: canvasSize.height),
                CGPoint(x: 0, y: canvasSize.height),
                .zero
            ], at: 0)
        }
        return ImageEditorSelectionEdgeGeometry(contours: contours)
    }

    private static func rasterGeometry(
        mask: ImageEditorSelectionMask,
        isInverted: Bool,
        canvasSize: CGSize
    ) -> ImageEditorSelectionEdgeGeometry {
        struct GridPoint: Hashable {
            var x: Int
            var y: Int
        }

        let scaleX = canvasSize.width / CGFloat(mask.width)
        let scaleY = canvasSize.height / CGFloat(mask.height)
        var outgoingEdges: [GridPoint: [GridPoint]] = [:]

        func isSelected(x: Int, y: Int) -> Bool {
            guard x >= 0, y >= 0, x < mask.width, y < mask.height else { return false }
            let selected = mask.alpha[y * mask.width + x] >= 128
            return isInverted ? !selected : selected
        }

        func appendEdge(from start: GridPoint, to end: GridPoint) {
            outgoingEdges[start, default: []].append(end)
        }

        func direction(from start: GridPoint, to end: GridPoint) -> Int {
            if end.x > start.x { return 0 }
            if end.y > start.y { return 1 }
            if end.x < start.x { return 2 }
            return 3
        }

        func turnRank(from incoming: Int, to outgoing: Int) -> Int {
            switch (outgoing - incoming + 4) % 4 {
            case 1: return 0
            case 0: return 1
            case 3: return 2
            default: return 3
            }
        }

        for y in 0..<mask.height {
            for x in 0..<mask.width where isSelected(x: x, y: y) {
                if !isSelected(x: x, y: y - 1) {
                    appendEdge(from: GridPoint(x: x, y: y), to: GridPoint(x: x + 1, y: y))
                }
                if !isSelected(x: x + 1, y: y) {
                    appendEdge(from: GridPoint(x: x + 1, y: y), to: GridPoint(x: x + 1, y: y + 1))
                }
                if !isSelected(x: x, y: y + 1) {
                    appendEdge(from: GridPoint(x: x + 1, y: y + 1), to: GridPoint(x: x, y: y + 1))
                }
                if !isSelected(x: x - 1, y: y) {
                    appendEdge(from: GridPoint(x: x, y: y + 1), to: GridPoint(x: x, y: y))
                }
            }
        }

        var contours: [[CGPoint]] = []
        while let start = outgoingEdges.keys.first {
            var gridContour = [start]
            var previous: GridPoint?
            var current = start
            repeat {
                guard var candidates = outgoingEdges[current], !candidates.isEmpty else { break }
                let nextIndex: Int
                if let previous {
                    let incomingDirection = direction(from: previous, to: current)
                    nextIndex = candidates.indices.min { left, right in
                        turnRank(
                            from: incomingDirection,
                            to: direction(from: current, to: candidates[left])
                        ) < turnRank(
                            from: incomingDirection,
                            to: direction(from: current, to: candidates[right])
                        )
                    } ?? candidates.startIndex
                } else {
                    nextIndex = candidates.startIndex
                }
                let next = candidates.remove(at: nextIndex)
                if candidates.isEmpty {
                    outgoingEdges.removeValue(forKey: current)
                } else {
                    outgoingEdges[current] = candidates
                }
                gridContour.append(next)
                previous = current
                current = next
            } while current != start

            let simplified = simplifiedClosedContour(gridContour) { ($0.x, $0.y) }
            contours.append(simplified.map {
                CGPoint(x: CGFloat($0.x) * scaleX, y: CGFloat($0.y) * scaleY)
            })
        }

        return ImageEditorSelectionEdgeGeometry(contours: contours)
    }

    private static func simplifiedClosedContour<Point: Equatable>(
        _ points: [Point],
        coordinate: (Point) -> (Int, Int)
    ) -> [Point] {
        guard points.count > 3, points.first == points.last else { return points }
        let openPoints = Array(points.dropLast())
        guard let cornerIndex = openPoints.indices.first(where: { index in
            let previous = coordinate(openPoints[(index - 1 + openPoints.count) % openPoints.count])
            let current = coordinate(openPoints[index])
            let next = coordinate(openPoints[(index + 1) % openPoints.count])
            let incoming = (current.0 - previous.0, current.1 - previous.1)
            let outgoing = (next.0 - current.0, next.1 - current.1)
            return incoming != outgoing
        }) else { return points }

        let rotated = Array(openPoints[cornerIndex...]) + Array(openPoints[..<cornerIndex])
        let closed = rotated + [rotated[0]]
        var simplified = [closed[0]]
        for index in 1..<(closed.count - 1) {
            let previous = coordinate(closed[index - 1])
            let current = coordinate(closed[index])
            let next = coordinate(closed[index + 1])
            let incoming = (current.0 - previous.0, current.1 - previous.1)
            let outgoing = (next.0 - current.0, next.1 - current.1)
            if incoming != outgoing { simplified.append(closed[index]) }
        }
        simplified.append(closed[closed.count - 1])
        return simplified
    }
}

/// A non-destructive canvas guide for the Patch tool's two transfer modes.
/// The selected contour stays at its real document position while its offset
/// counterpart and the arrow make the pixel flow explicit before commit.
struct ImageEditorPatchTransferGuide: Equatable {
    var sourceEdges: ImageEditorSelectionEdgeGeometry
    var targetEdges: ImageEditorSelectionEdgeGeometry
    var sourceAnchor: CGPoint
    var targetAnchor: CGPoint

    static func make(
        selectionEdges: ImageEditorSelectionEdgeGeometry,
        selectionBounds: CGRect,
        dragStart: CGPoint,
        dragEnd: CGPoint,
        mode: ImageEditorPatchMode
    ) -> ImageEditorPatchTransferGuide? {
        guard selectionBounds.width.isFinite,
              selectionBounds.height.isFinite,
              selectionBounds.midX.isFinite,
              selectionBounds.midY.isFinite,
              dragStart.x.isFinite,
              dragStart.y.isFinite,
              dragEnd.x.isFinite,
              dragEnd.y.isFinite
        else { return nil }

        let deltaX = dragEnd.x - dragStart.x
        let deltaY = dragEnd.y - dragStart.y
        let selectedAnchor = CGPoint(x: selectionBounds.midX, y: selectionBounds.midY)
        let offsetAnchor = CGPoint(
            x: selectedAnchor.x + deltaX,
            y: selectedAnchor.y + deltaY
        )
        let offsetEdges = selectionEdges.offsetBy(dx: deltaX, dy: deltaY)

        switch mode {
        case .source:
            return ImageEditorPatchTransferGuide(
                sourceEdges: offsetEdges,
                targetEdges: selectionEdges,
                sourceAnchor: offsetAnchor,
                targetAnchor: selectedAnchor
            )
        case .destination:
            return ImageEditorPatchTransferGuide(
                sourceEdges: selectionEdges,
                targetEdges: offsetEdges,
                sourceAnchor: selectedAnchor,
                targetAnchor: offsetAnchor
            )
        }
    }
}

struct ImageEditorPatchDragConstraintResult: Equatable {
    var endPoint: CGPoint
    var axis: ImageEditorObjectDragAxis?
}

enum ImageEditorPatchDragConstraint {
    static func resolve(
        start: CGPoint,
        proposedEnd: CGPoint,
        existingAxis: ImageEditorObjectDragAxis?,
        isConstrained: Bool
    ) -> ImageEditorPatchDragConstraintResult {
        let translation = CGSize(
            width: proposedEnd.x - start.x,
            height: proposedEnd.y - start.y
        )
        let axis = ImageEditorObjectDragConstraint.resolvedAxis(
            for: translation,
            existingAxis: existingAxis,
            isConstrained: isConstrained
        )
        let constrainedTranslation = ImageEditorObjectDragConstraint.constrainedDelta(
            translation,
            to: axis
        )
        let snappedTranslation = ImageEditorPatchPixelGrid.snappedDelta(
            constrainedTranslation
        )
        return ImageEditorPatchDragConstraintResult(
            endPoint: CGPoint(
                x: start.x + snappedTranslation.width,
                y: start.y + snappedTranslation.height
            ),
            axis: axis
        )
    }
}

/// Patch sampling ultimately addresses raster pixels. Resolve the pointer's
/// canvas-space displacement onto whole pixels before preview, guides, HUD,
/// and commit consume it so the displayed transfer never promises a
/// fractional movement that the pixel compositor must round differently.
enum ImageEditorPatchPixelGrid {
    static func snappedDelta(_ delta: CGSize) -> CGSize {
        let width = delta.width.rounded()
        let height = delta.height.rounded()
        return CGSize(
            width: width == 0 ? 0 : width,
            height: height == 0 ? 0 : height
        )
    }
}
