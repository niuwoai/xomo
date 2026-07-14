import CoreGraphics
import Foundation

enum ImageEditorStackAxis: String, CaseIterable, Codable, Identifiable, Sendable {
    case horizontal
    case vertical

    var id: String { rawValue }
    var localizationKey: String { "imageEditor.stackLayout.axis.\(rawValue)" }
}

enum ImageEditorStackPrimaryAlignment: String, CaseIterable, Codable, Identifiable, Sendable {
    case start
    case center
    case end
    case spaceBetween

    var id: String { rawValue }
    var localizationKey: String { "imageEditor.stackLayout.primary.\(rawValue)" }
}

enum ImageEditorStackCrossAlignment: String, CaseIterable, Codable, Identifiable, Sendable {
    case start
    case center
    case end

    var id: String { rawValue }
    var localizationKey: String { "imageEditor.stackLayout.cross.\(rawValue)" }
}

enum ImageEditorStackSizingMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case fixed
    case hug

    var id: String { rawValue }
    var localizationKey: String { "imageEditor.stackLayout.sizing.\(rawValue)" }
}

enum ImageEditorStackChildSizingMode: String, CaseIterable, Identifiable, Sendable {
    case fixed
    case fill

    var id: String { rawValue }
    var localizationKey: String { "imageEditor.stackLayout.childSizing.\(rawValue)" }
}

struct ImageEditorStackChildLayout: Equatable, Codable, Sendable {
    static let maximumGrow: CGFloat = 1_024

    var grow: CGFloat
    var stretchesCrossAxis: Bool

    init(grow: CGFloat = 0, stretchesCrossAxis: Bool = false) {
        self.grow = min(max(grow.isFinite ? grow : 0, 0), Self.maximumGrow)
        self.stretchesCrossAxis = stretchesCrossAxis
    }

    var primarySizingMode: ImageEditorStackChildSizingMode {
        grow > 0 ? .fill : .fixed
    }

    var crossSizingMode: ImageEditorStackChildSizingMode {
        stretchesCrossAxis ? .fill : .fixed
    }
}

struct ImageEditorStackLayout: Equatable, Codable, Sendable {
    static let maximumPadding: CGFloat = 4_096
    static let minimumSpacing: CGFloat = -1_024
    static let maximumSpacing: CGFloat = 4_096

    var axis: ImageEditorStackAxis
    var spacing: CGFloat
    var paddingTop: CGFloat
    var paddingRight: CGFloat
    var paddingBottom: CGFloat
    var paddingLeft: CGFloat
    var primaryAlignment: ImageEditorStackPrimaryAlignment
    var crossAlignment: ImageEditorStackCrossAlignment
    var primarySizingMode: ImageEditorStackSizingMode
    var crossSizingMode: ImageEditorStackSizingMode

    init(
        axis: ImageEditorStackAxis,
        spacing: CGFloat = 0,
        paddingTop: CGFloat = 0,
        paddingRight: CGFloat = 0,
        paddingBottom: CGFloat = 0,
        paddingLeft: CGFloat = 0,
        primaryAlignment: ImageEditorStackPrimaryAlignment = .start,
        crossAlignment: ImageEditorStackCrossAlignment = .start,
        primarySizingMode: ImageEditorStackSizingMode = .fixed,
        crossSizingMode: ImageEditorStackSizingMode = .fixed
    ) {
        self.axis = axis
        self.spacing = spacing
        self.paddingTop = paddingTop
        self.paddingRight = paddingRight
        self.paddingBottom = paddingBottom
        self.paddingLeft = paddingLeft
        self.primaryAlignment = primaryAlignment
        self.crossAlignment = crossAlignment
        self.primarySizingMode = primarySizingMode
        self.crossSizingMode = crossSizingMode
        self = normalized()
    }

