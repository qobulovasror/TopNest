import Foundation

// Kalkulyator ifodasi: rekursiv tushish parseri. NSExpression ishlatilmaydi — noto'g'ri ifodada ObjC exception tashlaydi.
// Qo'llanadi: + − × ÷ * / ^ %, qavslar, unar minus, o'nlik nuqta yoki vergul, pi/π.
// "200 + 10%" kalkulyatordagidek 220 beradi; alohida "10%" — 0,1.
enum Calculator {
    enum Failure: Error, Equatable {
        case empty, invalid, divisionByZero, overflow, undefined
    }

    static let maxLength = 300
    private static let maxDepth = 64

    static func evaluate(_ text: String) -> Result<Double, Failure> {
        let source = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else { return .failure(.empty) }
        guard source.count <= maxLength else { return .failure(.invalid) }
        var parser = Parser(Array(source.lowercased()))
        do {
            let value = try parser.parse()
            guard !value.isNaN else { return .failure(.undefined) }
            guard value.isFinite else { return .failure(.overflow) }
            return .success(value == 0 ? 0 : value)
        } catch let failure as Failure {
            return .failure(failure)
        } catch {
            return .failure(.invalid)
        }
    }

    // Raqam va amallardan iborat matnmi (tarjima/kalkulyator maydonini ajratish uchun).
    static func looksLikeExpression(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains(where: \.isNumber) || trimmed.contains("π") else { return false }
        let allowed = Set("0123456789.,+-−–—*/×÷^%() πpie")
        return trimmed.lowercased().allSatisfy { allowed.contains($0) }
    }

    // Nusxa: istalgan joyga qo'yiladigan va parserga qaytadigan ko'rinish ("1234.5", "1e+20").
    static func plain(_ value: Double) -> String {
        if abs(value) >= 1e15 || (abs(value) < 1e-10 && value != 0) { return String(value) }
        return format(value, locale: Locale(identifier: "en_US_POSIX"), grouping: false)
    }

