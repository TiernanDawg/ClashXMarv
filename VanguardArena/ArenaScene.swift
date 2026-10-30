import SpriteKit
import UIKit

final class ArenaScene: SKScene {
    weak var battle: BattleModel?
    var showDamageNumbers = true
    var reduceMotion = false
    var highContrast = false
    var hapticsEnabled = true
    var themeIndex = 0\n    var debugNavigation = false\n    private var debugLayer: SKNode?
    private var lastHP: [Int: Double] = [:]
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
        entityNodes.removeAll()
        lastHP.removeAll()
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
                tile.fillColor = UIColor.white.withAlphaComponent(0.025)
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
                flash.fillColor = .white.withAlphaComponent(0.72)
                flash.strokeColor = .clear
                flash.zPosition = 3
                node.addChild(flash)
                flash.run(.sequence([.fadeOut(withDuration: 0.12), .removeFromParent()]))
            }
            lastHP[entity.id] = entity.hp
            let newPosition = CGPoint(x: CGFloat(entity.x) * tileWidth, y: CGFloat(entity.y) * tileHeight)
            if !reduceMotion && !thermalLimited,
               let oldPosition = lastPositions[entity.id],
               hypot(Double(newPosition.x - oldPosition.x), Double(newPosition.y - oldPosition.y)) > 0.12 {
                if let body = node.childNode(withName: "//body") {
                    body.removeAction(forKey: "walk-squash")
                    body.run(.sequence([.scaleX(to: 0.91, duration: 0.07), .scaleX(to: 1.05, duration: 0.08), .scaleX(to: 1.0, duration: 0.07)]), withKey: "walk-squash")
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
            node.position = newPosition
            node.zPosition = CGFloat(entity.y)
            node.alpha = (CardCatalog.byID[entity.cardID]?.behavior.contains(.invisible) == true && !entity.hasAttacked) ? 0.28 : 1
            if let badge = node.childNode(withName: "hp") as? SKShapeNode {
                let ratio = max(0, min(1, entity.hp / max(1, entity.maxHP)))
                badge.xScale = ratio
                badge.fillColor = ratio > 0.5 ? .systemGreen : (ratio > 0.25 ? .systemYellow : .systemRed)
            }
            if let body = node.childNode(withName: "body") as? SKShapeNode {
                body.fillColor = highContrast ? (entity.team == .blue ? UIColor.systemCyan : UIColor.systemOrange) : (entity.team == .blue ? UIColor(red: 0.20, green: 0.58, blue: 0.98, alpha: 1) : UIColor(red: 0.96, green: 0.25, blue: 0.30, alpha: 1))
                if entity.tower { body.fillColor = entity.king ? .systemYellow : (entity.team == .blue ? .systemTeal : .systemPink) }
            }
        }
        for event in model.events where model.elapsed - event.born < (event.style == "tower-destroyed" ? 1.25 : 0.4) && (showDamageNumbers || !event.text.hasPrefix("−")) {
            let name = "event-\(event.id)"
            if childNode(withName: name) == nil {
                if let style = event.style, ["melee", "projectile", "beam"].contains(style) {
                    addAttackEffect(event, style: style)
                }
                if let style = event.style, style == "spell-telegraph" || style == "spell-impact" {
                    addSpellEffect(event, style: style)
                }
                if event.style != "melee" && event.style != "projectile" && event.style != "beam" &&
                    event.style != "spell-telegraph" && event.style != "spell-impact" {
                    let label = SKLabelNode(text: event.text)
                    label.name = name
                    label.fontName = "AvenirNext-Heavy"
                    label.fontSize = event.style == "tower-destroyed" ? max(12, min(17, tileWidth * 0.78)) : max(8, min(12, tileWidth * 0.55))
                    label.fontColor = event.style == "tower-destroyed" ? UIColor.systemYellow : .white
                    label.position = CGPoint(x: CGFloat(event.x) * tileWidth, y: CGFloat(event.y) * tileHeight + tileHeight)
                    label.zPosition = 1000
                    addChild(label)
                    if event.style == "tower-destroyed" { label.run(.sequence([.scale(to: 1.18, duration: 0.10), .scale(to: 1.0, duration: 0.10)])) }
                    if reduceMotion { label.run(.sequence([.wait(forDuration: 0.25), .removeFromParent()])) }
                    else { label.run(.sequence([.group([.moveBy(x: 0, y: tileHeight * 1.15, duration: 0.65), .fadeOut(withDuration: 0.65)]), .removeFromParent()])) }
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
                line.strokeColor = UIColor.systemPink.withAlphaComponent(0.8)
                line.lineWidth = 1.1; line.lineDashPattern = [NSNumber(value: 4), NSNumber(value: 3)]
                layer.addChild(line)
            }
        }
        addChild(layer)
        debugLayer = layer
    }

    private func addDebris(at point: CGPoint) {
        let palette: [UIColor] = [.systemYellow, .systemOrange, .lightGray, .white]
        for index in 0..<7 {
            let piece = SKShapeNode(rectOf: CGSize(width: 3, height: 3), cornerRadius: 0.5)
            piece.position = point
            piece.fillColor = palette[index % palette.count]
            piece.strokeColor = .clear
            piece.zPosition = 950
            addChild(piece)
            let dx = CGFloat((index % 4) - 2) * tileWidth * 0.42
            let dy = CGFloat((index / 4) + 1) * tileHeight * 0.5
            piece.run(.sequence([.group([.moveBy(x: dx, y: dy, duration: 0.28), .rotate(byAngle: CGFloat(index) * 1.1, duration: 0.28), .fadeOut(withDuration: 0.28)]), .removeFromParent()]))
        }
    }
    private func accentColor(for id: String) -> UIColor {
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
        let from = CGPoint(x: CGFloat(sourceX) * tileWidth, y: CGFloat(sourceY) * tileHeight)
        let to = CGPoint(x: CGFloat(event.x) * tileWidth, y: CGFloat(event.y) * tileHeight)
        let color: UIColor = style == "beam" ? .systemPurple : (style == "melee" ? .white : .systemYellow)
        if style == "melee" {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: to.x - tileWidth * 0.44, y: to.y - tileHeight * 0.12))
            path.addQuadCurve(to: CGPoint(x: to.x + tileWidth * 0.48, y: to.y + tileHeight * 0.16), control: CGPoint(x: to.x + tileWidth * 0.34, y: to.y + tileHeight * 0.64))
            let slash = SKShapeNode(path: path)
            slash.strokeColor = .white.withAlphaComponent(0.95); slash.lineWidth = max(2, tileWidth * 0.12); slash.glowWidth = 3; slash.zPosition = 850
            addChild(slash)
            slash.run(.sequence([.group([.fadeOut(withDuration: 0.18), .scale(to: 1.35, duration: 0.18)]), .removeFromParent()]))
        } else {
            let path = CGMutablePath(); path.move(to: from); path.addLine(to: to)
            let trail = SKShapeNode(path: path)
            trail.strokeColor = color.withAlphaComponent(style == "beam" ? 0.92 : 0.60)
            trail.lineWidth = style == "beam" ? max(3, tileWidth * 0.22) : max(1.5, tileWidth * 0.10)
            trail.glowWidth = style == "beam" ? 5 : 2; trail.zPosition = 840
            addChild(trail)
            trail.run(.sequence([.fadeOut(withDuration: style == "beam" ? 0.24 : 0.18), .removeFromParent()]))
            if style == "projectile" {
                let bolt = SKShapeNode(circleOfRadius: max(2, tileWidth * 0.12))
                bolt.position = from; bolt.fillColor = color; bolt.strokeColor = .white; bolt.lineWidth = 0.8; bolt.glowWidth = 3; bolt.zPosition = 860
                addChild(bolt)
                bolt.run(.sequence([.move(to: to, duration: 0.15), .fadeOut(withDuration: 0.06), .removeFromParent()]))
            } else {
                let flash = SKShapeNode(circleOfRadius: max(3, tileWidth * 0.25))
                flash.position = to; flash.fillColor = UIColor.systemPurple.withAlphaComponent(0.24); flash.strokeColor = .systemPurple; flash.lineWidth = 2; flash.zPosition = 855
                addChild(flash)
                flash.run(.sequence([.scale(to: 1.55, duration: 0.12), .fadeOut(withDuration: 0.12), .removeFromParent()]))
            }
        }
        if let sourceID = event.sourceID, let source = entityNodes[sourceID] {
            if let body = source.childNode(withName: "//body") {
                body.removeAction(forKey: "attack-pulse")
                body.run(.sequence([.scale(to: 1.14, duration: 0.055), .scale(to: 1.0, duration: 0.10)]), withKey: "attack-pulse")
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
        addChild(ring)
        if style == "spell-telegraph" {
            ring.run(.sequence([.group([.scale(to: 1.22, duration: 0.24), .fadeOut(withDuration: 0.34)]), .removeFromParent()]))
        } else {
            ring.run(.sequence([.group([.scale(to: radius / max(1, ring.frame.width / 2) * 1.35, duration: 0.22),
                                       .fadeOut(withDuration: 0.30)]), .removeFromParent()]))
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
        let shadow = SKShapeNode(ellipseOf: CGSize(width: entity.tower ? tileWidth * 1.6 : tileWidth * 1.12, height: tileHeight * 0.32))
        shadow.position = CGPoint(x: tileWidth * 0.08, y: -tileHeight * 0.34); shadow.fillColor = .black.withAlphaComponent(0.32); shadow.strokeColor = .clear
        root.addChild(shadow)
        let visual = SKNode()
        visual.name = "visual"; visual.yScale = entity.team == .blue ? 1 : -1
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
                addPolygon(visual, points: [
                    CGPoint(x: -width * 0.31, y: height * 0.62), CGPoint(x: -width * 0.21, y: height * 0.82),
                    CGPoint(x: -width * 0.04, y: height * 0.66), CGPoint(x: width * 0.10, y: height * 0.84),
                    CGPoint(x: width * 0.29, y: height * 0.62)
                ], fill: UIColor.systemYellow, stroke: .white, lineWidth: 0.7)
            } else {
                addPolygon(visual, points: [
                    CGPoint(x: width * 0.18, y: height * 0.44), CGPoint(x: width * 0.68, y: height * 0.66), CGPoint(x: width * 0.18, y: height * 0.78)
                ], fill: accent, stroke: .white, lineWidth: 0.7)
            }
        } else if definition?.kind == .building {
            let width = tileWidth * 1.18, height = tileHeight * 1.05
            addRect(visual, size: CGSize(width: width, height: height), at: .zero, radius: 4,
                    fill: UIColor(red: 0.18, green: 0.22, blue: 0.29, alpha: 1), stroke: accent, lineWidth: 1.7, name: "body")
            addPolygon(visual, points: [CGPoint(x: -width * 0.64, y: height * 0.30), CGPoint(x: 0, y: height * 0.78), CGPoint(x: width * 0.64, y: height * 0.30)],
                       fill: accent.withAlphaComponent(0.92), stroke: .white, lineWidth: 0.8)
            addCircle(visual, radius: tileWidth * 0.20, at: .zero, fill: .systemCyan, stroke: .white, lineWidth: 0.9)
            let core = SKShapeNode(circleOfRadius: tileWidth * 0.32)
            core.fillColor = .clear; core.strokeColor = accent.withAlphaComponent(0.8); core.lineWidth = 1.6; core.zPosition = -1; visual.addChild(core)
            if !reduceMotion && !thermalLimited { core.run(.repeatForever(.rotate(byAngle: CGFloat.pi * 2, duration: 3.2))) }
        } else if let card = definition {
            let analog = card.analog.lowercased()
            let isFlying = card.behavior.contains(.flying)
            let isShielded = card.behavior.contains(.shield)
            let isSkeleton = analog.contains("skeleton") || analog.contains("bone")
            let isRobot = analog.contains("bot") || analog.contains("droid") || analog.contains("drone") || analog.contains("coil")
            let isGoblin = analog.contains("goblin") || analog.contains("gobbler")
            let isMage = analog.contains("witch") || analog.contains("wizard") || analog.contains("strange") || analog.contains("mage")
            let isTank = card.behavior.contains(.buildingTarget) || card.hp > 2200
            let bodyWidth = tileWidth * (isTank ? 0.92 : 0.76), bodyHeight = tileHeight * (isTank ? 0.82 : 0.72)

            addPolygon(visual, points: [
                CGPoint(x: -bodyWidth * 0.25, y: bodyHeight * 0.12), CGPoint(x: bodyWidth * 0.25, y: bodyHeight * 0.12),
                CGPoint(x: bodyWidth * 0.56, y: -bodyHeight * 0.62), CGPoint(x: -bodyWidth * 0.56, y: -bodyHeight * 0.62)
            ], fill: accent.withAlphaComponent(0.88), stroke: UIColor.black.withAlphaComponent(0.45), lineWidth: 0.8)
            for side in [-1.0, 1.0] {
                addRect(visual, size: CGSize(width: bodyWidth * 0.22, height: bodyHeight * 0.28),
                        at: CGPoint(x: CGFloat(side) * bodyWidth * 0.18, y: -bodyHeight * 0.47), radius: 2, fill: UIColor(white: 0.13, alpha: 1))
            }
            let body = SKShapeNode(rectOf: CGSize(width: bodyWidth, height: bodyHeight), cornerRadius: isTank ? 5 : 7)
            body.name = "body"; body.position = CGPoint(x: 0, y: -bodyHeight * 0.04); body.fillColor = teamColor; body.strokeColor = accent; body.lineWidth = 1.5; body.zPosition = 2
            visual.addChild(body)
            addPolygon(visual, points: [
                CGPoint(x: -bodyWidth * 0.25, y: bodyHeight * 0.24), CGPoint(x: 0, y: bodyHeight * 0.39),
                CGPoint(x: bodyWidth * 0.25, y: bodyHeight * 0.24), CGPoint(x: bodyWidth * 0.18, y: -bodyHeight * 0.16),
                CGPoint(x: 0, y: -bodyHeight * 0.25), CGPoint(x: -bodyWidth * 0.18, y: -bodyHeight * 0.16)
            ], fill: accent.withAlphaComponent(0.95), stroke: UIColor.white.withAlphaComponent(0.65), lineWidth: 0.75)

            let skin = isSkeleton ? UIColor(white: 0.90, alpha: 1) : (isRobot ? UIColor(red: 0.60, green: 0.78, blue: 0.87, alpha: 1) : UIColor(red: 0.94, green: 0.72, blue: 0.53, alpha: 1))
            if isRobot {
                addRect(visual, size: CGSize(width: bodyWidth * 0.62, height: bodyHeight * 0.58), at: CGPoint(x: 0, y: bodyHeight * 0.52),
                        radius: 3, fill: skin, stroke: accent, lineWidth: 1.2)
                for side in [-1.0, 1.0] {
                    addRect(visual, size: CGSize(width: bodyWidth * 0.18, height: bodyHeight * 0.10),
                            at: CGPoint(x: CGFloat(side) * bodyWidth * 0.15, y: bodyHeight * 0.54), radius: 1, fill: .systemCyan)
                }
            } else {
                addCircle(visual, radius: bodyWidth * 0.30, at: CGPoint(x: 0, y: bodyHeight * 0.50), fill: skin, stroke: accent, lineWidth: 1.2)
                for side in [-1.0, 1.0] {
                    addCircle(visual, radius: max(1.2, bodyWidth * 0.045), at: CGPoint(x: CGFloat(side) * bodyWidth * 0.105, y: bodyHeight * 0.52),
                              fill: UIColor(white: 0.12, alpha: 1))
                }
            }
            addPolygon(visual, points: [
                CGPoint(x: -bodyWidth * 0.34, y: bodyHeight * 0.64), CGPoint(x: -bodyWidth * 0.25, y: bodyHeight * 0.96),
                CGPoint(x: 0, y: bodyHeight * 0.80), CGPoint(x: bodyWidth * 0.25, y: bodyHeight * 0.96),
                CGPoint(x: bodyWidth * 0.34, y: bodyHeight * 0.64)
            ], fill: isMage ? accent : UIColor(red: 0.28, green: 0.31, blue: 0.37, alpha: 1),
               stroke: UIColor.white.withAlphaComponent(0.65), lineWidth: 0.7)
            if isGoblin {
                addPolygon(visual, points: [
                    CGPoint(x: -bodyWidth * 0.24, y: bodyHeight * 0.47), CGPoint(x: -bodyWidth * 0.58, y: bodyHeight * 0.72), CGPoint(x: -bodyWidth * 0.18, y: bodyHeight * 0.68)
                ], fill: skin, stroke: accent, lineWidth: 0.5)
                addPolygon(visual, points: [
                    CGPoint(x: bodyWidth * 0.24, y: bodyHeight * 0.47), CGPoint(x: bodyWidth * 0.58, y: bodyHeight * 0.72), CGPoint(x: bodyWidth * 0.18, y: bodyHeight * 0.68)
                ], fill: skin, stroke: accent, lineWidth: 0.5)
            }
            let leftArm = SKNode(); leftArm.position = CGPoint(x: -bodyWidth * 0.46, y: bodyHeight * 0.12); visual.addChild(leftArm)
            addRect(leftArm, size: CGSize(width: bodyWidth * 0.20, height: bodyHeight * 0.44), at: CGPoint(x: 0, y: -bodyHeight * 0.10),
                    radius: 3, fill: teamColor, stroke: accent, lineWidth: 0.8)
            let weaponArm = SKNode(); weaponArm.name = "weapon-arm"; weaponArm.position = CGPoint(x: bodyWidth * 0.43, y: bodyHeight * 0.14); visual.addChild(weaponArm)
            addRect(weaponArm, size: CGSize(width: bodyWidth * 0.20, height: bodyHeight * 0.46), at: CGPoint(x: bodyWidth * 0.02, y: -bodyHeight * 0.08),
                    radius: 3, fill: teamColor, stroke: accent, lineWidth: 0.8)
            addCircle(weaponArm, radius: bodyWidth * 0.11, at: CGPoint(x: bodyWidth * 0.03, y: -bodyHeight * 0.29), fill: skin, stroke: accent, lineWidth: 0.5)
            if card.behavior.contains(.ranged) || isMage {
                addRect(weaponArm, size: CGSize(width: bodyWidth * 0.10, height: bodyHeight * 0.72), at: CGPoint(x: bodyWidth * 0.22, y: bodyHeight * 0.12),
                        radius: 2, fill: UIColor(red: 0.42, green: 0.27, blue: 0.16, alpha: 1), stroke: UIColor.black.withAlphaComponent(0.4), lineWidth: 0.6, name: "weapon")
                addCircle(weaponArm, radius: bodyWidth * 0.13, at: CGPoint(x: bodyWidth * 0.22, y: bodyHeight * 0.50),
                          fill: accent, stroke: .white, lineWidth: 0.7)
            } else {
                addRect(weaponArm, size: CGSize(width: bodyWidth * 0.13, height: bodyHeight * 0.66), at: CGPoint(x: bodyWidth * 0.22, y: bodyHeight * 0.19),
                        radius: 1, fill: UIColor(white: 0.82, alpha: 1), stroke: accent, lineWidth: 0.7, name: "weapon")
                addRect(weaponArm, size: CGSize(width: bodyWidth * 0.25, height: bodyHeight * 0.10), at: CGPoint(x: bodyWidth * 0.22, y: -bodyHeight * 0.16),
                        radius: 1, fill: UIColor(red: 0.48, green: 0.28, blue: 0.13, alpha: 1))
            }
            if isShielded {
                addPolygon(visual, points: [
                    CGPoint(x: -bodyWidth * 0.66, y: bodyHeight * 0.30), CGPoint(x: -bodyWidth * 0.35, y: bodyHeight * 0.44),
                    CGPoint(x: -bodyWidth * 0.32, y: -bodyHeight * 0.18), CGPoint(x: -bodyWidth * 0.56, y: -bodyHeight * 0.36),
                    CGPoint(x: -bodyWidth * 0.72, y: -bodyHeight * 0.16)
                ], fill: accent, stroke: .white, lineWidth: 1)
            }
            if isFlying {
                for side in [-1.0, 1.0] {
                    let wing = SKShapeNode(ellipseOf: CGSize(width: bodyWidth * 0.42, height: bodyHeight * 0.48))
                    wing.position = CGPoint(x: CGFloat(side) * bodyWidth * 0.47, y: bodyHeight * 0.10)
                    wing.fillColor = accent.withAlphaComponent(0.72); wing.strokeColor = .white.withAlphaComponent(0.78); wing.lineWidth = 0.8; wing.zPosition = -1
                    visual.addChild(wing)
                    if !reduceMotion && !thermalLimited { wing.run(.repeatForever(.sequence([.scaleY(to: 0.58, duration: 0.12), .scaleY(to: 1.0, duration: 0.12)]))) }
                }
            }
            if card.behavior.contains(.splash) || card.behavior.contains(.rampBeam) {
                let aura = SKShapeNode(circleOfRadius: min(tileWidth, tileHeight) * 0.63)
                aura.fillColor = .clear; aura.strokeColor = accent.withAlphaComponent(0.72); aura.lineWidth = card.behavior.contains(.rampBeam) ? 2.3 : 1.4; aura.zPosition = -2
                visual.addChild(aura)
                if !reduceMotion && !thermalLimited { aura.run(.repeatForever(.sequence([.scale(to: 1.14, duration: 0.45), .scale(to: 0.94, duration: 0.45)]))) }
            }
            for (name, x) in [("leg-left", -bodyWidth * 0.18), ("leg-right", bodyWidth * 0.18)] {
                let leg = SKNode(); leg.name = name; leg.position = CGPoint(x: x, y: -bodyHeight * 0.36); visual.addChild(leg)
                addRect(leg, size: CGSize(width: bodyWidth * 0.20, height: bodyHeight * 0.30), at: CGPoint(x: 0, y: -bodyHeight * 0.05),
                        radius: 2, fill: UIColor(white: 0.17, alpha: 1), stroke: accent, lineWidth: 0.5)
            }
            if !reduceMotion && !thermalLimited {
                body.run(.repeatForever(.sequence([.scaleY(to: 0.96, duration: 0.42), .scaleY(to: 1.02, duration: 0.42)])), withKey: "idle-breathe")
            }
        }

        let hpY = entity.tower ? tileHeight * 1.10 : tileHeight * 0.86
        let hpBack = SKShapeNode(rectOf: CGSize(width: tileWidth * (entity.tower ? 1.42 : 1.23), height: max(3, tileHeight * 0.17)), cornerRadius: 2)
        hpBack.position = CGPoint(x: 0, y: hpY); hpBack.fillColor = UIColor.black.withAlphaComponent(0.85); hpBack.strokeColor = UIColor.white.withAlphaComponent(0.65); hpBack.lineWidth = 0.6
        root.addChild(hpBack)
        let hp = SKShapeNode(rectOf: CGSize(width: tileWidth * (entity.tower ? 1.34 : 1.15), height: max(2, tileHeight * 0.12)), cornerRadius: 1)
        hp.name = "hp"; hp.position = CGPoint(x: -tileWidth * 0.025, y: hpY); hp.fillColor = .systemGreen; hp.strokeColor = .clear
        root.addChild(hp)
        if entity.deployClock > 0 {
            let ring = SKShapeNode(circleOfRadius: min(tileWidth, tileHeight) * 0.82)
            ring.strokeColor = UIColor.white.withAlphaComponent(0.88); ring.lineWidth = 2; ring.fillColor = .clear; root.addChild(ring)
            ring.run(.sequence([.wait(forDuration: entity.deployClock), .fadeOut(withDuration: 0.16), .removeFromParent()]))
        }
        return root
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