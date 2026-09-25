import AppKit
import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var expanded = false
    @Published var selectedTab: Tab = .home
    @Published var settingsPage: SettingsPage? = .general
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
    @Published var codexUsage: UsageSnapshot?
    @Published var codexError: String?
    @Published var claudeUsage: UsageSnapshot?
    @Published var claudeInstalled = ClaudeStatusBridge.isInstalled()
    @Published var claudeMessage: String?
    @Published var track: TrackInfo?
    let clipboard = ClipboardService()
    let calendar = CalendarService()
    let weather = WeatherService()
    var onExpand: (() -> Void)?
    var onCollapse: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    private var pulseTimer: Timer?
    private var clipboardTimer: Timer?
    private var slowTicks = 0
    private var codexFetching = false
    private var musicFetching = false
    private var hoverTask: Task<Void, Never>?

    enum Tab: String, CaseIterable { case home = "Asosiy", clips = "Clipboard" }

    init() {
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pulse() }
        }
        configureClipboardTimer()
        pulse()
        if codexEnabled { refreshCodex() }
        Task { await weather.refresh() }
    }

    private func pulse() {
        if musicEnabled { refreshMusic() }
        claudeUsage = claudeInstalled ? ClaudeUsageService.cached() : nil
        slowTicks += 1
        if slowTicks % 20 == 0 { calendar.refresh() }
        if codexEnabled && slowTicks % 40 == 0 { refreshCodex() }
        if slowTicks % 200 == 0 { Task { await weather.refresh() } }
    }

    func refreshMusic() {
        guard musicEnabled, !musicFetching else { return }
        musicFetching = true
        Task { [weak self] in
            let latest = await Task.detached(priority: .utility) { MusicService.current() }.value
            guard let self else { return }
            self.musicFetching = false
            if self.musicEnabled { self.track = latest }
        }
    }

    func handleCompactHover(_ inside: Bool) {
        hoverTask?.cancel()
        hoverTask = nil
        guard inside, hoverEnabled, !expanded else { return }
        hoverTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            self?.onExpand?()
        }
    }

    func showSettings(_ page: SettingsPage = .general) {
        settingsPage = page
        onOpenSettings?()
    }

    private func configureClipboardTimer() {
        clipboardTimer?.invalidate()
        clipboardTimer = nil
        guard clipboardEnabled else { return }
        clipboard.check(enabled: false)
        clipboardTimer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.clipboard.check(enabled: true) }
        }
    }

    func refreshCodex() {
        guard codexEnabled, !codexFetching else { return }
        codexFetching = true
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
    }

    func uninstallClaude() {
        claudeMessage = ClaudeStatusBridge.uninstall()
        claudeInstalled = ClaudeStatusBridge.isInstalled()
        claudeUsage = nil
    }
}
