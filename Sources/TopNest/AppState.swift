import AppKit
import Combine
import Foundation
import ServiceManagement
import UserNotifications

enum CompactActivity: Equatable {
    case idle
    case meeting(minutes: Int)
    case music
    case limit(remaining: Int)
}

enum HomeCard: String, CaseIterable, Identifiable {
    case music, calendar, weather, clipboard, limits

    var id: Self { self }

    var title: String {
        switch self {
        case .music: "Hozir ijroda"
        case .calendar: "Kalendar"
        case .weather: "Ob-havo"
        case .clipboard: "Clipboard"
        case .limits: "AI limitlari"
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    nonisolated static let wingWidth: CGFloat = 40
    nonisolated static let lowLimitThreshold = 20

    @Published var expanded = false
    @Published var selectedTab: Tab = .home
    @Published var settingsPage: SettingsPage? = .general
    @Published var notchWidth: CGFloat?
    @Published private(set) var activity: CompactActivity = .idle
    @Published var displayedActivity: CompactActivity = .idle
    @Published var musicEnabled = UserDefaults.standard.bool(forKey: "musicEnabled") {
        didSet {
            UserDefaults.standard.set(musicEnabled, forKey: "musicEnabled")
            if musicEnabled { refreshMusic() }
            else { track = nil }
        }
    }
    @Published var hoverEnabled = UserDefaults.standard.bool(forKey: "hoverEnabled") {
        didSet { UserDefaults.standard.set(hoverEnabled, forKey: "hoverEnabled") }
    }
    @Published var reduceMotion = UserDefaults.standard.bool(forKey: "reduceMotion") {
        didSet { UserDefaults.standard.set(reduceMotion, forKey: "reduceMotion") }
    }
    @Published private(set) var hiddenCards = Set((UserDefaults.standard.stringArray(forKey: "hiddenCards") ?? []).compactMap(HomeCard.init(rawValue:)))
    @Published var limitAlertsEnabled = (UserDefaults.standard.object(forKey: "limitAlertsEnabled") as? Bool) ?? true {
        didSet {
            UserDefaults.standard.set(limitAlertsEnabled, forKey: "limitAlertsEnabled")
            if limitAlertsEnabled { requestNotificationAccess() }
        }
    }
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
    @Published var track: TrackInfo? {
        didSet { updateActivity() }
    }
    let clipboard = ClipboardService()
    let calendar = CalendarService()
    let weather = WeatherService()
    var onExpand: (() -> Void)?
    var onCollapse: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onVisibilityRuleChange: (() -> Void)?
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

    enum Tab: String, CaseIterable { case home = "Asosiy", clips = "Clipboard" }

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
        configureClipboardTimer()
        if musicEnabled { refreshMusic() }
        refreshClaudeUsage()
        if codexEnabled { refreshCodex() }
        Task { await weather.refresh() }
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

    func isCardVisible(_ card: HomeCard) -> Bool { !hiddenCards.contains(card) }

    func setCard(_ card: HomeCard, visible: Bool) {
        if visible { hiddenCards.remove(card) } else { hiddenCards.insert(card) }
        UserDefaults.standard.set(hiddenCards.map(\.rawValue), forKey: "hiddenCards")
    }

    // Ustuvorlik: yaqin uchrashuv > ijrodagi musiqa > kam qolgan limit.
    private func updateActivity() {
        let now = Date()
        var next: CompactActivity = .idle
        if let event = calendar.events.first(where: { $0.start.timeIntervalSince(now) <= 300 && now.timeIntervalSince($0.start) <= 60 }) {
            next = .meeting(minutes: max(0, event.minutesUntilStart(from: now)))
        } else if track?.playing == true {
            next = .music
        } else if let lowest = lowestRemaining(at: now), lowest <= Self.lowLimitThreshold {
            next = .limit(remaining: lowest)
        }
        if next != activity { activity = next }
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
                var body = "\(label): \(window.remainingPercent)% qoldi."
                if let reset = window.resetAt { body += " Tiklanish: \(reset.formatted(date: .omitted, time: .shortened))." }
                pending.append((key, "\(name) limiti kam qoldi", body))
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

    func refreshMusic() {
        guard musicEnabled else { return }
        guard !musicFetching else { musicPending = true; return }
        musicFetching = true
        Task { [weak self] in
            let latest = await Task.detached(priority: .utility) { MusicService.current() }.value
            guard let self else { return }
            self.musicFetching = false
            if self.musicEnabled { self.track = latest }
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

    func markInteracted() { openedByHover = false }

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
        Task { [weak self] in
            await Task.detached(priority: .userInitiated) {
                MusicService.control(bundleID: track.bundleID, action: action)
            }.value
            self?.refreshMusic()
        }
    }

    func installClaude() {
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
