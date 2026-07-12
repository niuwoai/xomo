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

    var body: some Scene {
        WindowGroup {
            XomoEditorWorkspaceView()
        }
        .commands {
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
    func applicationWillTerminate(_ notification: Notification) {
        XomoAutomationServer.shared.stop()
    }
}
