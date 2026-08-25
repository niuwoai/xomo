//
//  XomoEditorWorkspaceView.swift
//  veilpic
//
//  Created by Codex on 2026/7/11.
//

import AppKit
import SwiftUI

struct XomoEditorWorkspaceView: View {
    @StateObject private var viewModel: ImageEditorViewModel
    @ObservedObject private var externalOpenCoordinator = XomoExternalDocumentOpenCoordinator.shared

    init() {
        let sourceName = L10n.text("imageEditor.developmentSampleName")
        let canvas = NSImage.transparent(size: NSSize(width: 1440, height: 900))
        let document = ImageEditorDocument(sourceName: sourceName, image: canvas)
        _viewModel = StateObject(
            wrappedValue: ImageEditorViewModel(
                document: document,
                initialCompositeImage: canvas,
                onApply: { _ in }
            )
        )
    }

    var body: some View {
        Group {
            if let presentation = externalOpenCoordinator.presentation {
                XomoDocumentLoadingView(presentation: presentation)
                    .transition(.opacity)
            } else {
                ImageEditorView(viewModel: viewModel)
                    .transition(.opacity)
            }
        }
            .background(
                XomoDocumentCloseGuard(viewModel: viewModel)
                    .frame(width: 0, height: 0)
            )
            .animation(.easeInOut(duration: 0.18), value: externalOpenCoordinator.presentation != nil)
            .onAppear {
                externalOpenCoordinator.register(viewModel)
                XomoAutomationRegistry.shared.register(viewModel)
                XomoAutomationServer.shared.start()
                presentPresetManagerForUITestingIfRequested()
            }
            .onDisappear {
                externalOpenCoordinator.unregister(viewModel)
                XomoAutomationRegistry.shared.unregister(viewModel)
            }
    }

    private func presentPresetManagerForUITestingIfRequested() {
        #if DEBUG
        guard UserDefaults.standard.bool(forKey: "XomoUITestPresetManager") else { return }
        viewModel.isLayerStylePresetManagerPresented = true
        #endif
    }
}
