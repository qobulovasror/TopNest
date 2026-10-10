import AppKit
import Foundation

enum FocusPhase: String, Codable, Equatable {
    case timer, work, shortBreak, longBreak

    // Tarjima kaliti (WidgetCard o'zi tarjima qiladi).
    var titleKey: String {
        switch self {
        case .timer: "Taymer"
        case .work: "Diqqat"
        case .shortBreak: "Qisqa tanaffus"
        case .longBreak: "Uzun tanaffus"
        }
    }

    var title: String { L10n.tr(titleKey) }

    var isPomodoro: Bool { self != .timer }
    var isBreak: Bool { self == .shortBreak || self == .longBreak }
}

struct PomodoroSettings: Equatable {
    var workMinutes = 25
    var shortBreakMinutes = 5
    var longBreakMinutes = 15
    var cyclesBeforeLongBreak = 4

    func minutes(for phase: FocusPhase) -> Int {
        switch phase {
        case .work: workMinutes
        case .shortBreak: shortBreakMinutes
        case .longBreak: longBreakMinutes
        case .timer: 0
        }
    }
}

// Taymer holati: soniya hisoblagichi yo'q, faqat tugash vaqti saqlanadi — uyqu va qayta ishga tushirishga chidamli.
struct FocusSession: Codable, Equatable {
    var phase: FocusPhase
    var duration: TimeInterval
    var endDate: Date?
    var pausedRemaining: TimeInterval?
    // Ketma-ket tugatilgan "Diqqat" bosqichlari (uzun tanaffusdan keyin 0 dan boshlanadi).
    var completedWork = 0
    // Keyingi Pomodoro bosqichi tayyor, lekin hali boshlanmagan.
    var waiting: Bool?

    static func start(_ phase: FocusPhase, duration: TimeInterval, completedWork: Int = 0, now: Date = Date()) -> FocusSession {
        FocusSession(phase: phase, duration: duration, endDate: now.addingTimeInterval(duration), completedWork: completedWork)
    }

    // Boshlanmagan (keyingi Pomodoro bosqichi tayyor turibdi).
    static func ready(_ phase: FocusPhase, duration: TimeInterval, completedWork: Int) -> FocusSession {
        FocusSession(phase: phase, duration: duration, pausedRemaining: duration, completedWork: completedWork, waiting: true)
    }

    var isRunning: Bool { endDate != nil }
    var isPaused: Bool { endDate == nil }
    var isUntouched: Bool { isPaused && waiting == true }

    func remaining(at now: Date) -> TimeInterval {
        if let endDate { return max(0, endDate.timeIntervalSince(now)) }
        return max(0, pausedRemaining ?? 0)
    }

    func progress(at now: Date) -> Double {
        duration > 0 ? min(1, max(0, 1 - remaining(at: now) / duration)) : 0
    }

    func isFinished(at now: Date) -> Bool { isRunning && remaining(at: now) <= 0 }

    mutating func pause(at now: Date) {
        guard isRunning else { return }
        pausedRemaining = remaining(at: now)
        endDate = nil
    }

    mutating func resume(at now: Date) {
        guard isPaused else { return }
        endDate = now.addingTimeInterval(remaining(at: now))
        pausedRemaining = nil
        waiting = nil
    }

    mutating func add(_ seconds: TimeInterval, at now: Date) {
        let value = remaining(at: now) + seconds
        guard value > 0 else { return }
        duration = max(duration, value)
        if isRunning { endDate = now.addingTimeInterval(value) } else { pausedRemaining = value }
    }

    // Tugagan bosqichdan keyingisi: oddiy taymer tugaydi, Pomodoro diqqat ↔ tanaffus almashadi.
    // O'tkazib yuborilgan diqqat bosqichi hisobga qo'shilmaydi.
    func next(settings: PomodoroSettings, completed: Bool = true) -> FocusSession? {
        switch phase {
        case .timer:
            return nil
        case .work:
            let done = completedWork + (completed ? 1 : 0)
            let long = completed && done % max(1, settings.cyclesBeforeLongBreak) == 0
            let phase: FocusPhase = long ? .longBreak : .shortBreak
            return .ready(phase, duration: TimeInterval(settings.minutes(for: phase) * 60), completedWork: done)
        case .shortBreak:
            return .ready(.work, duration: TimeInterval(settings.workMinutes * 60), completedWork: completedWork)
        case .longBreak:
            return .ready(.work, duration: TimeInterval(settings.workMinutes * 60), completedWork: 0)
        }
    }
}

