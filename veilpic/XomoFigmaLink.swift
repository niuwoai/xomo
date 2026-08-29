import Foundation

enum XomoFigmaResourceType: String, CaseIterable, Codable, Sendable {
    case design
    case legacyFile = "file"
    case prototype = "proto"
    case figJam = "board"
    case slides
    case slideDeck = "deck"
    case site
    case buzz
    case make
    case communityFile = "community/file"

    var plannedImportScope: XomoFigmaPlannedImportScope {
        switch self {
        case .design, .legacyFile, .prototype:
            .designDocument
        case .figJam:
            .figJamBoard
        case .slides, .slideDeck, .site, .buzz, .make, .communityFile:
            .previewOnly
        }
    }

    var localizationKey: String {
        switch self {
        case .design:
            "xomo.figma.resource.design"
        case .legacyFile:
            "xomo.figma.resource.legacyFile"
        case .prototype:
            "xomo.figma.resource.prototype"
        case .figJam:
            "xomo.figma.resource.figJam"
        case .slides:
            "xomo.figma.resource.slides"
        case .slideDeck:
            "xomo.figma.resource.slideDeck"
        case .site:
            "xomo.figma.resource.site"
        case .buzz:
            "xomo.figma.resource.buzz"
        case .make:
            "xomo.figma.resource.make"
        case .communityFile:
            "xomo.figma.resource.communityFile"
        }
    }
}

enum XomoFigmaPlannedImportScope: String, CaseIterable, Codable, Sendable {
    case designDocument
    case figJamBoard
    case previewOnly

    var localizationKey: String {
        "xomo.figma.scope.\(rawValue)"
    }
}

enum XomoFigmaAuthorizationState: String, Codable, Sendable {
    case notChecked

    var localizationKey: String {
        "xomo.figma.authorization.\(rawValue)"
    }
}

struct XomoFigmaLinkPreview: Equatable, Codable, Sendable {
    var resourceType: XomoFigmaResourceType
    var fileKey: String
    var fileSlug: String
    var nodeID: String?
    var startingPointNodeID: String?
    var versionID: String?
    var canonicalURL: URL
    var discardedQueryItemCount: Int

    var displayName: String {
        fileSlug.replacingOccurrences(of: "-", with: " ")
    }

    var plannedImportScope: XomoFigmaPlannedImportScope {
        resourceType.plannedImportScope
    }

    var authorizationState: XomoFigmaAuthorizationState {
        .notChecked
    }
}

enum XomoFigmaLinkParserError: Error, Equatable, CaseIterable, Sendable {
    case emptyInput
    case inputTooLong
    case malformedURL
    case insecureScheme
    case untrustedHost
    case credentialsNotAllowed
    case customPortNotAllowed
    case fragmentNotAllowed
    case unsupportedResourceType
    case invalidFileKey
    case invalidFileName
    case duplicateSelector
    case invalidNodeID
    case invalidVersionID

    var localizationKey: String {
        switch self {
        case .emptyInput:
            "xomo.figma.error.emptyInput"
        case .inputTooLong:
            "xomo.figma.error.inputTooLong"
        case .malformedURL:
            "xomo.figma.error.malformedURL"
        case .insecureScheme:
            "xomo.figma.error.insecureScheme"
        case .untrustedHost:
            "xomo.figma.error.untrustedHost"
        case .credentialsNotAllowed:
            "xomo.figma.error.credentialsNotAllowed"
        case .customPortNotAllowed:
            "xomo.figma.error.customPortNotAllowed"
        case .fragmentNotAllowed:
            "xomo.figma.error.fragmentNotAllowed"
        case .unsupportedResourceType:
            "xomo.figma.error.unsupportedResourceType"
        case .invalidFileKey:
            "xomo.figma.error.invalidFileKey"
        case .invalidFileName:
            "xomo.figma.error.invalidFileName"
        case .duplicateSelector:
            "xomo.figma.error.duplicateSelector"
        case .invalidNodeID:
            "xomo.figma.error.invalidNodeID"
        case .invalidVersionID:
            "xomo.figma.error.invalidVersionID"
        }
    }
}

