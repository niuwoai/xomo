//
//  ImageEditorPSD.swift
//  veilpic
//
//  Created by Codex on 2026/7/11.
//

import AppKit
import Compression
import Foundation
import UniformTypeIdentifiers

nonisolated enum ImageEditorPSDCodecError: LocalizedError, Sendable {
    case invalidFile
    case unsupportedDocument
    case unsupportedCompression
    case imageEncodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidFile:
            L10n.text("imageEditor.psd.error.invalid")
        case .unsupportedDocument:
            L10n.text("imageEditor.psd.error.unsupportedDocument")
        case .unsupportedCompression:
            L10n.text("imageEditor.psd.error.unsupportedCompression")
        case .imageEncodingFailed:
            L10n.text("imageEditor.psd.error.imageEncodingFailed")
        }
    }
}

enum ImageEditorPSDCodec {
    static var contentType: UTType {
        UTType(filenameExtension: "psd") ?? .data
    }

    static func encode(document: ImageEditorDocument) throws -> Data {
        let width = Int(document.canvasSize.width.rounded())
        let height = Int(document.canvasSize.height.rounded())
        guard width > 0, height > 0, width <= Int(Int32.max), height <= Int(Int32.max) else {
            throw ImageEditorPSDCodecError.unsupportedDocument
        }

        let exportLayers = try makeExportLayers(document: document, canvasHeight: height)

        var output = Data()
        output.appendASCII("8BPS")
        output.appendUInt16(1)
        output.append(Data(repeating: 0, count: 6))
        let exportedAlphaChannels = document.alphaChannels.prefix(52)
        output.appendUInt16(UInt16(4 + exportedAlphaChannels.count))
        output.appendUInt32(UInt32(height))
        output.appendUInt32(UInt32(width))
        output.appendUInt16(8)
        output.appendUInt16(3)
        output.appendUInt32(0)
        let imageResources = imageResourcesData(document: document)
        output.appendUInt32(UInt32(imageResources.count))
        output.append(imageResources)

        var layerInfo = Data()
        layerInfo.appendInt16(Int16(exportLayers.count))
        for item in exportLayers {
            layerInfo.append(layerRecord(item))
        }
        for item in exportLayers {
            for channel in item.channels {
                layerInfo.appendUInt16(0)
                layerInfo.append(channel.data)
            }
        }
        if layerInfo.count % 2 != 0 { layerInfo.append(0) }

        var layerAndMask = Data()
        layerAndMask.appendUInt32(UInt32(layerInfo.count))
        layerAndMask.append(layerInfo)
        layerAndMask.appendUInt32(0)
        output.appendUInt32(UInt32(layerAndMask.count))
        output.append(layerAndMask)

        guard let composite = rgbaChannels(image: document.compositedImage, width: width, height: height) else {
            throw ImageEditorPSDCodecError.imageEncodingFailed
        }
        output.appendUInt16(0)
        output.append(composite.red)
        output.append(composite.green)
        output.append(composite.blue)
        output.append(composite.alpha)
        for channel in exportedAlphaChannels {
            let mask = channel.mask.resizedNearest(to: CGSize(width: width, height: height))
            output.append(contentsOf: mask.alpha)
        }
        return output
    }

    private static func imageResourcesData(document: ImageEditorDocument) -> Data {
        var output = pathResourceData(
            document.savedPaths,
            canvasSize: document.canvasSize
        )
        let alphaChannels = Array(document.alphaChannels.prefix(52))
        guard !alphaChannels.isEmpty else { return output }

        var names = Data()
        for channel in alphaChannels {
            names.appendPascalString(channel.name, alignment: 2)
        }
        output.appendASCII("8BIM")
        output.appendUInt16(1006)
        output.appendPascalString("", alignment: 2)
        output.appendUInt32(UInt32(names.count))
        output.append(names)
        if names.count % 2 != 0 { output.append(0) }

        var displayInfo = Data()
        displayInfo.appendUInt32(1)
        for channel in alphaChannels {
            let spotColor = channel.spotColor ?? ImageEditorPSDSpotColor()
            let components = Array(spotColor.components.prefix(4)) + Array(repeating: UInt16(0), count: max(0, 4 - spotColor.components.count))
            displayInfo.appendUInt16(spotColor.colorSpace)
            for component in components { displayInfo.appendUInt16(component) }
            displayInfo.appendUInt16(spotColor.opacity)
            displayInfo.append(channel.kind == .spot ? 2 : 0)
        }
        output.appendASCII("8BIM")
        output.appendUInt16(1077)
        output.appendPascalString("", alignment: 2)
        output.appendUInt32(UInt32(displayInfo.count))
        output.append(displayInfo)
        if displayInfo.count % 2 != 0 { output.append(0) }
        return output
    }

    private static func pathResourceData(
        _ paths: [ImageEditorSavedPath],
        canvasSize: CGSize
    ) -> Data {
        var output = Data()
        for (index, path) in paths.prefix(ImageEditorSavedPath.maximumCount).enumerated() {
            guard let normalized = path.normalized(canvasSize: canvasSize),
                  let resourceID = UInt16(exactly: 2000 + index)
            else { continue }
            let payload = pathResourcePayload(normalized, canvasSize: canvasSize)
            guard !payload.isEmpty else { continue }
            output.appendASCII("8BIM")
            output.appendUInt16(resourceID)
            output.appendPascalString(normalized.name, alignment: 2)
            output.appendUInt32(UInt32(payload.count))
            output.append(payload)
            if payload.count % 2 != 0 { output.append(0) }
        }
        return output
    }

    private static func pathResourcePayload(
        _ path: ImageEditorSavedPath,
        canvasSize: CGSize
    ) -> Data {
        var output = Data()
        for subpath in path.subpaths where !subpath.isEmpty {
            guard let knotCount = UInt16(exactly: subpath.count) else { continue }
            output.appendUInt16(path.isClosed ? 0 : 3)
            output.appendUInt16(knotCount)
            // A path length record is 26 bytes: selector (2), knot count (2),
            // and 22 reserved bytes before the first 26-byte knot record.
            output.append(Data(repeating: 0, count: 22))
            for (index, anchor) in subpath.enumerated() {
                let selector: UInt16
                if path.isClosed {
                    selector = index == 0 ? 1 : 2
                } else {
                    selector = index == 0 ? 4 : 5
                }
                output.appendUInt16(selector)
                appendPathFixed8_24(anchor.inControl ?? anchor.point, canvasSize: canvasSize, to: &output)
                appendPathFixed8_24(anchor.point, canvasSize: canvasSize, to: &output)
                appendPathFixed8_24(anchor.outControl ?? anchor.point, canvasSize: canvasSize, to: &output)
            }
        }
        return output
    }

    private static func appendPathFixed8_24(
        _ point: CGPoint,
        canvasSize: CGSize,
        to data: inout Data
    ) {
        let normalizedX = canvasSize.width > 0 ? point.x / canvasSize.width : 0
        let normalizedY = canvasSize.height > 0 ? point.y / canvasSize.height : 0
        data.appendInt32(Int32((Double(normalizedY) * 16_777_216).rounded()))
        data.appendInt32(Int32((Double(normalizedX) * 16_777_216).rounded()))
    }

    static func compatibilityReport(_ data: Data) throws -> ImageEditorPSDCompatibilityReport {
        try scanCompatibility(data)
    }

    static func decode(_ data: Data, sourceName: String) throws -> ImageEditorDocument {
        try materialize(parse(data), sourceName: sourceName)
    }

    static func decodeAsync(
        _ data: Data,
        sourceName: String,
        onWillMaterialize: @MainActor @escaping () -> Void
    ) async throws -> ImageEditorDocument {
        let parsed = try await Task.detached(priority: .userInitiated) {
            try parse(data)
        }.value
        try Task.checkCancellation()
        onWillMaterialize()
        return try await materializeAsync(parsed, sourceName: sourceName)
    }

    nonisolated private static func scanCompatibility(
        _ data: Data
    ) throws -> ImageEditorPSDCompatibilityReport {
        var reader = PSDReader(data: data)
        guard try reader.ascii(count: 4) == "8BPS" else {
            throw ImageEditorPSDCodecError.invalidFile
        }
        let version = Int(try reader.uint16())
        try reader.skip(6)
        let channelCount = Int(try reader.uint16())
        let height = Int(try reader.uint32())
        let width = Int(try reader.uint32())
        let depth = Int(try reader.uint16())
        let colorMode = Int(try reader.uint16())

        var issueCounts: [ImageEditorPSDCompatibilityIssueKind: Int] = [:]
        func addIssue(_ kind: ImageEditorPSDCompatibilityIssueKind, count: Int = 1) {
            issueCounts[kind, default: 0] += count
        }
        if version != 1 { addIssue(.unsupportedVersion) }
        if depth != 8 { addIssue(.unsupportedBitDepth) }
        if colorMode != 3 { addIssue(.unsupportedColorMode) }
        // Additional alpha and spot channels are decoded into editable Xomo channels.
        // Keep the compatibility issue reserved for a future unsupported channel mode.

        guard version == 1 else {
            return compatibilityReport(
                width: width,
                height: height,
                depth: depth,
                colorMode: colorMode,
                layerCount: 0,
                groupCount: 0,
                maskCount: 0,
                compressions: [],
                issueCounts: issueCounts
            )
        }

        try reader.skipLengthPrefixed32()
        let imageResources = try reader.lengthPrefixedData32()
        if try imageResourcesContainICCProfile(imageResources) {
            addIssue(.colorProfileIgnored)
        }

        let layerAndMaskLength = Int(try reader.uint32())
        let layerAndMaskEnd = try reader.checkedEnd(length: layerAndMaskLength)
        var records: [PSDLayerRecord] = []
        var compressions = Set<ImageEditorPSDCompression>()
        if layerAndMaskLength >= 4 {
            let layerInfoLength = Int(try reader.uint32())
            let layerInfoEnd = min(try reader.checkedEnd(length: layerInfoLength), layerAndMaskEnd)
            if layerInfoLength >= 2 {
                let layerCount = abs(Int(try reader.int16()))
                records.reserveCapacity(layerCount)
                for _ in 0..<layerCount {
                    records.append(try readLayerRecord(&reader))
                }
                for record in records {
                    for (_, length) in record.channels {
                        let end = try reader.checkedEnd(length: length)
                        if length >= 2 {
                            let rawCompression = Int(try reader.uint16())
                            if let compression = ImageEditorPSDCompression(rawValue: rawCompression) {
                                compressions.insert(compression)
                            } else {
                                addIssue(.unsupportedCompression)
                            }
                        }
                        reader.offset = end
                    }
                }
            }
            reader.offset = layerInfoEnd
        }
        reader.offset = layerAndMaskEnd
        if reader.offset + 2 <= data.count {
            let rawCompression = Int(try reader.uint16())
            if let compression = ImageEditorPSDCompression(rawValue: rawCompression) {
                compressions.insert(compression)
            } else {
                addIssue(.unsupportedCompression)
            }
        }

        let textKeys: Set<String> = ["TySh", "Txt2"]
        let vectorKeys: Set<String> = ["vmsk", "vsms", "vstk", "vscg", "vogk"]
        let smartObjectKeys: Set<String> = ["SoLd", "PlLd", "plLd"]
        let effectKeys: Set<String> = ["lrFX", "lfx2"]
        let fillKeys: Set<String> = ["SoCo", "GdFl", "PtFl"]
        let adjustmentKeys: Set<String> = [
            "brit", "levl", "curv", "expA", "vibA", "hue ", "hue2", "blnc",
            "blwh", "phfl", "mixr", "clrL", "nvrt", "post", "thrs", "grdm", "selc"
        ]
        let recognizedKeys = textKeys
            .union(vectorKeys)
            .union(smartObjectKeys)
            .union(effectKeys)
            .union(fillKeys)
            .union(adjustmentKeys)
            .union([
                "luni", "lsct", "lsdk", "lspf", "iOpa", "lyid", "clbl", "infx",
                "knko", "lclr", "fxrp", "lyvr", "tsly", "lmgm", "vmgm", "shmd",
                "lnsr", "shpa", "sn2P", "anFX", "pths", "FMsk"
            ])
        for record in records {
            if !record.additionalKeys.isDisjoint(with: textKeys), record.textInfo == nil {
                addIssue(.textRasterized)
            }
            if !record.additionalKeys.isDisjoint(with: vectorKeys), record.vectorMaskInfo == nil {
                addIssue(.vectorRasterized)
            }
            if !record.additionalKeys.isDisjoint(with: smartObjectKeys) { addIssue(.smartObjectRasterized) }
            if !record.additionalKeys.isDisjoint(with: effectKeys) { addIssue(.layerEffectsRasterized) }
            if !record.additionalKeys.isDisjoint(with: fillKeys) { addIssue(.fillLayerRasterized) }
            if !record.additionalKeys.isDisjoint(with: adjustmentKeys) { addIssue(.adjustmentLayerRasterized) }
            if !ImageEditorBlendMode.supportedPSDKeys.contains(record.blendKey) {
                addIssue(.unknownBlendMode)
            }
            let unknownKeys = record.additionalKeys.subtracting(recognizedKeys)
            if !unknownKeys.isEmpty { addIssue(.unknownLayerData, count: unknownKeys.count) }
        }

        return compatibilityReport(
            width: width,
            height: height,
            depth: depth,
            colorMode: colorMode,
            layerCount: records.filter { $0.sectionType != 3 }.count,
            groupCount: records.filter { $0.sectionType == 1 || $0.sectionType == 2 }.count,
            maskCount: records.filter { $0.mask != nil }.count,
            compressions: compressions,
            issueCounts: issueCounts
        )
    }

