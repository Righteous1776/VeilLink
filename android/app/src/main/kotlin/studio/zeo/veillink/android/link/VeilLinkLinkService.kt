package studio.zeo.veillink.android.link

import android.app.*
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

class VeilLinkLinkService : Service() {
    companion object { const val CHANNEL = "veillink_links"; const val NOTIFICATION_ID = 1817 }
    private lateinit var ble: AndroidBleTransport
    private lateinit var lan: AndroidLanTurboTransport

    override fun onCreate() {
        super.onCreate()
        ble = AndroidBleTransport(this); lan = AndroidLanTurboTransport(this)
        if (Build.VERSION.SDK_INT >= 26) getSystemService(NotificationManager::class.java).createNotificationChannel(
            NotificationChannel(CHANNEL, "VeilLink 附近通信", NotificationManager.IMPORTANCE_LOW).apply { description = "保持已授权的 BLE / 局域网连接" })
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = Notification.Builder(this, CHANNEL).setContentTitle("VeilLink 附近通信运行中")
            .setContentText("BLE / LAN / Mesh 链路保持可用").setSmallIcon(android.R.drawable.stat_sys_data_bluetooth).setOngoing(true).build()
        if (Build.VERSION.SDK_INT >= 29) startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE)
        else startForeground(NOTIFICATION_ID, notification)
        ble.start(); lan.start(); return START_STICKY
    }

    override fun onDestroy() { ble.stop(); lan.stop(); super.onDestroy() }
    override fun onBind(intent: Intent?): IBinder? = null
}
