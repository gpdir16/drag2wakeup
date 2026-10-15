import AppKit

MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)

    let menuBar = MenuBar()
    withExtendedLifetime(menuBar) {
        app.run()
    }
}