    nonisolated private static func compatibilityReport(
        width: Int,
        height: Int,
        depth: Int,
        colorMode: Int,
        layerCount: Int,
        groupCount: Int,
        maskCount: Int,
        compressions: Set<ImageEditorPSDCompression>,
        issueCounts: [ImageEditorPSDCompatibilityIssueKind: Int]
    ) -> ImageEditorPSDCompatibilityReport {
        let order: [ImageEditorPSDCompatibilityIssueKind] = [
            .unsupportedVersion, .unsupportedBitDepth, .unsupportedColorMode,
            .unsupportedCompression, .additionalChannels, .textRasterized,
            .vectorRasterized, .smartObjectRasterized, .adjustmentLayerRasterized,
            .layerEffectsRasterized, .fillLayerRasterized, .colorProfileIgnored,
            .unknownBlendMode, .unknownLayerData, .flattenedFallback
        ]
        let issues = order.compactMap { kind -> ImageEditorPSDCompatibilityIssue? in
            guard let count = issueCounts[kind], count > 0 else { return nil }
            return ImageEditorPSDCompatibilityIssue(kind: kind, count: count)
        }
        return ImageEditorPSDCompatibilityReport(
            width: width,
            height: height,
            bitDepth: depth,
            colorMode: colorMode,
            layerCount: layerCount,
            groupCount: groupCount,
            maskCount: maskCount,
            compressions: compressions,
            issues: issues
        )
    }

    nonisolated private static func imageResourcesContainICCProfile(_ data: Data) throws -> Bool {
        var reader = PSDReader(data: data)
        while reader.offset + 12 <= data.count {
            let signature = try reader.ascii(count: 4)
            guard signature == "8BIM" else { return false }
            let identifier = try reader.uint16()
            _ = try reader.pascalString(alignment: 2)
            let length = Int(try reader.uint32())
            try reader.skip(length)
            if length % 2 != 0 { try reader.skip(1) }
            if identifier == 1039 { return true }
        }
        return false
    }

    nonisolated private static func parse(_ data: Data) throws -> PSDParsedDocument {
        var reader = PSDReader(data: data)
        guard try reader.ascii(count: 4) == "8BPS", try reader.uint16() == 1 else {
            throw ImageEditorPSDCodecError.invalidFile
        }
        try reader.skip(6)
        let channelCount = Int(try reader.uint16())
        let height = Int(try reader.uint32())
        let width = Int(try reader.uint32())
        let depth = try reader.uint16()
        let colorMode = try reader.uint16()
        guard (3...56).contains(channelCount), width > 0, height > 0, depth == 8, colorMode == 3 else {
            throw ImageEditorPSDCodecError.unsupportedDocument
        }
        try reader.skipLengthPrefixed32()
        let imageResources = try reader.lengthPrefixedData32()
        let alphaChannelNames = parseAlphaChannelNames(imageResources)
        let alphaChannelDisplayInfo = parseAlphaChannelDisplayInfo(imageResources)
        let savedPaths = parseSavedPaths(
            imageResources,
            canvasSize: CGSize(width: width, height: height)
        )

        let layerAndMaskLength = Int(try reader.uint32())
        let layerAndMaskEnd = try reader.checkedEnd(length: layerAndMaskLength)
        var decodedLayers: [PSDParsedLayer] = []
        if layerAndMaskLength >= 4 {
            let layerInfoLength = Int(try reader.uint32())
            let layerInfoEnd = min(try reader.checkedEnd(length: layerInfoLength), layerAndMaskEnd)
            if layerInfoLength >= 2 {
                let signedCount = Int(try reader.int16())
                let layerCount = abs(signedCount)
                var records: [PSDLayerRecord] = []
                records.reserveCapacity(layerCount)
                for _ in 0..<layerCount {
                    records.append(try readLayerRecord(&reader))
                }
                for record in records {
                    let channels = try readLayerChannels(&reader, record: record)
                    decodedLayers.append(PSDParsedLayer(record: record, channels: channels))
                }
            }
            reader.offset = layerInfoEnd
        }
        reader.offset = layerAndMaskEnd

        let compositeData = try readCompositeChannels(
            &reader,
            width: width,
            height: height,
            channelCount: channelCount,
            alphaChannelNames: alphaChannelNames,
            alphaChannelDisplayInfo: alphaChannelDisplayInfo
        )

        if !decodedLayers.isEmpty {
            return PSDParsedDocument(
                width: width,
                height: height,
                layers: decodedLayers,
                composite: nil,
                savedPaths: savedPaths,
                alphaChannels: compositeData.alphaChannels
            )
        }
        return PSDParsedDocument(
            width: width,
            height: height,
            layers: [],
            composite: compositeData.channels,
            savedPaths: savedPaths,
            alphaChannels: compositeData.alphaChannels
        )
    }

    nonisolated private static func parseAlphaChannelNames(_ data: Data) -> [String] {
        do {
            var reader = PSDReader(data: data)
            while reader.offset + 12 <= data.count {
                let signature = try reader.ascii(count: 4)
                guard signature == "8BIM" || signature == "8B64" else { break }
                let resourceID = try reader.uint16()
                _ = try reader.pascalString(alignment: 2)
                let resourceLength = Int(try reader.uint32())
                let resourceData = try reader.data(count: resourceLength)
                if resourceLength.isMultiple(of: 2) == false { try reader.skip(1) }
                guard resourceID == 1006 else { continue }

                var namesReader = PSDReader(data: resourceData)
                var names: [String] = []
                while namesReader.offset < resourceData.count {
                    names.append(try namesReader.pascalString(alignment: 2))
                }
                return names
            }
        } catch {
            return []
        }
        return []
    }

    nonisolated private static func parseAlphaChannelDisplayInfo(_ data: Data) -> [PSDAlphaChannelDisplayInfo] {
        do {
            var reader = PSDReader(data: data)
            while reader.offset + 12 <= data.count {
                let signature = try reader.ascii(count: 4)
                guard signature == "8BIM" || signature == "8B64" else { break }
                let resourceID = try reader.uint16()
                _ = try reader.pascalString(alignment: 2)
                let resourceLength = Int(try reader.uint32())
                let resourceData = try reader.data(count: resourceLength)
                if resourceLength.isMultiple(of: 2) == false { try reader.skip(1) }
                guard resourceID == 1077 else { continue }

                var infoReader = PSDReader(data: resourceData)
                _ = try infoReader.uint32()
                var result: [PSDAlphaChannelDisplayInfo] = []
                while infoReader.offset + 13 <= resourceData.count {
                    let colorSpace = try infoReader.uint16()
                    let components = [
                        try infoReader.uint16(), try infoReader.uint16(),
                        try infoReader.uint16(), try infoReader.uint16()
                    ]
                    let opacity = try infoReader.uint16()
                    let mode = try infoReader.uint8()
                    result.append(
                        PSDAlphaChannelDisplayInfo(
                            colorSpace: colorSpace,
                            components: components,
                            opacity: opacity,
                            mode: mode
                        )
                    )
                }
                return result
            }
        } catch {
            return []
        }
        return []
    }

    private static func parseSavedPaths(
        _ data: Data,
        canvasSize: CGSize
    ) -> [ImageEditorSavedPath] {
        do {
            var reader = PSDReader(data: data)
            var paths: [ImageEditorSavedPath] = []
            while reader.offset + 12 <= data.count {
                let signature = try reader.ascii(count: 4)
                guard signature == "8BIM" || signature == "8B64" else { break }
                let resourceID = try reader.uint16()
                let resourceName = try reader.pascalString(alignment: 2)
                let resourceLength = Int(try reader.uint32())
                let resourceData = try reader.data(count: resourceLength)
                if resourceLength.isMultiple(of: 2) == false {
                    try reader.skip(1)
                }
                guard (2000...2999).contains(Int(resourceID)) else { continue }
                guard let path = parseSavedPathResource(
                    resourceData,
                    name: resourceName,
                    fallbackIndex: paths.count + 1,
                    canvasSize: canvasSize
                ) else { continue }
                paths.append(path)
                guard paths.count < ImageEditorSavedPath.maximumCount else { break }
            }
            return paths
        } catch {
            return []
        }
    }

    private static func parseSavedPathResource(
        _ data: Data,
        name: String,
        fallbackIndex: Int,
        canvasSize: CGSize
    ) -> ImageEditorSavedPath? {
        do {
            var reader = PSDReader(data: data)
            var expectedKnotCount: Int?
            var currentSubpath: [ImageEditorPathAnchor] = []
            var currentIsClosed: Bool?
            var subpaths: [[ImageEditorPathAnchor]] = []
            var closureStates: Set<Bool> = []
            while reader.offset + 26 <= data.count {
                let selector = try reader.uint16()
                let payload = try reader.data(count: 24)
                switch selector {
                case 0, 3:
                    guard expectedKnotCount == nil else { return nil }
                    let count = Int(
                        UInt16(payload[payload.startIndex]) << 8
                            | UInt16(payload[payload.startIndex + 1])
                    )
                    guard count >= (selector == 0 ? 3 : 2) else { return nil }
                    expectedKnotCount = count
                    currentSubpath = []
                    currentIsClosed = selector == 0
                case 1, 2, 4, 5:
                    guard let knotCount = expectedKnotCount,
                          currentSubpath.count < knotCount,
                          let isClosed = currentIsClosed
                    else { return nil }
                    let previousControl = vectorPathPoint(in: payload, at: 0)
                    let anchor = vectorPathPoint(in: payload, at: 8)
                    let nextControl = vectorPathPoint(in: payload, at: 16)
                    let selectorIsClosed = selector <= 2
                    guard selectorIsClosed == isClosed else { return nil }
                    currentSubpath.append(
                        ImageEditorPathAnchor(
                            point: CGPoint(x: anchor.x * canvasSize.width, y: anchor.y * canvasSize.height),
                            inControl: CGPoint(x: previousControl.x * canvasSize.width, y: previousControl.y * canvasSize.height),
                            outControl: CGPoint(x: nextControl.x * canvasSize.width, y: nextControl.y * canvasSize.height)
                        )
                    )
                    if currentSubpath.count == knotCount {
                        subpaths.append(currentSubpath)
                        closureStates.insert(isClosed)
                        currentSubpath = []
                        currentIsClosed = nil
                        expectedKnotCount = nil
                    }
                case 6, 7, 8:
                    continue
                default:
                    return nil
                }
            }
            guard reader.offset == data.count,
                  expectedKnotCount == nil,
                  currentSubpath.isEmpty,
                  closureStates.count == 1,
                  let isClosed = closureStates.first,
                  !subpaths.isEmpty
            else { return nil }
            let pathName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "路径 \(fallbackIndex)"
                : name
            return ImageEditorSavedPath(
                name: pathName,
                subpaths: subpaths,
                isClosed: isClosed,
                isVisible: false
            ).normalized(canvasSize: canvasSize)
        } catch {
            return nil
        }
    }

