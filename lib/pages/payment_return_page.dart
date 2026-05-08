import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/services/payment_service.dart';
import 'package:flutter/material.dart';

class PaymentReturnPage extends StatefulWidget {
  const PaymentReturnPage({super.key});

  @override
  State<PaymentReturnPage> createState() => _PaymentReturnPageState();
}

class _PaymentReturnPageState extends State<PaymentReturnPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading && _result == null && _error == null) {
      _loadPaymentReturn();
    }
  }

  Future<void> _loadPaymentReturn() async {
    final reference = Uri.base.queryParameters['reference'] ??
        ModalRoute.of(context)?.settings.arguments?.toString();
    if (reference == null || reference.trim().isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Payment reference is missing.';
      });
      return;
    }

    try {
      final result = await PaymentService.getPaymentReturn(reference.trim());
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  bool get _isSuccess {
    final status = (_result?['status'] ?? '').toString().toLowerCase();
    return status.contains('paid') ||
        status.contains('success') ||
        status.contains('complete');
  }

  bool get _isPending {
    final status = (_result?['status'] ?? '').toString().toLowerCase();
    return status.contains('pending') || status.contains('await');
  }

  @override
  Widget build(BuildContext context) {
    final status = (_result?['status'] ?? 'Unknown').toString();
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Status')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _loading
              ? const CircularProgressIndicator()
              : _error != null
                  ? _StatusCard(
                      icon: Icons.error_outline,
                      color: Colors.red,
                      title: 'Could not verify payment',
                      message: _error!,
                      action: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _loading = true;
                            _error = null;
                          });
                          _loadPaymentReturn();
                        },
                        child: const Text('Retry'),
                      ),
                    )
                  : _StatusCard(
                      icon: _isSuccess
                          ? Icons.check_circle_outline
                          : Icons.hourglass_top,
                      color: _isSuccess
                          ? Color(primaryColour)
                          : (_isPending ? Colors.orange : Colors.blueGrey),
                      title: 'Transaction $status',
                      message: _isSuccess
                          ? 'Your wallet will reflect the backend-confirmed balance shortly.'
                          : _isPending
                              ? 'Payment is still pending. You can refresh this page or check your wallet again in a moment.'
                              : 'The transaction is not complete yet.',
                      action: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            '/tabs',
                            (route) => false,
                          );
                        },
                        child: const Text('Back to account'),
                      ),
                    ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final Widget action;

  const _StatusCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: color),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 20),
            action,
          ],
        ),
      ),
    );
  }
}
