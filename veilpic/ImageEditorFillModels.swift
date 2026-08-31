import AppKit
import CoreImage
import Foundation
import simd

struct ImageEditorSolidColorFillContent: Equatable, Codable {
    var red: Double = 1
    var green: Double = 0
    var blue: Double = 0

    func normalized() -> ImageEditorSolidColorFillContent {
        ImageEditorSolidColorFillContent(
            red: Self.zeroOne(red),
            green: Self.zeroOne(green),
            blue: Self.zeroOne(blue)
        )
    }

    var color: NSColor {
        let content = normalized()
        return NSColor(deviceRed: content.red, green: content.green, blue: content.blue, alpha: 1)
    }

    func renderedImage(size: CGSize) -> NSImage {
        NSImage.rendered(size: size) { rect in
            color.setFill()
            rect.fill()
        } ?? NSImage.transparent(size: size)
    }

    private static func zeroOne(_ value: Double) -> Double {
        max(0, min(1, value))
    }
}

struct ImageEditorPatternFillContent: Equatable, Codable {
    var kind: ImageEditorPatternOverlayKind = .checkerboard
    var repeatMode: ImageEditorPatternRepeatMode = .tile
    var red: Double = 0.10
    var green: Double = 0.24
    var blue: Double = 0.95
    var opacity: Double = 0.55
    var scale: CGFloat = 16
    var scaleX: CGFloat = 1
    var scaleY: CGFloat = 1
    var linksAxisScales = false
    var angle: CGFloat = 0
    var flipsHorizontally = false
    var flipsVertically = false
    var offsetX: CGFloat = 0
    var offsetY: CGFloat = 0

    init(
        kind: ImageEditorPatternOverlayKind = .checkerboard,
        repeatMode: ImageEditorPatternRepeatMode = .tile,
        red: Double = 0.10,
        green: Double = 0.24,
        blue: Double = 0.95,
        opacity: Double = 0.55,
        scale: CGFloat = 16,
        scaleX: CGFloat = 1,
        scaleY: CGFloat = 1,
        linksAxisScales: Bool = false,
        angle: CGFloat = 0,
        flipsHorizontally: Bool = false,
        flipsVertically: Bool = false,
        offsetX: CGFloat = 0,
        offsetY: CGFloat = 0
    ) {
        self.kind = kind
        self.repeatMode = repeatMode
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = opacity
        self.scale = scale
        self.scaleX = scaleX
        self.scaleY = scaleY
        self.linksAxisScales = linksAxisScales
        self.angle = angle
        self.flipsHorizontally = flipsHorizontally
        self.flipsVertically = flipsVertically
        self.offsetX = offsetX
        self.offsetY = offsetY
    }

    func normalized() -> ImageEditorPatternFillContent {
        ImageEditorPatternFillContent(
            kind: kind,
            repeatMode: repeatMode,
            red: Self.zeroOne(red),
            green: Self.zeroOne(green),
            blue: Self.zeroOne(blue),
            opacity: max(0.05, min(1, opacity)),
            scale: max(6, min(64, scale)),
            scaleX: Self.normalizedAxisScale(scaleX),
            scaleY: Self.normalizedAxisScale(scaleY),
            linksAxisScales: linksAxisScales,
            angle: Self.normalizedAngle(angle),
            flipsHorizontally: flipsHorizontally,
            flipsVertically: flipsVertically,
            offsetX: Self.normalizedOffset(offsetX),
            offsetY: Self.normalizedOffset(offsetY)
        )
    }

    var color: NSColor {
        let content = normalized()
        return NSColor(calibratedRed: content.red, green: content.green, blue: content.blue, alpha: 1)
    }

    func renderedImage(size: CGSize, invertsCoverage: Bool = false) -> NSImage {
        let content = normalized()
        let tileImage = content.kind.tileImage(
            color: content.color,
            opacity: CGFloat(content.opacity),
            scale: content.scale,
            invertsCoverage: invertsCoverage
        )
        guard size.width > 0,
              size.height > 0,
              let tileCGImage = tileImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            return NSImage.transparent(size: size)
        }

