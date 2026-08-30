//
//  ImageEditorScrollZoom.swift
//  veilpic
//
//  为图片编辑器画布提供 ⌘/⌥ + 鼠标滚轮的光标锚定缩放。
//  SwiftUI 没有原生 scrollWheel 修饰符，这里用一个透明的 AppKit 承载视图，
//  仅用于定位「编辑器窗口 + 画布视口」并把坐标系对齐到 SwiftUI 左上原点，
//  再用局部事件监听拦截滚轮事件，避免挡住 SwiftUI 的点击 / 拖拽绘制。
//

import AppKit
import Combine
import SwiftUI

enum ImageEditorCanvasMiddleMousePanGeometry {
    static func delta(from previous: CGPoint, to current: CGPoint) -> CGSize {
        CGSize(width: current.x - previous.x, height: current.y - previous.y)
    }
}

enum ImageEditorMiddleMousePanEventPolicy {
    struct ResetDecision: Equatable {
        let shouldEndPan: Bool
    }

    static func resetDecision(isPanning: Bool) -> ResetDecision {
        ResetDecision(shouldEndPan: isPanning)
    }
}

enum ImageEditorPrimaryPointerResetPolicy {
    struct Decision: Equatable {
        let shouldCancelActiveTransaction: Bool
        let shouldCancelRangeTool: Bool
        let shouldCancelPrimaryTool: Bool
        let shouldCancelLayerResize: Bool
    }

    static func decision(
        hasActiveTransaction: Bool,
        activeKind: ImageEditorPrimaryToolPointerCapture.Kind,
        isLayerResizing: Bool
    ) -> Decision {
        Decision(
            shouldCancelActiveTransaction: hasActiveTransaction,
            shouldCancelRangeTool: !hasActiveTransaction && activeKind == .rangeTool,
            shouldCancelPrimaryTool: !hasActiveTransaction && activeKind == .primaryTool,
            shouldCancelLayerResize: isLayerResizing
        )
    }
}

enum ImageEditorCanvasLifecycleInterruption: Equatable {
    case applicationDeactivated
    case windowDeactivated
    case bridgeDetached
}

enum ImageEditorObjectDragEventPolicy {
    static let activationDistance: CGFloat = 3

    enum CloneDragDecision: Equatable {
        case unavailable
        case pending
        case activate
    }

    struct ReleaseDecision: Equatable {
        let shouldFinishMove: Bool
        let shouldCommitClick: Bool
        let shouldConsumeEvent: Bool
    }

    struct ResetDecision: Equatable {
        let shouldCancelMove: Bool
    }

    static func shouldActivate(from start: CGPoint, to current: CGPoint) -> Bool {
        let deltaX = current.x - start.x
        let deltaY = current.y - start.y
        return hypot(deltaX, deltaY) >= activationDistance
    }

    static func resetDecision(isObjectMoving: Bool) -> ResetDecision {
        ResetDecision(shouldCancelMove: isObjectMoving)
    }

    static func allowsCandidate(
        modifierFlags: NSEvent.ModifierFlags,
        hasTransformTarget: Bool
    ) -> Bool {
        // Shift is the conventional axis constraint and may already be held
        // before mouse-down. Command, Option, and Control retain their deep
        // selection, duplication, and contextual meanings.
        let relevantFlags = modifierFlags.intersection([.command, .option, .control])
        return relevantFlags.isEmpty && !hasTransformTarget
    }

    static func allowsCloneDrag(modifierFlags: NSEvent.ModifierFlags) -> Bool {
        let relevantFlags = modifierFlags.intersection([.command, .option, .shift, .control])
        return relevantFlags == [.option] || relevantFlags == [.option, .shift]
    }

    static func cloneDragDecision(
        modifierFlags: NSEvent.ModifierFlags,
        from start: CGPoint,
        to current: CGPoint
    ) -> CloneDragDecision {
        guard allowsCloneDrag(modifierFlags: modifierFlags) else { return .unavailable }
        return shouldActivate(from: start, to: current) ? .activate : .pending
    }

    static func deepSelectionExtendsSelection(
        modifierFlags: NSEvent.ModifierFlags
    ) -> Bool? {
        let relevantFlags = modifierFlags.intersection([.command, .option, .shift, .control])
        if relevantFlags == [.command] { return false }
        if relevantFlags == [.command, .shift] { return true }
        return nil
    }

    static func releaseDecision(
        eventType: NSEvent.EventType,
        hasObjectMoveCandidate: Bool,
        isObjectMoving: Bool,
        isObjectMoveCaptureRejected: Bool = false
    ) -> ReleaseDecision {
        guard eventType == .leftMouseUp,
              hasObjectMoveCandidate || isObjectMoving else {
            return ReleaseDecision(
                shouldFinishMove: false,
                shouldCommitClick: false,
                shouldConsumeEvent: false
            )
        }

        // The local monitor owns the complete sequence once mouse-down hits a
        // movable object. Passing only the candidate mouse-up through creates
        // an unbalanced stream for SwiftUI; passing an active drag through lets
        // both gesture systems mutate the same transaction. Consume the paired
        // release even when the pointer never crosses the drag threshold.
        return ReleaseDecision(
            shouldFinishMove: isObjectMoving,
            shouldCommitClick: hasObjectMoveCandidate
                && !isObjectMoving
                && !isObjectMoveCaptureRejected,
            shouldConsumeEvent: true
        )
    }
}

enum ImageEditorMoveToolDoubleClickPolicy {
    static func shouldBeginDirectEditing(
        sidebarTab: XomoLeftSidebarTab,
        selectedTool: ImageEditorTool,
        clickCount: Int,
        modifierFlags: NSEvent.ModifierFlags
    ) -> Bool {
        let editingModifiers = modifierFlags.intersection([.command, .option, .shift, .control])
        return sidebarTab == .tools
            && selectedTool == .move
            && clickCount >= 2
            && editingModifiers.isEmpty
    }
}

enum ImageEditorPrimaryToolPointerCapture {
    enum Kind: Equatable {
        case none
        case primaryTool
        case rangeTool
    }

    static func shouldCapture(
        sidebarTab: XomoLeftSidebarTab,
        tool: ImageEditorTool,
        isCanvasTextEditing: Bool = false
    ) -> Bool {
        guard sidebarTab == .tools, !isCanvasTextEditing else { return false }
        return switch tool {
        case .brush, .pencil, .historyBrush, .eraser, .rectangle, .ellipse, .text:
            true
        default:
            false
        }
    }

    static func usesDirectCanvasHitTarget(
        sidebarTab: XomoLeftSidebarTab,
        tool: ImageEditorTool,
        isCanvasTextEditing: Bool = false
    ) -> Bool {
        captureKind(
            sidebarTab: sidebarTab,
            tool: tool,
            isCanvasTextEditing: isCanvasTextEditing
        ) != .none
    }

