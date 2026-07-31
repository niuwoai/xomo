import AppKit
import UniformTypeIdentifiers

@MainActor
extension ImageEditorViewModel {
    var canCreateSliceFromSelection: Bool {
        document.slices.count < ImageEditorSlice.maximumCount && sliceBoundsFromSelection != nil
    }

    var availableSlices: [ImageEditorSlice] {
        document.slices
    }

    @discardableResult
    func createSliceFromCurrentSelection(name: String? = nil) -> ImageEditorSlice? {
        guard let frame = sliceBoundsFromSelection else { return nil }
        guard document.slices.count < ImageEditorSlice.maximumCount else {
            statusText = L10n.text("imageEditor.status.sliceLimitReached")
            return nil
        }

        let baseName = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let sliceName = baseName.flatMap { $0.isEmpty ? nil : $0 }
            ?? nextSliceName()
        let slice = ImageEditorSlice(
            name: String(sliceName.prefix(ImageEditorSlice.maximumNameLength)),
            frame: frame
        )
        pushUndo()
        document.slices.append(slice)
        exportSettings.scope = .slice
        exportSettings.sliceID = slice.id
        isSlicesPanelVisible = true
        appendHistory(L10n.format("imageEditor.history.sliceCreated", slice.name))
        statusText = L10n.format("imageEditor.status.sliceCreated", slice.name)
        return slice
    }

    @discardableResult
    func deleteSlice(id: UUID) -> ImageEditorSlice? {
        guard let index = document.slices.firstIndex(where: { $0.id == id }) else { return nil }
        pushUndo()
        let removed = document.slices.remove(at: index)
        if exportSettings.sliceID == id {
            exportSettings.sliceID = document.slices.first?.id
            if exportSettings.sliceID == nil {
                exportSettings.scope = .composited
            }
        }
        appendHistory(L10n.format("imageEditor.history.sliceDeleted", removed.name))
        statusText = L10n.format("imageEditor.status.sliceDeleted", removed.name)
        return removed
    }

    @discardableResult
    func updateSlice(id: UUID, name: String? = nil, frame: CGRect? = nil) -> ImageEditorSlice? {
        guard let index = document.slices.firstIndex(where: { $0.id == id }) else { return nil }
        var updated = document.slices[index]
        if let name {
            updated.name = name
        }
        if let frame {
            updated.frame = frame
        }
        guard let normalized = updated.normalized(canvasSize: document.canvasSize) else { return nil }
        guard normalized != document.slices[index] else { return normalized }
        pushUndo()
        document.slices[index] = normalized
        if exportSettings.sliceID == id {
            exportSettings.scope = .slice
        }
        appendHistory(L10n.format("imageEditor.history.sliceUpdated", normalized.name))
        statusText = L10n.format("imageEditor.status.sliceUpdated", normalized.name)
        return normalized
    }

    func slice(with id: UUID) -> ImageEditorSlice? {
        document.slices.first { $0.id == id }
    }

    @discardableResult
    func selectSlice(id: UUID) -> ImageEditorSlice? {
        guard let slice = slice(with: id) else { return nil }
        selectedHotspotID = nil
        exportSettings.scope = .slice
        exportSettings.sliceID = id
        applyPrimaryExportPreset(for: slice)
        isSlicesPanelVisible = true
        statusText = L10n.format("imageEditor.status.sliceSelected", slice.name)
        return slice
    }

    func applyPrimaryExportPreset(for slice: ImageEditorSlice) {
        exportSettings.filenameSuffix = ""
        guard let preset = (slice.exportPresets ?? []).first(where: {
            $0.resolvedScale(for: slice.frame) != nil
        }), let scale = preset.resolvedScale(for: slice.frame) else {
            return
        }
        exportSettings.format = preset.format
        exportSettings.scale = scale
        exportSettings.batchScales = []
        exportSettings.filenameSuffix = preset.suffix
    }

    private var sliceBoundsFromSelection: CGRect? {
        guard let selection = document.selection else { return nil }
        let canvasBounds = CGRect(origin: .zero, size: document.canvasSize)
        let candidate = selection.isInverted ? canvasBounds : selection.bounds.standardized
        let bounded = candidate.intersection(canvasBounds).integral.intersection(canvasBounds)
        guard bounded.width > 0, bounded.height > 0 else { return nil }
        return bounded
    }

    private func nextSliceName() -> String {
        let existing = Set(document.slices.map { $0.name.lowercased() })
        var index = document.slices.count + 1
        while existing.contains(L10n.format("imageEditor.slice.defaultName", index).lowercased()) {
            index += 1
        }
        return L10n.format("imageEditor.slice.defaultName", index)
    }

