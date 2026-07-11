//
//  veilpicApp.swift
//  veilpic
//
//  Created by rocky on 2026/5/19.
//

import AppKit
import OSLog
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

#if DEBUG
        if ImageEditorDevelopmentLaunch.shouldOpenEditor {
            ImageEditorDevelopmentStartupMetrics.record("applicationDidFinishLaunching")
            ImageEditorWindowPresenter.shared.openDevelopmentSample()
            DispatchQueue.main.async {
                GlobalScreenshotShortcutManager.shared.setup(viewModel: .shared)
            }
            return
        }
#endif

        GlobalScreenshotShortcutManager.shared.setup(viewModel: .shared)

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

    private func present<Content: View>(rootView: Content) {
        let hostingController = NSHostingController(rootView: rootView)
#if DEBUG
        ImageEditorDevelopmentStartupMetrics.record("hostingControllerBuilt")
#endif

        if let window {
            window.contentViewController = hostingController
#if DEBUG
            ImageEditorDevelopmentStartupMetrics.record("windowContentAssigned")
#endif
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
        presentDevelopmentSampleEditor()
    }

    private func presentDevelopmentSampleEditor() {
        ImageEditorDevelopmentStartupMetrics.record("editorConstructionStarted")
        let sourceName = L10n.text("imageEditor.developmentSampleName")
        let document = developmentSampleDocument(sourceName: sourceName)
        ImageEditorDevelopmentStartupMetrics.record("sampleDocumentBuilt")
        let viewModel = ImageEditorViewModel(
            document: document,
            initialCompositeImage: document.layers.first?.image,
            onApply: { _ in }
        )
        ImageEditorDevelopmentStartupMetrics.record("viewModelBuilt")
        _ = viewModel.currentImage
        ImageEditorDevelopmentStartupMetrics.record("firstCompositeBuilt")
        present(rootView: ImageEditorView(viewModel: viewModel))
        ImageEditorDevelopmentStartupMetrics.record("editorWindowDisplayed")
    }

    private func developmentSampleDocument(sourceName: String) -> ImageEditorDocument {
        let size = NSSize(width: 960, height: 600)
        let background = NSImage.transparent(size: size)

        var document = ImageEditorDocument(sourceName: sourceName, image: background)
        guard let layerIndex = document.selectedLayerIndex else { return document }
        document.layers[layerIndex].name = L10n.text("imageEditor.developmentSampleLayerName")
        return document
    }
#endif

    private func show(_ window: NSWindow) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

#if DEBUG
private enum ImageEditorDevelopmentStartupMetrics {
    private static let logger = Logger(subsystem: "im.some.xomo", category: "DebugStartup")
    private static let startedAt = ProcessInfo.processInfo.systemUptime

    static func record(_ phase: String) {
        let elapsedMilliseconds = Int((ProcessInfo.processInfo.systemUptime - startedAt) * 1_000)
        logger.notice("phase=\(phase, privacy: .public) elapsed_ms=\(elapsedMilliseconds, privacy: .public)")
    }
}

#endif

enum LaunchGuide {
    private static let settingsSeenKey = "veilpic.launchGuide.settingsSeen.v1"

    static func shouldOpenSettings(profile: StorageProfile) -> Bool {
        !UserDefaults.standard.bool(forKey: settingsSeenKey) || !profile.isReadyForUpload
    }

    static func markSettingsSeen() {
        UserDefaults.standard.set(true, forKey: settingsSeenKey)
    }
}
