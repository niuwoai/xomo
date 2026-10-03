//
//  ImageEditorLayerCompTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/9.
//

import AppKit
import SwiftUI
import Testing
@testable import musepic

@MainActor
struct ImageEditorLayerCompTests {
    @Test
    func previousAndNextCycleApplyCanvasStatesAndPreserveTheInitialDocumentState() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemBlue, size: NSSize(width: 100, height: 80))
        ) { _ in }
        viewModel.addLayer()
        let detailID = try #require(viewModel.document.selectedLayerID)

        viewModel.addLayerComp(named: "Visible detail")
        let visibleCompID = try #require(viewModel.document.selectedLayerCompID)
        viewModel.toggleLayerVisibility(detailID)
        viewModel.addLayerComp(named: "Hidden detail")
        let hiddenCompID = try #require(viewModel.document.selectedLayerCompID)
        let historyCount = viewModel.document.history.count

        #expect(viewModel.applyPreviousLayerComp())
        #expect(viewModel.document.selectedLayerCompID == visibleCompID)
        #expect(viewModel.document.layers.first { $0.id == detailID }?.isVisible == true)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.lastDocumentLayerCompState?.layerStates.first {
            $0.layerID == detailID
        }?.isVisible == false)

        let boundaryHistoryCount = viewModel.document.history.count
        #expect(!viewModel.applyPreviousLayerComp())
        #expect(viewModel.document.selectedLayerCompID == visibleCompID)
        #expect(viewModel.document.history.count == boundaryHistoryCount)

        #expect(viewModel.applyNextLayerComp())
        #expect(viewModel.document.selectedLayerCompID == hiddenCompID)
        #expect(viewModel.document.layers.first { $0.id == detailID }?.isVisible == false)
        #expect(viewModel.document.history.count == boundaryHistoryCount + 1)
        #expect(viewModel.lastDocumentLayerCompState?.layerStates.first {
            $0.layerID == detailID
        }?.isVisible == false)

        #expect(viewModel.restoreLastDocumentLayerCompState())
        #expect(viewModel.document.selectedLayerCompID == nil)
        #expect(viewModel.document.layers.first { $0.id == detailID }?.isVisible == false)
        #expect(viewModel.lastDocumentLayerCompState == nil)
    }

    @Test
    func layerCompSearchMatchesNamesAndCommentsAndNavigatesOnlyFilteredResults() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemBlue, size: NSSize(width: 100, height: 80))
        ) { _ in }
        let layerID = try #require(viewModel.document.selectedLayerID)

        viewModel.addLayerComp(named: "Desktop Élite")
        let desktopID = try #require(viewModel.document.selectedLayerCompID)
        viewModel.toggleLayerVisibility(layerID)
        viewModel.addLayerComp(named: "Mobile Draft")
        let mobileID = try #require(viewModel.document.selectedLayerCompID)
        viewModel.toggleLayerVisibility(layerID)
        viewModel.addLayerComp(named: "Tablet Final")
        let tabletID = try #require(viewModel.document.selectedLayerCompID)
        #expect(viewModel.updateLayerCompComment(desktopID, to: "Client approved"))
        #expect(viewModel.updateLayerCompComment(mobileID, to: "Needs review"))
        #expect(viewModel.updateLayerCompComment(tabletID, to: "Approved handoff"))
        viewModel.selectLayerComp(mobileID)
        viewModel.document.layerComps[0].isFavorite = true
        viewModel.document.layerComps[2].isFavorite = true

        let projectDataBeforeSearch = try viewModel.projectData()
        let historyBeforeSearch = viewModel.document.history
        let undoCountBeforeSearch = viewModel.undoStack.count
        let redoCountBeforeSearch = viewModel.redoStack.count
        #expect(ImageEditorLayerCompSearch.filtered(
            viewModel.document.layerComps,
            matching: "  elite  "
        ).map(\.id) == [desktopID])
        #expect(ImageEditorLayerCompSearch.filtered(
            viewModel.document.layerComps,
            matching: "APPROVED"
        ).map(\.id) == [desktopID, tabletID])
        #expect(ImageEditorLayerCompSearch.filtered(
            viewModel.document.layerComps,
            matching: "  mobile\n review  "
        ).map(\.id) == [mobileID])
        #expect(ImageEditorLayerCompSearch.filtered(
            viewModel.document.layerComps,
            matching: "TABLET approved"
        ).map(\.id) == [tabletID])
        #expect(ImageEditorLayerCompSearch.filtered(
            viewModel.document.layerComps,
            matching: "approved review"
        ).isEmpty)
        #expect(ImageEditorLayerCompSearch.filtered(
            viewModel.document.layerComps,
            matching: "\"client approved\""
        ).map(\.id) == [desktopID])
        #expect(ImageEditorLayerCompSearch.filtered(
            viewModel.document.layerComps,
            matching: "\"client approved"
        ).map(\.id) == [desktopID])
        #expect(ImageEditorLayerCompSearch.filtered(
            viewModel.document.layerComps,
            matching: "approved -desktop"
        ).map(\.id) == [tabletID])
        #expect(ImageEditorLayerCompSearch.filtered(
            viewModel.document.layerComps,
            matching: "approved -\"client approved\""
        ).map(\.id) == [tabletID])
        #expect(ImageEditorLayerCompSearch.filtered(
            viewModel.document.layerComps,
            matching: "-approved"
        ).map(\.id) == [mobileID])
        #expect(ImageEditorLayerCompSearch.filtered(
            viewModel.document.layerComps,
            matching: "name:desktop"
        ).map(\.id) == [desktopID])
        #expect(ImageEditorLayerCompSearch.filtered(
            viewModel.document.layerComps,
            matching: "NAME:tablet"
        ).map(\.id) == [tabletID])
        #expect(ImageEditorLayerCompSearch.filtered(
            viewModel.document.layerComps,
            matching: "comment:approved"
        ).map(\.id) == [desktopID, tabletID])
        #expect(ImageEditorLayerCompSearch.filtered(
            viewModel.document.layerComps,
            matching: "name:approved"
        ).isEmpty)
        #expect(ImageEditorLayerCompSearch.filtered(
            viewModel.document.layerComps,
            matching: "comment:\"client approved\""
        ).map(\.id) == [desktopID])
        #expect(ImageEditorLayerCompSearch.filtered(
            viewModel.document.layerComps,
            matching: "approved -comment:client"
        ).map(\.id) == [tabletID])
        #expect(ImageEditorLayerCompSearch.filtered(
            viewModel.document.layerComps,
            matching: "-name:mobile"
        ).map(\.id) == [desktopID, tabletID])
        #expect(ImageEditorLayerCompSearch.filtered(
            viewModel.document.layerComps,
            matching: "approved",
            scope: .name
        ).isEmpty)
        #expect(ImageEditorLayerCompSearch.filtered(
            viewModel.document.layerComps,
            matching: "approved",
            scope: .comment
        ).map(\.id) == [desktopID, tabletID])
        #expect(ImageEditorLayerCompSearch.filtered(
            viewModel.document.layerComps,
            matching: "desktop elite",
            scope: .name
        ).map(\.id) == [desktopID])
        #expect(ImageEditorLayerCompSearch.filtered(
            viewModel.document.layerComps,
            matching: "name:mobile",
            scope: .comment
        ).map(\.id) == [mobileID])
        #expect(ImageEditorLayerCompSearch.filtered(
            viewModel.document.layerComps,
            matching: "-review",
            scope: .comment
        ).map(\.id) == [desktopID, tabletID])
        var favoriteComps = viewModel.document.layerComps
        favoriteComps[0].isFavorite = true
        favoriteComps[2].isFavorite = true
        #expect(ImageEditorLayerCompSearch.filtered(
            favoriteComps,
            matching: "",
            favoritesOnly: true
        ).map(\.id) == [desktopID, tabletID])
        #expect(ImageEditorLayerCompSearch.filtered(
            favoriteComps,
            matching: "client",
            scope: .comment,
            favoritesOnly: true
        ).map(\.id) == [desktopID])
        #expect(ImageEditorLayerCompSearch.filtered(
            favoriteComps,
            matching: "review",
            scope: .comment,
            favoritesOnly: true
        ).isEmpty)
        #expect(ImageEditorLayerCompSearch.preferredResultID(
            in: favoriteComps,
            matching: "",
            favoritesOnly: true,
            selectedLayerCompID: mobileID
        ) == desktopID)
        #expect(ImageEditorLayerCompSearch.selectionTarget(
            direction: .previous,
            layerComps: favoriteComps,
            query: "",
            favoritesOnly: true,
            selectedLayerCompID: mobileID
        ) == tabletID)
        #expect(ImageEditorLayerCompSearch.filtered(
            viewModel.document.layerComps,
            matching: "-"
        ).map(\.id) == [desktopID, mobileID, tabletID])
        #expect(!ImageEditorLayerCompSearch.hasTerms("\"\" -"))
        #expect(!ImageEditorLayerCompSearch.hasTerms("name: comment:"))
        var quotedComp = try #require(viewModel.document.layerComps.first)
        quotedComp.id = UUID()
        quotedComp.name = "Review \"Alpha\""
        #expect(ImageEditorLayerCompSearch.filtered(
            [quotedComp],
            matching: "\"Review \\\"Alpha\\\"\""
        ).map(\.id) == [quotedComp.id])
        #expect(ImageEditorLayerCompSearch.preferredResultID(
            in: viewModel.document.layerComps,
            matching: "approved",
            selectedLayerCompID: mobileID
        ) == desktopID)
        #expect(ImageEditorLayerCompSearch.preferredResultID(
            in: viewModel.document.layerComps,
            matching: "approved",
            selectedLayerCompID: tabletID
        ) == tabletID)
        #expect(ImageEditorLayerCompSearch.preferredResultID(
            in: viewModel.document.layerComps,
            matching: "comment:handoff",
            selectedLayerCompID: mobileID
        ) == tabletID)
        #expect(ImageEditorLayerCompSearch.preferredResultID(
            in: viewModel.document.layerComps,
            matching: "   ",
            selectedLayerCompID: tabletID
        ) == nil)
        #expect(ImageEditorLayerCompSearch.filtered(
            viewModel.document.layerComps,
            matching: "   "
        ).map(\.id) == [desktopID, mobileID, tabletID])
        #expect(viewModel.layerCompNavigationTarget(
            .previous,
            matching: "approved"
        ) == tabletID)
        #expect(viewModel.layerCompNavigationTarget(
            .next,
            matching: "approved"
        ) == desktopID)
        #expect(viewModel.layerCompNavigationTarget(
            .next,
            matching: "missing"
        ) == nil)
        #expect(viewModel.layerCompNavigationTarget(
            .next,
            matching: "approved",
            scope: .name
        ) == nil)
        #expect(viewModel.layerCompNavigationTarget(
            .next,
            matching: "approved",
            scope: .comment
        ) == desktopID)
        #expect(viewModel.layerCompNavigationTarget(
            .next,
            matching: "",
            favoritesOnly: true
        ) == desktopID)
        #expect(!viewModel.applyNextLayerComp(matching: "missing"))
        #expect(try viewModel.projectData() == projectDataBeforeSearch)
        #expect(viewModel.document.history == historyBeforeSearch)
        #expect(viewModel.undoStack.count == undoCountBeforeSearch)
        #expect(viewModel.redoStack.count == redoCountBeforeSearch)

        #expect(viewModel.applyNextLayerComp(matching: "approved"))
        #expect(viewModel.document.selectedLayerCompID == desktopID)
        #expect(viewModel.document.layers.first { $0.id == layerID }?.isVisible == true)
        #expect(viewModel.applyNextLayerComp(matching: "approved"))
        #expect(viewModel.document.selectedLayerCompID == tabletID)
        #expect(viewModel.document.layers.first { $0.id == layerID }?.isVisible == true)
        let boundaryHistoryCount = viewModel.document.history.count
        #expect(!viewModel.applyNextLayerComp(matching: "approved"))
        #expect(viewModel.document.history.count == boundaryHistoryCount)
    }

    @Test
    func returnAppliesThePreferredLayerCompSearchResultWithoutEmptyTransactions() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemBlue, size: NSSize(width: 100, height: 80))
        ) { _ in }
        let layerID = try #require(viewModel.document.selectedLayerID)
        viewModel.addLayerComp(named: "Desktop Approved")
        let desktopID = try #require(viewModel.document.selectedLayerCompID)
        viewModel.toggleLayerVisibility(layerID)
        viewModel.addLayerComp(named: "Mobile Approved")
        let mobileID = try #require(viewModel.document.selectedLayerCompID)

        #expect(viewModel.applyPreferredLayerCompSearchResult(matching: "desktop approved"))
        #expect(viewModel.document.selectedLayerCompID == desktopID)
        #expect(viewModel.document.layers.first { $0.id == layerID }?.isVisible == true)

        viewModel.toggleLayerVisibility(layerID)
        #expect(viewModel.document.layers.first { $0.id == layerID }?.isVisible == false)
        #expect(viewModel.applyPreferredLayerCompSearchResult(matching: "approved"))
        #expect(viewModel.document.selectedLayerCompID == desktopID)
        #expect(viewModel.document.layers.first { $0.id == layerID }?.isVisible == true)

        let appliedHistoryCount = viewModel.document.history.count
        #expect(!viewModel.applyPreferredLayerCompSearchResult(matching: "approved"))
        #expect(viewModel.document.history.count == appliedHistoryCount)

        viewModel.selectLayerComp(mobileID)
        let projectData = try viewModel.projectData()
        let history = viewModel.document.history
        let undoCount = viewModel.undoStack.count
        let redoCount = viewModel.redoStack.count
        #expect(!viewModel.applyPreferredLayerCompSearchResult(matching: "missing"))
        #expect(!viewModel.applyPreferredLayerCompSearchResult(matching: "   "))
        #expect(try viewModel.projectData() == projectData)
        #expect(viewModel.document.history == history)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.redoStack.count == redoCount)
    }

    @Test
    func arrowKeysSelectAdjacentSearchResultsWithoutApplyingTheCanvas() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemPurple, size: NSSize(width: 100, height: 80))
        ) { _ in }
        let layerID = try #require(viewModel.document.selectedLayerID)
        viewModel.addLayerComp(named: "Desktop Approved")
        let desktopID = try #require(viewModel.document.selectedLayerCompID)
        viewModel.toggleLayerVisibility(layerID)
        viewModel.addLayerComp(named: "Tablet Approved")
        let tabletID = try #require(viewModel.document.selectedLayerCompID)
        viewModel.toggleLayerVisibility(layerID)
        viewModel.addLayerComp(named: "Mobile Draft")
        let mobileID = try #require(viewModel.document.selectedLayerCompID)
        let history = viewModel.document.history
        let undoCount = viewModel.undoStack.count
        let redoCount = viewModel.redoStack.count

        #expect(viewModel.selectAdjacentLayerCompSearchResult(.next, matching: "approved"))
        #expect(viewModel.document.selectedLayerCompID == desktopID)
        #expect(viewModel.document.layers.first { $0.id == layerID }?.isVisible == true)
        #expect(viewModel.selectAdjacentLayerCompSearchResult(.next, matching: "approved"))
        #expect(viewModel.document.selectedLayerCompID == tabletID)
        #expect(!viewModel.selectAdjacentLayerCompSearchResult(.next, matching: "approved"))
        #expect(viewModel.selectAdjacentLayerCompSearchResult(.previous, matching: "approved"))
        #expect(viewModel.document.selectedLayerCompID == desktopID)

        viewModel.selectLayerComp(mobileID)
        #expect(viewModel.selectAdjacentLayerCompSearchResult(.previous, matching: "approved"))
        #expect(viewModel.document.selectedLayerCompID == tabletID)
        #expect(!viewModel.selectAdjacentLayerCompSearchResult(.next, matching: "missing"))
        #expect(!viewModel.selectAdjacentLayerCompSearchResult(.next, matching: "   "))
        #expect(viewModel.document.layers.first { $0.id == layerID }?.isVisible == true)
        #expect(viewModel.document.history == history)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.redoStack.count == redoCount)
    }

    @Test
    func nativeLayerSearchFieldConsumesOnlyConfiguredSubmitAndCancelCommands() {
        var text = "approved"
        var submitCount = 0
        var cancelCount = 0
        var previousCount = 0
        var nextCount = 0
        let coordinator = ImageEditorLayerSearchField.Coordinator(
            text: Binding(
                get: { text },
                set: { text = $0 }
            ),
            onSubmit: { submitCount += 1 },
            onCancel: { cancelCount += 1 },
            onMovePrevious: { previousCount += 1 },
            onMoveNext: { nextCount += 1 }
        )
        let field = NSTextField(string: text)
        let textView = NSTextView()

        #expect(coordinator.control(
            field,
            textView: textView,
            doCommandBy: #selector(NSResponder.insertNewline(_:))
        ))
        #expect(submitCount == 1)
        #expect(coordinator.control(
            field,
            textView: textView,
            doCommandBy: #selector(NSResponder.cancelOperation(_:))
        ))
        #expect(cancelCount == 1)
        #expect(coordinator.control(
            field,
            textView: textView,
            doCommandBy: #selector(NSResponder.moveUp(_:))
        ))
        #expect(previousCount == 1)
        #expect(coordinator.control(
            field,
            textView: textView,
            doCommandBy: #selector(NSResponder.moveDown(_:))
        ))
        #expect(nextCount == 1)
        #expect(!coordinator.control(
            field,
            textView: textView,
            doCommandBy: #selector(NSResponder.moveLeft(_:))
        ))

        let passiveCoordinator = ImageEditorLayerSearchField.Coordinator(
            text: .constant(""),
            onSubmit: nil,
            onCancel: nil
        )
        #expect(!passiveCoordinator.control(
            field,
            textView: textView,
            doCommandBy: #selector(NSResponder.insertNewline(_:))
        ))
        #expect(!passiveCoordinator.control(
            field,
            textView: textView,
            doCommandBy: #selector(NSResponder.cancelOperation(_:))
        ))
        #expect(!passiveCoordinator.control(
            field,
            textView: textView,
            doCommandBy: #selector(NSResponder.moveUp(_:))
        ))
        #expect(!passiveCoordinator.control(
            field,
            textView: textView,
            doCommandBy: #selector(NSResponder.moveDown(_:))
        ))
    }

    @Test
    func appliedLayerCompMarkerTracksRestorableStateWithoutCreatingTransactions() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemBlue, size: NSSize(width: 100, height: 80))
        ) { _ in }
        viewModel.addLayer()
        let detailID = try #require(viewModel.document.selectedLayerID)
        viewModel.addLayerComp(named: "Baseline")
        let compID = try #require(viewModel.document.selectedLayerCompID)

        let projectData = try viewModel.projectData()
        let history = viewModel.document.history
        let undoCount = viewModel.undoStack.count
        let redoCount = viewModel.redoStack.count
        #expect(viewModel.isLayerCompApplied(compID))
        #expect(viewModel.isLayerCompApplied(compID))
        #expect(try viewModel.projectData() == projectData)
        #expect(viewModel.document.history == history)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.redoStack.count == redoCount)

        viewModel.toggleLayerVisibility(detailID)
        #expect(!viewModel.isLayerCompApplied(compID))
        #expect(viewModel.applyLayerComp(compID))
        #expect(viewModel.isLayerCompApplied(compID))

        let otherLayerID = try #require(viewModel.document.layers.first { $0.id != detailID }?.id)
        viewModel.selectLayer(otherLayerID)
        #expect(!viewModel.isLayerCompApplied(compID))
        #expect(viewModel.applyLayerComp(compID))
        #expect(viewModel.isLayerCompApplied(compID))

        #expect(viewModel.setLayerCompCapturesVisibility(compID, enabled: false))
        viewModel.toggleLayerVisibility(detailID)
        #expect(viewModel.isLayerCompApplied(compID))

        #expect(viewModel.setLayerCompCapturesPosition(compID, enabled: false))
        let detailIndex = try #require(viewModel.document.layers.firstIndex { $0.id == detailID })
        viewModel.document.layers[detailIndex].frame.origin.x += 7
        #expect(viewModel.isLayerCompApplied(compID))

        #expect(viewModel.setLayerCompCapturesAppearance(compID, enabled: false))
        viewModel.document.layers[detailIndex].blendMode = .multiply
        #expect(viewModel.isLayerCompApplied(compID))

        viewModel.document.layers[detailIndex].opacity = 0.42
        #expect(!viewModel.isLayerCompApplied(compID))
        #expect(viewModel.applyLayerComp(compID))
        #expect(viewModel.isLayerCompApplied(compID))

        viewModel.document.layers.swapAt(0, 1)
        #expect(!viewModel.isLayerCompApplied(compID))
        #expect(viewModel.applyLayerComp(compID))
        #expect(viewModel.isLayerCompApplied(compID))

        viewModel.document.layers.removeAll { $0.id == detailID }
        #expect(!viewModel.isLayerCompApplied(compID))
    }

    @Test
    func reapplyingCurrentLayerCompIsANoOpAndPreservesRedo() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemIndigo, size: NSSize(width: 100, height: 80))
        ) { _ in }
        let layerID = try #require(viewModel.document.selectedLayerID)
        viewModel.addLayerComp(named: "Baseline")
        let compID = try #require(viewModel.document.selectedLayerCompID)

        viewModel.toggleLayerVisibility(layerID)
        viewModel.undo()
        #expect(viewModel.isLayerCompApplied(compID))
        #expect(!viewModel.canApplySelectedLayerComp)
        #expect(viewModel.canRedo)
        #expect(viewModel.lastDocumentLayerCompState == nil)
        let projectData = try viewModel.projectData()
        let history = viewModel.document.history
        let undoCount = viewModel.undoStack.count
        let redoCount = viewModel.redoStack.count

        #expect(!viewModel.applyLayerComp(compID))
        #expect(try viewModel.projectData() == projectData)
        #expect(viewModel.document.history == history)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.redoStack.count == redoCount)
        #expect(viewModel.canRedo)
        #expect(viewModel.lastDocumentLayerCompState == nil)

        viewModel.redo()
        #expect(viewModel.canApplySelectedLayerComp)
        #expect(viewModel.applyLayerComp(compID))
        #expect(viewModel.isLayerCompApplied(compID))
        #expect(!viewModel.canApplySelectedLayerComp)
        let appliedHistoryCount = viewModel.document.history.count
        #expect(!viewModel.applyLayerComp(compID))
        #expect(viewModel.document.history.count == appliedHistoryCount)
    }

    @Test
    func layerCompContextOperationsUseTheExplicitRowInsteadOfTheCurrentSelection() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemBlue, size: NSSize(width: 100, height: 80))
        ) { _ in }
        let layerID = try #require(viewModel.document.selectedLayerID)

        viewModel.addLayerComp(named: "Visible")
        let visibleCompID = try #require(viewModel.document.selectedLayerCompID)
        viewModel.toggleLayerVisibility(layerID)
        viewModel.addLayerComp(named: "Hidden")
        let hiddenCompID = try #require(viewModel.document.selectedLayerCompID)

        let duplicated = try #require(viewModel.duplicateLayerComp(visibleCompID))
        #expect(viewModel.document.layerComps.map(\.id) == [
            visibleCompID,
            duplicated.id,
            hiddenCompID
        ])
        #expect(duplicated.layerStates == viewModel.document.layerComps[0].layerStates)
        #expect(duplicated.name == L10n.format("imageEditor.layerComp.copyName", "Visible"))
        #expect(viewModel.document.selectedLayerCompID == duplicated.id)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerCompDuplicate"))

        viewModel.selectLayerComp(hiddenCompID)
        let historyCount = viewModel.document.history.count
        let compIDs = viewModel.document.layerComps.map(\.id)
        #expect(viewModel.duplicateLayerComp(UUID()) == nil)
        #expect(viewModel.document.layerComps.map(\.id) == compIDs)
        #expect(viewModel.document.selectedLayerCompID == hiddenCompID)
        #expect(viewModel.document.history.count == historyCount)

        viewModel.deleteLayerComp(visibleCompID)
        #expect(!viewModel.document.layerComps.contains { $0.id == visibleCompID })
        #expect(viewModel.document.selectedLayerCompID == hiddenCompID)
    }

    @Test
    func layerCompRowsExposeTheSameExplicitContextActionsAsTheirInlineControls() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorLayerPanel.swift"),
            encoding: .utf8
        )
        let contextStart = try #require(source.range(
            of: "private func layerCompContextMenu(_ comp: ImageEditorLayerComp)"
        ))
        let contextEnd = try #require(source.range(
            of: "private func layerCompIconButton",
            range: contextStart.upperBound..<source.endIndex
        ))
        let contextSource = source[contextStart.lowerBound..<contextEnd.lowerBound]

        #expect(source.contains(".contextMenu {\n            layerCompContextMenu(comp)"))
        #expect(source.contains("viewModel.isLayerCompApplied(comp.id)"))
        #expect(source.components(
            separatedBy: ".help(viewModel.layerCompApplyHelp(for: comp.id))"
        ).count - 1 == 2)
        #expect(source.contains("imageEditor.layerComp.currentlyApplied"))
        #expect(source.contains("image-editor-layer-comp-applied-"))
        #expect(source.components(separatedBy: ".disabled(isApplied)").count == 3)
        #expect(source.contains("imageEditor.layerComp.searchResultsCount"))
        #expect(source.contains("image-editor-layer-comp-search-results-count"))
        #expect(source.contains("imageEditor.layerComp.searchSyntaxHelp"))
        #expect(source.contains("ImageEditorLayerCompSearchScope.allCases"))
        #expect(source.contains("imageEditor.layerComp.searchScopeHelp"))
        #expect(source.contains("image-editor-layer-comp-search-scope"))
        #expect(source.contains("scope: layerCompSearchScope"))
        #expect(source.contains("favoritesOnly: showsFavoriteLayerCompsOnly"))
        #expect(source.contains("imageEditor.action.layerCompFavoritesOnly"))
        #expect(source.contains("image-editor-layer-comp-favorites-only"))
        #expect(source.contains("viewModel.setLayerCompFavorite("))
        #expect(source.contains("image-editor-layer-comp-favorite-\\(comp.id.uuidString)"))
        #expect(source.contains("viewModel.applyPreferredLayerCompSearchResult("))
        #expect(source.contains("#selector(NSResponder.insertNewline(_:))"))
        #expect(source.contains("#selector(NSResponder.cancelOperation(_:))"))
        #expect(source.contains("viewModel.selectAdjacentLayerCompSearchResult("))
        #expect(source.contains("#selector(NSResponder.moveUp(_:))"))
        #expect(source.contains("#selector(NSResponder.moveDown(_:))"))
        #expect(source.contains("ScrollViewReader { proxy in"))
        #expect(source.contains("proxy.scrollTo(selectedID, anchor: .center)"))
        #expect(contextSource.contains("viewModel.applyLayerComp(comp.id)"))
        #expect(contextSource.contains("viewModel.updateLayerComp(comp.id)"))
        #expect(contextSource.contains("viewModel.duplicateLayerComp(comp.id)"))
        #expect(contextSource.contains("viewModel.setLayerCompFavorite(comp.id"))
        #expect(contextSource.contains("viewModel.moveLayerCompToTop(comp.id)"))
        #expect(contextSource.contains("viewModel.moveLayerCompUp(comp.id)"))
        #expect(contextSource.contains("viewModel.moveLayerCompDown(comp.id)"))
        #expect(contextSource.contains("viewModel.moveLayerCompToBottom(comp.id)"))
        #expect(contextSource.contains("viewModel.canMoveLayerCompToTop(comp.id)"))
        #expect(contextSource.contains("viewModel.canMoveLayerCompToBottom(comp.id)"))
        #expect(contextSource.contains("viewModel.deleteLayerComp(comp.id)"))
        #expect(contextSource.contains("Button(role: .destructive)"))

        #expect(source.contains("layerCompDraggableRow(comp)"))
        #expect(source.contains("layerCompDropBand(comp, placement: .above)"))
        #expect(source.contains("layerCompDropBand(comp, placement: .below)"))
        #expect(source.contains("ImageEditorPanelListDropDelegate("))
        #expect(source.contains("handleLayerCompDrop(payload, on: comp, placement: placement)"))
        #expect(source.contains("NSEvent.modifierFlags"))
        #expect(source.contains(".contains(.option) ? .copy : .move"))
        #expect(source.contains("payload.serialized as NSString"))
        #expect(source.contains("ImageEditorLayerCompDragPayload.parse(serializedPayload)"))
        #expect(source.contains("viewModel.moveLayerComp(payload.layerCompID, toIndex: destinationIndex)"))
        #expect(source.contains("viewModel.duplicateLayerComp("))
        #expect(source.contains("payload.layerCompID,"))
        #expect(source.contains("toIndex: destinationIndex"))
        #expect(source.contains("imageEditor.layerComp.commentPlaceholder"))
        #expect(source.contains("text: layerCompCommentBinding(comp)"))
        #expect(source.contains("commitLayerCompCommentDraft(comp)"))
        #expect(source.contains("viewModel.updateLayerCompComment("))
        #expect(source.contains("if !comp.capturesVisibility"))
        #expect(source.contains("imageEditor.layerComp.visibilityNotCaptured"))
        #expect(source.contains("imageEditor.action.layerCompCaptureVisibility"))
        #expect(source.contains("viewModel.setLayerCompCapturesVisibility("))
        #expect(source.contains("if !comp.capturesPosition"))
        #expect(source.contains("imageEditor.layerComp.positionNotCaptured"))
        #expect(source.contains("imageEditor.action.layerCompCapturePosition"))
        #expect(source.contains("viewModel.setLayerCompCapturesPosition("))
        #expect(source.contains("if !comp.capturesAppearance"))
        #expect(source.contains("imageEditor.layerComp.appearanceNotCaptured"))
        #expect(source.contains("imageEditor.action.layerCompCaptureAppearance"))
        #expect(source.contains("viewModel.setLayerCompCapturesAppearance("))
        #expect(source.contains("viewModel.addLayerComp(captureOptions: layerCompCreationOptions)"))
        #expect(source.contains("imageEditor.action.layerCompCreationOptions"))
        #expect(source.contains("isOn: $defaultLayerCompCapturesVisibility"))
        #expect(source.contains("isOn: $defaultLayerCompCapturesPosition"))
        #expect(source.contains("isOn: $defaultLayerCompCapturesAppearance"))
        #expect(source.contains("viewModel.restoreLastDocumentLayerCompState()"))
        #expect(source.contains("viewModel.canRestoreLastDocumentLayerCompState"))
        #expect(source.contains("image-editor-layer-comp-last-document-state"))
        #expect(source.contains("viewModel.layerCompHasWarning(comp)"))
        #expect(source.contains("viewModel.showLayerCompWarning(comp.id)"))
        #expect(source.contains("viewModel.clearLayerCompWarning(comp.id)"))
        #expect(source.contains("viewModel.clearAllLayerCompWarnings()"))
        #expect(source.contains("image-editor-layer-comp-warning-\\(comp.id.uuidString)"))
        #expect(source.contains("viewModel.applyPreviousLayerComp("))
        #expect(source.contains("viewModel.applyNextLayerComp("))
        #expect(source.contains("ImageEditorLayerCompSearch.filtered("))
        #expect(source.contains("imageEditor.layerComp.searchPlaceholder"))
        #expect(source.contains("imageEditor.layerComp.noSearchResults"))
        #expect(source.contains("imageEditor.action.layerCompSearchClear"))
        #expect(source.contains("image-editor-layer-comp-search-field"))
        #expect(source.contains("image-editor-layer-comp-previous"))
        #expect(source.contains("image-editor-layer-comp-next"))

        let viewSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        #expect(viewSource.contains(
            "@State var targetedLayerCompDropTarget: ImageEditorLayerCompDropTarget?"
        ))
        #expect(viewSource.contains(
            "@State var layerCompCommentDrafts: [UUID: String] = [:]"
        ))
        #expect(viewSource.contains("@State var layerCompSearchQuery = \"\""))
        #expect(viewSource.contains(
            "@State var layerCompSearchScope: ImageEditorLayerCompSearchScope = .all"
        ))
        #expect(viewSource.contains("@State var showsFavoriteLayerCompsOnly = false"))
        #expect(viewSource.contains(
            "@AppStorage(ImageEditorLayerCompCaptureDefaults.visibilityKey)"
        ))
        #expect(viewSource.contains(
            "@AppStorage(ImageEditorLayerCompCaptureDefaults.positionKey)"
        ))
        #expect(viewSource.contains(
            "@AppStorage(ImageEditorLayerCompCaptureDefaults.appearanceKey)"
        ))
        let menuSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        #expect(menuSource.components(
            separatedBy: ".help(viewModel.layerCompApplyHelp(for: viewModel.selectedLayerComp?.id))"
        ).count - 1 == 2)
        #expect(menuSource.components(
            separatedBy: "viewModel.addLayerComp(captureOptions: .storedDefaults)"
        ).count - 1 == 2)
        #expect(menuSource.components(
            separatedBy: "viewModel.restoreLastDocumentLayerCompState()"
        ).count - 1 == 2)
        #expect(menuSource.components(
            separatedBy: "viewModel.clearLayerCompWarning(id)"
        ).count - 1 == 2)
        #expect(menuSource.components(
            separatedBy: "viewModel.clearAllLayerCompWarnings()"
        ).count - 1 == 2)
        #expect(menuSource.components(
            separatedBy: "viewModel.applyPreviousLayerComp()"
        ).count - 1 == 2)
        #expect(menuSource.components(
            separatedBy: "viewModel.applyNextLayerComp()"
        ).count - 1 == 2)
        #expect(menuSource.components(
            separatedBy: "viewModel.toggleSelectedLayerCompFavorite()"
        ).count - 1 == 2)
        #expect(menuSource.components(
            separatedBy: "viewModel.applyPreviousFavoriteLayerComp()"
        ).count - 1 == 2)
        #expect(menuSource.components(
            separatedBy: "viewModel.applyNextFavoriteLayerComp()"
        ).count - 1 == 2)
        #expect(menuSource.components(
            separatedBy: "viewModel.canSelectPreviousFavoriteLayerComp"
        ).count - 1 == 2)
        #expect(menuSource.components(
            separatedBy: "viewModel.canSelectNextFavoriteLayerComp"
        ).count - 1 == 2)
        let viewModelSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorViewModel.swift"),
            encoding: .utf8
        )
        #expect(viewModelSource.contains(
            "@Published var lastDocumentLayerCompState: ImageEditorLayerComp?"
        ))
        #expect(viewModelSource.components(
            separatedBy: "lastDocumentLayerCompState = nil"
        ).count - 1 >= 2)
    }

    @Test
    func layerCompDropGeometryAccountsForRemovalAndUsesTheSameAtomicMove() throws {
        #expect(ImageEditorLayerCompDropGeometry.destinationIndex(
            sourceIndex: 0,
            targetIndex: 2,
            placement: .above,
            count: 4
        ) == 1)
        #expect(ImageEditorLayerCompDropGeometry.destinationIndex(
            sourceIndex: 0,
            targetIndex: 2,
            placement: .below,
            count: 4
        ) == 2)
        #expect(ImageEditorLayerCompDropGeometry.destinationIndex(
            sourceIndex: 3,
            targetIndex: 1,
            placement: .above,
            count: 4
        ) == 1)
        #expect(ImageEditorLayerCompDropGeometry.destinationIndex(
            sourceIndex: 3,
            targetIndex: 1,
            placement: .below,
            count: 4
        ) == 2)
        #expect(ImageEditorLayerCompDropGeometry.destinationIndex(
            sourceIndex: 2,
            targetIndex: 2,
            placement: .above,
            count: 4
        ) == nil)
        #expect(ImageEditorLayerCompDropGeometry.destinationIndex(
            sourceIndex: -1,
            targetIndex: 2,
            placement: .above,
            count: 4
        ) == nil)

        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemPurple, size: NSSize(width: 100, height: 80))
        ) { _ in }
        for name in ["First", "Second", "Third", "Fourth"] {
            viewModel.addLayerComp(named: name)
        }
        let ids = viewModel.document.layerComps.map(\.id)
        let historyCount = viewModel.document.history.count
        let destinationIndex = try #require(ImageEditorLayerCompDropGeometry.destinationIndex(
            sourceIndex: 0,
            targetIndex: 2,
            placement: .below,
            count: 4
        ))

        #expect(viewModel.moveLayerComp(ids[0], toIndex: destinationIndex))
        #expect(viewModel.document.layerComps.map(\.id) == [ids[1], ids[2], ids[0], ids[3]])
        #expect(viewModel.document.selectedLayerCompID == ids[0])
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerCompMoved", "First"))

        viewModel.undo()
        #expect(viewModel.document.layerComps.map(\.id) == ids)
    }

    @Test
    func optionDragPayloadDuplicatesAtTheDropBandInOneUndoStep() throws {
        let sourceID = UUID()
        let movePayload = ImageEditorLayerCompDragPayload(
            layerCompID: sourceID,
            operation: .move
        )
        let copyPayload = ImageEditorLayerCompDragPayload(
            layerCompID: sourceID,
            operation: .copy
        )
        #expect(ImageEditorLayerCompDragPayload.parse(movePayload.serialized) == movePayload)
        #expect(ImageEditorLayerCompDragPayload.parse(copyPayload.serialized) == copyPayload)
        #expect(ImageEditorLayerCompDragPayload.parse(sourceID.uuidString) == nil)
        #expect(ImageEditorLayerCompDragPayload.parse("xomo-layer-comp:copy:not-a-uuid") == nil)

        #expect(ImageEditorLayerCompDropGeometry.copyInsertionIndex(
            targetIndex: 2,
            placement: .above,
            count: 4
        ) == 2)
        #expect(ImageEditorLayerCompDropGeometry.copyInsertionIndex(
            targetIndex: 2,
            placement: .below,
            count: 4
        ) == 3)
        #expect(ImageEditorLayerCompDropGeometry.copyInsertionIndex(
            targetIndex: 4,
            placement: .below,
            count: 4
        ) == nil)

        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemIndigo, size: NSSize(width: 100, height: 80))
        ) { _ in }
        for name in ["First", "Second", "Third", "Fourth"] {
            viewModel.addLayerComp(named: name)
        }
        let originalComps = viewModel.document.layerComps
        let historyCount = viewModel.document.history.count
        let destinationIndex = try #require(ImageEditorLayerCompDropGeometry.copyInsertionIndex(
            targetIndex: 2,
            placement: .below,
            count: originalComps.count
        ))

        let duplicate = try #require(viewModel.duplicateLayerComp(
            originalComps[0].id,
            toIndex: destinationIndex
        ))
        #expect(viewModel.document.layerComps.map(\.id) == [
            originalComps[0].id,
            originalComps[1].id,
            originalComps[2].id,
            duplicate.id,
            originalComps[3].id
        ])
        #expect(duplicate.layerStates == originalComps[0].layerStates)
        #expect(duplicate.name == L10n.format("imageEditor.layerComp.copyName", "First"))
        #expect(viewModel.document.selectedLayerCompID == duplicate.id)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerCompDuplicate"))

        viewModel.undo()
        #expect(viewModel.document.layerComps == originalComps)
        #expect(viewModel.canRedo)
        let historyAfterUndo = viewModel.document.history
        #expect(viewModel.duplicateLayerComp(originalComps[0].id, toIndex: -1) == nil)
        #expect(viewModel.document.history == historyAfterUndo)
        #expect(viewModel.canRedo)
    }

    @Test
    func layerCompCommentIsAtomicCopiedAndPreservedBySnapshotUpdates() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemTeal, size: NSSize(width: 100, height: 80))
        ) { _ in }
        viewModel.addLayerComp(named: "Review")
        let compID = try #require(viewModel.document.selectedLayerCompID)
        let historyCount = viewModel.document.history.count

        #expect(viewModel.updateLayerCompComment(compID, to: "  Mobile handoff  "))
        #expect(viewModel.document.layerComps.first?.comment == "Mobile handoff")
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerCompComment"))
        #expect(viewModel.statusText == L10n.format(
            "imageEditor.status.layerCompCommentUpdated",
            "Review"
        ))

        viewModel.undo()
        #expect(viewModel.document.layerComps.first?.comment.isEmpty == true)
        #expect(viewModel.canRedo)
        let historyAfterUndo = viewModel.document.history
        #expect(!viewModel.updateLayerCompComment(compID, to: "  "))
        #expect(viewModel.document.history == historyAfterUndo)
        #expect(viewModel.canRedo)
        viewModel.redo()

        let duplicate = try #require(viewModel.duplicateLayerComp(compID))
        #expect(duplicate.comment == "Mobile handoff")
        viewModel.toggleLayerVisibility(try #require(viewModel.document.selectedLayerID))
        viewModel.updateLayerComp(compID)
        #expect(viewModel.document.layerComps.first { $0.id == compID }?.comment == "Mobile handoff")

        #expect(viewModel.updateLayerCompComment(compID, to: ""))
        #expect(viewModel.statusText == L10n.format(
            "imageEditor.status.layerCompCommentCleared",
            "Review"
        ))
    }

    @Test
    func updatingAnUnchangedLayerCompDoesNotCreateHistory() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "layer-comp-noop.png",
            image: testImage(color: .systemBlue, size: NSSize(width: 100, height: 80))
        ) { _ in }
        viewModel.addLayerComp(named: "Baseline")
        let compID = try #require(viewModel.document.selectedLayerCompID)
        let history = viewModel.document.history
        let undoCount = viewModel.undoStack.count
        let redoCount = viewModel.redoStack.count

        viewModel.updateLayerComp(compID)

        #expect(viewModel.document.history == history)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.redoStack.count == redoCount)
        #expect(viewModel.statusText == L10n.format(
            "imageEditor.status.layerCompUnchanged",
            "Baseline"
        ))
    }

    @Test
    func applyingAnAlreadyAppliedLayerCompReportsNoOpWithoutChangingHistory() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "layer-comp-applied-noop.png",
            image: testImage(color: .systemBlue, size: NSSize(width: 100, height: 80))
        ) { _ in }
        viewModel.addLayerComp(named: "Baseline")
        let compID = try #require(viewModel.document.selectedLayerCompID)
        #expect(viewModel.updateLayerCompComment(compID, to: "Temporary"))
        viewModel.undo()

        let history = viewModel.document.history
        let undoCount = viewModel.undoStack.count
        let redoCount = viewModel.redoStack.count
        let lastDocumentState = viewModel.lastDocumentLayerCompState

        #expect(!viewModel.applyLayerComp(compID))

        #expect(viewModel.document.history == history)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.redoStack.count == redoCount)
        #expect(viewModel.lastDocumentLayerCompState == lastDocumentState)
        #expect(viewModel.statusText == L10n.format(
            "imageEditor.status.layerCompAlreadyApplied",
            "Baseline"
        ))
    }

    @Test
    func appliedLayerCompExposesItsDisabledActionReason() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "layer-comp-help.png",
            image: testImage(color: .systemBlue, size: NSSize(width: 100, height: 80))
        ) { _ in }
        viewModel.addLayerComp(named: "Baseline")
        let compID = try #require(viewModel.document.selectedLayerCompID)

        #expect(viewModel.layerCompApplyHelp(for: compID) == L10n.text(
            "imageEditor.layerComp.currentlyApplied"
        ))
        #expect(viewModel.layerCompApplyHelp(for: nil) == L10n.text(
            "imageEditor.action.layerCompApply"
        ))

        let layerID = try #require(viewModel.document.selectedLayerID)
        viewModel.toggleLayerVisibility(layerID)
        #expect(viewModel.layerCompApplyHelp(for: compID) == L10n.text(
            "imageEditor.action.layerCompApply"
        ))
    }

    @Test
    func layerCompFavoritesAreAtomicSearchableAndPersisted() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemYellow, size: NSSize(width: 100, height: 80))
        ) { _ in }
        viewModel.addLayerComp(named: "Desktop Approved")
        let desktopID = try #require(viewModel.document.selectedLayerCompID)
        viewModel.addLayerComp(named: "Mobile Draft")
        let historyCount = viewModel.document.history.count

        #expect(viewModel.setLayerCompFavorite(desktopID, isFavorite: true))
        #expect(viewModel.document.layerComps.first { $0.id == desktopID }?.isFavorite == true)
        #expect(viewModel.document.selectedLayerCompID == desktopID)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text(
            "imageEditor.history.layerCompFavoriteAdd"
        ))
        #expect(viewModel.statusText == L10n.format(
            "imageEditor.status.layerCompFavoriteAdded",
            "Desktop Approved"
        ))

        viewModel.undo()
        #expect(viewModel.document.layerComps.first { $0.id == desktopID }?.isFavorite == false)
        #expect(viewModel.canRedo)
        let historyAfterUndo = viewModel.document.history
        #expect(!viewModel.setLayerCompFavorite(desktopID, isFavorite: false))
        #expect(viewModel.document.history == historyAfterUndo)
        #expect(viewModel.canRedo)
        viewModel.redo()

        let duplicate = try #require(viewModel.duplicateLayerComp(desktopID))
        #expect(duplicate.isFavorite)
        viewModel.updateLayerComp(desktopID)
        #expect(viewModel.document.selectedLayerCompID == duplicate.id)
        #expect(viewModel.document.layerComps.first { $0.id == desktopID }?.isFavorite == true)
        #expect(ImageEditorLayerCompSearch.filtered(
            viewModel.document.layerComps,
            matching: "desktop",
            favoritesOnly: true
        ).map(\.id) == [desktopID, duplicate.id])
        viewModel.selectLayerComp(desktopID)
        #expect(!viewModel.canSelectPreviousFavoriteLayerComp)
        #expect(viewModel.canSelectNextFavoriteLayerComp)
        #expect(viewModel.applyNextFavoriteLayerComp())
        #expect(viewModel.document.selectedLayerCompID == duplicate.id)
        #expect(viewModel.canSelectPreviousFavoriteLayerComp)
        #expect(!viewModel.canSelectNextFavoriteLayerComp)
        let boundaryHistoryCount = viewModel.document.history.count
        #expect(!viewModel.applyNextFavoriteLayerComp())
        #expect(viewModel.document.history.count == boundaryHistoryCount)
        #expect(viewModel.applyPreviousFavoriteLayerComp())
        #expect(viewModel.document.selectedLayerCompID == desktopID)

        let data = try viewModel.projectData()
        let restored = ImageEditorViewModel(
            sourceName: "empty.png",
            image: testImage(color: .black, size: NSSize(width: 12, height: 12))
        ) { _ in }
        try restored.loadProjectData(data)
        #expect(restored.document.layerComps.filter(\.isFavorite).map(\.id) == [
            desktopID,
            duplicate.id
        ])

        #expect(viewModel.setLayerCompFavorite(desktopID, isFavorite: false))
        #expect(viewModel.document.history.last?.title == L10n.text(
            "imageEditor.history.layerCompFavoriteRemove"
        ))
        #expect(viewModel.statusText == L10n.format(
            "imageEditor.status.layerCompFavoriteRemoved",
            "Desktop Approved"
        ))
        #expect(!viewModel.isSelectedLayerCompFavorite)
        #expect(viewModel.toggleSelectedLayerCompFavorite())
        #expect(viewModel.isSelectedLayerCompFavorite)
        #expect(viewModel.toggleSelectedLayerCompFavorite())
        #expect(!viewModel.isSelectedLayerCompFavorite)
        #expect(!viewModel.setLayerCompFavorite(UUID(), isFavorite: true))
        viewModel.document.selectedLayerCompID = nil
        #expect(!viewModel.canToggleSelectedLayerCompFavorite)
        #expect(!viewModel.toggleSelectedLayerCompFavorite())
    }

    @Test
    func layerCompVisibilityCaptureCanBeDisabledWithoutChangingCurrentVisibility() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemGreen, size: NSSize(width: 80, height: 60))
        ) { _ in }
        let layerID = try #require(viewModel.document.selectedLayerID)
        let originalFrame = try #require(viewModel.document.layers.first?.frame)
        viewModel.addLayerComp(named: "Position only")
        let compID = try #require(viewModel.document.selectedLayerCompID)
        let historyCount = viewModel.document.history.count

        #expect(viewModel.setLayerCompCapturesVisibility(compID, enabled: false))
        #expect(viewModel.document.layerComps.first?.capturesVisibility == false)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text(
            "imageEditor.history.layerCompCaptureVisibility"
        ))
        #expect(viewModel.statusText == L10n.format(
            "imageEditor.status.layerCompCaptureVisibilityDisabled",
            "Position only"
        ))

        viewModel.undo()
        #expect(viewModel.document.layerComps.first?.capturesVisibility == true)
        #expect(viewModel.canRedo)
        let historyAfterUndo = viewModel.document.history
        #expect(!viewModel.setLayerCompCapturesVisibility(compID, enabled: true))
        #expect(viewModel.document.history == historyAfterUndo)
        #expect(viewModel.canRedo)
        viewModel.redo()

        let duplicate = try #require(viewModel.duplicateLayerComp(compID))
        #expect(duplicate.capturesVisibility == false)
        viewModel.undo()
        let layerIndex = try #require(viewModel.document.layers.firstIndex { $0.id == layerID })
        viewModel.document.layers[layerIndex].isVisible = false
        viewModel.document.layers[layerIndex].frame.origin.x += 17
        viewModel.applyLayerComp(compID)
        #expect(viewModel.document.layers[layerIndex].isVisible == false)
        #expect(viewModel.document.layers[layerIndex].frame == originalFrame)

        viewModel.updateLayerComp(compID)
        #expect(viewModel.document.layerComps.first?.capturesVisibility == false)
    }

    @Test
    func layerCompPositionCaptureCanBeDisabledWithoutChangingCurrentFrame() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemPink, size: NSSize(width: 80, height: 60))
        ) { _ in }
        let layerID = try #require(viewModel.document.selectedLayerID)
        viewModel.addLayerComp(named: "Appearance only")
        let compID = try #require(viewModel.document.selectedLayerCompID)
        let historyCount = viewModel.document.history.count

        #expect(viewModel.setLayerCompCapturesPosition(compID, enabled: false))
        #expect(viewModel.document.layerComps.first?.capturesPosition == false)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text(
            "imageEditor.history.layerCompCapturePosition"
        ))
        #expect(viewModel.statusText == L10n.format(
            "imageEditor.status.layerCompCapturePositionDisabled",
            "Appearance only"
        ))

        viewModel.undo()
        #expect(viewModel.document.layerComps.first?.capturesPosition == true)
        #expect(viewModel.canRedo)
        let historyAfterUndo = viewModel.document.history
        #expect(!viewModel.setLayerCompCapturesPosition(compID, enabled: true))
        #expect(viewModel.document.history == historyAfterUndo)
        #expect(viewModel.canRedo)
        viewModel.redo()

        let duplicate = try #require(viewModel.duplicateLayerComp(compID))
        #expect(duplicate.capturesPosition == false)
        viewModel.undo()
        let layerIndex = try #require(viewModel.document.layers.firstIndex { $0.id == layerID })
        viewModel.document.layers[layerIndex].frame.origin = CGPoint(x: 23, y: 17)
        let movedFrame = viewModel.document.layers[layerIndex].frame
        viewModel.document.layers[layerIndex].opacity = 0.35
        viewModel.applyLayerComp(compID)
        #expect(viewModel.document.layers[layerIndex].frame == movedFrame)
        #expect(viewModel.document.layers[layerIndex].opacity == 1)

        viewModel.updateLayerComp(compID)
        #expect(viewModel.document.layerComps.first?.capturesPosition == false)
    }

    @Test
    func layerCompAppearanceCaptureCanBeDisabledWithoutChangingStyleOrBlendMode() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemCyan, size: NSSize(width: 80, height: 60))
        ) { _ in }
        let layerID = try #require(viewModel.document.selectedLayerID)
        let originalFrame = try #require(viewModel.document.layers.first?.frame)
        viewModel.addLayerComp(named: "Layout only")
        let compID = try #require(viewModel.document.selectedLayerCompID)
        let historyCount = viewModel.document.history.count

        #expect(viewModel.setLayerCompCapturesAppearance(compID, enabled: false))
        #expect(viewModel.document.layerComps.first?.capturesAppearance == false)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text(
            "imageEditor.history.layerCompCaptureAppearance"
        ))
        #expect(viewModel.statusText == L10n.format(
            "imageEditor.status.layerCompCaptureAppearanceDisabled",
            "Layout only"
        ))

        viewModel.undo()
        #expect(viewModel.document.layerComps.first?.capturesAppearance == true)
        #expect(viewModel.canRedo)
        let historyAfterUndo = viewModel.document.history
        #expect(!viewModel.setLayerCompCapturesAppearance(compID, enabled: true))
        #expect(viewModel.document.history == historyAfterUndo)
        #expect(viewModel.canRedo)
        viewModel.redo()

        let duplicate = try #require(viewModel.duplicateLayerComp(compID))
        #expect(duplicate.capturesAppearance == false)
        viewModel.undo()
        let layerIndex = try #require(viewModel.document.layers.firstIndex { $0.id == layerID })
        viewModel.document.layers[layerIndex].style.strokeEnabled = true
        viewModel.document.layers[layerIndex].style.strokeWidth = 9
        viewModel.document.layers[layerIndex].blendMode = .multiply
        viewModel.document.layers[layerIndex].frame.origin.x += 13
        viewModel.applyLayerComp(compID)
        #expect(viewModel.document.layers[layerIndex].style.strokeEnabled)
        #expect(viewModel.document.layers[layerIndex].style.strokeWidth == 9)
        #expect(viewModel.document.layers[layerIndex].blendMode == .multiply)
        #expect(viewModel.document.layers[layerIndex].frame == originalFrame)

        viewModel.updateLayerComp(compID)
        #expect(viewModel.document.layerComps.first?.capturesAppearance == false)
    }

    @Test
    func newLayerCompUsesProvidedCaptureOptionsAndKeepsClassicDefaultsIndependent() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemMint, size: NSSize(width: 80, height: 60))
        ) { _ in }
        let historyCount = viewModel.document.history.count
        let customOptions = ImageEditorLayerCompCaptureOptions(
            capturesVisibility: false,
            capturesPosition: true,
            capturesAppearance: false
        )

        viewModel.addLayerComp(named: "Review layout", captureOptions: customOptions)
        let customComp = try #require(viewModel.document.layerComps.first)
        #expect(customComp.name == "Review layout")
        #expect(customComp.comment.isEmpty)
        #expect(customComp.capturesVisibility == false)
        #expect(customComp.capturesPosition)
        #expect(customComp.capturesAppearance == false)
        #expect(viewModel.document.history.count == historyCount + 1)

        viewModel.addLayerComp(named: "Classic")
        let classicComp = try #require(viewModel.document.layerComps.last)
        #expect(classicComp.capturesVisibility)
        #expect(classicComp.capturesPosition)
        #expect(classicComp.capturesAppearance)
        #expect(viewModel.document.history.count == historyCount + 2)
        #expect(ImageEditorLayerCompCaptureOptions.classic == ImageEditorLayerCompCaptureOptions())
    }

    @Test
    func layerCompCaptureDefaultsLoadClassicValuesAndStoredChoices() throws {
        let suiteName = "ImageEditorLayerCompTests.captureDefaults.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(ImageEditorLayerCompCaptureDefaults.load(from: defaults) == .classic)
        defaults.set(false, forKey: ImageEditorLayerCompCaptureDefaults.visibilityKey)
        defaults.set(true, forKey: ImageEditorLayerCompCaptureDefaults.positionKey)
        defaults.set(false, forKey: ImageEditorLayerCompCaptureDefaults.appearanceKey)
        #expect(ImageEditorLayerCompCaptureDefaults.load(from: defaults) == ImageEditorLayerCompCaptureOptions(
            capturesVisibility: false,
            capturesPosition: true,
            capturesAppearance: false
        ))
    }

    @Test
    func lastDocumentStateSurvivesCompCyclingAndPreservesCompDefinitions() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemBlue, size: NSSize(width: 90, height: 70))
        ) { _ in }
        let layerID = try #require(viewModel.document.selectedLayerID)
        let originalFrame = try #require(viewModel.document.layers.first?.frame)
        viewModel.addLayerComp(named: "Baseline")
        let baselineID = try #require(viewModel.document.selectedLayerCompID)

        let layerIndex = try #require(viewModel.document.layers.firstIndex { $0.id == layerID })
        viewModel.document.layers[layerIndex].isVisible = false
        viewModel.document.layers[layerIndex].frame.origin = CGPoint(x: 19, y: 23)
        viewModel.document.layers[layerIndex].style.strokeEnabled = true
        viewModel.document.layers[layerIndex].style.strokeWidth = 8
        viewModel.document.layers[layerIndex].blendMode = .screen
        let lastFrame = viewModel.document.layers[layerIndex].frame
        viewModel.addLayerComp(named: "Presentation")
        let presentationID = try #require(viewModel.document.selectedLayerCompID)

        viewModel.applyLayerComp(baselineID)
        let lastStateID = try #require(viewModel.lastDocumentLayerCompState?.id)
        #expect(viewModel.canRestoreLastDocumentLayerCompState)
        #expect(viewModel.document.layers[layerIndex].frame == originalFrame)
        #expect(viewModel.document.layers[layerIndex].isVisible)

        viewModel.applyLayerComp(presentationID)
        #expect(viewModel.lastDocumentLayerCompState?.id == lastStateID)
        #expect(viewModel.document.layers[layerIndex].frame == lastFrame)
        viewModel.applyLayerComp(baselineID)

        viewModel.renameLayerComp(presentationID, to: "Client presentation")
        viewModel.addLayerComp(named: "Added after apply")
        let compsBeforeRestore = viewModel.document.layerComps
        let historyCount = viewModel.document.history.count

        #expect(viewModel.restoreLastDocumentLayerCompState())
        #expect(viewModel.document.layers[layerIndex].frame == lastFrame)
        #expect(viewModel.document.layers[layerIndex].isVisible == false)
        #expect(viewModel.document.layers[layerIndex].style.strokeEnabled)
        #expect(viewModel.document.layers[layerIndex].style.strokeWidth == 8)
        #expect(viewModel.document.layers[layerIndex].blendMode == .screen)
        #expect(viewModel.document.layerComps == compsBeforeRestore)
        #expect(viewModel.document.selectedLayerCompID == nil)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text(
            "imageEditor.history.layerCompRestoreLastDocumentState"
        ))
        #expect(!viewModel.canRestoreLastDocumentLayerCompState)
        #expect(!viewModel.restoreLastDocumentLayerCompState())

        viewModel.undo()
        #expect(viewModel.document.layers[layerIndex].frame == originalFrame)
        #expect(viewModel.document.layers[layerIndex].isVisible)
        #expect(viewModel.document.layerComps == compsBeforeRestore)
        viewModel.redo()
        #expect(viewModel.document.layers[layerIndex].frame == lastFrame)
        #expect(viewModel.document.layers[layerIndex].isVisible == false)
        #expect(!viewModel.canRestoreLastDocumentLayerCompState)
    }

    @Test
    func missingLayerWarningsCanBeClearedAtomicallyAndReturnForNewMissingLayers() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemIndigo, size: NSSize(width: 90, height: 70))
        ) { _ in }
        let survivorID = try #require(viewModel.document.selectedLayerID)
        viewModel.duplicateSelectedLayer()
        let firstMissingID = try #require(viewModel.document.selectedLayerID)
        #expect(firstMissingID != survivorID)

        viewModel.addLayerComp(named: "Desktop")
        let desktopID = try #require(viewModel.document.selectedLayerCompID)
        viewModel.addLayerComp(named: "Mobile")
        let mobileID = try #require(viewModel.document.selectedLayerCompID)
        viewModel.deleteSelectedLayer()

        let desktop = try #require(viewModel.document.layerComps.first { $0.id == desktopID })
        let mobile = try #require(viewModel.document.layerComps.first { $0.id == mobileID })
        #expect(viewModel.unresolvedMissingLayerIDs(for: desktop) == [firstMissingID])
        #expect(viewModel.layerCompHasWarning(desktop))
        #expect(viewModel.layerCompHasWarning(mobile))
        #expect(viewModel.canClearAllLayerCompWarnings)

        viewModel.updateLayerComp(desktopID)
        let updatedDesktop = try #require(
            viewModel.document.layerComps.first { $0.id == desktopID }
        )
        #expect(!viewModel.layerCompHasWarning(updatedDesktop))
        #expect(updatedDesktop.acknowledgedMissingLayerIDs.isEmpty)
        viewModel.undo()
        #expect(viewModel.layerCompHasWarning(try #require(
            viewModel.document.layerComps.first { $0.id == desktopID }
        )))

        viewModel.showLayerCompWarning(desktopID)
        #expect(viewModel.document.selectedLayerCompID == desktopID)
        #expect(viewModel.statusText == L10n.format(
            "imageEditor.status.layerCompMissingLayers",
            "Desktop",
            1
        ))

        let historyBeforeClear = viewModel.document.history.count
        #expect(viewModel.clearLayerCompWarning(desktopID))
        #expect(viewModel.document.history.count == historyBeforeClear + 1)
        #expect(!viewModel.canClearSelectedLayerCompWarning)
        #expect(viewModel.document.layerComps.first { $0.id == desktopID }?
            .acknowledgedMissingLayerIDs == [firstMissingID])
        let clearedDesktop = try #require(
            viewModel.document.layerComps.first { $0.id == desktopID }
        )
        let roundTrippedDesktop = try JSONDecoder().decode(
            ImageEditorLayerComp.self,
            from: JSONEncoder().encode(clearedDesktop)
        )
        #expect(roundTrippedDesktop.acknowledgedMissingLayerIDs == [firstMissingID])
        #expect(!viewModel.layerCompHasWarning(try #require(
            viewModel.document.layerComps.first { $0.id == desktopID }
        )))
        #expect(viewModel.layerCompHasWarning(try #require(
            viewModel.document.layerComps.first { $0.id == mobileID }
        )))

        viewModel.undo()
        #expect(viewModel.canClearSelectedLayerCompWarning)
        #expect(viewModel.canRedo)
        viewModel.redo()
        #expect(!viewModel.canClearSelectedLayerCompWarning)

        let historyBeforeClearAll = viewModel.document.history.count
        #expect(viewModel.clearAllLayerCompWarnings())
        #expect(viewModel.document.history.count == historyBeforeClearAll + 1)
        #expect(!viewModel.canClearAllLayerCompWarnings)
        viewModel.undo()
        #expect(viewModel.canClearAllLayerCompWarnings)
        viewModel.redo()
        #expect(!viewModel.canClearAllLayerCompWarnings)

        viewModel.selectLayer(survivorID)
        viewModel.deleteSelectedLayer()
        for comp in viewModel.document.layerComps {
            #expect(viewModel.unresolvedMissingLayerIDs(for: comp) == [survivorID])
            #expect(viewModel.layerCompHasWarning(comp))
        }
        #expect(viewModel.clearAllLayerCompWarnings())
        #expect(!viewModel.clearAllLayerCompWarnings())
    }

    @Test
    func layerCompBatchExportUsesIsolatedSnapshotsUniqueNamesAndAtomicConflictPreflight() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "campaign/design.png",
            image: testImage(color: .systemBlue, size: NSSize(width: 48, height: 36))
        ) { _ in }
        let layerID = try #require(viewModel.document.layers.first?.id)
        viewModel.addLayerComp(named: "Client/Home")
        let favoriteID = try #require(viewModel.document.selectedLayerCompID)
        #expect(viewModel.setLayerCompFavorite(favoriteID, isFavorite: true))
        viewModel.toggleLayerVisibility(layerID)
        viewModel.addLayerComp(named: "Client/Home")
        let projectDataBeforeExport = try viewModel.projectData()
        let historyBeforeExport = viewModel.document.history
        let undoCountBeforeExport = viewModel.undoStack.count
        let redoCountBeforeExport = viewModel.redoStack.count
        let canUndoBeforeExport = viewModel.canUndo
        let canRedoBeforeExport = viewModel.canRedo
        let lastDocumentStateBeforeExport = viewModel.lastDocumentLayerCompState

        let plan = viewModel.layerCompExportPlan(format: .png)
        #expect(plan.map(\.filename) == [
            "campaign-design-Client-Home.png",
            "campaign-design-Client-Home-2.png"
        ])
        let favoritePlan = viewModel.layerCompExportPlan(format: .png, scope: .favorites)
        #expect(favoritePlan.map(\.layerCompID) == [favoriteID])
        #expect(favoritePlan.map(\.filename) == ["campaign-design-Client-Home.png"])
        #expect(viewModel.canExportFavoriteLayerComps)
        #expect(viewModel.layerCompExportPlan(format: .svg).isEmpty)

        let artifacts = try #require(viewModel.layerCompExportArtifacts(format: .png))
        #expect(artifacts.map(\.variant) == plan)
        let visibleImage = try #require(NSImage(data: artifacts[0].data))
        _ = try #require(NSImage(data: artifacts[1].data))
        let visiblePixel = try #require(
            visibleImage.color(at: CGPoint(x: 20, y: 18))?.usingColorSpace(.deviceRGB)
        )
        #expect(visiblePixel.blueComponent > 0.8)
        #expect(visiblePixel.alphaComponent > 0.99)
        #expect(artifacts[0].data != artifacts[1].data)
        let favoriteArtifacts = try #require(viewModel.layerCompExportArtifacts(
            format: .png,
            scope: .favorites
        ))
        #expect(favoriteArtifacts.map(\.variant) == favoritePlan)
        #expect(favoriteArtifacts.map(\.data) == [artifacts[0].data])
        var hiddenDocument = viewModel.document
        ImageEditorLayerCompApplication.apply(
            viewModel.document.layerComps[1],
            to: &hiddenDocument,
            selectedLayerCompID: viewModel.document.layerComps[1].id
        )
        #expect(hiddenDocument.layers.first { $0.id == layerID }?.isVisible == false)
        #expect(try viewModel.projectData() == projectDataBeforeExport)
        #expect(viewModel.document.history == historyBeforeExport)
        #expect(viewModel.undoStack.count == undoCountBeforeExport)
        #expect(viewModel.redoStack.count == redoCountBeforeExport)
        #expect(viewModel.canUndo == canUndoBeforeExport)
        #expect(viewModel.canRedo == canRedoBeforeExport)
        #expect(viewModel.lastDocumentLayerCompState == lastDocumentStateBeforeExport)

        let directory = URL(fileURLWithPath: "/tmp/xomo-layer-comp-export", isDirectory: true)
        var writtenURLs: [URL] = []
        let exportedCount = viewModel.exportLayerComps(
            format: .png,
            to: directory,
            fileExists: { _ in false },
            dataWriter: { data, destination in
                #expect(!data.isEmpty)
                writtenURLs.append(destination)
            }
        )
        #expect(exportedCount == 2)
        #expect(writtenURLs.map(\.lastPathComponent) == plan.map(\.filename))
        #expect(try viewModel.projectData() == projectDataBeforeExport)
        #expect(viewModel.document.history == historyBeforeExport)
        #expect(viewModel.undoStack.count == undoCountBeforeExport)
        #expect(viewModel.redoStack.count == redoCountBeforeExport)
        #expect(viewModel.statusText == L10n.format(
            "imageEditor.status.exportedLayerComps",
            2,
            "xomo-layer-comp-export"
        ))

        writtenURLs.removeAll()
        let favoriteCount = viewModel.exportLayerComps(
            format: .png,
            to: directory,
            scope: .favorites,
            fileExists: { _ in false },
            dataWriter: { _, destination in writtenURLs.append(destination) }
        )
        #expect(favoriteCount == 1)
        #expect(writtenURLs.map(\.lastPathComponent) == favoritePlan.map(\.filename))
        #expect(viewModel.statusText == L10n.format(
            "imageEditor.status.exportedLayerComps",
            1,
            "xomo-layer-comp-export"
        ))
        #expect(try viewModel.projectData() == projectDataBeforeExport)
        #expect(viewModel.document.history == historyBeforeExport)
        #expect(viewModel.undoStack.count == undoCountBeforeExport)
        #expect(viewModel.redoStack.count == redoCountBeforeExport)

        writtenURLs.removeAll()
        let conflictCount = viewModel.exportLayerComps(
            format: .png,
            to: directory,
            fileExists: { $0.lastPathComponent == plan[1].filename },
            dataWriter: { _, destination in writtenURLs.append(destination) }
        )
        #expect(conflictCount == 0)
        #expect(writtenURLs.isEmpty)
        #expect(try viewModel.projectData() == projectDataBeforeExport)
        #expect(viewModel.document.history == historyBeforeExport)
        #expect(viewModel.undoStack.count == undoCountBeforeExport)
        #expect(viewModel.redoStack.count == redoCountBeforeExport)
        #expect(viewModel.statusText == L10n.format(
            "imageEditor.status.exportLayerCompConflicts",
            1
        ))
    }

    @Test
    func layerCompMultipagePDFUsesOneIsolatedSnapshotPerPageWithoutMutatingTheEditor() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "campaign/design.png",
            image: testImage(color: .systemBlue, size: NSSize(width: 48, height: 36))
        ) { _ in }
        let layerID = try #require(viewModel.document.layers.first?.id)
        viewModel.addLayerComp(named: "Visible")
        let favoriteID = try #require(viewModel.document.selectedLayerCompID)
        #expect(viewModel.setLayerCompFavorite(favoriteID, isFavorite: true))
        viewModel.toggleLayerVisibility(layerID)
        viewModel.addLayerComp(named: "Hidden")
        let projectDataBeforeExport = try viewModel.projectData()
        let historyBeforeExport = viewModel.document.history
        let undoCountBeforeExport = viewModel.undoStack.count
        let redoCountBeforeExport = viewModel.redoStack.count
        let lastDocumentStateBeforeExport = viewModel.lastDocumentLayerCompState

        #expect(viewModel.layerCompPDFExportFilename == "campaign-design-layer-comps.pdf")
        #expect(viewModel.layerCompPDFExportFilename(
            scope: .favorites
        ) == "campaign-design-favorite-layer-comps.pdf")
        let exportDocuments = try #require(viewModel.layerCompExportDocuments())
        #expect(exportDocuments.count == 2)
        #expect(exportDocuments.map(\.selectedLayerCompID) == viewModel.document.layerComps.map(\.id))
        #expect(exportDocuments[0].layers.first { $0.id == layerID }?.isVisible == true)
        #expect(exportDocuments[1].layers.first { $0.id == layerID }?.isVisible == false)
        let favoriteDocuments = try #require(viewModel.layerCompExportDocuments(scope: .favorites))
        #expect(favoriteDocuments.map(\.selectedLayerCompID) == [favoriteID])
        #expect(favoriteDocuments[0].layers.first { $0.id == layerID }?.isVisible == true)

        let data = try #require(viewModel.layerCompMultipagePDFData())
        let provider = try #require(CGDataProvider(data: data as CFData))
        let pdf = try #require(CGPDFDocument(provider))
        #expect(pdf.numberOfPages == 2)
        for pageNumber in 1...pdf.numberOfPages {
            let page = try #require(pdf.page(at: pageNumber))
            let mediaBox = page.getBoxRect(.mediaBox)
            #expect(mediaBox.width == 48)
            #expect(mediaBox.height == 36)
        }
        let favoriteData = try #require(viewModel.layerCompMultipagePDFData(scope: .favorites))
        let favoriteProvider = try #require(CGDataProvider(data: favoriteData as CFData))
        let favoritePDF = try #require(CGPDFDocument(favoriteProvider))
        #expect(favoritePDF.numberOfPages == 1)
        #expect(try viewModel.projectData() == projectDataBeforeExport)
        #expect(viewModel.document.history == historyBeforeExport)
        #expect(viewModel.undoStack.count == undoCountBeforeExport)
        #expect(viewModel.redoStack.count == redoCountBeforeExport)
        #expect(viewModel.lastDocumentLayerCompState == lastDocumentStateBeforeExport)

        let destination = URL(fileURLWithPath: "/tmp/campaign-design-layer-comps.pdf")
        var writes: [(Data, URL)] = []
        #expect(viewModel.exportLayerCompsPDF(
            to: destination,
            fileExists: { _ in false },
            dataWriter: { writes.append(($0, $1)) }
        ))
        #expect(writes.count == 1)
        #expect(writes.first?.1 == destination)
        let writtenData = try #require(writes.first?.0)
        let writtenProvider = try #require(CGDataProvider(data: writtenData as CFData))
        let writtenPDF = try #require(CGPDFDocument(writtenProvider))
        #expect(writtenPDF.numberOfPages == 2)
        #expect(viewModel.statusText == L10n.format(
            "imageEditor.status.exportedLayerComps",
            2,
            destination.lastPathComponent
        ))

        writes.removeAll()
        let favoriteDestination = URL(
            fileURLWithPath: "/tmp/campaign-design-favorite-layer-comps.pdf"
        )
        #expect(viewModel.exportLayerCompsPDF(
            to: favoriteDestination,
            scope: .favorites,
            fileExists: { _ in false },
            dataWriter: { writes.append(($0, $1)) }
        ))
        #expect(writes.count == 1)
        #expect(writes.first?.1 == favoriteDestination)
        let favoriteWrittenData = try #require(writes.first?.0)
        let favoriteWrittenProvider = try #require(CGDataProvider(
            data: favoriteWrittenData as CFData
        ))
        #expect(CGPDFDocument(favoriteWrittenProvider)?.numberOfPages == 1)
        #expect(viewModel.statusText == L10n.format(
            "imageEditor.status.exportedLayerComps",
            1,
            favoriteDestination.lastPathComponent
        ))

        writes.removeAll()
        #expect(!viewModel.exportLayerCompsPDF(
            to: destination,
            fileExists: { _ in true },
            dataWriter: { writes.append(($0, $1)) }
        ))
        #expect(writes.isEmpty)
        #expect(viewModel.statusText == L10n.format(
            "imageEditor.status.exportLayerCompConflicts",
            1
        ))
        #expect(try viewModel.projectData() == projectDataBeforeExport)
        #expect(viewModel.document.history == historyBeforeExport)
        #expect(viewModel.undoStack.count == undoCountBeforeExport)
        #expect(viewModel.redoStack.count == redoCountBeforeExport)
        #expect(viewModel.lastDocumentLayerCompState == lastDocumentStateBeforeExport)
    }

    @Test
    func legacyLayerCompWithoutOptionalMetadataUsesClassicCaptureDefaults() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemBrown, size: NSSize(width: 40, height: 30))
        ) { _ in }
        viewModel.addLayerComp(named: "Legacy")
        let comp = try #require(viewModel.document.layerComps.first)
        let data = try JSONEncoder().encode(comp)
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "comment")
        object.removeValue(forKey: "isFavorite")
        object.removeValue(forKey: "capturesVisibility")
        object.removeValue(forKey: "capturesPosition")
        object.removeValue(forKey: "capturesAppearance")
        object.removeValue(forKey: "acknowledgedMissingLayerIDs")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(ImageEditorLayerComp.self, from: legacyData)
        #expect(decoded.id == comp.id)
        #expect(decoded.name == comp.name)
        #expect(decoded.comment.isEmpty)
        #expect(!decoded.isFavorite)
        #expect(decoded.capturesVisibility)
        #expect(decoded.capturesPosition)
        #expect(decoded.capturesAppearance)
        #expect(decoded.acknowledgedMissingLayerIDs.isEmpty)
    }

    @Test
    func layerCompOrderMovesAtomicallyAndRejectsEdgesWithoutClearingRedo() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemOrange, size: NSSize(width: 100, height: 80))
        ) { _ in }
        for name in ["First", "Second", "Third", "Fourth"] {
            viewModel.addLayerComp(named: name)
        }
        let ids = viewModel.document.layerComps.map(\.id)
        let thirdID = ids[2]
        let historyCount = viewModel.document.history.count

        #expect(viewModel.canMoveLayerCompToTop(thirdID))
        #expect(viewModel.canMoveLayerCompToBottom(thirdID))
        #expect(viewModel.moveLayerCompToTop(thirdID))
        #expect(viewModel.document.layerComps.map(\.id) == [ids[2], ids[0], ids[1], ids[3]])
        #expect(viewModel.document.selectedLayerCompID == thirdID)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerCompReorder"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerCompMovedToTop", "Third"))

        viewModel.undo()
        #expect(viewModel.document.layerComps.map(\.id) == ids)
        #expect(viewModel.canRedo)
        let historyAfterUndo = viewModel.document.history
        #expect(!viewModel.moveLayerCompToTop(ids[0]))
        #expect(viewModel.document.history == historyAfterUndo)
        #expect(viewModel.canRedo)
        viewModel.redo()
        #expect(viewModel.document.layerComps.map(\.id) == [ids[2], ids[0], ids[1], ids[3]])

        #expect(viewModel.moveLayerCompToBottom(thirdID))
        #expect(viewModel.document.layerComps.map(\.id) == [ids[0], ids[1], ids[3], ids[2]])
        #expect(viewModel.moveLayerCompUp(thirdID))
        #expect(viewModel.document.layerComps.map(\.id) == ids)
        #expect(viewModel.moveLayerCompDown(thirdID))
        #expect(viewModel.document.layerComps.map(\.id) == [ids[0], ids[1], ids[3], ids[2]])

        let finalOrder = viewModel.document.layerComps
        let finalHistory = viewModel.document.history
        #expect(!viewModel.moveLayerCompDown(thirdID))
        #expect(!viewModel.moveLayerCompToBottom(thirdID))
        #expect(!viewModel.moveLayerCompUp(UUID()))
        #expect(viewModel.document.layerComps == finalOrder)
        #expect(viewModel.document.history == finalHistory)
    }

    @Test
    func layerCompAppliesCapturedLayerState() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemBlue, size: NSSize(width: 100, height: 80))
        ) { _ in }
        let editLayerIndex = try #require(viewModel.document.selectedLayerIndex)
        let editLayerID = viewModel.document.layers[editLayerIndex].id
        let groupLayer = ImageEditorLayer.group(name: "Hero Group", size: viewModel.document.canvasSize)
        let groupID = groupLayer.id
        viewModel.document.layers.append(groupLayer)
        viewModel.document.layers[editLayerIndex].name = "Variant"
        viewModel.document.layers[editLayerIndex].frame = CGRect(x: 10, y: 12, width: 50, height: 40)
        viewModel.document.layers[editLayerIndex].opacity = 0.45
        viewModel.document.layers[editLayerIndex].fillOpacity = 0.62
        viewModel.document.layers[editLayerIndex].isMaskLinked = false
        viewModel.document.layers[editLayerIndex].blendIfSourceBlack = 0.18
        viewModel.document.layers[editLayerIndex].blendIfSourceWhite = 0.83
        viewModel.document.layers[editLayerIndex].blendIfUnderlyingBlack = 0.24
        viewModel.document.layers[editLayerIndex].blendIfUnderlyingWhite = 0.91
        viewModel.document.layers[editLayerIndex].isMaskEnabled = false
        viewModel.document.layers[editLayerIndex].maskDensity = 0.42
        viewModel.document.layers[editLayerIndex].maskFeather = 13
        viewModel.document.layers[editLayerIndex].isVectorMaskEnabled = false
        viewModel.document.layers[editLayerIndex].style.strokeEnabled = true
        viewModel.document.layers[editLayerIndex].style.strokeColor = NSColor(calibratedRed: 0.9, green: 0.2, blue: 0.1, alpha: 1)
        viewModel.document.layers[editLayerIndex].style.strokeWidth = 7
        viewModel.document.layers[editLayerIndex].style.strokePosition = .inside
        viewModel.document.layers[editLayerIndex].style.shadowEnabled = true
        viewModel.document.layers[editLayerIndex].style.shadowDistance = 11
        viewModel.document.layers[editLayerIndex].style.shadowAngle = 25
        viewModel.document.layers[editLayerIndex].style.shadowOffset = ImageEditorLayerStyle.shadowOffset(distance: 11, angle: 25)
        viewModel.document.layers[editLayerIndex].blendMode = .screen
        viewModel.document.layers[editLayerIndex].isVisible = false
        viewModel.document.layers[editLayerIndex].linkedLayerIDs = [groupID]
        viewModel.document.layers[editLayerIndex].groupID = groupID
        viewModel.document.layers[editLayerIndex].isLocked = true
        viewModel.document.layers[editLayerIndex].locksPixels = true
        viewModel.document.layers[editLayerIndex].locksPosition = true
        viewModel.document.layers[editLayerIndex].locksTransparentPixels = true
        viewModel.document.layers[editLayerIndex].isClippingMask = true
        let savedLayerOrder = viewModel.document.layers.map(\.id)

        viewModel.addLayerComp(named: "Hero hidden")
        let comp = try #require(viewModel.document.layerComps.first)

        viewModel.document.layers[editLayerIndex].frame = CGRect(x: 2, y: 3, width: 25, height: 20)
        viewModel.document.layers[editLayerIndex].opacity = 1
        viewModel.document.layers[editLayerIndex].fillOpacity = 1
        viewModel.document.layers[editLayerIndex].isMaskLinked = true
        viewModel.document.layers[editLayerIndex].blendIfSourceBlack = 0
        viewModel.document.layers[editLayerIndex].blendIfSourceWhite = 1
        viewModel.document.layers[editLayerIndex].blendIfUnderlyingBlack = 0
        viewModel.document.layers[editLayerIndex].blendIfUnderlyingWhite = 1
        viewModel.document.layers[editLayerIndex].isMaskEnabled = true
        viewModel.document.layers[editLayerIndex].maskDensity = 1
        viewModel.document.layers[editLayerIndex].maskFeather = 0
        viewModel.document.layers[editLayerIndex].isVectorMaskEnabled = true
        viewModel.document.layers[editLayerIndex].style = ImageEditorLayerStyle()
        viewModel.document.layers[editLayerIndex].blendMode = .normal
        viewModel.document.layers[editLayerIndex].isVisible = true
        viewModel.document.layers[editLayerIndex].linkedLayerIDs = []
        viewModel.document.layers[editLayerIndex].groupID = nil
        viewModel.document.layers[editLayerIndex].isLocked = false
        viewModel.document.layers[editLayerIndex].locksPixels = false
        viewModel.document.layers[editLayerIndex].locksPosition = false
        viewModel.document.layers[editLayerIndex].locksTransparentPixels = false
        viewModel.document.layers[editLayerIndex].isClippingMask = false
        viewModel.document.layers.reverse()

        viewModel.applyLayerComp(comp.id)

        let restoredLayer = try #require(viewModel.document.layers.first { $0.id == editLayerID })
        #expect(viewModel.document.layers.map(\.id) == savedLayerOrder)
        #expect(restoredLayer.frame == CGRect(x: 10, y: 12, width: 50, height: 40))
        #expect(restoredLayer.opacity == 0.45)
        #expect(restoredLayer.fillOpacity == 0.62)
        #expect(!restoredLayer.isMaskLinked)
        #expect(restoredLayer.blendIfSourceBlack == 0.18)
        #expect(restoredLayer.blendIfSourceWhite == 0.83)
        #expect(restoredLayer.blendIfUnderlyingBlack == 0.24)
        #expect(restoredLayer.blendIfUnderlyingWhite == 0.91)
        #expect(!restoredLayer.isMaskEnabled)
        #expect(restoredLayer.maskDensity == 0.42)
        #expect(restoredLayer.maskFeather == 13)
        #expect(!restoredLayer.isVectorMaskEnabled)
        #expect(restoredLayer.style.strokeEnabled)
        #expect(restoredLayer.style.strokeWidth == 7)
        #expect(restoredLayer.style.strokePosition == .inside)
        let restoredStrokeColor = try #require(restoredLayer.style.strokeColor.usingColorSpace(.deviceRGB))
        #expect(restoredStrokeColor.redComponent > 0.85)
        #expect(restoredStrokeColor.greenComponent < 0.35)
        #expect(restoredStrokeColor.blueComponent < 0.25)
        #expect(restoredLayer.style.shadowEnabled)
        #expect(abs(restoredLayer.style.shadowDistance - 11) < 0.001)
        #expect(abs(restoredLayer.style.shadowAngle - 25) < 0.001)
        #expect(restoredLayer.blendMode == .screen)
        #expect(!restoredLayer.isVisible)
        #expect(restoredLayer.linkedLayerIDs == [groupID])
        #expect(restoredLayer.groupID == groupID)
        #expect(restoredLayer.isLocked)
        #expect(restoredLayer.locksPixels)
        #expect(restoredLayer.locksPosition)
        #expect(restoredLayer.locksTransparentPixels)
        #expect(restoredLayer.isClippingMask)
        #expect(viewModel.document.selectedLayerCompID == comp.id)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerCompApply"))
    }

    @Test
    func layerCompStateDecodesLegacyFilesWithoutClippingMaskFlag() throws {
        let state = ImageEditorLayerCompLayerState(
            layerID: UUID(),
            isVisible: true,
            frame: CGRect(x: 4, y: 5, width: 20, height: 16),
            opacity: 0.7,
            fillOpacity: 0.8,
            isMaskLinked: false,
            blendIfSourceBlack: 0.2,
            blendIfSourceWhite: 0.9,
            blendIfUnderlyingBlack: 0.1,
            blendIfUnderlyingWhite: 0.8,
            isMaskEnabled: false,
            maskDensity: 0.5,
            maskFeather: 12,
            hasMaskSnapshot: true,
            maskData: Data([0, 1, 2, 3]),
            isVectorMaskEnabled: false,
            style: ImageEditorProjectLayerStyle(style: ImageEditorLayerStyle()),
            blendMode: .multiply,
            linkedLayerIDs: [UUID()],
            groupID: UUID(),
            isLocked: true,
            locksPixels: true,
            locksPosition: true,
            locksTransparentPixels: true,
            isGroupExpanded: false,
            isClippingMask: true
        )
        let data = try JSONEncoder().encode(state)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var legacyObject = object
        legacyObject.removeValue(forKey: "isClippingMask")
        legacyObject.removeValue(forKey: "isMaskLinked")
        legacyObject.removeValue(forKey: "blendIfSourceBlack")
        legacyObject.removeValue(forKey: "blendIfSourceWhite")
        legacyObject.removeValue(forKey: "blendIfUnderlyingBlack")
        legacyObject.removeValue(forKey: "blendIfUnderlyingWhite")
        legacyObject.removeValue(forKey: "isMaskEnabled")
        legacyObject.removeValue(forKey: "maskDensity")
        legacyObject.removeValue(forKey: "maskFeather")
        legacyObject.removeValue(forKey: "hasMaskSnapshot")
        legacyObject.removeValue(forKey: "maskData")
        legacyObject.removeValue(forKey: "isVectorMaskEnabled")
        legacyObject.removeValue(forKey: "isVectorMaskInverted")
        legacyObject.removeValue(forKey: "style")
        legacyObject.removeValue(forKey: "kind")
        legacyObject.removeValue(forKey: "smartFilters")
        legacyObject.removeValue(forKey: "adjustmentSettings")
        legacyObject.removeValue(forKey: "filterSettings")
        legacyObject.removeValue(forKey: "hasVectorMaskSnapshot")
        legacyObject.removeValue(forKey: "vectorMask")
        legacyObject.removeValue(forKey: "linkedLayerIDs")
        legacyObject.removeValue(forKey: "groupID")
        legacyObject.removeValue(forKey: "isLocked")
        legacyObject.removeValue(forKey: "locksPixels")
        legacyObject.removeValue(forKey: "locksPosition")
        legacyObject.removeValue(forKey: "locksTransparentPixels")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)

        let decoded = try JSONDecoder().decode(ImageEditorLayerCompLayerState.self, from: legacyData)

        #expect(decoded.layerID == state.layerID)
        #expect(decoded.frame == state.frame)
        #expect(decoded.opacity == state.opacity)
        #expect(decoded.fillOpacity == state.fillOpacity)
        #expect(decoded.isMaskLinked)
        #expect(decoded.blendIfSourceBlack == 0)
        #expect(decoded.blendIfSourceWhite == 1)
        #expect(decoded.blendIfUnderlyingBlack == 0)
        #expect(decoded.blendIfUnderlyingWhite == 1)
        #expect(decoded.isMaskEnabled)
        #expect(decoded.maskDensity == 1)
        #expect(decoded.maskFeather == 0)
        #expect(!decoded.hasMaskSnapshot)
        #expect(decoded.maskData == nil)
        #expect(decoded.isVectorMaskEnabled)
        #expect(!decoded.isVectorMaskInverted)
        #expect(!decoded.style.layerStyle.hasEffects)
        #expect(decoded.blendMode == state.blendMode)
        #expect(decoded.kind == nil)
        #expect(decoded.smartFilters == nil)
        #expect(decoded.adjustmentSettings == nil)
        #expect(decoded.filterSettings == nil)
        #expect(!decoded.hasVectorMaskSnapshot)
        #expect(decoded.vectorMask == nil)
        #expect(decoded.linkedLayerIDs.isEmpty)
        #expect(decoded.groupID == nil)
        #expect(!decoded.isLocked)
        #expect(!decoded.locksPixels)
        #expect(!decoded.locksPosition)
        #expect(!decoded.locksTransparentPixels)
        #expect(decoded.isGroupExpanded == state.isGroupExpanded)
        #expect(!decoded.isClippingMask)
    }

    @Test
    func layerCompAppliesCapturedRasterMaskSnapshot() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemPurple, size: NSSize(width: 100, height: 80))
        ) { _ in }
        let editLayerIndex = try #require(viewModel.document.selectedLayerIndex)
        let editLayerID = viewModel.document.layers[editLayerIndex].id
        let originalMask = maskImage(
            size: NSSize(width: 100, height: 80),
            whiteRect: CGRect(x: 0, y: 0, width: 50, height: 80)
        )
        viewModel.document.layers[editLayerIndex].mask = originalMask

        viewModel.addLayerComp(named: "Left masked")
        let comp = try #require(viewModel.document.layerComps.first)
        viewModel.document.layers[editLayerIndex].mask = maskImage(
            size: NSSize(width: 100, height: 80),
            whiteRect: CGRect(x: 50, y: 0, width: 50, height: 80)
        )

        viewModel.applyLayerComp(comp.id)

        let restoredLayer = try #require(viewModel.document.layers.first { $0.id == editLayerID })
        let restoredMask = try #require(restoredLayer.mask)
        let restoredWhiteSide = try #require(restoredMask.color(at: CGPoint(x: 24, y: 40))?.usingColorSpace(.deviceRGB))
        let restoredBlackSide = try #require(restoredMask.color(at: CGPoint(x: 74, y: 40))?.usingColorSpace(.deviceRGB))
        #expect(restoredWhiteSide.redComponent > 0.95)
        #expect(restoredBlackSide.redComponent < 0.05)
    }

    @Test
    func layerCompClearsRasterMaskWhenCapturedWithoutMask() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemOrange, size: NSSize(width: 100, height: 80))
        ) { _ in }
        let editLayerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[editLayerIndex].mask = nil

        viewModel.addLayerComp(named: "Unmasked")
        let comp = try #require(viewModel.document.layerComps.first)
        viewModel.document.layers[editLayerIndex].mask = maskImage(
            size: NSSize(width: 100, height: 80),
            whiteRect: CGRect(x: 0, y: 0, width: 100, height: 40)
        )

        viewModel.applyLayerComp(comp.id)

        #expect(viewModel.document.layers[editLayerIndex].mask == nil)
    }

    @Test
    func layerCompAppliesCapturedNonDestructiveContentState() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemGreen, size: NSSize(width: 96, height: 72))
        ) { _ in }
        let editLayerIndex = try #require(viewModel.document.selectedLayerIndex)
        let editLayerID = viewModel.document.layers[editLayerIndex].id
        let originalText = ImageEditorTextContent(
            text: "Draft title",
            color: .white,
            fontSize: 22,
            point: CGPoint(x: 4, y: 5),
            isBold: true,
            isItalic: false,
            characterSpacing: 1.5,
            lineSpacing: 2,
            boxWidth: 60,
            alignment: .center
        )
        let originalVectorMask = ImageEditorShapeContent(
            kind: .path,
            fillColor: .white,
            fillOpacity: 1,
            strokeColor: .white,
            strokeWidth: 1,
            strokeOpacity: 1,
            pathPoints: [],
            pathAnchors: [
                ImageEditorPathAnchor(point: CGPoint(x: 4, y: 4)),
                ImageEditorPathAnchor(point: CGPoint(x: 50, y: 4)),
                ImageEditorPathAnchor(point: CGPoint(x: 40, y: 44))
            ],
            isPathClosed: true
        )
        viewModel.document.layers[editLayerIndex].kind = .text(originalText)
        viewModel.document.layers[editLayerIndex].smartFilters = [
            ImageEditorSmartFilter(
                kind: .gaussianBlur,
                intensity: 0.42,
                settings: ImageEditorFilterSettings(unsharpRadius: 2.5, unsharpThreshold: 0.16),
                isEnabled: true
            )
        ]
        viewModel.document.layers[editLayerIndex].vectorMask = originalVectorMask
        viewModel.document.layers[editLayerIndex].isVectorMaskInverted = true

        var adjustmentSettings = ImageEditorAdjustmentSettings()
        adjustmentSettings.levelsBlackPoint = 0.2
        adjustmentSettings.levelsGamma = 1.4
        adjustmentSettings.levelsWhitePoint = 0.88
        let adjustmentLayer = ImageEditorLayer.adjustment(
            name: "Levels",
            size: viewModel.document.canvasSize,
            kind: .levels,
            amount: 0.76,
            settings: adjustmentSettings
        )
        let adjustmentLayerID = adjustmentLayer.id

        let filterSettings = ImageEditorFilterSettings(unsharpRadius: 3.5, unsharpThreshold: 0.22)
        let filterLayer = ImageEditorLayer.filter(
            name: "USM",
            size: viewModel.document.canvasSize,
            kind: .unsharpMask,
            intensity: 0.66,
            settings: filterSettings
        )
        let filterLayerID = filterLayer.id
        viewModel.document.layers.append(adjustmentLayer)
        viewModel.document.layers.append(filterLayer)

        viewModel.addLayerComp(named: "Editorial")
        let comp = try #require(viewModel.document.layerComps.first)

        viewModel.document.layers[editLayerIndex].kind = .text(
            ImageEditorTextContent(
                text: "Changed",
                color: .black,
                fontSize: 12,
                point: .zero
            )
        )
        viewModel.document.layers[editLayerIndex].smartFilters = []
        viewModel.document.layers[editLayerIndex].vectorMask = nil
        viewModel.document.layers[editLayerIndex].isVectorMaskInverted = false
        let adjustmentIndex = try #require(viewModel.document.layers.firstIndex { $0.id == adjustmentLayerID })
        viewModel.document.layers[adjustmentIndex].kind = .adjustment(.invert, 0.1)
        viewModel.document.layers[adjustmentIndex].adjustmentSettings = ImageEditorAdjustmentSettings()
        let filterIndex = try #require(viewModel.document.layers.firstIndex { $0.id == filterLayerID })
        viewModel.document.layers[filterIndex].kind = .filter(.gaussianBlur, 0.2)
        viewModel.document.layers[filterIndex].filterSettings = ImageEditorFilterSettings()

        viewModel.applyLayerComp(comp.id)

        let restoredTextLayer = try #require(viewModel.document.layers.first { $0.id == editLayerID })
        let restoredText = try #require(restoredTextLayer.textContent)
        #expect(restoredText.text == "Draft title")
        #expect(restoredText.isBold)
        #expect(restoredText.alignment == .center)
        #expect(restoredTextLayer.smartFilters.count == 1)
        #expect(restoredTextLayer.smartFilters.first?.kind == .gaussianBlur)
        #expect(restoredTextLayer.smartFilters.first?.intensity == 0.42)
        #expect(restoredTextLayer.vectorMask?.editablePathAnchors.count == 3)
        #expect(restoredTextLayer.isVectorMaskInverted)

        let restoredAdjustmentLayer = try #require(viewModel.document.layers.first { $0.id == adjustmentLayerID })
        let restoredAdjustment = try #require(restoredAdjustmentLayer.adjustment)
        #expect(restoredAdjustment.kind == .levels)
        #expect(restoredAdjustment.amount == 0.76)
        #expect(restoredAdjustmentLayer.adjustmentSettings.levelsBlackPoint == 0.2)
        #expect(restoredAdjustmentLayer.adjustmentSettings.levelsGamma == 1.4)
        #expect(restoredAdjustmentLayer.adjustmentSettings.levelsWhitePoint == 0.88)

        let restoredFilterLayer = try #require(viewModel.document.layers.first { $0.id == filterLayerID })
        let restoredFilter = try #require(restoredFilterLayer.filter)
        #expect(restoredFilter.kind == .unsharpMask)
        #expect(restoredFilter.intensity == 0.66)
        #expect(restoredFilterLayer.filterSettings.unsharpRadius == 3.5)
        #expect(restoredFilterLayer.filterSettings.unsharpThreshold == 0.22)
    }

    @Test
    func projectDocumentRoundTripsLayerComps() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemRed, size: NSSize(width: 64, height: 48))
        ) { _ in }
        let editLayerIndex = try #require(viewModel.document.selectedLayerIndex)
        let groupLayer = ImageEditorLayer.group(name: "Detail Group", size: viewModel.document.canvasSize)
        let groupID = groupLayer.id
        viewModel.document.layers.append(groupLayer)
        viewModel.document.layers[editLayerIndex].frame = CGRect(x: 8, y: 6, width: 20, height: 18)
        viewModel.document.layers[editLayerIndex].opacity = 0.35
        viewModel.document.layers[editLayerIndex].blendIfSourceBlack = 0.2
        viewModel.document.layers[editLayerIndex].blendIfUnderlyingWhite = 0.84
        viewModel.document.layers[editLayerIndex].isMaskEnabled = false
        viewModel.document.layers[editLayerIndex].maskDensity = 0.33
        viewModel.document.layers[editLayerIndex].maskFeather = 9
        let mask = maskImage(
            size: NSSize(width: 64, height: 48),
            whiteRect: CGRect(x: 4, y: 6, width: 28, height: 20)
        )
        let maskData = try #require(mask.qingtuPNGData())
        viewModel.document.layers[editLayerIndex].mask = mask
        viewModel.document.layers[editLayerIndex].isVectorMaskEnabled = false
        viewModel.document.layers[editLayerIndex].style.outerGlowEnabled = true
        viewModel.document.layers[editLayerIndex].style.outerGlowColor = NSColor(calibratedRed: 0.1, green: 0.7, blue: 0.9, alpha: 1)
        viewModel.document.layers[editLayerIndex].style.outerGlowBlur = 14
        viewModel.document.layers[editLayerIndex].linkedLayerIDs = [groupID]
        viewModel.document.layers[editLayerIndex].groupID = groupID
        viewModel.document.layers[editLayerIndex].isClippingMask = true
        let layerOrder = viewModel.document.layers.map(\.id)
        viewModel.addLayerComp(named: "Small detail")
        let compID = try #require(viewModel.document.layerComps.first?.id)
        #expect(viewModel.updateLayerCompComment(compID, to: "Client-approved mobile state"))
        #expect(viewModel.setLayerCompFavorite(compID, isFavorite: true))
        #expect(viewModel.setLayerCompCapturesVisibility(compID, enabled: false))
        #expect(viewModel.setLayerCompCapturesPosition(compID, enabled: false))
        #expect(viewModel.setLayerCompCapturesAppearance(compID, enabled: false))

        let data = try viewModel.projectData()
        let restoredViewModel = ImageEditorViewModel(
            sourceName: "empty.png",
            image: testImage(color: .black, size: NSSize(width: 12, height: 12))
        ) { _ in }
        try restoredViewModel.loadProjectData(data)

        let restoredComp = try #require(restoredViewModel.document.layerComps.first)
        #expect(restoredComp.id == compID)
        #expect(restoredComp.name == "Small detail")
        #expect(restoredComp.comment == "Client-approved mobile state")
        #expect(restoredComp.isFavorite)
        #expect(restoredComp.capturesVisibility == false)
        #expect(restoredComp.capturesPosition == false)
        #expect(restoredComp.capturesAppearance == false)
        #expect(restoredComp.layerStates.count == viewModel.document.layers.count)
        #expect(restoredComp.layerOrder == layerOrder)
        #expect(restoredComp.layerStates.contains { $0.isClippingMask })
        let restoredState = try #require(restoredComp.layerStates.first { $0.layerID == viewModel.document.layers[editLayerIndex].id })
        #expect(restoredState.blendIfSourceBlack == 0.2)
        #expect(restoredState.blendIfUnderlyingWhite == 0.84)
        #expect(!restoredState.isMaskEnabled)
        #expect(restoredState.maskDensity == 0.33)
        #expect(restoredState.maskFeather == 9)
        #expect(restoredState.hasMaskSnapshot)
        #expect(restoredState.maskData == maskData)
        #expect(!restoredState.isVectorMaskEnabled)
        #expect(restoredState.style.outerGlowEnabled)
        #expect(restoredState.style.outerGlowBlur == 14)
        let restoredGlowColor = restoredState.style.outerGlowColor.nsColor
        #expect(restoredGlowColor.blueComponent > 0.85)
        #expect(restoredGlowColor.greenComponent > 0.6)
        #expect(restoredGlowColor.redComponent < 0.2)
        #expect(restoredState.linkedLayerIDs == [groupID])
        #expect(restoredState.groupID == groupID)
        #expect(restoredViewModel.document.selectedLayerCompID == compID)
    }

    private func testImage(color: NSColor, size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        color.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        return image
    }

    private func maskImage(size: NSSize, whiteRect: CGRect) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.black.setFill()
        NSRect(origin: .zero, size: size).fill()
        NSColor.white.setFill()
        whiteRect.fill()
        image.unlockFocus()
        return image
    }
}
