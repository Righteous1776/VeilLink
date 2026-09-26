import Combine
import CryptoKit
import Foundation

struct VeilLegalAcceptanceRecord: Codable, Equatable {
    let schemaVersion: Int
    let legalDocumentVersion: String
    let appVersion: String
    let buildNumber: String
    let documentSHA256: String
    let acceptedAt: Date
    let acceptanceID: String
    let acknowledgment: String
}

@MainActor
final class VeilLegalConsentController: ObservableObject {
    static let documentVersion = "2026.09.26-r1"
    static let requiredAcknowledgment = "我已阅读并同意"

    @Published private(set) var isSatisfied = false
    @Published private(set) var currentRecord: VeilLegalAcceptanceRecord?
    @Published private(set) var integrityFailureDetected = false

    private let keychain: KeychainStore
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private enum Key {
        static let record = "legal.acceptance.record.v1"
        static let mac = "legal.acceptance.mac.v1"
        static let macKey = "legal.acceptance.mac-key.v1"
    }

    init(keychain: KeychainStore) {
        self.keychain = keychain
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        reload()
    }

    var currentAppVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    var currentBuildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    var currentReleaseID: String { "\(currentAppVersion)(\(currentBuildNumber))" }

    var currentDocumentSHA256: String {
        Self.sha256Hex(Data(VeilLegalDocuments.canonicalText.utf8))
    }

    var needsSignatureReason: String {
        guard let record = currentRecord else { return integrityFailureDetected ? "本地签署记录完整性校验失败" : "首次使用需要签署" }
        if record.legalDocumentVersion != Self.documentVersion { return "协议版本已更新" }
        if record.appVersion != currentAppVersion || record.buildNumber != currentBuildNumber { return "VeilLink 已更新，需要重新确认" }
        if record.documentSHA256 != currentDocumentSHA256 { return "协议正文已更新" }
        return isSatisfied ? "已签署" : "签署记录无效"
    }

    @discardableResult
    func accept(acknowledgment raw: String) -> Bool {
        let acknowledgment = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard acknowledgment == Self.requiredAcknowledgment else { return false }

        do {
            let record = VeilLegalAcceptanceRecord(
                schemaVersion: 1,
                legalDocumentVersion: Self.documentVersion,
                appVersion: currentAppVersion,
                buildNumber: currentBuildNumber,
                documentSHA256: currentDocumentSHA256,
                acceptedAt: Date(),
                acceptanceID: UUID().uuidString,
                acknowledgment: acknowledgment
            )
            let encoded = try encoder.encode(record)
            let mac = try authenticationCode(for: encoded)
            try keychain.set(encoded, for: Key.record)
            try keychain.set(mac, for: Key.mac)
            currentRecord = record
            integrityFailureDetected = false
            isSatisfied = validate(record: record)
            return isSatisfied
        } catch {
            isSatisfied = false
            return false
        }
    }

    func withdraw() {
        keychain.remove(Key.record)
        keychain.remove(Key.mac)
        currentRecord = nil
        integrityFailureDetected = false
        isSatisfied = false
    }

    func reload() {
        guard let encoded = keychain.data(for: Key.record),
              let storedMAC = keychain.data(for: Key.mac),
              let record = try? decoder.decode(VeilLegalAcceptanceRecord.self, from: encoded) else {
            currentRecord = nil
            isSatisfied = false
            integrityFailureDetected = false
            return
        }
        do {
            let expectedMAC = try authenticationCode(for: encoded)
            guard timingSafeEqual(storedMAC, expectedMAC) else {
                currentRecord = nil
                isSatisfied = false
                integrityFailureDetected = true
                return
            }
            currentRecord = record
            integrityFailureDetected = false
            isSatisfied = validate(record: record)
        } catch {
            currentRecord = nil
            isSatisfied = false
            integrityFailureDetected = true
        }
    }

    func evidenceJSON() -> Data? {
        guard let currentRecord else { return nil }
        let exportEncoder = JSONEncoder()
        exportEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        exportEncoder.dateEncodingStrategy = .iso8601
        return try? exportEncoder.encode(currentRecord)
    }

    private func validate(record: VeilLegalAcceptanceRecord) -> Bool {
        record.schemaVersion == 1 &&
        record.legalDocumentVersion == Self.documentVersion &&
        record.appVersion == currentAppVersion &&
        record.buildNumber == currentBuildNumber &&
        record.documentSHA256 == currentDocumentSHA256 &&
        record.acknowledgment == Self.requiredAcknowledgment
    }

