import XCTest
import SpriteKit
import UIKit
@testable import VanguardArena

@MainActor
final class VisualProofTests: XCTestCase {
    private let boardSize = CGSize(width: 378, height: 672)

    private func towerAndTroopSetup() -> [BattleEntity] {
        let knight = CardCatalog.all.first { $0.analog == "Knight" }!
        let archer = CardCatalog.all.first { $0.analog == "Archers" }!
        let giant = CardCatalog.all.first { $0.analog == "Giant" }!
        let wizard = CardCatalog.all.first { $0.analog == "Wizard" }!
        return [
            BattleEntity(id: 1, cardID: "tower", team: .blue, x: 3.2, y: 2, hp: 2600, maxHP: 2600, tower: true, awake: true),
            BattleEntity(id: 2, cardID: "tower", team: .blue, x: 14.8, y: 2, hp: 2600, maxHP: 2600, tower: true, awake: true),
            BattleEntity(id: 3, cardID: "tower", team: .blue, x: 9, y: 0.7, hp: 4200, maxHP: 4200, tower: true, king: true),
            BattleEntity(id: 4, cardID: "tower", team: .red, x: 3.2, y: 30, hp: 2600, maxHP: 2600, tower: true, awake: true),
            BattleEntity(id: 5, cardID: "tower", team: .red, x: 14.8, y: 30, hp: 2600, maxHP: 2600, tower: true, awake: true),
            BattleEntity(id: 6, cardID: "tower", team: .red, x: 9, y: 31.3, hp: 4200, maxHP: 4200, tower: true, king: true),
            BattleEntity(id: 7, cardID: knight.id, team: .blue, x: 5.0, y: 10.2, hp: 10000, maxHP: 10000),
            BattleEntity(id: 8, cardID: archer.id, team: .blue, x: 4.3, y: 12.0, hp: 10000, maxHP: 10000),
            BattleEntity(id: 9, cardID: giant.id, team: .red, x: 5.4, y: 14.2, hp: 10000, maxHP: 10000),
            BattleEntity(id: 10, cardID: wizard.id, team: .red, x: 13.2, y: 13.0, hp: 10000, maxHP: 10000),
            BattleEntity(id: 11, cardID: archer.id, team: .blue, x: 12.4, y: 10.0, hp: 10000, maxHP: 10000)
        ]
    }

    private func makeArena(removeRedPrincess: Bool = false) -> (SKView, ArenaScene, BattleModel) {
        var entities = towerAndTroopSetup()
        if removeRedPrincess { entities.removeAll { $0.id == 4 } }
        let model = BattleModel(deck: CardCatalog.starterDeck, seed: 77, isPractice: true,
                                practiceScenario: .standard, initialEntities: entities)
        let scene = ArenaScene(size: boardSize)
        scene.scaleMode = .resizeFill
        scene.reduceMotion = false
        let view = SKView(frame: CGRect(origin: .zero, size: boardSize))
        view.contentScaleFactor = 3
        view.ignoresSiblingOrder = true
        view.presentScene(scene)
        RunLoop.main.run(until: Date().addingTimeInterval(0.12))
        scene.battle = model
        scene.render(model)
        return (view, scene, model)
    }

    private func snapshot(_ view: SKView, _ scene: ArenaScene) -> UIImage {
        RunLoop.main.run(until: Date().addingTimeInterval(0.035))
        guard let texture = view.texture(from: scene) else {
            XCTFail("SpriteKit failed to render visual proof scene")
            return UIImage()
        }
        return UIImage(cgImage: texture.cgImage(), scale: 3, orientation: .up)
    }

    private func attach(_ image: UIImage, name: String) {
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func addName(_ name: String, x: CGFloat, y: CGFloat, to scene: ArenaScene) {
        let label = SKLabelNode(text: name)
        label.fontName = "AvenirNext-DemiBold"
        label.fontSize = 5.8
        label.fontColor = .white.withAlphaComponent(0.92)
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: x, y: y)
        label.zPosition = 1000
        scene.addChild(label)
    }

    func testGenerateEveryCardBlueAndRedContactSheets() {
        let scene = ArenaScene(size: boardSize)
        scene.scaleMode = .resizeFill
        scene.reduceMotion = true
        let view = SKView(frame: CGRect(origin: .zero, size: boardSize))
        view.contentScaleFactor = 3
        view.presentScene(scene)
        RunLoop.main.run(until: Date().addingTimeInterval(0.12))
        scene.proofPrepareContactSheet()

        for (index, card) in CardCatalog.all.enumerated() {
            let row = index / 7
            let column = index % 7
            let y = 1.75 + Double(row) * 2.20
            let blueX = 0.70 + Double(column) * 1.18
            let redX = 9.18 + Double(column) * 1.18
            scene.proofAddCardSprite(card, team: .blue, x: blueX, y: y)
            scene.proofAddCardSprite(card, team: .red, x: redX, y: y)
            addName(card.name, x: CGFloat(blueX) * (boardSize.width / 18),
                    y: CGFloat(y) * (boardSize.height / 32) - 18, to: scene)
            addName(card.name, x: CGFloat(redX) * (boardSize.width / 18),
                    y: CGFloat(y) * (boardSize.height / 32) - 18, to: scene)
        }

        let highResolution = snapshot(view, scene)
        attach(highResolution, name: "Card-Contact-Sheet-3x-Blue-and-Red.png")
        let oneXFormat = UIGraphicsImageRendererFormat()
        oneXFormat.scale = 1
        let oneX = UIGraphicsImageRenderer(size: boardSize, format: oneXFormat).image { _ in
            highResolution.draw(in: CGRect(origin: .zero, size: boardSize))
        }
        attach(oneX, name: "Card-Contact-Sheet-In-Game-Scale-Blue-and-Red.png")
        XCTAssertEqual(CardCatalog.all.count, 91, "Visual proof must cover the entire card catalog")
    }

