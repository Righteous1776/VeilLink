package studio.zeo.veillink.android

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import studio.zeo.veillink.android.link.VeilLinkLinkService

class MainActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestRuntimePermissions()
        setContentView(buildContent())
    }

    private fun buildContent(): ScrollView {
        val root = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(42, 48, 42, 48); setBackgroundColor(Color.rgb(9,10,13)) }
        fun label(text: String, size: Float, color: Int = Color.WHITE) = TextView(this).apply { this.text = text; textSize = size; setTextColor(color); setPadding(0,10,0,10) }
        root.addView(label("VeilLink · Android", 27f, Color.rgb(245, 211, 132)))
        root.addView(label("双端兼容基础版 · Wire Protocol v4", 14f, Color.LTGRAY))
        root.addView(label("当前接入：BLE 广播/扫描 · LAN Turbo NSD/TCP · 国内/国际 Relay 客户端 · Remote QR codec · connectedDevice 前台服务", 15f, Color.WHITE))
        root.addView(label("安全核心：X25519 · Ed25519 · HKDF-SHA256 · ChaCha20-Poly1305 · iOS 兼容 Wire framing", 14f, Color.LTGRAY))
        val start = Button(this).apply { text = "启动附近通信服务"; setOnClickListener {
            val i = Intent(this@MainActivity, VeilLinkLinkService::class.java)
            if (Build.VERSION.SDK_INT >= 26) startForegroundService(i) else startService(i)
        } }
        val stop = Button(this).apply { text = "停止附近通信服务"; setOnClickListener { stopService(Intent(this@MainActivity, VeilLinkLinkService::class.java)) } }
        root.addView(start); root.addView(stop)
        root.addView(label("说明：此 Android V1 是正式平台底座，不冒充完整 UI 功能对齐。聊天数据库、完整 SessionCoordinator、群聊频道与兵棋界面会继续在同一协议核心上迭代。", 13f, Color.GRAY))
        return ScrollView(this).apply { addView(root); isFillViewport = true }
    }

    private fun requestRuntimePermissions() {
        val permissions = mutableListOf<String>()
        if (Build.VERSION.SDK_INT >= 31) permissions += listOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT, Manifest.permission.BLUETOOTH_ADVERTISE)
        if (Build.VERSION.SDK_INT >= 33) permissions += Manifest.permission.POST_NOTIFICATIONS
        if (permissions.isNotEmpty() && permissions.any { checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED }) requestPermissions(permissions.toTypedArray(), 1817)
    }
}
