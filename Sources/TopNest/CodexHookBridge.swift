import Foundation

// Codex'ning rasmiy PermissionRequest hook'i faqat xabar yuboradi. Hech qachon
// allow/deny chiqarmaydi; qaror Codex'dagi odatiy tasdiq oynasida qoladi.
enum CodexHookBridge {
    private static var hooksURL: URL {
        let base = ProcessInfo.processInfo.environment["CODEX_HOME"]
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex", isDirectory: true)
        return base.appendingPathComponent("hooks.json").resolvingSymlinksInPath()
    }

    private static func isOurs(_ hook: [String: Any]) -> Bool {
        let command = hook["command"] as? String ?? ""
        return command.contains("TopNest") && command.contains(ClaudePermissionBridge.genericFlag)
    }

    private static func removingOurs(_ entries: [Any]) -> [Any] {
        entries.compactMap { entry -> Any? in
            guard var group = entry as? [String: Any], let handlers = group["hooks"] as? [[String: Any]] else { return entry }
            let remaining = handlers.filter { !isOurs($0) }
            if remaining.isEmpty { return nil }
            group["hooks"] = remaining
            return group
        }
    }

    static func isInstalled() -> Bool {
        guard let data = try? Data(contentsOf: hooksURL),
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let hooks = root["hooks"] as? [String: Any],
              let entries = hooks["PermissionRequest"] as? [Any] else { return false }
        return entries.contains { entry in
            ((entry as? [String: Any])?["hooks"] as? [[String: Any]])?.contains(where: isOurs) == true
        }
    }

    static func install() -> String? {
        guard let executable = Bundle.main.executableURL else { return "TopNest ilova yo‘li topilmadi." }
        return update(enabled: true, at: hooksURL, executable: executable)
    }
    static func uninstall() -> String? { update(enabled: false, at: hooksURL, executable: nil) }

    // URL argumenti testda ajratilgan vaqtinchalik config ishlatishga imkon beradi.
    static func update(enabled: Bool, at url: URL, executable: URL?) -> String? {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let original = try? Data(contentsOf: url)
        if attributes != nil && original == nil { return "Codex hooks.json faylini o‘qib bo‘lmadi; u o‘zgartirilmadi." }
        var root: [String: Any]
        if let original {
            guard let decoded = (try? JSONSerialization.jsonObject(with: original)) as? [String: Any] else {
                return "Codex hooks.json JSON formatida emas; u o‘zgartirilmadi."
            }
            root = decoded
        } else { root = [:] }
        if let value = root["hooks"], !(value is [String: Any]) {
            return "Codex hooks.json tuzilmasi tanilmadi; u o‘zgartirilmadi."
        }
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        if let value = hooks["PermissionRequest"], !(value is [Any]) {
            return "Codex PermissionRequest hook tuzilmasi tanilmadi; u o‘zgartirilmadi."
        }
        var entries = removingOurs(hooks["PermissionRequest"] as? [Any] ?? [])
        if enabled {
            guard let executable else { return "TopNest ilova yo‘li topilmadi." }
            entries.append(["hooks": [[
                "type": "command",
                "command": "\"\(executable.path)\" \(ClaudePermissionBridge.genericFlag) Codex",
                "timeout": ClaudePermissionBridge.hookTimeout
            ]]])
        }
        if entries.isEmpty { hooks.removeValue(forKey: "PermissionRequest") }
        else { hooks["PermissionRequest"] = entries }
        if hooks.isEmpty { root.removeValue(forKey: "hooks") }
        else { root["hooks"] = hooks }
        guard enabled || original != nil else { return nil }

        // O'qishdan keyin boshqa dastur faylni o'zgartirgan bo'lsa ustiga yozilmaydi.
        let current = try? Data(contentsOf: url)
        guard current == original else { return "Codex hooks.json shu orada o‘zgardi. Qayta urinib ko‘ring." }
        do {
            let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            if let permissions = attributes?[.posixPermissions] {
                try? FileManager.default.setAttributes([.posixPermissions: permissions], ofItemAtPath: url.path)
            }
            return enabled ? "Codex’da /hooks orqali yangi TopNest hook’ini ko‘rib, ishonchli deb belgilang." : nil
        } catch {
            return L10n.format("Codex hook’ini saqlab bo‘lmadi: %@", error.localizedDescription)
        }
    }
}
