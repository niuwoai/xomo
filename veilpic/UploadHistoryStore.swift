//
//  UploadHistoryStore.swift
//  veilpic
//
//  Created by Codex on 2026/5/20.
//

import Foundation

protocol UploadHistoryStoring {
    func load() -> [UploadHistoryItem]
    func append(_ item: UploadHistoryItem, to history: [UploadHistoryItem]) -> [UploadHistoryItem]
    func remove(_ item: UploadHistoryItem, from history: [UploadHistoryItem]) -> [UploadHistoryItem]
    func clear()
}

final class UploadHistoryStore: UploadHistoryStoring {
    private let defaultsKey = "veilpic.uploadHistory.v1"
    private let maximumItems = 80

    func load() -> [UploadHistoryItem] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let items = try? JSONDecoder().decode([UploadHistoryItem].self, from: data)
        else {
            return []
        }

        return Array(items.prefix(maximumItems))
    }

    func append(_ item: UploadHistoryItem, to history: [UploadHistoryItem]) -> [UploadHistoryItem] {
        let primaryURL = item.primaryURL
        let remaining = history.filter { $0.primaryURL != primaryURL }
        let updated = Array(([item] + remaining).prefix(maximumItems))
        save(updated)
        return updated
    }

    func remove(_ item: UploadHistoryItem, from history: [UploadHistoryItem]) -> [UploadHistoryItem] {
        let updated = history.filter { $0.id != item.id }
        save(updated)
        return updated
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }

    private func save(_ history: [UploadHistoryItem]) {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}
