import AppKit
import UniformTypeIdentifiers

enum ImageEditorSliceExportPresetMoveDirection {
    case up
    case down

    func destinationIndex(from index: Int) -> Int {
        switch self {
        case .up:
            index - 1
        case .down:
            index + 1
        }
    }
}

@MainActor
extension ImageEditorViewModel {
    var canCreateSliceFromSelection: Bool {
        document.slices.count < ImageEditorSlice.maximumCount && selectionDeliveryBounds != nil
    }

    var availableSlices: [ImageEditorSlice] {
        document.slices
    }

    @discardableResult
    func createSliceFromCurrentSelection(name: String? = nil) -> ImageEditorSlice? {
        guard let frame = selectionDeliveryBounds else { return nil }
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

    @discardableResult
    func addCurrentExportPreset(toSlice id: UUID) -> Bool {
        guard let index = document.slices.firstIndex(where: { $0.id == id }) else { return false }
        guard exportSettings.format.supportsSliceExportPreset else {
            statusText = L10n.text("imageEditor.status.sliceExportPresetUnsupported")
            return false
        }
        let existing = document.slices[index].exportPresets ?? []
        guard existing.count < ImageEditorSlice.maximumExportPresetCount else {
            statusText = L10n.text("imageEditor.status.sliceExportPresetLimitReached")
            return false
        }
        let scale = exportSettings.usesScale ? exportSettings.scale : 1
        let suffix = ImageEditorSliceExportPreset.defaultSuffix(forScale: scale)
        let preset = ImageEditorSliceExportPreset(
            suffix: suffix,
            format: exportSettings.format,
            constraint: .scale,
            value: scale
        )
        guard preset.resolvedScale(for: document.slices[index].frame) != nil else {
            statusText = L10n.text("imageEditor.status.sliceExportPresetInvalid")
            return false
        }
        guard !existing.contains(preset) else {
            statusText = L10n.text("imageEditor.status.sliceExportPresetUnchanged")
            return false
        }

        pushUndo()
        document.slices[index].exportPresets = existing + [preset]
        let name = document.slices[index].name
        appendHistory(L10n.format("imageEditor.history.sliceExportPresetAdded", name))
        statusText = L10n.format("imageEditor.status.sliceExportPresetAdded", name)
        return true
    }

    @discardableResult
    func removeSliceExportPreset(fromSlice id: UUID, at presetIndex: Int) -> Bool {
        guard let sliceIndex = document.slices.firstIndex(where: { $0.id == id }),
              var presets = document.slices[sliceIndex].exportPresets,
              presets.indices.contains(presetIndex)
        else { return false }

        pushUndo()
        presets.remove(at: presetIndex)
        document.slices[sliceIndex].exportPresets = presets.isEmpty ? nil : presets
        let updated = document.slices[sliceIndex]
        if exportSettings.sliceID == id {
            applyPrimaryExportPreset(for: updated)
        }
        appendHistory(L10n.format("imageEditor.history.sliceExportPresetRemoved", updated.name))
        statusText = L10n.format("imageEditor.status.sliceExportPresetRemoved", updated.name)
        return true
    }

    @discardableResult
    func moveSliceExportPreset(
        inSlice id: UUID,
        from presetIndex: Int,
        direction: ImageEditorSliceExportPresetMoveDirection
    ) -> Bool {
        guard let sliceIndex = document.slices.firstIndex(where: { $0.id == id }),
              var presets = document.slices[sliceIndex].exportPresets,
              presets.indices.contains(presetIndex)
        else { return false }
        let destination = direction.destinationIndex(from: presetIndex)
        guard presets.indices.contains(destination) else { return false }

        pushUndo()
        presets.swapAt(presetIndex, destination)
        document.slices[sliceIndex].exportPresets = presets
        let updated = document.slices[sliceIndex]
        if exportSettings.sliceID == id {
            applyPrimaryExportPreset(for: updated)
        }
        appendHistory(L10n.format("imageEditor.history.sliceExportPresetMoved", updated.name))
        statusText = L10n.format("imageEditor.status.sliceExportPresetMoved", updated.name)
        return true
    }

    @discardableResult
    func updateSliceExportPresetSuffix(
        inSlice id: UUID,
        at presetIndex: Int,
        suffix: String
    ) -> Bool {
        guard let sliceIndex = document.slices.firstIndex(where: { $0.id == id }),
              var presets = document.slices[sliceIndex].exportPresets,
              presets.indices.contains(presetIndex)
        else { return false }
        let current = presets[presetIndex]
        let updated = ImageEditorSliceExportPreset(
            suffix: suffix,
            format: current.format,
            constraint: current.constraint,
            value: current.value
        )
        guard updated != current else {
            statusText = L10n.text("imageEditor.status.sliceExportPresetUnchanged")
            return false
        }
        guard !presets.enumerated().contains(where: { index, preset in
            index != presetIndex && preset == updated
        }) else {
            statusText = L10n.text("imageEditor.status.sliceExportPresetDuplicate")
            return false
        }

        pushUndo()
        presets[presetIndex] = updated
        document.slices[sliceIndex].exportPresets = presets
        let slice = document.slices[sliceIndex]
        if exportSettings.sliceID == id && presetIndex == presets.startIndex {
            applyPrimaryExportPreset(for: slice)
        }
        appendHistory(L10n.format("imageEditor.history.sliceExportPresetSuffixUpdated", slice.name))
        statusText = L10n.format("imageEditor.status.sliceExportPresetSuffixUpdated", slice.name)
        return true
    }

    @discardableResult
    func updateSliceExportPresetFormat(
        inSlice id: UUID,
        at presetIndex: Int,
        format: ImageEditorExportFormat
    ) -> Bool {
        guard let sliceIndex = document.slices.firstIndex(where: { $0.id == id }),
              var presets = document.slices[sliceIndex].exportPresets,
              presets.indices.contains(presetIndex)
        else { return false }
        guard format.supportsSliceExportPreset else {
            statusText = L10n.text("imageEditor.status.sliceExportPresetUnsupported")
            return false
        }

        let current = presets[presetIndex]
        let updated = ImageEditorSliceExportPreset(
            suffix: current.suffix,
            format: format,
            constraint: format == .pdf ? .scale : current.constraint,
            value: format == .pdf ? 1 : current.value
        )
        guard updated != current else {
            statusText = L10n.text("imageEditor.status.sliceExportPresetUnchanged")
            return false
        }
        guard updated.resolvedScale(for: document.slices[sliceIndex].frame) != nil else {
            statusText = L10n.text("imageEditor.status.sliceExportPresetInvalid")
            return false
        }
        guard !presets.enumerated().contains(where: { index, preset in
            index != presetIndex && preset == updated
        }) else {
            statusText = L10n.text("imageEditor.status.sliceExportPresetDuplicate")
            return false
        }

        pushUndo()
        presets[presetIndex] = updated
        document.slices[sliceIndex].exportPresets = presets
        let slice = document.slices[sliceIndex]
        if exportSettings.sliceID == id && presetIndex == presets.startIndex {
            applyPrimaryExportPreset(for: slice)
        }
        appendHistory(L10n.format("imageEditor.history.sliceExportPresetFormatUpdated", slice.name))
        statusText = L10n.format("imageEditor.status.sliceExportPresetFormatUpdated", slice.name)
        return true
    }

    @discardableResult
    func changeSliceExportPresetConstraint(
        inSlice id: UUID,
        at presetIndex: Int,
        to constraint: ImageEditorSliceExportConstraint
    ) -> Bool {
        guard let slice = slice(with: id),
              let presets = slice.exportPresets,
              presets.indices.contains(presetIndex),
              let scale = presets[presetIndex].resolvedScale(for: slice.frame)
        else {
            statusText = L10n.text("imageEditor.status.sliceExportPresetInvalid")
            return false
        }
        let value: Double
        switch constraint {
        case .scale:
            value = scale
        case .width:
            value = scale * Double(slice.frame.width)
        case .height:
            value = scale * Double(slice.frame.height)
        }
        return updateSliceExportPresetDelivery(
            inSlice: id,
            at: presetIndex,
            constraint: constraint,
            value: value
        )
    }

    @discardableResult
    func updateSliceExportPresetValue(
        inSlice id: UUID,
        at presetIndex: Int,
        value: Double
    ) -> Bool {
        guard let slice = slice(with: id),
              let presets = slice.exportPresets,
              presets.indices.contains(presetIndex)
        else { return false }
        return updateSliceExportPresetDelivery(
            inSlice: id,
            at: presetIndex,
            constraint: presets[presetIndex].constraint,
            value: value
        )
    }

    private func updateSliceExportPresetDelivery(
        inSlice id: UUID,
        at presetIndex: Int,
        constraint: ImageEditorSliceExportConstraint,
        value: Double
    ) -> Bool {
        guard let sliceIndex = document.slices.firstIndex(where: { $0.id == id }),
              var presets = document.slices[sliceIndex].exportPresets,
              presets.indices.contains(presetIndex)
        else { return false }
        let current = presets[presetIndex]
        let updated = ImageEditorSliceExportPreset(
            suffix: current.suffix,
            format: current.format,
            constraint: current.format == .pdf ? .scale : constraint,
            value: current.format == .pdf ? 1 : value
        )
        guard updated.resolvedScale(for: document.slices[sliceIndex].frame) != nil else {
            statusText = L10n.text("imageEditor.status.sliceExportPresetInvalid")
            return false
        }
        guard updated != current else {
            statusText = L10n.text("imageEditor.status.sliceExportPresetUnchanged")
            return false
        }
        guard !presets.enumerated().contains(where: { index, preset in
            index != presetIndex && preset == updated
        }) else {
            statusText = L10n.text("imageEditor.status.sliceExportPresetDuplicate")
            return false
        }

        pushUndo()
        presets[presetIndex] = updated
        document.slices[sliceIndex].exportPresets = presets
        let slice = document.slices[sliceIndex]
        if exportSettings.sliceID == id && presetIndex == presets.startIndex {
            applyPrimaryExportPreset(for: slice)
        }
        appendHistory(L10n.format("imageEditor.history.sliceExportPresetDeliveryUpdated", slice.name))
        statusText = L10n.format("imageEditor.status.sliceExportPresetDeliveryUpdated", slice.name)
        return true
    }

    func syncExportSettingsAfterSliceHistoryChange(from previousSlices: [ImageEditorSlice]) {
        guard previousSlices != document.slices,
              exportSettings.scope == .slice
        else { return }
        if let id = exportSettings.sliceID, let selected = slice(with: id) {
            applyPrimaryExportPreset(for: selected)
        } else if let first = document.slices.first {
            exportSettings.sliceID = first.id
            applyPrimaryExportPreset(for: first)
        } else {
            exportSettings.scope = .composited
            exportSettings.sliceID = nil
            exportSettings.filenameSuffix = ""
        }
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
        document.hotspots.count < ImageEditorHotspot.maximumCount && selectionDeliveryBounds != nil
    }

    var availableHotspots: [ImageEditorHotspot] {
        document.hotspots
    }

    @discardableResult
    func createHotspotFromCurrentSelection(name: String? = nil, url: String? = nil) -> ImageEditorHotspot? {
        guard let frame = selectionDeliveryBounds else { return nil }
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
    var canDeleteSelectedDeliveryObject: Bool {
        if let hotspotID = selectedHotspotID {
            return document.hotspots.contains { $0.id == hotspotID }
        }
        guard exportSettings.scope == .slice,
              let sliceID = exportSettings.sliceID
        else { return false }
        return document.slices.contains { $0.id == sliceID }
    }

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

    private var selectionDeliveryBounds: CGRect? {
        guard let selection = document.selection else { return nil }
        let canvasBounds = CGRect(origin: .zero, size: document.canvasSize)
        guard let selectedBounds = selection.effectiveSelectedBounds(in: document.canvasSize) else { return nil }
        let bounded = selectedBounds.standardized
            .intersection(canvasBounds)
            .integral
            .intersection(canvasBounds)
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
    private static let allowedHrefSchemes = Set(["http", "https", "mailto", "tel"])

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
            let href = safeHref(hotspot.url)
            return "    <area shape=\"rect\" coords=\"\(coordinates)\" data-original-coords=\"\(coordinates)\" href=\"\(htmlEscaped(href))\" alt=\"\(htmlEscaped(hotspot.name))\" data-hotspot=\"\(htmlEscaped(hotspot.name))\">"
        }.joined(separator: "\n")
        let originalWidth = Int(canvasSize.width.rounded())
        let originalHeight = Int(canvasSize.height.rounded())
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
          <img src="data:image/png;base64,\(pngData.base64EncodedString())" width="\(originalWidth)" height="\(originalHeight)" data-original-width="\(originalWidth)" data-original-height="\(originalHeight)" usemap="#xomo-hotspots" alt="\(htmlEscaped(title))">
          <map name="xomo-hotspots">
        \(areas)
          </map>
          <script>
          (() => {
            const image = document.querySelector('img[usemap="#xomo-hotspots"]');
            const map = document.querySelector('map[name="xomo-hotspots"]');
            if (!image || !map) return;
            const originalWidth = Number(image.dataset.originalWidth);
            const originalHeight = Number(image.dataset.originalHeight);
            if (!(originalWidth > 0) || !(originalHeight > 0)) return;
            const updateHotspotCoordinates = () => {
              const scaleX = image.getBoundingClientRect().width / originalWidth;
              const scaleY = image.getBoundingClientRect().height / originalHeight;
              if (!(scaleX > 0) || !(scaleY > 0)) return;
              map.querySelectorAll("area[data-original-coords]").forEach((area) => {
                const originalCoordinates = area.dataset.originalCoords
                  .split(",")
                  .map(Number);
                if (originalCoordinates.length !== 4 || originalCoordinates.some(Number.isNaN)) return;
                area.coords = originalCoordinates
                  .map((coordinate, index) => Math.round(coordinate * (index % 2 === 0 ? scaleX : scaleY)))
                  .join(",");
              });
            };
            image.addEventListener("load", updateHotspotCoordinates);
            window.addEventListener("resize", updateHotspotCoordinates);
            if ("ResizeObserver" in window) {
              new ResizeObserver(updateHotspotCoordinates).observe(image);
            }
            updateHotspotCoordinates();
          })();
          </script>
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

    private static func safeHref(_ value: String) -> String {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty,
              trimmedValue.rangeOfCharacter(from: .controlCharacters) == nil,
              let components = URLComponents(string: trimmedValue) else {
            return "#"
        }
        if let scheme = components.scheme {
            return allowedHrefSchemes.contains(scheme.lowercased()) ? trimmedValue : "#"
        }
        guard components.host == nil,
              !trimmedValue.hasPrefix("//"),
              !trimmedValue.hasPrefix("\\\\") else {
            return "#"
        }
        return trimmedValue
    }
}