        let radians = content.angle * .pi / 180
        let affineTransform = NSAffineTransform()
        affineTransform.translateX(by: content.offsetX, yBy: content.offsetY)
        affineTransform.rotate(byRadians: radians)
        affineTransform.scaleX(
            by: content.scaleX * (content.flipsHorizontally ? -1 : 1),
            yBy: content.scaleY * (content.flipsVertically ? -1 : 1)
        )
        let repeatedTile = content.repeatedTileImage(from: CIImage(cgImage: tileCGImage))
        let tiled = repeatedTile.applyingFilter(
            "CIAffineTile",
            parameters: [kCIInputTransformKey: affineTransform]
        )
        let bounds = CGRect(origin: .zero, size: size)
        guard let rendered = ImageEditorImageProcessing.ciContext.createCGImage(
            tiled.cropped(to: bounds),
            from: bounds
        ) else {
            return NSImage.transparent(size: size)
        }
        return NSImage(cgImage: rendered, size: size)
    }

    private func repeatedTileImage(from tile: CIImage) -> CIImage {
        switch repeatMode {
        case .tile:
            return tile
        case .mirror:
            return mirroredTileImage(from: tile)
        case .brick:
            return brickTileImage(from: tile)
        case .halfDrop:
            return halfDropTileImage(from: tile)
        case .quarterDrop:
            return quarterDropTileImage(from: tile)
        }
    }

    private func mirroredTileImage(from tile: CIImage) -> CIImage {
        let width = tile.extent.width
        let height = tile.extent.height
        let horizontal = tile.transformed(by: CGAffineTransform(
            a: -1,
            b: 0,
            c: 0,
            d: 1,
            tx: width * 2,
            ty: 0
        ))
        let vertical = tile.transformed(by: CGAffineTransform(
            a: 1,
            b: 0,
            c: 0,
            d: -1,
            tx: 0,
            ty: height * 2
        ))
        let diagonal = tile.transformed(by: CGAffineTransform(
            a: -1,
            b: 0,
            c: 0,
            d: -1,
            tx: width * 2,
            ty: height * 2
        ))
        return diagonal
            .composited(over: vertical)
            .composited(over: horizontal)
            .composited(over: tile)
            .cropped(to: CGRect(x: 0, y: 0, width: width * 2, height: height * 2))
    }

    private func brickTileImage(from tile: CIImage) -> CIImage {
        let width = tile.extent.width
        let height = tile.extent.height
        let secondRowLeading = tile.transformed(by: CGAffineTransform(
            translationX: -width / 2,
            y: height
        ))
        let secondRowTrailing = tile.transformed(by: CGAffineTransform(
            translationX: width / 2,
            y: height
        ))
        return secondRowTrailing
            .composited(over: secondRowLeading)
            .composited(over: tile)
            .cropped(to: CGRect(x: 0, y: 0, width: width, height: height * 2))
    }

    private func halfDropTileImage(from tile: CIImage) -> CIImage {
        let width = tile.extent.width
        let height = tile.extent.height
        let secondColumnLower = tile.transformed(by: CGAffineTransform(
            translationX: width,
            y: -height / 2
        ))
        let secondColumnUpper = tile.transformed(by: CGAffineTransform(
            translationX: width,
            y: height / 2
        ))
        return secondColumnUpper
            .composited(over: secondColumnLower)
            .composited(over: tile)
            .cropped(to: CGRect(x: 0, y: 0, width: width * 2, height: height))
    }

    private func quarterDropTileImage(from tile: CIImage) -> CIImage {
        let width = tile.extent.width
        let height = tile.extent.height
        let columns = (1...3).flatMap { column -> [CIImage] in
            let offset = -height * CGFloat(column) / 4
            let x = width * CGFloat(column)
            return [offset, offset + height].map { y in
                tile.transformed(by: CGAffineTransform(translationX: x, y: y))
            }
        }
        return columns
            .reduce(tile) { result, column in column.composited(over: result) }
            .cropped(to: CGRect(x: 0, y: 0, width: width * 4, height: height))
    }

    private static func zeroOne(_ value: Double) -> Double {
        max(0, min(1, value))
    }

    private static func normalizedOffset(_ value: CGFloat) -> CGFloat {
        guard value.isFinite else { return 0 }
        return max(-128, min(128, value))
    }

    private static func normalizedAxisScale(_ value: CGFloat) -> CGFloat {
        guard value.isFinite else { return 1 }
        return max(0.25, min(4, value))
    }

    private static func normalizedAngle(_ value: CGFloat) -> CGFloat {
        guard value.isFinite else { return 0 }
        return max(-180, min(180, value))
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case repeatMode
        case red
        case green
        case blue
        case opacity
        case scale
        case scaleX
        case scaleY
        case linksAxisScales
        case angle
        case flipsHorizontally
        case flipsVertically
        case offsetX
        case offsetY
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decode(ImageEditorPatternOverlayKind.self, forKey: .kind)
        repeatMode = try container.decodeIfPresent(
            ImageEditorPatternRepeatMode.self,
            forKey: .repeatMode
        ) ?? .tile
        red = try container.decode(Double.self, forKey: .red)
        green = try container.decode(Double.self, forKey: .green)
        blue = try container.decode(Double.self, forKey: .blue)
        opacity = try container.decode(Double.self, forKey: .opacity)
        scale = try container.decode(CGFloat.self, forKey: .scale)
        scaleX = try container.decodeIfPresent(CGFloat.self, forKey: .scaleX) ?? 1
        scaleY = try container.decodeIfPresent(CGFloat.self, forKey: .scaleY) ?? 1
        linksAxisScales = try container.decodeIfPresent(Bool.self, forKey: .linksAxisScales) ?? false
        angle = try container.decodeIfPresent(CGFloat.self, forKey: .angle) ?? 0
        flipsHorizontally = try container.decodeIfPresent(Bool.self, forKey: .flipsHorizontally) ?? false
        flipsVertically = try container.decodeIfPresent(Bool.self, forKey: .flipsVertically) ?? false
        offsetX = try container.decodeIfPresent(CGFloat.self, forKey: .offsetX) ?? 0
        offsetY = try container.decodeIfPresent(CGFloat.self, forKey: .offsetY) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        let content = normalized()
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(content.kind, forKey: .kind)
        try container.encode(content.repeatMode, forKey: .repeatMode)
        try container.encode(content.red, forKey: .red)
        try container.encode(content.green, forKey: .green)
        try container.encode(content.blue, forKey: .blue)
        try container.encode(content.opacity, forKey: .opacity)
        try container.encode(content.scale, forKey: .scale)
        try container.encode(content.scaleX, forKey: .scaleX)
        try container.encode(content.scaleY, forKey: .scaleY)
        try container.encode(content.linksAxisScales, forKey: .linksAxisScales)
        try container.encode(content.angle, forKey: .angle)
        try container.encode(content.flipsHorizontally, forKey: .flipsHorizontally)
        try container.encode(content.flipsVertically, forKey: .flipsVertically)
        try container.encode(content.offsetX, forKey: .offsetX)
        try container.encode(content.offsetY, forKey: .offsetY)
    }
}

enum ImageEditorPatternRepeatMode: String, CaseIterable, Identifiable, Codable {
    case tile
    case mirror
    case brick
    case halfDrop
    case quarterDrop

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.patternRepeat.\(rawValue)")
    }
}

enum ImageEditorGradientFillPreset: String, CaseIterable, Identifiable {
    case blackWhite
    case sunset
    case blueOrange
    case purpleTeal
    case foregroundBackground
    case custom

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.gradientFill.preset.\(rawValue)")
    }
}

enum ImageEditorGradientFillStyle: String, CaseIterable, Identifiable {
    case linear
    case radial
    case angle
    case reflected
    case diamond

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.gradientFill.style.\(rawValue)")
    }
}

struct ImageEditorGradientColorStop: Equatable, Codable, Sendable {
    static let defaultMidpoint = 0.5
    static let defaultAlpha = 1.0

    var position: Double
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double
    var midpoint: Double

    enum CodingKeys: String, CodingKey {
        case position
        case red
        case green
        case blue
        case alpha
        case midpoint
    }

    init(
        position: Double,
        red: Double,
        green: Double,
        blue: Double,
        alpha: Double = Self.defaultAlpha,
        midpoint: Double = Self.defaultMidpoint
    ) {
        self.position = position
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
        self.midpoint = midpoint
    }

    init(
        position: Double,
        color: NSColor,
        midpoint: Double = Self.defaultMidpoint
    ) {
        let resolved = color.usingColorSpace(.deviceRGB) ?? .black
        self.init(
            position: position,
            red: Double(resolved.redComponent),
            green: Double(resolved.greenComponent),
            blue: Double(resolved.blueComponent),
            alpha: Double(resolved.alphaComponent),
            midpoint: midpoint
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        position = try container.decode(Double.self, forKey: .position)
        red = try container.decode(Double.self, forKey: .red)
        green = try container.decode(Double.self, forKey: .green)
        blue = try container.decode(Double.self, forKey: .blue)
        alpha = try container.decodeIfPresent(Double.self, forKey: .alpha)
            ?? Self.defaultAlpha
        midpoint = try container.decodeIfPresent(Double.self, forKey: .midpoint)
            ?? Self.defaultMidpoint
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(position, forKey: .position)
        try container.encode(red, forKey: .red)
        try container.encode(green, forKey: .green)
        try container.encode(blue, forKey: .blue)
        try container.encode(alpha, forKey: .alpha)
        try container.encode(midpoint, forKey: .midpoint)
    }

    var color: NSColor {
        NSColor(deviceRed: red, green: green, blue: blue, alpha: alpha)
    }

    func normalized() -> ImageEditorGradientColorStop {
        ImageEditorGradientColorStop(
            position: max(0, min(1, position.isFinite ? position : 0)),
            red: max(0, min(1, red.isFinite ? red : 0)),
            green: max(0, min(1, green.isFinite ? green : 0)),
            blue: max(0, min(1, blue.isFinite ? blue : 0)),
            alpha: max(0, min(1, alpha.isFinite ? alpha : Self.defaultAlpha)),
            midpoint: max(
                0,
                min(1, midpoint.isFinite ? midpoint : Self.defaultMidpoint)
            )
        )
    }

    var vector: SIMD3<Double> {
        let value = normalized()
        return SIMD3<Double>(value.red, value.green, value.blue)
    }

    var rgbaVector: SIMD4<Double> {
        let value = normalized()
        return SIMD4<Double>(value.red, value.green, value.blue, value.alpha)
    }

    func interpolationAmount(to upper: ImageEditorGradientColorStop, at position: Double) -> Double {
        let lower = normalized()
        let upper = upper.normalized()
        let distance = upper.position - lower.position
        guard distance > 0.000_001 else { return 1 }
        let linearAmount = max(0, min(1, (position - lower.position) / distance))
        if linearAmount <= lower.midpoint {
            guard lower.midpoint > 0.000_001 else { return linearAmount == 0 ? 0 : 0.5 }
            return 0.5 * linearAmount / lower.midpoint
        }
        guard lower.midpoint < 0.999_999 else { return linearAmount == 1 ? 1 : 0.5 }
        return 0.5 + 0.5 * (linearAmount - lower.midpoint) / (1 - lower.midpoint)
    }
}

struct ImageEditorGradientFillContent: Equatable, Codable {
    static let maximumColorStopCount = 16
    private static let bayer4x4 = [
        0, 8, 2, 10,
        12, 4, 14, 6,
        3, 11, 1, 9,
        15, 7, 13, 5
    ]

