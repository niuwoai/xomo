import CoreGraphics
import Testing
@testable import musepic

struct ImageEditorTransformHUDTests {
    @Test func moveReadoutIncludesRoundedPositionAndLiveSize() {
        let text = ImageEditorTransformHUD.displayText(
            frame: CGRect(x: 12.04, y: 23.96, width: 120.25, height: 43.84),
            mode: .move
        )

        #expect(text == "X 12  Y 24  ·  120.3 × 43.8")
    }

    @Test func resizeReadoutOnlyShowsDimensions() {
        let text = ImageEditorTransformHUD.displayText(
            frame: CGRect(x: 90, y: 80, width: 164, height: 48),
            mode: .resize
        )

        #expect(text == "164 × 48")
        #expect(ImageEditorTransformHUD.badgeSize(for: text).width >= 88)
    }

    @Test func readoutStaysBelowSelectionWhenViewportHasRoom() {
        let badgeSize = CGSize(width: 150, height: 24)
        let center = ImageEditorTransformHUD.badgeCenter(
            selectionRect: CGRect(x: 100, y: 80, width: 160, height: 48),
            viewportSize: CGSize(width: 600, height: 400),
            badgeSize: badgeSize
        )

        #expect(center.x == 180)
        #expect(center.y > 128)
    }

    @Test func readoutFlipsAboveSelectionNearViewportBottomAndClampsHorizontally() {
        let badgeSize = CGSize(width: 150, height: 24)
        let center = ImageEditorTransformHUD.badgeCenter(
            selectionRect: CGRect(x: -20, y: 350, width: 80, height: 40),
            viewportSize: CGSize(width: 600, height: 400),
            badgeSize: badgeSize
        )

        #expect(center.x == 81)
        #expect(center.y < 350)
    }
}
