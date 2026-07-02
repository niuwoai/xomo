//
//  RegionScreenshotCapture.swift
//  veilpic
//
//  Created by Codex on 2026/6/30.
//

import AppKit
import SwiftUI

final class RegionScreenshotCapture: NSObject, NSWindowDelegate {
    static let shared = RegionScreenshotCapture()

    private var windows: [NSWindow] = []
    private var keyMonitor: Any?
    private var completion: ((NSImage?) -> Void)?
    private var isActive = false

    private override init() {
        super.init()
    }

    var isCapturing: Bool {
        isActive
    }

    func start(completion: @escaping (NSImage?) -> Void) {
        guard !isActive else {
            bringToFront()
            return
        }

        self.completion = completion
        isActive = true
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        createOverlayWindows()
        installKeyMonitor()
        bringToFront()
    }

    private func createOverlayWindows() {
        windows = NSScreen.screens.map { screen in
            let view = RegionCaptureOverlayView(
                screenFrame: screen.frame,
                onCapture: { [weak self] rect in
                    self?.capture(rect)
                },
                onCancel: { [weak self] in
                    self?.cancel()
                }
            )

            let panel = RegionCapturePanel(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.ignoresMouseEvents = false
            panel.hidesOnDeactivate = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.acceptsMouseMovedEvents = true
            panel.delegate = self
            panel.contentView = NSHostingView(rootView: view)
            panel.setFrame(screen.frame, display: true)
            return panel
        }
    }

    private func bringToFront() {
        windows.forEach { window in
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
    }

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.cancel()
                return nil
            }

            return event
        }
    }

    private func capture(_ globalRect: CGRect) {
        let normalized = globalRect.standardized
        guard normalized.width >= 8, normalized.height >= 8 else {
            cancel()
            return
        }

        let excluded = Set(windows.map(\.windowNumber))
        cleanupWindows()

        Task { [weak self] in
            let image = await ScreenshotCaptureCoordinator.shared.captureGlobalRect(
                normalized,
                excludingWindowNumbers: excluded
            )
            await MainActor.run {
                self?.finish(image)
            }
        }
    }

    private func cancel() {
        cleanupWindows()
        finish(nil)
    }

    private func cleanupWindows() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }

        windows.forEach { window in
            window.delegate = nil
            window.close()
        }
        windows = []
        isActive = false
        DockVisibilitySettings.shared.applyActivationPolicy()
    }

    private func finish(_ image: NSImage?) {
        let callback = completion
        completion = nil
        callback?(image)
    }

    func windowWillClose(_ notification: Notification) {
        guard isActive else { return }
        guard let closedWindow = notification.object as? NSWindow else { return }
        windows.removeAll { $0 === closedWindow }
        if windows.isEmpty {
            cancel()
        }
    }
}

private final class RegionCapturePanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }
}

private struct RegionCaptureOverlayView: View {
    let screenFrame: CGRect
    let onCapture: (CGRect) -> Void
    let onCancel: () -> Void

    @State private var selection: CGRect = .zero
    @State private var interaction: RegionSelectionInteraction = .idle

