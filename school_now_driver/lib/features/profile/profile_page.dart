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

  Future<void> _openEditProfile(BuildContext context, Map<String, dynamic>? data) async {
    final didSave = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditProfilePage(
          driverId: driverId,
          initialData: data,
        ),
      ),
    );

    if (didSave == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final driverService = DriverService();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder(
          stream: driverService.streamDriver(driverId),
          builder: (context, snap) {
            final data = (snap.data as dynamic)?.data() as Map<String, dynamic>?;

            final name = (data?['name'] ?? 'Driver').toString();
            final email = (data?['email'] ?? '').toString();
            final ic = (data?['ic_number'] ?? '').toString();
            final contact = (data?['contact_number'] ?? '').toString();
            final address = (data?['address'] ?? '').toString();
            final transport = (data?['transport_number'] ?? '').toString();
            final seatCapacity = (data?['seat_capacity'] ?? '').toString();
            final monthlyFee = (data?['monthly_fee'] ?? '').toString();
            final verified = (data?['is_verified'] == true);
            final searchable = (data?['is_searchable'] == true);

            final serviceArea = (data?['service_area'] as Map?)?.cast<String, dynamic>();
            final schoolName = (serviceArea?['school_name'] ?? '').toString();
            final side = (serviceArea?['side'] ?? '').toString();
            final radius = (serviceArea?['radius_km'] ?? '').toString();

            final assignedBusPlate = data?['transport_number']?.toString();


            return ListView(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Profile', style: Theme.of(context).textTheme.headlineSmall),
                    ),
                    TextButton.icon(
                      onPressed: () => _openEditProfile(context, data),
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                    ),
                    TextButton.icon(
                      onPressed: () => _logout(),
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 🔹 Profile Info Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        ListTile(title: const Text('Name'), subtitle: Text(name)),
                        if (ic.isNotEmpty) ListTile(title: const Text('IC Number'), subtitle: Text(ic)),
                        if (email.isNotEmpty) ListTile(title: const Text('Email'), subtitle: Text(email)),
                        if (contact.isNotEmpty) ListTile(title: const Text('Contact Number'), subtitle: Text(contact)),
                        if (address.isNotEmpty) ListTile(title: const Text('Address'), subtitle: Text(address)),
                        if (transport.isNotEmpty)
                          ListTile(title: const Text('Transport Number'), subtitle: Text(transport)),
                        if (seatCapacity.isNotEmpty)
                          ListTile(title: const Text('Seat Capacity'), subtitle: Text(seatCapacity)),
                        if (monthlyFee.isNotEmpty)
                          ListTile(title: const Text('Monthly Fee'), subtitle: Text(monthlyFee)),
                        ListTile(
                          title: const Text('Verification'),
                          subtitle: Text(verified ? 'Verified' : 'Pending verification'),
                        ),
                        SwitchListTile(
                          title: const Text('Visible to parents'),
                          subtitle: Text(
                            verified
                                ? 'Parents can find you in Drivers'
                                : 'Disabled until verification is approved',
                          ),
                          value: searchable,
                          onChanged: !verified
                              ? null
                              : (v) async {
                                  await driverService.updateDriver(driverId, {'is_searchable': v});
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(v ? 'Profile is now visible.' : 'Profile is now hidden.')),
                                    );
                                  }
                                },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // 🚌 Assigned Bus Card
                if (assignedBusPlate != null)
                  StreamBuilder<Vehicle?>(
                    stream: driverService.watchAssignedBus(assignedBusPlate),
                    builder: (context, busSnap) {
                      if (!busSnap.hasData) {
                        return const Card(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('Loading assigned bus...'),
                          ),
                        );
                      }

                      final bus = busSnap.data!;

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              const ListTile(title: Text('Assigned Bus')),
                              ListTile(title: const Text('Plate'), subtitle: Text(bus.plate)),
                              ListTile(title: const Text('Capacity'), subtitle: Text(bus.capacity.toString())),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 12),

                // 🔹 Service Area Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        const ListTile(title: Text('Service Area')),
                        if (schoolName.isNotEmpty) ListTile(title: const Text('School'), subtitle: Text(schoolName)),
                        if (side.isNotEmpty) ListTile(title: const Text('Side'), subtitle: Text(side)),
                        if (radius.isNotEmpty) ListTile(title: const Text('Radius (km)'), subtitle: Text(radius)),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
