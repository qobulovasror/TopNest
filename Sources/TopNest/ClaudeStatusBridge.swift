import Foundation

enum ClaudeStatusBridge {
    static let commandFlag = "--claude-statusline"

    static var cacheURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/TopNest/claude-usage.json")
    }

    static func run() {
        let data = FileHandle.standardInput.readDataToEndOfFile()
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return }
        if let limits = root["rate_limits"] as? [String: Any] {
            let cache: [String: Any] = ["rate_limits": limits, "captured_at": Date().timeIntervalSince1970]
            if let output = try? JSONSerialization.data(withJSONObject: cache) {
                try? FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? output.write(to: cacheURL, options: .atomic)
            }
            let five = (limits["five_hour"] as? [String: Any])?["used_percentage"] as? Double
            let week = (limits["seven_day"] as? [String: Any])?["used_percentage"] as? Double
            let parts = [five.map { "5s: \(Int($0.rounded()))%" }, week.map { "7k: \(Int($0.rounded()))%" }].compactMap { $0 }
            if !parts.isEmpty { print("Claude • " + parts.joined(separator: "  ")) }
        }
    }

    static func isInstalled() -> Bool {
        guard let settings = loadSettings(), let status = settings["statusLine"] as? [String: Any],
              let command = status["command"] as? String else { return false }
        return command.contains("TopNest.app/Contents/MacOS/TopNest") && command.contains(commandFlag)
    }

    static func install() -> String? {
        guard var settings = loadSettings() else {
            return "Claude sozlamasini o‘qib bo‘lmadi. Fayl o‘zgartirilmadi."
        }
        if let status = settings["statusLine"] as? [String: Any],
           let command = status["command"] as? String,
           command.contains("Nukta.app/Contents/MacOS/Nukta"), command.contains(commandFlag) {
            guard let executable = Bundle.main.executableURL else { return "Ilova yo‘li topilmadi." }
            settings["statusLine"] = ["type": "command", "command": "\"\(executable.path)\" \(commandFlag)"]
            return saveSettings(settings)
        }
        if settings["statusLine"] != nil {
            return "Claude’da status line allaqachon sozlangan. Uni almashtirmadik."
        }
        guard let executable = Bundle.main.executableURL else { return "Ilova yo‘li topilmadi." }
        settings["statusLine"] = ["type": "command", "command": "\"\(executable.path)\" \(commandFlag)"]
        return saveSettings(settings)
    }

    static func uninstall() -> String? {
        guard var settings = loadSettings(), isInstalled() else { return nil }
        settings.removeValue(forKey: "statusLine")
        return saveSettings(settings)
    }

    private static var settingsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/settings.json")
    }

    private static func loadSettings() -> [String: Any]? {
        guard let data = try? Data(contentsOf: settingsURL) else { return [:] }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func saveSettings(_ settings: [String: Any]) -> String? {
        do {
            let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
            try FileManager.default.createDirectory(at: settingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: settingsURL, options: .atomic)
            return nil
        } catch {
            return "Claude sozlamasini saqlab bo‘lmadi: \(error.localizedDescription)"
        }
    }
}
