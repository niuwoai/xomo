import Foundation
import Testing
@testable import musepic

@Suite(.serialized)
struct ClipboardImageWriterTests {
    @Test func clipboardFilesUseLocalCachesInsteadOfDownloads() throws {
        let fileManager = FileManager.default
        let cacheDirectory = ClipboardImageWriter.clipboardCacheDirectory(fileManager: fileManager)
            .standardizedFileURL
        let userCachesDirectory = try #require(
            fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?.standardizedFileURL
        )
        let downloadsDirectory = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask)
            .first?
            .standardizedFileURL

        #expect(cacheDirectory.path.hasPrefix(userCachesDirectory.path + "/"))
        #expect(cacheDirectory.path.hasSuffix(ClipboardImageWriter.clipboardCacheFolderName))
        #expect(downloadsDirectory.map { !cacheDirectory.path.hasPrefix($0.path + "/") } ?? true)
    }
}
