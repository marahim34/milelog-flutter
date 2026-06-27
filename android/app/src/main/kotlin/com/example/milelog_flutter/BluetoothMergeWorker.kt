package com.example.milelog_flutter

import android.content.Context
import androidx.work.Worker
import androidx.work.WorkerParameters

/**
 * Fires 3 minutes after a Bluetooth disconnect that [BluetoothAclReceiver]
 * couldn't resolve in-process (app was killed). If nothing cancelled it in
 * the meantime (i.e. no reconnect happened), the stop is real — commit it.
 *
 * Scheduled as unique work keyed by mac (see
 * `BluetoothAutoTrackPrefs.scheduleMergeCheck`), so a flurry of disconnects
 * for the same vehicle can't stack multiple timers, and a reconnect within
 * the window cancels this outright rather than letting it fire moot.
 */
class BluetoothMergeWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result {
        val mac = inputData.getString("mac") ?: return Result.failure()
        val vehicleId = inputData.getInt("vehicleId", -1)
        if (vehicleId < 0) return Result.failure()
        BluetoothAutoTrackPrefs.commitStop(applicationContext, mac, vehicleId)
        return Result.success()
    }
}
