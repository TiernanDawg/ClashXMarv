import SpriteKit
import UIKit

final class ArenaScene: SKScene {
    weak var battle: BattleModel?
    var showDamageNumbers = true
    var reduceMotion = false
    var highContrast = false
    var hapticsEnabled = true
    var themeIndex = 0
    var debugNavigation = false
    private var debugLayer: SKNode?
    private var renderedEventIDs = Set<UUID>()
    private var transientEffects: [SKNode] = []
    private var particlePool: [SKShapeNode] = []
    private var projectilePool: [SKShapeNode] = []
    private(set) var proofProjectileEffectCount = 0
    private(set) var proofMeleeSwingCount = 0
    var proofHasProjectileEffect: Bool { proofProjectileEffectCount > 0 }
    var proofHasMeleeSwing: Bool { proofMeleeSwingCount > 0 }
    var proofHasSpellImpactShake: Bool { arenaCamera?.action(forKey: "spell-impact-shake") != nil }
    private var lastHP: [Int: Double] = [:]
    private var lastTeams: [Int: Team] = [:]
    private var lastPositions: [Int: CGPoint] = [:]
    private var lastAttackClock: [Int: Double] = [:]
    private var thermalLimited = false
    private var arenaCamera: SKCameraNode?
    private var arenaPalette: (UIColor, UIColor, UIColor, UIColor) {
        let palettes: [(UIColor, UIColor, UIColor, UIColor)] = [
            (.systemGreen, UIColor(red: 0.17, green: 0.43, blue: 0.29, alpha: 1), UIColor(red: 0.42, green: 0.62, blue: 0.37, alpha: 1), .systemBlue),
            (.darkGray, UIColor(red: 0.24, green: 0.28, blue: 0.32, alpha: 1), .lightGray, .systemTeal),
            (.systemPurple, UIColor(red: 0.25, green: 0.15, blue: 0.38, alpha: 1), .systemPurple, .systemCyan),
            (.systemBlue, UIColor(red: 0.10, green: 0.25, blue: 0.42, alpha: 1), .systemCyan, .systemBlue),
            (.systemCyan, UIColor(red: 0.08, green: 0.28, blue: 0.34, alpha: 1), .systemTeal, .systemBlue),
            (.black, UIColor(red: 0.10, green: 0.11, blue: 0.16, alpha: 1), .darkGray, .systemIndigo),
            (.systemOrange, UIColor(red: 0.40, green: 0.22, blue: 0.10, alpha: 1), .systemOrange, .systemBlue),
            (.systemIndigo, UIColor(red: 0.16, green: 0.16, blue: 0.36, alpha: 1), .systemPurple, .systemCyan),
            (.systemRed, UIColor(red: 0.32, green: 0.10, blue: 0.13, alpha: 1), .systemRed, .systemBlue),
            (.systemTeal, UIColor(red: 0.08, green: 0.28, blue: 0.27, alpha: 1), .systemTeal, .systemBlue),
            (.systemYellow, UIColor(red: 0.35, green: 0.28, blue: 0.10, alpha: 1), .systemYellow, .systemBlue),
            (.systemPink, UIColor(red: 0.30, green: 0.12, blue: 0.28, alpha: 1), .systemPink, .systemCyan),
            (.systemPurple, UIColor(red: 0.24, green: 0.12, blue: 0.33, alpha: 1), .systemYellow, .systemCyan)
        ]
        return palettes[min(palettes.count - 1, max(0, themeIndex))]
    }
    private var entityNodes: [Int: SKNode] = [:]
    private var ghost: SKShapeNode?
    private var gridPreview: SKShapeNode?
    private var lastTile = CGPoint(x: -999, y: -999)
    private var tileWidth: CGFloat { max(1, size.width / 18) }
    private var tileHeight: CGFloat { max(1, size.height / 32) }
    var onDrop: ((Double, Double) -> Void)?

    override func didMove(to view: SKView) {
        let thermal = ProcessInfo.processInfo.thermalState
        view.preferredFramesPerSecond = (thermal == .serious || thermal == .critical) ? 60 : UIScreen.main.maximumFramesPerSecond
        thermalLimited = thermal == .serious || thermal == .critical
        backgroundColor = arenaPalette.0
        drawArena()
        installCamera()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        drawArena()
        installCamera()
        if let battle { render(battle) }
    }

    private func installCamera() {
        arenaCamera?.removeFromParent()
        let cameraNode = SKCameraNode()
        cameraNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(cameraNode)
        camera = cameraNode
        arenaCamera = cameraNode
    }
    private func drawArena() {
        ghost = nil
        gridPreview = nil
        removeAllChildren()
        transientEffects.removeAll()
        entityNodes.removeAll()
        lastHP.removeAll()
        lastTeams.removeAll()
        lastPositions.removeAll()
        lastAttackClock.removeAll()
        let field = SKShapeNode(rect: CGRect(x: 2, y: 2, width: size.width - 4, height: size.height - 4), cornerRadius: 12)
        field.fillColor = arenaPalette.1
        field.strokeColor = arenaPalette.2
        field.lineWidth = 2
        field.zPosition = -10
        addChild(field)

        for x in 0..<18 {
            for y in 0..<32 where (x + y) % 2 == 0 {
                let tile = SKShapeNode(rectOf: CGSize(width: tileWidth - 1, height: tileHeight - 1), cornerRadius: 1)
                tile.position = CGPoint(x: (CGFloat(x) + 0.5) * tileWidth, y: (CGFloat(y) + 0.5) * tileHeight)
                tile.fillColor = (x + y).isMultiple(of: 4)
                    ? UIColor(red: 0.42, green: 0.64, blue: 0.34, alpha: 0.42)
                    : UIColor(red: 0.30, green: 0.53, blue: 0.28, alpha: 0.38)
                tile.strokeColor = .clear
                tile.zPosition = -9
                addChild(tile)
            }
        }
        let river = SKShapeNode(rectOf: CGSize(width: size.width, height: tileHeight * 2))
        river.position = CGPoint(x: size.width / 2, y: size.height / 2)
        river.fillColor = arenaPalette.3
        river.strokeColor = .clear
        river.zPosition = -5
        addChild(river)

        for row in 0..<5 {
            let wavePath = CGMutablePath()
            wavePath.move(to: CGPoint(x: -tileWidth * 3, y: 0))
            for step in 0...12 {
                let x = -tileWidth * 3 + CGFloat(step) * tileWidth * 0.5
                wavePath.addLine(to: CGPoint(x: x, y: sin(CGFloat(step) * 0.8) * tileHeight * 0.12))
            }
            let wave = SKShapeNode(path: wavePath)
            wave.position = CGPoint(x: size.width * CGFloat(row % 2) * 0.5, y: size.height / 2 - tileHeight * 0.78 + CGFloat(row) * tileHeight * 0.38)
            wave.strokeColor = UIColor.white.withAlphaComponent(0.18)
            wave.lineWidth = 1.2
            wave.zPosition = -4
            addChild(wave)
            if !reduceMotion && !thermalLimited {
                wave.run(.repeatForever(.sequence([.moveBy(x: tileWidth * 0.9, y: 0, duration: 1.8), .moveBy(x: -tileWidth * 0.9, y: 0, duration: 1.8)])))
            }
        }
        for x in [3.2 * tileWidth, 14.8 * tileWidth] {
            let bridge = SKShapeNode(rectOf: CGSize(width: tileWidth * 2.3, height: tileHeight * 2.4), cornerRadius: 4)
            bridge.position = CGPoint(x: x, y: size.height / 2)
            bridge.fillColor = UIColor(red: 0.42, green: 0.27, blue: 0.16, alpha: 1)
            bridge.strokeColor = UIColor(red: 0.91, green: 0.70, blue: 0.40, alpha: 1)
            bridge.lineWidth = 2
            bridge.zPosition = -3
            addChild(bridge)
            for plank in 0..<5 {
                let seam = SKShapeNode(rectOf: CGSize(width: tileWidth * 2.1, height: 1))
                seam.position = CGPoint(x: x, y: size.height / 2 - tileHeight * 0.95 + CGFloat(plank) * tileHeight * 0.47)
                seam.fillColor = UIColor.black.withAlphaComponent(0.22)
                seam.strokeColor = .clear
                seam.zPosition = -2
                addChild(seam)
            }
            for side in [-1.0, 1.0] {
                let rail = SKShapeNode(rectOf: CGSize(width: tileWidth * 0.10, height: tileHeight * 2.55), cornerRadius: 2)
                rail.position = CGPoint(x: x + CGFloat(side) * tileWidth * 1.08, y: size.height / 2)
                rail.fillColor = UIColor(red: 0.73, green: 0.54, blue: 0.31, alpha: 1)
                rail.strokeColor = UIColor.black.withAlphaComponent(0.25)
                rail.zPosition = -1
                addChild(rail)
            }
        }
        for y in stride(from: tileHeight * 2, through: size.height - tileHeight * 2, by: tileHeight * 4) {
            let line = SKShapeNode(rectOf: CGSize(width: size.width - 12, height: 1))
            line.position = CGPoint(x: size.width / 2, y: y)
            line.fillColor = .white.withAlphaComponent(0.07)
            line.strokeColor = .clear
            line.zPosition = -2
            addChild(line)
        }
    }

