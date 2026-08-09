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
    case baseline

    var id: String { rawValue }
    var localizationKey: String { "imageEditor.stackLayout.cross.\(rawValue)" }

    static func availableCases(for axis: ImageEditorStackAxis) -> [Self] {
        axis == .horizontal ? allCases : allCases.filter { $0 != .baseline }
    }
}

enum ImageEditorStackSizingMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case fixed
    case hug

    var id: String { rawValue }
    var localizationKey: String { "imageEditor.stackLayout.sizing.\(rawValue)" }
}

enum ImageEditorStackWrapMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case noWrap
    case wrap

    var id: String { rawValue }
    var localizationKey: String { "imageEditor.stackLayout.wrap.\(rawValue)" }
}

enum ImageEditorStackCrossTrackAlignment: String, CaseIterable, Codable, Identifiable, Sendable {
    case automatic
    case spaceBetween

    var id: String { rawValue }
    var localizationKey: String { "imageEditor.stackLayout.crossTrack.\(rawValue)" }

    static func availableCases(
        for axis: ImageEditorStackAxis,
        wrapMode: ImageEditorStackWrapMode
    ) -> [Self] {
        axis == .horizontal && wrapMode == .wrap ? allCases : [.automatic]
    }
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
    var wrapMode: ImageEditorStackWrapMode
    var counterSpacing: CGFloat
    var crossTrackAlignment: ImageEditorStackCrossTrackAlignment

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
        crossSizingMode: ImageEditorStackSizingMode = .fixed,
        wrapMode: ImageEditorStackWrapMode = .noWrap,
        counterSpacing: CGFloat = 0,
        crossTrackAlignment: ImageEditorStackCrossTrackAlignment = .automatic
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
        self.wrapMode = wrapMode
        self.counterSpacing = counterSpacing
        self.crossTrackAlignment = crossTrackAlignment
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
        case wrapMode
        case counterSpacing
        case crossTrackAlignment
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
            ) ?? .fixed,
            wrapMode: try container.decodeIfPresent(
                ImageEditorStackWrapMode.self,
                forKey: .wrapMode
            ) ?? .noWrap,
            counterSpacing: try container.decodeIfPresent(
                CGFloat.self,
                forKey: .counterSpacing
            ) ?? 0,
            crossTrackAlignment: try container.decodeIfPresent(
                ImageEditorStackCrossTrackAlignment.self,
                forKey: .crossTrackAlignment
            ) ?? .automatic
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
        try container.encode(wrapMode, forKey: .wrapMode)
        try container.encode(counterSpacing, forKey: .counterSpacing)
        try container.encode(crossTrackAlignment, forKey: .crossTrackAlignment)
    }

    func normalized() -> Self {
        var value = self
        value.spacing = min(max(spacing.isFinite ? spacing : 0, Self.minimumSpacing), Self.maximumSpacing)
        value.paddingTop = Self.normalizedPadding(paddingTop)
        value.paddingRight = Self.normalizedPadding(paddingRight)
        value.paddingBottom = Self.normalizedPadding(paddingBottom)
        value.paddingLeft = Self.normalizedPadding(paddingLeft)
        value.counterSpacing = min(
            max(counterSpacing.isFinite ? counterSpacing : 0, 0),
            Self.maximumSpacing
        )
        if value.axis != .horizontal {
            value.wrapMode = .noWrap
            if value.crossAlignment == .baseline {
                value.crossAlignment = .start
            }
        }
        if value.axis != .horizontal || value.wrapMode != .wrap {
            value.crossTrackAlignment = .automatic
        }
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
        containerSizeConstraints: XomoFigmaSizeConstraints? = nil,
        itemLayouts: [ImageEditorStackChildLayout] = [],
        itemSizeConstraints: [XomoFigmaSizeConstraints?] = [],
        itemBaselineOffsets: [CGFloat?] = [],
        layout: ImageEditorStackLayout
    ) -> ImageEditorStackLayoutResult {
        let layout = layout.normalized()
        let resolvedItemSizeConstraints = itemFrames.indices.map { index in
            itemSizeConstraints.indices.contains(index) ? itemSizeConstraints[index] : nil
        }
        var sizes = itemFrames.indices.map { index in
            constrainedSize(itemFrames[index].size, by: resolvedItemSizeConstraints[index])
        }
        let resolvedItemLayouts = itemFrames.indices.map { index in
            itemLayouts.indices.contains(index) ? itemLayouts[index] : ImageEditorStackChildLayout()
        }
        let resolvedItemBaselineOffsets = itemFrames.indices.map { index in
            itemBaselineOffsets.indices.contains(index) ? itemBaselineOffsets[index] : nil
        }
        let originalItemMain = sizes.reduce(0) { partial, size in
            partial + (layout.axis == .horizontal ? size.width : size.height)
        }
        let maximumItemCross: CGFloat
        if layout.axis == .horizontal, layout.crossAlignment == .baseline {
            maximumItemCross = baselineMetrics(
                indices: Array(sizes.indices),
                sizes: sizes,
                itemLayouts: resolvedItemLayouts,
                itemBaselineOffsets: resolvedItemBaselineOffsets
            ).extent
        } else {
            maximumItemCross = sizes.reduce(0) { partial, size in
                max(partial, layout.axis == .horizontal ? size.height : size.width)
            }
        }
        let gapCount = CGFloat(max(0, itemFrames.count - 1))
        let requiredMain = originalItemMain + layout.spacing * gapCount + mainPadding(layout)
        let requiredCross = maximumItemCross + crossPadding(layout)
        var resolvedContainer = constrainedFrame(
            container.standardized,
            by: containerSizeConstraints
        )
        if layout.primarySizingMode == .hug {
            setMainSize(max(1, requiredMain), axis: layout.axis, frame: &resolvedContainer)
            resolvedContainer = constrainedFrame(resolvedContainer, by: containerSizeConstraints)
        }
        if layout.wrapMode == .wrap, layout.axis == .horizontal {
            return wrappedHorizontalLayout(
                in: resolvedContainer,
                sizes: sizes,
                itemLayouts: resolvedItemLayouts,
                itemSizeConstraints: resolvedItemSizeConstraints,
                itemBaselineOffsets: resolvedItemBaselineOffsets,
                containerSizeConstraints: containerSizeConstraints,
                layout: layout
            )
        }
        if layout.crossSizingMode == .hug {
            setCrossSize(max(1, requiredCross), axis: layout.axis, frame: &resolvedContainer)
            resolvedContainer = constrainedFrame(resolvedContainer, by: containerSizeConstraints)
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
        let usesPrimaryFill = resolvedItemLayouts.contains { $0.grow > 0 }
            && layout.primarySizingMode == .fixed
        if usesPrimaryFill {
            let fixedMain = sizes.indices.reduce(0) { partial, index in
                guard resolvedItemLayouts[index].grow <= 0 else { return partial }
                return partial + mainSize(sizes[index], axis: layout.axis)
            }
            let distributableMain = max(0, availableMain - fixedMain - layout.spacing * gapCount)
            distributeMainSpace(
                indices: Array(sizes.indices),
                sizes: &sizes,
                itemLayouts: resolvedItemLayouts,
                itemSizeConstraints: resolvedItemSizeConstraints,
                distributableMain: distributableMain,
                axis: layout.axis
            )
        }
        if layout.crossSizingMode == .fixed {
            for index in sizes.indices where resolvedItemLayouts[index].stretchesCrossAxis {
                setCrossSize(max(1, availableCross), axis: layout.axis, size: &sizes[index])
            }
        }
        for index in sizes.indices {
            sizes[index] = constrainedSize(sizes[index], by: resolvedItemSizeConstraints[index])
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
        let baseline = baselineMetrics(
            indices: Array(sizes.indices),
            sizes: sizes,
            itemLayouts: resolvedItemLayouts,
            itemBaselineOffsets: resolvedItemBaselineOffsets
        )
        let frames = sizes.indices.map { index in
            let size = sizes[index]
            let crossOriginValue: CGFloat
            if layout.axis == .horizontal,
               layout.crossAlignment == .baseline,
               !resolvedItemLayouts[index].stretchesCrossAxis {
                crossOriginValue = inner.minY + baseline.target - resolvedBaselineOffset(
                    at: index,
                    sizes: sizes,
                    itemBaselineOffsets: resolvedItemBaselineOffsets
                )
            } else {
                crossOriginValue = crossOrigin(layout: layout, inner: inner, itemSize: size)
            }
            let frame: CGRect
            if layout.axis == .horizontal {
                frame = CGRect(x: cursor, y: crossOriginValue, width: size.width, height: size.height)
                cursor += size.width + spacing
            } else {
                frame = CGRect(x: crossOriginValue, y: cursor, width: size.width, height: size.height)
                cursor += size.height + spacing
            }
            return frame
        }
        return ImageEditorStackLayoutResult(containerFrame: resolvedContainer, itemFrames: frames)
    }

    static func frames(
        in container: CGRect,
        itemFrames: [CGRect],
        containerSizeConstraints: XomoFigmaSizeConstraints? = nil,
        itemLayouts: [ImageEditorStackChildLayout] = [],
        itemSizeConstraints: [XomoFigmaSizeConstraints?] = [],
        itemBaselineOffsets: [CGFloat?] = [],
        layout: ImageEditorStackLayout
    ) -> [CGRect] {
        self.layout(
            in: container,
            itemFrames: itemFrames,
            containerSizeConstraints: containerSizeConstraints,
            itemLayouts: itemLayouts,
            itemSizeConstraints: itemSizeConstraints,
            itemBaselineOffsets: itemBaselineOffsets,
            layout: layout
        ).itemFrames
    }

    private static func wrappedHorizontalLayout(
        in container: CGRect,
        sizes originalSizes: [CGSize],
        itemLayouts: [ImageEditorStackChildLayout],
        itemSizeConstraints: [XomoFigmaSizeConstraints?],
        itemBaselineOffsets: [CGFloat?],
        containerSizeConstraints: XomoFigmaSizeConstraints?,
        layout: ImageEditorStackLayout
    ) -> ImageEditorStackLayoutResult {
        guard !originalSizes.isEmpty else {
            var emptyContainer = container
            if layout.crossSizingMode == .hug {
                emptyContainer.size.height = max(1, layout.paddingTop + layout.paddingBottom)
            }
            return ImageEditorStackLayoutResult(
                containerFrame: constrainedFrame(emptyContainer, by: containerSizeConstraints),
                itemFrames: []
            )
        }

        let availableMain = max(0, container.width - layout.paddingLeft - layout.paddingRight)
        let rows = wrappedRows(sizes: originalSizes, availableMain: availableMain, spacing: layout.spacing)
        var sizes = originalSizes
        if layout.primarySizingMode == .fixed {
            for row in rows {
                resolveWrappedGrow(
                    row: row,
                    sizes: &sizes,
                    itemLayouts: itemLayouts,
                    itemSizeConstraints: itemSizeConstraints,
                    availableMain: availableMain,
                    spacing: layout.spacing
                )
            }
        }
        var rowHeights = rows.map { row in
            layout.crossAlignment == .baseline
                ? baselineMetrics(
                    indices: row,
                    sizes: sizes,
                    itemLayouts: itemLayouts,
                    itemBaselineOffsets: itemBaselineOffsets
                ).extent
                : row.reduce(CGFloat.zero) { max($0, sizes[$1].height) }
        }
        let rowGapCount = CGFloat(max(0, rows.count - 1))
        let usesSpaceBetweenTracks = layout.crossTrackAlignment == .spaceBetween
            && rows.count > 1
        var contentCross = rowHeights.reduce(0, +)
            + (usesSpaceBetweenTracks ? 0 : layout.counterSpacing * rowGapCount)
        var resolvedContainer = container
        if layout.crossSizingMode == .hug {
            resolvedContainer.size.height = max(1, contentCross + layout.paddingTop + layout.paddingBottom)
            resolvedContainer = constrainedFrame(resolvedContainer, by: containerSizeConstraints)
        } else if itemLayouts.allSatisfy({ $0.stretchesCrossAxis }) && !usesSpaceBetweenTracks {
            let availableCross = max(
                0,
                resolvedContainer.height - layout.paddingTop - layout.paddingBottom
            )
            let extraPerRow = max(0, availableCross - contentCross) / CGFloat(rows.count)
            rowHeights = rowHeights.map { $0 + extraPerRow }
            contentCross = rowHeights.reduce(0, +)
                + layout.counterSpacing * CGFloat(max(0, rows.count - 1))
        }
        let frames = wrappedFrames(
            rows: rows,
            rowHeights: rowHeights,
            sizes: sizes,
            itemLayouts: itemLayouts,
            itemSizeConstraints: itemSizeConstraints,
            itemBaselineOffsets: itemBaselineOffsets,
            container: resolvedContainer,
            availableMain: availableMain,
            contentCross: contentCross,
            layout: layout
        )
        return ImageEditorStackLayoutResult(containerFrame: resolvedContainer, itemFrames: frames)
    }

    private static func wrappedRows(
        sizes: [CGSize],
        availableMain: CGFloat,
        spacing: CGFloat
    ) -> [[Int]] {
        var rows: [[Int]] = []
        var row: [Int] = []
        var usedMain: CGFloat = 0
        for index in sizes.indices {
            let nextMain = row.isEmpty ? sizes[index].width : usedMain + spacing + sizes[index].width
            if !row.isEmpty, nextMain > availableMain {
                rows.append(row)
                row = [index]
                usedMain = sizes[index].width
            } else {
                row.append(index)
                usedMain = nextMain
            }
        }
        if !row.isEmpty {
            rows.append(row)
        }
        return rows
    }

    private static func resolveWrappedGrow(
        row: [Int],
        sizes: inout [CGSize],
        itemLayouts: [ImageEditorStackChildLayout],
        itemSizeConstraints: [XomoFigmaSizeConstraints?],
        availableMain: CGFloat,
        spacing: CGFloat
    ) {
        guard row.contains(where: { itemLayouts[$0].grow > 0 }) else { return }
        let fixedMain = row.reduce(CGFloat.zero) { partial, index in
            itemLayouts[index].grow > 0 ? partial : partial + sizes[index].width
        }
        let distributable = max(0, availableMain - fixedMain - spacing * CGFloat(max(0, row.count - 1)))
        distributeMainSpace(
            indices: row,
            sizes: &sizes,
            itemLayouts: itemLayouts,
            itemSizeConstraints: itemSizeConstraints,
            distributableMain: distributable,
            axis: .horizontal
        )
    }

    private static func wrappedFrames(
        rows: [[Int]],
        rowHeights: [CGFloat],
        sizes: [CGSize],
        itemLayouts: [ImageEditorStackChildLayout],
        itemSizeConstraints: [XomoFigmaSizeConstraints?],
        itemBaselineOffsets: [CGFloat?],
        container: CGRect,
        availableMain: CGFloat,
        contentCross: CGFloat,
        layout: ImageEditorStackLayout
    ) -> [CGRect] {
        var frames = Array(repeating: CGRect.zero, count: sizes.count)
        let availableCross = max(0, container.height - layout.paddingTop - layout.paddingBottom)
        let usesSpaceBetweenTracks = layout.crossTrackAlignment == .spaceBetween
            && rows.count > 1
        let freeCross = max(0, availableCross - contentCross)
        let trackOffset: CGFloat
        switch (layout.crossTrackAlignment, layout.crossAlignment) {
        case (.spaceBetween, _):
            trackOffset = 0
        case (.automatic, .start), (.automatic, .baseline):
            trackOffset = 0
        case (.automatic, .center):
            trackOffset = freeCross / 2
        case (.automatic, .end):
            trackOffset = freeCross
        }
        let trackSpacing = usesSpaceBetweenTracks
            ? max(0, availableCross - rowHeights.reduce(0, +)) / CGFloat(max(1, rows.count - 1))
            : layout.counterSpacing
        var rowOriginY = container.minY + layout.paddingTop + trackOffset
        for (rowOffset, row) in rows.enumerated() {
            let rowHeight = rowHeights[rowOffset]
            let baseline = baselineMetrics(
                indices: row,
                sizes: sizes,
                itemLayouts: itemLayouts,
                itemBaselineOffsets: itemBaselineOffsets
            )
            let metrics = wrappedPrimaryMetrics(
                row: row,
                sizes: sizes,
                itemLayouts: itemLayouts,
                availableMain: availableMain,
                layout: layout
            )
            var cursor = container.minX + layout.paddingLeft + metrics.offset
            for index in row {
                var size = sizes[index]
                if itemLayouts[index].stretchesCrossAxis {
                    size.height = max(1, rowHeight)
                }
                size = constrainedSize(size, by: itemSizeConstraints[index])
                let y: CGFloat
                if layout.crossAlignment == .baseline,
                   !itemLayouts[index].stretchesCrossAxis {
                    y = rowOriginY + baseline.target - resolvedBaselineOffset(
                        at: index,
                        sizes: sizes,
                        itemBaselineOffsets: itemBaselineOffsets
                    )
                } else {
                    y = wrappedCrossOrigin(
                        rowOrigin: rowOriginY,
                        rowHeight: rowHeight,
                        itemHeight: size.height,
                        alignment: layout.crossAlignment
                    )
                }
                frames[index] = CGRect(origin: CGPoint(x: cursor, y: y), size: size)
                cursor += size.width + metrics.spacing
            }
            rowOriginY += rowHeight + trackSpacing
        }
        return frames
    }

    private static func wrappedPrimaryMetrics(
        row: [Int],
        sizes: [CGSize],
        itemLayouts: [ImageEditorStackChildLayout],
        availableMain: CGFloat,
        layout: ImageEditorStackLayout
    ) -> (spacing: CGFloat, offset: CGFloat) {
        let totalMain = row.reduce(CGFloat.zero) { $0 + sizes[$1].width }
        let gapCount = CGFloat(max(0, row.count - 1))
        let usesFill = layout.primarySizingMode == .fixed
            && row.contains { itemLayouts[$0].grow > 0 }
        let spacing = layout.primaryAlignment == .spaceBetween && row.count > 1 && !usesFill
            ? max(0, availableMain - totalMain) / gapCount
            : layout.spacing
        let contentMain = totalMain + spacing * gapCount
        let offset: CGFloat
        switch (layout.primaryAlignment, usesFill) {
        case (_, true), (.start, false), (.spaceBetween, false): offset = 0
        case (.center, false): offset = (availableMain - contentMain) / 2
        case (.end, false): offset = availableMain - contentMain
        }
        return (spacing, offset)
    }

    private static func wrappedCrossOrigin(
        rowOrigin: CGFloat,
        rowHeight: CGFloat,
        itemHeight: CGFloat,
        alignment: ImageEditorStackCrossAlignment
    ) -> CGFloat {
        switch alignment {
        case .start, .baseline:
            return rowOrigin
        case .center:
            return rowOrigin + (rowHeight - itemHeight) / 2
        case .end:
            return rowOrigin + rowHeight - itemHeight
        }
    }

    private static func baselineMetrics(
        indices: [Int],
        sizes: [CGSize],
        itemLayouts: [ImageEditorStackChildLayout],
        itemBaselineOffsets: [CGFloat?]
    ) -> (target: CGFloat, extent: CGFloat) {
        let maximumHeight = indices.reduce(CGFloat.zero) { partial, index in
            max(partial, sizes[index].height)
        }
        let alignedIndices = indices.filter { !itemLayouts[$0].stretchesCrossAxis }
        guard !alignedIndices.isEmpty else {
            return (0, maximumHeight)
        }
        let target = alignedIndices.reduce(CGFloat.zero) { partial, index in
            max(
                partial,
                resolvedBaselineOffset(
                    at: index,
                    sizes: sizes,
                    itemBaselineOffsets: itemBaselineOffsets
                )
            )
        }
        let descent = alignedIndices.reduce(CGFloat.zero) { partial, index in
            let offset = resolvedBaselineOffset(
                at: index,
                sizes: sizes,
                itemBaselineOffsets: itemBaselineOffsets
            )
            return max(partial, sizes[index].height - offset)
        }
        return (target, max(maximumHeight, target + descent))
    }

    private static func resolvedBaselineOffset(
        at index: Int,
        sizes: [CGSize],
        itemBaselineOffsets: [CGFloat?]
    ) -> CGFloat {
        let height = max(0, sizes[index].height)
        guard itemBaselineOffsets.indices.contains(index),
              let requested = itemBaselineOffsets[index],
              requested.isFinite
        else { return height }
        return min(max(requested, 0), height)
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

    private static func constrainedSize(
        _ size: CGSize,
        by constraints: XomoFigmaSizeConstraints?
    ) -> CGSize {
        guard let constraints else { return size }
        return CGSize(
            width: constrainedDimension(
                size.width,
                minimum: constraints.minWidth,
                maximum: constraints.maxWidth
            ),
            height: constrainedDimension(
                size.height,
                minimum: constraints.minHeight,
                maximum: constraints.maxHeight
            )
        )
    }

    private static func constrainedFrame(
        _ frame: CGRect,
        by constraints: XomoFigmaSizeConstraints?
    ) -> CGRect {
        var result = frame
        result.size = constrainedSize(result.size, by: constraints)
        return result
    }

    private static func constrainedDimension(
        _ value: CGFloat,
        minimum: Double?,
        maximum: Double?
    ) -> CGFloat {
        let bounds = dimensionBounds(minimum: minimum, maximum: maximum)
        return min(max(value.isFinite ? value : bounds.lower, bounds.lower), bounds.upper)
    }

    private static func distributeMainSpace(
        indices: [Int],
        sizes: inout [CGSize],
        itemLayouts: [ImageEditorStackChildLayout],
        itemSizeConstraints: [XomoFigmaSizeConstraints?],
        distributableMain: CGFloat,
        axis: ImageEditorStackAxis
    ) {
        var active = indices.filter { itemLayouts[$0].grow > 0 }
        var remaining = max(0, distributableMain)
        while !active.isEmpty {
            let totalWeight = active.reduce(CGFloat.zero) { $0 + itemLayouts[$1].grow }
            guard totalWeight > 0 else { return }
            let iterationRemaining = remaining
            var locked: [(index: Int, value: CGFloat)] = []
            for index in active {
                let share = iterationRemaining * itemLayouts[index].grow / totalWeight
                let bounds = mainDimensionBounds(itemSizeConstraints[index], axis: axis)
                if share < bounds.lower {
                    locked.append((index, bounds.lower))
                } else if share > bounds.upper {
                    locked.append((index, bounds.upper))
                }
            }
            if locked.isEmpty {
                for index in active {
                    let share = remaining * itemLayouts[index].grow / totalWeight
                    setMainSize(max(1, share), axis: axis, size: &sizes[index])
                }
                return
            }
            for item in locked {
                setMainSize(item.value, axis: axis, size: &sizes[item.index])
            }
            remaining = max(0, remaining - locked.reduce(CGFloat.zero) { $0 + $1.value })
            let lockedSet = Set(locked.map(\.index))
            active.removeAll { lockedSet.contains($0) }
        }
    }

    private static func mainDimensionBounds(
        _ constraints: XomoFigmaSizeConstraints?,
        axis: ImageEditorStackAxis
    ) -> (lower: CGFloat, upper: CGFloat) {
        guard let constraints else { return (1, .greatestFiniteMagnitude) }
        return axis == .horizontal
            ? dimensionBounds(minimum: constraints.minWidth, maximum: constraints.maxWidth)
            : dimensionBounds(minimum: constraints.minHeight, maximum: constraints.maxHeight)
    }

    private static func dimensionBounds(
        minimum: Double?,
        maximum: Double?
    ) -> (lower: CGFloat, upper: CGFloat) {
        let lower = minimum.flatMap { $0.isFinite ? max(1, CGFloat($0)) : nil } ?? 1
        let requestedUpper = maximum.flatMap { $0.isFinite ? max(1, CGFloat($0)) : nil }
        return (lower, max(lower, requestedUpper ?? .greatestFiniteMagnitude))
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
        case .start, .baseline:
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

    func setSelectedStackWrapMode(_ mode: ImageEditorStackWrapMode) {
        updateSelectedStackLayout { $0.wrapMode = mode }
    }

    func setSelectedStackCounterSpacing(_ spacing: CGFloat) {
        updateSelectedStackLayout { $0.counterSpacing = spacing }
    }

    func setSelectedStackCrossTrackAlignment(_ alignment: ImageEditorStackCrossTrackAlignment) {
        updateSelectedStackLayout { $0.crossTrackAlignment = alignment }
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

    func setSelectedFigmaSizeConstraint(
        _ field: XomoFigmaSizeConstraintField,
        value: Double?
    ) {
        guard value == nil || value?.isFinite == true,
              let layerIndex = document.selectedLayerIndex else { return }
        let normalizedValue = value.map {
            min(Double(ImageEditorTextContent.maximumBoxDimension), max(1, $0))
        }
        var constraints = document.layers[layerIndex].xomoFigmaSizeConstraints
            ?? .empty
        guard field.value(in: constraints) != normalizedValue else { return }

        let reflowTarget = stackReflowTarget(for: document.layers[layerIndex])
        if let reflowTarget, !canEditStackLayout(groupID: reflowTarget.groupID) {
            statusText = L10n.text("imageEditor.status.stackLayoutLocked")
            return
        }

        pushUndo()
        if document.layers[layerIndex].xomoFigmaSizeConstraintDefaults == nil {
            document.layers[layerIndex].xomoFigmaSizeConstraintDefaults = constraints
        }
        field.set(normalizedValue, in: &constraints)
        document.layers[layerIndex].xomoFigmaSizeConstraints = constraints.isEmpty ? nil : constraints
        if let reflowTarget {
            applyStackLayout(groupID: reflowTarget.groupID, layout: reflowTarget.layout)
        }
        appendHistory(L10n.format(
            "imageEditor.history.figmaSizeConstraintChanged",
            L10n.text(field.localizationKey)
        ))
        statusText = L10n.format(
            "imageEditor.status.figmaSizeConstraintUpdated",
            L10n.text(field.localizationKey)
        )
    }

    func resetSelectedFigmaSizeConstraint(_ field: XomoFigmaSizeConstraintField) {
        guard let defaults = selectedLayerFigmaSizeConstraintDefaults else { return }
        setSelectedFigmaSizeConstraint(field, value: field.value(in: defaults))
    }

    func resetAllSelectedFigmaSizeConstraints() {
        guard let layerIndex = document.selectedLayerIndex,
              let defaults = document.layers[layerIndex].xomoFigmaSizeConstraintDefaults,
              (document.layers[layerIndex].xomoFigmaSizeConstraints ?? .empty) != defaults
        else { return }

        let reflowTarget = stackReflowTarget(for: document.layers[layerIndex])
        if let reflowTarget, !canEditStackLayout(groupID: reflowTarget.groupID) {
            statusText = L10n.text("imageEditor.status.stackLayoutLocked")
            return
        }

        pushUndo()
        document.layers[layerIndex].xomoFigmaSizeConstraints = defaults.isEmpty ? nil : defaults
        if let reflowTarget {
            applyStackLayout(groupID: reflowTarget.groupID, layout: reflowTarget.layout)
        }
        appendHistory(L10n.text("imageEditor.history.figmaSizeConstraintsReset"))
        statusText = L10n.text("imageEditor.status.figmaSizeConstraintsReset")
    }

    func resolveSelectedFigmaSizeConstraintConflict(
        _ conflict: XomoFigmaSizeConstraintConflict
    ) {
        guard let constraints = selectedLayerFigmaSizeConstraints,
              constraints.conflicts.contains(conflict),
              let minimum = conflict.minimumField.value(in: constraints)
        else { return }
        setSelectedFigmaSizeConstraint(conflict.maximumField, value: minimum)
    }

    func resolveAllSelectedFigmaSizeConstraintConflicts() {
        guard let layerIndex = document.selectedLayerIndex,
              let constraints = document.layers[layerIndex].xomoFigmaSizeConstraints,
              !constraints.conflicts.isEmpty
        else { return }

        let reflowTarget = stackReflowTarget(for: document.layers[layerIndex])
        if let reflowTarget, !canEditStackLayout(groupID: reflowTarget.groupID) {
            statusText = L10n.text("imageEditor.status.stackLayoutLocked")
            return
        }

        pushUndo()
        if document.layers[layerIndex].xomoFigmaSizeConstraintDefaults == nil {
            document.layers[layerIndex].xomoFigmaSizeConstraintDefaults = constraints
        }
        document.layers[layerIndex].xomoFigmaSizeConstraints =
            constraints.resolvingConflictsPreferringMinimum()
        if let reflowTarget {
            applyStackLayout(groupID: reflowTarget.groupID, layout: reflowTarget.layout)
        }
        appendHistory(L10n.text("imageEditor.history.figmaSizeConstraintConflictsResolved"))
        statusText = L10n.text("imageEditor.status.figmaSizeConstraintConflictsResolved")
    }

    var hasSelectedFigmaSizeConstraintOverrides: Bool {
        XomoFigmaSizeConstraintField.allCases.contains {
            hasSelectedFigmaSizeConstraintOverride($0)
        }
    }

    func hasSelectedFigmaSizeConstraintOverride(
        _ field: XomoFigmaSizeConstraintField
    ) -> Bool {
        guard let defaults = selectedLayerFigmaSizeConstraintDefaults else { return false }
        return field.value(in: selectedLayerFigmaSizeConstraints ?? .empty)
            != field.value(in: defaults)
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
            containerSizeConstraints: group.xomoFigmaSizeConstraints,
            itemLayouts: participantIndices.map {
                document.layers[$0].stackChildLayout ?? ImageEditorStackChildLayout()
            },
            itemSizeConstraints: participantIndices.map {
                document.layers[$0].xomoFigmaSizeConstraints
            },
            itemBaselineOffsets: participantIndices.map {
                document.layers[$0].stackBaselineOffset
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

    private func stackReflowTarget(
        for layer: ImageEditorLayer
    ) -> (groupID: UUID, layout: ImageEditorStackLayout)? {
        if let groupID = layer.groupID,
           let layout = document.layers.first(where: { $0.id == groupID })?.stackLayout {
            return (groupID, layout)
        }
        if let layout = layer.stackLayout {
            return (layer.id, layout)
        }
        return nil
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
