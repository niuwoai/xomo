//
//  ImageEditorLayerComps.swift
//  veilpic
//
//  Created by Codex on 2026/7/9.
//

import AppKit
import Foundation

enum ImageEditorLayerCompDropPlacement: Equatable {
    case above
    case below
}

enum ImageEditorLayerCompDragOperation: String, Equatable {
    case move
    case copy
}

struct ImageEditorLayerCompDragPayload: Equatable {
    private static let prefix = "xomo-layer-comp"

    var layerCompID: UUID
    var operation: ImageEditorLayerCompDragOperation

    var serialized: String {
        "\(Self.prefix):\(operation.rawValue):\(layerCompID.uuidString)"
    }

    static func parse(_ value: String) -> ImageEditorLayerCompDragPayload? {
        let parts = value.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 3,
              String(parts[0]) == prefix,
              let operation = ImageEditorLayerCompDragOperation(rawValue: String(parts[1])),
              let layerCompID = UUID(uuidString: String(parts[2]))
        else { return nil }
        return ImageEditorLayerCompDragPayload(
            layerCompID: layerCompID,
            operation: operation
        )
    }
}

struct ImageEditorLayerCompDropTarget: Equatable {
    var layerCompID: UUID
    var placement: ImageEditorLayerCompDropPlacement
}

struct ImageEditorLayerCompCaptureOptions: Equatable {
    var capturesVisibility = true
    var capturesPosition = true
    var capturesAppearance = true

    static let classic = ImageEditorLayerCompCaptureOptions()

    static var storedDefaults: ImageEditorLayerCompCaptureOptions {
        ImageEditorLayerCompCaptureDefaults.load()
    }
}

enum ImageEditorLayerCompCaptureDefaults {
    static let visibilityKey = "xomo.imageEditor.layerComp.defaultCapturesVisibility"
    static let positionKey = "xomo.imageEditor.layerComp.defaultCapturesPosition"
    static let appearanceKey = "xomo.imageEditor.layerComp.defaultCapturesAppearance"

    static func load(from defaults: UserDefaults = .standard) -> ImageEditorLayerCompCaptureOptions {
        ImageEditorLayerCompCaptureOptions(
            capturesVisibility: bool(forKey: visibilityKey, from: defaults),
            capturesPosition: bool(forKey: positionKey, from: defaults),
            capturesAppearance: bool(forKey: appearanceKey, from: defaults)
        )
    }

    private static func bool(forKey key: String, from defaults: UserDefaults) -> Bool {
        defaults.object(forKey: key).map { _ in defaults.bool(forKey: key) } ?? true
    }
}

enum ImageEditorLayerCompNavigationDirection: Equatable {
    case previous
    case next
}

enum ImageEditorLayerCompSearchScope: CaseIterable, Equatable, Hashable {
    case all
    case name
    case comment
}

enum ImageEditorLayerCompSearch {
    private struct Term: Equatable {
        var value: String
        var isExcluded: Bool
        var scope: ImageEditorLayerCompSearchScope
    }

    private static let namePrefix = "name:"
    private static let commentPrefix = "comment:"

    static func hasTerms(_ query: String) -> Bool {
        !terms(in: query).isEmpty
    }

