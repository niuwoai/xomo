//
//  ImageEditorColorRangeModels.swift
//  veilpic
//
//  Created by Codex on 2026/7/9.
//

import Foundation

enum ImageEditorColorRangeSampleMode: String, CaseIterable, Identifiable {
    case replace
    case add
    case subtract

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.colorRange.sampleMode.\(rawValue)")
    }
}
