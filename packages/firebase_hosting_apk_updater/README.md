# firebase_hosting_apk_updater (local)

Local plugin used by both `school_now` and `school_now_driver`.

It checks a Firebase Hosting `manifest.json`, downloads an APK, and opens Android's package installer.

## Firebase Hosting manifest

Host a JSON file like:

```json
{
  "school_now": {
    "versionCode": 12,
    "versionName": "1.2.0",
    "url": "https://YOUR_PROJECT.web.app/updates/school_now.apk",
    "sha256": "...optional..."
  },
  "school_now_driver": {
    "versionCode": 7,
    "versionName": "1.0.6",
    "url": "https://YOUR_PROJECT.web.app/updates/school_now_driver.apk"
  }
}
```

## Usage (Flutter)

```dart
final updater = FirebaseHostingApkUpdater(
  manifestUrl: 'https://YOUR_PROJECT.web.app/updates/manifest.json',
  appKey: 'school_now',
);

final check = await updater.checkForUpdate();
if (check.hasUpdate) {
  final allowed = await updater.canInstallUnknownApps();
  if (!allowed) {
    await updater.openInstallUnknownAppsSettings();
    return;
  }

  await updater.downloadAndInstallRelease(check.release!);
}
```

Notes:

- Android only; iOS cannot self-update via APK.
- Every update APK must be signed with the same keystore as the installed app.
- Users must confirm installation.
