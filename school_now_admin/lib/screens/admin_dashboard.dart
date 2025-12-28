import 'package:flutter/material.dart';
import 'change_credentials_screen.dart';
import 'manage_schools_screen.dart';
import 'manage_buses_screen.dart';
import 'manage_drivers_screen.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome, Admin 👋',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Manage your system easily',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 24),

            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _dashboardCard(
                    context,
                    icon: Icons.lock_outline,
                    title: 'Credentials',
                    subtitle: 'Change login details',
                    screen: const ChangeCredentialsScreen(),
                  ),
                  _dashboardCard(
                    context,
                    icon: Icons.school_outlined,
                    title: 'Schools',
                    subtitle: 'Manage schools',
                    screen: const ManageSchoolsScreen(),
                  ),
                  _dashboardCard(
                    context,
                    icon: Icons.directions_bus_outlined,
                    title: 'Buses',
                    subtitle: 'Manage buses',
                    screen: const ManageBusesScreen(),
                  ),
                  _dashboardCard(
                    context,
                    icon: Icons.people_outline,
                    title: 'Drivers',
                    subtitle: 'Manage drivers',
                    screen: const ManageDriversScreen(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dashboardCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget screen,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x11000000),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: Colors.indigo.withOpacity(0.1),
              child: Icon(icon, color: Colors.indigo),
            ),
            const Spacer(),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}
