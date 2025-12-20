import XCTest
@testable import Archie

final class ScanDurationFormatterTests: XCTestCase {
    private let formatter = ScanDurationFormatter()

    func test_formatsSubSecondDurationsWithTenths() {
        let duration = Duration.milliseconds(240)
        XCTAssertEqual(formatter.string(from: duration), "0.2 s")
    }

    func test_formatsShortDurationsWithTenths() {
        let duration = Duration.nanoseconds(1_230_000_000)
        XCTAssertEqual(formatter.string(from: duration), "1.2 s")
    }

    func test_formatsLongerDurationsWithSingleDecimal() {
        let duration = Duration.nanoseconds(12_340_000_000)
        XCTAssertEqual(formatter.string(from: duration), "12.3 s")
    }

    func test_roundsHalfUpToTenths() {
        let duration = Duration.nanoseconds(2_550_000_000)
        XCTAssertEqual(formatter.string(from: duration), "2.6 s")
    }
}
