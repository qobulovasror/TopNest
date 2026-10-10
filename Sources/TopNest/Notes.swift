import Foundation

struct Note: Codable, Identifiable, Equatable {
    var id = UUID()
    var text: String
    var pinned = false
    var updatedAt = Date()

    // Birinchi bo'sh bo'lmagan qator — sarlavha, qolgani — ko'rinish matni.
    var title: String {
        text.split(whereSeparator: \.isNewline).first.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
    }

    var preview: String {
        let lines = text.split(whereSeparator: \.isNewline).dropFirst()
        return lines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: " ")
    }

    var isBlank: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

// Qaydlar diskda (Application Support/TopNest/notes.json); yozish 0,5 s kechiktirib, ketma-ket tahrirlar birlashtiriladi.
@MainActor
final class NotesStore: ObservableObject {
    @Published private(set) var notes: [Note] = []
    @Published var selectedID: UUID?
    // O'chirishni qaytarish uchun oxirgi o'chirilgan qayd.
    @Published private(set) var lastDeleted: Note?
    // Har so'rovda tahrirlagichga fokus beriladi (yorliq va "yangi qayd").
    @Published private(set) var focusRequest = 0
    private let store: JSONFileStore<[Note]>
    private var saveTask: Task<Void, Never>?

    init(store: JSONFileStore<[Note]> = JSONFileStore("notes.json")) {
        self.store = store
        notes = Self.sorted(store.load() ?? [])
        selectedID = notes.first?.id
    }

    var selected: Note? { notes.first { $0.id == selectedID } }

    // Panel widgeti uchun: mahkamlangan, bo'lmasa eng oxirgi tahrirlangan qayd.
    var featured: Note? { notes.first { !$0.isBlank } }

    func filtered(_ query: String) -> [Note] {
        let query = query.trimmingCharacters(in: .whitespaces)
        return query.isEmpty ? notes : notes.filter { $0.text.localizedCaseInsensitiveContains(query) }
    }

    @discardableResult
    func create(_ text: String = "") -> Note {
        // Avvalgi bo'sh qayd ham o'chishi uchun tanlov oldin bo'shatiladi.
        selectedID = nil
        lastDeleted = nil
        pruneBlank()
        let note = Note(text: text)
        notes.insert(note, at: notes.firstIndex { !$0.pinned } ?? notes.count)
        selectedID = note.id
        focusRequest += 1
        scheduleSave()
        return note
    }

    // Bo'sh qayd tanlovdan chiqqanda o'chadi: ro'yxatda "Yangi qayd"lar to'planib qolmaydi.
    func select(_ id: UUID?) {
        guard id != selectedID else { return }
        selectedID = id
        lastDeleted = nil
        pruneBlank()
    }

    func update(_ id: UUID, text: String) {
        guard let index = notes.firstIndex(where: { $0.id == id }), notes[index].text != text else { return }
        notes[index].text = text
        notes[index].updatedAt = Date()
        // Tahrirlangan qayd o'z guruhi (mahkamlangan yoki oddiy) tepasiga ko'tariladi.
        notes = Self.sorted(notes)
        scheduleSave()
    }

    func togglePin(_ id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].pinned.toggle()
        notes = Self.sorted(notes)
        scheduleSave()
    }

    func delete(_ id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        let note = notes.remove(at: index)
        lastDeleted = note.isBlank ? nil : note
        if selectedID == id { selectedID = notes.first?.id }
        scheduleSave()
    }

    func undoDelete() {
        guard let note = lastDeleted else { return }
        notes = Self.sorted(notes + [note])
        selectedID = note.id
        lastDeleted = nil
        scheduleSave()
    }

    func requestFocus() { focusRequest += 1 }

    // Ilova yopilganda kutilayotgan yozuv darhol diskka tushadi.
    func flush() {
        saveTask?.cancel()
        saveTask = nil
        persist()
    }

    private func pruneBlank() {
        let before = notes.count
        notes.removeAll { $0.isBlank && $0.id != selectedID }
        if notes.count != before { scheduleSave() }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self?.persist()
        }
    }

    private func persist() {
        let kept = notes.filter { !$0.isBlank }
        if kept.isEmpty { store.remove() } else { store.save(kept) }
    }

    static func sorted(_ notes: [Note]) -> [Note] {
        notes.sorted { lhs, rhs in
            if lhs.pinned != rhs.pinned { return lhs.pinned }
            return lhs.updatedAt > rhs.updatedAt
        }
    }
}
