import CoreGraphics
import Foundation

nonisolated struct XomoSVGPathParseResult: Equatable {
    var subpaths: [[ImageEditorPathAnchor]]
    var subpathClosedStates: [Bool]
    var isClosed: Bool
}

nonisolated enum XomoSVGPathParser {
    static func parse(_ source: String) -> XomoSVGPathParseResult? {
        guard let tokens = XomoSVGPathLexer.tokenize(source) else { return nil }
        var parser = XomoSVGPathTokenParser(tokens: tokens)
        return parser.parse()
    }
}

nonisolated private enum XomoSVGPathToken: Equatable {
    case command(Character)
    case number(CGFloat)
}

nonisolated private enum XomoSVGPathLexer {
    static func tokenize(_ source: String) -> [XomoSVGPathToken]? {
        let scalars = Array(source.unicodeScalars)
        var tokens: [XomoSVGPathToken] = []
        var index = 0
        while index < scalars.count {
            let scalar = scalars[index]
            if CharacterSet.whitespacesAndNewlines.contains(scalar) || scalar == "," {
                index += 1
                continue
            }
            if CharacterSet.letters.contains(scalar) {
                let command = Character(String(scalar))
                guard "MmLlHhVvCcSsQqTtAaZz".contains(command) else { return nil }
                tokens.append(.command(command))
                index += 1
                continue
            }
            guard let (number, nextIndex) = readNumber(scalars, from: index) else { return nil }
            tokens.append(.number(number))
            index = nextIndex
        }
        return tokens
    }

    private static func readNumber(
        _ scalars: [UnicodeScalar],
        from start: Int
    ) -> (CGFloat, Int)? {
        var index = start
        if index < scalars.count, scalars[index] == "+" || scalars[index] == "-" {
            index += 1
        }
        var digitCount = 0
        while index < scalars.count, CharacterSet.decimalDigits.contains(scalars[index]) {
            digitCount += 1
            index += 1
        }
        if index < scalars.count, scalars[index] == "." {
            index += 1
            while index < scalars.count, CharacterSet.decimalDigits.contains(scalars[index]) {
                digitCount += 1
                index += 1
            }
        }
        guard digitCount > 0 else { return nil }
        if index < scalars.count, scalars[index] == "e" || scalars[index] == "E" {
            let exponentStart = index
            index += 1
            if index < scalars.count, scalars[index] == "+" || scalars[index] == "-" {
                index += 1
            }
            let exponentDigitsStart = index
            while index < scalars.count, CharacterSet.decimalDigits.contains(scalars[index]) {
                index += 1
            }
            if exponentDigitsStart == index {
                index = exponentStart
            }
        }
        let raw = String(String.UnicodeScalarView(scalars[start..<index]))
        guard let value = Double(raw), value.isFinite else { return nil }
        return (CGFloat(value), index)
    }
}