    var canCreateHotspotFromSelection: Bool {
        document.hotspots.count < ImageEditorHotspot.maximumCount && hotspotBoundsFromSelection != nil
    }

    var availableHotspots: [ImageEditorHotspot] {
        document.hotspots
    }

    @discardableResult
    func createHotspotFromCurrentSelection(name: String? = nil, url: String? = nil) -> ImageEditorHotspot? {
        guard let frame = hotspotBoundsFromSelection else { return nil }
        guard document.hotspots.count < ImageEditorHotspot.maximumCount else {
            statusText = L10n.text("imageEditor.status.hotspotLimitReached")
            return nil
        }

        let baseName = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hotspotName = baseName.flatMap { $0.isEmpty ? nil : $0 } ?? nextHotspotName()
        let hotspot = ImageEditorHotspot(
            name: String(hotspotName.prefix(ImageEditorHotspot.maximumNameLength)),
            frame: frame,
            url: String((url ?? "").trimmingCharacters(in: .whitespacesAndNewlines).prefix(ImageEditorHotspot.maximumURLLength))
        )
        pushUndo()
        document.hotspots.append(hotspot)
        selectedHotspotID = hotspot.id
        isHotspotsPanelVisible = true
        appendHistory(L10n.format("imageEditor.history.hotspotCreated", hotspot.name))
        statusText = L10n.format("imageEditor.status.hotspotCreated", hotspot.name)
        return hotspot
    }

    @discardableResult
    func deleteHotspot(id: UUID) -> ImageEditorHotspot? {
        guard let index = document.hotspots.firstIndex(where: { $0.id == id }) else { return nil }
        pushUndo()
        let removed = document.hotspots.remove(at: index)
        if selectedHotspotID == id {
            selectedHotspotID = document.hotspots.first?.id
        }
        appendHistory(L10n.format("imageEditor.history.hotspotDeleted", removed.name))
        statusText = L10n.format("imageEditor.status.hotspotDeleted", removed.name)
        return removed
    }

    @discardableResult
    func updateHotspot(
        id: UUID,
        name: String? = nil,
        url: String? = nil,
        frame: CGRect? = nil
    ) -> ImageEditorHotspot? {
        guard let index = document.hotspots.firstIndex(where: { $0.id == id }) else { return nil }
        var updated = document.hotspots[index]
        if let name {
            updated.name = name
        }
        if let url {
            updated.url = url
        }
        if let frame {
            updated.frame = frame
        }
        guard let normalized = updated.normalized(canvasSize: document.canvasSize) else { return nil }
        guard normalized != document.hotspots[index] else { return normalized }
        pushUndo()
        document.hotspots[index] = normalized
        selectedHotspotID = normalized.id
        appendHistory(L10n.format("imageEditor.history.hotspotUpdated", normalized.name))
        statusText = L10n.format("imageEditor.status.hotspotUpdated", normalized.name)
        return normalized
    }

    func hotspot(with id: UUID) -> ImageEditorHotspot? {
        document.hotspots.first { $0.id == id }
    }

    @discardableResult
    func selectHotspot(id: UUID) -> ImageEditorHotspot? {
        guard let hotspot = hotspot(with: id) else { return nil }
        selectedHotspotID = id
        isHotspotsPanelVisible = true
        statusText = L10n.format("imageEditor.status.hotspotSelected", hotspot.name)
        return hotspot
    }

    /// Delete the delivery object selected on the canvas or in its panel.
    /// Hotspots take precedence because they are independently selectable even
    /// while the export scope remains set to a slice.
    @discardableResult
    func deleteSelectedDeliveryObjectIfNeeded() -> Bool {
        if let hotspotID = selectedHotspotID {
            return deleteHotspot(id: hotspotID) != nil
        }
        guard exportSettings.scope == .slice,
              let sliceID = exportSettings.sliceID
        else { return false }
        return deleteSlice(id: sliceID) != nil
    }

    /// Nudge the selected delivery object by a pixel delta while keeping its
    /// original size and the whole rectangle inside the canvas.
    @discardableResult
    func nudgeSelectedDeliveryObject(by delta: CGSize) -> Bool {
        guard abs(delta.width) >= 0.1 || abs(delta.height) >= 0.1 else { return false }
        if let hotspotID = selectedHotspotID,
           let hotspot = hotspot(with: hotspotID) {
            let frame = clampedDeliveryFrame(hotspot.frame, offsetBy: delta)
            return updateHotspot(id: hotspotID, frame: frame) != nil
        }
        guard exportSettings.scope == .slice,
              let sliceID = exportSettings.sliceID,
              let slice = slice(with: sliceID)
        else { return false }
        let frame = clampedDeliveryFrame(slice.frame, offsetBy: delta)
        return updateSlice(id: sliceID, frame: frame) != nil
    }

