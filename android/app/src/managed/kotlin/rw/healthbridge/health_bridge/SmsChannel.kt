package rw.healthbridge.health_bridge

import android.Manifest
import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Telephony
import android.telephony.SmsManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

// Managed build only (TRD §3): sends the urgent SMS with SmsManager and collects the "HB OK <code>"
// acks. Deliberately not an SMS plugin: a plugin's manifest would merge SEND_SMS into the store build.
object FlavorChannels {
    fun register(engine: FlutterEngine) {
        engine.plugins.add(SmsChannel())
    }
}

private const val PREFS = "hb_sms"
private const val ACKS = "acks"
private const val REQUEST = 4242
private val ACK = Regex("^HB OK ([0-9a-f]{8})$")
private val PERMISSIONS = arrayOf(Manifest.permission.SEND_SMS, Manifest.permission.RECEIVE_SMS)

class SmsChannel : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler,
    PluginRegistry.RequestPermissionsResultListener {
    companion object {
        var live: MethodChannel? = null // lets the receiver nudge a running app
    }

    private lateinit var context: Context
    private var activity: ActivityPluginBinding? = null
    private var asking: MethodChannel.Result? = null

    override fun onAttachedToEngine(b: FlutterPlugin.FlutterPluginBinding) {
        context = b.applicationContext
        live = MethodChannel(b.binaryMessenger, "rw.healthbridge/sms").also { it.setMethodCallHandler(this) }
    }

    override fun onDetachedFromEngine(b: FlutterPlugin.FlutterPluginBinding) {
        live?.setMethodCallHandler(null)
        live = null
    }

    override fun onAttachedToActivity(b: ActivityPluginBinding) {
        activity = b
        b.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity?.removeRequestPermissionsResultListener(this)
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(b: ActivityPluginBinding) = onAttachedToActivity(b)
    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    private fun granted() = PERMISSIONS.all { context.checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestPermission" -> {
                val a = activity?.activity
                if (granted() || a == null || asking != null) return result.success(granted())
                asking = result
                a.requestPermissions(PERMISSIONS, REQUEST)
            }
            "send" -> if (granted()) send(call.argument("to")!!, call.argument("parts")!!, result)
                else result.error("permission", "SEND_SMS not granted", null)
            "takeAcks" -> {
                val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                result.success(prefs.getStringSet(ACKS, emptySet())!!.toList())
                prefs.edit().remove(ACKS).apply()
            }
            else -> result.notImplemented()
        }
    }

    override fun onRequestPermissionsResult(code: Int, permissions: Array<out String>, results: IntArray): Boolean {
        if (code != REQUEST) return false
        asking?.success(granted())
        asking = null
        return true
    }

    // Replies once the radio has reported on every part, so "sent" means the SMS left the phone.
    private fun send(to: String, parts: List<String>, result: MethodChannel.Result) {
        val action = "${context.packageName}.SMS_SENT.${System.nanoTime()}"
        var left = parts.size
        var error: Int? = null
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(c: Context, i: Intent) {
                if (resultCode != Activity.RESULT_OK) error = resultCode
                if (--left > 0) return
                c.unregisterReceiver(this)
                error?.let { result.error("not_sent", "SmsManager result $it", null) } ?: result.success(null)
            }
        }
        if (Build.VERSION.SDK_INT >= 33) {
            context.registerReceiver(receiver, IntentFilter(action), Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(receiver, IntentFilter(action))
        }
        val sms = if (Build.VERSION.SDK_INT >= 31) context.getSystemService(SmsManager::class.java)
            else @Suppress("DEPRECATION") SmsManager.getDefault()
        parts.forEachIndexed { i, part ->
            val sent = Intent(action).setPackage(context.packageName)
            sms.sendTextMessage(to, null, part, PendingIntent.getBroadcast(context, i, sent, PendingIntent.FLAG_IMMUTABLE), null)
        }
    }
}

/** Keeps "HB OK <code>" acks, even while the app is closed, until Dart takes them with takeAcks. */
class SmsAckReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val codes = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            .mapNotNull { ACK.matchEntire(it.messageBody.orEmpty().trim())?.groupValues?.get(1) }
        if (codes.isEmpty()) return
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.edit().putStringSet(ACKS, prefs.getStringSet(ACKS, emptySet())!! + codes).apply()
        SmsChannel.live?.invokeMethod("ack", null)
    }
}