    static func captureKind(
        sidebarTab: XomoLeftSidebarTab,
        tool: ImageEditorTool,
        isCanvasTextEditing: Bool = false
    ) -> Kind {
        guard sidebarTab == .tools, !isCanvasTextEditing else { return .none }
        if shouldCapture(sidebarTab: sidebarTab, tool: tool) {
            return .primaryTool
        }
        if tool == .marquee || tool == .gradient {
            return .rangeTool
        }
        return .none
    }
}

struct ImageEditorPrimaryPointerSample {
    let location: CGPoint
    let pressure: CGFloat?
    let tilt: ImageEditorStylusTilt?
}

final class ImageEditorCanvasPointerCaptureState: ObservableObject {
    var activeKind: ImageEditorPrimaryToolPointerCapture.Kind = .none
    var activeTool: ImageEditorTool?
    var isRangeToolDragging = false
    var lastRangeToolPoint: CGPoint?
    var isPrimaryToolDragging = false
    var lastPrimaryToolPoint: CGPoint?
    var primaryToolSamples: [ImageEditorPrimaryPointerSample] = []
    var isLayerResizing = false
    var lastLayerResizePoint: CGPoint?

    func reset() {
        activeKind = .none
        activeTool = nil
        isRangeToolDragging = false
        lastRangeToolPoint = nil
        isPrimaryToolDragging = false
        lastPrimaryToolPoint = nil
        primaryToolSamples = []
        isLayerResizing = false
        lastLayerResizePoint = nil
    }
}

enum ImageEditorCanvasLayerChooserEventPolicy {
    static func shouldOpen(
        eventType: NSEvent.EventType,
        modifierFlags: NSEvent.ModifierFlags
    ) -> Bool {
        eventType == .rightMouseDown
            || (eventType == .leftMouseDown && modifierFlags.contains(.control))
    }
}

/// 覆盖在画布上的滚轮缩放捕获层。自身对鼠标点击完全透明（hitTest 返回 nil），
/// 不会影响 SwiftUI 的绘制、选择和拖拽平移。
struct ScrollWheelZoomView: NSViewRepresentable {
    let pointerCaptureState: ImageEditorCanvasPointerCaptureState
    let pointerCaptureKind: ImageEditorPrimaryToolPointerCapture.Kind
    let capturesPrimaryPointer: Bool
    let claimsKeyboardFocusOnPointerDown: Bool
    /// A physical mouse-down starts a fresh pointer generation. SwiftUI uses
    /// this boundary to release cancellation latches left behind when the
    /// matching mouse-up was swallowed by an app/window transition.
    let onCanvasPointerSequenceBegan: () -> Void
    /// Path editing remains a SwiftUI gesture, so the AppKit bridge forwards
    /// lifecycle interruptions even when it has no native pointer capture.
    let onCanvasLifecycleInterrupted: (ImageEditorCanvasLifecycleInterruption) -> Void
    /// 回调参数：本次缩放乘法系数、光标在视口内的坐标（左上原点 y-down）、视口尺寸。
    let onZoom: (_ factor: CGFloat, _ location: CGPoint, _ viewportSize: CGSize) -> Void
    /// macOS 13 的 SwiftUI onHover 不提供坐标；由透明 AppKit 承载层补发
    /// 鼠标位置，让移动工具可以准确区分空白画布和可移动对象。
    let onMouseMoved: (
        _ location: CGPoint,
        _ stylusInput: ImageEditorStylusEventSample
    ) -> Void
    let onStylusProximityChanged: (_ proximity: ImageEditorStylusProximity) -> Void
    let onMiddleMousePanBegan: () -> Void
    let onMiddleMousePanChanged: (_ delta: CGSize) -> Void
    let onMiddleMousePanEnded: () -> Void
    /// Marquee and gradient both require a balanced down/drag/up sequence.
    /// Capturing that sequence here avoids macOS 13's drop destination
    /// occasionally delivering SwiftUI's `onChanged` without `onEnded`.
    let onRangeToolDragBegan: (_ location: CGPoint) -> Bool
    let onRangeToolDragChanged: (_ location: CGPoint) -> Void
    let onRangeToolDragEnded: (_ location: CGPoint) -> Void
    let onRangeToolDragCancelled: () -> Void
    /// Brush, shape, and text tools also require a balanced pointer sequence.
    /// Keeping their primary gesture on the same AppKit event path prevents
    /// fast drags from losing SwiftUI's `onEnded` callback on macOS 13.
    let onPrimaryToolDragBegan: (_ location: CGPoint) -> Bool
    let onPrimaryToolDragChanged: (
        _ location: CGPoint,
        _ pressure: CGFloat?,
        _ tilt: ImageEditorStylusTilt?
    ) -> Void
    let onPrimaryToolDragEnded: (
        _ location: CGPoint,
        _ samples: [ImageEditorPrimaryPointerSample]
    ) -> Void
    let onPrimaryToolDragCancelled: () -> Void
    /// Transform handles need the same balanced AppKit sequence as canvas
    /// tools on macOS 13; SwiftUI's nested handle gesture can otherwise lose
    /// the drag to the simultaneous canvas/drop gesture.
    let onLayerResizeBegan: (_ location: CGPoint) -> Bool
    let onLayerResizeChanged: (_ location: CGPoint) -> Void
    let onLayerResizeEnded: (_ location: CGPoint) -> Void
    let onLayerResizeCancelled: () -> Void
    /// Mouse-down only records a draggable component candidate.
    /// The actual transform transaction starts after a familiar small drag
    /// threshold; mouse-up commits an ordinary click without first collapsing
    /// a Shift multi-selection.
    let onObjectMoveCandidateBegan: (
        _ location: CGPoint,
        _ modifierFlags: NSEvent.ModifierFlags,
        _ clickCount: Int
    ) -> Bool
    let onObjectMoveActivated: (_ location: CGPoint, _ modifierFlags: NSEvent.ModifierFlags) -> Bool
    let onObjectMoveClicked: (
        _ location: CGPoint,
        _ modifierFlags: NSEvent.ModifierFlags,
        _ clickCount: Int
    ) -> Void
    let onObjectMoveChanged: (_ translation: CGSize) -> Void
    let onObjectMoveEnded: () -> Void
    let onObjectMoveCancelled: () -> Void
    let onLayerChooserRequested: (_ location: CGPoint) -> [ImageEditorCanvasLayerChoice]
    let onLayerChooserSelected: (_ layerID: UUID) -> Void

