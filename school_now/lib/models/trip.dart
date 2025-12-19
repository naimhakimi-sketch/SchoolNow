import 'trip_passenger.dart';

enum TripStatus { planned, inProgress, completed }

class Trip {
  final String id;
  final String driverId;
  final String vehicleId;
  final String routeId;
  final TripStatus status;
  final int? startTimeMs;
  final int? endTimeMs;
  final List<TripPassenger> passengers;
  final String liveLocationPath;

  const Trip({
    required this.id,
    required this.driverId,
    required this.vehicleId,
    required this.routeId,
    required this.status,
    this.startTimeMs,
    this.endTimeMs,
    required this.passengers,
    required this.liveLocationPath,
  });

  Map<String, dynamic> toJson() => {
        'driver_id': driverId,
        'vehicle_id': vehicleId,
        'route_id': routeId,
        'status': _statusToString(status),
        'start_time_ms': startTimeMs,
        'end_time_ms': endTimeMs,
        'passengers': passengers.map((p) => p.toJson()).toList(),
        'live_location_path': liveLocationPath,
      };

  factory Trip.fromJson(String id, Map<String, dynamic> json) => Trip(
        id: id,
        driverId: json['driver_id'] as String,
        vehicleId: json['vehicle_id'] as String,
        routeId: json['route_id'] as String,
        status: _statusFromString(json['status'] as String),
        startTimeMs: json['start_time_ms'] as int?,
        endTimeMs: json['end_time_ms'] as int?,
        passengers: ((json['passengers'] as List?) ?? [])
            .map((e) => TripPassenger.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        liveLocationPath: json['live_location_path'] as String,
      );

  static String _statusToString(TripStatus s) {
    switch (s) {
      case TripStatus.planned:
        return 'planned';
      case TripStatus.inProgress:
        return 'in_progress';
      case TripStatus.completed:
        return 'completed';
    }
  }

  static TripStatus _statusFromString(String s) {
    switch (s) {
      case 'planned':
        return TripStatus.planned;
      case 'in_progress':
        return TripStatus.inProgress;
      case 'completed':
        return TripStatus.completed;
      default:
        return TripStatus.planned;
    }
  }
}