    private enum CodingKeys: String, CodingKey {
        case axis
        case spacing
        case paddingTop
        case paddingRight
        case paddingBottom
        case paddingLeft
        case primaryAlignment
        case crossAlignment
        case primarySizingMode
        case crossSizingMode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            axis: try container.decode(ImageEditorStackAxis.self, forKey: .axis),
            spacing: try container.decode(CGFloat.self, forKey: .spacing),
            paddingTop: try container.decode(CGFloat.self, forKey: .paddingTop),
            paddingRight: try container.decode(CGFloat.self, forKey: .paddingRight),
            paddingBottom: try container.decode(CGFloat.self, forKey: .paddingBottom),
            paddingLeft: try container.decode(CGFloat.self, forKey: .paddingLeft),
            primaryAlignment: try container.decode(
                ImageEditorStackPrimaryAlignment.self,
                forKey: .primaryAlignment
            ),
            crossAlignment: try container.decode(
                ImageEditorStackCrossAlignment.self,
                forKey: .crossAlignment
            ),
            primarySizingMode: try container.decodeIfPresent(
                ImageEditorStackSizingMode.self,
                forKey: .primarySizingMode
            ) ?? .fixed,
            crossSizingMode: try container.decodeIfPresent(
                ImageEditorStackSizingMode.self,
                forKey: .crossSizingMode
            ) ?? .fixed
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(axis, forKey: .axis)
        try container.encode(spacing, forKey: .spacing)
        try container.encode(paddingTop, forKey: .paddingTop)
        try container.encode(paddingRight, forKey: .paddingRight)
        try container.encode(paddingBottom, forKey: .paddingBottom)
        try container.encode(paddingLeft, forKey: .paddingLeft)
        try container.encode(primaryAlignment, forKey: .primaryAlignment)
        try container.encode(crossAlignment, forKey: .crossAlignment)
        try container.encode(primarySizingMode, forKey: .primarySizingMode)
        try container.encode(crossSizingMode, forKey: .crossSizingMode)
    }

    func normalized() -> Self {
        var value = self
        value.spacing = min(max(spacing.isFinite ? spacing : 0, Self.minimumSpacing), Self.maximumSpacing)
        value.paddingTop = Self.normalizedPadding(paddingTop)
        value.paddingRight = Self.normalizedPadding(paddingRight)
        value.paddingBottom = Self.normalizedPadding(paddingBottom)
        value.paddingLeft = Self.normalizedPadding(paddingLeft)
        return value
    }

    private static func normalizedPadding(_ value: CGFloat) -> CGFloat {
        min(max(value.isFinite ? value : 0, 0), maximumPadding)
    }
}

struct ImageEditorStackLayoutResult: Equatable, Sendable {
    var containerFrame: CGRect
    var itemFrames: [CGRect]
}

enum ImageEditorStackLayoutEngine {
    static func layout(
        in container: CGRect,
        itemFrames: [CGRect],
        itemLayouts: [ImageEditorStackChildLayout] = [],
        layout: ImageEditorStackLayout
    ) -> ImageEditorStackLayoutResult {
        let layout = layout.normalized()
        var sizes = itemFrames.map(\.size)
        let resolvedItemLayouts = itemFrames.indices.map { index in
            itemLayouts.indices.contains(index) ? itemLayouts[index] : ImageEditorStackChildLayout()
        }
        let originalItemMain = sizes.reduce(0) { partial, size in
            partial + (layout.axis == .horizontal ? size.width : size.height)
        }
        let maximumItemCross = sizes.reduce(0) { partial, size in
            max(partial, layout.axis == .horizontal ? size.height : size.width)
        }
        let gapCount = CGFloat(max(0, itemFrames.count - 1))
        let requiredMain = originalItemMain + layout.spacing * gapCount + mainPadding(layout)
        let requiredCross = maximumItemCross + crossPadding(layout)
        var resolvedContainer = container.standardized
        if layout.primarySizingMode == .hug {
            setMainSize(max(1, requiredMain), axis: layout.axis, frame: &resolvedContainer)
        }
        if layout.crossSizingMode == .hug {
            setCrossSize(max(1, requiredCross), axis: layout.axis, frame: &resolvedContainer)
        }
        guard !itemFrames.isEmpty else {
            return ImageEditorStackLayoutResult(containerFrame: resolvedContainer, itemFrames: [])
        }
        let inner = CGRect(
            x: resolvedContainer.minX + layout.paddingLeft,
            y: resolvedContainer.minY + layout.paddingTop,
            width: max(0, resolvedContainer.width - layout.paddingLeft - layout.paddingRight),
            height: max(0, resolvedContainer.height - layout.paddingTop - layout.paddingBottom)
        )
        let availableMain = layout.axis == .horizontal ? inner.width : inner.height
        let availableCross = layout.axis == .horizontal ? inner.height : inner.width
        let totalGrow = resolvedItemLayouts.reduce(0) { $0 + $1.grow }
        let usesPrimaryFill = totalGrow > 0 && layout.primarySizingMode == .fixed
        if usesPrimaryFill {
            let fixedMain = sizes.indices.reduce(0) { partial, index in
                guard resolvedItemLayouts[index].grow <= 0 else { return partial }
                return partial + mainSize(sizes[index], axis: layout.axis)
            }
            let distributableMain = max(0, availableMain - fixedMain - layout.spacing * gapCount)
            for index in sizes.indices where resolvedItemLayouts[index].grow > 0 {
                let share = distributableMain * resolvedItemLayouts[index].grow / totalGrow
                setMainSize(max(1, share), axis: layout.axis, size: &sizes[index])
            }
        }
        if layout.crossSizingMode == .fixed {
            for index in sizes.indices where resolvedItemLayouts[index].stretchesCrossAxis {
                setCrossSize(max(1, availableCross), axis: layout.axis, size: &sizes[index])
            }
        }
        let totalItemMain = sizes.reduce(0) { partial, size in
            partial + mainSize(size, axis: layout.axis)
        }
        let spacing: CGFloat
        if layout.primaryAlignment == .spaceBetween, itemFrames.count > 1, !usesPrimaryFill {
            spacing = (availableMain - totalItemMain) / gapCount
        } else {
            spacing = layout.spacing
        }
        let contentMain = totalItemMain + spacing * gapCount
        let mainOffset: CGFloat
        switch (layout.primaryAlignment, usesPrimaryFill) {
        case (_, true):
            mainOffset = 0
        case (.center, false):
            mainOffset = (availableMain - contentMain) / 2
        case (.end, false):
            mainOffset = availableMain - contentMain
        case (.start, false), (.spaceBetween, false):
            mainOffset = 0
        }
        var cursor = (layout.axis == .horizontal ? inner.minX : inner.minY) + mainOffset
        let frames = sizes.map { size in
            let crossOrigin = crossOrigin(layout: layout, inner: inner, itemSize: size)
            let frame: CGRect
            if layout.axis == .horizontal {
                frame = CGRect(x: cursor, y: crossOrigin, width: size.width, height: size.height)
                cursor += size.width + spacing
            } else {
                frame = CGRect(x: crossOrigin, y: cursor, width: size.width, height: size.height)
                cursor += size.height + spacing
            }
            return frame
        }
        return ImageEditorStackLayoutResult(containerFrame: resolvedContainer, itemFrames: frames)
    }

