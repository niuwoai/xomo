//
//  ImageEditorPSD.swift
//  veilpic
//
//  Created by Codex on 2026/7/11.
//

import AppKit
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

        let exportLayers = try document.layers.reversed().compactMap { layer -> PSDExportLayer? in
            guard !layer.isGroup, !layer.isAdjustment, !layer.isFilter else { return nil }
            let frame = integralPSDFrame(layer.frame, canvasSize: document.canvasSize)
            guard frame.width > 0, frame.height > 0 else { return nil }
            let rendered = layer.renderedCompositingImage(globalLightAngle: document.globalLightAngle)
            guard let rgba = rgbaChannels(image: rendered, width: Int(frame.width), height: Int(frame.height)) else {
                throw ImageEditorPSDCodecError.imageEncodingFailed
            }
            return PSDExportLayer(layer: layer, frame: frame, canvasHeight: height, channels: rgba)
        }

        var output = Data()
        output.appendASCII("8BPS")
        output.appendUInt16(1)
        output.append(Data(repeating: 0, count: 6))
        output.appendUInt16(4)
        output.appendUInt32(UInt32(height))
        output.appendUInt32(UInt32(width))
        output.appendUInt16(8)
        output.appendUInt16(3)
        output.appendUInt32(0)
        output.appendUInt32(0)

        var layerInfo = Data()
        layerInfo.appendInt16(Int16(exportLayers.count))
        for item in exportLayers {
            layerInfo.append(layerRecord(item))
        }
        for item in exportLayers {
            for channel in item.orderedChannels {
                layerInfo.appendUInt16(0)
                layerInfo.append(channel)
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
        return output
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
        guard (3...4).contains(channelCount), width > 0, height > 0, depth == 8, colorMode == 3 else {
            throw ImageEditorPSDCodecError.unsupportedDocument
        }
        try reader.skipLengthPrefixed32()
        try reader.skipLengthPrefixed32()

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

        if !decodedLayers.isEmpty {
            return PSDParsedDocument(
                width: width,
                height: height,
                layers: decodedLayers,
                composite: nil
            )
        }

        let composite = try readCompositeChannels(
            &reader,
            width: width,
            height: height,
            channelCount: channelCount
        )
        return PSDParsedDocument(
            width: width,
            height: height,
            layers: [],
            composite: composite
        )
    }

    private static func materialize(
        _ parsed: PSDParsedDocument,
        sourceName: String
    ) throws -> ImageEditorDocument {
        let decodedLayers = parsed.layers.compactMap {
            makeLayer(record: $0.record, channels: $0.channels, canvasHeight: parsed.height)
        }
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
        for item in parsed.layers {
            try Task.checkCancellation()
            if let layer = makeLayer(
                record: item.record,
                channels: item.channels,
                canvasHeight: parsed.height
            ) {
                decodedLayers.append(layer)
            }
            await Task.yield()
        }
        return try materializedDocument(
            parsed: parsed,
            decodedLayers: decodedLayers,
            sourceName: sourceName
        )
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
            document.history = [ImageEditorHistoryEntry(title: L10n.text("imageEditor.history.psdOpen"))]
            return document
        }

        guard let composite = parsed.composite,
              let image = imageFromChannels(composite, width: parsed.width, height: parsed.height)
        else {
            throw ImageEditorPSDCodecError.invalidFile
        }
        return ImageEditorDocument(sourceName: sourceName, image: image)
    }

    private static func integralPSDFrame(_ frame: CGRect, canvasSize: CGSize) -> CGRect {
        frame.standardized.integral.intersection(CGRect(origin: .zero, size: canvasSize))
    }

    private static func layerRecord(_ item: PSDExportLayer) -> Data {
        let top = Int32(item.canvasHeight - Int(item.frame.maxY))
        let left = Int32(item.frame.minX)
        let bottom = Int32(item.canvasHeight - Int(item.frame.minY))
        let right = Int32(item.frame.maxX)
        let pixelCount = UInt32(Int(item.frame.width) * Int(item.frame.height) + 2)

        var record = Data()
        record.appendInt32(top)
        record.appendInt32(left)
        record.appendInt32(bottom)
        record.appendInt32(right)
        record.appendUInt16(4)
        for identifier: Int16 in [-1, 0, 1, 2] {
            record.appendInt16(identifier)
            record.appendUInt32(pixelCount)
        }
        record.appendASCII("8BIM")
        record.appendASCII(item.layer.blendMode.psdKey)
        record.append(UInt8((item.layer.opacity * 255).rounded().clamped(to: 0...255)))
        record.append(item.layer.isClippingMask ? 1 : 0)
        var flags: UInt8 = item.layer.locksTransparentPixels ? 1 : 0
        if !item.layer.isVisible { flags |= 2 }
        record.append(flags)
        record.append(0)

        var extra = Data()
        extra.appendUInt32(0)
        extra.appendUInt32(0)
        extra.appendPascalString(item.layer.name, alignment: 4)
        extra.appendUnicodeLayerName(item.layer.name)
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
        try reader.skipLengthPrefixed32()
        try reader.skipLengthPrefixed32()
        var name = try reader.pascalString(alignment: 4)
        while reader.offset + 12 <= extraEnd {
            let signature = try reader.ascii(count: 4)
            let key = try reader.ascii(count: 4)
            let length = Int(try reader.uint32())
            let blockEnd = min(try reader.checkedEnd(length: length), extraEnd)
            if signature == "8BIM", key == "luni", length >= 4 {
                let count = Int(try reader.uint32())
                let byteCount = min(count * 2, blockEnd - reader.offset)
                let stringData = try reader.data(count: byteCount)
                name = String(data: stringData, encoding: .utf16BigEndian) ?? name
            }
            reader.offset = blockEnd
            let paddedEnd = min(extraEnd, (reader.offset + 3) & ~3)
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
            blendKey: blendKey
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
            let decoded = try readChannel(&reader, width: width, height: height, end: end)
            switch identifier {
            case -1: result.alpha = decoded
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
        channelCount: Int
    ) throws -> PSDChannels {
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
        default:
            throw ImageEditorPSDCodecError.unsupportedCompression
        }
        var channels = PSDChannels.empty(pixelCount: pixelCount)
        if planes.indices.contains(0) { channels.red = planes[0] }
        if planes.indices.contains(1) { channels.green = planes[1] }
        if planes.indices.contains(2) { channels.blue = planes[2] }
        if planes.indices.contains(3) { channels.alpha = planes[3] }
        return channels
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
        default:
            reader.offset = end
            throw ImageEditorPSDCodecError.unsupportedCompression
        }
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

    private static func makeLayer(
        record: PSDLayerRecord,
        channels: PSDChannels,
        canvasHeight: Int
    ) -> ImageEditorLayer? {
        let width = record.right - record.left
        let height = record.bottom - record.top
        guard width > 0, height > 0,
              let image = imageFromChannels(channels, width: width, height: height)
        else { return nil }
        var layer = ImageEditorLayer.blank(name: record.name, size: image.size)
        layer.image = image
        layer.frame = CGRect(
            x: record.left,
            y: canvasHeight - record.bottom,
            width: width,
            height: height
        )
        layer.opacity = CGFloat(record.opacity) / 255
        layer.isVisible = record.flags & 2 == 0
        layer.locksTransparentPixels = record.flags & 1 != 0
        layer.isClippingMask = record.clipping != 0
        layer.blendMode = ImageEditorBlendMode(psdKey: record.blendKey)
        return layer
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
}

private struct PSDExportLayer {
    let layer: ImageEditorLayer
    let frame: CGRect
    let canvasHeight: Int
    let channels: PSDChannels

    var orderedChannels: [Data] { [channels.alpha, channels.red, channels.green, channels.blue] }
}

nonisolated private struct PSDParsedDocument: @unchecked Sendable {
    let width: Int
    let height: Int
    let layers: [PSDParsedLayer]
    let composite: PSDChannels?
}

nonisolated private struct PSDParsedLayer {
    let record: PSDLayerRecord
    let channels: PSDChannels
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
}

nonisolated private struct PSDChannels {
    var red: Data
    var green: Data
    var blue: Data
    var alpha: Data

    static func empty(pixelCount: Int) -> PSDChannels {
        PSDChannels(
            red: Data(repeating: 0, count: pixelCount),
            green: Data(repeating: 0, count: pixelCount),
            blue: Data(repeating: 0, count: pixelCount),
            alpha: Data(repeating: 255, count: pixelCount)
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
        while count % 4 != 0 { append(0) }
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
        case .multiply: "mul "
        case .screen: "scrn"
        case .overlay: "over"
        case .softLight: "sLit"
        case .hardLight: "hLit"
        case .darken: "dark"
        case .lighten: "lite"
        case .colorDodge: "div "
        case .colorBurn: "idiv"
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
        case "mul ": self = .multiply
        case "scrn": self = .screen
        case "over": self = .overlay
        case "sLit": self = .softLight
        case "hLit": self = .hardLight
        case "dark": self = .darken
        case "lite": self = .lighten
        case "div ": self = .colorDodge
        case "idiv": self = .colorBurn
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
}