    func makeNSView(context: Context) -> ScrollWheelZoomNSView {
        let view = ScrollWheelZoomNSView()
        view.pointerCaptureState = pointerCaptureState
        view.pointerCaptureKind = pointerCaptureKind
        view.capturesPrimaryPointer = capturesPrimaryPointer
        view.claimsKeyboardFocusOnPointerDown = claimsKeyboardFocusOnPointerDown
        view.onCanvasPointerSequenceBegan = onCanvasPointerSequenceBegan
        view.onCanvasLifecycleInterrupted = onCanvasLifecycleInterrupted
        view.onZoom = onZoom
        view.onMouseMoved = onMouseMoved
        view.onStylusProximityChanged = onStylusProximityChanged
        view.onMiddleMousePanBegan = onMiddleMousePanBegan
        view.onMiddleMousePanChanged = onMiddleMousePanChanged
        view.onMiddleMousePanEnded = onMiddleMousePanEnded
        view.onRangeToolDragBegan = onRangeToolDragBegan
        view.onRangeToolDragChanged = onRangeToolDragChanged
        view.onRangeToolDragEnded = onRangeToolDragEnded
        view.onRangeToolDragCancelled = onRangeToolDragCancelled
        view.onPrimaryToolDragBegan = onPrimaryToolDragBegan
        view.onPrimaryToolDragChanged = onPrimaryToolDragChanged
        view.onPrimaryToolDragEnded = onPrimaryToolDragEnded
        view.onPrimaryToolDragCancelled = onPrimaryToolDragCancelled
        view.onLayerResizeBegan = onLayerResizeBegan
        view.onLayerResizeChanged = onLayerResizeChanged
        view.onLayerResizeEnded = onLayerResizeEnded
        view.onLayerResizeCancelled = onLayerResizeCancelled
        view.onObjectMoveCandidateBegan = onObjectMoveCandidateBegan
        view.onObjectMoveActivated = onObjectMoveActivated
        view.onObjectMoveClicked = onObjectMoveClicked
        view.onObjectMoveChanged = onObjectMoveChanged
        view.onObjectMoveEnded = onObjectMoveEnded
        view.onObjectMoveCancelled = onObjectMoveCancelled
        view.onLayerChooserRequested = onLayerChooserRequested
        view.onLayerChooserSelected = onLayerChooserSelected
        view.markAsCurrentPointerHost()
        return view
    }

    func updateNSView(_ nsView: ScrollWheelZoomNSView, context: Context) {
        nsView.pointerCaptureState = pointerCaptureState
        nsView.pointerCaptureKind = pointerCaptureKind
        nsView.capturesPrimaryPointer = capturesPrimaryPointer
        nsView.claimsKeyboardFocusOnPointerDown = claimsKeyboardFocusOnPointerDown
        nsView.onCanvasPointerSequenceBegan = onCanvasPointerSequenceBegan
        nsView.onCanvasLifecycleInterrupted = onCanvasLifecycleInterrupted
        nsView.onZoom = onZoom
        nsView.onMouseMoved = onMouseMoved
        nsView.onStylusProximityChanged = onStylusProximityChanged
        nsView.onMiddleMousePanBegan = onMiddleMousePanBegan
        nsView.onMiddleMousePanChanged = onMiddleMousePanChanged
        nsView.onMiddleMousePanEnded = onMiddleMousePanEnded
        nsView.onRangeToolDragBegan = onRangeToolDragBegan
        nsView.onRangeToolDragChanged = onRangeToolDragChanged
        nsView.onRangeToolDragEnded = onRangeToolDragEnded
        nsView.onRangeToolDragCancelled = onRangeToolDragCancelled
        nsView.onPrimaryToolDragBegan = onPrimaryToolDragBegan
        nsView.onPrimaryToolDragChanged = onPrimaryToolDragChanged
        nsView.onPrimaryToolDragEnded = onPrimaryToolDragEnded
        nsView.onPrimaryToolDragCancelled = onPrimaryToolDragCancelled
        nsView.onLayerResizeBegan = onLayerResizeBegan
        nsView.onLayerResizeChanged = onLayerResizeChanged
        nsView.onLayerResizeEnded = onLayerResizeEnded
        nsView.onLayerResizeCancelled = onLayerResizeCancelled
        nsView.onObjectMoveCandidateBegan = onObjectMoveCandidateBegan
        nsView.onObjectMoveActivated = onObjectMoveActivated
        nsView.onObjectMoveClicked = onObjectMoveClicked
        nsView.onObjectMoveChanged = onObjectMoveChanged
        nsView.onObjectMoveEnded = onObjectMoveEnded
        nsView.onObjectMoveCancelled = onObjectMoveCancelled
        nsView.onLayerChooserRequested = onLayerChooserRequested
        nsView.onLayerChooserSelected = onLayerChooserSelected
        nsView.markAsCurrentPointerHost()
    }

    static func dismantleNSView(_ nsView: ScrollWheelZoomNSView, coordinator: ()) {
        nsView.teardownMonitor()
    }
}

final class ImageEditorCanvasPointerGestureRecognizer: NSGestureRecognizer {
    enum Phase: Equatable {
        case down
        case dragged
        case up
    }

    /// SwiftUI may replace the representable view after mouse-down (for
    /// example when a brush stroke updates editor state). Keep the handler
    /// captured at mouse-down alive until the matching mouse-up so the
    /// in-flight AppKit gesture cannot be stranded on a rebuilt view.
    private static var activePointerHandler: ((Phase, NSEvent) -> Void)?

    var onPointerEvent: ((Phase, NSEvent) -> Void)?

    override func mouseDown(with event: NSEvent) {
        Self.activePointerHandler = onPointerEvent
        state = .began
        Self.activePointerHandler?(.down, event)
    }

    override func mouseDragged(with event: NSEvent) {
        state = .changed
        Self.activePointerHandler?(.dragged, event)
    }

    override func mouseUp(with event: NSEvent) {
        Self.activePointerHandler?(.up, event)
        Self.activePointerHandler = nil
        state = .ended
    }
}

final class ImageEditorActiveCanvasPointerTransaction {
    let kind: ImageEditorPrimaryToolPointerCapture.Kind
    private weak var sourceWindow: NSWindow?
    let captureState: ImageEditorCanvasPointerCaptureState
    var lastPoint: CGPoint
    var lastWindowPoint: CGPoint
    var samples: [ImageEditorPrimaryPointerSample]
    let onRangeChanged: ((CGPoint) -> Void)?
    let onRangeEnded: ((CGPoint) -> Void)?
    let onPrimaryChanged: ((CGPoint, CGFloat?, ImageEditorStylusTilt?) -> Void)?
    let onPrimaryEnded: ((CGPoint, [ImageEditorPrimaryPointerSample]) -> Void)?
    let onCancelled: (() -> Void)?

