//
//  veilpicApp.swift
//  veilpic
//
//  Created by rocky on 2026/5/19.
//

import SwiftUI

@main
struct veilpicApp: App {
    var body: some Scene {
        WindowGroup {
            XomoEditorWorkspaceView()
        }
        .defaultSize(width: 1440, height: 900)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(L10n.text("about.menuItem")) {
                    AboutWindowPresenter.shared.open()
                }
            }
        }
    }
}
