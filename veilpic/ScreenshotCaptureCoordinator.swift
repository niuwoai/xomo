//
//  ScreenshotCaptureCoordinator.swift
//  veilpic
//
//  Created by Codex on 2026/6/30.
//

import AppKit
import CoreGraphics
import ScreenCaptureKit

final class ScreenshotCaptureCoordinator {
    static let shared = ScreenshotCaptureCoordinator()

    private init() {}

    func captureAllDisplays() async -> NSImage? {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return nil }

        let union = screens.reduce(CGRect.null) { $0.union($1.frame) }
        guard !union.isNull, !union.isEmpty else { return nil }

        let scale = screens.map(\.backingScaleFactor).max() ?? 2
        let pixelSize = CGSize(width: union.width * scale, height: union.height * scale)
        guard let context = CGContext(
            data: nil,
            width: Int(pixelSize.width),
            height: Int(pixelSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        context.scaleBy(x: scale, y: scale)

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )

            for screen in screens {
                guard let displayID = displayID(for: screen),
                      let display = content.displays.first(where: { $0.displayID == displayID }),
                      let capturedImage = try await capture(display: display, screen: screen),
                      let image = capturedImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
                else {
                    continue
                }

                let drawRect = CGRect(
                    x: screen.frame.minX - union.minX,
                    y: screen.frame.minY - union.minY,
                    width: screen.frame.width,
                    height: screen.frame.height
                )
                context.draw(image, in: drawRect)
            }
        } catch {
            return nil
        }

        guard let image = context.makeImage() else { return nil }
        return NSImage(cgImage: image, size: union.size)
    }

    func captureGlobalRect(_ rect: CGRect, excludingWindowNumbers: Set<Int> = []) async -> NSImage? {
        guard let screen = NSScreen.screens.first(where: { $0.frame.intersects(rect) }) ?? NSScreen.main,
              let displayID = displayID(for: screen)
        else {
            return nil
        }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
            guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
                return nil
            }

            let excludedWindows = content.windows.filter { excludingWindowNumbers.contains(Int($0.windowID)) }
            let localRect = sourceRect(fromGlobalRect: rect, in: screen)
            let config = SCStreamConfiguration()
            let scale = screen.backingScaleFactor
            config.sourceRect = localRect
            config.width = Int(localRect.width * scale)
            config.height = Int(localRect.height * scale)
            config.showsCursor = false
            config.capturesAudio = false

            let filter = SCContentFilter(display: display, excludingWindows: excludedWindows)
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            return NSImage(cgImage: image, size: rect.size)
        } catch {
            return nil
        }
    }

    func captureScreen(_ screen: NSScreen) async -> NSImage? {
        guard let displayID = displayID(for: screen) else {
            return nil
        }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
            guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
                return nil
            }
            return try await capture(display: display, screen: screen)
        } catch {
            return nil
        }
    }

    func requestScreenRecordingPermissionIfNeeded() -> Bool {
        if CGPreflightScreenCaptureAccess() {
            return true
        }

        return CGRequestScreenCaptureAccess()
    }

    private func capture(display: SCDisplay, screen: NSScreen) async throws -> NSImage? {
        let config = SCStreamConfiguration()
        let scale = screen.backingScaleFactor
        config.width = Int(CGFloat(display.width) * scale)
        config.height = Int(CGFloat(display.height) * scale)
        config.showsCursor = false
        config.capturesAudio = false

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        return NSImage(cgImage: image, size: screen.frame.size)
    }

    private func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }

        return CGDirectDisplayID(number.uint32Value)
    }

    private func sourceRect(fromGlobalRect rect: CGRect, in screen: NSScreen) -> CGRect {
        CGRect(
            x: rect.minX - screen.frame.minX,
            y: screen.frame.maxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }
}
