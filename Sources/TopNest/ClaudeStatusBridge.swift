import Foundation

enum ClaudeStatusBridge {
    static let commandFlag = "--claude-statusline"

    static var cacheURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/TopNest/claude-usage.json")
    }

    // Ulashdan oldingi foydalanuvchi status line sozlamasi; u zanjirda ishga tushiriladi.
    static var originalURL: URL {
        cacheURL.deletingLastPathComponent().appendingPathComponent("statusline-original.json")
    }

    static func run() {
        let data = FileHandle.standardInput.readDataToEndOfFile()
        let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let limits = root?["rate_limits"] as? [String: Any]
        if let limits {
            let cache: [String: Any] = ["rate_limits": limits, "captured_at": Date().timeIntervalSince1970]
            if let output = try? JSONSerialization.data(withJSONObject: cache) {
                try? FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? output.write(to: cacheURL, options: .atomic)
            }
        }
        if let command = originalCommand() {
            runOriginal(command, input: data)
            return
        }
        if let limits {
            let five = (limits["five_hour"] as? [String: Any])?["used_percentage"] as? Double
            let week = (limits["seven_day"] as? [String: Any])?["used_percentage"] as? Double
            let parts = [five.map { "5s: \(Int($0.rounded()))%" }, week.map { "7k: \(Int($0.rounded()))%" }].compactMap { $0 }
            if !parts.isEmpty { print("Claude • " + parts.joined(separator: "  ")) }
        }
    }

    private static func originalCommand() -> String? {
        guard let data = try? Data(contentsOf: originalURL),
              let original = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let command = original["command"] as? String, !command.isEmpty,
              !command.contains(commandFlag) else { return nil }
        return command
    }

    // Claude kabi buyruq shell orqali, xuddi shu stdin bilan bajariladi; chiqishi o'zgarishsiz uzatiladi.
    // stdin alohida oqimda yoziladi (pipe to'lib qolmasin); 3 s dan keyin buyruq to'xtatiladi.
    private static func runOriginal(_ command: String, input: Data) {
        signal(SIGPIPE, SIG_IGN)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]
        let stdin = Pipe(), stdout = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return }
        let writer = stdin.fileHandleForWriting
        DispatchQueue.global().async {
            try? writer.write(contentsOf: input)
            try? writer.close()
        }
        let output = OutputBuffer()
        let finished = DispatchSemaphore(value: 0)
        let reader = stdout.fileHandleForReading
        DispatchQueue.global().async {
            while let chunk = try? reader.read(upToCount: 4096), !chunk.isEmpty { output.append(chunk) }
            finished.signal()
        }
        if finished.wait(timeout: .now() + 3) == .timedOut {
            process.terminate()
            _ = finished.wait(timeout: .now() + 0.5)
        }
        FileHandle.standardOutput.write(output.data)
    }

    private final class OutputBuffer: @unchecked Sendable {
        private let lock = NSLock()
        private var storage = Data()
        func append(_ chunk: Data) { lock.withLock { if storage.count < 65_536 { storage.append(chunk) } } }
        var data: Data { lock.withLock { storage.prefix(65_536) } }
    }

    static func isInstalled() -> Bool {
        guard let settings = loadSettings() else { return false }
        return isInstalled(in: settings)
    }

    private static func isInstalled(in settings: [String: Any]) -> Bool {
        guard let status = settings["statusLine"] as? [String: Any],
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
        guard let executable = Bundle.main.executableURL else { return "Ilova yo‘li topilmadi." }
        let ours = "\"\(executable.path)\" \(commandFlag)"
        if var existing = settings["statusLine"] as? [String: Any],
           (existing["command"] as? String)?.contains(commandFlag) == true {
            // Eski TopNest yo'li: faqat yo'l yangilanadi, o'zini zanjirga qo'shmaslik uchun.
            existing["command"] = ours
            settings["statusLine"] = existing
            return saveSettings(settings)
        }
        if let existing = settings["statusLine"] as? [String: Any] {
            // Mavjud status line saqlanadi: TopNest limitlarni o'qiydi va uning chiqishini ko'rsatadi.
            guard (existing["type"] as? String ?? "command") == "command", existing["command"] is String else {
                return "Claude status line’i tanish formatda emas. Uni almashtirmadik."
            }
            do {
                try FileManager.default.createDirectory(at: originalURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                let backup = try JSONSerialization.data(withJSONObject: existing, options: [.prettyPrinted, .sortedKeys])
                try backup.write(to: originalURL, options: .atomic)
            } catch {
                return "Mavjud status line’ni saqlab bo‘lmadi. Fayl o‘zgartirilmadi."
            }
            var chained = existing
            chained["command"] = ours
            settings["statusLine"] = chained
            if let failure = saveSettings(settings) {
                try? FileManager.default.removeItem(at: originalURL)
                return failure
            }
            return nil
        } else if settings["statusLine"] != nil {
            return "Claude status line’i tanish formatda emas. Uni almashtirmadik."
        }
        try? FileManager.default.removeItem(at: originalURL)
        settings["statusLine"] = ["type": "command", "command": ours]
        return saveSettings(settings)
    }

    static func uninstall() -> String? {
        guard var settings = loadSettings() else { return "Claude sozlamasini o‘qib bo‘lmadi. Fayl o‘zgartirilmadi." }
        guard isInstalled(in: settings) else {
            // Backup faqat sozlamada TopNest buyrug'i umuman qolmaganda o'chiriladi.
            let command = (settings["statusLine"] as? [String: Any])?["command"] as? String
            if command?.contains(commandFlag) != true { try? FileManager.default.removeItem(at: originalURL) }
            return nil
        }
        if let data = try? Data(contentsOf: originalURL),
           let original = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            settings["statusLine"] = original
        } else {
            settings.removeValue(forKey: "statusLine")
        }
        if let failure = saveSettings(settings) { return failure }
        try? FileManager.default.removeItem(at: originalURL)
        return nil
    }

    // MARK: Ruxsat hook'i

    private static func isOurCommand(_ hook: [String: Any]) -> Bool {
        (hook["command"] as? String)?.contains(ClaudePermissionBridge.commandFlag) == true
    }

    private static func isOurHook(_ entry: Any) -> Bool {
        ((entry as? [String: Any])?["hooks"] as? [[String: Any]])?.contains(where: isOurCommand) == true
    }

    // Faqat TopNest buyrug'i olinadi; foydalanuvchining shu yozuvdagi boshqa hook'lari qoladi.
    private static func removingOurHooks(_ entries: [Any]) -> [Any] {
        entries.compactMap { entry -> Any? in
            guard var dict = entry as? [String: Any], let hooks = dict["hooks"] as? [[String: Any]] else { return entry }
            let rest = hooks.filter { !isOurCommand($0) }
            if rest.isEmpty { return nil }
            dict["hooks"] = rest
            return dict
        }
    }

    static func isPermissionHookInstalled() -> Bool {
        guard let hooks = loadSettings()?["hooks"] as? [String: Any],
              let entries = hooks["PermissionRequest"] as? [Any] else { return false }
        return entries.contains(where: isOurHook)
    }

    static func installPermissionHook() -> String? {
        guard var settings = loadSettings() else { return "Claude sozlamasini o‘qib bo‘lmadi. Fayl o‘zgartirilmadi." }
        guard let executable = Bundle.main.executableURL else { return "Ilova yo‘li topilmadi." }
        var hooks = settings["hooks"] as? [String: Any] ?? [:]
        var entries = removingOurHooks(hooks["PermissionRequest"] as? [Any] ?? [])
        entries.append([
            "matcher": "*",
            "hooks": [["type": "command", "command": "\"\(executable.path)\" \(ClaudePermissionBridge.commandFlag)", "timeout": ClaudePermissionBridge.hookTimeout]]
        ])
        hooks["PermissionRequest"] = entries
        settings["hooks"] = hooks
        return saveSettings(settings)
    }

    static func uninstallPermissionHook() -> String? {
        guard var settings = loadSettings() else { return "Claude sozlamasini o‘qib bo‘lmadi. Fayl o‘zgartirilmadi." }
        guard var hooks = settings["hooks"] as? [String: Any] else { return nil }
        let entries = removingOurHooks(hooks["PermissionRequest"] as? [Any] ?? [])
        if entries.isEmpty { hooks.removeValue(forKey: "PermissionRequest") } else { hooks["PermissionRequest"] = entries }
        if hooks.isEmpty { settings.removeValue(forKey: "hooks") } else { settings["hooks"] = hooks }
        return saveSettings(settings)
    }

    private static var settingsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/settings.json")
    }

    // Symlink (dotfiles) buzilmasligi uchun haqiqiy fayl bilan ishlanadi.
    private static var resolvedSettingsURL: URL { settingsURL.resolvingSymlinksInPath() }
    nonisolated(unsafe) private static var loadedModified: Date?

    private static func modificationDate() -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: resolvedSettingsURL.path))?[.modificationDate] as? Date
    }

    private static func loadSettings() -> [String: Any]? {
        loadedModified = modificationDate()
        guard let data = try? Data(contentsOf: resolvedSettingsURL) else { return [:] }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func saveSettings(_ settings: [String: Any]) -> String? {
        let target = resolvedSettingsURL
        let attributes = try? FileManager.default.attributesOfItem(atPath: target.path)
        // O'qish va yozish orasida Claude faylni o'zgartirgan bo'lsa, ustidan yozilmaydi.
        if let current = attributes?[.modificationDate] as? Date, current != loadedModified {
            return "Claude sozlamasi shu orada o‘zgardi. Fayl o‘zgartirilmadi, qayta urinib ko‘ring."
        }
        do {
            let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
            try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: target, options: .atomic)
            if let permissions = attributes?[.posixPermissions] {
                try? FileManager.default.setAttributes([.posixPermissions: permissions], ofItemAtPath: target.path)
            }
            return nil
        } catch {
            return "Claude sozlamasini saqlab bo‘lmadi: \(error.localizedDescription)"
        }
    }
}
