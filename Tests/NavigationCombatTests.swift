import XCTest
@testable import VanguardArena

@MainActor
final class NavigationCombatTests: XCTestCase {
    private func towers() -> [BattleEntity] {
        [
            BattleEntity(id: 1, cardID: "tower", team: .blue, x: 3.2, y: 2, hp: 2600, maxHP: 2600, tower: true, awake: true),
            BattleEntity(id: 2, cardID: "tower", team: .blue, x: 14.8, y: 2, hp: 2600, maxHP: 2600, tower: true, awake: true),
            BattleEntity(id: 3, cardID: "tower", team: .blue, x: 9, y: 0.7, hp: 4200, maxHP: 4200, tower: true, king: true),
            BattleEntity(id: 4, cardID: "tower", team: .red, x: 3.2, y: 30, hp: 2600, maxHP: 2600, tower: true, awake: true),
            BattleEntity(id: 5, cardID: "tower", team: .red, x: 14.8, y: 30, hp: 2600, maxHP: 2600, tower: true, awake: true),
            BattleEntity(id: 6, cardID: "tower", team: .red, x: 9, y: 31.3, hp: 4200, maxHP: 4200, tower: true, king: true)
        ]
    }

    func testPrincessTowerFallRetargetsAllLaneTroops() {
        let troop = CardCatalog.all.first { $0.kind == .troop && $0.speed > 0 && !$0.behavior.contains(.buildingTarget) }!
        var setup = towers()
        setup[3].hp = 0
        setup += [
            BattleEntity(id: 7, cardID: troop.id, team: .blue, x: 3.2, y: 19, hp: 10000, maxHP: 10000),
            BattleEntity(id: 8, cardID: troop.id, team: .blue, x: 3.7, y: 19.3, hp: 10000, maxHP: 10000),
            BattleEntity(id: 10, cardID: troop.id, team: .blue, x: 2.7, y: 19.3, hp: 10000, maxHP: 10000),
            BattleEntity(id: 9, cardID: troop.id, team: .red, x: 3.2, y: 21, hp: 100000, maxHP: 100000, stunClock: 30)
        ]
        let model = BattleModel(deck: CardCatalog.starterDeck, seed: 201, isPractice: true, initialEntities: setup)
        for _ in 0..<8 { model.tick() }
        for id in [7, 8, 10] {
            XCTAssertEqual(model.debugLockedTargetID(for: id), 9, "Every troop in the lane must acquire the nearest enemy troop")
        }
        let units = [7, 8, 10].compactMap { id in model.entities.first { $0.id == id } }
        XCTAssertEqual(units.count, 3)
        XCTAssertGreaterThan(hypot(units[0].x - units[1].x, units[0].y - units[1].y), 0.15)
    }

    func testBuildingTargetTroopIgnoresEnemyTroops() {
        let winCondition = CardCatalog.all.first { $0.kind == .troop && $0.behavior.contains(.buildingTarget) }!
        let troop = CardCatalog.all.first { $0.kind == .troop && $0.speed > 0 && $0.id != winCondition.id }!
        let building = CardCatalog.all.first { $0.kind == .building }!
        var setup = towers()
        setup += [
            BattleEntity(id: 7, cardID: winCondition.id, team: .blue, x: 3.2, y: 8, hp: 10000, maxHP: 10000),
            BattleEntity(id: 8, cardID: building.id, team: .red, x: 3.2, y: 10.8, hp: 100000, maxHP: 100000, lifetime: 100),
            BattleEntity(id: 9, cardID: troop.id, team: .red, x: 3.2, y: 9.7, hp: 100000, maxHP: 100000, stunClock: 30)
        ]
        let model = BattleModel(deck: CardCatalog.starterDeck, seed: 202, isPractice: true, initialEntities: setup)
        for _ in 0..<3 { model.tick() }
        XCTAssertEqual(model.debugLockedTargetID(for: 7), 8)
    }

    func testGroundUsesBridgeAndFlyerCrossesAnywhere() {
        let route = ArenaNavigation.path(from: ArenaCell(x: 9, y: 10), to: ArenaCell(x: 9, y: 25))
        XCTAssertFalse(route.isEmpty)
        XCTAssertTrue(route.contains(where: ArenaNavigation.isBridge))
        XCTAssertTrue(route.filter { (15...16).contains($0.y) }.allSatisfy(ArenaNavigation.isBridge))

        let ground = CardCatalog.all.first { $0.kind == .troop && $0.speed > 0 && !$0.behavior.contains(.flying) && !$0.behavior.contains(.buildingTarget) }!
        let flyer = CardCatalog.all.first { $0.kind == .troop && $0.speed > 0 && $0.behavior.contains(.flying) }!
        var setup = towers()
        setup += [
            BattleEntity(id: 7, cardID: ground.id, team: .blue, x: 9, y: 14.2, hp: 10000, maxHP: 10000),
            BattleEntity(id: 8, cardID: flyer.id, team: .blue, x: 9, y: 14.2, hp: 10000, maxHP: 10000),
            BattleEntity(id: 9, cardID: ground.id, team: .red, x: 9, y: 19, hp: 100000, maxHP: 100000, stunClock: 30)
        ]
        let model = BattleModel(deck: CardCatalog.starterDeck, seed: 203, isPractice: true, initialEntities: setup)
        for _ in 0..<18 { model.tick() }
        let groundUnit = model.entities.first { $0.id == 7 }!
        let flyingUnit = model.entities.first { $0.id == 8 }!
        XCTAssertLessThanOrEqual(groundUnit.y, 15.1)
        XCTAssertGreaterThan(abs(groundUnit.x - 9), 0.15)
        XCTAssertGreaterThan(flyingUnit.y, 15.1)
        XCTAssertLessThan(abs(flyingUnit.x - 9), 0.25)
    }