    init(
        kind: ImageEditorPrimaryToolPointerCapture.Kind,
        window: NSWindow,
        captureState: ImageEditorCanvasPointerCaptureState,
        point: CGPoint,
        windowPoint: CGPoint,
        stylusInput: ImageEditorStylusEventSample,
        onRangeChanged: ((CGPoint) -> Void)? = nil,
        onRangeEnded: ((CGPoint) -> Void)? = nil,
        onPrimaryChanged: ((CGPoint, CGFloat?, ImageEditorStylusTilt?) -> Void)? = nil,
        onPrimaryEnded: ((CGPoint, [ImageEditorPrimaryPointerSample]) -> Void)? = nil,
        onCancelled: (() -> Void)? = nil
    ) {
        self.kind = kind
        sourceWindow = window
        self.captureState = captureState
        lastPoint = point
        lastWindowPoint = windowPoint
        samples = [
            ImageEditorPrimaryPointerSample(
                location: point,
                pressure: stylusInput.pressure,
                tilt: stylusInput.tilt
            )
        ]
        self.onRangeChanged = onRangeChanged
        self.onRangeEnded = onRangeEnded
        self.onPrimaryChanged = onPrimaryChanged
        self.onPrimaryEnded = onPrimaryEnded
        self.onCancelled = onCancelled
    }

    /// Window deltas keep the original canvas coordinates across rebuilt view hosts.
    /// Foreign or windowless events must never add drawing samples.
    func advanceLocation(for event: NSEvent) -> CGPoint? {
        guard let sourceWindow, event.window === sourceWindow else { return nil }
        let windowPoint = event.locationInWindow
        lastPoint = CGPoint(
            x: lastPoint.x + windowPoint.x - lastWindowPoint.x,
            y: lastPoint.y - (windowPoint.y - lastWindowPoint.y)
        )
        lastWindowPoint = windowPoint
        return lastPoint
    }
}

final class ScrollWheelZoomNSView: NSView {
    private static var activePointerTransaction: ImageEditorActiveCanvasPointerTransaction?
    private static weak var currentPointerHost: ScrollWheelZoomNSView?
    private static var canvasPointerMonitor: Any?
    private static var tabletProximityMonitor: Any?
    private static var stylusProximity: ImageEditorStylusProximity = .none

    var pointerCaptureState = ImageEditorCanvasPointerCaptureState()
    var pointerCaptureKind: ImageEditorPrimaryToolPointerCapture.Kind = .none
    var capturesPrimaryPointer = false
    var claimsKeyboardFocusOnPointerDown = true
    var onCanvasPointerSequenceBegan: (() -> Void)?
    var onCanvasLifecycleInterrupted: ((ImageEditorCanvasLifecycleInterruption) -> Void)?
    var onZoom: ((CGFloat, CGPoint, CGSize) -> Void)?
    var onMouseMoved: ((CGPoint, ImageEditorStylusEventSample) -> Void)?
    var onStylusProximityChanged: ((ImageEditorStylusProximity) -> Void)?
    var onMiddleMousePanBegan: (() -> Void)?
    var onMiddleMousePanChanged: ((CGSize) -> Void)?
    var onMiddleMousePanEnded: (() -> Void)?
    var onRangeToolDragBegan: ((_ location: CGPoint) -> Bool)?
    var onRangeToolDragChanged: ((_ location: CGPoint) -> Void)?
    var onRangeToolDragEnded: ((_ location: CGPoint) -> Void)?
    var onRangeToolDragCancelled: (() -> Void)?
    var onPrimaryToolDragBegan: ((_ location: CGPoint) -> Bool)?
    var onPrimaryToolDragChanged: ((
        _ location: CGPoint,
        _ pressure: CGFloat?,
        _ tilt: ImageEditorStylusTilt?
    ) -> Void)?
    var onPrimaryToolDragEnded: ((
        _ location: CGPoint,
        _ samples: [ImageEditorPrimaryPointerSample]
    ) -> Void)?
    var onPrimaryToolDragCancelled: (() -> Void)?
    var onLayerResizeBegan: ((_ location: CGPoint) -> Bool)?
    var onLayerResizeChanged: ((_ location: CGPoint) -> Void)?
    var onLayerResizeEnded: ((_ location: CGPoint) -> Void)?
    var onLayerResizeCancelled: (() -> Void)?
    var onObjectMoveCandidateBegan: ((
        _ location: CGPoint,
        _ modifierFlags: NSEvent.ModifierFlags,
        _ clickCount: Int
    ) -> Bool)?
    var onObjectMoveActivated: ((_ location: CGPoint, _ modifierFlags: NSEvent.ModifierFlags) -> Bool)?
    var onObjectMoveClicked: ((
        _ location: CGPoint,
        _ modifierFlags: NSEvent.ModifierFlags,
        _ clickCount: Int
    ) -> Void)?
    var onObjectMoveChanged: ((_ translation: CGSize) -> Void)?
    var onObjectMoveEnded: (() -> Void)?
    var onObjectMoveCancelled: (() -> Void)?
    var onLayerChooserRequested: ((CGPoint) -> [ImageEditorCanvasLayerChoice])?
    var onLayerChooserSelected: ((UUID) -> Void)?
    private var monitor: Any?
    private var middleMouseMonitor: Any?
    private var mouseMovedMonitor: Any?
    private var layerChooserMonitor: Any?
    private var appDeactivateObserver: Any?
    private var windowResignKeyObserver: Any?
    private var ownsCanvasLifecycle = false
    private var isMiddleMousePanning = false
    private var lastMiddleMousePoint: CGPoint?
    private var isObjectMoving = false
    private var isLayerResizing = false
    private var hasObjectMoveCandidate = false
    private var isObjectMoveCaptureRejected = false
    private var objectMoveStartPoint: CGPoint?
    private var objectMoveCandidateModifierFlags: NSEvent.ModifierFlags = []
    private var objectMoveCandidateClickCount = 1
    private var lastReportedStylusProximity: ImageEditorStylusProximity?
    private lazy var primaryPointerGestureRecognizer: ImageEditorCanvasPointerGestureRecognizer = {
        let recognizer = ImageEditorCanvasPointerGestureRecognizer()
        installPrimaryPointerHandler(on: recognizer)
        return recognizer
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addGestureRecognizer(primaryPointerGestureRecognizer)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        addGestureRecognizer(primaryPointerGestureRecognizer)
    }