    func render(_ model: BattleModel) {
        let activeEventIDs = Set(model.events.map(\.id))
        renderedEventIDs.formIntersection(activeEventIDs)
        let alive = Set(model.entities.map(\.id))
        for id in Array(entityNodes.keys) where !alive.contains(id) {
            if let node = entityNodes[id] {
                let point = lastPositions[id] ?? node.position
                let destroyed = model.events.contains {
                    $0.style == "tower-destroyed" &&
                    hypot($0.x * Double(tileWidth) - Double(point.x), $0.y * Double(tileHeight) - Double(point.y)) < Double(tileWidth)
                }
                if destroyed {
                    addRubble(at: point)
                    if !reduceMotion && !thermalLimited { addDebris(at: point) }
                    if reduceMotion || thermalLimited { node.removeFromParent() }
                    else {
                        node.run(.sequence([
                            .group([.scale(to: 0.12, duration: 0.34), .fadeOut(withDuration: 0.34), .rotate(byAngle: 0.42, duration: 0.34)]),
                            .removeFromParent()
                        ]), withKey: "collapse")
                    }
                } else if !reduceMotion && !thermalLimited {
                    addDeathPoof(at: point, team: lastTeams[id] ?? .blue)
                    // Troops/buildings receive a short readable death animation instead of vanishing.
                    node.run(.sequence([
                        .group([.scale(to: 0.18, duration: 0.24), .fadeOut(withDuration: 0.24),
                                .rotate(byAngle: 0.35, duration: 0.24)]),
                        .removeFromParent()
                    ]), withKey: "unit-death")
                } else { node.removeFromParent() }
            }
            entityNodes.removeValue(forKey: id)
            lastHP.removeValue(forKey: id)
            lastTeams.removeValue(forKey: id)
            lastPositions.removeValue(forKey: id)
            lastAttackClock.removeValue(forKey: id)
        }
        for entity in model.entities {
            let node: SKNode
            if let existing = entityNodes[entity.id] {
                node = existing
            } else {
                node = makeNode(entity)
                entityNodes[entity.id] = node
                addChild(node)
            }
            if let oldHP = lastHP[entity.id], entity.hp < oldHP {
                if !reduceMotion && !thermalLimited && oldHP - entity.hp >= 180 {
                    arenaCamera?.removeAction(forKey: "impact-shake")
                    arenaCamera?.run(.sequence([.moveBy(x: 2.5, y: 1.5, duration: 0.025), .moveBy(x: -5, y: -3, duration: 0.05), .moveBy(x: 2.5, y: 1.5, duration: 0.025)]), withKey: "impact-shake")
                }
                if oldHP - entity.hp >= 180 {
                    arenaCamera?.removeAction(forKey: "impact-shake")
                    arenaCamera?.run(.sequence([.moveBy(x: 2.5, y: 1.5, duration: 0.025), .moveBy(x: -5, y: -3, duration: 0.05), .moveBy(x: 2.5, y: 1.5, duration: 0.025)]), withKey: "impact-shake")
                }
                if !reduceMotion && !thermalLimited {
                    node.removeAction(forKey: "hit-squash")
                    node.run(.sequence([.scale(to: 1.12, duration: 0.055), .scale(to: 1.0, duration: 0.11)]), withKey: "hit-squash")
                }
                let flash = SKShapeNode(circleOfRadius: min(tileWidth, tileHeight) * 0.7)
                flash.name = "hit-flash"
                flash.fillColor = .white.withAlphaComponent(0.72)
                flash.strokeColor = .clear
                flash.zPosition = 3
                node.addChild(flash)
                flash.run(.sequence([.fadeOut(withDuration: 0.12), .removeFromParent()]))
            }
            lastHP[entity.id] = entity.hp
            lastTeams[entity.id] = entity.team
            let newPosition = CGPoint(x: CGFloat(entity.x) * tileWidth, y: CGFloat(entity.y) * tileHeight)
            if !reduceMotion && !thermalLimited,
               let oldPosition = lastPositions[entity.id],
               hypot(Double(newPosition.x - oldPosition.x), Double(newPosition.y - oldPosition.y)) > 0.12 {
                if let body = node.childNode(withName: "//body") {
                    body.removeAction(forKey: "walk-squash")
                    body.run(.sequence([.scaleX(to: 0.91, duration: 0.07), .scaleX(to: 1.05, duration: 0.08), .scaleX(to: 1.0, duration: 0.07)]), withKey: "walk-squash")
                }
                if let visual = node.childNode(withName: "visual") {
                    let directionScale: CGFloat = newPosition.x < oldPosition.x ? -1 : 1
                    visual.xScale = (entity.team == .red ? -1 : 1) * directionScale
                }
                for (name, sign) in [("leg-left", 1.0), ("leg-right", -1.0)] {
                    if let leg = node.childNode(withName: "//" + name) {
                        leg.removeAction(forKey: "walk-cycle")
                        leg.run(.sequence([
                            .repeat(.sequence([.rotate(byAngle: CGFloat(sign) * 0.36, duration: 0.08), .rotate(byAngle: CGFloat(-sign) * 0.36, duration: 0.08)]), count: 2),
                            .rotate(toAngle: 0, duration: 0.04)
                        ]), withKey: "walk-cycle")
                    }
                }
            }
            lastPositions[entity.id] = newPosition
            if !reduceMotion && !thermalLimited, let previous = lastAttackClock[entity.id], entity.attackClock - previous > 0.18, let body = node.childNode(withName: "body") as? SKShapeNode {
                body.removeAction(forKey: "attack-squash")
                body.run(.sequence([.scale(to: 1.18, duration: 0.055), .scale(to: 1.0, duration: 0.10)]), withKey: "attack-squash")
            }
            lastAttackClock[entity.id] = entity.attackClock
            if hypot(Double(node.position.x - newPosition.x), Double(node.position.y - newPosition.y)) > 0.01 {
                node.removeAction(forKey: "fixed-step-interpolation")
                node.run(.move(to: newPosition, duration: Balance.tick), withKey: "fixed-step-interpolation")
            }
            node.zPosition = CGFloat(entity.y)
            node.alpha = (CardCatalog.byID[entity.cardID]?.behavior.contains(.invisible) == true && !entity.hasAttacked) ? 0.28 : 1
            if let badge = node.childNode(withName: "hp") as? SKShapeNode {
                let ratio = max(0, min(1, entity.hp / max(1, entity.maxHP)))
                badge.xScale = ratio
                badge.fillColor = ratio > 0.5 ? .systemGreen : (ratio > 0.25 ? .systemYellow : .systemRed)
                if entity.tower && ratio <= 0.25 {
                    if node.childNode(withName: "tower-damage-fx") == nil {
                        let fx = SKNode(); fx.name = "tower-damage-fx"; fx.zPosition = 18
                        for index in 0..<4 {
                            let smoke = SKShapeNode(circleOfRadius: max(2, tileWidth * 0.09))
                            smoke.position = CGPoint(x: CGFloat(index - 2) * tileWidth * 0.16, y: tileHeight * (0.72 + CGFloat(index % 2) * 0.10))
                            smoke.fillColor = UIColor(white: 0.24, alpha: 0.75); smoke.strokeColor = .clear
                            fx.addChild(smoke)
                            smoke.run(.repeatForever(.sequence([
                                .group([.moveBy(x: CGFloat(index - 2) * tileWidth * 0.10, y: tileHeight * 0.42, duration: 0.65),
                                        .scale(to: 1.9, duration: 0.65), .fadeOut(withDuration: 0.65)]),
                                .run { [weak self, weak smoke] in
                                    guard let self, let smoke else { return }
                                    smoke.position.y = self.tileHeight * 0.72
                                    smoke.alpha = 0.72
                                    smoke.setScale(0.65)
                                }
                            ])))
                        }
                        if ratio <= 0.12 {
                            let flame = SKShapeNode(path: {
                                let p = CGMutablePath(); p.move(to: CGPoint(x: -tileWidth*0.13,y:0))
                                p.addQuadCurve(to: CGPoint(x: tileWidth*0.13,y:0), control: CGPoint(x: 0,y: tileHeight*0.56))
                                p.addQuadCurve(to: CGPoint(x: -tileWidth*0.13,y:0), control: CGPoint(x: 0,y: tileHeight*0.22))
                                return p
                            }())
                            flame.position = CGPoint(x: tileWidth * 0.24, y: tileHeight * 0.56)
                            flame.fillColor = .systemOrange; flame.strokeColor = .systemYellow; flame.lineWidth = 1
                            fx.addChild(flame)
                            flame.run(.repeatForever(.sequence([.scale(to: 1.18, duration: 0.12), .scale(to: 0.88, duration: 0.12)])))
                        }
                        node.addChild(fx)
                    }
                } else {
                    node.childNode(withName: "tower-damage-fx")?.removeFromParent()
                }
            }
            if let body = node.childNode(withName: "//body") {
                if entity.tower {
                    body.fillColor = entity.king ? .systemYellow : (entity.team == .blue ? .systemTeal : .systemPink)
                } else if highContrast {
                    body.fillColor = entity.team == .blue ? UIColor.systemCyan : UIColor.systemOrange
                }
            }
        }
        // Tower lock indicators stay attached to the actual target and are reused.
        var activeLockTargets = Set<Int>()
        for lock in model.towerTargetLocks() {
            guard let targetNode = entityNodes[lock.targetID] else { continue }
            activeLockTargets.insert(lock.targetID)
            if targetNode.childNode(withName: "target-lock") == nil {
                let ring = SKShapeNode(circleOfRadius: tileWidth * 0.72)
                ring.name = "target-lock"; ring.fillColor = .clear
                ring.strokeColor = (lock.team == .blue ? UIColor.systemBlue : UIColor.systemRed).withAlphaComponent(0.98)
                ring.lineWidth = 1.8; ring.glowWidth = 2; ring.zPosition = 30
                targetNode.addChild(ring)
                ring.run(.repeatForever(.sequence([.scale(to: 1.14, duration: 0.32), .scale(to: 0.92, duration: 0.32)])))
            }
        }
        for (id, node) in entityNodes where !activeLockTargets.contains(id) {
            node.childNode(withName: "target-lock")?.removeFromParent()
        }
        for event in model.events {
            guard model.elapsed - event.born < (event.style == "tower-destroyed" ? 1.25 : 0.4),
                  showDamageNumbers || !event.text.hasPrefix("−"),
                  renderedEventIDs.insert(event.id).inserted else { continue }
            let name = "event-\(event.id)"
            if childNode(withName: name) == nil {
                if let style = event.style, ["melee", "projectile", "beam"].contains(style) {
                    addAttackEffect(event, style: style)
                }
                if event.style == "tower-destroyed" { addTowerDestructionEffect(event) }
                if let style = event.style, style == "spell-telegraph" || style == "spell-impact" {
                    addSpellEffect(event, style: style)
                }
                if event.style != "melee" && event.style != "projectile" && event.style != "beam" &&
                    event.style != "spell-telegraph" && event.style != "spell-impact" {
                    let label = SKLabelNode(text: event.text)
                    label.name = name
                    label.fontName = "AvenirNext-Heavy"
                    label.fontSize = event.style == "tower-destroyed" ? max(12, min(17, tileWidth * 0.78)) : max(8, min(12, tileWidth * 0.55))
                    label.fontColor = event.style == "tower-destroyed"
                        ? (event.team == .blue ? UIColor.systemRed : UIColor.systemBlue) : .white
                    if event.style == "tower-destroyed" { label.text = "TOWER DESTROYED" }
                    label.position = CGPoint(x: CGFloat(event.x) * tileWidth, y: CGFloat(event.y) * tileHeight + tileHeight)
                    label.zPosition = 1000
                    addChild(label)
                    if event.style == "tower-destroyed" {
                        label.run(.sequence([.scale(to: 1.35, duration: 0.12), .scale(to: 1.0, duration: 0.12)]))
                    }
                    if reduceMotion { label.run(.sequence([.wait(forDuration: 0.25), .removeFromParent()])) }
                    else {
                        label.setScale(0.72)
                        label.run(.sequence([.group([.moveBy(x: 0, y: tileHeight * 1.15, duration: 0.65),
                                                    .scale(to: 1.0, duration: 0.12), .fadeOut(withDuration: 0.65)]),
                                             .removeFromParent()]))
                    }
                }
            }
        }
        if debugNavigation { drawDebugOverlay(model) }
        else { debugLayer?.removeFromParent(); debugLayer = nil }
        if model.selectedCard != nil {
            if ghost == nil {
                let node = SKShapeNode(circleOfRadius: min(tileWidth, tileHeight) * 0.75)
                node.zPosition = 500
                ghost = node
                addChild(node)
            }
            ghost?.isHidden = false
        } else {
            ghost?.isHidden = true
            gridPreview?.isHidden = true
        }
    }

