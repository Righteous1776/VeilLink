package studio.zeo.veillink.protocol

import org.junit.Assert.*
import org.junit.Test

class ProtocolCoreTest {
    @Test fun wireVectorMatchesIOSRule() {
        val expected = "564c0402000000520112345678123456789abcdef0123456780000000000000001000102030405060708090a0bc40806ec77694a6bf5396fd0eafd2c85ac15204225bd94fd52878e9f0abfbee5a29062a9f01339e490b62734b9"
        val bytes = expected.hex()
        val envelope = VeilProtocol.decodeEnvelope(bytes)
        assertEquals(4, envelope.version)
        assertEquals(VeilProtocol.Kind.ENCRYPTED_MESSAGE, envelope.kind)
        assertArrayEquals(bytes, VeilProtocol.encodeEnvelope(envelope.version, envelope.kind, envelope.payload))
        val encrypted = VeilProtocol.decodeEncryptedPayload(envelope.payload)
        assertEquals("12345678-1234-5678-9ABC-DEF012345678", encrypted.messageID)
        assertEquals(1uL, encrypted.sequence)
        assertArrayEquals(envelope.payload, VeilProtocol.encodeEncryptedPayload(encrypted))
    }

    @Test fun replayWindowRejectsDuplicateAndOld() {
        val r = ReplayWindow()
        assertTrue(r.accept(1u)); assertFalse(r.accept(1u)); assertTrue(r.accept(3u)); assertTrue(r.accept(2u))
        assertFalse(r.accept(2u)); assertTrue(r.accept(70u)); assertFalse(r.accept(1u))
    }

    @Test fun remoteQrVectorMatchesIOSPayloadContract() {
        val text = "veillink://pair?v=1&d=eyJ2ZXJzaW9uIjoxLCJvZmZlcklEIjoiQTFCMkMzRDQtRTVGNi00N0E4LTkxMjMtNDU2Nzg5QUJDREVGIiwib2ZmZXJTZWNyZXQiOiJnWUtEaElXR2g0aUppb3VNalk2UGtKR1NrNVNWbHBlWW1acWJuSjJlbjZBPSIsImluaXRpYXRvckVwaGVtZXJhbFB1YmxpY0tleSI6IkI2Tjh2QlFnazhpM1Zkd2JFT2hzdENZM1N0RnFxRlB0QzkvQXNyaHRISHc9IiwiY3JlYXRlZEF0IjoxODAwMDAwMDAwMDAwLCJleHBpcmVzQXQiOjE4MDAwMDAwNjAwMDB9"
        val p = RemotePairingPayloadCodec.decode(text, 1_800_000_030_000L)
        assertEquals("A1B2C3D4-E5F6-47A8-9123-456789ABCDEF", p.offerID)
        assertEquals(32, p.offerSecret.size)
        assertTrue(RemotePairingPayloadCodec.encode(p).startsWith(RemotePairingPayloadCodec.PREFIX))
    }

    @Test fun base32MatchesIdentityGroupingInput() {
        val digestPrefix = "ba8112fa4ba3d6f934b2ad2aa0696602".hex()
        assertEquals("XKARF6SLUPLPSNFSVUVKA2LGAI", Base32.encode(digestPrefix))
    }
}

private fun String.hex(): ByteArray = chunked(2).map { it.toInt(16).toByte() }.toByteArray()
