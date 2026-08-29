//
//  Theme.swift
//  veilpic
//
//  「海盐晨蓝」皮肤 —— 取自 musemail 皮肤管理同名配色：
//  浅蓝海盐底配暖沙点缀，干净轻盈。集中托管全部颜色与卡片样式，
//  避免在各视图里硬编码色值。
//

import AppKit
import SwiftUI

enum AppTheme {
    // MARK: - 主色

    /// 海盐蓝（主强调色）
    static let accent = Color(red: 0.17, green: 0.52, blue: 0.64)
    /// 暖沙橙（次强调色）
    static let secondaryAccent = Color(red: 0.86, green: 0.57, blue: 0.36)

    // MARK: - 背景

    /// 窗口背景：浅蓝海盐 → 暖沙 → 浅蓝的斜向渐变
    static let windowBackground = LinearGradient(
        colors: [
            Color(red: 0.91, green: 0.97, blue: 0.98),
            Color(red: 0.95, green: 0.96, blue: 0.90),
            Color(red: 0.86, green: 0.94, blue: 0.95)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - 卡片 / 控件填充

    /// 白瓷卡片填充（半透明，叠在渐变之上呈现轻盈质感）
    static let cardFill = Color.white.opacity(0.58)
    /// 控件填充（暖白）
    static let controlFill = Color(red: 0.98, green: 0.99, blue: 0.96).opacity(0.76)
    /// 选中态填充
    static let selectionFill = accent.opacity(0.16)
    /// 悬停态填充
    static let hoverFill = secondaryAccent.opacity(0.10)
    /// 发丝描边
    static let hairline = Color(red: 0.22, green: 0.46, blue: 0.52).opacity(0.17)
    /// 强调描边（用于选中卡片）
    static let accentHairline = accent.opacity(0.30)

    // MARK: - 上传页插画卡片专用

    /// 深海蓝文字（标题）
    static let inkText = Color(red: 0.08, green: 0.24, blue: 0.29)
    /// 暖沙深色文字
    static let sandText = Color(red: 0.48, green: 0.25, blue: 0.07)
    /// 暖沙图标色
    static let sandIcon = Color(red: 0.79, green: 0.46, blue: 0.18)
    /// 海浪（浅）
    static let waveLight = Color(red: 0.75, green: 0.90, blue: 0.93)
    /// 海浪（深）
    static let waveDeep = Color(red: 0.61, green: 0.84, blue: 0.89)
    /// 卡片柔和投影色
    static let cardShadow = Color(red: 0.18, green: 0.34, blue: 0.42).opacity(0.10)

    /// 海盐蓝斜向渐变（用于图标方块、实心卡片）
    static let accentGradient = LinearGradient(
        colors: [accent, Color(red: 0.12, green: 0.42, blue: 0.52)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

enum XomoCanvasRichLinkDropLoader {
    nonisolated private final class ProviderBox: @unchecked Sendable {
        let value: NSItemProvider

        init(_ value: NSItemProvider) {
            self.value = value
        }
    }

    nonisolated static func load(
        providers: [NSItemProvider],
        completion: @escaping @MainActor (Data?, Data?) -> Void
    ) -> Bool {
        guard providers.count == 1, let provider = providers.first else { return false }
        let htmlType = NSPasteboard.PasteboardType.html.rawValue
        let rtfType = NSPasteboard.PasteboardType.rtf.rawValue
        let typeIdentifiers = [htmlType, rtfType].filter {
            provider.hasItemConformingToTypeIdentifier($0)
        }
        guard !typeIdentifiers.isEmpty else { return false }
        loadNext(
            providerBox: ProviderBox(provider),
            typeIdentifiers: typeIdentifiers,
            completion: completion
        )
        return true
    }

    nonisolated private static func loadNext(
        providerBox: ProviderBox,
        typeIdentifiers: [String],
        index: Int = 0,
        htmlData: Data? = nil,
        rtfData: Data? = nil,
        completion: @escaping @MainActor (Data?, Data?) -> Void
    ) {
        guard index < typeIdentifiers.count else {
            Task { @MainActor in completion(htmlData, rtfData) }
            return
        }

        let typeIdentifier = typeIdentifiers[index]
        providerBox.value.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, _ in
            let htmlType = NSPasteboard.PasteboardType.html.rawValue
            let rtfType = NSPasteboard.PasteboardType.rtf.rawValue
            loadNext(
                providerBox: providerBox,
                typeIdentifiers: typeIdentifiers,
                index: index + 1,
                htmlData: typeIdentifier == htmlType ? data : htmlData,
                rtfData: typeIdentifier == rtfType ? data : rtfData,
                completion: completion
            )
        }
    }
}

// MARK: - 视图修饰器

extension View {
    @ViewBuilder
    func xomoFocusEffectDisabled() -> some View {
        if #available(macOS 14.0, *) {
            focusEffectDisabled()
        } else {
            self
        }
    }

    @ViewBuilder
    func xomoScrollContentBackgroundHidden() -> some View {
        if #available(macOS 13.0, *) {
            scrollContentBackground(.hidden)
        } else {
            self
        }
    }

    @ViewBuilder
    func xomoDraggable(_ payload: String) -> some View {
        if #available(macOS 13.0, *) {
            onDrag {
                NSItemProvider(object: payload as NSString)
            }
        } else {
            self
        }
    }

    @ViewBuilder
    func xomoDraggable<Preview: View>(
        _ payload: String,
        onDragBegan: @escaping () -> Void = {},
        @ViewBuilder preview: () -> Preview
    ) -> some View {
        if #available(macOS 13.0, *) {
            onDrag {
                onDragBegan()
                return NSItemProvider(object: payload as NSString)
            } preview: {
                preview()
            }
        } else {
            self
        }
    }

