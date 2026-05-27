import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/services/ai_service.dart';
import 'package:flutter/material.dart';

class SeasonRecommendationsPage extends StatefulWidget {
  const SeasonRecommendationsPage({super.key});

  @override
  State<SeasonRecommendationsPage> createState() =>
      _SeasonRecommendationsPageState();
}

class _SeasonRecommendationsPageState extends State<SeasonRecommendationsPage> {
  final TextEditingController _regionController = TextEditingController(
    text: 'Harare',
  );
  final TextEditingController _budgetController = TextEditingController(
    text: '500',
  );
  final TextEditingController _seasonController = TextEditingController();
  int? _selectedMonth;
  final List<_MonthOption> _monthOptions = List.generate(
    12,
    (index) => _MonthOption(value: index + 1, label: _monthLabel(index + 1)),
  );

  bool _loading = false;
  String? _errorMessage;
  String? _seasonLabel;
  List<_Recommendation> _recommendations = [];

  @override
  void dispose() {
    _regionController.dispose();
    _budgetController.dispose();
    _seasonController.dispose();
    super.dispose();
  }

  Future<void> _fetchRecommendations() async {
    final region = _regionController.text.trim();
    if (region.isEmpty) {
      _showMessage('Region is required.');
      return;
    }
    final budget = double.tryParse(_budgetController.text.trim());
    if (budget == null || budget <= 0) {
      _showMessage('Enter a valid budget.');
      return;
    }
    final month = _selectedMonth;
    final season = _seasonController.text.trim();

    setState(() {
      _loading = true;
      _errorMessage = null;
      _seasonLabel = null;
      _recommendations = [];
    });

    try {
      final response = await AiService.prescriptiveRecommendations({
        'region': region,
        'season': season.isEmpty ? null : season,
        'month': month,
        'budget_usd': budget,
      });

      final parsed = _parseRecommendations(response);
      if (parsed.isEmpty) {
        throw Exception('No recommendations available.');
      }
      setState(() {
        _recommendations = parsed;
        _seasonLabel = response is Map<String, dynamic>
            ? response['season']?.toString()
            : null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  List<_Recommendation> _parseRecommendations(dynamic response) {
    if (response is! Map<String, dynamic>) {
      return [];
    }
    final items = response['recommendations'];
    if (items is! List) {
      return [];
    }
    return items
        .map((item) {
          if (item is Map<String, dynamic>) {
            return _Recommendation.fromJson(item);
          }
          return null;
        })
        .whereType<_Recommendation>()
        .toList();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Season Recommendations'),
        backgroundColor: Color(primaryColour),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildInputCard(),
          const SizedBox(height: 16),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (!_loading && _errorMessage != null)
            _buildMessageCard(_errorMessage!, isError: true),
          if (!_loading && _recommendations.isNotEmpty) ...[
            if (_seasonLabel != null && _seasonLabel!.isNotEmpty)
              _buildMessageCard('Season: ${_seasonLabel!}', isError: false),
            const SizedBox(height: 8),
            ..._recommendations.map(_buildRecommendationCard),
          ],
        ],
      ),
    );
  }

  Widget _buildInputCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Get Crop Recommendations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _regionController,
              decoration: _inputDecoration('Region'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _budgetController,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration('Budget (USD)'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _selectedMonth,
                    decoration: _inputDecoration('Planting Month'),
                    items: _monthOptions
                        .map(
                          (option) => DropdownMenuItem<int>(
                            value: option.value,
                            child: Text(option.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedMonth = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _seasonController,
                    decoration: _inputDecoration('Season (optional)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _fetchRecommendations,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(primaryColour),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Get Recommendations',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationCard(_Recommendation rec) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.eco, color: Color(primaryColour)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rec.commodity,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  'Score ${rec.score.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Color(primaryColour),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _infoChip(
                  rec.climateFit ? 'Climate fit' : 'Climate risk',
                  rec.climateFit ? Colors.green : Colors.orange,
                ),
                if (rec.estimatedCostUsd != null)
                  _infoChip(
                    'Cost USD ${rec.estimatedCostUsd!.toStringAsFixed(0)}/ha',
                    Colors.blueGrey,
                  ),
                if (rec.plantingMonths.isNotEmpty)
                  _infoChip(
                    'Planting ${rec.plantingMonths.join(', ')}',
                    Colors.blueGrey,
                  ),
              ],
            ),
            if (rec.marketTargets.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Top Markets',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              ...rec.marketTargets.map(
                (market) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(market.name)),
                      Text(
                        market.priceText,
                        style: TextStyle(color: Color(primaryColour)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildMessageCard(String message, {bool isError = false}) {
    return Card(
      color: isError ? Colors.red[50] : Colors.blue[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.info_outline,
              color: isError ? Colors.red : Colors.blue,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: isError ? Colors.red[900] : Colors.blue[900],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
    );
  }

  static String _monthLabel(int month) {
    const labels = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    if (month < 1 || month > labels.length) {
      return 'Month';
    }
    return labels[month - 1];
  }
}

class _MonthOption {
  final int value;
  final String label;

  const _MonthOption({required this.value, required this.label});
}

class _Recommendation {
  final String commodity;
  final double score;
  final bool climateFit;
  final double? estimatedCostUsd;
  final List<int> plantingMonths;
  final List<_MarketTarget> marketTargets;

  _Recommendation({
    required this.commodity,
    required this.score,
    required this.climateFit,
    required this.estimatedCostUsd,
    required this.plantingMonths,
    required this.marketTargets,
  });

  factory _Recommendation.fromJson(Map<String, dynamic> json) {
    final why = json['why'] as Map<String, dynamic>? ?? {};
    final markets = <_MarketTarget>[];
    if (json['market_targets'] is List) {
      for (final item in json['market_targets'] as List) {
        if (item is Map<String, dynamic>) {
          markets.add(_MarketTarget.fromJson(item));
        }
      }
    }
    final months = <int>[];
    if (why['planting_months'] is List) {
      for (final m in why['planting_months'] as List) {
        final month = int.tryParse(m.toString());
        if (month != null) {
          months.add(month);
        }
      }
    }
    return _Recommendation(
      commodity: json['commodity']?.toString() ?? 'Unknown',
      score: double.tryParse(json['score']?.toString() ?? '') ?? 0,
      climateFit: why['climate_fit'] == true,
      estimatedCostUsd: double.tryParse(
        why['estimated_cost_usd_per_ha']?.toString() ?? '',
      ),
      plantingMonths: months,
      marketTargets: markets,
    );
  }
}

class _MarketTarget {
  final String name;
  final double? avgPrice;

  _MarketTarget({required this.name, required this.avgPrice});

  String get priceText => avgPrice == null ? '-' : avgPrice!.toStringAsFixed(2);

  factory _MarketTarget.fromJson(Map<String, dynamic> json) {
    return _MarketTarget(
      name: json['market']?.toString() ?? 'Market',
      avgPrice: double.tryParse(json['avg_price']?.toString() ?? ''),
    );
  }
}
