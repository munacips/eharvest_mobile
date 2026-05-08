import 'dart:convert';

import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/services/auth_service.dart';
import 'package:http/http.dart' as http;

class PaymentService {
  static Future<Map<String, dynamic>> initiatePayment(
    Map<String, dynamic> payload,
  ) async {
    final token = await AuthService.getToken();
    if (token == null) {
      throw Exception('Authentication error. Please log in again.');
    }

    final response = await http.post(
      Uri.parse('${api}payments/init'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(payload),
    );
    return _decodeObjectResponse(response, 'payment');
  }

  static Future<Map<String, dynamic>> getPaymentReturn(String reference) async {
    final token = await AuthService.getToken();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final uri = Uri.parse(
      '${api}payments/return',
    ).replace(queryParameters: {'reference': reference});
    final response = await http.get(uri, headers: headers);
    return _decodeObjectResponse(response, 'payment status');
  }

  static Future<Map<String, dynamic>> fetchCurrentProfile() async {
    final token = await AuthService.getToken();
    final userId = await AuthService.getUserId();
    final role = await AuthService.getRole();
    if (token == null || userId == null) {
      throw Exception('Authentication error. Please log in again.');
    }

    final roleKey = (role ?? '').trim().toLowerCase().replaceAll(
      RegExp(r'[\s-]+'),
      '_',
    );
    final preferred = <String, String>{
      'farmer': 'farmers',
      'buyer': 'buyers',
      'logistics': 'logistics-providers',
      'logistics_provider': 'logistics-providers',
      'logisticsprovider': 'logistics-providers',
    }[roleKey];
    final endpoints = <String>[
      if (preferred != null) preferred,
      'buyers',
      'farmers',
      'logistics-providers',
      'users',
    ];

    for (final endpoint in endpoints.toSet()) {
      final response = await http.get(
        Uri.parse('$api$endpoint/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
    }

    throw Exception('Unable to refresh wallet profile.');
  }

  static double balanceForCurrency(
    Map<String, dynamic> profile,
    String currency,
  ) {
    final key = currency.toUpperCase() == 'ZIG'
        ? (profile['zigBalance'] ?? profile['zig_balance'])
        : (profile['usdBalance'] ?? profile['usd_balance']);
    return key is num ? key.toDouble() : double.tryParse('$key') ?? 0;
  }

  static Map<String, dynamic> _decodeObjectResponse(
    http.Response response,
    String label,
  ) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Failed to load $label (${response.statusCode}).';
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

    final decoded = response.body.isEmpty ? <String, dynamic>{} : json.decode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw Exception('Invalid $label response from server.');
  }
}
