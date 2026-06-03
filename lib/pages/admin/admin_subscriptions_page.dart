import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/pages/admin/admin_shared.dart';
import 'package:eharvest_mobile/services/admin_service.dart';
import 'package:eharvest_mobile/services/subscription_service.dart';
import 'package:flutter/material.dart';

class AdminSubscriptionsPage extends StatefulWidget {
  const AdminSubscriptionsPage({super.key});

  @override
  State<AdminSubscriptionsPage> createState() => _AdminSubscriptionsPageState();
}

class _AdminSubscriptionsPageState extends State<AdminSubscriptionsPage> {
  bool _loading = false;
  String? _error;
  List<ProduceSubscription> _items = [];
  final TextEditingController _buyerIdController = TextEditingController();
  final TextEditingController _farmerIdController = TextEditingController();
  _SubscriptionLookupMode _mode = _SubscriptionLookupMode.buyer;

  @override
  void dispose() {
    _buyerIdController.dispose();
    _farmerIdController.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final idText = _mode == _SubscriptionLookupMode.buyer
        ? _buyerIdController.text.trim()
        : _farmerIdController.text.trim();
    final id = int.tryParse(idText);
    if (id == null || id <= 0) {
      showAdminSnackBar(context, 'Enter a valid ID');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _items = [];
    });

    try {
      final items = _mode == _SubscriptionLookupMode.buyer
          ? await AdminService.fetchSubscriptionsByBuyer(id)
          : await AdminService.fetchSubscriptionsByFarmer(id);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _fetchById() async {
    final form = await showAdminFormDialog(
      context,
      title: 'Fetch Subscription',
      fields: const [
        AdminFormField(key: 'id', label: 'Subscription ID', keyboardType: TextInputType.number),
      ],
    );
    if (form == null) return;

    final id = int.tryParse(form['id'] ?? '');
    if (id == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final item = await AdminService.fetchSubscription(id);
      if (!mounted) return;
      setState(() {
        _items = [item];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _cancel(ProduceSubscription item) async {
    final confirmed = await confirmAdminAction(
      context,
      title: 'Cancel subscription?',
      message: 'Cancel subscription #${item.id}?',
      confirmLabel: 'Cancel subscription',
    );
    if (!confirmed) return;

    try {
      await AdminService.cancelSubscription(item.id);
      if (!mounted) return;
      showAdminSnackBar(context, 'Subscription cancelled');
      _lookup();
    } catch (e) {
      if (!mounted) return;
      showAdminSnackBar(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showDetails(ProduceSubscription item) {
    showAdminDetailsDialog(
      context,
      title: 'Subscription #${item.id}',
      rows: [
        ('Status', item.status),
        ('Frequency', item.frequency),
        ('Buyer', item.buyerName),
        ('Farmer', item.farmerName),
        ('Currency', item.currency),
        ('Total', item.totalAmount.toStringAsFixed(2)),
        ('Start', formatAdminDate(item.startDate)),
        ('Next delivery', formatAdminDate(item.nextDeliveryDate)),
        ('Requires logistics', item.requiresLogistics ? 'Yes' : 'No'),
        ('Items', item.items.length.toString()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Subscriptions',
      actions: [
        IconButton(
          tooltip: 'Fetch by subscription ID',
          onPressed: _fetchById,
          icon: const Icon(Icons.search),
        ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<_SubscriptionLookupMode>(
                  segments: const [
                    ButtonSegment(
                      value: _SubscriptionLookupMode.buyer,
                      label: Text('By buyer'),
                    ),
                    ButtonSegment(
                      value: _SubscriptionLookupMode.farmer,
                      label: Text('By farmer'),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (selection) {
                    setState(() => _mode = selection.first);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _mode == _SubscriptionLookupMode.buyer
                      ? _buyerIdController
                      : _farmerIdController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _mode == _SubscriptionLookupMode.buyer
                        ? 'Buyer ID'
                        : 'Farmer ID',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _loading ? null : _lookup,
                  icon: const Icon(Icons.search),
                  label: const Text('Search subscriptions'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Color(primaryColour),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AdminLoadingBody();
    if (_error != null) {
      return AdminErrorBody(message: _error!, onRetry: _lookup);
    }
    if (_items.isEmpty) {
      return const AdminEmptyBody(
        message: 'Search by buyer or farmer ID to view subscriptions.',
        icon: Icons.repeat,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _items[index];
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            title: Text('Subscription #${item.id}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${item.status} · ${item.frequency} · ${item.currency} ${item.totalAmount.toStringAsFixed(2)}'),
            onTap: () => _showDetails(item),
            trailing: item.status.toUpperCase() == 'CANCELLED'
                ? null
                : IconButton(
                    tooltip: 'Cancel',
                    icon: const Icon(Icons.cancel_outlined, color: Colors.orange),
                    onPressed: () => _cancel(item),
                  ),
          ),
        );
      },
    );
  }
}

enum _SubscriptionLookupMode { buyer, farmer }
