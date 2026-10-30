import Foundation

enum Balance {
    static let tickRate = 20.0
    static let tick = 1.0 / tickRate
    static let regulation = 180.0
    static let overtime = 120.0
    static let arenaWidth = 18.0
    static let arenaHeight = 32.0
    static let startElixir = 5.0
    static let maxElixir = 10.0
    static let deployDelay = 1.0
    static let sightRange = 5.5
    // Princess towers have higher sustained pressure; the king tower hits harder but fires slower.
    static let princessTowerDamage = 95.0
    static let princessTowerInterval = 0.90
    static let princessTowerRange = 6.4
    static let kingTowerDamage = 145.0
    static let kingTowerInterval = 1.10
    static let kingTowerRange = 7.2
    static func levelMultiplier(_ level: Int) -> Double { pow(1.10, Double(max(1, min(13, level)) - 9)) }
    static func elixirInterval(elapsed: Double, overtime: Bool) -> Double {
        if overtime && elapsed >= 240 { return 0.93 }
        if elapsed >= 120 { return 1.4 }
        return 2.8
    }
}