import AppKit
import Testing
@testable import musepic

@MainActor
struct XomoFigmaNodeIdentityTests {
    enum InvalidTree: CaseIterable {
        case siblings, ancestor, separateBranches, maskedSiblings, emptyRoot, whitespaceChild
    }

    @Test(arguments: InvalidTree.allCases)
    func mapperRejectsInvalidIdentitiesBeforeMappingMasksOrLayers(kind: InvalidTree) throws {
        let response = try response(root: invalidTree(kind))
        #expect(throws: XomoFigmaNodeImportError.invalidResponse) {
            try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:3")
        }
    }

    @Test func validMaskedSiblingsKeepTheirSourceOrderAndMaskFrames() throws {
        var mask = node("2:0")
        mask["isMask"] = true
        let root = node("1:3", type: "FRAME", children: [mask, node("2:1"), node("2:2")])
        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response(root: root), requestedNodeID: "1:3")
        #expect(plan.items.map(\.sourceID) == ["1:3", "2:0", "2:1", "2:2"])
        #expect(plan.items[2].siblingMaskFrame != nil)
        #expect(plan.items[3].siblingMaskFrame == plan.items[2].siblingMaskFrame)
        let result = XomoFigmaNodeMaterializer.materialize(plan: plan, canvasSize: CGSize(width: 100, height: 100))
        #expect(result.layers.count == 4)
        #expect(result.selectedLayerID != nil)
    }

    @Test func malformedUnselectedEnvelopesDoNotRejectTheRequestedTree() throws {
        var response = try response(root: node("1:3"))
        let unrelated = try self.response(root: invalidTree(.siblings))
        response.nodes["9:9"] = unrelated.nodes["1:3"]
        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:3")
        #expect(plan.items.map(\.sourceID) == ["1:3"])
    }

    @Test func existingNodeLimitIncludesRootAndAcceptsExactBoundary() throws {
        let limit = XomoFigmaNodeImportMapper.maximumNodeCount
        let children = (0..<limit - 1).map { node("2:\($0)") }
        let valid = try response(root: node("1:3", type: "FRAME", children: children))
        let plan = try XomoFigmaNodeImportMapper.makePlan(response: valid, requestedNodeID: "1:3")
        #expect(plan.items.count == limit)
        let tooLarge = try response(root: node("1:3", type: "FRAME", children: children + [node("3:0")]))
        #expect(throws: XomoFigmaNodeImportError.nodeLimitExceeded) {
            try XomoFigmaNodeImportMapper.makePlan(response: tooLarge, requestedNodeID: "1:3")
        }
    }

    @Test(arguments: ["duplicate", "blank", "tooMany"])
    func materializerSafelyRejectsManuallyConstructedInvalidPlans(invalidity: String) throws {
        var plan = try validPlan()
        switch invalidity {
        case "duplicate": plan.items.append(plan.items[0])
        case "blank": plan.items[0].sourceID = " \t\n"
        default:
            let item = plan.items[0]
            plan.items = (0...XomoFigmaNodeImportMapper.maximumNodeCount).map { index in
                var copy = item
                copy.sourceID = "2:\(index)"
                return copy
            }
        }
        let result = XomoFigmaNodeMaterializer.materialize(plan: plan, canvasSize: CGSize(width: 100, height: 100))
        #expect(result.layers.isEmpty)
        #expect(result.slices.isEmpty)
        #expect(result.selectedLayerID == nil)
        #expect(result.importedCount == 0)
        #expect(result.omittedCount == plan.items.count)
    }

    @Test func rejectedPlanPreservesDocumentRedoAndSelectionContext() throws {
        let model = ImageEditorViewModel(sourceName: "fixture.png", image: .transparent(size: CGSize(width: 100, height: 100))) { _ in }
        var plan = try validPlan()
        #expect(model.importFigmaNodePlan(plan))
        model.undo()
        model.document.selection = .rectangle(CGRect(x: 1, y: 2, width: 8, height: 9))
        model.toggleQuickMaskMode()
        let hotspot = ImageEditorHotspot(name: "Existing", frame: CGRect(x: 0, y: 0, width: 10, height: 10), url: "https://example.com")
        model.document.hotspots = [hotspot]
        model.selectedHotspotID = hotspot.id
        let before = try model.projectData()
        let undoCount = model.undoStack.count
        let redoCount = model.redoStack.count
        plan.items.append(plan.items[0])

        #expect(!model.importFigmaNodePlan(plan))
        #expect(try model.projectData() == before)
        #expect(model.undoStack.count == undoCount)
        #expect(model.redoStack.count == redoCount)
        #expect(model.isQuickMaskMode)
        #expect(model.selectedHotspotID == hotspot.id)
        #expect(model.statusText == L10n.text(XomoFigmaNodeImportError.invalidResponse.localizationKey))
    }

    @Test func clientRejectsDuplicatesBeforeOptionalResourceRequests() async throws {
        let data = try JSONSerialization.data(withJSONObject: envelope(root: invalidTree(.maskedSiblings)))
        let io = IdentityValidationIO(data: data)
        let client = XomoFigmaNodeContentAPIClient(transport: io, imageAssetFetcher: io, variableFetcher: io)
        let preview = try XomoFigmaLinkParser.parse("https://www.figma.com/design/abc123DEF456/Fixture?node-id=1-3")
        let token = try XomoFigmaPersonalAccessToken(validating: "local-fixture-token")
        await #expect(throws: XomoFigmaNodeImportError.invalidResponse) {
            try await client.fetchPlan(for: preview, credential: token)
        }
        #expect(io.requests == 1)
        #expect(io.optionalRequests == 0)
    }

    private func validPlan() throws -> XomoFigmaNodeImportPlan {
        try XomoFigmaNodeImportMapper.makePlan(response: response(root: node("1:3")), requestedNodeID: "1:3")
    }

    private func invalidTree(_ kind: InvalidTree) -> [String: Any] {
        switch kind {
        case .siblings: node("1:3", type: "FRAME", children: [node("2:1"), node("2:1")])
        case .ancestor: node("1:3", type: "FRAME", children: [node("1:3")])
        case .separateBranches:
            node("1:3", type: "FRAME", children: [
                node("2:1", type: "FRAME", children: [node("3:1")]),
                node("2:2", type: "FRAME", children: [node("3:1")])
            ])
        case .maskedSiblings:
            maskedDuplicateTree()
        case .emptyRoot: node("")
        case .whitespaceChild: node("1:3", type: "FRAME", children: [node(" \t\n")])
        }
    }

    private func maskedDuplicateTree() -> [String: Any] {
        var mask = node("2:0")
        mask["isMask"] = true
        var child = node("2:1")
        child["fills"] = [["type": "IMAGE", "imageRef": "fixture-image", "scaleMode": "FILL"]]
        child["boundVariables"] = ["fills": [["type": "VARIABLE_ALIAS", "id": "VariableID:fill"]]]
        return node("1:3", type: "FRAME", children: [mask, child, child])
    }

    private func node(_ id: String, type: String = "RECTANGLE", children: [[String: Any]] = []) -> [String: Any] {
        ["id": id, "name": "Same display name", "type": type, "children": children,
         "absoluteBoundingBox": ["x": 0, "y": 0, "width": 10, "height": 10]]
    }

    private func envelope(root: [String: Any]) -> [String: Any] {
        ["name": "Fixture", "nodes": ["1:3": ["document": root]]]
    }

    private func response(root: [String: Any]) throws -> XomoFigmaNodeResponse {
        try JSONDecoder().decode(XomoFigmaNodeResponse.self, from: JSONSerialization.data(withJSONObject: envelope(root: root)))
    }
}

@MainActor
private final class IdentityValidationIO: XomoFigmaHTTPTransport, XomoFigmaVariableFetching, XomoFigmaImageAssetFetching {
    let data: Data
    private(set) var requests = 0
    private(set) var optionalRequests = 0

    init(data: Data) { self.data = data }
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests += 1
        let url = try #require(request.url)
        return (data, try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)))
    }
    func fetchVariables(fileKey: String, credential: XomoFigmaPersonalAccessToken) async throws -> XomoFigmaVariableStore {
        optionalRequests += 1
        return XomoFigmaVariableStore(variables: [:], collections: [:])
    }
    func fetchAssets(fileKey: String, references: Set<String>, credential: XomoFigmaPersonalAccessToken) async throws -> [String: XomoFigmaImageAsset] {
        optionalRequests += 1
        return [:]
    }
}
