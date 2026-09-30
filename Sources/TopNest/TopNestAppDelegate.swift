import AppKit
import Carbon.HIToolbox
import Combine
import SwiftUI
import UserNotifications

final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

enum PanelDisplayPolicy {
    static func mirrorIDs(available: [UInt32], primary: UInt32?, showOnAll: Bool) -> Set<UInt32> {
        guard showOnAll else { return [] }
        return Set(available).subtracting(primary.map { [$0] } ?? [])
    }

    static func compactVisible(hasNotch: Bool, onlyNotch: Bool, isFullscreen: Bool, hideInFullscreen: Bool) -> Bool {
        !(onlyNotch && !hasNotch) && !(hideInFullscreen && isFullscreen)
    }
}

@MainActor
final class TopNestAppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private let state = AppState()
    private var panel: NotchPanel?
    private var mirrorPanels: [UInt32: NotchPanel] = [:]
    private var pendingHoverDisplayID: UInt32?
    private var settingsWindow: NSWindow?
    private var statusItem: NSStatusItem?
    private var keyMonitor: Any?
    private var clickMonitor: Any?
    private var outsideClickMonitor: Any?
    private var hoverExitTimer: Timer?
    private var hoverExitSince: Date?
    private var preferredScreen: NSScreen?
    private var hiddenByRule = false
    private var activityGeneration = 0
    private var cancellables: Set<AnyCancellable> = []

    private var notchWidth: CGFloat? {
        preferredScreen?.notchWidth
    }

    private var compactSize: NSSize {
        guard let screen = preferredScreen else { return NSSize(width: 220, height: 32) }
        return compactSize(on: screen)
    }

    private func compactSize(on screen: NSScreen) -> NSSize {
        guard let notchWidth = screen.notchWidth else { return NSSize(width: 220, height: 32) }
        let wings = state.activity == .idle ? 0 : AppState.wingWidth * 2
        let flare: CGFloat = state.compactStyle == .blended ? AppState.compactFlare : 0
        return NSSize(width: notchWidth + wings + flare * 2, height: max(screen.safeAreaInsets.top, 24))
    }
    private var expandedSize: NSSize { NSSize(width: state.expandedPanelSize.width, height: state.expandedPanelSize.height) }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if Bundle.main.bundleURL.pathExtension == "app" {
            UNUserNotificationCenter.current().delegate = self
        }
        preferredScreen = chooseScreen()
        state.notchWidth = notchWidth
        state.notchHeight = notchWidth == nil ? 0 : (preferredScreen?.safeAreaInsets.top ?? 0)
        let panel = makePanel(rootView: RootView(state: state, onCompactHover: { [weak self] inside in
            if inside { self?.pendingHoverDisplayID = nil }
            self?.state.handleCompactHover(inside)
        }))
        self.panel = panel
        state.onExpand = { [weak self] in self?.expand() }
        state.onCollapse = { [weak self] in self?.collapse() }
        state.onOpenSettings = { [weak self] in self?.openSettingsWindow() }
        state.onVisibilityRuleChange = { [weak self] in self?.updateVisibility() }
        state.onScreenRuleChange = { [weak self] in self?.reposition(reselect: true) }
        state.onHotKeysChange = { [weak self] in self?.registerHotKeys() }
        state.onGeometryChange = { [weak self] in self?.reposition(reselect: false) }
        state.onFocusPanel = { [weak self] in
            self?.stopHoverExitWatch()
            self?.panel?.makeKeyAndOrderFront(nil)
        }
        positionPanel(size: compactSize, animate: false)
        panel.orderFrontRegardless()
        syncMirrorPanels()

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
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(spaceOrAppChanged), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        workspace.addObserver(self, selector: #selector(spaceOrAppChanged), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        updateVisibility()
        registerHotKeys()
    }

    // Sozlamalar oynasi ochiq bo'lsa ham banner ko'rinsin.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func applicationWillTerminate(_ notification: Notification) {
        state.shutdown()
        closeMirrorPanels()
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    // Tanlangan ekran ulanmagan bo'lsa (masalan clamshell) avtomatik tanlovga qaytiladi.
    private func chooseScreen() -> NSScreen? {
        if !state.displayUUID.isEmpty, let chosen = NSScreen.screens.first(where: { $0.displayUUID == state.displayUUID }) {
            return chosen
        }
        return NSScreen.screens.first(where: { $0.auxiliaryTopLeftArea != nil || $0.auxiliaryTopRightArea != nil }) ?? NSScreen.main ?? NSScreen.screens.first
    }

    private func makePanel(rootView: RootView) -> NotchPanel {
        let panel = NotchPanel(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 220, height: 32)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        let hosting = NSHostingView(rootView: rootView)
        hosting.sizingOptions = []
        panel.contentView = hosting
        return panel
    }

    private func closeMirrorPanels() {
        for panel in mirrorPanels.values {
            panel.orderOut(nil)
            panel.close()
        }
        mirrorPanels.removeAll()
    }

    private func syncMirrorPanels(rebuild: Bool = false) {
        if rebuild || !state.showOnAllScreens { closeMirrorPanels() }
        guard state.showOnAllScreens else { return }
        let activeIDs = PanelDisplayPolicy.mirrorIDs(
            available: NSScreen.screens.compactMap(\.displayID), primary: preferredScreen?.displayID,
            showOnAll: state.showOnAllScreens
        )
        let screens = NSScreen.screens.filter { $0.displayID.map(activeIDs.contains) ?? false }
        for id in mirrorPanels.keys.filter({ !activeIDs.contains($0) }) {
            guard let panel = mirrorPanels.removeValue(forKey: id) else { continue }
            panel.orderOut(nil)
            // Sichqoncha hodisasi aynan shu oynadan kelgan bo'lishi mumkin.
            DispatchQueue.main.async { panel.close() }
        }
        for screen in screens {
            guard let id = screen.displayID else { continue }
            if mirrorPanels[id] == nil {
                mirrorPanels[id] = makePanel(rootView: RootView(
                    state: state, compactScreen: screen, forceCompact: true,
                    onCompactActivate: { [weak self] in self?.activateMirror(id) },
                    onCompactHover: { [weak self] inside in self?.handleMirrorHover(id, inside: inside) },
                    onCompactDrop: { [weak self] providers in self?.dropOnMirror(id, providers: providers) ?? false }
                ))
            }
            if let mirror = mirrorPanels[id] {
                position(mirror, on: screen, size: compactSize(on: screen), expanded: false, animate: false)
            }
        }
    }

    private func selectMirrorScreen(_ id: UInt32) {
        guard let screen = NSScreen.screens.first(where: { $0.displayID == id }) else { return }
        pendingHoverDisplayID = nil
        preferredScreen = screen
        state.notchWidth = notchWidth
        state.notchHeight = notchWidth == nil ? 0 : screen.safeAreaInsets.top
        positionPanel(size: state.expanded ? expandedSize : compactSize, animate: false)
        syncMirrorPanels()
        updateVisibility()
    }

    private func activateMirror(_ id: UInt32) {
        selectMirrorScreen(id)
        state.requestExpand()
    }

    private func handleMirrorHover(_ id: UInt32, inside: Bool) {
        if inside { pendingHoverDisplayID = id }
        else if pendingHoverDisplayID == id { pendingHoverDisplayID = nil }
        state.handleCompactHover(inside)
    }

    private func dropOnMirror(_ id: UInt32, providers: [NSItemProvider]) -> Bool {
        selectMirrorScreen(id)
        state.selectedTab = .shelf
        state.requestExpand(byHover: true)
        return state.shelf.accept(providers)
    }

    private func registerHotKeys() {
        let hotKeys = HotKeyCenter.shared
        hotKeys.unregisterAll()
        state.hotKeyMessage = nil
        guard state.hotKeysEnabled else { return }
        let modifiers = controlKey | optionKey | cmdKey
        let panelOK = hotKeys.register(id: 1, keyCode: kVK_ANSI_N, modifiers: modifiers) { [weak self] in self?.togglePanel() }
        let clipsOK = hotKeys.register(id: 2, keyCode: kVK_ANSI_V, modifiers: modifiers) { [weak self] in self?.state.openClipboardSearch() }
        if !panelOK || !clipsOK {
            state.hotKeyMessage = "Ba’zi yorliqlarni ro‘yxatdan o‘tkazib bo‘lmadi; ular boshqa ilova tomonidan band bo‘lishi mumkin."
        }
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
        let open = NSMenuItem(title: L10n.tr(state.expanded ? "Panelni yopish" : "Panelni ochish"), action: #selector(togglePanel), keyEquivalent: "")
        let settings = NSMenuItem(title: L10n.tr("Sozlamalar…"), action: #selector(openSettingsFromMenu), keyEquivalent: ",")
        let quit = NSMenuItem(title: L10n.tr("TopNest’dan chiqish"), action: #selector(quit), keyEquivalent: "q")
        for item in [open, settings, quit] { item.target = self }
        menu.items = [open, settings, .separator(), quit]
        return menu
    }

    @objc private func togglePanel() {
        state.expanded ? collapse() : state.requestExpand()
    }

    @objc private func openSettingsFromMenu() { state.showSettings() }

    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func screensChanged() { reposition(reselect: true) }

    private func reposition(reselect: Bool) {
        if reselect { preferredScreen = chooseScreen() }
        state.notchWidth = notchWidth
        state.notchHeight = notchWidth == nil ? 0 : (preferredScreen?.safeAreaInsets.top ?? 0)
        activityGeneration += 1
        state.displayedActivity = state.activity
        positionPanel(size: state.expanded ? expandedSize : compactSize, animate: false)
        syncMirrorPanels(rebuild: reselect)
        updateVisibility()
    }

    @objc private func spaceOrAppChanged() {
        updateVisibility()
        // Fullscreen o'tish animatsiyasi tugagach oyna o'lchami barqaror bo'ladi.
        for delay in [0.8, 1.5] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.updateVisibility()
            }
        }
    }

    // O'lcham kattalashsa avval panel kengayadi, kichraysa avval qanotlar yashiriladi.
    private func applyActivity() {
        activityGeneration += 1
        let generation = activityGeneration
        guard !state.expanded else {
            state.displayedActivity = state.activity
            positionMirrorPanels(animate: true)
            return
        }
        if state.activity == .idle {
            state.displayedActivity = .idle
            positionPanel(size: compactSize, animate: true)
            positionMirrorPanels(animate: true)
        } else if state.displayedActivity == .idle {
            positionPanel(size: compactSize, animate: true) { [weak self] in
                guard let self, generation == self.activityGeneration, !self.state.expanded else { return }
                self.state.displayedActivity = self.state.activity
            }
            positionMirrorPanels(animate: true)
        } else {
            state.displayedActivity = state.activity
        }
    }

    private func positionMirrorPanels(animate: Bool) {
        for (id, mirror) in mirrorPanels {
            guard let screen = NSScreen.screens.first(where: { $0.displayID == id }) else { continue }
            position(mirror, on: screen, size: compactSize(on: screen), expanded: false, animate: animate)
        }
    }

    private func updateVisibility() {
        for (id, mirror) in mirrorPanels {
            guard let screen = NSScreen.screens.first(where: { $0.displayID == id }) else { continue }
            let shouldShow = state.showOnAllScreens && PanelDisplayPolicy.compactVisible(
                hasNotch: screen.notchWidth != nil, onlyNotch: state.onlyNotchScreen,
                isFullscreen: Self.frontmostIsFullscreen(on: screen), hideInFullscreen: state.hideInFullscreen
            )
            if shouldShow && !mirror.isVisible { mirror.orderFrontRegardless() }
            if !shouldShow && mirror.isVisible { mirror.orderOut(nil) }
        }
        guard let panel, let screen = preferredScreen else { return }
        let shouldHide = !state.expanded && !PanelDisplayPolicy.compactVisible(
            hasNotch: notchWidth != nil, onlyNotch: state.onlyNotchScreen,
            isFullscreen: Self.frontmostIsFullscreen(on: screen), hideInFullscreen: state.hideInFullscreen
        )
        guard shouldHide != hiddenByRule else { return }
        hiddenByRule = shouldHide
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
        if state.openedByHover, let id = pendingHoverDisplayID { selectMirrorScreen(id) }
        pendingHoverDisplayID = nil
        state.expanded = true
        if hiddenByRule { hiddenByRule = false }
        state.displayedActivity = state.activity
        positionPanel(size: expandedSize, animate: true)
        // Hover yoki so'rov bilan ochilganda fokus olinmaydi; birinchi klikda panel key bo'ladi.
        if state.openedByHover {
            panel?.orderFrontRegardless()
            startHoverExitWatch()
        } else {
            panel?.makeKeyAndOrderFront(nil)
        }
        state.refreshCodex(ifOlderThan: 60)
        state.calendar.refresh()
        // Automation ruxsati tizim sozlamalarida berilgan bo'lsa karta darhol yangilansin.
        if state.musicPermissionDenied { state.refreshMusic() }
        state.shelf.pruneMissing()
    }

    private func collapse() {
        stopHoverExitWatch()
        let wasKey = panel?.isKeyWindow == true
        state.expanded = false
        state.displayedActivity = state.activity
        positionPanel(size: compactSize, animate: true)
        updateVisibility()
        if !hiddenByRule { panel?.orderFrontRegardless() }
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
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 580),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            // Zamonaviy ko'rinish: sarlavha satri shaffof, sidebar oyna tepasigacha cho'ziladi.
            window.title = L10n.tr("TopNest sozlamalari")
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.minSize = NSSize(width: 720, height: 520)
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsWindowView(state: state))
            window.center()
            settingsWindow = window
        }
        state.refreshLaunchAtLogin()
        settingsWindow?.title = L10n.tr("TopNest sozlamalari")
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func positionPanel(size: NSSize, animate: Bool, completion: (@MainActor @Sendable () -> Void)? = nil) {
        guard let panel, let screen = preferredScreen ?? NSScreen.main ?? NSScreen.screens.first else { completion?(); return }
        position(panel, on: screen, size: size, expanded: state.expanded, animate: animate, completion: completion)
    }

    private func position(_ panel: NotchPanel, on screen: NSScreen, size: NSSize, expanded: Bool,
                          animate: Bool, completion: (@MainActor @Sendable () -> Void)? = nil) {
        let width = min(size.width, screen.frame.width - 16)
        let height = min(size.height, screen.visibleFrame.height - 12)
        // Notchli ekranda compact va yopishgan uslublar ekran tepasiga tegadi, suzuvchi 2 pt pastda.
        let attached = expanded ? state.expandedAttached : screen.notchWidth != nil
        let topGap: CGFloat = attached ? 0 : 2
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

extension NSScreen {
    var notchWidth: CGFloat? {
        guard let left = auxiliaryTopLeftArea, let right = auxiliaryTopRightArea else { return nil }
        return right.minX - left.maxX
    }

    var displayID: UInt32? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }

    var displayUUID: String? {
        guard let displayID, let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue() else { return nil }
        return CFUUIDCreateString(nil, uuid) as String?
    }
}
