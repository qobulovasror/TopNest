import XCTest
@testable import TopNest

final class FocusTimerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    func testPauseResumeKeepsRemainingTime() {
        var session = FocusSession.start(.timer, duration: 600, now: now)
        XCTAssertEqual(session.remaining(at: now.addingTimeInterval(100)), 500)
        session.pause(at: now.addingTimeInterval(100))
        XCTAssertTrue(session.isPaused)
        // Pauzada vaqt o'tmaydi.
        XCTAssertEqual(session.remaining(at: now.addingTimeInterval(1000)), 500)
        session.resume(at: now.addingTimeInterval(1000))
        XCTAssertEqual(session.remaining(at: now.addingTimeInterval(1100)), 400)
        XCTAssertFalse(session.isFinished(at: now.addingTimeInterval(1499)))
        XCTAssertTrue(session.isFinished(at: now.addingTimeInterval(1500)))
        XCTAssertEqual(session.progress(at: now.addingTimeInterval(1500)), 1)
    }

    func testAddExtendsRunningAndPausedSessions() {
        var running = FocusSession.start(.timer, duration: 60, now: now)
        running.add(60, at: now.addingTimeInterval(30))
        XCTAssertEqual(running.remaining(at: now.addingTimeInterval(30)), 90)
        XCTAssertEqual(running.duration, 90)
        var paused = FocusSession.ready(.work, duration: 300, completedWork: 0)
        paused.add(60, at: now)
        XCTAssertEqual(paused.remaining(at: now), 360)
        XCTAssertTrue(paused.isUntouched)
        // Pauzadagi boshlangan taymerga vaqt qo'shilsa u qanotda qoladi.
        var stopped = FocusSession.start(.timer, duration: 60, now: now)
        stopped.pause(at: now.addingTimeInterval(30))
        stopped.add(120, at: now.addingTimeInterval(30))
        XCTAssertFalse(stopped.isUntouched)
    }

    func testPomodoroCycleReachesLongBreak() {
        let settings = PomodoroSettings(workMinutes: 25, shortBreakMinutes: 5, longBreakMinutes: 15, cyclesBeforeLongBreak: 2)
        let first = FocusSession.start(.work, duration: 1500, now: now).next(settings: settings)
        XCTAssertEqual(first?.phase, .shortBreak)
        XCTAssertEqual(first?.duration, 300)
        XCTAssertEqual(first?.isUntouched, true)
        let work = first?.next(settings: settings)
        XCTAssertEqual(work?.phase, .work)
        XCTAssertEqual(work?.completedWork, 1)
        let long = FocusSession.start(.work, duration: 1500, completedWork: 1, now: now).next(settings: settings)
        XCTAssertEqual(long?.phase, .longBreak)
        XCTAssertEqual(long?.next(settings: settings)?.completedWork, 0)
        XCTAssertNil(FocusSession.start(.timer, duration: 60, now: now).next(settings: settings))
        // O'tkazib yuborilgan diqqat bosqichi hisobga qo'shilmaydi va uzun tanaffusga olib bormaydi.
        let skipped = FocusSession.start(.work, duration: 1500, completedWork: 1, now: now).next(settings: settings, completed: false)
        XCTAssertEqual(skipped?.phase, .shortBreak)
        XCTAssertEqual(skipped?.completedWork, 1)
    }

    func testTickStartAlignsToEndDate() {
        let session = FocusSession.start(.timer, duration: 100, now: now)
        let start = session.tickStart(at: now.addingTimeInterval(10.4))
        XCTAssertLessThanOrEqual(start, now.addingTimeInterval(10.4))
        XCTAssertEqual(session.endDate!.timeIntervalSince(start).truncatingRemainder(dividingBy: 1), 0, accuracy: 0.0001)
    }

    func testShortFormatFitsWing() {
        XCTAssertEqual(FocusFormat.short(1453), "24:13")
        XCTAssertEqual(FocusFormat.short(59.2), "1:00")
        XCTAssertEqual(FocusFormat.short(0), "0:00")
        XCTAssertEqual(FocusFormat.short(3900), "65m")
    }

    func testTimerActivityPriority() {
        let running = FocusSession.start(.work, duration: 1500, now: now)
        XCTAssertEqual(ActivityPolicy.resolve(ActivityInputs(now: now, musicPlaying: true, timer: running)), .timer(running))
        let ready = FocusSession.ready(.work, duration: 1500, completedWork: 1)
        XCTAssertEqual(ActivityPolicy.resolve(ActivityInputs(now: now, musicPlaying: true, timer: ready)), .music)
        let meeting = ActivityInputs(now: now, meetingStarts: [now.addingTimeInterval(60)], timer: running)
        XCTAssertEqual(ActivityPolicy.resolve(meeting), .meeting(minutes: 1))
        XCTAssertEqual(ActivityPolicy.resolve(ActivityInputs(now: now, flash: .timerDone(.work), timer: running)), .timerDone(.work))
    }

    func testTimerWidgetIsAlwaysReady() {
        XCTAssertEqual(WidgetRules.state(for: WidgetConfig(kind: .focusTimer), in: WidgetContext()), .ready)
    }
}
