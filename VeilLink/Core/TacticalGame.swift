import Foundation

enum TacticalFaction: String, Codable, Hashable {
    case cao
    case yuan

    var player: MiniGamePlayer { self == .cao ? .host : .guest }
    var opponent: TacticalFaction { self == .cao ? .yuan : .cao }
    var title: String { self == .cao ? "曹军" : "袁军" }
}

enum TacticalTerrain: String, Codable, Hashable {
    case plain
    case road
    case forest
    case hill
    case river
    case ford
    case camp

    var title: String {
        switch self {
        case .plain: return "平原"
        case .road: return "驿道"
        case .forest: return "林地"
        case .hill: return "丘陵"
        case .river: return "河道"
        case .ford: return "渡口"
        case .camp: return "营地"
        }
    }

    var movementCost: Int? {
        switch self {
        case .river: return nil
        case .forest, .hill: return 2
        case .plain, .road, .ford, .camp: return 1
        }
    }

    var defenseBonus: Int {
        switch self {
        case .forest, .hill, .camp: return 1
        default: return 0
        }
    }
}

struct TacticalHex: Codable, Hashable, Identifiable {
    let index: Int
    let row: Int
    let col: Int
    let terrain: TacticalTerrain
    let name: String?
    let objectiveValue: Int
    let headquarters: TacticalFaction?

    var id: Int { index }
    var isObjective: Bool { objectiveValue > 0 }
}

enum TacticalUnitKind: String, Codable, Hashable {
    case command
    case infantry
    case cavalry
    case ranged
    case supply

    var title: String {
        switch self {
        case .command: return "中军"
        case .infantry: return "步军"
        case .cavalry: return "骑军"
        case .ranged: return "远程"
        case .supply: return "辎重"
        }
    }

    var symbol: String {
        switch self {
        case .command: return "帅"
        case .infantry: return "步"
        case .cavalry: return "骑"
        case .ranged: return "弩"
        case .supply: return "粮"
        }
    }

    var movement: Int {
        switch self {
        case .cavalry: return 3
        case .command, .infantry, .ranged: return 2
        case .supply: return 1
        }
    }

    var attackRange: Int { self == .ranged ? 2 : 1 }

    var attack: Int {
        switch self {
        case .command: return 3
        case .infantry: return 3
        case .cavalry: return 4
        case .ranged: return 2
        case .supply: return 1
        }
    }

    var defense: Int {
        switch self {
        case .command: return 4
        case .infantry: return 3
        case .cavalry: return 3
        case .ranged: return 2
        case .supply: return 1
        }
    }

    var maxSteps: Int { self == .supply ? 1 : 2 }
}

struct TacticalUnit: Codable, Hashable, Identifiable {
    let id: String
    let faction: TacticalFaction
    let kind: TacticalUnitKind
    let name: String
    var position: Int
    var steps: Int

    var isDestroyed: Bool { steps <= 0 }
}

struct TacticalCombatResult: Codable, Hashable {
    let attackerID: String
    let defenderID: String
    let attackerRoll: Int
    let defenderRoll: Int
    let attackerScore: Int
    let defenderScore: Int
    let attackerLoss: Int
    let defenderLoss: Int

    var summary: String {
        if defenderLoss >= 2 { return "守军溃散" }
        if defenderLoss == 1 { return "守军受损" }
        if attackerLoss > 0 { return "进攻受挫" }
        return "双方僵持"
    }
}

struct TacticalState: Equatable {
    static let rows = 7
    static let columns = 9
    static let ordersPerActivation = 2
    static let maxRounds = 8
    static let victoryPointsToWin = 8

    private(set) var units: [TacticalUnit]
    private(set) var currentPlayer: MiniGamePlayer = .host
    private(set) var turn = 0
    private(set) var round = 1
    private(set) var ordersRemaining = ordersPerActivation
    private(set) var actedUnitIDs: Set<String> = []
    private(set) var caoVictoryPoints = 0
    private(set) var yuanVictoryPoints = 0
    private(set) var winner: MiniGamePlayer?
    private(set) var isDraw = false
    private(set) var lastCombat: TacticalCombatResult?
    private(set) var lastActionText = "曹军先行"

    init() {
        units = Self.initialUnits
    }

    var moveCount: Int { turn }
    var currentFaction: TacticalFaction { currentPlayer == .host ? .cao : .yuan }

    func victoryPoints(for player: MiniGamePlayer) -> Int {
        player == .host ? caoVictoryPoints : yuanVictoryPoints
    }

    func units(for player: MiniGamePlayer) -> [TacticalUnit] {
        let faction: TacticalFaction = player == .host ? .cao : .yuan
        return units.filter { $0.faction == faction && !$0.isDestroyed }
    }

    func unit(at position: Int) -> TacticalUnit? {
        units.first { !$0.isDestroyed && $0.position == position }
    }

