import Carbon
import CoreGraphics
import Foundation

final class HotKeyController {
    private let preferences: Preferences
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    var onTrigger: (() -> Void)?

    init(preferences: Preferences) {
        self.preferences = preferences
    }

    deinit {
        stop()
    }

    @discardableResult
    func refresh() -> Bool {
        unregisterHotKey()
        installHandlerIfNeeded()

        guard preferences.triggerKind == .keyboardShortcut,
              let shortcut = preferences.keyboardShortcut else {
            return false
        }

        let hotKeyID = EventHotKeyID(signature: fourCharCode("XTYB"), id: 1)
        var newHotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(shortcut.keyCode),
            carbonModifiers(from: shortcut.modifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &newHotKeyRef
        )

        guard status == noErr, let newHotKeyRef else {
            return false
        }

        hotKeyRef = newHotKeyRef
        return true
    }

    func stop() {
        unregisterHotKey()

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    private func installHandlerIfNeeded() {
        guard eventHandlerRef == nil else {
            return
        }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else {
                    return noErr
                }

                let controller = Unmanaged<HotKeyController>
                    .fromOpaque(userData)
                    .takeUnretainedValue()

                DispatchQueue.main.async {
                    controller.onTrigger?()
                }

                return noErr
            },
            1,
            &eventType,
            refcon,
            &eventHandlerRef
        )
    }

    private func unregisterHotKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func carbonModifiers(from flags: CGEventFlags) -> UInt32 {
        var modifiers: UInt32 = 0
        if flags.contains(.maskCommand) {
            modifiers |= UInt32(cmdKey)
        }
        if flags.contains(.maskAlternate) {
            modifiers |= UInt32(optionKey)
        }
        if flags.contains(.maskControl) {
            modifiers |= UInt32(controlKey)
        }
        if flags.contains(.maskShift) {
            modifiers |= UInt32(shiftKey)
        }
        return modifiers
    }

    private func fourCharCode(_ string: String) -> OSType {
        string.utf8.reduce(0) { result, character in
            (result << 8) + OSType(character)
        }
    }
}