nonisolated private struct XomoSVGPathTokenParser {
    let tokens: [XomoSVGPathToken]
    var index = 0
    var command: Character?
    var currentPoint = CGPoint.zero
    var subpathStart = CGPoint.zero
    var currentAnchors: [ImageEditorPathAnchor] = []
    var subpaths: [[ImageEditorPathAnchor]] = []
    var subpathClosedStates: [Bool] = []
    var isCurrentSubpathClosed = false
    var previousCommand: Character?
    var lastCubicControl: CGPoint?
    var lastQuadraticControl: CGPoint?

    mutating func parse() -> XomoSVGPathParseResult? {
        while index < tokens.count {
            if case let .command(nextCommand) = tokens[index] {
                command = nextCommand
                index += 1
            }
            guard let activeCommand = command else { return nil }
            let startIndex = index
            guard consume(activeCommand) else { return nil }
            if index == startIndex, activeCommand != "Z", activeCommand != "z" { return nil }
        }
        finishSubpath()
        guard !subpaths.isEmpty else { return nil }
        return XomoSVGPathParseResult(
            subpaths: subpaths,
            subpathClosedStates: subpathClosedStates,
            isClosed: subpathClosedStates.allSatisfy { $0 }
        )
    }

    private mutating func consume(_ rawCommand: Character) -> Bool {
        let isRelative = rawCommand.isLowercase
        let normalized = Character(rawCommand.uppercased())
        switch normalized {
        case "M": return consumeMove(isRelative: isRelative)
        case "L": return consumeLine(isRelative: isRelative)
        case "H": return consumeHorizontal(isRelative: isRelative)
        case "V": return consumeVertical(isRelative: isRelative)
        case "C": return consumeCubic(isRelative: isRelative)
        case "S": return consumeSmoothCubic(isRelative: isRelative)
        case "Q": return consumeQuadratic(isRelative: isRelative)
        case "T": return consumeSmoothQuadratic(isRelative: isRelative)
        case "A": return consumeArc(isRelative: isRelative)
        case "Z": return consumeClose()
        default: return false
        }
    }

    private mutating func consumeMove(isRelative: Bool) -> Bool {
        guard let first = readPoint(relative: isRelative) else { return false }
        finishSubpath()
        currentPoint = first
        subpathStart = first
        currentAnchors = [ImageEditorPathAnchor(point: first)]
        resetControls()
        previousCommand = "M"
        while let point = readPoint(relative: isRelative) {
            appendLine(to: point)
        }
        command = isRelative ? "l" : "L"
        return true
    }

    private mutating func consumeLine(isRelative: Bool) -> Bool {
        var consumed = false
        while let point = readPoint(relative: isRelative) {
            appendLine(to: point)
            consumed = true
        }
        return consumed
    }

    private mutating func consumeHorizontal(isRelative: Bool) -> Bool {
        var consumed = false
        while let value = readNumber() {
            appendLine(to: CGPoint(x: isRelative ? currentPoint.x + value : value, y: currentPoint.y))
            consumed = true
        }
        return consumed
    }

    private mutating func consumeVertical(isRelative: Bool) -> Bool {
        var consumed = false
        while let value = readNumber() {
            appendLine(to: CGPoint(x: currentPoint.x, y: isRelative ? currentPoint.y + value : value))
            consumed = true
        }
        return consumed
    }

    private mutating func consumeCubic(isRelative: Bool) -> Bool {
        var consumed = false
        while hasNumberToken {
            let savedIndex = index
            guard let first = readPoint(relative: isRelative),
                  let second = readPoint(relative: isRelative),
                  let end = readPoint(relative: isRelative)
            else {
                index = savedIndex
                return false
            }
            appendCubic(firstControl: first, secondControl: second, end: end)
            lastCubicControl = second
            lastQuadraticControl = nil
            previousCommand = "C"
            consumed = true
        }
        return consumed
    }

    private mutating func consumeSmoothCubic(isRelative: Bool) -> Bool {
        var consumed = false
        while hasNumberToken {
            let savedIndex = index
            guard let second = readPoint(relative: isRelative),
                  let end = readPoint(relative: isRelative)
            else {
                index = savedIndex
                return false
            }
            let first = reflectedControl(lastCubicControl, forCommands: ["C", "S"])
            appendCubic(firstControl: first, secondControl: second, end: end)
            lastCubicControl = second
            lastQuadraticControl = nil
            previousCommand = "S"
            consumed = true
        }
        return consumed
    }

    private mutating func consumeQuadratic(isRelative: Bool) -> Bool {
        var consumed = false
        while hasNumberToken {
            let savedIndex = index
            guard let control = readPoint(relative: isRelative),
                  let end = readPoint(relative: isRelative)
            else {
                index = savedIndex
                return false
            }
            appendQuadratic(control: control, end: end)
            lastQuadraticControl = control
            lastCubicControl = nil
            previousCommand = "Q"
            consumed = true
        }
        return consumed
    }

    private mutating func consumeSmoothQuadratic(isRelative: Bool) -> Bool {
        var consumed = false
        while let end = readPoint(relative: isRelative) {
            let control = reflectedControl(lastQuadraticControl, forCommands: ["Q", "T"])
            appendQuadratic(control: control, end: end)
            lastQuadraticControl = control
            lastCubicControl = nil
            previousCommand = "T"
            consumed = true
        }
        return consumed
    }

    private mutating func consumeArc(isRelative: Bool) -> Bool {
        var consumed = false
        while hasNumberToken {
            let savedIndex = index
            guard let radiusX = readNumber(),
                  let radiusY = readNumber(),
                  let rotation = readNumber(),
                  let largeArc = readFlag(),
                  let sweep = readFlag(),
                  let end = readPoint(relative: isRelative)
            else {
                index = savedIndex
                return false
            }
            let segments = XomoSVGArcConverter.cubicSegments(
                from: currentPoint,
                to: end,
                radiusX: radiusX,
                radiusY: radiusY,
                rotationDegrees: rotation,
                largeArc: largeArc,
                sweep: sweep
            )
            if segments.isEmpty {
                appendLine(to: end)
            } else {
                for segment in segments {
                    appendCubic(
                        firstControl: segment.firstControl,
                        secondControl: segment.secondControl,
                        end: segment.end
                    )
                }
            }
            resetControls()
            previousCommand = "A"
            consumed = true
        }
        return consumed
    }

    private mutating func consumeClose() -> Bool {
        guard !currentAnchors.isEmpty else { return false }
        foldExplicitClosingAnchorIntoStart()
        isCurrentSubpathClosed = true
        currentPoint = subpathStart
        resetControls()
        previousCommand = "Z"
        command = nil
        return true
    }

    private mutating func foldExplicitClosingAnchorIntoStart() {
        guard currentAnchors.count >= 4,
              let closingAnchor = currentAnchors.last,
              closingAnchor.point == subpathStart,
              closingAnchor.outControl == nil
        else { return }
        currentAnchors[0].inControl = closingAnchor.inControl
        currentAnchors.removeLast()
    }

    private mutating func appendLine(to point: CGPoint) {
        currentAnchors.append(ImageEditorPathAnchor(point: point))
        currentPoint = point
        resetControls()
        previousCommand = "L"
    }

    private mutating func appendCubic(firstControl: CGPoint, secondControl: CGPoint, end: CGPoint) {
        guard !currentAnchors.isEmpty else { return }
        currentAnchors[currentAnchors.count - 1].outControl = firstControl
        currentAnchors.append(ImageEditorPathAnchor(point: end, inControl: secondControl, outControl: nil))
        currentPoint = end
    }

    private mutating func appendQuadratic(control: CGPoint, end: CGPoint) {
        let first = CGPoint(
            x: currentPoint.x + (control.x - currentPoint.x) * 2 / 3,
            y: currentPoint.y + (control.y - currentPoint.y) * 2 / 3
        )
        let second = CGPoint(
            x: end.x + (control.x - end.x) * 2 / 3,
            y: end.y + (control.y - end.y) * 2 / 3
        )
        appendCubic(firstControl: first, secondControl: second, end: end)
    }

    private func reflectedControl(_ control: CGPoint?, forCommands commands: Set<Character>) -> CGPoint {
        guard let control, let previousCommand, commands.contains(previousCommand) else { return currentPoint }
        return CGPoint(x: currentPoint.x * 2 - control.x, y: currentPoint.y * 2 - control.y)
    }

    private mutating func finishSubpath() {
        if currentAnchors.count >= 2 {
            subpaths.append(currentAnchors)
            subpathClosedStates.append(isCurrentSubpathClosed)
        }
        currentAnchors = []
        isCurrentSubpathClosed = false
    }

    private mutating func resetControls() {
        lastCubicControl = nil
        lastQuadraticControl = nil
    }

    private mutating func readPoint(relative: Bool) -> CGPoint? {
        let savedIndex = index
        guard let x = readNumber(), let y = readNumber() else {
            index = savedIndex
            return nil
        }
        return CGPoint(
            x: relative ? currentPoint.x + x : x,
            y: relative ? currentPoint.y + y : y
        )
    }

    private mutating func readFlag() -> Bool? {
        guard let value = readNumber(), value == 0 || value == 1 else { return nil }
        return value == 1
    }

    private mutating func readNumber() -> CGFloat? {
        guard index < tokens.count, case let .number(value) = tokens[index] else { return nil }
        index += 1
        return value
    }

    private var hasNumberToken: Bool {
        guard index < tokens.count else { return false }
        if case .number = tokens[index] { return true }
        return false
    }
}

