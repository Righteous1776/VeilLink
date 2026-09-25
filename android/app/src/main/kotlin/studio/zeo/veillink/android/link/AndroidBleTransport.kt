package studio.zeo.veillink.android.link

import android.annotation.SuppressLint
import android.bluetooth.*
import android.bluetooth.le.*
import android.content.Context
import android.os.ParcelUuid
import java.util.UUID

@SuppressLint("MissingPermission")
class AndroidBleTransport(private val context: Context) {
    companion object {
        val SERVICE_UUID: UUID = UUID.fromString("5D0F88D4-21A2-4DC4-A1E8-A2DF8C9AC001")
        val DATA_UUID: UUID = UUID.fromString("5D0F88D4-21A2-4DC4-A1E8-A2DF8C9AC002")
    }

    var onDiscovered: ((BluetoothDevice, Int) -> Unit)? = null
    var onFrame: ((String, ByteArray) -> Unit)? = null

    private val manager = context.getSystemService(BluetoothManager::class.java)
    private val adapter get() = manager?.adapter
    private var gattServer: BluetoothGattServer? = null
    private val serviceParcel = ParcelUuid(SERVICE_UUID)

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) { onDiscovered?.invoke(result.device, result.rssi) }
    }
    private val advertiseCallback = object : AdvertiseCallback() {}
    private val gattCallback = object : BluetoothGattServerCallback() {
        override fun onCharacteristicWriteRequest(device: BluetoothDevice, requestId: Int, characteristic: BluetoothGattCharacteristic,
            preparedWrite: Boolean, responseNeeded: Boolean, offset: Int, value: ByteArray) {
            if (characteristic.uuid == DATA_UUID && offset == 0) onFrame?.invoke(device.address, value)
            if (responseNeeded) gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
        }
    }

    fun start() {
        val a = adapter ?: return
        val filter = ScanFilter.Builder().setServiceUuid(serviceParcel).build()
        val settings = ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_BALANCED).build()
        a.bluetoothLeScanner?.startScan(listOf(filter), settings, scanCallback)
        a.bluetoothLeAdvertiser?.startAdvertising(
            AdvertiseSettings.Builder().setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY).setConnectable(true).build(),
            AdvertiseData.Builder().addServiceUuid(serviceParcel).setIncludeDeviceName(false).build(), advertiseCallback)
        val server = manager?.openGattServer(context, gattCallback)
        gattServer = server
        val service = BluetoothGattService(SERVICE_UUID, BluetoothGattService.SERVICE_TYPE_PRIMARY)
        val dataCharacteristic = BluetoothGattCharacteristic(DATA_UUID,
            BluetoothGattCharacteristic.PROPERTY_WRITE or BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE or BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            BluetoothGattCharacteristic.PERMISSION_WRITE)
        dataCharacteristic.addDescriptor(BluetoothGattDescriptor(
            UUID.fromString("00002902-0000-1000-8000-00805f9b34fb"),
            BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE
        ))
        service.addCharacteristic(dataCharacteristic)
        server?.addService(service)
    }

    fun stop() {
        adapter?.bluetoothLeScanner?.stopScan(scanCallback)
        adapter?.bluetoothLeAdvertiser?.stopAdvertising(advertiseCallback)
        gattServer?.close(); gattServer = null
    }
}
