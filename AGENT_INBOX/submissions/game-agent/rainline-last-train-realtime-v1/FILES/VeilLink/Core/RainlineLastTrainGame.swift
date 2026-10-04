import Foundation

enum RainlineOutcome: Equatable, Sendable {
    case running
    case arrived
    case blackout
    case stalled
}

struct RainlineInput: Equatable, Sendable {
    var move: Double
    var repairing: Bool
    var boostGrid: Bool

    init(move: Double = 0, repairing: Bool = false, boostGrid: Bool = false) {
        self.move = min(1, max(-1, move))
        self.repairing = repairing
        self.boostGrid = boostGrid
    }
}

struct RainlineFault: Equatable, Sendable {
    let id: Int
    let car: Int
    let severity: Double
    let repairTicks: Int
}

struct RainlineStoryBeat: Equatable, Sendable {
    let progress: Double
    let line: String
}

struct RainlineSnapshot: Equatable, Sendable {
    let tick: Int
    let progress: Double
    let playerCar: Int
    let playerOffset: Double
    let trainPower: Double
    let traction: Double
    let litCars: Int
    let activeFaults: Int
    let repairedFaults: Int
    let rain: Double
    let outcome: RainlineOutcome
    let activeLine: String?
}

struct RainlineState: Equatable, Sendable {
    static let fixedDelta = 1.0 / 60.0
    static let carCount = 8
    static let routeTicks = 60 * 180

    let seed: UInt64

    private(set) var tick = 0
    private(set) var progress = 0.0
    private(set) var playerPosition = 1.4
    private(set) var playerVelocity = 0.0
    private(set) var trainPower = 100.0
    private(set) var traction = 100.0
    private(set) var carPower = Array(repeating: 1.0, count: carCount)
    private(set) var faults: [RainlineFault] = []
    private(set) var repairedFaultIDs: Set<Int> = []
    private(set) var repairTicks = 0
    private(set) var repairingFaultID: Int?
    private(set) var lastStoryIndex = -1
    private(set) var activeLine: String?
    private(set) var outcome: RainlineOutcome = .running

    init(seed: UInt64) {
        self.seed = seed
    }

    var isFinished: Bool { outcome != .running }

    var rainIntensity: Double {
        let a = (sin(Double(tick) * 0.006 + Double(seed % 79) * 0.041) + 1) * 0.5
        let b = (sin(Double(tick) * 0.0017 + Double(seed % 43) * 0.097) + 1) * 0.5
        return min(1, max(0, 0.28 + a * 0.38 + b * 0.24))
    }

    var playerCar: Int {
        min(Self.carCount - 1, max(0, Int(playerPosition.rounded(.down))))
    }

    var playerOffset: Double {
        playerPosition - Double(playerCar)
    }

    mutating func step(input: RainlineInput) {
        guard outcome == .running else { return }
        tick += 1

        spawnFaultIfNeeded()
        updatePlayer(input: input)
        updateRepair(input: input)
        updatePower(input: input)
        updateRoute()
        updateStory()
        resolveOutcome()
    }

    func fault(for car: Int) -> RainlineFault? {
        faults.first { $0.car == car && !repairedFaultIDs.contains($0.id) }
    }

    func snapshot() -> RainlineSnapshot {
        RainlineSnapshot(
            tick: tick,
            progress: progress,
            playerCar: playerCar,
            playerOffset: playerOffset,
            trainPower: trainPower,
            traction: traction,
            litCars: carPower.filter { $0 > 0.22 }.count,
            activeFaults: faults.filter { !repairedFaultIDs.contains($0.id) }.count,
            repairedFaults: repairedFaultIDs.count,
            rain: rainIntensity,
            outcome: outcome,
            activeLine: activeLine
        )
    }

    private mutating func updatePlayer(input: RainlineInput) {
        let targetVelocity = input.move * 2.7
        playerVelocity += (targetVelocity - playerVelocity) * 0.18
        playerPosition += playerVelocity * Self.fixedDelta
        playerPosition = min(Double(Self.carCount) - 0.001, max(0, playerPosition))

        if playerPosition <= 0 || playerPosition >= Double(Self.carCount) - 0.001 {
            playerVelocity *= 0.25
        }
    }

    private mutating func updateRepair(input: RainlineInput) {
        guard let fault = fault(for: playerCar), input.repairing, abs(playerVelocity) < 0.9 else {
            repairTicks = 0
            repairingFaultID = nil
            return
        }

        if repairingFaultID != fault.id {
            repairingFaultID = fault.id
            repairTicks = 0
        }

        repairTicks += 1
        if repairTicks >= fault.repairTicks {
            repairedFaultIDs.insert(fault.id)
            trainPower = min(100, trainPower + 4 + fault.severity * 2.5)
            carPower[fault.car] = min(1, carPower[fault.car] + 0.42)
            repairTicks = 0
            repairingFaultID = nil
            activeLine = repairLine(for: fault.car)
        }
    }

