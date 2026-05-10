import AppKit
import CoreGraphics

final class ScreenSwitcher {
    func switchToNextScreenCenter() -> CGPoint {
        let screens = NSScreen.screens
        let currentLocation = NSEvent.mouseLocation

        guard screens.count > 1 else {
            return currentLocation
        }

        let currentIndex = screens.firstIndex { screen in
            NSMouseInRect(currentLocation, screen.frame, false)
        }

        let baseIndex: Int
        if let currentIndex {
            baseIndex = currentIndex
        } else if let main = NSScreen.main, let mainIndex = screens.firstIndex(of: main) {
            baseIndex = mainIndex
        } else {
            baseIndex = 0
        }

        let targetScreen = screens[(baseIndex + 1) % screens.count]
        let targetPoint = CGPoint(x: targetScreen.visibleFrame.midX, y: targetScreen.visibleFrame.midY)

        CGWarpMouseCursorPosition(quartzPoint(fromAppKitPoint: targetPoint, screens: screens))
        CGAssociateMouseAndMouseCursorPosition(1)

        return targetPoint
    }

    private func quartzPoint(fromAppKitPoint point: CGPoint, screens: [NSScreen]) -> CGPoint {
        let maxY = screens.map { $0.frame.maxY }.max() ?? point.y
        return CGPoint(x: point.x, y: maxY - point.y)
    }
}
