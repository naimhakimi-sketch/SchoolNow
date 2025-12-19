import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ChildSelector extends StatelessWidget {
  final QuerySnapshot<Map<String, dynamic>> childrenSnap;
  final String? selectedChildId;
  final ValueChanged<String?> onChanged;

  const ChildSelector({
    super.key,
    required this.childrenSnap,
    required this.selectedChildId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final items = childrenSnap.docs;
    if (items.isEmpty) {
      return const Text('No child added yet.');
    }

    return DropdownButtonFormField<String>(
      initialValue: selectedChildId ?? items.first.id,
      decoration: const InputDecoration(labelText: 'Selected Child'),
      items: items
          .map(
            (d) => DropdownMenuItem(
              value: d.id,
              child: Text((d.data()['child_name'] ?? 'Child').toString()),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}
