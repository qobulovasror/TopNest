import AppKit
import Foundation
import UniformTypeIdentifiers

struct ShelfItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL

    var name: String { url.lastPathComponent }
}

// Fayllar ko'chirilmaydi: tokchada faqat ularning yo'li saqlanadi.
@MainActor
final class ShelfService: ObservableObject {
    static let limit = 30

    @Published private(set) var items: [ShelfItem]

    init() {
        let paths = UserDefaults.standard.stringArray(forKey: "shelfPaths") ?? []
        items = paths.map { URL(fileURLWithPath: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
            .map { ShelfItem(url: $0) }
    }

    func add(_ urls: [URL]) {
        let fresh = urls.filter(\.isFileURL).map(\.standardizedFileURL)
            .filter { url in !items.contains { $0.url.path == url.path } }
        guard !fresh.isEmpty else { return }
        items.insert(contentsOf: fresh.map { ShelfItem(url: $0) }, at: 0)
        items = Array(items.prefix(Self.limit))
        persist()
    }

    func remove(_ item: ShelfItem) {
        items.removeAll { $0.id == item.id }
        persist()
    }

    func clear() {
        items.removeAll()
        persist()
    }

    func pruneMissing() {
        let existing = items.filter { FileManager.default.fileExists(atPath: $0.url.path) }
        guard existing.count != items.count else { return }
        items = existing
        persist()
    }

    func open(_ item: ShelfItem) { NSWorkspace.shared.open(item.url) }

    func reveal(_ items: [ShelfItem]) { NSWorkspace.shared.activateFileViewerSelecting(items.map(\.url)) }

    func airDrop(_ items: [ShelfItem]) {
        guard !items.isEmpty, let service = NSSharingService(named: .sendViaAirDrop) else { return }
        service.perform(withItems: items.map(\.url))
    }

    func icon(for item: ShelfItem) -> NSImage { NSWorkspace.shared.icon(forFile: item.url.path) }

    // Drop provider'laridan fayl URL'larini o'qib, tokchaga qo'shadi.
    func accept(_ providers: [NSItemProvider]) -> Bool {
        let fileProviders = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !fileProviders.isEmpty else { return false }
        let collector = URLCollector(count: fileProviders.count)
        let group = DispatchGroup()
        for (index, provider) in fileProviders.enumerated() {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url: URL? = (item as? Data).flatMap { URL(dataRepresentation: $0, relativeTo: nil) } ?? (item as? URL)
                collector.set(url, at: index)
                group.leave()
            }
        }
        // Tashlangan tartib saqlanishi uchun hammasi bir martada qo'shiladi.
        group.notify(queue: .main) { [weak self] in
            MainActor.assumeIsolated { self?.add(collector.urls) }
        }
        return true
    }

    private final class URLCollector: @unchecked Sendable {
        private let lock = NSLock()
        private var slots: [URL?]
        init(count: Int) { slots = Array(repeating: nil, count: count) }
        func set(_ url: URL?, at index: Int) { lock.withLock { slots[index] = url } }
        var urls: [URL] { lock.withLock { slots.compactMap { $0 } } }
    }

    private func persist() {
        UserDefaults.standard.set(items.map(\.url.path), forKey: "shelfPaths")
    }
}
