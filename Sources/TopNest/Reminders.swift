import AppKit
import EventKit
import Foundation

struct TaskItem: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let due: Date?
    let hasTime: Bool
    let listID: String
    let priority: Int

    // Muddat o'tgan: vaqtli bo'lsa shu lahzadan, faqat sana bo'lsa ertasi kundan.
    func isOverdue(at now: Date, calendar: Calendar = .current) -> Bool {
        guard let due else { return false }
        return hasTime ? due < now : calendar.startOfDay(for: due) < calendar.startOfDay(for: now)
    }

    func isDueToday(at now: Date, calendar: Calendar = .current) -> Bool {
        guard let due else { return false }
        return calendar.isDate(due, inSameDayAs: now)
    }
}

struct TaskList: Identifiable, Equatable {
    let id: String
    let title: String
    let color: NSColor
}

enum TaskOrdering {
    // Widget tartibi: muddati o'tgan → bugungi → muddatsiz → keyingi kunlar; ichida muddat va muhimlik bo'yicha.
    static func focus(_ items: [TaskItem], now: Date, calendar: Calendar = .current) -> [TaskItem] {
        func rank(_ item: TaskItem) -> Int {
            if item.isOverdue(at: now, calendar: calendar) { return 0 }
            if item.isDueToday(at: now, calendar: calendar) { return 1 }
            return item.due == nil ? 2 : 3
        }
        return items.sorted { lhs, rhs in
            let (l, r) = (rank(lhs), rank(rhs))
            if l != r { return l < r }
            if let a = lhs.due, let b = rhs.due, a != b { return a < b }
            // EventKit muhimligi: 1 — eng yuqori, 0 — belgilanmagan.
            let lp = lhs.priority == 0 ? 10 : lhs.priority, rp = rhs.priority == 0 ? 10 : rhs.priority
            if lp != rp { return lp < rp }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }
}

// Apple Reminders (EventKit): bajarilmagan vazifalar, belgilash, qo'shish. Ma'lumot iCloud orqali iPhone bilan sinxron.
@MainActor
final class RemindersService: ObservableObject {
    @Published private(set) var items: [TaskItem] = []
    @Published private(set) var lists: [TaskList] = []
    @Published private(set) var access: CalendarAccess = .notDetermined
    @Published private(set) var excludedIDs = Set(UserDefaults.standard.stringArray(forKey: "excludedReminderLists") ?? [])
    @Published var newTaskListID = UserDefaults.standard.string(forKey: "reminderListForNew") ?? "" {
        didSet { UserDefaults.standard.set(newTaskListID, forKey: "reminderListForNew") }
    }
    // Belgilangan, lekin hali ro'yxatdan olinmagan vazifalar (1,5 s chizilgan holda; qayta bosilsa qaytadi).
    @Published private(set) var recentlyCompleted: [TaskItem] = []
    @Published var errorMessage: String?
    private let store = EKEventStore()
    private var storeObserver: NSObjectProtocol?
    private var fetchGeneration = 0
    // EventKit sanalari Grigorian: tizim kalendari (masalan buddaviy) yillarni noto'g'ri bermasin.
    nonisolated private static var gregorian: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }
    private var hideTasks: [String: Task<Void, Never>] = [:]
    private var animatingIDs: Set<String> = []

    init() {
        updateAccess()
        storeObserver = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        if access == .granted { refresh() }
    }

    var accessGranted: Bool { access == .granted }