    private func authenticationCode(for data: Data) throws -> Data {
        let keyData: Data
        if let existing = keychain.data(for: Key.macKey), existing.count == 32 {
            keyData = existing
        } else {
            let key = SymmetricKey(size: .bits256)
            keyData = key.withUnsafeBytes { Data($0) }
            try keychain.set(keyData, for: Key.macKey)
        }
        return Data(HMAC<SHA256>.authenticationCode(for: data, using: SymmetricKey(data: keyData)))
    }

    private func timingSafeEqual(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var diff: UInt8 = 0
        for index in lhs.indices { diff |= lhs[index] ^ rhs[index] }
        return diff == 0
    }

    private static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

enum VeilLegalDocuments {
    static let permissions = """
    VeilLink 权限授权与隐私说明

    1. 蓝牙：用于发现附近 VeilLink 设备、建立 BLE 链路、发送端到端加密消息和进行近距离中继。关闭该权限后，附近通信能力会受到限制。

    2. 局域网与 Bonjour：用于在同一 Wi‑Fi、热点或 Apple 允许的点对点网络能力下建立高速直连。VeilLink 不会因为你同意本说明而绕过 iOS 的系统权限；系统仍会在需要时单独询问。

    3. 麦克风：仅在你主动录制语音消息、使用对讲或其他明确需要录音的功能时使用。拒绝麦克风权限不会授权 VeilLink 以其他方式获取录音。

    4. 照片：优先使用系统选择器导入图片。只有在你主动保存或开启自动保存时，才请求与照片写入有关的权限。

    5. 通知、Live Activity 与后台能力：用于显示通信状态、提醒和提升系统允许范围内的后台连续性。iOS 仍可随时挂起或终止 App，VeilLink 不保证永久后台在线。

    6. Internet Relay：启用互联网远程通信后，密文可能经过国内/国际第三方基础设施。VeilLink 设计为让 Relay 无法读取消息正文，但网络服务商仍可能观察 IP、时间、流量大小等元数据。

    7. 权限最小化：VeilLink 应只在功能实际需要时请求对应系统权限。你可以在 iOS 设置中撤销系统权限；撤销后相关功能可能不可用。
    """

    static let terms = """
    VeilLink 使用条款、风险告知与开发者责任边界

    1. VeilLink 是端到端加密通信与本地网络实验性软件，不应被用于紧急求救、生命安全、医疗、消防、灾害指挥或其他要求持续可用性的关键通信场景。

    2. BLE、局域网、热点、P2P Wi‑Fi、Mesh、中继、后台运行以及第三方网络服务均受设备、操作系统、无线环境和服务商限制。开发者不承诺持续在线、绝对送达、绝对匿名、绝对无延迟或绝对无数据丢失。

    3. 用户应自行对重要内容进行备份，并对自己发送、保存、转发和公开发布的内容及其合法性负责。不得利用 VeilLink 侵害他人合法权益或实施违法行为。

    4. VeilLink 尽力通过端到端加密、身份验证、重放保护、最小化元数据和本地安全存储降低风险，但任何软件、密码学实现、设备或网络环境都不能被描述为“绝对安全”。

    5. 在法律允许的范围内，对于由设备故障、无线干扰、系统限制、第三方服务中断、用户误操作或不可抗力直接引起的间接损失、预期利益损失或数据不可用，开发者不作超出法律强制规定的保证或责任承诺。

    6. 本条款不排除或限制依法不得排除或限制的责任；因故意或者重大过失造成财产损失的法定责任，以及依法不得免除的人身损害责任，不因本条款而被排除。

    7. 本 App 的权限说明、隐私说明和责任边界属于重要条款。你应完整阅读。若不同意，请不要签署；VeilLink 将保持锁定且不会启动核心通信服务。

    8. 每次 App 版本、Build 或协议正文更新后，原签署记录自动失效，需要重新确认。签署行为只证明你在该设备上明确作出同意表示，不意味着任何法律制度下的全部争议都必然按开发者单方面理解解决。

    9. 本条款的解释与效力受适用法律中的强制性规定约束。若某一条款被认定无效，不当然影响其他可分割条款的效力。
    """

    static let canonicalText = [permissions, terms].joined(separator: "\n\n---\n\n")
}
