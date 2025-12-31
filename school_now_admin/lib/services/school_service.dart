import 'package:cloud_firestore/cloud_firestore.dart';

class SchoolService {
  final _db = FirebaseFirestore.instance;

  Future<void> addSchool({
    required String name,
    required String type,
    required String address,
    required GeoPoint location,
  }) async {
    await _db.collection('schools').add({
      'name': name,
      'type': type,
      'address': address,
      'geo_location': {
        'latitude': location.latitude,
        'longitude': location.longitude,
      },
    });
  }

  Stream<QuerySnapshot> getSchools() {
    return _db.collection('schools').snapshots();
  }

  Future<void> updateSchool(
    String id, {
    required String name,
    required String type,
    required String address,
    required GeoPoint location,
  }) async {
    await _db.collection('schools').doc(id).update({
      'name': name,
      'type': type,
      'address': address,
      'geo_location': {
        'latitude': location.latitude,
        'longitude': location.longitude,
      },
    });
  }

  Future<void> deleteSchool(String id) async {
    await _db.collection('schools').doc(id).delete();
  }
}
