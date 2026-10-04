import SwiftUI

enum ImageEditorLayerAdvancedControlsLayout {
    static let viewportHeight: CGFloat = 112
}

/// Keep the property viewport independent of the flexible, higher-priority list.
struct ImageEditorLayerAdvancedControlsViewport<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            content
        }
        .frame(height: ImageEditorLayerAdvancedControlsLayout.viewportHeight)
    }
}