    static func filtered(
        _ layerComps: [ImageEditorLayerComp],
        matching query: String,
        scope: ImageEditorLayerCompSearchScope = .all,
        favoritesOnly: Bool = false
    ) -> [ImageEditorLayerComp] {
        let eligibleLayerComps = favoritesOnly
            ? layerComps.filter(\.isFavorite)
            : layerComps
        let terms = terms(in: query, defaultScope: scope)
        guard !terms.isEmpty else { return eligibleLayerComps }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]
        return eligibleLayerComps.filter { comp in
            return terms.allSatisfy { term in
                let searchableText: String
                switch term.scope {
                case .all:
                    searchableText = "\(comp.name)\n\(comp.comment)"
                case .name:
                    searchableText = comp.name
                case .comment:
                    searchableText = comp.comment
                }
                let containsTerm = searchableText.range(of: term.value, options: options) != nil
                return term.isExcluded ? !containsTerm : containsTerm
            }
        }
    }

    static func navigationTarget(
        direction: ImageEditorLayerCompNavigationDirection,
        layerComps: [ImageEditorLayerComp],
        query: String,
        scope: ImageEditorLayerCompSearchScope = .all,
        favoritesOnly: Bool = false,
        selectedLayerCompID: UUID?
    ) -> UUID? {
        guard let selectedLayerCompID else { return nil }
        let filteredIDs = filtered(
            layerComps,
            matching: query,
            scope: scope,
            favoritesOnly: favoritesOnly
        ).map(\.id)
        guard !filteredIDs.isEmpty else { return nil }
        guard let selectedIndex = filteredIDs.firstIndex(of: selectedLayerCompID) else {
            return direction == .previous ? filteredIDs.last : filteredIDs.first
        }
        switch direction {
        case .previous:
            guard selectedIndex > filteredIDs.startIndex else { return nil }
            return filteredIDs[filteredIDs.index(before: selectedIndex)]
        case .next:
            let nextIndex = filteredIDs.index(after: selectedIndex)
            guard nextIndex < filteredIDs.endIndex else { return nil }
            return filteredIDs[nextIndex]
        }
    }

    static func preferredResultID(
        in layerComps: [ImageEditorLayerComp],
        matching query: String,
        scope: ImageEditorLayerCompSearchScope = .all,
        favoritesOnly: Bool = false,
        selectedLayerCompID: UUID?
    ) -> UUID? {
        guard hasTerms(query) || favoritesOnly else { return nil }
        let results = filtered(
            layerComps,
            matching: query,
            scope: scope,
            favoritesOnly: favoritesOnly
        )
        if let selectedLayerCompID,
           results.contains(where: { $0.id == selectedLayerCompID }) {
            return selectedLayerCompID
        }
        return results.first?.id
    }

    static func selectionTarget(
        direction: ImageEditorLayerCompNavigationDirection,
        layerComps: [ImageEditorLayerComp],
        query: String,
        scope: ImageEditorLayerCompSearchScope = .all,
        favoritesOnly: Bool = false,
        selectedLayerCompID: UUID?
    ) -> UUID? {
        guard hasTerms(query) || favoritesOnly else { return nil }
        let filteredIDs = filtered(
            layerComps,
            matching: query,
            scope: scope,
            favoritesOnly: favoritesOnly
        ).map(\.id)
        guard !filteredIDs.isEmpty else { return nil }
        guard let selectedLayerCompID,
              let selectedIndex = filteredIDs.firstIndex(of: selectedLayerCompID)
        else {
            return direction == .previous ? filteredIDs.last : filteredIDs.first
        }
        switch direction {
        case .previous:
            guard selectedIndex > filteredIDs.startIndex else { return nil }
            return filteredIDs[filteredIDs.index(before: selectedIndex)]
        case .next:
            let nextIndex = filteredIDs.index(after: selectedIndex)
            guard nextIndex < filteredIDs.endIndex else { return nil }
            return filteredIDs[nextIndex]
        }
    }

    private static func terms(
        in query: String,
        defaultScope: ImageEditorLayerCompSearchScope = .all
    ) -> [Term] {
        var rawTerms: [String] = []
        var current = ""
        var isInsideQuotes = false
        var isEscaping = false
        for character in query {
            if isEscaping {
                current.append(character)
                isEscaping = false
            } else if character == "\\" {
                isEscaping = true
            } else if character == "\"" {
                isInsideQuotes.toggle()
            } else if character.isWhitespace, !isInsideQuotes {
                if !current.isEmpty {
                    rawTerms.append(current)
                    current = ""
                }
            } else {
                current.append(character)
            }
        }
        if isEscaping {
            current.append("\\")
        }
        if !current.isEmpty {
            rawTerms.append(current)
        }

        return rawTerms.compactMap { rawTerm in
            var value = rawTerm
            let isExcluded = value.first == "-" && value.count > 1
            if isExcluded {
                value.removeFirst()
            }
            value = value.trimmingCharacters(in: .whitespacesAndNewlines)
            let scope: ImageEditorLayerCompSearchScope
            let lowercaseValue = value.lowercased()
            if lowercaseValue.hasPrefix(namePrefix) {
                value.removeFirst(namePrefix.count)
                scope = .name
            } else if lowercaseValue.hasPrefix(commentPrefix) {
                value.removeFirst(commentPrefix.count)
                scope = .comment
            } else {
                scope = defaultScope
            }
            value = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, value != "-" else { return nil }
            return Term(value: value, isExcluded: isExcluded, scope: scope)
        }
    }
}

enum ImageEditorLayerCompDropGeometry {
    static func destinationIndex(
        sourceIndex: Int,
        targetIndex: Int,
        placement: ImageEditorLayerCompDropPlacement,
        count: Int
    ) -> Int? {
        guard count > 1,
              (0..<count).contains(sourceIndex),
              (0..<count).contains(targetIndex)
        else { return nil }

        var destinationIndex = targetIndex + (placement == .below ? 1 : 0)
        if sourceIndex < destinationIndex {
            destinationIndex -= 1
        }
        guard destinationIndex != sourceIndex,
              (0..<count).contains(destinationIndex)
        else { return nil }
        return destinationIndex
    }

    static func copyInsertionIndex(
        targetIndex: Int,
        placement: ImageEditorLayerCompDropPlacement,
        count: Int
    ) -> Int? {
        guard count > 0, (0..<count).contains(targetIndex) else { return nil }
        return targetIndex + (placement == .below ? 1 : 0)
    }
}

enum ImageEditorLayerCompApplication {
    private static let scalarTolerance = 0.000_001

    static func hasMatchingLayers(
        _ comp: ImageEditorLayerComp,
        in document: ImageEditorDocument
    ) -> Bool {
        let capturedLayerIDs = Set(comp.layerStates.map(\.layerID))
        return document.layers.contains { capturedLayerIDs.contains($0.id) }
    }

    static func matchesCurrentDocument(
        _ comp: ImageEditorLayerComp,
        in document: ImageEditorDocument
    ) -> Bool {
        guard document.selectedLayerCompID == comp.id else { return false }
        let layersByID = Dictionary(uniqueKeysWithValues: document.layers.map { ($0.id, $0) })
        let existingLayerIDs = Set(layersByID.keys)
        let existingGroupIDs = Set(document.layers.filter(\.isGroup).map(\.id))
        guard comp.layerStates.allSatisfy({ state in
            guard let layer = layersByID[state.layerID] else { return false }
            return layerMatches(
                layer,
                state: state,
                comp: comp,
                existingLayerIDs: existingLayerIDs,
                existingGroupIDs: existingGroupIDs
            )
        }) else { return false }
        guard expectedLayerOrder(comp.layerOrder, in: document) == document.layers.map(\.id) else {
            return false
        }

        let expectedSelectedLayerID = comp.selectedLayerID.flatMap {
            existingLayerIDs.contains($0) ? $0 : nil
        } ?? document.selectedLayerID.flatMap {
            existingLayerIDs.contains($0) ? $0 : nil
        } ?? document.layers.last?.id
        var expectedSelectedLayerIDs = comp.selectedLayerIDs.intersection(existingLayerIDs)
        if let expectedSelectedLayerID {
            expectedSelectedLayerIDs.insert(expectedSelectedLayerID)
        }
        return document.selectedLayerID == expectedSelectedLayerID
            && document.selectedLayerIDs == expectedSelectedLayerIDs
    }

