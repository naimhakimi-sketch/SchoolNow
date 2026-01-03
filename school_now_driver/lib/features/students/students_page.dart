import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/student_management_service.dart';

class StudentsPage extends StatelessWidget {
  final String driverId;

  const StudentsPage({super.key, required this.driverId});

  String _displayStudentName(Map<String, dynamic>? student, String studentId) {
    if (student == null) return studentId;
    final candidates = <String?>[];
    candidates.add((student['student_name'] ?? '').toString());
    candidates.add((student['name'] ?? '').toString());
    candidates.add((student['child_name'] ?? '').toString());
    candidates.add((student['childName'] ?? '').toString());
    final child = student['child'];
    if (child is Map) {
      candidates.add((child['name'] ?? '').toString());
    }
    for (final c in candidates) {
      if (c != null && c.trim().isNotEmpty) return c;
    }
    return studentId;
  }

  @override
  Widget build(BuildContext context) {
    final studentService = StudentManagementService();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Students', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),

            Expanded(
              child: ListView(
                children: [
                  Text(
                    'Pending Requests',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder(
                    stream: studentService.streamPendingRequests(driverId),
                    builder: (context, snap) {
                      final rawDocs = (snap.data as dynamic)?.docs as List?;
                      final docs = rawDocs == null ? null : List.of(rawDocs);
                      docs?.sort((a, b) {
                        final da = (a.data() as Map).cast<String, dynamic>();
                        final db = (b.data() as Map).cast<String, dynamic>();
                        final ta =
                            (da['created_at'] as Timestamp?)
                                ?.millisecondsSinceEpoch ??
                            0;
                        final tb =
                            (db['created_at'] as Timestamp?)
                                ?.millisecondsSinceEpoch ??
                            0;
                        return tb.compareTo(ta);
                      });
                      if (docs == null) return const SizedBox.shrink();
                      if (docs.isEmpty) {
                        return const Text('No pending requests.');
                      }
                      return Column(
                        children: docs.map((d) {
                          final data = (d.data() as Map)
                              .cast<String, dynamic>();
                          final studentId = (data['student_id'] ?? d.id)
                              .toString();
                          final studentName = _displayStudentName(
                            data,
                            studentId,
                          );
                          final parentName = (data['parent_name'] ?? '')
                              .toString();
                          final tripType = (data['trip_type'] ?? 'both')
                              .toString();

                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    studentName.isNotEmpty
                                        ? studentName
                                        : studentId,
                                  ),
                                  if (parentName.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'Parent: $parentName',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Trip Type: ${_getTripTypeLabel(tripType)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () async {
                                            await studentService.rejectRequest(
                                              driverId: driverId,
                                              requestId: d.id,
                                            );
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Request rejected. Refund should be handled by backend.',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                          child: const Text('Reject'),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () async {
                                            await studentService.approveRequest(
                                              driverId: driverId,
                                              requestId: d.id,
                                            );
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Request approved.',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                          child: const Text('Approve'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 16),
                  Text(
                    'Students Under Service',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder(
                    stream: studentService.streamApprovedStudents(driverId),
                    builder: (context, snap) {
                      final docs = (snap.data as dynamic)?.docs as List?;
                      if (docs == null) return const SizedBox.shrink();
                      if (docs.isEmpty) {
                        return const Text('No students under service');
                      }

                      return Column(
                        children: docs.map((d) {
                          final data = (d.data() as Map)
                              .cast<String, dynamic>();
                          final studentId = d.id;
                          final studentName = _displayStudentName(
                            data,
                            studentId,
                          );
                          final parentName = (data['parent_name'] ?? '')
                              .toString();
                          final parentPhone = (data['parent_phone'] ?? '')
                              .toString();
                          final schoolName = (data['school_name'] ?? '')
                              .toString();
                          final tripType = (data['trip_type'] ?? 'both')
                              .toString();

                          return Card(
                            child: ListTile(
                              title: Text(
                                studentName.isNotEmpty
                                    ? studentName
                                    : studentId,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (parentName.isNotEmpty ||
                                      parentPhone.isNotEmpty)
                                    Text(
                                      parentName.isNotEmpty
                                          ? 'Parent: $parentName'
                                          : 'Parent: $parentPhone',
                                    ),
                                  if (schoolName.isNotEmpty)
                                    Text(
                                      'School: $schoolName',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  Text(
                                    'Trip: ${_getTripTypeLabel(tripType)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: parentPhone.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Call parent',
                                      icon: const Icon(Icons.call),
                                      onPressed: () async {
                                        final uri = Uri.parse(
                                          'tel:$parentPhone',
                                        );
                                        if (!await launchUrl(uri)) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Could not launch phone dialer.',
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                    ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTripTypeLabel(String tripType) {
    return switch (tripType) {
      'going' => 'Going Only',
      'return' => 'Return Only',
      'both' => 'Both Ways',
      _ => 'Unknown',
    };
  }
}
