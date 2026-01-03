import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../services/driver_discovery_service.dart';
import '../../services/request_payment_service.dart';
import '../payments/payment_page.dart';

class DriversPage extends StatefulWidget {
  final String parentId;
  final QueryDocumentSnapshot<Map<String, dynamic>> childDoc;

  const DriversPage({
    super.key,
    required this.parentId,
    required this.childDoc,
  });

  @override
  State<DriversPage> createState() => _DriversPageState();
}

class _DriversPageState extends State<DriversPage> {
  final _discovery = DriverDiscoveryService();
  final _requestService = RequestPaymentService();

  bool _submitting = false;
  String? _error;

  LatLng? _pickupFromChild() {
    final m = (widget.childDoc.data()['pickup_location'] as Map?)
        ?.cast<String, dynamic>();
    if (m == null) return null;
    final lat = (m['lat'] as num?)?.toDouble();
    final lng = (m['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  Future<void> _requestDriver({
    required String driverId,
    required Map<String, dynamic> driverData,
  }) async {
    final child = widget.childDoc.data();
    final assigned = (child['assigned_driver_id'] as String?);
    if (assigned != null && assigned.isNotEmpty) {
      setState(() {
        _error = 'This child already has an assigned driver.';
      });
      return;
    }

    final parentUser = FirebaseAuth.instance.currentUser;
    if (parentUser == null) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final parentSnap = await FirebaseFirestore.instance
          .collection('parents')
          .doc(widget.parentId)
          .get();
      final parentData = parentSnap.data() ?? const <String, dynamic>{};
      final parentName =
          (parentData['name'] ?? parentUser.displayName ?? 'Parent').toString();
      final parentPhone = (parentData['contact_number'] ?? '').toString();

      if (!mounted) return;

      // Simulated payment page (assignment-safe; no real gateway).
      final amount = (driverData['monthly_fee'] as num?) ?? 0;
      final driverName = (driverData['name'] ?? 'Driver').toString();
      final paymentResult = await Navigator.of(context).push<PaymentResult>(
        MaterialPageRoute(
          builder: (_) => PaymentPage(
            parentId: widget.parentId,
            driverId: driverId,
            childId: widget.childDoc.id,
            driverName: driverName,
            amount: amount,
          ),
        ),
      );
      if (paymentResult == null) {
        // User cancelled checkout.
        return;
      }
      final paymentId = paymentResult.paymentId;
      final tripType = paymentResult.tripType;

      final reqId = '${widget.parentId}_${widget.childDoc.id}';
      final pickup = _pickupFromChild();

      await _requestService.createServiceRequest(
        driverId: driverId,
        requestId: reqId,
        payload: {
          'status': 'pending',
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
          'parent_id': widget.parentId,
          'parent_name': parentName,
          'parent_phone': parentPhone,
          'student_id': widget.childDoc.id,
          'student_name': (child['child_name'] ?? 'Student').toString(),
          'pickup_location': pickup == null
              ? null
              : {'lat': pickup.latitude, 'lng': pickup.longitude},
          'payment_id': paymentId,
          'amount': amount,
          'trip_type': tripType,
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request sent (Pending approval)')),
      );
    } catch (e) {
      setState(() {
        _error = 'Failed to request: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _renewService(
    BuildContext context,
    String driverId,
    String driverName,
    Map<String, dynamic> driverData,
  ) async {
    if (!mounted) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    // Capture context-dependent objects before async operations
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final parentSnap = await FirebaseFirestore.instance
          .collection('parents')
          .doc(widget.parentId)
          .get();
      final parentData = parentSnap.data() ?? {};
      final parentName =
          (parentData['name'] ??
                  FirebaseAuth.instance.currentUser?.displayName ??
                  'Parent')
              .toString();
      final parentPhone = (parentData['contact_number'] ?? '').toString();

      if (!mounted) return;

      final amount = (driverData['monthly_fee'] as num?) ?? 0;

      final paymentResult = await navigator.push<PaymentResult>(
        MaterialPageRoute(
          builder: (_) => PaymentPage(
            parentId: widget.parentId,
            driverId: driverId,
            childId: widget.childDoc.id,
            driverName: driverName,
            amount: amount,
          ),
        ),
      );

      if (paymentResult == null) {
        return;
      }

      final paymentId = paymentResult.paymentId;
      final tripType = paymentResult.tripType;
      final pickup = _pickupFromChild();

      await _requestService.createServiceRequest(
        driverId: driverId,
        requestId:
            '${widget.parentId}_${widget.childDoc.id}_renewal_${DateTime.now().millisecondsSinceEpoch}',
        payload: {
          'status': 'renewal',
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
          'parent_id': widget.parentId,
          'parent_name': parentName,
          'parent_phone': parentPhone,
          'student_id': widget.childDoc.id,
          'student_name': (widget.childDoc.data()['child_name'] ?? 'Student')
              .toString(),
          'pickup_location': pickup == null
              ? null
              : {'lat': pickup.latitude, 'lng': pickup.longitude},
          'payment_id': paymentId,
          'amount': amount,
          'trip_type': tripType,
        },
      );

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Service renewed successfully')),
      );
    } catch (e) {
      setState(() {
        _error = 'Failed to renew: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.childDoc.data();
    final assignedDriver = (child['assigned_driver_id'] ?? '').toString();

    // For now, the child's pickup point is stored at child.pickup_location.
    // If not set, we still list drivers, but proximity filtering is skipped.
    final pickup = _pickupFromChild();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _discovery.streamSearchableDrivers(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data?.docs ?? const [];
        final visible = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        final childSchoolId = (widget.childDoc.data()['school_id'] as String?);
        for (final d in docs) {
          final data = d.data();
          if (data['is_verified'] != true) continue;

          if (_discovery.isDriverEligibleForPickup(
            driverData: data,
            pickup: pickup,
            childSchoolId: childSchoolId,
          )) {
            visible.add(d);
          }
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (assignedDriver.isNotEmpty)
              StreamBuilder(
                stream: FirebaseFirestore.instance
                    .collection('drivers')
                    .doc(assignedDriver)
                    .snapshots(),
                builder: (context, driverSnap) {
                  final driverData = driverSnap.data?.data() ?? {};
                  final driverName = (driverData['name'] ?? 'Driver')
                      .toString();
                  final driverContact = (driverData['contact_number'] ?? '')
                      .toString();
                  final driverVehicle = (driverData['transport_number'] ?? '')
                      .toString();

                  return StreamBuilder(
                    stream: FirebaseFirestore.instance
                        .collection('payments')
                        .where('parent_id', isEqualTo: widget.parentId)
                        .snapshots(),
                    builder: (context, paySnap) {
                      final docs = (paySnap.data as dynamic)?.docs as List?;
                      if (docs == null) return const SizedBox.shrink();

                      // Filter for this child and driver
                      final filtered = docs.where((d) {
                        final m = (d.data() as Map).cast<String, dynamic>();
                        return (m['child_id'] ?? '').toString() ==
                                widget.childDoc.id &&
                            (m['driver_id'] ?? '').toString() == assignedDriver;
                      }).toList();

                      // Sort by most recent first
                      filtered.sort((a, b) {
                        final ma = (a.data() as Map).cast<String, dynamic>();
                        final mb = (b.data() as Map).cast<String, dynamic>();
                        final ta =
                            (ma['created_at'] as Timestamp?)
                                ?.millisecondsSinceEpoch ??
                            0;
                        final tb =
                            (mb['created_at'] as Timestamp?)
                                ?.millisecondsSinceEpoch ??
                            0;
                        return tb.compareTo(ta);
                      });

                      final latest = filtered.isNotEmpty
                          ? filtered.first
                          : null;
                      final latestData =
                          latest?.data() as Map<String, dynamic>?;
                      final status = (latestData?['status'] ?? 'pending')
                          .toString();
                      final createdAt =
                          (latestData?['created_at'] as Timestamp?)?.toDate();

                      // Calculate due date: 1st of next month
                      DateTime? dueDate;
                      if (createdAt != null) {
                        final nextMonth = createdAt.month == 12
                            ? DateTime(createdAt.year + 1, 1, 1)
                            : DateTime(createdAt.year, createdAt.month + 1, 1);
                        dueDate = nextMonth;
                      }

                      int? daysLeft;
                      String? dueText;
                      if (dueDate != null) {
                        final now = DateTime.now();
                        final today = DateTime(now.year, now.month, now.day);
                        daysLeft = dueDate.difference(today).inDays;
                        dueText =
                            '${dueDate.year.toString().padLeft(4, '0')}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}';
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          border: Border.all(color: Colors.blue.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Assigned Driver',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              color: Colors.blue.shade900,
                                            ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        driverName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (daysLeft != null && daysLeft <= 7)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: daysLeft <= 2
                                          ? Colors.red.shade100
                                          : Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      daysLeft <= 0
                                          ? 'Expired'
                                          : '$daysLeft days',
                                      style: TextStyle(
                                        color: daysLeft <= 2
                                            ? Colors.red.shade700
                                            : Colors.orange.shade700,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (driverContact.isNotEmpty)
                              Text('Contact: $driverContact'),
                            if (driverVehicle.isNotEmpty)
                              Text('Vehicle: $driverVehicle'),
                            const SizedBox(height: 12),
                            Text(
                              'Payment Status: $status',
                              style: TextStyle(
                                color: status == 'completed'
                                    ? Colors.green.shade700
                                    : Colors.orange.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (dueText != null) const SizedBox.shrink(),
                            FutureBuilder<
                              DocumentSnapshot<Map<String, dynamic>>
                            >(
                              future: FirebaseFirestore.instance
                                  .collection('parents')
                                  .doc(widget.parentId)
                                  .collection('children')
                                  .doc(widget.childDoc.id)
                                  .get(),
                              builder: (context, childSnap) {
                                if (!childSnap.hasData) {
                                  return const SizedBox.shrink();
                                }
                                final childData = childSnap.data?.data() ?? {};
                                final serviceEndDate =
                                    (childData['service_end_date']
                                            as Timestamp?)
                                        ?.toDate();
                                if (serviceEndDate == null) {
                                  return const SizedBox.shrink();
                                }
                                final serviceEndText =
                                    '${serviceEndDate.year.toString().padLeft(4, '0')}-${serviceEndDate.month.toString().padLeft(2, '0')}-${serviceEndDate.day.toString().padLeft(2, '0')}';
                                final now = DateTime.now();
                                final today = DateTime(
                                  now.year,
                                  now.month,
                                  now.day,
                                );
                                final daysUntilExpiry = serviceEndDate
                                    .difference(today)
                                    .inDays;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    'Service ends: $serviceEndText',
                                    style: TextStyle(
                                      color:
                                          daysUntilExpiry <= 7 &&
                                              daysUntilExpiry > 0
                                          ? Colors.orange
                                          : daysUntilExpiry <= 0
                                          ? Colors.red
                                          : Colors.black87,
                                      fontWeight: daysUntilExpiry <= 7
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _submitting
                                    ? null
                                    : () => _renewService(
                                        context,
                                        assignedDriver,
                                        driverName,
                                        driverData,
                                      ),
                                icon: const Icon(Icons.refresh),
                                label: const Text('Renew Service'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              'Available drivers',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (visible.isEmpty) const Text('No drivers found for this child.'),
            for (final d in visible) ...[
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (d.data()['name'] ?? 'Driver').toString(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Contact: ${(d.data()["contact_number"] ?? "").toString()}',
                      ),
                      Text(
                        'Vehicle: ${(d.data()["transport_number"] ?? "").toString()}',
                      ),
                      Text(
                        'Monthly fee: ${(d.data()["monthly_fee"] ?? "N/A").toString()}',
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submitting
                              ? null
                              : () => _requestDriver(
                                  driverId: d.id,
                                  driverData: d.data(),
                                ),
                          child: _submitting
                              ? const CircularProgressIndicator()
                              : const Text('Request Driver'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
