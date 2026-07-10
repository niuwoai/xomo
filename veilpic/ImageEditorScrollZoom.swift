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

/// 覆盖在画布上的滚轮缩放捕获层。自身对鼠标点击完全透明（hitTest 返回 nil），
/// 不会影响 SwiftUI 的绘制、选择和拖拽平移。
struct ScrollWheelZoomView: NSViewRepresentable {
    /// 回调参数：本次缩放乘法系数、光标在视口内的坐标（左上原点 y-down）、视口尺寸。
    let onZoom: (_ factor: CGFloat, _ location: CGPoint, _ viewportSize: CGSize) -> Void

    func makeNSView(context: Context) -> ScrollWheelZoomNSView {
        let view = ScrollWheelZoomNSView()
        view.onZoom = onZoom
        return view
    }

    func updateNSView(_ nsView: ScrollWheelZoomNSView, context: Context) {
        nsView.onZoom = onZoom
    }

    static func dismantleNSView(_ nsView: ScrollWheelZoomNSView, coordinator: ()) {
        nsView.teardownMonitor()
    }
}

final class ScrollWheelZoomNSView: NSView {
    var onZoom: ((CGFloat, CGPoint, CGSize) -> Void)?
    private var monitor: Any?

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
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self else { return event }
            guard let handled = self.handleScroll(event), handled else { return event }
            return nil // 消费事件，避免继续冒泡触发页面滚动
        }
    }

    func teardownMonitor() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    deinit {
        teardownMonitor()
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

    /// 归一化不同输入源的滚动量：触控板（精确增量）与鼠标滚轮（离散行）。
    private func scrollAmount(from event: NSEvent) -> CGFloat {
        if event.hasPreciseScrollingDeltas {
            return event.scrollingDeltaY
        }
        // 鼠标滚轮一般每格 ±1，放大步幅以获得可用的缩放速度。
        return event.scrollingDeltaY * 6
    }
}
