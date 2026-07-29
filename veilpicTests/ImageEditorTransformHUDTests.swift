import AppKit
import CoreGraphics
import Testing
@testable import musepic

struct ImageEditorTransformHUDTests {
    @Test func moveReadoutIncludesRoundedPositionAndCumulativeDelta() {
        let text = ImageEditorTransformHUD.displayText(
            frame: CGRect(x: 12.04, y: 23.96, width: 120.25, height: 43.84),
            mode: .move(delta: CGSize(width: 13.46, height: -7.54))
        )

        #expect(text == "X 12  Y 24  ·  ΔX 13.5  ΔY -7.5")
    }

    @Test func moveReadoutFallsBackToLiveSizeWhenDeltaIsUnavailable() {
        #expect(
            ImageEditorTransformHUD.displayText(
                frame: CGRect(x: 12.04, y: 23.96, width: 120.25, height: 43.84),
                mode: .move(delta: nil)
            ) == "X 12  Y 24  ·  120.3 × 43.8"
        )
    }

    @Test func resizeReadoutShowsDimensionsAndLiveScalePercent() {
        let text = ImageEditorTransformHUD.displayText(
            frame: CGRect(x: 90, y: 80, width: 164, height: 48),
            mode: .resize(scalePercent: CGSize(width: 136.67, height: 100))
        )

        #expect(text == "164 × 48  ·  W 136.7%  H 100%")
        #expect(ImageEditorTransformHUD.badgeSize(for: text).width >= 88)
    }

    @Test func resizeReadoutFallsBackToDimensionsWhenScaleIsUnavailable() {
        #expect(
            ImageEditorTransformHUD.displayText(
                frame: CGRect(x: 90, y: 80, width: 164, height: 48),
                mode: .resize(scalePercent: nil)
            ) == "164 × 48"
        )
    }

    @Test func rotationReadoutShowsSignedAngleToOneDecimalPlace() {
        #expect(
            ImageEditorTransformHUD.displayText(
                frame: CGRect(x: 10, y: 20, width: 100, height: 60),
                mode: .rotate(degrees: -14.96)
            ) == "-15°"
        )
        #expect(
            ImageEditorTransformHUD.displayText(
                frame: CGRect(x: 10, y: 20, width: 100, height: 60),
                mode: .rotate(degrees: 22.54)
            ) == "22.5°"
        )
    }

    @MainActor
    @Test func rotationReadoutTracksShiftSnappingAndClearsWhenCommitted() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "rotation-hud",
            image: NSImage.transparent(size: CGSize(width: 120, height: 80))
        ) { _ in }
        let frame = try #require(viewModel.selectedLayerTransformFrame)
        let radius: CGFloat = 60
        let start = CGPoint(x: frame.midX, y: frame.midY + radius)
        let dragAngle = CGFloat(104) * .pi / 180
        let end = CGPoint(
            x: frame.midX + cos(dragAngle) * radius,
            y: frame.midY + sin(dragAngle) * radius
        )

        viewModel.beginRotatingSelectedLayer(from: start)
        #expect(viewModel.rotatingPreviewDegrees == 0)
        viewModel.rotateSelectedLayer(to: end, snappingToStep: true)
        #expect(viewModel.rotatingPreviewDegrees == 15)
        viewModel.finishRotatingSelectedLayer()
        #expect(viewModel.rotatingPreviewDegrees == nil)
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
