import XCTest
@testable import Archie

@MainActor
final class FreeScanCounterTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "FreeScanCounterTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    private func makeCounter(userId: String? = "user-a", limit: Int = 10) -> FreeScanCounter {
        FreeScanCounter(defaults: defaults, userId: userId, limit: limit)
    }

    func test_newUser_hasFullAllowance() {
        let counter = makeCounter()
        XCTAssertEqual(counter.used, 0)
        XCTAssertEqual(counter.remaining, 10)
        XCTAssertTrue(counter.hasFreeScans)
    }

    func test_recordScan_decrementsRemaining() {
        let counter = makeCounter()
        counter.recordScan()
        counter.recordScan()
        XCTAssertEqual(counter.used, 2)
        XCTAssertEqual(counter.remaining, 8)
    }

    func test_recordScan_persistsAcrossInstances() {
        makeCounter().recordScan()
        XCTAssertEqual(makeCounter().used, 1)
    }

    func test_atLimit_hasNoFreeScans_andRemainingNeverNegative() {
        let counter = makeCounter(limit: 2)
        counter.recordScan()
        counter.recordScan()
        counter.recordScan()
        XCTAssertFalse(counter.hasFreeScans)
        XCTAssertEqual(counter.remaining, 0)
    }

    func test_usersAreIsolated() {
        makeCounter(userId: "user-a").recordScan()
        XCTAssertEqual(makeCounter(userId: "user-b").used, 0)
    }

    func test_setUser_reloadsCount() {
        makeCounter(userId: "user-b").recordScan()
        let counter = makeCounter(userId: "user-a")
        counter.setUser("user-b")
        XCTAssertEqual(counter.used, 1)
        counter.setUser(nil)
        XCTAssertEqual(counter.used, 0)
    }

    func test_setLimit_updatesRemaining() {
        let counter = makeCounter()
        counter.recordScan()
        counter.setLimit(3)
        XCTAssertEqual(counter.limit, 3)
        XCTAssertEqual(counter.remaining, 2)
    }

    func test_setLimit_nilOrNonPositive_fallsBackToDefault() {
        let counter = makeCounter(limit: 3)
        counter.setLimit(nil)
        XCTAssertEqual(counter.limit, FreeScanPolicy.defaultLimit)
        counter.setLimit(0)
        XCTAssertEqual(counter.limit, FreeScanPolicy.defaultLimit)
        counter.setLimit(-5)
        XCTAssertEqual(counter.limit, FreeScanPolicy.defaultLimit)
    }
}
