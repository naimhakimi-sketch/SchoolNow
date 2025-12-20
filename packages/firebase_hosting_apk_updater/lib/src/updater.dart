import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'models.dart';

class FirebaseHostingApkUpdater {
  FirebaseHostingApkUpdater({
    required this.manifestUrl,
    required this.appKey,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String manifestUrl;
  final String appKey;
  final http.Client _http;

  static const MethodChannel _channel = MethodChannel('firebase_hosting_apk_updater');

  Future<FirebaseHostingApkUpdateCheckResult> checkForUpdate() async {
    final info = await PackageInfo.fromPlatform();
    final currentVersionCode = int.tryParse(info.buildNumber) ?? 0;

    final response = await _http.get(Uri.parse(manifestUrl));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('Failed to fetch manifest: HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Manifest must be a JSON object');
    }

    final appNode = decoded[appKey];
    if (appNode == null) {
      return FirebaseHostingApkUpdateCheckResult(
        currentVersionCode: currentVersionCode,
        hasUpdate: false,
      );
    }

    if (appNode is! Map<String, dynamic>) {
      throw const FormatException('Manifest entry must be an object');
    }

    final release = FirebaseHostingApkRelease.fromJson(appNode);
    final hasUpdate = release.versionCode > currentVersionCode;

    return FirebaseHostingApkUpdateCheckResult(
      currentVersionCode: currentVersionCode,
      hasUpdate: hasUpdate,
      release: hasUpdate ? release : null,
    );
  }

  Future<bool> canInstallUnknownApps() async {
    if (!Platform.isAndroid) return false;
    final result = await _channel.invokeMethod<bool>('canInstallUnknownApps');
    return result ?? false;
  }

  Future<void> openInstallUnknownAppsSettings() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod('openInstallUnknownAppsSettings');
  }

  /// Downloads the APK and launches the Android installer UI.
  ///
  /// - If [expectedSha256] is provided, validates the file hash.
  Future<void> downloadAndInstall({
    required String apkUrl,
    String? expectedSha256,
    ValueChanged<double>? onProgress,
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('APK install is only supported on Android');
    }

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/update.apk');

    final request = http.Request('GET', Uri.parse(apkUrl));
    final streamed = await _http.send(request);

    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw HttpException('Failed to download APK: HTTP ${streamed.statusCode}');
    }

    final sink = file.openWrite();
    final total = streamed.contentLength ?? 0;
    var received = 0;

    try {
      await for (final chunk in streamed.stream) {
        received += chunk.length;
        sink.add(chunk);
        if (onProgress != null && total > 0) {
          onProgress(received / total);
        }
      }
    } finally {
      await sink.close();
    }

    if (expectedSha256 != null && expectedSha256.trim().isNotEmpty) {
      final bytes = await file.readAsBytes();
      final digest = sha256.convert(bytes).toString();
      if (digest.toLowerCase() != expectedSha256.toLowerCase()) {
        throw const FormatException('APK sha256 mismatch');
      }
    }

    await _channel.invokeMethod('installApk', {'filePath': file.path});
  }

  Future<void> downloadAndInstallRelease({
    required FirebaseHostingApkRelease release,
    ValueChanged<double>? onProgress,
  }) {
    return downloadAndInstall(
      apkUrl: release.url,
      expectedSha256: release.sha256,
      onProgress: onProgress,
    );
  }
}
