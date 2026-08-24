//
//  ImageEditorPathBoolean.swift
//  veilpic
//
//  Created by Codex on 2026/8/24.
//

import AppKit
import Foundation

extension ImageEditorShapeContent {
    var hasExplicitPathComponentOperations: Bool {
        !pathComponentOperations.isEmpty || pathStartsWithAllPixels
    }

    var resolvedPathComponentOperations: [ImageEditorPathComponentOperation] {
        let subpathCount = allEditablePathSubpaths.count
        return (0..<subpathCount).map { index in
            pathComponentOperations.indices.contains(index)
                ? pathComponentOperations[index]
                : .exclude
        }
    }

    func renderedPathComponentMask(size: CGSize, inverted: Bool) -> NSImage? {
        guard kind == .path,
              isPathClosed,
              editablePathAnchors.count >= 3,
              size.width > 0,
              size.height > 0
        else { return nil }

        let groups = pathComponentGroups()
        guard !groups.isEmpty else { return nil }
        guard let normalMask = NSImage.rendered(size: size, actions: { rect in
            NSGraphicsContext.current?.withImageEditorTopLeftCoordinates(height: size.height) {
                if pathStartsWithAllPixels {
                    NSColor.white.setFill()
                    rect.fill()
                }
                for (index, group) in groups.enumerated() {
                    if index == 0,
                       !pathStartsWithAllPixels,
                       group.operation == .subtract || group.operation == .intersect {
                        NSColor.white.setFill()
                        rect.fill()
                    }
                    let path = NSBezierPath()
                    path.windingRule = .evenOdd
                    for anchors in group.subpaths {
                        appendBooleanSubpath(anchors, to: path)
                    }
                    guard let context = NSGraphicsContext.current?.cgContext else { continue }
                    context.saveGState()
                    NSColor.white.setFill()
                    if group.operation == .intersect {
                        let outsidePath = NSBezierPath(rect: rect)
                        outsidePath.append(path)
                        outsidePath.windingRule = .evenOdd
                        context.setBlendMode(.clear)
                        outsidePath.fill()
                    } else {
                        context.setBlendMode(group.operation.cgBlendMode)
                        path.fill()
                    }
                    context.restoreGState()
                }
            }
        }) else { return nil }

        guard inverted else { return normalMask }
        return NSImage.rendered(size: size) { rect in
            NSColor.white.setFill()
            rect.fill()
            normalMask.draw(
                in: rect,
                from: .zero,
                operation: .destinationOut,
                fraction: 1,
                respectFlipped: true,
                hints: nil
            )
        }
    }

    private func pathComponentGroups() -> [ImageEditorPathComponentGroup] {
        let subpaths = allEditablePathSubpaths
        guard !subpaths.isEmpty else { return [] }
        let operations = resolvedPathComponentOperations
        var groups: [ImageEditorPathComponentGroup] = []
        for (index, subpath) in subpaths.enumerated() {
            let operation = operations[index]
            if operation == .continuePrevious, !groups.isEmpty {
                groups[groups.count - 1].subpaths.append(subpath)
            } else {
                groups.append(
                    ImageEditorPathComponentGroup(
                        operation: operation == .continuePrevious ? .exclude : operation,
                        subpaths: [subpath]
                    )
                )
            }
        }
        return groups
    }

    private func appendBooleanSubpath(
        _ anchors: [ImageEditorPathAnchor],
        to path: NSBezierPath
    ) {
        guard let first = anchors.first else { return }
        path.move(to: first.point)
        for index in anchors.indices.dropFirst() {
            let previous = anchors[index - 1]
            let current = anchors[index]
            if previous.outControl != nil || current.inControl != nil {
                path.curve(
                    to: current.point,
                    controlPoint1: previous.outControl ?? previous.point,
                    controlPoint2: current.inControl ?? current.point
                )
            } else {
                path.line(to: current.point)
            }
        }
        let last = anchors[anchors.count - 1]
        if last.outControl != nil || first.inControl != nil {
            path.curve(
                to: first.point,
                controlPoint1: last.outControl ?? last.point,
                controlPoint2: first.inControl ?? first.point
            )
        }
        path.close()
    }
}

private struct ImageEditorPathComponentGroup {
    var operation: ImageEditorPathComponentOperation
    var subpaths: [[ImageEditorPathAnchor]]
}

private extension ImageEditorPathComponentOperation {
    var cgBlendMode: CGBlendMode {
        switch self {
        case .exclude, .continuePrevious:
            .xor
        case .combine:
            .normal
        case .subtract:
            .destinationOut
        case .intersect:
            .destinationIn
        }
    }
}
