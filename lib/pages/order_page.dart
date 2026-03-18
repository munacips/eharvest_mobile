import 'package:flutter/material.dart';
import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/pages/logistics_request_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:eharvest_mobile/services/auth_service.dart';

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
  bool _loading = true;
  String? _error;

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

    try {
      final token = await AuthService.getToken();
      if (token == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Authentication error')));
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logistics request created successfully'),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create logistics request')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
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
                      _statusChip(_order!.status),
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
                        'Total: ${_order!.totalAmount.toStringAsFixed(2)}',
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
                        Text(
                          'Buyer: ${_order!.buyer!.displayName}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
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
                        Text(
                          'Farmer: ${_order!.farmer!.displayName}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
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
            if (_order!.status.toLowerCase() == 'accepted')
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

  Widget _orderItemCard(OrderItem item) {
    final produce = item.produce;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Produce image placeholder
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  (produce?.name.isNotEmpty ?? false)
                      ? produce!.name[0].toUpperCase()
                      : '?',
                  style: const TextStyle(fontSize: 28, color: Colors.black54),
                ),
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
                  Text(
                    'Quantity: ${item.quantity}',
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Price: ${item.price.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
