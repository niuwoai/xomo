import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct XomoCloseCommandTests {
    @Test func nativeFileMenuContainsExactlyOneLocalizedCommandWClose() throws {
        let mainMenu = try #require(NSApplication.shared.mainMenu)
        let fileMenu = try #require(mainMenu.items.compactMap(\.submenu).first { menu in
            menu.items.contains { item in
                item.keyEquivalent == "o" && commandModifiers(item) == [.command]
            }
        })
        let closeItems = fileMenu.items.filter {
            $0.keyEquivalent == "w" && commandModifiers($0) == [.command]
        }
        #expect(closeItems.count == 1)
        let close = try #require(closeItems.first)
        #expect(close.title == NSLocalizedString("imageEditor.action.close",
            tableName: "WindowCommands", comment: ""))
        // SwiftUI owns command dispatch; NSMenuItem.action may legitimately be
        // nil. Actual keyboard invocation is verified in native UI acceptance.
    }

    @Test func sharedMenuCloseUsesTheExistingGuardedWindowAction() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let commands = try String(contentsOf: root.appendingPathComponent("veilpic/XomoApplicationCommands.swift"), encoding: .utf8)
        let start = try #require(commands.range(of: "        case .cancel:"))
        let close = commands[start.lowerBound...]
        #expect(close.contains("actions?.cancel()"))
        #expect(close.contains(".keyboardShortcut(\"w\", modifiers: [.command])"))
        #expect(close.contains("Text(\"imageEditor.action.close\", tableName: \"WindowCommands\")"))
        let menuBar = try String(contentsOf: root.appendingPathComponent("veilpic/ImageEditorMenuBar.swift"), encoding: .utf8)
        let editor = try String(contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"), encoding: .utf8)
        #expect(menuBar.contains("cancel: { closeWindow() }"))
        #expect(editor.contains("NSApplication.shared.keyWindow?.performClose(nil)"))
        #expect(!editor.contains("keyWindow?.close()"))
    }

    @Test(arguments: ["zh-Hans", "en", "ja"])
    func closeTitleIsPackagedAndLocalizedWithoutChangingCancel(locale: String) throws {
        let expected = ["zh-Hans": "关闭", "en": "Close", "ja": "閉じる"]
        let path = try #require(Bundle.main.path(forResource: locale, ofType: "lproj"))
        let bundle = try #require(Bundle(path: path))
        let title = bundle.localizedString(forKey: "imageEditor.action.close", value: nil, table: "WindowCommands")
        #expect(title == expected[locale])
        let cancel = bundle.localizedString(forKey: "imageEditor.action.cancel", value: nil, table: nil)
        #expect(cancel != title && cancel != "imageEditor.action.cancel")
    }

    private func commandModifiers(_ item: NSMenuItem) -> NSEvent.ModifierFlags {
        item.keyEquivalentModifierMask.intersection([.command, .option, .shift, .control])
    }
}