    func clampedDeliveryFrame(_ frame: CGRect, offsetBy delta: CGSize) -> CGRect {
        let standardized = frame.standardized
        let canvasSize = document.canvasSize
        let width = min(standardized.width, canvasSize.width)
        let height = min(standardized.height, canvasSize.height)
        let maxX = max(0, canvasSize.width - width)
        let maxY = max(0, canvasSize.height - height)
        let originX = min(max(standardized.minX + delta.width, 0), maxX)
        let originY = min(max(standardized.minY + delta.height, 0), maxY)
        return CGRect(x: originX, y: originY, width: width, height: height)
    }

    var canExportHotspotHTML: Bool {
        !document.hotspots.isEmpty
    }

    func hotspotHTMLData() -> Data? {
        guard canExportHotspotHTML,
              let pngData = document.compositedImage.qingtuPNGData()
        else { return nil }
        return ImageEditorHotspotHTMLExporter.data(
            canvasSize: document.canvasSize,
            pngData: pngData,
            hotspots: document.hotspots,
            title: document.sourceName
        )
    }

    func exportHotspotHTML() {
        guard canExportHotspotHTML else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "html") ?? .plainText]
        panel.canCreateDirectories = true
        let baseName = (document.sourceName as NSString).deletingPathExtension
        let exportBaseName = baseName.isEmpty ? "xomo" : baseName
        panel.nameFieldStringValue = "\(exportBaseName).hotspots.html"
        panel.begin { [weak self] response in
            Task { @MainActor in
                guard let self, response == .OK, let url = panel.url else { return }
                do {
                    guard let data = self.hotspotHTMLData() else {
                        self.statusText = L10n.text("imageEditor.status.hotspotHTMLExportFailed")
                        return
                    }
                    try data.write(to: url, options: .atomic)
                    self.statusText = L10n.format("imageEditor.status.hotspotHTMLExported", url.lastPathComponent)
                } catch {
                    self.statusText = L10n.format(
                        "imageEditor.status.hotspotHTMLExportFailedWithReason",
                        error.localizedDescription
                    )
                }
            }
        }
    }

    private var hotspotBoundsFromSelection: CGRect? {
        guard let selection = document.selection else { return nil }
        let canvasBounds = CGRect(origin: .zero, size: document.canvasSize)
        let candidate = selection.isInverted ? canvasBounds : selection.bounds.standardized
        let bounded = candidate.intersection(canvasBounds).integral.intersection(canvasBounds)
        guard bounded.width > 0, bounded.height > 0 else { return nil }
        return bounded
    }

    private func nextHotspotName() -> String {
        let existing = Set(document.hotspots.map { $0.name.lowercased() })
        var index = document.hotspots.count + 1
        while existing.contains(L10n.format("imageEditor.hotspot.defaultName", index).lowercased()) {
            index += 1
        }
        return L10n.format("imageEditor.hotspot.defaultName", index)
    }
}

enum ImageEditorHotspotHTMLExporter {
    static func data(
        canvasSize: CGSize,
        pngData: Data,
        hotspots: [ImageEditorHotspot],
        title: String
    ) -> Data {
        let validHotspots = hotspots.compactMap { $0.normalized(canvasSize: canvasSize) }
        let areas = validHotspots.map { hotspot in
            let frame = hotspot.frame
            let coordinates = [
                Int(frame.minX.rounded()),
                Int(frame.minY.rounded()),
                Int(frame.maxX.rounded()),
                Int(frame.maxY.rounded())
            ].map(String.init).joined(separator: ",")
            let href = hotspot.url.isEmpty ? "#" : hotspot.url
            return "    <area shape=\"rect\" coords=\"\(coordinates)\" href=\"\(htmlEscaped(href))\" alt=\"\(htmlEscaped(hotspot.name))\" data-hotspot=\"\(htmlEscaped(hotspot.name))\">"
        }.joined(separator: "\n")
        let html = """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>\(htmlEscaped(title))</title>
          <style>html,body{margin:0;background:#202124}body{display:grid;place-items:center;min-height:100vh}img{max-width:100%;height:auto}</style>
        </head>
        <body>
          <img src="data:image/png;base64,\(pngData.base64EncodedString())" width="\(Int(canvasSize.width.rounded()))" height="\(Int(canvasSize.height.rounded()))" usemap="#xomo-hotspots" alt="\(htmlEscaped(title))">
          <map name="xomo-hotspots">
        \(areas)
          </map>
        </body>
        </html>
        """
        return Data(html.utf8)
    }

    private static func htmlEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
