import AppKit

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
        document.slices.append(slice)
        exportSettings.scope = .slice
        exportSettings.sliceID = slice.id
        appendHistory(L10n.format("imageEditor.history.sliceCreated", slice.name))
        statusText = L10n.format("imageEditor.status.sliceCreated", slice.name)
        return slice
    }

    @discardableResult
    func deleteSlice(id: UUID) -> ImageEditorSlice? {
        guard let index = document.slices.firstIndex(where: { $0.id == id }) else { return nil }
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

    func slice(with id: UUID) -> ImageEditorSlice? {
        document.slices.first { $0.id == id }
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
        document.hotspots.append(hotspot)
        appendHistory(L10n.format("imageEditor.history.hotspotCreated", hotspot.name))
        statusText = L10n.format("imageEditor.status.hotspotCreated", hotspot.name)
        return hotspot
    }

    @discardableResult
    func deleteHotspot(id: UUID) -> ImageEditorHotspot? {
        guard let index = document.hotspots.firstIndex(where: { $0.id == id }) else { return nil }
        let removed = document.hotspots.remove(at: index)
        appendHistory(L10n.format("imageEditor.history.hotspotDeleted", removed.name))
        statusText = L10n.format("imageEditor.status.hotspotDeleted", removed.name)
        return removed
    }

    func hotspot(with id: UUID) -> ImageEditorHotspot? {
        document.hotspots.first { $0.id == id }
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
