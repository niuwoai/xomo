//
//  ScreenshotShortcuts.swift
//  veilpic
//
//  Created by Codex on 2026/6/30.
//

import AppKit
import Carbon
import Combine

enum ScreenshotShortcutKey: String, CaseIterable, Identifiable {
    case keyA = "A"
    case keyB = "B"
    case keyC = "C"
    case keyD = "D"
    case keyE = "E"
    case keyF = "F"
    case keyG = "G"
    case keyH = "H"
    case keyI = "I"
    case keyJ = "J"
    case keyK = "K"
    case keyL = "L"
    case keyM = "M"
    case keyN = "N"
    case keyO = "O"
    case keyP = "P"
    case keyQ = "Q"
    case keyR = "R"
    case keyS = "S"
    case keyT = "T"
    case keyU = "U"
    case keyV = "V"
    case keyW = "W"
    case keyX = "X"
    case keyY = "Y"
    case keyZ = "Z"
    case key0 = "0"
    case key1 = "1"
    case key2 = "2"
    case key3 = "3"
    case key4 = "4"
    case key5 = "5"
    case key6 = "6"
    case key7 = "7"
    case key8 = "8"
    case key9 = "9"

    var id: String { rawValue }

    var code: UInt16 {
        switch self {
        case .keyA:
            return UInt16(kVK_ANSI_A)
        case .keyB:
            return UInt16(kVK_ANSI_B)
        case .keyC:
            return UInt16(kVK_ANSI_C)
        case .keyD:
            return UInt16(kVK_ANSI_D)
        case .keyE:
            return UInt16(kVK_ANSI_E)
        case .keyF:
            return UInt16(kVK_ANSI_F)
        case .keyG:
            return UInt16(kVK_ANSI_G)
        case .keyH:
            return UInt16(kVK_ANSI_H)
        case .keyI:
            return UInt16(kVK_ANSI_I)
        case .keyJ:
            return UInt16(kVK_ANSI_J)
        case .keyK:
            return UInt16(kVK_ANSI_K)
        case .keyL:
            return UInt16(kVK_ANSI_L)
        case .keyM:
            return UInt16(kVK_ANSI_M)
        case .keyN:
            return UInt16(kVK_ANSI_N)
        case .keyO:
            return UInt16(kVK_ANSI_O)
        case .keyP:
            return UInt16(kVK_ANSI_P)
        case .keyQ:
            return UInt16(kVK_ANSI_Q)
        case .keyR:
            return UInt16(kVK_ANSI_R)
        case .keyS:
            return UInt16(kVK_ANSI_S)
        case .keyT:
            return UInt16(kVK_ANSI_T)
        case .keyU:
            return UInt16(kVK_ANSI_U)
        case .keyV:
            return UInt16(kVK_ANSI_V)
        case .keyW:
            return UInt16(kVK_ANSI_W)
        case .keyX:
            return UInt16(kVK_ANSI_X)
        case .keyY:
            return UInt16(kVK_ANSI_Y)
        case .keyZ:
            return UInt16(kVK_ANSI_Z)
        case .key0:
            return UInt16(kVK_ANSI_0)
        case .key1:
            return UInt16(kVK_ANSI_1)
        case .key2:
            return UInt16(kVK_ANSI_2)
        case .key3:
            return UInt16(kVK_ANSI_3)
        case .key4:
            return UInt16(kVK_ANSI_4)
        case .key5:
            return UInt16(kVK_ANSI_5)
        case .key6:
            return UInt16(kVK_ANSI_6)
        case .key7:
            return UInt16(kVK_ANSI_7)
        case .key8:
            return UInt16(kVK_ANSI_8)
        case .key9:
            return UInt16(kVK_ANSI_9)
        }
    }
}

struct ScreenshotKeyboardShortcut: Equatable {
    static let allowedModifiers: NSEvent.ModifierFlags = [.control, .option, .shift, .command]

    let key: ScreenshotShortcutKey
    let modifiers: NSEvent.ModifierFlags

    static let defaultFullScreen = ScreenshotKeyboardShortcut(
        key: .key3,
        modifiers: [.control, .shift, .command]
    )

    static let defaultRegion = ScreenshotKeyboardShortcut(
        key: .key9,
        modifiers: [.shift, .command]
    )

    var displayText: String {
        "\(modifierText)\(key.rawValue)"
    }

    var normalizedModifiers: NSEvent.ModifierFlags {
        modifiers.intersection(Self.allowedModifiers)
    }

    var carbonModifiers: UInt32 {
        var result: UInt32 = 0
        if normalizedModifiers.contains(.control) {
            result |= UInt32(controlKey)
        }
        if normalizedModifiers.contains(.option) {
            result |= UInt32(optionKey)
        }
        if normalizedModifiers.contains(.shift) {
            result |= UInt32(shiftKey)
        }
        if normalizedModifiers.contains(.command) {
            result |= UInt32(cmdKey)
        }
        return result
    }

    private var modifierText: String {
        var symbols: [String] = []
        if normalizedModifiers.contains(.control) {
            symbols.append("⌃")
        }
        if normalizedModifiers.contains(.option) {
            symbols.append("⌥")
        }
        if normalizedModifiers.contains(.shift) {
            symbols.append("⇧")
        }
        if normalizedModifiers.contains(.command) {
            symbols.append("⌘")
        }
        return symbols.joined()
    }
}

@MainActor
final class ScreenshotShortcutSettings: ObservableObject {
    static let shared = ScreenshotShortcutSettings()

