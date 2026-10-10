import XCTest
@testable import TopNest

final class WeatherTests: XCTestCase {
    private func sample(currentCode: Int = 1, precipitation: Double = 0, minutely: [Double?] = [0, 0.4, 0, 0]) -> Data {
        let minutelyValues = minutely.map { $0.map { String($0) } ?? "null" }.joined(separator: ",")
        return Data("""
        {"current":{"time":"2026-10-10T15:15","temperature_2m":21.4,"weather_code":\(currentCode),"apparent_temperature":19.6,"precipitation":\(precipitation)},
         "hourly":{"time":["2026-10-10T15:00","2026-10-10T16:00","2026-10-10T17:00","2026-10-10T18:00","2026-10-10T19:00"],
                   "temperature_2m":[21,20,null,18,17],"weather_code":[1,2,3,61,61],"precipitation_probability":[35,40,50,70,80]},
         "daily":{"time":["2026-10-10","2026-10-11","2026-10-12"],"weather_code":[1,61,null],
                  "temperature_2m_max":[23,19,20],"temperature_2m_min":[12,10,9],"precipitation_probability_max":[35,90,5]},
         "minutely_15":{"time":["2026-10-10T15:15","2026-10-10T15:30","2026-10-10T15:45","2026-10-10T16:00"],"precipitation":[\(minutelyValues)]}}
        """.utf8)
    }

    func testParsesCurrentHourlyAndDaily() throws {
        let info = try WeatherParser.parse(sample(), city: "Toshkent")
        XCTAssertEqual(info.temperature, 21.4)
        XCTAssertEqual(info.apparent, 19.6)
        XCTAssertEqual(info.precipitationChance, 35)
        // null qiymatli soat tashlab ketiladi, keyingi uchtasi olinadi.
        XCTAssertEqual(info.hourly.map(\.label), ["16:00", "18:00", "19:00"])
        // Kodsiz kun tashlab ketiladi.
        XCTAssertEqual(info.daily.map(\.date), ["2026-10-10", "2026-10-11"])
        XCTAssertEqual(info.daily[1].precipitation, 90)
    }

    func testRainSoonOnlyWhenDryNow() throws {
        // 15:15 dan keyingi birinchi bo'lak (15:30) quruq emas: 15 daqiqadan keyin.
        XCTAssertEqual(try WeatherParser.parse(sample(minutely: [0, 0.4, 0, 0]), city: "").rainInMinutes, 15)
        XCTAssertEqual(try WeatherParser.parse(sample(minutely: [0, 0, 0.3, 0]), city: "").rainInMinutes, 30)
        // 30 daqiqadan keyingisi hisoblanmaydi.
        XCTAssertNil(try WeatherParser.parse(sample(minutely: [0, 0, 0, 1]), city: "").rainInMinutes)
        // Hozir yog'ayotgan bo'lsa ogohlantirish kerak emas.
        XCTAssertNil(try WeatherParser.parse(sample(currentCode: 61, minutely: [0, 0.4, 0, 0]), city: "").rainInMinutes)
        XCTAssertNil(try WeatherParser.parse(sample(precipitation: 0.5, minutely: [0, 0.4, 0, 0]), city: "").rainInMinutes)
    }

    func testBrokenOptionalSectionsDoNotDropCurrent() throws {
        let data = Data(#"{"current":{"time":"2026-10-10T15:15","temperature_2m":5,"weather_code":0},"daily":{"time":"bad"}}"#.utf8)
        let info = try WeatherParser.parse(data, city: "")
        XCTAssertEqual(info.temperature, 5)
        XCTAssertTrue(info.daily.isEmpty)
        XCTAssertNil(info.rainInMinutes)
    }

    func testWeekdayLabel() {
        let day = DailyWeather(date: "2026-10-12", code: 0, high: 1, low: 0, precipitation: nil)
        XCTAssertEqual(day.weekday(locale: Locale(identifier: "en_US")), "Mon")
    }

    func testRainActivityRanksAsFlash() {
        XCTAssertEqual(ActivityPolicy.resolve(ActivityInputs(flash: .rain(minutes: 15), musicPlaying: true)), .rain(minutes: 15))
    }
}
