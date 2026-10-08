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
    @Environment(\.openWindow) private var openWindow

    init() {
        SomeIMUpdateController.shared.start()
    }

    private var editorWindowScene: some Scene {
        let openWindow = openWindow
        let applicationDelegate = applicationDelegate
        DispatchQueue.main.async {
            applicationDelegate.bindEditorWindowOpener {
                openWindow(id: XomoEditorWindowScene.identifier)
            }
        }
        return WindowGroup(id: XomoEditorWindowScene.identifier) {
            XomoEditorWorkspaceView()
        }
        .commands {
            SomeIMUpdateCommands()
            XomoFileCommands()
            XomoEditCommands()
            XomoImageCommands()
            XomoLayerCommands()
            XomoSelectCommands()
            XomoFilterCommands()
            XomoViewCommands()
            XomoWindowCommands()
            XomoSupportCommands()
        }
    }

    var body: some Scene {
        editorWindowScene
    }
}

enum XomoEditorWindowScene {
    static let identifier = "xomo-editor-window"
}


@MainActor
final class XomoApplicationDelegate: NSObject, NSApplicationDelegate {
    private let terminationCoordinator = XomoApplicationTerminationCoordinator()

    func bindEditorWindowOpener(_ openWindow: @escaping @MainActor () -> Void) {
        XomoExternalDocumentOpenCoordinator.shared.bindEditorWindowOpener(openWindow)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        let coordinator = XomoExternalDocumentOpenCoordinator.shared
        coordinator.open(urls)
        coordinator.ensureEditorWindow()
    }

    func applicationWillTerminate(_ notification: Notification) {
        XomoAutomationServer.shared.stop()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        terminationCoordinator.requestTermination { shouldTerminate in
            sender.reply(toApplicationShouldTerminate: shouldTerminate)
        }
    }
}
