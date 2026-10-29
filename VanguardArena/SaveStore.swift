import Foundation
import Combine

struct PlayerProfile: Codable {
    var schemaVersion = 2
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
}
struct BattleRecord: Codable, Identifiable {
    var id = UUID()
    var date = Date()
    var result: String
    var crowns: Int
    var opponent: String
    var seed: UInt64
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
        fileURL = root.appendingPathComponent("vanguard-profile-v2.json")
        if let data = try? Data(contentsOf: fileURL),
           let loaded = try? JSONDecoder().decode(PlayerProfile.self, from: data),
           loaded.schemaVersion <= 2 {
            var valid = loaded
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
    func update(_ body: (inout PlayerProfile) -> Void) { body(&profile); profile.schemaVersion = 2; persist() }
    func persist() {
        do { try JSONEncoder().encode(profile).write(to: fileURL, options: .atomic) }
        catch { /* In-memory progress remains available if disk storage fails. */ }
    }
    func reset() { profile = PlayerProfile(); persist() }
}