class Stop {
  final String id;
  final String name;
  final double latitude;
  final double longitude;

  const Stop({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'lat': latitude,
        'lng': longitude,
      };

  factory Stop.fromJson(String id, Map<String, dynamic> json) => Stop(
        id: id,
        name: json['name'] as String,
        latitude: (json['lat'] as num).toDouble(),
        longitude: (json['lng'] as num).toDouble(),
      );
}
