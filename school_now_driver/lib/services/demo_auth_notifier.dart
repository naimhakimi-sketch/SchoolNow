import 'package:flutter/foundation.dart';

/// In-memory demo mode notifier.
///
/// This avoids polling timers and lets AuthGate switch instantly.
class DemoAuthNotifier {
  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(false);
}
