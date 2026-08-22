//
//  ImageEditorBrushPresetQuery.swift
//  veilpic
//
//  Created by Codex on 2026/8/22.
//

import Foundation

enum ImageEditorBrushPresetScope: String, CaseIterable, Identifiable {
    case all
    case builtIn
    case custom

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.brushPreset.scope.\(rawValue)")
    }
}

enum ImageEditorBrushPresetCollection: String, CaseIterable, Identifiable {
    case all
    case favorites
    case recent

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.brushPreset.collection.\(rawValue)")
    }

    var symbolName: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .favorites: return "star.fill"
        case .recent: return "clock.fill"
        }
    }
}

enum ImageEditorBrushPresetPanelLayout: String, CaseIterable, Identifiable {
    static let storageKey = "im.some.xomo.imageEditor.brushPresetPanelLayout"

    case list
    case grid

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.brushPreset.layout.\(rawValue)")
    }

    var symbolName: String {
        switch self {
        case .list: return "list.bullet"
        case .grid: return "square.grid.2x2"
        }
    }

    static func load(from defaults: UserDefaults = .standard) -> Self {
        guard let rawValue = defaults.string(forKey: storageKey),
              let layout = Self(rawValue: rawValue)
        else { return .list }
        return layout
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: Self.storageKey)
    }
}

enum ImageEditorBrushPresetGridDensity: String, CaseIterable, Identifiable {
    static let storageKey = "im.some.xomo.imageEditor.brushPresetGridDensity"

    case compact
    case regular
    case large

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.brushPreset.gridDensity.\(rawValue)")
    }

    var symbolName: String {
        switch self {
        case .compact: return "square.grid.3x3"
        case .regular: return "square.grid.2x2"
        case .large: return "rectangle.grid.1x2"
        }
    }

    var columnCount: Int {
        switch self {
        case .compact: return 3
        case .regular: return 2
        case .large: return 1
        }
    }

    var thumbnailSize: CGFloat {
        switch self {
        case .compact: return 36
        case .regular: return 58
        case .large: return 80
        }
    }

    var minimumTileHeight: CGFloat {
        switch self {
        case .compact: return 72
        case .regular: return 92
        case .large: return 118
        }
    }

    static func load(from defaults: UserDefaults = .standard) -> Self {
        guard let rawValue = defaults.string(forKey: storageKey),
              let density = Self(rawValue: rawValue)
        else { return .regular }
        return density
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: Self.storageKey)
    }
}

enum ImageEditorBrushPresetSortOrder: String, CaseIterable, Identifiable {
    static let storageKey = "im.some.xomo.imageEditor.brushPresetSortOrder"

    case catalog
    case nameAscending
    case nameDescending

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.brushPreset.sort.\(rawValue)")
    }

    var symbolName: String {
        switch self {
        case .catalog: return "list.bullet"
        case .nameAscending: return "arrow.up"
        case .nameDescending: return "arrow.down"
        }
    }

    static func load(from defaults: UserDefaults = .standard) -> Self {
        guard let rawValue = defaults.string(forKey: storageKey),
              let order = Self(rawValue: rawValue)
        else { return .catalog }
        return order
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: Self.storageKey)
    }

    func sort(_ presets: [ImageEditorBrushPreset]) -> [ImageEditorBrushPreset] {
        guard self != .catalog else { return presets }
        return presets.enumerated().sorted { lhs, rhs in
            let comparison = lhs.element.title.compare(
                rhs.element.title,
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            )
            if comparison == .orderedSame {
                return lhs.offset < rhs.offset
            }
            return self == .nameAscending
                ? comparison == .orderedAscending
                : comparison == .orderedDescending
        }.map(\.element)
    }
}

struct ImageEditorBrushPresetReorderMove: Equatable {
    let sourceID: String
    let destinationIndex: Int
}

enum ImageEditorBrushPresetReorderPolicy {
    static func canReorder(
        _ preset: ImageEditorBrushPreset,
        collection: ImageEditorBrushPresetCollection,
        sortOrder: ImageEditorBrushPresetSortOrder
    ) -> Bool {
        !preset.isBuiltIn && collection == .all && sortOrder == .catalog
    }

    static func resolvedMove(
        draggedIDs: [String],
        onto targetID: String,
        customPresets: [ImageEditorBrushPreset]
    ) -> ImageEditorBrushPresetReorderMove? {
        guard draggedIDs.count == 1,
              let sourceID = draggedIDs.first,
              sourceID != targetID,
              customPresets.contains(where: { $0.id == sourceID && !$0.isBuiltIn }),
              let destinationIndex = customPresets.firstIndex(where: {
                $0.id == targetID && !$0.isBuiltIn
              })
        else { return nil }
        return ImageEditorBrushPresetReorderMove(
            sourceID: sourceID,
            destinationIndex: destinationIndex
        )
    }
}

