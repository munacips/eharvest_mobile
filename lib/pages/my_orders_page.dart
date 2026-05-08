import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/services/auth_service.dart';
import 'package:eharvest_mobile/services/order_service.dart';
import 'package:flutter/material.dart';

class MyOrdersPage extends StatefulWidget {
  const MyOrdersPage({super.key});

  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> {
  static const String _newStatus = 'NEW';
  static const String _pendingStatus = 'PENDING';
  static const String _acceptedStatus = 'ACCEPTED';
  static const String _rejectedStatus = 'REJECTED';

  List<Order> _orders = [];
  bool _isLoading = true;
  String? _error;
  int? _updatingOrderId;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final farmerId = await AuthService.getUserId();
      if (farmerId == null) {
        throw Exception('Could not find farmer account.');
      }

      final orders = await OrderService.fetchOrdersForFarmer(farmerId);
      if (!mounted) {
        return;
      }

      setState(() {
        _orders = orders;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _updateOrderStatus(Order order, String status) async {
    setState(() {
      _updatingOrderId = order.id;
      _error = null;
    });

    try {
      if (status == _acceptedStatus) {
        await OrderService.acceptOrder(order.id);
      } else if (status == _rejectedStatus) {
        await OrderService.rejectOrder(order.id);
      } else {
        final success = await OrderService.updateOrderStatus(order, status);
        if (!success) {
          setState(() {
            _error = 'Failed to update order status.';
            _updatingOrderId = null;
          });
          return;
        }
      }
      if (!mounted) {
        return;
      }

      await _fetchOrders();
      if (!mounted) {
        return;
      }

      setState(() {
        _updatingOrderId = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString();
        _updatingOrderId = null;
      });
    }
  }

  bool _canProcessOrder(Order order) {
    return order.status == _newStatus || order.status == _pendingStatus;
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case _acceptedStatus:
        return Colors.green;
      case _rejectedStatus:
        return Colors.red;
      case _newStatus:
      case _pendingStatus:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

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
                onPressed: _fetchOrders,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchOrders,
        child: ListView(
          children: const [
            SizedBox(height: 240),
            Center(child: Text('No orders found.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchOrders,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return _buildOrderCard(_orders[index]);
        },
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    final isUpdating = _updatingOrderId == order.id;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #${order.id}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Chip(
                  label: Text(order.status),
                  backgroundColor: _statusColor(order.status),
                  labelStyle: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Date: ${_formatDate(order.orderDate)}'),
            Text('Total: USD ${order.totalAmount.toStringAsFixed(2)}'),
            if (order.buyer != null) Text('Buyer: ${order.buyer!.fullName}'),
            if (_canProcessOrder(order))
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.check, color: Colors.green),
                    label: const Text(
                      'Accept',
                      style: TextStyle(color: Colors.green),
                    ),
                    onPressed: isUpdating
                        ? null
                        : () => _updateOrderStatus(order, _acceptedStatus),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.close, color: Colors.red),
                    label: const Text(
                      'Reject',
                      style: TextStyle(color: Colors.red),
                    ),
                    onPressed: isUpdating
                        ? null
                        : () => _updateOrderStatus(order, _rejectedStatus),
                  ),
                  if (isUpdating)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
