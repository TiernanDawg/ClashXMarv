import XCTest
@testable import VanguardArena

@MainActor
final class BattleSelfTestTests: XCTestCase {
    func testOneThousandDeterministicBotMatches() {
        let report = BattleSelfTest.run(matches: 1_000)
        XCTAssertEqual(report.matches, 1_000)
        XCTAssertGreaterThan(report.totalTicks, 0)
        XCTAssertGreaterThan(report.maxEntities, 0)
    }
}