    func testGenerateFivePracticeArenaScreenshots() {
        // Existing practice-mode BattleModel is used for every screenshot scenario.
        let (view, scene, model) = makeArena()
        for _ in 0..<18 { model.tick() }
        scene.render(model)
        attach(snapshot(view, scene), name: "Arena-Mid-Battle-Units-Fighting.png")

        scene.proofAddAttack(style: "projectile", sourceID: 1,
                             from: CGPoint(x: 3.2, y: 2), to: CGPoint(x: 5.0, y: 10.2))
        attach(snapshot(view, scene), name: "Arena-Tower-Firing-Projectile.png")

        scene.proofAddSpell(style: "spell-telegraph", x: 8.2, y: 13.2, radius: 3.0)
        scene.proofAddSpell(style: "spell-impact", x: 8.2, y: 13.2, radius: 3.0)
        attach(snapshot(view, scene), name: "Arena-Spell-Landing-Impact.png")

        let (destroyView, destroyScene, _) = makeArena()
        destroyScene.proofAddTowerDestruction(x: 3.2, y: 30, destroyedTeam: .red)
        attach(snapshot(destroyView, destroyScene), name: "Arena-Tower-Destruction-Explosion.png")

        let (crownView, crownScene, _) = makeArena(removeRedPrincess: true)
        crownScene.proofAddCrownTracker(blue: 1, red: 0)
        attach(snapshot(crownView, crownScene), name: "Arena-Crown-Tracker-After-Princess-Falls.png")
    }

    private func frameStrip(kind: String) -> UIImage {
        let (view, scene, _) = makeArena()
        let tower = kind == "tower"
        let sourceID = tower ? 1 : 7
        if kind == "spell" {
            scene.proofAddSpell(style: "spell-telegraph", x: 8.2, y: 13.2, radius: 3.0)
        } else {
            scene.proofBeginAttack(sourceID: sourceID)
        }
        var frames: [UIImage] = []
        if kind == "spell" {
            frames.append(snapshot(view, scene))
            RunLoop.main.run(until: Date().addingTimeInterval(0.13))
            scene.proofAddSpell(style: "spell-impact", x: 8.2, y: 13.2, radius: 3.0)
            frames.append(snapshot(view, scene))
            RunLoop.main.run(until: Date().addingTimeInterval(0.20))
            frames.append(snapshot(view, scene))
        } else {
            frames.append(snapshot(view, scene))
            scene.proofAddAttack(style: kind == "melee" ? "melee" : "projectile",
                                 sourceID: sourceID,
                                 from: tower ? CGPoint(x: 3.2, y: 2) : CGPoint(x: 5.0, y: 10.2),
                                 to: CGPoint(x: 6.0, y: 13.2))
            RunLoop.main.run(until: Date().addingTimeInterval(0.10))
            frames.append(snapshot(view, scene))
            RunLoop.main.run(until: Date().addingTimeInterval(0.22))
            frames.append(snapshot(view, scene))
        }
        let stripSize = CGSize(width: boardSize.width * 3, height: boardSize.height)
        let stripFormat = UIGraphicsImageRendererFormat()
        stripFormat.scale = 1
        return UIGraphicsImageRenderer(size: stripSize, format: stripFormat).image { context in
            for (index, frame) in frames.enumerated() {
                frame.draw(in: CGRect(x: CGFloat(index) * boardSize.width, y: 0,
                                      width: boardSize.width, height: boardSize.height))
                let title = ["WINDUP", "STRIKE", "RECOVERY"][index] as NSString
                title.draw(at: CGPoint(x: CGFloat(index) * boardSize.width + 12, y: 10),
                           withAttributes: [.font: UIFont.boldSystemFont(ofSize: 14),
                                            .foregroundColor: UIColor.white])
            }
        }
    }

    func testGenerateAttackAnimationFrameStrips() {
        for kind in ["melee", "ranged", "tower", "spell"] {
            attach(frameStrip(kind: kind), name: "Attack-Frame-Strip-\(kind.capitalized).png")
        }
    }
}