    var preset: ImageEditorGradientFillPreset = .blueOrange
    var style: ImageEditorGradientFillStyle = .linear
    var reverse: Bool = false
    var dither: Bool = false
    var angle: CGFloat = 0
    var scale: CGFloat = 1
    var startRed: Double = 0.12
    var startGreen: Double = 0.20
    var startBlue: Double = 0.95
    var endRed: Double = 1.0
    var endGreen: Double = 0.50
    var endBlue: Double = 0.10
    var colorStops: [ImageEditorGradientColorStop]? = nil

    enum CodingKeys: String, CodingKey {
        case preset
        case style
        case reverse
        case dither
        case angle
        case scale
        case startRed
        case startGreen
        case startBlue
        case endRed
        case endGreen
        case endBlue
        case colorStops
    }

    init(
        preset: ImageEditorGradientFillPreset = .blueOrange,
        style: ImageEditorGradientFillStyle = .linear,
        reverse: Bool = false,
        dither: Bool = false,
        angle: CGFloat = 0,
        scale: CGFloat = 1,
        startRed: Double = 0.12,
        startGreen: Double = 0.20,
        startBlue: Double = 0.95,
        endRed: Double = 1.0,
        endGreen: Double = 0.50,
        endBlue: Double = 0.10,
        colorStops: [ImageEditorGradientColorStop]? = nil
    ) {
        self.preset = preset
        self.style = style
        self.reverse = reverse
        self.dither = dither
        self.angle = angle
        self.scale = scale
        self.startRed = startRed
        self.startGreen = startGreen
        self.startBlue = startBlue
        self.endRed = endRed
        self.endGreen = endGreen
        self.endBlue = endBlue
        self.colorStops = colorStops
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        preset = try container.decodeIfPresent(ImageEditorGradientFillPreset.self, forKey: .preset) ?? .blueOrange
        style = try container.decodeIfPresent(ImageEditorGradientFillStyle.self, forKey: .style) ?? .linear
        reverse = try container.decodeIfPresent(Bool.self, forKey: .reverse) ?? false
        dither = try container.decodeIfPresent(Bool.self, forKey: .dither) ?? false
        angle = try container.decodeIfPresent(CGFloat.self, forKey: .angle) ?? 0
        scale = try container.decodeIfPresent(CGFloat.self, forKey: .scale) ?? 1
        startRed = try container.decodeIfPresent(Double.self, forKey: .startRed) ?? 0.12
        startGreen = try container.decodeIfPresent(Double.self, forKey: .startGreen) ?? 0.20
        startBlue = try container.decodeIfPresent(Double.self, forKey: .startBlue) ?? 0.95
        endRed = try container.decodeIfPresent(Double.self, forKey: .endRed) ?? 1.0
        endGreen = try container.decodeIfPresent(Double.self, forKey: .endGreen) ?? 0.50
        endBlue = try container.decodeIfPresent(Double.self, forKey: .endBlue) ?? 0.10
        colorStops = try container.decodeIfPresent(
            [ImageEditorGradientColorStop].self,
            forKey: .colorStops
        )
    }

    func normalized() -> ImageEditorGradientFillContent {
        let stops = Self.normalizedColorStops(colorStops)
        let first = stops?.first
        let last = stops?.last
        return ImageEditorGradientFillContent(
            preset: preset,
            style: style,
            reverse: reverse,
            dither: dither,
            angle: max(-180, min(180, angle)),
            scale: max(0.25, min(4, scale)),
            startRed: first?.red ?? Self.zeroOne(startRed),
            startGreen: first?.green ?? Self.zeroOne(startGreen),
            startBlue: first?.blue ?? Self.zeroOne(startBlue),
            endRed: last?.red ?? Self.zeroOne(endRed),
            endGreen: last?.green ?? Self.zeroOne(endGreen),
            endBlue: last?.blue ?? Self.zeroOne(endBlue),
            colorStops: stops
        )
    }

    func colors(foreground: NSColor = .systemRed, background: NSColor = .clear) -> (start: SIMD3<Double>, end: SIMD3<Double>) {
        let content = normalized()
        if let stops = content.colorStops, let first = stops.first, let last = stops.last {
            return (first.vector, last.vector)
        }
        switch content.preset {
        case .blackWhite:
            return (SIMD3<Double>(0, 0, 0), SIMD3<Double>(1, 1, 1))
        case .sunset:
            return (SIMD3<Double>(0.15, 0.04, 0.35), SIMD3<Double>(1.0, 0.55, 0.10))
        case .blueOrange:
            return (SIMD3<Double>(0.10, 0.24, 0.95), SIMD3<Double>(1.0, 0.50, 0.12))
        case .purpleTeal:
            return (SIMD3<Double>(0.45, 0.16, 0.80), SIMD3<Double>(0.05, 0.78, 0.72))
        case .foregroundBackground:
            return (Self.rgbVector(foreground), Self.rgbVector(background))
        case .custom:
            return (
                SIMD3<Double>(content.startRed, content.startGreen, content.startBlue),
                SIMD3<Double>(content.endRed, content.endGreen, content.endBlue)
            )
        }
    }