    static func frames(
        in container: CGRect,
        itemFrames: [CGRect],
        itemLayouts: [ImageEditorStackChildLayout] = [],
        layout: ImageEditorStackLayout
    ) -> [CGRect] {
        self.layout(
            in: container,
            itemFrames: itemFrames,
            itemLayouts: itemLayouts,
            layout: layout
        ).itemFrames
    }

    private static func mainPadding(_ layout: ImageEditorStackLayout) -> CGFloat {
        layout.axis == .horizontal
            ? layout.paddingLeft + layout.paddingRight
            : layout.paddingTop + layout.paddingBottom
    }

    private static func crossPadding(_ layout: ImageEditorStackLayout) -> CGFloat {
        layout.axis == .horizontal
            ? layout.paddingTop + layout.paddingBottom
            : layout.paddingLeft + layout.paddingRight
    }

    private static func setMainSize(
        _ value: CGFloat,
        axis: ImageEditorStackAxis,
        frame: inout CGRect
    ) {
        if axis == .horizontal {
            frame.size.width = value
        } else {
            frame.size.height = value
        }
    }

    private static func setCrossSize(
        _ value: CGFloat,
        axis: ImageEditorStackAxis,
        frame: inout CGRect
    ) {
        if axis == .horizontal {
            frame.size.height = value
        } else {
            frame.size.width = value
        }
    }

    private static func mainSize(_ size: CGSize, axis: ImageEditorStackAxis) -> CGFloat {
        axis == .horizontal ? size.width : size.height
    }

    private static func setMainSize(
        _ value: CGFloat,
        axis: ImageEditorStackAxis,
        size: inout CGSize
    ) {
        if axis == .horizontal {
            size.width = value
        } else {
            size.height = value
        }
    }

    private static func setCrossSize(
        _ value: CGFloat,
        axis: ImageEditorStackAxis,
        size: inout CGSize
    ) {
        if axis == .horizontal {
            size.height = value
        } else {
            size.width = value
        }
    }

