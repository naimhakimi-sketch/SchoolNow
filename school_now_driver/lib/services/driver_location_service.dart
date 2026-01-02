import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

class DriverLocationService {
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;
  StreamSubscription<Position>? _locationSubscription;
  String? _driverId;

  // Start tracking and updating location
  Future<void> startLocationTracking(String driverId) async {
    _driverId = driverId;

    // Request permission
    LocationPermission permission = LocationPermission.denied;
    try {
      permission = await Geolocator.checkPermission().timeout(
        const Duration(seconds: 5),
      );
    } catch (_) {
      permission = LocationPermission.denied;
    }
    if (permission == LocationPermission.denied) {
      try {
        permission = await Geolocator.requestPermission().timeout(
          const Duration(seconds: 8),
        );
      } catch (_) {
        permission = LocationPermission.denied;
      }
    }

    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      throw Exception('Location permission denied');
    }

    // Start listening to location updates
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );

    try {
      _locationSubscription =
          Geolocator.getPositionStream(
            locationSettings: locationSettings,
          ).listen((Position position) {
            _updateLocation(position);
          });
    } catch (_) {
      // If starting the stream fails, don't crash — caller will see tracking not active.
    }
  }

  // Update location in Realtime Database
  Future<void> _updateLocation(Position position) async {
    if (_driverId == null) return;

    try {
      await _rtdb.ref('live_locations/$_driverId').set({
        'lat': position.latitude,
        'lng': position.longitude,
        'timestamp': ServerValue.timestamp,
        'speed': position.speed,
        'heading': position.heading,
      });
    } catch (e) {
      // Error updating location - silently fail
    }
  }

  // Stop tracking
  void stopLocationTracking() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _driverId = null;
  }

  // Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }
}
