import Foundation
import Testing
@testable import musepic

@MainActor
struct XomoFigmaCancellationTests {
    @Test(arguments: CancellationPipelineIO.Stage.allCases, CancellationPipelineIO.Cancellation.allCases)
    func cancellationStopsRemainingPipelineStages(
        stage: CancellationPipelineIO.Stage,
        cancellation: CancellationPipelineIO.Cancellation
    ) async throws {
        let io = CancellationPipelineIO(stopAt: stage, cancellation: cancellation)
        let client = XomoFigmaNodeContentAPIClient(
            transport: io,
            imageAssetFetcher: XomoFigmaImageAssetAPIClient(transport: io),
            variableFetcher: io
        )
        let preview = try preview()
        let credential = try credential()
        // Cancel a child task, never the test runner's own task.
        let task = Task {
            do {
                _ = try await client.fetchPlan(for: preview, credential: credential)
                return false
            } catch is CancellationError {
                return true
            } catch {
                return false
            }
        }
        #expect(await task.value)
        #expect(io.stages == Array(CancellationPipelineIO.Stage.allCases.prefix(stage.rawValue + 1)))
    }

    @Test func alreadyCancelledClientsMakeNoRequests() async throws {
        let io = CancellationPipelineIO()
        let nodes = XomoFigmaNodeContentAPIClient(transport: io)
        let assets = XomoFigmaImageAssetAPIClient(transport: io)
        let preview = try preview()
        let credential = try credential()
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            var cancellations = 0
            do { _ = try await nodes.fetchPlan(for: preview, credential: credential) }
            catch is CancellationError { cancellations += 1 }
            catch { Issue.record("Cancelled node request returned a non-cancellation error") }
            do { _ = try await assets.fetchAssets(fileKey: preview.fileKey, references: ["a"], credential: credential) }
            catch is CancellationError { cancellations += 1 }
            catch { Issue.record("Cancelled asset request returned a non-cancellation error") }
            return cancellations
        }
        #expect(await task.value == 2)
        #expect(io.stages.isEmpty)
    }

    @Test func ordinaryOptionalFailuresStillAllowPartialImport() async throws {
        let io = CancellationPipelineIO(ordinaryFailures: true)
        let client = XomoFigmaNodeContentAPIClient(
            transport: io,
            imageAssetFetcher: XomoFigmaImageAssetAPIClient(transport: io),
            variableFetcher: io
        )
        let plan = try await client.fetchPlan(for: preview(), credential: credential())
        #expect(io.stages == CancellationPipelineIO.Stage.allCases)
        #expect(plan.requiredImageReferences == ["a", "b"])
        #expect(!plan.requiredVariableIDs.isEmpty)
        #expect(plan.imageAssets.isEmpty)
        #expect(!plan.items.isEmpty)
    }

    @Test func sheetOwnsAndCancelsBothTasksAtLifecycleBoundaries() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent("veilpic/XomoFigmaLinkImportSheet.swift"), encoding: .utf8)
        #expect(source.contains("metadataTask = Task {"))
        #expect(source.contains("nodeImportTask = Task {"))
        #expect(source.contains(".onDisappear {\n            cancelRequests()"))
        #expect(source.contains("metadataTask?.cancel()"))
        #expect(source.contains("nodeImportTask?.cancel()"))
        // Disappear, disconnect, typed link, pasted link, plus the declaration.
        #expect(source.components(separatedBy: "cancelRequests()").count == 6)
        #expect(source.contains("nodeImportTask = nil\n            nodeImportController.clear()"))
    }

    private func preview() throws -> XomoFigmaLinkPreview {
        try XomoFigmaLinkParser.parse("https://www.figma.com/design/abc123DEF456/Fixture?node-id=1-3")
    }

    private func credential() throws -> XomoFigmaPersonalAccessToken {
        try XomoFigmaPersonalAccessToken(validating: "local-fixture-token")
    }
}

@MainActor
final class CancellationPipelineIO: XomoFigmaHTTPTransport, XomoFigmaVariableFetching {
    enum Stage: Int, CaseIterable, Sendable { case nodes, variables, manifest, firstAsset, lastAsset }
    enum Cancellation: CaseIterable, Sendable { case cancelAndReturn, cancelAndFail, throwCancellation }
    enum FixtureError: Error { case offline }

    private(set) var stages: [Stage] = []
    let stopAt: Stage?
    let cancellation: Cancellation
    let ordinaryFailures: Bool

    init(stopAt: Stage? = nil, cancellation: Cancellation = .cancelAndReturn, ordinaryFailures: Bool = false) {
        self.stopAt = stopAt
        self.cancellation = cancellation
        self.ordinaryFailures = ordinaryFailures
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let url = try #require(request.url)
        let body: Data
        switch url.lastPathComponent {
        case "nodes":
            try record(.nodes)
            body = Self.nodeData
        case "images":
            try record(.manifest)
            body = Data(#"{"images":{"a":"https://assets.example.com/a.png","b":"https://assets.example.com/b.png"}}"#.utf8)
        case "a.png":
            try record(.firstAsset)
            if ordinaryFailures { throw FixtureError.offline }
            body = Data()
        case "b.png":
            try record(.lastAsset)
            body = Data()
        default:
            Issue.record("Unexpected fixture request")
            throw FixtureError.offline
        }
        return (body, try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)))
    }

    func fetchVariables(fileKey: String, credential: XomoFigmaPersonalAccessToken) async throws -> XomoFigmaVariableStore {
        try record(.variables)
        if ordinaryFailures { throw FixtureError.offline }
        return XomoFigmaVariableStore(variables: [:], collections: [:])
    }

    private func record(_ stage: Stage) throws {
        stages.append(stage)
        guard stage == stopAt else { return }
        switch cancellation {
        case .cancelAndReturn:
            withUnsafeCurrentTask { $0?.cancel() }
        case .cancelAndFail:
            withUnsafeCurrentTask { $0?.cancel() }
            throw FixtureError.offline
        case .throwCancellation:
            throw CancellationError()
        }
    }

    private static let nodeData = Data(#"""
    {"name":"Fixture","nodes":{"1:3":{"document":{
      "id":"1:3","name":"Frame","type":"FRAME",
      "absoluteBoundingBox":{"x":0,"y":0,"width":100,"height":100},
      "boundVariables":{"fills":[{"type":"VARIABLE_ALIAS","id":"VariableID:fill"}]},
      "children":[
        {"id":"2:1","name":"A","type":"RECTANGLE",
         "absoluteBoundingBox":{"x":0,"y":0,"width":10,"height":10},
         "fills":[{"type":"IMAGE","imageRef":"a","scaleMode":"FILL"}]},
        {"id":"2:2","name":"B","type":"RECTANGLE",
         "absoluteBoundingBox":{"x":20,"y":0,"width":10,"height":10},
         "fills":[{"type":"IMAGE","imageRef":"b","scaleMode":"FILL"}]}
      ]
    }}}}
    """#.utf8)
}
