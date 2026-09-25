package studio.zeo.veillink.protocol

object Base32 {
    private const val ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"

    fun encode(data: ByteArray): String {
        val out = StringBuilder()
        var buffer = 0
        var bitsLeft = 0
        for (raw in data) {
            buffer = (buffer shl 8) or (raw.toInt() and 0xff)
            bitsLeft += 8
            while (bitsLeft >= 5) {
                bitsLeft -= 5
                out.append(ALPHABET[(buffer shr bitsLeft) and 31])
            }
            buffer = if (bitsLeft == 0) 0 else buffer and ((1 shl bitsLeft) - 1)
        }
        if (bitsLeft > 0) out.append(ALPHABET[(buffer shl (5 - bitsLeft)) and 31])
        return out.toString()
    }
}
