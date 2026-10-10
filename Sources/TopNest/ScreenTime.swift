import AppKit
import CoreGraphics
import Foundation

// Kunlik ilova vaqtlari: kun → bundle ID → soniya. UI va tizim hodisalaridan mustaqil, test qilinadi.
struct ScreenTimeLedger: Codable, Equatable {
    static let keepDays = 30

    var days: [String: [String: Double]] = [:]
    var names: [String: String] = [:]

    static func key(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    // Yarim tundan o'tgan oraliq ikki kunga bo'linadi.
    mutating func add(_ bundleID: String, from start: Date, to end: Date, calendar: Calendar = .current) {
        guard end > start else { return }
        var cursor = start
        while cursor < end {
            let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: cursor)) ?? end
            let segmentEnd = min(end, nextDay)
            days[Self.key(for: cursor, calendar: calendar), default: [:]][bundleID, default: 0] += segmentEnd.timeIntervalSince(cursor)
            cursor = segmentEnd
        }
    }

    func total(on date: Date, calendar: Calendar = .current) -> Double {
        days[Self.key(for: date, calendar: calendar)]?.values.reduce(0, +) ?? 0
    }

    func top(on date: Date, limit: Int, calendar: Calendar = .current) -> [(bundleID: String, seconds: Double)] {
        (days[Self.key(for: date, calendar: calendar)] ?? [:])
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { ($0.key, $0.value) }
    }

    // Oxirgi 7 kun (eskisidan bugungacha).
    func week(endingAt date: Date, calendar: Calendar = .current) -> [(day: Date, seconds: Double)] {
        let today = calendar.startOfDay(for: date)
        return (0..<7).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today).map { ($0, total(on: $0, calendar: calendar)) }
        }
    }

    mutating func prune(now: Date, calendar: Calendar = .current) {
        guard let cutoff = calendar.date(byAdding: .day, value: -Self.keepDays, to: calendar.startOfDay(for: now)) else { return }
        let oldest = Self.key(for: cutoff, calendar: calendar)
        // "yyyy-MM-dd" kalitlari matn sifatida ham sana tartibida.
        days = days.filter { $0.key >= oldest }
        let used = Set(days.values.flatMap(\.keys))
        names = names.filter { used.contains($0.key) }
    }
}

// Uzluksiz ish: 5 daqiqadan ko'p faolsizlik yoki ekran qulfi hisobni nolga tushiradi.
struct BreakPolicy {
    var limit: TimeInterval
    var resetAfterIdle: TimeInterval = 300
    private(set) var streakStart: Date?
    private var reminded = false

    init(limit: TimeInterval) { self.limit = limit }

    // Uyqu, ekran qulfi yoki uzoq tanaffus: hisob boshidan.
    mutating func reset() {
        streakStart = nil
        reminded = false
    }

    // true — tanaffus eslatmasini ko'rsatish vaqti.
    mutating func feed(active: Bool, idle: TimeInterval, at now: Date) -> Bool {
        guard active, idle < resetAfterIdle else {
            streakStart = nil
            reminded = false
            return false
        }
        let start = streakStart ?? now
        streakStart = start
        guard !reminded, now.timeIntervalSince(start) >= limit else { return false }
        reminded = true
        return true
    }
}

enum ScreenTimeFormat {
    // "3 s 25 daq", "45 daq", "<1 daq".
    static func duration(_ seconds: Double) -> String {
        let minutes = Int(seconds / 60)
        if minutes < 1 { return L10n.tr("<1 daq") }
        if minutes < 60 { return L10n.format("%d daq", minutes) }
        if minutes % 60 == 0 { return L10n.format("%d s", minutes / 60) }
        return L10n.format("%d s %d daq", minutes / 60, minutes % 60)
    }
}

// TopNest o'zi hisoblaydi: faol ilova, faolsizlik (2 daqiqa), ekran qulfi va uyqu. Ma'lumot faqat shu Mac'da.
@MainActor
final class ScreenTimeTracker: ObservableObject {
    static let idleThreshold: TimeInterval = 120

    @Published private(set) var ledger: ScreenTimeLedger
    var onBreakReminder: ((TimeInterval) -> Void)?
    var breakLimit: TimeInterval = 90 * 60 {
        didSet { breakPolicy.limit = breakLimit }
    }
    private let store: JSONFileStore<ScreenTimeLedger>
    private var current: (bundleID: String, since: Date)?
    private var locked = false
    private var asleep = false
    private var timer: Timer?
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var breakPolicy = BreakPolicy(limit: 90 * 60)
    private var lastSave = Date()
    private var lastTick = Date()
    // Bitta yozuv bundan uzun bo'lmaydi: uyqu hodisasi o'tkazib yuborilsa ham uyqu vaqti hisoblanmaydi.
    static let maxCommit: TimeInterval = 600
    private(set) var running = false

