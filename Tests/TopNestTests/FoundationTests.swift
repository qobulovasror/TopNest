import XCTest
@testable import TopNest

final class FoundationTests: XCTestCase {
    func testTabOrderKeepsHomeFirstAndAppendsNewTabs() {
        XCTAssertEqual(TabLayout.order(stored: []), AppState.Tab.allCases)
        XCTAssertEqual(TabLayout.order(stored: ["Tokcha", "Asosiy", "Tokcha", "noma'lum"]).first, .home)
        XCTAssertEqual(TabLayout.order(stored: ["Tokcha"]), [.home, .shelf, .clips, .notes, .tools])
    }

    func testHiddenTabsUseDefaultsOnlyForUnseenTabs() {
        XCTAssertEqual(TabLayout.hidden(stored: nil, known: nil), AppState.Tab.defaultHidden)
        XCTAssertEqual(TabLayout.hidden(stored: ["Tokcha", "Asosiy"], known: ["Asosiy", "Clipboard", "Tokcha"]), [.shelf])
    }

    func testHiddenSelectedTabStaysVisibleAndLabelsCollapse() {
        let order: [AppState.Tab] = [.home, .clips, .shelf]
        XCTAssertEqual(TabLayout.visible(order: order, hidden: [.clips], selected: .home), [.home, .shelf])
        XCTAssertEqual(TabLayout.visible(order: order, hidden: [.clips], selected: .clips), order)
        XCTAssertEqual(TabLayout.labelStyle(.iconAndText, count: 5), .iconAndText)
        XCTAssertEqual(TabLayout.labelStyle(.iconAndText, count: 6), .icon)
        XCTAssertEqual(TabLayout.labelStyle(.text, count: 6), .text)
    }

    func testActivityPriority() {
        let now = Date()
        XCTAssertEqual(ActivityPolicy.resolve(ActivityInputs(now: now)), .idle)
        XCTAssertEqual(ActivityPolicy.resolve(ActivityInputs(now: now, lowestLimit: 50)), .idle)
        XCTAssertEqual(ActivityPolicy.resolve(ActivityInputs(now: now, lowestLimit: 10)), .limit(remaining: 10))
        XCTAssertEqual(ActivityPolicy.resolve(ActivityInputs(now: now, musicPlaying: true, lowestLimit: 10)), .music)
        let meeting = ActivityInputs(now: now, meetingStarts: [now.addingTimeInterval(130)], musicPlaying: true)
        XCTAssertEqual(ActivityPolicy.resolve(meeting), .meeting(minutes: 3))
        XCTAssertEqual(ActivityPolicy.resolve(ActivityInputs(now: now, meetingStarts: [now.addingTimeInterval(-30)])), .meeting(minutes: 0))
        XCTAssertEqual(ActivityPolicy.resolve(ActivityInputs(now: now, meetingStarts: [now.addingTimeInterval(400)])), .idle)
        var flashed = meeting
        flashed.flash = .charging(percent: 80)
        XCTAssertEqual(ActivityPolicy.resolve(flashed), .charging(percent: 80))
    }

    func testFileStoreRoundTripAndBackupOfCorruptFile() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = JSONFileStore<[String]>("items.json", directory: directory)
        XCTAssertNil(store.load())
        XCTAssertTrue(store.save(["a", "b"]))
        XCTAssertEqual(store.load(), ["a", "b"])
        let mode = try FileManager.default.attributesOfItem(atPath: store.url.path)[.posixPermissions] as? Int
        XCTAssertEqual(mode, 0o600)
        try Data("{".utf8).write(to: store.url)
        XCTAssertNil(store.load())
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.url.appendingPathExtension("bak").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.url.path))
        // Ikkinchi buzilgan fayl eski zaxirani almashtiradi.
        try Data("[".utf8).write(to: store.url)
        XCTAssertNil(store.load())
        XCTAssertEqual(try String(contentsOf: store.url.appendingPathExtension("bak"), encoding: .utf8), "[")
        store.save(["c"])
        store.remove()
        XCTAssertNil(store.load())
    }
}
