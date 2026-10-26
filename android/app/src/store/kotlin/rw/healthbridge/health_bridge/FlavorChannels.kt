package rw.healthbridge.health_bridge

import io.flutter.embedding.engine.FlutterEngine

// The store build has no native channels: Play forbids SEND_SMS, so urgent SMS go through the
// composer (url_launcher). The managed build's version lives in src/managed/kotlin/SmsChannel.kt.
object FlavorChannels {
    fun register(engine: FlutterEngine) {}
}
