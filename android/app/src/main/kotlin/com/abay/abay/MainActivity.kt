package com.abay.abay

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "abay/call"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    CallService.start(applicationContext)
                    result.success(true)
                }
                "stopService" -> {
                    CallService.stop(applicationContext)
                    result.success(true)
                }
                "registered" -> {
                    val title = call.argument<String>("title") ?: "Abay"
                    val text = call.argument<String>("text") ?: "Registered"
                    CallService.notifyRegistered(applicationContext, title, text)
                    result.success(true)
                }
                "incoming" -> {
                    val title = call.argument<String>("title") ?: "Incoming call"
                    val text = call.argument<String>("text") ?: ""
                    CallService.notifyIncoming(applicationContext, title, text)
                    result.success(true)
                }
                "ongoing" -> {
                    val title = call.argument<String>("title") ?: "On call"
                    val text = call.argument<String>("text") ?: ""
                    CallService.notifyOngoing(applicationContext, title, text)
                    result.success(true)
                }
                "clearCall" -> {
                    CallService.clearCallNotifications(applicationContext)
                    result.success(true)
                }
                "setAnswerHandler" -> {
                    CallServiceBridge.onAnswer = {
                        runOnUiThread {
                            MethodChannel(
                                flutterEngine.dartExecutor.binaryMessenger,
                                channelName
                            ).invokeMethod("answer", null)
                        }
                    }
                    result.success(true)
                }
                "setRejectHandler" -> {
                    CallServiceBridge.onReject = {
                        runOnUiThread {
                            MethodChannel(
                                flutterEngine.dartExecutor.binaryMessenger,
                                channelName
                            ).invokeMethod("reject", null)
                        }
                    }
                    result.success(true)
                }
                "bringToForeground" -> {
                    val i = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                        addFlags(
                            Intent.FLAG_ACTIVITY_NEW_TASK or
                                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                                Intent.FLAG_ACTIVITY_SINGLE_TOP
                        )
                    }
                    if (i != null) startActivity(i)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