    private static func materialize(
        _ parsed: PSDParsedDocument,
        sourceName: String
    ) throws -> ImageEditorDocument {
        let decodedLayers = materializeLayers(parsed)
        return try materializedDocument(
            parsed: parsed,
            decodedLayers: decodedLayers,
            sourceName: sourceName
        )
    }

    private static func materializeAsync(
        _ parsed: PSDParsedDocument,
        sourceName: String
    ) async throws -> ImageEditorDocument {
        var decodedLayers: [ImageEditorLayer] = []
        decodedLayers.reserveCapacity(parsed.layers.count)
        var groupStack: [UUID] = []
        for item in parsed.layers {
            try Task.checkCancellation()
            switch item.record.sectionType {
            case 1, 2:
                let layer = makeGroupLayer(
                    record: item.record,
                    channels: item.channels,
                    canvasSize: CGSize(width: parsed.width, height: parsed.height),
                    parentGroupID: groupStack.last
                )
                decodedLayers.append(layer)
                groupStack.append(layer.id)
            case 3:
                _ = groupStack.popLast()
            default:
                if var layer = makeLayer(
                    record: item.record,
                    channels: item.channels,
                    canvasHeight: parsed.height
                ) {
                    layer.groupID = groupStack.last
                    decodedLayers.append(layer)
                }
            }
            await Task.yield()
        }
        return try materializedDocument(
            parsed: parsed,
            decodedLayers: decodedLayers,
            sourceName: sourceName
        )
    }

    private static func materializeLayers(_ parsed: PSDParsedDocument) -> [ImageEditorLayer] {
        var decodedLayers: [ImageEditorLayer] = []
        decodedLayers.reserveCapacity(parsed.layers.count)
        var groupStack: [UUID] = []
        for item in parsed.layers {
            switch item.record.sectionType {
            case 1, 2:
                let layer = makeGroupLayer(
                    record: item.record,
                    channels: item.channels,
                    canvasSize: CGSize(width: parsed.width, height: parsed.height),
                    parentGroupID: groupStack.last
                )
                decodedLayers.append(layer)
                groupStack.append(layer.id)
            case 3:
                _ = groupStack.popLast()
            default:
                if var layer = makeLayer(
                    record: item.record,
                    channels: item.channels,
                    canvasHeight: parsed.height
                ) {
                    layer.groupID = groupStack.last
                    decodedLayers.append(layer)
                }
            }
        }
        return decodedLayers
    }

    private static func materializedDocument(
        parsed: PSDParsedDocument,
        decodedLayers: [ImageEditorLayer],
        sourceName: String
    ) throws -> ImageEditorDocument {
        if !decodedLayers.isEmpty {
            var document = ImageEditorDocument(
                sourceName: sourceName,
                image: NSImage.transparent(size: CGSize(width: parsed.width, height: parsed.height))
            )
            document.layers = decodedLayers.reversed()
            document.selectedLayerID = document.layers.last?.id
            document.selectedLayerIDs = Set(document.layers.last.map { [$0.id] } ?? [])
            document.savedPaths = parsed.savedPaths
            document.selectedSavedPathID = parsed.savedPaths.last?.id
            document.alphaChannels = parsed.alphaChannels
            document.history = [ImageEditorHistoryEntry(title: L10n.text("imageEditor.history.psdOpen"))]
            return document
        }

        guard let composite = parsed.composite,
              let image = imageFromChannels(composite, width: parsed.width, height: parsed.height)
        else {
            throw ImageEditorPSDCodecError.invalidFile
        }
        var document = ImageEditorDocument(sourceName: sourceName, image: image)
        document.savedPaths = parsed.savedPaths
        document.selectedSavedPathID = parsed.savedPaths.last?.id
        document.alphaChannels = parsed.alphaChannels
        return document
    }

    private static func integralPSDFrame(_ frame: CGRect, canvasSize: CGSize) -> CGRect {
        frame.standardized.integral.intersection(CGRect(origin: .zero, size: canvasSize))
    }

    private static func makeExportLayers(
        document: ImageEditorDocument,
        canvasHeight: Int
    ) throws -> [PSDExportLayer] {
        let layers = document.layers
        let layerIDs = Set(layers.map(\.id))
        var visited = Set<UUID>()
        var result: [PSDExportLayer] = []

        func appendLayer(_ layer: ImageEditorLayer) throws {
            guard visited.insert(layer.id).inserted else { return }
            if layer.isGroup {
                result.append(try exportGroupLayer(layer, document: document, canvasHeight: canvasHeight))
                for child in layers.reversed() where child.groupID == layer.id {
                    try appendLayer(child)
                }
                result.append(.groupDivider(canvasHeight: canvasHeight))
                return
            }
            guard !layer.isAdjustment, !layer.isFilter,
                  let item = try exportPixelLayer(layer, document: document, canvasHeight: canvasHeight)
            else { return }
            result.append(item)
        }

        for layer in layers.reversed() {
            let hasValidParent = layer.groupID.map(layerIDs.contains) == true
            if !hasValidParent { try appendLayer(layer) }
        }
        for layer in layers.reversed() where !visited.contains(layer.id) {
            try appendLayer(layer)
        }
        guard result.count <= Int(Int16.max) else {
            throw ImageEditorPSDCodecError.unsupportedDocument
        }
        return result
    }

    private static func exportPixelLayer(
        _ layer: ImageEditorLayer,
        document: ImageEditorDocument,
        canvasHeight: Int
    ) throws -> PSDExportLayer? {
        let frame = integralPSDFrame(layer.frame, canvasSize: document.canvasSize)
        guard frame.width > 0, frame.height > 0 else { return nil }

        var layerWithoutMasks = layer
        layerWithoutMasks.mask = nil
        layerWithoutMasks.vectorMask = nil
        let rendered = layerWithoutMasks.renderedCompositingImage(
            globalLightAngle: document.globalLightAngle
        )
        guard let rgba = rgbaChannels(
            image: rendered,
            width: Int(frame.width),
            height: Int(frame.height)
        ) else {
            throw ImageEditorPSDCodecError.imageEncodingFailed
        }

        var channels = [
            PSDExportChannel(identifier: -1, data: rgba.alpha),
            PSDExportChannel(identifier: 0, data: rgba.red),
            PSDExportChannel(identifier: 1, data: rgba.green),
            PSDExportChannel(identifier: 2, data: rgba.blue)
        ]
        let vectorMask = exportVectorMask(layer: layer)
        let mask = layer.mask != nil || vectorMask == nil
            ? exportMask(layer: layer, frame: frame)
            : nil
        if let mask { channels.append(PSDExportChannel(identifier: -2, data: mask.alpha)) }
        return PSDExportLayer(
            name: layer.name,
            frame: frame,
            canvasHeight: canvasHeight,
            channels: channels,
            opacity: layer.opacity,
            fillOpacity: layer.fillOpacity,
            blendMode: layer.blendMode,
            isVisible: layer.isVisible,
            isClippingMask: layer.isClippingMask,
            isLocked: layer.isLocked,
            locksPixels: layer.locksPixels,
            locksPosition: layer.locksPosition,
            locksTransparentPixels: layer.locksTransparentPixels,
            sectionType: nil,
            mask: mask,
            vectorMask: vectorMask,
            textObject: layer.textContent.flatMap {
                exportTextToolObject($0, size: frame.size)
            }
        )
    }

    private static func exportTextToolObject(
        _ content: ImageEditorTextContent,
        size: CGSize
    ) -> PSDExportText? {
        guard !content.text.isEmpty else { return nil }
        var engine = Data()
        engine.appendASCII("<<\n/EngineDict <<\n/Editor <<\n/Text ")
        appendEngineUnicodeString(content.text, to: &engine)
        engine.appendASCII("\n>>\n/StyleRun <<\n/RunLengthArray [ \(content.text.utf16.count) ]\n")
        engine.appendASCII("/RunArray [ << /StyleSheet << /StyleSheetData << /Font 0 /FontSize \(content.fontSize) ")
        let fauxBold = content.isBold ? "true" : "false"
        let fauxItalic = content.isItalic ? "true" : "false"
        let underline = content.isUnderlined ? "true" : "false"
        let strikethrough = content.isStruckThrough ? "true" : "false"
        engine.appendASCII("/FauxBold \(fauxBold) /FauxItalic \(fauxItalic) ")
        engine.appendASCII("/Underline \(underline) /Strikethrough \(strikethrough) ")
        let tracking = content.fontSize > 0 ? content.characterSpacing * 1000 / content.fontSize : 0
        engine.appendASCII("/Tracking \(tracking) /Leading \(content.lineSpacing) /LeftIndent \(content.leftIndent) /RightIndent \(content.rightIndent) /FirstLineIndent \(content.firstLineIndent) ")
        let color = content.color.usingColorSpace(.deviceRGB) ?? .black
        engine.appendASCII("/FillColor << /Type 1 /Values [ \(color.redComponent) \(color.greenComponent) \(color.blueComponent) \(color.alphaComponent) ] >> >> >> >> ]\n>>\n")
        let justification: Int
        switch content.alignment {
        case .left: justification = 0
        case .right: justification = 1
        case .center: justification = 2
        case .justified: justification = 3
        }
        engine.appendASCII("/ParagraphRun << /RunLengthArray [ \(content.text.utf16.count) ] /RunArray [ << /ParagraphSheet << /Properties << /Justification \(justification) >> >> >> ] >>\n")
        engine.appendASCII("/Rendered << /Shapes << /Children [ << /Cookie << /Photoshop << /ShapeType \(content.boxWidth > 0 ? 1 : 0) >> >> >> ] >> >>\n>>\n/ResourceDict << /FontSet [ << /Name ")
        appendEngineUnicodeString(content.fontFamilyName, to: &engine)
        engine.appendASCII(" /FontFamily ")
        appendEngineUnicodeString(content.fontFamilyName, to: &engine)
        engine.appendASCII(" /FontStyle ")
        appendEngineUnicodeString(content.isBold ? "Bold" : "Regular", to: &engine)
        engine.appendASCII(" >> ] >>\n>>")

        var descriptorItems = Data()
        descriptorItems.append(descriptorItem(key: "Txt ", type: "TEXT", payload: descriptorUnicodeString(content.text)))
        descriptorItems.append(descriptorItem(key: "EngineData", type: "tdta", payload: lengthPrefixedData(engine)))
        var tysh = Data()
        tysh.appendUInt16(1)
        for value in [1, 0, 0, 1, 0, 0] { tysh.appendDouble(Double(value)) }
        tysh.appendUInt16(50)
        tysh.append(descriptorBlock(name: "", classID: "TxLr", itemCount: 2, items: descriptorItems))
        tysh.appendUInt16(1)
        tysh.append(descriptorBlock(name: "", classID: "warp", itemCount: 0, items: Data()))
        let boxWidth = content.boxWidth > 0 ? content.boxWidth : size.width
        let boxHeight = content.boxHeight > 0 ? content.boxHeight : size.height
        for value in [0, 0, boxHeight, boxWidth] { tysh.appendDouble(Double(value)) }
        return PSDExportText(data: tysh)
    }

    private static func appendEngineUnicodeString(_ value: String, to data: inout Data) {
        data.append(0x28)
        data.append(contentsOf: [0xFE, 0xFF])
        for codeUnit in value.utf16 {
            if codeUnit == 0x28 || codeUnit == 0x29 || codeUnit == 0x5C {
                data.appendUInt16(0x5C)
            }
            data.appendUInt16(codeUnit)
        }
        data.append(0x29)
    }

