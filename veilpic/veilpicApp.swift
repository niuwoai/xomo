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
            Label("轻图", systemImage: "photo.on.rectangle.angled")
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
        guard LaunchGuide.shouldOpenSettings(profile: MenuBarUploadViewModel.shared.profile) else {
            return
        }

        SettingsWindowPresenter.shared.open(mode: .onboarding)
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
            window.title = mode == .onboarding ? "开始使用轻图" : "轻图设置"
            show(window)
            return
        }

        let window = NSWindow(contentViewController: hostingController)
        window.title = mode == .onboarding ? "开始使用轻图" : "轻图设置"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        self.window = window
        show(window)
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
