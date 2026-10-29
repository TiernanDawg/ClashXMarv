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
        let report = BattleSelfTest.run(matches: 10, startingAt: start)
        XCTAssertEqual(report.matches, 10)
        XCTAssertGreaterThan(report.totalTicks, 0)
        XCTAssertGreaterThan(report.maxEntities, 0)
    }

    func testSimulationBatch000() { runBatch(0) }
    func testSimulationBatch001() { runBatch(10) }
    func testSimulationBatch002() { runBatch(20) }
    func testSimulationBatch003() { runBatch(30) }
    func testSimulationBatch004() { runBatch(40) }
    func testSimulationBatch005() { runBatch(50) }
    func testSimulationBatch006() { runBatch(60) }
    func testSimulationBatch007() { runBatch(70) }
    func testSimulationBatch008() { runBatch(80) }
    func testSimulationBatch009() { runBatch(90) }
    func testSimulationBatch010() { runBatch(100) }
    func testSimulationBatch011() { runBatch(110) }
    func testSimulationBatch012() { runBatch(120) }
    func testSimulationBatch013() { runBatch(130) }
    func testSimulationBatch014() { runBatch(140) }
    func testSimulationBatch015() { runBatch(150) }
    func testSimulationBatch016() { runBatch(160) }
    func testSimulationBatch017() { runBatch(170) }
    func testSimulationBatch018() { runBatch(180) }
    func testSimulationBatch019() { runBatch(190) }
    func testSimulationBatch020() { runBatch(200) }
    func testSimulationBatch021() { runBatch(210) }
    func testSimulationBatch022() { runBatch(220) }
    func testSimulationBatch023() { runBatch(230) }
    func testSimulationBatch024() { runBatch(240) }
    func testSimulationBatch025() { runBatch(250) }
    func testSimulationBatch026() { runBatch(260) }
    func testSimulationBatch027() { runBatch(270) }
    func testSimulationBatch028() { runBatch(280) }
    func testSimulationBatch029() { runBatch(290) }
    func testSimulationBatch030() { runBatch(300) }
    func testSimulationBatch031() { runBatch(310) }
    func testSimulationBatch032() { runBatch(320) }
    func testSimulationBatch033() { runBatch(330) }
    func testSimulationBatch034() { runBatch(340) }
    func testSimulationBatch035() { runBatch(350) }
    func testSimulationBatch036() { runBatch(360) }
    func testSimulationBatch037() { runBatch(370) }
    func testSimulationBatch038() { runBatch(380) }
    func testSimulationBatch039() { runBatch(390) }
    func testSimulationBatch040() { runBatch(400) }
    func testSimulationBatch041() { runBatch(410) }
    func testSimulationBatch042() { runBatch(420) }
    func testSimulationBatch043() { runBatch(430) }
    func testSimulationBatch044() { runBatch(440) }
    func testSimulationBatch045() { runBatch(450) }
    func testSimulationBatch046() { runBatch(460) }
    func testSimulationBatch047() { runBatch(470) }
    func testSimulationBatch048() { runBatch(480) }
    func testSimulationBatch049() { runBatch(490) }
    func testSimulationBatch050() { runBatch(500) }
    func testSimulationBatch051() { runBatch(510) }
    func testSimulationBatch052() { runBatch(520) }
    func testSimulationBatch053() { runBatch(530) }
    func testSimulationBatch054() { runBatch(540) }
    func testSimulationBatch055() { runBatch(550) }
    func testSimulationBatch056() { runBatch(560) }
    func testSimulationBatch057() { runBatch(570) }
    func testSimulationBatch058() { runBatch(580) }
    func testSimulationBatch059() { runBatch(590) }
    func testSimulationBatch060() { runBatch(600) }
    func testSimulationBatch061() { runBatch(610) }
    func testSimulationBatch062() { runBatch(620) }
    func testSimulationBatch063() { runBatch(630) }
    func testSimulationBatch064() { runBatch(640) }
    func testSimulationBatch065() { runBatch(650) }
    func testSimulationBatch066() { runBatch(660) }
    func testSimulationBatch067() { runBatch(670) }
    func testSimulationBatch068() { runBatch(680) }
    func testSimulationBatch069() { runBatch(690) }
    func testSimulationBatch070() { runBatch(700) }
    func testSimulationBatch071() { runBatch(710) }
    func testSimulationBatch072() { runBatch(720) }
    func testSimulationBatch073() { runBatch(730) }
    func testSimulationBatch074() { runBatch(740) }
    func testSimulationBatch075() { runBatch(750) }
    func testSimulationBatch076() { runBatch(760) }
    func testSimulationBatch077() { runBatch(770) }
    func testSimulationBatch078() { runBatch(780) }
    func testSimulationBatch079() { runBatch(790) }
    func testSimulationBatch080() { runBatch(800) }
    func testSimulationBatch081() { runBatch(810) }
    func testSimulationBatch082() { runBatch(820) }
    func testSimulationBatch083() { runBatch(830) }
    func testSimulationBatch084() { runBatch(840) }
    func testSimulationBatch085() { runBatch(850) }
    func testSimulationBatch086() { runBatch(860) }
    func testSimulationBatch087() { runBatch(870) }
    func testSimulationBatch088() { runBatch(880) }
    func testSimulationBatch089() { runBatch(890) }
    func testSimulationBatch090() { runBatch(900) }
    func testSimulationBatch091() { runBatch(910) }
    func testSimulationBatch092() { runBatch(920) }
    func testSimulationBatch093() { runBatch(930) }
    func testSimulationBatch094() { runBatch(940) }
    func testSimulationBatch095() { runBatch(950) }
    func testSimulationBatch096() { runBatch(960) }
    func testSimulationBatch097() { runBatch(970) }
    func testSimulationBatch098() { runBatch(980) }
    func testSimulationBatch099() { runBatch(990) }
}
