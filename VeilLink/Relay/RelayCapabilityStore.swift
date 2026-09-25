import Foundation

struct VeilRelayProvisionPacket: Codable, Equatable, Sendable {
    let version: UInt8
    let ownerIdentityID: String
    let peerIdentityID: String
    let secret: Data
    let createdAt: Date
}

@MainActor
final class VeilRelayCapabilityStore {
    private let keychain: KeychainStore
    private unowned let identity: IdentityManager

    init(keychain: KeychainStore, identity: IdentityManager) {
        self.keychain = keychain
        self.identity = identity
    }

    func secret(for peerIdentityID: String) -> Data? {
        guard let localIdentityID = identity.activeIdentity?.id else { return nil }
        let value = keychain.data(for: key(localIdentityID: localIdentityID, peerIdentityID: peerIdentityID))
        guard value?.count == 32 else { return nil }
        return value
    }

    func provisioningSecretIfOwner(for peerIdentityID: String) -> Data? {
        guard let localIdentityID = identity.activeIdentity?.id,
              localIdentityID < peerIdentityID else { return nil }
        if let existing = secret(for: peerIdentityID) { return existing }
        let generated = PasswordKDF.randomData(count: 32)
        guard generated.count == 32 else { return nil }
        try? keychain.set(generated, for: key(localIdentityID: localIdentityID, peerIdentityID: peerIdentityID))
        return generated
    }

    @discardableResult
    func install(_ packet: VeilRelayProvisionPacket, from remoteIdentityID: String) -> Bool {
        guard packet.version == 1,
              packet.secret.count == 32,
              let localIdentityID = identity.activeIdentity?.id,
              packet.ownerIdentityID == remoteIdentityID,
              packet.ownerIdentityID == min(localIdentityID, remoteIdentityID),
              packet.peerIdentityID == max(localIdentityID, remoteIdentityID),
              abs(packet.createdAt.timeIntervalSinceNow) <= 30 * 24 * 60 * 60 else { return false }
        do {
            try keychain.set(packet.secret, for: key(localIdentityID: localIdentityID, peerIdentityID: remoteIdentityID))
            return true
        } catch {
            return false
        }
    }

    func installRemotePairingSecret(_ secret: Data, peerIdentityID: String) throws {
        guard secret.count == 32,
              let localIdentityID = identity.activeIdentity?.id,
              localIdentityID != peerIdentityID else { throw VeilRelayCryptoError.invalidSecret }
        try keychain.set(secret, for: key(localIdentityID: localIdentityID, peerIdentityID: peerIdentityID))
    }

    func resetForIdentityChange() {
        // Pair secrets are identity-scoped in Keychain and intentionally retained for that identity.
        // The active transport is rebuilt by InternetRelayTransport after the identity switch.
    }

    private func key(localIdentityID: String, peerIdentityID: String) -> String {
        "relay.pair.v1.\(localIdentityID).\(peerIdentityID)"
    }
}
