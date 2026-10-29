import SpriteKit
import UIKit

final class ArenaScene: SKScene {
    weak var battle: BattleModel?
    private var entityNodes: [Int: SKNode] = [:]
    private var ghost: SKShapeNode?
    private var gridPreview: SKShapeNode?
    private var lastTile = CGPoint(x: -999, y: -999)
    var onDrop: ((Double, Double) -> Void)?
    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.10, green: 0.30, blue: 0.22, alpha: 1)
        drawArena()
    }
    private func drawArena() {
        removeAllChildren(); entityNodes.removeAll()
        let field = SKShapeNode(rect: CGRect(x: 8, y: 8, width: size.width - 16, height: size.height - 16), cornerRadius: 12)
        field.fillColor = UIColor(red: 0.17, green: 0.43, blue: 0.29, alpha: 1)
        field.strokeColor = UIColor(red: 0.42, green: 0.62, blue: 0.37, alpha: 1); field.lineWidth = 3; field.zPosition = -10; addChild(field)
        for x in 1...17 {
            for y in 1...31 where (x + y) % 2 == 0 {
                let tile = SKShapeNode(rectOf: CGSize(width: 19, height: 19), cornerRadius: 2)
                tile.position = CGPoint(x: CGFloat(x) * 20, y: CGFloat(y) * 20)
                tile.fillColor = UIColor.white.withAlphaComponent(0.025); tile.strokeColor = .clear; tile.zPosition = -9
                addChild(tile)
            }
        }
        let river = SKShapeNode(rectOf: CGSize(width: size.width, height: 34))
        river.position = CGPoint(x: size.width / 2, y: size.height / 2)
        river.fillColor = UIColor(red: 0.12, green: 0.52, blue: 0.75, alpha: 1); river.strokeColor = .clear; river.zPosition = -5; addChild(river)
        for x in [64.0, 296.0] {
            let bridge = SKShapeNode(rectOf: CGSize(width: 46, height: 48), cornerRadius: 4)
            bridge.position = CGPoint(x: x, y: size.height / 2); bridge.fillColor = UIColor(red: 0.61, green: 0.42, blue: 0.25, alpha: 1)
            bridge.strokeColor = UIColor(red: 0.83, green: 0.65, blue: 0.40, alpha: 1); bridge.lineWidth = 2; bridge.zPosition = -3; addChild(bridge)
        }
        for y in stride(from: 40.0, through: size.height - 40, by: 80) {
            let line = SKShapeNode(rectOf: CGSize(width: size.width - 24, height: 1))
            line.position = CGPoint(x: size.width / 2, y: y); line.fillColor = .white.withAlphaComponent(0.08); line.strokeColor = .clear; line.zPosition = -2; addChild(line)
        }
    }
    func render(_ model: BattleModel) {
        let alive = Set(model.entities.map(\.id))
        for id in Array(entityNodes.keys) where !alive.contains(id) { entityNodes[id]?.removeFromParent(); entityNodes.removeValue(forKey: id) }
        for entity in model.entities {
            let node: SKNode
            if let existing = entityNodes[entity.id] { node = existing }
            else { node = makeNode(entity); entityNodes[entity.id] = node; addChild(node) }
            node.position = CGPoint(x: entity.x * 20, y: entity.y * 20)
            node.zPosition = CGFloat(entity.y)
            if let badge = node.childNode(withName: "hp") as? SKShapeNode {
                let ratio = max(0, min(1, entity.hp / max(1, entity.maxHP)))
                badge.xScale = ratio
                badge.fillColor = ratio > 0.5 ? .systemGreen : (ratio > 0.25 ? .systemYellow : .systemRed)
            }
            if let body = node.childNode(withName: "body") as? SKShapeNode {
                body.fillColor = entity.team == .blue ? UIColor(red: 0.20, green: 0.58, blue: 0.98, alpha: 1) : UIColor(red: 0.96, green: 0.25, blue: 0.30, alpha: 1)
                if entity.tower { body.fillColor = entity.king ? .systemYellow : (entity.team == .blue ? .systemTeal : .systemPink) }
            }
        }
        for event in model.events where elapsedSince(event.born, model.elapsed) < 0.4 {
            if childNode(withName: "event-\(event.id)") == nil {
                let label = SKLabelNode(text: event.text)
                label.name = "event-\(event.id)"; label.fontName = "AvenirNext-Bold"; label.fontSize = 10
                label.fontColor = .white; label.position = CGPoint(x: event.x * 20, y: event.y * 20 + 18)
                label.zPosition = 1000; addChild(label)
                label.run(.sequence([.group([.moveBy(x: 0, y: 22, duration: 0.45), .fadeOut(withDuration: 0.45)]), .removeFromParent()]))
            }
        }
        if let id = model.selectedCard, let card = CardCatalog.byID[id] {
            if ghost == nil {
                let g = SKShapeNode(circleOfRadius: card.kind == .spell ? 28 : 17)
                g.fillColor = UIColor.systemGreen.withAlphaComponent(0.22); g.strokeColor = .systemGreen; g.lineWidth = 2; g.zPosition = 500
                ghost = g; addChild(g)
            }
            if let ghost { ghost.isHidden = false }
        } else { ghost?.isHidden = true; gridPreview?.isHidden = true }
    }
    private func elapsedSince(_ start: Double, _ now: Double) -> Double { now - start }
    private func makeNode(_ entity: BattleEntity) -> SKNode {
        let root = SKNode()
        let shadow = SKShapeNode(ellipseOf: CGSize(width: entity.tower ? 32 : 20, height: 9))
        shadow.position = CGPoint(x: 2, y: -7); shadow.fillColor = .black.withAlphaComponent(0.25); shadow.strokeColor = .clear; root.addChild(shadow)
        let body = SKShapeNode(rectOf: CGSize(width: entity.king ? 29 : (entity.tower ? 24 : 20), height: entity.king ? 29 : (entity.tower ? 24 : 20), cornerRadius: entity.tower ? 5 : 10))
        body.name = "body"; body.fillColor = entity.team == .blue ? .systemBlue : .systemRed; body.strokeColor = .white.withAlphaComponent(0.85); body.lineWidth = 1.4; root.addChild(body)
        let label = SKLabelNode(text: entity.king ? "♛" : (entity.tower ? "◆" : String(CardCatalog.byID[entity.cardID]?.name.first ?? "•")))
        label.fontName = "AvenirNext-Bold"; label.fontSize = entity.tower ? 14 : 10; label.verticalAlignmentMode = .center; label.fontColor = .white; label.zPosition = 2; root.addChild(label)
        let hpBack = SKShapeNode(rectOf: CGSize(width: 25, height: 3))
        hpBack.position = CGPoint(x: 0, y: entity.tower ? 19 : 15); hpBack.fillColor = .black; hpBack.strokeColor = .clear; root.addChild(hpBack)
        let hp = SKShapeNode(rectOf: CGSize(width: 24, height: 2.5))
        hp.name = "hp"; hp.position = CGPoint(x: -0.5, y: entity.tower ? 19 : 15); hp.fillColor = .systemGreen; hp.strokeColor = .clear; root.addChild(hp)
        if entity.deployClock > 0 {
            let ring = SKShapeNode(circleOfRadius: 15); ring.strokeColor = .white.withAlphaComponent(0.8); ring.lineWidth = 2; ring.fillColor = .clear; root.addChild(ring)
            ring.run(.sequence([.wait(forDuration: entity.deployClock), .fadeOut(withDuration: 0.15), .removeFromParent()]))
        }
        return root
    }
    private func boardPoint(_ point: CGPoint) -> (Double, Double) {
        (min(17.5, max(0.5, point.x / 20)), min(31.5, max(0.5, point.y / 20)))
    }
    private func valid(_ y: Double) -> Bool {
        guard let id = battle?.selectedCard, let card = CardCatalog.byID[id] else { return false }
        return card.kind == .spell || y <= 15.5
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, battle?.selectedCard != nil else { return }
        updateGhost(at: touch.location(in: self))
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, battle?.selectedCard != nil else { return }
        updateGhost(at: touch.location(in: self))
    }
    private func updateGhost(at point: CGPoint) {
        let (x, y) = boardPoint(point)
        let tile = CGPoint(x: floor(x), y: floor(y))
        if tile != lastTile { UISelectionFeedbackGenerator().selectionChanged(); lastTile = tile }
        if ghost == nil {
            let g = SKShapeNode(circleOfRadius: 17); g.zPosition = 500; ghost = g; addChild(g)
        }
        ghost?.isHidden = false
        ghost?.position = CGPoint(x: CGFloat(x * 20), y: CGFloat(y * 20 + 24))
        ghost?.fillColor = (valid(y) ? UIColor.systemGreen : UIColor.systemRed).withAlphaComponent(0.22)
        ghost?.strokeColor = valid(y) ? .systemGreen : .systemRed
        if gridPreview == nil {
            let p = SKShapeNode(rectOf: CGSize(width: 19, height: 19), cornerRadius: 2); p.zPosition = 490; gridPreview = p; addChild(p)
        }
        gridPreview?.isHidden = false; gridPreview?.position = CGPoint(x: CGFloat((floor(x) + 0.5) * 20), y: CGFloat((floor(y) + 0.5) * 20))
        gridPreview?.fillColor = (valid(y) ? UIColor.systemGreen : UIColor.systemRed).withAlphaComponent(0.28)
        gridPreview?.strokeColor = valid(y) ? .systemGreen : .systemRed
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let (x, y) = boardPoint(touch.location(in: self))
        if valid(y) { UIImpactFeedbackGenerator(style: .medium).impactOccurred(); onDrop?(x, y) }
        else { battle?.cancelSelection() }
        ghost?.isHidden = true; gridPreview?.isHidden = true
    }
}