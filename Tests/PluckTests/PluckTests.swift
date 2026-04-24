import XCTest
@testable import Pluck

final class PluckTests: XCTestCase {
    func testPackageBuilds() {
        _ = Pluck.self
    }
}
