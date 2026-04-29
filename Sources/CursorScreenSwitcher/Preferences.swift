import CoreGraphics
import Foundation
import IOKit.hid

enum TriggerKind: String {
    case mouseButton
    case doubleOption
    case keyboardShortcut
}

struct KeyboardShortcut {
    let keyCode: Int64
    let modifiers: CGEventFlags
}

struct HIDMouseShortcut: Hashable {
    let usagePage: Int64
    let usage: Int64
}

enum CapturedShortcut {
    case mouseButton(Int64)
    case hidMouseShortcut(HIDMouseShortcut)
    case doubleOption
    case keyboardShortcut(KeyboardShortcut)
}

final class Preferences {
    private enum Key {
        static let didCompleteSetup = "didCompleteSetup"
        static let triggerKind = "triggerKind"
        static let mouseButtonNumber = "mouseButtonNumber"
        static let mouseUsagePage = "mouseUsagePage"
        static let mouseUsage = "mouseUsage"
        static let doubleOptionEnabled = "doubleOptionEnabled"
        static let interceptSideButton = "interceptSideButton"
        static let keyboardKeyCode = "keyboardKeyCode"
        static let keyboardModifiers = "keyboardModifiers"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.triggerKind: TriggerKind.mouseButton.rawValue,
            Key.doubleOptionEnabled: true,
            Key.interceptSideButton: true
        ])
    }

    var didCompleteSetup: Bool {
        get { defaults.bool(forKey: Key.didCompleteSetup) }
        set { defaults.set(newValue, forKey: Key.didCompleteSetup) }
    }

    var triggerKind: TriggerKind {
        get {
            if let raw = defaults.string(forKey: Key.triggerKind),
               let kind = TriggerKind(rawValue: raw) {
                return kind
            }
            return .mouseButton
        }
        set { defaults.set(newValue.rawValue, forKey: Key.triggerKind) }
    }

    var mouseButtonNumber: Int64? {
        get {
            guard defaults.object(forKey: Key.mouseButtonNumber) != nil else {
                return nil
            }
            return Int64(defaults.integer(forKey: Key.mouseButtonNumber))
        }
        set {
            if let newValue {
                defaults.set(Int(newValue), forKey: Key.mouseButtonNumber)
            } else {
                defaults.removeObject(forKey: Key.mouseButtonNumber)
            }
        }
    }

    var mouseHIDShortcut: HIDMouseShortcut? {
        get {
            guard defaults.object(forKey: Key.mouseUsagePage) != nil,
                  defaults.object(forKey: Key.mouseUsage) != nil else {
                return nil
            }
            return HIDMouseShortcut(
                usagePage: Int64(defaults.integer(forKey: Key.mouseUsagePage)),
                usage: Int64(defaults.integer(forKey: Key.mouseUsage))
            )
        }
        set {
            if let newValue {
                defaults.set(Int(newValue.usagePage), forKey: Key.mouseUsagePage)
                defaults.set(Int(newValue.usage), forKey: Key.mouseUsage)
                if newValue.usagePage == Int64(kHIDPage_Button) {
                    mouseButtonNumber = newValue.usage
                }
            } else {
                defaults.removeObject(forKey: Key.mouseUsagePage)
                defaults.removeObject(forKey: Key.mouseUsage)
                mouseButtonNumber = nil
            }
        }
    }

    var doubleOptionEnabled: Bool {
        get { defaults.bool(forKey: Key.doubleOptionEnabled) }
        set {
            defaults.set(newValue, forKey: Key.doubleOptionEnabled)
            if newValue {
                triggerKind = .doubleOption
            } else if triggerKind == .doubleOption {
                triggerKind = .mouseButton
            }
        }
    }

    var interceptSideButton: Bool {
        get { defaults.bool(forKey: Key.interceptSideButton) }
        set { defaults.set(newValue, forKey: Key.interceptSideButton) }
    }

    var keyboardShortcut: KeyboardShortcut? {
        get {
            guard defaults.object(forKey: Key.keyboardKeyCode) != nil,
                  defaults.object(forKey: Key.keyboardModifiers) != nil else {
                return nil
            }
            return KeyboardShortcut(
                keyCode: Int64(defaults.integer(forKey: Key.keyboardKeyCode)),
                modifiers: CGEventFlags(rawValue: UInt64(defaults.integer(forKey: Key.keyboardModifiers)))
            )
        }
        set {
            if let newValue {
                defaults.set(Int(newValue.keyCode), forKey: Key.keyboardKeyCode)
                defaults.set(Int(newValue.modifiers.rawValue), forKey: Key.keyboardModifiers)
            } else {
                defaults.removeObject(forKey: Key.keyboardKeyCode)
                defaults.removeObject(forKey: Key.keyboardModifiers)
            }
        }
    }

    func apply(_ capturedShortcut: CapturedShortcut) {
        switch capturedShortcut {
        case .mouseButton(let buttonNumber):
            mouseButtonNumber = buttonNumber
            mouseHIDShortcut = HIDMouseShortcut(usagePage: Int64(kHIDPage_Button), usage: buttonNumber)
            triggerKind = .mouseButton

        case .hidMouseShortcut(let shortcut):
            mouseHIDShortcut = shortcut
            triggerKind = .mouseButton

        case .doubleOption:
            triggerKind = .doubleOption

        case .keyboardShortcut(let shortcut):
            keyboardShortcut = shortcut
            triggerKind = .keyboardShortcut
        }
    }

    var triggerDescription: String {
        switch triggerKind {
        case .mouseButton:
            if let mouseHIDShortcut {
                return Self.hidMouseShortcutDescription(mouseHIDShortcut)
            }
            if let mouseButtonNumber {
                return Self.mouseButtonDescription(mouseButtonNumber)
            }
            return "鼠标侧键"

        case .doubleOption:
            return "双击 Option"

        case .keyboardShortcut:
            guard let keyboardShortcut else {
                return "未设置键盘快捷键"
            }
            return Self.keyboardShortcutDescription(keyboardShortcut)
        }
    }

    static func mouseButtonDescription(_ buttonNumber: Int64) -> String {
        if buttonNumber >= 2 {
            return "鼠标按钮 \(buttonNumber)"
        }
        return "鼠标按钮 \(buttonNumber)"
    }

    static func hidMouseShortcutDescription(_ shortcut: HIDMouseShortcut) -> String {
        if shortcut.usagePage == Int64(kHIDPage_Button) {
            return mouseButtonDescription(shortcut.usage)
        }

        if shortcut.usagePage == Int64(kHIDPage_Consumer) {
            switch shortcut.usage {
            case 0x224: return "鼠标后退键"
            case 0x225: return "鼠标前进键"
            default: return "鼠标功能键 \(shortcut.usage)"
            }
        }

        return "鼠标按键 \(shortcut.usagePage):\(shortcut.usage)"
    }

    static func keyboardShortcutDescription(_ shortcut: KeyboardShortcut) -> String {
        var parts: [String] = []
        if shortcut.modifiers.contains(.maskCommand) {
            parts.append("⌘")
        }
        if shortcut.modifiers.contains(.maskAlternate) {
            parts.append("⌥")
        }
        if shortcut.modifiers.contains(.maskControl) {
            parts.append("⌃")
        }
        if shortcut.modifiers.contains(.maskShift) {
            parts.append("⇧")
        }
        parts.append(keyName(shortcut.keyCode))
        return parts.joined(separator: " ")
    }

    static func normalizedKeyboardModifiers(_ flags: CGEventFlags) -> CGEventFlags {
        CGEventFlags(rawValue: flags.rawValue & (
            CGEventFlags.maskCommand.rawValue
                | CGEventFlags.maskAlternate.rawValue
                | CGEventFlags.maskControl.rawValue
                | CGEventFlags.maskShift.rawValue
        ))
    }

    private static func keyName(_ keyCode: Int64) -> String {
        switch keyCode {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "O"
        case 32: return "U"
        case 33: return "["
        case 34: return "I"
        case 35: return "P"
        case 37: return "L"
        case 38: return "J"
        case 39: return "'"
        case 40: return "K"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        case 49: return "Space"
        case 50: return "`"
        case 53: return "Esc"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 99: return "F3"
        case 100: return "F8"
        case 101: return "F9"
        case 103: return "F11"
        case 109: return "F10"
        case 111: return "F12"
        case 118: return "F4"
        case 120: return "F2"
        case 122: return "F1"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default: return "Key \(keyCode)"
        }
    }
}
