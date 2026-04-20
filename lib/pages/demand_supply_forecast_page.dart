import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/services/ai_service.dart';
import 'package:flutter/material.dart';

class DemandSupplyForecastPage extends StatefulWidget {
  const DemandSupplyForecastPage({super.key});

  @override
  State<DemandSupplyForecastPage> createState() =>
      _DemandSupplyForecastPageState();
}

class _DemandSupplyForecastPageState extends State<DemandSupplyForecastPage> {
  final TextEditingController _regionController =
      TextEditingController(text: 'Harare');
  final TextEditingController _periodsController =
      TextEditingController(text: '6');
  final TextEditingController _supplyMultiplierController =
      TextEditingController(text: '1.05');
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  bool _autoFetch = false;

  final List<_EntryForm> _salesEntries = [];
  final List<_EntryForm> _supplyEntries = [];

  bool _loading = false;
  String? _errorMessage;
  List<_DemandSupplySeries> _series = [];

  @override
  void initState() {
    super.initState();
    _salesEntries.add(_EntryForm());
  }

  @override
  void dispose() {
    _regionController.dispose();
    _periodsController.dispose();
    _supplyMultiplierController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    for (final entry in _salesEntries) {
      entry.dispose();
    }
    for (final entry in _supplyEntries) {
      entry.dispose();
    }
    super.dispose();
  }

  void _addSalesEntry() {
    setState(() {
      _salesEntries.add(_EntryForm());
    });
  }

  void _addSupplyEntry() {
    setState(() {
      _supplyEntries.add(_EntryForm());
    });
  }

  void _removeSalesEntry(int index) {
    setState(() {
      _salesEntries[index].dispose();
      _salesEntries.removeAt(index);
    });
  }

  void _removeSupplyEntry(int index) {
    setState(() {
      _supplyEntries[index].dispose();
      _supplyEntries.removeAt(index);
    });
  }

