import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/pages/admin/admin_shared.dart';
import 'package:eharvest_mobile/services/admin_service.dart';
import 'package:flutter/material.dart';

class AdminProducePage extends StatefulWidget {
  const AdminProducePage({super.key});

  @override
  State<AdminProducePage> createState() => _AdminProducePageState();
}

class _AdminProducePageState extends State<AdminProducePage> {
  bool _loading = true;
  String? _error;
  List<Produce> _items = [];

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
      final items = await AdminService.fetchProduce();
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
      title: 'Create Produce',
      fields: const [
        AdminFormField(key: 'name', label: 'Name'),
        AdminFormField(key: 'category', label: 'Category'),
        AdminFormField(key: 'description', label: 'Description'),
        AdminFormField(key: 'qualityGrade', label: 'Quality grade'),
        AdminFormField(key: 'quantity', label: 'Quantity', keyboardType: TextInputType.number),
        AdminFormField(key: 'price', label: 'Price', keyboardType: TextInputType.number),
        AdminFormField(key: 'cityTown', label: 'City / town'),
        AdminFormField(key: 'farmerId', label: 'Farmer ID', keyboardType: TextInputType.number),
      ],
    );
    if (form == null) return;

    try {
      await AdminService.createProduce({
        'name': form['name'],
        'category': form['category'],
        'description': form['description'],
        'qualityGrade': form['qualityGrade'],
        'quantity': double.tryParse(form['quantity'] ?? '') ?? 0,
        'price': double.tryParse(form['price'] ?? '') ?? 0,
        'cityTown': form['cityTown'],
        'farmer': {'id': int.tryParse(form['farmerId'] ?? '') ?? 0},
      });
      if (!mounted) return;
      showAdminSnackBar(context, 'Produce created');
      _load();
    } catch (e) {
      if (!mounted) return;
      showAdminSnackBar(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _edit(Produce item) async {
    final form = await showAdminFormDialog(
      context,
      title: 'Edit ${item.name}',
      fields: [
        AdminFormField(key: 'name', label: 'Name', initialValue: item.name),
        AdminFormField(key: 'category', label: 'Category', initialValue: item.category),
        AdminFormField(key: 'description', label: 'Description', initialValue: item.description),
        AdminFormField(key: 'qualityGrade', label: 'Quality grade', initialValue: item.qualityGrade),
        AdminFormField(key: 'quantity', label: 'Quantity', initialValue: item.quantity.toString(), keyboardType: TextInputType.number),
        AdminFormField(key: 'price', label: 'Price', initialValue: item.price.toString(), keyboardType: TextInputType.number),
        AdminFormField(key: 'cityTown', label: 'City / town', initialValue: item.cityTown),
      ],
    );
    if (form == null) return;

    try {
      await AdminService.updateProduce(item.id, {
        'name': form['name'],
        'category': form['category'],
        'description': form['description'],
        'qualityGrade': form['qualityGrade'],
        'quantity': double.tryParse(form['quantity'] ?? '') ?? item.quantity,
        'price': double.tryParse(form['price'] ?? '') ?? item.price,
        'cityTown': form['cityTown'],
        'farmer': {'id': item.farmerId ?? item.farmer?.id ?? 0},
      });
      if (!mounted) return;
      showAdminSnackBar(context, 'Produce updated');
      _load();
    } catch (e) {
      if (!mounted) return;
      showAdminSnackBar(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _delete(Produce item) async {
    final confirmed = await confirmAdminAction(
      context,
      title: 'Delete produce?',
      message: 'Delete ${item.name}?',
    );
    if (!confirmed) return;

    try {
      await AdminService.deleteProduce(item.id);
      if (!mounted) return;
      showAdminSnackBar(context, 'Produce deleted');
      _load();
    } catch (e) {
      if (!mounted) return;
      showAdminSnackBar(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showDetails(Produce item) {
    showAdminDetailsDialog(
      context,
      title: item.name,
      rows: [
        ('ID', item.id.toString()),
        ('Category', item.category),
        ('Quality', item.qualityGrade),
        ('Quantity', item.quantity.toString()),
        ('Price', item.price.toStringAsFixed(2)),
        ('Location', item.cityTown),
        ('Farmer ID', (item.farmerId ?? item.farmer?.id ?? 0).toString()),
        ('Available from', formatAdminDate(item.availableFrom)),
        ('Harvest date', formatAdminDate(item.harvestDate)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Produce',
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
    if (_items.isEmpty) return const AdminEmptyBody(message: 'No produce listings.');

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
            title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${item.category} · ${item.quantity} units · \$${item.price.toStringAsFixed(2)}'),
            onTap: () => _showDetails(item),
            trailing: PopupMenuButton<String>(
              onSelected: (action) {
                if (action == 'edit') {
                  _edit(item);
                } else if (action == 'delete') {
                  _delete(item);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ),
        );
      },
    );
  }
}
