import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorStrokeCompletionTests {
    private typealias Fixture = ImageEditorNativePointerTestFixture

    @Test(arguments: [false, true])
    func commitKeepsNextStrokeToolAndSamples(explicitRoute: Bool) throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            let nextDown = try Fixture.event(.leftMouseDown, window: window, point: CGPoint(x: 80, y: 80))
            var begins = 0
            var ends = 0
            var tools: [ImageEditorTool?] = []
            host.onPrimaryToolDragBegan = { [weak host] _ in
                begins += 1
                host?.pointerCaptureState.activeTool = begins == 1 ? .brush : .eraser
                host?.pointerCaptureState.isPrimaryToolDragging = true
                return true
            }
            host.onPrimaryToolDragEnded = { [weak host] _, _ in
                ends += 1
                tools.append(host?.pointerCaptureState.activeTool)
                if ends == 1 {
                    #expect(host?.handleCanvasPointerDrag(nextDown, phase: explicitRoute ? .down : nil) == true)
                }
            }
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: window), phase: explicitRoute ? .down : nil))
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseUp, window: window), phase: explicitRoute ? .up : nil))
            #expect(host.pointerCaptureState.activeKind == .primaryTool)
            #expect(host.pointerCaptureState.activeTool == .eraser)
            #expect(host.pointerCaptureState.isPrimaryToolDragging)
            #expect(host.pointerCaptureState.primaryToolSamples.map(\.location) == [CGPoint(x: 80, y: 160)])
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseUp, window: nil), phase: explicitRoute ? .up : nil))
            #expect(tools == [.brush, .eraser])
            #expect(host.pointerCaptureState.activeKind == .none)
            #expect(host.pointerCaptureState.activeTool == nil)
        }
    }

    @Test func primaryCommitKeepsFollowingRangeCapture() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            let nextDown = try Fixture.event(.leftMouseDown, window: window, point: CGPoint(x: 90, y: 100))
            host.onPrimaryToolDragBegan = { _ in true }
            host.onPrimaryToolDragEnded = { [weak host] _, _ in
                host?.onPrimaryToolDragBegan = { _ in false }
                host?.onRangeToolDragBegan = { [weak host] _ in
                    host?.pointerCaptureState.activeTool = .marquee
                    host?.pointerCaptureState.isRangeToolDragging = true
                    return true
                }
                #expect(host?.handleCanvasPointerDrag(nextDown) == true)
            }
            var ended: CGPoint?
            host.onRangeToolDragEnded = { ended = $0 }
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: window)))
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseUp, window: window)))
            #expect(host.pointerCaptureState.activeKind == .rangeTool)
            #expect(host.pointerCaptureState.activeTool == .marquee)
            #expect(host.pointerCaptureState.isRangeToolDragging)
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseUp, window: nil)))
            #expect(ended == CGPoint(x: 90, y: 140))
        }
    }

    @Test func rangeCommitKeepsFollowingPrimaryCapture() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            let nextDown = try Fixture.event(.leftMouseDown, window: window)
            host.onRangeToolDragBegan = { _ in true }
            host.onRangeToolDragEnded = { [weak host] _ in
                host?.onPrimaryToolDragBegan = { [weak host] _ in
                    host?.pointerCaptureState.activeTool = .pencil
                    return true
                }
                #expect(host?.handleCanvasPointerDrag(nextDown, phase: .down) == true)
            }
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: window), phase: .down))
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseUp, window: window), phase: .up))
            #expect(host.pointerCaptureState.activeKind == .primaryTool)
            #expect(host.pointerCaptureState.activeTool == .pencil)
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseUp, window: nil)))
        }
    }

    @Test func strokeCommitDoesNotEraseNewResizeLastPoint() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            let nextDown = try Fixture.event(.leftMouseDown, window: window, point: CGPoint(x: 80, y: 80))
            host.onPrimaryToolDragBegan = { _ in true }
            host.onPrimaryToolDragEnded = { [weak host] _, _ in
                host?.onPrimaryToolDragBegan = { _ in false }
                host?.onLayerResizeBegan = { _ in true }
                #expect(host?.handleCanvasPointerDrag(nextDown) == true)
            }
            var ended: CGPoint?
            host.onLayerResizeEnded = { ended = $0 }
            host.onLayerResizeCancelled = { Issue.record("Old stroke erased new resize") }
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: window)))
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseUp, window: window)))
            #expect(host.pointerCaptureState.isLayerResizing)
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseUp, window: nil)))
            #expect(ended == CGPoint(x: 80, y: 160))
        }
    }

    @Test func recognizerReleasePreservesHandlerStartedByCommit() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            let recognizer = ImageEditorCanvasPointerGestureRecognizer()
            host.addGestureRecognizer(recognizer)
            let down = try Fixture.event(.leftMouseDown, window: window)
            let drag = try Fixture.event(.leftMouseDragged, window: window)
            let up = try Fixture.event(.leftMouseUp, window: window)
            var phases: [ImageEditorCanvasPointerGestureRecognizer.Phase] = []
            var ends = 0
            recognizer.onPointerEvent = { [weak recognizer] phase, _ in
                phases.append(phase)
                if phase == .up {
                    ends += 1
                    if ends == 1 { recognizer?.mouseDown(with: down) }
                }
            }
            recognizer.mouseDown(with: down)
            recognizer.mouseUp(with: up)
            recognizer.mouseDragged(with: drag)
            recognizer.mouseUp(with: up)
            #expect(phases == [.down, .up, .down, .dragged, .up])
        }
    }

    @Test func recognizerConsumesHandlerBeforeReentrantRelease() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            let recognizer = ImageEditorCanvasPointerGestureRecognizer()
            host.addGestureRecognizer(recognizer)
            let up = try Fixture.event(.leftMouseUp, window: window)
            var ends = 0
            recognizer.onPointerEvent = { [weak recognizer] phase, _ in
                guard phase == .up else { return }
                ends += 1
                if ends == 1 { recognizer?.mouseUp(with: up) }
            }
            recognizer.mouseDown(with: try Fixture.event(.leftMouseDown, window: window))
            recognizer.mouseUp(with: up)
            #expect(ends == 1)
        }
    }
}
