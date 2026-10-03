import AppKit
import SwiftUI

enum ImageEditorRotationHandleHitRegion {
    static let diameter: CGFloat = 16
    static let padding: CGFloat = 1
    static let canvasCoordinateSpace = "image-editor-canvas-space"

    static func contains(_ point: CGPoint, handlePoint: CGPoint) -> Bool {
        guard point.x.isFinite, point.y.isFinite,
              handlePoint.x.isFinite, handlePoint.y.isFinite else { return false }
        let radius = diameter / 2 + padding
        return hypot(point.x - handlePoint.x, point.y - handlePoint.y) <= radius
    }
}

/// Bind the gesture to the small handle before positioning it in the canvas.
/// A second start-point check prevents a competing canvas drag from owning a
/// rotation transaction, even if a hosting hit-test forwards that sequence.
struct ImageEditorLayerRotationHandle: View {
    let rect: CGRect
    @Binding var isRotating: Bool
    let canBegin: () -> Bool
    let onBegan: (CGPoint) -> Void
    let onChanged: (CGPoint) -> Void
    let onEnded: () -> Void

    var handlePoint: CGPoint { ImageEditorCanvasCursor.transformRotateHandlePoint(in: rect) }

    var body: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: rect.midX, y: rect.minY))
                path.addLine(to: handlePoint)
            }
            .stroke(Color(nsColor: ImageEditorTheme.selected).opacity(0.75), lineWidth: 1.4)
            .allowsHitTesting(false)

            Circle()
                .fill(Color.white.opacity(0.96))
                .overlay(Circle().stroke(Color(nsColor: ImageEditorTheme.selected), lineWidth: 1.6))
                .overlay {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color(nsColor: ImageEditorTheme.selected))
                }
                .frame(width: ImageEditorRotationHandleHitRegion.diameter,
                       height: ImageEditorRotationHandleHitRegion.diameter)
                .contentShape(Circle().inset(by: -ImageEditorRotationHandleHitRegion.padding))
                .gesture(DragGesture(minimumDistance: 0,
                                     coordinateSpace: .named(ImageEditorRotationHandleHitRegion.canvasCoordinateSpace))
                    .onChanged { dragChanged(startLocation: $0.startLocation, location: $0.location) }
                    .onEnded { _ in dragEnded() })
                .position(handlePoint)
                .help(L10n.text("imageEditor.action.layerRotateHandle"))
                .accessibilityIdentifier("image-editor-layer-rotation-handle")
        }
    }

    func dragChanged(startLocation: CGPoint, location: CGPoint) {
        if !isRotating {
            guard canBegin(), ImageEditorRotationHandleHitRegion.contains(startLocation, handlePoint: handlePoint)
            else { return }
            isRotating = true
            onBegan(startLocation)
        }
        onChanged(location)
    }

    func dragEnded() {
        guard isRotating else { return }
        isRotating = false
        onEnded()
    }
}