    static func apply(
        _ comp: ImageEditorLayerComp,
        to document: inout ImageEditorDocument,
        selectedLayerCompID: UUID?
    ) {
        let statesByLayerID = Dictionary(uniqueKeysWithValues: comp.layerStates.map { ($0.layerID, $0) })
        let existingLayerIDs = Set(document.layers.map(\.id))
        let existingGroupIDs = Set(document.layers.filter(\.isGroup).map(\.id))
        for index in document.layers.indices {
            guard let state = statesByLayerID[document.layers[index].id] else { continue }
            if comp.capturesVisibility {
                document.layers[index].isVisible = state.isVisible
            }
            if comp.capturesPosition {
                document.layers[index].frame = state.frame
            }
            document.layers[index].opacity = max(0, min(1, state.opacity))
            document.layers[index].fillOpacity = max(0, min(1, state.fillOpacity))
            document.layers[index].isMaskLinked = state.isMaskLinked
            document.layers[index].blendIfSourceBlack = max(0, min(1, state.blendIfSourceBlack))
            document.layers[index].blendIfSourceWhite = max(
                document.layers[index].blendIfSourceBlack,
                min(1, state.blendIfSourceWhite)
            )
            document.layers[index].blendIfUnderlyingBlack = max(0, min(1, state.blendIfUnderlyingBlack))
            document.layers[index].blendIfUnderlyingWhite = max(
                document.layers[index].blendIfUnderlyingBlack,
                min(1, state.blendIfUnderlyingWhite)
            )
            document.layers[index].isMaskEnabled = state.isMaskEnabled
            document.layers[index].maskDensity = max(0, min(1, state.maskDensity))
            document.layers[index].maskFeather = max(0, min(80, state.maskFeather))
            document.layers[index].maskFeatherSamplingScale = state.maskFeatherSamplingScale
            if state.hasMaskSnapshot {
                if let maskData = state.maskData {
                    if let mask = NSImage(data: maskData)?.normalizedBitmapImage() {
                        document.layers[index].mask = mask
                    }
                } else {
                    document.layers[index].mask = nil
                }
            }
            document.layers[index].isVectorMaskEnabled = state.isVectorMaskEnabled
            document.layers[index].isVectorMaskInverted = state.isVectorMaskInverted
            if comp.capturesAppearance {
                document.layers[index].style = state.style.layerStyle
                document.layers[index].blendMode = state.blendMode
            }
            if let kind = state.kind {
                document.layers[index].kind = kind.layerKind
            }
            if let smartFilters = state.smartFilters {
                document.layers[index].smartFilters = smartFilters
            }
            if let adjustmentSettings = state.adjustmentSettings {
                document.layers[index].adjustmentSettings = adjustmentSettings.normalized()
            }
            if let filterSettings = state.filterSettings {
                document.layers[index].filterSettings = filterSettings.normalized()
            }
            if state.hasVectorMaskSnapshot {
                document.layers[index].vectorMask = state.vectorMask?.content
            }
            document.layers[index].linkedLayerIDs = state.linkedLayerIDs
                .intersection(existingLayerIDs)
                .subtracting([document.layers[index].id])
            if let groupID = state.groupID,
               groupID != document.layers[index].id,
               existingGroupIDs.contains(groupID) {
                document.layers[index].groupID = groupID
            } else {
                document.layers[index].groupID = nil
            }
            document.layers[index].isLocked = state.isLocked
            document.layers[index].locksPixels = state.locksPixels
            document.layers[index].locksPosition = state.locksPosition
            document.layers[index].locksTransparentPixels = state.locksTransparentPixels
            document.layers[index].isGroupExpanded = state.isGroupExpanded
            document.layers[index].isClippingMask = state.isClippingMask
            document.layers[index].labelColor = state.labelColor
        }

        restoreLayerOrder(comp.layerOrder, in: &document)
        let remainingLayerIDs = Set(document.layers.map(\.id))
        document.selectedLayerID = comp.selectedLayerID.flatMap { remainingLayerIDs.contains($0) ? $0 : nil }
            ?? document.selectedLayerID.flatMap { remainingLayerIDs.contains($0) ? $0 : nil }
            ?? document.layers.last?.id
        document.selectedLayerIDs = comp.selectedLayerIDs.intersection(remainingLayerIDs)
        if let selectedLayerID = document.selectedLayerID {
            document.selectedLayerIDs.insert(selectedLayerID)
        }
        document.selectedLayerCompID = selectedLayerCompID
    }

    private static func restoreLayerOrder(
        _ layerOrder: [UUID],
        in document: inout ImageEditorDocument
    ) {
        let orderIndexByID = Dictionary(uniqueKeysWithValues: layerOrder.enumerated().map {
            ($0.element, $0.offset)
        })
        guard !orderIndexByID.isEmpty else { return }
        let capturedLayers = document.layers
            .filter { orderIndexByID[$0.id] != nil }
            .sorted { left, right in
                (orderIndexByID[left.id] ?? Int.max) < (orderIndexByID[right.id] ?? Int.max)
            }
        let uncapturedLayers = document.layers.filter { orderIndexByID[$0.id] == nil }
        document.layers = capturedLayers + uncapturedLayers
    }

