import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/pages/subscription_form_page.dart';
import 'package:eharvest_mobile/services/subscription_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

class SubscriptionDetailPage extends StatefulWidget {
  final int subscriptionId;
  final String roleKey;

  const SubscriptionDetailPage({
    super.key,
    required this.subscriptionId,
    required this.roleKey,
  });

  @override
  State<SubscriptionDetailPage> createState() => _SubscriptionDetailPageState();
}

class _SubscriptionDetailPageState extends State<SubscriptionDetailPage> {
  ProduceSubscription? _subscription;
  bool _loading = true;
  String? _error;
  bool _changed = false;
  bool _mutating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final subscription = await SubscriptionService.fetchSubscription(
        widget.subscriptionId,
      );
      if (!mounted) return;
      setState(() {
        _subscription = subscription;
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

  Future<void> _runAction(
    Future<ProduceSubscription> Function(int id) action,
    String label,
  ) async {
    final subscription = _subscription;
    if (subscription == null) return;
    setState(() {
      _mutating = true;
      _error = null;
    });
    try {
      final updated = await action(subscription.id);
      if (!mounted) return;
      setState(() {
        _subscription = updated;
        _changed = true;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Subscription $label.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  String _date(DateTime date) {
    return intl.DateFormat('yyyy-MM-dd HH:mm').format(date.toLocal());
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return Colors.green;
      case 'PAUSED':
        return Colors.orange;
      case 'CANCELLED':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, __) {
        Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Subscription Details')),
        body: _body(),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _subscription == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    final subscription = _subscription!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Subscription #${subscription.id}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Chip(
              label: Text(subscription.status),
              backgroundColor: _statusColor(subscription.status),
              labelStyle: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _detailCard(
          children: [
            _row('Buyer', subscription.buyerName),
            _row('Farmer', subscription.farmerName),
            _row('Frequency', subscription.frequency),
            _row('Currency', subscription.currency),
            _row('Start date', _date(subscription.startDate)),
            _row('Next delivery', _date(subscription.nextDeliveryDate)),
            _row(
              'Logistics',
              subscription.requiresLogistics ? 'Required' : 'Pickup',
            ),
            if (!subscription.requiresLogistics)
              _row('Pickup address', subscription.pickupAddress ?? '-'),
          ],
        ),
        const SizedBox(height: 12),
        _detailCard(
          children: [
            const Text(
              'Items',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ...subscription.items.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Produce #${item.produceId}'),
                subtitle: Text('Quantity: ${item.quantity}'),
                trailing: Text(
                  '${subscription.currency} '
                  '${item.unitPrice.toStringAsFixed(2)}',
                ),
              ),
            ),
            const Divider(),
            _row(
              'Total',
              '${subscription.currency} '
                  '${subscription.totalAmount.toStringAsFixed(2)}',
              bold: true,
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 16),
        _actions(subscription),
      ],
    );
  }

  Widget _detailCard({required List<Widget> children}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions(ProduceSubscription subscription) {
    final status = subscription.status.toUpperCase();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit'),
          onPressed: _mutating || status == 'CANCELLED'
              ? null
              : () async {
                  final changed = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          SubscriptionFormPage(subscription: subscription),
                    ),
                  );
                  if (changed == true) {
                    _changed = true;
                    _load();
                  }
                },
        ),
        if (status == 'ACTIVE')
          OutlinedButton.icon(
            icon: const Icon(Icons.pause_circle_outline),
            label: const Text('Pause'),
            onPressed: _mutating
                ? null
                : () => _runAction(
                    SubscriptionService.pauseSubscription,
                    'paused',
                  ),
          ),
        if (status == 'PAUSED')
          OutlinedButton.icon(
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('Resume'),
            onPressed: _mutating
                ? null
                : () => _runAction(
                    SubscriptionService.resumeSubscription,
                    'resumed',
                  ),
          ),
        if (status != 'CANCELLED')
          OutlinedButton.icon(
            icon: const Icon(Icons.cancel_outlined, color: Colors.red),
            label: const Text('Cancel', style: TextStyle(color: Colors.red)),
            onPressed: _mutating
                ? null
                : () => _runAction(
                    SubscriptionService.cancelSubscription,
                    'cancelled',
                  ),
          ),
        ElevatedButton.icon(
          icon: _mutating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.bolt_outlined),
          label: const Text('Process Cycle'),
          onPressed: _mutating
              ? null
              : () => _runAction(
                  SubscriptionService.processSubscription,
                  'processed',
                ),
        ),
      ],
    );
  }
}
