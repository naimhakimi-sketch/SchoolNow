import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/boarding_status.dart';
import '../../services/trip_read_service.dart';

class StudentPage extends StatefulWidget {
  final String parentId;
  final QueryDocumentSnapshot<Map<String, dynamic>> childDoc;

  const StudentPage({
    super.key,
    required this.parentId,
    required this.childDoc,
  });

  @override
  State<StudentPage> createState() => _StudentPageState();
}

class _StudentPageState extends State<StudentPage> {
  final _trips = TripReadService();
  bool _scanning = false;
  String? _error;

  String _formatScanError(Object error) {
    if (error is FirebaseException) {
      final msg = (error.message == null || error.message!.trim().isEmpty)
          ? 'No message'
          : error.message!.trim();
      return '[${error.plugin}/${error.code}] $msg';
    }
    return error.toString();
  }

  void _validateTripIdFromQr(String tripId) {
    final v = tripId.trim();
    if (v.isEmpty) {
      throw const FormatException('Invalid QR: empty trip id');
    }
    // A Firestore document id cannot contain '/'.
    // If a URL or path was encoded, this prevents opaque native errors.
    if (v.contains('/')) {
      throw const FormatException(
        'Invalid QR: expected a trip id (not a path or URL)',
      );
    }
  }

  Future<void> _handleScan(String tripId) async {
    setState(() {
      _error = null;
    });

    try {
      _validateTripIdFromQr(tripId);

      // Decide the next status based on the current passenger status.
      final snap = await FirebaseFirestore.instance
          .collection('trips')
          .doc(tripId)
          .get();
      final trip = snap.data();
      if (trip == null) throw Exception('Trip not found');

      final passengers = (trip['passengers'] as List?)?.cast<Map>() ?? <Map>[];
      final me = passengers
          .map((e) => e.cast<String, dynamic>())
          .firstWhere(
            (x) => (x['student_id'] ?? '').toString() == widget.childDoc.id,
            orElse: () => const <String, dynamic>{},
          );

      final current = BoardingStatusCodec.fromJson(
        (me['status'] ?? 'not_boarded').toString(),
      );

      // Simple scan progression: not_boarded -> boarded -> alighted.
      final next = switch (current) {
        BoardingStatus.notBoarded => BoardingStatus.boarded,
        BoardingStatus.boarded => BoardingStatus.alighted,
        BoardingStatus.alighted => BoardingStatus.alighted,
        BoardingStatus.absent => BoardingStatus.absent,
      };

      await _trips.updatePassengerStatus(
        tripId: tripId,
        studentId: widget.childDoc.id,
        status: BoardingStatusCodec.toJson(next),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Updated status: ${BoardingStatusCodec.toJson(next)}'),
        ),
      );

      setState(() {
        _scanning = false;
      });
    } catch (e, st) {
      debugPrint(
        'Student QR scan failed. tripId=$tripId studentId=${widget.childDoc.id}',
      );
      debugPrint('Error: $e');
      debugPrintStack(stackTrace: st);
      setState(() {
        _error = 'Scan failed: ${_formatScanError(e)}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.childDoc.data();
    final childName = (child['child_name'] ?? 'Student').toString();

    // Personal QR for driver to scan (SRS FR-ST-2.2).
    final personalQrPayload = widget.childDoc.id;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Student: $childName',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Text(
          'My QR (show to driver):',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Center(child: QrImageView(data: personalQrPayload, size: 180)),
        const SizedBox(height: 24),
        Text(
          'Scan Driver Session QR to update boarding status:',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => setState(() => _scanning = true),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan Driver QR'),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: Colors.red.shade700)),
        ],
        if (_scanning) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 320,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: MobileScanner(
                onDetect: (capture) {
                  final barcodes = capture.barcodes;
                  if (barcodes.isEmpty) return;
                  final raw = barcodes.first.rawValue;
                  if (raw == null || raw.trim().isEmpty) return;
                  // Driver app session QR encodes tripId.
                  _handleScan(raw.trim());
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => setState(() => _scanning = false),
            child: const Text('Cancel'),
          ),
        ],
      ],
    );
  }
}