    private static func expectedLayerOrder(
        _ layerOrder: [UUID],
        in document: ImageEditorDocument
    ) -> [UUID] {
        let orderIndexByID = Dictionary(uniqueKeysWithValues: layerOrder.enumerated().map {
            ($0.element, $0.offset)
        })
        guard !orderIndexByID.isEmpty else { return document.layers.map(\.id) }
        let capturedIDs = document.layers
            .filter { orderIndexByID[$0.id] != nil }
            .sorted { left, right in
                (orderIndexByID[left.id] ?? Int.max) < (orderIndexByID[right.id] ?? Int.max)
            }
            .map(\.id)
        let uncapturedIDs = document.layers.filter { orderIndexByID[$0.id] == nil }.map(\.id)
        return capturedIDs + uncapturedIDs
    }

    private static func layerMatches(
        _ layer: ImageEditorLayer,
        state: ImageEditorLayerCompLayerState,
        comp: ImageEditorLayerComp,
        existingLayerIDs: Set<UUID>,
        existingGroupIDs: Set<UUID>
    ) -> Bool {
        if comp.capturesVisibility, layer.isVisible != state.isVisible { return false }
        if comp.capturesPosition, !rectMatches(layer.frame, state.frame) { return false }
        guard scalarMatches(layer.opacity, max(0, min(1, state.opacity))),
              scalarMatches(layer.fillOpacity, max(0, min(1, state.fillOpacity))),
              layer.isMaskLinked == state.isMaskLinked,
              scalarMatches(layer.blendIfSourceBlack, max(0, min(1, state.blendIfSourceBlack))),
              scalarMatches(
                  layer.blendIfSourceWhite,
                  max(layer.blendIfSourceBlack, min(1, state.blendIfSourceWhite))
              ),
              scalarMatches(
                  layer.blendIfUnderlyingBlack,
                  max(0, min(1, state.blendIfUnderlyingBlack))
              ),
              scalarMatches(
                  layer.blendIfUnderlyingWhite,
                  max(layer.blendIfUnderlyingBlack, min(1, state.blendIfUnderlyingWhite))
              ),
              layer.isMaskEnabled == state.isMaskEnabled,
              scalarMatches(layer.maskDensity, max(0, min(1, state.maskDensity))),
              scalarMatches(layer.maskFeather, max(0, min(80, state.maskFeather))),
              scalarMatches(ImageEditorMaskSampling.featherScale(layer.maskFeatherSamplingScale), ImageEditorMaskSampling.featherScale(state.maskFeatherSamplingScale)),
              maskMatches(layer.mask, state: state),
              layer.isVectorMaskEnabled == state.isVectorMaskEnabled,
              layer.isVectorMaskInverted == state.isVectorMaskInverted
        else { return false }
        if comp.capturesAppearance {
            guard ImageEditorProjectLayerStyle(style: layer.style) == state.style,
                  layer.blendMode == state.blendMode
            else { return false }
        }
        if let kind = state.kind, ImageEditorProjectLayerKind(kind: layer.kind) != kind { return false }
        if let smartFilters = state.smartFilters, layer.smartFilters != smartFilters { return false }
        if let adjustmentSettings = state.adjustmentSettings,
           layer.adjustmentSettings != adjustmentSettings.normalized() {
            return false
        }
        if let filterSettings = state.filterSettings,
           layer.filterSettings != filterSettings.normalized() {
            return false
        }
        if state.hasVectorMaskSnapshot,
           layer.vectorMask.map(ImageEditorProjectShapeContent.init(content:)) != state.vectorMask {
            return false
        }
        let expectedLinkedLayerIDs = state.linkedLayerIDs
            .intersection(existingLayerIDs)
            .subtracting([layer.id])
        let expectedGroupID = state.groupID.flatMap { groupID in
            groupID != layer.id && existingGroupIDs.contains(groupID) ? groupID : nil
        }
        return layer.linkedLayerIDs == expectedLinkedLayerIDs
            && layer.groupID == expectedGroupID
            && layer.isLocked == state.isLocked
            && layer.locksPixels == state.locksPixels
            && layer.locksPosition == state.locksPosition
            && layer.locksTransparentPixels == state.locksTransparentPixels
            && layer.isGroupExpanded == state.isGroupExpanded
            && layer.isClippingMask == state.isClippingMask
            && layer.labelColor == state.labelColor
    }

    private static func maskMatches(
        _ mask: NSImage?,
        state: ImageEditorLayerCompLayerState
    ) -> Bool {
        guard state.hasMaskSnapshot else { return true }
        guard let stateData = state.maskData else { return mask == nil }
        return mask?.qingtuPNGData() == stateData
    }

    private static func scalarMatches(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) <= scalarTolerance
    }

    private static func rectMatches(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        scalarMatches(Double(lhs.origin.x), Double(rhs.origin.x))
            && scalarMatches(Double(lhs.origin.y), Double(rhs.origin.y))
            && scalarMatches(Double(lhs.size.width), Double(rhs.size.width))
            && scalarMatches(Double(lhs.size.height), Double(rhs.size.height))
    }
}

@MainActor
extension ImageEditorViewModel {
    var selectedLayerComp: ImageEditorLayerComp? {
        guard let selectedLayerCompID = document.selectedLayerCompID else { return nil }
        return document.layerComps.first { $0.id == selectedLayerCompID }
    }

    var canApplySelectedLayerComp: Bool {
        guard let selectedLayerComp else { return false }
        return !ImageEditorLayerCompApplication.matchesCurrentDocument(
            selectedLayerComp,
            in: document
        )
    }

    var canUpdateSelectedLayerComp: Bool {
        selectedLayerComp != nil
    }