    func requestAccess() {
        Task {
            do {
                _ = try await store.requestFullAccessToReminders()
                updateAccess()
                if accessGranted { refresh() } else { errorMessage = L10n.tr("Eslatmalar ruxsati berilmadi.") }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func setIncluded(_ included: Bool, listID: String) {
        if included { excludedIDs.remove(listID) } else { excludedIDs.insert(listID) }
        UserDefaults.standard.set(Array(excludedIDs), forKey: "excludedReminderLists")
        refresh()
    }

    func list(_ id: String) -> TaskList? { lists.first { $0.id == id } }

    // Ruxsat tizim sozlamalarida o'zgargan bo'lishi mumkin: har yangilashda holat qayta o'qiladi.
    private func updateAccess() {
        let next: CalendarAccess = switch EKEventStore.authorizationStatus(for: .reminder) {
        case .fullAccess: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
        guard next != access else { return }
        if next == .granted { store.reset() }
        access = next
    }

    func refresh() {
        updateAccess()
        guard accessGranted else { items = []; lists = []; return }
        let all = store.calendars(for: .reminder)
        lists = all.map { TaskList(id: $0.calendarIdentifier, title: $0.title, color: $0.color) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        let known = Set(all.map(\.calendarIdentifier))
        if !excludedIDs.isSubset(of: known) {
            excludedIDs.formIntersection(known)
            UserDefaults.standard.set(Array(excludedIDs), forKey: "excludedReminderLists")
        }
        let included = all.filter { !excludedIDs.contains($0.calendarIdentifier) }
        guard !included.isEmpty else { items = []; return }
        fetchGeneration += 1
        let generation = fetchGeneration
        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: included)
        // EKReminder Sendable emas: javob fonda oddiy struct'ga aylantiriladi.
        store.fetchReminders(matching: predicate) { [weak self] reminders in
            let mapped = (reminders ?? []).map(Self.item)
            Task { @MainActor in
                guard let self, generation == self.fetchGeneration else { return }
                // Belgilanib, hali animatsiyada turganlar ro'yxatda qoladi; qolgan belgilanganlar chiqariladi.
                let pending = Set(self.recentlyCompleted.map(\.id))
                let animating = self.items.filter { self.animatingIDs.contains($0.id) }
                self.items = mapped.filter { !pending.contains($0.id) } + animating
                self.errorMessage = nil
            }
        }
    }

    nonisolated private static func item(_ reminder: EKReminder) -> TaskItem {
        let components = reminder.dueDateComponents
        return TaskItem(
            id: reminder.calendarItemIdentifier,
            title: reminder.title?.isEmpty == false ? reminder.title! : L10n.tr("Nomsiz vazifa"),
            due: components.flatMap { gregorian.date(from: $0) },
            hasTime: components?.hour != nil,
            listID: reminder.calendar?.calendarIdentifier ?? "",
            priority: reminder.priority
        )
    }

    // Belgilangan vazifa 1,5 s ko'rinib turadi (chizilgan), keyin ro'yxatdan chiqadi; shu vaqtda qayta bosib qaytarish mumkin.
    func complete(_ item: TaskItem) {
        guard setCompleted(true, id: item.id) else { return }
        recentlyCompleted.removeAll { $0.id == item.id }
        recentlyCompleted.append(item)
        animatingIDs.insert(item.id)
        hideTasks[item.id]?.cancel()
        hideTasks[item.id] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled, let self else { return }
            self.animatingIDs.remove(item.id)
            self.items.removeAll { $0.id == item.id }
            self.recentlyCompleted.removeAll { $0.id == item.id }
            self.hideTasks[item.id] = nil
        }
    }

    func isCompleting(_ item: TaskItem) -> Bool { recentlyCompleted.contains { $0.id == item.id } }

    func undoComplete(_ item: TaskItem) {
        hideTasks[item.id]?.cancel()
        hideTasks[item.id] = nil
        animatingIDs.remove(item.id)
        recentlyCompleted.removeAll { $0.id == item.id }
        guard setCompleted(false, id: item.id) else { return }
        if !items.contains(where: { $0.id == item.id }) { items.append(item) }
        // Belgilashdan oldin boshlangan eski so'rov qaytarilgan vazifani yashirib qo'ymasin.
        refresh()
    }

    private func setCompleted(_ completed: Bool, id: String) -> Bool {
        guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else { return false }
        reminder.isCompleted = completed
        do {
            try store.save(reminder, commit: true)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // Tez qo'shish: widgetdan — bugungi sana bilan (widget bugungi vazifalarni ko'rsatadi), tabdan — muddatsiz.
    @discardableResult
    func add(_ title: String, dueToday: Bool) -> Bool {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard accessGranted, !title.isEmpty else { return false }
        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.calendar = store.calendars(for: .reminder).first { $0.calendarIdentifier == newTaskListID }
            ?? store.defaultCalendarForNewReminders()
        guard reminder.calendar != nil else { errorMessage = L10n.tr("Eslatmalar ro‘yxati topilmadi."); return false }
        if dueToday {
            reminder.dueDateComponents = Self.gregorian.dateComponents([.year, .month, .day], from: Date())
        }
        do {
            try store.save(reminder, commit: true)
            refresh()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func openInReminders() {
        if let url = URL(string: "x-apple-reminderkit://"), NSWorkspace.shared.open(url) { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Reminders.app"))
    }
}