    var body: some View {
        ZStack {
            dimmingLayer
            selectionLayer
            instructionLayer
        }
        .frame(width: screenFrame.width, height: screenFrame.height)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in
                    handleDragChanged(value)
                }
                .onEnded { value in
                    handleDragEnded(value)
                }
        )
    }

    private var dimmingLayer: some View {
        Rectangle()
            .fill(Color.black.opacity(0.34))
            .overlay {
                if !selection.isEmpty {
                    Rectangle()
                        .frame(width: selection.width, height: selection.height)
                        .position(x: selection.midX, y: selection.midY)
                        .blendMode(.destinationOut)
                }
            }
            .compositingGroup()
    }

    @ViewBuilder
    private var selectionLayer: some View {
        if !selection.isEmpty {
            Rectangle()
                .strokeBorder(Color.white, lineWidth: 1.5)
                .background(Color.white.opacity(0.05))
                .frame(width: selection.width, height: selection.height)
                .position(x: selection.midX, y: selection.midY)

            resizeHandles

            sizeBadge
                .position(badgePosition)

            toolbar
                .position(toolbarPosition)
        }
    }

    private var instructionLayer: some View {
        VStack(spacing: 8) {
            Image(systemName: "selection.pin.in.out")
                .font(.system(size: 30, weight: .semibold))
            Text(L10n.text("screenshot.region.instruction.title"))
                .font(.headline)
            Text(L10n.text("screenshot.region.instruction.subtitle"))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.82))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.black.opacity(0.34))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .opacity(selection.isEmpty ? 1 : 0)
    }

    private var sizeBadge: some View {
        Text("\(Int(selection.width.rounded())) x \(Int(selection.height.rounded()))")
            .font(.caption.monospacedDigit().weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.black.opacity(0.54))
            .clipShape(Capsule())
    }

    private var resizeHandles: some View {
        ForEach(RegionResizeHandle.allCases) { handle in
            Circle()
                .fill(Color.white)
                .frame(width: handle.visualSize, height: handle.visualSize)
                .overlay {
                    Circle()
                        .strokeBorder(AppTheme.accent, lineWidth: 2)
                }
                .shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 1)
                .position(handle.position(in: selection))
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Button {
                onCancel()
            } label: {
                Label(L10n.text("button.cancel"), systemImage: "xmark")
            }
            .buttonStyle(.bordered)

            Button {
                onCapture(globalRect(fromLocalRect: selection))
            } label: {
                Label(L10n.text("button.capture"), systemImage: "camera.viewfinder")
            }
            .buttonStyle(.borderedProminent)
        }
        .controlSize(.small)
        .padding(8)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private var badgePosition: CGPoint {
        let x = min(max(selection.midX, 58), screenFrame.width - 58)
        let y = max(selection.minY - 18, 20)
        return CGPoint(x: x, y: y)
    }

    private var toolbarPosition: CGPoint {
        let x = min(max(selection.midX, 118), screenFrame.width - 118)
        let preferredY = selection.maxY + 30
        let y = preferredY < screenFrame.height - 22 ? preferredY : max(selection.minY - 38, 28)
        return CGPoint(x: x, y: y)
    }

    private func rect(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }

    private func handleDragChanged(_ value: DragGesture.Value) {
        if case .idle = interaction {
            interaction = interactionForStartLocation(value.startLocation)
        }

        switch interaction {
        case let .drawing(start):
            selection = constrained(rect(from: start, to: value.location))
        case let .moving(startSelection):
            selection = moved(startSelection, by: value.translation)
        case let .resizing(handle, startSelection):
            selection = resized(startSelection, handle: handle, translation: value.translation)
        case .idle:
            break
        }
    }

    private func handleDragEnded(_ value: DragGesture.Value) {
        handleDragChanged(value)
        if selection.width < 8 || selection.height < 8 {
            selection = .zero
        }
        interaction = .idle
    }

    private func interactionForStartLocation(_ point: CGPoint) -> RegionSelectionInteraction {
        guard !selection.isEmpty else {
            return .drawing(point)
        }

        if let handle = resizeHandle(at: point) {
            return .resizing(handle: handle, startSelection: selection)
        }

        if selection.contains(point) {
            return .moving(startSelection: selection)
        }

        return .drawing(point)
    }

    private func resizeHandle(at point: CGPoint) -> RegionResizeHandle? {
        let hitSize: CGFloat = 18
        return RegionResizeHandle.allCases.first { handle in
            let position = handle.position(in: selection)
            return abs(point.x - position.x) <= hitSize && abs(point.y - position.y) <= hitSize
        }
    }

    private func moved(_ startSelection: CGRect, by translation: CGSize) -> CGRect {
        let maxX = max(screenFrame.width - startSelection.width, 0)
        let maxY = max(screenFrame.height - startSelection.height, 0)
        let nextOrigin = CGPoint(
            x: (startSelection.minX + translation.width).clamped(to: 0...maxX),
            y: (startSelection.minY + translation.height).clamped(to: 0...maxY)
        )
        return CGRect(origin: nextOrigin, size: startSelection.size)
    }

    private func resized(_ startSelection: CGRect, handle: RegionResizeHandle, translation: CGSize) -> CGRect {
        var minX = startSelection.minX
        var maxX = startSelection.maxX
        var minY = startSelection.minY
        var maxY = startSelection.maxY

        if handle.movesLeft {
            minX += translation.width
        }
        if handle.movesRight {
            maxX += translation.width
        }
        if handle.movesTop {
            minY += translation.height
        }
        if handle.movesBottom {
            maxY += translation.height
        }

        let minimumSize: CGFloat = 8
        minX = minX.clamped(to: 0...screenFrame.width)
        maxX = maxX.clamped(to: 0...screenFrame.width)
        minY = minY.clamped(to: 0...screenFrame.height)
        maxY = maxY.clamped(to: 0...screenFrame.height)

        if maxX - minX < minimumSize {
            if handle.movesLeft {
                minX = max(maxX - minimumSize, 0)
            } else {
                maxX = min(minX + minimumSize, screenFrame.width)
            }
        }

        if maxY - minY < minimumSize {
            if handle.movesTop {
                minY = max(maxY - minimumSize, 0)
            } else {
                maxY = min(minY + minimumSize, screenFrame.height)
            }
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY).standardized
    }

    private func constrained(_ rect: CGRect) -> CGRect {
        let normalized = rect.standardized
        let minX = normalized.minX.clamped(to: 0...screenFrame.width)
        let maxX = normalized.maxX.clamped(to: 0...screenFrame.width)
        let minY = normalized.minY.clamped(to: 0...screenFrame.height)
        let maxY = normalized.maxY.clamped(to: 0...screenFrame.height)
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY).standardized
    }

    private func globalRect(fromLocalRect rect: CGRect) -> CGRect {
        CGRect(
            x: screenFrame.minX + rect.minX,
            y: screenFrame.maxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }
}