    var canDuplicateSelectedLayerComp: Bool {
        selectedLayerComp != nil
    }

    var canDeleteSelectedLayerComp: Bool {
        selectedLayerComp != nil
    }

    var canRestoreLastDocumentLayerCompState: Bool {
        lastDocumentLayerCompState != nil
    }

    func isLayerCompApplied(_ id: UUID) -> Bool {
        guard document.selectedLayerCompID == id,
              let comp = document.layerComps.first(where: { $0.id == id })
        else { return false }
        return ImageEditorLayerCompApplication.matchesCurrentDocument(comp, in: document)
    }

    var canClearSelectedLayerCompWarning: Bool {
        selectedLayerComp.map { !unresolvedMissingLayerIDs(for: $0).isEmpty } ?? false
    }

    var canClearAllLayerCompWarnings: Bool {
        document.layerComps.contains { !unresolvedMissingLayerIDs(for: $0).isEmpty }
    }

    var canMoveSelectedLayerCompToTop: Bool {
        selectedLayerComp.map { canMoveLayerCompToTop($0.id) } ?? false
    }

    var canMoveSelectedLayerCompUp: Bool {
        selectedLayerComp.map { canMoveLayerCompUp($0.id) } ?? false
    }

    var canMoveSelectedLayerCompDown: Bool {
        selectedLayerComp.map { canMoveLayerCompDown($0.id) } ?? false
    }

    var canMoveSelectedLayerCompToBottom: Bool {
        selectedLayerComp.map { canMoveLayerCompToBottom($0.id) } ?? false
    }

    var canSelectPreviousLayerComp: Bool {
        layerCompNavigationTarget(.previous, matching: "") != nil
    }

    var canSelectNextLayerComp: Bool {
        layerCompNavigationTarget(.next, matching: "") != nil
    }

    var isSelectedLayerCompFavorite: Bool {
        selectedLayerComp?.isFavorite == true
    }

    var canToggleSelectedLayerCompFavorite: Bool {
        selectedLayerComp != nil
    }

    var canSelectPreviousFavoriteLayerComp: Bool {
        layerCompNavigationTarget(
            .previous,
            matching: "",
            favoritesOnly: true
        ) != nil
    }

    var canSelectNextFavoriteLayerComp: Bool {
        layerCompNavigationTarget(
            .next,
            matching: "",
            favoritesOnly: true
        ) != nil
    }

    func addLayerComp(
        named proposedName: String? = nil,
        captureOptions: ImageEditorLayerCompCaptureOptions = .classic
    ) {
        let name = normalizedLayerCompName(proposedName, fallbackIndex: document.layerComps.count + 1)
        pushUndo()
        var comp = ImageEditorLayerComp.capture(name: name, document: document)
        comp.capturesVisibility = captureOptions.capturesVisibility
        comp.capturesPosition = captureOptions.capturesPosition
        comp.capturesAppearance = captureOptions.capturesAppearance
        document.layerComps.append(comp)
        document.selectedLayerCompID = comp.id
        appendHistory(L10n.text("imageEditor.history.layerCompNew"))
        statusText = L10n.format("imageEditor.status.layerCompSaved", comp.name)
    }

    @discardableResult
    func applyLayerComp(_ id: UUID) -> Bool {
        guard let comp = document.layerComps.first(where: { $0.id == id }) else { return false }
        guard layerCompHasMatchingLayers(comp) else {
            statusText = L10n.text("imageEditor.status.layerCompNoMatchingLayers")
            return false
        }
        guard !ImageEditorLayerCompApplication.matchesCurrentDocument(comp, in: document) else {
            return false
        }
        if lastDocumentLayerCompState == nil {
            lastDocumentLayerCompState = ImageEditorLayerComp.capture(
                name: L10n.text("imageEditor.layerComp.lastDocumentState"),
                document: document
            )
        }
        applyLayerCompState(
            comp,
            selectedLayerCompID: comp.id,
            historyKey: "imageEditor.history.layerCompApply",
            statusText: L10n.format("imageEditor.status.layerCompApplied", comp.name)
        )
        return true
    }

    @discardableResult
    func restoreLastDocumentLayerCompState() -> Bool {
        guard let state = lastDocumentLayerCompState else { return false }
        guard layerCompHasMatchingLayers(state) else {
            statusText = L10n.text("imageEditor.status.layerCompNoMatchingLayers")
            return false
        }
        applyLayerCompState(
            state,
            selectedLayerCompID: nil,
            historyKey: "imageEditor.history.layerCompRestoreLastDocumentState",
            statusText: L10n.text("imageEditor.status.layerCompRestoredLastDocumentState")
        )
        lastDocumentLayerCompState = nil
        return true
    }

    private func applyLayerCompState(
        _ comp: ImageEditorLayerComp,
        selectedLayerCompID: UUID?,
        historyKey: String,
        statusText finalStatusText: String
    ) {
        pushUndo()
        ImageEditorLayerCompApplication.apply(
            comp,
            to: &document,
            selectedLayerCompID: selectedLayerCompID
        )
        isEditingLayerMask = false
        appendHistory(L10n.text(historyKey))
        statusText = finalStatusText
    }

    func applySelectedLayerComp() {
        guard let selectedLayerComp else { return }
        applyLayerComp(selectedLayerComp.id)
    }

