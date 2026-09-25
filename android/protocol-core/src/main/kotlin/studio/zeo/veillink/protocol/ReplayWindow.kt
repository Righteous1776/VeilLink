package studio.zeo.veillink.protocol

class ReplayWindow {
    var highestSequence: ULong = 0u
        private set
    private var seenBitmap: ULong = 0u

    fun isPotentiallyFresh(sequence: ULong): Boolean {
        if (sequence == 0uL) return false
        if (highestSequence == 0uL) return true
        if (sequence > highestSequence) return true
        val distance = highestSequence - sequence
        if (distance >= 64u) return false
        return (seenBitmap and (1uL shl distance.toInt())) == 0uL
    }

    fun accept(sequence: ULong): Boolean {
        if (!isPotentiallyFresh(sequence)) return false
        if (highestSequence == 0uL) {
            highestSequence = sequence
            seenBitmap = 1u
            return true
        }
        if (sequence > highestSequence) {
            val shift = sequence - highestSequence
            seenBitmap = if (shift >= 64u) 1u else (seenBitmap shl shift.toInt()) or 1u
            highestSequence = sequence
            return true
        }
        val distance = highestSequence - sequence
        seenBitmap = seenBitmap or (1uL shl distance.toInt())
        return true
    }
}
