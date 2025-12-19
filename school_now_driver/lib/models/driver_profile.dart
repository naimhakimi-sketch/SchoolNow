import 'user_profile.dart';

class DriverProfile extends UserProfile {
  final String? vehicleId;

  const DriverProfile({
    required super.id,
    required super.name,
    required super.email,
    required super.role,
    this.vehicleId,
  });

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'vehicle_id': vehicleId,
      };
}