    func unit(id: String) -> TacticalUnit? {
        units.first { $0.id == id && !$0.isDestroyed }
    }

    func hex(at index: Int) -> TacticalHex? {
        Self.hexes.indices.contains(index) ? Self.hexes[index] : nil
    }

    func isSupplied(unitID: String) -> Bool {
        guard let unit = unit(id: unitID) else { return false }
        if unit.kind == .supply { return true }
        let sources = supplySources(for: unit.faction)
        guard !sources.isEmpty else { return false }
        let blocked = Set(units.filter { !$0.isDestroyed && $0.faction != unit.faction }.map(\.position))
        var frontier = sources
        var visited = Set(sources)
        while let current = frontier.first {
            frontier.removeFirst()
            if current == unit.position { return true }
            for next in Self.neighbors(of: current) {
                guard !visited.contains(next),
                      !blocked.contains(next),
                      let terrain = hex(at: next)?.terrain,
                      terrain.movementCost != nil else { continue }
                visited.insert(next)
                frontier.append(next)
            }
        }
        return false
    }

    func legalDestinations(from position: Int, actor: MiniGamePlayer) -> Set<Int> {
        guard winner == nil, !isDraw, actor == currentPlayer,
              let unit = unit(at: position), unit.faction.player == actor,
              !actedUnitIDs.contains(unit.id) else { return [] }

        var result = reachableMovementDestinations(for: unit)
        for enemy in units where !enemy.isDestroyed && enemy.faction != unit.faction {
            let distance = Self.hexDistance(position, enemy.position)
            if distance <= unit.kind.attackRange {
                result.insert(enemy.position)
            }
        }
        return result
    }

    func isAttack(from: Int, to: Int) -> Bool {
        guard let attacker = unit(at: from), let defender = unit(at: to) else { return false }
        return attacker.faction != defender.faction && Self.hexDistance(from, to) <= attacker.kind.attackRange
    }

    func control(at position: Int) -> TacticalFaction? {
        unit(at: position)?.faction
    }

    mutating func apply(from: Int?, to: Int?, actor: MiniGamePlayer, sessionID: String) -> Bool {
        guard winner == nil, !isDraw, actor == currentPlayer else { return false }
        if from == nil, to == nil {
            let endingFaction = currentFaction
            finishActivation(force: true)
            turn += 1
            lastActionText = "\(endingFaction.title)结束阶段"
            return true
        }
        guard let from, let to,
              let moving = unit(at: from), moving.faction.player == actor,
              !actedUnitIDs.contains(moving.id),
              legalDestinations(from: from, actor: actor).contains(to) else { return false }

        lastCombat = nil
        if let target = unit(at: to) {
            guard target.faction != moving.faction else { return false }
            resolveCombat(attackerID: moving.id, defenderID: target.id, sessionID: sessionID)
        } else {
            guard let index = units.firstIndex(where: { $0.id == moving.id }) else { return false }
            units[index].position = to
            lastActionText = "\(moving.name)机动至\(hex(at: to)?.name ?? hex(at: to)?.terrain.title ?? "目标区域")"
        }

        actedUnitIDs.insert(moving.id)
        ordersRemaining -= 1
        turn += 1
        checkImmediateVictory()
        if winner == nil, !isDraw, ordersRemaining <= 0 || availableUnitIDs(for: currentPlayer).isEmpty {
            finishActivation(force: false)
        }
        return true
    }

    private func reachableMovementDestinations(for unit: TacticalUnit) -> Set<Int> {
        let supplied = isSupplied(unitID: unit.id)
        let allowance = max(1, supplied ? unit.kind.movement : min(1, unit.kind.movement))
        let occupied = Set(units.filter { !$0.isDestroyed }.map(\.position))
        var best: [Int: Int] = [unit.position: 0]
        var queue: [(Int, Int)] = [(unit.position, 0)]
        var result = Set<Int>()

        while !queue.isEmpty {
            let (current, cost) = queue.removeFirst()
            for next in Self.neighbors(of: current) {
                guard let terrain = hex(at: next)?.terrain, let stepCost = terrain.movementCost else { continue }
                let nextCost = cost + stepCost
                guard nextCost <= allowance else { continue }
                if let existing = best[next], existing <= nextCost { continue }
                best[next] = nextCost
                if !occupied.contains(next) {
                    result.insert(next)
                    queue.append((next, nextCost))
                }
            }
        }
        return result
    }

    private func availableUnitIDs(for player: MiniGamePlayer) -> Set<String> {
        Set(units(for: player).filter { !actedUnitIDs.contains($0.id) }.map(\.id))
    }

