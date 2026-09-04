import AppKit
import JavaScriptCore
import Testing
@testable import musepic

@MainActor
struct ImageEditorHotspotHTMLExporterTests {
    @Test func exportKeepsFallbackCoordinatesAndEscapesMetadata() throws {
        let hotspot = ImageEditorHotspot(
            name: "Hero & Link",
            frame: CGRect(x: 10, y: 12, width: 30, height: 20),
            url: "https://example.com/a?x=1&y=2"
        )
        let html = try exportedHTML(hotspots: [hotspot], title: "Demo <Page>")

        #expect(html.contains("usemap=\"#xomo-hotspots\""))
        #expect(html.contains("data:image/png;base64,"))
        #expect(html.contains("<area shape=\"rect\" coords=\"10,12,40,32\""))
        #expect(html.contains("data-original-coords=\"10,12,40,32\""))
        #expect(html.contains("width=\"80\" height=\"60\" data-original-width=\"80\" data-original-height=\"60\""))
        #expect(html.contains("Hero &amp; Link"))
        #expect(html.contains("https://example.com/a?x=1&amp;y=2"))
        #expect(html.contains("<title>Demo &lt;Page&gt;</title>"))
        #expect(!html.contains("Hero & Link"))
        #expect(!html.contains("https://example.com/a?x=1&y=2"))
        #expect(!html.contains("Demo <Page>"))

        let script = try embeddedScript(in: html)
        #expect(!script.contains(hotspot.name))
        #expect(!script.contains(hotspot.url))
        #expect(!script.contains("fetch("))
        #expect(!script.contains("XMLHttpRequest"))
        #expect(!html.contains("<script src="))
    }

    @Test func exportAllowsOnlySafeHotspotHrefs() throws {
        let unsafeURLs = [
            "",
            " \n ",
            "javascript:alert(1)",
            " JaVaScRiPt:alert(1) ",
            "java\nscript:alert(1)",
            "java\tscript:alert(1)",
            "java\rscript:alert(1)",
            "\nDATA:text/html,<script>alert(1)</script>\t",
            "vbscript:msgbox(1)",
            "ftp://example.com/file",
            "//example.com/network-path"
        ]
        let unsafeHotspots = unsafeURLs.enumerated().map { index, url in
            ImageEditorHotspot(
                name: "Unsafe \(index)",
                frame: CGRect(x: index, y: index, width: 4, height: 4),
                url: url
            )
        }
        let unsafeHTML = try exportedHTML(hotspots: unsafeHotspots)
        #expect(unsafeHTML.components(separatedBy: "href=\"#\"").count - 1 == unsafeURLs.count)
        #expect(!unsafeHTML.lowercased().contains("href=\"javascript:"))
        #expect(!unsafeHTML.lowercased().contains("href=\"data:"))
        #expect(!unsafeHTML.lowercased().contains("href=\"vbscript:"))

        let safeURLs = [
            "http://example.com/start",
            " https://example.com/trimmed ",
            "mailto:hello@example.com",
            "tel:+15551234567",
            "/docs/start?x=1&y=2",
            "guide/page.html",
            "#details"
        ]
        let safeHotspots = safeURLs.enumerated().map { index, url in
            ImageEditorHotspot(
                name: "Safe \(index)",
                frame: CGRect(x: index, y: index, width: 4, height: 4),
                url: url
            )
        }
        let safeHTML = try exportedHTML(hotspots: safeHotspots)
        #expect(safeHTML.contains("href=\"http://example.com/start\""))
        #expect(safeHTML.contains("href=\"https://example.com/trimmed\""))
        #expect(safeHTML.contains("href=\"mailto:hello@example.com\""))
        #expect(safeHTML.contains("href=\"tel:+15551234567\""))
        #expect(safeHTML.contains("href=\"/docs/start?x=1&amp;y=2\""))
        #expect(safeHTML.contains("href=\"guide/page.html\""))
        #expect(safeHTML.contains("href=\"#details\""))
    }

