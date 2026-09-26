import AppKit
import Combine
import Foundation
import ServiceManagement

enum CompactActivity: Equatable {
    case idle
    case music
}

@MainActor
final class AppState: ObservableObject {
    static let wingWidth: CGFloat = 40

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
    @Published var codexUsage: UsageSnapshot?
    @Published var codexError: String?
    @Published var claudeUsage: UsageSnapshot?
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
        if ticks % 60 == 0 { calendar.refresh() }
        if codexEnabled && ticks % 60 == 0 { refreshCodex() }
        if ticks % 120 == 0 { Task { await weather.refresh() } }
    }

    private func updateActivity() {
        let next: CompactActivity = (track?.playing == true) ? .music : .idle
        if next != activity { activity = next }
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
