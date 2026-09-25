package studio.zeo.veillink.android.pairing

import java.util.Base64
import studio.zeo.veillink.android.crypto.VeilCrypto
import studio.zeo.veillink.protocol.RemotePairingPayload
import java.nio.ByteBuffer

enum class RemotePairDirection(val raw: String) { TO_INITIATOR("toInitiator"), TO_RESPONDER("toResponder") }
enum class RemotePairRegion(val raw: String) { DOMESTIC("domestic"), INTERNATIONAL("international") }
data class RemotePairRoute(val mailbox: String, val readToken: String, val writeToken: String)

object RemotePairingCrypto {
    fun route(qr: RemotePairingPayload, region: RemotePairRegion, direction: RemotePairDirection): RemotePairRoute {
        validateStructure(qr)
        val context = "${region.raw}|${direction.raw}|${qr.offerID}"
        return RemotePairRoute(
            mailbox = token(qr.offerSecret, "mailbox|$context", 24),
            readToken = token(qr.offerSecret, "read|$context", 32),
            writeToken = token(qr.offerSecret, "write|$context", 32)
        )
    }

    fun bootstrapKey(localEphemeralPrivateKey: ByteArray, remoteEphemeralPublicKey: ByteArray, qr: RemotePairingPayload): ByteArray {
        validateStructure(qr)
        val shared = VeilCrypto.x25519(localEphemeralPrivateKey, remoteEphemeralPublicKey)
        return VeilCrypto.hkdfSha256(shared, qr.offerSecret, "VeilLink/RemotePair/Bootstrap/v1|${qr.offerID}".toByteArray())
    }

    fun finalPairSecret(
        localEphemeralPrivateKey: ByteArray,
        remoteEphemeralPublicKey: ByteArray,
        qr: RemotePairingPayload,
        initiatorIdentityID: String,
        responderIdentityID: String,
        initiatorPublicKey: ByteArray,
        responderPublicKey: ByteArray
    ): ByteArray {
        val shared = VeilCrypto.x25519(localEphemeralPrivateKey, remoteEphemeralPublicKey)
        val prefix = "VeilLink/RemotePair/PairSecret/v1|${qr.offerID}|$initiatorIdentityID|$responderIdentityID".toByteArray()
        val info = prefix + lengthPrefixed(initiatorPublicKey) + lengthPrefixed(responderPublicKey)
        return VeilCrypto.hkdfSha256(shared, qr.offerSecret, info)
    }

    fun sas(pairSecret: ByteArray, offerID: String, initiatorIdentityID: String, responderIdentityID: String): String {
        val mac = VeilCrypto.hmacSha256(pairSecret, "VeilLink/RemotePair/SAS/v1|$offerID|$initiatorIdentityID|$responderIdentityID".toByteArray())
        val value = ((mac[0].toLong() and 255) shl 24) or ((mac[1].toLong() and 255) shl 16) or ((mac[2].toLong() and 255) shl 8) or (mac[3].toLong() and 255)
        return "%06d".format(value % 1_000_000)
    }

    fun outerKey(qr: RemotePairingPayload, region: RemotePairRegion, direction: RemotePairDirection): ByteArray =
        VeilCrypto.hkdfSha256(
            qr.offerSecret,
            "VeilLink/RemotePair/OuterSalt/v1".toByteArray(),
            "${region.raw}|${direction.raw}|${qr.offerID}".toByteArray()
        )

    private fun token(secret: ByteArray, label: String, bytes: Int): String {
        val mac = VeilCrypto.hmacSha256(secret, "VeilLink/RemotePair/v1|$label".toByteArray()).copyOf(bytes)
        return Base64.getUrlEncoder().withoutPadding().encodeToString(mac)
    }

    private fun validateStructure(qr: RemotePairingPayload) {
        require(qr.version == 1 && qr.offerSecret.size == 32 && qr.initiatorEphemeralPublicKey.size == 32)
        java.util.UUID.fromString(qr.offerID)
    }

    private fun lengthPrefixed(value: ByteArray): ByteArray = ByteBuffer.allocate(4 + value.size).putInt(value.size).put(value).array()
}
