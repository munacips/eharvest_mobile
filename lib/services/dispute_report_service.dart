import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/services/auth_service.dart';
import 'package:eharvest_mobile/models/dispute_report.dart';

class DisputeReportService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication error. Please log in again.');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<DisputeReport> createReport({
    required String description,
    required int filedAgainstId,
  }) async {
    final response = await http.post(
      Uri.parse('${api}dispute-reports'),
      headers: await _headers(),
      body: jsonEncode({
        'description': description,
        'filedAgainstId': filedAgainstId,
      }),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_parseErrorMessage(response, 'Failed to file report.'));
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return DisputeReport.fromJson(decoded);
    }
    throw Exception('Invalid response received from server.');
  }

  static Future<List<DisputeReport>> fetchMyReports() async {
    final response = await http.get(
      Uri.parse('${api}dispute-reports/mine'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_parseErrorMessage(response, 'Failed to fetch dispute reports.'));
    }

    final decoded = jsonDecode(response.body);
    if (decoded is List) {
      return decoded
          .whereType<Map<String, dynamic>>()
          .map((json) => DisputeReport.fromJson(json))
          .toList();
    } else if (decoded is Map && decoded['content'] is List) {
      final List content = decoded['content'];
      return content
          .whereType<Map<String, dynamic>>()
          .map((json) => DisputeReport.fromJson(json))
          .toList();
    }
    return const [];
  }

  static String _parseErrorMessage(http.Response response, String fallback) {
    try {
      final decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message']?.toString();
        final error = decoded['error']?.toString();
        if (message != null && message.isNotEmpty) {
          return message;
        }
        if (error != null && error.isNotEmpty) {
          return error;
        }
      }
    } catch (_) {}

    return '$fallback (${response.statusCode})';
  }
}
