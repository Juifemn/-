import Foundation
import IOKit.hid

final class HIDMouseButtonController {
    private let preferences: Preferences
    private var manager: IOHIDManager?
    private var lastTriggerTime: CFTimeInterval = 0
    private var pressedShortcuts = Set<HIDMouseShortcut>()
    private var shortcutCaptureHandler: ((CapturedShortcut) -> Void)?

    var onTrigger: (() -> Void)?
    var onStatusChanged: (() -> Void)?

    var isRunning: Bool {
        manager != nil
    }

    init(preferences: Preferences) {
        self.preferences = preferences
    }

    deinit {
        stop()
    }

    @discardableResult
    func start() -> Bool {
        stop()

        let newManager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matchMouse = [
            kIOHIDDeviceUsagePageKey as String: NSNumber(value: kHIDPage_GenericDesktop),
            kIOHIDDeviceUsageKey as String: NSNumber(value: kHIDUsage_GD_Mouse)
        ]
        let matchPointer = [
            kIOHIDDeviceUsagePageKey as String: NSNumber(value: kHIDPage_GenericDesktop),
            kIOHIDDeviceUsageKey as String: NSNumber(value: kHIDUsage_GD_Pointer)
        ]
        let matchKeyboard = [
            kIOHIDDeviceUsagePageKey as String: NSNumber(value: kHIDPage_GenericDesktop),
            kIOHIDDeviceUsageKey as String: NSNumber(value: kHIDUsage_GD_Keyboard)
        ]
        let matchConsumer = [
            kIOHIDDeviceUsagePageKey as String: NSNumber(value: kHIDPage_Consumer),
            kIOHIDDeviceUsageKey as String: NSNumber(value: kHIDUsage_Csmr_ConsumerControl)
        ]

        IOHIDManagerSetDeviceMatchingMultiple(newManager, [matchMouse, matchPointer, matchKeyboard, matchConsumer] as CFArray)

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterInputValueCallback(newManager, HIDMouseButtonController.inputValueCallback, refcon)
        IOHIDManagerScheduleWithRunLoop(newManager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)

        let openResult = IOHIDManagerOpen(newManager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard openResult == kIOReturnSuccess else {
            IOHIDManagerUnscheduleFromRunLoop(newManager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
            return false
        }

        manager = newManager
        onStatusChanged?()
        return true
    }

    func stop() {
        guard let manager else {
            return
        }

        pressedShortcuts.removeAll()
        shortcutCaptureHandler = nil
        IOHIDManagerRegisterInputValueCallback(manager, nil, nil)
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = nil
        onStatusChanged?()
    }

    func beginShortcutCapture(_ handler: @escaping (CapturedShortcut) -> Void) {
        shortcutCaptureHandler = handler
    }

    func cancelShortcutCapture() {
        shortcutCaptureHandler = nil
    }

    private func handle(value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        let usagePage = Int64(IOHIDElementGetUsagePage(element))
        let usage = Int64(IOHIDElementGetUsage(element))
        let shortcut = HIDMouseShortcut(usagePage: usagePage, usage: usage)
        let integerValue = IOHIDValueGetIntegerValue(value)

        if integerValue == 0 {
            pressedShortcuts.remove(shortcut)
            return
        }

        guard isMouseLikeShortcut(shortcut, element: element),
              !pressedShortcuts.contains(shortcut) else {
            return
        }
        pressedShortcuts.insert(shortcut)

        if let shortcutCaptureHandler {
            self.shortcutCaptureHandler = nil
            DispatchQueue.main.async {
                shortcutCaptureHandler(.hidMouseShortcut(shortcut))
            }
            return
        }

        guard preferences.triggerKind == .mouseButton,
              isTriggerMouseShortcut(shortcut) else {
            return
        }

        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastTriggerTime > 0.20 else {
            return
        }
        lastTriggerTime = now

        if preferences.mouseHIDShortcut == nil {
            preferences.mouseHIDShortcut = shortcut
            onStatusChanged?()
        }

        onTrigger?()
    }

    private func isTriggerMouseShortcut(_ shortcut: HIDMouseShortcut) -> Bool {
        if let configured = preferences.mouseHIDShortcut {
            return configured == shortcut
        }

        if let configured = preferences.mouseButtonNumber {
            return shortcut.usagePage == Int64(kHIDPage_Button) && shortcut.usage == configured
        }

        return isDefaultMouseTrigger(shortcut)
    }

    private func isMouseLikeShortcut(_ shortcut: HIDMouseShortcut, element: IOHIDElement) -> Bool {
        switch Int(shortcut.usagePage) {
        case kHIDPage_Button:
            return shortcut.usage >= 3 && !isInternalAppleTrackpad(element: element)

        case kHIDPage_Consumer:
            return Self.consumerNavigationUsages.contains(shortcut.usage)

        default:
            return false
        }
    }

    private func isDefaultMouseTrigger(_ shortcut: HIDMouseShortcut) -> Bool {
        switch Int(shortcut.usagePage) {
        case kHIDPage_Button:
            return shortcut.usage >= 3

        case kHIDPage_Consumer:
            return Self.consumerNavigationUsages.contains(shortcut.usage)

        default:
            return false
        }
    }

    private func isInternalAppleTrackpad(element: IOHIDElement) -> Bool {
        let device = IOHIDElementGetDevice(element)
        guard let product = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String else {
            return false
        }

        return product.localizedCaseInsensitiveContains("internal")
            && product.localizedCaseInsensitiveContains("trackpad")
    }

    private static let consumerNavigationUsages: Set<Int64> = [
        0x224, // AC Back
        0x225  // AC Forward
    ]

    private static let inputValueCallback: IOHIDValueCallback = { context, _, _, value in
        guard let context else {
            return
        }

        let controller = Unmanaged<HIDMouseButtonController>
            .fromOpaque(context)
            .takeUnretainedValue()

        controller.handle(value: value)
    }
}
