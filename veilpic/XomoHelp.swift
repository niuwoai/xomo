import AppKit
import SwiftUI

enum XomoHelpSection: String, CaseIterable, Identifiable {
    case guide
    case shortcuts

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .guide: "xomo.help.guide"
        case .shortcuts: "xomo.help.shortcuts"
        }
    }
}

struct XomoHelpShortcut: Identifiable, Equatable {
    let id: String
    let titleKey: String
    let keys: String
}

struct XomoHelpShortcutGroup: Identifiable, Equatable {
    let id: String
    let titleKey: String
    let shortcuts: [XomoHelpShortcut]
}

enum XomoHelpContent {
    static let shortcutGroups: [XomoHelpShortcutGroup] = [
        XomoHelpShortcutGroup(
            id: "file",
            titleKey: "xomo.help.shortcuts.group.file",
            shortcuts: [
                XomoHelpShortcut(id: "open", titleKey: "imageEditor.action.projectOpen", keys: "⌘O"),
                XomoHelpShortcut(id: "save", titleKey: "imageEditor.action.projectSave", keys: "⌘S"),
                XomoHelpShortcut(id: "import", titleKey: "imageEditor.action.fileImport", keys: "File"),
                XomoHelpShortcut(id: "export", titleKey: "imageEditor.action.export", keys: "⌥⇧⌘S"),
            ]
        ),
        XomoHelpShortcutGroup(
            id: "edit",
            titleKey: "xomo.help.shortcuts.group.edit",
            shortcuts: [
                XomoHelpShortcut(id: "undo", titleKey: "imageEditor.action.undo", keys: "⌘Z"),
                XomoHelpShortcut(id: "redo", titleKey: "imageEditor.action.redo", keys: "⇧⌘Z"),
                XomoHelpShortcut(id: "copy", titleKey: "imageEditor.action.copySelectionClipboard", keys: "⌘C"),
                XomoHelpShortcut(id: "paste", titleKey: "imageEditor.action.pasteClipboardLayer", keys: "⌘V"),
                XomoHelpShortcut(id: "transform", titleKey: "imageEditor.action.freeTransform", keys: "⌘T"),
                XomoHelpShortcut(id: "delete", titleKey: "imageEditor.action.deleteSelectedObject", keys: "⌫"),
            ]
        ),
        XomoHelpShortcutGroup(
            id: "tools",
            titleKey: "xomo.help.shortcuts.group.tools",
            shortcuts: [
                XomoHelpShortcut(id: "move", titleKey: "imageEditor.tool.move", keys: "V"),
                XomoHelpShortcut(id: "crop", titleKey: "imageEditor.tool.crop", keys: "C"),
                XomoHelpShortcut(id: "brush", titleKey: "imageEditor.tool.brush", keys: "B"),
                XomoHelpShortcut(id: "eraser", titleKey: "imageEditor.tool.eraser", keys: "E"),
                XomoHelpShortcut(id: "pen", titleKey: "imageEditor.tool.pen", keys: "P"),
                XomoHelpShortcut(id: "text", titleKey: "imageEditor.tool.text", keys: "T"),
                XomoHelpShortcut(id: "hand", titleKey: "imageEditor.tool.hand", keys: "H / Space"),
                XomoHelpShortcut(id: "zoom", titleKey: "imageEditor.tool.zoom", keys: "Z"),
            ]
        ),
        XomoHelpShortcutGroup(
            id: "view",
            titleKey: "xomo.help.shortcuts.group.view",
            shortcuts: [
                XomoHelpShortcut(id: "actualPixels", titleKey: "imageEditor.menu.view.actualPixels", keys: "⌘1"),
                XomoHelpShortcut(id: "fit", titleKey: "imageEditor.menu.view.fit", keys: "⌘0"),
                XomoHelpShortcut(id: "zoomIn", titleKey: "imageEditor.menu.view.zoomIn", keys: "⌘+"),
                XomoHelpShortcut(id: "zoomOut", titleKey: "imageEditor.menu.view.zoomOut", keys: "⌘−"),
            ]
        ),
    ]
}

