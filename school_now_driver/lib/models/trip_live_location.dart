class TripLiveLocation {
  final double latitude;
  final double longitude;
  final double? speed;
  final double? heading;
  final DateTime timestamp;

  const TripLiveLocation({
    required this.latitude,
    required this.longitude,
    this.speed,
    this.heading,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'lat': latitude,
        'lng': longitude,
        'speed': speed,
        'heading': heading,
        'ts': timestamp.millisecondsSinceEpoch,
      };

  factory TripLiveLocation.fromJson(Map<String, dynamic> json) => TripLiveLocation(
        latitude: (json['lat'] as num).toDouble(),
        longitude: (json['lng'] as num).toDouble(),
        speed: (json['speed'] as num?)?.toDouble(),
        heading: (json['heading'] as num?)?.toDouble(),
        timestamp: DateTime.fromMillisecondsSinceEpoch(json['ts'] as int),
      );

  static String pathForTrip(String tripId) => 'trips/$tripId/live_location';
}
