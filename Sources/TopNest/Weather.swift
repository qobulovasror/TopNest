import AppKit
import CoreLocation
import Foundation

struct HourlyWeather: Identifiable {
    let time: String
    let temperature: Double
    let code: Int
    var id: String { time }
    var label: String { String(time.suffix(5)) }
    var symbol: String { WeatherInfo.symbol(for: code) }
}

struct DailyWeather: Identifiable {
    let date: String
    let code: Int
    let high: Double
    let low: Double
    let precipitation: Int?
    var id: String { date }
    var symbol: String { WeatherInfo.symbol(for: code) }

    // "2026-10-12" → qisqa hafta kuni ("Du").
    func weekday(locale: Locale) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let parts = date.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, let day = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) else { return date }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter.string(from: day)
    }
}

enum TemperatureUnit: String, CaseIterable, Identifiable {
    case celsius, fahrenheit
    var id: Self { self }
    var title: String { self == .celsius ? "°C" : "°F" }
}

struct WeatherInfo {
    let temperature: Double
    let code: Int
    let city: String
    let updatedAt: Date
    let hourly: [HourlyWeather]
    var apparent: Double? = nil
    var precipitationChance: Int? = nil
    var daily: [DailyWeather] = []
    // Keyingi 30 daqiqada yog'ingarchilik boshlanadigan bo'lsa — necha daqiqadan keyin (hozir yog'mayotgan bo'lsa).
    var rainInMinutes: Int? = nil
    var symbol: String { Self.symbol(for: code) }

    static func symbol(for code: Int) -> String {
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

    static func isPrecipitation(_ code: Int) -> Bool { (51...99).contains(code) }
}

// Open-Meteo javobini ajratish: tarmoqdan mustaqil, test qilinadi.
enum WeatherParser {
    struct Forecast: Decodable {
        let current: Current
        let hourly: Hourly?
        let daily: Daily?
        let minutely15: Minutely?

        enum CodingKeys: String, CodingKey { case current, hourly, daily, minutely15 = "minutely_15" }

        // Qo'shimcha qismlar buzilgan bo'lsa ham joriy ob-havo yangilanadi.
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            current = try container.decode(Current.self, forKey: .current)
            hourly = try? container.decodeIfPresent(Hourly.self, forKey: .hourly)
            daily = try? container.decodeIfPresent(Daily.self, forKey: .daily)
            minutely15 = try? container.decodeIfPresent(Minutely.self, forKey: .minutely15)
        }
    }
    struct Current: Decodable {
        let time: String
        let temperature_2m: Double
        let weather_code: Int
        let apparent_temperature: Double?
        let precipitation: Double?
    }
    struct Hourly: Decodable { let time: [String]; let temperature_2m: [Double?]; let weather_code: [Int?]; let precipitation_probability: [Int?]? }
    struct Daily: Decodable {
        let time: [String]
        let weather_code: [Int?]
        let temperature_2m_max: [Double?]
        let temperature_2m_min: [Double?]
        let precipitation_probability_max: [Int?]?
    }
    struct Minutely: Decodable { let time: [String]; let precipitation: [Double?] }

