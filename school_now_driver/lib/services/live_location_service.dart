import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:location/location.dart';
import '../models/trip_live_location.dart';

class LiveLocationService {
  final Location _location = Location();
  StreamSubscription<LocationData>? _sub;
  Timer? _heartbeat;
  DateTime? _lastSuccessfulWriteAt;

  Future<void> startSharing({
    required String tripId,
    required String driverId,
  }) async {
    final granted = await _ensurePermissions();
    if (!granted) return;

    // Make sure we actually emit updates frequently enough.
    // (Defaults can be too conservative on some devices.)
    try {
      await _location.changeSettings(
        accuracy: LocationAccuracy.high,
        // Most aggressive settings supported by the plugin API:
        // request updates every ~1s and on any movement.
        // Note: OS/device may still throttle/clamp in practice.
        interval: 1000,
        distanceFilter: 0,
      );
    } catch (_) {}

    final tripRef = FirebaseDatabase.instance.ref(
      TripLiveLocation.pathForTrip(tripId),
    );
    final driverRef = FirebaseDatabase.instance.ref('live_locations/$driverId');
    _sub?.cancel();
    _heartbeat?.cancel();

    Future<void> write(LocationData data) async {
      final loc = TripLiveLocation(
        latitude: (data.latitude ?? 0).toDouble(),
        longitude: (data.longitude ?? 0).toDouble(),
        speed: (data.speed ?? 0).toDouble(),
        heading: (data.heading ?? 0).toDouble(),
        timestamp: DateTime.now(),
      );
      final payload = loc.toJson();
      await Future.wait([tripRef.set(payload), driverRef.set(payload)]);
      _lastSuccessfulWriteAt = DateTime.now();
    }

    // Write once immediately (so parents see something even before movement).
    try {
      final first = await _location.getLocation().timeout(
        const Duration(seconds: 5),
      );
      await write(first).timeout(const Duration(seconds: 5));
    } catch (_) {}

    // Heartbeat: ensure at least one update per minute even if the platform
    // throttles stream callbacks or the device is stationary.
    _heartbeat = Timer.periodic(const Duration(minutes: 1), (_) async {
      final last = _lastSuccessfulWriteAt;
      if (last != null &&
          DateTime.now().difference(last) < const Duration(seconds: 55)) {
        return;
      }
      try {
        final now = await _location.getLocation();
        await write(now);
      } catch (_) {
        // Best-effort only.
      }
    });

    _sub = _location.onLocationChanged.listen((data) async {
      try {
        await write(data);
      } catch (_) {
        // Keep listening even if a write fails (e.g., transient network).
      }
    });
  }

  Future<void> stopSharing() async {
    await _sub?.cancel();
    _sub = null;
    _heartbeat?.cancel();
    _heartbeat = null;
    _lastSuccessfulWriteAt = null;
  }

  Future<bool> _ensurePermissions() async {
    bool serviceEnabled = false;
    try {
      serviceEnabled = await _location.serviceEnabled().timeout(
        const Duration(seconds: 6),
      );
    } catch (_) {
      serviceEnabled = false;
    }
    if (!serviceEnabled) {
      try {
        serviceEnabled = await _location.requestService().timeout(
          const Duration(seconds: 8),
        );
      } catch (_) {
        serviceEnabled = false;
      }
      if (!serviceEnabled) return false;
    }

    PermissionStatus permissionGranted = PermissionStatus.denied;
    try {
      permissionGranted = await _location.hasPermission().timeout(
        const Duration(seconds: 4),
      );
    } catch (_) {
      permissionGranted = PermissionStatus.denied;
    }
    if (permissionGranted == PermissionStatus.denied) {
      try {
        permissionGranted = await _location.requestPermission().timeout(
          const Duration(seconds: 8),
        );
      } catch (_) {
        permissionGranted = PermissionStatus.denied;
      }
      if (permissionGranted != PermissionStatus.granted) return false;
    }
    return true;
  }
}
