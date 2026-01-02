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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Assigned driver: $assignedDriver'),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
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
