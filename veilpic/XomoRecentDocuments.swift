//
//  XomoRecentDocuments.swift
//  veilpic
//
//  Created by Codex on 2026/8/25.
//

import AppKit
import Combine
import Foundation

@MainActor
protocol XomoRecentDocumentControlling: AnyObject {
    var recentDocumentURLs: [URL] { get }
    var maximumRecentDocumentCount: Int { get }
    func noteNewRecentDocumentURL(_ url: URL)
    func clearRecentDocuments(_ sender: Any?)
}

extension NSDocumentController: XomoRecentDocumentControlling {}

enum XomoRecentDocumentPolicy {
    static let fallbackLimit = 10

    static func availableURLs(
        from urls: [URL],
        limit: Int,
        fileExists: (String) -> Bool
    ) -> [URL] {
        let resolvedLimit = max(0, limit)
        guard resolvedLimit > 0 else { return [] }

        var seenPaths: Set<String> = []
        var result: [URL] = []
        result.reserveCapacity(min(urls.count, resolvedLimit))

        for url in urls where result.count < resolvedLimit {
            guard url.isFileURL else { continue }
            let standardizedURL = url.standardizedFileURL
            let path = standardizedURL.path
            guard fileExists(path), seenPaths.insert(path).inserted else { continue }
            result.append(standardizedURL)
        }
        return result
    }
}

@MainActor
final class XomoRecentDocumentStore: ObservableObject {
    static let shared = XomoRecentDocumentStore()

    @Published private(set) var urls: [URL] = []

    private let controller: XomoRecentDocumentControlling
    private let fileExists: (String) -> Bool

    convenience init() {
        self.init(controller: NSDocumentController.shared)
    }

    init(
        controller: XomoRecentDocumentControlling,
        fileExists: @escaping (String) -> Bool = FileManager.default.fileExists(atPath:)
    ) {
        self.controller = controller
        self.fileExists = fileExists
        refresh()
    }

    func noteOpened(_ url: URL) {
        guard url.isFileURL, fileExists(url.path) else { return }
        controller.noteNewRecentDocumentURL(url.standardizedFileURL)
        refresh()
    }

    func clear() {
        controller.clearRecentDocuments(nil)
        refresh()
    }

    func refresh() {
        let limit = controller.maximumRecentDocumentCount > 0
            ? controller.maximumRecentDocumentCount
            : XomoRecentDocumentPolicy.fallbackLimit
        urls = XomoRecentDocumentPolicy.availableURLs(
            from: controller.recentDocumentURLs,
            limit: limit,
            fileExists: fileExists
        )
    }
}
