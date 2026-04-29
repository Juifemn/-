import ApplicationServices
import AppKit

enum PermissionManager {
    static var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    static var isInputMonitoringTrusted: Bool {
        CGPreflightListenEventAccess()
    }

    static var canListenForGlobalInput: Bool {
        isInputMonitoringTrusted
    }

    @discardableResult
    static func requestAccessibilityAccess() -> Bool {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    @discardableResult
    static func requestInputMonitoringAccess() -> Bool {
        CGRequestListenEventAccess()
    }

    static func openPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
