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
    var spawnClock = 0.0
    var beamRamp = 1.0
    var stunClock = 0.0
    var slowClock = 0.0
    var rageClock = 0.0
    var shieldHP = 0.0
    var hasAttacked = false
    var levelMultiplier = 1.0
    var travelSinceAttack = 0.0
    var tower = false
    var king = false
    var awake = false
    var alive: Bool { hp > 0 }
}
struct TimedSpell: Codable {
    var cardID: String
    var team: Team
    var x: Double
    var y: Double
    var remaining: Double
    var tickClock: Double = 0
}
struct BattleSnapshot: Codable {
    var version = 1
    var savedAt = Date()
    var seed: UInt64
    var elapsed: Double
    var energyClock: Double
    var overtime: Bool
    var blueElixir: Double
    var redElixir: Double
    var blueCrowns: Int
    var redCrowns: Int
    var entities: [BattleEntity]
    var hand: [String]
    var nextCard: String
    var queue: [String]
    var redQueue: [String]
    var redHand: [String]
    var originalDeck: [String]
    var entitySequence: Int
    var aiClock: Double
    var blueAIClock: Double
    var bannerClock: Double
    var rng: UInt64
    var lastEmote: Double
    var opponentEmoteClock: Double
    var fallenTowerKeys: Set<String>
    var processedDeaths: Set<Int>
    var activeSpells: [TimedSpell]
    var lastBlueCard: String?
    var lastRedCard: String?
    var actions: [BattleAction]
    var cardLevels: [String: Int]
    var botLevel: Int
    var trophyBand: Int
    var isValid: Bool {
        version == 1 && elapsed.isFinite && elapsed >= 0 && elapsed < 300 &&
        energyClock.isFinite && blueElixir.isFinite && redElixir.isFinite &&
        blueElixir >= 0 && blueElixir <= 10 && redElixir >= 0 && redElixir <= 10 &&
        entities.count <= 1000 && hand.count == 4 && redHand.count == 4 &&
        queue.count == 8 && redQueue.count == 8 && originalDeck.count == 8 &&
        entities.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.hp.isFinite && $0.maxHP.isFinite && $0.x >= 0 && $0.x <= 18 && $0.y >= 0 && $0.y <= 32 && ($0.cardID == "tower" || CardCatalog.byID[$0.cardID] != nil) } &&
        activeSpells.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.remaining.isFinite && CardCatalog.byID[$0.cardID] != nil }
    }
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
    @Published private(set) var actions: [BattleAction] = []
    @Published private(set) var seed: UInt64
    private var queue: [String]
    private let originalDeck: [String]
    private let replayActions: [BattleAction]
    private let isReplaying: Bool
    private let cardLevels: [String: Int]
    private let botLevel: Int
    private let trophyBand: Int
    private var replayIndex = 0
    private var redQueue: [String] = []
    private var redHand: [String] = []
    private var entitySequence = 0
    private var aiClock = 2.4
    private var blueAIClock = 1.7
    private let automatedBlue: Bool
    private var bannerClock = 3.0
    private var overtime = false
    private var energyClock = 0.0
    private var rng: UInt64
    private var lastEmote = -100.0
    private var opponentEmoteClock = 24.0
    private var opponentEmotesMuted = false
    private var soundEnabled = true
    private var fallenTowerKeys = Set<String>()
    private var processedDeaths = Set<Int>()
    private var lastDamageEventTime: [Int: Double] = [:]
    private var activeSpells: [TimedSpell] = []
    private var lastBlueCard: String?
    private var lastRedCard: String?
    var isFinished: Bool { result != nil }
    var timeText: String {
        let remaining = max(0, overtime ? 300 - elapsed : 180 - elapsed)
        return String(format: "%d:%02d", Int(remaining) / 60, Int(remaining) % 60)
    }
    init(deck: [String], seed: UInt64 = UInt64(Date().timeIntervalSince1970), automatedBlue: Bool = false, replayActions: [BattleAction] = [], isReplaying: Bool = false, cardLevels: [String: Int] = [:], trophies: Int = 0) {
        let valid = deck.filter { CardCatalog.byID[$0] != nil }
        let chosen = Array((valid.count >= 8 ? valid : CardCatalog.starterDeck).prefix(8))
        queue = chosen
        originalDeck = chosen
        self.cardLevels = cardLevels
        trophyBand = max(0, min(12, trophies / 300))
        let levelTotal = chosen.reduce(0) { $0 + max(1, min(13, cardLevels[$1] ?? 1)) }
        botLevel = max(1, min(13, Int((Double(levelTotal) / Double(max(1, chosen.count))).rounded())))
        self.replayActions = replayActions.sorted { $0.time < $1.time }
        self.isReplaying = isReplaying
        self.automatedBlue = automatedBlue
        let normalizedSeed = seed == 0 ? 1 : seed
        self.seed = normalizedSeed
        rng = normalizedSeed
        let offset = Int(random() % UInt64(max(1, queue.count)))
        queue = Array(queue[offset...]) + Array(queue[..<offset])
        hand = Array(queue.prefix(4))
        nextCard = queue.dropFirst(4).first ?? queue[0]
        redQueue = CardCatalog.starterDeck
        let redOffset = Int(random() % UInt64(max(1, redQueue.count)))
        redQueue = Array(redQueue[redOffset...]) + Array(redQueue[..<redOffset])
        redHand = Array(redQueue.prefix(4))
        addTower(.blue, 3.2, 2, false); addTower(.blue, 14.8, 2, false); addTower(.blue, 9, 0.7, true)
        addTower(.red, 3.2, 30, false); addTower(.red, 14.8, 30, false); addTower(.red, 9, 31.3, true)
        aiClock = max(1.2, 3.4 - Double(trophyBand) * 0.12) + Double(random() % 100) / 100
    }
    init(snapshot: BattleSnapshot) {
        seed = snapshot.seed
        elapsed = snapshot.elapsed
        energyClock = snapshot.energyClock
        overtime = snapshot.overtime
        blueElixir = snapshot.blueElixir
        redElixir = snapshot.redElixir
        blueCrowns = snapshot.blueCrowns
        redCrowns = snapshot.redCrowns
        entities = snapshot.entities
        hand = snapshot.hand
        nextCard = snapshot.nextCard
        selectedCard = nil
        actions = snapshot.actions
        queue = snapshot.queue
        originalDeck = snapshot.originalDeck
        redQueue = snapshot.redQueue
        redHand = snapshot.redHand
        entitySequence = snapshot.entitySequence
        aiClock = snapshot.aiClock
        blueAIClock = snapshot.blueAIClock
        bannerClock = snapshot.bannerClock
        rng = snapshot.rng
        lastEmote = snapshot.lastEmote
        opponentEmoteClock = snapshot.opponentEmoteClock
        fallenTowerKeys = snapshot.fallenTowerKeys
        processedDeaths = snapshot.processedDeaths
        activeSpells = snapshot.activeSpells
        lastBlueCard = snapshot.lastBlueCard
        lastRedCard = snapshot.lastRedCard
        cardLevels = snapshot.cardLevels
        botLevel = snapshot.botLevel
        trophyBand = snapshot.trophyBand
        replayActions = []
        isReplaying = false
        automatedBlue = false
        banner = elapsed >= 240 ? "TRIPLE ELIXIR" : (elapsed >= 120 ? "DOUBLE ELIXIR" : "BATTLE!")
    }
    func snapshot() -> BattleSnapshot? {
        guard !isFinished, !isReplaying else { return nil }
        return BattleSnapshot(seed: seed, elapsed: elapsed, energyClock: energyClock, overtime: overtime,
            blueElixir: blueElixir, redElixir: redElixir, blueCrowns: blueCrowns, redCrowns: redCrowns,
            entities: entities, hand: hand, nextCard: nextCard, queue: queue, redQueue: redQueue, redHand: redHand,
            originalDeck: originalDeck, entitySequence: entitySequence, aiClock: aiClock, blueAIClock: blueAIClock,
            bannerClock: bannerClock, rng: rng, lastEmote: lastEmote, opponentEmoteClock: opponentEmoteClock,
            fallenTowerKeys: fallenTowerKeys, processedDeaths: processedDeaths, activeSpells: activeSpells,
            lastBlueCard: lastBlueCard, lastRedCard: lastRedCard, actions: actions, cardLevels: cardLevels,
            botLevel: botLevel, trophyBand: trophyBand)
    }
    private func random() -> UInt64 {
        rng ^= rng << 13; rng ^= rng >> 7; rng ^= rng << 17
        return rng
    }
    private func addTower(_ team: Team, _ x: Double, _ y: Double, _ king: Bool) {
        entitySequence += 1
        let multiplier = Balance.levelMultiplier(botLevel)
        let hp = (king ? 4200.0 : 2600.0) * multiplier
        entities.append(BattleEntity(id: entitySequence, cardID: "tower", team: team, x: x, y: y, hp: hp, maxHP: hp, levelMultiplier: multiplier, tower: true, king: king, awake: !king))
    }
    func select(_ id: String) {
        guard hand.contains(id), CardCatalog.byID[id] != nil, cost(for: id) <= Int(floor(blueElixir)) else { return }
        selectedCard = id
    }
    func cancelSelection() { selectedCard = nil }
    func cost(for id: String) -> Int {
        guard let card = CardCatalog.byID[id] else { return 0 }
        if card.behavior.contains(.mirror) {
            return min(10, (lastBlueCard.flatMap { CardCatalog.byID[$0]?.cost } ?? 0) + 1)
        }
        return card.cost
    }
    func isValidPlacement(x: Double, y: Double) -> Bool {
        guard let id = selectedCard, let card = CardCatalog.byID[id], cost(for: id) <= Int(floor(blueElixir)) else { return false }
        let actual = card.behavior.contains(.mirror) ? lastBlueCard.flatMap { CardCatalog.byID[$0] } : card
        guard let actual else { return false }
        return actual.kind == .spell || actual.behavior.contains(.tunnel) || canDeploy(team: .blue, x: x, y: y)
    }
    func deploySelected(x: Double, y: Double) -> Bool {
        guard let id = selectedCard else { return false }
        return deploy(id: id, x: x, y: y, team: .blue)
    }
    @discardableResult
    func deploy(id: String, x: Double, y: Double, team: Team) -> Bool {
        guard !isFinished, let selectedDefinition = CardCatalog.byID[id] else { return false }
        let isMirror = selectedDefinition.behavior.contains(.mirror)
        let previousID = team == .blue ? lastBlueCard : lastRedCard
        let actualID = isMirror ? (previousID ?? "") : id
        guard let card = CardCatalog.byID[actualID] else { return false }
        let cost = isMirror ? min(10, card.cost + 1) : selectedDefinition.cost
        let xx = min(17.5, max(0.5, x)), yy = min(31.5, max(0.5, y))
        if team == .blue {
            guard hand.contains(id), blueElixir >= Double(cost), card.kind == .spell || card.behavior.contains(.tunnel) || canDeploy(team: .blue, x: xx, y: yy) else { return false }
            blueElixir -= Double(cost); cycle(id); selectedCard = nil
            if !isMirror { lastBlueCard = id }
            if !automatedBlue && !isReplaying { actions.append(BattleAction(time: elapsed, cardID: id, x: xx, y: yy)) }
        } else {
            guard redElixir >= Double(cost), redHand.contains(id), card.kind == .spell || card.behavior.contains(.tunnel) || canDeploy(team: .red, x: xx, y: yy) else { return false }
            redElixir -= Double(cost)
            if !isMirror { lastRedCard = id }
            if let index = redQueue.firstIndex(of: id) { redQueue.remove(at: index); redQueue.append(id) }
            redHand = Array(redQueue.prefix(4))
        }
        if card.kind == .spell { cast(card, x: xx, y: yy, team: team); return true }
        entitySequence += 1
        let multiplier = Balance.levelMultiplier(team == .blue ? max(1, min(13, cardLevels[card.id] ?? 1)) : botLevel)
        let hp = max(1, card.hp * multiplier)
        let count = card.kind == .troop ? max(1, card.unitCount) : 1
        for index in 0..<count {
            entitySequence += 1
            let spread = Double(index) - Double(count - 1) / 2
            entities.append(BattleEntity(id: entitySequence, cardID: card.id, team: team,
                x: min(17.5, max(0.5, xx + spread * 0.28)), y: min(31.5, max(0.5, yy + abs(spread) * 0.12)),
                hp: hp, maxHP: hp, deployClock: Balance.deployDelay,
                lifetime: card.kind == .building ? 30 : 0, spawnClock: (card.behavior.contains(.spawner) || card.behavior.contains(.elixirPump)) ? 5.0 : 0, shieldHP: card.behavior.contains(.shield) ? 100 * multiplier : 0, levelMultiplier: multiplier))
        }
        events.append(BattleEvent(x: xx, y: yy, text: isMirror ? "MIRRORED" : (card.behavior.contains(.tunnel) ? "TUNNEL" : "DEPLOY"), born: elapsed))
        if card.behavior.contains(.jump) {
            for i in entities.indices where entities[i].alive && entities[i].team != team && hypot(entities[i].x - xx, entities[i].y - yy) <= 1.35 {
                applyDamage(i, amount: card.damage * 1.1 * entities[i].levelMultiplier)
            }
            events.append(BattleEvent(x: xx, y: yy, text: "JUMP SLAM", born: elapsed))
        }
        return true
    }
    private func canDeploy(team: Team, x: Double, y: Double) -> Bool {
        let baseValid = team == .blue ? y <= 15.5 : y >= 16.5
        if baseValid { return true }
        let laneTowerX = x < 9 ? 3.2 : 14.8
        let opponent: Team = team == .blue ? .red : .blue
        let pocketOpen = fallenTowerKeys.contains("\(opponent.rawValue)-\(laneTowerX < 9 ? "left" : "right")")
        return pocketOpen && (team == .blue ? y <= 19.5 : y >= 12.5)
    }
    private func cycle(_ id: String) {
        if let index = queue.firstIndex(of: id) { queue.remove(at: index); queue.append(id) }
        hand = Array(queue.prefix(4)); nextCard = queue.dropFirst(4).first ?? queue[0]
    }
    private func cast(_ card: CardDefinition, x: Double, y: Double, team: Team) {
        let analog = card.analog.lowercased()
        if soundEnabled { ProceduralAudio.shared.play(.spell, enabled: true) }
        if analog.contains("rage") {
            activeSpells.append(TimedSpell(cardID: card.id, team: team, x: x, y: y, remaining: 6.0))
            events.append(BattleEvent(x: x, y: y, text: "RAGE!", born: elapsed))
            return
        }
        if analog.contains("goblin barrel") || analog.contains("skeleton barrel") {
            let child = analog.contains("goblin barrel") ? (CardCatalog.all.first { $0.analog == "Goblins" }?.id ?? "green-gobbler") : (CardCatalog.all.first { $0.analog == "Skeletons" }?.id ?? "ant-dude-swarm")
            for n in 0..<3 { createSpawn(team: team, x: x + (Double(n) - 1) * 0.35, y: y, cardID: child, scale: 1.0) }
            events.append(BattleEvent(x: x, y: y, text: "BARREL!", born: elapsed))
            return
        }
        let radius: Double
        if analog.contains("rocket") { radius = 2.0 }
        else if analog.contains("arrows") || analog.contains("graveyard") { radius = 4.0 }
        else if analog.contains("log") { radius = 3.8 }
        else if analog.contains("poison") || analog.contains("earthquake") || analog.contains("freeze") || analog.contains("tornado") { radius = 3.4 }
        else if analog.contains("barrel") { radius = 1.5 }
        else { radius = 2.7 }
        if card.behavior.contains(.areaOverTime) {
            activeSpells.append(TimedSpell(cardID: card.id, team: team, x: x, y: y, remaining: 5.0))
        }
        if card.behavior.contains(.clone) {
            let clones = entities.filter { $0.alive && !$0.tower && $0.team == team && hypot($0.x - x, $0.y - y) <= radius }
            for unit in clones.prefix(8) {
                entitySequence += 1
                let hp = max(1, unit.hp * 0.3)
                entities.append(BattleEntity(id: entitySequence, cardID: unit.cardID, team: team, x: unit.x + 0.2, y: unit.y + 0.2, hp: hp, maxHP: hp, deployClock: 0.25))
            }
        } else {
            let candidates = entities.indices.filter { index in
                let target = entities[index]
                guard target.alive && target.team != team else { return false }
                if analog.contains("earthquake") && !target.tower && CardCatalog.byID[target.cardID]?.kind != .building { return false }
                let dx = analog.contains("log") ? (target.x - x) * 0.55 : target.x - x
                return hypot(dx, target.y - y) <= radius
            }.sorted { analog.contains("lightning") ? entities[$0].hp > entities[$1].hp : entities[$0].hp < entities[$1].hp }
            let limit = analog.contains("lightning") ? min(3, candidates.count) : candidates.count
            for index in candidates.prefix(limit) {
                let dx = analog.contains("log") ? (entities[index].x - x) * 0.55 : entities[index].x - x
                let distance = hypot(dx, entities[index].y - y)
                let falloff = max(0.35, 1 - distance / max(0.1, radius) * 0.55)
                let towerScale = entities[index].tower ? (analog.contains("rocket") ? 1.0 : 0.45) : 1.0
                let level = team == .blue ? max(1, min(13, cardLevels[card.id] ?? 1)) : botLevel
                applyDamage(index, amount: card.damage * Balance.levelMultiplier(level) * falloff * towerScale)
                if card.behavior.contains(.stun) { entities[index].stunClock = max(entities[index].stunClock, analog.contains("freeze") ? 2.0 : 0.65) }
                if card.behavior.contains(.slow) { entities[index].slowClock = max(entities[index].slowClock, analog.contains("freeze") ? 2.0 : 1.8) }
                if card.behavior.contains(.knockback) && !entities[index].tower {
                    let dist = max(0.1, hypot(entities[index].x - x, entities[index].y - y))
                    let direction = analog.contains("tornado") ? -1.0 : 1.0
                    entities[index].x = min(17.5, max(0.5, entities[index].x + (entities[index].x - x) / dist * 0.8 * direction))
                    entities[index].y = min(31.5, max(0.5, entities[index].y + (entities[index].y - y) / dist * 0.8 * direction))
                }
            }
        }
        if analog.contains("barbarian barrel") {
            let barbarian = CardCatalog.all.first { $0.analog == "Barbarians" }?.id ?? "avenger-rookies"
            createSpawn(team: team, x: x, y: y, cardID: barbarian, scale: 1.0)
        }
        events.append(BattleEvent(x: x, y: y, text: card.name.uppercased(), born: elapsed))
        if card.behavior.contains(.elixirPump) && team == .blue { blueElixir = min(10, blueElixir + 1) }
    }
    func setOpponentEmotesMuted(_ muted: Bool) { opponentEmotesMuted = muted }
    func setSoundEnabled(_ enabled: Bool) { soundEnabled = enabled }
    func emote(_ label: String) -> Bool {
        guard elapsed - lastEmote >= 4, !isFinished else { return false }
        lastEmote = elapsed; events.append(BattleEvent(x: 9, y: 7, text: label, born: elapsed)); return true
    }
    func tick() {
        guard !isFinished else { return }
        elapsed += Balance.tick
        if isReplaying {
            while replayIndex < replayActions.count && replayActions[replayIndex].time <= elapsed {
                let action = replayActions[replayIndex]
                replayIndex += 1
                if hand.contains(action.cardID) { _ = deploy(id: action.cardID, x: action.x, y: action.y, team: .blue) }
            }
        }
        energyClock += Balance.tick
        applyTimedSpells()
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
        opponentEmoteClock -= Balance.tick
        if !opponentEmotesMuted && opponentEmoteClock <= 0 {
            if random() % 3 == 0 {
                let labels = ["NICE!", "OOPS", "WOW", "WELL PLAYED", "GOOD GAME", "THINK"]
                events.append(BattleEvent(x: 9, y: 25, text: labels[Int(random() % UInt64(labels.count))], born: elapsed))
            }
            opponentEmoteClock = 22 + Double(random() % 180) / 10
        }
        aiClock -= Balance.tick
        if aiClock <= 0 { playAI(); aiClock = max(1.1, 2.6 - Double(trophyBand) * 0.08) + Double(random() % 260) / 100 }
        blueAIClock -= Balance.tick
        if automatedBlue && blueAIClock <= 0 {
            playBlueAI()
            blueAIClock = 1.6 + Double(random() % 240) / 100
        }
        moveAndFight(); resolveTowers()
        if events.count > 120 { events.removeFirst(events.count - 120) }
        if isFinished { return }
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
    private func chooseBotCard(hand botHand: [String], team: Team, elixir: Double) -> CardDefinition? {
        let affordable = botHand.compactMap { CardCatalog.byID[$0] }.filter { $0.cost <= Int(floor(elixir)) }
        guard !affordable.isEmpty else { return nil }
        let enemy: Team = team == .blue ? .red : .blue
        let threats = entities.filter { entity in
            guard entity.alive && !entity.tower && entity.team == enemy else { return false }
            return team == .red ? entity.y > 20 : entity.y < 12
        }
        let hasAirThreat = threats.contains { CardCatalog.byID[$0.cardID]?.behavior.contains(.flying) == true }
        let cluster = threats.count >= 2 && threats.contains { first in
            threats.contains { second in first.id != second.id && hypot(first.x - second.x, first.y - second.y) <= 1.8 }
        }
        let scored = affordable.map { card -> (CardDefinition, Double) in
            var score = Double(random() % 100) / 100
            if !threats.isEmpty {
                if hasAirThreat && card.targetsAir { score += 2.8 }
                if cluster && card.behavior.contains(.splash) { score += 1.7 }
                if cluster && card.kind == .spell { score += 1.0 }
                if card.behavior.contains(.ranged) { score += 0.55 }
                if card.kind == .building { score += 0.45 }
                score += Double(max(0, 4 - card.cost)) * 0.12
            } else {
                if card.behavior.contains(.buildingTarget) { score += 1.35 }
                if card.kind == .troop { score += 0.5 }
                if (4...6).contains(card.cost) { score += 0.25 }
                if card.kind == .spell { score -= 0.25 }
            }
            score += Double(trophyBand) * 0.025
            return (card, score)
        }
        return scored.max { $0.1 < $1.1 }?.0
    }
    private func playBlueAI() {
        guard let choice = chooseBotCard(hand: hand, team: .blue, elixir: blueElixir) else { return }
        let threats = entities.filter { $0.alive && !$0.tower && $0.team == .red && $0.y < 12 }
        let threat = threats.min { $0.y < $1.y }
        let lane = threat.map { $0.x < 9 ? 3.2 : 14.8 } ?? (random() % 2 == 0 ? 3.2 : 14.8)
        let x = choice.kind == .spell ? (threat?.x ?? lane) : lane
        let y: Double
        if choice.kind == .spell {
            y = threat?.y ?? (22 + Double(random() % 65) / 10)
        } else if let threat {
            y = max(1.5, min(14.5, threat.y - 1.1))
        } else {
            y = 4 + Double(random() % 65) / 10
        }
        _ = deploy(id: choice.id, x: x, y: y, team: .blue)
    }
    private func playAI() {
        guard let choice = chooseBotCard(hand: redHand, team: .red, elixir: redElixir) else { return }
        let threats = entities.filter { $0.alive && !$0.tower && $0.team == .blue && $0.y > 20 }
        let threat = threats.max { $0.y < $1.y }
        let lane = threat.map { $0.x < 9 ? 3.2 : 14.8 } ?? (random() % 2 == 0 ? 3.2 : 14.8)
        let x = choice.kind == .spell ? (threat?.x ?? lane) : lane
        let y: Double
        if choice.kind == .spell {
            y = threat?.y ?? (4 + Double(random() % 65) / 10)
        } else if let threat {
            y = min(30.0, max(16.5, threat.y + 1.1))
        } else {
            y = 22 + Double(random() % 65) / 10
        }
        _ = deploy(id: choice.id, x: x, y: y, team: .red)
    }
    private func moveAndFight() {
        var pendingSpawns: [(Team, Double, Double, String)] = []
        for i in entities.indices {
            guard entities[i].alive else { continue }
            if entities[i].deployClock > 0 { entities[i].deployClock = max(0, entities[i].deployClock - Balance.tick); continue }
            entities[i].rageClock = max(0, entities[i].rageClock - Balance.tick)
            if entities[i].stunClock > 0 {
                entities[i].stunClock = max(0, entities[i].stunClock - Balance.tick)
                entities[i].slowClock = max(0, entities[i].slowClock - Balance.tick)
                continue
            }
            entities[i].slowClock = max(0, entities[i].slowClock - Balance.tick)
            if entities[i].tower {
                if entities[i].king && !entities[i].awake { continue }
                entities[i].attackClock -= Balance.tick * (entities[i].rageClock > 0 ? 1.35 : 1.0)
                if entities[i].attackClock <= 0, let target = nearestTarget(from: entities[i], range: 5.8) {
                    applyDamage(target, amount: 100 * entities[i].levelMultiplier); entities[i].attackClock = 0.9
                }
                continue
            }
            guard let card = CardCatalog.byID[entities[i].cardID] else { continue }
            if card.kind == .building {
                entities[i].lifetime -= Balance.tick
                if entities[i].lifetime <= 0 { entities[i].hp = 0; continue }
                if card.behavior.contains(.elixirPump) {
                    entities[i].spawnClock -= Balance.tick
                    if entities[i].spawnClock <= 0 {
                        if entities[i].team == .blue { blueElixir = min(10, blueElixir + 1) } else { redElixir = min(10, redElixir + 1) }
                        entities[i].spawnClock = 5.0
                        events.append(BattleEvent(x: entities[i].x, y: entities[i].y, text: "+1 ELIXIR", born: elapsed))
                    }
                }
            }
            if card.behavior.contains(.spawner) {
                entities[i].spawnClock -= Balance.tick
                if entities[i].spawnClock <= 0 {
                    let spawnID = spawnerUnitID(for: card)
                    pendingSpawns.append((entities[i].team, entities[i].x, entities[i].y, spawnID))
                    entities[i].spawnClock = card.kind == .building ? 5.0 : 7.0
                }
            }
            entities[i].attackClock -= Balance.tick
            if let target = nearestTarget(from: entities[i], range: max(card.range, Balance.sightRange)) {
                let distance = hypot(entities[target].x - entities[i].x, entities[target].y - entities[i].y)
                if distance <= card.range + 0.35 && card.range > 0 {
                    if entities[i].attackClock <= 0 {
                        let damage = card.damage * entities[i].levelMultiplier * (card.behavior.contains(.rampBeam) ? entities[i].beamRamp : 1) * (card.behavior.contains(.charge) && entities[i].travelSinceAttack >= 2.2 ? 2 : 1)
                        if card.behavior.contains(.splash) {
                            for j in entities.indices where entities[j].alive && entities[j].team != entities[i].team && hypot(entities[j].x - entities[target].x, entities[j].y - entities[target].y) <= 1.5 { applyDamage(j, amount: damage * 0.75) }
                        } else { applyDamage(target, amount: damage) }
                        if card.behavior.contains(.heal) { entities[i].hp = min(entities[i].maxHP, entities[i].hp + 25) }
                        if card.behavior.contains(.stun) { entities[target].stunClock = max(entities[target].stunClock, 0.35) }
                        if card.behavior.contains(.slow) { entities[target].slowClock = max(entities[target].slowClock, 0.8) }
                        entities[i].attackClock = card.hitSpeed
                        entities[i].hasAttacked = true
                        entities[i].travelSinceAttack = 0
                        if card.behavior.contains(.rampBeam) { entities[i].beamRamp = min(3.2, entities[i].beamRamp + 0.35) }
                        if card.behavior.contains(.heal) {
                            for ally in entities.indices where entities[ally].alive && entities[ally].team == entities[i].team && !entities[ally].tower && hypot(entities[ally].x - entities[i].x, entities[ally].y - entities[i].y) <= 2.0 {
                                entities[ally].hp = min(entities[ally].maxHP, entities[ally].hp + 45 * entities[i].levelMultiplier)
                            }
                        }
                        events.append(BattleEvent(x: entities[target].x, y: entities[target].y, text: "−\(Int(damage))", born: elapsed))
                    }
                    continue
                }
            }
            if !card.behavior.contains(.rampBeam) { entities[i].beamRamp = 1 }
            let laneX = entities[i].x < 9 ? 3.2 : 14.8
            let targetY = entities[i].team == .blue ? 30.0 : 2.0
            let dx = laneX - entities[i].x, dy = targetY - entities[i].y
            let distance = max(0.001, hypot(dx, dy))
            let step = card.speed * Balance.tick * (entities[i].slowClock > 0 ? 0.55 : 1.0) * (entities[i].rageClock > 0 ? 1.35 : 1.0)
            if card.behavior.contains(.charge) { entities[i].travelSinceAttack += step }
            if !card.behavior.contains(.flying) && entities[i].y > 14 && entities[i].y < 18 {
                let bridgeX = entities[i].x < 9 ? 3.2 : 14.8
                entities[i].x += (bridgeX - entities[i].x) * min(1, step * 1.8)
                entities[i].y += dy / distance * step
            } else {
                entities[i].x += dx / distance * step
                entities[i].y += dy / distance * step
            }
            entities[i].x = min(17.5, max(0.5, entities[i].x)); entities[i].y = min(31.5, max(0.5, entities[i].y))
        }
        separateUnits()
        let deadUnits = entities.filter { !$0.alive && !$0.tower && !processedDeaths.contains($0.id) }
        for dead in deadUnits {
            processedDeaths.insert(dead.id)
            guard let card = CardCatalog.byID[dead.cardID] else { continue }
            let analog = card.analog.lowercased()
            events.append(BattleEvent(x: dead.x, y: dead.y, text: "BURST!", born: elapsed))
            if analog.contains("giant skeleton") {
                for index in entities.indices where entities[index].alive && entities[index].team != dead.team && hypot(entities[index].x - dead.x, entities[index].y - dead.y) <= 2.4 {
                    applyDamage(index, amount: 420)
                }
                events.append(BattleEvent(x: dead.x, y: dead.y, text: "BOMB!", born: elapsed))
            } else if card.behavior.contains(.deathSpawn) {
                let child = analog.contains("lava hound") ? "falcon-flock" : (analog.contains("skeleton barrel") || analog.contains("giant skeleton") ? "ant-dude-swarm" : "green-gobbler")
                let count = analog.contains("lava hound") ? 4 : 2
                for n in 0..<count {
                    let spawnX = min(17.5, max(0.5, dead.x + (Double(n) - Double(count - 1) / 2) * 0.45))
                    pendingSpawns.append((dead.team, spawnX, dead.y, child))
                }
                if analog.contains("lumberjack") {
                    if let rage = CardCatalog.all.first(where: { $0.analog == "Rage" }) {
                        activeSpells.append(TimedSpell(cardID: rage.id, team: dead.team, x: dead.x, y: dead.y, remaining: 5.0))
                    }
                    events.append(BattleEvent(x: dead.x, y: dead.y, text: "RAGE!", born: elapsed))
                }
            }
        }
        for spawn in pendingSpawns { createSpawn(team: spawn.0, x: spawn.1, y: spawn.2, cardID: spawn.3) }
        for tower in entities where tower.tower && tower.king && !tower.alive {
            events.append(BattleEvent(x: tower.x, y: tower.y, text: "KING DOWN · 3 CROWNS", born: elapsed))
            if tower.team == .blue { redCrowns = 3; finish("DEFEAT") }
            else { blueCrowns = 3; finish("VICTORY") }
        }
        for i in entities.indices where entities[i].tower && entities[i].king && !entities[i].awake {
            let team = entities[i].team
            let princessFallen = entities.contains { $0.tower && !$0.king && $0.team == team && !$0.alive }
            if entities[i].hp < entities[i].maxHP || princessFallen {
                entities[i].awake = true
                events.append(BattleEvent(x: entities[i].x, y: entities[i].y, text: "KING AWAKENED", born: elapsed))
            }
        }
        for tower in entities where tower.tower && !tower.king && !tower.alive {
            let lane = tower.x < 9 ? "left" : "right"
            fallenTowerKeys.insert("\(tower.team.rawValue)-\(lane)")
            events.append(BattleEvent(x: tower.x, y: tower.y, text: "CROWN!", born: elapsed))
            if overtime { finish(tower.team == .blue ? "DEFEAT" : "VICTORY") }
            if tower.team == .blue { redCrowns = min(3, redCrowns + 1) }
            else { blueCrowns = min(3, blueCrowns + 1) }
        }
        entities.removeAll { !$0.alive }
    }
    private func applyTimedSpells() {
        var pending: [(Team, Double, Double, String)] = []
        for i in activeSpells.indices {
            activeSpells[i].remaining -= Balance.tick
            activeSpells[i].tickClock -= Balance.tick
            guard activeSpells[i].tickClock <= 0, let card = CardCatalog.byID[activeSpells[i].cardID] else { continue }
            let effect = activeSpells[i]
            let a = card.analog.lowercased()
            if a.contains("rage") {
                for index in entities.indices where entities[index].alive && !entities[index].tower && entities[index].team == effect.team && hypot(entities[index].x - effect.x, entities[index].y - effect.y) <= 3.0 {
                    entities[index].rageClock = max(entities[index].rageClock, 1.1)
                }
                activeSpells[i].tickClock = 1.0
                continue
            }
            for index in entities.indices where entities[index].alive && entities[index].team != effect.team && hypot(entities[index].x - effect.x, entities[index].y - effect.y) <= 3.4 {
                if a.contains("graveyard") { continue }
                if a.contains("earthquake") && !entities[index].tower && CardCatalog.byID[entities[index].cardID]?.kind != .building { continue }
                applyDamage(index, amount: card.damage * 0.18 * (entities[index].tower ? 0.35 : 1))
                if a.contains("poison") { entities[index].slowClock = max(entities[index].slowClock, 0.8) }
            }
            if a.contains("graveyard") {
                let id = CardCatalog.all.first { $0.analog == "Skeletons" }?.id ?? "ant-dude-swarm"
                pending.append((effect.team, effect.x + Double(random() % 7) / 10 - 0.3, effect.y + Double(random() % 7) / 10 - 0.3, id))
            }
            activeSpells[i].tickClock = 1.0
        }
        activeSpells.removeAll { $0.remaining <= 0 }
        for item in pending { createSpawn(team: item.0, x: item.1, y: item.2, cardID: item.3) }
    }
    private func spawnerUnitID(for card: CardDefinition) -> String {
        let a = card.analog.lowercased()
        if a.contains("furnace") { return CardCatalog.all.first { $0.analog == "Fire Spirits" }?.id ?? CardCatalog.starterDeck[0] }
        if a.contains("night witch") { return CardCatalog.all.first { $0.analog == "Bats" }?.id ?? CardCatalog.starterDeck[0] }
        if a.contains("witch") || a.contains("tombstone") { return CardCatalog.all.first { $0.analog == "Skeletons" }?.id ?? CardCatalog.starterDeck[0] }
        if a.contains("barbarian hut") { return CardCatalog.all.first { $0.analog == "Barbarians" }?.id ?? CardCatalog.starterDeck[0] }
        return CardCatalog.all.first { $0.analog == "Goblins" }?.id ?? CardCatalog.starterDeck[0]
    }
    private func createSpawn(team: Team, x: Double, y: Double, cardID: String, scale: Double = 0.55) {
        guard let card = CardCatalog.byID[cardID] else { return }
        entitySequence += 1
        let multiplier = Balance.levelMultiplier(team == .blue ? max(1, min(13, cardLevels[cardID] ?? 1)) : botLevel)
        let hp = max(1, card.hp * scale * multiplier)
        entities.append(BattleEntity(id: entitySequence, cardID: cardID, team: team, x: x, y: y, hp: hp, maxHP: hp, deployClock: 0.15, levelMultiplier: multiplier))
    }
    private func applyDamage(_ index: Int, amount: Double) {
        guard entities.indices.contains(index), amount > 0 else { return }
        if entities[index].shieldHP > 0 {
            let absorbed = min(entities[index].shieldHP, amount)
            entities[index].shieldHP -= absorbed
            let overflow = amount - absorbed
            if overflow > 0 { entities[index].hp -= overflow }
        } else {
            entities[index].hp -= amount
        }
        let id = entities[index].id
        if amount >= 35 && elapsed - (lastDamageEventTime[id] ?? -100) >= 0.25 {
            events.append(BattleEvent(x: entities[index].x, y: entities[index].y, text: "−\(Int(amount))", born: elapsed))
            lastDamageEventTime[id] = elapsed
        }
    }
    private func separateUnits() {
        guard entities.count > 1 else { return }
        for i in 0..<(entities.count - 1) where entities[i].alive && !entities[i].tower {
            for j in (i + 1)..<entities.count where entities[j].alive && !entities[j].tower {
                let dx = entities[j].x - entities[i].x
                let dy = entities[j].y - entities[i].y
                let d = hypot(dx, dy)
                if d > 0.001 && d < 0.62 {
                    let push = (0.62 - d) * 0.22
                    entities[i].x = min(17.5, max(0.5, entities[i].x - dx / d * push))
                    entities[i].y = min(31.5, max(0.5, entities[i].y - dy / d * push))
                    entities[j].x = min(17.5, max(0.5, entities[j].x + dx / d * push))
                    entities[j].y = min(31.5, max(0.5, entities[j].y + dy / d * push))
                }
            }
        }
    }
    private func nearestTarget(from entity: BattleEntity, range: Double) -> Int? {
        entities.indices.filter { i in
            let t = entities[i]
            guard t.alive && t.team != entity.team && t.id != entity.id && !(entity.tower && t.tower) && hypot(t.x - entity.x, t.y - entity.y) <= range else { return false }
            if let targetCard = CardCatalog.byID[t.cardID], targetCard.behavior.contains(.invisible), !t.hasAttacked { return false }
            if let source = CardCatalog.byID[entity.cardID], source.kind == .troop, source.behavior.contains(.buildingTarget) {
                guard t.tower || CardCatalog.byID[t.cardID]?.kind == .building else { return false }
            }
            if let target = CardCatalog.byID[t.cardID], target.behavior.contains(.flying) {
                return entity.tower || (CardCatalog.byID[entity.cardID]?.targetsAir == true)
            }
            return true
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
            if !Calendar.current.isDateInToday(p.dailyDate) { p.dailyDate = Date(); p.dailyCrowns = 0 }
            let oldDailyCrowns = p.dailyCrowns
            p.dailyCrowns = min(10, p.dailyCrowns + blueCrowns)
            if oldDailyCrowns < 10 && p.dailyCrowns >= 10 { p.gold += 300; p.gems += 5 }
            p.battleLog.insert(BattleRecord(result: result, crowns: blueCrowns, opponent: "Arena Rival", seed: seed, deck: originalDeck, actions: actions), at: 0)
            p.battleLog = Array(p.battleLog.prefix(30))
            var meta = p.meta ?? MetaProgression()
            if !Calendar.current.isDateInToday(meta.dailyDate) {
                meta.dailyDate = Date()
                meta.dailyQuests = MetaProgression().dailyQuests
            }
            for i in meta.dailyQuests.indices {
                switch meta.dailyQuests[i].id {
                case "win-one": if result == "VICTORY" { meta.dailyQuests[i].progress = min(meta.dailyQuests[i].target, meta.dailyQuests[i].progress + 1) }
                case "play-three": meta.dailyQuests[i].progress = min(meta.dailyQuests[i].target, meta.dailyQuests[i].progress + 1)
                case "earn-crowns": meta.dailyQuests[i].progress = min(meta.dailyQuests[i].target, meta.dailyQuests[i].progress + blueCrowns)
                default: break
                }
            }
            if Date().timeIntervalSince(meta.seasonStart) >= 30 * 24 * 3600 {
                meta.seasonStart = Date()
                meta.seasonXP = 0
                meta.claimedSeasonTiers = []
            }
            meta.seasonXP += result == "VICTORY" ? 30 : 10
            if result == "VICTORY" && meta.chestSlots.count < 4 {
                let roll = Int(seed % 100)
                let kind: (String, TimeInterval, Int, Int, Int)
                if roll < 52 { kind = ("Silver", 30 * 60, 70, 0, 8) }
                else if roll < 78 { kind = ("Gold", 2 * 3600, 160, 1, 16) }
                else if roll < 91 { kind = ("Giant", 4 * 3600, 350, 2, 28) }
                else if roll < 97 { kind = ("Magical", 6 * 3600, 500, 4, 40) }
                else if roll < 99 { kind = ("Super Magical", 8 * 3600, 700, 6, 55) }
                else { kind = ("Legendary", 12 * 3600, 900, 10, 65) }
                meta.chestSlots.append(ChestSlot(type: kind.0, startedAt: Date(), duration: kind.1, gold: kind.2, gems: kind.3, copies: kind.4))
            }
            meta.battleSnapshot = nil
            p.meta = meta
        }
    }
}