    // Ekranda: ilova tili bo'yicha guruhlangan, 10 tagacha kasr raqam.
    static func format(_ value: Double, locale: Locale = .current, grouping: Bool = true) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = grouping
        formatter.maximumFractionDigits = 10
        if abs(value) >= 1e15 || (abs(value) < 1e-10 && value != 0) {
            formatter.numberStyle = .scientific
            formatter.maximumFractionDigits = 8
        }
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private struct Parser {
        let chars: [Character]
        var index = 0
        var depth = 0

        init(_ chars: [Character]) { self.chars = chars }

        mutating func parse() throws -> Double {
            let value = try expression()
            skipSpaces()
            guard index == chars.count else { throw Failure.invalid }
            return value
        }

        private mutating func skipSpaces() {
            while index < chars.count, chars[index].isWhitespace { index += 1 }
        }

        private mutating func peek() -> Character? {
            skipSpaces()
            return index < chars.count ? chars[index] : nil
        }

        private mutating func expression() throws -> Double {
            var value = try term().value
            while let op = peek(), "+-−–—".contains(op) {
                index += 1
                let right = try term()
                // Foiz qo'shish/ayirish chap qiymatga nisbatan: 200 + 10% = 220.
                let amount = right.percent ? value * right.value : right.value
                value = op == "+" ? value + amount : value - amount
            }
            return value
        }

        private mutating func term() throws -> (value: Double, percent: Bool) {
            var result = try unary()
            while let op = peek(), "*/×÷".contains(op) {
                index += 1
                let right = try unary().value
                if op == "/" || op == "÷" {
                    guard right != 0 else { throw Failure.divisionByZero }
                    result = (result.value / right, false)
                } else {
                    result = (result.value * right, false)
                }
            }
            return result
        }

        // Unar minus darajadan past: -2^2 = -4.
        private mutating func unary() throws -> (value: Double, percent: Bool) {
            if let op = peek(), "+-−–—".contains(op) {
                index += 1
                let inner = try unary()
                return (op == "+" ? inner.value : -inner.value, inner.percent)
            }
            return try power()
        }

        // Daraja o'ngdan bog'lanadi: 2^3^2 = 2^9; ko'rsatkich manfiy bo'lishi mumkin: 2^-1.
        private mutating func power() throws -> (value: Double, percent: Bool) {
            let base = try postfix()
            if peek() == "^" {
                index += 1
                let exponent = try unary().value
                return (pow(base.value, exponent), false)
            }
            return base
        }

        private mutating func postfix() throws -> (value: Double, percent: Bool) {
            var result = (value: try primary(), percent: false)
            while peek() == "%" {
                index += 1
                result = (result.value / 100, true)
            }
            return result
        }

        private mutating func primary() throws -> Double {
            guard let char = peek() else { throw Failure.invalid }
            if char == "(" {
                depth += 1
                guard depth <= Calculator.maxDepth else { throw Failure.invalid }
                index += 1
                let value = try expression()
                guard peek() == ")" else { throw Failure.invalid }
                index += 1
                depth -= 1
                return value
            }
            if char == "π" { index += 1; return .pi }
            if char == "p", index + 1 < chars.count, chars[index + 1] == "i" { index += 2; return .pi }
            return try number()
        }

        // Ajratgichlar: ikkala belgi bo'lsa oxirgisi o'nlik; bitta belgi takrorlansa — ming ajratgichi;
        // yagona vergul va undan keyin aniq 3 raqam (butun qism 0 bo'lmasa) — ming ajratgichi ("1,000" = 1000).
        private mutating func number() throws -> Double {
            var raw = ""
            while index < chars.count, (chars[index].isASCII && chars[index].isNumber) || chars[index] == "." || chars[index] == "," {
                raw.append(chars[index])
                index += 1
            }
            guard let normalized = Self.normalize(raw), var value = Double(normalized) else { throw Failure.invalid }
            // Ilmiy ko'rinish: 1e20, 2.5E-3.
            if index < chars.count, chars[index] == "e" {
                var cursor = index + 1
                var exponent = ""
                if cursor < chars.count, "+-".contains(chars[cursor]) { exponent.append(chars[cursor]); cursor += 1 }
                while cursor < chars.count, chars[cursor].isASCII && chars[cursor].isNumber { exponent.append(chars[cursor]); cursor += 1 }
                guard let power = Double(exponent) else { throw Failure.invalid }
                value *= pow(10, power)
                index = cursor
            }
            return value
        }

        static func normalize(_ raw: String) -> String? {
            guard raw.contains(where: \.isNumber) else { return nil }
            let separators = raw.filter { $0 == "." || $0 == "," }
            guard !separators.isEmpty else { return raw }
            func grouped(_ text: String, by separator: Character) -> String? {
                let parts = text.split(separator: separator, omittingEmptySubsequences: false)
                guard let first = parts.first, (1...3).contains(first.count),
                      parts.dropFirst().allSatisfy({ $0.count == 3 }) else { return nil }
                return parts.joined()
            }
            let decimal: Character
            if Set(separators).count == 2 {
                decimal = separators.last!
                guard separators.filter({ $0 == decimal }).count == 1 else { return nil }
            } else if separators.count > 1 {
                return grouped(raw, by: separators.first!)
            } else {
                let parts = raw.split(separator: separators.first!, omittingEmptySubsequences: false)
                if separators.first == ",", parts[1].count == 3, !parts[0].isEmpty, parts[0] != "0" {
                    return grouped(raw, by: ",")
                }
                decimal = separators.first!
            }
            let group: Character = decimal == "." ? "," : "."
            let pieces = raw.split(separator: decimal, omittingEmptySubsequences: false)
            guard pieces.count == 2 else { return nil }
            let integer = pieces[0].contains(group) ? grouped(String(pieces[0]), by: group) : String(pieces[0])
            guard let integer, !(integer.isEmpty && pieces[1].isEmpty) else { return nil }
            return integer + "." + pieces[1]
        }
    }
}

// Oxirgi hisoblar: ifoda va natija, diskda kichik ro'yxat.
@MainActor
final class CalculatorStore: ObservableObject {
    struct Entry: Codable, Equatable, Identifiable {
        var id = UUID()
        let expression: String
        let result: Double
    }

    static let historyLimit = 3

    @Published var input = ""
    @Published private(set) var history: [Entry] = []
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: "calculatorHistory"),
           let saved = try? JSONDecoder().decode([Entry].self, from: data) {
            history = Array(saved.prefix(Self.historyLimit))
        }
    }

    var result: Result<Double, Calculator.Failure> { Calculator.evaluate(input) }

    var value: Double? { try? result.get() }

    // Natija tarixga yoziladi; qaytgan matnni chaqiruvchi clipboard'ga nusxalaydi.
    @discardableResult
    func commit() -> String? {
        guard let value else { return nil }
        let expression = input.trimmingCharacters(in: .whitespacesAndNewlines)
        history.removeAll { $0.expression == expression }
        history.insert(Entry(expression: expression, result: value), at: 0)
        history = Array(history.prefix(Self.historyLimit))
        if let data = try? JSONEncoder().encode(history) { defaults.set(data, forKey: "calculatorHistory") }
        return Calculator.plain(value)
    }

    func clearHistory() {
        history = []
        defaults.removeObject(forKey: "calculatorHistory")
    }
}
