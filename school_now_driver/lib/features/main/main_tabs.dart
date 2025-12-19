import 'package:flutter/material.dart';

import '../drive/drive_page.dart';
import '../students/students_page.dart';
import '../profile/profile_page.dart';

class MainTabs extends StatefulWidget {
  final String driverId;
  final bool isDemoMode;

  const MainTabs({
    super.key,
    required this.driverId,
    required this.isDemoMode,
  });

  @override
  State<MainTabs> createState() => _MainTabsState();
}

class _MainTabsState extends State<MainTabs> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      DrivePage(driverId: widget.driverId, isDemoMode: widget.isDemoMode),
      StudentsPage(driverId: widget.driverId),
      ProfilePage(driverId: widget.driverId, isDemoMode: widget.isDemoMode),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.directions_bus), label: 'Drive'),
          BottomNavigationBarItem(icon: Icon(Icons.groups), label: 'Students'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
