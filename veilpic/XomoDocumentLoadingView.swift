//
//  XomoDocumentLoadingView.swift
//  veilpic
//
//  Created by Codex on 2026/7/16.
//

import SwiftUI

struct XomoDocumentLoadingView: View {
    let presentation: XomoDocumentLoadingPresentation

    var body: some View {
        ZStack {
            Color.black
            Image("StartupArtwork")
                .resizable()
                .scaledToFill()
                .accessibilityHidden(true)

            LinearGradient(
                colors: [.clear, .black.opacity(0.08), .black.opacity(0.68)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack {
                Spacer()
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white.opacity(0.9))
                    Text(presentation.message)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .background(.black.opacity(0.32), in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                }
                .padding(.bottom, 24)
            }
        }
        .frame(minWidth: 1_160, minHeight: 720)
        .clipped()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("xomo.documentLoading")
        .animation(.easeInOut(duration: 0.18), value: presentation.stage)
    }
}
