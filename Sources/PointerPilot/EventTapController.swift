import AppKit
import CoreGraphics
import QuartzCore

final class EventTapController {
    private let preferences: Preferences
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var globalMonitors: [Any] = []
    private var lastOptionDownTime: CFTimeInterval = 0
    private var optionWasDown = false
    private var shortcutCaptureHandler: ((CapturedShortcut) -> Void)?

    var onTrigger: (() -> Void)?
    var onStatusChanged: (() -> Void)?

    var isRunning: Bool {
        eventTap != nil || !globalMonitors.isEmpty
    }

    var canInterceptEvents: Bool {
        eventTap != nil
    }

    var allowsMouseTriggers = true

    init(preferences: Preferences) {
        self.preferences = preferences
    }

    func start() -> Bool {
        stop()

        let mask = (CGEventMask(1) << CGEventType.otherMouseDown.rawValue)
            | (CGEventMask(1) << CGEventType.keyDown.rawValue)
            | (CGEventMask(1) << CGEventType.flagsChanged.rawValue)

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        if let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: EventTapController.eventCallback,
            userInfo: refcon
        ), let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) {
            eventTap = tap
            runLoopSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            onStatusChanged?()
            return true
        }

        startGlobalMonitorFallback()
        return isRunning
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }

        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        runLoopSource = nil
        eventTap = nil

        for monitor in globalMonitors {
            NSEvent.removeMonitor(monitor)
        }
        globalMonitors.removeAll()
        onStatusChanged?()
    }

    func beginShortcutCapture(_ handler: @escaping (CapturedShortcut) -> Void) {
        shortcutCaptureHandler = handler
    }

    func cancelShortcutCapture() {
        shortcutCaptureHandler = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)

        case .otherMouseDown:
            return handleMouseDown(type: type, event: event)

        case .keyDown:
            return handleKeyDown(event)

        case .flagsChanged:
            handleFlagsChanged(event)
            return Unmanaged.passUnretained(event)

        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func startGlobalMonitorFallback() {
        let mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.otherMouseDown]) { [weak self] event in
            self?.handleGlobalMouseDown(event)
        }
        let keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            self?.handleGlobalKeyDown(event)
        }
        let flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handleGlobalFlagsChanged(event)
        }

        globalMonitors = [mouseMonitor, keyMonitor, flagsMonitor].compactMap { $0 }
        onStatusChanged?()
    }

    private func handleGlobalMouseDown(_ event: NSEvent) {
        let buttonNumber = Int64(event.buttonNumber + 1)

        if let shortcutCaptureHandler {
            self.shortcutCaptureHandler = nil
            shortcutCaptureHandler(.mouseButton(buttonNumber))
            return
        }

        guard allowsMouseTriggers else {
            return
        }

        guard preferences.triggerKind == .mouseButton,
              isTriggerMouseButton(buttonNumber) else {
            return
        }

        if preferences.mouseButtonNumber == nil {
            preferences.mouseButtonNumber = buttonNumber
            onStatusChanged?()
        }
        onTrigger?()
    }

    private func handleGlobalKeyDown(_ event: NSEvent) {
        let shortcut = KeyboardShortcut(
            keyCode: Int64(event.keyCode),
            modifiers: Preferences.normalizedKeyboardModifiers(CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue)))
        )

        if let shortcutCaptureHandler {
            self.shortcutCaptureHandler = nil
            shortcutCaptureHandler(.keyboardShortcut(shortcut))
            return
        }

        guard preferences.triggerKind == .keyboardShortcut,
              let configured = preferences.keyboardShortcut,
              configured.keyCode == shortcut.keyCode,
              configured.modifiers.rawValue == shortcut.modifiers.rawValue else {
            return
        }

        onTrigger?()
    }

    private func handleGlobalFlagsChanged(_ event: NSEvent) {
        let flags = CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue))
        handleOptionChange(optionIsDown: flags.contains(.maskAlternate))
    }

    private func handleMouseDown(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let buttonNumber = mouseButtonNumber(type: type, event: event)

        if let shortcutCaptureHandler {
            self.shortcutCaptureHandler = nil
            DispatchQueue.main.async {
                shortcutCaptureHandler(.mouseButton(buttonNumber))
            }
            return nil
        }

        guard allowsMouseTriggers else {
            if preferences.triggerKind == .mouseButton,
               preferences.interceptSideButton,
               isTriggerMouseButton(buttonNumber) {
                return nil
            }
            return Unmanaged.passUnretained(event)
        }

        guard preferences.triggerKind == .mouseButton,
              isTriggerMouseButton(buttonNumber) else {
            return Unmanaged.passUnretained(event)
        }

        if preferences.mouseButtonNumber == nil {
            preferences.mouseButtonNumber = buttonNumber
            DispatchQueue.main.async { [weak self] in
                self?.onStatusChanged?()
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.onTrigger?()
        }

        if preferences.interceptSideButton {
            return nil
        }
        return Unmanaged.passUnretained(event)
    }

    private func handleKeyDown(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let shortcut = KeyboardShortcut(
            keyCode: event.getIntegerValueField(.keyboardEventKeycode),
            modifiers: Preferences.normalizedKeyboardModifiers(event.flags)
        )

        if let shortcutCaptureHandler {
            self.shortcutCaptureHandler = nil
            DispatchQueue.main.async {
                shortcutCaptureHandler(.keyboardShortcut(shortcut))
            }
            return nil
        }

        guard preferences.triggerKind == .keyboardShortcut,
              let configured = preferences.keyboardShortcut,
              configured.keyCode == shortcut.keyCode,
              configured.modifiers.rawValue == shortcut.modifiers.rawValue else {
            return Unmanaged.passUnretained(event)
        }

        DispatchQueue.main.async { [weak self] in
            self?.onTrigger?()
        }
        return nil
    }

    private func mouseButtonNumber(type: CGEventType, event: CGEvent) -> Int64 {
        switch type {
        case .leftMouseDown:
            return 1
        case .rightMouseDown:
            return 2
        default:
            return event.getIntegerValueField(.mouseEventButtonNumber) + 1
        }
    }

    private func isTriggerMouseButton(_ buttonNumber: Int64) -> Bool {
        if let configured = preferences.mouseButtonNumber {
            return buttonNumber == configured
        }

        return buttonNumber >= 3
    }

    private func handleFlagsChanged(_ event: CGEvent) {
        guard preferences.triggerKind == .doubleOption else {
            return
        }

        handleOptionChange(optionIsDown: event.flags.contains(.maskAlternate))
    }

    private func handleOptionChange(optionIsDown: Bool) {
        guard preferences.triggerKind == .doubleOption else {
            return
        }

        defer {
            optionWasDown = optionIsDown
        }

        guard optionIsDown, !optionWasDown else {
            return
        }

        let now = CACurrentMediaTime()
        if now - lastOptionDownTime <= 0.38 {
            lastOptionDownTime = 0
            DispatchQueue.main.async { [weak self] in
                self?.onTrigger?()
            }
        } else {
            lastOptionDownTime = now
        }
    }

    private static let eventCallback: CGEventTapCallBack = { _, type, event, refcon in
        guard let refcon else {
            return Unmanaged.passUnretained(event)
        }

        let controller = Unmanaged<EventTapController>
            .fromOpaque(refcon)
            .takeUnretainedValue()

        return controller.handle(type: type, event: event)
    }
}
