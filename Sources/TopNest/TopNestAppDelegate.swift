import AppKit
import Combine
import SwiftUI
import UserNotifications

final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class TopNestAppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private let state = AppState()
    private var panel: NotchPanel?
    private var settingsWindow: NSWindow?
    private var statusItem: NSStatusItem?
    private var keyMonitor: Any?
    private var clickMonitor: Any?
    private var outsideClickMonitor: Any?
    private var hoverExitTimer: Timer?
    private var hoverExitSince: Date?
    private var preferredScreen: NSScreen?
    private var hiddenForFullscreen = false
    private var activityGeneration = 0
    private var cancellables: Set<AnyCancellable> = []

    private var notchWidth: CGFloat? {
        guard let screen = preferredScreen,
              let left = screen.auxiliaryTopLeftArea,
              let right = screen.auxiliaryTopRightArea else { return nil }
        return right.minX - left.maxX
    }

    private var compactSize: NSSize {
        guard let notchWidth, let screen = preferredScreen else { return NSSize(width: 220, height: 32) }
        let wings = state.activity == .idle ? 0 : AppState.wingWidth * 2
        return NSSize(width: notchWidth + wings, height: max(screen.safeAreaInsets.top, 24))
    }
    private let expandedSize = NSSize(width: 440, height: 500)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if Bundle.main.bundleURL.pathExtension == "app" {
            UNUserNotificationCenter.current().delegate = self
        }
        preferredScreen = Self.defaultScreen()
        state.notchWidth = notchWidth
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
        state.onOpenSettings = { [weak self] in self?.openSettingsWindow() }
        state.onVisibilityRuleChange = { [weak self] in self?.updateFullscreenVisibility() }
        positionPanel(size: compactSize, animate: false)
        panel.orderFrontRegardless()

        state.$activity.removeDuplicates().dropFirst().sink { [weak self] _ in
            // @Published qiymati sink'dan keyin yoziladi, shuning uchun o'lcham keyingi siklda olinadi.
            DispatchQueue.main.async { self?.applyActivity() }
        }.store(in: &cancellables)

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "square.stack.3d.up.fill", accessibilityDescription: "TopNest")
        item.button?.target = self
        item.button?.action = #selector(statusItemClicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        self.statusItem = item

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.window === self?.panel { self?.state.markInteracted() }
            if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "," {
                self?.state.showSettings()
                return nil
            }
            if event.keyCode == 53, self?.state.expanded == true {
                self?.collapse()
                return nil
            }
            return event
        }
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if event.window === self?.panel, self?.state.expanded == true {
                self?.state.markInteracted()
                self?.panel?.makeKey()
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
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(spaceOrAppChanged), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        workspace.addObserver(self, selector: #selector(spaceOrAppChanged), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        updateFullscreenVisibility()
    }

    // Sozlamalar oynasi ochiq bo'lsa ham banner ko'rinsin.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    private static func defaultScreen() -> NSScreen? {
        NSScreen.screens.first(where: { $0.auxiliaryTopLeftArea != nil || $0.auxiliaryTopRightArea != nil }) ?? NSScreen.main ?? NSScreen.screens.first
    }

    // Chap klik panelni ochadi/yopadi, o'ng klik menyuni ko'rsatadi.
    @objc private func statusItemClicked() {
        guard let statusItem else { return }
        if NSApp.currentEvent?.type == .rightMouseUp {
            statusItem.menu = makeStatusMenu()
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            togglePanel()
        }
    }

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()
        let open = NSMenuItem(title: state.expanded ? "Panelni yopish" : "Panelni ochish", action: #selector(togglePanel), keyEquivalent: "")
        let settings = NSMenuItem(title: "Sozlamalar…", action: #selector(openSettingsFromMenu), keyEquivalent: ",")
        let quit = NSMenuItem(title: "TopNest’dan chiqish", action: #selector(quit), keyEquivalent: "q")
        for item in [open, settings, quit] { item.target = self }
        menu.items = [open, settings, .separator(), quit]
        return menu
    }

    @objc private func togglePanel() {
        state.expanded ? collapse() : state.requestExpand()
    }

    @objc private func openSettingsFromMenu() { state.showSettings() }

    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func reposition() {
        if let preferredScreen, !NSScreen.screens.contains(preferredScreen) {
            self.preferredScreen = Self.defaultScreen()
        }
        state.notchWidth = notchWidth
        positionPanel(size: state.expanded ? expandedSize : compactSize, animate: false)
        updateFullscreenVisibility()
    }

    @objc private func spaceOrAppChanged() {
        updateFullscreenVisibility()
        // Fullscreen o'tish animatsiyasi tugagach oyna o'lchami barqaror bo'ladi.
        for delay in [0.8, 1.5] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.updateFullscreenVisibility()
            }
        }
    }

    // O'lcham kattalashsa avval panel kengayadi, kichraysa avval qanotlar yashiriladi.
    private func applyActivity() {
        activityGeneration += 1
        let generation = activityGeneration
        guard !state.expanded else {
            state.displayedActivity = state.activity
            return
        }
        if state.activity == .idle {
            state.displayedActivity = .idle
            positionPanel(size: compactSize, animate: true)
        } else if state.displayedActivity == .idle {
            positionPanel(size: compactSize, animate: true) { [weak self] in
                guard let self, generation == self.activityGeneration, !self.state.expanded else { return }
                self.state.displayedActivity = self.state.activity
            }
        } else {
            state.displayedActivity = state.activity
        }
    }

    private func updateFullscreenVisibility() {
        guard let panel, let screen = preferredScreen else { return }
        let shouldHide = state.hideInFullscreen && !state.expanded && Self.frontmostIsFullscreen(on: screen)
        guard shouldHide != hiddenForFullscreen else { return }
        hiddenForFullscreen = shouldHide
        if shouldHide { panel.orderOut(nil) }
        else { panel.orderFrontRegardless() }
    }

    // Ekrandagi eng yuqori oddiy oyna butun ekranni (notch ostidagi qismdan tashqari) egallasa — fullscreen.
    private static func frontmostIsFullscreen(on screen: NSScreen) -> Bool {
        guard let primary = NSScreen.screens.first,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return false }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let frame = screen.frame
        let quartzFrame = CGRect(x: frame.minX, y: primary.frame.maxY - frame.maxY, width: frame.width, height: frame.height)
        for info in windows {
            guard (info[kCGWindowLayer as String] as? Int) == 0,
                  (info[kCGWindowOwnerPID as String] as? pid_t) != ownPID,
                  let bounds = info[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds),
                  rect.intersects(quartzFrame) else { continue }
            let minHeight = frame.height - screen.safeAreaInsets.top - 1
            return abs(rect.minX - quartzFrame.minX) < 1
                && abs(rect.maxY - quartzFrame.maxY) < 1
                && rect.width >= frame.width - 1
                && rect.height >= minHeight
        }
        return false
    }

    private func expand() {
        state.expanded = true
        if hiddenForFullscreen { hiddenForFullscreen = false }
        state.displayedActivity = state.activity
        positionPanel(size: expandedSize, animate: true)
        // Hover bilan ochilganda fokus olinmaydi; birinchi klikda panel key bo'ladi.
        if state.openedByHover {
            panel?.orderFrontRegardless()
            startHoverExitWatch()
        } else {
            panel?.makeKeyAndOrderFront(nil)
        }
        state.refreshCodex(ifOlderThan: 60)
        state.calendar.refresh()
    }

    private func collapse() {
        stopHoverExitWatch()
        let wasKey = panel?.isKeyWindow == true
        state.expanded = false
        state.displayedActivity = state.activity
        positionPanel(size: compactSize, animate: true)
        updateFullscreenVisibility()
        if !hiddenForFullscreen { panel?.orderFrontRegardless() }
        // Nonactivating panel fokusni ushlab qolmasligi uchun uni oldingi ilovaga qaytaramiz.
        if wasKey, let front = NSWorkspace.shared.frontmostApplication,
           front.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            front.activate()
        }
    }

    // Hover bilan ochilgan panel: kursor tashqarida 0.4 s tursa yopiladi.
    private func startHoverExitWatch() {
        stopHoverExitWatch()
        let timer = Timer(timeInterval: 0.15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkHoverExit() }
        }
        RunLoop.main.add(timer, forMode: .common)
        hoverExitTimer = timer
    }

    private func stopHoverExitWatch() {
        hoverExitTimer?.invalidate()
        hoverExitTimer = nil
        hoverExitSince = nil
    }

    private func checkHoverExit() {
        guard state.expanded, state.openedByHover, let panel else { stopHoverExitWatch(); return }
        if panel.frame.insetBy(dx: -8, dy: -8).contains(NSEvent.mouseLocation) {
            hoverExitSince = nil
        } else if let since = hoverExitSince {
            if Date().timeIntervalSince(since) > 0.4 { collapse() }
        } else {
            hoverExitSince = Date()
        }
    }

    private func openSettingsWindow() {
        if state.expanded { collapse() }
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 760, height: 560),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "TopNest sozlamalari"
            window.minSize = NSSize(width: 700, height: 500)
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsWindowView(state: state))
            window.center()
            settingsWindow = window
        }
        state.refreshLaunchAtLogin()
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func positionPanel(size: NSSize, animate: Bool, completion: (@MainActor @Sendable () -> Void)? = nil) {
        guard let panel, let screen = preferredScreen ?? NSScreen.main ?? NSScreen.screens.first else { completion?(); return }
        let width = min(size.width, screen.frame.width - 16)
        let height = min(size.height, screen.visibleFrame.height - 12)
        // Notchli ekranda compact holat ekran tepasiga yopishadi, aks holda 2 pt bo'shliq.
        let topGap: CGFloat = (!state.expanded && notchWidth != nil) ? 0 : 2
        let frame = NSRect(
            x: screen.frame.midX - width / 2,
            y: screen.frame.maxY - height - topGap,
            width: width,
            height: height
        )
        guard animate, !state.motionReduced, panel.frame != frame else {
            panel.setFrame(frame, display: true)
            completion?()
            return
        }
        let growing = frame.width * frame.height > panel.frame.width * panel.frame.height
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = growing ? 0.3 : 0.22
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1)
            panel.animator().setFrame(frame, display: true)
        }, completionHandler: {
            MainActor.assumeIsolated { completion?() }
        })
    }
}
