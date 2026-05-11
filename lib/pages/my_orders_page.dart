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
  static const String _awaitingTransportFeeStatus =
      'AWAITING_TRANSPORT_FEE_APPROVAL';

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

  Future<void> _proposeTransportFee(Order order, double fee) async {
    setState(() {
      _updatingOrderId = order.id;
      _error = null;
    });
    try {
      await OrderService.proposeTransportFee(order.id, fee);
      if (!mounted) return;
      await _fetchOrders();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transport fee proposed.')),
      );
      setState(() => _updatingOrderId = null);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
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

  String _statusLabel(Order order) {
    switch (order.status.toUpperCase()) {
      case _pendingStatus:
      case _newStatus:
        return 'Awaiting farmer response';
      case _acceptedStatus:
        if (order.logisticsType == 'BUYER_PICKUP') return 'Ready for pickup';
        if (order.logisticsType == 'FARMER_DELIVERY') {
          return 'Awaiting transport fee proposal';
        }
        return 'Order accepted';
      case _awaitingTransportFeeStatus:
        return 'Awaiting buyer transport fee approval';
      case 'IN_TRANSIT':
        return 'In transit';
      case 'DELIVERED':
        return 'Delivered';
      case _rejectedStatus:
        return 'Rejected';
      case 'CANCELLED':
        return 'Cancelled';
      default:
        return order.status;
    }
  }

  String _logisticsLabel(String logisticsType) {
    switch (logisticsType) {
      case 'FARMER_DELIVERY':
        return 'Farmer delivery';
      case 'BUYER_PICKUP':
        return 'Buyer pickup';
      case 'THIRD_PARTY':
      default:
        return 'Third-party logistics';
    }
  }

  void _showTransportFeeDialog(Order order) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Propose transport fee'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Fee', prefixText: '\$ '),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final fee = double.tryParse(controller.text.trim());
              if (fee == null || fee <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Enter a transport fee greater than 0.'),
                  ),
                );
                return;
              }
              Navigator.of(context).pop();
              _proposeTransportFee(order, fee);
            },
            child: const Text('Propose'),
          ),
        ],
      ),
    );
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
                  label: Text(_statusLabel(order)),
                  backgroundColor: _statusColor(order.status),
                  labelStyle: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Date: ${_formatDate(order.orderDate)}'),
            Text('Total: USD ${order.totalAmount.toStringAsFixed(2)}'),
            Text('Logistics: ${_logisticsLabel(order.logisticsType)}'),
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
            if (order.logisticsType == 'FARMER_DELIVERY' &&
                order.status == _acceptedStatus)
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.request_quote_outlined),
                  label: const Text('Propose transport fee'),
                  onPressed: isUpdating
                      ? null
                      : () => _showTransportFeeDialog(order),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
