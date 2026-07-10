//
//  veilpicApp.swift
//  veilpic
//
//  Created by rocky on 2026/5/19.
//

import AppKit
import SwiftUI

@main
struct veilpicApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel = MenuBarUploadViewModel.shared

    var body: some Scene {
        MenuBarExtra {
            ContentView(viewModel: viewModel)
        } label: {
            Label {
                Text(L10n.text("app.name"))
            } icon: {
                Image("MenuBarIcon")
            }
        }
        .menuBarExtraStyle(.window)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(L10n.text("about.menuItem")) {
                    AboutWindowPresenter.shared.open()
                }
            }
        }

        Settings {
            StorageSettingsView(viewModel: viewModel, mode: .settings)
        }
    }
}

enum SettingsPresentationMode {
    case onboarding
    case settings
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        DockVisibilitySettings.shared.applyActivationPolicy()
        GlobalScreenshotShortcutManager.shared.setup(viewModel: .shared)

#if DEBUG
        if ImageEditorDevelopmentLaunch.shouldOpenEditor {
            DispatchQueue.main.async {
                ImageEditorWindowPresenter.shared.openDevelopmentSample()
            }
            return
        }
#endif

        guard LaunchGuide.shouldOpenSettings(profile: MenuBarUploadViewModel.shared.profile) else {
            return
        }

        SettingsWindowPresenter.shared.open(mode: .onboarding)
    }

    func applicationWillTerminate(_ notification: Notification) {
        GlobalScreenshotShortcutManager.shared.unregisterAll()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            MainWindowPresenter.shared.open()
        }

        return true
    }
}

enum ImageEditorDevelopmentLaunch {
    static var shouldOpenEditor: Bool {
#if DEBUG
        shouldOpenEditor(
            isDebugBuild: true,
            environment: ProcessInfo.processInfo.environment,
            isRunningXCTest: NSClassFromString("XCTestCase") != nil
        )
#else
        false
#endif
    }

    static func shouldOpenEditor(
        isDebugBuild: Bool,
        environment: [String: String],
        isRunningXCTest: Bool
    ) -> Bool {
        isDebugBuild
            && environment["XCTestConfigurationFilePath"] == nil
            && !isRunningXCTest
    }
}

final class MainWindowPresenter: NSObject, NSWindowDelegate {
    static let shared = MainWindowPresenter()

    private var window: NSWindow?

    private override init() {
        super.init()
    }

    func open() {
        let rootView = MainWindowView(viewModel: .shared)
        let hostingController = NSHostingController(rootView: rootView)

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
        window.setContentSize(NSSize(width: 680, height: 720))
        window.minSize = NSSize(width: 560, height: 560)
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

    private override init() {
        super.init()
    }

    func open(mode: SettingsPresentationMode) {
        let rootView = StorageSettingsView(viewModel: .shared, mode: mode)
        let hostingController = NSHostingController(rootView: rootView)

        if let window {
            window.contentViewController = hostingController
            window.title = mode == .onboarding ? L10n.text("settings.title.onboarding") : L10n.text("settings.title")
            show(window)
            return
        }

        let window = NSWindow(contentViewController: hostingController)
        window.title = mode == .onboarding ? L10n.text("settings.title.onboarding") : L10n.text("settings.title")
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        WindowChrome.applySeaSalt(to: window)
        window.center()
        self.window = window
        show(window)
    }

    func openFromMenuBar(mode: SettingsPresentationMode) {
        let menuBarWindow = NSApplication.shared.keyWindow
        open(mode: mode)

        if let menuBarWindow, menuBarWindow !== window {
            menuBarWindow.close()
        }
    }

    func close() {
        window?.close()
        LaunchGuide.markSettingsSeen()
    }

    private func show(_ window: NSWindow) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        if MenuBarUploadViewModel.shared.profile.isReadyForUpload {
            LaunchGuide.markSettingsSeen()
        }
    }
}

final class ImageEditorWindowPresenter: NSObject, NSWindowDelegate {
    static let shared = ImageEditorWindowPresenter()

    private var window: NSWindow?

    private override init() {
        super.init()
    }

    func open(image: NSImage, sourceName: String, onApply: @escaping (NSImage) -> Void) {
        let rootView = ImageEditorView(sourceName: sourceName, image: image, onApply: onApply)
        present(rootView: rootView)
    }

    private func present(rootView: ImageEditorView) {
        let hostingController = NSHostingController(rootView: rootView)

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
        window.titlebarAppearsTransparent = false
        window.backgroundColor = ImageEditorTheme.window
        window.center()
        self.window = window
        show(window)
    }

#if DEBUG
    func openDevelopmentSample() {
        let sourceName = L10n.text("imageEditor.developmentSampleName")
        let viewModel = ImageEditorViewModel(
            document: developmentSampleDocument(sourceName: sourceName),
            onApply: { _ in }
        )
        present(rootView: ImageEditorView(viewModel: viewModel))
    }

    private func developmentSampleDocument(sourceName: String) -> ImageEditorDocument {
        let size = NSSize(width: 1600, height: 1000)
        let background = NSImage.rendered(size: size) { rect in
            NSColor(srgbRed: 0.08, green: 0.10, blue: 0.14, alpha: 1).setFill()
            rect.fill()
        } ?? NSImage.transparent(size: size)

        let editableShapes = NSImage.rendered(size: size) { _ in
            NSColor(srgbRed: 0.12, green: 0.45, blue: 0.86, alpha: 1).setFill()
            CGRect(x: 110, y: 120, width: 620, height: 680).fill()

            NSColor(srgbRed: 0.96, green: 0.58, blue: 0.20, alpha: 1).setFill()
            NSBezierPath(ovalIn: CGRect(x: 760, y: 280, width: 520, height: 520)).fill()

            NSColor(srgbRed: 0.92, green: 0.94, blue: 0.98, alpha: 1).setFill()
            CGRect(x: 860, y: 120, width: 520, height: 110).fill()
        } ?? NSImage.transparent(size: size)

        var document = ImageEditorDocument(sourceName: sourceName, image: background)
        guard let layerIndex = document.selectedLayerIndex else { return document }
        document.layers[layerIndex].name = L10n.text("imageEditor.developmentSampleLayerName")
        document.layers[layerIndex].image = editableShapes
        return document
    }
#endif

    private func show(_ window: NSWindow) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

enum LaunchGuide {
    private static let settingsSeenKey = "veilpic.launchGuide.settingsSeen.v1"

    static func shouldOpenSettings(profile: StorageProfile) -> Bool {
        !UserDefaults.standard.bool(forKey: settingsSeenKey) || !profile.isReadyForUpload
    }

    static func markSettingsSeen() {
        UserDefaults.standard.set(true, forKey: settingsSeenKey)
    }
}
