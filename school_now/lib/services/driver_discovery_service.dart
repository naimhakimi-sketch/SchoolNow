import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

class DriverDiscoveryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> streamSearchableDrivers() {
    return _db.collection('drivers').where('is_searchable', isEqualTo: true).snapshots();
  }

  /// Returns true if the child's pickup location is inside driver's service radius.
  bool isDriverEligibleForPickup({
    required Map<String, dynamic> driverData,
    required LatLng pickup,
  }) {
    final serviceArea = (driverData['service_area'] as Map?)?.cast<String, dynamic>();
    final schoolLat = (serviceArea?['school_lat'] as num?)?.toDouble();
    final schoolLng = (serviceArea?['school_lng'] as num?)?.toDouble();
    final radiusKm = (serviceArea?['radius_km'] as num?)?.toDouble();
    if (schoolLat == null || schoolLng == null || radiusKm == null) return false;

    final dist = const Distance();
    final center = LatLng(schoolLat, schoolLng);
    final meters = dist(center, pickup);
    return meters <= radiusKm * 1000;
  }
}
