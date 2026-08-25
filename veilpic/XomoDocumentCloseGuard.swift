//
//  XomoDocumentCloseGuard.swift
//  veilpic
//
//  Created by Codex on 2026/8/25.
//

import AppKit
import SwiftUI

enum XomoDocumentCloseGateAction: Equatable {
    case allow
    case requestConfirmation
}

struct XomoDocumentCloseGate {
    private(set) var allowsNextClose = false

    mutating func action(hasUnsavedChanges: Bool) -> XomoDocumentCloseGateAction {
        if allowsNextClose {
            allowsNextClose = false
            return .allow
        }
        return hasUnsavedChanges ? .requestConfirmation : .allow
    }

    mutating func approveNextClose() {
        allowsNextClose = true
    }

    mutating func cancelPendingApproval() {
        allowsNextClose = false
    }
}

@MainActor
enum XomoUnsavedDocumentCloseAlert {
    static func present(
        for window: NSWindow,
        viewModel: ImageEditorViewModel,
        completion: @escaping @MainActor (Bool) -> Void
    ) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L10n.text("imageEditor.confirmation.unsavedCloseTitle")
        alert.informativeText = L10n.format(
            "imageEditor.confirmation.unsavedCloseMessage",
            viewModel.document.sourceName
        )
        alert.addButton(withTitle: L10n.text("imageEditor.action.closeSave"))
        alert.addButton(withTitle: L10n.text("imageEditor.action.closeDiscard"))
        alert.addButton(withTitle: L10n.text("button.cancel"))

        alert.beginSheetModal(for: window) { response in
            Task { @MainActor in
                switch response {
                case .alertFirstButtonReturn:
                    viewModel.saveProjectDocument(completion: completion)
                case .alertSecondButtonReturn:
                    completion(true)
                default:
                    completion(false)
                }
            }
        }
    }
}

@MainActor
struct XomoDocumentTerminationCandidate {
    let window: NSWindow
    let viewModel: ImageEditorViewModel
}

@MainActor
final class XomoDocumentWindowRegistry {
    static let shared = XomoDocumentWindowRegistry()

    private final class Entry {
        weak var window: NSWindow?
        weak var viewModel: ImageEditorViewModel?

        init(window: NSWindow, viewModel: ImageEditorViewModel) {
            self.window = window
            self.viewModel = viewModel
        }
    }

    private var entries: [ObjectIdentifier: Entry] = [:]

    func register(window: NSWindow, viewModel: ImageEditorViewModel) {
        entries[ObjectIdentifier(window)] = Entry(window: window, viewModel: viewModel)
    }

    func unregister(window: NSWindow) {
        entries.removeValue(forKey: ObjectIdentifier(window))
    }

    var terminationCandidates: [XomoDocumentTerminationCandidate] {
        entries = entries.filter { _, entry in
            entry.window != nil && entry.viewModel != nil
        }
        return entries.values.compactMap { entry in
            guard let window = entry.window, let viewModel = entry.viewModel else { return nil }
            return XomoDocumentTerminationCandidate(window: window, viewModel: viewModel)
        }
    }

    func resetForTesting() {
        entries.removeAll()
    }
}

@MainActor
final class XomoApplicationTerminationCoordinator {
    typealias CandidateProvider = @MainActor () -> [XomoDocumentTerminationCandidate]
    typealias ConfirmationPresenter = @MainActor (
        XomoDocumentTerminationCandidate,
        @escaping @MainActor (Bool) -> Void
    ) -> Void

    private let candidateProvider: CandidateProvider
    private let confirmationPresenter: ConfirmationPresenter
    private var pendingCandidates: [XomoDocumentTerminationCandidate] = []
    private var replyHandler: (@MainActor (Bool) -> Void)?

    convenience init() {
        self.init(
            candidateProvider: {
                XomoDocumentWindowRegistry.shared.terminationCandidates
            },
            confirmationPresenter: { candidate, completion in
                XomoUnsavedDocumentCloseAlert.present(
                    for: candidate.window,
                    viewModel: candidate.viewModel,
                    completion: completion
                )
            }
        )
    }

    init(
        candidateProvider: @escaping CandidateProvider,
        confirmationPresenter: @escaping ConfirmationPresenter
    ) {
        self.candidateProvider = candidateProvider
        self.confirmationPresenter = confirmationPresenter
    }

