import XCTest
@testable import TopNest

final class WidgetLayoutTests: XCTestCase {
    private func items(_ sizes: [WidgetSize]) -> [WidgetGridItem] {
        sizes.map { WidgetGridItem(id: UUID(), size: $0) }
    }

    // Har bir katak ko'pi bilan bitta widgetga tegishli va hamma widget grid ichida.
    private func assertValid(_ result: GridLayoutResult, rows: Int, count: Int, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(result.placements.count, count, "hamma widget joylashishi kerak", file: file, line: line)
        var occupied = Set<[Int]>()
        for placement in result.placements {
            XCTAssertGreaterThanOrEqual(placement.row, 0, file: file, line: line)
            XCTAssertLessThanOrEqual(placement.row + placement.rows, rows, file: file, line: line)
            XCTAssertLessThanOrEqual(placement.column + placement.columns, result.columnCount, file: file, line: line)
            for c in placement.column..<(placement.column + placement.columns) {
                for r in placement.row..<(placement.row + placement.rows) {
                    XCTAssertTrue(occupied.insert([c, r]).inserted, "katak [\(c), \(r)] ikki marta band", file: file, line: line)
                }
            }
        }
    }

    func testDefaultSetFillsFourColumnsWithoutGaps() {
        // Standart to'plam: katta musiqa, o'rta kalendar, 3 ta kichik va o'rta clipboard.
        let result = WidgetLayout.pack(items([.large, .medium, .small, .small, .small, .medium]), rows: 2)
        assertValid(result, rows: 2, count: 6)
        // 4 + 2 + 3 + 2 = 11 katak → 2 qatorda kamida 6 ustun; bo'sh sahifa emas, ixcham grid.
        XCTAssertEqual(result.columnCount, 6)
    }

    func testSmallWidgetFillsHoleLeftByLargeOne() {
        // Kichik (0,0), keyin katta (1–2 ustun), keyingi kichik (0,1) dagi teshikni to'ldiradi.
        let result = WidgetLayout.pack(items([.small, .large, .small]), rows: 2)
        assertValid(result, rows: 2, count: 3)
        XCTAssertEqual(result.columnCount, 3)
        XCTAssertEqual(result.placements[2].column, 0)
        XCTAssertEqual(result.placements[2].row, 1)
    }

    func testFillsColumnTopThenBottom() {
        let result = WidgetLayout.pack(items([.small, .small, .small]), rows: 2)
        XCTAssertEqual(result.placements.map { [$0.column, $0.row] }, [[0, 0], [0, 1], [1, 0]])
        XCTAssertEqual(result.columnCount, 2)
    }

    func testMediumWidgetsStackIntoRows() {
        let result = WidgetLayout.pack(items([.medium, .medium, .medium]), rows: 2)
        assertValid(result, rows: 2, count: 3)
        XCTAssertEqual(result.columnCount, 4)
    }

    func testLargeWidgetClampsToSingleRowGrid() {
        let result = WidgetLayout.pack(items([.large, .small]), rows: 1)
        assertValid(result, rows: 1, count: 2)
        XCTAssertEqual(result.placements[0].rows, 1)
    }

    func testEmptyInput() {
        let result = WidgetLayout.pack([], rows: 2)
        XCTAssertTrue(result.placements.isEmpty)
        XCTAssertEqual(result.columnCount, 0)
    }

    func testManyRandomCombinationsStayValid() {
        var generator = SystemRandomNumberGenerator()
        for _ in 0..<500 {
            let sizes = (0..<Int.random(in: 1...12, using: &generator)).map { _ in WidgetSize.allCases.randomElement(using: &generator)! }
            let result = WidgetLayout.pack(items(sizes), rows: 2)
            assertValid(result, rows: 2, count: sizes.count)
            // Ixchamlik: jami katakdan kelib chiqadigan minimal ustunlardan ko'p emas (+1 teshik uchun zaxira).
            let cells = sizes.reduce(0) { $0 + $1.columns * $1.rows }
            XCTAssertLessThanOrEqual(result.columnCount, (cells + 1) / 2 + 1)
        }
    }

    func testDisplayColumns() {
        XCTAssertEqual(WidgetLayout.displayColumns(for: 1), 3)
        XCTAssertEqual(WidgetLayout.displayColumns(for: 3), 3)
        XCTAssertEqual(WidgetLayout.displayColumns(for: 4), 4)
        XCTAssertEqual(WidgetLayout.displayColumns(for: 9), 4)
    }
}
