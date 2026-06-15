package com.woocommercemanager.wcp_premium

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

/**
 * FCM receiver — Firebase Android SDK only (NO pub.dev firebase_messaging
 * plugin), resolved from Google Maven so the app stays Iran-safe. Privacy
 * mandate: the push is DATA-ONLY and content-free
 *   data = { type:"chat_changed", tenant:<public_key>, version:<int> }
 * so NO message bodies / names / ids / counts ever cross Google. On receipt we
 * raise a generic LOCAL notification; the real text is fetched from the
 * merchant WP only after the user opens the app -> chat.
 */
class WcpFcmService : FirebaseMessagingService() {

    /**
     * A fresh registration token. Cache it (SharedPreferences key "fcm_token")
     * so MainActivity's "fcmToken" channel method can return it synchronously,
     * and best-effort push it to Dart if the engine is alive so the app can
     * re-register the device immediately.
     */
    override fun onNewToken(token: String) {
        super.onNewToken(token)
        try {
            getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit()
                .putString(KEY_FCM_TOKEN, token)
                .apply()
        } catch (e: Exception) {
            // ignore — token still flows to Dart via the fcmToken fallback.
        }
        // Best-effort: forward to Dart on the main thread if the engine + channel
        // are alive (app in foreground/background with an attached engine).
        try {
            Handler(Looper.getMainLooper()).post {
                try {
                    MainActivity.nativeChannel?.invokeMethod("onFcmToken", token)
                } catch (e: Exception) {
                    // engine detached — Dart re-reads the cached token on next start.
                }
            }
        } catch (e: Exception) {
            // ignore
        }
    }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)
        val data = remoteMessage.data
        if (data["type"] != "chat_changed") return
        try {
            // Ensure the channel exists even if MainActivity never ran this boot
            // (push can arrive while the app is dead).
            MainActivity.ensureChatChannel(this)

            val launch = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            }
            val flags = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val contentIntent = PendingIntent.getActivity(this, 0, launch, flags)

            val builder = NotificationCompat.Builder(this, MainActivity.CHAT_CHANNEL_ID)
                .setSmallIcon(applicationInfo.icon)
                .setContentTitle("پیام جدید گفتگو")
                .setContentText("برای دیدن پیام، باز کنید")
                .setAutoCancel(true)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setContentIntent(contentIntent)

            // Reuse the user's chosen chat sound (BATCH 2) when one is saved.
            val soundUri = MainActivity.chatSoundUri(this)
            if (soundUri != null) builder.setSound(soundUri)

            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.notify(CHAT_NOTIF_ID, builder.build())
        } catch (e: Exception) {
            // never crash the push pipeline
        }
    }

    companion object {
        const val PREFS = "wcp_native"
        const val KEY_FCM_TOKEN = "fcm_token"
        private const val CHAT_NOTIF_ID = 7311
    }
}
