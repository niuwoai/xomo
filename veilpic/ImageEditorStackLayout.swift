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

    init(
        axis: ImageEditorStackAxis,
        spacing: CGFloat = 0,
        paddingTop: CGFloat = 0,
        paddingRight: CGFloat = 0,
        paddingBottom: CGFloat = 0,
        paddingLeft: CGFloat = 0,
        primaryAlignment: ImageEditorStackPrimaryAlignment = .start,
        crossAlignment: ImageEditorStackCrossAlignment = .start
    ) {
        self.axis = axis
        self.spacing = spacing
        self.paddingTop = paddingTop
        self.paddingRight = paddingRight
        self.paddingBottom = paddingBottom
        self.paddingLeft = paddingLeft
        self.primaryAlignment = primaryAlignment
        self.crossAlignment = crossAlignment
        self = normalized()
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

enum ImageEditorStackLayoutEngine {
    static func frames(
        in container: CGRect,
        itemFrames: [CGRect],
        layout: ImageEditorStackLayout
    ) -> [CGRect] {
        guard !itemFrames.isEmpty else { return [] }
        let layout = layout.normalized()
        let inner = CGRect(
            x: container.minX + layout.paddingLeft,
            y: container.minY + layout.paddingTop,
            width: max(0, container.width - layout.paddingLeft - layout.paddingRight),
            height: max(0, container.height - layout.paddingTop - layout.paddingBottom)
        )
        let sizes = itemFrames.map(\.size)
        let availableMain = layout.axis == .horizontal ? inner.width : inner.height
        let totalItemMain = sizes.reduce(0) { partial, size in
            partial + (layout.axis == .horizontal ? size.width : size.height)
        }
        let spacing: CGFloat
        if layout.primaryAlignment == .spaceBetween, itemFrames.count > 1 {
            spacing = (availableMain - totalItemMain) / CGFloat(itemFrames.count - 1)
        } else {
            spacing = layout.spacing
        }
        let contentMain = totalItemMain + spacing * CGFloat(max(0, itemFrames.count - 1))
        let mainOffset: CGFloat
        switch layout.primaryAlignment {
        case .center:
            mainOffset = (availableMain - contentMain) / 2
        case .end:
            mainOffset = availableMain - contentMain
        case .start, .spaceBetween:
            mainOffset = 0
        }
        var cursor = (layout.axis == .horizontal ? inner.minX : inner.minY) + mainOffset
        return sizes.map { size in
            let crossOrigin = crossOrigin(
                layout: layout,
                inner: inner,
                itemSize: size
            )
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

    var canReflowSelectedStackLayout: Bool {
        guard let group = document.selectedLayer,
              group.isGroup,
              group.stackLayout != nil,
              !document.isEffectivelyPositionLocked(group)
        else { return false }
        let indices = stackParticipantIndices(groupID: group.id)
        return !indices.isEmpty && indices.allSatisfy {
            !document.isEffectivelyPositionLocked(document.layers[$0])
        }
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
        guard canReflowSelectedStackLayout else {
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

    private func applyStackLayout(groupID: UUID, layout: ImageEditorStackLayout) {
        guard let group = document.layers.first(where: { $0.id == groupID }) else { return }
        let participantIndices = stackParticipantIndices(groupID: groupID)
        let targetFrames = ImageEditorStackLayoutEngine.frames(
            in: group.frame.standardized,
            itemFrames: participantIndices.map { document.layers[$0].frame.standardized },
            layout: layout
        )
        for (participantIndex, targetFrame) in zip(participantIndices, targetFrames) {
            let participant = document.layers[participantIndex]
            let delta = CGSize(
                width: targetFrame.minX - participant.frame.minX,
                height: targetFrame.minY - participant.frame.minY
            )
            guard abs(delta.width) >= 0.001 || abs(delta.height) >= 0.001 else { continue }
            let movedLayerIDs = stackMovedLayerIDs(participant)
            for index in document.layers.indices where movedLayerIDs.contains(document.layers[index].id) {
                document.layers[index].frame = document.layers[index].frame.offsetBy(
                    dx: delta.width,
                    dy: delta.height
                )
            }
        }
    }

    private func stackParticipantIndices(groupID: UUID) -> [Int] {
        document.layers.indices.filter { index in
            let layer = document.layers[index]
            return layer.groupID == groupID && !layer.isStackLayoutExcluded
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
