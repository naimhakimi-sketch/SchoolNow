package com.schoolnow.firebase_hosting_apk_updater

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File

class FirebaseHostingApkUpdaterPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
  private lateinit var channel: MethodChannel
  private var applicationContext: Context? = null
  private var activityBinding: ActivityPluginBinding? = null

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    applicationContext = flutterPluginBinding.applicationContext
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "firebase_hosting_apk_updater")
    channel.setMethodCallHandler(this)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    applicationContext = null
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "canInstallUnknownApps" -> {
        val ctx = applicationContext
        if (ctx == null) {
          result.success(false)
          return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
          result.success(true)
          return
        }
        result.success(ctx.packageManager.canRequestPackageInstalls())
      }

      "openInstallUnknownAppsSettings" -> {
        val ctx = applicationContext
        if (ctx == null) {
          result.success(null)
          return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
          val intent = Intent(
            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
            Uri.parse("package:" + ctx.packageName)
          )
          intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
          ctx.startActivity(intent)
        }
        result.success(null)
      }

      "installApk" -> {
        val ctx = applicationContext
        if (ctx == null) {
          result.error("no_context", "No Android context available", null)
          return
        }

        val args = call.arguments as? Map<*, *>
        val filePath = args?.get("filePath") as? String
        if (filePath.isNullOrBlank()) {
          result.error("bad_args", "Missing filePath", null)
          return
        }

        try {
          val file = File(filePath)
          val authority = ctx.packageName + ".firebase_hosting_apk_updater.fileprovider"
          val contentUri = FileProvider.getUriForFile(ctx, authority, file)

          val intent = Intent(Intent.ACTION_VIEW)
          intent.setDataAndType(contentUri, "application/vnd.android.package-archive")
          intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
          intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
          ctx.startActivity(intent)

          result.success(null)
        } catch (e: Exception) {
          result.error("install_failed", e.message, null)
        }
      }

      else -> result.notImplemented()
    }
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activityBinding = binding
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activityBinding = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activityBinding = binding
  }

  override fun onDetachedFromActivity() {
    activityBinding = null
  }
}
