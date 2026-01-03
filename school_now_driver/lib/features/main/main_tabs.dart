import 'package:flutter/material.dart';

import '../drive/drive_page.dart';
import '../students/students_page.dart';
import '../profile/profile_page.dart';
import '../../services/driver_location_service.dart';

class MainTabs extends StatefulWidget {
  final String driverId;
  final bool isDemoMode;

  const MainTabs({super.key, required this.driverId, required this.isDemoMode});

  @override
  State<MainTabs> createState() => _MainTabsState();
}

class _MainTabsState extends State<MainTabs> {
  int _index = 0;
  final DriverLocationService _locationService = DriverLocationService();
  bool _isTrackingLocation = false;

  @override
  void initState() {
    super.initState();
    _startLocationTracking();
  }

  Future<void> _startLocationTracking() async {
    try {
      await _locationService.startLocationTracking(widget.driverId);
      setState(() => _isTrackingLocation = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location tracking disabled: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _locationService.stopLocationTracking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DrivePage(driverId: widget.driverId, isDemoMode: widget.isDemoMode),
      StudentsPage(driverId: widget.driverId),
      ProfilePage(driverId: widget.driverId, isDemoMode: widget.isDemoMode),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              _isTrackingLocation ? Icons.gps_fixed : Icons.gps_off,
              color: _isTrackingLocation
                  ? const Color(0xFFECCC6E)
                  : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              _isTrackingLocation ? 'Location Active' : 'Location Off',
              style: TextStyle(
                color: _isTrackingLocation
                    ? const Color(0xFFECCC6E)
                    : const Color(0xFF999999),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        elevation: 16,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_bus),
            label: 'Drive',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.groups), label: 'Students'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
