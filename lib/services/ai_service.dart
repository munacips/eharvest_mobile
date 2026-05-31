import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:eharvest_mobile/global_variables.dart';

class AiService {
  static const Duration _timeout = Duration(seconds: 12);

  static Future<dynamic> predictPrice(Map<String, dynamic> payload) {
    return _post('/predict-price', payload);
  }

  static Future<dynamic> pricingSchema() {
    return _get('/pricing/schema');
  }

  static Future<dynamic> pricingBatch(Map<String, dynamic> payload) {
    return _post('/pricing/batch', payload);
  }

  static Future<dynamic> autoPricing(Map<String, dynamic> payload) {
    return _post('/pricing/auto', payload);
  }

  static Future<dynamic> forecastCommodity(
    String commodity, {
    int periods = 30,
    String? region,
    bool visual = true,
  }) {
    final query = <String, String>{
      'periods': periods.toString(),
      'visual': visual.toString(),
    };
    if (region != null && region.trim().isNotEmpty) {
      query['region'] = region.trim();
    }
    return _get('/forecast/$commodity', query: query);
  }

  static Future<dynamic> demandSupplyForecast(Map<String, dynamic> payload) {
    return _post('/forecast/demand-supply', payload);
  }

  static Future<dynamic> prescriptiveRecommendations(
    Map<String, dynamic> payload,
  ) {
    return _post('/recommendations/prescriptive', payload);
  }

  static Future<dynamic> logisticsMatch(Map<String, dynamic> payload) {
    return _post('/logistics/match', payload);
  }

  static Future<dynamic> integrationsWeather({
    required double latitude,
    required double longitude,
    int days = 7,
  }) {
    return _get(
      '/integrations/weather',
      query: {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'days': days.toString(),
      },
    );
  }

  static Future<dynamic> integrationsMarketPrices({
    String? region,
    String? commodity,
  }) {
    final query = <String, String>{};
    if (region != null && region.trim().isNotEmpty) {
      query['region'] = region.trim();
    }
    if (commodity != null && commodity.trim().isNotEmpty) {
      query['commodity'] = commodity.trim();
    }
    return _get('/integrations/market-prices', query: query);
  }

  static Future<dynamic> trustScore(String userId) {
    return _get('/trust-score/$userId');
  }

  static Future<dynamic> health() {
    return _get('/health');
  }

  static Future<dynamic> root() {
    return _get('/');
  }

  static Future<dynamic> _get(String path, {Map<String, String>? query}) async {
    final uri = _buildUri(path).replace(queryParameters: query);
    final response = await http.get(uri, headers: _headers()).timeout(_timeout);
    return _handleResponse(response);
  }

  static Future<dynamic> _post(
    String path,
    Map<String, dynamic> payload,
  ) async {
    final uri = _buildUri(path);
    final response = await http
        .post(uri, headers: _headers(), body: jsonEncode(payload))
        .timeout(_timeout);
    return _handleResponse(response);
  }

  static Uri _buildUri(String path) {
    final base = aiApi.endsWith('/')
        ? aiApi.substring(0, aiApi.length - 1)
        : aiApi;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$normalizedPath');
  }

  static Map<String, String> _headers() {
    return const {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  static dynamic _handleResponse(http.Response response) {
    final body = response.body.trim();
    dynamic decoded;
    if (body.isNotEmpty) {
      try {
        decoded = jsonDecode(body);
      } catch (_) {
        decoded = body;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded ?? {};
    }

    String message = 'Request failed (${response.statusCode}).';
    if (decoded is Map<String, dynamic>) {
      message =
          decoded['detail']?.toString() ??
          decoded['message']?.toString() ??
          decoded['error']?.toString() ??
          message;
    } else if (decoded is String && decoded.isNotEmpty) {
      message = decoded;
    }
    throw Exception(message);
  }
}
