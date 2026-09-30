import AppKit
import Combine
import Foundation
import ServiceManagement
import UserNotifications

enum CompactActivity: Equatable {
    case idle
    case charging(percent: Int)
    case meeting(minutes: Int)
    case music
    case limit(remaining: Int)
}

@MainActor
final class AppState: ObservableObject {
    nonisolated static let wingWidth: CGFloat = 40
    nonisolated static let lowLimitThreshold = 20

    @Published var expanded = false
    @Published var selectedTab: Tab = .home
    @Published var settingsPage: SettingsPage? = .general
    @Published var notchWidth: CGFloat?
    @Published var notchHeight: CGFloat = 0
    @Published private(set) var activity: CompactActivity = .idle
    @Published var displayedActivity: CompactActivity = .idle
    @Published var language = AppLanguage(rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? "") ?? .system {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "appLanguage") }
    }
    @Published var appearance = AppAppearance(rawValue: UserDefaults.standard.string(forKey: "appAppearance") ?? "") ?? .system {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: "appAppearance") }
    }
    @Published var musicEnabled = UserDefaults.standard.bool(forKey: "musicEnabled") {
        didSet {
            UserDefaults.standard.set(musicEnabled, forKey: "musicEnabled")
            configureMediaSource()
            if !musicEnabled { track = nil }
        }
    }
    // Kengaytirilgan musiqa rejimi faqat foydalanuvchi roziligi bilan yoqiladi (standart — rasmiy usul).
    @Published private(set) var extendedMediaEnabled = UserDefaults.standard.bool(forKey: "extendedMediaEnabled")
    @Published var hoverEnabled = UserDefaults.standard.bool(forKey: "hoverEnabled") {
        didSet { UserDefaults.standard.set(hoverEnabled, forKey: "hoverEnabled") }
    }
    @Published var compactStyle = CompactStyle(rawValue: UserDefaults.standard.string(forKey: "compactStyle") ?? "") ?? .standard {
        didSet { UserDefaults.standard.set(compactStyle.rawValue, forKey: "compactStyle"); onGeometryChange?() }
    }
    @Published var expandedStyle = ExpandedStyle(rawValue: UserDefaults.standard.string(forKey: "expandedStyle") ?? "") ?? .blended {
        didSet { UserDefaults.standard.set(expandedStyle.rawValue, forKey: "expandedStyle"); onGeometryChange?() }
    }
    @Published var panelSize = PanelSize(rawValue: UserDefaults.standard.string(forKey: "panelSize") ?? "") ?? .standard {
        didSet { UserDefaults.standard.set(panelSize.rawValue, forKey: "panelSize"); onGeometryChange?() }
    }
    @Published var tabPlacement = TabPlacement(rawValue: UserDefaults.standard.string(forKey: "tabPlacement") ?? "") ?? .bottom {
        didSet { UserDefaults.standard.set(tabPlacement.rawValue, forKey: "tabPlacement") }
    }
    @Published var tabLabelStyle = TabLabelStyle(rawValue: UserDefaults.standard.string(forKey: "tabLabelStyle") ?? "") ?? .iconAndText {
        didSet { UserDefaults.standard.set(tabLabelStyle.rawValue, forKey: "tabLabelStyle") }
    }
    @Published var reduceMotion = UserDefaults.standard.bool(forKey: "reduceMotion") {
        didSet { UserDefaults.standard.set(reduceMotion, forKey: "reduceMotion") }
    }
    @Published var limitAlertsEnabled = (UserDefaults.standard.object(forKey: "limitAlertsEnabled") as? Bool) ?? true {
        didSet {
            UserDefaults.standard.set(limitAlertsEnabled, forKey: "limitAlertsEnabled")
            if limitAlertsEnabled { requestNotificationAccess() }
        }
    }
    @Published var chargingAlertEnabled = (UserDefaults.standard.object(forKey: "chargingAlertEnabled") as? Bool) ?? true {
        didSet { UserDefaults.standard.set(chargingAlertEnabled, forKey: "chargingAlertEnabled") }
    }
    @Published var hotKeysEnabled = (UserDefaults.standard.object(forKey: "hotKeysEnabled") as? Bool) ?? true {
        didSet {
            UserDefaults.standard.set(hotKeysEnabled, forKey: "hotKeysEnabled")
            onHotKeysChange?()
        }
    }
    @Published var hotKeyMessage: String?
    // Bo'sh — avtomatik (notchli ekran, bo'lmasa asosiy ekran). UUID qayta ulanishda o'zgarmaydi.
    @Published var displayUUID = UserDefaults.standard.string(forKey: "displayUUID") ?? "" {
        didSet {
            UserDefaults.standard.set(displayUUID, forKey: "displayUUID")
            onScreenRuleChange?()
        }
    }
    @Published var showOnAllScreens = UserDefaults.standard.bool(forKey: "showOnAllScreens") {
        didSet {
            UserDefaults.standard.set(showOnAllScreens, forKey: "showOnAllScreens")
            onScreenRuleChange?()
        }
    }
    @Published var onlyNotchScreen = UserDefaults.standard.bool(forKey: "onlyNotchScreen") {
        didSet {
            UserDefaults.standard.set(onlyNotchScreen, forKey: "onlyNotchScreen")
            onVisibilityRuleChange?()
        }
    }
    @Published var clipboardSearchRequest = 0
    @Published var hideInFullscreen = (UserDefaults.standard.object(forKey: "hideInFullscreen") as? Bool) ?? true {
        didSet {
            UserDefaults.standard.set(hideInFullscreen, forKey: "hideInFullscreen")
            onVisibilityRuleChange?()
        }
    }
    @Published var codexEnabled = (UserDefaults.standard.object(forKey: "codexEnabled") as? Bool) ?? true {
        didSet {
            UserDefaults.standard.set(codexEnabled, forKey: "codexEnabled")
            if codexEnabled { refreshCodex() }
            else { codexUsage = nil; codexError = nil }
        }
    }
    @Published var clipboardEnabled = UserDefaults.standard.bool(forKey: "clipboardEnabled") {
        didSet {
            UserDefaults.standard.set(clipboardEnabled, forKey: "clipboardEnabled")
            configureClipboardTimer()
        }
    }
    @Published private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled
    @Published var launchAtLoginMessage: String?
    @Published var codexUsage: UsageSnapshot? {
        didSet { usageChanged() }
    }
    @Published var codexError: String?
    @Published var claudeUsage: UsageSnapshot? {
        didSet { usageChanged() }
    }
    @Published var claudeInstalled = ClaudeStatusBridge.isInstalled()
    @Published var claudeMessage: String?
    @Published private(set) var permissionHookInstalled = ClaudeStatusBridge.isPermissionHookInstalled()
    @Published var permissionMessage: String?
    @Published private(set) var codexHookInstalled = CodexHookBridge.isInstalled()
    @Published var codexHookMessage: String?
    @Published private(set) var musicPermissionDenied = false
    // Har body'da fayl tizimini tekshirmaslik uchun Codex yangilanganda keshlanadi.
    @Published private(set) var codexInstalled = CodexUsageService.isInstalled
    @Published private(set) var hasSeenWelcome = UserDefaults.standard.bool(forKey: "hasSeenWelcome")
    @Published var track: TrackInfo? {
        didSet { updateActivity() }
    }
    let clipboard = ClipboardService()
    let calendar = CalendarService()
    let weather = WeatherService()
    let shelf = ShelfService()
    let power = PowerService()
    let widgets = WidgetStore()
    let customRunners = CustomWidgetRunners()
    let stats = SystemStatsService()
    let media = MediaRemoteService()
    var onExpand: (() -> Void)?
    var onCollapse: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onVisibilityRuleChange: (() -> Void)?
    var onScreenRuleChange: (() -> Void)?
    var onHotKeysChange: (() -> Void)?
    var onFocusPanel: (() -> Void)?
    var onGeometryChange: (() -> Void)?
    private var chargingUntil: Date?
    private var aiEventServer: AIEventServer?
    private(set) var openedByHover = false
    private var pulseTimer: Timer?
    private var clipboardTimer: Timer?
    private var ticks = 0
    private var codexFetching = false
    private var codexFetchedAt: Date?
    private var musicFetching = false
    private var musicPending = false
    private var claudeCacheDate: Date?
    private var hoverTask: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    private var notifying: Set<String> = []

    enum Tab: String, CaseIterable {
        case home = "Asosiy", clips = "Clipboard", shelf = "Tokcha"

        var title: String { L10n.tr(rawValue) }

        var icon: String {
            switch self {
            case .home: "square.grid.2x2.fill"
            case .clips: "doc.on.clipboard.fill"
            case .shelf: "tray.fill"
            }
        }
    }

    // Panel geometriyasi: delegate va RootView bir xil qiymatlardan foydalanadi.
    nonisolated static let compactFlare: CGFloat = 6
    nonisolated static let expandedFlare: CGFloat = 12
    nonisolated static let tabBarHeight: CGFloat = 32
    nonisolated static let tabGap: CGFloat = 8
    nonisolated static let bottomInset: CGFloat = 14

    var compactFlare: CGFloat { notchWidth != nil && compactStyle == .blended ? Self.compactFlare : 0 }
    var expandedFlare: CGFloat { notchWidth != nil && expandedStyle == .blended ? Self.expandedFlare : 0 }
    var expandedAttached: Bool { notchWidth != nil && expandedStyle.attachedToTop }

    // Notchli ekranda sarlavha qatori notch balandligiga teng (suzuvchi uslubda panel 2 pt pastda).
    var headerHeight: CGFloat {
        guard notchHeight > 0 else { return 26 }
        return expandedAttached ? notchHeight : notchHeight - 2
    }

    // Sarlavha + uning paddinglari (RootView bilan bir xil: notchda 0/6, aks holda 10/10).
    var headerBlockHeight: CGFloat { headerHeight + (notchHeight > 0 ? 6 : 20) }

    var expandedPanelSize: CGSize {
        let content = panelSize.contentSize
        let height = headerBlockHeight + content.height + Self.tabBarHeight + Self.tabGap + Self.bottomInset
        return CGSize(width: content.width + expandedFlare * 2, height: height)
    }

    init() {
        // Sekin zaxira tekshiruv; musiqa o'zgarishlari asosan bildirishnoma orqali keladi.
        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pulse() }
        }
        timer.tolerance = 1
        RunLoop.main.add(timer, forMode: .common)
        pulseTimer = timer
        let center = DistributedNotificationCenter.default()
        for name in ["com.spotify.client.PlaybackStateChanged", "com.apple.Music.playerInfo"] {
            observers.append(center.addObserver(forName: Notification.Name(name), object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refreshMusic() }
            })
        }
        power.onPluggedIn = { [weak self] in self?.showCharging() }
        media.onUpdate = { [weak self] track in
            guard let self, self.musicEnabled, self.extendedMediaEnabled else { return }
            self.track = track
            if track == nil { self.refreshMusic() }
        }
        media.onFallback = { [weak self] in self?.refreshMusic() }
        configureMediaSource()
        configureClipboardTimer()
        if musicEnabled { refreshMusic() }
        refreshClaudeUsage()
        if codexEnabled { refreshCodex() }
        Task { await weather.refresh() }
        // Boshqa AI dasturlarning mahalliy hook'lari ham shu socketga xabar yubora oladi.
        startAIEventServer()
    }

    private func pulse() {
        ticks += 1
        if musicEnabled && (expanded || ticks % 6 == 0) { refreshMusic() }
        refreshClaudeUsage()
        updateActivity()
        if ticks % 60 == 0 { calendar.refresh() }
        if codexEnabled && ticks % 60 == 0 { refreshCodex() }
        if ticks % 120 == 0 { Task { await weather.refresh() } }
    }

    var motionReduced: Bool { reduceMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    // Ustuvorlik: zaryad (qisqa) > yaqin uchrashuv > ijrodagi musiqa > kam qolgan limit.
    private func updateActivity() {
        let now = Date()
        var next: CompactActivity = .idle
        if let chargingUntil, chargingUntil > now, let percent = power.percent {
            next = .charging(percent: percent)
        } else if let event = calendar.events.first(where: { $0.start.timeIntervalSince(now) <= 300 && now.timeIntervalSince($0.start) <= 60 }) {
            next = .meeting(minutes: max(0, event.minutesUntilStart(from: now)))
        } else if track?.playing == true {
            next = .music
        } else if let lowest = lowestRemaining(at: now), lowest <= Self.lowLimitThreshold {
            next = .limit(remaining: lowest)
        }
        if next != activity { activity = next }
    }

    private func showCharging() {
        guard chargingAlertEnabled else { return }
        chargingUntil = Date().addingTimeInterval(3)
        updateActivity()
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(3100))
            self?.updateActivity()
        }
    }

    func openClipboardSearch() {
        selectedTab = .clips
        clipboardSearchRequest += 1
        markInteracted()
        if expanded { onFocusPanel?() } else { requestExpand() }
    }

    func openShelfForDrop() {
        guard !expanded else { selectedTab = .shelf; return }
        selectedTab = .shelf
        requestExpand(byHover: true)
    }

    private func lowestRemaining(at now: Date) -> Int? {
        [codexUsage?.lowestRemaining(at: now), claudeUsage?.lowestRemaining(at: now)].compactMap { $0 }.min()
    }

    private func usageChanged() {
        updateActivity()
        notifyLowLimits()
    }

    private var notificationsAvailable: Bool { Bundle.main.bundleIdentifier != nil && Bundle.main.bundleURL.pathExtension == "app" }

    private func requestNotificationAccess() {
        guard notificationsAvailable else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    // Har bir limit oynasi uchun reset davrida bir marta xabar beriladi.
    private func notifyLowLimits() {
        guard limitAlertsEnabled, notificationsAvailable else { return }
        let now = Date()
        let sent = Set(UserDefaults.standard.stringArray(forKey: "notifiedLimits") ?? [])
        let entries: [(String, [(String, UsageWindow?)], UsageSnapshot?)] = [
            ("Codex", [("Asosiy", codexUsage?.primary), ("Qo‘shimcha", codexUsage?.secondary)], codexUsage),
            ("Claude", [("5 soat", claudeUsage?.primary), ("7 kun", claudeUsage?.secondary)], claudeUsage)
        ]
        var pending: [(key: String, title: String, body: String)] = []
        for (name, windows, snapshot) in entries {
            guard let snapshot, !snapshot.isStale(at: now) else { continue }
            for (label, window) in windows {
                guard let window, window.remainingPercent <= Self.lowLimitThreshold, !window.hasReset(at: now) else { continue }
                let key = "\(name)|\(label)|\(Int(window.resetAt?.timeIntervalSince1970 ?? 0))"
                guard !sent.contains(key), !notifying.contains(key) else { continue }
                var body = L10n.format("%@: %d%% qoldi.", L10n.tr(label), window.remainingPercent)
                if let reset = window.resetAt { body += L10n.format(" Tiklanish: %@.", reset.formatted(date: .omitted, time: .shortened)) }
                pending.append((key, L10n.format("%@ limiti kam qoldi", name), body))
            }
        }
        guard !pending.isEmpty else { return }
        notifying.formUnion(pending.map(\.key))
        Task {
            let center = UNUserNotificationCenter.current()
            var status = await center.notificationSettings().authorizationStatus
            if status == .notDetermined {
                _ = try? await center.requestAuthorization(options: [.alert, .sound])
                status = await center.notificationSettings().authorizationStatus
            }
            if status == .authorized || status == .provisional {
                for item in pending {
                    let content = UNMutableNotificationContent()
                    content.title = item.title
                    content.body = item.body
                    if (try? await center.add(UNNotificationRequest(identifier: item.key, content: content, trigger: nil))) != nil {
                        markNotified(item.key)
                    }
                }
            }
            notifying.subtract(pending.map(\.key))
        }
    }

    // Reset vaqti o'tgan kalitlar keraksiz; vaqtsiz kalitlardan oxirgi 20 tasi qoladi.
    private func markNotified(_ key: String) {
        let now = Date().timeIntervalSince1970
        var keys = (UserDefaults.standard.stringArray(forKey: "notifiedLimits") ?? []).filter { stored in
            guard let stamp = stored.split(separator: "|").last.flatMap({ Double($0) }), stamp > 0 else { return true }
            return stamp > now
        }
        keys.append(key)
        let untimed = keys.filter { $0.hasSuffix("|0") }
        if untimed.count > 20 {
            let drop = Set(untimed.prefix(untimed.count - 20))
            keys.removeAll { drop.contains($0) }
        }
        UserDefaults.standard.set(keys, forKey: "notifiedLimits")
    }

    private func refreshClaudeUsage() {
        guard claudeInstalled else {
            if claudeUsage != nil { claudeUsage = nil }
            claudeCacheDate = nil
            return
        }
        let modified = (try? FileManager.default.attributesOfItem(atPath: ClaudeStatusBridge.cacheURL.path))?[.modificationDate] as? Date
        guard modified != claudeCacheDate else { return }
        claudeCacheDate = modified
        claudeUsage = ClaudeUsageService.cached()
    }

    // Kengaytirilgan rejim trek bersa AppleScript chaqirilmaydi. Rejim ishga tushayotgan bo'lsa ham kutiladi;
    // u hech narsa topmasa (masalan, jim ishlamay qolgan bo'lsa), Spotify/Music baribir tekshiriladi.
    private var appleScriptAllowed: Bool {
        MusicSourcePolicy.appleScriptAllowed(status: media.status, recovering: media.recovering, hasMediaTrack: media.lastTrack != nil)
    }

    func refreshMusic() {
        guard musicEnabled, appleScriptAllowed else { return }
        guard !musicFetching else { musicPending = true; return }
        musicFetching = true
        Task { [weak self] in
            let probe = await Task.detached(priority: .utility) { MusicService.current() }.value
            guard let self else { return }
            self.musicFetching = false
            // Shu orada kengaytirilgan rejim trek bergan bo'lsa, kechikkan AppleScript natijasi uni bosmaydi.
            if self.musicEnabled && self.appleScriptAllowed {
                self.track = probe.track
                self.musicPermissionDenied = probe.permissionDenied
            }
            if self.musicPending {
                self.musicPending = false
                self.refreshMusic()
            }
        }
    }

    func requestExpand(byHover: Bool = false) {
        hoverTask?.cancel()
        hoverTask = nil
        openedByHover = byHover
        onExpand?()
    }

    func markInteracted() {
        openedByHover = false
    }

    // MARK: AI savol va ruxsat bildirishnomalari

    func setPermissionHook(_ enabled: Bool) {
        permissionMessage = enabled ? ClaudeStatusBridge.installPermissionHook() : ClaudeStatusBridge.uninstallPermissionHook()
        permissionHookInstalled = ClaudeStatusBridge.isPermissionHookInstalled()
        startAIEventServer()
        if enabled && permissionHookInstalled { requestNotificationAccess() }
    }

    func setCodexHook(_ enabled: Bool) {
        codexHookMessage = enabled ? CodexHookBridge.install() : CodexHookBridge.uninstall()
        codexHookInstalled = CodexHookBridge.isInstalled()
        startAIEventServer()
        if enabled && codexHookInstalled { requestNotificationAccess() }
    }

    private func startAIEventServer() {
        guard aiEventServer == nil else { return }
        let server = AIEventServer(onEvent: { [weak self] event in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.receiveAIEvent(event) } }
        })
        server.start()
        aiEventServer = server
    }

    // Kutilayotgan hook'lar darhol uziladi va Claude odatiy so'rovga qaytadi.
    func dismissWelcome() {
        hasSeenWelcome = true
        UserDefaults.standard.set(true, forKey: "hasSeenWelcome")
    }

    func widgetContext(now: Date = Date()) -> WidgetContext {
        WidgetContext(
            // Kengaytirilgan rejim trek bersa Automation ruxsati ahamiyatsiz.
            musicEnabled: musicEnabled,
            musicPermissionDenied: musicPermissionDenied && track == nil,
            calendarAccess: calendar.access,
            hasUpcomingEvents: calendar.events.contains { $0.end > now },
            weatherCityConfigured: !(UserDefaults.standard.string(forKey: "weatherCity") ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            hasWeather: weather.weather != nil,
            weatherError: weather.errorMessage,
            clipboardEnabled: clipboardEnabled,
            hasClips: !(clipboard.items.isEmpty && clipboard.pinned.isEmpty),
            codexEnabled: codexEnabled,
            codexInstalled: codexInstalled,
            hasCodexUsage: codexUsage != nil,
            codexError: codexError,
            claudeInstalled: claudeInstalled,
            hasClaudeUsage: claudeUsage != nil
        )
    }

    func perform(_ action: SetupAction) {
        switch action {
        case .openSettings(let page): showSettings(page)
        case .requestCalendarAccess: calendar.requestAccess()
        case .openCalendarPrivacy: openPrivacyPane("Privacy_Calendars")
        case .openAutomationPrivacy: openPrivacyPane("Privacy_Automation")
        }
    }

    // macOS 13+ yangi manzil, ochilmasa eski manzil.
    private func openPrivacyPane(_ anchor: String) {
        for base in ["x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension", "x-apple.systempreferences:com.apple.preference.security"] {
            if let url = URL(string: "\(base)?\(anchor)"), NSWorkspace.shared.open(url) { return }
        }
    }

    func setExtendedMedia(_ enabled: Bool) {
        extendedMediaEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "extendedMediaEnabled")
        configureMediaSource()
    }

    private func configureMediaSource() {
        musicPermissionDenied = false
        if musicEnabled && extendedMediaEnabled {
            media.start()
        } else {
            media.stop()
        }
        refreshMusic()
    }

    var canSeekMusic: Bool { media.available && media.lastTrack != nil }

    func seekMusic(to fraction: Double) {
        guard musicEnabled, canSeekMusic, let track, track.duration > 0 else { return }
        media.seek(to: track.duration * min(1, max(0, fraction)))
    }

    func shutdown() {
        stopAIEventServer()
        media.stop()
    }

    private func stopAIEventServer() {
        aiEventServer?.stop()
        aiEventServer = nil
    }

    private func receiveAIEvent(_ request: AIEvent) {
        // Socket darhol yopiladi: AI dasturining o'z savoli/tasdig'i faol qoladi.
        aiEventServer?.finish(request.id)
        let title: String
        switch request.tool {
        case "AskUserQuestion": title = L10n.format("%@ savol berdi", request.provider)
        case "ExitPlanMode": title = L10n.format("%@ reja bo‘yicha javob kutmoqda", request.provider)
        case "": title = L10n.format("%@ e’tibor kutmoqda", request.provider)
        default: title = L10n.format("%@ ruxsat kutmoqda", request.provider)
        }
        let body = request.project.isEmpty ? request.summary : "\(request.project): \(request.summary)"
        notifyAgent(title: title, body: body)
    }

    private func notifyAgent(title: String, body: String) {
        guard notificationsAvailable else { return }
        Task {
            let center = UNUserNotificationCenter.current()
            var status = await center.notificationSettings().authorizationStatus
            if status == .notDetermined {
                _ = try? await center.requestAuthorization(options: [.alert, .sound])
                status = await center.notificationSettings().authorizationStatus
            }
            guard status == .authorized || status == .provisional else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            _ = try? await center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }

    func handleCompactHover(_ inside: Bool) {
        hoverTask?.cancel()
        hoverTask = nil
        guard inside, hoverEnabled, !expanded else { return }
        hoverTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            self?.requestExpand(byHover: true)
        }
    }

    func showSettings(_ page: SettingsPage = .general) {
        settingsPage = page
        onOpenSettings?()
    }

    func refreshLaunchAtLogin() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginMessage = nil
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            launchAtLoginMessage = error.localizedDescription
        }
        let status = SMAppService.mainApp.status
        launchAtLogin = status == .enabled
        if status == .requiresApproval {
            launchAtLoginMessage = "Tizim sozlamalari → Login Items bo‘limida TopNest’ga ruxsat bering."
            SMAppService.openSystemSettingsLoginItems()
        }
    }

    private func configureClipboardTimer() {
        clipboardTimer?.invalidate()
        clipboardTimer = nil
        guard clipboardEnabled else { return }
        clipboard.check(enabled: false)
        let timer = Timer(timeInterval: 0.75, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.clipboard.check(enabled: true) }
        }
        timer.tolerance = 0.25
        RunLoop.main.add(timer, forMode: .common)
        clipboardTimer = timer
    }

    func refreshCodex(ifOlderThan age: TimeInterval = 0) {
        guard codexEnabled, !codexFetching else { return }
        if age > 0, let codexFetchedAt, Date().timeIntervalSince(codexFetchedAt) < age { return }
        codexFetching = true
        codexFetchedAt = Date()
        let installed = CodexUsageService.isInstalled
        if installed != codexInstalled { codexInstalled = installed }
        Task { [weak self] in
            let result = await Task.detached(priority: .utility) { CodexUsageService.fetch() }.value
            guard let self else { return }
            self.codexFetching = false
            guard self.codexEnabled else { return }
            switch result {
            case .success(let snapshot): self.codexUsage = snapshot; self.codexError = nil
            case .failure(let error): self.codexError = error.localizedDescription
            }
        }
    }

    func controlMusic(_ action: String) {
        guard musicEnabled, let track else { return }
        // Trek kengaytirilgan rejimdan kelgan bo'lsa buyruq ham u orqali, aks holda AppleScript.
        if media.available && media.lastTrack != nil {
            let command: MediaRemoteService.Command? = ["playpause": .togglePlayPause, "next track": .next, "previous track": .previous][action]
            if let command { media.send(command) }
            return
        }
        Task { [weak self] in
            await Task.detached(priority: .userInitiated) {
                MusicService.control(bundleID: track.bundleID, action: action)
            }.value
            self?.refreshMusic()
        }
    }

    func installClaude() {
        // Oldingi ulanishdan qolgan cache yangi ulanishda eskirgan limit sifatida ko'rinmasin.
        if !claudeInstalled { try? FileManager.default.removeItem(at: ClaudeStatusBridge.cacheURL) }
        claudeMessage = ClaudeStatusBridge.install()
        claudeInstalled = ClaudeStatusBridge.isInstalled()
        refreshClaudeUsage()
    }

    func uninstallClaude() {
        claudeMessage = ClaudeStatusBridge.uninstall()
        claudeInstalled = ClaudeStatusBridge.isInstalled()
        refreshClaudeUsage()
    }
}