    func updateLayerComp(_ id: UUID) {
        guard let index = document.layerComps.firstIndex(where: { $0.id == id }) else { return }
        let existing = document.layerComps[index]
        let name = existing.name
        var updated = ImageEditorLayerComp.capture(name: name, document: document)
        updated.id = id
        updated.comment = existing.comment
        updated.isFavorite = existing.isFavorite
        updated.capturesVisibility = existing.capturesVisibility
        updated.capturesPosition = existing.capturesPosition
        updated.capturesAppearance = existing.capturesAppearance
        updated.acknowledgedMissingLayerIDs = []
        updated.createdAt = existing.createdAt
        guard updated != existing else {
            statusText = L10n.format("imageEditor.status.layerCompUnchanged", name)
            return
        }
        pushUndo()
        document.layerComps[index] = updated
        document.selectedLayerCompID = id
        appendHistory(L10n.text("imageEditor.history.layerCompUpdate"))
        statusText = L10n.format("imageEditor.status.layerCompUpdated", name)
    }

    func updateSelectedLayerComp() {
        guard let selectedLayerComp else { return }
        updateLayerComp(selectedLayerComp.id)
    }

    func duplicateSelectedLayerComp() {
        guard let selectedLayerComp else { return }
        _ = duplicateLayerComp(selectedLayerComp.id)
    }

    @discardableResult
    func duplicateLayerComp(_ id: UUID) -> ImageEditorLayerComp? {
        guard let sourceIndex = document.layerComps.firstIndex(where: { $0.id == id }) else {
            return nil
        }
        return duplicateLayerComp(id, toIndex: sourceIndex + 1)
    }

    @discardableResult
    func duplicateLayerComp(
        _ id: UUID,
        toIndex destinationIndex: Int
    ) -> ImageEditorLayerComp? {
        guard let sourceIndex = document.layerComps.firstIndex(where: { $0.id == id }),
              (0...document.layerComps.count).contains(destinationIndex)
        else { return nil }
        let source = document.layerComps[sourceIndex]
        pushUndo()
        var duplicated = source
        duplicated.id = UUID()
        duplicated.name = duplicateLayerCompName(for: source.name)
        duplicated.createdAt = Date()
        document.layerComps.insert(duplicated, at: destinationIndex)
        document.selectedLayerCompID = duplicated.id
        appendHistory(L10n.text("imageEditor.history.layerCompDuplicate"))
        statusText = L10n.format("imageEditor.status.layerCompDuplicated", duplicated.name)
        return duplicated
    }