    func requestTermination(
        reply: @escaping @MainActor (Bool) -> Void
    ) -> NSApplication.TerminateReply {
        guard replyHandler == nil else { return .terminateLater }
        let dirtyCandidates = candidateProvider().filter(\.viewModel.hasUnsavedProjectChanges)
        guard !dirtyCandidates.isEmpty else { return .terminateNow }

        pendingCandidates = dirtyCandidates
        replyHandler = reply
        presentNextConfirmation()
        return .terminateLater
    }

    private func presentNextConfirmation() {
        while let candidate = pendingCandidates.first {
            pendingCandidates.removeFirst()
            guard candidate.viewModel.hasUnsavedProjectChanges else { continue }
            confirmationPresenter(candidate) { [weak self] approved in
                self?.resolveCurrentConfirmation(approved: approved)
            }
            return
        }
        finish(shouldTerminate: true)
    }

    private func resolveCurrentConfirmation(approved: Bool) {
        guard approved else {
            pendingCandidates.removeAll()
            finish(shouldTerminate: false)
            return
        }
        presentNextConfirmation()
    }

    private func finish(shouldTerminate: Bool) {
        let reply = replyHandler
        replyHandler = nil
        pendingCandidates.removeAll()
        reply?(shouldTerminate)
    }
}

@MainActor
final class XomoDocumentCloseGuardCoordinator: NSObject, NSWindowDelegate {
    var viewModel: ImageEditorViewModel {
        didSet {
            if let window {
                XomoDocumentWindowRegistry.shared.register(window: window, viewModel: viewModel)
            }
        }
    }

    private weak var window: NSWindow?
    private var previousDelegate: (any NSWindowDelegate)?
    private var gate = XomoDocumentCloseGate()
    private var isPresentingConfirmation = false

    init(viewModel: ImageEditorViewModel) {
        self.viewModel = viewModel
    }

    func install(on window: NSWindow?) {
        guard self.window !== window else { return }
        uninstall()
        guard let window else { return }
        self.window = window
        previousDelegate = window.delegate
        window.delegate = self
        XomoDocumentWindowRegistry.shared.register(window: window, viewModel: viewModel)
    }

    func uninstall() {
        if let window {
            XomoDocumentWindowRegistry.shared.unregister(window: window)
        }
        if let window, window.delegate === self {
            window.delegate = previousDelegate
        }
        window = nil
        previousDelegate = nil
        isPresentingConfirmation = false
        gate.cancelPendingApproval()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        let previousAllowsClose = previousDelegate?.windowShouldClose?(sender) ?? true
        guard previousAllowsClose else { return false }

        switch gate.action(hasUnsavedChanges: viewModel.hasUnsavedProjectChanges) {
        case .allow:
            return true
        case .requestConfirmation:
            presentConfirmation(for: sender)
            return false
        }
    }

    override func responds(to selector: Selector!) -> Bool {
        super.responds(to: selector) || (previousDelegate?.responds(to: selector) ?? false)
    }

    override func forwardingTarget(for selector: Selector!) -> Any? {
        if previousDelegate?.responds(to: selector) == true {
            return previousDelegate
        }
        return super.forwardingTarget(for: selector)
    }

    private func presentConfirmation(for window: NSWindow) {
        guard !isPresentingConfirmation else { return }
        isPresentingConfirmation = true
        XomoUnsavedDocumentCloseAlert.present(
            for: window,
            viewModel: viewModel
        ) { [weak self, weak window] isApproved in
            guard let self else { return }
            self.isPresentingConfirmation = false
            guard isApproved, let window else {
                self.gate.cancelPendingApproval()
                return
            }
            self.gate.approveNextClose()
            window.performClose(nil)
        }
    }
}

private final class XomoDocumentCloseGuardNSView: NSView {
    weak var coordinator: XomoDocumentCloseGuardCoordinator?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        coordinator?.install(on: window)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

struct XomoDocumentCloseGuard: NSViewRepresentable {
    let viewModel: ImageEditorViewModel

    func makeCoordinator() -> XomoDocumentCloseGuardCoordinator {
        XomoDocumentCloseGuardCoordinator(viewModel: viewModel)
    }

    func makeNSView(context: Context) -> NSView {
        let view = XomoDocumentCloseGuardNSView(frame: .zero)
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.viewModel = viewModel
        context.coordinator.install(on: nsView.window)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: XomoDocumentCloseGuardCoordinator) {
        coordinator.uninstall()
    }
}
