import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/pages/admin/admin_shared.dart';
import 'package:eharvest_mobile/services/admin_service.dart';
import 'package:flutter/material.dart';

class AdminOrderItemsPage extends StatefulWidget {
  const AdminOrderItemsPage({super.key});

  @override
  State<AdminOrderItemsPage> createState() => _AdminOrderItemsPageState();
}

class _AdminOrderItemsPageState extends State<AdminOrderItemsPage> {
  bool _loading = true;
  String? _error;
  List<OrderItem> _items = [];

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
      final items = await AdminService.fetchOrderItems();
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

  Future<void> _create() async {
    final form = await showAdminFormDialog(
      context,
      title: 'Create Order Item',
      fields: const [
        AdminFormField(key: 'orderId', label: 'Order ID', keyboardType: TextInputType.number),
        AdminFormField(key: 'produceId', label: 'Produce ID', keyboardType: TextInputType.number),
        AdminFormField(key: 'quantity', label: 'Quantity', keyboardType: TextInputType.number),
        AdminFormField(key: 'price', label: 'Price', keyboardType: TextInputType.number),
      ],
    );
    if (form == null) return;

    try {
      await AdminService.createOrderItem({
        'order': {'id': int.tryParse(form['orderId'] ?? '') ?? 0},
        'produce': {'id': int.tryParse(form['produceId'] ?? '') ?? 0},
        'quantity': int.tryParse(form['quantity'] ?? '') ?? 0,
        'price': double.tryParse(form['price'] ?? '') ?? 0,
      });
      if (!mounted) return;
      showAdminSnackBar(context, 'Order item created');
      _load();
    } catch (e) {
      if (!mounted) return;
      showAdminSnackBar(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _delete(OrderItem item) async {
    final confirmed = await confirmAdminAction(
      context,
      title: 'Delete order item?',
      message: 'Delete item #${item.id}?',
    );
    if (!confirmed) return;

    try {
      await AdminService.deleteOrderItem(item.id);
      if (!mounted) return;
      showAdminSnackBar(context, 'Order item deleted');
      _load();
    } catch (e) {
      if (!mounted) return;
      showAdminSnackBar(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showDetails(OrderItem item) {
    showAdminDetailsDialog(
      context,
      title: 'Order Item #${item.id}',
      rows: [
        ('Order ID', (item.order?.id ?? 0).toString()),
        ('Produce', item.produce?.name ?? 'N/A'),
        ('Quantity', item.quantity.toString()),
        ('Price', item.price.toStringAsFixed(2)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Order Items',
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        backgroundColor: Color(primaryColour),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AdminLoadingBody();
    if (_error != null) return AdminErrorBody(message: _error!, onRetry: _load);
    if (_items.isEmpty) return const AdminEmptyBody(message: 'No order items found.');

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
            title: Text('Item #${item.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              '${item.produce?.name ?? 'Produce'} · Qty ${item.quantity} · \$${item.price.toStringAsFixed(2)}',
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
