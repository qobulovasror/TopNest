import Foundation

enum SettingsMigration {
    private static let oldBundleID = "com.codex.nukta.prototype"
    private static let migrationKey = "migratedFromNukta"

    static func migrateIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: migrationKey) else { return }

        if let old = defaults.persistentDomain(forName: oldBundleID) {
            for key in ["musicEnabled", "hoverEnabled", "codexEnabled", "clipboardEnabled"] {
                if defaults.object(forKey: key) == nil, let value = old[key] as? Bool {
                    defaults.set(value, forKey: key)
                }
            }
            if defaults.object(forKey: "weatherCity") == nil, let city = old["weatherCity"] as? String {
                defaults.set(city, forKey: "weatherCity")
            }
        }

        let files = FileManager.default
        let support = files.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let oldCache = support.appendingPathComponent("Nukta/claude-usage.json")
        let newCache = support.appendingPathComponent("TopNest/claude-usage.json")
        if files.fileExists(atPath: oldCache.path), !files.fileExists(atPath: newCache.path) {
            try? files.createDirectory(at: newCache.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? files.copyItem(at: oldCache, to: newCache)
        }

        defaults.set(true, forKey: migrationKey)
    }
}
