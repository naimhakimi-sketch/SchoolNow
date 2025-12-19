import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:location/location.dart';
import '../models/trip_live_location.dart';

class LiveLocationService {
  final Location _location = Location();
  StreamSubscription<LocationData>? _sub;

  Future<void> startSharing({
    required String tripId,
    required String driverId,
  }) async {
    final granted = await _ensurePermissions();
    if (!granted) return;
    final tripRef = FirebaseDatabase.instance.ref(TripLiveLocation.pathForTrip(tripId));
    final driverRef = FirebaseDatabase.instance.ref('live_locations/$driverId');
    _sub?.cancel();
    _sub = _location.onLocationChanged.listen((data) async {
      final loc = TripLiveLocation(
        latitude: (data.latitude ?? 0).toDouble(),
        longitude: (data.longitude ?? 0).toDouble(),
        speed: (data.speed ?? 0).toDouble(),
        heading: (data.heading ?? 0).toDouble(),
        timestamp: DateTime.now(),
      );
      final payload = loc.toJson();
      await Future.wait([
        tripRef.set(payload),
        driverRef.set(payload),
      ]);
    });
  }

  Future<void> stopSharing() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<bool> _ensurePermissions() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return false;
    }
    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return false;
    }
    return true;
  }
}
