package studio.zeo.veillink.android.crypto

import org.bouncycastle.crypto.digests.SHA256Digest
import org.bouncycastle.crypto.generators.HKDFBytesGenerator
import org.bouncycastle.crypto.modes.ChaCha20Poly1305
import org.bouncycastle.crypto.params.AEADParameters
import org.bouncycastle.crypto.params.Ed25519PrivateKeyParameters
import org.bouncycastle.crypto.params.Ed25519PublicKeyParameters
import org.bouncycastle.crypto.params.HKDFParameters
import org.bouncycastle.crypto.params.KeyParameter
import org.bouncycastle.crypto.params.X25519PrivateKeyParameters
import org.bouncycastle.crypto.params.X25519PublicKeyParameters
import org.bouncycastle.math.ec.rfc8032.Ed25519
import studio.zeo.veillink.protocol.Base32
import java.security.MessageDigest
import java.security.SecureRandom
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

object VeilCrypto {
    private val random = SecureRandom()

    data class X25519KeyPair(val privateKey: ByteArray, val publicKey: ByteArray)
    data class Ed25519KeyPair(val privateSeed: ByteArray, val publicKey: ByteArray)

    fun newX25519(): X25519KeyPair {
        val p = X25519PrivateKeyParameters(random)
        return X25519KeyPair(p.encoded, p.generatePublicKey().encoded)
    }

    fun newEd25519(): Ed25519KeyPair {
        val p = Ed25519PrivateKeyParameters(random)
        return Ed25519KeyPair(p.encoded, p.generatePublicKey().encoded)
    }

    fun x25519(privateKey: ByteArray, remotePublicKey: ByteArray): ByteArray {
        require(privateKey.size == 32 && remotePublicKey.size == 32)
        val out = ByteArray(32)
        X25519PrivateKeyParameters(privateKey).generateSecret(X25519PublicKeyParameters(remotePublicKey), out, 0)
        return out
    }

    fun identityID(publicKey: ByteArray): String {
        require(publicKey.size == 32)
        val digest = MessageDigest.getInstance("SHA-256").digest(publicKey).copyOfRange(0, 16)
        return Base32.encode(digest).chunked(4).joinToString("-")
    }

    fun sign(privateSeed: ByteArray, message: ByteArray): ByteArray {
        require(privateSeed.size == 32)
        val sig = ByteArray(64)
        Ed25519PrivateKeyParameters(privateSeed).sign(Ed25519.Algorithm.Ed25519, null, message, 0, message.size, sig, 0)
        return sig
    }

    fun verify(publicKey: ByteArray, message: ByteArray, signature: ByteArray): Boolean {
        if (publicKey.size != 32 || signature.size != 64) return false
        return Ed25519PublicKeyParameters(publicKey).verify(Ed25519.Algorithm.Ed25519, null, message, 0, message.size, signature, 0)
    }

    fun hkdfSha256(ikm: ByteArray, salt: ByteArray?, info: ByteArray, outputSize: Int = 32): ByteArray {
        val hkdf = HKDFBytesGenerator(SHA256Digest())
        hkdf.init(HKDFParameters(ikm, salt, info))
        return ByteArray(outputSize).also { hkdf.generateBytes(it, 0, it.size) }
    }

    fun deriveSessionRoot(privateKey: ByteArray, remotePublicKey: ByteArray, transcript: ByteArray): ByteArray {
        val shared = x25519(privateKey, remotePublicKey)
        val salt = MessageDigest.getInstance("SHA-256").digest(transcript)
        return hkdfSha256(shared, salt, "VeilLink/SessionRoot/v4".toByteArray())
    }

    fun directionalKey(rootKey: ByteArray, senderIdentityID: String, receiverIdentityID: String): ByteArray =
        hkdfSha256(rootKey, ByteArray(0), "VeilLink/Direction/v4|$senderIdentityID|$receiverIdentityID".toByteArray())

    fun pairingCode(rootKey: ByteArray, transcript: ByteArray): String {
        val mac = hmacSha256(rootKey, transcript)
        val value = ((mac[0].toLong() and 255) shl 24) or ((mac[1].toLong() and 255) shl 16) or
            ((mac[2].toLong() and 255) shl 8) or (mac[3].toLong() and 255)
        return "%06d".format(value % 1_000_000)
    }

    fun chachaSeal(key: ByteArray, nonce: ByteArray, plaintext: ByteArray, aad: ByteArray): ByteArray {
        require(key.size == 32 && nonce.size == 12)
        val cipher = ChaCha20Poly1305()
        cipher.init(true, AEADParameters(KeyParameter(key), 128, nonce, aad))
        val out = ByteArray(cipher.getOutputSize(plaintext.size))
        var count = cipher.processBytes(plaintext, 0, plaintext.size, out, 0)
        count += cipher.doFinal(out, count)
        return nonce + out.copyOf(count)
    }

    fun chachaOpen(key: ByteArray, combined: ByteArray, aad: ByteArray): ByteArray {
        require(key.size == 32 && combined.size >= 28)
        val nonce = combined.copyOfRange(0, 12)
        val body = combined.copyOfRange(12, combined.size)
        val cipher = ChaCha20Poly1305()
        cipher.init(false, AEADParameters(KeyParameter(key), 128, nonce, aad))
        val out = ByteArray(cipher.getOutputSize(body.size))
        var count = cipher.processBytes(body, 0, body.size, out, 0)
        count += cipher.doFinal(out, count)
        return out.copyOf(count)
    }

    fun authenticatedHeader(messageID: String, sequence: ULong, context: String = "chat") =
        "VeilLink/AAD/v4|$context|$messageID|$sequence".toByteArray()

    fun hmacSha256(key: ByteArray, data: ByteArray): ByteArray {
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(SecretKeySpec(key, "HmacSHA256"))
        return mac.doFinal(data)
    }
}
