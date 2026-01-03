import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/parent_service.dart';
import '../children/add_child_page.dart';
import '../children/child_selector.dart';
import '../drivers/drivers_page.dart';
import '../monitor/monitor_page.dart';
import '../profile/profile_page.dart';
import '../student/student_page.dart';

class HomePage extends StatefulWidget {
  final String parentId;

  const HomePage({super.key, required this.parentId});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _parentService = ParentService();
  int _index = 0;
  String? _selectedChildId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _parentService.streamChildren(widget.parentId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final childrenSnap = snap.data;
        if (childrenSnap == null || childrenSnap.docs.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              title: Image.asset('launcher/title.png', height: 40),
              centerTitle: false,
              elevation: 0,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_add_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No children added yet',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your first child to get started',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AddChildPage()),
                      );
                    },
                    icon: const Icon(Icons.person_add_outlined),
                    label: const Text('Add Child'),
                  ),
                ],
              ),
            ),
          );
        }

        _selectedChildId ??= childrenSnap.docs.first.id;

        final selectedChildId = _selectedChildId;
        QueryDocumentSnapshot<Map<String, dynamic>> selectedChild =
            childrenSnap.docs.first;
        if (selectedChildId != null) {
          for (final d in childrenSnap.docs) {
            if (d.id == selectedChildId) {
              selectedChild = d;
              break;
            }
          }
        }

        final pages = <Widget>[
          DriversPage(parentId: widget.parentId, childDoc: selectedChild),
          MonitorPage(parentId: widget.parentId, childDoc: selectedChild),
          StudentPage(parentId: widget.parentId, childDoc: selectedChild),
          ProfilePage(parentId: widget.parentId, childDoc: selectedChild),
        ];

        return Scaffold(
          appBar: AppBar(
            title: Image.asset('launcher/title.png', height: 40),
            centerTitle: false,
            elevation: 0,
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  width: 220,
                  child: ChildSelector(
                    childrenSnap: childrenSnap,
                    selectedChildId: _selectedChildId,
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _selectedChildId = v;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          body: pages[_index],
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            indicatorColor: const Color(0xFFECCC6E),
            backgroundColor: Colors.white,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.directions_bus_outlined),
                selectedIcon: Icon(Icons.directions_bus_filled),
                label: 'Drivers',
              ),
              NavigationDestination(
                icon: Icon(Icons.map_outlined),
                selectedIcon: Icon(Icons.map),
                label: 'Monitor',
              ),
              NavigationDestination(
                icon: Icon(Icons.qr_code_outlined),
                selectedIcon: Icon(Icons.qr_code),
                label: 'Student',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outlined),
                selectedIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }
}
