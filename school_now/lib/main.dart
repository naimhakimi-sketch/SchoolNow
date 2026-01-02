import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_hosting_apk_updater/firebase_hosting_apk_updater.dart';

import 'core/firebase_options.dart';
import 'features/auth/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } on FirebaseException catch (e) {
    // On some Android setups Firebase may be auto-initialized natively.
    // In that case, calling initializeApp again throws duplicate-app.
    if (e.code != 'duplicate-app') rethrow;
  }

  runApp(const SchoolNowApp());
}

class SchoolNowApp extends StatelessWidget {
  const SchoolNowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SchoolNow',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const _UpdateOnStart(appKey: 'school_now', child: AuthGate()),
    );
  }
}

class _UpdateOnStart extends StatefulWidget {
  const _UpdateOnStart({required this.appKey, required this.child});

  final String appKey;
  final Widget child;

  static const String manifestUrl =
      'https://busnow-applications.web.app/updates/manifest.json';

  @override
  State<_UpdateOnStart> createState() => _UpdateOnStartState();
}

class _UpdateOnStartState extends State<_UpdateOnStart> {
  bool _checked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_checked) return;
    _checked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    try {
      final updater = FirebaseHostingApkUpdater(
        manifestUrl: _UpdateOnStart.manifestUrl,
        appKey: widget.appKey,
      );

      final check = await updater.checkForUpdate();
      final release = check.release;
      if (!mounted || !check.hasUpdate || release == null) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) {
          var downloading = false;

          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('Update available'),
                content: Text(
                  'Version ${release.versionName} is available.\n\nInstall now?',
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: downloading
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: const Text('Later'),
                  ),
                  FilledButton(
                    onPressed: downloading
                        ? null
                        : () async {
                            setState(() => downloading = true);
                            try {
                              final allowed = await updater
                                  .canInstallUnknownApps();
                              if (!allowed) {
                                await updater.openInstallUnknownAppsSettings();
                                return;
                              }
                              await updater.downloadAndInstallRelease(
                                release: release,
                              );
                            } catch (e) {
                              if (!dialogContext.mounted) return;
                              await showDialog<void>(
                                context: dialogContext,
                                builder: (_) => AlertDialog(
                                  title: const Text('Update failed'),
                                  content: Text(e.toString()),
                                  actions: <Widget>[
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(dialogContext).pop(),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                            } finally {
                              if (dialogContext.mounted) {
                                setState(() => downloading = false);
                              }
                            }
                          },
                    child: downloading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Update'),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (_) {
      // Ignore update errors on startup.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
