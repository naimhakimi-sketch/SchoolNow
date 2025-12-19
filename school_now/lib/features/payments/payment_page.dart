import 'package:flutter/material.dart';

import '../../services/request_payment_service.dart';

class PaymentResult {
  final String paymentId;
  final num amount;

  const PaymentResult({
    required this.paymentId,
    required this.amount,
  });
}

class PaymentPage extends StatefulWidget {
  final String parentId;
  final String driverId;
  final String childId;
  final String driverName;
  final num amount;

  const PaymentPage({
    super.key,
    required this.parentId,
    required this.driverId,
    required this.childId,
    required this.driverName,
    required this.amount,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  final _service = RequestPaymentService();

  final _nameOnCard = TextEditingController();
  final _cardNumber = TextEditingController();
  final _expiry = TextEditingController();
  final _cvv = TextEditingController();

  String _method = 'Card';
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameOnCard.dispose();
    _cardNumber.dispose();
    _expiry.dispose();
    _cvv.dispose();
    super.dispose();
  }

  String _digitsOnly(String s) => s.replaceAll(RegExp(r'\D'), '');

  Future<void> _pay() async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (widget.amount <= 0) throw Exception('Invalid amount');

      // Lightweight validation (fake page).
      if (_method == 'Card') {
        final cardDigits = _digitsOnly(_cardNumber.text);
        if (_nameOnCard.text.trim().isEmpty) throw Exception('Name on card is required');
        if (cardDigits.length < 12) throw Exception('Card number looks too short');
        if (_expiry.text.trim().isEmpty) throw Exception('Expiry is required');
        if (_digitsOnly(_cvv.text).length < 3) throw Exception('CVV looks too short');
      }

      final cardDigits = _digitsOnly(_cardNumber.text);
      final last4 = cardDigits.length >= 4 ? cardDigits.substring(cardDigits.length - 4) : '';

      final paymentId = await _service.createPayment(
        parentId: widget.parentId,
        driverId: widget.driverId,
        childId: widget.childId,
        amount: widget.amount,
        metadata: {
          'method': _method,
          if (_method == 'Card') 'card_last4': last4,
          if (_method == 'Card') 'name_on_card': _nameOnCard.text.trim(),
        },
      );

      if (!mounted) return;
      Navigator.of(context).pop(PaymentResult(paymentId: paymentId, amount: widget.amount));
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Driver', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(widget.driverName.isEmpty ? widget.driverId : widget.driverName),
                  const SizedBox(height: 12),
                  Text('Amount', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(widget.amount.toString()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey(_method),
            initialValue: _method,
            decoration: const InputDecoration(labelText: 'Payment method'),
            items: const [
              DropdownMenuItem(value: 'Card', child: Text('Card (Visa/Master)')),
              DropdownMenuItem(value: 'FPX', child: Text('FPX (Online Banking)')),
              DropdownMenuItem(value: 'Cash', child: Text('Cash (record only)')),
            ],
            onChanged: _loading
                ? null
                : (v) {
                    if (v == null) return;
                    setState(() {
                      _method = v;
                    });
                  },
          ),
          const SizedBox(height: 12),
          if (_method == 'Card') ...[
            TextField(
              controller: _nameOnCard,
              decoration: const InputDecoration(labelText: 'Name on card'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cardNumber,
              decoration: const InputDecoration(labelText: 'Card number'),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _expiry,
                    decoration: const InputDecoration(labelText: 'Expiry (MM/YY)'),
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _cvv,
                    decoration: const InputDecoration(labelText: 'CVV'),
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                  ),
                ),
              ],
            ),
          ] else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _method == 'FPX'
                      ? 'This is a simulation page. Tap Pay to create a "Pending" payment record.'
                      : 'This will create a payment record only (no gateway).',
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (_error != null) Text(_error!, style: TextStyle(color: Colors.red.shade700)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _pay,
              child: _loading ? const CircularProgressIndicator() : const Text('Pay'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _loading ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }
}
