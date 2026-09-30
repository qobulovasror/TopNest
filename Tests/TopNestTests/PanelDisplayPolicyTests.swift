import XCTest
@testable import TopNest

final class PanelDisplayPolicyTests: XCTestCase {
    func testSingleDisplayRemainsDefaultAndOtherDisplaysAreMirroredWhenEnabled() {
        XCTAssertEqual(PanelDisplayPolicy.mirrorIDs(available: [1, 2, 3], primary: 1, showOnAll: false), [])
        XCTAssertEqual(PanelDisplayPolicy.mirrorIDs(available: [1, 2, 3], primary: 1, showOnAll: true), [2, 3])
        XCTAssertEqual(PanelDisplayPolicy.mirrorIDs(available: [2, 3], primary: 2, showOnAll: true), [3])
    }

    func testEachCompactPanelHonorsNotchAndFullscreenRules() {
        XCTAssertTrue(PanelDisplayPolicy.compactVisible(hasNotch: false, onlyNotch: false, isFullscreen: false, hideInFullscreen: true))
        XCTAssertFalse(PanelDisplayPolicy.compactVisible(hasNotch: false, onlyNotch: true, isFullscreen: false, hideInFullscreen: true))
        XCTAssertFalse(PanelDisplayPolicy.compactVisible(hasNotch: true, onlyNotch: true, isFullscreen: true, hideInFullscreen: true))
        XCTAssertTrue(PanelDisplayPolicy.compactVisible(hasNotch: true, onlyNotch: true, isFullscreen: true, hideInFullscreen: false))
    }
}
