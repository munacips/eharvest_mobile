import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/services/ai_service.dart';
import 'package:flutter/material.dart';

class MarketInsightsPage extends StatefulWidget {
  const MarketInsightsPage({super.key});

  @override
  State<MarketInsightsPage> createState() => _MarketInsightsPageState();
}

class _MarketInsightsPageState extends State<MarketInsightsPage> {
  final TextEditingController _weatherLatController =
      TextEditingController(text: '-17.8');
  final TextEditingController _weatherLonController =
      TextEditingController(text: '31.0');
  final TextEditingController _weatherDaysController =
      TextEditingController(text: '7');

  final TextEditingController _marketRegionController =
      TextEditingController(text: 'Harare');
  final TextEditingController _marketCommodityController =
      TextEditingController(text: 'maize');

  bool _weatherLoading = false;
  bool _marketLoading = false;
  String? _weatherError;
  String? _marketError;
  List<_WeatherPoint> _weather = [];
  List<_MarketPrice> _prices = [];

  @override
  void dispose() {
    _weatherLatController.dispose();
    _weatherLonController.dispose();
    _weatherDaysController.dispose();
    _marketRegionController.dispose();
    _marketCommodityController.dispose();
    super.dispose();
  }

  Future<void> _fetchWeather() async {
    setState(() {
      _weatherLoading = true;
      _weatherError = null;
      _weather = [];
    });
    try {
      final lat = double.tryParse(_weatherLatController.text.trim()) ?? 0.0;
      final lon = double.tryParse(_weatherLonController.text.trim()) ?? 0.0;
      final days = int.tryParse(_weatherDaysController.text.trim()) ?? 7;
      final response = await AiService.integrationsWeather(
        latitude: lat,
        longitude: lon,
        days: days,
      );
      final list = response is Map<String, dynamic>
          ? response['weather'] as List<dynamic>?
          : null;
      if (list == null) {
        throw Exception('No weather data.');
      }
      final parsed = list
          .map((item) =>
              item is Map<String, dynamic> ? _WeatherPoint.fromJson(item) : null)
          .whereType<_WeatherPoint>()
          .toList();
      setState(() {
        _weather = parsed;
      });
    } catch (e) {
      setState(() {
        _weatherError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _weatherLoading = false;
        });
      }
    }
  }

  Future<void> _fetchMarketPrices() async {
    setState(() {
      _marketLoading = true;
      _marketError = null;
      _prices = [];
    });
    try {
      final response = await AiService.integrationsMarketPrices(
        region: _marketRegionController.text.trim(),
        commodity: _marketCommodityController.text.trim(),
      );
      final list = response is Map<String, dynamic>
          ? response['market_prices'] as List<dynamic>?
          : null;
      if (list == null) {
        throw Exception('No market prices available.');
      }
      final parsed = list
          .map((item) =>
              item is Map<String, dynamic> ? _MarketPrice.fromJson(item) : null)
          .whereType<_MarketPrice>()
          .toList();
      setState(() {
        _prices = parsed;
      });
    } catch (e) {
      setState(() {
        _marketError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _marketLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Market Insights'),
        backgroundColor: Color(primaryColour),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildWeatherCard(),
          const SizedBox(height: 16),
          _buildMarketPricesCard(),
        ],
      ),
    );
  }

  Widget _buildWeatherCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Weather Outlook',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _weatherLatController,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration('Latitude'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _weatherLonController,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration('Longitude'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _weatherDaysController,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration('Days (1-14)'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _weatherLoading ? null : _fetchWeather,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(primaryColour),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Fetch Weather',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            if (_weatherLoading)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_weatherError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _weatherError!,
                  style: TextStyle(color: Colors.red[700], fontSize: 12),
                ),
              ),
            if (_weather.isNotEmpty) ...[
              const SizedBox(height: 12),
              ..._weather.map(
                (point) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(point.date),
                      Text(
                        '${point.temperatureText} | ${point.rainText}',
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

  Widget _buildMarketPricesCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Market Prices',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _marketRegionController,
              decoration: _inputDecoration('Region'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _marketCommodityController,
              decoration: _inputDecoration('Commodity'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _marketLoading ? null : _fetchMarketPrices,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(primaryColour),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Fetch Prices',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            if (_marketLoading)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_marketError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _marketError!,
                  style: TextStyle(color: Colors.red[700], fontSize: 12),
                ),
              ),
            if (_prices.isNotEmpty) ...[
              const SizedBox(height: 12),
              ..._prices.map(
                (price) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(price.market)),
                      Text(
                        price.priceText,
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

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
    );
  }
}

class _WeatherPoint {
  final String date;
  final double? rainfall;
  final double? temperature;

  _WeatherPoint({required this.date, this.rainfall, this.temperature});

  String get rainText =>
      rainfall == null ? 'Rain -' : '${rainfall!.toStringAsFixed(0)} mm';
  String get temperatureText =>
      temperature == null ? 'Temp -' : '${temperature!.toStringAsFixed(1)} C';

  factory _WeatherPoint.fromJson(Map<String, dynamic> json) {
    return _WeatherPoint(
      date: json['date']?.toString() ?? 'Unknown',
      rainfall: double.tryParse(json['rainfall_mm']?.toString() ?? ''),
      temperature: double.tryParse(json['temperature_c']?.toString() ?? ''),
    );
  }
}

class _MarketPrice {
  final String market;
  final double? price;

  _MarketPrice({required this.market, this.price});

  String get priceText =>
      price == null ? '-' : price!.toStringAsFixed(2);

  factory _MarketPrice.fromJson(Map<String, dynamic> json) {
    final market = json['market']?.toString() ??
        json['region']?.toString() ??
        'Market';
    return _MarketPrice(
      market: market,
      price: double.tryParse(json['price']?.toString() ?? ''),
    );
  }
}
