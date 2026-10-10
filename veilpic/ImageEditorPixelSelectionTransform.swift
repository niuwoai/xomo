import CoreGraphics

enum ImageEditorPixelSelectionTransform {
    private static let componentsPerPixel = 4
    private static let maximumComponent: CGFloat = 255

    static func flipped(
        source: [UInt8], maskAlpha: [UInt8], width: Int, height: Int, horizontally: Bool
    ) -> [UInt8]? {
        guard width > 0, height > 0,
              height <= maskAlpha.count / width,
              maskAlpha.count == width * height,
              source.count.isMultiple(of: componentsPerPixel),
              source.count / componentsPerPixel == maskAlpha.count,
              let bounds = ImageEditorPixelMoveCoverageBounds(maskAlpha: maskAlpha, width: width, height: height)
        else { return nil }

        var output = source
        clear(source: source, maskAlpha: maskAlpha, width: width, bounds: bounds, into: &output)
        for y in bounds.rows {
            for x in bounds.columns {
                let sourcePixel = y * width + x
                let coverage = CGFloat(maskAlpha[sourcePixel]) / maximumComponent
                guard coverage > 0 else { continue }
                let targetX = horizontally
                    ? bounds.columns.upperBound - (x - bounds.columns.lowerBound) - 1
                    : x
                let targetY = horizontally
                    ? y
                    : bounds.rows.upperBound - (y - bounds.rows.lowerBound) - 1
                ImageEditorPremultipliedPixelCompositing.composite(
                    source: source,
                    sourcePixel: sourcePixel,
                    targetPixel: targetY * width + targetX,
                    coverage: coverage,
                    into: &output
                )
            }
        }
        return output
    }

    static func rotatedQuarterTurns(
        source: [UInt8], maskAlpha: [UInt8], width: Int, height: Int, clockwiseTurns: Int
    ) -> [UInt8]? {
        guard width > 0, height > 0,
              height <= maskAlpha.count / width,
              maskAlpha.count == width * height,
              source.count.isMultiple(of: componentsPerPixel),
              source.count / componentsPerPixel == maskAlpha.count,
              let bounds = ImageEditorPixelMoveCoverageBounds(maskAlpha: maskAlpha, width: width, height: height)
        else { return nil }

        let turns = ((clockwiseTurns % 4) + 4) % 4
        guard turns != 0 else { return source }

        var output = source
        clear(source: source, maskAlpha: maskAlpha, width: width, bounds: bounds, into: &output)
        let selectedWidth = bounds.columns.count
        let selectedHeight = bounds.rows.count
        for y in bounds.rows {
            for x in bounds.columns {
                let sourcePixel = y * width + x
                let coverage = CGFloat(maskAlpha[sourcePixel]) / maximumComponent
                guard coverage > 0 else { continue }

                let localX = x - bounds.columns.lowerBound
                let localY = y - bounds.rows.lowerBound
                let target: (x: Int, y: Int)
                switch turns {
                case 1:
                    target = (bounds.columns.lowerBound + selectedHeight - 1 - localY,
                              bounds.rows.lowerBound + localX)
                case 2:
                    target = (bounds.columns.upperBound - 1 - localX,
                              bounds.rows.upperBound - 1 - localY)
                default:
                    target = (bounds.columns.lowerBound + localY,
                              bounds.rows.lowerBound + selectedWidth - 1 - localX)
                }
                guard target.x >= 0, target.y >= 0, target.x < width, target.y < height else { continue }
                ImageEditorPremultipliedPixelCompositing.composite(
                    source: source,
                    sourcePixel: sourcePixel,
                    targetPixel: target.y * width + target.x,
                    coverage: coverage,
                    into: &output
                )
            }
        }
        return output
    }