    static func parse(_ data: Data, city: String, now: Date = Date()) throws -> WeatherInfo {
        let response = try JSONDecoder().decode(Forecast.self, from: data)
        // ISO vaqtlar (joy vaqt zonasida) satr sifatida taqqoslanadi.
        let currentHour = String(response.current.time.prefix(13)) + ":00"
        var hourly: [HourlyWeather] = []
        var chance: Int?
        if let hours = response.hourly {
            for (index, time) in hours.time.enumerated() {
                if time == currentHour { chance = hours.precipitation_probability?[safe: index] ?? nil }
                guard time > currentHour, hourly.count < 3,
                      let temperature = hours.temperature_2m[safe: index] ?? nil, let code = hours.weather_code[safe: index] ?? nil else { continue }
                hourly.append(HourlyWeather(time: time, temperature: temperature, code: code))
            }
        }
        let daily: [DailyWeather] = response.daily.map { days in
            days.time.enumerated().compactMap { index, date in
                guard let code = days.weather_code[safe: index] ?? nil, let high = days.temperature_2m_max[safe: index] ?? nil,
                      let low = days.temperature_2m_min[safe: index] ?? nil else { return nil }
                return DailyWeather(date: date, code: code, high: high, low: low, precipitation: days.precipitation_probability_max?[safe: index] ?? nil)
            }
        } ?? []
        // 15 daqiqalik bo'laklar: hozir quruq, keyingi 30 daqiqada ≥0,1 mm — necha daqiqadan keyin.
        var rain: Int?
        let raining = (response.current.precipitation ?? 0) >= 0.1 || WeatherInfo.isPrecipitation(response.current.weather_code)
        if !raining, let minutes = response.minutely15 {
            let upcoming = zip(minutes.time, minutes.precipitation).filter { $0.0 > response.current.time }.prefix(2)
            if let index = upcoming.firstIndex(where: { ($0.1 ?? 0) >= 0.1 }) {
                rain = (upcoming.distance(from: upcoming.startIndex, to: index) + 1) * 15
            }
        }
        return WeatherInfo(temperature: response.current.temperature_2m, code: response.current.weather_code, city: city,
                           updatedAt: now, hourly: hourly, apparent: response.current.apparent_temperature,
                           precipitationChance: chance, daily: Array(daily.prefix(5)), rainInMinutes: rain)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

// Bir martalik joylashuv (ixtiyoriy). Ruxsat birinchi so'rovda so'raladi.
@MainActor
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuations: [CheckedContinuation<CLLocation?, Never>] = []
    private var batch = 0

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    var denied: Bool { [.denied, .restricted].contains(manager.authorizationStatus) }
    var onAuthorizationChange: ((Bool) -> Void)?

    func current() async -> CLLocation? {
        if denied { return nil }
        // Yaqinda olingan joy qayta so'ralmaydi.
        if let location = manager.location, location.timestamp.timeIntervalSinceNow > -900 { return location }
        return await withCheckedContinuation { continuation in
            continuations.append(continuation)
            guard continuations.count == 1 else { return }
            batch += 1
            let current = batch
            if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() } else { manager.requestLocation() }
            // Ruxsat oynasi e'tiborsiz qolsa yoki javob kelmasa, 20 soniyadan keyin bo'sh natija (faqat shu so'rov uchun).
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(20))
                guard let self, self.batch == current else { return }
                self.finish(nil)
            }
        }
    }

    private func finish(_ location: CLLocation?) {
        batch += 1
        let pending = continuations
        continuations.removeAll()
        pending.forEach { $0.resume(returning: location) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated {
            onAuthorizationChange?(denied)
            guard !continuations.isEmpty else { return }
            switch manager.authorizationStatus {
            case .notDetermined: break
            case .denied, .restricted: finish(nil)
            default: manager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let last = locations.last
        MainActor.assumeIsolated { finish(last) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated { finish(nil) }
    }
}

@MainActor
final class WeatherService: ObservableObject {
    @Published private(set) var weather: WeatherInfo?
    @Published var errorMessage: String?
    @Published var city = UserDefaults.standard.string(forKey: "weatherCity") ?? ""
    @Published var useLocation = UserDefaults.standard.bool(forKey: "weatherUseLocation") {
        didSet {
            UserDefaults.standard.set(useLocation, forKey: "weatherUseLocation")
            Task { await refresh() }
        }
    }
    @Published var unit = TemperatureUnit(rawValue: UserDefaults.standard.string(forKey: "weatherUnit") ?? "") ?? .celsius {
        didSet {
            UserDefaults.standard.set(unit.rawValue, forKey: "weatherUnit")
            Task { await refresh() }
        }
    }
    @Published private(set) var locationDenied = false
    // Oxirgi muvaffaqiyatli joy (namoz vaqtlari shu koordinatadan hisoblanadi).
    @Published private(set) var coordinate: Coordinate?
    struct Coordinate: Equatable { let latitude: Double; let longitude: Double }
    // Yog'ingarchilik yaqinlashganda (soatiga ko'pi bilan bir marta).
    var onRainSoon: ((Int) -> Void)?
    private var rainAnnouncedAt: Date?
    // Har yangilashga raqam: kech kelgan eski javob (boshqa birlik yoki rejim) yangisini bosmaydi.
    private var requestID = 0
    private var cachedLocation: Location?
    private var cachedCity: String?
    private var placeName: (coordinate: CLLocationCoordinate2D, name: String)?
    private lazy var locator: LocationProvider = {
        let provider = LocationProvider()
        provider.onAuthorizationChange = { [weak self] denied in self?.locationDenied = denied }
        return provider
    }()
    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 8
        return URLSession(configuration: config)
    }()

    var configured: Bool {
        useLocation || !(UserDefaults.standard.string(forKey: "weatherCity") ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func openWeatherApp() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Weather.app"))
    }

    func refresh(saveCity: Bool = false) async {
        requestID += 1
        let request = requestID
        do {
            let target: (Location, String)
            if useLocation {
                guard let location = await locator.current() else {
                    locationDenied = locator.denied
                    throw WeatherError.location
                }
                locationDenied = false
                // Koordinatalar ~1 km gacha yaxlitlanib yuboriladi.
                let latitude = (location.coordinate.latitude * 100).rounded() / 100
                let longitude = (location.coordinate.longitude * 100).rounded() / 100
                target = (Location(name: await placeName(for: location), latitude: latitude, longitude: longitude), "")
            } else {
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
                target = (try await geocode(name), name)
            }
            let (location, name) = target
            var forecast = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
            forecast.queryItems = [
                URLQueryItem(name: "latitude", value: String(location.latitude)),
                URLQueryItem(name: "longitude", value: String(location.longitude)),
                URLQueryItem(name: "current", value: "temperature_2m,weather_code,apparent_temperature,precipitation"),
                URLQueryItem(name: "hourly", value: "temperature_2m,weather_code,precipitation_probability"),
                URLQueryItem(name: "forecast_hours", value: "5"),
                URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max"),
                URLQueryItem(name: "forecast_days", value: "5"),
                URLQueryItem(name: "minutely_15", value: "precipitation"),
                URLQueryItem(name: "forecast_minutely_15", value: "4"),
                URLQueryItem(name: "temperature_unit", value: unit.rawValue),
                URLQueryItem(name: "timezone", value: "auto")
            ]
            let (data, response) = try await session.data(from: forecast.url!)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw WeatherError.network }
            // Shu orada yangi so'rov boshlangan yoki shahar o'zgargan bo'lsa eski javob qo'llanmaydi.
            guard request == requestID else { return }
            if !useLocation {
                guard name == (saveCity ? city : (UserDefaults.standard.string(forKey: "weatherCity") ?? "")).trimmingCharacters(in: .whitespacesAndNewlines) else { return }
            }
            let info = try WeatherParser.parse(data, city: location.name)
            weather = info
            coordinate = Coordinate(latitude: location.latitude, longitude: location.longitude)
            if !useLocation {
                cachedCity = name
                cachedLocation = location
                if saveCity { UserDefaults.standard.set(name, forKey: "weatherCity") }
            }
            errorMessage = nil
            announceRain(info.rainInMinutes)
        } catch {
            guard request == requestID else { return }
            if saveCity || useLocation || weather == nil { errorMessage = error.localizedDescription }
        }
    }

    private func announceRain(_ minutes: Int?) {
        guard let minutes else { return }
        if let rainAnnouncedAt, Date().timeIntervalSince(rainAnnouncedAt) < 3600 { return }
        rainAnnouncedAt = Date()
        onRainSoon?(minutes)
    }

    private func geocode(_ name: String) async throws -> Location {
        if cachedCity == name, let cachedLocation { return cachedLocation }
        var geo = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        geo.queryItems = [URLQueryItem(name: "name", value: name), URLQueryItem(name: "count", value: "1")]
        let (geoData, geoResponse) = try await session.data(from: geo.url!)
        guard (geoResponse as? HTTPURLResponse)?.statusCode == 200 else { throw WeatherError.network }
        let locations = try JSONDecoder().decode(GeocodingResponse.self, from: geoData)
        guard let match = locations.results?.first else { throw WeatherError.cityNotFound }
        return match
    }

    // Joy nomi (shahar) bir marta aniqlanadi; 5 km dan ko'p siljilsa qayta so'raladi.
    private func placeName(for location: CLLocation) async -> String {
        if let placeName, CLLocation(latitude: placeName.coordinate.latitude, longitude: placeName.coordinate.longitude).distance(from: location) < 5000 {
            return placeName.name
        }
        // Muvaffaqiyatsiz natija keshlanmaydi: keyingi safar qayta uriniladi.
        guard let name = (try? await CLGeocoder().reverseGeocodeLocation(location))?.first?.locality else { return L10n.tr("Joriy joy") }
        placeName = (location.coordinate, name)
        return name
    }

    private struct GeocodingResponse: Decodable { let results: [Location]? }
    private struct Location: Decodable { let name: String; let latitude: Double; let longitude: Double }
    private enum WeatherError: LocalizedError {
        case cityNotFound, network, location
        var errorDescription: String? {
            switch self {
            case .cityNotFound: L10n.tr("Shahar topilmadi.")
            case .network: L10n.tr("Ob-havo xizmati javob bermadi.")
            case .location: L10n.tr("Joylashuvni aniqlab bo‘lmadi.")
            }
        }
    }
}
