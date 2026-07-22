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
    @NSApplicationDelegateAdaptor(XomoApplicationDelegate.self) private var applicationDelegate

    init() {
        SomeIMUpdateController.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            XomoEditorWorkspaceView()
        }
        .commands {
            SomeIMUpdateCommands()

            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .appInfo) {
                Button(L10n.text("about.menuItem")) {
                    AboutWindowPresenter.shared.open()
                }
            }
        }
    }
}


@MainActor
final class XomoApplicationDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        XomoExternalDocumentOpenCoordinator.shared.open(urls)
    }

    func applicationWillTerminate(_ notification: Notification) {
        XomoAutomationServer.shared.stop()
    }
}
