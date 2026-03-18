import 'dart:convert';

import 'package:eharvest_mobile/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:eharvest_mobile/global_variables.dart';
import 'package:http/http.dart' as http;

class CheckoutPage extends StatefulWidget {
  final List<Produce> cart;

  const CheckoutPage({super.key, required this.cart});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  late List<Produce> _cart;
  // Track quantities for each cart item
  late List<int> _quantities;
  bool _isSubmitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _cart = List<Produce>.from(widget.cart, growable: true);
    _quantities = List<int>.filled(_cart.length, 1);
  }

  int? _extractFarmerId(Produce product) {
    final id = product.farmer?.id ?? product.farmerId;
    if (id != null && id > 0) {
      return id;
    }
    return null;
  }

  void _removeCartItem(int index) {
    setState(() {
      _cart.removeAt(index);
      _quantities.removeAt(index);
    });
  }

  Future<void> _placeOrder() async {
    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });
    try {
      final token = await AuthService.getToken();
      final buyerId = await AuthService.getUserId();
      if (token == null || buyerId == null) {
        setState(() {
          _submitError = 'Authentication token or user not found.';
          _isSubmitting = false;
        });
        return;
      }

      // Group cart items by farmer id
      final Map<int, List<int>> farmerToCartIndexes = {};
      for (int i = 0; i < _cart.length; i++) {
        final product = _cart[i];
        final farmerId = _extractFarmerId(product);
        if (farmerId == null) continue;
        farmerToCartIndexes.putIfAbsent(farmerId, () => []).add(i);
      }

      if (farmerToCartIndexes.isEmpty) {
        setState(() {
          _submitError =
              'Could not place order: farmer id is missing for all cart items.';
          _isSubmitting = false;
        });
        return;
      }

      // For each farmer, create an order, then create order items with the order id
      for (final entry in farmerToCartIndexes.entries) {
        final farmerId = entry.key;
        final indexes = entry.value;
        double totalAmount = 0;
        final orderItems = <Map<String, dynamic>>[];
        for (final idx in indexes) {
          final product = _cart[idx];
          final qty = _quantities[idx];
          if (qty < 1) continue;
          final itemTotal = product.price * qty;
          totalAmount += itemTotal;
          orderItems.add({
            'produce': product.id,
            'quantity': qty,
            'price': product.price,
          });
        }
        final orderPayload = {
          'totalAmount': totalAmount,
          'status': 'PENDING',
          'escrowReleased': false,
          'buyerId': buyerId,
          'farmerId': farmerId
        };

        if (orderItems.isEmpty) {
          continue;
        }

        // Create the order first
        final response = await http.post(
          Uri.parse('${api}orders'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: json.encode(orderPayload),
        );
        if (response.statusCode != 200 && response.statusCode != 201) {
          throw Exception('Order failed: ${response.statusCode}');
        }

        // Parse the created order id
        final orderData = json.decode(response.body);
        final orderId = orderData['id'];
        if (orderId == null) {
          throw Exception('Order ID not returned from API.');
        }

        // Create order items for this order
        for (final item in orderItems) {
          if (item['price'] == null) {
            setState(() {
              _submitError =
                  'Error: Tried to create an order item with a missing price.';
              _isSubmitting = false;
            });
            return;
          }
          final orderItemPayload = {
            'quantity': item['quantity'],
            'price': item['price'],
            'produce': item['produce'],
            'order': orderId,
          };
          // Debug print for payload
          // print('OrderItem payload: ' + orderItemPayload.toString());
          final itemResponse = await http.post(
            Uri.parse('${api}order_items'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode(orderItemPayload),
          );
          if (itemResponse.statusCode != 200 &&
              itemResponse.statusCode != 201) {
            throw Exception('Order item failed: ${itemResponse.statusCode}');
          }
        }
      }

      setState(() {
        _isSubmitting = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order(s) placed successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _submitError = 'Error placing order: $e';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: _cart.isEmpty
          ? const Center(child: Text('Your cart is empty'))
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _cart.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final item = _cart[index];
                      return ListTile(
                        title: Text(item.name),
                        subtitle: Text(item.category),
                        trailing: SizedBox(
                          width: 170,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: _isSubmitting
                                    ? null
                                    : () {
                                        setState(() {
                                          if (_quantities[index] > 1) {
                                            _quantities[index]--;
                                          }
                                        });
                                      },
                              ),
                              SizedBox(
                                width: 40,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        enabled: !_isSubmitting,
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        controller: TextEditingController(
                                          text: _quantities[index].toString(),
                                        ),
                                        onChanged: (val) {
                                          final parsed = int.tryParse(val);
                                          if (parsed != null && parsed > 0) {
                                            setState(() {
                                              _quantities[index] = parsed;
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    const Text(
                                      'kg',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: _isSubmitting
                                    ? null
                                    : () {
                                        setState(() {
                                          _quantities[index]++;
                                        });
                                      },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: _isSubmitting
                                    ? null
                                    : () => _removeCartItem(index),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      if (_submitError != null)
                        Text(
                          _submitError!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _placeOrder,
                          child: _isSubmitting
                              ? const CircularProgressIndicator()
                              : const Text('Place Order'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