    func renderedImage(
        size: CGSize,
        foreground: NSColor = .systemRed,
        background: NSColor = .clear,
        centerNormalized: CGPoint = CGPoint(x: 0.5, y: 0.5),
        opacity: Double = 1
    ) -> NSImage {
        let content = normalized()
        let width = max(1, Int(size.width.rounded()))
        let height = max(1, Int(size.height.rounded()))
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        let resolvedColors = content.colors(foreground: foreground, background: background)
        var stops = content.colorStops ?? [
            ImageEditorGradientColorStop(
                position: 0,
                red: resolvedColors.start.x,
                green: resolvedColors.start.y,
                blue: resolvedColors.start.z
            ),
            ImageEditorGradientColorStop(
                position: 1,
                red: resolvedColors.end.x,
                green: resolvedColors.end.y,
                blue: resolvedColors.end.z
            )
        ]
        if content.reverse {
            let forwardStops = stops
            stops = forwardStops.indices.reversed().map { index in
                let stop = forwardStops[index]
                return ImageEditorGradientColorStop(
                    position: 1 - stop.position,
                    red: stop.red,
                    green: stop.green,
                    blue: stop.blue,
                    alpha: stop.alpha,
                    midpoint: index > forwardStops.startIndex
                        ? 1 - forwardStops[index - 1].midpoint
                        : 0.5
                )
            }
        }
        let radians = Double(content.angle) * Double.pi / 180
        let direction = SIMD2<Double>(cos(radians), sin(radians))
        let span = max(1, abs(direction.x) * Double(width) + abs(direction.y) * Double(height)) * Double(content.scale)
        let center = SIMD2<Double>(
            Double(width) * Double(centerNormalized.x) - 0.5,
            Double(height) * Double(centerNormalized.y) - 0.5
        )
        let cornerDistance = max(
            1,
            hypot(Double(width - 1) / 2, Double(height - 1) / 2) * Double(content.scale)
        )

        for y in 0..<height {
            for x in 0..<width {
                let point = SIMD2<Double>(Double(x), Double(y))
                let rawProgress = content.progress(
                    at: point,
                    center: center,
                    direction: direction,
                    span: span,
                    cornerDistance: cornerDistance
                )
                let t = content.dither
                    ? Self.ditheredProgress(rawProgress, x: x, y: y)
                    : rawProgress
                let color = Self.interpolatedColor(at: t, stops: stops)
                let alpha = Self.zeroOne(color.w * opacity)
                let offset = y * bytesPerRow + x * bytesPerPixel
                pixels[offset] = Self.byte(color.x * alpha)
                pixels[offset + 1] = Self.byte(color.y * alpha)
                pixels[offset + 2] = Self.byte(color.z * alpha)
                pixels[offset + 3] = Self.byte(alpha)
            }
        }

        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let image = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              )
        else { return NSImage.transparent(size: size) }

        return NSImage(cgImage: image, size: size)
    }

    static func ditheredProgress(_ progress: Double, x: Int, y: Int) -> Double {
        let threshold = (Double(bayer4x4[(y & 3) * 4 + (x & 3)]) + 0.5) / 16
        return max(0, min(1, progress + (threshold - 0.5) / 96))
    }

    private func progress(
        at point: SIMD2<Double>,
        center: SIMD2<Double>,
        direction: SIMD2<Double>,
        span: Double,
        cornerDistance: Double
    ) -> Double {
        let delta = point - center
        switch style {
        case .linear:
            let projection = simd_dot(delta, direction)
            return Self.zeroOne(0.5 + projection / span)
        case .radial:
            return Self.zeroOne(hypot(delta.x, delta.y) / cornerDistance)
        case .angle:
            guard abs(delta.x) > 0.000_001 || abs(delta.y) > 0.000_001 else { return 0 }
            let startAngle = atan2(direction.y, direction.x)
            let turns = (atan2(delta.y, delta.x) - startAngle) / (2 * Double.pi)
            return turns - floor(turns)
        case .reflected:
            let projection = abs(simd_dot(delta, direction))
            return Self.zeroOne((projection * 2) / span)
        case .diamond:
            let xAxis = direction
            let yAxis = SIMD2<Double>(-direction.y, direction.x)
            let projectedX = abs(simd_dot(delta, xAxis))
            let projectedY = abs(simd_dot(delta, yAxis))
            return Self.zeroOne((projectedX + projectedY) / cornerDistance)
        }
    }

    private static func rgbVector(_ color: NSColor) -> SIMD3<Double> {
        let rgb = color.usingColorSpace(.deviceRGB) ?? .black
        return SIMD3<Double>(
            zeroOne(Double(rgb.redComponent)),
            zeroOne(Double(rgb.greenComponent)),
            zeroOne(Double(rgb.blueComponent))
        )
    }

    private static func normalizedColorStops(
        _ stops: [ImageEditorGradientColorStop]?
    ) -> [ImageEditorGradientColorStop]? {
        guard let stops, stops.count >= 2 else { return nil }
        return Array(stops.prefix(maximumColorStopCount))
            .map { $0.normalized() }
            .enumerated()
            .sorted { lhs, rhs in
                if lhs.element.position == rhs.element.position {
                    return lhs.offset < rhs.offset
                }
                return lhs.element.position < rhs.element.position
            }
            .map(\.element)
    }

    private static func interpolatedColor(
        at progress: Double,
        stops: [ImageEditorGradientColorStop]
    ) -> SIMD4<Double> {
        guard let first = stops.first, let last = stops.last else { return .zero }
        if progress <= first.position { return first.rgbaVector }
        if progress >= last.position { return last.rgbaVector }
        for index in 1..<stops.count {
            let upper = stops[index]
            guard progress <= upper.position else { continue }
            let lower = stops[index - 1]
            let amount = lower.interpolationAmount(to: upper, at: progress)
            return lower.rgbaVector + (upper.rgbaVector - lower.rgbaVector) * amount
        }
        return last.rgbaVector
    }

    private static func zeroOne(_ value: Double) -> Double {
        max(0, min(1, value))
    }

    private static func byte(_ value: Double) -> UInt8 {
        UInt8(max(0, min(255, (zeroOne(value) * 255).rounded())))
    }
}

enum ImageEditorSelectiveColorRange: String, CaseIterable, Identifiable {
    case reds
    case yellows
    case greens
    case cyans
    case blues
    case magentas
    case whites
    case neutrals
    case blacks

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.selectiveColor.range.\(rawValue)")
    }
}

enum ImageEditorSelectiveColorComponent: String, CaseIterable, Identifiable {
    case cyan
    case magenta
    case yellow
    case black

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.selectiveColor.component.\(rawValue)")
    }
}

enum ImageEditorSelectiveColorMethod: String, CaseIterable, Identifiable {
    case relative
    case absolute

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.selectiveColor.method.\(rawValue)")
    }
}

struct ImageEditorSelectiveColorValues: Equatable, Codable {
    var cyan: Double = 0
    var magenta: Double = 0
    var yellow: Double = 0
    var black: Double = 0

    func normalized() -> ImageEditorSelectiveColorValues {
        ImageEditorSelectiveColorValues(
            cyan: Self.unit(cyan),
            magenta: Self.unit(magenta),
            yellow: Self.unit(yellow),
            black: Self.unit(black)
        )
    }

    private static func unit(_ value: Double) -> Double {
        max(-1, min(1, value))
    }
}

struct ImageEditorSelectiveColorSettings: Equatable, Codable {
    var reds = ImageEditorSelectiveColorValues()
    var yellows = ImageEditorSelectiveColorValues()
    var greens = ImageEditorSelectiveColorValues()
    var cyans = ImageEditorSelectiveColorValues()
    var blues = ImageEditorSelectiveColorValues()
    var magentas = ImageEditorSelectiveColorValues()
    var whites = ImageEditorSelectiveColorValues()
    var neutrals = ImageEditorSelectiveColorValues()
    var blacks = ImageEditorSelectiveColorValues()

    func values(for range: ImageEditorSelectiveColorRange) -> ImageEditorSelectiveColorValues {
        switch range {
        case .reds:
            return reds
        case .yellows:
            return yellows
        case .greens:
            return greens
        case .cyans:
            return cyans
        case .blues:
            return blues
        case .magentas:
            return magentas
        case .whites:
            return whites
        case .neutrals:
            return neutrals
        case .blacks:
            return blacks
        }
    }