    func renameLayerComp(_ id: UUID, to proposedName: String) {
        guard let index = document.layerComps.firstIndex(where: { $0.id == id }) else { return }
        let trimmedName = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            statusText = L10n.text("imageEditor.status.layerCompNameInvalid")
            return
        }
        guard document.layerComps[index].name != trimmedName else { return }
        pushUndo()
        document.layerComps[index].name = trimmedName
        document.selectedLayerCompID = id
        appendHistory(L10n.text("imageEditor.history.layerCompRename"))
        statusText = L10n.format("imageEditor.status.layerCompRenamed", trimmedName)
    }

    @discardableResult
    func updateLayerCompComment(_ id: UUID, to proposedComment: String) -> Bool {
        guard let index = document.layerComps.firstIndex(where: { $0.id == id }) else {
            return false
        }
        let comment = proposedComment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard document.layerComps[index].comment != comment else { return false }
        pushUndo()
        document.layerComps[index].comment = comment
        document.selectedLayerCompID = id
        appendHistory(L10n.text("imageEditor.history.layerCompComment"))
        statusText = L10n.format(
            comment.isEmpty
                ? "imageEditor.status.layerCompCommentCleared"
                : "imageEditor.status.layerCompCommentUpdated",
            document.layerComps[index].name
        )
        return true
    }

    @discardableResult
    func setLayerCompFavorite(_ id: UUID, isFavorite: Bool) -> Bool {
        guard let index = document.layerComps.firstIndex(where: { $0.id == id }),
              document.layerComps[index].isFavorite != isFavorite
        else { return false }
        pushUndo()
        document.layerComps[index].isFavorite = isFavorite
        document.selectedLayerCompID = id
        appendHistory(L10n.text(
            isFavorite
                ? "imageEditor.history.layerCompFavoriteAdd"
                : "imageEditor.history.layerCompFavoriteRemove"
        ))
        statusText = L10n.format(
            isFavorite
                ? "imageEditor.status.layerCompFavoriteAdded"
                : "imageEditor.status.layerCompFavoriteRemoved",
            document.layerComps[index].name
        )
        return true
    }

    @discardableResult
    func toggleSelectedLayerCompFavorite() -> Bool {
        guard let selectedLayerComp else { return false }
        return setLayerCompFavorite(
            selectedLayerComp.id,
            isFavorite: !selectedLayerComp.isFavorite
        )
    }

    @discardableResult
    func setLayerCompCapturesVisibility(_ id: UUID, enabled: Bool) -> Bool {
        guard let index = document.layerComps.firstIndex(where: { $0.id == id }),
              document.layerComps[index].capturesVisibility != enabled
        else { return false }
        pushUndo()
        document.layerComps[index].capturesVisibility = enabled
        document.selectedLayerCompID = id
        appendHistory(L10n.text("imageEditor.history.layerCompCaptureVisibility"))
        statusText = L10n.format(
            enabled
                ? "imageEditor.status.layerCompCaptureVisibilityEnabled"
                : "imageEditor.status.layerCompCaptureVisibilityDisabled",
            document.layerComps[index].name
        )
        return true
    }

    @discardableResult
    func setLayerCompCapturesPosition(_ id: UUID, enabled: Bool) -> Bool {
        guard let index = document.layerComps.firstIndex(where: { $0.id == id }),
              document.layerComps[index].capturesPosition != enabled
        else { return false }
        pushUndo()
        document.layerComps[index].capturesPosition = enabled
        document.selectedLayerCompID = id
        appendHistory(L10n.text("imageEditor.history.layerCompCapturePosition"))
        statusText = L10n.format(
            enabled
                ? "imageEditor.status.layerCompCapturePositionEnabled"
                : "imageEditor.status.layerCompCapturePositionDisabled",
            document.layerComps[index].name
        )
        return true
    }

    @discardableResult
    func setLayerCompCapturesAppearance(_ id: UUID, enabled: Bool) -> Bool {
        guard let index = document.layerComps.firstIndex(where: { $0.id == id }),
              document.layerComps[index].capturesAppearance != enabled
        else { return false }
        pushUndo()
        document.layerComps[index].capturesAppearance = enabled
        document.selectedLayerCompID = id
        appendHistory(L10n.text("imageEditor.history.layerCompCaptureAppearance"))
        statusText = L10n.format(
            enabled
                ? "imageEditor.status.layerCompCaptureAppearanceEnabled"
                : "imageEditor.status.layerCompCaptureAppearanceDisabled",
            document.layerComps[index].name
        )
        return true
    }

    func unresolvedMissingLayerIDs(for comp: ImageEditorLayerComp) -> Set<UUID> {
        let currentLayerIDs = Set(document.layers.map(\.id))
        return Set(comp.layerStates.map(\.layerID))
            .subtracting(currentLayerIDs)
            .subtracting(comp.acknowledgedMissingLayerIDs)
    }

    func layerCompHasWarning(_ comp: ImageEditorLayerComp) -> Bool {
        !unresolvedMissingLayerIDs(for: comp).isEmpty
    }

    func showLayerCompWarning(_ id: UUID) {
        guard let comp = document.layerComps.first(where: { $0.id == id }) else { return }
        let missingCount = unresolvedMissingLayerIDs(for: comp).count
        guard missingCount > 0 else { return }
        document.selectedLayerCompID = id
        statusText = L10n.format(
            "imageEditor.status.layerCompMissingLayers",
            comp.name,
            missingCount
        )
    }

    @discardableResult
    func clearLayerCompWarning(_ id: UUID) -> Bool {
        guard let index = document.layerComps.firstIndex(where: { $0.id == id }) else {
            return false
        }
        let missingLayerIDs = unresolvedMissingLayerIDs(for: document.layerComps[index])
        guard !missingLayerIDs.isEmpty else { return false }
        pushUndo()
        document.layerComps[index].acknowledgedMissingLayerIDs.formUnion(missingLayerIDs)
        document.selectedLayerCompID = id
        appendHistory(L10n.text("imageEditor.history.layerCompClearWarning"))
        statusText = L10n.format(
            "imageEditor.status.layerCompWarningCleared",
            document.layerComps[index].name
        )
        return true
    }

    @discardableResult
    func clearAllLayerCompWarnings() -> Bool {
        let unresolvedByIndex = document.layerComps.indices.map { index in
            (index, unresolvedMissingLayerIDs(for: document.layerComps[index]))
        }.filter { !$0.1.isEmpty }
        guard !unresolvedByIndex.isEmpty else { return false }
        pushUndo()
        for (index, missingLayerIDs) in unresolvedByIndex {
            document.layerComps[index].acknowledgedMissingLayerIDs.formUnion(missingLayerIDs)
        }
        appendHistory(L10n.text("imageEditor.history.layerCompClearAllWarnings"))
        statusText = L10n.format(
            "imageEditor.status.layerCompAllWarningsCleared",
            unresolvedByIndex.count
        )
        return true
    }

    func deleteLayerComp(_ id: UUID) {
        guard let comp = document.layerComps.first(where: { $0.id == id }) else { return }
        pushUndo()
        document.layerComps.removeAll { $0.id == id }
        if document.selectedLayerCompID == id {
            document.selectedLayerCompID = document.layerComps.last?.id
        }
        appendHistory(L10n.text("imageEditor.history.layerCompDelete"))
        statusText = L10n.format("imageEditor.status.layerCompDeleted", comp.name)
    }

    func deleteSelectedLayerComp() {
        guard let selectedLayerComp else { return }
        deleteLayerComp(selectedLayerComp.id)
    }

    func canMoveLayerCompToTop(_ id: UUID) -> Bool {
        document.layerComps.firstIndex { $0.id == id }.map { $0 > 0 } ?? false
    }

    func canMoveLayerCompUp(_ id: UUID) -> Bool {
        canMoveLayerCompToTop(id)
    }

    func canMoveLayerCompDown(_ id: UUID) -> Bool {
        document.layerComps.firstIndex { $0.id == id }
            .map { $0 < document.layerComps.count - 1 } ?? false
    }

    func canMoveLayerCompToBottom(_ id: UUID) -> Bool {
        canMoveLayerCompDown(id)
    }

    @discardableResult
    func moveLayerCompToTop(_ id: UUID) -> Bool {
        moveLayerComp(
            id,
            destinationIndex: document.layerComps.startIndex,
            statusKey: "imageEditor.status.layerCompMovedToTop"
        )
    }

    @discardableResult
    func moveLayerCompUp(_ id: UUID) -> Bool {
        guard let sourceIndex = document.layerComps.firstIndex(where: { $0.id == id }) else {
            return false
        }
        return moveLayerComp(
            id,
            destinationIndex: sourceIndex - 1,
            statusKey: "imageEditor.status.layerCompMovedUp"
        )
    }

    @discardableResult
    func moveLayerCompDown(_ id: UUID) -> Bool {
        guard let sourceIndex = document.layerComps.firstIndex(where: { $0.id == id }) else {
            return false
        }
        return moveLayerComp(
            id,
            destinationIndex: sourceIndex + 1,
            statusKey: "imageEditor.status.layerCompMovedDown"
        )
    }

    @discardableResult
    func moveLayerCompToBottom(_ id: UUID) -> Bool {
        guard !document.layerComps.isEmpty else { return false }
        return moveLayerComp(
            id,
            destinationIndex: document.layerComps.index(before: document.layerComps.endIndex),
            statusKey: "imageEditor.status.layerCompMovedToBottom"
        )
    }

    @discardableResult
    func moveLayerComp(_ id: UUID, toIndex destinationIndex: Int) -> Bool {
        moveLayerComp(
            id,
            destinationIndex: destinationIndex,
            statusKey: "imageEditor.status.layerCompMoved"
        )
    }

    func selectLayerComp(_ id: UUID) {
        guard let comp = document.layerComps.first(where: { $0.id == id }) else { return }
        document.selectedLayerCompID = id
        statusText = L10n.format("imageEditor.status.layerCompSelected", comp.name)
    }

    @discardableResult
    func applyPreviousLayerComp(
        matching query: String = "",
        scope: ImageEditorLayerCompSearchScope = .all,
        favoritesOnly: Bool = false
    ) -> Bool {
        guard let targetID = layerCompNavigationTarget(
            .previous,
            matching: query,
            scope: scope,
            favoritesOnly: favoritesOnly
        ) else {
            return false
        }
        return applyLayerComp(targetID)
    }

    @discardableResult
    func applyNextLayerComp(
        matching query: String = "",
        scope: ImageEditorLayerCompSearchScope = .all,
        favoritesOnly: Bool = false
    ) -> Bool {
        guard let targetID = layerCompNavigationTarget(
            .next,
            matching: query,
            scope: scope,
            favoritesOnly: favoritesOnly
        ) else {
            return false
        }
        return applyLayerComp(targetID)
    }

    @discardableResult
    func applyPreviousFavoriteLayerComp() -> Bool {
        applyPreviousLayerComp(favoritesOnly: true)
    }

    @discardableResult
    func applyNextFavoriteLayerComp() -> Bool {
        applyNextLayerComp(favoritesOnly: true)
    }

    func layerCompNavigationTarget(
        _ direction: ImageEditorLayerCompNavigationDirection,
        matching query: String,
        scope: ImageEditorLayerCompSearchScope = .all,
        favoritesOnly: Bool = false
    ) -> UUID? {
        ImageEditorLayerCompSearch.navigationTarget(
            direction: direction,
            layerComps: document.layerComps,
            query: query,
            scope: scope,
            favoritesOnly: favoritesOnly,
            selectedLayerCompID: document.selectedLayerCompID
        )
    }

    @discardableResult
    func applyPreferredLayerCompSearchResult(
        matching query: String,
        scope: ImageEditorLayerCompSearchScope = .all,
        favoritesOnly: Bool = false
    ) -> Bool {
        guard let id = ImageEditorLayerCompSearch.preferredResultID(
            in: document.layerComps,
            matching: query,
            scope: scope,
            favoritesOnly: favoritesOnly,
            selectedLayerCompID: document.selectedLayerCompID
        ) else { return false }
        return applyLayerComp(id)
    }

    @discardableResult
    func selectAdjacentLayerCompSearchResult(
        _ direction: ImageEditorLayerCompNavigationDirection,
        matching query: String,
        scope: ImageEditorLayerCompSearchScope = .all,
        favoritesOnly: Bool = false
    ) -> Bool {
        guard let id = ImageEditorLayerCompSearch.selectionTarget(
            direction: direction,
            layerComps: document.layerComps,
            query: query,
            scope: scope,
            favoritesOnly: favoritesOnly,
            selectedLayerCompID: document.selectedLayerCompID
        ) else { return false }
        selectLayerComp(id)
        return true
    }

    func layerCompSummary(_ comp: ImageEditorLayerComp) -> String {
        L10n.format("imageEditor.layerComp.summary", comp.layerStates.count)
    }

    private func normalizedLayerCompName(_ proposedName: String?, fallbackIndex: Int) -> String {
        let trimmedName = (proposedName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return L10n.format("imageEditor.layerComp.defaultName", fallbackIndex)
        }
        return trimmedName
    }

    private func layerCompHasMatchingLayers(_ comp: ImageEditorLayerComp) -> Bool {
        ImageEditorLayerCompApplication.hasMatchingLayers(comp, in: document)
    }

    private func duplicateLayerCompName(for sourceName: String) -> String {
        let existingNames = Set(document.layerComps.map(\.name))
        let baseName = L10n.format("imageEditor.layerComp.copyName", sourceName)
        guard existingNames.contains(baseName) else { return baseName }

        var suffix = 2
        while true {
            let candidate = L10n.format("imageEditor.layerComp.copyNameIndexed", sourceName, suffix)
            if !existingNames.contains(candidate) {
                return candidate
            }
            suffix += 1
        }
    }

    private func moveLayerComp(
        _ id: UUID,
        destinationIndex: Int,
        statusKey: String
    ) -> Bool {
        guard let sourceIndex = document.layerComps.firstIndex(where: { $0.id == id }),
              document.layerComps.indices.contains(destinationIndex),
              sourceIndex != destinationIndex
        else { return false }
        let name = document.layerComps[sourceIndex].name

        pushUndo()
        let comp = document.layerComps.remove(at: sourceIndex)
        document.layerComps.insert(comp, at: destinationIndex)
        document.selectedLayerCompID = id
        appendHistory(L10n.text("imageEditor.history.layerCompReorder"))
        statusText = L10n.format(statusKey, name)
        return true
    }

}
