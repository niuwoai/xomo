//
//  ImageEditorLayerStylePresets.swift
//  veilpic
//
//  Created by Codex on 2026/7/14.
//

import Foundation
import SwiftUI

struct ImageEditorLayerStylePreset: Identifiable, Codable, Equatable {
    static let builtInIDPrefix = "builtin."

    let id: String
    let name: String
    let style: ImageEditorProjectLayerStyle

    init(id: String, name: String, style: ImageEditorProjectLayerStyle) {
        self.id = id
        self.name = name
        self.style = style
    }

    var title: String {
        name
    }

    var isBuiltIn: Bool {
        id.hasPrefix(Self.builtInIDPrefix)
    }

    var layerStyle: ImageEditorLayerStyle {
        style.layerStyle
    }

    var normalizedCustomPreset: ImageEditorLayerStylePreset {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedName = trimmedName.isEmpty
            ? L10n.text("imageEditor.layerStylePreset.untitled")
            : trimmedName
        let normalizedStyle = ImageEditorProjectLayerStyle(style: style.layerStyle)
        let normalizedID = id.isEmpty || isBuiltIn ? UUID().uuidString : id
        return ImageEditorLayerStylePreset(
            id: normalizedID,
            name: String(normalizedName.prefix(80)),
            style: normalizedStyle
        )
    }

    func matches(_ candidate: ImageEditorLayerStyle) -> Bool {
        style == ImageEditorProjectLayerStyle(style: candidate)
    }
}

struct ImageEditorLayerStylePresetPreferences: Codable, Equatable {
    static let storageKey = "im.some.xomo.imageEditor.customLayerStylePresets"
    static let maximumPresetCount = 100

    var presets: [ImageEditorLayerStylePreset]

    var normalized: ImageEditorLayerStylePresetPreferences {
        var seenIDs = Set<String>()
        let normalizedPresets = presets.compactMap { preset -> ImageEditorLayerStylePreset? in
            let normalized = preset.normalizedCustomPreset
            guard seenIDs.insert(normalized.id).inserted else { return nil }
            return normalized
        }
        return ImageEditorLayerStylePresetPreferences(
            presets: Array(normalizedPresets.prefix(Self.maximumPresetCount))
        )
    }

    static func load(from defaults: UserDefaults) -> ImageEditorLayerStylePresetPreferences {
        guard let data = defaults.data(forKey: storageKey),
              let preferences = try? JSONDecoder().decode(
                ImageEditorLayerStylePresetPreferences.self,
                from: data
              )
        else { return ImageEditorLayerStylePresetPreferences(presets: []) }
        return preferences.normalized
    }

    func save(to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(normalized) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}

struct ImageEditorLayerStylePresetMenu: View {
    @ObservedObject var viewModel: ImageEditorViewModel

    var body: some View {
        Menu {
            if !viewModel.favoriteLayerStylePresets.isEmpty {
                Section(L10n.text("imageEditor.layerStylePreset.favoriteSection")) {
                    ForEach(viewModel.favoriteLayerStylePresets) { preset in
                        presetButton(preset)
                    }
                }
            }

            if !viewModel.recentLayerStylePresets.isEmpty {
                Section(L10n.text("imageEditor.layerStylePreset.recentSection")) {
                    ForEach(viewModel.recentLayerStylePresets) { preset in
                        presetButton(preset)
                    }
                }
            }

            Section(L10n.text("imageEditor.layerStylePreset.builtInSection")) {
                ForEach(viewModel.builtInLayerStylePresets) { preset in
                    presetButton(preset)
                }
            }

            Section(L10n.text("imageEditor.layerStylePreset.customSection")) {
                if viewModel.customLayerStylePresets.isEmpty {
                    Text(L10n.text("imageEditor.layerStylePreset.empty"))
                }
                ForEach(viewModel.customLayerStylePresets) { preset in
                    presetButton(preset)
                }
            }

            Divider()
            Button {
                viewModel.createLayerStylePresetFromSelectedLayer()
            } label: {
                Label(L10n.text("imageEditor.action.layerStylePresetCreate"), systemImage: "plus")
            }
            .disabled(!viewModel.canCreateLayerStylePreset)

            if let activePreset = viewModel.activeLayerStylePreset, !activePreset.isBuiltIn {
                Button(role: .destructive) {
                    viewModel.deleteLayerStylePreset(activePreset)
                } label: {
                    Label(L10n.text("imageEditor.action.layerStylePresetDelete"), systemImage: "trash")
                }
            }

            Divider()
            Button {
                viewModel.isLayerStylePresetManagerPresented = true
            } label: {
                Label(L10n.text("imageEditor.action.layerStylePresetManage"), systemImage: "slider.horizontal.3")
            }
        } label: {
            Label(
                viewModel.activeLayerStylePreset?.title
                    ?? L10n.text("imageEditor.option.layerStylePreset"),
                systemImage: "square.stack.3d.up"
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize(horizontal: false, vertical: true)
        .help(L10n.text("imageEditor.help.layerStylePreset"))
        .accessibilityIdentifier("image-editor-layer-style-preset-menu")
        .focusable(false)
    }

    private func presetButton(_ preset: ImageEditorLayerStylePreset) -> some View {
        Button {
            viewModel.applyLayerStylePreset(preset)
        } label: {
            HStack(spacing: 6) {
                ImageEditorLayerStylePresetThumbnail(preset: preset, width: 24, height: 16)
                Text(preset.title)
                if viewModel.isFavoriteLayerStylePreset(id: preset.id) {
                    Image(systemName: "star.fill")
                }
                if viewModel.activeLayerStylePreset?.id == preset.id {
                    Image(systemName: "checkmark")
                }
            }
        }
        .disabled(!viewModel.canApplyLayerStylePreset)
    }
}
