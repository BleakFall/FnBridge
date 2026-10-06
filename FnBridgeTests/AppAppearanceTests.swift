import AppKit
import XCTest
@testable import FnBridge

final class AppAppearanceTests: XCTestCase {
    func testActivationPolicyMapping() {
        XCTAssertEqual(AppAppearance.activationPolicy(showInDock: true), .regular)
        XCTAssertEqual(AppAppearance.activationPolicy(showInDock: false), .accessory)
    }
}