    private func installPrimaryPointerHandler(
        on recognizer: ImageEditorCanvasPointerGestureRecognizer
    ) {
        recognizer.onPointerEvent = { phase, event in
            _ = self.handleCanvasPointerDrag(event, phase: phase)
            guard phase == .up else { return }
            recognizer.onPointerEvent = nil
            DispatchQueue.main.async { [weak self, weak recognizer] in
                guard let self, let recognizer else { return }
                self.installPrimaryPointerHandler(on: recognizer)
            }
        }
    }

    // 采用左上原点，坐标系与 SwiftUI 画布对齐，锚点不会上下翻转。
    override var isFlipped: Bool { true }

    // Drawing/range tools use an explicit AppKit tracking loop so SwiftUI's
    // surrounding drop host cannot take over after mouse-down. Move/component
    // modes remain transparent for transform handles and drop targets.
    override func hitTest(_ point: NSPoint) -> NSView? {
        capturesPrimaryPointer && bounds.contains(point) ? self : nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            markAsCurrentPointerHost()
            installMonitor()
        } else {
            teardownMonitor()
        }
    }

    func markAsCurrentPointerHost() {
        Self.currentPointerHost = self
        Self.installCanvasPointerMonitorIfNeeded()
        Self.installTabletProximityMonitorIfNeeded()
        reportStylusProximity(Self.stylusProximity)
    }

    private static func installCanvasPointerMonitorIfNeeded() {
        guard canvasPointerMonitor == nil else { return }
        canvasPointerMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
        ) { event in
            guard let host = currentPointerHost else { return event }
            guard host.handleCanvasPointerDrag(event) else { return event }
            return nil
        }
    }

    private static func installTabletProximityMonitorIfNeeded() {
        guard tabletProximityMonitor == nil else { return }
        tabletProximityMonitor = NSEvent.addLocalMonitorForEvents(
            matching: .tabletProximity
        ) { event in
            updateStylusProximity(from: event)
            return event
        }
    }

    private static func updateStylusProximity(from event: NSEvent) {
        guard event.type == .tabletProximity || event.subtype == .tabletProximity else {
            return
        }
        let nextState = ImageEditorStylusProximity.nextState(
            current: stylusProximity,
            device: ImageEditorStylusProximity.device(
                from: event.pointingDeviceType
            ),
            enteringProximity: event.isEnteringProximity
        )
        guard nextState != stylusProximity else { return }
        stylusProximity = nextState
        currentPointerHost?.reportStylusProximity(nextState)
    }

    private func reportStylusProximity(_ proximity: ImageEditorStylusProximity) {
        guard lastReportedStylusProximity != proximity else {
            return
        }
        lastReportedStylusProximity = proximity
        onStylusProximityChanged?(proximity)
    }

    private func installMonitor() {
        ownsCanvasLifecycle = true
        if monitor == nil {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self else { return event }
                guard let handled = self.handleScroll(event), handled else { return event }
                return nil // 消费事件，避免继续冒泡触发页面滚动
            }
        }
        if middleMouseMonitor == nil {
            middleMouseMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.otherMouseDown, .otherMouseDragged, .otherMouseUp]
            ) { [weak self] event in
                guard let self else { return event }
                guard self.handleMiddleMousePan(event) else { return event }
                return nil
            }
        }
        if mouseMovedMonitor == nil {
            mouseMovedMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
                self?.handleMouseMoved(event)
                return event
            }
        }
        if layerChooserMonitor == nil {
            layerChooserMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.rightMouseDown, .leftMouseDown]
            ) { [weak self] event in
                guard let self else { return event }
                return self.showLayerChooserIfNeeded(for: event) ? nil : event
            }
        }
        if appDeactivateObserver == nil {
            appDeactivateObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didResignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.interruptCanvasLifecycle(.applicationDeactivated)
            }
        }
        if windowResignKeyObserver == nil {
            windowResignKeyObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let self,
                      notification.object as? NSWindow === self.window else { return }
                self.interruptCanvasLifecycle(.windowDeactivated)
            }
        }
    }

    func teardownMonitor() {
        let shouldNotifyBridgeDetached = ownsCanvasLifecycle
        ownsCanvasLifecycle = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        if let middleMouseMonitor {
            NSEvent.removeMonitor(middleMouseMonitor)
        }
        middleMouseMonitor = nil
        if let mouseMovedMonitor {
            NSEvent.removeMonitor(mouseMovedMonitor)
        }
        mouseMovedMonitor = nil
        if let layerChooserMonitor {
            NSEvent.removeMonitor(layerChooserMonitor)
        }
        layerChooserMonitor = nil
        if let appDeactivateObserver {
            NotificationCenter.default.removeObserver(appDeactivateObserver)
        }
        appDeactivateObserver = nil
        if let windowResignKeyObserver {
            NotificationCenter.default.removeObserver(windowResignKeyObserver)
        }
        windowResignKeyObserver = nil
        let resetDecision = ImageEditorObjectDragEventPolicy.resetDecision(
            isObjectMoving: isObjectMoving
        )
        if resetDecision.shouldCancelMove {
            onObjectMoveCancelled?()
        }
        isObjectMoving = false
        hasObjectMoveCandidate = false
        isObjectMoveCaptureRejected = false
        objectMoveStartPoint = nil
        objectMoveCandidateModifierFlags = []
        objectMoveCandidateClickCount = 1
        cancelStaleMiddleMousePanCapture()
        cancelStalePrimaryPointerCapture()
        if shouldNotifyBridgeDetached {
            onCanvasLifecycleInterrupted?(.bridgeDetached)
        }
    }

    deinit {
        teardownMonitor()
    }

    private func handleMouseMoved(_ event: NSEvent) {
        Self.updateStylusProximity(from: event)
        guard let window, event.window === window else { return }
        let location = convert(event.locationInWindow, from: nil)
        guard bounds.contains(location) else { return }
        onMouseMoved?(location, ImageEditorStylusInput.sample(from: event))
    }

    private func showLayerChooserIfNeeded(for event: NSEvent) -> Bool {
        guard ImageEditorCanvasLayerChooserEventPolicy.shouldOpen(
                eventType: event.type,
                modifierFlags: event.modifierFlags
              ),
              let window,
              event.window === window,
              !isMiddleMousePanning,
              !isObjectMoving,
              Self.activePointerTransaction == nil
        else { return false }

        let location = convert(event.locationInWindow, from: nil)
        guard bounds.contains(location),
              let choices = onLayerChooserRequested?(location),
              !choices.isEmpty
        else { return false }

        let menu = NSMenu()
        for choice in choices {
            let item = NSMenuItem(
                title: choice.title,
                action: #selector(selectLayerChoice(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = choice.id.uuidString
            item.state = choice.isSelected ? .on : .off
            menu.addItem(item)
        }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
        return true
    }

    @objc private func selectLayerChoice(_ sender: NSMenuItem) {
        guard let rawLayerID = sender.representedObject as? String,
              let layerID = UUID(uuidString: rawLayerID)
        else { return }
        onLayerChooserSelected?(layerID)
    }

    /// The canvas is also a drop destination on macOS 13. Once a mouse-down
    /// begins a range tool or hits a movable Xomo object, this monitor owns
    /// that complete pointer sequence so SwiftUI's canvas gesture cannot race
    /// the document transaction. All unrelated events pass through untouched.
    func handleCanvasPointerDrag(
        _ event: NSEvent,
        phase explicitPhase: ImageEditorCanvasPointerGestureRecognizer.Phase? = nil
    ) -> Bool {
        if let explicitPhase,
           explicitPhase != .down,
           let transaction = Self.activePointerTransaction {
            let nextLocation = transaction.advanceLocation(for: event)
            if explicitPhase == .dragged, nextLocation == nil { return true }
            let location = nextLocation ?? transaction.lastPoint
            switch explicitPhase {
            case .dragged:
                transaction.lastPoint = location
                switch transaction.kind {
                case .rangeTool:
                    transaction.onRangeChanged?(location)
                case .primaryTool:
                    let stylusInput = ImageEditorStylusInput.sample(from: event)
                    transaction.samples.append(
                        ImageEditorPrimaryPointerSample(
                            location: location,
                            pressure: stylusInput.pressure,
                            tilt: stylusInput.tilt
                        )
                    )
                    transaction.onPrimaryChanged?(
                        location,
                        stylusInput.pressure,
                        stylusInput.tilt
                    )
                case .none:
                    break
                }
            case .up:
                Self.activePointerTransaction = nil
                defer { transaction.captureState.reset() }
                switch transaction.kind {
                case .rangeTool:
                    transaction.onRangeEnded?(location)
                case .primaryTool:
                    let stylusInput = ImageEditorStylusInput.sample(from: event)
                    transaction.samples.append(
                        ImageEditorPrimaryPointerSample(
                            location: location,
                            pressure: stylusInput.pressure,
                            tilt: stylusInput.tilt
                        )
                    )
                    transaction.onPrimaryEnded?(location, transaction.samples)
                case .none:
                    break
                }
            case .down:
                break
            }
            return true
        }

        guard let window = self.window else { return false }
        if explicitPhase == nil, event.buttonNumber != 0 {
            return false
        }
        let phase: ImageEditorCanvasPointerGestureRecognizer.Phase?
        if let explicitPhase {
            phase = explicitPhase
        } else {
            switch event.type {
            case .leftMouseDown:
                phase = .down
            case .leftMouseDragged:
                phase = .dragged
            case .leftMouseUp:
                phase = .up
            default:
                phase = nil
            }
        }

        switch phase {
        case .down:
            guard event.window === window else {
                return false
            }
            let location = convert(event.locationInWindow, from: nil)
            guard bounds.contains(location) else {
                return false
            }
            prepareForNewPrimaryPointerSequence()
            guard self.window === window else { return false }
            if claimsKeyboardFocusOnPointerDown {
                ImageEditorFilePanelKeyboardFocusRestorer.claimEditorResponder(in: window)
            }
            onCanvasPointerSequenceBegan?()
            // Remote desktops, accessibility clients and pointer warps can
            // deliver mouse-down at a new location without a preceding
            // mouseMoved event. Refresh the semantic pointer state before
            // capture arbitration so the first click already shows the
            // active tool cursor (or the component library's native arrow).
            onMouseMoved?(location, ImageEditorStylusInput.sample(from: event))
            let primaryAccepted = onPrimaryToolDragBegan?(location) == true
            if primaryAccepted {
                let stylusInput = ImageEditorStylusInput.sample(from: event)
                pointerCaptureState.activeKind = .primaryTool
                pointerCaptureState.lastPrimaryToolPoint = location
                pointerCaptureState.primaryToolSamples = [
                    ImageEditorPrimaryPointerSample(
                        location: location,
                        pressure: stylusInput.pressure,
                        tilt: stylusInput.tilt
                    )
                ]
                Self.activePointerTransaction = ImageEditorActiveCanvasPointerTransaction(
                        kind: .primaryTool,
                        window: window,
                        captureState: pointerCaptureState,
                        point: location,
                        windowPoint: event.locationInWindow,
                        stylusInput: stylusInput,
                        onPrimaryChanged: onPrimaryToolDragChanged,
                        onPrimaryEnded: onPrimaryToolDragEnded,
                        onCancelled: { [weak self] in
                            self?.pointerCaptureState.reset()
                            self?.onPrimaryToolDragCancelled?()
                        }
                    )
                return true
            }
            if onRangeToolDragBegan?(location) == true {
                pointerCaptureState.activeKind = .rangeTool
                pointerCaptureState.lastRangeToolPoint = location
                Self.activePointerTransaction = ImageEditorActiveCanvasPointerTransaction(
                        kind: .rangeTool,
                        window: window,
                        captureState: pointerCaptureState,
                        point: location,
                        windowPoint: event.locationInWindow,
                        stylusInput: ImageEditorStylusEventSample(
                            pressure: nil,
                            tilt: nil
                        ),
                        onRangeChanged: onRangeToolDragChanged,
                        onRangeEnded: onRangeToolDragEnded,
                        onCancelled: { [weak self] in
                            self?.pointerCaptureState.reset()
                            self?.onRangeToolDragCancelled?()
                        }
                    )
                return true
            }
            if onLayerResizeBegan?(location) == true {
                isLayerResizing = true
                pointerCaptureState.isLayerResizing = true
                pointerCaptureState.lastLayerResizePoint = location
                return true
            }
            let flags = event.modifierFlags.intersection([.command, .option, .shift, .control])
            guard onObjectMoveCandidateBegan?(location, flags, event.clickCount) == true else {
                return false
            }
            hasObjectMoveCandidate = true
            isObjectMoveCaptureRejected = false
            objectMoveStartPoint = location
            objectMoveCandidateModifierFlags = flags
            objectMoveCandidateClickCount = event.clickCount
            return true
        case .dragged:
            if let transaction = Self.activePointerTransaction {
                guard let location = transaction.advanceLocation(for: event) else { return true }
                switch transaction.kind {
                case .rangeTool:
                    transaction.onRangeChanged?(location)
                case .primaryTool:
                    let stylusInput = ImageEditorStylusInput.sample(from: event)
                    transaction.samples.append(
                        ImageEditorPrimaryPointerSample(
                            location: location,
                            pressure: stylusInput.pressure,
                            tilt: stylusInput.tilt
                        )
                    )
                    transaction.onPrimaryChanged?(
                        location,
                        stylusInput.pressure,
                        stylusInput.tilt
                    )
                case .none:
                    break
                }
                return true
            }
            if pointerCaptureState.activeKind == .rangeTool {
                guard event.window === window else { return true }
                let location = convert(event.locationInWindow, from: nil)
                pointerCaptureState.lastRangeToolPoint = location
                onRangeToolDragChanged?(location)
                return true
            }
            if pointerCaptureState.activeKind == .primaryTool {
                guard event.window === window else { return true }
                let location = convert(event.locationInWindow, from: nil)
                pointerCaptureState.lastPrimaryToolPoint = location
                let stylusInput = ImageEditorStylusInput.sample(from: event)
                pointerCaptureState.primaryToolSamples.append(
                    ImageEditorPrimaryPointerSample(
                        location: location,
                        pressure: stylusInput.pressure,
                        tilt: stylusInput.tilt
                    )
                )
                onPrimaryToolDragChanged?(
                    location,
                    stylusInput.pressure,
                    stylusInput.tilt
                )
                return true
            }
            if isLayerResizing || pointerCaptureState.isLayerResizing {
                guard event.window === window else { return true }
                let location = convert(event.locationInWindow, from: nil)
                pointerCaptureState.lastLayerResizePoint = location
                onLayerResizeChanged?(location)
                return true
            }
            guard event.window === window else { return hasObjectMoveCandidate }
            let location = convert(event.locationInWindow, from: nil)
            guard hasObjectMoveCandidate, let objectMoveStartPoint else { return false }
            if isObjectMoveCaptureRejected {
                return true
            }
            if !isObjectMoving {
                guard ImageEditorObjectDragEventPolicy.shouldActivate(
                    from: objectMoveStartPoint,
                    to: location
                ) else { return true }
                guard onObjectMoveActivated?(
                    objectMoveStartPoint,
                    objectMoveCandidateModifierFlags
                ) == true else {
                    // Mouse-down was already consumed. Keep ownership through
                    // mouse-up even if the model rejects activation, otherwise
                    // SwiftUI receives an orphaned release event.
                    isObjectMoveCaptureRejected = true
                    return true
                }
                isObjectMoving = true
            }
            onObjectMoveChanged?(CGSize(
                width: location.x - objectMoveStartPoint.x,
                height: location.y - objectMoveStartPoint.y
            ))
            return true
        case .up:
            if let transaction = Self.activePointerTransaction {
                Self.activePointerTransaction = nil
                let location = transaction.advanceLocation(for: event) ?? transaction.lastPoint
                defer { transaction.captureState.reset() }
                switch transaction.kind {
                case .rangeTool:
                    transaction.onRangeEnded?(location)
                case .primaryTool:
                    let stylusInput = ImageEditorStylusInput.sample(from: event)
                    transaction.samples.append(
                        ImageEditorPrimaryPointerSample(
                            location: location,
                            pressure: stylusInput.pressure,
                            tilt: stylusInput.tilt
                        )
                    )
                    transaction.onPrimaryEnded?(location, transaction.samples)
                case .none:
                    break
                }
                return true
            }
            if pointerCaptureState.activeKind == .rangeTool {
                let location: CGPoint
                if event.window === window {
                    location = convert(event.locationInWindow, from: nil)
                } else {
                    location = pointerCaptureState.lastRangeToolPoint ?? .zero
                }
                onRangeToolDragEnded?(location)
                pointerCaptureState.lastRangeToolPoint = nil
                pointerCaptureState.activeKind = .none
                return true
            }
            if pointerCaptureState.activeKind == .primaryTool {
                let location: CGPoint
                if event.window === window {
                    location = convert(event.locationInWindow, from: nil)
                } else {
                    location = pointerCaptureState.lastPrimaryToolPoint ?? .zero
                }
                let stylusInput = ImageEditorStylusInput.sample(from: event)
                pointerCaptureState.primaryToolSamples.append(
                    ImageEditorPrimaryPointerSample(
                        location: location,
                        pressure: stylusInput.pressure,
                        tilt: stylusInput.tilt
                    )
                )
                onPrimaryToolDragEnded?(
                    location,
                    pointerCaptureState.primaryToolSamples
                )
                pointerCaptureState.lastPrimaryToolPoint = nil
                pointerCaptureState.primaryToolSamples = []
                pointerCaptureState.activeKind = .none
                return true
            }
            if isLayerResizing || pointerCaptureState.isLayerResizing {
                let location = event.window === window
                    ? convert(event.locationInWindow, from: nil)
                    : pointerCaptureState.lastLayerResizePoint
                // Finish ownership before callbacks can detach or re-enter the host.
                isLayerResizing = false
                pointerCaptureState.isLayerResizing = false
                pointerCaptureState.lastLayerResizePoint = nil
                if let location {
                    onLayerResizeEnded?(location)
                } else {
                    onLayerResizeCancelled?()
                }
                return true
            }
            // A local monitor may still receive the release after the pointer
            // has crossed the canvas/window edge. Always close the transaction
            // once a drag has started, otherwise the next click is swallowed
            // and the closed-hand cursor can remain stuck indefinitely.
            guard hasObjectMoveCandidate || isObjectMoving else { return false }
            let releaseDecision = ImageEditorObjectDragEventPolicy.releaseDecision(
                eventType: event.type,
                hasObjectMoveCandidate: hasObjectMoveCandidate,
                isObjectMoving: isObjectMoving,
                isObjectMoveCaptureRejected: isObjectMoveCaptureRejected
            )
            if releaseDecision.shouldFinishMove {
                onObjectMoveEnded?()
            }
            if releaseDecision.shouldCommitClick,
               let objectMoveStartPoint {
                onObjectMoveClicked?(
                    objectMoveStartPoint,
                    objectMoveCandidateModifierFlags,
                    objectMoveCandidateClickCount
                )
            }
            isObjectMoving = false
            hasObjectMoveCandidate = false
            isObjectMoveCaptureRejected = false
            objectMoveStartPoint = nil
            objectMoveCandidateModifierFlags = []
            objectMoveCandidateClickCount = 1
            return releaseDecision.shouldConsumeEvent
        case .none:
            return false
        }
    }

    private func cancelStaleObjectMoveCapture() {
        let resetDecision = ImageEditorObjectDragEventPolicy.resetDecision(
            isObjectMoving: isObjectMoving
        )
        if resetDecision.shouldCancelMove {
            onObjectMoveCancelled?()
        }
        isObjectMoving = false
        hasObjectMoveCandidate = false
        isObjectMoveCaptureRejected = false
        objectMoveStartPoint = nil
        objectMoveCandidateModifierFlags = []
        objectMoveCandidateClickCount = 1
    }

    private func interruptCanvasLifecycle(
        _ interruption: ImageEditorCanvasLifecycleInterruption
    ) {
        cancelStaleObjectMoveCapture()
        cancelStaleMiddleMousePanCapture()
        cancelStalePrimaryPointerCapture()
        onCanvasLifecycleInterrupted?(interruption)
    }

    private func cancelStaleMiddleMousePanCapture() {
        let resetDecision = ImageEditorMiddleMousePanEventPolicy.resetDecision(
            isPanning: isMiddleMousePanning
        )
        // Clear ownership before callbacks, which can detach this view or re-enter.
        isMiddleMousePanning = false
        lastMiddleMousePoint = nil
        if resetDecision.shouldEndPan {
            onMiddleMousePanEnded?()
        }
    }

    private func prepareForNewPrimaryPointerSequence() {
        // A fresh accepted mouse-down supersedes a stroke whose mouse-up was lost,
        // including one owned by a different editor window.
        if let previous = Self.activePointerTransaction {
            Self.activePointerTransaction = nil
            previous.captureState.reset()
            previous.onCancelled?()
        }
        cancelStalePrimaryPointerCapture()
        if hasObjectMoveCandidate || isObjectMoving {
            cancelStaleObjectMoveCapture()
        }
    }

    private func cancelStalePrimaryPointerCapture() {
        let transaction = Self.activePointerTransaction.flatMap {
            $0.captureState === pointerCaptureState ? $0 : nil
        }
        let decision = ImageEditorPrimaryPointerResetPolicy.decision(
            hasActiveTransaction: transaction != nil,
            activeKind: pointerCaptureState.activeKind,
            isLayerResizing: isLayerResizing || pointerCaptureState.isLayerResizing
        )
        // Callbacks may detach the view and re-enter cancellation.
        isLayerResizing = false
        pointerCaptureState.reset()
        if decision.shouldCancelActiveTransaction, let transaction {
            Self.activePointerTransaction = nil
            transaction.onCancelled?()
        }
        if decision.shouldCancelRangeTool {
            onRangeToolDragCancelled?()
        }
        if decision.shouldCancelPrimaryTool {
            onPrimaryToolDragCancelled?()
        }
        if decision.shouldCancelLayerResize {
            onLayerResizeCancelled?()
        }
    }

    private static func continueActivePointerTransaction(
        phase: ImageEditorCanvasPointerGestureRecognizer.Phase,
        event: NSEvent
    ) {
        guard phase != .down,
              let transaction = activePointerTransaction
        else { return }
        let nextLocation = transaction.advanceLocation(for: event)
        if phase == .dragged, nextLocation == nil { return }
        let location = nextLocation ?? transaction.lastPoint

        switch phase {
        case .dragged:
            switch transaction.kind {
            case .rangeTool:
                transaction.onRangeChanged?(location)
            case .primaryTool:
                let stylusInput = ImageEditorStylusInput.sample(from: event)
                transaction.samples.append(
                    ImageEditorPrimaryPointerSample(
                        location: location,
                        pressure: stylusInput.pressure,
                        tilt: stylusInput.tilt
                    )
                )
                transaction.onPrimaryChanged?(
                    location,
                    stylusInput.pressure,
                    stylusInput.tilt
                )
            case .none:
                break
            }
        case .up:
            activePointerTransaction = nil
            defer { transaction.captureState.reset() }
            switch transaction.kind {
            case .rangeTool:
                transaction.onRangeEnded?(location)
            case .primaryTool:
                let stylusInput = ImageEditorStylusInput.sample(from: event)
                transaction.samples.append(
                    ImageEditorPrimaryPointerSample(
                        location: location,
                        pressure: stylusInput.pressure,
                        tilt: stylusInput.tilt
                    )
                )
                transaction.onPrimaryEnded?(location, transaction.samples)
            case .none:
                break
            }
        case .down:
            break
        }
    }

    /// 返回 true 表示已处理并应消费该滚轮事件。
    private func handleScroll(_ event: NSEvent) -> Bool? {
        // 1) 仅限承载本视图的编辑器窗口，避免主窗口 ⌘+滚轮误触发。
        guard let window, event.window === window else { return false }

        // 2) 必须按住 ⌘ 或 ⌥，普通滚轮保持原生滚动语义。
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command) || flags.contains(.option) else { return false }

        // 3) 光标必须落在画布视口内。locationInWindow 为左下原点，
        //    经 convert(from: nil) 转换到本 flipped 视图坐标即得到左上原点视口坐标。
        let location = convert(event.locationInWindow, from: nil)
        guard bounds.contains(location) else { return false }

        let delta = scrollAmount(from: event)
        guard delta != 0 else { return false }

        // 向上滚动放大、向下滚动缩小；指数映射保证任意缩放级别手感一致。
        let factor = exp(delta * 0.01)
        onZoom?(factor, location, bounds.size)
        return true
    }

    /// Middle-button dragging is a familiar canvas-navigation gesture in
    /// Photoshop, Sketch and many graphics tools. It never enters the
    /// document gesture arena, so pixels, selections and History stay intact.
    func handleMiddleMousePan(_ event: NSEvent) -> Bool {
        guard [.otherMouseDown, .otherMouseDragged, .otherMouseUp].contains(event.type),
              event.buttonNumber == 2 else { return false }

        // An owned gesture must finish even if its release no longer has our window.
        if event.type == .otherMouseUp {
            guard isMiddleMousePanning else { return false }
            cancelStaleMiddleMousePanCapture()
            return true
        }
        guard let window, event.window === window else {
            return isMiddleMousePanning && event.type == .otherMouseDragged
        }

        let location = convert(event.locationInWindow, from: nil)
        switch event.type {
        case .otherMouseDown:
            guard bounds.contains(location) else { return false }
            isMiddleMousePanning = true
            lastMiddleMousePoint = location
            onMiddleMousePanBegan?()
            return true
        case .otherMouseDragged:
            guard isMiddleMousePanning, let lastMiddleMousePoint else { return false }
            let delta = ImageEditorCanvasMiddleMousePanGeometry.delta(
                from: lastMiddleMousePoint,
                to: location
            )
            self.lastMiddleMousePoint = location
            if delta != .zero {
                onMiddleMousePanChanged?(delta)
            }
            return true
        default:
            return false
        }
    }

    /// 归一化不同输入源的滚动量：触控板（精确增量）与鼠标滚轮（离散行）。
    private func scrollAmount(from event: NSEvent) -> CGFloat {
        if event.hasPreciseScrollingDeltas {
            return event.scrollingDeltaY
        }
        // 鼠标滚轮一般每格 ±1，放大步幅以获得可用的缩放速度。
        return event.scrollingDeltaY * 6
    }
}
