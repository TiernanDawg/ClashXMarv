import Foundation
import Combine

enum Team: Int, Codable { case blue = 0, red = 1 }
struct BattleEntity: Identifiable, Codable {
    var id: Int
    var cardID: String
    var team: Team
    var x: Double
    var y: Double
    var hp: Double
    var maxHP: Double
    var attackClock = 0.0
    var deployClock = 0.0
    var lifetime = 0.0
    var tower = false
    var king = false
    var alive: Bool { hp > 0 }
}
struct BattleEvent: Identifiable {
    let id = UUID()
    let x: Double
    let y: Double
    let text: String
    let born: Double
}
@MainActor
final class BattleModel: ObservableObject {
    @Published private(set) var entities: [BattleEntity] = []
    @Published private(set) var blueElixir = Balance.startElixir
    @Published private(set) var redElixir = Balance.startElixir
    @Published private(set) var elapsed = 0.0
    @Published private(set) var banner = "BATTLE!"
    @Published private(set) var result: String?
    @Published private(set) var blueCrowns = 0
    @Published private(set) var redCrowns = 0
    @Published private(set) var hand: [String] = []
    @Published private(set) var nextCard = ""
    @Published private(set) var selectedCard: String?
    @Published private(set) var events: [BattleEvent] = []
    @Published private(set) var seed: UInt64
    private var queue: [String]
    private var entitySequence = 0
    private var aiClock = 2.4
    private var bannerClock = 3.0
    private var overtime = false
    private var energyClock = 0.0
    private var rng: UInt64
    private var lastEmote = -100.0
    var isFinished: Bool { result != nil }
    var timeText: String {
        let remaining = max(0, overtime ? 300 - elapsed : 180 - elapsed)
        return String(format: "%d:%02d", Int(remaining) / 60, Int(remaining) % 60)
    }
    init(deck: [String], seed: UInt64 = UInt64(Date().timeIntervalSince1970)) {
        let valid = deck.filter { CardCatalog.byID[$0] != nil }
        let chosen = Array((valid.count >= 8 ? valid : CardCatalog.starterDeck).prefix(8))
        queue = chosen
        self.seed = seed == 0 ? 1 : seed
        rng = self.seed
        hand = Array(queue.prefix(4))
        nextCard = queue.dropFirst(4).first ?? queue[0]
        addTower(.blue, 3.2, 2, false); addTower(.blue, 14.8, 2, false); addTower(.blue, 9, 0.7, true)
        addTower(.red, 3.2, 30, false); addTower(.red, 14.8, 30, false); addTower(.red, 9, 31.3, true)
    }
    private func random() -> UInt64 {
        rng ^= rng << 13; rng ^= rng >> 7; rng ^= rng << 17
        return rng
    }
    private func addTower(_ team: Team, _ x: Double, _ y: Double, _ king: Bool) {
        entitySequence += 1
        entities.append(BattleEntity(id: entitySequence, cardID: "tower", team: team, x: x, y: y, hp: king ? 4200 : 2600, maxHP: king ? 4200 : 2600, tower: true, king: king))
    }
    func select(_ id: String) {
        guard hand.contains(id), let card = CardCatalog.byID[id], card.cost <= Int(floor(blueElixir)) else { return }
        selectedCard = id
    }
    func cancelSelection() { selectedCard = nil }
    func deploySelected(x: Double, y: Double) -> Bool {
        guard let id = selectedCard else { return false }
        return deploy(id: id, x: x, y: y, team: .blue)
    }
    @discardableResult
    func deploy(id: String, x: Double, y: Double, team: Team) -> Bool {
        guard !isFinished, let card = CardCatalog.byID[id] else { return false }
        let xx = min(17.5, max(0.5, x)), yy = min(31.5, max(0.5, y))
        if team == .blue {
            guard hand.contains(id), blueElixir >= Double(card.cost), card.kind == .spell || yy <= 15.5 else { return false }
            blueElixir -= Double(card.cost); cycle(id); selectedCard = nil
        } else {
            guard redElixir >= Double(card.cost), card.kind == .spell || yy >= 16.5 else { return false }
            redElixir -= Double(card.cost)
        }
        if card.kind == .spell { cast(card, x: xx, y: yy, team: team); return true }
        entitySequence += 1
        let hp = max(1, card.hp * Balance.levelMultiplier(1))
        entities.append(BattleEntity(id: entitySequence, cardID: card.id, team: team, x: xx, y: yy, hp: hp, maxHP: hp, deployClock: Balance.deployDelay, lifetime: card.kind == .building ? 30 : 0))
        events.append(BattleEvent(x: xx, y: yy, text: "DEPLOY", born: elapsed))
        return true
    }
    private func cycle(_ id: String) {
        if let index = queue.firstIndex(of: id) { queue.remove(at: index); queue.append(id) }
        hand = Array(queue.prefix(4)); nextCard = queue.dropFirst(4).first ?? queue[0]
    }
    private func cast(_ card: CardDefinition, x: Double, y: Double, team: Team) {
        let radius = card.behavior.contains(.areaOverTime) ? 3.2 : 2.7
        if card.behavior.contains(.clone) {
            let clones = entities.filter { $0.alive && !$0.tower && $0.team == team && hypot($0.x - x, $0.y - y) <= radius }
            for unit in clones.prefix(8) {
                entitySequence += 1
                let hp = max(1, unit.hp * 0.3)
                entities.append(BattleEntity(id: entitySequence, cardID: unit.cardID, team: team, x: unit.x + 0.2, y: unit.y + 0.2, hp: hp, maxHP: hp, deployClock: 0.25))
            }
        } else {
            for i in entities.indices where entities[i].alive && entities[i].team != team && hypot(entities[i].x - x, entities[i].y - y) <= radius {
                entities[i].hp -= card.damage * (entities[i].tower ? 0.55 : 1)
                if card.behavior.contains(.stun) { entities[i].attackClock += 0.7 }
            }
        }
        events.append(BattleEvent(x: x, y: y, text: card.name.uppercased(), born: elapsed))
        if card.behavior.contains(.elixirPump) && team == .blue { blueElixir = min(10, blueElixir + 1) }
    }
    func emote(_ label: String) -> Bool {
        guard elapsed - lastEmote >= 4, !isFinished else { return false }
        lastEmote = elapsed; events.append(BattleEvent(x: 9, y: 7, text: label, born: elapsed)); return true
    }
    func tick() {
        guard !isFinished else { return }
        elapsed += Balance.tick
        energyClock += Balance.tick
        bannerClock = max(0, bannerClock - Balance.tick)
        events.removeAll { elapsed - $0.born > 1.4 }
        let localElapsed = overtime ? elapsed - 180 : elapsed
        let interval = overtime && localElapsed >= 60 ? 0.93 : (elapsed >= 120 ? 1.4 : 2.8)
        if energyClock >= interval {
            energyClock -= interval
            blueElixir = min(10, blueElixir + 1); redElixir = min(10, redElixir + 1)
        }
        if elapsed >= 120 && elapsed < 121 { banner = "DOUBLE ELIXIR"; bannerClock = 2.8 }
        if overtime && elapsed >= 240 && elapsed < 241 { banner = "TRIPLE ELIXIR"; bannerClock = 2.8 }
        aiClock -= Balance.tick
        if aiClock <= 0 { playAI(); aiClock = 1.8 + Double(random() % 260) / 100 }
        moveAndFight(); resolveTowers()
        if !overtime && elapsed >= 180 {
            if blueCrowns != redCrowns { finish(blueCrowns > redCrowns ? "VICTORY" : "DEFEAT") }
            else { overtime = true; banner = "SUDDEN DEATH"; bannerClock = 3 }
        } else if overtime && elapsed >= 300 {
            let blueHP = entities.filter { $0.team == .blue && $0.tower }.reduce(0) { $0 + max(0, $1.hp) }
            let redHP = entities.filter { $0.team == .red && $0.tower }.reduce(0) { $0 + max(0, $1.hp) }
            finish(abs(blueHP - redHP) < 1 ? "DRAW" : (blueHP > redHP ? "VICTORY" : "DEFEAT"))
        }
        if bannerClock <= 0 { banner = "" }
    }
    private func playAI() {
        let affordable = CardCatalog.all.filter { $0.cost <= Int(floor(redElixir)) && $0.kind != .spell }
        guard !affordable.isEmpty else { return }
        let choice = affordable[Int(random() % UInt64(affordable.count))]
        let lane = random() % 2 == 0 ? 3.2 : 14.8
        _ = deploy(id: choice.id, x: lane, y: 22 + Double(random() % 65) / 10, team: .red)
    }
    private func moveAndFight() {
        for i in entities.indices {
            guard entities[i].alive else { continue }
            if entities[i].deployClock > 0 { entities[i].deployClock = max(0, entities[i].deployClock - Balance.tick); continue }
            if entities[i].tower {
                entities[i].attackClock -= Balance.tick
                if entities[i].attackClock <= 0, let target = nearestTarget(from: entities[i], range: 5.8) {
                    entities[target].hp -= 100; entities[i].attackClock = 0.9
                }
                continue
            }
            guard let card = CardCatalog.byID[entities[i].cardID] else { continue }
            if card.kind == .building {
                entities[i].lifetime -= Balance.tick
                if entities[i].lifetime <= 0 { entities[i].hp = 0; continue }
            }
            entities[i].attackClock -= Balance.tick
            if let target = nearestTarget(from: entities[i], range: max(card.range, Balance.sightRange)) {
                let distance = hypot(entities[target].x - entities[i].x, entities[target].y - entities[i].y)
                if distance <= card.range + 0.35 && card.range > 0 {
                    if entities[i].attackClock <= 0 {
                        let damage = card.damage * (card.behavior.contains(.rampBeam) ? 1.45 : 1)
                        if card.behavior.contains(.splash) {
                            for j in entities.indices where entities[j].alive && entities[j].team != entities[i].team && hypot(entities[j].x - entities[target].x, entities[j].y - entities[target].y) <= 1.5 { entities[j].hp -= damage * 0.75 }
                        } else { entities[target].hp -= damage }
                        if card.behavior.contains(.heal) { entities[i].hp = min(entities[i].maxHP, entities[i].hp + 25) }
                        if card.behavior.contains(.stun) { entities[target].attackClock += 0.35 }
                        if card.behavior.contains(.slow) { entities[target].attackClock += 0.25 }
                        entities[i].attackClock = card.hitSpeed
                        events.append(BattleEvent(x: entities[target].x, y: entities[target].y, text: "−\(Int(damage))", born: elapsed))
                    }
                    continue
                }
            }
            let laneX = entities[i].x < 9 ? 3.2 : 14.8
            let targetY = entities[i].team == .blue ? 30.0 : 2.0
            let dx = laneX - entities[i].x, dy = targetY - entities[i].y
            let distance = max(0.001, hypot(dx, dy))
            let step = card.speed * Balance.tick
            if !card.behavior.contains(.flying) && entities[i].y > 14 && entities[i].y < 18 {
                let bridgeX = entities[i].x < 9 ? 3.2 : 14.8
                entities[i].x += (bridgeX - entities[i].x) * min(1, step)
            } else {
                entities[i].x += dx / distance * step
                entities[i].y += dy / distance * step
            }
            entities[i].x = min(17.5, max(0.5, entities[i].x)); entities[i].y = min(31.5, max(0.5, entities[i].y))
        }
        for tower in entities where tower.tower && !tower.king && !tower.alive {
            if overtime {
                finish(tower.team == .blue ? "DEFEAT" : "VICTORY")
            }
            if tower.team == .blue { redCrowns = min(3, redCrowns + 1) }
            else { blueCrowns = min(3, blueCrowns + 1) }
        }
        entities.removeAll { !$0.alive }
    }
    private func nearestTarget(from entity: BattleEntity, range: Double) -> Int? {
        entities.indices.filter { i in
            let t = entities[i]
            return t.alive && t.team != entity.team && t.id != entity.id && !(entity.tower && t.tower) && hypot(t.x - entity.x, t.y - entity.y) <= range
        }.min { a, b in
            if entities[a].tower != entities[b].tower { return !entities[a].tower }
            return hypot(entities[a].x - entity.x, entities[a].y - entity.y) < hypot(entities[b].x - entity.x, entities[b].y - entity.y)
        }
    }
    private func resolveTowers() {
        if entities.contains(where: { $0.tower && $0.king && $0.team == .blue && !$0.alive }) { redCrowns = 3; finish("DEFEAT") }
        if entities.contains(where: { $0.tower && $0.king && $0.team == .red && !$0.alive }) { blueCrowns = 3; finish("VICTORY") }
    }
    private func finish(_ outcome: String) { result = outcome; banner = outcome }
    func saveRecord(profile: ProfileStore) {
        guard let result else { return }
        profile.update { p in
            if result == "VICTORY" { p.wins += 1; p.trophies += 28; p.gold += 35; p.xp += 25; p.crowns += blueCrowns }
            else if result == "DEFEAT" { p.losses += 1; p.trophies = max(0, p.trophies - 18); p.gold += 15; p.xp += 10 }
            p.kingLevel = min(50, 1 + p.xp / 100)
            p.dailyCrowns = min(10, p.dailyCrowns + blueCrowns)
            p.battleLog.insert(BattleRecord(result: result, crowns: blueCrowns, opponent: "Arena Rival", seed: seed), at: 0)
            p.battleLog = Array(p.battleLog.prefix(30))
        }
    }
}