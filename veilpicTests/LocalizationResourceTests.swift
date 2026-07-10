//
//  LocalizationResourceTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/10.
//

import Foundation
import Testing

struct LocalizationResourceTests {
    private static let supportedLocalizationIDs: Set<String> = ["zh-Hans", "en", "ja"]
    private static let supportedStringTables: Set<String> = ["InfoPlist.strings", "Localizable.strings"]

    @Test func appShipsOnlyChineseEnglishAndJapaneseLocalizations() throws {
        let paths = try Self.repositoryPaths()
        let localizations = try FileManager.default.contentsOfDirectory(
            at: paths.appDirectory,
            includingPropertiesForKeys: nil
        )
            .filter { $0.pathExtension == "lproj" }
            .map { $0.deletingPathExtension().lastPathComponent }

        #expect(Set(localizations) == Self.supportedLocalizationIDs)

        let projectText = try String(contentsOf: paths.projectFile, encoding: .utf8)
        #expect(projectText.contains("developmentRegion = en;"))
        #expect(Self.knownRegions(in: projectText) == Self.supportedLocalizationIDs)
    }

    @Test func supportedLocalizationTablesKeepMatchingKeys() throws {
        let paths = try Self.repositoryPaths()

        for tableName in ["Localizable", "InfoPlist"] {
            let referenceKeys = try Self.stringTableKeys(
                tableName: tableName,
                localizationID: "en",
                appDirectory: paths.appDirectory
            )

            for localizationID in Self.supportedLocalizationIDs {
                let localizedKeys = try Self.stringTableKeys(
                    tableName: tableName,
                    localizationID: localizationID,
                    appDirectory: paths.appDirectory
                )

                #expect(localizedKeys == referenceKeys)
            }
        }
    }

    @Test func supportedLocalizationDirectoriesShipOnlyTrackedStringTables() throws {
        let paths = try Self.repositoryPaths()

        for localizationID in Self.supportedLocalizationIDs {
            let directory = paths.appDirectory.appendingPathComponent("\(localizationID).lproj", isDirectory: true)
            let filenames = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            )
                .filter { $0.pathExtension == "strings" }
                .map(\.lastPathComponent)

            #expect(Set(filenames) == Self.supportedStringTables)
        }
    }

    private static func knownRegions(in projectText: String) -> Set<String> {
        guard let start = projectText.range(of: "knownRegions = (") else { return [] }
        let remaining = projectText[start.upperBound...]
        guard let end = remaining.range(of: ");") else { return [] }

        return Set(
            remaining[..<end.lowerBound]
                .split(separator: "\n")
                .map {
                    $0
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .trimmingCharacters(in: CharacterSet(charactersIn: ",\""))
                }
                .filter { !$0.isEmpty }
        )
    }

    private static func stringTableKeys(
        tableName: String,
        localizationID: String,
        appDirectory: URL
    ) throws -> Set<String> {
        let tableURL = appDirectory
            .appendingPathComponent("\(localizationID).lproj", isDirectory: true)
            .appendingPathComponent("\(tableName).strings")
        let dictionary = try #require(NSDictionary(contentsOf: tableURL) as? [String: String])
        return Set(dictionary.keys)
    }

    private static func repositoryPaths() throws -> (appDirectory: URL, projectFile: URL) {
        let testFile = URL(fileURLWithPath: #filePath)
        let repositoryRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        return (
            appDirectory: repositoryRoot.appendingPathComponent("veilpic", isDirectory: true),
            projectFile: repositoryRoot
                .appendingPathComponent("veilpic.xcodeproj", isDirectory: true)
                .appendingPathComponent("project.pbxproj")
        )
    }
}