    mutating func setValues(_ values: ImageEditorSelectiveColorValues, for range: ImageEditorSelectiveColorRange) {
        switch range {
        case .reds:
            reds = values
        case .yellows:
            yellows = values
        case .greens:
            greens = values
        case .cyans:
            cyans = values
        case .blues:
            blues = values
        case .magentas:
            magentas = values
        case .whites:
            whites = values
        case .neutrals:
            neutrals = values
        case .blacks:
            blacks = values
        }
    }

    func normalized() -> ImageEditorSelectiveColorSettings {
        ImageEditorSelectiveColorSettings(
            reds: reds.normalized(),
            yellows: yellows.normalized(),
            greens: greens.normalized(),
            cyans: cyans.normalized(),
            blues: blues.normalized(),
            magentas: magentas.normalized(),
            whites: whites.normalized(),
            neutrals: neutrals.normalized(),
            blacks: blacks.normalized()
        )
    }
}

struct ImageEditorAdjustmentSettings: Equatable, Codable {
    var levelsBlackPoint: Double = 0
    var levelsGamma: Double = 1
    var levelsWhitePoint: Double = 1
    var curvesShadows: Double = 0
    var curvesMidtones: Double = 0
    var curvesHighlights: Double = 0
    var colorBalanceShadowsCyanRed: Double = 0
    var colorBalanceShadowsMagentaGreen: Double = 0
    var colorBalanceShadowsYellowBlue: Double = 0
    var colorBalanceMidtonesCyanRed: Double = 0
    var colorBalanceMidtonesMagentaGreen: Double = 0
    var colorBalanceMidtonesYellowBlue: Double = 0
    var colorBalanceHighlightsCyanRed: Double = 0
    var colorBalanceHighlightsMagentaGreen: Double = 0
    var colorBalanceHighlightsYellowBlue: Double = 0
    var hueSaturationHue: Double = 0
    var hueSaturationSaturation: Double = 0
    var hueSaturationLightness: Double = 0
    var hueSaturationColorize: Bool = false
    var brightnessContrastBrightness: Double = 0
    var brightnessContrastContrast: Double = 0
    var exposureEV: Double = 0
    var exposureOffset: Double = 0
    var exposureGamma: Double = 1
    var shadowsHighlightsShadows: Double = 0
    var shadowsHighlightsHighlights: Double = 0
    var vibranceAmount: Double = 0
    var vibranceSaturation: Double = 0
    var blackWhiteReds: Double = 0.40
    var blackWhiteYellows: Double = 0.60
    var blackWhiteGreens: Double = 0.40
    var blackWhiteCyans: Double = 0.60
    var blackWhiteBlues: Double = 0.20
    var blackWhiteMagentas: Double = 0.80
    var channelMixerRedRed: Double = 1
    var channelMixerRedGreen: Double = 0
    var channelMixerRedBlue: Double = 0
    var channelMixerRedConstant: Double = 0
    var channelMixerGreenRed: Double = 0
    var channelMixerGreenGreen: Double = 1
    var channelMixerGreenBlue: Double = 0
    var channelMixerGreenConstant: Double = 0
    var channelMixerBlueRed: Double = 0
    var channelMixerBlueGreen: Double = 0
    var channelMixerBlueBlue: Double = 1
    var channelMixerBlueConstant: Double = 0
    var channelMixerMonochrome: Bool = false
    var channelMixerMonoRed: Double = 0.40
    var channelMixerMonoGreen: Double = 0.40
    var channelMixerMonoBlue: Double = 0.20
    var channelMixerMonoConstant: Double = 0
    var photoFilterPreset: ImageEditorPhotoFilterPreset = .warming85
    var photoFilterDensity: Double = 0.25
    var photoFilterPreserveLuminosity: Bool = true
    var photoFilterCustomRed: Double = 1
    var photoFilterCustomGreen: Double = 0.65
    var photoFilterCustomBlue: Double = 0.30
    var colorLookupPreset: ImageEditorColorLookupPreset = .filmStock
    var colorLookupCube: ImageEditorColorLookupCube = ImageEditorColorLookupCube()
    var selectiveColorSettings = ImageEditorSelectiveColorSettings()
    var selectiveColorMethod: ImageEditorSelectiveColorMethod = .relative
    var gradientMapPreset: ImageEditorGradientMapPreset = .blackWhite
    var gradientMapReverse: Bool = false
    var gradientMapDither: Bool = false
    var gradientMapShadowRed: Double = 0
    var gradientMapShadowGreen: Double = 0
    var gradientMapShadowBlue: Double = 0
    var gradientMapHighlightRed: Double = 1
    var gradientMapHighlightGreen: Double = 1
    var gradientMapHighlightBlue: Double = 1

