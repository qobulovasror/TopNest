import Foundation

// Application Support/TopNest ichidagi JSON fayl: atomik yozish (0600), o'qib bo'lmagan fayl .bak ga ko'chiriladi.
struct JSONFileStore<Value: Codable> {
    let url: URL

    init(_ name: String, directory: URL = JSONFileStore.defaultDirectory) {
        url = directory.appendingPathComponent(name)
    }

    static var defaultDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/TopNest")
    }

    func load() -> Value? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        if let value = try? JSONDecoder().decode(Value.self, from: data) { return value }
        // O'qib bo'lmagan fayl ustidan yozilmasin.
        let backup = url.appendingPathExtension("bak")
        try? FileManager.default.removeItem(at: backup)
        try? FileManager.default.moveItem(at: url, to: backup)
        return nil
    }

    @discardableResult
    func save(_ value: Value) -> Bool {
        guard let data = try? JSONEncoder().encode(value) else { return false }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        // Vaqtinchalik fayl darhol 0600 bilan yaratiladi, keyin almashtiriladi.
        let temp = url.appendingPathExtension("tmp")
        guard FileManager.default.createFile(atPath: temp.path, contents: data, attributes: [.posixPermissions: 0o600]) else { return false }
        if rename(temp.path, url.path) != 0 {
            try? FileManager.default.removeItem(at: temp)
            return false
        }
        return true
    }

    func remove() {
        try? FileManager.default.removeItem(at: url)
    }
}
