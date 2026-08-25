import Foundation
import Testing
@testable import musepic

@MainActor
struct XomoHelpTests {
    @Test func shortcutCatalogCoversCoreFileEditToolAndViewActionsWithoutDuplicateIDs() {
        let groups = XomoHelpContent.shortcutGroups
        let shortcuts = groups.flatMap(\.shortcuts)

        #expect(groups.map(\.id) == ["file", "edit", "tools", "view"])
        #expect(shortcuts.count == 22)
        #expect(Set(shortcuts.map(\.id)).count == shortcuts.count)
        #expect(shortcuts.allSatisfy { !$0.titleKey.isEmpty && !$0.keys.isEmpty })
        #expect(shortcuts.contains { $0.id == "open" && $0.keys == "⌘O" })
        #expect(shortcuts.contains { $0.id == "delete" && $0.keys == "⌫" })
        #expect(shortcuts.contains { $0.id == "brush" && $0.keys == "B" })
        #expect(shortcuts.contains { $0.id == "fit" && $0.keys == "⌘0" })
    }

    @Test func nativeHelpMenuOpensBothOfflineSectionsAndUsesTheStandardShortcut() throws {
        let root = Self.repositoryRoot()
        let helpSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/XomoHelp.swift"),
            encoding: .utf8
        )
        let appSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/veilpicApp.swift"),
            encoding: .utf8
        )

        #expect(helpSource.contains("CommandGroup(after: .help)"))
        #expect(helpSource.contains("open(section: .guide)"))
        #expect(helpSource.contains("open(section: .shortcuts)"))
        #expect(helpSource.contains(".keyboardShortcut(\"?\", modifiers: [.command])"))
        #expect(helpSource.contains("switch section"))
        #expect(helpSource.contains("case .guide: guide"))
        #expect(helpSource.contains("case .shortcuts: shortcutReference"))
        #expect(!helpSource.contains("https://"))
        #expect(helpSource.contains("XomoHelpCommands()"))
        #expect(helpSource.contains("CommandGroup(replacing: .appInfo)"))
        #expect(appSource.contains("XomoSupportCommands()"))
    }

    @Test func everyHelpStringIsLocalizedInAllSupportedLanguages() throws {
        let keys = [
            "xomo.help.guide",
            "xomo.help.shortcuts",
            "xomo.help.title",
            "xomo.help.subtitle",
            "xomo.help.windowTitle",
            "xomo.help.offlineNote",
            "xomo.help.guide.open.title",
            "xomo.help.guide.open.body",
            "xomo.help.guide.components.title",
            "xomo.help.guide.components.body",
            "xomo.help.guide.figma.title",
            "xomo.help.guide.figma.body",
            "xomo.help.guide.save.title",
            "xomo.help.guide.save.body",
            "xomo.help.shortcuts.group.file",
            "xomo.help.shortcuts.group.edit",
            "xomo.help.shortcuts.group.tools",
            "xomo.help.shortcuts.group.view",
        ]

        for locale in ["zh-Hans", "en", "ja"] {
            let source = try String(
                contentsOf: Self.repositoryRoot().appendingPathComponent(
                    "veilpic/\(locale).lproj/Localizable.strings"
                ),
                encoding: .utf8
            )
            for key in keys {
                #expect(source.contains("\"\(key)\" = \""), "Missing \(key) in \(locale)")
            }
        }
    }

    private static func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
