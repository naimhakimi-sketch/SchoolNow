import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'demo_auth_notifier.dart';

class DemoAuthService {
  static const String demoUid = 'demo_driver_uid_12345';
  static const String demoEmail = 'demo@schoolnow.local';
  static const String _demoModeKey = 'demo_mode_enabled';

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    DemoAuthNotifier.enabled.value = prefs.getBool(_demoModeKey) ?? false;
  }

  static Future<void> setupDemoUser() async {
    final db = FirebaseFirestore.instance;
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_demoModeKey, true);
    DemoAuthNotifier.enabled.value = true;

    await db.collection('drivers').doc(demoUid).set({
      'ic_number': 'DEMO-IC-0000',
      'ic_number_normalized': 'DEMOIC0000',
      'name': 'Demo Driver',
      'email': demoEmail,
      'contact_number': '+60123456789',
      'address': 'Demo Home / Operator Address',
      'transport_number': 'WXX 1234',
      'seat_capacity': 12,
      'home_location': {
        'lat': 3.1390,
        'lng': 101.6869,
        'display_name': 'Demo Home (Kuala Lumpur)',
      },
      'service_area': {
        'school_name': 'Demo School',
        'school_lat': 3.1478,
        'school_lng': 101.7016,
        'side': 'north',
        'radius_km': 10,
      },
      'role': 'driver',
      'created_at': FieldValue.serverTimestamp(),
      'is_demo': true,
      'is_verified': true,
      'is_searchable': true,
    }, SetOptions(merge: true));

    // Seed students under service (approved).
    final students = db
        .collection('drivers')
        .doc(demoUid)
        .collection('students');
    await students.doc('student_demo_001').set({
      'student_name': 'Ali Demo',
      'parent_name': 'Parent Ali',
      'contact_number': '+60111111111',
      'pickup_location': {
        'latitude': 3.1520,
        'longitude': 101.6860,
        'display_name': 'Pickup 1',
      },
      'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await students.doc('student_demo_002').set({
      'student_name': 'Siti Demo',
      'parent_name': 'Parent Siti',
      'contact_number': '+60122222222',
      'pickup_location': {
        'latitude': 3.1335,
        'longitude': 101.6980,
        'display_name': 'Pickup 2',
      },
      'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Seed pending requests.
    final requests = db
        .collection('drivers')
        .doc(demoUid)
        .collection('service_requests');
    await requests.doc('req_demo_001').set({
      'status': 'pending',
      'student_id': 'student_demo_003',
      'student_name': 'Hafiz Demo',
      'parent_name': 'Parent Hafiz',
      'contact_number': '+60133333333',
      'pickup_location': {
        'latitude': 3.1602,
        'longitude': 101.7070,
        'display_name': 'Pickup 3',
      },
      'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> exitDemoMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_demoModeKey, false);
    DemoAuthNotifier.enabled.value = false;
  }

  static String getDemoUid() => demoUid;
}