    private func supplySources(for faction: TacticalFaction) -> [Int] {
        var sources = Self.hexes.filter { $0.headquarters == faction }.map(\.index)
        sources.append(contentsOf: units.filter { !$0.isDestroyed && $0.faction == faction && $0.kind == .supply }.map(\.position))
        return Array(Set(sources))
    }

    private mutating func resolveCombat(attackerID: String, defenderID: String, sessionID: String) {
        guard let attackerIndex = units.firstIndex(where: { $0.id == attackerID }),
              let defenderIndex = units.firstIndex(where: { $0.id == defenderID }) else { return }
        let attacker = units[attackerIndex]
        let defender = units[defenderIndex]
        let attackRoll = Self.deterministicDie(sessionID: sessionID, turn: turn, salt: "A|\(attackerID)|\(defenderID)")
        let defenseRoll = Self.deterministicDie(sessionID: sessionID, turn: turn, salt: "D|\(attackerID)|\(defenderID)")
        let attackSupply = isSupplied(unitID: attackerID) ? 0 : -1
        let defenseSupply = isSupplied(unitID: defenderID) ? 0 : -1
        let terrainBonus = hex(at: defender.position)?.terrain.defenseBonus ?? 0
        let commandAttack = commandSupport(for: attacker.faction, around: attacker.position)
        let commandDefense = commandSupport(for: defender.faction, around: defender.position)
        let attackScore = attacker.kind.attack + attackRoll + attackSupply + commandAttack
        let defenseScore = defender.kind.defense + defenseRoll + defenseSupply + terrainBonus + commandDefense
        let margin = attackScore - defenseScore
        let defenderLoss = margin >= 3 ? 2 : (margin >= 1 ? 1 : 0)
        let attackerLoss = margin <= -3 ? 1 : 0

        units[defenderIndex].steps = max(0, units[defenderIndex].steps - defenderLoss)
        units[attackerIndex].steps = max(0, units[attackerIndex].steps - attackerLoss)
        let result = TacticalCombatResult(
            attackerID: attackerID,
            defenderID: defenderID,
            attackerRoll: attackRoll,
            defenderRoll: defenseRoll,
            attackerScore: attackScore,
            defenderScore: defenseScore,
            attackerLoss: attackerLoss,
            defenderLoss: defenderLoss
        )
        lastCombat = result
        lastActionText = "\(attacker.name)攻击\(defender.name) · \(result.summary)"
    }

    private func commandSupport(for faction: TacticalFaction, around position: Int) -> Int {
        units.contains { unit in
            !unit.isDestroyed && unit.faction == faction && unit.kind == .command && Self.hexDistance(unit.position, position) <= 1
        } ? 1 : 0
    }

    private mutating func finishActivation(force: Bool) {
        let endingPlayer = currentPlayer
        if force { ordersRemaining = 0 }
        if endingPlayer == .guest {
            scoreObjectives()
            round += 1
            if winner == nil, round > Self.maxRounds {
                if caoVictoryPoints == yuanVictoryPoints { isDraw = true }
                else { winner = caoVictoryPoints > yuanVictoryPoints ? .host : .guest }
            }
        }
        if winner == nil, !isDraw {
            currentPlayer = currentPlayer.opponent
            ordersRemaining = Self.ordersPerActivation
            actedUnitIDs.removeAll(keepingCapacity: true)
        }
    }

    private mutating func scoreObjectives() {
        for hex in Self.hexes where hex.objectiveValue > 0 {
            guard let faction = control(at: hex.index) else { continue }
            if faction == .cao { caoVictoryPoints += hex.objectiveValue }
            else { yuanVictoryPoints += hex.objectiveValue }
        }
        let caoReached = caoVictoryPoints >= Self.victoryPointsToWin
        let yuanReached = yuanVictoryPoints >= Self.victoryPointsToWin
        if caoReached && yuanReached {
            if caoVictoryPoints == yuanVictoryPoints { isDraw = true }
            else { winner = caoVictoryPoints > yuanVictoryPoints ? .host : .guest }
        } else if caoReached {
            winner = .host
        } else if yuanReached {
            winner = .guest
        }
    }

    private mutating func checkImmediateVictory() {
        if let caoHQ = Self.hexes.first(where: { $0.headquarters == .cao })?.index,
           control(at: caoHQ) == .yuan { winner = .guest }
        if let yuanHQ = Self.hexes.first(where: { $0.headquarters == .yuan })?.index,
           control(at: yuanHQ) == .cao { winner = .host }

        let caoCommandAlive = units.contains { !$0.isDestroyed && $0.faction == .cao && $0.kind == .command }
        let yuanCommandAlive = units.contains { !$0.isDestroyed && $0.faction == .yuan && $0.kind == .command }
        if !caoCommandAlive && !yuanCommandAlive {
            winner = nil
            isDraw = true
        } else if !caoCommandAlive {
            winner = .guest
        } else if !yuanCommandAlive {
            winner = .host
        }
    }