enum XomoFigmaLinkImportState: Equatable {
    case empty
    case valid(XomoFigmaLinkPreview)
    case invalid(XomoFigmaLinkParserError)
}

struct XomoFigmaLinkImportDraft: Equatable {
    private(set) var input = ""
    private(set) var state: XomoFigmaLinkImportState = .empty

    init(input: String = "") {
        updateInput(input)
    }

    var preview: XomoFigmaLinkPreview? {
        guard case let .valid(preview) = state else { return nil }
        return preview
    }

    var error: XomoFigmaLinkParserError? {
        guard case let .invalid(error) = state else { return nil }
        return error
    }

    var canCopyCanonicalURL: Bool {
        preview != nil
    }

    var canonicalURLForExternalOpen: URL? {
        XomoFigmaSourceOpenPolicy.canonicalURL(from: preview?.canonicalURL)
    }

    var canUseCanonicalURL: Bool {
        guard let canonicalURL = preview?.canonicalURL.absoluteString else { return false }
        return input != canonicalURL
    }

    @discardableResult
    mutating func useCanonicalURL() -> Bool {
        guard let preview, canUseCanonicalURL else { return false }
        input = preview.canonicalURL.absoluteString
        var canonicalPreview = preview
        canonicalPreview.discardedQueryItemCount = 0
        state = .valid(canonicalPreview)
        return true
    }

    @discardableResult
    mutating func retarget(toNodeInput nodeInput: String) -> Bool {
        guard let preview,
              let nodeID = XomoFigmaNodeSelectionInput.nodeID(
                from: nodeInput,
                matchingFileKey: preview.fileKey
              ),
              let retargetedURL = XomoFigmaSourceOpenPolicy.canonicalURL(
                from: preview.canonicalURL,
                selectingNodeID: nodeID
              )
        else { return false }
        updateInput(retargetedURL.absoluteString)
        return true
    }

    mutating func updateInput(_ value: String) {
        input = value
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            state = .empty
            return
        }
        do {
            state = .valid(try XomoFigmaLinkParser.parse(value))
        } catch let parserError as XomoFigmaLinkParserError {
            if let sharedTextPreview = XomoFigmaSharedTextInput.preview(in: value) {
                state = .valid(sharedTextPreview)
            } else {
                state = .invalid(parserError)
            }
        } catch {
            assertionFailure("Unexpected Figma link parser error: \(error)")
            state = .invalid(.malformedURL)
        }
    }
}

enum XomoFigmaNodeSelectionInput {
    static func nodeID(from input: String, matchingFileKey fileKey: String) -> String? {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return nil }
        guard trimmedInput.contains("://") else { return trimmedInput }
        guard let linkedPreview = try? XomoFigmaLinkParser.parse(trimmedInput),
              linkedPreview.fileKey == fileKey,
              let nodeID = linkedPreview.nodeID
        else { return nil }
        return nodeID
    }
}

enum XomoFigmaClipboardPasteRoute: Equatable {
    case layerPayload
    case figmaLink(String)
    case unavailable
}

enum XomoFigmaClipboardLinkPolicy {
    static func canonicalURL(
        clipboardText: String?,
        clipboardURLString: String? = nil
    ) -> String? {
        let textPreview: XomoFigmaLinkPreview?
        if let clipboardText {
            textPreview = XomoFigmaSharedTextInput.preview(in: clipboardText)
        } else {
            textPreview = nil
        }
        if let clipboardURLString,
           !clipboardURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let urlPreview = XomoFigmaSharedTextInput.preview(in: clipboardURLString) else {
                return nil
            }
            guard textPreview == nil || textPreview?.canonicalURL == urlPreview.canonicalURL else {
                return nil
            }
            return urlPreview.canonicalURL.absoluteString
        }

        return textPreview?.canonicalURL.absoluteString
    }
}

