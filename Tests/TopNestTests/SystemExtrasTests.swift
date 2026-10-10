import XCTest
@testable import TopNest

final class SystemExtrasTests: XCTestCase {
    func testCPUAlertFiresOnceAfterSustainedLoadAndRearms() {
        var policy = CPUAlertPolicy()
        let start = Date()
        XCTAssertFalse(policy.feed(0.95, at: start))
        XCTAssertFalse(policy.feed(0.95, at: start.addingTimeInterval(119)))
        XCTAssertTrue(policy.feed(0.95, at: start.addingTimeInterval(120)))
        XCTAssertFalse(policy.feed(0.95, at: start.addingTimeInterval(400)))
        // Qisqa pasayish (70% dan yuqori) qayta qurollamaydi.
        XCTAssertFalse(policy.feed(0.8, at: start.addingTimeInterval(410)))
        XCTAssertFalse(policy.feed(0.95, at: start.addingTimeInterval(700)))
        XCTAssertFalse(policy.feed(0.5, at: start.addingTimeInterval(710)))
        XCTAssertFalse(policy.feed(0.95, at: start.addingTimeInterval(720)))
        XCTAssertTrue(policy.feed(0.95, at: start.addingTimeInterval(840)))
    }

    func testDipAboveRearmDoesNotResetWindow() {
        var policy = CPUAlertPolicy()
        let start = Date()
        XCTAssertFalse(policy.feed(0.95, at: start))
        XCTAssertFalse(policy.feed(0.88, at: start.addingTimeInterval(60)))
        XCTAssertTrue(policy.feed(0.92, at: start.addingTimeInterval(121)))
    }

    func testParseProcesses() {
        let output = """
          623  45.4  61792 WindowServer
          964 134,1  14992 Google Chrome Helper
            1   0.0  21424 launchd
          bad line
        """
        let processes = SystemExtras.parseProcesses(output, limit: 2, excluding: 1)
        XCTAssertEqual(processes.map(\.name), ["Google Chrome Helper", "WindowServer"])
        XCTAssertEqual(processes[0].cpu, 134.1)
        XCTAssertEqual(processes[1].memory, 61792 * 1024)
    }

    func testBatteryHealthPrefersBatteryData() {
        let top: [String: Int] = ["CycleCount": 366, "MaxCapacity": 100]
        let health = SystemExtras.health(top: { top[$0] }, data: ["DesignCapacity": 6075, "NominalChargeCapacity": 4961])
        XCTAssertEqual(health?.cycles, 366)
        XCTAssertEqual(health?.capacity ?? 0, 0.8166, accuracy: 0.001)
        let legacy: [String: Int] = ["DesignCapacity": 5000, "AppleRawMaxCapacity": 4500, "CycleCount": 10]
        XCTAssertEqual(SystemExtras.health(top: { legacy[$0] }, data: [:])?.capacity ?? 0, 0.9, accuracy: 0.001)
        // Faqat foizli MaxCapacity — salomatlik ko'rsatilmaydi.
        XCTAssertNil(SystemExtras.health(top: { top[$0] }, data: [:]))
    }

    @MainActor
    func testCompositeViewerRegistersAndReleasesKinds() {
        let stats = SystemStatsService()
        let id = UUID()
        stats.retain(id, kinds: [.cpu, .memory])
        XCTAssertEqual(stats.neededKinds, [.cpu, .memory])
        stats.retain(id, kinds: [.cpu])
        XCTAssertEqual(stats.neededKinds, [.cpu])
        stats.release(id)
        XCTAssertTrue(stats.neededKinds.isEmpty)
    }
}
