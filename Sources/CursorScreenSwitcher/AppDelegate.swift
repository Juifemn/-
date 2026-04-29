import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = Preferences()
    private let screenSwitcher = ScreenSwitcher()
    private let overlayWindow = FocusOverlayWindow()
    private lazy var eventTapController = EventTapController(preferences: preferences)
    private lazy var hotKeyController = HotKeyController(preferences: preferences)
    private lazy var hidMouseButtonController = HIDMouseButtonController(preferences: preferences)

    private var statusItem: NSStatusItem?
    private var permissionWindowController: PermissionWindowController?
    private var shortcutWindowController: ShortcutWindowController?
    private var lastEventTapStartSucceeded = false
    private var lastHotKeyStartSucceeded = false
    private var lastHIDStartSucceeded = false
    private var lastSwitchTime: CFTimeInterval = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureEventTap()
        configureHotKey()
        configureHIDMouseButtons()
        configureStatusItem()
        startMonitoring()

        preferences.didCompleteSetup = true
        if !hasAnyWorkingTriggerPath {
            showPermissionWindow()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        eventTapController.stop()
        hotKeyController.stop()
        hidMouseButtonController.stop()
    }

    private func configureEventTap() {
        eventTapController.onTrigger = { [weak self] in
            self?.performSwitch()
        }
        eventTapController.onStatusChanged = { [weak self] in
            self?.refreshMenu()
        }
    }

    private func configureHotKey() {
        hotKeyController.onTrigger = { [weak self] in
            self?.performSwitch()
        }
    }

    private func configureHIDMouseButtons() {
        hidMouseButtonController.onTrigger = { [weak self] in
            self?.performSwitch()
        }
        hidMouseButtonController.onStatusChanged = { [weak self] in
            self?.refreshMenu()
        }
    }

    private var hasAnyWorkingTriggerPath: Bool {
        switch preferences.triggerKind {
        case .mouseButton:
            return lastHIDStartSucceeded || lastEventTapStartSucceeded || eventTapController.isRunning
        case .doubleOption:
            return lastEventTapStartSucceeded || eventTapController.isRunning
        case .keyboardShortcut:
            return lastHotKeyStartSucceeded
        }
    }

    private var isMacMouseFixRunning: Bool {
        NSWorkspace.shared.runningApplications.contains { app in
            app.bundleIdentifier?.contains("mac-mouse-fix") == true
                || app.localizedName?.localizedCaseInsensitiveContains("Mac Mouse Fix") == true
        }
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            if let image = NSImage(systemSymbolName: "cursorarrow.motionlines", accessibilityDescription: "旋转跳跃我闭着眼") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "⌖"
            }
        }
        statusItem = item
        refreshMenu()
    }

    private func refreshMenu() {
        let menu = NSMenu()

        let titleItem = NSMenuItem(title: "旋转跳跃我闭着眼", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        let statusText: String
        if preferences.triggerKind == .keyboardShortcut, lastHotKeyStartSucceeded {
            statusText = "状态：已启用"
        } else if preferences.triggerKind == .mouseButton, lastHIDStartSucceeded {
            statusText = eventTapController.canInterceptEvents ? "状态：已启用" : "状态：已启用（不拦截原事件）"
        } else if preferences.triggerKind == .doubleOption, eventTapController.isRunning {
            statusText = eventTapController.canInterceptEvents ? "状态：已启用" : "状态：已启用（需要权限以提升可靠性）"
        } else if PermissionManager.canListenForGlobalInput {
            statusText = "状态：监听未启动"
        } else {
            statusText = "状态：等待输入监控权限"
        }
        let statusItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        let triggerItem = NSMenuItem(title: "快捷键：\(preferences.triggerDescription)", action: nil, keyEquivalent: "")
        triggerItem.isEnabled = false
        menu.addItem(triggerItem)

        if preferences.triggerKind == .mouseButton, isMacMouseFixRunning {
            let conflictItem = NSMenuItem(title: "提示：侧键可能被 Mac Mouse Fix 占用", action: nil, keyEquivalent: "")
            conflictItem.isEnabled = false
            menu.addItem(conflictItem)
        }

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "测试切换一次", action: #selector(testSwitchOnce), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "设置快捷键…", action: #selector(openShortcutSettings), keyEquivalent: ","))

        let doubleOptionItem = NSMenuItem(title: "双击 Option 切换", action: #selector(useDoubleOptionShortcut), keyEquivalent: "")
        doubleOptionItem.state = preferences.triggerKind == .doubleOption ? .on : .off
        menu.addItem(doubleOptionItem)

        let interceptItem = NSMenuItem(title: "拦截鼠标按钮原事件", action: #selector(toggleSideButtonInterception), keyEquivalent: "")
        interceptItem.state = preferences.interceptSideButton ? .on : .off
        menu.addItem(interceptItem)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "打开权限设置", action: #selector(openPermissionSettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "重新检测权限", action: #selector(recheckPermissions), keyEquivalent: ""))

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))

        menu.items.forEach { $0.target = self }
        self.statusItem?.menu = menu
    }

    private func startMonitoring() {
        lastHotKeyStartSucceeded = hotKeyController.refresh()
        lastHIDStartSucceeded = hidMouseButtonController.start()
        eventTapController.allowsMouseTriggers = !lastHIDStartSucceeded

        if PermissionManager.canListenForGlobalInput {
            lastEventTapStartSucceeded = eventTapController.start()
        } else {
            eventTapController.stop()
            lastEventTapStartSucceeded = false
        }

        refreshMenu()
    }

    private func performSwitch() {
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastSwitchTime > 0.15 else {
            return
        }
        lastSwitchTime = now

        let target = screenSwitcher.switchToNextScreenCenter()
        overlayWindow.show(at: target)
    }

    private func showPermissionWindow() {
        if permissionWindowController == nil {
            permissionWindowController = PermissionWindowController { [weak self] in
                guard let self else {
                    return .monitoringFailed
                }

                guard PermissionManager.canListenForGlobalInput else {
                    self.refreshMenu()
                    return .waitingForPermission
                }

                self.preferences.didCompleteSetup = true
                self.startMonitoring()

                if self.hasAnyWorkingTriggerPath {
                    self.permissionWindowController = nil
                    return .started
                } else {
                    NSSound.beep()
                    return .monitoringFailed
                }
            }
        }
        permissionWindowController?.show()
    }

    @objc private func openShortcutSettings() {
        showShortcutWindow()
    }

    private func showShortcutWindow() {
        if shortcutWindowController == nil {
            shortcutWindowController = ShortcutWindowController(
                onUseDefaultMouse: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.preferences.mouseHIDShortcut = nil
                    self.preferences.triggerKind = .mouseButton
                    self.startMonitoring()
                    self.refreshMenu()
                    self.shortcutWindowController?.update(currentShortcut: self.preferences.triggerDescription, isRecording: false)
                },
                onUseDoubleOption: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.preferences.triggerKind = .doubleOption
                    self.startMonitoring()
                    self.refreshMenu()
                    self.shortcutWindowController?.update(currentShortcut: self.preferences.triggerDescription, isRecording: false)
                },
                onStartRecording: { [weak self] in
                    self?.beginShortcutRecording()
                },
                onCancelRecording: { [weak self] in
                    self?.eventTapController.cancelShortcutCapture()
                    self?.hidMouseButtonController.cancelShortcutCapture()
                    self?.shortcutWindowController?.update(currentShortcut: self?.preferences.triggerDescription ?? "", isRecording: false)
                },
                onCapturedShortcut: { [weak self] shortcut in
                    guard let self else {
                        return
                    }
                    self.preferences.apply(shortcut)
                    self.startMonitoring()
                    self.refreshMenu()
                    self.shortcutWindowController?.update(currentShortcut: self.preferences.triggerDescription, isRecording: false)
                }
            )
        }

        shortcutWindowController?.show(currentShortcut: preferences.triggerDescription)
    }

    private func beginShortcutRecording() {
        shortcutWindowController?.update(currentShortcut: preferences.triggerDescription, isRecording: true)
        eventTapController.beginShortcutCapture { [weak self] shortcut in
            guard let self else {
                return
            }
            self.preferences.apply(shortcut)
            self.startMonitoring()
            self.refreshMenu()
            self.shortcutWindowController?.update(currentShortcut: self.preferences.triggerDescription, isRecording: false)
        }
        hidMouseButtonController.beginShortcutCapture { [weak self] shortcut in
            guard let self else {
                return
            }
            self.eventTapController.cancelShortcutCapture()
            self.preferences.apply(shortcut)
            self.startMonitoring()
            self.refreshMenu()
            self.shortcutWindowController?.update(currentShortcut: self.preferences.triggerDescription, isRecording: false)
        }
    }

    @objc private func useDoubleOptionShortcut() {
        preferences.triggerKind = .doubleOption
        startMonitoring()
        refreshMenu()
    }

    @objc private func testSwitchOnce() {
        performSwitch()
    }

    @objc private func toggleSideButtonInterception() {
        preferences.interceptSideButton.toggle()
        refreshMenu()
    }

    @objc private func openPermissionSettings() {
        PermissionManager.requestInputMonitoringAccess()
        PermissionManager.openPrivacySettings()
        showPermissionWindow()
    }

    @objc private func recheckPermissions() {
        preferences.didCompleteSetup = true
        startMonitoring()
        if !hasAnyWorkingTriggerPath {
            showPermissionWindow()
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
