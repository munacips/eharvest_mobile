import 'package:flutter/material.dart';
import 'package:eharvest_mobile/global_variables.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:eharvest_mobile/services/auth_service.dart';
import 'package:eharvest_mobile/services/ai_service.dart';

class LogisticsRequestPage extends StatefulWidget {
  final LogisticsRequest logisticsRequest;
  final VoidCallback? onUpdate;

  const LogisticsRequestPage({
    super.key,
    required this.logisticsRequest,
    this.onUpdate,
  });

  @override
  State<LogisticsRequestPage> createState() => _LogisticsRequestPageState();
}

class _LogisticsRequestPageState extends State<LogisticsRequestPage> {
  late LogisticsRequest _logisticsRequest;
  late TextEditingController _deliveryLocationController;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _matchLoading = false;
  List<Map<String, dynamic>> _matches = [];
  String? _matchError;

  @override
  void initState() {
    super.initState();
    _logisticsRequest = widget.logisticsRequest;
    _deliveryLocationController = TextEditingController(
      text: _logisticsRequest.deliveryLocation,
    );
  }

  @override
  void dispose() {
    _deliveryLocationController.dispose();
    super.dispose();
  }

  Future<void> _updateLogisticsRequest() async {
    if (_deliveryLocationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter delivery location')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final token = await AuthService.getToken();
      if (token == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Authentication error')));
        return;
      }

      final response = await http.put(
        Uri.parse('${api}logistics/${_logisticsRequest.id}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'deliveryLocation': _deliveryLocationController.text,
          'pickupLocation': _logisticsRequest.pickupLocation,
          'status': _logisticsRequest.status,
          'cost': _logisticsRequest.cost,
        }),
      );

      if (response.statusCode == 200) {
        final updatedJson = json.decode(response.body);
        setState(() {
          _logisticsRequest = LogisticsRequest.fromJson(updatedJson);
          _isEditing = false;
        });
        widget.onUpdate?.call();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logistics request updated successfully'),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update logistics request')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _fetchMatches() async {
    setState(() {
      _matchLoading = true;
      _matchError = null;
      _matches = [];
    });
    try {
      final response = await AiService.logisticsMatch({
        'request_id': _logisticsRequest.id.toString(),
        'top_n': 3,
      });
      if (response is Map<String, dynamic>) {
        final matches = response['matches'];
        if (matches is List) {
          setState(() {
            _matches = matches.whereType<Map<String, dynamic>>().toList();
          });
        }
      }
    } catch (e) {
      setState(() {
        _matchError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _matchLoading = false;
        });
      }
    }
  }

  String _providerName(Map<String, dynamic> provider) {
    final name = provider['name'] ?? provider['companyName'];
    if (name != null && name.toString().trim().isNotEmpty) {
      return name.toString();
    }
    final username = provider['username'];
    if (username != null && username.toString().trim().isNotEmpty) {
      return username.toString();
    }
    final id = provider['id'] ?? provider['provider_id'];
    return id != null ? 'Provider $id' : 'Provider';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Color(primaryColour),
        elevation: 0,
        title: Text(
          'Logistics Request #${_logisticsRequest.id}',
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  _deliveryLocationController.text =
                      _logisticsRequest.deliveryLocation;
                });
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              decoration: BoxDecoration(
                color: Color(primaryColour),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.local_shipping, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Request #${_logisticsRequest.id}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _statusChip(_logisticsRequest.status),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.attach_money, color: Colors.white70, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Cost: ${_logisticsRequest.cost.toStringAsFixed(2)}',
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
            const SizedBox(height: 30),
            // Details Section
            const Text(
              'Logistics Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailCard(
              icon: Icons.location_on,
              label: 'Pickup Location',
              value: _logisticsRequest.pickupLocation,
            ),
            const SizedBox(height: 12),
            _buildDetailCard(
              icon: Icons.location_on_outlined,
              label: 'Delivery Location',
              value: _isEditing ? null : _logisticsRequest.deliveryLocation,
              editingWidget: _isEditing
                  ? TextField(
                      controller: _deliveryLocationController,
                      decoration: InputDecoration(
                        hintText: 'Enter delivery location',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 12,
                        ),
                      ),
                      maxLines: null,
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            _buildDetailCard(
              icon: Icons.info_outline,
              label: 'Status',
              value: _logisticsRequest.status,
            ),
            if (_logisticsRequest.assignedProvider != null)
              Column(
                children: [
                  const SizedBox(height: 12),
                  _buildDetailCard(
                    icon: Icons.person,
                    label: 'Assigned Provider',
                    value: _logisticsRequest.assignedProvider!.displayName,
                  ),
                ],
              ),
            const SizedBox(height: 24),
            _buildMatchesSection(),
            const SizedBox(height: 30),
            if (_isEditing)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _updateLogisticsRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(primaryColour),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Save Changes',
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
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required String label,
    String? value,
    Widget? editingWidget,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Color(primaryColour), size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (value != null)
            Text(
              value,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
          if (editingWidget != null) editingWidget,
        ],
      ),
    );
  }

  Widget _buildMatchesSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: Color(primaryColour), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Suggested Providers',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton(
                onPressed: _matchLoading ? null : _fetchMatches,
                child: _matchLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Find Matches'),
              ),
            ],
          ),
          if (_matchError != null)
            Text(
              _matchError!,
              style: TextStyle(color: Colors.red[700], fontSize: 12),
            ),
          if (_matches.isEmpty && !_matchLoading && _matchError == null)
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Text(
                'No matches yet. Tap Find Matches to see suggestions.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          if (_matches.isNotEmpty) ...[
            const SizedBox(height: 8),
            ..._matches.map((match) {
              final provider = match['provider'] as Map<String, dynamic>? ?? {};
              final score = match['score'];
              final cost = match['estimated_cost'];
              final distance = match['pickup_distance_km'];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  children: [
                    Icon(Icons.local_shipping, color: Color(primaryColour)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _providerName(provider),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Score: ${score ?? '-'} | Cost: ${cost ?? '-'} | Distance: ${distance ?? '-'} km',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'pending':
        color = Colors.orange;
        break;
      case 'assigned':
        color = Colors.blue;
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
}
