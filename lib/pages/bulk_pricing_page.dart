import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/services/ai_service.dart';
import 'package:flutter/material.dart';

class BulkPricingPage extends StatefulWidget {
  const BulkPricingPage({super.key});

  @override
  State<BulkPricingPage> createState() => _BulkPricingPageState();
}

class _BulkPricingPageState extends State<BulkPricingPage> {
  final TextEditingController _marketController =
      TextEditingController(text: 'harare');
  final TextEditingController _unitController =
      TextEditingController(text: 'KG');
  final TextEditingController _monthController =
      TextEditingController(text: DateTime.now().month.toString());
  final TextEditingController _latitudeController =
      TextEditingController(text: '-17.8');
  final TextEditingController _longitudeController =
      TextEditingController(text: '31.0');
  final TextEditingController _currencyController =
      TextEditingController(text: 'USD');
  final TextEditingController _priceFlagController =
      TextEditingController(text: 'actual');

  final List<_BulkItemForm> _items = [];

  bool _loading = false;
  String? _errorMessage;
  List<_BulkPriceResult> _results = [];

  @override
  void initState() {
    super.initState();
    _items.add(_BulkItemForm());
  }

  @override
  void dispose() {
    _marketController.dispose();
    _unitController.dispose();
    _monthController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _currencyController.dispose();
    _priceFlagController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _addItem() {
    setState(() {
      _items.add(_BulkItemForm());
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  Future<void> _runBatchPricing() async {
    final month = int.tryParse(_monthController.text.trim()) ?? 1;
    final latitude = double.tryParse(_latitudeController.text.trim()) ?? 0.0;
    final longitude = double.tryParse(_longitudeController.text.trim()) ?? 0.0;

    final itemsPayload = <Map<String, dynamic>>[];
    for (final item in _items) {
      final commodity = item.commodityController.text.trim();
      final category = item.categoryController.text.trim();
      if (commodity.isEmpty || category.isEmpty) {
        continue;
      }
      itemsPayload.add({
        'commodity': commodity,
        'market': _marketController.text.trim(),
        'category': category,
        'unit': _unitController.text.trim(),
        'month': month,
        'latitude': latitude,
        'longitude': longitude,
        'currency': _currencyController.text.trim(),
        'priceflag': _priceFlagController.text.trim(),
      });
    }

    if (itemsPayload.isEmpty) {
      _showMessage('Add at least one item with commodity and category.');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
      _results = [];
    });

    try {
      final response = await AiService.pricingBatch({'items': itemsPayload});
      if (response is Map<String, dynamic>) {
        final list = response['predictions'] as List<dynamic>?;
        if (list == null) {
          throw Exception('No predictions returned.');
        }
        final parsed = list
            .map((item) => item is Map<String, dynamic>
                ? _BulkPriceResult.fromJson(item)
                : null)
            .whereType<_BulkPriceResult>()
            .toList();
        setState(() {
          _results = parsed;
        });
      }
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Bulk Price Check'),
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
          if (!_loading && _results.isNotEmpty) _buildResultsCard(),
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
              'Shared Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _marketController,
              decoration: _inputDecoration('Market'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _unitController,
                    decoration: _inputDecoration('Unit'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _monthController,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration('Month'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _latitudeController,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration('Latitude'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _longitudeController,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration('Longitude'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _currencyController,
                    decoration: _inputDecoration('Currency'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _priceFlagController,
                    decoration: _inputDecoration('Price Flag'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Items',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      TextField(
                        controller: item.commodityController,
                        decoration: _inputDecoration('Commodity'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: item.categoryController,
                        decoration: _inputDecoration('Category'),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed:
                              _items.length > 1 ? () => _removeItem(index) : null,
                          child: const Text('Remove'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            TextButton.icon(
              onPressed: _addItem,
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _runBatchPricing,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(primaryColour),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Get Suggestions',
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

  Widget _buildResultsCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Suggested Prices',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ..._results.map(
              (result) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${result.commodity} (${result.market})',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      '${result.currency} ${result.price.toStringAsFixed(2)}',
                      style: TextStyle(color: Color(primaryColour)),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
    );
  }
}

class _BulkItemForm {
  final TextEditingController commodityController = TextEditingController();
  final TextEditingController categoryController = TextEditingController();

  void dispose() {
    commodityController.dispose();
    categoryController.dispose();
  }
}

class _BulkPriceResult {
  final String commodity;
  final String market;
  final double price;
  final String currency;

  _BulkPriceResult({
    required this.commodity,
    required this.market,
    required this.price,
    required this.currency,
  });

  factory _BulkPriceResult.fromJson(Map<String, dynamic> json) {
    return _BulkPriceResult(
      commodity: json['commodity']?.toString() ?? 'Commodity',
      market: json['market']?.toString() ?? 'Market',
      price: double.tryParse(json['suggested_price']?.toString() ?? '') ?? 0,
      currency: json['currency']?.toString() ?? 'USD',
    );
  }
}
