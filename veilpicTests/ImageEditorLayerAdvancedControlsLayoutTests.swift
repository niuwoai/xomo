import AppKit
import Foundation
import SwiftUI
#if !XOMO_STANDALONE_LAYOUT_TESTS
import Testing
@testable import musepic
#endif

@MainActor
enum ImageEditorLayerAdvancedControlsLayoutFixture {
    static let panelHeight: CGFloat = 420
    static let minimumListHeight: CGFloat = 150
    nonisolated static let widths: [CGFloat] = [300, 360, 460]
    nonisolated static let rowCounts = [0, 2, 20, 120]
    static let viewportID = "property-viewport-test-probe"
    static let listID = "layer-list-test-probe"

    struct Probe: NSViewRepresentable {
        let identifier: String
        func makeNSView(context: Context) -> NSView {
            let view = NSView()
            view.identifier = NSUserInterfaceItemIdentifier(identifier)
            return view
        }
        func updateNSView(_ view: NSView, context: Context) {}
    }

    struct Panel: View {
        let rows: Int
        let expanded: Bool
        let width: CGFloat
        @State private var opacity = 1.0

        var body: some View {
            VStack(spacing: 8) {
                Text("Tabs").frame(height: 28)
                Text("Search").frame(height: 24)
                Text("Actions").frame(height: 24)
                ScrollView {
                    VStack {
                        ForEach(0..<rows, id: \.self) { _ in Text("Layer").frame(height: 50) }
                    }
                }
                .frame(minHeight: minimumListHeight, maxHeight: .infinity)
                .layoutPriority(1)
                .background(Probe(identifier: listID))
                VStack(spacing: 6) {
                    Text("Advanced controls").frame(height: 28)
                    if expanded {
                        ImageEditorLayerAdvancedControlsViewport {
                            VStack(spacing: 8) {
                                Text("Opacity")
                                Slider(value: $opacity)
                                Text("Fill opacity")
                                Slider(value: $opacity)
                                Text("Blend If")
                                Slider(value: $opacity)
                            }
                        }
                        .background(Probe(identifier: viewportID))
                    }
                }
            }
            .frame(width: width, height: panelHeight)
        }
    }

    struct Measurement {
        let viewport: NSRect?
        let list: NSRect
    }

    static func measure(width: CGFloat, rows: Int, expanded: Bool) throws -> Measurement {
        _ = NSApplication.shared
        let host = NSHostingView(rootView: Panel(rows: rows, expanded: expanded, width: width))
        host.frame = NSRect(x: 0, y: 0, width: width, height: panelHeight)
        for _ in 0..<5 {
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
        }
        guard let list = find(listID, in: host) else {
            throw NSError(domain: "PropertyLayoutTest", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Missing hosted layer list probe"])
        }
        return Measurement(viewport: find(viewportID, in: host)?.frame, list: list.frame)
    }

    private static func find(_ identifier: String, in view: NSView) -> NSView? {
        if view.identifier?.rawValue == identifier { return view }
        return view.subviews.lazy.compactMap { find(identifier, in: $0) }.first
    }
}

#if XOMO_STANDALONE_LAYOUT_TESTS
@main
struct ImageEditorLayerAdvancedControlsStandaloneTests {
    @MainActor static func main() throws {
        typealias Fixture = ImageEditorLayerAdvancedControlsLayoutFixture
        var cases: [[String: Any]] = []
        for width in Fixture.widths {
            for rows in Fixture.rowCounts {
                let expanded = try Fixture.measure(width: width, rows: rows, expanded: true)
                let collapsed = try Fixture.measure(width: width, rows: rows, expanded: false)
                let visible = expanded.viewport?.height == ImageEditorLayerAdvancedControlsLayout.viewportHeight
                    && expanded.viewport?.width == width
                let listRetained = expanded.list.height >= Fixture.minimumListHeight
                let reclaimed = collapsed.viewport == nil && collapsed.list.height > expanded.list.height
                cases.append(["width": width, "rows": rows,
                              "expanded_viewport_height": expanded.viewport?.height ?? -1,
                              "expanded_list_height": expanded.list.height,
                              "collapsed_list_height": collapsed.list.height,
                              "viewport_visible": visible, "list_retained": listRetained,
                              "collapsed_reclaims_space": reclaimed,
                              "passed": visible && listRetained && reclaimed])
            }
        }
        let passed = cases.allSatisfy { $0["passed"] as? Bool == true }
        let data = try JSONSerialization.data(withJSONObject: ["passed": passed, "cases": cases],
                                              options: [.prettyPrinted, .sortedKeys])
        print(String(decoding: data, as: UTF8.self))
        if !passed { exit(1) }
    }
}
#else
@MainActor
@Suite(.serialized)
struct ImageEditorLayerAdvancedControlsLayoutTests {
    @Test(arguments: ImageEditorLayerAdvancedControlsLayoutFixture.widths,
          ImageEditorLayerAdvancedControlsLayoutFixture.rowCounts)
    func expandedProductionViewportRetainsSpaceAndCollapseReclaimsIt(width: CGFloat, rows: Int) throws {
        typealias Fixture = ImageEditorLayerAdvancedControlsLayoutFixture
        let expanded = try Fixture.measure(width: width, rows: rows, expanded: true)
        let viewport = try #require(expanded.viewport)
        #expect(viewport.height == ImageEditorLayerAdvancedControlsLayout.viewportHeight)
        #expect(viewport.width == width)
        #expect(expanded.list.height >= Fixture.minimumListHeight)
        let collapsed = try Fixture.measure(width: width, rows: rows, expanded: false)
        #expect(collapsed.viewport == nil)
        #expect(collapsed.list.height > expanded.list.height)
    }
}
#endif
