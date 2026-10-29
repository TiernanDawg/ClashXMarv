#if DEBUG
import Foundation

struct BattleSelfTestReport {
    let matches: Int
    let totalTicks: Int
    let maxEntities: Int
}

@MainActor
enum BattleSelfTest {
    static func run(matches: Int = 1_000, startingAt: Int = 0) -> BattleSelfTestReport {
        precondition(matches > 0 && startingAt >= 0)
        var totalTicks = 0
        var maxEntities = 0
        for offset in 0..<matches {
            let match = startingAt + offset
            if offset % 25 == 0 { print("Self-test progress: \(startingAt + offset)/\(startingAt + matches)") }
            let model = BattleModel(deck: CardCatalog.starterDeck, seed: UInt64(match + 1), automatedBlue: true)
            model.setSoundEnabled(false)
            model.setOpponentEmotesMuted(true)
            var previous: [Int: (Double, Double, Int)] = [:]
            var ticks = 0
            while !model.isFinished && ticks < 6_000 {
                model.tick()
                ticks += 1
                totalTicks += 1
                maxEntities = max(maxEntities, model.entities.count)
                // Deep state/path checks every half-second avoid making QA itself the bottleneck.
                if ticks.isMultiple(of: 10) {
                    for entity in model.entities {
                        precondition(entity.x.isFinite && entity.y.isFinite && entity.hp.isFinite && entity.maxHP.isFinite, "Non-finite battle state in match \(match)")
                        precondition((0.5...17.5).contains(entity.x) && (0.5...31.5).contains(entity.y), "Entity escaped arena bounds in match \(match)")
                        guard !entity.tower, entity.deployClock <= 0, CardCatalog.byID[entity.cardID]?.kind == .troop else { continue }
                        let old = previous[entity.id]
                        let moved = old.map { hypot(entity.x - $0.0, entity.y - $0.1) > 0.015 } ?? true
                        let targetNearby = model.entities.contains { other in
                            other.alive && other.team != entity.team && hypot(other.x - entity.x, other.y - entity.y) <= max(Balance.sightRange, CardCatalog.byID[entity.cardID]?.range ?? 1)
                        }
                        let stalled = moved || targetNearby ? 0 : (old?.2 ?? 0) + 10
                        precondition(stalled < 240, "Possible pathing deadlock in match \(match), entity \(entity.id)")
                        previous[entity.id] = (entity.x, entity.y, stalled)
                    }
                }
            }
            precondition(model.isFinished, "Match \(match) failed to resolve within 3:00 + 2:00")
        }
        return BattleSelfTestReport(matches: matches, totalTicks: totalTicks, maxEntities: maxEntities)
    }
}
#endif
