//
//  LaunchAtLoginSettings.swift
//  veilpic
//
//  Created by Codex on 2026/5/20.
//

import Combine
import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginSettings: ObservableObject {
    @Published private(set) var isEnabled: Bool
    @Published var errorMessage: String?

    init() {
        isEnabled = Self.currentStatusIsEnabled
    }

    func refresh() {
        isEnabled = Self.currentStatusIsEnabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }

            errorMessage = nil
            refresh()
        } catch {
            errorMessage = error.localizedDescription
            refresh()
        }
    }

    private static var currentStatusIsEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }
}