    private static func crossOrigin(
        layout: ImageEditorStackLayout,
        inner: CGRect,
        itemSize: CGSize
    ) -> CGFloat {
        let availableCross = layout.axis == .horizontal ? inner.height : inner.width
        let itemCross = layout.axis == .horizontal ? itemSize.height : itemSize.width
        let minimum = layout.axis == .horizontal ? inner.minY : inner.minX
        switch layout.crossAlignment {
        case .start:
            return minimum
        case .center:
            return minimum + (availableCross - itemCross) / 2
        case .end:
            return minimum + availableCross - itemCross
        }
    }
}

@MainActor
extension ImageEditorViewModel {
    var selectedStackLayout: ImageEditorStackLayout? {
        guard let layer = document.selectedLayer, layer.isGroup else { return nil }
        return layer.stackLayout
    }

    var selectedStackChildLayout: ImageEditorStackChildLayout? {
        guard let layer = document.selectedLayer,
              !layer.isStackLayoutExcluded,
              !layer.isStackLayoutBackground,
              let groupID = layer.groupID,
              document.layers.contains(where: { $0.id == groupID && $0.stackLayout != nil })
        else { return nil }
        return layer.stackChildLayout ?? ImageEditorStackChildLayout()
    }

    var canReflowSelectedStackLayout: Bool {
        guard let group = document.selectedLayer else { return false }
        let indices = stackParticipantIndices(groupID: group.id)
        return !indices.isEmpty && canEditStackLayout(groupID: group.id)
    }

    func setSelectedStackAxis(_ axis: ImageEditorStackAxis) {
        updateSelectedStackLayout { $0.axis = axis }
    }

    func setSelectedStackSpacing(_ spacing: CGFloat) {
        updateSelectedStackLayout { $0.spacing = spacing }
    }

    func setSelectedStackPaddingTop(_ padding: CGFloat) {
        updateSelectedStackLayout { $0.paddingTop = padding }
    }

    func setSelectedStackPaddingRight(_ padding: CGFloat) {
        updateSelectedStackLayout { $0.paddingRight = padding }
    }

    func setSelectedStackPaddingBottom(_ padding: CGFloat) {
        updateSelectedStackLayout { $0.paddingBottom = padding }
    }

    func setSelectedStackPaddingLeft(_ padding: CGFloat) {
        updateSelectedStackLayout { $0.paddingLeft = padding }
    }

    func setSelectedStackPrimaryAlignment(_ alignment: ImageEditorStackPrimaryAlignment) {
        updateSelectedStackLayout { $0.primaryAlignment = alignment }
    }

    func setSelectedStackCrossAlignment(_ alignment: ImageEditorStackCrossAlignment) {
        updateSelectedStackLayout { $0.crossAlignment = alignment }
    }

    func setSelectedStackPrimarySizingMode(_ mode: ImageEditorStackSizingMode) {
        updateSelectedStackLayout { $0.primarySizingMode = mode }
    }

    func setSelectedStackCrossSizingMode(_ mode: ImageEditorStackSizingMode) {
        updateSelectedStackLayout { $0.crossSizingMode = mode }
    }

    func setSelectedStackChildPrimarySizingMode(_ mode: ImageEditorStackChildSizingMode) {
        updateSelectedStackChildLayout { layout in
            layout.grow = mode == .fill ? max(1, layout.grow) : 0
        }
    }

    func setSelectedStackChildCrossSizingMode(_ mode: ImageEditorStackChildSizingMode) {
        updateSelectedStackChildLayout { layout in
            layout.stretchesCrossAxis = mode == .fill
        }
    }

    func reflowSelectedStackLayout() {
        updateSelectedStackLayout(forceReflow: true) { _ in }
    }

    private func updateSelectedStackLayout(
        forceReflow: Bool = false,
        update: (inout ImageEditorStackLayout) -> Void
    ) {
        guard let groupID = document.selectedLayerID,
              let groupIndex = document.layers.firstIndex(where: { $0.id == groupID && $0.isGroup }),
              var layout = document.layers[groupIndex].stackLayout
        else { return }
        guard canEditStackLayout(groupID: groupID) else {
            statusText = L10n.text("imageEditor.status.stackLayoutLocked")
            return
        }
        let original = layout
        update(&layout)
        layout = layout.normalized()
        guard forceReflow || layout != original else { return }

        pushUndo()
        document.layers[groupIndex].stackLayout = layout
        applyStackLayout(groupID: groupID, layout: layout)
        appendHistory(L10n.text("imageEditor.history.stackLayout"))
        statusText = L10n.text("imageEditor.status.stackLayoutApplied")
    }

