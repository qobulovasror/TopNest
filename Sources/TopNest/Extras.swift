import AppKit
import Foundation

// MARK: Dunyo soatlari

@MainActor
final class WorldClockStore: ObservableObject {
    static let limit = 4

    @Published private(set) var zones: [String]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        zones = (defaults.stringArray(forKey: "worldClocks") ?? ["Europe/London", "America/New_York", "Asia/Tokyo"])
            .filter { TimeZone(identifier: $0) != nil }
    }

    private let defaults: UserDefaults

    func add(_ identifier: String) {
        guard TimeZone(identifier: identifier) != nil, !zones.contains(identifier), zones.count < Self.limit else { return }
        zones.append(identifier)
        save()
    }

    func remove(_ identifier: String) {
        zones.removeAll { $0 == identifier }
        save()
    }

    private func save() { defaults.set(zones, forKey: "worldClocks") }

    // "America/New_York" → "New York".
    nonisolated static func city(_ identifier: String) -> String {
        (identifier.split(separator: "/").last.map(String.init) ?? identifier).replacingOccurrences(of: "_", with: " ")
    }

    // Mahalliy vaqtga nisbatan farq: "+3 s", "−8 s 30 daq", "+30 daq", "0".
    nonisolated static func offset(_ zone: TimeZone, at date: Date, local: TimeZone = .current) -> String {
        let seconds = zone.secondsFromGMT(for: date) - local.secondsFromGMT(for: date)
        guard seconds != 0 else { return "0" }
        let sign = seconds > 0 ? "+" : "−"
        let hours = abs(seconds) / 3600, minutes = abs(seconds) % 3600 / 60
        if hours == 0 { return L10n.format("%@%d daq", sign, minutes) }
        return minutes == 0 ? L10n.format("%@%d s", sign, hours) : L10n.format("%@%d s %d daq", sign, hours, minutes)
    }

    // Qidiruv: shahar nomi bo'yicha (bo'shliq va pastki chiziq farqi hisobga olinmaydi).
    nonisolated static func search(_ query: String, limit: Int = 8) -> [String] {
        let query = query.trimmingCharacters(in: .whitespaces).lowercased().replacingOccurrences(of: " ", with: "_")
        guard query.count >= 2 else { return [] }
        return TimeZone.knownTimeZoneIdentifiers.filter { $0.lowercased().contains(query) }.prefix(limit).map { $0 }
    }
}

// MARK: Shortcuts

// macOS "Shortcuts" ilovasidagi tezkor amallar: tanlangan 4 tasi widgetdan ishga tushiriladi.
@MainActor
final class ShortcutsStore: ObservableObject {
    static let limit = 4

    @Published private(set) var selected: [String] = UserDefaults.standard.stringArray(forKey: "pinnedShortcuts") ?? []
    @Published private(set) var available: [String] = []
    @Published private(set) var loaded = false
    @Published private(set) var running: Set<String> = []
    @Published var errorMessage: String?

    func loadAvailable() {
        Task {
            let names = await Task.detached(priority: .utility) { Self.run(["list"]).map(Self.parseList) ?? [] }.value
            available = names
            loaded = true
        }
    }

    nonisolated static func parseList(_ output: String) -> [String] {
        var seen = Set<String>()
        return output.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    func toggle(_ name: String) {
        if let index = selected.firstIndex(of: name) {
            selected.remove(at: index)
        } else if selected.count < Self.limit {
            selected.append(name)
        }
        UserDefaults.standard.set(selected, forKey: "pinnedShortcuts")
    }

    func run(_ name: String) {
        guard !running.contains(name) else { return }
        running.insert(name)
        errorMessage = nil
        Task {
            let ok = await Task.detached(priority: .userInitiated) { Self.run(["run", name]) != nil }.value
            running.remove(name)
            if !ok { errorMessage = L10n.format("“%@” bajarilmadi", name) }
        }
    }

    // Muvaffaqiyatli bo'lsa chiqish matni, aks holda nil. Uzoq ishlaydigan amal 2 daqiqada to'xtatiladi.
    nonisolated private static func run(_ arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        let killer = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 120, execute: killer)
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        killer.cancel()
        return process.terminationStatus == 0 ? String(decoding: data, as: UTF8.self) : nil
    }

    func openShortcutsApp() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Shortcuts.app"))
    }
}

// MARK: Namoz vaqtlari

struct PrayerTime: Identifiable, Equatable {
    enum Name: String, CaseIterable { case fajr, sunrise, dhuhr, asr, maghrib, isha }
    let name: Name
    let date: Date
    var timeZone: TimeZone? = nil
    var id: Name { name }

    var title: String {
        switch name {
        case .fajr: L10n.tr("Bomdod")
        case .sunrise: L10n.tr("Quyosh")
        case .dhuhr: L10n.tr("Peshin")
        case .asr: L10n.tr("Asr")
        case .maghrib: L10n.tr("Shom")
        case .isha: L10n.tr("Xufton")
        }
    }
}

