package studio.zeo.veillink.protocol

import java.security.SecureRandom
import java.util.Base64
import java.util.UUID

/** Pure protocol representation of iOS VeilRemotePairQRCode. */
data class RemotePairingPayload(
    val version: Int,
    val offerID: String,
    val offerSecret: ByteArray,
    val initiatorEphemeralPublicKey: ByteArray,
    val createdAtMs: Long,
    val expiresAtMs: Long
)

object RemotePairingPayloadCodec {
    const val PREFIX = "veillink://pair?v=1&d="
    const val LIFETIME_MS = 60_000L

    fun createOffer(ephemeralPublicKey: ByteArray, nowMs: Long = System.currentTimeMillis()): RemotePairingPayload {
        require(ephemeralPublicKey.size == 32)
        return RemotePairingPayload(
            version = 1,
            offerID = UUID.randomUUID().toString().uppercase(),
            offerSecret = ByteArray(32).also { SecureRandom().nextBytes(it) },
            initiatorEphemeralPublicKey = ephemeralPublicKey.copyOf(),
            createdAtMs = nowMs,
            expiresAtMs = nowMs + LIFETIME_MS
        )
    }

    fun encode(payload: RemotePairingPayload): String {
        validate(payload, payload.createdAtMs)
        val std = Base64.getEncoder()
        val json = buildString {
            append('{')
            append("\"version\":").append(payload.version).append(',')
            append("\"offerID\":\"").append(payload.offerID).append("\",")
            append("\"offerSecret\":\"").append(std.encodeToString(payload.offerSecret)).append("\",")
            append("\"initiatorEphemeralPublicKey\":\"").append(std.encodeToString(payload.initiatorEphemeralPublicKey)).append("\",")
            append("\"createdAt\":").append(payload.createdAtMs).append(',')
            append("\"expiresAt\":").append(payload.expiresAtMs)
            append('}')
        }
        return PREFIX + Base64.getUrlEncoder().withoutPadding().encodeToString(json.toByteArray())
    }

    fun decode(text: String, nowMs: Long = System.currentTimeMillis()): RemotePairingPayload {
        require(text.startsWith(PREFIX))
        val json = String(Base64.getUrlDecoder().decode(padBase64Url(text.removePrefix(PREFIX))))
        val payload = RemotePairingPayload(
            version = number(json, "version").toInt(),
            offerID = string(json, "offerID"),
            offerSecret = Base64.getDecoder().decode(string(json, "offerSecret")),
            initiatorEphemeralPublicKey = Base64.getDecoder().decode(string(json, "initiatorEphemeralPublicKey")),
            createdAtMs = number(json, "createdAt"),
            expiresAtMs = number(json, "expiresAt")
        )
        validate(payload, nowMs)
        return payload
    }

    fun validate(payload: RemotePairingPayload, nowMs: Long = System.currentTimeMillis()) {
        require(payload.version == 1)
        UUID.fromString(payload.offerID)
        require(payload.offerSecret.size == 32 && payload.initiatorEphemeralPublicKey.size == 32)
        require(payload.expiresAtMs > payload.createdAtMs)
        require(payload.expiresAtMs - payload.createdAtMs <= LIFETIME_MS + 2_000)
        require(payload.createdAtMs - nowMs < 10_000)
        require(nowMs <= payload.expiresAtMs) { "expired" }
    }

    private fun string(json: String, key: String): String {
        val m = Regex("\\\"${Regex.escape(key)}\\\"\\s*:\\s*\\\"([^\\\"]*)\\\"").find(json) ?: error("missing $key")
        return m.groupValues[1]
    }

    private fun number(json: String, key: String): Long {
        val m = Regex("\\\"${Regex.escape(key)}\\\"\\s*:\\s*(-?[0-9]+(?:\\.[0-9]+)?)").find(json) ?: error("missing $key")
        return m.groupValues[1].substringBefore('.').toLong()
    }

    private fun padBase64Url(value: String) = value + "=".repeat((4 - value.length % 4) % 4)
}
