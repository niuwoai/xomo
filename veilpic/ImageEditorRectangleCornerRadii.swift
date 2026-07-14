//
//  ImageEditorRectangleCornerRadii.swift
//  veilpic
//
//  Created by Codex on 2026/7/15.
//

import AppKit
import Foundation

enum ImageEditorRectangleCorner: String, CaseIterable, Identifiable, Sendable {
    case topLeft
    case topRight
    case bottomRight
    case bottomLeft

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.properties.shapeCorner.\(rawValue)")
    }
}

struct ImageEditorRectangleCornerRadii: Codable, Equatable, Sendable {
    var topLeft: CGFloat
    var topRight: CGFloat
    var bottomRight: CGFloat
    var bottomLeft: CGFloat

    static let zero = uniform(0)

    static func uniform(_ radius: CGFloat) -> Self {
        Self(
            topLeft: radius,
            topRight: radius,
            bottomRight: radius,
            bottomLeft: radius
        )
    }

    var isUniform: Bool {
        abs(topRight - topLeft) <= 0.001
            && abs(bottomRight - topLeft) <= 0.001
            && abs(bottomLeft - topLeft) <= 0.001
    }

    var hasRoundedCorner: Bool {
        topLeft > 0 || topRight > 0 || bottomRight > 0 || bottomLeft > 0
    }

    func radius(at corner: ImageEditorRectangleCorner) -> CGFloat {
        switch corner {
        case .topLeft: topLeft
        case .topRight: topRight
        case .bottomRight: bottomRight
        case .bottomLeft: bottomLeft
        }
    }

    mutating func setRadius(_ radius: CGFloat, at corner: ImageEditorRectangleCorner) {
        switch corner {
        case .topLeft: topLeft = radius
        case .topRight: topRight = radius
        case .bottomRight: bottomRight = radius
        case .bottomLeft: bottomLeft = radius
        }
    }

    func normalized(size: CGSize) -> Self {
        let maximum = max(0, min(size.width, size.height) / 2)
        return Self(
            topLeft: Self.clamped(topLeft, maximum: maximum),
            topRight: Self.clamped(topRight, maximum: maximum),
            bottomRight: Self.clamped(bottomRight, maximum: maximum),
            bottomLeft: Self.clamped(bottomLeft, maximum: maximum)
        )
    }

    func scaled(by scale: CGFloat) -> Self {
        Self(
            topLeft: max(0, topLeft * scale),
            topRight: max(0, topRight * scale),
            bottomRight: max(0, bottomRight * scale),
            bottomLeft: max(0, bottomLeft * scale)
        )
    }

    private static func clamped(_ radius: CGFloat, maximum: CGFloat) -> CGFloat {
        guard radius.isFinite else { return 0 }
        return min(maximum, max(0, radius))
    }
}

extension ImageEditorShapeContent {
    var effectiveCornerRadii: ImageEditorRectangleCornerRadii {
        cornerRadii ?? .uniform(cornerRadius)
    }

    func rectangleBezierPath(in rect: CGRect) -> NSBezierPath {
        let radii = effectiveCornerRadii.normalized(size: rect.size)
        guard radii.hasRoundedCorner else { return NSBezierPath(rect: rect) }

        let path = NSBezierPath()
        let kappa: CGFloat = 0.552_284_749_8

        path.move(to: CGPoint(x: rect.minX + radii.topLeft, y: rect.minY))
        path.line(to: CGPoint(x: rect.maxX - radii.topRight, y: rect.minY))
        path.curve(
            to: CGPoint(x: rect.maxX, y: rect.minY + radii.topRight),
            controlPoint1: CGPoint(
                x: rect.maxX - radii.topRight + radii.topRight * kappa,
                y: rect.minY
            ),
            controlPoint2: CGPoint(
                x: rect.maxX,
                y: rect.minY + radii.topRight - radii.topRight * kappa
            )
        )
        path.line(to: CGPoint(x: rect.maxX, y: rect.maxY - radii.bottomRight))
        path.curve(
            to: CGPoint(x: rect.maxX - radii.bottomRight, y: rect.maxY),
            controlPoint1: CGPoint(
                x: rect.maxX,
                y: rect.maxY - radii.bottomRight + radii.bottomRight * kappa
            ),
            controlPoint2: CGPoint(
                x: rect.maxX - radii.bottomRight + radii.bottomRight * kappa,
                y: rect.maxY
            )
        )
        path.line(to: CGPoint(x: rect.minX + radii.bottomLeft, y: rect.maxY))
        path.curve(
            to: CGPoint(x: rect.minX, y: rect.maxY - radii.bottomLeft),
            controlPoint1: CGPoint(
                x: rect.minX + radii.bottomLeft - radii.bottomLeft * kappa,
                y: rect.maxY
            ),
            controlPoint2: CGPoint(
                x: rect.minX,
                y: rect.maxY - radii.bottomLeft + radii.bottomLeft * kappa
            )
        )
        path.line(to: CGPoint(x: rect.minX, y: rect.minY + radii.topLeft))
        path.curve(
            to: CGPoint(x: rect.minX + radii.topLeft, y: rect.minY),
            controlPoint1: CGPoint(
                x: rect.minX,
                y: rect.minY + radii.topLeft - radii.topLeft * kappa
            ),
            controlPoint2: CGPoint(
                x: rect.minX + radii.topLeft - radii.topLeft * kappa,
                y: rect.minY
            )
        )
        path.close()
        return path
    }
}
