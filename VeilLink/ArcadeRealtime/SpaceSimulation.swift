import Foundation

struct SpaceVector: Equatable, Sendable {
    var x: Double
    var y: Double

    static let zero = SpaceVector(x: 0, y: 0)

    var lengthSquared: Double { x * x + y * y }
    var length: Double { sqrt(lengthSquared) }

    var normalized: SpaceVector {
        let magnitude = length
        guard magnitude > 0.000_001 else { return .zero }
        return self / magnitude
    }

    func limited(to maximum: Double) -> SpaceVector {
        guard maximum >= 0, lengthSquared > maximum * maximum else { return self }
        return normalized * maximum
    }

    static func + (lhs: SpaceVector, rhs: SpaceVector) -> SpaceVector {
        SpaceVector(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    static func - (lhs: SpaceVector, rhs: SpaceVector) -> SpaceVector {
        SpaceVector(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    static func * (lhs: SpaceVector, rhs: Double) -> SpaceVector {
        SpaceVector(x: lhs.x * rhs, y: lhs.y * rhs)
    }

    static func / (lhs: SpaceVector, rhs: Double) -> SpaceVector {
        SpaceVector(x: lhs.x / rhs, y: lhs.y / rhs)
    }
}

struct SpaceGameConfiguration: Equatable, Sendable {
    var arenaWidth: Double
    var arenaHeight: Double
    var fixedTimeStep: Double
    var playerMaximumHealth: Double
    var playerSpeed: Double
    var playerFireInterval: Double
    var initialEnemyCount: Int
    var spawnInterval: Double
    var waveIntermission: Double

    init(
        arenaWidth: Double = 1_024,
        arenaHeight: Double = 768,
        fixedTimeStep: Double = 1.0 / 60.0,
        playerMaximumHealth: Double = 100,
        playerSpeed: Double = 300,
        playerFireInterval: Double = 0.19,
        initialEnemyCount: Int = 6,
        spawnInterval: Double = 0.38,
        waveIntermission: Double = 1.7
    ) {
        self.arenaWidth = max(320, arenaWidth)
        self.arenaHeight = max(240, arenaHeight)
        self.fixedTimeStep = min(1.0 / 30.0, max(1.0 / 120.0, fixedTimeStep))
        self.playerMaximumHealth = max(1, playerMaximumHealth)
        self.playerSpeed = max(1, playerSpeed)
        self.playerFireInterval = max(0.04, playerFireInterval)
        self.initialEnemyCount = max(1, initialEnemyCount)
        self.spawnInterval = max(0.01, spawnInterval)
        self.waveIntermission = max(0.01, waveIntermission)
    }

    static let standard = SpaceGameConfiguration()
}

enum SpaceGamePhase: Equatable, Sendable {
    case playing
    case paused
    case gameOver
}

enum SpaceEnemyKind: Int, CaseIterable, Equatable, Sendable {
    case hunter
    case charger
    case gunship
}

enum SpaceProjectileOwner: Equatable, Sendable {
    case player
    case enemy
}

struct SpaceInput: Equatable, Sendable {
    var movement: SpaceVector

    init(movement: SpaceVector = .zero) {
        self.movement = movement.limited(to: 1)
    }
}

struct SpacePlayerSnapshot: Equatable, Sendable {
    let position: SpaceVector
    let velocity: SpaceVector
    let health: Double
    let maximumHealth: Double
    let invulnerabilityRemaining: Double
}

struct SpaceEnemySnapshot: Identifiable, Equatable, Sendable {
    let id: Int
    let kind: SpaceEnemyKind
    let position: SpaceVector
    let velocity: SpaceVector
    let healthFraction: Double
    let radius: Double
}

struct SpaceProjectileSnapshot: Identifiable, Equatable, Sendable {
    let id: Int
    let owner: SpaceProjectileOwner
    let position: SpaceVector
    let velocity: SpaceVector
    let radius: Double
}

struct SpaceGameSnapshot: Equatable, Sendable {
    let phase: SpaceGamePhase
    let player: SpacePlayerSnapshot
    let enemies: [SpaceEnemySnapshot]
    let projectiles: [SpaceProjectileSnapshot]
    let wave: Int
    let score: Int
    let highCombo: Int
    let elapsedTime: Double
    let enemiesRemainingInWave: Int
}

enum SpaceGameEvent: Equatable, Sendable {
    case playerFired(position: SpaceVector)
    case enemyFired(position: SpaceVector)
    case impact(position: SpaceVector, hostile: Bool)
    case enemyDestroyed(position: SpaceVector, kind: SpaceEnemyKind)
    case playerDamaged(position: SpaceVector)
    case waveStarted(Int)
    case gameOver(score: Int)
}

struct SpaceSimulation: Sendable {
    private struct Player: Equatable, Sendable {
        var position: SpaceVector
        var velocity = SpaceVector.zero
        var health: Double
        var fireCooldown = 0.08
        var invulnerabilityRemaining = 0.0
    }

    private struct Enemy: Equatable, Sendable {
        let id: Int
        let kind: SpaceEnemyKind
        var position: SpaceVector
        var velocity = SpaceVector.zero
        var health: Double
        let maximumHealth: Double
        let radius: Double
        var attackCooldown: Double
        var behaviorClock: Double
    }

    private struct Projectile: Equatable, Sendable {
        let id: Int
        let owner: SpaceProjectileOwner
        var position: SpaceVector
        let velocity: SpaceVector
        let damage: Double
        var lifetime: Double
        let radius: Double
    }

    private struct Generator: Equatable, Sendable {
        var state: UInt64

        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var value = state
            value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
            value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
            return value ^ (value >> 31)
        }

        mutating func unit() -> Double {
            Double(next() >> 11) / Double(1 << 53)
        }
    }

    let configuration: SpaceGameConfiguration
    private(set) var phase: SpaceGamePhase = .playing
    private(set) var wave = 1
    private(set) var score = 0
    private(set) var highCombo = 0
    private(set) var elapsedTime = 0.0

    private var player: Player
    private var enemies: [Enemy] = []
    private var projectiles: [Projectile] = []
    private var generator: Generator
    private var accumulator = 0.0
    private var nextIdentifier = 1
    private var pendingSpawns: Int
    private var spawnCooldown = 0.12
    private var intermissionRemaining: Double
    private var combo = 0
    private var comboRemaining = 0.0

    init(configuration: SpaceGameConfiguration = .standard, seed: UInt64 = 0x5645_494C_5350_4143) {
        self.configuration = configuration
        self.generator = Generator(state: seed)
        self.player = Player(
            position: SpaceVector(x: configuration.arenaWidth / 2, y: configuration.arenaHeight / 2),
            health: configuration.playerMaximumHealth
        )
        self.pendingSpawns = configuration.initialEnemyCount
        self.intermissionRemaining = configuration.waveIntermission
    }

    var snapshot: SpaceGameSnapshot {
        SpaceGameSnapshot(
            phase: phase,
            player: SpacePlayerSnapshot(
                position: player.position,
                velocity: player.velocity,
                health: player.health,
                maximumHealth: configuration.playerMaximumHealth,
                invulnerabilityRemaining: player.invulnerabilityRemaining
            ),
            enemies: enemies.map {
                SpaceEnemySnapshot(
                    id: $0.id,
                    kind: $0.kind,
                    position: $0.position,
                    velocity: $0.velocity,
                    healthFraction: max(0, $0.health / $0.maximumHealth),
                    radius: $0.radius
                )
            },
            projectiles: projectiles.map {
                SpaceProjectileSnapshot(
                    id: $0.id,
                    owner: $0.owner,
                    position: $0.position,
                    velocity: $0.velocity,
                    radius: $0.radius
                )
            },
            wave: wave,
            score: score,
            highCombo: highCombo,
            elapsedTime: elapsedTime,
            enemiesRemainingInWave: pendingSpawns + enemies.count
        )
    }

    mutating func setPaused(_ paused: Bool) {
        guard phase != .gameOver else { return }
        phase = paused ? .paused : .playing
        accumulator = 0
    }

    mutating func restart(seed: UInt64 = 0x5645_494C_5350_4143) {
        self = SpaceSimulation(configuration: configuration, seed: seed)
    }

    @discardableResult
    mutating func advance(frameDelta: Double, input: SpaceInput = SpaceInput()) -> [SpaceGameEvent] {
        guard phase == .playing, frameDelta.isFinite, frameDelta > 0 else { return [] }
        accumulator += min(frameDelta, 0.1)
        var events: [SpaceGameEvent] = []
        var steps = 0
        while accumulator + 0.000_000_1 >= configuration.fixedTimeStep, steps < 6 {
            events.append(contentsOf: simulateStep(input: input))
            accumulator -= configuration.fixedTimeStep
            steps += 1
        }
        if steps == 6, accumulator >= configuration.fixedTimeStep {
            accumulator = 0
        }
        return events
    }

    private mutating func simulateStep(input: SpaceInput) -> [SpaceGameEvent] {
        let dt = configuration.fixedTimeStep
        elapsedTime += dt
        player.invulnerabilityRemaining = max(0, player.invulnerabilityRemaining - dt)
        player.fireCooldown -= dt
        comboRemaining -= dt
        if comboRemaining <= 0 { combo = 0 }

        let desiredVelocity = input.movement.limited(to: 1) * configuration.playerSpeed
        let steering = (desiredVelocity - player.velocity).limited(to: 1_550 * dt)
        player.velocity = (player.velocity + steering) * (input.movement.lengthSquared > 0.001 ? 1 : 0.90)
        player.position = clampedPlayerPosition(player.position + player.velocity * dt)

        var events: [SpaceGameEvent] = []
        updateWave(events: &events, dt: dt)
        updateEnemies(events: &events, dt: dt)
        autoFire(events: &events)
        updateProjectiles(dt: dt)
        resolveProjectileCollisions(events: &events)
        resolveContactCollisions(events: &events)

        return events
    }

    private mutating func updateWave(events: inout [SpaceGameEvent], dt: Double) {
        if pendingSpawns > 0 {
            spawnCooldown -= dt
            if spawnCooldown <= 0 {
                spawnEnemy()
                pendingSpawns -= 1
                spawnCooldown = max(0.13, configuration.spawnInterval - Double(wave - 1) * 0.012)
            }
        } else if enemies.isEmpty {
            intermissionRemaining -= dt
            if intermissionRemaining <= 0 {
                wave += 1
                pendingSpawns = configuration.initialEnemyCount + (wave - 1) * 2
                spawnCooldown = 0.08
                intermissionRemaining = configuration.waveIntermission
                player.health = min(configuration.playerMaximumHealth, player.health + 8)
                events.append(.waveStarted(wave))
            }
        }
    }

    private mutating func spawnEnemy() {
        let edge = Int(generator.next() % 4)
        let margin = 34.0
        let position: SpaceVector
        switch edge {
        case 0:
            position = SpaceVector(x: margin, y: margin + generator.unit() * (configuration.arenaHeight - margin * 2))
        case 1:
            position = SpaceVector(x: configuration.arenaWidth - margin, y: margin + generator.unit() * (configuration.arenaHeight - margin * 2))
        case 2:
            position = SpaceVector(x: margin + generator.unit() * (configuration.arenaWidth - margin * 2), y: margin)
        default:
            position = SpaceVector(x: margin + generator.unit() * (configuration.arenaWidth - margin * 2), y: configuration.arenaHeight - margin)
        }

        let roll = generator.unit()
        let kind: SpaceEnemyKind
        if wave >= 3, roll > 0.78 {
            kind = .gunship
        } else if wave >= 2, roll > 0.48 {
            kind = .charger
        } else {
            kind = .hunter
        }
        let baseHealth: Double
        let radius: Double
        switch kind {
        case .hunter: (baseHealth, radius) = (22, 19)
        case .charger: (baseHealth, radius) = (34, 23)
        case .gunship: (baseHealth, radius) = (52, 28)
        }
        let health = baseHealth * (1 + Double(wave - 1) * 0.10)
        enemies.append(Enemy(
            id: makeIdentifier(),
            kind: kind,
            position: position,
            health: health,
            maximumHealth: health,
            radius: radius,
            attackCooldown: 0.6 + generator.unit(),
            behaviorClock: generator.unit() * .pi * 2
        ))
    }

    private mutating func updateEnemies(events: inout [SpaceGameEvent], dt: Double) {
        for index in enemies.indices {
            let toPlayer = player.position - enemies[index].position
            let distance = max(1, toPlayer.length)
            let direction = toPlayer / distance
            enemies[index].behaviorClock += dt
            enemies[index].attackCooldown -= dt

            let desired: SpaceVector
            let acceleration: Double
            switch enemies[index].kind {
            case .hunter:
                let tangent = SpaceVector(x: -direction.y, y: direction.x)
                desired = direction * 126 + tangent * sin(enemies[index].behaviorClock * 2.2) * 58
                acceleration = 340
            case .charger:
                let surge = sin(enemies[index].behaviorClock * 1.7) > 0.58
                desired = direction * (surge ? 260 : 76)
                acceleration = surge ? 780 : 250
            case .gunship:
                let tangent = SpaceVector(x: -direction.y, y: direction.x)
                let radial = direction * ((distance - 285) * 0.72)
                desired = (radial + tangent * 112).limited(to: 165)
                acceleration = 300
                if enemies[index].attackCooldown <= 0, distance < 560 {
                    let muzzle = enemies[index].position + direction * (enemies[index].radius + 8)
                    projectiles.append(Projectile(
                        id: makeIdentifier(),
                        owner: .enemy,
                        position: muzzle,
                        velocity: direction * 305,
                        damage: 12,
                        lifetime: 2.1,
                        radius: 6
                    ))
                    enemies[index].attackCooldown = max(0.72, 1.36 - Double(wave) * 0.025)
                    events.append(.enemyFired(position: muzzle))
                }
            }

            let steering = (desired - enemies[index].velocity).limited(to: acceleration * dt)
            enemies[index].velocity = enemies[index].velocity + steering
            enemies[index].position = clampedEnemyPosition(
                enemies[index].position + enemies[index].velocity * dt,
                radius: enemies[index].radius
            )
        }
    }

    private mutating func autoFire(events: inout [SpaceGameEvent]) {
        guard player.fireCooldown <= 0,
              let target = enemies.min(by: {
                  ($0.position - player.position).lengthSquared < ($1.position - player.position).lengthSquared
              }) else { return }

        let direction = (target.position - player.position).normalized
        let muzzle = player.position + direction * 24
        projectiles.append(Projectile(
            id: makeIdentifier(),
            owner: .player,
            position: muzzle,
            velocity: direction * 670,
            damage: 14,
            lifetime: 1.5,
            radius: 5
        ))
        player.fireCooldown += configuration.playerFireInterval
        events.append(.playerFired(position: muzzle))
    }

    private mutating func updateProjectiles(dt: Double) {
        for index in projectiles.indices {
            projectiles[index].position = projectiles[index].position + projectiles[index].velocity * dt
            projectiles[index].lifetime -= dt
        }
        projectiles.removeAll {
            $0.lifetime <= 0 || $0.position.x < -50 || $0.position.y < -50 ||
                $0.position.x > configuration.arenaWidth + 50 || $0.position.y > configuration.arenaHeight + 50
        }
    }

    private mutating func resolveProjectileCollisions(events: inout [SpaceGameEvent]) {
        var projectileIDsToRemove = Set<Int>()
        var enemyDamage: [Int: Double] = [:]

        for projectile in projectiles where projectile.owner == .player {
            if let enemy = enemies.first(where: {
                let radius = projectile.radius + $0.radius
                return ($0.position - projectile.position).lengthSquared <= radius * radius
            }) {
                projectileIDsToRemove.insert(projectile.id)
                enemyDamage[enemy.id, default: 0] += projectile.damage
                events.append(.impact(position: projectile.position, hostile: false))
            }
        }

        for projectile in projectiles where projectile.owner == .enemy {
            let collisionRadius = projectile.radius + 17
            if (projectile.position - player.position).lengthSquared <= collisionRadius * collisionRadius {
                projectileIDsToRemove.insert(projectile.id)
                damagePlayer(projectile.damage, at: projectile.position, events: &events)
            }
        }

        if !enemyDamage.isEmpty {
            for index in enemies.indices {
                enemies[index].health -= enemyDamage[enemies[index].id, default: 0]
            }
            let destroyed = enemies.filter { $0.health <= 0 }
            for enemy in destroyed {
                registerDestruction(enemy, events: &events)
            }
            let destroyedIDs = Set(destroyed.map(\.id))
            enemies.removeAll { destroyedIDs.contains($0.id) }
        }
        projectiles.removeAll { projectileIDsToRemove.contains($0.id) }
    }

    private mutating func resolveContactCollisions(events: inout [SpaceGameEvent]) {
        for index in enemies.indices {
            let delta = player.position - enemies[index].position
            let collisionRadius = 17 + enemies[index].radius
            guard delta.lengthSquared <= collisionRadius * collisionRadius else { continue }
            let direction = delta.normalized.lengthSquared > 0 ? delta.normalized : SpaceVector(x: 1, y: 0)
            enemies[index].velocity = enemies[index].velocity - direction * 120
            player.velocity = player.velocity + direction * 155
            let damage: Double
            switch enemies[index].kind {
            case .hunter: damage = 9
            case .charger: damage = 17
            case .gunship: damage = 13
            }
            damagePlayer(damage, at: player.position, events: &events)
        }
    }

    private mutating func damagePlayer(_ damage: Double, at position: SpaceVector, events: inout [SpaceGameEvent]) {
        guard phase == .playing, player.invulnerabilityRemaining <= 0 else { return }
        player.health = max(0, player.health - damage)
        player.invulnerabilityRemaining = 0.58
        combo = 0
        comboRemaining = 0
        events.append(.playerDamaged(position: position))
        if player.health <= 0 {
            phase = .gameOver
            events.append(.gameOver(score: score))
        }
    }

    private mutating func registerDestruction(_ enemy: Enemy, events: inout [SpaceGameEvent]) {
        combo += 1
        highCombo = max(highCombo, combo)
        comboRemaining = 2.4
        let value: Int
        switch enemy.kind {
        case .hunter: value = 100
        case .charger: value = 180
        case .gunship: value = 300
        }
        score += value + min(10, combo - 1) * 12
        events.append(.enemyDestroyed(position: enemy.position, kind: enemy.kind))
    }

    private func clampedPlayerPosition(_ point: SpaceVector) -> SpaceVector {
        SpaceVector(
            x: min(configuration.arenaWidth - 22, max(22, point.x)),
            y: min(configuration.arenaHeight - 22, max(22, point.y))
        )
    }

    private func clampedEnemyPosition(_ point: SpaceVector, radius: Double) -> SpaceVector {
        SpaceVector(
            x: min(configuration.arenaWidth - radius, max(radius, point.x)),
            y: min(configuration.arenaHeight - radius, max(radius, point.y))
        )
    }

    private mutating func makeIdentifier() -> Int {
        defer { nextIdentifier += 1 }
        return nextIdentifier
    }
}