struct ImageEditorBrushPresetContextPolicy: Equatable {
    let customIndex: Int?
    let customCount: Int

    var isCustom: Bool { customIndex != nil }
    var canMoveUp: Bool { (customIndex ?? 0) > 0 }
    var canMoveDown: Bool {
        guard let customIndex else { return false }
        return customIndex < customCount - 1
    }

    var moveUpDestinationIndex: Int? {
        canMoveUp ? customIndex.map { $0 - 1 } : nil
    }

    var moveDownDestinationIndex: Int? {
        canMoveDown ? customIndex.map { $0 + 1 } : nil
    }

    init(
        preset: ImageEditorBrushPreset,
        customPresets: [ImageEditorBrushPreset]
    ) {
        customIndex = preset.isBuiltIn
            ? nil
            : customPresets.firstIndex(where: { $0.id == preset.id })
        customCount = customPresets.count
    }
}

enum ImageEditorBrushPresetSelectionGesture: Equatable {
    case replace
    case toggle
    case range
    case additiveRange

    static func resolved(
        isCommandPressed: Bool,
        isShiftPressed: Bool
    ) -> Self {
        switch (isCommandPressed, isShiftPressed) {
        case (true, true): return .additiveRange
        case (false, true): return .range
        case (true, false): return .toggle
        case (false, false): return .replace
        }
    }
}

struct ImageEditorBrushPresetSelectionState: Equatable {
    var selectedIDs: Set<String> = []
    var primaryID: String?
    var anchorID: String?

    func selecting(
        _ targetID: String,
        gesture: ImageEditorBrushPresetSelectionGesture,
        orderedIDs: [String]
    ) -> Self {
        guard orderedIDs.contains(targetID) else { return self }
        switch gesture {
        case .replace:
            return Self(
                selectedIDs: [targetID],
                primaryID: targetID,
                anchorID: targetID
            )
        case .toggle:
            return toggling(targetID, orderedIDs: orderedIDs)
        case .range:
            return selectingRange(targetID, additive: false, orderedIDs: orderedIDs)
        case .additiveRange:
            return selectingRange(targetID, additive: true, orderedIDs: orderedIDs)
        }
    }

    func repaired(visibleIDs: [String]) -> Self {
        guard !visibleIDs.isEmpty else { return Self() }
        let visibleIDSet = Set(visibleIDs)
        var repairedIDs = selectedIDs.intersection(visibleIDSet)
        var repairedPrimaryID = primaryID.flatMap {
            repairedIDs.contains($0) ? $0 : nil
        }
        if repairedPrimaryID == nil {
            repairedPrimaryID = visibleIDs.first(where: repairedIDs.contains)
        }
        if repairedPrimaryID == nil, let firstID = visibleIDs.first {
            repairedIDs = [firstID]
            repairedPrimaryID = firstID
        }
        let repairedAnchorID = anchorID.flatMap {
            visibleIDSet.contains($0) ? $0 : nil
        } ?? repairedPrimaryID
        return Self(
            selectedIDs: repairedIDs,
            primaryID: repairedPrimaryID,
            anchorID: repairedAnchorID
        )
    }

    func selectingAll(orderedIDs: [String]) -> Self {
        guard !orderedIDs.isEmpty else { return Self() }
        let visibleIDs = Set(orderedIDs)
        let resolvedPrimaryID = primaryID.flatMap {
            visibleIDs.contains($0) ? $0 : nil
        } ?? orderedIDs[0]
        let resolvedAnchorID = anchorID.flatMap {
            visibleIDs.contains($0) ? $0 : nil
        } ?? resolvedPrimaryID
        return Self(
            selectedIDs: visibleIDs,
            primaryID: resolvedPrimaryID,
            anchorID: resolvedAnchorID
        )
    }

    func deselectingAll() -> Self {
        Self()
    }

    func inverting(orderedIDs: [String]) -> Self {
        let invertedIDs = orderedIDs.filter { !selectedIDs.contains($0) }
        guard let firstInvertedID = invertedIDs.first else { return Self() }
        let invertedIDSet = Set(invertedIDs)
        let resolvedPrimaryID = primaryID.flatMap {
            invertedIDSet.contains($0) ? $0 : nil
        } ?? firstInvertedID
        let resolvedAnchorID = anchorID.flatMap {
            invertedIDSet.contains($0) ? $0 : nil
        } ?? resolvedPrimaryID
        return Self(
            selectedIDs: invertedIDSet,
            primaryID: resolvedPrimaryID,
            anchorID: resolvedAnchorID
        )
    }

