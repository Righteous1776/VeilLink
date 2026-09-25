package studio.zeo.veillink.protocol

import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.UUID

object VeilProtocol {
    const val VERSION = 4
    const val MAXIMUM_ENVELOPE_BYTES = 96 * 1024
    const val ENVELOPE_HEADER_SIZE = 8
    const val ENCRYPTED_PAYLOAD_HEADER_SIZE = 25
    const val ATTACHMENT_CHUNK_HEADER_SIZE = 5
    const val ATTACHMENT_CHECKPOINT_SIZE = 5
    private val MAGIC = byteArrayOf(0x56, 0x4c)

    enum class Kind(val raw: Int) {
        HELLO(1), ENCRYPTED_MESSAGE(2), ACKNOWLEDGEMENT(3), ATTACHMENT_CHUNK(4),
        ATTACHMENT_CHECKPOINT(5), PTT_CONTROL(6), PTT_AUDIO(7), MESH_OVERLAY(8), RELAY_PROVISION(9);
        companion object { fun from(raw: Int) = entries.firstOrNull { it.raw == raw } }
    }

    data class Envelope(val version: Int, val kind: Kind, val payload: ByteArray)
    data class EncryptedPayload(val combined: ByteArray, val messageID: String, val sequence: ULong)
    data class AttachmentChunk(val index: Int, val total: Int, val bytes: ByteArray)
    data class AttachmentCheckpoint(val nextIndex: Int, val total: Int)

    fun encodeEnvelope(version: Int, kind: Kind, payload: ByteArray): ByteArray {
        require(version in 0..255)
        require(payload.size <= MAXIMUM_ENVELOPE_BYTES - ENVELOPE_HEADER_SIZE)
        return ByteBuffer.allocate(ENVELOPE_HEADER_SIZE + payload.size).order(ByteOrder.BIG_ENDIAN)
            .put(MAGIC).put(version.toByte()).put(kind.raw.toByte()).putInt(payload.size).put(payload).array()
    }

    fun decodeEnvelope(data: ByteArray): Envelope {
        require(data.size in ENVELOPE_HEADER_SIZE..MAXIMUM_ENVELOPE_BYTES)
        require(data[0] == MAGIC[0] && data[1] == MAGIC[1])
        val length = ByteBuffer.wrap(data, 4, 4).order(ByteOrder.BIG_ENDIAN).int
        require(length == data.size - ENVELOPE_HEADER_SIZE)
        val kind = Kind.from(data[3].toInt() and 0xff) ?: error("unknown kind")
        return Envelope(data[2].toInt() and 0xff, kind, data.copyOfRange(ENVELOPE_HEADER_SIZE, data.size))
    }

    fun encodeEncryptedPayload(value: EncryptedPayload): ByteArray {
        require(value.sequence > 0u)
        require(value.combined.size >= 28)
        val uuid = UUID.fromString(value.messageID)
        val out = ByteBuffer.allocate(ENCRYPTED_PAYLOAD_HEADER_SIZE + value.combined.size).order(ByteOrder.BIG_ENDIAN)
        out.put(1).putLong(uuid.mostSignificantBits).putLong(uuid.leastSignificantBits).putLong(value.sequence.toLong()).put(value.combined)
        return out.array()
    }

    fun decodeEncryptedPayload(data: ByteArray): EncryptedPayload {
        require(data.size >= ENCRYPTED_PAYLOAD_HEADER_SIZE + 28 && data[0].toInt() == 1)
        val b = ByteBuffer.wrap(data).order(ByteOrder.BIG_ENDIAN)
        b.get()
        val uuid = UUID(b.long, b.long)
        val sequence = b.long.toULong()
        require(sequence > 0u)
        val combined = ByteArray(b.remaining()); b.get(combined)
        return EncryptedPayload(combined, uuid.toString().uppercase(), sequence)
    }

    fun encodeAttachmentChunk(value: AttachmentChunk): ByteArray {
        require(value.total in 1..0xffff && value.index in 0 until value.total && value.bytes.isNotEmpty())
        return ByteBuffer.allocate(ATTACHMENT_CHUNK_HEADER_SIZE + value.bytes.size).order(ByteOrder.BIG_ENDIAN)
            .put(1).putShort(value.index.toShort()).putShort(value.total.toShort()).put(value.bytes).array()
    }

    fun decodeAttachmentChunk(data: ByteArray): AttachmentChunk {
        require(data.size > ATTACHMENT_CHUNK_HEADER_SIZE && data[0].toInt() == 1)
        val b = ByteBuffer.wrap(data).order(ByteOrder.BIG_ENDIAN); b.get()
        val index = b.short.toInt() and 0xffff; val total = b.short.toInt() and 0xffff
        val bytes = ByteArray(b.remaining()); b.get(bytes)
        require(total > 0 && index < total && bytes.isNotEmpty())
        return AttachmentChunk(index, total, bytes)
    }

    fun encodeAttachmentCheckpoint(value: AttachmentCheckpoint): ByteArray {
        require(value.total in 1..0xffff && value.nextIndex in 0..value.total)
        return ByteBuffer.allocate(ATTACHMENT_CHECKPOINT_SIZE).order(ByteOrder.BIG_ENDIAN)
            .put(1).putShort(value.nextIndex.toShort()).putShort(value.total.toShort()).array()
    }

    fun decodeAttachmentCheckpoint(data: ByteArray): AttachmentCheckpoint {
        require(data.size == ATTACHMENT_CHECKPOINT_SIZE && data[0].toInt() == 1)
        val b = ByteBuffer.wrap(data).order(ByteOrder.BIG_ENDIAN); b.get()
        val next = b.short.toInt() and 0xffff; val total = b.short.toInt() and 0xffff
        require(total > 0 && next <= total)
        return AttachmentCheckpoint(next, total)
    }
}
