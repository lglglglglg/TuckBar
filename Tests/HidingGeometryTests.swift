import XCTest
@testable import TuckBar

final class HidingGeometryTests: XCTestCase {
    func testUsesStableOffscreenSectionLength() {
        XCTAssertEqual(HidingGeometry.collapsedLength(forDisplayWidths: [1512, 2560]), 10_000)
    }

    func testAppliesMinimumLength() {
        XCTAssertEqual(HidingGeometry.collapsedLength(forDisplayWidths: [120]), 10_000)
        XCTAssertEqual(HidingGeometry.collapsedLength(forDisplayWidths: []), 10_000)
    }

    func testCapsLengthAtSystemSafeMaximum() {
        XCTAssertEqual(HidingGeometry.collapsedLength(forDisplayWidths: [6016]), 10_000)
    }

    func testRejectsWindowNumbersThatCannotBecomeCGWindowIDs() {
        XCTAssertNil(HidingGeometry.windowID(from: -1))
        XCTAssertNil(HidingGeometry.windowID(from: 0))
        XCTAssertNil(HidingGeometry.windowID(from: Int.max))
        XCTAssertEqual(HidingGeometry.windowID(from: 12_291), 12_291)
    }
}
