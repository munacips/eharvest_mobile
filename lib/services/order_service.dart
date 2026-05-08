import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/services/auth_service.dart';

class OrderService {
  static Future<List<Order>> fetchOrdersForFarmer(int farmerId) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('No auth token');
    final response = await http.get(
      Uri.parse('${api}orders/farmer/$farmerId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((e) => Order.fromJson(e)).toList();
    } else {
      throw Exception('Failed to fetch orders: ${response.statusCode}');
    }
  }

  static Future<bool> updateOrderStatus(Order order, String status) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('No auth token');
    final response = await http.put(
      Uri.parse('${api}orders/${order.id}'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'id': order.id,
        'totalAmount': order.totalAmount,
        'status': status,
        'buyerId': order.buyer?.id,
        'farmerId': order.farmer?.id,
        'logisticsRequestId': order.logisticsRequest?.id,
        'escrowReleased': order.escrowReleased,
      }),
    );
    return response.statusCode == 200;
  }

  static Future<Order> createOrder(Map<String, dynamic> payload) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('No auth token');
    final response = await http.post(
      Uri.parse('${api}orders'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(payload),
    );
    return _decodeOrderResponse(response, 'create order');
  }

  static Future<Map<String, dynamic>> holdEscrow(int orderId) {
    return _postOrderAction(orderId, 'hold-escrow');
  }

  static Future<Map<String, dynamic>> acceptOrder(int orderId) {
    return _postOrderAction(orderId, 'accept');
  }

  static Future<Map<String, dynamic>> confirmDeliveryStarted(int orderId) {
    return _postOrderAction(orderId, 'delivery-started');
  }

  static Future<Map<String, dynamic>> confirmDelivery(int orderId) {
    return _postOrderAction(orderId, 'delivery-confirmed');
  }

  static Future<Map<String, dynamic>> rejectOrder(int orderId) {
    return _postOrderAction(orderId, 'reject');
  }

  static Future<Map<String, dynamic>> _postOrderAction(
    int orderId,
    String action,
  ) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('No auth token');
    final response = await http.post(
      Uri.parse('${api}orders/$orderId/$action'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    return _decodeObjectResponse(response, action);
  }

  static Order _decodeOrderResponse(http.Response response, String label) {
    final decoded = _decodeObjectResponse(response, label);
    return Order.fromJson(decoded);
  }

  static Map<String, dynamic> _decodeObjectResponse(
    http.Response response,
    String label,
  ) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Failed to $label: ${response.statusCode}';
      try {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) {
          message =
              decoded['message']?.toString() ??
              decoded['error']?.toString() ??
              message;
        }
      } catch (_) {}
      throw Exception(message);
    }
    if (response.body.isEmpty) {
      return <String, dynamic>{};
    }
    final decoded = json.decode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return <String, dynamic>{'status': decoded.toString()};
  }
}
