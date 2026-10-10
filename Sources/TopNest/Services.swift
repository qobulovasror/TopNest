import AppKit
import EventKit
import Foundation

struct TrackInfo: Equatable, Sendable {
    let title: String
    let artist: String
    let source: String
    let bundleID: String
    let playing: Bool
    let position: Double
    let duration: Double
    let artworkURL: URL?
    let artworkData: Data?
    let observedAt: Date

    var elapsed: Double {
        let value = position + (playing ? Date().timeIntervalSince(observedAt) : 0)
        return duration > 0 ? min(duration, max(0, value)) : max(0, value)
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, elapsed / duration))
    }
}

struct MusicProbe: Sendable {
    let track: TrackInfo?
    // macOS Automation ruxsati rad etilgan (AppleScript xatosi -1743).
    let permissionDenied: Bool
}

enum MusicService {
    static let automationDeniedError = -1743

    static func current() -> MusicProbe {
        let players: [(String, String)] = [
            ("com.spotify.client", "Spotify"),
            ("com.apple.Music", "Music")
        ]
        var found: [TrackInfo] = []
        var denied = false
        for (bundleID, name) in players where !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty {
            let script: String
            if name == "Spotify" {
                script = "set coverURL to \"\"\ntry\ntell application id \"com.spotify.client\" to set coverURL to artwork url of current track as text\nend try\ntell application id \"com.spotify.client\" to return (player state as text) & \"|||\" & (name of current track) & \"|||\" & (artist of current track) & \"|||\" & (player position as text) & \"|||\" & (duration of current track as text) & \"|||\" & coverURL"
            } else {
                script = "tell application id \"com.apple.Music\" to return (player state as text) & \"|||\" & (name of current track) & \"|||\" & (artist of current track) & \"|||\" & (player position as text) & \"|||\" & (duration of current track as text)"
            }
            var error: NSDictionary?
            guard let output = NSAppleScript(source: script)?.executeAndReturnError(&error).stringValue else {
                if (error?[NSAppleScript.errorNumber] as? Int) == automationDeniedError { denied = true }
                continue
            }
            let parts = output.components(separatedBy: "|||")
            guard parts.count >= 5, !parts[1].isEmpty else { continue }
            let rawDuration = Double(parts[4]) ?? 0
            // Spotify's AppleScript dictionary labels duration as seconds, but reports milliseconds.
            let duration = name == "Spotify" ? rawDuration / 1000 : rawDuration
            found.append(TrackInfo(
                title: parts[1], artist: parts[2], source: name, bundleID: bundleID,
                playing: parts[0].lowercased().contains("playing"),
                position: Double(parts[3]) ?? 0, duration: duration,
                artworkURL: parts.count > 5 ? spotifyArtworkURL(parts[5]) : nil,
                artworkData: nil,
                observedAt: Date()
            ))
        }
        let track = found.first(where: { $0.playing }) ?? found.first
        return MusicProbe(track: track, permissionDenied: denied && track == nil)
    }

    static func control(bundleID: String, action: String) {
        guard ["playpause", "next track", "previous track"].contains(action),
              ["com.spotify.client", "com.apple.Music"].contains(bundleID) else { return }
        let script = "tell application id \"\(bundleID)\" to \(action)"
        var error: NSDictionary?
        _ = NSAppleScript(source: script)?.executeAndReturnError(&error)
    }

    private static func spotifyArtworkURL(_ raw: String) -> URL? {
        guard let url = URL(string: raw), url.scheme == "https", let host = url.host?.lowercased(),
              host == "scdn.co" || host.hasSuffix(".scdn.co") || host == "spotifycdn.com" || host.hasSuffix(".spotifycdn.com") else { return nil }
        return url
    }
}

struct ClipItem: Identifiable, Equatable, Codable {
    var id = UUID()
    let text: String
    let capturedAt: Date
}

@MainActor
final class ClipboardService: ObservableObject {
    static let limit = 25
    static let pinLimit = 50

    @Published private(set) var items: [ClipItem] = []
    // Mahkamlanganlar foydalanuvchi tanlovi bilan diskda saqlanadi, qolgan tarix faqat xotirada.
    @Published private(set) var pinned: [ClipItem] = []
    private var lastChange = NSPasteboard.general.changeCount

    private let pinnedStore = JSONFileStore<[ClipItem]>("pinned-clips.json")

    init() {
        pinned = pinnedStore.load() ?? []
    }

    func check(enabled: Bool) {
        let board = NSPasteboard.general
        guard board.changeCount != lastChange else { return }
        lastChange = board.changeCount
        guard enabled, let value = board.string(forType: .string), !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        // nspasteboard.org belgilari: parol va vaqtinchalik ma'lumot tarixga yozilmaydi.
        let privateTypes = ["org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType", "org.nspasteboard.AutoGeneratedType", "com.agilebits.onepassword"]
        if let types = board.types, types.contains(where: { privateTypes.contains($0.rawValue) }) { return }
        let excluded = ["com.1password.1password", "com.bitwarden.desktop", "com.agilebits.onepassword7"]
        if let source = NSWorkspace.shared.frontmostApplication?.bundleIdentifier, excluded.contains(source) { return }
        guard items.first?.text != value, !pinned.contains(where: { $0.text == value }) else { return }
        items.insert(ClipItem(text: value, capturedAt: Date()), at: 0)
        items = Array(items.prefix(Self.limit))
    }

