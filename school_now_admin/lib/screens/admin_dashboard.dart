import 'package:flutter/material.dart';
import 'change_credentials_screen.dart';
import 'manage_schools_screen.dart';
import 'manage_buses_screen.dart';
import 'manage_drivers_screen.dart';
import 'manage_parents_screen.dart';
import 'manage_students_screen.dart';
import 'manage_payments_screen.dart';
import 'manage_service_requests_screen.dart';
import 'analytics_dashboard_screen.dart';
import 'operator_settings_screen.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AnalyticsDashboardScreen(),
                ),
              );
            },
            tooltip: 'Analytics',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const OperatorSettingsScreen(),
                ),
              );
            },
            tooltip: 'Operator Settings',
          ),
        ],
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
                    icon: Icons.analytics,
                    title: 'Analytics',
                    subtitle: 'View statistics',
                    color: const Color(0xFF667eea),
                    screen: const AnalyticsDashboardScreen(),
                  ),
                  _dashboardCard(
                    context,
                    icon: Icons.lock_outline,
                    title: 'Credentials',
                    subtitle: 'Change login details',
                    color: const Color(0xFF764ba2),
                    screen: const ChangeCredentialsScreen(),
                  ),
                  _dashboardCard(
                    context,
                    icon: Icons.school_outlined,
                    title: 'Schools',
                    subtitle: 'Manage schools',
                    color: const Color(0xFF4facfe),
                    screen: const ManageSchoolsScreen(),
                  ),
                  _dashboardCard(
                    context,
                    icon: Icons.directions_bus_outlined,
                    title: 'Buses',
                    subtitle: 'Manage buses',
                    color: const Color(0xFF00f2fe),
                    screen: const ManageBusesScreen(),
                  ),
                  _dashboardCard(
                    context,
                    icon: Icons.people_outline,
                    title: 'Drivers',
                    subtitle: 'Manage drivers',
                    color: const Color(0xFF43e97b),
                    screen: const ManageDriversScreen(),
                  ),
                  _dashboardCard(
                    context,
                    icon: Icons.family_restroom,
                    title: 'Parents',
                    subtitle: 'Manage parents',
                    color: const Color(0xFFf093fb),
                    screen: const ManageParentsScreen(),
                  ),
                  _dashboardCard(
                    context,
                    icon: Icons.child_care,
                    title: 'Students',
                    subtitle: 'Manage students',
                    color: const Color(0xFFffa751),
                    screen: const ManageStudentsScreen(),
                  ),
                  _dashboardCard(
                    context,
                    icon: Icons.payment,
                    title: 'Payments',
                    subtitle: 'View payments',
                    color: const Color(0xFF38ef7d),
                    screen: const ManagePaymentsScreen(),
                  ),
                  _dashboardCard(
                    context,
                    icon: Icons.request_page,
                    title: 'Requests',
                    subtitle: 'Service requests',
                    color: const Color(0xFFf5576c),
                    screen: const ManageServiceRequestsScreen(),
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
    Color? color,
  }) {
    final cardColor = color ?? Colors.indigo;

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
              backgroundColor: cardColor.withValues(alpha: 0.1),
              child: Icon(icon, color: cardColor),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
