import XCTest
@testable import TopNest

final class MusicSourcePolicyTests: XCTestCase {
    func testAppleScriptFallbackRules() {
        // Standart rejim yoki kengaytirilgan rejim ishlamay qolganda AppleScript ishlaydi.
        XCTAssertTrue(MusicSourcePolicy.appleScriptAllowed(status: .off, recovering: false, hasMediaTrack: false))
        XCTAssertTrue(MusicSourcePolicy.appleScriptAllowed(status: .failed, recovering: false, hasMediaTrack: false))
        // Birinchi ulanish kutiladi, qayta urinishda esa zaxira ishlaydi.
        XCTAssertFalse(MusicSourcePolicy.appleScriptAllowed(status: .starting, recovering: false, hasMediaTrack: false))
        XCTAssertTrue(MusicSourcePolicy.appleScriptAllowed(status: .starting, recovering: true, hasMediaTrack: false))
        // Ishlayotgan rejim trek bersa, AppleScript uni bosmaydi; "jim" holatda (trek yo'q) zaxira tekshiriladi.
        XCTAssertFalse(MusicSourcePolicy.appleScriptAllowed(status: .active, recovering: false, hasMediaTrack: true))
        XCTAssertTrue(MusicSourcePolicy.appleScriptAllowed(status: .active, recovering: false, hasMediaTrack: false))
    }
}

final class PersistenceTests: XCTestCase {
    func testOldWidgetConfigWithoutNewFieldsDecodes() throws {
        let json = #"{"kind":"calendar"}"#.data(using: .utf8)!
        let widget = try JSONDecoder().decode(WidgetConfig.self, from: json)
        XCTAssertEqual(widget.kind, .calendar)
        XCTAssertEqual(widget.size, WidgetKind.calendar.defaultSize)
        XCTAssertEqual(widget.statStyle, .ring)
    }

    func testWidgetConfigRoundTrip() throws {
        var widget = WidgetConfig(kind: .cpu, size: .medium)
        widget.statStyle = .graph
        let decoded = try JSONDecoder().decode(WidgetConfig.self, from: JSONEncoder().encode(widget))
        XCTAssertEqual(decoded, widget)
    }

    func testCustomSpecPartialDecodeAndNormalize() throws {
        let json = #"{"title":"  BTC ","target":" https://api.example.com/p \n","refreshSeconds":1}"#.data(using: .utf8)!
        let spec = try JSONDecoder().decode(CustomWidgetSpec.self, from: json)
        XCTAssertEqual(spec.source, .url)
        let normalized = try XCTUnwrap(spec.normalized())
        XCTAssertEqual(normalized.title, "BTC")
        XCTAssertEqual(normalized.target, "https://api.example.com/p")
        XCTAssertEqual(normalized.refreshSeconds, 10)
        var empty = spec
        empty.target = "   "
        XCTAssertNil(empty.normalized())
    }

    func testJSONPath() throws {
        let object = try JSONSerialization.jsonObject(with: #"{"a":{"b":[{"c":1.5},{"c":true}]},"s":"x"}"#.data(using: .utf8)!)
        XCTAssertEqual(JSONPath.describe(JSONPath.extract("a.b[0].c", from: object)), "1.5")
        XCTAssertEqual(JSONPath.describe(JSONPath.extract("a.b[1].c", from: object)), "true")
        XCTAssertEqual(JSONPath.describe(JSONPath.extract("s", from: object)), "x")
        XCTAssertNil(JSONPath.describe(JSONPath.extract("a.b[9]", from: object)))
    }

    func testLowestRemainingIgnoresResetAndStaleWindows() {
        let now = Date()
        let snapshot = UsageSnapshot(
            primary: UsageWindow(usedPercent: 90, resetAt: now.addingTimeInterval(-60)),
            secondary: UsageWindow(usedPercent: 70, resetAt: now.addingTimeInterval(3600)),
            updatedAt: now.addingTimeInterval(-7200)
        )
        // Birinchisi tiklangan, ikkinchisining reset vaqti kelmagan — eskirgan bo'lsa ham ishonchli.
        XCTAssertEqual(snapshot.lowestRemaining(at: now), 30)
        let stale = UsageSnapshot(primary: UsageWindow(usedPercent: 95, resetAt: nil), secondary: nil, updatedAt: now.addingTimeInterval(-7200))
        XCTAssertNil(stale.lowestRemaining(at: now))
    }
}
