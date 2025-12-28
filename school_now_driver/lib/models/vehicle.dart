class Vehicle {
  final String plate;
  final int capacity;

  const Vehicle({
    required this.plate,
    required this.capacity,
  });

  Map<String, dynamic> toJson() => {
        'plate': plate,
        'capacity': capacity,
      };

  factory Vehicle.fromFirestore(String id, Map<String, dynamic> json) => Vehicle(
        plate: json['plate'] as String,
        capacity: (json['capacity'] ?? 0) as int,
      );
}
