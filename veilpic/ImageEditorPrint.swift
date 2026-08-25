//
//  ImageEditorPrint.swift
//  veilpic
//
//  Created by Codex on 2026/8/25.
//

import AppKit

@MainActor
final class ImageEditorPrintConfiguration {
    private var printInfo: NSPrintInfo
    private(set) var isCustomized = false

    init(sourcePrintInfo: NSPrintInfo = .shared) {
        printInfo = (sourcePrintInfo.copy() as? NSPrintInfo) ?? NSPrintInfo()
    }

    func candidate(for canvasSize: CGSize) -> NSPrintInfo? {
        guard let candidate = printInfo.copy() as? NSPrintInfo else { return nil }
        if !isCustomized {
            candidate.orientation = canvasSize.width > canvasSize.height
                ? .landscape
                : .portrait
        }
        return candidate
    }

    func commit(_ candidate: NSPrintInfo) {
        guard let committed = candidate.copy() as? NSPrintInfo else { return }
        printInfo = committed
        isCustomized = true
    }
}

enum ImageEditorPrintLayout {
    static func fittedRect(for contentSize: CGSize, in pageRect: CGRect) -> CGRect? {
        let content = CGSize(
            width: abs(contentSize.width),
            height: abs(contentSize.height)
        )
        let page = pageRect.standardized
        guard content.width > 0,
              content.height > 0,
              content.width.isFinite,
              content.height.isFinite,
              page.width > 0,
              page.height > 0,
              page.minX.isFinite,
              page.minY.isFinite,
              page.width.isFinite,
              page.height.isFinite
        else { return nil }

        let scale = min(page.width / content.width, page.height / content.height)
        let fittedSize = CGSize(
            width: content.width * scale,
            height: content.height * scale
        )
        return CGRect(
            x: page.midX - fittedSize.width / 2,
            y: page.midY - fittedSize.height / 2,
            width: fittedSize.width,
            height: fittedSize.height
        )
    }
}

final class ImageEditorPrintPageView: NSView {
    let image: NSImage
    let imageRect: CGRect

    init?(image: NSImage, printableSize: CGSize) {
        let pageRect = CGRect(origin: .zero, size: printableSize)
        guard let imageRect = ImageEditorPrintLayout.fittedRect(
            for: image.size,
            in: pageRect
        ) else { return nil }
        self.image = image
        self.imageRect = imageRect
        super.init(frame: pageRect)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        return nil
    }

    override var isFlipped: Bool { true }

    override func knowsPageRange(_ range: NSRangePointer) -> Bool {
        range.pointee = NSRange(location: 1, length: 1)
        return true
    }

    override func rectForPage(_ page: Int) -> NSRect {
        page == 1 ? bounds : .zero
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        image.draw(
            in: imageRect,
            from: CGRect(origin: .zero, size: image.size),
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
    }
}

@MainActor
extension ImageEditorViewModel {
    var canPrintCompositedCanvas: Bool {
        document.canvasSize.width > 0 && document.canvasSize.height > 0
    }

    @discardableResult
    func presentPageSetup(
        pageLayoutRunner: @MainActor (NSPrintInfo) -> Bool = { printInfo in
            NSPageLayout().runModal(with: printInfo)
                == NSApplication.ModalResponse.OK.rawValue
        }
    ) -> Bool {
        guard canPrintCompositedCanvas,
              let candidate = printConfiguration.candidate(for: document.canvasSize)
        else {
            statusText = L10n.text("imageEditor.status.pageSetupFailed")
            return false
        }

        let didChange = pageLayoutRunner(candidate)
        if didChange {
            printConfiguration.commit(candidate)
        }
        statusText = L10n.text(
            didChange
                ? "imageEditor.status.pageSetupCompleted"
                : "imageEditor.status.pageSetupCancelled"
        )
        return didChange
    }

    @discardableResult
    func printCompositedCanvas(
        printInfo sourcePrintInfo: NSPrintInfo? = nil,
        printRunner: @MainActor (ImageEditorPrintPageView, NSPrintInfo) -> Bool = { view, printInfo in
            let operation = NSPrintOperation(view: view, printInfo: printInfo)
            operation.showsPrintPanel = true
            operation.showsProgressPanel = true
            return operation.run()
        }
    ) -> Bool {
        guard canPrintCompositedCanvas else {
            statusText = L10n.text("imageEditor.status.printFailed")
            return false
        }

        let printInfo: NSPrintInfo?
        if let sourcePrintInfo {
            printInfo = sourcePrintInfo.copy() as? NSPrintInfo
            printInfo?.orientation = document.canvasSize.width > document.canvasSize.height
                ? .landscape
                : .portrait
        } else {
            printInfo = printConfiguration.candidate(for: document.canvasSize)
        }
        guard let printInfo
        else {
            statusText = L10n.text("imageEditor.status.printFailed")
            return false
        }

        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .fit
        printInfo.isHorizontallyCentered = true
        printInfo.isVerticallyCentered = true

        let printableSize = printInfo.imageablePageBounds.size
        let image = document.compositedImage.normalizedBitmapImage()
        guard let pageView = ImageEditorPrintPageView(
            image: image,
            printableSize: printableSize
        ) else {
            statusText = L10n.text("imageEditor.status.printFailed")
            return false
        }

        let didPrint = printRunner(pageView, printInfo)
        statusText = L10n.text(
            didPrint
                ? "imageEditor.status.printCompleted"
                : "imageEditor.status.printCancelled"
        )
        return didPrint
    }
}