    func copy(_ item: ClipItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.text, forType: .string)
        lastChange = NSPasteboard.general.changeCount
    }

    // Ilova o'zi nusxalagan matn tarixga ikki marta tushmaydi.
    func copyText(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        lastChange = NSPasteboard.general.changeCount
    }

    func clear() { items.removeAll() }

    func clearPinned() {
        pinned.removeAll()
        savePinned()
    }

    func remove(_ item: ClipItem) {
        items.removeAll { $0.id == item.id }
        if pinned.contains(where: { $0.id == item.id }) {
            pinned.removeAll { $0.id == item.id }
            savePinned()
        }
    }

    func isPinned(_ item: ClipItem) -> Bool { pinned.contains { $0.id == item.id } }

    func togglePin(_ item: ClipItem) {
        if isPinned(item) {
            pinned.removeAll { $0.id == item.id }
            items.insert(item, at: 0)
            items = Array(items.prefix(Self.limit))
        } else {
            items.removeAll { $0.id == item.id || $0.text == item.text }
            pinned.insert(item, at: 0)
            pinned = Array(pinned.prefix(Self.pinLimit))
        }
        savePinned()
    }

    private func savePinned() {
        if pinned.isEmpty { pinnedStore.remove() } else { pinnedStore.save(pinned) }
    }
}

struct CalendarItem: Identifiable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let url: URL?
    let meetingURL: URL?

    // Havola: avval video uchrashuv, bo'lmasa oddiy http(s) havola.
    var link: URL? { meetingURL ?? url.flatMap { ["https", "http"].contains($0.scheme?.lowercased() ?? "") ? $0 : nil } }

    func minutesUntilStart(from now: Date = Date()) -> Int {
        Int((start.timeIntervalSince(now) / 60).rounded(.up))
    }
}

struct CalendarSource: Identifiable {
    let id: String
    let title: String
    let color: NSColor
}

enum MeetingLinkFinder {
    private static let hosts = ["zoom.us", "meet.google.com", "teams.microsoft.com", "teams.live.com", "webex.com", "whereby.com", "facetime.apple.com"]
    private static let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    static func find(in texts: [String?]) -> URL? {
        for text in texts.compactMap({ $0 }) {
            let range = NSRange(text.startIndex..., in: text)
            for match in detector?.matches(in: text, range: range) ?? [] {
                guard let url = match.url, isMeeting(url) else { continue }
                return url
            }
        }
        return nil
    }

    static func isMeeting(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https", let host = url.host?.lowercased() else { return false }
        return hosts.contains { host == $0 || host.hasSuffix("." + $0) }
    }
}

@MainActor
final class CalendarService: ObservableObject {
    @Published private(set) var events: [CalendarItem] = []
    @Published private(set) var sources: [CalendarSource] = []
    @Published private(set) var accessGranted = false
    @Published private(set) var access: CalendarAccess = .notDetermined
    @Published private(set) var excludedIDs = Set(UserDefaults.standard.stringArray(forKey: "excludedCalendars") ?? [])
    @Published var errorMessage: String?
    private let store = EKEventStore()
    private var storeObserver: NSObjectProtocol?

    init() {
        updateAccess()
        storeObserver = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        if accessGranted { refresh() }
    }

    func requestAccess() {
        Task {
            do {
                _ = try await store.requestFullAccessToEvents()
                updateAccess()
                if accessGranted { refresh() }
                else { errorMessage = "Kalendar ruxsati berilmadi." }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func setIncluded(_ included: Bool, calendarID: String) {
        if included { excludedIDs.remove(calendarID) } else { excludedIDs.insert(calendarID) }
        UserDefaults.standard.set(Array(excludedIDs), forKey: "excludedCalendars")
        refresh()
    }

    // Tizim sozlamalarida ruxsat o'zgargan bo'lishi mumkin: har yangilashda holat qayta o'qiladi.
    private func updateAccess() {
        let next: CalendarAccess = switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
        guard next != access else { return }
        // Ruxsat tashqaridan (Tizim sozlamalari) berilgan bo'lsa eski store kalendarlarni bo'sh qaytarishi mumkin.
        if next == .granted { store.reset() }
        access = next
        accessGranted = next == .granted
    }

    func refresh() {
        updateAccess()
        guard accessGranted else { return }
        let all = store.calendars(for: .event)
        sources = all.map { CalendarSource(id: $0.calendarIdentifier, title: $0.title, color: $0.color) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        let known = Set(all.map(\.calendarIdentifier))
        if !excludedIDs.isSubset(of: known) {
            excludedIDs.formIntersection(known)
            UserDefaults.standard.set(Array(excludedIDs), forKey: "excludedCalendars")
        }
        let included = all.filter { !excludedIDs.contains($0.calendarIdentifier) }
        guard !included.isEmpty else { events = []; return }
        let start = Date()
        let end = Calendar.current.date(byAdding: .day, value: 2, to: start) ?? start.addingTimeInterval(172_800)
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: included)
        events = store.events(matching: predicate)
            .filter { !$0.isAllDay && $0.endDate > start }
            .sorted { $0.startDate < $1.startDate }
            .prefix(5)
            .map { event in
                let direct = event.url.flatMap { MeetingLinkFinder.isMeeting($0) ? $0 : nil }
                return CalendarItem(
                    id: "\(event.eventIdentifier ?? UUID().uuidString)|\(event.startDate.timeIntervalSince1970)",
                    title: event.title ?? "Uchrashuv",
                    start: event.startDate, end: event.endDate, url: event.url,
                    meetingURL: direct ?? MeetingLinkFinder.find(in: [event.location, event.notes])
                )
            }
    }
}
