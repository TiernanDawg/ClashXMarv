import Foundation

/// Integer cell on the 18 × 32 arena navigation grid.
struct ArenaCell: Hashable, Codable {
    let x: Int
    let y: Int
}

struct CachedArenaPath {
    var targetID: Int
    var targetCell: ArenaCell
    var navigationRevision: Int
    var cells: [ArenaCell]
    var cursor: Int
}

/// Deterministic A* navigation. Rows 15–16 are the river; only the two
/// bridge spans are walkable by ground units. Flyers deliberately bypass it.
enum ArenaNavigation {
    static let width = 18
    static let height = 32
    static let riverRows = 15...16

    static func cell(x: Double, y: Double) -> ArenaCell {
        ArenaCell(x: min(width - 1, max(0, Int(floor(x)))),
                  y: min(height - 1, max(0, Int(floor(y)))))
    }

    static func isBridge(_ cell: ArenaCell) -> Bool {
        riverRows.contains(cell.y) && (2...3).contains(cell.x) ||
        riverRows.contains(cell.y) && (14...15).contains(cell.x)
    }

    static func isWalkable(_ cell: ArenaCell, blocked: Set<ArenaCell> = []) -> Bool {
        guard (0..<width).contains(cell.x), (0..<height).contains(cell.y) else { return false }
        if riverRows.contains(cell.y) && !isBridge(cell) { return false }
        return !blocked.contains(cell)
    }

    static func path(from start: ArenaCell, to goal: ArenaCell,
                     blocked: Set<ArenaCell> = []) -> [ArenaCell] {
        guard (0..<width).contains(start.x), (0..<height).contains(start.y),
              (0..<width).contains(goal.x), (0..<height).contains(goal.y) else { return [] }
        var obstacles = blocked
        obstacles.remove(goal)
        obstacles.remove(start) // A unit pushed onto a blocked tile must still be able to escape.\n        guard isWalkable(goal, blocked: obstacles) else { return [] }
        if start == goal { return [start] }

        func heuristic(_ a: ArenaCell, _ b: ArenaCell) -> Int {
            let dx = abs(a.x - b.x), dy = abs(a.y - b.y)\n            return 14 * min(dx, dy) + 10 * abs(dx - dy)
        }
        let directions = [(0,1),(1,0),(0,-1),(-1,0),(1,1),(1,-1),(-1,1),(-1,-1)]
        var open: [ArenaCell] = [start]
        var cameFrom: [ArenaCell: ArenaCell] = [:]
        var gScore: [ArenaCell: Int] = [start: 0]
        var closed = Set<ArenaCell>()

        while !open.isEmpty {
            let bestIndex = open.indices.min {
                let lhs = gScore[open[$0], default: Int.max / 4] + heuristic(open[$0], goal)
                let rhs = gScore[open[$1], default: Int.max / 4] + heuristic(open[$1], goal)
                return lhs == rhs ? (open[$0].y == open[$1].y ? open[$0].x < open[$1].x : open[$0].y < open[$1].y) : lhs < rhs
            }!
            let current = open.remove(at: bestIndex)
            if current == goal {
                var result = [current]
                var cursor = current
                while let previous = cameFrom[cursor] {
                    result.append(previous)
                    cursor = previous
                }
                return Array(result.reversed())
            }
            closed.insert(current)
            for (dx, dy) in directions {
                let next = ArenaCell(x: current.x + dx, y: current.y + dy)
                guard !closed.contains(next), isWalkable(next, blocked: obstacles) else { continue }
                // Prevent diagonal corner-cutting around a blocked tile or river bank.
                if dx != 0 && dy != 0 {
                    let sideA = ArenaCell(x: current.x + dx, y: current.y)
                    let sideB = ArenaCell(x: current.x, y: current.y + dy)
                    guard isWalkable(sideA, blocked: obstacles), isWalkable(sideB, blocked: obstacles) else { continue }
                }
                let tentative = gScore[current, default: Int.max / 4] + (dx == 0 || dy == 0 ? 10 : 14)
                if tentative < gScore[next, default: Int.max / 4] {
                    cameFrom[next] = current
                    gScore[next] = tentative
                    if !open.contains(next) { open.append(next) }
                }
            }
        }
        return []
    }
}
