import 'package:flutter/material.dart';
import 'package:eharvest_mobile/global_variables.dart'; // Assuming primaryColour is here
import 'package:eharvest_mobile/services/ai_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  bool _insightLoading = true;
  String? _insightError;
  double? _insightChangePct;
  final String _insightCommodity = 'maize';

  bool _recommendationsLoading = true;
  String? _recommendationsError;
  List<_HomeRecommendation> _recommendations = [];

  @override
  void initState() {
    super.initState();
    _loadInsight();
    _loadRecommendations();
  }

  Future<void> _loadInsight() async {
    setState(() {
      _insightLoading = true;
      _insightError = null;
      _insightChangePct = null;
    });
    try {
      final response = await AiService.forecastCommodity(
        _insightCommodity,
        periods: 7,
        visual: false,
      );
      final forecast = response is Map<String, dynamic>
          ? response['forecast'] as List<dynamic>?
          : null;
      if (forecast == null || forecast.length < 2) {
        throw Exception('No forecast data.');
      }
      final values = forecast
          .map((item) => double.tryParse(item['value']?.toString() ?? ''))
          .whereType<double>()
          .toList();
      if (values.length < 2 || values.first == 0) {
        throw Exception('Forecast data unavailable.');
      }
      final change = (values.last - values.first) / values.first;
      setState(() {
        _insightChangePct = change;
      });
    } catch (e) {
      setState(() {
        _insightError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _insightLoading = false;
        });
      }
    }
  }

  Future<void> _loadRecommendations() async {
    setState(() {
      _recommendationsLoading = true;
      _recommendationsError = null;
      _recommendations = [];
    });
    try {
      final response = await AiService.prescriptiveRecommendations({
        'region': 'Harare',
        'budget_usd': 500,
        'climate': {'rainfall_mm': 600, 'temperature_c': 24},
        'top_n': 2,
      });
      final items = response is Map<String, dynamic>
          ? response['recommendations'] as List<dynamic>?
          : null;
      if (items == null) {
        throw Exception('No recommendations available.');
      }
      final parsed = items
          .map((item) =>
              item is Map<String, dynamic> ? _HomeRecommendation.fromJson(item) : null)
          .whereType<_HomeRecommendation>()
          .toList();
      setState(() {
        _recommendations = parsed;
      });
    } catch (e) {
      setState(() {
        _recommendationsError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _recommendationsLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Smart Farming, Connected Markets',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 20),

            // AI INSIGHT CARD
            _buildAIInsightCard(),

            const SizedBox(height: 24),

            // TWO COLUMN SECTION (Active Orders & Recommendations)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildSectionCard('ACTIVE ORDERS', _buildOrderList())),
                const SizedBox(width: 12),
                Expanded(child: _buildSectionCard('RECOMMENDED', _buildRecommendationList())),
              ],
            ),

            const SizedBox(height: 24),

            // SEARCH BAR
            TextField(
              decoration: InputDecoration(
                hintText: 'Find produce, buyers...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(primaryColour).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.tune, color: Color(primaryColour)),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),

            const SizedBox(height: 24),

            // CATEGORIES
            const Text(
              'Categories',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildCategoryRow(),
          ],
        ),
      ),
    );
  }

  // 1. Large AI Insight Card
  Widget _buildAIInsightCard() {
    final change = _insightChangePct;
    final changeText = change == null
        ? 'No forecast available'
        : '${change >= 0 ? '+' : ''}${(change * 100).toStringAsFixed(1)}%';
    final statusText = _insightLoading
        ? 'LOADING INSIGHT'
        : _insightError != null
        ? 'INSIGHT UNAVAILABLE'
        : 'MARKET TREND';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(primaryColour).withOpacity(0.2), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Color(primaryColour).withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.trending_up, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      statusText,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${_insightCommodity.toUpperCase()}: $changeText\nNEXT WEEK',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _insightError == null
                      ? 'Based on AI demand forecast'
                      : 'Check your AI service connection',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Column(
            children: [
              CircleAvatar(
                radius: 35,
                backgroundColor: Color(primaryColour),
                child: const Icon(
                  Icons.add_shopping_cart,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'LIST NOW',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          )
        ],
      ),
    );
  }

  // 2. Generic Section Wrapper
  Widget _buildSectionCard(String title, Widget content) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 10),
          content,
        ],
      ),
    );
  }

  // 3. Placeholder for Active Orders
  Widget _buildOrderList() {
    return Column(
      children: [
        _orderItem(Icons.local_shipping, 'Apples', 'In Transit'),
        const Divider(),
        _orderItem(Icons.payments, 'Maize', 'Pending'),
      ],
    );
  }

  Widget _orderItem(IconData icon, String title, String status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Color(primaryColour)),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
          Text(status, style: const TextStyle(fontSize: 10, color: Colors.orange)),
        ],
      ),
    );
  }

  // 4. Placeholder for Recommendations
  Widget _buildRecommendationList() {
    if (_recommendationsLoading) {
      return const Center(
        child: SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_recommendationsError != null || _recommendations.isEmpty) {
      return const Text(
        'No recommendations yet',
        style: TextStyle(fontSize: 12, color: Colors.grey),
      );
    }
    return Column(
      children: _recommendations
          .map(
            (rec) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Icon(Icons.eco, size: 16, color: Color(primaryColour)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      rec.commodity,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    'Score ${rec.score.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  // 5. Category Icons
  Widget _buildCategoryRow() {
    List<Map<String, dynamic>> cats = [
      {'icon': Icons.apple, 'name': 'Fruits'},
      {'icon': Icons.grass, 'name': 'Grains'},
      {'icon': Icons.eco, 'name': 'Veg'},
      {'icon': Icons.bakery_dining, 'name': 'Spices'},
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: cats.map((c) => Column(
        children: [
          CircleAvatar(
            backgroundColor: Colors.grey.shade100,
            child: Icon(c['icon'], color: Color(primaryColour)),
          ),
          const SizedBox(height: 4),
          Text(c['name'], style: const TextStyle(fontSize: 12)),
        ],
      )).toList(),
    );
  }
}

class _HomeRecommendation {
  final String commodity;
  final double score;

  _HomeRecommendation({required this.commodity, required this.score});

  factory _HomeRecommendation.fromJson(Map<String, dynamic> json) {
    return _HomeRecommendation(
      commodity: json['commodity']?.toString() ?? 'Unknown',
      score: double.tryParse(json['score']?.toString() ?? '') ?? 0,
    );
  }
}