    init(store: JSONFileStore<ScreenTimeLedger> = JSONFileStore("screen-time.json")) {
        self.store = store
        ledger = store.load() ?? ScreenTimeLedger()
    }

    func setEnabled(_ enabled: Bool) {
        enabled ? start() : stop()
    }

    private func start() {
        guard !running else { return }
        running = true
        let workspace = NSWorkspace.shared.notificationCenter
        let distributed = DistributedNotificationCenter.default()
        func observe(_ center: NotificationCenter, _ name: Notification.Name, _ handler: @escaping @MainActor () -> Void) {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { _ in MainActor.assumeIsolated { handler() } }
            observers.append((center, token))
        }
        observe(workspace, NSWorkspace.didActivateApplicationNotification) { [weak self] in self?.switchToFrontmost() }
        observe(workspace, NSWorkspace.willSleepNotification) { [weak self] in self?.asleep = true; self?.pause() }
        observe(workspace, NSWorkspace.screensDidSleepNotification) { [weak self] in self?.asleep = true; self?.pause() }
        observe(workspace, NSWorkspace.didWakeNotification) { [weak self] in self?.asleep = false; self?.switchToFrontmost() }
        observe(workspace, NSWorkspace.screensDidWakeNotification) { [weak self] in self?.asleep = false; self?.switchToFrontmost() }
        observe(distributed, Notification.Name("com.apple.screenIsLocked")) { [weak self] in self?.locked = true; self?.pause() }
        observe(distributed, Notification.Name("com.apple.screenIsUnlocked")) { [weak self] in self?.locked = false; self?.switchToFrontmost() }
        // Foydalanuvchi almashganda boshqa sessiyadagi faollik bu sessiyaga yozilmaydi.
        observe(workspace, NSWorkspace.sessionDidResignActiveNotification) { [weak self] in self?.locked = true; self?.pause() }
        observe(workspace, NSWorkspace.sessionDidBecomeActiveNotification) { [weak self] in self?.locked = false; self?.switchToFrontmost() }
        switchToFrontmost()
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.tick() } }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stop() {
        guard running else { return }
        pause()
        running = false
        timer?.invalidate()
        timer = nil
        for (center, token) in observers { center.removeObserver(token) }
        observers.removeAll()
        save()
    }

    func clearHistory() {
        ledger = ScreenTimeLedger()
        store.remove()
        if running { switchToFrontmost() }
    }

    // Ilova yopilganda hisoblangan vaqt diskka yoziladi.
    func flush() {
        commit(until: Date())
        save()
    }

    private var idleSeconds: TimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
    }

    private func switchToFrontmost() {
        let now = Date()
        commit(until: now)
        guard running, !locked, !asleep, let app = NSWorkspace.shared.frontmostApplication, let id = app.bundleIdentifier else {
            current = nil
            return
        }
        if let name = app.localizedName, ledger.names[id] != name { ledger.names[id] = name }
        current = (id, now)
    }

    private func pause() {
        commit(until: Date())
        current = nil
        breakPolicy.reset()
    }

    // Faolsiz vaqt hisoblanmaydi: oxirgi kiritishdan keyingi qism kesib tashlanadi.
    private func commit(until now: Date) {
        guard let current else { return }
        let idle = idleSeconds
        let trimmed = idle >= Self.idleThreshold ? max(current.since, now.addingTimeInterval(-idle)) : now
        let end = min(trimmed, current.since.addingTimeInterval(Self.maxCommit))
        // Bo'sh oraliqda @Published o'zgarmaydi: widget har 30 s qayta chizilmaydi.
        if end > current.since { ledger.add(current.bundleID, from: current.since, to: end) }
        self.current = (current.bundleID, now)
    }

    private func tick() {
        let now = Date()
        let idle = idleSeconds
        // Taymer uzoq kechikkan bo'lsa (uyqu), oraliq ish vaqti emas.
        if now.timeIntervalSince(lastTick) > 120 { breakPolicy.reset() }
        lastTick = now
        commit(until: now)
        if current == nil, !locked, !asleep, idle < Self.idleThreshold { switchToFrontmost() }
        if breakPolicy.feed(active: !locked && !asleep, idle: idle, at: now) { onBreakReminder?(breakLimit) }
        if now.timeIntervalSince(lastSave) >= 300 { save() }
    }

    private func save() {
        lastSave = Date()
        ledger.prune(now: Date())
        if ledger.days.isEmpty { store.remove() } else { store.save(ledger) }
    }
}
