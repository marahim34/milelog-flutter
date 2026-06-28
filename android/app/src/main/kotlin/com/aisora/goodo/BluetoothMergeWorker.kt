package com.aisora.goodo

import android.content.Context
import androidx.work.Worker
import androidx.work.WorkerParameters

/**
 * Fires 3 minutes after a Bluetooth disconnect (killed-app path only).
 *
 * If the device reconnected within the 3-minute merge window,
 * [BluetoothAutoStartReceiver.handleConnect] already cancelled this job via
 * WorkManager.cancelUniqueWork — so this worker only runs when no reconnect arrived.
 *
 * At this point [TrackingService] is still running and paused. It wrote the
 * pause waypoint to `trip_waypoints` immediately when it received
 * [TrackingService.ACTION_PAUSE], so there is nothing further to commit here.
 * The trip stays active and paused until the next BT connect or the user
 * manually stops it from inside the app.
 */
class BluetoothMergeWorker(context: Context, params: WorkerParameters) : Worker(context, params) {

    override fun doWork(): Result {
        // Engine alive → Dart's BluetoothAutoTrackingController in-memory timer
        // already handled the merge window; nothing to duplicate here.
        if (AppProcessState.isEngineAlive) return Result.success()

        // 3-minute merge window elapsed with no reconnect.
        // Pause waypoint was written by TrackingService on ACTION_PAUSE.
        // Trip remains active-and-paused — no further action required.
        return Result.success()
    }
}
