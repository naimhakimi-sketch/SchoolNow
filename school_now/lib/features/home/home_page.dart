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

  const HomePage({
    super.key,
    required this.parentId,
  });

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
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final childrenSnap = snap.data;
        if (childrenSnap == null || childrenSnap.docs.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('SchoolNow')),
            body: const Center(child: Text('No child added yet.')),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddChildPage()));
              },
              icon: const Icon(Icons.person_add),
              label: const Text('Add Child'),
            ),
          );
        }

        _selectedChildId ??= childrenSnap.docs.first.id;

        final selectedChildId = _selectedChildId;
        QueryDocumentSnapshot<Map<String, dynamic>> selectedChild = childrenSnap.docs.first;
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
            title: const Text('SchoolNow'),
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
            destinations: const [
              NavigationDestination(icon: Icon(Icons.directions_bus), label: 'Drivers'),
              NavigationDestination(icon: Icon(Icons.map), label: 'Monitor'),
              NavigationDestination(icon: Icon(Icons.qr_code), label: 'Student'),
              NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
            ],
          ),
        );
      },
    );
  }
}