    private static func descriptorItem(key: String, type: String, payload: Data) -> Data {
        var output = descriptorKey(key)
        output.appendASCII(type)
        output.append(payload)
        return output
    }

    private static func descriptorBlock(name: String, classID: String, itemCount: Int, items: Data) -> Data {
        var output = Data()
        output.appendUInt32(16)
        output.append(descriptorUnicodeString(name))
        output.append(descriptorKey(classID))
        output.appendUInt32(UInt32(itemCount))
        output.append(items)
        return output
    }

    private static func descriptorKey(_ value: String) -> Data {
        let bytes = Array(value.utf8)
        var output = Data()
        if bytes.count == 4 {
            output.appendUInt32(0)
            output.append(contentsOf: bytes)
        } else {
            output.appendUInt32(UInt32(bytes.count))
            output.append(contentsOf: bytes)
        }
        return output
    }

    private static func descriptorUnicodeString(_ value: String) -> Data {
        var output = Data()
        let utf16 = Array(value.utf16)
        output.appendUInt32(UInt32(utf16.count))
        for codeUnit in utf16 { output.appendUInt16(codeUnit) }
        return output
    }

    private static func lengthPrefixedData(_ data: Data) -> Data {
        var output = Data()
        output.appendUInt32(UInt32(data.count))
        output.append(data)
        return output
    }

    private static func exportGroupLayer(
        _ layer: ImageEditorLayer,
        document: ImageEditorDocument,
        canvasHeight: Int
    ) throws -> PSDExportLayer {
        let maskFrame = integralPSDFrame(layer.frame, canvasSize: document.canvasSize)
        let mask = maskFrame.isEmpty ? nil : exportMask(layer: layer, frame: maskFrame)
        let frame = mask == nil ? .zero : maskFrame
        let channels = mask.map { [PSDExportChannel(identifier: -2, data: $0.alpha)] } ?? []
        return PSDExportLayer(
            name: layer.name,
            frame: frame,
            canvasHeight: canvasHeight,
            channels: channels,
            opacity: layer.opacity,
            fillOpacity: layer.fillOpacity,
            blendMode: layer.blendMode,
            isVisible: layer.isVisible,
            isClippingMask: false,
            isLocked: layer.isLocked,
            locksPixels: layer.locksPixels,
            locksPosition: layer.locksPosition,
            locksTransparentPixels: layer.locksTransparentPixels,
            sectionType: layer.isGroupExpanded ? 1 : 2,
            mask: mask,
            vectorMask: nil,
            textObject: nil
        )
    }

    private static func exportVectorMask(layer: ImageEditorLayer) -> PSDExportVectorMask? {
        guard let content = layer.vectorMask,
              content.kind == .path,
              content.isPathClosed
        else { return nil }
        let size = CGSize(width: max(1, layer.image.size.width), height: max(1, layer.image.size.height))
        let normalized = content.normalized(size: size)
        let subpaths = normalized.allEditablePathSubpaths
        guard !subpaths.isEmpty,
              subpaths.allSatisfy({ $0.count >= 3 })
        else { return nil }
        var payload = Data()
        payload.appendUInt32(3)
        payload.appendUInt32(layer.isVectorMaskEnabled ? 0 : 4)
        payload.appendUInt16(6)
        payload.append(Data(repeating: 0, count: 24))
        for anchors in subpaths {
            guard let count = UInt16(exactly: anchors.count) else { return nil }
            payload.appendUInt16(0)
            payload.appendUInt16(count)
            // A vector path length record is 26 bytes: selector (2),
            // knot count (2), and 22 reserved bytes.
            payload.append(Data(repeating: 0, count: 22))
            for (index, anchor) in anchors.enumerated() {
                payload.appendUInt16(index == 0 ? 1 : 2)
                appendVectorPathPoint(anchor.inControl ?? anchor.point, size: size, to: &payload)
                appendVectorPathPoint(anchor.point, size: size, to: &payload)
                appendVectorPathPoint(anchor.outControl ?? anchor.point, size: size, to: &payload)
            }
        }
        return PSDExportVectorMask(data: payload)
    }

    private static func appendVectorPathPoint(
        _ point: CGPoint,
        size: CGSize,
        to data: inout Data
    ) {
        let normalizedX = size.width > 0 ? point.x / size.width : 0
        let normalizedY = size.height > 0 ? point.y / size.height : 0
        data.appendInt32(Int32((Double(normalizedY) * 16_777_216).rounded()))
        data.appendInt32(Int32((Double(normalizedX) * 16_777_216).rounded()))
    }

    private static func exportMask(layer: ImageEditorLayer, frame: CGRect) -> PSDExportMask? {
        var maskSourceLayer = layer
        let isEnabled: Bool
        if layer.mask != nil {
            maskSourceLayer.vectorMask = nil
            maskSourceLayer.isMaskEnabled = true
            isEnabled = layer.isMaskEnabled
        } else {
            maskSourceLayer.isVectorMaskEnabled = true
            isEnabled = layer.isVectorMaskEnabled
        }
        guard let effectiveMask = maskSourceLayer.effectiveMask,
              let alpha = alphaPlane(
                image: effectiveMask,
                width: Int(frame.width),
                height: Int(frame.height)
              )
        else { return nil }
        return PSDExportMask(
            alpha: alpha,
            isEnabled: isEnabled,
            isLinked: layer.isMaskLinked
        )
    }

    private static func layerRecord(_ item: PSDExportLayer) -> Data {
        let top = Int32(item.canvasHeight - Int(item.frame.maxY))
        let left = Int32(item.frame.minX)
        let bottom = Int32(item.canvasHeight - Int(item.frame.minY))
        let right = Int32(item.frame.maxX)

        var record = Data()
        record.appendInt32(top)
        record.appendInt32(left)
        record.appendInt32(bottom)
        record.appendInt32(right)
        record.appendUInt16(UInt16(item.channels.count))
        for channel in item.channels {
            record.appendInt16(channel.identifier)
            record.appendUInt32(UInt32(channel.data.count + 2))
        }
        record.appendASCII("8BIM")
        record.appendASCII(item.blendMode.psdKey)
        record.append(UInt8((item.opacity * 255).rounded().clamped(to: 0...255)))
        record.append(item.isClippingMask ? 1 : 0)
        var flags: UInt8 = (item.locksTransparentPixels || item.isLocked) ? 1 : 0
        if !item.isVisible { flags |= 2 }
        record.append(flags)
        record.append(0)

        var extra = Data()
        extra.appendLayerMask(item.mask, frame: item.frame, canvasHeight: item.canvasHeight)
        extra.appendUInt32(0)
        extra.appendPascalString(item.name, alignment: 4)
        extra.appendUnicodeLayerName(item.name)
        extra.appendFillOpacity(item.fillOpacity)
        extra.appendProtectionFlags(
            isLocked: item.isLocked,
            locksPixels: item.locksPixels,
            locksPosition: item.locksPosition,
            locksTransparentPixels: item.locksTransparentPixels
        )
        if let sectionType = item.sectionType {
            extra.appendSectionDivider(type: sectionType, blendMode: item.blendMode)
        }
        extra.appendVectorMask(item.vectorMask)
        extra.appendTextToolObject(item.textObject)
        record.appendUInt32(UInt32(extra.count))
        record.append(extra)
        return record
    }

    nonisolated private static func readLayerRecord(_ reader: inout PSDReader) throws -> PSDLayerRecord {
        let top = Int(try reader.int32())
        let left = Int(try reader.int32())
        let bottom = Int(try reader.int32())
        let right = Int(try reader.int32())
        let channelCount = Int(try reader.uint16())
        var channelLengths: [(Int16, Int)] = []
        for _ in 0..<channelCount {
            channelLengths.append((try reader.int16(), Int(try reader.uint32())))
        }
        guard try reader.ascii(count: 4) == "8BIM" else { throw ImageEditorPSDCodecError.invalidFile }
        let blendKey = try reader.ascii(count: 4)
        let opacity = try reader.uint8()
        let clipping = try reader.uint8()
        let flags = try reader.uint8()
        try reader.skip(1)
        let extraLength = Int(try reader.uint32())
        let extraEnd = try reader.checkedEnd(length: extraLength)
        let mask = try readLayerMaskRecord(&reader)
        try reader.skipLengthPrefixed32()
        var name = try reader.pascalString(alignment: 4)
        var sectionType: Int?
        var sectionBlendKey: String?
        var fillOpacity = UInt8.max
        var protectionFlags: UInt32 = 0
        var additionalKeys = Set<String>()
        var textInfo: PSDTextLayerInfo?
        var vectorMaskInfo: PSDVectorMaskInfo?
        while reader.offset + 12 <= extraEnd {
            let signature = try reader.ascii(count: 4)
            let key = try reader.ascii(count: 4)
            let length = Int(try reader.uint32())
            let blockEnd = min(try reader.checkedEnd(length: length), extraEnd)
            additionalKeys.insert(key)
            if (signature == "8BIM" || signature == "8B64"), key == "luni", length >= 4 {
                let count = Int(try reader.uint32())
                let byteCount = min(count * 2, blockEnd - reader.offset)
                let stringData = try reader.data(count: byteCount)
                name = String(data: stringData, encoding: .utf16BigEndian) ?? name
            } else if (key == "lsct" || key == "lsdk"), length >= 4 {
                sectionType = Int(try reader.uint32())
                if length >= 12 {
                    _ = try reader.ascii(count: 4)
                    sectionBlendKey = try reader.ascii(count: 4)
                }
            } else if key == "lspf", length >= 4 {
                protectionFlags = try reader.uint32()
            } else if key == "iOpa", length >= 1 {
                fillOpacity = try reader.uint8()
            } else if key == "TySh" {
                let blockData = try reader.data(count: length)
                textInfo = parseTextToolObject(blockData)
            } else if key == "Txt2" {
                let blockData = try reader.data(count: length)
                textInfo = parseEngineDataText(blockData)
            } else if (key == "vmsk" || key == "vsms") {
                let blockData = try reader.data(count: length)
                vectorMaskInfo = parseVectorMask(blockData)
            }
            reader.offset = blockEnd
            let paddedEnd = min(extraEnd, blockEnd + (length % 2))
            reader.offset = paddedEnd
        }
        reader.offset = extraEnd
        return PSDLayerRecord(
            top: top,
            left: left,
            bottom: bottom,
            right: right,
            channels: channelLengths,
            name: name,
            opacity: opacity,
            clipping: clipping,
            flags: flags,
            blendKey: sectionBlendKey ?? blendKey,
            fillOpacity: fillOpacity,
            protectionFlags: protectionFlags,
            sectionType: sectionType,
            mask: mask,
            additionalKeys: additionalKeys,
            textInfo: textInfo,
            vectorMaskInfo: vectorMaskInfo
        )
    }

    nonisolated private static func readLayerMaskRecord(
        _ reader: inout PSDReader
    ) throws -> PSDLayerMaskRecord? {
        let length = Int(try reader.uint32())
        guard length > 0 else { return nil }
        let end = try reader.checkedEnd(length: length)
        guard length >= 18 else {
            reader.offset = end
            return nil
        }
        let top = Int(try reader.int32())
        let left = Int(try reader.int32())
        let bottom = Int(try reader.int32())
        let right = Int(try reader.int32())
        let defaultColor = try reader.uint8()
        let flags = try reader.uint8()
        reader.offset = end
        return PSDLayerMaskRecord(
            top: top,
            left: left,
            bottom: bottom,
            right: right,
            defaultColor: defaultColor,
            flags: flags
        )
    }