    func normalized() -> ImageEditorAdjustmentSettings {
        let black = max(0, min(0.98, levelsBlackPoint))
        let white = max(black + 0.01, min(1, levelsWhitePoint))
        let gamma = max(0.1, min(4, levelsGamma))
        return ImageEditorAdjustmentSettings(
            levelsBlackPoint: black,
            levelsGamma: gamma,
            levelsWhitePoint: white,
            curvesShadows: max(-1, min(1, curvesShadows)),
            curvesMidtones: max(-1, min(1, curvesMidtones)),
            curvesHighlights: max(-1, min(1, curvesHighlights)),
            colorBalanceShadowsCyanRed: Self.unit(colorBalanceShadowsCyanRed),
            colorBalanceShadowsMagentaGreen: Self.unit(colorBalanceShadowsMagentaGreen),
            colorBalanceShadowsYellowBlue: Self.unit(colorBalanceShadowsYellowBlue),
            colorBalanceMidtonesCyanRed: Self.unit(colorBalanceMidtonesCyanRed),
            colorBalanceMidtonesMagentaGreen: Self.unit(colorBalanceMidtonesMagentaGreen),
            colorBalanceMidtonesYellowBlue: Self.unit(colorBalanceMidtonesYellowBlue),
            colorBalanceHighlightsCyanRed: Self.unit(colorBalanceHighlightsCyanRed),
            colorBalanceHighlightsMagentaGreen: Self.unit(colorBalanceHighlightsMagentaGreen),
            colorBalanceHighlightsYellowBlue: Self.unit(colorBalanceHighlightsYellowBlue),
            hueSaturationHue: max(-180, min(180, hueSaturationHue)),
            hueSaturationSaturation: Self.unit(hueSaturationSaturation),
            hueSaturationLightness: Self.unit(hueSaturationLightness),
            hueSaturationColorize: hueSaturationColorize,
            brightnessContrastBrightness: Self.unit(brightnessContrastBrightness),
            brightnessContrastContrast: Self.unit(brightnessContrastContrast),
            exposureEV: max(-5, min(5, exposureEV)),
            exposureOffset: max(-0.5, min(0.5, exposureOffset)),
            exposureGamma: max(0.1, min(9.99, exposureGamma)),
            shadowsHighlightsShadows: Self.zeroOne(shadowsHighlightsShadows),
            shadowsHighlightsHighlights: Self.zeroOne(shadowsHighlightsHighlights),
            vibranceAmount: Self.unit(vibranceAmount),
            vibranceSaturation: Self.unit(vibranceSaturation),
            blackWhiteReds: Self.channelMix(blackWhiteReds),
            blackWhiteYellows: Self.channelMix(blackWhiteYellows),
            blackWhiteGreens: Self.channelMix(blackWhiteGreens),
            blackWhiteCyans: Self.channelMix(blackWhiteCyans),
            blackWhiteBlues: Self.channelMix(blackWhiteBlues),
            blackWhiteMagentas: Self.channelMix(blackWhiteMagentas),
            channelMixerRedRed: Self.mixerCoefficient(channelMixerRedRed),
            channelMixerRedGreen: Self.mixerCoefficient(channelMixerRedGreen),
            channelMixerRedBlue: Self.mixerCoefficient(channelMixerRedBlue),
            channelMixerRedConstant: Self.unit(channelMixerRedConstant),
            channelMixerGreenRed: Self.mixerCoefficient(channelMixerGreenRed),
            channelMixerGreenGreen: Self.mixerCoefficient(channelMixerGreenGreen),
            channelMixerGreenBlue: Self.mixerCoefficient(channelMixerGreenBlue),
            channelMixerGreenConstant: Self.unit(channelMixerGreenConstant),
            channelMixerBlueRed: Self.mixerCoefficient(channelMixerBlueRed),
            channelMixerBlueGreen: Self.mixerCoefficient(channelMixerBlueGreen),
            channelMixerBlueBlue: Self.mixerCoefficient(channelMixerBlueBlue),
            channelMixerBlueConstant: Self.unit(channelMixerBlueConstant),
            channelMixerMonochrome: channelMixerMonochrome,
            channelMixerMonoRed: Self.mixerCoefficient(channelMixerMonoRed),
            channelMixerMonoGreen: Self.mixerCoefficient(channelMixerMonoGreen),
            channelMixerMonoBlue: Self.mixerCoefficient(channelMixerMonoBlue),
            channelMixerMonoConstant: Self.unit(channelMixerMonoConstant),
            photoFilterPreset: photoFilterPreset,
            photoFilterDensity: max(0, min(1, photoFilterDensity)),
            photoFilterPreserveLuminosity: photoFilterPreserveLuminosity,
            photoFilterCustomRed: max(0, min(1, photoFilterCustomRed)),
            photoFilterCustomGreen: max(0, min(1, photoFilterCustomGreen)),
            photoFilterCustomBlue: max(0, min(1, photoFilterCustomBlue)),
            colorLookupPreset: colorLookupPreset,
            colorLookupCube: colorLookupCube.normalized(),
            selectiveColorSettings: selectiveColorSettings.normalized(),
            selectiveColorMethod: selectiveColorMethod,
            gradientMapPreset: gradientMapPreset,
            gradientMapReverse: gradientMapReverse,
            gradientMapDither: gradientMapDither,
            gradientMapShadowRed: Self.zeroOne(gradientMapShadowRed),
            gradientMapShadowGreen: Self.zeroOne(gradientMapShadowGreen),
            gradientMapShadowBlue: Self.zeroOne(gradientMapShadowBlue),
            gradientMapHighlightRed: Self.zeroOne(gradientMapHighlightRed),
            gradientMapHighlightGreen: Self.zeroOne(gradientMapHighlightGreen),
            gradientMapHighlightBlue: Self.zeroOne(gradientMapHighlightBlue)
        )
    }

    private static func unit(_ value: Double) -> Double {
        max(-1, min(1, value))
    }

    private static func channelMix(_ value: Double) -> Double {
        max(0, min(2, value))
    }

    private static func mixerCoefficient(_ value: Double) -> Double {
        max(-2, min(2, value))
    }

    private static func zeroOne(_ value: Double) -> Double {
        max(0, min(1, value))
    }
}

