import Foundation
#if !XOMO_STANDALONE_BLEND_IF_TESTS
import Testing
@testable import musepic
#endif

enum ImageEditorLayerBlendIfCompletionFixture {
    nonisolated static func results() -> [[String: Any]] {
        var results: [[String: Any]] = []
        for ending in ImageEditorLayerBlendIfEditKind.allCases {
            for active in ImageEditorLayerBlendIfEditKind.allCases {
                let result = ImageEditorLayerBlendIfCompletionOwnership.mayFinish(active: active, ending: ending)
                results.append(["active": active.rawValue, "ending": ending.rawValue,
                                "may_finish": result, "passed": result == (active == ending)])
            }
            let result = ImageEditorLayerBlendIfCompletionOwnership.mayFinish(active: nil, ending: ending)
            results.append(["active": "none", "ending": ending.rawValue,
                            "may_finish": result, "passed": !result])
        }
        return results
    }
}

#if XOMO_STANDALONE_BLEND_IF_TESTS
@main
struct ImageEditorLayerBlendIfCompletionStandaloneTests {
    static func main() throws {
        let cases = ImageEditorLayerBlendIfCompletionFixture.results()
        let passed = cases.allSatisfy { $0["passed"] as? Bool == true }
        let data = try JSONSerialization.data(withJSONObject: ["passed": passed, "cases": cases],
                                              options: [.prettyPrinted, .sortedKeys])
        print(String(decoding: data, as: UTF8.self))
        if !passed { exit(1) }
    }
}
#else
@Suite(.serialized)
struct ImageEditorLayerBlendIfCompletionOwnershipTests {
    @Test func onlyMatchingActivePropertyMayFinish() {
        for active in ImageEditorLayerBlendIfEditKind.allCases {
            for ending in ImageEditorLayerBlendIfEditKind.allCases {
                #expect(ImageEditorLayerBlendIfCompletionOwnership.mayFinish(active: active, ending: ending)
                        == (active == ending))
            }
        }
    }

    @Test func delayedCompletionAfterResetIsIgnored() {
        for ending in ImageEditorLayerBlendIfEditKind.allCases {
            #expect(!ImageEditorLayerBlendIfCompletionOwnership.mayFinish(active: nil, ending: ending))
        }
    }
}
#endif
