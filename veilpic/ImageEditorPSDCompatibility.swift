//
//  ImageEditorPSDCompatibility.swift
//  veilpic
//
//  Created by Codex on 2026/7/16.
//

import SwiftUI

enum ImageEditorPSDCompression: Int, CaseIterable, Hashable, Sendable {
    case raw = 0
    case rle = 1
    case zip = 2
    case zipPrediction = 3

    var identifier: String {
        switch self {
        case .raw: "raw"
        case .rle: "rle"
        case .zip: "zip"
        case .zipPrediction: "zipPrediction"
        }
    }

    var titleKey: String {
        switch self {
        case .raw: "imageEditor.psd.compatibility.compression.raw"
        case .rle: "imageEditor.psd.compatibility.compression.rle"
        case .zip: "imageEditor.psd.compatibility.compression.zip"
        case .zipPrediction: "imageEditor.psd.compatibility.compression.zipPrediction"
        }
    }
}

enum ImageEditorPSDCompatibilityIssueKind: String, Hashable, Sendable {
    case unsupportedVersion
    case unsupportedBitDepth
    case unsupportedColorMode
    case unsupportedCompression
    case additionalChannels
    case textRasterized
    case vectorRasterized
    case smartObjectRasterized
    case adjustmentLayerRasterized
    case layerEffectsRasterized
    case fillLayerRasterized
    case colorProfileIgnored
    case unknownBlendMode
    case unknownLayerData
    case flattenedFallback

    var titleKey: String { "imageEditor.psd.compatibility.issue.\(rawValue)" }
}

struct ImageEditorPSDCompatibilityIssue: Identifiable, Hashable, Sendable {
    let kind: ImageEditorPSDCompatibilityIssueKind
    let count: Int

    var id: ImageEditorPSDCompatibilityIssueKind { kind }
}

enum ImageEditorPSDCompatibilityMetadataSource: Equatable, Sendable {
    case sourceDocument
    case flattenedWorkingCopy
}

struct ImageEditorPSDCompatibilityReport: Equatable, Sendable {
    let width: Int
    let height: Int
    let bitDepth: Int
    let colorMode: Int
    let layerCount: Int
    let groupCount: Int
    let maskCount: Int
    let compressions: Set<ImageEditorPSDCompression>
    var issues: [ImageEditorPSDCompatibilityIssue]
    var metadataSource: ImageEditorPSDCompatibilityMetadataSource = .sourceDocument

    var requiresAttention: Bool { !issues.isEmpty }

    var metadataNoticeKey: String? {
        metadataSource == .flattenedWorkingCopy
            ? "imageEditor.psd.compatibility.flattenedMetadataNotice"
            : nil
    }

    var colorModeTitleKey: String {
        switch colorMode {
        case 0: "imageEditor.psd.compatibility.colorMode.bitmap"
        case 1: "imageEditor.psd.compatibility.colorMode.grayscale"
        case 2: "imageEditor.psd.compatibility.colorMode.indexed"
        case 3: "imageEditor.psd.compatibility.colorMode.rgb"
        case 4: "imageEditor.psd.compatibility.colorMode.cmyk"
        case 7: "imageEditor.psd.compatibility.colorMode.multichannel"
        case 8: "imageEditor.psd.compatibility.colorMode.duotone"
        case 9: "imageEditor.psd.compatibility.colorMode.lab"
        default: "imageEditor.psd.compatibility.colorMode.unknown"
        }
    }

    func addingFlattenedFallback() -> Self {
        guard !issues.contains(where: { $0.kind == .flattenedFallback }) else { return self }
        var copy = self
        copy.issues.append(ImageEditorPSDCompatibilityIssue(kind: .flattenedFallback, count: 1))
        return copy
    }
}

struct ImageEditorPSDCompatibilityReportView: View {
    let report: ImageEditorPSDCompatibilityReport
    let fileName: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: report.requiresAttention ? "exclamationmark.triangle" : "checkmark.seal")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(report.requiresAttention ? .orange : .green)
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.text("imageEditor.psd.compatibility.title"))
                        .font(.title3.weight(.semibold))
                    Text(fileName)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            metadataGrid

            if let metadataNoticeKey = report.metadataNoticeKey {
                Label(
                    L10n.text(metadataNoticeKey),
                    systemImage: "info.circle"
                )
                .font(.callout)
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
            }

            if report.issues.isEmpty {
                Label(
                    L10n.text("imageEditor.psd.compatibility.noIssues"),
                    systemImage: "checkmark.circle.fill"
                )
                .foregroundStyle(.green)
            } else {
                Text(L10n.text("imageEditor.psd.compatibility.attention"))
                    .font(.headline)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(report.issues) { issue in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "exclamationmark.circle")
                                    .foregroundStyle(.orange)
                                Text(issueText(issue))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
                .frame(maxHeight: 260)
            }

            HStack {
                Spacer()
                Button(L10n.text("action.done")) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 560)
        .background(Color(nsColor: ImageEditorTheme.panel))
        .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
    }

    private var metadataGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
            metadataRow(
                labelKey: "imageEditor.psd.compatibility.document",
                value: "\(report.width) × \(report.height) · \(report.bitDepth)-bit · \(L10n.text(report.colorModeTitleKey))"
            )
            metadataRow(
                labelKey: "imageEditor.psd.compatibility.layers",
                value: L10n.format(
                    "imageEditor.psd.compatibility.layerSummary",
                    report.layerCount,
                    report.groupCount,
                    report.maskCount
                )
            )
            metadataRow(
                labelKey: "imageEditor.psd.compatibility.compression",
                value: report.compressions
                    .sorted { $0.rawValue < $1.rawValue }
                    .map { L10n.text($0.titleKey) }
                    .joined(separator: ", ")
            )
        }
        .padding(12)
        .background(Color(nsColor: ImageEditorTheme.chrome))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func metadataRow(labelKey: String, value: String) -> some View {
        GridRow {
            Text(L10n.text(labelKey))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
            Text(value)
                .textSelection(.enabled)
        }
    }

    private func issueText(_ issue: ImageEditorPSDCompatibilityIssue) -> String {
        issue.count > 1
            ? L10n.format("imageEditor.psd.compatibility.issueCount", L10n.text(issue.kind.titleKey), issue.count)
            : L10n.text(issue.kind.titleKey)
    }
}
