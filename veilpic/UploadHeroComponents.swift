//
//  UploadHeroComponents.swift
//  veilpic
//
//  上传页「海盐晨蓝」插画式组件：海面拖拽 Hero、可点击插画卡片、药丸分段导航。
//  尽量用自定义可点击区域取代标准按钮，整体更轻盈耐看。
//

import SwiftUI

// MARK: - 海浪形状

/// 一条柔和的海浪，下方填充至底部，用于 Hero 拖拽区底部装饰。
struct WaveShape: Shape {
    /// 波峰高度
    var amplitude: CGFloat = 10
    /// 基线在高度中的占比（0~1，越大越靠下）
    var baseline: CGFloat = 0.62

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let y = h * baseline

        path.move(to: CGPoint(x: 0, y: y))
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: y),
            control1: CGPoint(x: w * 0.17, y: y - amplitude),
            control2: CGPoint(x: w * 0.33, y: y + amplitude)
        )
        path.addCurve(
            to: CGPoint(x: w, y: y - amplitude * 0.35),
            control1: CGPoint(x: w * 0.67, y: y - amplitude),
            control2: CGPoint(x: w * 0.85, y: y + amplitude)
        )
        path.addLine(to: CGPoint(x: w, y: h))
        path.addLine(to: CGPoint(x: 0, y: h))
        path.closeSubpath()
        return path
    }
}

// MARK: - 海面 Hero 拖拽区

/// 整块可点击 / 可拖拽的上传 Hero。点击触发传入的 action（默认选择图片）。
struct HeroDropZone: View {
    let isTargeted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottom) {
                // 底部双层海浪装饰（不拦截点击）
                ZStack(alignment: .bottom) {
                    WaveShape(amplitude: 10, baseline: 0.30)
                        .fill(AppTheme.waveLight)
                        .opacity(0.55)
                    WaveShape(amplitude: 8, baseline: 0.52)
                        .fill(AppTheme.waveDeep)
                        .opacity(0.6)
                }
                .frame(height: 66)
                .frame(maxWidth: .infinity, alignment: .bottom)
                .allowsHitTesting(false)

                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.accent.opacity(0.12))
                        Image(systemName: isTargeted ? "arrow.down.circle.fill" : "photo.badge.plus")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(AppTheme.accent)
                    }
                    .frame(width: 56, height: 56)

                    Text(isTargeted ? L10n.text("upload.hero.release") : L10n.text("upload.hero.title"))
                        .font(.headline)
                        .foregroundStyle(AppTheme.inkText)

                    Text(L10n.text("upload.hero.subtitle"))
                        .font(.caption)
                        .foregroundStyle(AppTheme.accent.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .background(isTargeted ? AppTheme.accent.opacity(0.12) : AppTheme.cardFill)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        isTargeted ? AppTheme.accent : AppTheme.accent.opacity(0.42),
                        style: StrokeStyle(lineWidth: 1.5, dash: [6])
                    )
            }
            .shadow(color: AppTheme.cardShadow, radius: 12, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 插画式上传卡片

enum UploadTileStyle {
    case filledAccent   // 海盐蓝实心渐变（主入口）
    case sandOutline    // 暖沙描边白瓷
    case accentOutline  // 海盐蓝描边白瓷
}

/// 一张可点击的上传动作卡片：左上图标、右上角标箭头、标题 + 副标题。
struct UploadActionTile: View {
    let icon: String
    let title: String
    let subtitle: String
    let style: UploadTileStyle
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(iconColor)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(iconColor.opacity(0.7))
                }

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(titleColor)
                    .padding(.top, 12)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(subtitleColor)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                if let border = borderColor {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(border, lineWidth: 1)
                }
            }
            .shadow(color: shadowColor, radius: 9, x: 0, y: 4)
        }
        .buttonStyle(PressableTileStyle())
    }

    // MARK: 配色

    @ViewBuilder
    private var background: some View {
        switch style {
        case .filledAccent:
            AppTheme.accentGradient
        case .sandOutline, .accentOutline:
            Color.white.opacity(0.66)
        }
    }

    private var iconColor: Color {
        switch style {
        case .filledAccent: return .white
        case .sandOutline: return AppTheme.sandIcon
        case .accentOutline: return AppTheme.accent
        }
    }

    private var titleColor: Color {
        switch style {
        case .filledAccent: return .white
        case .sandOutline: return AppTheme.sandText
        case .accentOutline: return AppTheme.inkText
        }
    }

    private var subtitleColor: Color {
        switch style {
        case .filledAccent: return Color.white.opacity(0.82)
        case .sandOutline: return AppTheme.sandIcon.opacity(0.85)
        case .accentOutline: return AppTheme.accent.opacity(0.8)
        }
    }

    private var borderColor: Color? {
        switch style {
        case .filledAccent: return nil
        case .sandOutline: return AppTheme.secondaryAccent.opacity(0.45)
        case .accentOutline: return AppTheme.accent.opacity(0.32)
        }
    }

    private var shadowColor: Color {
        switch style {
        case .filledAccent: return AppTheme.accent.opacity(0.32)
        case .sandOutline, .accentOutline: return AppTheme.cardShadow
        }
    }
}

/// 轻微的按下缩放反馈，让自定义卡片有"可按"的手感。
private struct PressableTileStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - 药丸分段导航

/// 浮在白瓷胶囊里的分段导航，取代系统 segmented Picker。
struct SectionPillNav: View {
    @Binding var selection: PanelSection

    var body: some View {
        HStack(spacing: 2) {
            ForEach(PanelSection.allCases) { section in
                pill(for: section)
            }
        }
        .padding(3)
        .background(Color.white.opacity(0.55))
        .clipShape(Capsule())
        .overlay {
            Capsule().strokeBorder(AppTheme.hairline, lineWidth: 1)
        }
    }

    private func pill(for section: PanelSection) -> some View {
        let isSelected = selection == section
        return Button {
            selection = section
        } label: {
            Label(section.title, systemImage: section.icon)
                .labelStyle(.titleAndIcon)
                .font(.caption.weight(isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? Color.white : AppTheme.accent.opacity(0.85))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background {
                    if isSelected {
                        Capsule().fill(AppTheme.accent)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.2), value: isSelected)
    }
}
