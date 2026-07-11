import AppKit
import SwiftUI

// Temporary compatibility bridge for the retired tray workflow. These presenters
// are no longer reachable from Xomo's app lifecycle and will be removed with the
// remaining tray modules in phase 0.
final class MainWindowPresenter: NSObject, NSWindowDelegate {
    static let shared = MainWindowPresenter()

    private var window: NSWindow?

    func open() {
        let hostingController = NSHostingController(rootView: MainWindowView(viewModel: .shared))
        present(hostingController, size: NSSize(width: 680, height: 720), minimumSize: NSSize(width: 560, height: 560))
    }

    private func present(_ hostingController: NSHostingController<some View>, size: NSSize, minimumSize: NSSize) {
        if let window {
            window.contentViewController = hostingController
            show(window)
            return
        }

        let window = NSWindow(contentViewController: hostingController)
        window.title = L10n.text("app.name")
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.setContentSize(size)
        window.minSize = minimumSize
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

final class SettingsWindowPresenter: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowPresenter()

    private var window: NSWindow?

    func openFromMenuBar(mode: SettingsPresentationMode) {
        let hostingController = NSHostingController(rootView: StorageSettingsView(viewModel: .shared, mode: mode))

        if let window {
            window.contentViewController = hostingController
            show(window)
            return
        }

        let window = NSWindow(contentViewController: hostingController)
        window.title = L10n.text("settings.title")
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        WindowChrome.applySeaSalt(to: window)
        window.center()
        self.window = window
        show(window)
    }

    func close() {
        window?.close()
    }

    private func show(_ window: NSWindow) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

final class ImageEditorWindowPresenter: NSObject, NSWindowDelegate {
    static let shared = ImageEditorWindowPresenter()

    private var window: NSWindow?

    func open(image: NSImage, sourceName: String, onApply: @escaping (NSImage) -> Void) {
        let hostingController = NSHostingController(rootView: ImageEditorView(sourceName: sourceName, image: image, onApply: onApply))

        if let window {
            window.contentViewController = hostingController
            show(window)
            return
        }

        let window = NSWindow(contentViewController: hostingController)
        window.title = L10n.text("imageEditor.window.title")
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.setContentSize(NSSize(width: 1440, height: 900))
        window.minSize = NSSize(width: 1160, height: 720)
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = ImageEditorTheme.window
        window.center()
        self.window = window
        show(window)
    }

    private func show(_ window: NSWindow) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
