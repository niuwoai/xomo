import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
@Suite
struct ImageEditorStackLayoutTests {
    @Test func verticalLayoutHonorsPaddingSpacingAndCrossAlignment() {
        let frames = ImageEditorStackLayoutEngine.frames(
            in: CGRect(x: 10, y: 20, width: 200, height: 160),
            itemFrames: [
                CGRect(x: 0, y: 0, width: 30, height: 20),
                CGRect(x: 0, y: 0, width: 50, height: 30)
            ],
            layout: ImageEditorStackLayout(
                axis: .vertical,
                spacing: 10,
                paddingTop: 10,
                paddingRight: 20,
                paddingBottom: 10,
                paddingLeft: 20,
                crossAlignment: .center
            )
        )

        #expect(frames == [
            CGRect(x: 95, y: 30, width: 30, height: 20),
            CGRect(x: 85, y: 60, width: 50, height: 30)
        ])
    }

    @Test func horizontalLayoutSupportsSpaceBetweenAndEndAlignment() {
        let frames = ImageEditorStackLayoutEngine.frames(
            in: CGRect(x: 0, y: 0, width: 200, height: 100),
            itemFrames: [
                CGRect(x: 0, y: 0, width: 20, height: 10),
                CGRect(x: 0, y: 0, width: 40, height: 20),
                CGRect(x: 0, y: 0, width: 30, height: 30)
            ],
            layout: ImageEditorStackLayout(
                axis: .horizontal,
                paddingTop: 10,
                paddingRight: 10,
                paddingBottom: 10,
                paddingLeft: 10,
                primaryAlignment: .spaceBetween,
                crossAlignment: .end
            )
        )

        #expect(frames == [
            CGRect(x: 10, y: 80, width: 20, height: 10),
            CGRect(x: 75, y: 70, width: 40, height: 20),
            CGRect(x: 160, y: 60, width: 30, height: 30)
        ])
    }

    @Test func horizontalBaselineAlignmentUsesFontMetricsAndHugEnvelope() {
        let result = ImageEditorStackLayoutEngine.layout(
            in: CGRect(x: 10, y: 20, width: 200, height: 100),
            itemFrames: [
                CGRect(x: 0, y: 0, width: 30, height: 20),
                CGRect(x: 0, y: 0, width: 40, height: 30)
            ],
            itemBaselineOffsets: [15, 10],
            layout: ImageEditorStackLayout(
                axis: .horizontal,
                spacing: 8,
                paddingTop: 4,
                paddingRight: 6,
                paddingBottom: 6,
                paddingLeft: 5,
                crossAlignment: .baseline,
                crossSizingMode: .hug
            )
        )

        #expect(result.containerFrame == CGRect(x: 10, y: 20, width: 200, height: 45))
        #expect(result.itemFrames == [
            CGRect(x: 15, y: 24, width: 30, height: 20),
            CGRect(x: 53, y: 29, width: 40, height: 30)
        ])
        #expect(result.itemFrames[0].minY + 15 == result.itemFrames[1].minY + 10)
    }

    @Test func wrappedRowsComputeIndependentBaselineEnvelopes() {
        let result = ImageEditorStackLayoutEngine.layout(
            in: CGRect(x: 0, y: 0, width: 100, height: 160),
            itemFrames: [
                CGRect(x: 0, y: 0, width: 30, height: 20),
                CGRect(x: 0, y: 0, width: 30, height: 30),
                CGRect(x: 0, y: 0, width: 30, height: 12)
            ],
            itemBaselineOffsets: [15, 10, 8],
            layout: ImageEditorStackLayout(
                axis: .horizontal,
                spacing: 10,
                paddingTop: 10,
                paddingRight: 10,
                paddingBottom: 10,
                paddingLeft: 10,
                crossAlignment: .baseline,
                crossSizingMode: .hug,
                wrapMode: .wrap,
                counterSpacing: 5
            )
        )

        #expect(result.containerFrame == CGRect(x: 0, y: 0, width: 100, height: 72))
        #expect(result.itemFrames == [
            CGRect(x: 10, y: 10, width: 30, height: 20),
            CGRect(x: 50, y: 15, width: 30, height: 30),
            CGRect(x: 10, y: 50, width: 30, height: 12)
        ])
        #expect(result.itemFrames[0].minY + 15 == result.itemFrames[1].minY + 10)
    }

    @Test func baselineFallsBackToBottomEdgeAndStretchedChildrenKeepTrackOrigin() {
        let frames = ImageEditorStackLayoutEngine.frames(
            in: CGRect(x: 0, y: 0, width: 140, height: 80),
            itemFrames: [
                CGRect(x: 0, y: 0, width: 30, height: 20),
                CGRect(x: 0, y: 0, width: 30, height: 10),
                CGRect(x: 0, y: 0, width: 30, height: 12)
            ],
            itemLayouts: [
                ImageEditorStackChildLayout(),
                ImageEditorStackChildLayout(),
                ImageEditorStackChildLayout(stretchesCrossAxis: true)
            ],
            itemBaselineOffsets: [nil, 6, nil],
            layout: ImageEditorStackLayout(
                axis: .horizontal,
                spacing: 5,
                paddingTop: 10,
                paddingBottom: 10,
                crossAlignment: .baseline
            )
        )

        #expect(frames == [
            CGRect(x: 0, y: 10, width: 30, height: 20),
            CGRect(x: 35, y: 24, width: 30, height: 10),
            CGRect(x: 70, y: 10, width: 30, height: 60)
        ])
    }

    @Test func hugSizingRecomputesBothContainerAxesFromContents() {
        let result = ImageEditorStackLayoutEngine.layout(
            in: CGRect(x: 10, y: 20, width: 300, height: 200),
            itemFrames: [
                CGRect(x: 0, y: 0, width: 30, height: 20),
                CGRect(x: 0, y: 0, width: 50, height: 40)
            ],
            layout: ImageEditorStackLayout(
                axis: .horizontal,
                spacing: 10,
                paddingTop: 3,
                paddingRight: 7,
                paddingBottom: 4,
                paddingLeft: 5,
                primarySizingMode: .hug,
                crossSizingMode: .hug
            )
        )

        #expect(result.containerFrame == CGRect(x: 10, y: 20, width: 102, height: 47))
        #expect(result.itemFrames == [
            CGRect(x: 15, y: 23, width: 30, height: 20),
            CGRect(x: 55, y: 23, width: 50, height: 40)
        ])
    }

    @Test func figmaContainerSizeConstraintsApplyToFixedAndHugLayouts() {
        let constraints = XomoFigmaSizeConstraints(
            minWidth: 150,
            maxWidth: 220,
            minHeight: nil,
            maxHeight: 60
        )
        let fixed = ImageEditorStackLayoutEngine.layout(
            in: CGRect(x: 10, y: 20, width: 500, height: 200),
            itemFrames: [CGRect(x: 0, y: 0, width: 40, height: 20)],
            containerSizeConstraints: constraints,
            layout: ImageEditorStackLayout(axis: .horizontal)
        )
        let hug = ImageEditorStackLayoutEngine.layout(
            in: CGRect(x: 10, y: 20, width: 500, height: 200),
            itemFrames: [CGRect(x: 0, y: 0, width: 100, height: 100)],
            containerSizeConstraints: constraints,
            layout: ImageEditorStackLayout(
                axis: .horizontal,
                primarySizingMode: .hug,
                crossSizingMode: .hug
            )
        )

        #expect(fixed.containerFrame == CGRect(x: 10, y: 20, width: 220, height: 60))
        #expect(hug.containerFrame == CGRect(x: 10, y: 20, width: 150, height: 60))
    }

    @Test func fillChildrenSharePrimarySpaceByWeightAndStretchCrossAxis() {
        let frames = ImageEditorStackLayoutEngine.frames(
            in: CGRect(x: 0, y: 0, width: 300, height: 100),
            itemFrames: [
                CGRect(x: 0, y: 0, width: 20, height: 20),
                CGRect(x: 0, y: 0, width: 30, height: 30),
                CGRect(x: 0, y: 0, width: 40, height: 10)
            ],
            itemLayouts: [
                ImageEditorStackChildLayout(),
                ImageEditorStackChildLayout(grow: 1, stretchesCrossAxis: true),
                ImageEditorStackChildLayout(grow: 2)
            ],
            layout: ImageEditorStackLayout(
                axis: .horizontal,
                spacing: 10,
                paddingTop: 10,
                paddingRight: 10,
                paddingBottom: 10,
                paddingLeft: 10
            )
        )

        #expect(frames == [
            CGRect(x: 10, y: 10, width: 20, height: 20),
            CGRect(x: 40, y: 10, width: 80, height: 80),
            CGRect(x: 130, y: 10, width: 160, height: 10)
        ])
    }

    @Test func figmaSizeConstraintsRedistributeFillAfterAChildReachesItsMaximum() {
        for wrapMode in [ImageEditorStackWrapMode.noWrap, .wrap] {
            let frames = ImageEditorStackLayoutEngine.frames(
                in: CGRect(x: 0, y: 0, width: 300, height: 100),
                itemFrames: [
                    CGRect(x: 0, y: 0, width: 20, height: 20),
                    CGRect(x: 0, y: 0, width: 20, height: 20)
                ],
                itemLayouts: [
                    ImageEditorStackChildLayout(grow: 1, stretchesCrossAxis: true),
                    ImageEditorStackChildLayout(grow: 1, stretchesCrossAxis: true)
                ],
                itemSizeConstraints: [
                    XomoFigmaSizeConstraints(
                        minWidth: nil,
                        maxWidth: 80,
                        minHeight: 30,
                        maxHeight: 50
                    ),
                    XomoFigmaSizeConstraints(
                        minWidth: 140,
                        maxWidth: nil,
                        minHeight: nil,
                        maxHeight: nil
                    )
                ],
                layout: ImageEditorStackLayout(axis: .horizontal, wrapMode: wrapMode)
            )

            #expect(frames == [
                CGRect(x: 0, y: 0, width: 80, height: 50),
                CGRect(x: 80, y: 0, width: 220, height: 100)
            ])
        }
    }

    @Test func conflictingFigmaSizeConstraintsPreferTheMinimum() {
        let frames = ImageEditorStackLayoutEngine.frames(
            in: CGRect(x: 0, y: 0, width: 100, height: 100),
            itemFrames: [CGRect(x: 0, y: 0, width: 20, height: 20)],
            itemSizeConstraints: [XomoFigmaSizeConstraints(
                minWidth: 60,
                maxWidth: 40,
                minHeight: 70,
                maxHeight: 50
            )],
            layout: ImageEditorStackLayout(axis: .horizontal)
        )

        #expect(frames == [CGRect(x: 0, y: 0, width: 60, height: 70)])
    }

    @Test func horizontalWrapCreatesRowsWithIndependentCrossAlignmentAndSpacing() {
        let frames = ImageEditorStackLayoutEngine.frames(
            in: CGRect(x: 0, y: 0, width: 120, height: 100),
            itemFrames: [
                CGRect(x: 0, y: 0, width: 45, height: 20),
                CGRect(x: 0, y: 0, width: 45, height: 30),
                CGRect(x: 0, y: 0, width: 30, height: 10)
            ],
            layout: ImageEditorStackLayout(
                axis: .horizontal,
                spacing: 10,
                paddingTop: 10,
                paddingRight: 10,
                paddingBottom: 10,
                paddingLeft: 10,
                primaryAlignment: .center,
                crossAlignment: .center,
                wrapMode: .wrap,
                counterSpacing: 8
            )
        )

        #expect(frames == [
            CGRect(x: 10, y: 31, width: 45, height: 20),
            CGRect(x: 65, y: 26, width: 45, height: 30),
            CGRect(x: 45, y: 64, width: 30, height: 10)
        ])
    }

    @Test func wrappedRowsDistributeSpaceBetweenTracksAcrossFixedCrossAxis() {
        let result = ImageEditorStackLayoutEngine.layout(
            in: CGRect(x: 0, y: 0, width: 120, height: 140),
            itemFrames: [
                CGRect(x: 0, y: 0, width: 90, height: 20),
                CGRect(x: 0, y: 0, width: 90, height: 30)
            ],
            layout: ImageEditorStackLayout(
                axis: .horizontal,
                paddingTop: 10,
                paddingRight: 10,
                paddingBottom: 10,
                paddingLeft: 10,
                wrapMode: .wrap,
                counterSpacing: 4,
                crossTrackAlignment: .spaceBetween
            )
        )

        #expect(result.containerFrame == CGRect(x: 0, y: 0, width: 120, height: 140))
        #expect(result.itemFrames == [
            CGRect(x: 10, y: 10, width: 90, height: 20),
            CGRect(x: 10, y: 100, width: 90, height: 30)
        ])
    }

    @Test func wrapNormalizationKeepsOfficialHorizontalBoundaryAndSafeSpacing() {
        let vertical = ImageEditorStackLayout(
            axis: .vertical,
            wrapMode: .wrap,
            counterSpacing: -20
        )
        let nonFinite = ImageEditorStackLayout(
            axis: .horizontal,
            wrapMode: .wrap,
            counterSpacing: .infinity
        )
        let nonWrapped = ImageEditorStackLayout(
            axis: .horizontal,
            wrapMode: .noWrap,
            crossTrackAlignment: .spaceBetween
        )

        #expect(vertical.wrapMode == .noWrap)
        #expect(vertical.counterSpacing == 0)
        #expect(nonFinite.wrapMode == .wrap)
        #expect(nonFinite.counterSpacing == 0)
        #expect(nonWrapped.crossTrackAlignment == .automatic)
    }

    @Test func baselineNormalizationKeepsOfficialHorizontalOnlyBoundary() {
        let horizontal = ImageEditorStackLayout(
            axis: .horizontal,
            crossAlignment: .baseline
        )
        let vertical = ImageEditorStackLayout(
            axis: .vertical,
            crossAlignment: .baseline
        )

        #expect(horizontal.crossAlignment == .baseline)
        #expect(vertical.crossAlignment == .start)
        #expect(ImageEditorStackCrossAlignment.availableCases(for: .horizontal).contains(.baseline))
        #expect(!ImageEditorStackCrossAlignment.availableCases(for: .vertical).contains(.baseline))
    }

    @Test func wrappedRowsResizeHugCrossAxisAndDistributeGrowPerRow() {
        let result = ImageEditorStackLayoutEngine.layout(
            in: CGRect(x: 5, y: 7, width: 130, height: 200),
            itemFrames: [
                CGRect(x: 0, y: 0, width: 50, height: 20),
                CGRect(x: 0, y: 0, width: 50, height: 30),
                CGRect(x: 0, y: 0, width: 70, height: 25)
            ],
            itemLayouts: [
                ImageEditorStackChildLayout(),
                ImageEditorStackChildLayout(grow: 1, stretchesCrossAxis: true),
                ImageEditorStackChildLayout()
            ],
            layout: ImageEditorStackLayout(
                axis: .horizontal,
                spacing: 10,
                paddingTop: 5,
                paddingRight: 5,
                paddingBottom: 5,
                paddingLeft: 5,
                crossSizingMode: .hug,
                wrapMode: .wrap,
                counterSpacing: 7
            )
        )

        #expect(result.containerFrame == CGRect(x: 5, y: 7, width: 130, height: 72))
        #expect(result.itemFrames == [
            CGRect(x: 10, y: 12, width: 50, height: 20),
            CGRect(x: 70, y: 12, width: 60, height: 30),
            CGRect(x: 10, y: 49, width: 70, height: 25)
        ])
    }

    @Test func allStretchChildrenExpandWrappedTracksAcrossFixedCrossAxis() {
        let frames = ImageEditorStackLayoutEngine.frames(
            in: CGRect(x: 0, y: 0, width: 120, height: 100),
            itemFrames: [
                CGRect(x: 0, y: 0, width: 70, height: 20),
                CGRect(x: 0, y: 0, width: 70, height: 10)
            ],
            itemLayouts: [
                ImageEditorStackChildLayout(stretchesCrossAxis: true),
                ImageEditorStackChildLayout(stretchesCrossAxis: true)
            ],
            layout: ImageEditorStackLayout(
                axis: .horizontal,
                spacing: 10,
                paddingTop: 10,
                paddingRight: 10,
                paddingBottom: 10,
                paddingLeft: 10,
                wrapMode: .wrap,
                counterSpacing: 10
            )
        )

        #expect(frames == [
            CGRect(x: 10, y: 10, width: 70, height: 40),
            CGRect(x: 10, y: 60, width: 70, height: 30)
        ])
    }

    @Test func reflowMovesDirectChildrenAndNestedSubtreeButNotExcludedBackground() throws {
        let fixture = makeFixture()
        let originalChildFrame = fixture.layer(named: "First").frame
        let originalNestedFrame = fixture.layer(named: "Nested").frame
        let originalDescendantFrame = fixture.layer(named: "Nested Child").frame
        let originalBackgroundFrame = fixture.layer(named: "Background").frame

        fixture.viewModel.reflowSelectedStackLayout()

        #expect(fixture.layer(named: "First").frame == CGRect(x: 95, y: 30, width: 30, height: 20))
        #expect(fixture.layer(named: "Nested").frame == CGRect(x: 85, y: 60, width: 50, height: 30))
        #expect(fixture.layer(named: "Nested Child").frame == CGRect(x: 95, y: 70, width: 10, height: 10))
        #expect(fixture.layer(named: "Background").frame == originalBackgroundFrame)
        #expect(fixture.viewModel.document.history.last?.title == L10n.text("imageEditor.history.stackLayout"))

        fixture.viewModel.undo()
        #expect(fixture.layer(named: "First").frame == originalChildFrame)
        #expect(fixture.layer(named: "Nested").frame == originalNestedFrame)
        #expect(fixture.layer(named: "Nested Child").frame == originalDescendantFrame)

        fixture.viewModel.redo()
        #expect(fixture.layer(named: "First").frame == CGRect(x: 95, y: 30, width: 30, height: 20))
    }

    @Test func reflowExecutesImportedFigmaChildSizeConstraints() {
        let fixture = makeFixture()
        fixture.updateLayer(named: "First") {
            $0.xomoFigmaSizeConstraints = XomoFigmaSizeConstraints(
                minWidth: 80,
                maxWidth: nil,
                minHeight: nil,
                maxHeight: 15
            )
        }

        fixture.viewModel.reflowSelectedStackLayout()

        #expect(fixture.layer(named: "First").frame == CGRect(x: 70, y: 30, width: 80, height: 15))
        #expect(fixture.layer(named: "Nested").frame == CGRect(x: 85, y: 55, width: 50, height: 30))
    }

    @Test func localFigmaConstraintEditsReflowAndSupportUndoRedo() {
        let fixture = makeFixture()
        fixture.selectLayer(named: "First")

        fixture.viewModel.setSelectedFigmaSizeConstraint(.minWidth, value: 80)

        #expect(fixture.layer(named: "First").xomoFigmaSizeConstraints?.minWidth == 80)
        #expect(fixture.layer(named: "First").xomoFigmaSizeConstraintDefaults == .empty)
        #expect(fixture.viewModel.hasSelectedFigmaSizeConstraintOverride(.minWidth))
        #expect(fixture.layer(named: "First").frame == CGRect(x: 70, y: 30, width: 80, height: 20))
        #expect(fixture.viewModel.document.history.last?.title == L10n.format(
            "imageEditor.history.figmaSizeConstraintChanged",
            L10n.text("imageEditor.properties.figmaMinWidth")
        ))

        fixture.viewModel.undo()
        #expect(fixture.layer(named: "First").xomoFigmaSizeConstraints == nil)
        #expect(fixture.layer(named: "First").xomoFigmaSizeConstraintDefaults == nil)
        #expect(fixture.layer(named: "First").frame == CGRect(x: 30, y: 40, width: 30, height: 20))

        fixture.viewModel.redo()
        #expect(fixture.layer(named: "First").xomoFigmaSizeConstraints?.minWidth == 80)
        #expect(fixture.layer(named: "First").xomoFigmaSizeConstraintDefaults == .empty)
        #expect(fixture.layer(named: "First").frame == CGRect(x: 70, y: 30, width: 80, height: 20))

        fixture.viewModel.setSelectedFigmaSizeConstraint(.maxHeight, value: 0)
        #expect(fixture.layer(named: "First").xomoFigmaSizeConstraints?.maxHeight == 1)
        #expect(fixture.layer(named: "First").frame == CGRect(x: 70, y: 30, width: 80, height: 1))
        #expect(fixture.layer(named: "Nested").frame == CGRect(x: 85, y: 41, width: 50, height: 30))

        let historyCount = fixture.viewModel.document.history.count
        fixture.viewModel.setSelectedFigmaSizeConstraint(.maxHeight, value: .infinity)
        #expect(fixture.viewModel.document.history.count == historyCount)
        #expect(fixture.layer(named: "First").xomoFigmaSizeConstraints?.maxHeight == 1)

        fixture.viewModel.setSelectedFigmaSizeConstraint(.maxHeight, value: nil)
        #expect(fixture.layer(named: "First").xomoFigmaSizeConstraints?.maxHeight == nil)
        #expect(fixture.layer(named: "First").xomoFigmaSizeConstraints?.minWidth == 80)

        fixture.viewModel.resetSelectedFigmaSizeConstraint(.minWidth)
        #expect(fixture.layer(named: "First").xomoFigmaSizeConstraints == nil)
        #expect(fixture.layer(named: "First").xomoFigmaSizeConstraintDefaults == .empty)
        #expect(!fixture.viewModel.hasSelectedFigmaSizeConstraintOverride(.minWidth))
    }

    @Test func localFigmaConstraintEditsRespectLockedAutoLayout() {
        let fixture = makeFixture()
        fixture.updateLayer(named: "Root") { $0.locksPosition = true }
        fixture.selectLayer(named: "First")

        fixture.viewModel.setSelectedFigmaSizeConstraint(.minWidth, value: 80)

        #expect(fixture.layer(named: "First").xomoFigmaSizeConstraints == nil)
        #expect(fixture.layer(named: "First").frame == CGRect(x: 30, y: 40, width: 30, height: 20))
        #expect(fixture.viewModel.statusText == L10n.text("imageEditor.status.stackLayoutLocked"))
    }

    @Test func nestedPositionLockPreventsAncestorStackLayoutFromMovingTheSubtree() {
        let fixture = makeFixture()
        fixture.updateLayer(named: "Nested Child") { $0.locksPosition = true }
        let framesBefore = Dictionary(uniqueKeysWithValues: fixture.viewModel.document.layers.map {
            ($0.id, $0.frame)
        })
        let historyCount = fixture.viewModel.document.history.count

        fixture.viewModel.setSelectedStackSpacing(24)

        #expect(fixture.layer(named: "Root").stackLayout?.spacing == 10)
        #expect(fixture.viewModel.document.layers.allSatisfy { framesBefore[$0.id] == $0.frame })
        #expect(fixture.viewModel.document.history.count == historyCount)
        #expect(fixture.viewModel.statusText == L10n.text("imageEditor.status.stackLayoutLocked"))
    }

    @Test func resetAllFigmaConstraintOverridesUsesOneUndoAndOneReflow() {
        let fixture = makeFixture()
        let imported = XomoFigmaSizeConstraints(
            minWidth: 40,
            maxWidth: nil,
            minHeight: nil,
            maxHeight: 15
        )
        fixture.updateLayer(named: "First") {
            $0.xomoFigmaSizeConstraints = imported
            $0.xomoFigmaSizeConstraintDefaults = imported
        }
        fixture.selectLayer(named: "First")
        fixture.viewModel.reflowSelectedStackLayout()
        fixture.viewModel.setSelectedFigmaSizeConstraint(.minWidth, value: 80)
        fixture.viewModel.setSelectedFigmaSizeConstraint(.maxHeight, value: 10)
        #expect(fixture.viewModel.hasSelectedFigmaSizeConstraintOverrides)
        #expect(fixture.layer(named: "First").frame == CGRect(x: 70, y: 30, width: 80, height: 10))

        fixture.viewModel.resetAllSelectedFigmaSizeConstraints()

        #expect(fixture.layer(named: "First").xomoFigmaSizeConstraints == imported)
        #expect(fixture.layer(named: "First").xomoFigmaSizeConstraintDefaults == imported)
        #expect(!fixture.viewModel.hasSelectedFigmaSizeConstraintOverrides)
        // Restoring min/max metadata must not invent an imported preferred size.
        // The current 80×10 frame remains valid inside the restored bounds.
        #expect(fixture.layer(named: "First").frame == CGRect(x: 70, y: 30, width: 80, height: 10))
        #expect(fixture.viewModel.document.history.last?.title == L10n.text(
            "imageEditor.history.figmaSizeConstraintsReset"
        ))

        fixture.viewModel.undo()
        #expect(fixture.layer(named: "First").xomoFigmaSizeConstraints?.minWidth == 80)
        #expect(fixture.layer(named: "First").xomoFigmaSizeConstraints?.maxHeight == 10)
        #expect(fixture.layer(named: "First").frame == CGRect(x: 70, y: 30, width: 80, height: 10))

        fixture.viewModel.redo()
        #expect(fixture.layer(named: "First").xomoFigmaSizeConstraints == imported)
        let historyCount = fixture.viewModel.document.history.count
        fixture.viewModel.resetAllSelectedFigmaSizeConstraints()
        #expect(fixture.viewModel.document.history.count == historyCount)
    }

    @Test func resolveFigmaConstraintConflictUsesMinimumAndSupportsUndo() {
        let fixture = makeFixture()
        let imported = XomoFigmaSizeConstraints(
            minWidth: 80,
            maxWidth: 40,
            minHeight: nil,
            maxHeight: nil
        )
        fixture.updateLayer(named: "First") {
            $0.xomoFigmaSizeConstraints = imported
            $0.xomoFigmaSizeConstraintDefaults = imported
        }
        fixture.selectLayer(named: "First")

        fixture.viewModel.resolveSelectedFigmaSizeConstraintConflict(.width)

        #expect(fixture.layer(named: "First").xomoFigmaSizeConstraints?.minWidth == 80)
        #expect(fixture.layer(named: "First").xomoFigmaSizeConstraints?.maxWidth == 80)
        #expect(fixture.viewModel.selectedLayerFigmaSizeConstraintConflicts.isEmpty)
        #expect(fixture.viewModel.hasSelectedFigmaSizeConstraintOverride(.maxWidth))
        #expect(fixture.layer(named: "First").frame == CGRect(x: 70, y: 30, width: 80, height: 20))

        fixture.viewModel.undo()
        #expect(fixture.layer(named: "First").xomoFigmaSizeConstraints == imported)
        #expect(fixture.viewModel.selectedLayerFigmaSizeConstraintConflicts == [.width])
        #expect(fixture.layer(named: "First").frame == CGRect(x: 30, y: 40, width: 30, height: 20))

        fixture.viewModel.redo()
        #expect(fixture.layer(named: "First").xomoFigmaSizeConstraints?.maxWidth == 80)
        #expect(fixture.viewModel.selectedLayerFigmaSizeConstraintConflicts.isEmpty)
    }

    @Test func resolveAllFigmaConstraintConflictsUsesOneUndoAndOneReflow() {
        let fixture = makeFixture()
        let imported = XomoFigmaSizeConstraints(
            minWidth: 80,
            maxWidth: 40,
            minHeight: 30,
            maxHeight: 10
        )
        fixture.updateLayer(named: "First") {
            $0.xomoFigmaSizeConstraints = imported
            $0.xomoFigmaSizeConstraintDefaults = imported
        }
        fixture.selectLayer(named: "First")

        fixture.viewModel.resolveAllSelectedFigmaSizeConstraintConflicts()

        #expect(fixture.layer(named: "First").xomoFigmaSizeConstraints == XomoFigmaSizeConstraints(
            minWidth: 80,
            maxWidth: 80,
            minHeight: 30,
            maxHeight: 30
        ))
        #expect(fixture.viewModel.selectedLayerFigmaSizeConstraintConflicts.isEmpty)
        #expect(fixture.layer(named: "First").frame == CGRect(x: 70, y: 30, width: 80, height: 30))
        #expect(fixture.viewModel.document.history.last?.title == L10n.text(
            "imageEditor.history.figmaSizeConstraintConflictsResolved"
        ))

        fixture.viewModel.undo()
        #expect(fixture.layer(named: "First").xomoFigmaSizeConstraints == imported)
        #expect(fixture.viewModel.selectedLayerFigmaSizeConstraintConflicts == [.width, .height])
        #expect(fixture.layer(named: "First").frame == CGRect(x: 30, y: 40, width: 30, height: 20))

        fixture.viewModel.redo()
        #expect(fixture.viewModel.selectedLayerFigmaSizeConstraintConflicts.isEmpty)
    }

    @Test func reflowExecutesImportedFigmaContainerConstraintsAndResizesBackground() {
        let fixture = makeFixture()
        fixture.updateLayer(named: "Root") {
            $0.xomoFigmaSizeConstraints = XomoFigmaSizeConstraints(
                minWidth: nil,
                maxWidth: 120,
                minHeight: nil,
                maxHeight: 100
            )
        }

        fixture.viewModel.reflowSelectedStackLayout()

        #expect(fixture.layer(named: "Root").frame == CGRect(x: 10, y: 20, width: 120, height: 100))
        #expect(fixture.layer(named: "Background").frame == CGRect(x: 10, y: 20, width: 120, height: 100))
        #expect(fixture.layer(named: "First").frame == CGRect(x: 55, y: 30, width: 30, height: 20))
        #expect(fixture.layer(named: "Nested").frame == CGRect(x: 45, y: 60, width: 50, height: 30))
    }

    @Test func reflowDerivesLiveBaselinesFromTextLayerFontMetrics() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "baseline.png",
            image: NSImage.transparent(size: CGSize(width: 240, height: 120))
        ) { _ in }
        var root = ImageEditorLayer.group(name: "Baseline Row", size: viewModel.document.canvasSize)
        root.frame = CGRect(x: 10, y: 20, width: 220, height: 80)
        root.stackLayout = ImageEditorStackLayout(
            axis: .horizontal,
            spacing: 12,
            paddingTop: 8,
            paddingRight: 8,
            paddingBottom: 8,
            paddingLeft: 8,
            crossAlignment: .baseline
        )
        let padding = ImageEditorTextContent.drawingPadding
        var caption = ImageEditorLayer.text(
            name: "Caption",
            origin: CGPoint(x: 80, y: 70),
            content: ImageEditorTextContent(
                text: "Caption",
                color: .white,
                fontSize: 12,
                point: CGPoint(x: padding, y: padding)
            )
        )
        caption.groupID = root.id
        var title = ImageEditorLayer.text(
            name: "Title",
            origin: CGPoint(x: 130, y: 30),
            content: ImageEditorTextContent(
                text: "Title",
                color: .white,
                fontSize: 28,
                point: CGPoint(x: padding, y: padding)
            )
        )
        title.groupID = root.id
        viewModel.document.layers = [caption, title, root]
        viewModel.document.selectedLayerID = root.id
        viewModel.document.selectedLayerIDs = [root.id]

        viewModel.reflowSelectedStackLayout()

        let movedCaption = try #require(viewModel.document.layers.first { $0.name == "Caption" })
        let movedTitle = try #require(viewModel.document.layers.first { $0.name == "Title" })
        let captionBaseline = try #require(movedCaption.stackBaselineOffset)
        let titleBaseline = try #require(movedTitle.stackBaselineOffset)
        #expect(abs(
            movedCaption.frame.minY + captionBaseline
                - movedTitle.frame.minY - titleBaseline
        ) < 0.001)
        #expect(movedCaption.frame.minY > movedTitle.frame.minY)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.stackLayout"))
    }

    @Test func textBaselineOffsetScalesWithTransformedLayerHeight() throws {
        let padding = ImageEditorTextContent.drawingPadding
        var layer = ImageEditorLayer.text(
            name: "Scale",
            origin: .zero,
            content: ImageEditorTextContent(
                text: "Scale",
                color: .white,
                fontSize: 20,
                point: CGPoint(x: padding, y: padding)
            )
        )
        let original = try #require(layer.stackBaselineOffset)

        layer.frame.size.height *= 2

        let scaled = try #require(layer.stackBaselineOffset)
        #expect(abs(scaled - original * 2) < 0.001)
    }

    @Test func stackLayoutAndExclusionSurviveProjectRoundTrip() throws {
        let fixture = makeFixture()
        fixture.updateRootLayout { layout in
            layout.primarySizingMode = .hug
            layout.crossSizingMode = .hug
        }
        fixture.updateLayer(named: "First") {
            $0.stackChildLayout = ImageEditorStackChildLayout(grow: 2, stretchesCrossAxis: true)
        }
        let projectData = try fixture.viewModel.projectData()
        let reopened = ImageEditorViewModel(
            sourceName: "empty.png",
            image: NSImage.transparent(size: CGSize(width: 8, height: 8))
        ) { _ in }

        try reopened.loadProjectData(projectData)

        let root = try #require(reopened.document.layers.first { $0.name == "Root" })
        let background = try #require(reopened.document.layers.first { $0.name == "Background" })
        let first = try #require(reopened.document.layers.first { $0.name == "First" })
        #expect(root.stackLayout == ImageEditorStackLayout(
            axis: .vertical,
            spacing: 10,
            paddingTop: 10,
            paddingRight: 20,
            paddingBottom: 10,
            paddingLeft: 20,
            crossAlignment: .center,
            primarySizingMode: .hug,
            crossSizingMode: .hug
        ))
        #expect(background.isStackLayoutExcluded)
        #expect(background.isStackLayoutBackground)
        #expect(first.stackChildLayout == ImageEditorStackChildLayout(
            grow: 2,
            stretchesCrossAxis: true
        ))
    }

    @Test func hugReflowResizesGroupAndBackgroundWithUndoRedo() {
        let fixture = makeFixture()
        fixture.updateRootLayout { layout in
            layout.primarySizingMode = .hug
            layout.crossSizingMode = .hug
        }
        let originalRootFrame = fixture.layer(named: "Root").frame
        let originalBackgroundFrame = fixture.layer(named: "Background").frame

        fixture.viewModel.reflowSelectedStackLayout()

        #expect(fixture.layer(named: "Root").frame == CGRect(x: 10, y: 20, width: 90, height: 80))
        #expect(fixture.layer(named: "Background").frame == CGRect(x: 10, y: 20, width: 90, height: 80))
        #expect(fixture.layer(named: "First").frame == CGRect(x: 40, y: 30, width: 30, height: 20))
        #expect(fixture.layer(named: "Nested").frame == CGRect(x: 30, y: 60, width: 50, height: 30))

        fixture.viewModel.undo()
        #expect(fixture.layer(named: "Root").frame == originalRootFrame)
        #expect(fixture.layer(named: "Background").frame == originalBackgroundFrame)

        fixture.viewModel.redo()
        #expect(fixture.layer(named: "Root").frame == CGRect(x: 10, y: 20, width: 90, height: 80))
    }

    @Test func legacyStackLayoutWithoutSizingModesDefaultsToFixed() throws {
        let data = Data(
            """
            {
              "axis": "horizontal",
              "spacing": 8,
              "paddingTop": 1,
              "paddingRight": 2,
              "paddingBottom": 3,
              "paddingLeft": 4,
              "primaryAlignment": "start",
              "crossAlignment": "center"
            }
            """.utf8
        )

        let layout = try JSONDecoder().decode(ImageEditorStackLayout.self, from: data)
        #expect(layout.primarySizingMode == .fixed)
        #expect(layout.crossSizingMode == .fixed)
        #expect(layout.wrapMode == .noWrap)
        #expect(layout.counterSpacing == 0)
    }

    @Test func wrapSettingsSurviveProjectRoundTrip() throws {
        let fixture = makeFixture()
        fixture.updateRootLayout { layout in
            layout.axis = .horizontal
            layout.wrapMode = .wrap
            layout.counterSpacing = 17
            layout.crossAlignment = .baseline
            layout.crossTrackAlignment = .spaceBetween
        }
        let projectData = try fixture.viewModel.projectData()
        let reopened = ImageEditorViewModel(
            sourceName: "empty.png",
            image: NSImage.transparent(size: CGSize(width: 8, height: 8))
        ) { _ in }

        try reopened.loadProjectData(projectData)

        let root = try #require(reopened.document.layers.first { $0.name == "Root" })
        #expect(root.stackLayout?.wrapMode == .wrap)
        #expect(root.stackLayout?.counterSpacing == 17)
        #expect(root.stackLayout?.crossAlignment == .baseline)
        #expect(root.stackLayout?.crossTrackAlignment == .spaceBetween)
    }

    @Test func wrapControlsReflowAndSupportUndoRedo() {
        let fixture = makeFixture()

        fixture.viewModel.setSelectedStackAxis(.horizontal)
        fixture.viewModel.setSelectedStackWrapMode(.wrap)
        fixture.viewModel.setSelectedStackCounterSpacing(19)
        #expect(fixture.viewModel.selectedStackLayout?.wrapMode == .wrap)
        #expect(fixture.viewModel.selectedStackLayout?.counterSpacing == 19)
        #expect(fixture.viewModel.document.history.last?.title == L10n.text("imageEditor.history.stackLayout"))

        fixture.viewModel.undo()
        #expect(fixture.viewModel.selectedStackLayout?.counterSpacing == 0)

        fixture.viewModel.redo()
        #expect(fixture.viewModel.selectedStackLayout?.counterSpacing == 19)
    }

    @Test func wrappedHugReflowResizesGroupAndBackgroundWithUndo() {
        let fixture = makeFixture()
        fixture.updateLayer(named: "Root") { layer in
            layer.frame.size.width = 100
        }
        fixture.updateRootLayout { layout in
            layout.axis = .horizontal
            layout.wrapMode = .wrap
            layout.counterSpacing = 15
            layout.crossSizingMode = .hug
        }

        fixture.viewModel.reflowSelectedStackLayout()

        #expect(fixture.layer(named: "Root").frame == CGRect(x: 10, y: 20, width: 100, height: 85))
        #expect(fixture.layer(named: "Background").frame == CGRect(x: 10, y: 20, width: 100, height: 85))
        #expect(fixture.layer(named: "First").frame == CGRect(x: 30, y: 30, width: 30, height: 20))
        #expect(fixture.layer(named: "Nested").frame == CGRect(x: 30, y: 65, width: 50, height: 30))

        fixture.viewModel.undo()
        #expect(fixture.layer(named: "Root").frame == CGRect(x: 10, y: 20, width: 100, height: 160))
        #expect(fixture.layer(named: "Background").frame == CGRect(x: 10, y: 20, width: 200, height: 160))
    }

    @Test func childSizingControlsReflowParentAndSupportUndoRedo() {
        let fixture = makeFixture()
        fixture.selectLayer(named: "First")

        #expect(fixture.viewModel.selectedStackChildLayout?.primarySizingMode == .fixed)
        fixture.viewModel.setSelectedStackChildPrimarySizingMode(.fill)
        #expect(fixture.layer(named: "First").frame == CGRect(x: 95, y: 30, width: 30, height: 100))
        #expect(fixture.layer(named: "Nested").frame == CGRect(x: 85, y: 140, width: 50, height: 30))

        fixture.viewModel.setSelectedStackChildCrossSizingMode(.fill)
        #expect(fixture.layer(named: "First").frame == CGRect(x: 30, y: 30, width: 160, height: 100))
        #expect(fixture.viewModel.document.history.last?.title == L10n.text("imageEditor.history.stackChildLayout"))

        fixture.viewModel.undo()
        #expect(fixture.layer(named: "First").frame == CGRect(x: 95, y: 30, width: 30, height: 100))

        fixture.viewModel.redo()
        #expect(fixture.layer(named: "First").frame == CGRect(x: 30, y: 30, width: 160, height: 100))
    }

    @Test func propertyPanelAndLayerTabsKeepExplicitInteractionAndLightTextContracts() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorStackLayoutControls.swift"),
            encoding: .utf8
        )
        let panelSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorLayerPanel.swift"),
            encoding: .utf8
        )

        #expect(viewSource.contains("image-editor-stack-layout-axis"))
        #expect(viewSource.contains("image-editor-stack-layout-cross-alignment"))
        #expect(viewSource.contains("image-editor-stack-layout-primary-sizing"))
        #expect(viewSource.contains("image-editor-stack-layout-cross-sizing"))
        #expect(viewSource.contains("image-editor-stack-layout-wrap"))
        #expect(viewSource.contains("image-editor-stack-layout-cross-track-alignment"))
        #expect(viewSource.contains("image-editor-stack-layout-counter-spacing"))
        #expect(viewSource.contains("image-editor-stack-child-primary-sizing"))
        #expect(viewSource.contains("image-editor-stack-child-cross-sizing"))
        #expect(viewSource.contains("image-editor-stack-layout-reflow"))
        #expect(viewSource.contains("setSelectedStackSpacing"))
        #expect(viewSource.contains("ImageEditorStackCrossAlignment.availableCases"))
        #expect(panelSource.contains("static let foregroundColor = NSColor(calibratedWhite: 0.88, alpha: 1)"))
        #expect(panelSource.contains(".foregroundColor: color"))
    }

    private func makeFixture() -> StackLayoutFixture {
        let viewModel = ImageEditorViewModel(
            sourceName: "stack-layout.png",
            image: NSImage.transparent(size: CGSize(width: 240, height: 200))
        ) { _ in }
        var root = ImageEditorLayer.group(name: "Root", size: viewModel.document.canvasSize)
        root.frame = CGRect(x: 10, y: 20, width: 200, height: 160)
        root.stackLayout = ImageEditorStackLayout(
            axis: .vertical,
            spacing: 10,
            paddingTop: 10,
            paddingRight: 20,
            paddingBottom: 10,
            paddingLeft: 20,
            crossAlignment: .center
        )
        var first = ImageEditorLayer.blank(name: "First", size: CGSize(width: 30, height: 20))
        first.frame = CGRect(x: 30, y: 40, width: 30, height: 20)
        first.groupID = root.id
        var nested = ImageEditorLayer.group(name: "Nested", size: CGSize(width: 50, height: 30))
        nested.frame = CGRect(x: 100, y: 100, width: 50, height: 30)
        nested.groupID = root.id
        var descendant = ImageEditorLayer.blank(name: "Nested Child", size: CGSize(width: 10, height: 10))
        descendant.frame = CGRect(x: 110, y: 110, width: 10, height: 10)
        descendant.groupID = nested.id
        var background = ImageEditorLayer.blank(name: "Background", size: CGSize(width: 200, height: 160))
        background.frame = root.frame
        background.groupID = root.id
        background.isStackLayoutExcluded = true
        background.isStackLayoutBackground = true
        viewModel.document.layers = [first, descendant, nested, background, root]
        viewModel.document.selectedLayerID = root.id
        viewModel.document.selectedLayerIDs = [root.id]
        return StackLayoutFixture(viewModel: viewModel)
    }
}

@MainActor
private struct StackLayoutFixture {
    let viewModel: ImageEditorViewModel

    func layer(named name: String) -> ImageEditorLayer {
        guard let layer = viewModel.document.layers.first(where: { $0.name == name }) else {
            fatalError("Missing test layer")
        }
        return layer
    }

    func updateRootLayout(_ update: (inout ImageEditorStackLayout) -> Void) {
        guard let index = viewModel.document.layers.firstIndex(where: { $0.name == "Root" }),
              var layout = viewModel.document.layers[index].stackLayout else {
            fatalError("Missing root stack layout")
        }
        update(&layout)
        viewModel.document.layers[index].stackLayout = layout
    }

    func updateLayer(named name: String, update: (inout ImageEditorLayer) -> Void) {
        guard let index = viewModel.document.layers.firstIndex(where: { $0.name == name }) else {
            fatalError("Missing test layer")
        }
        update(&viewModel.document.layers[index])
    }

    func selectLayer(named name: String) {
        guard let layer = viewModel.document.layers.first(where: { $0.name == name }) else {
            fatalError("Missing test layer")
        }
        viewModel.document.selectedLayerID = layer.id
        viewModel.document.selectedLayerIDs = [layer.id]
    }
}