enum FocusFormat {
    // Qanot 40 pt: 1 soatdan kam — "24:13", ko'p — "65m".
    static func short(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        if total >= 3600 { return "\(total / 60)m" }
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

@MainActor
final class FocusTimerService: ObservableObject {
    static let sounds = ["Glass", "Hero", "Ping", "Submarine", "Purr"]
    static let presets = [5, 10, 25, 50]

    @Published private(set) var session: FocusSession? {
        didSet { save(); schedule() }
    }
    @Published var settings: PomodoroSettings {
        didSet {
            let d = UserDefaults.standard
            d.set(settings.workMinutes, forKey: "pomodoroWork")
            d.set(settings.shortBreakMinutes, forKey: "pomodoroShortBreak")
            d.set(settings.longBreakMinutes, forKey: "pomodoroLongBreak")
            d.set(settings.cyclesBeforeLongBreak, forKey: "pomodoroCycles")
        }
    }
    @Published var autoStartNext = UserDefaults.standard.bool(forKey: "pomodoroAutoStart") {
        didSet { UserDefaults.standard.set(autoStartNext, forKey: "pomodoroAutoStart") }
    }
    // Bo'sh qator — ovozsiz.
    @Published var sound = UserDefaults.standard.string(forKey: "focusSound") ?? "Glass" {
        didSet { UserDefaults.standard.set(sound, forKey: "focusSound") }
    }
    var onFinish: ((FocusPhase, FocusSession?) -> Void)?
    // Bildirishnomadagi "+5 daq" tugagan bosqichni davom ettirishi uchun; finishedNext — o'shanda qo'yilgan holat.
    private var lastFinished: FocusSession?
    private var finishedNext: FocusSession?
    private var finishTask: Task<Void, Never>?
    private var wakeObserver: NSObjectProtocol?

    init() {
        let d = UserDefaults.standard
        func value(_ key: String, _ fallback: Int) -> Int { (d.object(forKey: key) as? Int).map { max(1, $0) } ?? fallback }
        settings = PomodoroSettings(workMinutes: value("pomodoroWork", 25), shortBreakMinutes: value("pomodoroShortBreak", 5),
                                    longBreakMinutes: value("pomodoroLongBreak", 15), cyclesBeforeLongBreak: value("pomodoroCycles", 4))
        if let data = d.data(forKey: "focusSession"), let saved = try? JSONDecoder().decode(FocusSession.self, from: data) {
            // Ilova yopiq paytda tugagan bosqich jim yakunlanadi: keyingisi tayyor turadi, lekin boshlanmaydi.
            session = saved.isFinished(at: Date()) ? saved.next(settings: settings) : saved
            save()
        }
        schedule()
        // Uyqudan keyin tugash vaqti qayta rejalanadi.
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.schedule() }
        }
    }

    func startTimer(minutes: Int) {
        session = .start(.timer, duration: TimeInterval(minutes * 60))
    }

    func startPomodoro() {
        session = .start(.work, duration: TimeInterval(settings.workMinutes * 60))
    }

    // Bitta tugma: ishlayotgan bo'lsa pauza, pauzada bo'lsa davom, yo'q bo'lsa Pomodoro boshlanadi.
    func toggle() {
        guard var current = session else { startPomodoro(); return }
        let now = Date()
        if current.isRunning { current.pause(at: now) } else { current.resume(at: now) }
        session = current
    }

    func add(minutes: Int) {
        guard var current = session else { startTimer(minutes: minutes); return }
        current.add(TimeInterval(minutes * 60), at: Date())
        session = current
    }

    // Joriy bosqichni o'tkazib yuborish (Pomodoro) yoki taymerni to'xtatish.
    func skip() {
        guard let current = session else { return }
        session = current.next(settings: settings, completed: false)
    }

    func stop() { session = nil }

    // Tugagan bosqich qo'shimcha daqiqa bilan davom etadi (Pomodoro hisobi ikki marta oshmaydi).
    // Eski bildirishnoma yangi boshlangan taymerni bosib ketmasin: faqat tugashdan keyin holat o'zgarmagan bo'lsa.
    func extendFinished(minutes: Int) {
        guard let last = lastFinished, session == finishedNext || session?.isUntouched == true else { return }
        session = .start(last.phase, duration: TimeInterval(minutes * 60), completedWork: last.completedWork)
        lastFinished = nil
    }

    // Tayyor turgan keyingi bosqichni boshlash (allaqachon ishlayotgan bo'lsa tegilmaydi).
    func startNext() {
        guard var current = session, current.isPaused else { return }
        current.resume(at: Date())
        session = current
    }

    func previewSound(_ name: String) {
        guard !name.isEmpty else { return }
        NSSound(named: NSSound.Name(name))?.play()
    }

    private func schedule() {
        finishTask?.cancel()
        finishTask = nil
        guard let session, let endDate = session.endDate else { return }
        let delay = max(0, endDate.timeIntervalSinceNow)
        finishTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.finishIfNeeded()
        }
    }

    private func finishIfNeeded() {
        guard let current = session else { return }
        let now = Date()
        guard current.isRunning else { return }
        // Uyqu tufayli erta uyg'onilgan bo'lsa qayta rejalanadi.
        guard current.isFinished(at: now) else { schedule(); return }
        var next = current.next(settings: settings)
        if autoStartNext, var upcoming = next {
            upcoming.resume(at: now)
            next = upcoming
        }
        lastFinished = current
        finishedNext = next
        session = next
        previewSound(sound)
        onFinish?(current.phase, next)
    }

    private func save() {
        if let session, let data = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(data, forKey: "focusSession")
        } else {
            UserDefaults.standard.removeObject(forKey: "focusSession")
        }
    }
}

extension FocusSession {
    // Har soniyalik yangilanish tugash vaqtiga tekislanadi: ko'rsatilgan soniya kechikmaydi.
    func tickStart(at now: Date = Date()) -> Date {
        guard let endDate else { return now }
        return endDate.addingTimeInterval(-endDate.timeIntervalSince(now).rounded(.up))
    }
}
