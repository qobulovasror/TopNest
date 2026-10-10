import XCTest
@testable import TopNest

final class CalculatorTests: XCTestCase {
    private func value(_ text: String) -> Double? { try? Calculator.evaluate(text).get() }

    func testPrecedenceAndParentheses() {
        XCTAssertEqual(value("2 + 3 * 4"), 14)
        XCTAssertEqual(value("(2 + 3) × 4"), 20)
        XCTAssertEqual(value("10 ÷ 4"), 2.5)
        XCTAssertEqual(value("2^3^2"), 512)
        XCTAssertEqual(value("-2^2"), -4)
        XCTAssertEqual(value("2^-1"), 0.5)
        XCTAssertEqual(value("−(3 − 5)"), 2)
        XCTAssertEqual(value("1,5 + 1.5"), 3)
        XCTAssertEqual(value(".5 * 4"), 2)
        XCTAssertEqual(value("2 * pi"), 2 * .pi)
    }

    func testThousandsSeparatorsAndScientific() {
        XCTAssertEqual(value("1,000"), 1000)
        XCTAssertEqual(value("1,234 + 1"), 1235)
        XCTAssertEqual(value("1,234,567.5"), 1_234_567.5)
        XCTAssertEqual(value("1.234.567,5"), 1_234_567.5)
        XCTAssertEqual(value("0,125"), 0.125)
        XCTAssertEqual(value("12,5"), 12.5)
        XCTAssertEqual(value("1e20"), 1e20)
        XCTAssertEqual(value("2.5E-3"), 0.0025)
        XCTAssertEqual(value("5 — 2"), 3)
        XCTAssertEqual(value(Calculator.plain(1e20)), 1e20)
        XCTAssertEqual(Calculator.plain(0.1 + 0.2), "0.3")
        XCTAssertEqual(Calculator.evaluate("1,23,4"), .failure(.invalid))
        XCTAssertEqual(Calculator.evaluate("(-1)^0.5"), .failure(.undefined))
    }

    func testPercent() {
        XCTAssertEqual(value("10%"), 0.1)
        XCTAssertEqual(value("200 + 10%"), 220)
        XCTAssertEqual(value("200 - 25%"), 150)
        XCTAssertEqual(value("50% * 80"), 40)
    }

    func testErrorsDoNotCrash() {
        XCTAssertEqual(Calculator.evaluate(""), .failure(.empty))
        XCTAssertEqual(Calculator.evaluate("1 / 0"), .failure(.divisionByZero))
        XCTAssertEqual(Calculator.evaluate("10^400"), .failure(.overflow))
        for bad in ["2 +", "(1 + 2", "1 + 2)", "abc", "1..2", "1,2,3", "*3", ".", "()"] {
            XCTAssertEqual(Calculator.evaluate(bad), .failure(.invalid), bad)
        }
        XCTAssertEqual(Calculator.evaluate(String(repeating: "(", count: 100) + "1" + String(repeating: ")", count: 100)), .failure(.invalid))
        XCTAssertEqual(Calculator.evaluate(String(repeating: "1+", count: 200) + "1"), .failure(.invalid))
    }

    func testExpressionDetectionAndFormat() {
        XCTAssertTrue(Calculator.looksLikeExpression("12 * (3 + 4)"))
        XCTAssertFalse(Calculator.looksLikeExpression("hello world"))
        XCTAssertFalse(Calculator.looksLikeExpression("+ -"))
        let en = Locale(identifier: "en_US")
        XCTAssertEqual(Calculator.format(1234.5, locale: en), "1,234.5")
        XCTAssertEqual(Calculator.format(1234.5, locale: en, grouping: false), "1234.5")
        XCTAssertEqual(Calculator.format(0.1 + 0.2, locale: en), "0.3")
    }

    @MainActor
    func testHistoryKeepsLastThreeUniqueEntries() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "calc-\(UUID().uuidString)"))
        let store = CalculatorStore(defaults: defaults)
        for text in ["1+1", "2+2", "3+3", "1+1", "4+4"] {
            store.input = text
            store.commit()
        }
        XCTAssertEqual(store.history.map(\.expression), ["4+4", "1+1", "3+3"])
        store.input = "1/0"
        XCTAssertNil(store.commit())
        XCTAssertEqual(CalculatorStore(defaults: defaults).history.count, 3)
    }
}
