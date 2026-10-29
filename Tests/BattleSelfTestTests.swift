import XCTest
@testable import VanguardArena

@MainActor
final class BattleSelfTestTests: XCTestCase {
    func testCompleteRosterHasUsableStatsAndUniqueIDs() {
        XCTAssertEqual(CardCatalog.all.count, 91, "Every requested card must be present")
        XCTAssertEqual(Set(CardCatalog.all.map(\.id)).count, 91, "Card IDs must be unique")
        XCTAssertEqual(CardCatalog.starterDeck.count, 8)
        for card in CardCatalog.all {
            XCTAssertFalse(card.name.isEmpty)
            XCTAssertFalse(card.description.isEmpty)
            XCTAssertGreaterThanOrEqual(card.cost, 1)
            XCTAssertLessThanOrEqual(card.cost, 9)
            XCTAssertTrue(card.hp.isFinite && card.damage.isFinite && card.range.isFinite && card.speed.isFinite && card.hitSpeed.isFinite, "Non-finite stats for \(card.name)")
            XCTAssertGreaterThan(card.hitSpeed, 0, "Invalid hit speed for \(card.name)")
            XCTAssertFalse(card.behavior.isEmpty, "Missing behavior flags for \(card.name)")
            if card.kind == .spell {
                XCTAssertEqual(card.hp, 0, "Spell HP must be zero: \(card.name)")
            } else {
                XCTAssertGreaterThan(card.hp, 0, "Troops/buildings need HP: \(card.name)")
            }
        }
    }

    private func runBatch(_ start: Int) {
        let report = BattleSelfTest.run(matches: 100, startingAt: start)
        XCTAssertEqual(report.matches, 100)
        XCTAssertGreaterThan(report.totalTicks, 0)
        XCTAssertGreaterThan(report.maxEntities, 0)
    }

    func testSimulationBatch00() { runBatch(0) }
    func testSimulationBatch01() { runBatch(100) }
    func testSimulationBatch02() { runBatch(200) }
    func testSimulationBatch03() { runBatch(300) }
    func testSimulationBatch04() { runBatch(400) }
    func testSimulationBatch05() { runBatch(500) }
    func testSimulationBatch06() { runBatch(600) }
    func testSimulationBatch07() { runBatch(700) }
    func testSimulationBatch08() { runBatch(800) }
    func testSimulationBatch09() { runBatch(900) }
}
