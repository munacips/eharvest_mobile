import 'dart:async';
import 'package:eharvest_mobile/models/tracking_update.dart';
import 'package:flutter/material.dart';
import 'package:eharvest_mobile/global_variables.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:eharvest_mobile/services/auth_service.dart';
import 'package:eharvest_mobile/services/logistics_service.dart';
import 'package:eharvest_mobile/services/tracking_service.dart';
import 'package:latlong2/latlong.dart';

class LogisticsRequestPage extends StatefulWidget {
  final LogisticsRequest logisticsRequest;
  final VoidCallback? onUpdate;
  final bool allowEditing;

  const LogisticsRequestPage({
    super.key,
    required this.logisticsRequest,
    this.onUpdate,
    this.allowEditing = true,
  });

  @override
  State<LogisticsRequestPage> createState() => _LogisticsRequestPageState();
}

class _LogisticsRequestPageState extends State<LogisticsRequestPage> {
  static const LatLng _defaultMapCenter = LatLng(-19.0154, 29.1549);

  late LogisticsRequest _logisticsRequest;
  late TextEditingController _deliveryLocationController;
  final MapController _mapController = MapController();
  bool _isEditing = false;
  bool _isSaving = false;
  bool _actionLoading = false;
  bool _trackingLoading = true;
  bool _isPublishingLocation = false;
  String? _trackingError;
  int? _userId;
  String _roleKey = '';
  TrackingUpdate? _trackingUpdate;
  TrackingConnectionStatus _trackingStatus =
      TrackingConnectionStatus.disconnected;
  OrderTrackingSubscription? _trackingSubscription;
  Timer? _providerLocationTimer;
  bool _hasCenteredOnTrackedLocation = false;

  @override
  void initState() {
    super.initState();
    _logisticsRequest = widget.logisticsRequest;
    _deliveryLocationController = TextEditingController(
      text: _logisticsRequest.deliveryLocation,
    );
    _loadCurrentUser();
    _initializeTracking();
  }

  @override
  void dispose() {
    _providerLocationTimer?.cancel();
    _trackingSubscription?.disconnect();
    _deliveryLocationController.dispose();
    super.dispose();
  }

  int? get _orderId => _logisticsRequest.order?.id;

