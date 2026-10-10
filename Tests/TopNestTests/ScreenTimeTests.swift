import XCTest
@testable import TopNest

final class ScreenTimeTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tashkent")!
        return calendar
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    func testIntervalsSplitAtMidnight() {
        var ledger = ScreenTimeLedger()
        ledger.add("com.apple.Safari", from: date(9, 23, 30), to: date(10, 0, 45), calendar: calendar)
        XCTAssertEqual(ledger.total(on: date(9, 12), calendar: calendar), 1800)
        XCTAssertEqual(ledger.total(on: date(10, 12), calendar: calendar), 2700)
        ledger.add("com.apple.Safari", from: date(10, 1), to: date(10, 1), calendar: calendar)
        XCTAssertEqual(ledger.total(on: date(10, 12), calendar: calendar), 2700)
    }

    func testTopWeekAndPrune() {
        var ledger = ScreenTimeLedger()
        ledger.add("a", from: date(10, 9), to: date(10, 10), calendar: calendar)
        ledger.add("b", from: date(10, 10), to: date(10, 12), calendar: calendar)
        ledger.add("c", from: date(1, 10), to: date(1, 11), calendar: calendar)
        ledger.names = ["a": "A", "b": "B", "c": "C"]
        XCTAssertEqual(ledger.top(on: date(10, 20), limit: 1, calendar: calendar).map(\.bundleID), ["b"])
        let week = ledger.week(endingAt: date(10, 20), calendar: calendar)
        XCTAssertEqual(week.count, 7)
        XCTAssertEqual(week.last?.seconds, 3 * 3600)
        XCTAssertEqual(week.first?.seconds, 0)
        ledger.add("c", from: calendar.date(byAdding: .day, value: -40, to: date(10, 10))!, to: calendar.date(byAdding: .day, value: -40, to: date(10, 11))!, calendar: calendar)
        ledger.prune(now: date(10, 20), calendar: calendar)
        XCTAssertEqual(ledger.days.count, 2)
        XCTAssertNotNil(ledger.names["c"])
    }

    func testBreakPolicy() {
        var policy = BreakPolicy(limit: 3600)
        let start = date(10, 9)
        XCTAssertFalse(policy.feed(active: true, idle: 0, at: start))
        XCTAssertFalse(policy.feed(active: true, idle: 200, at: start.addingTimeInterval(1800)))
        XCTAssertTrue(policy.feed(active: true, idle: 0, at: start.addingTimeInterval(3600)))
        XCTAssertFalse(policy.feed(active: true, idle: 0, at: start.addingTimeInterval(4000)))
        // 5 daqiqalik dam hisobni boshidan boshlaydi.
        XCTAssertFalse(policy.feed(active: true, idle: 400, at: start.addingTimeInterval(4400)))
        XCTAssertFalse(policy.feed(active: true, idle: 0, at: start.addingTimeInterval(4500)))
        XCTAssertTrue(policy.feed(active: true, idle: 0, at: start.addingTimeInterval(8100)))
        XCTAssertFalse(policy.feed(active: false, idle: 0, at: start.addingTimeInterval(8200)))
        // Uyqu/qulfdan keyin hisob boshidan.
        XCTAssertFalse(policy.feed(active: true, idle: 0, at: start.addingTimeInterval(9000)))
        policy.reset()
        XCTAssertFalse(policy.feed(active: true, idle: 0, at: start.addingTimeInterval(12000)))
        XCTAssertFalse(policy.feed(active: true, idle: 0, at: start.addingTimeInterval(15000)))
    }

    func testFormatAndRules() {
        XCTAssertEqual(ScreenTimeFormat.duration(30), "<1 daq")
        XCTAssertEqual(ScreenTimeFormat.duration(45 * 60), "45 daq")
        XCTAssertEqual(ScreenTimeFormat.duration(3 * 3600 + 25 * 60), "3 s 25 daq")
        XCTAssertEqual(ScreenTimeFormat.duration(2 * 3600 + 30), "2 s")
        var context = WidgetContext()
        if case .needsSetup(_, let action) = WidgetRules.state(for: WidgetConfig(kind: .screenTime), in: context) {
            XCTAssertEqual(action, .openSettings(.screenTime))
        } else { XCTFail() }
        context.screenTimeEnabled = true
        XCTAssertEqual(WidgetRules.state(for: WidgetConfig(kind: .screenTime), in: context), .ready)
    }
}
