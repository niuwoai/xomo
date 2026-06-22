//
//  DockVisibilitySettings.swift
//  veilpic
//
//  Created by Codex on 2026/6/3.
//

import AppKit
import Combine
import Foundation

@MainActor
final class DockVisibilitySettings: ObservableObject {
    static let shared = DockVisibilitySettings()

    private static let hideDockIconKey = "veilpic.dock.hideIcon.v1"

    @Published var hideDockIcon: Bool {
        didSet {
            guard oldValue != hideDockIcon else { return }
            UserDefaults.standard.set(hideDockIcon, forKey: Self.hideDockIconKey)
            applyActivationPolicy()
        }
    }

    private init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Self.hideDockIconKey) == nil {
            defaults.set(true, forKey: Self.hideDockIconKey)
            hideDockIcon = true
        } else {
            hideDockIcon = defaults.bool(forKey: Self.hideDockIconKey)
        }
    }

    func applyActivationPolicy() {
        let targetPolicy: NSApplication.ActivationPolicy = hideDockIcon ? .accessory : .regular
        guard NSApp.activationPolicy() != targetPolicy else { return }
        NSApp.setActivationPolicy(targetPolicy)

        if targetPolicy == .regular {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