nonisolated private struct XomoSVGArcSegment {
    var firstControl: CGPoint
    var secondControl: CGPoint
    var end: CGPoint
}

nonisolated private enum XomoSVGArcConverter {
    static func cubicSegments(
        from start: CGPoint,
        to end: CGPoint,
        radiusX rawRadiusX: CGFloat,
        radiusY rawRadiusY: CGFloat,
        rotationDegrees: CGFloat,
        largeArc: Bool,
        sweep: Bool
    ) -> [XomoSVGArcSegment] {
        var radiusX = abs(rawRadiusX)
        var radiusY = abs(rawRadiusY)
        guard radiusX > 0, radiusY > 0, start != end else { return [] }
        let rotation = rotationDegrees * .pi / 180
        let cosine = cos(rotation)
        let sine = sin(rotation)
        let halfDelta = CGPoint(x: (start.x - end.x) / 2, y: (start.y - end.y) / 2)
        let transformed = CGPoint(
            x: cosine * halfDelta.x + sine * halfDelta.y,
            y: -sine * halfDelta.x + cosine * halfDelta.y
        )
        let scale = transformed.x * transformed.x / (radiusX * radiusX)
            + transformed.y * transformed.y / (radiusY * radiusY)
        if scale > 1 {
            let factor = sqrt(scale)
            radiusX *= factor
            radiusY *= factor
        }
        let numerator = max(
            0,
            radiusX * radiusX * radiusY * radiusY
                - radiusX * radiusX * transformed.y * transformed.y
                - radiusY * radiusY * transformed.x * transformed.x
        )
        let denominator = radiusX * radiusX * transformed.y * transformed.y
            + radiusY * radiusY * transformed.x * transformed.x
        let sign: CGFloat = largeArc == sweep ? -1 : 1
        let coefficient = denominator > 0 ? sign * sqrt(numerator / denominator) : 0
        let centerPrime = CGPoint(
            x: coefficient * radiusX * transformed.y / radiusY,
            y: coefficient * -radiusY * transformed.x / radiusX
        )
        let center = CGPoint(
            x: cosine * centerPrime.x - sine * centerPrime.y + (start.x + end.x) / 2,
            y: sine * centerPrime.x + cosine * centerPrime.y + (start.y + end.y) / 2
        )
        let startVector = CGPoint(
            x: (transformed.x - centerPrime.x) / radiusX,
            y: (transformed.y - centerPrime.y) / radiusY
        )
        let endVector = CGPoint(
            x: (-transformed.x - centerPrime.x) / radiusX,
            y: (-transformed.y - centerPrime.y) / radiusY
        )
        var startAngle = atan2(startVector.y, startVector.x)
        var deltaAngle = atan2(
            startVector.x * endVector.y - startVector.y * endVector.x,
            startVector.x * endVector.x + startVector.y * endVector.y
        )
        if !sweep, deltaAngle > 0 { deltaAngle -= 2 * .pi }
        if sweep, deltaAngle < 0 { deltaAngle += 2 * .pi }
        let segmentCount = max(1, Int(ceil(abs(deltaAngle) / (.pi / 2))))
        let segmentAngle = deltaAngle / CGFloat(segmentCount)
        var result: [XomoSVGArcSegment] = []
        for _ in 0..<segmentCount {
            let nextAngle = startAngle + segmentAngle
            let factor = 4 / 3 * tan(segmentAngle / 4)
            let firstControl = mappedPoint(
                angle: startAngle,
                tangentScale: factor,
                center: center,
                radiusX: radiusX,
                radiusY: radiusY,
                cosine: cosine,
                sine: sine,
                isStart: true
            )
            let secondControl = mappedPoint(
                angle: nextAngle,
                tangentScale: factor,
                center: center,
                radiusX: radiusX,
                radiusY: radiusY,
                cosine: cosine,
                sine: sine,
                isStart: false
            )
            result.append(XomoSVGArcSegment(
                firstControl: firstControl,
                secondControl: secondControl,
                end: ellipsePoint(
                    angle: nextAngle,
                    center: center,
                    radiusX: radiusX,
                    radiusY: radiusY,
                    cosine: cosine,
                    sine: sine
                )
            ))
            startAngle = nextAngle
        }
        if !result.isEmpty { result[result.count - 1].end = end }
        return result
    }

    private static func mappedPoint(
        angle: CGFloat,
        tangentScale: CGFloat,
        center: CGPoint,
        radiusX: CGFloat,
        radiusY: CGFloat,
        cosine: CGFloat,
        sine: CGFloat,
        isStart: Bool
    ) -> CGPoint {
        let direction: CGFloat = isStart ? 1 : -1
        let x = cos(angle) - direction * tangentScale * sin(angle)
        let y = sin(angle) + direction * tangentScale * cos(angle)
        return CGPoint(
            x: center.x + cosine * radiusX * x - sine * radiusY * y,
            y: center.y + sine * radiusX * x + cosine * radiusY * y
        )
    }

    private static func ellipsePoint(
        angle: CGFloat,
        center: CGPoint,
        radiusX: CGFloat,
        radiusY: CGFloat,
        cosine: CGFloat,
        sine: CGFloat
    ) -> CGPoint {
        CGPoint(
            x: center.x + cosine * radiusX * cos(angle) - sine * radiusY * sin(angle),
            y: center.y + sine * radiusX * cos(angle) + cosine * radiusY * sin(angle)
        )
    }
}
