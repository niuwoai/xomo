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

    @Test func filterApplyActionIsLocalizedInEverySupportedLanguage() throws {
        let paths = try Self.repositoryPaths()
        let expectedValues = [
            "zh-Hans": "应用滤镜",
            "en": "Apply Filter",
            "ja": "フィルターを適用"
        ]

        for (localizationID, expectedValue) in expectedValues {
            let strings = try Self.stringTable(
                tableName: "Localizable",
                localizationID: localizationID,
                appDirectory: paths.appDirectory
            )

            #expect(strings["imageEditor.action.applyFilter"] == expectedValue)
        }
    }

    @Test func smudgeStrengthLabelIsLocalizedInEverySupportedLanguage() throws {
        let paths = try Self.repositoryPaths()
        let expectedValues = [
            "zh-Hans": "强度",
            "en": "Strength",
            "ja": "強さ"
        ]

        for (localizationID, expectedValue) in expectedValues {
            let strings = try Self.stringTable(
                tableName: "Localizable",
                localizationID: localizationID,
                appDirectory: paths.appDirectory
            )
            #expect(strings["imageEditor.option.strength"] == expectedValue)
        }
    }

    @Test func dodgeBurnExposureLabelIsLocalizedInEverySupportedLanguage() throws {
        let paths = try Self.repositoryPaths()
        let expectedValues = [
            "zh-Hans": "曝光度",
            "en": "Exposure",
            "ja": "露光量"
        ]

        for (localizationID, expectedValue) in expectedValues {
            let strings = try Self.stringTable(
                tableName: "Localizable",
                localizationID: localizationID,
                appDirectory: paths.appDirectory
            )
            #expect(strings["imageEditor.option.exposure"] == expectedValue)
        }
    }

    @Test func dodgeBurnToneRangesAreLocalizedInEverySupportedLanguage() throws {
        let paths = try Self.repositoryPaths()
        let expectedValues = [
            "zh-Hans": ["范围", "阴影", "中间调", "高光"],
            "en": ["Range", "Shadows", "Midtones", "Highlights"],
            "ja": ["範囲", "シャドウ", "中間調", "ハイライト"]
        ]
        let keys = [
            "imageEditor.option.toneRange",
            "imageEditor.toneRange.shadows",
            "imageEditor.toneRange.midtones",
            "imageEditor.toneRange.highlights"
        ]

        for (localizationID, expected) in expectedValues {
            let strings = try Self.stringTable(
                tableName: "Localizable",
                localizationID: localizationID,
                appDirectory: paths.appDirectory
            )
            #expect(keys.compactMap { strings[$0] } == expected)
        }
    }

    @Test func dodgeBurnProtectTonesIsLocalizedInEverySupportedLanguage() throws {
        let paths = try Self.repositoryPaths()
        let expectedValues = [
            "zh-Hans": ["保护色调", "保持颜色并减少高光和阴影剪切"],
            "en": ["Protect Tones", "Preserve color and reduce clipping in highlights and shadows"],
            "ja": ["階調を保護", "色を保ちながらハイライトとシャドウのクリッピングを抑えます"]
        ]
        let keys = [
            "imageEditor.option.protectTones",
            "imageEditor.option.protectTones.help"
        ]

        for (localizationID, expected) in expectedValues {
            let strings = try Self.stringTable(
                tableName: "Localizable",
                localizationID: localizationID,
                appDirectory: paths.appDirectory
            )
            #expect(keys.compactMap { strings[$0] } == expected)
        }
    }

    @Test func dodgeBurnAirbrushIsLocalizedInEverySupportedLanguage() throws {
        let paths = try Self.repositoryPaths()
        let expectedValues = [
            "zh-Hans": ["喷枪", "按住指针时逐渐累积减淡或加深效果"],
            "en": ["Airbrush", "Build up dodge or burn gradually while holding the pointer"],
            "ja": ["エアブラシ", "ポインタを押している間、覆い焼きまたは焼き込み効果を徐々に重ねます"]
        ]
        let keys = [
            "imageEditor.option.airbrush",
            "imageEditor.option.airbrush.help"
        ]

        for (localizationID, expected) in expectedValues {
            let strings = try Self.stringTable(
                tableName: "Localizable",
                localizationID: localizationID,
                appDirectory: paths.appDirectory
            )
            #expect(keys.compactMap { strings[$0] } == expected)
        }
    }

    @Test func dodgeBurnToneRangeShortcutsAreLocalizedInEverySupportedLanguage() throws {
        let paths = try Self.repositoryPaths()
        let expectedValues = [
            "zh-Hans": ["范围快捷键：%@ %@；%@ %@；%@ %@", "减淡/加深范围：%@（%@）"],
            "en": ["Range shortcuts: %@ %@ · %@ %@ · %@ %@", "Dodge/Burn range: %@ (%@)"],
            "ja": ["範囲ショートカット：%@ %@・%@ %@・%@ %@", "覆い焼き/焼き込み範囲：%@（%@）"]
        ]
        let keys = [
            "imageEditor.option.toneRange.help",
            "imageEditor.status.toneRangeShortcut"
        ]

        for (localizationID, expected) in expectedValues {
            let strings = try Self.stringTable(
                tableName: "Localizable",
                localizationID: localizationID,
                appDirectory: paths.appDirectory
            )
            #expect(keys.compactMap { strings[$0] } == expected)
        }
    }

    @Test func spongeModeShortcutsAreLocalizedInEverySupportedLanguage() throws {
        let paths = try Self.repositoryPaths()
        let expectedValues = [
            "zh-Hans": ["海绵模式快捷键：%@ %@；%@ %@", "海绵模式：%@（%@）"],
            "en": ["Sponge mode shortcuts: %@ %@ · %@ %@", "Sponge mode: %@ (%@)"],
            "ja": ["スポンジモードのショートカット：%@ %@・%@ %@", "スポンジモード：%@（%@）"]
        ]
        let keys = [
            "imageEditor.option.spongeMode.help",
            "imageEditor.status.spongeModeShortcut"
        ]

        for (localizationID, expected) in expectedValues {
            let strings = try Self.stringTable(
                tableName: "Localizable",
                localizationID: localizationID,
                appDirectory: paths.appDirectory
            )
            #expect(keys.compactMap { strings[$0] } == expected)
        }
    }

    @Test func spongeVibranceIsLocalizedInEverySupportedLanguage() throws {
        let paths = try Self.repositoryPaths()
        let expectedValues = [
            "zh-Hans": ["自然饱和", "减少完全饱和或完全去色附近的颜色剪切。"],
            "en": ["Vibrance", "Reduce clipping near fully saturated or desaturated colors."],
            "ja": ["自然な彩度", "完全な彩度または彩度ゼロ付近でのクリッピングを抑えます。"]
        ]
        let keys = [
            "imageEditor.option.spongeVibrance",
            "imageEditor.option.spongeVibrance.help"
        ]

        for (localizationID, expected) in expectedValues {
            let strings = try Self.stringTable(
                tableName: "Localizable",
                localizationID: localizationID,
                appDirectory: paths.appDirectory
            )
            #expect(keys.compactMap { strings[$0] } == expected)
        }
    }

    @Test func spongePressureSizeHelpIsLocalizedInEverySupportedLanguage() throws {
        let paths = try Self.repositoryPaths()
        let expectedValues = [
            "zh-Hans": "使用数位笔压力控制海绵画笔大小",
            "en": "Use pen pressure to control the Sponge brush size",
            "ja": "ペンの筆圧でスポンジブラシのサイズを制御します"
        ]

        for (localizationID, expected) in expectedValues {
            let strings = try Self.stringTable(
                tableName: "Localizable",
                localizationID: localizationID,
                appDirectory: paths.appDirectory
            )
            #expect(strings["imageEditor.option.spongePressureSize.help"] == expected)
        }
    }

    @Test func smudgePressureSizeHelpIsLocalizedInEverySupportedLanguage() throws {
        let paths = try Self.repositoryPaths()
        let expectedValues = [
            "zh-Hans": "使用数位笔压力控制涂抹画笔大小",
            "en": "Use pen pressure to control the Smudge brush size",
            "ja": "ペンの筆圧で指先ブラシのサイズを制御します"
        ]

        for (localizationID, expected) in expectedValues {
            let strings = try Self.stringTable(
                tableName: "Localizable",
                localizationID: localizationID,
                appDirectory: paths.appDirectory
            )
            #expect(strings["imageEditor.option.smudgePressureSize.help"] == expected)
        }
    }

    @Test func blurSharpenPressureSizeHelpIsLocalizedInEverySupportedLanguage() throws {
        let paths = try Self.repositoryPaths()
        let expectedValues = [
            "zh-Hans": "使用数位笔压力控制模糊或锐化画笔大小",
            "en": "Use pen pressure to control the Blur or Sharpen brush size",
            "ja": "ペンの筆圧でぼかしまたはシャープブラシのサイズを制御します"
        ]

        for (localizationID, expected) in expectedValues {
            let strings = try Self.stringTable(
                tableName: "Localizable",
                localizationID: localizationID,
                appDirectory: paths.appDirectory
            )
            #expect(strings["imageEditor.option.blurSharpenPressureSize.help"] == expected)
        }
    }

    @Test func sampledBrushPressureSizeHelpIsLocalizedInEverySupportedLanguage() throws {
        let paths = try Self.repositoryPaths()
        let expectedValues = [
            "zh-Hans": "使用数位笔压力控制仿制图章或修复画笔大小",
            "en": "Use pen pressure to control the Clone Stamp or Healing Brush size",
            "ja": "ペンの筆圧でコピースタンプまたは修復ブラシのサイズを制御します"
        ]

        for (localizationID, expected) in expectedValues {
            let strings = try Self.stringTable(
                tableName: "Localizable",
                localizationID: localizationID,
                appDirectory: paths.appDirectory
            )
            #expect(strings["imageEditor.option.sampledBrushPressureSize.help"] == expected)
        }
    }

    @Test func retouchPressureSensitivityHelpIsLocalizedInEverySupportedLanguage() throws {
        let paths = try Self.repositoryPaths()
        let expectedValues = [
            "zh-Hans": "调整数位笔压力控制修饰画笔大小的灵敏度",
            "en": "Adjust how pen pressure changes the retouch brush size",
            "ja": "筆圧によるレタッチブラシサイズの変化感度を調整します"
        ]

        for (localizationID, expected) in expectedValues {
            let strings = try Self.stringTable(
                tableName: "Localizable",
                localizationID: localizationID,
                appDirectory: paths.appDirectory
            )
            #expect(strings["imageEditor.option.retouchPressureSensitivity.help"] == expected)
        }
    }

    @Test func clippingToolbarMixedStateIsLocalizedInEverySupportedLanguage() throws {
        let paths = try Self.repositoryPaths()
        let expectedValues = [
            "zh-Hans": ["未剪贴", "全部已剪贴", "部分已剪贴"],
            "en": ["Not clipped", "All clipped", "Partially clipped"],
            "ja": ["クリップなし", "すべてクリップ", "一部クリップ"]
        ]
        let keys = [
            "imageEditor.layer.clippingState.off",
            "imageEditor.layer.clippingState.on",
            "imageEditor.layer.clippingState.mixed"
        ]

        for (localizationID, expected) in expectedValues {
            let strings = try Self.stringTable(
                tableName: "Localizable",
                localizationID: localizationID,
                appDirectory: paths.appDirectory
            )
            #expect(keys.compactMap { strings[$0] } == expected)
        }
    }

    @Test func layerStyleToolbarEffectStateIsLocalizedInEverySupportedLanguage() throws {
        let paths = try Self.repositoryPaths()
        let expectedValues = [
            "zh-Hans": ["未启用", "全部已启用", "部分已启用"],
            "en": ["Not enabled", "Enabled for all", "Partially enabled"],
            "ja": ["無効", "すべて有効", "一部有効"]
        ]
        let keys = [
            "imageEditor.layer.effectState.off",
            "imageEditor.layer.effectState.on",
            "imageEditor.layer.effectState.mixed"
        ]

        for (localizationID, expected) in expectedValues {
            let strings = try Self.stringTable(
                tableName: "Localizable",
                localizationID: localizationID,
                appDirectory: paths.appDirectory
            )
            #expect(keys.compactMap { strings[$0] } == expected)
        }
    }

    @Test func layerStyleGlobalLightStateReusesLocalizedSelectionValues() throws {
        let paths = try Self.repositoryPaths()
        let expectedValues = [
            "zh-Hans": ["未启用", "全部已启用", "部分已启用"],
            "en": ["Not enabled", "Enabled for all", "Partially enabled"],
            "ja": ["無効", "すべて有効", "一部有効"]
        ]
        let keys = [
            "imageEditor.layer.effectState.off",
            "imageEditor.layer.effectState.on",
            "imageEditor.layer.effectState.mixed"
        ]

        for (localizationID, expected) in expectedValues {
            let strings = try Self.stringTable(
                tableName: "Localizable",
                localizationID: localizationID,
                appDirectory: paths.appDirectory
            )
            #expect(keys.compactMap { strings[$0] } == expected)
        }
    }

    @Test func layerStyleSatinInvertTriStateIsLocalizedInEverySupportedLanguage() throws {
        let paths = try Self.repositoryPaths()
        let expectedValues = [
            "zh-Hans": ["反相光泽", "未启用", "全部已启用", "部分已启用"],
            "en": ["Invert Satin", "Not enabled", "Enabled for all", "Partially enabled"],
            "ja": ["サテンを反転", "無効", "すべて有効", "一部有効"]
        ]
        let keys = [
            "imageEditor.properties.satinInvert",
            "imageEditor.layer.effectState.off",
            "imageEditor.layer.effectState.on",
            "imageEditor.layer.effectState.mixed"
        ]

        for (localizationID, expected) in expectedValues {
            let strings = try Self.stringTable(
                tableName: "Localizable",
                localizationID: localizationID,
                appDirectory: paths.appDirectory
            )
            #expect(keys.compactMap { strings[$0] } == expected)
        }
    }

    @Test func layerStyleStrokePositionMixedValueIsLocalizedInEverySupportedLanguage() throws {
        let paths = try Self.repositoryPaths()
        let expectedValues = [
            "zh-Hans": ["描边位置", "多个值", "外侧", "居中", "内侧"],
            "en": ["Stroke Position", "Multiple Values", "Outside", "Center", "Inside"],
            "ja": ["境界線の位置", "複数の値", "外側", "中央", "内側"]
        ]
        let keys = [
            "imageEditor.properties.strokePosition",
            "imageEditor.properties.multipleValues",
            "imageEditor.strokePosition.outside",
            "imageEditor.strokePosition.center",
            "imageEditor.strokePosition.inside"
        ]

        for (localizationID, expected) in expectedValues {
            let strings = try Self.stringTable(
                tableName: "Localizable",
                localizationID: localizationID,
                appDirectory: paths.appDirectory
            )
            #expect(keys.compactMap { strings[$0] } == expected)
        }
    }

    @Test func layerStyleStrokeFillTypeMixedValueIsLocalizedInEverySupportedLanguage() throws {
        let paths = try Self.repositoryPaths()
        let expectedValues = [
            "zh-Hans": ["描边填充", "多个值", "颜色", "渐变", "图案"],
            "en": ["Stroke Fill", "Multiple Values", "Color", "Gradient", "Pattern"],
            "ja": ["境界線の塗り", "複数の値", "カラー", "グラデーション", "パターン"]
        ]
        let keys = [
            "imageEditor.properties.strokeFillType",
            "imageEditor.properties.multipleValues",
            "imageEditor.strokeFillType.color",
            "imageEditor.strokeFillType.gradient",
            "imageEditor.strokeFillType.pattern"
        ]

        for (localizationID, expected) in expectedValues {
            let strings = try Self.stringTable(
                tableName: "Localizable",
                localizationID: localizationID,
                appDirectory: paths.appDirectory
            )
            #expect(keys.compactMap { strings[$0] } == expected)
        }
    }

    @Test func layerStyleStrokeGradientStyleMixedValueIsLocalizedInEverySupportedLanguage() throws {
        let paths = try Self.repositoryPaths()
        let expectedValues = [
            "zh-Hans": ["描边渐变样式", "多个值", "线性", "径向", "反射", "菱形"],
            "en": ["Stroke Gradient Style", "Multiple Values", "Linear", "Radial", "Reflected", "Diamond"],
            "ja": ["境界線グラデーションスタイル", "複数の値", "線形", "円形", "反射", "菱形"]
        ]
        let keys = [
            "imageEditor.properties.strokeGradientStyle",
            "imageEditor.properties.multipleValues",
            "imageEditor.gradientFill.style.linear",
            "imageEditor.gradientFill.style.radial",
            "imageEditor.gradientFill.style.reflected",
            "imageEditor.gradientFill.style.diamond"
        ]

        for (localizationID, expected) in expectedValues {
            let strings = try Self.stringTable(
                tableName: "Localizable",
                localizationID: localizationID,
                appDirectory: paths.appDirectory
            )
            #expect(keys.compactMap { strings[$0] } == expected)
        }
    }

    @Test func layerStyleStrokePatternKindMixedValueIsLocalizedInEverySupportedLanguage() throws {
        let paths = try Self.repositoryPaths()
        let expectedValues = [
            "zh-Hans": ["描边图案", "多个值", "棋盘", "斜线", "圆点"],
            "en": ["Stroke Pattern", "Multiple Values", "Checkerboard", "Diagonal Stripes", "Dots"],
            "ja": ["境界線パターン", "複数の値", "市松模様", "斜線", "ドット"]
        ]
        let keys = [
            "imageEditor.properties.strokePatternKind",
            "imageEditor.properties.multipleValues",
            "imageEditor.patternOverlay.checkerboard",
            "imageEditor.patternOverlay.diagonalStripes",
            "imageEditor.patternOverlay.dots"
        ]

        for (localizationID, expected) in expectedValues {
            let strings = try Self.stringTable(
                tableName: "Localizable",
                localizationID: localizationID,
                appDirectory: paths.appDirectory
            )
            #expect(keys.compactMap { strings[$0] } == expected)
        }
    }

    @Test func fingerPaintingIsLocalizedInEverySupportedLanguage() throws {
        let paths = try Self.repositoryPaths()
        let expectedValues = [
            "zh-Hans": ["手指绘画", "每次涂抹从当前前景色起笔，并沿拖动方向带出颜色"],
            "en": ["Finger Painting", "Start each Smudge stroke with the current foreground color"],
            "ja": ["フィンガーペイント", "現在の描画色で各ぼかしストロークを開始します"]
        ]
        let keys = [
            "imageEditor.option.fingerPainting",
            "imageEditor.option.fingerPainting.help"
        ]

        for (localizationID, expected) in expectedValues {
            let strings = try Self.stringTable(
                tableName: "Localizable",
                localizationID: localizationID,
                appDirectory: paths.appDirectory
            )
            #expect(keys.compactMap { strings[$0] } == expected)
        }
    }

    @Test func sampleAllLayersIsLocalizedInEverySupportedLanguage() throws {
        let paths = try Self.repositoryPaths()
        let expectedValues = [
            "zh-Hans": ["对所有图层取样", "从所有可见图层取样涂抹，并只写入当前图层"],
            "en": ["Sample All Layers", "Smudge visible pixels from all layers into the active layer"],
            "ja": ["全レイヤーを対象", "すべての表示レイヤーからぼかし、アクティブレイヤーにのみ描画します"]
        ]
        let keys = [
            "imageEditor.option.sampleAllLayers",
            "imageEditor.option.sampleAllLayers.help"
        ]

        for (localizationID, expected) in expectedValues {
            let strings = try Self.stringTable(
                tableName: "Localizable",
                localizationID: localizationID,
                appDirectory: paths.appDirectory
            )
            #expect(keys.compactMap { strings[$0] } == expected)
        }
    }

    @Test func spongeFlowSummaryIsLocalizedInEverySupportedLanguage() throws {
        let paths = try Self.repositoryPaths()
        let expectedValues = [
            "zh-Hans": "工具：%@ | 选区：%@ | 大小：%d px | 流量：%d%% | 硬度：%d%%",
            "en": "Tool: %@ | Selection: %@ | Size: %d px | Flow: %d%% | Hardness: %d%%",
            "ja": "ツール：%@ | 選択：%@ | サイズ：%d px | 流量：%d%% | 硬さ：%d%%"
        ]

        for (localizationID, expected) in expectedValues {
            let strings = try Self.stringTable(
                tableName: "Localizable",
                localizationID: localizationID,
                appDirectory: paths.appDirectory
            )
            #expect(strings["imageEditor.status.spongeOptionsPanelSummary"] == expected)
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
        Set(try stringTable(
            tableName: tableName,
            localizationID: localizationID,
            appDirectory: appDirectory
        ).keys)
    }

    private static func stringTable(
        tableName: String,
        localizationID: String,
        appDirectory: URL
    ) throws -> [String: String] {
        let tableURL = appDirectory
            .appendingPathComponent("\(localizationID).lproj", isDirectory: true)
            .appendingPathComponent("\(tableName).strings")
        return try #require(NSDictionary(contentsOf: tableURL) as? [String: String])
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
