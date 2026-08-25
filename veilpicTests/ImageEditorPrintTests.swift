//
//  ImageEditorPrintTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/8/25.
//

import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
struct ImageEditorPrintTests {
    @Test func layoutFitsWideAndTallContentOnOneCenteredPage() throws {
        let page = CGRect(x: 10, y: 20, width: 500, height: 700)
        let wide = try #require(
            ImageEditorPrintLayout.fittedRect(
                for: CGSize(width: 400, height: 200),
                in: page
            )
        )
        #expect(wide == CGRect(x: 10, y: 245, width: 500, height: 250))

        let tall = try #require(
            ImageEditorPrintLayout.fittedRect(
                for: CGSize(width: 100, height: 400),
                in: page
            )
        )
        #expect(tall == CGRect(x: 172.5, y: 20, width: 175, height: 700))
        #expect(ImageEditorPrintLayout.fittedRect(for: .zero, in: page) == nil)
        #expect(
            ImageEditorPrintLayout.fittedRect(
                for: CGSize(width: 10, height: 10),
                in: .zero
            ) == nil
        )
    }

    @Test func printingUsesOneCompositedPageWithoutChangingEditorState() throws {
        let canvasSize = CGSize(width: 12, height: 7)
        let viewModel = ImageEditorViewModel(
            sourceName: "Print Layout.xomoproject",
            image: solidImage(color: .systemBlue, size: canvasSize)
        ) { _ in }
        viewModel.renameSelectedLayer(to: "Unsaved Print Layer")
        viewModel.exportSettings.format = .jpeg
        viewModel.exportSettings.scope = .selectedLayer
        viewModel.exportSettings.scale = 4
        let projectDataBeforePrint = try viewModel.projectData()
        let historyBeforePrint = viewModel.document.history
        let undoCountBeforePrint = viewModel.undoStack.count
        let redoCountBeforePrint = viewModel.redoStack.count
        let exportSettingsBeforePrint = viewModel.exportSettings
        let sourcePrintInfo = try #require(NSPrintInfo.shared.copy() as? NSPrintInfo)
        sourcePrintInfo.orientation = .portrait
        var capturedPageView: ImageEditorPrintPageView?
        var capturedPrintInfo: NSPrintInfo?

        let didPrint = viewModel.printCompositedCanvas(
            printInfo: sourcePrintInfo,
            printRunner: { pageView, printInfo in
                capturedPageView = pageView
                capturedPrintInfo = printInfo
                return true
            }
        )

        #expect(didPrint)
        let pageView = try #require(capturedPageView)
        let printInfo = try #require(capturedPrintInfo)
        #expect(sourcePrintInfo.orientation == .portrait)
        #expect(printInfo !== sourcePrintInfo)
        #expect(printInfo.orientation == .landscape)
        #expect(printInfo.horizontalPagination == .fit)
        #expect(printInfo.verticalPagination == .fit)
        #expect(printInfo.isHorizontallyCentered)
        #expect(printInfo.isVerticallyCentered)
        #expect(pageView.bounds.size == printInfo.imageablePageBounds.size)
        #expect(pageView.image.size == canvasSize)
        #expect(pageView.imageRect.minX >= 0)
        #expect(pageView.imageRect.minY >= 0)
        #expect(pageView.imageRect.maxX <= pageView.bounds.maxX)
        #expect(pageView.imageRect.maxY <= pageView.bounds.maxY)
        var pageRange = NSRange()
        #expect(pageView.knowsPageRange(&pageRange))
        #expect(pageRange == NSRange(location: 1, length: 1))
        #expect(pageView.rectForPage(1) == pageView.bounds)
        #expect(pageView.rectForPage(2) == .zero)

        #expect(try viewModel.projectData() == projectDataBeforePrint)
        #expect(viewModel.document.history == historyBeforePrint)
        #expect(viewModel.undoStack.count == undoCountBeforePrint)
        #expect(viewModel.redoStack.count == redoCountBeforePrint)
        #expect(viewModel.exportSettings == exportSettingsBeforePrint)
        #expect(viewModel.hasUnsavedProjectChanges)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.printCompleted"))
    }

    @Test func cancellingPrintPreservesDocumentAndReportsCancellation() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "Cancel Print.png",
            image: solidImage(color: .systemOrange, size: CGSize(width: 8, height: 11))
        ) { _ in }
        let projectDataBeforePrint = try viewModel.projectData()
        let historyBeforePrint = viewModel.document.history
        let sourcePrintInfo = try #require(NSPrintInfo.shared.copy() as? NSPrintInfo)
        var capturedOrientation: NSPrintInfo.PaperOrientation?

        let didPrint = viewModel.printCompositedCanvas(
            printInfo: sourcePrintInfo,
            printRunner: { _, printInfo in
                capturedOrientation = printInfo.orientation
                return false
            }
        )
        #expect(!didPrint)
        #expect(capturedOrientation == .portrait)
        #expect(try viewModel.projectData() == projectDataBeforePrint)
        #expect(viewModel.document.history == historyBeforePrint)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.printCancelled"))
    }

    @Test func pageSetupCommitsPaperChoicesWithoutChangingEditorState() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "Page Setup.xomoproject",
            image: solidImage(color: .systemGreen, size: CGSize(width: 14, height: 8))
        ) { _ in }
        viewModel.renameSelectedLayer(to: "Unsaved Page Setup Layer")
        viewModel.exportSettings.format = .jpeg
        let projectDataBeforeSetup = try viewModel.projectData()
        let historyBeforeSetup = viewModel.document.history
        let undoCountBeforeSetup = viewModel.undoStack.count
        let redoCountBeforeSetup = viewModel.redoStack.count
        let exportSettingsBeforeSetup = viewModel.exportSettings
        var initialOrientation: NSPrintInfo.PaperOrientation?

        let didChange = viewModel.presentPageSetup { printInfo in
            initialOrientation = printInfo.orientation
            printInfo.orientation = .portrait
            printInfo.leftMargin = 17
            printInfo.rightMargin = 19
            printInfo.scalingFactor = 0.75
            return true
        }

        #expect(didChange)
        #expect(initialOrientation == .landscape)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.pageSetupCompleted"))
        var capturedPrintInfo: NSPrintInfo?
        let didPrint = viewModel.printCompositedCanvas { _, printInfo in
            capturedPrintInfo = printInfo
            return true
        }
        #expect(didPrint)
        let printInfo = try #require(capturedPrintInfo)
        #expect(printInfo.orientation == .portrait)
        #expect(printInfo.leftMargin == 17)
        #expect(printInfo.rightMargin == 19)
        #expect(printInfo.scalingFactor == 0.75)
        #expect(try viewModel.projectData() == projectDataBeforeSetup)
        #expect(viewModel.document.history == historyBeforeSetup)
        #expect(viewModel.undoStack.count == undoCountBeforeSetup)
        #expect(viewModel.redoStack.count == redoCountBeforeSetup)
        #expect(viewModel.exportSettings == exportSettingsBeforeSetup)
        #expect(viewModel.hasUnsavedProjectChanges)
    }

    @Test func cancellingPageSetupDiscardsCandidatePaperChanges() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "Cancel Page Setup.png",
            image: solidImage(color: .systemPurple, size: CGSize(width: 8, height: 14))
        ) { _ in }
        let projectDataBeforeSetup = try viewModel.projectData()
        let didConfigureInitialPage = viewModel.presentPageSetup { printInfo in
            printInfo.orientation = .landscape
            printInfo.leftMargin = 23
            return true
        }
        #expect(didConfigureInitialPage)
        var candidateOrientation: NSPrintInfo.PaperOrientation?
        var candidateLeftMargin: CGFloat?

        let didChange = viewModel.presentPageSetup { printInfo in
            candidateOrientation = printInfo.orientation
            candidateLeftMargin = printInfo.leftMargin
            printInfo.orientation = .portrait
            printInfo.leftMargin = 99
            return false
        }

        #expect(!didChange)
        #expect(candidateOrientation == .landscape)
        #expect(candidateLeftMargin == 23)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.pageSetupCancelled"))
        var capturedPrintInfo: NSPrintInfo?
        let didPrint = viewModel.printCompositedCanvas { _, printInfo in
            capturedPrintInfo = printInfo
            return true
        }
        #expect(didPrint)
        let printInfo = try #require(capturedPrintInfo)
        #expect(printInfo.orientation == .landscape)
        #expect(printInfo.leftMargin == 23)
        #expect(try viewModel.projectData() == projectDataBeforeSetup)
    }

    @Test func sharedFileMenuWiresPageSetupAndPrintShortcutsInEveryLanguage() throws {
        let root = Self.repositoryRoot()
        let commands = try source("veilpic/XomoApplicationCommands.swift", root: root)
        let menuBar = try source("veilpic/ImageEditorMenuBar.swift", root: root)

        #expect(commands.contains("case pageSetup"))
        #expect(commands.contains("imageEditor.action.pageSetup"))
        #expect(commands.contains("actions?.pageSetup()"))
        #expect(commands.contains(".keyboardShortcut(\"p\", modifiers: [.command, .shift])"))
        #expect(commands.contains("actions?.canConfigurePage != true"))
        #expect(commands.contains("case printDocument"))
        #expect(commands.contains("imageEditor.action.printDocument"))
        #expect(commands.contains("actions?.printDocument()"))
        #expect(commands.contains(".keyboardShortcut(\"p\", modifiers: [.command])"))
        #expect(commands.contains("actions?.canPrintDocument != true"))
        #expect(menuBar.contains("pageSetup: { viewModel.presentPageSetup() }"))
        #expect(menuBar.contains("canConfigurePage: viewModel.canPrintCompositedCanvas"))
        #expect(menuBar.contains("printDocument: { viewModel.printCompositedCanvas() }"))
        #expect(menuBar.contains("canPrintDocument: viewModel.canPrintCompositedCanvas"))

        for locale in ["zh-Hans", "en", "ja"] {
            let strings = try source(
                "veilpic/\(locale).lproj/Localizable.strings",
                root: root
            )
            #expect(strings.contains("\"imageEditor.action.pageSetup\" ="))
            #expect(strings.contains("\"imageEditor.status.pageSetupCompleted\" ="))
            #expect(strings.contains("\"imageEditor.status.pageSetupCancelled\" ="))
            #expect(strings.contains("\"imageEditor.status.pageSetupFailed\" ="))
            #expect(strings.contains("\"imageEditor.action.printDocument\" ="))
            #expect(strings.contains("\"imageEditor.status.printCompleted\" ="))
            #expect(strings.contains("\"imageEditor.status.printCancelled\" ="))
            #expect(strings.contains("\"imageEditor.status.printFailed\" ="))
        }
    }

    private static func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func source(_ path: String, root: URL) throws -> String {
        try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    private func solidImage(color: NSColor, size: CGSize) -> NSImage {
        NSImage(size: size, flipped: false) { rect in
            color.setFill()
            rect.fill()
            return true
        }
    }
}
