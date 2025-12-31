import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/payment_service.dart';

class ManagePaymentsScreen extends StatefulWidget {
  const ManagePaymentsScreen({super.key});

  @override
  State<ManagePaymentsScreen> createState() => _ManagePaymentsScreenState();
}

class _ManagePaymentsScreenState extends State<ManagePaymentsScreen> {
  final service = PaymentService();
  String selectedFilter = 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(title: const Text('Manage Payments'), centerTitle: true),
      body: Column(
        children: [
          // Statistics Card
          FutureBuilder<Map<String, dynamic>>(
            future: service.getPaymentStatistics(),
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
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
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
                      'Payment Statistics',
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
                        _statItem('Completed', stats['completed'].toString()),
                        _statItem('Refunded', stats['refunded'].toString()),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 8),
                    Text(
                      'Total Revenue: RM ${stats['completedAmount'].toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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
                _filterChip('Completed', 'completed'),
                const SizedBox(width: 8),
                _filterChip('Refunded', 'refunded'),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Payments List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: selectedFilter == 'all'
                  ? service.getPayments()
                  : service.getPaymentsByStatus(selectedFilter),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No payments found',
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    return _paymentCard(doc.id, data);
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

  Widget _paymentCard(String paymentId, Map<String, dynamic> data) {
    final status = data['status'] ?? 'unknown';
    final amount = (data['amount'] as num?)?.toDouble() ?? 0;
    final parentId = data['parent_id'] ?? '';
    final driverId = data['driver_id'] ?? '';
    final createdAt = (data['created_at'] as Timestamp?)?.toDate();

    Color statusColor;
    switch (status) {
      case 'completed':
        statusColor = Colors.green;
        break;
      case 'pending':
        statusColor = Colors.orange;
        break;
      case 'refunded':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.grey;
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
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.1),
          child: Icon(Icons.payment, color: statusColor),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'RM ${amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            FutureBuilder<String>(
              future: service.getParentName(parentId),
              builder: (context, snapshot) {
                return Text('Parent: ${snapshot.data ?? 'Loading...'}');
              },
            ),
            FutureBuilder<String>(
              future: service.getDriverName(driverId),
              builder: (context, snapshot) {
                return Text('Driver: ${snapshot.data ?? 'Loading...'}');
              },
            ),
            if (createdAt != null)
              Text(
                'Date: ${DateFormat('dd MMM yyyy, HH:mm').format(createdAt)}',
                style: const TextStyle(fontSize: 12, color: Colors.black45),
              ),
          ],
        ),
        trailing: status == 'pending'
            ? PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  _updatePaymentStatus(paymentId, value);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'completed',
                    child: Text('Mark as Completed'),
                  ),
                  const PopupMenuItem(
                    value: 'refunded',
                    child: Text('Mark as Refunded'),
                  ),
                ],
              )
            : null,
        isThreeLine: true,
      ),
    );
  }

  void _updatePaymentStatus(String paymentId, String newStatus) async {
    await service.updatePaymentStatus(paymentId, newStatus);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment status updated to $newStatus')),
      );
    }
  }
}
