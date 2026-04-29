import AppKit

enum PermissionStartResult {
    case started
    case waitingForPermission
    case monitoringFailed
}

final class PermissionWindowController: NSWindowController {
    private let statusLabel = NSTextField(labelWithString: "")
    private let openButton = NSButton(title: "打开输入监控设置", target: nil, action: nil)
    private let startButton = NSButton(title: "重新检测", target: nil, action: nil)
    private var pollTimer: Timer?
    private let onStart: () -> PermissionStartResult

    init(onStart: @escaping () -> PermissionStartResult) {
        self.onStart = onStart

        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 460, height: 236),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "旋转跳跃我闭着眼"
        window.center()

        super.init(window: window)

        window.delegate = self
        buildContent()
        updateStatus()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func show() {
        updateStatus()
        startPolling()
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildContent() {
        guard let contentView = window?.contentView else {
            return
        }

        let titleLabel = NSTextField(labelWithString: "启用侧键监听")
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let detailLabel = NSTextField(wrappingLabelWithString: "使用鼠标侧键或双击 Option 时，需要允许输入监控权限。键盘组合快捷键不需要此权限。")
        detailLabel.font = .systemFont(ofSize: 13)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.alignment = .center
        detailLabel.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.font = .systemFont(ofSize: 13, weight: .medium)
        statusLabel.alignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        openButton.target = self
        openButton.action = #selector(openSettings)
        openButton.bezelStyle = .rounded
        openButton.translatesAutoresizingMaskIntoConstraints = false

        startButton.target = self
        startButton.action = #selector(startUsing)
        startButton.bezelStyle = .rounded
        startButton.keyEquivalent = "\r"
        startButton.translatesAutoresizingMaskIntoConstraints = false

        let buttonStack = NSStackView(views: [openButton, startButton])
        buttonStack.orientation = .horizontal
        buttonStack.alignment = .centerY
        buttonStack.distribution = .gravityAreas
        buttonStack.spacing = 12
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(titleLabel)
        contentView.addSubview(detailLabel)
        contentView.addSubview(statusLabel)
        contentView.addSubview(buttonStack)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 28),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),

            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 18),
            detailLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 36),
            detailLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -36),

            statusLabel.topAnchor.constraint(equalTo: detailLabel.bottomAnchor, constant: 18),
            statusLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            statusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),

            buttonStack.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 18),
            buttonStack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor)
        ])
    }

    private func updateStatus() {
        if PermissionManager.canListenForGlobalInput {
            statusLabel.stringValue = "已检测到权限。"
            statusLabel.textColor = .systemGreen
            startButton.title = "开始使用"
        } else {
            statusLabel.stringValue = "请在“输入监控”中允许此应用。"
            statusLabel.textColor = .systemOrange
            startButton.title = "重新检测"
        }
    }

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            self?.updateStatus()
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    @objc private func openSettings() {
        PermissionManager.requestInputMonitoringAccess()
        PermissionManager.openPrivacySettings()
        updateStatus()
    }

    @objc private func startUsing() {
        updateStatus()
        switch onStart() {
        case .started:
            stopPolling()
            close()

        case .waitingForPermission:
            statusLabel.stringValue = "还没有检测到输入监控权限。允许后请再点一次。"
            statusLabel.textColor = .systemOrange

        case .monitoringFailed:
            statusLabel.stringValue = "已授权，但监听没有启动。请退出应用后重新打开。"
            statusLabel.textColor = .systemRed
        }
    }
}

extension PermissionWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        stopPolling()
    }
}
