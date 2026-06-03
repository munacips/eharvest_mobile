import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/pages/admin/admin_shared.dart';
import 'package:eharvest_mobile/services/admin_service.dart';
import 'package:flutter/material.dart';

class AdminVehiclesPage extends StatefulWidget {
  const AdminVehiclesPage({super.key});

  @override
  State<AdminVehiclesPage> createState() => _AdminVehiclesPageState();
}

class _AdminVehiclesPageState extends State<AdminVehiclesPage> {
  bool _loading = true;
  String? _error;
  List<Vehicle> _items = [];

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
      final items = await AdminService.fetchVehicles();
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
      title: 'Create Vehicle',
      fields: const [
        AdminFormField(key: 'plateNumber', label: 'Plate number'),
        AdminFormField(key: 'type', label: 'Type'),
        AdminFormField(key: 'colour', label: 'Colour'),
        AdminFormField(key: 'ownerId', label: 'Owner (provider) ID', keyboardType: TextInputType.number),
      ],
    );
    if (form == null) return;

    try {
      await AdminService.createVehicle({
        'plateNumber': form['plateNumber'],
        'type': form['type'],
        'colour': form['colour'],
        'owner': {'id': int.tryParse(form['ownerId'] ?? '') ?? 0},
      });
      if (!mounted) return;
      showAdminSnackBar(context, 'Vehicle created');
      _load();
    } catch (e) {
      if (!mounted) return;
      showAdminSnackBar(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _delete(Vehicle item) async {
    final confirmed = await confirmAdminAction(
      context,
      title: 'Delete vehicle?',
      message: 'Delete ${item.plateNumber}?',
    );
    if (!confirmed) return;

    try {
      await AdminService.deleteVehicle(item.id);
      if (!mounted) return;
      showAdminSnackBar(context, 'Vehicle deleted');
      _load();
    } catch (e) {
      if (!mounted) return;
      showAdminSnackBar(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showDetails(Vehicle item) {
    showAdminDetailsDialog(
      context,
      title: item.plateNumber,
      rows: [
        ('ID', item.id.toString()),
        ('Type', item.type),
        ('Colour', item.colour),
        ('Owner', item.owner?.displayName ?? 'Unknown'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Vehicles',
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
    if (_items.isEmpty) return const AdminEmptyBody(message: 'No vehicles found.');

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
            title: Text(item.plateNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${item.type} · ${item.colour}'),
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
