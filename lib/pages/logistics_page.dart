import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/pages/logistics_request_page.dart';
import 'package:eharvest_mobile/services/auth_service.dart';
import 'package:http/http.dart' as http;

class LogisticsPage extends StatefulWidget {
  const LogisticsPage({super.key});

  @override
  State<LogisticsPage> createState() => LogisticsPageState();
}

class LogisticsPageState extends State<LogisticsPage> {
  List<LogisticsRequest> logisticsRequests = [];
  bool isLoading = true;
  String? errorMessage;
  int? _currentUserId;
  String _roleKey = '';

  String _normalizeRoleKey(String rawRole) {
    final normalized = rawRole.trim().toLowerCase().replaceAll(
      RegExp(r'[\s-]+'),
      '_',
    );
    final baseRole = normalized.startsWith('role_')
        ? normalized.substring('role_'.length)
        : normalized;

    switch (baseRole) {
      case 'farmer':
      case 'buyer':
        return baseRole;
      case 'logistics':
      case 'logistics_provider':
      case 'logisticsprovider':
      case 'driver':
        return 'logistics';
      default:
        return baseRole;
    }
  }

  List<LogisticsRequest> _parseLogisticsItems(dynamic payload) {
    List<dynamic> items = <dynamic>[];
    if (payload is List) {
      items = payload;
    } else if (payload is Map<String, dynamic> && payload['content'] is List) {
      items = payload['content'] as List<dynamic>;
    }

    return items
        .whereType<Map>()
        .map<LogisticsRequest>(
          (item) => LogisticsRequest.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList();
  }

  String _readString(Map<String, dynamic>? map, List<String> keys) {
    if (map == null) return '';
    for (final key in keys) {
      final value = map[key];
      if (value != null) {
        final text = value.toString().trim();
        if (text.isNotEmpty && text.toLowerCase() != 'null') {
          return text;
        }
      }
    }
    return '';
  }

  int _readInt(
    Map<String, dynamic>? map,
    List<String> keys, {
    int fallback = 0,
  }) {
    final text = _readString(map, keys);
    if (text.isEmpty) return fallback;
    return int.tryParse(text) ?? fallback;
  }

  Map<String, dynamic>? _readMap(Map<String, dynamic>? map, List<String> keys) {
    if (map == null) return null;
    for (final key in keys) {
      final value = map[key];
      if (value is Map) {
        return value.map((dynamic k, dynamic v) => MapEntry(k.toString(), v));
      }
    }
    return null;
  }

  bool _isRelatedToCurrentUser(LogisticsRequest request) {
    final userId = _currentUserId;
    if (userId == null) return false;

    final buyerId = request.order?.buyer?.id;
    final farmerId = request.order?.farmer?.id;
    final providerId = request.assignedProvider?.id;

    final isBuyer = buyerId != null && buyerId == userId;
    final isSeller = farmerId != null && farmerId == userId;
    final isProvider = providerId != null && providerId == userId;

    if (_roleKey == 'buyer') return isBuyer;
    if (_roleKey == 'farmer') return isSeller;
    if (_roleKey == 'logistics') return isProvider;

    return isBuyer || isSeller || isProvider;
  }

  @override
  void initState() {
    super.initState();
    fetchLogisticsRequests();
  }

  Future<void> fetchLogisticsRequests() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      // AuthService and api are used as in buy_page.dart
      final token = await AuthService.getToken();
      final userId = await AuthService.getUserId();
      final role = await AuthService.getRole();
      if (token == null) {
        setState(() {
          errorMessage = 'Authentication token not found. Please log in again.';
          isLoading = false;
        });
        return;
      }
      _currentUserId = userId;
      _roleKey = _normalizeRoleKey(role ?? '');

      if (_currentUserId == null) {
        setState(() {
          errorMessage = 'Unable to resolve current user.';
          isLoading = false;
        });
        return;
      }

      final uri = Uri.parse('${api}logistics');
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final dataList = _parseLogisticsItems(decoded);
        final filtered = dataList.where(_isRelatedToCurrentUser).toList();
        setState(() {
          logisticsRequests = filtered;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage =
              'Failed to fetch logistics requests: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching logistics requests: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          _buildSummaryHeader(),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : errorMessage != null
                ? Center(child: Text(errorMessage!))
                : logisticsRequests.isEmpty
                ? const Center(child: Text('No logistics requests found.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: logisticsRequests.length,
                    itemBuilder: (context, index) {
                      return _buildLogisticsCard(logisticsRequests[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // Header showing active shipments count
  Widget _buildSummaryHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Color(primaryColour),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Logistics Requests",
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogisticsCard(LogisticsRequest request) {
    // Use model fields with defensives
    final status = request.status;
    final cost = request.cost;
    final pickupLocation = (request.pickupLocation.isNotEmpty)
        ? request.pickupLocation
        : 'Unknown Pickup';
    final deliveryLocation = (request.deliveryLocation.isNotEmpty)
        ? request.deliveryLocation
        : 'Unknown Delivery';
    final provider =
        request.assignedProvider?.displayName ?? 'Unknown Provider';
    final id = request.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Status and Cost Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatusBadge(status),
                Text(
                  "\$${cost.toStringAsFixed(2)}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            // Route Information
            Row(
              children: [
                Column(
                  children: [
                    const Icon(
                      Icons.radio_button_checked,
                      color: Colors.green,
                      size: 20,
                    ),
                    Container(width: 2, height: 30, color: Colors.grey[300]),
                    const Icon(Icons.location_on, color: Colors.red, size: 20),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pickupLocation.toString(),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        deliveryLocation.toString(),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Provider and Detail Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.local_shipping_outlined,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      provider.toString(),
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LogisticsRequestPage(
                          logisticsRequest: request,
                          onUpdate: fetchLogisticsRequests,
                          allowEditing: _roleKey == 'buyer',
                        ),
                      ),
                    );
                    fetchLogisticsRequests();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(primaryColour).withOpacity(0.1),
                    foregroundColor: Color(primaryColour),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text("View Delivery"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'IN_TRANSIT':
        color = Colors.blue;
        break;
      case 'AWAITING_PICKUP':
        color = Colors.orange;
        break;
      case 'DELIVERED':
        color = Colors.green;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showTrackingDetails(LogisticsRequest request) {
    final status = (request.status).toString().toUpperCase();
    final pickupLocation = request.pickupLocation.isNotEmpty
        ? request.pickupLocation
        : 'Unknown';
    final deliveryLocation = request.deliveryLocation.isNotEmpty
        ? request.deliveryLocation
        : 'Unknown';
    double progress = 0.2;
    if (status == 'AWAITING_PICKUP') {
      progress = 0.3;
    } else if (status == 'IN_TRANSIT') {
      progress = 0.6;
    } else if (status == 'DELIVERED') {
      progress = 1.0;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: 200,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              "Tracking ID: #LOG-${request.id}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 20),
            Text("Status: ${status.isEmpty ? 'UNKNOWN' : status}"),
            const SizedBox(height: 6),
            Text("Pickup: $pickupLocation"),
            const SizedBox(height: 6),
            Text("Delivery: $deliveryLocation"),
          ],
        ),
      ),
    );
  }
}
