import AppKit
import SwiftUI

struct ImageEditorSmartFilterMaskThumbnail: View {
    let image: NSImage
    let isMaskEnabled: Bool
    let isEditing: Bool
    let accessibilityLabel: String
    let accessibilityValue: String
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.none)
                .scaledToFill()
                .frame(width: 24, height: 24)
                .clipped()
                .opacity(isMaskEnabled ? 1 : 0.45)
                .background(Color.black.opacity(0.24))
                .overlay {
                    Rectangle().stroke(
                        isEditing ? Color(nsColor: ImageEditorTheme.selected) : Color.white.opacity(0.55),
                        lineWidth: 1.4
                    )
                }
                .overlay {
                    if !isMaskEnabled {
                        Image(systemName: "slash")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.8), radius: 1)
                            .accessibilityHidden(true)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityIdentifier(accessibilityIdentifier)
        .help(L10n.text("imageEditor.action.smartFilterMaskThumbnailHelp"))
    }
}
