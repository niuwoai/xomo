//
//  ImageEditorPaintBucketSymbol.swift
//  veilpic
//

import SwiftUI

struct ImageEditorPaintBucketSymbol: View {
    var body: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: 2.5, y: 6))
                path.addLine(to: CGPoint(x: 8.5, y: 1.5))
                path.addLine(to: CGPoint(x: 13, y: 7.5))
                path.addLine(to: CGPoint(x: 7, y: 12))
                path.closeSubpath()
                path.move(to: CGPoint(x: 4.5, y: 10.5))
                path.addLine(to: CGPoint(x: 10.5, y: 6))
            }
            .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

            Path { path in
                path.move(to: CGPoint(x: 12, y: 11.5))
                path.addCurve(
                    to: CGPoint(x: 12, y: 14),
                    control1: CGPoint(x: 10.8, y: 12.8),
                    control2: CGPoint(x: 11.2, y: 14)
                )
                path.addCurve(
                    to: CGPoint(x: 12, y: 11.5),
                    control1: CGPoint(x: 12.8, y: 14),
                    control2: CGPoint(x: 13.2, y: 12.8)
                )
            }
            .fill(.primary)
        }
        .frame(width: 15, height: 15)
        .accessibilityHidden(true)
    }
}
