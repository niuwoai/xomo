//
//  ImageEditorTransformHUD.swift
//  veilpic
//
//  Created by Codex on 2026/7/18.
//

import CoreGraphics
import Foundation

enum ImageEditorTransformHUDMode: Equatable {
    case move(delta: CGSize?)
    case resize(scalePercent: CGSize?)
    case rotate(degrees: CGFloat)
    case patchTransfer(delta: CGSize, constrainedAxis: ImageEditorObjectDragAxis?)
}

/// Pure presentation geometry for the lightweight transform readout shown by
/// Photoshop, Sketch and Figma-style object workflows. Keeping the math out of
/// SwiftUI makes the pointer-hot path deterministic and inexpensive to test.
enum ImageEditorTransformHUD {
    private static let badgeHeight: CGFloat = 24
    private static let characterWidth: CGFloat = 6.2
    private static let horizontalPadding: CGFloat = 16
    private static let minimumBadgeWidth: CGFloat = 88
    private static let maximumBadgeWidth: CGFloat = 220
    private static let selectionGap: CGFloat = 8
    private static let viewportMargin: CGFloat = 6

    static func displayText(frame: CGRect, mode: ImageEditorTransformHUDMode) -> String {
        let frame = frame.standardized
        let size = "\(format(frame.width)) × \(format(frame.height))"
        switch mode {
        case let .move(delta):
            guard let delta else {
                return "X \(format(frame.minX))  Y \(format(frame.minY))  ·  \(size)"
            }
            return "X \(format(frame.minX))  Y \(format(frame.minY))  ·  ΔX \(format(delta.width))  ΔY \(format(delta.height))"
        case let .resize(scalePercent):
            guard let scalePercent else { return size }
            return "\(size)  ·  W \(format(scalePercent.width))%  H \(format(scalePercent.height))%"
        case let .rotate(degrees):
            return "\(format(degrees))°"
        case let .patchTransfer(delta, constrainedAxis):
            let offset = "ΔX \(format(delta.width))  ΔY \(format(delta.height))"
            switch constrainedAxis {
            case .horizontal:
                return "⇧↔  \(offset)"
            case .vertical:
                return "⇧↕  \(offset)"
            case nil:
                return "\(offset)  ·  D \(format(hypot(delta.width, delta.height)))"
            }
        }
    }

    static func badgeSize(for text: String) -> CGSize {
        CGSize(
            width: min(
                maximumBadgeWidth,
                max(minimumBadgeWidth, CGFloat(text.count) * characterWidth + horizontalPadding)
            ),
            height: badgeHeight
        )
    }

    static func badgeCenter(
        selectionRect: CGRect,
        viewportSize: CGSize,
        badgeSize: CGSize
    ) -> CGPoint {
        let halfWidth = badgeSize.width * 0.5
        let halfHeight = badgeSize.height * 0.5
        let minimumX = viewportMargin + halfWidth
        let maximumX = max(minimumX, viewportSize.width - viewportMargin - halfWidth)
        let x = min(max(selectionRect.midX, minimumX), maximumX)

        let below = selectionRect.maxY + selectionGap + halfHeight
        let maximumY = viewportSize.height - viewportMargin - halfHeight
        let preferredY = below <= maximumY
            ? below
            : selectionRect.minY - selectionGap - halfHeight
        let minimumY = viewportMargin + halfHeight
        let y = min(max(preferredY, minimumY), max(minimumY, maximumY))
        return CGPoint(x: x, y: y)
    }

    private static func format(_ value: CGFloat) -> String {
        let roundedTenth = (value * 10).rounded() / 10
        if abs(roundedTenth - roundedTenth.rounded()) < 0.001 {
            return String(Int(roundedTenth.rounded()))
        }
        return String(
            format: "%.1f",
            locale: Locale(identifier: "en_US_POSIX"),
            Double(roundedTenth)
        )
    }
}