    nonisolated private static func readLayerChannels(
        _ reader: inout PSDReader,
        record: PSDLayerRecord
    ) throws -> PSDChannels {
        let width = max(0, record.right - record.left)
        let height = max(0, record.bottom - record.top)
        var result = PSDChannels.empty(pixelCount: width * height)
        for (identifier, length) in record.channels {
            let end = try reader.checkedEnd(length: length)
            let dimensions = record.channelDimensions(identifier: identifier)
            let decoded = try readChannel(
                &reader,
                width: dimensions.width,
                height: dimensions.height,
                end: end
            )
            switch identifier {
            case -1: result.alpha = decoded
            case -3, -2: result.userMask = decoded
            case 0: result.red = decoded
            case 1: result.green = decoded
            case 2: result.blue = decoded
            default: break
            }
            reader.offset = end
        }
        return result
    }

    nonisolated private static func readCompositeChannels(
        _ reader: inout PSDReader,
        width: Int,
        height: Int,
        channelCount: Int,
        alphaChannelNames: [String],
        alphaChannelDisplayInfo: [PSDAlphaChannelDisplayInfo]
    ) throws -> PSDCompositeChannels {
        let compression = try reader.uint16()
        let pixelCount = width * height
        var planes: [Data] = []
        switch compression {
        case 0:
            for _ in 0..<channelCount { planes.append(try reader.data(count: pixelCount)) }
        case 1:
            var rowLengths: [Int] = []
            for _ in 0..<(channelCount * height) { rowLengths.append(Int(try reader.uint16())) }
            for channel in 0..<channelCount {
                var plane = Data()
                for row in 0..<height {
                    let packed = try reader.data(count: rowLengths[channel * height + row])
                    plane.append(try unpackBits(packed, expectedCount: width))
                }
                planes.append(plane)
            }
        case 2, 3:
            let inflated = try inflate(
                try reader.data(count: reader.data.count - reader.offset),
                expectedCount: pixelCount * channelCount
            )
            let restored = compression == 3
                ? reverseZIPPrediction(
                    inflated,
                    width: width,
                    height: height,
                    channelCount: channelCount
                )
                : inflated
            for channel in 0..<channelCount {
                let start = channel * pixelCount
                planes.append(restored.subdata(in: start..<(start + pixelCount)))
            }
        default:
            throw ImageEditorPSDCodecError.unsupportedCompression
        }
        var channels = PSDChannels.empty(pixelCount: pixelCount)
        if planes.indices.contains(0) { channels.red = planes[0] }
        if planes.indices.contains(1) { channels.green = planes[1] }
        if planes.indices.contains(2) { channels.blue = planes[2] }
        if planes.indices.contains(3) { channels.alpha = planes[3] }
        let alphaChannels = planes.dropFirst(4).enumerated().map { index, plane in
            let fallbackName = "Alpha \(index + 1)"
            let importedName = alphaChannelNames.indices.contains(index)
                ? alphaChannelNames[index].trimmingCharacters(in: .whitespacesAndNewlines)
                : ""
            let displayInfo = alphaChannelDisplayInfo.indices.contains(index)
                ? alphaChannelDisplayInfo[index]
                : nil
            return ImageEditorAlphaChannel(
                name: importedName.isEmpty ? fallbackName : importedName,
                mask: ImageEditorSelectionMask(
                    width: width,
                    height: height,
                    alpha: Array(plane)
                ),
                kind: displayInfo?.mode == 2 ? .spot : .alpha,
                spotColor: displayInfo.map {
                    ImageEditorPSDSpotColor(
                        colorSpace: $0.colorSpace,
                        components: $0.components,
                        opacity: $0.opacity
                    )
                }
            )
        }
        return PSDCompositeChannels(channels: channels, alphaChannels: alphaChannels)
    }

    nonisolated private static func readChannel(
        _ reader: inout PSDReader,
        width: Int,
        height: Int,
        end: Int
    ) throws -> Data {
        guard width > 0, height > 0 else { return Data() }
        let compression = try reader.uint16()
        switch compression {
        case 0:
            return try reader.data(count: width * height)
        case 1:
            var lengths: [Int] = []
            for _ in 0..<height { lengths.append(Int(try reader.uint16())) }
            var output = Data()
            for length in lengths {
                output.append(try unpackBits(try reader.data(count: length), expectedCount: width))
            }
            return output
        case 2, 3:
            let packed = try reader.data(count: end - reader.offset)
            let inflated = try inflate(packed, expectedCount: width * height)
            return compression == 3
                ? reverseZIPPrediction(inflated, width: width, height: height, channelCount: 1)
                : inflated
        default:
            reader.offset = end
            throw ImageEditorPSDCodecError.unsupportedCompression
        }
    }

    nonisolated private static func inflate(_ data: Data, expectedCount: Int) throws -> Data {
        guard expectedCount >= 0 else { throw ImageEditorPSDCodecError.invalidFile }
        if expectedCount == 0 { return Data() }
        var destination = [UInt8](repeating: 0, count: expectedCount)
        let decodedCount = data.withUnsafeBytes { sourceBuffer -> Int in
            guard let source = sourceBuffer.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return compression_decode_buffer(
                &destination,
                destination.count,
                source,
                sourceBuffer.count,
                nil,
                COMPRESSION_ZLIB
            )
        }
        guard decodedCount == expectedCount else {
            throw ImageEditorPSDCodecError.invalidFile
        }
        return Data(destination)
    }

    nonisolated private static func reverseZIPPrediction(
        _ data: Data,
        width: Int,
        height: Int,
        channelCount: Int
    ) -> Data {
        guard width > 1, height > 0, channelCount > 0 else { return data }
        var bytes = [UInt8](data)
        let planeSize = width * height
        for channel in 0..<channelCount {
            let planeStart = channel * planeSize
            for row in 0..<height {
                let rowStart = planeStart + row * width
                for column in 1..<width {
                    let index = rowStart + column
                    bytes[index] = bytes[index] &+ bytes[index - 1]
                }
            }
        }
        return Data(bytes)
    }

    nonisolated private static func unpackBits(_ packed: Data, expectedCount: Int) throws -> Data {
        let bytes = [UInt8](packed)
        var output = Data()
        var index = 0
        while index < bytes.count, output.count < expectedCount {
            let header = Int(Int8(bitPattern: bytes[index]))
            index += 1
            if header >= 0 {
                let count = header + 1
                guard index + count <= bytes.count else { throw ImageEditorPSDCodecError.invalidFile }
                output.append(contentsOf: bytes[index..<(index + count)])
                index += count
            } else if header >= -127 {
                let count = 1 - header
                guard index < bytes.count else { throw ImageEditorPSDCodecError.invalidFile }
                output.append(Data(repeating: bytes[index], count: count))
                index += 1
            }
        }
        guard output.count >= expectedCount else { throw ImageEditorPSDCodecError.invalidFile }
        return output.prefix(expectedCount)
    }

    private static func parseTextToolObject(_ data: Data) -> PSDTextLayerInfo? {
        do {
            var reader = PSDReader(data: data)
            guard try reader.uint16() == 1 else { return nil }
            try reader.skip(48)
            guard try reader.uint16() == 50 else { return nil }
            let descriptor = try reader.psdDescriptorBlock()
            _ = try reader.uint16()
            _ = try reader.psdDescriptorBlock()

            let topLevelText = descriptor["Txt "]?.stringValue
            let engineData = descriptor["EngineData"]?.rawData
            let style = engineData.flatMap(parseEngineDataStyle)
            let bounds = try (0..<4).map { _ in try reader.doubleValue() }
            guard let text = topLevelText ?? style?.text, !text.isEmpty else { return nil }
            return PSDTextLayerInfo(
                text: normalizedPSDText(text),
                fontFamilyName: style?.fontFamilyName ?? ImageEditorTextContent.systemFontFamilyName,
                fontSize: style?.fontSize ?? 12,
                color: style?.color ?? .black,
                alignment: style?.alignment ?? .left,
                isParagraph: style?.isParagraph ?? false,
                isBold: style?.isBold ?? false,
                isItalic: style?.isItalic ?? false,
                isUnderlined: style?.isUnderlined ?? false,
                isStruckThrough: style?.isStruckThrough ?? false,
                characterSpacing: style?.characterSpacing ?? 0,
                lineSpacing: style?.lineSpacing ?? 0,
                leftIndent: style?.leftIndent ?? 0,
                rightIndent: style?.rightIndent ?? 0,
                firstLineIndent: style?.firstLineIndent ?? 0,
                paragraphBoxSize: style?.isParagraph == true ? paragraphBoxSize(from: bounds) : nil
            )
        } catch {
            return nil
        }
    }

    private static func parseEngineDataText(_ data: Data) -> PSDTextLayerInfo? {
        guard let style = parseEngineDataStyle(data), let text = style.text, !text.isEmpty else {
            return nil
        }
        return PSDTextLayerInfo(
            text: normalizedPSDText(text),
            fontFamilyName: style.fontFamilyName ?? ImageEditorTextContent.systemFontFamilyName,
            fontSize: style.fontSize ?? 12,
            color: style.color ?? .black,
            alignment: style.alignment ?? .left,
            isParagraph: style.isParagraph ?? false,
            isBold: style.isBold,
            isItalic: style.isItalic,
            isUnderlined: style.isUnderlined,
            isStruckThrough: style.isStruckThrough,
            characterSpacing: style.characterSpacing,
            lineSpacing: style.lineSpacing,
            leftIndent: style.leftIndent,
            rightIndent: style.rightIndent,
            firstLineIndent: style.firstLineIndent,
            paragraphBoxSize: nil
        )
    }

    private static func paragraphBoxSize(from bounds: [Double]) -> CGSize? {
        guard bounds.count == 4, bounds.allSatisfy(\.isFinite) else { return nil }
        let width = abs(bounds[3] - bounds[1])
        let height = abs(bounds[2] - bounds[0])
        guard width > 0, height > 0 else { return nil }
        return CGSize(width: width, height: height)
    }

    private static func parseEngineDataStyle(_ data: Data) -> PSDTextLayerStyle? {
        let bytes = [UInt8](data)
        let text = engineUnicodeString(after: "/Text", in: bytes)
        let fontSetStart = index(of: Array("/FontSet".utf8), in: bytes) ?? 0
        let fontName = engineUnicodeString(after: "/Name", in: bytes, startingAt: fontSetStart)
            ?? engineASCIIString(after: "/Name", in: bytes, startingAt: fontSetStart)
        guard text != nil || fontName != nil else { return nil }

        let fontSize = engineNumber(after: "/FontSize", in: bytes).map { CGFloat(max(1, $0)) }
        let alignment = engineNumber(after: "/Justification", in: bytes).map {
            switch Int($0.rounded()) {
            case 1: return ImageEditorTextAlignment.right
            case 2: return ImageEditorTextAlignment.center
            case 3, 4, 5, 6, 7: return ImageEditorTextAlignment.justified
            default: return ImageEditorTextAlignment.left
            }
        }
        let isParagraph = engineNumber(after: "/ShapeType", in: bytes).map {
            Int($0.rounded()) == 1
        }
        let color = engineColor(after: "/FillColor", in: bytes)
        let fontSizeValue = fontSize ?? 12
        let tracking = engineNumber(after: "/Tracking", in: bytes) ?? 0
        let leading = engineNumber(after: "/Leading", in: bytes) ?? 0
        return PSDTextLayerStyle(
            text: text,
            fontFamilyName: fontName,
            fontSize: fontSize,
            color: color,
            alignment: alignment,
            isParagraph: isParagraph,
            isBold: engineBoolean(after: "/FauxBold", in: bytes) ?? false,
            isItalic: engineBoolean(after: "/FauxItalic", in: bytes) ?? false,
            isUnderlined: engineBoolean(after: "/Underline", in: bytes) ?? false,
            isStruckThrough: engineBoolean(after: "/Strikethrough", in: bytes) ?? false,
            characterSpacing: CGFloat(tracking) * fontSizeValue / 1000,
            lineSpacing: CGFloat(max(0, leading)),
            leftIndent: CGFloat(max(0, engineNumber(after: "/LeftIndent", in: bytes) ?? 0)),
            rightIndent: CGFloat(max(0, engineNumber(after: "/RightIndent", in: bytes) ?? 0)),
            firstLineIndent: CGFloat(engineNumber(after: "/FirstLineIndent", in: bytes) ?? 0)
        )
    }

