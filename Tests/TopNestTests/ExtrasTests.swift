import XCTest
@testable import TopNest

final class ExtrasTests: XCTestCase {
    func testWorldClockHelpers() {
        XCTAssertEqual(WorldClockStore.city("America/New_York"), "New York")
        let date = Date(timeIntervalSince1970: 1_791_600_000)
        let tashkent = TimeZone(identifier: "Asia/Tashkent")!
        XCTAssertEqual(WorldClockStore.offset(TimeZone(identifier: "Asia/Tokyo")!, at: date, local: tashkent), "+4 s")
        XCTAssertEqual(WorldClockStore.offset(TimeZone(identifier: "Asia/Kolkata")!, at: date, local: tashkent), "+30 daq")
        XCTAssertEqual(WorldClockStore.offset(tashkent, at: date, local: tashkent), "0")
        XCTAssertTrue(WorldClockStore.search("new york").contains("America/New_York"))
        XCTAssertTrue(WorldClockStore.search("n").isEmpty)
    }

    @MainActor
    func testWorldClockLimitAndValidation() throws {
        let store = WorldClockStore(defaults: try XCTUnwrap(UserDefaults(suiteName: "clocks-\(UUID().uuidString)")))
        store.add("Not/AZone")
        store.add("Europe/Paris")
        XCTAssertEqual(store.zones.count, WorldClockStore.limit)
        store.add("Asia/Seoul")
        XCTAssertFalse(store.zones.contains("Asia/Seoul"))
        store.remove("Europe/London")
        XCTAssertFalse(store.zones.contains("Europe/London"))
    }

    func testShortcutsListParsing() {
        XCTAssertEqual(ShortcutsStore.parseList("Focus On\n\n  Kun rejasi \nFocus On\n"), ["Focus On", "Kun rejasi"])
    }

    func testPrayerParsingAndNext() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tashkent")!
        let day = calendar.date(from: DateComponents(year: 2026, month: 10, day: 10, hour: 12))!
        let json = #"{"code":200,"data":{"timings":{"Fajr":"04:57","Sunrise":"06:29","Dhuhr":"12:10 (+05)","Asr":"15:20","Sunset":"17:50","Maghrib":"17:50","Isha":"19:17"}}}"#
        let times = PrayerParser.parse(Data(json.utf8), day: day, calendar: calendar)
        XCTAssertEqual(times.map(\.name), [.fajr, .sunrise, .dhuhr, .asr, .maghrib, .isha])
        XCTAssertEqual(calendar.component(.minute, from: times[2].date), 10)
        XCTAssertEqual(PrayerParser.next(times, after: day)?.name, .dhuhr)
        XCTAssertNil(PrayerParser.next(times, after: calendar.date(bySettingHour: 20, minute: 0, second: 0, of: day)!))
        XCTAssertTrue(PrayerParser.parse(Data("{}".utf8), day: day).isEmpty)
        // Shahar vaqt zonasi Mac'nikidan farq qilsa: vaqtlar shahar zonasida, sana javobdan olinadi.
        let istanbul = #"{"code":200,"data":{"timings":{"Fajr":"06:10","Sunrise":"07:35","Dhuhr":"13:05","Asr":"16:10","Maghrib":"18:40","Isha":"20:00"},"date":{"gregorian":{"date":"11-10-2026"}},"meta":{"timezone":"Europe/Istanbul"}}}"#
        let remote = PrayerParser.parse(Data(istanbul.utf8), day: day, calendar: calendar)
        var istanbulCalendar = Calendar(identifier: .gregorian)
        istanbulCalendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        XCTAssertEqual(istanbulCalendar.component(.hour, from: remote[0].date), 6)
        XCTAssertEqual(istanbulCalendar.component(.day, from: remote[0].date), 11)
        // Toshkent vaqtida 08:10.
        XCTAssertEqual(calendar.component(.hour, from: remote[0].date), 8)
    }

    func testDownloadScanner() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let safari = directory.appendingPathComponent("movie.mp4.download")
        try FileManager.default.createDirectory(at: safari, withIntermediateDirectories: true)
        NSDictionary(dictionary: ["DownloadEntryProgressBytesSoFar": 25, "DownloadEntryProgressTotalToLoad": 100])
            .write(to: safari.appendingPathComponent("Info.plist"), atomically: true)
        FileManager.default.createFile(atPath: directory.appendingPathComponent("file.zip.crdownload").path, contents: Data())
        FileManager.default.createFile(atPath: directory.appendingPathComponent("done.pdf").path, contents: Data())
        let items = DownloadScanner.scan(directory)
        XCTAssertEqual(items.map(\.name), ["file.zip", "movie.mp4"])
        XCTAssertEqual(items.first { $0.name == "movie.mp4" }?.progress, 0.25)
        XCTAssertEqual(DownloadScanner.overall(items), 0.25)
        XCTAssertNil(DownloadScanner.overall([DownloadItem(name: "x", progress: nil)]))
    }

    func testActivityPriorities() {
        let now = Date()
        let running = FocusSession.start(.work, duration: 600, now: now)
        XCTAssertEqual(ActivityPolicy.resolve(ActivityInputs(now: now, timer: running, prayerSoon: ("Asr", 5))), .prayer(name: "Asr", minutes: 5))
        XCTAssertEqual(ActivityPolicy.resolve(ActivityInputs(now: now, musicPlaying: true, download: .some(40))), .download(progress: 40))
        XCTAssertEqual(ActivityPolicy.resolve(ActivityInputs(now: now, musicPlaying: true, timer: running, download: .some(nil))), .timer(running))
    }

    func testWidgetRules() {
        var context = WidgetContext()
        if case .needsSetup(_, let action) = WidgetRules.state(for: WidgetConfig(kind: .prayer), in: context) {
            XCTAssertEqual(action, .openSettings(.weather))
        } else { XCTFail() }
        context.prayerLocation = true
        XCTAssertFalse(WidgetRules.state(for: WidgetConfig(kind: .prayer), in: context).isVisible)
        context.hasPrayerTimes = true
        XCTAssertEqual(WidgetRules.state(for: WidgetConfig(kind: .prayer), in: context), .ready)
        if case .needsSetup = WidgetRules.state(for: WidgetConfig(kind: .shortcuts), in: context) {} else { XCTFail() }
        XCTAssertEqual(WidgetRules.state(for: WidgetConfig(kind: .worldClock), in: context), .ready)
    }
}
