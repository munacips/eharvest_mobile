import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/services/ai_service.dart';
import 'package:flutter/material.dart';

class AiForecastPage extends StatefulWidget {
  const AiForecastPage({super.key});

  @override
  State<AiForecastPage> createState() => _AiForecastPageState();
}

class _AiForecastPageState extends State<AiForecastPage> {
  final TextEditingController _commodityController =
      TextEditingController(text: 'maize');
  final TextEditingController _periodsController =
      TextEditingController(text: '30');
  final TextEditingController _regionController = TextEditingController();

  bool _loading = false;
  String? _errorMessage;
  List<_ForecastPoint> _points = [];
  double? _avgValue;
  double? _changePct;

  @override
  void dispose() {
    _commodityController.dispose();
    _periodsController.dispose();
    _regionController.dispose();
    super.dispose();
  }

  Future<void> _fetchForecast() async {
    final commodity = _commodityController.text.trim();
    if (commodity.isEmpty) {
      _showMessage('Commodity is required.');
      return;
    }
    final periods = int.tryParse(_periodsController.text.trim()) ?? 30;
    final region = _regionController.text.trim();

    setState(() {
      _loading = true;
      _errorMessage = null;
      _points = [];
      _avgValue = null;
      _changePct = null;
    });

    try {
      final response = await AiService.forecastCommodity(
        commodity,
        periods: periods,
        region: region.isEmpty ? null : region,
        visual: false,
      );
      final points = _parseForecast(response);
      if (points.isEmpty) {
        throw Exception('No forecast data available.');
      }
      final avg = points.map((p) => p.value).reduce((a, b) => a + b) /
          points.length;
      double? change;
      if (points.length >= 2 && points.first.value != 0) {
        change = (points.last.value - points.first.value) /
            points.first.value;
      }
      setState(() {
        _points = points;
        _avgValue = avg;
        _changePct = change;
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

  List<_ForecastPoint> _parseForecast(dynamic response) {
    if (response is! Map<String, dynamic>) {
      return [];
    }
    final data = response['forecast'];
    if (data is! List) {
      return [];
    }
    return data
        .map((item) {
          if (item is Map<String, dynamic>) {
            final dateText = item['date']?.toString() ?? '';
            final value = double.tryParse(item['value']?.toString() ?? '');
            if (dateText.isEmpty || value == null) {
              return null;
            }
            return _ForecastPoint(dateText, value);
          }
          return null;
        })
        .whereType<_ForecastPoint>()
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
        title: const Text('Forecasts'),
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
          if (!_loading && _points.isNotEmpty) ...[
            _buildSummaryCard(),
            const SizedBox(height: 16),
            _buildChartCard(),
            const SizedBox(height: 16),
            _buildListCard(),
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
              'Price Forecast',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _commodityController,
              decoration: _inputDecoration('Commodity', hint: 'e.g. maize'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _periodsController,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration('Periods (Months)', hint: 'e.g. 30'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _regionController,
                    decoration: _inputDecoration('Region (optional)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
                  'Get Forecast',
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

  Widget _buildSummaryCard() {
    final avg = _avgValue ?? 0;
    final change = _changePct;
    final changeText = change == null
        ? 'N/A'
        : '${change >= 0 ? '+' : ''}${(change * 100).toStringAsFixed(1)}%';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _metricTile(
                label: 'Average Price',
                value: '\$${avg.toStringAsFixed(4)}/kg',
              ),
            ),
            Container(width: 1, height: 36, color: Colors.grey[300]),
            Expanded(
              child: _metricTile(
                label: 'Trend',
                value: changeText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricTile({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(primaryColour),
          ),
        ),
      ],
    );
  }

  Widget _buildChartCard() {
    final values = _points.map((p) => p.value).toList();
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Forecast Trend',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              width: double.infinity,
              child: CustomPaint(
                painter: _LineChartPainter(values),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListCard() {
    final preview = _points.take(7).toList();
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Upcoming Forecast',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...preview.map(
              (point) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(point.date),
                    Text(
                      '\$${point.value.toStringAsFixed(4)}/kg',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(primaryColour),
                      ),
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

  InputDecoration _inputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
    );
  }
}

class _ForecastPoint {
  final String date;
  final double value;

  const _ForecastPoint(this.date, this.value);
}

class _LineChartPainter extends CustomPainter {
  final List<double> values;

  _LineChartPainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) {
      return;
    }
    final paintLine = Paint()
      ..color = const Color(primaryColour)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final paintFill = Paint()
      ..color = const Color(primaryColour).withOpacity(0.15)
      ..style = PaintingStyle.fill;

    final minVal = values.reduce((a, b) => a < b ? a : b);
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final span = (maxVal - minVal) == 0 ? 1 : (maxVal - minVal);

    final dx = size.width / (values.length - 1);
    final points = <Offset>[];

    for (var i = 0; i < values.length; i++) {
      final x = dx * i;
      final normalized = (values[i] - minVal) / span;
      final y = size.height - (normalized * size.height);
      points.add(Offset(x, y));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    canvas.drawPath(fillPath, paintFill);
    canvas.drawPath(path, paintLine);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.values != values;
  }
}