  Future<void> _initializeTracking() async {
    final orderId = _orderId;
    if (orderId == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _trackingLoading = false;
        _trackingError = 'Tracking is unavailable for this delivery right now.';
      });
      return;
    }

    setState(() {
      _trackingLoading = true;
      _trackingError = null;
    });

    try {
      final lastKnown = await TrackingService.fetchLastKnownLocation(orderId);
      if (!mounted) {
        return;
      }
      setState(() {
        _trackingUpdate = lastKnown;
      });
      _centerMapOnTrackedLocation(lastKnown);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _trackingError = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _trackingLoading = false;
        });
      }
    }

    _trackingSubscription?.disconnect();
    _trackingSubscription = TrackingService.subscribeToOrderTracking(
      orderId: orderId,
      onLocation: (update) {
        if (!mounted) {
          return;
        }
        setState(() {
          _trackingUpdate = update;
          _trackingError = null;
        });
        _centerMapOnTrackedLocation(update);
      },
      onStatusChanged: (status) {
        if (!mounted) {
          return;
        }
        setState(() {
          _trackingStatus = status;
        });
      },
      onError: (message) {
        if (!mounted) {
          return;
        }
        setState(() {
          _trackingError = message;
        });
      },
    );
  }

  void _centerMapOnTrackedLocation(TrackingUpdate? update) {
    if (update == null || !mounted) {
      return;
    }

    final nextCenter = LatLng(update.latitude, update.longitude);
    if (!_hasCenteredOnTrackedLocation) {
      _hasCenteredOnTrackedLocation = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _mapController.move(nextCenter, 14);
      });
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _mapController.move(nextCenter, _mapController.camera.zoom);
    });
  }

  Future<void> _updateLogisticsRequest() async {
    if (_deliveryLocationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter delivery location')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final token = await AuthService.getToken();
      if (token == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Authentication error')));
        return;
      }

      final response = await http.put(
        Uri.parse('${api}logistics/${_logisticsRequest.id}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'deliveryLocation': _deliveryLocationController.text,
          'pickupLocation': _logisticsRequest.pickupLocation,
          'status': _logisticsRequest.status,
          'cost': _logisticsRequest.cost,
        }),
      );

      if (response.statusCode == 200) {
        final updatedJson = json.decode(response.body);
        setState(() {
          _logisticsRequest = LogisticsRequest.fromJson(updatedJson);
          _isEditing = false;
        });
        widget.onUpdate?.call();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logistics request updated successfully'),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update logistics request')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _loadCurrentUser() async {
    final userId = await AuthService.getUserId();
    final role = await AuthService.getRole();
    if (!mounted) return;
    setState(() {
      _userId = userId;
      _roleKey = (role ?? '')
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[\s-]+'), '_');
    });
    _syncProviderLocationPublishing();
  }

  Future<void> _refreshRequest() async {
    final updated = await LogisticsService.getRequest(_logisticsRequest.id);
    if (!mounted) return;
    setState(() {
      _logisticsRequest = updated;
      _deliveryLocationController.text = updated.deliveryLocation;
    });
    _syncProviderLocationPublishing();
    widget.onUpdate?.call();
  }

  Future<void> _runAction(
    String successMessage,
    Future<LogisticsRequest> Function() action,
  ) async {
    setState(() => _actionLoading = true);
    try {
      final updated = await action();
      if (!mounted) return;
      setState(() {
        _logisticsRequest = updated;
        _deliveryLocationController.text = updated.deliveryLocation;
      });
      _syncProviderLocationPublishing();
      widget.onUpdate?.call();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  String _normalizeStatus(String raw) {
    return raw.trim().toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');
  }

  bool get _isBuyer {
    return _roleKey.contains('buyer') &&
        _logisticsRequest.order?.buyer?.id == _userId;
  }

  bool get _isProvider {
    return (_roleKey.contains('logistics') || _roleKey.contains('driver')) &&
        _logisticsRequest.assignedProvider?.id == _userId;
  }

  bool get _canMarkInTransit {
    final status = _normalizeStatus(_logisticsRequest.status);
    return _isProvider && (status == 'assigned' || status == 'accepted');
  }

  bool get _canConfirmDelivered {
    final status = _normalizeStatus(_logisticsRequest.status);
    return _isBuyer && status == 'in_transit';
  }

  bool get _isActiveProviderDelivery {
    final status = _normalizeStatus(_logisticsRequest.status);
    return _isProvider &&
        _orderId != null &&
        <String>{'accepted', 'assigned', 'in_transit'}.contains(status);
  }

  Future<void> _syncProviderLocationPublishing() async {
    if (!_isActiveProviderDelivery) {
      _providerLocationTimer?.cancel();
      _providerLocationTimer = null;
      return;
    }

    if (_providerLocationTimer != null) {
      return;
    }

    final hasPermission = await TrackingService.ensureLocationPermission();
    if (!mounted) {
      return;
    }
    if (!hasPermission) {
      setState(() {
        _trackingError =
            'Location permission is required to share live delivery updates.';
      });
      return;
    }

    await _publishCurrentProviderLocation();
    _providerLocationTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _publishCurrentProviderLocation();
    });
  }

  Future<void> _publishCurrentProviderLocation() async {
    if (_isPublishingLocation || !_isActiveProviderDelivery) {
      return;
    }

    final orderId = _orderId;
    final providerId = _logisticsRequest.assignedProvider?.id ?? _userId;
    if (orderId == null || providerId == null) {
      return;
    }

    _isPublishingLocation = true;
    try {
      final position = await TrackingService.getCurrentPosition();
      final update = _trackingFromPosition(
        orderId: orderId,
        providerId: providerId,
        position: position,
      );
      await TrackingService.publishLocation(update);
      if (!mounted) {
        return;
      }
      setState(() {
        _trackingUpdate = update;
        _trackingError = null;
      });
      _centerMapOnTrackedLocation(update);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _trackingError = 'Unable to share live driver location right now.';
      });
    } finally {
      _isPublishingLocation = false;
    }
  }

  TrackingUpdate _trackingFromPosition({
    required int orderId,
    required int providerId,
    required Position position,
  }) {
    final heading = position.heading.isFinite ? position.heading : 0.0;
    final speed = position.speed.isFinite ? position.speed : 0.0;
    return TrackingUpdate(
      orderId: orderId,
      providerId: providerId,
      latitude: position.latitude,
      longitude: position.longitude,
      heading: heading,
      speed: speed,
      timestamp: DateTime.now(),
    );
  }

  String _trackingStatusLabel() {
    switch (_trackingStatus) {
      case TrackingConnectionStatus.connecting:
        return 'Connecting to live tracking...';
      case TrackingConnectionStatus.connected:
        return _trackingUpdate == null
            ? 'Connected. Waiting for driver location.'
            : 'Live tracking connected';
      case TrackingConnectionStatus.reconnecting:
        return 'Reconnecting to live tracking...';
      case TrackingConnectionStatus.authExpired:
        return 'Tracking session expired';
      case TrackingConnectionStatus.disconnected:
        return 'Live tracking offline';
    }
  }

  Color _trackingStatusColor() {
    switch (_trackingStatus) {
      case TrackingConnectionStatus.connected:
        return Colors.green;
      case TrackingConnectionStatus.connecting:
      case TrackingConnectionStatus.reconnecting:
        return Colors.orange;
      case TrackingConnectionStatus.authExpired:
        return Colors.red;
      case TrackingConnectionStatus.disconnected:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Color(primaryColour),
        elevation: 0,
        title: Text(
          'Logistics Request #${_logisticsRequest.id}',
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (widget.allowEditing && !_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            ),
          if (widget.allowEditing && _isEditing)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  _deliveryLocationController.text =
                      _logisticsRequest.deliveryLocation;
                });
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              decoration: BoxDecoration(
                color: Color(primaryColour),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.local_shipping, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Request #${_logisticsRequest.id}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _statusChip(_logisticsRequest.status),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.attach_money, color: Colors.white70, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Cost: ${_logisticsRequest.cost.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            // Details Section
            const Text(
              'Logistics Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailCard(
              icon: Icons.location_on,
              label: 'Pickup Location',
              value: _logisticsRequest.pickupLocation,
            ),
            const SizedBox(height: 12),
            _buildDetailCard(
              icon: Icons.location_on_outlined,
              label: 'Delivery Location',
              value: _isEditing ? null : _logisticsRequest.deliveryLocation,
              editingWidget: _isEditing
                  ? TextField(
                      controller: _deliveryLocationController,
                      decoration: InputDecoration(
                        hintText: 'Enter delivery location',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 12,
                        ),
                      ),
                      maxLines: null,
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            _buildDetailCard(
              icon: Icons.info_outline,
              label: 'Status',
              value: _logisticsRequest.status,
            ),
            const SizedBox(height: 12),
            _buildTrackingCard(),
            const SizedBox(height: 12),
            _buildDetailCard(
              icon: Icons.lock_outline,
              label: 'Escrow',
              value: _logisticsRequest.escrowReleased
                  ? 'Released to driver'
                  : (_logisticsRequest.escrowHeld
                        ? 'Held from buyer wallet'
                        : 'Not held yet'),
            ),
            if (_logisticsRequest.assignedProvider != null)
              Column(
                children: [
                  const SizedBox(height: 12),
                  _buildDetailCard(
                    icon: Icons.person,
                    label: 'Assigned Provider',
                    value: _logisticsRequest.assignedProvider!.displayName,
                  ),
                ],
              ),
            const SizedBox(height: 30),
            if (_canMarkInTransit || _canConfirmDelivered)
              _buildEscrowActions(),
            if (_canMarkInTransit || _canConfirmDelivered)
              const SizedBox(height: 16),
            if (widget.allowEditing && _isEditing)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _updateLogisticsRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(primaryColour),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
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

  Widget _buildEscrowActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_canMarkInTransit)
          ElevatedButton.icon(
            onPressed: _actionLoading
                ? null
                : () => _runAction(
                    'Delivery marked in transit.',
                    () => LogisticsService.markInTransit(_logisticsRequest.id),
                  ),
            icon: _actionLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.local_shipping_outlined),
            label: const Text('Start Delivery'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(primaryColour),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        if (_canConfirmDelivered)
          ElevatedButton.icon(
            onPressed: _actionLoading
                ? null
                : () => _runAction(
                    'Delivery confirmed. Logistics escrow released to the driver.',
                    () => LogisticsService.markDelivered(_logisticsRequest.id),
                  ),
            icon: _actionLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.verified_outlined),
            label: const Text('Confirm Received'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(primaryColour),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        TextButton.icon(
          onPressed: _actionLoading ? null : _refreshRequest,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh status'),
        ),
      ],
    );
  }

  Widget _buildTrackingCard() {
    final trackedPoint = _trackingUpdate == null
        ? _defaultMapCenter
        : LatLng(_trackingUpdate!.latitude, _trackingUpdate!.longitude);
    final hasLiveLocation = _trackingUpdate != null;
    final statusColor = _trackingStatusColor();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.map_outlined, color: Color(primaryColour), size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Live Order Tracking',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _trackingStatusLabel(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 240,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: trackedPoint,
                      initialZoom: hasLiveLocation ? 14 : 6.5,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                        subdomains: const ['a', 'b', 'c'],
                      ),
                      MarkerLayer(
                        markers: hasLiveLocation
                            ? [
                                Marker(
                                  point: trackedPoint,
                                  width: 84,
                                  height: 84,
                                  child: _buildDriverMarker(),
                                ),
                              ]
                            : const <Marker>[],
                      ),
                    ],
                  ),
                  if (_trackingLoading)
                    Container(
                      color: Colors.black.withOpacity(0.12),
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(),
                    ),
                  if (!_trackingLoading && !hasLiveLocation)
                    Container(
                      color: Colors.black.withOpacity(0.22),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(20),
                      child: const Text(
                        'Waiting for driver location',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_trackingError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _trackingError!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          if (hasLiveLocation) ...[
            Text(
              'Driver position: ${_trackingUpdate!.latitude.toStringAsFixed(5)}, ${_trackingUpdate!.longitude.toStringAsFixed(5)}',
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 4),
            Text(
              'Heading ${_trackingUpdate!.heading.toStringAsFixed(0)}°  •  Speed ${_trackingUpdate!.speed.toStringAsFixed(1)} m/s',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            if (_trackingUpdate!.timestamp != null) ...[
              const SizedBox(height: 4),
              Text(
                'Last update ${_trackingUpdate!.timestamp!.toLocal()}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ] else
            const Text(
              'The map will update automatically as soon as the driver starts sharing location.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: _initializeTracking,
                icon: const Icon(Icons.refresh),
                label: const Text('Reload tracking'),
              ),
              if (_trackingStatus != TrackingConnectionStatus.connected)
                TextButton.icon(
                  onPressed: () => _trackingSubscription?.reconnectNow(),
                  icon: const Icon(Icons.wifi_protected_setup),
                  label: const Text('Reconnect'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDriverMarker() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Color(primaryColour),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.local_shipping,
            color: Colors.white,
            size: 24,
          ),
        ),
        Container(
          width: 3,
          height: 18,
          color: Color(primaryColour),
        ),
      ],
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required String label,
    String? value,
    Widget? editingWidget,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Color(primaryColour), size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (value != null)
            Text(
              value,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
          if (editingWidget != null) editingWidget,
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'pending':
        color = Colors.orange;
        break;
      case 'accepted':
      case 'assigned':
        color = Colors.blue;
        break;
      case 'in_transit':
        color = Colors.orange;
        break;
      case 'completed':
      case 'delivered':
        color = Colors.green;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      default:
        color = Colors.blueGrey;
    }
    return Chip(
      label: Text(status, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
    );
  }
}
