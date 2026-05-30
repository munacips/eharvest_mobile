import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:eharvest_mobile/global_variables.dart'; // Assuming primaryColour is here
import 'package:eharvest_mobile/services/auth_service.dart';
import 'package:eharvest_mobile/services/ai_service.dart';
import 'package:eharvest_mobile/pages/buy_page.dart';
import 'package:eharvest_mobile/utils/responsive_breakpoints.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  bool _insightLoading = true;
  String? _insightError;
  double? _insightChangePct;
  double? _insightDelta;
  bool _insightUsesPercent = true;
  final String _insightCommodity = 'maize';

  bool _ordersLoading = true;
  String? _ordersError;
  List<Order> _activeOrders = [];
  final TextEditingController _searchController = TextEditingController();

  bool _marketPricesLoading = true;
  String? _marketPricesError;
  List<_MarketPrice> _marketPrices = [];

  @override
  void initState() {
    super.initState();
    _loadInsight();
    _loadMarketPrices();
    _loadActiveOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _normalizeRoleKey(String rawRole) {
    final normalized = rawRole.trim().toLowerCase().replaceAll(
      RegExp(r'[\s-]+'),
      '_',
    );
    final baseRole = normalized.startsWith('role_')
        ? normalized.substring('role_'.length)
        : normalized;

    switch (baseRole) {
      case 'farmer':
      case 'buyer':
        return baseRole;
      case 'logistics':
      case 'logistics_provider':
      case 'logisticsprovider':
      case 'driver':
        return 'logistics';
      default:
        return baseRole;
    }
  }

  bool _isActiveStatus(String status) {
    final normalized = status.trim().toLowerCase().replaceAll(
      RegExp(r'[\s-]+'),
      '_',
    );
    const closedStatuses = <String>{
      'delivered',
      'completed',
      'rejected',
      'cancelled',
    };
    if (normalized.isEmpty) {
      return true;
    }
    return !closedStatuses.contains(normalized);
  }

  List<Order> _decodeOrders(dynamic payload) {
    List<dynamic> items = <dynamic>[];
    if (payload is List) {
      items = payload;
    } else if (payload is Map<String, dynamic> && payload['content'] is List) {
      items = payload['content'] as List<dynamic>;
    }

    return items
        .whereType<Map>()
        .map<Map<String, dynamic>>(
          (item) => item.map((key, value) => MapEntry(key.toString(), value)),
        )
        .map(Order.fromJson)
        .toList();
  }

  Future<void> _loadActiveOrders() async {
    setState(() {
      _ordersLoading = true;
      _ordersError = null;
      _activeOrders = [];
    });

    try {
      final token = await AuthService.getToken();
      final userId = await AuthService.getUserId();
      final role = await AuthService.getRole();

      if (token == null || userId == null || role == null || role.isEmpty) {
        throw Exception('Authentication error. Please log in again.');
      }

      final roleKey = _normalizeRoleKey(role);
      final candidates = <String>[];

      void addCandidate(String endpoint) {
        if (!candidates.contains(endpoint)) {
          candidates.add(endpoint);
        }
      }

      if (roleKey == 'farmer') {
        addCandidate('orders/farmer/$userId');
      } else if (roleKey == 'buyer') {
        addCandidate('orders/buyer/$userId');
      } else if (roleKey == 'logistics') {
        addCandidate('orders/logistics-provider/$userId');
        addCandidate('orders/logistics/$userId');
        addCandidate('orders/driver/$userId');
      }

      addCandidate('orders/farmer/$userId');
      addCandidate('orders/buyer/$userId');
      addCandidate('orders/logistics-provider/$userId');
      addCandidate('orders/logistics/$userId');
      addCandidate('orders/driver/$userId');

      final triedStatuses = <String>[];
      List<Order>? resolvedOrders;

      for (final endpoint in candidates) {
        final uri = Uri.parse('$api$endpoint');
        final response = await http.get(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        triedStatuses.add('/$endpoint: ${response.statusCode}');

        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          resolvedOrders = _decodeOrders(decoded);
          break;
        }
      }

      final active =
          (resolvedOrders ?? <Order>[])
              .where((order) => _isActiveStatus(order.status))
              .toList()
            ..sort((a, b) => b.orderDate.compareTo(a.orderDate));

      if (!mounted) {
        return;
      }

      setState(() {
        _activeOrders = active.take(5).toList();
        _ordersLoading = false;
        if (resolvedOrders == null) {
          _ordersError = 'Unable to load orders (${triedStatuses.join(', ')}).';
        }
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _ordersError = e.toString();
        _ordersLoading = false;
      });
    }
  }

  void _openBuyPage({String? search, String? category}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BuyPage(
          initialSearchQuery: search,
          initialCategoryFilter: category,
        ),
      ),
    );
  }

  void _submitSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      return;
    }
    _openBuyPage(search: query);
  }

  Future<void> _loadInsight() async {
    setState(() {
      _insightLoading = true;
      _insightError = null;
      _insightChangePct = null;
      _insightDelta = null;
      _insightUsesPercent = true;
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
      if (values.length < 2) {
        throw Exception('Forecast data unavailable.');
      }

      final first = values.first;
      final last = values.last;
      final delta = last - first;

      // Percent change is only meaningful when the baseline magnitude is not tiny.
      // For near-zero baselines, display point movement to avoid extreme percentages.
      const minBaselineForPercent = 1.0;
      final usePercent = first.abs() >= minBaselineForPercent;

      double? pct;
      if (usePercent) {
        pct = delta / first;
        // Cap visual percentage to keep the card readable.
        if (pct > 3) {
          pct = 3;
        } else if (pct < -3) {
          pct = -3;
        }
      }

      setState(() {
        _insightChangePct = pct;
        _insightDelta = delta;
        _insightUsesPercent = usePercent;
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

  Future<void> _loadMarketPrices() async {
    setState(() {
      _marketPricesLoading = true;
      _marketPricesError = null;
      _marketPrices = [];
    });

    try {
      final response = await AiService.integrationsMarketPrices(
        region: 'Harare',
      );

      List<dynamic> rawItems = <dynamic>[];
      if (response is List) {
        rawItems = response;
      } else if (response is Map<String, dynamic>) {
        if (response['market_prices'] is List) {
          rawItems = response['market_prices'] as List<dynamic>;
        } else if (response['prices'] is List) {
          rawItems = response['prices'] as List<dynamic>;
        } else if (response['data'] is List) {
          rawItems = response['data'] as List<dynamic>;
        } else if (response['items'] is List) {
          rawItems = response['items'] as List<dynamic>;
        } else if (response['market_prices'] is Map<String, dynamic>) {
          final map = response['market_prices'] as Map<String, dynamic>;
          rawItems = map.entries
              .map(
                (entry) => <String, dynamic>{
                  'commodity': entry.key,
                  'price': entry.value,
                },
              )
              .toList();
        }
      }

      final parsed = rawItems
          .map(
            (item) => item is Map<String, dynamic>
                ? _MarketPrice.fromJson(item)
                : null,
          )
          .whereType<_MarketPrice>()
          .toList();

      setState(() {
        _marketPrices = parsed.take(5).toList();
      });
    } catch (e) {
      setState(() {
        _marketPricesError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _marketPricesLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = ResponsiveBreakpoints.isDesktopWidth(
          constraints.maxWidth,
        );
        final content = Padding(
          padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
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

              // TWO COLUMN SECTION (Active Orders & Market Prices)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildSectionCard(
                      'ACTIVE ORDERS',
                      _buildActiveOrdersList(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSectionCard(
                      'MARKET PRICES',
                      _buildMarketPricesList(),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // SEARCH BAR
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Find produce, buyers...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    onPressed: _submitSearch,
                    icon: Icon(
                      Icons.arrow_forward,
                      color: Color(primaryColour),
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onSubmitted: (_) => _submitSearch(),
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
        );

        if (!isDesktop) {
          return SingleChildScrollView(child: content);
        }

        return SingleChildScrollView(
          child: ResponsiveContent(child: content),
        );
      },
    );
  }

  // 1. Large AI Insight Card
  Widget _buildAIInsightCard() {
    final change = _insightChangePct;
    final delta = _insightDelta;
    final changeText = _insightError != null
        ? 'No forecast available'
        : _insightUsesPercent
        ? (change == null
              ? 'No forecast available'
              : '${change >= 0 ? '+' : ''}${(change * 100).toStringAsFixed(1)}%')
        : (delta == null
              ? 'No forecast available'
              : '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(3)} pts');
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
              IconButton(
                onPressed: _loadInsight,
                icon: CircleAvatar(
                  radius: 28,
                  backgroundColor: Color(primaryColour),
                  child: const Icon(
                    Icons.refresh,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'REFRESH',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
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
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),
          content,
        ],
      ),
    );
  }

  Widget _buildActiveOrdersList() {
    if (_ordersLoading) {
      return const Center(
        child: SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_ordersError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Could not load orders',
            style: TextStyle(fontSize: 12, color: Colors.red[700]),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: _loadActiveOrders, child: const Text('Retry')),
        ],
      );
    }

    if (_activeOrders.isEmpty) {
      return const Text(
        'No active orders',
        style: TextStyle(fontSize: 12, color: Colors.grey),
      );
    }

    return Column(
      children: _activeOrders
          .map(
            (order) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: 16,
                    color: Color(primaryColour),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Order #${order.id}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    order.status,
                    style: const TextStyle(fontSize: 10, color: Colors.orange),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildMarketPricesList() {
    if (_marketPricesLoading) {
      return const Center(
        child: SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_marketPricesError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Could not load prices',
            style: TextStyle(fontSize: 12, color: Colors.red[700]),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: _loadMarketPrices, child: const Text('Retry')),
        ],
      );
    }

    if (_marketPrices.isEmpty) {
      return const Text(
        'No market prices available',
        style: TextStyle(fontSize: 12, color: Colors.grey),
      );
    }

    return Column(
      children: _marketPrices
          .map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Icon(Icons.show_chart, size: 16, color: Color(primaryColour)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.commodity,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    item.priceLabel,
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  // 5. Category Filters
  Widget _buildCategoryRow() {
    List<Map<String, dynamic>> cats = [
      {'icon': Icons.apple, 'name': 'Fruits'},
      {'icon': Icons.grass, 'name': 'Grains'},
      {'icon': Icons.eco, 'name': 'Vegetables'},
      {'icon': Icons.spa, 'name': 'Legumes'},
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: cats
          .map(
            (c) => InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _openBuyPage(category: c['name'] as String),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                child: Column(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.grey.shade100,
                      child: Icon(
                        c['icon'] as IconData,
                        color: Color(primaryColour),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      c['name'] as String,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _MarketPrice {
  final String commodity;
  final String priceLabel;

  _MarketPrice({required this.commodity, required this.priceLabel});

  factory _MarketPrice.fromJson(Map<String, dynamic> json) {
    final commodity =
        json['commodity']?.toString() ?? json['name']?.toString() ?? 'Unknown';
    final rawPrice = json['price'] ?? json['market_price'] ?? json['value'];
    final currency = json['currency']?.toString();

    String label;
    final parsedPrice = double.tryParse(rawPrice?.toString() ?? '');
    if (parsedPrice != null) {
      final prefix = (currency != null && currency.isNotEmpty)
          ? '$currency '
          : 'USD ';
      label = '$prefix${parsedPrice.toStringAsFixed(2)}';
    } else {
      label = rawPrice?.toString() ?? '-';
    }

    return _MarketPrice(commodity: commodity, priceLabel: label);
  }
}
