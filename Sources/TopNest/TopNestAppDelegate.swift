import AppKit
import SwiftUI

final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class TopNestAppDelegate: NSObject, NSApplicationDelegate {
    private let state = AppState()
    private var panel: NotchPanel?
    private var statusItem: NSStatusItem?
    private var keyMonitor: Any?
    private var outsideClickMonitor: Any?
    private var preferredScreen: NSScreen?

    private let compactSize = NSSize(width: 290, height: 38)
    private let expandedSize = NSSize(width: 480, height: 580)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let panel = NotchPanel(
            contentRect: NSRect(origin: .zero, size: compactSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.contentView = NSHostingView(rootView: RootView(state: state))
        self.panel = panel
        state.onExpand = { [weak self] in self?.expand() }
        state.onCollapse = { [weak self] in self?.collapse() }
        preferredScreen = NSScreen.screens.first(where: { $0.auxiliaryTopLeftArea != nil || $0.auxiliaryTopRightArea != nil }) ?? NSScreen.main
        positionPanel(size: compactSize, animate: false)
        panel.orderFrontRegardless()

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "square.stack.3d.up.fill", accessibilityDescription: "TopNest")
        item.button?.target = self
        item.button?.action = #selector(togglePanel)
        self.statusItem = item

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53, self?.state.expanded == true {
                self?.collapse()
                return nil
            }
            return event
        }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                guard self?.state.expanded == true else { return }
                self?.collapse()
            }
        }
        NotificationCenter.default.addObserver(self, selector: #selector(reposition), name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func togglePanel() {
        state.expanded ? collapse() : expand()
    }

    @objc private func reposition() {
        if let preferredScreen, !NSScreen.screens.contains(preferredScreen) {
            self.preferredScreen = NSScreen.main ?? NSScreen.screens.first
        }
        positionPanel(size: state.expanded ? expandedSize : compactSize, animate: false)
    }

    private func expand() {
        state.expanded = true
        positionPanel(size: expandedSize, animate: true)
        panel?.makeKeyAndOrderFront(nil)
        state.refreshCodex()
    }

    private func collapse() {
        state.expanded = false
        positionPanel(size: compactSize, animate: true)
        panel?.orderFrontRegardless()
    }

    private func positionPanel(size: NSSize, animate: Bool) {
        guard let panel, let screen = preferredScreen ?? NSScreen.main ?? NSScreen.screens.first else { return }
        let width = min(size.width, screen.frame.width - 16)
        let height = min(size.height, screen.visibleFrame.height - 12)
        let frame = NSRect(
            x: screen.frame.midX - width / 2,
            y: screen.frame.maxY - height - 2,
            width: width,
            height: height
        )
        panel.setFrame(frame, display: true, animate: animate)
    }
}
