import AppKit
import SwiftUI

struct ImageEditorSmartFilterMaskThumbnail: View {
    let image: NSImage
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
                .background(Color.black.opacity(0.24))
                .overlay {
                    Rectangle().stroke(
                        isEditing ? Color(nsColor: ImageEditorTheme.selected) : Color.white.opacity(0.55),
                        lineWidth: 1.4
                    )
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
