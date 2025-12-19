import 'package:firebase_database/firebase_database.dart';

class TripLiveLocationService {
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;

  DatabaseReference liveLocationRef(String tripId) => _rtdb.ref('trips/$tripId/live_location');

  Stream<DatabaseEvent> streamLiveLocation(String tripId) => liveLocationRef(tripId).onValue;
}