    private static func deterministicDie(sessionID: String, turn: Int, salt: String) -> Int {
        var hash: UInt64 = 1469598103934665603
        for byte in Data("\(sessionID)|\(turn)|\(salt)".utf8) {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return Int(hash % 6) + 1
    }

    static func neighbors(of index: Int) -> [Int] {
        guard hexes.indices.contains(index) else { return [] }
        let row = index / columns
        let col = index % columns
        let offsetsEven = [(-1, -1), (-1, 0), (0, -1), (0, 1), (1, -1), (1, 0)]
        let offsetsOdd = [(-1, 0), (-1, 1), (0, -1), (0, 1), (1, 0), (1, 1)]
        return (row.isMultiple(of: 2) ? offsetsEven : offsetsOdd).compactMap { dr, dc in
            let r = row + dr
            let c = col + dc
            guard (0..<rows).contains(r), (0..<columns).contains(c) else { return nil }
            return r * columns + c
        }
    }

    static func hexDistance(_ a: Int, _ b: Int) -> Int {
        let ar = a / columns, ac = a % columns
        let br = b / columns, bc = b % columns
        func axial(row: Int, col: Int) -> (q: Int, r: Int) {
            (col - (row - (row & 1)) / 2, row)
        }
        let aa = axial(row: ar, col: ac)
        let bb = axial(row: br, col: bc)
        let ax = aa.q, az = aa.r, ay = -ax - az
        let bx = bb.q, bz = bb.r, by = -bx - bz
        return max(abs(ax - bx), abs(ay - by), abs(az - bz))
    }

    static let hexes: [TacticalHex] = {
        let terrainRows: [[TacticalTerrain]] = [
            [.hill, .plain, .forest, .plain, .road, .plain, .plain, .camp, .camp],
            [.plain, .camp, .forest, .road, .plain, .road, .plain, .plain, .plain],
            [.river, .river, .ford, .river, .ford, .river, .ford, .river, .river],
            [.plain, .road, .plain, .forest, .camp, .hill, .plain, .road, .plain],
            [.forest, .plain, .road, .plain, .plain, .road, .hill, .plain, .forest],
            [.plain, .road, .plain, .hill, .plain, .plain, .road, .forest, .plain],
            [.camp, .camp, .plain, .road, .plain, .hill, .plain, .plain, .forest]
        ]
        var result: [TacticalHex] = []
        for row in 0..<rows {
            for col in 0..<columns {
                let index = row * columns + col
                var name: String?
                var value = 0
                var hq: TacticalFaction?
                switch index {
                case 10: name = "乌巢"; value = 2
                case 22: name = "白马"; value = 1
                case 31: name = "官渡"; value = 2
                case 7: name = "袁军大营"; hq = .yuan
                case 55: name = "曹军大营"; hq = .cao
                default: break
                }
                result.append(TacticalHex(index: index, row: row, col: col, terrain: terrainRows[row][col], name: name, objectiveValue: value, headquarters: hq))
            }
        }
        return result
    }()

    static let initialUnits: [TacticalUnit] = [
        TacticalUnit(id: "cao-command", faction: .cao, kind: .command, name: "曹操中军", position: 55, steps: 2),
        TacticalUnit(id: "cao-infantry-l", faction: .cao, kind: .infantry, name: "曹军左部", position: 45, steps: 2),
        TacticalUnit(id: "cao-infantry-r", faction: .cao, kind: .infantry, name: "曹军右部", position: 47, steps: 2),
        TacticalUnit(id: "cao-cavalry", faction: .cao, kind: .cavalry, name: "曹军骑军", position: 49, steps: 2),
        TacticalUnit(id: "cao-ranged", faction: .cao, kind: .ranged, name: "曹军远程", position: 57, steps: 2),
        TacticalUnit(id: "cao-supply", faction: .cao, kind: .supply, name: "曹军粮队", position: 54, steps: 1),
        TacticalUnit(id: "yuan-command", faction: .yuan, kind: .command, name: "袁绍中军", position: 7, steps: 2),
        TacticalUnit(id: "yuan-infantry-l", faction: .yuan, kind: .infantry, name: "袁军左部", position: 15, steps: 2),
        TacticalUnit(id: "yuan-infantry-r", faction: .yuan, kind: .infantry, name: "袁军右部", position: 17, steps: 2),
        TacticalUnit(id: "yuan-cavalry", faction: .yuan, kind: .cavalry, name: "袁军骑军", position: 13, steps: 2),
        TacticalUnit(id: "yuan-ranged", faction: .yuan, kind: .ranged, name: "袁军远程", position: 5, steps: 2),
        TacticalUnit(id: "yuan-supply", faction: .yuan, kind: .supply, name: "袁军粮队", position: 8, steps: 1)
    ]
}
