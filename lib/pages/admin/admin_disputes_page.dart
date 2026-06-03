import 'package:eharvest_mobile/models/admin_models.dart';
import 'package:eharvest_mobile/pages/admin/admin_shared.dart';
import 'package:eharvest_mobile/services/admin_service.dart';
import 'package:flutter/material.dart';

class AdminDisputesPage extends StatefulWidget {
  const AdminDisputesPage({super.key});

  @override
  State<AdminDisputesPage> createState() => _AdminDisputesPageState();
}

class _AdminDisputesPageState extends State<AdminDisputesPage> {
  bool _loading = true;
  String? _error;
  List<DisputeReport> _items = [];
  bool? _attendedFilter;

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
      final items = await AdminService.fetchDisputeReports(attendedTo: _attendedFilter);
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

  Future<void> _toggleAttended(DisputeReport item) async {
    try {
      await AdminService.markDisputeAttended(item.id, !item.attendedTo);
      if (!mounted) return;
      showAdminSnackBar(
        context,
        item.attendedTo ? 'Marked as unattended' : 'Marked as attended',
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      showAdminSnackBar(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _delete(DisputeReport item) async {
    final confirmed = await confirmAdminAction(
      context,
      title: 'Delete dispute report?',
      message: 'Delete report #${item.id}?',
    );
    if (!confirmed) return;

    try {
      await AdminService.deleteDisputeReport(item.id);
      if (!mounted) return;
      showAdminSnackBar(context, 'Dispute report deleted');
      _load();
    } catch (e) {
      if (!mounted) return;
      showAdminSnackBar(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showDetails(DisputeReport item) {
    showAdminDetailsDialog(
      context,
      title: 'Dispute #${item.id}',
      rows: [
        ('Status', item.status),
        ('Attended', item.attendedTo ? 'Yes' : 'No'),
        ('Reporter', item.reporterName ?? item.reporterId?.toString() ?? 'N/A'),
        ('Order ID', item.orderId?.toString() ?? 'N/A'),
        ('Created', formatAdminDate(item.createdAt)),
        ('Description', item.description),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Dispute Reports',
      actions: [
        PopupMenuButton<bool?>(
          tooltip: 'Filter',
          onSelected: (value) {
            setState(() => _attendedFilter = value);
            _load();
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: null, child: Text('All reports')),
            PopupMenuItem(value: false, child: Text('Unattended only')),
            PopupMenuItem(value: true, child: Text('Attended only')),
          ],
          icon: const Icon(Icons.filter_list),
        ),
      ],
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AdminLoadingBody();
    if (_error != null) return AdminErrorBody(message: _error!, onRetry: _load);
    if (_items.isEmpty) return const AdminEmptyBody(message: 'No dispute reports found.');

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
            title: Text('Dispute #${item.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    adminStatusChip(
                      item.attendedTo ? 'Attended' : 'Unattended',
                      color: item.attendedTo ? Colors.green : Colors.orange,
                    ),
                    if (item.status.isNotEmpty) adminStatusChip(item.status),
                  ],
                ),
              ],
            ),
            onTap: () => _showDetails(item),
            trailing: PopupMenuButton<String>(
              onSelected: (action) {
                switch (action) {
                  case 'attended':
                    _toggleAttended(item);
                    break;
                  case 'delete':
                    _delete(item);
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'attended',
                  child: Text(item.attendedTo ? 'Mark unattended' : 'Mark attended'),
                ),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ),
        );
      },
    );
  }
}