extension ImageEditorAdjustmentSettings {
    private enum CodingKeys: String, CodingKey {
        case levelsBlackPoint
        case levelsGamma
        case levelsWhitePoint
        case curvesShadows
        case curvesMidtones
        case curvesHighlights
        case colorBalanceShadowsCyanRed
        case colorBalanceShadowsMagentaGreen
        case colorBalanceShadowsYellowBlue
        case colorBalanceMidtonesCyanRed
        case colorBalanceMidtonesMagentaGreen
        case colorBalanceMidtonesYellowBlue
        case colorBalanceHighlightsCyanRed
        case colorBalanceHighlightsMagentaGreen
        case colorBalanceHighlightsYellowBlue
        case hueSaturationHue
        case hueSaturationSaturation
        case hueSaturationLightness
        case hueSaturationColorize
        case brightnessContrastBrightness
        case brightnessContrastContrast
        case exposureEV
        case exposureOffset
        case exposureGamma
        case shadowsHighlightsShadows
        case shadowsHighlightsHighlights
        case vibranceAmount
        case vibranceSaturation
        case blackWhiteReds
        case blackWhiteYellows
        case blackWhiteGreens
        case blackWhiteCyans
        case blackWhiteBlues
        case blackWhiteMagentas
        case channelMixerRedRed
        case channelMixerRedGreen
        case channelMixerRedBlue
        case channelMixerRedConstant
        case channelMixerGreenRed
        case channelMixerGreenGreen
        case channelMixerGreenBlue
        case channelMixerGreenConstant
        case channelMixerBlueRed
        case channelMixerBlueGreen
        case channelMixerBlueBlue
        case channelMixerBlueConstant
        case channelMixerMonochrome
        case channelMixerMonoRed
        case channelMixerMonoGreen
        case channelMixerMonoBlue
        case channelMixerMonoConstant
        case photoFilterPreset
        case photoFilterDensity
        case photoFilterPreserveLuminosity
        case photoFilterCustomRed
        case photoFilterCustomGreen
        case photoFilterCustomBlue
        case colorLookupPreset
        case colorLookupCube
        case selectiveColorSettings
        case selectiveColorMethod
        case gradientMapPreset
        case gradientMapReverse
        case gradientMapDither
        case gradientMapShadowRed
        case gradientMapShadowGreen
        case gradientMapShadowBlue
        case gradientMapHighlightRed
        case gradientMapHighlightGreen
        case gradientMapHighlightBlue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        levelsBlackPoint = try container.decodeIfPresent(Double.self, forKey: .levelsBlackPoint) ?? 0
        levelsGamma = try container.decodeIfPresent(Double.self, forKey: .levelsGamma) ?? 1
        levelsWhitePoint = try container.decodeIfPresent(Double.self, forKey: .levelsWhitePoint) ?? 1
        curvesShadows = try container.decodeIfPresent(Double.self, forKey: .curvesShadows) ?? 0
        curvesMidtones = try container.decodeIfPresent(Double.self, forKey: .curvesMidtones) ?? 0
        curvesHighlights = try container.decodeIfPresent(Double.self, forKey: .curvesHighlights) ?? 0
        colorBalanceShadowsCyanRed = try container.decodeIfPresent(Double.self, forKey: .colorBalanceShadowsCyanRed) ?? 0
        colorBalanceShadowsMagentaGreen = try container.decodeIfPresent(Double.self, forKey: .colorBalanceShadowsMagentaGreen) ?? 0
        colorBalanceShadowsYellowBlue = try container.decodeIfPresent(Double.self, forKey: .colorBalanceShadowsYellowBlue) ?? 0
        colorBalanceMidtonesCyanRed = try container.decodeIfPresent(Double.self, forKey: .colorBalanceMidtonesCyanRed) ?? 0
        colorBalanceMidtonesMagentaGreen = try container.decodeIfPresent(Double.self, forKey: .colorBalanceMidtonesMagentaGreen) ?? 0
        colorBalanceMidtonesYellowBlue = try container.decodeIfPresent(Double.self, forKey: .colorBalanceMidtonesYellowBlue) ?? 0
        colorBalanceHighlightsCyanRed = try container.decodeIfPresent(Double.self, forKey: .colorBalanceHighlightsCyanRed) ?? 0
        colorBalanceHighlightsMagentaGreen = try container.decodeIfPresent(Double.self, forKey: .colorBalanceHighlightsMagentaGreen) ?? 0
        colorBalanceHighlightsYellowBlue = try container.decodeIfPresent(Double.self, forKey: .colorBalanceHighlightsYellowBlue) ?? 0
        hueSaturationHue = try container.decodeIfPresent(Double.self, forKey: .hueSaturationHue) ?? 0
        hueSaturationSaturation = try container.decodeIfPresent(Double.self, forKey: .hueSaturationSaturation) ?? 0
        hueSaturationLightness = try container.decodeIfPresent(Double.self, forKey: .hueSaturationLightness) ?? 0
        hueSaturationColorize = try container.decodeIfPresent(Bool.self, forKey: .hueSaturationColorize) ?? false
        brightnessContrastBrightness = try container.decodeIfPresent(Double.self, forKey: .brightnessContrastBrightness) ?? 0
        brightnessContrastContrast = try container.decodeIfPresent(Double.self, forKey: .brightnessContrastContrast) ?? 0
        exposureEV = try container.decodeIfPresent(Double.self, forKey: .exposureEV) ?? 0
        exposureOffset = try container.decodeIfPresent(Double.self, forKey: .exposureOffset) ?? 0
        exposureGamma = try container.decodeIfPresent(Double.self, forKey: .exposureGamma) ?? 1
        shadowsHighlightsShadows = try container.decodeIfPresent(Double.self, forKey: .shadowsHighlightsShadows) ?? 0
        shadowsHighlightsHighlights = try container.decodeIfPresent(Double.self, forKey: .shadowsHighlightsHighlights) ?? 0
        vibranceAmount = try container.decodeIfPresent(Double.self, forKey: .vibranceAmount) ?? 0
        vibranceSaturation = try container.decodeIfPresent(Double.self, forKey: .vibranceSaturation) ?? 0
        blackWhiteReds = try container.decodeIfPresent(Double.self, forKey: .blackWhiteReds) ?? 0.40
        blackWhiteYellows = try container.decodeIfPresent(Double.self, forKey: .blackWhiteYellows) ?? 0.60
        blackWhiteGreens = try container.decodeIfPresent(Double.self, forKey: .blackWhiteGreens) ?? 0.40
        blackWhiteCyans = try container.decodeIfPresent(Double.self, forKey: .blackWhiteCyans) ?? 0.60
        blackWhiteBlues = try container.decodeIfPresent(Double.self, forKey: .blackWhiteBlues) ?? 0.20
        blackWhiteMagentas = try container.decodeIfPresent(Double.self, forKey: .blackWhiteMagentas) ?? 0.80
        channelMixerRedRed = try container.decodeIfPresent(Double.self, forKey: .channelMixerRedRed) ?? 1
        channelMixerRedGreen = try container.decodeIfPresent(Double.self, forKey: .channelMixerRedGreen) ?? 0
        channelMixerRedBlue = try container.decodeIfPresent(Double.self, forKey: .channelMixerRedBlue) ?? 0
        channelMixerRedConstant = try container.decodeIfPresent(Double.self, forKey: .channelMixerRedConstant) ?? 0
        channelMixerGreenRed = try container.decodeIfPresent(Double.self, forKey: .channelMixerGreenRed) ?? 0
        channelMixerGreenGreen = try container.decodeIfPresent(Double.self, forKey: .channelMixerGreenGreen) ?? 1
        channelMixerGreenBlue = try container.decodeIfPresent(Double.self, forKey: .channelMixerGreenBlue) ?? 0
        channelMixerGreenConstant = try container.decodeIfPresent(Double.self, forKey: .channelMixerGreenConstant) ?? 0
        channelMixerBlueRed = try container.decodeIfPresent(Double.self, forKey: .channelMixerBlueRed) ?? 0
        channelMixerBlueGreen = try container.decodeIfPresent(Double.self, forKey: .channelMixerBlueGreen) ?? 0
        channelMixerBlueBlue = try container.decodeIfPresent(Double.self, forKey: .channelMixerBlueBlue) ?? 1
        channelMixerBlueConstant = try container.decodeIfPresent(Double.self, forKey: .channelMixerBlueConstant) ?? 0
        channelMixerMonochrome = try container.decodeIfPresent(Bool.self, forKey: .channelMixerMonochrome) ?? false
        channelMixerMonoRed = try container.decodeIfPresent(Double.self, forKey: .channelMixerMonoRed) ?? 0.40
        channelMixerMonoGreen = try container.decodeIfPresent(Double.self, forKey: .channelMixerMonoGreen) ?? 0.40
        channelMixerMonoBlue = try container.decodeIfPresent(Double.self, forKey: .channelMixerMonoBlue) ?? 0.20
        channelMixerMonoConstant = try container.decodeIfPresent(Double.self, forKey: .channelMixerMonoConstant) ?? 0
        photoFilterPreset = try container.decodeIfPresent(ImageEditorPhotoFilterPreset.self, forKey: .photoFilterPreset) ?? .warming85
        photoFilterDensity = try container.decodeIfPresent(Double.self, forKey: .photoFilterDensity) ?? 0.25
        photoFilterPreserveLuminosity = try container.decodeIfPresent(Bool.self, forKey: .photoFilterPreserveLuminosity) ?? true
        photoFilterCustomRed = try container.decodeIfPresent(Double.self, forKey: .photoFilterCustomRed) ?? 1
        photoFilterCustomGreen = try container.decodeIfPresent(Double.self, forKey: .photoFilterCustomGreen) ?? 0.65
        photoFilterCustomBlue = try container.decodeIfPresent(Double.self, forKey: .photoFilterCustomBlue) ?? 0.30
        colorLookupPreset = try container.decodeIfPresent(ImageEditorColorLookupPreset.self, forKey: .colorLookupPreset) ?? .filmStock
        colorLookupCube = try container.decodeIfPresent(ImageEditorColorLookupCube.self, forKey: .colorLookupCube) ?? ImageEditorColorLookupCube()
        selectiveColorSettings = try container.decodeIfPresent(ImageEditorSelectiveColorSettings.self, forKey: .selectiveColorSettings) ?? ImageEditorSelectiveColorSettings()
        selectiveColorMethod = try container.decodeIfPresent(ImageEditorSelectiveColorMethod.self, forKey: .selectiveColorMethod) ?? .relative
        gradientMapPreset = try container.decodeIfPresent(ImageEditorGradientMapPreset.self, forKey: .gradientMapPreset) ?? .blackWhite
        gradientMapReverse = try container.decodeIfPresent(Bool.self, forKey: .gradientMapReverse) ?? false
        gradientMapDither = try container.decodeIfPresent(Bool.self, forKey: .gradientMapDither) ?? false
        gradientMapShadowRed = try container.decodeIfPresent(Double.self, forKey: .gradientMapShadowRed) ?? 0
        gradientMapShadowGreen = try container.decodeIfPresent(Double.self, forKey: .gradientMapShadowGreen) ?? 0
        gradientMapShadowBlue = try container.decodeIfPresent(Double.self, forKey: .gradientMapShadowBlue) ?? 0
        gradientMapHighlightRed = try container.decodeIfPresent(Double.self, forKey: .gradientMapHighlightRed) ?? 1
        gradientMapHighlightGreen = try container.decodeIfPresent(Double.self, forKey: .gradientMapHighlightGreen) ?? 1
        gradientMapHighlightBlue = try container.decodeIfPresent(Double.self, forKey: .gradientMapHighlightBlue) ?? 1
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(levelsBlackPoint, forKey: .levelsBlackPoint)
        try container.encode(levelsGamma, forKey: .levelsGamma)
        try container.encode(levelsWhitePoint, forKey: .levelsWhitePoint)
        try container.encode(curvesShadows, forKey: .curvesShadows)
        try container.encode(curvesMidtones, forKey: .curvesMidtones)
        try container.encode(curvesHighlights, forKey: .curvesHighlights)
        try container.encode(colorBalanceShadowsCyanRed, forKey: .colorBalanceShadowsCyanRed)
        try container.encode(colorBalanceShadowsMagentaGreen, forKey: .colorBalanceShadowsMagentaGreen)
        try container.encode(colorBalanceShadowsYellowBlue, forKey: .colorBalanceShadowsYellowBlue)
        try container.encode(colorBalanceMidtonesCyanRed, forKey: .colorBalanceMidtonesCyanRed)
        try container.encode(colorBalanceMidtonesMagentaGreen, forKey: .colorBalanceMidtonesMagentaGreen)
        try container.encode(colorBalanceMidtonesYellowBlue, forKey: .colorBalanceMidtonesYellowBlue)
        try container.encode(colorBalanceHighlightsCyanRed, forKey: .colorBalanceHighlightsCyanRed)
        try container.encode(colorBalanceHighlightsMagentaGreen, forKey: .colorBalanceHighlightsMagentaGreen)
        try container.encode(colorBalanceHighlightsYellowBlue, forKey: .colorBalanceHighlightsYellowBlue)
        try container.encode(hueSaturationHue, forKey: .hueSaturationHue)
        try container.encode(hueSaturationSaturation, forKey: .hueSaturationSaturation)
        try container.encode(hueSaturationLightness, forKey: .hueSaturationLightness)
        try container.encode(hueSaturationColorize, forKey: .hueSaturationColorize)
        try container.encode(brightnessContrastBrightness, forKey: .brightnessContrastBrightness)
        try container.encode(brightnessContrastContrast, forKey: .brightnessContrastContrast)
        try container.encode(exposureEV, forKey: .exposureEV)
        try container.encode(exposureOffset, forKey: .exposureOffset)
        try container.encode(exposureGamma, forKey: .exposureGamma)
        try container.encode(shadowsHighlightsShadows, forKey: .shadowsHighlightsShadows)
        try container.encode(shadowsHighlightsHighlights, forKey: .shadowsHighlightsHighlights)
        try container.encode(vibranceAmount, forKey: .vibranceAmount)
        try container.encode(vibranceSaturation, forKey: .vibranceSaturation)
        try container.encode(blackWhiteReds, forKey: .blackWhiteReds)
        try container.encode(blackWhiteYellows, forKey: .blackWhiteYellows)
        try container.encode(blackWhiteGreens, forKey: .blackWhiteGreens)
        try container.encode(blackWhiteCyans, forKey: .blackWhiteCyans)
        try container.encode(blackWhiteBlues, forKey: .blackWhiteBlues)
        try container.encode(blackWhiteMagentas, forKey: .blackWhiteMagentas)
        try container.encode(channelMixerRedRed, forKey: .channelMixerRedRed)
        try container.encode(channelMixerRedGreen, forKey: .channelMixerRedGreen)
        try container.encode(channelMixerRedBlue, forKey: .channelMixerRedBlue)
        try container.encode(channelMixerRedConstant, forKey: .channelMixerRedConstant)
        try container.encode(channelMixerGreenRed, forKey: .channelMixerGreenRed)
        try container.encode(channelMixerGreenGreen, forKey: .channelMixerGreenGreen)
        try container.encode(channelMixerGreenBlue, forKey: .channelMixerGreenBlue)
        try container.encode(channelMixerGreenConstant, forKey: .channelMixerGreenConstant)
        try container.encode(channelMixerBlueRed, forKey: .channelMixerBlueRed)
        try container.encode(channelMixerBlueGreen, forKey: .channelMixerBlueGreen)
        try container.encode(channelMixerBlueBlue, forKey: .channelMixerBlueBlue)
        try container.encode(channelMixerBlueConstant, forKey: .channelMixerBlueConstant)
        try container.encode(channelMixerMonochrome, forKey: .channelMixerMonochrome)
        try container.encode(channelMixerMonoRed, forKey: .channelMixerMonoRed)
        try container.encode(channelMixerMonoGreen, forKey: .channelMixerMonoGreen)
        try container.encode(channelMixerMonoBlue, forKey: .channelMixerMonoBlue)
        try container.encode(channelMixerMonoConstant, forKey: .channelMixerMonoConstant)
        try container.encode(photoFilterPreset, forKey: .photoFilterPreset)
        try container.encode(photoFilterDensity, forKey: .photoFilterDensity)
        try container.encode(photoFilterPreserveLuminosity, forKey: .photoFilterPreserveLuminosity)
        try container.encode(photoFilterCustomRed, forKey: .photoFilterCustomRed)
        try container.encode(photoFilterCustomGreen, forKey: .photoFilterCustomGreen)
        try container.encode(photoFilterCustomBlue, forKey: .photoFilterCustomBlue)
        try container.encode(colorLookupPreset, forKey: .colorLookupPreset)
        try container.encode(colorLookupCube, forKey: .colorLookupCube)
        try container.encode(selectiveColorSettings, forKey: .selectiveColorSettings)
        try container.encode(selectiveColorMethod, forKey: .selectiveColorMethod)
        try container.encode(gradientMapPreset, forKey: .gradientMapPreset)
        try container.encode(gradientMapReverse, forKey: .gradientMapReverse)
        try container.encode(gradientMapDither, forKey: .gradientMapDither)
        try container.encode(gradientMapShadowRed, forKey: .gradientMapShadowRed)
        try container.encode(gradientMapShadowGreen, forKey: .gradientMapShadowGreen)
        try container.encode(gradientMapShadowBlue, forKey: .gradientMapShadowBlue)
        try container.encode(gradientMapHighlightRed, forKey: .gradientMapHighlightRed)
        try container.encode(gradientMapHighlightGreen, forKey: .gradientMapHighlightGreen)
        try container.encode(gradientMapHighlightBlue, forKey: .gradientMapHighlightBlue)
    }
}
