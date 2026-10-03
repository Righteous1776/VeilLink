import CoreGraphics
import Foundation

/// Declarative level data for the real-time platformer. Keeping geometry out
/// of the SpriteKit scene makes new stages inexpensive to author and validate.
struct PlatformerLevel: Equatable, Sendable {
    struct Platform: Equatable, Sendable {
        let frame: CGRect
        let style: Style

        enum Style: Equatable, Sendable {
            case ground
            case floating
            case glass
        }
    }

    struct Hazard: Equatable, Sendable {
        let frame: CGRect
    }

    struct Patrol: Equatable, Sendable {
        let origin: CGPoint
        let travel: CGFloat
        let duration: TimeInterval
    }

    let name: String
    let subtitle: String
    let worldSize: CGSize
    let spawn: CGPoint
    let exit: CGPoint
    let platforms: [Platform]
    let hazards: [Hazard]
    let crystals: [CGPoint]
    let springs: [CGPoint]
    let patrols: [Patrol]

    var requiredCrystalCount: Int { crystals.count }

    var isValid: Bool {
        worldSize.width >= 1_280 && worldSize.height >= 720
            && spawn.x >= 0 && spawn.x <= worldSize.width
            && spawn.y >= 0 && spawn.y <= worldSize.height
            && exit.x >= 0 && exit.x <= worldSize.width
            && exit.y >= 0 && exit.y <= worldSize.height
            && platforms.allSatisfy { platform in
                platform.frame.width > 0 && platform.frame.height > 0
                    && platform.frame.minX >= 0 && platform.frame.maxX <= worldSize.width
            }
    }
}

extension PlatformerLevel {
    static let campaign: [PlatformerLevel] = [skylineRelay, prismFoundry, auroraSpine]

    static let skylineRelay = PlatformerLevel(
        name: "天际中继站",
        subtitle: "穿过霓虹屋脊，找回散落的星核",
        worldSize: CGSize(width: 3_700, height: 1_050),
        spawn: CGPoint(x: 150, y: 190),
        exit: CGPoint(x: 3_510, y: 305),
        platforms: [
            .init(frame: CGRect(x: 0, y: 0, width: 760, height: 105), style: .ground),
            .init(frame: CGRect(x: 860, y: 0, width: 520, height: 105), style: .ground),
            .init(frame: CGRect(x: 1_470, y: 0, width: 720, height: 105), style: .ground),
            .init(frame: CGRect(x: 2_290, y: 0, width: 580, height: 105), style: .ground),
            .init(frame: CGRect(x: 2_990, y: 0, width: 710, height: 105), style: .ground),
            .init(frame: CGRect(x: 410, y: 255, width: 250, height: 34), style: .floating),
            .init(frame: CGRect(x: 850, y: 335, width: 250, height: 34), style: .glass),
            .init(frame: CGRect(x: 1_245, y: 235, width: 225, height: 34), style: .floating),
            .init(frame: CGRect(x: 1_680, y: 405, width: 285, height: 34), style: .glass),
            .init(frame: CGRect(x: 2_160, y: 285, width: 240, height: 34), style: .floating),
            .init(frame: CGRect(x: 2_650, y: 445, width: 290, height: 34), style: .glass),
            .init(frame: CGRect(x: 3_220, y: 225, width: 400, height: 34), style: .floating)
        ],
        hazards: [
            .init(frame: CGRect(x: 760, y: 8, width: 100, height: 46)),
            .init(frame: CGRect(x: 1_380, y: 8, width: 90, height: 46)),
            .init(frame: CGRect(x: 2_190, y: 8, width: 100, height: 46)),
            .init(frame: CGRect(x: 2_870, y: 8, width: 120, height: 46))
        ],
        crystals: [
            CGPoint(x: 530, y: 345), CGPoint(x: 970, y: 425),
            CGPoint(x: 1_790, y: 500), CGPoint(x: 2_280, y: 375),
            CGPoint(x: 2_790, y: 540), CGPoint(x: 3_390, y: 320)
        ],
        springs: [CGPoint(x: 1_570, y: 125), CGPoint(x: 3_080, y: 125)],
        patrols: [
            .init(origin: CGPoint(x: 1_810, y: 470), travel: 105, duration: 2.1),
            .init(origin: CGPoint(x: 2_510, y: 150), travel: 190, duration: 3.0)
        ]
    )

