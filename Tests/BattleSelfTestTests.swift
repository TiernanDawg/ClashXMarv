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
    func testPracticeScenariosAreRepeatableAndIsolated() {
        let deck = CardCatalog.starterDeck
        let dummy = BattleModel(deck: deck, seed: 42, isPractice: true, practiceScenario: .targetDummy)
        XCTAssertTrue(dummy.isPractice)
        XCTAssertEqual(dummy.practiceScenario, .targetDummy)
        XCTAssertEqual(dummy.entities.filter { $0.tower && $0.maxHP >= 100000 }.count, 1)

        let defense = BattleModel(deck: deck, seed: 42, isPractice: true, practiceScenario: .enemyPush)
        XCTAssertEqual(defense.practiceScenario, .enemyPush)
        XCTAssertEqual(defense.entities.filter { $0.team == .red && !$0.tower }.count, 3)

        let standard = BattleModel(deck: deck, seed: 42, isPractice: true, practiceScenario: .standard)
        XCTAssertEqual(standard.entities.filter { $0.tower }.count, 6)
    }
}