    private func acquireParticle(radius: CGFloat, color: UIColor, z: CGFloat) -> SKShapeNode {
        let node = particlePool.popLast() ?? SKShapeNode()
        let path = CGMutablePath()
        path.addEllipse(in: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2))
        node.path = path
        node.fillColor = color; node.strokeColor = .clear; node.lineWidth = 0
        node.alpha = 1; node.setScale(1); node.zPosition = z
        node.removeAllActions()
        return node
    }

    private func recycleParticle(_ node: SKShapeNode) {
        node.removeFromParent(); node.removeAllActions()
        node.alpha = 1; node.setScale(1)
        if particlePool.count < 64 { particlePool.append(node) }
    }

    private func emitParticle(at point: CGPoint, radius: CGFloat, color: UIColor, z: CGFloat,
                              dx: CGFloat, dy: CGFloat, duration: TimeInterval,
                              finalScale: CGFloat = 1.7) {
        let particle = acquireParticle(radius: radius, color: color, z: z)
        particle.position = point
        addTransientEffect(particle)
        particle.run(.sequence([
            .group([.moveBy(x: dx, y: dy, duration: duration),
                    .scale(to: finalScale, duration: duration),
                    .fadeOut(withDuration: duration)]),
            .run { [weak self, weak particle] in
                guard let self, let particle else { return }
                self.recycleParticle(particle)
            }
        ]))
    }

    private func acquireProjectile(color: UIColor) -> SKShapeNode {
        let bolt = projectilePool.popLast() ?? SKShapeNode()
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: tileWidth * 0.20))
        path.addLine(to: CGPoint(x: tileWidth * 0.11, y: -tileWidth * 0.10))
        path.addLine(to: CGPoint(x: 0, y: -tileWidth * 0.20))
        path.addLine(to: CGPoint(x: -tileWidth * 0.11, y: -tileWidth * 0.10))
        path.closeSubpath()
        bolt.path = path; bolt.fillColor = color; bolt.strokeColor = .white
        bolt.lineWidth = 1; bolt.glowWidth = 4; bolt.alpha = 1
        bolt.removeAllActions(); bolt.setScale(1)
        return bolt
    }

    private func recycleProjectile(_ node: SKShapeNode) {
        node.removeFromParent(); node.removeAllActions()
        node.alpha = 1; node.setScale(1)
        if projectilePool.count < 16 { projectilePool.append(node) }
    }

    /// Keep short-lived particles/projectiles bounded so busy fights cannot grow the scene graph.
    private func addTransientEffect(_ node: SKNode) {
        transientEffects.removeAll { $0.parent == nil }
        if transientEffects.count >= 80 {
            let oldest = transientEffects.removeFirst()
            oldest.removeAllActions()
            oldest.removeFromParent()
        }
        node.name = "transient-effect"
        addChild(node)
        transientEffects.append(node)
    }

    private func addTowerDestructionEffect(_ event: BattleEvent) {
        let point = CGPoint(x: CGFloat(event.x) * tileWidth, y: CGFloat(event.y) * tileHeight)
        let winnerColor: UIColor = event.team == .blue ? .systemRed : .systemBlue
        let flash = SKShapeNode(circleOfRadius: tileWidth * 0.55)
        flash.position = point; flash.fillColor = .white.withAlphaComponent(0.85)
        flash.strokeColor = winnerColor; flash.lineWidth = 3; flash.glowWidth = 9; flash.zPosition = 960
        addTransientEffect(flash)
        flash.run(.sequence([.group([.scale(to: 4.2, duration: 0.34), .fadeOut(withDuration: 0.34)]), .removeFromParent()]))
        for index in 0..<12 {
            let angle = CGFloat(index) * (.pi * 2 / 12)
            emitParticle(at: point, radius: tileWidth * 0.09,
                         color: index.isMultiple(of: 2) ? .systemYellow : winnerColor,
                         z: 965, dx: cos(angle) * tileWidth * 1.65,
                         dy: sin(angle) * tileHeight * 1.65, duration: 0.42, finalScale: 1.3)
        }
        for index in 0..<5 {
            emitParticle(at: point, radius: tileWidth * (0.15 + CGFloat(index) * 0.025),
                         color: UIColor(white: 0.22, alpha: 0.48), z: 955,
                         dx: CGFloat(index - 2) * tileWidth * 0.26,
                         dy: tileHeight * CGFloat(1 + index % 2), duration: 0.55, finalScale: 2.4)
        }
        let crownPath = CGMutablePath()
        crownPath.move(to: CGPoint(x: -tileWidth*0.32, y: -tileHeight*0.18))
        crownPath.addLine(to: CGPoint(x: -tileWidth*0.27, y: tileHeight*0.22))
        crownPath.addLine(to: CGPoint(x: -tileWidth*0.08, y: tileHeight*0.03))
        crownPath.addLine(to: CGPoint(x: 0, y: tileHeight*0.30))
        crownPath.addLine(to: CGPoint(x: tileWidth*0.10, y: tileHeight*0.03))
        crownPath.addLine(to: CGPoint(x: tileWidth*0.29, y: tileHeight*0.22))
        crownPath.addLine(to: CGPoint(x: tileWidth*0.34, y: -tileHeight*0.18))
        crownPath.closeSubpath()
        let crown = SKShapeNode(path: crownPath)
        crown.position = point; crown.fillColor = .systemYellow; crown.strokeColor = winnerColor
        crown.lineWidth = 1.6; crown.glowWidth = 3; crown.zPosition = 980
        addTransientEffect(crown)
        crown.run(.sequence([.group([.move(to: CGPoint(x: size.width * 0.5, y: size.height - tileHeight * 0.7), duration: 0.72),
                                     .scale(to: 0.45, duration: 0.72), .rotate(byAngle: .pi * 2, duration: 0.72)]),
                            .fadeOut(withDuration: 0.16), .removeFromParent()]))
        if !reduceMotion && !thermalLimited {
            arenaCamera?.removeAction(forKey: "tower-destroy-shake")
            arenaCamera?.run(.sequence([.moveBy(x: 8, y: -5, duration: 0.025), .moveBy(x: -16, y: 10, duration: 0.05),
                                        .moveBy(x: 8, y: -5, duration: 0.025)]), withKey: "tower-destroy-shake")
        }
        speed = 0.55
        run(.sequence([.wait(forDuration: 0.16), .run { [weak self] in self?.speed = 1 }]), withKey: "tower-slow-beat")
    }

    private func drawDebugOverlay(_ model: BattleModel) {
        debugLayer?.removeFromParent()
        let layer = SKNode()
        layer.name = "navigation-debug-overlay"
        layer.zPosition = 900
        for item in model.debugOverlayItems() {
            let origin = CGPoint(x: CGFloat(item.x) * tileWidth, y: CGFloat(item.y) * tileHeight)
            if item.aggroRange > 0 {
                let aggro = SKShapeNode(circleOfRadius: CGFloat(item.aggroRange) * tileWidth)
                aggro.position = origin; aggro.fillColor = UIColor.systemCyan.withAlphaComponent(0.035)
                aggro.strokeColor = UIColor.systemCyan.withAlphaComponent(0.38); aggro.lineWidth = 0.8
                layer.addChild(aggro)
            }
            if item.attackRange > 0 {
                let attack = SKShapeNode(circleOfRadius: CGFloat(item.attackRange) * tileWidth)
                attack.position = origin; attack.fillColor = .clear
                attack.strokeColor = UIColor.systemOrange.withAlphaComponent(0.55); attack.lineWidth = 1
                layer.addChild(attack)
            }
            if item.path.count > 1 {
                let route = CGMutablePath()
                route.move(to: CGPoint(x: (Double(item.path[0].x) + 0.5) * Double(tileWidth),
                                       y: (Double(item.path[0].y) + 0.5) * Double(tileHeight)))
                for cell in item.path.dropFirst() {
                    route.addLine(to: CGPoint(x: (Double(cell.x) + 0.5) * Double(tileWidth),
                                              y: (Double(cell.y) + 0.5) * Double(tileHeight)))
                }
                let line = SKShapeNode(path: route)
                line.strokeColor = UIColor.systemGreen.withAlphaComponent(0.8)
                line.lineWidth = 1.5; line.glowWidth = 1
                layer.addChild(line)
            }
            if let tx = item.targetX, let ty = item.targetY {
                let linePath = CGMutablePath()
                linePath.move(to: origin)
                linePath.addLine(to: CGPoint(x: CGFloat(tx) * tileWidth, y: CGFloat(ty) * tileHeight))
                let line = SKShapeNode(path: linePath)
                // A solid line keeps the target marker compatible with the iOS 16 SpriteKit API.
                line.strokeColor = UIColor.systemPink.withAlphaComponent(0.8)
                line.lineWidth = 1.1
                layer.addChild(line)
            }
        }
        addChild(layer)
        debugLayer = layer
    }

    private func addDeathPoof(at point: CGPoint, team: Team) {
        let tint: UIColor = team == .blue ? .systemBlue : .systemRed
        for index in 0..<7 {
            let angle = CGFloat(index) * (.pi * 2 / 7)
            emitParticle(at: point, radius: max(1.5, tileWidth * 0.075),
                         color: index.isMultiple(of: 2) ? UIColor.white.withAlphaComponent(0.85) : tint.withAlphaComponent(0.72),
                         z: 940, dx: cos(angle) * tileWidth * 0.42,
                         dy: sin(angle) * tileHeight * 0.42, duration: 0.22)
        }
    }

    private func addDebris(at point: CGPoint) {
        let palette: [UIColor] = [.systemYellow, .systemOrange, .lightGray, .white]
        for index in 0..<7 {
            let piece = SKShapeNode(rectOf: CGSize(width: 3, height: 3), cornerRadius: 0.5)
            piece.position = point
            piece.fillColor = palette[index % palette.count]
            piece.strokeColor = .clear
            piece.zPosition = 950
            addTransientEffect(piece)
            let dx = CGFloat((index % 4) - 2) * tileWidth * 0.42
            let dy = CGFloat((index / 4) + 1) * tileHeight * 0.5
            piece.run(.sequence([.group([.moveBy(x: dx, y: dy, duration: 0.28), .rotate(byAngle: CGFloat(index) * 1.1, duration: 0.28), .fadeOut(withDuration: 0.28)]), .removeFromParent()]))
        }
    }
    private func accentColor(for id: String) -> UIColor {
        // Golden-angle spacing gives every catalog card a distinct, stable hue.
        if let index = CardCatalog.all.firstIndex(where: { $0.id == id }) {
            let hue = CGFloat((Double(index) * 0.61803398875).truncatingRemainder(dividingBy: 1))
            return UIColor(hue: hue, saturation: 0.76, brightness: 0.98, alpha: 1)
        }
        var hash: UInt32 = 2166136261
        for byte in id.utf8 { hash = (hash ^ UInt32(byte)) &* 16777619 }
        return UIColor(hue: CGFloat(hash % 360) / 360, saturation: 0.72, brightness: 0.98, alpha: 1)
    }

    @discardableResult
    private func addRect(_ parent: SKNode, size: CGSize, at point: CGPoint, radius: CGFloat,
                         fill: UIColor, stroke: UIColor = .clear, lineWidth: CGFloat = 0,
                         name: String? = nil) -> SKShapeNode {
        let node = SKShapeNode(rectOf: size, cornerRadius: radius)
        node.position = point; node.fillColor = fill; node.strokeColor = stroke; node.lineWidth = lineWidth; node.name = name
        parent.addChild(node)
        return node
    }

    @discardableResult
    private func addCircle(_ parent: SKNode, radius: CGFloat, at point: CGPoint,
                           fill: UIColor, stroke: UIColor = .clear, lineWidth: CGFloat = 0,
                           name: String? = nil) -> SKShapeNode {
        let node = SKShapeNode(circleOfRadius: radius)
        node.position = point; node.fillColor = fill; node.strokeColor = stroke; node.lineWidth = lineWidth; node.name = name
        parent.addChild(node)
        return node
    }

    @discardableResult
    private func addPolygon(_ parent: SKNode, points: [CGPoint], fill: UIColor,
                            stroke: UIColor = .clear, lineWidth: CGFloat = 0,
                            name: String? = nil) -> SKShapeNode {
        let path = CGMutablePath()
        guard let first = points.first else { return SKShapeNode() }
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
        let node = SKShapeNode(path: path)
        node.fillColor = fill; node.strokeColor = stroke; node.lineWidth = lineWidth; node.name = name
        parent.addChild(node)
        return node
    }

    private func addRubble(at point: CGPoint) {
        let base = SKShapeNode(ellipseOf: CGSize(width: tileWidth * 1.55, height: tileHeight * 0.58))
        base.position = CGPoint(x: point.x, y: point.y - tileHeight * 0.12)
        base.fillColor = UIColor(white: 0.12, alpha: 0.9)
        base.strokeColor = UIColor.systemGray.withAlphaComponent(0.55); base.lineWidth = 1.5
        base.zPosition = CGFloat(point.y / max(1, tileHeight)) - 0.1
        addChild(base)
        for index in 0..<5 {
            let chip = SKShapeNode(rectOf: CGSize(width: tileWidth * 0.24, height: tileHeight * 0.18), cornerRadius: 1)
            chip.position = CGPoint(x: point.x + CGFloat(index - 2) * tileWidth * 0.22, y: point.y - tileHeight * 0.08 + CGFloat(index % 2) * tileHeight * 0.10)
            chip.fillColor = index.isMultiple(of: 2) ? UIColor.systemGray2 : UIColor.darkGray
            chip.strokeColor = .clear; chip.zPosition = base.zPosition + 0.1
            addChild(chip)
        }
    }

    private func addAttackEffect(_ event: BattleEvent, style: String) {
        guard let sourceX = event.sourceX, let sourceY = event.sourceY else { return }
        if style == "melee" { proofMeleeSwingCount += 1 }
        if style == "projectile" { proofProjectileEffectCount += 1 }
        let from = CGPoint(x: CGFloat(sourceX) * tileWidth, y: CGFloat(sourceY) * tileHeight)
        let to = CGPoint(x: CGFloat(event.x) * tileWidth, y: CGFloat(event.y) * tileHeight)
        let color: UIColor = style == "beam" ? .systemPurple : (style == "melee" ? .white : .systemYellow)
        if style == "melee" {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: to.x - tileWidth * 0.44, y: to.y - tileHeight * 0.12))
            path.addQuadCurve(to: CGPoint(x: to.x + tileWidth * 0.48, y: to.y + tileHeight * 0.16), control: CGPoint(x: to.x + tileWidth * 0.34, y: to.y + tileHeight * 0.64))
            let slash = SKShapeNode(path: path)
            slash.strokeColor = .white.withAlphaComponent(0.95); slash.lineWidth = max(2, tileWidth * 0.12); slash.glowWidth = 3; slash.zPosition = 850
            addTransientEffect(slash)
            slash.run(.sequence([.group([.fadeOut(withDuration: 0.18), .scale(to: 1.35, duration: 0.18)]), .removeFromParent()]))
        } else {
            let path = CGMutablePath(); path.move(to: from); path.addLine(to: to)
            let trail = SKShapeNode(path: path)
            trail.strokeColor = color.withAlphaComponent(style == "beam" ? 0.92 : 0.60)
            trail.lineWidth = style == "beam" ? max(3, tileWidth * 0.22) : max(1.5, tileWidth * 0.10)
            trail.glowWidth = style == "beam" ? 5 : 2; trail.zPosition = 840
            addTransientEffect(trail)
            trail.run(.sequence([.fadeOut(withDuration: style == "beam" ? 0.24 : 0.18), .removeFromParent()]))
            if style == "projectile" {
                let bolt = acquireProjectile(color: color)
                bolt.position = from; bolt.zPosition = 860
                addTransientEffect(bolt)
                let travel = CGPoint(x: to.x - from.x, y: to.y - from.y)
                bolt.zRotation = atan2(travel.y, travel.x) - .pi / 2
                bolt.run(.group([.move(to: to, duration: 0.17), .rotate(byAngle: .pi * 0.7, duration: 0.17)]))
                bolt.run(.sequence([.wait(forDuration: 0.17), .fadeOut(withDuration: 0.06),
                                    .run { [weak self, weak bolt] in
                                        guard let self, let bolt else { return }
                                        self.recycleProjectile(bolt)
                                    }]))
                let muzzle = SKShapeNode(circleOfRadius: max(3, tileWidth * 0.18))
                muzzle.position = from; muzzle.fillColor = .systemYellow.withAlphaComponent(0.8)
                muzzle.strokeColor = .white; muzzle.glowWidth = 4; muzzle.zPosition = 861
                addTransientEffect(muzzle)
                muzzle.run(.sequence([.group([.scale(to: 1.9, duration: 0.08), .fadeOut(withDuration: 0.08)]), .removeFromParent()]))
                let impact = SKShapeNode(circleOfRadius: max(3, tileWidth * 0.20))
                impact.position = to
                impact.fillColor = color.withAlphaComponent(0.30)
                impact.strokeColor = .white.withAlphaComponent(0.9)
                impact.lineWidth = 1.1
                impact.glowWidth = 3
                impact.zPosition = 865
                addTransientEffect(impact)
                impact.run(.sequence([
                    .wait(forDuration: 0.17),
                    .group([.scale(to: 2.1, duration: 0.14), .fadeOut(withDuration: 0.14)]),
                    .removeFromParent()
                ]))
                for index in 0..<5 {
                    let angle = CGFloat(index) * (.pi * 2 / 5)
                    emitParticle(at: to, radius: max(1, tileWidth * 0.045),
                                 color: index.isMultiple(of: 2) ? .systemYellow : .white,
                                 z: 866, dx: cos(angle) * tileWidth * 0.28,
                                 dy: sin(angle) * tileHeight * 0.28, duration: 0.18, finalScale: 1.0)
                }
            } else {
                let flash = SKShapeNode(circleOfRadius: max(3, tileWidth * 0.25))
                flash.position = to; flash.fillColor = UIColor.systemPurple.withAlphaComponent(0.24); flash.strokeColor = .systemPurple; flash.lineWidth = 2; flash.zPosition = 855
                addTransientEffect(flash)
                flash.run(.sequence([.scale(to: 1.55, duration: 0.12), .fadeOut(withDuration: 0.12), .removeFromParent()]))
            }
        }
        if let sourceID = event.sourceID, let source = entityNodes[sourceID] {
            if let body = source.childNode(withName: "//body") {
                body.removeAction(forKey: "attack-pulse")
                body.run(.sequence([
                    .scale(to: 1.08, duration: 0.075), // windup
                    .scale(to: 0.90, duration: 0.055), // strike
                    .scale(to: 1.0, duration: 0.13)    // recovery
                ]), withKey: "attack-pulse")
            }
            if let weapon = source.childNode(withName: "//weapon-arm") {
                weapon.removeAction(forKey: "weapon-swing")
                weapon.run(.sequence([.rotate(byAngle: 0.82, duration: 0.07), .rotate(byAngle: -0.82, duration: 0.11)]), withKey: "weapon-swing")
            }
            if let turret = source.childNode(withName: "//turret") {
                turret.removeAction(forKey: "turret-recoil")
                turret.run(.sequence([.scale(to: 1.12, duration: 0.045), .scale(to: 1.0, duration: 0.10)]), withKey: "turret-recoil")
            }
        }
    }

    private func addSpellEffect(_ event: BattleEvent, style: String) {
        let center = CGPoint(x: CGFloat(event.x) * tileWidth, y: CGFloat(event.y) * tileHeight)
        let radius = CGFloat(min(5.0, max(0.8, event.effectRadius ?? 2.5))) * tileWidth
        let ring = SKShapeNode(circleOfRadius: style == "spell-telegraph" ? radius * 0.72 : radius * 0.38)
        ring.position = center
        ring.fillColor = style == "spell-telegraph" ? UIColor.systemCyan.withAlphaComponent(0.035) : UIColor.systemOrange.withAlphaComponent(0.18)
        ring.strokeColor = style == "spell-telegraph" ? UIColor.systemCyan.withAlphaComponent(0.9) : UIColor.systemYellow
        ring.lineWidth = style == "spell-telegraph" ? 1.8 : 2.4
        ring.glowWidth = style == "spell-impact" ? 5 : 1
        ring.zPosition = 870
        addTransientEffect(ring)
        if style == "spell-telegraph" {
            ring.run(.sequence([.group([.scale(to: 1.22, duration: 0.24), .fadeOut(withDuration: 0.34)]), .removeFromParent()]))
        } else {
            ring.run(.sequence([.group([.scale(to: radius / max(1, ring.frame.width / 2) * 1.35, duration: 0.22),
                                       .fadeOut(withDuration: 0.30)]), .removeFromParent()]))
            for index in 0..<10 {
                let angle = CGFloat(index) * (.pi * 2 / 10)
                let distance = radius * (0.48 + CGFloat(index % 3) * 0.12)
                emitParticle(at: center, radius: max(1.5, tileWidth * 0.055),
                             color: index.isMultiple(of: 2) ? .systemYellow : .systemOrange,
                             z: 875, dx: cos(angle) * distance, dy: sin(angle) * distance,
                             duration: 0.28, finalScale: 0.2)
            }
            if !reduceMotion && !thermalLimited {
                let shake = min(6.0, max(1.5, radius * 0.12))
                arenaCamera?.removeAction(forKey: "spell-impact-shake")
                arenaCamera?.run(.sequence([
                    .moveBy(x: shake, y: -shake * 0.55, duration: 0.025),
                    .moveBy(x: -shake * 2, y: shake * 1.1, duration: 0.05),
                    .moveBy(x: shake, y: -shake * 0.55, duration: 0.025)
                ]), withKey: "spell-impact-shake")
            }
        }
    }

    private func makeNode(_ entity: BattleEntity) -> SKNode {
        let root = SKNode()
        let definition = CardCatalog.byID[entity.cardID]
        let accent = accentColor(for: entity.cardID)
        let teamColor = entity.team == .blue
            ? UIColor(red: 0.13, green: 0.48, blue: 0.92, alpha: 1)
            : UIColor(red: 0.88, green: 0.20, blue: 0.27, alpha: 1)
        let isFlyingEntity = definition?.behavior.contains(.flying) == true
        let shadow = SKShapeNode(ellipseOf: CGSize(width: entity.tower ? tileWidth * 1.6 : tileWidth * (isFlyingEntity ? 0.78 : 1.12), height: tileHeight * 0.32))
        shadow.position = CGPoint(x: tileWidth * 0.08, y: -tileHeight * (isFlyingEntity ? 0.72 : 0.34))
        shadow.fillColor = .black.withAlphaComponent(0.32); shadow.strokeColor = .clear
        root.addChild(shadow)
        let visual = SKNode()
        // Keep the sprite upright; mirror only its horizontal facing for the red side.
        visual.name = "visual"
        visual.yScale = 1
        visual.xScale = entity.team == .blue ? 1 : -1
        root.addChild(visual)

        if entity.tower {
            let width = tileWidth * (entity.king ? 1.48 : 1.27)
            let height = tileHeight * (entity.king ? 1.50 : 1.30)
            addRect(visual, size: CGSize(width: width, height: height), at: .zero, radius: 5,
                    fill: UIColor(red: 0.20, green: 0.23, blue: 0.29, alpha: 1),
                    stroke: UIColor.white.withAlphaComponent(0.72), lineWidth: 1.7, name: "body")
            addRect(visual, size: CGSize(width: width * 0.82, height: height * 0.78), at: CGPoint(x: 0, y: -height * 0.04), radius: 4,
                    fill: entity.king ? UIColor(red: 0.82, green: 0.57, blue: 0.18, alpha: 1) : teamColor, stroke: accent, lineWidth: 1.1)
            for column in -1...1 {
                addRect(visual, size: CGSize(width: width * 0.22, height: height * 0.18), at: CGPoint(x: CGFloat(column) * width * 0.32, y: height * 0.47),
                        radius: 2, fill: UIColor(red: 0.78, green: 0.80, blue: 0.85, alpha: 1), stroke: UIColor.black.withAlphaComponent(0.25), lineWidth: 0.5)
            }
            let turret = SKNode(); turret.name = "turret"; turret.position = CGPoint(x: 0, y: height * 0.05); visual.addChild(turret)
            addCircle(turret, radius: width * 0.23, at: .zero,
                      fill: entity.king ? UIColor.systemYellow : UIColor(red: 0.25, green: 0.29, blue: 0.36, alpha: 1),
                      stroke: UIColor.white.withAlphaComponent(0.85), lineWidth: 1.2)
            addRect(turret, size: CGSize(width: width * 0.17, height: height * 0.42), at: CGPoint(x: 0, y: height * 0.29), radius: 2,
                    fill: UIColor(red: 0.82, green: 0.84, blue: 0.89, alpha: 1), stroke: .darkGray, lineWidth: 0.8)
            if entity.king {
                // A visible king mascot sits on the King Tower rather than a generic turret cap.
                addRect(visual, size: CGSize(width: width * 0.50, height: height * 0.28),
                        at: CGPoint(x: 0, y: height * 0.58), radius: 4,
                        fill: teamColor, stroke: UIColor(red: 0.055, green: 0.065, blue: 0.10, alpha: 1), lineWidth: 1.8)
                addCircle(visual, radius: width * 0.24, at: CGPoint(x: 0, y: height * 0.82),
                          fill: UIColor(red: 0.95, green: 0.72, blue: 0.52, alpha: 1),
                          stroke: UIColor(red: 0.055, green: 0.065, blue: 0.10, alpha: 1), lineWidth: 1.8)
                addPolygon(visual, points: [
                    CGPoint(x: -width * 0.28, y: height * 0.88), CGPoint(x: -width * 0.22, y: height * 1.10),
                    CGPoint(x: -width * 0.06, y: height * 0.96), CGPoint(x: width * 0.08, y: height * 1.12),
                    CGPoint(x: width * 0.27, y: height * 0.88)
                ], fill: UIColor.systemYellow, stroke: UIColor(red: 0.055, green: 0.065, blue: 0.10, alpha: 1), lineWidth: 1.7)
                addCircle(visual, radius: 1.5, at: CGPoint(x: -width * 0.09, y: height * 0.84), fill: .black)
                addCircle(visual, radius: 1.5, at: CGPoint(x: width * 0.09, y: height * 0.84), fill: .black)
                addPolygon(visual, points: [
                    CGPoint(x: -width * 0.16, y: height * 0.70), CGPoint(x: 0, y: height * 0.76),
                    CGPoint(x: width * 0.16, y: height * 0.70), CGPoint(x: 0, y: height * 0.64)
                ], fill: UIColor(white: 0.96, alpha: 1), stroke: UIColor(red: 0.055, green: 0.065, blue: 0.10, alpha: 1), lineWidth: 1.2)
            } else {
                addPolygon(visual, points: [
                    CGPoint(x: width * 0.18, y: height * 0.44), CGPoint(x: width * 0.68, y: height * 0.66), CGPoint(x: width * 0.18, y: height * 0.78)
                ], fill: accent, stroke: .white, lineWidth: 0.7)
            }
        } else if let card = definition {
            let avatar = CardSpriteFactory.make(card: card, team: entity.team,
                                                 size: CGSize(width: tileWidth * 1.15, height: tileHeight * 1.65))
            avatar.name = "body"
            visual.addChild(avatar)
            if !reduceMotion && !thermalLimited {
                avatar.run(.repeatForever(.sequence([
                    .moveBy(x: 0, y: tileHeight * 0.035, duration: 0.48),
                    .moveBy(x: 0, y: -tileHeight * 0.035, duration: 0.48)
                ])), withKey: "idle-bob")
            }
        }

        let hpY = entity.tower ? tileHeight * 1.10 : tileHeight * 0.86
        let hpBack = SKShapeNode(rectOf: CGSize(width: tileWidth * (entity.tower ? 1.42 : 1.23), height: max(3, tileHeight * 0.17)), cornerRadius: 2)
        hpBack.name = "hp-background"
        hpBack.position = CGPoint(x: 0, y: hpY); hpBack.fillColor = UIColor.black.withAlphaComponent(0.85); hpBack.strokeColor = UIColor.white.withAlphaComponent(0.65); hpBack.lineWidth = 0.6
        root.addChild(hpBack)
        let hp = SKShapeNode(rectOf: CGSize(width: tileWidth * (entity.tower ? 1.34 : 1.15), height: max(2, tileHeight * 0.12)), cornerRadius: 1)
        hp.name = "hp"; hp.position = CGPoint(x: -tileWidth * 0.025, y: hpY); hp.fillColor = .systemGreen; hp.strokeColor = .clear
        root.addChild(hp)
        if entity.deployClock > 0 {
            let ring = SKShapeNode(circleOfRadius: min(tileWidth, tileHeight) * 0.82)
            ring.name = "deploy-ring"
            ring.strokeColor = UIColor.white.withAlphaComponent(0.88); ring.lineWidth = 2; ring.fillColor = .clear; root.addChild(ring)
            ring.run(.sequence([.wait(forDuration: entity.deployClock), .fadeOut(withDuration: 0.16), .removeFromParent()]))
        }
        // Deployment is a readable pop-in with a small, capped dust burst at ground level.
        root.setScale(0.24)
        root.run(.sequence([.scale(to: 1.12, duration: 0.11), .scale(to: 1.0, duration: 0.09)]), withKey: "deploy-pop")
        if !entity.tower && !reduceMotion && !thermalLimited {
            for index in 0..<4 {
                let dust = SKShapeNode(circleOfRadius: max(1.2, tileWidth * 0.055))
                dust.position = CGPoint(x: CGFloat(index - 2) * tileWidth * 0.10, y: -tileHeight * 0.40)
                dust.fillColor = UIColor(white: 0.78, alpha: 0.72); dust.strokeColor = .clear; dust.zPosition = -2
                root.addChild(dust)
                dust.run(.sequence([.group([.moveBy(x: CGFloat(index - 2) * tileWidth * 0.18, y: tileHeight * 0.20, duration: 0.22),
                                             .scale(to: 1.8, duration: 0.22), .fadeOut(withDuration: 0.22)]), .removeFromParent()]))
            }
        }
        return root
    }

    // Deterministic visual-proof hooks used only by the simulator's XCTest renderer.
    func proofPrepareContactSheet() {
        removeAllChildren()
        transientEffects.removeAll()
        installCamera()
        backgroundColor = UIColor(red: 0.075, green: 0.09, blue: 0.14, alpha: 1)
    }

    func proofAddCardSprite(_ card: CardDefinition, team: Team, x: Double, y: Double) {
        let hp = max(100, card.hp)
        let entity = BattleEntity(id: Int(x * 100 + y), cardID: card.id, team: team,
                                  x: x, y: y, hp: hp, maxHP: hp)
        let node = makeNode(entity)
        node.removeAction(forKey: "deploy-pop")
        node.setScale(1)
        // The audit sheet is for silhouette/palette, not HUD health bars.
        for child in node.children where ["hp", "hp-background", "deploy-ring"].contains(child.name ?? "") {
            child.removeFromParent()
        }
        node.position = CGPoint(x: CGFloat(x) * tileWidth, y: CGFloat(y) * tileHeight)
        addChild(node)
    }

    /// Build an actual rendered card node for exhaustive XCTest animation checks.
    func proofCreateAnimationNode(_ card: CardDefinition, team: Team, id: Int) -> SKNode {
        let hp = max(100, card.hp)
        let entity = BattleEntity(id: id, cardID: card.id, team: team, x: 8, y: 12, hp: hp, maxHP: hp)
        let node = makeNode(entity)
        node.position = CGPoint(x: tileWidth * 8, y: tileHeight * 12)
        entityNodes[id] = node
        addChild(node)
        return node
    }

    func proofTriggerWalk(_ node: SKNode) {
        if let body = node.childNode(withName: "//body") {
            body.run(.sequence([.scaleX(to: 0.91, duration: 0.07),
                                .scaleX(to: 1.05, duration: 0.08),
                                .scaleX(to: 1.0, duration: 0.07)]), withKey: "walk-squash")
        }
        for (name, sign) in [("leg-left", 1.0), ("leg-right", -1.0)] {
            if let leg = node.childNode(withName: "//" + name) {
                leg.run(.sequence([.rotate(byAngle: CGFloat(sign) * 0.36, duration: 0.08),
                                   .rotate(byAngle: CGFloat(-sign) * 0.36, duration: 0.08)]),
                        withKey: "walk-cycle")
            }
        }
    }

    func proofTriggerHit(_ node: SKNode) {
        let flash = SKShapeNode(circleOfRadius: min(tileWidth, tileHeight) * 0.7)
        flash.name = "hit-flash"
        flash.fillColor = .white.withAlphaComponent(0.72)
        flash.strokeColor = .clear
        flash.zPosition = 3
        node.addChild(flash)
        flash.run(.sequence([.fadeOut(withDuration: 0.12), .removeFromParent()]), withKey: "hit-flash")
    }

    func proofTriggerDeath(_ node: SKNode) {
        node.run(.sequence([.scale(to: 0.18, duration: 0.24),
                            .fadeOut(withDuration: 0.24),
                            .rotate(byAngle: 0.35, duration: 0.24)]), withKey: "unit-death")
    }

    func proofTriggerAttack(_ node: SKNode, sourceID: Int) {
        if let body = node.childNode(withName: "//body") {
            body.run(.sequence([.scale(to: 1.08, duration: 0.075),
                                .scale(to: 0.90, duration: 0.055),
                                .scale(to: 1.0, duration: 0.13)]), withKey: "attack-pulse")
        }
        if let weapon = node.childNode(withName: "//weapon-arm") {
            weapon.run(.sequence([.rotate(byAngle: 0.82, duration: 0.07),
                                  .rotate(byAngle: -0.82, duration: 0.11)]), withKey: "weapon-swing")
        }
        if let turret = node.childNode(withName: "//turret") {
            turret.run(.sequence([.scale(to: 1.12, duration: 0.045),
                                  .scale(to: 1.0, duration: 0.10)]), withKey: "turret-recoil")
        }
        _ = sourceID
    }

    func proofBeginAttack(sourceID: Int) {
        guard let source = entityNodes[sourceID] else { return }
        source.childNode(withName: "//body")?.run(.sequence([.scale(to: 1.18, duration: 0.12), .scale(to: 1.04, duration: 0.08)]))
        source.childNode(withName: "//weapon-arm")?.run(.rotate(byAngle: -0.45, duration: 0.12))
    }

    func proofAddAttack(style: String, sourceID: Int, from: CGPoint, to: CGPoint) {
        addAttackEffect(BattleEvent(x: Double(to.x), y: Double(to.y), text: "PROOF",
                                    born: 0, sourceX: Double(from.x), sourceY: Double(from.y),
                                    sourceID: sourceID, style: style), style: style)
    }

    func proofAddSpell(style: String, x: Double, y: Double, radius: Double) {
        addSpellEffect(BattleEvent(x: x, y: y, text: "SPELL", born: 0,
                                   style: style, effectRadius: radius), style: style)
    }

    func proofAddTowerDestruction(x: Double, y: Double, destroyedTeam: Team) {
        let point = CGPoint(x: CGFloat(x) * tileWidth, y: CGFloat(y) * tileHeight)
        addRubble(at: point)
        addDebris(at: point)
        if let tower = entityNodes.values.first(where: { hypot(Double($0.position.x - point.x), Double($0.position.y - point.y)) < Double(tileWidth) }) {
            tower.run(.sequence([.group([.scale(to: 0.12, duration: 0.34), .fadeOut(withDuration: 0.34),
                                         .rotate(byAngle: 0.42, duration: 0.34)]), .removeFromParent()]))
        }
        addTowerDestructionEffect(BattleEvent(x: x, y: y, text: "TOWER DESTROYED",
                                              born: 0, style: "tower-destroyed", team: destroyedTeam))
        let banner = SKLabelNode(text: "TOWER DESTROYED")
        banner.fontName = "AvenirNext-Heavy"; banner.fontSize = 17
        banner.fontColor = destroyedTeam == .blue ? .systemRed : .systemBlue
        banner.position = CGPoint(x: size.width * 0.5, y: size.height * 0.54)
        banner.zPosition = 1100; addChild(banner)
    }

    func proofAddCrownTracker(blue: Int, red: Int) {
        func crown(_ x: CGFloat, _ y: CGFloat, _ color: UIColor, _ filled: Bool) {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -9, y: -5)); path.addLine(to: CGPoint(x: -7, y: 7))
            path.addLine(to: CGPoint(x: -3, y: 1)); path.addLine(to: CGPoint(x: 0, y: 9))
            path.addLine(to: CGPoint(x: 3, y: 1)); path.addLine(to: CGPoint(x: 7, y: 7))
            path.addLine(to: CGPoint(x: 9, y: -5)); path.closeSubpath()
            let shape = SKShapeNode(path: path); shape.position = CGPoint(x: x, y: y)
            shape.fillColor = filled ? color : UIColor.white.withAlphaComponent(0.12)
            shape.strokeColor = color; shape.lineWidth = 1.4; shape.zPosition = 1000
            addChild(shape)
        }
        for i in 0..<3 {
            crown(size.width * 0.5 - 28 + CGFloat(i) * 24, size.height - 22, .systemBlue, i < blue)
            crown(size.width * 0.5 + 52 + CGFloat(i) * 24, size.height - 22, .systemRed, i < red)
        }
    }

    private func boardPoint(_ point: CGPoint) -> (Double, Double) {
        (min(17.5, max(0.5, Double(point.x / tileWidth))),
         min(31.5, max(0.5, Double(point.y / tileHeight))))
    }

    private func valid(_ x: Double, _ y: Double) -> Bool { battle?.isValidPlacement(x: x, y: y) ?? false }

    func updatePlacementGhost(x: Double, y: Double, valid: Bool) {
        let tile = CGPoint(x: floor(x), y: floor(y))
        if tile != lastTile {
            if hapticsEnabled { UISelectionFeedbackGenerator().selectionChanged() }
            lastTile = tile
        }
        if ghost == nil {
            let node = SKShapeNode(circleOfRadius: min(tileWidth, tileHeight) * 0.75)
            node.zPosition = 500
            ghost = node
            addChild(node)
        }
        ghost?.isHidden = false
        ghost?.position = CGPoint(x: CGFloat(x) * tileWidth, y: CGFloat(y) * tileHeight + tileHeight)
        ghost?.fillColor = (valid ? UIColor.systemGreen : UIColor.systemRed).withAlphaComponent(0.22)
        ghost?.strokeColor = valid ? .systemGreen : .systemRed
        if gridPreview == nil {
            let preview = SKShapeNode(rectOf: CGSize(width: tileWidth - 1, height: tileHeight - 1), cornerRadius: 2)
            preview.zPosition = 490
            gridPreview = preview
            addChild(preview)
        }
        gridPreview?.isHidden = false
        gridPreview?.position = CGPoint(x: (floor(x) + 0.5) * tileWidth, y: (floor(y) + 0.5) * tileHeight)
        gridPreview?.fillColor = (valid ? UIColor.systemGreen : UIColor.systemRed).withAlphaComponent(0.28)
        gridPreview?.strokeColor = valid ? .systemGreen : .systemRed
    }

    private func updateGhost(at point: CGPoint) {
        let (x, y) = boardPoint(point)
        updatePlacementGhost(x: x, y: y, valid: valid(x, y))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, battle?.selectedCard != nil else { return }
        updateGhost(at: touch.location(in: self))
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, battle?.selectedCard != nil else { return }
        updateGhost(at: touch.location(in: self))
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let (x, y) = boardPoint(touch.location(in: self))
        if valid(x, y) {
            if hapticsEnabled { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
            onDrop?(x, y)
        } else {
            battle?.cancelSelection()
        }
        ghost?.isHidden = true
        gridPreview?.isHidden = true
    }
}