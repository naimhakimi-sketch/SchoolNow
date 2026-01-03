import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_hosting_apk_updater/firebase_hosting_apk_updater.dart';

import 'core/firebase_options.dart';
import 'features/auth/auth_gate.dart';
import 'services/student_migration_service.dart';

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

  // Run student migration for trip_type field
  _runMigration();

  runApp(const SchoolNowApp());
}

Future<void> _runMigration() async {
  try {
    final service = StudentMigrationService();
    await service.migrateAllParents();
  } catch (e) {
    debugPrint('Student migration error: $e');
  }
}

class SchoolNowApp extends StatelessWidget {
  const SchoolNowApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFECCC6E);
    const Color secondaryColor = Color(0xFF814256);
    const Color backgroundColor = Colors.white;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SchoolNow',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.light(
          primary: primaryColor,
          secondary: secondaryColor,
          surface: backgroundColor,
          background: backgroundColor,
        ),
        scaffoldBackgroundColor: backgroundColor,
        appBarTheme: const AppBarTheme(
          backgroundColor: backgroundColor,
          foregroundColor: Colors.black87,
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.black87,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: secondaryColor,
            side: const BorderSide(color: secondaryColor, width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: primaryColor),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryColor, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        cardTheme: CardThemeData(
          color: backgroundColor,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: backgroundColor,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return primaryColor;
            }
            return Colors.grey[400];
          }),
          trackColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return primaryColor.withOpacity(0.5);
            }
            return Colors.grey[300];
          }),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: primaryColor,
          foregroundColor: Colors.black87,
          elevation: 4,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: backgroundColor,
          indicatorColor: primaryColor,
          labelTextStyle: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              );
            }
            return TextStyle(fontSize: 12, color: Colors.grey[600]);
          }),
          iconTheme: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return const IconThemeData(color: Colors.black87);
            }
            return IconThemeData(color: Colors.grey[600]);
          }),
        ),
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
