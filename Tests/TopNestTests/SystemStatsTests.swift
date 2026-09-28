import XCTest
@testable import TopNest

@MainActor
final class SystemStatsTests: XCTestCase {
    // Vaqtga emas, shartga qarab kutadi (band CI mashinasida ham barqaror).
    private func wait(upTo seconds: TimeInterval, until condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(seconds)
        while !condition() && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.1)) }
    }

    // Faqat CPU widgeti ko'rinsa GPU, RAM va tarmoq o'lchanmaydi.
    func testMeasuresOnlyVisibleKinds() {
        let stats = SystemStatsService()
        let id = UUID()
        stats.retain(id, kind: .cpu)
        wait(upTo: 8) { stats.cpu != nil }
        XCTAssertNotNil(stats.cpu, "ikkinchi namunadan keyin CPU qiymati bo'lishi kerak")
        XCTAssertNil(stats.gpu)
        XCTAssertEqual(stats.memoryUsed, 0)
        XCTAssertNil(stats.download)
        XCTAssertEqual(stats.neededKinds, [.cpu])
        stats.release(id)
    }

    func testReleaseClearsValuesAndRepeatedRetainIsIdempotent() {
        let stats = SystemStatsService()
        let id = UUID()
        stats.retain(id, kind: .memory)
        stats.retain(id, kind: .memory)
        wait(upTo: 5) { stats.memoryUsed > 0 }
        XCTAssertGreaterThan(stats.memoryUsed, 0)
        stats.release(id)
        XCTAssertTrue(stats.neededKinds.isEmpty)
        XCTAssertNil(stats.history[.memory])
        // Ortiqcha release hisobni buzmaydi.
        stats.release(id)
        XCTAssertTrue(stats.neededKinds.isEmpty)
    }
}
