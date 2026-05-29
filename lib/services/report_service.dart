import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/models/report_descriptor.dart';
import 'package:eharvest_mobile/services/auth_service.dart';
import 'package:http/http.dart' as http;

class ReportService {
  static Future<List<ReportDescriptor>> fetchAvailableReports() async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication error. Please log in again.');
    }

    http.Response response;
    try {
      response = await http
          .get(
            Uri.parse('${reportsApi}available'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw Exception('Request timed out while loading reports.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_parseErrorMessage(response, 'Failed to load reports.'));
    }

    final decoded = json.decode(response.body);
    if (decoded is! List) {
      throw Exception('Invalid reports response from server.');
    }

    return decoded
        .whereType<Map>()
        .map(
          (item) => ReportDescriptor.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList();
  }

  static Future<Uint8List> generateReport({
    required String reportName,
    required Map<String, String> queryParams,
  }) async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication error. Please log in again.');
    }

    final uri = Uri.parse(
      '${reportsApi}generate/$reportName',
    ).replace(queryParameters: queryParams.isEmpty ? null : queryParams);

    http.Response response;
    try {
      response = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/pdf',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw Exception('Request timed out while generating the report.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _parseErrorMessage(response, 'Failed to generate report.'),
      );
    }

    if (response.bodyBytes.isEmpty) {
      throw Exception('The generated report was empty.');
    }

    return response.bodyBytes;
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
