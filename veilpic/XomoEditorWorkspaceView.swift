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
        ImageEditorView(viewModel: viewModel)
            .onAppear {
                XomoAutomationRegistry.shared.register(viewModel)
                XomoAutomationServer.shared.start()
                presentPresetManagerForUITestingIfRequested()
            }
            .onDisappear {
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
