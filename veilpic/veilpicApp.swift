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

        guard LaunchGuide.shouldOpenSettings(profile: MenuBarUploadViewModel.shared.profile) else {
            return
        }

        SettingsWindowPresenter.shared.open(mode: .onboarding)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            MainWindowPresenter.shared.open()
        }

        return true
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

enum LaunchGuide {
    private static let settingsSeenKey = "veilpic.launchGuide.settingsSeen.v1"

    static func shouldOpenSettings(profile: StorageProfile) -> Bool {
        !UserDefaults.standard.bool(forKey: settingsSeenKey) || !profile.isReadyForUpload
    }

    static func markSettingsSeen() {
        UserDefaults.standard.set(true, forKey: settingsSeenKey)
    }
}
