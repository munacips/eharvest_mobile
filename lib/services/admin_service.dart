import 'dart:convert';

import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/models/admin_models.dart';
import 'package:eharvest_mobile/services/auth_service.dart';
import 'package:eharvest_mobile/services/subscription_service.dart';
import 'package:http/http.dart' as http;

class AdminService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication error. Please log in again.');
    }
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Map<String, dynamic> _decodeObject(http.Response response, String action) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
      throw Exception('Unexpected response while trying to $action.');
    }
    throw Exception(_errorMessage(response, action));
  }

  static List<Map<String, dynamic>> _decodeList(
    http.Response response,
    String action,
  ) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return [];
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
            .toList();
      }
      if (decoded is Map && decoded['content'] is List) {
        return (decoded['content'] as List)
            .whereType<Map>()
            .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
            .toList();
      }
      throw Exception('Unexpected response while trying to $action.');
    }
    throw Exception(_errorMessage(response, action));
  }

  static String _errorMessage(http.Response response, String action) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        final message = decoded['message'] ?? decoded['error'] ?? decoded['details'];
        if (message != null && message.toString().isNotEmpty) {
          return message.toString();
        }
      }
    } catch (_) {}
    return 'Failed to $action (${response.statusCode}).';
  }

  static Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('$adminApi$path').replace(queryParameters: query);
  }

  // --- Dashboard ---

  static Future<AdminDashboardStats> fetchDashboardStats() async {
    final response = await http.get(
      _uri('dashboard/stats'),
      headers: await _headers(),
    );
    return AdminDashboardStats.fromJson(_decodeObject(response, 'load dashboard stats'));
  }

  // --- Users ---

  static Future<List<User>> fetchUsers() async {
    final response = await http.get(_uri('users'), headers: await _headers());
    return _decodeList(response, 'load users').map(User.fromJson).toList();
  }

  static Future<User> fetchUser(int id) async {
    final response = await http.get(_uri('users/$id'), headers: await _headers());
    return User.fromJson(_decodeObject(response, 'load user'));
  }

  static Future<User> createUser(Map<String, dynamic> payload) async {
    final response = await http.post(
      _uri('users'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    return User.fromJson(_decodeObject(response, 'create user'));
  }

  static Future<User> updateUser(int id, Map<String, dynamic> payload) async {
    final response = await http.put(
      _uri('users/$id'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    return User.fromJson(_decodeObject(response, 'update user'));
  }

  static Future<void> deleteUser(int id) async {
    final response = await http.delete(_uri('users/$id'), headers: await _headers());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response, 'delete user'));
    }
  }

  static Future<void> setUserActive(int id, bool active) async {
    final response = await http.put(
      _uri('users/$id/active', {'active': active.toString()}),
      headers: await _headers(),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response, 'update user active status'));
    }
  }

  static Future<User> setUserVerified(int id, bool verified) async {
    final response = await http.put(
      _uri('users/$id/verified', {'verified': verified.toString()}),
      headers: await _headers(),
    );
    return User.fromJson(_decodeObject(response, 'update user verification'));
  }

  // --- Farmers ---

  static Future<PagedResult<User>> searchFarmers({
    String? search,
    bool? active,
    bool? verified,
    int page = 0,
    int size = 20,
  }) async {
    final query = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
      if (search != null && search.isNotEmpty) 'search': search,
      if (active != null) 'active': active.toString(),
      if (verified != null) 'verified': verified.toString(),
    };
    final response = await http.get(
      _uri('farmers', query),
      headers: await _headers(),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        return PagedResult.fromJson(
          decoded.map((key, value) => MapEntry(key.toString(), value)),
          User.fromJson,
        );
      }
    }
    throw Exception(_errorMessage(response, 'search farmers'));
  }

  static Future<User> fetchFarmer(int id) async {
    final response = await http.get(_uri('farmers/$id'), headers: await _headers());
    return User.fromJson(_decodeObject(response, 'load farmer'));
  }

  static Future<User> createFarmer(Map<String, dynamic> payload) async {
    final response = await http.post(
      _uri('farmers'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    return User.fromJson(_decodeObject(response, 'create farmer'));
  }

  static Future<User> updateFarmer(int id, Map<String, dynamic> payload) async {
    final response = await http.put(
      _uri('farmers/$id'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    return User.fromJson(_decodeObject(response, 'update farmer'));
  }

  static Future<void> deleteFarmer(int id) async {
    final response = await http.delete(_uri('farmers/$id'), headers: await _headers());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response, 'delete farmer'));
    }
  }

  // --- Buyers ---

  static Future<PagedResult<User>> searchBuyers({
    String? search,
    bool? active,
    bool? verified,
    int page = 0,
    int size = 20,
  }) async {
    final query = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
      if (search != null && search.isNotEmpty) 'search': search,
      if (active != null) 'active': active.toString(),
      if (verified != null) 'verified': verified.toString(),
    };
    final response = await http.get(
      _uri('buyers', query),
      headers: await _headers(),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        return PagedResult.fromJson(
          decoded.map((key, value) => MapEntry(key.toString(), value)),
          User.fromJson,
        );
      }
    }
    throw Exception(_errorMessage(response, 'search buyers'));
  }

  static Future<User> fetchBuyer(int id) async {
    final response = await http.get(_uri('buyers/$id'), headers: await _headers());
    return User.fromJson(_decodeObject(response, 'load buyer'));
  }

  static Future<User> createBuyer(Map<String, dynamic> payload) async {
    final response = await http.post(
      _uri('buyers'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    return User.fromJson(_decodeObject(response, 'create buyer'));
  }

  static Future<User> updateBuyer(int id, Map<String, dynamic> payload) async {
    final response = await http.put(
      _uri('buyers/$id'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    return User.fromJson(_decodeObject(response, 'update buyer'));
  }

  static Future<void> deleteBuyer(int id) async {
    final response = await http.delete(_uri('buyers/$id'), headers: await _headers());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response, 'delete buyer'));
    }
  }

  // --- Logistics providers ---

  static Future<List<User>> fetchLogisticsProviders() async {
    final response = await http.get(
      _uri('logistics-providers'),
      headers: await _headers(),
    );
    return _decodeList(response, 'load logistics providers')
        .map(User.fromJson)
        .toList();
  }

  static Future<User> fetchLogisticsProvider(int id) async {
    final response = await http.get(
      _uri('logistics-providers/$id'),
      headers: await _headers(),
    );
    return User.fromJson(_decodeObject(response, 'load logistics provider'));
  }

  static Future<User> createLogisticsProvider(Map<String, dynamic> payload) async {
    final response = await http.post(
      _uri('logistics-providers'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    return User.fromJson(_decodeObject(response, 'create logistics provider'));
  }

  static Future<User> updateLogisticsProvider(
    int id,
    Map<String, dynamic> payload,
  ) async {
    final response = await http.put(
      _uri('logistics-providers/$id'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    return User.fromJson(_decodeObject(response, 'update logistics provider'));
  }

  static Future<void> deleteLogisticsProvider(int id) async {
    final response = await http.delete(
      _uri('logistics-providers/$id'),
      headers: await _headers(),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response, 'delete logistics provider'));
    }
  }

  // --- Produce ---

  static Future<List<Produce>> fetchProduce() async {
    final response = await http.get(_uri('produce'), headers: await _headers());
    return _decodeList(response, 'load produce').map(Produce.fromJson).toList();
  }

  static Future<Produce> fetchProduceItem(int id) async {
    final response = await http.get(_uri('produce/$id'), headers: await _headers());
    return Produce.fromJson(_decodeObject(response, 'load produce'));
  }

  static Future<Produce> createProduce(Map<String, dynamic> payload) async {
    final response = await http.post(
      _uri('produce'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    return Produce.fromJson(_decodeObject(response, 'create produce'));
  }

  static Future<Produce> updateProduce(int id, Map<String, dynamic> payload) async {
    final response = await http.put(
      _uri('produce/$id'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    return Produce.fromJson(_decodeObject(response, 'update produce'));
  }

  static Future<void> deleteProduce(int id) async {
    final response = await http.delete(_uri('produce/$id'), headers: await _headers());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response, 'delete produce'));
    }
  }

  // --- Vehicles ---

  static Future<List<Vehicle>> fetchVehicles() async {
    final response = await http.get(_uri('vehicles'), headers: await _headers());
    return _decodeList(response, 'load vehicles').map(Vehicle.fromJson).toList();
  }

  static Future<Vehicle> fetchVehicle(int id) async {
    final response = await http.get(_uri('vehicles/$id'), headers: await _headers());
    return Vehicle.fromJson(_decodeObject(response, 'load vehicle'));
  }

  static Future<Vehicle> createVehicle(Map<String, dynamic> payload) async {
    final response = await http.post(
      _uri('vehicles'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    return Vehicle.fromJson(_decodeObject(response, 'create vehicle'));
  }

  static Future<Vehicle> updateVehicle(int id, Map<String, dynamic> payload) async {
    final response = await http.put(
      _uri('vehicles/$id'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    return Vehicle.fromJson(_decodeObject(response, 'update vehicle'));
  }

  static Future<void> deleteVehicle(int id) async {
    final response = await http.delete(_uri('vehicles/$id'), headers: await _headers());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response, 'delete vehicle'));
    }
  }

  // --- Orders ---

  static Future<List<Order>> fetchOrders() async {
    final response = await http.get(_uri('orders'), headers: await _headers());
    return _decodeList(response, 'load orders').map(Order.fromJson).toList();
  }

  static Future<Order> fetchOrder(int id) async {
    final response = await http.get(_uri('orders/$id'), headers: await _headers());
    return Order.fromJson(_decodeObject(response, 'load order'));
  }

  static Future<Order> createOrder(Map<String, dynamic> payload) async {
    final response = await http.post(
      _uri('orders'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    return Order.fromJson(_decodeObject(response, 'create order'));
  }

  static Future<Order> updateOrder(int id, Map<String, dynamic> payload) async {
    final response = await http.put(
      _uri('orders/$id'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    return Order.fromJson(_decodeObject(response, 'update order'));
  }

  static Future<void> deleteOrder(int id) async {
    final response = await http.delete(_uri('orders/$id'), headers: await _headers());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response, 'delete order'));
    }
  }

  // --- Order items ---

  static Future<List<OrderItem>> fetchOrderItems() async {
    final response = await http.get(_uri('order-items'), headers: await _headers());
    return _decodeList(response, 'load order items').map(OrderItem.fromJson).toList();
  }

  static Future<OrderItem> fetchOrderItem(int id) async {
    final response = await http.get(
      _uri('order-items/$id'),
      headers: await _headers(),
    );
    return OrderItem.fromJson(_decodeObject(response, 'load order item'));
  }

  static Future<OrderItem> createOrderItem(Map<String, dynamic> payload) async {
    final response = await http.post(
      _uri('order-items'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    return OrderItem.fromJson(_decodeObject(response, 'create order item'));
  }

  static Future<OrderItem> updateOrderItem(int id, Map<String, dynamic> payload) async {
    final response = await http.put(
      _uri('order-items/$id'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    return OrderItem.fromJson(_decodeObject(response, 'update order item'));
  }

  static Future<void> deleteOrderItem(int id) async {
    final response = await http.delete(
      _uri('order-items/$id'),
      headers: await _headers(),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response, 'delete order item'));
    }
  }

  // --- Reviews ---

  static Future<List<Review>> fetchReviews() async {
    final response = await http.get(_uri('reviews'), headers: await _headers());
    return _decodeList(response, 'load reviews').map(Review.fromJson).toList();
  }

  static Future<Review> fetchReview(int id) async {
    final response = await http.get(_uri('reviews/$id'), headers: await _headers());
    return Review.fromJson(_decodeObject(response, 'load review'));
  }

  static Future<Review> createReview(Map<String, dynamic> payload) async {
    final response = await http.post(
      _uri('reviews'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    return Review.fromJson(_decodeObject(response, 'create review'));
  }

  static Future<Review> updateReview(int id, Map<String, dynamic> payload) async {
    final response = await http.put(
      _uri('reviews/$id'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    return Review.fromJson(_decodeObject(response, 'update review'));
  }

  static Future<void> deleteReview(int id) async {
    final response = await http.delete(_uri('reviews/$id'), headers: await _headers());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response, 'delete review'));
    }
  }

  // --- Logistics requests ---

  static Future<List<LogisticsRequest>> fetchLogisticsRequests() async {
    final response = await http.get(_uri('logistics'), headers: await _headers());
    return _decodeList(response, 'load logistics requests')
        .map(LogisticsRequest.fromJson)
        .toList();
  }

  static Future<LogisticsRequest> fetchLogisticsRequest(int id) async {
    final response = await http.get(
      _uri('logistics/$id'),
      headers: await _headers(),
    );
    return LogisticsRequest.fromJson(_decodeObject(response, 'load logistics request'));
  }

  static Future<LogisticsRequest> createLogisticsRequest(
    Map<String, dynamic> payload,
  ) async {
    final response = await http.post(
      _uri('logistics'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    return LogisticsRequest.fromJson(
      _decodeObject(response, 'create logistics request'),
    );
  }

  static Future<LogisticsRequest> updateLogisticsRequest(
    int id,
    Map<String, dynamic> payload,
  ) async {
    final response = await http.put(
      _uri('logistics/$id'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    return LogisticsRequest.fromJson(
      _decodeObject(response, 'update logistics request'),
    );
  }

  static Future<void> deleteLogisticsRequest(int id) async {
    final response = await http.delete(
      _uri('logistics/$id'),
      headers: await _headers(),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response, 'delete logistics request'));
    }
  }

  // --- Subscriptions ---

  static Future<ProduceSubscription> fetchSubscription(int id) async {
    final response = await http.get(
      _uri('subscriptions/$id'),
      headers: await _headers(),
    );
    return ProduceSubscription.fromJson(
      _decodeObject(response, 'load subscription'),
    );
  }

  static Future<List<ProduceSubscription>> fetchSubscriptionsByBuyer(
    int buyerId,
  ) async {
    final response = await http.get(
      _uri('subscriptions/buyer/$buyerId'),
      headers: await _headers(),
    );
    return _decodeList(response, 'load buyer subscriptions')
        .map(ProduceSubscription.fromJson)
        .toList();
  }

  static Future<List<ProduceSubscription>> fetchSubscriptionsByFarmer(
    int farmerId,
  ) async {
    final response = await http.get(
      _uri('subscriptions/farmer/$farmerId'),
      headers: await _headers(),
    );
    return _decodeList(response, 'load farmer subscriptions')
        .map(ProduceSubscription.fromJson)
        .toList();
  }

  static Future<ProduceSubscription> createSubscription(
    Map<String, dynamic> payload,
  ) async {
    final response = await http.post(
      _uri('subscriptions'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    return ProduceSubscription.fromJson(
      _decodeObject(response, 'create subscription'),
    );
  }

  static Future<ProduceSubscription> updateSubscription(
    int id,
    Map<String, dynamic> payload,
  ) async {
    final response = await http.put(
      _uri('subscriptions/$id'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    return ProduceSubscription.fromJson(
      _decodeObject(response, 'update subscription'),
    );
  }

  static Future<ProduceSubscription> cancelSubscription(int id) async {
    final response = await http.post(
      _uri('subscriptions/$id/cancel'),
      headers: await _headers(),
    );
    return ProduceSubscription.fromJson(
      _decodeObject(response, 'cancel subscription'),
    );
  }

  // --- Dispute reports ---

  static Future<List<DisputeReport>> fetchDisputeReports({bool? attendedTo}) async {
    final response = await http.get(
      _uri('dispute-reports', attendedTo == null ? null : {'attendedTo': attendedTo.toString()}),
      headers: await _headers(),
    );
    return _decodeList(response, 'load dispute reports')
        .map(DisputeReport.fromJson)
        .toList();
  }

  static Future<DisputeReport> fetchDisputeReport(int id) async {
    final response = await http.get(
      _uri('dispute-reports/$id'),
      headers: await _headers(),
    );
    return DisputeReport.fromJson(_decodeObject(response, 'load dispute report'));
  }

  static Future<DisputeReport> markDisputeAttended(int id, bool attendedTo) async {
    final response = await http.put(
      _uri('dispute-reports/$id/attended', {'attendedTo': attendedTo.toString()}),
      headers: await _headers(),
    );
    return DisputeReport.fromJson(
      _decodeObject(response, 'update dispute report'),
    );
  }

  static Future<void> deleteDisputeReport(int id) async {
    final response = await http.delete(
      _uri('dispute-reports/$id'),
      headers: await _headers(),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response, 'delete dispute report'));
    }
  }

  // --- Transactions ---

  static Future<List<AdminTransaction>> fetchTransactions({
    String? status,
    String? type,
    String? currency,
  }) async {
    final query = <String, String>{
      if (status != null && status.isNotEmpty) 'status': status,
      if (type != null && type.isNotEmpty) 'type': type,
      if (currency != null && currency.isNotEmpty) 'currency': currency,
    };
    final response = await http.get(
      _uri('transactions', query.isEmpty ? null : query),
      headers: await _headers(),
    );
    return _decodeList(response, 'load transactions')
        .map(AdminTransaction.fromJson)
        .toList();
  }
}
