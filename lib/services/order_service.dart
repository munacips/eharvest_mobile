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
}
