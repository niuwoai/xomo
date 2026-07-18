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
import SwiftUI

enum ImageEditorCanvasMiddleMousePanGeometry {
    static func delta(from previous: CGPoint, to current: CGPoint) -> CGSize {
        CGSize(width: current.x - previous.x, height: current.y - previous.y)
    }
}

enum ImageEditorObjectDragEventPolicy {
    static let activationDistance: CGFloat = 3

    static func shouldActivate(from start: CGPoint, to current: CGPoint) -> Bool {
        let deltaX = current.x - start.x
        let deltaY = current.y - start.y
        return hypot(deltaX, deltaY) >= activationDistance
    }

    static func shouldFinish(
        eventType: NSEvent.EventType,
        isObjectMoving: Bool
    ) -> Bool {
        return eventType == .leftMouseUp && isObjectMoving
    }
}

/// 覆盖在画布上的滚轮缩放捕获层。自身对鼠标点击完全透明（hitTest 返回 nil），
/// 不会影响 SwiftUI 的绘制、选择和拖拽平移。
struct ScrollWheelZoomView: NSViewRepresentable {
    /// 回调参数：本次缩放乘法系数、光标在视口内的坐标（左上原点 y-down）、视口尺寸。
    let onZoom: (_ factor: CGFloat, _ location: CGPoint, _ viewportSize: CGSize) -> Void
    /// macOS 13 的 SwiftUI onHover 不提供坐标；由透明 AppKit 承载层补发
    /// 鼠标位置，让移动工具可以准确区分空白画布和可移动对象。
    let onMouseMoved: (_ location: CGPoint) -> Void
    let onMiddleMousePanBegan: () -> Void
    let onMiddleMousePanChanged: (_ delta: CGSize) -> Void
    let onMiddleMousePanEnded: () -> Void
    /// Mouse-down only selects and records a draggable component candidate.
    /// The actual transform transaction starts after a familiar small drag
    /// threshold, so an ordinary click stays cheap and responsive.
    let onObjectMoveCandidateBegan: (_ location: CGPoint, _ modifierFlags: NSEvent.ModifierFlags) -> Bool
    let onObjectMoveActivated: () -> Bool
    let onObjectMoveChanged: (_ translation: CGSize) -> Void
    let onObjectMoveEnded: () -> Void

    func makeNSView(context: Context) -> ScrollWheelZoomNSView {
        let view = ScrollWheelZoomNSView()
        view.onZoom = onZoom
        view.onMouseMoved = onMouseMoved
        view.onMiddleMousePanBegan = onMiddleMousePanBegan
        view.onMiddleMousePanChanged = onMiddleMousePanChanged
        view.onMiddleMousePanEnded = onMiddleMousePanEnded
        view.onObjectMoveCandidateBegan = onObjectMoveCandidateBegan
        view.onObjectMoveActivated = onObjectMoveActivated
        view.onObjectMoveChanged = onObjectMoveChanged
        view.onObjectMoveEnded = onObjectMoveEnded
        return view
    }

    func updateNSView(_ nsView: ScrollWheelZoomNSView, context: Context) {
        nsView.onZoom = onZoom
        nsView.onMouseMoved = onMouseMoved
        nsView.onMiddleMousePanBegan = onMiddleMousePanBegan
        nsView.onMiddleMousePanChanged = onMiddleMousePanChanged
        nsView.onMiddleMousePanEnded = onMiddleMousePanEnded
        nsView.onObjectMoveCandidateBegan = onObjectMoveCandidateBegan
        nsView.onObjectMoveActivated = onObjectMoveActivated
        nsView.onObjectMoveChanged = onObjectMoveChanged
        nsView.onObjectMoveEnded = onObjectMoveEnded
    }

    static func dismantleNSView(_ nsView: ScrollWheelZoomNSView, coordinator: ()) {
        nsView.teardownMonitor()
    }
}

final class ScrollWheelZoomNSView: NSView {
    var onZoom: ((CGFloat, CGPoint, CGSize) -> Void)?
    var onMouseMoved: ((CGPoint) -> Void)?
    var onMiddleMousePanBegan: (() -> Void)?
    var onMiddleMousePanChanged: ((CGSize) -> Void)?
    var onMiddleMousePanEnded: (() -> Void)?
    var onObjectMoveCandidateBegan: ((_ location: CGPoint, _ modifierFlags: NSEvent.ModifierFlags) -> Bool)?
    var onObjectMoveActivated: (() -> Bool)?
    var onObjectMoveChanged: ((_ translation: CGSize) -> Void)?
    var onObjectMoveEnded: (() -> Void)?
    private var monitor: Any?
    private var middleMouseMonitor: Any?
    private var mouseMovedMonitor: Any?
    private var leftMouseMonitor: Any?
    private var isMiddleMousePanning = false
    private var lastMiddleMousePoint: CGPoint?
    private var isObjectMoving = false
    private var hasObjectMoveCandidate = false
    private var objectMoveStartPoint: CGPoint?

