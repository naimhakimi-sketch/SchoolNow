import 'package:firebase_database/firebase_database.dart';

class TripLiveLocationService {
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;

  DatabaseReference liveLocationRef(String tripId) => _rtdb.ref('trips/$tripId/live_location');

  DatabaseReference driverLiveLocationRef(String driverId) =>
      _rtdb.ref('live_locations/$driverId');

  Stream<DatabaseEvent> streamLiveLocation(String tripId) => liveLocationRef(tripId).onValue;

  Stream<DatabaseEvent> streamDriverLiveLocation(String driverId) =>
      driverLiveLocationRef(driverId).onValue;
}
