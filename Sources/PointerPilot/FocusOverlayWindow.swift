import AppKit
import QuartzCore

final class FocusOverlayWindow: NSWindow {
    private let overlayView = FocusOverlayView(frame: CGRect(x: 0, y: 0, width: 160, height: 160))
    private var closeWorkItem: DispatchWorkItem?

    init() {
        super.init(
            contentRect: CGRect(x: 0, y: 0, width: 160, height: 160),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        contentView = overlayView
    }

    func show(at point: CGPoint) {
        closeWorkItem?.cancel()

        let size = frame.size
        setFrameOrigin(CGPoint(x: point.x - size.width / 2, y: point.y - size.height / 2))
        alphaValue = 1
        overlayView.prepareForAnimation()
        orderFrontRegardless()
        overlayView.animate()

        let workItem = DispatchWorkItem { [weak self] in
            self?.orderOut(nil)
        }
        closeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.46, execute: workItem)
    }
}

final class FocusOverlayView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = false
    }

    required init?(coder: NSCoder) {
        nil
    }

    func prepareForAnimation() {
        layer?.removeAllAnimations()
        layer?.opacity = 1
        layer?.setAffineTransform(.identity)
        needsDisplay = true
    }

    func animate() {
        let scale = CAKeyframeAnimation(keyPath: "transform.scale")
        scale.values = [0.74, 1.06, 1.0]
        scale.keyTimes = [0, 0.55, 1]
        scale.duration = 0.38
        scale.timingFunctions = [
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .easeInEaseOut)
        ]

        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [0, 1, 1, 0]
        opacity.keyTimes = [0, 0.20, 0.60, 1]
        opacity.duration = 0.44
        opacity.timingFunctions = [
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .linear),
            CAMediaTimingFunction(name: .easeIn)
        ]

        layer?.add(scale, forKey: "focus-scale")
        layer?.add(opacity, forKey: "focus-opacity")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let glowRect = bounds.insetBy(dx: 28, dy: 28)
        let ringRect = bounds.insetBy(dx: 46, dy: 46)
        let accent = NSColor.controlAccentColor

        let glowPath = NSBezierPath(ovalIn: glowRect)
        accent.withAlphaComponent(0.11).setFill()
        glowPath.fill()

        let ringPath = NSBezierPath(ovalIn: ringRect)
        NSColor.white.withAlphaComponent(0.22).setFill()
        ringPath.fill()
        accent.withAlphaComponent(0.82).setStroke()
        ringPath.lineWidth = 3
        ringPath.stroke()

        let innerGlow = NSBezierPath(ovalIn: ringRect.insetBy(dx: 15, dy: 15))
        accent.withAlphaComponent(0.16).setFill()
        innerGlow.fill()

        let dotRect = CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)
        let dot = NSBezierPath(ovalIn: dotRect)
        accent.withAlphaComponent(0.92).setFill()
        dot.fill()
    }
}