private enum RegionSelectionInteraction {
    case idle
    case drawing(CGPoint)
    case moving(startSelection: CGRect)
    case resizing(handle: RegionResizeHandle, startSelection: CGRect)
}

private enum RegionResizeHandle: String, CaseIterable, Identifiable {
    case topLeft
    case top
    case topRight
    case right
    case bottomRight
    case bottom
    case bottomLeft
    case left

    var id: String { rawValue }

    var visualSize: CGFloat {
        switch self {
        case .top, .right, .bottom, .left:
            10
        case .topLeft, .topRight, .bottomRight, .bottomLeft:
            12
        }
    }

    var movesLeft: Bool {
        self == .topLeft || self == .left || self == .bottomLeft
    }

    var movesRight: Bool {
        self == .topRight || self == .right || self == .bottomRight
    }

    var movesTop: Bool {
        self == .topLeft || self == .top || self == .topRight
    }

    var movesBottom: Bool {
        self == .bottomLeft || self == .bottom || self == .bottomRight
    }

    func position(in rect: CGRect) -> CGPoint {
        switch self {
        case .topLeft:
            CGPoint(x: rect.minX, y: rect.minY)
        case .top:
            CGPoint(x: rect.midX, y: rect.minY)
        case .topRight:
            CGPoint(x: rect.maxX, y: rect.minY)
        case .right:
            CGPoint(x: rect.maxX, y: rect.midY)
        case .bottomRight:
            CGPoint(x: rect.maxX, y: rect.maxY)
        case .bottom:
            CGPoint(x: rect.midX, y: rect.maxY)
        case .bottomLeft:
            CGPoint(x: rect.minX, y: rect.maxY)
        case .left:
            CGPoint(x: rect.minX, y: rect.midY)
        }
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
