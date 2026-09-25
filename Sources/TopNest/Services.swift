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
    let observedAt: Date

    var progress: Double {
        guard duration > 0 else { return 0 }
        let elapsed = playing ? Date().timeIntervalSince(observedAt) : 0
        return min(1, max(0, (position + elapsed) / duration))
    }
}

enum MusicService {
    static func current() -> TrackInfo? {
        let players: [(String, String)] = [
            ("com.spotify.client", "Spotify"),
            ("com.apple.Music", "Music")
        ]
        var found: [TrackInfo] = []
        for (bundleID, name) in players where !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty {
            let script: String
            if name == "Spotify" {
                script = "set coverURL to \"\"\ntry\ntell application id \"com.spotify.client\" to set coverURL to artwork url of current track as text\nend try\ntell application id \"com.spotify.client\" to return (player state as text) & \"|||\" & (name of current track) & \"|||\" & (artist of current track) & \"|||\" & (player position as text) & \"|||\" & (duration of current track as text) & \"|||\" & coverURL"
            } else {
                script = "tell application id \"com.apple.Music\" to return (player state as text) & \"|||\" & (name of current track) & \"|||\" & (artist of current track) & \"|||\" & (player position as text) & \"|||\" & (duration of current track as text)"
            }
            var error: NSDictionary?
            guard let output = NSAppleScript(source: script)?.executeAndReturnError(&error).stringValue else { continue }
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
                observedAt: Date()
            ))
        }
        return found.first(where: { $0.playing }) ?? found.first
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

struct ClipItem: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let capturedAt: Date
}

@MainActor
final class ClipboardService: ObservableObject {
    @Published private(set) var items: [ClipItem] = []
    private var lastChange = NSPasteboard.general.changeCount

    func check(enabled: Bool) {
        let board = NSPasteboard.general
        guard board.changeCount != lastChange else { return }
        lastChange = board.changeCount
        guard enabled, let value = board.string(forType: .string), !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let excluded = ["com.1password.1password", "com.bitwarden.desktop", "com.agilebits.onepassword7"]
        if let source = NSWorkspace.shared.frontmostApplication?.bundleIdentifier, excluded.contains(source) { return }
        guard items.first?.text != value else { return }
        items.insert(ClipItem(text: value, capturedAt: Date()), at: 0)
        items = Array(items.prefix(25))
    }

    func copy(_ item: ClipItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.text, forType: .string)
        lastChange = NSPasteboard.general.changeCount
    }

    func clear() { items.removeAll() }

    func remove(_ item: ClipItem) { items.removeAll { $0.id == item.id } }
}

struct CalendarItem: Identifiable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let url: URL?
}

@MainActor
final class CalendarService: ObservableObject {
    @Published private(set) var events: [CalendarItem] = []
    @Published private(set) var accessGranted = false
    @Published var errorMessage: String?
    private let store = EKEventStore()

    init() {
        accessGranted = EKEventStore.authorizationStatus(for: .event) == .fullAccess
        if accessGranted { refresh() }
    }

    func requestAccess() {
        Task {
            do {
                accessGranted = try await store.requestFullAccessToEvents()
                if accessGranted { refresh() }
                else { errorMessage = "Kalendar ruxsati berilmadi." }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func refresh() {
        guard accessGranted else { return }
        let start = Date()
        let end = Calendar.current.date(byAdding: .day, value: 2, to: start) ?? start.addingTimeInterval(172_800)
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        events = store.events(matching: predicate)
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }
            .prefix(5)
            .map { CalendarItem(id: $0.eventIdentifier ?? UUID().uuidString, title: $0.title ?? "Uchrashuv", start: $0.startDate, end: $0.endDate, url: $0.url) }
    }
}

struct WeatherInfo {
    let temperature: Double
    let code: Int
    let city: String
    let updatedAt: Date
    var symbol: String {
        switch code {
        case 0: "sun.max.fill"
        case 1...3: "cloud.sun.fill"
        case 45...48: "cloud.fog.fill"
        case 51...67, 80...82: "cloud.rain.fill"
        case 71...77, 85...86: "cloud.snow.fill"
        case 95...99: "cloud.bolt.rain.fill"
        default: "cloud.fill"
        }
    }
}

@MainActor
final class WeatherService: ObservableObject {
    @Published private(set) var weather: WeatherInfo?
    @Published var errorMessage: String?
    @Published var city = UserDefaults.standard.string(forKey: "weatherCity") ?? ""
    private var cachedLocation: Location?
    private var cachedCity: String?
    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 8
        return URLSession(configuration: config)
    }()

    func refresh(saveCity: Bool = false) async {
        let name = (saveCity ? city : (UserDefaults.standard.string(forKey: "weatherCity") ?? ""))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            if saveCity {
                weather = nil
                errorMessage = nil
                cachedLocation = nil
                cachedCity = nil
                UserDefaults.standard.removeObject(forKey: "weatherCity")
            }
            return
        }
        do {
            let location: Location
            if cachedCity == name, let cachedLocation {
                location = cachedLocation
            } else {
                var geo = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
                geo.queryItems = [URLQueryItem(name: "name", value: name), URLQueryItem(name: "count", value: "1")]
                let (geoData, geoResponse) = try await session.data(from: geo.url!)
                guard (geoResponse as? HTTPURLResponse)?.statusCode == 200 else { throw WeatherError.network }
                let locations = try JSONDecoder().decode(GeocodingResponse.self, from: geoData)
                guard let match = locations.results?.first else { throw WeatherError.cityNotFound }
                location = match
            }
            var forecast = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
            forecast.queryItems = [
                URLQueryItem(name: "latitude", value: String(location.latitude)),
                URLQueryItem(name: "longitude", value: String(location.longitude)),
                URLQueryItem(name: "current", value: "temperature_2m,weather_code"),
                URLQueryItem(name: "timezone", value: "auto")
            ]
            let (forecastData, forecastResponse) = try await session.data(from: forecast.url!)
            guard (forecastResponse as? HTTPURLResponse)?.statusCode == 200 else { throw WeatherError.network }
            let response = try JSONDecoder().decode(ForecastResponse.self, from: forecastData)
            guard name == (saveCity ? city : (UserDefaults.standard.string(forKey: "weatherCity") ?? "")).trimmingCharacters(in: .whitespacesAndNewlines) else { return }
            weather = WeatherInfo(temperature: response.current.temperature_2m, code: response.current.weather_code, city: location.name, updatedAt: Date())
            cachedCity = name
            cachedLocation = location
            if saveCity { UserDefaults.standard.set(name, forKey: "weatherCity") }
            errorMessage = nil
        } catch {
            if saveCity || weather == nil { errorMessage = error.localizedDescription }
        }
    }

    private struct GeocodingResponse: Decodable { let results: [Location]? }
    private struct Location: Decodable { let name: String; let latitude: Double; let longitude: Double }
    private struct ForecastResponse: Decodable { let current: Current }
    private struct Current: Decodable { let temperature_2m: Double; let weather_code: Int }
    private enum WeatherError: LocalizedError {
        case cityNotFound, network
        var errorDescription: String? {
            switch self {
            case .cityNotFound: "Shahar topilmadi."
            case .network: "Ob-havo xizmati javob bermadi."
            }
        }
    }
}
