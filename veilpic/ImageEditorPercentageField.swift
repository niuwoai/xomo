//
//  ImageEditorPercentageField.swift
//  veilpic
//
//  Created by Codex on 2026/8/16.
//

import Foundation
import SwiftUI

enum ImageEditorPercentageDraft {
    static func normalizedValue(from text: String) -> Double? {
        var candidate = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if candidate.hasSuffix("%") {
            candidate.removeLast()
        }
        candidate = candidate
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let percentage = Double(candidate), percentage.isFinite else { return nil }
        return max(0, min(100, percentage)) / 100
    }

    static func text(for normalizedValue: Double) -> String {
        let resolved = max(0, min(1, normalizedValue.isFinite ? normalizedValue : 0)) * 100
        var formatted = String(
            format: "%.2f",
            locale: Locale(identifier: "en_US_POSIX"),
            resolved
        )
        while formatted.hasSuffix("0") {
            formatted.removeLast()
        }
        if formatted.hasSuffix(".") {
            formatted.removeLast()
        }
        return formatted
    }
}

struct ImageEditorPercentageField: View {
    let label: String
    let normalizedValue: Double
    let accessibilityIdentifier: String
    let onCommit: (Double) -> Void

    @State private var draft = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
            TextField("", text: $draft)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11, design: .monospaced))
                .multilineTextAlignment(.trailing)
                .frame(width: 54)
                .focused($isFocused)
                .onSubmit {
                    isFocused = false
                }
                .accessibilityLabel(label)
                .accessibilityIdentifier(accessibilityIdentifier)
            Text(L10n.text("imageEditor.properties.percentUnit"))
                .font(.system(size: 10, design: .monospaced))
                .accessibilityHidden(true)
        }
        .onAppear {
            synchronizeDraft()
        }
        .onChange(of: normalizedValue) { _ in
            if !isFocused {
                synchronizeDraft()
            }
        }
        .onChange(of: isFocused) { focused in
            if focused {
                if draft.isEmpty { synchronizeDraft() }
            } else {
                commitDraft()
            }
        }
    }

    private func synchronizeDraft() {
        draft = ImageEditorPercentageDraft.text(for: normalizedValue)
    }

    private func commitDraft() {
        guard let value = ImageEditorPercentageDraft.normalizedValue(from: draft) else {
            synchronizeDraft()
            return
        }
        draft = ImageEditorPercentageDraft.text(for: value)
        onCommit(value)
    }
}
