import 'package:eharvest_mobile/pages/subscription_detail_page.dart';
import 'package:eharvest_mobile/services/auth_service.dart';
import 'package:eharvest_mobile/services/subscription_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

class SubscriptionsPage extends StatefulWidget {
  const SubscriptionsPage({super.key});

  @override
  State<SubscriptionsPage> createState() => _SubscriptionsPageState();
}

class _SubscriptionsPageState extends State<SubscriptionsPage> {
  List<ProduceSubscription> _subscriptions = [];
  bool _loading = true;
  String? _error;
  String _roleKey = '';
  int? _mutatingId;

  @override
  void initState() {
    super.initState();
    _loadSubscriptions();
  }

  String _normalizeRoleKey(String rawRole) {
    final normalized = rawRole.trim().toLowerCase().replaceAll(
      RegExp(r'[\s-]+'),
      '_',
    );
    final baseRole = normalized.startsWith('role_')
        ? normalized.substring('role_'.length)
        : normalized;
    return baseRole == 'farmer' ? 'farmer' : baseRole == 'buyer' ? 'buyer' : baseRole;
  }

  Future<void> _loadSubscriptions() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final userId = await AuthService.getUserId();
      final role = await AuthService.getRole();
      if (userId == null) throw Exception('Could not find your account.');
      final roleKey = _normalizeRoleKey(role ?? '');
      final subscriptions = roleKey == 'farmer'
          ? await SubscriptionService.fetchFarmerSubscriptions(userId)
          : await SubscriptionService.fetchBuyerSubscriptions(userId);
      if (!mounted) return;
      setState(() {
        _roleKey = roleKey;
        _subscriptions = subscriptions;
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
    ProduceSubscription subscription,
    Future<ProduceSubscription> Function(int id) action,
    String label,
  ) async {
    setState(() {
      _mutatingId = subscription.id;
      _error = null;
    });
    try {
      await action(subscription.id);
      await _loadSubscriptions();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Subscription $label.')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _mutatingId = null);
      }
    }
  }

  String _formatDate(DateTime date) {
    return intl.DateFormat('yyyy-MM-dd').format(date.toLocal());
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
    return Scaffold(appBar: AppBar(title: const Text('Subscriptions')), body: _body());
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
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
              OutlinedButton(
                onPressed: _loadSubscriptions,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_subscriptions.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadSubscriptions,
        child: ListView(
          children: const [
            SizedBox(height: 240),
            Center(child: Text('No subscriptions found.')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadSubscriptions,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _subscriptions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _card(_subscriptions[index]),
      ),
    );
  }

  Widget _card(ProduceSubscription subscription) {
    final isMutating = _mutatingId == subscription.id;
    final otherName = _roleKey == 'farmer'
        ? subscription.buyerName
        : subscription.farmerName;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () async {
          final changed = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => SubscriptionDetailPage(
                subscriptionId: subscription.id,
                roleKey: _roleKey,
              ),
            ),
          );
          if (changed == true) _loadSubscriptions();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Subscription #${subscription.id}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
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
              const SizedBox(height: 8),
              Text('${_roleKey == 'farmer' ? 'Buyer' : 'Farmer'}: $otherName'),
              Text('Frequency: ${subscription.frequency}'),
              Text('Next delivery: ${_formatDate(subscription.nextDeliveryDate)}'),
              Text(
                'Total: ${subscription.currency} '
                '${subscription.totalAmount.toStringAsFixed(2)}',
              ),
              const SizedBox(height: 8),
              _actions(subscription, isMutating),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actions(ProduceSubscription subscription, bool isMutating) {
    final status = subscription.status.toUpperCase();
    if (status == 'CANCELLED') return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      alignment: WrapAlignment.end,
      children: [
        if (status == 'ACTIVE')
          TextButton.icon(
            icon: const Icon(Icons.pause_circle_outline),
            label: const Text('Pause'),
            onPressed: isMutating
                ? null
                : () => _runAction(
                    subscription,
                    SubscriptionService.pauseSubscription,
                    'paused',
                  ),
          ),
        if (status == 'PAUSED')
          TextButton.icon(
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('Resume'),
            onPressed: isMutating
                ? null
                : () => _runAction(
                    subscription,
                    SubscriptionService.resumeSubscription,
                    'resumed',
                  ),
          ),
        TextButton.icon(
          icon: const Icon(Icons.cancel_outlined, color: Colors.red),
          label: const Text('Cancel', style: TextStyle(color: Colors.red)),
          onPressed: isMutating
              ? null
              : () => _runAction(
                  subscription,
                  SubscriptionService.cancelSubscription,
                  'cancelled',
                ),
        ),
        if (isMutating)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }
}