    private static func normalizedPSDText(_ text: String) -> String {
        text.replacingOccurrences(of: "\r", with: "\n")
    }

    private static func engineUnicodeString(
        after marker: String,
        in bytes: [UInt8],
        startingAt: Int = 0
    ) -> String? {
        guard let markerIndex = index(of: Array(marker.utf8), in: bytes, startingAt: startingAt) else {
            return nil
        }
        var cursor = markerIndex + marker.utf8.count
        while cursor < bytes.count, bytes[cursor] != 0x28 { cursor += 1 }
        guard cursor < bytes.count else { return nil }
        cursor += 1
        guard cursor + 1 < bytes.count, bytes[cursor] == 0xFE, bytes[cursor + 1] == 0xFF else {
            return nil
        }
        cursor += 2
        var value = Data()
        var escaped = false
        while cursor + 1 < bytes.count {
            // EngineData writes the UTF-16 payload as pairs but keeps the
            // PostScript closing parenthesis as a single byte. Detect that
            // delimiter before consuming the next pair; otherwise the first
            // byte of the following key becomes part of the font name.
            if bytes[cursor] == 0x29, bytes[cursor + 1] != 0x00 { break }
            let codeUnit = UInt16(bytes[cursor]) << 8 | UInt16(bytes[cursor + 1])
            if escaped {
                value.append(bytes[cursor])
                value.append(bytes[cursor + 1])
                escaped = false
                cursor += 2
                continue
            }
            if codeUnit == 0x5C {
                escaped = true
                cursor += 2
                continue
            }
            if codeUnit == 0x29 { break }
            value.append(bytes[cursor])
            value.append(bytes[cursor + 1])
            cursor += 2
        }
        return String(data: value, encoding: .utf16BigEndian)
    }

    private static func engineASCIIString(
        after marker: String,
        in bytes: [UInt8],
        startingAt: Int = 0
    ) -> String? {
        guard let markerIndex = index(of: Array(marker.utf8), in: bytes, startingAt: startingAt) else {
            return nil
        }
        var cursor = markerIndex + marker.utf8.count
        while cursor < bytes.count, bytes[cursor] != 0x28 { cursor += 1 }
        guard cursor < bytes.count else { return nil }
        cursor += 1
        let start = cursor
        while cursor < bytes.count, bytes[cursor] != 0x29 { cursor += 1 }
        guard cursor > start else { return nil }
        return String(bytes: bytes[start..<cursor], encoding: .ascii)
    }

    private static func engineNumber(after marker: String, in bytes: [UInt8]) -> Double? {
        guard let markerIndex = index(of: Array(marker.utf8), in: bytes) else { return nil }
        var cursor = markerIndex + marker.utf8.count
        while cursor < bytes.count,
              !((bytes[cursor] >= 0x30 && bytes[cursor] <= 0x39) || bytes[cursor] == 0x2D || bytes[cursor] == 0x2B) {
            cursor += 1
        }
        let start = cursor
        if cursor < bytes.count, bytes[cursor] == 0x2D || bytes[cursor] == 0x2B { cursor += 1 }
        while cursor < bytes.count,
              (bytes[cursor] >= 0x30 && bytes[cursor] <= 0x39 || bytes[cursor] == 0x2E) {
            cursor += 1
        }
        guard cursor > start else { return nil }
        return Double(String(bytes: bytes[start..<cursor], encoding: .ascii) ?? "")
    }

    private static func engineBoolean(after marker: String, in bytes: [UInt8]) -> Bool? {
        guard let markerIndex = index(of: Array(marker.utf8), in: bytes) else { return nil }
        let start = markerIndex + marker.utf8.count
        let end = min(bytes.count, start + 64)
        guard start < end else { return nil }
        let remainder = Array(bytes[start..<end])
        let trueIndex = index(of: Array("true".utf8), in: remainder)
        let falseIndex = index(of: Array("false".utf8), in: remainder)
        switch (trueIndex, falseIndex) {
        case let (trueIndex?, falseIndex?):
            return trueIndex < falseIndex
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        default:
            return nil
        }
    }

    private static func engineColor(after marker: String, in bytes: [UInt8]) -> NSColor? {
        guard let markerIndex = index(of: Array(marker.utf8), in: bytes),
              let valuesIndex = index(of: Array("/Values".utf8), in: bytes, startingAt: markerIndex),
              let openIndex = bytes[valuesIndex...].firstIndex(of: 0x5B),
              let closeIndex = bytes[openIndex...].firstIndex(of: 0x5D)
        else { return nil }
        let valueBytes = Array(bytes[(openIndex + 1)..<closeIndex])
        let values = valueBytes
            .split(whereSeparator: { $0 == 0x20 || $0 == 0x0A || $0 == 0x0D || $0 == 0x09 })
            .compactMap { Double(String(bytes: $0, encoding: .ascii) ?? "") }
        guard values.count >= 3 else { return nil }
        return NSColor(
            calibratedRed: CGFloat(min(max(values[0], 0), 1)),
            green: CGFloat(min(max(values[1], 0), 1)),
            blue: CGFloat(min(max(values[2], 0), 1)),
            alpha: CGFloat(min(max(values.count > 3 ? values[3] : 1, 0), 1))
        )
    }

    private static func index(of needle: [UInt8], in bytes: [UInt8], startingAt: Int = 0) -> Int? {
        guard !needle.isEmpty, startingAt >= 0, startingAt + needle.count <= bytes.count else { return nil }
        for candidate in startingAt...(bytes.count - needle.count) {
            if Array(bytes[candidate..<(candidate + needle.count)]) == needle { return candidate }
        }
        return nil
    }

    private static func makeLayer(
        record: PSDLayerRecord,
        channels: PSDChannels,
        canvasHeight: Int
    ) -> ImageEditorLayer? {
        let width = record.right - record.left
        let height = record.bottom - record.top
        guard width > 0, height > 0 else { return nil }
        if let textInfo = record.textInfo {
            var content = ImageEditorTextContent(
                text: textInfo.text,
                color: textInfo.color,
                fontSize: textInfo.fontSize,
                point: .zero
            )
            content.fontFamilyName = textInfo.fontFamilyName
            content.isBold = textInfo.isBold
            content.isItalic = textInfo.isItalic
            content.isUnderlined = textInfo.isUnderlined
            content.isStruckThrough = textInfo.isStruckThrough
            content.characterSpacing = textInfo.characterSpacing
            content.lineSpacing = textInfo.lineSpacing
            content.leftIndent = textInfo.leftIndent
            content.rightIndent = textInfo.rightIndent
            content.firstLineIndent = textInfo.firstLineIndent
            content.alignment = textInfo.alignment
            let paragraphSize = textInfo.paragraphBoxSize ?? CGSize(width: width, height: height)
            content.boxWidth = textInfo.isParagraph ? paragraphSize.width : 0
            content.boxHeight = textInfo.isParagraph ? paragraphSize.height : 0
            var layer = ImageEditorLayer.text(
                name: record.name,
                size: CGSize(width: width, height: height),
                content: content
            )
            layer.frame = CGRect(
                x: record.left,
                y: canvasHeight - record.bottom,
                width: width,
                height: height
            )
            layer.opacity = CGFloat(record.opacity) / 255
            layer.fillOpacity = CGFloat(record.fillOpacity) / 255
            layer.isVisible = record.flags & 2 == 0
            applyProtection(record: record, to: &layer)
            layer.isClippingMask = record.clipping != 0
            layer.blendMode = ImageEditorBlendMode(psdKey: record.blendKey)
            applyMask(record: record, channels: channels, to: &layer)
            applyVectorMask(record: record, size: CGSize(width: width, height: height), to: &layer)
            return layer
        }
        guard let image = imageFromChannels(channels, width: width, height: height) else { return nil }
        var layer = ImageEditorLayer.blank(name: record.name, size: image.size)
        layer.image = image
        layer.frame = CGRect(
            x: record.left,
            y: canvasHeight - record.bottom,
            width: width,
            height: height
        )
        layer.opacity = CGFloat(record.opacity) / 255
        layer.fillOpacity = CGFloat(record.fillOpacity) / 255
        layer.isVisible = record.flags & 2 == 0
        applyProtection(record: record, to: &layer)
        layer.isClippingMask = record.clipping != 0
        layer.blendMode = ImageEditorBlendMode(psdKey: record.blendKey)
        applyMask(record: record, channels: channels, to: &layer)
        applyVectorMask(record: record, size: image.size, to: &layer)
        return layer
    }

    private static func applyVectorMask(
        record: PSDLayerRecord,
        size: CGSize,
        to layer: inout ImageEditorLayer
    ) {
        guard let info = record.vectorMaskInfo else { return }
        let subpaths = info.subpaths.map { anchors in
            anchors.map { anchor in
                ImageEditorPathAnchor(
                    point: CGPoint(x: anchor.point.x * size.width, y: anchor.point.y * size.height),
                    inControl: anchor.inControl.map {
                        CGPoint(x: $0.x * size.width, y: $0.y * size.height)
                    },
                    outControl: anchor.outControl.map {
                        CGPoint(x: $0.x * size.width, y: $0.y * size.height)
                    }
                )
            }
        }
        guard let anchors = subpaths.first, anchors.count >= 3 else { return }
        let content = ImageEditorShapeContent(
            kind: .path,
            fillColor: .white,
            fillOpacity: 1,
            strokeColor: .clear,
            strokeWidth: 1,
            strokeOpacity: 0,
            pathPoints: anchors.map(\.point),
            pathAnchors: anchors,
            pathSubpaths: Array(subpaths.dropFirst()),
            isPathClosed: true
        ).normalized(size: size)
        layer.vectorMask = content
        layer.isVectorMaskEnabled = info.isEnabled
    }

    private static func parseVectorMask(_ data: Data) -> PSDVectorMaskInfo? {
        do {
            var reader = PSDReader(data: data)
            guard try reader.uint32() == 3 else { return nil }
            let flags = try reader.uint32()
            guard flags & 0b011 == 0 else { return nil }
            var expectedKnotCount: Int?
            var currentSubpath: [ImageEditorPathAnchor] = []
            var subpaths: [[ImageEditorPathAnchor]] = []
            while reader.offset + 26 <= data.count {
                let selector = try reader.uint16()
                let payload = try reader.data(count: 24)
                switch selector {
                case 0:
                    guard expectedKnotCount == nil else { return nil }
                    let count = Int(UInt16(payload[payload.startIndex]) << 8 | UInt16(payload[payload.startIndex + 1]))
                    guard count >= 3 else { return nil }
                    expectedKnotCount = count
                    currentSubpath = []
                case 1, 2:
                    guard let knotCount = expectedKnotCount,
                          currentSubpath.count < knotCount
                    else { return nil }
                    let previousControl = vectorPathPoint(in: payload, at: 0)
                    let anchor = vectorPathPoint(in: payload, at: 8)
                    let nextControl = vectorPathPoint(in: payload, at: 16)
                    currentSubpath.append(
                        ImageEditorPathAnchor(
                            point: anchor,
                            inControl: previousControl,
                            outControl: nextControl
                        )
                    )
                    if currentSubpath.count == knotCount {
                        subpaths.append(currentSubpath)
                        currentSubpath = []
                        expectedKnotCount = nil
                    }
                case 6, 7, 8:
                    continue
                default:
                    return nil
                }
            }
            guard expectedKnotCount == nil,
                  currentSubpath.isEmpty,
                  !subpaths.isEmpty,
                  subpaths.allSatisfy({ $0.count >= 3 })
            else { return nil }
            return PSDVectorMaskInfo(
                subpaths: subpaths,
                isEnabled: flags & 0b100 == 0
            )
        } catch {
            return nil
        }
    }

