import Darwin
import Foundation

// Istalgan sayt/API yoki dastur chiqishidan qiymat oladigan widget ta'rifi.
// JSON fayl sifatida import/eksport qilinadi, shuning uchun maydonlar barqaror.
struct CustomWidgetSpec: Codable, Equatable {
    enum Source: String, Codable, CaseIterable, Identifiable {
        case url, command
        var id: Self { self }
        var title: String { self == .url ? "URL (sayt yoki API)" : "Shell buyrug‘i" }
    }

    enum Display: String, Codable, CaseIterable, Identifiable {
        case text, number, gauge
        var id: Self { self }
        var title: String {
            switch self {
            case .text: "Matn"
            case .number: "Katta raqam"
            case .gauge: "Halqa (qiymat / maksimum)"
            }
        }
    }

    var title: String
    var icon: String = "puzzlepiece.extension"
    var source: Source = .url
    var target: String = ""
    var jsonPath: String = ""
    var prefix: String = ""
    var suffix: String = ""
    var refreshSeconds: Int = 300
    var display: Display = .text
    var gaugeMax: Double = 100

    init(title: String) { self.title = title }

    // Yetishmagan kalitlar standart qiymat oladi: eski eksport va qo'lda yozilgan fayllar ham o'qiladi.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decode(String.self, forKey: .title)
        icon = try c.decodeIfPresent(String.self, forKey: .icon) ?? icon
        source = (try? c.decodeIfPresent(Source.self, forKey: .source)) ?? source
        target = try c.decodeIfPresent(String.self, forKey: .target) ?? target
        jsonPath = try c.decodeIfPresent(String.self, forKey: .jsonPath) ?? jsonPath
        prefix = try c.decodeIfPresent(String.self, forKey: .prefix) ?? prefix
        suffix = try c.decodeIfPresent(String.self, forKey: .suffix) ?? suffix
        refreshSeconds = try c.decodeIfPresent(Int.self, forKey: .refreshSeconds) ?? refreshSeconds
        display = (try? c.decodeIfPresent(Display.self, forKey: .display)) ?? display
        gaugeMax = try c.decodeIfPresent(Double.self, forKey: .gaugeMax) ?? gaugeMax
    }

    // Import qilingan qiymatlarni xavfsiz chegaralarga keltiradi; manzil bo'sh bo'lsa nil.
    func normalized() -> CustomWidgetSpec? {
        var spec = self
        spec.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        spec.target = target.trimmingCharacters(in: .whitespacesAndNewlines)
        spec.refreshSeconds = min(86_400, max(10, refreshSeconds))
        guard !spec.title.isEmpty, !spec.target.isEmpty else { return nil }
        return spec
    }
}

enum JSONPath {
    // "data.items[0].price" ko'rinishidagi oddiy yo'l. Bo'sh yo'l — butun qiymat.
    static func extract(_ path: String, from object: Any) -> Any? {
        var current: Any? = object
        for token in tokens(path) {
            switch token {
            case .key(let key): current = (current as? [String: Any])?[key]
            case .index(let index):
                guard let array = current as? [Any], array.indices.contains(index) else { return nil }
                current = array[index]
            }
        }
        return current
    }

    private enum Token { case key(String), index(Int) }

    private static func tokens(_ path: String) -> [Token] {
        var result: [Token] = []
        for part in path.split(separator: ".") {
            var name = Substring(part)
            var indexes: [Int] = []
            while let open = name.lastIndex(of: "["), name.hasSuffix("]"),
                  let value = Int(name[name.index(after: open)..<name.index(before: name.endIndex)]) {
                indexes.insert(value, at: 0)
                name = name[..<open]
            }
            if !name.isEmpty { result.append(.key(String(name))) }
            result.append(contentsOf: indexes.map(Token.index))
        }
        return result
    }

    static func describe(_ value: Any?) -> String? {
        switch value {
        case nil, is NSNull: return nil
        case let string as String: return string
        case let number as NSNumber: return number.stringValue
        case let other?:
            guard JSONSerialization.isValidJSONObject(other),
                  let data = try? JSONSerialization.data(withJSONObject: other, options: [.sortedKeys]) else { return "\(other)" }
            return String(data: data, encoding: .utf8)
        }
    }
}

@MainActor
final class CustomWidgetRunner: ObservableObject {
    @Published private(set) var value: String?
    @Published private(set) var error: String?
    @Published private(set) var updatedAt: Date?
    private var startedAt: Date?
    private var loadingSpec: CustomWidgetSpec?
    private var lastSpec: CustomWidgetSpec?
    private var generation = 0

    var numericValue: Double? {
        guard var text = value?.trimmingCharacters(in: .whitespaces) else { return nil }
        // "1,234.5" — minglik ajratgich; "12,5" — o'nlik vergul.
        text = text.contains(".") ? text.replacingOccurrences(of: ",", with: "") : text.replacingOccurrences(of: ",", with: ".")
        return Double(text)
    }

    // Oraliq so'rov boshlangan vaqtdan hisoblanadi, aks holda yangilanish ikki barobar kechikadi.
    func refreshIfNeeded(_ spec: CustomWidgetSpec) {
        if spec == lastSpec, let startedAt, Date().timeIntervalSince(startedAt) < TimeInterval(max(10, spec.refreshSeconds)) - 1 { return }
        refresh(spec)
    }