enum XomoFigmaClipboardPastePolicy {
    static func resolve(
        hasLayerPayload: Bool,
        clipboardText: String?,
        clipboardURLString: String? = nil
    ) -> XomoFigmaClipboardPasteRoute {
        guard !hasLayerPayload else { return .layerPayload }
        guard let canonicalURL = XomoFigmaClipboardLinkPolicy.canonicalURL(
            clipboardText: clipboardText,
            clipboardURLString: clipboardURLString
        ) else { return .unavailable }
        return .figmaLink(canonicalURL)
    }
}

enum XomoFigmaSharedTextInput {
    static func preview(in input: String) -> XomoFigmaLinkPreview? {
        if let exactPreview = try? XomoFigmaLinkParser.parse(input) {
            return exactPreview
        }

        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty,
              trimmedInput.count <= XomoFigmaLinkParser.maximumInputLength,
              let detector = try? NSDataDetector(
                types: NSTextCheckingResult.CheckingType.link.rawValue
              )
        else { return nil }

        let range = NSRange(trimmedInput.startIndex..., in: trimmedInput)
        let links = detector.matches(in: trimmedInput, options: [], range: range)
        guard links.count == 1,
              let detectedURL = links.first?.url
        else { return nil }
        return try? XomoFigmaLinkParser.parse(detectedURL.absoluteString)
    }
}

enum XomoFigmaSourceOpenPolicy {
    static func canonicalURL(
        from candidate: URL?,
        selectingNodeID selectedNodeID: String? = nil
    ) -> URL? {
        guard let candidate,
              let preview = try? XomoFigmaLinkParser.parse(candidate.absoluteString)
        else { return nil }
        guard let selectedNodeID else { return preview.canonicalURL }
        guard var components = URLComponents(
            url: preview.canonicalURL,
            resolvingAgainstBaseURL: false
        ) else { return nil }
        var queryItems = components.queryItems?.filter { $0.name != "node-id" } ?? []
        queryItems.append(URLQueryItem(
            name: "node-id",
            value: selectedNodeID.replacingOccurrences(of: ":", with: "-")
        ))
        components.queryItems = queryItems
        guard let retargetedURL = components.url,
              let retargetedPreview = try? XomoFigmaLinkParser.parse(retargetedURL.absoluteString)
        else { return nil }
        return retargetedPreview.canonicalURL
    }
}

enum XomoCanvasURLDropRoute: Equatable {
    case localFiles([URL])
    case figmaLink(String)
    case unavailable
}

enum XomoCanvasURLDropPolicy {
    static func resolve(_ urls: [URL]) -> XomoCanvasURLDropRoute {
        if let localFiles = ImageEditorLayerFileImportPolicy.supportedURLs(from: urls) {
            return .localFiles(localFiles)
        }
        guard urls.count == 1,
              let url = urls.first,
              let preview = try? XomoFigmaLinkParser.parse(url.absoluteString)
        else { return .unavailable }
        return .figmaLink(preview.canonicalURL.absoluteString)
    }
}

enum XomoCanvasStringDropRoute: Equatable {
    case componentPayload(String)
    case figmaLink(String)
    case unavailable
}

enum XomoCanvasStringDropPolicy {
    static func resolve(
        _ values: [String],
        knownComponentPayloads: Set<String>
    ) -> XomoCanvasStringDropRoute {
        guard values.count == 1, let value = values.first else { return .unavailable }
        if knownComponentPayloads.contains(value) {
            return .componentPayload(value)
        }
        guard let preview = XomoFigmaSharedTextInput.preview(in: value) else {
            return .unavailable
        }
        return .figmaLink(preview.canonicalURL.absoluteString)
    }
}

enum XomoFigmaLinkParser {
    static let maximumInputLength = 4_096
    private static let standardPathComponentCount = 4
    private static let communityPathComponentCount = 5
    private static let minimumFileKeyLength = 6
    private static let maximumIdentifierLength = 128
    private static let maximumFileSlugLength = 200
    private static let trustedHosts = ["figma.com", "www.figma.com"]
    private static let selectorNames = ["node-id", "starting-point-node-id", "version-id"]

