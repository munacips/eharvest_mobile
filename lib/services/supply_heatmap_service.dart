import 'dart:convert';

import 'package:eharvest_mobile/global_variables.dart';
import 'package:http/http.dart' as http;

class SupplyHeatmapService {
  static Future<List<HeatmapPoint>> fetchSupplyHeatmap(String crop) async {
    final uri = Uri.parse(
      '${api}heatmap/supply',
    ).replace(queryParameters: {'crop': crop});

    final response = await http.get(
      uri,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Failed to load supply heatmap (${response.statusCode}).',
      );
    }

    final body = response.body.trim();
    if (body.isEmpty) {
      return <HeatmapPoint>[];
    }

    final decoded = jsonDecode(body);
    List<dynamic> rawItems = <dynamic>[];

    if (decoded is List) {
      rawItems = decoded;
    } else if (decoded is Map<String, dynamic>) {
      if (decoded['data'] is List) {
        rawItems = decoded['data'] as List<dynamic>;
      } else if (decoded['points'] is List) {
        rawItems = decoded['points'] as List<dynamic>;
      } else if (decoded['heatmap'] is List) {
        rawItems = decoded['heatmap'] as List<dynamic>;
      }
    }

    return rawItems
        .whereType<Map>()
        .map<Map<String, dynamic>>(
          (item) => item.map((key, value) => MapEntry(key.toString(), value)),
        )
        .map(HeatmapPoint.fromJson)
        .where((point) => point.latitude != 0.0 || point.longitude != 0.0)
        .toList();
  }
}