    @Test func embeddedScriptRescalesMultipleAreasForEveryLayoutSignal() throws {
        let hotspots = [
            ImageEditorHotspot(
                name: "Primary",
                frame: CGRect(x: 10, y: 12, width: 30, height: 20),
                url: "#primary"
            ),
            ImageEditorHotspot(
                name: "Secondary",
                frame: CGRect(x: 0, y: 0, width: 20, height: 10),
                url: "#secondary"
            )
        ]
        let script = try embeddedScript(in: exportedHTML(hotspots: hotspots))
        let context = try #require(JSContext())
        context.evaluateScript(Self.domMockScript)
        context.evaluateScript(script)
        #expect(context.exception == nil)

        #expect(coordinates(in: context) == "5,9,20,24|0,0,10,8")
        #expect(context.evaluateScript("Boolean(callbacks.load)")?.toBool() == true)
        #expect(context.evaluateScript("Boolean(callbacks.resize)")?.toBool() == true)
        #expect(context.evaluateScript("observedImage === image")?.toBool() == true)

        context.evaluateScript("image.bounds = { width: 80, height: 30 }; callbacks.load();")
        #expect(coordinates(in: context) == "10,6,40,16|0,0,20,5")

        context.evaluateScript("image.bounds = { width: 20, height: 60 }; callbacks.resize();")
        #expect(coordinates(in: context) == "3,12,10,32|0,0,5,10")

        context.evaluateScript("image.bounds = { width: 80, height: 60 }; resizeObserverCallback();")
        #expect(coordinates(in: context) == "10,12,40,32|0,0,20,10")

        context.evaluateScript("areas.forEach((area) => { area.coords = area.dataset.originalCoords; }); image.bounds = { width: 0, height: 45 }; callbacks.resize();")
        #expect(coordinates(in: context) == "10,12,40,32|0,0,20,10")
        #expect(context.exception == nil)
    }

    private func exportedHTML(
        hotspots: [ImageEditorHotspot],
        title: String = "Hotspots"
    ) throws -> String {
        let image = NSImage.transparent(size: CGSize(width: 80, height: 60))
        let pngData = try #require(image.qingtuPNGData())
        let data = ImageEditorHotspotHTMLExporter.data(
            canvasSize: image.size,
            pngData: pngData,
            hotspots: hotspots,
            title: title
        )
        return try #require(String(data: data, encoding: .utf8))
    }

    private func embeddedScript(in html: String) throws -> String {
        let scriptStart = try #require(html.range(of: "<script>"))
        let scriptEnd = try #require(html.range(
            of: "</script>",
            range: scriptStart.upperBound..<html.endIndex
        ))
        return String(html[scriptStart.upperBound..<scriptEnd.lowerBound])
    }

    private func coordinates(in context: JSContext) -> String? {
        context.evaluateScript("areas.map((area) => area.coords).join('|')")?.toString()
    }

    private static let domMockScript = """
    var callbacks = {};
    var resizeObserverCallback;
    var observedImage;
    var areas = [
      { dataset: { originalCoords: "10,12,40,32" }, coords: "10,12,40,32" },
      { dataset: { originalCoords: "0,0,20,10" }, coords: "0,0,20,10" }
    ];
    var image = {
      dataset: { originalWidth: "80", originalHeight: "60" },
      bounds: { width: 40, height: 45 },
      getBoundingClientRect: function() { return this.bounds; },
      addEventListener: function(name, callback) { callbacks[name] = callback; }
    };
    var map = {
      querySelectorAll: function() { return areas; }
    };
    var document = {
      querySelector: function(selector) {
        return selector.indexOf("img") === 0 ? image : map;
      }
    };
    var window = {
      addEventListener: function(name, callback) { callbacks[name] = callback; }
    };
    var ResizeObserver = function(callback) {
      resizeObserverCallback = callback;
      this.observe = function(target) { observedImage = target; };
    };
    window.ResizeObserver = ResizeObserver;
    """
}
