import XCTest
@testable import TopNest

@MainActor
final class NotesTests: XCTestCase {
    private var directory: URL!

    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func makeStore() -> NotesStore {
        NotesStore(store: JSONFileStore("notes.json", directory: directory))
    }

    func testTitleAndPreview() {
        let note = Note(text: "\n  Xarid  \nnon\n\nsut")
        XCTAssertEqual(note.title, "Xarid")
        XCTAssertEqual(note.preview, "non sut")
        XCTAssertTrue(Note(text: " \n ").isBlank)
    }

    func testCreateEditPersistAndBlankNotesAreDropped() {
        let store = makeStore()
        let first = store.create("Birinchi")
        store.create()
        // Bo'sh qayd tanlovdan chiqsa o'chadi.
        store.select(first.id)
        XCTAssertEqual(store.notes.count, 1)
        store.update(first.id, text: "Birinchi\nmatn")
        store.flush()
        let reloaded = makeStore()
        XCTAssertEqual(reloaded.notes.map(\.text), ["Birinchi\nmatn"])
        XCTAssertEqual(reloaded.selectedID, first.id)
    }

    func testRepeatedNewNoteDoesNotPileUpBlanks() {
        let store = makeStore()
        store.create()
        store.create()
        store.create("Matn")
        XCTAssertEqual(store.notes.map(\.text), ["Matn"])
    }

    func testPinnedFirstAndRecentlyEditedNext() {
        let store = makeStore()
        let a = store.create("A")
        let b = store.create("B")
        let c = store.create("C")
        store.togglePin(a.id)
        store.update(b.id, text: "B2")
        XCTAssertEqual(store.notes.map(\.id), [a.id, b.id, c.id])
        XCTAssertEqual(store.featured?.id, a.id)
        XCTAssertEqual(store.filtered("b2").map(\.id), [b.id])
    }

    func testDeleteAndUndo() {
        let store = makeStore()
        let a = store.create("A")
        store.delete(a.id)
        XCTAssertTrue(store.notes.isEmpty)
        XCTAssertEqual(store.lastDeleted?.id, a.id)
        store.undoDelete()
        XCTAssertEqual(store.notes.map(\.id), [a.id])
        XCTAssertNil(store.lastDeleted)
        store.delete(a.id)
        store.flush()
        XCTAssertNil(JSONFileStore<[Note]>("notes.json", directory: directory).load())
    }
}
