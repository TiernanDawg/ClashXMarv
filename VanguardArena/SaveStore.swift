import Foundation
import Combine

struct ChestSlot: Codable, Identifiable {
    var id = UUID()
    var type: String
    var startedAt: Date
    var duration: TimeInterval
    var gold: Int
    var gems: Int
    var copies: Int
    var remaining: TimeInterval { max(0, duration - Date().timeIntervalSince(startedAt)) }
    var isReady: Bool { remaining <= 0 }
}
struct DailyQuest: Codable, Identifiable {
    var id: String
    var title: String
    var target: Int
    var progress: Int = 0
    var rewardGold: Int
    var rewardXP: Int
    var claimed = false
}
struct MetaProgression: Codable {
    var chestSlots: [ChestSlot] = []
    var dailyQuests: [DailyQuest] = [
        DailyQuest(id: "win-one", title: "Win one battle", target: 1, rewardGold: 120, rewardXP: 30),
        DailyQuest(id: "play-three", title: "Play three battles", target: 3, rewardGold: 100, rewardXP: 25),
        DailyQuest(id: "earn-crowns", title: "Earn five crowns", target: 5, rewardGold: 150, rewardXP: 35)
    ]
    var dailyDate: Date = .distantPast
    var seasonStart = Date()
    var seasonXP = 0
    var claimedSeasonTiers: [Int] = []
    var tutorialCompleted = false
}
struct PlayerProfile: Codable {
    var schemaVersion = 3
    var trophies = 0
    var gold = 1200
    var gems = 100
    var wins = 0
    var losses = 0
    var crowns = 0
    var kingLevel = 1
    var xp = 0
    var selectedDeck: [String] = CardCatalog.starterDeck
    var unlocked: [String] = Array(CardCatalog.all.prefix(20)).map(\.id)
    var levels: [String: Int] = [:]
    var lastFreeChest: Date = .distantPast
    var dailyCrowns = 0
    var dailyDate: Date = .distantPast
    var battleLog: [BattleRecord] = []
    var settings = GameSettings()
    var meta: MetaProgression? = MetaProgression()
}
struct BattleAction: Codable, Identifiable {
    var id = UUID()
    var time: Double
    var cardID: String
    var x: Double
    var y: Double
}
struct BattleRecord: Codable, Identifiable {
    var id = UUID()
    var date = Date()
    var result: String
    var crowns: Int
    var opponent: String
    var seed: UInt64
    var deck: [String]? = nil
    var actions: [BattleAction]? = nil
}
struct GameSettings: Codable {
    var sound = true
    var music = true
    var haptics = true
    var damageNumbers = true
    var leftHanded = false
    var muteOpponentEmotes = false
    var reduceMotion = false
    var highContrast = false
    var largeText = false
}
@MainActor
final class ProfileStore: ObservableObject {
    static let shared = ProfileStore()
    @Published private(set) var profile: PlayerProfile
    private let fileURL: URL
    private init() {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        fileURL = root.appendingPathComponent("vanguard-profile-v3.json")
        let legacyURL = root.appendingPathComponent("vanguard-profile-v2.json")
        if let data = (try? Data(contentsOf: fileURL)) ?? (try? Data(contentsOf: legacyURL)),
           let loaded = try? JSONDecoder().decode(PlayerProfile.self, from: data),
           loaded.schemaVersion <= 3 {
            var valid = loaded
            valid.schemaVersion = 3
            valid.meta = valid.meta ?? MetaProgression()
            if let meta = valid.meta, !Calendar.current.isDateInToday(meta.dailyDate) {
                valid.meta?.dailyDate = Date()
                valid.meta?.dailyQuests = MetaProgression().dailyQuests
            }
            if let meta = valid.meta, Date().timeIntervalSince(meta.seasonStart) >= 30 * 24 * 3600 {
                valid.meta?.seasonStart = Date()
                valid.meta?.seasonXP = 0
                valid.meta?.claimedSeasonTiers = []
            }
            valid.selectedDeck = Array(valid.selectedDeck.filter { CardCatalog.byID[$0] != nil }.prefix(8))
            for id in CardCatalog.starterDeck where valid.selectedDeck.count < 8 && !valid.selectedDeck.contains(id) { valid.selectedDeck.append(id) }
            valid.unlocked = Array(Set(valid.unlocked.filter { CardCatalog.byID[$0] != nil }))
            if valid.unlocked.isEmpty { valid.unlocked = Array(CardCatalog.all.prefix(20)).map(\.id) }
            valid.trophies = max(0, min(10000, valid.trophies))
            valid.gold = max(0, valid.gold); valid.gems = max(0, valid.gems)
            profile = valid
        } else { profile = PlayerProfile() }
        persist()
    }
    func update(_ body: (inout PlayerProfile) -> Void) { body(&profile); profile.schemaVersion = 3; persist() }
    func persist() {
        do { try JSONEncoder().encode(profile).write(to: fileURL, options: .atomic) }
        catch { /* In-memory progress remains available if disk storage fails. */ }
    }
    func reset() { profile = PlayerProfile(); persist() }
}