  Future<void> _fetchForecast() async {
    final region = _regionController.text.trim();
    if (region.isEmpty) {
      _showMessage('Region is required.');
      return;
    }
    final periods = int.tryParse(_periodsController.text.trim()) ?? 6;
    final supplyMultiplier =
        double.tryParse(_supplyMultiplierController.text.trim()) ?? 1.05;
    final latitude = double.tryParse(_latitudeController.text.trim());
    final longitude = double.tryParse(_longitudeController.text.trim());

    final salesPayload = _buildEntries(_salesEntries, region);
    if (salesPayload.isEmpty) {
      _showMessage('Add at least one sales entry.');
      return;
    }
    final supplyPayload = _buildEntries(_supplyEntries, region);

    setState(() {
      _loading = true;
      _errorMessage = null;
      _series = [];
    });

    try {
      final response = await AiService.demandSupplyForecast({
        'region': region,
        'periods': periods,
        'historical_sales': salesPayload,
        if (supplyPayload.isNotEmpty) 'historical_supply': supplyPayload,
        'supply_multiplier': supplyMultiplier,
        'auto_fetch_external': _autoFetch,
        if (_autoFetch && latitude != null) 'latitude': latitude,
        if (_autoFetch && longitude != null) 'longitude': longitude,
      });
      final parsed = _parseForecastSeries(response);
      if (parsed.isEmpty) {
        throw Exception('No forecast data returned.');
      }
      setState(() {
        _series = parsed;
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

  List<Map<String, dynamic>> _buildEntries(
    List<_EntryForm> entries,
    String region,
  ) {
    final payload = <Map<String, dynamic>>[];
    for (final entry in entries) {
      final date = entry.dateController.text.trim();
      final commodity = entry.commodityController.text.trim();
      final quantity =
          double.tryParse(entry.quantityController.text.trim()) ?? 0.0;
      if (date.isEmpty || commodity.isEmpty || quantity <= 0) {
        continue;
      }
      payload.add({
        'date': date,
        'commodity': commodity,
        'quantity': quantity,
        'region': region,
      });
    }
    return payload;
  }

  List<_DemandSupplySeries> _parseForecastSeries(dynamic response) {
    if (response is! Map<String, dynamic>) {
      return [];
    }
    final forecasts = response['forecasts'];
    if (forecasts is! List) {
      return [];
    }
    return forecasts
        .map((item) {
          if (item is Map<String, dynamic>) {
            return _DemandSupplySeries.fromJson(item);
          }
          return null;
        })
        .whereType<_DemandSupplySeries>()
        .toList();
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
        title: const Text('Demand & Supply'),
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
          if (!_loading && _series.isNotEmpty) ...[
            const SizedBox(height: 8),
            ..._series.map(_buildSeriesCard),
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
              'Demand & Supply Forecast',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _regionController,
              decoration: _inputDecoration('Region'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _periodsController,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration('Periods'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _supplyMultiplierController,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration('Supply Multiplier'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _autoFetch,
              onChanged: (value) {
                setState(() {
                  _autoFetch = value;
                });
              },
              title: const Text('Use live weather & market data'),
              activeThumbColor: Color(primaryColour),
            ),
            if (_autoFetch) ...[
              const SizedBox(height: 8),
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
            ],
            const SizedBox(height: 16),
            _buildEntrySection(
              title: 'Historical Sales',
              entries: _salesEntries,
              onAdd: _addSalesEntry,
              onRemove: _removeSalesEntry,
            ),
            const SizedBox(height: 16),
            _buildEntrySection(
              title: 'Historical Supply (optional)',
              entries: _supplyEntries,
              onAdd: _addSupplyEntry,
              onRemove: _removeSupplyEntry,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _fetchForecast,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(primaryColour),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Generate Forecast',
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

  Widget _buildEntrySection({
    required String title,
    required List<_EntryForm> entries,
    required VoidCallback onAdd,
    required void Function(int) onRemove,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...entries.asMap().entries.map((entry) {
          final index = entry.key;
          final form = entry.value;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextField(
                    controller: form.dateController,
                    decoration: _inputDecoration('Date (YYYY-MM-DD)'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: form.commodityController,
                          decoration: _inputDecoration('Commodity'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: form.quantityController,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration('Quantity'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed:
                          entries.length > 1 ? () => onRemove(index) : null,
                      child: const Text('Remove'),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSeriesCard(_DemandSupplySeries series) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              series.commodity,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              width: double.infinity,
              child: CustomPaint(
                painter: _DualLineChartPainter(
                  series.demandValues,
                  series.supplyValues,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _legendDot('Demand', Colors.green),
                const SizedBox(width: 12),
                _legendDot('Supply', Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
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

class _EntryForm {
  final TextEditingController dateController = TextEditingController();
  final TextEditingController commodityController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();

  void dispose() {
    dateController.dispose();
    commodityController.dispose();
    quantityController.dispose();
  }
}

class _DemandSupplySeries {
  final String commodity;
  final List<double> demandValues;
  final List<double> supplyValues;

  _DemandSupplySeries({
    required this.commodity,
    required this.demandValues,
    required this.supplyValues,
  });

  factory _DemandSupplySeries.fromJson(Map<String, dynamic> json) {
    final demand = (json['demand'] as List<dynamic>? ?? [])
        .map((item) => double.tryParse(item['value']?.toString() ?? ''))
        .whereType<double>()
        .toList();
    final supply = (json['supply'] as List<dynamic>? ?? [])
        .map((item) => double.tryParse(item['value']?.toString() ?? ''))
        .whereType<double>()
        .toList();
    return _DemandSupplySeries(
      commodity: json['commodity']?.toString() ?? 'Commodity',
      demandValues: demand,
      supplyValues: supply.isEmpty ? List<double>.filled(demand.length, 0) : supply,
    );
  }
}

class _DualLineChartPainter extends CustomPainter {
  final List<double> demand;
  final List<double> supply;

  _DualLineChartPainter(this.demand, this.supply);

  @override
  void paint(Canvas canvas, Size size) {
    if (demand.length < 2) {
      return;
    }
    final allValues = [...demand, ...supply];
    final minVal = allValues.reduce((a, b) => a < b ? a : b);
    final maxVal = allValues.reduce((a, b) => a > b ? a : b);
    final span = (maxVal - minVal) == 0 ? 1 : (maxVal - minVal);

    final dx = size.width / (demand.length - 1);
    final demandPoints = <Offset>[];
    final supplyPoints = <Offset>[];

    for (var i = 0; i < demand.length; i++) {
      final demandY = size.height - ((demand[i] - minVal) / span) * size.height;
      demandPoints.add(Offset(dx * i, demandY));
    }
    for (var i = 0; i < supply.length; i++) {
      final supplyY = size.height - ((supply[i] - minVal) / span) * size.height;
      supplyPoints.add(Offset(dx * i, supplyY));
    }

    final demandPaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final supplyPaint = Paint()
      ..color = Colors.orange
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final demandPath = Path()..moveTo(demandPoints.first.dx, demandPoints.first.dy);
    for (var i = 1; i < demandPoints.length; i++) {
      demandPath.lineTo(demandPoints[i].dx, demandPoints[i].dy);
    }

    canvas.drawPath(demandPath, demandPaint);

    if (supplyPoints.length >= 2) {
      final supplyPath = Path()..moveTo(supplyPoints.first.dx, supplyPoints.first.dy);
      for (var i = 1; i < supplyPoints.length; i++) {
        supplyPath.lineTo(supplyPoints[i].dx, supplyPoints[i].dy);
      }
      canvas.drawPath(supplyPath, supplyPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DualLineChartPainter oldDelegate) {
    return oldDelegate.demand != demand || oldDelegate.supply != supply;
  }
}