    static let prismFoundry = PlatformerLevel(
        name: "棱镜铸造厂",
        subtitle: "借弹射脉冲越过熔光流水线",
        worldSize: CGSize(width: 4_150, height: 1_180),
        spawn: CGPoint(x: 150, y: 205),
        exit: CGPoint(x: 3_970, y: 600),
        platforms: [
            .init(frame: CGRect(x: 0, y: 0, width: 620, height: 110), style: .ground),
            .init(frame: CGRect(x: 760, y: 0, width: 400, height: 110), style: .ground),
            .init(frame: CGRect(x: 1_300, y: 0, width: 460, height: 110), style: .ground),
            .init(frame: CGRect(x: 1_900, y: 0, width: 380, height: 110), style: .ground),
            .init(frame: CGRect(x: 2_430, y: 0, width: 510, height: 110), style: .ground),
            .init(frame: CGRect(x: 3_100, y: 0, width: 1_050, height: 110), style: .ground),
            .init(frame: CGRect(x: 450, y: 310, width: 260, height: 35), style: .glass),
            .init(frame: CGRect(x: 900, y: 455, width: 240, height: 35), style: .floating),
            .init(frame: CGRect(x: 1_325, y: 625, width: 260, height: 35), style: .glass),
            .init(frame: CGRect(x: 1_780, y: 465, width: 285, height: 35), style: .floating),
            .init(frame: CGRect(x: 2_230, y: 655, width: 250, height: 35), style: .glass),
            .init(frame: CGRect(x: 2_700, y: 430, width: 285, height: 35), style: .floating),
            .init(frame: CGRect(x: 3_170, y: 620, width: 350, height: 35), style: .glass),
            .init(frame: CGRect(x: 3_690, y: 510, width: 420, height: 35), style: .floating)
        ],
        hazards: [
            .init(frame: CGRect(x: 620, y: 8, width: 140, height: 48)),
            .init(frame: CGRect(x: 1_160, y: 8, width: 140, height: 48)),
            .init(frame: CGRect(x: 1_760, y: 8, width: 140, height: 48)),
            .init(frame: CGRect(x: 2_280, y: 8, width: 150, height: 48)),
            .init(frame: CGRect(x: 2_940, y: 8, width: 160, height: 48))
        ],
        crystals: [
            CGPoint(x: 570, y: 400), CGPoint(x: 1_020, y: 545),
            CGPoint(x: 1_455, y: 720), CGPoint(x: 1_920, y: 560),
            CGPoint(x: 2_355, y: 750), CGPoint(x: 2_845, y: 525),
            CGPoint(x: 3_335, y: 715), CGPoint(x: 3_850, y: 605)
        ],
        springs: [CGPoint(x: 830, y: 130), CGPoint(x: 1_965, y: 130), CGPoint(x: 3_245, y: 130)],
        patrols: [
            .init(origin: CGPoint(x: 1_455, y: 690), travel: 95, duration: 1.8),
            .init(origin: CGPoint(x: 2_830, y: 495), travel: 105, duration: 2.0),
            .init(origin: CGPoint(x: 3_380, y: 165), travel: 280, duration: 3.6)
        ]
    )

    static let auroraSpine = PlatformerLevel(
        name: "极光之脊",
        subtitle: "在风暴抵达前点亮最后一座信标",
        worldSize: CGSize(width: 4_650, height: 1_320),
        spawn: CGPoint(x: 140, y: 210),
        exit: CGPoint(x: 4_450, y: 900),
        platforms: [
            .init(frame: CGRect(x: 0, y: 0, width: 660, height: 110), style: .ground),
            .init(frame: CGRect(x: 800, y: 0, width: 390, height: 110), style: .ground),
            .init(frame: CGRect(x: 1_340, y: 0, width: 410, height: 110), style: .ground),
            .init(frame: CGRect(x: 1_920, y: 0, width: 440, height: 110), style: .ground),
            .init(frame: CGRect(x: 2_520, y: 0, width: 460, height: 110), style: .ground),
            .init(frame: CGRect(x: 3_140, y: 0, width: 500, height: 110), style: .ground),
            .init(frame: CGRect(x: 3_800, y: 0, width: 850, height: 110), style: .ground),
            .init(frame: CGRect(x: 480, y: 330, width: 250, height: 34), style: .glass),
            .init(frame: CGRect(x: 900, y: 520, width: 270, height: 34), style: .floating),
            .init(frame: CGRect(x: 1_340, y: 715, width: 260, height: 34), style: .glass),
            .init(frame: CGRect(x: 1_780, y: 490, width: 270, height: 34), style: .floating),
            .init(frame: CGRect(x: 2_190, y: 720, width: 260, height: 34), style: .glass),
            .init(frame: CGRect(x: 2_640, y: 925, width: 300, height: 34), style: .floating),
            .init(frame: CGRect(x: 3_130, y: 690, width: 300, height: 34), style: .glass),
            .init(frame: CGRect(x: 3_610, y: 885, width: 285, height: 34), style: .floating),
            .init(frame: CGRect(x: 4_090, y: 810, width: 500, height: 34), style: .glass)
        ],
        hazards: [
            .init(frame: CGRect(x: 660, y: 8, width: 140, height: 48)),
            .init(frame: CGRect(x: 1_190, y: 8, width: 150, height: 48)),
            .init(frame: CGRect(x: 1_750, y: 8, width: 170, height: 48)),
            .init(frame: CGRect(x: 2_360, y: 8, width: 160, height: 48)),
            .init(frame: CGRect(x: 2_980, y: 8, width: 160, height: 48)),
            .init(frame: CGRect(x: 3_640, y: 8, width: 160, height: 48))
        ],
        crystals: [
            CGPoint(x: 600, y: 425), CGPoint(x: 1_035, y: 615),
            CGPoint(x: 1_470, y: 810), CGPoint(x: 1_910, y: 585),
            CGPoint(x: 2_320, y: 815), CGPoint(x: 2_790, y: 1_020),
            CGPoint(x: 3_280, y: 785), CGPoint(x: 3_755, y: 980),
            CGPoint(x: 4_300, y: 905)
        ],
        springs: [
            CGPoint(x: 860, y: 130), CGPoint(x: 1_975, y: 130),
            CGPoint(x: 2_590, y: 130), CGPoint(x: 3_245, y: 130)
        ],
        patrols: [
            .init(origin: CGPoint(x: 1_470, y: 780), travel: 95, duration: 1.7),
            .init(origin: CGPoint(x: 2_790, y: 990), travel: 115, duration: 2.1),
            .init(origin: CGPoint(x: 3_760, y: 950), travel: 105, duration: 1.9),
            .init(origin: CGPoint(x: 4_130, y: 165), travel: 320, duration: 3.5)
        ]
    )
}
