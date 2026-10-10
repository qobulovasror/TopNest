import AppKit
import SwiftUI
import XCTest
@testable import TopNest

// Vizual tekshiruv uchun: TOPNEST_SNAPSHOT_DIR o'rnatilgan bo'lsa asosiy holatlarni PNG'ga chizadi.
// Oddiy test ishga tushirishda hech narsa yozilmaydi.
@MainActor
final class SnapshotTests: XCTestCase {
    private var directory: URL?

    override func setUp() async throws {
        guard let path = ProcessInfo.processInfo.environment["TOPNEST_SNAPSHOT_DIR"] else {
            throw XCTSkip("TOPNEST_SNAPSHOT_DIR o'rnatilmagan")
        }
        directory = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: directory!, withIntermediateDirectories: true)
    }

    private func render<V: View>(_ name: String, width: CGFloat, height: CGFloat, scheme: ColorScheme = .dark, @ViewBuilder _ view: () -> V) throws {
        let content = view()
            .frame(width: width, height: height)
            .padding(16)
            .background(scheme == .dark ? Color.black : Color.white)
            .environment(\.colorScheme, scheme)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.nsImage, name)
        let data = try XCTUnwrap(NSBitmapImageRep(data: try XCTUnwrap(image.tiffRepresentation))?.representation(using: .png, properties: [:]))
        try data.write(to: directory!.appendingPathComponent("\(name).png"))
    }

    private static let artwork: Data = {
        let image = NSImage(size: NSSize(width: 300, height: 300))
        image.lockFocus()
        NSGradient(starting: .systemIndigo, ending: .systemPink)?.draw(in: NSRect(x: 0, y: 0, width: 300, height: 300), angle: 45)
        image.unlockFocus()
        return NSBitmapImageRep(data: image.tiffRepresentation!)!.representation(using: .png, properties: [:])!
    }()

    private func track(artwork: Bool, playing: Bool = true) -> TrackInfo {
        // Haqiqiy bundle ID ilova ikonkasini (NSImage) yuklaydi, u esa ImageRenderer'da butun rasmni
        // xiralashtiradi (faqat renderer artefakti). Shuning uchun mavjud bo'lmagan ID ishlatiladi.
        TrackInfo(title: "Urban Vengeance — Extended Mix", artist: "EDBU, Venecellia", source: "Yandex Music",
                  bundleID: "snapshot.no-icon", playing: playing, position: 42, duration: 155,
                  artworkURL: nil, artworkData: artwork ? Self.artwork : nil, observedAt: Date())
    }

    private let contentWidth: CGFloat = 648
    private let contentHeight: CGFloat = 210

    func testMusicSizesAndStates() throws {
        for size in WidgetSize.allCases {
            let width: CGFloat = size == .small ? 156 : 320
            let height: CGFloat = size == .large ? 210 : 101
            for (label, artwork, seek) in [("art-standard", true, false), ("noart-extended", false, true)] {
                try render("music-\(size.rawValue)-\(label)", width: width, height: height) {
                    MusicWidget(track: track(artwork: artwork), size: size, canSeek: seek, onControl: { _ in }, onSeek: { _ in })
                }
            }
        }
        for (label, status, extended) in [("idle", MediaRemoteService.Status.off, false), ("starting", .starting, true), ("failed", .failed, true)] {
            try render("music-idle-\(label)", width: 320, height: 101) {
                MusicIdleWidget(size: .medium, status: status, extended: extended)
            }
        }
    }

    // Yangi foydalanuvchi: "Xush kelibsiz" + sozlash kartalari (bo'sh panel emas), standart va ixcham panelda.
    func testFirstRunGrid() throws {
        try renderFirstRun(name: "grid-first-run", width: contentWidth, height: contentHeight)
        try renderFirstRun(name: "grid-first-run-compact", width: 568, height: 170, musicDenied: true)
    }

    private func renderFirstRun(name: String, width: CGFloat, height: CGFloat, musicDenied: Bool = false) throws {
        let context = WidgetContext(musicEnabled: musicDenied, musicPermissionDenied: musicDenied, codexInstalled: false)
        let visible = WidgetStore.defaults.compactMap { widget -> (WidgetConfig, WidgetState)? in
            let state = WidgetRules.state(for: widget, in: context)
            return state.isVisible ? (widget, state) : nil
        }
        let items = [WidgetGridItem(id: HomeContent.welcomeID, size: .large)] + visible.map { WidgetGridItem(id: $0.0.id, size: .small) }
        try render(name, width: width, height: height) {
            WidgetGrid(layout: WidgetLayout.pack(items, rows: 2), firstColumn: .constant(0), allowsScrolling: false) { id in
                if id == HomeContent.welcomeID {
                    WelcomeCard(onSettings: {}, onDismiss: {})
                } else if let entry = visible.first(where: { $0.0.id == id }), case .needsSetup(let reason, let action) = entry.1 {
                    SetupCard(title: entry.0.title, icon: entry.0.icon, reason: reason, actionTitle: action.title, onAction: {})
                }
            }
        }
    }

    func testSettingsPreview() throws {
        let fresh = WidgetContext(codexInstalled: false)
        try render("settings-preview-first-run", width: 460, height: 150) {
            WidgetLayoutPreview(widgets: WidgetStore.defaults, context: fresh)
        }
        var configured = WidgetContext(musicEnabled: true, calendarAccess: .granted, hasUpcomingEvents: true,
                                       weatherCityConfigured: true, hasWeather: true, clipboardEnabled: true, hasClips: true,
                                       hasCodexUsage: true, claudeInstalled: true, hasClaudeUsage: true)
        configured.codexInstalled = true
        let many = WidgetStore.defaults + [WidgetConfig(kind: .cpu), WidgetConfig(kind: .network), WidgetConfig(kind: .memory, size: .medium)]
        try render("settings-preview-many", width: 460, height: 150) {
            WidgetLayoutPreview(widgets: many, context: configured)
        }
    }

    func testLightThemeWidgets() throws {
        try render("music-light", width: 320, height: 101, scheme: .light) {
            MusicWidget(track: track(artwork: true), size: .medium, canSeek: false, onControl: { _ in }, onSeek: { _ in })
        }
        try render("music-idle-light", width: 320, height: 101, scheme: .light) {
            MusicIdleWidget(size: .medium, status: .off, extended: false)
        }
    }

    func testTypicalAndFewWidgetGrids() throws {
        let now = Date()
        let usage = UsageSnapshot(primary: UsageWindow(usedPercent: 46, resetAt: now.addingTimeInterval(3000)),
                                  secondary: UsageWindow(usedPercent: 13, resetAt: now.addingTimeInterval(300_000)), updatedAt: now)
        let weather = WeatherInfo(temperature: 23, code: 0, city: "Tashkent", updatedAt: now,
                                  hourly: [HourlyWeather(time: "2026-09-28T18:00", temperature: 22, code: 1),
                                           HourlyWeather(time: "2026-09-28T19:00", temperature: 20, code: 2),
                                           HourlyWeather(time: "2026-09-28T20:00", temperature: 19, code: 3)])
        let music = UUID(), weatherID = UUID(), claude = UUID(), codex = UUID(), clip = UUID()
        func cell(_ id: UUID, size: WidgetSize) -> AnyView {
            switch id {
            case music: AnyView(MusicWidget(track: track(artwork: true), size: size, canSeek: true, onControl: { _ in }, onSeek: { _ in }))
            case weatherID: AnyView(WeatherWidget(info: weather, size: size))
            case claude: AnyView(LimitWidget(name: "Claude", snapshot: usage, labels: ("5 soat", "7 kun"), size: size))
            case codex: AnyView(LimitWidget(name: "Codex", snapshot: usage, labels: ("Asosiy", "Qo‘shimcha"), size: size))
            default: AnyView(SetupCard(title: "Clipboard", icon: "doc.on.clipboard", reason: "Clipboard tarixi o‘chiq", actionTitle: "Sozlash", onAction: {}))
            }
        }
        let typical: [(UUID, WidgetSize)] = [(music, .large), (weatherID, .medium), (claude, .small), (codex, .small)]
        try render("grid-typical", width: contentWidth, height: contentHeight) {
            WidgetGrid(layout: WidgetLayout.pack(typical.map { WidgetGridItem(id: $0.0, size: $0.1) }, rows: 2), firstColumn: .constant(0), allowsScrolling: false) { id in
                cell(id, size: typical.first { $0.0 == id }!.1)
            }
        }
        let few: [(UUID, WidgetSize)] = [(weatherID, .small), (claude, .small)]
        try render("grid-few", width: contentWidth, height: contentHeight) {
            WidgetGrid(layout: WidgetLayout.pack(few.map { WidgetGridItem(id: $0.0, size: $0.1) }, rows: 2), firstColumn: .constant(0), allowsScrolling: false) { id in
                cell(id, size: .small)
            }
        }
        let many: [(UUID, WidgetSize)] = typical + [(clip, .small), (UUID(), .medium), (UUID(), .small)]
        try render("grid-many", width: contentWidth, height: contentHeight) {
            WidgetGrid(layout: WidgetLayout.pack(many.map { WidgetGridItem(id: $0.0, size: $0.1) }, rows: 2), firstColumn: .constant(0), allowsScrolling: false) { id in
                cell(id, size: many.first { $0.0 == id }!.1)
            }
        }
    }

    // v0.7 asboblari: har o'lchamda bo'sh va ishlayotgan holat.
    func testFocusTimerWidget() throws {
        let focus = FocusTimerService()
        defer { focus.stop() }
        focus.stop()
        for size in WidgetSize.allCases {
            let width: CGFloat = size == .small ? 156 : 320
            let height: CGFloat = size == .large ? 210 : 101
            try render("focus-\(size.rawValue)-idle", width: width, height: height) { FocusTimerWidget(focus: focus, size: size) }
        }
        focus.startPomodoro()
        for size in WidgetSize.allCases {
            let width: CGFloat = size == .small ? 156 : 320
            let height: CGFloat = size == .large ? 210 : 101
            try render("focus-\(size.rawValue)-running", width: width, height: height) { FocusTimerWidget(focus: focus, size: size) }
        }
        try render("focus-wing", width: 80, height: 32) {
            HStack { FocusWingRing(session: focus.session!); FocusWingTime(session: focus.session!) }
        }
    }

    func testCalculatorWidget() throws {
        let calculator = CalculatorStore(defaults: UserDefaults(suiteName: "snapshot-calc")!)
        calculator.input = "1250 × 12 + 15%"
        for size in WidgetSize.allCases {
            let width: CGFloat = size == .small ? 156 : 320
            let height: CGFloat = size == .large ? 210 : 101
            try render("calc-\(size.rawValue)", width: width, height: height) { CalculatorWidget(calculator: calculator, size: size, onCopy: { _ in }) }
        }
        calculator.input = "12 / 0"
        try render("calc-error", width: 156, height: 101) { CalculatorWidget(calculator: calculator, size: .small, onCopy: { _ in }) }
    }

    func testNotes() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let notes = NotesStore(store: JSONFileStore("notes.json", directory: directory))
        notes.create("Uchrashuv rejasi\nDizayn ko‘rib chiqish, release sanasi, test natijalari")
        let pinned = notes.create("Xarid ro‘yxati\nnon, sut, olma")
        notes.togglePin(pinned.id)
        for size in WidgetSize.allCases where size != .large {
            let width: CGFloat = size == .small ? 156 : 320
            try render("notes-\(size.rawValue)", width: width, height: 101) { NotesWidget(notes: notes, size: size, onOpen: { _ in }, onNew: {}) }
        }
        try render("notes-tab", width: contentWidth, height: contentHeight) { NotesContent(notes: notes) }
    }

    func testDevicesWidget() throws {
        let service = DeviceBatteryService()
        // Widget faqat ko'rinish uchun: ma'lumot o'rniga namunaviy qurilmalar.
        service.setPreview([
            BluetoothDevice(id: "1", name: "AirPods Pro", kind: .airpods, batteries: [BatteryReading(part: .left, percent: 85), BatteryReading(part: .right, percent: 90), BatteryReading(part: .caseUnit, percent: 40)]),
            BluetoothDevice(id: "2", name: "Magic Mouse", kind: .mouse, batteries: [BatteryReading(part: .main, percent: 15)])
        ])
        for size in WidgetSize.allCases {
            let width: CGFloat = size == .small ? 156 : 320
            let height: CGFloat = size == .large ? 210 : 101
            try render("devices-\(size.rawValue)", width: width, height: height) {
                DeviceBatteryWidget(service: service, power: PowerService(), size: size, includeMac: true)
            }
        }
    }

    func testSystemWidget() throws {
        let stats = SystemStatsService()
        for size in WidgetSize.allCases {
            let width: CGFloat = size == .small ? 156 : 320
            let height: CGFloat = size == .large ? 210 : 101
            try render("system-\(size.rawValue)", width: width, height: height) { SystemWidget(id: UUID(), stats: stats, size: size) }
        }
    }

    func testScreenTimeWidget() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var ledger = ScreenTimeLedger()
        let now = Date()
        for (offset, hours) in [(6, 3.0), (5, 5.5), (4, 2.0), (3, 6.2), (2, 4.1), (1, 1.5)] {
            let day = Calendar.current.date(byAdding: .day, value: -offset, to: Calendar.current.startOfDay(for: now))!.addingTimeInterval(9 * 3600)
            ledger.add("com.apple.Safari", from: day, to: day.addingTimeInterval(hours * 3600))
        }
        let today = Calendar.current.startOfDay(for: now)
        ledger.add("com.apple.dt.Xcode", from: today, to: today.addingTimeInterval(min(7200, now.timeIntervalSince(today))))
        ledger.add("com.apple.Safari", from: today, to: today.addingTimeInterval(min(2400, now.timeIntervalSince(today))))
        ledger.names = ["com.apple.Safari": "Safari", "com.apple.dt.Xcode": "Xcode"]
        let store = JSONFileStore<ScreenTimeLedger>("screen.json", directory: directory)
        store.save(ledger)
        let tracker = ScreenTimeTracker(store: store)
        for size in WidgetSize.allCases {
            let width: CGFloat = size == .small ? 156 : 320
            let height: CGFloat = size == .large ? 210 : 101
            try render("screentime-\(size.rawValue)", width: width, height: height) { ScreenTimeWidget(tracker: tracker, size: size) }
        }
    }

    func testWeatherLarge() throws {
        let info = WeatherInfo(temperature: 21, code: 1, city: "Toshkent", updatedAt: Date(),
                               hourly: [HourlyWeather(time: "2026-10-10T16:00", temperature: 20, code: 2),
                                        HourlyWeather(time: "2026-10-10T17:00", temperature: 19, code: 3),
                                        HourlyWeather(time: "2026-10-10T18:00", temperature: 17, code: 61)],
                               apparent: 19, precipitationChance: 30,
                               daily: [DailyWeather(date: "2026-10-10", code: 1, high: 23, low: 12, precipitation: 10),
                                       DailyWeather(date: "2026-10-11", code: 61, high: 19, low: 10, precipitation: 90),
                                       DailyWeather(date: "2026-10-12", code: 3, high: 20, low: 9, precipitation: 30),
                                       DailyWeather(date: "2026-10-13", code: 0, high: 24, low: 11, precipitation: nil)])
        try render("weather-large", width: 320, height: 210) { WeatherWidget(info: info, size: .large) }
    }

    func testMoreToolWidgets() throws {
        let clocks = WorldClockStore(defaults: UserDefaults(suiteName: "snapshot-clocks-\(UUID().uuidString)")!)
        let translator = TranslatorStore()
        let reminders = RemindersService()
        for size in WidgetSize.allCases {
            let width: CGFloat = size == .small ? 156 : 320
            let height: CGFloat = size == .large ? 210 : 101
            try render("clock-\(size.rawValue)", width: width, height: height) { WorldClockWidget(store: clocks, size: size) }
            try render("translate-\(size.rawValue)", width: width, height: height) {
                TranslateWidget(translator: translator, size: size, clipboardText: "Salom, dunyo", onCopy: { _ in }, onSetup: {})
            }
            try render("tasks-\(size.rawValue)", width: width, height: height) { TasksWidget(reminders: reminders, size: size, onOpen: {}) }
        }
    }
}
