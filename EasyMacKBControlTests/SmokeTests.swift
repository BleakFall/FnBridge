import XCTest
@testable import EasyMacKBControl

final class SmokeTests: XCTestCase {
    func testFKeyActionHasTwelveCases() {
        XCTAssertEqual(FKeyAction.allCases.count, 12)
    }
}