    private func toggling(_ targetID: String, orderedIDs: [String]) -> Self {
        var selectedIDs = selectedIDs
        if selectedIDs.remove(targetID) == nil {
            selectedIDs.insert(targetID)
        }
        let primaryID = selectedIDs.contains(targetID)
            ? targetID
            : orderedIDs.first(where: selectedIDs.contains)
        return Self(
            selectedIDs: selectedIDs,
            primaryID: primaryID,
            anchorID: selectedIDs.contains(targetID) ? targetID : anchorID
        )
    }

    private func selectingRange(
        _ targetID: String,
        additive: Bool,
        orderedIDs: [String]
    ) -> Self {
        let rangeAnchorID = anchorID.flatMap { orderedIDs.contains($0) ? $0 : nil }
            ?? primaryID.flatMap { orderedIDs.contains($0) ? $0 : nil }
            ?? targetID
        guard let anchorIndex = orderedIDs.firstIndex(of: rangeAnchorID),
              let targetIndex = orderedIDs.firstIndex(of: targetID)
        else { return self }
        let selectedRange = Set(
            orderedIDs[min(anchorIndex, targetIndex)...max(anchorIndex, targetIndex)]
        )
        return Self(
            selectedIDs: additive ? selectedIDs.union(selectedRange) : selectedRange,
            primaryID: targetID,
            anchorID: rangeAnchorID
        )
    }
}

enum ImageEditorBrushPresetSearchField: String, CaseIterable {
    case size
    case hardness
    case flow
    case spacing
    case roundness
    case angle
    case smoothing

    func value(in preset: ImageEditorBrushPreset) -> Double {
        switch self {
        case .size: return Double(preset.size)
        case .hardness: return Double(preset.hardness * 100)
        case .flow: return Double(preset.flow)
        case .spacing: return Double(preset.spacing)
        case .roundness: return Double(preset.tipRoundness)
        case .angle: return Double(preset.tipAngleDegrees)
        case .smoothing: return Double(preset.smoothing)
        }
    }
}

enum ImageEditorBrushPresetSearchComparison: Equatable {
    case equal
    case lessThan
    case lessThanOrEqual
    case greaterThan
    case greaterThanOrEqual

    func matches(_ actualValue: Double, expectedValue: Double) -> Bool {
        switch self {
        case .equal:
            return abs(actualValue - expectedValue) <= 0.000_001
        case .lessThan:
            return actualValue < expectedValue
        case .lessThanOrEqual:
            return actualValue <= expectedValue
        case .greaterThan:
            return actualValue > expectedValue
        case .greaterThanOrEqual:
            return actualValue >= expectedValue
        }
    }
}

struct ImageEditorBrushPresetSearchConstraint: Equatable {
    let field: ImageEditorBrushPresetSearchField
    let comparison: ImageEditorBrushPresetSearchComparison
    let value: Double

    func matches(_ preset: ImageEditorBrushPreset) -> Bool {
        comparison.matches(field.value(in: preset), expectedValue: value)
    }
}

struct ImageEditorBrushPresetSearchExpression: Equatable {
    let nameTerms: [String]
    let constraints: [ImageEditorBrushPresetSearchConstraint]

    init(_ searchText: String) {
        var nameTerms: [String] = []
        var constraints: [ImageEditorBrushPresetSearchConstraint] = []
        for token in Self.tokens(in: searchText) {
            if let constraint = Self.constraint(from: token) {
                constraints.append(constraint)
            } else {
                nameTerms.append(token)
            }
        }
        self.nameTerms = nameTerms
        self.constraints = constraints
    }

    func matches(_ preset: ImageEditorBrushPreset) -> Bool {
        let matchesName = nameTerms.allSatisfy { term in
            preset.title.range(
                of: term,
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            ) != nil
        }
        return matchesName && constraints.allSatisfy { $0.matches(preset) }
    }

    private static func tokens(in searchText: String) -> [String] {
        var tokens: [String] = []
        var token = ""
        var isQuoted = false
        for character in searchText {
            if character == "\"" {
                isQuoted.toggle()
            } else if character.isWhitespace && !isQuoted {
                if !token.isEmpty {
                    tokens.append(token)
                    token = ""
                }
            } else {
                token.append(character)
            }
        }
        if !token.isEmpty {
            tokens.append(token)
        }
        return tokens
    }

