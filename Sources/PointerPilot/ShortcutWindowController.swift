import AppKit

final class ShortcutWindowController: NSWindowController {
    private let currentLabel = NSTextField(labelWithString: "")
    private let captureTitleLabel = NSTextField(labelWithString: "+")
    private let captureHintLabel = NSTextField(labelWithString: "")
    private let recordButton = NSButton(title: "录制快捷键", target: nil, action: nil)
    private lazy var recorderView = ShortcutRecorderView { [weak self] shortcut in
        self?.finishLocalRecording(shortcut)
    }

    private let onUseDefaultMouse: () -> Void
    private let onUseDoubleOption: () -> Void
    private let onStartRecording: () -> Void
    private let onCancelRecording: () -> Void
    private let onCapturedShortcut: (CapturedShortcut) -> Void

    init(
        onUseDefaultMouse: @escaping () -> Void,
        onUseDoubleOption: @escaping () -> Void,
        onStartRecording: @escaping () -> Void,
        onCancelRecording: @escaping () -> Void,
        onCapturedShortcut: @escaping (CapturedShortcut) -> Void
    ) {
        self.onUseDefaultMouse = onUseDefaultMouse
        self.onUseDoubleOption = onUseDoubleOption
        self.onStartRecording = onStartRecording
        self.onCancelRecording = onCancelRecording
        self.onCapturedShortcut = onCapturedShortcut

        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 520, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "设置快捷键"
        window.center()

        super.init(window: window)
        window.delegate = self
        buildContent()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func show(currentShortcut: String) {
        update(currentShortcut: currentShortcut, isRecording: false)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func update(currentShortcut: String, isRecording: Bool) {
        currentLabel.stringValue = "当前：\(currentShortcut)"
        captureTitleLabel.stringValue = isRecording ? "…" : "+"
        captureHintLabel.stringValue = isRecording
            ? "按下键盘组合键，或按一下鼠标侧键。"
            : "点击录制后，按下你想使用的键盘组合键或鼠标侧键。"
        recordButton.title = isRecording ? "正在录制" : "录制快捷键"
        recordButton.isEnabled = !isRecording
        recorderView.isRecording = isRecording
        recorderView.isHidden = !isRecording
        if isRecording {
            window?.makeFirstResponder(recorderView)
        }
    }

    private func buildContent() {
        guard let contentView = window?.contentView else {
            return
        }

        let titleLabel = NSTextField(labelWithString: "选择一个切换方式")
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        currentLabel.font = .systemFont(ofSize: 13, weight: .medium)
        currentLabel.textColor = .secondaryLabelColor
        currentLabel.translatesAutoresizingMaskIntoConstraints = false

        let captureBox = NSBox()
        captureBox.boxType = .custom
        captureBox.cornerRadius = 12
        captureBox.borderColor = .separatorColor
        captureBox.fillColor = NSColor.controlBackgroundColor
        captureBox.translatesAutoresizingMaskIntoConstraints = false

        captureTitleLabel.font = .systemFont(ofSize: 72, weight: .thin)
        captureTitleLabel.textColor = .tertiaryLabelColor
        captureTitleLabel.alignment = .center
        captureTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        captureHintLabel.font = .systemFont(ofSize: 13)
        captureHintLabel.textColor = .secondaryLabelColor
        captureHintLabel.alignment = .center
        captureHintLabel.translatesAutoresizingMaskIntoConstraints = false

        captureBox.contentView?.addSubview(captureTitleLabel)
        captureBox.contentView?.addSubview(captureHintLabel)

        let defaultMouseButton = NSButton(title: "鼠标侧键", target: self, action: #selector(useDefaultMouse))
        defaultMouseButton.bezelStyle = .rounded

        let doubleOptionButton = NSButton(title: "双击 Option", target: self, action: #selector(useDoubleOption))
        doubleOptionButton.bezelStyle = .rounded

        recordButton.target = self
        recordButton.action = #selector(startRecording)
        recordButton.bezelStyle = .rounded

        let buttonStack = NSStackView(views: [defaultMouseButton, doubleOptionButton, recordButton])
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 10
        buttonStack.alignment = .centerY
        buttonStack.distribution = .gravityAreas
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        let footnote = NSTextField(wrappingLabelWithString: "建议使用不常被其他应用占用的组合键。鼠标侧键触发时，可以在菜单栏里选择是否拦截原本的后退动作。")
        footnote.font = .systemFont(ofSize: 12)
        footnote.textColor = .secondaryLabelColor
        footnote.alignment = .center
        footnote.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(titleLabel)
        contentView.addSubview(currentLabel)
        contentView.addSubview(captureBox)
        contentView.addSubview(buttonStack)
        contentView.addSubview(footnote)
        contentView.addSubview(recorderView)
        recorderView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            recorderView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            recorderView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            recorderView.topAnchor.constraint(equalTo: contentView.topAnchor),
            recorderView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 22),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),

            currentLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            currentLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            currentLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            captureBox.topAnchor.constraint(equalTo: currentLabel.bottomAnchor, constant: 16),
            captureBox.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            captureBox.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            captureBox.heightAnchor.constraint(equalToConstant: 130),

            captureTitleLabel.centerXAnchor.constraint(equalTo: captureBox.contentView!.centerXAnchor),
            captureTitleLabel.centerYAnchor.constraint(equalTo: captureBox.contentView!.centerYAnchor, constant: -18),

            captureHintLabel.leadingAnchor.constraint(equalTo: captureBox.contentView!.leadingAnchor, constant: 18),
            captureHintLabel.trailingAnchor.constraint(equalTo: captureBox.contentView!.trailingAnchor, constant: -18),
            captureHintLabel.bottomAnchor.constraint(equalTo: captureBox.contentView!.bottomAnchor, constant: -16),

            buttonStack.topAnchor.constraint(equalTo: captureBox.bottomAnchor, constant: 18),
            buttonStack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            footnote.topAnchor.constraint(equalTo: buttonStack.bottomAnchor, constant: 16),
            footnote.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 42),
            footnote.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -42)
        ])
    }

    @objc private func useDefaultMouse() {
        onCancelRecording()
        onUseDefaultMouse()
    }

    @objc private func useDoubleOption() {
        onCancelRecording()
        onUseDoubleOption()
    }

    @objc private func startRecording() {
        onStartRecording()
    }

    private func finishLocalRecording(_ shortcut: CapturedShortcut) {
        onCancelRecording()
        onCapturedShortcut(shortcut)
    }
}

extension ShortcutWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        onCancelRecording()
    }
}

final class ShortcutRecorderView: NSView {
    var isRecording = false
    private let onCapture: (CapturedShortcut) -> Void

    init(onCapture: @escaping (CapturedShortcut) -> Void) {
        self.onCapture = onCapture
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        let shortcut = KeyboardShortcut(
            keyCode: Int64(event.keyCode),
            modifiers: Preferences.normalizedKeyboardModifiers(CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue)))
        )
        onCapture(.keyboardShortcut(shortcut))
    }

    override func otherMouseDown(with event: NSEvent) {
        guard isRecording else {
            super.otherMouseDown(with: event)
            return
        }
        onCapture(.mouseButton(Int64(event.buttonNumber + 1)))
    }
}
