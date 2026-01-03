import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/service_request_service.dart';

class ManageServiceRequestsScreen extends StatefulWidget {
  const ManageServiceRequestsScreen({super.key});

  @override
  State<ManageServiceRequestsScreen> createState() =>
      _ManageServiceRequestsScreenState();
}

class _ManageServiceRequestsScreenState
    extends State<ManageServiceRequestsScreen> {
  final service = ServiceRequestService();
  String selectedFilter = 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(title: const Text('Service Requests'), centerTitle: true),
      body: Column(
        children: [
          // Statistics Card
          FutureBuilder<Map<String, int>>(
            future: service.getRequestStatistics(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final stats = snapshot.data!;
              return Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFf093fb), Color(0xFFf5576c)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'Request Statistics',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _statItem('Total', stats['total'].toString()),
                        _statItem('Pending', stats['pending'].toString()),
                        _statItem('Renewal', stats['renewal'].toString()),
                        _statItem('Approved', stats['approved'].toString()),
                        _statItem('Rejected', stats['rejected'].toString()),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          // Filter Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _filterChip('All', 'all'),
                const SizedBox(width: 8),
                _filterChip('Pending', 'pending'),
                const SizedBox(width: 8),
                _filterChip('Renewal', 'renewal'),
                const SizedBox(width: 8),
                _filterChip('Approved', 'approved'),
                const SizedBox(width: 8),
                _filterChip('Rejected', 'rejected'),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Requests List
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: selectedFilter == 'all'
                  ? service.getAllServiceRequests()
                  : service.getServiceRequestsByStatus(selectedFilter),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final requests = snapshot.data!;

                if (requests.isEmpty) {
                  return const Center(
                    child: Text(
                      'No service requests found',
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                  );
                }

                // Sort by created_at descending
                requests.sort((a, b) {
                  final aTime =
                      (a['created_at'] as Timestamp?)?.millisecondsSinceEpoch ??
                      0;
                  final bTime =
                      (b['created_at'] as Timestamp?)?.millisecondsSinceEpoch ??
                      0;
                  return bTime.compareTo(aTime);
                });

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final request = requests[index];
                    return _requestCard(request);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = selectedFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            selectedFilter = value;
          });
        }
      },
    );
  }

  Widget _requestCard(Map<String, dynamic> data) {
    final status = data['status'] ?? 'unknown';
    final studentName = data['student_name'] ?? 'Unknown Student';
    final parentName = data['parent_name'] ?? 'Unknown Parent';
    final driverId = data['driver_id'] ?? '';
    final requestId = data['id'] ?? '';
    final amount = (data['amount'] as num?)?.toDouble() ?? 0;
    final tripType = (data['trip_type'] ?? 'both').toString();
    final createdAt = (data['created_at'] as Timestamp?)?.toDate();

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      case 'renewal':
        statusColor = Colors.blue;
        statusIcon = Icons.refresh;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.1),
          child: Icon(statusIcon, color: statusColor),
        ),
        title: Text(
          studentName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Parent: $parentName'),
            if (amount > 0) Text('Amount: RM ${amount.toStringAsFixed(2)}'),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow('Student ID', data['student_id'] ?? 'N/A'),
                _detailRow('Contact Number', data['contact_number'] ?? 'N/A'),
                FutureBuilder<String>(
                  future: service.getDriverName(driverId),
                  builder: (context, snapshot) {
                    return _detailRow('Driver', snapshot.data ?? 'Loading...');
                  },
                ),
                _detailRow('Trip Type', _tripTypeLabel(tripType)),
                if (createdAt != null)
                  _detailRow(
                    'Created At',
                    DateFormat('dd MMM yyyy, HH:mm').format(createdAt),
                  ),
                if (data['pickup_location'] != null) ...[
                  const Divider(height: 24),
                  const Text(
                    'Pickup Location:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Lat: ${data['pickup_location']['lat']}, Lng: ${data['pickup_location']['lng']}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
                if (status == 'pending' || status == 'renewal') ...[
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          icon: const Icon(Icons.close),
                          label: const Text('Reject'),
                          onPressed: () =>
                              _updateStatus(driverId, requestId, 'rejected'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.check),
                          label: const Text('Approve'),
                          onPressed: () =>
                              _updateStatus(driverId, requestId, 'approved'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.black54)),
          ),
        ],
      ),
    );
  }

  void _updateStatus(
    String driverId,
    String requestId,
    String newStatus,
  ) async {
    try {
      await service.updateRequestStatus(driverId, requestId, newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request $newStatus successfully'),
            backgroundColor: newStatus == 'approved'
                ? Colors.green
                : Colors.red,
          ),
        );
      }
    } catch (e) {
      // Extract the real error from wrapped exceptions
      String errorMessage = 'Unknown error occurred';

      // Debug: Log the raw error
      debugPrint('Raw error: $e');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Error toString: ${e.toString()}');

      if (e.toString().contains('converted Future')) {
        // Try to get the actual error details from different properties
        try {
          // Try different ways to access the wrapped error
          dynamic realError = e;

          // Check if it's a wrapped error with an 'error' property
          if (realError is Error && (realError as dynamic).error != null) {
            realError = (realError as dynamic).error;
          }

          // If it's still wrapped, try to get the original error
          while (realError != null &&
              realError.toString().contains('converted Future')) {
            if (realError is Error && (realError as dynamic).error != null) {
              realError = (realError as dynamic).error;
            } else {
              break;
            }
          }

          errorMessage = realError?.toString() ?? 'Firebase operation failed';

          // If it's still generic, try to get more specific info
          if (errorMessage.contains('converted Future')) {
            errorMessage =
                'Firebase operation failed - check network connection and permissions';
          }
        } catch (unwrapError) {
          debugPrint('Error unwrapping failed: $unwrapError');
          errorMessage = 'Firebase operation failed';
        }
      } else {
        errorMessage = e.toString();
      }

      debugPrint('Final error message: $errorMessage');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $errorMessage'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _tripTypeLabel(String tripType) {
    return switch (tripType) {
      'going' => 'Going Only (Morning)',
      'return' => 'Return Only (Afternoon)',
      'both' => 'Both (Going & Return)',
      _ => 'Unknown',
    };
  }
}
