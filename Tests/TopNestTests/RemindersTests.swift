import XCTest
@testable import TopNest

final class RemindersTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tashkent")!
        return calendar
    }()
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 10, hour: 15))! }

    private func task(_ title: String, dayOffset: Int? = nil, hour: Int? = nil, priority: Int = 0) -> TaskItem {
        let due = dayOffset.map { offset -> Date in
            let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now))!
            return hour.map { calendar.date(bySettingHour: $0, minute: 0, second: 0, of: day)! } ?? day
        }
        return TaskItem(id: title, title: title, due: due, hasTime: hour != nil, listID: "l", priority: priority)
    }

    func testOverdueAndToday() {
        XCTAssertTrue(task("a", dayOffset: -1).isOverdue(at: now, calendar: calendar))
        // Faqat sanali bugungi vazifa kun oxirigacha muddati o'tmagan hisoblanadi.
        XCTAssertFalse(task("b", dayOffset: 0).isOverdue(at: now, calendar: calendar))
        XCTAssertTrue(task("c", dayOffset: 0, hour: 9).isOverdue(at: now, calendar: calendar))
        XCTAssertFalse(task("d", dayOffset: 0, hour: 18).isOverdue(at: now, calendar: calendar))
        XCTAssertTrue(task("e", dayOffset: 0, hour: 18).isDueToday(at: now, calendar: calendar))
    }

    func testFocusOrdering() {
        let items = [task("later", dayOffset: 3), task("undated"), task("today", dayOffset: 0),
                     task("overdue", dayOffset: -2), task("urgent undated", priority: 1)]
        XCTAssertEqual(TaskOrdering.focus(items, now: now, calendar: calendar).map(\.title),
                       ["overdue", "today", "urgent undated", "undated", "later"])
    }

    func testDueLabels() {
        XCTAssertNil(TaskDueFormat.label(task("x"), now: now, calendar: calendar))
        XCTAssertEqual(TaskDueFormat.label(task("x", dayOffset: 0), now: now, calendar: calendar), "Bugun")
        XCTAssertEqual(TaskDueFormat.label(task("x", dayOffset: -1), now: now, calendar: calendar), "Kecha")
        XCTAssertEqual(TaskDueFormat.label(task("x", dayOffset: 1), now: now, calendar: calendar), "Ertaga")
    }

    func testWidgetRules() {
        func state(_ access: CalendarAccess) -> WidgetState {
            var context = WidgetContext()
            context.remindersAccess = access
            return WidgetRules.state(for: WidgetConfig(kind: .tasks), in: context)
        }
        XCTAssertEqual(state(.notDetermined), .needsSetup(reason: "Eslatmalarga ruxsat kerak", action: .requestRemindersAccess))
        if case .needsSetup(_, let action) = state(.denied) { XCTAssertEqual(action, .openRemindersPrivacy) } else { XCTFail() }
        XCTAssertEqual(state(.granted), .ready)
    }
}
