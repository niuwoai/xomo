//
//  AboutView.swift
//  veilpic
//
//  Created by Codex on 2026/7/8.
//

import AppKit
import SwiftUI

struct AboutView: View {
    static let defaultWindowSize = CGSize(width: 520, height: 360)

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .center, spacing: 18) {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 104, height: 104)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.text("app.name"))
                            .font(.title2.weight(.semibold))

                        Text(L10n.format("about.versionFormat", appVersion))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)

                        Text(L10n.text("about.summary"))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Link(destination: URL(string: "https://83d.me")!) {
                        Label(L10n.text("about.authorHomepage"), systemImage: "link")
                    }

                    Link(destination: URL(string: "https://83d.me/zh/products/qingtu")!) {
                        Label(L10n.text("about.productPage"), systemImage: "photo.on.rectangle.angled")
                    }
                }
                .font(.subheadline.weight(.medium))
                .buttonStyle(.link)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            HStack {
                Text(copyrightText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button(L10n.text("action.done")) {
                    NSApp.keyWindow?.close()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.72))
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(height: 1)
            }
        }
        .frame(width: Self.defaultWindowSize.width, height: Self.defaultWindowSize.height)
        .background(Color(nsColor: .windowBackgroundColor))
        .focusable(false)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? L10n.text("about.unknownVersion")
    }

    private var copyrightText: String {
        let year = Calendar.current.component(.year, from: Date())
        return L10n.format("about.copyright", year)
    }
}

final class AboutWindowPresenter: NSObject, NSWindowDelegate {
    static let shared = AboutWindowPresenter()

    private var window: NSWindow?

    private override init() {
        super.init()
    }

    func open() {
        let hostingController = NSHostingController(rootView: AboutView())

        if let window {
            window.contentViewController = hostingController
            show(window)
            return
        }

        let window = NSWindow(contentViewController: hostingController)
        window.title = L10n.format("about.windowTitle", L10n.text("app.name"))
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.setContentSize(AboutView.defaultWindowSize)
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
