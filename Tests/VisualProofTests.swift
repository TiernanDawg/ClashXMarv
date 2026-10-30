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
        label.fontSize = 5.0
        label.fontColor = .white.withAlphaComponent(0.92)
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: x, y: y)
        label.zPosition = 1000
        scene.addChild(label)
    }

    private func contactSheet(team: Team) -> UIImage {
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
            let x = 1.7 + Double(column) * 2.3
            let y = 1.6 + Double(row) * 2.25
            scene.proofAddCardSprite(card, team: team, x: x, y: y)
            addName(card.name, x: CGFloat(x) * (boardSize.width / 18),
                    y: CGFloat(y) * (boardSize.height / 32) - 22, to: scene)
        }
        return snapshot(view, scene)
    }

    private func downsampleToOneX(_ image: UIImage) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: boardSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: boardSize))
        }
    }

    private func renderedCardAudit() -> (masks: [[Bool]], palettes: [(CGFloat, CGFloat, CGFloat)]) {
        let columns = 9
        let cellWidth = 42
        let cellHeight = 66
        let canvas = CGSize(width: columns * cellWidth, height: 10 * cellHeight)
        let scene = SKScene(size: canvas)
        scene.backgroundColor = .white
        let view = SKView(frame: CGRect(origin: .zero, size: canvas))
        view.contentScaleFactor = 1
        view.ignoresSiblingOrder = true
        view.presentScene(scene)

        for (index, card) in CardCatalog.all.enumerated() {
            let row = index / columns
            let column = index % columns
            let sprite = CardSpriteFactory.make(card: card, team: .blue,
                size: CGSize(width: boardSize.width / 18 * 1.15,
                             height: boardSize.height / 32 * 1.65))
            func flatten(_ node: SKNode) {
                if let shape = node as? SKShapeNode {
                    shape.fillColor = .black
                    shape.strokeColor = .black
                    shape.glowWidth = 0
                }
                for child in node.children { flatten(child) }
            }
            flatten(sprite)
            sprite.position = CGPoint(x: CGFloat(column * cellWidth + cellWidth / 2),
                                      y: canvas.height - CGFloat(row * cellHeight + cellHeight / 2))
            scene.addChild(sprite)
        }
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        guard let texture = view.texture(from: scene) else {
            XCTFail("SpriteKit could not render the 91-card silhouette audit")
            return ([], [])
        }
        let image = texture.cgImage()
        let width = image.width, height = image.height
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 255, count: height * bytesPerRow)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        pixels.withUnsafeMutableBytes { buffer in
            if let context = CGContext(data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
                context.setFillColor(UIColor.white.cgColor)
                context.fill(CGRect(x: 0, y: 0, width: width, height: height))
                context.interpolationQuality = .none
                context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            }
        }

        var masks: [[Bool]] = []
        var palettes: [(CGFloat, CGFloat, CGFloat)] = []
        for index in CardCatalog.all.indices {
            let row = index / columns, column = index % columns
            var mask: [Bool] = []
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, count: CGFloat = 0
            for y in (row * cellHeight)..<min(height, (row + 1) * cellHeight) {
                for x in (column * cellWidth)..<min(width, (column + 1) * cellWidth) {
                    let offset = y * bytesPerRow + x * 4
                    let r = CGFloat(pixels[offset]) / 255
                    let g = CGFloat(pixels[offset + 1]) / 255
                    let b = CGFloat(pixels[offset + 2]) / 255
                    let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
                    mask.append(luminance < 0.35)
                    if luminance > 0.18 && luminance < 0.94 {
                        red += r; green += g; blue += b; count += 1
                    }
                }
            }
            masks.append(mask)
            palettes.append(count > 0 ? (red / count, green / count, blue / count) : (0, 0, 0))
        }
        return (masks, palettes)
    }

    func testEveryCardHasDistinctReadableSilhouetteAndPalette() {
        XCTAssertEqual(CardCatalog.all.count, 91)
        let audit = renderedCardAudit()
        XCTAssertEqual(audit.masks.count, 91)
        for first in 0..<audit.masks.count {
            for second in (first + 1)..<audit.masks.count {
                let a = audit.masks[first], b = audit.masks[second]
                let intersection = zip(a, b).filter { $0 && $1 }.count
                let union = zip(a, b).filter { $0 || $1 }.count
                let silhouetteSimilarity = union == 0 ? 1.0 : Double(intersection) / Double(union)
                let p = audit.palettes[first], q = audit.palettes[second]
                let paletteDistance = sqrt(pow(Double(p.0 - q.0), 2) +
                                           pow(Double(p.1 - q.1), 2) +
                                           pow(Double(p.2 - q.2), 2))
                XCTAssertLessThan(silhouetteSimilarity, 0.965,
                    "Cards \(CardCatalog.all[first].name) and \(CardCatalog.all[second].name) have near-identical in-game silhouettes (IoU \(silhouetteSimilarity))")
                if paletteDistance < 0.055 {
                    XCTAssertLessThan(silhouetteSimilarity, 0.88,
                        "Cards \(CardCatalog.all[first].name) and \(CardCatalog.all[second].name) share both palette and silhouette")
                }
            }
        }
    }

    func testEveryCardHasItsRequiredAnimationCoverage() {
        XCTAssertEqual(CardCatalog.all.count, 91)
        for (index, card) in CardCatalog.all.enumerated() {
            let scene = ArenaScene(size: boardSize)
            scene.scaleMode = .resizeFill
            scene.reduceMotion = false
            let view = SKView(frame: CGRect(origin: .zero, size: boardSize))
            view.presentScene(scene)
            RunLoop.main.run(until: Date().addingTimeInterval(0.015))
            let nodeID = 50_000 + index
            let node = scene.proofCreateAnimationNode(card, team: .blue, id: nodeID)
            XCTAssertNotNil(node.action(forKey: "deploy-pop"), "\(card.name): deploy pop missing")
            let body = node.childNode(withName: "//body")
            XCTAssertNotNil(body?.action(forKey: "idle-bob"), "\(card.name): idle animation missing")
            scene.proofTriggerWalk(node)
            if card.kind != .spell {
                XCTAssertNotNil(node.childNode(withName: "//leg-left")?.action(forKey: "walk-cycle"),
                                "\(card.name): walk cycle missing")
            }
            scene.proofTriggerAttack(node, sourceID: nodeID)
            XCTAssertNotNil(body?.action(forKey: "attack-pulse"), "\(card.name): windup/strike/recovery missing")
            scene.proofTriggerHit(node)
            XCTAssertNotNil(node.childNode(withName: "//hit-flash")?.action(forKey: "hit-flash"),
                             "\(card.name): hit flash missing")
            scene.proofTriggerDeath(node)
            XCTAssertNotNil(node.action(forKey: "unit-death"), "\(card.name): death animation missing")

            if card.kind == .spell {
                scene.proofAddSpell(style: "spell-telegraph", x: 8, y: 12, radius: 2.5)
                scene.proofAddSpell(style: "spell-impact", x: 8, y: 12, radius: 2.5)
                XCTAssertTrue(scene.proofHasSpellImpactShake,
                              "\(card.name): spell impact screen shake missing")
            } else if card.behavior.contains(.ranged) || card.range > 1.2 {
                let previous = scene.proofProjectileEffectCount
                scene.proofAddAttack(style: "projectile", sourceID: nodeID,
                                     from: CGPoint(x: 8, y: 12), to: CGPoint(x: 10, y: 14))
                XCTAssertGreaterThan(scene.proofProjectileEffectCount, previous,
                              "\(card.name): ranged projectile missing")
            } else {
                let previous = scene.proofMeleeSwingCount
                scene.proofAddAttack(style: "melee", sourceID: nodeID,
                                     from: CGPoint(x: 8, y: 12), to: CGPoint(x: 9, y: 12))
                XCTAssertGreaterThan(scene.proofMeleeSwingCount, previous,
                              "\(card.name): melee swing/lunge missing")
            }
        }
    }

    func testGenerateEveryCardBlueAndRedContactSheets() {
        let blue = contactSheet(team: .blue)
        attach(blue, name: "Card-Contact-Sheet-3x-Blue.png")
        attach(downsampleToOneX(blue), name: "Card-Contact-Sheet-In-Game-Scale-Blue.png")
        let red = contactSheet(team: .red)
        attach(red, name: "Card-Contact-Sheet-3x-Red.png")
        attach(downsampleToOneX(red), name: "Card-Contact-Sheet-In-Game-Scale-Red.png")
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
        let destructionFrame = snapshot(destroyView, destroyScene)
        attach(destructionFrame, name: "Arena-Tower-Destruction-Explosion.png")
        let tile = boardSize.width / 18
        attach(crop(destructionFrame, sceneRect: CGRect(x: 0, y: tile * 24, width: tile * 8, height: tile * 8)),
               name: "Arena-Tower-Destruction-Closeup.png")

        let (crownView, crownScene, _) = makeArena(removeRedPrincess: true)
        crownScene.proofAddCrownTracker(blue: 1, red: 0)
        attach(snapshot(crownView, crownScene), name: "Arena-Crown-Tracker-After-Princess-Falls.png")
    }

    private func crop(_ image: UIImage, sceneRect: CGRect) -> UIImage {
        guard let cg = image.cgImage else { return image }
        let scale = image.scale
        let cropRect = CGRect(x: sceneRect.minX * scale,
                              y: (boardSize.height - sceneRect.maxY) * scale,
                              width: sceneRect.width * scale,
                              height: sceneRect.height * scale).integral
        guard let cropped = cg.cropping(to: cropRect) else { return image }
        return UIImage(cgImage: cropped, scale: scale, orientation: .up)
    }

    private func frameStrip(kind: String) -> UIImage {
        let (view, scene, _) = makeArena()
        let tower = kind == "tower"
        let sourceID = tower ? 1 : (kind == "melee" ? 7 : 8)
        let from = tower ? CGPoint(x: 3.2, y: 2) :
            (kind == "melee" ? CGPoint(x: 5.0, y: 10.2) : CGPoint(x: 4.3, y: 12.0))
        let to = tower ? CGPoint(x: 5.0, y: 10.2) : CGPoint(x: 6.0, y: 13.2)
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
                                 sourceID: sourceID, from: from, to: to)
            RunLoop.main.run(until: Date().addingTimeInterval(0.10))
            frames.append(snapshot(view, scene))
            RunLoop.main.run(until: Date().addingTimeInterval(0.22))
            frames.append(snapshot(view, scene))
        }
        let tile = boardSize.width / 18
        let regionTiles: CGRect
        switch kind {
        case "melee": regionTiles = CGRect(x: 3, y: 8, width: 6, height: 7)
        case "ranged": regionTiles = CGRect(x: 2, y: 9, width: 6, height: 7)
        case "tower": regionTiles = CGRect(x: 0, y: 0, width: 8, height: 15)
        default: regionTiles = CGRect(x: 4, y: 9, width: 8, height: 8)
        }
        let sceneRect = CGRect(x: regionTiles.minX * tile, y: regionTiles.minY * tile,
                               width: regionTiles.width * tile, height: regionTiles.height * tile)
        let croppedFrames = frames.map { crop($0, sceneRect: sceneRect) }
        let frameSize = croppedFrames[0].size
        let stripSize = CGSize(width: frameSize.width * 3, height: frameSize.height)
        let stripFormat = UIGraphicsImageRendererFormat()
        stripFormat.scale = 1
        return UIGraphicsImageRenderer(size: stripSize, format: stripFormat).image { _ in
            for (index, frame) in croppedFrames.enumerated() {
                frame.draw(in: CGRect(x: CGFloat(index) * frameSize.width, y: 0,
                                      width: frameSize.width, height: frameSize.height))
                let title = ["WINDUP", "STRIKE", "RECOVERY"][index] as NSString
                title.draw(at: CGPoint(x: CGFloat(index) * frameSize.width + 8, y: 6),
                           withAttributes: [.font: UIFont.boldSystemFont(ofSize: 12),
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
