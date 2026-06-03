import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/pages/admin/admin_shared.dart';
import 'package:eharvest_mobile/services/admin_service.dart';
import 'package:flutter/material.dart';

class AdminLogisticsPage extends StatefulWidget {
  const AdminLogisticsPage({super.key});

  @override
  State<AdminLogisticsPage> createState() => _AdminLogisticsPageState();
}

class _AdminLogisticsPageState extends State<AdminLogisticsPage> {
  bool _loading = true;
  String? _error;
  List<LogisticsRequest> _items = [];

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
      final items = await AdminService.fetchLogisticsRequests();
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
      title: 'Create Logistics Request',
      fields: const [
        AdminFormField(key: 'orderId', label: 'Order ID', keyboardType: TextInputType.number),
        AdminFormField(key: 'pickupLocation', label: 'Pickup location'),
        AdminFormField(key: 'deliveryLocation', label: 'Delivery location'),
        AdminFormField(key: 'cost', label: 'Cost', keyboardType: TextInputType.number),
      ],
    );
    if (form == null) return;

    try {
      await AdminService.createLogisticsRequest({
        'orderId': int.tryParse(form['orderId'] ?? '') ?? 0,
        'pickupLocation': form['pickupLocation'],
        'deliveryLocation': form['deliveryLocation'],
        'cost': double.tryParse(form['cost'] ?? '') ?? 0,
      });
      if (!mounted) return;
      showAdminSnackBar(context, 'Logistics request created');
      _load();
    } catch (e) {
      if (!mounted) return;
      showAdminSnackBar(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _delete(LogisticsRequest item) async {
    final confirmed = await confirmAdminAction(
      context,
      title: 'Delete logistics request?',
      message: 'Delete request #${item.id}?',
    );
    if (!confirmed) return;

    try {
      await AdminService.deleteLogisticsRequest(item.id);
      if (!mounted) return;
      showAdminSnackBar(context, 'Logistics request deleted');
      _load();
    } catch (e) {
      if (!mounted) return;
      showAdminSnackBar(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showDetails(LogisticsRequest item) {
    showAdminDetailsDialog(
      context,
      title: 'Logistics #${item.id}',
      rows: [
        ('Status', item.status),
        ('Pickup', item.pickupLocation),
        ('Delivery', item.deliveryLocation),
        ('Cost', item.cost.toStringAsFixed(2)),
        ('Provider', item.assignedProvider?.displayName ?? 'Unassigned'),
        ('Order ID', (item.order?.id ?? 0).toString()),
        ('Escrow held', item.escrowHeld ? 'Yes' : 'No'),
        ('Escrow released', item.escrowReleased ? 'Yes' : 'No'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Logistics Requests',
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
    if (_items.isEmpty) {
      return const AdminEmptyBody(message: 'No logistics requests found.');
    }

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
            title: Text('Request #${item.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${item.status} · ${item.pickupLocation} → ${item.deliveryLocation}'),
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
