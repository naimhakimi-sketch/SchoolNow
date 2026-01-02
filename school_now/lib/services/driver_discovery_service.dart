import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

class DriverDiscoveryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> streamSearchableDrivers() {
    return _db
        .collection('drivers')
        .where('is_searchable', isEqualTo: true)
        .snapshots();
  }

  /// Returns true if the child's pickup location is inside driver's service radius.
  bool isDriverEligibleForPickup({
    required Map<String, dynamic> driverData,
    LatLng? pickup,
    String? childSchoolId,
  }) {
    // Enforce assigned_school_ids constraint if the driver declares served schools.
    final assignedSchoolIds =
        (driverData['assigned_school_ids'] as List?)?.cast<String>() ?? [];
    if (childSchoolId != null &&
        assignedSchoolIds.isNotEmpty &&
        !assignedSchoolIds.contains(childSchoolId)) {
      return false;
    }

    // If pickup is not provided, we've already validated school assignment (if any).
    if (pickup == null) {
      return true;
    }

    final serviceArea = (driverData['service_area'] as Map?)
        ?.cast<String, dynamic>();
    final centerLat = (serviceArea?['center_lat'] as num?)?.toDouble();
    final centerLng = (serviceArea?['center_lng'] as num?)?.toDouble();
    final radiusKm = (serviceArea?['radius_km'] as num?)?.toDouble();
    if (centerLat == null || centerLng == null || radiusKm == null) {
      return false;
    }

    final dist = const Distance();
    final center = LatLng(centerLat, centerLng);
    final meters = dist(center, pickup);
    return meters <= radiusKm * 1000;
  }
}
