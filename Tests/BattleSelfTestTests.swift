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

    func testTroopsRedirectToKingWhenTheirLanePrincessTowerFalls() {
        let runner = CardCatalog.all.first { $0.kind == .troop && $0.speed > 0 && !$0.behavior.contains(.buildingTarget) }!
        let setup = [
            BattleEntity(id: 1, cardID: "tower", team: .blue, x: 3.2, y: 2, hp: 2600, maxHP: 2600, tower: true, awake: true),
            BattleEntity(id: 2, cardID: "tower", team: .blue, x: 14.8, y: 2, hp: 2600, maxHP: 2600, tower: true, awake: true),
            BattleEntity(id: 3, cardID: "tower", team: .blue, x: 9, y: 0.7, hp: 4200, maxHP: 4200, tower: true, king: true),
            BattleEntity(id: 4, cardID: "tower", team: .red, x: 3.2, y: 30, hp: 0, maxHP: 2600, tower: true, awake: true),
            BattleEntity(id: 5, cardID: "tower", team: .red, x: 14.8, y: 30, hp: 2600, maxHP: 2600, tower: true, awake: true),
            BattleEntity(id: 6, cardID: "tower", team: .red, x: 9, y: 31.3, hp: 4200, maxHP: 4200, tower: true, king: true),
            BattleEntity(id: 7, cardID: runner.id, team: .blue, x: 3.2, y: 21.5, hp: runner.hp, maxHP: runner.hp)
        ]
        let model = BattleModel(deck: CardCatalog.starterDeck, seed: 71, isPractice: true, practiceScenario: .standard, initialEntities: setup)
        for _ in 0..<15 { model.tick() }
        let troop = model.entities.first { $0.id == 7 }
        XCTAssertNotNil(troop)
        XCTAssertGreaterThan(troop?.x ?? 3.2, 3.25, "Troops must turn toward the King Tower after their lane Princess Tower falls")
        XCTAssertTrue(model.events.contains { $0.style == "tower-destroyed" })
    }

    func testTroopsChaseVisibleEnemyUnitsViaBridge() {
        let runner = CardCatalog.all.first { $0.kind == .troop && $0.speed > 0 && !$0.behavior.contains(.buildingTarget) }!
        let enemy = CardCatalog.all.first { $0.kind == .troop && $0.speed > 0 && !$0.behavior.contains(.buildingTarget) && $0.id != runner.id }!
        let setup = [
            BattleEntity(id: 1, cardID: "tower", team: .blue, x: 3.2, y: 2, hp: 2600, maxHP: 2600, tower: true, awake: true),
            BattleEntity(id: 2, cardID: "tower", team: .blue, x: 14.8, y: 2, hp: 2600, maxHP: 2600, tower: true, awake: true),
            BattleEntity(id: 3, cardID: "tower", team: .blue, x: 9, y: 0.7, hp: 4200, maxHP: 4200, tower: true, king: true),
            BattleEntity(id: 4, cardID: "tower", team: .red, x: 3.2, y: 30, hp: 2600, maxHP: 2600, tower: true, awake: true),
            BattleEntity(id: 5, cardID: "tower", team: .red, x: 14.8, y: 30, hp: 2600, maxHP: 2600, tower: true, awake: true),
            BattleEntity(id: 6, cardID: "tower", team: .red, x: 9, y: 31.3, hp: 4200, maxHP: 4200, tower: true, king: true),
            BattleEntity(id: 7, cardID: runner.id, team: .blue, x: 3.2, y: 14.2, hp: runner.hp, maxHP: runner.hp),
            BattleEntity(id: 8, cardID: enemy.id, team: .red, x: 3.2, y: 19.0, hp: enemy.hp, maxHP: enemy.hp, stunClock: 8)
        ]
        let model = BattleModel(deck: CardCatalog.starterDeck, seed: 72, isPractice: true, practiceScenario: .standard, initialEntities: setup)
        for _ in 0..<45 { model.tick() }
        let troop = model.entities.first { $0.id == 7 }
        XCTAssertNotNil(troop)
        XCTAssertGreaterThan(troop?.y ?? 14.2, 14.5, "Troops must pursue a visible enemy rather than drift toward a fixed tower point")
    }

    func testCombatTickKeepsEntitiesFinite() {
        let model = BattleModel(deck: CardCatalog.starterDeck, seed: 99, automatedBlue: true)
        for _ in 0..<1200 where !model.isFinished { model.tick() }
        XCTAssertTrue(model.entities.allSatisfy {
            $0.x.isFinite && $0.y.isFinite && $0.hp.isFinite &&
            $0.x >= 0 && $0.x <= 18 && $0.y >= 0 && $0.y <= 32
        })
    }
}