    func refresh(_ spec: CustomWidgetSpec) {
        guard loadingSpec != spec else { return }
        generation += 1
        let current = generation
        if spec != lastSpec { value = nil; error = nil }
        lastSpec = spec
        loadingSpec = spec
        startedAt = Date()
        Task { [weak self] in
            let result = await Self.load(spec)
            // Shu orada ta'rif o'zgargan bo'lsa eski natija yozilmaydi.
            guard let self, current == self.generation else { return }
            self.loadingSpec = nil
            self.updatedAt = Date()
            switch result {
            case .success(let text): self.value = text; self.error = nil
            case .failure(let failure): self.error = failure.message
            }
        }
    }

    struct Failure: Error { let message: String }

    nonisolated private static func load(_ spec: CustomWidgetSpec) async -> Result<String, Failure> {
        let raw: Data
        switch spec.source {
        case .url:
            // Ilovada ATS istisnosi yo'q: http so'rovlari tizim tomonidan bloklanadi.
            guard let url = URL(string: spec.target.trimmingCharacters(in: .whitespacesAndNewlines)),
                  url.scheme?.lowercased() == "https", url.host != nil else { return .failure(Failure(message: "Faqat https:// manzil qo‘llanadi")) }
            var request = URLRequest(url: url, timeoutInterval: 10)
            request.setValue("TopNest", forHTTPHeaderField: "User-Agent")
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    return .failure(Failure(message: "Server xatosi (\((response as? HTTPURLResponse)?.statusCode ?? 0))"))
                }
                guard data.count <= 2_000_000 else { return .failure(Failure(message: "Javob juda katta")) }
                raw = data
            } catch let error as URLError {
                switch error.code {
                case .timedOut: return .failure(Failure(message: "Vaqt tugadi"))
                case .notConnectedToInternet, .networkConnectionLost: return .failure(Failure(message: "Internet yo‘q"))
                case .cannotFindHost, .dnsLookupFailed: return .failure(Failure(message: "Sayt topilmadi"))
                default: return .failure(Failure(message: "Tarmoq xatosi"))
                }
            } catch {
                return .failure(Failure(message: "Tarmoq xatosi"))
            }
        case .command:
            guard let output = await runCommand(spec.target) else {
                return .failure(Failure(message: "Buyruq bajarilmadi"))
            }
            raw = output
        }
        let text: String?
        if spec.jsonPath.trimmingCharacters(in: .whitespaces).isEmpty {
            text = String(data: raw, encoding: .utf8)?.split(whereSeparator: \.isNewline).first.map(String.init)
        } else {
            guard let object = try? JSONSerialization.jsonObject(with: raw, options: [.fragmentsAllowed]) else {
                return .failure(Failure(message: "JSON emas"))
            }
            text = JSONPath.describe(JSONPath.extract(spec.jsonPath, from: object))
        }
        guard let text, !text.isEmpty else { return .failure(Failure(message: "Qiymat topilmadi")) }
        return .success(String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500)))
    }

    nonisolated private static func runCommand(_ command: String) async -> Data? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async { continuation.resume(returning: runCommandBlocking(command)) }
        }
    }

    // Login shell'siz, kengaytirilgan PATH bilan. 10 s dan keyin SIGTERM, yana 1 s dan keyin SIGKILL.
    // Chiqish readabilityHandler orqali o'qiladi: fon jarayon pipe'ni ushlab qolsa ham thread bloklanmaydi.
    nonisolated private static func runCommandBlocking(_ command: String) -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = ["\(home)/.local/bin", "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"].joined(separator: ":")
        process.environment = ProcessInfo.processInfo.environment.merging(["PATH": path]) { _, new in new }
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        let buffer = LockedData()
        let finishedReading = DispatchSemaphore(value: 0)
        let reader = output.fileHandleForReading
        reader.readabilityHandler = { handle in
            let chunk = handle.availableData
            if chunk.isEmpty {
                handle.readabilityHandler = nil
                finishedReading.signal()
            } else {
                buffer.append(chunk)
            }
        }
        let exited = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in exited.signal() }
        do { try process.run() } catch {
            reader.readabilityHandler = nil
            return nil
        }
        var timedOut = false
        if exited.wait(timeout: .now() + 10) == .timedOut {
            timedOut = true
            killDescendants(of: process.processIdentifier)
            process.terminate()
            if exited.wait(timeout: .now() + 1) == .timedOut {
                kill(process.processIdentifier, SIGKILL)
                _ = exited.wait(timeout: .now() + 1)
            }
        }
        _ = finishedReading.wait(timeout: .now() + 0.2)
        reader.readabilityHandler = nil
        try? reader.close()
        guard !timedOut, !process.isRunning, process.terminationStatus == 0 else { return nil }
        return buffer.data
    }

    // Vaqt tugaganda shell bilan birga uning bola jarayonlari ham to'xtatiladi (yetim qolmasin).
    nonisolated private static func killDescendants(of pid: pid_t) {
        var children = [pid_t](repeating: 0, count: 64)
        let count = proc_listchildpids(pid, &children, Int32(children.count * MemoryLayout<pid_t>.size))
        guard count > 0 else { return }
        for child in children.prefix(Int(count)) where child > 0 {
            killDescendants(of: child)
            kill(child, SIGKILL)
        }
    }

    private final class LockedData: @unchecked Sendable {
        private let lock = NSLock()
        private var storage = Data()
        func append(_ chunk: Data) { lock.withLock { if storage.count < 262_144 { storage.append(chunk) } } }
        var data: Data { lock.withLock { storage } }
    }
}

@MainActor
final class CustomWidgetRunners {
    private var runners: [UUID: CustomWidgetRunner] = [:]

    func prune(keeping ids: Set<UUID>) {
        runners = runners.filter { ids.contains($0.key) }
    }

    func runner(for id: UUID) -> CustomWidgetRunner {
        if let runner = runners[id] { return runner }
        let runner = CustomWidgetRunner()
        runners[id] = runner
        return runner
    }
}
