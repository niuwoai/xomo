import Foundation

/// Reuses only immutable, value-semantic selection/channel content. All image
/// payloads and other fields are freshly encoded and compared byte for byte.
struct ImageEditorProjectContentCheckpoint {
    private let selection: ImageEditorSelection?
    private let savedSelection: ImageEditorSelection?
    private let alphaChannels: [ImageEditorAlphaChannel]
    private let remainingData: Data

    init(project: ImageEditorProjectDocument) throws {
        selection = project.selection
        savedSelection = project.savedSelection
        alphaChannels = project.alphaChannels
        remainingData = try Self.remainingProjectData(project)
    }

    /// nil means equivalence is unproven and the full-data baseline must be used.
    func matches(_ project: ImageEditorProjectDocument) throws -> Bool? {
        guard Self.sameSelectionEncoding(selection, project.selection),
              Self.sameSelectionEncoding(savedSelection, project.savedSelection),
              Self.sameChannelEncoding(alphaChannels, project.alphaChannels)
        else { return nil }
        return try remainingData == Self.remainingProjectData(project)
    }

    private static func remainingProjectData(_ project: ImageEditorProjectDocument) throws -> Data {
        var remaining = project
        remaining.selection = nil
        remaining.savedSelection = nil
        remaining.alphaChannels = []
        return try remaining.encodedProjectData()
    }

    // Format 10 selection fields contain only finite coordinates, Booleans,
    // integers and alpha bytes. Preserve coordinate bits, including signed zero;
    // ordinary Equatable alone does not prove identical JSON representation.
    private static func sameSelectionEncoding(_ lhs: ImageEditorSelection?, _ rhs: ImageEditorSelection?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil): return true
        case let (lhs?, rhs?):
            guard lhs.isPolygon == rhs.isPolygon, lhs.isInverted == rhs.isInverted,
                  lhs.rasterMask == rhs.rasterMask, lhs.points.count == rhs.points.count
            else { return false }
            return zip(lhs.points, rhs.points).allSatisfy { first, second in
                first.x.isFinite && first.y.isFinite &&
                    Double(first.x).bitPattern == Double(second.x).bitPattern &&
                    Double(first.y).bitPattern == Double(second.y).bitPattern
            }
        default: return false
        }
    }

    // Strings use UTF-8 rather than canonical Unicode equality. A channel name
    // with equal glyphs but different stored scalars still needs the full check.
    private static func sameChannelEncoding(_ lhs: [ImageEditorAlphaChannel], _ rhs: [ImageEditorAlphaChannel]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        return zip(lhs, rhs).allSatisfy { first, second in
            first.id == second.id && first.name.utf8.elementsEqual(second.name.utf8) &&
                first.mask == second.mask && first.kind == second.kind && first.spotColor == second.spotColor
        }
    }
}
