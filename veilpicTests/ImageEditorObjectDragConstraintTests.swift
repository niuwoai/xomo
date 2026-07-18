import CoreGraphics
import Testing
@testable import musepic

struct ImageEditorObjectDragConstraintTests {
    @Test func shiftChoosesTheDominantAxisAfterMeaningfulMovement() {
        #expect(
            ImageEditorObjectDragConstraint.resolvedAxis(
                for: CGSize(width: 12, height: 4),
                existingAxis: nil,
                isConstrained: true
            ) == .horizontal
        )
        #expect(
            ImageEditorObjectDragConstraint.resolvedAxis(
                for: CGSize(width: 2, height: -14),
                existingAxis: nil,
                isConstrained: true
            ) == .vertical
        )
    }

    @Test func tinyPointerNoiseDoesNotChooseTheWrongAxis() {
        #expect(
            ImageEditorObjectDragConstraint.resolvedAxis(
                for: CGSize(width: 0.2, height: 0.3),
                existingAxis: nil,
                isConstrained: true
            ) == nil
        )
    }

    @Test func heldShiftKeepsTheFirstAxisWhenTheDiagonalChanges() {
        #expect(
            ImageEditorObjectDragConstraint.resolvedAxis(
                for: CGSize(width: 8, height: 30),
                existingAxis: .horizontal,
                isConstrained: true
            ) == .horizontal
        )
    }

    @Test func releasingShiftClearsTheAxisWithoutAddingAJump() {
        let axis = ImageEditorObjectDragConstraint.resolvedAxis(
            for: CGSize(width: 20, height: 8),
            existingAxis: .horizontal,
            isConstrained: false
        )
        let delta = ImageEditorObjectDragConstraint.incrementalDelta(
            currentTranslation: CGSize(width: 23, height: 12),
            previousTranslation: CGSize(width: 20, height: 8),
            axis: axis
        )

        #expect(axis == nil)
        #expect(delta == CGSize(width: 3, height: 4))
    }

    @Test func constrainedIncrementChangesOnlyTheLockedAxis() {
        #expect(
            ImageEditorObjectDragConstraint.incrementalDelta(
                currentTranslation: CGSize(width: 18, height: 11),
                previousTranslation: CGSize(width: 12, height: 7),
                axis: .horizontal
            ) == CGSize(width: 6, height: 0)
        )
        #expect(
            ImageEditorObjectDragConstraint.incrementalDelta(
                currentTranslation: CGSize(width: 18, height: 11),
                previousTranslation: CGSize(width: 12, height: 7),
                axis: .vertical
            ) == CGSize(width: 0, height: 4)
        )
    }
}
