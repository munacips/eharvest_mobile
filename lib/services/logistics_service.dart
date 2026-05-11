import 'dart:convert';

import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/services/auth_service.dart';
import 'package:http/http.dart' as http;

class LogisticsService {
  static Future<LogisticsRequest> getRequest(int requestId) async {
    final response = await http.get(
      Uri.parse('${api}logistics/$requestId'),
      headers: await _headers(),
    );
    return _decodeRequest(response, 'load logistics request');
  }

  static Future<LogisticsRequest> acceptRequest(
    int requestId,
    int providerId,
  ) async {
    final response = await http.post(
      Uri.parse('${api}logistics/$requestId/accept?providerId=$providerId'),
      headers: await _headers(),
    );
    return _decodeRequest(response, 'accept logistics request');
  }

  static Future<LogisticsRequest> rejectRequest(
    int requestId,
    int providerId,
  ) async {
    final response = await http.post(
      Uri.parse('${api}logistics/$requestId/reject?providerId=$providerId'),
      headers: await _headers(),
    );
    return _decodeRequest(response, 'reject logistics request');
  }

  static Future<LogisticsRequest> holdEscrow(int requestId) async {
    final response = await http.post(
      Uri.parse('${api}logistics/$requestId/hold-escrow'),
      headers: await _headers(),
    );
    return _decodeRequest(response, 'hold logistics escrow');
  }

  static Future<LogisticsRequest> markInTransit(int requestId) async {
    final response = await http.post(
      Uri.parse('${api}logistics/$requestId/in-transit'),
      headers: await _headers(),
    );
    return _decodeRequest(response, 'mark delivery in transit');
  }

  static Future<LogisticsRequest> markDelivered(int requestId) async {
    final response = await http.post(
      Uri.parse('${api}logistics/$requestId/delivered'),
      headers: await _headers(),
    );
    return _decodeRequest(response, 'confirm delivery');
  }

  static Future<LogisticsRequest> releaseEscrow(int requestId) async {
    final response = await http.post(
      Uri.parse('${api}logistics/$requestId/release-escrow'),
      headers: await _headers(),
    );
    return _decodeRequest(response, 'release logistics escrow');
  }

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    if (token == null) {
      throw Exception('Authentication error. Please log in again.');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static LogisticsRequest _decodeRequest(http.Response response, String label) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Failed to $label (${response.statusCode}).';
      final body = response.body.trim();
      try {
        final decoded = json.decode(body);
        if (decoded is Map<String, dynamic>) {
          message =
              decoded['message']?.toString() ??
              decoded['error']?.toString() ??
              message;
        }
      } catch (_) {
        if (body.isNotEmpty) {
          message = body;
        }
      }
      throw Exception(message);
    }

    final decoded = json.decode(response.body);
    if (decoded is Map<String, dynamic>) {
      return LogisticsRequest.fromJson(decoded);
    }
    throw Exception('Invalid logistics response from server.');
  }
}