    static func scaled(
        source: [UInt8], sourceMaskAlpha: [UInt8], destinationMaskAlpha: [UInt8],
        width: Int, height: Int, layerFrame: CGRect,
        sourceCanvasBounds: CGRect, destinationCanvasBounds: CGRect
    ) -> [UInt8]? {
        guard width > 0, height > 0,
              [layerFrame.minX, layerFrame.minY, layerFrame.width, layerFrame.height,
               sourceCanvasBounds.minX, sourceCanvasBounds.minY,
               sourceCanvasBounds.width, sourceCanvasBounds.height,
               destinationCanvasBounds.minX, destinationCanvasBounds.minY,
               destinationCanvasBounds.width, destinationCanvasBounds.height].allSatisfy(\.isFinite),
              layerFrame.width > 0, layerFrame.height > 0,
              sourceCanvasBounds.width > 0, sourceCanvasBounds.height > 0,
              destinationCanvasBounds.width > 0, destinationCanvasBounds.height > 0
        else { return nil }
        let (pixelCount, overflow) = width.multipliedReportingOverflow(by: height)
        guard !overflow, pixelCount <= Int.max / componentsPerPixel,
              sourceMaskAlpha.count == pixelCount,
              destinationMaskAlpha.count == pixelCount,
              source.count == pixelCount * componentsPerPixel,
              let sourceBounds = ImageEditorPixelMoveCoverageBounds(
                maskAlpha: sourceMaskAlpha, width: width, height: height
              ),
              let destinationBounds = ImageEditorPixelMoveCoverageBounds(
                maskAlpha: destinationMaskAlpha, width: width, height: height
              )
        else { return nil }

        var output = source
        clear(source: source, maskAlpha: sourceMaskAlpha, width: width, bounds: sourceBounds, into: &output)

        for targetY in destinationBounds.rows {
            for targetX in destinationBounds.columns {
                let targetPixel = targetY * width + targetX
                let coverage = CGFloat(destinationMaskAlpha[targetPixel]) / maximumComponent
                guard coverage > 0,
                      let sample = sampleScaledPixel(
                        source: source,
                        sourceMaskAlpha: sourceMaskAlpha,
                        width: width,
                        sourceBounds: sourceBounds,
                        layerFrame: layerFrame,
                        sourceCanvasBounds: sourceCanvasBounds,
                        destinationCanvasBounds: destinationCanvasBounds,
                        targetX: targetX,
                        targetY: targetY
                      )
                else { continue }
                composite(sample: sample, coverage: coverage, targetPixel: targetPixel, into: &output)
            }
        }
        return output
    }

