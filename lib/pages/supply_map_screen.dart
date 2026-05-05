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
    'Carrots',
    'Tomatoes',
    'Wheat',
    'Soya Beans',
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
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: _defaultCrops.map((crop) {
                  final selected = crop == _selectedCrop;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(crop),
                      selected: selected,
                      onSelected: (value) {
                        if (!value || selected) {
                          return;
                        }
                        setState(() {
                          _selectedCrop = crop;
                        });
                        _loadHeatmap();
                      },
                      selectedColor: theme.colorScheme.primary,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      labelStyle: TextStyle(
                        color: selected
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
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
                    MarkerLayer(markers: _buildCityMarkers()),
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

  List<Marker> _buildCityMarkers() {
    return _points
        .map(
          (point) => Marker(
            point: LatLng(point.latitude, point.longitude),
            width: 120,
            height: 22,
            alignment: Alignment.topCenter,
            child: IgnorePointer(
              child: Text(
                point.city,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                ),
              ),
            ),
          ),
        )
        .toList();
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

    for (final point in points) {
      final center = camera.getOffsetFromOrigin(
        LatLng(point.latitude, point.longitude),
      );

      final radius = _scaledRadius(
        normalizedWeight: point.normalizedWeight,
        zoom: camera.zoom,
      );

      if (center.dx < -radius ||
          center.dx > size.width + radius ||
          center.dy < -radius ||
          center.dy > size.height + radius) {
        continue;
      }

      final color = _heatColor(point.normalizedWeight);
      final shader = ui.Gradient.radial(
        center,
        radius,
        [color, Colors.transparent],
        const [0.0, 1.0],
      );

      final paint = Paint()
        ..blendMode = BlendMode.screen
        ..shader = shader;

      canvas.drawCircle(center, radius, paint);
    }
  }

  double _scaledRadius({
    required double normalizedWeight,
    required double zoom,
  }) {
    final weight = normalizedWeight.clamp(0.0, 1.0);
    final zoomScale = math
        .pow(2.0, (zoom - 6.5) / 3.0)
        .toDouble()
        .clamp(0.6, 2.4);
    final baseRadius = 12 + (weight * 44);
    return baseRadius * zoomScale;
  }

  Color _heatColor(double normalizedWeight) {
    final weight = normalizedWeight.clamp(0.0, 1.0);
    if (weight <= 0.0) {
      return Colors.transparent;
    }

    final hue = (1.0 - weight) * 120.0;
    final hsv = HSVColor.fromAHSV(0.70, hue, 1.0, 1.0);
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
                    Colors.transparent,
                    Colors.green,
                    Colors.yellow,
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
                    'None',
                    style: TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                  Text(
                    'Low',
                    style: TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                  Text(
                    'High',
                    style: TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
