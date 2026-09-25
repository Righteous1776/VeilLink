package studio.zeo.veillink.android

import org.junit.Assert.*
import org.junit.Test
import studio.zeo.veillink.android.crypto.VeilCrypto
import studio.zeo.veillink.protocol.RemotePairingPayloadCodec
import studio.zeo.veillink.android.pairing.RemotePairingCrypto
import studio.zeo.veillink.android.pairing.RemotePairDirection
import studio.zeo.veillink.android.pairing.RemotePairRegion

class CryptoCompatibilityTest {
    @Test fun deterministicSessionVectorMatchesIOSRules() {
        val privateA = H("0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20")
        val publicB = H("5869aff450549732cbaaed5e5df9b30a6da31cb0e5742bad5ad4a1a768f1a67b")
        val transcript = "VeilLink/Transcript/v4|android-ios-vector".toByteArray()
        val root = VeilCrypto.deriveSessionRoot(privateA, publicB, transcript)
        assertEquals("7be51bd45e1873153c62a16b545524efc8391408b76c7a2158095667c418d755", root.hex())
        val ida = "XKAR-F6SL-UPLP-SNFS-VUVK-A2LG-AI"; val idb = "WTFU-XE6E-AJ6O-HVCV-6KNB-OWBO-YI"
        val send = VeilCrypto.directionalKey(root, ida, idb)
        assertEquals("aa18bcc429be4ee7d0920a2e4a08eab8ae073e23590c3358c2957cc79e46ccdf", send.hex())
    }

    @Test fun identityIdMatchesIOSVector() {
        assertEquals("XKAR-F6SL-UPLP-SNFS-VUVK-A2LG-AI", VeilCrypto.identityID(H("adc14011f82d1c56d956aa4f9d73d8858361a606048525e0d08c638dc75dd8c7")))
    }

    @Test fun chachaCombinedDecryptsIOSCompatibleVector() {
        val key = H("aa18bcc429be4ee7d0920a2e4a08eab8ae073e23590c3358c2957cc79e46ccdf")
        val combined = H("000102030405060708090a0bc40806ec77694a6bf5396fd0eafd2c85ac15204225bd94fd52878e9f0abfbee5a29062a9f01339e490b62734b9")
        val aad = H("5665696c4c696e6b2f4141442f76347c636861747c31323334353637382d313233342d353637382d394142432d4445463031323334353637387c31")
        assertEquals("VeilLink iOS↔Android vector", String(VeilCrypto.chachaOpen(key, combined, aad)))
    }

    @Test fun remoteQrVectorDecodesWithSixtySecondRule() {
        val text = "veillink://pair?v=1&d=eyJ2ZXJzaW9uIjoxLCJvZmZlcklEIjoiQTFCMkMzRDQtRTVGNi00N0E4LTkxMjMtNDU2Nzg5QUJDREVGIiwib2ZmZXJTZWNyZXQiOiJnWUtEaElXR2g0aUppb3VNalk2UGtKR1NrNVNWbHBlWW1acWJuSjJlbjZBPSIsImluaXRpYXRvckVwaGVtZXJhbFB1YmxpY0tleSI6IkI2Tjh2QlFnazhpM1Zkd2JFT2hzdENZM1N0RnFxRlB0QzkvQXNyaHRISHc9IiwiY3JlYXRlZEF0IjoxODAwMDAwMDAwMDAwLCJleHBpcmVzQXQiOjE4MDAwMDAwNjAwMDB9"
        val p = RemotePairingPayloadCodec.decode(text, 1_800_000_030_000L)
        assertEquals("A1B2C3D4-E5F6-47A8-9123-456789ABCDEF", p.offerID)
        assertEquals(32, p.offerSecret.size)
    }
    @Test fun remotePairRoutesSeparateRegionsAndDirections() {
        val text = "veillink://pair?v=1&d=eyJ2ZXJzaW9uIjoxLCJvZmZlcklEIjoiQTFCMkMzRDQtRTVGNi00N0E4LTkxMjMtNDU2Nzg5QUJDREVGIiwib2ZmZXJTZWNyZXQiOiJnWUtEaElXR2g0aUppb3VNalk2UGtKR1NrNVNWbHBlWW1acWJuSjJlbjZBPSIsImluaXRpYXRvckVwaGVtZXJhbFB1YmxpY0tleSI6IkI2Tjh2QlFnazhpM1Zkd2JFT2hzdENZM1N0RnFxRlB0QzkvQXNyaHRISHc9IiwiY3JlYXRlZEF0IjoxODAwMDAwMDAwMDAwLCJleHBpcmVzQXQiOjE4MDAwMDAwNjAwMDB9"
        val q = RemotePairingPayloadCodec.decode(text, 1_800_000_001_000L)
        val cn = RemotePairingCrypto.route(q, RemotePairRegion.DOMESTIC, RemotePairDirection.TO_INITIATOR)
        val global = RemotePairingCrypto.route(q, RemotePairRegion.INTERNATIONAL, RemotePairDirection.TO_INITIATOR)
        val reverse = RemotePairingCrypto.route(q, RemotePairRegion.DOMESTIC, RemotePairDirection.TO_RESPONDER)
        assertNotEquals(cn.mailbox, global.mailbox); assertNotEquals(cn.mailbox, reverse.mailbox)
        assertNotEquals(cn.readToken, cn.writeToken)
    }
}
private fun H(s: String)=s.chunked(2).map { it.toInt(16).toByte() }.toByteArray()
private fun ByteArray.hex()=joinToString("") { "%02x".format(it.toInt() and 255) }
