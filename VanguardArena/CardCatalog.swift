import Foundation

enum CardKind: String, Codable { case troop, building, spell }
enum CardRarity: String, Codable { case common = "Common", rare = "Rare", epic = "Epic", legendary = "Legendary" }
enum CardBehavior: String, Codable, CaseIterable {
    case melee, ranged, splash, flying, charge, jump, spawner, deathSpawn, rampBeam, stun, slow, invisible, tunnel, areaOverTime, buildingTarget, spell, heal, shield, knockback, clone, mirror, elixirPump, swarm
}

struct CardDefinition: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let cost: Int
    let kind: CardKind
    let analog: String
    let rarity: CardRarity
    let description: String
    let hp: Double
    let damage: Double
    let range: Double
    let speed: Double
    let hitSpeed: Double
    let targetsAir: Bool
    let targetsGround: Bool
    let unitCount: Int
    let behavior: Set<CardBehavior>
    var dps: Double { damage / max(0.25, hitSpeed) }
    var statsLine: String { "HP \(Int(hp)) · DPS \(Int(dps)) · Range \(String(format: "%.1f", range)) · \(speed == 0 ? "Stationary" : "\(Int(speed * 60)) tiles/min")" }
}

enum CardCatalog {
    private static let raw = #"""
Torch Tots|1|troop|Fire Spirits
Icey Man|1|troop|Ice Spirit
Static Bro|1|troop|Electro Spirit
Ant Dude Swarm|1|troop|Skeletons
Spider Dude|2|troop|Web slow melee
Waspies|2|troop|Bats
Green Gobbler|2|troop|Goblins
Hobgobbler Pair|2|troop|Spear Goblins
Doombot|2|troop|Bomber
Cold Colossus|2|troop|Ice Golem
Captain Amerika|3|troop|Knight
Black Window|3|troop|Archers
Starr Lordy|3|troop|Dart Goblin
Falcon Flock|3|troop|Minions
Dedpool|3|troop|Bandit
Gobbler Gang|3|troop|Goblin Gang
Hydra Horde|3|troop|Skeleton Army
Hydra Guards|3|troop|Guards
Sentinelle|3|troop|Mega Minion
Mole Dude|3|troop|Miner
Mini Grooty|3|troop|Elixir Golem
Invisa-Girl|3|troop|Princess
Frostbyte|3|troop|Ice Wizard
Phantom Man|3|troop|Royal Ghost
Wolverene|4|troop|Mini P.E.K.K.A
Thorr|4|troop|Valkyrie
Ghost Ryder|4|troop|Hog Rider
Hawk Eyed|4|troop|Musketeer
Iron Guy|4|troop|Baby Dragon
Magnetoe|4|troop|Electro Wizard
Cyclopz|4|troop|Inferno Dragon
Craven Hunter|4|troop|Hunter
Moon Knightly|4|troop|Night Witch
Sabertoothy|4|troop|Lumberjack
Quin-Jet|4|troop|Flying Machine
Shocker Trio|4|troop|Zappies
Rhyno Charge|4|troop|Battle Ram
Darkhold Prince|4|troop|Dark Prince
Gamorra|4|troop|Magic Archer
Doc Heals|4|troop|Battle Healer
Black Pantha|5|troop|Prince
Doc Strangely|5|troop|Wizard
Scarlet Witchy|5|troop|Witch
Hulkster|5|troop|Giant
Avenger Rookies|5|troop|Barbarians
Juggernot|5|troop|Bowler
Punisha|5|troop|Executioner
Ultrawn Drones|5|troop|Minion Horde
Stark Tank|5|troop|Cannon Cart
Hogun Squad|5|troop|Royal Hogs
Street Rascals|5|troop|Rascals
Zemo's Zeppelin|5|troop|Balloon
Dr. Doomsday|6|troop|Sparky
Elite Rookies|6|troop|Elite Barbarians
Red Skullz|6|troop|Giant Skeleton
Giant-Man|6|troop|Royal Giant
Venum|7|troop|Mega Knight
Thanoz|7|troop|P.E.K.K.A
Shield Recruits|7|troop|Royal Recruits
Surtoo|7|troop|Lava Hound
Grooty|8|troop|Golem
Three Avengerteers|9|troop|Three Musketeers
Furry's Turret|3|building|Cannon
Morbious Crypt|3|building|Tombstone
Doombot Tower|4|building|Bomb Tower
Stark Coil|4|building|Tesla
Torch Forge|4|building|Furnace
Stark Mortar|4|building|Mortar
Hydrant Hut|5|building|Goblin Hut
Cyclopz Beam Tower|5|building|Inferno Tower
Hawk X-Bow|6|building|X-Bow
Arc Reactor|6|building|Elixir Collector
Avenger Hut|7|building|Barbarian Hut
Shrink Zap|2|spell|Zap
Hammer Roll|2|spell|The Log
Avenger Barrel|2|spell|Barbarian Barrel
Icey Snowball|2|spell|Giant Snowball
Hawk Volley|3|spell|Arrows
Smash Quake|3|spell|Earthquake
Lokey Clones|3|spell|Clone
Stormy Cyclone|3|spell|Tornado
Gobbler Barrel|3|spell|Goblin Barrel
Hydra Barrel|3|spell|Skeleton Barrel
Human Torchy Fireball|4|spell|Fireball
Web Trap|4|spell|Freeze
Infinity Snappe|4|spell|Rage
Mysterio Fog|4|spell|Poison
Zombie Graveyard|5|spell|Graveyard
Stormy Bolt|6|spell|Lightning
Rocket Rascal|6|spell|Rocket
Mirror Dimension|1|spell|Mirror
"""#
    static let all: [CardDefinition] = raw.split(separator: "\n").compactMap { line in
        let p = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard p.count == 4, let cost = Int(p[1]), let kind = CardKind(rawValue: p[2]) else { return nil }
        return make(name: p[0], cost: cost, kind: kind, analog: p[3])
    }
    static let byID: [String: CardDefinition] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    static func unlockThreshold(for card: CardDefinition) -> Int {
        guard let index = all.firstIndex(where: { $0.id == card.id }) else { return 3_600 }
        return min(3_600, (index / 7) * 300)
    }
    static let starterDeck: [String] = ["Captain Amerika","Black Window","Green Gobbler","Hobgobbler Pair","Icey Man","Waspies","Doombot","Ant Dude Swarm"].compactMap { name in all.first { $0.name == name }?.id }
    private static func make(name: String, cost: Int, kind: CardKind, analog: String) -> CardDefinition {
        let id = name.lowercased().replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let a = analog.lowercased()
        var b: Set<CardBehavior> = []
        if kind == .spell { b.insert(.spell) }
        if kind == .building { b.insert(.buildingTarget) }
        if ["bat","minion","flying machine","baby dragon","balloon","lava hound","minion horde"].contains(where: { a.contains($0) }) { b.insert(.flying) }
        if ["spear","archer","dart","musketeer","wizard","dragon","bowler","executioner","magic archer","mortar","x-bow","cannon","hunter","rocket","fireball","arrows","bolt","volley","zap"].contains(where: { a.contains($0) }) { b.insert(.ranged) }
        if ["fire spirit","ice spirit","electro spirit","bomber","valkyrie","wizard","baby dragon","bowler","executioner","fireball","arrows","rocket","poison","earthquake","bomb","tornado","snowball"].contains(where: { a.contains($0) }) { b.insert(.splash) }
        if a.contains("miner") || a.contains("tunnel") { b.insert(.tunnel) }
        if a.contains("inferno") || a.contains("beam") || a.contains("sparky") || a.contains("ramping") { b.insert(.rampBeam) }
        if ["ice","freeze","slow","web","snowball"].contains(where: { a.contains($0) }) { b.insert(.slow) }
        if ["electro","zap","zappies","stun"].contains(where: { a.contains($0) }) { b.insert(.stun) }
        if ["witch","tombstone","furnace","goblin hut","barbarian hut"].contains(where: { a.contains($0) }) { b.insert(.spawner) }
        if ["giant skeleton","lumberjack","golem","lava hound","skeleton barrel","elixir golem"].contains(where: { a.contains($0) }) { b.insert(.deathSpawn) }
        if ["prince","bandit","ram","hog rider","charge"].contains(where: { a.contains($0) }) { b.insert(.charge) }
        if a.contains("mega knight") || a.contains("jump") { b.insert(.jump) }
        if a.contains("ghost") || a.contains("invisa") { b.insert(.invisible) }
        if a == "giant" || a.contains("royal giant") || a.contains("golem") || a.contains("balloon") || a.contains("hog rider") || a.contains("prince") || a.contains("ram") || a.contains("miner") || a.contains("lava hound") || a.contains("royal hogs") || a.contains("p.e.k.k.a") || a.contains("pekka") { b.insert(.buildingTarget) }
        if a.contains("healer") { b.insert(.heal) }
        if ["fire spirits","skeletons","bats","goblins","spear goblins","goblin gang","skeleton army","guards","minions","zappies","barbarians","minion horde","royal hogs","rascals","three musketeers"].contains(where: { a.contains($0) }) { b.insert(.swarm) }
        if a.contains("guard") || a.contains("shield") { b.insert(.shield) }
        if ["log","barrel","bowler","snowball","tornado"].contains(where: { a.contains($0) }) { b.insert(.knockback) }
        if a.contains("clone") { b.insert(.clone) }
        if a.contains("mirror") { b.insert(.mirror) }
        if a.contains("collector") || a.contains("pump") || a.contains("arc reactor") { b.insert(.elixirPump) }
        if ["poison","graveyard","furnace","hut","crypt"].contains(where: { a.contains($0) }) { b.insert(.areaOverTime) }
        let rarity: CardRarity
        if ["bandit","miner","princess","royal ghost","inferno dragon","night witch","magic archer","electro wizard","the log","lava hound","mega knight"].contains(where: { a.contains($0) }) { rarity = .legendary }
        else if cost >= 7 || ["three musketeers","sparky","golem","p.e.k.k.a","mirror","rocket","lightning","witch","baby dragon","executioner"].contains(where: { a.contains($0) }) { rarity = .epic }
        else if cost >= 4 || ["battle ram","hunter","musketeer","valkyrie","mini p.e.k.k.a","collector","freeze","poison"].contains(where: { a.contains($0) }) { rarity = .rare }
        else { rarity = .common }
        let unitCount: Int
        if a.contains("fire spirits") { unitCount = 3 }
        else if a.contains("skeleton army") { unitCount = 6 }
        else if a.contains("minion horde") { unitCount = 6 }
        else if a.contains("goblin gang") { unitCount = 5 }
        else if a.contains("royal hogs") { unitCount = 4 }
        else if a.contains("three musketeers") { unitCount = 3 }
        else if a.contains("barbarians") { unitCount = 4 }
        else if a.contains("rascals") { unitCount = 3 }
        else if a.contains("spear goblins") { unitCount = 2 }
        else if a.contains("bats") || a.contains("minions") || a.contains("skeletons") || a.contains("goblins") || a.contains("zappies") || a.contains("guards") { unitCount = 3 }
        else { unitCount = 1 }
        let hp = kind == .spell ? 0 : (kind == .building ? 850 + Double(cost) * 125 : 190 + Double(cost) * 155) * (unitCount > 1 ? 0.58 : 1)
        let damage = kind == .spell ? 150 + Double(cost) * 78 : 34 + Double(cost) * 31
        let range = kind == .spell ? 2.8 : (b.contains(.ranged) ? 5.0 : (kind == .building ? 5.5 : 0.9))
        let speed = kind == .building || kind == .spell ? 0 : (b.contains(.flying) ? 1.5 : (cost <= 2 ? 1.25 : (cost >= 6 ? 0.62 : 0.95)))
        let hit = cost >= 6 ? 1.8 : (cost <= 2 ? 0.85 : 1.15)
        let description: String
        if kind == .spell { description = "Cast instantly to \(a.contains("freeze") ? "freeze" : a.contains("mirror") ? "copy the last card" : "damage or disrupt") enemies in an area." }
        else if kind == .building { description = "Defensive structure that pulls nearby threats and supports your lane." }
        else if b.contains(.flying) { description = "Air unit that bypasses river obstacles and pressures towers." }
        else if b.contains(.ranged) { description = "Ranged support unit; protect it behind a durable front line." }
        else if b.contains(.splash) { description = "Area damage punishes clustered units and fragile swarms." }
        else { description = "Ground fighter that advances through a bridge and pressures the nearest tower." }
        let targetsAir: Bool
        if kind == .building {
            targetsAir = a.contains("tesla") || a.contains("inferno tower")
        } else if kind == .spell {
            targetsAir = ["arrows","fireball","snowball","lightning","rocket","poison","freeze","tornado","zap"].contains(where: { a.contains($0) })
        } else {
            targetsAir = b.contains(.ranged) || b.contains(.flying) || b.contains(.stun)
        }
        return CardDefinition(id: id, name: name, cost: cost, kind: kind, analog: analog, rarity: rarity, description: description, hp: hp, damage: damage, range: range, speed: speed, hitSpeed: hit, targetsAir: targetsAir, targetsGround: true, unitCount: unitCount, behavior: b)
    }
}