    private static func vectorPathPoint(in payload: Data, at offset: Int) -> CGPoint {
        func fixed(_ index: Int) -> CGFloat {
            let start = payload.startIndex + index
            let bits = UInt32(payload[start]) << 24
                | UInt32(payload[start + 1]) << 16
                | UInt32(payload[start + 2]) << 8
                | UInt32(payload[start + 3])
            return CGFloat(Double(Int32(bitPattern: bits)) / 16_777_216)
        }
        return CGPoint(x: fixed(offset + 4), y: fixed(offset))
    }

    private static func makeGroupLayer(
        record: PSDLayerRecord,
        channels: PSDChannels,
        canvasSize: CGSize,
        parentGroupID: UUID?
    ) -> ImageEditorLayer {
        var layer = ImageEditorLayer.group(name: record.name, size: canvasSize)
        layer.frame = CGRect(origin: .zero, size: canvasSize)
        layer.groupID = parentGroupID
        layer.opacity = CGFloat(record.opacity) / 255
        layer.fillOpacity = CGFloat(record.fillOpacity) / 255
        layer.isVisible = record.flags & 2 == 0
        layer.isGroupExpanded = record.sectionType != 2
        layer.blendMode = ImageEditorBlendMode(psdKey: record.blendKey)
        applyProtection(record: record, to: &layer)
        applyMask(
            record: record,
            channels: channels,
            targetTop: 0,
            targetLeft: 0,
            to: &layer
        )
        return layer
    }

    private static func applyProtection(
        record: PSDLayerRecord,
        to layer: inout ImageEditorLayer
    ) {
        let flags = record.protectionFlags
        layer.locksTransparentPixels = record.flags & 1 != 0 || flags & 1 != 0
        layer.locksPixels = flags & 2 != 0
        layer.locksPosition = flags & 4 != 0
        layer.isLocked = flags & 7 == 7
    }

    private static func applyMask(
        record: PSDLayerRecord,
        channels: PSDChannels,
        targetTop: Int? = nil,
        targetLeft: Int? = nil,
        to layer: inout ImageEditorLayer
    ) {
        guard let maskRecord = record.mask,
              let userMask = channels.userMask,
              let mask = maskImage(
                maskRecord: maskRecord,
                values: userMask,
                targetSize: layer.image.size,
                targetTop: targetTop ?? record.top,
                targetLeft: targetLeft ?? record.left
              )
        else { return }
        layer.mask = mask
        layer.isMaskLinked = maskRecord.flags & 1 != 0
        layer.isMaskEnabled = maskRecord.flags & 2 == 0
    }

    private static func maskImage(
        maskRecord: PSDLayerMaskRecord,
        values: Data,
        targetSize: CGSize,
        targetTop: Int,
        targetLeft: Int
    ) -> NSImage? {
        let width = max(1, Int(targetSize.width.rounded()))
        let height = max(1, Int(targetSize.height.rounded()))
        let maskWidth = max(0, maskRecord.right - maskRecord.left)
        let maskHeight = max(0, maskRecord.bottom - maskRecord.top)
        guard maskWidth > 0, maskHeight > 0, values.count >= maskWidth * maskHeight else { return nil }
        var alpha = [UInt8](repeating: maskRecord.defaultColor, count: width * height)
        for row in 0..<maskHeight {
            let localY = maskRecord.top + row - targetTop
            guard (0..<height).contains(localY) else { continue }
            for column in 0..<maskWidth {
                let localX = maskRecord.left + column - targetLeft
                guard (0..<width).contains(localX), (0..<height).contains(localY) else { continue }
                alpha[localY * width + localX] = values[row * maskWidth + column]
            }
        }
        return alphaMaskImage(width: width, height: height, topDownAlpha: alpha)
    }

    private static func rgbaChannels(image: NSImage, width: Int, height: Int) -> PSDChannels? {
        guard width > 0, height > 0,
              let rendered = NSImage.rendered(size: CGSize(width: width, height: height), actions: { rect in
                  image.draw(in: rect, from: CGRect(origin: .zero, size: image.size), operation: .copy, fraction: 1)
              }),
              let representation = NSBitmapImageRep(data: rendered.tiffRepresentation ?? Data())
        else { return nil }
        var channels = PSDChannels.empty(pixelCount: width * height)
        for row in 0..<height {
            let imageY = height - row - 1
            for x in 0..<width {
                let color = (representation.colorAt(x: x, y: imageY) ?? .clear)
                    .usingColorSpace(.deviceRGB) ?? .clear
                let index = row * width + x
                channels.red[index] = UInt8((color.redComponent * 255).rounded().clamped(to: 0...255))
                channels.green[index] = UInt8((color.greenComponent * 255).rounded().clamped(to: 0...255))
                channels.blue[index] = UInt8((color.blueComponent * 255).rounded().clamped(to: 0...255))
                channels.alpha[index] = UInt8((color.alphaComponent * 255).rounded().clamped(to: 0...255))
            }
        }
        return channels
    }

    private static func alphaPlane(image: NSImage, width: Int, height: Int) -> Data? {
        guard width > 0, height > 0,
              let rendered = NSImage.rendered(size: CGSize(width: width, height: height), actions: { rect in
                  image.draw(in: rect, from: CGRect(origin: .zero, size: image.size), operation: .copy, fraction: 1)
              }),
              let representation = NSBitmapImageRep(data: rendered.tiffRepresentation ?? Data())
        else { return nil }
        var alpha = Data(repeating: 0, count: width * height)
        for row in 0..<height {
            let imageY = height - row - 1
            for x in 0..<width {
                alpha[row * width + x] = UInt8(
                    ((representation.colorAt(x: x, y: imageY)?.alphaComponent ?? 0) * 255)
                        .rounded()
                        .clamped(to: 0...255)
                )
            }
        }
        return alpha
    }

    private static func imageFromChannels(_ channels: PSDChannels, width: Int, height: Int) -> NSImage? {
        guard channels.red.count >= width * height,
              channels.green.count >= width * height,
              channels.blue.count >= width * height,
              channels.alpha.count >= width * height,
              let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: width,
                pixelsHigh: height,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bitmapFormat: .alphaNonpremultiplied,
                bytesPerRow: width * 4,
                bitsPerPixel: 32
              ), let pixels = bitmap.bitmapData
        else { return nil }
        for row in 0..<height {
            let imageY = height - row - 1
            for x in 0..<width {
                let source = row * width + x
                let destination = (imageY * width + x) * 4
                pixels[destination] = channels.red[source]
                pixels[destination + 1] = channels.green[source]
                pixels[destination + 2] = channels.blue[source]
                pixels[destination + 3] = channels.alpha[source]
            }
        }
        let image = NSImage(size: CGSize(width: width, height: height))
        image.addRepresentation(bitmap)
        return image
    }

    private static func alphaMaskImage(
        width: Int,
        height: Int,
        topDownAlpha: [UInt8]
    ) -> NSImage? {
        guard topDownAlpha.count >= width * height,
              let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: width,
                pixelsHigh: height,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bitmapFormat: .alphaNonpremultiplied,
                bytesPerRow: width * 4,
                bitsPerPixel: 32
              ),
              let pixels = bitmap.bitmapData
        else { return nil }
        for row in 0..<height {
            let imageY = height - row - 1
            for x in 0..<width {
                let destination = (imageY * width + x) * 4
                pixels[destination] = 255
                pixels[destination + 1] = 255
                pixels[destination + 2] = 255
                pixels[destination + 3] = topDownAlpha[row * width + x]
            }
        }
        let image = NSImage(size: CGSize(width: width, height: height))
        image.addRepresentation(bitmap)
        return image
    }
}

private struct PSDExportLayer {
    let name: String
    let frame: CGRect
    let canvasHeight: Int
    let channels: [PSDExportChannel]
    let opacity: Double
    let fillOpacity: Double
    let blendMode: ImageEditorBlendMode
    let isVisible: Bool
    let isClippingMask: Bool
    let isLocked: Bool
    let locksPixels: Bool
    let locksPosition: Bool
    let locksTransparentPixels: Bool
    let sectionType: Int?
    let mask: PSDExportMask?
    let vectorMask: PSDExportVectorMask?
    let textObject: PSDExportText?

    static func groupDivider(canvasHeight: Int) -> PSDExportLayer {
        PSDExportLayer(
            name: "</Layer group>",
            frame: .zero,
            canvasHeight: canvasHeight,
            channels: [],
            opacity: 1,
            fillOpacity: 1,
            blendMode: .normal,
            isVisible: false,
            isClippingMask: false,
            isLocked: false,
            locksPixels: false,
            locksPosition: false,
            locksTransparentPixels: false,
            sectionType: 3,
            mask: nil,
            vectorMask: nil,
            textObject: nil
        )
    }
}

private struct PSDExportChannel {
    let identifier: Int16
    let data: Data
}

private struct PSDExportMask {
    let alpha: Data
    let isEnabled: Bool
    let isLinked: Bool
}

private struct PSDExportVectorMask {
    let data: Data
}

private struct PSDExportText {
    let data: Data
}

nonisolated private struct PSDCompositeChannels {
    let channels: PSDChannels
    let alphaChannels: [ImageEditorAlphaChannel]
}

nonisolated private struct PSDAlphaChannelDisplayInfo {
    let colorSpace: UInt16
    let components: [UInt16]
    let opacity: UInt16
    let mode: UInt8
}

nonisolated private struct PSDParsedDocument: @unchecked Sendable {
    let width: Int
    let height: Int
    let layers: [PSDParsedLayer]
    let composite: PSDChannels?
    let savedPaths: [ImageEditorSavedPath]
    let alphaChannels: [ImageEditorAlphaChannel]
}

nonisolated private struct PSDParsedLayer {
    let record: PSDLayerRecord
    let channels: PSDChannels
}

private enum PSDDescriptorValue {
    case string(String)
    case raw(Data)
    case integer(Int32)
    case double(Double)
    case unit(Double)
    case boolean(Bool)
    case object([String: PSDDescriptorValue])
    case list([PSDDescriptorValue])
    case unknown

    var stringValue: String? {
        guard case let .string(value) = self else { return nil }
        return value
    }

    var rawData: Data? {
        guard case let .raw(value) = self else { return nil }
        return value
    }
}

private struct PSDTextLayerStyle {
    let text: String?
    let fontFamilyName: String?
    let fontSize: CGFloat?
    let color: NSColor?
    let alignment: ImageEditorTextAlignment?
    let isParagraph: Bool?
    let isBold: Bool
    let isItalic: Bool
    let isUnderlined: Bool
    let isStruckThrough: Bool
    let characterSpacing: CGFloat
    let lineSpacing: CGFloat
    let leftIndent: CGFloat
    let rightIndent: CGFloat
    let firstLineIndent: CGFloat
}

private struct PSDTextLayerInfo {
    let text: String
    let fontFamilyName: String
    let fontSize: CGFloat
    let color: NSColor
    let alignment: ImageEditorTextAlignment
    let isParagraph: Bool
    let isBold: Bool
    let isItalic: Bool
    let isUnderlined: Bool
    let isStruckThrough: Bool
    let characterSpacing: CGFloat
    let lineSpacing: CGFloat
    let leftIndent: CGFloat
    let rightIndent: CGFloat
    let firstLineIndent: CGFloat
    let paragraphBoxSize: CGSize?
}

private struct PSDVectorMaskInfo {
    let subpaths: [[ImageEditorPathAnchor]]
    let isEnabled: Bool
}

nonisolated private struct PSDLayerRecord {
    let top: Int
    let left: Int
    let bottom: Int
    let right: Int
    let channels: [(Int16, Int)]
    let name: String
    let opacity: UInt8
    let clipping: UInt8
    let flags: UInt8
    let blendKey: String
    let fillOpacity: UInt8
    let protectionFlags: UInt32
    let sectionType: Int?
    let mask: PSDLayerMaskRecord?
    let additionalKeys: Set<String>
    let textInfo: PSDTextLayerInfo?
    let vectorMaskInfo: PSDVectorMaskInfo?

    func channelDimensions(identifier: Int16) -> (width: Int, height: Int) {
        if identifier == -2 || identifier == -3, let mask {
            return (max(0, mask.right - mask.left), max(0, mask.bottom - mask.top))
        }
        return (max(0, right - left), max(0, bottom - top))
    }
}

