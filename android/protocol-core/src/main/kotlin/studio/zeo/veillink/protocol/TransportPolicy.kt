package studio.zeo.veillink.protocol

enum class TransportPath { LAN, BLE, INTERNET_DOMESTIC, INTERNET_INTERNATIONAL }

data class LinkCandidate(
    val path: TransportPath,
    val authenticated: Boolean,
    val ready: Boolean,
    val rttMs: Int? = null,
    val bulkCapable: Boolean = false
)

object TransportPolicy {
    fun preferred(candidates: List<LinkCandidate>, bulk: Boolean): LinkCandidate? = candidates
        .asSequence()
        .filter { it.authenticated && it.ready && (!bulk || it.bulkCapable || it.path == TransportPath.BLE) }
        .sortedWith(compareBy<LinkCandidate> {
            when (it.path) {
                TransportPath.LAN -> 0
                TransportPath.BLE -> 1
                TransportPath.INTERNET_DOMESTIC, TransportPath.INTERNET_INTERNATIONAL -> 2
            }
        }.thenBy { it.rttMs ?: Int.MAX_VALUE })
        .firstOrNull()
}
