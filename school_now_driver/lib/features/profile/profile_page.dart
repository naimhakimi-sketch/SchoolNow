import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/demo_auth_service.dart';
import '../../services/driver_service.dart';
import '../../models/vehicle.dart';
import 'edit_profile_page.dart';

class ProfilePage extends StatelessWidget {
  final String driverId;
  final bool isDemoMode;

  const ProfilePage({
    super.key,
    required this.driverId,
    required this.isDemoMode,
  });

  Future<void> _logout() async {
    if (isDemoMode) {
      await DemoAuthService.exitDemoMode();
    } else {
      await FirebaseAuth.instance.signOut();
    }
  }

  Future<void> _openEditProfile(
    BuildContext context,
    Map<String, dynamic>? data,
  ) async {
    final didSave = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditProfilePage(driverId: driverId, initialData: data),
      ),
    );

    if (didSave == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final driverService = DriverService();

    return SafeArea(
      child: StreamBuilder(
        stream: driverService.streamDriver(driverId),
        builder: (context, snap) {
          final data = (snap.data as dynamic)?.data() as Map<String, dynamic>?;

          final name = (data?['name'] ?? 'Driver').toString();
          final email = (data?['email'] ?? '').toString();
          final ic = (data?['ic_number'] ?? '').toString();
          final contact = (data?['contact_number'] ?? '').toString();
          final address = (data?['address'] ?? '').toString();
          final monthlyFee = (data?['monthly_fee'] ?? '').toString();
          final verified = (data?['is_verified'] == true);
          final searchable = (data?['is_searchable'] == true);

          final serviceArea = (data?['service_area'] as Map?)
              ?.cast<String, dynamic>();
          final schoolName = (serviceArea?['school_name'] ?? '').toString();
          final side = (serviceArea?['side'] ?? '').toString();
          final radius = (serviceArea?['radius_km'] ?? '').toString();

          final assignedBusPlate = data?['transport_number']?.toString();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header with Edit and Logout
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Profile',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Row(
                    children: [
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.edit),
                          onPressed: () => _openEditProfile(context, data),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFF5F5F5),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.logout,
                            color: Color(0xFF814256),
                          ),
                          onPressed: () => _logout(),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFFFE8ED),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Profile Info Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: const Color(0xFFECCC6E),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'D',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2C2C2C),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2C2C2C),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: verified
                                        ? const Color(
                                            0xFFECCC6E,
                                          ).withValues(alpha: 0.1)
                                        : const Color(0xFFFFE8ED),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        verified
                                            ? Icons.verified_outlined
                                            : Icons.info_outline,
                                        size: 14,
                                        color: verified
                                            ? const Color(0xFFECCC6E)
                                            : const Color(0xFF814256),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        verified ? 'Verified' : 'Pending',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: verified
                                              ? const Color(0xFFECCC6E)
                                              : const Color(0xFF814256),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      _buildProfileField('IC Number', ic),
                      const SizedBox(height: 12),
                      _buildProfileField('Email', email),
                      const SizedBox(height: 12),
                      _buildProfileField('Contact', contact),
                      if (address.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildProfileField('Address', address),
                      ],
                      if (monthlyFee.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildProfileField('Monthly Fee', monthlyFee),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Visibility Toggle
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Visible to Parents',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2C2C2C),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              verified
                                  ? 'Parents can find you'
                                  : 'Disabled until verified',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF999999),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: searchable,
                        onChanged: !verified
                            ? null
                            : (v) async {
                                await driverService.updateDriver(driverId, {
                                  'is_searchable': v,
                                });
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        v
                                            ? 'Profile is now visible'
                                            : 'Profile is now hidden',
                                      ),
                                    ),
                                  );
                                }
                              },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Assigned Bus Card
              if (assignedBusPlate != null)
                StreamBuilder<Vehicle?>(
                  stream: driverService.watchAssignedBus(assignedBusPlate),
                  builder: (context, busSnap) {
                    if (!busSnap.hasData) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: SizedBox(
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    }

                    final bus = busSnap.data!;

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.directions_bus,
                                  color: Color(0xFFECCC6E),
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Assigned Bus',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2C2C2C),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildProfileField('Plate', bus.plate),
                            const SizedBox(height: 12),
                            _buildProfileField(
                              'Capacity',
                              '${bus.capacity} seats',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

              const SizedBox(height: 16),

              // Service Area Card
              if (schoolName.isNotEmpty || radius.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: Color(0xFF814256),
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Service Area',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2C2C2C),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (schoolName.isNotEmpty)
                          _buildProfileField('School', schoolName),
                        if (schoolName.isNotEmpty && side.isNotEmpty)
                          const SizedBox(height: 12),
                        if (side.isNotEmpty) _buildProfileField('Side', side),
                        if (radius.isNotEmpty &&
                            (schoolName.isNotEmpty || side.isNotEmpty))
                          const SizedBox(height: 12),
                        if (radius.isNotEmpty)
                          _buildProfileField('Radius', '$radius km'),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProfileField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF999999),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C2C2C),
          ),
        ),
      ],
    );
  }
}