enum PrayerMethod: Int, CaseIterable, Identifiable {
    case mwl = 3, isna = 2, egypt = 5, ummAlQura = 4, karachi = 1, diyanet = 13
    var id: Self { self }
    var title: String {
        switch self {
        case .mwl: "Muslim World League"
        case .isna: "ISNA"
        case .egypt: "Egyptian General Authority"
        case .ummAlQura: "Umm al-Qura"
        case .karachi: "Karachi"
        case .diyanet: "Diyanet"
        }
    }
}

enum PrayerParser {
    // Aladhan javobi: "HH:mm" (ba'zan " (+05)" qo'shimchasi bilan) shahar vaqtida (meta.timezone) va javobdagi sana bo'yicha;
    // Mac boshqa vaqt zonasida bo'lsa ham to'g'ri lahza olinadi.
    static func parse(_ data: Data, day fallbackDay: Date, calendar fallback: Calendar = .current) -> [PrayerTime] {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let payload = object["data"] as? [String: Any],
              let timings = payload["timings"] as? [String: String] else { return [] }
        var calendar = fallback
        if let zone = ((payload["meta"] as? [String: Any])?["timezone"] as? String).flatMap(TimeZone.init(identifier:)) {
            calendar.timeZone = zone
        }
        var day = fallbackDay
        if let date = ((payload["date"] as? [String: Any])?["gregorian"] as? [String: Any])?["date"] as? String {
            let parts = date.split(separator: "-").compactMap { Int($0) }
            if parts.count == 3, let parsed = calendar.date(from: DateComponents(year: parts[2], month: parts[1], day: parts[0], hour: 12)) {
                day = parsed
            }
        }
        let keys: [(String, PrayerTime.Name)] = [("Fajr", .fajr), ("Sunrise", .sunrise), ("Dhuhr", .dhuhr), ("Asr", .asr), ("Maghrib", .maghrib), ("Isha", .isha)]
        return keys.compactMap { key, name in
            let parts = (timings[key] ?? "").prefix(5).split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2, let date = calendar.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: day) else { return nil }
            return PrayerTime(name: name, date: date, timeZone: calendar.timeZone)
        }
    }

    // Keyingi namoz (quyosh chiqishi namoz emas, lekin vaqt sifatida ko'rsatiladi).
    static func next(_ times: [PrayerTime], after now: Date) -> PrayerTime? {
        times.filter { $0.date > now }.min { $0.date < $1.date }
    }
}

@MainActor
final class PrayerService: ObservableObject {
    @Published private(set) var times: [PrayerTime] = []
    @Published private(set) var tomorrowFajr: PrayerTime?
    @Published var errorMessage: String?
    @Published var method = PrayerMethod(rawValue: UserDefaults.standard.integer(forKey: "prayerMethod")) ?? .mwl {
        didSet { UserDefaults.standard.set(method.rawValue, forKey: "prayerMethod"); loadedKey = nil; reloadLast() }
    }
    // O'zbekistonda Hanafiy mazhabi bo'yicha asr.
    @Published var hanafi = (UserDefaults.standard.object(forKey: "prayerHanafi") as? Bool) ?? true {
        didSet { UserDefaults.standard.set(hanafi, forKey: "prayerHanafi"); loadedKey = nil; reloadLast() }
    }
    private var loadedKey: String?
    private var loading = false
    private var last: (latitude: Double, longitude: Double)?
    private var pendingReload = false
    // Shahar vaqt zonasi (oxirgi javobdan): kun shu zonada hisoblanadi.
    private var cityTimeZone = TimeZone.current
    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        return URLSession(configuration: config)
    }()

    func next(after now: Date) -> PrayerTime? { PrayerParser.next(times, after: now) ?? tomorrowFajr }

    // Kuniga bir marta (yoki joy/sozlama o'zgarganda) yuklanadi.
    private func reloadLast() {
        guard let last else { return }
        refresh(latitude: last.latitude, longitude: last.longitude)
    }

    func refresh(latitude: Double, longitude: Double, now: Date = Date()) {
        last = (latitude, longitude)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = cityTimeZone
        let day = ScreenTimeLedger.key(for: now, calendar: calendar)
        let key = "\(day)|\((latitude * 100).rounded())|\((longitude * 100).rounded())|\(method.rawValue)|\(hanafi)"
        guard key != loadedKey else { return }
        // Yuklanayotgan paytdagi so'rov yo'qolmaydi: tugagach qayta tekshiriladi.
        guard !loading else { pendingReload = true; return }
        loading = true
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        Task { [weak self] in
            guard let self else { return }
            let today = await self.fetch(day: now, calendar: calendar, latitude: latitude, longitude: longitude)
            let next = await self.fetch(day: tomorrow, calendar: calendar, latitude: latitude, longitude: longitude)
            self.loading = false
            if today.isEmpty {
                self.errorMessage = L10n.tr("Namoz vaqtlarini yuklab bo‘lmadi.")
            } else {
                self.times = today
                self.tomorrowFajr = next.first { $0.name == .fajr }
                self.errorMessage = nil
                // Javobdagi vaqt zonasi boshqa bo'lsa kun kaliti qayta hisoblanadi (kerak bo'lsa qayta so'raladi).
                let zone = today[0].timeZone ?? self.cityTimeZone
                if zone != self.cityTimeZone {
                    self.cityTimeZone = zone
                    self.pendingReload = true
                } else {
                    self.loadedKey = key
                }
            }
            if self.pendingReload {
                self.pendingReload = false
                self.reloadLast()
            }
        }
    }

    private func fetch(day: Date, calendar: Calendar, latitude: Double, longitude: Double) async -> [PrayerTime] {
        let parts = calendar.dateComponents([.day, .month, .year], from: day)
        let date = String(format: "%02d-%02d-%04d", parts.day ?? 1, parts.month ?? 1, parts.year ?? 2026)
        var components = URLComponents(string: "https://api.aladhan.com/v1/timings/\(date)")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.2f", latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.2f", longitude)),
            URLQueryItem(name: "method", value: String(method.rawValue)),
            URLQueryItem(name: "school", value: hanafi ? "1" : "0")
        ]
        guard let url = components.url, let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return [] }
        return PrayerParser.parse(data, day: day, calendar: calendar)
    }
}