    // 采用左上原点，坐标系与 SwiftUI 画布对齐，锚点不会上下翻转。
    override var isFlipped: Bool { true }

    // 对所有命中测试透明，滚轮之外的一切鼠标事件都穿透给下方 SwiftUI 视图。
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            installMonitor()
        } else {
            teardownMonitor()
        }
    }

    private func installMonitor() {
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
        if leftMouseMonitor == nil {
            leftMouseMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
            ) { [weak self] event in
                guard let self else { return event }
                guard self.handleObjectMove(event) else { return event }
                return nil
            }
        }
    }

    func teardownMonitor() {
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
        if let leftMouseMonitor {
            NSEvent.removeMonitor(leftMouseMonitor)
        }
        leftMouseMonitor = nil
        if isObjectMoving {
            onObjectMoveEnded?()
        }
        isObjectMoving = false
        hasObjectMoveCandidate = false
        objectMoveStartPoint = nil
        if isMiddleMousePanning {
            onMiddleMousePanEnded?()
        }
        isMiddleMousePanning = false
        lastMiddleMousePoint = nil
    }

    deinit {
        teardownMonitor()
    }

    private func handleMouseMoved(_ event: NSEvent) {
        guard let window, event.window === window else { return }
        let location = convert(event.locationInWindow, from: nil)
        guard bounds.contains(location) else { return }
        onMouseMoved?(location)
    }

    /// The canvas is also a drop destination on macOS 13. A local left-button
    /// monitor gives already-selected Xomo objects a deterministic drag path
    /// without changing the event stream for pixels, selections, or imports.
    private func handleObjectMove(_ event: NSEvent) -> Bool {
        guard let window, event.buttonNumber == 0 else { return false }

        switch event.type {
        case .leftMouseDown:
            guard event.window === window else { return false }
            let location = convert(event.locationInWindow, from: nil)
            guard bounds.contains(location), !hasObjectMoveCandidate, !isObjectMoving else { return false }
            let flags = event.modifierFlags.intersection([.command, .option, .shift, .control])
            guard onObjectMoveCandidateBegan?(location, flags) == true else { return false }
            hasObjectMoveCandidate = true
            objectMoveStartPoint = location
            return true
        case .leftMouseDragged:
            guard event.window === window else { return false }
            let location = convert(event.locationInWindow, from: nil)
            guard hasObjectMoveCandidate, let objectMoveStartPoint else { return false }
            if !isObjectMoving {
                guard ImageEditorObjectDragEventPolicy.shouldActivate(
                    from: objectMoveStartPoint,
                    to: location
                ) else { return true }
                guard onObjectMoveActivated?() == true else {
                    hasObjectMoveCandidate = false
                    self.objectMoveStartPoint = nil
                    return true
                }
                isObjectMoving = true
            }
            onObjectMoveChanged?(CGSize(
                width: location.x - objectMoveStartPoint.x,
                height: location.y - objectMoveStartPoint.y
            ))
            return true
        case .leftMouseUp:
            // A local monitor may still receive the release after the pointer
            // has crossed the canvas/window edge. Always close the transaction
            // once a drag has started, otherwise the next click is swallowed
            // and the closed-hand cursor can remain stuck indefinitely.
            guard hasObjectMoveCandidate || isObjectMoving else { return false }
            if ImageEditorObjectDragEventPolicy.shouldFinish(
                eventType: event.type,
                isObjectMoving: isObjectMoving
            ) {
                onObjectMoveEnded?()
            }
            isObjectMoving = false
            hasObjectMoveCandidate = false
            objectMoveStartPoint = nil
            return true
        default:
            return false
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
    private func handleMiddleMousePan(_ event: NSEvent) -> Bool {
        guard let window, event.window === window, event.buttonNumber == 2 else { return false }

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
        case .otherMouseUp:
            guard isMiddleMousePanning else { return false }
            onMiddleMousePanEnded?()
            isMiddleMousePanning = false
            lastMiddleMousePoint = nil
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
