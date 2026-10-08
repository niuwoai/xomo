import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
private final class XomoRecentDocumentControllerSpy: XomoRecentDocumentControlling {
    var recentDocumentURLs: [URL]
    var maximumRecentDocumentCount: Int
    private(set) var notedURLs: [URL] = []
    private(set) var clearCount = 0

    init(recentDocumentURLs: [URL], maximumRecentDocumentCount: Int) {
        self.recentDocumentURLs = recentDocumentURLs
        self.maximumRecentDocumentCount = maximumRecentDocumentCount
    }

    func noteNewRecentDocumentURL(_ url: URL) {
        notedURLs.append(url)
        recentDocumentURLs.removeAll { $0.standardizedFileURL == url.standardizedFileURL }
        recentDocumentURLs.insert(url, at: 0)
    }

    func clearRecentDocuments(_ sender: Any?) {
        clearCount += 1
        recentDocumentURLs.removeAll()
    }
}

@MainActor
struct XomoRecentDocumentsTests {
    @Test func recentPolicyKeepsAvailableUniqueFilesInMostRecentOrderAndCapsTheMenu() {
        let first = URL(fileURLWithPath: "/tmp/first.xomoproject")
        let second = URL(fileURLWithPath: "/tmp/second.psd")
        let missing = URL(fileURLWithPath: "/tmp/missing.png")
        let web = URL(string: "https://example.com/design.fig")!
        let available = Set([first.path, second.path])

        let result = XomoRecentDocumentPolicy.availableURLs(
            from: [first, missing, first, web, second],
            limit: 2,
            fileExists: { available.contains($0) }
        )

        #expect(result == [first, second])
        #expect(
            XomoRecentDocumentPolicy.availableURLs(
                from: [first],
                limit: 0,
                fileExists: { _ in true }
            ).isEmpty
        )
    }

    @Test func storeNotesRefreshesAndClearsThroughTheNativeDocumentController() {
        let first = URL(fileURLWithPath: "/tmp/first.xomoproject")
        let second = URL(fileURLWithPath: "/tmp/second.png")
        let third = URL(fileURLWithPath: "/tmp/third.psd")
        let available = Set([first.path, second.path, third.path])
        let controller = XomoRecentDocumentControllerSpy(
            recentDocumentURLs: [first, second],
            maximumRecentDocumentCount: 2
        )
        let store = XomoRecentDocumentStore(
            controller: controller,
            fileExists: { available.contains($0) }
        )

        #expect(store.urls == [first, second])
        store.noteOpened(third)
        #expect(controller.notedURLs == [third])
        #expect(store.urls == [third, first])

        store.clear()
        #expect(controller.clearCount == 1)
        #expect(store.urls.isEmpty)
    }

    @Test func fileMenuAndSuccessfulOpenPipelinesShareTheRecentDocumentStore() throws {
        let root = Self.repositoryRoot()
        let commands = try String(
            contentsOf: root.appendingPathComponent("veilpic/XomoApplicationCommands.swift"),
            encoding: .utf8
        )
        let menu = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let project = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorProjectDocument.swift"),
            encoding: .utf8
        )
        let external = try String(
            contentsOf: root.appendingPathComponent("veilpic/XomoExternalDocumentOpen.swift"),
            encoding: .utf8
        )

        #expect(commands.contains("case openRecent"))
        #expect(commands.contains("Menu(L10n.text(\"imageEditor.action.openRecent\"))"))
        #expect(commands.contains("ForEach(actions.recentDocuments, id: \\.path)"))
        #expect(commands.contains("actions.openRecentDocument(url)"))
        #expect(commands.contains("actions.clearRecentDocuments()"))
        #expect(menu.contains("recentDocuments: recentDocumentStore.urls"))
        #expect(menu.contains("openRecentDocument: { openRecentDocumentSafely(at: $0) }"))
        #expect(menu.contains("func openRecentDocumentSafely(at url: URL)"))
        #expect(menu.contains("ImageEditorViewModel.routesThroughExternalDocumentCoordinator(url)"))
        #expect(menu.contains("requestDocumentReplacement {\n            viewModel.openDocument(at: url)"))
        #expect(project.contains("recentDocumentRegistrar(url)"))
        #expect(project.contains("XomoRecentDocumentStore.shared.noteOpened($0)"))
        #expect(project.contains("recentDocumentRegistrar(standardizedURL)"))
        #expect(external.components(separatedBy: "finishSuccessfulOpen(url: url").count - 1 == 4)
        #expect(external.contains("XomoRecentDocumentStore.shared.noteOpened($0)"))
        #expect(external.contains("recentDocumentRegistrar(url)"))
    }

    @Test func recentFileMenuStringsExistInEverySupportedLanguage() throws {
        let root = Self.repositoryRoot()
        let keys = [
            "imageEditor.action.openRecent",
            "imageEditor.action.noRecent",
            "imageEditor.action.clearRecent",
        ]

        for locale in ["zh-Hans", "en", "ja"] {
            let source = try String(
                contentsOf: root.appendingPathComponent(
                    "veilpic/\(locale).lproj/Localizable.strings"
                ),
                encoding: .utf8
            )
            for key in keys {
                #expect(source.contains("\"\(key)\" = \""))
            }
        }
    }

    private static func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
