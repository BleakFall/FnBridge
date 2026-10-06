import XCTest
@testable import FnBridge

final class SmokeTests: XCTestCase {
    func testFKeyActionHasTwelveCases() {
        XCTAssertEqual(FKeyAction.allCases.count, 12)
    }
}
