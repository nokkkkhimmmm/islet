import AppKit
import IsletCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var monitor: AgentActivityMonitor?
    private var model: IslandModel?
    private var windowController: NotchWindowController?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let screen = NotchGeometry.islandScreen() else {
            NSLog("[Islet] No usable screen found; not showing the island.")
            return
        }

        let monitor = AgentActivityMonitor()
        let model = IslandModel(agents: monitor, metrics: NotchGeometry.metrics(for: screen))
        let windowController = NotchWindowController(model: model)

        self.monitor = monitor
        self.model = model
        self.windowController = windowController

        monitor.start()
        windowController.show()
        installStatusItem()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor?.stop()
        windowController?.hide()
    }

    /// Islet has no dock icon, so the menu bar item is the only way to quit it.
    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "rectangle.topthird.inset.filled",
            accessibilityDescription: "Islet"
        )

        let menu = NSMenu()
        menu.addItem(
            withTitle: "Islet \(Bundle.main.shortVersion)",
            action: nil,
            keyEquivalent: ""
        )
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit Islet",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        item.menu = menu
        statusItem = item
    }
}

extension Bundle {
    var shortVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }
}