    private static func constraint(
        from token: String
    ) -> ImageEditorBrushPresetSearchConstraint? {
        guard let separatorIndex = token.firstIndex(of: ":"),
              let field = ImageEditorBrushPresetSearchField(
                rawValue: String(token[..<separatorIndex]).lowercased()
              )
        else { return nil }

        var valueText = String(token[token.index(after: separatorIndex)...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let comparison: ImageEditorBrushPresetSearchComparison
        if valueText.hasPrefix(">=") {
            comparison = .greaterThanOrEqual
            valueText.removeFirst(2)
        } else if valueText.hasPrefix("<=") {
            comparison = .lessThanOrEqual
            valueText.removeFirst(2)
        } else if valueText.hasPrefix(">") {
            comparison = .greaterThan
            valueText.removeFirst()
        } else if valueText.hasPrefix("<") {
            comparison = .lessThan
            valueText.removeFirst()
        } else {
            comparison = .equal
            if valueText.hasPrefix("=") {
                valueText.removeFirst()
            }
        }

        let lowercaseValue = valueText.lowercased()
        if lowercaseValue.hasSuffix("px") {
            valueText.removeLast(2)
        } else if lowercaseValue.hasSuffix("%") {
            valueText.removeLast()
        }
        guard let value = Double(valueText), value.isFinite else { return nil }
        return ImageEditorBrushPresetSearchConstraint(
            field: field,
            comparison: comparison,
            value: value
        )
    }
}

struct ImageEditorBrushPresetQuery: Equatable {
    var searchText: String
    var scope: ImageEditorBrushPresetScope
    var collection: ImageEditorBrushPresetCollection
    var sortOrder: ImageEditorBrushPresetSortOrder
    var favoriteIDs: Set<String>
    var recentIDs: [String]

    init(
        searchText: String,
        scope: ImageEditorBrushPresetScope,
        collection: ImageEditorBrushPresetCollection = .all,
        sortOrder: ImageEditorBrushPresetSortOrder = .catalog,
        favoriteIDs: Set<String> = [],
        recentIDs: [String] = []
    ) {
        self.searchText = searchText
        self.scope = scope
        self.collection = collection
        self.sortOrder = sortOrder
        self.favoriteIDs = favoriteIDs
        self.recentIDs = recentIDs
    }

    func filter(_ presets: [ImageEditorBrushPreset]) -> [ImageEditorBrushPreset] {
        let expression = ImageEditorBrushPresetSearchExpression(searchText)
        let filteredPresets: [ImageEditorBrushPreset]
        switch collection {
        case .all:
            filteredPresets = presets.filter { matches($0, expression: expression) }
        case .favorites:
            filteredPresets = presets.filter {
                favoriteIDs.contains($0.id) && matches($0, expression: expression)
            }
        case .recent:
            let indexedPresets = Dictionary(
                uniqueKeysWithValues: presets.map { ($0.id, $0) }
            )
            filteredPresets = recentIDs.compactMap { indexedPresets[$0] }.filter {
                matches($0, expression: expression)
            }
        }
        return sortOrder.sort(filteredPresets)
    }

    func presented(_ presets: [ImageEditorBrushPreset]) -> [ImageEditorBrushPreset] {
        let filteredPresets = filter(presets)
        guard collection == .all else { return filteredPresets }
        return filteredPresets.filter(\.isBuiltIn)
            + filteredPresets.filter { !$0.isBuiltIn }
    }

    func exportableCustomPresetIDs(
        in presets: [ImageEditorBrushPreset]
    ) -> [String] {
        presented(presets)
            .filter { !$0.isBuiltIn }
            .map(\.id)
    }

    func exportableSelectedCustomPresetIDs(
        _ selectedIDs: Set<String>,
        in presets: [ImageEditorBrushPreset]
    ) -> [String] {
        presented(presets)
            .filter { selectedIDs.contains($0.id) && !$0.isBuiltIn }
            .map(\.id)
    }

    func repairedSelectionID(
        _ currentID: String?,
        in presets: [ImageEditorBrushPreset]
    ) -> String? {
        let filteredPresets = presented(presets)
        if let currentID, filteredPresets.contains(where: { $0.id == currentID }) {
            return currentID
        }
        return filteredPresets.first?.id
    }

    private func matches(
        _ preset: ImageEditorBrushPreset,
        expression: ImageEditorBrushPresetSearchExpression
    ) -> Bool {
        guard matchesScope(preset) else { return false }
        return expression.matches(preset)
    }

    private func matchesScope(_ preset: ImageEditorBrushPreset) -> Bool {
        switch scope {
        case .all:
            return true
        case .builtIn:
            return preset.isBuiltIn
        case .custom:
            return !preset.isBuiltIn
        }
    }
}