nonisolated private struct PSDLayerMaskRecord {
    let top: Int
    let left: Int
    let bottom: Int
    let right: Int
    let defaultColor: UInt8
    let flags: UInt8
}

nonisolated private struct PSDChannels {
    var red: Data
    var green: Data
    var blue: Data
    var alpha: Data
    var userMask: Data?

    static func empty(pixelCount: Int) -> PSDChannels {
        PSDChannels(
            red: Data(repeating: 0, count: pixelCount),
            green: Data(repeating: 0, count: pixelCount),
            blue: Data(repeating: 0, count: pixelCount),
            alpha: Data(repeating: 255, count: pixelCount),
            userMask: nil
        )
    }
}

nonisolated private struct PSDReader {
    let data: Data
    var offset = 0

    mutating func uint8() throws -> UInt8 {
        guard offset < data.count else { throw ImageEditorPSDCodecError.invalidFile }
        defer { offset += 1 }
        return data[offset]
    }

    mutating func uint16() throws -> UInt16 {
        let bytes = try self.data(count: 2)
        return bytes.reduce(0) { ($0 << 8) | UInt16($1) }
    }

    mutating func int16() throws -> Int16 { Int16(bitPattern: try uint16()) }

    mutating func uint32() throws -> UInt32 {
        let bytes = try self.data(count: 4)
        return bytes.reduce(0) { ($0 << 8) | UInt32($1) }
    }

    mutating func int32() throws -> Int32 { Int32(bitPattern: try uint32()) }

    mutating func data(count: Int) throws -> Data {
        let end = try checkedEnd(length: count)
        defer { offset = end }
        return data.subdata(in: offset..<end)
    }

    mutating func ascii(count: Int) throws -> String {
        String(data: try data(count: count), encoding: .ascii) ?? ""
    }

    mutating func skip(_ count: Int) throws { offset = try checkedEnd(length: count) }

    mutating func skipLengthPrefixed32() throws { try skip(Int(try uint32())) }

    mutating func lengthPrefixedData32() throws -> Data {
        try data(count: Int(try uint32()))
    }

    func checkedEnd(length: Int) throws -> Int {
        guard length >= 0, offset <= data.count - length else { throw ImageEditorPSDCodecError.invalidFile }
        return offset + length
    }

    mutating func pascalString(alignment: Int) throws -> String {
        let start = offset
        let length = Int(try uint8())
        let bytes = try data(count: length)
        let consumed = offset - start
        let padding = (alignment - consumed % alignment) % alignment
        try skip(padding)
        return String(data: bytes, encoding: .macOSRoman) ?? String(data: bytes, encoding: .utf8) ?? "Layer"
    }

    mutating func unicodeString() throws -> String {
        let count = Int(try uint32())
        let bytes = try data(count: count * 2)
        return String(data: bytes, encoding: .utf16BigEndian) ?? ""
    }

    mutating func descriptorKey() throws -> String {
        let length = Int(try uint32())
        return try ascii(count: length == 0 ? 4 : length)
    }

    mutating func doubleValue() throws -> Double {
        let bytes = try data(count: 8)
        let bits = bytes.reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        return Double(bitPattern: bits)
    }

    mutating func psdDescriptorBlock() throws -> [String: PSDDescriptorValue] {
        _ = try uint32()
        return try psdDescriptorBody()
    }

    mutating func psdDescriptorBody() throws -> [String: PSDDescriptorValue] {
        _ = try unicodeString()
        _ = try descriptorKey()
        let count = Int(try uint32())
        guard count >= 0, count <= 10_000 else { throw ImageEditorPSDCodecError.invalidFile }
        var result: [String: PSDDescriptorValue] = [:]
        for _ in 0..<count {
            let key = try descriptorKey()
            let type = try ascii(count: 4)
            result[key] = try psdDescriptorValue(type: type)
        }
        return result
    }

    mutating func psdDescriptorValue(type: String) throws -> PSDDescriptorValue {
        switch type {
        case "TEXT":
            return .string(try unicodeString())
        case "tdta", "alis":
            return .raw(try lengthPrefixedData32())
        case "Objc", "GlbO":
            return .object(try psdDescriptorBody())
        case "VlLs":
            let count = Int(try uint32())
            guard count >= 0, count <= 10_000 else { throw ImageEditorPSDCodecError.invalidFile }
            var values: [PSDDescriptorValue] = []
            values.reserveCapacity(count)
            for _ in 0..<count {
                values.append(try psdDescriptorValue(type: ascii(count: 4)))
            }
            return .list(values)
        case "doub":
            return .double(try doubleValue())
        case "long":
            return .integer(try int32())
        case "bool":
            return .boolean(try uint8() != 0)
        case "UntF":
            _ = try ascii(count: 4)
            return .unit(try doubleValue())
        case "enum":
            _ = try descriptorKey()
            _ = try descriptorKey()
            return .unknown
        case "type", "Clss":
            _ = try unicodeString()
            _ = try descriptorKey()
            return .unknown
        case "comp":
            _ = try uint32()
            _ = try uint32()
            return .unknown
        case "rele":
            return .double(try doubleValue())
        default:
            throw ImageEditorPSDCodecError.invalidFile
        }
    }
}

private extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        append(contentsOf: [UInt8(value >> 8), UInt8(value & 0xFF)])
    }

    mutating func appendInt16(_ value: Int16) { appendUInt16(UInt16(bitPattern: value)) }

    mutating func appendUInt32(_ value: UInt32) {
        append(contentsOf: [
            UInt8((value >> 24) & 0xFF), UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)
        ])
    }

    mutating func appendUInt64(_ value: UInt64) {
        append(contentsOf: [
            UInt8((value >> 56) & 0xFF), UInt8((value >> 48) & 0xFF),
            UInt8((value >> 40) & 0xFF), UInt8((value >> 32) & 0xFF),
            UInt8((value >> 24) & 0xFF), UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)
        ])
    }

    mutating func appendDouble(_ value: Double) {
        appendUInt64(value.bitPattern)
    }

    mutating func appendInt32(_ value: Int32) { appendUInt32(UInt32(bitPattern: value)) }

    mutating func appendASCII(_ value: String) {
        append(value.data(using: .ascii) ?? Data())
    }

    mutating func appendPascalString(_ value: String, alignment: Int) {
        let encoded = value.data(using: .macOSRoman, allowLossyConversion: true) ?? Data("Layer".utf8)
        let bytes = encoded.prefix(255)
        let start = count
        append(UInt8(bytes.count))
        append(bytes)
        while (count - start) % alignment != 0 { append(0) }
    }

    mutating func appendUnicodeLayerName(_ value: String) {
        let utf16 = Array(value.utf16)
        var block = Data()
        block.appendUInt32(UInt32(utf16.count))
        for codeUnit in utf16 { block.appendUInt16(codeUnit) }
        appendASCII("8BIM")
        appendASCII("luni")
        appendUInt32(UInt32(block.count))
        append(block)
        if block.count % 2 != 0 { append(0) }
    }

    mutating func appendLayerMask(
        _ mask: PSDExportMask?,
        frame: CGRect,
        canvasHeight: Int
    ) {
        guard let mask else {
            appendUInt32(0)
            return
        }
        appendUInt32(20)
        appendInt32(Int32(canvasHeight - Int(frame.maxY)))
        appendInt32(Int32(frame.minX))
        appendInt32(Int32(canvasHeight - Int(frame.minY)))
        appendInt32(Int32(frame.maxX))
        append(0)
        var flags: UInt8 = mask.isLinked ? 1 : 0
        if !mask.isEnabled { flags |= 2 }
        append(flags)
        appendUInt16(0)
    }

    mutating func appendFillOpacity(_ opacity: Double) {
        appendASCII("8BIM")
        appendASCII("iOpa")
        appendUInt32(4)
        append(UInt8((opacity * 255).rounded().clamped(to: 0...255)))
        append(contentsOf: [0, 0, 0])
    }

    mutating func appendProtectionFlags(
        isLocked: Bool,
        locksPixels: Bool,
        locksPosition: Bool,
        locksTransparentPixels: Bool
    ) {
        var flags: UInt32 = 0
        if isLocked || locksTransparentPixels { flags |= 1 }
        if isLocked || locksPixels { flags |= 2 }
        if isLocked || locksPosition { flags |= 4 }
        guard flags != 0 else { return }
        appendASCII("8BIM")
        appendASCII("lspf")
        appendUInt32(4)
        appendUInt32(flags)
    }

    mutating func appendSectionDivider(type: Int, blendMode: ImageEditorBlendMode) {
        appendASCII("8BIM")
        appendASCII("lsct")
        if type == 3 {
            appendUInt32(4)
            appendUInt32(UInt32(type))
            return
        }
        appendUInt32(12)
        appendUInt32(UInt32(type))
        appendASCII("8BIM")
        appendASCII(blendMode.psdKey)
    }

    mutating func appendVectorMask(_ mask: PSDExportVectorMask?) {
        guard let mask else { return }
        appendASCII("8BIM")
        appendASCII("vmsk")
        appendUInt32(UInt32(mask.data.count))
        append(mask.data)
        if mask.data.count % 2 != 0 { append(0) }
    }

    mutating func appendTextToolObject(_ text: PSDExportText?) {
        guard let text else { return }
        appendASCII("8BIM")
        appendASCII("TySh")
        appendUInt32(UInt32(text.data.count))
        append(text.data)
        if text.data.count % 2 != 0 { append(0) }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

private extension ImageEditorBlendMode {
    var psdKey: String {
        switch self {
        case .dissolve: "diss"
        case .multiply: "mul "
        case .screen: "scrn"
        case .overlay: "over"
        case .softLight: "sLit"
        case .hardLight: "hLit"
        case .darken: "dark"
        case .lighten: "lite"
        case .darkerColor: "dkCl"
        case .lighterColor: "lgCl"
        case .colorDodge: "div "
        case .colorBurn: "idiv"
        case .linearDodge: "lddg"
        case .linearBurn: "lbrn"
        case .subtract: "fsub"
        case .divide: "fdiv"
        case .vividLight: "vLit"
        case .linearLight: "lLit"
        case .pinLight: "pLit"
        case .hardMix: "hMix"
        case .difference: "diff"
        case .exclusion: "smud"
        case .hue: "hue "
        case .saturation: "sat "
        case .color: "colr"
        case .luminosity: "lum "
        case .passThrough: "pass"
        default: "norm"
        }
    }

    init(psdKey: String) {
        switch psdKey {
        case "diss": self = .dissolve
        case "mul ": self = .multiply
        case "scrn": self = .screen
        case "over": self = .overlay
        case "sLit": self = .softLight
        case "hLit": self = .hardLight
        case "dark": self = .darken
        case "lite": self = .lighten
        case "dkCl": self = .darkerColor
        case "lgCl": self = .lighterColor
        case "div ": self = .colorDodge
        case "idiv": self = .colorBurn
        case "lddg": self = .linearDodge
        case "lbrn": self = .linearBurn
        case "fsub": self = .subtract
        case "fdiv": self = .divide
        case "vLit": self = .vividLight
        case "lLit": self = .linearLight
        case "pLit": self = .pinLight
        case "hMix": self = .hardMix
        case "diff": self = .difference
        case "smud": self = .exclusion
        case "hue ": self = .hue
        case "sat ": self = .saturation
        case "colr": self = .color
        case "lum ": self = .luminosity
        case "pass": self = .passThrough
        default: self = .normal
        }
    }

    static let supportedPSDKeys: Set<String> = [
        "pass", "norm", "diss", "dark", "mul ", "idiv", "lbrn", "dkCl",
        "lite", "scrn", "div ", "lddg", "lgCl", "over", "sLit", "hLit",
        "vLit", "lLit", "pLit", "hMix", "diff", "smud", "fsub", "fdiv",
        "hue ", "sat ", "colr", "lum "
    ]
}