    private mutating func updatePower(input: RainlineInput) {
        let rain = rainIntensity
        let activeFaults = faults.filter { !repairedFaultIDs.contains($0.id) }
        let faultLoad = activeFaults.reduce(0.0) { $0 + $1.severity }
        let boostDrain = input.boostGrid ? 1.9 : 0
        let baseDrain = 0.36 + rain * 0.32 + faultLoad * 0.11 + boostDrain
        trainPower = max(0, trainPower - baseDrain * Self.fixedDelta)

        traction = max(0, min(100,
            traction + (input.boostGrid ? 4.8 : -0.25 - faultLoad * 0.03) * Self.fixedDelta
        ))

        for car in 0..<Self.carCount {
            let hasFault = activeFaults.contains { $0.car == car }
            let target = hasFault ? 0.08 : (trainPower > 22 ? 1.0 : max(0.08, trainPower / 22))
            let response = input.boostGrid ? 0.055 : 0.032
            carPower[car] += (target - carPower[car]) * response
            carPower[car] = min(1, max(0, carPower[car]))
        }
    }

    private mutating func updateRoute() {
        let tractionFactor = 0.42 + traction / 100 * 0.58
        progress = min(1, progress + tractionFactor / Double(Self.routeTicks))
    }

    private mutating func spawnFaultIfNeeded() {
        guard tick > 0, tick % 480 == Int(seed % 97) else { return }
        let id = tick / 8 + Int(seed % 1_000)
        let car = deterministicInt(salt: UInt64(id) ^ 0xA55A, upperBound: Self.carCount)
        guard fault(for: car) == nil else { return }
        let severity = 0.75 + deterministicUnit(salt: UInt64(id) ^ 0x91E1) * 1.45
        let repairTicks = 78 + deterministicInt(salt: UInt64(id) ^ 0xCAFE, upperBound: 88)
        faults.append(.init(id: id, car: car, severity: severity, repairTicks: repairTicks))
    }

    private mutating func updateStory() {
        let beats = Self.storyBeats
        guard lastStoryIndex + 1 < beats.count else { return }
        let next = lastStoryIndex + 1
        if progress >= beats[next].progress {
            lastStoryIndex = next
            activeLine = beats[next].line
        }
    }

    private mutating func resolveOutcome() {
        if progress >= 1 {
            outcome = .arrived
            activeLine = litCarsEndingLine()
        } else if trainPower <= 0 {
            outcome = .blackout
            activeLine = "列车广播：主电网熄灭。车内只剩下应急灯。"
        } else if traction <= 0 {
            outcome = .stalled
            activeLine = "司机：牵引断了。我们停在雨里。"
        }
    }

    private func litCarsEndingLine() -> String {
        let lit = carPower.filter { $0 > 0.22 }.count
        if lit == Self.carCount {
            return "终点站：八节车厢，全灯抵达。雨还在，但门已经打开。"
        } else if lit >= 5 {
            return "终点站：多数车厢亮着。有人开始从窗口看见站台。"
        } else {
            return "终点站：列车到了。后面的车厢一路都很安静。"
        }
    }

    private func repairLine(for car: Int) -> String {
        switch car {
        case 0: return "司机：驾驶台电压回来了。"
        case 1: return "一号车厢：灯亮了，谢谢。"
        case 2: return "二号车厢：别急着走，前面还有人。"
        case 3: return "三号车厢：孩子不哭了。"
        case 4: return "四号车厢：窗外全是雨，里面终于能看清人。"
        case 5: return "五号车厢：暖气也恢复了一点。"
        case 6: return "六号车厢：我们还能听见广播。"
        default: return "尾车：最后一盏灯重新亮了。"
        }
    }

    private func deterministicInt(salt: UInt64, upperBound: Int) -> Int {
        guard upperBound > 0 else { return 0 }
        return Int(mix(seed ^ salt) % UInt64(upperBound))
    }

    private func deterministicUnit(salt: UInt64) -> Double {
        Double(mix(seed ^ salt) & 0xFFFF) / Double(0xFFFF)
    }

    private func mix(_ input: UInt64) -> UInt64 {
        var z = input &+ 0x9E3779B97F4A7C15
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    static let storyBeats: [RainlineStoryBeat] = [
        .init(progress: 0.05, line: "广播：雨线已经压到高架桥。末班车不停站。"),
        .init(progress: 0.22, line: "司机：后面有一节车厢掉电了。能过去看看吗？"),
        .init(progress: 0.44, line: "乘客：窗外的楼都黑了，只有我们还在动。"),
        .init(progress: 0.68, line: "广播：下一段隧道没有市电。保持车内照明。"),
        .init(progress: 0.88, line: "司机：前面能看到终点站的灯了。把后面的车厢也带过去。")
    ]
}
