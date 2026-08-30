import Foundation

enum XomoFigmaNodeIdentityValidation {
    /// Validate the entire selected tree before mask dictionaries or recursive
    /// mapping consume any IDs. Unselected response envelopes are irrelevant.
    static func validate(root: XomoFigmaNode) throws {
        var pending = [root]
        var seen = Set<String>()
        let limit = XomoFigmaNodeImportMapper.maximumNodeCount
        while let node = pending.popLast() {
            guard seen.count < limit else {
                throw XomoFigmaNodeImportError.nodeLimitExceeded
            }
            guard insert(node.id, into: &seen) else {
                throw XomoFigmaNodeImportError.invalidResponse
            }
            let children = node.children ?? []
            guard children.count <= limit - seen.count - pending.count else {
                throw XomoFigmaNodeImportError.nodeLimitExceeded
            }
            pending.append(contentsOf: children)
        }
    }

    static func error(in items: [XomoFigmaNodeImportItem]) -> XomoFigmaNodeImportError? {
        guard items.count <= XomoFigmaNodeImportMapper.maximumNodeCount else {
            return .nodeLimitExceeded
        }
        var seen = Set<String>()
        for item in items {
            guard insert(item.sourceID, into: &seen) else { return .invalidResponse }
        }
        return nil
    }

    private static func insert(_ id: String, into seen: inout Set<String>) -> Bool {
        !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && seen.insert(id).inserted
    }
}