    func testMassSeparationPushesLightUnitMoreThanHeavyUnit() {
        let light = CardCatalog.all.first { $0.analog == "Skeletons" }!
        let heavy = CardCatalog.all.first { $0.analog == "Giant" }!
        var setup = towers()
        setup += [
            BattleEntity(id: 7, cardID: light.id, team: .blue, x: 9, y: 10, hp: 100, maxHP: 100, stunClock: 2),
            BattleEntity(id: 8, cardID: heavy.id, team: .red, x: 9, y: 10, hp: 1000, maxHP: 1000, stunClock: 2)
        ]
        let model = BattleModel(deck: CardCatalog.starterDeck, seed: 204, isPractice: true, initialEntities: setup)
        model.tick()
        let a = model.entities.first { $0.id == 7 }!
        let b = model.entities.first { $0.id == 8 }!
        XCTAssertGreaterThan(hypot(a.x - b.x, a.y - b.y), 0.1)
        XCTAssertGreaterThan(abs(a.x - 9), abs(b.x - 9))
    }

    func testKingTowerActivatesOnDirectHitAndPrincessTowerFall() {
        let troop = CardCatalog.all.first { $0.kind == .troop && $0.speed > 0 && !$0.behavior.contains(.buildingTarget) }!
        var direct = towers()
        direct.append(BattleEntity(id: 7, cardID: troop.id, team: .red, x: 9, y: 1, hp: 10000, maxHP: 10000))
        let directModel = BattleModel(deck: CardCatalog.starterDeck, seed: 205, isPractice: true, initialEntities: direct)
        directModel.tick()
        XCTAssertTrue(directModel.entities.first { $0.id == 3 }?.awake == true)

        var fallen = towers()
        fallen[0].hp = 0
        let fallenModel = BattleModel(deck: CardCatalog.starterDeck, seed: 206, isPractice: true, initialEntities: fallen)
        fallenModel.tick()
        XCTAssertTrue(fallenModel.entities.first { $0.id == 3 }?.awake == true)
    }

    func testCrownCountingForPrincessAndKingTower() {
        var princess = towers()
        princess[3].hp = 0
        let princessModel = BattleModel(deck: CardCatalog.starterDeck, seed: 207, isPractice: true, initialEntities: princess)
        princessModel.tick()
        XCTAssertEqual(princessModel.blueCrowns, 1)

        var king = towers()
        king[5].hp = 0
        let kingModel = BattleModel(deck: CardCatalog.starterDeck, seed: 208, isPractice: true, initialEntities: king)
        kingModel.tick()
        XCTAssertEqual(kingModel.blueCrowns, 3)
        XCTAssertEqual(kingModel.result, "VICTORY")
    }

    func testAStarAvoidsRiverAndFreesDestroyedTowerCell() {
        let start = ArenaCell(x: 3, y: 10)
        let goal = ArenaCell(x: 3, y: 20)
        let occupied = ArenaCell(x: 3, y: 17)
        let whileAlive = ArenaNavigation.path(from: start, to: goal, blocked: [occupied])
        XCTAssertFalse(whileAlive.isEmpty)
        XCTAssertFalse(whileAlive.contains(occupied))
        XCTAssertTrue(whileAlive.contains(where: ArenaNavigation.isBridge))
        let afterDestruction = ArenaNavigation.path(from: start, to: goal)
        XCTAssertTrue(afterDestruction.contains(occupied))
    }

    func testTargetLockAndStuckRepath() {
        let troop = CardCatalog.all.first { $0.kind == .troop && $0.speed > 0 && !$0.behavior.contains(.buildingTarget) }!
        var lockSetup = towers()
        lockSetup += [
            BattleEntity(id: 7, cardID: troop.id, team: .blue, x: 3.2, y: 10, hp: 10000, maxHP: 10000),
            BattleEntity(id: 8, cardID: troop.id, team: .red, x: 3.2, y: 12, hp: 100000, maxHP: 100000, stunClock: 30),
            BattleEntity(id: 9, cardID: troop.id, team: .red, x: 3.2, y: 13.5, hp: 100000, maxHP: 100000, stunClock: 30)
        ]
        let lockModel = BattleModel(deck: CardCatalog.starterDeck, seed: 209, isPractice: true, initialEntities: lockSetup)
        for _ in 0..<30 { lockModel.tick() }
        XCTAssertEqual(lockModel.debugLockedTargetID(for: 7), 8)

        let building = CardCatalog.all.first { $0.kind == .building }!
        var stuckSetup = towers()
        stuckSetup.append(BattleEntity(id: 7, cardID: troop.id, team: .blue, x: 9.5, y: 9.5, hp: 10000, maxHP: 10000))
        var id = 20
        for y in 8...10 {
            for x in 8...10 where x != 9 || y != 9 {
                stuckSetup.append(BattleEntity(id: id, cardID: building.id, team: .blue,
                                               x: Double(x) + 0.5, y: Double(y) + 0.5,
                                               hp: 5000, maxHP: 5000, lifetime: 100))
                id += 1
            }
        }
        let stuckModel = BattleModel(deck: CardCatalog.starterDeck, seed: 210, isPractice: true, initialEntities: stuckSetup)
        for _ in 0..<12 { stuckModel.tick() }
        XCTAssertGreaterThanOrEqual(stuckModel.debugPathRepathCount(for: 7), 2)
    }
}
