import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/pages/admin/admin_shared.dart';
import 'package:eharvest_mobile/services/admin_service.dart';
import 'package:flutter/material.dart';

class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {
  bool _loading = true;
  String? _error;
  List<Order> _items = [];

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
      final items = await AdminService.fetchOrders();
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

  Future<void> _delete(Order item) async {
    final confirmed = await confirmAdminAction(
      context,
      title: 'Delete order?',
      message: 'Delete order #${item.id}?',
    );
    if (!confirmed) return;

    try {
      await AdminService.deleteOrder(item.id);
      if (!mounted) return;
      showAdminSnackBar(context, 'Order deleted');
      _load();
    } catch (e) {
      if (!mounted) return;
      showAdminSnackBar(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showDetails(Order item) {
    showAdminDetailsDialog(
      context,
      title: 'Order #${item.id}',
      rows: [
        ('Status', item.status),
        ('Date', formatAdminDate(item.orderDate)),
        ('Total', '${item.currency} ${item.totalAmount.toStringAsFixed(2)}'),
        ('Escrow', item.escrowAmount.toStringAsFixed(2)),
        ('Buyer', item.buyer?.displayName ?? 'N/A'),
        ('Farmer', item.farmer?.displayName ?? 'N/A'),
        ('Logistics type', item.logisticsType),
        ('Escrow held', item.escrowHeld ? 'Yes' : 'No'),
        ('Escrow released', item.escrowReleased ? 'Yes' : 'No'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Orders',
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AdminLoadingBody();
    if (_error != null) return AdminErrorBody(message: _error!, onRetry: _load);
    if (_items.isEmpty) return const AdminEmptyBody(message: 'No orders found.');

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _items[index];
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            title: Text('Order #${item.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              '${item.status} · ${item.currency} ${item.totalAmount.toStringAsFixed(2)} · ${formatAdminDate(item.orderDate)}',
            ),
            onTap: () => _showDetails(item),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _delete(item),
            ),
          ),
        );
      },
    );
  }
}
