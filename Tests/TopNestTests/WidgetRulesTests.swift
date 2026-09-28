import XCTest
@testable import TopNest

final class WidgetRulesTests: XCTestCase {
    private func state(_ kind: WidgetKind, _ configure: (inout WidgetContext) -> Void = { _ in }) -> WidgetState {
        var context = WidgetContext()
        configure(&context)
        return WidgetRules.state(for: WidgetConfig(kind: kind), in: context)
    }

    func testMusicNeedsConsentAndNeverAutoEnables() {
        XCTAssertEqual(state(.music), .needsSetup(reason: "Musiqa kuzatuvi o‘chiq", action: .openSettings(.music)))
        XCTAssertEqual(state(.music) { $0.musicEnabled = true }, .ready)
        if case .needsSetup(_, let action) = state(.music, { $0.musicEnabled = true; $0.musicPermissionDenied = true }) {
            XCTAssertEqual(action, .openAutomationPrivacy)
        } else { XCTFail("ruxsatsiz holat sozlash kartasi bo'lishi kerak") }
    }

    func testCalendarStates() {
        XCTAssertEqual(state(.calendar), .needsSetup(reason: "Kalendarga ruxsat kerak", action: .requestCalendarAccess))
        if case .needsSetup(_, let action) = state(.calendar, { $0.calendarAccess = .denied }) {
            XCTAssertEqual(action, .openCalendarPrivacy)
        } else { XCTFail() }
        XCTAssertFalse(state(.calendar) { $0.calendarAccess = .granted }.isVisible)
        XCTAssertEqual(state(.calendar) { $0.calendarAccess = .granted; $0.hasUpcomingEvents = true }, .ready)
    }

    func testClipboardNeedsConsentThenHidesWhenEmpty() {
        if case .needsSetup(_, let action) = state(.clipboard) { XCTAssertEqual(action, .openSettings(.clipboard)) } else { XCTFail() }
        XCTAssertFalse(state(.clipboard) { $0.clipboardEnabled = true }.isVisible)
        XCTAssertEqual(state(.clipboard) { $0.clipboardEnabled = true; $0.hasClips = true }, .ready)
    }

    func testWeather() {
        if case .needsSetup = state(.weather) {} else { XCTFail("shaharsiz sozlash kerak") }
        let failed = state(.weather) { $0.weatherCityConfigured = true; $0.weatherError = "Shahar topilmadi." }
        XCTAssertFalse(failed.isVisible)
        XCTAssertEqual(failed.reason, "Ob-havo yuklanmadi: Shahar topilmadi.")
        XCTAssertEqual(state(.weather) { $0.weatherCityConfigured = true; $0.hasWeather = true }, .ready)
    }

    func testCodexHiddenWhenNotInstalledNotNagging() {
        XCTAssertEqual(state(.codexLimits) { $0.codexInstalled = false }, .hidden(reason: "Codex CLI topilmadi"))
        XCTAssertEqual(state(.codexLimits) { $0.codexEnabled = false }, .hidden(reason: "Sozlamalarda o‘chirilgan"))
        XCTAssertEqual(state(.codexLimits) { $0.hasCodexUsage = true }, .ready)
    }

    func testClaude() {
        if case .needsSetup(_, let action) = state(.claudeLimits) { XCTAssertEqual(action, .openSettings(.integrations)) } else { XCTFail() }
        XCTAssertFalse(state(.claudeLimits) { $0.claudeInstalled = true }.isVisible)
        XCTAssertEqual(state(.claudeLimits) { $0.claudeInstalled = true; $0.hasClaudeUsage = true }, .ready)
    }

    func testFreshInstallShowsSetupCardsInsteadOfEmptyPanel() {
        // Yangi foydalanuvchi: standart widgetlarning kamida bittasi ko'rinadi (bo'sh panel emas).
        let context = WidgetContext(codexInstalled: false)
        let visible = WidgetStore.defaults.filter { WidgetRules.state(for: $0, in: context).isVisible }
        XCTAssertFalse(visible.isEmpty)
        XCTAssertTrue(visible.allSatisfy { if case .needsSetup = WidgetRules.state(for: $0, in: context) { true } else { false } })
    }
}
