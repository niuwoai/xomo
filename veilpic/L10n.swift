//
//  L10n.swift
//  veilpic
//
//  Created by Codex on 2026/5/20.
//

import Foundation

nonisolated enum L10n {
    static func text(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: Locale.current, arguments: arguments)
    }
}
