import AppKit

@main
struct ClaudeUsageTrackerDesktop {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.setActivationPolicy(.accessory)
        application.delegate = delegate
        application.run()
    }
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
    private let controller = DesktopUsageController()
    private let loginManager = LaunchAtLoginManager()
    private var panel: DesktopPanel?
    private var statusItem: NSStatusItem?
    private var visibilityItem: NSMenuItem?
    private var loginItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let panel = DesktopPanel(controller: controller)
        self.panel = panel
        panel.orderFrontRegardless()
        configureStatusItem()
        controller.start()
    }

    private func configureStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.statusItem = statusItem
        statusItem.button?.image = NSImage(
            systemSymbolName: "gauge.with.dots.needle.50percent",
            accessibilityDescription: "Claude usage"
        )

        let menu = NSMenu()
        let visibility = NSMenuItem(title: "Hide Desktop Tile", action: #selector(togglePanel), keyEquivalent: "")
        visibility.target = self
        visibilityItem = visibility
        menu.addItem(visibility)

        let refresh = NSMenuItem(title: "Refresh Now", action: #selector(refresh), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)

        let reposition = NSMenuItem(title: "Move to Top Right", action: #selector(reposition), keyEquivalent: "")
        reposition.target = self
        menu.addItem(reposition)

        menu.addItem(.separator())
        let login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        login.target = self
        login.state = loginManager.isEnabled ? .on : .off
        loginItem = login
        menu.addItem(login)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Claude Usage Tracker", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
    }

    @objc private func togglePanel() {
        guard let panel else { return }
        if panel.isVisible {
            panel.orderOut(nil)
            visibilityItem?.title = "Show Desktop Tile"
        } else {
            panel.orderFrontRegardless()
            visibilityItem?.title = "Hide Desktop Tile"
        }
    }

    @objc private func refresh() {
        Task { await controller.refresh() }
    }

    @objc private func reposition() {
        panel?.moveToTopRight()
        panel?.orderFrontRegardless()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            try loginManager.setEnabled(!loginManager.isEnabled)
            loginItem?.state = loginManager.isEnabled ? .on : .off
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn’t update Launch at Login"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