struct XomoHelpView: View {
    static let defaultWindowSize = CGSize(width: 680, height: 600)

    @State private var section: XomoHelpSection
    let dismiss: () -> Void

    init(section: XomoHelpSection, dismiss: @escaping () -> Void) {
        _section = State(initialValue: section)
        self.dismiss = dismiss
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                Group {
                    switch section {
                    case .guide: guide
                    case .shortcuts: shortcutReference
                    }
                }
                .padding(24)
            }
            Divider()
            HStack {
                Text(L10n.text("xomo.help.offlineNote"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(L10n.text("action.done"), action: dismiss)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .frame(width: Self.defaultWindowSize.width, height: Self.defaultWindowSize.height)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 16) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.text("xomo.help.title"))
                    .font(.title2.weight(.semibold))
                Text(L10n.text("xomo.help.subtitle"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Picker("", selection: $section) {
                ForEach(XomoHelpSection.allCases) { section in
                    Text(L10n.text(section.titleKey)).tag(section)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 240)
        }
        .padding(24)
    }

    private var guide: some View {
        LazyVStack(alignment: .leading, spacing: 16) {
            guideCard(
                systemImage: "doc.badge.plus",
                titleKey: "xomo.help.guide.open.title",
                bodyKey: "xomo.help.guide.open.body"
            )
            guideCard(
                systemImage: "square.grid.2x2",
                titleKey: "xomo.help.guide.components.title",
                bodyKey: "xomo.help.guide.components.body"
            )
            guideCard(
                systemImage: "f.square",
                titleKey: "xomo.help.guide.figma.title",
                bodyKey: "xomo.help.guide.figma.body"
            )
            guideCard(
                systemImage: "square.and.arrow.up",
                titleKey: "xomo.help.guide.save.title",
                bodyKey: "xomo.help.guide.save.body"
            )
        }
    }

    private func guideCard(systemImage: String, titleKey: String, bodyKey: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.text(titleKey)).font(.headline)
                Text(L10n.text(bodyKey))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var shortcutReference: some View {
        LazyVStack(alignment: .leading, spacing: 20) {
            ForEach(XomoHelpContent.shortcutGroups) { group in
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.text(group.titleKey))
                        .font(.headline)
                    ForEach(group.shortcuts) { shortcut in
                        HStack {
                            Text(L10n.text(shortcut.titleKey))
                            Spacer()
                            Text(shortcut.keys)
                                .font(.system(.body, design: .monospaced).weight(.medium))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .font(.callout)
                    }
                }
            }
        }
    }
}

@MainActor
final class XomoHelpWindowPresenter: NSObject, NSWindowDelegate {
    static let shared = XomoHelpWindowPresenter()

    private var window: NSWindow?

    private override init() {
        super.init()
    }

    func open(section: XomoHelpSection) {
        let rootView = XomoHelpView(section: section) { [weak self] in
            self?.window?.close()
        }
        let hostingController = NSHostingController(rootView: rootView)

        if let window {
            window.contentViewController = hostingController
            show(window)
            return
        }

        let window = NSWindow(contentViewController: hostingController)
        window.title = L10n.text("xomo.help.windowTitle")
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.setContentSize(XomoHelpView.defaultWindowSize)
        window.minSize = CGSize(width: 560, height: 480)
        WindowChrome.applySeaSalt(to: window)
        window.center()
        self.window = window
        show(window)
    }

    private func show(_ window: NSWindow) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

struct XomoHelpCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .help) {
            Button(L10n.text("xomo.help.guide")) {
                XomoHelpWindowPresenter.shared.open(section: .guide)
            }
            .keyboardShortcut("?", modifiers: [.command])
            Button(L10n.text("xomo.help.shortcuts")) {
                XomoHelpWindowPresenter.shared.open(section: .shortcuts)
            }
        }
    }
}

struct XomoSupportCommands: Commands {
    var body: some Commands {
        XomoHelpCommands()
        CommandGroup(replacing: .appInfo) {
            Button(L10n.text("about.menuItem")) {
                AboutWindowPresenter.shared.open()
            }
        }
    }
}
