class FirebaseHostingApkRelease {
  FirebaseHostingApkRelease({
    required this.versionCode,
    required this.versionName,
    required this.url,
    this.sha256,
  });

  final int versionCode;
  final String versionName;
  final String url;
  final String? sha256;

  factory FirebaseHostingApkRelease.fromJson(Map<String, dynamic> json) {
    final versionCode = json['versionCode'];
    final versionName = json['versionName'];
    final url = json['url'];

    if (versionCode is! num || versionName is! String || url is! String) {
      throw const FormatException('Invalid release JSON: expected versionCode/versionName/url');
    }

    return FirebaseHostingApkRelease(
      versionCode: versionCode.toInt(),
      versionName: versionName,
      url: url,
      sha256: json['sha256'] as String?,
    );
  }
}

class FirebaseHostingApkUpdateCheckResult {
  FirebaseHostingApkUpdateCheckResult({
    required this.currentVersionCode,
    required this.hasUpdate,
    this.release,
  });

  final int currentVersionCode;
  final bool hasUpdate;
  final FirebaseHostingApkRelease? release;
}