    static func parse(_ input: String) throws -> XomoFigmaLinkPreview {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { throw XomoFigmaLinkParserError.emptyInput }
        guard trimmedInput.count <= maximumInputLength else { throw XomoFigmaLinkParserError.inputTooLong }
        guard !trimmedInput.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 }),
              let components = URLComponents(string: trimmedInput)
        else { throw XomoFigmaLinkParserError.malformedURL }

        try validateOrigin(components)
        let identity = try parseIdentity(components.percentEncodedPath)
        let selectors = try parseSelectors(components.queryItems ?? [])
        let canonicalURL = try makeCanonicalURL(identity: identity, selectors: selectors)

        return XomoFigmaLinkPreview(
            resourceType: identity.resourceType,
            fileKey: identity.fileKey,
            fileSlug: identity.fileSlug,
            nodeID: selectors.nodeID,
            startingPointNodeID: selectors.startingPointNodeID,
            versionID: selectors.versionID,
            canonicalURL: canonicalURL,
            discardedQueryItemCount: selectors.discardedCount
        )
    }

    private static func validateOrigin(_ components: URLComponents) throws {
        guard components.scheme?.lowercased() == "https" else {
            throw XomoFigmaLinkParserError.insecureScheme
        }
        guard let host = components.host?.lowercased(), trustedHosts.contains(host) else {
            throw XomoFigmaLinkParserError.untrustedHost
        }
        guard components.user == nil, components.password == nil else {
            throw XomoFigmaLinkParserError.credentialsNotAllowed
        }
        guard components.port == nil else {
            throw XomoFigmaLinkParserError.customPortNotAllowed
        }
        guard components.fragment == nil else {
            throw XomoFigmaLinkParserError.fragmentNotAllowed
        }
    }

    private static func parseIdentity(_ percentEncodedPath: String) throws -> FigmaIdentity {
        let encodedSegments = percentEncodedPath.split(separator: "/", omittingEmptySubsequences: false)
        guard encodedSegments.first?.isEmpty == true else {
            throw XomoFigmaLinkParserError.malformedURL
        }

        let resourceType: XomoFigmaResourceType
        let encodedFileKey: Substring
        let encodedFileSlug: Substring
        if encodedSegments.count == communityPathComponentCount,
           encodedSegments[1] == "community",
           encodedSegments[2] == "file" {
            resourceType = .communityFile
            encodedFileKey = encodedSegments[3]
            encodedFileSlug = encodedSegments[4]
        } else {
            guard encodedSegments.count == standardPathComponentCount,
                  let resourcePath = String(encodedSegments[1]).removingPercentEncoding,
                  let standardResourceType = XomoFigmaResourceType(rawValue: resourcePath)
            else { throw XomoFigmaLinkParserError.unsupportedResourceType }
            resourceType = standardResourceType
            encodedFileKey = encodedSegments[2]
            encodedFileSlug = encodedSegments[3]
        }
        guard let fileKey = String(encodedFileKey).removingPercentEncoding,
              let fileSlug = String(encodedFileSlug).removingPercentEncoding
        else { throw XomoFigmaLinkParserError.malformedURL }
        guard isSafeIdentifier(fileKey, minimumLength: minimumFileKeyLength) else {
            throw XomoFigmaLinkParserError.invalidFileKey
        }
        guard isSafeFileSlug(fileSlug) else {
            throw XomoFigmaLinkParserError.invalidFileName
        }
        return FigmaIdentity(resourceType: resourceType, fileKey: fileKey, fileSlug: fileSlug)
    }

    private static func parseSelectors(_ queryItems: [URLQueryItem]) throws -> FigmaSelectors {
        var values: [String: String] = [:]
        var discardedCount = 0
        for item in queryItems {
            guard selectorNames.contains(item.name) else {
                discardedCount += 1
                continue
            }
            guard values[item.name] == nil else {
                throw XomoFigmaLinkParserError.duplicateSelector
            }
            values[item.name] = item.value ?? ""
        }
        return FigmaSelectors(
            nodeID: try normalizedNodeID(values["node-id"]),
            startingPointNodeID: try normalizedNodeID(values["starting-point-node-id"]),
            versionID: try normalizedVersionID(values["version-id"]),
            discardedCount: discardedCount
        )
    }

    private static func normalizedNodeID(_ value: String?) throws -> String? {
        guard let value else { return nil }
        let normalized = value.replacingOccurrences(of: "-", with: ":")
        guard !normalized.isEmpty, normalized.count <= maximumIdentifierLength,
              normalized.contains(where: { $0.isNumber })
        else { throw XomoFigmaLinkParserError.invalidNodeID }
        let sections = normalized.split(separator: ";", omittingEmptySubsequences: false)
        let isValid = sections.allSatisfy { section in
            let components = section.split(separator: ":", omittingEmptySubsequences: false)
            return (1...2).contains(components.count) && components.allSatisfy(isSafeNodeComponent)
        }
        guard isValid else { throw XomoFigmaLinkParserError.invalidNodeID }
        return normalized
    }

    private static func normalizedVersionID(_ value: String?) throws -> String? {
        guard let value else { return nil }
        guard isSafeIdentifier(value, minimumLength: 1) else {
            throw XomoFigmaLinkParserError.invalidVersionID
        }
        return value
    }

    private static func makeCanonicalURL(
        identity: FigmaIdentity,
        selectors: FigmaSelectors
    ) throws -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.figma.com"
        components.path = "/\(identity.resourceType.rawValue)/\(identity.fileKey)/\(identity.fileSlug)"
        components.queryItems = canonicalQueryItems(selectors)
        if let percentEncodedQuery = components.percentEncodedQuery {
            components.percentEncodedQuery = percentEncodedQuery.replacingOccurrences(
                of: ";",
                with: "%3B"
            )
        }
        guard let url = components.url else { throw XomoFigmaLinkParserError.malformedURL }
        return url
    }

    private static func canonicalQueryItems(_ selectors: FigmaSelectors) -> [URLQueryItem]? {
        var items: [URLQueryItem] = []
        if let nodeID = selectors.nodeID {
            items.append(URLQueryItem(name: "node-id", value: urlNodeID(nodeID)))
        }
        if let startingPointNodeID = selectors.startingPointNodeID {
            items.append(URLQueryItem(name: "starting-point-node-id", value: urlNodeID(startingPointNodeID)))
        }
        if let versionID = selectors.versionID {
            items.append(URLQueryItem(name: "version-id", value: versionID))
        }
        return items.isEmpty ? nil : items
    }

    private static func urlNodeID(_ nodeID: String) -> String {
        nodeID.replacingOccurrences(of: ":", with: "-")
    }

    private static func isSafeIdentifier(_ value: String, minimumLength: Int) -> Bool {
        guard (minimumLength...maximumIdentifierLength).contains(value.count) else { return false }
        return value.unicodeScalars.allSatisfy { scalar in
            scalar.isASCII && (CharacterSet.alphanumerics.contains(scalar) || scalar == "_" || scalar == "-")
        }
    }

    nonisolated private static func isSafeNodeComponent(_ component: Substring) -> Bool {
        guard !component.isEmpty else { return false }
        return component.unicodeScalars.allSatisfy { scalar in
            scalar.isASCII && (CharacterSet.alphanumerics.contains(scalar) || scalar == "_")
        }
    }

    private static func isSafeFileSlug(_ value: String) -> Bool {
        guard (1...maximumFileSlugLength).contains(value.count), value != ".", value != "..",
              value.trimmingCharacters(in: .whitespacesAndNewlines) == value
        else { return false }
        return !value.unicodeScalars.contains { scalar in
            scalar.value < 32 || scalar.value == 127 || scalar == "/" || scalar == "\\"
        }
    }
}

private struct FigmaIdentity {
    var resourceType: XomoFigmaResourceType
    var fileKey: String
    var fileSlug: String
}

private struct FigmaSelectors {
    var nodeID: String?
    var startingPointNodeID: String?
    var versionID: String?
    var discardedCount: Int
}
