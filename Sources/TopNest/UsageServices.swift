import Foundation

struct UsageWindow: Equatable {
    let usedPercent: Double
    let resetAt: Date?
    var remainingPercent: Int { max(0, min(100, Int((100 - usedPercent).rounded()))) }

    func hasReset(at now: Date = Date()) -> Bool {
        guard let resetAt else { return false }
        return resetAt <= now
    }
}

struct UsageSnapshot: Equatable {
    static let staleAfter: TimeInterval = 900

    let primary: UsageWindow?
    let secondary: UsageWindow?
    let updatedAt: Date

    func isStale(at now: Date = Date()) -> Bool { now.timeIntervalSince(updatedAt) > Self.staleAfter }

    // Reset vaqti kelmagan oyna foizi eskirgan bo'lsa ham ishonchli: sarf faqat oshadi.
    func lowestRemaining(at now: Date = Date()) -> Int? {
        [primary, secondary].compactMap { window -> Int? in
            guard let window, !window.hasReset(at: now) else { return nil }
            if window.resetAt == nil && isStale(at: now) { return nil }
            return window.remainingPercent
        }.min()
    }
}

enum CodexUsageService {
    static func fetch() -> Result<UsageSnapshot, Error> {
        guard let executable = executableURL() else { return .failure(UsageError.notInstalled) }
        let process = Process()
        process.executableURL = executable
        process.arguments = ["app-server", "--stdio"]
        let localBin = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin").path
        let searchPath = [localBin, "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"].joined(separator: ":")
        process.environment = ProcessInfo.processInfo.environment.merging(["PATH": searchPath]) { _, new in new }
        let input = Pipe(), output = Pipe(), errors = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = errors
        do { try process.run() } catch { return .failure(error) }
        let initial = """
        {"method":"initialize","id":1,"params":{"clientInfo":{"name":"topnest","title":"TopNest","version":"0.4.0"}}}
        {"method":"initialized","params":{}}

        """
        input.fileHandleForWriting.write(Data(initial.utf8))
        DispatchQueue.global().asyncAfter(deadline: .now() + 10) {
            if process.isRunning { process.terminate() }
        }
        var buffer = Data()
        var sentRequest = false
        while process.isRunning {
            let chunk = output.fileHandleForReading.availableData
            if chunk.isEmpty { break }
            buffer.append(chunk)
            while let newline = buffer.firstIndex(of: 10) {
                let line = Data(buffer[..<newline])
                buffer.removeSubrange(...newline)
                guard let response = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any],
                      let id = response["id"] as? Int else { continue }
                if id == 1 && !sentRequest {
                    if response["error"] != nil { process.terminate(); return .failure(UsageError.protocolError) }
                    input.fileHandleForWriting.write(Data("{\"method\":\"account/rateLimits/read\",\"id\":2}\n".utf8))
                    sentRequest = true
                } else if id == 2 {
                    if process.isRunning { process.terminate() }
                    guard let result = response["result"] as? [String: Any] else { return .failure(UsageError.noAccount) }
                    let buckets = result["rateLimitsByLimitId"] as? [String: Any]
                    let selected = (buckets?["codex"] as? [String: Any]) ?? (result["rateLimits"] as? [String: Any])
                    guard let selected else { return .failure(UsageError.noAccount) }
                    return .success(UsageSnapshot(primary: parseWindow(selected["primary"]), secondary: parseWindow(selected["secondary"]), updatedAt: Date()))
                }
            }
        }
        return .failure(UsageError.timeout)
    }

    private static func parseWindow(_ value: Any?) -> UsageWindow? {
        guard let window = value as? [String: Any], let used = window["usedPercent"] as? Double else { return nil }
        let reset = (window["resetsAt"] as? Double).map(Date.init(timeIntervalSince1970:))
        return UsageWindow(usedPercent: used, resetAt: reset)
    }

    private static func executableURL() -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        for path in ["\(home)/.local/bin/codex", "/opt/homebrew/bin/codex", "/usr/local/bin/codex"] {
            if FileManager.default.isExecutableFile(atPath: path) { return URL(fileURLWithPath: path) }
        }
        return nil
    }

    enum UsageError: LocalizedError {
        case notInstalled, noAccount, timeout, protocolError
        var errorDescription: String? {
            switch self {
            case .notInstalled: "Codex CLI topilmadi."
            case .noAccount: "Codex hisobiga kirilmagan yoki limit ma’lumoti mavjud emas."
            case .timeout: "Codex javob bermadi."
            case .protocolError: "Codex bilan ulanishda xato."
            }
        }
    }
}

enum ClaudeUsageService {
    static func cached() -> UsageSnapshot? {
        guard let data = try? Data(contentsOf: ClaudeStatusBridge.cacheURL),
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let limits = root["rate_limits"] as? [String: Any],
              let captured = root["captured_at"] as? Double else { return nil }
        return UsageSnapshot(primary: parse(limits["five_hour"]), secondary: parse(limits["seven_day"]), updatedAt: Date(timeIntervalSince1970: captured))
    }

    private static func parse(_ value: Any?) -> UsageWindow? {
        guard let dict = value as? [String: Any], let used = dict["used_percentage"] as? Double else { return nil }
        return UsageWindow(usedPercent: used, resetAt: (dict["resets_at"] as? Double).map(Date.init(timeIntervalSince1970:)))
    }
}