    static func scaledCoverageMask(
        sourceMaskAlpha: [UInt8], width: Int, height: Int, layerFrame: CGRect,
        sourceCanvasBounds: CGRect, destinationCanvasBounds: CGRect,
        coverageCanvasBounds: CGRect? = nil, usesNearestSampling: Bool = false
    ) -> [UInt8]? {
        let coverageBounds = coverageCanvasBounds ?? destinationCanvasBounds
        guard width > 0, height > 0,
              [layerFrame.minX, layerFrame.minY, layerFrame.width, layerFrame.height,
               sourceCanvasBounds.minX, sourceCanvasBounds.minY,
               sourceCanvasBounds.width, sourceCanvasBounds.height,
               destinationCanvasBounds.minX, destinationCanvasBounds.minY,
               destinationCanvasBounds.width, destinationCanvasBounds.height,
               coverageBounds.minX, coverageBounds.minY,
               coverageBounds.width, coverageBounds.height].allSatisfy(\.isFinite),
              layerFrame.width > 0, layerFrame.height > 0,
              sourceCanvasBounds.width > 0, sourceCanvasBounds.height > 0,
              destinationCanvasBounds.width > 0, destinationCanvasBounds.height > 0,
              height <= Int.max / width,
              sourceMaskAlpha.count == width * height,
              let sourceBounds = ImageEditorPixelMoveCoverageBounds(
                maskAlpha: sourceMaskAlpha, width: width, height: height
              )
        else { return nil }

        var output = [UInt8](repeating: 0, count: sourceMaskAlpha.count)
        let clippedCoverageBounds = coverageBounds.intersection(layerFrame)
        guard !clippedCoverageBounds.isNull, !clippedCoverageBounds.isEmpty,
              let targetColumns = pixelCenters(
                in: clippedCoverageBounds.minX..<clippedCoverageBounds.maxX,
                origin: layerFrame.minX, extent: layerFrame.width, count: width
              ),
              let targetRows = pixelCenters(
                in: clippedCoverageBounds.minY..<clippedCoverageBounds.maxY,
                origin: layerFrame.minY, extent: layerFrame.height, count: height
              )
        else { return nil }
        guard !targetColumns.isEmpty, !targetRows.isEmpty else { return output }

        for targetY in targetRows {
            let canvasY = layerFrame.minY + (CGFloat(targetY) + 0.5) * layerFrame.height / CGFloat(height)
            guard canvasY >= coverageBounds.minY,
                  canvasY < coverageBounds.maxY else { continue }
            let sourceCanvasY = sourceCanvasBounds.minY
                + (canvasY - destinationCanvasBounds.minY)
                    * sourceCanvasBounds.height / destinationCanvasBounds.height
            let sourceY = (sourceCanvasY - layerFrame.minY) * CGFloat(height) / layerFrame.height - 0.5
            guard sourceY >= CGFloat(sourceBounds.rows.lowerBound) - 0.5,
                  sourceY <= CGFloat(sourceBounds.rows.upperBound) - 0.5 else { continue }
            let y0 = max(sourceBounds.rows.lowerBound,
                         min(sourceBounds.rows.upperBound - 1, Int(floor(sourceY))))
            let y1 = min(sourceBounds.rows.upperBound - 1, y0 + 1)
            let fractionY = max(0, min(1, sourceY - CGFloat(y0)))

            for targetX in targetColumns {
                let canvasX = layerFrame.minX + (CGFloat(targetX) + 0.5) * layerFrame.width / CGFloat(width)
                guard canvasX >= coverageBounds.minX,
                      canvasX < coverageBounds.maxX else { continue }
                let sourceCanvasX = sourceCanvasBounds.minX
                    + (canvasX - destinationCanvasBounds.minX)
                        * sourceCanvasBounds.width / destinationCanvasBounds.width
                let sourceX = (sourceCanvasX - layerFrame.minX) * CGFloat(width) / layerFrame.width - 0.5
                guard sourceX >= CGFloat(sourceBounds.columns.lowerBound) - 0.5,
                      sourceX <= CGFloat(sourceBounds.columns.upperBound) - 0.5 else { continue }
                if usesNearestSampling {
                    let nearestX = max(sourceBounds.columns.lowerBound,
                                       min(sourceBounds.columns.upperBound - 1, Int((sourceX + 0.5).rounded(.down))))
                    let nearestY = max(sourceBounds.rows.lowerBound,
                                       min(sourceBounds.rows.upperBound - 1, Int((sourceY + 0.5).rounded(.down))))
                    output[targetY * width + targetX] = sourceMaskAlpha[nearestY * width + nearestX]
                    continue
                }
                let x0 = max(sourceBounds.columns.lowerBound,
                             min(sourceBounds.columns.upperBound - 1, Int(floor(sourceX))))
                let x1 = min(sourceBounds.columns.upperBound - 1, x0 + 1)
                let fractionX = max(0, min(1, sourceX - CGFloat(x0)))
                let top = interpolate(
                    sourceMaskAlpha[y0 * width + x0], sourceMaskAlpha[y0 * width + x1], fraction: fractionX
                )
                let bottom = interpolate(
                    sourceMaskAlpha[y1 * width + x0], sourceMaskAlpha[y1 * width + x1], fraction: fractionX
                )
                output[targetY * width + targetX] = interpolate(top, bottom, fraction: fractionY)
            }
        }
        return output
    }

    private static func interpolate(_ first: UInt8, _ second: UInt8, fraction: CGFloat) -> UInt8 {
        UInt8(max(0, min(maximumComponent,
                         (CGFloat(first) * (1 - fraction) + CGFloat(second) * fraction).rounded())))
    }

    private static func pixelCenters(
        in bounds: Range<CGFloat>, origin: CGFloat, extent: CGFloat, count: Int
    ) -> Range<Int>? {
        guard count > 0, extent > 0, extent.isFinite,
              bounds.lowerBound.isFinite, bounds.upperBound.isFinite else { return nil }
        let first = (bounds.lowerBound - origin) * CGFloat(count) / extent - 0.5
        let end = (bounds.upperBound - origin) * CGFloat(count) / extent - 0.5
        guard first.isFinite, end.isFinite else { return nil }
        let lower = Int(max(0, min(CGFloat(count), first.rounded(.up))))
        let upper = Int(max(0, min(CGFloat(count), end.rounded(.up))))
        return lower..<max(lower, upper)
    }

