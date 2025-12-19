class Vehicle {
  final String id;
  final String plateNumber;
  final int capacity;

  const Vehicle({
    required this.id,
    required this.plateNumber,
    required this.capacity,
  });

  Map<String, dynamic> toJson() => {
        'plate_number': plateNumber,
        'capacity': capacity,
      };

  factory Vehicle.fromJson(String id, Map<String, dynamic> json) => Vehicle(
        id: id,
        plateNumber: json['plate_number'] as String,
        capacity: json['capacity'] as int,
      );
}
