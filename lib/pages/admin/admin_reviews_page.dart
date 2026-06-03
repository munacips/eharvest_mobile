import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/pages/admin/admin_shared.dart';
import 'package:eharvest_mobile/services/admin_service.dart';
import 'package:flutter/material.dart';

class AdminReviewsPage extends StatefulWidget {
  const AdminReviewsPage({super.key});

  @override
  State<AdminReviewsPage> createState() => _AdminReviewsPageState();
}

class _AdminReviewsPageState extends State<AdminReviewsPage> {
  bool _loading = true;
  String? _error;
  List<Review> _items = [];

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
      final items = await AdminService.fetchReviews();
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
      title: 'Create Review',
      fields: const [
        AdminFormField(key: 'reviewerId', label: 'Reviewer ID', keyboardType: TextInputType.number),
        AdminFormField(key: 'revieweeId', label: 'Reviewee ID', keyboardType: TextInputType.number),
        AdminFormField(key: 'orderId', label: 'Order ID', keyboardType: TextInputType.number),
        AdminFormField(key: 'rating', label: 'Rating (1-5)', keyboardType: TextInputType.number),
        AdminFormField(key: 'comment', label: 'Comment'),
      ],
    );
    if (form == null) return;

    try {
      await AdminService.createReview({
        'reviewerId': int.tryParse(form['reviewerId'] ?? '') ?? 0,
        'revieweeId': int.tryParse(form['revieweeId'] ?? '') ?? 0,
        'orderId': int.tryParse(form['orderId'] ?? '') ?? 0,
        'rating': int.tryParse(form['rating'] ?? '') ?? 0,
        'comment': form['comment'],
      });
      if (!mounted) return;
      showAdminSnackBar(context, 'Review created');
      _load();
    } catch (e) {
      if (!mounted) return;
      showAdminSnackBar(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _edit(Review item) async {
    final form = await showAdminFormDialog(
      context,
      title: 'Edit Review #${item.id}',
      fields: [
        AdminFormField(key: 'rating', label: 'Rating (1-5)', initialValue: item.rating.toString(), keyboardType: TextInputType.number),
        AdminFormField(key: 'comment', label: 'Comment', initialValue: item.comment),
      ],
    );
    if (form == null) return;

    try {
      await AdminService.updateReview(item.id, {
        'rating': int.tryParse(form['rating'] ?? '') ?? item.rating,
        'comment': form['comment'],
        'reviewerId': item.reviewerId,
        'revieweeId': item.revieweeId,
        'orderId': item.orderId,
      });
      if (!mounted) return;
      showAdminSnackBar(context, 'Review updated');
      _load();
    } catch (e) {
      if (!mounted) return;
      showAdminSnackBar(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _delete(Review item) async {
    final confirmed = await confirmAdminAction(
      context,
      title: 'Delete review?',
      message: 'Delete review #${item.id}?',
    );
    if (!confirmed) return;

    try {
      await AdminService.deleteReview(item.id);
      if (!mounted) return;
      showAdminSnackBar(context, 'Review deleted');
      _load();
    } catch (e) {
      if (!mounted) return;
      showAdminSnackBar(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showDetails(Review item) {
    showAdminDetailsDialog(
      context,
      title: 'Review #${item.id}',
      rows: [
        ('Rating', '${item.rating}/5'),
        ('Status', item.status),
        ('Order ID', item.orderId.toString()),
        ('Reviewer', item.reviewer?.displayName ?? item.reviewerId.toString()),
        ('Reviewee', item.reviewee?.displayName ?? item.revieweeId.toString()),
        ('Comment', item.comment),
        ('Created', formatAdminDate(item.createdAt)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Reviews',
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
    if (_items.isEmpty) return const AdminEmptyBody(message: 'No reviews found.');

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
            title: Text('${item.rating}/5 · Review #${item.id}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${item.status} · ${item.comment}'),
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
