import SpriteKit
import UIKit

final class ArenaScene: SKScene {
    weak var battle: BattleModel?
    var showDamageNumbers = true
    var reduceMotion = false
    var highContrast = false
    var hapticsEnabled = true
    var themeIndex = 0
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

        for x in [3.2 * tileWidth, 14.8 * tileWidth] {
            let bridge = SKShapeNode(rectOf: CGSize(width: tileWidth * 2.3, height: tileHeight * 2.4), cornerRadius: 4)
            bridge.position = CGPoint(x: x, y: size.height / 2)
            bridge.fillColor = UIColor(red: 0.61, green: 0.42, blue: 0.25, alpha: 1)
            bridge.strokeColor = UIColor(red: 0.83, green: 0.65, blue: 0.40, alpha: 1)
            bridge.lineWidth = 2
            bridge.zPosition = -3
            addChild(bridge)
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
            entityNodes[id]?.removeFromParent()
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
            if !reduceMotion && !thermalLimited, let oldPosition = lastPositions[entity.id], hypot(Double(newPosition.x - oldPosition.x), Double(newPosition.y - oldPosition.y)) > 0.6, let body = node.childNode(withName: "body") {
                body.removeAction(forKey: "walk-squash")
                body.run(.sequence([.scaleX(to: 0.93, duration: 0.06), .scaleX(to: 1.0, duration: 0.09)]), withKey: "walk-squash")
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
        for event in model.events where model.elapsed - event.born < 0.4 && (showDamageNumbers || !event.text.hasPrefix("−")) {
            let name = "event-\(event.id)"
            if childNode(withName: name) == nil {
                let label = SKLabelNode(text: event.text)
                label.name = name
                label.fontName = "AvenirNext-Bold"
                label.fontSize = max(8, min(12, tileWidth * 0.55))
                label.fontColor = .white
                label.position = CGPoint(x: CGFloat(event.x) * tileWidth, y: CGFloat(event.y) * tileHeight + tileHeight)
                label.zPosition = 1000
                addChild(label)
                if event.text.contains("CROWN") || event.text.contains("KING DOWN") {
                    if !reduceMotion && !thermalLimited { addDebris(at: CGPoint(x: CGFloat(event.x) * tileWidth, y: CGFloat(event.y) * tileHeight)) }
                    if event.text.contains("CROWN") && !reduceMotion { label.run(.sequence([.scale(to: 1.55, duration: 0.07), .scale(to: 1.0, duration: 0.12)])) }
                }
                if reduceMotion {
                    label.run(.sequence([.wait(forDuration: 0.25), .removeFromParent()]))
                } else {
                    label.run(.sequence([.group([.moveBy(x: 0, y: tileHeight, duration: 0.45), .fadeOut(withDuration: 0.45)]), .removeFromParent()]))
                }
            }
        }
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
    private func makeNode(_ entity: BattleEntity) -> SKNode {
        let root = SKNode()
        let shadow = SKShapeNode(ellipseOf: CGSize(width: entity.tower ? tileWidth * 1.6 : tileWidth, height: tileHeight * 0.3))
        shadow.position = CGPoint(x: tileWidth * 0.08, y: -tileHeight * 0.35)
        shadow.fillColor = .black.withAlphaComponent(0.25)
        shadow.strokeColor = .clear
        root.addChild(shadow)

        let bodySize = CGSize(width: entity.king ? tileWidth * 1.45 : (entity.tower ? tileWidth * 1.2 : tileWidth),
                              height: entity.king ? tileHeight * 1.45 : (entity.tower ? tileHeight * 1.2 : tileHeight))
        let definition = CardCatalog.byID[entity.cardID]
        let body: SKShapeNode
        if entity.tower || definition?.kind == .building {
            body = SKShapeNode(rectOf: bodySize, cornerRadius: 4)
        } else if definition?.behavior.contains(.flying) == true {
            body = SKShapeNode(ellipseOf: bodySize)
        } else if definition?.behavior.contains(.shield) == true {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: bodySize.height / 2))
            path.addLine(to: CGPoint(x: bodySize.width / 2, y: bodySize.height / 4))
            path.addLine(to: CGPoint(x: bodySize.width / 2, y: -bodySize.height / 4))
            path.addLine(to: CGPoint(x: 0, y: -bodySize.height / 2))
            path.addLine(to: CGPoint(x: -bodySize.width / 2, y: -bodySize.height / 4))
            path.addLine(to: CGPoint(x: -bodySize.width / 2, y: bodySize.height / 4))
            path.closeSubpath()
            body = SKShapeNode(path: path)
        } else if definition?.behavior.contains(.splash) == true {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: bodySize.height / 2))
            path.addLine(to: CGPoint(x: bodySize.width / 2, y: 0))
            path.addLine(to: CGPoint(x: 0, y: -bodySize.height / 2))
            path.addLine(to: CGPoint(x: -bodySize.width / 2, y: 0))
            path.closeSubpath()
            body = SKShapeNode(path: path)
        } else {
            body = SKShapeNode(rectOf: bodySize, cornerRadius: 8)
        }
        body.name = "body"
        body.fillColor = entity.team == .blue ? .systemBlue : .systemRed
        body.strokeColor = .white.withAlphaComponent(0.85)
        body.lineWidth = 1.2
        if !reduceMotion && !thermalLimited { body.run(.repeatForever(.sequence([.scale(to: 1.035, duration: 0.38), .scale(to: 1.0, duration: 0.38)])), withKey: "idle-breathe") }
        root.addChild(body)

        let label = SKLabelNode(text: entity.king ? "♛" : (entity.tower ? "◆" : String(CardCatalog.byID[entity.cardID]?.name.prefix(2).uppercased() ?? "•")))
        let markerPath = CGMutablePath()
        if entity.team == .blue {
            markerPath.move(to: CGPoint(x: bodySize.width * 0.55, y: bodySize.height * 0.52))
            markerPath.addLine(to: CGPoint(x: bodySize.width * 0.42, y: bodySize.height * 0.30))
            markerPath.addLine(to: CGPoint(x: bodySize.width * 0.68, y: bodySize.height * 0.30))
        } else {
            markerPath.move(to: CGPoint(x: bodySize.width * 0.42, y: bodySize.height * 0.52))
            markerPath.addLine(to: CGPoint(x: bodySize.width * 0.68, y: bodySize.height * 0.52))
            markerPath.addLine(to: CGPoint(x: bodySize.width * 0.55, y: bodySize.height * 0.30))
        }
        markerPath.closeSubpath()
        let marker = SKShapeNode(path: markerPath)
        marker.fillColor = entity.team == .blue ? .systemCyan : .systemOrange
        marker.strokeColor = .white
        marker.lineWidth = 0.5
        marker.zPosition = 4
        root.addChild(marker)

        label.fontName = "AvenirNext-Bold"
        label.fontSize = max(8, min(14, tileWidth * 0.62))
        label.verticalAlignmentMode = .center
        label.fontColor = .white
        label.zPosition = 2
        root.addChild(label)

        let hpBack = SKShapeNode(rectOf: CGSize(width: tileWidth * 1.25, height: max(2, tileHeight * 0.15)))
        hpBack.position = CGPoint(x: 0, y: entity.tower ? tileHeight * 0.95 : tileHeight * 0.75)
        hpBack.fillColor = .black
        hpBack.strokeColor = .clear
        root.addChild(hpBack)
        let hp = SKShapeNode(rectOf: CGSize(width: tileWidth * 1.2, height: max(2, tileHeight * 0.12)))
        hp.name = "hp"
        hp.position = CGPoint(x: -tileWidth * 0.025, y: hpBack.position.y)
        hp.fillColor = .systemGreen
        hp.strokeColor = .clear
        root.addChild(hp)

        if entity.deployClock > 0 {
            let ring = SKShapeNode(circleOfRadius: min(tileWidth, tileHeight) * 0.75)
            ring.strokeColor = .white.withAlphaComponent(0.8)
            ring.lineWidth = 2
            ring.fillColor = .clear
            root.addChild(ring)
            ring.run(.sequence([.wait(forDuration: entity.deployClock), .fadeOut(withDuration: 0.15), .removeFromParent()]))
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