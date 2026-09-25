package studio.zeo.veillink.android.link

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import java.io.DataInputStream
import java.io.DataOutputStream
import java.net.ServerSocket
import java.net.Socket
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors

class AndroidLanTurboTransport(context: Context) {
    companion object { private const val SERVICE_TYPE = "_veillink._tcp."; private const val MAX_FRAME = 96 * 1024 }
    var onFrame: ((String, ByteArray) -> Unit)? = null
    private val nsd = context.getSystemService(NsdManager::class.java)
    private val pool = Executors.newCachedThreadPool()
    private var server: ServerSocket? = null
    private var serviceName = "VL-${UUID.randomUUID().toString().take(8)}"
    private val sockets = ConcurrentHashMap<String, Socket>()

    private val registration = object : NsdManager.RegistrationListener {
        override fun onServiceRegistered(info: NsdServiceInfo) { serviceName = info.serviceName }
        override fun onRegistrationFailed(info: NsdServiceInfo, errorCode: Int) {}
        override fun onServiceUnregistered(info: NsdServiceInfo) {}
        override fun onUnregistrationFailed(info: NsdServiceInfo, errorCode: Int) {}
    }
    private val discovery = object : NsdManager.DiscoveryListener {
        override fun onDiscoveryStarted(type: String) {}
        override fun onServiceFound(info: NsdServiceInfo) {
            if (info.serviceType != SERVICE_TYPE || info.serviceName == serviceName) return
            @Suppress("DEPRECATION")
            nsd.resolveService(info, object : NsdManager.ResolveListener {
                override fun onResolveFailed(serviceInfo: NsdServiceInfo, errorCode: Int) {}
                override fun onServiceResolved(serviceInfo: NsdServiceInfo) { connect(serviceInfo.serviceName, serviceInfo.host.hostAddress ?: return, serviceInfo.port) }
            })
        }
        override fun onServiceLost(info: NsdServiceInfo) { sockets.remove(info.serviceName)?.close() }
        override fun onDiscoveryStopped(type: String) {}
        override fun onStartDiscoveryFailed(type: String, errorCode: Int) { runCatching { nsd.stopServiceDiscovery(this) } }
        override fun onStopDiscoveryFailed(type: String, errorCode: Int) { runCatching { nsd.stopServiceDiscovery(this) } }
    }

    fun start() {
        if (server != null) return
        server = ServerSocket(0)
        nsd.registerService(NsdServiceInfo().apply { serviceName = this@AndroidLanTurboTransport.serviceName; serviceType = SERVICE_TYPE; port = server!!.localPort }, NsdManager.PROTOCOL_DNS_SD, registration)
        nsd.discoverServices(SERVICE_TYPE, NsdManager.PROTOCOL_DNS_SD, discovery)
        pool.execute { while (server?.isClosed == false) runCatching { server?.accept()?.let { readLoop("incoming-${it.inetAddress.hostAddress}", it) } } }
    }

    fun stop() {
        runCatching { nsd.stopServiceDiscovery(discovery) }; runCatching { nsd.unregisterService(registration) }
        sockets.values.forEach { runCatching { it.close() } }; sockets.clear(); runCatching { server?.close() }; server = null
    }

    fun send(peer: String, frame: ByteArray): Boolean {
        if (frame.size > MAX_FRAME) return false
        val socket = sockets[peer] ?: return false
        return runCatching { synchronized(socket) { DataOutputStream(socket.getOutputStream()).apply { writeInt(frame.size); write(frame); flush() } }; true }.getOrDefault(false)
    }

    private fun connect(peer: String, host: String, port: Int) {
        if (sockets.containsKey(peer)) return
        pool.execute { runCatching { Socket(host, port).also { sockets[peer] = it; readLoop(peer, it) } } }
    }

    private fun readLoop(peer: String, socket: Socket) {
        try {
            val input = DataInputStream(socket.getInputStream())
            while (!socket.isClosed) {
                val length = input.readInt(); if (length !in 1..MAX_FRAME) break
                val frame = ByteArray(length); input.readFully(frame); onFrame?.invoke(peer, frame)
            }
        } catch (_: Exception) { } finally { sockets.remove(peer, socket); runCatching { socket.close() } }
    }
}
