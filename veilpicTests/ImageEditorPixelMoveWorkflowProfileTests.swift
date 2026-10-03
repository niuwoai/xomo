import AppKit
import Darwin
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorPixelMoveWorkflowProfileTests {
    @Test func measureNativeLargeBitmapPreviewPhasesWithoutUITimingClaims() throws {
        var cases: [[String: Any]] = []
        for size in [1_024, 2_048] {
            cases.append(try profile(size: size))
        }
        #if DEBUG
        let configuration = "Debug native test host"
        #else
        let configuration = "Release native test host"
        #endif
        let report: [String: Any] = ["version": AppVersion.current, "cases": cases,
            "configuration": configuration, "iterations": 3,
            "scope": "Native model update and explicit composite; excludes event delivery and displayed frame latency",
            "memory_scope": "getrusage process lifetime high-water bytes, not per-phase allocations or GUI peak memory"]
        let prefix = FileManager.default.temporaryDirectory
            .appendingPathComponent("xomo-pixel-move-workflow-\(AppVersion.current)").path
        let jsonURL = URL(fileURLWithPath: prefix + ".json")
        let jsonData = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        try jsonData.write(to: jsonURL)
        #expect(try Data(contentsOf: jsonURL) == jsonData)
        var rows = ["# Native pixel move workflow profile", "",
            "\(configuration), 3 iterations. No UI frame latency or per-phase allocation claim.", "",
            "| Bitmap | Phase | Median ms |", "|---|---|---:|"]
        for item in cases {
            let phases = try #require(item["median_ms"] as? [String: Double])
            for name in phases.keys.sorted() {
                rows.append("| \(item["size"]!) | \(name) | \(String(format: "%.3f", phases[name]!)) |")
            }
            rows.append("\nProcess lifetime high-water after this case: \(item["peak_resident_bytes"]!) bytes.\n")
        }
        let markdown = rows.joined(separator: "\n") + "\n"
        try markdown.write(toFile: prefix + ".md", atomically: true, encoding: .utf8)
        #expect(try String(contentsOfFile: prefix + ".md", encoding: .utf8) == markdown)
        print("Pixel move workflow profile: \(prefix).{json,md}")
    }

    private func profile(size: Int) throws -> [String: Any] {
        var samples: [String: [Double]] = [:]
        for _ in 0..<3 {
            try autoreleasepool {
                let model = try ImageEditorPixelMoveWorkflowFixture.model(size: size, selectionSide: 64)
                let original = try model.projectData()
                let originalUndo = model.undoStack.count
                let begin = model.beginPixelSelectionMove()
                #expect(begin)
                record("selection_translation", into: &samples) {
                    _ = model.document.selection?.translated(by: CGSize(width: 1, height: 0), canvasSize: model.document.canvasSize)
                }
                record("distinct_preview", into: &samples) { model.updatePixelSelectionMove(by: CGSize(width: 1.1, height: 0)) }
                record("same_pixel_preview", into: &samples) { model.updatePixelSelectionMove(by: CGSize(width: 1.4, height: 0.1)) }
                var composite: NSImage?
                record("explicit_composite", into: &samples) { composite = model.document.compositedImage }
                #expect(composite?.size == model.document.canvasSize)
                record("return_to_zero", into: &samples) { model.updatePixelSelectionMove(by: .zero) }
                record("finish_no_change", into: &samples) { model.finishPixelSelectionMove() }
                #expect(try model.projectData() == original)
                #expect(model.undoStack.count == originalUndo)

                #expect(model.beginPixelSelectionMove())
                record("committed_preview", into: &samples) { model.updatePixelSelectionMove(by: CGSize(width: 2, height: 0)) }
                record("finish_changed", into: &samples) { model.finishPixelSelectionMove() }
                #expect(model.undoStack.count == originalUndo + 1)
                let moved = try model.projectData()
                model.undo()
                #expect(try model.projectData() == original)
                model.redo()
                #expect(try model.projectData() == moved)
            }
        }
        var usage = rusage()
        #expect(getrusage(RUSAGE_SELF, &usage) == 0)
        let medians = samples.mapValues { $0.sorted()[$0.count / 2] }
        return ["size": size, "selection_side": 64, "samples_ms": samples, "median_ms": medians,
                "peak_resident_bytes": usage.ru_maxrss, "project_and_history_exact": true]
    }

    private func record(_ name: String, into samples: inout [String: [Double]], _ action: () -> Void) {
        let start = ProcessInfo.processInfo.systemUptime
        action()
        samples[name, default: []].append((ProcessInfo.processInfo.systemUptime - start) * 1_000)
    }
}

@MainActor
enum ImageEditorPixelMoveWorkflowFixture {
    static func model(size: Int = 64, selectionSide: Int = 16) throws -> ImageEditorViewModel {
        let imageSize = CGSize(width: size, height: size)
        let origin = (size - selectionSide) / 2
        let selection = CGRect(x: origin, y: origin, width: selectionSide, height: selectionSide)
        let image = try #require(NSImage.rendered(size: imageSize) { rect in
            NSColor.blue.setFill()
            rect.fill()
            NSColor.red.setFill()
            selection.fill()
        })
        var layer = ImageEditorLayer.blank(name: "Move source", size: imageSize)
        layer.image = image
        let model = ImageEditorViewModel(sourceName: "move-profile.png", image: .transparent(size: imageSize)) { _ in }
        model.document.layers = [layer]
        model.selectLayer(layer.id)
        model.selectedTool = .move
        model.document.selection = .rectangle(selection)
        return model
    }
}