    private func updateSelectedStackChildLayout(
        update: (inout ImageEditorStackChildLayout) -> Void
    ) {
        guard let layerID = document.selectedLayerID,
              let layerIndex = document.layers.firstIndex(where: { $0.id == layerID }),
              !document.layers[layerIndex].isStackLayoutExcluded,
              !document.layers[layerIndex].isStackLayoutBackground,
              let groupID = document.layers[layerIndex].groupID,
              let groupLayout = document.layers.first(where: { $0.id == groupID })?.stackLayout,
              canEditStackLayout(groupID: groupID)
        else {
            statusText = L10n.text("imageEditor.status.stackLayoutLocked")
            return
        }
        let original = document.layers[layerIndex].stackChildLayout ?? ImageEditorStackChildLayout()
        var childLayout = original
        update(&childLayout)
        childLayout = ImageEditorStackChildLayout(
            grow: childLayout.grow,
            stretchesCrossAxis: childLayout.stretchesCrossAxis
        )
        guard childLayout != original else { return }

        pushUndo()
        document.layers[layerIndex].stackChildLayout = childLayout == ImageEditorStackChildLayout()
            ? nil
            : childLayout
        applyStackLayout(groupID: groupID, layout: groupLayout)
        appendHistory(L10n.text("imageEditor.history.stackChildLayout"))
        statusText = L10n.text("imageEditor.status.stackChildLayoutApplied")
    }

    private func applyStackLayout(groupID: UUID, layout: ImageEditorStackLayout) {
        guard let groupIndex = document.layers.firstIndex(where: { $0.id == groupID }) else { return }
        let group = document.layers[groupIndex]
        let participantIndices = stackParticipantIndices(groupID: groupID)
        let result = ImageEditorStackLayoutEngine.layout(
            in: group.frame.standardized,
            itemFrames: participantIndices.map { document.layers[$0].frame.standardized },
            itemLayouts: participantIndices.map {
                document.layers[$0].stackChildLayout ?? ImageEditorStackChildLayout()
            },
            layout: layout
        )
        document.layers[groupIndex].frame = result.containerFrame
        for index in stackBackgroundIndices(groupID: groupID) {
            document.layers[index].frame = result.containerFrame
        }
        for (participantIndex, targetFrame) in zip(participantIndices, result.itemFrames) {
            let participant = document.layers[participantIndex]
            let delta = CGSize(
                width: targetFrame.minX - participant.frame.minX,
                height: targetFrame.minY - participant.frame.minY
            )
            if abs(delta.width) >= 0.001 || abs(delta.height) >= 0.001 {
                let movedLayerIDs = stackMovedLayerIDs(participant)
                for index in document.layers.indices where movedLayerIDs.contains(document.layers[index].id) {
                    document.layers[index].frame = document.layers[index].frame.offsetBy(
                        dx: delta.width,
                        dy: delta.height
                    )
                }
            }
            document.layers[participantIndex].frame = targetFrame
            if let nestedLayout = document.layers[participantIndex].stackLayout,
               canEditStackLayout(groupID: participant.id) {
                applyStackLayout(groupID: participant.id, layout: nestedLayout)
            }
        }
    }

    private func stackParticipantIndices(groupID: UUID) -> [Int] {
        document.layers.indices.filter { index in
            let layer = document.layers[index]
            return layer.groupID == groupID && !layer.isStackLayoutExcluded
        }
    }

    private func stackBackgroundIndices(groupID: UUID) -> [Int] {
        document.layers.indices.filter { index in
            let layer = document.layers[index]
            return layer.groupID == groupID && layer.isStackLayoutBackground
        }
    }

    private func canEditStackLayout(groupID: UUID) -> Bool {
        guard let group = document.layers.first(where: {
            $0.id == groupID && $0.isGroup && $0.stackLayout != nil
        }), !document.isEffectivelyPositionLocked(group) else { return false }
        let affectedIndices = stackParticipantIndices(groupID: groupID)
            + stackBackgroundIndices(groupID: groupID)
        return affectedIndices.allSatisfy {
            !document.isEffectivelyPositionLocked(document.layers[$0])
        }
    }

    private func stackMovedLayerIDs(_ participant: ImageEditorLayer) -> Set<UUID> {
        guard participant.isGroup else { return [participant.id] }
        var ids: Set<UUID> = [participant.id]
        for layer in document.layers where document.ancestorGroups(for: layer).contains(where: { $0.id == participant.id }) {
            ids.insert(layer.id)
        }
        return ids
    }
}