    @ViewBuilder
    func xomoCanvasPlatformInteractions(
        onDrop: @escaping ([String], CGPoint) -> Bool,
        onFileDrop: @escaping ([URL], CGPoint) -> Bool,
        onRichLinkDrop: @escaping (Data?, Data?, CGPoint) -> Bool,
        onMagnifyChanged: @escaping (CGFloat, CGPoint?) -> Void,
        onMagnifyEnded: @escaping () -> Void,
        onHoverChanged: @escaping (Bool, CGPoint?) -> Void
    ) -> some View {
        if #available(macOS 14.0, *) {
            dropDestination(for: String.self, action: onDrop)
                .dropDestination(for: URL.self, action: onFileDrop)
                .onDrop(of: [
                    NSPasteboard.PasteboardType.html.rawValue,
                    NSPasteboard.PasteboardType.rtf.rawValue
                ], isTargeted: nil) { providers, location in
                    XomoCanvasRichLinkDropLoader.load(providers: providers) { htmlData, rtfData in
                        _ = onRichLinkDrop(htmlData, rtfData, location)
                    }
                }
                .simultaneousGesture(
                    MagnifyGesture()
                        .onChanged { value in
                            onMagnifyChanged(value.magnification, value.startLocation)
                        }
                        .onEnded { _ in onMagnifyEnded() }
                )
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        onHoverChanged(true, location)
                    case .ended:
                        onHoverChanged(false, nil)
                    }
                }
        } else if #available(macOS 13.0, *) {
            dropDestination(for: String.self, action: onDrop)
                .dropDestination(for: URL.self, action: onFileDrop)
                .onDrop(of: [
                    NSPasteboard.PasteboardType.html.rawValue,
                    NSPasteboard.PasteboardType.rtf.rawValue
                ], isTargeted: nil) { providers, location in
                    XomoCanvasRichLinkDropLoader.load(providers: providers) { htmlData, rtfData in
                        _ = onRichLinkDrop(htmlData, rtfData, location)
                    }
                }
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in onMagnifyChanged(value, nil) }
                        .onEnded { _ in onMagnifyEnded() }
                )
                .onHover { isInside in onHoverChanged(isInside, nil) }
        } else {
            simultaneousGesture(
                MagnificationGesture()
                    .onChanged { value in onMagnifyChanged(value, nil) }
                    .onEnded { _ in onMagnifyEnded() }
            )
            .onHover { isInside in onHoverChanged(isInside, nil) }
        }
    }

    /// 给视图铺上「海盐晨蓝」窗口渐变背景，并锁定浅色配色。
    func themedWindowBackground() -> some View {
        self
            .background(AppTheme.windowBackground.ignoresSafeArea())
            .tint(AppTheme.accent)
            .preferredColorScheme(.light)
            .xomoFocusEffectDisabled() // 全局去掉焦点环，macOS 13 使用系统兼容降级
    }

    /// 白瓷卡片：半透明填充 + 发丝描边 + 轻柔投影。
    func themedCard(
        cornerRadius: CGFloat = 12,
        fill: Color = AppTheme.cardFill,
        border: Color = AppTheme.hairline,
        shadow: Bool = true
    ) -> some View {
        self
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(border, lineWidth: 1)
            }
            .shadow(
                color: shadow ? Color(red: 0.18, green: 0.34, blue: 0.42).opacity(0.10) : .clear,
                radius: shadow ? 10 : 0,
                x: 0,
                y: shadow ? 4 : 0
            )
    }
}

// MARK: - 原生窗口外观

enum WindowChrome {
    /// 让 NSWindow 与「海盐晨蓝」内容融为一体：标题栏透明、锁定浅色外观、
    /// 背景与渐变顶色一致，避免出现突兀的深色/系统灰标题区。
    static func applySeaSalt(to window: NSWindow) {
        window.appearance = NSAppearance(named: .aqua)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .visible
        window.backgroundColor = NSColor(
            calibratedRed: 0.91, green: 0.97, blue: 0.98, alpha: 1.0
        )
    }
}
