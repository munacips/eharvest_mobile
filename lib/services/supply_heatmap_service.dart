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
    final rawItems = _extractItems(decoded);

    return rawItems
        .whereType<Map>()
        .map<Map<String, dynamic>>(
          (item) => item.map((key, value) => MapEntry(key.toString(), value)),
        )
        .map(_parsePoint)
        .whereType<HeatmapPoint>()
        .toList(growable: false);
  }

  static List<dynamic> _extractItems(dynamic decoded) {
    if (decoded is List) {
      return decoded;
    }

    if (decoded is Map<String, dynamic>) {
      const candidateKeys = <String>[
        'data',
        'points',
        'heatmap',
        'results',
        'items',
      ];

      for (final key in candidateKeys) {
        final value = decoded[key];
        if (value is List) {
          return value;
        }
      }
    }

    throw const FormatException(
      'Supply heatmap response did not contain a heatmap array.',
    );
  }

  static HeatmapPoint? _parsePoint(Map<String, dynamic> item) {
    final latitude =
        double.tryParse((item['latitude'] ?? item['lat'] ?? '').toString()) ??
        0.0;
    final longitude =
        double.tryParse((item['longitude'] ?? item['lng'] ?? '').toString()) ??
        0.0;
    final weightKg =
        double.tryParse(
          (item['weight_kg'] ??
                  item['weightKg'] ??
                  item['total_kg'] ??
                  item['totalKg'] ??
                  item['normalizedWeight'] ??
                  '')
              .toString(),
        ) ??
        0.0;

    if (latitude == 0.0 && longitude == 0.0) {
      return null;
    }

    if (weightKg <= 0.0) {
      return null;
    }

    return HeatmapPoint(
      latitude: latitude,
      longitude: longitude,
      normalizedWeight: weightKg,
    );
  }
}
