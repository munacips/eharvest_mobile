import 'dart:convert';

import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/services/auth_service.dart';
import 'package:eharvest_mobile/services/logistics_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class LogisticsList extends StatefulWidget {
  const LogisticsList({super.key});

  @override
  State<LogisticsList> createState() => _LogisticsListState();
}

class _LogisticsListState extends State<LogisticsList> {
  List<Map<String, dynamic>> _requests = <Map<String, dynamic>>[];
  bool _isLoading = true;
  String? _error;
  final Set<int> _acceptingIds = <int>{};

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  String _normalizeStatus(String raw) {
    return raw.trim().toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');
  }

  bool _isPendingRequest(Map<String, dynamic> request) {
    final status = _normalizeStatus(_readString(request, <String>['status']));
    const closedStatuses = <String>{
      'accepted',
      'assigned',
      'rejected',
      'cancelled',
      'in_transit',
      'delivered',
      'completed',
    };
    if (status.isEmpty) {
      return true;
    }
    return !closedStatuses.contains(status);
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

  double _readDouble(Map<String, dynamic>? map, List<String> keys) {
    final text = _readString(map, keys);
    if (text.isEmpty) return 0;
    return double.tryParse(text) ?? 0;
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

  Map<String, dynamic>? _readMap(
    Map<String, dynamic>? source,
    List<String> keys,
  ) {
    if (source == null) return null;
    for (final key in keys) {
      final value = source[key];
      if (value is Map<String, dynamic>) {
        return value;
      }
      if (value is Map) {
        return value.map((k, v) => MapEntry(k.toString(), v));
      }
    }
    return null;
  }

  String _fullName(
    Map<String, dynamic>? person, {
    String fallback = 'Unknown',
  }) {
    if (person == null || person.isEmpty) {
      return fallback;
    }

    final company = _readString(person, <String>[
      'companyName',
      'company_name',
    ]);
    if (company.isNotEmpty) {
      return company;
    }

    final first = _readString(person, <String>['firstName', 'first_name']);
    final last = _readString(person, <String>['lastName', 'last_name']);
    final combined = '$first $last'.trim();
    if (combined.isNotEmpty) {
      return combined;
    }

    final username = _readString(person, <String>['username']);
    if (username.isNotEmpty) {
      return username;
    }

    return fallback;
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await AuthService.getToken();
      if (token == null) {
        setState(() {
          _error = 'Authentication token not found. Please log in again.';
          _isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('${api}logistics'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        setState(() {
          _error =
              'Failed to fetch logistics requests (${response.statusCode}).';
          _isLoading = false;
        });
        return;
      }

      final decoded = json.decode(response.body);
      List<dynamic> items = <dynamic>[];
      if (decoded is List) {
        items = decoded;
      } else if (decoded is Map<String, dynamic> &&
          decoded['content'] is List) {
        items = decoded['content'] as List<dynamic>;
      }

      final mapped = items
          .whereType<Map>()
          .map<Map<String, dynamic>>(
            (e) => e.map((k, v) => MapEntry(k.toString(), v)),
          )
          .where(_isPendingRequest)
          .toList();

      setState(() {
        _requests = mapped;
        _error = null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error fetching logistics requests: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshRequests() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        setState(() {
          _error = 'Authentication token not found. Please log in again.';
        });
        return;
      }

      final response = await http.get(
        Uri.parse('${api}logistics'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        setState(() {
          _error =
              'Failed to fetch logistics requests (${response.statusCode}).';
        });
        return;
      }

      final decoded = json.decode(response.body);
      List<dynamic> items = <dynamic>[];
      if (decoded is List) {
        items = decoded;
      } else if (decoded is Map<String, dynamic> &&
          decoded['content'] is List) {
        items = decoded['content'] as List<dynamic>;
      }

      final mapped = items
          .whereType<Map>()
          .map<Map<String, dynamic>>(
            (e) => e.map((k, v) => MapEntry(k.toString(), v)),
          )
          .where(_isPendingRequest)
          .toList();

      setState(() {
        _requests = mapped;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = 'Error fetching logistics requests: $e';
      });
    }
  }

  String _friendlyAcceptError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    final lowerMessage = message.toLowerCase();
    if (lowerMessage.contains('insufficient') &&
        lowerMessage.contains('buyer') &&
        lowerMessage.contains('balance')) {
      return 'Cannot accept this request because the buyer has insufficient USD funds for logistics escrow.';
    }
    return message.isEmpty ? 'Unable to accept this request right now.' : message;
  }

  Future<void> _acceptRequest(Map<String, dynamic> request) async {
    final requestId = _readInt(request, <String>['id'], fallback: -1);
    if (requestId <= 0) {
      return;
    }

    setState(() {
      _acceptingIds.add(requestId);
    });

    try {
      final token = await AuthService.getToken();
      final providerId = await AuthService.getUserId();
      if (token == null || providerId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication error. Please log in again.'),
          ),
        );
        return;
      }

      final updated = await LogisticsService.acceptRequest(
        requestId,
        providerId,
      );
      if (!mounted) return;
      final escrowText = updated.escrowHeld
          ? ' Buyer funds are now held in escrow.'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request #$requestId accepted successfully.$escrowText'),
        ),
      );
      setState(() {
        _requests.removeWhere(
          (item) => _readInt(item, <String>['id'], fallback: -1) == requestId,
        );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyAcceptError(e))));
    } finally {
      if (mounted) {
        setState(() {
          _acceptingIds.remove(requestId);
        });
      }
    }
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final requestId = _readInt(request, <String>['id']);
    final pickup = _readString(request, <String>[
      'pickupLocation',
      'pickup_location',
    ]);
    final delivery = _readString(request, <String>[
      'deliveryLocation',
      'delivery_location',
    ]);
    final cost = _readDouble(request, <String>['cost']);
    final statusText = _readString(request, <String>['status']);
    final order = _readMap(request, <String>['order']);
    final buyer = _readMap(order, <String>['buyer']);
    final farmer = _readMap(order, <String>['farmer']);
    final buyerPhone = _readString(buyer, <String>[
      'phoneNumber',
      'phone_number',
    ]);
    final createdAt = _readString(order, <String>['orderDate', 'order_date']);
    final accepting = _acceptingIds.contains(requestId);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Request #$requestId',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Text(
                    statusText.isEmpty ? 'PENDING' : statusText,
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _detailRow(
              Icons.upload_rounded,
              'From',
              pickup.isEmpty ? 'Unknown' : pickup,
            ),
            const SizedBox(height: 4),
            _detailRow(
              Icons.download_rounded,
              'To',
              delivery.isEmpty ? 'Unknown' : delivery,
            ),
            const SizedBox(height: 4),
            _detailRow(Icons.person_outline, 'Buyer', _fullName(buyer)),
            if (buyerPhone.isNotEmpty) ...[
              const SizedBox(height: 4),
              _detailRow(Icons.phone_outlined, 'Buyer Phone', buyerPhone),
            ],
            const SizedBox(height: 4),
            _detailRow(Icons.agriculture_outlined, 'Farmer', _fullName(farmer)),
            const SizedBox(height: 4),
            _detailRow(
              Icons.payments_outlined,
              'Price Set',
              '\$${cost.toStringAsFixed(2)}',
            ),
            if (createdAt.isNotEmpty) ...[
              const SizedBox(height: 4),
              _detailRow(Icons.schedule_outlined, 'Created', createdAt),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: accepting ? null : () => _acceptRequest(request),
                icon: accepting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(accepting ? 'Accepting...' : 'Accept Request'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(primaryColour),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: Colors.grey[700]),
        const SizedBox(width: 6),
        SizedBox(
          width: 76,
          child: Text(
            '$label:',
            style: TextStyle(
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Color(primaryColour),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
          ),
          child: const Text(
            'Pending Requests',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshRequests,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadRequests,
                        child: const Text('Retry'),
                      ),
                    ],
                  )
                : _requests.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      Center(
                        child: Text(
                          'No pending logistics requests right now.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: _requests.length,
                    itemBuilder: (context, index) =>
                        _buildRequestCard(_requests[index]),
                  ),
          ),
        ),
      ],
    );
  }
}
