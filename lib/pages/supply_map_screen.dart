import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/services/supply_heatmap_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class SupplyMapScreen extends StatefulWidget {
  const SupplyMapScreen({super.key});

  @override
  State<SupplyMapScreen> createState() => _SupplyMapScreenState();
}

class _SupplyMapScreenState extends State<SupplyMapScreen> {
  static const List<String> _defaultCrops = <String>[
    'Maize',
    'Sorghum',
    'Millet',
    'Finger Millet',
    'Wheat',
    'Barley',
    'Rice',
    'Soya Beans',
    'Groundnuts',
    'Sugar Beans',
    'Cowpeas',
    'Bambara Nuts',
    'Sunflower',
    'Cotton',
    'Tobacco',
    'Sugarcane',
    'Carrots',
    'Tomatoes',
    'Onions',
    'Potatoes',
    'Sweet Potatoes',
    'Cabbage',
    'Leafy Vegetables',
    'Butternut',
    'Pumpkin',
    'Paprika',
    'Chillies',
    'Bananas',
    'Oranges',
    'Avocados',
    'Mangoes',
  ];

  static const LatLng _zimbabweCenter = LatLng(-19.0154, 29.1549);

  String _selectedCrop = _defaultCrops.first;
  bool _loading = true;
  String? _error;
  List<HeatmapPoint> _points = <HeatmapPoint>[];

  @override
  void initState() {
    super.initState();
    _loadHeatmap();
  }

  Future<void> _loadHeatmap() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final points = await SupplyHeatmapService.fetchSupplyHeatmap(
        _selectedCrop,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _points = points;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Supply Heatmap'),
        backgroundColor: Color(primaryColour),
      ),
      body: Column(
        children: [
          Container(
            color: theme.colorScheme.surface,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: DropdownButtonFormField<String>(
              initialValue: _selectedCrop,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Select Crop',
                labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 1.4,
                  ),
                ),
              ),
              dropdownColor: theme.colorScheme.surface,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              items: _defaultCrops
                  .map(
                    (crop) => DropdownMenuItem<String>(
                      value: crop,
                      child: Text(
                        crop,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null || value == _selectedCrop) {
                  return;
                }

                setState(() {
                  _selectedCrop = value;
                });
                _loadHeatmap();
              },
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  options: const MapOptions(
                    initialCenter: _zimbabweCenter,
                    initialZoom: 6.5,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c'],
                      retinaMode: MediaQuery.of(context).devicePixelRatio > 1.0,
                    ),
                    _HeatmapLayer(points: _points),
                  ],
                ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: _HeatLegend(theme: theme),
                ),
                if (_loading)
                  const Positioned.fill(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (_error != null && !_loading)
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        margin: const EdgeInsets.all(20),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Failed to load heatmap data',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _loadHeatmap,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(primaryColour),
                              ),
                              child: const Text(
                                'Retry',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeatmapLayer extends StatelessWidget {
  final List<HeatmapPoint> points;

  const _HeatmapLayer({required this.points});

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) => CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _HeatmapPainter(points: points, camera: camera),
        ),
      ),
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  final List<HeatmapPoint> points;
  final MapCamera camera;

  const _HeatmapPainter({required this.points, required this.camera});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) {
      return;
    }

    final maxWeight = points
        .map((point) => point.normalizedWeight)
        .fold<double>(0.0, math.max);
    if (maxWeight <= 0.0) {
      return;
    }

    for (final point in points) {
      final center = camera.getOffsetFromOrigin(
        LatLng(point.latitude, point.longitude),
      );
      final intensity = _logarithmicIntensity(
        currentWeight: point.normalizedWeight,
        maxWeight: maxWeight,
      );
      if (intensity <= 0.0) {
        continue;
      }

      final radius = _scaledRadius(
        intensity: intensity,
        zoom: camera.zoom,
      );

      if (center.dx < -radius ||
          center.dx > size.width + radius ||
          center.dy < -radius ||
          center.dy > size.height + radius) {
        continue;
      }

      final color = _heatColor(intensity);
      final shader = ui.Gradient.radial(
        center,
        radius,
        <Color>[
          color.withOpacity(0.85),
          color.withOpacity(0.45),
          color.withOpacity(0.10),
          Colors.transparent,
        ],
        const <double>[0.0, 0.35, 0.75, 1.0],
      );

      final paint = Paint()
        ..blendMode = BlendMode.plus
        ..shader = shader;

      canvas.drawCircle(center, radius, paint);
    }
  }

  double _logarithmicIntensity({
    required double currentWeight,
    required double maxWeight,
  }) {
    if (currentWeight <= 0.0 || maxWeight <= 0.0) {
      return 0.0;
    }

    return (math.log(currentWeight + 1) / math.log(maxWeight + 1)).clamp(
      0.0,
      1.0,
    );
  }

  double _scaledRadius({required double intensity, required double zoom}) {
    final zoomScale = math.pow(2.0, (zoom - 6.5) / 2.4).toDouble().clamp(
      0.45,
      4.0,
    );
    final baseRadius = 28.0 + (intensity * 34.0);
    return baseRadius * zoomScale;
  }

  Color _heatColor(double intensity) {
    final clampedIntensity = intensity.clamp(0.0, 1.0);
    if (clampedIntensity <= 0.0) {
      return Colors.transparent;
    }

    final hue = (1.0 - clampedIntensity) * 120.0;
    final hsv = HSVColor.fromAHSV(1.0, hue, 0.95, 1.0);
    return hsv.toColor();
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.camera != camera;
  }
}

class _HeatLegend extends StatelessWidget {
  final ThemeData theme;

  const _HeatLegend({required this.theme});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Supply Intensity',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 120,
              height: 10,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                gradient: const LinearGradient(
                  colors: [
                    Colors.green,
                    Colors.yellow,
                    Colors.orange,
                    Colors.red,
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            const SizedBox(
              width: 120,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Lower',
                    style: TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                  Text(
                    'Log Scale',
                    style: TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                  Text(
                    'Higher',
                    style: TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Colors reflect raw kg using local logarithmic scaling.',
              style: TextStyle(color: Colors.white60, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}