    @Published var fullScreenShortcut: ScreenshotKeyboardShortcut = .defaultFullScreen {
        didSet { persistAndReloadIfNeeded() }
    }
    @Published var regionShortcut: ScreenshotKeyboardShortcut = .defaultRegion {
        didSet { persistAndReloadIfNeeded() }
    }

    private var isLoading = true

    private init() {
        fullScreenShortcut = loadShortcut(prefix: "screenshot.shortcut.fullscreen", defaultValue: .defaultFullScreen)
        regionShortcut = loadShortcut(prefix: "screenshot.shortcut.region", defaultValue: .defaultRegion)
        isLoading = false
    }

    func resetToDefaults() {
        fullScreenShortcut = .defaultFullScreen
        regionShortcut = .defaultRegion
    }

    private func persistAndReloadIfNeeded() {
        guard !isLoading else { return }
        saveShortcut(fullScreenShortcut, prefix: "screenshot.shortcut.fullscreen")
        saveShortcut(regionShortcut, prefix: "screenshot.shortcut.region")
        GlobalScreenshotShortcutManager.shared.reload(viewModel: .shared)
    }

    private func loadShortcut(prefix: String, defaultValue: ScreenshotKeyboardShortcut) -> ScreenshotKeyboardShortcut {
        let defaults = UserDefaults.standard
        guard let keyRaw = defaults.string(forKey: "\(prefix).key"),
              let key = ScreenshotShortcutKey(rawValue: keyRaw),
              defaults.object(forKey: "\(prefix).modifiers") != nil
        else {
            return defaultValue
        }

        let rawModifiers = UInt(defaults.integer(forKey: "\(prefix).modifiers"))
        var modifiers = NSEvent.ModifierFlags(rawValue: rawModifiers)
            .intersection(ScreenshotKeyboardShortcut.allowedModifiers)
        if modifiers.isEmpty {
            modifiers = defaultValue.normalizedModifiers
        }
        return ScreenshotKeyboardShortcut(key: key, modifiers: modifiers)
    }

    private func saveShortcut(_ shortcut: ScreenshotKeyboardShortcut, prefix: String) {
        let defaults = UserDefaults.standard
        defaults.set(shortcut.key.rawValue, forKey: "\(prefix).key")
        defaults.set(Int(shortcut.normalizedModifiers.rawValue), forKey: "\(prefix).modifiers")
    }
}

@MainActor
final class GlobalScreenshotShortcutManager {
    static let shared = GlobalScreenshotShortcutManager()

    private enum ShortcutID {
        static let fullScreen: UInt32 = 1
        static let region: UInt32 = 2
    }

    private var hotKeys: [UInt32: EventHotKeyRef] = [:]
    private var isSetup = false

    private init() {}

    func setup(viewModel: MenuBarUploadViewModel) {
        guard !isSetup else { return }

        ScreenshotHotKeyCallbackRegistry.shared.installIfNeeded()
        let settings = ScreenshotShortcutSettings.shared
        register(
            id: ShortcutID.fullScreen,
            shortcut: settings.fullScreenShortcut
        ) {
            viewModel.captureFullScreenToWorkspace(revealWhenDone: true)
        }
        register(
            id: ShortcutID.region,
            shortcut: settings.regionShortcut
        ) {
            viewModel.captureRegionToWorkspace(revealWhenDone: true)
        }

        isSetup = true
    }

    func reload(viewModel: MenuBarUploadViewModel) {
        guard isSetup else { return }
        unregisterAll()
        setup(viewModel: viewModel)
    }

    func unregisterAll() {
        for (_, ref) in hotKeys {
            UnregisterEventHotKey(ref)
        }
        hotKeys.removeAll()
        ScreenshotHotKeyCallbackRegistry.shared.removeAllCallbacks()
        isSetup = false
    }

    private func register(
        id: UInt32,
        shortcut: ScreenshotKeyboardShortcut,
        action: @escaping @MainActor () -> Void
    ) {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
        let status = RegisterEventHotKey(
            UInt32(shortcut.key.code),
            shortcut.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr, let hotKeyRef else { return }
        hotKeys[id] = hotKeyRef
        ScreenshotHotKeyCallbackRegistry.shared.setCallback(id: id, action: action)
    }

    private static let signature = fourCharCode("QTSH")

    private static func fourCharCode(_ string: String) -> OSType {
        var result: OSType = 0
        for scalar in string.unicodeScalars.prefix(4) {
            result = (result << 8) + OSType(scalar.value)
        }
        return result
    }
}

@MainActor
private final class ScreenshotHotKeyCallbackRegistry {
    static let shared = ScreenshotHotKeyCallbackRegistry()

    private var callbacks: [UInt32: @MainActor () -> Void] = [:]
    private var eventHandler: EventHandlerRef?

    private init() {}

    func installIfNeeded() {
        guard eventHandler == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let callback: EventHandlerUPP = { _, event, _ in
            guard let event else { return noErr }

            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )

            guard status == noErr else { return status }
            let id = hotKeyID.id
            DispatchQueue.main.async {
                Task { @MainActor in
                    ScreenshotHotKeyCallbackRegistry.shared.executeCallback(for: id)
                }
            }
            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            nil,
            &eventHandler
        )
    }

    func setCallback(id: UInt32, action: @escaping @MainActor () -> Void) {
        callbacks[id] = action
    }

    func removeAllCallbacks() {
        callbacks.removeAll()
    }

    private func executeCallback(for id: UInt32) {
        callbacks[id]?()
    }
}