    private static func clear(
        source: [UInt8], maskAlpha: [UInt8], width: Int,
        bounds: ImageEditorPixelMoveCoverageBounds, into output: inout [UInt8]
    ) {
        for y in bounds.rows {
            for x in bounds.columns {
                let pixel = y * width + x
                let inverse = 1 - CGFloat(maskAlpha[pixel]) / maximumComponent
                guard inverse < 1 else { continue }
                let offset = pixel * componentsPerPixel
                for channel in 0..<componentsPerPixel {
                    output[offset + channel] = UInt8((CGFloat(source[offset + channel]) * inverse).rounded())
                }
            }
        }
    }

    private static func sampleScaledPixel(
        source: [UInt8], sourceMaskAlpha: [UInt8], width: Int,
        sourceBounds: ImageEditorPixelMoveCoverageBounds,
        layerFrame: CGRect, sourceCanvasBounds: CGRect, destinationCanvasBounds: CGRect,
        targetX: Int, targetY: Int
    ) -> [UInt8]? {
        let height = sourceMaskAlpha.count / width
        let canvasX = layerFrame.minX + (CGFloat(targetX) + 0.5) * layerFrame.width / CGFloat(width)
        let canvasY = layerFrame.minY + (CGFloat(targetY) + 0.5) * layerFrame.height / CGFloat(height)
        let sourceCanvasX = sourceCanvasBounds.minX
            + (canvasX - destinationCanvasBounds.minX)
                * sourceCanvasBounds.width / destinationCanvasBounds.width
        let sourceCanvasY = sourceCanvasBounds.minY
            + (canvasY - destinationCanvasBounds.minY)
                * sourceCanvasBounds.height / destinationCanvasBounds.height
        let sourceX = (sourceCanvasX - layerFrame.minX) * CGFloat(width) / layerFrame.width - 0.5
        let sourceY = (sourceCanvasY - layerFrame.minY) * CGFloat(height) / layerFrame.height - 0.5
        guard sourceX.isFinite, sourceY.isFinite,
              sourceX >= CGFloat(sourceBounds.columns.lowerBound) - 0.5,
              sourceX <= CGFloat(sourceBounds.columns.upperBound) - 0.5,
              sourceY >= CGFloat(sourceBounds.rows.lowerBound) - 0.5,
              sourceY <= CGFloat(sourceBounds.rows.upperBound) - 0.5
        else { return nil }

        let x0 = max(sourceBounds.columns.lowerBound, min(sourceBounds.columns.upperBound - 1, Int(floor(sourceX))))
        let y0 = max(sourceBounds.rows.lowerBound, min(sourceBounds.rows.upperBound - 1, Int(floor(sourceY))))
        let x1 = min(sourceBounds.columns.upperBound - 1, x0 + 1)
        let y1 = min(sourceBounds.rows.upperBound - 1, y0 + 1)
        let fractionX = max(0, min(1, sourceX - CGFloat(x0)))
        let fractionY = max(0, min(1, sourceY - CGFloat(y0)))
        let samples: [(x: Int, y: Int, weight: CGFloat)] = [
            (x0, y0, (1 - fractionX) * (1 - fractionY)),
            (x1, y0, fractionX * (1 - fractionY)),
            (x0, y1, (1 - fractionX) * fractionY),
            (x1, y1, fractionX * fractionY)
        ]
        var totalWeight: CGFloat = 0
        var channels = [CGFloat](repeating: 0, count: componentsPerPixel)
        for sample in samples {
            let pixel = sample.y * width + sample.x
            let selectionWeight = CGFloat(sourceMaskAlpha[pixel]) / maximumComponent
            let weight = sample.weight * selectionWeight
            guard weight > 0 else { continue }
            totalWeight += weight
            let offset = pixel * componentsPerPixel
            for channel in 0..<componentsPerPixel {
                channels[channel] += CGFloat(source[offset + channel]) * weight
            }
        }
        guard totalWeight > 0 else { return nil }
        return channels.map { UInt8(max(0, min(maximumComponent, ($0 / totalWeight).rounded()))) }
    }

    private static func composite(sample: [UInt8], coverage: CGFloat, targetPixel: Int, into output: inout [UInt8]) {
        let offset = targetPixel * componentsPerPixel
        let inverse = 1 - CGFloat(sample[3]) / maximumComponent * coverage
        for channel in 0..<componentsPerPixel {
            let value = CGFloat(sample[channel]) * coverage + CGFloat(output[offset + channel]) * inverse
            output[offset + channel] = UInt8(max(0, min(maximumComponent, value.rounded())))
        }
    }
}