// MARK: Yuklab olishlar

struct DownloadItem: Equatable {
    let name: String
    let progress: Double?
}

enum DownloadScanner {
    static let partialExtensions = ["download", "crdownload", "part", "partial"]

    // Safari ".download" to'plamidagi Info.plist'da yuklangan va umumiy baytlar bor; boshqa brauzerlarda umumiy hajm noma'lum.
    static func scan(_ directory: URL) -> [DownloadItem] {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else { return [] }
        return names.compactMap { name in
            let url = directory.appendingPathComponent(name)
            guard partialExtensions.contains(url.pathExtension.lowercased()) else { return nil }
            let display = url.deletingPathExtension().lastPathComponent
            guard url.pathExtension.lowercased() == "download",
                  let plist = NSDictionary(contentsOf: url.appendingPathComponent("Info.plist")) as? [String: Any] else {
                return DownloadItem(name: display, progress: nil)
            }
            return DownloadItem(name: display, progress: progress(from: plist))
        }
        .sorted { $0.name < $1.name }
    }

    static func progress(from plist: [String: Any]) -> Double? {
        guard let done = (plist["DownloadEntryProgressBytesSoFar"] as? NSNumber)?.doubleValue,
              let total = (plist["DownloadEntryProgressTotalToLoad"] as? NSNumber)?.doubleValue, total > 0 else { return nil }
        return min(1, max(0, done / total))
    }

    // Bir nechta yuklanma: ma'lum foizlarning o'rtachasi, hech biri ma'lum bo'lmasa nil.
    static func overall(_ items: [DownloadItem]) -> Double? {
        let known = items.compactMap(\.progress)
        return known.isEmpty ? nil : known.reduce(0, +) / Double(known.count)
    }
}

// ~/Downloads kuzatuvi (ixtiyoriy: macOS papkaga kirish ruxsatini so'raydi). Yuklanma bor paytdagina har soniya tekshiriladi.
@MainActor
final class DownloadsMonitor: ObservableObject {
    @Published private(set) var items: [DownloadItem] = []
    // Papkani ochib bo'lmadi (ruxsat berilmagan): sozlamada ko'rsatiladi, vaqti-vaqti bilan qayta uriniladi.
    @Published private(set) var accessDenied = false
    private var enabled = false
    private var source: DispatchSourceFileSystemObject?
    private var timer: Timer?
    private let directory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")

    func setEnabled(_ enabled: Bool) {
        self.enabled = enabled
        enabled ? start() : stop()
    }

    func retryIfNeeded() {
        if enabled, source == nil { start() }
    }

    private func start() {
        guard source == nil else { return }
        let descriptor = open(directory.path, O_EVTONLY)
        accessDenied = descriptor < 0
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: [.write, .rename, .delete], queue: .main)
        source.setEventHandler { [weak self] in MainActor.assumeIsolated { self?.scan() } }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        self.source = source
        scan()
    }

    private func stop() {
        source?.cancel()
        source = nil
        timer?.invalidate()
        timer = nil
        items = []
        accessDenied = false
    }

    private func scan() {
        let next = DownloadScanner.scan(directory)
        if next != items { items = next }
        if next.isEmpty {
            timer?.invalidate()
            timer = nil
        } else if timer == nil {
            let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.scan() } }
            timer.tolerance = 0.3
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
    }
}
