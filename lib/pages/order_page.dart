import 'package:flutter/material.dart';
import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/pages/account_page.dart';
import 'package:eharvest_mobile/pages/logistics_request_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:eharvest_mobile/services/auth_service.dart';
import 'package:eharvest_mobile/services/order_service.dart';
import 'package:eharvest_mobile/services/payment_service.dart';
import 'package:eharvest_mobile/widgets/order_review_section.dart';

class OrderPage extends StatefulWidget {
  final int orderId;

  const OrderPage({super.key, required this.orderId});

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  Order? _order;
  List<OrderItem> _orderItems = [];
  LogisticsRequest? _logisticsRequest;
  Map<String, dynamic>? _profile;
  String? _role;
  int? _userId;
  bool _loading = true;
  String? _error;
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchOrderDetails();
  }

  Future<void> _fetchOrderDetails() async {
    setState(() {
      _loading = true;
      _error = null;
      _logisticsRequest = null;
    });
    try {
      // Get token
      final token = await AuthService.getToken();
      _role = await AuthService.getRole();
      _userId = await AuthService.getUserId();
      if (token == null) {
        setState(() {
          _error = 'Authentication error. Please log in again.';
          _loading = false;
        });
        return;
      }

      // Fetch order details
      final orderResp = await http.get(
        Uri.parse('${api}orders/${widget.orderId}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (orderResp.statusCode == 200) {
        final orderJson = json.decode(orderResp.body);
        _order = Order.fromJson(orderJson);
      } else {
        setState(() {
          _error = 'Failed to load order details.';
          _loading = false;
        });
        return;
      }

      // Fetch order items
      final itemsResp = await http.get(
        Uri.parse('${api}order_items/order/${widget.orderId}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (itemsResp.statusCode == 200) {
        final itemsJson = json.decode(itemsResp.body);
        if (itemsJson is List) {
          _orderItems = itemsJson
              .map<OrderItem?>((o) {
                try {
                  return OrderItem.fromJson(o as Map<String, dynamic>);
                } catch (e) {
                  return null;
                }
              })
              .whereType<OrderItem>()
              .toList();
        } else {
          _orderItems = [];
        }
      } else {
        _orderItems = [];
      }

      // Fetch logistics request (if any)
      _logisticsRequest = await _fetchLogisticsRequest(token);
      try {
        _profile = await PaymentService.fetchCurrentProfile();
      } catch (_) {
        _profile = null;
      }

      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading order: $e';
        _loading = false;
      });
    }
  }

  Future<LogisticsRequest?> _fetchLogisticsRequest(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${api}logistics/order/${widget.orderId}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData is Map<String, dynamic>) {
          return LogisticsRequest.fromJson(jsonData);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  void _showRequestLogisticsDialog() {
    final deliveryLocationController = TextEditingController();
    final costController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Request Logistics'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: deliveryLocationController,
                decoration: InputDecoration(
                  labelText: 'Delivery Location',
                  hintText: 'Enter delivery location',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: costController,
                decoration: InputDecoration(
                  labelText: 'Cost Bid',
                  hintText: 'Enter your cost bid',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _submitLogisticsRequest(
                  deliveryLocationController.text,
                  costController.text,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(primaryColour),
              ),
              child: const Text(
                'Submit',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitLogisticsRequest(
    String deliveryLocation,
    String costStr,
  ) async {
    if (deliveryLocation.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter delivery location')),
      );
      return;
    }

    if (costStr.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter cost bid')));
      return;
    }

    final cost = double.tryParse(costStr);
    if (cost == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid cost')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    try {
      final token = await AuthService.getToken();
      if (token == null) {
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('Authentication error')),
        );
        return;
      }

      final response = await http.post(
        Uri.parse('${api}logistics'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'pickupLocation': _order?.farmer?.address ?? '',
          'deliveryLocation': deliveryLocation,
          'cost': cost,
          'status': 'SEARCHING',
          'order': widget.orderId,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (!mounted) return;
        // Refresh order details to show the new logistics request
        await _fetchOrderDetails();
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Logistics request created successfully'),
          ),
        );
      } else {
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('Failed to create logistics request')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _runOrderAction(
    String successMessage,
    Future<Map<String, dynamic>> Function() action,
  ) async {
    setState(() {
      _actionLoading = true;
      _error = null;
    });
    try {
      await action();
      await _fetchOrderDetails();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
    } finally {
      if (mounted) {
        setState(() => _actionLoading = false);
      }
    }
  }

  void _showTransportFeeDialog(Order order) {
    final feeController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Propose transport fee'),
          content: TextField(
            controller: feeController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Fee',
              prefixText: '\$ ',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final fee = double.tryParse(feeController.text.trim());
                if (fee == null || fee <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a transport fee greater than 0.'),
                    ),
                  );
                  return;
                }
                Navigator.of(context).pop();
                _runOrderAction(
                  'Transport fee proposed.',
                  () => OrderService.proposeTransportFee(order.id, fee),
                );
              },
              child: const Text('Propose'),
            ),
          ],
        );
      },
    );
  }

  bool get _isBuyer {
    final role = (_role ?? '').toLowerCase();
    return role.contains('buyer') && _order?.buyer?.id == _userId;
  }

  bool get _isFarmer {
    final role = (_role ?? '').toLowerCase();
    return role.contains('farmer') && _order?.farmer?.id == _userId;
  }

  double get _availableBalance {
    final profile = _profile;
    final order = _order;
    if (profile == null || order == null) return 0;
    return PaymentService.balanceForCurrency(profile, order.currency);
  }

  bool _isStatus(String value) {
    return (_order?.status ?? '').toLowerCase() == value.toLowerCase();
  }

  bool get _canHoldEscrow {
    final order = _order;
    if (order == null) return false;
    return _isBuyer &&
        _isThirdParty &&
        !order.escrowReleased &&
        !order.escrowHeld &&
        _availableBalance >= order.escrowAmount;
  }

  bool get _isThirdParty => _order?.logisticsType == 'THIRD_PARTY';
  bool get _isFarmerDelivery => _order?.logisticsType == 'FARMER_DELIVERY';
  bool get _isBuyerPickup => _order?.logisticsType == 'BUYER_PICKUP';

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

  String _statusLabel(Order order) {
    switch (order.status.toUpperCase()) {
      case 'PENDING':
      case 'NEW':
        return 'Awaiting farmer response';
      case 'ACCEPTED':
        if (order.logisticsType == 'BUYER_PICKUP') return 'Ready for pickup';
        if (order.logisticsType == 'FARMER_DELIVERY') {
          return 'Awaiting transport fee proposal';
        }
        return 'Order accepted';
      case 'AWAITING_TRANSPORT_FEE_APPROVAL':
        return 'Awaiting buyer transport fee approval';
      case 'IN_TRANSIT':
      case 'DELIVERY_STARTED':
        return 'In transit';
      case 'DELIVERED':
      case 'COMPLETED':
        return 'Delivered';
      case 'REJECTED':
        return 'Rejected';
      case 'CANCELLED':
        return 'Cancelled';
      default:
        return order.status;
    }
  }

  String _friendlyError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    return message.isEmpty
        ? 'That action is not available for this order right now.'
        : message;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF7F7F7),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: Color(0xFFF7F7F7),
        body: Center(
          child: Text(
            _error!,
            style: const TextStyle(color: Colors.red, fontSize: 16),
          ),
        ),
      );
    }
    if (_order == null) {
      return Scaffold(
        backgroundColor: Color(0xFFF7F7F7),
        body: const Center(child: Text('Order not found.')),
      );
    }

    final logisticsRequest = _logisticsRequest ?? _order!.logisticsRequest;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Color(primaryColour),
        elevation: 0,
        title: Text(
          'Order #${_order!.id}',
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              decoration: BoxDecoration(
                color: Color(primaryColour),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.receipt_long, color: Colors.white, size: 32),
                      const SizedBox(width: 12),
                      Text(
                        'Order #${_order!.id}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      _statusChip(_statusLabel(_order!)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: Colors.white70,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Order Date: ${_order!.orderDate.toLocal().toString().split(' ')[0]}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.attach_money, color: Colors.white70, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Total: ${_order!.currency} ${_order!.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.local_shipping_outlined,
                        color: Colors.white70,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _logisticsLabel(_order!.logisticsType),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_order!.buyer != null)
                    Row(
                      children: [
                        Icon(Icons.person, color: Colors.white70, size: 18),
                        const SizedBox(width: 6),
                        const Text(
                          'Buyer: ',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AccountPage(id: _order!.buyer!.id),
                              ),
                            );
                          },
                          child: Text(
                            _order!.buyer!.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (_order!.farmer != null)
                    Row(
                      children: [
                        Icon(
                          Icons.agriculture,
                          color: Colors.white70,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Farmer: ',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AccountPage(id: _order!.farmer!.id),
                              ),
                            );
                          },
                          child: Text(
                            _order!.farmer!.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: _escrowCard(),
            ),
            const SizedBox(height: 24),
            // Order Items Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Order Items',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_orderItems.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'No items found.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ..._orderItems.map((item) => _orderItemCard(item)),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Logistics Section
            if (_isThirdParty && _order!.status.toLowerCase() == 'accepted')
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Logistics',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (logisticsRequest != null)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LogisticsRequestPage(
                                  logisticsRequest: logisticsRequest,
                                  onUpdate: _fetchOrderDetails,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(primaryColour),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'View Logistics Request',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _showRequestLogisticsDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(primaryColour),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Request Logistics',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 32),
            if (_order != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: OrderReviewSection(
                  order: _order!,
                  logisticsRequest: logisticsRequest,
                  currentUserId: _userId,
                  currentUserRole: _role,
                  onReviewCreated: _fetchOrderDetails,
                ),
              ),
            if (_order != null) const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'pending':
        color = Colors.orange;
        break;
      case 'completed':
      case 'delivered':
        color = Colors.green;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      default:
        color = Colors.blueGrey;
    }
    return Chip(
      label: Text(status, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
    );
  }

  Widget _escrowCard() {
    final order = _order!;
    final escrowText = order.escrowReleased
        ? 'Released to farmer'
        : (order.escrowHeld
              ? 'Held'
              : (_isStatus('REJECTED')
                    ? 'Refunded or released by backend'
                    : 'Pending hold'));
    final transportFee = order.transportFee;
    final escrowTotal = order.totalAmount + (transportFee ?? 0);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock_outline, color: Color(primaryColour)),
                const SizedBox(width: 8),
                const Text(
                  'Wallet and Escrow',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Available balance: ${order.currency} ${_availableBalance.toStringAsFixed(2)}',
            ),
            Text(
              'Order amount: ${order.currency} ${order.totalAmount.toStringAsFixed(2)}',
            ),
            Text(
              'Escrow amount: ${order.currency} ${order.escrowAmount.toStringAsFixed(2)}',
            ),
            Text('Logistics: ${_logisticsLabel(order.logisticsType)}'),
            if (transportFee != null)
              Text(
                'Transport fee: ${order.currency} ${transportFee.toStringAsFixed(2)}',
              ),
            if (_isFarmerDelivery &&
                _isStatus('AWAITING_TRANSPORT_FEE_APPROVAL') &&
                transportFee != null)
              Text(
                'New escrow total: ${order.currency} ${escrowTotal.toStringAsFixed(2)}',
              ),
            Text('Escrow status: $escrowText'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_isBuyer &&
                    _isThirdParty &&
                    !order.escrowReleased &&
                    !order.escrowHeld &&
                    !_isStatus('REJECTED'))
                  ElevatedButton.icon(
                    onPressed: _actionLoading || !_canHoldEscrow
                        ? null
                        : () => _runOrderAction(
                            'Escrow held for this order.',
                            () => OrderService.holdEscrow(order.id),
                          ),
                    icon: _actionLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.lock),
                    label: const Text('Hold Escrow'),
                  ),
                if (_isFarmer && (_isStatus('PENDING') || _isStatus('NEW')))
                  OutlinedButton.icon(
                    onPressed: _actionLoading
                        ? null
                        : () => _runOrderAction(
                            'Order accepted.',
                            () => OrderService.acceptOrder(order.id),
                          ),
                    icon: const Icon(Icons.check),
                    label: const Text('Accept'),
                  ),
                if (_isFarmer && (_isStatus('PENDING') || _isStatus('NEW')))
                  OutlinedButton.icon(
                    onPressed: _actionLoading
                        ? null
                        : () => _runOrderAction(
                            'Order rejected.',
                            () => OrderService.rejectOrder(order.id),
                          ),
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                  ),
                if (_isFarmer && _isThirdParty && _isStatus('ACCEPTED'))
                  OutlinedButton.icon(
                    onPressed: _actionLoading
                        ? null
                        : () => _runOrderAction(
                            'Delivery marked as started.',
                            () => OrderService.confirmDeliveryStarted(order.id),
                          ),
                    icon: const Icon(Icons.local_shipping_outlined),
                    label: const Text('Delivery Started'),
                  ),
                if (_isFarmer && _isFarmerDelivery && _isStatus('ACCEPTED'))
                  OutlinedButton.icon(
                    onPressed: _actionLoading
                        ? null
                        : () => _showTransportFeeDialog(order),
                    icon: const Icon(Icons.request_quote_outlined),
                    label: const Text('Propose transport fee'),
                  ),
                if (_isBuyer &&
                    _isFarmerDelivery &&
                    _isStatus('AWAITING_TRANSPORT_FEE_APPROVAL'))
                  ElevatedButton.icon(
                    onPressed: _actionLoading
                        ? null
                        : () => _runOrderAction(
                            'Transport fee accepted.',
                            () => OrderService.acceptTransportFee(order.id),
                          ),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Accept transport fee'),
                  ),
                if (_isBuyer &&
                    _isFarmerDelivery &&
                    _isStatus('AWAITING_TRANSPORT_FEE_APPROVAL'))
                  OutlinedButton.icon(
                    onPressed: _actionLoading
                        ? null
                        : () => _runOrderAction(
                            'Transport fee rejected.',
                            () => OrderService.rejectTransportFee(order.id),
                          ),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Reject transport fee'),
                  ),
                if (_isBuyer &&
                    ((_isThirdParty &&
                            (_isStatus('DELIVERY_STARTED') ||
                                _isStatus('IN_TRANSIT'))) ||
                        (_isFarmerDelivery && _isStatus('IN_TRANSIT')) ||
                        (_isBuyerPickup && _isStatus('ACCEPTED'))))
                  ElevatedButton.icon(
                    onPressed: _actionLoading
                        ? null
                        : () => _runOrderAction(
                            'Delivery confirmed. Escrow released to the farmer.',
                            () => OrderService.confirmDelivery(order.id),
                          ),
                    icon: const Icon(Icons.verified_outlined),
                    label: const Text('Confirm Delivery'),
                  ),
              ],
            ),
            if (_isBuyer && !_canHoldEscrow && !order.escrowReleased)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _availableBalance < order.escrowAmount
                      ? 'Add funds before holding escrow for this order.'
                      : 'Escrow is not available for this order state.',
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _orderItemCard(OrderItem item) {
    final produce = item.produce;
    final produceImageUrl = produce?.imageUrls.isNotEmpty == true
        ? produce!.imageUrls.first
        : null;
    final produceDetails = [
      if (produce?.category.isNotEmpty ?? false) produce!.category,
      if (produce?.qualityGrade.isNotEmpty ?? false) produce!.qualityGrade,
      if (produce?.cityTown.isNotEmpty ?? false) produce!.cityTown,
    ].join(' - ');
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 48,
                height: 48,
                child: produceImageUrl != null
                    ? Image.network(
                        produceImageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _produceImageFallback(produce),
                      )
                    : _produceImageFallback(produce),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    produce?.name ?? 'Unknown Produce',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (produceDetails.isNotEmpty) ...[
                    Text(
                      produceDetails,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  if (produce?.description.isNotEmpty ?? false) ...[
                    Text(
                      produce!.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    'Quantity: ${item.quantity} Kg',
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Price: \$${item.price.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  if (produce?.canProvideTransport ?? false) ...[
                    const SizedBox(height: 2),
                    const Text(
                      'Farmer delivery available',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _produceImageFallback(Produce? produce) {
    return Container(
      color: Colors.grey.shade100,
      child: Center(
        child: Text(
          (produce?.name.isNotEmpty ?? false)
              ? produce!.name[0].toUpperCase()
              : '?',
          style: const TextStyle(fontSize: 28, color: Colors.black54),
        ),
      ),
    );
  }
}
