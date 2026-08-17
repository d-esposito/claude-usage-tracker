import AppKit
import SwiftUI

@MainActor
final class DesktopPanel: NSPanel {
    private static let originXKey = "desktopPanelOriginX"
    private static let originYKey = "desktopPanelOriginY"

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init(controller: DesktopUsageController) {
        let size = NSSize(width: 390, height: 132)
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        animationBehavior = .utilityWindow
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        let hostingView = NSHostingView(rootView: DesktopTileView(controller: controller))
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor

        if #available(macOS 26.0, *) {
            let glassView = NSGlassEffectView(frame: NSRect(origin: .zero, size: size))
            glassView.style = .clear
            glassView.cornerRadius = 30
            glassView.tintColor = nil
            hostingView.frame = glassView.bounds
            hostingView.autoresizingMask = [.width, .height]
            glassView.contentView = hostingView
            contentView = glassView
        } else {
            let materialView = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
            materialView.material = .underWindowBackground
            materialView.blendingMode = .behindWindow
            materialView.state = .active
            materialView.wantsLayer = true
            materialView.layer?.cornerRadius = 30
            materialView.layer?.masksToBounds = true
            hostingView.frame = materialView.bounds
            hostingView.autoresizingMask = [.width, .height]
            materialView.addSubview(hostingView)
            contentView = materialView
        }
        restorePosition()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowMoved),
            name: NSWindow.didMoveNotification,
            object: self
        )
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    func moveToTopRight() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        setFrameOrigin(NSPoint(x: visible.maxX - frame.width - 28, y: visible.maxY - frame.height - 28))
        savePosition()
    }

    private func restorePosition() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Self.originXKey) != nil,
           defaults.object(forKey: Self.originYKey) != nil {
            setFrameOrigin(NSPoint(
                x: defaults.double(forKey: Self.originXKey),
                y: defaults.double(forKey: Self.originYKey)
            ))
        } else {
            moveToTopRight()
        }
    }

    @objc private func windowMoved() { savePosition() }

    private func savePosition() {
        UserDefaults.standard.set(frame.origin.x, forKey: Self.originXKey)
        UserDefaults.standard.set(frame.origin.y, forKey: Self.originYKey)
    }
}
