import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/services/auth_service.dart';
import 'package:http/http.dart' as http;

class LogisticsPage extends StatefulWidget {
  const LogisticsPage({super.key});

  @override
  State<LogisticsPage> createState() => LogisticsPageState();
}

class LogisticsPageState extends State<LogisticsPage> {
  List<Map<String, dynamic>> logisticsRequests = [];
  bool isLoading = true;
  String? errorMessage;

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
      if (token == null) {
        setState(() {
          errorMessage = 'Authentication token not found. Please log in again.';
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
        List<dynamic> dataList;
        if (decoded is List) {
          dataList = decoded;
        } else if (decoded is Map<String, dynamic> &&
            decoded['content'] is List) {
          dataList = decoded['content'] as List<dynamic>;
        } else {
          dataList = [];
        }
        setState(() {
          logisticsRequests = dataList.cast<Map<String, dynamic>>();
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage =
              'Failed to fetch logistics requests: \\${response.statusCode}';
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

  Widget _buildLogisticsCard(Map<String, dynamic> request) {
    // Defensive: fallback for missing/null fields
    final status = (request['status'] ?? '').toString();
    final cost = (request['cost'] is num)
        ? (request['cost'] as num).toDouble()
        : double.tryParse(request['cost']?.toString() ?? '') ?? 0.0;
    final pickupLocation =
        request['pickupLocation'] ??
        request['pickup_location'] ??
        'Unknown Pickup';
    final deliveryLocation =
        request['deliveryLocation'] ??
        request['delivery_location'] ??
        'Unknown Delivery';
    final provider = request['provider'] ?? 'Unknown Provider';
    final produce = request['produce'] ?? 'Produce';
    final id = request['id'] ?? 'ID';

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
                  onPressed: () =>
                      _showTrackingDetails({'id': id, 'produce': produce}),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(primaryColour).withOpacity(0.1),
                    foregroundColor: Color(primaryColour),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text("Track Order"),
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

  void _showTrackingDetails(Map<String, dynamic> request) {
    // This could navigate to a real-time Google Maps screen later
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: 200,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              "Tracking ID: #LOG-${request['id']}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const LinearProgressIndicator(value: 0.6), // Mock progress
            const SizedBox(height: 20),
            Text("Current Item: ${request['produce']}"),
            const Text(
              "Estimated Delivery: 2 Hours",
              style: TextStyle(color: Colors.green),
            ),
          ],
        ),
      ),
    );
  }
}
