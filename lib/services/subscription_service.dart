import 'dart:convert';

import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/services/auth_service.dart';
import 'package:http/http.dart' as http;

class SubscriptionItem {
  final int id;
  final int produceId;
  final int quantity;
  final double unitPrice;

  const SubscriptionItem({
    required this.id,
    required this.produceId,
    required this.quantity,
    required this.unitPrice,
  });

  factory SubscriptionItem.fromJson(Map<String, dynamic> json) {
    return SubscriptionItem(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      produceId: int.tryParse(json['produceId']?.toString() ?? '0') ?? 0,
      quantity: int.tryParse(json['quantity']?.toString() ?? '0') ?? 0,
      unitPrice: double.tryParse(json['unitPrice']?.toString() ?? '0') ?? 0.0,
    );
  }

  Map<String, dynamic> toRequestJson() {
    return {
      'produceId': produceId,
      'quantity': quantity,
      'unitPrice': unitPrice,
    };
  }
}

class ProduceSubscription {
  final int id;
  final int buyerId;
  final int farmerId;
  final String frequency;
  final String status;
  final bool requiresLogistics;
  final String? pickupAddress;
  final String currency;
  final DateTime startDate;
  final DateTime nextDeliveryDate;
  final Map<String, dynamic>? buyer;
  final Map<String, dynamic>? farmer;
  final List<SubscriptionItem> items;
  final double totalAmount;

  const ProduceSubscription({
    required this.id,
    required this.buyerId,
    required this.farmerId,
    required this.frequency,
    required this.status,
    required this.requiresLogistics,
    required this.pickupAddress,
    required this.currency,
    required this.startDate,
    required this.nextDeliveryDate,
    required this.buyer,
    required this.farmer,
    required this.items,
    required this.totalAmount,
  });

  factory ProduceSubscription.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return ProduceSubscription(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      buyerId: int.tryParse(json['buyerId']?.toString() ?? '0') ?? 0,
      farmerId: int.tryParse(json['farmerId']?.toString() ?? '0') ?? 0,
      frequency: (json['frequency'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      requiresLogistics: json['requiresLogistics'] == true,
      pickupAddress: json['pickupAddress']?.toString(),
      currency: (json['currency'] ?? 'USD').toString(),
      startDate:
          DateTime.tryParse(json['startDate']?.toString() ?? '') ??
          DateTime.now(),
      nextDeliveryDate:
          DateTime.tryParse(json['nextDeliveryDate']?.toString() ?? '') ??
          DateTime.now(),
      buyer: json['buyer'] is Map<String, dynamic>
          ? json['buyer'] as Map<String, dynamic>
          : null,
      farmer: json['farmer'] is Map<String, dynamic>
          ? json['farmer'] as Map<String, dynamic>
          : null,
      items: rawItems is List
          ? rawItems
                .whereType<Map<String, dynamic>>()
                .map(SubscriptionItem.fromJson)
                .toList()
          : const [],
      totalAmount:
          double.tryParse(json['totalAmount']?.toString() ?? '0') ?? 0.0,
    );
  }

  String get farmerName => _displayName(farmer, fallback: 'Farmer #$farmerId');
  String get buyerName => _displayName(buyer, fallback: 'Buyer #$buyerId');

  static String _displayName(Map<String, dynamic>? user, {required String fallback}) {
    if (user == null) return fallback;
    final firstName = (user['firstName'] ?? user['first_name'] ?? '').toString();
    final lastName = (user['lastName'] ?? user['last_name'] ?? '').toString();
    final fullName = '$firstName $lastName'.trim();
    if (fullName.isNotEmpty) return fullName;
    final username = (user['username'] ?? '').toString();
    return username.isNotEmpty ? username : fallback;
  }
}

class SubscriptionService {
  static Future<ProduceSubscription> createSubscription(
    Map<String, dynamic> payload,
  ) async {
    final response = await _authedRequest(
      (headers) => http.post(
        Uri.parse('${api}subscriptions'),
        headers: headers,
        body: jsonEncode(payload),
      ),
    );
    return ProduceSubscription.fromJson(_decodeObject(response, 'create subscription'));
  }

  static Future<ProduceSubscription> fetchSubscription(int id) async {
    final response = await _authedRequest(
      (headers) => http.get(
        Uri.parse('${api}subscriptions/$id'),
        headers: headers,
      ),
    );
    return ProduceSubscription.fromJson(_decodeObject(response, 'fetch subscription'));
  }

  static Future<List<ProduceSubscription>> fetchBuyerSubscriptions(
    int buyerId,
  ) async {
    return _fetchList('${api}subscriptions/buyer/$buyerId');
  }

  static Future<List<ProduceSubscription>> fetchFarmerSubscriptions(
    int farmerId,
  ) async {
    return _fetchList('${api}subscriptions/farmer/$farmerId');
  }

  static Future<ProduceSubscription> updateSubscription(
    int id,
    Map<String, dynamic> payload,
  ) async {
    final response = await _authedRequest(
      (headers) => http.put(
        Uri.parse('${api}subscriptions/$id'),
        headers: headers,
        body: jsonEncode(payload),
      ),
    );
    return ProduceSubscription.fromJson(_decodeObject(response, 'update subscription'));
  }

  static Future<ProduceSubscription> pauseSubscription(int id) {
    return _postAction(id, 'pause');
  }

  static Future<ProduceSubscription> resumeSubscription(int id) {
    return _postAction(id, 'resume');
  }

  static Future<ProduceSubscription> cancelSubscription(int id) {
    return _postAction(id, 'cancel');
  }

  static Future<ProduceSubscription> processSubscription(int id) {
    return _postAction(id, 'process');
  }

  static Future<List<ProduceSubscription>> _fetchList(String url) async {
    final response = await _authedRequest(
      (headers) => http.get(Uri.parse(url), headers: headers),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwResponse(response, 'fetch subscriptions');
    }
    final decoded = response.body.isEmpty ? [] : jsonDecode(response.body);
    final list = decoded is Map<String, dynamic> && decoded['content'] is List
        ? decoded['content'] as List
        : decoded is List
        ? decoded
        : const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(ProduceSubscription.fromJson)
        .toList();
  }

  static Future<ProduceSubscription> _postAction(int id, String action) async {
    final response = await _authedRequest(
      (headers) => http.post(
        Uri.parse('${api}subscriptions/$id/$action'),
        headers: headers,
      ),
    );
    return ProduceSubscription.fromJson(_decodeObject(response, action));
  }

  static Future<http.Response> _authedRequest(
    Future<http.Response> Function(Map<String, String> headers) request,
  ) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('No auth token');
    return request({
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    });
  }

  static Map<String, dynamic> _decodeObject(http.Response response, String label) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwResponse(response, label);
    }
    if (response.body.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    throw Exception('Unexpected response while trying to $label.');
  }

  static Never _throwResponse(http.Response response, String label) {
    var message = 'Failed to $label: ${response.statusCode}';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        message =
            decoded['message']?.toString() ??
            decoded['error']?.toString() ??
            message;
      }
    } catch (_) {}
    throw Exception(message);
  }
}
