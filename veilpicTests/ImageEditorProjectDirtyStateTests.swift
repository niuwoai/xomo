import AppKit
import CryptoKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorProjectDirtyStateTests {
    private enum Mutation: CaseIterable {
        case name, frame, guide, history, theme, readout, sampleSize, samplerSource, ignoreAdjustments
        case rasterSelection, savedSelection, alphaChannel
    }

    @Test(arguments: Mutation.allCases)
    private func persistentStateMatchesExactProjectComparison(mutation: Mutation) throws {
        let model = try ImageEditorPixelMoveWorkflowFixture.model()
        model.resetProjectSaveBaseline()
        let baseline = try model.projectData()
        #expect(!model.hasUnsavedProjectChanges)
        switch mutation {
        case .name: model.document.layers[0].name = "Changed without history"
        case .frame: model.document.layers[0].frame.origin.x += 0.05
        case .guide: model.document.areGuidesVisible.toggle()
        case .history: model.document.history.append(ImageEditorHistoryEntry(title: "Changed history"))
        case .theme: model.xomoComponentTheme = .softMobile
        case .readout: model.selectedColorSamplerReadoutMode = .hexadecimal
        case .sampleSize: model.selectColorSamplerSampleSize(.fiveByFive)
        case .samplerSource: _ = model.selectColorSamplerSource(.selectedLayer)
        case .ignoreAdjustments: model.setColorSamplerIgnoresAdjustmentLayers(true)
        case .rasterSelection:
            model.document.selection = ImageEditorSelection(points: [], isPolygon: false,
                rasterMask: ImageEditorSelectionMask(width: 64, height: 64, alpha: [UInt8](repeating: 128, count: 4_096)))
        case .savedSelection: model.document.savedSelection = model.document.selection
        case .alphaChannel:
            model.document.alphaChannels.append(ImageEditorAlphaChannel(name: "Saved alpha",
                mask: ImageEditorSelectionMask(width: 64, height: 64, alpha: [UInt8](repeating: 128, count: 4_096))))
        }
        #expect(try model.projectData() != baseline)
        #expect(model.hasUnsavedProjectChanges)
        try model.loadProjectData(baseline)
        #expect(!model.hasUnsavedProjectChanges)
    }

    @Test func differingMetadataSkipsRasterEncodingButMatchingMetadataNeverProvesClean() throws {
        let model = try ImageEditorPixelMoveWorkflowFixture.model()
        model.document.layers[0].mask = .transparent(size: CGSize(width: 64, height: 64))
        model.resetProjectSaveBaseline()
        model.renameSelectedLayer(to: "Metadata changed")
        var encodes = 0
        let dirty = model.projectHasUnsavedChanges(rasterEncoder: { image in
            encodes += 1
            return image.qingtuPNGData()
        })
        #expect(dirty && encodes == 0)
        model.undo()
        encodes = 0
        let clean = model.projectHasUnsavedChanges(rasterEncoder: { image in
            encodes += 1
            return image.qingtuPNGData()
        })
        #expect(!clean && encodes == 2)
        model.document.layers[0].mask = .transparent(size: CGSize(width: 32, height: 32))
        encodes = 0
        let maskChanged = model.projectHasUnsavedChanges(rasterEncoder: { image in
            encodes += 1
            return image.qingtuPNGData()
        })
        #expect(maskChanged && encodes == 2)
        #expect(model.projectHasUnsavedChanges(rasterEncoder: { _ in nil }))
    }

    @Test func sharedSmartObjectAndMaskMetadataMatchesFullSnapshot() throws {
        let model = try ImageEditorPixelMoveWorkflowFixture.model()
        var smart = ImageEditorLayer.smartObject(name: "Source", image: model.document.layers[0].image,
                                               sourceName: "source.png")
        smart.mask = .transparent(size: CGSize(width: 64, height: 64))
        var instance = smart
        instance.id = UUID()
        model.document.layers = [smart, instance]
        let full = try model.projectDocument()
        let metadataOnly = try model.projectDocument(rasterEncoder: { _ in Data() })
        #expect(try ImageEditorProjectSaveMetadata(project: full) == ImageEditorProjectSaveMetadata(project: metadataOnly))
        #expect(full.smartObjectSources?.count == 1)
        #expect(full.layers.allSatisfy { $0.imageData == nil && $0.maskData != nil })
        model.resetProjectSaveBaseline()
        #expect(!model.hasUnsavedProjectChanges)
        model.document.layers[1].frame.origin.x += 1
        var encodes = 0
        let dirty = model.projectHasUnsavedChanges(rasterEncoder: { _ in encodes += 1; return nil })
        #expect(dirty && encodes == 0)
    }

    @Test func mutableImageWithoutDocumentPublicationStillRequiresSaving() throws {
        let model = try ImageEditorPixelMoveWorkflowFixture.model()
        let cgImage = try #require(model.document.layers[0].image.cgImage(forProposedRect: nil, context: nil, hints: nil))
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        let image = NSImage(size: bitmap.size)
        image.addRepresentation(bitmap)
        model.document.layers[0].image = image
        model.resetProjectSaveBaseline()
        let baseline = try model.projectData()
        let changed = try #require(NSImage.rendered(size: image.size) { rect in
            NSColor.green.setFill()
            rect.fill()
        })
        let changedCGImage = try #require(changed.cgImage(forProposedRect: nil, context: nil, hints: nil))
        let replacement = NSBitmapImageRep(cgImage: changedCGImage)
        image.removeRepresentation(bitmap)
        image.addRepresentation(replacement)
        #expect(try model.projectData() != baseline)
        #expect(model.hasUnsavedProjectChanges)
        image.removeRepresentation(replacement)
        image.addRepresentation(bitmap)
        #expect(try model.projectData() == baseline)
        #expect(!model.hasUnsavedProjectChanges)
    }

    @Test func editDuringWriterDoesNotAdvanceBaselineToUnwrittenContent() throws {
        let model = try ImageEditorPixelMoveWorkflowFixture.model()
        let original = try model.projectData()
        let saved = model.writeProjectDocument(to: URL(fileURLWithPath: "/tmp/dirty-writer.xomoproject"),
            dataWriter: { data, _ in
                #expect(data == original)
                model.document.layers[0].name = "Not in written data"
            }, recentDocumentRegistrar: { _ in })
        #expect(saved)
        #expect(model.hasUnsavedProjectChanges)
        model.document.layers[0].name = "Move source"
        #expect(try model.projectData() == original)
        #expect(!model.hasUnsavedProjectChanges)
    }

    @Test func profileNativeSerializationAndDirtyChecks() throws {
        var cases: [[String: Any]] = []
        for size in [1_024, 2_048] {
            var samples: [String: [Double]] = [:]
            var bytes = 0
            for _ in 0..<3 {
                try autoreleasepool {
                    let model = try ImageEditorPixelMoveWorkflowFixture.model(size: size)
                    var baseline = Data()
                    try record("serialization", into: &samples) { baseline = try model.projectData() }
                    bytes = baseline.count
                    record("reset_baseline", into: &samples) { model.resetProjectSaveBaseline() }
                    record("clean_check", into: &samples) { #expect(!model.hasUnsavedProjectChanges) }
                    model.renameSelectedLayer(to: "Measured edit")
                    record("dirty_check", into: &samples) { #expect(model.hasUnsavedProjectChanges) }
                    record("dirty_window_metadata", into: &samples) {
                        #expect(XomoDocumentWindowMetadata(viewModel: model).isDocumentEdited)
                    }
                    model.undo()
                    record("undone_check", into: &samples) { #expect(!model.hasUnsavedProjectChanges) }
                    #expect(try model.projectData() == baseline)
                }
            }
            cases.append(["size": size, "project_bytes": bytes, "samples_ms": samples,
                          "median_ms": samples.mapValues { $0.sorted()[$0.count / 2] }])
        }
        let fixtureURL = URL(fileURLWithPath: "/private/tmp/xomo-ui-transform-rc1713-saved.xomoproject")
        if FileManager.default.fileExists(atPath: fixtureURL.path) {
            let fixture = try Data(contentsOf: fixtureURL)
            let sha = SHA256.hash(data: fixture).map { String(format: "%02x", $0) }.joined()
            try #require(sha == "ed0f8bf54993038d1f121a86d9ef55922c906dd0847ecac2d260e9136107a16d")
            var samples: [String: [Double]] = [:]
            for _ in 0..<3 {
                try autoreleasepool {
                    let model = try ImageEditorPixelMoveWorkflowFixture.model()
                    try model.loadProjectData(fixture)
                    let baseline = try model.projectData()
                    record("clean_check", into: &samples) { #expect(!model.hasUnsavedProjectChanges) }
                    model.renameSelectedLayer(to: "Measured edit")
                    record("dirty_check", into: &samples) { #expect(model.hasUnsavedProjectChanges) }
                    record("dirty_window_metadata", into: &samples) {
                        #expect(XomoDocumentWindowMetadata(viewModel: model).isDocumentEdited)
                    }
                    model.undo()
                    record("undone_check", into: &samples) { #expect(!model.hasUnsavedProjectChanges) }
                    #expect(try model.projectData() == baseline)
                }
            }
            cases.append(["size": "actual saved 2048² raster-selection project", "project_bytes": fixture.count,
                "fixture_sha256": sha, "samples_ms": samples,
                "median_ms": samples.mapValues { $0.sorted()[$0.count / 2] }])
        }
        let report: [String: Any] = ["version": AppVersion.current, "iterations": 3, "cases": cases,
            "configuration": "Debug native model, App -O, tests -Onone",
            "scope": "Serialization and dirty window metadata; excludes displayed UI latency, disk writes and memory"]
        let prefix = "/private/tmp/xomo-project-dirty-\(AppVersion.current)"
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            .write(to: URL(fileURLWithPath: prefix + ".json"))
        var rows = ["# Native project dirty-state profile", "", report["scope"] as! String, "",
                    "| Bitmap | Phase | Median ms |", "|---|---|---:|"]
        for item in cases {
            let medians = try #require(item["median_ms"] as? [String: Double])
            for phase in medians.keys.sorted() {
                rows.append("| \(item["size"]!) | \(phase) | \(String(format: "%.3f", medians[phase]!)) |")
            }
        }
        try (rows.joined(separator: "\n") + "\n").write(toFile: prefix + ".md", atomically: true, encoding: .utf8)
        print("Project dirty-state profile: \(prefix).{json,md}")
    }

    private func record(_ name: String, into samples: inout [String: [Double]], _ action: () throws -> Void) rethrows {
        let started = ProcessInfo.processInfo.systemUptime
        try action()
        samples[name, default: []].append((ProcessInfo.processInfo.systemUptime - started) * 1_000)
    }
}
