package studio.zeo.veillink.android.relay

import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors
import kotlin.math.roundToInt

enum class RelayRegion { DOMESTIC, INTERNATIONAL }
data class RelayHealth(val region: RelayRegion, val healthy: Boolean, val rttMs: Int?, val checkedAt: Long)

class DualRelayClient {
    private val pool = Executors.newFixedThreadPool(2)
    @Volatile var domesticEndpoint: String = ""
    @Volatile var internationalEndpoint: String = ""
    @Volatile var health: Map<RelayRegion, RelayHealth> = emptyMap()
        private set

    fun probe(callback: (Map<RelayRegion, RelayHealth>) -> Unit = {}) {
        val targets = listOf(RelayRegion.DOMESTIC to domesticEndpoint, RelayRegion.INTERNATIONAL to internationalEndpoint).filter { it.second.startsWith("https://") }
        if (targets.isEmpty()) { health = emptyMap(); callback(health); return }
        val results = java.util.Collections.synchronizedMap(mutableMapOf<RelayRegion, RelayHealth>())
        targets.forEach { (region, endpoint) -> pool.execute {
            val started = System.nanoTime(); val ok = runCatching { request(endpoint.trimEnd('/') + "/health", "GET", null).first in 200..299 }.getOrDefault(false)
            results[region] = RelayHealth(region, ok, ((System.nanoTime() - started) / 1_000_000.0).roundToInt(), System.currentTimeMillis())
            if (results.size == targets.size) { health = results.toMap(); callback(health) }
        } }
    }

    fun push(endpoint: String, mailbox: String, writeToken: String, packetID: String, bodyBase64: String, expiresAtMs: Long): Boolean {
        require(endpoint.startsWith("https://"))
        val json = JSONObject().put("mailbox", mailbox).put("writeToken", writeToken).put("packetID", packetID).put("body", bodyBase64).put("expiresAt", expiresAtMs)
        return request(endpoint.trimEnd('/') + "/push", "POST", json.toString()).first in 200..299
    }

    private fun request(url: String, method: String, body: String?): Pair<Int, String> {
        val c = URL(url).openConnection() as HttpURLConnection
        c.requestMethod = method; c.connectTimeout = 4_000; c.readTimeout = 6_000
        c.setRequestProperty("Content-Type", "application/json")
        if (body != null) { c.doOutput = true; c.outputStream.use { it.write(body.toByteArray()) } }
        val code = c.responseCode
        val stream = if (code in 200..299) c.inputStream else c.errorStream
        val text = stream?.bufferedReader()?.use { it.readText() }.orEmpty(); c.disconnect(); return code to text
    }
}
