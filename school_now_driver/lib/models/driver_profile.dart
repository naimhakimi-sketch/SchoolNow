import 'user_profile.dart';

class DriverProfile extends UserProfile {
  final String? assignedBusPlate;

  const DriverProfile({
    required super.id,
    required super.name,
    required super.email,
    required super.role,
    this.assignedBusPlate,
  });

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'assigned_bus_plate': assignedBusPlate,
      };

  factory DriverProfile.fromJson(String id, Map<String, dynamic> json) {
    return DriverProfile(
      id: id,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? '',
      assignedBusPlate: json['assigned_bus_plate'],
    );
  }
}
